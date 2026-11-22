# Read options
opts=$(getopt -ao ht:f:r:c:m:b:g:p:d:s:e:a:klyvq -l help,key-type:,format:,subject:,rand:,config:,cipher:,digest:,rsa-bits:,rsa-pubexp:,ec-curve:,hexseed:,param:,paramfile:,password:,directory:,req-type:,ca-type:,days:,startdate:,enddate:,create-pem,create-p12,create-pkcs12,keep-csr,list,yes,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

dir=''
pass=''
verb=''
ciph=''
cnf='openssl.cnf'
alg='RSA'
fmt='DER'
fd=/dev/stdout
genpem=0
genp12=0
keep=0
yes=0

# OpenSSL arguments
ssl_reqext=''
ssl_caext=''
ssl_verb=''
ssl_batch=''
declare -a subj
declare -a genpkey_args
declare -a ca_args

# Check presence of OpenSSL
command -v openssl &>/dev/null
readonly openssl=$?

# Include common modules
. "$script_dir/.internal/mod_config.sh" || { echo "Module not found: $script_dir/.internal/mod_config.sh" 1>&2; exit 3; }
. "$script_dir/.internal/mod_list.sh" || { echo "Module not found: $script_dir/.internal/mod_list.sh" 1>&2; exit 3; }

list() {
	[[ $openssl -ne 0 ]] && usage
	list_key_algo_names
	echo; list_cipher_names
	echo; list_digest_names
	echo; list_ec_curve_names
	exit 2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-s|--subject) subj+=('-subj' "$2"); shift 2 ;;
		-t|--key-type) alg="${2^^}"; shift 2 ;;
		-f|--format)
			fmt="${2^^}"
			if [[ "$fmt" == P* ]]; then fmt='PEM'
			elif [[ "$fmt" == D* ]]; then fmt='DER'; fi
			shift 2 ;;
		-r|--rand)
			[[ -f "$2" ]] || { echo "The rand file $2 does not exists!" 1>&2; exit 2; }
			genpkey_args+=('-rand' "$(realpath -m "$2")")
			shift 2 ;;
		-e|--req-type) ssl_reqext="-reqexts $2"; shift 2 ;;
		-a|--ca-type) ssl_caext="-extensions $2"; shift 2 ;;
		-m|--digest) ca_args+=('-md' "$2"); shift 2 ;;
		-b|--rsa-bits) genpkey_args+=('-pkeyopt' "rsa_keygen_bits:$2"); shift 2 ;;
		--rsa-pubexp) genpkey_args+=('-pkeyopt' "rsa_keygen_pubexp:$2"); shift 2 ;;
		--ec-curve) genpkey_args+=('-pkeyopt' "ec_paramgen_curve:$2"); shift 2 ;;
		--hexseed) genpkey_args+=('-pkeyopt' "hexseed:$2"); shift 2 ;;
		--paramfile)
			[[ -f "$2" ]] || { echo "The parameter file $2 does not exists!" 1>&2; exit 2; }
			genpkey_args+=('-paramfile' "$(realpath -m "$2")")
			shift 2 ;;
		-g|--param) genpkey_args+=('-pkeyopt' "$2"); shift 2 ;;
		-d|--days) ca_args+=('-days' "$2"); shift 2 ;;
		--startdate) ca_args+=('-startdate' "$2"); shift 2 ;;
		--enddate) ca_args+=('-enddate' "$2"); shift 2 ;;
		--directory)
			[[ "$2" != */* ]] || { echo 'Please enter a name, not a path after --directory!' 1>&2; usage; }
			dir="$2"; shift 2 ;;
		-p|--password) pass="$2"; shift 2 ;;
		-c|--config) cnf="$2"; shift 2 ;;
		--cipher) ciph="-${2,,}"; shift 2 ;;
		--create-pem) genpem=1; shift ;;
		--create-p12|--create-pkcs12) genp12=1; shift ;;
		-k|--keep-csr) keep=1; shift ;;
		-y|--yes) yes=1; shift ;;
		-v|--verbose) verb='-v'; ssl_verb='-verbose'; shift ;;
		-q|--quiet) fd=/dev/null; shift ;;
		-l|--list) list ;;
		-h|--help) usage ;;
		--) shift; break ;;
		*) echo "Unknown option: $1" 1>&2; usage ;;
	esac
done

# Check positional arguments
[[ $# -ge 1 ]] || usage
[[ "$1" != */* ]] || { echo 'Please enter a name, not a path!' 1>&2; usage; }
[[ $openssl -eq 0 ]] || { echo 'OpenSSL command was not found!' 1>&2; usage; }

# Check if the config exists
readonly config_file="$script_dir/../configs/$cnf"
[[ -f "$config_file" ]] || { echo "Config file $cnf not found!" 1>&2; exit 2; }

[[ $yes -eq 0 ]] || ssl_batch='-batch'

set -e

# Extracting the path of the certificates from the config
[[ -z "$dir" ]] && readonly certs_dir=$(cnf_get_single_value certs 'certs' "$config_file") || readonly certs_dir="$dir"

# Move to the data directory
readonly temp_csr=$(mktemp -u)
readonly temp_cer=$(mktemp -u)
readonly temp_key=$(mktemp -u)
atexit() {
	rm -f "$temp_csr" &>/dev/null
	rm -f "$temp_cer" &>/dev/null
	rm -f "$temp_key" &>/dev/null
	popd &>/dev/null
}
pushd "$script_dir/../data" &>/dev/null
trap atexit EXIT

# Check if certificate file already exists
readonly cert="$certs_dir/$1"
[[ ! -f "$cert.cer" ]] || { echo "The certificate $1 already exists in $certs_dir!" 1>&2; exit 2; }
