/**
 * Wrapper Firebase Auth pour le site web Offibox.
 * Connexion par e-mail/mot de passe uniquement pour l'instant.
 * signInWithGoogle est conservé pour une réactivation ultérieure (Gmail).
 */
(function() {
  'use strict';
  if (typeof firebase === 'undefined') {
    window.OffiboxAuth = null;
    return;
  }
  var auth = firebase.auth();
  /** LOCAL = rester connecté (par défaut), SESSION = déconnexion à la fermeture de l'onglet */
  window.OffiboxAuth = {
    getCurrentUser: function() {
      return auth.currentUser;
    },
    onAuthStateChanged: function(callback) {
      return auth.onAuthStateChanged(callback);
    },
    setPersistenceStayLoggedIn: function(stayLoggedIn) {
      var p = stayLoggedIn ? firebase.auth.Auth.Persistence.LOCAL : firebase.auth.Auth.Persistence.SESSION;
      return auth.setPersistence(p);
    },
    signInWithGoogle: function() {
      return auth.signInWithPopup(new firebase.auth.GoogleAuthProvider());
    },
    signInWithEmailPassword: function(email, password) {
      return auth.signInWithEmailAndPassword(email, password);
    },
    signUpWithEmailPassword: function(email, password) {
      return auth.createUserWithEmailAndPassword(email, password);
    },
    sendPasswordResetEmail: function(email) {
      return auth.sendPasswordResetEmail(email);
    },
    signOut: function() {
      return auth.signOut();
    }
  };
})();
