# Get the first occurrence of a value within an OpenSSL config file
# Usage: cnf_get_single_value <key> <default> <openssl.cnf>
#
cnf_get_single_value() {
	local u
	local w
	local v=$(sed -En "s/^[ \t]*$1[ \t]*=(.*)$/\1/p" "$3" | head -n1 | xargs)

	# While there is a variable parameter
	while [[ "$v" =~ \$([a-zA-Z0-9]+) ]]; do
		u="${BASH_REMATCH[1]}"
		w=$(sed -En "s/^[ \t]*$u[ \t]*=(.*)$/\1/p" "$3" | head -n1 | xargs)
		v=$(sed -E "s/\\\$$u/$w/g" <<<"$v")
	done

	[[ -n "$v" ]] || v="$2"
	echo "$v"
}
