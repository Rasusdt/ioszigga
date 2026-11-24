const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('zigga', {
  login: (pin) => ipcRenderer.invoke('zigga:login', pin),
  refresh: () => ipcRenderer.invoke('zigga:refresh'),
  getSession: () => ipcRenderer.invoke('zigga:getSession'),
  getConfig: () => ipcRenderer.invoke('zigga:getConfig'),
  logout: () => ipcRenderer.invoke('zigga:logout'),
  importConfig: () => ipcRenderer.invoke('zigga:importConfig'),
  exportConfig: () => ipcRenderer.invoke('zigga:exportConfig'),
  openBot: () => ipcRenderer.invoke('zigga:openBot'),
  openInWireGuard: () => ipcRenderer.invoke('zigga:openInWireGuard')
});
