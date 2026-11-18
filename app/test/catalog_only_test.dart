import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart' show Source;
import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/brand.dart';
import 'package:caldero_app/src/catalog/story_catalog.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/narration/recorded_voice.dart';
import 'package:caldero_app/src/pack_loader.dart';
import 'package:caldero_app/src/player_support.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// El catálogo fijo del lanzamiento (docs/31, A7): con `catalogOnly` la app solo cuenta los cuentos grabados, y
/// cada uno siempre con las opciones de su entrada (sin el nombre del niño, sin edad, sin preguntas).

final _bundle = FileBundle();

Pack _pack(String id) => Pack.fromJson(
      jsonDecode(File('assets/packs/$id/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );

FixedCatalog _fixed() => FixedCatalog.fromJson(
      jsonDecode(File(fixedCatalogAsset).readAsStringSync())
          as Map<String, Object?>,
    );

Map<String, Pack> _packs() => {
      for (final id in ['medieval', 'mar', 'cosmos']) id: _pack(id),
    };

void main() {
  test('el lanzamiento es solo con el catálogo grabado', () {
    expect(catalogOnly, isTrue);
    expect(recordedVoiceBaseUrl, isEmpty, reason: 'se llena en el paso A8');
  });

  group('catálogo fijo', () {
    test('solo entran los cuentos del catálogo, en su orden', () {
      final fixed = _fixed();
      final c = StoryCatalog.fromPacks(_packs(), fixed: fixed);
      expect(c.stories.map((s) => s.key), fixed.entries.map((e) => e.id));
      expect(c.stories.every((s) => s.fixed), isTrue);
      expect(c.stories.any((s) => s.key == 'medieval:amigo_nuevo'), isFalse,
          reason: 'un cuento que no se grabó no sale');
      // Sin el catálogo fijo, todos los de los paquetes (como antes)
      final all = StoryCatalog.fromPacks(_packs());
      expect(all.stories.length, greaterThan(c.stories.length));
      expect(all.stories.any((s) => s.fixed), isFalse);
    });

    test(
        'un cuento del catálogo ignora al niño y se cuenta con sus opciones fijas',
        () {
      final fixed = _fixed();
      final c = StoryCatalog.fromPacks(_packs(), fixed: fixed);
      for (final s in c.stories) {
        final e = fixed.byId(s.key)!;
        final o =
            s.options(childAge: '6-8', heroName: 'Valentina', heroGender: 'm');
        expect(o.seed, e.seed, reason: s.key);
        expect(s.seed, e.seed, reason: s.key);
        expect(o.premiseId, e.premiseId);
        expect(o.heroGender, e.heroGender);
        expect(o.heroName, isNull);
        expect(o.age, isNull);
        expect(o.interactive, isFalse);
        expect(s.fitsChild(heroName: 'Valentina', heroGender: 'm'), isTrue);
      }
      final s = c.stories.first;
      final engine = StoryEngine(s.pack);
      final story = engine.generate(s.options(heroName: 'Valentina'));
      final expected = engine.generate(fixed.byId(s.key)!.options());
      expect(
          story.scenes.map((x) => x.text), expected.scenes.map((x) => x.text));
      expect(story.title, expected.title);
      expect(story.catalogId, s.key);
      expect(engine.begin(s.options()).isComplete, isTrue,
          reason: 'sin preguntas');
    });

    test('si el catálogo fijo no se puede leer, se queda vacío', () async {
      final c = await loadFixedCatalog(_bundle,
          path: 'assets/catalogo/no-existe.json');
      expect(c.isEmpty, isTrue);
    });
  });

  group('en la app', () {
    void phone(WidgetTester tester) {
      tester.view
        ..physicalSize = const Size(1080, 2340)
        ..devicePixelRatio = 3;
      addTearDown(tester.view.reset);
    }

    Future<(AppSettings, StoryShelf)> openApp(
      WidgetTester tester, {
      bool catalogOnly = true,
      StoryShelf? shelf,
      int seed = 3,
    }) async {
      phone(tester);
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(
          age: '6-8', name: 'Valentina', heroGender: 'f');
      final s = shelf ?? StoryShelf(MemoryShelfStore());
      await tester.pumpWidget(CalderoApp(
        bundle: _bundle,
        seedProvider: () => seed++,
        feedback: FeedbackService(store: MemoryFeedbackStore()),
        settings: settings,
        shelf: s,
        showWizard: false,
        animateArt: false,
        catalogOnly: catalogOnly,
      ));
      await tester.pumpAndSettle();
      return (settings, s);
    }

    Future<void> search(WidgetTester tester, String q) async {
      await tester.enterText(find.byKey(const Key('explore-search')), q);
      await tester.pumpAndSettle();
    }

    testWidgets('«Explorar» solo enseña los cuentos del catálogo',
        (tester) async {
      await openApp(tester);
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      await search(tester, 'sombras del cuarto');
      expect(
          find.byKey(const Key('story-row-medieval:sombras')), findsOneWidget);
      await search(tester, 'mochila verde');
      expect(find.byKey(const Key('story-row-medieval:amigo_nuevo')),
          findsNothing);
      expect(find.textContaining('No encontramos'), findsOneWidget);
    });

    testWidgets(
        'con el interruptor apagado, «Explorar» enseña todos como antes',
        (tester) async {
      await openApp(tester, catalogOnly: false);
      await tester.tap(find.text('Explorar'));
      await tester.pumpAndSettle();
      await search(tester, 'mochila verde');
      expect(find.byKey(const Key('story-row-medieval:amigo_nuevo')),
          findsOneWidget);
    });

    testWidgets(
        '«Crear cuento» cuenta uno del catálogo de esa enseñanza, sin el nombre del niño ni preguntas',
        (tester) async {
      final (_, shelf) = await openApp(tester);
      await tester.tap(find.text('Valentía'));
      await tester.pump();
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      // Uno de valentía del Reino de la Luna, contado con las opciones fijas de su entrada del catálogo
      final entry = shelf.recent.first;
      final e = _fixed().byId('medieval:${entry.premiseId}')!;
      expect(
          _pack('medieval')
              .premises
              .firstWhere((p) => p.id == entry.premiseId)
              .value,
          'valentia');
      expect(entry.seed, e.seed);
      expect(entry.heroName, isNull);
      expect(entry.age, isNull);
      expect(entry.heroGender, e.heroGender);
      expect(entry.hero, e.heroName);
      // Las elecciones son las que hizo sola la app, las mismas de la grabación
      expect(
        entry.choices,
        StoryEngine(_pack('medieval'))
            .generate(e.options())
            .choices
            .map((c) => c.optionId),
      );
      expect(find.byKey(const Key('choice-for-me')), findsNothing,
          reason: 'sin preguntas');
      expect(find.textContaining('Valentina'), findsNothing);

      // «Contar otro cuento» es otro del catálogo, también con sus opciones fijas
      final another = find.text('Contar otro cuento');
      await tester.scrollUntilVisible(another, 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(another);
      await tester.pumpAndSettle();
      final next = shelf.recent.first;
      expect(next.premiseId, isNot('sombras'));
      final ne = _fixed().byId('medieval:${next.premiseId}');
      expect(ne, isNotNull, reason: 'del catálogo');
      expect(next.seed, ne!.seed);
      expect(next.heroGender, ne.heroGender);
      expect(next.heroName, isNull);
      expect(find.textContaining('Valentina'), findsNothing);
    });

    testWidgets('un cuento guardado de antes se sigue pudiendo volver a contar',
        (tester) async {
      final shelf = StoryShelf(MemoryShelfStore());
      await shelf.load();
      await shelf.addRecent(const ShelfEntry(
        seed: 5,
        option: 'valentia',
        title: 'Un cuento de antes',
        moral: 'Valentía',
        moralId: 'valentia',
        hero: 'Valentina',
        packId: 'medieval',
        day: '2026-10-11',
        age: '6-8',
        heroName: 'Valentina',
        heroGender: 'f',
      ));
      await openApp(tester, shelf: shelf);
      await tester.tap(find.text('Mis cuentos'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Un cuento de antes').first);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.textContaining('Valentina'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.textContaining('Valentina'), findsWidgets,
          reason: 'se cuenta igual que la primera vez, con su nombre');
      expect(shelf.recent.first.heroName, 'Valentina');
    });
  });

  group('voz grabada de un cuento', () {
    final fixed = _fixed();
    final e = fixed.entries.first;
    final story = StoryEngine(_pack(e.packId)).generate(e.options());

    RecordedVoice voiceWith(Map<String, RecordedClip> byText) => RecordedVoice(
          language: 'es',
          stories: {e.id: StoryClips(byText)},
          store: _NoClips(),
          player: _SilentPlayer.new,
        );

    Future<({StoryClips? clips, ClipStore? store, ClipPlayer? player})> read(
        WidgetTester tester, RecordedVoice? voice) async {
      late ({StoryClips? clips, ClipStore? store, ClipPlayer? player}) out;
      final builder = Builder(builder: (context) {
        out = recordedFor(context, story);
        return const SizedBox();
      });
      await tester.pumpWidget(voice == null
          ? builder
          : RecordedVoiceScope(voice: voice, child: builder));
      return out;
    }

    RecordedClip clip(String text) =>
        RecordedClip(text: text, file: 'x.m4a', seconds: 1, bundled: true);

    testWidgets('el cuento del catálogo trae sus audios y un reproductor',
        (tester) async {
      final r = await read(tester,
          voiceWith({for (final s in story.scenes) s.text: clip(s.text)}));
      expect(r.clips, isNotNull);
      expect(r.store, isNotNull);
      expect(r.player, isA<_SilentPlayer>());
    });

    testWidgets(
        'si casi nada coincide (un cuento con el nombre del niño) suena todo con la voz del teléfono',
        (tester) async {
      final r = await read(
          tester,
          voiceWith({
            story.title!: clip(story.title!),
            story.scenes.first.text: clip(story.scenes.first.text),
          }));
      expect(r.clips, isNull);
      expect(r.player, isNull);
    });

    testWidgets('sin voz grabada (las pruebas) todo queda como antes',
        (tester) async {
      final r = await read(tester, null);
      expect(r.clips, isNull);
      expect(r.store, isNull);
      expect(r.player, isNull);
    });
  });
}

class _NoClips implements ClipStore {
  @override
  Future<Source?> sourceFor(RecordedClip clip) async => null;
  @override
  Future<void> prefetch(Iterable<RecordedClip> clips) async {}
}

class _SilentPlayer implements ClipPlayer {
  @override
  Future<bool> play(Source source) async => true;
  @override
  Future<void> stop() async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> dispose() async {}
}
