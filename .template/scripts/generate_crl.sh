#!/bin/bash

usage() {
	printf "Usage: $0 [options]

Generate a revocation list from all the revoked certificates.

Options:
  -f|--format <format>: Format of the CRL file (PEM or DER; default is DER).
  -c|--config   <conf>: Pick a specific OpenSSL config file (relative to ./configs; default is openssl.cnf).
  -d|--days     <days>: Override the number of days before the next CRL is due.
     --directory <dir>: Override the CRL directory from the one in the config.
  -e|--ext-type  <ext>: Set the CRL extensions to include, in the form of config section (e.g: v2_crl_ext).
     --compr-key <tim>: Define the reason as the key was comprimised (time format: YYYYMMDDHHMMSSZ).
     --compr-ca  <tim>: Define the reason as the CA was comprimised (time format: YYYYMMDDHHMMSSZ).
     --affiliation    : Define the reason as the affiliation was changed.
     --superseded     : Define the reason as it has been superseded.
     --cessation      : Define the reason as a cessation of operation.
  -v|--verbose        : Turn on commands verbosity.
  -q|--quiet          : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao hf:c:d:e:vq -l help,format:,config:,ext-type:,days:,directory:,compr-key:,compr-ca:,affiliation,superseded,cessation,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

dir=''
verb=''
cnf='openssl.cnf'
fmt='DER'
fd=/dev/stdout

# OpenSSL arguments
ssl_reason=''
ssl_ext=''
ssl_verb=''
declare -a args

# Check presence of OpenSSL
command -v openssl &>/dev/null
readonly openssl=$?

while [[ $# -gt 0 ]]; do
	case "$1" in
		-f|--format)
			fmt="${2^^}"
			if [[ "$fmt" == P* ]]; then fmt='PEM'
			elif [[ "$fmt" == D* ]]; then fmt='DER'; fi
			shift 2 ;;
		-e|--ext-type) ssl_ext="-crlexts $2"; shift 2 ;;
		-d|--days) args+=('-crldays' "$2"); shift 2 ;;
		--directory)
			[[ "$2" != */* ]] || { echo 'Please enter a name, not a path after --directory!' 1>&2; usage; }
			dir="$2"; shift 2 ;;
		-c|--config) cnf="$2"; shift 2 ;;
		--compr-key)
			ssl_reason='-crl_reason keyCompromise'
			args+=('-crl_compromise' "$2")
			shift 2 ;;
		--compr-ca)
			ssl_reason='-crl_reason CACompromise'
			args+=('-crl_CA_compromise' "$2")
			shift 2 ;;
		--cessation) ssl_reason='-crl_reason cessationOfOperation'; shift ;;
		--affiliation) ssl_reason='-crl_reason affiliationChanged'; shift ;;
		--superseded) ssl_reason='-crl_reason superseded'; shift ;;
		-v|--verbose) verb='-v'; ssl_verb='-verbose'; shift ;;
		-q|--quiet) fd=/dev/null; shift ;;
		-h|--help) usage ;;
		--) break ;;
		*) echo "Unknown option: $1" 1>&2; usage ;;
	esac
done

[[ $openssl -eq 0 ]] || { echo 'OpenSSL command was not found!' 1>&2; usage; }

# Include common modules
readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$script_dir/.internal/mod_config.sh" || { echo "Module not found: $script_dir/.internal/mod_config.sh" 1>&2; exit 3; }

# Check if the config exists
readonly config_file="$script_dir/../configs/$cnf"
[[ -f "$config_file" ]] || { echo "Config file $cnf not found!" 1>&2; exit 2; }

set -e

# Extracting the path of the CRL directory from the config
[[ -z "$dir" ]] && readonly crl_dir=$(cnf_get_single_value crl_dir 'crl' "$config_file") || readonly crl_dir="$dir"
readonly crl_current=$(cnf_get_single_value crl 'crl.crl' "$config_file")
readonly crlnum_file=$(cnf_get_single_value crlnumber 'crlnumber' "$config_file")

readonly temp_crl=$(mktemp -u)
atexit() {
	rm -f "$temp_crl" &>/dev/null
	popd &>/dev/null
}
pushd "$script_dir/../data" &>/dev/null
trap atexit EXIT

# Récuperation du numéro de la CRL
read -r crl_num < "$crlnum_file" || crl_num='01'

echo 'Creating certificate revocation list...' >$fd
openssl ca $ssl_verb -gencrl -updatedb -out "$temp_crl" $ssl_reason ${args[@]} $ssl_ext -config "../configs/$cnf" >$fd

# Creating the directory
mkdir $verb -m0775 "$crl_dir" >$fd 2>/dev/null || true

# Convert to the requested format
readonly crl="$crl_dir/$crl_num.crl"
[[ $fmt = PEM ]] && cp $verb "$temp_crl" "$crl" || openssl crl -in "$temp_crl" -out "$crl" -inform PEM -outform "$fmt"

# Link to the current CRL
ln -sf $verb "$crl" "$crl_current" >$fd

echo 'Success!' >$fd

# Print out the CRL in PEM format
if [[ $fd = /dev/stdout ]]; then
	echo; openssl crl -in "$temp_crl" -inform PEM >$fd
fi
