#!/bin/bash

usage() {
	printf "Usage: $0 [options] <cert name> [<csr>]

Create a new X.509 certificate from provided CSR.
Supports both inputting CSR as a filename, as a raw PEM and as standard input.

Options:
  -s|--subject  <subj>: Set the subject distinguished name, overriding the config (e.g: /type=value/...).
  -f|--format <format>: Format of the certificate file (PEM or DER; default is DER).
  -a|--ca-type   <ext>: Set the type of X.509 certificate, in the form of config section (e.g: v3_cert_user).
  -c|--config   <conf>: Pick a specific OpenSSL config file (relative to ./configs; default is openssl.cnf).
  -m|--digest <digest>: Override the message digest to use for the certificate.
  -d|--days     <days>: Override the number of days to certify the certificate for.
     --startdate <dat>: Override the start date of validity (YYYYMMDDHHMMSSZ format).
     --enddate   <dat>: Override the end date of validity (YYYYMMDDHHMMSSZ format).
     --directory <dir>: Override the certificate directory from the one in the config.
  -l|--list           : List the supported message digest types.
  -y|--yes            : Proceed without asking anything for confirmation.
  -v|--verbose        : Turn on commands verbosity.
  -q|--quiet          : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao hf:c:m:d:s:a:lyvq -l help,format:,subject:,config:,digest:,directory:,ca-type:,days:,startdate:,enddate:,list,yes,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

dir=''
verb=''
cnf='openssl.cnf'
fmt='DER'
fd=/dev/stdout
yes=0

# OpenSSL arguments
ssl_ext=''
ssl_verb=''
ssl_batch=''
declare -a args
declare -a subj

# Check presence of OpenSSL
command -v openssl &>/dev/null
readonly openssl=$?

# Include common modules
readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$script_dir/.internal/mod_config.sh" || { echo "Module not found: $script_dir/.internal/mod_config.sh" 1>&2; exit 3; }
. "$script_dir/.internal/mod_list.sh" || { echo "Module not found: $script_dir/.internal/mod_list.sh" 1>&2; exit 3; }

list() {
	[[ $openssl -ne 0 ]] && usage
	list_digest_names
	exit 2
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-s|--subject) subj+=('-subj' "$2"); shift 2 ;;
		-f|--format)
			fmt="${2^^}"
			if [[ "$fmt" == P* ]]; then fmt='PEM'
			elif [[ "$fmt" == D* ]]; then fmt='DER'; fi
			shift 2 ;;
		-a|--ca-type) ssl_ext="-extensions $2"; shift 2 ;;
		-m|--digest) args+=('-md' "$2"); shift 2 ;;
		-d|--days) args+=('-days' "$2"); shift 2 ;;
		--startdate) args+=('-startdate' "$2"); shift 2 ;;
		--enddate) args+=('-enddate' "$2"); shift 2 ;;
		--directory)
			[[ "$2" != */* ]] || { echo 'Please enter a name, not a path after --directory!' 1>&2; usage; }
			dir="$2"; shift 2 ;;
		-c|--config) cnf="$2"; shift 2 ;;
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

# Check the input CSR
csr_file=''
readonly temp_csr=$(mktemp -u)
if [[ $# -ge 2 ]]; then
	if [[ -f "$2" ]]; then
		csr_file=$(realpath -m "$2")
	else
		echo "$2">"$temp_csr"
		csr_file="$temp_csr"
	fi
elif read -t 0; then
	cat - >"$temp_csr"
	[[ ! -s "$temp_csr" ]] || csr_file="$temp_csr"
fi
[[ -n "$csr_file" ]] || { echo "Please provide a CSR as argument or standard input!" 1>&2; usage; }

# Apply the PEM header & footer to the temp file if created
if [[ -f "$temp_csr" ]]; then
	if ! grep -qF -- '-----BEGIN CERTIFICATE REQUEST-----' "$temp_csr"; then
		readonly csr=$(<"$temp_csr")
		printf -- "-----BEGIN CERTIFICATE REQUEST-----
$csr
-----END CERTIFICATE REQUEST-----">"$temp_csr"
	fi
fi

[[ $yes -eq 0 ]] || ssl_batch='-batch'

set -e

# Extracting the path of the certificates from the config
[[ -z "$dir" ]] && readonly certs_dir=$(cnf_get_single_value certs 'certs' "$config_file") || readonly certs_dir="$dir"

# Move to the data directory
readonly temp_cer=$(mktemp -u)
atexit() {
	rm -f "$temp_cer" &>/dev/null
	rm -f "$temp_csr" &>/dev/null
	popd &>/dev/null
}
pushd "$script_dir/../data" &>/dev/null
trap atexit EXIT

# Check if certificate file already exists
readonly cert="$certs_dir/$1"
[[ ! -f "$cert.cer" ]] || { echo "The certificate $1 already exists in $certs_dir!" 1>&2; exit 2; }

echo 'Creating signed certificate...' >$fd
openssl ca $ssl_verb -in "$csr_file" -out "$temp_cer" "${args[@]}" "${subj[@]}" $ssl_ext -utf8 -notext $ssl_batch -config "../configs/$cnf" </dev/tty>$fd

# Check if the certificate was accepted
[[ -f "$temp_cer" ]] || exit 4

# Creating the directory
mkdir $verb -m0775 "$certs_dir" >$fd 2>/dev/null || true

# Convert to the requested format
[[ $fmt = PEM ]] && cp $verb "$temp_cer" "$cert.cer" || openssl x509 -in "$temp_cer" -out "$cert.cer" -inform PEM -outform "$fmt"

echo 'Success!' >$fd

# Print out the certificate in PEM format
if [[ $fd = /dev/stdout ]]; then
	echo; openssl x509 -in "$temp_cer" -inform PEM >$fd
fi
