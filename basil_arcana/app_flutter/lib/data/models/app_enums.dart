import 'package:flutter/material.dart';

enum AppLanguage { en, ru, kz, fr, tr }

extension AppLanguageX on AppLanguage {
  String get code {
    switch (this) {
      case AppLanguage.en:
        return 'en';
      case AppLanguage.ru:
        return 'ru';
      case AppLanguage.kz:
        return 'kk';
      case AppLanguage.fr:
        return 'fr';
      case AppLanguage.tr:
        return 'tr';
    }
  }

  Locale get locale => Locale(code);

  static AppLanguage fromCode(String? code) {
    switch (code) {
      case 'ru':
        return AppLanguage.ru;
      case 'kk':
        return AppLanguage.kz;
      case 'fr':
        return AppLanguage.fr;
      case 'tr':
        return AppLanguage.tr;
      case 'en':
      default:
        return AppLanguage.en;
    }
  }

  static AppLanguage fromLocale(Locale locale) => fromCode(locale.languageCode);
}

enum SpreadType { one, three, five }

extension SpreadTypeX on SpreadType {
  String get storageValue {
    return switch (this) {
      SpreadType.one => 'one',
      SpreadType.three => 'three',
      SpreadType.five => 'five',
    };
  }

  int get cardCount {
    return switch (this) {
      SpreadType.one => 1,
      SpreadType.three => 3,
      SpreadType.five => 5,
    };
  }

  static SpreadType fromStorage(String? value) {
    if (value == 'five') {
      return SpreadType.five;
    }
    if (value == 'three') {
      return SpreadType.three;
    }
    return SpreadType.one;
  }
}
