import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art/story_stage.dart';
import 'feedback/feedback_service.dart';
import 'home_page.dart';
import 'seed.dart';
import 'shelf/story_shelf.dart';
import 'theme.dart';
import 'ui/splash_page.dart';

class CalderoApp extends StatefulWidget {
  const CalderoApp({
    super.key,
    required this.feedback,
    this.bundle,
    this.seedProvider = timeSeed,
    this.animateArt = true,
    this.shelf,
    this.showSplash = false,
    this.splashMinimum = const Duration(milliseconds: 3000),
  });

  /// Si `false`, los dibujos de los cuentos no se animan (pruebas).
  final bool animateArt;

  /// Origen de los assets; por defecto el de la app.
  final AssetBundle? bundle;
  final SeedProvider seedProvider;
  final FeedbackService feedback;

  /// «Mis cuentos»; por defecto uno en memoria (la app real pasa el que se guarda en el teléfono).
  final StoryShelf? shelf;

  /// Muestra la pantalla de bienvenida animada antes del inicio (la app real sí; las pruebas no).
  final bool showSplash;
  final Duration splashMinimum;

  @override
  State<CalderoApp> createState() => _CalderoAppState();
}

class _CalderoAppState extends State<CalderoApp> {
  late final AssetBundle _bundle = widget.bundle ?? rootBundle;
  late final StoryShelf _shelf = widget.shelf ?? StoryShelf(MemoryShelfStore());
  late bool _splash = widget.showSplash;

  /// Se precarga el arte mientras suena el splash, para que el inicio ya esté listo al caer.
  late final Future<void> _ready = widget.showSplash
      ? Future.wait<void>([
          loadStageArt(_bundle).then((_) {}),
          _shelf.load(),
        ])
      : Future<void>.value();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caldero de Cuentos',
      debugShowCheckedModeBanner: false,
      theme: nightTheme(),
      // Sin animación (pruebas): las estrellitas y demás adornos se quedan quietos, como con «reducir movimiento».
      builder: (context, child) => widget.animateArt
          ? child!
          : MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
      home: Stack(
        children: [
          // Mientras suena el splash, el inicio se prepara debajo y no se lee con el lector de pantalla.
          ExcludeSemantics(
            excluding: _splash,
            child: HomePage(
              bundle: _bundle,
              seedProvider: widget.seedProvider,
              feedback: widget.feedback,
              shelf: _shelf,
              animateArt: widget.animateArt,
            ),
          ),
          if (_splash)
            Positioned.fill(
              child: SplashPage(
                ready: _ready,
                minimum: widget.splashMinimum,
                onFinished: () => setState(() => _splash = false),
              ),
            ),
        ],
      ),
    );
  }
}
