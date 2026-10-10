import 'package:flutter/material.dart';

import '../narration/narrator.dart';
import 'palette.dart';
import 'voice_services.dart';

/// Nombres con los que se presentan las voces (nunca el código técnico del motor). Son neutros a propósito:
/// el teléfono no dice si una voz es de mujer o de hombre y un nombre equivocado confundiría.
const List<String> voiceFriendlyNames = ['Luna', 'Brisa', 'Nube', 'Trueno'];

/// Una tarjeta de voz: su nombre amigable y la voz del teléfono que hay detrás (`null` = la de siempre).
class VoiceOption {
  const VoiceOption(this.name, this.voice);

  final String name;
  final TtsVoice? voice;
}

/// De 1 a 4 opciones a partir de las voces instaladas: las que funcionan sin conexión primero, sin repetir,
/// siempre en el mismo orden (así «Luna» es la misma voz cada vez).
List<VoiceOption> voiceOptions(List<TtsVoice> installed) {
  final seen = <String>{};
  final unique = [
    for (final v in installed)
      if (seen.add(v.name)) v,
  ]..sort((a, b) {
      final la = a.name.contains('local') ? 0 : 1;
      final lb = b.name.contains('local') ? 0 : 1;
      return la != lb ? la - lb : a.name.compareTo(b.name);
    });
  if (unique.isEmpty) return [VoiceOption(voiceFriendlyNames.first, null)];
  return [
    for (var i = 0; i < unique.length && i < voiceFriendlyNames.length; i++)
      VoiceOption(voiceFriendlyNames[i], unique[i]),
  ];
}

String sampleGreeting(String name) =>
    '¡Hola! Soy $name y esta noche te voy a contar un cuento.';

/// Tarjetas de voz del wizard y de Ajustes. Al tocar una suena un saludo corto con esa voz; el saludo se detiene
/// si se toca otra o si se sale de la pantalla.
class VoicePicker extends StatefulWidget {
  const VoicePicker({
    super.key,
    required this.services,
    required this.selected,
    required this.speed,
    required this.onSelected,
  });

  final VoiceServices services;

  /// La voz elegida (`null` = la primera del teléfono).
  final TtsVoice? selected;

  /// Velocidad del saludo (la del perfil de edad).
  final double speed;
  final ValueChanged<VoiceOption> onSelected;

  @override
  State<VoicePicker> createState() => _VoicePickerState();
}

class _VoicePickerState extends State<VoicePicker> {
  /// Si el teléfono no contesta (o falla) hay igual una opción: la voz de siempre.
  late final Future<List<VoiceOption>> _options = widget.services
      .listVoices()
      .timeout(const Duration(seconds: 3), onTimeout: () => const [])
      .then(voiceOptions)
      .catchError((Object _) => [VoiceOption(voiceFriendlyNames.first, null)]);
  TtsNarrator? _sample;

  @override
  void dispose() {
    _sample?.dispose();
    super.dispose();
  }

  Future<void> _play(VoiceOption o) async {
    widget.onSelected(o);
    await _sample?.stop(); // el saludo anterior se corta
    final narrator = _sample ??= widget.services.sampleNarrator(
      VoiceConfig(voice: o.voice, speed: widget.speed),
    );
    await narrator.configure(VoiceConfig(voice: o.voice, speed: widget.speed));
    await narrator.speak(sampleGreeting(o.name));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return FutureBuilder<List<VoiceOption>>(
      future: _options,
      builder: (context, snap) {
        final options = snap.data;
        if (options == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return Column(
          children: [
            for (var i = 0; i < options.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Builder(builder: (context) {
                  final o = options[i];
                  final selected = widget.selected == null
                      ? i == 0
                      : widget.selected == o.voice;
                  return Material(
                    color: selected ? Palette.amber : Palette.card,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      key: Key('voice-card-$i'),
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => _play(o),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              Icons.record_voice_over,
                              size: 30,
                              color:
                                  selected ? Palette.amberDark : Palette.amber,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    o.name,
                                    style: text.titleLarge!.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: selected
                                          ? Palette.amberDark
                                          : Palette.cream,
                                    ),
                                  ),
                                  Text(
                                    'Toca para oírla',
                                    style: text.bodySmall!.copyWith(
                                      color: selected
                                          ? Palette.amberDark
                                          : Palette.mutedText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.play_circle_outline,
                              color:
                                  selected ? Palette.amberDark : Palette.cream,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
          ],
        );
      },
    );
  }
}
