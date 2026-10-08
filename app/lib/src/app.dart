import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'feedback/feedback_service.dart';
import 'home_page.dart';
import 'seed.dart';
import 'theme.dart';

class CalderoApp extends StatelessWidget {
  const CalderoApp({
    super.key,
    required this.feedback,
    this.bundle,
    this.seedProvider = timeSeed,
  });

  /// Origen de los assets; por defecto el de la app.
  final AssetBundle? bundle;
  final SeedProvider seedProvider;
  final FeedbackService feedback;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Caldero de Cuentos',
      debugShowCheckedModeBanner: false,
      theme: nightTheme(),
      home: HomePage(
        bundle: bundle ?? rootBundle,
        seedProvider: seedProvider,
        feedback: feedback,
      ),
    );
  }
}
