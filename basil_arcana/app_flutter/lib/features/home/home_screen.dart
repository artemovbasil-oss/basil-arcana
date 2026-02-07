import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/assets/asset_paths.dart';
import '../../core/config/config_service.dart';
import '../../core/config/diagnostics.dart';
import '../../core/navigation/app_route_config.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_buttons.dart';
import '../../state/providers.dart';
import '../../state/reading_flow_controller.dart';
import '../history/history_screen.dart';
import '../cards/cards_screen.dart';
import '../settings/settings_screen.dart';
import '../spread/spread_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _questionKey = GlobalKey();
  String? _buildMarker;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
    final initialQuestion =
        ref.read(readingFlowControllerProvider).question;
    if (initialQuestion.isNotEmpty) {
      _controller.text = initialQuestion;
    }
    ref.listen<ReadingFlowState>(
      readingFlowControllerProvider,
      (prev, next) {
        if (_controller.text == next.question) {
          return;
        }
        _controller.value = _controller.value.copyWith(
          text: next.question,
          selection:
              TextSelection.collapsed(offset: next.question.length),
          composing: TextRange.empty,
        );
        setState(() {});
      },
    );
    if (kShowDiagnostics) {
      _buildMarker = _resolveBuildMarker();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _resolveBuildMarker() {
    final build = ConfigService.instance.build;
    if (build != null && build.trim().isNotEmpty) {
      return build.trim();
    }
    return DateTime.now().toIso8601String();
  }

  void _applyExample(String example) {
    _controller.text = example;
    ref.read(readingFlowControllerProvider.notifier).setQuestion(example);
    setState(() {});
  }

  void _clearQuestion() {
    _controller.clear();
    ref.read(readingFlowControllerProvider.notifier).setQuestion('');
    setState(() {});
  }

  void _handleFocusChange() {
    setState(() {});
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
    final spreadsRepo = ref.read(dataRepositoryProvider);
    final cardsCacheKey = cardsRepo.cardsCacheKey(locale);
    final spreadsCacheKey = spreadsRepo.spreadsCacheKey(locale);
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
                  value: spreadsUrl(locale.languageCode),
                  textTheme: textTheme,
                ),
                _DebugLine(
                  label: 'Cards URL',
                  value: cardsRepo.cardsUrlForLocale(locale),
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
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onLongPress: kShowDiagnostics
                                ? () {
                                    _showDebugOverlay(context, locale);
                                  }
                                : null,
                            child: Text(
                              l10n.appTitle,
                              style: AppTextStyles.title(context)
                                  .copyWith(color: colorScheme.onSurface),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history),
                          tooltip: l10n.historyTooltip,
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              HistoryScreen.routeName,
                              arguments:
                                  const AppRouteConfig(showBackButton: true),
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: l10n.settingsTitle,
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              SettingsScreen.routeName,
                              arguments:
                                  const AppRouteConfig(showBackButton: true),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.homeDescription,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      key: _questionKey,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        color: colorScheme.surfaceVariant.withOpacity(0.25),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.18),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: colorScheme.primary.withOpacity(0.35),
                        ),
                      ),
                      child: Stack(
                        children: [
                          TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 6,
                            minLines: 5,
                            decoration: InputDecoration(
                              hintText: l10n.homeQuestionPlaceholder,
                              hintStyle: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        colorScheme.onSurface.withOpacity(0.45),
                                  ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 16, 48, 32),
                              alignLabelWithHint: true,
                            ),
                            onChanged: (value) {
                              ref
                                  .read(readingFlowControllerProvider.notifier)
                                  .setQuestion(value);
                              setState(() {});
                            },
                          ),
                          if (hasQuestion)
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _InlineIconButton(
                                    icon: Icons.close,
                                    tooltip: l10n.homeClearQuestionTooltip,
                                    onTap: _clearQuestion,
                                  ),
                                  const SizedBox(width: 8),
                                  _InlineIconButton(
                                    icon: Icons.arrow_forward,
                                    tooltip: l10n.homeContinueButton,
                                    onTap: () => _handlePrimaryAction(hasQuestion),
                                    backgroundColor:
                                        colorScheme.primary.withOpacity(0.2),
                                    iconColor: colorScheme.primary,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.homeTryPrompt,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: examples
                          .map(
                            (example) => _ExampleChip(
                              text: example,
                              onTap: () => _applyExample(example),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.homeSubtitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                    const SizedBox(height: 12),
                    _HomeNavCard(
                      title: l10n.homeAllCardsButton,
                      description: l10n.cardsTitle,
                      icon: Icons.auto_awesome,
                      onTap: () {
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
                  ],
                ),
              ),
            ),
            if (kShowDiagnostics && _buildMarker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'build: $_buildMarker',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.55),
                      ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: _PrimaryActionButton(
            isActive: hasQuestion,
            primaryColor: primaryColor,
            disabledColor: disabledColor,
            label: l10n.homeContinueButton,
            onPressed: () => _handlePrimaryAction(hasQuestion),
          ),
        ),
      ),
    );
  }

  void _handlePrimaryAction(bool hasQuestion) {
    if (!hasQuestion) {
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: false),
        builder: (_) => const SpreadScreen(),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ExampleChip extends StatelessWidget {
  const _ExampleChip({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surfaceVariant.withOpacity(0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _HomeNavCard extends StatelessWidget {
  const _HomeNavCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: colorScheme.surfaceVariant.withOpacity(0.3),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.65),
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.isActive,
    required this.primaryColor,
    required this.disabledColor,
    required this.label,
    this.onPressed,
  });

  final bool isActive;
  final Color primaryColor;
  final Color disabledColor;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AppPrimaryButton(
      label: label,
      onPressed: onPressed,
      backgroundColor: isActive ? primaryColor : disabledColor,
      padding: const EdgeInsets.symmetric(vertical: 16),
    );
  }
}

class _InlineIconButton extends StatelessWidget {
  const _InlineIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolvedBackground =
        backgroundColor ?? colorScheme.surface.withOpacity(0.85);
    final resolvedIconColor =
        iconColor ?? colorScheme.onSurface.withOpacity(0.75);
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: resolvedBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.35),
            ),
          ),
          child: Icon(
            icon,
            size: 18,
            color: resolvedIconColor,
          ),
        ),
      ),
    );
  }
}
