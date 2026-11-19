import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../narration/recorded_voice.dart';

/// Grabaciones de la familia (docs/28, R-15 a R-18): mamá, papá o quien sea graba un cuento con su voz, escena por
/// escena, y después el cuento puede sonar con esa voz en «Ver y escuchar» y «Solo escuchar».
///
/// Todo queda **solo en este teléfono** (carpeta privada de la app): no se sube a ningún servidor. Cada audio se
/// guarda junto al texto exacto que dice, así el reproductor de siempre ([StoryClips], el mismo de la voz grabada del
/// catálogo) lo encuentra por texto. Se borran desde Ajustes («Borrar las grabaciones»).
class FamilyRecordings extends ChangeNotifier {
  FamilyRecordings(this._dir);

  /// Carpeta donde viven las grabaciones (y su índice).
  final Directory _dir;

  /// Por cuento (`pack:premisa`): quién grabó y el archivo de cada texto.
  final Map<String, FamilyRecording> _byStory = {};

  /// Abre las grabaciones guardadas en la carpeta privada de la app.
  static Future<FamilyRecordings> open() async {
    final base = await getApplicationDocumentsDirectory();
    final r = FamilyRecordings(Directory('${base.path}/grabaciones'));
    await r.load();
    return r;
  }

  File get _index => File('${_dir.path}/indice.json');

  Future<void> load() async {
    try {
      if (!await _index.exists()) return;
      final j = jsonDecode(await _index.readAsString()) as Map<String, Object?>;
      _byStory.clear();
      for (final MapEntry(:key, :value) in j.entries) {
        if (value is Map<String, Object?>) {
          _byStory[key] = FamilyRecording.fromJson(value);
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Grabaciones ilegibles: $e');
    }
  }

  Future<void> _save() async {
    await _dir.create(recursive: true);
    await _index.writeAsString(jsonEncode(
        {for (final e in _byStory.entries) e.key: e.value.toJson()}));
  }

  /// La grabación de un cuento (puede estar a medias), o `null`.
  FamilyRecording? of(String storyKey) => _byStory[storyKey];

  /// Todas las grabaciones (para Ajustes).
  Map<String, FamilyRecording> get all => Map.unmodifiable(_byStory);

  /// Dónde guardar la escena [index] del cuento [storyKey].
  Future<String> pathFor(String storyKey, int index) async {
    final d = Directory('${_dir.path}/${_safe(storyKey)}');
    await d.create(recursive: true);
    return '${d.path}/$index.m4a';
  }

  /// Guarda que [file] dice [text] en el cuento [storyKey], grabado por [voice].
  Future<void> put(String storyKey,
      {required String voice,
      required String text,
      required String file}) async {
    final old = _byStory[storyKey];
    _byStory[storyKey] = FamilyRecording(
      voice: voice,
      files: {...?old?.files, text: file},
    );
    notifyListeners();
    await _save();
  }

  /// Borra la grabación de un cuento.
  Future<void> deleteStory(String storyKey) async {
    _byStory.remove(storyKey);
    try {
      final d = Directory('${_dir.path}/${_safe(storyKey)}');
      if (await d.exists()) await d.delete(recursive: true);
    } catch (_) {}
    notifyListeners();
    await _save();
  }

  /// Borra todas las grabaciones del teléfono.
  Future<void> deleteAll() async {
    _byStory.clear();
    try {
      if (await _dir.exists()) await _dir.delete(recursive: true);
    } catch (_) {}
    notifyListeners();
  }

  /// La voz de la familia para un cuento, lista para el reproductor, o `null` si no está grabado entero
  /// ([texts]: los textos que suenan: título, escenas y enseñanza).
  RecordedVoice? voiceFor(String storyKey, Iterable<String> texts) {
    final r = _byStory[storyKey];
    if (r == null || !r.covers(texts)) return null;
    return RecordedVoice(
      language: 'es',
      stories: {
        storyKey: StoryClips({
          for (final e in r.files.entries)
            e.key: RecordedClip(
                text: e.key, file: e.value, seconds: 0, bundled: false),
        }),
      },
      store: LocalClipStore(),
    );
  }

  static String _safe(String key) =>
      key.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
}

/// La grabación de un cuento: quién la hizo y qué archivo dice cada texto.
class FamilyRecording {
  const FamilyRecording({required this.voice, required this.files});

  factory FamilyRecording.fromJson(Map<String, Object?> j) => FamilyRecording(
        voice: (j['voz'] as String?) ?? 'Mi voz',
        files: {
          for (final e in ((j['audios'] as Map?) ?? const {}).entries)
            if (e.key is String && e.value is String)
              e.key as String: e.value as String,
        },
      );

  /// Quién grabó («Mamá», «Papá», «Abuela»…).
  final String voice;

  /// Texto exacto → archivo.
  final Map<String, String> files;

  bool covers(Iterable<String> texts) => texts.every(files.containsKey);

  Map<String, Object?> toJson() => {'voz': voice, 'audios': files};
}

/// Los audios grabados en el teléfono: suenan directo del archivo.
class LocalClipStore implements ClipStore {
  @override
  Future<Source?> sourceFor(RecordedClip clip) async =>
      File(clip.file).existsSync() ? DeviceFileSource(clip.file) : null;

  @override
  Future<void> prefetch(Iterable<RecordedClip> clips) async {}
}

/// Pone las grabaciones al alcance de las pantallas (en las pruebas puede no haber).
class FamilyRecordingsScope extends InheritedNotifier<FamilyRecordings> {
  const FamilyRecordingsScope(
      {super.key, required FamilyRecordings? recordings, required super.child})
      : super(notifier: recordings);

  static FamilyRecordings? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<FamilyRecordingsScope>()
      ?.notifier;
}

/// El micrófono. Las pruebas ponen uno de mentira.
abstract class VoiceRecorder {
  /// Pide (si hace falta) y dice si hay permiso para usar el micrófono.
  Future<bool> hasPermission();
  Future<void> start(String path);

  /// Termina y devuelve el archivo grabado.
  Future<String?> stop();
  Future<void> dispose();
}

/// El micrófono de verdad (paquete `record`), en AAC (`.m4a`), mono y con el ruido de fondo reducido.
class MicRecorder implements VoiceRecorder {
  final _rec = AudioRecorder();

  @override
  Future<bool> hasPermission() => _rec.hasPermission();

  @override
  Future<void> start(String path) => _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          numChannels: 1,
          sampleRate: 44100,
          bitRate: 96000,
          noiseSuppress: true,
          echoCancel: true,
          autoGain: true,
        ),
        path: path,
      );

  @override
  Future<String?> stop() => _rec.stop();

  @override
  Future<void> dispose() => _rec.dispose();
}
