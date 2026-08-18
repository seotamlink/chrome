#!/bin/bash
# Chẩn đoán vì sao Account Dock không mở được.
# Gửi file này cho người gặp lỗi, bảo họ chạy rồi chụp kết quả gửi lại.
A="/Applications/Account Dock.app"
echo "===== CHẨN ĐOÁN ACCOUNT DOCK ====="
echo "macOS      : $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
echo "Chip       : $(uname -m)"
echo
if [ ! -d "$A" ]; then
  echo "KHÔNG THẤY app ở $A"
  echo "-> Bạn đã kéo app vào thư mục Applications chưa?"
  exit 1
fi
echo "App        : có"
echo "Kiến trúc  : $(lipo -info "$A/Contents/MacOS/Account Dock" 2>&1 | sed 's/.*: //')"
echo "Yêu cầu OS : $(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$A/Contents/Info.plist" 2>/dev/null)"
echo
Q=$(xattr -p com.apple.quarantine "$A" 2>/dev/null)
if [ -n "$Q" ]; then
  echo "CỜ QUARANTINE: CÒN  ($Q)   <-- ĐÂY LÀ NGUYÊN NHÂN"
  echo "Chạy lệnh này rồi mở lại:"
  echo "    xattr -dr com.apple.quarantine \"$A\""
else
  echo "Cờ quarantine: đã gỡ"
fi
echo
echo "Chữ ký     : $(codesign --verify "$A" 2>&1 | head -1 || echo 'hợp lệ')"
echo "Gatekeeper : $(spctl -a -t exec "$A" 2>&1 | sed 's|.*: ||')"
echo
echo "Thử chạy trực tiếp:"
"$A/Contents/MacOS/Account Dock" --dump >/dev/null 2>&1
C=$?
echo "  exit=$C"
case $C in
  0)   echo "  -> Binary CHẠY ĐƯỢC. Vấn đề nằm ở Gatekeeper khi mở bằng Finder." ;;
  137) echo "  -> Bị kernel giết vì chữ ký/quarantine." ;;
  *)   echo "  -> Lỗi khác, xem log:"; "$A/Contents/MacOS/Account Dock" --dump 2>&1 | head -5 ;;
esac
echo
echo "Log hệ thống 60 giây qua:"
log show --last 60s --predicate 'eventMessage CONTAINS "Account Dock"' 2>/dev/null \
  | grep -viE "^Filtering|^Timestamp" | tail -6
echo "===== HẾT ====="
