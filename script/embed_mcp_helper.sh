#!/bin/sh

set -eu

scratch_path="$DERIVED_FILE_DIR/RoutinaAIMCPHelper"
destination_directory="$TARGET_BUILD_DIR/$CONTENTS_FOLDER_PATH/Helpers"
destination="$destination_directory/RoutinaAIMCPServer"

swift build \
    --package-path "$SRCROOT" \
    --scratch-path "$scratch_path" \
    --configuration release \
    --product RoutinaAIMCPServer

binary_directory=$(swift build \
    --package-path "$SRCROOT" \
    --scratch-path "$scratch_path" \
    --configuration release \
    --show-bin-path)

mkdir -p "$destination_directory"
install -m 755 "$binary_directory/RoutinaAIMCPServer" "$destination"

if [ "${CODE_SIGNING_ALLOWED:-NO}" = "YES" ]; then
    signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:--}"
    codesign --force --sign "$signing_identity" --options runtime "$destination"
fi
