import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/scene_painter.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Auditoría visual (herramienta, no prueba): dibuja **cada variante de cada escena** de todos los cuentos, en cada
/// camino de sus preguntas, con el mismo pintor que la app, y la guarda junto a su texto. Escribe:
///   * `<paquete>/<premisa>/<nn>_<variante>.png` — la escena;
///   * `scenes.jsonl` — una línea por escena (texto, enseñanza, imagen…), para el revisor automático
///     (`tools/audit/visual_audit.py`, que pide a un modelo con visión que compare texto y dibujo);
///   * `index.html` — todo junto para revisarlo a ojo (o con los hallazgos del revisor, si ya pasó).
///
/// Uso (desde `app/`):
///   AUDIT_OUT=/tmp/auditoria flutter test test/audit_visual_manual_test.dart
/// `AUDIT_PACKS=medieval` y `AUDIT_PREMISES=sombras,taza` limitan qué se dibuja.
void main() {
  final out = Platform.environment['AUDIT_OUT'];
  Set<String> list(String key) => (Platform.environment[key] ?? '')
      .split(',')
      .where((e) => e.isNotEmpty)
      .toSet();
  final packs = list('AUDIT_PACKS');
  final premises = list('AUDIT_PREMISES');

  testWidgets('auditoría visual de todos los cuentos', (tester) async {
    await tester.runAsync(() async {
      final art = StageArt(await loadArtLibrary(FileBundle()));
      Directory(out!).createSync(recursive: true);
      final jsonl = StringBuffer();
      final html = StringBuffer()
        ..writeln(
            '<!doctype html><meta charset="utf-8"><title>Auditoría visual</title>'
            '<style>body{font-family:system-ui;background:#1b1438;color:#fff6e6;margin:24px}'
            'h2{color:#ffd36e}figure{display:inline-block;width:360px;vertical-align:top;margin:8px;'
            'background:#2a1f5c;border-radius:12px;padding:8px}img{width:100%;border-radius:8px}'
            'figcaption{font-size:13px;line-height:1.4}.id{opacity:.6;font-size:11px}'
            '.lesson{color:#8ee3c8}</style><h1>Auditoría visual</h1>');
      var total = 0;
      for (final packId in ['medieval', 'mar', 'cosmos']) {
        if (packs.isNotEmpty && !packs.contains(packId)) continue;
        final pack = Pack.fromJson(
          jsonDecode(File('assets/packs/$packId/pack.json').readAsStringSync())
              as Map<String, Object?>,
        );
        final engine = StoryEngine(pack);
        for (final premise in pack.premises) {
          if (premises.isNotEmpty && !premises.contains(premise.id)) continue;
          final dir = '$packId/${premise.id}';
          Directory('$out/$dir').createSync(recursive: true);
          // Caminos: sin forzar y forzando cada opción de la primera pregunta
          final firstChoice = premise.beats
              .map((b) => b.choice)
              .whereType<Choice>()
              .firstOrNull;
          final paths = <List<String>>[
            const [],
            if (firstChoice != null)
              for (final o in firstChoice.options) [o.id],
          ];
          final variants = {
            for (final b in premise.beats)
              for (final v in b.variants) v.id,
          };
          final rendered = <String>{};
          html.writeln(
              '<h2>${premise.title} <span class="id">$packId:${premise.id}</span></h2>'
              '<p class="lesson">Enseñanza: ${premise.lesson ?? '(falta)'}</p>');
          for (final path in paths) {
            for (var seed = 1; seed < 400; seed++) {
              if (path.isEmpty &&
                  variants
                      .every((v) => rendered.any((k) => k.startsWith('$v|')))) {
                break;
              }
              final Story story;
              try {
                story = engine.generate(StoryOptions(
                    seed: seed,
                    premiseId: premise.id,
                    choices: path,
                    interactive: false));
              } catch (_) {
                break;
              }
              var added = false;
              for (var i = 0; i < story.scenes.length; i++) {
                final s = story.scenes[i];
                // Una vez por variante y por lo que se dibuja (con «when», el dibujo cambia según el camino)
                final key = '${s.fragmentId}|${jsonEncode(s.directives)}';
                if (rendered.contains(key)) continue;
                final setup = stageFor(art, story.cast, s.directives);
                if (setup == null) continue;
                rendered.add(key);
                added = true;
                final name =
                    '${(i + 1).toString().padLeft(2, '0')}_${s.fragmentId.split('.').skip(1).join('_')}'
                    '${path.isEmpty ? '' : '_${path.join('_')}'}_${rendered.length}.png';
                File('$out/$dir/$name')
                    .writeAsBytesSync(await _render(setup, 0.5));
                total++;
                final record = {
                  'pack': packId,
                  'premise': premise.id,
                  'title': story.title,
                  'lesson': story.moralLine,
                  'scene': i + 1,
                  'of': story.scenes.length,
                  'fragment': s.fragmentId,
                  'path': path,
                  'text': s.text,
                  'previous': i == 0 ? null : story.scenes[i - 1].text,
                  'hero': story.cast['hero'] is Character
                      ? (story.cast['hero']! as Character).given
                      : null,
                  'image': '$dir/$name',
                  'directives': s.directives,
                };
                jsonl.writeln(jsonEncode(record));
                html.writeln(
                    '<figure data-image="$dir/$name"><img src="$dir/$name" loading="lazy">'
                    '<figcaption><b>${i + 1}/${story.scenes.length}</b> ${const HtmlEscape().convert(s.text)}'
                    '<div class="id">${s.fragmentId}${path.isEmpty ? '' : ' · camino ${path.join(',')}'}</div>'
                    '</figcaption></figure>');
              }
              if (!added && path.isNotEmpty) break;
            }
          }
        }
      }
      File('$out/scenes.jsonl').writeAsStringSync(jsonl.toString());
      File('$out/index.html').writeAsStringSync(html.toString());
      debugPrint('Auditoría: $total escenas en $out');
    });
  }, skip: out == null, timeout: const Timeout(Duration(minutes: 30)));
}

Future<Uint8List> _render(StageSetup setup, double t) async {
  const width = 640;
  final view = setup.view;
  final height = (width * view.height / view.width).round();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  ScenePainter(
    scene: setup.scene,
    actors: setup.actors,
    props: setup.props,
    tint: setup.tint,
    vignette: setup.focus,
    ropes: setup.ropes,
    blurBackground: setup.focus,
    clock: ValueNotifier<double>(t),
    view: view,
  ).paint(canvas, Size(width.toDouble(), height.toDouble()));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
