import 'package:caldero_app/src/feedback/feedback_service.dart';
import 'package:caldero_app/src/feedback/feedback_store.dart';
import 'package:caldero_app/src/notifications/bedtime_reminder.dart';
import 'package:caldero_app/src/settings/app_settings.dart';
import 'package:caldero_app/src/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _FakeReminder implements BedtimeReminder {
  _FakeReminder({this.allowed = true});

  final bool allowed;
  TimeOfDay? scheduled;
  int cancels = 0;

  @override
  Future<bool> schedule(TimeOfDay time) async {
    if (!allowed) return false;
    scheduled = time;
    return true;
  }

  @override
  Future<void> cancel() async => cancels++;
}

void main() {
  test('el próximo aviso es hoy si aún no pasó la hora; si no, mañana', () {
    tzdata.initializeTimeZones();
    final loc = tz.getLocation('America/Panama');
    final at = tz.TZDateTime(loc, 2026, 11, 8, 18, 0);
    final today = nextInstanceOf(const TimeOfDay(hour: 19, minute: 30), at);
    expect([today.day, today.hour, today.minute], [8, 19, 30]);
    final tomorrow = nextInstanceOf(const TimeOfDay(hour: 7, minute: 0), at);
    expect([tomorrow.day, tomorrow.hour], [9, 7]);
  });

  Future<AppSettings> openSettings(
      WidgetTester tester, BedtimeReminder reminder) async {
    tester.view
      ..physicalSize = const Size(1080, 2340)
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final settings = AppSettings(MemorySettingsStore());
    await settings.load();
    await tester.pumpWidget(MaterialApp(
      home: SettingsScope(
        settings: settings,
        child: SettingsPage(
          feedback: FeedbackService(store: MemoryFeedbackStore()),
          reminder: reminder,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final tile = find.byKey(const Key('setting-reminder'));
    await tester.scrollUntilVisible(tile, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('encender el recordatorio pide la hora, lo programa y se guarda',
      (tester) async {
    final fake = _FakeReminder();
    final settings = await openSettings(tester, fake);
    await tester.tap(find.byKey(const Key('setting-reminder')));
    await tester.pumpAndSettle();
    expect(find.text('¿A qué hora es el cuento?'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(fake.scheduled, const TimeOfDay(hour: 19, minute: 30));
    expect(settings.reminderMinutes, 19 * 60 + 30);

    await tester.tap(find.byKey(const Key('setting-reminder')));
    await tester.pumpAndSettle();
    expect(settings.reminderMinutes, isNull);
    expect(fake.cancels, 1);
  });

  testWidgets('sin permiso no queda encendido y se explica', (tester) async {
    final settings = await openSettings(tester, _FakeReminder(allowed: false));
    await tester.tap(find.byKey(const Key('setting-reminder')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(settings.reminderMinutes, isNull);
    expect(find.textContaining('Sin permiso para avisar'), findsOneWidget);
  });
}
