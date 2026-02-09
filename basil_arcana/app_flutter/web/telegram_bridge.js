(function () {
  'use strict';

  var readyCalled = false;

  function getWebApp() {
    try {
      if (window.Telegram && window.Telegram.WebApp) {
        return window.Telegram.WebApp;
      }
    } catch (error) {
      return null;
    }
    return null;
  }

  function callReadyOnce() {
    var webApp = getWebApp();
    if (!webApp) {
      return false;
    }
    if (readyCalled) {
      return true;
    }
    readyCalled = true;
    try {
      if (typeof webApp.ready === 'function') {
        webApp.ready();
      }
    } catch (error) {}
    return true;
  }

  function readInitData() {
    var webApp = getWebApp();
    if (webApp && typeof webApp.initData === 'string' && webApp.initData.trim()) {
      return webApp.initData;
    }
    if (typeof window.__tgInitData === 'string' && window.__tgInitData.trim()) {
      return window.__tgInitData;
    }
    return '';
  }

  function refreshInitData() {
    callReadyOnce();
    var value = readInitData();
    if (value && typeof value === 'string' && value.trim()) {
      window.__tgInitData = value;
      window.__isTelegram = true;
      window.isTelegramWebApp = true;
      return value;
    }
    return '';
  }

  window.__tgInitDataGetter = function () {
    return refreshInitData();
  };

  var initial = refreshInitData();
  if (!initial) {
    var available = Boolean(getWebApp());
    window.isTelegramWebApp = available;
    if (available) {
      window.__isTelegram = true;
    }
  }

  window.tgIsAvailable = function () {
    return Boolean(getWebApp());
  };

  window.tgSendData = function (payload) {
    var webApp = getWebApp();
    if (!webApp || typeof webApp.sendData !== 'function') {
      return false;
    }
    try {
      webApp.sendData(String(payload || ''));
      return true;
    } catch (error) {
      return false;
    }
  };

  window.tgClose = function () {
    var webApp = getWebApp();
    if (!webApp || typeof webApp.close !== 'function') {
      return false;
    }
    try {
      webApp.close();
      return true;
    } catch (error) {
      return false;
    }
  };

  window.tgOpenTelegramLink = function (url) {
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
    } catch (error) {}
    try {
      window.open(link, '_blank');
      return true;
    } catch (error) {
      return false;
    }
  };
})();
