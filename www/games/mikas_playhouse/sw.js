/* Mika's Adorable Playhouse: offline support.
   Serves everything from the saved copy first, refreshes it in the background. */
const CACHE = 'mph-v1';
const SHELL = ['./', 'index.html', 'manifest.webmanifest', 'icon-192.png', 'icon-512.png', 'apple-touch-icon.png'];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE)
      .then(c => c.addAll(SHELL.map(u => new Request(u, { cache: 'reload' }))))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k.startsWith('mph-') && k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const r = e.request;
  if (r.method !== 'GET') return;
  if (r.cache === 'reload' || r.cache === 'no-store') return; // the page is saving or checking files itself
  const u = new URL(r.url);
  const fonts = /(^|\.)(googleapis|gstatic)\.com$/.test(u.hostname);
  if (u.origin !== location.origin && !fonts) return;        // e.g. the GitHub API: leave alone
  e.respondWith(swr(e, r));
});

async function swr(e, r) {
  const cache = await caches.open(CACHE);
  const hit = await cache.match(r, { ignoreSearch: true });
  const net = fetch(r, { cache: 'no-cache' })
    .then(res => {
      if (res && (res.status === 200 || res.type === 'opaque')) cache.put(r, res.clone());
      return res;
    })
    .catch(() => null);
  if (hit) { e.waitUntil(net); return ranged(hit, r); }
  const res = await net;
  if (res) return res;
  if (r.mode === 'navigate') {
    const home = await cache.match(new URL('index.html', self.registration.scope).href);
    if (home) return home;
  }
  return new Response('Offline', { status: 503, statusText: 'Offline' });
}

/* Safari won't play cached audio/video unless Range requests get 206 answers. */
async function ranged(res, r) {
  const h = r.headers.get('range');
  const m = h && /bytes=(\d*)-(\d*)/.exec(h);
  if (!m || res.status !== 200) return res;
  const buf = await res.clone().arrayBuffer(), size = buf.byteLength;
  const s = m[1] === '' ? Math.max(size - Number(m[2]), 0) : Number(m[1]);
  const end = m[1] !== '' && m[2] !== '' ? Math.min(Number(m[2]), size - 1) : size - 1;
  return new Response(buf.slice(s, end + 1), {
    status: 206, statusText: 'Partial Content',
    headers: {
      'Content-Type': res.headers.get('Content-Type') || 'application/octet-stream',
      'Content-Range': `bytes ${s}-${end}/${size}`,
      'Content-Length': String(end - s + 1),
      'Accept-Ranges': 'bytes'
    }
  });
}
