import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';

/// Texto fijo de cada cuento de un catálogo (docs/31): el mismo que la app muestra al reproducir el audio grabado.
/// Cada cuento se genera con su semilla y el género de su héroe, sin el nombre del niño y sin preguntas.
///
/// Uso (desde packages/caldero_engine):
///   dart run bin/catalog_texts.dart ../../content/catalogo/lanzamiento-es.json salida.json
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
        'Uso: dart run bin/catalog_texts.dart <catalogo.json> <salida.json>');
    exit(64);
  }
  final catalogFile = File(args[0]);
  final catalog =
      jsonDecode(catalogFile.readAsStringSync()) as Map<String, Object?>;
  final packsDir = '${catalogFile.parent.parent.path}/packs';
  final engines = <String, StoryEngine>{};
  final out = <Map<String, Object?>>[];
  var problems = 0;
  for (final entry
      in (catalog['cuentos']! as List).cast<Map<String, Object?>>()) {
    final id = entry['id']! as String;
    final [packId, premiseId] = id.split(':');
    final engine = engines.putIfAbsent(
      packId,
      () => StoryEngine(Pack.fromJson(
        jsonDecode(File('$packsDir/$packId/pack.json').readAsStringSync())
            as Map<String, Object?>,
      )),
    );
    final story = engine.generate(StoryOptions(
      seed: entry['semilla']! as int,
      premiseId: premiseId,
      heroGender: entry['generoHeroe'] as String?,
      interactive: false,
    ));
    final hero = story.cast['hero'];
    final heroName = hero is Character ? hero.given : null;
    if (entry['heroe'] != null && heroName != entry['heroe']) {
      stderr.writeln(
          '$id: el héroe salió «$heroName» y el catálogo dice «${entry['heroe']}»');
      problems++;
    }
    out.add({
      'id': id,
      'titulo': story.title,
      'ensenanza': story.moralLine,
      'heroe': heroName,
      'escenas': [for (final s in story.scenes) s.text],
    });
  }
  File(args[1]).writeAsStringSync(const JsonEncoder.withIndent(' ').convert({
    'version': catalog['version'],
    'idioma': catalog['idioma'],
    'cuentos': out,
  }));
  final chars = out.fold<int>(
      0,
      (n, c) =>
          n +
          (c['escenas']! as List)
              .fold<int>(0, (m, s) => m + (s as String).length));
  print('${out.length} cuentos, $chars caracteres → ${args[1]}');
  if (problems > 0) exit(1);
}
