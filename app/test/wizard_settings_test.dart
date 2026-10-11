import 'package:caldero_app/src/app.dart';
import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/narration/narrator.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/ui/voice_picker.dart';
import 'package:caldero_app/src/ui/voice_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_tts.dart';
import 'file_bundle.dart';

final _bundle = FileBundle();

const _voices = [
  TtsVoice(name: 'es-es-x-eea-local', locale: 'es-ES'),
  TtsVoice(name: 'es-us-x-sfb-local', locale: 'es-US'),
  TtsVoice(name: 'es-es-x-eea-network', locale: 'es-ES'),
  TtsVoice(name: 'es-mx-x-bkr-local', locale: 'es-MX'),
  TtsVoice(name: 'es-ar-x-zzz-local', locale: 'es-AR'),
];

/// Voces de mentira: lista fija y un motor que anota lo que dice cada una.
class FakeVoices {
  final tts = FakeTts();
  final said = <String>[];
  final configs = <VoiceConfig>[];

  VoiceServices get services => VoiceServices(
        listVoices: () async => _voices,
        sampleNarrator: (config) {
          configs.add(config);
          return TtsNarrator(
            tts: tts,
            config: config,
            retryDelay: const Duration(milliseconds: 5),
            fallback: TimedNarrator(wordsPerSecond: 1000, minSeconds: 0.01),
          );
        },
        storyNarrator: (config) => TimedNarrator(wordsPerSecond: 1000),
      );
}

FeedbackService _feedback() => FeedbackService(store: MemoryFeedbackStore());

void main() {
  void phone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(412, 915)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<AppSettings> openApp(
    WidgetTester tester, {
    AppSettings? settings,
    FakeVoices? voices,
    bool wizard = true,
  }) async {
    phone(tester);
    final s = settings ?? AppSettings(MemorySettingsStore());
    await tester.pumpWidget(CalderoApp(
      bundle: _bundle,
      feedback: _feedback(),
      settings: s,
      voices: (voices ?? FakeVoices()).services,
      showWizard: wizard,
      animateArt: false,
    ));
    await tester.pumpAndSettle();
    return s;
  }

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('wizard-next')));
    await tester.pumpAndSettle();
  }

  group('ajustes (modelo)', () {
    test('valores por defecto: idioma del sistema, primera voz, perfil 4–5',
        () {
      final s = AppSettings(MemorySettingsStore(), systemLanguage: 'es');
      expect(s.wizardDone, isFalse);
      expect(s.child.language, 'es');
      expect(s.child.voice, isNull);
      expect(s.child.age, '4-5');
      expect(s.child.speed, ReadingSpeed.normal);
      expect(s.music, isTrue);
    });

    test('si el idioma del sistema no está, se usa español y se avisa', () {
      final s = AppSettings(MemorySettingsStore(), systemLanguage: 'fr');
      expect(s.child.language, 'es');
      expect(s.systemLanguageUnavailable, isTrue);
      expect(
          AppSettings(MemorySettingsStore(), systemLanguage: 'es')
              .systemLanguageUnavailable,
          isFalse);
    });

    test('se guardan y se leen de nuevo, incluido wizard_completado', () async {
      final store = MemorySettingsStore();
      final a = AppSettings(store);
      await a.load();
      await a.completeWizard(
        language: 'es',
        voice: const TtsVoice(name: 'v1', locale: 'es-ES'),
        age: '6-8',
      );
      await a.updateChild(speed: ReadingSpeed.slow);
      await a.setMusic(on: false, volume: 0.4);

      final b = AppSettings(store);
      await b.load();
      expect(b.wizardDone, isTrue);
      expect(b.child.age, '6-8');
      expect(b.child.voice, const TtsVoice(name: 'v1', locale: 'es-ES'));
      expect(b.child.speed, ReadingSpeed.slow);
      expect(b.music, isFalse);
      expect(b.musicVolume, 0.4);
      expect(store.value, contains('wizard_completado'));
    });

    test('la velocidad es la del perfil de edad por la lectura elegida', () {
      const base = ChildProfile(age: '6-8');
      expect(base.voiceConfig.speed, closeTo(0.90, 1e-9));
      expect(base.copyWith(speed: ReadingSpeed.slow).voiceConfig.speed,
          closeTo(0.90 * 0.85, 1e-9));
      expect(
          base.copyWith(age: '2-3', speed: ReadingSpeed.fast).voiceConfig.speed,
          closeTo(0.80 * 1.15, 1e-9));
      expect(base.copyWith(age: '9-12').voiceConfig.speed, closeTo(1.0, 1e-9));
    });

    test('el modelo guarda una lista de perfiles (varios niños más adelante)',
        () async {
      final store = MemorySettingsStore();
      final s = AppSettings(store);
      await s.updateChild(age: '2-3');
      expect(s.profiles, hasLength(1));
      expect(store.value, contains('"perfiles"'));
    });

    test('ajustes ilegibles empiezan de cero y el wizard vuelve a salir',
        () async {
      final s = AppSettings(MemorySettingsStore()..value = '{{no');
      await s.load();
      expect(s.wizardDone, isFalse);
    });
  });

  group('voces', () {
    test(
        '1 a 4 opciones: sin repetir, las de sin conexión primero, nombres amigables',
        () {
      final o = voiceOptions(_voices);
      expect(o, hasLength(4));
      expect(o.map((v) => v.name), ['Luna', 'Brisa', 'Nube', 'Trueno']);
      expect(
          o.any((v) => v.voice!.name.contains('network') && o.indexOf(v) < 3),
          isFalse);
      // nunca el código técnico
      for (final v in o) {
        expect(v.name, isNot(contains('es-')));
      }
      // el mismo orden siempre
      expect(voiceOptions(_voices.reversed.toList()).map((v) => v.voice),
          o.map((v) => v.voice));
    });

    test('sin voces en el teléfono sigue habiendo una opción', () {
      final o = voiceOptions(const []);
      expect(o, hasLength(1));
      expect(o.single.voice, isNull);
    });
  });

  group('wizard', () {
    testWidgets('la primera vez sale el wizard y al terminar entra al inicio',
        (tester) async {
      final voices = FakeVoices();
      final s = await openApp(tester, voices: voices);
      expect(find.text('¿En qué idioma les contamos los cuentos?'),
          findsOneWidget);
      expect(find.byKey(const Key('language-es')), findsOneWidget);
      expect(find.text('Crear cuento'), findsNothing);

      await next(tester); // idioma → voz
      expect(find.text('¿Quién les cuenta el cuento?'), findsOneWidget);
      expect(find.byKey(const Key('voice-card-0')), findsOneWidget);
      expect(find.byKey(const Key('voice-card-3')), findsOneWidget);
      // toca la segunda: suena el saludo con su nombre
      await tester.tap(find.byKey(const Key('voice-card-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(voices.tts.spoken.last,
          '¡Hola! Soy Brisa y esta noche te voy a contar un cuento.');
      await next(tester); // voz → edad

      expect(find.text('¿Qué edad tiene el niño?'), findsOneWidget);
      for (final id in ['2-3', '4-5', '6-8', '9-12']) {
        expect(find.byKey(Key('age-$id')), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('age-6-8')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('age-note')), findsNothing,
          reason: 'hay cuentos de 6–8');
      await next(tester); // edad → nombre

      expect(find.text('¿Cómo se llama el niño?'), findsOneWidget);
      await tester.enterText(
          find.byKey(const Key('wizard-name')), '  Valentina ');
      await tester.tap(find.byKey(const Key('gender-f')));
      await tester.pumpAndSettle();
      await next(tester); // nombre → resumen

      expect(find.text('Todo listo'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(find.text('Brisa'), findsOneWidget);
      expect(find.text('6–8 años'), findsOneWidget);
      expect(find.text('Valentina'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard-start')));
      await tester.pumpAndSettle();

      expect(find.text('Crear cuento'), findsOneWidget);
      expect(s.wizardDone, isTrue);
      expect(s.child.age, '6-8');
      expect(s.child.name, 'Valentina');
      expect(s.child.heroName, 'Valentina');
      expect(s.child.heroGender, 'f');
      expect(s.child.voice, voiceOptions(_voices)[1].voice);
    });

    testWidgets('el saludo se detiene si se toca otra voz o se avanza',
        (tester) async {
      final voices = FakeVoices();
      await openApp(tester, voices: voices);
      await next(tester);
      await tester.tap(find.byKey(const Key('voice-card-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(voices.tts.speaking, isTrue);
      final stopsBefore = voices.tts.stops;
      await tester.tap(find.byKey(const Key('voice-card-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(voices.tts.stops, greaterThan(stopsBefore));
      expect(voices.tts.spoken.last, contains('Nube'));
      // al avanzar, se corta
      final before = voices.tts.stops;
      await next(tester);
      expect(voices.tts.stops, greaterThan(before));
      expect(voices.tts.speaking, isFalse);
    });

    testWidgets('elegir una edad sin cuentos lo explica con honestidad',
        (tester) async {
      await openApp(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.byKey(const Key('age-9-12')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('age-note')), findsOneWidget);
      expect(find.textContaining('6–8 años'), findsWidgets);
    });

    testWidgets('«Saltar» usa los valores por defecto y no vuelve a salir',
        (tester) async {
      final store = MemorySettingsStore();
      final s = await openApp(tester, settings: AppSettings(store));
      await tester.tap(find.byKey(const Key('wizard-skip')));
      await tester.pumpAndSettle();
      expect(find.text('Crear cuento'), findsOneWidget);
      expect(s.wizardDone, isTrue);
      expect(s.child.age, '4-5');
      expect(s.child.voice, isNull);
      expect(s.child.language, 'es');

      // abrir la app otra vez: el wizard ya no sale (y se lee del almacén)
      final again = AppSettings(store);
      await again.load();
      await openApp(tester, settings: again);
      expect(find.text('Crear cuento'), findsOneWidget);
      expect(find.byKey(const Key('wizard-skip')), findsNothing);
    });

    testWidgets('el resumen deja cambiar y volver a empezar', (tester) async {
      await openApp(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      expect(find.text('Todo listo'), findsOneWidget);
      await tester.tap(find.byKey(const Key('wizard-change')));
      await tester.pumpAndSettle();
      expect(find.text('¿En qué idioma les contamos los cuentos?'),
          findsOneWidget);
    });

    testWidgets(
        'los botones del resumen no se parten en pantallas estrechas ni con letra grande',
        (tester) async {
      for (final width in [320.0, 412.0]) {
        tester.view
          ..physicalSize = Size(width, 800)
          ..devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        await tester.pumpWidget(CalderoApp(
          key: ValueKey(width),
          bundle: _bundle,
          feedback: _feedback(),
          settings: AppSettings(MemorySettingsStore()),
          voices: FakeVoices().services,
          showWizard: true,
          animateArt: false,
        ));
        await tester.pumpAndSettle();
        await next(tester);
        await next(tester);
        await next(tester);
        await next(tester);
        for (final label in ['Cambiar', 'Empezar']) {
          final h = tester.getSize(find.text(label)).height;
          expect(h, lessThan(40),
              reason: '$label a $width dp (una sola línea)');
        }
        addTearDown(tester.view.reset);
      }
    });

    testWidgets('con un idioma de sistema sin cuentos se avisa en el wizard',
        (tester) async {
      await openApp(tester,
          settings: AppSettings(MemorySettingsStore(), systemLanguage: 'fr'));
      expect(find.byKey(const Key('language-unavailable')), findsOneWidget);
    });

    testWidgets('si no hay wizard (pruebas, o ya hecho) se entra directo',
        (tester) async {
      await openApp(tester, wizard: false);
      expect(find.text('Crear cuento'), findsOneWidget);
    });
  });

  group('Ajustes de adultos', () {
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open-settings')));
      await tester.pumpAndSettle();
      final q =
          tester.widget<Text>(find.byKey(const Key('gate-question'))).data!;
      final m = RegExp(r'(\d) × (\d)').firstMatch(q)!;
      await tester.enterText(find.byKey(const Key('gate-answer')),
          '${int.parse(m.group(1)!) * int.parse(m.group(2)!)}');
      await tester.tap(find.byKey(const Key('gate-ok')));
      await tester.pumpAndSettle();
    }

    testWidgets('cambiar edad, velocidad y música se guarda y vale al instante',
        (tester) async {
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard();
      await openApp(tester, settings: settings, wizard: false);
      await openSettings(tester);

      expect(find.text('Cuentos y voz'), findsOneWidget);

      await tester.scrollUntilVisible(find.byKey(const Key('setting-age')), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.descendant(
          of: find.byKey(const Key('setting-age')),
          matching: find.text('6–8')));
      await tester.pumpAndSettle();
      expect(settings.child.age, '6-8');
      expect(find.byKey(const Key('setting-age-note')), findsNothing);

      await tester.tap(find.descendant(
          of: find.byKey(const Key('setting-age')),
          matching: find.text('9–12')));
      await tester.pumpAndSettle();
      expect(settings.child.age, '9-12');
      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-age-note')), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('setting-age-note')), findsOneWidget);

      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-speed')), 100,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.descendant(
          of: find.byKey(const Key('setting-speed')),
          matching: find.text('Lenta')));
      await tester.pumpAndSettle();
      expect(settings.child.speed, ReadingSpeed.slow);

      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-music')), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.byKey(const Key('setting-music')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('setting-music')));
      await tester.pumpAndSettle();
      expect(settings.music, isFalse);
      await tester.scrollUntilVisible(
          find.byKey(const Key('setting-downloads')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('setting-downloads')), findsOneWidget);
    });

    testWidgets('la voz se elige con tarjetas y suena su saludo',
        (tester) async {
      final voices = FakeVoices();
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard();
      await openApp(tester, settings: settings, voices: voices, wizard: false);
      await openSettings(tester);
      await tester.tap(find.byKey(const Key('voice-card-2')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(settings.child.voice, voiceOptions(_voices)[2].voice);
      expect(voices.tts.spoken.last, contains('Nube'));
    });

    testWidgets(
        'con una edad sin cuentos propios igual se cuenta uno (el más cercano)',
        (tester) async {
      final settings = AppSettings(MemorySettingsStore());
      await settings.completeWizard(age: '9-12');
      await openApp(tester, settings: settings, wizard: false);
      // el pack medieval solo tiene cuentos 6–8: igual se cuenta uno (el más cercano)
      await tester.tap(find.text('Crear cuento'));
      await tester.pumpAndSettle();
      expect(find.text('Enseñanza'), findsNothing); // aún arriba del cuento
      expect(find.byType(Scrollable), findsWidgets);
    });
  });
}
