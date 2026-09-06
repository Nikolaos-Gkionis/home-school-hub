// A service worker is a background script the browser installs with the app.
// Chrome and Edge require a fetch handler before they will offer "Install".
const CACHE_NAME = "home-school-hub-v1"
const PRECACHE_URLS = ["/icon.png", "/icon.svg", "/icon-192.png", "/offline.html"]

self.addEventListener("install", (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => cache.addAll(PRECACHE_URLS)).then(() => self.skipWaiting())
  )
})

self.addEventListener("activate", (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key)))
    ).then(() => self.clients.claim())
  )
})

// Network-first: always try the live app (lessons and logins change often).
// If the device is offline, show a cached file or the offline page.
self.addEventListener("fetch", (event) => {
  const { request } = event
  if (request.method !== "GET") return

  event.respondWith(
    fetch(request).catch(async () => {
      const cached = await caches.match(request)
      if (cached) return cached
      if (request.mode === "navigate") return caches.match("/offline.html")
      return Response.error()
    })
  )
})
