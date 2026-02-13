import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/telegram/telegram_bridge.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/data_load_error.dart';
import '../../data/repositories/energy_topup_repository.dart';
import '../settings/settings_screen.dart';
import '../../data/models/app_enums.dart';
import '../../data/models/deck_model.dart';
import '../../data/models/spread_model.dart';
import '../../state/providers.dart';
import '../shuffle/shuffle_screen.dart';

class SpreadScreen extends ConsumerWidget {
  const SpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spreadsAsync = ref.watch(spreadsProvider);
    final deckId = ref.watch(deckProvider);
    final l10n = AppLocalizations.of(context)!;
    final spreadCopy = _resolveSpreadCopy(l10n: l10n, deckId: deckId);

    return Scaffold(
      appBar: buildEnergyTopBar(
        context,
        showBack: true,
        onSettings: () {
          Navigator.pushNamed(
            context,
            SettingsScreen.routeName,
            arguments: const AppRouteConfig(showBackButton: true),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: spreadsAsync.when(
          data: (spreads) {
            final oneCardSpread = _resolveSpreadByType(
              spreads,
              SpreadType.one,
              l10n: l10n,
            );
            final threeCardSpread = _resolveSpreadByType(
              spreads,
              SpreadType.three,
              l10n: l10n,
            );
            final fiveCardSpread = _resolveSpreadByType(
              spreads,
              SpreadType.five,
              l10n: l10n,
            );

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (oneCardSpread != null)
                    Expanded(
                      child: _SpreadOptionCard(
                        spread: oneCardSpread,
                        spreadType: SpreadType.one,
                        title: spreadCopy.oneTitle,
                        subtitle: spreadCopy.oneSubtitle,
                        animation:
                            const SpreadIconDeck(mode: SpreadIconMode.oneCard),
                      ),
                    ),
                  if (oneCardSpread != null && threeCardSpread != null)
                    const SizedBox(height: 18),
                  if (threeCardSpread != null)
                    Expanded(
                      child: _SpreadOptionCard(
                        spread: threeCardSpread,
                        spreadType: SpreadType.three,
                        title: spreadCopy.threeTitle,
                        subtitle: spreadCopy.threeSubtitle,
                        animation: const SpreadIconDeck(
                          mode: SpreadIconMode.threeCards,
                        ),
                      ),
                    ),
                  if (threeCardSpread != null && fiveCardSpread != null)
                    const SizedBox(height: 18),
                  if (fiveCardSpread != null)
                    Expanded(
                      child: _SpreadOptionCard(
                        spread: fiveCardSpread,
                        spreadType: SpreadType.five,
                        title: spreadCopy.fiveTitle,
                        subtitle: spreadCopy.fiveSubtitle,
                        animation: const SpreadIconDeck(
                          mode: SpreadIconMode.fiveCards,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            final repo = ref.read(spreadsRepositoryProvider);
            final locale = ref.read(localeProvider);
            final cacheKey = repo.spreadsCacheKey(locale);
            DevFailureInfo? failureInfo;
            if (kEnableDevDiagnostics) {
              failureInfo = buildDevFailureInfo(
                FailedStage.spreadsLocalLoad,
                error,
              );
              logDevFailure(failureInfo);
            }
            final debugInfo = kEnableDevDiagnostics
                ? DataLoadDebugInfo(
                    assetsBaseUrl: AssetsConfig.assetsBaseUrl,
                    requests: {
                      'spreads (${repo.spreadsFileNameForLocale(locale)})':
                          DataLoadRequestDebugInfo(
                        url: repo.lastAttemptedUrls[cacheKey] ?? '—',
                        statusCode: repo.lastStatusCodes[cacheKey],
                        contentType: repo.lastContentTypes[cacheKey],
                        contentLength: repo.lastContentLengths[cacheKey],
                        responseSnippetStart:
                            repo.lastResponseSnippetsStart[cacheKey],
                        responseSnippetEnd:
                            repo.lastResponseSnippetsEnd[cacheKey],
                        responseLength:
                            repo.lastResponseStringLengths[cacheKey],
                        bytesLength: repo.lastResponseByteLengths[cacheKey],
                        rootType: repo.lastResponseRootTypes[cacheKey],
                      ),
                    },
                    failedStage: failureInfo?.failedStage,
                    exceptionSummary: failureInfo?.summary,
                  )
                : null;
            return Center(
              child: DataLoadError(
                title: l10n.dataLoadTitle,
                message: l10n.dataLoadSpreadsError,
                retryLabel: l10n.dataLoadRetry,
                onRetry: () {
                  ref.invalidate(spreadsProvider);
                },
                debugInfo: debugInfo,
              ),
            );
          },
        ),
      ),
    );
  }
}

SpreadModel? _findSpread(
  List<SpreadModel> spreads,
  int count,
) {
  for (final spread in spreads) {
    final cardsCount = spread.cardsCount ?? spread.positions.length;
    if (cardsCount == count) {
      return spread;
    }
  }
  return null;
}

class _SpreadOptionCard extends ConsumerStatefulWidget {
  const _SpreadOptionCard({
    required this.spread,
    required this.spreadType,
    required this.title,
    required this.subtitle,
    required this.animation,
  });

  final SpreadModel spread;
  final SpreadType spreadType;
  final String title;
  final String subtitle;
  final Widget animation;

  @override
  ConsumerState<_SpreadOptionCard> createState() => _SpreadOptionCardState();
}

class _SpreadOptionCardState extends ConsumerState<_SpreadOptionCard> {
  bool _isUnlocking = false;

  Future<void> _openSpread() async {
    ref
        .read(readingFlowControllerProvider.notifier)
        .selectSpread(widget.spread, widget.spreadType);
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: true),
        builder: (_) => const ShuffleScreen(),
      ),
    );
  }

  Future<void> _handleTap() async {
    if (_isUnlocking) {
      return;
    }
    if (widget.spreadType != SpreadType.five) {
      await _openSpread();
      return;
    }

    final energy = ref.read(energyProvider);
    final hasPremiumAccess = energy.isUnlimited || energy.promoCodeActive;
    if (hasPremiumAccess) {
      await _openSpread();
      return;
    }

    try {
      final consumeResult = await ref
          .read(userDashboardRepositoryProvider)
          .consumeFreeFiveCardsCredit();
      if (consumeResult.consumed) {
        if (!mounted) {
          return;
        }
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.settingsDashboardFreePremiumRemaining(
                  consumeResult.remaining),
            ),
          ),
        );
        await _openSpread();
        return;
      }
    } catch (_) {}

    setState(() {
      _isUnlocking = true;
    });
    final unlocked = await _showFiveCardsPremiumModal(context, ref);
    if (!mounted) {
      return;
    }
    setState(() {
      _isUnlocking = false;
    });
    if (unlocked) {
      await _openSpread();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isFiveCardsPremium = widget.spreadType == SpreadType.five;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: _handleTap,
      child: Ink(
        decoration: BoxDecoration(
          gradient: isFiveCardsPremium
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF23212A),
                    Color(0xFF302A39),
                    Color(0xFF3F2E52),
                  ],
                )
              : null,
          color: isFiveCardsPremium ? null : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: isFiveCardsPremium
                ? const Color(0xFFB987F9).withOpacity(0.62)
                : primary.withOpacity(0.32),
            width: isFiveCardsPremium ? 1.2 : 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: isFiveCardsPremium
                  ? const Color(0xFF9A67F2).withOpacity(0.24)
                  : primary.withOpacity(0.14),
              blurRadius: isFiveCardsPremium ? 24 : 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: isFiveCardsPremium
                      ? MainAxisAlignment.start
                      : MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.title(context)
                          .copyWith(color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      maxLines: isFiveCardsPremium ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(context).copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        height: 1.35,
                      ),
                    ),
                    if (isFiveCardsPremium) ...[
                      const Spacer(),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF9B5CFF).withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: const Color(0xFFB987F9).withOpacity(0.65),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          _FiveCardsPremiumCopy.resolve(context).premiumTag,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFFDCC3FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                height: 140,
                child: widget.animation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> _showFiveCardsPremiumModal(
    BuildContext context, WidgetRef ref) async {
  final copy = _FiveCardsPremiumCopy.resolve(context);
  final l10n = AppLocalizations.of(context)!;
  final granted = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      var processing = false;
      return StatefulBuilder(
        builder: (statefulContext, setState) {
          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(sheetContext)
                            .colorScheme
                            .outlineVariant
                            .withOpacity(0.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          copy.title,
                          style: Theme.of(sheetContext).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        onPressed: processing
                            ? null
                            : () => Navigator.of(sheetContext).pop(false),
                        icon: const Icon(Icons.close),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    copy.body,
                    style: Theme.of(sheetContext).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    copy.scope,
                    style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                          color: Theme.of(sheetContext)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.72),
                        ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: processing
                          ? null
                          : () async {
                              setState(() {
                                processing = true;
                              });
                              final ok = await _purchaseFiveCardsAccess(
                                context: context,
                                ref: ref,
                                l10n: l10n,
                              );
                              if (!statefulContext.mounted) {
                                return;
                              }
                              setState(() {
                                processing = false;
                              });
                              if (ok) {
                                Navigator.of(sheetContext).pop(true);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        backgroundColor:
                            Theme.of(sheetContext).colorScheme.primary,
                        foregroundColor:
                            Theme.of(sheetContext).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              copy.buyButton,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(sheetContext)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '1 ⭐',
                            style: Theme.of(sheetContext)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
  return granted == true;
}

Future<bool> _purchaseFiveCardsAccess({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l10n,
}) async {
  if (!TelegramBridge.isAvailable) {
    if (!context.mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.energyTopUpOnlyInTelegram)),
    );
    return false;
  }
  try {
    final topUpRepo = ref.read(energyTopUpRepositoryProvider);
    final invoice = await topUpRepo.createInvoice(EnergyPackId.fiveCardsSingle);
    final status = await TelegramBridge.openInvoice(invoice.invoiceLink);
    try {
      await topUpRepo.confirmInvoiceResult(
        payload: invoice.payload,
        status: status,
      );
    } catch (_) {}
    if (!context.mounted) {
      return false;
    }
    switch (status) {
      case 'paid':
        return true;
      case 'cancelled':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpPaymentCancelled)),
        );
        return false;
      case 'pending':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpPaymentPending)),
        );
        return false;
      case 'failed':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpPaymentFailed)),
        );
        return false;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
        );
        return false;
    }
  } on EnergyTopUpRepositoryException {
    if (!context.mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
    );
    return false;
  } catch (_) {
    if (!context.mounted) {
      return false;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.energyTopUpServiceUnavailable)),
    );
    return false;
  }
}

class _FiveCardsPremiumCopy {
  const _FiveCardsPremiumCopy({
    required this.title,
    required this.body,
    required this.scope,
    required this.buyButton,
    required this.premiumTag,
  });

  final String title;
  final String body;
  final String scope;
  final String buyButton;
  final String premiumTag;

  static _FiveCardsPremiumCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _FiveCardsPremiumCopy(
        title: 'Премиум расклад на 5 карт',
        body:
            'Этот расклад открывает глубинный слой истории: пять позиций показывают скрытые причины, баланс сил и лучший вектор действий.',
        scope:
            'Для владельцев безлимитной подписки на 1 год и пользователей с промокодом LUCY100 доступ открыт. Разовый доступ: 1⭐ за расклад.',
        buyButton: 'Купить доступ',
        premiumTag: 'Премиум',
      );
    }
    if (code == 'kk') {
      return const _FiveCardsPremiumCopy(
        title: '5 картаға премиум жайылма',
        body:
            'Бұл формат жағдайды терең ашады: бес позиция жасырын себептерді, күштердің тепе-теңдігін және ең дәл келесі қадамды көрсетеді.',
        scope:
            '1 жылдық шексіз жазылымы бар немесе LUCY100 промокодын енгізгендерге ашық. Бір реттік кіру: 1⭐.',
        buyButton: 'Қолжетімділікті сатып алу',
        premiumTag: 'Премиум',
      );
    }
    return const _FiveCardsPremiumCopy(
      title: 'Premium five-card spread',
      body:
          'This spread opens a deeper layer of your story: five positions reveal hidden causes, the balance of forces, and your most practical next move.',
      scope:
          'Included in the 1-year unlimited plan and available to users with promo code LUCY100. Single access costs 1⭐ per spread.',
      buyButton: 'Buy access',
      premiumTag: 'Premium',
    );
  }
}

class _SpreadCopy {
  const _SpreadCopy({
    required this.oneTitle,
    required this.oneSubtitle,
    required this.threeTitle,
    required this.threeSubtitle,
    required this.fiveTitle,
    required this.fiveSubtitle,
  });

  final String oneTitle;
  final String oneSubtitle;
  final String threeTitle;
  final String threeSubtitle;
  final String fiveTitle;
  final String fiveSubtitle;
}

_SpreadCopy _resolveSpreadCopy({
  required AppLocalizations l10n,
  required DeckType deckId,
}) {
  if (deckId == DeckType.lenormand) {
    return _SpreadCopy(
      oneTitle: l10n.spreadOneCardTitle,
      oneSubtitle: l10n.spreadLenormandOneCardSubtitle,
      threeTitle: l10n.spreadThreeCardTitle,
      threeSubtitle: l10n.spreadLenormandThreeCardSubtitle,
      fiveTitle: l10n.spreadFiveCardTitle,
      fiveSubtitle: l10n.spreadLenormandFiveCardSubtitle,
    );
  }
  return _SpreadCopy(
    oneTitle: l10n.spreadOneCardTitle,
    oneSubtitle: l10n.spreadOneCardSubtitle,
    threeTitle: l10n.spreadThreeCardTitle,
    threeSubtitle: l10n.spreadThreeCardSubtitle,
    fiveTitle: l10n.spreadFiveCardTitle,
    fiveSubtitle: l10n.spreadFiveCardSubtitle,
  );
}

SpreadModel? _resolveSpreadByType(
  List<SpreadModel> spreads,
  SpreadType spreadType, {
  required AppLocalizations l10n,
}) {
  final desiredCount = spreadType.cardCount;
  final directMatch = _findSpread(spreads, desiredCount);
  if (directMatch != null) {
    return directMatch;
  }
  if (spreads.isEmpty) {
    return null;
  }
  final fallback = spreads.first;
  final fallbackPositions = <SpreadPosition>[];
  if (fallback.positions.isNotEmpty) {
    fallbackPositions.addAll(fallback.positions.take(desiredCount));
  }
  while (fallbackPositions.length < desiredCount) {
    final idx = fallbackPositions.length + 1;
    final defaultTitle = spreadType == SpreadType.five
        ? switch (idx) {
            1 => l10n.spreadFivePosition1,
            2 => l10n.spreadFivePosition2,
            3 => l10n.spreadFivePosition3,
            4 => l10n.spreadFivePosition4,
            _ => l10n.spreadFivePosition5,
          }
        : 'Card $idx';
    fallbackPositions.add(
      SpreadPosition(
        id: 'slot_$idx',
        title: defaultTitle,
      ),
    );
  }
  final fallbackName = switch (spreadType) {
    SpreadType.one => l10n.spreadOneCardTitle,
    SpreadType.three => l10n.spreadThreeCardTitle,
    SpreadType.five => l10n.spreadFiveCardTitle,
  };
  return SpreadModel(
    id: switch (spreadType) {
      SpreadType.one => 'one_card',
      SpreadType.three => 'three_card',
      SpreadType.five => 'five_card',
    },
    name: fallback.name.trim().isEmpty ? fallbackName : fallback.name,
    positions: fallbackPositions,
    cardsCount: desiredCount,
  );
}

enum SpreadIconMode { oneCard, threeCards, fiveCards }

class SpreadIconDeck extends StatefulWidget {
  const SpreadIconDeck({
    super.key,
    required this.mode,
  });

  final SpreadIconMode mode;

  @override
  State<SpreadIconDeck> createState() => _SpreadIconDeckState();
}

class _SpreadIconDeckState extends State<SpreadIconDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _progress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final deckColor = _shiftLightness(primary, -0.22).withOpacity(0.96);
    final deckHighlight = _shiftLightness(primary, -0.05).withOpacity(0.9);
    final deckBorder = _shiftLightness(primary, 0.2).withOpacity(0.85);
    final cardColor = _shiftLightness(primary, -0.12).withOpacity(0.95);
    final cardHighlight = _shiftLightness(primary, 0.05).withOpacity(0.92);
    final cardBorder = _shiftLightness(primary, 0.28).withOpacity(0.9);
    final shadow = primary.withOpacity(0.28);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cardWidth = size.width * 0.48;
        final cardHeight = size.height * 0.68;
        final center = Offset(size.width * 0.5, size.height * 0.54);
        return AnimatedBuilder(
          animation: _progress,
          builder: (context, child) {
            final pullY = lerpDouble(-14, -6, _progress.value) ?? 0;
            final pullX = lerpDouble(6, 10, _progress.value) ?? 0;
            final fanProgress = _progress.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                _CardShape(
                  width: cardWidth,
                  height: cardHeight,
                  gradient: LinearGradient(
                    colors: [deckColor, deckHighlight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: deckBorder,
                  shadowColor: shadow,
                  offset: center + const Offset(0, 10),
                  rotation: -0.02,
                ),
                _CardShape(
                  width: cardWidth,
                  height: cardHeight,
                  gradient: LinearGradient(
                    colors: [deckColor, deckHighlight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: deckBorder,
                  shadowColor: shadow,
                  offset: center + const Offset(-8, 4),
                  rotation: 0.02,
                ),
                if (widget.mode != SpreadIconMode.oneCard)
                  _CardShape(
                    width: cardWidth,
                    height: cardHeight,
                    gradient: LinearGradient(
                      colors: [cardColor, cardHighlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    offset:
                        center + Offset(-14 * fanProgress, -14 * fanProgress),
                    rotation: -0.14 * fanProgress,
                  ),
                if (widget.mode != SpreadIconMode.oneCard)
                  _CardShape(
                    width: cardWidth,
                    height: cardHeight,
                    gradient: LinearGradient(
                      colors: [cardColor, cardHighlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    offset: center + Offset(0, -10 * fanProgress),
                    rotation: 0,
                  ),
                _CardShape(
                  width: cardWidth,
                  height: cardHeight,
                  gradient: LinearGradient(
                    colors: [cardColor, cardHighlight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderColor: cardBorder,
                  shadowColor: shadow,
                  offset: widget.mode == SpreadIconMode.oneCard
                      ? center + Offset(pullX, pullY)
                      : center + Offset(14 * fanProgress, -12 * fanProgress),
                  rotation: widget.mode == SpreadIconMode.oneCard
                      ? 0.05
                      : 0.14 * fanProgress,
                ),
                if (widget.mode == SpreadIconMode.fiveCards)
                  _CardShape(
                    width: cardWidth,
                    height: cardHeight,
                    gradient: LinearGradient(
                      colors: [cardColor, cardHighlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    offset:
                        center + Offset(-26 * fanProgress, -6 * fanProgress),
                    rotation: -0.22 * fanProgress,
                  ),
                if (widget.mode == SpreadIconMode.fiveCards)
                  _CardShape(
                    width: cardWidth,
                    height: cardHeight,
                    gradient: LinearGradient(
                      colors: [cardColor, cardHighlight],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderColor: cardBorder,
                    shadowColor: shadow,
                    offset: center + Offset(28 * fanProgress, -4 * fanProgress),
                    rotation: 0.22 * fanProgress,
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _CardShape extends StatelessWidget {
  const _CardShape({
    required this.width,
    required this.height,
    required this.gradient,
    required this.borderColor,
    required this.shadowColor,
    required this.offset,
    required this.rotation,
  });

  final double width;
  final double height;
  final Gradient gradient;
  final Color borderColor;
  final Color shadowColor;
  final Offset offset;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx - width / 2,
      top: offset.dy - height / 2,
      child: Transform.rotate(
        angle: rotation,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor, width: 1.6),
            boxShadow: [
              BoxShadow(
                color: shadowColor,
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _shiftLightness(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
  return hsl.withLightness(lightness).toColor();
}
