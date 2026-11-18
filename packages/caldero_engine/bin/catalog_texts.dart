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
      'Uso: dart run bin/catalog_texts.dart <catalogo.json> <salida.json>',
    );
    exit(64);
  }
  final catalogFile = File(args[0]);
  final catalog = FixedCatalog.fromJson(
    jsonDecode(catalogFile.readAsStringSync()) as Map<String, Object?>,
  );
  final packsDir = '${catalogFile.parent.parent.path}/packs';
  final engines = <String, StoryEngine>{};
  final out = <Map<String, Object?>>[];
  var problems = 0;
  for (final entry in catalog.entries) {
    final id = entry.id;
    final engine = engines.putIfAbsent(
      entry.packId,
      () => StoryEngine(
        Pack.fromJson(
          jsonDecode(
            File('$packsDir/${entry.packId}/pack.json').readAsStringSync(),
          ) as Map<String, Object?>,
        ),
      ),
    );
    // Las mismas opciones con que la app cuenta el cuento (CatalogEntry.options): así el texto es el grabado.
    final story = engine.generate(entry.options());
    final heroName = CatalogEntry.heroOf(story);
    if (entry.heroName != null && heroName != entry.heroName) {
      stderr.writeln(
        '$id: el héroe salió «$heroName» y el catálogo dice «${entry.heroName}»',
      );
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
  File(args[1]).writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'version': catalog.version,
      'idioma': catalog.language,
      'cuentos': out,
    }),
  );
  final chars = out.fold<int>(
    0,
    (n, c) =>
        n +
        (c['escenas']! as List)
            .fold<int>(0, (m, s) => m + (s as String).length),
  );
  print('${out.length} cuentos, $chars caracteres → ${args[1]}');
  if (problems > 0) exit(1);
}
