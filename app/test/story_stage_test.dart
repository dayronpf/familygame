import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
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
      };

  group('el pack y el arte van de la mano', () {
    test('todo personaje del pack tiene su dibujo', () {
      for (final c in pack.characters) {
        expect(art.rigs, contains(c.id), reason: 'sin rig para ${c.id}');
      }
    });

    test('todo lugar del pack tiene escena y se puede compilar', () {
      for (final p in pack.places) {
        expect(art.library.places, contains(p.id),
            reason: 'sin arte para el lugar ${p.id}');
        expect(art.sceneFor(p.id), isNotNull, reason: p.id);
        final place = art.library.places[p.id]!;
        final scene = art.library.scenes[place.scene]!;
        expect(
            Rect.fromLTWH(0, 0, scene.width, scene.height)
                .contains(place.view.topLeft),
            isTrue);
        expect(place.view.right, lessThanOrEqualTo(scene.width));
        expect(place.view.bottom, lessThanOrEqualTo(scene.height));
        expect(place.floor, inInclusiveRange(place.view.top, place.view.bottom),
            reason: 'los pies de ${p.id} quedan fuera de la vista');
      }
    });

    test('todo ánimo, rol y fondo usados por las escenas tienen su dibujo', () {
      final clips = art.library.clips.clips;
      for (final premise in pack.premises) {
        final places = {
          for (final e in premise.cast.entries)
            if (e.value.kind == 'place') e.key: e.value,
        };
        for (final beat in premise.beats) {
          for (final v in beat.variants) {
            final mood = v.scene['mood'];
            expect(moodClips, contains(mood), reason: '${v.id}: ánimo "$mood"');
            expect(places, contains(v.scene['bg']), reason: '${v.id}: fondo');
            for (final role
                in (v.scene['actors'] as List<Object?>? ?? const [])) {
              expect(roleOrder, contains(role), reason: '${v.id}: rol "$role"');
            }
          }
        }
        // Todo lugar que la premisa puede usar tiene escena.
        for (final spec in places.values) {
          for (final id in castCandidates(pack, spec).map((e) => e.id)) {
            expect(art.library.places, contains(id),
                reason: '${premise.id}: $id');
          }
        }
      }
      for (final e in moodClips.entries) {
        for (final clip in e.value.values) {
          expect(clips, contains(clip), reason: '${e.key} usa el clip "$clip"');
        }
      }
    });

    test('cada escena declara fondo y personajes', () {
      for (final premise in pack.premises) {
        for (final beat in premise.beats) {
          for (final v in beat.variants) {
            expect(v.scene['bg'], isNotNull, reason: v.id);
            expect(v.scene['actors'], isNotEmpty, reason: v.id);
          }
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
          expect(setup!.actors, isNotEmpty);
        }
      }
    });
  });

  group('stageFor', () {
    test('coloca héroe, ayudante y villano de izquierda a derecha', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'actors': ['villain', 'hero', 'helper'],
        'mood': 'calm'
      })!;
      expect(s.placeId, 'bosque');
      expect(s.actors, hasLength(3));
      final xs = s.actors.map((a) => a.x).toList();
      expect(xs, [...xs]..sort(),
          reason: 'el orden no depende del orden de la lista');
      expect(s.actors.first.rig.rig.id, 'aldo');
      expect(s.actors.last.rig.rig.id, 'codicio');
    });

    test('«place2» usa el segundo lugar', () {
      final s = stageFor(art, cast(), {
        'bg': 'place2',
        'actors': ['hero'],
        'mood': 'calm'
      })!;
      expect(s.placeId, 'rio');
      expect(s.actors.single.x,
          closeTo(s.place.view.left + s.place.view.width / 2, 0.01));
    });

    test('el ánimo elige la animación de cada rol', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'actors': ['hero', 'villain'],
        'mood': 'triumph'
      })!;
      final clips = art.library.clips.clips;
      expect(s.actors[0].clip, same(clips['cheer']));
      expect(s.actors[1].clip, same(clips['scared']));
    });

    test('un ánimo desconocido se trata como tranquilo', () {
      final s = stageFor(art, cast(), {
        'bg': 'place',
        'actors': ['hero'],
        'mood': 'rareza'
      })!;
      expect(s.actors.single.clip, same(art.library.clips.clips['idle']));
    });

    test('sin arte para el lugar no falla: devuelve null', () {
      final broken = <String, Entity>{
        ...cast(),
        'place': const Place(
            id: 'luna', noun: 'luna', gender: Gender.f, mood: 'calm'),
      };
      expect(
          stageFor(art, broken, {
            'bg': 'place',
            'actors': ['hero'],
            'mood': 'calm'
          }),
          isNull);
    });

    test('un rol sin dibujo simplemente no aparece', () {
      final c = cast();
      c['helper'] = const Character(
          id: 'fantasma',
          noun: 'fantasma',
          gender: Gender.m,
          given: 'Casper',
          roles: ['helper'],
          alignment: 'positive',
          trait: {'m': 'x', 'f': 'x'});
      final s = stageFor(art, c, {
        'bg': 'place',
        'actors': ['hero', 'helper'],
        'mood': 'calm'
      })!;
      expect(s.actors, hasLength(1));
    });
  });
}
