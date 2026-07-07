#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

PROJECT="${PROJECT:-Anywhere.xcodeproj}"
IOS_SCHEME="${IOS_SCHEME:-Anywhere}"
MACOS_SCHEME="${MACOS_SCHEME:-Anywhere}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/build}"
OUTPUT_DIR="${OUTPUT_DIR:-$ROOT_DIR/output}"

BUILD_IPA=false
BUILD_DMG=false
PRINT_VERSION=false

UNSIGNED_FLAGS=(
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
  DEVELOPMENT_TEAM=
  PROVISIONING_PROFILE_SPECIFIER=
)

usage() {
  cat <<'EOF'
Usage: build_nosign.sh [--ipa] [--dmg] [--print-version] [-h]

Build unsigned Anywhere artifacts without code signing.

Options:
  --ipa            Build unsigned iOS .ipa only
  --dmg            Build unsigned macOS .dmg only
  --print-version  Print MARKETING_VERSION and BUILD_NUMBER, then exit
  -h, --help       Show this help message

If neither --ipa nor --dmg is provided, both artifacts are built.

Environment variables:
  PROJECT          Xcode project path (default: Anywhere.xcodeproj)
  IOS_SCHEME       iOS scheme name (default: Anywhere)
  MACOS_SCHEME     macOS scheme name (default: Anywhere)
  CONFIGURATION    Build configuration (default: Release)
  DERIVED_DATA     Derived data path (default: ./build)
  OUTPUT_DIR       Output directory (default: ./output)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ipa)
      BUILD_IPA=true
      shift
      ;;
    --dmg)
      BUILD_DMG=true
      shift
      ;;
    --print-version)
      PRINT_VERSION=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

read_version() {
  local settings
  settings="$(xcodebuild -showBuildSettings \
    -project "$PROJECT" \
    -scheme "$IOS_SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=iOS' 2>/dev/null)"

  MARKETING_VERSION="$(echo "$settings" | awk -F' = ' '/ MARKETING_VERSION / { print $2; exit }')"
  BUILD_NUMBER="$(echo "$settings" | awk -F' = ' '/ CURRENT_PROJECT_VERSION / { print $2; exit }')"

  if [[ -z "${MARKETING_VERSION:-}" || -z "${BUILD_NUMBER:-}" ]]; then
    echo "Failed to read app version from Xcode build settings." >&2
    exit 1
  fi
}

artifact_basename() {
  echo "Anywhere-${MARKETING_VERSION}-${BUILD_NUMBER}-unsigned"
}

strip_code_signature() {
  local app_path="$1"

  find "$app_path" -name "_CodeSignature" -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "$app_path" -name "CodeResources" -type f -delete 2>/dev/null || true
}

package_ipa() {
  local app_path="$1"
  local ipa_path="$2"
  local payload_dir="$OUTPUT_DIR/Payload"

  rm -rf "$payload_dir"
  mkdir -p "$payload_dir"
  cp -R "$app_path" "$payload_dir/"

  rm -f "$ipa_path"
  (
    cd "$OUTPUT_DIR"
    zip -qr "$(basename "$ipa_path")" Payload
  )
  rm -rf "$payload_dir"
}

has_macos_destination() {
  xcodebuild \
    -project "$PROJECT" \
    -scheme "$MACOS_SCHEME" \
    -showdestinations 2>/dev/null | grep -q 'platform:macOS'
}

build_ios_ipa() {
  echo "==> Building unsigned iOS IPA"

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$IOS_SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=iOS' \
    -derivedDataPath "$DERIVED_DATA" \
    SWIFT_COMPILATION_MODE=incremental \
    "${UNSIGNED_FLAGS[@]}" \
    build

  local app_path="$DERIVED_DATA/Build/Products/Release-iphoneos/Anywhere.app"
  if [[ ! -d "$app_path" ]]; then
    echo "iOS app not found at: $app_path" >&2
    exit 1
  fi

  strip_code_signature "$app_path"

  local ipa_path="$OUTPUT_DIR/$(artifact_basename).ipa"
  package_ipa "$app_path" "$ipa_path"

  echo "==> Created $ipa_path"
}

build_macos_dmg() {
  echo "==> Building unsigned macOS DMG"

  if ! has_macos_destination; then
    cat >&2 <<EOF
No macOS build destination found for scheme '$MACOS_SCHEME'.

The current Xcode project does not expose a macOS target yet.
Add a macOS app target (or set MACOS_SCHEME to the correct scheme) before using --dmg.
EOF
    exit 1
  fi

  xcodebuild \
    -project "$PROJECT" \
    -scheme "$MACOS_SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination 'generic/platform=macOS' \
    -derivedDataPath "$DERIVED_DATA" \
    "${UNSIGNED_FLAGS[@]}" \
    build

  local app_path=""
  for candidate in \
    "$DERIVED_DATA/Build/Products/Release/Anywhere.app" \
    "$DERIVED_DATA/Build/Products/Release-macosx/Anywhere.app"; do
    if [[ -d "$candidate" ]]; then
      app_path="$candidate"
      break
    fi
  done

  if [[ -z "$app_path" ]]; then
    echo "macOS app not found under $DERIVED_DATA/Build/Products" >&2
    exit 1
  fi

  strip_code_signature "$app_path"

  local dmg_path="$OUTPUT_DIR/$(artifact_basename).dmg"
  rm -f "$dmg_path"
  hdiutil create \
    -volname "Anywhere" \
    -srcfolder "$app_path" \
    -ov \
    -format UDZO \
    "$dmg_path" >/dev/null

  echo "==> Created $dmg_path"
}

read_version

if $PRINT_VERSION; then
  echo "MARKETING_VERSION=$MARKETING_VERSION"
  echo "BUILD_NUMBER=$BUILD_NUMBER"
  exit 0
fi

if ! $BUILD_IPA && ! $BUILD_DMG; then
  BUILD_IPA=true
  BUILD_DMG=true
fi

mkdir -p "$OUTPUT_DIR"

if $BUILD_IPA; then
  build_ios_ipa
fi

if $BUILD_DMG; then
  build_macos_dmg
fi

echo "==> Done"