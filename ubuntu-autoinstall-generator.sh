#!/bin/bash
set -Eeuo pipefail

function cleanup() {
	trap - SIGINT SIGTERM ERR EXIT
	if [ -n "${tmpdir+x}" ]; then
		rm -rf "$tmpdir"
		log "🚽 Deleted temporary working directory $tmpdir"
	fi
}

trap cleanup SIGINT SIGTERM ERR EXIT
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
today=$(/usr/bin/date +"%Y-%m-%d")

function log() {
	echo >&2 -e "[$(date +"%Y-%m-%d %H:%M:%S")] ${1-}"
}

function die() {
	local msg=$1
	local code=${2-1} # Bash parameter expansion - default exit status 1. See https://wiki.bash-hackers.org/syntax/pe#use_a_default_value
	log "$msg"
	exit "$code"
}

usage() {
	cat <<EOF
Usage: $(basename "${BASH_SOURCE[0]}") [-h] [-v] [-a] [-u user-data-file] [-m meta-data-file]

💁 This script will create fully-automated Ubuntu 20.04 Focal Fossa installation media.

Available options:

-h, --help          Print this help and exit
-v, --verbose       Print script debug info
-a, --all-in-one    Bake user-data and meta-data into the generated ISO. By default you will
                    need to boot systems with a CIDATA volume attached containing your
                    autoinstall user-data and meta-data files.
                    For more information see: https://ubuntu.com/server/docs/install/autoinstall-quickstart
-u, --user-data     Path to user-data file. Required if using -a
-m, --meta-data     Path to meta-data file. Will be an empty file if not specified and using -a
-k, --no-verify     Disable GPG verification of the source ISO file. By default SHA256SUMS and
                    SHA256SUMS.gpg in ${script_dir} will be used to verify the authenticity and integrity
                    of the source ISO file. If they are not present the latest daily SHA256SUMS will be
                    downloaded and saved in ${script_dir}. The Ubuntu signing key will be downloaded and
                    saved in a new keyring in ${script_dir}
-s, --source        Source ISO file. By default the latest daily ISO for Ubuntu 20.04 will be downloaded
                    and saved as ${script_dir}/ubuntu-original-$today.iso
                    That file will be used by default if it already exists.
-d, --destination   Destination ISO file. By default ${script_dir}/ubuntu-autoinstall-$today.iso will be
                    created, overwriting any existing file.
EOF
	exit
}

function parse_params() {
	# default values of variables set from params
	user_data_file=''
	meta_data_file=''
	source_iso="${script_dir}/ubuntu-original-$today.iso"
	destination_iso="${script_dir}/ubuntu-autoinstall-$today.iso"
	gpg_verify=1
	all_in_one=0

	while :; do
		case "${1-}" in
		-h | --help) usage ;;
		-v | --verbose) set -x ;;
		-a | --all-in-one) all_in_one=1 ;;
		-k | --no-verify) gpg_verify=0 ;;
		-u | --user-data)
			user_data_file="${2-}"
			shift
			;;
		-s | --source)
			source_iso="${2-}"
			shift
			;;
		-d | --destination)
			destination_iso="${2-}"
			shift
			;;
		-m | --meta-data)
			meta_data_file="${2-}"
			shift
			;;
		-?*) die "Unknown option: $1" ;;
		*) break ;;
		esac
		shift
	done

	log "👶 Starting up..."

	# check required params and arguments
	if [ ${all_in_one} -ne 0 ]; then
		[[ -z "${user_data_file}" ]] && die "💥 user-data file was not specified."
		[[ ! -f "$user_data_file" ]] && die "💥 user-data file could not be found."
		[[ -n "${meta_data_file}" ]] && [[ ! -f "$meta_data_file" ]] && die "💥 meta-data file could not be found."
	fi

	if [ "${source_iso}" != "${script_dir}/ubuntu-original-$today.iso" ]; then
		[[ ! -f "${source_iso}" ]] && die "💥 Source ISO file could not be found."
	fi

	destination_iso=$(realpath "${destination_iso}")
	source_iso=$(realpath "${source_iso}")

	return 0
}

ubuntu_gpg_key_id="843938DF228D22F7B3742BC0D94AA3F0EFE21092"

parse_params "$@"

tmpdir=$(mktemp -d)

if [[ ! "$tmpdir" || ! -d "$tmpdir" ]]; then
	die "💥 Could not create temporary working directory."
else
	log "📁 Created temporary working directory $tmpdir"
fi

log "🔎 Checking for required utilities..."
[[ ! -f "/usr/bin/7z" ]] && die "💥 7z is not installed."
[[ ! -f "/usr/bin/sed" ]] && die "💥 sed is not installed."
[[ ! -f "/usr/bin/curl" ]] && die "💥 curl is not installed."
[[ ! -f "/usr/bin/mkisofs" ]] && die "💥 mkisofs is not installed."
[[ ! -f "/usr/bin/gpg" ]] && die "💥 gpg is not installed."
log "👍 All required utilities are installed."

if [ ! -f "${source_iso}" ]; then
	log "🌎 Downloading current daily ISO image for Ubuntu 20.04 Focal Fossa..."
	/usr/bin/curl -NsSL "https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/focal-live-server-amd64.iso" -o "${source_iso}"
	log "👍 Downloaded and saved to ${source_iso}"
else
	log "☑️ Using existing ${source_iso} file."
fi

if [ ${gpg_verify} -eq 1 ]; then
	if [ ! -f "${script_dir}/SHA256SUMS" ]; then
		log "🌎 Downloading SHA256SUMS & SHA256SUMS.gpg files..."
		/usr/bin/curl -NsSL "https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/SHA256SUMS" -o "${script_dir}/SHA256SUMS"
		/usr/bin/curl -NsSL "https://cdimage.ubuntu.com/ubuntu-server/focal/daily-live/current/SHA256SUMS.gpg" -o "${script_dir}/SHA256SUMS.gpg"
	else
		log "☑️ Using existing SHA256SUMS & SHA256SUMS.gpg files."
	fi

	if [ ! -f "${script_dir}/${ubuntu_gpg_key_id}.keyring" ]; then
		log "🌎 Downloading and saving Ubuntu signing key..."
		/usr/bin/gpg -q --no-default-keyring --keyring "${script_dir}/${ubuntu_gpg_key_id}.keyring" --keyserver "hkp://keyserver.ubuntu.com" --recv-keys "${ubuntu_gpg_key_id}"
		log "👍 Downloaded and saved to ${script_dir}/${ubuntu_gpg_key_id}.keyring"
	else
		log "☑️ Using existing Ubuntu signing key saved in ${script_dir}/${ubuntu_gpg_key_id}.keyring"
	fi

	log "🔐 Verifying ${source_iso} integrity and authenticity..."
	/usr/bin/gpg -q --keyring "${script_dir}/${ubuntu_gpg_key_id}.keyring" --verify "${script_dir}/SHA256SUMS.gpg" "${script_dir}/SHA256SUMS" 2>/dev/null
	if [ $? -ne 0 ]; then
		rm -f "${script_dir}/${ubuntu_gpg_key_id}.keyring~"
		die "👿 Verification of SHA256SUMS signature failed."
	fi

	rm -f "${script_dir}/${ubuntu_gpg_key_id}.keyring~"
	digest=$(sha256sum "${source_iso}" | cut -f1 -d ' ')
	set +e
	/usr/bin/grep -Fq "$digest" "${script_dir}/SHA256SUMS"
	if [ $? -eq 0 ]; then
		log "👍 Verification succeeded."
		set -e
	else
		die "👿 Verification of ISO digest failed."
	fi
else
	log "🤞 Skipping verification of source ISO."
fi
log "🔧 Extracting ISO image..."
/usr/bin/7z -y x "${source_iso}" -o"$tmpdir" >/dev/null
rm -rf "$tmpdir/"'[BOOT]'
log "👍 Extracted to $tmpdir"

log "🧩 Adding autoinstall parameter to kernel command line..."
/usr/bin/sed -i -e 's/---/ autoinstall  ---/g' "$tmpdir/isolinux/txt.cfg"
/usr/bin/sed -i -e 's/---/ autoinstall  ---/g' "$tmpdir/boot/grub/grub.cfg"
/usr/bin/sed -i -e 's/---/ autoinstall  ---/g' "$tmpdir/boot/grub/loopback.cfg"
log "👍 Added parameter to UEFI and BIOS kernel command lines."

if [ ${all_in_one} -eq 1 ]; then
	log "🧩 Adding user-data and meta-data files..."
	mkdir "$tmpdir/nocloud"
	cp "$user_data_file" "$tmpdir/nocloud/user-data"
	if [ -n "${meta_data_file}" ]; then
		cp "$meta_data_file" "$tmpdir/nocloud/meta-data"
	else
		touch "$tmpdir/nocloud/meta-data"
	fi
	/usr/bin/sed -i -e 's,---, ds=nocloud;s=/cdrom/nocloud/  ---,g' "$tmpdir/isolinux/txt.cfg"
	/usr/bin/sed -i -e 's,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g' "$tmpdir/boot/grub/grub.cfg"
	/usr/bin/sed -i -e 's,---, ds=nocloud\\\;s=/cdrom/nocloud/  ---,g' "$tmpdir/boot/grub/loopback.cfg"
	log "👍 Added data and configured kernel command line."
fi

log "👷 Updating $tmpdir/md5sum.txt with hashes of modified files..."
md5=$(/usr/bin/md5sum "$tmpdir/boot/grub/grub.cfg" | /usr/bin/cut -f1 -d ' ')
/usr/bin/sed -i -e 's,^.*[[:space:]] ./boot/grub/grub.cfg,'"$md5"'  ./boot/grub/grub.cfg,' "$tmpdir/md5sum.txt"
md5=$(/usr/bin/md5sum "$tmpdir/boot/grub/loopback.cfg" | /usr/bin/cut -f1 -d ' ')
/usr/bin/sed -i -e 's,^.*[[:space:]] ./boot/grub/loopback.cfg,'"$md5"'  ./boot/grub/loopback.cfg,' "$tmpdir/md5sum.txt"
log "👍 Updated hashes."

log "📦 Repackaging extracted files into an ISO image..."
cd "$tmpdir"
/usr/bin/mkisofs -quiet -D -r -V "ubuntu-autoinstall-$today" -cache-inodes -J -l -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table -eltorito-alt-boot -e boot/grub/efi.img -no-emul-boot -o "${destination_iso}" .
cd "$OLDPWD"
log "👍 Repackaged into ${destination_iso}"

die "✅ Completed." 0
