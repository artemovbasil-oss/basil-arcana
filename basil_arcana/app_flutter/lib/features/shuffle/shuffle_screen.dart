import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/widgets/tarot_asset_widgets.dart';
import '../../state/providers.dart';
import '../result/result_screen.dart';

class ShuffleScreen extends ConsumerStatefulWidget {
  const ShuffleScreen({super.key});

  @override
  ConsumerState<ShuffleScreen> createState() => _ShuffleScreenState();
}

class _ShuffleScreenState extends ConsumerState<ShuffleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _ctaTimer;
  bool _showCta = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      precacheImage(
        const AssetImage('assets/deck/cover.webp'),
        context,
      );
    });
    _ctaTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() {
          _showCta = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _ctaTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    final cardsAsync = ref.watch(cardsProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.shuffleTitle)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 220,
                      height: 280,
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          final t = _controller.value * 2 * pi;
                          final phases = <double>[
                            0,
                            pi / 2,
                            pi,
                            3 * pi / 2,
                            pi / 3,
                          ];
                          final baseOffsets = <Offset>[
                            const Offset(0, 24),
                            const Offset(-20, 12),
                            const Offset(18, 6),
                            const Offset(-12, -4),
                            const Offset(12, -10),
                          ];
                          final baseAngles = <double>[
                            -0.12,
                            -0.06,
                            0.05,
                            0.11,
                            -0.02,
                          ];
                          return Stack(
                            alignment: Alignment.center,
                            children: List.generate(phases.length, (index) {
                              final wave = sin(t + phases[index]);
                              final sway = cos(t + phases[index]);
                              final offset = baseOffsets[index] +
                                  Offset(wave * 10, sway * 6);
                              final angle = baseAngles[index] + wave * 0.08;
                              return Transform.translate(
                                offset: offset,
                                child: Transform.rotate(
                                  angle: angle,
                                  child: DeckCoverBack(
                                    highlight: index == phases.length - 1,
                                  ),
                                ),
                              );
                            }),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.shuffleSubtitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: colorScheme.onSurface),
                    ),
                  ],
                ),
              ),
            ),
            if (state.isLoading) const LinearProgressIndicator(),
            const SizedBox(height: 16),
            AnimatedSlide(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              offset: _showCta ? Offset.zero : const Offset(0, 0.2),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 360),
                opacity: _showCta ? 1 : 0,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: !_showCta || state.isLoading
                        ? null
                        : () async {
                            final cards = await cardsAsync.valueOrNull;
                            if (cards == null) {
                              return;
                            }
                            await ref
                                .read(readingFlowControllerProvider.notifier)
                                .drawAndGenerate(cards);
                            if (mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ResultScreen(),
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: const StadiumBorder(),
                    ),
                    child: Text(l10n.shuffleDrawButton),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
