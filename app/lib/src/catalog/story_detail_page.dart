import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import '../share.dart';
import '../shelf/story_shelf.dart';
import '../story_page.dart';
import '../ui/moral_style.dart';
import '../ui/palette.dart';
import 'catalog_widgets.dart';
import 'story_catalog.dart';

/// Ficha de un cuento antes de abrirlo: la ilustración, su enseñanza, compartir y guardar, los botones
/// **Leer / Escuchar**, cuánto dura, cuántas escenas tiene, para qué edad es y cómo empieza.
class StoryDetailPage extends StatelessWidget {
  const StoryDetailPage({
    super.key,
    required this.story,
    required this.preview,
    required this.artFor,
    required this.shelf,
    required this.onStart,
    this.entry,
  });

  final CatalogStory story;
  final Story? preview;
  final ArtFor artFor;
  final StoryShelf shelf;

  /// Abre el cuento en el modo elegido.
  final void Function(StoryStart start) onStart;

  /// Cómo queda en «Mis cuentos» (para el botón de guardar). `null` si no se pudo armar la vista previa.
  final ShelfEntry? entry;

  /// El principio del cuento, unas 3 líneas.
  String get _synopsis {
    final p = preview;
    if (p == null || p.scenes.isEmpty) return '';
    final first = p.scenes.first.text.trim();
    if (first.length <= 320) return first;
    final cut = first.lastIndexOf(' ', 300);
    return '${first.substring(0, cut < 0 ? 300 : cut)}…';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = MoralStyle.of(story.moral?.id ?? '');
    final e = entry;
    return Scaffold(
      backgroundColor: Palette.skyLow,
      body: ListenableBuilder(
        listenable: shelf,
        builder: (context, _) => CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Palette.skyTop,
              leading: IconButton(
                key: const Key('detail-back'),
                tooltip: 'Volver',
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const CircleAvatar(
                  backgroundColor: Color(0x88000000),
                  child: Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    StoryCover(story: story, preview: preview, artFor: artFor),
                    if (story.isNew)
                      const Positioned(
                          right: 16, bottom: 16, child: NewBadge()),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, color: style.color, size: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            [
                              if (story.moral != null) story.moral!.name,
                              story.info.name,
                            ].join(' · '),
                            style: text.bodyLarge!
                                .copyWith(color: Palette.mutedText),
                          ),
                        ),
                        IconButton(
                          key: const Key('detail-share'),
                          tooltip: 'Compartir',
                          onPressed: () => shareStory(context, story.title),
                          icon:
                              const Icon(Icons.ios_share, color: Palette.amber),
                        ),
                        if (e != null)
                          IconButton(
                            key: const Key('detail-favorite'),
                            tooltip: shelf.isFavorite(e)
                                ? 'Quitar de favoritos'
                                : 'Guardar en favoritos',
                            onPressed: () => shelf.toggleFavorite(e),
                            icon: Icon(
                              shelf.isFavorite(e)
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: const Color(0xFFFF7A9C),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(story.title,
                        style: text.headlineMedium!
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 18),
                    _ReadListenButtons(onStart: onStart),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        key: const Key('detail-together'),
                        onPressed: () => onStart(StoryStart.together),
                        icon: const Icon(Icons.menu_book),
                        label: const Text('Leemos juntos (letra grande)'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Palette.cardSoft),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      children: [
                        _Fact(Icons.schedule, '${story.minutes} min'),
                        _Fact(Icons.photo_library_outlined,
                            '${story.scenes} escenas'),
                        _Fact(Icons.child_care, story.agesLabel),
                        if (e != null && shelf.isFinished(e))
                          const _Fact(Icons.check_circle, 'Ya lo leyeron'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Divider(color: Palette.cardSoft),
                    const SizedBox(height: 12),
                    if (_synopsis.isNotEmpty)
                      Text(_synopsis,
                          key: const Key('detail-synopsis'),
                          style: text.bodyLarge!.copyWith(height: 1.45)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadListenButtons extends StatelessWidget {
  const _ReadListenButtons({required this.onStart});

  final void Function(StoryStart start) onStart;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget half(String label, IconData icon, StoryStart start, Key key,
            BorderRadius radius) =>
        Expanded(
          child: Material(
            color: Palette.amber,
            borderRadius: radius,
            child: InkWell(
              key: key,
              borderRadius: radius,
              onTap: () => onStart(start),
              child: SizedBox(
                height: 60,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // Con letra muy grande se encoge en vez de salirse del botón.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: const Color(0xFF1B1233)),
                        const SizedBox(width: 8),
                        Text(label,
                            style: text.titleLarge!.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1B1233))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(
      children: [
        half(
            'Leer',
            Icons.auto_stories,
            StoryStart.reader,
            const Key('detail-read'),
            const BorderRadius.horizontal(left: Radius.circular(30))),
        const SizedBox(width: 2),
        half(
            'Escuchar',
            Icons.volume_up,
            StoryStart.listen,
            const Key('detail-listen'),
            const BorderRadius.horizontal(right: Radius.circular(30))),
      ],
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: Palette.mutedText),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: Palette.cream, fontWeight: FontWeight.w700)),
        ],
      );
}
