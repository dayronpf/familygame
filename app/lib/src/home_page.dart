import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'pack_loader.dart';
import 'seed.dart';
import 'story_page.dart';

/// Pantalla de inicio: el adulto elige una enseñanza y crea el cuento.
class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.bundle, required this.seedProvider});

  final AssetBundle bundle;
  final SeedProvider seedProvider;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Pack> _pack = loadPack(widget.bundle);

  /// `null` = «Sorpréndeme» (el caldero elige).
  String? _selectedMoral;

  void _createStory(Pack pack) {
    final story = StoryEngine(pack).generate(
      StoryOptions(seed: widget.seedProvider(), valueId: _selectedMoral),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPage(
          story: story,
          onAnother: () => StoryEngine(pack).generate(
            StoryOptions(seed: widget.seedProvider(), valueId: _selectedMoral),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<Pack>(
          future: _pack,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudo abrir el caldero.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge,
                  ),
                ),
              );
            }
            final pack = snapshot.data;
            if (pack == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 16),
                Text('Caldero de Cuentos', style: text.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  '¿Qué quieres que aprenda hoy el protagonista?',
                  style: text.titleMedium,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    ChoiceChip(
                      label: const Text('Sorpréndeme'),
                      selected: _selectedMoral == null,
                      onSelected: (_) => setState(() => _selectedMoral = null),
                    ),
                    for (final moral in pack.morals)
                      ChoiceChip(
                        label: Text(moral.name),
                        selected: _selectedMoral == moral.id,
                        onSelected: (_) =>
                            setState(() => _selectedMoral = moral.id),
                      ),
                  ],
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () => _createStory(pack),
                  icon: const Icon(Icons.auto_stories),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Crear cuento'),
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
