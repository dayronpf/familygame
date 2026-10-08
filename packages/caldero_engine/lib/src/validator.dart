import 'engine.dart';
import 'grammar.dart';
import 'models.dart';

/// «Y La urraca…»: artículo capitalizado que no abre frase.
final RegExp _midSentenceCaps = RegExp(
  r'[^.!?»¿¡\s]\s+(?:El|La|Un|Una|En)\s\S',
);

/// «a el» / «de el»: faltó la contracción (usar `{rol.al}` o `{rol.del}`).
final RegExp _missingContraction = RegExp(r'(?:^|\s)(?:[Aa]|[Dd]e) el(?:\s|$)');

class ValidationReport {
  ValidationReport({required this.rendersChecked, required this.problems});

  final int rendersChecked;
  final List<String> problems;

  bool get isValid => problems.isEmpty;
}

/// Valida un pack: estructura, referencias, gramática de plantillas y cobertura.
///
/// Es el equivalente en Dart del `--lint` del prototipo y se ejecuta en CI.
ValidationReport validatePack(Pack pack, {int coverageSeeds = 50}) {
  final problems = <String>{};
  var renders = 0;

  _checkStructure(pack, problems);

  // Renderiza cada fragmento con todos los repartos posibles.
  final heroes = pack.withRole('hero');
  final helpers = pack.withRole('helper');
  final villains = pack.withRole('villain');
  for (final hero in heroes) {
    for (final helper in helpers) {
      if (helper.id == hero.id) continue;
      for (final villain in villains) {
        for (final place in pack.places) {
          for (final place2 in pack.places) {
            if (place.id == place2.id) continue;
            final cast = <String, Entity>{
              'hero': hero,
              'helper': helper,
              'villain': villain,
              'place': place,
              'place2': place2,
            };
            for (final f in pack.fragments) {
              renders++;
              _checkRender(f, cast, problems);
            }
          }
        }
      }
    }
  }

  // Cobertura: cada enseñanza debe poder recorrer todas las etapas.
  if (problems.isEmpty) {
    final engine = StoryEngine(pack);
    for (final moral in pack.morals) {
      for (var seed = 0; seed < coverageSeeds; seed++) {
        try {
          engine.generate(StoryOptions(seed: seed, valueId: moral.id));
        } on StoryGenerationException catch (e) {
          problems.add('cobertura «${moral.id}» semilla $seed: ${e.message}');
          break;
        }
      }
    }
  }

  return ValidationReport(
    rendersChecked: renders,
    problems: problems.toList()..sort(),
  );
}

void _checkRender(Fragment f, Map<String, Entity> cast, Set<String> problems) {
  final String out;
  try {
    out = renderTemplate(f.text, cast);
  } on TemplateException catch (e) {
    problems.add('${f.id}: ${e.message}');
    return;
  }
  final last = out.trimRight();
  if (out.contains('  ') ||
      out.contains('{') ||
      !(last.endsWith('.') ||
          last.endsWith('!') ||
          last.endsWith('?') ||
          last.endsWith('»'))) {
    final tail = out.length <= 40 ? out : out.substring(out.length - 40);
    problems.add('${f.id}: texto sospechoso: "$tail"');
  }
  final contraction = _missingContraction.firstMatch(out);
  if (contraction != null) {
    problems.add(
      '${f.id}: falta contracción: «${contraction.group(0)!.trim()}»',
    );
  }
  final mid = _midSentenceCaps.firstMatch(out);
  if (mid != null) {
    problems.add(
      '${f.id}: artículo en mayúscula a mitad de frase: «${mid.group(0)}»',
    );
  }
}

void _checkStructure(Pack pack, Set<String> problems) {
  void duplicates(String kind, Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) problems.add('$kind duplicado: "$id"');
    }
  }

  duplicates('personaje', pack.characters.map((c) => c.id));
  duplicates('lugar', pack.places.map((p) => p.id));
  duplicates('enseñanza', pack.morals.map((m) => m.id));
  duplicates('fragmento', pack.fragments.map((f) => f.id));

  final moralIds = pack.morals.map((m) => m.id).toSet();
  final added = pack.fragments.expand((f) => f.adds).toSet();
  for (final f in pack.fragments) {
    for (final v in f.values) {
      if (v != anyValue && !moralIds.contains(v)) {
        problems.add('${f.id}: enseñanza inexistente "$v"');
      }
    }
    for (final r in f.requires) {
      if (!added.contains(r)) {
        problems.add('${f.id}: requiere "$r" pero ningún fragmento lo añade');
      }
    }
  }
}
