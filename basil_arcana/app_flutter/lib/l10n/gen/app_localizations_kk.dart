// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppLocalizationsKk extends AppLocalizations {
  AppLocalizationsKk([String locale = 'kk']) : super(locale);

  @override
  String get appTitle => 'The real magic';

  @override
  String get historyTooltip => 'Тарих';

  @override
  String get settingsTitle => 'Баптаулар';

  @override
  String get settingsPromoTitle => 'Промокод';

  @override
  String get settingsPromoDescription => 'Іске қосу үшін промокод енгізіңіз.';

  @override
  String get settingsPromoHint => 'Промокод енгіз';

  @override
  String get settingsPromoApplyButton => 'Промокодты қосу';

  @override
  String get settingsPromoInvalid => 'Промокод жарамсыз.';

  @override
  String get settingsPromoApplied => 'Промокод сәтті іске қосылды.';

  @override
  String get settingsPromoResetButton => 'Промокодтан бас тарту';

  @override
  String get settingsPromoResetDone =>
      'Промокод өшірілді. Тегін нұсқаға қайттық.';

  @override
  String get settingsDashboardTitle => 'Профиль және көрсеткіштер';

  @override
  String get settingsDashboardTopCardsTitle =>
      'Түсу жиілігі бойынша топ карталар';

  @override
  String get settingsDashboardTopCardsEmpty => 'Карталар статистикасы әлі жоқ.';

  @override
  String get settingsDashboardServicesTitle => 'Ақылы сервистер';

  @override
  String get settingsDashboardServicesEmpty => 'Белсенді ақылы сервис жоқ.';

  @override
  String get settingsDashboardServiceUnlimitedNoDate =>
      'Шексіз энергия белсенді.';

  @override
  String settingsDashboardServiceUnlimitedWithDate(Object date) {
    return 'Шексіз энергия $date дейін белсенді.';
  }

  @override
  String settingsDashboardEnergy(Object value) {
    return 'Қазіргі энергия: $value';
  }

  @override
  String settingsDashboardFreePremium(int count) {
    return 'Тегін бонустар (5 карта / үйлесімділік / наталдық карта): $count';
  }

  @override
  String settingsDashboardFreePremiumRemaining(int count) {
    return 'Қалған тегін бонустар: $count';
  }

  @override
  String settingsDashboardInvited(int count) {
    return 'Шақырылған пайдаланушылар: $count';
  }

  @override
  String get settingsDashboardShareButton => 'Жеке реферал сілтемені бөлісу';

  @override
  String get settingsDashboardLoadError =>
      'Дашборд деректерін жүктеу мүмкін болмады.';

  @override
  String get languageLabel => 'Тіл';

  @override
  String get languageEnglish => 'English (EN)';

  @override
  String get languageRussian => 'Русский (RU)';

  @override
  String get languageKazakh => 'Қазақша (KZ)';

  @override
  String get deckLabel => 'Топтама';

  @override
  String get deckAll => 'Барлық топтамалар';

  @override
  String get deckMajor => 'Үлкен аркандар';

  @override
  String get deckWands => 'Таяқтар';

  @override
  String get deckCups => 'Тостағандар';

  @override
  String get deckSwords => 'Қылыштар';

  @override
  String get deckPentacles => 'Пентакльдер';

  @override
  String get deckTarotRiderWaite => 'Райдер-Уэйт Таро';

  @override
  String get deckLenormand => 'Ленорман колодасы';

  @override
  String get deckAllName => 'Барлық топтамалар';

  @override
  String get deckMajorName => 'Үлкен аркандар';

  @override
  String get deckWandsName => 'Таяқтар';

  @override
  String get deckCupsName => 'Тостағандар';

  @override
  String get deckSwordsName => 'Қылыштар';

  @override
  String get deckPentaclesName => 'Пентакльдер';

  @override
  String get deckLenormandName => 'Ленорман';

  @override
  String get deckDebugLogLabel => 'Debug: Таяқтар жолын шығару';

  @override
  String get homeTagline => 'Карталардағы айқындық.';

  @override
  String get homeSubtitle =>
      'Сұрақ қойып, келесі қадамыңызды айқындайтын желілерді зерттеңіз';

  @override
  String get homeDescription => 'Сиқыр вайбын ұста';

  @override
  String get homeQuestionPlaceholder => 'Сұрағыңызды жазыңыз…';

  @override
  String get homeQuestionLabel => 'Сұрағыңыз қандай?';

  @override
  String get homeQuestionHint => 'Айқындық керек нәрсені жазыңыз';

  @override
  String get homeClearQuestionTooltip => 'Сұрақты тазарту';

  @override
  String get homeTryPrompt => 'Осы сұрақтардың бірін көріңіз:';

  @override
  String get homeRecentQueriesButton => '🕘 Алдыңғы сұрақтар';

  @override
  String get homeExample1 => 'Энергиямды қайда бағыттаған дұрыс?';

  @override
  String get homeExample2 => 'Мұндағы жасырын сабақ қандай?';

  @override
  String get homeExample3 => 'Қай жерде сабыр керек?';

  @override
  String get homeQuickTopicRelationships => 'Қарым-қатынас';

  @override
  String get homeQuickTopicMoney => 'Ақша';

  @override
  String get homeQuickTopicFuture => 'Болашақ';

  @override
  String get homeQuickTopicGrowth => 'Өсу нүктесі';

  @override
  String get homeQuickTopicWeatherTomorrow => 'Ертеңгі ауа райы';

  @override
  String get homeContinueButton => 'Жаймаға өту';

  @override
  String get homeAllCardsButton => 'Барлық карталар';

  @override
  String get homeAllCardsDescription => 'Карталар сиқырына қол тигіз';

  @override
  String get cardsTitle => 'Барлық карталар';

  @override
  String get cardsEmptyTitle => 'Карталар әзірге жоқ';

  @override
  String get cardsEmptySubtitle => 'Сәл кейінірек қайталап көріңіз.';

  @override
  String get cardsLoadError => 'Карталардың деректері жоқ немесе бүлінген.';

  @override
  String get dataLoadTitle => 'Карталар кітапханасына қосыла алмадық.';

  @override
  String get dataLoadRetry => 'Қайталау';

  @override
  String get dataLoadUseCache => 'Кэшті пайдалану';

  @override
  String get dataLoadSpreadsError => 'Таралымдарды жүктеу мүмкін емес.';

  @override
  String get cardsDetailTitle => 'Карта туралы';

  @override
  String get cardKeywordsTitle => 'Түйін сөздер';

  @override
  String get cardGeneralTitle => 'Жалпы мағына';

  @override
  String get cardDetailedTitle => 'Толық сипаттама';

  @override
  String get cardFunFactTitle => 'Қызықты дерек';

  @override
  String get cardStatsTitle => 'Көрсеткіштер';

  @override
  String get cardDetailsFallback => 'Мәліметтер жоқ.';

  @override
  String get statLuck => 'Сәттілік';

  @override
  String get statPower => 'Күш';

  @override
  String get statLove => 'Махаббат';

  @override
  String get statClarity => 'Айқындық';

  @override
  String get cardsDetailKeywordsTitle => 'Кілт сөздер';

  @override
  String get cardsDetailMeaningTitle => 'Жалпы мағынасы';

  @override
  String get cardsDetailDescriptionTitle => 'Толық сипаттама';

  @override
  String get cardsDetailFunFactTitle => 'Қызықты дерек';

  @override
  String get cardsDetailStatsTitle => 'Көрсеткіштер';

  @override
  String get cardsDetailStatLuck => 'Сәттілік';

  @override
  String get cardsDetailStatPower => 'Күш';

  @override
  String get cardsDetailStatLove => 'Махаббат';

  @override
  String get cardsDetailStatClarity => 'Айқындық';

  @override
  String get videoTapToPlay => 'Ойнату үшін түртіңіз';

  @override
  String get cdnHealthTitle => 'CDN күйі';

  @override
  String get cdnHealthAssetsBaseLabel => 'Ассеттер базасы';

  @override
  String get cdnHealthLocaleLabel => 'Тіл';

  @override
  String get cdnHealthCardsFileLabel => 'Карталар JSON';

  @override
  String get cdnHealthSpreadsFileLabel => 'Таралымдар JSON';

  @override
  String get cdnHealthVideoIndexLabel => 'Видео индексі';

  @override
  String get cdnHealthLastFetchLabel => 'Соңғы жүктеу';

  @override
  String get cdnHealthLastCacheLabel => 'Соңғы кэш';

  @override
  String get cdnHealthTestFetch => 'Карта/таралым жүктеуін тексеру';

  @override
  String get cdnHealthStatusIdle => 'Күту';

  @override
  String get cdnHealthStatusSuccess => 'Сәтті';

  @override
  String get cdnHealthStatusFailed => 'Қате';

  @override
  String get spreadTitle => 'Жайманы таңдаңыз';

  @override
  String get spreadOneCardTitle => 'Бір карта';

  @override
  String get spreadOneCardSubtitle =>
      'Сәтті тез аңғаруға арналған айна. Бір карта — бір айқын фокус.';

  @override
  String get spreadThreeCardTitle => 'Үш карта';

  @override
  String get spreadThreeCardSubtitle =>
      'Оқиғаңның қарапайым доғасы. Үш карта — мәнмәтін мен бағыт.';

  @override
  String get spreadFiveCardTitle => 'Бес карта';

  @override
  String get spreadFiveCardSubtitle =>
      'Жағдайға тереңірек көзқарас. Бес карта — көпқабатты мәнмәтін мен бағыт.';

  @override
  String get spreadLenormandOneCardSubtitle =>
      'Қазірге арналған нақты белгі. Бір карта — бір айқын нұсқау.';

  @override
  String get spreadLenormandThreeCardSubtitle =>
      'Себептен нәтижеге дейінгі желі. Үш карта — түрткі, даму, жақын нәтиже.';

  @override
  String get spreadLenormandFiveCardSubtitle =>
      'Оқиғалардың тірі тізбегі. Бес карта — әр келесісі алдыңғы мағынаны нақтылайды.';

  @override
  String get spreadFivePosition1 => 'Жағдайдың мәні';

  @override
  String get spreadFivePosition2 => 'Не көмектеседі';

  @override
  String get spreadFivePosition3 => 'Не кедергі';

  @override
  String get spreadFivePosition4 => 'Жасырын фактор';

  @override
  String get spreadFivePosition5 => 'Нәтиже және кеңес';

  @override
  String get spreadLabelPast => 'Өткен';

  @override
  String get spreadLabelPresent => 'Қазіргі';

  @override
  String get spreadLabelFuture => 'Болашақ';

  @override
  String spreadCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count карта',
    );
    return '$_temp0';
  }

  @override
  String spreadLoadError(Object error) {
    return 'Қате: $error';
  }

  @override
  String get shuffleTitle => 'Колоданы араластырыңыз';

  @override
  String get shuffleSubtitle => 'Колода араластырылуда';

  @override
  String get shuffleReadingSubtitle => 'Жайманы оқимыз';

  @override
  String get shuffleDrawButton => 'Карталарды тарту';

  @override
  String get resultTitle => 'Сіздің оқылымыңыз';

  @override
  String get resultStatusAiReading => 'Basil түсіндіріп жатыр…';

  @override
  String get resultRequestIdUnavailable => 'Сұрау идентификаторы қолжетімсіз';

  @override
  String resultRequestIdLabel(Object id) {
    return 'Сұрау ID: $id';
  }

  @override
  String get resultSnackSaved => 'Оқылым сақталды.';

  @override
  String get resultSectionArcaneSnapshot => 'Аркандық шолу';

  @override
  String get resultSectionWhy => 'Неге бұл оқылым';

  @override
  String get resultSectionAction => 'Әрекет қадамы (келесі 24–72 сағ)';

  @override
  String resultLenormandStep(int step, int total) {
    return 'Ленорман: $step/$total қадам';
  }

  @override
  String get resultLenormandBuildsOn => 'Осыған сүйенеді';

  @override
  String get resultReferralTitle => 'Ұсыныс бонусы';

  @override
  String get resultReferralBody =>
      'Жеке сілтемеңді достарыңмен бөліс және сілтеме арқылы келген әр жаңа қолданушы үшін 5 карталық 20 тегін премиум жайылма, 20 үйлесімділік тесті және 20 наталдық карта ал.';

  @override
  String get resultReferralButton => 'Сілтемемен бөлісу';

  @override
  String get resultReferralCopied =>
      'Реферал сілтеме көшірілді. Оны Telegram-да жібер.';

  @override
  String get resultReferralShareMessage =>
      'Basil Arcana-ны байқап көр: Telegram ішіндегі әдемі әрі нақты Таро жайылмалары.';

  @override
  String get resultDeepPrompt =>
      'Қарым-қатынас пен мансап туралы толығырақ керек пе?';

  @override
  String get resultDeepNotNow => 'Қазір емес';

  @override
  String get resultDeepShowDetails => 'Иә';

  @override
  String get resultDeepRetryMessage =>
      'Терең оқылым үзіліп қалды. Қайта көреміз бе?';

  @override
  String get resultDeepCancel => 'Болдырмау';

  @override
  String get resultDeepTryAgain => 'Қайта көру';

  @override
  String get resultDeepTypingLabel => 'Оракул жазып жатыр…';

  @override
  String get resultDeepRelationshipsHeading => 'Қарым-қатынас';

  @override
  String get resultDeepCareerHeading => 'Мансап';

  @override
  String cardsDrawnCount(int count) {
    return '$count× түсті';
  }

  @override
  String get resultDetailsTitle => 'Толығырақ';

  @override
  String get resultSaveButton => 'Оқылымды сақтау';

  @override
  String get resultNewButton => 'Жаңа оқылым';

  @override
  String get resultWantMoreButton => 'Көбірек қалаймын';

  @override
  String get resultStatusUnauthorized =>
      'Қызмет қолжетімсіз — сәл кейінірек қайталап көріңіз.';

  @override
  String get resultStatusNoInternet =>
      'Интернет жоқ — офлайн оқылым көрсетіледі';

  @override
  String get resultStatusTimeout =>
      'Оракул кідірді — қайта көру үшін түртіңіз.';

  @override
  String get resultStatusTooManyAttempts =>
      'Тым көп әрекет — біраз күтіп, қайта көріңіз.';

  @override
  String resultStatusServerUnavailableWithStatus(int status) {
    return 'Оракул қолжетімсіз ($status) — сәл кейінірек қайталап көріңіз.';
  }

  @override
  String get resultStatusServerUnavailable =>
      'Оракул қолжетімсіз — сәл кейінірек қайталап көріңіз.';

  @override
  String get resultStatusMissingApiBaseUrl =>
      'Баптау қатесі — API базалық URL жоқ.';

  @override
  String get resultStatusUnexpectedResponse =>
      'Күтілмеген жауап — қайта көру үшін түртіңіз.';

  @override
  String get resultStatusInterpretationUnavailable =>
      'AI түсіндірмесі қолжетімсіз — қайта көру үшін түртіңіз.';

  @override
  String get oracleWaitingTitle => 'Оракул тыңдап тұр…';

  @override
  String get oracleWaitingSubtitle =>
      'Карталар айқындала бастағанша сабыр сақтаңыз.';

  @override
  String get oracleTimeoutTitle => 'Оракул үнсіз…';

  @override
  String get oracleTimeoutBody => 'Кейде айқындыққа тағы бір дем керек.';

  @override
  String get actionCancel => 'Болдырмау';

  @override
  String get actionTryAgain => 'Қайта көру';

  @override
  String get actionApply => 'Қолдану';

  @override
  String get historyTitle => 'Оқылым тарихы';

  @override
  String get historyEmpty => 'Әзірге тарих бос.';

  @override
  String get historyClearButton => 'Тарихты тазалау';

  @override
  String get historyDetailTitle => 'Оқылым мәліметі';

  @override
  String get historyTldrTitle => 'TL;DR';

  @override
  String get queryHistoryTitle => 'Алдыңғы сұрақтар';

  @override
  String get queryHistoryEmpty => 'Әзірге алдыңғы сұрақтар жоқ.';

  @override
  String get queryHistoryLoadError => 'Сұрақтар тарихын жүктеу мүмкін болмады.';

  @override
  String get queryHistoryRetry => 'Қайталау';

  @override
  String get offlineFallbackReflection => 'ойлану';

  @override
  String offlineFallbackSummary(Object question, Object keywords) {
    return '«$question» сұрағы үшін оқылым $keywords төңірегінде өрбиді.';
  }

  @override
  String offlineFallbackAdviceLabel(Object advice) {
    return 'Кеңес: $advice';
  }

  @override
  String get offlineFallbackWhy =>
      'Әр позиция сұрағыңыздың бір қырын көрсетеді, ал карталардың тақырыптары қазір назарды қайда бағыттау керегін айқындайды.';

  @override
  String get offlineFallbackAction =>
      'Карталардың кеңесіне сай бір шағын, практикалық қадам таңдаңыз.';

  @override
  String get moreFeaturesTitle => 'Қосымша мүмкіндіктер';

  @override
  String get natalChartTitle => 'Наталдық карта';

  @override
  String get natalChartDescription =>
      'Туған күніңіз бойынша жеке астрологиялық талдау.';

  @override
  String get natalChartFreeLabel => 'Тегін';

  @override
  String get natalChartButton => 'Қалаймын';

  @override
  String get natalChartBirthDateLabel => 'Туған күні';

  @override
  String get natalChartBirthDateHint => 'ЖЖЖЖ-АА-КК';

  @override
  String get natalChartBirthDateError => 'Туған күніңізді енгізіңіз.';

  @override
  String get natalChartBirthTimeLabel => 'Туған уақыты';

  @override
  String get natalChartBirthTimeHint => 'СС:ММ';

  @override
  String get natalChartBirthTimeHelper =>
      'Дәл уақыт белгісіз болса, 12:00 (түскі) деп көрсетіңіз.';

  @override
  String get natalChartGenerateButton => 'Жасау';

  @override
  String get natalChartLoading => 'Наталдық карта жасалуда…';

  @override
  String get natalChartResultTitle => 'Түсіндірме';

  @override
  String get natalChartError =>
      'Наталдық картаны жасау мүмкін болмады. Қайта көріңіз.';

  @override
  String energyLabelWithPercent(int value) {
    return 'Оракул энергиясы: $value%';
  }

  @override
  String get energyLabel => 'Оракул энергиясы';

  @override
  String get energyInfoTooltip =>
      'Энергия әрекеттерге жұмсалады және уақыт өте қалпына келеді';

  @override
  String get energyRecoveryReady => 'Энергия толық қалпына келді.';

  @override
  String get energyRecoveryLessThanMinute =>
      'Толық қалпына келуге бір минуттан аз қалды.';

  @override
  String energyRecoveryInMinutes(int minutes) {
    return '100%-ға дейін: $minutes мин.';
  }

  @override
  String energyActionCost(int value) {
    return 'Әрекет құны: $value%';
  }

  @override
  String get energyTopUpButton => 'Толықтыру';

  @override
  String get energyTopUpTitle => 'Сиқыр қуатын күшейт';

  @override
  String get energyTopUpDescription =>
      'Энергияң жорамалды терең әрі анық етеді. Ырғағыңды таңда да ағымды жалғастыр.';

  @override
  String get energyTopUpDescriptionCompact =>
      'Энергия әр әрекетке жұмсалады және уақыт өте қалпына келеді. Күте тұр немесе жұлдызбен бірден толықтыр.';

  @override
  String get energyCostsTitle => 'Әрекетке кететін энергия';

  @override
  String get energyCostReading => 'Жорамал';

  @override
  String get energyCostDeepDetails => 'Терең талдау';

  @override
  String get energyCostNatalChart => 'Наталдық карта';

  @override
  String get energyCostCompatibility => 'Махаббат үйлесімділігі';

  @override
  String get energyNextFreeReady => 'Келесі тегін әрекет дайын.';

  @override
  String energyNextFreeIn(String value) {
    return 'Келесі тегін әрекетке дейін: $value';
  }

  @override
  String get energyPackSmall => '+25% энергия сатып алу';

  @override
  String get energyPackMedium => '+50% энергия сатып алу';

  @override
  String get energyPackFull => '100%-ға дейін толықтыру';

  @override
  String get energyPackWeekUnlimited => '1 аптаға шексіз — 99 ⭐';

  @override
  String get energyPackMonthUnlimited => '1 айға шексіз — 499 ⭐';

  @override
  String get energyPackYearUnlimited => '1 жылға шексіз — 9999 ⭐';

  @override
  String energyTopUpSuccess(int value) {
    return 'Энергия $value%-ға толықты.';
  }

  @override
  String get energyUnlimitedActivated => 'Шексіз энергия қосылды.';

  @override
  String get energyTopUpProcessing => 'Төлем ашылып жатыр...';

  @override
  String get energyTopUpOnlyInTelegram =>
      'Жұлдызбен толықтыру тек Telegram ішінде қолжетімді.';

  @override
  String get energyTopUpPaymentCancelled => 'Төлем тоқтатылды.';

  @override
  String get energyTopUpPaymentPending => 'Төлем расталуын күтіп тұр.';

  @override
  String get energyTopUpPaymentFailed =>
      'Төлем сәтсіз аяқталды. Қайталап көріңіз.';

  @override
  String get energyTopUpServiceUnavailable => 'Төлем уақытша қолжетімсіз.';

  @override
  String energyInsufficientForAction(int value) {
    return 'Бұл әрекетке энергия жеткіліксіз ($value%).';
  }

  @override
  String get professionalReadingTitle => 'Кәсіби жорамал';

  @override
  String get professionalReadingDescription => 'Таралымды терең кәсіби талдау.';

  @override
  String get professionalReadingButton => 'Тариф таңдау';

  @override
  String get professionalReadingOpenBotMessage =>
      'Жазылым жоспарларын көру үшін ботты ашыңыз.';

  @override
  String get professionalReadingOpenBotAction => 'Ботты ашу';

  @override
  String get professionalReadingOpenBotSnackbar =>
      'Тарифті таңдау үшін ботты ашыңыз.';
}
