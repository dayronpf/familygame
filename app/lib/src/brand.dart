/// El nombre del juego, en un solo sitio. **Cuando se elija el nombre definitivo** (ver `docs/19`), se cambia aquí con
/// `tools/rename_app.py "Nombre nuevo"`, que además actualiza la etiqueta de Android y de iOS y vuelve a generar la
/// guía en PDF. Nada más en el código escribe el nombre a mano.
library;

/// El nombre que ve la familia (pantalla de inicio, ajustes, mensaje para compartir, icono del teléfono).
const String appName = 'Mininoches';

/// La frase corta debajo del nombre en la pantalla de bienvenida.
const String appTagline = 'Cuentos para soñar';

/// Quién publica la app y cómo contactarle: salen en la política de privacidad y los términos de uso que se leen en
/// Ajustes. **Hay que rellenarlos antes de publicar** (ver `docs/22`); `legalPending` avisa a la familia mientras no
/// estén.
const String legalOwner = 'TuVendor';
const String contactEmail = 'ventas@tuvendor.com';

/// Fecha de la última revisión de los textos legales.
const String legalDate = '8 de noviembre de 2026';

/// `false` mientras no exista el servidor de valoraciones: la política lo dice con claridad (nada sale del teléfono).
const bool feedbackServerLive = false;

bool get legalPending =>
    legalOwner.startsWith('[') || contactEmail.startsWith('[');

/// Producto de suscripción en Google Play (un producto con dos planes base: `anual` y `mensual`). Es un
/// identificador técnico de la tienda: **no cambia** aunque cambie el nombre de la app.
const String subscriptionProductId = 'mininoches_premium';

/// En App Store cada duración es un producto distinto (mismo grupo de suscripción): plan → id de producto.
const Map<String, String> iosSubscriptionProducts = {
  'anual': 'mininoches_premium_anual',
  'mensual': 'mininoches_premium_mensual',
};

/// Días de prueba configurados en App Store Connect (StoreKit 2 no los expone en el plugin de Flutter).
const int iosTrialDays = 7;
