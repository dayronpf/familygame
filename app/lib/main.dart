import 'dart:ui' show PlatformDispatcher;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/ui/splash_page.dart';
import 'src/content/remote_content.dart';
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
  // Contenido bajado del servidor (docs/34): si existe y vale, reemplaza los paquetes, el catálogo y la voz que trae
  // la app. Leerlo es rápido (unos pocos MB en el teléfono); si tarda o falla, se arranca con lo de dentro.
  final remote = RemoteContent();
  final downloaded = await remote
      .local()
      .timeout(const Duration(seconds: 2), onTimeout: () => null);
  runApp(CalderoApp(
    bundle: downloaded == null
        ? null
        : ContentBundle(rootBundle, downloaded.assets),
    access: access,
    purchases: StorePurchases(access),
    feedback: feedback,
    settings: settings,
    showWizard: true,
    shelf: StoryShelf(PrefsShelfStore(prefs)),
    progress: ReadingProgress(PrefsProgressStore(prefs)),
    showSplash: true,
    splashSound: const AssetSplashSound(),
    recordedVoice: true,
  ));
  // Lo nuevo se busca después de arrancar y vale desde el siguiente arranque (no bloquea ni cambia lo que se ve).
  unawaited(remote.update());
}
