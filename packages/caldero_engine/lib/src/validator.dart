import 'dart:math' as math;

import 'age.dart';
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
  for (final premise in pack.premises) {
    renders += _checkPremise(pack, premise, problems, coverageSeeds);
  }

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
  if (problems.isEmpty && pack.premises.isEmpty) {
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

void _checkRender(
  Fragment f,
  Map<String, Entity> cast,
  Set<String> problems, {
  AttrChooser? choose,
  AltPicker? alt,
}) {
  final String out;
  try {
    out = renderTemplate(f.text, cast, choose: choose, alt: alt);
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
  duplicates('premisa', pack.premises.map((p) => p.id));
  duplicates('objeto', pack.props.map((p) => p.id));

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

// ---------------------------------------------------------------------------
// Reglas de coherencia de las premisas (esquema 2)
// ---------------------------------------------------------------------------

/// Un cuento más corto que esto es un resumen, no una historia para leer en voz alta.
const int minStoryWords = 420;
const int maxStoryWords = 950;

/// Mínimo de escenas en las que debe aparecer el nombre del héroe.
const double minHeroPresence = 0.7;

/// Conectores que enlazan causa y efecto; sin ellos la trama es una lista de sucesos.
final RegExp causalConnectors = RegExp(
  r'\bporque\b|\bpor eso\b|\bpor lo tanto\b|\bya que\b|\bpor eso mismo\b|\basí que\b|\bpara que\b|\bpues\b|\bpor culpa\b|\bgracias a\b|\bde modo que\b|\bcomo\b[^.?!»]{3,40},',
  caseSensitive: false,
);

/// Adjetivos y participios con género que suelen referirse al héroe (y «él»/«ella», que con un reparto
/// al azar salen mal: usa el nombre o «los dos»). En una plantilla se escriben con
/// `{hero.o}` («quiet{hero.o}»); si aparecen literales, con una heroína (o un héroe) salen mal.
final RegExp _fixedGender = RegExp(
  r'\b(?:quiet|dormid|tranquil|liger|helad|cansad|asustad|sorprendid|content|preocupad|confundid)(?:o|a)\b'
  r'|\b(?:yo|entró|siguió|quedó|iba|estaba|fue|llegó|subió|ir|irse|iría|quedarse|cruz\w+)\s+sol(?:o|a)\b'
  r'|(?<![\wáéíóúüñ])(?:él|ella)(?![\wáéíóúüñ])',
);

/// Mínimo y máximo de palabras de un cuento de [premise]: los de su perfil de edad con un margen (el reparto de cada
/// versión cambia un poco la longitud); sin edad declarada, los generales.
({int min, int max}) storyWordLimits(Premise premise) {
  final profiles = [
    for (final a in premise.ages)
      if (AgeProfile.byId(a) != null) AgeProfile.byId(a)!,
  ];
  if (profiles.isEmpty) return (min: minStoryWords, max: maxStoryWords);
  final lo = profiles.map((p) => p.minWords).reduce(math.min);
  final hi = profiles.map((p) => p.maxWords).reduce(math.max);
  return (min: (lo * 0.85).floor(), max: (hi * 1.15).ceil());
}

/// Palabras que no caben en un cuento para 2–3 años (ni miedo, ni oscuridad amenazante, ni separación).
final RegExp _notForToddlers = RegExp(
  r'\b(?:miedo|asust\w*|susto|oscur\w*|monstruo\w*|peligr\w*|muert\w*|mori\w*|sangre|matar|perdid[oa]s?|llor[óo]\w*|grit[óo]\w*|enfad\w*|gruñ\w*|ladr[óo]n\w*|bandid\w*|espada\w*|arma|armas)\b',
  caseSensitive: false,
);

/// Palabras que no caben en un cuento para 4–5 años (sin peligro real; las emociones se nombran pero se resuelven).
final RegExp _notForLittle = RegExp(
  r'\b(?:monstruo\w*|peligr\w*|muert\w*|mori\w*|sangre|matar|ladr[óo]n\w*|bandid\w*|espada\w*|arma|armas|fantasma\w*|bruja\w*)\b',
  caseSensitive: false,
);

/// Reglas por edad (docs/18): oración típica, longitud máxima de oración, contenido y final tranquilo.
void _checkAge(Premise premise, List<String> texts, void Function(String) add) {
  if (texts.isNotEmpty && texts.last.contains('?')) {
    add('el último párrafo termina con una pregunta abierta (para dormir se cierra en calma)');
  }
  if (premise.ages.isEmpty) return;
  final profiles = [
    for (final a in premise.ages)
      if (AgeProfile.byId(a) != null) AgeProfile.byId(a)!,
  ];
  final m = measureText(texts);
  final lo = profiles.map((p) => p.minSentence).reduce(math.min) - 1.5;
  final hi = profiles.map((p) => p.maxSentence).reduce(math.max) + 2.0;
  if (m.avgSentence < lo || m.avgSentence > hi) {
    add(
      'oración media de ${m.avgSentence.toStringAsFixed(1)} palabras: fuera de lo típico '
      'para ${premise.ages.join('/')} (${lo.toStringAsFixed(1)}–${hi.toStringAsFixed(1)})',
    );
  }
  final young = premise.ages.every((a) => a == '2-3' || a == '4-5');
  if (!young) return;
  final maxSentence = profiles.map((p) => p.maxSentence).reduce(math.max) * 2;
  if (m.maxSentence > maxSentence) {
    add('una oración de ${m.maxSentence} palabras (máximo $maxSentence para ${premise.ages.join('/')})');
  }
  final toddler = premise.ages.contains('2-3');
  final banned = toddler ? _notForToddlers : _notForLittle;
  for (final t in texts) {
    final hit = banned.firstMatch(t);
    if (hit != null) {
      add('«${hit.group(0)}» no cabe en un cuento para ${premise.ages.join('/')}');
    }
  }
}

int _words(String s) => RegExp(r'[\wáéíóúüñÁÉÍÓÚÜÑ]+').allMatches(s).length;

String _name(Entity e) => e is Character ? e.given : e.noun;

/// Comprueba una premisa: estructura, todos los repartos posibles y, sobre cuentos generados,
/// que haya hilo (presentaciones, objetos que se retoman, viajes contados, longitud, causas).
/// Devuelve cuántos textos renderizó.
int _checkPremise(
  Pack pack,
  Premise premise,
  Set<String> problems,
  int seeds,
) {
  final pid = premise.id;
  var renders = 0;
  if (pack.moralById(premise.value) == null && premise.value != anyValue) {
    problems.add('$pid: enseñanza inexistente "${premise.value}"');
  }

  // Los cuentos para 2–5 años no llevan villano (sin peligro real)
  if (premise.ages.isNotEmpty &&
      premise.ages.every((a) => a == '2-3' || a == '4-5')) {
    for (final e in premise.cast.entries) {
      if (e.value.kind == 'character' && e.value.roles.contains('villain')) {
        problems.add(
          '$pid: «${e.key}» es un villano y el cuento es para ${premise.ages.join('/')}',
        );
      }
    }
  }

  // --- estructura estática
  final slotKinds = {for (final e in premise.cast.entries) e.key: e.value.kind};
  if (slotKinds['hero'] != 'character') {
    problems.add('$pid: falta la ranura «hero» (personaje)');
  }
  final beatIds = <String>{};
  final variantIds = <String>{};
  final addedBefore = <String>{};
  final choicesBefore =
      <String, Choice>{}; // preguntas ya hechas al llegar a la escena
  for (final beat in premise.beats) {
    if (!beatIds.add(beat.id)) {
      problems.add('$pid: escena duplicada "${beat.id}"');
    }
    for (final slot in beat.introduces) {
      if (!slotKinds.containsKey(slot)) {
        problems
            .add('$pid.${beat.id}: presenta una ranura inexistente "$slot"');
      }
    }
    final addedHere = <String>{};
    for (final v in beat.variants) {
      if (!variantIds.add(v.id)) problems.add('variante duplicada: ${v.id}');
      for (final r in v.requires) {
        final fromCast = RegExp(r'^(\w+):').firstMatch(r)?.group(1);
        final asked = fromCast == null ? null : choicesBefore[fromCast];
        if (asked != null) {
          final option = r.substring(fromCast!.length + 1);
          if (asked.optionById(option) == null) {
            problems.add(
              '${v.id}: requiere «$r» pero «$fromCast» no tiene la opción "$option"',
            );
          }
        } else if (fromCast != null) {
          if (!slotKinds.containsKey(fromCast)) {
            problems
                .add('${v.id}: requiere «$r» pero no hay ranura "$fromCast"');
          }
        } else if (!addedBefore.contains(r)) {
          problems.add(
            '${v.id}: requiere «$r» pero ninguna escena anterior lo añade',
          );
        }
      }
      _checkFixedGender(v, problems);
      addedHere.addAll(v.adds);
      final bg = v.scene['bg'];
      if (bg != null && slotKinds[bg] != 'place') {
        problems.add('${v.id}: el fondo «$bg» no es una ranura de lugar');
      }
      for (final e in stageEntries(v.scene)) {
        final who = e.who;
        if (who != null && slotKinds[who] != 'character') {
          problems.add('${v.id}: «$who» no es una ranura de personaje');
        }
        final rig = e.rig;
        if (rig != null && !premise.npcs.containsKey(rig)) {
          problems.add(
            '${v.id}: el secundario «$rig» no está declarado en "npcs" de la premisa',
          );
        }
      }
      if (stageEntries(v.scene).length > maxOnStage) {
        problems.add('${v.id}: más de $maxOnStage personajes en pantalla');
      }
      for (final o in _offstage(v.scene)) {
        if (!slotKinds.containsKey(o) && !premise.npcs.containsKey(o)) {
          problems.add('${v.id}: «$o» en "offstage" no existe');
        }
      }
    }
    addedBefore.addAll(addedHere);
    final asking = beat.choice;
    if (asking != null) {
      _checkChoice(
        pack,
        premise,
        beat,
        asking,
        slotKinds,
        choicesBefore,
        problems,
      );
      choicesBefore[asking.id] = asking;
      for (final o in asking.options) {
        addedBefore
          ..add('${asking.id}:${o.id}')
          ..addAll(o.adds);
      }
    }
  }
  if (premise.beats.any((b) => b.choice != null) &&
      !pack.features.contains('choice@1')) {
    problems.add(
      '$pid: tiene preguntas y el pack no declara "features": ["choice@1"]',
    );
  }
  final choiceIds = {
    for (final b in premise.beats)
      if (b.choice != null) b.choice!.id,
  };
  final usesChoiceTokens =
      RegExp('\\{(${choiceIds.isEmpty ? '(?!)' : choiceIds.join('|')})\\.');

  // --- todos los repartos posibles: cada variante debe renderizar bien con cada uno
  final casts = _allCasts(pack, premise);
  if (casts.isEmpty) {
    problems.add('$pid: ningún reparto cumple los requisitos');
    return renders;
  }
  for (final cast in casts) {
    try {
      renderTemplate(premise.title, cast);
    } on TemplateException catch (e) {
      problems.add('$pid: título: ${e.message}');
    }
    final state = castState(cast, premise);
    for (final beat in premise.beats) {
      for (final v in beat.variants) {
        // Las variantes que exigen otro reparto no se aplican a este.
        final castReqs = v.requires.where(
          (r) => premise.cast.containsKey(r.split(':').first),
        );
        if (!castReqs.every(state.contains)) continue;
        // Las que usan lo que dijo una opción se prueban en cada camino (`_checkChoicePaths`)
        if (usesChoiceTokens.hasMatch(v.text)) continue;
        // Cada forma de cada atributo con varias opciones debe dar un texto correcto.
        final forms = cast.values
            .whereType<Character>()
            .expand((c) => c.attrs.values.map((o) => o.length))
            .fold<int>(1, (a, b) => a > b ? a : b);
        // Y cada alternativa `[[a|b|c]]` del texto se prueba al menos una vez.
        final iterations =
            forms > maxAlternatives(v.text) ? forms : maxAlternatives(v.text);
        for (var k = 0; k < iterations; k++) {
          renders++;
          _checkRender(
            Fragment(
              id: v.id,
              stage: 'opening',
              values: const ['*'],
              requires: v.requires,
              adds: v.adds,
              text: v.text,
              scene: v.scene,
            ),
            cast,
            problems,
            choose: (key, options) => options[k % options.length],
            alt: (n) => k % n,
          );
        }
      }
    }
  }

  if (choiceIds.isNotEmpty) {
    renders += _checkChoicePaths(pack, premise, casts, problems);
  }

  // --- cuentos generados: reglas de hilo
  final engine = StoryEngine(pack);
  final seenOptions = <String>{};
  for (final moral in pack.morals.where((m) => premise.fitsValue(m.id))) {
    for (var seed = 0; seed < seeds * 8; seed++) {
      final Story story;
      try {
        story = engine.generate(StoryOptions(seed: seed, valueId: moral.id));
      } on StoryGenerationException catch (e) {
        problems.add('$pid semilla $seed: ${e.message}');
        break;
      } on TemplateException catch (e) {
        problems.add('$pid semilla $seed: ${e.message}');
        break;
      }
      if (!story.recipe.fragmentIds.first.startsWith('$pid.')) continue;
      seenOptions.addAll(story.choices.map((c) => c.id));
      _checkStory(premise, story, problems);
    }
  }
  for (final b in premise.beats) {
    for (final o in b.choice?.options ?? const <ChoiceOption>[]) {
      if (!seenOptions.contains('$pid.${b.choice!.id}.${o.id}')) {
        problems.add(
          '$pid: la opción «${b.choice!.id}:${o.id}» no salió en ningún cuento de prueba',
        );
      }
    }
  }
  return renders;
}

final RegExp _choiceLabelPunctuation = RegExp(r'[.!?¿¡«»,;:]');

/// Reglas de una pregunta al niño ([Choice]) dentro de su premisa (docs/20 §3.4).
void _checkChoice(
  Pack pack,
  Premise premise,
  Beat beat,
  Choice choice,
  Map<String, String> slotKinds,
  Map<String, Choice> before,
  Set<String> problems,
) {
  final where = '${premise.id}.${beat.id} (pregunta «${choice.id}»)';
  void add(String msg) => problems.add('$where: $msg');

  if (slotKinds.containsKey(choice.id)) {
    add('el id coincide con una ranura del reparto');
  }
  if (before.containsKey(choice.id)) add('el id está repetido');
  final profiles = choice.ages.isEmpty ? Choice.defaultAges : choice.ages;
  for (final a in profiles) {
    if (a == '2-3') add('no se pregunta a los de 2–3 años');
    if (!const ['4-5', '6-8', '9-12'].contains(a)) add('edad «$a» desconocida');
    if (a == '4-5' && choice.options.length > 2) {
      add('a los de 4–5 años se les dan 2 opciones, no ${choice.options.length}');
    }
    if (choice.ages.isNotEmpty && !premise.fitsAge(a)) {
      add('pregunta a $a pero el cuento no es para esa edad');
    }
  }
  if (choice.options.length < 2 || choice.options.length > 3) {
    add('lleva ${choice.options.length} opciones (deben ser 2 o 3)');
  }
  final maxQuestions = profiles.every((a) => a == '9-12') ? 2 : 1;
  final total = premise.beats.where((b) => b.choice != null).length;
  if (total > maxQuestions) {
    add('el cuento tiene $total preguntas (máximo $maxQuestions para su edad)');
  }
  if (choice.ask.length > 120) add('la pregunta pasa de 120 caracteres');
  if ((choice.talk ?? '').length > 100) add('«talk» pasa de 100 caracteres');
  final ids = <String>{};
  final sayKeys = <Set<String>>[];
  for (final o in choice.options) {
    if (!ids.add(o.id)) add('opción repetida «${o.id}»');
    if (o.label.length > 28) add('«${o.label}» pasa de 28 caracteres');
    if (_choiceLabelPunctuation.hasMatch(o.label)) {
      add('«${o.label}» lleva puntuación (se lee tal cual)');
    }
    if (!choiceGlyphs.contains(o.glyph)) {
      add('«${o.label}»: icono «${o.glyph}» fuera de la lista cerrada');
    }
    sayKeys.add(o.says.keys.toSet());
  }
  for (final k in sayKeys) {
    if (k.length != sayKeys.first.length || !k.containsAll(sayKeys.first)) {
      add('las opciones no definen las mismas claves de "says"');
      break;
    }
  }

  // Posición: ni al principio ni al final, y entre el 30 % y el 60 % del texto
  final at = premise.beats.indexOf(beat);
  if (at == 0) add('no puede estar en la primera escena');
  if (at >= premise.beats.length - 3) {
    add('debe quedar al menos tres escenas antes del final (descenso al cierre)');
  }
  double avg(Beat b) =>
      b.variants.fold<int>(0, (n, v) => n + _words(v.text)) / b.variants.length;
  final totalWords = premise.beats.fold<double>(0, (n, b) => n + avg(b));
  var upTo = 0.0;
  for (var i = 0; i <= at; i++) {
    upTo += avg(premise.beats[i]);
  }
  final share = upTo / totalWords;
  if (share < 0.3 || share > 0.6) {
    add('la pregunta cae al ${(share * 100).round()} % del texto (debe estar entre el 30 % y el 60 %)');
  }

  // Equilibrio: las ramas pesan parecido (±20 % de la media)
  final weights = <String, double>{};
  for (final o in choice.options) {
    final tag = '${choice.id}:${o.id}';
    final vs = [
      for (final b in premise.beats)
        for (final v in b.variants)
          if (v.requires.contains(tag)) v,
    ];
    if (vs.isEmpty) {
      add('ninguna variante pide «$tag»: la opción no cambia nada');
      continue;
    }
    weights[o.id] = vs.fold<int>(0, (n, v) => n + _words(v.text)) / vs.length +
        o.says.values.fold<int>(0, (n, t) => n + _words(t));
  }
  if (weights.length > 1) {
    final mean =
        weights.values.fold<double>(0, (a, b) => a + b) / weights.length;
    for (final e in weights.entries) {
      if ((e.value - mean).abs() > mean * 0.2) {
        add('la rama «${e.key}» pesa ${e.value.round()} palabras y la media es ${mean.round()} (±20 %)');
      }
    }
  }
}

/// Todas las rutas de una premisa con preguntas, sin enumerar los cuentos: para cada reparto y cada
/// combinación de opciones se recorre el estado escena a escena (con todas las variantes elegibles) y se
/// comprueba que siempre haya alguna variante y que los textos que usan lo que dijo la opción se rendericen.
int _checkChoicePaths(
  Pack pack,
  Premise premise,
  List<Map<String, Entity>> casts,
  Set<String> problems,
) {
  final pid = premise.id;
  final questions = [
    for (final b in premise.beats)
      if (b.choice != null) b.choice!,
  ];
  var routes = <List<ChoiceOption>>[[]];
  for (final q in questions) {
    routes = [
      for (final r in routes)
        for (final o in q.options) [...r, o],
    ];
  }
  var renders = 0;
  for (final cast in casts) {
    for (final route in routes) {
      final label =
          '${cast.entries.map((e) => '${e.key}=${e.value.id}').join(' ')} · '
          '${route.map((o) => o.id).join('/')}';
      var states = <Set<String>>[castState(cast, premise)];
      final says = <String, String>{};
      var picked = 0;
      for (final beat in premise.beats) {
        final next = <String>{};
        final nextStates = <Set<String>>[];
        for (final state in states) {
          final candidates = beat.variants
              .where((v) => v.weight > 0 && state.containsAll(v.requires))
              .toList();
          if (candidates.isEmpty) {
            problems.add(
              '$pid.${beat.id}: sin variante elegible en la ruta $label (¿falta alguna etiqueta del camino?)',
            );
            continue;
          }
          for (final v in candidates) {
            renders++;
            try {
              final out = renderTemplate(v.text, cast, says: says);
              if (out.contains('{') || out.contains('  ')) {
                problems.add('${v.id}: texto sospechoso en la ruta $label');
              }
            } on TemplateException catch (e) {
              problems.add('${v.id}: ${e.message} (ruta $label)');
            }
            final s = {...state, ...v.adds};
            if (next.add((s.toList()..sort()).join(','))) nextStates.add(s);
          }
        }
        states =
            nextStates.length > 2000 ? nextStates.sublist(0, 2000) : nextStates;
        final q = beat.choice;
        if (q != null) {
          final o = route[picked++];
          for (final s in states) {
            s
              ..add('${q.id}:${o.id}')
              ..addAll(o.adds);
          }
          for (final e in o.says.entries) {
            says['${q.id}.${e.key}'] = renderTemplate(e.value, cast);
          }
        }
        if (states.isEmpty) break;
      }
    }
  }
  return renders;
}

/// Todos los repartos que cumplen los requisitos de la premisa (producto cartesiano sin repetir).
List<Map<String, Entity>> _allCasts(Pack pack, Premise premise) {
  var partial = <Map<String, Entity>>[{}];
  for (final slot in premise.cast.entries) {
    final next = <Map<String, Entity>>[];
    final candidates = castCandidates(pack, slot.value);
    for (final p in partial) {
      for (final c in candidates) {
        if (p.values.any((e) => e.id == c.id)) continue;
        next.add({...p, slot.key: c});
      }
    }
    partial = next;
  }
  return partial;
}

void _checkStory(Premise premise, Story story, Set<String> problems) {
  final pid = premise.id;
  final texts = [for (final s in story.scenes) s.text];
  final who =
      story.recipe.cast.entries.map((e) => '${e.key}=${e.value}').join(' ');
  void add(String msg) => problems.add('$pid [$who]: $msg');

  final total = texts.fold<int>(0, (n, t) => n + _words(t));
  final limits = storyWordLimits(premise);
  if (total < limits.min) {
    add('muy corto: $total palabras (mínimo ${limits.min} para su edad)');
  }
  if (total > limits.max) {
    add('muy largo: $total palabras (máximo ${limits.max} para su edad)');
  }
  _checkAge(premise, texts, add);

  final causal = causalConnectors.allMatches(texts.join(' ')).length;
  if (causal < 3) {
    add('solo $causal conectores causales (mínimo 3): la trama no tiene causas');
  }

  final quotes = RegExp('«[^»]+»').allMatches(texts.join(' ')).length;
  if (quotes < 2) add('solo $quotes citas de diálogo (mínimo 2)');

  // Presencia del héroe
  final hero = story.cast['hero']!;
  final heroName = _name(hero);
  final withHero = texts.where((t) => t.contains(heroName)).length;
  if (withHero / texts.length < minHeroPresence) {
    add('el héroe solo aparece en $withHero de ${texts.length} escenas');
  }
  if (!texts.last.contains(heroName) &&
      !texts.last.contains(RegExp('${hero.noun}\\b'))) {
    add('el cierre no nombra al héroe');
  }

  // Presentaciones: nadie actúa antes de ser presentado, y quien se presenta aparece
  final firstMention = <String, int>{};
  for (final slot in story.cast.keys) {
    final e = story.cast[slot]!;
    if (e is Place) continue;
    final name = _name(e);
    final i = texts.indexWhere((t) => t.contains(name));
    firstMention[slot] = i;
    var mentions = 0;
    for (final t in texts) {
      if (t.contains(name)) mentions++;
    }
    if (mentions < 2) {
      add('«$slot» (${e.id}) solo se nombra en $mentions escena: se presenta y desaparece');
    }
  }
  for (var i = 0; i < premise.beats.length; i++) {
    for (final slot in premise.beats[i].introduces) {
      final at = firstMention[slot];
      if (at == null) continue;
      if (at < i) {
        add('«$slot» se nombra en la escena ${at + 1} antes de presentarse en la ${i + 1}');
      } else if (at > i) {
        add('«$slot» debía presentarse en la escena ${i + 1} pero no se nombra hasta la ${at + 1}');
      }
    }
  }
  // Quien no se presenta explícitamente solo puede ser el héroe
  for (final slot in story.cast.keys) {
    final e = story.cast[slot]!;
    if (slot == 'hero' || e is Place) continue;
    final introduced = premise.beats.any((b) => b.introduces.contains(slot));
    if (!introduced) add('«$slot» (${e.id}) no se presenta en ninguna escena');
  }

  // Texto ↔ ilustración: quien sale dibujado está en el texto y quien el texto cuenta sale dibujado
  for (var i = 0; i < story.scenes.length; i++) {
    _checkStage(premise, story, i, add);
    _checkSetting(premise, story, i, add);
  }

  // Los lugares no cambian sin contar el viaje
  String? previousBg;
  for (var i = 0; i < story.scenes.length; i++) {
    final bg = story.scenes[i].directives['bg'] as String?;
    if (previousBg != null &&
        bg != null &&
        bg != previousBg &&
        !premise.beats[i].moves) {
      add('la escena ${i + 1} cambia de lugar sin contar el viaje (falta moves: true)');
    }
    if (bg != null) previousBg = bg;
  }
}

/// Género fijo en el texto literal de la plantilla: si se refiere al héroe, debe usar `{hero.o}`.
void _checkFixedGender(Variant v, Set<String> problems) {
  for (final m in _fixedGender.allMatches(v.text)) {
    problems.add(
      '${v.id}: género fijo «${m.group(0)}»: si se refiere al héroe usa {hero.o} '
      '(«quiet{hero.o}»); si no, reescribe',
    );
  }
}

/// Máximo de personajes en una ilustración (más no caben sin pisarse).
const int maxOnStage = 6;

/// Un personaje de una ilustración: una ranura del reparto (`who`) o un secundario (`rig`).
class StageEntry {
  const StageEntry({
    this.who,
    this.rig,
    this.clip,
    this.x,
    this.lift,
    this.scale,
    this.rotate,
  });

  final String? who;
  final String? rig;
  final String? clip;

  /// Posición horizontal opcional (0–1 del ancho visible); por defecto se reparten a partes iguales.
  final double? x;

  /// Cuánto se sube sobre el suelo (para pisar un puente o una tarima) y factor de tamaño (más lejos = menor).
  final double? lift;
  final double? scale;

  /// Grados que se gira sobre los pies (−90 = tumbado con la cabeza a la izquierda: dormir en la cama).
  final double? rotate;
}

/// Personajes de una escena, de izquierda a derecha: la lista `stage` o, en packs antiguos, `actors`.
List<StageEntry> stageEntries(Map<String, Object?> scene) {
  final stage = scene['stage'];
  if (stage is List) {
    return [
      for (final e in stage)
        if (e is Map)
          StageEntry(
            who: e['who'] as String?,
            rig: e['rig'] as String?,
            clip: e['clip'] as String?,
            x: (e['x'] as num?)?.toDouble(),
            lift: (e['lift'] as num?)?.toDouble(),
            scale: (e['scale'] as num?)?.toDouble(),
            rotate: (e['rotate'] as num?)?.toDouble(),
          )
        else if (e is String)
          StageEntry(who: e),
    ];
  }
  final actors = scene['actors'];
  return [
    if (actors is List)
      for (final a in actors)
        if (a is String) StageEntry(who: a),
  ];
}

List<String> _offstage(Map<String, Object?> scene) {
  final o = scene['offstage'];
  return o is List ? [for (final x in o) x.toString()] : const [];
}

void _checkStage(
  Premise premise,
  Story story,
  int i,
  void Function(String) add,
) {
  final scene = story.scenes[i];
  final text = scene.text;
  // En un primer plano (`focus`) solo se ve el objeto: nadie sale dibujado ni hace falta decir `offstage`.
  final isFocus = scene.directives['focus'] is Map;
  final entries =
      isFocus ? const <StageEntry>[] : stageEntries(scene.directives);
  final offstage = _offstage(scene.directives);
  final where = 'escena ${i + 1} (${scene.fragmentId})';

  // Personajes del reparto (salvo el héroe, que puede estar sin nombrarse)
  for (final role in story.cast.keys) {
    final e = story.cast[role]!;
    if (e is! Character) {
      continue;
    }
    final named = text.contains(e.given);
    final onStage = entries.any((x) => x.who == role);
    if (onStage && !named && role != 'hero') {
      add('$where: «$role» (${e.given}) sale dibujado pero el texto no lo nombra');
    }
    if (named && !onStage && !isFocus && !offstage.contains(role)) {
      add('$where: el texto nombra a «$role» (${e.given}) pero no sale dibujado (¿offstage?)');
    }
  }
  // Secundarios
  for (final npc in premise.npcs.entries) {
    final named = npc.value.any(text.contains);
    final onStage = entries.any((x) => x.rig == npc.key);
    if (onStage && !named) {
      add('$where: «${npc.key}» sale dibujado pero el texto no lo nombra (${npc.value.join('/')})');
    }
    if (named && !onStage && !isFocus && !offstage.contains(npc.key)) {
      add('$where: el texto nombra a «${npc.key}» pero no sale dibujado (¿offstage?)');
    }
  }
}

// ---------------------------------------------------------------- hora, estación y lugar

/// Qué horas del día admite cada pista del texto. Si el texto trae varias pistas basta con que la hora de
/// la ilustración sea admitida por alguna (una descripción habitual como «por la mañana… por la noche…»).
final List<(RegExp, Set<String>)> _timeCues = [
  (
    RegExp(
      r'\b(?:aquella|esa|esta|la misma|toda la|de|por la) noche\b|medianoche|anocheci|a oscuras',
      caseSensitive: false,
    ),
    {'noche'},
  ),
  // «la Luna» con mayúscula es el nombre del castillo, no la luna del cielo; «Una noche» abre una escena
  // (y «una noche entera» dentro de una frase es una duración)
  (RegExp(r'\bUna noche\b|\bla luna\b|bajo la luna'), {'noche'}),
  (
    RegExp(
      r'amanec|\bal alba\b|antes de que (?:saliera|saliese|salga) el sol|no había salido el sol|madrugada',
      caseSensitive: false,
    ),
    {'amanecer', 'noche'},
  ),
  (
    RegExp(
      r'por la mañana|cada mañana|una mañana|esa mañana|aquella mañana|esta mañana|mediodía',
      caseSensitive: false,
    ),
    {'dia', 'amanecer'},
  ),
  (
    RegExp(
      r'(?:esa|aquella|esta|cada) tarde|todas las tardes|por la tarde',
      caseSensitive: false,
    ),
    {'dia', 'atardecer'},
  ),
  (
    RegExp(
      r'atardec|cielo naranja|al ponerse el sol|puesta de sol|al caer la tarde',
      caseSensitive: false,
    ),
    {'atardecer'},
  ),
];

/// Estación que cuenta cada pista del texto; `verano` = la normal (sin estación) o la primavera.
final List<(RegExp, Set<String>)> _seasonCues = [
  (
    RegExp(
      r'invierno|nevada|nevaba|nevó|nieve|hielo',
      caseSensitive: false,
    ),
    {'invierno'},
  ),
  (RegExp(r'primavera|charcos', caseSensitive: false), {'primavera'}),
  (RegExp(r'verano', caseSensitive: false), {'', 'primavera'}),
  (
    RegExp(
      r'otoño|hojas (?:se pusieron )?doradas|hojas secas',
      caseSensitive: false,
    ),
    {'otono'},
  ),
];

/// Rasgos del lugar que el texto puede nombrar y que el arte debe tener dibujados.
final List<(RegExp, String)> _featureWords = [
  (RegExp(r'\bpozo\b', caseSensitive: false), 'pozo'),
  (RegExp(r'\bventana\b', caseSensitive: false), 'ventana'),
  (RegExp(r'\b(?:cama|almohada)\b', caseSensitive: false), 'cama'),
  (RegExp(r'\b(?:mesa|mesita)\b', caseSensitive: false), 'mesa'),
  (RegExp(r'\bmostrador\b', caseSensitive: false), 'mostrador'),
  (RegExp(r'\bhorno\b', caseSensitive: false), 'horno'),
  (RegExp(r'\bpuente\b', caseSensitive: false), 'puente'),
];

/// Objetos que el texto puede nombrar y el dibujo que los representa (cualquiera de esos objetos basta). Lo que se cuenta
/// tiene que verse: si el texto dice «una mariposa», la escena dibuja la mariposa (o la acerca con `focus`).
final List<(RegExp, String, Set<String>)> _objectWords = [
  (RegExp(r'\bmariposa', caseSensitive: false), 'mariposa', {'mariposa'}),
  (
    RegExp(r'\btaza\b', caseSensitive: false),
    'taza',
    {'taza', 'taza_leche', 'taza_volcada'}
  ),
  (
    RegExp(r'\b(?:panecillo|bollo)s?\b', caseSensitive: false),
    'panecillo',
    {'pan', 'trozos_de_pan'}
  ),
  (
    RegExp(r'\blinterna\b', caseSensitive: false),
    'linterna',
    {'linterna', 'linterna_apagada'}
  ),
  (RegExp(r'\bmanta\b', caseSensitive: false), 'manta', {'manta'}),
  (RegExp(r'\bcuenco\b', caseSensitive: false), 'cuenco', {'cuenco'}),
  (RegExp(r'\bcabrita\b', caseSensitive: false), 'cabrita', {'cabrita'}),
  (RegExp(r'\bpiedras\b', caseSensitive: false), 'piedras', {'piedras'}),
  (
    RegExp(r'\bcampana\b', caseSensitive: false),
    'campana',
    {'campana', 'campana_colgada', 'campana_rota'}
  ),
  (RegExp(r'\bbolsa\b', caseSensitive: false), 'bolsa', {'bolsa'}),
  (RegExp(r'\bcometa\b', caseSensitive: false), 'cometa', {'cometa'}),
  (
    RegExp(r'\bsemillas\b', caseSensitive: false),
    'semillas',
    {'semillas', 'semillas_dos'}
  ),
  (
    RegExp(r'\bgirasol\b', caseSensitive: false),
    'girasol',
    {'girasol', 'girasol_seco'}
  ),
  (RegExp(r'\bhierba de luna\b', caseSensitive: false), 'hierba', {'hierba'}),
  (RegExp(r'\bolla\b', caseSensitive: false), 'olla', {'olla'}),
  (RegExp(r'\bpan\b', caseSensitive: false), 'pan', {'pan', 'trozos_de_pan'}),
];

/// Horas y estaciones (`time`, `season`), rasgos del lugar y primer plano de los objetos nuevos:
/// lo que el texto cuenta es lo que se ve.
void _checkSetting(
  Premise premise,
  Story story,
  int i,
  void Function(String) add,
) {
  final scene = story.scenes[i];
  final d = scene.directives;
  final bg = d['bg'];
  final place = bg is String ? story.cast[bg] : null;
  if (place is! Place) return;
  final text = scene.text;
  final where = 'escena ${i + 1} (${scene.fragmentId})';

  // Las pistas de hora y estación se buscan en la narración: lo que se dice entre «» puede referirse a otro momento
  final narration = text.replaceAll(RegExp('«[^»]*»'), ' ');
  final time = d['time'] as String?;
  final season = d['season'] as String?;
  final times = place.times;
  if (times != null) {
    if (time == null) {
      add('$where: falta «time» (${times.join('/')}) para dibujar ${place.noun} a la hora del texto');
    } else if (!times.contains(time)) {
      add('$where: «time: $time» no existe en «${place.id}» (hay ${times.join('/')})');
    } else {
      final allowed = <String>{};
      final cues = <String>[];
      for (final (re, set) in _timeCues) {
        final m = re.firstMatch(narration);
        if (m != null) {
          allowed.addAll(set);
          cues.add('«${m.group(0)}»');
        }
      }
      if (allowed.isNotEmpty && !allowed.contains(time)) {
        add('$where: el texto dice ${cues.join(', ')} pero se dibuja «time: $time» '
            '(debería ser ${allowed.join(' o ')})');
      }
    }
  }
  if (season != null && !place.seasons.contains(season)) {
    add('$where: «season: $season» no existe en «${place.id}» '
        '(hay ${place.seasons.isEmpty ? 'ninguna' : place.seasons.join('/')})');
  }
  if (times != null) {
    final allowed = <String>{};
    final cues = <String>[];
    for (final (re, set) in _seasonCues) {
      final m = re.firstMatch(narration);
      if (m != null) {
        allowed.addAll(set);
        cues.add('«${m.group(0)}»');
      }
    }
    if (allowed.isNotEmpty && !allowed.contains(season ?? '')) {
      add('$where: el texto dice ${cues.join(', ')} pero se dibuja '
          '«season: ${season ?? 'ninguna'}» (debería ser ${allowed.map((s) => s.isEmpty ? 'ninguna' : s).join(' o ')})');
    }
  }

  final features = place.features;
  if (features != null) {
    // Lo que se ve: los rasgos del lugar y los objetos que la escena dibuja (una mesa larga, una maceta).
    final seen = <String>{
      ...features,
      for (final p in (d['props'] is List ? d['props']! as List : const []))
        if (p is Map) '${p['prop']}',
      if (d['focus'] is Map) '${(d['focus']! as Map)['prop']}',
    };
    // `unseen`: lo que el texto nombra a propósito sin que se vea (algo que se atisba por una rendija).
    final unseen = [
      for (final x in (d['unseen'] is List ? d['unseen']! as List : const []))
        '$x',
    ];
    for (final (re, feature) in _featureWords) {
      final m = re.firstMatch(text);
      if (m != null && !seen.contains(feature) && !unseen.contains(feature)) {
        add('$where: el texto nombra «${m.group(0)}» pero en ${place.noun} no se ve «$feature» '
            '(dibújalo con un objeto, cambia el texto o márcalo «unseen»)');
      }
    }
  }

  // Lo que se cuenta se ve: cada objeto que la narración nombra está dibujado en la escena (o en su primer plano)
  final drawn = <String>{
    for (final p in (d['props'] is List ? d['props']! as List : const []))
      if (p is Map) '${p['prop']}',
    if (d['focus'] is Map) '${(d['focus']! as Map)['prop']}',
    for (final e in stageEntries(d))
      if (e.rig != null) e.rig!,
  };
  final hidden = {
    for (final x in (d['unseen'] is List ? d['unseen']! as List : const []))
      '$x',
  };
  final spoken = text.replaceAll(RegExp('«[^»]*»'), ' ');
  for (final (re, key, rigs) in _objectWords) {
    if (!re.hasMatch(spoken) || hidden.contains(key)) continue;
    if (rigs.any(drawn.contains)) continue;
    add('$where: el texto nombra «$key» pero no se ve en la escena '
        '(dibújalo con un objeto, acércalo con un primer plano o márcalo «unseen»)');
  }

  // Un objeto que se presenta se ve de cerca: primer plano (`focus`) de ese objeto
  final beat = premise.beats[i];
  for (final slot in beat.introduces) {
    final e = story.cast[slot];
    if (e is! Prop) continue;
    final focus = d['focus'];
    if (focus is! Map || focus['prop'] != e.id) {
      add('$where: «$slot» (${e.id}) se presenta aquí y debe verse de cerca (falta «focus» con prop: ${e.id})');
    }
    break; // si se presentan varios objetos a la vez, basta con el primero
  }
}
