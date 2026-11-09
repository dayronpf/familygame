import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'brand.dart';
import 'feedback/adult_gate.dart';

/// Dónde se descarga la app. Mientras no esté en las tiendas es el enlace del APK de prueba; cuando se
/// publique, se cambia aquí por el de la tienda.
const String appDownloadUrl =
    'https://github.com/dayronpf/familygame/releases/download/apk-latest/mininoches.apk';

const String shareMessage =
    '🌙 ¡Te recomiendo $appName! Cuentos para dormir con dibujos animados, voz y una enseñanza, '
    'pensados para niños. Descárgala aquí: $appDownloadUrl';

/// Abre el menú de compartir del teléfono (WhatsApp, mensajes, correo…). Si no se puede, copia el mensaje.
/// Compartir saca un enlace fuera de la app: en la zona de los niños va detrás de la pregunta para adultos (lo exigen
/// Apple —guía 1.3, categoría Niños— y la política de Familias de Google). En Ajustes, que ya la pidió, `gated: false`.
Future<void> shareApp(BuildContext context, {bool gated = true}) async {
  if (gated && !await askAdult(context)) return;
  if (!context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await SharePlus.instance.share(
      ShareParams(text: shareMessage, subject: appName),
    );
  } catch (_) {
    await Clipboard.setData(const ClipboardData(text: shareMessage));
    messenger?.showSnackBar(
      const SnackBar(
          content:
              Text('Copiamos el mensaje: pégalo donde quieras compartirlo')),
    );
  }
}

/// Recomienda un cuento concreto (su título y el enlace de la app).
Future<void> shareStory(BuildContext context, String title,
    {bool gated = true}) async {
  if (gated && !await askAdult(context)) return;
  if (!context.mounted) return;
  final text =
      '🌙 Esta noche leímos «$title» en $appName. Descárgala aquí: $appDownloadUrl';
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await SharePlus.instance.share(ShareParams(text: text, subject: title));
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(
      const SnackBar(
          content:
              Text('Copiamos el mensaje: pégalo donde quieras compartirlo')),
    );
  }
}
