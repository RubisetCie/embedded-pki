#!/bin/bash

usage() {
	printf "Usage: $0 [options] <ca name>

Create a root CA with a name.

Options:
  -v|--verbose: Turn on commands verbosity.
  -q|--quiet  : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao hvq -l help,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

verb=''
fd=/dev/stdout

while [[ $# -gt 0 ]]; do
	case "$1" in
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

# Check if root CA already exists
[[ ! -d "$dest_dir" ]] || { echo "The root CA $1 already exists!" 1>&2; exit 2; }

set -e

echo 'Creating directories...' >$fd
mkdir $verb -m0775 "$dest_dir" "$dest_dir/data" "$dest_dir/configs" "$dest_dir/scripts" "$dest_dir/scripts/.internal" >$fd

readonly template_dir="$script_dir/.template"

echo 'Copying configs...' >$fd
for c in "$template_dir/configs/"*.sample; do
	dest="${c/\/.template\//\/$1\/}"; cp -r $verb --preserve=mode,ownership "$c" "${dest%.sample}" >$fd
done

echo 'Setting up initial data...' >$fd
readonly database='index.txt'
readonly serial='serial'
readonly crlnumber='crlnumber'
. "$template_dir/scripts/.internal/body_init_data.sh" || { echo "Body not found: $template_dir/scripts/.internal/body_init_data.sh" 1>&2; exit 3; }

echo 'Linking individual scripts...' >$fd
find "$template_dir/scripts" -name '*.sh' -print0 |
	while IFS= read -rd '' l; do
		dest="${l/\/.template\//\/$1\/}"; rel=$(realpath -s --relative-to="${dest%/*}" "$l"); ln -s $verb "$rel" "$dest" >$fd
	done

echo 'Success!' >$fd
