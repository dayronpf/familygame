import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../narration/playback.dart';

/// Lo que pide el adulto desde la notificación o la pantalla de bloqueo.
enum BackgroundAction { play, pause, stop }

/// Mantiene vivo el cuento con la **pantalla bloqueada**. En Android es un servicio en primer plano con
/// notificación de medios (así el sistema no duerme la app ni la mata para ahorrar batería) y con los botones
/// de reproducir, pausar y parar en la pantalla de bloqueo. Está en `android/.../StoryAudioService.kt`.
abstract class BackgroundAudio {
  /// Quien recibe las órdenes de la notificación.
  void Function(BackgroundAction action)? onAction;

  /// Empieza a mantener el cuento vivo (muestra la notificación).
  Future<void> start(String title, {required bool playing});

  /// Cambia el botón de la notificación (reproducir/pausar) y suelta o retoma el bloqueo de CPU.
  Future<void> setPlaying(bool playing);

  /// Quita la notificación y deja de proteger la app: el sistema vuelve a poder dormirla.
  Future<void> stop();
}

/// No hace nada (iOS por ahora, pruebas y escritorio).
class NoBackgroundAudio implements BackgroundAudio {
  @override
  void Function(BackgroundAction action)? onAction;

  @override
  Future<void> start(String title, {required bool playing}) async {}
  @override
  Future<void> setPlaying(bool playing) async {}
  @override
  Future<void> stop() async {}
}

/// Habla con el servicio de Android por un canal. Si el teléfono no lo permite (falta el permiso de
/// notificaciones, el sistema rechaza el servicio…) el cuento sigue como antes, solo que sin protección.
class PlatformBackgroundAudio implements BackgroundAudio {
  static const _channel = MethodChannel('caldero/background_audio');

  @override
  void Function(BackgroundAction action)? onAction;

  Future<void> _call(String method, [Object? args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } catch (e) {
      debugPrint('Audio en segundo plano no disponible: $e');
    }
  }

  @override
  Future<void> start(String title, {required bool playing}) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'action') return;
      final name = call.arguments;
      for (final a in BackgroundAction.values) {
        if (a.name == name) onAction?.call(a);
      }
    });
    await _call('start', {'title': title, 'playing': playing});
  }

  @override
  Future<void> setPlaying(bool playing) =>
      _call('setPlaying', {'playing': playing});

  @override
  Future<void> stop() async {
    _channel.setMethodCallHandler(null);
    await _call('stop');
  }
}

/// El que se usa en la app: solo Android tiene el servicio; en el resto no hace nada.
BackgroundAudio defaultBackgroundAudio() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? PlatformBackgroundAudio()
        : NoBackgroundAudio();

/// Une un cuento que suena con el servicio: avisa de si suena o está en pausa y obedece a la notificación.
class BackgroundSession {
  BackgroundSession({
    required this.playback,
    required this.audio,
    required this.title,
    this.onStopped,
  });

  final StoryPlayback playback;
  final BackgroundAudio audio;
  final String title;

  /// Se pulsó «parar» en la notificación (la pantalla puede cerrarse).
  final VoidCallback? onStopped;

  bool _last = false;
  bool _closed = false;

  Future<void> start({required bool playing}) async {
    _last = playing;
    audio.onAction = _onAction;
    playback.addListener(_sync);
    await audio.start(title, playing: playing);
  }

  void _sync() {
    if (_closed || playback.playing == _last) return;
    _last = playback.playing;
    audio.setPlaying(_last);
  }

  void _onAction(BackgroundAction action) {
    if (_closed) return;
    switch (action) {
      case BackgroundAction.play:
        playback.play();
      case BackgroundAction.pause:
        playback.pause();
      case BackgroundAction.stop:
        playback.pause();
        onStopped?.call();
        close();
    }
  }

  /// Quita la notificación. Se puede llamar más de una vez.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    playback.removeListener(_sync);
    audio.onAction = null;
    await audio.stop();
  }
}
