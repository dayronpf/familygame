import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:caldero_rig/caldero_rig.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

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

  test('todos los trazos de dibujos y fondos se leen con el lector de la app',
      () {
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

    for (final sub in ['rigs', 'scenes']) {
      for (final f
          in Directory('../art/mar/$sub').listSync().whereType<File>()) {
        walk(jsonDecode(f.readAsStringSync()), f.path);
      }
    }
  });

  group('fondos, objetos y gestos (fase 4)', () {
    late StageArt art;
    late Pack mar;
    setUpAll(() async {
      art = StageArt(await loadArtLibrary(FileBundle(), pack: 'mar'));
      mar = Pack.fromJson(pack);
    });

    test('cada lugar tiene su fondo y cada hora del pack, su luz', () {
      for (final p in mar.places) {
        final place = art.library.places[p.id];
        expect(place, isNotNull, reason: 'sin fondo para ${p.id}');
        expect(art.sceneFor(p.id), isNotNull, reason: p.id);
        for (final t in p.times ?? const <String>[]) {
          expect(place!.looks, contains(t), reason: '${p.id}: sin «$t»');
          expect(art.sceneFor(p.id, time: t), isNotNull);
        }
      }
    });

    test('cada objeto del pack tiene dibujo y los gestos del mar existen', () {
      for (final p in mar.props) {
        expect(art.rigs, contains(p.id), reason: 'sin dibujo para ${p.id}');
      }
      for (final c in ['row', 'spyglass', 'steer', 'swim']) {
        expect(art.library.clips.clips, contains(c));
      }
      expect(art.library.propClips, contains('bob'));
    });

    test('cada cuento del pack dibuja todas sus escenas, con niño y con niña',
        () {
      for (final premise in mar.premises) {
        // Un pack con solo ese cuento: así se prueban todos, no los que toque el azar
        final solo = Pack.fromJson({
          ...pack,
          'premises': [
            for (final q in pack['premises']! as List)
              if ((q as Map)['id'] == premise.id) q,
          ],
        });
        final engine = StoryEngine(solo);
        for (final g in ['m', 'f']) {
          for (var seed = 1; seed <= 6; seed++) {
            final story =
                engine.generate(StoryOptions(seed: seed, heroGender: g));
            for (final s in story.scenes) {
              final setup = stageFor(art, story.cast, s.directives);
              expect(setup, isNotNull, reason: '${s.fragmentId} ($g, $seed)');
              if (s.directives['focus'] is! Map) {
                expect(setup!.actors.length, stageEntries(s.directives).length,
                    reason: '${s.fragmentId} ($g, $seed)');
              }
            }
          }
        }
      }
    });
  });
}
