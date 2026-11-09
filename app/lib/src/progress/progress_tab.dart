import 'package:flutter/material.dart';

import '../ui/palette.dart';
import 'reading_progress.dart';

/// Medalla redonda de un premio: a color si se ganó, en gris si aún no.
class AwardMedal extends StatelessWidget {
  const AwardMedal({
    super.key,
    required this.award,
    required this.earned,
    this.size = 84,
  });

  final Award award;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors =
        earned ? award.colors : const [Color(0xFF5A5470), Color(0xFF34304A)];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
        border: Border.all(
          color: earned ? Palette.amber : Palette.cardSoft,
          width: size / 18,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: award.colors.first.withValues(alpha: 0.45),
                  blurRadius: size / 5,
                ),
              ]
            : null,
      ),
      // Sin ganar se ve su silueta en gris (para saber qué se puede conseguir) con un candadito.
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            award.icon,
            size: size * 0.48,
            color: earned
                ? Colors.white
                : Palette.mutedText.withValues(alpha: 0.6),
          ),
          if (!earned)
            Positioned(
              right: size * 0.1,
              bottom: size * 0.1,
              child: Icon(Icons.lock, size: size * 0.2, color: Palette.cream),
            ),
        ],
      ),
    );
  }
}

/// «Nuestras noches»: cuánto han leído (minutos, semanas con cuento y cuentos terminados) y los premios.
class ProgressTab extends StatelessWidget {
  const ProgressTab({
    super.key,
    required this.progress,
    required this.childId,
    this.childName,
  });

  final ReadingProgress progress;
  final String? childId;
  final String? childName;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: progress,
      builder: (context, _) {
        final p = progress.of(childId);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
                childName == null
                    ? 'Nuestras noches'
                    : 'Las noches de $childName',
                style:
                    text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Row(
              children: [
                _Stat(
                    key: const Key('stat-minutes'),
                    icon: Icons.hourglass_bottom,
                    value: '${p.minutes}',
                    unit: 'min',
                    label: 'Tiempo de cuento'),
                _Stat(
                    key: const Key('stat-weeks'),
                    icon: Icons.nightlight_round,
                    value: '${p.storyWeeks}',
                    label: 'Semanas con cuento'),
                _Stat(
                    key: const Key('stat-stories'),
                    icon: Icons.menu_book,
                    value: '${p.stories}',
                    label: 'Cuentos leídos'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Una «semana con cuento» es una semana con cuento al menos 3 noches.',
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: Palette.mutedText),
            ),
            const SizedBox(height: 24),
            Text('Premios (${p.earned.length} de ${awards.length})',
                style: text.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                const columns = 3;
                final w = (c.maxWidth - 2 * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 18,
                  children: [
                    for (final a in awards)
                      SizedBox(
                        width: w,
                        child: InkWell(
                          key: Key('award-${a.id}'),
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _explain(context, a, p),
                          child: Column(
                            children: [
                              AwardMedal(
                                  award: a,
                                  earned: p.earned.containsKey(a.id),
                                  size: w * 0.72),
                              const SizedBox(height: 6),
                              Text(a.name,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: text.bodyMedium!.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: p.earned.containsKey(a.id)
                                          ? Palette.cream
                                          : Palette.mutedText)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Todo esto se guarda solo en este teléfono. Los premios nunca se pierden.',
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: Palette.mutedText),
            ),
          ],
        );
      },
    );
  }

  void _explain(BuildContext context, Award a, ChildProgress p) {
    final day = p.earned[a.id];
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        title: Text(a.name, textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AwardMedal(award: a, earned: day != null, size: 110),
            const SizedBox(height: 14),
            Text(a.hint, textAlign: TextAlign.center),
            if (day != null) ...[
              const SizedBox(height: 6),
              Text('Ganado el $day',
                  style: const TextStyle(color: Palette.mutedText)),
            ],
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit,
  });

  final IconData icon;
  final String value;
  final String? unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 40, color: Palette.amber),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: value,
                    style: text.headlineMedium!
                        .copyWith(fontWeight: FontWeight.w800)),
                if (unit != null)
                  TextSpan(text: ' $unit', style: text.bodyMedium),
              ]),
            ),
          ),
          Text(label,
              textAlign: TextAlign.center,
              style: text.bodySmall!.copyWith(color: Palette.mutedText)),
        ],
      ),
    );
  }
}

/// Celebración al terminar un cuento que da premios nuevos: una tarjeta en el final del cuento (nunca una
/// ventana que tape la valoración ni interrumpa la lectura).
class AwardsEarned extends StatelessWidget {
  const AwardsEarned({super.key, required this.awards});

  final List<Award> awards;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: const Key('award-celebration'),
      color: Palette.card,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text(awards.length == 1 ? '¡Un premio nuevo!' : '¡Premios nuevos!',
                style: text.titleLarge!.copyWith(
                    fontWeight: FontWeight.w800, color: Palette.amber)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 12,
              children: [
                for (final a in awards)
                  SizedBox(
                    width: 120,
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0.4, end: 1),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.elasticOut,
                          builder: (context, v, child) =>
                              Transform.scale(scale: v, child: child),
                          child: AwardMedal(award: a, earned: true, size: 90),
                        ),
                        const SizedBox(height: 8),
                        Text(a.name,
                            textAlign: TextAlign.center,
                            style: text.titleMedium!
                                .copyWith(fontWeight: FontWeight.w800)),
                        Text(a.hint,
                            textAlign: TextAlign.center,
                            style: text.bodySmall!
                                .copyWith(color: Palette.mutedText)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
