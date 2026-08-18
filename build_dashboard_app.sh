#!/bin/bash
# ============================================================================
#  Đóng gói Account Dock thành app macOS thật (.app)
#  Dùng: ./build_dashboard_app.sh
# ============================================================================
set -euo pipefail

NAME="Account Dock"
BID="local.accountdock"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
APP="/Applications/$NAME.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

command -v swiftc >/dev/null || { echo "Cần Xcode Command Line Tools (swiftc)."; exit 1; }

echo "=== $NAME ==="

# 1. Compile universal (arm64 + x86_64) để máy Intel cũng chạy được.
#    Chỉ build arm64 thì bạn bè dùng Mac Intel mở lên báo lỗi không mở được.
echo "  compile..."
SRC=("$SRCDIR/AccountDock.swift" "$SRCDIR/AccountDockHTML.swift")
SLICES=()
for arch in arm64 x86_64; do
  if swiftc -O -parse-as-library -target "$arch-apple-macos13.0" \
       -o "$TMP/AccountDock-$arch" "${SRC[@]}" \
       -framework AppKit -framework WebKit 2>"$TMP/err-$arch"; then
    SLICES+=("$TMP/AccountDock-$arch")
    echo "    $arch OK"
  else
    echo "    $arch BỎ QUA ($(head -1 "$TMP/err-$arch" | cut -c1-60))"
  fi
done
[ ${#SLICES[@]} -eq 0 ] && { echo "Không compile được kiến trúc nào."; exit 1; }
lipo -create "${SLICES[@]}" -output "$TMP/AccountDock"

# 2. Icon: squircle xanh + 3 chấm (nhiều tài khoản)
cat > "$TMP/icon.swift" <<'ICON'
import AppKit
let S: CGFloat = 1024
let img = NSImage(size: NSSize(width: S, height: S))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext
let inset = S * 0.055
let rect = CGRect(x: inset, y: inset, width: S - inset*2, height: S - inset*2)
let path = NSBezierPath(roundedRect: rect, xRadius: S*0.225, yRadius: S*0.225)
ctx.saveGState()
path.addClip()
let grad = NSGradient(colors: [NSColor(srgbRed:0.204,green:0.353,blue:0.98,alpha:1),
                               NSColor(srgbRed:0.086,green:0.212,blue:0.71,alpha:1)])!
grad.draw(in: rect, angle: -90)
ctx.restoreGState()
// 3 chấm: 1 lớn + 2 nhỏ, gợi ý nhiều tài khoản xếp chồng
let cy = S * 0.5
for (dx, r, a) in [(-0.20, 0.088, 0.55), (0.0, 0.125, 1.0), (0.20, 0.088, 0.55)] as [(CGFloat,CGFloat,CGFloat)] {
    let c = CGPoint(x: S*0.5 + S*dx, y: cy)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: a))
    ctx.fillEllipse(in: CGRect(x: c.x - S*r, y: c.y - S*r, width: S*r*2, height: S*r*2))
}
// thanh dock dưới
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.85))
let bw = S*0.44, bh = S*0.055
ctx.addPath(CGPath(roundedRect: CGRect(x: (S-bw)/2, y: S*0.265, width: bw, height: bh),
                   cornerWidth: bh/2, cornerHeight: bh/2, transform: nil))
ctx.fillPath()
img.unlockFocus()
let tiff = img.tiffRepresentation!
let png = NSBitmapImageRep(data: tiff)!.representation(using: .png, properties: [:])!
try! png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
ICON
swiftc -O -o "$TMP/mkicon" "$TMP/icon.swift" 2>/dev/null
"$TMP/mkicon" "$TMP/icon.png"

SET="$TMP/AppIcon.iconset"; mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -s format png -z $s $s "$TMP/icon.png" --out "$SET/icon_${s}x${s}.png" >/dev/null 2>&1
  sips -s format png -z $((s*2)) $((s*2)) "$TMP/icon.png" --out "$SET/icon_${s}x${s}@2x.png" >/dev/null 2>&1
done
iconutil -c icns "$SET" -o "$TMP/AppIcon.icns"
echo "  icon xong"

# 3. Dựng bundle
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TMP/AccountDock" "$APP/Contents/MacOS/$NAME"
cp "$TMP/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# script build đi kèm để nút "Build lại" hoạt động dù app đứng một mình
for f in build_chrome_apps.sh build_telegram_apps.sh make_icon.swift; do
  [ -f "$SRCDIR/$f" ] && cp "$SRCDIR/$f" "$APP/Contents/Resources/"
done
chmod +x "$APP/Contents/Resources/"*.sh 2>/dev/null || true

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleIdentifier</key><string>$BID</string>
  <key>CFBundleExecutable</key><string>$NAME</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key>
  <string>Để thoát các app tài khoản khi bạn bấm nút Thoát.</string>
</dict></plist>
PLIST

# 4. Ký ad-hoc
xattr -cr "$APP" 2>/dev/null || true
codesign --force --sign - --options runtime "$APP" >/dev/null 2>&1

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f "$APP" >/dev/null 2>&1 || true

echo "  sign : $(codesign -dv "$APP" 2>&1 | grep -o 'flags=[^ ]*')"
echo "  xong : $APP"
echo
echo "Mở bằng Spotlight (⌘Space → 'Account Dock') hoặc:  open -a \"$NAME\""
