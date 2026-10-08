import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

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
  });

  final Story story;

  /// Genera otro cuento con la misma enseñanza.
  final Story Function() onAnother;
  final FeedbackService feedback;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  late Story _story = widget.story;
  bool? _askRating; // null = aún no sabemos si el envío está permitido
  bool _reachedEnd = false; // la ficha de valoración llegó a mostrarse
  bool _answered = false; // ya valoraron o dijeron «Ahora no»
  Future<String?>? _ratingId; // id del evento guardado al valorar

  @override
  void initState() {
    super.initState();
    widget.feedback.enabled.then((v) {
      if (mounted) setState(() => _askRating = v);
    });
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
