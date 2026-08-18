// ============================================================================
//  Account Dock — app macOS quản lý các app clone đa tài khoản.
//
//  Giao diện dựng bằng WKWebView, nhưng KHÔNG có server/port/token:
//  JS gọi thẳng sang Swift qua WKScriptMessageHandler.
//
//  Build: ./build_dashboard_app.sh
// ============================================================================
import AppKit
import UniformTypeIdentifiers
import WebKit

// MARK: - Tiện ích

let HOME = FileManager.default.homeDirectoryForCurrentUser
let APPS = URL(fileURLWithPath: "/Applications")
let CHROME_DATA = HOME.appendingPathComponent("Library/Application Support/Google/Chrome")
let TG_NATIVE = HOME.appendingPathComponent("Library/Group Containers/6N38VWS5BX.ru.keepcoder.Telegram/appstore")

@discardableResult
func sh(_ launch: String, _ args: [String], timeout: TimeInterval = 60) -> String {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: launch)
    p.arguments = args
    let pipe = Pipe()
    p.standardOutput = pipe
    p.standardError = Pipe()
    do { try p.run() } catch { return "" }

    // Giới hạn thời gian thật. Không có nó thì một script build treo sẽ
    // khoá luôn hàng đợi và app đứng im mãi.
    let done = DispatchSemaphore(value: 0)
    var out = Data()
    DispatchQueue.global(qos: .utility).async {
        out = pipe.fileHandleForReading.readDataToEndOfFile()
        done.signal()
    }
    if done.wait(timeout: .now() + timeout) == .timedOut {
        p.terminate()
        _ = done.wait(timeout: .now() + 2)
    }
    p.waitUntilExit()
    return String(data: out, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
}

func infoPlist(_ app: URL) -> [String: Any] {
    let u = app.appendingPathComponent("Contents/Info.plist")
    guard let d = try? Data(contentsOf: u),
          let o = try? PropertyListSerialization.propertyList(from: d, format: nil) as? [String: Any]
    else { return [:] }
    return o
}

// MARK: - Cache cho những phép đo đắt
//
// scan() chạy lại mỗi 15 giây. Đo thực tế:
//   codesign --verify  ~1.03s cho 5 app (riêng Telegram 0.53s)
//   du -sh             ~0.10s
// Chạy lại cả hai mỗi 15 giây là đốt CPU/đĩa vô ích, vì:
//   - chữ ký chỉ đổi khi bundle được build lại  -> cache theo mtime của bundle
//   - dung lượng đổi chậm                        -> cache theo thời gian (5 phút)
// Trạng thái đang-chạy và ghim-Dock thì rẻ, vẫn tính mới mỗi lần.

private let cacheLock = NSLock()
private var sigCache: [String: (mtime: Double, ok: Bool)] = [:]
private var sizeCache: [String: (at: Double, value: String)] = [:]
private let SIZE_TTL: Double = 300

func mtimeOf(_ path: String) -> Double {
    let a = try? FileManager.default.attributesOfItem(atPath: path)
    return (a?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
}

func dirSize(_ p: URL?) -> String {
    guard let p, FileManager.default.fileExists(atPath: p.path) else { return "-" }
    let key = p.path
    let now = Date().timeIntervalSince1970
    cacheLock.lock()
    if let c = sizeCache[key], now - c.at < SIZE_TTL {
        cacheLock.unlock()
        return c.value
    }
    cacheLock.unlock()

    let out = sh("/usr/bin/du", ["-sh", key])
    let v = out.components(separatedBy: "\t").first ?? "-"
    cacheLock.lock(); sizeCache[key] = (now, v); cacheLock.unlock()
    return v
}

/// Chữ ký chỉ đổi khi bundle bị sửa -> lấy mtime làm khoá cache.
func signatureOK(_ appPath: String) -> Bool {
    let mt = mtimeOf(appPath)
    cacheLock.lock()
    if let c = sigCache[appPath], c.mtime == mt {
        cacheLock.unlock()
        return c.ok
    }
    cacheLock.unlock()

    let ok = sh("/usr/bin/codesign", ["--verify", appPath]).isEmpty
    cacheLock.lock(); sigCache[appPath] = (mt, ok); cacheLock.unlock()
    return ok
}

/// Sau khi build lại thì buộc đo lại ngay, không chờ TTL.
func clearCaches() {
    cacheLock.lock()
    sigCache.removeAll(); sizeCache.removeAll()
    cacheLock.unlock()
}

/// Đang chạy hay không — hỏi NSWorkspace theo bundle id, chính xác hơn pgrep.
func runningApp(_ bundleID: String?) -> NSRunningApplication? {
    guard let bundleID else { return nil }
    return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
}

/// Email + tên profile từ một user-data-dir của Chrome.
func chromeAccount(_ dataDir: URL) -> (String?, String?) {
    let pref = dataDir.appendingPathComponent("Default/Preferences")
    guard let d = try? Data(contentsOf: pref),
          let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    else { return (nil, nil) }
    let accs = o["account_info"] as? [[String: Any]] ?? []
    let email = accs.first?["email"] as? String
    let name = (o["profile"] as? [String: Any])?["name"] as? String
    return (email, name)
}

/// Số slot tài khoản Telegram.
/// KHÔNG suy ra được đã đăng nhập hay chưa: tdata mã hoá, và tdesktop tạo sẵn
/// `user_data` ngay lần chạy đầu dù chưa login — key_datas/usertag giống hệt nhau
/// ở cả bản đã login lẫn bản trắng.
func telegramSlots(_ workdir: URL) -> Int {
    let tdata = workdir.appendingPathComponent("tdata")
    let items = (try? FileManager.default.contentsOfDirectory(atPath: tdata.path)) ?? []
    return items.filter { $0.hasPrefix("user_data") }.count
}

func chromeProfiles() -> [[String: Any]] {
    let ls = CHROME_DATA.appendingPathComponent("Local State")
    guard let d = try? Data(contentsOf: ls),
          let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
          let cache = (o["profile"] as? [String: Any])?["info_cache"] as? [String: Any]
    else { return [] }
    return cache.map { k, v in
        let m = v as? [String: Any] ?? [:]
        return ["dir": k, "name": m["name"] as? String ?? "?",
                "email": m["user_name"] as? String ?? ""]
    }.sorted { ($0["dir"] as! String) < ($1["dir"] as! String) }
}

func dockPinned() -> String {
    sh("/usr/bin/defaults", ["read", "com.apple.dock", "persistent-apps"])
}

/// So khớp ĐƯỜNG DẪN ĐẦY ĐỦ, không phải tên.
/// Khớp theo tên sẽ báo nhầm khi một tên là tiền tố của tên khác:
/// "Telegram" là chuỗi con của "Telegram%202.app", và
/// "/Applications/Telegram.app" khác "/Applications/Telegram.localized/Telegram.app".
func isPinned(_ appPath: String, in dock: String) -> Bool {
    let enc = appPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? appPath
    return dock.contains("file://\(enc)/")
}

// MARK: - Tài khoản người dùng tự thêm

/// App clone thì tự dò được. Còn tài khoản người dùng tự thêm (Facebook, Shopee, …)
/// phải lưu lại. Ghi atomic để tắt app giữa chừng không hỏng file.
let STORE = HOME.appendingPathComponent("Library/Application Support/AccountDock/accounts.json")

/// Cả file: { "accounts": [...], "overrides": { "<id>": {name, identifier, note} } }
/// `accounts` là tài khoản tự thêm. `overrides` là tên do người dùng đặt cho
/// app dò được — app clone lấy tên từ tên file .app nên không sửa trực tiếp được.
func loadStore() -> [String: Any] {
    guard let d = try? Data(contentsOf: STORE),
          let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any]
    else { return ["accounts": [], "overrides": [:]] }
    var doc = o
    if doc["accounts"] == nil { doc["accounts"] = [] }
    if doc["overrides"] == nil { doc["overrides"] = [:] }
    return doc
}

func saveStore(_ doc: [String: Any]) {
    let dir = STORE.deletingLastPathComponent()
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    guard let d = try? JSONSerialization.data(withJSONObject: doc,
                                              options: [.prettyPrinted, .sortedKeys]) else { return }
    let tmp = STORE.appendingPathExtension("tmp")
    try? d.write(to: tmp)
    if FileManager.default.fileExists(atPath: STORE.path) {
        _ = try? FileManager.default.replaceItemAt(STORE, withItemAt: tmp)
    } else {
        try? FileManager.default.moveItem(at: tmp, to: STORE)
    }
}

func loadCustom() -> [[String: Any]] {
    loadStore()["accounts"] as? [[String: Any]] ?? []
}

/// Chỉ ghi phần accounts, giữ nguyên overrides.
func saveCustom(_ accounts: [[String: Any]]) {
    var doc = loadStore()
    doc["accounts"] = accounts
    saveStore(doc)
}

func loadOverrides() -> [String: [String: Any]] {
    loadStore()["overrides"] as? [String: [String: Any]] ?? [:]
}

/// Đặt tên riêng cho một app dò được. Truyền nil để khôi phục tên gốc.
func setOverride(_ id: String, _ fields: [String: Any]?) {
    var doc = loadStore()
    var ov = doc["overrides"] as? [String: [String: Any]] ?? [:]
    if let f = fields { ov[id] = f } else { ov.removeValue(forKey: id) }
    doc["overrides"] = ov
    saveStore(doc)
}

/// Áp tên người dùng đặt lên một item dò được.
func applyOverride(_ item: inout [String: Any], _ ov: [String: [String: Any]]) {
    guard let id = item["id"] as? String, let o = ov[id] else { return }
    if let n = o["name"] as? String, !n.isEmpty {
        item["orig_name"] = item["name"]
        item["name"] = n
    }
    if let h = o["identifier"] as? String, !h.isEmpty { item["handle"] = h }
    if let note = o["note"] as? String, !note.isEmpty { item["sub"] = note }
    item["renamed"] = true
}

/// Mở theo cấu hình: app / url / cmd.
func runLaunch(_ cfg: [String: Any]) {
    switch cfg["kind"] as? String ?? "app" {
    case "url":
        guard let u = cfg["url"] as? String else { return }
        if let via = cfg["via"] as? String, !via.isEmpty {
            _ = sh("/usr/bin/open", ["-a", via, u])
        } else {
            _ = sh("/usr/bin/open", [u])
        }
    case "cmd":
        guard let c = cfg["cmd"] as? [String], let first = c.first else { return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: first)
        p.arguments = Array(c.dropFirst())
        try? p.run()
    default:
        guard let a = cfg["app"] as? String else { return }
        _ = sh("/usr/bin/open", ["-a", a])
    }
}

/// Nhóm hiển thị của một dịch vụ.
func groupOf(_ service: String) -> String {
    ["google": "google", "telegram": "telegram"][service] ?? "other"
}

// MARK: - Quét trạng thái

let WRAPPERS = ["chrome-wrapper": "google", "tg-wrapper": "telegram"]
let BASE_APP = ["google": APPS.appendingPathComponent("Google Chrome.app"),
                "telegram": APPS.appendingPathComponent("Telegram.app")]

func scan() -> [String: Any] {
    let pinned = dockPinned()
    let overrides = loadOverrides()
    var items: [[String: Any]] = []
    var activity: [[String: Any]] = []
    let fm = FileManager.default

    let all = (try? fm.contentsOfDirectory(atPath: APPS.path))?.sorted() ?? []
    for entry in all where entry.hasSuffix(".app") {
        let app = APPS.appendingPathComponent(entry)
        guard let wrapper = WRAPPERS.keys.first(where: {
            fm.fileExists(atPath: app.appendingPathComponent("Contents/MacOS/\($0)").path)
        }) else { continue }

        let group = WRAPPERS[wrapper]!
        let name = String(entry.dropLast(4))
        let wtext = (try? String(contentsOf: app.appendingPathComponent("Contents/MacOS/\(wrapper)"),
                                encoding: .utf8)) ?? ""

        var dataDir: URL? = nil
        if let r = wtext.range(of: #"(?:--user-data-dir=|-workdir )"([^"]+)""#,
                               options: .regularExpression) {
            let m = String(wtext[r])
            if let q1 = m.firstIndex(of: "\""), let q2 = m.lastIndex(of: "\""), q1 < q2 {
                dataDir = URL(fileURLWithPath: String(m[m.index(after: q1)..<q2]))
            }
        }

        var handle: String? = nil, sub: String? = nil
        if let dd = dataDir {
            if group == "google" {
                let (e, n) = chromeAccount(dd); handle = e; sub = n
            } else {
                let n = telegramSlots(dd); handle = "\(n) slot tài khoản"
            }
        }

        let info = infoPlist(app)
        let bid = info["CFBundleIdentifier"] as? String
        let cver = info["CFBundleShortVersionString"] as? String
        let bver = infoPlist(BASE_APP[group]!)["CFBundleShortVersionString"] as? String
        let sigOK = signatureOK(app.path)

        if let dd = dataDir,
           let at = try? fm.attributesOfItem(atPath: dd.path),
           let mt = at[.modificationDate] as? Date {
            activity.append(["name": name, "ts": mt.timeIntervalSince1970])
        }

        var it: [String: Any] = [
            "id": "app:" + app.path, "service": group, "custom": false,
            "name": name, "group": group, "app_path": app.path,
            "bundle_id": bid ?? "", "handle": handle ?? "", "sub": sub ?? "",
            "data_dir": dataDir?.path ?? "", "size": dirSize(dataDir),
            "running": runningApp(bid) != nil,
            "version": cver ?? "", "base_version": bver ?? "",
            "needs_rebuild": (cver != nil && bver != nil && cver != bver),
            "signature_ok": sigOK,
            "pinned": isPinned(app.path, in: pinned),
            "is_base": false, "locked": false,
        ]
        applyOverride(&it, overrides)
        items.append(it)
    }

    // App gốc
    for (group, base) in BASE_APP where fm.fileExists(atPath: base.path) {
        let name = base.deletingPathExtension().lastPathComponent
        let info = infoPlist(base)
        let bid = info["CFBundleIdentifier"] as? String
        var handle = "", sub = "", dd = CHROME_DATA
        if group == "google" {
            handle = "nhiều profile"; sub = "\(chromeProfiles().count) profile"
        } else {
            dd = HOME.appendingPathComponent("Library/Application Support/Telegram Desktop")
            handle = "\(telegramSlots(dd)) slot tài khoản"
        }
        var it: [String: Any] = [
            "id": "app:" + base.path, "service": group, "custom": false,
            "name": name, "group": group, "app_path": base.path,
            "bundle_id": bid ?? "", "handle": handle, "sub": sub,
            "data_dir": dd.path, "size": dirSize(dd),
            "running": runningApp(bid) != nil,
            "version": info["CFBundleShortVersionString"] as? String ?? "",
            "base_version": "", "needs_rebuild": false, "signature_ok": true,
            "pinned": isPinned(base.path, in: pinned),
            "is_base": true, "locked": false,
        ]
        applyOverride(&it, overrides)
        items.append(it)
    }

    // Telegram native — sandboxed, không tách được
    let native = APPS.appendingPathComponent("Telegram.localized/Telegram.app")
    if fm.fileExists(atPath: native.path) {
        let n = ((try? fm.contentsOfDirectory(atPath: TG_NATIVE.path)) ?? [])
            .filter { $0.hasPrefix("account-") }.count
        var it: [String: Any] = [
            "id": "app:" + native.path, "service": "telegram", "custom": false,
            "name": "Telegram (native)", "group": "telegram", "app_path": native.path,
            "bundle_id": "ru.keepcoder.Telegram",
            "handle": "sandboxed — không tách được", "sub": "\(n) tài khoản",
            "data_dir": TG_NATIVE.deletingLastPathComponent().path, "size": "—",
            "running": runningApp("ru.keepcoder.Telegram") != nil,
            "version": infoPlist(native)["CFBundleShortVersionString"] as? String ?? "",
            "base_version": "", "needs_rebuild": false, "signature_ok": true,
            "pinned": isPinned(native.path, in: pinned), "is_base": true, "locked": true,
        ]
        applyOverride(&it, overrides)
        items.append(it)
    }

    // Tài khoản người dùng tự thêm
    for c in loadCustom() {
        let svc = c["service"] as? String ?? "other"
        let cfg = c["launch"] as? [String: Any] ?? [:]
        var target = ""
        switch cfg["kind"] as? String ?? "app" {
        case "url": target = cfg["url"] as? String ?? ""
        case "cmd": target = (cfg["cmd"] as? [String] ?? []).joined(separator: " ")
        default:    target = cfg["app"] as? String ?? ""
        }
        let appOK = (cfg["kind"] as? String ?? "app") != "app"
            || fm.fileExists(atPath: cfg["app"] as? String ?? "")
        items.append([
            "id": c["id"] as? String ?? UUID().uuidString,
            "service": svc, "custom": true,
            "name": c["name"] as? String ?? "?", "group": groupOf(svc),
            "app_path": cfg["app"] as? String ?? "",
            "bundle_id": "", "handle": c["identifier"] as? String ?? "",
            "sub": c["note"] as? String ?? "",
            "data_dir": "", "size": "",
            "running": false,
            "version": "", "base_version": "", "needs_rebuild": false,
            "signature_ok": appOK, "pinned": false,
            "is_base": false, "locked": false,
            "target": target, "launch": cfg,
        ])
    }

    activity.sort { ($0["ts"] as! Double) > ($1["ts"] as! Double) }
    return ["items": items, "activity": Array(activity.prefix(6)),
            "generated": Date().timeIntervalSince1970]
}

// MARK: - Cầu nối JS <-> Swift

final class Bridge: NSObject, WKScriptMessageHandler {
    weak var web: WKWebView?
    /// Thư mục chứa các script build — cạnh app bundle hoặc trong Resources.
    var scriptDir: URL

    init(scriptDir: URL) { self.scriptDir = scriptDir }

    func reply(_ id: Any, _ payload: Any) {
        guard let d = try? JSONSerialization.data(withJSONObject: payload,
                                                  options: [.fragmentsAllowed]),
              let s = String(data: d, encoding: .utf8) else { return }
        let idJS = (id as? String).map { "\"\($0)\"" } ?? "\(id)"
        DispatchQueue.main.async {
            self.web?.evaluateJavaScript("window.__reply(\(idJS), \(s))")
        }
    }

    /// Chỉ cho thao tác trên app nằm trong /Applications.
    func allowed(_ path: String) -> Bool {
        URL(fileURLWithPath: path).resolvingSymlinksInPath().path.hasPrefix("/Applications/")
    }

    func userContentController(_ c: WKUserContentController, didReceive msg: WKScriptMessage) {
        guard let body = msg.body as? [String: Any],
              let id = body["id"], let action = body["action"] as? String else { return }
        let arg = body["payload"] as? [String: Any] ?? [:]
        let appPath = arg["app"] as? String ?? ""

        switch action {
        case "state":
            DispatchQueue.global(qos: .userInitiated).async { self.reply(id, scan()) }

        case "open":
            // Tài khoản tự thêm: mở theo cấu hình launch của nó.
            if let aid = arg["id"] as? String,
               let acc = loadCustom().first(where: { ($0["id"] as? String) == aid }) {
                runLaunch(acc["launch"] as? [String: Any] ?? [:])
                return reply(id, ["ok": true])
            }
            guard allowed(appPath) else { return reply(id, ["ok": false, "error": "đường dẫn không hợp lệ"]) }
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: appPath),
                                               configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                self.reply(id, ["ok": true])
            }

        case "save":
            // Thêm mới (không có id) hoặc sửa (có id).
            guard var acc = arg["account"] as? [String: Any] else {
                return reply(id, ["ok": false, "error": "thiếu dữ liệu"])
            }
            var list = loadCustom()
            if let aid = acc["id"] as? String, !aid.isEmpty,
               let i = list.firstIndex(where: { ($0["id"] as? String) == aid }) {
                list[i] = acc
            } else {
                acc["id"] = UUID().uuidString
                list.append(acc)
            }
            saveCustom(list)
            reply(id, ["ok": true])

        case "rename":
            // Đặt tên riêng cho app dò được (tên gốc lấy từ tên file .app / profile Chrome).
            guard let aid = arg["id"] as? String else { return reply(id, ["ok": false]) }
            var f: [String: Any] = [:]
            for k in ["name", "identifier", "note"] {
                if let v = arg[k] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty {
                    f[k] = v
                }
            }
            setOverride(aid, f.isEmpty ? nil : f)
            reply(id, ["ok": true])

        case "resetName":
            guard let aid = arg["id"] as? String else { return reply(id, ["ok": false]) }
            setOverride(aid, nil)
            reply(id, ["ok": true])

        case "delete":
            guard let aid = arg["id"] as? String else { return reply(id, ["ok": false]) }
            saveCustom(loadCustom().filter { ($0["id"] as? String) != aid })
            setOverride(aid, nil)
            reply(id, ["ok": true])

        case "reorder":
            guard let src = arg["src"] as? String, let dst = arg["dst"] as? String else {
                return reply(id, ["ok": false])
            }
            var list = loadCustom()
            guard let si = list.firstIndex(where: { ($0["id"] as? String) == src }),
                  let di = list.firstIndex(where: { ($0["id"] as? String) == dst })
            else { return reply(id, ["ok": false]) }
            let moved = list.remove(at: si)
            list.insert(moved, at: di)
            saveCustom(list)
            reply(id, ["ok": true])

        case "pickApp":
            DispatchQueue.main.async {
                let panel = NSOpenPanel()
                panel.directoryURL = APPS
                panel.allowedContentTypes = [.application]
                panel.allowsMultipleSelection = false
                panel.canChooseDirectories = false
                let r = panel.runModal()
                self.reply(id, ["ok": r == .OK, "path": panel.url?.path ?? ""])
            }

        case "quit":
            guard allowed(appPath) else { return reply(id, ["ok": false]) }
            let bid = infoPlist(URL(fileURLWithPath: appPath))["CFBundleIdentifier"] as? String
            runningApp(bid)?.terminate()
            reply(id, ["ok": true])

        case "reveal":
            let p = arg["path"] as? String ?? ""
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue {
                NSWorkspace.shared.open(URL(fileURLWithPath: p))
            }
            reply(id, ["ok": true])

        case "rebuild":
            let group = arg["group"] as? String ?? ""
            let script = ["google": "build_chrome_apps.sh",
                          "telegram": "build_telegram_apps.sh"][group]
            guard let script else { return reply(id, ["ok": false, "error": "nhóm không hợp lệ"]) }
            let path = scriptDir.appendingPathComponent(script).path
            guard FileManager.default.fileExists(atPath: path) else {
                return reply(id, ["ok": false, "error": "không thấy \(script) cạnh app"])
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let log = sh("/bin/bash", [path], timeout: 900)
                clearCaches()
                self.reply(id, ["ok": true, "log": log])
            }

        default:
            reply(id, ["ok": false, "error": "hành động lạ"])
        }
    }
}

// MARK: - App

final class Delegate: NSObject, NSApplicationDelegate, WKNavigationDelegate {
    var win: NSWindow!
    var web: WKWebView!
    var bridge: Bridge!

    func applicationDidFinishLaunching(_ n: Notification) {
        // Script build nằm cạnh app, hoặc trong Resources của bundle
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        let inRes = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources")
        if FileManager.default.fileExists(atPath: inRes.appendingPathComponent("build_chrome_apps.sh").path) {
            dir = inRes
        }
        bridge = Bridge(scriptDir: dir)

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(bridge, name: "api")
        web = WKWebView(frame: .zero, configuration: cfg)
        web.navigationDelegate = self
        bridge.web = web
        if web.responds(to: Selector(("setInspectable:"))) { web.setValue(true, forKey: "inspectable") }

        win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1500, height: 900),
                       styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                       backing: .buffered, defer: false)
        win.title = "Account Dock"
        win.titlebarAppearsTransparent = true
        win.minSize = NSSize(width: 1120, height: 640)
        win.contentView = web
        win.center()
        win.makeKeyAndOrderFront(nil)

        web.loadHTMLString(HTML, baseURL: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ s: NSApplication) -> Bool { true }
}

@main
enum Main {
    static func main() {
        // Chế độ kiểm tra: in trạng thái ra JSON rồi thoát, không mở cửa sổ.
        //   /Applications/Account\ Dock.app/Contents/MacOS/Account\ Dock --dump
        // Đo scan() lặp lại trong CÙNG process — đúng cách app chạy thật (cache còn nóng).
        if CommandLine.arguments.contains("--bench") {
            for i in 1...4 {
                let t = Date()
                _ = scan()
                print(String(format: "  lần %d: %.3fs", i, -t.timeIntervalSinceNow))
            }
            exit(0)
        }

        if CommandLine.arguments.contains("--dump") {
            let d = try! JSONSerialization.data(withJSONObject: scan(), options: [.prettyPrinted, .sortedKeys])
            print(String(data: d, encoding: .utf8)!)
            exit(0)
        }

        let app = NSApplication.shared
        let d = Delegate()
        app.delegate = d
        app.setActivationPolicy(.regular)

        // Menu tối thiểu để ⌘Q / ⌘W / ⌘R hoạt động
        let menu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Về Account Dock", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Ẩn", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Thoát Account Dock", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        let winItem = NSMenuItem()
        let winMenu = NSMenu(title: "Cửa sổ")
        winMenu.addItem(withTitle: "Đóng", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        winMenu.addItem(withTitle: "Thu nhỏ", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        winItem.submenu = winMenu
        menu.addItem(winItem)
        app.mainMenu = menu

        app.run()
    }
}
