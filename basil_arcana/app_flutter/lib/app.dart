import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/history/history_screen.dart';

class BasilArcanaApp extends StatelessWidget {
  const BasilArcanaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Basil\'s Arcana',
      theme: buildAppTheme(),
      home: const HomeScreen(),
      routes: {
        HistoryScreen.routeName: (_) => const HistoryScreen(),
      },
    );
  }
}
