import 'package:caldero_engine/caldero_engine.dart' show AgePremises;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art/story_stage.dart';
import 'feedback/feedback_service.dart';
import 'home_page.dart';
import 'pack_loader.dart';
import 'seed.dart';
import 'settings/app_settings.dart';
import 'shelf/story_shelf.dart';
import 'theme.dart';
import 'ui/splash_page.dart';
import 'ui/voice_services.dart';
import 'ui/wizard_page.dart';
import 'brand.dart';

class CalderoApp extends StatefulWidget {
  const CalderoApp({
    super.key,
    required this.feedback,
    this.bundle,
    this.seedProvider = timeSeed,
    this.animateArt = true,
    this.shelf,
    this.settings,
    this.voices = const VoiceServices(),
    this.showWizard = false,
    this.showSplash = false,
    this.splashMinimum = const Duration(milliseconds: 3600),
  });

  /// Si `false`, los dibujos de los cuentos no se animan (pruebas).
  final bool animateArt;

  /// Origen de los assets; por defecto el de la app.
  final AssetBundle? bundle;
  final SeedProvider seedProvider;
  final FeedbackService feedback;

  /// «Mis cuentos»; por defecto uno en memoria (la app real pasa el que se guarda en el teléfono).
  final StoryShelf? shelf;

  /// Ajustes de la familia; por defecto unos en memoria (la app real pasa los que se guardan en el teléfono).
  final AppSettings? settings;

  /// Cómo se crean las voces (las pruebas ponen versiones mudas).
  final VoiceServices voices;

  /// Muestra el wizard la primera vez que se abre la app (si los ajustes no lo dan por hecho). Las pruebas no.
  final bool showWizard;

  /// Muestra la pantalla de bienvenida animada antes del inicio (la app real sí; las pruebas no).
  final bool showSplash;
  final Duration splashMinimum;

  @override
  State<CalderoApp> createState() => _CalderoAppState();
}

class _CalderoAppState extends State<CalderoApp> {
  late final AssetBundle _bundle = widget.bundle ?? rootBundle;
  late final StoryShelf _shelf = widget.shelf ?? StoryShelf(MemoryShelfStore());
  late final AppSettings _settings =
      widget.settings ?? AppSettings(MemorySettingsStore());
  late bool _wizard = widget.showWizard && !_settings.wizardDone;
  late bool _splash = widget.showSplash;

  /// Si se borran los datos (Ajustes), el asistente de bienvenida vuelve a salir.
  void _showWizardAgain() {
    if (widget.showWizard && !_settings.wizardDone && !_wizard && mounted) {
      setState(() => _wizard = true);
    }
  }

  @override
  void initState() {
    super.initState();
    _settings.addListener(_showWizardAgain);
  }

  @override
  void dispose() {
    _settings.removeListener(_showWizardAgain);
    super.dispose();
  }

  /// Se precarga el arte mientras suena el splash, para que el inicio ya esté listo al caer.
  late final Future<void> _ready = widget.showSplash
      ? Future.wait<void>([
          loadStageArt(_bundle).then((_) {}),
          _shelf.load(),
        ])
      : Future<void>.value();

  Widget _wizardPage() => FutureBuilder<Set<String>>(
        future: loadPack(_bundle)
            .then((p) => p.agesWithStories)
            .catchError((Object _) => const {'6-8'}),
        builder: (context, snap) => snap.data == null
            ? const SizedBox.expand()
            : WizardPage(
                settings: _settings,
                voices: widget.voices,
                agesWithStories: snap.data!,
                onDone: () => setState(() => _wizard = false),
              ),
      );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: nightTheme(),
      // Sin animación (pruebas): las estrellitas y demás adornos se quedan quietos, como con «reducir movimiento».
      builder: (context, child) => SettingsScope(
        settings: _settings,
        voices: widget.voices,
        child: widget.animateArt
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: true),
                child: child!,
              ),
      ),
      home: Stack(
        children: [
          // Mientras suena el splash, el inicio se prepara debajo y no se lee con el lector de pantalla.
          ExcludeSemantics(
            excluding: _splash,
            child: _wizard
                ? _wizardPage()
                : HomePage(
                    bundle: _bundle,
                    seedProvider: widget.seedProvider,
                    feedback: widget.feedback,
                    shelf: _shelf,
                    animateArt: widget.animateArt,
                  ),
          ),
          // El splash se desvanece al caer (en vez de desaparecer de golpe)
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _splash
                  ? SplashPage(
                      key: const ValueKey('splash'),
                      ready: _ready,
                      minimum: widget.splashMinimum,
                      onFinished: () => setState(() => _splash = false),
                    )
                  : const SizedBox.shrink(key: ValueKey('home')),
            ),
          ),
        ],
      ),
    );
  }
}
