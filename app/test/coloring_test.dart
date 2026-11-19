import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/coloring_page.dart';
import 'package:caldero_app/src/art/rig_renderer.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

void main() {
  testWidgets(
      'el dibujo para colorear es una imagen PNG y deja el arte como estaba',
      (tester) async {
    final art = await tester
        .runAsync(() async => StageArt(await loadArtLibrary(FileBundle())));
    final pack = Pack.fromJson(
        jsonDecode(File('assets/packs/medieval/pack.json').readAsStringSync())
            as Map<String, Object?>);
    final story = StoryEngine(pack).generate(StoryOptions(seed: 5));
    final setup = stageFor(art!, story.cast, story.scenes.first.directives)!;
    final png = await tester.runAsync(() => coloringPagePng(setup, width: 400));
    expect(png!.length, greaterThan(1000));
    expect(png.sublist(1, 4), [0x50, 0x4E, 0x47], reason: 'cabecera PNG');
    expect(CompiledShape.outline, isFalse,
        reason: 'el modo de líneas se apaga al terminar');
  });
}
