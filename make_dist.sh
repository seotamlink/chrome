#!/bin/bash
# ============================================================================
#  Đóng gói Account Dock để gửi cho người khác.
#
#  Tạo dist/AccountDock-<ver>.zip gồm: app universal + hướng dẫn.
#  KHÔNG kèm file *.conf (cấu hình riêng của máy này).
#
#  Dùng: ./make_dist.sh
# ============================================================================
set -euo pipefail

NAME="Account Dock"
APP="/Applications/$NAME.app"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
DIST="$SRCDIR/dist"
VER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo 1.0.0)"

[ -d "$APP" ] || { echo "Chưa có $APP. Chạy ./build_dashboard_app.sh trước."; exit 1; }

FOLDER="$NAME $VER"
rm -rf "$DIST"; mkdir -p "$DIST/$FOLDER"
cp -R "$APP" "$DIST/$FOLDER/"
STAGED="$DIST/$FOLDER/$NAME.app"

# --- Gỡ mọi cấu hình riêng khỏi bản đem chia sẻ ---------------------------
# build_dashboard_app.sh copy các script vào Contents/Resources để nút "Build lại"
# chạy được. Script thì generic, nhưng file .conf thì KHÔNG được đi kèm.
rm -f "$STAGED/Contents/Resources/"*.conf
LEAK=$(grep -rlniE "gmail\.com|@[a-z0-9.-]+\.(com|vn|net)" "$STAGED/Contents/Resources/" 2>/dev/null || true)
if [ -n "$LEAK" ]; then
  echo "DỪNG: còn dữ liệu cá nhân trong bundle:"
  echo "$LEAK" | sed 's/^/  /'
  exit 1
fi

# Ký lại vì vừa sửa nội dung bundle
xattr -cr "$STAGED" 2>/dev/null || true
codesign --force --sign - --options runtime "$STAGED" >/dev/null 2>&1

ARCHS="$(lipo -info "$STAGED/Contents/MacOS/$NAME" 2>/dev/null | sed 's/.*are: //;s/.*is architecture: //')"

cat > "$DIST/$FOLDER/DOC-DE-CHAY.txt" <<EOF
Account Dock $VER
Quản lý nhiều tài khoản Chrome / Telegram, mỗi tài khoản một app riêng.

CÀI ĐẶT
  1. Kéo "Account Dock.app" vào thư mục Applications.
  2. QUAN TRỌNG — mở Terminal, dán đúng dòng này rồi Enter:

       xattr -dr com.apple.quarantine "/Applications/Account Dock.app"

  3. Mở app bình thường.

VÌ SAO PHẢI LÀM BƯỚC 2
  App này ký ad-hoc, không có chứng chỉ Apple Developer (\$99/năm).
  Mọi file tải từ internet đều bị macOS gắn cờ "quarantine", và app ký ad-hoc
  dính cờ đó sẽ bị chặn thẳng với thông báo kiểu:

      "Account Dock" is damaged and can't be opened.

  App KHÔNG hỏng. Lệnh ở bước 2 chỉ gỡ cờ quarantine.
  Cách bấm chuột phải > Open không còn tác dụng với app ad-hoc trên macOS mới.

YÊU CẦU
  macOS 13 trở lên. Kiến trúc: $ARCHS

APP NÀY LÀM GÌ
  - Dò các app Chrome/Telegram đã tách tài khoản trên máy bạn
  - Bấm một cái để mở đúng tài khoản
  - Thêm lối tắt web (Facebook, Shopee...) gắn với một profile Chrome cụ thể
  - Nút "Build lại" tạo app clone cho từng profile Chrome đã đăng nhập

DỮ LIỆU
  Chỉ đọc máy bạn, không gửi đi đâu. Không có server, không có kết nối mạng.
  Tài khoản bạn tự thêm lưu tại:
    ~/Library/Application Support/AccountDock/accounts.json

GỠ CÀI ĐẶT
  rm -rf "/Applications/Account Dock.app"
  rm -rf ~/Library/Application\\ Support/AccountDock
EOF

ditto -c -k --sequesterRsrc --keepParent "$DIST/$FOLDER" "$DIST/AccountDock-$VER.zip"
rm -rf "$DIST/$FOLDER"

echo "=== Gói xong ==="
echo "  $DIST/AccountDock-$VER.zip  ($(du -h "$DIST/AccountDock-$VER.zip" | cut -f1))"
echo "  kiến trúc: $ARCHS"
echo "  đã gỡ .conf khỏi bundle, đã quét lại không còn dữ liệu cá nhân"
echo
echo "Gửi file zip đó. Người nhận đọc DOC-DE-CHAY.txt bên trong."
