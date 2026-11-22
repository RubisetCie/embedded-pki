#!/bin/bash

usage() {
	printf "Usage: $0 [options] <ca name>

Delete a root CA by name.

Options:
  -y|--yes    : Proceed without asking for confirmation.
  -v|--verbose: Turn on commands verbosity.
  -q|--quiet  : Suppress all messages.
" 1>&2
	exit 2
}

# Read options
opts=$(getopt -ao hyvq -l help,yes,verbose,quiet -- "$@")
[[ $? -eq 0 ]] || usage
eval set --$opts

yes=0
verb=''
fd=/dev/stdout

while [[ $# -gt 0 ]]; do
	case "$1" in
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

# Ask for confirmation
if [[ $yes -eq 0 ]]; then
	read -rp "Are you sure you want to delete full CA $1? [y/n]:"</dev/tty; echo
	[[ $REPLY =~ ^[Yy]$ ]] || exit 2
fi

echo 'Removing directories...' >$fd
rm $verb -rf "$dest_dir" >$fd && echo 'Success!' >$fd

echo 'Done!' >$fd
