import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/card_video.dart';
import '../../data/models/deck_model.dart';
import '../../state/providers.dart';

String cardAssetPath(String cardId, {DeckId deckId = DeckId.major}) {
  if (deckId == DeckId.wands ||
      (deckId == DeckId.all && cardId.startsWith('wands_'))) {
    return 'assets/cards/wands/$cardId.webp';
  }
  if (deckId == DeckId.swords ||
      (deckId == DeckId.all && cardId.startsWith('swords_'))) {
    return 'assets/cards/swords/$cardId.webp';
  }
  if (deckId == DeckId.pentacles ||
      (deckId == DeckId.all && cardId.startsWith('pentacles_'))) {
    return 'assets/cards/pentacles/$cardId.webp';
  }
  if (deckId == DeckId.cups ||
      (deckId == DeckId.all && cardId.startsWith('cups_'))) {
    return 'assets/cards/cups/$cardId.webp';
  }
  switch (cardId) {
    case 'major_10_wheel':
      return 'assets/cards/major/major_10_wheel_of_fortune.webp';
    default:
      return 'assets/cards/major/$cardId.webp';
  }
}

String deckCoverAssetPath(DeckId deckId) {
  switch (deckId) {
    case DeckId.wands:
      return 'assets/deck/wands_cover.webp';
    case DeckId.major:
    case DeckId.all:
    default:
      return 'assets/deck/cover.webp';
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
  VideoPlayerController? _controller;
  bool _showVideo = false;
  bool _videoFailed = false;
  String? _resolvedVideoPath;

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
    _controller?.dispose();
    _controller = null;
  }

  void _setupController() {
    _resolvedVideoPath = normalizeVideoAssetPath(
      widget.videoAssetPath ?? resolveCardVideoAsset(widget.cardId),
    );
    if (!widget.enableVideo || _resolvedVideoPath == null) {
      return;
    }
    if (widget.autoPlayOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
    final controller = VideoPlayerController.asset(resolvedPath);
    _controller = controller;
    controller
      ..setLooping(false)
      ..setVolume(0.0);
    try {
      await controller.initialize();
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
      _disposeController();
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
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      if (autoPlay) {
        setState(() {
          _showVideo = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(18);
    final hasVideo =
        widget.enableVideo && _resolvedVideoPath != null && !_videoFailed;
    return GestureDetector(
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
          if (hasVideo && !_showVideo)
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
