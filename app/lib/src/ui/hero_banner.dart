import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import '../art/scene_painter.dart';
import '../art/story_stage.dart';
import 'palette.dart';

/// Portada del inicio: el castillo del Reino de la Luna de noche, con Mara y Zafiro, vivos (parpadean, respiran
/// y saludan). Si el arte no carga, un degradado de noche con la luna. Encima va el saludo.
class HeroBanner extends StatefulWidget {
  const HeroBanner({
    super.key,
    required this.art,
    required this.pack,
    required this.greeting,
    this.animate = true,
  });

  final StageArt? art;
  final Pack pack;
  final String greeting;
  final bool animate;

  @override
  State<HeroBanner> createState() => _HeroBannerState();
}

class _HeroBannerState extends State<HeroBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3600),
  );
  final ValueNotifier<double> _clock = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _c.addListener(() => _clock.value = _c.value * 3600);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && !MediaQuery.disableAnimationsOf(context)) {
      if (!_c.isAnimating) _c.forward();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = widget.art;
    final setup = art == null
        ? null
        : bannerSetup(art, widget.pack, const Rect.fromLTWH(0, 330, 600, 350));
    final text = Theme.of(context).textTheme;
    return AspectRatio(
      aspectRatio: 600 / 350,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (setup == null)
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Palette.skyTop, Palette.skyLow],
                  ),
                ),
                child: Align(
                  alignment: Alignment(0.6, -0.4),
                  child: Icon(Icons.nightlight_round,
                      size: 64, color: Palette.moon),
                ),
              )
            else
              RepaintBoundary(
                child: CustomPaint(
                  painter: ScenePainter(
                    scene: setup.scene,
                    actors: setup.actors,
                    props: setup.props,
                    clock: _clock,
                    view: setup.view,
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 34, 18, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Palette.skyTop.withValues(alpha: 0.85)
                    ],
                  ),
                ),
                child: Text(
                  widget.greeting,
                  style: text.titleLarge!.copyWith(
                    color: Palette.cream,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La escena de portada: el castillo de noche con Mara y Zafiro, recortada a [view] (o `null` si falta algo).
StageSetup? bannerSetup(StageArt art, Pack pack, Rect view) {
  Character? by(String id) {
    for (final c in pack.characters) {
      if (c.id == id) return c;
    }
    return null;
  }

  Place? place;
  for (final p in pack.places) {
    if (p.id == 'castillo') place = p;
  }
  final mara = by('mara'), zafiro = by('zafiro');
  if (place == null || mara == null || zafiro == null) return null;
  final base = stageFor(
    art,
    {'lugar': place, 'hero': mara, 'helper': zafiro},
    {
      'bg': 'lugar',
      'time': 'noche',
      'mood': 'calm',
      'stage': [
        {'who': 'hero', 'clip': 'wave', 'x': 0.32},
        {'who': 'helper', 'clip': 'talk', 'x': 0.7},
      ],
    },
  );
  if (base == null) return null;
  return StageSetup(
    placeId: base.placeId,
    place: base.place,
    scene: base.scene,
    actors: base.actors,
    view: view,
    props: base.props,
  );
}

/// La portada pequeña de un paquete (el castillo, quieto), para las tarjetas.
Widget castleCover(StageArt? art, Pack pack) {
  final setup = art == null
      ? null
      : bannerSetup(art, pack, const Rect.fromLTWH(0, 350, 600, 306));
  if (setup == null) return const SizedBox.shrink();
  return RepaintBoundary(
    child: CustomPaint(
      painter: ScenePainter(
        scene: setup.scene,
        actors: setup.actors,
        props: setup.props,
        clock: ValueNotifier<double>(0.5),
        view: setup.view,
      ),
    ),
  );
}
