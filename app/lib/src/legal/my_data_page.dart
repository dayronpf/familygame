import 'dart:convert';

import 'package:flutter/material.dart';

/// «Ver mis datos»: todo lo que la app guarda en este teléfono, tal cual (transparencia total para los adultos).
class MyDataPage extends StatelessWidget {
  const MyDataPage({super.key, required this.load});

  /// Devuelve lo guardado (ajustes, cuentos, valoraciones pendientes).
  final Future<Map<String, Object?>> Function() load;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis datos en este teléfono')),
      body: SafeArea(
        child: FutureBuilder<Map<String, Object?>>(
          future: load(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Esto es todo lo que la app guarda, y no sale del teléfono. Un adulto puede borrarlo desde Ajustes.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(snap.data),
                  key: const Key('my-data-json'),
                  style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
