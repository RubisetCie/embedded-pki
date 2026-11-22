#!/bin/bash

usage() {
	printf "Usage: $0 [options] <cert name or serial hex>

Print the PEM data of the certificate chain from name or hexadecimal serial.

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

# Recurse at every CA
ca_cert=$(cnf_get_single_value certificate 'cacert.cer' "../configs/$cnf")

while [[ -f "$ca_cert" ]]; do
	openssl x509 -in "$ca_cert"
	cd '../../../data' &>/dev/null || break
	ca_cert=$(cnf_get_single_value certificate 'cacert.cer' "../configs/$cnf")
done
