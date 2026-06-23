#!/usr/bin/env bash
#
# build-dmg.sh — Build, sign, notarize, and staple a distributable DMG for Twine.
#
# This script:
#   1. Regenerates the Xcode project with `xcodegen generate`
#   2. Archives the Release build with hardened runtime + Developer ID signing
#   3. Exports the .app from the archive (method "developer-id")
#   4. Packages the .app into a DMG (with an /Applications symlink)
#   5. Notarizes the DMG via `xcrun notarytool` (keychain profile "blip-notary")
#   6. Staples the notarization ticket to the DMG
#   7. Verifies the result with `spctl`
#
# Output: build/Twine-<version>.dmg
#
# ----------------------------------------------------------------------------
# IMPORTANT: This file must be executable. Run once after checkout:
#     chmod +x scripts/build-dmg.sh
# ----------------------------------------------------------------------------
#
# Prerequisites (see docs/NOTARIZATION.md):
#   - Xcode + command line tools, xcodegen, hdiutil (built in)
#   - "Developer ID Application: Ivan Kuria (347LA37C2B)" in the login keychain
#   - A stored notarytool keychain profile named "blip-notary":
#       xcrun notarytool store-credentials "blip-notary" ...
#
# Usage:
#     scripts/build-dmg.sh [VERSION]
#   If VERSION is omitted, it is read from MARKETING_VERSION in project.yml.
#
set -euo pipefail

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
PROJECT_NAME="Twine"
SCHEME="Twine"
CONFIGURATION="Release"
PRODUCT_NAME="Twine"            # produces Twine.app
BUNDLE_ID="com.ivankuria.twine"
TEAM_ID="347LA37C2B"
SIGN_IDENTITY="Developer ID Application: Ivan Kuria (347LA37C2B)"
KEYCHAIN_PROFILE="blip-notary"

# Resolve project root (parent of this script's directory) so the script can
# be run from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

XCODEPROJ="${PROJECT_NAME}.xcodeproj"
BUILD_DIR="${ROOT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_DIR="${BUILD_DIR}/export"
EXPORT_OPTIONS_PLIST="${BUILD_DIR}/ExportOptions.plist"
APP_PATH="${EXPORT_DIR}/${PRODUCT_NAME}.app"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
step()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
info()  { printf '    %s\n' "$*"; }
fail()  { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# ----------------------------------------------------------------------------
# Resolve VERSION (arg overrides project.yml)
# ----------------------------------------------------------------------------
VERSION="${1:-}"
if [[ -z "${VERSION}" ]]; then
  if [[ -f "${ROOT_DIR}/project.yml" ]]; then
    # Grab MARKETING_VERSION: "x.y.z" from project.yml (strip quotes/space).
    VERSION="$(grep -E 'MARKETING_VERSION:' "${ROOT_DIR}/project.yml" \
      | head -n1 \
      | sed -E 's/.*MARKETING_VERSION:[[:space:]]*"?([^"#]+)"?.*/\1/' \
      | tr -d '[:space:]')"
  fi
fi
[[ -n "${VERSION}" ]] || fail "Could not determine VERSION. Pass it as an argument: scripts/build-dmg.sh 1.2.3"

DMG_PATH="${BUILD_DIR}/${PROJECT_NAME}-${VERSION}.dmg"

# ----------------------------------------------------------------------------
# Preflight checks
# ----------------------------------------------------------------------------
step "Preflight checks (Twine v${VERSION})"

command -v xcodegen >/dev/null 2>&1 || fail "xcodegen not found. Install with: brew install xcodegen"
command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild not found. Install Xcode and run: xcode-select --install"
command -v xcrun >/dev/null 2>&1 || fail "xcrun not found. Install Xcode command line tools."
command -v hdiutil >/dev/null 2>&1 || fail "hdiutil not found (should ship with macOS)."

# Confirm the Developer ID signing identity is present in a keychain.
if ! security find-identity -v -p codesigning 2>/dev/null | grep -qF "${SIGN_IDENTITY}"; then
  fail "Signing identity not found in keychain:
    \"${SIGN_IDENTITY}\"
  Import your Developer ID Application certificate (and its private key) into
  the login keychain, then verify with:
    security find-identity -v -p codesigning"
fi
info "Found signing identity: ${SIGN_IDENTITY}"

# Confirm the notarytool keychain profile exists.
# `notarytool history` against the profile is the cheapest way to validate it.
if ! xcrun notarytool history --keychain-profile "${KEYCHAIN_PROFILE}" >/dev/null 2>&1; then
  fail "notarytool keychain profile \"${KEYCHAIN_PROFILE}\" is missing or invalid.
  Create it once with (see docs/NOTARIZATION.md):
    xcrun notarytool store-credentials \"${KEYCHAIN_PROFILE}\" \\
      --apple-id \"<your-apple-id>\" \\
      --team-id \"${TEAM_ID}\" \\
      --password \"<app-specific-password>\""
fi
info "Found notarytool keychain profile: ${KEYCHAIN_PROFILE}"

# ----------------------------------------------------------------------------
# Clean & prepare
# ----------------------------------------------------------------------------
step "Preparing build directory"
rm -rf "${ARCHIVE_PATH}" "${EXPORT_DIR}" "${EXPORT_OPTIONS_PLIST}" "${DMG_PATH}"
mkdir -p "${BUILD_DIR}"

# ----------------------------------------------------------------------------
# Generate Xcode project
# ----------------------------------------------------------------------------
step "Generating Xcode project (xcodegen)"
xcodegen generate

# ----------------------------------------------------------------------------
# Archive (Release, hardened runtime, Developer ID signing)
# ----------------------------------------------------------------------------
step "Archiving ${SCHEME} (${CONFIGURATION})"
xcodebuild \
  -project "${XCODEPROJ}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIGURATION}" \
  -archivePath "${ARCHIVE_PATH}" \
  archive \
  CODE_SIGN_STYLE="Manual" \
  CODE_SIGN_IDENTITY="${SIGN_IDENTITY}" \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  ENABLE_HARDENED_RUNTIME="YES" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  | xcbeautify 2>/dev/null || true

[[ -d "${ARCHIVE_PATH}" ]] || fail "Archive failed: ${ARCHIVE_PATH} was not produced."
info "Archive created: ${ARCHIVE_PATH}"

# ----------------------------------------------------------------------------
# Export the .app (Developer ID)
# ----------------------------------------------------------------------------
step "Writing ExportOptions.plist"
cat > "${EXPORT_OPTIONS_PLIST}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${SIGN_IDENTITY}</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
PLIST
info "Wrote ${EXPORT_OPTIONS_PLIST}"

step "Exporting .app from archive"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTIONS_PLIST}" \
  | xcbeautify 2>/dev/null || true

[[ -d "${APP_PATH}" ]] || fail "Export failed: ${APP_PATH} was not produced."
info "Exported app: ${APP_PATH}"

# Sanity-check the signature on the exported app before packaging.
step "Verifying app signature (codesign)"
codesign --verify --strict --deep --verbose=2 "${APP_PATH}" \
  || fail "codesign verification failed on ${APP_PATH}"
info "App signature OK."

# ----------------------------------------------------------------------------
# Build the DMG
# ----------------------------------------------------------------------------
step "Creating DMG"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/twine-dmg.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

# Stage the app for drag-to-install.
cp -R "${APP_PATH}" "${STAGING_DIR}/"

make_dmg_hdiutil() {
  # hdiutil needs the Applications symlink staged ourselves.
  ln -sf /Applications "${STAGING_DIR}/Applications"
  hdiutil create \
    -volname "${PRODUCT_NAME} ${VERSION}" \
    -srcfolder "${STAGING_DIR}" \
    -ov \
    -format UDZO \
    "${DMG_PATH}"
}

if command -v create-dmg >/dev/null 2>&1; then
  info "Using create-dmg."
  # Detach any stale dmg volumes from a prior interrupted run (they cause an
  # "Applications: File exists" collision).
  for v in /Volumes/dmg.*; do
    [[ -e "$v" ]] && hdiutil detach "$v" -force >/dev/null 2>&1 || true
  done
  # NOTE: create-dmg adds its own /Applications drop link, so do NOT pre-create one.
  if ! create-dmg \
      --volname "${PRODUCT_NAME} ${VERSION}" \
      --app-drop-link 480 170 \
      --icon "${PRODUCT_NAME}.app" 160 170 \
      --window-size 640 360 \
      "${DMG_PATH}" \
      "${STAGING_DIR}"; then
    info "create-dmg failed; falling back to hdiutil."
    rm -f "${DMG_PATH}" "${BUILD_DIR}"/rw.*.dmg
    make_dmg_hdiutil || fail "hdiutil create failed."
  fi
else
  info "create-dmg not found; using hdiutil."
  make_dmg_hdiutil || fail "hdiutil create failed."
fi

[[ -f "${DMG_PATH}" ]] || fail "DMG was not produced: ${DMG_PATH}"
info "DMG created: ${DMG_PATH}"

# The DMG must itself be signed with the Developer ID so Gatekeeper trusts the
# container before staple (notarytool does not require this, but signing the
# DMG yields a cleaner spctl assessment).
step "Signing DMG"
codesign --sign "${SIGN_IDENTITY}" --timestamp "${DMG_PATH}" \
  || fail "Failed to codesign the DMG."
info "DMG signed."

# ----------------------------------------------------------------------------
# Notarize
# ----------------------------------------------------------------------------
step "Submitting DMG for notarization (this can take a few minutes)"
xcrun notarytool submit "${DMG_PATH}" \
  --keychain-profile "${KEYCHAIN_PROFILE}" \
  --wait \
  || fail "Notarization failed. Inspect the log with:
    xcrun notarytool log <submission-id> --keychain-profile \"${KEYCHAIN_PROFILE}\""
info "Notarization accepted."

# ----------------------------------------------------------------------------
# Staple
# ----------------------------------------------------------------------------
step "Stapling notarization ticket to DMG"
xcrun stapler staple "${DMG_PATH}" || fail "stapler staple failed."
xcrun stapler validate "${DMG_PATH}" || fail "stapler validate failed."
info "Ticket stapled and validated."

# ----------------------------------------------------------------------------
# Verify with Gatekeeper
# ----------------------------------------------------------------------------
step "Verifying with spctl"
if spctl -a -t open --context context:primary-signature -v "${DMG_PATH}"; then
  info "spctl assessment: ACCEPTED"
else
  fail "spctl assessment failed for ${DMG_PATH}"
fi

# ----------------------------------------------------------------------------
# Done
# ----------------------------------------------------------------------------
step "Done"
info "Distributable DMG: ${DMG_PATH}"
info "SHA-256 (for the Homebrew cask):"
shasum -a 256 "${DMG_PATH}"
