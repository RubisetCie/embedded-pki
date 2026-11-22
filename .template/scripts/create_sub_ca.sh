#!/bin/bash

usage() {
	printf "Usage: $0 [options] <cert name> [<ca name>]

Create a new X.509 certificate to form the base of a sub CA.

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

# Include body
readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
. "$script_dir/.internal/body_newcert_opts.sh" || { echo "Body not found: $script_dir/.internal/body_newcert_opts.sh" 1>&2; exit 3; }

# Check if the sub CA already exists
readonly subca="${2:-$1}"
readonly dest_dir="../subca/$subca"
[[ ! -d "$dest_dir" ]] || { echo "The sub CA $subca already exists!" 1>&2; exit 2; }

# Retrieve the paths of data files
readonly database=$(cnf_get_single_value database 'index.txt' "../configs/$cnf")
readonly serial=$(cnf_get_single_value serial 'serial' "../configs/$cnf")
readonly crlnumber=$(cnf_get_single_value crlnumber 'crlnumber' "../configs/$cnf")
readonly newcerts=$(cnf_get_single_value new_certs_dir 'newcerts' "$config_file")

# Create certificate
. "$script_dir/.internal/body_newcert_core.sh" || { echo "Body not found: $script_dir/.internal/body_newcert_core.sh" 1>&2; exit 3; }

# Create the sub CA structure
echo 'Creating sub CA directories...' >$fd
mkdir $verb -m0775 '../subca' >$fd 2>/dev/null || true
mkdir $verb -m0775 "$dest_dir" "$dest_dir/data" "$dest_dir/configs" "$dest_dir/scripts" "$dest_dir/scripts/.internal" >$fd

echo 'Copying configs...' >$fd
for c in ../configs/*; do
	dest="${c/..\//}"; cp -r $verb --preserve=mode,ownership "$c" "$dest_dir/$dest" >$fd
done

echo 'Setting up initial data...' >$fd
. "$script_dir/.internal/body_init_data.sh" || { echo "Body not found: $script_dir/.internal/body_init_data.sh" 1>&2; exit 3; }

echo 'Linking individual scripts...' >$fd
find ../scripts -name '*.sh' -print0 |
	while IFS= read -rd '' l; do
		dest="${l/..\//}"; rel=$(realpath -s --relative-to="$dest_dir/${dest%/*}" "$l"); ln -s $verb "$rel" "$dest_dir/$dest" >$fd
	done

# Retrieve the locations of the CA certificate and key
readonly ca_key=$(cnf_get_single_value private_key 'private/cakey.key' "../configs/$cnf")
readonly ca_cert=$(cnf_get_single_value certificate 'cacert.cer' "../configs/$cnf")

# Copy the certificate and private key as root of the sub CA
echo 'Copying root certificate to sub CA...' >$fd
mkdir $verb -pm0775 "$dest_dir/data/$newcerts" >$fd 2>/dev/null || true
mkdir $verb -pm0775 "$dest_dir/data/${ca_cert%/*}" >$fd 2>/dev/null || true; cp $verb --preserve=mode,ownership "$cert.cer" "$dest_dir/data/$ca_cert"
mkdir $verb -pm0775 "$dest_dir/data/${ca_key%/*}" >$fd 2>/dev/null || true; cp $verb --preserve=mode,ownership "$cert.key" "$dest_dir/data/$ca_key"

echo 'Success!' >$fd

# Print out the certificate in PEM format
if [[ $fd = /dev/stdout ]]; then
	echo; openssl x509 -in "$temp_cer" -inform PEM >$fd
fi
