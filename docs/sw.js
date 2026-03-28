const CACHE_NAME = 'dbcheck-v4';
const PRECACHE_URLS = [
    '/',
    '/index.html',
    '/static/index.html'
];

// Install: precache static assets
self.addEventListener('install', function(event) {
    event.waitUntil(
        caches.open(CACHE_NAME).then(function(cache) {
            return Promise.all(PRECACHE_URLS.map(function(url) {
                return cache.add(url).catch(function() {
                    console.warn('Failed to precache:', url);
                });
            }));
        }).then(function() {
            return self.skipWaiting();
        })
    );
});

// Activate: clean old caches
self.addEventListener('activate', function(event) {
    event.waitUntil(
        caches.keys().then(function(names) {
            return Promise.all(
                names.filter(function(name) { return name !== CACHE_NAME; })
                    .map(function(name) { return caches.delete(name); })
            );
        }).then(function() {
            return self.clients.claim();
        })
    );
});

// Fetch: network-first for HTML pages, stale-while-revalidate for other static assets
self.addEventListener('fetch', function(event) {
    var url = new URL(event.request.url);

    // Never cache API calls, admin API, or non-GET requests
    if (url.pathname.startsWith('/api/') ||
        url.pathname.startsWith('/admin/api/') ||
        event.request.method !== 'GET') {
        return;
    }

    // HTML pages: network-first (always show latest, fallback to cache offline)
    var isPage = event.request.mode === 'navigate' ||
        url.pathname === '/' ||
        url.pathname.endsWith('.html');

    if (isPage) {
        event.respondWith(
            fetch(event.request).then(function(response) {
                if (response.ok) {
                    var clone = response.clone();
                    caches.open(CACHE_NAME).then(function(cache) {
                        cache.put(event.request, clone);
                    }).catch(function() {});
                }
                return response;
            }).catch(function() {
                return caches.match(event.request);
            })
        );
        return;
    }

    // Other static assets: stale-while-revalidate
    event.respondWith(
        caches.match(event.request).then(function(cached) {
            var fetched = fetch(event.request).then(function(response) {
                if (response.ok) {
                    var clone = response.clone();
                    caches.open(CACHE_NAME).then(function(cache) {
                        cache.put(event.request, clone);
                    }).catch(function() {});
                }
                return response;
            }).catch(function() {
                return cached;
            });
            return cached || fetched;
        })
    );
});
