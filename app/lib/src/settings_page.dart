import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'feedback/feedback_service.dart';
import 'feedback/rating_event.dart';

/// Ajustes para adultos: permiso de valoraciones y transparencia total sobre qué se envía.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.feedback});

  final FeedbackService feedback;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _enabled;
  int _queued = 0;

  static final RatingEvent _example = RatingEvent(
    id: '3f2b8c1e-5a47-4d2e-9b0a-7c1d6e8f2a90',
    recipe: const StoryRecipe(
      packId: 'medieval',
      packVersion: '1.0.0',
      engineVersion: engineVersion,
      seed: 482913,
      valueId: 'honestidad',
      cast: {
        'hero': 'nilo',
        'helper': 'bruna',
        'villain': 'brisca',
        'place': 'bosque',
        'place2': 'rio'
      },
      fragmentIds: [
        'op_1',
        'tr_hon',
        'he_hon',
        'te_1',
        'cl_hon',
        're_hon',
        'cl_end'
      ],
    ),
    rating: 5,
    day: '2026-10-08',
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final e = await widget.feedback.enabled;
    final q = await widget.feedback.queuedCount();
    if (!mounted) return;
    setState(() {
      _enabled = e;
      _queued = q;
    });
  }

  Future<void> _toggle(bool value) async {
    await widget.feedback.setEnabled(value);
    await _refresh();
    if (!mounted || value) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Listo. Se borró lo que esperaba para enviarse.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = _enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes para adultos')),
      body: SafeArea(
        child: enabled == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SwitchListTile(
                    key: const Key('feedback-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ayudar a mejorar los cuentos'),
                    subtitle: const Text(
                        'Enviar la valoración (1 a 5) de forma anónima al terminar un cuento.'),
                    value: enabled,
                    onChanged: _toggle,
                  ),
                  if (enabled && _queued > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Esperando para enviarse: $_queued',
                          style: text.bodySmall),
                    ),
                  const Divider(height: 32),
                  Text('Qué enviamos', style: text.titleMedium),
                  const SizedBox(height: 8),
                  const _Bullets(items: [
                    'La nota que dieron, de 1 a 5.',
                    'Qué cuento fue, solo con códigos: la enseñanza, los personajes y las partes que lo formaron. Con eso podemos mejorar las partes que no gustan.',
                    'El día (sin la hora) y la versión de la app.',
                  ]),
                  const SizedBox(height: 16),
                  Text('Qué NO enviamos', style: text.titleMedium),
                  const SizedBox(height: 8),
                  const _Bullets(items: [
                    'Nombres, edades, fotos, voz ni ubicación.',
                    'El texto del cuento.',
                    'Datos del teléfono, cuentas, ni identificadores de publicidad (no hay anuncios).',
                    'Nada que permita saber quién es su familia.',
                  ]),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: const Key('example-tile'),
                    tilePadding: EdgeInsets.zero,
                    title:
                        const Text('Ver un ejemplo exacto de lo que se envía'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(_example.toJson()),
                          key: const Key('example-json'),
                          style:
                              text.bodySmall?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Versión de la app: $appVersion', style: text.bodySmall),
                ],
              ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(i)),
              ],
            ),
          ),
      ],
    );
  }
}
