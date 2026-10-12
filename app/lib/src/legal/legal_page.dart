import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../brand.dart';

/// Los textos legales con los datos de la marca puestos ({{APP}}, {{TITULAR}}…). Se leen de `assets/legal/`.
String fillLegal(String raw) => raw
    .replaceAll('{{APP}}', appName)
    .replaceAll('{{TITULAR}}', legalOwner)
    .replaceAll('{{CORREO}}', contactEmail)
    .replaceAll('{{FECHA}}', legalDate)
    .replaceAll(
      '{{ESTADO_SERVIDOR}}',
      feedbackServerLive
          ? ''
          : 'Hoy la app todavía no tiene servidor de valoraciones: las notas se guardan en el teléfono y no se envían a ningún sitio.',
    );

/// Un texto legal en pantalla (política de privacidad, términos de uso): títulos, listas y párrafos sencillos.
class LegalPage extends StatefulWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.asset,
    this.bundle,
  });

  final String title;

  /// Ruta del texto, p. ej. `assets/legal/politica-de-privacidad.es.md`.
  final String asset;
  final AssetBundle? bundle;

  @override
  State<LegalPage> createState() => _LegalPageState();
}

class _LegalPageState extends State<LegalPage> {
  late final Future<String> _text =
      (widget.bundle ?? rootBundle).loadString(widget.asset).then(fillLegal);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _text,
          builder: (context, snap) {
            if (snap.hasError) {
              return const Center(child: Text('No se pudo abrir el texto.'));
            }
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              key: const Key('legal-text'),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (legalPending)
                  Container(
                    key: const Key('legal-pending'),
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Versión de prueba: faltan el titular y el correo de contacto, y el texto no ha pasado por revisión legal.',
                    ),
                  ),
                ..._blocks(context, snap.data!),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _blocks(BuildContext context, String raw) {
    final text = Theme.of(context).textTheme;
    final out = <Widget>[];
    for (final line in raw.split('\n')) {
      final l = line.trimRight();
      if (l.isEmpty) continue;
      if (l.startsWith('# ')) {
        out.add(Text(l.substring(2), style: text.headlineSmall));
        out.add(const SizedBox(height: 8));
      } else if (l.startsWith('## ')) {
        out.add(const SizedBox(height: 16));
        out.add(Text(l.substring(3), style: text.titleMedium));
        out.add(const SizedBox(height: 6));
      } else if (l.startsWith('> ')) {
        out.add(Text(l.substring(2),
            style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic)));
        out.add(const SizedBox(height: 8));
      } else if (l.startsWith('- ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('•  '),
              Expanded(child: Text(_plain(l.substring(2)))),
            ],
          ),
        ));
      } else {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(_plain(l)),
        ));
      }
    }
    return out;
  }

  /// Quita las marcas de negrita (`**texto**`).
  String _plain(String s) => s.replaceAll('**', '');
}
