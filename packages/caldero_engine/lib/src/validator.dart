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
  });

  final String? who;
  final String? rig;
  final String? clip;

  /// Posición horizontal opcional (0–1 del ancho visible); por defecto se reparten a partes iguales.
  final double? x;

  /// Cuánto se sube sobre el suelo (para pisar un puente o una tarima) y factor de tamaño (más lejos = menor).
  final double? lift;
  final double? scale;
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
