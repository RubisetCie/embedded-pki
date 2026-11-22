# Read options
opts=$(getopt -ao hc:d:q -l help,config:,directory:,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

dir=''
cnf='openssl.cnf'

# Check presence of OpenSSL
command -v openssl &>/dev/null
readonly openssl=$?

while [[ $# -gt 0 ]]; do
	case "$1" in
		-c|--config) cnf="$2"; shift 2 ;;
		-d|--directory)
			[[ "$2" != */* ]] || { echo 'Please enter a name, not a path after --directory!' 1>&2; usage; }
			dir="$2"; shift 2 ;;
		-h|--help) usage ;;
		--) shift; break ;;
		*) echo "Unknown option: $1" 1>&2; usage ;;
	esac
done

# Check positional arguments
[[ $# -ge 1 ]] || usage
[[ "$1" != */* ]] || { echo 'Please enter a name, not a path!' 1>&2; usage; }
[[ $openssl -eq 0 ]] || { echo 'OpenSSL command was not found!' 1>&2; usage; }

# Include common modules
. "$script_dir/.internal/mod_config.sh" || { echo "Module not found: $script_dir/.internal/mod_config.sh" 1>&2; exit 3; }

# Check if the config exists
readonly config_file="$script_dir/../configs/$cnf"
[[ -f "$config_file" ]] || { echo "Config file $cnf not found!" 1>&2; exit 2; }

set -e

# Move to the data directory
atexit() { popd &>/dev/null; }
pushd "$script_dir/../data" &>/dev/null
trap atexit EXIT

# Extracting the path of the certificates from the config
[[ -z "$dir" ]] && readonly certs_dir=$(cnf_get_single_value certs 'certs' "$config_file") || readonly certs_dir="$dir"
readonly newcerts=$(cnf_get_single_value new_certs_dir 'newcerts' "$config_file")

# Check if the certificate exists
cert="$certs_dir/$1.cer"
[[ -f "$cert" ]] || cert="$newcerts/$1.pem"
[[ -f "$cert" ]] || { echo "The certificate $1 does not exists!" 1>&2; exit 2; }
