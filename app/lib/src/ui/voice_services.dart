import '../narration/narrator.dart';

/// Cómo se crean las voces: para listar las del teléfono, para las muestras del wizard y para narrar los cuentos.
/// Las pruebas ponen versiones de mentira.
class VoiceServices {
  const VoiceServices({
    this.listVoices = _listSystemVoices,
    this.sampleNarrator = _systemNarrator,
    this.storyNarrator = _systemNarrator,
  });

  /// Voces en español que ofrece el teléfono.
  final Future<List<TtsVoice>> Function() listVoices;

  /// Narrador de las muestras («¡Hola! Soy Luna…»).
  final TtsNarrator Function(VoiceConfig config) sampleNarrator;

  /// Narrador de los cuentos (modo cine y holograma).
  final Narrator Function(VoiceConfig config) storyNarrator;
}

TtsNarrator _systemNarrator(VoiceConfig config) => TtsNarrator(config: config);

Future<List<TtsVoice>> _listSystemVoices() => TtsNarrator().availableVoices();
