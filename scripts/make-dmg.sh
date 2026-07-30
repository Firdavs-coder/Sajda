#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DERIVED="${ROOT}/DerivedData"
APP="${DERIVED}/Build/Products/Release/Sajda.app"
STAGE="${ROOT}/dist/dmg-root"
DMG="${ROOT}/dist/Sajda.dmg"

echo "→ Building Release…"
xcodebuild -scheme Sajda \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=YES \
  build

if [[ ! -d "$APP" ]]; then
  echo "error: expected app at $APP" >&2
  exit 1
fi

echo "→ Staging DMG contents…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -sf /Applications "$STAGE/Applications"
xattr -cr "$STAGE/Sajda.app" 2>/dev/null || true

echo "→ Creating $DMG…"
hdiutil create -volname "Sajda" -srcfolder "$STAGE" -ov -format UDZO "$DMG"

echo "✓ Created: $DMG"
ls -lh "$DMG"
