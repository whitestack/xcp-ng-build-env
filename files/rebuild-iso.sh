#!/bin/bash

set -eE
set -o pipefail

die() {
    echo >&2
    echo >&2 "ERROR: $*"
    echo >&2
    exit 1
}

die_usage() {
    usage >&2
    die "$*"
}

download_iso() {
    local iso_url="$1"
    local output_dir="$2"
    local iso_index=$(dirname "${iso_url}")
    local output_file=$(basename "${iso_url}")

    if [[ -z "${iso_url}" || -z "${output_dir}" ]]; then
        echo "Usage: download_iso <iso_url> <output_dir>"
        return 1
    fi
    [ -d "${output_dir}" ] || die "'${output_dir}' is not a directory"

    echo "Download from URL: ${iso_url}"
    curl -L -# --fail -o "${output_dir}/${output_file}" "${iso_url}"
    test -r "${output_dir}/${output_file}" || die "Failed to download ISO."

    echo -e "\nChecksum validation:"
    local original_checksum=$(curl -L -s --fail "${iso_index}/SHA256SUMS" | grep "${output_file}" | awk '{print $1}')
    local actual_checksum=$(sha256sum "${output_dir}/${output_file}" | awk '{print $1}')
    echo "Original: ${original_checksum}"
    echo "Actual:   ${actual_checksum}"
    [[ "${actual_checksum}" == "${original_checksum}" ]] || die "Checksum validation failed."
    
    LTS_ISO="${output_dir}/${output_file}"
    VERSION=$(dirname "${iso_index}")
}

usage() {
    cat <<EOF
Usage: $0 [arguments]

Arguments:
    -i|--iso-url <url>          (mandatory) upstream ISO URL
    -r|--rpm-dir <dir>          (mandatory) custom RPM packages directory
    -o|--out-dir <dir>          (mandatory) directory to place rebuild ISO
    --force-overwrite           don't abort if output file already exists
    --verbose                   be talkative
EOF
}

VERBOSE=
VERSION=
ISO_URL=
RPM_DIR=
OUT_DIR=
LTS_ISO=
BUILD_ISO=
while [ $# -ge 1 ]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=-v
            ;;
        -i|--iso-url)
            [ $# -ge 2 ] || die_usage "$1 needs an argument"
            ISO_URL="$2"
            shift
            ;;
        -r|--rpm-dir)
            [ $# -ge 2 ] || die_usage "$1 needs an argument"
            RPM_DIR="$2"
            shift
            ;;
        -o|--out-dir)
            [ $# -ge 2 ] || die_usage "$1 needs an argument"
            OUT_DIR="$2"
            shift
            ;;
        -*)
            die_usage "unknown flag '$1'"
            ;;
        *)
            break
            ;;
    esac
    shift
done

# Validations
[ -d "$RPM_DIR" ] || die "'$RPM_DIR' is not a directory"
[ -d "$OUT_DIR" ] || die "'$OUT_DIR' is not a directory"
[ -z "$VERBOSE" ] || set -x

cd $(dirname "$0")

command -v genisoimage >/dev/null || die "required tool not found: genisoimage"
command -v isohybrid >/dev/null || die "required tool not found: isohybrid (syslinux)"
command -v createrepo_c >/dev/null || die "required tool not found: createrepo_c"

# Step 1 - Download LTS ISO
echo -e "\nStep 1 - Downloading ISO..."
download_iso "${ISO_URL}" "${OUT_DIR}"

# Step 2 - Mount LTS ISO
echo -e "\nStep 2 - Mounting ISO..."
ISO_DIR=${OUT_DIR}/build
mkdir -p ${OUT_DIR}/tmp
mount -o loop ${LTS_ISO} ${OUT_DIR}/tmp
cp -a ${OUT_DIR}/tmp ${ISO_DIR}
umount ${OUT_DIR}/tmp && rm -rf ${OUT_DIR}/tmp
chmod a+w ${ISO_DIR} -R

# Step 3 - Patch
echo -e "\nStep 3 - Patching RPM packages..."
rm -rf ${ISO_DIR}/repodata
cp ${RPM_DIR}/* ${ISO_DIR}/Packages/.
createrepo_c ${ISO_DIR} -o ${ISO_DIR}

# Step 4 - Rebuild
echo -e "\nStep 4 - Building ISO..."
BUILD_ISO="${OUT_DIR}/xcp-ng-${VERSION}-ws.iso"
genisoimage \
    -o "${BUILD_ISO}" \
    ${VERBOSE:- -quiet} \
    -r -J --joliet-long -V "XCP-ng ${VERSION}" -input-charset utf-8 \
    -c boot/isolinux/boot.cat -b boot/isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot --efi-boot boot/efiboot.img \
    -no-emul-boot \
    ${ISO_DIR}
isohybrid ${VERBOSE} --uefi "$BUILD_ISO"
