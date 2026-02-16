import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_user_profile.dart';
import '../../core/utils/date_format.dart';
import '../../data/models/app_enums.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../data/repositories/sofia_consent_repository.dart';
import '../../data/repositories/user_dashboard_repository.dart';
import '../../state/energy_controller.dart';
import '../../state/providers.dart';
import '../../state/settings_controller.dart';
import '../debug/runtime_error_log_screen.dart';
import '../home/home_screen.dart';

const String _settingsBoxName = 'settings';
const String _sofiaConsentKey = 'sofiaConsentDecision';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const routeName = '/settings';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _promoController;
  String? _promoFeedback;
  UserDashboardData? _dashboard;
  bool _loadingDashboard = false;
  String? _dashboardError;

  @override
  void initState() {
    super.initState();
    _promoController = TextEditingController();
    _loadDashboard();
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settingsBox = Hive.box<String>(_settingsBoxName);
    final hasSofiaConsent =
        (settingsBox.get(_sofiaConsentKey) ?? '').isNotEmpty;
    final settingsState = ref.watch(settingsControllerProvider);
    final energyState = ref.watch(energyProvider);
    final settingsController = ref.read(settingsControllerProvider.notifier);
    final cards =
        ref.watch(cardsAllProvider).asData?.value ?? const <CardModel>[];
    final telegramProfile = readTelegramUserProfile();
    final displayProfile = _dashboard?.profile;
    final userInitials = _resolveInitials(displayProfile, telegramProfile);
    final userPhoto =
        (displayProfile?.photoUrl ?? telegramProfile?.photoUrl ?? '').trim();
    final referralLink = (_dashboard?.referralLink ?? '').trim().isNotEmpty
        ? _dashboard!.referralLink
        : (telegramProfile != null
            ? buildReferralLinkForUserId(telegramProfile.userId)
            : 'https://t.me/tarot_arkana_bot/app');
    final isDirty = settingsState.isDirty;
    final bottomPadding = isDirty ? 120.0 : 32.0;
    return Scaffold(
      appBar: buildTopBar(
        context,
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPress: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const RuntimeErrorLogScreen(),
              ),
            );
          },
          child: Text(l10n.settingsTitle),
        ),
        showBack: true,
      ),
      bottomNavigationBar: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: isDirty
            ? SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: AppPrimaryButton(
                    label: l10n.actionApply,
                    onPressed: () async {
                      await settingsController.apply();
                      if (!context.mounted) {
                        return;
                      }
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          settings: appRouteSettings(showBackButton: false),
                          builder: (_) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomPadding),
          children: [
            _buildDashboardCard(
              context: context,
              l10n: l10n,
              photoUrl: userPhoto,
              initials: userInitials,
              referralLink: referralLink,
              energyState: energyState,
            ),
            const SizedBox(height: 20),
            Text(
              l10n.languageLabel,
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 8),
            _LanguageOption(
              label: l10n.languageEnglish,
              language: AppLanguage.en,
              groupValue: settingsState.language,
              onSelected: (value) {
                settingsController.updateLanguage(value);
              },
            ),
            _LanguageOption(
              label: l10n.languageRussian,
              language: AppLanguage.ru,
              groupValue: settingsState.language,
              onSelected: (value) {
                settingsController.updateLanguage(value);
              },
            ),
            _LanguageOption(
              label: l10n.languageKazakh,
              language: AppLanguage.kz,
              groupValue: settingsState.language,
              onSelected: (value) {
                settingsController.updateLanguage(value);
              },
            ),
            const SizedBox(height: 20),
            Text(
              l10n.deckLabel,
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 8),
            _DeckOption(
              label: l10n.deckTarotRiderWaite,
              deckType: DeckType.all,
              previewUrl: _previewImageUrl(cards, DeckType.all),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckLenormand,
              deckType: DeckType.lenormand,
              previewUrl: _previewImageUrl(cards, DeckType.lenormand),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            _DeckOption(
              label: l10n.deckCrowley,
              deckType: DeckType.crowley,
              previewUrl: _previewImageUrl(cards, DeckType.crowley),
              groupValue: settingsState.deckType,
              onSelected: (value) {
                settingsController.updateDeck(value);
              },
            ),
            const SizedBox(height: 20),
            Text(
              l10n.settingsPromoTitle,
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.settingsPromoDescription,
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _promoController,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: l10n.settingsPromoHint,
                suffixIcon: energyState.promoCodeActive
                    ? const Icon(Icons.verified_rounded)
                    : const Icon(Icons.sell_outlined),
              ),
            ),
            const SizedBox(height: 10),
            AppPrimaryButton(
              label: l10n.settingsPromoApplyButton,
              onPressed: () async {
                final ok = await ref
                    .read(energyProvider.notifier)
                    .applyPromoCode(_promoController.text);
                if (!mounted) {
                  return;
                }
                setState(() {
                  _promoFeedback = ok
                      ? l10n.settingsPromoApplied
                      : l10n.settingsPromoInvalid;
                });
                if (ok) {
                  _promoController.clear();
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(_promoFeedback!)),
                );
              },
            ),
            if (energyState.promoCodeActive) ...[
              const SizedBox(height: 10),
              AppGhostButton(
                label: l10n.settingsPromoResetButton,
                onPressed: () async {
                  await ref
                      .read(energyProvider.notifier)
                      .clearPromoCodeAccess();
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _promoFeedback = l10n.settingsPromoResetDone;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(_promoFeedback!)),
                  );
                },
              ),
            ],
            if (_promoFeedback != null) ...[
              const SizedBox(height: 8),
              Text(
                _promoFeedback!,
                style: AppTextStyles.caption(context),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              _privacySectionTitle(context),
              style: AppTextStyles.subtitle(context),
            ),
            const SizedBox(height: 8),
            Text(
              _privacySectionHint(context),
              style: AppTextStyles.caption(context),
            ),
            const SizedBox(height: 10),
            AppGhostButton(
              label: _revokeConsentLabel(context),
              onPressed: hasSofiaConsent
                  ? () async {
                      try {
                        await ref
                            .read(sofiaConsentRepositoryProvider)
                            .submitDecision(SofiaConsentDecision.revoked);
                      } catch (_) {
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(_revokeConsentError(context))),
                        );
                        return;
                      }
                      final box = Hive.box<String>(_settingsBoxName);
                      await box.delete(_sofiaConsentKey);
                      if (!mounted) {
                        return;
                      }
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(_revokeConsentDone(context))),
                      );
                    }
                  : null,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: const Icon(Icons.bug_report_outlined),
                title: Text(l10n.deckDebugLogLabel),
                onTap: () {
                  final path = _previewImageUrl(cards, DeckType.wands) ?? '—';
                  debugPrint('Wands sample image: $path');
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadDashboard() async {
    if (_loadingDashboard) {
      return;
    }
    setState(() {
      _loadingDashboard = true;
      _dashboardError = null;
    });
    try {
      final data =
          await ref.read(userDashboardRepositoryProvider).fetchDashboard();
      if (!mounted) {
        return;
      }
      setState(() {
        _dashboard = data;
        _loadingDashboard = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingDashboard = false;
        _dashboardError = 'failed';
      });
    }
  }

  String _resolveInitials(
    UserDashboardProfile? dashboardProfile,
    TelegramUserProfile? telegramProfile,
  ) {
    final first =
        (dashboardProfile?.firstName ?? telegramProfile?.firstName ?? '')
            .trim();
    final last =
        (dashboardProfile?.lastName ?? telegramProfile?.lastName ?? '').trim();
    final username =
        (dashboardProfile?.username ?? telegramProfile?.username ?? '').trim();
    if (first.isNotEmpty && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first.isNotEmpty) {
      return first.substring(0, first.length >= 2 ? 2 : 1).toUpperCase();
    }
    if (username.isNotEmpty) {
      final raw = username.startsWith('@') ? username.substring(1) : username;
      return raw.substring(0, raw.length >= 2 ? 2 : 1).toUpperCase();
    }
    return 'BA';
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required AppLocalizations l10n,
    required String photoUrl,
    required String initials,
    required String referralLink,
    required EnergyState energyState,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final sectionTitleStyle = textTheme.bodyLarge?.copyWith(
      fontWeight: FontWeight.w600,
      color: colorScheme.onSurface.withOpacity(0.92),
    );
    final sectionValueStyle = textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurface,
    );
    final sectionDetailStyle = textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w500,
      color: colorScheme.onSurfaceVariant,
    );
    final recoveryLabel = energyState.isUnlimited
        ? l10n.energyUnlimitedActivated
        : energyState.clampedValue >= 100
            ? l10n.energyRecoveryReady
            : energyState.timeToFull.inMinutes <= 0
                ? l10n.energyRecoveryLessThanMinute
                : l10n
                    .energyRecoveryInMinutes(energyState.timeToFull.inMinutes);
    final freeFiveCardCredits = _dashboard?.freeFiveCardsCredits ?? 0;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: colorScheme.surfaceContainerHighest.withOpacity(0.28),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.42)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SettingsAvatar(photoUrl: photoUrl, initials: initials),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.settingsDashboardTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (_loadingDashboard)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _DashboardSectionTitle(
            title: _dashboardEnergyTitle(context),
            style: sectionTitleStyle,
          ),
          const SizedBox(height: 6),
          Text(
            energyState.isUnlimited ? '∞' : '${energyState.percent}%',
            style: sectionValueStyle,
          ),
          const SizedBox(height: 2),
          Text(
            recoveryLabel,
            style: sectionDetailStyle,
          ),
          const SizedBox(height: 12),
          _DashboardSectionTitle(
            title: _dashboardPaidSubscriptionsTitle(context),
            style: sectionTitleStyle,
          ),
          const SizedBox(height: 6),
          if ((_dashboard?.services ?? const <UserDashboardService>[]).isEmpty)
            Text(
              l10n.settingsDashboardServicesEmpty,
              style: sectionDetailStyle,
            )
          else
            for (final service in _dashboard!.services)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  _serviceLabel(context, service),
                  style: sectionDetailStyle,
                ),
              ),
          const SizedBox(height: 12),
          _DashboardSectionTitle(
            title: _dashboardReferralBonusesTitle(context),
            style: sectionTitleStyle,
          ),
          const SizedBox(height: 6),
          Text(
            _dashboardFiveCardsBonusLine(context, freeFiveCardCredits),
            style: sectionDetailStyle,
          ),
          const SizedBox(height: 2),
          Text(
            _dashboardNatalBonusLine(context, freeFiveCardCredits),
            style: sectionDetailStyle,
          ),
          const SizedBox(height: 14),
          AppGhostButton(
            label: l10n.settingsDashboardShareButton,
            icon: Icons.ios_share,
            onPressed: () async {
              final text = '${l10n.resultReferralShareMessage}\n$referralLink';
              await Clipboard.setData(ClipboardData(text: text));
              if (!mounted) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.resultReferralCopied)),
              );
              final shareUri = Uri.parse(
                'https://t.me/share/url?url=${Uri.encodeComponent(referralLink)}'
                '&text=${Uri.encodeComponent(l10n.resultReferralShareMessage)}',
              );
              await launchUrl(shareUri, mode: LaunchMode.externalApplication);
            },
          ),
          if (_dashboardError != null) ...[
            const SizedBox(height: 8),
            Text(
              l10n.settingsDashboardLoadError,
              style: AppTextStyles.caption(context),
            ),
          ],
        ],
      ),
    );
  }

  String _serviceLabel(BuildContext context, UserDashboardService service) {
    final l10n = AppLocalizations.of(context);
    if (service.type == 'year_unlimited' || service.type == 'unlimited') {
      if (service.expiresAt == null) {
        return l10n.settingsDashboardServiceUnlimitedNoDate;
      }
      return l10n.settingsDashboardServiceUnlimitedWithDate(
        formatDateTime(service.expiresAt!,
            locale: Localizations.localeOf(context).languageCode),
      );
    }
    return service.id;
  }

  String _dashboardEnergyTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Энергия сейчас';
    }
    if (code == 'kk') {
      return 'Қазіргі энергия';
    }
    return 'Current energy';
  }

  String _dashboardPaidSubscriptionsTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Платные подписки';
    }
    if (code == 'kk') {
      return 'Ақылы жазылымдар';
    }
    return 'Paid subscriptions';
  }

  String _dashboardReferralBonusesTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Бонусы за приглашения';
    }
    if (code == 'kk') {
      return 'Шақыру үшін бонустар';
    }
    return 'Referral bonuses';
  }

  String _dashboardFiveCardsBonusLine(BuildContext context, int count) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Премиальный расклад на 5 карт: $count';
    }
    if (code == 'kk') {
      return '5 картаға премиум ашылым: $count';
    }
    return 'Premium five-card spread: $count';
  }

  String _dashboardNatalBonusLine(BuildContext context, int count) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Натальная карта и совместимость: $count';
    }
    if (code == 'kk') {
      return 'Натал карта және үйлесімділік: $count';
    }
    return 'Natal chart and compatibility: $count';
  }

  String _revokeConsentLabel(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Отозвать согласие для Софии';
    }
    if (code == 'kk') {
      return 'София үшін келісімді қайтарып алу';
    }
    return 'Withdraw Sofia consent';
  }

  String _revokeConsentDone(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Согласие отозвано. На главном экране снова появится запрос.';
    }
    if (code == 'kk') {
      return 'Келісім қайтарылды. Басты экранда сұрау қайта көрсетіледі.';
    }
    return 'Consent withdrawn. The request will appear again on Home.';
  }

  String _privacySectionTitle(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Приватность';
    }
    if (code == 'kk') {
      return 'Құпиялық';
    }
    return 'Privacy';
  }

  String _privacySectionHint(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Если передумаешь, здесь можно сбросить согласие на передачу имени и username.';
    }
    if (code == 'kk') {
      return 'Егер ойың өзгерсе, осында ат пен username жіберуге берілген келісімді өшіре аласың.';
    }
    return 'If you change your mind, reset consent for sharing name and username here.';
  }

  String _revokeConsentError(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return 'Не получилось отправить отзыв согласия. Попробуй еще раз.';
    }
    if (code == 'kk') {
      return 'Келісімді қайтарып алу жіберілмеді. Қайтадан көр.';
    }
    return 'Could not submit consent withdrawal. Please try again.';
  }
}

class _DashboardSectionTitle extends StatelessWidget {
  const _DashboardSectionTitle({
    required this.title,
    this.style,
  });

  final String title;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: style,
    );
  }
}

class _SettingsAvatar extends StatelessWidget {
  const _SettingsAvatar({
    required this.photoUrl,
    required this.initials,
  });

  final String photoUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _avatarFallback(context);
          },
        ),
      );
    }
    return _avatarFallback(context);
  }

  Widget _avatarFallback(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF8F4BFF),
        borderRadius: BorderRadius.circular(999),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DeckOption extends StatelessWidget {
  const _DeckOption({
    required this.label,
    required this.deckType,
    required this.previewUrl,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final DeckType deckType;
  final String? previewUrl;
  final DeckType groupValue;
  final ValueChanged<DeckType> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = deckType == groupValue;
    return Card(
      color: isSelected ? colorScheme.primary.withOpacity(0.12) : null,
      child: RadioListTile<DeckType>(
        value: deckType,
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) {
            onSelected(value);
          }
        },
        title: Text(label),
        secondary: _DeckPreviewThumbnail(imageUrl: previewUrl),
      ),
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.language,
    required this.groupValue,
    required this.onSelected,
  });

  final String label;
  final AppLanguage language;
  final AppLanguage groupValue;
  final ValueChanged<AppLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = language == groupValue;
    return Card(
      color: isSelected ? colorScheme.primary.withOpacity(0.12) : null,
      child: RadioListTile<AppLanguage>(
        value: language,
        groupValue: groupValue,
        onChanged: (value) {
          if (value != null) {
            onSelected(value);
          }
        },
        title: Text(label),
      ),
    );
  }
}

class _DeckPreviewThumbnail extends StatelessWidget {
  const _DeckPreviewThumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const width = 36.0;
    const height = 54.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: imageUrl == null || imageUrl!.isEmpty
          ? Container(
              width: width,
              height: height,
              color: Theme.of(context).colorScheme.surfaceVariant,
              alignment: Alignment.center,
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 16,
              ),
            )
          : Image.network(
              imageUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return const SizedBox(
                  width: width,
                  height: height,
                  child: Center(
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: width,
                  height: height,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_outlined,
                    size: 16,
                  ),
                );
              },
            ),
    );
  }
}

String? _previewImageUrl(List<CardModel> cards, DeckType deckId) {
  if (cards.isEmpty) {
    return null;
  }
  String previewId;
  switch (deckId) {
    case DeckType.wands:
      previewId = wandsCardIds.first;
    case DeckType.swords:
      previewId = swordsCardIds.first;
    case DeckType.pentacles:
      previewId = pentaclesCardIds.first;
    case DeckType.cups:
      previewId = cupsCardIds.first;
    case DeckType.lenormand:
      previewId = lenormandCardIds.first;
    case DeckType.crowley:
      previewId = crowleyCardIds.first;
    case DeckType.major:
    case DeckType.all:
      previewId = majorCardIds.first;
  }
  final normalizedId = canonicalCardId(previewId);
  for (final card in cards) {
    if (card.id == normalizedId) {
      return card.imageUrl;
    }
  }
  return cards.first.imageUrl;
}
