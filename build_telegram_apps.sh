#!/bin/bash
# ============================================================================
#  Tạo các bản Telegram Desktop ĐỘC LẬP trên macOS
#  -> mỗi tài khoản là một app riêng: icon Dock riêng, Cmd+Tab riêng, thông báo riêng
#
#  Chỉ áp dụng cho Telegram Desktop (com.tdesktop.Telegram).
#  KHÔNG áp dụng cho Telegram for macOS (ru.keepcoder.Telegram) — bản đó sandboxed,
#  group container gắn Team ID, ad-hoc re-sign là mất quyền đọc dữ liệu của chính nó.
#
#  Dùng: ./build_telegram_apps.sh
# ============================================================================
set -euo pipefail

# ---------------------------------------------------------------- CẤU HÌNH --
# Cấu hình nằm ở file RIÊNG `telegram_apps.conf` cạnh script này, KHÔNG nhúng
# vào đây — để bản app đem chia sẻ không kèm theo tên tài khoản của ai cả.
#
# Mỗi dòng:  Tên app|suffix|đường dẫn ảnh icon (bỏ trống = giữ logo Telegram)
# Ví dụ:     Telegram Việc|work|/Users/ban/anh.png
#
# Không có file conf thì mặc định tạo một bản "Telegram 2".
APPS=()
CONF="$(cd "$(dirname "$0")" && pwd)/telegram_apps.conf"
if [ -f "$CONF" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$line" ] && APPS+=("$line")
  done < "$CONF"
fi
[ ${#APPS[@]} -eq 0 ] && APPS=("Telegram 2|tg2|")
# ---------------------------------------------------------------------------

SRCAPP="/Applications/Telegram.app"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -d "$SRCAPP" ] || { echo "Không tìm thấy $SRCAPP"; exit 1; }

BID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SRCAPP/Contents/Info.plist" 2>/dev/null || true)"
if [ "$BID" != "com.tdesktop.Telegram" ]; then
  echo "Cảnh báo: $SRCAPP có bundle ID '$BID', không phải Telegram Desktop."
  echo "Script này chỉ dựng được từ Telegram Desktop. Dừng."
  exit 1
fi

# Entitlements của tdesktop rất đơn giản và KHÔNG có cái nào gắn Team ID
# (không application-identifier, không keychain-access-groups) -> ad-hoc không mất gì.
cat > "$TMP/ent.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.device.audio-input</key><true/>
  <key>com.apple.security.device.camera</key><true/>
  <key>com.apple.security.personal-information.location</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
EOF

# Công cụ ghép icon (dùng chung với build_chrome_apps.sh)
ICONTOOL="$TMP/make_icon"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SRCDIR/make_icon.swift" ] && command -v swiftc >/dev/null 2>&1; then
  swiftc -O -o "$ICONTOOL" "$SRCDIR/make_icon.swift" 2>/dev/null || ICONTOOL=""
else
  ICONTOOL=""
fi

for spec in "${APPS[@]}"; do
  IFS='|' read -r NAME SUFFIX ICONSRC <<< "$spec"
  APP="/Applications/$NAME.app"
  WORKDIR="$HOME/Library/Application Support/Telegram-$SUFFIX"

  echo "=== $NAME ==="


  # Nếu app đã tồn tại và đang trỏ tới thư mục dữ liệu KHÁC thì cảnh báo.
  # Không có bước này, chỉ cần đổi suffix (hoặc chạy script khi thiếu file conf,
  # lúc đó suffix tự sinh theo email) là app âm thầm chuyển sang thư mục mới
  # và bỏ rơi toàn bộ dữ liệu cũ — nhìn như mất sạch tài khoản.
  if [ -f "$APP/Contents/MacOS/tg-wrapper" ]; then
    # `--` bắt buộc: mẫu bắt đầu bằng '-' sẽ bị grep hiểu nhầm là tham số.
    # `|| true` vì set -e + pipefail: grep không khớp là script chết.
    OLD=$(grep -o -- '-workdir "[^"]*"' "$APP/Contents/MacOS/tg-wrapper" 2>/dev/null | sed 's/.*"\(.*\)"/\1/' | head -1 || true)
    if [ -n "$OLD" ] && [ "$OLD" != "$WORKDIR" ] && [ -d "$OLD" ]; then
      echo "  ⚠ CẢNH BÁO: '$NAME' đang dùng dữ liệu ở:"
      echo "      $OLD"
      echo "    Lần build này sẽ chuyển sang:"
      echo "      $WORKDIR"
      echo "    Dữ liệu cũ KHÔNG bị xoá, nhưng app sẽ không dùng tới nữa."
      echo "    Muốn giữ nguyên: đặt suffix '$(basename "$OLD" | sed 's/^[A-Za-z]*-//')' trong $(basename "$CONF")"
      echo
    fi
  fi

  pkill -f "MacOS/$NAME" 2>/dev/null || true
  sleep 1
  rm -rf "$APP"

  # 1. Clone bằng APFS copy-on-write
  cp -Rc "$SRCAPP" "$APP"
  xattr -cr "$APP" 2>/dev/null || true
  find "$APP" -name '._*' -delete 2>/dev/null || true

  # 2. Đổi tên binary -> Cmd+Tab hiện đúng tên (macOS lấy tên process từ tên file thực thi)
  mv "$APP/Contents/MacOS/Telegram" "$APP/Contents/MacOS/$NAME"

  # 3. Wrapper truyền -workdir. Đây là flag CHÍNH THỨC của tdesktop, không phải hack.
  #    Cần wrapper vì double-click app không truyền được tham số dòng lệnh.
  mkdir -p "$WORKDIR"
  cat > "$APP/Contents/MacOS/tg-wrapper" <<WRAP
#!/bin/bash
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec "\$DIR/$NAME" -workdir "$WORKDIR" "\$@"
WRAP
  chmod +x "$APP/Contents/MacOS/tg-wrapper"

  # 4. Danh tính bundle riêng -> macOS mới coi là app khác
  P="$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.tdesktop.Telegram.$SUFFIX" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $NAME"                                "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $NAME"                         "$P" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string $NAME" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable tg-wrapper"                     "$P"
  # không tranh xử lý link tg:// với bản gốc
  /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$P" 2>/dev/null || true
  # BẮT BUỘC: còn CFBundleIconName thì macOS lấy icon từ Assets.car và bỏ qua .icns
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$P" 2>/dev/null || true

  # 5. Icon
  ICNS="$APP/Contents/Resources/Icon.icns"
  if [ -n "$ICONSRC" ] && [ -f "$ICONSRC" ] && [ -x "$ICONTOOL" ] \
     && "$ICONTOOL" "$SRCAPP/Contents/Resources/Icon.icns" "$ICONSRC" "$TMP/$SUFFIX.png" 2>/dev/null; then
    set="$TMP/$SUFFIX.iconset"; rm -rf "$set"; mkdir -p "$set"
    for s in 16 32 128 256 512; do
      sips -s format png -z $s $s "$TMP/$SUFFIX.png" --out "$set/icon_${s}x${s}.png" >/dev/null 2>&1
      sips -s format png -z $((s*2)) $((s*2)) "$TMP/$SUFFIX.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null 2>&1
    done
    iconutil -c icns "$set" -o "$ICNS" 2>/dev/null && echo "  icon  : logo Telegram + badge từ $(basename "$ICONSRC")"
  else
    echo "  icon  : giữ logo Telegram (chưa cấu hình ảnh)"
  fi

  # 6. Re-sign ad-hoc
  codesign --force --sign - --options runtime \
    --entitlements "$TMP/ent.plist" "$APP/Contents/MacOS/$NAME" >/dev/null 2>&1
  codesign --force --sign - --options runtime "$APP" >/dev/null 2>&1

  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP" >/dev/null 2>&1 || true

  echo "  workdir: $WORKDIR"
  echo "  sign   : $(codesign -dv "$APP" 2>&1 | grep -o 'flags=[^ ]*')"
  echo "  xong   : $APP"
  echo
done

killall Dock 2>/dev/null || true
echo "Hoàn tất. Mở app rồi đăng nhập tài khoản cho nó."
echo "LƯU Ý: mỗi app là một phiên đăng nhập ĐỘC LẬP — không copy tdata giữa các app,"
echo "       vì chúng sẽ dùng chung authorization key và đăng xuất chéo lẫn nhau."
