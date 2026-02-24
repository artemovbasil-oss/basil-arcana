// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'La vraie magie';

  @override
  String get historyTooltip => 'Historique';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsPromoTitle => 'Code promotionnel';

  @override
  String get settingsPromoDescription =>
      'Entrez un code promo pour l\'activer.';

  @override
  String get settingsPromoHint => 'Entrez le code promotionnel';

  @override
  String get settingsPromoApplyButton => 'Activer le code promo';

  @override
  String get settingsPromoInvalid => 'Le code promotionnel n\'est pas valide.';

  @override
  String get settingsPromoApplied => 'Code promotionnel activé avec succès.';

  @override
  String get settingsPromoResetButton => 'Désactiver le code promo';

  @override
  String get settingsPromoResetDone =>
      'Promo désactivée. Retour à la version gratuite.';

  @override
  String get settingsDashboardTitle => 'Votre tableau de bord de profil';

  @override
  String get settingsDashboardTopCardsTitle =>
      'Meilleures cartes par fréquence';

  @override
  String get settingsDashboardTopCardsEmpty =>
      'Aucune statistique de carte pour l\'instant.';

  @override
  String get settingsDashboardServicesTitle => 'Prestations payantes';

  @override
  String get settingsDashboardServicesEmpty => 'Aucun service payant actif.';

  @override
  String get settingsDashboardServiceUnlimitedNoDate =>
      'Le plan d\'énergie illimité est actif.';

  @override
  String settingsDashboardServiceUnlimitedWithDate(Object date) {
    return 'Le plan d\'énergie illimité est actif jusqu\'au $date.';
  }

  @override
  String settingsDashboardEnergy(Object value) {
    return 'Énergie actuelle : $value';
  }

  @override
  String settingsDashboardFreePremium(int count) {
    return 'Bonus gratuits (lecture de cinq cartes / compatibilité / thème natal) : $count';
  }

  @override
  String settingsDashboardFreePremiumRemaining(int count) {
    return 'Bonus gratuits restants : $count';
  }

  @override
  String settingsDashboardInvited(int count) {
    return 'Utilisateurs invités : $count';
  }

  @override
  String get settingsDashboardShareButton =>
      'Partager un lien de parrainage personnel';

  @override
  String get settingsDashboardLoadError =>
      'Impossible de charger les données du tableau de bord pour le moment.';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageEnglish => 'Anglais (EN)';

  @override
  String get languageRussian => 'Russe (RU)';

  @override
  String get languageKazakh => 'Kazakh (KZ)';

  @override
  String get deckLabel => 'Jeu';

  @override
  String get deckAll => 'Tous les decks';

  @override
  String get deckMajor => 'Arcanes majeurs';

  @override
  String get deckWands => 'Bâtons';

  @override
  String get deckCups => 'Coupes';

  @override
  String get deckSwords => 'Épées';

  @override
  String get deckPentacles => 'Pentacles';

  @override
  String get deckTarotRiderWaite => 'Tarot Rider-Waite';

  @override
  String get deckLenormand => 'Jeu Lenormand';

  @override
  String get deckCrowley => 'Jeu Aleister Crowley';

  @override
  String get deckAllName => 'Tous les decks';

  @override
  String get deckMajorName => 'Arcanes majeurs';

  @override
  String get deckWandsName => 'Bâtons';

  @override
  String get deckCupsName => 'Coupes';

  @override
  String get deckSwordsName => 'Épées';

  @override
  String get deckPentaclesName => 'Pentacles';

  @override
  String get deckLenormandName => 'Lenormand';

  @override
  String get deckCrowleyName => 'Crowley';

  @override
  String get deckDebugLogLabel =>
      'Débogage : enregistrer le chemin de l\'actif Wands';

  @override
  String get homeTagline => 'Clarté, dans les cartes.';

  @override
  String get homeSubtitle =>
      'Posez une question et explorez les fils de discussion qui façonneront votre prochaine étape';

  @override
  String get homeDescription => 'Attrapez l\'ambiance magique';

  @override
  String get homeQuestionPlaceholder => 'Tapez votre question ici…';

  @override
  String get homeQuestionLabel => 'Quelle est votre question ?';

  @override
  String get homeQuestionHint =>
      'Tapez ce sur quoi vous voulez des éclaircissements';

  @override
  String get homeClearQuestionTooltip => 'Effacer la question';

  @override
  String get homeTryPrompt => 'Essayez l\'une de ces invites :';

  @override
  String get homeRecentQueriesButton => 'Invites récentes';

  @override
  String get homeExample1 => 'Où dois-je placer mon énergie ?';

  @override
  String get homeExample2 => 'Quelle est la leçon cachée ici ?';

  @override
  String get homeExample3 => 'Qu\'est-ce qui a besoin de patience de ma part ?';

  @override
  String get homeQuickTopicRelationships => 'Relations';

  @override
  String get homeQuickTopicMoney => 'Argent';

  @override
  String get homeQuickTopicFuture => 'Avenir';

  @override
  String get homeQuickTopicGrowth => 'Point de croissance';

  @override
  String get homeQuickTopicWeatherTomorrow => 'La météo de demain';

  @override
  String get homeContinueButton => 'Continuer vers votre tirage';

  @override
  String get homeAllCardsButton => 'Toutes les cartes';

  @override
  String get homeAllCardsDescription => 'Touchez la magie des cartes';

  @override
  String get cardsTitle => 'Toutes les cartes';

  @override
  String get cardsEmptyTitle => 'Aucune carte à afficher pour l\'instant';

  @override
  String get cardsEmptySubtitle => 'Veuillez réessayer dans un instant.';

  @override
  String get cardsLoadError => 'Données de cartes manquantes ou invalides.';

  @override
  String get dataLoadTitle =>
      'Impossible d\'accéder à la bibliothèque de cartes.';

  @override
  String get dataLoadRetry => 'Réessayer';

  @override
  String get dataLoadUseCache => 'Utiliser les données mises en cache';

  @override
  String get dataLoadSpreadsError =>
      'Impossible de charger les tirages pour le moment.';

  @override
  String get cardsDetailTitle => 'Détails de la carte';

  @override
  String get cardTitleFieldTitle => 'Titre';

  @override
  String get cardTagsTitle => 'Balises';

  @override
  String get cardDescriptionTitle => 'Description';

  @override
  String get cardKeywordsTitle => 'Mots-clés';

  @override
  String get cardGeneralTitle => 'Signification générale';

  @override
  String get cardDetailedTitle => 'Description détaillée';

  @override
  String get cardFunFactTitle => 'Fait amusant';

  @override
  String get cardStatsTitle => 'Statistiques';

  @override
  String get cardDetailsFallback => 'Détails indisponibles.';

  @override
  String get statLuck => 'Chance';

  @override
  String get statPower => 'Pouvoir';

  @override
  String get statLove => 'Amour';

  @override
  String get statClarity => 'Clarté';

  @override
  String get cardsDetailKeywordsTitle => 'Mots-clés';

  @override
  String get cardsDetailMeaningTitle => 'Signification générale';

  @override
  String get cardsDetailDescriptionTitle => 'Description détaillée';

  @override
  String get cardsDetailFunFactTitle => 'Fait amusant';

  @override
  String get cardsDetailStatsTitle => 'Statistiques';

  @override
  String get cardsDetailStatLuck => 'Chance';

  @override
  String get cardsDetailStatPower => 'Pouvoir';

  @override
  String get cardsDetailStatLove => 'Amour';

  @override
  String get cardsDetailStatClarity => 'Clarté';

  @override
  String get videoTapToPlay => 'Appuyez pour jouer';

  @override
  String get cdnHealthTitle => 'Santé du CDN';

  @override
  String get cdnHealthAssetsBaseLabel => 'URL de base des éléments';

  @override
  String get cdnHealthLocaleLabel => 'Langue';

  @override
  String get cdnHealthCardsFileLabel => 'Cartes JSON';

  @override
  String get cdnHealthSpreadsFileLabel => 'Tirages JSON';

  @override
  String get cdnHealthVideoIndexLabel => 'Index vidéo';

  @override
  String get cdnHealthLastFetchLabel => 'Dernière récupération';

  @override
  String get cdnHealthLastCacheLabel => 'Dernier accès au cache';

  @override
  String get cdnHealthTestFetch => 'Test de récupération de cartes/spreads';

  @override
  String get cdnHealthStatusIdle => 'Inactif';

  @override
  String get cdnHealthStatusSuccess => 'Récupération réussie';

  @override
  String get cdnHealthStatusFailed => 'Échec de la récupération';

  @override
  String get spreadTitle => 'Choisissez un tirage';

  @override
  String get spreadOneCardTitle => 'Une carte';

  @override
  String get spreadOneCardSubtitle =>
      'Un petit miroir pour le moment. Une carte – un objectif clair.';

  @override
  String get spreadThreeCardTitle => 'Trois cartes';

  @override
  String get spreadThreeCardSubtitle =>
      'Un arc simple de votre histoire. Trois cartes – contexte et direction.';

  @override
  String get spreadFiveCardTitle => 'Cinq cartes';

  @override
  String get spreadFiveCardSubtitle =>
      'Un regard plus profond sur votre chemin. Cinq cartes – contexte et conseils à plusieurs niveaux.';

  @override
  String get spreadLenormandOneCardSubtitle =>
      'Un signal pratique pour le moment. Une carte – un indicateur clair.';

  @override
  String get spreadLenormandThreeCardSubtitle =>
      'Une ligne de cause à résultat. Trois cartes : déclencheur, développement, résultat le plus proche.';

  @override
  String get spreadLenormandFiveCardSubtitle =>
      'Une chaîne d’événements vivante. Cinq cartes – chaque symbole suivant affine le précédent.';

  @override
  String get spreadFivePosition1 => 'Énergie de base';

  @override
  String get spreadFivePosition2 => 'Qu\'est-ce qui aide';

  @override
  String get spreadFivePosition3 => 'Quels blocs';

  @override
  String get spreadFivePosition4 => 'Facteur caché';

  @override
  String get spreadFivePosition5 => 'Résultat et conseils';

  @override
  String get spreadLabelPast => 'Passé';

  @override
  String get spreadLabelPresent => 'Présent';

  @override
  String get spreadLabelFuture => 'Avenir';

  @override
  String spreadCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cartes',
      one: '1 carte',
    );
    return '$_temp0';
  }

  @override
  String spreadLoadError(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get shuffleTitle => 'Mélangez le jeu';

  @override
  String get shuffleSubtitle => 'Mélanger le jeu';

  @override
  String get shuffleReadingSubtitle => 'Lire votre spread';

  @override
  String get shuffleDrawButton => 'Tirer des cartes';

  @override
  String get resultTitle => 'Votre lecture';

  @override
  String get resultStatusAiReading => 'Basil interprète…';

  @override
  String get resultRequestIdUnavailable => 'ID de demande indisponible';

  @override
  String resultRequestIdLabel(Object id) {
    return 'Numéro de demande : $id';
  }

  @override
  String get resultSnackSaved => 'Lecture enregistrée.';

  @override
  String get resultSectionArcaneSnapshot => 'Instantané arcanique';

  @override
  String get resultSectionWhy => 'Pourquoi cette lecture';

  @override
  String get resultSectionAction =>
      'Étape d’action (prochaines 24 à 72 heures)';

  @override
  String resultLenormandStep(int step, int total) {
    return 'Lenormand étape $step de $total';
  }

  @override
  String get resultLenormandBuildsOn => 'S\'appuie sur';

  @override
  String get resultReferralTitle => 'Prime de parrainage';

  @override
  String get resultReferralBody =>
      'Partagez votre lien personnel avec vos amis et obtenez 20 lectures premium gratuites de cinq cartes, 20 tests de compatibilité et 20 cartes natales pour chaque nouvel utilisateur qui rejoint votre lien.';

  @override
  String get resultReferralButton => 'Partager le lien';

  @override
  String get resultReferralCopied =>
      'Lien de parrainage copié. Envoyez-le dans Telegram.';

  @override
  String get resultReferralShareMessage =>
      'Découvrez la vraie magie de Telegram : une clarté élégante du Tarot pour l\'amour, l\'argent et votre prochain mouvement.';

  @override
  String get resultDeepPrompt =>
      'Vous voulez des détails sur les relations et la carrière ?';

  @override
  String get resultDeepNotNow => 'Pas maintenant';

  @override
  String get resultDeepShowDetails => 'Oui';

  @override
  String get resultDeepRetryMessage =>
      'La lecture plus approfondie s\'est échappée. Voulez-vous réessayer ?';

  @override
  String get resultDeepCancel => 'Annuler';

  @override
  String get resultDeepTryAgain => 'Essayer à nouveau';

  @override
  String get resultDeepTypingLabel => 'Oracle tape…';

  @override
  String get resultDeepRelationshipsHeading => 'Relations';

  @override
  String get resultDeepCareerHeading => 'Carrière';

  @override
  String cardsDrawnCount(int count) {
    return 'Dessiné $count×';
  }

  @override
  String get resultDetailsTitle => 'Détails';

  @override
  String get resultSaveButton => 'Enregistrer la lecture';

  @override
  String get resultNewButton => 'Nouvelle lecture';

  @override
  String get resultWantMoreButton => 'Je veux plus';

  @override
  String get resultStatusUnauthorized =>
      'Service indisponible : réessayez dans quelques instants.';

  @override
  String get resultStatusNoInternet =>
      'Pas d\'Internet – affichage de la lecture hors ligne';

  @override
  String get resultStatusTimeout =>
      'L\'oracle s\'est arrêté : appuyez pour réessayer.';

  @override
  String get resultStatusTooManyAttempts =>
      'Trop de tentatives : veuillez patienter et réessayer.';

  @override
  String resultStatusServerUnavailableWithStatus(int status) {
    return 'Oracle indisponible ($status) — réessayez dans un instant.';
  }

  @override
  String get resultStatusServerUnavailable =>
      'Oracle indisponible : réessayez dans un instant.';

  @override
  String get resultStatusMissingApiBaseUrl =>
      'Erreur de configuration : URL de base de l\'API manquante.';

  @override
  String get resultStatusUnexpectedResponse =>
      'Réponse inattendue : appuyez pour réessayer.';

  @override
  String get resultStatusInterpretationUnavailable =>
      'Interprétation IA indisponible : appuyez pour réessayer.';

  @override
  String get oracleWaitingTitle => 'L’Oracle écoute…';

  @override
  String get oracleWaitingSubtitle =>
      'Restez stable pendant que les cartes se mettent au point.';

  @override
  String get oracleTimeoutTitle => 'L’Oracle est silencieux…';

  @override
  String get oracleTimeoutBody =>
      'Parfois, la clarté a besoin d’un autre souffle.';

  @override
  String get actionCancel => 'Annuler';

  @override
  String get actionTryAgain => 'Essayer à nouveau';

  @override
  String get actionApply => 'Appliquer';

  @override
  String get historyTitle => 'Historique des tirages';

  @override
  String get historyEmpty => 'L historique est vide pour le moment.';

  @override
  String get historyClearButton => 'Effacer l\'historique';

  @override
  String get historyDetailTitle => 'Détail de la lecture';

  @override
  String get historyTldrTitle => 'TL;DR';

  @override
  String get queryHistoryTitle => 'Invites récentes';

  @override
  String get queryHistoryEmpty => 'Aucune invite précédente pour l\'instant.';

  @override
  String get queryHistoryLoadError =>
      'Impossible de charger l historique des requêtes.';

  @override
  String get queryHistoryRetry => 'Réessayer';

  @override
  String get offlineFallbackReflection => 'réflexion';

  @override
  String offlineFallbackSummary(Object question, Object keywords) {
    return 'Pour « $question », la lecture est centrée sur $keywords.';
  }

  @override
  String offlineFallbackAdviceLabel(Object advice) {
    return 'Conseil : $advice';
  }

  @override
  String get offlineFallbackWhy =>
      'Chaque position reflète une facette de votre question, et les thèmes des cartes correspondent à l\'endroit où l\'attention peut être portée maintenant.';

  @override
  String get offlineFallbackAction =>
      'Choisissez une petite étape pratique qui respecte les conseils contenus dans les cartes.';

  @override
  String get moreFeaturesTitle => 'Plus de fonctionnalités';

  @override
  String get natalChartTitle => 'Thème natal';

  @override
  String get natalChartDescription =>
      'Obtenez un aperçu astrologique personnel basé sur vos données de naissance.';

  @override
  String get natalChartFreeLabel => 'Gratuit';

  @override
  String get natalChartButton => 'Je veux';

  @override
  String get natalChartBirthDateLabel => 'Date de naissance';

  @override
  String get natalChartBirthDateHint => 'AAAA-MM-JJ';

  @override
  String get natalChartBirthDateError =>
      'Veuillez entrer votre date de naissance.';

  @override
  String get natalChartBirthTimeLabel => 'Heure de naissance';

  @override
  String get natalChartBirthTimeHint => 'HH : MM';

  @override
  String get natalChartBirthTimeHelper =>
      'En cas de doute, utilisez 12h00 (midi).';

  @override
  String get natalChartGenerateButton => 'Générer';

  @override
  String get natalChartLoading => 'Création de votre thème natal…';

  @override
  String get natalChartResultTitle => 'Votre interprétation';

  @override
  String get natalChartError =>
      'Impossible de générer le thème natal. Veuillez réessayer.';

  @override
  String energyLabelWithPercent(int value) {
    return 'Énergie oracle : $value %';
  }

  @override
  String get energyLabel => 'Énergie Oracle';

  @override
  String get energyInfoTooltip =>
      'L\'énergie est dépensée en actions et restaurée au fil du temps';

  @override
  String get energyRecoveryReady => 'Complètement rechargé.';

  @override
  String get energyRecoveryLessThanMinute => 'Complet en moins d\'une minute.';

  @override
  String energyRecoveryInMinutes(int minutes) {
    return 'Complète en $minutes min.';
  }

  @override
  String energyActionCost(int value) {
    return 'Coût de l\'action : $value %';
  }

  @override
  String get energyTopUpButton => 'Recharger';

  @override
  String get energyTopUpTitle => 'Nourrissez votre flux arcanique';

  @override
  String get energyTopUpDescription =>
      'Votre énergie garde la lecture claire et profonde. Choisissez votre rythme et restez dans la magie.';

  @override
  String get energyTopUpDescriptionCompact =>
      'L\'énergie est dépensée en actions et récupère avec le temps. Vous pouvez attendre une recharge gratuite ou la booster instantanément avec des étoiles.';

  @override
  String get energyCostsTitle => 'Coût énergétique par action';

  @override
  String get energyCostReading => 'En lisant';

  @override
  String get energyCostDeepDetails => 'Détails profonds';

  @override
  String get energyCostNatalChart => 'Thème natal';

  @override
  String get energyCostCompatibility => 'Compatibilité amoureuse';

  @override
  String get energyNextFreeReady =>
      'Votre prochaine tentative gratuite est prête.';

  @override
  String energyNextFreeIn(String value) {
    return 'Prochaine tentative gratuite dans : $value';
  }

  @override
  String get energyPackSmall => 'Achetez +25% d\'énergie';

  @override
  String get energyPackMedium => 'Achetez +50% d\'énergie';

  @override
  String get energyPackFull => 'Recharger jusqu\'à 100%';

  @override
  String get energyPackWeekUnlimited => 'Illimité pendant 1 semaine — 99 ⭐';

  @override
  String get energyPackMonthUnlimited => 'Illimité pendant 1 mois — 499 ⭐';

  @override
  String get energyPackYearUnlimited => 'Illimité pendant 1 an — 4999 ⭐';

  @override
  String energyTopUpSuccess(int value) {
    return 'Énergie restaurée de $value%.';
  }

  @override
  String get energyUnlimitedActivated => 'Énergie illimitée activée.';

  @override
  String get energyTopUpProcessing => 'Paiement d\'ouverture...';

  @override
  String get energyTopUpOnlyInTelegram =>
      'Le rechargement avec Telegram Stars est disponible uniquement dans Telegram.';

  @override
  String get energyTopUpPaymentCancelled => 'Le paiement a été annulé.';

  @override
  String get energyTopUpPaymentPending =>
      'Le paiement est en attente de confirmation.';

  @override
  String get energyTopUpPaymentFailed =>
      'Le paiement a échoué. Essayer à nouveau.';

  @override
  String get energyTopUpServiceUnavailable =>
      'Le paiement est temporairement indisponible.';

  @override
  String energyInsufficientForAction(int value) {
    return 'Pas assez d\'énergie pour cette action ($value%).';
  }

  @override
  String get professionalReadingTitle => 'Lecture professionnelle';

  @override
  String get professionalReadingDescription =>
      'Interprétation approfondie de votre tirage par un oracle.';

  @override
  String get professionalReadingButton => 'Choisir le forfait';

  @override
  String get professionalReadingOpenBotMessage =>
      'Ouvrez le bot pour voir les plans d\'abonnement.';

  @override
  String get professionalReadingOpenBotAction => 'Bot ouvert';

  @override
  String get professionalReadingOpenBotSnackbar =>
      'Ouvrez le bot pour choisir un plan.';

  @override
  String get languageFrench => 'Français (FR)';

  @override
  String get languageTurkish => 'Turc (TR)';
}
