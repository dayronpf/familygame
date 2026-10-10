import 'dart:async';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'art/hologram.dart';
import 'art/scene_painter.dart';
import 'art/story_stage.dart';
import 'audio/ambience.dart';
import 'narration/narrator.dart';
import 'narration/playback.dart';
import 'player_support.dart';

/// Modo holograma: cuatro copias de la escena sobre negro, una por cada cara de un prisma
/// transparente (pirámide invertida) apoyado en el centro de la pantalla. Sin texto: una voz
/// cuenta el cuento, suena un fondo suave y el dibujo cambia según avanza la narración.
/// Toca la pantalla para ver los controles (solo iconos, para no ensuciar el reflejo).
class HologramPage extends StatefulWidget {
  const HologramPage({
    super.key,
    required this.story,
    required this.art,
    required this.setups,
    this.narrator,
    this.ambience,
    this.autoStart = true,
  });

  final Story story;
  final StageArt art;
  final List<StageSetup?> setups;
  final Narrator? narrator;
  final Ambience? ambience;
  final bool autoStart;

  @override
  State<HologramPage> createState() => _HologramPageState();
}

class _HologramPageState extends State<HologramPage>
    with SingleTickerProviderStateMixin {
  late final StageClock _clock = StageClock(this);
  late final StoryPlayback _playback;
  late final Ambience _ambience = widget.ambience ?? defaultAmbience();
  List<ActorInstance> _actors = const [];
  List<ActorInstance> _props = const [];
  double _crop = 1;
  StageSetup? _setup;
  int _shownScene = -1;
  HologramLayout _layout = const HologramLayout();
  bool _controls = true;
  Timer? _hide;
  bool _hearVoice = true;

  @override
  void initState() {
    super.initState();
    _playback = StoryPlayback(
      scenes: playScenes(widget.story, widget.setups),
      narrator: widget.narrator ?? defaultNarrator(),
      title: widget.story.title,
    )..addListener(_onPlayback);
    _onPlayback();
    _loadLayout();
    enterShowMode(immersive: true);
    if (widget.autoStart) {
      _ambience.start();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playback.play();
      });
      _scheduleHide();
    }
  }

  /// Cuando cambia la escena, el dibujo nuevo llega caminando.
  void _onPlayback() {
    if (_playback.scene != _shownScene) {
      final s = _playback.current.setup;
      setState(() {
        _shownScene = _playback.scene;
        _setup = s;
        _crop = s == null ? 1 : holoCrop(s.actors.length);
        _actors = s == null
            ? const []
            : holoSqueeze(
                withEntrance(s, widget.art, _clock.value.value), s, _crop);
        _props = s == null ? const [] : holoSqueeze(s.props, s, _crop);
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadLayout() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() => _layout = HologramLayout(
            gap: (p.getDouble('holo.gap') ?? _layout.gap)
                .clamp(HologramLayout.minGap, HologramLayout.maxGap),
            feetInward: p.getBool('holo.feet') ?? _layout.feetInward,
            mirror: p.getBool('holo.mirror') ?? _layout.mirror,
          ));
    } catch (_) {}
  }

  Future<void> _setLayout(HologramLayout l) async {
    setState(() => _layout = l);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('holo.gap', l.gap);
      await p.setBool('holo.feet', l.feetInward);
      await p.setBool('holo.mirror', l.mirror);
    } catch (_) {}
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && _playback.playing) setState(() => _controls = false);
    });
  }

  void _tap() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.muted = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _hide?.cancel();
    _playback.removeListener(_onPlayback);
    _playback.dispose();
    _ambience.stop();
    _ambience.dispose();
    _clock.dispose();
    leaveShowMode();
    super.dispose();
  }

  Widget _icon(IconData icon, String tip, VoidCallback? onTap,
      {bool on = true}) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tip,
      color: on ? const Color(0xFF9EEBFF) : const Color(0xFF4A6A73),
      iconSize: 30,
      onPressed: onTap == null
          ? null
          : () {
              onTap();
              _scheduleHide();
            },
    );
  }

  @override
  Widget build(BuildContext context) {
    final setup = _setup;
    final pb = _playback;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 700),
              child: setup == null
                  ? const SizedBox.expand(key: ValueKey('vacio'))
                  : CustomPaint(
                      key: ValueKey('holo-$_shownScene'),
                      painter: HologramPainter(
                        setup: setup,
                        actors: _actors,
                        props: _props,
                        crop: _crop,
                        guides: _controls,
                        clock: _clock.value,
                        layout: _layout,
                      ),
                      size: Size.infinite,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: IgnorePointer(
                  ignoring: !_controls,
                  child: AnimatedOpacity(
                    opacity: _controls ? 1 : 0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: const Color(0xCC000000),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          _icon(Icons.close, 'Salir',
                              () => Navigator.pop(context)),
                          _icon(Icons.skip_previous, 'Escena anterior',
                              pb.previous),
                          _icon(pb.playing ? Icons.pause : Icons.play_arrow,
                              pb.playing ? 'Pausa' : 'Continuar', pb.toggle),
                          _icon(Icons.skip_next, 'Escena siguiente', pb.next),
                          _icon(_hearVoice ? Icons.volume_up : Icons.volume_off,
                              'Voz', () {
                            setState(() {
                              _hearVoice = !_hearVoice;
                              pb.narrate = _hearVoice;
                            });
                          }, on: _hearVoice),
                          _icon(
                              Icons.remove,
                              'Prisma más pequeño',
                              () => _setLayout(_layout.copyWith(
                                  gap: (_layout.gap - 0.03).clamp(
                                      HologramLayout.minGap,
                                      HologramLayout.maxGap)))),
                          _icon(
                              Icons.add,
                              'Prisma más grande',
                              () => _setLayout(_layout.copyWith(
                                  gap: (_layout.gap + 0.03).clamp(
                                      HologramLayout.minGap,
                                      HologramLayout.maxGap)))),
                          _icon(
                              Icons.swap_vert,
                              'Pies hacia dentro o fuera',
                              () => _setLayout(_layout.copyWith(
                                  feetInward: !_layout.feetInward))),
                          _icon(
                              Icons.flip,
                              'Reflejar izquierda y derecha',
                              () => _setLayout(
                                  _layout.copyWith(mirror: !_layout.mirror))),
                        ],
                      ),
                    ),
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
