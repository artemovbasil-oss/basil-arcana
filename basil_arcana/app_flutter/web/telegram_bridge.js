(function () {
  'use strict';

  var hasInitialized = false;

  function getWebApp() {
    try {
      if (window.Telegram && window.Telegram.WebApp) {
        return window.Telegram.WebApp;
      }
    } catch (error) {
      console.warn('Telegram WebApp access failed', error);
    }
    return null;
  }

  function ensureReady() {
    var webApp = getWebApp();
    if (!webApp) {
      return false;
    }
    window.__isTelegram = true;
    if (!hasInitialized) {
      hasInitialized = true;
      try {
        if (typeof webApp.ready === 'function') {
          webApp.ready();
        }
        if (typeof webApp.expand === 'function') {
          webApp.expand();
        }
      } catch (error) {
        console.warn('Telegram WebApp ready/expand failed', error);
      }
    }
    return true;
  }

  function scheduleReadyCheck(attemptsLeft) {
    if (ensureReady()) {
      return;
    }
    if (attemptsLeft <= 0) {
      return;
    }
    setTimeout(function () {
      scheduleReadyCheck(attemptsLeft - 1);
    }, 50);
  }

  window.__isTelegram = false;
  window.__tgInitData = function () {
    var webApp = getWebApp();
    if (!webApp) {
      return '';
    }
    var initData = webApp.initData;
    if (typeof initData === 'string') {
      return initData;
    }
    return '';
  };

  scheduleReadyCheck(60);
})();
