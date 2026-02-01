import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../spread/spread_screen.dart';
import '../history/history_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _examples = const [
    'What should I focus on right now?',
    'What is blocking my progress?',
    'How can I approach this situation more wisely?',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _applyExample(String example) {
    _controller.text = example;
    ref.read(readingFlowControllerProvider.notifier).setQuestion(example);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(readingFlowControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Basil\'s Arcana'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, HistoryScreen.routeName);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reflective tarot readings for clarity, not certainty.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What\'s your question?',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(readingFlowControllerProvider.notifier).setQuestion(value);
                setState(() {});
              },
            ),
            const SizedBox(height: 16),
            Text(
              'Try one of these prompts:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _examples
                  .map(
                    (example) => ActionChip(
                      label: Text(example),
                      onPressed: () => _applyExample(example),
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.question.trim().isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SpreadScreen(),
                          ),
                        );
                      },
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
