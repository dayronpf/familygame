import 'dart:convert';
import 'dart:io';

import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter_test/flutter_test.dart';

/// Arte de la Aldea de las Nubes (docs/27): lo genera `tools/art/cosmos_kit.py` en `art/cosmos/`.
void main() {
  final dir = Directory('../art/cosmos/rigs');
  Set<String> bones(Map<String, Object?> node) => {
        node['id']! as String,
        for (final c in [...node['pre']! as List, ...node['post']! as List])
          ...bones(c as Map<String, Object?>),
      };
  Map<String, Object?> raw(String id) =>
      jsonDecode(File('${dir.path}/$id.json').readAsStringSync())
          as Map<String, Object?>;

  test(
      'los personajes, sus variantes y Chispa se leen con el formato de la app',
      () {
    const cast = [
      'orion', 'lira', 'aurora', 'tornillo', 'osa', 'brillo', 'zumbo', //
      'pip', 'nube', 'panadero', 'cartera',
    ];
    for (final id in cast) {
      for (final v in [id, '${id}_miedo']) {
        Rig.fromJson(raw(v));
      }
    }
    for (final id in ['orion_pijama', 'lira_pijama', 'chispa']) {
      Rig.fromJson(raw(id));
    }
    // El robot y el alien conservan el esqueleto humano: les sirven todos los gestos
    const humanoid = {
      'root', 'torso', 'head', 'eyes', 'browL', 'browR', 'mouth', 'jaw', //
      'armL', 'foreArmL', 'armR', 'foreArmR', 'legL', 'legR',
    };
    for (final id in cast) {
      expect(bones(raw(id)['root']! as Map<String, Object?>),
          containsAll(humanoid),
          reason: id);
    }
    expect(
        bones(raw('chispa')['root']! as Map<String, Object?>),
        containsAll(
            {'head', 'eyes', 'tail', 'legFN', 'legBN', 'legFF', 'legBF'}));
  });

  test('todos los trazos se leen con el lector de la app', () {
    void walk(Object? node, String where) {
      if (node is Map) {
        final d = node['d'];
        if (d is String) {
          expect(() => parseSvgPath(d), returnsNormally, reason: '$where: $d');
        }
        for (final v in node.values) {
          walk(v, where);
        }
      } else if (node is List) {
        for (final v in node) {
          walk(v, where);
        }
      }
    }

    for (final f in dir.listSync().whereType<File>()) {
      walk(jsonDecode(f.readAsStringSync()), f.path);
    }
  });
}
