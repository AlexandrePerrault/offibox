/**
 * Configuration Firebase pour le site web Offibox.
 * Alignée sur lib/firebase_options.dart (projet offibox-prod).
 */
(function() {
  'use strict';
  if (typeof firebase === 'undefined') return;
  var config = {
    apiKey: 'AIzaSyA3eizSKEwkUnH1Y5Xcum3fVgczGgPAFkk',
    authDomain: 'offibox-prod.firebaseapp.com',
    projectId: 'offibox-prod',
    storageBucket: 'offibox-prod.firebasestorage.app',
    messagingSenderId: '264737328165',
    appId: '1:264737328165:web:d8744f8fc1c188d9ddc3cc',
    measurementId: 'G-E1FP98K8WE'
  };
  if (!firebase.apps.length) {
    firebase.initializeApp(config);
  }
})();
