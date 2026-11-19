import 'package:caldero_app/src/audio/ambience.dart';
import 'package:caldero_app/src/audio/sleep_music.dart';
import 'package:flutter_test/flutter_test.dart';

class _Music implements Ambience {
  bool playing = true;
  double level = 1;
  @override
  Future<void> start() async => playing = true;
  @override
  Future<void> stop() async => playing = false;
  @override
  Future<void> setLevel(double l) async => level = l;
  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets(
      'al terminar, el fondo sigue los minutos elegidos y luego se apaga solo',
      (t) async {
    {
      final m = _Music();
      SleepMusic(m).storyFinished(15);
      await t.pump(const Duration(minutes: 14));
      expect(m.playing, isTrue);
      expect(m.level, 1);
      await t.pump(const Duration(minutes: 2));
      expect(m.playing, isFalse);
      expect(m.level, 1,
          reason: 'vuelve al volumen normal para la próxima vez');
    }
  });

  testWidgets(
      'con «No» se apaga suave enseguida; si vuelven a reproducir se cancela',
      (t) async {
    {
      final m = _Music();
      final s = SleepMusic(m)..storyFinished(0);
      await t.pump(const Duration(seconds: 3));
      expect(m.level, lessThan(1), reason: 'bajando');
      await t.pump(const Duration(seconds: 4));
      expect(m.playing, isFalse);

      final m2 = _Music();
      final s2 = SleepMusic(m2)..storyFinished(15);
      s2.cancel();
      await t.pump(const Duration(minutes: 30));
      expect(m2.playing, isTrue);
      s.cancel();
    }
  });
}
