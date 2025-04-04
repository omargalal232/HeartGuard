importScripts("https://www.gstatic.com/firebasejs/9.6.1/firebase-app.js");
importScripts("https://www.gstatic.com/firebasejs/9.6.1/firebase-messaging.js");

firebase.initializeApp({
  apiKey: "AIzaSyD4Nl9us2UBIF_9AOjYjrojJ2Fl5v7zzBE",
  authDomain: "heart-guard-1c49e.firebaseapp.com",
  projectId: "heart-guard-1c49e",
  storageBucket: "heart-guard-1c49e.firebasestorage.app",
  messagingSenderId: "872244640879",
  appId: "1:872244640879:web:0ede0a68d4c6a29c2a619a"
});

const messaging = firebase.messaging();
