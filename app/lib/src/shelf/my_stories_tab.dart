import 'package:flutter/material.dart';

import '../ui/moral_style.dart';
import '../ui/palette.dart';
import 'story_shelf.dart';

/// Qué se ve en «Mis cuentos».
enum ShelfFilter { all, favorites, unfinished }

/// «Mis cuentos»: los que guardaron con el corazón y los últimos que contaron, para volver a oírlos. Arriba,
/// unos filtros: todos, favoritos o los que no se leyeron hasta el final.
class MyStoriesTab extends StatefulWidget {
  const MyStoriesTab({super.key, required this.shelf, required this.onOpen});

  final StoryShelf shelf;
  final void Function(ShelfEntry entry) onOpen;

  @override
  State<MyStoriesTab> createState() => _MyStoriesTabState();
}

class _MyStoriesTabState extends State<MyStoriesTab> {
  ShelfFilter _filter = ShelfFilter.all;

  StoryShelf get shelf => widget.shelf;
  void Function(ShelfEntry entry) get onOpen => widget.onOpen;

  Widget _chips() {
    Widget chip(ShelfFilter f, String label, IconData icon) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            key: Key('shelf-filter-${f.name}'),
            avatar: Icon(icon, size: 18),
            label: Text(label),
            selected: _filter == f,
            onSelected: (_) => setState(() => _filter = f),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        children: [
          chip(ShelfFilter.all, 'Todos', Icons.auto_stories),
          chip(ShelfFilter.favorites, 'Favoritos', Icons.favorite),
          chip(ShelfFilter.unfinished, 'Sin terminar', Icons.bookmark_border),
        ],
      ),
    );
  }

  /// Favoritos y recientes juntos, sin repetir.
  List<ShelfEntry> _everything() {
    final seen = <String>{};
    return [
      for (final e in [...shelf.favorites, ...shelf.recent])
        if (seen.add(e.key)) e,
    ];
  }

  Widget _filtered(List<ShelfEntry> list, String empty) {
    final text = Theme.of(context).textTheme;
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(empty,
              textAlign: TextAlign.center,
              style: text.bodyLarge!.copyWith(color: Palette.mutedText)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        for (final e in list) _EntryTile(entry: e, shelf: shelf, onOpen: onOpen)
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: shelf,
      builder: (context, _) {
        final favorites = shelf.favorites;
        final recent = shelf.recent;
        if (favorites.isEmpty && recent.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Palette.card,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Palette.amber.withValues(alpha: 0.5),
                          width: 2),
                    ),
                    child: const Icon(Icons.auto_stories,
                        size: 54, color: Palette.amber),
                  ),
                  const SizedBox(height: 20),
                  Text('Aquí vivirán tus cuentos',
                      textAlign: TextAlign.center,
                      style: text.titleLarge!
                          .copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                    'Cuenta un cuento y toca el corazón para guardarlo. Los últimos que oigas también aparecerán aquí.',
                    textAlign: TextAlign.center,
                    style: text.bodyLarge!.copyWith(color: Palette.mutedText),
                  ),
                ],
              ),
            ),
          );
        }
        final Widget body = switch (_filter) {
          ShelfFilter.favorites => _filtered(favorites,
              'Aún no hay favoritos. Toca el corazón de un cuento para guardarlo aquí.'),
          ShelfFilter.unfinished => _filtered([
              for (final e in _everything())
                if (!shelf.isFinished(e)) e
            ], '¡Todos los cuentos se leyeron hasta el final!'),
          ShelfFilter.all => _allList(favorites, recent),
        };
        return Column(
          children: [
            _chips(),
            Expanded(child: body),
          ],
        );
      },
    );
  }

  Widget _allList(List<ShelfEntry> favorites, List<ShelfEntry> recent) =>
      ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (favorites.isNotEmpty) ...[
            _Heading(
                icon: Icons.favorite,
                color: const Color(0xFFFF7A9C),
                title: 'Mis favoritos'),
            for (final e in favorites)
              _EntryTile(entry: e, shelf: shelf, onOpen: onOpen),
            const SizedBox(height: 18),
          ],
          if (recent.isNotEmpty) ...[
            _Heading(
              icon: Icons.history,
              color: Palette.teal,
              title: 'Los últimos cuentos',
              action: TextButton(
                onPressed: shelf.clearRecent,
                child: const Text('Borrar'),
              ),
            ),
            for (final e in recent)
              _EntryTile(entry: e, shelf: shelf, onOpen: onOpen),
          ],
        ],
      );
}

class _Heading extends StatelessWidget {
  const _Heading(
      {required this.icon,
      required this.color,
      required this.title,
      this.action});

  final IconData icon;
  final Color color;
  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontWeight: FontWeight.w800)),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile(
      {required this.entry, required this.shelf, required this.onOpen});

  final ShelfEntry entry;
  final StoryShelf shelf;
  final void Function(ShelfEntry entry) onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = MoralStyle.of(entry.moralId);
    final fav = shelf.isFavorite(entry);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Palette.card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => onOpen(entry),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration:
                      BoxDecoration(color: style.color, shape: BoxShape.circle),
                  child: Icon(style.icon, color: const Color(0xFF1B1233)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium!
                              .copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        [
                          if (entry.hero.isNotEmpty) entry.hero,
                          entry.moral,
                          if (shelf.isFinished(entry)) 'leído ✓',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            text.bodyMedium!.copyWith(color: Palette.mutedText),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: fav ? 'Quitar de favoritos' : 'Guardar en favoritos',
                  onPressed: () => shelf.toggleFavorite(entry),
                  icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                      color: fav ? const Color(0xFFFF7A9C) : Palette.mutedText),
                ),
                const Icon(Icons.play_circle_fill,
                    color: Palette.amber, size: 34),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
