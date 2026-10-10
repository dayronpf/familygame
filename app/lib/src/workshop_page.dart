import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'art/art_library.dart';
import 'art/frame_stats.dart';
import 'art/rig_renderer.dart';
import 'art/scene_painter.dart';

/// Taller de personajes: previsualiza el arte, prueba cualquier clip y mide el rendimiento.
class WorkshopPage extends StatefulWidget {
  const WorkshopPage({super.key, required this.bundle, this.freezeAt});

  final AssetBundle bundle;

  /// Si se indica, la animación queda congelada en ese instante (pruebas y capturas).
  final double? freezeAt;

  @override
  State<WorkshopPage> createState() => _WorkshopPageState();
}

class _Loaded {
  _Loaded(this.art)
      : rigs = {for (final e in art.rigs.entries) e.key: CompiledRig(e.value)},
        scene = CompiledScene(art.scene);

  final ArtLibrary art;
  final Map<String, CompiledRig> rigs;
  final CompiledScene scene;
}

class _WorkshopPageState extends State<WorkshopPage>
    with SingleTickerProviderStateMixin {
  late final Future<_Loaded> _future =
      loadArtLibrary(widget.bundle).then(_Loaded.new);
  final ValueNotifier<double> _clock = ValueNotifier(0);
  final FrameStats _stats = FrameStats();
  Ticker? _ticker;

  String _clip = 'idle';
  bool _stress = false;
  double _count = 6;
  bool _background = true;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    final freeze = widget.freezeAt;
    if (freeze != null) {
      _clock.value = freeze;
    } else {
      _ticker = createTicker((e) => _clock.value = e.inMicroseconds / 1e6)
        ..start();
      _stats.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _stats.stop();
    _clock.dispose();
    super.dispose();
  }

  void _togglePause() => setState(() {
        _paused = !_paused;
        _ticker?.muted = _paused;
      });

  List<ActorInstance> _actors(_Loaded l) {
    final clip = l.art.clips.clips[_clip]!;
    if (!_stress) {
      return [
        for (final a in l.art.scene.actors)
          ActorInstance(
              rig: l.rigs[a.rig]!,
              clip: clip,
              x: a.x,
              y: a.y,
              scale: a.scale,
              phase: a.phase),
      ];
    }
    // Prueba de carga: N personajes (se repiten los rigs) repartidos en filas, de atrás hacia delante.
    final ids = [
      for (final e in l.rigs.entries)
        if (e.value.rig.type == 'humanoid') e.key,
    ];
    final n = _count.round();
    final cols = math.max(1, math.sqrt(n * 0.8).ceil());
    final rows = (n / cols).ceil();
    final scale = (0.85 / (1 + 0.16 * (n - 1))).clamp(0.3, 0.8);
    return [
      for (var i = 0; i < n; i++)
        ActorInstance(
          rig: l.rigs[ids[i % ids.length]]!,
          clip: clip,
          x: ((i % cols) + 0.5) * l.art.scene.width / cols +
              ((i ~/ cols).isOdd ? 20 : -20),
          y: 650 + (rows == 1 ? 60 : 130 * (i ~/ cols) / (rows - 1)),
          scale: scale,
          phase: i * 0.37,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Taller de personajes')),
      body: SafeArea(
        child: FutureBuilder<_Loaded>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) {
              return Center(
                  child: Text('No se pudo cargar el arte.\n${snap.error}',
                      textAlign: TextAlign.center));
            }
            final l = snap.data;
            if (l == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            key: const Key('scene-canvas'),
                            painter: ScenePainter(
                              scene: l.scene,
                              actors: _actors(l),
                              clock: _clock,
                              showBackground: _background,
                            ),
                          ),
                        ),
                      ),
                      if (widget.freezeAt == null)
                        Positioned(
                          left: 8,
                          top: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: const Color(0xB3000000),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: ValueListenableBuilder<String>(
                                valueListenable: _stats.label,
                                builder: (context, v, child) =>
                                    Text(v, style: text.labelMedium),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.34),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final name in l.art.clips.clips.keys)
                              ChoiceChip(
                                label: Text(name),
                                selected: _clip == name,
                                onSelected: (_) => setState(() => _clip = name),
                              ),
                          ],
                        ),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Prueba de carga (más personajes)'),
                          value: _stress,
                          onChanged: (v) => setState(() => _stress = v),
                        ),
                        if (_stress)
                          Row(
                            children: [
                              Text('${_count.round()} personajes'),
                              Expanded(
                                child: Slider(
                                  min: 1,
                                  max: 24,
                                  divisions: 23,
                                  value: _count,
                                  onChanged: (v) => setState(() => _count = v),
                                ),
                              ),
                            ],
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: SwitchListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Fondo'),
                                value: _background,
                                onChanged: (v) =>
                                    setState(() => _background = v),
                              ),
                            ),
                            if (widget.freezeAt == null)
                              TextButton.icon(
                                onPressed: _togglePause,
                                icon: Icon(
                                    _paused ? Icons.play_arrow : Icons.pause),
                                label: Text(_paused ? 'Seguir' : 'Pausa'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
