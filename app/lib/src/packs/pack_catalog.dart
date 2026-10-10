import 'package:flutter/material.dart';

import '../share.dart';
import '../ui/palette.dart';

/// Si el paquete se puede abrir ya o llegará más adelante.
enum PackStatus { available, soon }

/// Un paquete de cuentos de la tienda: su portada, su tema y su estado.
class PackInfo {
  const PackInfo({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.icon,
    required this.colors,
    this.status = PackStatus.soon,
  });

  final String id;
  final String name;
  final String tagline;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final PackStatus status;

  bool get available => status == PackStatus.available;
}

/// Catálogo que ve la familia. Hoy solo el Reino de la Luna se puede abrir; los demás se ven en gris
/// (próximamente: serán de pago). El contenido real de cada paquete vive en `content/packs/<id>`.
const List<PackInfo> packCatalog = [
  PackInfo(
    id: 'medieval',
    name: 'Reino de la Luna',
    tagline: 'Castillos, magos y valientes',
    description:
        'Cuentos de un reino medieval: campanas rotas, linternas apagadas, puentes que crujen y '
        'semillas que se vuelven soles. Con enseñanzas de honestidad, generosidad y valentía.',
    icon: Icons.castle_outlined,
    colors: [Color(0xFF6B4FD8), Color(0xFF3B2A8A)],
    status: PackStatus.available,
  ),
  PackInfo(
    id: 'mar',
    name: 'Mar de las Estrellas',
    tagline: 'Piratas y sirenas',
    description:
        'Barcos que navegan de noche, mapas del tesoro y sirenas que cantan nanas. Aventuras suaves para '
        'aprender a compartir el botín.',
    icon: Icons.sailing_outlined,
    colors: [Color(0xFF2FA7C9), Color(0xFF1B5E8C)],
  ),
  PackInfo(
    id: 'bosque',
    name: 'Bosque Susurrante',
    tagline: 'Animales que hablan bajito',
    description:
        'Zorros tímidos, búhos sabios y un bosque que cuenta secretos. Cuentos tranquilos sobre la amistad '
        'y cuidar a los demás.',
    icon: Icons.forest_outlined,
    colors: [Color(0xFF3FB27F), Color(0xFF1F6B4F)],
  ),
  PackInfo(
    id: 'cosmos',
    name: 'Aldea de las Nubes',
    tagline: 'Cohetes y planetas',
    description:
        'Un viaje entre estrellas con robots amables y un perrito astronauta. Cuentos para soñar despacio y '
        'perder el miedo a la oscuridad.',
    icon: Icons.rocket_launch_outlined,
    colors: [Color(0xFFE05A8B), Color(0xFF7A2A6A)],
  ),
  PackInfo(
    id: 'granja',
    name: 'Granja Alegre',
    tagline: 'Gallinas, vacas y huertos',
    description:
        'Un día entero en la granja: cuidar las semillas, esperar a que crezcan y repartir la cosecha. '
        'Ideal para los más pequeños.',
    icon: Icons.agriculture_outlined,
    colors: [Color(0xFFF2A33A), Color(0xFFB8641E)],
  ),
];

/// Matriz de color para pasar un dibujo a escala de grises.
const ColorFilter greyscale = ColorFilter.matrix(<double>[
  0.2126, 0.7152, 0.0722, 0, 0, //
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
]);

/// La portada de un paquete: a color si se puede abrir; en gris, con candado y una cinta «Pronto» si no.
class PackCard extends StatelessWidget {
  const PackCard({
    super.key,
    required this.pack,
    required this.onTap,
    this.cover,
    this.width = 168,
    this.height = 210,
  });

  final PackInfo pack;
  final VoidCallback onTap;

  /// Ilustración opcional que sustituye al icono (el castillo dibujado por la app).
  final Widget? cover;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final soon = !pack.available;
    Widget face = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: pack.colors,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: cover != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(26), child: cover)
                : Align(
                    alignment: const Alignment(0, -0.35),
                    child: Icon(pack.icon,
                        size: 74, color: Colors.white.withValues(alpha: 0.92)),
                  ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
              decoration: BoxDecoration(
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(26)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.62)
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    pack.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium!.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pack.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall!.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (soon) {
      face = ColorFiltered(
          colorFilter: greyscale, child: Opacity(opacity: 0.85, child: face));
    }
    return Semantics(
      button: true,
      label: soon ? '${pack.name}, próximamente' : '${pack.name}, disponible',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              face,
              if (soon) ...[
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.lock_outline,
                        size: 18, color: Colors.white),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: const BoxDecoration(
                      color: Palette.amber,
                      borderRadius:
                          BorderRadius.horizontal(right: Radius.circular(12)),
                    ),
                    child: Text(
                      'Pronto',
                      style: text.labelMedium!.copyWith(
                        color: Palette.amberDark,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ] else
                Positioned(
                  top: 14,
                  left: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Palette.teal,
                      borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(12)),
                    ),
                    child: Text(
                      'Tuyo',
                      style: text.labelMedium!.copyWith(
                        color: const Color(0xFF06322C),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hoja con lo que traerá un paquete que aún no está disponible.
Future<void> showSoonSheet(BuildContext context, PackInfo pack) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.card,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) {
      final text = Theme.of(context).textTheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ColorFiltered(
                      colorFilter: greyscale,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: pack.colors),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(pack.icon, color: Colors.white, size: 36),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pack.name,
                              style: text.titleLarge!
                                  .copyWith(fontWeight: FontWeight.w800)),
                          Text(pack.tagline,
                              style: text.bodyMedium!
                                  .copyWith(color: Palette.mutedText)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(pack.description, style: text.bodyLarge),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Palette.amber.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_top, color: Palette.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Próximamente. Será un paquete de pago: los cuentos del Reino de la Luna seguirán '
                          'siendo gratis.',
                          style: text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => shareApp(context),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Recomendar a un amigo'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Entendido'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
