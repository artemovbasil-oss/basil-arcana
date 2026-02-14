// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'The real magic';

  @override
  String get historyTooltip => 'История';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsPromoTitle => 'Промокод';

  @override
  String get settingsPromoDescription =>
      'Введи промокод, чтобы открыть безлимитную энергию на 1 год.';

  @override
  String get settingsPromoHint => 'Введи промокод';

  @override
  String get settingsPromoApplyButton => 'Активировать промокод';

  @override
  String get settingsPromoInvalid => 'Промокод не найден.';

  @override
  String get settingsPromoApplied =>
      'Промокод активирован: безлимит на 1 год включен.';

  @override
  String get settingsPromoResetButton => 'Отказаться от промокода';

  @override
  String get settingsPromoResetDone =>
      'Промокод отключен. Возвращаемся к бесплатной версии.';

  @override
  String get settingsDashboardTitle => 'Профиль и показатели';

  @override
  String get settingsDashboardTopCardsTitle => 'Топ карт по частоте';

  @override
  String get settingsDashboardTopCardsEmpty => 'Пока нет статистики по картам.';

  @override
  String get settingsDashboardServicesTitle => 'Платные сервисы';

  @override
  String get settingsDashboardServicesEmpty => 'Активных платных сервисов нет.';

  @override
  String get settingsDashboardServiceUnlimitedNoDate =>
      'Безлимитная энергия активна.';

  @override
  String settingsDashboardServiceUnlimitedWithDate(Object date) {
    return 'Безлимитная энергия активна до $date.';
  }

  @override
  String settingsDashboardEnergy(Object value) {
    return 'Энергия сейчас: $value';
  }

  @override
  String settingsDashboardFreePremium(int count) {
    return 'Бесплатные бонусы (5 карт / совместимость / натальная карта): $count';
  }

  @override
  String settingsDashboardFreePremiumRemaining(int count) {
    return 'Осталось бесплатных бонусов: $count';
  }

  @override
  String settingsDashboardInvited(int count) {
    return 'Приглашено пользователей: $count';
  }

  @override
  String get settingsDashboardShareButton => 'Поделиться персональной ссылкой';

  @override
  String get settingsDashboardLoadError =>
      'Не удалось загрузить данные дашборда.';

  @override
  String get languageLabel => 'Язык';

  @override
  String get languageEnglish => 'English (EN)';

  @override
  String get languageRussian => 'Русский (RU)';

  @override
  String get languageKazakh => 'Қазақша (KZ)';

  @override
  String get deckLabel => 'Колода';

  @override
  String get deckAll => 'Все колоды';

  @override
  String get deckMajor => 'Старшие арканы';

  @override
  String get deckWands => 'Жезлы';

  @override
  String get deckCups => 'Кубки';

  @override
  String get deckSwords => 'Мечи';

  @override
  String get deckPentacles => 'Пентакли';

  @override
  String get deckTarotRiderWaite => 'Таро Райдера — Уэйта';

  @override
  String get deckLenormand => 'Колода Ленорман';

  @override
  String get deckAllName => 'Все колоды';

  @override
  String get deckMajorName => 'Старшие арканы';

  @override
  String get deckWandsName => 'Жезлы';

  @override
  String get deckCupsName => 'Кубки';

  @override
  String get deckSwordsName => 'Мечи';

  @override
  String get deckPentaclesName => 'Пентакли';

  @override
  String get deckLenormandName => 'Ленорман';

  @override
  String get deckDebugLogLabel => 'Debug: вывести путь для Жезлов';

  @override
  String get homeTagline => 'Ясность в картах.';

  @override
  String get homeSubtitle =>
      'Задайте вопрос и исследуйте нити, которые определяют ваш следующий шаг';

  @override
  String get homeDescription => 'Поймай магический вайб';

  @override
  String get homeQuestionPlaceholder => 'Напишите свой вопрос…';

  @override
  String get homeQuestionLabel => 'Какой у вас вопрос?';

  @override
  String get homeQuestionHint => 'Напишите, в чем нужна ясность';

  @override
  String get homeClearQuestionTooltip => 'Очистить вопрос';

  @override
  String get homeTryPrompt => 'Попробуй один из этих запросов:';

  @override
  String get homeRecentQueriesButton => '🕘 Прошлые запросы';

  @override
  String get homeExample1 => 'Куда направить свою энергию?';

  @override
  String get homeExample2 => 'Какой урок здесь скрыт?';

  @override
  String get homeExample3 => 'Где мне стоит проявить терпение?';

  @override
  String get homeQuickTopicRelationships => 'Отношения';

  @override
  String get homeQuickTopicMoney => 'Деньги';

  @override
  String get homeQuickTopicFuture => 'Будущее';

  @override
  String get homeQuickTopicGrowth => 'Точка роста';

  @override
  String get homeQuickTopicWeatherTomorrow => 'Погода на завтра';

  @override
  String get homeContinueButton => 'Перейти к раскладу';

  @override
  String get homeAllCardsButton => 'Все карты';

  @override
  String get homeAllCardsDescription => 'Прикоснись к магии карт';

  @override
  String get cardsTitle => 'Все карты';

  @override
  String get cardsEmptyTitle => 'Карты пока недоступны';

  @override
  String get cardsEmptySubtitle => 'Попробуйте снова чуть позже.';

  @override
  String get cardsLoadError => 'Данные карт отсутствуют или повреждены.';

  @override
  String get dataLoadTitle => 'Не удаётся подключиться к библиотеке карт.';

  @override
  String get dataLoadRetry => 'Повторить';

  @override
  String get dataLoadUseCache => 'Использовать кэш';

  @override
  String get dataLoadSpreadsError => 'Не удалось загрузить расклады.';

  @override
  String get cardsDetailTitle => 'Детали карты';

  @override
  String get cardKeywordsTitle => 'Ключевые слова';

  @override
  String get cardGeneralTitle => 'Общее значение';

  @override
  String get cardDetailedTitle => 'Подробное описание';

  @override
  String get cardFunFactTitle => 'Интересный факт';

  @override
  String get cardStatsTitle => 'Показатели';

  @override
  String get cardDetailsFallback => 'Нет подробностей.';

  @override
  String get statLuck => 'Удача';

  @override
  String get statPower => 'Сила';

  @override
  String get statLove => 'Любовь';

  @override
  String get statClarity => 'Ясность';

  @override
  String get cardsDetailKeywordsTitle => 'Ключевые слова';

  @override
  String get cardsDetailMeaningTitle => 'Общее значение';

  @override
  String get cardsDetailDescriptionTitle => 'Подробное описание';

  @override
  String get cardsDetailFunFactTitle => 'Интересный факт';

  @override
  String get cardsDetailStatsTitle => 'Показатели';

  @override
  String get cardsDetailStatLuck => 'Удача';

  @override
  String get cardsDetailStatPower => 'Сила';

  @override
  String get cardsDetailStatLove => 'Любовь';

  @override
  String get cardsDetailStatClarity => 'Ясность';

  @override
  String get videoTapToPlay => 'Нажмите, чтобы воспроизвести';

  @override
  String get cdnHealthTitle => 'CDN состояние';

  @override
  String get cdnHealthAssetsBaseLabel => 'База ассетов';

  @override
  String get cdnHealthLocaleLabel => 'Язык';

  @override
  String get cdnHealthCardsFileLabel => 'Карты JSON';

  @override
  String get cdnHealthSpreadsFileLabel => 'Расклады JSON';

  @override
  String get cdnHealthVideoIndexLabel => 'Индекс видео';

  @override
  String get cdnHealthLastFetchLabel => 'Последняя загрузка';

  @override
  String get cdnHealthLastCacheLabel => 'Последний кэш';

  @override
  String get cdnHealthTestFetch => 'Проверить загрузку карт/раскладов';

  @override
  String get cdnHealthStatusIdle => 'Ожидание';

  @override
  String get cdnHealthStatusSuccess => 'Успешно';

  @override
  String get cdnHealthStatusFailed => 'Ошибка';

  @override
  String get spreadTitle => 'Выберите расклад';

  @override
  String get spreadOneCardTitle => 'Одна карта';

  @override
  String get spreadOneCardSubtitle =>
      'Быстрый фокус: одна карта, один ясный ответ.';

  @override
  String get spreadThreeCardTitle => 'Три карты';

  @override
  String get spreadThreeCardSubtitle =>
      'Короткая дуга: контекст, суть и направление.';

  @override
  String get spreadFiveCardTitle => 'Пять карт';

  @override
  String get spreadFiveCardSubtitle =>
      'Глубокий разбор: причины, контекст и рекомендации.';

  @override
  String get spreadLenormandOneCardSubtitle =>
      'Практичный сигнал на сейчас. Одна карта — один ясный индикатор.';

  @override
  String get spreadLenormandThreeCardSubtitle =>
      'Линия причины и исхода. Три карты — импульс, развитие, ближайший результат.';

  @override
  String get spreadLenormandFiveCardSubtitle =>
      'Живая цепочка событий. Пять карт — каждая следующая уточняет предыдущую.';

  @override
  String get spreadFivePosition1 => 'Суть ситуации';

  @override
  String get spreadFivePosition2 => 'Что помогает';

  @override
  String get spreadFivePosition3 => 'Что мешает';

  @override
  String get spreadFivePosition4 => 'Скрытый фактор';

  @override
  String get spreadFivePosition5 => 'Итог и совет';

  @override
  String get spreadLabelPast => 'Прошлое';

  @override
  String get spreadLabelPresent => 'Настоящее';

  @override
  String get spreadLabelFuture => 'Будущее';

  @override
  String spreadCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карты',
      many: '$count карт',
      few: '$count карты',
      one: '1 карта',
    );
    return '$_temp0';
  }

  @override
  String spreadLoadError(Object error) {
    return 'Ошибка: $error';
  }

  @override
  String get shuffleTitle => 'Перетасуйте колоду';

  @override
  String get shuffleSubtitle => 'Перетасовываем колоду';

  @override
  String get shuffleReadingSubtitle => 'Читаем расклад';

  @override
  String get shuffleDrawButton => 'Вытянуть карты';

  @override
  String get resultTitle => 'Ваш расклад';

  @override
  String get resultStatusAiReading => 'Базилик толкует…';

  @override
  String get resultRequestIdUnavailable => 'Идентификатор запроса недоступен';

  @override
  String resultRequestIdLabel(Object id) {
    return 'ID запроса: $id';
  }

  @override
  String get resultSnackSaved => 'Расклад сохранен.';

  @override
  String get resultSectionArcaneSnapshot => 'Арканический снимок';

  @override
  String get resultSectionWhy => 'Почему этот расклад';

  @override
  String get resultSectionAction => 'Шаг действия (следующие 24–72 ч)';

  @override
  String resultLenormandStep(int step, int total) {
    return 'Ленорман: шаг $step из $total';
  }

  @override
  String get resultLenormandBuildsOn => 'Опирается на';

  @override
  String get resultReferralTitle => 'Бонус за рекомендацию';

  @override
  String get resultReferralBody =>
      'Поделись персональной ссылкой с друзьями и получай 20 бесплатных премиум-раскладов на 5 карт, 20 тестов на совместимость и 20 натальных карт за каждого нового пользователя, который перейдет по ссылке.';

  @override
  String get resultReferralButton => 'Поделиться ссылкой';

  @override
  String get resultReferralCopied =>
      'Реферальная ссылка скопирована. Отправь ее в Telegram.';

  @override
  String get resultReferralShareMessage =>
      'Загляни в Basil Arcana: красивые и точные расклады Таро прямо в Telegram.';

  @override
  String get resultDeepPrompt => 'Хочешь детали про отношения и карьеру?';

  @override
  String get resultDeepNotNow => 'Не сейчас';

  @override
  String get resultDeepShowDetails => 'Да';

  @override
  String get resultDeepRetryMessage =>
      'Глубокое чтение ускользнуло. Попробовать ещё раз?';

  @override
  String get resultDeepCancel => 'Отмена';

  @override
  String get resultDeepTryAgain => 'Повторить';

  @override
  String get resultDeepTypingLabel => 'Оракул печатает…';

  @override
  String get resultDeepRelationshipsHeading => 'Отношения';

  @override
  String get resultDeepCareerHeading => 'Карьера';

  @override
  String cardsDrawnCount(int count) {
    return 'Выпадала $count×';
  }

  @override
  String get resultDetailsTitle => 'Детали';

  @override
  String get resultSaveButton => 'Сохранить расклад';

  @override
  String get resultNewButton => 'Новый расклад';

  @override
  String get resultWantMoreButton => 'Хочу больше';

  @override
  String get resultStatusUnauthorized =>
      'Сервис недоступен — попробуйте снова чуть позже.';

  @override
  String get resultStatusNoInternet =>
      'Нет интернета — показываем офлайн-расклад';

  @override
  String get resultStatusTimeout =>
      'Оракул на паузе — нажмите, чтобы повторить.';

  @override
  String get resultStatusTooManyAttempts =>
      'Слишком много попыток — подождите и попробуйте снова.';

  @override
  String resultStatusServerUnavailableWithStatus(int status) {
    return 'Оракул недоступен ($status) — попробуйте снова чуть позже.';
  }

  @override
  String get resultStatusServerUnavailable =>
      'Оракул недоступен — попробуйте снова чуть позже.';

  @override
  String get resultStatusMissingApiBaseUrl =>
      'Ошибка конфигурации — отсутствует базовый URL API.';

  @override
  String get resultStatusUnexpectedResponse =>
      'Неожиданный ответ — нажмите, чтобы повторить.';

  @override
  String get resultStatusInterpretationUnavailable =>
      'Интерпретация ИИ недоступна — нажмите, чтобы повторить.';

  @override
  String get oracleWaitingTitle => 'Оракул слушает…';

  @override
  String get oracleWaitingSubtitle =>
      'Сохраняйте тишину, пока карты складываются в ясность.';

  @override
  String get oracleTimeoutTitle => 'Оракул молчит…';

  @override
  String get oracleTimeoutBody => 'Иногда ясности нужен ещё один вдох.';

  @override
  String get actionCancel => 'Отмена';

  @override
  String get actionTryAgain => 'Попробовать снова';

  @override
  String get actionApply => 'Применить';

  @override
  String get historyTitle => 'История раскладов';

  @override
  String get historyEmpty => 'История пока пуста.';

  @override
  String get historyClearButton => 'Очистить историю';

  @override
  String get historyDetailTitle => 'Детали расклада';

  @override
  String get historyTldrTitle => 'TL;DR';

  @override
  String get queryHistoryTitle => 'Прошлые запросы';

  @override
  String get queryHistoryEmpty => 'Пока нет прошлых запросов.';

  @override
  String get queryHistoryLoadError => 'Не удалось загрузить историю запросов.';

  @override
  String get queryHistoryRetry => 'Повторить';

  @override
  String get offlineFallbackReflection => 'размышление';

  @override
  String offlineFallbackSummary(Object question, Object keywords) {
    return 'Для «$question» чтение сосредоточено на $keywords.';
  }

  @override
  String offlineFallbackAdviceLabel(Object advice) {
    return 'Совет: $advice';
  }

  @override
  String get offlineFallbackWhy =>
      'Каждая позиция отражает грань вашего вопроса, а темы карт указывают, куда стоит направить внимание сейчас.';

  @override
  String get offlineFallbackAction =>
      'Выберите один небольшой практичный шаг, который следует советам карт.';

  @override
  String get moreFeaturesTitle => 'Больше возможностей';

  @override
  String get natalChartTitle => 'Натальная карта';

  @override
  String get natalChartDescription =>
      'Персональный астрологический разбор по дате рождения.';

  @override
  String get natalChartFreeLabel => 'Бесплатно';

  @override
  String get natalChartButton => 'Хочу';

  @override
  String get natalChartBirthDateLabel => 'Дата рождения';

  @override
  String get natalChartBirthDateHint => 'ГГГГ-ММ-ДД';

  @override
  String get natalChartBirthDateError => 'Укажите дату рождения.';

  @override
  String get natalChartBirthTimeLabel => 'Время рождения';

  @override
  String get natalChartBirthTimeHint => 'ЧЧ:ММ';

  @override
  String get natalChartBirthTimeHelper =>
      'Если точное время неизвестно, укажите 12:00 (полдень).';

  @override
  String get natalChartGenerateButton => 'Сгенерировать';

  @override
  String get natalChartLoading => 'Создаем натальную карту…';

  @override
  String get natalChartResultTitle => 'Ваш разбор';

  @override
  String get natalChartError =>
      'Не удалось создать натальную карту. Попробуйте еще раз.';

  @override
  String energyLabelWithPercent(int value) {
    return 'Энергия оракула: $value%';
  }

  @override
  String get energyLabel => 'Энергия оракула';

  @override
  String get energyInfoTooltip =>
      'Энергия тратится на действия и восстанавливается со временем';

  @override
  String get energyRecoveryReady => 'Энергия полностью восстановлена.';

  @override
  String get energyRecoveryLessThanMinute =>
      'До полного восстановления меньше минуты.';

  @override
  String energyRecoveryInMinutes(int minutes) {
    return 'До 100%: $minutes мин.';
  }

  @override
  String energyActionCost(int value) {
    return 'Стоимость действия: $value%';
  }

  @override
  String get energyTopUpButton => 'Пополнить';

  @override
  String get energyTopUpTitle => 'Подпитай магию';

  @override
  String get energyTopUpDescription =>
      'Твоя энергия ведет расклад глубже. Выбери ритм и продолжай без пауз.';

  @override
  String get energyTopUpDescriptionCompact =>
      'Энергия тратится на действия и мягко восстанавливается сама. Можно подождать или усилить поток звездами.';

  @override
  String get energyCostsTitle => 'Сколько стоит каждое действие';

  @override
  String get energyCostReading => 'Расклад';

  @override
  String get energyCostDeepDetails => 'Углубление по раскладу';

  @override
  String get energyCostNatalChart => 'Натальная карта';

  @override
  String get energyNextFreeReady => 'Следующая бесплатная попытка уже готова.';

  @override
  String energyNextFreeIn(String value) {
    return 'До следующей бесплатной попытки: $value';
  }

  @override
  String get energyPackSmall => 'Купить +25% энергии';

  @override
  String get energyPackMedium => 'Купить +50% энергии';

  @override
  String get energyPackFull => 'Купить полный заряд';

  @override
  String get energyPackYearUnlimited => 'Бесконечная энергия на 1 год — 1000 ⭐';

  @override
  String energyTopUpSuccess(int value) {
    return 'Энергия пополнена на $value%.';
  }

  @override
  String get energyUnlimitedActivated =>
      'Бесконечная энергия активирована на 1 год.';

  @override
  String get energyTopUpProcessing => 'Открываем оплату...';

  @override
  String get energyTopUpOnlyInTelegram =>
      'Пополнение звездами доступно только внутри Telegram.';

  @override
  String get energyTopUpPaymentCancelled => 'Оплата отменена.';

  @override
  String get energyTopUpPaymentPending => 'Платеж ожидает подтверждения.';

  @override
  String get energyTopUpPaymentFailed => 'Оплата не прошла. Попробуйте снова.';

  @override
  String get energyTopUpServiceUnavailable => 'Оплата временно недоступна.';

  @override
  String energyInsufficientForAction(int value) {
    return 'Недостаточно энергии для действия ($value%).';
  }

  @override
  String get professionalReadingTitle => 'Профессиональное толкование';

  @override
  String get professionalReadingDescription =>
      'Глубокий разбор расклада с помощью оракула.';

  @override
  String get professionalReadingButton => 'Выбрать тариф';

  @override
  String get professionalReadingOpenBotMessage =>
      'Открой бота, чтобы увидеть тарифы подписки.';

  @override
  String get professionalReadingOpenBotAction => 'Открыть бота';

  @override
  String get professionalReadingOpenBotSnackbar =>
      'Открой бота, чтобы выбрать тариф.';
}
