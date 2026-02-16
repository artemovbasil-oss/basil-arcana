import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:basil_arcana/l10n/gen/app_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/telemetry/web_error_overlay.dart';
import 'core/telegram/telegram_back_button_observer.dart';
import 'data/models/deck_model.dart';
import 'features/history/history_screen.dart';
import 'features/history/query_history_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/splash/splash_screen.dart';
import 'state/providers.dart';

class BasilArcanaApp extends ConsumerWidget {
  const BasilArcanaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final selectedDeck = ref.watch(deckProvider);
    final appThemeFlavor = selectedDeck == DeckType.crowley
        ? AppThemeFlavor.crowley
        : AppThemeFlavor.defaultTheme;
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildAppTheme(flavor: appThemeFlavor),
      builder: (context, child) {
        return Stack(
          children: [
            if (child != null) child,
            const WebErrorOverlay(),
          ],
        );
      },
      navigatorObservers: [TelegramBackButtonObserver()],
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('kk'),
      ],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const SplashScreen(),
      routes: {
        HistoryScreen.routeName: (_) => const HistoryScreen(),
        QueryHistoryScreen.routeName: (_) => const QueryHistoryScreen(),
        SettingsScreen.routeName: (_) => const SettingsScreen(),
      },
    );
  }
}
