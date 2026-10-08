import 'dart:math';

import 'package:flutter/material.dart';

/// Pregunta de multiplicar que un niño pequeño no resuelve: protege ajustes y (más adelante) compras.
/// Devuelve `true` solo si la respuesta es correcta.
Future<bool> askAdult(BuildContext context, {Random? random}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => _AdultGateDialog(random ?? Random()),
  );
  return ok ?? false;
}

class _AdultGateDialog extends StatefulWidget {
  const _AdultGateDialog(this.random);

  final Random random;

  @override
  State<_AdultGateDialog> createState() => _AdultGateDialogState();
}

class _AdultGateDialogState extends State<_AdultGateDialog> {
  late final int _a = 6 + widget.random.nextInt(4); // 6–9
  late final int _b = 6 + widget.random.nextInt(4);
  // El campo es del diálogo: se destruye con él, después de su animación de cierre.
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _correct => _controller.text.trim() == '${_a * _b}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Solo para adultos'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('¿Cuánto es $_a × $_b?', key: const Key('gate-question')),
          const SizedBox(height: 12),
          TextField(
            key: const Key('gate-answer'),
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (_) => Navigator.pop(context, _correct),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('gate-ok'),
          onPressed: () => Navigator.pop(context, _correct),
          child: const Text('Entrar'),
        ),
      ],
    );
  }
}
