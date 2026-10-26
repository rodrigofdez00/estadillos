// Guarda la app en la tablet para que funcione sin cobertura.
const CACHE = 'estadillos-v7';
const TESELAS = 'estadillos-teselas';   // mapa del IGN: se conserva entre versiones
const LIBS = [
  'https://cdnjs.cloudflare.com/ajax/libs/xlsx/0.18.5/xlsx.full.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/dist/umd/supabase.min.js'
];
const ASSETS = ['./', './index.html', './config.js', './manifest.webmanifest', './icon.svg', ...LIBS];

self.addEventListener('install', e => {
  // Los archivos de la app se piden frescos al servidor; las librerías pueden venir de la caché.
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(ASSETS.map(u => LIBS.includes(u) ? u : new Request(u, { cache: 'reload' })))).then(() => self.skipWaiting()));
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(keys => Promise.all(keys.filter(k => k !== CACHE && k !== TESELAS).map(k => caches.delete(k))))
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
  // Teselas del IGN: la guardada si la hay; si no, se descarga y se guarda.
  if ((url.hostname === 'www.ign.es' && url.pathname.startsWith('/wmts/')) || url.hostname === 'server.arcgisonline.com') {
    // Las teselas llegan como respuesta opaca (sin CORS): también se guardan.
    // Una copia opaca no sirve a quien pide la tesela con CORS para leer sus píxeles (propuesta de parcelas).
    e.respondWith(caches.open(TESELAS).then(c => c.match(req.url).then(hit => (hit && !(hit.type === 'opaque' && req.mode === 'cors')) ? hit : fetch(req).then(res => { if (res.ok || res.type === 'opaque') c.put(req.url, res.clone()); return res; }))));
    return;
  }
  // Archivos de la app: primero la red para recibir versiones nuevas; sin red, la copia guardada.
  // Lo demás (Supabase) pasa directo sin guardarse.
  if (url.origin !== self.location.origin) return;
  // cache: 'no-cache' obliga a preguntar al servidor (GitHub Pages deja la página 10 min en la caché del navegador).
  e.respondWith(
    fetch(req.url, { cache: 'no-cache', credentials: 'same-origin' })
      .then(res => { if (res.ok) { const cp = res.clone(); caches.open(CACHE).then(c => c.put(req.mode === 'navigate' ? './index.html' : req, cp)); } return res; })
      .catch(() => caches.match(req.mode === 'navigate' ? './index.html' : req))
  );
});
