# List the supported ciphers in current OpenSSL
#
list_cipher_names() {
	local ci
	echo 'Supported ciphers:'
	for c in $(openssl enc -list | tail -n+2 | xargs); do
		ci="${c:1}" # Remove the dash from the output
		echo "${ci^^}"
	done | column
}

# List the supported digests in current OpenSSL
#
list_digest_names() {
	echo 'Supported digests:'
	for d in $(openssl list -digest-commands | xargs); do echo "${d^^}"; done | column
}

# List the supported key algorithms in current OpenSSL
#
list_key_algo_names() {
	echo 'Supported key algorithms:'
	LANG='C' openssl list -public-key-algorithms | sed -nE 's/ *Name: *OpenSSL *([a-zA-Z0-9_-]+) *implementation/\1/p' | column
}

# List the supported elliptic curves in current OpenSSL
#
list_ec_curve_names() {
	echo 'Supported elliptic curves:'
	for c in $(openssl ecparam -list_curves | grep -F ':' | cut -d ':' -f1 | xargs); do echo "$c"; done | column
}
