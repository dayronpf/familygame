/// Texto para la voz (`texto_voz`): lo que se manda al motor de voz, distinto de lo que se lee en pantalla
/// (`texto_pantalla`). El motor de voz del teléfono lee mal las letras alargadas («Fiuuu»), las comillas «»,
/// los símbolos, las cifras y las mayúsculas de énfasis, así que antes de narrar se pasa cada frase por
/// [normalizeForVoice] (reglas de `docs/18-voz-edades-y-wizard.md`, por idioma; aquí, español).
library;

/// Ajustes del normalizador de un idioma: diccionarios de abreviaturas y de pronunciación.
class VoiceRules {
  const VoiceRules({
    this.abbreviations = _esAbbreviations,
    this.pronunciation = _esPronunciation,
    this.soundEffects = _esSoundEffects,
    this.maxSentenceWords = 20,
  });

  /// Abreviatura con su punto («Sr.») → palabra («señor»).
  final Map<String, String> abbreviations;

  /// Palabra (minúsculas, ya sin letras repetidas) → cómo se dice. Onomatopeyas aprobadas y nombres propios.
  final Map<String, String> pronunciation;

  /// Efectos de sonido («¡Cric!», «¡Beee!», «¡Plaf!»): palabra en minúsculas y ya sin letras alargadas → id del
  /// sonido (`creak`, `bleat`, `splash`…). **La voz no los dice**: un motor de voz no sabe imitar sonidos y los lee
  /// como palabras raras («bi», «cric»). La app los reproduce como sonido (`speechParts`) y se ven en pantalla.
  final Map<String, String> soundEffects;

  /// Una frase más larga se parte en dos con un punto (solo para la voz; en pantalla queda igual).
  final int maxSentenceWords;
}

const Map<String, String> _esAbbreviations = {
  'Sr.': 'señor',
  'Sra.': 'señora',
  'Srta.': 'señorita',
  'Dr.': 'doctor',
  'Dra.': 'doctora',
  'etc.': 'etcétera',
  'pág.': 'página',
  'vs.': 'versus',
  'aprox.': 'aproximadamente',
};

/// Onomatopeyas del pack, ya sin letras alargadas (paso 2), y cómo las dice bien la voz. Todo lo que no esté
/// aquí se deja como llega: la regla del proyecto es **describir el sonido en vez de imitarlo** (docs/18).
const Map<String, String> _esPronunciation = {
  'sh': 'chis', // «Shhh» pidiendo silencio
  'gr': 'gruñ', // «Grrr», la barriga que ruge
  'fu': 'fu', // «Fuuu»
  'be': 'bee', // la cabrita («Beee»)
  'uh': 'uuh',
  'pst': 'psst',
  'rum': 'rum', // «Rummm»
  'chis': 'chis',
};

/// Efectos de sonido del pack: forma sin letras alargadas («¡Fuuush!» → `fush`) → sonido (`assets/audio/sfx/<id>.ogg`).
/// Las interjecciones de un personaje («¡Ay!», «¡Uf!», «¡Ja!») no están aquí: son palabras que sí se dicen.
const Map<String, String> _esSoundEffects = {
  'be': 'bleat', //
  'cric': 'creak',
  'fu': 'wind', 'fiu': 'wind', 'fush': 'wind', 'suish': 'wind',
  'fr': 'flutter',
  'tilín': 'coins',
  'sh': 'hiss', 'chis': 'hiss', 'pst': 'hiss',
  'clang': 'clang', 'clong': 'clang',
  'cling': 'clink', 'clinc': 'clink',
  'clic': 'click',
  'din': 'bell', 'don': 'bell',
  'gr': 'growl', 'rum': 'growl',
  'plaf': 'splash',
  'plof': 'plop', 'flup': 'plop', 'pof': 'plop',
  'plin': 'drop',
  'crac': 'crack', 'cras': 'crack',
  'hop': 'hop',
  'pum': 'thump',
  'uh': 'hoot',
};

const VoiceRules spanishVoiceRules = VoiceRules();

final RegExp _emoji = RegExp(
  '[\u{1F000}-\u{1FAFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]',
  unicode: true,
);
final RegExp _symbols = RegExp(r'[★☆♪♫♥♡•·@#*_=+<>~^|\\/]');
final RegExp _quotes = RegExp('[«»“”„‟"]');
final RegExp _repeated =
    RegExp(r'(\p{L})\1{2,}', unicode: true, caseSensitive: false);
final RegExp _allCaps =
    RegExp(r'(?<![\p{L}\p{N}])[\p{Lu}]{2,}(?![\p{L}\p{N}])', unicode: true);
final RegExp _digits = RegExp(r'\d+(?:[.,]\d+)?');

/// Un efecto de sonido entre signos de exclamación, con sus comillas si las lleva: `¡Cric!`, `«¡Beee!»`,
/// `¡Cric, cric!`.
final RegExp _effectSegment = RegExp('[«“"]?¡([^!¡«»]*)!»?[”"]?');

/// Marca donde había un efecto de sonido (se limpia al final del paso 0).
const String _gap = '\u0001';

/// Quita los efectos de sonido de [t] y deja la frase bien puntuada (paso 0 de [normalizeForVoice]).
String _dropSoundEffects(String t, VoiceRules rules) {
  var removed = false;
  var out = t.replaceAllMapped(_effectSegment, (m) {
    final words = RegExp(r'\p{L}+', unicode: true)
        .allMatches(m.group(1)!)
        .map(
          (w) => w
              .group(0)!
              .toLowerCase()
              .replaceAllMapped(_repeated, (r) => r.group(1)!),
        )
        .toList();
    if (words.isEmpty || !words.every(rules.soundEffects.containsKey)) {
      return m.group(0)!;
    }
    removed = true;
    return _gap;
  });
  if (!removed) return t;
  out = out
      // «una ráfaga: ¡fuuu! La lucecita…» → «una ráfaga. La lucecita…»
      .replaceAll(
        RegExp('\\s*:\\s*$_gap\\s*(?=[«“"¡¿]*\\p{Lu}|\$)', unicode: true),
        '. ',
      )
      .replaceAll(RegExp('\\s*:\\s*$_gap'), '')
      .replaceAll(RegExp('\\s*$_gap\\s*(?=[,;])'), '')
      .replaceAll(_gap, ' ');
  out = out
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m.group(1)!)
      .replaceAll(RegExp(r',\s*,'), ',')
      .replaceAllMapped(RegExp(r'([.!?])\s*[,;]'), (m) => m.group(1)!)
      .replaceAll(RegExp(r'\.\s*\.'), '.')
      .trim();
  // Si el efecto abría la frase («¡Beee!», dijo la cabrita), lo que queda empieza en minúscula (y tras una coma).
  final lead = RegExp(r'^[,;]\s*').firstMatch(out);
  if (lead != null) out = out.substring(lead.end);
  final opened = RegExp('^[«“"¡]').hasMatch(t.trimLeft());
  if ((lead != null || opened) && out.isNotEmpty) {
    out = out[0].toUpperCase() + out.substring(1);
  }
  return out;
}

/// Un trozo de lo que se narra: texto para la voz o un efecto de sonido.
sealed class SpeechPart {
  const SpeechPart();
}

class SpokenText extends SpeechPart {
  const SpokenText(this.text);

  /// Ya normalizado para la voz.
  final String text;

  @override
  String toString() => 'SpokenText($text)';
}

class SoundEffect extends SpeechPart {
  const SoundEffect(this.sound);

  /// Id del sonido (`creak`, `bleat`…), ver [VoiceRules.soundEffects].
  final String sound;

  @override
  String toString() => 'SoundEffect($sound)';
}

/// Parte la frase en lo que dice la voz y los efectos de sonido, **en orden**: «El viento la levantó, ¡fiuuu!, y
/// subió.» → [«El viento la levantó,», sonido `wind`, «y subió.»]. La app dice cada trozo y reproduce cada sonido
/// entre medias. Los trozos de texto salen ya normalizados ([normalizeForVoice]).
List<SpeechPart> speechParts(
  String text, {
  VoiceRules rules = spanishVoiceRules,
}) {
  final parts = <SpeechPart>[];
  var last = 0;
  void spoken(String raw) {
    var t = raw.replaceFirst(RegExp(r'^[\s,;:]+'), '');
    t = t.replaceFirst(RegExp('[\\s«“"]+\$'), '');
    if (t.endsWith(':')) t = '${t.substring(0, t.length - 1)}.';
    final v = normalizeForVoice(t, rules: rules);
    if (RegExp(r'\p{L}', unicode: true).hasMatch(v)) parts.add(SpokenText(v));
  }

  for (final m in _effectSegment.allMatches(text)) {
    final words = RegExp(r'\p{L}+', unicode: true)
        .allMatches(m.group(1)!)
        .map(
          (w) => w
              .group(0)!
              .toLowerCase()
              .replaceAllMapped(_repeated, (r) => r.group(1)!),
        )
        .toList();
    if (words.isEmpty || !words.every(rules.soundEffects.containsKey)) continue;
    spoken(text.substring(last, m.start));
    parts.add(SoundEffect(rules.soundEffects[words.first]!));
    last = m.end;
  }
  spoken(text.substring(last));
  return parts;
}

/// Pasa [text] a lo que debe decir la voz. Reglas, en este orden:
/// 0. quita los efectos de sonido entre signos de exclamación («¡Cric!», «¡Beee!»: la voz no los imita; el texto
///    debe seguir teniendo sentido sin ellos, lo comprueba [voiceIssues]);
/// 1. quita emojis y símbolos que no se pronuncian;
/// 2. reduce cualquier letra repetida 3 o más veces a una sola («fiuuu» → «fiu»);
/// 3. quita las comillas «» y “” (y arregla el signo que quedaba pegado: `!».` → `!`);
/// 4. pasa números y abreviaturas a palabras;
/// 5. baja las mayúsculas de énfasis («¡NO!» → «¡No!»);
/// 6. aplica el diccionario de pronunciación;
/// 7. deja un solo punto en vez de los suspensivos;
/// 8. parte con un punto las frases de más de [VoiceRules.maxSentenceWords] palabras.
String normalizeForVoice(String text, {VoiceRules rules = spanishVoiceRules}) {
  // 0
  var t = _dropSoundEffects(text, rules);
  // 1
  t = t.replaceAll(_emoji, ' ');
  t = t.replaceAll('&', ' y ').replaceAll('%', ' por ciento ');
  t = t.replaceAll(_symbols, ' ');
  // abreviaturas antes de tocar los puntos
  rules.abbreviations.forEach((abbr, word) {
    t = t.replaceAllMapped(
      RegExp('(?<![\\p{L}])${RegExp.escape(abbr)}', unicode: true),
      (m) => word,
    );
  });
  // 5 (antes de quitar letras repetidas: «NOOO» → «Noo» → «No»)
  t = t.replaceAllMapped(_allCaps, (m) {
    final w = m.group(0)!;
    return w[0] + w.substring(1).toLowerCase();
  });
  // 2
  t = t.replaceAllMapped(_repeated, (m) => m.group(1)!);
  // 6 (palabra completa, sin importar mayúsculas; conserva la inicial en mayúscula)
  t = t.replaceAllMapped(RegExp(r'\p{L}+', unicode: true), (m) {
    final w = m.group(0)!;
    final spoken = rules.pronunciation[w.toLowerCase()];
    if (spoken == null) return w;
    final cap = w[0] != w[0].toLowerCase();
    return cap ? spoken[0].toUpperCase() + spoken.substring(1) : spoken;
  });
  // 3
  t = t.replaceAll(_quotes, '');
  t = t.replaceAllMapped(RegExp(r'([!?])\s*[.,;:]'), (m) => m.group(1)!);
  // 4
  t = t.replaceAllMapped(_digits, (m) => _numberToWords(m.group(0)!));
  // 7
  t = t.replaceAll(
    RegExp(r'(?:\.{2,}|…+)\s*(?=[\p{Ll}])', unicode: true),
    ', ',
  );
  t = t.replaceAll(RegExp(r'\.{2,}|…+'), '.');
  t = t.replaceAll(RegExp(r'\.\s*\.'), '.');
  t = t.replaceAll(RegExp(r',\s*,'), ',');
  t = t.replaceAll(RegExp(r',\s*\.'), '.');
  // espacios
  t = t
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAllMapped(RegExp(r'\s+([,.;:!?])'), (m) => m.group(1)!)
      .trim();
  // 8
  t = _splitLong(t, rules.maxSentenceWords);
  return t;
}

int _wordCount(String s) =>
    s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// Parte las frases largas por la coma más cercana a la mitad (si deja al menos 6 palabras a cada lado).
String _splitLong(String text, int maxWords) {
  final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
  final out = <String>[];
  for (final s in sentences) {
    out.addAll(_splitSentence(s, maxWords));
  }
  return out.join(' ');
}

List<String> _splitSentence(String s, int maxWords) {
  if (_wordCount(s) <= maxWords) return [s];
  final commas = <int>[
    for (var i = 0; i < s.length; i++)
      if (s[i] == ',') i,
  ];
  int? best;
  var bestGap = 1 << 30;
  final mid = s.length ~/ 2;
  for (final c in commas) {
    final left = s.substring(0, c);
    final right = s.substring(c + 1);
    if (_wordCount(left) < 6 || _wordCount(right) < 6) continue;
    final gap = (c - mid).abs();
    if (gap < bestGap) {
      bestGap = gap;
      best = c;
    }
  }
  if (best == null) return [s];
  final left = '${s.substring(0, best)}.';
  var right = s.substring(best + 1).trim();
  if (right.isNotEmpty) right = right[0].toUpperCase() + right.substring(1);
  return [
    ..._splitSentence(left, maxWords),
    ..._splitSentence(right, maxWords),
  ];
}

/// Problemas que aún tiene un `texto_voz` (vacío = limpio). Es la prueba de aceptación del normalizador.
List<String> voiceIssues(String voiceText, {int maxSentenceWords = 20}) {
  final issues = <String>[];
  if (_repeated.hasMatch(voiceText)) {
    issues.add('letras repetidas 3 o más veces');
  }
  if (RegExp('[«»“”„‟"]').hasMatch(voiceText)) issues.add('comillas');
  if (RegExp(r'\d').hasMatch(voiceText)) issues.add('cifras');
  if (_emoji.hasMatch(voiceText) ||
      _symbols.hasMatch(voiceText) ||
      RegExp('[&%]').hasMatch(voiceText)) {
    issues.add('símbolos o emojis');
  }
  if (_allCaps.hasMatch(voiceText)) issues.add('mayúsculas de énfasis');
  if (RegExp(r'\.{2,}|…').hasMatch(voiceText)) issues.add('puntos suspensivos');
  // Un efecto de sonido que se quitó y dejó la frase cortada («El agua hacía.», «cayó con un,», «estaba el.»)
  if (RegExp(
    r'(?:^|[\s,;])(?:(?:hacía|hacían|hizo|hicieron|haciendo|con un|con una|el)\s*(?:[,;.!?]|$))',
    caseSensitive: false,
  ).hasMatch(voiceText)) {
    issues.add('frase cortada (¿un efecto de sonido sin verbo?)');
  }
  if (RegExp(r'[!?][.,;:]').hasMatch(voiceText)) {
    issues.add('signo pegado a otro signo');
  }
  if (RegExp(r'\b(?:Sr|Sra|Srta|Dr|Dra|etc|pág|vs|aprox)\.')
      .hasMatch(voiceText)) {
    issues.add('abreviaturas');
  }
  for (final s in voiceText.split(RegExp(r'(?<=[.!?])\s+'))) {
    if (_wordCount(s) > maxSentenceWords) {
      issues.add('frase de más de $maxSentenceWords palabras');
      break;
    }
  }
  return issues;
}

// ---------------------------------------------------------------- números
const _units = [
  'cero',
  'uno',
  'dos',
  'tres',
  'cuatro',
  'cinco',
  'seis',
  'siete',
  'ocho',
  'nueve',
  'diez',
  'once',
  'doce',
  'trece',
  'catorce',
  'quince',
  'dieciséis',
  'diecisiete',
  'dieciocho',
  'diecinueve',
  'veinte',
  'veintiuno',
  'veintidós',
  'veintitrés',
  'veinticuatro',
  'veinticinco',
  'veintiséis',
  'veintisiete',
  'veintiocho',
  'veintinueve',
];
const _tens = [
  '',
  '',
  '',
  'treinta',
  'cuarenta',
  'cincuenta',
  'sesenta',
  'setenta',
  'ochenta',
  'noventa',
];
const _hundreds = [
  '',
  'ciento',
  'doscientos',
  'trescientos',
  'cuatrocientos',
  'quinientos',
  'seiscientos',
  'setecientos',
  'ochocientos',
  'novecientos',
];

String _below1000(int n) {
  if (n == 100) return 'cien';
  if (n < 30) return _units[n];
  if (n < 100) {
    final u = n % 10;
    return u == 0 ? _tens[n ~/ 10] : '${_tens[n ~/ 10]} y ${_units[u]}';
  }
  final rest = n % 100;
  return rest == 0
      ? _hundreds[n ~/ 100]
      : '${_hundreds[n ~/ 100]} ${_below1000(rest)}';
}

/// «3» → «tres»; «1250» → «mil doscientos cincuenta»; «3,5» → «tres coma cinco». Hasta 999 999.
String _numberToWords(String digits) {
  if (digits.contains(RegExp(r'[.,]'))) {
    final parts = digits.split(RegExp(r'[.,]'));
    // «1.250» con tres cifras tras el punto es un millar escrito a la española
    if (parts.length == 2 && parts[1].length == 3 && digits.contains('.')) {
      return _numberToWords(parts.join());
    }
    return '${_numberToWords(parts[0])} coma ${parts[1].split('').map((d) => _units[int.parse(d)]).join(' ')}';
  }
  final n = int.tryParse(digits);
  if (n == null || n > 999999) {
    return digits.split('').map((d) => _units[int.parse(d)]).join(' ');
  }
  if (n < 1000) return _below1000(n);
  final thousands = n ~/ 1000;
  final rest = n % 1000;
  final head = thousands == 1 ? 'mil' : '${_below1000(thousands)} mil';
  return rest == 0 ? head : '$head ${_below1000(rest)}';
}
