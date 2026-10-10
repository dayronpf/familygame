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
    this.maxSentenceWords = 20,
  });

  /// Abreviatura con su punto («Sr.») → palabra («señor»).
  final Map<String, String> abbreviations;

  /// Palabra (minúsculas, ya sin letras repetidas) → cómo se dice. Onomatopeyas aprobadas y nombres propios.
  final Map<String, String> pronunciation;

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

/// Pasa [text] a lo que debe decir la voz. Reglas, en este orden:
/// 1. quita emojis y símbolos que no se pronuncian;
/// 2. reduce cualquier letra repetida 3 o más veces a una sola («fiuuu» → «fiu»);
/// 3. quita las comillas «» y “” (y arregla el signo que quedaba pegado: `!».` → `!`);
/// 4. pasa números y abreviaturas a palabras;
/// 5. baja las mayúsculas de énfasis («¡NO!» → «¡No!»);
/// 6. aplica el diccionario de pronunciación;
/// 7. deja un solo punto en vez de los suspensivos;
/// 8. parte con un punto las frases de más de [VoiceRules.maxSentenceWords] palabras.
String normalizeForVoice(String text, {VoiceRules rules = spanishVoiceRules}) {
  var t = text;
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
