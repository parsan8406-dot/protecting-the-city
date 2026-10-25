'use strict';
// پنل مدیریت بازی — بدون کتابخانه‌ی بیرونی.
// قانون امنیتی: هر متنی که از سرور می‌آید (نام، پیام، چت) فقط به‌صورت text node
// وارد صفحه می‌شود (تابع h)؛ هیچ‌جا innerHTML با دیتای کاربر ساخته نمی‌شود.

const $app = document.getElementById('app');
let ME = null;
const isAdmin = () => !!ME && ME.role === 'admin';

// ------------------------------------------------------------ DOM
function h(tag, attrs, ...kids) {
  const el = document.createElement(tag);
  if (attrs) {
    for (const [k, v] of Object.entries(attrs)) {
      if (v == null || v === false) continue;
      if (k === 'class') el.className = v;
      else if (k.startsWith('on') && typeof v === 'function') el.addEventListener(k.slice(2), v);
      else if (k === 'value') el.value = v;
      else if (k === 'checked') el.checked = !!v;
      else el.setAttribute(k, v === true ? '' : String(v));
    }
  }
  add(el, kids);
  return el;
}
function add(el, kids) {
  for (const k of [kids].flat(Infinity)) {
    if (k == null || k === false) continue;
    el.append(k instanceof Node ? k : String(k));
  }
  return el;
}
function clear(el) { while (el.firstChild) el.firstChild.remove(); return el; }
const SVGNS = 'http://www.w3.org/2000/svg';
function s(tag, attrs, ...kids) {
  const el = document.createElementNS(SVGNS, tag);
  for (const [k, v] of Object.entries(attrs || {})) el.setAttribute(k, String(v));
  add(el, kids);
  return el;
}

// ------------------------------------------------------------ API
function qs(obj) {
  const p = new URLSearchParams();
  for (const [k, v] of Object.entries(obj || {})) if (v !== '' && v != null) p.set(k, v);
  const str = p.toString();
  return str ? '?' + str : '';
}
async function api(path, body) {
  const opts = { credentials: 'same-origin', headers: {} };
  if (body !== undefined) {
    opts.method = 'POST';
    opts.headers['Content-Type'] = 'application/json';
    opts.headers['X-Admin-CSRF'] = ME ? ME.csrf : '';
    opts.body = JSON.stringify(body);
  }
  let res;
  try { res = await fetch('api/' + path, opts); }
  catch (e) { throw new Error('اتصال به سرور برقرار نشد'); }
  let data = null;
  try { data = await res.json(); } catch (e) { /* بدنه‌ی غیر JSON */ }
  if (res.status === 423) {
    ME = null;
    renderLocked((data && data.error) || 'پنل قفل است');
    throw new Error('پنل در قفل اضطراری است');
  }
  if (res.status === 401 && path !== 'login') {
    ME = null;
    renderLogin();
    throw new Error('نشست تمام شد — دوباره وارد شوید');
  }
  if (!res.ok) throw new Error((data && data.error) || ('خطای ' + res.status));
  return data;
}

// ------------------------------------------------------------ قالب‌بندی
const nf = new Intl.NumberFormat('fa-IR');
const fmtN = (n) => nf.format(Number(n) || 0);
const dtf = new Intl.DateTimeFormat('fa-IR-u-ca-persian', {
  year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', timeZone: 'Asia/Tehran',
});
const dayf = new Intl.DateTimeFormat('fa-IR-u-ca-persian', { month: 'numeric', day: 'numeric', timeZone: 'Asia/Tehran' });
function validDate(v) {
  if (!v) return null;
  const d = new Date(v);
  return isNaN(d) || d.getFullYear() < 2000 ? null : d;
}
function fmtDate(v) { const d = validDate(v); return d ? dtf.format(d) : '—'; }
function ago(v) {
  const d = validDate(v);
  if (!d) return '—';
  const sec = Math.round((Date.now() - d.getTime()) / 1000);
  const fut = sec < 0;
  const a = Math.abs(sec);
  let t;
  if (a < 60) t = 'چند ثانیه';
  else if (a < 3600) t = fmtN(Math.floor(a / 60)) + ' دقیقه';
  else if (a < 86400) t = fmtN(Math.floor(a / 3600)) + ' ساعت';
  else if (a < 86400 * 30) t = fmtN(Math.floor(a / 86400)) + ' روز';
  else return fmtDate(v);
  return fut ? t + ' دیگر' : t + ' پیش';
}
function when(v) { return h('span', { title: fmtDate(v), class: 'nowrap' }, ago(v)); }
function bytes(n) {
  const u = ['B', 'KB', 'MB', 'GB'];
  let i = 0; n = Number(n) || 0;
  while (n >= 1024 && i < u.length - 1) { n /= 1024; i++; }
  return nf.format(Math.round(n * 10) / 10) + ' ' + u[i];
}
function duration(sec) {
  sec = Number(sec) || 0;
  const d = Math.floor(sec / 86400), hh = Math.floor((sec % 86400) / 3600), m = Math.floor((sec % 3600) / 60);
  return [d && fmtN(d) + ' روز', hh && fmtN(hh) + ' ساعت', fmtN(m) + ' دقیقه'].filter(Boolean).join(' و ');
}
const pill = (text, cls) => h('span', { class: 'pill ' + (cls || '') }, text);
const avatar = (name, lg) => h('span', { class: 'avatar' + (lg ? ' lg' : '') }, (String(name || '?').trim()[0] || '?').toUpperCase());
const playerLink = (id, name) => id ? h('a', { href: '#/player/' + encodeURIComponent(id) }, name || id) : (name || '—');

const STATUS = {
  new: ['جدید', 'red'], read: ['خوانده‌شده', 'gold'], answered: ['پاسخ داده شد', 'green'], closed: ['بسته', ''],
};
const statusPill = (st) => pill((STATUS[st] || [st])[0], (STATUS[st] || [])[1]);
const STORE = { bazaar: 'بازار', myket: 'مایکت' };
const CHANNEL = { global: 'جهانی', city: 'شهر', private: 'خصوصی' };

// ------------------------------------------------------------ اعلان و پنجره
function toast(msg, err) {
  const t = h('div', { class: 'toast' + (err ? ' err' : '') }, msg);
  document.getElementById('toasts').append(t);
  setTimeout(() => t.remove(), err ? 6000 : 3500);
}
const fail = (e) => { if (e && e.message) toast(e.message, true); };

function modal(title, body, actions) {
  const back = h('div', { class: 'modal-back' });
  const close = () => { back.remove(); document.removeEventListener('keydown', onKey); };
  const onKey = (e) => { if (e.key === 'Escape') close(); };
  document.addEventListener('keydown', onKey);
  back.addEventListener('mousedown', (e) => { if (e.target === back) close(); });
  const box = h('div', { class: 'modal', role: 'dialog', 'aria-modal': 'true' }, h('h3', null, title), body);
  if (actions) box.append(h('div', { class: 'actions' }, actions(close)));
  back.append(box);
  document.body.append(back);
  const first = box.querySelector('input,textarea,select');
  if (first) first.focus();
  return close;
}

function confirmBox(title, text, okLabel, danger) {
  return new Promise((resolve) => {
    let done = false;
    const close = modal(title, h('p', { class: 'pre' }, text), (c) => [
      h('button', { class: 'btn ' + (danger ? 'primary' : 'gold'), onclick: () => { done = true; c(); resolve(true); } }, okLabel || 'تأیید'),
      h('button', { class: 'btn ghost', onclick: () => { c(); resolve(false); } }, 'انصراف'),
    ]);
    void close; void done;
  });
}

// fields: [{name,label,type,value,options,placeholder,hint,min,rows}]
function buildFields(fields) {
  const inputs = {};
  const rows = [];
  let row = null;
  const put = (n) => (row ? row.append(n) : rows.push(n));
  for (const f of fields) {
    if (f.type === 'row') { row = h('div', { class: 'row' }); rows.push(row); continue; }
    if (f.type === 'endrow') { row = null; continue; }
    let input;
    if (f.type === 'textarea') input = h('textarea', { class: 'input', placeholder: f.placeholder, rows: f.rows }, f.value || '');
    else if (f.type === 'select') {
      input = h('select', { class: 'input' }, f.options.map(([v, l]) => h('option', { value: v }, l)));
      if (f.value != null) input.value = f.value;
    } else if (f.type === 'check') {
      input = h('input', { type: 'checkbox', checked: f.value });
      inputs[f.name] = input;
      put(h('label', { class: 'check' }, input, f.label));
      continue;
    } else {
      input = h('input', { class: 'input', type: f.type || 'text', value: f.value ?? '', placeholder: f.placeholder, min: f.min, list: f.list, dir: f.dir });
    }
    inputs[f.name] = input;
    const field = h('div', { class: 'field' }, h('label', null, f.label), input, f.hint ? h('small', { class: 'faint' }, f.hint) : null);
    put(field);
  }
  return { node: h('div', { class: 'form' }, rows), inputs };
}
function readFields(inputs) {
  const out = {};
  for (const [k, el] of Object.entries(inputs)) {
    if (el.type === 'checkbox') out[k] = el.checked;
    else if (el.type === 'number') out[k] = el.value === '' ? null : Number(el.value);
    else out[k] = el.value;
  }
  return out;
}
function formModal(title, fields, submitLabel, onSubmit, extra) {
  const { node, inputs } = buildFields(fields);
  modal(title, [extra || null, node], (close) => {
    const btn = h('button', { class: 'btn primary' }, submitLabel);
    btn.addEventListener('click', async () => {
      btn.disabled = true;
      try { await onSubmit(readFields(inputs), inputs); close(); }
      catch (e) { fail(e); }
      finally { btn.disabled = false; }
    });
    return [btn, h('button', { class: 'btn ghost', onclick: close }, 'انصراف')];
  });
  return inputs;
}

// ------------------------------------------------------------ جدول و صفحه‌بندی
function table(cols, rows, onRow) {
  if (!rows || !rows.length) return h('div', { class: 'table-wrap' }, h('div', { class: 'empty' }, 'موردی نیست'));
  return h('div', { class: 'table-wrap' }, h('table', null,
    h('thead', null, h('tr', null, cols.map((c) => h('th', { class: c.n ? 'n' : null }, c.t)))),
    h('tbody', null, rows.map((r) => h('tr', { class: onRow ? 'click' : null, onclick: onRow ? (e) => { if (!e.target.closest('button,a')) onRow(r); } : null },
      cols.map((c) => h('td', { class: c.n ? 'n' : null }, c.v(r))))))));
}
function pager(page, size, total, go) {
  const pages = Math.max(1, Math.ceil((total || 0) / size));
  return h('div', { class: 'pager' },
    h('span', null, fmtN(total) + ' مورد — صفحه‌ی ' + fmtN(page) + ' از ' + fmtN(pages)),
    h('div', { class: 'btns' },
      h('button', { class: 'btn sm', disabled: page <= 1, onclick: () => go(page - 1) }, 'قبلی'),
      h('button', { class: 'btn sm', disabled: page >= pages, onclick: () => go(page + 1) }, 'بعدی')));
}
const loading = () => h('div', { class: 'loading' }, h('span', { class: 'spin' }));
function card(title, ...kids) { return h('div', { class: 'card' }, title ? h('h2', null, title) : null, kids); }
function stat(label, value, foot, cls) {
  return h('div', { class: 'card stat ' + (cls || '') }, h('div', { class: 'label' }, label), h('div', { class: 'value' }, value), foot ? h('div', { class: 'foot' }, foot) : null);
}
function debounce(fn, ms) { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; }

// ------------------------------------------------------------ نمودار ستونی
function barChart(points, cls) {
  const W = 600, H = 170, pad = { t: 16, r: 6, b: 22, l: 34 };
  const max = Math.max(1, ...points.map((p) => p.value));
  const nice = Math.pow(10, Math.floor(Math.log10(max)));
  const top = Math.ceil(max / nice) * nice;
  const iw = W - pad.l - pad.r, ih = H - pad.t - pad.b;
  const bw = iw / points.length;
  const svg = s('svg', { class: 'chart', viewBox: `0 0 ${W} ${H}`, role: 'img' });
  for (const f of [0, 0.5, 1]) {
    const y = pad.t + ih - ih * f;
    svg.append(s('line', { class: 'grid-line', x1: pad.l, x2: W - pad.r, y1: y, y2: y }));
    svg.append(s('text', { class: 'axis', x: pad.l - 6, y: y + 3, 'text-anchor': 'end' }, fmtN(Math.round(top * f))));
  }
  points.forEach((p, i) => {
    const bh = (p.value / top) * ih;
    const x = pad.l + i * bw + bw * 0.18;
    const rect = s('rect', { class: 'bar ' + (cls || ''), x, y: pad.t + ih - bh, width: bw * 0.64, height: Math.max(bh, p.value ? 1.5 : 0), rx: 2 },
      s('title', null, p.label + ': ' + fmtN(p.value)));
    svg.append(rect);
    if (i % 2 === points.length % 2 || points.length <= 8) {
      svg.append(s('text', { class: 'axis', x: x + bw * 0.32, y: H - 6, 'text-anchor': 'middle' }, p.label));
    }
  });
  return svg;
}
const dayLabel = (day) => dayf.format(new Date(day + 'T12:00:00+03:30'));
const seriesOf = (rows, key) => (rows || []).map((r) => ({ label: dayLabel(r.day), value: Number(r[key]) || 0 }));

// ------------------------------------------------------------ ورود
function renderLogin(msg) {
  clear($app);
  const user = h('input', { class: 'input', autocomplete: 'username', dir: 'ltr', placeholder: 'نام کاربری' });
  const pass = h('input', { class: 'input', type: 'password', autocomplete: 'current-password', dir: 'ltr', placeholder: 'رمز عبور' });
  const code = h('input', { class: 'input', inputmode: 'numeric', autocomplete: 'one-time-code', dir: 'ltr', maxlength: 6, placeholder: '۶ رقم از اپ Authenticator' });
  const err = h('div', { class: 'err' }, msg || '');
  const btn = h('button', { class: 'btn primary', type: 'submit' }, 'ورود');
  const form = h('form', { class: 'form' }, h('div', { class: 'field' }, h('label', null, 'نام کاربری'), user),
    h('div', { class: 'field' }, h('label', null, 'رمز عبور'), pass),
    h('div', { class: 'field' }, h('label', null, 'کد دومرحله‌ای'), code), err, btn);
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    btn.disabled = true; err.textContent = '';
    try {
      ME = await api('login', { username: user.value.trim(), password: pass.value, code: toLatinDigits(code.value.trim()) });
      pass.value = ''; code.value = '';
      boot();
    } catch (ex) { err.textContent = ex.message; code.value = ''; } finally { btn.disabled = false; }
  });
  $app.append(h('div', { class: 'login' }, h('div', { class: 'box' },
    h('div', { class: 'brand-mark' }, 'G'), h('h1', null, 'پنل مدیریت'), h('p', null, 'مدیریت بازیکن‌ها، پیام‌ها و پشتیبانی'), form,
    h('button', { class: 'btn danger panic-link', onclick: () => panicFlow(true) }, 'هک شدم — قفل اضطراری با کلید'))));
  user.focus();
}

const toLatinDigits = (v) => v.replace(/[۰-۹]/g, (d) => '۰۱۲۳۴۵۶۷۸۹'.indexOf(d)).replace(/[٠-٩]/g, (d) => '٠١٢٣٤٥٦٧٨٩'.indexOf(d));

function renderLocked(msg) {
  clear($app);
  $app.append(h('div', { class: 'login' }, h('div', { class: 'box locked' },
    h('div', { class: 'brand-mark' }, '!'), h('h1', null, 'قفل اضطراری'),
    h('p', null, msg || 'پنل قفل شده و همه‌ی ادمین‌ها بیرون انداخته شده‌اند.'),
    h('ol', { class: 'steps' },
      h('li', null, 'به سرور SSH بزنید.'),
      h('li', null, 'رمزها، کدهای دومرحله‌ای و کلید اضطراری را در ‎/opt/gungame/.env‎ عوض کنید.'),
      h('li', null, h('span', { class: 'mono' }, 'cd /opt/gungame && ./gun_game_server admin-unlock')),
      h('li', null, h('span', { class: 'mono' }, 'systemctl restart gungame'))))));
}

// panicFlow دکمه‌ی «هک شدم». از داخل پنل با نشستِ فعلی، از صفحه‌ی ورود با کلید اضطراری.
function panicFlow(fromLogin) {
  const fields = [];
  if (fromLogin) fields.push({ name: 'panic_key', label: 'کلید اضطراری', type: 'password', dir: 'ltr' });
  fields.push(
    { name: 'reason', label: 'چه اتفاقی افتاده؟ (اختیاری)' },
    { name: 'disable_gift_codes', label: 'همه‌ی کدهای هدیه غیرفعال شوند', type: 'check', value: true },
    { name: 'revoke_recent_rewards', label: 'پیام‌های جایزه‌دارِ دریافت‌نشده‌ی ۲۴ ساعت اخیر پاک شوند', type: 'check', value: true },
    { name: 'confirm', label: 'برای تأیید بنویسید: قفل', placeholder: 'قفل' },
  );
  const warn = h('div', { class: 'banner red' },
    'همه‌ی ادمین‌ها (از جمله خودتان) همین الان بیرون انداخته می‌شوند و ورود به پنل بسته می‌شود. ',
    'بازی برای بازیکن‌ها عادی کار می‌کند. باز کردن قفل فقط از روی خودِ سرور ممکن است.');
  formModal('قفل اضطراری', fields, 'قفل کن', async (v) => {
    if (v.confirm.trim() !== 'قفل') throw new Error('برای تأیید باید «قفل» را بنویسید');
    const opts = { credentials: 'same-origin', method: 'POST', headers: { 'Content-Type': 'application/json' } };
    if (ME) opts.headers['X-Admin-CSRF'] = ME.csrf;
    opts.body = JSON.stringify({
      panic_key: v.panic_key || '', reason: v.reason, disable_gift_codes: v.disable_gift_codes,
      revoke_recent_rewards: v.revoke_recent_rewards, revoke_hours: 24,
    });
    const res = await fetch('api/panic', opts);
    let data = null;
    try { data = await res.json(); } catch (e) { /* */ }
    if (!res.ok) throw new Error((data && data.error) || ('خطای ' + res.status));
    ME = null;
    const parts = ['پنل قفل شد.'];
    if (data.gift_codes_disabled != null) parts.push(fmtN(data.gift_codes_disabled) + ' کد هدیه غیرفعال شد.');
    if (data.reward_messages_deleted != null) parts.push(fmtN(data.reward_messages_deleted) + ' پیام جایزه‌دار پاک شد.');
    renderLocked(parts.join(' '));
  }, warn);
}

// ------------------------------------------------------------ قاب اصلی و مسیریابی
const NAV = [
  ['کلی'],
  ['dashboard', 'داشبورد', viewDashboard],
  ['online', 'آنلاین‌ها', viewOnline],
  ['بازیکن‌ها'],
  ['players', 'بازیکن‌ها', viewPlayers],
  ['support', 'پشتیبانی', viewSupport],
  ['messages', 'ارسال پیام', viewMessages],
  ['chat', 'نظارت چت', viewChat],
  ['clans', 'شهرها', viewClans],
  ['اقتصاد و بازی'],
  ['purchases', 'خریدها', viewPurchases],
  ['gifts', 'کد هدیه', viewGifts],
  ['shop', 'فروشگاه', viewShop],
  ['modes', 'حالت‌های بازی', viewModes],
  ['سیستم'],
  ['security', 'امنیت', viewSecurity],
  ['server', 'وضعیت سرور', viewServer],
  ['audit', 'تاریخچه‌ی ادمین‌ها', viewAudit, true],
];
const DETAIL = { player: viewPlayer, ticket: viewTicket, clan: viewClan };
let $main, $side, $supportBadge, refreshTimer;

function renderShell() {
  clear($app);
  $supportBadge = h('span', { class: 'badge hidden' });
  const nav = h('nav', { class: 'nav' });
  for (const item of NAV) {
    if (item.length === 1) { nav.append(h('div', { class: 'nav-group' }, item[0])); continue; }
    const [id, label, , adminOnly] = item;
    if (adminOnly && !isAdmin()) continue;
    nav.append(h('a', { href: '#/' + id, 'data-id': id }, label, id === 'support' ? $supportBadge : null));
  }
  nav.addEventListener('click', () => $side.classList.remove('open'));
  $side = h('aside', { class: 'side' },
    h('div', { class: 'brand' }, h('div', { class: 'brand-mark' }, 'G'), h('div', null, h('div', { class: 'brand-title' }, 'گان گیم'), h('div', { class: 'brand-sub' }, 'پنل مدیریت'))),
    nav,
    h('div', { class: 'side-foot' },
      h('div', null, h('b', null, ME.user), ' — ', ME.role === 'admin' ? 'مدیر کامل' : 'پشتیبانی'),
      h('div', { class: 'btns' },
        h('button', { class: 'btn sm ghost', onclick: logout }, 'خروج'),
        h('button', { class: 'btn sm danger', onclick: () => panicFlow(false) }, 'قفل اضطراری'))));
  $main = h('main', { class: 'main' });
  $app.append(h('div', { class: 'shell' }, $side, $main));
}

async function logout() {
  try { await api('logout', {}); } catch (e) { /* مهم نیست */ }
  ME = null;
  renderLogin('خارج شدید');
}

function topbar(title, sub, ...actions) {
  return h('div', { class: 'topbar' },
    h('button', { class: 'btn menu-btn', onclick: () => $side.classList.add('open'), 'aria-label': 'منو' }, '☰'),
    h('div', null, h('h1', null, title), sub ? h('div', { class: 'sub' }, sub) : null),
    h('div', { class: 'spacer' }), actions);
}

function route() {
  if (!ME) return;
  clearInterval(refreshTimer);
  const parts = location.hash.replace(/^#\/?/, '').split('/').map(decodeURIComponent);
  const name = parts[0] || 'dashboard';
  for (const a of $side.querySelectorAll('.nav a')) {
    const id = a.getAttribute('data-id');
    const on = id === name || (name === 'player' && id === 'players') || (name === 'ticket' && id === 'support') || (name === 'clan' && id === 'clans');
    a.classList.toggle('active', on);
  }
  const entry = NAV.find((n) => n[0] === name);
  const view = DETAIL[name] || (entry && entry[2]) || viewDashboard;
  clear($main).append(loading());
  window.scrollTo(0, 0);
  Promise.resolve(view(parts[1])).catch((e) => { clear($main).append(topbar('خطا'), card(null, h('p', null, e.message))); });
}

async function refreshSupportBadge() {
  try {
    const d = await api('support' + qs({ status: 'new', size: 1 }));
    const n = d.counts.new || 0;
    $supportBadge.textContent = fmtN(n);
    $supportBadge.classList.toggle('hidden', !n);
  } catch (e) { /* بی‌صدا */ }
}

async function boot() {
  try { ME = await api('me'); } catch (e) { if (!ME && !document.querySelector('.locked')) { renderLogin(); } return; }
  renderShell();
  refreshSupportBadge();
  setInterval(refreshSupportBadge, 60000);
  route();
}
window.addEventListener('hashchange', route);

// ================================================================ داشبورد
async function viewDashboard() {
  const d = await api('dashboard');
  const p = d.players, live = d.live, sup = d.support, eco = d.economy;
  const tickets = await api('support' + qs({ status: 'open', size: 6 }));
  clear($main).append(
    topbar('داشبورد', 'به‌روزرسانی: ' + fmtDate(d.generated_at), h('button', { class: 'btn', onclick: route }, 'تازه‌سازی')),
    h('div', { class: 'grid g4' },
      stat('آنلاین همین حالا', fmtN(live.online), live.ok ? fmtN(live.in_match) + ' نفر در مسابقه — ' + fmtN(live.rounds) + ' راند' : 'هاب پاسخ نداد', 'green'),
      stat('کل بازیکن‌ها', fmtN(p.total), '+' + fmtN(p.new_today) + ' امروز، +' + fmtN(p.new_week) + ' این هفته', 'gold'),
      stat('فعال ۲۴ ساعت', fmtN(p.active_day), fmtN(p.active_week) + ' نفر در ۷ روز'),
      stat('پیام پشتیبانی جدید', fmtN(sup.new), fmtN(sup.open) + ' باز — ' + fmtN(sup.week) + ' در این هفته', sup.new ? 'red' : '')),
    h('div', { class: 'grid g4' },
      stat('فروش ۲۴ ساعت', fmtN(eco.toman_day) + ' ت', fmtN(eco.purchases_day) + ' خرید — ' + fmtN(eco.gems_day) + ' قلب', 'gold'),
      stat('فروش ۷ روز', fmtN(eco.toman_week) + ' ت', fmtN(eco.purchases_week) + ' خرید — ' + fmtN(eco.gems_week) + ' قلب', 'gold'),
      stat('وصل به گوگل', fmtN(p.google), 'مسدود: ' + fmtN(p.banned)),
      stat('شهرها', fmtN(d.clans), fmtN(d.matches_week) + ' مسابقه‌ی ثبت‌شده در ۷ روز')),
    h('div', { class: 'grid g2' },
      card('ثبت‌نام روزانه', barChart(seriesOf(d.signups, 'count'))),
      card('بازیکن‌های فعال (آخرین بازدید)', barChart(seriesOf(d.active, 'count'), 'alt'))),
    h('div', { class: 'grid split' },
      card('پیام‌های پشتیبانیِ باز',
        tickets.tickets.length ? h('div', { class: 'list' }, tickets.tickets.map(ticketItem)) : h('div', { class: 'empty' }, 'همه‌ی پیام‌ها رسیدگی شده‌اند'),
        h('div', { class: 'btns' }, h('a', { class: 'btn sm', href: '#/support' }, 'همه‌ی پیام‌ها'))),
      h('div', { class: 'grid' },
        card('قلبِ فروخته‌شده (روزانه)', barChart(seriesOf(d.sales, 'sum'), 'alt')),
        card('پیام پشتیبانی (روزانه)', barChart(seriesOf(d.tickets, 'count'))))),
  );
  // داشبورد خودش هر ۳۰ ثانیه تازه می‌شود
  refreshTimer = setInterval(() => { if (location.hash.replace(/^#\/?/, '') === '' || location.hash === '#/dashboard') route(); }, 30000);
}

function ticketItem(t) {
  return h('div', { class: 'list-item' },
    h('div', { class: 'head' }, h('b', null, t.username), statusPill(t.status), when(t.created_at), t.platform ? pill(t.platform) : null),
    h('a', { href: '#/ticket/' + encodeURIComponent(t.ticket_id), class: 'pre' }, t.body.length > 180 ? t.body.slice(0, 180) + '…' : t.body));
}

// ================================================================ آنلاین‌ها
async function viewOnline() {
  const d = await api('online');
  const snap = d.snapshot;
  const kick = async (r) => {
    if (!r.player_id || !await confirmBox('قطع اتصال', 'اتصال «' + r.username + '» قطع شود؟ اگر وسط مسابقه باشد از راند خارج می‌شود.', 'قطع اتصال', true)) return;
    try { await api('player/kick', { player_id: r.player_id }); toast('قطع شد'); route(); } catch (e) { fail(e); }
  };
  clear($main).append(
    topbar('بازیکن‌های آنلاین', fmtN(snap.online) + ' نفر — ' + fmtN(snap.in_match) + ' در مسابقه', h('button', { class: 'btn', onclick: route }, 'تازه‌سازی')),
    h('div', { class: 'grid g4' },
      stat('اتصال باز', fmtN(snap.connections)), stat('وارد شده', fmtN(snap.online), null, 'green'),
      stat('راندهای در جریان', fmtN(snap.rounds), null, 'gold'), stat('بات فعال', fmtN(snap.bots))),
    card(null, table([
      { t: 'بازیکن', v: (r) => h('div', { class: 'who' }, avatar(r.username), playerLink(r.player_id, r.username)) },
      { t: 'وضعیت', v: (r) => r.match_id ? pill('در مسابقه' + (r.mode_id ? ' — ' + r.mode_id : ''), 'red') : pill('منو', 'green') },
      { t: 'مسابقه', v: (r) => h('span', { class: 'mono' }, r.match_id || '—') },
      { t: '', v: (r) => h('button', { class: 'btn sm danger', onclick: () => kick(r) }, 'قطع اتصال') },
    ], d.players, (r) => r.player_id && (location.hash = '#/player/' + encodeURIComponent(r.player_id)))),
  );
  refreshTimer = setInterval(() => { if (location.hash === '#/online') route(); }, 15000);
}

// ================================================================ لیست بازیکن‌ها
const playersState = { q: '', filter: '', sort: 'seen', page: 1 };
async function viewPlayers() {
  const st = playersState;
  const body = h('div');
  const load = async () => {
    clear(body).append(loading());
    try {
      const d = await api('players' + qs({ q: st.q, filter: st.filter, sort: st.sort, page: st.page }));
      clear(body).append(table([
        { t: 'بازیکن', v: (r) => h('div', { class: 'who' }, avatar(r.username), h('div', null, h('div', { class: 'name' }, r.username), h('div', { class: 'faint mono' }, r.player_id))) },
        { t: 'وضعیت', v: (r) => h('div', { class: 'btns' }, h('span', { class: 'dot' + (r.is_online ? ' on' : '') }), r.is_banned ? pill('مسدود', 'red') : null, r.google ? pill('گوگل', 'blue') : null, r.is_bot ? pill('بات') : null) },
        { t: 'سطح', n: 1, v: (r) => fmtN(r.level) },
        { t: 'کاپ', n: 1, v: (r) => fmtN(r.trophies) },
        { t: 'سکه', n: 1, v: (r) => fmtN(r.coins) },
        { t: 'قلب', n: 1, v: (r) => fmtN(r.gems) },
        { t: 'مسابقه', n: 1, v: (r) => fmtN(r.matches) },
        { t: 'آخرین بازدید', v: (r) => when(r.last_seen_at) },
        { t: 'عضویت', v: (r) => when(r.created_at) },
      ], d.players, (r) => { location.hash = '#/player/' + encodeURIComponent(r.player_id); }),
      pager(d.page, d.size, d.total, (p) => { st.page = p; load(); }));
    } catch (e) { clear(body); fail(e); }
  };
  const search = h('input', { class: 'input', placeholder: 'جستجو: نام، آیدی، ایمیل یا آیدی شهر', value: st.q });
  search.addEventListener('input', debounce(() => { st.q = search.value.trim(); st.page = 1; load(); }, 350));
  const filter = h('select', { class: 'input', onchange: (e) => { st.filter = e.target.value; st.page = 1; load(); } },
    [['', 'همه'], ['online', 'آنلاین'], ['new', 'ثبت‌نام ۲۴ ساعت'], ['google', 'وصل به گوگل'], ['guest', 'مهمان'], ['banned', 'مسدود'], ['muted', 'چت بسته'], ['bots', 'بات‌ها']].map(([v, l]) => h('option', { value: v }, l)));
  filter.value = st.filter;
  const sort = h('select', { class: 'input', onchange: (e) => { st.sort = e.target.value; st.page = 1; load(); } },
    [['seen', 'آخرین بازدید'], ['created', 'جدیدترین'], ['level', 'سطح'], ['trophies', 'کاپ'], ['coins', 'سکه'], ['gems', 'قلب'], ['matches', 'تعداد مسابقه']].map(([v, l]) => h('option', { value: v }, 'مرتب: ' + l)));
  sort.value = st.sort;
  clear($main).append(topbar('بازیکن‌ها'), card(null, h('div', { class: 'toolbar' }, search, filter, sort), body));
  load();
  search.focus();
}

// ================================================================ صفحه‌ی یک بازیکن
async function viewPlayer(id) {
  const d = await api('player' + qs({ player_id: id }));
  const p = d.player, mod = d.moderation, acc = d.account;
  const reload = () => route();
  const muted = mod.chat_muted_until && validDate(mod.chat_muted_until) > new Date();

  const act = (label, fn, cls, adminOnly) => (adminOnly && !isAdmin()) ? null : h('button', { class: 'btn ' + (cls || ''), onclick: fn }, label);
  const actions = h('div', { class: 'btns' },
    act('ارسال پیام', () => sendToPlayerModal(p)),
    act('سکه / قلب / کاپ', () => economyModal(p, reload), 'gold', true),
    act('آیتم‌ها', () => itemsModal(p, reload), '', true),
    mod.is_banned ? act('رفع مسدودیت', async () => {
      if (!await confirmBox('رفع مسدودیت', 'مسدودیت «' + p.username + '» برداشته شود؟', 'رفع مسدودیت')) return;
      try { await api('player/unban', { player_id: p.player_id }); toast('رفع شد'); reload(); } catch (e) { fail(e); }
    }) : act('مسدود کردن', () => banModal(p, reload), 'danger'),
    act(muted ? 'باز کردن چت' : 'بستن چت', () => muteModal(p, muted, reload)),
    d.live.connected ? act('قطع اتصال', async () => {
      if (!await confirmBox('قطع اتصال', 'اتصال زنده‌ی بازیکن قطع شود؟', 'قطع اتصال', true)) return;
      try { await api('player/kick', { player_id: p.player_id }); toast('قطع شد'); reload(); } catch (e) { fail(e); }
    }, 'danger') : null,
  );

  const banners = [];
  if (mod.is_banned) banners.push(h('div', { class: 'banner red' }, 'مسدود ', mod.banned_until ? 'تا ' + fmtDate(mod.banned_until) : '(دائمی)', ' — دلیل: ', mod.ban_reason || '—', ' — از ', fmtDate(mod.banned_at)));
  if (muted) banners.push(h('div', { class: 'banner gold' }, 'چت بسته است تا ' + fmtDate(mod.chat_muted_until)));

  const hero = card(null, h('div', { class: 'hero' },
    avatar(p.username, true),
    h('div', { class: 'grow' },
      h('h2', null, p.username),
      h('div', { class: 'meta' },
        pill('ID ' + p.player_id), d.live.connected ? pill(d.live.match_id ? 'در مسابقه' : 'آنلاین', 'green') : pill('آفلاین — ' + ago(p.last_seen_at)),
        acc.google_linked ? pill('گوگل', 'blue') : pill('مهمان'), mod.is_bot ? pill('بات') : null,
        d.clan_name ? h('a', { href: '#/clan/' + encodeURIComponent(p.clan_id) }, pill('شهر: ' + d.clan_name + ' (' + (p.clan_role || '') + ')', 'gold')) : null)),
    h('div', { class: 'money' },
      h('div', { class: 'c' }, h('span', null, 'سکه'), h('b', null, fmtN(p.coins))),
      h('div', { class: 'g' }, h('span', null, 'قلب'), h('b', null, fmtN(p.gems))),
      h('div', null, h('span', null, 'کاپ'), h('b', null, fmtN(p.trophies))),
      h('div', null, h('span', null, 'سطح'), h('b', null, fmtN(p.level))))),
  h('div', { class: 'btns' }, actions));
  hero.lastChild.classList.add('mt');

  const stats = p.stats || {};
  const overview = h('div', { class: 'grid g2' },
    card('آمار',
      h('dl', { class: 'kv' },
        kv('مسابقه', fmtN(stats.total_matches)), kv('برد / باخت', fmtN(stats.wins) + ' / ' + fmtN(stats.losses) + ' (' + fmtN(d.computed.win_rate) + '٪)'),
        kv('کشته / مرگ', fmtN(stats.kills) + ' / ' + fmtN(stats.deaths) + ' (K/D ' + d.computed.kd + ')'),
        kv('زمان بازی', duration(stats.playtime_seconds)), kv('تجربه', fmtN(p.experience) + ' — ' + fmtN(d.computed.xp_into) + '/' + fmtN(d.computed.xp_need)),
        kv('رتبه', (p.rank && p.rank.tier_name) || '—'), kv('آخرین سلاح', stats.last_used_weapon || '—'),
        kv('دستاورد', fmtN((p.achievements || []).length)), kv('آموزش', p.tutorial_done ? 'تمام شده' : 'نه'))),
    card('حساب',
      h('dl', { class: 'kv' },
        kv('ورود', acc.provider || '—'), kv('ایمیل', acc.email ? h('span', { class: 'ltr' }, acc.email) : '—'), kv('نام گوگل', acc.google_name || '—'),
        kv('وصل شده', fmtDate(acc.linked_at)), kv('آخرین ورود', fmtDate(acc.last_login_at)), kv('عضویت', fmtDate(p.created_at)),
        kv('دستگاه‌ها', acc.sessions.length ? h('div', null, acc.sessions.map((s2) => h('div', null, (s2.device || 'نامشخص') + ' — ' + fmtDate(s2.created_at)))) : '—')),
      h('h3', null, 'تجهیزات و دارایی'),
      h('dl', { class: 'kv' },
        kv('کاراکتر', p.equipped_character || '—'), kv('سلاح', p.equipped_weapon || '—'),
        kv('کاراکترها', pills(p.owned_characters)), kv('سلاح‌ها', pills(p.owned_weapons)), kv('اسکین‌ها', pills(p.owned_skins)))),
  );

  const matches = card(null, table([
    { t: 'زمان', v: (m) => when(m.at) }, { t: 'حالت', v: (m) => m.mode_id },
    { t: 'نتیجه', v: (m) => m.draw ? pill('مساوی') : m.won ? pill('برد', 'green') : pill('باخت', 'red') },
    { t: 'کشته', n: 1, v: (m) => fmtN(m.kills) }, { t: 'مرگ', n: 1, v: (m) => fmtN(m.deaths) }, { t: 'سلاح', v: (m) => m.weapon },
  ], d.recent_matches.slice().reverse()));

  const messages = card(null, table([
    { t: 'زمان', v: (m) => when(m.created_at) }, { t: 'نوع', v: (m) => pill(m.type) }, { t: 'از', v: (m) => m.sender_name },
    { t: 'عنوان', v: (m) => h('span', { title: m.body }, m.title) },
    { t: 'جایزه', v: (m) => rewardText(m.reward) },
    { t: 'وضعیت', v: (m) => h('div', { class: 'btns' }, m.is_read ? pill('خوانده', 'green') : pill('نخوانده'), m.reward && m.reward_claimed ? pill('دریافت شد', 'gold') : null) },
    { t: '', v: (m) => h('button', { class: 'btn sm danger', onclick: async () => {
      if (!await confirmBox('حذف پیام', 'پیام «' + m.title + '» از صندوق بازیکن حذف شود؟', 'حذف', true)) return;
      try { await api('player/message/delete', { message_id: m.message_id }); toast('حذف شد'); reload(); } catch (e) { fail(e); }
    } }, 'حذف') },
  ], d.messages));

  const tickets = card(null, d.tickets.length ? h('div', { class: 'list' }, d.tickets.map(ticketItem)) : h('div', { class: 'empty' }, 'پیامی نفرستاده'));

  const purchases = card(null, purchasesTable(d.purchases));

  const redemptions = card(null, table([
    { t: 'کد', v: (r) => h('span', { class: 'mono' }, r.code) }, { t: 'سکه', n: 1, v: (r) => fmtN(r.coins) }, { t: 'قلب', n: 1, v: (r) => fmtN(r.gems) }, { t: 'زمان', v: (r) => when(r.created_at) },
  ], d.redemptions));

  const friends = card(null, d.friends.length ? h('div', { class: 'btns' }, d.friends.map((f) => h('a', { class: 'pill', href: '#/player/' + encodeURIComponent(f.player_id) }, f.username + ' · ' + fmtN(f.level)))) : h('div', { class: 'empty' }, 'دوستی ندارد'));

  const noteInput = h('textarea', { class: 'input', placeholder: 'یادداشت داخلی (بازیکن نمی‌بیند)' });
  const notes = card(null,
    h('div', { class: 'form' }, noteInput, h('div', { class: 'btns' }, h('button', { class: 'btn gold', onclick: async () => {
      if (!noteInput.value.trim()) return;
      try { await api('player/note', { player_id: p.player_id, text: noteInput.value }); toast('ذخیره شد'); reload(); } catch (e) { fail(e); }
    } }, 'افزودن یادداشت'))),
    h('div', { class: 'list' }, d.notes.map((n) => h('div', { class: 'list-item' },
      h('div', { class: 'head' }, h('b', null, n.by), when(n.at), h('button', { class: 'btn sm ghost', onclick: async () => {
        try { await api('player/note', { player_id: p.player_id, note_id: n._id, delete: true }); reload(); } catch (e) { fail(e); }
      } }, 'حذف')), h('div', { class: 'pre' }, n.text)))));

  const auditCard = card(null, auditTable(d.audit));

  const tabs = [
    ['نمای کلی', overview], ['مسابقات اخیر', matches, d.recent_matches.length], ['صندوق پیام', messages, d.messages.length],
    ['پشتیبانی', tickets, d.tickets.length], ['خریدها', purchases, d.purchases.length], ['کد هدیه', redemptions, d.redemptions.length],
    ['دوستان', friends, d.friends.length], ['یادداشت‌ها', notes, d.notes.length], ['تاریخچه‌ی ادمین', auditCard, d.audit.length],
  ];
  clear($main).append(topbar('بازیکن', null, h('a', { class: 'btn', href: '#/players' }, 'بازگشت به لیست')), banners, hero, tabbed(tabs));
}

function kv(k, v) { return [h('dt', null, k), h('dd', null, v)]; }
function pills(list) { return list && list.length ? h('div', { class: 'btns' }, list.map((x) => pill(x))) : '—'; }
function rewardText(r) {
  if (!r) return '—';
  const parts = [];
  if (r.coins) parts.push(fmtN(r.coins) + ' سکه');
  if (r.gems) parts.push(fmtN(r.gems) + ' قلب');
  if (r.xp) parts.push(fmtN(r.xp) + ' تجربه');
  if (r.items && r.items.length) parts.push(r.items.join('، '));
  return parts.join(' + ') || '—';
}
function tabbed(tabs) {
  const bar = h('div', { class: 'tabs' });
  const body = h('div');
  tabs.forEach(([label, node, count], i) => {
    const b = h('button', { onclick: () => { for (const x of bar.children) x.classList.remove('active'); b.classList.add('active'); clear(body).append(node); } },
      label, count ? h('span', { class: 'count' }, fmtN(count)) : null);
    if (i === 0) b.classList.add('active');
    bar.append(b);
  });
  body.append(tabs[0][1]);
  return h('div', { class: 'card' }, bar, body);
}

// ------------------------------------------------------------ پنجره‌های کارهای بازیکن
function sendToPlayerModal(p) {
  const fields = [
    { name: 'title', label: 'عنوان', value: 'پیام از پشتیبانی' },
    { name: 'body', label: 'متن پیام', type: 'textarea' },
  ];
  if (isAdmin()) fields.push({ type: 'row' }, { name: 'coins', label: 'سکه (اختیاری)', type: 'number', min: 0 }, { name: 'gems', label: 'قلب', type: 'number', min: 0 }, { name: 'xp', label: 'تجربه', type: 'number', min: 0 }, { type: 'endrow' });
  fields.push({ name: 'expire_days', label: 'انقضا (روز)', type: 'number', value: 30, min: 1 });
  formModal('پیام به ' + p.username, fields, 'ارسال', async (v) => {
    await api('messages/send', { target: 'players', players: p.player_id, title: v.title, body: v.body, coins: v.coins || 0, gems: v.gems || 0, xp: v.xp || 0, expire_days: v.expire_days || 30 });
    toast('پیام در صندوق بازیکن نشست');
  });
}

function economyModal(p, done) {
  const info = h('p', { class: 'muted' }, 'در حالت «اضافه/کم» عدد منفی کم می‌کند و مقدار هیچ‌وقت زیر صفر نمی‌رود. سطح از روی تجربه خودکار حساب می‌شود.');
  const inputs = formModal('تغییر دارایی ' + p.username, [
    { name: 'mode', label: 'نوع تغییر', type: 'select', options: [['add', 'اضافه / کم کردن'], ['set', 'تنظیم مقدار دقیق']], value: 'add' },
    { type: 'row' },
    { name: 'coins', label: 'سکه (' + fmtN(p.coins) + ')', type: 'number' },
    { name: 'gems', label: 'قلب (' + fmtN(p.gems) + ')', type: 'number' },
    { type: 'endrow' }, { type: 'row' },
    { name: 'trophies', label: 'کاپ (' + fmtN(p.trophies) + ')', type: 'number' },
    { name: 'experience', label: 'تجربه (' + fmtN(p.experience) + ')', type: 'number' },
    { type: 'endrow' },
    { name: 'reason', label: 'دلیل (در تاریخچه ثبت می‌شود)', placeholder: 'مثلاً: جبران خرید ناموفق' },
  ], 'ذخیره', async (v) => {
    const body = { player_id: p.player_id, mode: v.mode, reason: v.reason };
    for (const k of ['coins', 'gems', 'trophies', 'experience']) if (v[k] !== null) body[k] = v[k];
    const summary = ['coins', 'gems', 'trophies', 'experience'].filter((k) => body[k] !== undefined).map((k) => k + ': ' + (v.mode === 'add' && body[k] > 0 ? '+' : '') + body[k]).join('\n');
    if (!summary) throw new Error('هیچ عددی وارد نشده');
    if (!await confirmBox('تأیید تغییر', (v.mode === 'set' ? 'تنظیم دقیق:\n' : 'اضافه/کم:\n') + summary, 'اعمال')) return;
    await api('player/economy', body);
    toast('اعمال شد');
    done();
  }, info);
  inputs.mode.addEventListener('change', () => {
    const set = inputs.mode.value === 'set';
    inputs.coins.value = set ? p.coins : ''; inputs.gems.value = set ? p.gems : '';
    inputs.trophies.value = set ? p.trophies : ''; inputs.experience.value = set ? p.experience : '';
  });
}

async function itemsModal(p, done) {
  let shop = { items: [] };
  try { shop = await api('shop'); } catch (e) { /* فهرست پیشنهادی نداریم */ }
  const dl = h('datalist', { id: 'shop-items' }, shop.items.filter((i) => i.category === 'weapon' || i.category === 'character').map((i) => h('option', { value: i.item_id }, i.name + ' (' + i.category + ')')));
  formModal('آیتم‌های ' + p.username, [
    { type: 'row' },
    { name: 'action', label: 'کار', type: 'select', options: [['add', 'دادن'], ['remove', 'گرفتن']] },
    { name: 'kind', label: 'نوع', type: 'select', options: [['character', 'کاراکتر'], ['weapon', 'سلاح'], ['skin', 'اسکین']] },
    { type: 'endrow' },
    { name: 'item_id', label: 'شناسه‌ی آیتم', list: 'shop-items', dir: 'ltr', hint: 'کاراکترها: ' + (p.owned_characters || []).join('، ') + ' — سلاح‌ها: ' + (p.owned_weapons || []).join('، ') },
  ], 'اعمال', async (v) => {
    await api('player/items', { player_id: p.player_id, action: v.action, kind: v.kind, item_id: v.item_id.trim() });
    toast('انجام شد');
    done();
  }, dl);
}

function banModal(p, done) {
  const opts = [['1', '۱ ساعت'], ['24', '۱ روز'], ['72', '۳ روز'], ['168', '۷ روز']];
  if (isAdmin()) opts.push(['720', '۳۰ روز'], ['0', 'دائمی']);
  formModal('مسدود کردن ' + p.username, [
    { name: 'hours', label: 'مدت', type: 'select', options: opts, value: '24' },
    { name: 'reason', label: 'دلیل (به بازیکن نشان داده می‌شود)', placeholder: 'مثلاً: تقلب / فحاشی' },
  ], 'مسدود کن', async (v) => {
    const r = await api('player/ban', { player_id: p.player_id, hours: Number(v.hours), reason: v.reason });
    toast('مسدود شد' + (r.kicked ? ' و اتصالش قطع شد' : ''));
    done();
  }, h('p', { class: 'muted' }, 'بازیکن مسدود نه وارد بازی می‌شود و نه هیچ درخواستی از او پذیرفته می‌شود.'));
}

function muteModal(p, muted, done) {
  if (muted) {
    confirmBox('باز کردن چت', 'چت «' + p.username + '» دوباره باز شود؟', 'باز کن').then(async (ok) => {
      if (!ok) return;
      try { await api('player/mute', { player_id: p.player_id, hours: 0 }); toast('باز شد'); done(); } catch (e) { fail(e); }
    });
    return;
  }
  formModal('بستن چت ' + p.username, [
    { name: 'hours', label: 'مدت', type: 'select', options: [['1', '۱ ساعت'], ['6', '۶ ساعت'], ['24', '۱ روز'], ['72', '۳ روز'], ['168', '۷ روز'], ['720', '۳۰ روز']], value: '24' },
    { name: 'reason', label: 'دلیل' },
  ], 'بستن چت', async (v) => {
    await api('player/mute', { player_id: p.player_id, hours: Number(v.hours), reason: v.reason });
    toast('چت بسته شد');
    done();
  });
}

// ================================================================ پشتیبانی
const supportState = { status: 'open', q: '', page: 1 };
async function viewSupport() {
  const st = supportState;
  const tabs = h('div', { class: 'tabs' });
  const body = h('div');
  const load = async () => {
    clear(body).append(loading());
    try {
      const d = await api('support' + qs({ status: st.status, q: st.q, page: st.page }));
      const c = d.counts;
      clear(tabs);
      for (const [key, label, n] of [['open', 'باز', (c.new || 0) + (c.read || 0)], ['new', 'جدید', c.new], ['read', 'خوانده‌شده', c.read], ['answered', 'پاسخ‌داده', c.answered], ['closed', 'بسته', c.closed], ['all', 'همه']]) {
        tabs.append(h('button', { class: st.status === key ? 'active' : null, onclick: () => { st.status = key; st.page = 1; load(); } }, label, n != null ? h('span', { class: 'count' }, fmtN(n)) : null));
      }
      clear(body).append(table([
        { t: 'بازیکن', v: (t) => h('div', { class: 'who' }, avatar(t.username), h('span', { class: 'name' }, t.username)) },
        { t: 'متن', v: (t) => h('span', null, t.body.length > 110 ? t.body.slice(0, 110) + '…' : t.body) },
        { t: 'وضعیت', v: (t) => statusPill(t.status) },
        { t: 'پاسخ', n: 1, v: (t) => fmtN((t.replies || []).length) },
        { t: 'دستگاه', v: (t) => h('span', { class: 'faint' }, [t.platform, t.app_version].filter(Boolean).join(' ') || '—') },
        { t: 'زمان', v: (t) => when(t.created_at) },
      ], d.tickets, (t) => { location.hash = '#/ticket/' + encodeURIComponent(t.ticket_id); }),
      pager(d.page, d.size, d.total, (p) => { st.page = p; load(); }));
    } catch (e) { clear(body); fail(e); }
  };
  const search = h('input', { class: 'input', placeholder: 'جستجو در نام، آیدی یا متن پیام', value: st.q });
  search.addEventListener('input', debounce(() => { st.q = search.value.trim(); st.page = 1; load(); }, 350));
  clear($main).append(topbar('پیام‌های پشتیبانی', 'پیام‌هایی که بازیکن‌ها از تنظیمات بازی فرستاده‌اند'), card(null, tabs, h('div', { class: 'toolbar' }, search), body));
  load();
}

async function viewTicket(id) {
  const d = await api('support/ticket' + qs({ ticket_id: id }));
  refreshSupportBadge();
  const t = d.ticket;
  const thread = h('div', { class: 'thread' },
    h('div', { class: 'bubble' }, h('div', { class: 'meta' }, h('b', null, t.username), fmtDate(t.created_at)), h('div', { class: 'pre' }, t.body)),
    (t.replies || []).map((r) => h('div', { class: 'bubble me' }, h('div', { class: 'meta' }, h('b', null, 'پشتیبانی — ' + r.by), fmtDate(r.at)), h('div', { class: 'pre' }, r.body))));

  const { node, inputs } = buildFields([
    { name: 'body', label: 'پاسخ (در صندوق پیام بازیکن با عنوان «پاسخ پشتیبانی» می‌نشیند)', type: 'textarea' },
    ...(isAdmin() ? [{ type: 'row' }, { name: 'coins', label: 'جایزه‌ی سکه (اختیاری)', type: 'number', min: 0 }, { name: 'gems', label: 'جایزه‌ی قلب', type: 'number', min: 0 }, { type: 'endrow' }] : []),
    { name: 'close', label: 'بعد از پاسخ، پیام بسته شود', type: 'check' },
  ]);
  const send = h('button', { class: 'btn primary' }, 'ارسال پاسخ');
  send.addEventListener('click', async () => {
    const v = readFields(inputs);
    if (!v.body.trim()) return toast('متن پاسخ خالی است', true);
    send.disabled = true;
    try {
      await api('support/reply', { ticket_id: t.ticket_id, body: v.body, coins: v.coins || 0, gems: v.gems || 0, close: v.close });
      toast('پاسخ فرستاده شد');
      route();
    } catch (e) { fail(e); } finally { send.disabled = false; }
  });
  const setStatus = (st) => async () => {
    try { await api('support/status', { ticket_id: t.ticket_id, status: st }); toast('وضعیت عوض شد'); route(); } catch (e) { fail(e); }
  };

  const pl = d.player;
  clear($main).append(
    topbar('پیام پشتیبانی', h('span', null, statusPill(t.status), ' ', h('span', { class: 'mono' }, t.ticket_id)), h('a', { class: 'btn', href: '#/support' }, 'بازگشت')),
    h('div', { class: 'grid split' },
      h('div', { class: 'grid' },
        card('گفتگو', thread),
        card('پاسخ', node, h('div', { class: 'btns' }, send,
          t.status !== 'closed' ? h('button', { class: 'btn', onclick: setStatus('closed') }, 'بستن بدون پاسخ') : h('button', { class: 'btn', onclick: setStatus('read') }, 'باز کردن دوباره'),
          t.status !== 'new' ? h('button', { class: 'btn ghost', onclick: setStatus('new') }, 'علامت «جدید»') : null))),
      h('div', { class: 'grid' },
        card('فرستنده', pl ? [
          h('div', { class: 'who' }, avatar(pl.username), h('div', null, playerLink(pl.player_id, pl.username), h('div', { class: 'faint mono' }, pl.player_id))),
          h('dl', { class: 'kv' }, kv('سطح', fmtN(pl.level)), kv('سکه / قلب', fmtN(pl.coins) + ' / ' + fmtN(pl.gems)), kv('مسابقه', fmtN(pl.matches)),
            kv('آخرین بازدید', ago(pl.last_seen_at)), kv('عضویت', fmtDate(pl.created_at)), kv('دستگاه', [t.platform, t.app_version].filter(Boolean).join(' ') || '—'),
            kv('وضعیت', pl.is_banned ? pill('مسدود', 'red') : pill('عادی', 'green'))),
        ] : h('p', { class: 'muted' }, 'بازیکن دیگر وجود ندارد')),
        card('پیام‌های قبلی همین بازیکن', d.history.length ? h('div', { class: 'list' }, d.history.map(ticketItem)) : h('div', { class: 'empty' }, 'اولین پیامش است')))),
  );
}

// ================================================================ ارسال پیام
async function viewMessages() {
  const target = isAdmin() ? [['players', 'بازیکن‌های مشخص'], ['all', 'همه‌ی بازیکن‌ها'], ['active', 'بازیکن‌های فعال اخیر']] : [['players', 'بازیکن‌های مشخص']];
  const { node, inputs } = buildFields([
    { name: 'target', label: 'گیرنده', type: 'select', options: target },
    { name: 'players', label: 'آیدی یا نام بازیکن‌ها (با ویرگول یا خط جدا کنید)', type: 'textarea', rows: 3, dir: 'auto' },
    { name: 'active_days', label: 'فعال در چند روز اخیر', type: 'number', value: 7, min: 1 },
    { name: 'title', label: 'عنوان', placeholder: 'مثلاً: هدیه‌ی آپدیت جدید' },
    { name: 'body', label: 'متن', type: 'textarea' },
    ...(isAdmin() ? [{ type: 'row' }, { name: 'coins', label: 'سکه', type: 'number', min: 0 }, { name: 'gems', label: 'قلب', type: 'number', min: 0 }, { name: 'xp', label: 'تجربه', type: 'number', min: 0 }, { type: 'endrow' }] : []),
    { name: 'expire_days', label: 'انقضا (روز)', type: 'number', value: 30, min: 1 },
  ]);
  const playersField = inputs.players.parentElement, activeField = inputs.active_days.parentElement;
  const sync = () => {
    playersField.classList.toggle('hidden', inputs.target.value !== 'players');
    activeField.classList.toggle('hidden', inputs.target.value !== 'active');
  };
  inputs.target.addEventListener('change', sync);
  sync();
  const send = h('button', { class: 'btn primary' }, 'ارسال');
  send.addEventListener('click', async () => {
    const v = readFields(inputs);
    const reward = rewardText({ coins: v.coins, gems: v.gems, xp: v.xp });
    const who = v.target === 'all' ? 'همه‌ی بازیکن‌ها' : v.target === 'active' ? 'بازیکن‌های فعال در ' + fmtN(v.active_days) + ' روز اخیر' : v.players;
    if (!await confirmBox('ارسال پیام', 'گیرنده: ' + who + '\nعنوان: ' + v.title + '\nجایزه: ' + reward, 'ارسال', v.target !== 'players')) return;
    send.disabled = true;
    try {
      const r = await api('messages/send', { ...v, coins: v.coins || 0, gems: v.gems || 0, xp: v.xp || 0 });
      toast('برای ' + fmtN(r.campaign.recipients) + ' نفر فرستاده شد');
      if (r.missing && r.missing.length) toast('پیدا نشد: ' + r.missing.join('، '), true);
      inputs.title.value = ''; inputs.body.value = ''; inputs.players.value = '';
      loadCamps();
    } catch (e) { fail(e); } finally { send.disabled = false; }
  });

  const camps = h('div');
  let page = 1;
  const loadCamps = async () => {
    clear(camps).append(loading());
    try {
      const d = await api('messages/campaigns' + qs({ page }));
      clear(camps).append(table([
        { t: 'زمان', v: (r) => when(r.campaign.created_at) },
        { t: 'عنوان', v: (r) => h('span', { title: r.campaign.body }, r.campaign.title) },
        { t: 'گیرنده', v: (r) => ({ players: 'مشخص', all: 'همه', active: 'فعال‌ها' })[r.campaign.target] },
        { t: 'تعداد', n: 1, v: (r) => fmtN(r.campaign.recipients) },
        { t: 'خوانده', n: 1, v: (r) => fmtN(r.read) },
        { t: 'جایزه', v: (r) => rewardText(r.campaign.reward) + (r.claimed != null ? ' (' + fmtN(r.claimed) + ' دریافت)' : '') },
        { t: 'فرستنده', v: (r) => r.campaign.created_by },
        { t: '', v: (r) => r.campaign.revoked ? pill('پس گرفته شد') : h('button', { class: 'btn sm danger', onclick: async () => {
          if (!await confirmBox('پس گرفتن پیام', 'پیام «' + r.campaign.title + '» از صندوق همه‌ی گیرنده‌ها حذف شود؟ جایزه‌های دریافت‌شده برنمی‌گردد.', 'حذف', true)) return;
          try { const x = await api('messages/revoke', { campaign_id: r.campaign.campaign_id }); toast(fmtN(x.deleted) + ' پیام حذف شد'); loadCamps(); } catch (e) { fail(e); }
        } }, 'پس گرفتن') },
      ], d.campaigns), pager(d.page, d.size, d.total, (p) => { page = p; loadCamps(); }));
    } catch (e) { clear(camps); fail(e); }
  };
  clear($main).append(topbar('ارسال پیام', 'پیام در منوی «پیام‌ها»ی بازی با برچسب «پشتیبانی» دیده می‌شود'),
    h('div', { class: 'grid split' }, card('پیام تازه', node, h('div', { class: 'btns' }, send)), card('راهنما',
      h('p', { class: 'muted' }, 'پیام همگانیِ بدون جایزه یک پیام مشترک است و بازیکن‌هایی که بعداً ثبت‌نام کنند هم آن را می‌بینند.'),
      h('p', { class: 'muted' }, 'پیام جایزه‌دار برای هر بازیکن جدا ساخته می‌شود تا جایزه فقط یک بار دریافت شود؛ فقط به بازیکن‌های موجود می‌رسد.'),
      h('p', { class: 'muted' }, 'پیام‌ها بعد از تاریخ انقضا خودکار پاک می‌شوند.'))),
    card('پیام‌های فرستاده‌شده', camps));
  loadCamps();
}

// ================================================================ چت
const chatState = { channel: 'global', q: '', player_id: '' };
async function viewChat() {
  const st = chatState;
  const list = h('div');
  let oldest = null;
  const load = async (more) => {
    if (!more) { clear(list).append(loading()); oldest = null; }
    try {
      const d = await api('chat' + qs({ channel: st.channel, q: st.q, player_id: st.player_id, before: more ? oldest : '' }));
      if (!more) clear(list);
      const old = list.querySelector('.more'); if (old) old.remove();
      if (!d.messages.length && !more) list.append(h('div', { class: 'empty' }, 'پیامی نیست'));
      for (const m of d.messages) {
        const room = m.room.startsWith('city:') ? 'شهر ' + (d.clan_names[m.room.slice(5)] || '') : m.room.startsWith('dm:') ? 'خصوصی' : 'جهانی';
        const row = h('div', { class: 'chat-row' },
          avatar(m.sender_name),
          h('div', null, h('div', { class: 'btns' }, playerLink(m.sender_id, m.sender_name), pill(room), h('span', { class: 'faint' }, fmtDate(m.created_at))), h('div', { class: 'text pre' }, m.text)),
          h('div', { class: 'btns' },
            h('button', { class: 'btn sm danger', onclick: async () => {
              try { await api('chat/delete', { message_id: m.message_id }); row.remove(); toast('حذف شد'); } catch (e) { fail(e); }
            } }, 'حذف'),
            h('button', { class: 'btn sm ghost', onclick: async () => {
              if (!await confirmBox('پاکسازی', 'همه‌ی پیام‌های عمومی (جهانی و شهر) «' + m.sender_name + '» حذف شود؟', 'پاک کن', true)) return;
              try { const r = await api('chat/delete', { player_id: m.sender_id, all: true }); toast(fmtN(r.deleted) + ' پیام حذف شد'); load(); } catch (e) { fail(e); }
            } }, 'پاکسازی همه')));
        list.append(row);
        oldest = m.created_at;
      }
      if (d.messages.length === 100) list.append(h('div', { class: 'btns more' }, h('button', { class: 'btn', onclick: () => load(true) }, 'پیام‌های قدیمی‌تر')));
    } catch (e) { if (!more) clear(list); fail(e); }
  };
  const channels = [['global', 'جهانی'], ['city', 'شهرها'], ['', 'همه‌ی عمومی‌ها']];
  if (isAdmin()) channels.push(['private', 'خصوصی']);
  const ch = h('select', { class: 'input', onchange: (e) => { st.channel = e.target.value; load(); } }, channels.map(([v, l]) => h('option', { value: v }, l)));
  ch.value = st.channel;
  const search = h('input', { class: 'input', placeholder: 'جستجو در متن', value: st.q });
  search.addEventListener('input', debounce(() => { st.q = search.value.trim(); load(); }, 400));
  const pid = h('input', { class: 'input', placeholder: 'آیدی فرستنده', value: st.player_id, dir: 'ltr' });
  pid.addEventListener('input', debounce(() => { st.player_id = pid.value.trim(); load(); }, 400));
  clear($main).append(topbar('نظارت چت', 'پیام‌های جهانی و شهر ۷ روز نگه داشته می‌شوند', h('button', { class: 'btn', onclick: () => load() }, 'تازه‌سازی')),
    card(null, h('div', { class: 'toolbar' }, ch, search, pid), list));
  load();
}

// ================================================================ خریدها
function purchasesTable(rows) {
  return table([
    { t: 'زمان', v: (r) => when(r.created_at) },
    { t: 'بازیکن', v: (r) => playerLink(r.player_id, r.username) },
    { t: 'فروشگاه', v: (r) => STORE[r.store] || r.store },
    { t: 'محصول', v: (r) => h('span', { class: 'mono' }, r.product_id) },
    { t: 'قلب', n: 1, v: (r) => fmtN(r.gems) },
    { t: 'مبلغ تقریبی', n: 1, v: (r) => r.toman_estimate ? fmtN(r.toman_estimate) + ' ت' : '—' },
    { t: 'وضعیت', v: (r) => r.state === 'credited' ? pill('واریز شد', 'green') : pill(r.state, 'gold') },
    { t: 'توکن', v: (r) => h('span', { class: 'mono', title: r.token }, String(r.token || '').slice(0, 14) + '…') },
  ], rows);
}
const purchaseState = { q: '', store: '', state: '', page: 1 };
async function viewPurchases() {
  const st = purchaseState;
  const body = h('div'), summary = h('div');
  const load = async () => {
    clear(body).append(loading());
    try {
      const d = await api('purchases' + qs(st));
      clear(body).append(purchasesTable(d.purchases), pager(d.page, d.size, d.total, (p) => { st.page = p; load(); }));
      let sumT = 0, sumG = 0, sumC = 0;
      clear(summary).append(table([
        { t: 'محصول', v: (r) => h('span', { class: 'mono' }, r._id.product) },
        { t: 'فروشگاه', v: (r) => STORE[r._id.store] || r._id.store },
        { t: 'تعداد', n: 1, v: (r) => fmtN(r.count) },
        { t: 'قلب', n: 1, v: (r) => fmtN(r.gems) },
        { t: 'فروش تقریبی', n: 1, v: (r) => r.unit_toman ? fmtN(r.unit_toman * r.count) + ' ت' : '—' },
      ], d.by_product));
      for (const r of d.by_product) { sumC += r.count; sumG += r.gems; sumT += (r.unit_toman || 0) * r.count; }
      summary.prepend(h('div', { class: 'grid g3' }, stat('کل خریدها', fmtN(sumC), null, 'gold'), stat('کل قلب فروخته‌شده', fmtN(sumG)), stat('فروش تقریبی کل', fmtN(sumT) + ' ت', 'با قیمت فعلی بسته‌ها', 'gold')));
    } catch (e) { clear(body); fail(e); }
  };
  const search = h('input', { class: 'input', placeholder: 'نام، آیدی، توکن یا شناسه‌ی محصول', value: st.q });
  search.addEventListener('input', debounce(() => { st.q = search.value.trim(); st.page = 1; load(); }, 350));
  const store = h('select', { class: 'input', onchange: (e) => { st.store = e.target.value; st.page = 1; load(); } }, [['', 'همه‌ی فروشگاه‌ها'], ['bazaar', 'بازار'], ['myket', 'مایکت']].map(([v, l]) => h('option', { value: v }, l)));
  store.value = st.store;
  const state = h('select', { class: 'input', onchange: (e) => { st.state = e.target.value; st.page = 1; load(); } }, [['', 'همه‌ی وضعیت‌ها'], ['credited', 'واریزشده'], ['pending', 'در انتظار']].map(([v, l]) => h('option', { value: v }, l)));
  state.value = st.state;
  clear($main).append(topbar('خریدهای درون‌برنامه‌ای'), summary, card('ریز خریدها', h('div', { class: 'toolbar' }, search, store, state), body));
  summary.classList.add('grid');
  load();
}

// ================================================================ کد هدیه
async function viewGifts() {
  const d = await api('gift_codes');
  const now = new Date();
  const create = isAdmin() ? (() => {
    const { node, inputs } = buildFields([
      { name: 'code', label: 'کد (خالی = تصادفی)', dir: 'ltr', placeholder: 'NOROOZ1405' },
      { type: 'row' }, { name: 'coins', label: 'سکه', type: 'number', min: 0 }, { name: 'gems', label: 'قلب', type: 'number', min: 0 }, { type: 'endrow' },
      { type: 'row' }, { name: 'max_uses', label: 'حداکثر استفاده (۰ = نامحدود)', type: 'number', value: 0, min: 0 },
      { name: 'expires_in_hours', label: 'انقضا بعد از چند ساعت (۰ = هیچ‌وقت)', type: 'number', value: 72, min: 0 }, { type: 'endrow' },
    ]);
    const btn = h('button', { class: 'btn primary' }, 'ساخت کد');
    btn.addEventListener('click', async () => {
      const v = readFields(inputs);
      btn.disabled = true;
      try {
        const r = await api('gift_codes/create', { code: v.code, coins: v.coins || 0, gems: v.gems || 0, max_uses: v.max_uses || 0, expires_in_hours: v.expires_in_hours || 0 });
        toast('کد ' + r.code.code + ' ساخته شد');
        route();
      } catch (e) { fail(e); } finally { btn.disabled = false; }
    });
    return card('کد تازه', node, h('div', { class: 'btns' }, btn));
  })() : null;
  const showRedemptions = async (c) => {
    try {
      const r = await api('gift_codes/redemptions' + qs({ code: c.code }));
      modal('استفاده‌های ' + c.code, table([
        { t: 'بازیکن', v: (x) => playerLink(x.player_id, x.username) }, { t: 'زمان', v: (x) => fmtDate(x.created_at) },
      ], r.redemptions), (close) => [h('button', { class: 'btn', onclick: close }, 'بستن')]);
    } catch (e) { fail(e); }
  };
  clear($main).append(topbar('کدهای هدیه', 'بازیکن کد را در تنظیمات بازی وارد می‌کند'), create, card('کدها', table([
    { t: 'کد', v: (c) => h('b', { class: 'mono' }, c.code) },
    { t: 'جایزه', v: (c) => rewardText(c) },
    { t: 'استفاده', n: 1, v: (c) => fmtN(c.uses) + ' / ' + (c.max_uses ? fmtN(c.max_uses) : '∞') },
    { t: 'انقضا', v: (c) => c.expires_at ? (validDate(c.expires_at) < now ? pill('منقضی', 'red') : when(c.expires_at)) : '—' },
    { t: 'وضعیت', v: (c) => c.active ? pill('فعال', 'green') : pill('غیرفعال') },
    { t: 'ساخت', v: (c) => when(c.created_at) },
    { t: '', v: (c) => h('div', { class: 'btns' },
      h('button', { class: 'btn sm', onclick: () => showRedemptions(c) }, 'استفاده‌کننده‌ها'),
      isAdmin() ? h('button', { class: 'btn sm ' + (c.active ? 'danger' : ''), onclick: async () => {
        try { await api('gift_codes/toggle', { code: c.code, active: !c.active }); toast('انجام شد'); route(); } catch (e) { fail(e); }
      } }, c.active ? 'غیرفعال کن' : 'فعال کن') : null) },
  ], d.codes)));
}

// ================================================================ شهرها
const clanState = { q: '', page: 1 };
async function viewClans() {
  const st = clanState;
  const body = h('div');
  const load = async () => {
    clear(body).append(loading());
    try {
      const d = await api('clans' + qs(st));
      clear(body).append(table([
        { t: 'شهر', v: (c) => h('div', null, h('b', null, c.name), ' ', pill(c.tag, 'gold')) },
        { t: 'رهبر', v: (c) => c.leader || '—' },
        { t: 'اعضا', n: 1, v: (c) => fmtN(c.member_count) + ' / ' + fmtN(c.max_members) },
        { t: 'سطح', n: 1, v: (c) => fmtN(c.level) },
        { t: 'نوع', v: (c) => c.is_public ? pill('عمومی', 'green') : pill('خصوصی') },
        { t: 'ساخت', v: (c) => when(c.created_at) },
      ], d.clans, (c) => { location.hash = '#/clan/' + encodeURIComponent(c.clan_id); }), pager(d.page, d.size, d.total, (p) => { st.page = p; load(); }));
    } catch (e) { clear(body); fail(e); }
  };
  const search = h('input', { class: 'input', placeholder: 'نام یا تگ شهر', value: st.q });
  search.addEventListener('input', debounce(() => { st.q = search.value.trim(); st.page = 1; load(); }, 350));
  clear($main).append(topbar('شهرها'), card(null, h('div', { class: 'toolbar' }, search), body));
  load();
}

async function viewClan(id) {
  const d = await api('clan' + qs({ clan_id: id }));
  const c = d.clan;
  const ROLE = { leader: ['رهبر', 'gold'], officer: ['معاون', 'blue'], member: ['عضو', ''] };
  const edit = () => formModal('ویرایش شهر', [
    { name: 'name', label: 'نام', value: c.name }, { name: 'tag', label: 'تگ', value: c.tag, dir: 'ltr' },
    { name: 'description', label: 'توضیح', type: 'textarea', value: c.description, rows: 3 },
    { type: 'row' }, { name: 'min_level', label: 'حداقل سطح', type: 'number', value: c.min_level, min: 0 }, { name: 'max_members', label: 'ظرفیت', type: 'number', value: c.max_members, min: 1 }, { type: 'endrow' },
    { name: 'is_public', label: 'عمومی (عضویت بدون تأیید)', type: 'check', value: c.is_public },
  ], 'ذخیره', async (v) => {
    await api('clan/update', { clan_id: c.clan_id, ...v });
    toast('ذخیره شد'); route();
  });
  const disband = async () => {
    if (!await confirmBox('انحلال شهر', 'شهر «' + c.name + '» منحل شود؟ همه‌ی ' + fmtN(c.member_count) + ' عضو آزاد می‌شوند. این کار برگشت ندارد.', 'منحل کن', true)) return;
    try { await api('clan/disband', { clan_id: c.clan_id }); toast('منحل شد'); location.hash = '#/clans'; } catch (e) { fail(e); }
  };
  clear($main).append(
    topbar(c.name, h('span', null, pill(c.tag, 'gold'), ' ', h('span', { class: 'mono' }, c.clan_id)), h('a', { class: 'btn', href: '#/clans' }, 'بازگشت'),
      isAdmin() ? h('button', { class: 'btn gold', onclick: edit }, 'ویرایش') : null, isAdmin() ? h('button', { class: 'btn danger', onclick: disband }, 'انحلال') : null),
    h('div', { class: 'grid g4' }, stat('اعضا', fmtN(c.member_count) + ' / ' + fmtN(c.max_members), null, 'gold'), stat('سطح', fmtN(c.level)), stat('حداقل سطح ورود', fmtN(c.min_level)), stat('درخواست در انتظار', fmtN(d.requests.length))),
    c.description ? card('توضیح', h('p', { class: 'pre' }, c.description)) : null,
    card('اعضا', table([
      { t: 'بازیکن', v: (m) => h('div', { class: 'who' }, h('span', { class: 'dot' + (m.is_online ? ' on' : '') }), playerLink(m.player_id, m.username)) },
      { t: 'نقش', v: (m) => pill((ROLE[m.role] || [m.role])[0], (ROLE[m.role] || [])[1]) },
      { t: 'سطح', n: 1, v: (m) => fmtN(m.level) }, { t: 'کاپ', n: 1, v: (m) => fmtN(m.trophies) },
      { t: 'عضویت', v: (m) => when(m.joined_at) }, { t: 'آخرین بازدید', v: (m) => when(m.last_seen_at) },
      { t: '', v: (m) => isAdmin() ? h('button', { class: 'btn sm danger', onclick: async () => {
        if (!await confirmBox('اخراج', '«' + m.username + '» از شهر اخراج شود؟' + (m.role === 'leader' ? '\nرهبری به قدیمی‌ترین معاون/عضو می‌رسد.' : ''), 'اخراج', true)) return;
        try { await api('clan/kick', { clan_id: c.clan_id, player_id: m.player_id }); toast('اخراج شد'); route(); } catch (e) { fail(e); }
      } }, 'اخراج') : null },
    ], d.members)),
  );
}

// ================================================================ حالت‌های بازی
async function viewModes() {
  const d = await api('modes');
  const edit = (m) => formModal('ویرایش ' + m.name, [
    { name: 'name', label: 'نام', value: m.name }, { name: 'subtitle', label: 'زیرعنوان', value: m.subtitle },
    { name: 'description', label: 'توضیح', type: 'textarea', value: m.description, rows: 3 },
    { type: 'row' }, { name: 'win_trophies', label: 'کاپ برد', type: 'number', value: m.win_trophies, min: 0 }, { name: 'win_coins', label: 'سکه برد', type: 'number', value: m.win_coins, min: 0 }, { name: 'win_xp', label: 'تجربه برد', type: 'number', value: m.win_xp, min: 0 }, { type: 'endrow' },
    { type: 'row' }, { name: 'lose_trophies', label: 'کاپ کسر باخت', type: 'number', value: m.lose_trophies, min: 0 }, { name: 'lose_coins', label: 'سکه باخت', type: 'number', value: m.lose_coins, min: 0 }, { name: 'lose_xp', label: 'تجربه باخت', type: 'number', value: m.lose_xp, min: 0 }, { type: 'endrow' },
    { type: 'row' }, { name: 'min_trophies', label: 'حداقل کاپ ورود', type: 'number', value: m.min_trophies, min: 0 }, { name: 'sort_order', label: 'ترتیب', type: 'number', value: m.sort_order, min: 0 }, { type: 'endrow' },
    { name: 'is_active', label: 'فعال (در منوی بازی دیده شود)', type: 'check', value: m.is_active },
  ], 'ذخیره', async (v) => {
    const body = { mode_id: m.mode_id };
    for (const [k, val] of Object.entries(v)) if (val !== null) body[k] = val;
    await api('modes/update', body);
    toast('ذخیره شد'); route();
  }, h('p', { class: 'muted' }, 'تعداد نفرات و قانون راند در کد سرور است و اینجا عوض نمی‌شود.'));
  clear($main).append(topbar('حالت‌های بازی', 'پاداش و جریمه‌ی هر حالت'), card(null, table([
    { t: 'حالت', v: (m) => h('div', null, h('b', null, m.name), h('div', { class: 'faint mono' }, m.mode_id)) },
    { t: 'نفرات', n: 1, v: (m) => fmtN(m.team_size) + ' در ' + fmtN(m.team_size) },
    { t: 'برد (کاپ/سکه/تجربه)', n: 1, v: (m) => [m.win_trophies, m.win_coins, m.win_xp].map(fmtN).join(' / ') },
    { t: 'باخت (کاپ/سکه/تجربه)', n: 1, v: (m) => ['-' + fmtN(m.lose_trophies), fmtN(m.lose_coins), fmtN(m.lose_xp)].join(' / ') },
    { t: 'حداقل کاپ', n: 1, v: (m) => fmtN(m.min_trophies) },
    { t: 'وضعیت', v: (m) => m.is_active ? pill('فعال', 'green') : pill('خاموش', 'red') },
    { t: '', v: (m) => isAdmin() ? h('button', { class: 'btn sm gold', onclick: () => edit(m) }, 'ویرایش') : null },
  ], d.modes)));
}

// ================================================================ فروشگاه
async function viewShop() {
  const d = await api('shop');
  const SECTION = { weekly: 'هفتگی', very_special: 'خیلی ویژه' };
  const edit = (it) => formModal('ویرایش ' + it.name, [
    { name: 'discount_percent', label: 'درصد تخفیف (۰ تا ۹۰)', type: 'number', value: it.discount_percent, min: 0 },
    { name: 'featured_section', label: 'ویترین پیشنهاد ویژه', type: 'select', options: [['', 'هیچ‌کدام'], ['weekly', 'هفتگی'], ['very_special', 'خیلی ویژه']], value: it.featured_section || '' },
  ], 'ذخیره', async (v) => {
    await api('shop/update', { item_id: it.item_id, discount_percent: v.discount_percent || 0, featured_section: v.featured_section });
    toast('ذخیره شد'); route();
  }, h('p', { class: 'muted' }, 'قیمت پایه از کد سرور می‌آید و با هر بوت بازنویسی می‌شود؛ تخفیف و ویترین می‌ماند.'));
  clear($main).append(topbar('فروشگاه', fmtN(d.items.length) + ' آیتم'), card(null, table([
    { t: 'آیتم', v: (it) => h('div', null, h('b', null, it.name), h('div', { class: 'faint mono' }, it.item_id)) },
    { t: 'دسته', v: (it) => pill(it.category) }, { t: 'رده', v: (it) => it.rarity || '—' },
    { t: 'قیمت', n: 1, v: (it) => fmtN(it.original_price) + ' ' + ({ coins: 'سکه', gems: 'قلب', toman: 'ت' }[it.cost_type] || it.cost_type) },
    { t: 'تخفیف', n: 1, v: (it) => it.discount_percent ? pill(fmtN(it.discount_percent) + '٪', 'red') : '—' },
    { t: 'نهایی', n: 1, v: (it) => fmtN(it.final_price) },
    { t: 'ویترین', v: (it) => it.featured_section ? pill(SECTION[it.featured_section] || it.featured_section, 'gold') : '—' },
    { t: 'دارندگان', n: 1, v: (it) => d.owners[it.item_id] != null ? fmtN(d.owners[it.item_id]) : '—' },
    { t: '', v: (it) => isAdmin() ? h('button', { class: 'btn sm gold', onclick: () => edit(it) }, 'ویرایش') : null },
  ], d.items)));
}

// ================================================================ سرور
async function viewServer() {
  const d = await api('server');
  const flag = (ok) => ok ? pill('روشن', 'green') : pill('خاموش', 'red');
  const cfgNames = { google_signin: 'ورود با گوگل', game_server_key: 'کلید سرویس داخلی', bazaar_api: 'API بازار', myket_api: 'API مایکت', iap_debug: 'خرید آزمایشی (باید خاموش باشد)', trust_proxy: 'اعتماد به پراکسی' };
  clear($main).append(topbar('وضعیت سرور', 'روشن از ' + fmtDate(d.started_at), h('button', { class: 'btn', onclick: route }, 'تازه‌سازی')),
    h('div', { class: 'grid g4' },
      stat('زمان روشن بودن', duration(d.uptime_sec), null, 'green'),
      stat('دیتابیس', d.db_ok ? 'سالم' : 'قطع', null, d.db_ok ? 'green' : 'red'),
      stat('هاب بازی', d.hub_ok ? fmtN(d.hub.online) + ' آنلاین' : 'پاسخ نداد', fmtN(d.hub.connections) + ' اتصال — ' + fmtN(d.hub.rounds) + ' راند', d.hub_ok ? 'gold' : 'red'),
      stat('حافظه', bytes(d.mem_alloc), 'از سیستم: ' + bytes(d.mem_sys) + ' — ' + fmtN(d.goroutines) + ' گوروتین')),
    h('div', { class: 'grid g2' },
      card('تنظیمات', h('dl', { class: 'kv' }, Object.entries(d.config).map(([k, v]) => kv(cfgNames[k] || k, k === 'iap_debug' ? (v ? pill('روشن!', 'red') : pill('خاموش', 'green')) : flag(v))), kv('نسخه‌ی Go', d.go_version))),
      card('کالکشن‌ها', h('dl', { class: 'kv' }, Object.entries(d.collections).sort((a, b) => b[1] - a[1]).map(([k, v]) => kv(h('span', { class: 'mono' }, k), fmtN(v)))))));
}

// ================================================================ امنیت
async function viewSecurity() {
  const d = await api('security');
  const ok = (v, yes, no) => v ? pill(yes, 'green') : pill(no, 'red');
  const logoutAll = isAdmin() ? h('button', { class: 'btn', onclick: async () => {
    if (!await confirmBox('خروج بقیه', 'همه‌ی نشست‌های دیگر (به جز همین مرورگر) بسته شوند؟', 'ببند')) return;
    try { const r = await api('security/logout_all', {}); toast(fmtN(r.dropped) + ' نشست بسته شد'); route(); } catch (e) { fail(e); }
  } }, 'بیرون انداختن بقیه‌ی نشست‌ها') : null;
  clear($main).append(
    topbar('امنیت', 'نشست‌ها، ورودها و قفل اضطراری'),
    h('div', { class: 'grid g3' },
      stat('کد دومرحله‌ای حساب شما', d.totp_enabled ? 'فعال' : 'غیرفعال', null, d.totp_enabled ? 'green' : 'red'),
      stat('کلید اضطراری', d.panic_key_set ? 'تنظیم شده' : 'ندارد', 'برای قفل کردن بدون ورود', d.panic_key_set ? 'green' : 'gold'),
      stat('نشست‌های فعال', fmtN(d.sessions.length), 'بعد از ۱ ساعت بی‌کاری خودکار بسته می‌شوند', 'gold')),
    h('div', { class: 'card panic-card' },
      h('h2', null, 'هک شدم؟'),
      h('p', null, 'اگر فکر می‌کنید رمز یا گوشی‌تان دست کس دیگری افتاده، یا در تاریخچه کاری می‌بینید که شما نکرده‌اید، این دکمه را بزنید. همه‌ی ادمین‌ها بیرون انداخته می‌شوند، ورود بسته می‌شود و فقط از روی خودِ سرور باز می‌شود. بازی برای بازیکن‌ها قطع نمی‌شود.'),
      h('button', { class: 'btn primary big', onclick: () => panicFlow(false) }, 'قفل اضطراری پنل')),
    card('نشست‌های باز', h('div', { class: 'btns mb' }, logoutAll), table([
      { t: 'ادمین', v: (x) => h('div', null, h('b', null, x.user), ' ', x.me ? pill('همین مرورگر', 'green') : null) },
      { t: 'نقش', v: (x) => x.role === 'admin' ? 'مدیر کامل' : 'پشتیبانی' },
      { t: 'آی‌پی', v: (x) => h('span', { class: 'mono' }, x.ip) },
      { t: 'مرورگر', v: (x) => h('span', { class: 'faint', title: x.agent }, (x.agent || '').slice(0, 60)) },
      { t: 'ورود', v: (x) => when(x.created) },
      { t: 'آخرین فعالیت', v: (x) => when(x.last_seen) },
    ], d.sessions)),
    card('ورودهای اخیر', auditTable(d.logins)),
    card('وضعیت', h('dl', { class: 'kv' },
      kv('رمزها فقط به‌صورت هش', ok(d.hashed, 'بله', 'نه')),
      kv('کد دومرحله‌ای', ok(d.totp_enabled, 'فعال', 'غیرفعال')),
      kv('کلید اضطراری', ok(d.panic_key_set, 'دارد', 'ندارد')))),
  );
}

// ================================================================ تاریخچه‌ی ادمین‌ها
const ACTIONS = {
  login: 'ورود', login_failed: 'ورود ناموفق', logout: 'خروج', player_economy: 'تغییر دارایی', player_items: 'آیتم', player_ban: 'مسدود کردن',
  player_unban: 'رفع مسدودیت', player_mute: 'بستن چت', player_kick: 'قطع اتصال', note_delete: 'حذف یادداشت', message_delete: 'حذف پیام',
  message_send: 'ارسال پیام', message_revoke: 'پس گرفتن پیام', support_reply: 'پاسخ پشتیبانی', support_status: 'وضعیت پشتیبانی',
  chat_delete: 'حذف چت', chat_purge: 'پاکسازی چت', gift_code_create: 'ساخت کد هدیه', gift_code_toggle: 'فعال/غیرفعال کد',
  clan_update: 'ویرایش شهر', clan_kick: 'اخراج از شهر', clan_disband: 'انحلال شهر', mode_update: 'ویرایش حالت بازی', shop_update: 'ویرایش فروشگاه', panic_lockdown: 'قفل اضطراری', panic_unlock: 'باز کردن قفل', panic_key_failed: 'کلید اضطراری اشتباه', logout_all: 'بستن همه‌ی نشست‌ها',
};
function auditTable(rows) {
  return table([
    { t: 'زمان', v: (e) => h('span', { title: fmtDate(e.at) }, fmtDate(e.at)) },
    { t: 'ادمین', v: (e) => h('b', null, e.admin || '—') },
    { t: 'کار', v: (e) => pill(ACTIONS[e.action] || e.action, e.action.includes('ban') || e.action.includes('fail') || e.action.includes('panic') ? 'red' : e.action.includes('economy') ? 'gold' : '') },
    { t: 'هدف', v: (e) => /^\d+$/.test(e.target || '') ? playerLink(e.target, e.target) : h('span', { class: 'mono' }, e.target || '—') },
    { t: 'جزئیات', v: (e) => e.details ? h('span', { class: 'mono pre' }, JSON.stringify(e.details)) : '—' },
    { t: 'آی‌پی', v: (e) => h('span', { class: 'mono' }, e.ip) },
  ], rows);
}
const auditState = { admin: '', action: '', target: '', page: 1 };
async function viewAudit() {
  const st = auditState;
  const body = h('div');
  const load = async () => {
    clear(body).append(loading());
    try {
      const d = await api('audit' + qs(st));
      clear(body).append(auditTable(d.entries), pager(d.page, d.size, d.total, (p) => { st.page = p; load(); }));
    } catch (e) { clear(body); fail(e); }
  };
  const admin = h('input', { class: 'input', placeholder: 'نام ادمین', value: st.admin, dir: 'ltr' });
  admin.addEventListener('input', debounce(() => { st.admin = admin.value.trim(); st.page = 1; load(); }, 350));
  const action = h('select', { class: 'input', onchange: (e) => { st.action = e.target.value; st.page = 1; load(); } }, [h('option', { value: '' }, 'همه‌ی کارها'), Object.entries(ACTIONS).map(([k, l]) => h('option', { value: k }, l))]);
  action.value = st.action;
  const target = h('input', { class: 'input', placeholder: 'هدف (آیدی بازیکن، کد...)', value: st.target, dir: 'ltr' });
  target.addEventListener('input', debounce(() => { st.target = target.value.trim(); st.page = 1; load(); }, 350));
  clear($main).append(topbar('تاریخچه‌ی ادمین‌ها', 'هر تغییری که از پنل انجام شده'), card(null, h('div', { class: 'toolbar' }, admin, action, target), body));
  load();
}

boot();
