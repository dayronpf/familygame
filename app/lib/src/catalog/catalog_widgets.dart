import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import '../art/scene_painter.dart';
import '../art/story_stage.dart';
import '../ui/moral_style.dart';
import '../ui/palette.dart';
import 'story_catalog.dart';

/// Dibujos de cada paquete (se cargan una vez y se comparten).
typedef ArtFor = Future<StageArt?> Function(String packId);

/// Vistas previas de los cuentos del catálogo para el niño activo (su nombre y su género), generadas una vez.
class CatalogPreviews {
  CatalogPreviews({this.childAge, this.heroName, this.heroGender});

  final String? childAge;
  final String? heroName;
  final String? heroGender;
  final Map<String, Story?> _cache = {};

  /// El cuento tal como se leerá (sin preguntas: lo que falte se elige solo). `null` si no se pudo armar.
  Story? of(CatalogStory s) => _cache.putIfAbsent(s.key, () {
        try {
          return StoryEngine(s.pack).generate(s.options(
            childAge: childAge,
            heroName: heroName,
            heroGender: heroGender,
          ));
        } catch (_) {
          return null;
        }
      });

  bool sameChild(String? age, String? name, String? gender) =>
      age == childAge && name == heroName && gender == heroGender;
}

/// La ilustración de la primera escena del cuento, quieta, cubriendo todo su hueco. Mientras carga el arte (o si
/// falta), un degradado con el color de su enseñanza.
class StoryCover extends StatelessWidget {
  const StoryCover({
    super.key,
    required this.story,
    required this.preview,
    required this.artFor,
  });

  final CatalogStory story;
  final Story? preview;
  final ArtFor artFor;

  @override
  Widget build(BuildContext context) {
    final style = MoralStyle.of(story.moral?.id ?? '');
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: story.info.colors,
        ),
      ),
      child: Center(
        child: Icon(style.icon,
            size: 48, color: Colors.white.withValues(alpha: 0.6)),
      ),
    );
    final p = preview;
    if (p == null || p.scenes.isEmpty) return fallback;
    return FutureBuilder<StageArt?>(
      future: artFor(story.pack.id),
      builder: (context, snap) {
        final art = snap.data;
        final setup = art == null
            ? null
            : stageFor(art, p.cast, p.scenes.first.directives);
        if (setup == null) return fallback;
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: setup.view.width,
              height: setup.view.height,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: ScenePainter(
                    scene: setup.scene,
                    actors: setup.actors,
                    props: setup.props,
                    clock: ValueNotifier<double>(0.5),
                    view: setup.view,
                    tint: setup.tint,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Insignia pequeña sobre la ilustración («Nuevo»).
class NewBadge extends StatelessWidget {
  const NewBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE5566B),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text('Nuevo',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13)),
      );
}

/// «⏱ 6 min · 🙂 4+», la línea de datos de un cuento.
class StoryFacts extends StatelessWidget {
  const StoryFacts({super.key, required this.story, this.center = false});

  final CatalogStory story;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(color: Palette.mutedText, fontWeight: FontWeight.w700);
    return Row(
      mainAxisAlignment:
          center ? MainAxisAlignment.center : MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.schedule, size: 16, color: Palette.mutedText),
        const SizedBox(width: 4),
        Text('${story.minutes} min', style: style),
        const SizedBox(width: 12),
        const Icon(Icons.child_care, size: 16, color: Palette.mutedText),
        const SizedBox(width: 4),
        Text(story.minAgeBadge, style: style),
      ],
    );
  }
}

/// Tarjeta grande: ilustración arriba y, debajo, título, enseñanza y datos (Recomendado, Novedades).
class StoryCard extends StatelessWidget {
  const StoryCard({
    super.key,
    required this.story,
    required this.preview,
    required this.artFor,
    required this.onTap,
    this.coverHeight = 190,
  });

  final CatalogStory story;
  final Story? preview;
  final ArtFor artFor;
  final VoidCallback onTap;

  /// Alto de la ilustración; `null` = la que quede (en un hueco de alto fijo, como el carrusel, se encoge para que
  /// el título siempre quepa).
  final double? coverHeight;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = MoralStyle.of(story.moral?.id ?? '');
    final cover = Stack(
      fit: StackFit.expand,
      children: [
        StoryCover(story: story, preview: preview, artFor: artFor),
        if (story.isNew)
          const Positioned(top: 12, right: 12, child: NewBadge()),
      ],
    );
    return Material(
      key: Key('story-card-${story.key}'),
      color: Color.lerp(Palette.card, style.color, 0.18),
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (coverHeight == null)
              Expanded(child: cover)
            else
              SizedBox(height: coverHeight, child: cover),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  Text(story.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleLarge!
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (story.moral != null) story.moral!.name,
                      story.info.name
                    ].join(' · '),
                    textAlign: TextAlign.center,
                    style: text.bodyMedium!.copyWith(color: Palette.mutedText),
                  ),
                  const SizedBox(height: 6),
                  StoryFacts(story: story, center: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de lista: miniatura, título, enseñanza y datos (categorías y búsqueda).
class StoryRow extends StatelessWidget {
  const StoryRow({
    super.key,
    required this.story,
    required this.preview,
    required this.artFor,
    required this.onTap,
  });

  final CatalogStory story;
  final Story? preview;
  final ArtFor artFor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      key: Key('story-row-${story.key}'),
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryCover(story: story, preview: preview, artFor: artFor),
                    if (story.isNew)
                      Positioned(
                        top: 6,
                        left: 6,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                              color: Color(0xFFE5566B), shape: BoxShape.circle),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(story.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium!
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (story.moral != null) story.moral!.name,
                      story.info.name
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium!.copyWith(color: Palette.mutedText),
                  ),
                  const SizedBox(height: 6),
                  StoryFacts(story: story),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Palette.amber),
          ],
        ),
      ),
    );
  }
}
