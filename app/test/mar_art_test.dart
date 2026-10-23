import 'dart:convert';
import 'dart:io';

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arte del Mar de las Estrellas (docs/26, fase 3): lo genera `tools/art/mar_kit.py` en `art/mar/`.
void main() {
  final dir = Directory('../art/mar/rigs');
  Map<String, Object?> raw(String id) =>
      jsonDecode(File('${dir.path}/$id.json').readAsStringSync())
          as Map<String, Object?>;

  Set<String> bones(Map<String, Object?> node) => {
        node['id']! as String,
        for (final c in [...node['pre']! as List, ...node['post']! as List])
          ...bones(c as Map<String, Object?>),
      };

  final pack =
      jsonDecode(File('../content/packs/mar/pack.json').readAsStringSync())
          as Map<String, Object?>;
  final cast = [
    for (final c in pack['characters']! as List)
      (c as Map<String, Object?>)['id']! as String,
  ];

  test(
      'cada personaje del pack tiene dibujo, con miedo y (los protagonistas) en pijama',
      () {
    for (final id in cast) {
      expect(File('${dir.path}/$id.json').existsSync(), isTrue, reason: id);
      expect(File('${dir.path}/${id}_miedo.json').existsSync(), isTrue,
          reason: '${id}_miedo');
    }
    for (final id in ['bruno', 'vega']) {
      expect(File('${dir.path}/${id}_pijama.json').existsSync(), isTrue);
    }
  });

  test('todos se leen y usan solo colores de su paleta', () {
    final files = dir.listSync().whereType<File>().toList();
    expect(files.length, greaterThanOrEqualTo(30));
    for (final f in files) {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, Object?>;
      Rig.fromJson(j); // el formato que lee la app
      final palette = (j['palette']! as Map).keys.toSet();
      void walk(Map<String, Object?> node) {
        for (final s in node['shapes']! as List) {
          for (final k in ['fill', 'stroke']) {
            final v = (s as Map)[k];
            if (v is String && v.startsWith(r'$')) {
              expect(palette, contains(v.substring(1)),
                  reason: '${f.path}: ${node['id']} usa $v');
            }
          }
        }
        for (final c in [...node['pre']! as List, ...node['post']! as List]) {
          walk(c as Map<String, Object?>);
        }
      }

      walk(j['root']! as Map<String, Object?>);
    }
  });

  test('los gestos encuentran sus huesos (también la sirena y el pulpo)', () {
    const humanoid = {
      'root', 'torso', 'head', 'eyes', 'browL', 'browR', 'mouth', 'jaw', //
      'armL', 'foreArmL', 'armR', 'foreArmR', 'legL', 'legR',
    };
    for (final id in [...cast, 'cazo', 'ola', 'nino_puerto', 'nina_puerto']) {
      expect(bones(raw(id)['root']! as Map<String, Object?>),
          containsAll(humanoid),
          reason: id);
    }
    // El loro usa los gestos del búho y el aleteo; la tortuga, los de la cabrita
    expect(bones(raw('loro')['root']! as Map<String, Object?>),
        containsAll({'root', 'eyes', 'wingL', 'wingR'}));
    expect(
        bones(raw('tortuga')['root']! as Map<String, Object?>),
        containsAll({
          'root',
          'head',
          'eyes',
          'tail',
          'legFN',
          'legBN',
          'legFF',
          'legBF'
        }));
  });
}
