const STATIC_CACHE = "manual-guardian-shell-v1";
const IMAGE_CACHE = "manual-guardian-images-v1";
const SHELL = ["./", "./index.html", "./manifest.webmanifest", "./assets/app-icon-192.png", "./assets/app-icon-512.png", "./assets/mythag-insignia.svg"];
self.addEventListener("install", event => { event.waitUntil(caches.open(STATIC_CACHE).then(cache => cache.addAll(SHELL)).then(() => self.skipWaiting())); });
self.addEventListener("activate", event => { event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key.startsWith("manual-guardian-") && ![STATIC_CACHE, IMAGE_CACHE].includes(key)).map(key => caches.delete(key)))).then(() => self.clients.claim())); });
self.addEventListener("fetch", event => {
  const request = event.request;
  if (request.method !== "GET" || new URL(request.url).origin !== self.location.origin) return;
  if (request.mode === "navigate") {
    event.respondWith(fetch(request).then(response => { const copy = response.clone(); caches.open(STATIC_CACHE).then(cache => cache.put("./index.html", copy)); return response; }).catch(() => caches.match("./index.html")));
    return;
  }
  if (new URL(request.url).pathname.includes("/assets/")) {
    event.respondWith(caches.open(IMAGE_CACHE).then(async cache => {
      const cached = await cache.match(request);
      const fresh = fetch(request).then(async response => { if (response.ok) { await cache.put(request, response.clone()); const keys = await cache.keys(); for (const old of keys.slice(80)) await cache.delete(old); } return response; }).catch(() => cached);
      return cached || fresh;
    }));
  }
});
