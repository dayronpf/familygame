import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'art/story_stage.dart';
import 'feedback/feedback_service.dart';
import 'feedback/rating_card.dart';

/// Nombre corto de un cuento para recordarlo («Honestidad · Nilo»). Solo se guarda en el teléfono.
String storyLabel(Story story) {
  final hero = story.cast['hero'];
  return '${story.moral.name} · ${hero is Character ? hero.given : ''}'.trim();
}

/// Muestra un cuento en texto grande, pensado para leer en voz alta de noche.
/// Al final pregunta (una vez, sin insistir) cuánto gustó.
class StoryPage extends StatefulWidget {
  const StoryPage({
    super.key,
    required this.story,
    required this.onAnother,
    required this.feedback,
    this.art,
    this.animate = true,
  });

  final Story story;

  /// Arte de los cuentos (puede tardar o faltar: entonces se lee solo el texto).
  final Future<StageArt?>? art;

  /// Si `false`, los dibujos se quedan quietos (pruebas).
  final bool animate;

  /// Genera otro cuento con la misma enseñanza.
  final Story Function() onAnother;
  final FeedbackService feedback;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage>
    with SingleTickerProviderStateMixin {
  late Story _story = widget.story;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Ticker? _ticker;
  StageArt? _stageArt;
  List<StageSetup?> _setups = const [];
  bool? _askRating; // null = aún no sabemos si el envío está permitido
  bool _reachedEnd = false; // la ficha de valoración llegó a mostrarse
  bool _answered = false; // ya valoraron o dijeron «Ahora no»
  Future<String?>? _ratingId; // id del evento guardado al valorar

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6)
        ..start();
    }
    widget.art?.then((a) {
      if (!mounted) return;
      setState(() {
        _stageArt = a;
        _computeSetups();
      });
    });
    widget.feedback.enabled.then((v) {
      if (mounted) setState(() => _askRating = v);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // «Reducir movimiento» del sistema: los dibujos se quedan quietos.
    _ticker?.muted = MediaQuery.disableAnimationsOf(context);
  }

  /// Fondo, personajes y animación de cada escena del cuento actual.
  void _computeSetups() {
    final art = _stageArt;
    _setups = art == null
        ? const []
        : [
            for (final s in _story.scenes)
              stageFor(art, _story.cast, s.directives)
          ];
  }

  /// Si leyeron el cuento hasta el final y no respondieron, se les preguntará con calma más tarde.
  void _rememberIfUnanswered() {
    if (_reachedEnd && !_answered) {
      widget.feedback.rememberPending(_story.recipe, storyLabel(_story));
    }
  }

  /// Termina la valoración: añade los motivos (si hay) y recién entonces intenta enviar.
  Future<void> _finishRating(
      Future<String?>? idFuture, List<String> reasons) async {
    final id = await idFuture;
    if (id != null && reasons.isNotEmpty) {
      await widget.feedback.setReasons(id, reasons);
    }
    await widget.feedback.flush();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _clock.dispose();
    _rememberIfUnanswered();
    // Si se fueron a mitad del segundo paso, la nota ya está guardada: se envía sin motivo.
    if (_answered && _ratingId != null) {
      _finishRating(_ratingId, const []);
    }
    super.dispose();
  }

  void _another() {
    _rememberIfUnanswered();
    if (_answered && _ratingId != null) {
      _finishRating(
          _ratingId, const []); // por si se quedaron a mitad del segundo paso
    }
    setState(() {
      _story = widget.onAnother();
      _computeSetups();
      _reachedEnd = false;
      _answered = false;
      _ratingId = null;
    });
  }

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
            if (_story.title != null) ...[
              Text(
                _story.title!,
                style: text.headlineSmall!.copyWith(color: scheme.primary),
              ),
              const SizedBox(height: 16),
            ],
            for (var i = 0; i < _story.scenes.length; i++) ...[
              if (i < _setups.length && _setups[i] != null) ...[
                StoryStage(
                  setup: _setups[i]!,
                  clock: _clock,
                  art: _stageArt,
                  animate: widget.animate,
                ),
                const SizedBox(height: 14),
              ],
              Text(_story.scenes[i].text, style: body),
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
            const SizedBox(height: 16),
            if (_askRating == true)
              RatingCard(
                key: ValueKey(
                    'rating-${_story.recipe.seed}-${_story.recipe.valueId}'),
                onShown: () => _reachedEnd = true,
                onRate: (v) {
                  _answered = true;
                  // La nota se guarda al tocar; el envío espera a que terminen (por si añaden un motivo).
                  _ratingId = widget.feedback.rate(_story.recipe, v);
                },
                onDone: (reasons) => _finishRating(_ratingId, reasons),
                onSkip: () => _answered = true,
              ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _another,
              icon: const Icon(Icons.refresh),
              label: const Text('Contar otro cuento'),
            ),
          ],
        ),
      ),
    );
  }
}
