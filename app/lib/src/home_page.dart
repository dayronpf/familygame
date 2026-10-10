import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'art/story_stage.dart';
import 'feedback/adult_gate.dart';
import 'feedback/feedback_service.dart';
import 'feedback/feedback_store.dart';
import 'feedback/rating_card.dart';
import 'pack_loader.dart';
import 'seed.dart';
import 'settings_page.dart';
import 'story_page.dart';
import 'workshop_page.dart';

/// Pantalla de inicio: el adulto elige una enseñanza y crea el cuento.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.bundle,
    required this.seedProvider,
    required this.feedback,
    this.animateArt = true,
  });

  final bool animateArt;
  final AssetBundle bundle;
  final SeedProvider seedProvider;
  final FeedbackService feedback;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Pack> _pack = loadPack(widget.bundle);

  /// Dibujos de los cuentos; se carga una vez y se comparte con todos los cuentos.
  late final Future<StageArt?> _art = loadStageArt(widget.bundle);

  /// `null` = «Sorpréndeme» (el caldero elige).
  String? _selectedMoral;

  /// Cuento leído hasta el final que aún no valoraron (se pregunta con calma, no en plena noche).
  PendingStory? _pending;

  /// Ya respondieron la tarjeta pendiente: se deja a la vista con su «gracias» hasta el próximo cuento.
  bool _pendingAnswered = false;
  Future<String?>? _pendingRating;

  @override
  void initState() {
    super.initState();
    widget.feedback.flush(); // envía lo que haya esperando; nunca bloquea
    widget.feedback.pendingChanges.addListener(_refreshPending);
    _refreshPending();
  }

  @override
  void dispose() {
    widget.feedback.pendingChanges.removeListener(_refreshPending);
    super.dispose();
  }

  Future<void> _refreshPending() async {
    if (_pendingAnswered) return;
    final p = await widget.feedback.nextPending();
    if (mounted) setState(() => _pending = p);
  }

  void _createStory(Pack pack) {
    if (_pendingAnswered) {
      setState(() {
        _pendingAnswered = false;
        _pending = null;
      });
    }
    final engine = StoryEngine(pack);
    final story = engine.generate(
      StoryOptions(seed: widget.seedProvider(), valueId: _selectedMoral),
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPage(
          story: story,
          feedback: widget.feedback,
          art: _art,
          animate: widget.animateArt,
          onAnother: () => engine.generate(
            StoryOptions(seed: widget.seedProvider(), valueId: _selectedMoral),
          ),
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    if (!await askAdult(context) || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
          builder: (_) => SettingsPage(feedback: widget.feedback)),
    );
    _refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final pending = _pending;
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
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    key: const Key('open-settings'),
                    tooltip: 'Ajustes para adultos',
                    onPressed: _openSettings,
                    icon: const Icon(Icons.settings_outlined),
                  ),
                ),
                Text('Caldero de Cuentos', style: text.headlineLarge),
                const SizedBox(height: 8),
                Text(
                  '¿Qué quieres que aprenda hoy el protagonista?',
                  style: text.titleMedium,
                ),
                if (pending != null) ...[
                  const SizedBox(height: 24),
                  RatingCard(
                    key: ValueKey('pending-${pending.recipe.seed}'),
                    title: '¿Cuánto les gustó «${pending.label}»?',
                    onRate: (v) {
                      _pendingAnswered = true;
                      _pendingRating = widget.feedback.rate(pending.recipe, v);
                    },
                    onDone: (reasons) async {
                      final id = await _pendingRating;
                      if (id != null && reasons.isNotEmpty) {
                        await widget.feedback.setReasons(id, reasons);
                      }
                      await widget.feedback.flush();
                    },
                    onSkip: () async {
                      await widget.feedback.dismissPending(pending.recipe);
                      _refreshPending();
                    },
                  ),
                ],
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
                const SizedBox(height: 32),
                // Herramienta de desarrollo: previsualiza el arte y mide el rendimiento.
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => WorkshopPage(bundle: widget.bundle),
                    ),
                  ),
                  icon: const Icon(Icons.brush_outlined),
                  label: const Text('Taller de personajes (prueba)'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
