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
  late final AnimationController _cursorController;

  final Random _random = Random();

  _VibePromptsCopy? _copy;
  String _displayedText = '';
  String _currentPrompt = '';
  int _promptIndex = 0;
  bool _showShine = false;
  bool _flickerVisible = true;
  bool _isTyping = false;
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
    _cursorController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

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
    _cursorController.dispose();
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
          _isTyping = false;
        });
      }

      await Future<void>.delayed(const Duration(milliseconds: 220));
    }
  }

  Future<void> _typePrompt(String prompt) async {
    if (mounted) {
      setState(() {
        _currentPrompt = prompt;
        _displayedText = '';
        _showShine = false;
        _flickerVisible = true;
        _isTyping = true;
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
        Duration(
          milliseconds: _typingDelayForChar(
            char: char,
            index: i - 1,
            total: prompt.length,
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isTyping = false;
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 220));
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
    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  Future<void> _runFlicker() async {
    const pattern = <int>[56, 42, 60, 38, 58, 40, 70, 36, 82, 64, 98];
    for (var i = 0; i < pattern.length; i++) {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() {
        _flickerVisible = i.isEven ? false : true;
      });
      final jitter = _random.nextInt(18);
      await Future<void>.delayed(
        Duration(milliseconds: pattern[i] + jitter),
      );
    }
  }

  int _typingDelayForChar({
    required String char,
    required int index,
    required int total,
  }) {
    final progress = total <= 1 ? 1.0 : (index / (total - 1));
    if (char == ' ') {
      return 28 + _random.nextInt(28);
    }
    const punctuation = '.,!?;:';
    if (punctuation.contains(char)) {
      return 95 + _random.nextInt(95);
    }

    int base;
    if (progress < 0.2) {
      base = 22 + _random.nextInt(24);
    } else if (progress < 0.7) {
      base = 30 + _random.nextInt(30);
    } else {
      base = 44 + _random.nextInt(36);
    }

    if (_random.nextDouble() < 0.1) {
      base += 35 + _random.nextInt(70);
    }
    if (_random.nextDouble() < 0.08) {
      base -= 10 + _random.nextInt(10);
    }
    return max(16, base);
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
                              cursorAnimation: _cursorController,
                              showShine: _showShine,
                              showCursor:
                                  _displayedText.isNotEmpty && _isTyping,
                              style: textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.94),
                                fontWeight: FontWeight.w500,
                                fontSize: 32,
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
    required this.cursorAnimation,
    required this.showShine,
    required this.showCursor,
    required this.style,
    required this.shimmerColor,
  });

  final String text;
  final Animation<double> animation;
  final Animation<double> cursorAnimation;
  final bool showShine;
  final bool showCursor;
  final TextStyle? style;
  final Color shimmerColor;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox(height: 84);
    }
    final cursorColor = style?.color ?? Colors.white.withValues(alpha: 0.94);
    final cursorHeight = (style?.fontSize ?? 32) * 0.82;
    final cursorWidth = (style?.fontSize ?? 32) * 0.52;
    final composed = RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: style,
        children: [
          TextSpan(text: text),
          if (showCursor)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: AnimatedBuilder(
                animation: cursorAnimation,
                builder: (context, _) {
                  final opacity = 0.28 + (0.72 * cursorAnimation.value);
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: cursorWidth,
                        height: cursorHeight,
                        decoration: BoxDecoration(
                          color: cursorColor,
                          borderRadius: BorderRadius.circular(2.5),
                          boxShadow: [
                            BoxShadow(
                              color: cursorColor.withValues(alpha: 0.36),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    if (!showShine) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: composed,
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
            child: DefaultTextStyle.merge(
              style: style?.copyWith(color: Colors.white),
              child: composed,
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
