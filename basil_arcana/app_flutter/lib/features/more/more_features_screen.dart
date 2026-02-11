import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/energy_widgets.dart';
import '../../core/widgets/linkified_text.dart';
import '../../core/widgets/sofia_promo_card.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/energy_controller.dart';
import '../../state/providers.dart';

class MoreFeaturesScreen extends ConsumerStatefulWidget {
  const MoreFeaturesScreen({super.key});

  @override
  ConsumerState<MoreFeaturesScreen> createState() => _MoreFeaturesScreenState();
}

class _MoreFeaturesScreenState extends ConsumerState<MoreFeaturesScreen> {
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _birthTimeController = TextEditingController();
  bool _showNatalForm = false;
  bool _isLoading = false;
  String? _resultText;
  String? _errorText;

  static const bool _enableDebugLogs = !kReleaseMode;
  static final DateFormat _birthDateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _birthDateController.dispose();
    _birthTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initialDate = _parseBirthDate() ?? DateTime(now.year - 25, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _birthDateController.text = _birthDateFormat.format(picked);
    });
  }

  Future<void> _pickBirthTime() async {
    final initialTime =
        _parseBirthTime() ?? const TimeOfDay(hour: 12, minute: 0);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (picked == null) {
      return;
    }
    final formatted = MaterialLocalizations.of(context).formatTimeOfDay(
      picked,
      alwaysUse24HourFormat: true,
    );
    setState(() {
      _birthTimeController.text = formatted;
    });
  }

  DateTime? _parseBirthDate() {
    final text = _birthDateController.text.trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      return _birthDateFormat.parseStrict(text);
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseBirthTime() {
    final text = _birthTimeController.text.trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text);
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '');
    if (hour == null || minute == null) {
      return null;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _handleNatalChart() async {
    final l10n = AppLocalizations.of(context)!;
    final birthDate = _birthDateController.text.trim();
    if (birthDate.isEmpty) {
      setState(() {
        _errorText = l10n.natalChartBirthDateError;
      });
      return;
    }

    final canProceed = await trySpendEnergyForAction(
      context,
      ref,
      EnergyAction.natalChart,
    );
    if (!canProceed || !mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
      _resultText = null;
    });

    final birthTime = _birthTimeController.text.trim();
    final languageCode = Localizations.localeOf(context).languageCode;
    try {
      final result = await ref.read(aiRepositoryProvider).generateNatalChart(
            birthDate: birthDate,
            birthTime: birthTime.isEmpty ? null : birthTime,
            languageCode: languageCode,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _resultText = result;
        _isLoading = false;
      });
    } on AiRepositoryException {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = l10n.natalChartError;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = l10n.natalChartError;
        _isLoading = false;
      });
    }
  }

  void _logDebug(String message, [Object? error]) {
    if (!_enableDebugLogs) {
      return;
    }
    if (error != null) {
      debugPrint('[want-more] $message: $error');
    } else {
      debugPrint('[want-more] $message');
    }
  }

  Future<void> _requestPlansAndReturnToBot() async {
    final url = Uri.parse('https://t.me/tarot_arkana_bot?start=plans');
    var didOpen = false;
    if (!didOpen) {
      try {
        didOpen = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (error) {
        _logDebug('launchUrl failed', error);
      }
    }
    if (didOpen) {
      return;
    }

    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.professionalReadingOpenBotSnackbar),
        action: SnackBarAction(
          label: l10n.professionalReadingOpenBotAction,
          onPressed: () {
            launchUrl(url, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final resultText = _resultText;
    final cleanedResult =
        resultText == null ? null : stripSofiaPromo(resultText);
    final hasSofiaPromo =
        resultText == null ? false : containsSofiaPromo(resultText);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreFeaturesTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.actionCancel,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _FeatureCard(
              title: l10n.natalChartTitle,
              description: l10n.natalChartDescription,
              trailing: _StatusPill(text: l10n.natalChartFreeLabel),
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: l10n.natalChartButton,
                    icon: Icons.auto_awesome,
                    onPressed: () {
                      setState(() {
                        _showNatalForm = true;
                      });
                    },
                  ),
                ),
                if (_showNatalForm) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _birthDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.natalChartBirthDateLabel,
                      hintText: l10n.natalChartBirthDateHint,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: _pickBirthDate,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _birthTimeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: l10n.natalChartBirthTimeLabel,
                      hintText: l10n.natalChartBirthTimeHint,
                      helperText: l10n.natalChartBirthTimeHelper,
                      suffixIcon: const Icon(Icons.schedule),
                    ),
                    onTap: _pickBirthTime,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AppPrimaryButton(
                      label: l10n.natalChartGenerateButton,
                      icon: Icons.auto_awesome_outlined,
                      onPressed: _isLoading ? null : _handleNatalChart,
                    ),
                  ),
                ],
                if (_isLoading) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.natalChartLoading,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
                if (_errorText != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorText!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: colorScheme.error),
                  ),
                ],
                if (resultText != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.natalChartResultTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  if ((cleanedResult ?? '').trim().isNotEmpty)
                    LinkifiedText(
                      cleanedResult!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  if (hasSofiaPromo) ...[
                    const SizedBox(height: 12),
                    SofiaPromoCard(
                      compact: true,
                      prefilledMessage: (cleanedResult ?? '').trim(),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 16),
            _FeatureCard(
              title: l10n.professionalReadingTitle,
              description: l10n.professionalReadingDescription,
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: AppPrimaryButton(
                    label: l10n.professionalReadingButton,
                    icon: Icons.workspace_premium,
                    onPressed: _requestPlansAndReturnToBot,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
    this.trailing,
    this.children = const [],
  });

  final String title;
  final String description;
  final Widget? trailing;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colorScheme.surface.withOpacity(0.96),
            colorScheme.primary.withOpacity(0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: colorScheme.primary.withOpacity(0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0A3C20),
            Color(0xFF14592F),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2FA25A)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
