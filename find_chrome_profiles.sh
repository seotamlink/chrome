#!/bin/bash

# Script để liệt kê tất cả Chrome profiles
echo "🔍 Đang tìm Chrome profiles..."
echo ""

CHROME_DATA_PATH="$HOME/Library/Application Support/Google/Chrome"

if [ ! -d "$CHROME_DATA_PATH" ]; then
    echo "❌ Chrome chưa được cài đặt hoặc không tìm thấy data"
    exit 1
fi

echo "Các profile tìm thấy:"
echo "===================="

ls -d "$CHROME_DATA_PATH"/Profile* "$CHROME_DATA_PATH"/Default 2>/dev/null | while read profile; do
    profile_name=$(basename "$profile")
    echo "✅ $profile_name"
done

echo ""
echo "Hãy copy tên profile (ví dụ: Default, Profile 1, Profile 2) để dùng ở bước tiếp theo"
