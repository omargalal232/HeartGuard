importScripts("https://www.gstatic.com/firebasejs/9.6.0/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.0/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyAljUNCr6Qh6FikDif2oDZ6tU38wENopC0",
  authDomain: "heart-guard-1c49e.firebaseapp.com",
  projectId: "heart-guard-1c49e",
  storageBucket: "heart-guard-1c49e.appspot.com",
  messagingSenderId: "872244640879",
  appId: "1:872244640879:android:53503e5e780fc6a82a619a",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  console.log('Received background message:', payload);

  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/notification_icon.png',
    badge: '/icons/notification_icon.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const urlToOpen = new URL('/', self.location.origin).href;

  event.waitUntil(
    clients.matchAll({
      type: 'window',
      includeUncontrolled: true
    })
    .then((windowClients) => {
      for (let client of windowClients) {
        if (client.url === urlToOpen && 'focus' in client) {
          return client.focus();
        }
      }
      return clients.openWindow(urlToOpen);
    })
  );
}); 