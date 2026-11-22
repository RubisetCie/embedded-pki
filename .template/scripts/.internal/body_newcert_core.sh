if [[ -n "$ciph" ]]; then
	[[ -n "$pass" ]] || pass=$(cnf_get_single_value input_password '' "../configs/$cnf")
	[[ -z "$pass" ]] || genpkey_args+=('-pass' "pass:$pass")
fi

echo 'Generating the private key...' >$fd
openssl genpkey $ssl_verb -out "$temp_key" $ciph -algorithm "$alg" -outform "$fmt" "${genpkey_args[@]}" -config "../configs/$cnf" >$fd

echo 'Creating certificate request...' >$fd
openssl req $ssl_verb -new -key "$temp_key" -out "$temp_csr" -outform "$fmt" "${subj[@]}" $ssl_reqext -utf8 $ssl_batch -config "../configs/$cnf" </dev/tty>$fd

echo 'Creating signed certificate...' >$fd
openssl ca $ssl_verb -in "$temp_csr" -out "$temp_cer" "${ca_args[@]}" "${subj[@]}" $ssl_caext -utf8 -notext $ssl_batch -config "../configs/$cnf" </dev/tty>$fd

# Check if the certificate was accepted
[[ -f "$temp_cer" ]] || exit 4

# Creating the directory
mkdir $verb -m0775 "$certs_dir" >$fd 2>/dev/null || true

# Convert to the requested format
[[ $fmt = PEM ]] && cp $verb "$temp_cer" "$cert.cer" || openssl x509 -in "$temp_cer" -out "$cert.cer" -inform PEM -outform "$fmt"

# Copy the files to the directory
cp $verb "$temp_key" "$cert.key"
[[ $keep -eq 0 ]] || cp $verb "$temp_csr" "$cert.csr"

# Concatenate certificate and pritave key in PEM for convenience
if [[ $genpem -eq 1 ]]; then
	openssl x509 -in "$temp_cer" -inform PEM >"$cert.pem"
	openssl pkey -in "$temp_key" -inform "$fmt" >>"$cert.pem"
fi

# Create PKCS#12 combining the certificate and private key
if [[ $genp12 -eq 1 ]]; then
	echo 'Creating PKCS#11 container...' >$fd
	[[ -n "$pass" ]] && pw="-passin pass:$pass -passout pass:$pass" || pw=''

	# Need to convert the private key to PEM, because otherwise not supported
	[[ $fmt = PEM ]] || openssl pkey -in "$cert.key" -inform "$fmt" -out "$temp_key"

	openssl pkcs12 -export -in "$cert.cer" -inkey "$temp_key" -out "$cert.p12" -name "$1" $pw
fi
