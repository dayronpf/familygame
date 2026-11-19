import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/recordings/family_recordings.dart';
import 'package:caldero_app/src/shelf/story_shelf.dart';
import 'package:caldero_app/src/store/access.dart';
import 'package:caldero_app/src/recordings/recorder_page.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Micrófono de mentira: «graba» un archivo vacío donde le digan.
class _Mic implements VoiceRecorder {
  _Mic({this.allowed = true});
  final bool allowed;
  String? _path;
  @override
  Future<bool> hasPermission() async => allowed;
  @override
  Future<void> start(String path) async => _path = path;
  @override
  Future<String?> stop() async {
    File(_path!).writeAsStringSync('audio');
    return _path;
  }

  @override
  Future<void> dispose() async {}
}

Story _story() {
  final pack = Pack.fromJson(
      jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
          as Map<String, Object?>);
  return StoryEngine(pack)
      .generate(StoryOptions(seed: 7, premiseId: 'sombras'));
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('grab'));
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test(
      'la voz de la familia solo vale con el cuento grabado entero, y se recuerda',
      () async {
    final story = _story();
    final texts = recordingTexts(story);
    final r = FamilyRecordings(dir);
    for (var i = 0; i < texts.length - 1; i++) {
      final f = await r.pathFor(story.catalogId!, i);
      File(f).writeAsStringSync('x');
      await r.put(story.catalogId!, voice: 'Papá', text: texts[i], file: f);
    }
    expect(r.voiceFor(story.catalogId!, texts), isNull,
        reason: 'falta la última');
    final f = await r.pathFor(story.catalogId!, texts.length - 1);
    File(f).writeAsStringSync('x');
    await r.put(story.catalogId!, voice: 'Papá', text: texts.last, file: f);
    final voice = r.voiceFor(story.catalogId!, texts)!;
    expect(voice.clipsFor(story.catalogId)!.clipFor(story.scenes.first.text),
        isNotNull);

    final again = FamilyRecordings(dir);
    await again.load();
    expect(again.of(story.catalogId!)!.voice, 'Papá');
    expect(again.voiceFor(story.catalogId!, texts), isNotNull);

    await again.deleteAll();
    expect(again.all, isEmpty);
    expect(dir.existsSync(), isFalse);
  });

  testWidgets('se elige quién graba y se graba página a página hasta terminar',
      (tester) async {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final story = _story();
    final r = FamilyRecordings(dir);
    await tester.pumpWidget(MaterialApp(
      home: RecorderPage(
          story: story,
          storyKey: story.catalogId!,
          recordings: r,
          recorder: _Mic()),
    ));
    await tester.tap(find.byKey(const Key('voice-Mamá')));
    await tester.pump();
    final n = recordingTexts(story).length;
    for (var i = 0; i < n; i++) {
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('recorder-record')));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
        await tester.tap(find.byKey(const Key('recorder-record')));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        await tester.pump();
      });
      await tester.pump();
      if (i < n - 1) {
        await tester.tap(find.byKey(const Key('recorder-next')));
        await tester.pump();
      }
    }
    await tester.pump();
    expect(find.byKey(const Key('recorder-complete')), findsOneWidget);
    expect(r.of(story.catalogId!)!.voice, 'Mamá');
  });

  testWidgets('sin permiso del micrófono lo explica', (tester) async {
    final story = _story();
    await tester.pumpWidget(MaterialApp(
      home: RecorderPage(
          story: story,
          storyKey: story.catalogId!,
          recordings: FamilyRecordings(dir),
          recorder: _Mic(allowed: false)),
    ));
    await tester.tap(find.byKey(const Key('voice-Papá')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('recorder-record')));
      await Future<void>.delayed(const Duration(milliseconds: 30));
    });
    await tester.pump();
    expect(find.byKey(const Key('recorder-denied')), findsOneWidget);
  });

  testWidgets(
      'la ficha ofrece grabar y, con el cuento grabado, escucharlo con esa voz',
      (tester) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final r = FamilyRecordings(dir);
    final access = AccessService(MemoryShelfStore());
    await tester.pumpWidget(CalderoApp(
      bundle: FileBundle(),
      seedProvider: () => 3,
      feedback: FeedbackService(store: MemoryFeedbackStore()),
      shelf: StoryShelf(MemoryShelfStore()),
      access: access,
      animateArt: false,
      recordings: r,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explorar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('explore-search')), 'sombras');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('story-row-medieval:sombras')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('detail-record')), findsOneWidget);
    expect(find.byKey(const Key('detail-family-listen')), findsNothing);

    // Se abre la pantalla de grabar (con el mismo cuento que la ficha) y se graba entero «por detrás»
    await tester.tap(find.byKey(const Key('detail-record')));
    await tester.pumpAndSettle();
    final rp = tester.widget<RecorderPage>(find.byType(RecorderPage));
    final texts = recordingTexts(rp.story);
    final key = rp.storyKey;
    expect(key, 'medieval:sombras');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (var i = 0; i < texts.length; i++) {
        final f = await r.pathFor(key, i);
        File(f).writeAsStringSync('x');
        await r.put(key, voice: 'Mamá', text: texts[i], file: f);
      }
    });
    await tester.pumpAndSettle();
    expect(find.text('Escuchar con la voz de Mamá'), findsOneWidget);
  });
}
