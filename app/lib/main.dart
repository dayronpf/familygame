import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'src/app.dart';
import 'src/feedback/feedback_service.dart';
import 'src/feedback/feedback_store.dart';
import 'src/feedback/feedback_transport.dart';

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
  runApp(CalderoApp(feedback: feedback));
}
