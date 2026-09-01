#!/bin/bash
#
# BoosterSimApp release pipeline:
#   archive -> Developer-ID export -> zip -> notarize -> staple -> DMG
#
# Credential-free dry run (archive/export/zip/DMG only):
#   scripts/build-release.sh --skip-notarization
#
# Full run (requires a stored notarytool keychain profile; see
# docs/deployment-guide.md "One-time credential setup"):
#   scripts/build-release.sh
#
# SECURITY: no credentials, tokens, or passwords live in this script —
# notarization reads the keychain profile referenced by NAME only
# ($NOTARY_PROFILE). Storing the profile is interactive and human-owned:
#
#   xcrun notarytool store-credentials booster-notary \
#     --apple-id <Apple ID> --team-id K2TYLYAWMK \
#     --password <app-specific password>

set -euo pipefail

# Run from the repo root regardless of the caller's cwd.
cd "$(dirname "$0")/.."

# ---------------------------------------------------------------------------
# Configuration (env-overridable)
# ---------------------------------------------------------------------------
PROJECT="${PROJECT:-BoosterSimApp.xcodeproj}"
SCHEME="${SCHEME:-BoosterSimApp}"
CONFIGURATION="${CONFIGURATION:-Release}"
BUILD_DIR="${BUILD_DIR:-build}"
NOTARY_PROFILE="${NOTARY_PROFILE:-booster-notary}"

SKIP_NOTARIZATION=0
for arg in "$@"; do
  case "$arg" in
    --skip-notarization) SKIP_NOTARIZATION=1 ;;
    *)
      echo "Usage: $0 [--skip-notarization]" >&2
      exit 1
      ;;
  esac
done

ARCHIVE_PATH="$BUILD_DIR/BoosterSimApp.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP_PATH="$EXPORT_DIR/BoosterSimApp.app"
ZIP_PATH="$BUILD_DIR/BoosterSimApp.zip"
DMG_PATH="$BUILD_DIR/BoosterSim.dmg"

echo "=============================================================="
echo " BoosterSimApp release pipeline"
echo "   project:        $PROJECT"
echo "   scheme:         $SCHEME ($CONFIGURATION)"
echo "   build dir:      $BUILD_DIR"
echo "   notary profile: $NOTARY_PROFILE"
echo "=============================================================="

# ---------------------------------------------------------------------------
# Stage 0: Pre-build the iOS Connect framework
# ---------------------------------------------------------------------------
# The app target's "Build iOS Framework & Copy" script phase copies
# BoosterSimConnect.framework from ${BUILD_DIR}/${CONFIGURATION}-iphonesimulator
# when present; otherwise it attempts a nested xcodebuild *inside* the archive,
# whose Clang scanner collides with the archive's generated module maps
# (redefinition of module 'PulseObjCHelpers') and fails the archive with exit 65.
# Building the framework first (the project's documented convention — STATE.md
# Phase 5) keeps the app script phase on its copy-only branch.
#
# The archive action rewrites BUILD_DIR to its own ArchiveIntermediates tree and
# wipes it at start, so the override below pins BOTH stages to the scheme's
# shared products dir — the one place the script phase's lookup can find the
# pre-built framework.
PRODUCTS_DIR="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | awk -F' = ' '/^[[:space:]]+BUILD_DIR =/{print $2; exit}')"
if [ -z "$PRODUCTS_DIR" ]; then
  echo "ERROR: could not resolve BUILD_DIR via -showBuildSettings" >&2
  exit 1
fi

echo ""
echo "==> [0/5] Pre-build BoosterSimConnect (iphonesimulator)"
xcodebuild \
  -project "$PROJECT" \
  -scheme BoosterSimConnect \
  -configuration "$CONFIGURATION" \
  -sdk iphonesimulator \
  BUILD_DIR="$PRODUCTS_DIR" \
  build

# ---------------------------------------------------------------------------
# Stage 1: Archive
# ---------------------------------------------------------------------------
echo ""
echo "==> [1/5] Archive"
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  BUILD_DIR="$PRODUCTS_DIR"

# ---------------------------------------------------------------------------
# Stage 2: Export (the .app is re-signed Developer ID here)
# ---------------------------------------------------------------------------
echo ""
echo "==> [2/5] Export (Developer ID re-sign via ExportOptions.plist)"
rm -rf "$EXPORT_DIR"
mkdir -p "$EXPORT_DIR"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_DIR" \
  -exportOptionsPlist ExportOptions.plist

# ---------------------------------------------------------------------------
# Stage 3: Zip (notarytool submission format)
# ---------------------------------------------------------------------------
echo ""
echo "==> [3/5] Zip for notarization"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# ---------------------------------------------------------------------------
# Stage 4: Notarize + staple (skipped with --skip-notarization)
# ---------------------------------------------------------------------------
echo ""
if [ "$SKIP_NOTARIZATION" -eq 1 ]; then
  echo "==> [4/5] Notarization SKIPPED (--skip-notarization): no ticket, no staple"
else
  echo "==> [4/5] Notarize (keychain profile: $NOTARY_PROFILE) + staple"
  # Fail fast when the keychain profile is absent — never prompt, never embed.
  if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "ERROR: notarytool keychain profile '$NOTARY_PROFILE' not found or unusable." >&2
    echo "Store it once, interactively (human-only step):" >&2
    echo "" >&2
    echo "  xcrun notarytool store-credentials $NOTARY_PROFILE \\" >&2
    echo "    --apple-id <Apple ID> --team-id K2TYLYAWMK \\" >&2
    echo "    --password <app-specific password>" >&2
    exit 1
  fi
  xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP_PATH"
  xcrun stapler validate "$APP_PATH"
fi

# ---------------------------------------------------------------------------
# Stage 5: DMG
# ---------------------------------------------------------------------------
echo ""
echo "==> [5/5] DMG"
hdiutil create -volname "BoosterSim" \
  -srcfolder "$APP_PATH" \
  -ov -format UDZO \
  "$DMG_PATH"

# ---------------------------------------------------------------------------
# Artifacts
# ---------------------------------------------------------------------------
echo ""
echo "=============================================================="
echo " Release artifacts:"
echo "   $ARCHIVE_PATH"
echo "   $APP_PATH (Developer ID, team K2TYLYAWMK)"
if [ "$SKIP_NOTARIZATION" -eq 1 ]; then
  echo "   notarized + stapled: NO (--skip-notarization)"
else
  echo "   notarized + stapled: YES"
fi
echo "   $ZIP_PATH"
echo "   $DMG_PATH"
echo "=============================================================="
