export function registerServiceWorker() {
  if (import.meta.env.PROD && 'serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      void navigator.serviceWorker.register('/sw.js', { updateViaCache: 'none' })
        .catch((error: unknown) => {
          console.error('Enregistrement PWA impossible.', error)
        })
    })
  }
}
