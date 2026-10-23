// Aucun précache, Cache API, stockage local ni interception des requêtes.
// L'installation PWA ne fournit aucun fonctionnement hors ligne.
self.addEventListener('install', () => {
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim())
})
