import 'package:flutter/material.dart';

import '../share.dart';
import '../ui/palette.dart';
import 'pack_catalog.dart';

/// Pestaña «Paquetes»: los que ya son suyos, a color; los que llegarán, en gris; y una invitación a
/// recomendar la app a un amigo.
class PacksTab extends StatelessWidget {
  const PacksTab({super.key, required this.onOpenPack, this.coverFor});

  /// Se toca un paquete disponible.
  final void Function(PackInfo pack) onOpenPack;

  /// Ilustración opcional de un paquete (el castillo dibujado por la app).
  final Widget? Function(PackInfo pack)? coverFor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final mine = packCatalog.where((p) => p.available).toList();
    final soon = packCatalog.where((p) => !p.available).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Text('Tus paquetes',
            style: text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) => Column(
            children: [
              for (final p in mine)
                PackCard(
                  pack: p,
                  cover: coverFor?.call(p),
                  width: c.maxWidth,
                  height: 190,
                  onTap: () => onOpenPack(p),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text('Próximamente',
                  style:
                      text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
            ),
            const Icon(Icons.lock_clock, color: Palette.mutedText),
          ],
        ),
        const SizedBox(height: 4),
        Text(
            'Nuevos mundos de cuentos, para cuando termines con el Reino de la Luna.',
            style: text.bodyMedium!.copyWith(color: Palette.mutedText)),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) => Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final p in soon)
                PackCard(
                  pack: p,
                  width: (c.maxWidth - 14) / 2,
                  onTap: () => showSoonSheet(context, p),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _ShareCard(),
      ],
    );
  }
}

class _ShareCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF3B2A8A), Color(0xFF6B4FD8)]),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, color: Palette.amber, size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text('¿Se lo cuentas a un amigo?',
                    style: text.titleMedium!
                        .copyWith(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
              'Recomienda Caldero de Cuentos a otra familia: más niños durmiendo con un buen cuento.',
              style: text.bodyMedium),
          const SizedBox(height: 14),
          FilledButton.icon(
            key: const Key('share-card'),
            onPressed: () => shareApp(context),
            icon: const Icon(Icons.ios_share),
            label: const Text('Compartir con un amigo'),
          ),
        ],
      ),
    );
  }
}
