import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:video_player/video_player.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/data_load_error.dart';
import '../../core/widgets/tarot_asset_widgets.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({
    super.key,
    this.card,
    this.cardId,
  });

  final CardModel? card;
  final String? cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final deckId = ref.watch(deckProvider);
    final videoIndex = ref.watch(videoIndexProvider).asData?.value;
    final availableVideos =
        videoIndex == null || videoIndex.isEmpty ? null : videoIndex;
    final resolvedCardId = widget.card?.id ?? widget.cardId;
    final cardsAsync = ref.watch(cardsAllProvider);
    final selectedCardsAsync = ref.watch(cardsProvider);
    final resolvedCard = _resolveCard(
      cardsAsync.asData?.value,
      selectedCardsAsync.asData?.value,
      resolvedCardId,
      widget.card,
    );
    if (resolvedCard == null) {
      final repo = ref.read(cardsRepositoryProvider);
      final locale = ref.read(localeProvider);
      final cacheKey = repo.cardsCacheKey(locale);
      DevFailureInfo? failureInfo;
      if (kEnableDevDiagnostics && cardsAsync.hasError) {
        failureInfo = buildDevFailureInfo(
          FailedStage.cardsLocalLoad,
          cardsAsync.error ?? StateError('Cards not loaded'),
        );
        logDevFailure(failureInfo);
      }
      final debugInfo = kEnableDevDiagnostics
          ? DataLoadDebugInfo(
              assetsBaseUrl: AssetsConfig.assetsBaseUrl,
              requests: {
                'cards (${repo.cardsFileNameForLocale(locale)})':
                    DataLoadRequestDebugInfo(
                  url: repo.lastAttemptedUrls[cacheKey] ?? '—',
                  statusCode: repo.lastStatusCodes[cacheKey],
                  contentType: repo.lastContentTypes[cacheKey],
                  contentLength: repo.lastContentLengths[cacheKey],
                  responseSnippetStart:
                      repo.lastResponseSnippetsStart[cacheKey],
                  responseSnippetEnd: repo.lastResponseSnippetsEnd[cacheKey],
                  responseLength: repo.lastResponseStringLengths[cacheKey],
                  bytesLength: repo.lastResponseByteLengths[cacheKey],
                  rootType: repo.lastResponseRootTypes[cacheKey],
                ),
              },
              failedStage: failureInfo?.failedStage,
              exceptionSummary: failureInfo?.summary,
            )
          : null;
      return Scaffold(
        appBar: buildTopBar(
          context,
          title: Text(l10n.cardsDetailTitle),
          showBack: true,
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: cardsAsync.isLoading
                ? const CircularProgressIndicator()
                : DataLoadError(
                    title: l10n.dataLoadTitle,
                    message: l10n.cardsLoadError,
                    retryLabel: l10n.dataLoadRetry,
                    onRetry: () => ref.invalidate(cardsAllProvider),
                    debugInfo: debugInfo,
                  ),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: buildTopBar(
        context,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.cardsDetailTitle,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Text(
              resolvedCard.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        showBack: true,
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Builder(
                builder: (context) {
                  final mediaAssets = CardMediaResolver(
                    deckId: deckId,
                    availableVideoFiles: availableVideos,
                  ).resolve(
                    resolvedCard.id,
                    card: resolvedCard,
                    imageUrlOverride: resolvedCard.imageUrl,
                    videoUrlOverride: resolvedCard.videoUrl,
                  );
                  final hasVideo =
                      mediaAssets.videoUrl?.trim().isNotEmpty ?? false;
                  final overlayKeywords =
                      resolvedCard.keywords.take(2).toList();
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceVariant
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(26),
                              boxShadow: [
                                BoxShadow(
                                  color: colorScheme.primary
                                      .withValues(alpha: 0.18),
                                  blurRadius: 24,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(26),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: CardMedia(
                                      cardId: resolvedCard.id,
                                      imageUrl: mediaAssets.imageUrl,
                                      videoUrl: mediaAssets.videoUrl,
                                      width: double.infinity,
                                      height: double.infinity,
                                      enableVideo: false,
                                      autoPlayOnce: false,
                                      loopVideo: false,
                                      playLabel: l10n.videoTapToPlay,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  if (hasVideo)
                                    Positioned(
                                      top: 14,
                                      right: 14,
                                      child: _VideoToggleButton(
                                        onPressed: () {
                                          final videoUrl = mediaAssets.videoUrl;
                                          if (videoUrl == null ||
                                              videoUrl.trim().isEmpty) {
                                            return;
                                          }
                                          _showVideoOverlay(
                                            videoUrl: videoUrl,
                                            title: resolvedCard.name,
                                          );
                                        },
                                      ),
                                    ),
                                  Positioned(
                                    left: 14,
                                    right: 14,
                                    bottom: 14,
                                    child: _CardOverlaySummary(
                                      keywords: overlayKeywords,
                                      generalMeaning:
                                          resolvedCard.meaning.general.trim(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.96),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.14),
                        blurRadius: 26,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.cardDetailedTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.primary,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resolvedCard.detailedDescription?.trim().isNotEmpty ??
                                false
                            ? resolvedCard.detailedDescription!
                            : l10n.cardDetailsFallback,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.cardFunFactTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colorScheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        resolvedCard.funFact?.trim().isNotEmpty ?? false
                            ? resolvedCard.funFact!
                            : l10n.cardDetailsFallback,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.cardStatsTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      if (resolvedCard.stats != null)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 2.4,
                          children: [
                            _StatTile(
                              label: l10n.statLuck,
                              value: resolvedCard.stats!.luck,
                              iconKind: _StatIconKind.luck,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withValues(alpha: 0.22),
                                  colorScheme.surfaceVariant
                                      .withValues(alpha: 0.55),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _StatTile(
                              label: l10n.statPower,
                              value: resolvedCard.stats!.power,
                              iconKind: _StatIconKind.power,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.secondary.withValues(alpha: 0.22),
                                  colorScheme.surfaceVariant
                                      .withValues(alpha: 0.5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _StatTile(
                              label: l10n.statLove,
                              value: resolvedCard.stats!.love,
                              iconKind: _StatIconKind.love,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.tertiary.withValues(alpha: 0.2),
                                  colorScheme.surfaceVariant
                                      .withValues(alpha: 0.5),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            _StatTile(
                              label: l10n.statClarity,
                              value: resolvedCard.stats!.clarity,
                              iconKind: _StatIconKind.clarity,
                              gradient: LinearGradient(
                                colors: [
                                  colorScheme.primary.withValues(alpha: 0.14),
                                  colorScheme.surface.withValues(alpha: 0.7),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          l10n.cardDetailsFallback,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVideoOverlay({
    required String videoUrl,
    required String title,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => _CardVideoOverlay(
        videoUrl: videoUrl,
        title: title,
      ),
    );
  }
}

CardModel? _resolveCard(
  List<CardModel>? cardsAll,
  List<CardModel>? selectedDeckCards,
  String? cardId,
  CardModel? fallback,
) {
  if (cardId == null || cardId.isEmpty) {
    return fallback;
  }
  final canonicalId = canonicalCardId(cardId);
  if (cardsAll != null && cardsAll.isNotEmpty) {
    for (final card in cardsAll) {
      if (card.id == canonicalId) {
        return card;
      }
    }
  }
  if (selectedDeckCards != null && selectedDeckCards.isNotEmpty) {
    for (final card in selectedDeckCards) {
      if (card.id == canonicalId) {
        return card;
      }
    }
  }
  return fallback;
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.iconKind,
    required this.gradient,
  });

  final String label;
  final int value;
  final _StatIconKind iconKind;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SvgPicture.string(
                _statIconSvg(iconKind, colorScheme.primary),
                width: 18,
                height: 18,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '$value',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _StatIconKind { luck, power, love, clarity }

String _statIconSvg(_StatIconKind kind, Color color) {
  final stroke =
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  return switch (kind) {
    _StatIconKind.luck => '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 3L13.9 8.1L19 10L13.9 11.9L12 17L10.1 11.9L5 10L10.1 8.1L12 3Z" stroke="$stroke" stroke-width="1.8" stroke-linejoin="round"/>
<path d="M18.5 14L19.3 16.2L21.5 17L19.3 17.8L18.5 20L17.7 17.8L15.5 17L17.7 16.2L18.5 14Z" stroke="$stroke" stroke-width="1.6" stroke-linejoin="round"/>
</svg>
''',
    _StatIconKind.power => '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M13 2L5 13H11L10 22L19 10H13L13 2Z" stroke="$stroke" stroke-width="1.8" stroke-linejoin="round"/>
</svg>
''',
    _StatIconKind.love => '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M12 20C7.5 16.8 4 13.7 4 9.7C4 7.4 5.8 5.5 8.2 5.5C9.7 5.5 11 6.2 12 7.4C13 6.2 14.3 5.5 15.8 5.5C18.2 5.5 20 7.4 20 9.7C20 13.7 16.5 16.8 12 20Z" stroke="$stroke" stroke-width="1.8" stroke-linejoin="round"/>
</svg>
''',
    _StatIconKind.clarity => '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M2.5 12C4.8 7.8 8.1 5.7 12 5.7C15.9 5.7 19.2 7.8 21.5 12C19.2 16.2 15.9 18.3 12 18.3C8.1 18.3 4.8 16.2 2.5 12Z" stroke="$stroke" stroke-width="1.8" stroke-linejoin="round"/>
<circle cx="12" cy="12" r="2.5" stroke="$stroke" stroke-width="1.8"/>
</svg>
''',
  };
}

class _CardOverlaySummary extends StatelessWidget {
  const _CardOverlaySummary({
    required this.keywords,
    required this.generalMeaning,
  });

  final List<String> keywords;
  final String generalMeaning;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final summary = generalMeaning.isNotEmpty ? generalMeaning : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (keywords.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: keywords
                .map(
                  (keyword) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.outline.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      keyword,
                      style: AppTextStyles.caption(context).copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.38),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          child: Text(
            summary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.96),
              height: 1.28,
            ),
          ),
        ),
      ],
    );
  }
}

class _VideoToggleButton extends StatelessWidget {
  const _VideoToggleButton({
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final videoLabel = switch (locale) {
      'ru' => 'Видео',
      'kk' => 'Видео',
      _ => 'Video',
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surface.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.string(
                _videoToggleIconSvg(colorScheme.onSurface),
                width: 14,
                height: 14,
              ),
              const SizedBox(width: 4),
              Text(
                videoLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _videoToggleIconSvg(Color color) {
  final stroke =
      '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  return '''
<svg viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
<path d="M8 6.8L17.2 12L8 17.2V6.8Z" stroke="$stroke" stroke-width="2" stroke-linejoin="round"/>
</svg>
''';
}

class _CardVideoOverlay extends StatefulWidget {
  const _CardVideoOverlay({
    required this.videoUrl,
    required this.title,
  });

  final String videoUrl;
  final String title;

  @override
  State<_CardVideoOverlay> createState() => _CardVideoOverlayState();
}

class _CardVideoOverlayState extends State<_CardVideoOverlay> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
      });
    } catch (error) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      backgroundColor: Colors.black.withValues(alpha: 0.9),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildBody(context),
            ),
            Positioned(
              top: 10,
              left: 12,
              right: 56,
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      final locale = Localizations.localeOf(context).languageCode;
      final errorText = switch (locale) {
        'ru' => 'Не удалось воспроизвести видео',
        'kk' => 'Бейне ойнатылмады',
        _ => 'Could not play video',
      };
      return Center(
        child: Text(
          errorText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
              ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: controller.value.aspectRatio > 0
            ? controller.value.aspectRatio
            : 2 / 3,
        child: VideoPlayer(controller),
      ),
    );
  }
}
