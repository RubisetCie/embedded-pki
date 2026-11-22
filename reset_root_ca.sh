#!/bin/bash

usage() {
	printf "Usage: $0 [options] <ca name>

Reset a root CA to it's uninitialized state.

Options:
  -c|--config <conf>: Pick a specific OpenSSL config file (relative to ./configs; default is openssl.cnf).
  -y|--yes          : Proceed without asking for confirmation.
  -v|--verbose      : Turn on commands verbosity.
  -q|--quiet        : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao c:hyvq -l config:,help,yes,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

yes=0
verb=''
cnf='openssl.cnf'
fd=/dev/stdout

while [[ $# -gt 0 ]]; do
	case "$1" in
		-c|--config) cnf="$2"; shift 2 ;;
		-y|--yes) yes=1; shift ;;
		-v|--verbose) verb='-v'; shift ;;
		-q|--quiet) fd=/dev/null; shift ;;
		-h|--help) usage ;;
		--) shift; break ;;
		*) echo "Unknown option: $1" 1>&2; usage ;;
	esac
done

# Check positional arguments
[[ $# -ge 1 ]] || usage
[[ "$1" != */* ]] || { echo 'Please enter a name, not a path!' 1>&2; usage; }
[[ "$1" != .* ]] || { echo 'Please enter a name, that does not start with a dot!' 1>&2; usage; }

readonly script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
readonly dest_dir="$script_dir/$1"

# Check if root CA exists
[[ -d "$dest_dir" ]] || { echo "The root CA $1 does not exists!" 1>&2; exit 2; }

# Check if root CA is initialized
readonly template_dir="$script_dir/.template"
ca_cert='cacert.cer'
. "$template_dir/scripts/.internal/mod_config.sh" && ca_cert=$(cnf_get_single_value certificate 'cacert.cer' "$dest_dir/configs/$cnf")
[[ -f "$dest_dir/data/$ca_cert" ]] || { echo "The root CA $1 is not initialized!" 1>&2; exit 2; }

# Ask for confirmation
if [[ $yes -eq 0 ]]; then
	read -rp "Are you sure you want to reset CA $1? [y/n]:"</dev/tty; echo
	[[ $REPLY =~ ^[Yy]$ ]] || exit 2
fi

# Retrieve the paths of data files
readonly database=$(cnf_get_single_value database 'index.txt' "$dest_dir/configs/$cnf")
readonly serial=$(cnf_get_single_value serial 'serial' "$dest_dir/configs/$cnf")
readonly crlnumber=$(cnf_get_single_value crlnumber 'crlnumber' "$dest_dir/configs/$cnf")

# Erase the current CA in order to initialize it
echo 'Erasing current state...' >$fd

rm $verb -rf "$dest_dir/data" "$dest_dir/subca" >$fd
mkdir $verb -m0775 "$dest_dir/data" >$fd

. "$template_dir/scripts/.internal/body_init_data.sh" || { echo "Body not found: $template_dir/scripts/.internal/body_init_data.sh" 1>&2; exit 3; }

echo 'Done!' >$fd
