import 'package:flutter/material.dart';

import '../ui/palette.dart';

/// Qué hace un aviso al tocarlo.
enum NewsAction { explore, packs, none }

/// Un aviso del inicio («comunicados»): novedades de la app, siempre cerrables y nunca dirigidos al niño para
/// comprar. Viven aquí, en el código, y se cambian con cada versión.
class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.colors,
    this.action = NewsAction.none,
    this.actionLabel,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final List<Color> colors;
  final NewsAction action;
  final String? actionLabel;
}

const List<NewsItem> newsItems = [
  NewsItem(
    id: 'explorar-2026-11',
    title: '¡Nuevo! Explora los cuentos',
    body:
        'Busca por edad, por enseñanza o por paquete, y mira de qué va cada cuento antes de leerlo.',
    icon: Icons.explore,
    colors: [Color(0xFF6B4FD8), Color(0xFF3B2A8A)],
    action: NewsAction.explore,
    actionLabel: 'Explorar',
  ),
  NewsItem(
    id: 'aldea-nubes',
    title: 'Llegó la Aldea de las Nubes',
    body:
        'Cohetes, planetas y un robot amable: treinta cuentos para soñar despacio.',
    icon: Icons.rocket_launch,
    colors: [Color(0xFFE05A8B), Color(0xFF7A2A6A)],
    action: NewsAction.explore,
    actionLabel: 'Ver novedades',
  ),
  NewsItem(
    id: 'leemos-juntos',
    title: 'Léele tú el cuento',
    body:
        'En la ficha de cada cuento toca «Leemos juntos»: letra grande para leer en voz alta, con calma.',
    icon: Icons.menu_book,
    colors: [Color(0xFF2FA7C9), Color(0xFF1B5E8C)],
  ),
];

/// Carrusel de avisos con puntos de página y una ✕ para cerrar cada uno. Si no queda ninguno, no ocupa sitio.
class NewsCarousel extends StatefulWidget {
  const NewsCarousel({
    super.key,
    required this.items,
    required this.onDismiss,
    required this.onAction,
  });

  final List<NewsItem> items;
  final void Function(NewsItem item) onDismiss;
  final void Function(NewsItem item) onAction;

  @override
  State<NewsCarousel> createState() => _NewsCarouselState();
}

class _NewsCarouselState extends State<NewsCarousel> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    if (items.isEmpty) return const SizedBox.shrink();
    final page = _page.clamp(0, items.length - 1);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            key: const Key('news-carousel'),
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) {
              final n = items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DecoratedBox(
                  key: Key('news-${n.id}'),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: n.colors,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 16, 48, 14),
                        child: Row(
                          children: [
                            Icon(n.icon, size: 44, color: Palette.cream),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(n.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.titleMedium!.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: Palette.cream)),
                                  const SizedBox(height: 4),
                                  Flexible(
                                    child: Text(n.body,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: text.bodyMedium!
                                            .copyWith(color: Palette.cream)),
                                  ),
                                  if (n.actionLabel != null)
                                    TextButton(
                                      key: Key('news-action-${n.id}'),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        foregroundColor: Palette.amber,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      onPressed: () => widget.onAction(n),
                                      child: Text('${n.actionLabel} ›'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: IconButton(
                          key: Key('news-close-${n.id}'),
                          tooltip: 'Cerrar aviso',
                          onPressed: () => widget.onDismiss(n),
                          icon: const Icon(Icons.close, color: Palette.cream),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < items.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == page ? 18 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == page ? Palette.amber : Palette.cardSoft,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
