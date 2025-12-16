const { ipcRenderer } = require('electron')

window.addEventListener('message', e => {
  if (!e.data || !e.data.type) return

  if (e.data.type === 'RFID_OK') {
    ipcRenderer.send('rfid-ok')
  }

  if (e.data.type === 'RFID_FAIL') {
    ipcRenderer.send('rfid-fail')
  }
})
