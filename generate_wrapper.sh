#!/bin/bash
set -Eeuo pipefail

usage() {
        cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-u intial-user-name] [-n hostname] [-p initial-password] [-s source-iso-file] [-d destination-iso-file] [-i packages-to-install-file]

This script will create fully-automated Ubuntu 20.04 Focal Fossa installation from an iso, with an optional list of packages to install.

Available options:

-h, --help              Print this help and exit
-u, --username          Initial user to create.
-n, -- hostname         Hostname of the machine.
-s, --source            Source ISO file.
-d, --destination       Destination ISO file.
-i, --install           (Optional) Preformatted list of packages to install. 
EOF
        exit
}

function parse_params() {

        while :; do
                case "${1-}" in
                -h | --help) usage ;;
                -s | --source)
                        source_iso="${2-}"
                        shift
                        ;;
                -d | --destination)
                        destination_iso="${2-}"
                        shift
                        ;;
                -u | --username)
                        username="${2-}"
                        shift
                        ;;
                -n | --hostname)
                        hostname="${2-}"
                        shift
                        ;;
                -p | --password)
                        password="${2-}"
                        shift
                        ;;
                -i | --install)
                        install="${2-}"
                        shift
                        ;;
                -?*) die "Unknown option: $1" ;;
                *) break ;;
                esac
                shift
        done
        return 0
}

parse_params "$@"

echo $password
pass_hash=$(mkpasswd --method=SHA-512 $password)
echo $pass_hash

destination=${destination_iso%.iso}
mkdir "$destination"

sed "s/<username>/${username}/g;s/<hostname>/${hostname}/g;s|<password>|${pass_hash}|g" template.cfg > "$destination"/"$destination".cfg
# conditional if we have stuff to install
if [ -n "${install}" ]; then
    cp "$destination"/"$destination".cfg "$destination"/"$destination".tmp
    echo "  packages:" > "$destination"/p.tmp
    cat "$destination"/"$destination".tmp "$destination/p.tmp" "$install" > "$destination"/"$destination".cfg
    rm "$destination"/"$destination".tmp
    rm "$destination"/p.tmp
fi

./ubuntu-autoinstall-generator.sh -a -s $source_iso -d $destination/$destination_iso -u $destination/$destination.cfg -k 
