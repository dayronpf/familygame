/// El nombre del niño que protagoniza el cuento: se limpia antes de usarlo en el texto y en la voz.
library;

/// Longitud máxima de un nombre (los nombres compuestos largos caben; evita pegar frases enteras).
const int maxChildNameLength = 16;

final RegExp _notName = RegExp(r"[^\p{L}\s'’-]", unicode: true);

/// Limpia [raw]: quita lo que no son letras (cifras, emojis, signos), junta espacios, pone cada palabra en mayúscula
/// inicial y corta a [maxChildNameLength]. Devuelve `null` si no queda nada.
String? normalizeChildName(String? raw) {
  if (raw == null) return null;
  var t = raw.replaceAll(_notName, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (t.isEmpty) return null;
  if (t.length > maxChildNameLength) {
    t = t.substring(0, maxChildNameLength).trimRight();
  }
  String cap(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
  // «ana-luz» → «Ana-Luz»; «d'arcy» → «D'arcy»
  final words = [
    for (final w in t.split(' '))
      if (w.isNotEmpty) w.split('-').map(cap).join('-'),
  ];
  final out = words.join(' ').replaceAll(RegExp(r"^[-'’]+|[-'’]+$"), '');
  return out.isEmpty ? null : out;
}
