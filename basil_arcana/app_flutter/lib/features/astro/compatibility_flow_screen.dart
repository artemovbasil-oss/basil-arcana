import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/energy_widgets.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/energy_controller.dart';
import '../../state/providers.dart';
import '../../data/repositories/activity_stats_repository.dart';
import '../settings/settings_screen.dart';
import 'astro_result_screen.dart';

class CompatibilityFlowScreen extends ConsumerStatefulWidget {
  const CompatibilityFlowScreen({super.key});

  @override
  ConsumerState<CompatibilityFlowScreen> createState() =>
      _CompatibilityFlowScreenState();
}

class _CompatibilityFlowScreenState
    extends ConsumerState<CompatibilityFlowScreen> {
  final TextEditingController _p1NameController = TextEditingController();
  final TextEditingController _p1DateController = TextEditingController();
  final TextEditingController _p1TimeController = TextEditingController();
  final TextEditingController _p2NameController = TextEditingController();
  final TextEditingController _p2DateController = TextEditingController();
  final TextEditingController _p2TimeController = TextEditingController();

  int _step = 0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _p1NameController.dispose();
    _p1DateController.dispose();
    _p1TimeController.dispose();
    _p2NameController.dispose();
    _p2DateController.dispose();
    _p2TimeController.dispose();
    super.dispose();
  }

  TextEditingController _controllerForStep(int step) {
    switch (step) {
      case 0:
        return _p1NameController;
      case 1:
        return _p1DateController;
      case 2:
        return _p1TimeController;
      case 3:
        return _p2NameController;
      case 4:
        return _p2DateController;
      default:
        return _p2TimeController;
    }
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) {
      return;
    }
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    controller.text = '${picked.year}-$month-$day';
    setState(() {});
  }

  Future<void> _pickTime(TextEditingController controller) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked == null) {
      return;
    }
    final hour = picked.hour.toString().padLeft(2, '0');
    final minute = picked.minute.toString().padLeft(2, '0');
    controller.text = '$hour:$minute';
    setState(() {});
  }

  Future<void> _next() async {
    final current = _controllerForStep(_step).text.trim();
    if (current.isEmpty || _isSubmitting) {
      return;
    }
    if (_step == 5) {
      await _submit();
      return;
    }
    setState(() {
      _step += 1;
    });
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
    });

    final canProceed = await trySpendEnergyForAction(
      context,
      ref,
      EnergyAction.compatibility,
    );
    if (!canProceed) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final copy = _CompatibilityCopy.resolve(context);
    final p1Name = _p1NameController.text.trim();
    final p2Name = _p2NameController.text.trim();
    final p1Date = _p1DateController.text.trim();
    final p1Time = _p1TimeController.text.trim();
    final p2Date = _p2DateController.text.trim();
    final p2Time = _p2TimeController.text.trim();
    final localeCode = Localizations.localeOf(context).languageCode;

    String summary;
    int score;
    try {
      summary = await ref.read(aiRepositoryProvider).generateCompatibility(
            personOneName: p1Name,
            personOneBirthDate: p1Date,
            personOneBirthTime: p1Time,
            personTwoName: p2Name,
            personTwoBirthDate: p2Date,
            personTwoBirthTime: p2Time,
            languageCode: localeCode,
          );
      score = 72 + Random().nextInt(17);
    } on AiRepositoryException {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.errorText)),
      );
      return;
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSubmitting = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(copy.errorText)),
      );
      return;
    }

    await ref
        .read(activityStatsRepositoryProvider)
        .mark(UserActivityKind.compatibility);

    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: true),
        builder: (_) => AstroResultScreen(
          userPrompt: copy.userPrompt(p1Name, p2Name),
          title: copy.resultTitle,
          summary: summary,
          highlights: [
            copy.scoreLine(score),
            copy.styleLine(p1Name, p2Name),
            copy.conflictLine,
          ],
          action: copy.randomAction(p1Name, p2Name),
          sofiaPrefill: summary,
          tarotQuestion: copy.tarotQuestion(p1Name, p2Name),
        ),
      ),
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final copy = _CompatibilityCopy.resolve(context);
    final currentController = _controllerForStep(_step);
    final canContinue =
        currentController.text.trim().isNotEmpty && !_isSubmitting;

    final title = copy.stepTitle(_step);
    final label = copy.stepLabel(_step);
    final hint = copy.stepHint(_step);
    final isDate = _step == 1 || _step == 4;
    final isTime = _step == 2 || _step == 5;

    return Scaffold(
      appBar: buildEnergyTopBar(
        context,
        showBack: true,
        onSettings: () {
          Navigator.pushNamed(
            context,
            SettingsScreen.routeName,
            arguments: const AppRouteConfig(showBackButton: true),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(copy.screenTitle,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              _StepProgress(total: 6, current: _step),
              const SizedBox(height: 20),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              TextField(
                controller: currentController,
                readOnly: isDate || isTime,
                onChanged: (_) => setState(() {}),
                onTap: () {
                  if (isDate) {
                    _pickDate(currentController);
                  } else if (isTime) {
                    _pickTime(currentController);
                  }
                },
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  suffixIcon: isDate
                      ? const Icon(Icons.calendar_today)
                      : isTime
                          ? const Icon(Icons.schedule)
                          : null,
                ),
              ),
              if (_isSubmitting) ...[
                const SizedBox(height: 14),
                _MagicLoadingCard(
                  label: copy.loadingLabel,
                ),
              ],
              const Spacer(),
              Text(
                copy.footerHint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
                    ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (_step > 0) ...[
                    Expanded(
                      child: AppGhostButton(
                        label: copy.backButton,
                        onPressed: _isSubmitting
                            ? null
                            : () {
                                setState(() {
                                  _step -= 1;
                                });
                              },
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: AppPrimaryButton(
                      label: _step == 5 ? copy.generateButton : copy.nextButton,
                      onPressed: canContinue ? _next : null,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MagicLoadingCard extends StatelessWidget {
  const _MagicLoadingCard({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.22),
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              backgroundColor: Colors.white.withValues(alpha: 0.22),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityCopy {
  const _CompatibilityCopy({
    required this.screenTitle,
    required this.loadingLabel,
    required this.backButton,
    required this.nextButton,
    required this.generateButton,
    required this.resultTitle,
    required this.errorText,
    required this.conflictLine,
    required this.footerHint,
  });

  final String screenTitle;
  final String loadingLabel;
  final String backButton;
  final String nextButton;
  final String generateButton;
  final String resultTitle;
  final String errorText;
  final String conflictLine;
  final String footerHint;

  String stepTitle(int step) {
    if (screenTitle == 'Любовная совместимость') {
      return step < 3 ? 'Человек 1' : 'Человек 2';
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return step < 3 ? '1-адам' : '2-адам';
    }
    return step < 3 ? 'Person 1' : 'Person 2';
  }

  String stepLabel(int step) {
    if (screenTitle == 'Любовная совместимость') {
      return switch (step % 3) {
        0 => 'Имя',
        1 => 'Дата рождения',
        _ => 'Время рождения',
      };
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return switch (step % 3) {
        0 => 'Аты',
        1 => 'Туған күні',
        _ => 'Туған уақыты',
      };
    }
    return switch (step % 3) {
      0 => 'Name',
      1 => 'Date of birth',
      _ => 'Time of birth',
    };
  }

  String stepHint(int step) {
    if (screenTitle == 'Любовная совместимость') {
      return switch (step % 3) {
        0 => 'Введите имя',
        1 => 'ГГГГ-ММ-ДД',
        _ => 'ЧЧ:ММ',
      };
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return switch (step % 3) {
        0 => 'Атын енгізіңіз',
        1 => 'ЖЖЖЖ-АА-КК',
        _ => 'СС:ММ',
      };
    }
    return switch (step % 3) {
      0 => 'Enter name',
      1 => 'YYYY-MM-DD',
      _ => 'HH:MM',
    };
  }

  String userPrompt(String p1, String p2) {
    if (screenTitle == 'Любовная совместимость') {
      return 'Проверь совместимость: $p1 и $p2';
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return 'Үйлесімділікті тексер: $p1 және $p2';
    }
    return 'Check compatibility: $p1 and $p2';
  }

  String scoreLine(int score) {
    if (screenTitle == 'Любовная совместимость') {
      return 'Индекс совместимости: $score%';
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return 'Үйлесім индексі: $score%';
    }
    return 'Compatibility index: $score%';
  }

  String styleLine(String p1, String p2) {
    if (screenTitle == 'Любовная совместимость') {
      return 'Стиль пары $p1 + $p2: «эмоциональная честность + ясные договоренности». ';
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return '$p1 + $p2 жұбының стилі: «эмоциялық адалдық + нақты келісімдер». ';
    }
    return '$p1 + $p2 couple style: "emotional honesty + clear agreements."';
  }

  String tarotQuestion(String p1, String p2) {
    if (screenTitle == 'Любовная совместимость') {
      return 'узнать совместимость $p1 и $p2';
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      return '$p1 және $p2 үйлесімділігін білу';
    }
    return 'check compatibility between $p1 and $p2';
  }

  String randomAction(String p1, String p2) {
    if (screenTitle == 'Любовная совместимость') {
      final options = [
        'Отключите телефоны и 15 минут обсудите только один бытовой конфликт без «всегда/никогда». На выходе: одно правило на неделю.',
        'Сверьте деньги: кто и за что платит до конца месяца. Без романтики, просто цифры и дедлайны.',
        'Назначьте «тихий час» после работы: 60 минут без претензий и разборок. Потом коротко: что помогло, что бесит.',
        'Разведите триггеры по углам: каждому по одной теме, куда второй не лезет до договоренного времени.',
        'Сделайте проверку быта: сон, еда, усталость. Половина ссор не про чувства, а про ресурс.',
      ];
      return options[Random().nextInt(options.length)];
    }
    if (screenTitle == 'Махаббат үйлесімділігі') {
      final options = [
        '15 минут телефонсыз бір тұрмыстық мәселені ғана талқылаңыз. Соңында бір аптаға ортақ бір ереже бекітіңіз.',
        'Ай соңына дейінгі төлемдерді ашық бөлісіңіз: кім, не, қашан төлейді.',
        'Жұмыстан кейін 60 минут «тыныш аймақ» жасаңыз: шағымсыз. Кейін қысқа қорытынды айтыңыз.',
        'Тітіркендіретін тақырыптарды алдын ала бөліп алыңыз: әрқайсысына өз шекарасы болсын.',
        'Тұрмысты тексеріңіз: ұйқы, тамақ, шаршау. Көп жанжал сезімнен емес, шаршаудан туады.',
      ];
      return options[Random().nextInt(options.length)];
    }
    final options = [
      'No phones for 15 minutes. Discuss one real-life friction point and leave with one clear rule for this week.',
      'Align money expectations for the month: who pays what, by when, no vague promises.',
      'Set a 60-minute post-work quiet zone with no criticism. Debrief in two short sentences each.',
      'Identify one trigger topic for each person and set boundaries on when it can be discussed.',
      'Audit basics first: sleep, food, stress. Many fights are energy problems, not love problems.',
    ];
    return options[Random().nextInt(options.length)];
  }

  static _CompatibilityCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _CompatibilityCopy(
        screenTitle: 'Любовная совместимость',
        loadingLabel: 'Считаем совместимость…',
        backButton: 'Назад',
        nextButton: 'Далее',
        generateButton: 'Проверить',
        resultTitle: 'Разбор совместимости',
        errorText:
            'Не удалось сгенерировать совместимость. Попробуйте еще раз.',
        conflictLine:
            'Зона внимания: заранее проговаривайте ожидания к темпу общения и личным границам.',
        footerHint:
            'Проверка совместимости пары показывает, как ваши характеры, ритм и ценности сочетаются в отношениях.',
      );
    }
    if (code == 'kk') {
      return const _CompatibilityCopy(
        screenTitle: 'Махаббат үйлесімділігі',
        loadingLabel: 'Үйлесімділік есептелуде…',
        backButton: 'Артқа',
        nextButton: 'Келесі',
        generateButton: 'Тексеру',
        resultTitle: 'Үйлесімділік талдауы',
        errorText: 'Үйлесімділікті жасау мүмкін болмады. Қайта көріңіз.',
        conflictLine:
            'Назар аймағы: қарым-қатынас қарқыны мен жеке шекаралар туралы күтулерді алдын ала келісіп алыңыз.',
        footerHint:
            'Жұп үйлесімділігін тексеру қарым-қатынаста мінез, ырғақ және құндылықтардың қалай үйлесетінін көрсетеді.',
      );
    }
    return const _CompatibilityCopy(
      screenTitle: 'Love Compatibility',
      loadingLabel: 'Calculating compatibility…',
      backButton: 'Back',
      nextButton: 'Next',
      generateButton: 'Check',
      resultTitle: 'Compatibility reading',
      errorText: 'Could not generate compatibility. Please try again.',
      conflictLine:
          'Watch area: align expectations early on communication pace and personal boundaries.',
      footerHint:
          'Compatibility shows how your personalities, pace, and values interact in a relationship.',
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        for (var index = 0; index < total; index++) ...[
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: index <= current
                    ? colorScheme.primary
                    : colorScheme.outlineVariant,
              ),
            ),
          ),
          if (index != total - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}
