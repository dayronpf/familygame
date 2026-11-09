import 'package:flutter/material.dart';

import '../ui/palette.dart';
import 'catalog_widgets.dart';
import 'story_catalog.dart';

/// Pestaña «Explorar»: buscador, *Novedades* en carrusel, *Categorías* (edad, cortos, enseñanza, paquete) y
/// un acceso a los paquetes.
class ExploreTab extends StatefulWidget {
  const ExploreTab({
    super.key,
    required this.catalog,
    required this.previews,
    required this.artFor,
    required this.onOpen,
    required this.onPacks,
  });

  final StoryCatalog catalog;
  final CatalogPreviews previews;
  final ArtFor artFor;
  final void Function(CatalogStory story) onOpen;

  /// Abre la lista de paquetes (los suyos y los que vienen).
  final VoidCallback onPacks;

  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Widget _row(CatalogStory s) => StoryRow(
        story: s,
        preview: widget.previews.of(s),
        artFor: widget.artFor,
        onTap: () => widget.onOpen(s),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final q = _query.text.trim();
    final results = widget.catalog.search(q);
    final newest = widget.catalog.newest.take(10).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        TextField(
          key: const Key('explore-search'),
          controller: _query,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar un cuento, una enseñanza…',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: q.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar',
                    onPressed: () => setState(_query.clear),
                    icon: const Icon(Icons.close),
                  ),
            filled: true,
            fillColor: Palette.card,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (q.isNotEmpty) ...[
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('No encontramos cuentos con «$q».',
                  textAlign: TextAlign.center,
                  style: text.bodyLarge!.copyWith(color: Palette.mutedText)),
            ),
          for (final s in results) _row(s),
        ] else ...[
          if (newest.isNotEmpty) ...[
            Text('Novedades',
                style: text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            SizedBox(
              height: 280,
              child: ListView.separated(
                key: const Key('explore-newest'),
                scrollDirection: Axis.horizontal,
                itemCount: newest.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, i) => SizedBox(
                  width: 210,
                  child: StoryCard(
                    story: newest[i],
                    preview: widget.previews.of(newest[i]),
                    artFor: widget.artFor,
                    coverHeight: null,
                    onTap: () => widget.onOpen(newest[i]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),
          ],
          Text('Categorías',
              style: text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          for (final c in widget.catalog.categories)
            ListTile(
              key: Key('category-${c.id}'),
              contentPadding: EdgeInsets.zero,
              leading: Text(c.emoji, style: const TextStyle(fontSize: 30)),
              title: Text(c.title,
                  style:
                      text.titleMedium!.copyWith(fontWeight: FontWeight.w700)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${c.stories.length}',
                      style: text.bodyLarge!.copyWith(
                          color: Palette.mutedText,
                          fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right, color: Palette.mutedText),
                ],
              ),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => CategoryPage(
                  category: c,
                  previews: widget.previews,
                  artFor: widget.artFor,
                  onOpen: widget.onOpen,
                ),
              )),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            key: const Key('explore-packs'),
            onPressed: widget.onPacks,
            icon: const Icon(Icons.widgets_outlined),
            label: const Text('Ver todos los paquetes'),
          ),
        ],
      ],
    );
  }
}

/// Los cuentos de una categoría, en lista.
class CategoryPage extends StatelessWidget {
  const CategoryPage({
    super.key,
    required this.category,
    required this.previews,
    required this.artFor,
    required this.onOpen,
  });

  final CatalogCategory category;
  final CatalogPreviews previews;
  final ArtFor artFor;
  final void Function(CatalogStory story) onOpen;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Palette.skyLow,
        appBar: AppBar(
          backgroundColor: Palette.skyTop,
          title: Text('${category.emoji}  ${category.title}'),
        ),
        body: ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: category.stories.length,
          itemBuilder: (context, i) {
            final s = category.stories[i];
            return StoryRow(
              story: s,
              preview: previews.of(s),
              artFor: artFor,
              onTap: () => onOpen(s),
            );
          },
        ),
      );
}
