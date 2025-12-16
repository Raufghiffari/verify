const { app, BrowserWindow, ipcMain, globalShortcut } = require('electron')
const { exec } = require('child_process')
const path = require('path')

let win
let isLogonPage = false

// ================= CONFIG =================
const PASSWORD = '0010373705'
const MAX_INTERVAL = 50
const REQUIRED_LEN = 10
const DEBUG = true
// ==========================================

function log (...args) {
  if (!DEBUG) return
  console.log('[MAIN]', new Date().toISOString(), ...args)
}

// ================= WINDOW =================
function createWindow () {
  win = new BrowserWindow({
    fullscreen: true,
    kiosk: true,
    frame: false,
    autoHideMenuBar: true,
    backgroundColor: '#000',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js')
    }
  })

  // ===== RENDERER LOG =====
  win.webContents.on('console-message', (_, level, message, line, sourceId) => {
    const map = ['LOG', 'WARN', 'ERROR']
    console.log(`[RENDERER:${map[level] || level}] ${message} (${sourceId}:${line})`)
  })

  // ===== ROUTE DETECTION =====
  win.webContents.on('did-navigate', (_, url) => handleRoute(url))
  win.webContents.on('did-navigate-in-page', (_, url) => handleRoute(url))

  // ===== LOAD BLANK =====
  win.loadFile('index.html')

  win.webContents.once('did-finish-load', () => {
    setTimeout(() => {
      win.loadFile('home.html')
    }, 300)
  })
}

// ================= ROUTE HANDLER =================
function handleRoute (url) {
  const clean = url.split('?')[0].split('#')[0]
  log('route', clean)

  const isLogon =
    clean.endsWith('/winlogon.html') ||
    clean.endsWith('/linuxlogon.html') ||
    clean.endsWith('/winlogon') ||
    clean.endsWith('/linuxlogon')

  if (isLogon) {
    if (!isLogonPage) {
      log('ENTER LOGON')
      isLogonPage = true
      injectRFID()
    }
  } else {
    if (isLogonPage) {
      log('EXIT LOGON')
      isLogonPage = false
      removeRFID()
    }
  }
}

// ================= RFID INJECT =================
function injectRFID () {
  win.webContents.executeJavaScript(`
    (() => {
      if (window.__rfid_active__) return
      window.__rfid_active__ = true

      let buffer = ''
      let lastTime = 0

      const clearAll = () => {
        buffer = ''
        lastTime = 0
      }

      const onKey = (e) => {
        const ch = e.key

        // hanya angka
        if (!/^[0-9]$/.test(ch)) {
          clearAll()
          return
        }

        const now = Date.now()
        if (lastTime && now - lastTime > ${MAX_INTERVAL}) {
          clearAll()
          return
        }

        buffer += ch
        lastTime = now

        if (buffer.length === ${REQUIRED_LEN}) {
          if (buffer === '${PASSWORD}') {
            window.postMessage({ type: 'RFID_OK' }, '*')
          } else {
            window.postMessage({ type: 'RFID_FAIL' }, '*')
          }
          clearAll()
        }
      }

      window.addEventListener('keydown', onKey, true)

      // cleanup saat keluar logon
      window.__rfid_cleanup__ = () => {
        window.removeEventListener('keydown', onKey, true)
        window.__rfid_active__ = false
      }
    })()
  `)
}

function removeRFID () {
  win.webContents.executeJavaScript(`
    if (window.__rfid_cleanup__) {
      window.__rfid_cleanup__()
      delete window.__rfid_cleanup__
    }
  `)
}

// ================= IPC =================
ipcMain.on('rfid-ok', () => {
  log('RFID OK')

  // 1. load success page
  win.loadFile('success.html')

  // 2. tunggu success tampil 5 detik
  setTimeout(() => {

    // 3. inject fade style + trigger fade (2 detik)
    win.webContents.executeJavaScript(`
      (() => {
        const style = document.createElement('style')
        style.innerHTML = \`
          body {
            opacity: 1;
            transition: opacity 2s ease;
          }
        \`
        document.head.appendChild(style)

        requestAnimationFrame(() => {
          document.body.style.opacity = '0'
        })
      })()
    `)

    // 4. tunggu fade selesai 2 detik
    setTimeout(() => {

      // 5. tunggu ekstra 1 detik
      setTimeout(() => {
        log('REBOOT ALPINE → WINDOWS')

        if (process.platform === 'linux') {
          exec('reboot')
        }
      }, 1000)

    }, 2000)

  }, 5000)
})

// ================= APP =================
app.whenReady().then(createWindow)

app.on('window-all-closed', () => app.quit())
