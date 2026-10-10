#!/bin/zsh
# Regenerate the icon with: swift scripts/make-icon.swift App/Resources/AppIcon-1024.png, then rebuild the .icns.
# Builds "Not a Lawyer.app" into build/, with the law snapshot bundled.
# Signed ad hoc for running on this Mac; release signing and notarisation come in M5.
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release --package-path App --product NotALawyer
bin="$(swift build -c release --package-path App --show-bin-path)/NotALawyer"

app="build/Not a Lawyer.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/laws"
cp "$bin" "$app/Contents/MacOS/NotALawyer"
cp data/snapshot/*.xml data/snapshot/checked.txt "$app/Contents/Resources/laws/"
cp App/Resources/AppIcon.icns "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Not a Lawyer</string>
    <key>CFBundleDisplayName</key><string>Not a Lawyer</string>
    <key>CFBundleIdentifier</key><string>io.github.ingridstevens.notalawyer</string>
    <key>CFBundleExecutable</key><string>NotALawyer</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>26.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.reference</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSMicrophoneUsageDescription</key><string>To let you speak your question. Your voice is recognised on this Mac and never leaves it.</string>
    <key>NSSpeechRecognitionUsageDescription</key><string>To turn your spoken question into text, on this Mac only.</string>
</dict>
</plist>
PLIST

# A stable signing identity keeps macOS permissions (microphone, speech) between builds.
# Ad-hoc signing gives every build a new identity, so macOS asks again each time.
# To set one up once: Keychain Access → Certificate Assistant → Create a Certificate…,
# name "Not a Lawyer Development", type "Code Signing". Or set SIGN_IDENTITY yourself.
identity="${SIGN_IDENTITY:-Not a Lawyer Development}"
if security find-identity -p codesigning 2>/dev/null | grep -q "$identity"; then
    codesign --force --sign "$identity" "$app"
    echo "Signed with \"$identity\""
else
    codesign --force --sign - "$app"
    echo "Signed ad hoc (macOS will ask for permissions again after each build; see the comment in this script)"
fi
echo "Built $app"
