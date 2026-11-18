import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

/// Las palabras de España se detectan sueltas, sin confundir palabras de Latinoamérica que las contienen (docs/32).
void main() {
  test('detecta las palabras de España', () {
    for (final s in [
      'Mara cogió la cuerda.',
      '«Cógelo», dijo.',
      'Se puso las gafas.',
      'Comieron tarta.',
      'Pip traía zumo.',
      'Había setas en el bosque.',
      'Se tumbaron en la hierba.',
      '¡Te pillé!',
      'Mañana me la devuelves, ¿vale?',
      '¡Menudo gigante!',
      'del color de la nata',
      'miró hacia delante',
      'No te enfades.',
      'Te eché de menos.',
      'Saltaba a la pata coja.',
      'Giraba como una peonza.',
    ]) {
      expect(spainWords.hasMatch(s), isTrue, reason: s);
    }
  });

  test('no confunde palabras de Latinoamérica', () {
    for (final s in [
      'Fueron a recoger las conchas.',
      'La aldea los acogió.',
      'Junto a la tumba del rey.',
      'Eso vale mucho.',
      'Era un pillo simpático.',
      'Iba nadando con natación.',
      'Comió un pastel con jugo.',
      'Miró hacia adelante.',
      'Se enojó un poco.',
      'Encontró un escondite.',
    ]) {
      expect(spainWords.hasMatch(s), isFalse, reason: s);
    }
  });
}
