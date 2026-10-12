import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'art/story_stage.dart';
import 'audio/ambience.dart';
import 'audio/sfx.dart';
import 'narration/narrator.dart';
import 'narration/playback.dart';
import 'settings/app_settings.dart';
import 'story_flow.dart';
import 'ui/screen_dimmer.dart';

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

/// Los efectos de sonido según los ajustes (sin ajustes, como en las pruebas, no suenan).
Sfx sfxFor(BuildContext context) {
  final s = SettingsScope.maybeOf(context);
  return s != null && s.effects ? AssetSfx() : SilentSfx();
}

bool musicOn(BuildContext context) =>
    SettingsScope.maybeOf(context)?.music ?? true;

/// Escenas a reproducir: las del cuento y, al final, la enseñanza dicha en voz alta (solo si el cuento está
/// completo: con una pregunta sin responder termina en la pregunta). Una escena sin dibujo conserva el de la
/// anterior para que la pantalla no se quede vacía.
List<PlayScene> playScenes(
  Story story,
  List<StageSetup?> setups, {
  bool complete = true,
}) {
  StageSetup? last;
  final out = <PlayScene>[];
  for (var i = 0; i < story.scenes.length; i++) {
    final s = i < setups.length ? setups[i] : null;
    last = s ?? last;
    final sc = story.scenes[i];
    out.add(PlayScene(
      text: sc.text,
      setup: last,
      choice: sc.choice,
      pickedOption: sc.pickedOption,
    ));
  }
  if (complete) {
    out.add(PlayScene(
        text: 'La enseñanza de hoy: ${story.moralLine}',
        setup: last,
        isMoral: true));
  }
  return out;
}

/// Los dibujos de lo contado hasta ahora (con preguntas el cuento crece, así que se calculan al vuelo).
List<StageSetup?> flowSetups(StageArt? art, Story story) => art == null
    ? const []
    : [
        for (final s in story.scenes) stageFor(art, story.cast, s.directives),
      ];

/// El niño contestó (o eligió la app) la pregunta de la escena [asked]: responde en el [flow] y devuelve **todas**
/// las escenas que vienen después (hasta la enseñanza si el cuento ya está completo).
List<PlayScene> continueFlow(
  StoryFlow flow,
  StageArt? art,
  int asked,
  String? optionId,
) {
  optionId == null ? flow.chooseForMe() : flow.choose(optionId);
  final all = playScenes(
    flow.story,
    flowSetups(art, flow.story),
    complete: flow.isComplete,
  );
  return all.sublist(asked + 1);
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

/// El fundido del temporizador de sueño: baja a la vez la voz, la música y el brillo, y lo devuelve todo cuando el
/// adulto vuelve a reproducir o sale de la pantalla.
class SleepFade {
  SleepFade({
    required this.playback,
    required this.ambience,
    required this.dimmer,
  });

  final StoryPlayback playback;
  final Ambience ambience;
  final ScreenDimmer dimmer;
  bool _dark = false;

  /// El oído nota el volumen en escala logarítmica: con `nivel²` la bajada se siente pareja.
  static double volumeFor(double level) => level * level;

  /// [level] de 1 a 0 (lo manda el temporizador cada segundo).
  void apply(double level) {
    _dark = level < 1;
    playback.setVolume(volumeFor(level));
    ambience.setLevel(volumeFor(level));
    dimmer.setLevel(level);
  }

  /// Se cumplió el temporizador: silencio total; la pantalla se queda oscura hasta que el adulto la despierte.
  Future<void> finish() async {
    await playback.pause();
    await ambience.stop();
  }

  /// Vuelve todo a como estaba (se quitó el temporizador, se pulsó reproducir o se salió de la pantalla).
  Future<void> reset() async {
    if (!_dark) return;
    _dark = false;
    await playback.setVolume(1);
    await ambience.setLevel(1);
    await dimmer.restore();
  }

  Future<void> dispose() => dimmer.restore();
}
