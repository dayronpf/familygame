import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Efectos de sonido del cuento («¡Cric!», «¡Beee!», «¡Plaf!»…): los que la voz no sabe imitar. Los archivos están
/// en `assets/audio/sfx/<id>.ogg` (sonidos CC0 y sintetizados, ver `docs/21-efectos-de-sonido.md`).
abstract class Sfx {
  /// Suena el efecto [id] y termina cuando acaba (o a los 2 s como mucho, para no frenar el cuento).
  Future<void> play(String id);

  /// Corta lo que esté sonando (al pausar, saltar o cerrar).
  Future<void> stop();

  /// Factor de volumen (0–1): el fundido del temporizador de sueño.
  Future<void> setLevel(double level) async {}
  Future<void> dispose();
}

/// No suena nada (pruebas, o si la familia los quita).
class SilentSfx implements Sfx {
  @override
  Future<void> play(String id) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setLevel(double level) async {}
  @override
  Future<void> dispose() async {}
}

/// Reproduce los archivos con `audioplayers`. **Sin pedir el foco de audio** (`mixWithOthers`): la voz del sistema y
/// el sonido de fondo ya lo gestionan y pedirlo aquí los pausaría.
class AssetSfx implements Sfx {
  AssetSfx({this.volume = 0.8});

  final double volume;
  double _level = 1.0;
  final _players = <AudioPlayer>{};

  @override
  Future<void> play(String id) async {
    final p = AudioPlayer();
    _players.add(p);
    try {
      await p.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers)
            .build(),
      );
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setVolume((volume * _level).clamp(0.0, 1.0));
      final done = p.onPlayerComplete.first;
      await p.play(AssetSource('audio/sfx/$id.ogg'));
      await done.timeout(const Duration(seconds: 2), onTimeout: () {});
    } catch (e) {
      debugPrint('Sin efecto de sonido «$id»: $e');
    } finally {
      _players.remove(p);
      try {
        await p.dispose();
      } catch (_) {}
    }
  }

  @override
  Future<void> stop() async {
    for (final p in _players.toList()) {
      try {
        await p.stop();
      } catch (_) {}
    }
  }

  @override
  Future<void> setLevel(double level) async {
    _level = level.clamp(0.0, 1.0);
    for (final p in _players.toList()) {
      try {
        await p.setVolume((volume * _level).clamp(0.0, 1.0));
      } catch (_) {}
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
  }
}
