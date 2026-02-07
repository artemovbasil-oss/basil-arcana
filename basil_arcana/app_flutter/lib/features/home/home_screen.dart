import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/config/config_service.dart';
import '../../core/config/diagnostics.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_text_field.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../data/models/app_enums.dart';
import '../../state/providers.dart';
import '../cards/cards_screen.dart';
import '../spread/spread_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _questionKey = GlobalKey();
  final _scrollController = ScrollController();
  bool _autoFocused = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_scrollToQuestionField);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToQuestionField() {
    if (!_focusNode.hasFocus) {
      return;
    }
    final context = _questionKey.currentContext;
    if (context == null) {
      return;
    }
    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.2,
    );
  }

  void _showDebugOverlay(BuildContext context, Locale locale) {
    if (!kShowDiagnostics) {
      return;
    }
    final config = ConfigService.instance;
    final cardsRepo = ref.read(cardsRepositoryProvider);
    final spreadsRepo = ref.read(spreadsRepositoryProvider);
    final cardsCacheKey = cardsRepo.cardsCacheKey(locale.languageCode);
    final spreadsCacheKey = spreadsRepo.spreadsCacheKey(locale.languageCode);
    final lastRequestedCardsUrl =
        cardsRepo.lastAttemptedUrls[cardsCacheKey] ?? '—';
    final lastRequestedSpreadsUrl =
        spreadsRepo.lastAttemptedUrls[spreadsCacheKey] ?? '—';
    final cardsStatusCode = cardsRepo.lastStatusCodes[cardsCacheKey];
    final lastError = cardsRepo.lastError ??
        spreadsRepo.lastError ??
        config.lastError ??
        'None';
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final textTheme = Theme.of(dialogContext).textTheme;
        return AlertDialog(
          title: const Text('Debug info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DebugLine(
                  label: 'API_BASE_URL',
                  value: config.apiBaseUrl.trim().isEmpty
                      ? '—'
                      : config.apiBaseUrl,
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'ASSETS_BASE_URL',
                  value: config.assetsBaseUrl,
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Spreads URL',
                  value: spreadsRepo.spreadsUrlForLanguage(locale.languageCode),
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Cards URL',
                  value: cardsRepo.cardsUrlForLanguage(locale.languageCode),
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Cards last requested URL',
                  value: lastRequestedCardsUrl,
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Cards last status',
                  value: cardsStatusCode?.toString() ?? '—',
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Spreads last requested URL',
                  value: lastRequestedSpreadsUrl,
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Last error',
                  value: lastError,
                  textTheme: textTheme,
                ),
              ],
            ),
          ),
          actions: [
            AppSmallButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              label: 'Close',
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final examples = [
      l10n.homeExample1,
      l10n.homeExample2,
      l10n.homeExample3,
    ];
    final hasQuestion = _controller.text.trim().isNotEmpty;

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    const buttonHeight = 56.0;
    final primaryColor = colorScheme.primary;
    final disabledColor =
        Color.lerp(primaryColor, colorScheme.surface, 0.45)!;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  24 + buttonHeight,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.homeTitle,
                                style: AppTextStyles.title(context),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                l10n.homeTagline,
                                style: AppTextStyles.caption(context).copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showDebugOverlay(context, locale),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _ExampleGrid(
                      examples: examples,
                      onSelected: (value) {
                        _controller.text = value;
                        if (!_autoFocused) {
                          _autoFocused = true;
                          Future<void>.delayed(const Duration(milliseconds: 80))
                              .then((_) {
                            if (mounted) {
                              FocusScope.of(context).requestFocus(_focusNode);
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 22),
                    Text(
                      l10n.homeQuestionLabel,
                      style: AppTextStyles.sectionTitle(context),
                    ),
                    const SizedBox(height: 8),
                    _QuestionField(
                      key: _questionKey,
                      controller: _controller,
                      focusNode: _focusNode,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.homeQuickActionsLabel,
                      style: AppTextStyles.sectionTitle(context),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: AppGhostButton(
                            label: l10n.homeAllCardsButton,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings:
                                      appRouteSettings(showBackButton: true),
                                  builder: (_) => const CardsScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: AppGhostButton(
                            label: l10n.homeSpreadsButton,
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  settings:
                                      appRouteSettings(showBackButton: true),
                                  builder: (_) => const SpreadScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.homeQuickActionsHint,
                      style: AppTextStyles.caption(context).copyWith(
                        color: colorScheme.onSurface.withOpacity(0.75),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
            _BottomActionBar(
              question: _controller.text,
              enabled: hasQuestion,
              bottomInset: bottomInset,
              onSubmitted: () {
                if (!hasQuestion) {
                  return;
                }
                ref
                    .read(readingFlowControllerProvider.notifier)
                    .setQuestion(_controller.text);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    settings: appRouteSettings(showBackButton: true),
                    builder: (_) => const SpreadScreen(),
                  ),
                );
              },
              onCopied: () async {
                await Clipboard.setData(
                  ClipboardData(text: _controller.text),
                );
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.homeQuestionCopied)),
                );
              },
              backgroundColor: colorScheme.surface,
              buttonColor: hasQuestion ? primaryColor : disabledColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ExampleGrid extends StatelessWidget {
  const _ExampleGrid({
    required this.examples,
    required this.onSelected,
  });

  final List<String> examples;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 640 ? 3 : 2;
        final spacing = 12.0;
        final itemWidth = (width - spacing * (crossAxisCount - 1)) / crossAxisCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: examples
              .map(
                (example) => SizedBox(
                  width: itemWidth,
                  child: _ExampleCard(
                    text: example,
                    onTap: () => onSelected(example),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withOpacity(0.6),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            text,
            style: AppTextStyles.body(context),
          ),
        ),
      ),
    );
  }
}

class _QuestionField extends StatelessWidget {
  const _QuestionField({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      controller: controller,
      focusNode: focusNode,
      minLines: 3,
      maxLines: 6,
      hintText: AppLocalizations.of(context)!.homeQuestionPlaceholder,
      textInputAction: TextInputAction.newline,
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.question,
    required this.enabled,
    required this.bottomInset,
    required this.onSubmitted,
    required this.onCopied,
    required this.backgroundColor,
    required this.buttonColor,
  });

  final String question;
  final bool enabled;
  final double bottomInset;
  final VoidCallback onSubmitted;
  final VoidCallback onCopied;
  final Color backgroundColor;
  final Color buttonColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: AppPrimaryButton(
              onPressed: enabled ? onSubmitted : null,
              label: l10n.shuffleDrawButton,
              color: buttonColor,
            ),
          ),
          const SizedBox(width: 12),
          AppIconButton(
            onPressed: enabled ? onCopied : null,
            icon: Icons.copy_rounded,
          ),
        ],
      ),
    );
  }
}

class _DebugLine extends StatelessWidget {
  const _DebugLine({
    required this.label,
    required this.value,
    required this.textTheme,
  });

  final String label;
  final String value;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          SelectableText(value),
        ],
      ),
    );
  }
}
