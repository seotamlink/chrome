#!/bin/bash
# ============================================================================
#  Đóng gói Account Dock thành file .dmg để gửi cho người khác.
#
#  Mở ra là thấy icon app + mũi tên + thư mục Applications, kéo sang là xong —
#  đúng kiểu cài đặt quen thuộc trên macOS.
#
#  Dùng: ./make_dmg.sh
# ============================================================================
set -euo pipefail

NAME="Account Dock"
APP="/Applications/$NAME.app"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
DIST="$SRCDIR/dist"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 1.0.0)"
VOL="$NAME $VER"
DMG="$DIST/AccountDock-$VER.dmg"
TMP="$(mktemp -d)"
trap 'hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true; rm -rf "$TMP"' EXIT

[ -d "$APP" ] || { echo "Chưa có $APP. Chạy ./build_dashboard_app.sh trước."; exit 1; }
mkdir -p "$DIST"

# --- 1. Chuẩn bị nội dung ------------------------------------------------
STAGE="$TMP/stage"; mkdir -p "$STAGE/.background"
cp -R "$APP" "$STAGE/"
[ -f "$SRCDIR/chan_doan.sh" ] && cp "$SRCDIR/chan_doan.sh" "$STAGE/" && chmod +x "$STAGE/chan_doan.sh"
ln -s /Applications "$STAGE/Applications"
STAGED="$STAGE/$NAME.app"

# Gỡ cấu hình riêng của máy build. Script build thì generic, .conf thì KHÔNG.
rm -f "$STAGED/Contents/Resources/"*.conf
LEAK=$(grep -rlniE "gmail\.com|@[a-z0-9.-]+\.(com|vn|net)" "$STAGED/Contents/Resources/" 2>/dev/null || true)
if [ -n "$LEAK" ]; then
  echo "DỪNG: còn dữ liệu cá nhân trong bundle:"; echo "$LEAK" | sed 's/^/  /'; exit 1
fi
xattr -cr "$STAGED" 2>/dev/null || true
codesign --force --sign - --options runtime "$STAGED" >/dev/null 2>&1

ARCHS="$(lipo -info "$STAGED/Contents/MacOS/$NAME" 2>/dev/null | sed 's/.*are: //;s/.*is architecture: //')"

cat > "$STAGE/DOC-DE-CHAY.txt" <<EOF
$NAME $VER
Quản lý nhiều tài khoản Chrome / Telegram, mỗi tài khoản một app riêng.

CÀI ĐẶT
  1. Kéo "$NAME" vào thư mục Applications (đã có sẵn trong cửa sổ này).
  2. QUAN TRỌNG — mở Terminal, dán đúng dòng này rồi Enter:

       xattr -dr com.apple.quarantine "/Applications/$NAME.app" && open -a "$NAME"

VÌ SAO PHẢI LÀM BƯỚC 2
  App ký ad-hoc, không có chứng chỉ Apple Developer (\$99/năm). Mọi file tải từ
  internet đều bị macOS gắn cờ "quarantine", app ad-hoc dính cờ đó bị chặn với
  thông báo sai lệch:

      "$NAME" is damaged and can't be opened.

  App KHÔNG hỏng. Lệnh trên chỉ gỡ cờ. ĐỪNG bấm "Move to Trash".
  Mẹo chuột phải > Open không còn tác dụng với app ad-hoc trên macOS mới.

  Lưu ý: phải kéo app vào /Applications TRƯỚC, rồi mới chạy lệnh.
  Chạy lệnh khi app còn nằm trong Downloads hoặc trong cửa sổ DMG là vô ích.

NẾU VẪN KHÔNG MỞ ĐƯỢC
  Cách 1 — System Settings > Privacy & Security, kéo xuống cuối, bấm
           "Open Anyway" ở dòng nhắc về Account Dock. (macOS 15/26 dùng cách này
           thay cho mẹo chuột phải cũ.)

  Cách 2 — Chạy file chan_doan.sh kèm trong cửa sổ này để biết lý do thật:
             bash "/Volumes/$VOL/chan_doan.sh"
           Rồi chụp kết quả gửi lại.

YÊU CẦU   macOS 13+ · $ARCHS

DỮ LIỆU   Chỉ đọc máy bạn, không gửi đi đâu. Không server, không kết nối mạng.
          Tài khoản tự thêm lưu ở:
          ~/Library/Application Support/AccountDock/accounts.json

GỠ        rm -rf "/Applications/$NAME.app"
          rm -rf ~/Library/Application\\ Support/AccountDock
EOF

# --- 2. Ảnh nền -----------------------------------------------------------
if [ -f "$SRCDIR/make_dmg_bg.swift" ] && swiftc -O -o "$TMP/bg" "$SRCDIR/make_dmg_bg.swift" 2>/dev/null \
   && "$TMP/bg" "$TMP/bg.png" 2>/dev/null; then
  # NSImage render theo Retina (2x) -> ép đúng 620x400 vì Finder đọc kích thước pixel
  sips -z 400 620 "$TMP/bg.png" --out "$STAGE/.background/bg.png" >/dev/null 2>&1
  HAVE_BG=1
else
  HAVE_BG=0
  echo "  (không dựng được ảnh nền — DMG vẫn dùng được, chỉ là nền trắng)"
fi

# --- 3. Dựng DMG đọc-ghi để còn sắp xếp được ------------------------------
hdiutil create -volname "$VOL" -srcfolder "$STAGE" -ov -format UDRW \
        -fs HFS+ "$TMP/rw.dmg" >/dev/null
hdiutil detach "/Volumes/$VOL" -quiet 2>/dev/null || true
hdiutil attach "$TMP/rw.dmg" -noautoopen -quiet
sleep 2

# --- 4. Sắp xếp cửa sổ bằng Finder ---------------------------------------
# Có thể thất bại nếu chưa cấp quyền Automation cho Terminal -> bỏ qua, DMG vẫn chạy.
if osascript <<OSA >/dev/null 2>&1
tell application "Finder"
  tell disk "$VOL"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 820, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 104
    $([ "$HAVE_BG" = 1 ] && echo 'set background picture of opts to file ".background:bg.png"')
    set position of item "$NAME.app" to {155, 190}
    set position of item "Applications" to {465, 190}
    set position of item "DOC-DE-CHAY.txt" to {310, 330}
    close
    open
    update without registering applications
    delay 1
  end tell
end tell
OSA
then echo "  bố cục cửa sổ: đã sắp xếp"
else echo "  bố cục cửa sổ: BỎ QUA (Finder không cho tự động hoá) — DMG vẫn dùng bình thường"
fi

sync
hdiutil detach "/Volumes/$VOL" -quiet || hdiutil detach "/Volumes/$VOL" -force -quiet

# --- 5. Nén lại thành bản chỉ đọc ----------------------------------------
rm -f "$DMG"
hdiutil convert "$TMP/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null

echo
echo "=== Xong ==="
echo "  $DMG  ($(du -h "$DMG" | cut -f1))"
echo "  kiến trúc: $ARCHS"
echo "  đã gỡ .conf, đã quét lại không còn dữ liệu cá nhân"
