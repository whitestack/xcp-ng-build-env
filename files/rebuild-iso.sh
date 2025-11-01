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

usage() {
    cat <<EOF
Usage: $0 [arguments]

Arguments:
    -t|--target <version>   (mandatory) target version
    -r|--rpm-dir <dir>      (mandatory) custom RPM packages directory
    -o|--out-dir <dir>      (mandatory) directory to place rebuild ISO
    -v|--verbose            be talkative
EOF
}

VERBOSE=
VERSION=
RPM_DIR=
OUT_DIR=
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
        -t|--target)
            [ $# -ge 2 ] || die_usage "$1 needs an argument"
            TARGET="$2"
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
[ -n "${LTS_ISO_PATH}" ] && [ -f "${LTS_ISO_PATH}" ] || die "Path of LTS ISO must be set and should be an existing file"
[ -n "$TARGET" ] || die "Target version must be specified"
[ -d "$RPM_DIR" ] || die "'$RPM_DIR' is not a directory"
[ -d "$OUT_DIR" ] || die "'$OUT_DIR' is not a directory"
[ -z "$VERBOSE" ] || set -x

cd $(dirname "$0")

command -v genisoimage >/dev/null || die "required tool not found: genisoimage"
command -v isohybrid >/dev/null || die "required tool not found: isohybrid (syslinux)"
command -v createrepo_c >/dev/null || die "required tool not found: createrepo_c"
command -v bsdtar >/dev/null || die "required tool not found: createrepo_c"

# Step 1 - Extract ISO
echo -e "\nStep 1 - Extract ISO contents..."
ISO_CONTENT=${OUT_DIR}/content
mkdir -p ${ISO_CONTENT}
bsdtar -xf ${LTS_ISO_PATH} -C ${ISO_CONTENT}
chmod a+w ${ISO_CONTENT} -R
echo "Step 1 - Done."

# Step 2 - Patch
echo -e "\nStep 2 - Patching RPM packages..."
rm -rf ${ISO_CONTENT}/repodata
cp ${RPM_DIR}/* ${ISO_CONTENT}/Packages/.
createrepo_c ${ISO_CONTENT} -o ${ISO_CONTENT}
echo "Step 2 - Done."

# Step 3 - Rebuild
echo -e "\nStep 3 - Building ISO..."
BUILD_ISO="${OUT_DIR}/xcp_${TARGET}.iso"
genisoimage \
    -o "${BUILD_ISO}" \
    ${VERBOSE:- -quiet} \
    -r -J --joliet-long -V "XCP-ng ${VERSION}" -input-charset utf-8 \
    -c boot/isolinux/boot.cat -b boot/isolinux/isolinux.bin \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -eltorito-alt-boot --efi-boot boot/efiboot.img \
    -no-emul-boot \
    ${ISO_CONTENT}
isohybrid ${VERBOSE} --uefi "$BUILD_ISO"
echo "Step 3 - Done."
