#!/bin/bash

usage() {
	printf "Usage: $0 [options] <cert name or serial hex>

Print the PEM data of an X.509 certificate from name or hexadecimal serial.

Options:
  -c|--config <conf>: Pick a specific OpenSSL config file (relative to ./configs; default is openssl.cnf).
  -d|--directory <d>: Set the directory in which the certificate is placed (default is taken from config).
" 1>&2
	exit 2
}

# Include body
readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$script_dir/.internal/body_print.sh" || { echo "Body not found: $script_dir/.internal/body_print.sh" 1>&2; exit 3; }

openssl x509 -in "$cert"
