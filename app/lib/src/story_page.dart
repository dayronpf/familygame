import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'art/story_stage.dart';
import 'audio/ambience.dart';
import 'cinema_page.dart';
import 'hologram_page.dart';
import 'narration/narrator.dart';
import 'feedback/feedback_service.dart';
import 'feedback/rating_card.dart';
import 'shelf/story_shelf.dart';
import 'ui/palette.dart';

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
    required this.shelf,
    this.option,
    this.art,
    this.animate = true,
    this.narrator,
    this.ambience,
  });

  /// Voz y fondo de los modos cine y holograma (por defecto, los del teléfono; las pruebas ponen mudos).
  final Narrator Function()? narrator;
  final Ambience Function()? ambience;

  final Story story;

  /// Arte de los cuentos (puede tardar o faltar: entonces se lee solo el texto).
  final Future<StageArt?>? art;

  /// Si `false`, los dibujos se quedan quietos (pruebas).
  final bool animate;

  /// Genera otro cuento con la misma enseñanza.
  final Story Function() onAnother;
  final FeedbackService feedback;

  /// «Mis cuentos»: aquí se anota que se contó y se guarda el corazón.
  final StoryShelf shelf;

  /// Enseñanza elegida al crear el cuento (`null` = «Sorpréndeme»), para poder contarlo igual otra vez.
  final String? option;

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
    widget.shelf.addListener(_onShelf);
    // Fuera del armado de pantalla: el inicio escucha al estante y no puede reconstruirse a mitad de otro armado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _remember());
  }

  void _onShelf() {
    if (mounted) setState(() {});
  }

  ShelfEntry get _entry => ShelfEntry.fromStory(_story, option: widget.option);

  /// Anota el cuento en «Mis cuentos» (los últimos que se contaron).
  void _remember() => widget.shelf.addRecent(_entry);

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

  void _openShow({required bool hologram}) {
    final art = _stageArt;
    if (art == null) return;
    final narrator = widget.narrator?.call();
    final ambience = widget.ambience?.call();
    final page = hologram
        ? HologramPage(
            story: _story,
            art: art,
            setups: _setups,
            narrator: narrator,
            ambience: ambience,
          )
        : CinemaPage(
            story: _story,
            art: art,
            setups: _setups,
            narrator: narrator,
            ambience: ambience,
            animate: widget.animate,
          );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
    widget.shelf.removeListener(_onShelf);
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
    _remember();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final body = text.titleLarge!.copyWith(height: 1.6);
    return Scaffold(
      appBar: AppBar(
        title: Text(_story.moral.name),
        actions: [
          IconButton(
            key: const Key('favorite'),
            icon: Icon(
              widget.shelf.isFavorite(_entry)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: widget.shelf.isFavorite(_entry)
                  ? Palette.moral['generosidad']
                  : null,
            ),
            tooltip: widget.shelf.isFavorite(_entry)
                ? 'Quitar de Mis cuentos'
                : 'Guardar en Mis cuentos',
            onPressed: () => widget.shelf.toggleFavorite(_entry),
          ),
          if (_stageArt != null && _setups.any((s) => s != null)) ...[
            IconButton(
              icon: const Icon(Icons.movie_filter),
              tooltip: 'Modo cine: escuchar con dibujos',
              onPressed: () => _openShow(hologram: false),
            ),
            IconButton(
              icon: const Icon(Icons.view_in_ar),
              tooltip: 'Modo holograma (prisma sobre la pantalla)',
              onPressed: () => _openShow(hologram: true),
            ),
          ],
        ],
      ),
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
