#!/bin/bash

usage() {
	printf "Usage: $0 [options] <ca name>

Initialize a root CA, creating the root X.509 certificate and private key.

Options:
  -s|--subject  <subj>: Set the subject distinguished name, overriding the config (e.g: /type=value/...).
  -f|--format <format>: Format of the private key file (PEM or DER; default is DER).
  -t|--key-type <type>: Algorithm of private key to generate (RSA, EC, etc; default is RSA).
  -k|--keep-csr       : Keep the certificate request alongside the certificate.
  -e|--req-type  <ext>: Set the type of certificate request, in the form of config section (e.g: v3_req_ca).
  -a|--ca-type   <ext>: Set the type of X.509 certificate, in the form of config section (e.g: v3_cert_ca).
  -c|--config   <conf>: Pick a specific OpenSSL config file (relative to ./configs; default is openssl.cnf).
     --cipher   <ciph>: Encrypts the generated private key with the supplied cipher.
  -m|--digest <digest>: Override the message digest to use for the certificate.
  -b|--rsa-bits <bits>: Number of bits in the generated key (RSA & RSA-PSS specific).
     --rsa-pubexp <ex>: Public exponent value (supports dec and hex '0x' - RSA specific).
     --ec-curve <name>: Elliptic curve name to use for the generated key (EC specific).
     --hexseed  <seed>: Custom seed in 64 hexadecimal digits form (ML-DSA specific).
     --paramfile <par>: Custom parameter file for certain key algorithms (like DSA).
  -g|--param <key:val>: Custom key generation option to pass in 'key:value' form.
  -d|--days     <days>: Override the number of days to certify the certificate for.
     --startdate <dat>: Override the start date of validity (YYYYMMDDHHMMSSZ format).
     --enddate   <dat>: Override the end date of validity (YYYYMMDDHHMMSSZ format).
  -p|--password <pass>: Override the password of the key from the one in the config.
  -r|--rand    <files>: List of file(s) to use for random number generation.
  -l|--list           : List the supported key types, ciphers and elliptic curves.
  -y|--yes            : Proceed without asking anything for confirmation.
  -v|--verbose        : Turn on commands verbosity.
  -q|--quiet          : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao ht:f:r:c:m:b:g:p:d:s:e:a:klyvq -l help,key-type:,format:,subject:,rand:,config:,cipher:,digest:,rsa-bits:,rsa-pubexp:,ec-curve:,hexseed:,param:,paramfile:,password:,req-type:,ca-type:,days:,startdate:,enddate:,keep-csr,list,yes,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

pass=''
verb=''
ciph=''
cnf='openssl.cnf'
alg='RSA'
fmt='DER'
fd=/dev/stdout
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
readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
readonly template_dir="$script_dir/.template"
. "$template_dir/scripts/.internal/mod_config.sh" || { echo "Module not found: $template_dir/scripts/.internal/mod_config.sh" 1>&2; exit 3; }
. "$template_dir/scripts/.internal/mod_list.sh" || { echo "Module not found: $template_dir/scripts/.internal/mod_list.sh" 1>&2; exit 3; }

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
		-p|--password) pass="$2"; shift 2 ;;
		-c|--config) cnf="$2"; shift 2 ;;
		--cipher) ciph="-${2,,}"; shift 2 ;;
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
[[ "$1" != .* ]] || { echo 'Please enter a name, that does not start with a dot!' 1>&2; usage; }
[[ $openssl -eq 0 ]] || { echo 'OpenSSL command was not found!' 1>&2; usage; }

readonly dest_dir="$script_dir/$1"
readonly config_file="$dest_dir/configs/$cnf"

# Check if root CA exists
[[ -d "$dest_dir" ]] || { echo "The root CA $1 does not exists!" 1>&2; exit 2; }

# Check if root CA contains the config
[[ -f "$config_file" ]] || { echo "The root CA $1 does not contains a $cnf config!" 1>&2; exit 2; }

[[ $yes -eq 0 ]] || ssl_batch='-batch'

set -e

# Extracting the path of the private key from the config
readonly private_key=$(cnf_get_single_value private_key 'private/cakey.key' "$config_file")
readonly ca_cert=$(cnf_get_single_value certificate 'cacert.cer' "$config_file")
readonly newcerts=$(cnf_get_single_value new_certs_dir 'newcerts' "$config_file")
readonly database=$(cnf_get_single_value database 'index.txt' "$config_file")
readonly serial=$(cnf_get_single_value serial 'serial' "$config_file")

# Check if root CA is not already initialized
if [[ -f "$dest_dir/data/$ca_cert" ]]; then
	if [[ $yes -eq 0 ]]; then
		echo "The root CA $1 seems already initialized!"
		read -rp 'Do you want to erase it and proceed? [y/n]:'</dev/tty; echo
		[[ $REPLY =~ ^[Yy]$ ]] || exit 2
	fi

	readonly crlnumber=$(cnf_get_single_value crlnumber 'crlnumber' "$config_file")

	# Erase the current CA in order to initialize it
	echo 'Erasing current state...' >$fd

	rm $verb -rf "$dest_dir/data" "$dest_dir/subca" >$fd
	mkdir $verb -m0775 "$dest_dir/data" >$fd

	. "$template_dir/scripts/.internal/body_init_data.sh" || { echo "Body not found: $template_dir/scripts/.internal/body_init_data.sh" 1>&2; exit 3; }
fi

# Move to the data directory
readonly temp_csr=$(mktemp -u)
readonly temp_cer=$(mktemp -u)
atexit() {
	rm -f "$temp_csr" &>/dev/null
	rm -f "$temp_cer" &>/dev/null
	popd &>/dev/null
}
pushd "$dest_dir/data" &>/dev/null
trap atexit EXIT

echo 'Creating directories...' >$fd
mkdir $verb -pm0775 "$newcerts" "${private_key%/*}" "${ca_cert%/*}" >$fd 2>/dev/null || true
mkdir $verb -m0775  >$fd 2>/dev/null || true

if [[ -n "$ciph" ]]; then
	[[ -n "$pass" ]] || pass=$(cnf_get_single_value input_password '' "../configs/$cnf")
	[[ -z "$pass" ]] || genpkey_args+=('-pass' "pass:$pass")
fi

echo 'Generating the private key...' >$fd
openssl genpkey $ssl_verb -out "$private_key" $ciph -algorithm "$alg" -outform "$fmt" "${genpkey_args[@]}" -config "../configs/$cnf" >$fd

echo 'Creating certificate request...' >$fd
openssl req $ssl_verb -new -key "$private_key" -out "$temp_csr" -outform "$fmt" "${subj[@]}" $ssl_reqext -utf8 $ssl_batch -config "../configs/$cnf" </dev/tty>$fd

echo 'Creating self-signed certificate...' >$fd
openssl ca $ssl_verb -selfsign -in "$temp_csr" -out "$temp_cer" "${ca_args[@]}" "${subj[@]}" $ssl_caext -utf8 -notext $ssl_batch -config "../configs/$cnf" </dev/tty>$fd

# Check if the certificate was accepted
[[ -f "$temp_cer" ]] || exit 4

# Convert to the requested format
[[ $fmt = PEM ]] && { mkdir $verb -m0775 "${ca_cert%/*}" >$fd 2>/dev/null || true; cp $verb "$temp_cer" "$ca_cert"; } || openssl x509 -in "$temp_cer" -out "$ca_cert" -inform PEM -outform "$fmt"

# Copy the files to the directory
[[ $keep -eq 0 ]] || cp $verb "$temp_csr" "${ca_cert%.*}.csr"

# Cancel the database modification to erase the root CA from the index
rm $verb -f "$database" "$serial" "$newcerts"/*.pem >$fd
mv $verb "$database.old" "$database" >$fd
mv $verb "$serial.old" "$serial" >$fd

echo 'Success!' >$fd
