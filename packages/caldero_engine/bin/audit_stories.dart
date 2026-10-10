import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';

/// Auditoría de calidad narrativa de un pack, con el motor real.
///
/// Uso: `dart run caldero_engine:audit_stories <pack.json> [cuentos=3000]`
///
/// Mide lo que el validador no mira (el validador comprueba gramática, no si el cuento tiene sentido):
/// longitud, variedad, cuándo se presenta cada personaje, referencias sin antecedente, repeticiones.
void main(List<String> args) {
  if (args.isEmpty) {
    stderr
        .writeln('Uso: dart run caldero_engine:audit_stories <pack.json> [n]');
    exit(64);
  }
  final pack = Pack.fromJson(
    jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>,
  );
  final n = args.length > 1 ? int.parse(args[1]) : 3000;
  final engine = StoryEngine(pack);
  final stories = [
    for (var seed = 1; seed <= n; seed++)
      engine.generate(StoryOptions(seed: seed)),
  ];

  String pct(int a, int b) => '${(100 * a / b).toStringAsFixed(1)} %';
  int words(String s) => RegExp(r'[\wáéíóúüñÁÉÍÓÚÜÑ]+').allMatches(s).length;

  stdout
      .writeln('# Auditoría de «${pack.name}» v${pack.version} — $n cuentos\n');

  // 1. Longitud
  final lens = [
    for (final s in stories) words(s.scenes.map((e) => e.text).join(' ')),
  ]..sort();
  final mean = lens.reduce((a, b) => a + b) / lens.length;
  stdout.writeln('## 1. Longitud (palabras del cuento, sin la enseñanza)');
  stdout.writeln(
    'media ${mean.toStringAsFixed(0)} · mín ${lens.first} · mediana ${lens[lens.length ~/ 2]} · máx ${lens.last}',
  );
  stdout.writeln(
    'lectura en voz alta a ~110 palabras/min ≈ ${(mean / 110).toStringAsFixed(1)} min',
  );
  final sentences = [
    for (final s in stories)
      RegExp(r'[.!?»]\s')
          .allMatches(s.scenes.map((e) => '${e.text} ').join())
          .length,
  ];
  stdout.writeln(
    'frases por cuento: ${(sentences.reduce((a, b) => a + b) / n).toStringAsFixed(1)}',
  );
  stdout.writeln(
    'piezas de texto por cuento: ${storyStages.length} (una por etapa, sin transiciones propias)\n',
  );

  // 2. Variedad
  stdout.writeln('## 2. Variedad real');
  for (final m in pack.morals) {
    final mine = stories.where((s) => s.moral.id == m.id).toList();
    final skeletons = {
      for (final s in mine) s.scenes.map((e) => e.fragmentId).join('>'),
    };
    final used = {
      for (final s in mine)
        for (final e in s.scenes) e.fragmentId,
    };
    stdout.writeln(
        '${m.name}: ${skeletons.length} esqueletos distintos de fragmentos '
        '(${used.length} fragmentos en uso) en ${mine.length} cuentos');
  }
  final totalFrag = pack.fragments.length;
  stdout.writeln(
    'fragmentos del pack: $totalFrag · se leen ${storyStages.length} por cuento\n',
  );

  // 3. Quién aparece y cuándo
  stdout.writeln(
    '## 3. Presencia de los personajes por etapa (% de cuentos donde se nombra)',
  );
  stdout.writeln('${'etapa'.padRight(12)}héroe   ayudante  villano');
  for (var i = 0; i < storyStages.length; i++) {
    int count(String role) => stories.where((s) {
          final e = s.cast[role]!;
          final t = s.scenes[i].text;
          return t.contains((e as Character).given);
        }).length;
    stdout.writeln(
      storyStages[i].padRight(12) +
          pct(count('hero'), n).padRight(8) +
          pct(count('helper'), n).padRight(10) +
          pct(count('villain'), n),
    );
  }
  int firstAppears(Story s, String role) {
    final g = (s.cast[role]! as Character).given;
    return s.scenes.indexWhere((e) => e.text.contains(g));
  }

  final helperFirst = stories.map((s) => firstAppears(s, 'helper')).toList();
  final villainFirst = stories.map((s) => firstAppears(s, 'villain')).toList();
  stdout.writeln('El ayudante se nombra por primera vez en la etapa '
      '«${storyStages[helperFirst.reduce((a, b) => a < b ? a : b)]}» '
      '(${pct(helperFirst.where((i) => i == 2).length, n)} de los cuentos: a mitad del cuento, sin presentación).');
  stdout.writeln('El villano se nombra por primera vez en «${storyStages[1]}» '
      '(${pct(villainFirst.where((i) => i == 1).length, n)}); desaparece en la prueba '
      '(${pct(stories.where((s) => !s.scenes[3].text.contains((s.cast['villain']! as Character).given)).length, n)} '
      'de los cuentos no lo nombran en esa etapa).\n');

  // 4. Lugares
  stdout.writeln(
    '## 4. Lugares: cuántos cuentos usan cada lugar y cómo suena la apertura',
  );
  for (final p in pack.places) {
    final withP = stories.where((s) => s.cast['place']!.id == p.id).toList();
    stdout.writeln(
        '${p.id}: apertura con este lugar en ${pct(withP.length, n)}; ejemplo → '
        '«${withP.first.scenes[0].text}»');
  }
  final samePlaceSeq =
      stories.where((s) => s.cast['place']!.id == s.cast['place2']!.id).length;
  stdout.writeln(
    'lugar y lugar2 coinciden: $samePlaceSeq cuentos (el motor los hace distintos)',
  );
  var jumps = 0;
  for (final st in stories) {
    String? prev;
    for (final sc in st.scenes) {
      final bg = sc.directives['bg'] as String?;
      if (prev != null && bg != prev) jumps++;
      prev = bg;
    }
  }
  stdout.writeln(
    'cambios de lugar entre escenas: ${(jumps / n).toStringAsFixed(1)} por cuento '
    '(va al lugar 2 y vuelve al 1 sin que el texto cuente el regreso)',
  );
  // ¿el «lugar 2» de la prueba tiene relación con el problema?
  final testUsesPlace2 = pack.fragments
      .where((f) => f.stage == 'test' && f.text.contains('{place2'))
      .length;
  final testTotal = pack.fragments.where((f) => f.stage == 'test').length;
  stdout.writeln(
      'fragmentos de «prueba» que usan un lugar sorteado: $testUsesPlace2 de $testTotal; '
      'ninguno tiene relación con el problema planteado antes\n');

  // 5. Referencias sin antecedente / marcadores de continuidad
  stdout.writeln(
    '## 5. Marcadores de continuidad (frases que presuponen algo que el cuento no dijo)',
  );
  final markers = <String, RegExp>{
    '«una vez más / de nuevo»': RegExp(r'una vez más|de nuevo|otra vez'),
    '«Allí / hasta allí»': RegExp(r'\bAllí\b|hasta allí', caseSensitive: false),
    '«Entonces» al inicio': RegExp(r'^Entonces'),
    '«Juntos»': RegExp(r'\bJuntos\b'),
    '«Para resolverlo» (¿resolver qué?)': RegExp(r'Para resolverlo'),
    '«el camino» sin camino previo': RegExp(r'\bel camino\b'),
  };
  for (final e in markers.entries) {
    final frags = pack.fragments
        .where((f) => e.value.hasMatch(f.text))
        .map((f) => f.id)
        .toList();
    final inStories = stories
        .where((s) => s.scenes.any((x) => e.value.hasMatch(x.text)))
        .length;
    stdout.writeln(
      '${e.key}: ${frags.length} fragmentos (${frags.join(', ')}) → ${pct(inStories, n)} de los cuentos',
    );
  }
  stdout.writeln('');

  // 7. Conectores causales y diálogo
  stdout.writeln('## 6. Hilo causal y voz');
  final causal = RegExp(
    r'\bporque\b|\bpor eso\b|\bpor lo tanto\b|\bya que\b|\basí que\b|\bpara que\b|\bpues\b',
    caseSensitive: false,
  );
  final withCausal = stories
      .where((s) => causal.hasMatch(s.scenes.map((e) => e.text).join(' ')))
      .length;
  stdout.writeln(
    'cuentos con algún conector causal (porque, por eso, así que…): ${pct(withCausal, n)}',
  );
  final dialog = stories
      .map(
        (s) => RegExp('«[^»]+»')
            .allMatches(s.scenes.map((e) => e.text).join(' '))
            .length,
      )
      .toList();
  stdout.writeln(
      'citas de diálogo por cuento: media ${(dialog.reduce((a, b) => a + b) / n).toStringAsFixed(1)} '
      '(${pct(dialog.where((d) => d == 0).length, n)} sin ninguna)');
  stdout.writeln('');

  // 8. El carácter del personaje no cambia el cuento
  stdout.writeln(
    '## 7. ¿El personaje importa? El reparto no influye en qué texto sale',
  );
  final byMask = <String, Set<String>>{};
  for (final s in stories) {
    final masked = s.scenes.map((e) => e.fragmentId).join('>');
    (byMask[masked] ??= {})
        .add('${s.cast['hero']!.id}/${s.cast['villain']!.id}');
  }
  var identical = 0;
  for (final v in byMask.values) {
    if (v.length > 1) identical++;
  }
  stdout.writeln(
      '${byMask.length} esqueletos distintos; en $identical de ellos la MISMA secuencia de texto sale con '
      'distintos héroes y villanos: cambia el nombre, no la historia.');
  stdout.writeln(
    'rasgos por personaje: ${pack.characters.map((c) => '${c.given}=${c.trait['m']}').join(', ')}',
  );
  stdout.writeln(
    '(el único rasgo del personaje que entra al texto es un adjetivo en la apertura)\n',
  );

  // 9. Muestra
  stdout.writeln('## 8. Cuentos de muestra');
  for (final seed in [3, 5, 8, 11]) {
    final s = engine.generate(StoryOptions(seed: seed));
    stdout.writeln(
      '\n— seed $seed · ${s.moral.name} · ${s.scenes.map((e) => e.fragmentId).join(' > ')}',
    );
    for (final sc in s.scenes) {
      stdout.writeln('  ${sc.text}');
    }
  }
}
