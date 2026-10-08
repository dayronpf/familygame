import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

/// Muestra un cuento en texto grande, pensado para leer en voz alta de noche.
class StoryPage extends StatefulWidget {
  const StoryPage({super.key, required this.story, required this.onAnother});

  final Story story;

  /// Genera otro cuento con la misma enseñanza.
  final Story Function() onAnother;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late Story _story = widget.story;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final body = text.titleLarge!.copyWith(height: 1.6);
    return Scaffold(
      appBar: AppBar(title: Text(_story.moral.name)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            for (final scene in _story.scenes) ...[
              Text(scene.text, style: body),
              const SizedBox(height: 20),
            ],
            const SizedBox(height: 8),
            Card(
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enseñanza',
                      style: text.labelLarge!.copyWith(color: scheme.primary),
                    ),
                    const SizedBox(height: 8),
                    Text(_story.moral.text, style: body),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => setState(() => _story = widget.onAnother()),
              icon: const Icon(Icons.refresh),
              label: const Text('Contar otro cuento'),
            ),
          ],
        ),
      ),
    );
  }
}
