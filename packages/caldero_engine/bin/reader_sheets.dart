import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';

/// Hojas para la prueba editorial con lectores de verdad (docs/24): un cuento por hoja, listo para imprimir o leer en
/// el móvil, con las preguntas que debe contestar quien lo lea en voz alta. No lleva ilustraciones ni directivas: el
/// lector ve solo lo que oirá el niño.
///
/// Uso: `dart run caldero_engine:reader_sheets <pack.json> <carpeta> [edades=2-3,4-5] [por_enseñanza=1]`
///
/// Escribe `<carpeta>/<edad>-<enseñanza>-<semilla>.html`, `index.html` y `respuestas.csv` (la cabecera de la hoja de
/// cálculo donde se vuelcan las respuestas; la columna `cuento` es el nombre del archivo).
void main(List<String> args) {
  if (args.length < 2) {
    stderr.writeln(
      'Uso: dart run caldero_engine:reader_sheets <pack.json> <carpeta> [edades] [por_enseñanza]',
    );
    exit(64);
  }
  final pack = Pack.fromJson(
    jsonDecode(File(args[0]).readAsStringSync()) as Map<String, Object?>,
  );
  final out = Directory(args[1])..createSync(recursive: true);
  final ages = (args.length > 2 ? args[2] : '2-3,4-5').split(',');
  final per = args.length > 3 ? int.parse(args[3]) : 1;
  final engine = StoryEngine(pack);

  final index = StringBuffer()
    ..writeln(_head('Cuentos para leer', ''))
    ..writeln('<h1>Cuentos para leer en voz alta</h1>')
    ..writeln(
      '<p>Pack ${pack.id} ${pack.version}. Una hoja por cuento.</p><ul>',
    );
  final csv = StringBuffer(
    'cuento,lector,edad_del_niño,se_entiende_1a5,frases_raras,atención,'
    'pidió_repetir,se_asustó,se_durmió,qué_dijo_que_trataba,edad_adecuada,cambiarías\n',
  );

  for (final age in ages) {
    for (final moral in pack.morals) {
      final seen = <String>{};
      var made = 0;
      for (var seed = 1; seed < 5000 && made < per; seed++) {
        final Story s;
        try {
          s = engine.generate(
            StoryOptions(seed: seed, valueId: moral.id, age: age),
          );
        } on StoryGenerationException {
          break;
        }
        // un cuento por premisa distinta (el primer fragmento lleva el id de la premisa)
        final premise = s.recipe.fragmentIds.first.split('.').first;
        if (!seen.add(premise)) continue;
        // solo premisas hechas para esa edad (no el «perfil más cercano»)
        if (!pack.premises.any((p) => p.id == premise && p.fitsAge(age))) {
          continue;
        }
        final name = '$age-${moral.id}-${seed.toString().padLeft(4, '0')}';
        File('${out.path}/$name.html').writeAsStringSync(_sheet(pack, s, age));
        index.writeln(
          '<li><a href="$name.html">${_esc(s.title ?? s.moral.name)}</a> · '
          '$age · ${moral.name}</li>',
        );
        csv.writeln('$name,,,,,,,,,,,');
        made++;
      }
    }
  }
  index.writeln('</ul></body></html>');
  File('${out.path}/index.html').writeAsStringSync(index.toString());
  File('${out.path}/respuestas.csv').writeAsStringSync(csv.toString());
  stdout.writeln('Hojas en ${out.path}');
}

String _esc(String s) => const HtmlEscape().convert(s);

String _head(String title, String extra) => '''<!doctype html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_esc(title)}</title>
<style>
  body { font-family: Georgia, serif; max-width: 42rem; margin: 2rem auto; padding: 0 1rem; line-height: 1.55; color: #222; }
  h1 { font-size: 1.7rem; margin-bottom: .2rem; }
  .story p { font-size: 1.2rem; margin: 0 0 1.1rem; }
  .meta { color: #777; font-size: .8rem; }
  .form { border: 2px solid #999; border-radius: 8px; padding: .8rem 1rem; margin-top: 2rem; font-family: sans-serif; font-size: .95rem; }
  .form li { margin-bottom: .9rem; }
  .line { display: block; border-bottom: 1px solid #aaa; height: 1.6rem; }
  @media print { body { margin: 1cm; } .form { page-break-inside: avoid; } }
</style>$extra</head><body>''';

String _sheet(Pack pack, Story s, String age) {
  final b = StringBuffer()..writeln(_head(s.title ?? s.moral.name, ''));
  b
    ..writeln('<h1>${_esc(s.title ?? s.moral.name)}</h1>')
    ..writeln(
      '<p class="meta">Cuento para $age años · lee en voz alta, despacio, '
      'y apunta lo que pase. No expliques la enseñanza.</p>',
    )
    ..writeln('<div class="story">');
  for (final sc in s.scenes) {
    b.writeln('<p>${_esc(sc.text)}</p>');
  }
  b
    ..writeln('<p><em>${_esc(s.moralLine)}</em></p></div>')
    ..writeln('''<div class="form"><ol>
<li><b>¿Se entiende de qué va?</b> 1 = nada, 5 = perfectamente &nbsp; 1 · 2 · 3 · 4 · 5</li>
<li><b>Frases raras o difíciles de leer en voz alta</b> (copia la frase)<span class="line"></span><span class="line"></span></li>
<li><b>El niño o la niña…</b> ☐ estuvo atento/a &nbsp; ☐ pidió repetir &nbsp; ☐ se asustó &nbsp; ☐ se rio &nbsp; ☐ se durmió &nbsp; ☐ se distrajo</li>
<li><b>Al acabar, pregúntale «¿de qué iba el cuento?»</b> y apunta lo que dice, con sus palabras<span class="line"></span><span class="line"></span></li>
<li><b>La edad:</b> ☐ muy fácil &nbsp; ☐ justo &nbsp; ☐ muy difícil</li>
<li><b>¿Qué cambiarías?</b><span class="line"></span><span class="line"></span></li>
</ol></div>''')
    ..writeln(
      '<p class="meta">${pack.id} ${pack.version} · semilla ${s.seed} · '
      '${s.recipe.fragmentIds.join(' › ')}</p></body></html>',
    );
  return b.toString();
}
