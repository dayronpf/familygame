/// El nombre del juego, en un solo sitio. **Cuando se elija el nombre definitivo** (ver `docs/19`), se cambia aquí con
/// `tools/rename_app.py "Nombre nuevo"`, que además actualiza la etiqueta de Android y de iOS y vuelve a generar la
/// guía en PDF. Nada más en el código escribe el nombre a mano.
library;

/// El nombre que ve la familia (pantalla de inicio, ajustes, mensaje para compartir, icono del teléfono).
const String appName = 'Caldero de Cuentos';

/// La frase corta debajo del nombre en la pantalla de bienvenida.
const String appTagline = 'Cuentos para soñar';

/// Quién publica la app y cómo contactarle: salen en la política de privacidad y los términos de uso que se leen en
/// Ajustes. **Hay que rellenarlos antes de publicar** (ver `docs/22`); `legalPending` avisa a la familia mientras no
/// estén.
const String legalOwner = '[titular pendiente de definir]';
const String contactEmail = '[correo de contacto pendiente]';

/// Fecha de la última revisión de los textos legales.
const String legalDate = '12 de octubre de 2026';

/// `false` mientras no exista el servidor de valoraciones: la política lo dice con claridad (nada sale del teléfono).
const bool feedbackServerLive = false;

bool get legalPending =>
    legalOwner.startsWith('[') || contactEmail.startsWith('[');
