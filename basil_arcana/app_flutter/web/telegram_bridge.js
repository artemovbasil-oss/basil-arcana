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

  function readInitDataFromUrl() {
    var search = window.location.search || '';
    var hash = window.location.hash || '';
    var candidates = [];
    if (search) {
      candidates.push(search.charAt(0) === '?' ? search.slice(1) : search);
    }
    if (hash) {
      var trimmedHash = hash.charAt(0) === '#' ? hash.slice(1) : hash;
      if (trimmedHash.indexOf('?') !== -1) {
        trimmedHash = trimmedHash.split('?').pop();
      }
      candidates.push(trimmedHash);
    }
    for (var i = 0; i < candidates.length; i += 1) {
      try {
        var params = new URLSearchParams(candidates[i]);
        var initData =
          params.get('tgWebAppData') ||
          params.get('tgInitData') ||
          params.get('initData');
        if (initData && typeof initData === 'string') {
          return initData;
        }
      } catch (error) {
        console.warn('Telegram initData URL parsing failed', error);
      }
    }
    return '';
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

  var urlInitData = readInitDataFromUrl();

  window.__isTelegram = Boolean(urlInitData);
  window.__tgInitData = function () {
    var webApp = getWebApp();
    if (!webApp) {
      return urlInitData || '';
    }
    var initData = webApp.initData;
    if (typeof initData === 'string' && initData) {
      return initData;
    }
    return urlInitData || '';
  };

  scheduleReadyCheck(60);

  function tgIsAvailable() {
    return Boolean(getWebApp());
  }

  function tgSendData(payload) {
    var webApp = getWebApp();
    if (!webApp || typeof webApp.sendData !== 'function') {
      return false;
    }
    try {
      webApp.sendData(String(payload || ''));
      return true;
    } catch (error) {
      console.warn('Telegram sendData failed', error);
      return false;
    }
  }

  function tgClose() {
    var webApp = getWebApp();
    if (!webApp || typeof webApp.close !== 'function') {
      return false;
    }
    try {
      webApp.close();
      return true;
    } catch (error) {
      console.warn('Telegram close failed', error);
      return false;
    }
  }

  function tgOpenTelegramLink(url) {
    var link = String(url || '');
    if (!link) {
      return false;
    }
    var webApp = getWebApp();
    try {
      if (webApp && typeof webApp.openTelegramLink === 'function') {
        webApp.openTelegramLink(link);
        return true;
      }
    } catch (error) {
      console.warn('Telegram openTelegramLink failed', error);
    }
    try {
      window.open(link, '_blank');
      return true;
    } catch (error) {
      console.warn('window.open failed', error);
      return false;
    }
  }

  window.tgIsAvailable = tgIsAvailable;
  window.tgSendData = tgSendData;
  window.tgClose = tgClose;
  window.tgOpenTelegramLink = tgOpenTelegramLink;
})();
