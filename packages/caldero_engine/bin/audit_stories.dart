import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';

/// Auditoría de calidad narrativa de un pack, con el motor real (esquema 1 o 2).
///
/// Uso: `dart run caldero_engine:audit_stories <pack.json> [cuentos=3000]`
///
/// Mide lo que el validador de gramática no mira: longitud, variedad, cuándo se presenta cada
/// personaje, saltos de lugar, presuposiciones y causas. Es informativo; las reglas que
/// bloquean un pack están en `validatePack` (se ejecutan en CI con `validate_pack`).
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
  final isPremise = pack.premises.isNotEmpty;

  String pct(int a, int b) => '${(100 * a / b).toStringAsFixed(1)} %';
  int words(String s) => RegExp(r'[\wáéíóúüñÁÉÍÓÚÜÑ]+').allMatches(s).length;
  String text(Story s) => s.scenes.map((e) => e.text).join(' ');
  String name(Entity e) => e is Character ? e.given : e.noun;
  int sum(Iterable<int> xs) => xs.fold(0, (a, b) => a + b);

  stdout.writeln('# Auditoría de «${pack.name}» v${pack.version} — $n cuentos '
      '(${isPremise ? 'premisas' : 'fragmentos por etapa'})\n');

  // 1. Longitud
  final lens = [for (final s in stories) words(text(s))]..sort();
  final mean = sum(lens) / lens.length;
  final sentences = sum(
        stories
            .map((s) => RegExp(r'[.!?»]\s').allMatches('${text(s)} ').length),
      ) /
      n;
  stdout.writeln('## 1. Longitud (palabras del cuento, sin la enseñanza)');
  stdout.writeln('media ${mean.toStringAsFixed(0)} · mín ${lens.first} · '
      'mediana ${lens[lens.length ~/ 2]} · máx ${lens.last}');
  stdout.writeln(
    'lectura en voz alta a ~110 palabras/min ≈ ${(mean / 110).toStringAsFixed(1)} min',
  );
  stdout.writeln('frases por cuento: ${sentences.toStringAsFixed(1)} · '
      'escenas por cuento: ${(sum(stories.map((s) => s.scenes.length)) / n).toStringAsFixed(1)}\n');

  // 2. Variedad
  stdout.writeln('## 2. Variedad real');
  for (final m in pack.morals) {
    final mine = stories.where((s) => s.moral.id == m.id).toList();
    if (mine.isEmpty) continue;
    final skeletons = {
      for (final s in mine) s.scenes.map((e) => e.fragmentId).join('>'),
    };
    final casts = {
      for (final s in mine)
        s.recipe.cast.entries.map((e) => '${e.key}=${e.value}').join(','),
    };
    final texts = {for (final s in mine) text(s)};
    stdout.writeln(
        '${m.name}: ${mine.length} cuentos → ${skeletons.length} secuencias de escenas, '
        '${casts.length} repartos, ${texts.length} textos distintos '
        '(${pct(texts.length, mine.length)} de los cuentos son únicos)');
  }
  if (isPremise) {
    final variants = sum(
      pack.premises.map((p) => sum(p.beats.map((b) => b.variants.length))),
    );
    stdout.writeln(
      'premisas: ${pack.premises.length} · variantes de escena: $variants',
    );
  } else {
    stdout.writeln('fragmentos del pack: ${pack.fragments.length}');
  }
  stdout.writeln('');

  // 3. Presencia de los personajes por escena
  stdout.writeln(
    '## 3. Presencia de los personajes por escena (% de cuentos donde se nombra)',
  );
  final maxScenes = stories.map((s) => s.scenes.length).reduce(
        (a, b) => a > b ? a : b,
      );
  stdout.writeln('${'escena'.padRight(8)}héroe    ayudante  villano');
  for (var i = 0; i < maxScenes; i++) {
    final here = stories.where((s) => s.scenes.length > i).toList();
    int count(String role) => here.where((s) {
          final e = s.cast[role];
          return e != null && s.scenes[i].text.contains(name(e));
        }).length;
    stdout.writeln(
      '${i + 1}'.padRight(8) +
          pct(count('hero'), here.length).padRight(9) +
          pct(count('helper'), here.length).padRight(10) +
          pct(count('villain'), here.length),
    );
  }
  int firstAppears(Story s, String role) {
    final e = s.cast[role];
    return e == null
        ? -1
        : s.scenes.indexWhere((x) => x.text.contains(name(e)));
  }

  stdout.writeln(
      '\nEscena en la que se nombra por primera vez (media; el total medio es '
      '${(sum(stories.map((s) => s.scenes.length)) / n).toStringAsFixed(1)}): '
      'ayudante ${(sum(stories.map((s) => firstAppears(s, 'helper') + 1)) / n).toStringAsFixed(1)} · '
      'villano ${(sum(stories.map((s) => firstAppears(s, 'villain') + 1)) / n).toStringAsFixed(1)}');
  final heroEnd = stories.where((s) {
    final k = s.scenes.length - 2;
    return k >= 0 && s.scenes[k].text.contains(name(s.cast['hero']!));
  }).length;
  final heroLast = stories
      .where((s) => s.scenes.last.text.contains(name(s.cast['hero']!)))
      .length;
  stdout.writeln(
    'el héroe se nombra en la resolución: ${pct(heroEnd, n)} · en el cierre: ${pct(heroLast, n)}',
  );
  int vanishes(String role) => stories.where((s) {
        final e = s.cast[role];
        if (e == null) return false;
        final first = firstAppears(s, role);
        final last = s.scenes.lastIndexWhere((x) => x.text.contains(name(e)));
        if (first < 0) return true;
        for (var i = first; i <= last; i++) {
          if (!s.scenes[i].text.contains(name(e))) return true;
        }
        return false;
      }).length;
  stdout.writeln(
      'cuentos donde el ayudante «desaparece» entre dos apariciones: ${pct(vanishes('helper'), n)} '
      '· el villano: ${pct(vanishes('villain'), n)}\n');

  // 4. Lugares
  stdout.writeln('## 4. Lugares');
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
      'cambios de lugar entre escenas: ${(jumps / n).toStringAsFixed(1)} por cuento'
      '${isPremise ? ' (todos narrados: el validador exige moves: true)' : ' (el texto no cuenta el regreso)'}\n');

  // 5. Presuposiciones
  stdout.writeln(
    '## 5. Marcadores de continuidad (presuponen algo que el cuento quizá no dijo)',
  );
  final markers = <String, RegExp>{
    '«una vez más / de nuevo / otra vez»':
        RegExp(r'una vez más|de nuevo|otra vez'),
    '«Entonces» al inicio de escena': RegExp(r'^Entonces'),
    '«Para resolverlo»': RegExp(r'Para resolverlo'),
    '«Allí / hasta allí»': RegExp(r'\bAllí\b|hasta allí'),
  };
  for (final e in markers.entries) {
    final c = stories
        .where((s) => s.scenes.any((x) => e.value.hasMatch(x.text)))
        .length;
    stdout.writeln('${e.key}: ${pct(c, n)} de los cuentos');
  }
  stdout.writeln('');

  // 6. Hilo causal y voz
  stdout.writeln('## 6. Hilo causal y voz');
  final causal =
      stories.map((s) => causalConnectors.allMatches(text(s)).length).toList();
  stdout.writeln(
      'conectores causales por cuento: media ${(sum(causal) / n).toStringAsFixed(1)} · '
      'mínimo ${causal.reduce((a, b) => a < b ? a : b)}');
  final dialog =
      stories.map((s) => RegExp('«[^»]+»').allMatches(text(s)).length).toList();
  stdout.writeln(
      'citas de diálogo por cuento: media ${(sum(dialog) / n).toStringAsFixed(1)} '
      '(${pct(dialog.where((d) => d == 0).length, n)} sin ninguna)');
  final sounds = RegExp(r'¡[A-ZÁÉÍÓÚ]{3,}[A-ZÁÉÍÓÚ!]*|¡[a-z]{2,}, [a-z]{2,}');
  stdout.writeln(
    'cuentos con onomatopeyas / sonidos: ${pct(stories.where((s) => sounds.hasMatch(text(s))).length, n)}\n',
  );

  // 7. ¿El reparto cambia la historia?
  stdout.writeln('## 7. ¿El reparto cambia lo que se lee?');
  final bySkeleton = <String, Set<String>>{};
  for (final s in stories) {
    (bySkeleton[s.scenes.map((e) => e.fragmentId).join('>')] ??= {})
        .add(text(s));
  }
  final perSkeleton = bySkeleton.values.map((v) => v.length).toList();
  stdout.writeln(
      '${bySkeleton.length} secuencias de escenas; cada una sale con '
      '${(sum(perSkeleton) / perSkeleton.length).toStringAsFixed(1)} textos distintos de media '
      '(${isPremise ? 'el reparto cambia gestos, voz, objetos y favores' : 'solo cambian los nombres'}).\n');

  // 8. Muestra
  stdout.writeln('## 8. Cuentos de muestra');
  for (final seed in [3, 5, 8, 11]) {
    final s = engine.generate(StoryOptions(seed: seed));
    stdout.writeln(
        '\n— seed $seed · ${s.title ?? s.moral.name} · ${s.moral.name} · '
        '${s.scenes.map((e) => e.fragmentId).join(' > ')}');
    for (final sc in s.scenes) {
      stdout.writeln('  ${sc.text}');
    }
  }
}
