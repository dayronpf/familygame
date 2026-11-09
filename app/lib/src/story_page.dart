import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'art/story_stage.dart';
import 'audio/ambience.dart';
import 'audio/sfx.dart';
import 'audio_only_page.dart';
import 'cinema_page.dart';
import 'hologram_page.dart';
import 'narration/narrator.dart';
import 'progress/progress_tab.dart';
import 'progress/reading_progress.dart';
import 'settings/app_settings.dart';
import 'feedback/feedback_service.dart';
import 'feedback/rating_card.dart';
import 'shared_reading_page.dart';
import 'shelf/story_shelf.dart';
import 'story_flow.dart';
import 'ui/choice_cards.dart';
import 'ui/palette.dart';

/// Nombre corto de un cuento para recordarlo («Honestidad · Nilo»). Solo se guarda en el teléfono.
String storyLabel(Story story) {
  final hero = story.cast['hero'];
  return '${story.moral.name} · ${hero is Character ? hero.given : ''}'.trim();
}

/// Cómo se abre el cuento: el lector de siempre, «Leemos juntos» o solo escuchar.
enum StoryStart { reader, together, listen }

/// Muestra un cuento en texto grande, pensado para leer en voz alta de noche.
/// Al final pregunta (una vez, sin insistir) cuánto gustó.
class StoryPage extends StatefulWidget {
  const StoryPage({
    super.key,
    required this.story,
    required this.onAnother,
    required this.feedback,
    required this.shelf,
    this.run,
    this.onAnotherRun,
    this.option,
    this.age,
    this.heroName,
    this.heroGender,
    this.childId,
    this.art,
    this.animate = true,
    this.narrator,
    this.ambience,
    this.sfx,
    this.premiseId,
    this.start = StoryStart.reader,
    this.progress,
    this.packId,
    this.canTellAnother = true,
  });

  /// Si «Contar otro cuento» puede crear uno nuevo (sin suscripción, solo hay los gratis: el botón lleva a verlos).
  final bool canTellAnother;

  /// Progreso del niño: se anota cada cuento terminado (y se celebran los premios nuevos).
  final ReadingProgress? progress;

  /// Paquete del cuento (para el progreso; por defecto el de la receta).
  final String? packId;

  /// Cuento elegido en el catálogo (se guarda para contarlo igual otra vez).
  final String? premiseId;

  /// Con qué modo se abre (la ficha del cuento ofrece «Leer juntos» y «Escuchar»).
  final StoryStart start;

  /// Voz y fondo de los modos cine y holograma (por defecto, los del teléfono; las pruebas ponen mudos).
  final Narrator Function()? narrator;
  final Ambience Function()? ambience;
  final Sfx Function()? sfx;

  final Story story;

  /// El cuento con sus preguntas al niño (puede estar a medias). Sin él, [story] es un cuento entero y no se
  /// pregunta nada.
  final StoryRun? run;

  /// Otro cuento con preguntas (si no se da, se usa [onAnother]).
  final StoryRun Function()? onAnotherRun;

  /// Con qué se generó este cuento (para guardarlo en «Mis cuentos» y contarlo igual otra vez).
  final String? age;
  final String? heroName;
  final String? heroGender;
  final String? childId;

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
  late Story _plain = widget.story;
  StoryFlow? _flow;
  Story get _story => _flow?.story ?? _plain;
  final ValueNotifier<double> _clock = ValueNotifier(0);
  Ticker? _ticker;
  StageArt? _stageArt;
  List<StageSetup?> _setups = const [];
  bool? _askRating; // null = aún no sabemos si el envío está permitido
  bool _reachedEnd = false; // la ficha de valoración llegó a mostrarse
  bool _answered = false; // ya valoraron o dijeron «Ahora no»
  Future<String?>? _ratingId; // id del evento guardado al valorar
  bool _counted = false; // este cuento ya se anotó como terminado
  bool _artPending = false; // los dibujos aún se están cargando
  List<Award> _fresh =
      const []; // premios que dio este cuento (se celebran al final, sin ventanas)

  @override
  void initState() {
    super.initState();
    if (widget.run != null) {
      _flow = StoryFlow(widget.run!)..addListener(_onFlow);
    }
    if (widget.animate) {
      _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6)
        ..start();
    }
    _artPending = widget.art != null;
    widget.art?.then((a) {
      if (!mounted) return;
      setState(() {
        _stageArt = a;
        _artPending = false;
        _computeSetups();
      });
    }, onError: (Object _) {
      if (mounted) setState(() => _artPending = false);
    });
    widget.feedback.enabled.then((v) {
      if (mounted) setState(() => _askRating = v);
    });
    widget.shelf.addListener(_onShelf);
    // Fuera del armado de pantalla: el inicio escucha al estante y no puede reconstruirse a mitad de otro armado.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remember();
      if (!mounted) return;
      switch (widget.start) {
        case StoryStart.reader:
          break;
        case StoryStart.together:
          _openSharedReading();
        case StoryStart.listen:
          _openAudioOnly();
      }
    });
  }

  void _onShelf() {
    if (mounted) setState(() {});
  }

  /// El niño contestó una pregunta: aparece el resto del cuento y se guarda lo que eligió.
  void _onFlow() {
    if (!mounted) return;
    setState(() => _computeSetups());
    _remember();
  }

  ShelfEntry get _entry => ShelfEntry.fromStory(
        _story,
        option: widget.option,
        premiseId: widget.premiseId,
        age: widget.age,
        heroName: widget.heroName,
        heroGender: widget.heroGender,
        childId: widget.childId,
      );

  bool get _complete => _flow?.isComplete ?? true;

  /// El cuento se terminó (leído hasta el final, «Terminar» en Leemos juntos o sonó entero): se marca en
  /// «Mis cuentos», se suma al progreso una sola vez y, si da premios nuevos, se celebran.
  Future<void> _finished({bool together = false}) async {
    widget.shelf.markFinished(_entry);
    final progress = widget.progress;
    if (_counted || progress == null) return;
    _counted = true;
    final chars = _story.scenes.fold<int>(0, (n, s) => n + s.text.length);
    final fresh = await progress.recordFinished(
      childId: widget.childId,
      moralId: _story.moral.id,
      packId: widget.packId ?? _story.recipe.packId,
      minutes: minutesForText(chars),
      together: together,
    );
    if (!mounted || fresh.isEmpty) return;
    setState(() => _fresh = fresh);
  }

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
            flow: _flow,
            art: art,
            setups: _setups,
            narrator: narrator,
            ambience: ambience,
            sfx: widget.sfx?.call(),
          )
        : CinemaPage(
            story: _story,
            flow: _flow,
            art: art,
            setups: _setups,
            narrator: narrator,
            ambience: ambience,
            sfx: widget.sfx?.call(),
            animate: widget.animate,
          );
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }

  /// «Ver y escuchar» funciona siempre: si los dibujos aún cargan, espera a que lleguen; si no hay dibujos, el cuento
  /// se escucha igual (solo audio) en vez de dejar un botón apagado que no explica nada.
  Future<void> _watch() async {
    if (_artPending) {
      try {
        await widget.art;
      } catch (_) {}
      if (!mounted) return;
    }
    if (_stageArt != null && _setups.any((s) => s != null)) {
      _openShow(hologram: false);
    } else {
      _openAudioOnly();
    }
  }

  /// El holograma necesita los dibujos: espera a que carguen y, si no hay, lo dice.
  Future<void> _hologram() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (_artPending) {
      try {
        await widget.art;
      } catch (_) {}
      if (!mounted) return;
    }
    if (_stageArt != null && _setups.any((s) => s != null)) {
      _openShow(hologram: true);
    } else {
      messenger?.showSnackBar(const SnackBar(
          content: Text(
              'Este cuento no tiene dibujos ahora: prueba «Leer juntos» o «Solo escuchar».')));
    }
  }

  /// Solo audio: la pantalla se queda negra y el cuento sigue sonando.
  void _openAudioOnly() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AudioOnlyPage(
        story: _flow?.finish() ?? _story,
        onFinished: _finished,
        narrator: widget.narrator?.call(),
        ambience: widget.ambience?.call(),
        sfx: widget.sfx?.call(),
      ),
    ));
  }

  /// Leemos juntos: texto grande por escenas para leer en voz alta (con turnos con la voz si se quiere).
  void _openSharedReading() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SharedReadingPage(
        story: _story,
        flow: _flow,
        art: _stageArt,
        setups: _setups,
        narrator: widget.narrator?.call(),
        animate: widget.animate,
        onFinished: () => _finished(together: true),
      ),
    ));
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
    _flow?.removeListener(_onFlow);
    _flow?.dispose();
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
      if (widget.onAnotherRun != null) {
        _flow?.removeListener(_onFlow);
        _flow?.dispose();
        _flow = StoryFlow(widget.onAnotherRun!())..addListener(_onFlow);
      } else {
        _plain = widget.onAnother();
      }
      _computeSetups();
      _reachedEnd = false;
      _answered = false;
      _ratingId = null;
      _counted = false;
      _fresh = const [];
    });
    _remember();
  }

  /// La pregunta de una escena: con los dos o tres caminos si está sin responder (el adulto manda, sin esperas) y,
  /// ya respondida, una línea con lo que se eligió.
  Widget _question(StoryScene scene) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final q = scene.choice!;
    final picked = scene.pickedOption;
    if (picked != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          key: const Key('choice-picked'),
          children: [
            Icon(
              choiceIcons[q.optionById(picked)?.glyph] ?? Icons.check_circle,
              size: 20,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eligieron: ${q.optionById(picked)?.label ?? ''}',
                style: text.bodyLarge!.copyWith(
                  fontStyle: FontStyle.italic,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Card(
      key: const Key('choice-block'),
      color: scheme.surfaceContainerHighest,
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              q.ask,
              textAlign: TextAlign.center,
              style: text.titleLarge!.copyWith(color: scheme.primary),
            ),
            if (q.talk != null) ...[
              const SizedBox(height: 6),
              Text(
                q.talk!,
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            ChoiceCards(
              choice: q,
              dark: false,
              art: _stageArt,
              onChoose: (id) => _flow?.choose(id),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('choice-for-me'),
              onPressed: () => _flow?.chooseForMe(),
              child: const Text('Elige por nosotros'),
            ),
          ],
        ),
      ),
    );
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
        ],
      ),
      // Cómo se cuenta el cuento, siempre a la vista y con palabras (no solo iconos): un niño tiene que entenderlo.
      bottomNavigationBar: _ModeBar(
        artLoading: _artPending,
        onWatch: _watch,
        onTogether: _openSharedReading,
        onListen: _openAudioOnly,
        onHologram: _hologram,
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
              if (_story.scenes[i].choice != null) _question(_story.scenes[i]),
            ],
            const SizedBox(height: 8),
            if (_complete)
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
                      Text(_story.moralLine, style: body),
                    ],
                  ),
                ),
              ),
            // La lista se arma al bajar: si esto llega a armarse, leyeron hasta el final.
            if (_complete) _EndReached(onReached: _finished),
            if (_fresh.isNotEmpty &&
                (SettingsScope.maybeOf(context)?.celebrateAwards ?? true))
              AwardsEarned(awards: _fresh),
            const SizedBox(height: 16),
            if (_askRating == true && _complete)
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
            if (widget.canTellAnother)
              OutlinedButton.icon(
                onPressed: _another,
                icon: const Icon(Icons.refresh),
                label: const Text('Contar otro cuento'),
              )
            else
              OutlinedButton.icon(
                key: const Key('more-stories'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.auto_stories),
                label: const Text('Ver más cuentos'),
              ),
          ],
        ),
      ),
    );
  }
}

/// Avisa una vez, al aparecer, de que el cuento llegó al final.
class _EndReached extends StatefulWidget {
  const _EndReached({required this.onReached});

  final VoidCallback onReached;

  @override
  State<_EndReached> createState() => _EndReachedState();
}

class _EndReachedState extends State<_EndReached> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onReached());
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// «¿Cómo quieren el cuento?»: un botón grande para que se cuente solo (con dibujos y voz) y tres más pequeños para
/// leerlo juntos con letra grande, solo escucharlo (pantalla negra, para dormirse) o verlo como holograma. Cada uno
/// con su icono y dos palabras, para que se entienda sin explicaciones. Leer aquí mismo es lo que ya se ve arriba.
class _ModeBar extends StatelessWidget {
  const _ModeBar({
    this.artLoading = false,
    required this.onWatch,
    required this.onTogether,
    required this.onListen,
    required this.onHologram,
  });

  /// Mientras cargan los dibujos el botón grande muestra que espera; si no hay dibujos, queda apagado.
  final bool artLoading;
  final VoidCallback onWatch;
  final VoidCallback onTogether;
  final VoidCallback onListen;
  final VoidCallback onHologram;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: Palette.skyTop,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  key: const Key('mode-watch'),
                  // Siempre activo y con buen contraste (marrón oscuro sobre amarillo, ~10:1): un botón «apagado» se
                  // leía mal y no decía por qué.
                  onPressed: onWatch,
                  style: FilledButton.styleFrom(
                    backgroundColor: Palette.amber,
                    foregroundColor: Palette.amberDark,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30)),
                    textStyle:
                        text.titleLarge!.copyWith(fontWeight: FontWeight.w800),
                  ),
                  icon: !artLoading
                      ? const Icon(Icons.play_circle_fill, size: 34)
                      : const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Palette.amberDark),
                        ),
                  label: const Text('Ver y escuchar'),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _ModeChip(
                    key: const Key('mode-together'),
                    icon: Icons.menu_book,
                    label: 'Leer juntos',
                    color: Palette.teal,
                    onTap: onTogether,
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    key: const Key('mode-listen'),
                    icon: Icons.headphones,
                    label: 'Solo escuchar',
                    color: const Color(0xFF8E9BFF),
                    onTap: onListen,
                  ),
                  const SizedBox(width: 8),
                  _ModeChip(
                    key: const Key('mode-hologram'),
                    icon: Icons.view_in_ar,
                    label: 'Holograma',
                    color: const Color(0xFFFFA8D2),
                    onTap: onHologram,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = onTap != null;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Palette.card,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Opacity(
              opacity: enabled ? 1 : 0.45,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: color, size: 28),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(label,
                          maxLines: 1,
                          style: text.labelLarge!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Palette.cream)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
