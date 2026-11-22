#!/bin/bash

usage() {
	printf "Usage: $0 [options] <cert name or serial hex>

Revoke an X.509 certificate from name or hexadecimal serial.

Options:
  -c|--config <conf>: Pick a specific OpenSSL config file (relative to ./configs; default is openssl.cnf).
     --directory <d>: Set the directory in which the certificate is placed.
  -v|--verbose      : Turn on commands verbosity.
  -q|--quiet        : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao hc:vq -l help,config:,directory:,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

dir=''
verb=''
cnf='openssl.cnf'
fd=/dev/stdout

# Check presence of OpenSSL
command -v openssl &>/dev/null
readonly openssl=$?

while [[ $# -gt 0 ]]; do
	case "$1" in
		-c|--config) cnf="$2"; shift 2 ;;
		--directory)
			[[ "$2" != */* ]] || { echo 'Please enter a name, not a path after --directory!' 1>&2; usage; }
			dir="$2"; shift 2 ;;
		-v|--verbose) verb='-verbose'; shift ;;
		-q|--quiet) fd=/dev/null; shift ;;
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
readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$script_dir/.internal/mod_config.sh" || { echo "Module not found: $script_dir/.internal/mod_config.sh" 1>&2; exit 3; }

# Check if the config exists
readonly config_file="$script_dir/../configs/$cnf"
[[ -f "$config_file" ]] || { echo "Config file $cnf not found!" 1>&2; exit 2; }

set -e

# Extracting the path of the certificates from the config
[[ -z "$dir" ]] && readonly certs_dir=$(cnf_get_single_value certs 'certs' "$config_file") || readonly certs_dir="$dir"
readonly newcerts=$(cnf_get_single_value new_certs_dir 'newcerts' "$config_file")

atexit() { popd &>/dev/null; }
pushd "$script_dir/../data" &>/dev/null
trap atexit EXIT

# Check if the certificate exists
cert="$certs_dir/$1.cer"
[[ -f "$cert" ]] || cert="$newcerts/$1.pem"
[[ -f "$cert" ]] || { echo "The certificate $1 does not exists!" 1>&2; exit 2; }

echo 'Revoking the certificate...' >$fd
openssl ca $verb -revoke "$cert" -updatedb -config "../configs/$cnf" >$fd

echo 'Success!' >$fd
