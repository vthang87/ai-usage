#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# shellcheck source=Scripts/build-release.sh
source "$ROOT/Scripts/build-release.sh"

APP_NAME="AI Usage"
BUNDLE_ID="com.thangdang.AIUsage"
WIDGET_ID="com.thangdang.AIUsage.widget"
INSTALL_APP="/Applications/${APP_NAME}.app"
USER_APP="$HOME/Applications/${APP_NAME}.app"

echo "==> Stop running copies"
osascript >/dev/null 2>&1 <<'APPLESCRIPT' || true
tell application "System Events"
  if exists process "Xcode" then
    tell process "Xcode"
      try
        click menu item "Stop" of menu "Product" of menu bar 1
      end try
    end tell
  end if
end tell
APPLESCRIPT
killall "$APP_NAME" 2>/dev/null || true
killall AIUsageWidget 2>/dev/null || true
sleep 1

# Keep a single install in /Applications so Apps/Launchpad don't list duplicates.
if [ -d "$USER_APP" ]; then
  echo "==> Remove leftover ~/Applications copy"
  rm -rf "$USER_APP"
fi

echo "==> Install to /Applications (admin password if asked)"
OWNER="$(id -un)"
osascript <<EOF
do shell script "rm -rf " & quoted form of "$INSTALL_APP" & " && cp -R " & quoted form of "$BUILT_APP" & " " & quoted form of "$INSTALL_APP" & " && chown -R " & quoted form of "$OWNER:staff" & " " & quoted form of "$INSTALL_APP" & " && xattr -cr " & quoted form of "$INSTALL_APP" with administrator privileges
EOF

echo "==> Register widget"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$INSTALL_APP"
pluginkit -a "$INSTALL_APP/Contents/PlugIns/AIUsageWidget.appex" >/dev/null 2>&1 || true
pluginkit -e use -i "$WIDGET_ID" >/dev/null 2>&1 || true
rm -rf "$HOME/Library/Containers/$WIDGET_ID/Data/SystemData/com.apple.chrono" 2>/dev/null || true
killall chronod 2>/dev/null || true

echo "==> Launch"
open "$INSTALL_APP"

echo "Installed ${APP_NAME} to ${INSTALL_APP}"
echo "Add the widget: right-click Desktop → Edit Widgets → AI Usage"
