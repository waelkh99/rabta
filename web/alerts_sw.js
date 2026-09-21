// A service worker that exists only so notifications can be shown at all.
//
// Chrome for Android refuses `new Notification(...)` outright — the API is only
// reachable through a service worker registration — so Rabta registers this one
// and calls showNotification() on it. It caches nothing and intercepts no
// requests; Flutter's own generated worker does the caching in release builds,
// and the two do not overlap.
//
// Registered lazily, only once a seller has turned alerts on.

self.addEventListener('install', () => {
  // Take over immediately. The alternative is a worker that becomes active on
  // the next page load, which means the seller turns alerts on and the first
  // notification silently does not arrive.
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  // Bring the tab the seller already has, rather than opening a second Rabta.
  // Matching on origin rather than on an exact URL, because the application is
  // a single page and its address carries state we do not want to reset.
  event.waitUntil(
    self.clients
      .matchAll({ type: 'window', includeUncontrolled: true })
      .then((clients) => {
        for (const client of clients) {
          if (client.url.startsWith(self.registration.scope) && 'focus' in client) {
            client.postMessage({ conversation: event.notification.tag });
            return client.focus();
          }
        }

        // No tab open any more. Opening one is the whole point of having
        // clicked, and the scope is the application's own root.
        if (self.clients.openWindow) return self.clients.openWindow(self.registration.scope);
      }),
  );
});
