#!/bin/sh

set -eu

usage() {
    cat <<'USAGE'
Usage: script/audit_backup.sh <backup.routinabackup>

Runs an isolated semantic restore audit. The command does not open or modify
Routina's production, development, or CloudKit stores.
USAGE
}

if [ "$#" -eq 1 ] && { [ "$1" = "--help" ] || [ "$1" = "-h" ]; }; then
    usage
    exit 0
fi

if [ "$#" -ne 1 ]; then
    usage >&2
    exit 64
fi

backup_path=$1
if [ ! -d "$backup_path" ]; then
    echo "Backup package not found: $backup_path" >&2
    exit 66
fi

script_directory=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
project_directory=$(dirname -- "$script_directory")

cd "$project_directory"
exec swift run -q RoutinaBackupAudit "$backup_path"
