#!/bin/bash
# Build PadderPro, re-sign with the stable "PadderPro Dev" certificate, and launch.
#
# Why: macOS TCC (Accessibility / Automation permissions) ties grants to the app's
# code-signature identity. Xcode debug builds are ad-hoc signed, whose hash changes
# every build, so previously-granted permissions are invalidated on each rebuild.
# Signing with a stable self-signed cert keeps the designated requirement constant,
# so permissions you grant once persist across rebuilds.

set -e
cd "$(dirname "$0")"

KC="$HOME/Library/Keychains/padderpro.keychain-db"
KCPASS="padderpro"
IDENTITY="PadderPro Dev"

echo "==> Building..."
xcodebuild -project Enjoy2.xcodeproj -scheme PadderPro -configuration Debug build \
  2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED" || true

APP=$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/Enjoy2-*/Build/Products/Debug/PadderPro.app | head -1)
echo "==> App: $APP"

echo "==> Re-signing with stable identity '$IDENTITY'..."
security unlock-keychain -p "$KCPASS" "$KC"
codesign --force --sign "$IDENTITY" --keychain "$KC" \
  --entitlements PadderPro.entitlements \
  "$APP"

echo "==> Signature:"
codesign -dvvv "$APP" 2>&1 | grep -E "Authority|Identifier" | head -3

echo "==> Launching..."
pkill PadderPro 2>/dev/null || true
sleep 1
open "$APP"
sleep 2
pgrep -la PadderPro
