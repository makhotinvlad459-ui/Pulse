importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: "AIzaSyBXoRO7sp49PotOrUEPmTsbRxCpcDpdyZ0",
    authDomain: "pulse-yourmoney.firebaseapp.com",
    projectId: "pulse-yourmoney",
    storageBucket: "pulse-yourmoney.firebasestorage.app",
    messagingSenderId: "267395124760",
    appId: "1:267395124760:web:93231e40b80650ccf9bd6d"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
    console.log("Background message:", payload);
    const notificationTitle = payload.notification?.title || "Новое сообщение";
    const notificationOptions = {
        body: payload.notification?.body || "",
        icon: "/icons/Icon-192.png"
    };
    self.registration.showNotification(notificationTitle, notificationOptions);
});