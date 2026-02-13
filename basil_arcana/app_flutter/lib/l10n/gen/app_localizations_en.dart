// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'The real magic';

  @override
  String get historyTooltip => 'History';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsPromoTitle => 'Promo code';

  @override
  String get settingsPromoDescription =>
      'Enter a promo code to unlock unlimited energy for 1 year.';

  @override
  String get settingsPromoHint => 'Enter promo code';

  @override
  String get settingsPromoApplyButton => 'Activate promo code';

  @override
  String get settingsPromoInvalid => 'Promo code is invalid.';

  @override
  String get settingsPromoApplied =>
      'Promo activated: 1-year unlimited access enabled.';

  @override
  String get settingsPromoResetButton => 'Disable promo code';

  @override
  String get settingsPromoResetDone => 'Promo disabled. Back to free version.';

  @override
  String get settingsDashboardTitle => 'Your profile dashboard';

  @override
  String get settingsDashboardTopCardsTitle => 'Top cards by frequency';

  @override
  String get settingsDashboardTopCardsEmpty => 'No card stats yet.';

  @override
  String get settingsDashboardServicesTitle => 'Paid services';

  @override
  String get settingsDashboardServicesEmpty => 'No active paid services.';

  @override
  String get settingsDashboardServiceUnlimitedNoDate =>
      'Unlimited energy plan is active.';

  @override
  String settingsDashboardServiceUnlimitedWithDate(Object date) {
    return 'Unlimited energy plan is active until $date.';
  }

  @override
  String settingsDashboardEnergy(Object value) {
    return 'Current energy: $value';
  }

  @override
  String settingsDashboardFreePremium(int count) {
    return 'Free premium five-card readings: $count';
  }

  @override
  String settingsDashboardFreePremiumRemaining(int count) {
    return 'Free premium readings left: $count';
  }

  @override
  String settingsDashboardInvited(int count) {
    return 'Invited users: $count';
  }

  @override
  String get settingsDashboardShareButton => 'Share personal referral link';

  @override
  String get settingsDashboardLoadError =>
      'Could not load dashboard data right now.';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageEnglish => 'English (EN)';

  @override
  String get languageRussian => 'Russian (RU)';

  @override
  String get languageKazakh => 'Kazakh (KZ)';

  @override
  String get deckLabel => 'Deck';

  @override
  String get deckAll => 'All decks';

  @override
  String get deckMajor => 'Major Arcana';

  @override
  String get deckWands => 'Wands';

  @override
  String get deckCups => 'Cups';

  @override
  String get deckSwords => 'Swords';

  @override
  String get deckPentacles => 'Pentacles';

  @override
  String get deckTarotRiderWaite => 'Rider-Waite Tarot';

  @override
  String get deckLenormand => 'Lenormand deck';

  @override
  String get deckAllName => 'All decks';

  @override
  String get deckMajorName => 'Major Arcana';

  @override
  String get deckWandsName => 'Wands';

  @override
  String get deckCupsName => 'Cups';

  @override
  String get deckSwordsName => 'Swords';

  @override
  String get deckPentaclesName => 'Pentacles';

  @override
  String get deckLenormandName => 'Lenormand';

  @override
  String get deckDebugLogLabel => 'Debug: log Wands asset path';

  @override
  String get homeTagline => 'Clarity, in cards.';

  @override
  String get homeSubtitle =>
      'Ask a question and explore the threads that shape your next step';

  @override
  String get homeDescription => 'Catch the magic vibe';

  @override
  String get homeQuestionPlaceholder => 'Type your question here…';

  @override
  String get homeQuestionLabel => 'What\'s your question?';

  @override
  String get homeQuestionHint => 'Type what you want clarity on';

  @override
  String get homeClearQuestionTooltip => 'Clear question';

  @override
  String get homeTryPrompt => 'Try one of these prompts:';

  @override
  String get homeRecentQueriesButton => '🕘 Recent prompts';

  @override
  String get homeExample1 => 'Where should I place my energy?';

  @override
  String get homeExample2 => 'What is the hidden lesson here?';

  @override
  String get homeExample3 => 'What needs patience from me?';

  @override
  String get homeQuickTopicRelationships => 'Relationships';

  @override
  String get homeQuickTopicMoney => 'Money';

  @override
  String get homeQuickTopicFuture => 'Future';

  @override
  String get homeQuickTopicGrowth => 'Growth point';

  @override
  String get homeQuickTopicWeatherTomorrow => 'Tomorrow\'s weather';

  @override
  String get homeContinueButton => 'Continue to your spread';

  @override
  String get homeAllCardsButton => 'All cards';

  @override
  String get homeAllCardsDescription => 'Touch the magic of the cards';

  @override
  String get cardsTitle => 'All cards';

  @override
  String get cardsEmptyTitle => 'No cards to show yet';

  @override
  String get cardsEmptySubtitle => 'Please try again in a moment.';

  @override
  String get cardsLoadError => 'Cards data missing or invalid.';

  @override
  String get dataLoadTitle => 'Unable to reach the card library.';

  @override
  String get dataLoadRetry => 'Retry';

  @override
  String get dataLoadUseCache => 'Use cached data';

  @override
  String get dataLoadSpreadsError => 'Unable to load spreads right now.';

  @override
  String get cardsDetailTitle => 'Card details';

  @override
  String get cardKeywordsTitle => 'Keywords';

  @override
  String get cardGeneralTitle => 'General meaning';

  @override
  String get cardDetailedTitle => 'Detailed description';

  @override
  String get cardFunFactTitle => 'Fun fact';

  @override
  String get cardStatsTitle => 'Stats';

  @override
  String get cardDetailsFallback => 'Details unavailable.';

  @override
  String get statLuck => 'Luck';

  @override
  String get statPower => 'Power';

  @override
  String get statLove => 'Love';

  @override
  String get statClarity => 'Clarity';

  @override
  String get cardsDetailKeywordsTitle => 'Keywords';

  @override
  String get cardsDetailMeaningTitle => 'General meaning';

  @override
  String get cardsDetailDescriptionTitle => 'Detailed description';

  @override
  String get cardsDetailFunFactTitle => 'Fun fact';

  @override
  String get cardsDetailStatsTitle => 'Stats';

  @override
  String get cardsDetailStatLuck => 'Luck';

  @override
  String get cardsDetailStatPower => 'Power';

  @override
  String get cardsDetailStatLove => 'Love';

  @override
  String get cardsDetailStatClarity => 'Clarity';

  @override
  String get videoTapToPlay => 'Tap to play';

  @override
  String get cdnHealthTitle => 'CDN health';

  @override
  String get cdnHealthAssetsBaseLabel => 'Assets base URL';

  @override
  String get cdnHealthLocaleLabel => 'Locale';

  @override
  String get cdnHealthCardsFileLabel => 'Cards JSON';

  @override
  String get cdnHealthSpreadsFileLabel => 'Spreads JSON';

  @override
  String get cdnHealthVideoIndexLabel => 'Video index';

  @override
  String get cdnHealthLastFetchLabel => 'Last fetch';

  @override
  String get cdnHealthLastCacheLabel => 'Last cache hit';

  @override
  String get cdnHealthTestFetch => 'Test fetch cards/spreads';

  @override
  String get cdnHealthStatusIdle => 'Idle';

  @override
  String get cdnHealthStatusSuccess => 'Fetch succeeded';

  @override
  String get cdnHealthStatusFailed => 'Fetch failed';

  @override
  String get spreadTitle => 'Choose a spread';

  @override
  String get spreadOneCardTitle => 'One card';

  @override
  String get spreadOneCardSubtitle =>
      'A quick mirror for the moment. One card — one clear focus.';

  @override
  String get spreadThreeCardTitle => 'Three cards';

  @override
  String get spreadThreeCardSubtitle =>
      'A simple arc of your story. Three cards — context and direction.';

  @override
  String get spreadFiveCardTitle => 'Five cards';

  @override
  String get spreadFiveCardSubtitle =>
      'A deeper look at your path. Five cards — layered context and guidance.';

  @override
  String get spreadLenormandOneCardSubtitle =>
      'A practical signal for right now. One card — one clear indicator.';

  @override
  String get spreadLenormandThreeCardSubtitle =>
      'A cause-to-outcome line. Three cards — trigger, development, nearest result.';

  @override
  String get spreadLenormandFiveCardSubtitle =>
      'A living chain of events. Five cards — each next symbol refines the previous one.';

  @override
  String get spreadFivePosition1 => 'Core energy';

  @override
  String get spreadFivePosition2 => 'What helps';

  @override
  String get spreadFivePosition3 => 'What blocks';

  @override
  String get spreadFivePosition4 => 'Hidden factor';

  @override
  String get spreadFivePosition5 => 'Outcome and advice';

  @override
  String get spreadLabelPast => 'Past';

  @override
  String get spreadLabelPresent => 'Present';

  @override
  String get spreadLabelFuture => 'Future';

  @override
  String spreadCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cards',
      one: '1 card',
    );
    return '$_temp0';
  }

  @override
  String spreadLoadError(Object error) {
    return 'Error: $error';
  }

  @override
  String get shuffleTitle => 'Shuffle the deck';

  @override
  String get shuffleSubtitle => 'Shuffling the deck';

  @override
  String get shuffleReadingSubtitle => 'Reading your spread';

  @override
  String get shuffleDrawButton => 'Draw cards';

  @override
  String get resultTitle => 'Your reading';

  @override
  String get resultStatusAiReading => 'Basil is interpreting…';

  @override
  String get resultRequestIdUnavailable => 'Request ID unavailable';

  @override
  String resultRequestIdLabel(Object id) {
    return 'Request ID: $id';
  }

  @override
  String get resultSnackSaved => 'Reading saved.';

  @override
  String get resultSectionArcaneSnapshot => 'Arcane Snapshot';

  @override
  String get resultSectionWhy => 'Why this reading';

  @override
  String get resultSectionAction => 'Action step (next 24–72h)';

  @override
  String resultLenormandStep(int step, int total) {
    return 'Lenormand step $step of $total';
  }

  @override
  String get resultLenormandBuildsOn => 'Builds on';

  @override
  String get resultReferralTitle => 'Referral bonus';

  @override
  String get resultReferralBody =>
      'Share your personal link with friends and get 20 free premium five-card readings for every new user who joins from your link.';

  @override
  String get resultReferralButton => 'Share link';

  @override
  String get resultReferralCopied =>
      'Referral link copied. Send it in Telegram.';

  @override
  String get resultReferralShareMessage =>
      'Try Basil Arcana: stylish and accurate Tarot readings right in Telegram.';

  @override
  String get resultDeepPrompt => 'Want details on relationships and career?';

  @override
  String get resultDeepNotNow => 'Not now';

  @override
  String get resultDeepShowDetails => 'Yes';

  @override
  String get resultDeepRetryMessage =>
      'The deeper reading slipped away. Want to try again?';

  @override
  String get resultDeepCancel => 'Cancel';

  @override
  String get resultDeepTryAgain => 'Try again';

  @override
  String get resultDeepTypingLabel => 'Oracle is typing…';

  @override
  String get resultDeepRelationshipsHeading => 'Relationships';

  @override
  String get resultDeepCareerHeading => 'Career';

  @override
  String cardsDrawnCount(int count) {
    return 'Drawn $count×';
  }

  @override
  String get resultDetailsTitle => 'Details';

  @override
  String get resultSaveButton => 'Save reading';

  @override
  String get resultNewButton => 'New reading';

  @override
  String get resultWantMoreButton => 'Want more';

  @override
  String get resultStatusUnauthorized =>
      'Service unavailable — try again in a moment.';

  @override
  String get resultStatusNoInternet => 'No internet — showing offline reading';

  @override
  String get resultStatusTimeout => 'The oracle paused — tap to retry.';

  @override
  String get resultStatusTooManyAttempts =>
      'Too many attempts — please wait and try again.';

  @override
  String resultStatusServerUnavailableWithStatus(int status) {
    return 'Oracle unavailable ($status) — try again in a moment.';
  }

  @override
  String get resultStatusServerUnavailable =>
      'Oracle unavailable — try again in a moment.';

  @override
  String get resultStatusMissingApiBaseUrl =>
      'Configuration error — missing API base URL.';

  @override
  String get resultStatusUnexpectedResponse =>
      'Unexpected response — tap to retry.';

  @override
  String get resultStatusInterpretationUnavailable =>
      'AI interpretation unavailable — tap to retry.';

  @override
  String get oracleWaitingTitle => 'The Oracle is listening…';

  @override
  String get oracleWaitingSubtitle =>
      'Hold steady while the cards settle into focus.';

  @override
  String get oracleTimeoutTitle => 'The Oracle is silent…';

  @override
  String get oracleTimeoutBody => 'Sometimes clarity needs another breath.';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionTryAgain => 'Try again';

  @override
  String get actionApply => 'Apply';

  @override
  String get historyTitle => 'Reading history';

  @override
  String get historyEmpty => 'History is empty for now.';

  @override
  String get historyClearButton => 'Clear history';

  @override
  String get historyDetailTitle => 'Reading detail';

  @override
  String get historyTldrTitle => 'TL;DR';

  @override
  String get queryHistoryTitle => 'Recent prompts';

  @override
  String get queryHistoryEmpty => 'No previous prompts yet.';

  @override
  String get queryHistoryLoadError => 'Could not load prompt history.';

  @override
  String get queryHistoryRetry => 'Retry';

  @override
  String get offlineFallbackReflection => 'reflection';

  @override
  String offlineFallbackSummary(Object question, Object keywords) {
    return 'For “$question”, the reading centers on $keywords.';
  }

  @override
  String offlineFallbackAdviceLabel(Object advice) {
    return 'Advice: $advice';
  }

  @override
  String get offlineFallbackWhy =>
      'Each position reflects a facet of your question, and the card themes align with where attention can be placed now.';

  @override
  String get offlineFallbackAction =>
      'Choose one small, practical step that honors the advice in the cards.';

  @override
  String get moreFeaturesTitle => 'More features';

  @override
  String get natalChartTitle => 'Natal chart';

  @override
  String get natalChartDescription =>
      'Get a personal astrological overview based on your birth data.';

  @override
  String get natalChartFreeLabel => 'Free';

  @override
  String get natalChartButton => 'I want';

  @override
  String get natalChartBirthDateLabel => 'Date of birth';

  @override
  String get natalChartBirthDateHint => 'YYYY-MM-DD';

  @override
  String get natalChartBirthDateError => 'Please enter your birth date.';

  @override
  String get natalChartBirthTimeLabel => 'Time of birth';

  @override
  String get natalChartBirthTimeHint => 'HH:MM';

  @override
  String get natalChartBirthTimeHelper => 'If unsure, use 12:00 (noon).';

  @override
  String get natalChartGenerateButton => 'Generate';

  @override
  String get natalChartLoading => 'Creating your natal chart…';

  @override
  String get natalChartResultTitle => 'Your interpretation';

  @override
  String get natalChartError =>
      'Couldn’t generate the natal chart. Please try again.';

  @override
  String energyLabelWithPercent(int value) {
    return 'Oracle energy: $value%';
  }

  @override
  String get energyLabel => 'Oracle energy';

  @override
  String get energyInfoTooltip =>
      'Energy is spent on actions and restores over time';

  @override
  String get energyRecoveryReady => 'Fully recharged.';

  @override
  String get energyRecoveryLessThanMinute => 'Full in less than a minute.';

  @override
  String energyRecoveryInMinutes(int minutes) {
    return 'Full in $minutes min.';
  }

  @override
  String energyActionCost(int value) {
    return 'Action cost: $value%';
  }

  @override
  String get energyTopUpButton => 'Top up';

  @override
  String get energyTopUpTitle => 'Feed your arcane flow';

  @override
  String get energyTopUpDescription =>
      'Your energy keeps the reading clear and deep. Choose your rhythm and stay in the magic.';

  @override
  String get energyTopUpDescriptionCompact =>
      'Energy is spent on actions and recovers over time. You can wait for free recharge or boost it instantly with Stars.';

  @override
  String get energyCostsTitle => 'Energy cost per action';

  @override
  String get energyCostReading => 'Reading';

  @override
  String get energyCostDeepDetails => 'Deep details';

  @override
  String get energyCostNatalChart => 'Natal chart';

  @override
  String get energyNextFreeReady => 'Your next free attempt is ready.';

  @override
  String energyNextFreeIn(String value) {
    return 'Next free attempt in: $value';
  }

  @override
  String get energyPackSmall => 'Buy +25% energy';

  @override
  String get energyPackMedium => 'Buy +50% energy';

  @override
  String get energyPackFull => 'Buy full energy';

  @override
  String get energyPackYearUnlimited => 'Unlimited energy for 1 year — 1000 ⭐';

  @override
  String energyTopUpSuccess(int value) {
    return 'Energy restored by $value%.';
  }

  @override
  String get energyUnlimitedActivated =>
      'Unlimited energy activated for 1 year.';

  @override
  String get energyTopUpProcessing => 'Opening payment...';

  @override
  String get energyTopUpOnlyInTelegram =>
      'Top up with Telegram Stars is available only inside Telegram.';

  @override
  String get energyTopUpPaymentCancelled => 'Payment was cancelled.';

  @override
  String get energyTopUpPaymentPending => 'Payment is pending confirmation.';

  @override
  String get energyTopUpPaymentFailed => 'Payment failed. Try again.';

  @override
  String get energyTopUpServiceUnavailable =>
      'Payment is temporarily unavailable.';

  @override
  String energyInsufficientForAction(int value) {
    return 'Not enough energy for this action ($value%).';
  }

  @override
  String get professionalReadingTitle => 'Professional reading';

  @override
  String get professionalReadingDescription =>
      'Deep interpretation of your spread by an oracle.';

  @override
  String get professionalReadingButton => 'Choose plan';

  @override
  String get professionalReadingOpenBotMessage =>
      'Open the bot to see subscription plans.';

  @override
  String get professionalReadingOpenBotAction => 'Open bot';

  @override
  String get professionalReadingOpenBotSnackbar => 'Open bot to choose a plan.';
}
