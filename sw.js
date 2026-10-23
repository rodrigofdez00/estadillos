// Guarda la app en el móvil para que funcione sin cobertura.
const CACHE = 'estadillos-v3';
const LIBS = [
  'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js'
];
const ASSETS = ['./', './index.html', './config.js', './manifest.webmanifest', './icon.svg', ...LIBS];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS)).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  // Librerías: siempre la copia guardada (llevan versión fija en la URL).
  if (LIBS.includes(req.url)) {
    e.respondWith(caches.match(req).then(hit => hit || fetch(req).then(res => { const cp = res.clone(); caches.open(CACHE).then(c => c.put(req, cp)); return res; })));
    return;
  }
  // Archivos de la app: primero la red para recibir versiones nuevas; sin red, la copia guardada.
  // Lo demás (Supabase, mapas) pasa directo sin guardarse.
  if (url.origin !== self.location.origin) return;
  e.respondWith(
    fetch(req)
      .then(res => { if (res.ok) { const cp = res.clone(); caches.open(CACHE).then(c => c.put(req.mode === 'navigate' ? './index.html' : req, cp)); } return res; })
      .catch(() => caches.match(req.mode === 'navigate' ? './index.html' : req))
  );
});
