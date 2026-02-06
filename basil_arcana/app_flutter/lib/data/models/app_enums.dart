import 'package:flutter/material.dart';

enum AppLanguage { en, ru, kz }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.en:
        return 'en';
      case AppLanguage.ru:
        return 'ru';
      case AppLanguage.kz:
        return 'kk';
    }
  }

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'ru':
        return AppLanguage.ru;
      case 'kk':
        return AppLanguage.kz;
      case 'en':
      default:
        return AppLanguage.en;
    }
  }

  static AppLanguage fromLocale(Locale locale) => fromCode(locale.languageCode);
}

enum SpreadType { one, three }

extension SpreadTypeX on SpreadType {
  String get storageValue => this == SpreadType.one ? 'one' : 'three';

  int get cardCount => this == SpreadType.one ? 1 : 3;

  static SpreadType fromStorage(String? value) {
    if (value == 'three') {
      return SpreadType.three;
    }
    return SpreadType.one;
  }
}
