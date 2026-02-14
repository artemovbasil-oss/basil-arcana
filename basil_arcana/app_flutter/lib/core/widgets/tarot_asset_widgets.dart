import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/assets_config.dart';
import '../../core/config/diagnostics.dart';
import '../../data/models/card_video.dart';
import '../../data/models/card_model.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

class CardMediaAssets {
  const CardMediaAssets({
    required this.imageUrl,
    required this.videoUrl,
  });

  final String imageUrl;
  final String? videoUrl;
}

class CardMediaResolver {
  const CardMediaResolver({
    this.deckId = DeckType.major,
    this.availableVideoFiles,
  });

  final DeckType deckId;
  final Set<String>? availableVideoFiles;

  CardMediaAssets resolve(
    String cardId, {
    CardModel? card,
    String? imageUrlOverride,
    String? videoUrlOverride,
  }) {
    final imageUrl = imageUrlOverride ?? cardImageUrl(cardId, deckId: deckId);
    final fallbackCard = card ??
        CardModel(
          id: cardId,
          deckId: deckId,
          name: '',
          keywords: const [],
          meaning: const CardMeaning(
            general: '',
            light: '',
            shadow: '',
            advice: '',
          ),
          imageUrl: imageUrl,
        );
    final hasExplicitVideo =
        videoUrlOverride != null || _hasExplicitVideo(card);
    final directVideoUrl = videoUrlOverride ??
        cardVideoUrl(fallbackCard, AssetsConfig.assetsBaseUrl);
    String? resolvedVideo =
        directVideoUrl ?? _videoUrlFromCardId(cardId, availableVideoFiles);
    if (resolvedVideo != null &&
        availableVideoFiles != null &&
        availableVideoFiles!.isNotEmpty &&
        !hasExplicitVideo) {
      final fileName = resolvedVideo.split('/').last.toLowerCase();
      if (!availableVideoFiles!.contains(fileName)) {
        resolvedVideo = null;
      }
    }
    return CardMediaAssets(
      imageUrl: imageUrl,
      videoUrl: resolvedVideo,
    );
  }

  String? _videoUrlFromCardId(
    String cardId,
    Set<String>? availableVideoFiles,
  ) {
    final fileName = resolveCardVideoFileName(
      cardId,
      availableFiles: availableVideoFiles,
    );
    if (fileName == null || fileName.isEmpty) {
      return null;
    }
    return '${AssetsConfig.assetsBaseUrl}/video/$fileName';
  }

  bool _hasExplicitVideo(CardModel? card) {
    if (card == null) {
      return false;
    }
    final hasVideoFileName = card.videoFileName?.trim().isNotEmpty ?? false;
    final hasVideoUrl = card.videoUrl?.trim().isNotEmpty ?? false;
    return hasVideoFileName || hasVideoUrl;
  }
}

class CardAssetImage extends ConsumerWidget {
  const CardAssetImage({
    super.key,
    required this.cardId,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius,
    this.fit = BoxFit.cover,
    this.showGlow = true,
  });

  final String cardId;
  final String? imageUrl;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final BoxFit fit;
  final bool showGlow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = borderRadius ?? BorderRadius.circular(18);
    final cardsAsync = ref.watch(cardsProvider);
    final resolvedPath = imageUrl ??
        cardsAsync.asData?.value
            .firstWhere(
              (card) => card.id == cardId,
              orElse: () => const CardModel(
                id: '',
                deckId: DeckType.major,
                name: '',
                keywords: [],
                meaning: CardMeaning(
                  general: '',
                  light: '',
                  shadow: '',
                  advice: '',
                ),
                imageUrl: '',
              ),
            )
            .imageUrl;
    final image = Image.network(
      resolvedPath ?? '',
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        if (kEnableDevDiagnostics) {
          logDevFailure(
            buildDevFailureInfo(FailedStage.mediaLoad, error),
          );
        }
        assert(() {
          debugPrint('Missing card image for $cardId');
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
    this.imageUrl,
    this.videoUrl,
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
  final String? imageUrl;
  final String? videoUrl;
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
  String? _resolvedVideoUrl;
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
        oldWidget.videoUrl != widget.videoUrl ||
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
    _resolvedVideoUrl = widget.videoUrl;
    _videoFailed = false;
    _showVideo = false;
    _autoPlayAttempted = false;
    _autoPlayFailed = false;
    if (!widget.enableVideo || _resolvedVideoUrl == null) {
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
    final resolvedUrl = _resolvedVideoUrl;
    if (resolvedUrl == null) {
      return;
    }
    final cacheKey = resolvedUrl;
    _cacheKey = cacheKey;
    final cached = _controllerCache[cacheKey];
    final controller = cached?.controller ??
        VideoPlayerController.networkUrl(
          Uri.parse(resolvedUrl),
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
    } catch (error) {
      if (kEnableDevDiagnostics) {
        logDevFailure(
          buildDevFailureInfo(FailedStage.mediaLoad, error),
        );
      }
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
        widget.enableVideo && _resolvedVideoUrl != null && !_videoFailed;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasVideo ? () => _playOnce(autoPlay: false) : null,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CardAssetImage(
            cardId: widget.cardId,
            imageUrl: widget.imageUrl,
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
    this.imageUrl,
  });

  final double width;
  final double height;
  final bool highlight;
  final String? imageUrl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(18);
    final deckId = ref.watch(deckProvider);
    final coverPath = deckCoverAssetPath(deckId);
    final resolvedUrl = imageUrl ?? coverPath;
    Widget buildPlaceholder() {
      return Container(
        width: width,
        height: height,
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        alignment: Alignment.center,
        child: Icon(
          Icons.auto_awesome,
          color: colorScheme.primary.withOpacity(0.5),
          size: 28,
        ),
      );
    }

    Widget buildImage(String url, {bool allowFallback = false}) {
      return Image.network(
        url,
        width: width,
        height: height,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) {
            return child;
          }
          return buildPlaceholder();
        },
        errorBuilder: (context, error, stackTrace) {
          if (kEnableDevDiagnostics) {
            logDevFailure(
              buildDevFailureInfo(FailedStage.mediaLoad, error),
            );
          }
          if (allowFallback && deckId != DeckType.major) {
            return buildImage(
              deckCoverAssetPath(DeckType.major),
            );
          }
          return buildPlaceholder();
        },
      );
    }

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
        child: buildImage(resolvedUrl, allowFallback: imageUrl == null),
      ),
    );
  }
}
