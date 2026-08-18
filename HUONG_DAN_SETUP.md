# Chrome Multi-Account trên macOS

## Cốt lõi vấn đề

Trên Windows, Chrome tự tạo shortcut riêng cho từng profile. **Trên macOS thì không** — Chrome
chạy một process duy nhất cho mọi profile. Mọi hướng dẫn kiểu "multi-account trên Mac" đều là
workaround quanh giới hạn này, và chúng chia làm hai loại rất khác nhau:

| | `--profile-directory` | `--user-data-dir` + clone app |
|---|---|---|
| Số process | 1 (dùng chung) | riêng từng tài khoản |
| Icon Dock riêng | ❌ chỉ 1 icon Chrome | ✅ |
| Cmd+Tab tách được | ❌ | ✅ |
| Cmd+Q độc lập | ❌ tắt 1 là tắt cả 3 | ✅ |
| Crash | chết cả 3 | chỉ chết 1 |
| Chrome tự update | ✅ | ❌ phải build lại |

Cách 1 chỉ đổi profile bên trong một app duy nhất — **không tạo được app riêng**. Nếu bạn chỉ
cần "bấm một cái là mở đúng tài khoản" thì nó đủ dùng, và không cần repo này.

Cách 2 là cái repo này làm, mô tả bên dưới.

---

## Kết quả

Chạy `./build_chrome_apps.sh`. Ví dụ với hai tài khoản:

| App | Bundle ID | user-data-dir | Nguồn data |
|---|---|---|---|
| `/Applications/Google Chrome.app` | `com.google.Chrome` | `~/Library/Application Support/Google/Chrome` | (không đổi) |
| `/Applications/Chrome Cá nhân.app` | `com.google.Chrome.canhan` | `~/Library/Application Support/Chrome-canhan` | `Profile 1` → canhan@gmail.com |
| `/Applications/Chrome Việc.app` | `com.google.Chrome.viec` | `~/Library/Application Support/Chrome-viec` | `Profile 2` → congviec@gmail.com |

Chrome gốc giữ nguyên, không bị sửa gì, vẫn tự update bình thường.
Data gốc (`Profile 1`, `Profile 2`) chỉ được **đọc** để copy sang, không bị thay đổi.

### Cấu hình

Tạo `chrome_apps.conf` cạnh script (file này **không** được commit — xem `.gitignore`):

```
Tên app|suffix|profile nguồn
Chrome Cá nhân|canhan|Profile 1
Chrome Việc|viec|Profile 2
```

**Không có file conf thì script tự dò** mọi profile Chrome đã đăng nhập trên máy đó —
nên clone repo về là chạy được ngay, không cần sửa gì.

Xem profile nào có sẵn: `./find_chrome_profiles.sh`

Script là **idempotent** — chạy lại sẽ dựng lại app nhưng giữ nguyên data đã có.
Muốn reset data về trắng: xoá `~/Library/Application Support/Chrome-<suffix>` rồi chạy lại.

---

## Cơ chế: 4 thứ phải làm cùng lúc

Thiếu bất kỳ bước nào là hỏng, và mỗi bước fix một triệu chứng khác nhau:

1. **`--user-data-dir` riêng** → Chrome mới bung ra process riêng.
   Thiếu bước này: vẫn dùng chung 1 process, Cmd+Q vẫn giết cả 3.

2. **`CFBundleIdentifier` riêng** → macOS mới coi là app khác.
   Thiếu bước này: có 2 process nhưng Dock/Cmd+Tab vẫn gộp thành 1 "Google Chrome".

3. **Đổi tên file binary** trong `Contents/MacOS/` thành tên app.
   Wrapper dùng `exec`, nên macOS lấy tên process từ **tên file thực thi**, không phải từ
   `CFBundleName`. Thiếu bước này: Cmd+Tab hiện "Google Chrome" hai lần.

4. **Re-sign ad-hoc.** Đây là bước hay bị bỏ sót nhất.

### Vì sao bắt buộc phải re-sign

Chrome gốc ký với `flags=0x12a00(kill,restrict,library-validation,runtime)`:

- Binary `Google Chrome` **tự niêm phong hash của `Info.plist`**. Sửa `Info.plist` → hash sai.
- Cờ **`kill`** → kernel `SIGKILL` ngay lập tức. Biểu hiện: app bấm vào không mở gì cả,
  chạy từ Terminal thì `exit code 137`, log không có gì.
- Cờ **`library-validation`** → chỉ load được thư viện cùng Team ID `EQHXZ8M8AV` của Google.
  Bản ad-hoc không có Team ID nên phải tắt cờ này (`disable-library-validation`).

Chẩn đoán: `codesign --verify --verbose=2 "/Applications/Chrome Cá nhân.app"` →
`invalid Info.plist (plist or signature have been modified)`

### Entitlements phải lược bỏ

Chrome gốc có 2 entitlement gắn cứng Team ID Google, bản ad-hoc **không thể** giữ:

- `com.apple.application-identifier` = `EQHXZ8M8AV.com.google.Chrome`
- `keychain-access-groups` = `EQHXZ8M8AV.com.google.Chrome.webauthn`, `.unexportable-keys`,
  `.devicetrust`, `.secure-payment-confirmation`, ...

---

## ⚠️ Cái giá phải trả

Đây là hệ quả trực tiếp của việc bản clone bị ký ad-hoc (không có Team ID Google):

- **Passkeys / WebAuthn platform authenticator sẽ không hoạt động** trong các bản clone.
  Do mất `keychain-access-groups`. Login bằng passkey phải dùng Chrome gốc.
- **Keychain sẽ hỏi quyền lần đầu.** Cookies được mã hoá bằng key trong Keychain item
  "Chrome Safe Storage", mà quyền truy cập gắn với code signature. Bản clone có signature
  khác → macOS hiện hộp thoại xin quyền. **Nhập mật khẩu máy và bấm "Always Allow"** thì
  cookies giải mã được và giữ nguyên đăng nhập. Nếu bấm Deny → bị đăng xuất.
- **Chrome không tự update các bản clone.** Sau mỗi lần Chrome gốc update, chạy lại
  `./build_chrome_apps.sh` (data được giữ nguyên).
- **Widevine DRM có thể lỗi** → Netflix/Spotify trong bản clone có thể không phát được.
  Dùng Chrome gốc cho việc đó.
- Dung lượng: clone dùng APFS copy-on-write nên **gần như không tốn thêm** lúc đầu, nhưng sẽ
  phình dần khi Chrome update và các block không còn chia sẻ.

Nếu những cái trên là vấn đề, giải pháp không-hack: dùng **các browser khác nhau** cho từng
tài khoản (Chrome + Chrome Beta + Brave/Edge). Chúng đều là app riêng thật, bundle ID riêng
sẵn, vendor tự ký, tự update — không cần workaround nào.

---

## Icon

Icon = **logo Chrome làm nền + avatar tài khoản làm badge tròn ở góc dưới-phải**.
Lý do không dùng avatar tràn kín khung: avatar Google chỉ có 256×256, phóng lên 1024 thì mờ,
và ảnh vuông không viền nhìn không ra là browser — ở cỡ Dock (~48px) chỉ còn một mảng màu.

Ghép bằng `make_icon.swift` (CoreGraphics). `build_chrome_apps.sh` tự compile bằng `swiftc`
rồi gọi; nếu máy không có `swiftc` thì tự động fallback về avatar tràn viền.

Chỉnh kích thước / vị trí badge ở phần `let r` và `let c` trong `make_icon.swift`.
Xem trước không cần build cả app:
```bash
swiftc -O -o /tmp/mi make_icon.swift
/tmp/mi "/Applications/Google Chrome.app/Contents/Resources/app.icns" \
        ~/Library/Application\ Support/Google/Chrome/Profile\ 3/Google\ Profile\ Picture.png \
        /tmp/preview.png && open /tmp/preview.png
```

Lưu ý: `swift make_icon.swift` (chạy trực tiếp) **không hoạt động** — JIT interpreter không
resolve được symbol CoreGraphics. Phải compile bằng `swiftc`.

Avatar lấy từ `~/Library/Application Support/Google/Chrome/<Profile>/Google Profile Picture.png`.
File này chỉ có nếu tài khoản Google đã đặt ảnh đại diện.

### Bẫy: phải xoá `CFBundleIconName`

Chrome khai `CFBundleIconName = AppIcon` và ship `Contents/Resources/Assets.car`.
Còn key đó thì macOS lấy icon từ **asset catalog** và **bỏ qua hoàn toàn `app.icns`** —
thay `app.icns` bao nhiêu lần cũng vô ích, Dock vẫn hiện logo Chrome gốc.

`build_chrome_apps.sh` xoá key này. Kiểm tra icon macOS thực sự trả về (đúng cái Dock vẽ):

```bash
cat > /tmp/gi.swift <<'EOF'
import AppKit
let i = NSWorkspace.shared.icon(forFile: CommandLine.arguments[1])
i.size = NSSize(width: 512, height: 512)
try! NSBitmapImageRep(data: i.tiffRepresentation!)!
    .representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
EOF
swiftc -O -o /tmp/gi /tmp/gi.swift
/tmp/gi "/Applications/Chrome Việc.app" /tmp/icon.png && open /tmp/icon.png
```

## Ghim vào Dock

Đã ghim sẵn. Cách dễ nhất nếu cần làm lại: kéo app từ `/Applications` vào Dock, hoặc bấm chạy
app rồi right-click icon trên Dock → **Options → Keep in Dock**.

### Nếu muốn script hoá — 2 cái bẫy

**1. Mỗi tile có key `book` — Dock phân giải app từ bookmark đó, không phải từ `_CFURLString`.**
Copy một tile rồi sửa `_CFURLString` sẽ **không** hoạt động: Dock đọc `book` (trỏ về app cũ) và
ghi đè `_CFURLString` trở lại → hai icon trùng nhau. Phải thêm tile **tối giản** chỉ có đường dẫn
rồi để Dock tự sinh `book`:

```bash
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Chrome Việc.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
killall Dock
```

**2. Đừng sửa thẳng `~/Library/Preferences/com.apple.dock.plist`.**
Dock đang chạy giữ bản trong bộ nhớ và flush đè lên file khi bị kill → mất thay đổi.
Phải đi qua `defaults write` / `defaults import` (qua cfprefsd), rồi mới `killall Dock`.

Sắp xếp lại thứ tự thì an toàn, vì `book` đi theo tile:
```bash
defaults export com.apple.dock /tmp/dock.plist
# ...sửa mảng persistent-apps trong /tmp/dock.plist...
defaults import com.apple.dock /tmp/dock.plist && killall Dock
```

---

## Troubleshooting

**Bấm app không mở gì / mở rồi tắt ngay**
Signature bị hỏng. Chạy lại `./build_chrome_apps.sh`. Kiểm tra:
```bash
"/Applications/Chrome Việc.app/Contents/MacOS/chrome-wrapper"; echo "exit=$?"
```
`exit=137` → bị kernel giết vì signature. `exit=0` ngay lập tức và app đã chạy → bình thường
(instance thứ 2 chuyển tiếp vào instance đầu rồi thoát).

**Cmd+Tab vẫn hiện "Google Chrome" thay vì tên app**
LaunchServices cache cũ:
```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "/Applications/Chrome Việc.app"
killall Dock
```

**Icon không đổi**
```bash
touch "/Applications/Chrome Việc.app"; killall Dock; killall Finder
```

**Bị đăng xuất sau khi build**
Đã bấm Deny ở hộp thoại Keychain. Mở **Keychain Access** → tìm `Chrome Safe Storage` →
tab **Access Control** → thêm app clone vào danh sách cho phép. Hoặc đăng nhập lại thủ công.

**Muốn xoá sạch mọi thứ**
```bash
rm -rf "/Applications/Chrome Cá nhân.app" "/Applications/Chrome Việc.app"
rm -rf ~/Library/Application\ Support/Chrome-canhan ~/Library/Application\ Support/Chrome-viec
killall Dock
```
Chrome gốc và data gốc không bị ảnh hưởng.

---

---

# Telegram

Cùng nguyên lý với Chrome, nhưng **chỉ làm được với một trong hai bản Telegram trên máy**.

| | `/Applications/Telegram.app` | `/Applications/Telegram.localized/Telegram.app` |
|---|---|---|
| Loại | Telegram Desktop (tdesktop) | Telegram for macOS (native) |
| Bundle ID | `com.tdesktop.Telegram` | `ru.keepcoder.Telegram` |
| Sandbox | ❌ không | ✅ **có** |
| Đổi thư mục dữ liệu | ✅ flag `-workdir` chính thức | ❌ không có |
| Dữ liệu | `~/Library/Application Support/Telegram Desktop` | Group Container (team `6N38VWS5BX`) |
| **Clone được?** | ✅ **được** | ❌ **không** |

## Bản native KHÔNG clone được

Entitlements của nó gắn cứng Team ID `6N38VWS5BX`:

```
com.apple.security.app-sandbox
com.apple.security.application-groups  -> 6N38VWS5BX.ru.keepcoder.Telegram
keychain-access-groups                 -> 6N38VWS5BX.ru.keepcoder.Telegram
```

App sandboxed chỉ được dùng application-group có tiền tố bằng Team ID của chính nó. Bản clone
ký ad-hoc **không có Team ID** nên không thể khai group đó → mất sạch quyền đọc group container
→ app mở lên trắng trơn. Bỏ luôn entitlement sandbox cũng không cứu được, vì code gọi
`containerURL(forSecurityApplicationGroupIdentifier:)`, không có entitlement thì trả về `nil`.

Bản native chỉ dùng được account switcher có sẵn trong app.

## Telegram Desktop thì dễ hơn Chrome

- Không sandbox, không cờ `kill`, không `library-validation`
- Entitlements chỉ có 3 cái và **không cái nào gắn Team ID** → ad-hoc re-sign không mất gì.
  Không có vụ Keychain hỏi quyền hay passkey hỏng như Chrome.
- Có flag `-workdir` **chính thức** → không cần hack, chỉ cần wrapper để truyền tham số
  (double-click app không truyền được tham số dòng lệnh)
- Bẫy icon giống hệt Chrome: `CFBundleIconName = Icon` + `Assets.car` → phải xoá key

Dựng bằng `./build_telegram_apps.sh`, sửa mảng `APPS` ở đầu file:

```bash
APPS=(
  "Telegram 2|tg2|/đường/dẫn/ảnh.png"    # tên app|suffix|ảnh icon (bỏ trống = logo Telegram)
)
```

## ⚠️ Khác Chrome: KHÔNG được copy dữ liệu

Với Chrome, copy profile sang là giữ nguyên đăng nhập. **Với Telegram thì không.**

`tdata` chứa authorization key của phiên. Copy sang clone nghĩa là hai app dùng **chung một key**:
đăng xuất ở app này sẽ giết luôn phiên của app kia, và cả hai đều hiện đủ mọi tài khoản kèm
thông báo trùng lặp.

Nên mỗi app clone phải bắt đầu bằng `-workdir` **trắng** và **đăng nhập lại bằng số điện thoại**.
Không có cách vòng qua.

Đếm số tài khoản đang có:

```bash
ls -d ~/Library/Application\ Support/Telegram\ Desktop/tdata/user_data*   # tdesktop
ls -d ~/Library/Group\ Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore/account-*  # native
```

---

# Account Dock — app quản lý

**App macOS thật**, có icon riêng, Dock riêng, Cmd+Tab riêng:

```bash
./build_dashboard_app.sh     # dựng /Applications/Account Dock.app
open -a "Account Dock"       # hoặc ⌘Space → "Account Dock"
```

Viết bằng Swift + `WKWebView`. Giao diện là HTML nhưng **không có server, không port, không token** —
JS gọi thẳng sang Swift qua `WKScriptMessageHandler`. Không mở cổng mạng nào.

Kiểm tra nhanh không cần mở cửa sổ:
```bash
"/Applications/Account Dock.app/Contents/MacOS/Account Dock" --dump   # in trạng thái ra JSON
```

Các script build được copy vào `Contents/Resources/` nên nút **Build lại** vẫn chạy được
kể cả khi app đứng một mình, không cần thư mục này.

Hiện tất cả app clone + app gốc theo nhóm, mỗi thẻ có: tài khoản, dung lượng dữ liệu, phiên bản,
đã ghim Dock chưa, đang chạy hay không, và cảnh báo **cần build lại** khi app gốc đã update lên
phiên bản mới hơn clone. Nút **Mở / Thoát / Dữ liệu** cho từng app, **Build lại** cho từng nhóm,
chuột phải để **đổi tên hiển thị**.

Dữ liệu đọc trực tiếp từ máy mỗi 15 giây. App nào được coi là "được quản lý" thì tự dò:
có `chrome-wrapper` hoặc `tg-wrapper` trong `Contents/MacOS/`.

### Hiệu năng

`scan()` chạy lại mỗi 15 giây, nên hai phép đo đắt được cache:

| | Không cache | Có cache |
|---|---|---|
| `codesign --verify` (5 app) | 1.03s | cache theo `mtime` của bundle |
| `du -sh` | 0.10s | cache 5 phút |
| **Tổng `scan()`** | **~1.0s** | **0.088s** |

Bấm **Build lại** thì cache tự xoá để đo lại ngay. Đo bằng:
```bash
"/Applications/Account Dock.app/Contents/MacOS/Account Dock" --bench
```

## Giới hạn đã biết

Thẻ Telegram chỉ hiện **số slot tài khoản**, không hiện đã đăng nhập hay chưa.
`tdata` mã hoá, và tdesktop tạo sẵn `user_data` ngay lần chạy đầu dù chưa login —
`key_datas` (388B) lẫn `usertag` (8B) giống hệt nhau ở cả bản đã login lẫn bản trắng,
không có tín hiệu nào phân biệt được từ bên ngoài.

Cần dữ liệu cho script khác: `"/Applications/Account Dock.app/Contents/MacOS/Account Dock" --dump`

## File trong thư mục này

| File | Việc |
|---|---|
| `build_chrome_apps.sh` | **Cách 2** — dựng app Chrome độc lập thật. Chạy lại sau mỗi Chrome update. |
| `build_telegram_apps.sh` | Dựng app Telegram Desktop độc lập. Chạy lại sau mỗi Telegram update. |
| `AccountDock.swift` | **Account Dock** — app macOS: quét trạng thái + cầu nối JS↔Swift. |
| `AccountDockHTML.swift` | Giao diện của Account Dock (HTML/CSS/JS). Sửa giao diện ở đây. |
| `build_dashboard_app.sh` | Compile + đóng gói `.app` + tự vẽ icon + ký. |
| `make_icon.swift` | Ghép logo app + ảnh thành icon badge. Cả hai script trên đều dùng chung. |
| `find_chrome_profiles.sh` | Liệt kê profile đang có |
| `make_dist.sh` | Đóng gói zip để gửi cho người khác (tự gỡ file `.conf`). |
| `*.conf` | **Cấu hình riêng của từng máy.** Không commit, không chia sẻ. |
