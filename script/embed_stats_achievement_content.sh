#!/bin/sh

set -eu

source_path="$SRCROOT/SharedCore/Resources/en.lproj/StatsAchievementContentCatalog.json"
resource_directory="$TARGET_BUILD_DIR/$UNLOCALIZED_RESOURCES_FOLDER_PATH"
destination_path="$resource_directory/StatsAchievementContentCatalogFallback.json"

if [ ! -f "$source_path" ]; then
    echo "error: Missing Stats achievement content source: $source_path" >&2
    exit 1
fi

mkdir -p "$resource_directory"
cp "$source_path" "$destination_path"
