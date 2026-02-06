import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/widgets/data_load_error.dart';
import '../../data/models/spread_model.dart';
import '../../state/providers.dart';
import '../shuffle/shuffle_screen.dart';

class SpreadScreen extends ConsumerWidget {
  const SpreadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spreadsAsync = ref.watch(spreadsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.spreadTitle),
        leading: Navigator.canPop(context) ? const BackButton() : null,
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: SafeArea(
        top: false,
        child: spreadsAsync.when(
          data: (spreads) {
            final oneCardSpread = _findSpread(spreads, 1);
            final threeCardSpread = _findSpread(spreads, 3, fallbackIndex: 1);

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (oneCardSpread != null)
                    Expanded(
                      child: _SpreadOptionCard(
                        spread: oneCardSpread,
                        title: l10n.spreadOneCardTitle,
                        subtitle: l10n.spreadOneCardSubtitle,
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
                        title: l10n.spreadThreeCardTitle,
                        subtitle: l10n.spreadThreeCardSubtitle,
                        animation: const SpreadIconDeck(
                          mode: SpreadIconMode.threeCards,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            final repo = ref.read(dataRepositoryProvider);
            final locale = ref.read(localeProvider);
            final cacheKey = repo.spreadsCacheKey(locale);
            final debugInfo = kShowDiagnostics
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
                        responseLength: repo.lastResponseStringLengths[cacheKey],
                        bytesLength: repo.lastResponseByteLengths[cacheKey],
                        rootType: repo.lastResponseRootTypes[cacheKey],
                      ),
                    },
                    lastError: repo.lastError,
                  )
                : null;
            return Center(
              child: FutureBuilder<bool>(
                future: repo.hasCachedData(cacheKey),
                builder: (context, snapshot) {
                  final hasCache = snapshot.data ?? false;
                  return DataLoadError(
                    title: l10n.dataLoadTitle,
                    message: l10n.dataLoadSpreadsError,
                    retryLabel: l10n.dataLoadRetry,
                    onRetry: () {
                      ref.read(useCachedSpreadsProvider.notifier).state = false;
                      ref.invalidate(spreadsProvider);
                    },
                    secondaryLabel: hasCache ? l10n.dataLoadUseCache : null,
                    onSecondary: hasCache
                        ? () {
                            ref.read(useCachedSpreadsProvider.notifier).state =
                                true;
                            ref.invalidate(spreadsProvider);
                          }
                        : null,
                    debugInfo: debugInfo,
                  );
                },
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
  int count, {
  int fallbackIndex = 0,
}) {
  for (final spread in spreads) {
    if (spread.positions.length == count) {
      return spread;
    }
  }
  if (spreads.isEmpty) {
    return null;
  }
  final index = fallbackIndex < spreads.length ? fallbackIndex : 0;
  return spreads[index];
}

class _SpreadOptionCard extends ConsumerWidget {
  const _SpreadOptionCard({
    required this.spread,
    required this.title,
    required this.subtitle,
    required this.animation,
  });

  final SpreadModel spread;
  final String title;
  final String subtitle;
  final Widget animation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () {
        ref.read(readingFlowControllerProvider.notifier).selectSpread(spread);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ShuffleScreen()),
        );
      },
      child: Ink(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(
            color: primary.withOpacity(0.32),
            width: 1.1,
          ),
          boxShadow: [
            BoxShadow(
              color: primary.withOpacity(0.14),
              blurRadius: 20,
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                height: 140,
                child: animation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum SpreadIconMode { oneCard, threeCards }

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
                if (widget.mode == SpreadIconMode.threeCards)
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
                if (widget.mode == SpreadIconMode.threeCards)
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
