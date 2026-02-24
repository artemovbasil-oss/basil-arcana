// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Turkish (`tr`).
class AppLocalizationsTr extends AppLocalizations {
  AppLocalizationsTr([String locale = 'tr']) : super(locale);

  @override
  String get appTitle => 'Gerçek büyü';

  @override
  String get historyTooltip => 'Geçmiş';

  @override
  String get settingsTitle => 'Ayarlar';

  @override
  String get settingsPromoTitle => 'Promosyon kodu';

  @override
  String get settingsPromoDescription =>
      'Etkinleştirmek için bir promosyon kodu girin.';

  @override
  String get settingsPromoHint => 'Promosyon kodunu girin';

  @override
  String get settingsPromoApplyButton => 'Promosyon kodunu etkinleştir';

  @override
  String get settingsPromoInvalid => 'Promosyon kodu geçersiz.';

  @override
  String get settingsPromoApplied =>
      'Promosyon kodu başarıyla etkinleştirildi.';

  @override
  String get settingsPromoResetButton => 'Promosyon kodunu devre dışı bırak';

  @override
  String get settingsPromoResetDone =>
      'Promosyon devre dışı bırakıldı. Ücretsiz sürüme geri dönün.';

  @override
  String get settingsDashboardTitle => 'Profil kontrol paneliniz';

  @override
  String get settingsDashboardTopCardsTitle => 'Sıklığa göre en iyi kartlar';

  @override
  String get settingsDashboardTopCardsEmpty => 'Henüz kart istatistiği yok.';

  @override
  String get settingsDashboardServicesTitle => 'Ücretli hizmetler';

  @override
  String get settingsDashboardServicesEmpty => 'Aktif ücretli hizmet yok.';

  @override
  String get settingsDashboardServiceUnlimitedNoDate =>
      'Sınırsız enerji planı aktif.';

  @override
  String settingsDashboardServiceUnlimitedWithDate(Object date) {
    return 'Sınırsız enerji planı $date tarihine kadar etkindir.';
  }

  @override
  String settingsDashboardEnergy(Object value) {
    return 'Mevcut enerji: $value';
  }

  @override
  String settingsDashboardFreePremium(int count) {
    return 'Ücretsiz bonuslar (beş kart okuma / uyumluluk / doğum haritası): $count';
  }

  @override
  String settingsDashboardFreePremiumRemaining(int count) {
    return 'Kalan ücretsiz bonuslar: $count';
  }

  @override
  String settingsDashboardInvited(int count) {
    return 'Davet edilen kullanıcılar: $count';
  }

  @override
  String get settingsDashboardShareButton => 'Kişisel davet bağlantını paylaş';

  @override
  String get settingsDashboardLoadError =>
      'Kontrol paneli verileri şu anda yüklenemiyor.';

  @override
  String get languageLabel => 'Dil';

  @override
  String get languageEnglish => 'İngilizce (EN)';

  @override
  String get languageRussian => 'Rusça (RU)';

  @override
  String get languageKazakh => 'Kazakça (KZ)';

  @override
  String get deckLabel => 'Deste';

  @override
  String get deckAll => 'Tüm desteler';

  @override
  String get deckMajor => 'Büyük Arkana';

  @override
  String get deckWands => 'Değnekler';

  @override
  String get deckCups => 'Kupalar';

  @override
  String get deckSwords => 'Kılıçlar';

  @override
  String get deckPentacles => 'Tılsımlar';

  @override
  String get deckTarotRiderWaite => 'Rider-Waite Tarot';

  @override
  String get deckLenormand => 'Lenormand güvertesi';

  @override
  String get deckCrowley => 'Aleister Crowley destesi';

  @override
  String get deckAllName => 'Tüm desteler';

  @override
  String get deckMajorName => 'Büyük Arkana';

  @override
  String get deckWandsName => 'Değnekler';

  @override
  String get deckCupsName => 'Kupalar';

  @override
  String get deckSwordsName => 'Kılıçlar';

  @override
  String get deckPentaclesName => 'Tılsımlar';

  @override
  String get deckLenormandName => 'Lenormand';

  @override
  String get deckCrowleyName => 'Crowley';

  @override
  String get deckDebugLogLabel =>
      'Hata ayıklama: Değnekler varlık yolunu kaydet';

  @override
  String get homeTagline => 'Kartlarda netlik.';

  @override
  String get homeSubtitle =>
      'Bir soru sorun ve bir sonraki adımınızı şekillendirecek konuları keşfedin';

  @override
  String get homeDescription => 'Büyülü havayı yakalayın';

  @override
  String get homeQuestionPlaceholder => 'Sorunuzu buraya yazın…';

  @override
  String get homeQuestionLabel => 'Sorunuz nedir?';

  @override
  String get homeQuestionHint => 'Netlik istediğiniz şeyi yazın';

  @override
  String get homeClearQuestionTooltip => 'Soruyu temizle';

  @override
  String get homeTryPrompt => 'Bu istemlerden birini deneyin:';

  @override
  String get homeRecentQueriesButton => 'Son istemler';

  @override
  String get homeExample1 => 'Enerjimi nereye yönlendirmeliyim?';

  @override
  String get homeExample2 => 'Buradaki gizli ders nedir?';

  @override
  String get homeExample3 => 'Benden sabır gerektiren ne?';

  @override
  String get homeQuickTopicRelationships => 'İlişkiler';

  @override
  String get homeQuickTopicMoney => 'Para';

  @override
  String get homeQuickTopicFuture => 'Gelecek';

  @override
  String get homeQuickTopicGrowth => 'Büyüme noktası';

  @override
  String get homeQuickTopicWeatherTomorrow => 'Yarının hava durumu';

  @override
  String get homeContinueButton => 'Açılımına devam et';

  @override
  String get homeAllCardsButton => 'Tüm kartlar';

  @override
  String get homeAllCardsDescription => 'Kartların büyüsüne dokunun';

  @override
  String get cardsTitle => 'Tüm kartlar';

  @override
  String get cardsEmptyTitle => 'Henüz gösterilecek kart yok';

  @override
  String get cardsEmptySubtitle => 'Lütfen kısa bir süre sonra tekrar deneyin.';

  @override
  String get cardsLoadError => 'Kart verileri eksik veya geçersiz.';

  @override
  String get dataLoadTitle => 'Kart kitaplığına erişilemiyor.';

  @override
  String get dataLoadRetry => 'Yeniden dene';

  @override
  String get dataLoadUseCache => 'Önbelleğe alınmış verileri kullan';

  @override
  String get dataLoadSpreadsError => 'Açılımlar şu anda yüklenemiyor.';

  @override
  String get cardsDetailTitle => 'Kart ayrıntıları';

  @override
  String get cardTitleFieldTitle => 'Başlık';

  @override
  String get cardTagsTitle => 'Etiketler';

  @override
  String get cardDescriptionTitle => 'Tanım';

  @override
  String get cardKeywordsTitle => 'Anahtar Kelimeler';

  @override
  String get cardGeneralTitle => 'Genel anlam';

  @override
  String get cardDetailedTitle => 'Ayrıntılı açıklama';

  @override
  String get cardFunFactTitle => 'Eğlenceli gerçek';

  @override
  String get cardStatsTitle => 'İstatistikler';

  @override
  String get cardDetailsFallback => 'Ayrıntılar mevcut değil.';

  @override
  String get statLuck => 'Şans';

  @override
  String get statPower => 'Güç';

  @override
  String get statLove => 'Aşk';

  @override
  String get statClarity => 'Netlik';

  @override
  String get cardsDetailKeywordsTitle => 'Anahtar Kelimeler';

  @override
  String get cardsDetailMeaningTitle => 'Genel anlam';

  @override
  String get cardsDetailDescriptionTitle => 'Ayrıntılı açıklama';

  @override
  String get cardsDetailFunFactTitle => 'Eğlenceli gerçek';

  @override
  String get cardsDetailStatsTitle => 'İstatistikler';

  @override
  String get cardsDetailStatLuck => 'Şans';

  @override
  String get cardsDetailStatPower => 'Güç';

  @override
  String get cardsDetailStatLove => 'Aşk';

  @override
  String get cardsDetailStatClarity => 'Netlik';

  @override
  String get videoTapToPlay => 'Oynamak için dokunun';

  @override
  String get cdnHealthTitle => 'CDN sağlığı';

  @override
  String get cdnHealthAssetsBaseLabel => 'Öğeler temel URL\'si';

  @override
  String get cdnHealthLocaleLabel => 'Yerel ayar';

  @override
  String get cdnHealthCardsFileLabel => 'Kartlar JSON';

  @override
  String get cdnHealthSpreadsFileLabel => 'Açılımlar JSON';

  @override
  String get cdnHealthVideoIndexLabel => 'Video dizini';

  @override
  String get cdnHealthLastFetchLabel => 'Son indirme';

  @override
  String get cdnHealthLastCacheLabel => 'Son önbellek isabeti';

  @override
  String get cdnHealthTestFetch => 'Kart ve açılım indirmesini test et';

  @override
  String get cdnHealthStatusIdle => 'Boşta';

  @override
  String get cdnHealthStatusSuccess => 'İndirme başarılı';

  @override
  String get cdnHealthStatusFailed => 'İndirme başarısız';

  @override
  String get spreadTitle => 'Bir açılım seç';

  @override
  String get spreadOneCardTitle => 'Bir kart';

  @override
  String get spreadOneCardSubtitle =>
      'Şimdilik hızlı bir ayna. Tek kart – tek net odak.';

  @override
  String get spreadThreeCardTitle => 'Üç kart';

  @override
  String get spreadThreeCardSubtitle =>
      'Hikayenizin basit bir akışı. Üç kart – bağlam ve yön.';

  @override
  String get spreadFiveCardTitle => 'Beş kart';

  @override
  String get spreadFiveCardSubtitle =>
      'Yolunuza daha derin bir bakış. Beş kart — katmanlı bağlam ve rehberlik.';

  @override
  String get spreadLenormandOneCardSubtitle =>
      'Şu an için pratik bir sinyal. Bir kart — tek bir açık gösterge.';

  @override
  String get spreadLenormandThreeCardSubtitle =>
      'Neden-sonuç çizgisi. Üç kart – tetikleme, geliştirme, en yakın sonuç.';

  @override
  String get spreadLenormandFiveCardSubtitle =>
      'Yaşayan bir olaylar zinciri. Beş kart — sonraki her sembol bir öncekini geliştirir.';

  @override
  String get spreadFivePosition1 => 'Çekirdek enerjisi';

  @override
  String get spreadFivePosition2 => 'Ne yardımcı olur?';

  @override
  String get spreadFivePosition3 => 'Hangi bloklar';

  @override
  String get spreadFivePosition4 => 'Gizli faktör';

  @override
  String get spreadFivePosition5 => 'Sonuç ve tavsiye';

  @override
  String get spreadLabelPast => 'Geçmiş';

  @override
  String get spreadLabelPresent => 'Şimdi';

  @override
  String get spreadLabelFuture => 'Gelecek';

  @override
  String spreadCardCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kart',
      one: '1 kart',
    );
    return '$_temp0';
  }

  @override
  String spreadLoadError(Object error) {
    return 'Hata: $error';
  }

  @override
  String get shuffleTitle => 'Desteyi karıştır';

  @override
  String get shuffleSubtitle => 'Desteyi karıştırma';

  @override
  String get shuffleReadingSubtitle => 'Açılımın okunuyor';

  @override
  String get shuffleDrawButton => 'Kart çek';

  @override
  String get resultTitle => 'Okumanız';

  @override
  String get resultStatusAiReading => 'Basil yorumluyor…';

  @override
  String get resultRequestIdUnavailable => 'İstek kimliği kullanılamıyor';

  @override
  String resultRequestIdLabel(Object id) {
    return 'İstek Kimliği: $id';
  }

  @override
  String get resultSnackSaved => 'Okuma kaydedildi.';

  @override
  String get resultSectionArcaneSnapshot => 'Gizemli Anlık Görüntü';

  @override
  String get resultSectionWhy => 'Neden bu okuma';

  @override
  String get resultSectionAction => 'Eylem adımı (sonraki 24-72 saat)';

  @override
  String resultLenormandStep(int step, int total) {
    return 'Lenormand adımı $step / $total';
  }

  @override
  String get resultLenormandBuildsOn => 'Üzerine inşa edilmiştir';

  @override
  String get resultReferralTitle => 'Tavsiye bonusu';

  @override
  String get resultReferralBody =>
      'Kişisel bağlantınızı arkadaşlarınızla paylaşın ve bağlantınızdan katılan her yeni kullanıcı için 20 ücretsiz premium beş kart okuması, 20 uyumluluk testi ve 20 doğum haritası kazanın.';

  @override
  String get resultReferralButton => 'Bağlantıyı paylaş';

  @override
  String get resultReferralCopied =>
      'Yönlendirme bağlantısı kopyalandı. Telegram\'da gönderin.';

  @override
  String get resultReferralShareMessage =>
      'Telegram\'daki gerçek büyüyü keşfedin; aşk, para ve bir sonraki hamleniz için şık Tarot netliği.';

  @override
  String get resultDeepPrompt =>
      'İlişkiler ve kariyer hakkında ayrıntılı bilgi mi istiyorsunuz?';

  @override
  String get resultDeepNotNow => 'Şimdi değil';

  @override
  String get resultDeepShowDetails => 'Evet';

  @override
  String get resultDeepRetryMessage =>
      'Daha derin okumalar kayıp gitti. Tekrar denemek ister misin?';

  @override
  String get resultDeepCancel => 'İptal etmek';

  @override
  String get resultDeepTryAgain => 'Tekrar deneyin';

  @override
  String get resultDeepTypingLabel => 'Kâhin yazıyor…';

  @override
  String get resultDeepRelationshipsHeading => 'İlişkiler';

  @override
  String get resultDeepCareerHeading => 'Kariyer';

  @override
  String cardsDrawnCount(int count) {
    return '$count kez çekildi';
  }

  @override
  String get resultDetailsTitle => 'Detaylar';

  @override
  String get resultSaveButton => 'Okumayı kaydet';

  @override
  String get resultNewButton => 'Yeni okuma';

  @override
  String get resultWantMoreButton => 'Daha fazlası';

  @override
  String get resultStatusUnauthorized =>
      'Hizmet kullanılamıyor; bir süre sonra tekrar deneyin.';

  @override
  String get resultStatusNoInternet =>
      'İnternet yok — çevrimdışı okuma gösteriliyor';

  @override
  String get resultStatusTimeout =>
      'Kâhin durakladı; yeniden denemek için dokunun.';

  @override
  String get resultStatusTooManyAttempts =>
      'Çok fazla deneme yapıldı. Lütfen bekleyin ve tekrar deneyin.';

  @override
  String resultStatusServerUnavailableWithStatus(int status) {
    return 'Kâhin şu anda kullanılamıyor ($status); birazdan tekrar deneyin.';
  }

  @override
  String get resultStatusServerUnavailable =>
      'Kâhin şu anda kullanılamıyor; birazdan tekrar deneyin.';

  @override
  String get resultStatusMissingApiBaseUrl =>
      'Yapılandırma hatası — eksik API temel URL\'si.';

  @override
  String get resultStatusUnexpectedResponse =>
      'Beklenmeyen yanıt — yeniden denemek için dokunun.';

  @override
  String get resultStatusInterpretationUnavailable =>
      'Yapay zeka yorumu kullanılamıyor; yeniden denemek için dokunun.';

  @override
  String get oracleWaitingTitle => 'Kâhin dinliyor…';

  @override
  String get oracleWaitingSubtitle =>
      'Kartlar odağa yerleşene kadar sabit durun.';

  @override
  String get oracleTimeoutTitle => 'Kâhin sessiz…';

  @override
  String get oracleTimeoutBody => 'Bazen netlik bir nefes daha ister.';

  @override
  String get actionCancel => 'İptal';

  @override
  String get actionTryAgain => 'Tekrar dene';

  @override
  String get actionApply => 'Uygula';

  @override
  String get historyTitle => 'Okuma geçmişi';

  @override
  String get historyEmpty => 'Geçmiş şimdilik boş.';

  @override
  String get historyClearButton => 'Geçmişi temizle';

  @override
  String get historyDetailTitle => 'Okuma detayı';

  @override
  String get historyTldrTitle => 'TL;DR';

  @override
  String get queryHistoryTitle => 'Son istemler';

  @override
  String get queryHistoryEmpty => 'Henüz önceki istem yok.';

  @override
  String get queryHistoryLoadError => 'İstem geçmişi yüklenemedi.';

  @override
  String get queryHistoryRetry => 'Yeniden dene';

  @override
  String get offlineFallbackReflection => 'yansıma';

  @override
  String offlineFallbackSummary(Object question, Object keywords) {
    return '“$question” için okuma $keywords üzerinde yoğunlaşır.';
  }

  @override
  String offlineFallbackAdviceLabel(Object advice) {
    return 'Tavsiye: $advice';
  }

  @override
  String get offlineFallbackWhy =>
      'Her pozisyon sorunuzun bir yönünü yansıtır ve kart temaları dikkatin şu anda odaklanabileceği yere uygundur.';

  @override
  String get offlineFallbackAction =>
      'Kartlardaki tavsiyeyi dikkate alan küçük, pratik bir adım seçin.';

  @override
  String get moreFeaturesTitle => 'Daha fazla özellik';

  @override
  String get natalChartTitle => 'Doğum haritası';

  @override
  String get natalChartDescription =>
      'Doğum verilerinize dayalı kişisel astrolojik genel bakış alın.';

  @override
  String get natalChartFreeLabel => 'Ücretsiz';

  @override
  String get natalChartButton => 'İstiyorum';

  @override
  String get natalChartBirthDateLabel => 'Doğum tarihi';

  @override
  String get natalChartBirthDateHint => 'YYYY-MM-DD';

  @override
  String get natalChartBirthDateError => 'Lütfen doğum tarihinizi giriniz.';

  @override
  String get natalChartBirthTimeLabel => 'Doğum saati';

  @override
  String get natalChartBirthTimeHint => 'HH:MM';

  @override
  String get natalChartBirthTimeHelper =>
      'Emin değilseniz 12:00\'ı (öğlen) kullanın.';

  @override
  String get natalChartGenerateButton => 'Oluştur';

  @override
  String get natalChartLoading => 'Doğum haritanız oluşturuluyor…';

  @override
  String get natalChartResultTitle => 'Yorumunuz';

  @override
  String get natalChartError =>
      'Doğum haritası oluşturulamadı. Lütfen tekrar deneyin.';

  @override
  String energyLabelWithPercent(int value) {
    return 'Kâhin enerjisi: %$value';
  }

  @override
  String get energyLabel => 'Kâhin enerjisi';

  @override
  String get energyInfoTooltip =>
      'Enerji eylemlere harcanır ve zamanla yenilenir';

  @override
  String get energyRecoveryReady => 'Tamamen şarj edildi.';

  @override
  String get energyRecoveryLessThanMinute => 'Bir dakikadan kısa sürede doldu.';

  @override
  String energyRecoveryInMinutes(int minutes) {
    return '$minutes dk. içinde doldu.';
  }

  @override
  String energyActionCost(int value) {
    return 'İşlem maliyeti: %$value';
  }

  @override
  String get energyTopUpButton => 'Yükle';

  @override
  String get energyTopUpTitle => 'Gizemli akışınızı besleyin';

  @override
  String get energyTopUpDescription =>
      'Enerjiniz okumayı net ve derin tutar. Ritiminizi seçin ve büyünün içinde kalın.';

  @override
  String get energyTopUpDescriptionCompact =>
      'Enerji eylemlere harcanır ve zamanla iyileşir. Ücretsiz şarjı bekleyebilir veya Yıldızlarla anında artırabilirsiniz.';

  @override
  String get energyCostsTitle => 'Eylem başına enerji maliyeti';

  @override
  String get energyCostReading => 'Tiraj';

  @override
  String get energyCostDeepDetails => 'Derin ayrıntılar';

  @override
  String get energyCostNatalChart => 'Doğum haritası';

  @override
  String get energyCostCompatibility => 'Aşk uyumluluğu';

  @override
  String get energyNextFreeReady => 'Bir sonraki ücretsiz denemeniz hazır.';

  @override
  String energyNextFreeIn(String value) {
    return 'Sonraki ücretsiz deneme tarihi: $value';
  }

  @override
  String get energyPackSmall => '+%25 enerji satın alın';

  @override
  String get energyPackMedium => '+%50 enerji satın alın';

  @override
  String get energyPackFull => '%100\'e kadar yükleme';

  @override
  String get energyPackWeekUnlimited => '1 hafta boyunca sınırsız — 99 ⭐';

  @override
  String get energyPackMonthUnlimited => '1 ay boyunca sınırsız — 499 ⭐';

  @override
  String get energyPackYearUnlimited => '1 yıl boyunca sınırsız — 4999 ⭐';

  @override
  String energyTopUpSuccess(int value) {
    return 'Enerji %$value oranında yenilendi.';
  }

  @override
  String get energyUnlimitedActivated => 'Sınırsız enerji etkinleştirildi.';

  @override
  String get energyTopUpProcessing => 'Ödeme açılıyor...';

  @override
  String get energyTopUpOnlyInTelegram =>
      'Telegram Yıldızları ile yükleme yalnızca Telegram\'da mümkündür.';

  @override
  String get energyTopUpPaymentCancelled => 'Ödeme iptal edildi.';

  @override
  String get energyTopUpPaymentPending => 'Ödeme onayı bekleniyor.';

  @override
  String get energyTopUpPaymentFailed =>
      'Ödeme başarısız oldu. Tekrar deneyin.';

  @override
  String get energyTopUpServiceUnavailable =>
      'Ödeme geçici olarak kullanılamıyor.';

  @override
  String energyInsufficientForAction(int value) {
    return 'Bu işlem için yeterli enerji yok (%$value).';
  }

  @override
  String get professionalReadingTitle => 'Profesyonel okuma';

  @override
  String get professionalReadingDescription =>
      'Açılımının bir uzman tarafından derinlemesine yorumlanması.';

  @override
  String get professionalReadingButton => 'Planı seç';

  @override
  String get professionalReadingOpenBotMessage =>
      'Abonelik planlarını görmek için botu açın.';

  @override
  String get professionalReadingOpenBotAction => 'Botu aç';

  @override
  String get professionalReadingOpenBotSnackbar =>
      'Bir plan seçmek için botu açın.';

  @override
  String get languageFrench => 'Fransızca (FR)';

  @override
  String get languageTurkish => 'Türkçe (TR)';
}
