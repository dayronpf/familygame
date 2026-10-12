import 'dart:async';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'audio/ambience.dart';
import 'audio/background_audio.dart';
import 'audio/sfx.dart';
import 'narration/narrator.dart';
import 'narration/playback.dart';
import 'player_support.dart';
import 'ui/palette.dart';
import 'ui/screen_dimmer.dart';
import 'ui/sleep_timer.dart';

/// Modo solo audio: la pantalla se queda negra y con el brillo al mínimo (en una pantalla OLED, apagada del todo) y el
/// cuento sigue sonando. Un toque enseña los controles unos segundos. Sirve para dejar el teléfono en la mesita.
///
/// Si el adulto bloquea el teléfono, el cuento sigue: un servicio en primer plano con notificación de medios
/// (`BackgroundSession`, ver `audio/background_audio.dart`) evita que Android duerma o mate la app, y deja
/// reproducir/pausar/parar en la pantalla de bloqueo. En iOS lo permite el modo de fondo `audio`.
class AudioOnlyPage extends StatefulWidget {
  const AudioOnlyPage({
    super.key,
    required this.story,
    this.narrator,
    this.ambience,
    this.dimmer,
    this.background,
    this.sfx,
    this.autoStart = true,
  });

  final Story story;
  final Narrator? narrator;
  final Ambience? ambience;

  /// Quien baja el brillo (por defecto, el de la pantalla del teléfono; las pruebas ponen uno de mentira).
  final ScreenDimmer? dimmer;

  /// Quien mantiene el cuento vivo con la pantalla bloqueada (por defecto, el servicio de Android).
  final BackgroundAudio? background;

  /// Efectos de sonido (por defecto, según los ajustes; las pruebas ponen uno de mentira).
  final Sfx? sfx;
  final bool autoStart;

  @override
  State<AudioOnlyPage> createState() => _AudioOnlyPageState();
}

class _AudioOnlyPageState extends State<AudioOnlyPage> {
  late final StoryPlayback _playback;
  late final Sfx _sfx = widget.sfx ?? sfxFor(context);
  late final Ambience _ambience = widget.ambience ?? ambienceFor(context);
  late final ScreenDimmer _screen = widget.dimmer ?? SystemDimmer();

  /// El fundido del temporizador solo baja la voz y la música: la pantalla ya está al mínimo.
  late final SleepFade _fade = SleepFade(
    playback: _playback,
    ambience: _ambience,
    dimmer: const NoDimmer(),
  );
  late final BackgroundSession _bg;
  bool _controls = true;
  bool _hearMusic = true;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    _playback = StoryPlayback(
      scenes: playScenes(widget.story, const []),
      narrator: widget.narrator ?? narratorFor(context),
      title: widget.story.title,
      sfx: _sfx,
    )..addListener(() {
        if (!mounted) return;
        // Al terminar los controles se quedan a la vista (con el botón «Volver»)
        setState(() => _controls = _controls || _playback.finished);
      });
    _hearMusic = musicOn(context);
    // Servicio en primer plano con notificación de medios: el cuento sigue con la pantalla bloqueada.
    _bg = BackgroundSession(
      playback: _playback,
      audio: widget.background ?? defaultBackgroundAudio(),
      title: widget.story.title ?? widget.story.moral.name,
    )..start(playing: widget.autoStart);
    enterShowMode(immersive: true);
    _screen.setLevel(0);
    if (widget.autoStart) {
      if (_hearMusic) _ambience.start();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _playback.play();
      });
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 5), () {
      if (mounted && _playback.playing) setState(() => _controls = false);
    });
  }

  void _tap() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _bg.close();
    _playback.dispose();
    _sfx.dispose();
    _ambience.stop();
    _ambience.dispose();
    _screen.restore();
    leaveShowMode();
    super.dispose();
  }

  Widget _icon(IconData icon, String tip, VoidCallback? onTap,
          {double size = 34}) =>
      IconButton(
        icon: Icon(icon),
        iconSize: size,
        color: Palette.amber.withValues(alpha: 0.7),
        tooltip: tip,
        onPressed: onTap == null
            ? null
            : () {
                onTap();
                _scheduleHide();
              },
      );

  @override
  Widget build(BuildContext context) {
    final pb = _playback;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        key: const Key('audio-only-surface'),
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        child: SafeArea(
          child: AnimatedOpacity(
            opacity: _controls ? 1 : 0,
            duration: const Duration(milliseconds: 400),
            child: IgnorePointer(
              ignoring: !_controls,
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _icon(
                        Icons.close, 'Salir', () => Navigator.pop(context)),
                  ),
                  const Spacer(),
                  Icon(Icons.nightlight_round,
                      size: 56, color: Palette.moon.withValues(alpha: 0.35)),
                  const SizedBox(height: 12),
                  Text(
                    widget.story.title ?? widget.story.moral.name,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: Palette.mutedText.withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pb.finished
                        ? 'Fin del cuento'
                        : (pb.playing ? 'Escuchando…' : 'En pausa'),
                    key: const Key('audio-only-status'),
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: Palette.mutedText.withValues(alpha: 0.5),
                        ),
                  ),
                  if (pb.finished) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      key: const Key('finished-back'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Volver'),
                    ),
                  ],
                  const Spacer(),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      _icon(Icons.skip_previous, 'Escena anterior',
                          pb.scene == 0 ? null : pb.previous),
                      _icon(
                        pb.playing
                            ? Icons.pause_circle
                            : (pb.finished ? Icons.replay : Icons.play_circle),
                        pb.playing ? 'Pausa' : 'Reproducir',
                        () {
                          _fade.reset();
                          pb.toggle();
                        },
                        size: 60,
                      ),
                      _icon(Icons.skip_next, 'Escena siguiente',
                          pb.scene >= pb.scenes.length - 1 ? null : pb.next),
                      _icon(
                        _hearMusic ? Icons.music_note : Icons.music_off,
                        'Sonido de fondo',
                        () {
                          setState(() => _hearMusic = !_hearMusic);
                          _hearMusic ? _ambience.start() : _ambience.stop();
                        },
                        size: 28,
                      ),
                      SleepTimerButton(
                        color: Palette.amber.withValues(alpha: 0.7),
                        iconSize: 30,
                        onPicked: _scheduleHide,
                        onFade: _fade.apply,
                        onCancel: _fade.reset,
                        onExpire: _fade.finish,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
