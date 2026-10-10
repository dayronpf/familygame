import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';

/// Genera un corpus de cuentos legibles (Markdown) para revisión editorial, con las directivas de
/// escena (fondo, personajes en pantalla, ánimo) para poder juzgar también texto ↔ ilustración.
///
/// Uso: `dart run caldero_engine:sample_stories <pack.json> <carpeta> [por_enseñanza=12]`
///
/// Elige cuentos variados: repartos distintos primero y, después, otras combinaciones de variantes.
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Uso: dart run caldero_engine:sample_stories <pack.json> <carpeta> [n]',
    );
    exit(64);
  }
  final pack = Pack.fromJson(
    jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>,
  );
  final out = Directory(args[1])..createSync(recursive: true);
  final perMoral = args.length > 2 ? int.parse(args[2]) : 12;
  final engine = StoryEngine(pack);
  final index = StringBuffer('# Corpus de cuentos\n\n');

  for (final moral in pack.morals) {
    final chosen = <Story>[];
    final castsSeen = <String>{};
    final skeletons = <String>{};
    for (var seed = 1; seed < 20000 && chosen.length < perMoral; seed++) {
      final Story s;
      try {
        s = engine.generate(StoryOptions(seed: seed, valueId: moral.id));
      } on StoryGenerationException {
        break;
      }
      final cast =
          s.recipe.cast.entries.map((e) => '${e.key}=${e.value}').join(',');
      final skeleton = s.scenes.map((e) => e.fragmentId).join('>');
      // Primero un cuento por reparto distinto; luego, esqueletos nuevos.
      final fresh = castsSeen.add(cast);
      if (!fresh &&
          (chosen.length < castsSeen.length || !skeletons.add(skeleton))) {
        continue;
      }
      skeletons.add(skeleton);
      chosen.add(s);
    }
    for (final s in chosen) {
      final b = StringBuffer()
        ..writeln(
          '# ${s.title ?? s.moral.name} — ${s.moral.name} (semilla ${s.seed})',
        )
        ..writeln()
        ..writeln(
          'Reparto: ${s.recipe.cast.entries.map((e) => '${e.key}=${e.value}').join(', ')}',
        )
        ..writeln();
      var words = 0;
      for (var i = 0; i < s.scenes.length; i++) {
        final sc = s.scenes[i];
        final d = sc.directives;
        final onStage = [
          for (final e in stageEntries(d))
            e.who != null
                ? '${e.who}=${s.cast[e.who]?.id}${e.clip != null ? ' (${e.clip})' : ''}'
                : '${e.rig}${e.clip != null ? ' (${e.clip})' : ''}',
        ];
        final props = [
          for (final p in (d['props'] as List?) ?? const []) (p as Map)['prop'],
        ];
        b
          ..writeln('## Escena ${i + 1} · ${sc.fragmentId}')
          ..writeln(
            '*Ilustración: fondo «${d['bg']}» (${s.cast[d['bg']]?.id ?? '?'}), '
            'en pantalla (izq→der): ${onStage.isEmpty ? '—' : onStage.join(', ')}'
            '${props.isEmpty ? '' : ' · objetos: ${props.join(', ')}'}'
            '${d['light'] != null ? ' · luz: ${d['light']}' : ''}'
            '${d['offstage'] != null && (d['offstage'] as List).isNotEmpty ? ' · fuera de cámara: ${(d['offstage'] as List).join(', ')}' : ''}'
            ' · ánimo: ${d['mood']}*',
          )
          ..writeln()
          ..writeln(sc.text)
          ..writeln();
        words += RegExp(r'[\wáéíóúüñÁÉÍÓÚÜÑ]+').allMatches(sc.text).length;
      }
      b.writeln('**Enseñanza:** ${s.moral.text}  \n*(≈ $words palabras)*');
      final name = '${s.moral.id}-${s.seed.toString().padLeft(5, '0')}.md';
      File('${out.path}/$name').writeAsStringSync(b.toString());
      index.writeln(
        '- [$name]($name) — ${s.title}, ${s.recipe.cast['hero']}/${s.recipe.cast['helper']}/${s.recipe.cast['villain']}, $words palabras',
      );
    }
  }
  File('${out.path}/INDEX.md').writeAsStringSync(index.toString());
  stdout.writeln('Corpus en ${out.path}');
}
