import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import '../art/rig_renderer.dart';
import '../art/story_stage.dart';

/// Nombres de Material Icons que pueden llevar las opciones (la lista cerrada está en el motor: `choiceGlyphs`).
const Map<String, IconData> choiceIcons = {
  'hearing': Icons.hearing,
  'touch_app': Icons.touch_app,
  'hourglass_bottom': Icons.hourglass_bottom,
  'visibility': Icons.visibility,
  'pets': Icons.pets,
  'air': Icons.air,
  'spa': Icons.spa,
  'search': Icons.search,
  'forest': Icons.forest,
  'self_improvement': Icons.self_improvement,
  'explore': Icons.explore,
  'volume_up': Icons.volume_up,
  'lightbulb': Icons.lightbulb,
  'waving_hand': Icons.waving_hand,
  'directions_walk': Icons.directions_walk,
  'music_note': Icons.music_note,
  'nightlight_round': Icons.nightlight_round,
  'favorite': Icons.favorite,
};

/// Las 2–3 tarjetas de una pregunta: icono grande y la etiqueta. Sin cuenta atrás, sin colores de «acierto» y
/// sin movimiento; solo un resplandor suave en la que se está nombrando ([highlighted]).
class ChoiceCards extends StatelessWidget {
  const ChoiceCards({
    super.key,
    required this.choice,
    required this.onChoose,
    this.highlighted,
    this.dark = true,
    this.art,
  });

  final StoryChoice choice;
  final void Function(String optionId) onChoose;

  /// Posición de la opción que la voz está diciendo ahora.
  final int? highlighted;

  /// Sobre fondo oscuro (cine, holograma) o claro (pantalla de texto).
  final bool dark;

  /// El arte del pack: con él, las opciones que tienen dibujo propio lo enseñan (si no, el icono).
  final StageArt? art;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = dark ? Colors.white : scheme.onSurface;
    final n = choice.options.length;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < n; i++)
          Semantics(
            button: true,
            label: 'Opción ${i + 1} de $n: ${choice.options[i].label}',
            excludeSemantics: true,
            child: _Card(
              key: Key('choice-${choice.options[i].id}'),
              option: choice.options[i],
              rig: art?.rigs[choice.options[i].art ?? ''],
              lit: highlighted == i,
              color: fg,
              accent: scheme.primary,
              dark: dark,
              onTap: () => onChoose(choice.options[i].id),
            ),
          ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    super.key,
    required this.option,
    required this.rig,
    required this.lit,
    required this.color,
    required this.accent,
    required this.dark,
    required this.onTap,
  });

  final StoryOption option;

  /// El dibujo de la opción, si lo tiene y está en el arte.
  final CompiledRig? rig;
  final bool lit;
  final Color color, accent;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: dark ? Colors.white.withValues(alpha: lit ? 0.18 : 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: lit ? accent : color.withValues(alpha: 0.25),
          width: lit ? 3 : 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 104, minHeight: 104),
          child: SizedBox(
            width: 112,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (rig != null)
                    RigIcon(rig: rig!, size: 56, glow: lit ? accent : null)
                  else
                    Icon(
                      choiceIcons[option.glyph] ?? Icons.circle_outlined,
                      size: 48,
                      color: lit ? accent : color,
                    ),
                  const SizedBox(height: 8),
                  Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall!
                        .copyWith(color: color, height: 1.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un dibujo del arte (un objeto, un pictograma) en reposo, ajustado a un cuadrado de [size].
class RigIcon extends StatelessWidget {
  const RigIcon({super.key, required this.rig, required this.size, this.glow});

  final CompiledRig rig;
  final double size;

  /// Resplandor tras el dibujo (la opción que se está nombrando).
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: glow == null
              ? null
              : [
                  BoxShadow(color: glow!.withValues(alpha: 0.5), blurRadius: 14)
                ],
        ),
        child:
            CustomPaint(size: Size.square(size), painter: _RigIconPainter(rig)),
      ),
    );
  }
}

class _RigIconPainter extends CustomPainter {
  _RigIconPainter(this.rig);

  final CompiledRig rig;

  @override
  void paint(Canvas canvas, Size size) {
    final vb = rig.rig.viewBox;
    final k = size.width / (vb[2] > vb[3] ? vb[2] : vb[3]);
    canvas
      ..translate(
        (size.width - vb[2] * k) / 2 - vb[0] * k,
        (size.height - vb[3] * k) / 2 - vb[1] * k,
      )
      ..scale(k, k);
    rig.paintRest(canvas);
  }

  @override
  bool shouldRepaint(_RigIconPainter old) => old.rig != rig;
}
