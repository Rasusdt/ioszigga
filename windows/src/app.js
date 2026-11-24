const $ = (id) => document.getElementById(id);

let connected = false;
let connecting = false;

(function drawBg() {
  const canvas = document.getElementById('bg');
  const ctx = canvas.getContext('2d');
  function resize() {
    const dpr = window.devicePixelRatio || 1;
    canvas.width = window.innerWidth * dpr;
    canvas.height = window.innerHeight * dpr;
    canvas.style.width = window.innerWidth + 'px';
    canvas.style.height = window.innerHeight + 'px';
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    render();
  }
  function render() {
    const w = window.innerWidth, h = window.innerHeight;
    ctx.fillStyle = '#05070D';
    ctx.fillRect(0, 0, w, h);
    const cx = w * 1.02, cy = h * 1.02;
    const radius = Math.max(w, h) * 1.10;
    const grd = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
    grd.addColorStop(0, 'rgba(156,182,228,0.40)');
    grd.addColorStop(0.34, 'rgba(118,144,190,0.16)');
    grd.addColorStop(1, 'rgba(0,0,0,0)');
    ctx.fillStyle = grd;
    ctx.fillRect(0, 0, w, h);
    const step = 7;
    const rx = w * 1.25, ry = h * 0.92;
    for (let y = step / 2; y < h; y += step) {
      for (let x = step / 2; x < w; x += step) {
        const dx = (x - cx) / rx;
        const dy = (y - cy) / ry;
        const d = Math.min(1, Math.sqrt(dx*dx + dy*dy));
        const f = Math.pow(1 - d, 1.75);
        const vertical = Math.min(1, 0.45 + 0.55 * (1 - (y / h) * 0.35));
        const alpha = (0.075 + 0.925 * f) * vertical;
        if (alpha > 0.06) {
          const r = 0.9 + 0.95 * f;
          const rr = Math.round(25 + 62 * f);
          const gg = Math.round(36 + 55 * f);
          const bb = Math.round(54 + 46 * f);
          ctx.fillStyle = `rgba(${rr},${gg},${bb},${alpha})`;
          ctx.beginPath();
          ctx.arc(x, y, r, 0, Math.PI * 2);
          ctx.fill();
        }
      }
    }
    const vg = ctx.createLinearGradient(0, 0, 0, h);
    vg.addColorStop(0, 'rgba(0,0,0,0.30)');
    vg.addColorStop(0.5, 'rgba(0,0,0,0.04)');
    vg.addColorStop(1, 'rgba(5,7,13,0.60)');
    ctx.fillStyle = vg;
    ctx.fillRect(0, 0, w, h);
  }
  window.addEventListener('resize', resize);
  resize();
})();

const pinInput = $('pinInput');
const pinBoxes = document.querySelectorAll('.pin-box');
const loginBtn = $('loginBtn');

pinInput.addEventListener('input', () => {
  const v = pinInput.value.replace(/\D/g, '').slice(0, 6);
  pinInput.value = v;
  pinBoxes.forEach((b, i) => {
    b.textContent = v[i] || '';
    b.classList.toggle('filled', !!v[i]);
  });
  loginBtn.disabled = v.length !== 6;
  $('codeError').textContent = '';
});

document.getElementById('pinRow').addEventListener('click', () => pinInput.focus());

loginBtn.addEventListener('click', async () => {
  const pin = pinInput.value;
  if (pin.length !== 6) return;
  loginBtn.disabled = true;
  loginBtn.textContent = 'Проверяем…';
  const res = await window.zigga.login(pin);
  loginBtn.disabled = false;
  loginBtn.textContent = 'Войти';
  if (res.ok) {
    showHome(res.data);
  } else {
    $('codeError').textContent = res.error || 'Ошибка';
  }
});

$('botBtnCode').addEventListener('click', () => window.zigga.openBot());

function showCode() {
  $('screen-code').classList.remove('hidden');
  $('screen-home').classList.add('hidden');
}
function showHome(data) {
  $('screen-code').classList.add('hidden');
  $('screen-home').classList.remove('hidden');
  renderHome(data);
}

async function renderHome(data) {
  if (!data) {
    const s = await window.zigga.getSession();
    data = s && s.response;
  }
  if (!data) { showCode(); return; }
  const brand = data.brand || 'ZIGGA';
  $('brandTitle').textContent = brand + ' VPN';
  $('configTitle').textContent = brand + ' VPN';
  const cfg = await window.zigga.getConfig();
  const storeCfg = cfg.config;
  if (storeCfg && storeCfg.name) $('configTitle').textContent = storeCfg.name;
  $('configSummary').textContent = storeCfg ? (storeCfg.filename || 'Конфиг получен') : 'Конфиг не получен';
  const user = data.user || {};
  $('accountLine').textContent = user.nickname ? 'Аккаунт: ' + user.nickname : '';
  const bal = data.balance;
  $('balanceLine').textContent = (bal != null) ? ('Баланс: ' + bal) : '';
  const sub = data.subscription || {};
  const subText = sub.active ? ('Подписка активна' + (sub.daysLeft != null ? ' · ' + sub.daysLeft + ' дн.' : '')) : 'Подписка не активна';
  $('subLine').textContent = subText;
  $('subLine').style.color = sub.active ? '#B4E832' : '#98A4B8';
  const cfgErr = data.configError;
  if (cfgErr) {
    const map = { no_device: 'Нет устройства', subscription_expired: 'Подписка закончилась' };
    $('configStatus').textContent = 'Конфиг: ' + (map[cfgErr] || cfgErr);
  } else if (storeCfg) {
    $('configStatus').textContent = 'Конфиг получен';
  } else {
    $('configStatus').textContent = '';
  }
  updatePowerUI();
  updateHint();
}

function updatePowerUI() {
  const btn = $('powerBtn');
  btn.classList.remove('on', 'connecting');
  if (connected) btn.classList.add('on');
  else if (connecting) btn.classList.add('connecting');
  const dot = $('statusDot');
  dot.classList.remove('connected', 'connecting', 'error');
  if (connected) dot.classList.add('connected');
  else if (connecting) dot.classList.add('connecting');
}
function updateHint() {
  const el = $('powerHint');
  if (connecting) { el.textContent = 'Подключение…'; return; }
  if (connected) { el.textContent = 'Нажмите, чтобы отключить'; return; }
  window.zigga.getConfig().then(cfg => {
    if (!cfg.valid) {
      el.textContent = cfg.config ? 'Конфиг недействителен — обновите данные' : 'Конфиг не получен — нажмите «Обновить»';
    } else {
      el.textContent = 'Нажмите, чтобы подключиться';
    }
  });
}

$('powerBtn').addEventListener('click', async () => {
  if (connecting) return;
  if (connected) { connected = false; updatePowerUI(); updateHint(); return; }
  const cfg = await window.zigga.getConfig();
  if (!cfg.valid) {
    $('statusError').textContent = 'Ошибка: ' + (cfg.config ? 'Конфиг недействителен — нажмите «Обновить»' : 'Конфиг не получен — нажмите «Обновить»');
    return;
  }
  $('statusError').textContent = '';
  connecting = true; updatePowerUI(); updateHint();
  setTimeout(async () => {
    const r = await window.zigga.openInWireGuard();
    connecting = false;
    if (r.ok) {
      connected = true;
    } else {
      connected = false;
      $('statusError').textContent = 'Ошибка: ' + (r.error || 'Не удалось открыть WireGuard. Установите WireGuard для Windows.');
    }
    updatePowerUI(); updateHint();
  }, 600);
});

$('refreshBtn').addEventListener('click', async () => {
  $('homeSpinner').style.display = 'inline-block';
  const res = await window.zigga.refresh();
  $('homeSpinner').style.display = 'none';
  if (res.ok) renderHome(res.data);
  else $('statusError').textContent = 'Ошибка: ' + (res.error || '');
});

$('logoutBtn').addEventListener('click', async () => {
  if (!confirm('Выйти из аккаунта? Пароль и конфиг будут удалены с устройства.')) return;
  connected = false;
  await window.zigga.logout();
  showCode();
  pinInput.value = '';
  pinBoxes.forEach(b => { b.textContent = ''; b.classList.remove('filled'); });
  loginBtn.disabled = true;
});

$('importBtn').addEventListener('click', async () => {
  const res = await window.zigga.importConfig();
  if (res.canceled) return;
  if (res.ok) {
    $('statusError').textContent = '';
    const cfg = await window.zigga.getConfig();
    $('configSummary').textContent = cfg.config ? cfg.config.filename : 'Конфиг импортирован';
    $('configStatus').textContent = 'Конфиг импортирован из файла';
    updateHint();
  } else {
    $('statusError').textContent = 'Ошибка: ' + (res.error || 'Не удалось импортировать');
  }
});

$('exportBtn').addEventListener('click', async () => {
  const res = await window.zigga.exportConfig();
  if (res.canceled) return;
  if (!res.ok) $('statusError').textContent = 'Ошибка: ' + (res.error || '');
});

$('wgBtn').addEventListener('click', async () => {
  const res = await window.zigga.openInWireGuard();
  if (!res.ok) $('statusError').textContent = 'Ошибка: ' + (res.error || 'WireGuard не установлен');
});

$('botBtnHome').addEventListener('click', () => window.zigga.openBot());

(async function boot() {
  const s = await window.zigga.getSession();
  if (s && s.response) showHome(s.response);
  else showCode();
})();
