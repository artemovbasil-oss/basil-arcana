import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Basil\'s Arcana'**
  String get appTitle;

  /// No description provided for @historyTooltip.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTooltip;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English (EN)'**
  String get languageEnglish;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian (RU)'**
  String get languageRussian;

  /// No description provided for @languageKazakh.
  ///
  /// In en, this message translates to:
  /// **'Kazakh (KZ)'**
  String get languageKazakh;

  /// No description provided for @deckLabel.
  ///
  /// In en, this message translates to:
  /// **'Deck'**
  String get deckLabel;

  /// No description provided for @deckAll.
  ///
  /// In en, this message translates to:
  /// **'All decks'**
  String get deckAll;

  /// No description provided for @deckMajor.
  ///
  /// In en, this message translates to:
  /// **'Major Arcana'**
  String get deckMajor;

  /// No description provided for @deckWands.
  ///
  /// In en, this message translates to:
  /// **'Wands'**
  String get deckWands;

  /// No description provided for @deckCups.
  ///
  /// In en, this message translates to:
  /// **'Cups'**
  String get deckCups;

  /// No description provided for @deckSwords.
  ///
  /// In en, this message translates to:
  /// **'Swords'**
  String get deckSwords;

  /// No description provided for @deckPentacles.
  ///
  /// In en, this message translates to:
  /// **'Pentacles'**
  String get deckPentacles;

  /// No description provided for @deckAllName.
  ///
  /// In en, this message translates to:
  /// **'All decks'**
  String get deckAllName;

  /// No description provided for @deckMajorName.
  ///
  /// In en, this message translates to:
  /// **'Major Arcana'**
  String get deckMajorName;

  /// No description provided for @deckWandsName.
  ///
  /// In en, this message translates to:
  /// **'Wands'**
  String get deckWandsName;

  /// No description provided for @deckCupsName.
  ///
  /// In en, this message translates to:
  /// **'Cups'**
  String get deckCupsName;

  /// No description provided for @deckSwordsName.
  ///
  /// In en, this message translates to:
  /// **'Swords'**
  String get deckSwordsName;

  /// No description provided for @deckPentaclesName.
  ///
  /// In en, this message translates to:
  /// **'Pentacles'**
  String get deckPentaclesName;

  /// No description provided for @deckDebugLogLabel.
  ///
  /// In en, this message translates to:
  /// **'Debug: log Wands asset path'**
  String get deckDebugLogLabel;

  /// No description provided for @homeTagline.
  ///
  /// In en, this message translates to:
  /// **'Clarity, in cards.'**
  String get homeTagline;

  /// No description provided for @homeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Ask a question and explore the threads that shape your next step'**
  String get homeSubtitle;

  /// No description provided for @homeDescription.
  ///
  /// In en, this message translates to:
  /// **'A quiet space for a single clear question'**
  String get homeDescription;

  /// No description provided for @homeQuestionPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type your question here…'**
  String get homeQuestionPlaceholder;

  /// No description provided for @homeQuestionLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s your question?'**
  String get homeQuestionLabel;

  /// No description provided for @homeQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Type what you want clarity on'**
  String get homeQuestionHint;

  /// No description provided for @homeClearQuestionTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear question'**
  String get homeClearQuestionTooltip;

  /// No description provided for @homeTryPrompt.
  ///
  /// In en, this message translates to:
  /// **'Try one of these prompts:'**
  String get homeTryPrompt;

  /// No description provided for @homeExample1.
  ///
  /// In en, this message translates to:
  /// **'Where should I place my energy?'**
  String get homeExample1;

  /// No description provided for @homeExample2.
  ///
  /// In en, this message translates to:
  /// **'What is the hidden lesson here?'**
  String get homeExample2;

  /// No description provided for @homeExample3.
  ///
  /// In en, this message translates to:
  /// **'What needs patience from me?'**
  String get homeExample3;

  /// No description provided for @homeContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue to your spread'**
  String get homeContinueButton;

  /// No description provided for @homeAllCardsButton.
  ///
  /// In en, this message translates to:
  /// **'All cards'**
  String get homeAllCardsButton;

  /// No description provided for @cardsTitle.
  ///
  /// In en, this message translates to:
  /// **'All cards'**
  String get cardsTitle;

  /// No description provided for @cardsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cards to show yet'**
  String get cardsEmptyTitle;

  /// No description provided for @cardsEmptySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get cardsEmptySubtitle;

  /// No description provided for @cardsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Cards data missing or invalid.'**
  String get cardsLoadError;

  /// No description provided for @dataLoadTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to reach the card library.'**
  String get dataLoadTitle;

  /// No description provided for @dataLoadRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get dataLoadRetry;

  /// No description provided for @dataLoadUseCache.
  ///
  /// In en, this message translates to:
  /// **'Use cached data'**
  String get dataLoadUseCache;

  /// No description provided for @dataLoadSpreadsError.
  ///
  /// In en, this message translates to:
  /// **'Unable to load spreads right now.'**
  String get dataLoadSpreadsError;

  /// No description provided for @cardsDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Card details'**
  String get cardsDetailTitle;

  /// No description provided for @cardKeywordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get cardKeywordsTitle;

  /// No description provided for @cardGeneralTitle.
  ///
  /// In en, this message translates to:
  /// **'General meaning'**
  String get cardGeneralTitle;

  /// No description provided for @cardDetailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed description'**
  String get cardDetailedTitle;

  /// No description provided for @cardFunFactTitle.
  ///
  /// In en, this message translates to:
  /// **'Fun fact'**
  String get cardFunFactTitle;

  /// No description provided for @cardStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get cardStatsTitle;

  /// No description provided for @cardDetailsFallback.
  ///
  /// In en, this message translates to:
  /// **'Details unavailable.'**
  String get cardDetailsFallback;

  /// No description provided for @statLuck.
  ///
  /// In en, this message translates to:
  /// **'Luck'**
  String get statLuck;

  /// No description provided for @statPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get statPower;

  /// No description provided for @statLove.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get statLove;

  /// No description provided for @statClarity.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get statClarity;

  /// No description provided for @cardsDetailKeywordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Keywords'**
  String get cardsDetailKeywordsTitle;

  /// No description provided for @cardsDetailMeaningTitle.
  ///
  /// In en, this message translates to:
  /// **'General meaning'**
  String get cardsDetailMeaningTitle;

  /// No description provided for @cardsDetailDescriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Detailed description'**
  String get cardsDetailDescriptionTitle;

  /// No description provided for @cardsDetailFunFactTitle.
  ///
  /// In en, this message translates to:
  /// **'Fun fact'**
  String get cardsDetailFunFactTitle;

  /// No description provided for @cardsDetailStatsTitle.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get cardsDetailStatsTitle;

  /// No description provided for @cardsDetailStatLuck.
  ///
  /// In en, this message translates to:
  /// **'Luck'**
  String get cardsDetailStatLuck;

  /// No description provided for @cardsDetailStatPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get cardsDetailStatPower;

  /// No description provided for @cardsDetailStatLove.
  ///
  /// In en, this message translates to:
  /// **'Love'**
  String get cardsDetailStatLove;

  /// No description provided for @cardsDetailStatClarity.
  ///
  /// In en, this message translates to:
  /// **'Clarity'**
  String get cardsDetailStatClarity;

  /// No description provided for @videoTapToPlay.
  ///
  /// In en, this message translates to:
  /// **'Tap to play'**
  String get videoTapToPlay;

  /// No description provided for @cdnHealthTitle.
  ///
  /// In en, this message translates to:
  /// **'CDN health'**
  String get cdnHealthTitle;

  /// No description provided for @cdnHealthAssetsBaseLabel.
  ///
  /// In en, this message translates to:
  /// **'Assets base URL'**
  String get cdnHealthAssetsBaseLabel;

  /// No description provided for @cdnHealthLocaleLabel.
  ///
  /// In en, this message translates to:
  /// **'Locale'**
  String get cdnHealthLocaleLabel;

  /// No description provided for @cdnHealthCardsFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Cards JSON'**
  String get cdnHealthCardsFileLabel;

  /// No description provided for @cdnHealthSpreadsFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Spreads JSON'**
  String get cdnHealthSpreadsFileLabel;

  /// No description provided for @cdnHealthVideoIndexLabel.
  ///
  /// In en, this message translates to:
  /// **'Video index'**
  String get cdnHealthVideoIndexLabel;

  /// No description provided for @cdnHealthLastFetchLabel.
  ///
  /// In en, this message translates to:
  /// **'Last fetch'**
  String get cdnHealthLastFetchLabel;

  /// No description provided for @cdnHealthLastCacheLabel.
  ///
  /// In en, this message translates to:
  /// **'Last cache hit'**
  String get cdnHealthLastCacheLabel;

  /// No description provided for @cdnHealthTestFetch.
  ///
  /// In en, this message translates to:
  /// **'Test fetch cards/spreads'**
  String get cdnHealthTestFetch;

  /// No description provided for @cdnHealthStatusIdle.
  ///
  /// In en, this message translates to:
  /// **'Idle'**
  String get cdnHealthStatusIdle;

  /// No description provided for @cdnHealthStatusSuccess.
  ///
  /// In en, this message translates to:
  /// **'Fetch succeeded'**
  String get cdnHealthStatusSuccess;

  /// No description provided for @cdnHealthStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Fetch failed'**
  String get cdnHealthStatusFailed;

  /// No description provided for @spreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a spread'**
  String get spreadTitle;

  /// No description provided for @spreadOneCardTitle.
  ///
  /// In en, this message translates to:
  /// **'One card'**
  String get spreadOneCardTitle;

  /// No description provided for @spreadOneCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A quick mirror for the moment. One card — one clear focus.'**
  String get spreadOneCardSubtitle;

  /// No description provided for @spreadThreeCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Three cards'**
  String get spreadThreeCardTitle;

  /// No description provided for @spreadThreeCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A simple arc of your story. Three cards — context and direction.'**
  String get spreadThreeCardSubtitle;

  /// No description provided for @spreadFiveCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Five cards'**
  String get spreadFiveCardTitle;

  /// No description provided for @spreadFiveCardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A deeper look at your path. Five cards — layered context and guidance.'**
  String get spreadFiveCardSubtitle;

  /// No description provided for @spreadFivePosition1.
  ///
  /// In en, this message translates to:
  /// **'Core energy'**
  String get spreadFivePosition1;

  /// No description provided for @spreadFivePosition2.
  ///
  /// In en, this message translates to:
  /// **'What helps'**
  String get spreadFivePosition2;

  /// No description provided for @spreadFivePosition3.
  ///
  /// In en, this message translates to:
  /// **'What blocks'**
  String get spreadFivePosition3;

  /// No description provided for @spreadFivePosition4.
  ///
  /// In en, this message translates to:
  /// **'Hidden factor'**
  String get spreadFivePosition4;

  /// No description provided for @spreadFivePosition5.
  ///
  /// In en, this message translates to:
  /// **'Outcome and advice'**
  String get spreadFivePosition5;

  /// No description provided for @spreadLabelPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get spreadLabelPast;

  /// No description provided for @spreadLabelPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get spreadLabelPresent;

  /// No description provided for @spreadLabelFuture.
  ///
  /// In en, this message translates to:
  /// **'Future'**
  String get spreadLabelFuture;

  /// No description provided for @spreadCardCount.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, one{1 card} other{{count} cards}}'**
  String spreadCardCount(int count);

  /// No description provided for @spreadLoadError.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String spreadLoadError(Object error);

  /// No description provided for @shuffleTitle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle the deck'**
  String get shuffleTitle;

  /// No description provided for @shuffleSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Shuffling the deck'**
  String get shuffleSubtitle;

  /// No description provided for @shuffleReadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reading your spread'**
  String get shuffleReadingSubtitle;

  /// No description provided for @shuffleDrawButton.
  ///
  /// In en, this message translates to:
  /// **'Draw cards'**
  String get shuffleDrawButton;

  /// No description provided for @resultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your reading'**
  String get resultTitle;

  /// No description provided for @resultStatusAiReading.
  ///
  /// In en, this message translates to:
  /// **'Basil is interpreting…'**
  String get resultStatusAiReading;

  /// No description provided for @resultRequestIdUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Request ID unavailable'**
  String get resultRequestIdUnavailable;

  /// No description provided for @resultRequestIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Request ID: {id}'**
  String resultRequestIdLabel(Object id);

  /// No description provided for @resultSnackSaved.
  ///
  /// In en, this message translates to:
  /// **'Reading saved.'**
  String get resultSnackSaved;

  /// No description provided for @resultSectionArcaneSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Arcane Snapshot'**
  String get resultSectionArcaneSnapshot;

  /// No description provided for @resultSectionWhy.
  ///
  /// In en, this message translates to:
  /// **'Why this reading'**
  String get resultSectionWhy;

  /// No description provided for @resultSectionAction.
  ///
  /// In en, this message translates to:
  /// **'Action step (next 24–72h)'**
  String get resultSectionAction;

  /// No description provided for @resultDeepPrompt.
  ///
  /// In en, this message translates to:
  /// **'Want details on relationships and career?'**
  String get resultDeepPrompt;

  /// No description provided for @resultDeepNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get resultDeepNotNow;

  /// No description provided for @resultDeepShowDetails.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get resultDeepShowDetails;

  /// No description provided for @resultDeepRetryMessage.
  ///
  /// In en, this message translates to:
  /// **'The deeper reading slipped away. Want to try again?'**
  String get resultDeepRetryMessage;

  /// No description provided for @resultDeepCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get resultDeepCancel;

  /// No description provided for @resultDeepTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get resultDeepTryAgain;

  /// No description provided for @resultDeepTypingLabel.
  ///
  /// In en, this message translates to:
  /// **'Oracle is typing…'**
  String get resultDeepTypingLabel;

  /// No description provided for @resultDeepRelationshipsHeading.
  ///
  /// In en, this message translates to:
  /// **'Relationships'**
  String get resultDeepRelationshipsHeading;

  /// No description provided for @resultDeepCareerHeading.
  ///
  /// In en, this message translates to:
  /// **'Career'**
  String get resultDeepCareerHeading;

  /// No description provided for @cardsDrawnCount.
  ///
  /// In en, this message translates to:
  /// **'Drawn {count}×'**
  String cardsDrawnCount(int count);

  /// No description provided for @resultDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get resultDetailsTitle;

  /// No description provided for @resultSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save reading'**
  String get resultSaveButton;

  /// No description provided for @resultNewButton.
  ///
  /// In en, this message translates to:
  /// **'New reading'**
  String get resultNewButton;

  /// No description provided for @resultWantMoreButton.
  ///
  /// In en, this message translates to:
  /// **'Want more'**
  String get resultWantMoreButton;

  /// No description provided for @resultStatusUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Service unavailable — try again in a moment.'**
  String get resultStatusUnauthorized;

  /// No description provided for @resultStatusNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet — showing offline reading'**
  String get resultStatusNoInternet;

  /// No description provided for @resultStatusTimeout.
  ///
  /// In en, this message translates to:
  /// **'The oracle paused — tap to retry.'**
  String get resultStatusTimeout;

  /// No description provided for @resultStatusTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts — please wait and try again.'**
  String get resultStatusTooManyAttempts;

  /// No description provided for @resultStatusServerUnavailableWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Oracle unavailable ({status}) — try again in a moment.'**
  String resultStatusServerUnavailableWithStatus(int status);

  /// No description provided for @resultStatusServerUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Oracle unavailable — try again in a moment.'**
  String get resultStatusServerUnavailable;

  /// No description provided for @resultStatusMissingApiBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Configuration error — missing API base URL.'**
  String get resultStatusMissingApiBaseUrl;

  /// No description provided for @resultStatusUnexpectedResponse.
  ///
  /// In en, this message translates to:
  /// **'Unexpected response — tap to retry.'**
  String get resultStatusUnexpectedResponse;

  /// No description provided for @resultStatusInterpretationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'AI interpretation unavailable — tap to retry.'**
  String get resultStatusInterpretationUnavailable;

  /// No description provided for @oracleWaitingTitle.
  ///
  /// In en, this message translates to:
  /// **'The Oracle is listening…'**
  String get oracleWaitingTitle;

  /// No description provided for @oracleWaitingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hold steady while the cards settle into focus.'**
  String get oracleWaitingSubtitle;

  /// No description provided for @oracleTimeoutTitle.
  ///
  /// In en, this message translates to:
  /// **'The Oracle is silent…'**
  String get oracleTimeoutTitle;

  /// No description provided for @oracleTimeoutBody.
  ///
  /// In en, this message translates to:
  /// **'Sometimes clarity needs another breath.'**
  String get oracleTimeoutBody;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionTryAgain;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @historyTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading history'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In en, this message translates to:
  /// **'History is empty for now.'**
  String get historyEmpty;

  /// No description provided for @historyClearButton.
  ///
  /// In en, this message translates to:
  /// **'Clear history'**
  String get historyClearButton;

  /// No description provided for @historyDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading detail'**
  String get historyDetailTitle;

  /// No description provided for @historyTldrTitle.
  ///
  /// In en, this message translates to:
  /// **'TL;DR'**
  String get historyTldrTitle;

  /// No description provided for @offlineFallbackReflection.
  ///
  /// In en, this message translates to:
  /// **'reflection'**
  String get offlineFallbackReflection;

  /// No description provided for @offlineFallbackSummary.
  ///
  /// In en, this message translates to:
  /// **'For “{question}”, the reading centers on {keywords}.'**
  String offlineFallbackSummary(Object question, Object keywords);

  /// No description provided for @offlineFallbackAdviceLabel.
  ///
  /// In en, this message translates to:
  /// **'Advice: {advice}'**
  String offlineFallbackAdviceLabel(Object advice);

  /// No description provided for @offlineFallbackWhy.
  ///
  /// In en, this message translates to:
  /// **'Each position reflects a facet of your question, and the card themes align with where attention can be placed now.'**
  String get offlineFallbackWhy;

  /// No description provided for @offlineFallbackAction.
  ///
  /// In en, this message translates to:
  /// **'Choose one small, practical step that honors the advice in the cards.'**
  String get offlineFallbackAction;

  /// No description provided for @moreFeaturesTitle.
  ///
  /// In en, this message translates to:
  /// **'More features'**
  String get moreFeaturesTitle;

  /// No description provided for @natalChartTitle.
  ///
  /// In en, this message translates to:
  /// **'Natal chart'**
  String get natalChartTitle;

  /// No description provided for @natalChartDescription.
  ///
  /// In en, this message translates to:
  /// **'Get a personal astrological overview based on your birth data.'**
  String get natalChartDescription;

  /// No description provided for @natalChartFreeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get natalChartFreeLabel;

  /// No description provided for @natalChartButton.
  ///
  /// In en, this message translates to:
  /// **'I want'**
  String get natalChartButton;

  /// No description provided for @natalChartBirthDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get natalChartBirthDateLabel;

  /// No description provided for @natalChartBirthDateHint.
  ///
  /// In en, this message translates to:
  /// **'YYYY-MM-DD'**
  String get natalChartBirthDateHint;

  /// No description provided for @natalChartBirthDateError.
  ///
  /// In en, this message translates to:
  /// **'Please enter your birth date.'**
  String get natalChartBirthDateError;

  /// No description provided for @natalChartBirthTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time of birth'**
  String get natalChartBirthTimeLabel;

  /// No description provided for @natalChartBirthTimeHint.
  ///
  /// In en, this message translates to:
  /// **'HH:MM'**
  String get natalChartBirthTimeHint;

  /// No description provided for @natalChartBirthTimeHelper.
  ///
  /// In en, this message translates to:
  /// **'If unsure, use 12:00 (noon).'**
  String get natalChartBirthTimeHelper;

  /// No description provided for @natalChartGenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get natalChartGenerateButton;

  /// No description provided for @natalChartLoading.
  ///
  /// In en, this message translates to:
  /// **'Creating your natal chart…'**
  String get natalChartLoading;

  /// No description provided for @natalChartResultTitle.
  ///
  /// In en, this message translates to:
  /// **'Your interpretation'**
  String get natalChartResultTitle;

  /// No description provided for @natalChartError.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t generate the natal chart. Please try again.'**
  String get natalChartError;

  /// No description provided for @energyLabelWithPercent.
  ///
  /// In en, this message translates to:
  /// **'Oracle energy: {value}%'**
  String energyLabelWithPercent(int value);

  /// No description provided for @energyRecoveryReady.
  ///
  /// In en, this message translates to:
  /// **'Fully recharged.'**
  String get energyRecoveryReady;

  /// No description provided for @energyRecoveryLessThanMinute.
  ///
  /// In en, this message translates to:
  /// **'Full in less than a minute.'**
  String get energyRecoveryLessThanMinute;

  /// No description provided for @energyRecoveryInMinutes.
  ///
  /// In en, this message translates to:
  /// **'Full in {minutes} min.'**
  String energyRecoveryInMinutes(int minutes);

  /// No description provided for @energyActionCost.
  ///
  /// In en, this message translates to:
  /// **'Action cost: {value}%'**
  String energyActionCost(int value);

  /// No description provided for @energyTopUpButton.
  ///
  /// In en, this message translates to:
  /// **'Top up'**
  String get energyTopUpButton;

  /// No description provided for @energyTopUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Energy is running low'**
  String get energyTopUpTitle;

  /// No description provided for @energyTopUpDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose a pack to continue readings without waiting for recharge.'**
  String get energyTopUpDescription;

  /// No description provided for @energyPackSmall.
  ///
  /// In en, this message translates to:
  /// **'Buy +25% energy'**
  String get energyPackSmall;

  /// No description provided for @energyPackMedium.
  ///
  /// In en, this message translates to:
  /// **'Buy +50% energy'**
  String get energyPackMedium;

  /// No description provided for @energyPackFull.
  ///
  /// In en, this message translates to:
  /// **'Buy full energy'**
  String get energyPackFull;

  /// No description provided for @energyTopUpSuccess.
  ///
  /// In en, this message translates to:
  /// **'Energy restored by {value}%.'**
  String energyTopUpSuccess(int value);

  /// No description provided for @energyInsufficientForAction.
  ///
  /// In en, this message translates to:
  /// **'Not enough energy for this action ({value}%).'**
  String energyInsufficientForAction(int value);

  /// No description provided for @professionalReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional reading'**
  String get professionalReadingTitle;

  /// No description provided for @professionalReadingDescription.
  ///
  /// In en, this message translates to:
  /// **'Deep interpretation of your spread by an oracle.'**
  String get professionalReadingDescription;

  /// No description provided for @professionalReadingButton.
  ///
  /// In en, this message translates to:
  /// **'Choose plan'**
  String get professionalReadingButton;

  /// No description provided for @professionalReadingOpenBotMessage.
  ///
  /// In en, this message translates to:
  /// **'Open the bot to see subscription plans.'**
  String get professionalReadingOpenBotMessage;

  /// No description provided for @professionalReadingOpenBotAction.
  ///
  /// In en, this message translates to:
  /// **'Open bot'**
  String get professionalReadingOpenBotAction;

  /// No description provided for @professionalReadingOpenBotSnackbar.
  ///
  /// In en, this message translates to:
  /// **'Open bot to choose a plan.'**
  String get professionalReadingOpenBotSnackbar;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'kk':
      return AppLocalizationsKk();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
