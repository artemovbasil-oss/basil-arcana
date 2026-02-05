import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/card_video.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

String cardAssetPath(String cardId, {DeckId deckId = DeckId.major}) {
  final normalizedId = canonicalCardId(cardId);
  if (deckId == DeckId.wands ||
      (deckId == DeckId.all && normalizedId.startsWith('wands_'))) {
    return 'assets/cards/wands/$normalizedId.webp';
  }
  if (deckId == DeckId.swords ||
      (deckId == DeckId.all && normalizedId.startsWith('swords_'))) {
    return 'assets/cards/swords/$normalizedId.webp';
  }
  if (deckId == DeckId.pentacles ||
      (deckId == DeckId.all && normalizedId.startsWith('pentacles_'))) {
    return 'assets/cards/pentacles/$normalizedId.webp';
  }
  if (deckId == DeckId.cups ||
      (deckId == DeckId.all && normalizedId.startsWith('cups_'))) {
    return 'assets/cards/cups/$normalizedId.webp';
  }
  switch (normalizedId) {
    case 'major_10_wheel':
      return 'assets/cards/major/major_10_wheel_of_fortune.webp';
    default:
      return 'assets/cards/major/$normalizedId.webp';
  }
}

String deckCoverAssetPath(DeckId deckId) {
  switch (deckId) {
    case DeckId.wands:
    case DeckId.swords:
    case DeckId.pentacles:
    case DeckId.cups:
    case DeckId.major:
    case DeckId.all:
    default:
      return 'assets/deck/cover.webp';
  }
}

class CardMediaAssets {
  const CardMediaAssets({
    required this.imageAssetPath,
    required this.videoAssetPath,
  });

  final String imageAssetPath;
  final String? videoAssetPath;
}

class CardMediaResolver {
  const CardMediaResolver({
    this.deckId = DeckId.major,
    this.availableVideoAssets,
  });

  final DeckId deckId;
  final Set<String>? availableVideoAssets;

  CardMediaAssets resolve(
    String cardId, {
    String? videoAssetPathOverride,
  }) {
    final imageAssetPath = cardAssetPath(cardId, deckId: deckId);
    final resolvedVideo = normalizeVideoAssetPath(
      videoAssetPathOverride ??
          resolveCardVideoAsset(
            cardId,
            availableAssets: availableVideoAssets,
          ),
    );
    return CardMediaAssets(
      imageAssetPath: imageAssetPath,
      videoAssetPath: resolvedVideo,
    );
  }
}

class CardAssetImage extends ConsumerWidget {
  const CardAssetImage({
    super.key,
    required this.cardId,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showGlow = true,
  });

  final String cardId;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(18);
    final deckId = ref.watch(deckProvider);
    final image = Image.asset(
      cardAssetPath(cardId, deckId: deckId),
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        if (deckId != DeckId.major) {
          return Image.asset(
            cardAssetPath(cardId, deckId: DeckId.major),
            width: width,
            height: height,
            fit: fit,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              assert(() {
                debugPrint('Missing card asset for $cardId');
                return true;
              }());
              return _MissingCardPlaceholder(
                width: width,
                height: height,
                borderRadius: radius,
              );
            },
          );
        }
        assert(() {
          debugPrint('Missing card asset for $cardId');
          return true;
        }());
        return _MissingCardPlaceholder(
          width: width,
          height: height,
          borderRadius: radius,
        );
      },
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.35),
          width: 1,
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.25),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: image,
      ),
    );
  }
}

class CardMedia extends StatefulWidget {
  const CardMedia({
    super.key,
    required this.cardId,
    this.videoAssetPath,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showGlow = true,
    this.enableVideo = false,
    this.autoPlayOnce = false,
    this.playLabel,
  });

  final String cardId;
  final String? videoAssetPath;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showGlow;
  final bool enableVideo;
  final bool autoPlayOnce;
  final String? playLabel;

  @override
  State<CardMedia> createState() => _CardMediaState();
}

class _CardMediaState extends State<CardMedia> {
  static final Map<String, _CachedVideoController> _controllerCache = {};
  static const int _controllerCacheLimit = 3;

  VideoPlayerController? _controller;
  bool _showVideo = false;
  bool _videoFailed = false;
  String? _resolvedVideoPath;
  String? _cacheKey;
  bool _autoPlayAttempted = false;
  bool _autoPlayFailed = false;

  @override
  void initState() {
    super.initState();
    _setupController();
  }

  @override
  void didUpdateWidget(CardMedia oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cardId != widget.cardId ||
        oldWidget.videoAssetPath != widget.videoAssetPath ||
        oldWidget.enableVideo != widget.enableVideo) {
      _disposeController();
      _setupController();
    }
  }

  @override
  void dispose() {
    _disposeController();
    super.dispose();
  }

  void _disposeController() {
    _controller?.removeListener(_handlePlayback);
    final cacheKey = _cacheKey;
    if (cacheKey != null) {
      _releaseController(cacheKey);
    } else {
      _controller?.dispose();
    }
    _controller = null;
    _cacheKey = null;
  }

  void _setupController() {
    _resolvedVideoPath = normalizeVideoAssetPath(
      widget.videoAssetPath ?? resolveCardVideoAsset(widget.cardId),
    );
    _videoFailed = false;
    _showVideo = false;
    _autoPlayAttempted = false;
    _autoPlayFailed = false;
    if (!widget.enableVideo || _resolvedVideoPath == null) {
      return;
    }
    if (widget.autoPlayOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_autoPlayAttempted) {
          return;
        }
        _autoPlayAttempted = true;
        _playOnce(autoPlay: true);
      });
    }
  }

  void _handlePlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.position >= controller.value.duration &&
        !controller.value.isPlaying) {
      if (mounted && _showVideo) {
        setState(() {
          _showVideo = false;
        });
      }
    }
  }

  Future<void> _ensureInitialized() async {
    if (_controller != null || _videoFailed) {
      return;
    }
    final resolvedPath = _resolvedVideoPath;
    if (resolvedPath == null) {
      return;
    }
    final cacheKey = resolvedPath;
    _cacheKey = cacheKey;
    final cached = _controllerCache[cacheKey];
    final controller = cached?.controller ??
        VideoPlayerController.asset(
          resolvedPath,
          videoPlayerOptions: VideoPlayerOptions(
            mixWithOthers: true,
            allowBackgroundPlayback: false,
          ),
        );
    _controller = controller;
    if (cached == null) {
      _controllerCache[cacheKey] = _CachedVideoController(controller);
      _trimControllerCache();
    }
    _controllerCache[cacheKey]?.refCount++;
    controller
      ..setLooping(false)
      ..setVolume(0.0);
    try {
      if (!controller.value.isInitialized) {
        await controller.initialize();
      }
      if (!mounted) {
        return;
      }
      controller.addListener(_handlePlayback);
    } catch (_) {
      if (mounted) {
        setState(() {
          _videoFailed = true;
        });
      } else {
        _videoFailed = true;
      }
      _releaseController(cacheKey, forceDispose: true);
      _controller = null;
    }
  }

  Future<void> _playOnce({required bool autoPlay}) async {
    await _ensureInitialized();
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    try {
      await controller.seekTo(Duration.zero);
      await controller.play();
      if (!mounted) {
        return;
      }
      setState(() {
        _showVideo = true;
        if (autoPlay) {
          _autoPlayFailed = false;
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _showVideo = false;
        if (autoPlay) {
          _autoPlayFailed = true;
        }
      });
    }
  }

  void _releaseController(String cacheKey, {bool forceDispose = false}) {
    final cached = _controllerCache[cacheKey];
    if (cached == null) {
      _controller?.dispose();
      return;
    }
    if (cached.refCount > 0) {
      cached.refCount -= 1;
    }
    if (cached.refCount <= 0 || forceDispose) {
      cached.controller.dispose();
      _controllerCache.remove(cacheKey);
    }
  }

  void _trimControllerCache() {
    if (_controllerCache.length <= _controllerCacheLimit) {
      return;
    }
    final keys = _controllerCache.keys.toList();
    for (final key in keys) {
      if (_controllerCache.length <= _controllerCacheLimit) {
        break;
      }
      final cached = _controllerCache[key];
      if (cached == null || cached.refCount > 0) {
        continue;
      }
      cached.controller.dispose();
      _controllerCache.remove(key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(18);
    final hasVideo =
        widget.enableVideo && _resolvedVideoPath != null && !_videoFailed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasVideo ? () => _playOnce(autoPlay: false) : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CardAssetImage(
            cardId: widget.cardId,
            width: widget.width,
            height: widget.height,
            borderRadius: radius,
            fit: widget.fit,
            showGlow: widget.showGlow,
          ),
          if (hasVideo &&
              _controller != null &&
              _controller!.value.isInitialized &&
              _showVideo)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: FittedBox(
                  fit: widget.fit,
                  clipBehavior: Clip.hardEdge,
                  child: SizedBox(
                    width: _controller!.value.size.width,
                    height: _controller!.value.size.height,
                    child: VideoPlayer(_controller!),
                  ),
                ),
              ),
            ),
          if (hasVideo &&
              !_showVideo &&
              (!widget.autoPlayOnce || _autoPlayFailed))
            Positioned.fill(
              child: ClipRRect(
                borderRadius: radius,
                child: ColoredBox(
                  color: Colors.black.withOpacity(0.35),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white,
                        ),
                        if (widget.playLabel != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            widget.playLabel!,
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(color: Colors.white),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CachedVideoController {
  _CachedVideoController(this.controller);

  final VideoPlayerController controller;
  int refCount = 0;
}

class _MissingCardPlaceholder extends StatelessWidget {
  const _MissingCardPlaceholder({
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: colorScheme.surfaceVariant.withOpacity(0.5),
        border: Border.all(color: colorScheme.primary.withOpacity(0.35)),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.auto_awesome,
        color: colorScheme.primary.withOpacity(0.6),
        size: 32,
      ),
    );
  }
}

class DeckCoverBack extends ConsumerWidget {
  const DeckCoverBack({
    super.key,
    this.width = 160,
    this.height = 230,
    this.highlight = false,
  });

  final double width;
  final double height;
  final bool highlight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);
    final deckId = ref.watch(deckProvider);
    final coverPath = deckCoverAssetPath(deckId);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colorScheme.primary.withOpacity(highlight ? 0.6 : 0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(highlight ? 0.35 : 0.2),
            blurRadius: highlight ? 28 : 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          coverPath,
          width: width,
          height: height,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.high,
          errorBuilder: (context, error, stackTrace) {
            if (deckId != DeckId.major) {
              return Image.asset(
                deckCoverAssetPath(DeckId.major),
                width: width,
                height: height,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}
