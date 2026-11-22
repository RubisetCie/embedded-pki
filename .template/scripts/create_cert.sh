#!/bin/bash

usage() {
	printf "Usage: $0 [options] <cert name>

Create a new X.509 certificate from name.

Options:
  -s|--subject  <subj>: Set the subject distinguished name, overriding the config (e.g: /type=value/...).
  -f|--format <format>: Format of the certificate file (PEM or DER; default is DER).
  -t|--key-type <type>: Algorithm of private key to generate (RSA, EC, etc; default is RSA).
  -k|--keep-csr       : Keep the certificate request alongside the certificate.
     --create-pem     : Create a concatenation of certificate and key, in the form of a PEM.
     --create-pkcs12  : Create a PKCS#12 combining the certificate and private key.
  -e|--req-type  <ext>: Set the type of certificate request, in the form of config section (e.g: v3_req_user).
  -a|--ca-type   <ext>: Set the type of X.509 certificate, in the form of config section (e.g: v3_cert_user).
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
     --directory <dir>: Override the certificate directory from the one in the config.
  -p|--password <pass>: Override the password of the key from the one in the config.
  -r|--rand    <files>: List of file(s) to use for random number generation.
  -l|--list           : List the supported key types, ciphers and elliptic curves.
  -y|--yes            : Proceed without asking anything for confirmation.
  -v|--verbose        : Turn on commands verbosity.
  -q|--quiet          : Suppress all messages.
" 1>&2
	exit 2
}

readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$script_dir/.internal/body_newcert_opts.sh" || { echo "Body not found: $script_dir/.internal/body_newcert_opts.sh" 1>&2; exit 3; }
. "$script_dir/.internal/body_newcert_core.sh" || { echo "Body not found: $script_dir/.internal/body_newcert_core.sh" 1>&2; exit 3; }

echo 'Success!' >$fd

# Print out the certificate in PEM format
if [[ $fd = /dev/stdout ]]; then
	echo; openssl x509 -in "$temp_cer" -inform PEM >$fd
fi
