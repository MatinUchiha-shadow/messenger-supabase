// GapChat Service Worker - Push Notifications
self.addEventListener('install', function(event) {
  self.skipWaiting();
});

self.addEventListener('activate', function(event) {
  event.waitUntil(clients.claim());
});

self.addEventListener('push', function(event) {
  if (!event.data) return;
  try {
    var data = event.data.json();
    var options = {
      body: data.body || '',
      icon: data.icon || '/icon.png',
      badge: '/icon.png',
      tag: data.tag || 'gapchat',
      data: data.data || {},
      requireInteraction: false,
      vibrate: [200, 100, 200],
      silent: false
    };
    event.waitUntil(
      self.registration.showNotification(data.title || 'GapChat', options)
    );
  } catch(e) {
    // Plain text notification
    event.waitUntil(
      self.registration.showNotification('GapChat', {
        body: event.data.text(),
        icon: '/icon.png'
      })
    );
  }
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      for (var i = 0; i < clientList.length; i++) {
        var client = clientList[i];
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    })
  );
});
