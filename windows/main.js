const { app, BrowserWindow, ipcMain, dialog, shell } = require('electron');
const path = require('path');
const fs = require('fs');
const https = require('https');
const Store = require('electron-store');

const store = new Store({ name: 'zigga' });
const API_BASE = 'https://v0-telegram-vpn-bot-iota.vercel.app';

function createWindow() {
  const win = new BrowserWindow({
    width: 420,
    height: 760,
    minWidth: 360,
    minHeight: 600,
    resizable: true,
    title: 'ZIGGA VPN',
    backgroundColor: '#05070D',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });
  win.loadFile(path.join(__dirname, 'src', 'index.html'));
}

app.whenReady().then(() => {
  createWindow();
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});

function mapError(err, status) {
  const e = (err || '').toLowerCase();
  if (e === 'invalid_pin_format') return 'Пароль должен состоять из 6 цифр';
  if (e === 'wrong_pin') return 'Неверный пароль';
  if (e === 'too_many_attempts') return 'Слишком много попыток. Попробуйте через 15 минут';
  if (status === 401) return 'Неверный пароль';
  if (status === 429) return 'Слишком много попыток. Попробуйте через 15 минут';
  return 'Сервер ответил ошибкой ' + status;
}

function doLogin(pin) {
  return new Promise((resolve) => {
    try {
      const url = new URL(API_BASE + '/api/app/login');
      const body = JSON.stringify({ pin });
      const req = https.request(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-store',
          'User-Agent': 'ZIGGA-Windows/1.0'
        }
      }, (res) => {
        let data = '';
        res.on('data', (c) => { data += c; });
        res.on('end', () => {
          let decoded = null;
          try { decoded = JSON.parse(data); } catch (e) { decoded = null; }
          if (res.statusCode === 200 && decoded && decoded.ok === true) {
            store.set('session', { pin, response: decoded, savedAt: Date.now() });
            if (decoded.config && decoded.config.content) {
              store.set('config', {
                name: decoded.config.name || 'ZIGGA',
                filename: decoded.config.filename || 'zigga.conf',
                type: decoded.config.type || 'amneziawg',
                content: decoded.config.content
              });
              store.set('configValid', true);
            } else {
              store.set('configValid', false);
            }
            resolve({ ok: true, data: decoded });
          } else {
            const err = (decoded && decoded.error) ? decoded.error : '';
            resolve({ ok: false, error: mapError(err, res.statusCode) });
          }
        });
      });
      req.on('error', () => resolve({ ok: false, error: 'Нет связи с сервером. Проверьте интернет' }));
      req.write(body);
      req.end();
    } catch (e) {
      resolve({ ok: false, error: 'Ошибка запроса' });
    }
  });
}

ipcMain.handle('zigga:login', async (_event, pin) => doLogin(pin));

ipcMain.handle('zigga:refresh', async () => {
  const s = store.get('session');
  if (!s || !s.pin) return { ok: false, error: 'Нет сохранённого пароля' };
  return doLogin(s.pin);
});

ipcMain.handle('zigga:getSession', async () => store.get('session') || null);
ipcMain.handle('zigga:getConfig', async () => ({ config: store.get('config') || null, valid: !!store.get('configValid') }));

ipcMain.handle('zigga:logout', async () => {
  store.delete('session');
  store.delete('config');
  store.delete('configValid');
  store.delete('configSource');
  return { ok: true };
});

ipcMain.handle('zigga:importConfig', async () => {
  const result = await dialog.showOpenDialog({
    title: 'Импорт конфига',
    filters: [{ name: 'WireGuard/AmneziaWG', extensions: ['conf', 'vpn', 'txt'] }, { name: 'Все файлы', extensions: ['*'] }],
    properties: ['openFile']
  });
  if (result.canceled || !result.filePaths || !result.filePaths.length) return { ok: false, canceled: true };
  const filePath = result.filePaths[0];
  let raw = '';
  try { raw = fs.readFileSync(filePath, 'utf8'); }
  catch (e) { return { ok: false, error: 'Не удалось прочитать файл' }; }
  if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1);
  const validation = validateConfig(raw);
  if (!validation.ok) return { ok: false, error: validation.error };
  const name = path.basename(filePath);
  store.set('config', { name, filename: name, type: 'amneziawg', content: validation.cleaned });
  store.set('configValid', true);
  store.set('configSource', 'file:' + filePath);
  try {
    const outDir = path.join(app.getPath('userData'), 'configs');
    fs.mkdirSync(outDir, { recursive: true });
    fs.writeFileSync(path.join(outDir, name), validation.cleaned, 'utf8');
  } catch (e) {}
  return { ok: true, name, cleaned: validation.cleaned };
});

function validateConfig(raw) {
  let text = raw.replace(/\r\n/g, '\n').replace(/\r/g, '\n');
  const lines = text.split('\n');
  const sections = { Interface: [], Peer: [] };
  let current = null;
  const unsupported = new Set(['I1','I2','I3','I4','I5','J1','J2','J3','Table','SaveConfig','FwMark','fwmark','saveconfig','table']);
  for (const rawLine of lines) {
    const line = rawLine.trim();
    if (!line) continue;
    if (line.startsWith('#') || line.startsWith(';')) continue;
    const secMatch = line.match(/^\[(.+)\]$/);
    if (secMatch) {
      const sec = secMatch[1].trim();
      current = (sec === 'Interface' || sec === 'Peer') ? sec : null;
      continue;
    }
    if (!current) continue;
    const eq = line.indexOf('=');
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    const val = line.slice(eq + 1).trim();
    if (!key) continue;
    if (unsupported.has(key)) continue;
    sections[current].push(key + ' = ' + val);
  }
  const iface = sections.Interface;
  const peer = sections.Peer;
  const ifaceKeys = new Set(iface.map((l) => l.split('=')[0].trim()));
  const peerKeys = new Set(peer.map((l) => l.split('=')[0].trim()));
  if (!ifaceKeys.has('PrivateKey')) return { ok: false, error: 'не хватает PrivateKey' };
  if (!ifaceKeys.has('Address')) return { ok: false, error: 'нет Address' };
  if (peer.length === 0) return { ok: false, error: 'нет секции [Peer]' };
  if (!peerKeys.has('PublicKey')) return { ok: false, error: 'не хватает PublicKey' };
  if (!peerKeys.has('Endpoint')) return { ok: false, error: 'нет Endpoint' };
  const cleaned = '[Interface]\n' + iface.join('\n') + '\n\n[Peer]\n' + peer.join('\n') + '\n';
  return { ok: true, cleaned };
}

ipcMain.handle('zigga:exportConfig', async () => {
  const c = store.get('config');
  if (!c || !c.content) return { ok: false, error: 'Нет конфига' };
  const result = await dialog.showSaveDialog({
    title: 'Сохранить конфиг',
    defaultPath: c.filename || 'zigga.conf',
    filters: [{ name: 'WireGuard config', extensions: ['conf'] }]
  });
  if (result.canceled || !result.filePath) return { ok: false, canceled: true };
  try { fs.writeFileSync(result.filePath, c.content, 'utf8'); return { ok: true, path: result.filePath }; }
  catch (e) { return { ok: false, error: 'Не удалось сохранить' }; }
});

ipcMain.handle('zigga:openBot', async () => {
  try { await shell.openExternal('https://t.me/ziggabot?start=ZIGGA7FXSDZW'); return { ok: true }; }
  catch (e) { return { ok: false }; }
});

ipcMain.handle('zigga:openInWireGuard', async () => {
  const c = store.get('config');
  if (!c || !c.content) return { ok: false, error: 'Нет конфига' };
  const dir = path.join(app.getPath('userData'), 'configs');
  fs.mkdirSync(dir, { recursive: true });
  const filePath = path.join(dir, c.filename || 'zigga.conf');
  fs.writeFileSync(filePath, c.content, 'utf8');
  const res = await shell.openPath(filePath);
  return { ok: res === '', error: res || null };
});
