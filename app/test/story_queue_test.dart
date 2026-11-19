import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/story_queue_page.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final pack = Pack.fromJson(
      jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
          as Map<String, Object?>);
  final engine = StoryEngine(pack);
  final stories = [
    for (var s = 1; s <= 3; s++) engine.generate(StoryOptions(seed: s))
  ];

  Widget fakePage(Story story, bool last, VoidCallback done) => Scaffold(
        body: Column(children: [
          Text('suena ${story.recipe.seed}'),
          Text(last ? 'último' : 'sigue otro'),
          TextButton(onPressed: done, child: const Text('terminar')),
        ]),
      );

  testWidgets(
      'los favoritos suenan seguidos y el último se queda con la música',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StoryQueuePage(
        title: 'Mis favoritos',
        length: 3,
        storyAt: (i) => i < 3 ? stories[i] : null,
        pageFor: fakePage,
        gap: const Duration(seconds: 2),
      ),
    ));
    expect(find.text('Mis favoritos · 1 de 3'), findsOneWidget);
    expect(find.text('suena ${stories[0].recipe.seed}'), findsOneWidget);
    for (var i = 1; i < 3; i++) {
      await tester.tap(find.text('terminar'));
      await tester.pump();
      expect(find.byKey(const Key('queue-next')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('suena ${stories[i].recipe.seed}'), findsOneWidget);
      expect(find.text('Mis favoritos · ${i + 1} de 3'), findsOneWidget);
    }
    expect(find.text('último'), findsOneWidget);
    await tester.tap(find.text('terminar'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('suena ${stories[2].recipe.seed}'), findsOneWidget,
        reason: 'después del último no viene nada');
  });

  testWidgets('la radio no tiene fin', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: StoryQueuePage(
        title: 'Radio de cuentos',
        storyAt: (i) => stories[i % 3],
        pageFor: fakePage,
        gap: const Duration(seconds: 1),
      ),
    ));
    expect(find.text('sigue otro'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text('terminar'));
      await tester.pump(const Duration(seconds: 2));
    }
    expect(find.text('suena ${stories[4 % 3].recipe.seed}'), findsOneWidget);
    expect(find.text('Radio de cuentos'), findsOneWidget);
  });
}
