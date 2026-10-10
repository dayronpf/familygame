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
            // Los animales y objetos como secundarios usan clips de objetos (goat_baa…).
            expect(art.clip(e.clip), isNotNull,
                reason: 'clip «${e.clip}» (personaje u objeto)');
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

    test(
        'cada escena declara fondo y al menos un personaje (o un primer plano)',
        () {
      for (final scene in allScenes()) {
        expect(scene['bg'], isNotNull, reason: '$scene');
        if (scene['focus'] is Map) {
          expect(art.rigs, contains((scene['focus']! as Map)['prop']));
        } else {
          expect(stageEntries(scene), isNotEmpty, reason: '$scene');
        }
      }
    });

    test('toda hora y estación que usa el pack tiene su escena dibujada', () {
      for (final p in pack.places) {
        final times = p.times;
        if (times == null) continue;
        final art0 = art.library.places[p.id]!;
        for (final t in times) {
          expect(art0.looks, contains(t), reason: '${p.id}: sin escena «$t»');
          for (final se in p.seasons) {
            expect(art0.looks, contains('${t}__$se'),
                reason: '${p.id}: sin escena «$t» en «$se»');
          }
        }
      }
      // Y todo cuento posible pide solo luces que existen
      final engine = StoryEngine(pack);
      for (var seed = 1; seed <= 150; seed++) {
        final story = engine.generate(StoryOptions(seed: seed));
        for (final sc in story.scenes) {
          final bg = sc.directives['bg'];
          final place = bg is String ? story.cast[bg] : null;
          if (place is! Place || place.times == null) continue;
          final time = sc.directives['time'] as String?;
          final season = sc.directives['season'] as String?;
          expect(time, isNotNull, reason: 'seed $seed ${sc.fragmentId}');
          final key = season == null ? time! : '${time}__$season';
          expect(art.library.places[place.id]!.looks, contains(key),
              reason:
                  'seed $seed ${sc.fragmentId}: «${place.id}» no tiene «$key»');
        }
      }
    });

    test('cualquier cuento posible dibuja todas sus escenas', () {
      final engine = StoryEngine(pack);
      for (var seed = 1; seed <= 150; seed++) {
        final story = engine.generate(StoryOptions(seed: seed));
        for (final s in story.scenes) {
          final setup = stageFor(art, story.cast, s.directives);
          expect(setup, isNotNull, reason: 'seed $seed ${s.fragmentId}');
          if (s.directives['focus'] is Map) {
            // Primer plano: solo el objeto, y el recuadro cabe en la escena.
            expect(setup!.focus, isTrue);
            expect(setup.actors, isEmpty);
            expect(setup.props, isNotEmpty);
            expect(
                setup.view.left, greaterThanOrEqualTo(setup.place.view.left));
            expect(setup.view.right,
                lessThanOrEqualTo(setup.place.view.right + 0.01));
            expect(setup.view.top, greaterThanOrEqualTo(setup.place.view.top));
            expect(setup.view.bottom,
                lessThanOrEqualTo(setup.place.view.bottom + 0.01));
            continue;
          }
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
      expect(lia.rig.rig.id, 'lia_miedo',
          reason: 'triste: lleva su cara de pena');
      expect(lia.clip, same(art.library.clips.clips['sad']));
      expect(lia.scale, lessThan(hero.scale),
          reason: 'los niños son más pequeños');
      expect(s.actors[2].rig.rig.id, 'teo',
          reason: 'en reposo, su cara normal');
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

  group('hora, estación y primer plano', () {
    test('«time» y «season» eligen la escena del lugar', () {
      Map<String, Object?> d(String? time, [String? season]) => {
            'bg': 'plaza',
            'stage': [
              {'who': 'hero'},
            ],
            'mood': 'calm',
            if (time != null) 'time': time,
            if (season != null) 'season': season,
          };
      final ids = {
        for (final k in [
          ['noche', null],
          ['dia', null],
          ['dia', 'invierno'],
          ['dia', 'otono'],
          [null, null],
        ])
          '${k[0]}/${k[1]}':
              stageFor(art, cast(), d(k[0], k[1]))!.scene.scene.id,
      };
      expect(ids['noche/null'], 'aldea__noche');
      expect(ids['dia/null'], 'aldea__dia');
      expect(ids['dia/invierno'], 'aldea__dia__invierno');
      expect(ids['dia/otono'], 'aldea__dia__otono');
      // Sin hora, el fondo base del lugar
      expect(ids['null/null'], art.library.places['aldea']!.scene);
      expect(ids.values.toSet(), hasLength(5));
    });

    test(
        'una combinación que no existe cae en la hora sola, y luego en la base',
        () {
      final place = art.library.places['aldea']!;
      expect(place.sceneId(time: 'dia', season: 'verano'), 'aldea__dia');
      expect(place.sceneId(time: 'madrugada'), place.scene);
    });

    test('en invierno el suelo es nieve y de día el cielo no tiene estrellas',
        () {
      final inv = art.library.scenes['aldea__dia__invierno']!;
      final dia = art.library.scenes['aldea__dia']!;
      expect(inv.layers.any((l) => l.id == 'snow'), isTrue,
          reason: 'copos de nieve');
      expect(dia.layers.any((l) => l.id == 'snow'), isFalse);
      final stars =
          dia.layers.first.post.where((n) => n.id.startsWith('st')).length;
      expect(stars, 0);
    });

    test(
        '«focus» da un primer plano: solo el objeto, centrado y dentro de la escena',
        () {
      final setup = stageFor(art, cast(), {
        'bg': 'plaza',
        'time': 'dia',
        'mood': 'hope',
        'stage': [
          {'who': 'hero'},
        ],
        'focus': {'prop': 'semillas', 'x': 0.5, 'fill': 0.5},
      })!;
      expect(setup.focus, isTrue);
      expect(setup.actors, isEmpty, reason: 'sin personajes');
      expect(setup.props.single.rig.rig.id, 'semillas');
      final place = setup.place;
      expect(setup.view.width, lessThan(place.view.width / 2),
          reason: 'está acercado');
      expect(setup.view.width / setup.view.height,
          closeTo(place.view.width / place.view.height, 0.01));
      expect(place.view.contains(setup.view.topLeft), isTrue);
      expect(setup.view.right, lessThanOrEqualTo(place.view.right + 0.01));
      expect(setup.view.bottom, lessThanOrEqualTo(place.view.bottom + 0.01));
      final c = setup.props.single;
      expect(setup.view.contains(Offset(c.x, c.y - 10)), isTrue,
          reason: 'el objeto cae dentro del encuadre');
    });

    test('un «focus» con un objeto que no existe se ignora (se ve la escena)',
        () {
      final setup = stageFor(art, cast(), {
        'bg': 'plaza',
        'time': 'dia',
        'mood': 'calm',
        'stage': [
          {'who': 'hero'},
        ],
        'focus': {'prop': 'no_existe'},
      })!;
      expect(setup.focus, isFalse);
      expect(setup.actors, hasLength(1));
    });

    test(
        '«lift» y «scale» suben a un personaje (a pisar un puente) y lo alejan',
        () {
      final normal = stageFor(art, cast(), {
        'bg': 'place2',
        'stage': [
          {'who': 'hero'},
        ],
        'mood': 'calm',
      })!;
      final enPuente = stageFor(art, cast(), {
        'bg': 'place2',
        'stage': [
          {'who': 'hero', 'lift': 80, 'scale': 0.85},
        ],
        'mood': 'calm',
      })!;
      expect(enPuente.actors.single.y, normal.actors.single.y - 80);
      expect(enPuente.actors.single.scale,
          closeTo(normal.actors.single.scale * 0.85, 1e-9));
    });
  });

  group('la acción se ve: tumbados, objetos en la mano y cuerdas', () {
    Map<String, Object?> base(Map<String, Object?> extra) => {
          'bg': 'plaza',
          'time': 'dia',
          'mood': 'calm',
          ...extra,
        };

    test('«rotate» tumba al personaje, sin sombra y sin llegar caminando', () {
      final setup = stageFor(
        art,
        cast(),
        base({
          'stage': [
            {'who': 'hero', 'clip': 'sleep', 'rotate': -90, 'lift': 150},
            {'who': 'helper'},
          ],
        }),
      )!;
      expect(setup.actors.first.rotation, -90);
      expect(setup.actors.last.rotation, 0);
      final entering = withEntrance(setup, art, 0);
      expect(entering.first.enterFrom, 0,
          reason: 'quien duerme ya está en la cama');
      expect(entering.last.enterFrom, isNot(0));
    });

    test('«near» pone el objeto junto al personaje, a la altura de su mano',
        () {
      final setup = stageFor(
        art,
        cast(),
        base({
          'stage': [
            {'who': 'hero', 'x': 0.3},
            {'who': 'helper', 'x': 0.7},
          ],
          'props': [
            {'prop': 'vela', 'near': 'helper', 'dx': -0.05, 'lift': 60},
          ],
        }),
      )!;
      final helper = setup.actors.last;
      final vela = setup.props.single;
      expect(vela.x, closeTo(helper.x - 0.05 * setup.view.width, 0.01));
      expect(vela.y, helper.y - 60);
      expect(vela.front, isTrue, reason: 'se ve delante del personaje');
    });

    test('«rope» une a dos personajes y puede salir de cuadro', () {
      final two = stageFor(
        art,
        cast(),
        base({
          'stage': [
            {'who': 'hero', 'x': 0.3},
            {'who': 'helper', 'x': 0.7},
          ],
          'rope': {'from': 'hero', 'to': 'helper'},
        }),
      )!;
      expect(two.ropes, hasLength(1));
      expect(two.ropes.single.a.dx, closeTo(two.actors.first.x, 0.01));
      expect(two.ropes.single.b.dx, closeTo(two.actors.last.x, 0.01));
      final out = stageFor(
        art,
        cast(),
        base({
          'stage': [
            {'who': 'hero', 'x': 0.5},
          ],
          'rope': {'from': 'hero', 'to': 'left'},
        }),
      )!;
      expect(out.ropes.single.b.dx, lessThan(out.view.left));
    });

    test('los gestos nuevos existen y se pueden dibujar', () {
      for (final clip in [
        'shiver',
        'hug',
        'sit',
        'sit_sad',
        'climb',
        'hide',
      ]) {
        expect(art.clip(clip), isNotNull, reason: clip);
      }
    });
  });

  group('caras y pijama', () {
    test(
        'el miedo, la tristeza y el sigilo usan la variante con miedo; dormir, el pijama',
        () {
      String rigOf(String clip, {String who = 'hero'}) =>
          stageFor(art, cast(), {
            'bg': 'place',
            'mood': 'calm',
            'stage': [
              {'who': who, 'clip': clip},
            ],
          })!
              .actors
              .single
              .rig
              .rig
              .id;
      expect(rigOf('shiver'), 'aldo_miedo');
      expect(rigOf('sneak'), 'aldo_miedo');
      expect(rigOf('sleep'), 'aldo_pijama');
      expect(rigOf('idle'), 'aldo');
      // quien no tiene variante (los objetos, o personajes sin ella) conserva su dibujo
      expect(art.rigs.containsKey('aldo_pijama'), isTrue);
    });

    test('con miedo, Aldo ya no esgrime la espada (le taparía la cara)', () {
      final base = art.library.rigs['aldo']!;
      final fear = art.library.rigs['aldo_miedo']!;
      expect(fear.itemUpright, isFalse);
      expect(base.itemUpright, isTrue);
    });
  });
}
