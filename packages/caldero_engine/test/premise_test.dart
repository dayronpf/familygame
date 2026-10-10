// Datos de prueba muy anidados: el formateador no añade las comas finales que pide el lint.
// ignore_for_file: require_trailing_commas

import 'dart:convert';
import 'dart:io';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:test/test.dart';

/// Una premisa mínima y válida (salvo la longitud, que exige 300 palabras) para modificar en cada prueba.
Map<String, Object?> basePack({
  List<Map<String, Object?>>? beats,
  Map<String, Object?>? cast,
  List<Map<String, Object?>>? characters,
}) {
  Map<String, Object?> v(String text, [Map<String, Object?>? scene]) => {
        'id': 'a',
        'text': text,
        'scene': scene ??
            {
              'bg': 'casa',
              'actors': ['hero'],
              'mood': 'calm'
            },
      };
  return {
    'pack': {
      'schema': 2,
      'id': 't',
      'name': 'T',
      'version': '1.0.0',
      'language': 'es',
    },
    'characters': characters ??
        <Map<String, Object?>>[
          {
            'id': 'ana',
            'given': 'Ana',
            'noun': 'niña',
            'gender': 'f',
            'roles': ['hero'],
            'alignment': 'positive',
            'trait': {'m': 'listo', 'f': 'lista'},
          },
          {
            'id': 'beto',
            'given': 'Beto',
            'noun': 'mago',
            'gender': 'm',
            'roles': ['helper'],
            'alignment': 'positive',
            'trait': {'m': 'sabio', 'f': 'sabia'},
            'tags': ['wise'],
            'attrs': {'gesto': 'se rascó la barba'},
          },
          {
            'id': 'coco',
            'given': 'Coco',
            'noun': 'duque',
            'gender': 'm',
            'roles': ['villain'],
            'alignment': 'negative',
            'trait': {'m': 'avaro', 'f': 'avara'},
            'tags': ['greedy'],
          },
        ],
    'places': [
      {'id': 'casa', 'noun': 'casa', 'gender': 'f', 'mood': 'calm'},
      {'id': 'bosque', 'noun': 'bosque', 'gender': 'm', 'mood': 'calm'},
    ],
    'props': [
      {'id': 'farol', 'noun': 'farol', 'gender': 'm'},
    ],
    'morals': [
      {'id': 'm1', 'name': 'Moral', 'text': 'Texto.'},
    ],
    'premises': [
      {
        'id': 'p',
        'value': 'm1',
        'title': 'El {item.noun}',
        'cast': cast ??
            {
              'hero': {
                'kind': 'character',
                'roles': ['hero']
              },
              'helper': {
                'kind': 'character',
                'roles': ['helper']
              },
              'villain': {
                'kind': 'character',
                'roles': ['villain']
              },
              'casa': {
                'kind': 'place',
                'ids': ['casa']
              },
              'bosque': {
                'kind': 'place',
                'ids': ['bosque']
              },
              'item': {'kind': 'prop'},
            },
        'beats': beats ??
            [
              {
                'id': 'b1',
                'introduces': ['item'],
                'variants': [v('{hero} tenía {item.un} en {casa.el}.')],
              },
              {
                'id': 'b2',
                'introduces': ['helper'],
                'variants': [
                  v('{hero} llamó {helper.al} {helper}, porque {item.el} se apagó.')
                ],
              },
              {
                'id': 'b3',
                'introduces': ['villain'],
                'variants': [
                  v('{villain.El} {villain} {helper.gesto}. «Hola», dijo.')
                ],
              },
            ],
      },
    ],
  };
}

Pack load(Map<String, Object?> json) => Pack.fromJson(json);

List<String> problemsOf(Map<String, Object?> json) =>
    validatePack(load(json), coverageSeeds: 3).problems;

void main() {
  group('motor de premisas', () {
    test('es determinista y renderiza título y cuento', () {
      final engine = StoryEngine(load(basePack()));
      final a = engine.generate(const StoryOptions(seed: 7));
      final b = engine.generate(const StoryOptions(seed: 7));
      expect(a.scenes.map((s) => s.text), b.scenes.map((s) => s.text));
      expect(a.title, 'El farol');
      expect(a.recipe.fragmentIds, ['p.b1.a', 'p.b2.a', 'p.b3.a']);
      expect(a.recipe.cast['item'], 'farol');
      expect(a.scenes.first.text, 'Ana tenía un farol en la casa.');
      expect(a.recipe.engineVersion, engineVersion);
    });

    test('el reparto respeta etiquetas, ids y no repite entidades', () {
      final json = basePack(
        characters: [
          ...(basePack()['characters']! as List<Object?>)
              .cast<Map<String, Object?>>(),
          {
            'id': 'dani',
            'given': 'Dani',
            'noun': 'aprendiz',
            'gender': 'm',
            'roles': ['helper', 'hero'],
            'alignment': 'positive',
            'trait': {'m': 'x', 'f': 'x'},
          },
        ],
        cast: {
          'hero': {
            'kind': 'character',
            'roles': ['hero']
          },
          'helper': {
            'kind': 'character',
            'roles': ['helper'],
            'tags': ['wise']
          },
          'villain': {
            'kind': 'character',
            'roles': ['villain']
          },
          'casa': {
            'kind': 'place',
            'ids': ['casa']
          },
          'bosque': {
            'kind': 'place',
            'ids': ['bosque']
          },
          'item': {'kind': 'prop'},
        },
      );
      final engine = StoryEngine(load(json));
      final heroes = <String>{};
      for (var seed = 0; seed < 60; seed++) {
        final s = engine.generate(StoryOptions(seed: seed));
        expect(s.cast['helper']!.id, 'beto', reason: 'solo Beto es sabio');
        expect(s.cast['hero']!.id, isNot(s.cast['helper']!.id));
        heroes.add(s.cast['hero']!.id);
      }
      expect(heroes, {'ana', 'dani'});
    });

    test('las variantes pueden exigir un reparto concreto', () {
      final json = basePack();
      final chars =
          (json['characters']! as List<Object?>).cast<Map<String, Object?>>();
      chars.add({
        'id': 'dodo',
        'given': 'Dodo',
        'noun': 'bandido',
        'gender': 'm',
        'roles': ['villain'],
        'alignment': 'negative',
        'trait': {'m': 'x', 'f': 'x'},
        'tags': ['sly'],
      });
      final beats = ((json['premises']! as List<Object?>).first!
          as Map<String, Object?>)['beats']! as List<Object?>;
      final b3 = beats.last! as Map<String, Object?>;
      b3['variants'] = [
        {
          'id': 'greedy',
          'requires': ['villain:greedy'],
          'text': '{villain} contó monedas. «Hola», dijo.'
        },
        {
          'id': 'sly',
          'requires': ['villain:sly'],
          'text': '{villain} se escondió. «Hola», dijo.'
        },
      ];
      final engine = StoryEngine(load(json));
      for (var seed = 0; seed < 40; seed++) {
        final s = engine.generate(StoryOptions(seed: seed));
        final expected =
            s.cast['villain']!.id == 'coco' ? 'p.b3.greedy' : 'p.b3.sly';
        expect(s.recipe.fragmentIds.last, expected);
      }
    });

    test('las etiquetas que añade una variante habilitan las siguientes', () {
      final json = basePack();
      final beats = ((json['premises']! as List<Object?>).first!
          as Map<String, Object?>)['beats']! as List<Object?>;
      (beats[0]! as Map<String, Object?>)['variants'] = [
        {
          'id': 'x',
          'adds': ['paso'],
          'text': '{hero} tenía {item.un} en {casa.el}.'
        },
      ];
      (beats[2]! as Map<String, Object?>)['variants'] = [
        {
          'id': 'solo',
          'requires': ['paso'],
          'text': '{villain} y {helper}. «Hola», dijo.'
        },
        {
          'id': 'nunca',
          'requires': ['jamas'],
          'text': '{villain}.'
        },
      ];
      final s = StoryEngine(load(json)).generate(const StoryOptions(seed: 1));
      expect(s.recipe.fragmentIds.last, 'p.b3.solo');
    });

    test('sin ninguna variante elegible falla con un mensaje claro', () {
      final json = basePack();
      final beats = ((json['premises']! as List<Object?>).first!
          as Map<String, Object?>)['beats']! as List<Object?>;
      (beats[1]! as Map<String, Object?>)['variants'] = [
        {
          'id': 'x',
          'requires': ['villain:nadie'],
          'text': '{hero}.'
        },
      ];
      expect(
        () => StoryEngine(load(json)).generate(const StoryOptions(seed: 1)),
        throwsA(isA<StoryGenerationException>()),
      );
    });

    test('una premisa se elige según la enseñanza pedida', () {
      final json = basePack();
      (json['morals']! as List<Object?>)
          .add({'id': 'm2', 'name': 'Otra', 'text': 'Otra.'});
      final engine = StoryEngine(load(json));
      expect(
          engine
              .generate(const StoryOptions(seed: 1, valueId: 'm1'))
              .recipe
              .fragmentIds
              .first,
          startsWith('p.'));
      // m2 no tiene premisa ni fragmentos: no hay con qué contarla.
      expect(() => engine.generate(const StoryOptions(seed: 1, valueId: 'm2')),
          throwsA(isA<StoryGenerationException>()));
    });
  });

  group('lectura del pack (esquema 2)', () {
    test('rechaza lo mal formado', () {
      final noBeats = basePack(beats: []);
      expect(() => load(noBeats), throwsA(isA<PackFormatException>()));
      final badKind = basePack(cast: {
        'hero': {'kind': 'monstruo'},
      });
      expect(() => load(badKind), throwsA(isA<PackFormatException>()));
      final json = basePack();
      ((json['characters']! as List<Object?>).first!
          as Map<String, Object?>)['attrs'] = {'el': 'x'};
      expect(() => load(json), throwsA(isA<PackFormatException>()),
          reason: 'un atributo no puede pisar una forma gramatical');
    });

    test('un atributo propio del personaje se escribe con {rol.atributo}', () {
      final s =
          StoryEngine(load(basePack())).generate(const StoryOptions(seed: 1));
      expect(s.scenes.last.text, contains('Coco se rascó la barba'));
    });
  });

  group('el validador rechaza cada tipo de sinsentido', () {
    Map<String, Object?> v(String text, {Map<String, Object?>? scene}) => {
          'id': 'a',
          'text': text,
          'scene': scene ??
              {
                'bg': 'casa',
                'actors': ['hero'],
                'mood': 'calm'
              },
        };

    test('alguien actúa antes de ser presentado', () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item'],
          'variants': [v('{hero} habló con {helper} sobre {item.el}.')]
        },
        {
          'id': 'b2',
          'introduces': ['helper'],
          'variants': [v('{helper} y {hero} siguieron, porque sí.')]
        },
        {
          'id': 'b3',
          'introduces': ['villain'],
          'variants': [v('{villain} y {helper}. «Hola», dijo.')]
        },
      ]));
      expect(
          p.join('\n'),
          contains(
              '«helper» se nombra en la escena 1 antes de presentarse en la 2'));
    });

    test('alguien debía presentarse y no se nombra', () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item', 'helper'],
          'variants': [v('{hero} tenía {item.un}.')]
        },
        {
          'id': 'b2',
          'introduces': ['villain'],
          'variants': [v('{villain} y {helper}. «Hola», dijo {hero}.')]
        },
      ]));
      expect(p.join('\n'), contains('debía presentarse en la escena 1'));
    });

    test('un personaje del reparto nunca se presenta', () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item'],
          'variants': [
            v('{hero} tenía {item.un}, porque sí. «Hola», dijo {hero}.')
          ]
        },
        {
          'id': 'b2',
          'variants': [v('{hero} y {item.el}.')]
        },
      ]));
      expect(p.join('\n'), contains('no se presenta en ninguna escena'));
    });

    test('se presenta y desaparece', () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item', 'helper', 'villain'],
          'variants': [v('{hero}, {item.el}, {helper} y {villain}.')]
        },
        {
          'id': 'b2',
          'variants': [v('{hero} y {item.el} y {helper}. «Hola», dijo {hero}.')]
        },
        {
          'id': 'b3',
          'variants': [
            v('{hero} y {item.el} y {helper}. «Adiós», dijo {hero}.')
          ]
        },
      ]));
      expect(p.join('\n'),
          contains('«villain» (coco) solo se nombra en 1 escena'));
    });

    test('cambia de lugar sin contar el viaje', () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item'],
          'variants': [v('{hero} tenía {item.un}.')]
        },
        {
          'id': 'b2',
          'introduces': ['helper'],
          'variants': [
            v('{hero} y {helper} y {item.el}.', scene: {
              'bg': 'bosque',
              'actors': ['hero'],
              'mood': 'calm'
            })
          ]
        },
        {
          'id': 'b3',
          'introduces': ['villain'],
          'variants': [
            v('{villain} y {helper} y {item.el}. «Hola», dijo {hero}.', scene: {
              'bg': 'bosque',
              'actors': ['hero'],
              'mood': 'calm'
            })
          ]
        },
      ]));
      expect(p.join('\n'), contains('cambia de lugar sin contar el viaje'));
    });

    test('un cuento corto, sin causas ni diálogo', () {
      final p = problemsOf(basePack());
      final text = p.join('\n');
      expect(text, contains('muy corto'));
      expect(text, contains('conectores causales'));
      expect(text, contains('citas de diálogo'));
    });

    test('el fondo debe ser un lugar y los actores, personajes', () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item'],
          'variants': [
            v('{hero} tenía {item.un}.', scene: {
              'bg': 'item',
              'actors': ['casa'],
              'mood': 'calm'
            })
          ]
        },
      ]));
      final text = p.join('\n');
      expect(text, contains('no es una ranura de lugar'));
      expect(text, contains('no es una ranura de personaje'));
    });

    test(
        'un atributo que el personaje no tiene, una etiqueta imposible y un texto roto',
        () {
      final p = problemsOf(basePack(beats: [
        {
          'id': 'b1',
          'introduces': ['item'],
          'variants': [
            {
              'id': 'a',
              'text': '{hero.zzz} y {item.un}.',
              'scene': <String, Object?>{}
            },
            {
              'id': 'b',
              'requires': ['paso'],
              'text': '{hero} y  {item.un}.',
              'scene': <String, Object?>{}
            },
            {
              'id': 'c',
              'text': 'Ana va a el bosque con {item.un}.',
              'scene': <String, Object?>{}
            },
          ]
        },
      ]));
      final text = p.join('\n');
      expect(text, contains('la forma «hero.zzz» no existe'));
      expect(text,
          contains('requiere «paso» pero ninguna escena anterior lo añade'));
      expect(text, contains('falta contracción'));
    });
  });

  test('el validador detecta el género fijo («quieto», «yo solo»)', () {
    Map<String, Object?> v(String id, String text) => {
          'id': id,
          'text': text,
          'scene': <String, Object?>{},
        };
    final p = problemsOf(basePack(beats: [
      {
        'id': 'b1',
        'introduces': ['item'],
        'variants': [
          v('mal1', '{hero} se quedó quieto con {item.un}.'),
          v('mal2', '{hero} dijo: «Lo haré yo solo» con {item.un}.'),
          v('mal3', '{hero} estaba dormida con {item.un}.'),
          v('bien',
              '{hero} se quedó quiet{hero.o} y sol{hero.o} con {item.un}. Solo quería dormir.'),
        ],
      },
    ])).join('\n');
    expect(p, contains('mal1: género fijo «quieto»'));
    expect(p, contains('mal2: género fijo «yo solo»'));
    expect(p, contains('mal3: género fijo «dormida»'));
    expect(p, isNot(contains('bien: género fijo')));
  });

  test('el pack medieval real pasa todas las reglas de coherencia', () {
    final pack = Pack.fromJson(
      jsonDecode(
              File('../../content/packs/medieval/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );
    expect(pack.premises.length, greaterThanOrEqualTo(3));
    final report = validatePack(pack);
    expect(report.problems, isEmpty);
    expect(report.rendersChecked, greaterThan(100));
    // Cada enseñanza tiene al menos una premisa.
    for (final m in pack.morals) {
      expect(pack.premises.any((p) => p.fitsValue(m.id)), isTrue, reason: m.id);
    }
  });
}
