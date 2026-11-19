import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import '../ui/palette.dart';
import '../ui/reading_text.dart';
import 'family_recordings.dart';

/// Lo que suena de un cuento, en orden: el título, cada escena y la enseñanza (igual que el reproductor). Es lo que
/// se graba, y cada audio queda ligado a su texto exacto.
List<String> recordingTexts(Story story) => [
      if (story.title != null && story.title!.isNotEmpty) story.title!,
      for (final s in story.scenes) s.text,
      'La enseñanza de hoy: ${story.moralLine}',
    ];

/// Grabar un cuento con la voz de mamá, papá o quien sea: se elige quién graba y se lee en voz alta, página a página
/// (el título, cada escena y la enseñanza). En cada página: grabar, escuchar cómo quedó, repetir o seguir. Se puede
/// dejar a medias y seguir otro día: lo grabado se guarda al momento.
class RecorderPage extends StatefulWidget {
  const RecorderPage({
    super.key,
    required this.story,
    required this.storyKey,
    required this.recordings,
    this.recorder,
  });

  final Story story;
  final String storyKey;
  final FamilyRecordings recordings;

  /// El micrófono (por defecto, el del teléfono; las pruebas ponen uno de mentira).
  final VoiceRecorder? recorder;

  @override
  State<RecorderPage> createState() => _RecorderPageState();
}

class _RecorderPageState extends State<RecorderPage> {
  /// El micrófono se abre al grabar la primera vez (no al entrar).
  VoiceRecorder? _micOrNull;
  VoiceRecorder get _mic => _micOrNull ??= widget.recorder ?? MicRecorder();
  /// El que hace sonar lo grabado (se crea al escuchar la primera vez).
  AudioPlayer? _player;
  late final List<String> _texts = recordingTexts(widget.story);
  late String? _voice = widget.recordings.of(widget.storyKey)?.voice;
  int _page = 0;
  bool _recording = false;
  bool _denied = false;
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si ya empezaron antes, se sigue en la primera página que falta
    final done = widget.recordings.of(widget.storyKey)?.files ?? const {};
    final next = _texts.indexWhere((t) => !done.containsKey(t));
    _page = next < 0 ? 0 : next;
  }

  @override
  void dispose() {
    if (_recording) _micOrNull?.stop();
    _micOrNull?.dispose();
    _player?.dispose();
    _name.dispose();
    super.dispose();
  }

  String? get _fileOfPage =>
      widget.recordings.of(widget.storyKey)?.files[_texts[_page]];

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _mic.stop();
      setState(() => _recording = false);
      if (path != null) {
        await widget.recordings.put(widget.storyKey,
            voice: _voice!, text: _texts[_page], file: path);
        if (mounted) setState(() {});
      }
      return;
    }
    if (!await _mic.hasPermission()) {
      setState(() => _denied = true);
      return;
    }
    await _player?.stop();
    final path = await widget.recordings.pathFor(widget.storyKey, _page);
    try {
      final f = File(path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    await _mic.start(path);
    setState(() {
      _recording = true;
      _denied = false;
    });
  }

  Future<void> _listen() async {
    final f = _fileOfPage;
    if (f == null) return;
    final p = _player ??= AudioPlayer();
    await p.stop();
    await p.play(DeviceFileSource(f));
  }

  void _go(int delta) {
    if (_recording) return;
    _player?.stop();
    setState(() => _page = (_page + delta).clamp(0, _texts.length - 1));
  }

  Widget _whoRecords(TextTheme text) {
    const options = ['Mamá', 'Papá', 'Abuela', 'Abuelo'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('¿Quién va a grabar este cuento?',
            style: text.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
            'Después el cuento podrá sonar con tu voz en «Ver y escuchar» y «Solo escuchar», aunque no estés. '
            'Las grabaciones se quedan solo en este teléfono.',
            style: text.bodyLarge!.copyWith(color: Palette.mutedText)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final o in options)
              ActionChip(
                key: Key('voice-$o'),
                label: Text(o),
                onPressed: () => setState(() => _voice = o),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('voice-other'),
          controller: _name,
          decoration: const InputDecoration(
              labelText: 'Otro nombre (Tía Ana, Padrino…)'),
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) setState(() => _voice = v.trim());
          },
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            onPressed: () {
              final v = _name.text.trim();
              if (v.isNotEmpty) setState(() => _voice = v);
            },
            child: const Text('Seguir'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final files = widget.recordings.of(widget.storyKey)?.files ?? const {};
    final done = _texts.where(files.containsKey).length;
    final complete = done == _texts.length;
    return Scaffold(
      backgroundColor: Palette.skyLow,
      appBar: AppBar(
        backgroundColor: Palette.skyTop,
        title: Text(_voice == null ? 'Grabar con mi voz' : 'Graba: $_voice'),
      ),
      body: _voice == null
          ? _whoRecords(text)
          : Column(
              children: [
                LinearProgressIndicator(
                  value: done / _texts.length,
                  backgroundColor: Palette.cardSoft,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Text(
                    'Página ${_page + 1} de ${_texts.length} · grabadas $done',
                    key: const Key('recorder-progress'),
                    style: text.bodyMedium!.copyWith(color: Palette.mutedText),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                    child: Text(
                      context.readingText(_texts[_page]),
                      key: const Key('recorder-text'),
                      style: context.readingStyle(
                          text.headlineSmall!.copyWith(height: 1.5)),
                    ),
                  ),
                ),
                if (_denied)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Text(
                      'Para grabar hace falta permiso para usar el micrófono. Puedes darlo en los ajustes del teléfono.',
                      key: const Key('recorder-denied'),
                      style: text.bodyMedium!.copyWith(color: Palette.amber),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        tooltip: 'Página anterior',
                        onPressed: _page == 0 ? null : () => _go(-1),
                        icon: const Icon(Icons.chevron_left, size: 36),
                      ),
                      IconButton(
                        key: const Key('recorder-listen'),
                        tooltip: 'Escuchar cómo quedó',
                        onPressed:
                            _fileOfPage == null || _recording ? null : _listen,
                        icon: const Icon(Icons.play_circle_outline, size: 36),
                      ),
                      SizedBox(
                        width: 78,
                        height: 78,
                        child: FilledButton(
                          key: const Key('recorder-record'),
                          onPressed: _toggleRecord,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: _recording
                                ? const Color(0xFFE5484D)
                                : Palette.amber,
                          ),
                          child: Icon(_recording ? Icons.stop : Icons.mic,
                              size: 36),
                        ),
                      ),
                      IconButton(
                        key: const Key('recorder-next'),
                        tooltip: 'Página siguiente',
                        onPressed: _page >= _texts.length - 1 || _recording
                            ? null
                            : () => _go(1),
                        icon: const Icon(Icons.chevron_right, size: 36),
                      ),
                      IconButton(
                        key: const Key('recorder-done'),
                        tooltip: complete ? 'Listo' : 'Seguir otro día',
                        onPressed: _recording
                            ? null
                            : () => Navigator.of(context).pop(complete),
                        icon: Icon(complete ? Icons.check_circle : Icons.save,
                            size: 32, color: complete ? Palette.amber : null),
                      ),
                    ],
                  ),
                ),
                if (complete)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('¡Listo! El cuento ya suena con tu voz.',
                        key: const Key('recorder-complete'),
                        style:
                            text.titleMedium!.copyWith(color: Palette.amber)),
                  ),
              ],
            ),
    );
  }
}
