import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/app_top_bar.dart';
import '../../core/widgets/energy_widgets.dart';
import '../../data/repositories/ai_repository.dart';
import '../../state/energy_controller.dart';
import '../../state/providers.dart';
import '../settings/settings_screen.dart';
import 'astro_result_screen.dart';

class NatalChartFlowScreen extends ConsumerStatefulWidget {
  const NatalChartFlowScreen({super.key});

  @override
  ConsumerState<NatalChartFlowScreen> createState() =>
      _NatalChartFlowScreenState();
}

class _NatalChartFlowScreenState extends ConsumerState<NatalChartFlowScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();

  int _step = 0;
  bool _isSubmitting = false;
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
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
    setState(() {
      _dateController.text = _dateFormat.format(picked);
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (picked == null) {
      return;
    }
    final formatted = MaterialLocalizations.of(context).formatTimeOfDay(
      picked,
      alwaysUse24HourFormat: true,
    );
    setState(() {
      _timeController.text = formatted;
    });
  }

  Future<void> _next() async {
    if (_step == 0 && _nameController.text.trim().isEmpty) {
      return;
    }
    if (_step == 1 && _dateController.text.trim().isEmpty) {
      return;
    }
    if (_step == 2) {
      await _submit();
      return;
    }
    setState(() {
      _step += 1;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final name = _nameController.text.trim();
    final birthDate = _dateController.text.trim();
    final birthTime = _timeController.text.trim();
    if (name.isEmpty || birthDate.isEmpty || birthTime.isEmpty) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final canProceed = await trySpendEnergyForAction(
      context,
      ref,
      EnergyAction.natalChart,
    );
    if (!canProceed) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
      return;
    }

    final localeCode = Localizations.localeOf(context).languageCode;
    String summary;
    try {
      summary = await ref.read(aiRepositoryProvider).generateNatalChart(
            birthDate: birthDate,
            birthTime: birthTime,
            languageCode: localeCode,
          );
    } on AiRepositoryException {
      summary = _fallbackSummary(localeCode, name);
    } catch (_) {
      summary = _fallbackSummary(localeCode, name);
    }

    if (!mounted) {
      return;
    }

    final copy = _NatalCopy.resolve(context);
    await Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: true),
        builder: (_) => AstroResultScreen(
          userPrompt: copy.userPrompt(name),
          title: copy.resultTitle,
          summary: summary,
          highlights: [
            copy.highlightDate(birthDate),
            copy.highlightTime(birthTime),
            copy.highlightAdvice,
          ],
          action: copy.randomAction(name),
          sofiaPrefill: '$summary\n\n${copy.highlightDate(birthDate)}',
          tarotQuestion: copy.tarotQuestion(name),
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

  String _fallbackSummary(String languageCode, String name) {
    if (languageCode == 'ru') {
      return 'Для $name сейчас важен баланс между внутренней опорой и внешней инициативой. Натальная карта показывает, что ваши сильные решения рождаются там, где есть дисциплина и честность к себе.';
    }
    if (languageCode == 'kk') {
      return '$name үшін қазір ішкі тұрақтылық пен сыртқы әрекеттің тепе-теңдігі маңызды. Наталдық картада күшті шешімдеріңіз тәртіп пен өзіңізге адалдықтан туатыны көрінеді.';
    }
    return 'For $name, the key theme now is balancing inner stability with outward initiative. The natal chart suggests your strongest decisions come from discipline and honest self-alignment.';
  }

  @override
  Widget build(BuildContext context) {
    final copy = _NatalCopy.resolve(context);
    final canContinue = switch (_step) {
      0 => _nameController.text.trim().isNotEmpty,
      1 => _dateController.text.trim().isNotEmpty,
      _ => _timeController.text.trim().isNotEmpty && !_isSubmitting,
    };

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
              _StepProgress(total: 3, current: _step),
              const SizedBox(height: 20),
              if (_step == 0)
                _InputField(
                  controller: _nameController,
                  label: copy.nameLabel,
                  hint: copy.nameHint,
                  onChanged: (_) => setState(() {}),
                ),
              if (_step == 1)
                _InputField(
                  controller: _dateController,
                  label: copy.dateLabel,
                  hint: copy.dateHint,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
              if (_step == 2)
                _InputField(
                  controller: _timeController,
                  label: copy.timeLabel,
                  hint: copy.timeHint,
                  readOnly: true,
                  suffixIcon: const Icon(Icons.schedule),
                  onTap: _pickTime,
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
                      label: _step == 2 ? copy.generateButton : copy.nextButton,
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

class _NatalCopy {
  const _NatalCopy({
    required this.screenTitle,
    required this.nameLabel,
    required this.nameHint,
    required this.dateLabel,
    required this.dateHint,
    required this.timeLabel,
    required this.timeHint,
    required this.loadingLabel,
    required this.backButton,
    required this.nextButton,
    required this.generateButton,
    required this.resultTitle,
    required this.highlightAdvice,
    required this.footerHint,
  });

  final String screenTitle;
  final String nameLabel;
  final String nameHint;
  final String dateLabel;
  final String dateHint;
  final String timeLabel;
  final String timeHint;
  final String loadingLabel;
  final String backButton;
  final String nextButton;
  final String generateButton;
  final String resultTitle;
  final String highlightAdvice;
  final String footerHint;

  String userPrompt(String name) {
    final normalizedName = name.trim();
    if (screenTitle == 'Натальная карта') {
      return 'Собери мне натальную карту для $normalizedName';
    }
    if (screenTitle == 'Наталдық карта') {
      return '$normalizedName үшін наталдық карта жаса';
    }
    return 'Generate a natal chart for $normalizedName';
  }

  String highlightDate(String date) {
    if (screenTitle == 'Натальная карта') {
      return 'Дата рождения: $date';
    }
    if (screenTitle == 'Наталдық карта') {
      return 'Туған күні: $date';
    }
    return 'Birth date: $date';
  }

  String highlightTime(String time) {
    if (screenTitle == 'Натальная карта') {
      return 'Время рождения: $time';
    }
    if (screenTitle == 'Наталдық карта') {
      return 'Туған уақыты: $time';
    }
    return 'Birth time: $time';
  }

  String tarotQuestion(String name) {
    final normalizedName = name.trim();
    if (screenTitle == 'Натальная карта') {
      return 'Расклад на удачу для $normalizedName';
    }
    if (screenTitle == 'Наталдық карта') {
      return '$normalizedName үшін сәттілікке расклад';
    }
    return 'Luck spread for $normalizedName';
  }

  String randomAction(String name) {
    final normalizedName = name.trim();
    if (screenTitle == 'Натальная карта') {
      final options = [
        '$normalizedName, разберите завал на столе и в заметках за 25 минут: хаос вокруг съедает фокус быстрее любых сомнений.',
        'Поставьте один «земной» дедлайн на 48 часов: счет, звонок, документы. Духовность работает лучше, когда быт под контролем.',
        'Сделайте ревизию окружения: с кем после общения вы выжаты. На неделю сократите контакт хотя бы на 30%.',
        'Проверьте режим сна на три ночи подряд. Если спите рвано, никакие инсайты не закрепятся в действии.',
        'Выберите одну привычку-утечку (скролл, сахар, поздние чаты) и урежьте ее вдвое на 7 дней.',
      ];
      return options[DateTime.now().microsecondsSinceEpoch % options.length];
    }
    if (screenTitle == 'Наталдық карта') {
      final options = [
        '$normalizedName, 25 минут ішінде үстел мен жазбаларды реттеңіз: сыртқы ретсіздік фокусты жейді.',
        'Алдағы 48 сағатқа бір нақты тұрмыстық дедлайн қойыңыз: төлем, қоңырау, құжат.',
        'Қарым-қатынасты сүзгіден өткізіңіз: қай адамнан кейін күшіңіз түседі. Бір апта сол байланысты азайтыңыз.',
        'Үш түн ұйқы режимін реттеңіз. Ұйқы бұзылса, жақсы ой да іске айналмайды.',
        'Бір зиянды әдетті таңдаңыз да (артық скролл, кеш чат), 7 күнге екі есе қысқартыңыз.',
      ];
      return options[DateTime.now().microsecondsSinceEpoch % options.length];
    }
    final options = [
      '$normalizedName, do a 25-minute cleanup of your desk and notes. External mess drains decision quality fast.',
      'Set one practical 48-hour deadline: bill, call, document. Spiritual clarity needs operational traction.',
      'Audit your circle: who leaves you depleted. Reduce that contact by 30% this week.',
      'Stabilize sleep for three nights in a row. Insights without recovery rarely turn into action.',
      'Pick one leakage habit (doomscrolling, late chats, sugar spikes) and cut it in half for 7 days.',
    ];
    return options[DateTime.now().microsecondsSinceEpoch % options.length];
  }

  static _NatalCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _NatalCopy(
        screenTitle: 'Натальная карта',
        nameLabel: 'Имя',
        nameHint: 'Введите имя',
        dateLabel: 'Дата рождения',
        dateHint: 'ГГГГ-ММ-ДД',
        timeLabel: 'Время рождения',
        timeHint: 'ЧЧ:ММ',
        loadingLabel: 'Создаем натальную карту…',
        backButton: 'Назад',
        nextButton: 'Далее',
        generateButton: 'Построить',
        resultTitle: 'Ваш разбор',
        highlightAdvice:
            'Главный фокус: раскрывайте сильные стороны постепенно, через устойчивый ритм.',
        footerHint:
            'Натальная карта — это личная астрологическая схема по дате, времени и месту рождения.',
      );
    }
    if (code == 'kk') {
      return const _NatalCopy(
        screenTitle: 'Наталдық карта',
        nameLabel: 'Аты',
        nameHint: 'Атыңызды енгізіңіз',
        dateLabel: 'Туған күні',
        dateHint: 'ЖЖЖЖ-АА-КК',
        timeLabel: 'Туған уақыты',
        timeHint: 'СС:ММ',
        loadingLabel: 'Наталдық карта жасалуда…',
        backButton: 'Артқа',
        nextButton: 'Келесі',
        generateButton: 'Құру',
        resultTitle: 'Түсіндірме',
        highlightAdvice:
            'Негізгі фокус: күшті қырларыңызды тұрақты ырғақ арқылы біртіндеп ашыңыз.',
        footerHint:
            'Наталдық карта — туған күн, уақыт және орынға негізделген жеке астрологиялық сызба.',
      );
    }
    return const _NatalCopy(
      screenTitle: 'Natal Chart',
      nameLabel: 'Name',
      nameHint: 'Enter name',
      dateLabel: 'Date of birth',
      dateHint: 'YYYY-MM-DD',
      timeLabel: 'Time of birth',
      timeHint: 'HH:MM',
      loadingLabel: 'Creating your natal chart…',
      backButton: 'Back',
      nextButton: 'Next',
      generateButton: 'Build',
      resultTitle: 'Your interpretation',
      highlightAdvice:
          'Main focus: unfold your strengths gradually through a steady rhythm.',
      footerHint:
          'A natal chart is your personal astrological map based on date, time, and place of birth.',
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

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.hint,
    this.readOnly = false,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final bool readOnly;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onChanged: onChanged,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
