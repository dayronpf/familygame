import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/story/talk_questions.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'tres preguntas por cuento, con el nombre del protagonista y siempre las mismas',
      () {
    for (final id in ['medieval', 'mar', 'cosmos']) {
      final pack = Pack.fromJson(
          jsonDecode(File('assets/packs/$id/pack.json').readAsStringSync())
              as Map<String, Object?>);
      final engine = StoryEngine(pack);
      final morals = <String>{};
      for (var seed = 1; seed <= 40; seed++) {
        final story = engine.generate(StoryOptions(seed: seed));
        morals.add(story.moral.id);
        final q = talkQuestions(story);
        expect(q, hasLength(3), reason: '$id $seed');
        expect(q.toSet(), hasLength(3), reason: 'sin repetir');
        expect(q.any((x) => x.contains('{')), isFalse);
        expect(talkQuestions(story), q,
            reason: 'mismo cuento, mismas preguntas');
        for (final x in q) {
          expect(x.startsWith('¿') && x.endsWith('?'), isTrue, reason: x);
        }
      }
      expect(morals, hasLength(greaterThanOrEqualTo(4)));
    }
  });
}
