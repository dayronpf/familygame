import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Sonido de fondo del cuento (un colchón suave con campanitas, sintetizado por el proyecto).
abstract class Ambience {
  Future<void> start();
  Future<void> stop();

  /// Factor de volumen (0–1) sobre el volumen de los ajustes: el fundido del temporizador de sueño.
  Future<void> setLevel(double level) async {}
  Future<void> dispose();
}

/// No suena nada (pruebas, o si el usuario lo quita).
class SilentAmbience implements Ambience {
  @override
  Future<void> start() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> setLevel(double level) async {}
  @override
  Future<void> dispose() async {}
}

/// Sonido de fondo propio de cada paquete (los que no tienen, el de siempre). El del mar va en AAC (`.m4a`), que
/// suena también en iOS.
const Map<String, String> packAmbience = {'mar': 'audio/ambient_mar.m4a'};

/// El sonido de fondo del paquete [packId] (o el de siempre).
String ambienceAsset(String? packId) =>
    packAmbience[packId] ?? 'audio/ambient.ogg';

/// Reproduce [asset] (por defecto `assets/audio/ambient.ogg`) en bucle y bajito para que la voz mande.
class AssetAmbience implements Ambience {
  AssetAmbience({this.volume = 0.22, this.asset = 'audio/ambient.ogg'});

  final double volume;

  /// Ruta dentro de `assets/` (ver [ambienceAsset]).
  final String asset;
  AudioPlayer? _player;
  double _level = 1.0;

  @override
  Future<void> start() async {
    try {
      final p = _player ??= AudioPlayer();
      await p.setReleaseMode(ReleaseMode.loop);
      await p.setVolume(volume * _level);
      await p.play(AssetSource(asset));
    } catch (e) {
      debugPrint('Sin sonido de fondo: $e');
    }
  }

  @override
  Future<void> setLevel(double level) async {
    _level = level.clamp(0.0, 1.0);
    try {
      await _player?.setVolume(volume * _level);
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _player?.stop();
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    try {
      await _player?.dispose();
    } catch (_) {}
    _player = null;
  }
}
