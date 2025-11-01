#!/bin/bash

XCP_VERSION="8.3"
IMAGE_NAME="gcr.io/whitestack-private/nephora/xcp-ng-build-env"

# ISO
LTS_ISO_URL="https://storage.googleapis.com/storage.whitestack.com/nephora/base/xcp-ng-8.3.0-20250606.iso"
LTS_ISO_SHA="4d6f5a99da0d70920bc313470ad2b14decab66038f0863ca68a2b81126ee2977"
LTS_ISO_NAME=$(basename "${LTS_ISO_URL}")
ISO_DIR="iso"
