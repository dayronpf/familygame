import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'art/story_stage.dart';
import 'audio/ambience.dart';
import 'narration/narrator.dart';
import 'narration/playback.dart';
import 'settings/app_settings.dart';

/// Cómo se crean la voz y el sonido de fondo (las pruebas ponen versiones mudas).
typedef NarratorFactory = Narrator Function();
typedef AmbienceFactory = Ambience Function();

Narrator defaultNarrator() => TtsNarrator();
Ambience defaultAmbience() => AssetAmbience();

/// El narrador y el sonido de fondo según los ajustes de la familia (voz elegida, velocidad del perfil de edad
/// y lectura, música). Se leen al abrir el cine o el holograma: un cambio en Ajustes vale desde el siguiente cuento.
Narrator narratorFor(BuildContext context) => SettingsScope.voicesOf(context)
    .storyNarrator(SettingsScope.maybeOf(context)?.child.voiceConfig ??
        const VoiceConfig());

Ambience ambienceFor(BuildContext context) {
  final s = SettingsScope.maybeOf(context);
  if (s == null) return defaultAmbience();
  return s.music ? AssetAmbience(volume: s.musicVolume) : SilentAmbience();
}

bool musicOn(BuildContext context) =>
    SettingsScope.maybeOf(context)?.music ?? true;

/// Escenas a reproducir: las del cuento y, al final, la enseñanza dicha en voz alta.
/// Una escena sin dibujo conserva el de la anterior para que la pantalla no se quede vacía.
List<PlayScene> playScenes(Story story, List<StageSetup?> setups) {
  StageSetup? last;
  final out = <PlayScene>[];
  for (var i = 0; i < story.scenes.length; i++) {
    final s = i < setups.length ? setups[i] : null;
    last = s ?? last;
    out.add(PlayScene(text: story.scenes[i].text, setup: last));
  }
  out.add(PlayScene(
      text: 'La enseñanza de hoy: ${story.moralLine}',
      setup: last,
      isMoral: true));
  return out;
}

/// Reloj de animación (segundos) que se detiene con «reducir movimiento».
class StageClock {
  StageClock(TickerProvider vsync) {
    _ticker = vsync.createTicker((e) => value.value = e.inMicroseconds / 1e6)
      ..start();
  }

  final ValueNotifier<double> value = ValueNotifier(0);
  late final Ticker _ticker;

  set muted(bool m) => _ticker.muted = m;

  void dispose() {
    _ticker.dispose();
    value.dispose();
  }
}

/// Mantiene la pantalla encendida mientras suena el cuento y oculta las barras del sistema.
/// Si el sistema no lo permite (pruebas, otras plataformas) no pasa nada.
Future<void> enterShowMode({required bool immersive}) async {
  try {
    await WakelockPlus.enable();
  } catch (_) {}
  if (immersive) {
    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }
}

Future<void> leaveShowMode() async {
  try {
    await WakelockPlus.disable();
  } catch (_) {}
  try {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  } catch (_) {}
}
