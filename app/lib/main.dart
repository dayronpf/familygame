import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/feedback/feedback_service.dart';
import 'src/feedback/feedback_store.dart';
import 'src/feedback/feedback_transport.dart';
import 'src/progress/reading_progress.dart';
import 'src/store/access.dart';
import 'src/store/purchases.dart';
import 'src/settings/app_settings.dart';
import 'src/shelf/story_shelf.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final feedback = FeedbackService(
    store: PrefsFeedbackStore(prefs),
    // Sin servidor configurado, las valoraciones esperan en el teléfono (ver docs/12).
    transport: configuredApi.isEmpty
        ? null
        : HttpFeedbackTransport(Uri.parse('$configuredApi/v1/feedback')),
  );
  final settings = AppSettings(
    PrefsSettingsStore(prefs),
    systemLanguage: PlatformDispatcher.instance.locale.languageCode,
  );
  await settings.load();
  final access = AccessService(
    PrefsAccessStore(prefs),
    api: configuredApi.isEmpty ? null : HttpStoreApi(configuredApi),
  );
  await access.load();
  runApp(CalderoApp(
    access: access,
    purchases: StorePurchases(access),
    feedback: feedback,
    settings: settings,
    showWizard: true,
    shelf: StoryShelf(PrefsShelfStore(prefs)),
    progress: ReadingProgress(PrefsProgressStore(prefs)),
    showSplash: true,
  ));
}
