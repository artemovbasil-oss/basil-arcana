import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import '../../core/telegram/telegram_bridge.dart';
import '../../core/widgets/app_buttons.dart';
import '../../data/repositories/ai_repository.dart';
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

  @override
  void dispose() {
    _birthDateController.dispose();
    _birthTimeController.dispose();
    super.dispose();
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

  void _scheduleClose() {
    Future.microtask(() {
      TelegramBridge.close();
    });
  }

  Future<void> _requestPlansAndReturnToBot() async {
    // Previously used TelegramWebApp.sendData/close with a dialog fallback.
    final payload = jsonEncode(
      {
        'action': 'show_plans',
        'source': 'want_more',
        'ts': DateTime.now().millisecondsSinceEpoch,
      },
    );
    if (TelegramBridge.isAvailable) {
      try {
        final didSend = TelegramBridge.sendData(payload);
        if (didSend) {
          _scheduleClose();
          return;
        }
      } catch (error) {
        _logDebug('sendData failed', error);
      }
    }

    final url = Uri.parse('https://t.me/tarot_arkana_bot?start=plans');
    var didOpen = false;
    if (TelegramBridge.isAvailable) {
      try {
        didOpen = TelegramBridge.openTelegramLink(url.toString());
      } catch (error) {
        _logDebug('openTelegramLink failed', error);
      }
    }
    if (!didOpen) {
      try {
        didOpen = await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (error) {
        _logDebug('launchUrl failed', error);
      }
    }
    if (didOpen) {
      _scheduleClose();
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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.moreFeaturesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: l10n.actionCancel,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
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
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: l10n.natalChartBirthDateLabel,
                      hintText: l10n.natalChartBirthDateHint,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _birthTimeController,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      labelText: l10n.natalChartBirthTimeLabel,
                      hintText: l10n.natalChartBirthTimeHint,
                      helperText: l10n.natalChartBirthTimeHelper,
                    ),
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
                if (_resultText != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    l10n.natalChartResultTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _resultText!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
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
                    icon: Icons.star,
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
    return Card(
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.primary.withOpacity(0.6)),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: colorScheme.onSurface),
      ),
    );
  }
}
