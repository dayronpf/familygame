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
const int minStoryWords = 300;
const int maxStoryWords = 650;

/// Mínimo de escenas en las que debe aparecer el nombre del héroe.
const double minHeroPresence = 0.7;

/// Conectores que enlazan causa y efecto; sin ellos la trama es una lista de sucesos.
final RegExp causalConnectors = RegExp(
  r'\bporque\b|\bpor eso\b|\bpor lo tanto\b|\bya que\b|\bpor eso mismo\b|\basí que\b|\bpara que\b|\bpues\b|\bpor culpa\b|\bgracias a\b|\bde modo que\b|\bcomo\b[^.?!»]{3,40},',
  caseSensitive: false,
);

/// Adjetivos y participios con género que suelen referirse al héroe. En una plantilla se escriben con
/// `{hero.o}` («quiet{hero.o}»); si aparecen literales, con una heroína (o un héroe) salen mal.
final RegExp _fixedGender = RegExp(
  r'\b(?:quiet|dormid|tranquil|liger|helad|cansad|asustad|sorprendid|content|preocupad|confundid)(?:o|a)\b'
  r'|\b(?:yo|entró|siguió|quedó|iba|estaba|fue|llegó|subió)\s+sol(?:o|a)\b',
);

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

  // --- estructura estática
  final slotKinds = {for (final e in premise.cast.entries) e.key: e.value.kind};
  if (slotKinds['hero'] != 'character') {
    problems.add('$pid: falta la ranura «hero» (personaje)');
  }
  final beatIds = <String>{};
  final variantIds = <String>{};
  final addedBefore = <String>{};
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
        if (fromCast != null) {
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
      final actors = v.scene['actors'];
      if (actors is List) {
        for (final a in actors) {
          if (slotKinds[a] != 'character') {
            problems
                .add('${v.id}: el actor «$a» no es una ranura de personaje');
          }
        }
      }
    }
    addedBefore.addAll(addedHere);
  }

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
        final castReqs = v.requires.where((r) => r.contains(':'));
        if (!castReqs.every(state.contains)) continue;
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
        );
      }
    }
  }

  // --- cuentos generados: reglas de hilo
  final engine = StoryEngine(pack);
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
      _checkStory(premise, story, problems);
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
  if (total < minStoryWords) {
    add('muy corto: $total palabras (mínimo $minStoryWords)');
  }
  if (total > maxStoryWords) {
    add('muy largo: $total palabras (máximo $maxStoryWords)');
  }

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
