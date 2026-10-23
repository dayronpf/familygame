import 'package:flutter/material.dart';

/// Pregunta si [name] es un niño o una niña (`m`/`f`; `null` si se cierra sin elegir).
///
/// Para los niños guardados con nombre y «al azar»: con su nombre el cuento no puede decidirlo, porque el dibujo
/// y la gramática («solo/sola») siguen al héroe elegido.
Future<String?> askHeroGender(BuildContext context, String name) =>
    showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿$name es un niño o una niña?'),
        content: const Text(
          'Así el cuento lo dibuja y habla de su protagonista como toca. Se puede cambiar en Ajustes.',
        ),
        actions: [
          TextButton(
            key: const Key('ask-gender-m'),
            onPressed: () => Navigator.pop(context, 'm'),
            child: const Text('Un niño'),
          ),
          // Los dos con el mismo peso: ninguna respuesta va «por defecto»
          TextButton(
            key: const Key('ask-gender-f'),
            onPressed: () => Navigator.pop(context, 'f'),
            child: const Text('Una niña'),
          ),
        ],
      ),
    );
