import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../content/remote_content.dart';

/// Voz grabada de los cuentos del catálogo (docs/31, paso A6): cada escena, el título y la enseñanza de cada cuento
/// se grabaron una vez con ElevenLabs. Los cuentos gratis vienen dentro de la app; los demás se descargan la primera
/// vez y quedan guardados en el teléfono. Si un audio falta (o el texto cambió desde que se grabó), esa frase la dice
/// la voz del teléfono, como siempre.
///
/// El manifiesto (`assets/voz/<idioma>/manifiesto.json`) lo escribe `tools/voice/export_app.py`.

/// Un audio grabado: el texto exacto que dice y dónde está.
class RecordedClip {
  const RecordedClip({
    required this.text,
    required this.file,
    required this.seconds,
    required this.bundled,
  });

  final String text;

  /// Nombre del archivo (`<huella>.m4a`).
  final String file;
  final double seconds;

  /// `true` = viene dentro de la app (`assets/voz/<idioma>/audio/`); `false` = se descarga.
  final bool bundled;
}

/// Los audios de un cuento, por texto: la escena (o el título, o la enseñanza) cuyo texto coincide letra por letra.
class StoryClips {
  StoryClips(this.byText);

  final Map<String, RecordedClip> byText;

  RecordedClip? clipFor(String text) => byText[text];

  bool get isEmpty => byText.isEmpty;
}

/// Dónde se busca y se guarda cada audio. Las pruebas ponen uno en memoria.
abstract class ClipStore {
  /// La fuente lista para sonar, o `null` si no se puede conseguir (sin conexión, no existe…).
  Future<Source?> sourceFor(RecordedClip clip);

  /// Baja de antemano los audios de un cuento (para que no haya pausas entre escenas). Silencioso si falla.
  Future<void> prefetch(Iterable<RecordedClip> clips);
}

/// Los incluidos salen de los assets; los demás se descargan de [baseUrl] a una carpeta del teléfono.
class CachedClipStore implements ClipStore {
  CachedClipStore({
    required this.language,
    required this.baseUrl,
    http.Client? client,
    Future<Directory> Function()? cacheDir,
  })  : _client = client ?? http.Client(),
        _cacheDir = cacheDir ?? _defaultCacheDir;

  final String language;

  /// Carpeta pública del audio en el servidor (`https://…/voz/es/`). Vacía = no se descarga nada.
  final String baseUrl;
  final http.Client _client;
  final Future<Directory> Function() _cacheDir;
  final _inFlight = <String, Future<File?>>{};

  static Future<Directory> _defaultCacheDir() async {
    final base = await getApplicationSupportDirectory();
    return Directory('${base.path}/voz');
  }

  @override
  Future<Source?> sourceFor(RecordedClip clip) async {
    if (clip.bundled) return AssetSource('voz/$language/audio/${clip.file}');
    final f = await _download(clip);
    return f == null ? null : DeviceFileSource(f.path);
  }

  @override
  Future<void> prefetch(Iterable<RecordedClip> clips) async {
    for (final c in clips) {
      if (!c.bundled) await _download(c);
    }
  }

  // Ojo: el `remove` devuelve el propio Future; si se devolviera a `whenComplete`, se esperaría a sí mismo.
  Future<File?> _download(RecordedClip clip) =>
      _inFlight[clip.file] ??= _fetch(clip).whenComplete(() {
        _inFlight.remove(clip.file);
      });

  Future<File?> _fetch(RecordedClip clip) async {
    try {
      final dir = Directory('${(await _cacheDir()).path}/$language');
      final file = File('${dir.path}/${clip.file}');
      if (await file.exists() && await file.length() > 0) return file;
      if (baseUrl.isEmpty) return null;
      final res = await _client
          .get(Uri.parse('$baseUrl${clip.file}'))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;
      await dir.create(recursive: true);
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      return await tmp.rename(file.path);
    } catch (e) {
      debugPrint('Sin audio grabado «${clip.file}»: $e');
      return null;
    }
  }
}

/// Reproduce un audio grabado y termina cuando acaba. Las pruebas ponen uno que no suena.
abstract class ClipPlayer {
  /// Suena [source]; termina al acabar, al llamar a [stop] o si falla (devuelve `false` si no pudo sonar).
  Future<bool> play(Source source);
  Future<void> stop();
  Future<void> setVolume(double volume);
  Future<void> dispose();
}

class AudioplayersClipPlayer implements ClipPlayer {
  final AudioPlayer _player = AudioPlayer();
  Completer<bool>? _current;
  double _volume = 1;

  @override
  Future<bool> play(Source source) async {
    await stop();
    final c = _current = Completer<bool>();
    final sub = _player.onPlayerComplete.listen((_) {
      if (!c.isCompleted) c.complete(true);
    });
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(_volume);
      // Si lo pararon mientras se preparaba, no se empieza (sonaría con el cuento en pausa)
      if (!c.isCompleted) await _player.play(source);
      if (c.isCompleted && identical(_current, c)) await _player.stop();
    } catch (e) {
      debugPrint('No sonó el audio grabado: $e');
      if (!c.isCompleted) c.complete(false);
    }
    final ok = await c.future;
    await sub.cancel();
    return ok;
  }

  @override
  Future<void> stop() async {
    final c = _current;
    if (c != null && !c.isCompleted) c.complete(true);
    try {
      await _player.stop();
    } catch (_) {}
  }

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume;
    try {
      await _player.setVolume(volume);
    } catch (_) {}
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _player.dispose();
  }
}

/// El manifiesto de la voz grabada: cuento («paquete:premisa») → sus audios.
class RecordedVoice {
  RecordedVoice({
    required this.language,
    required Map<String, StoryClips> stories,
    required this.store,
    ClipPlayer Function()? player,
  })  : _stories = stories,
        _player = player ?? AudioplayersClipPlayer.new;

  final String language;
  final Map<String, StoryClips> _stories;
  final ClipStore store;
  final ClipPlayer Function() _player;

  /// Sin voz grabada (pruebas, o si el manifiesto no se pudo leer).
  static final RecordedVoice none = RecordedVoice(
    language: 'es',
    stories: const {},
    store: _NoStore(),
  );

  bool has(String storyKey) => _stories.containsKey(storyKey);

  /// Los audios del cuento [storyKey], o `null` si no está grabado.
  StoryClips? clipsFor(String? storyKey) =>
      storyKey == null ? null : _stories[storyKey];

  ClipPlayer newPlayer() => _player();

  /// Lee el manifiesto. Si no está o está roto, devuelve [none]: la app sigue con la voz del teléfono.
  ///
  /// Si el manifiesto llegó del servidor ([ContentBundle], docs/34), solo cuentan como incluidos los audios que
  /// también lo están en el manifiesto que trae la app (los demás se descargan, aunque el servidor diga «incluido»).
  static Future<RecordedVoice> load(
    AssetBundle bundle, {
    String language = 'es',
    String baseUrl = '',
    ClipStore? store,
  }) async {
    try {
      final key = 'assets/voz/$language/manifiesto.json';
      final raw = await bundle.loadString(key);
      Set<String>? bundledFiles;
      if (bundle is ContentBundle && bundle.replaces(key)) {
        try {
          final inApp = parse(
            jsonDecode(await bundle.base.loadString(key))
                as Map<String, Object?>,
            language: language,
            store: _NoStore(),
          );
          bundledFiles = {
            for (final s in inApp._stories.values)
              for (final c in s.byText.values)
                if (c.bundled) c.file,
          };
        } catch (_) {
          bundledFiles = const {};
        }
      }
      return parse(
        jsonDecode(raw) as Map<String, Object?>,
        language: language,
        store: store ?? CachedClipStore(language: language, baseUrl: baseUrl),
        bundledFiles: bundledFiles,
      );
    } catch (e) {
      debugPrint('Sin voz grabada ($language): $e');
      return none;
    }
  }

  /// Con [bundledFiles], un audio está incluido en la app solo si su archivo está en ese conjunto (y no por el
  /// `incluido` del manifiesto).
  static RecordedVoice parse(
    Map<String, Object?> json, {
    required String language,
    required ClipStore store,
    ClipPlayer Function()? player,
    Set<String>? bundledFiles,
  }) {
    final stories = <String, StoryClips>{};
    final cuentos = (json['cuentos'] as Map<String, Object?>?) ?? const {};
    for (final MapEntry(:key, :value) in cuentos.entries) {
      final c = value! as Map<String, Object?>;
      final bundled = c['incluido'] == true;
      final byText = <String, RecordedClip>{};
      void add(Object? raw) {
        if (raw is! Map<String, Object?>) return;
        final text = raw['texto'] as String?;
        final file = raw['archivo'] as String?;
        if (text == null || file == null) return;
        byText[text] = RecordedClip(
          text: text,
          file: file,
          seconds: (raw['segundos'] as num?)?.toDouble() ?? 0,
          bundled: bundledFiles?.contains(file) ?? bundled,
        );
      }

      add(c['titulo']);
      add(c['ensenanza']);
      for (final e in (c['escenas'] as List?) ?? const []) {
        add(e);
      }
      if (byText.isNotEmpty) stories[key] = StoryClips(byText);
    }
    return RecordedVoice(
        language: language, stories: stories, store: store, player: player);
  }
}

class _NoStore implements ClipStore {
  @override
  Future<Source?> sourceFor(RecordedClip clip) async => null;
  @override
  Future<void> prefetch(Iterable<RecordedClip> clips) async {}
}

/// Pone la voz grabada al alcance de las pantallas de reproducción.
class RecordedVoiceScope extends InheritedWidget {
  const RecordedVoiceScope(
      {super.key, required this.voice, required super.child});

  final RecordedVoice voice;

  static RecordedVoice of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<RecordedVoiceScope>()?.voice ??
      RecordedVoice.none;

  @override
  bool updateShouldNotify(RecordedVoiceScope oldWidget) =>
      voice != oldWidget.voice;
}
