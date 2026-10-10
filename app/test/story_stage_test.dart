import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/scene_painter.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

void main() {
  late StageArt art;
  late Pack pack;

  setUpAll(() async {
    art = StageArt(await loadArtLibrary(FileBundle()));
    pack = Pack.fromJson(
      jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );
  });

  Map<String, Entity> cast({
    String hero = 'aldo',
    String helper = 'zafiro',
    String villain = 'codicio',
    String place = 'bosque',
    String place2 = 'rio',
  }) =>
      {
        'hero': pack.characters.firstWhere((c) => c.id == hero),
        'helper': pack.characters.firstWhere((c) => c.id == helper),
        'villain': pack.characters.firstWhere((c) => c.id == villain),
        'place': pack.places.firstWhere((p) => p.id == place),
        'place2': pack.places.firstWhere((p) => p.id == place2),
        'bosque': pack.places.firstWhere((p) => p.id == 'bosque'),
        'plaza': pack.places.firstWhere((p) => p.id == 'aldea'),
      };

  Iterable<Map<String, Object?>> allScenes() => [
        for (final p in pack.premises)
          for (final b in p.beats)
            for (final v in b.variants) v.scene,
      ];

  group('el pack y el arte van de la mano', () {
    test('todo personaje y todo secundario del pack tienen su dibujo', () {
      for (final c in pack.characters) {
        expect(art.rigs, contains(c.id), reason: 'sin rig para ${c.id}');
      }
      for (final p in pack.premises) {
        for (final rig in p.npcs.keys) {
          expect(art.rigs, contains(rig), reason: '${p.id}: sin rig «$rig»');
        }
      }
    });

    test('todo lugar del pack tiene escena y se puede compilar', () {
      for (final p in pack.places) {
        expect(art.library.places, contains(p.id),
            reason: 'sin arte para el lugar ${p.id}');
        expect(art.sceneFor(p.id), isNotNull, reason: p.id);
        final place = art.library.places[p.id]!;
        final scene = art.library.scenes[place.scene]!;
        expect(place.view.right, lessThanOrEqualTo(scene.width));
        expect(place.view.bottom, lessThanOrEqualTo(scene.height));
        expect(place.floor, inInclusiveRange(place.view.top, place.view.bottom),
            reason: 'los pies de ${p.id} quedan fuera de la vista');
      }
    });

    test('todo ánimo, clip, objeto y luz que usan las escenas existen', () {
      for (final scene in allScenes()) {
        expect(moodClips, contains(scene['mood']), reason: '$scene');
        final light = scene['light'];
        if (light != null) {
          expect(lightTints, contains(light), reason: 'luz «$light»');
        }
        for (final e in stageEntries(scene)) {
          if (e.clip != null) {
            expect(art.library.clips.clips, contains(e.clip),
                reason: 'clip de personaje «${e.clip}»');
          }
          if (e.x != null) {
            expect(e.x, inInclusiveRange(0.05, 0.95));
          }
        }
        for (final p in (scene['props'] as List<Object?>? ?? const [])) {
          final m = p! as Map<String, Object?>;
          expect(art.rigs, contains(m['prop']),
              reason: 'objeto «${m['prop']}»');
          expect(art.library.propClips, contains(m['clip'] ?? 'still'),
              reason: 'clip de objeto «${m['clip']}»');
        }
      }
      for (final e in moodClips.entries) {
        for (final clip in e.value.values) {
          expect(art.library.clips.clips, contains(clip),
              reason: '${e.key} usa el clip "$clip"');
        }
      }
    });

    test('cada escena declara fondo y al menos un personaje', () {
      for (final scene in allScenes()) {
        expect(scene['bg'], isNotNull, reason: '$scene');
        expect(stageEntries(scene), isNotEmpty, reason: '$scene');
      }
    });

    test('cualquier cuento posible dibuja todas sus escenas', () {
      final engine = StoryEngine(pack);
      for (var seed = 1; seed <= 150; seed++) {
        final story = engine.generate(StoryOptions(seed: seed));
        for (final s in story.scenes) {
          final setup = stageFor(art, story.cast, s.directives);
          expect(setup, isNotNull, reason: 'seed $seed ${s.fragmentId}');
          expect(setup!.actors, isNotEmpty);
          // Todo lo que dibuja la escena es lo que declara (nadie se pierde en el camino).
          expect(setup.actors.length, stageEntries(s.directives).length,
              reason: 'seed $seed ${s.fragmentId}');
        }
      }
    });
  });

  group('stageFor', () {
    test('respeta el orden de izquierda a derecha y reparte a partes iguales',
        () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'villain'},
          {'who': 'hero'},
          {'who': 'helper'},
        ],
        'mood': 'calm',
      })!;
      expect(s.placeId, 'bosque');
      expect(s.actors.map((a) => a.rig.rig.id), ['codicio', 'aldo', 'zafiro']);
      final xs = s.actors.map((a) => a.x).toList();
      expect(xs, [...xs]..sort());
      expect(xs[1], closeTo(s.place.view.left + s.place.view.width / 2, 0.01));
    });

    test('las escenas antiguas (`actors`) siguen funcionando', () {
      final s = stageFor(art, cast(), {
        'bg': 'place2',
        'actors': ['hero', 'villain'],
        'mood': 'calm'
      })!;
      expect(s.placeId, 'rio');
      expect(s.actors, hasLength(2));
    });

    test('una posición `x` fija a ese personaje', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'},
          {'who': 'villain', 'x': 0.9},
        ],
        'mood': 'calm',
      })!;
      expect(s.actors.last.x,
          closeTo(s.place.view.left + s.place.view.width * 0.9, 0.01));
    });

    test('los secundarios salen con su dibujo, su tamaño y su gesto', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'rig': 'lia', 'clip': 'sad'},
          {'who': 'hero'},
          {'rig': 'teo'},
        ],
        'mood': 'calm',
      })!;
      final lia = s.actors[0];
      final hero = s.actors[1];
      expect(lia.rig.rig.id, 'lia');
      expect(lia.clip, same(art.library.clips.clips['sad']));
      expect(lia.scale, lessThan(hero.scale),
          reason: 'los niños son más pequeños');
      expect(s.actors[2].clip, same(art.library.clips.clips['idle']),
          reason: 'sin clip, el de su ánimo (calma → reposo)');
    });

    test('el ánimo elige la animación de cada rol y el clip explícito la anula',
        () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'},
          {'who': 'villain'},
          {'who': 'helper', 'clip': 'think'},
        ],
        'mood': 'triumph',
      })!;
      final clips = art.library.clips.clips;
      expect(s.actors[0].clip, same(clips['cheer']));
      expect(s.actors[1].clip, same(clips['scared']));
      expect(s.actors[2].clip, same(clips['think']));
    });

    test('los objetos se colocan, animan y pueden emitir luz', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'},
        ],
        'mood': 'calm',
        'light': 'night',
        'props': [
          {'prop': 'olla', 'x': 0.5, 'clip': 'boil', 'front': true},
          {
            'prop': 'linterna',
            'x': 0.8,
            'clip': 'glow',
            'lift': 90,
            'emit': true
          },
        ],
      })!;
      expect(s.props, hasLength(2));
      expect(s.props[0].clip, same(art.library.propClips['boil']));
      expect(s.props[0].front, isTrue);
      expect(s.props[0].shadow, isTrue, reason: 'apoyada en el suelo');
      expect(s.props[1].emissive, isTrue);
      expect(s.props[1].shadow, isFalse, reason: 'colgada: sin sombra');
      expect(s.props[1].y, lessThan(s.props[0].y));
      expect(s.tint, lightTints['night']);
    });

    test('con pocos personajes crecen un poco; con muchos se escalonan', () {
      Map<String, Object?> scene(int n) => {
            'bg': 'place',
            'mood': 'calm',
            'stage': [
              {'who': 'hero'},
              for (var i = 1; i < n; i++) {'rig': 'tomas'},
            ],
          };
      final one = stageFor(art, cast(), scene(1))!.actors.single.scale;
      final six = stageFor(art, cast(), scene(6))!.actors;
      expect(one, greaterThan(six.first.scale));
      expect(six[1].y, lessThan(six[0].y), reason: 'los impares, atrás');
      expect(six[1].scale, lessThan(six[2].scale));
    });

    test('un rig desconocido simplemente no aparece', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'},
          {'rig': 'fantasma'},
        ],
        'mood': 'calm',
      })!;
      expect(s.actors, hasLength(1));
    });

    test(
        'un ánimo desconocido se trata como tranquilo; sin lugar con arte, null',
        () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'}
        ],
        'mood': 'rareza'
      })!;
      expect(s.actors.single.clip, same(art.library.clips.clips['idle']));
      final broken = <String, Entity>{
        ...cast(),
        'place': const Place(
            id: 'luna', noun: 'luna', gender: Gender.f, mood: 'calm'),
      };
      expect(
          stageFor(art, broken, {
            'bg': 'place',
            'stage': [
              {'who': 'hero'}
            ]
          }),
          isNull);
    });
  });

  group('StoryStage', () {
    testWidgets('los personajes llegan caminando y se quedan en su sitio',
        (tester) async {
      final setup = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'},
          {'who': 'villain'},
        ],
        'mood': 'calm',
        'props': [
          {'prop': 'linterna', 'clip': 'glow', 'emit': true, 'lift': 90},
        ],
        'light': 'dusk',
      })!;
      final clock = ValueNotifier<double>(0);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StoryStage(setup: setup, clock: clock, art: art),
        ),
      ));
      final entering = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byType(StoryStage), matching: find.byType(CustomPaint)))
          .painter! as ScenePainter;
      expect(entering.actors.every((a) => a.enterFrom != 0), isTrue);
      expect(entering.actors.first.enterFrom, lessThan(0),
          reason: 'el de la izquierda entra por la izquierda');
      expect(entering.actors.last.enterFrom, greaterThan(0));
      expect(entering.camera, isTrue);
      // Avanza el reloj hasta mucho después de la entrada: pinta sin errores.
      for (final t in [0.4, 0.9, 1.6, 4.0]) {
        clock.value = t;
        await tester.pump();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'sin animación, todo está ya en su sitio y la cámara no se mueve',
        (tester) async {
      final setup = stageFor(art, cast(), {
        'bg': 'place',
        'stage': [
          {'who': 'hero'},
        ],
        'mood': 'calm',
      })!;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StoryStage(
              setup: setup,
              clock: ValueNotifier<double>(0),
              art: art,
              animate: false),
        ),
      ));
      final painter = tester
          .widget<CustomPaint>(find.descendant(
              of: find.byType(StoryStage), matching: find.byType(CustomPaint)))
          .painter! as ScenePainter;
      expect(painter.actors.single.enterFrom, 0);
      expect(painter.camera, isFalse);
    });
  });
}
