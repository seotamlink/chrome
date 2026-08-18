// Giao diện Account Dock — dark theme theo mockup.
// JS gọi Swift qua window.webkit.messageHandlers.api: không HTTP, không port, không token.
let HTML = #"""
<!doctype html><html lang="vi"><head><meta charset="utf-8">
<title>Account Dock</title>
<style>
:root{
  --bg:#0F131A; --sidebar:#11161E; --card:#171D26; --card-h:#1D2530; --line:#252E3A;
  --accent:#2F6BFF; --accent-soft:#16203A; --accent-txt:#9FC0FF;
  --ok:#3DDC84; --ok-bg:#12291D; --warn:#FFB020; --warn-bg:#2A210E; --bad:#FF5C5C; --bad-bg:#2B1518;
  --txt:#E8ECF2; --dim:#8B95A5; --faint:#5A6474;
}
*{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%}
body{background:var(--bg);color:var(--txt);overflow:hidden;
  font:13.5px/1.5 system-ui,-apple-system,sans-serif;-webkit-font-smoothing:antialiased}
button{font:inherit;color:inherit;border:0;background:none;cursor:default}
::-webkit-scrollbar{width:9px;height:9px}
::-webkit-scrollbar-thumb{background:var(--line);border-radius:5px}
::-webkit-scrollbar-thumb:hover{background:#38424F}
::-webkit-scrollbar-track{background:transparent}

.app{display:grid;grid-template-columns:230px 1fr 300px;height:100vh}
@media(max-width:1180px){.app{grid-template-columns:230px 1fr}.rail{display:none}}

/* ------------------------------------------------------------ sidebar -- */
.side{background:var(--sidebar);border-right:1px solid var(--line);
  padding:34px 14px 14px;display:flex;flex-direction:column;gap:3px}
.brand{display:flex;gap:11px;align-items:center;padding:0 6px 20px}
.brand .mark{width:30px;height:30px;border-radius:9px;background:var(--accent);
  display:flex;align-items:center;justify-content:center;gap:2.5px;flex:none}
.brand .mark i{width:5px;height:5px;border-radius:50%;background:#fff;opacity:.55}
.brand .mark i:nth-child(2){opacity:1;width:6px;height:6px}
.brand b{font-size:14.5px;font-weight:650;display:block}
.brand span{font-size:10.5px;color:var(--faint);letter-spacing:.05em}
.nav{display:flex;align-items:center;gap:11px;padding:9px 12px;border-radius:10px;
  color:var(--dim);font-size:13px;width:100%;text-align:left}
.nav:hover{background:var(--card);color:var(--txt)}
.nav.on{background:var(--accent-soft);color:var(--accent-txt);font-weight:600}
.nav .g{width:16px;text-align:center;font-size:13px;flex:none}
.seclbl{font-size:10px;letter-spacing:.12em;color:var(--faint);padding:16px 12px 5px;font-weight:600}
.side .grow{flex:1}
.chip{display:flex;align-items:center;gap:10px;background:var(--card);
  border:1px solid var(--line);border-radius:10px;padding:9px 11px}
.chip .av{width:30px;height:30px;border-radius:50%;background:#1B2E5C;color:var(--accent-txt);
  display:flex;align-items:center;justify-content:center;font-weight:650;font-size:13px;flex:none}
.chip b{font-size:12.5px;display:block}
.chip span{font-size:11px;color:var(--faint)}

/* --------------------------------------------------------------- main -- */
.main{display:flex;flex-direction:column;min-width:0;padding:32px 26px 14px}
.head{display:flex;align-items:center;gap:14px;margin-bottom:8px;flex-wrap:wrap}
.head h1{font-size:22px;font-weight:700;letter-spacing:-.01em}
.head p{font-size:12.5px;color:var(--dim);margin-top:3px}
.head .sp{flex:1}
.search{position:relative}
.search input{background:var(--card);border:1px solid var(--line);border-radius:9px;
  color:var(--txt);padding:9px 46px 9px 34px;width:270px;font:inherit;outline:none}
.search input:focus{border-color:var(--accent)}
.search .ico{position:absolute;left:12px;top:50%;transform:translateY(-50%);color:var(--faint)}
.search kbd{position:absolute;right:10px;top:50%;transform:translateY(-50%);
  background:var(--bg);border:1px solid var(--line);border-radius:5px;
  padding:1px 5px;font-size:10.5px;color:var(--faint);font-family:inherit}
.primary{background:var(--accent);color:#fff;border-radius:9px;padding:9px 15px;
  font-size:13px;font-weight:600;display:flex;align-items:center;gap:7px}
.primary:hover{background:#3F79FF}

.scroll{flex:1;overflow-y:auto;overflow-x:hidden;margin-top:16px;padding-right:4px}
.sec{margin-bottom:26px}
.sechead{display:flex;align-items:center;gap:10px;margin-bottom:12px}
.sechead .ico{width:22px;height:22px;border-radius:7px;display:flex;align-items:center;
  justify-content:center;font-size:12px;font-weight:700;color:#fff;flex:none}
.sechead h2{font-size:14.5px;font-weight:650}
.sechead .sp{flex:1}
.link{color:var(--dim);font-size:12.5px}
.link:hover{color:var(--accent-txt)}

.rowscroll{overflow-x:auto;overflow-y:hidden;padding-bottom:6px}
.row{display:flex;gap:12px;min-width:min-content}

.card{width:212px;height:206px;flex:none;background:var(--card);border:1px solid var(--line);
  border-radius:12px;padding:14px;display:flex;flex-direction:column;align-items:center;
  position:relative;transition:background .12s,border-color .12s}
.card:hover{background:var(--card-h);border-color:#33404F}
.card.drag{opacity:.4}
.card .dots{position:absolute;top:9px;right:9px;color:var(--faint);
  font-size:15px;line-height:1;padding:2px 5px;border-radius:5px}
.card .dots:hover{background:var(--bg);color:var(--txt)}
.avwrap{position:relative;margin:8px 0 10px}
.av{width:58px;height:58px;border-radius:50%;display:flex;align-items:center;
  justify-content:center;font-size:24px;font-weight:600}
.badge{position:absolute;right:-3px;bottom:-3px;width:22px;height:22px;border-radius:50%;
  display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;
  color:#fff;border:2.5px solid var(--card)}
.card:hover .badge{border-color:var(--card-h)}
.card b{font-size:13px;font-weight:600;text-align:center;max-width:100%;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.card .id{font-size:11.5px;color:var(--dim);text-align:center;max-width:100%;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap;margin-top:2px}
.card .foot{margin-top:auto;display:flex;gap:5px;align-items:center;flex-wrap:wrap;justify-content:center}
.pill{background:var(--ok-bg);color:var(--ok);border-radius:9px;padding:3px 9px;
  font-size:11px;font-weight:600;white-space:nowrap}
.pill.warn{background:var(--warn-bg);color:var(--warn)}
.pill.bad{background:var(--bad-bg);color:var(--bad)}
.open{background:var(--bg);border:1px solid var(--line);border-radius:9px;
  padding:5px 14px;font-size:12px;color:var(--dim);display:flex;align-items:center;gap:6px}
.open:hover{background:var(--accent);border-color:var(--accent);color:#fff}

.addcard{width:212px;height:206px;flex:none;border:1px dashed var(--line);border-radius:12px;
  display:flex;flex-direction:column;align-items:center;justify-content:center;gap:8px;
  color:var(--dim);font-size:12.5px;text-align:center}
.addcard:hover{border-color:var(--accent);background:var(--accent-soft);color:var(--accent-txt)}
.addcard .p{font-size:28px;line-height:1;color:var(--faint)}
.addcard:hover .p{color:var(--accent-txt)}
.empty{color:var(--faint);text-align:center;padding:50px 0;font-size:13px}

.foot{display:flex;align-items:center;gap:12px;padding-top:12px;border-top:1px solid var(--line);
  margin-top:6px;color:var(--faint);font-size:11.5px}
.foot .sp{flex:1}
.foot button{color:var(--faint);border-radius:6px;padding:3px 7px;font-size:13px}
.foot button:hover{background:var(--card);color:var(--txt)}

/* ---------------------------------------------------------------- rail -- */
.rail{padding:34px 22px 18px 0;overflow-y:auto;display:flex;flex-direction:column;gap:14px}
.panel{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:18px}
.panel h3{font-size:13.5px;font-weight:650;margin-bottom:10px}
.act{display:flex;gap:10px;align-items:center;padding:8px 0;border-bottom:1px solid var(--line)}
.act:last-of-type{border-bottom:0}
.act .t{flex:1;min-width:0}
.act .t b{font-size:12.5px;font-weight:500;display:block;
  overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.act .t span{font-size:11px;color:var(--faint)}
.act .d{width:8px;height:8px;border-radius:50%;flex:none}
.tips{list-style:none;display:flex;flex-direction:column;gap:9px}
.tips li{display:flex;gap:9px;font-size:11.5px;color:var(--dim);line-height:1.45}
.tips li::before{content:"•";color:var(--accent);flex:none}
.tips kbd{background:var(--bg);border:1px solid var(--line);border-radius:4px;
  padding:0 4px;font-size:10.5px;font-family:inherit}

/* -------------------------------------------------------------- dialog -- */
.mask{position:fixed;inset:0;background:#000A;display:none;align-items:center;
  justify-content:center;z-index:50}
.mask.on{display:flex}
.dlg{background:var(--bg);border:1px solid var(--line);border-radius:14px;padding:24px;
  width:440px;max-height:88vh;overflow-y:auto}
.dlg h2{font-size:17px;font-weight:700;margin-bottom:16px}
.f{margin-bottom:12px}
.f label{display:block;font-size:12px;color:var(--dim);margin-bottom:5px}
.f input,.f select,.f textarea{width:100%;background:var(--card);border:1px solid var(--line);
  border-radius:8px;color:var(--txt);padding:9px 10px;font:inherit;outline:none}
.f input:focus,.f select:focus,.f textarea:focus{border-color:var(--accent)}
.f textarea{resize:vertical;min-height:52px}
.f .withbtn{display:flex;gap:8px}
.ghost{background:var(--card);border:1px solid var(--line);border-radius:9px;
  padding:9px 16px;font-size:13px;color:var(--dim);white-space:nowrap}
.ghost:hover{background:var(--card-h);color:var(--txt)}
.dlgfoot{display:flex;gap:9px;justify-content:flex-end;margin-top:18px}
.err{color:var(--bad);font-size:12px;margin-top:9px;display:none}
.err.on{display:block}

.menu{position:fixed;background:var(--card);border:1px solid var(--line);border-radius:9px;
  padding:5px;z-index:60;display:none;min-width:172px;box-shadow:0 10px 30px #0008}
.menu.on{display:block}
.menu button{display:block;width:100%;text-align:left;padding:7px 12px;
  border-radius:6px;font-size:12.5px;color:var(--txt)}
.menu button:hover{background:var(--accent-soft);color:var(--accent-txt)}
.menu button.del:hover{background:var(--bad-bg);color:var(--bad)}
.menu hr{border:0;border-top:1px solid var(--line);margin:4px 8px}

#toast{position:fixed;bottom:20px;left:50%;transform:translateX(-50%);background:var(--card-h);
  border:1px solid var(--line);color:var(--txt);padding:9px 16px;border-radius:9px;
  font-size:12.5px;opacity:0;transition:opacity .2s;pointer-events:none;z-index:70}
#toast.on{opacity:1}
</style></head><body>

<div class="app">
  <aside class="side">
    <div class="brand">
      <div class="mark"><i></i><i></i><i></i></div>
      <div><b>Account Dock</b><span>DATDEPTRAI</span></div>
    </div>
    <button class="nav on" data-f="all"><span class="g">▦</span>Tổng quan</button>
    <button class="nav" data-f="google"><span class="g">G</span>Google</button>
    <button class="nav" data-f="telegram"><span class="g">✈</span>Telegram</button>
    <button class="nav" data-f="other"><span class="g">▣</span>Tiện ích khác</button>
    <button class="nav" data-f="settings"><span class="g">⚙</span>Cài đặt</button>
    <div class="seclbl">NHANH</div>
    <button class="nav" id="quickAdd"><span class="g">＋</span>Thêm tài khoản</button>
    <button class="nav" id="quickSync"><span class="g">↻</span>Đồng bộ</button>
    <div class="grow"></div>
    <div class="chip"><div class="av">A</div><div><b>Admin</b><span>Local</span></div></div>
  </aside>

  <main class="main">
    <div class="head">
      <div><h1 id="ttl">Tổng quan</h1><p id="sub">Quản lý tất cả tài khoản của bạn tại một nơi</p></div>
      <div class="sp"></div>
      <div class="search">
        <span class="ico">⌕</span>
        <input id="q" type="search" placeholder="Tìm kiếm tài khoản...">
        <kbd>⌘K</kbd>
      </div>
      <button class="primary" id="addBtn"><span>＋</span>Thêm tài khoản</button>
    </div>
    <div class="scroll" id="body"></div>
    <div class="foot">
      <button id="syncBtn">↻&nbsp; Đồng bộ dữ liệu: <span id="synced">—</span></button>
      <div class="sp"></div>
      <span>Phiên bản 1.0.0</span>
      <button title="Giao diện tối">🌙</button>
      <button title="Cài đặt" data-f="settings">⚙</button>
    </div>
  </main>

  <aside class="rail">
    <div class="panel">
      <h3>Hoạt động gần đây</h3>
      <div id="acts"></div>
    </div>
    <div class="panel">
      <h3>Mẹo sử dụng</h3>
      <ul class="tips">
        <li>Mỗi app là một phiên độc lập — <kbd>⌘Q</kbd> app này không tắt app kia.</li>
        <li>Chuột phải vào tài khoản để xem thêm tùy chọn.</li>
        <li>Kéo thả để sắp xếp thứ tự (tài khoản tự thêm).</li>
        <li>Telegram chỉ hiện <b>số slot</b>, không hiện đã đăng nhập hay chưa.</li>
      </ul>
    </div>
  </aside>
</div>

<div class="mask" id="mask"><div class="dlg">
  <h2 id="dlgTtl">Thêm tài khoản</h2>
  <div class="f"><label>Tên tài khoản</label><input id="fName" placeholder="Ví dụ: Facebook chính"></div>
  <div class="f" id="fSvcW"><label>Loại dịch vụ</label><select id="fSvc"></select></div>
  <div class="f"><label>Username / Email</label><input id="fId" placeholder="email@gmail.com hoặc @username"></div>
  <div class="f" id="fKindW"><label>Cách mở</label><select id="fKind">
    <option value="app">Mở app (.app)</option>
    <option value="url">Mở đường dẫn web</option>
    <option value="cmd">Chạy lệnh</option></select></div>
  <div class="f" id="fTgtW"><label id="fTgtLbl">Đường dẫn app</label>
    <div class="withbtn"><input id="fTgt"><button class="ghost" id="fPick">Chọn…</button></div></div>
  <div class="f" id="fViaWrap"><label>Mở bằng trình duyệt</label><select id="fVia"></select></div>
  <div class="f"><label>Ghi chú</label><textarea id="fNote" placeholder="Tùy chọn"></textarea></div>
  <div class="err" id="fErr"></div>
  <div id="dlgHint" style="font-size:11.5px;color:var(--faint);margin-top:8px;display:none"></div>
  <div class="dlgfoot">
    <button class="ghost" id="dlgCancel">Hủy</button>
    <button class="primary" id="dlgSave">Thêm tài khoản</button>
  </div>
</div></div>

<div class="menu" id="menu"></div>
<div id="toast"></div>

<script>
/* ---------------------------------------------------------- cầu nối --- */
let __seq = 0; const __pending = {};
window.__reply = (id, data) => { const r = __pending[id]; if (r){ delete __pending[id]; r(data); } };
const api = (action, payload = {}) => new Promise(res => {
  const id = "m" + (++__seq); __pending[id] = res;
  window.webkit.messageHandlers.api.postMessage({ id, action, payload });
});

/* ------------------------------------------------------------ dữ liệu -- */
const SVC = {
  google:    {label:"Google",    color:"#4285F4", glyph:"G"},
  telegram:  {label:"Telegram",  color:"#2AABEE", glyph:"✈"},
  facebook:  {label:"Facebook",  color:"#1877F2", glyph:"f"},
  instagram: {label:"Instagram", color:"#E1306C", glyph:"◎"},
  shopee:    {label:"Shopee",    color:"#EE4D2D", glyph:"S"},
  other:     {label:"Khác",      color:"#8B95A5", glyph:"▣"},
};
const GROUPS = [
  ["google",   "Google",        "google"],
  ["telegram", "Telegram",      "telegram"],
  ["other",    "Tiện ích khác", "other"],
];
const PAGE = {
  all:      ["Tổng quan",     "Quản lý tất cả tài khoản của bạn tại một nơi"],
  google:   ["Google",        "Các tài khoản Google và profile Chrome"],
  telegram: ["Telegram",      "Các phiên Telegram Desktop độc lập"],
  other:    ["Tiện ích khác", "Facebook, Instagram, Shopee và dịch vụ khác"],
  settings: ["Cài đặt",       "Đường dẫn dữ liệu và thao tác bảo trì"],
};

let STATE = null, FILTER = "all", Q = "", EDITING = null, DRAG = null;
const esc = s => String(s ?? "").replace(/[&<>"]/g, c =>
  ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;"}[c]));
const toast = m => { const t = el("toast"); t.textContent = m;
  t.classList.add("on"); setTimeout(() => t.classList.remove("on"), 1900); };
const el = id => document.getElementById(id);

function ago(ts){
  const s = Math.max(0, Date.now()/1000 - ts);
  if (s < 90) return "vừa xong";
  if (s < 5400) return Math.round(s/60) + " phút trước";
  if (s < 172800) return Math.round(s/3600) + " giờ trước";
  return Math.round(s/86400) + " ngày trước";
}

/* -------------------------------------------------------------- render -- */
function cardHTML(it){
  const svc = SVC[it.service] || SVC.other;
  const initial = (it.name || "?").trim()[0].toUpperCase();
  const pills = [];
  if (it.running)        pills.push(`<span class="pill">● Đang hoạt động</span>`);
  if (it.needs_rebuild)  pills.push(`<span class="pill warn">cần build lại</span>`);
  if (!it.signature_ok)  pills.push(`<span class="pill bad">${it.custom ? "không thấy app" : "chữ ký hỏng"}</span>`);
  if (it.locked)         pills.push(`<span class="pill bad">không tách được</span>`);
  if (!pills.length)     pills.push(`<button class="open" data-act="open" data-id="${esc(it.id)}">▶ Mở</button>`);
  return `<div class="card" data-id="${esc(it.id)}" ${it.custom ? 'draggable="true"' : ""}>
    <button class="dots" data-act="menu" data-id="${esc(it.id)}">⋯</button>
    <div class="avwrap">
      <div class="av" style="background:${svc.color}33;color:${svc.color}">${esc(initial)}</div>
      <div class="badge" style="background:${svc.color}">${svc.glyph}</div>
    </div>
    <b title="${esc(it.name)}">${esc(it.name)}</b>
    <div class="id" title="${esc(it.handle)}">${esc(it.handle || "—")}</div>
    <div class="foot">${pills.join("")}</div>
  </div>`;
}

function render(){
  if (!STATE) return;
  const [t, s] = PAGE[FILTER]; el("ttl").textContent = t; el("sub").textContent = s;
  const q = Q.trim().toLowerCase();

  if (FILTER === "settings"){
    el("body").innerHTML = `<div class="panel"><h3>Cài đặt</h3>
      <ul class="tips">
        <li>Tài khoản tự thêm lưu ở <b>~/Library/Application Support/AccountDock/accounts.json</b></li>
        <li>App clone Chrome/Telegram được dò tự động, không cần thêm tay.</li>
        <li>Phím tắt: <kbd>⌘K</kbd> tìm · <kbd>⌘N</kbd> thêm · <kbd>⌘R</kbd> làm mới</li>
      </ul>
      <div style="display:flex;gap:9px;margin-top:16px">
        <button class="ghost" data-act="rebuild" data-group="google">Build lại Chrome</button>
        <button class="ghost" data-act="rebuild" data-group="telegram">Build lại Telegram</button>
      </div></div>`;
    return;
  }

  let html = "", total = 0;
  for (const [key, label, icoSvc] of GROUPS){
    if (FILTER !== "all" && FILTER !== key) continue;
    let list = (STATE.items || []).filter(i => i.group === key);
    if (q) list = list.filter(i =>
      (i.name + " " + (i.handle||"") + " " + (i.sub||"") + " " + i.service).toLowerCase().includes(q));
    total += list.length;
    const c = SVC[icoSvc] || SVC.other;
    html += `<section class="sec">
      <div class="sechead">
        <div class="ico" style="background:${c.color}">${c.glyph}</div>
        <h2>${label}</h2><div class="sp"></div>
        <button class="link" data-f="${key}">Xem tất cả (${list.length})</button>
      </div>
      <div class="rowscroll"><div class="row">
        ${list.map(cardHTML).join("")}
        <div class="addcard" data-act="add" data-svc="${icoSvc}">
          <div class="p">＋</div><div>Thêm<br>tài khoản</div></div>
      </div></div></section>`;
  }
  if (q && total === 0) html += `<div class="empty">Không tìm thấy tài khoản nào khớp “${esc(Q)}”.</div>`;
  el("body").innerHTML = html;

  el("acts").innerHTML = (STATE.activity || []).slice(0, 4).map(a => {
    const it = (STATE.items || []).find(i => i.name === a.name) || {};
    const c = SVC[it.service] || SVC.other;
    return `<div class="act"><div class="t"><b>${esc(a.name)}</b>
      <span>${ago(a.ts)}</span></div><div class="d" style="background:${c.color}"></div></div>`;
  }).join("") || `<div class="act"><div class="t"><span>Chưa có hoạt động</span></div></div>`;
  el("synced").textContent = ago(STATE.generated);
}

async function load(){ STATE = await api("state"); render(); }

/* -------------------------------------------------------------- dialog -- */
function fillSelects(){
  el("fSvc").innerHTML = Object.entries(SVC)
    .map(([k, v]) => `<option value="${k}">${v.glyph}  ${v.label}</option>`).join("");
  const browsers = (STATE?.items || []).filter(i => i.group === "google" && i.app_path);
  el("fVia").innerHTML = `<option value="">(trình duyệt mặc định)</option>` +
    browsers.map(b => `<option value="${esc(b.app_path)}">${esc(b.name)}</option>`).join("");
}

function syncKind(){
  const k = el("fKind").value;
  el("fTgtLbl").textContent =
    {app:"Đường dẫn app", url:"Đường dẫn web", cmd:"Lệnh (cách nhau bởi dấu cách)"}[k];
  el("fTgt").placeholder =
    {app:"/Applications/Chrome Cá nhân.app", url:"https://facebook.com", cmd:"/path/bin --flag"}[k];
  el("fPick").style.display = k === "app" ? "" : "none";
  el("fViaWrap").style.display = k === "url" ? "" : "none";
}

function openDialog(account, service){
  EDITING = account || null;
  // App dò được (Chrome/Telegram clone) chỉ cho sửa nhãn hiển thị —
  // cách mở của nó do chính bundle quyết định, sửa ở đây là vô nghĩa.
  const renameOnly = !!(account && !account.custom);
  for (const el2 of ["fSvcW","fKindW","fTgtW","fViaWrap"])
    { const n = document.getElementById(el2); if (n) n.style.display = renameOnly ? "none" : ""; }
  fillSelects();
  el("dlgTtl").textContent = renameOnly ? "Đổi tên hiển thị"
                           : account ? "Chỉnh sửa tài khoản" : "Thêm tài khoản";
  el("dlgSave").textContent = account ? "Lưu" : "Thêm tài khoản";
  el("dlgHint").style.display = renameOnly ? "" : "none";
  if (renameOnly) el("dlgHint").textContent =
    "Tên gốc: " + (account.orig_name || account.name) + " — chỉ đổi nhãn trong Account Dock, không đổi tên file .app.";
  const L = (account && account.launch) || {};
  el("fName").value = account?.name || "";
  el("fSvc").value  = account?.service || service || "facebook";
  el("fId").value   = account?.handle || "";
  el("fKind").value = L.kind || (service === "google" || service === "telegram" ? "app" : "url");
  el("fTgt").value  = L.app || L.url || (L.cmd || []).join(" ") || "";
  el("fVia").value  = L.via || "";
  el("fNote").value = account?.sub || "";
  el("fErr").classList.remove("on");
  syncKind();
  el("mask").classList.add("on");
  setTimeout(() => el("fName").focus(), 40);
}
const closeDialog = () => el("mask").classList.remove("on");

async function saveDialog(){
  const name = el("fName").value.trim(), tgt = el("fTgt").value.trim();
  if (!name) return fail("Chưa nhập tên tài khoản");
  if (EDITING && !EDITING.custom){
    const r = await api("rename", { id: EDITING.id, name,
                                    identifier: el("fId").value.trim(),
                                    note: el("fNote").value.trim() });
    if (!r || !r.ok) return fail("Không lưu được");
    closeDialog(); toast("Đã đổi tên"); return load();
  }
  if (!tgt)  return fail("Chưa nhập đường dẫn / lệnh để mở");
  const kind = el("fKind").value;
  const launch = { kind };
  if (kind === "app") launch.app = tgt;
  else if (kind === "url"){ launch.url = tgt; launch.via = el("fVia").value; }
  else launch.cmd = tgt.split(/\s+/);
  const acc = { name, service: el("fSvc").value, identifier: el("fId").value.trim(),
                note: el("fNote").value.trim(), launch };
  if (EDITING && EDITING.custom) acc.id = EDITING.id;
  const r = await api("save", { account: acc });
  if (!r || !r.ok) return fail((r && r.error) || "Không lưu được");
  closeDialog(); toast(EDITING ? "Đã lưu" : "Đã thêm tài khoản"); load();
}
function fail(m){ const e = el("fErr"); e.textContent = m; e.classList.add("on"); }

/* --------------------------------------------------------- menu chuột -- */
function showMenu(x, y, it){
  const m = el("menu");
  const rows = [`<button data-m="open">Mở</button>`];
  if (it.custom){
    rows.push(`<button data-m="edit">Chỉnh sửa</button>`);
    rows.push(`<hr><button class="del" data-m="del">Xóa</button>`);
  } else {
    rows.push(`<button data-m="edit">Đổi tên hiển thị</button>`);
    if (it.renamed) rows.push(`<button data-m="reset">Khôi phục tên gốc</button>`);
    if (it.data_dir) rows.push(`<button data-m="reveal">Mở thư mục dữ liệu</button>`);
    if (it.running)  rows.push(`<button data-m="quit">Thoát app</button>`);
  }
  m.innerHTML = rows.join("");
  m.dataset.id = it.id;
  m.classList.add("on");
  const r = m.getBoundingClientRect();
  m.style.left = Math.min(x, innerWidth - r.width - 8) + "px";
  m.style.top  = Math.min(y, innerHeight - r.height - 8) + "px";
}
const hideMenu = () => el("menu").classList.remove("on");
const byId = id => (STATE?.items || []).find(i => i.id === id);

/* ------------------------------------------------------------ sự kiện -- */
document.addEventListener("click", async e => {
  const nav = e.target.closest("[data-f]");
  if (nav){
    FILTER = nav.dataset.f;
    document.querySelectorAll(".nav[data-f]").forEach(n =>
      n.classList.toggle("on", n.dataset.f === FILTER));
    hideMenu(); return render();
  }
  const mi = e.target.closest("#menu button");
  if (mi){
    const it = byId(el("menu").dataset.id); hideMenu();
    if (!it) return;
    if (mi.dataset.m === "open")   { await api("open", {app: it.app_path, id: it.id}); toast("Đang mở…"); }
    if (mi.dataset.m === "quit")   { await api("quit", {app: it.app_path}); toast("Đang thoát…"); }
    if (mi.dataset.m === "reveal") { await api("reveal", {path: it.data_dir}); }
    if (mi.dataset.m === "edit")   { return openDialog(it); }
    if (mi.dataset.m === "reset")  { await api("resetName", {id: it.id}); toast("Đã khôi phục tên gốc"); }
    if (mi.dataset.m === "del"){
      if (!confirm(`Xóa “${it.name}” khỏi danh sách?\n\nChỉ xóa khỏi Account Dock — app và dữ liệu trên máy không bị đụng tới.`)) return;
      await api("delete", {id: it.id}); toast("Đã xóa");
    }
    return setTimeout(load, 400);
  }
  hideMenu();

  const b = e.target.closest("[data-act]");
  if (!b) {
    const card = e.target.closest(".card");
    if (card){ const it = byId(card.dataset.id);
      if (it){ await api("open", {app: it.app_path, id: it.id}); toast("Đang mở…"); setTimeout(load, 2000); } }
    return;
  }
  const act = b.dataset.act;
  if (act === "add")   return openDialog(null, b.dataset.svc);
  if (act === "menu"){ const r = b.getBoundingClientRect();
                       return showMenu(r.left, r.bottom + 4, byId(b.dataset.id)); }
  if (act === "open"){ const it = byId(b.dataset.id);
                       await api("open", {app: it.app_path, id: it.id});
                       toast("Đang mở…"); return setTimeout(load, 2000); }
  if (act === "rebuild"){ toast("Đang build lại, chờ chút…");
                          const r = await api("rebuild", {group: b.dataset.group});
                          toast(r && r.ok ? "Build xong" : "Lỗi: " + ((r && r.error) || "?"));
                          return load(); }
});

document.addEventListener("contextmenu", e => {
  const card = e.target.closest(".card");
  if (!card) return;
  e.preventDefault();
  const it = byId(card.dataset.id);
  if (it) showMenu(e.clientX, e.clientY, it);
});

/* --------------------------------------------------------- kéo thả ---- */
document.addEventListener("dragstart", e => {
  const c = e.target.closest(".card[draggable=true]");
  if (!c) return;
  DRAG = c.dataset.id; c.classList.add("drag");
  e.dataTransfer.effectAllowed = "move";
});
document.addEventListener("dragend", e => {
  document.querySelectorAll(".card.drag").forEach(c => c.classList.remove("drag"));
  DRAG = null;
});
document.addEventListener("dragover", e => {
  if (DRAG && e.target.closest(".card[draggable=true]")) e.preventDefault();
});
document.addEventListener("drop", async e => {
  const c = e.target.closest(".card[draggable=true]");
  if (!DRAG || !c || c.dataset.id === DRAG) return;
  e.preventDefault();
  await api("reorder", {src: DRAG, dst: c.dataset.id});
  load();
});

el("q").addEventListener("input", e => { Q = e.target.value; render(); });
el("addBtn").addEventListener("click", () => openDialog(null, "facebook"));
el("quickAdd").addEventListener("click", () => openDialog(null, "facebook"));
el("quickSync").addEventListener("click", () => { toast("Đang làm mới…"); load(); });
el("syncBtn").addEventListener("click", () => { toast("Đang làm mới…"); load(); });
el("dlgCancel").addEventListener("click", closeDialog);
el("dlgSave").addEventListener("click", saveDialog);
el("fKind").addEventListener("change", syncKind);
el("fPick").addEventListener("click", async () => {
  const r = await api("pickApp"); if (r && r.ok && r.path) el("fTgt").value = r.path;
});
el("mask").addEventListener("click", e => { if (e.target === el("mask")) closeDialog(); });

document.addEventListener("keydown", e => {
  if (e.metaKey && e.key === "k"){ e.preventDefault(); el("q").focus(); el("q").select(); }
  if (e.metaKey && e.key === "n"){ e.preventDefault(); openDialog(null, "facebook"); }
  if (e.metaKey && e.key === "r"){ e.preventDefault(); load(); }
  if (e.key === "Escape"){ closeDialog(); hideMenu(); }
});

load();
setInterval(load, 15000);
</script></body></html>
"""#
