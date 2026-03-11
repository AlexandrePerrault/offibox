/**
 * Fichier client pour la période d'essai de 15 jours.
 * Stocke la date de début d'essai (au premier accès ou à l'inscription) et expose
 * des helpers pour vérifier si l'essai est encore valide.
 */
(function() {
  'use strict';
  var TRIAL_DAYS = 15;
  var STORAGE_KEY = 'offibox_trial_start';

  function nowIso() {
    return new Date().toISOString().slice(0, 10);
  }

  function getStart() {
    try {
      return localStorage.getItem(STORAGE_KEY) || null;
    } catch (e) {
      return null;
    }
  }

  function setStart(dateIso) {
    try {
      localStorage.setItem(STORAGE_KEY, dateIso || nowIso());
      return true;
    } catch (e) {
      return false;
    }
  }

  function daysBetween(a, b) {
    var d1 = new Date(a);
    var d2 = new Date(b);
    return Math.round((d2 - d1) / (24 * 60 * 60 * 1000));
  }

  /**
   * Démarre l'essai si pas encore démarré (à appeler après inscription ou premier accès).
   */
  function startIfNeeded() {
    if (getStart()) return;
    setStart(nowIso());
  }

  /**
   * Retourne la date de début d'essai (YYYY-MM-DD) ou null.
   */
  function getTrialStartDate() {
    return getStart();
  }

  /**
   * Retourne le nombre de jours restants (0 si expiré). Max TRIAL_DAYS.
   */
  function getDaysRemaining() {
    var start = getStart();
    if (!start) return TRIAL_DAYS;
    var elapsed = daysBetween(start, nowIso());
    var remaining = TRIAL_DAYS - elapsed;
    return remaining > 0 ? remaining : 0;
  }

  /**
   * true si l'essai est encore valide.
   */
  function isTrialValid() {
    return getDaysRemaining() > 0;
  }

  /**
   * Nombre de jours depuis le début de l'essai (0 si pas démarré).
   */
  function getDaysUsed() {
    var start = getStart();
    if (!start) return 0;
    var n = daysBetween(start, nowIso());
    return n > TRIAL_DAYS ? TRIAL_DAYS : n;
  }

  window.OffiboxTrial = {
    TRIAL_DAYS: TRIAL_DAYS,
    startIfNeeded: startIfNeeded,
    getTrialStartDate: getTrialStartDate,
    getDaysRemaining: getDaysRemaining,
    isTrialValid: isTrialValid,
    getDaysUsed: getDaysUsed
  };
})();
