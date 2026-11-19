import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/coloring_page.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

/// Herramienta de revisión: guarda dibujos para colorear de unas escenas. UI_OUT=/tmp/x flutter test …
void main() {
  final out = Platform.environment['UI_OUT'];
  testWidgets('dibujos para colorear', (tester) async {
    for (final id in ['medieval', 'mar']) {
      final art = await tester.runAsync(
          () async => StageArt(await loadArtLibrary(FileBundle(), pack: id)));
      final pack = Pack.fromJson(jsonDecode(
              File('assets/packs/$id/pack.json').readAsStringSync())
          as Map<String, Object?>);
      final story = StoryEngine(pack).generate(StoryOptions(seed: 5));
      final setup = stageFor(art!, story.cast, story.scenes[1].directives)!;
      final png = await tester.runAsync(() => coloringPagePng(setup, width: 1100));
      File('$out/colorear_$id.png').writeAsBytesSync(png!);
    }
  }, skip: out == null);
}
