import 'dart:convert';
import 'dart:io';

import 'package:caldero_rig/caldero_rig.dart';
import 'package:test/test.dart';

const artDir = '../../art';

Map<String, Object?> readJson(String path) =>
    jsonDecode(File('$artDir/$path').readAsStringSync())
        as Map<String, Object?>;

void main() {
  group('svg_path', () {
    test('comandos básicos y repetición implícita', () {
      final c = parseSvgPath('M1,2 L3,4 5,6 Z');
      expect(c, hasLength(4));
      expect(c[0], isA<MoveTo>());
      expect((c[2] as LineTo).x, 5);
      expect(c[3], isA<ClosePath>());
    });

    test('números negativos pegados a la letra y decimales', () {
      final c = parseSvgPath('M-4,-246.5 Q-1.5,.5 2,3');
      expect((c[0] as MoveTo).x, -4);
      expect((c[0] as MoveTo).y, -246.5);
      final q = c[1] as QuadTo;
      expect([q.cx, q.cy, q.x, q.y], [-1.5, 0.5, 2, 3]);
    });

    test('arcos con banderas', () {
      final a = parseSvgPath('M0,0 A6,6 0 1 0 12,5')[1] as ArcTo;
      expect([a.rx, a.ry, a.rotation, a.x, a.y], [6, 6, 0, 12, 5]);
      expect(a.largeArc, isTrue);
      expect(a.sweep, isFalse);
    });

    test('cúbicas', () {
      final c = parseSvgPath('M0,0 C1,2 3,4 5,6')[1] as CubicTo;
      expect([c.c1x, c.c1y, c.c2x, c.c2y, c.x, c.y], [1, 2, 3, 4, 5, 6]);
    });

    test('rutas inválidas lanzan FormatException', () {
      expect(() => parseSvgPath('M1,2 L3'), throwsFormatException);
      // Los comandos relativos (minúsculas) no se soportan: antes se ignoraban en silencio y
      // dibujaban mal (una ola `q16,-8 …` se leía como un `Q` absoluto cerca del origen).
      for (final d in [
        'M1,2 q3,4 5,6',
        'M1,2 l3,4',
        'M1,2 h5',
        'M1,2 Z m3,4',
      ]) {
        expect(() => parseSvgPath(d), throwsFormatException, reason: d);
      }
      expect(parseSvgPath('M1,2 L1e1,2.5e-1'), hasLength(2));
      expect(() => parseSvgPath('1,2'), throwsFormatException);
    });
  });

  group('color', () {
    test('lectura y mezcla', () {
      expect(parseHexColor('#ff8000'), 0xFFFF8000);
      expect(mixColors(0xFF000000, 0xFFFFFFFF, 0.5), 0xFF808080);
      expect(mixColors(0xFF123456, 0xFF654321, 0), 0xFF123456);
    });
  });

  group('archivos reales del repositorio', () {
    final index = readJson('medieval/index.json');
    final rigPaths = [
      for (final p in index['rigs']! as List<Object?>) p! as String,
    ];

    test('todos los rigs se leen y tienen formas', () {
      expect(rigPaths, isNotEmpty);
      for (final path in rigPaths) {
        final rig = Rig.fromJson(readJson(path));
        expect(rig.type, 'humanoid');
        var shapes = 0;
        void walk(RigNode n) {
          shapes += n.shapes.length;
          for (final s in n.shapes) {
            expect(s.commands, isNotEmpty, reason: '${rig.id}/${n.id}');
          }
          n.pre.forEach(walk);
          n.post.forEach(walk);
        }

        walk(rig.root);
        expect(shapes, greaterThan(30), reason: rig.id);
      }
    });

    test('los colores de cada rig existen en su paleta', () {
      for (final path in rigPaths) {
        final rig = Rig.fromJson(readJson(path));
        void walk(RigNode n) {
          for (final s in n.shapes) {
            for (final c in [s.fill, s.stroke]) {
              if (c != null && c.startsWith(r'$')) {
                expect(
                  rig.palette,
                  contains(c.substring(1)),
                  reason: '${rig.id}: $c',
                );
              }
            }
          }
          n.pre.forEach(walk);
          n.post.forEach(walk);
        }

        walk(rig.root);
      }
    });

    test('el clip de cada actor existe y cada pista apunta a un hueso real',
        () {
      final lib = ClipLibrary.fromJson(readJson(index['clips']! as String));
      final scene = Scene.fromJson(
        readJson((index['scenes']! as List<Object?>).first! as String),
      );
      final rigs = {
        for (final p in rigPaths)
          Rig.fromJson(readJson(p)).id: Rig.fromJson(readJson(p)),
      };
      for (final a in scene.actors) {
        expect(lib.clips, contains(a.clip));
        expect(rigs, contains(a.rig));
      }
      for (final rig in rigs.values) {
        final ids = <String>{};
        void collect(RigNode n) {
          ids.add(n.id);
          n.pre.forEach(collect);
          n.post.forEach(collect);
        }

        collect(rig.root);
        for (final e in lib.clips.entries) {
          for (final track in e.value.tracks.keys) {
            expect(
              ids,
              contains(track.split('.').first),
              reason: '${e.key}/$track en ${rig.id}',
            );
          }
        }
      }
    });

    test('la escena se lee: degradados referenciados existen', () {
      final scene = Scene.fromJson(
        readJson((index['scenes']! as List<Object?>).first! as String),
      );
      expect(scene.layers.map((l) => l.id), ['sky', 'far', 'mid', 'near']);
      void walk(RigNode n) {
        for (final s in n.shapes) {
          final f = s.fill;
          if (f != null && f.startsWith('@')) {
            expect(scene.gradients, contains(f.substring(1)));
          }
        }
        n.pre.forEach(walk);
        n.post.forEach(walk);
      }

      scene.layers.forEach(walk);
    });
  });

  group('animación', () {
    test('sampleKeys: interpolación suave, límites y bucle', () {
      final keys = [
        [0.0, 0.0],
        [1.0, 10.0],
      ];
      expect(sampleKeys(keys, 0, 1, true, 'smooth'), 0);
      expect(sampleKeys(keys, 0.5, 1, true, 'smooth'), closeTo(5, 1e-9));
      expect(sampleKeys(keys, 0.5, 1, true, 'linear'), closeTo(5, 1e-9));
      expect(sampleKeys(keys, 0.25, 1, true, 'linear'), closeTo(2.5, 1e-9));
      expect(
        sampleKeys(keys, 0.25, 1, true, 'smooth'),
        lessThan(2.5),
      ); // arranque suave
      expect(
        sampleKeys(keys, 1.5, 1, true, 'linear'),
        closeTo(5, 1e-9),
      ); // bucle
      expect(
        sampleKeys(keys, 9, 1, false, 'linear'),
        10,
      ); // sin bucle: se queda al final
    });

    test('las pistas aditivas se suman al reposo y las absolutas no', () {
      final rig = Rig.fromJson(readJson('medieval/rigs/aldo.json'));
      final clip = Clip.fromJson({
        'dur': 1.0,
        'tracks': {
          'armR': [
            [0.0, 10.0],
            [1.0, 10.0],
          ],
          'eyes.sy': [
            [0.0, 0.5],
            [1.0, 0.5],
          ],
        },
      });
      final p = samplePose(rig, clip, 0.3);
      expect(p['armR'], rig.rest['armR']! + 10);
      expect(p['eyes.sy'], 0.5);
      // el arma sigue erguida: se compensa el ángulo total del brazo
      expect(p['itemR'], closeTo(-p['armR']! + rig.itemTilt, 1e-9));
    });

    test('paridad con Python: poses de 4 personajes × 10 clips × 7 instantes',
        () {
      final fx = readJson('fixtures/animation_samples.json');
      final lib = ClipLibrary.fromJson(readJson('clips/humanoid.json'));
      final rigs = <String, Rig>{};
      var checked = 0;
      for (final item in fx['poses']! as List<Object?>) {
        final m = item! as Map<String, Object?>;
        final rig = rigs.putIfAbsent(
          m['rig']! as String,
          () => Rig.fromJson(readJson('medieval/rigs/${m['rig']}.json')),
        );
        final got =
            samplePose(rig, lib.clips[m['clip']]!, (m['t']! as num).toDouble());
        final want = (m['pose']! as Map<String, Object?>)
            .map((k, v) => MapEntry(k, (v! as num).toDouble()));
        expect(
          got.keys.toSet(),
          want.keys.toSet(),
          reason: '${m['rig']}/${m['clip']}@${m['t']}',
        );
        for (final k in want.keys) {
          expect(
            got[k],
            closeTo(want[k]!, 1e-5),
            reason: '${m['rig']}/${m['clip']}@${m['t']} $k',
          );
        }
        checked++;
      }
      expect(checked, greaterThan(200));
    });

    test('paridad con Python: animaciones ambientales de la escena', () {
      final fx = readJson('fixtures/animation_samples.json');
      final scene =
          Scene.fromJson(readJson('medieval/scenes/castle_night.json'));
      final byId = <String, RigNode>{};
      void walk(RigNode n) {
        byId[n.id] = n;
        n.pre.forEach(walk);
        n.post.forEach(walk);
      }

      scene.layers.forEach(walk);
      var checked = 0;
      for (final item in fx['ambient']! as List<Object?>) {
        final m = item! as Map<String, Object?>;
        final anim =
            byId[m['node']]!.anims.firstWhere((a) => a.prop == m['prop']);
        expect(
          sampleAmbient(anim, (m['t']! as num).toDouble()),
          closeTo((m['value']! as num).toDouble(), 1e-5),
          reason: '${m['node']}@${m['t']}',
        );
        checked++;
      }
      expect(checked, greaterThan(20));
    });

    test('formatos inválidos se rechazan con mensaje', () {
      expect(
        () => Rig.fromJson({'format': 'otra-cosa'}),
        throwsA(isA<ArtFormatException>()),
      );
      expect(
        () => Scene.fromJson({'format': 'caldero-scene', 'version': 2}),
        throwsA(isA<ArtFormatException>()),
      );
      expect(
        () => Clip.fromJson({
          'dur': 1,
          'tracks': {'x': []},
        }),
        throwsA(isA<ArtFormatException>()),
      );
    });
  });
}
