#!/usr/bin/env bash
# Build and ad-hoc sign AI Usage.app into .derivedData/.../Release
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="AI Usage"
BUNDLE_ID="com.thangdang.AIUsage"
WIDGET_ID="com.thangdang.AIUsage.widget"
DERIVED="$ROOT/.derivedData"
export BUILT_APP="$DERIVED/Build/Products/Release/${APP_NAME}.app"
WIDGET="$BUILT_APP/Contents/PlugIns/AIUsageWidget.appex"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -x "$DEVELOPER_DIR/usr/bin/xcodebuild" ]]; then
  echo "Xcode not found at $DEVELOPER_DIR" >&2
  exit 1
fi

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required. Install with: brew install xcodegen" >&2
  exit 1
fi

echo "==> Generate Xcode project"
xcodegen generate

echo "==> Build Release"
xcodebuild \
  -scheme AIUsage \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  ENABLE_DEBUG_DYLIB=NO \
  build

echo "==> Ad-hoc sign"
codesign --force --sign - \
  --identifier "$WIDGET_ID" \
  --entitlements "$ROOT/AIUsageWidget/AIUsageWidget.entitlements" \
  "$WIDGET"
codesign --force --sign - \
  --identifier "$BUNDLE_ID" \
  --entitlements "$ROOT/AIUsage/AIUsage.entitlements" \
  "$BUILT_APP"

echo "Built $BUILT_APP"
