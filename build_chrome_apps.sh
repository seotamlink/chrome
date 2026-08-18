#!/bin/bash
# ============================================================================
#  Tạo các bản Chrome ĐỘC LẬP trên macOS
#  -> mỗi tài khoản là một app riêng: icon Dock riêng, Cmd+Tab riêng, Cmd+Q riêng
#
#  Chạy lại script này sau mỗi lần Google Chrome update.
#  Dùng: ./build_chrome_apps.sh
# ============================================================================
set -euo pipefail

# ---------------------------------------------------------------- CẤU HÌNH --
# Cấu hình nằm ở file RIÊNG `chrome_apps.conf` cạnh script này, KHÔNG nhúng vào
# đây — để bản app đem chia sẻ không kèm theo tên tài khoản của ai cả.
#
# Mỗi dòng:  Tên app|suffix|profile nguồn      (suffix: chữ thường, không dấu cách)
# Ví dụ:     Chrome Việc|work|Profile 1
#
# Không có file conf thì script tự dò mọi profile Chrome đã đăng nhập.
APPS=()
CONF="$(cd "$(dirname "$0")" && pwd)/chrome_apps.conf"
if [ -f "$CONF" ]; then
  while IFS= read -r line; do
    line="${line%%#*}"; line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [ -n "$line" ] && APPS+=("$line")
  done < "$CONF"
fi
# ---------------------------------------------------------------------------

SRCAPP="/Applications/Google Chrome.app"
CHROMEDATA="$HOME/Library/Application Support/Google/Chrome"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -d "$SRCAPP" ] || { echo "Không tìm thấy $SRCAPP"; exit 1; }

# Không có file conf -> tự dò mọi profile Chrome đã đăng nhập.
# Nhờ vậy máy nào chạy cũng ra kết quả đúng của máy đó, không cần sửa script.
if [ ${#APPS[@]} -eq 0 ]; then
  echo "Không thấy $(basename "$CONF") — tự dò profile Chrome đã đăng nhập:"
  while IFS='|' read -r nm sfx prof; do
    [ -n "$prof" ] && APPS+=("$nm|$sfx|$prof") && echo "  $nm  <-  $prof"
  done < <(python3 - "$CHROMEDATA" <<'PY'
import json, os, re, sys
ls = os.path.join(sys.argv[1], "Local State")
try:
    info = json.load(open(ls, encoding="utf-8"))["profile"]["info_cache"]
except Exception:
    sys.exit(0)
used = set()
for key, v in sorted(info.items()):
    email = v.get("user_name")
    if not email:                       # bỏ profile chưa đăng nhập
        continue
    base = re.sub(r"[^A-Za-z0-9]+", "", email.split("@")[0])[:12].lower() or "acc"
    sfx = base
    i = 2
    while sfx in used:
        sfx = f"{base}{i}"; i += 1
    used.add(sfx)
    name = (v.get("name") or email.split("@")[0]).strip()
    print(f"Chrome {name}|{sfx}|{key}")
PY
  )
  [ ${#APPS[@]} -eq 0 ] && { echo "Không có profile nào đã đăng nhập. Dừng."; exit 0; }
  echo
fi

# Chrome phải tắt hẳn trước khi copy profile
if pgrep -f "Google Chrome.app/Contents/MacOS" >/dev/null; then
  echo "Đang tắt Google Chrome..."
  osascript -e 'tell application "Google Chrome" to quit' 2>/dev/null || true
  for _ in $(seq 1 20); do
    pgrep -f "Google Chrome.app/Contents/MacOS" >/dev/null || break
    sleep 0.5
  done
fi

# Entitlements ad-hoc: bỏ những cái gắn cứng Team ID của Google
# (application-identifier, keychain-access-groups) vì bản clone không có Team ID.
cat > "$TMP/ent.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.device.audio-input</key><true/>
  <key>com.apple.security.device.bluetooth</key><true/>
  <key>com.apple.security.device.camera</key><true/>
  <key>com.apple.security.device.print</key><true/>
  <key>com.apple.security.device.usb</key><true/>
  <key>com.apple.security.personal-information.location</key><true/>
  <key>com.apple.security.personal-information.photos-library</key><true/>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
</dict></plist>
EOF

build_icon() {  # $1=png nguồn  $2=đích .icns  $3=tag
  local set="$TMP/$3.iconset"; rm -rf "$set"; mkdir -p "$set"
  # Ghép logo Chrome + avatar thành badge tròn (make_icon.swift).
  # Nếu không compile được thì fallback: dùng avatar tràn viền như trước.
  if [ -x "$ICONTOOL" ] && "$ICONTOOL" "$SRCAPP/Contents/Resources/app.icns" "$1" "$TMP/$3.png" 2>/dev/null; then
    :
  else
    sips -s format png -z 1024 1024 "$1" --out "$TMP/$3.png" >/dev/null 2>&1 || return 1
  fi
  for s in 16 32 128 256 512; do
    sips -s format png -z $s $s "$TMP/$3.png" --out "$set/icon_${s}x${s}.png" >/dev/null 2>&1
    sips -s format png -z $((s*2)) $((s*2)) "$TMP/$3.png" --out "$set/icon_${s}x${s}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$set" -o "$2" 2>/dev/null
}

# Compile công cụ ghép icon (một lần cho cả lượt chạy)
ICONTOOL="$TMP/make_icon"
SRCDIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SRCDIR/make_icon.swift" ] && command -v swiftc >/dev/null 2>&1; then
  swiftc -O -o "$ICONTOOL" "$SRCDIR/make_icon.swift" 2>/dev/null || ICONTOOL=""
else
  ICONTOOL=""
fi

for spec in "${APPS[@]}"; do
  IFS='|' read -r NAME SUFFIX SRCPROFILE <<< "$spec"
  APP="/Applications/$NAME.app"
  UDD="$HOME/Library/Application Support/Chrome-$SUFFIX"

  echo "=== $NAME (profile nguồn: $SRCPROFILE) ==="

  pkill -f "MacOS/$NAME" 2>/dev/null || true
  sleep 1
  rm -rf "$APP"

  # 1. Clone bằng APFS copy-on-write: tức thì, không tốn thêm dung lượng
  cp -Rc "$SRCAPP" "$APP"
  xattr -cr "$APP" 2>/dev/null || true
  find "$APP" -name '._*' -delete 2>/dev/null || true

  # 2. Đổi tên binary -> process name hiện đúng trong Cmd+Tab / menu bar
  mv "$APP/Contents/MacOS/Google Chrome" "$APP/Contents/MacOS/$NAME"

  # 3. Wrapper luôn inject user-data-dir riêng
  cat > "$APP/Contents/MacOS/chrome-wrapper" <<WRAP
#!/bin/bash
DIR="\$(cd "\$(dirname "\$0")" && pwd)"
exec "\$DIR/$NAME" --user-data-dir="$UDD" "\$@"
WRAP
  chmod +x "$APP/Contents/MacOS/chrome-wrapper"

  # 4. Bundle ID riêng -> đây là thứ khiến macOS coi nó là app KHÁC
  P="$APP/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.google.Chrome.$SUFFIX" "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName $NAME"                          "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName $NAME"                   "$P"
  /usr/libexec/PlistBuddy -c "Set :CFBundleExecutable chrome-wrapper"           "$P"
  # không tranh làm browser mặc định với Chrome gốc
  /usr/libexec/PlistBuddy -c "Delete :CFBundleURLTypes" "$P" 2>/dev/null || true
  # BẮT BUỘC: Chrome khai CFBundleIconName=AppIcon + ship Assets.car.
  # Còn key này thì macOS lấy icon từ asset catalog và BỎ QUA app.icns -> icon không đổi.
  /usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$P" 2>/dev/null || true

  # 5. Icon = avatar Google của tài khoản đó
  AVATAR="$CHROMEDATA/$SRCPROFILE/Google Profile Picture.png"
  if [ -f "$AVATAR" ] && build_icon "$AVATAR" "$APP/Contents/Resources/app.icns" "$SUFFIX"; then
    echo "  icon  : avatar Google"
  else
    echo "  icon  : giữ icon Chrome (không tìm thấy avatar)"
  fi

  # 6. Migrate data — CHỈ ĐỌC bản gốc, không sửa gì. Bỏ qua nếu đã có.
  if [ -d "$UDD/Default" ]; then
    echo "  data  : đã có, giữ nguyên ($(du -sh "$UDD/Default" | cut -f1))"
  elif [ -d "$CHROMEDATA/$SRCPROFILE" ]; then
    mkdir -p "$UDD"
    cp -Rc "$CHROMEDATA/$SRCPROFILE" "$UDD/Default"
    echo "  data  : $SRCPROFILE -> $UDD/Default ($(du -sh "$UDD/Default" | cut -f1))"
  else
    echo "  data  : không thấy '$SRCPROFILE', sẽ tạo profile trắng"
  fi

  # 7. Re-sign. BẮT BUỘC: binary gốc niêm phong hash của Info.plist,
  #    sửa Info.plist mà không re-sign -> cờ 'kill' cho kernel giết ngay (exit 137).
  codesign --force --sign - --options runtime \
    --entitlements "$TMP/ent.plist" "$APP/Contents/MacOS/$NAME" >/dev/null 2>&1
  codesign --force --sign - --options runtime "$APP" >/dev/null 2>&1

  # 8. Đăng ký lại với LaunchServices để Dock/Finder thấy tên + icon mới
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP" >/dev/null 2>&1 || true

  echo "  sign  : $(codesign -dv "$APP" 2>&1 | grep -o 'flags=[^ ]*')"
  echo "  xong  : $APP"
  echo
done

killall Dock 2>/dev/null || true
echo "Hoàn tất. Mở bằng Spotlight hoặc icon trên Dock."
