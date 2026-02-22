import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/app_route_config.dart';
import '../../core/widgets/app_buttons.dart';
import '../../state/providers.dart';
import '../spread/spread_screen.dart';

class VibePromptsScreen extends ConsumerStatefulWidget {
  const VibePromptsScreen({super.key});

  @override
  ConsumerState<VibePromptsScreen> createState() => _VibePromptsScreenState();
}

class _VibePromptsScreenState extends ConsumerState<VibePromptsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _breathController;
  late final AnimationController _shineController;

  final Random _random = Random();

  _VibePromptsCopy? _copy;
  String _displayedText = '';
  String _currentPrompt = '';
  int _promptIndex = 0;
  bool _showShine = false;
  bool _flickerVisible = true;
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5600),
      value: 0.5,
    )..repeat(reverse: true);
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _copy = _VibePromptsCopy.resolve(context);
      _runPromptLoop();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _breathController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  Future<void> _runPromptLoop() async {
    while (mounted && !_isDisposed) {
      final copy = _copy ?? _VibePromptsCopy.resolve(context);
      final prompts = copy.prompts;
      if (prompts.isEmpty) {
        return;
      }

      final prompt = prompts[_promptIndex % prompts.length];
      _promptIndex += 1;
      await _typePrompt(prompt);
      if (!mounted || _isDisposed) {
        return;
      }

      await _runShine();
      if (!mounted || _isDisposed) {
        return;
      }

      await _runFlicker();
      if (!mounted || _isDisposed) {
        return;
      }

      if (mounted) {
        setState(() {
          _displayedText = '';
          _flickerVisible = true;
          _showShine = false;
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 320));
    }
  }

  Future<void> _typePrompt(String prompt) async {
    if (mounted) {
      setState(() {
        _currentPrompt = prompt;
        _displayedText = '';
        _showShine = false;
        _flickerVisible = true;
      });
    }

    for (var i = 1; i <= prompt.length; i++) {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() {
        _displayedText = prompt.substring(0, i);
      });
      final char = prompt[i - 1];
      await Future<void>.delayed(
        Duration(milliseconds: _typingDelayForChar(char)),
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 380));
  }

  Future<void> _runShine() async {
    if (!mounted || _isDisposed) {
      return;
    }
    setState(() {
      _showShine = true;
    });
    await _shineController.forward(from: 0);
    if (!mounted || _isDisposed) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 380));
  }

  Future<void> _runFlicker() async {
    const pattern = <int>[90, 60, 80, 45, 70, 50, 55, 120, 45, 120, 75, 170];
    for (var i = 0; i < pattern.length; i++) {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() {
        _flickerVisible = i.isEven ? false : true;
      });
      final jitter = _random.nextInt(24);
      await Future<void>.delayed(
        Duration(milliseconds: pattern[i] + jitter),
      );
    }
  }

  int _typingDelayForChar(String char) {
    if (char == ' ') {
      return 42 + _random.nextInt(38);
    }
    const punctuation = '.,!?;:';
    if (punctuation.contains(char)) {
      return 170 + _random.nextInt(150);
    }
    final base = 46 + _random.nextInt(86);
    if (_random.nextDouble() < 0.17) {
      return base + 70 + _random.nextInt(140);
    }
    if (_random.nextDouble() < 0.12) {
      return max(28, base - (12 + _random.nextInt(18)));
    }
    return base;
  }

  void _startReadingFromPrompt() {
    final question = _currentPrompt.trim();
    if (question.isEmpty) {
      return;
    }
    ref.read(readingFlowControllerProvider.notifier).setQuestion(question);
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: appRouteSettings(showBackButton: false),
        builder: (_) => const SpreadScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final copy = _copy ?? _VibePromptsCopy.resolve(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: _breathController,
          builder: (context, _) {
            final breath =
                Curves.easeInOutSine.transform(_breathController.value);
            final centerAuraScale = 0.88 + (0.22 * breath);
            final sideAuraScale = 0.92 + (0.17 * (1 - breath));

            return Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          colorScheme.surface,
                          colorScheme.surface.withValues(alpha: 0.96),
                          colorScheme.surface,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        Align(
                          alignment: const Alignment(0, -0.08),
                          child: Transform.scale(
                            scale: centerAuraScale,
                            child: _BreathingAura(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.36),
                              size: 360,
                            ),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(-0.74, -0.42),
                          child: Transform.scale(
                            scale: sideAuraScale,
                            child: _BreathingAura(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.18),
                              size: 240,
                            ),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(0.76, 0.56),
                          child: Transform.scale(
                            scale: sideAuraScale,
                            child: _BreathingAura(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.16),
                              size: 230,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  child: Column(
                    children: [
                      _VibeHeader(copy: copy),
                      Expanded(
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _flickerVisible ? 1 : 0.12,
                            duration: const Duration(milliseconds: 110),
                            curve: Curves.easeOut,
                            child: _PromptText(
                              text: _displayedText,
                              animation: _shineController,
                              showShine: _showShine,
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.94),
                                fontWeight: FontWeight.w500,
                                fontSize: 36,
                                height: 1.28,
                              ),
                              shimmerColor:
                                  colorScheme.primary.withValues(alpha: 0.95),
                            ),
                          ),
                        ),
                      ),
                      AppPrimaryButton(
                        label: copy.cta,
                        onPressed: _currentPrompt.trim().isEmpty
                            ? null
                            : _startReadingFromPrompt,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _VibeHeader extends StatelessWidget {
  const _VibeHeader({required this.copy});

  final _VibePromptsCopy copy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  copy.overline,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  copy.title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.96),
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                      ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PromptText extends StatelessWidget {
  const _PromptText({
    required this.text,
    required this.animation,
    required this.showShine,
    required this.style,
    required this.shimmerColor,
  });

  final String text;
  final Animation<double> animation;
  final bool showShine;
  final TextStyle? style;
  final Color shimmerColor;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox(height: 84);
    }
    if (!showShine) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: style,
        ),
      );
    }
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            final shift =
                (-bounds.width) + (bounds.width * 2.2 * animation.value);
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white.withValues(alpha: 0.72),
                Colors.white.withValues(alpha: 0.92),
                shimmerColor,
                Colors.white.withValues(alpha: 0.92),
                Colors.white.withValues(alpha: 0.72),
              ],
              stops: const [0.0, 0.33, 0.5, 0.67, 1.0],
            ).createShader(
              Rect.fromLTWH(
                shift,
                bounds.top,
                bounds.width,
                bounds.height,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: style?.copyWith(color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _BreathingAura extends StatelessWidget {
  const _BreathingAura({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withValues(alpha: color.a * 0.62),
              color.withValues(alpha: 0),
            ],
            stops: const [0.0, 0.44, 1.0],
          ),
        ),
      ),
    );
  }
}

class _VibePromptsCopy {
  const _VibePromptsCopy({
    required this.overline,
    required this.title,
    required this.cta,
    required this.prompts,
  });

  final String overline;
  final String title;
  final String cta;
  final List<String> prompts;

  static _VibePromptsCopy resolve(BuildContext context) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru') {
      return const _VibePromptsCopy(
        overline: 'Поймай магический вайб',
        title: 'Не знаешь что спросить?',
        cta: 'Задать этот вопрос',
        prompts: [
          'Как я могу взять под контроль свою жизнь?',
          'Какие шаги мне нужно предпринять, чтобы достичь своих целей?',
          'Что мешает мне добиться успеха?',
          'Как я могу преодолеть свои страхи и сомнения?',
          'Как мне развить больше уверенности в себе?',
          'Какие риски я боюсь взять на себя?',
          'Почему я не достигаю своего полного потенциала?',
          'Каков смысл и цель моей жизни?',
          'Как я могу найти счастье и удовлетворение?',
          'Как я могу внести позитивные изменения в мир?',
          'Почему я снова возвращаюсь к этому человеку?',
          'Как улучшить отношения и перестать повторять старые сценарии?',
          'Что мне важно обсудить с партнером прямо сейчас?',
          'Что мне мешает спокойно выбрать следующий шаг?',
          'Какая энергия сейчас тормозит мои деньги?',
          'Какой финансовый шаг даст мне максимум пользы в ближайший месяц?',
          'Почему деньги приходят рывками и как стабилизировать поток?',
          'На чем мне сфокусироваться в карьере в этом квартале?',
          'Куда направить силы, чтобы быстрее увидеть результат?',
          'Как мне выйти из тревожного круга в отношениях?',
          'Какой план действий поможет мне перестать откладывать важное?',
          'Что сейчас самое важное для моего личного роста?',
          'Какое решение стоит принять сейчас, чтобы не жалеть позже?',
          'Что мне нужно отпустить, чтобы двигаться дальше?',
        ],
      );
    }
    if (code == 'kk') {
      return const _VibePromptsCopy(
        overline: 'Сиқырлы вайбты ұста',
        title: 'Не сұрауды білмейсің бе?',
        cta: 'Осы сұрақты қою',
        prompts: [
          'Өмірімді бақылауға қалай аламын?',
          'Мақсаттарыма жету үшін қандай қадамдар жасауым керек?',
          'Табысыма не кедергі болып тұр?',
          'Қорқыныш пен күмәнді қалай жеңемін?',
          'Өзіме деген сенімді қалай арттырамын?',
          'Қандай тәуекелдерді алуға қорқамын?',
          'Неге әлеуетімді толық аша алмай жүрмін?',
          'Өмірімнің мәні мен мақсаты қандай?',
          'Бақыт пен қанағатты қалай табамын?',
          'Неге мен осы адамға қайта орала беремін?',
          'Қарым-қатынасты жақсарту үшін қазір нені өзгертуім керек?',
          'Келесі қадамды таңдауға не кедергі?',
          'Қазір қаржыма қандай энергия тосқауыл болып тұр?',
          'Келесі айда қаржыма ең пайдалы қадам қайсы?',
          'Карьерамда қазір қай бағытқа күш салған дұрыс?',
          'Нәтижені тез көру үшін күшті қайда бағыттаймын?',
          'Қарым-қатынастағы уайым шеңберінен қалай шығамын?',
          'Маңызды істерді кейінге қалдырмау үшін қандай жоспар керек?',
          'Қазір қандай шешім кейін өкінбеуге көмектеседі?',
        ],
      );
    }
    return const _VibePromptsCopy(
      overline: 'Catch the magic vibe',
      title: 'Not sure what to ask?',
      cta: 'Ask this question',
      prompts: [
        'How can I take control of my life?',
        'What steps should I take to reach my goals?',
        'What is blocking my success right now?',
        'How can I overcome fear and self-doubt?',
        'How do I build stronger confidence in myself?',
        'Which risks am I afraid to take?',
        'Why am I not reaching my full potential?',
        'What is the deeper purpose of my life?',
        'How can I find more happiness and fulfillment?',
        'How can I make a positive impact in the world?',
        'Why do I keep returning to this person?',
        'How can I improve my relationship dynamics right now?',
        'What blocks me from choosing my next step calmly?',
        'What energy is slowing down my money right now?',
        'What financial move would help me most this month?',
        'What should I prioritize in my career this quarter?',
        'Where should I direct my focus for visible progress?',
        'How can I break this anxious cycle in relationships?',
        'What plan would help me stop procrastinating on what matters?',
        'What decision now will save me regret later?',
        'What do I need to release to move forward?',
      ],
    );
  }
}
