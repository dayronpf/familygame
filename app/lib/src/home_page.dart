import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'art/story_stage.dart';
import 'feedback/adult_gate.dart';
import 'feedback/feedback_service.dart';
import 'feedback/feedback_store.dart';
import 'feedback/rating_card.dart';
import 'guide/holograma_guide.dart';
import 'pack_loader.dart';
import 'packs/pack_catalog.dart';
import 'packs/packs_tab.dart';
import 'seed.dart';
import 'settings/app_settings.dart';
import 'settings_page.dart';
import 'share.dart';
import 'shelf/my_stories_tab.dart';
import 'shelf/story_shelf.dart';
import 'story_page.dart';
import 'ui/children_page.dart';
import 'ui/hero_banner.dart';
import 'ui/hero_gender_dialog.dart';
import 'ui/moral_style.dart';
import 'ui/moral_tile.dart';
import 'ui/night_background.dart';
import 'ui/palette.dart';
import 'brand.dart';

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
  /// Packs y dibujos ya leídos, por id de paquete: cada uno se carga una vez y se comparte con todos sus cuentos.
  final Map<String, Future<Pack>> _packs = {};
  final Map<String, Future<StageArt?>> _arts = {};

  Future<Pack> _packFor(String id) =>
      _packs[id] ??= loadPack(widget.bundle, path: packPath(id));

  Future<StageArt?> _artFor(String id) =>
      _arts[id] ??= loadStageArt(widget.bundle, pack: id);

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

  /// Cuenta un cuento. Sin [replay] se usan los ajustes de ahora (edad, nombre y género del niño); al volver a
  /// contar uno guardado se usan los que tenía, para que salga el mismo.
  ///
  /// Un niño guardado con nombre pero sin género (de antes de que fuera obligatorio) se pregunta una vez.
  Future<void> _openStory(
    Pack pack, {
    required int? seed,
    required String? option,
    ShelfEntry? replay,
  }) async {
    final settings = SettingsScope.maybeOf(context);
    final child = settings?.child;
    if (replay == null &&
        child?.heroName != null &&
        child?.heroGender == null) {
      final gender = await askHeroGender(context, child!.heroName!);
      if (gender == null || !mounted) return;
      await settings!.updateChild(heroGender: gender);
      if (!mounted) return;
    }
    _tell(pack, seed: seed, option: option, replay: replay);
  }

  void _tell(
    Pack pack, {
    required int? seed,
    required String? option,
    ShelfEntry? replay,
  }) {
    if (_pendingAnswered) {
      setState(() {
        _pendingAnswered = false;
        _pending = null;
      });
    }
    final child = SettingsScope.maybeOf(context)?.child;
    final age = replay != null ? replay.age : child?.age;
    final heroName = replay != null ? replay.heroName : child?.heroName;
    final heroGender = replay != null ? replay.heroGender : child?.heroGender;
    final childId = replay?.childId ?? child?.id;
    final engine = StoryEngine(pack);
    // Al contar uno guardado se usan las elecciones que se hicieron y no se pregunta; si no, se pregunta salvo
    // que la familia lo haya apagado para este niño.
    final asks = replay == null && (child?.asksQuestions ?? true);
    // Cada «otro cuento» usa una semilla nueva; el primero, la pedida (o la del reloj).
    var first = true;
    StoryRun next() {
      final s = first && seed != null ? seed : widget.seedProvider();
      first = false;
      return engine.begin(StoryOptions(
        seed: s,
        valueId: option,
        age: age,
        heroName: heroName,
        heroGender: heroGender,
        choices: replay?.choices ?? const [],
        interactive: asks,
      ));
    }

    final run = next();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StoryPage(
          story: run.story,
          run: run,
          feedback: widget.feedback,
          shelf: widget.shelf,
          option: option,
          age: age,
          heroName: heroName,
          heroGender: heroGender,
          childId: childId,
          art: _artFor(pack.id),
          animate: widget.animateArt,
          onAnother: () => next().toStory(),
          onAnotherRun: next,
        ),
      ),
    );
  }

  /// Vuelve a contar un cuento guardado con su propio paquete (puede no ser el que está abierto).
  Future<void> _replay(ShelfEntry e) async {
    final Pack pack;
    try {
      pack = await _packFor(e.packId);
    } catch (_) {
      return; // un paquete que ya no está en la app
    }
    if (!mounted) return;
    await _openStory(pack, seed: e.seed, option: e.option, replay: e);
  }

  /// La portada dibujada de la tarjeta de un paquete (vacía mientras carga o si aún no tiene arte).
  Widget _coverFor(PackInfo info) => FutureBuilder<(Pack, StageArt?)>(
        future: Future.wait([_packFor(info.id), _artFor(info.id)])
            .then((r) => (r[0] as Pack, r[1] as StageArt?)),
        builder: (context, snap) => snap.data == null
            ? const SizedBox.shrink()
            : packCover(snap.data!.$2, snap.data!.$1, cover: info.cover),
      );

  Future<void> _openSettings(Set<String> agesWithStories) async {
    if (!await askAdult(context) || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          feedback: widget.feedback,
          bundle: widget.bundle,
          shelf: widget.shelf,
          agesWithStories: agesWithStories,
        ),
      ),
    );
    _refreshPending();
  }

  /// Elegir a otro niño (sin pedir la pregunta de adultos: cambiar de niño no cambia nada importante).
  Future<void> _switchChild() async {
    final settings = SettingsScope.maybeOf(context);
    if (settings == null) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Palette.card,
      builder: (context) => SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Text('¿Para quién es el cuento?',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (var i = 0; i < settings.profiles.length; i++)
                ListTile(
                  key: Key('switch-${settings.profiles[i].id}'),
                  leading: ChildAvatar(profile: settings.profiles[i], index: i),
                  title: Text(settings.profiles[i].label(i)),
                  trailing: i == settings.activeIndex
                      ? const Icon(Icons.check_circle, color: Palette.amber)
                      : null,
                  onTap: () {
                    settings.selectChild(i);
                    Navigator.pop(context);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // Se vuelve a dibujar al cambiar de niño; el estante enseña solo los cuentos del activo.
    final settings = SettingsScope.watch(context);
    widget.shelf.viewer = settings?.child.id;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          bottom: false,
          child: FutureBuilder<Pack>(
            future: _packFor(settings?.packId ?? defaultPackId),
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
                  _TopBar(
                    onSettings: () => _openSettings(pack.agesWithStories),
                    settings: settings,
                    onSwitchChild: _switchChild,
                  ),
                  Expanded(
                    child: switch (_tab) {
                      0 => _homeTab(pack),
                      1 => PacksTab(
                          onOpenPack: (p) {
                            settings?.setPack(p.id);
                            setState(() => _tab = 0);
                          },
                          coverFor: _coverFor,
                          openId: pack.id,
                        ),
                      _ => MyStoriesTab(
                          shelf: widget.shelf,
                          onOpen: _replay,
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
                future: _artFor(pack.id),
                builder: (context, art) => HeroBanner(
                  art: art.data,
                  pack: pack,
                  cover: packInfo(pack.id).cover,
                  greeting: SettingsScope.maybeOf(context)?.child.heroName ==
                          null
                      ? '¡Hola! ¿Qué cuento\nquieres esta noche?'
                      : '¡Hola, ${SettingsScope.maybeOf(context)!.child.heroName}!\n¿Qué cuento quieres?',
                  heroGender: SettingsScope.maybeOf(context)?.child.heroGender,
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
                          seed: last.seed, option: last.option, replay: last),
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),
              _GuideCard(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => HologramGuidePage(bundle: widget.bundle),
                  ),
                ),
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
    // Al cambiar de paquete, una enseñanza elegida que aquí no tiene cuentos vuelve a «Sorpréndeme»
    if (_selectedMoral != null &&
        !pack.moralsWithStories.any((m) => m.id == _selectedMoral)) {
      _selectedMoral = null;
    }
    final tiles = <Widget>[
      MoralTile(
        name: 'Sorpréndeme',
        style: MoralStyle.surprise,
        selected: _selectedMoral == null,
        onTap: () => setState(() => _selectedMoral = null),
      ),
      for (final moral in pack.moralsWithStories)
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
  const _TopBar({
    required this.onSettings,
    required this.onSwitchChild,
    this.settings,
  });

  final VoidCallback onSettings;
  final VoidCallback onSwitchChild;
  final AppSettings? settings;

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
            child: Text(appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800, color: Palette.cream)),
          ),
          if (settings != null && settings!.profiles.length > 1)
            IconButton(
              key: const Key('child-switch'),
              tooltip: 'Cambiar de niño',
              onPressed: onSwitchChild,
              icon: ChildAvatar(
                profile: settings!.child,
                index: settings!.activeIndex,
                radius: 15,
              ),
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

/// Invitación (discreta) a armar el holograma en casa; lleva a la guía y al PDF.
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      key: const Key('guide-card'),
      color: Palette.cardSoft,
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
                decoration: const BoxDecoration(
                    color: Palette.teal, shape: BoxShape.circle),
                child: const Icon(Icons.view_in_ar, color: Color(0xFF06322C)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Holograma en casa',
                        style: text.titleMedium!
                            .copyWith(fontWeight: FontWeight.w800)),
                    Text('Haz una pirámide con un adulto',
                        style:
                            text.bodySmall!.copyWith(color: Palette.mutedText)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Palette.amber),
            ],
          ),
        ),
      ),
    );
  }
}
