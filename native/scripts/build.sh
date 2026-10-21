#!/bin/zsh
set -eu
sprig_root="$(cd "$(dirname "$0")/../.." && pwd)"
sprig_version="${SPRIG_VERSION:-0.3.12}"
sprig_arch="${SPRIG_ARCH:-$(uname -m)}"
sprig_derived="${TMPDIR:-/tmp}/tandemry-sprig-native-derived"
cd "$sprig_root"
xcodebuild -project native/Sprig.xcodeproj -scheme Sprig -configuration Release -destination "platform=macOS,arch=$sprig_arch" -derivedDataPath "$sprig_derived" ARCHS="$sprig_arch" ONLY_ACTIVE_ARCH=YES CODE_SIGNING_ALLOWED=NO build
if [[ "${1:-}" == "--package" ]]; then
  sprig_output="$sprig_root/releases/Sprig-native-$sprig_arch"
  sprig_appdir="${SPRIG_ARTIFACTS_DIR:-$HOME/.codex/artifacts/sprig-native-$sprig_version-$sprig_arch}"
  mkdir -p "$sprig_output" "$sprig_appdir"
  ditto --noextattr --norsrc "$sprig_derived/Build/Products/Release/Sprig.app" "$sprig_appdir/Sprig.app"
  xattr -cr "$sprig_appdir/Sprig.app"
  codesign --force --sign - --timestamp=none "$sprig_appdir/Sprig.app"
  codesign --verify --deep --strict "$sprig_appdir/Sprig.app"
  ditto -c -k --keepParent "$sprig_appdir/Sprig.app" "$sprig_output/Sprig-native-macOS-$sprig_arch-$sprig_version.zip"
  (cd "$sprig_output" && shasum -a 256 "Sprig-native-macOS-$sprig_arch-$sprig_version.zip") > "$sprig_output/SHA256SUMS.txt"
  echo "Packaged native Sprig: $sprig_appdir/Sprig.app"
fi
