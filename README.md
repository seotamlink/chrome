# Account Dock

Tách nhiều tài khoản Chrome / Telegram thành **các app macOS riêng biệt** — mỗi tài khoản một
icon Dock, một mục Cmd+Tab, một ⌘Q độc lập. Kèm app quản lý để bấm một cái là mở đúng tài khoản.

Chạy hoàn toàn local. Không server, không kết nối mạng, không gửi dữ liệu đi đâu.

---

## Vấn đề

Trên Windows, Chrome tự tạo shortcut riêng cho từng profile. **Trên macOS thì không** — Chrome
chạy một process duy nhất cho mọi profile.

Hầu hết hướng dẫn "multi-account trên Mac" dùng `--profile-directory`. Cách đó **chỉ đổi profile
bên trong một app**, nên:

- Cmd+Tab chỉ thấy **một** "Google Chrome" — không chuyển giữa các tài khoản được
- Dock chỉ có **một** icon, gộp hết cửa sổ của mọi tài khoản
- **⌘Q giết sạch cả ba tài khoản** cùng lúc
- Chrome crash là mất hết

Repo này làm cách khác: clone app + `--user-data-dir` riêng + bundle ID riêng.

| | `--profile-directory` | Repo này |
|---|---|---|
| Process | 1, dùng chung | riêng từng tài khoản |
| Icon Dock riêng | ❌ | ✅ |
| Cmd+Tab tách được | ❌ | ✅ |
| ⌘Q độc lập | ❌ | ✅ |
| Chrome tự update | ✅ | ❌ phải build lại |

---

## Cài

Cần **macOS 13+** và **Xcode Command Line Tools** (`xcode-select --install`).

```bash
git clone https://github.com/seotamlink/chrome.git account-dock && cd account-dock

./build_chrome_apps.sh      # tách tài khoản Chrome thành app riêng
./build_telegram_apps.sh    # tách Telegram Desktop (tuỳ chọn)
./build_dashboard_app.sh    # dựng /Applications/Account Dock.app
open -a "Account Dock"
```

Không cần cấu hình gì. `build_chrome_apps.sh` **tự dò mọi profile Chrome đã đăng nhập**
trên máy bạn và tạo app tương ứng.

Muốn đặt tên riêng thì tạo `chrome_apps.conf`:

```
Chrome Cá nhân|canhan|Profile 1
Chrome Việc|viec|Profile 2
```

Xem profile có sẵn: `./find_chrome_profiles.sh`

> File `*.conf` nằm trong `.gitignore` — nó là cấu hình riêng của máy bạn, đừng commit.

---

## Dùng

**Account Dock** hiện mọi app đã tách theo nhóm. Mỗi thẻ có tài khoản, dung lượng, phiên bản,
trạng thái đang chạy, và cảnh báo *cần build lại* khi Chrome đã update lên bản mới hơn clone.

| Thao tác | |
|---|---|
| Bấm thẻ / nút **Mở** | mở tài khoản đó |
| Chuột phải | Mở · Đổi tên hiển thị · Mở thư mục dữ liệu · Thoát app |
| **＋ Thêm tài khoản** | thêm lối tắt web (Facebook, Shopee…) gắn với một profile Chrome cụ thể |
| **Build lại** | dựng lại app clone sau khi Chrome update — dữ liệu giữ nguyên |
| ⌘K ⌘N ⌘R | tìm kiếm · thêm · làm mới |

Tài khoản tự thêm và tên bạn đặt lưu ở
`~/Library/Application Support/AccountDock/accounts.json`.

---

## ⚠️ Đọc trước khi dùng

Bản clone bị ký **ad-hoc** (không có Apple Developer Team ID). Hệ quả không tránh được:

- **Passkeys / WebAuthn không hoạt động** trong app clone. Login bằng passkey phải dùng Chrome gốc.
- **Keychain hỏi quyền lần đầu.** Cookies mã hoá bằng key trong Keychain "Chrome Safe Storage",
  quyền gắn với code signature. Bấm **"Always Allow"** thì giữ nguyên đăng nhập; bấm Deny là
  bị đăng xuất.
- **Chrome không tự update app clone.** Sau mỗi lần Chrome gốc update, bấm **Build lại**.
- **Widevine DRM có thể lỗi** → Netflix/Spotify dùng Chrome gốc.

Dữ liệu gốc (`Profile 1`, `Profile 2`…) chỉ được **đọc** để copy sang, không bị sửa. Clone dùng
APFS copy-on-write nên gần như **không tốn thêm dung lượng** lúc đầu.

### Telegram

Chỉ **Telegram Desktop** (`com.tdesktop.Telegram`) tách được — nó có flag `-workdir` chính thức
và không chạy sandbox.

**Telegram for macOS** (`ru.keepcoder.Telegram`, bản App Store) **không tách được**: sandboxed,
group container gắn Team ID `6N38VWS5BX`, bản ad-hoc không khai được group đó nên mở lên trắng trơn.

Khác Chrome: **không copy được dữ liệu Telegram giữa các app**. `tdata` chứa authorization key,
hai app dùng chung một key sẽ đăng xuất chéo nhau. Mỗi app phải đăng nhập lại bằng số điện thoại.

---

## Gửi cho người khác

```bash
./make_dmg.sh     # -> dist/AccountDock-<ver>.dmg  (~312 KB) — khuyên dùng
./make_dist.sh    # -> dist/AccountDock-<ver>.zip  (~280 KB) — nếu cần file zip
```

DMG mở ra là thấy icon app, mũi tên, và thư mục Applications — kéo sang là cài xong,
đúng kiểu quen thuộc trên macOS. Cả hai đều universal (`arm64` + `x86_64`).

Script tự gỡ file `.conf` khỏi bundle rồi quét lại; còn sót email là nó **dừng, không đóng gói**.

Người nhận **bắt buộc** chạy một lệnh:

```bash
xattr -dr com.apple.quarantine "/Applications/Account Dock.app"
```

Không chạy thì macOS báo *"is damaged and can't be opened"*. App không hỏng — mọi file tải từ
internet đều bị gắn cờ quarantine, và app ký ad-hoc dính cờ đó bị chặn thẳng. Mẹo chuột phải →
Open **không còn tác dụng** trên macOS mới.

Bỏ hẳn bước này cần **Apple Developer Program ($99/năm)** để ký Developer ID và notarize.
Không có đường vòng.

---

## Cấu trúc

| File | Việc |
|---|---|
| `build_chrome_apps.sh` | Tách tài khoản Chrome thành app riêng |
| `build_telegram_apps.sh` | Tách Telegram Desktop |
| `build_dashboard_app.sh` | Compile + đóng gói `Account Dock.app` (universal) |
| `make_dmg.sh` | Đóng gói `.dmg` để chia sẻ (khuyên dùng) |
| `make_dist.sh` | Đóng gói `.zip` để chia sẻ |
| `make_dmg_bg.swift` | Vẽ ảnh nền cửa sổ DMG |
| `AccountDock.swift` | App quản lý: quét trạng thái + cầu nối JS↔Swift |
| `AccountDockHTML.swift` | Giao diện (HTML/CSS/JS) — sửa giao diện ở đây |
| `make_icon.swift` | Ghép logo app + avatar thành icon badge |
| `find_chrome_profiles.sh` | Liệt kê profile Chrome |
| `HUONG_DAN_SETUP.md` | **Tài liệu kỹ thuật** — cơ chế, các bẫy, cách chẩn đoán |

Account Dock viết bằng Swift + `WKWebView`. Giao diện là HTML nhưng **không có server, không port,
không token** — JS gọi thẳng sang Swift qua `WKScriptMessageHandler`.

```bash
"/Applications/Account Dock.app/Contents/MacOS/Account Dock" --dump    # trạng thái ra JSON
"/Applications/Account Dock.app/Contents/MacOS/Account Dock" --bench   # đo hiệu năng scan()
```

---

## Gỡ sạch

```bash
rm -rf "/Applications/Account Dock.app"
rm -rf ~/Library/Application\ Support/AccountDock
# app clone + dữ liệu của chúng:
rm -rf /Applications/Chrome\ *.app /Applications/Telegram\ [0-9]*.app
rm -rf ~/Library/Application\ Support/Chrome-* ~/Library/Application\ Support/Telegram-*
killall Dock
```

Chrome gốc, Telegram gốc và dữ liệu gốc không bị ảnh hưởng.
