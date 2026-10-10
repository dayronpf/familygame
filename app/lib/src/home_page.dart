import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'art/story_stage.dart';
import 'feedback/adult_gate.dart';
import 'feedback/feedback_service.dart';
import 'feedback/feedback_store.dart';
import 'feedback/rating_card.dart';
import 'pack_loader.dart';
import 'packs/packs_tab.dart';
import 'seed.dart';
import 'settings_page.dart';
import 'share.dart';
import 'shelf/my_stories_tab.dart';
import 'shelf/story_shelf.dart';
import 'story_page.dart';
import 'ui/hero_banner.dart';
import 'ui/moral_style.dart';
import 'ui/moral_tile.dart';
import 'ui/night_background.dart';
import 'ui/palette.dart';

/// Pantalla de inicio, pensada para que la entienda un niño: una portada viva, tarjetas grandes para elegir lo
/// que se aprende y un único botón enorme para crear el cuento. Tres pestañas: Inicio, Paquetes y Mis cuentos.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.bundle,
    required this.seedProvider,
    required this.feedback,
    required this.shelf,
    this.animateArt = true,
  });

  final bool animateArt;
  final AssetBundle bundle;
  final SeedProvider seedProvider;
  final FeedbackService feedback;
  final StoryShelf shelf;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Future<Pack> _pack = loadPack(widget.bundle);

  /// Dibujos de los cuentos; se carga una vez y se comparte con todos los cuentos.
  late final Future<StageArt?> _art = loadStageArt(widget.bundle);

  /// `null` = «Sorpréndeme» (el caldero elige).
  String? _selectedMoral;

  /// 0 = Inicio, 1 = Paquetes, 2 = Mis cuentos.
  int _tab = 0;

  /// Cuento leído hasta el final que aún no valoraron (se pregunta con calma, no en plena noche).
  PendingStory? _pending;

  /// Ya respondieron la tarjeta pendiente: se deja a la vista con su «gracias» hasta el próximo cuento.
  bool _pendingAnswered = false;
  Future<String?>? _pendingRating;

  @override
  void initState() {
    super.initState();
    widget.shelf.load();
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

  void _openStory(Pack pack, {required int? seed, required String? option}) {
    if (_pendingAnswered) {
      setState(() {
        _pendingAnswered = false;
        _pending = null;
      });
    }
    final engine = StoryEngine(pack);
    // Cada «otro cuento» usa una semilla nueva; el primero, la pedida (o la del reloj).
    var first = true;
    Story next() {
      final s = first && seed != null ? seed : widget.seedProvider();
      first = false;
      return engine.generate(StoryOptions(seed: s, valueId: option));
    }

    final story = next();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPage(
          story: story,
          feedback: widget.feedback,
          shelf: widget.shelf,
          option: option,
          art: _art,
          animate: widget.animateArt,
          onAnother: next,
        ),
      ),
    );
  }

  Future<void> _openSettings() async {
    if (!await askAdult(context) || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsPage(feedback: widget.feedback, bundle: widget.bundle),
      ),
    );
    _refreshPending();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
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
              return Column(
                children: [
                  _TopBar(onSettings: _openSettings),
                  Expanded(
                    child: switch (_tab) {
                      0 => _homeTab(pack),
                      1 => FutureBuilder<StageArt?>(
                          future: _art,
                          builder: (context, art) => PacksTab(
                            onOpenPack: (_) => setState(() => _tab = 0),
                            coverFor: (p) => p.id == 'medieval'
                                ? castleCover(art.data, pack)
                                : null,
                          ),
                        ),
                      _ => MyStoriesTab(
                          shelf: widget.shelf,
                          onOpen: (e) =>
                              _openStory(pack, seed: e.seed, option: e.option),
                        ),
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Palette.skyTop,
        indicatorColor: Palette.amber,
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.nightlight_outlined),
            selectedIcon: Icon(Icons.nightlight, color: Palette.amberDark),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.widgets_outlined),
            selectedIcon: Icon(Icons.widgets, color: Palette.amberDark),
            label: 'Paquetes',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite, color: Palette.amberDark),
            label: 'Mis cuentos',
          ),
        ],
      ),
    );
  }

  Widget _homeTab(Pack pack) {
    final text = Theme.of(context).textTheme;
    final pending = _pending;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            children: [
              FutureBuilder<StageArt?>(
                future: _art,
                builder: (context, art) => HeroBanner(
                  art: art.data,
                  pack: pack,
                  greeting: '¡Hola! ¿Qué cuento\nquieres esta noche?',
                  animate: widget.animateArt,
                ),
              ),
              if (pending != null) ...[
                const SizedBox(height: 18),
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
              const SizedBox(height: 22),
              Text('¿Qué quieres aprender hoy?',
                  style:
                      text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              _moralGrid(pack),
              ListenableBuilder(
                listenable: widget.shelf,
                builder: (context, _) {
                  final last = widget.shelf.recent.isEmpty
                      ? null
                      : widget.shelf.recent.first;
                  if (last == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 22),
                    child: _ContinueCard(
                      entry: last,
                      onTap: () => _openStory(pack,
                          seed: last.seed, option: last.option),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Palette.skyLow.withValues(alpha: 0), Palette.skyLow],
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton.icon(
              onPressed: () =>
                  _openStory(pack, seed: null, option: _selectedMoral),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32)),
                textStyle:
                    text.titleLarge!.copyWith(fontWeight: FontWeight.w800),
              ),
              icon: const Icon(Icons.auto_stories, size: 28),
              label: const Text('Crear cuento'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _moralGrid(Pack pack) {
    final tiles = <Widget>[
      MoralTile(
        name: 'Sorpréndeme',
        style: MoralStyle.surprise,
        selected: _selectedMoral == null,
        onTap: () => setState(() => _selectedMoral = null),
      ),
      for (final moral in pack.morals)
        MoralTile(
          name: moral.name,
          style: MoralStyle.of(moral.id),
          selected: _selectedMoral == moral.id,
          onTap: () => setState(() => _selectedMoral = moral.id),
        ),
    ];
    // De dos en dos; cada fila toma la altura de su tarjeta más alta (así la letra grande no se corta).
    return Column(
      children: [
        for (var i = 0; i < tiles.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: 12),
                Expanded(
                  child: i + 1 < tiles.length ? tiles[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onSettings});

  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 8, 6),
      child: Row(
        children: [
          const Icon(Icons.nightlight_round, color: Palette.amber, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Caldero de Cuentos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800, color: Palette.cream)),
          ),
          IconButton(
            key: const Key('share-app'),
            tooltip: 'Recomendar a un amigo',
            onPressed: () => shareApp(context),
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            key: const Key('open-settings'),
            tooltip: 'Ajustes para adultos',
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.entry, required this.onTap});

  final ShelfEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = MoralStyle.of(entry.moralId);
    return Material(
      color: Palette.card,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(color: style.color, shape: BoxShape.circle),
                child: Icon(style.icon, color: const Color(0xFF1B1233)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Oír otra vez',
                        style:
                            text.labelMedium!.copyWith(color: Palette.amber)),
                    Text(entry.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium!
                            .copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              const Icon(Icons.replay_circle_filled,
                  color: Palette.amber, size: 38),
            ],
          ),
        ),
      ),
    );
  }
}
