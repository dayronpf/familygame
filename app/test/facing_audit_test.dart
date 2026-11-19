import 'dart:convert';
import 'dart:io';

import 'package:caldero_app/src/art/art_library.dart';
import 'package:caldero_app/src/art/scene_painter.dart';
import 'package:caldero_app/src/art/story_stage.dart';
import 'package:caldero_app/src/catalog/story_catalog.dart';
import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'file_bundle.dart';

Pack _pack(String id) => Pack.fromJson(
      jsonDecode(File('assets/packs/$id/pack.json').readAsStringSync())
          as Map<String, Object?>,
    );

/// En todos los cuentos del catálogo, cada dibujo de perfil (tortuga, cabrita, loro, chispa…) mira hacia el
/// personaje más cercano de su escena, o hacia el centro si está solo: nunca de espaldas a quien tiene al lado.
void main() {
  test('en ningún cuento un animal de perfil le da la espalda a los demás',
      () async {
    final packs = {
      for (final id in ['medieval', 'mar', 'cosmos']) id: _pack(id)
    };
    final arts = <String, StageArt>{
      for (final id in packs.keys)
        id: StageArt(await loadArtLibrary(FileBundle(), pack: id)),
    };
    final catalog = StoryCatalog.fromPacks(packs);
    var seen = 0;
    final report = <String>[];
    for (final s in catalog.stories) {
      final story = StoryEngine(s.pack)
          .generate(s.options(childAge: s.premise.ages.first));
      final art = arts[s.pack.id]!;
      for (final sc in story.scenes) {
        final setup = stageFor(art, story.cast, sc.directives);
        if (setup == null) continue;
        final all = [...setup.actors, ...setup.props];
        for (final a in all.where((a) => a.rig.facing != 0)) {
          seen++;
          final looks = a.flip ? -a.rig.facing : a.rig.facing;
          ActorInstance? nearest;
          for (final o in setup.actors) {
            if (identical(o, a) || (o.x - a.x).abs() < 1) continue;
            if (nearest == null ||
                (o.x - a.x).abs() < (nearest.x - a.x).abs()) {
              nearest = o;
            }
          }
          final target = nearest?.x ?? setup.view.center.dx;
          final want = (target - a.x).sign.toInt();
          report.add('${s.key} ${sc.fragmentId}: ${a.rig.rig.id} mira '
              '${looks > 0 ? 'derecha' : 'izquierda'}'
              '${nearest != null ? ' hacia ${nearest.rig.rig.id}' : ' (sola)'}');
          if (want != 0) {
            expect(looks, want,
                reason:
                    '${s.key} ${sc.fragmentId}: ${a.rig.rig.id} de espaldas');
          }
        }
      }
    }
    if (Platform.environment['FACING_REPORT'] != null) {
      File(Platform.environment['FACING_REPORT']!)
          .writeAsStringSync(report.join('\n'));
    }
    expect(seen, greaterThan(0), reason: 'hay cuentos con animales de perfil');
  });
}
