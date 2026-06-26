#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$ROOT_DIR/StickyKeys.xcodeproj"
SCHEME="${SCHEME:-StickyKeys}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_DIR="${DERIVED_DATA_DIR:-${TMPDIR:-/tmp}/StickyKeys-release-derived-data}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
PRODUCT_NAME="${PRODUCT_NAME:-StickyKeys}"
APP_PATH="$DERIVED_DATA_DIR/Build/Products/$CONFIGURATION/$PRODUCT_NAME.app"

cd "$ROOT_DIR"

mkdir -p "$DERIVED_DATA_DIR" "$DIST_DIR"

echo "Building $PRODUCT_NAME ($CONFIGURATION)..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination "platform=macOS" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  clean build \
  "$@"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: expected app was not built at: $APP_PATH" >&2
  exit 1
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
GIT_REF="$(git describe --tags --dirty --always 2>/dev/null || date +%Y%m%d%H%M%S)"

if [[ -n "$VERSION" && -n "$BUILD" ]]; then
  ZIP_BASENAME="$PRODUCT_NAME-$VERSION-$BUILD-$GIT_REF"
elif [[ -n "$VERSION" ]]; then
  ZIP_BASENAME="$PRODUCT_NAME-$VERSION-$GIT_REF"
else
  ZIP_BASENAME="$PRODUCT_NAME-$GIT_REF"
fi

ZIP_PATH="$DIST_DIR/$ZIP_BASENAME.zip"
rm -f "$ZIP_PATH"

echo "Verifying code signature..."
codesign --verify --deep --strict --verbose=2 "$APP_PATH"
codesign --display --verbose=2 "$APP_PATH" 2>&1 | sed -n 's/^Authority=/Authority: /p'

echo "Packaging $ZIP_PATH..."
(
  cd "$(dirname "$APP_PATH")"
  ditto -c -k --sequesterRsrc --keepParent "$(basename "$APP_PATH")" "$ZIP_PATH"
)

echo "Release artifact:"
echo "$ZIP_PATH"
