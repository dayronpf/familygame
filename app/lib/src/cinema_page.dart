import 'dart:math' as math;

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'art/story_stage.dart';
import 'audio/ambience.dart';
import 'hologram_page.dart';
import 'narration/narrator.dart';
import 'narration/playback.dart';
import 'player_support.dart';

/// Modo cine: el cuento a pantalla completa, con cielo de estrellas, una escena por vez que
/// cambia sola al ritmo de la voz y subtítulos grandes con la frase que suena resaltada.
class CinemaPage extends StatefulWidget {
  const CinemaPage({
    super.key,
    required this.story,
    required this.art,
    required this.setups,
    this.narrator,
    this.ambience,
    this.autoStart = true,
    this.animate = true,
  });

  final Story story;
  final StageArt art;
  final List<StageSetup?> setups;
  final Narrator? narrator;
  final Ambience? ambience;
  final bool autoStart;
  final bool animate;

  @override
  State<CinemaPage> createState() => _CinemaPageState();
}

class _CinemaPageState extends State<CinemaPage>
    with SingleTickerProviderStateMixin {
  late final StageClock _clock = StageClock(this);
  late final StoryPlayback _playback;
  late final Ambience _ambience = widget.ambience ?? defaultAmbience();
  bool _hearVoice = true;
  bool _hearMusic = true;

  @override
  void initState() {
    super.initState();
    _playback = StoryPlayback(
      scenes: playScenes(widget.story, widget.setups),
      narrator: widget.narrator ?? defaultNarrator(),
      title: widget.story.title,
    )..addListener(() => mounted ? setState(() {}) : null);
    enterShowMode(immersive: false);
    if (widget.autoStart) {
      _ambience.start();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playback.play();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.muted = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _playback.dispose();
    _ambience.stop();
    _ambience.dispose();
    _clock.dispose();
    leaveShowMode();
    super.dispose();
  }

  Future<void> _toHologram() async {
    final nav = Navigator.of(context);
    await _playback.pause();
    await _ambience.stop();
    await nav.push(MaterialPageRoute<void>(
      builder: (_) => HologramPage(
        story: widget.story,
        art: widget.art,
        setups: widget.setups,
        narrator: widget.narrator,
        ambience: widget.ambience,
      ),
    ));
    // Al volver del holograma se recupera el modo cine (pausado, con su fondo si estaba activo).
    if (!mounted) return;
    enterShowMode(immersive: false);
    if (_hearMusic) _ambience.start();
  }

  TextSpan _subtitle(PlayScene sc, TextStyle base, Color accent) {
    final cur = _playback.sentence;
    return TextSpan(children: [
      for (var i = 0; i < sc.sentences.length; i++)
        TextSpan(
          text: i == sc.sentences.length - 1
              ? sc.sentences[i]
              : '${sc.sentences[i]} ',
          style: base.copyWith(
            color: i == cur ? accent : base.color!.withValues(alpha: 0.55),
            fontWeight: i == cur ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final pb = _playback;
    final sc = pb.current;
    final scheme = Theme.of(context).colorScheme;
    final base = Theme.of(context)
        .textTheme
        .titleLarge!
        .copyWith(height: 1.55, color: Colors.white);
    final setup = sc.setup;
    return Scaffold(
      backgroundColor: const Color(0xFF0B1030),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0B1030),
                  Color(0xFF241A4F),
                  Color(0xFF3B2A5E)
                ],
              ),
            ),
          ),
          CustomPaint(painter: _Stars(_clock.value)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        tooltip: 'Cerrar',
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          widget.story.title ?? widget.story.moral.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium!
                              .copyWith(color: scheme.primary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.view_in_ar),
                        color: Colors.white,
                        tooltip: 'Ver en holograma',
                        onPressed: _toHologram,
                      ),
                    ],
                  ),
                ),
                if (setup != null)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween(
                                begin: const Offset(0.04, 0), end: Offset.zero)
                            .animate(anim),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      key: ValueKey('stage-${pb.scene}'),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: StoryStage(
                        setup: setup,
                        clock: _clock.value,
                        art: widget.art,
                        animate: widget.animate,
                      ),
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
                    child: Text.rich(
                      _subtitle(sc, base, scheme.primary),
                      key: const ValueKey('subtitle'),
                    ),
                  ),
                ),
                LinearProgressIndicator(
                  value: (pb.scene + 1) / pb.scenes.length,
                  minHeight: 3,
                  backgroundColor: Colors.white12,
                ),
                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      color: Colors.white,
                      iconSize: 32,
                      tooltip: 'Escena anterior',
                      onPressed: pb.scene == 0 ? null : pb.previous,
                    ),
                    IconButton(
                      icon: Icon(pb.playing
                          ? Icons.pause_circle
                          : (pb.finished ? Icons.replay : Icons.play_circle)),
                      color: scheme.primary,
                      iconSize: 52,
                      tooltip: pb.playing ? 'Pausa' : 'Reproducir',
                      onPressed: pb.toggle,
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      color: Colors.white,
                      iconSize: 32,
                      tooltip: 'Escena siguiente',
                      onPressed:
                          pb.scene >= pb.scenes.length - 1 ? null : pb.next,
                    ),
                    IconButton(
                      icon: Icon(_hearVoice
                          ? Icons.record_voice_over
                          : Icons.voice_over_off),
                      color: _hearVoice ? Colors.white : Colors.white38,
                      iconSize: 28,
                      tooltip: 'Voz',
                      onPressed: () => setState(() {
                        _hearVoice = !_hearVoice;
                        pb.narrate = _hearVoice;
                      }),
                    ),
                    IconButton(
                      icon:
                          Icon(_hearMusic ? Icons.music_note : Icons.music_off),
                      color: _hearMusic ? Colors.white : Colors.white38,
                      iconSize: 28,
                      tooltip: 'Sonido de fondo',
                      onPressed: () {
                        setState(() => _hearMusic = !_hearMusic);
                        _hearMusic ? _ambience.start() : _ambience.stop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Estrellitas que titilan (barato: unos 40 puntos).
class _Stars extends CustomPainter {
  _Stars(this.clock) : super(repaint: clock);
  final ValueNotifier<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final t = clock.value;
    final p = Paint();
    for (var i = 0; i < 42; i++) {
      final sx = math.sin(i * 12.9898) * 0.5 + 0.5;
      final sy = math.sin(i * 78.233) * 0.5 + 0.5;
      final a =
          0.25 + 0.6 * (math.sin(t * (0.8 + (i % 5) * 0.25) + i) * 0.5 + 0.5);
      p.color = Color.fromRGBO(255, 244, 214, a);
      canvas.drawCircle(Offset(sx * size.width, sy * size.height * 0.7),
          1.0 + (i % 3) * 0.6, p);
    }
  }

  @override
  bool shouldRepaint(_Stars old) => false;
}
