#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# shellcheck source=Scripts/build-release.sh
source "$ROOT/Scripts/build-release.sh"

APP_NAME="AI Usage"
VERSION="$(python3 - <<'PY'
import pathlib, re
text = pathlib.Path("project.yml").read_text()
match = re.search(r'MARKETING_VERSION:\s*"([^"]+)"', text)
print(match.group(1) if match else "1.0.0")
PY
)"
DIST="$ROOT/dist"
STAGE="$DIST/dmg-root"
VOL="AI Usage"
DMG="$DIST/AI-Usage-${VERSION}.dmg"
TMP_DMG="$DIST/AI-Usage-rw.dmg"

echo "==> Stage DMG contents"
rm -rf "$STAGE" "$DMG" "$TMP_DMG"
mkdir -p "$STAGE"
cp -R "$BUILT_APP" "$STAGE/${APP_NAME}.app"
ln -s /Applications "$STAGE/Applications"
xattr -cr "$STAGE/${APP_NAME}.app" 2>/dev/null || true

echo "==> Create compressed disk image"
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  -imagekey zlib-level=9 \
  -fs HFS+ \
  "$DMG"

rm -rf "$STAGE"
echo
echo "DMG: $DMG"
ls -lh "$DMG"
echo
echo "Open with:  open \"$DMG\""
echo "Drag AI Usage into Applications. First launch: right-click → Open (ad-hoc signed)."
