#!/usr/bin/env bash
set -euo pipefail

MODE="run"
FLAVOR="dev"
CONFIGURATION="${CONFIGURATION:-Debug}"

for arg in "$@"; do
  case "$arg" in
    run|--debug|debug|--logs|logs|--telemetry|telemetry|--verify|verify)
      MODE="$arg"
      ;;
    --dev|dev)
      FLAVOR="dev"
      ;;
    --prod|prod)
      FLAVOR="prod"
      ;;
    --release|release)
      CONFIGURATION="Release"
      ;;
    --debug-build|debug-build)
      CONFIGURATION="Debug"
      ;;
    *)
      echo "usage: $0 [run|--debug|--logs|--telemetry|--verify] [--dev|--prod] [--debug-build|--release]" >&2
      exit 2
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

case "$FLAVOR" in
  dev)
    SCHEME="RoutinaMacOSDev"
    APP_NAME="RoutinaMacOSDev"
    BUNDLE_ID="ir.hamedgh.Routinam.mac.dev"
    DEFAULT_DERIVED_DATA_DIR="$ROOT_DIR/.build/xcode-derived-data/macos-dev"
    ;;
  prod)
    SCHEME="RoutinaMacOSProd"
    APP_NAME="Routinam"
    BUNDLE_ID="ir.hamedgh.Routinam"
    DEFAULT_DERIVED_DATA_DIR="$ROOT_DIR/.build/xcode-derived-data/macos-prod"
    ;;
esac

DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-$DEFAULT_DERIVED_DATA_DIR}"
APP_BUNDLE="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$APP_NAME.app"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

build_app() {
  xcodebuild build -quiet \
    -project "$ROOT_DIR/RoutinaMacOS.xcodeproj" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_DIR"
}

stop_app() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
}

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    stop_app
    build_app
    open_app
    ;;
  --debug|debug)
    stop_app
    build_app
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    stop_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    stop_app
    build_app
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    stop_app
    build_app
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify] [--dev|--prod] [--debug-build|--release]" >&2
    exit 2
    ;;
esac
