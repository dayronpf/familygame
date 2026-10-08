import 'package:flutter/material.dart';

/// Las cinco caritas: icono, color suave (es de noche) y palabra para lectores de pantalla.
const List<({IconData icon, Color color, String label})> _faces = [
  (
    icon: Icons.sentiment_very_dissatisfied,
    color: Color(0xFFE5777B),
    label: 'Nada'
  ),
  (icon: Icons.sentiment_dissatisfied, color: Color(0xFFE8A06B), label: 'Poco'),
  (icon: Icons.sentiment_neutral, color: Color(0xFFE8C96B), label: 'Regular'),
  (icon: Icons.sentiment_satisfied, color: Color(0xFFB6D77E), label: 'Bien'),
  (
    icon: Icons.sentiment_very_satisfied,
    color: Color(0xFF7ED6A1),
    label: '¡Me encantó!'
  ),
];

/// Pregunta de 1 a 5, pensada para el final de un cuento de noche: un solo toque, tranquila,
/// con caritas grandes (las entiende un niño y las pulsa un adulto) y una salida clara («Ahora no»).
class RatingCard extends StatefulWidget {
  const RatingCard({
    super.key,
    required this.onRate,
    required this.onSkip,
    this.title = '¿Cuánto les gustó este cuento?',
    this.onShown,
  });

  final ValueChanged<int> onRate;
  final VoidCallback onSkip;
  final String title;

  /// Se llama una vez cuando la ficha aparece (así sabemos que el cuento llegó al final).
  final VoidCallback? onShown;

  @override
  State<RatingCard> createState() => _RatingCardState();
}

class _RatingCardState extends State<RatingCard> {
  int? _chosen;
  bool _skipped = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onShown?.call());
  }

  void _rate(int value) {
    if (_chosen != null) return;
    setState(() => _chosen = value);
    widget.onRate(value);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    if (_skipped) return const SizedBox.shrink();

    return Card(
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: text.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Un toque nos ayuda a hacer mejores cuentos. No guardamos nada sobre ustedes.',
              style: text.bodySmall
                  ?.copyWith(color: scheme.onSurface.withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _faces.length; i++)
                  _Face(
                    key: Key('rating-${i + 1}'),
                    face: _faces[i],
                    value: i + 1,
                    selected: _chosen == i + 1,
                    dimmed: _chosen != null && _chosen != i + 1,
                    onTap: () => _rate(i + 1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_chosen != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.bedtime_outlined,
                        size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('¡Gracias! Buenas noches.',
                          style: text.bodyMedium,
                          key: const Key('rating-thanks')),
                    ),
                  ],
                ),
              )
            else
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    setState(() => _skipped = true);
                    widget.onSkip();
                  },
                  child: const Text('Ahora no'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    super.key,
    required this.face,
    required this.value,
    required this.selected,
    required this.dimmed,
    required this.onTap,
  });

  final ({IconData icon, Color color, String label}) face;
  final int value;
  final bool selected, dimmed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: 'Valorar con $value de 5: ${face.label}',
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: SizedBox(
          width: 60,
          child: Opacity(
            opacity: dimmed ? 0.35 : 1,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(face.icon, size: selected ? 46 : 40, color: face.color),
                const SizedBox(height: 2),
                Text(
                  face.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: text.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
