/// El nombre del juego, en un solo sitio. **Cuando se elija el nombre definitivo** (ver `docs/19`), se cambia aquí con
/// `tools/rename_app.py "Nombre nuevo"`, que además actualiza la etiqueta de Android y de iOS y vuelve a generar la
/// guía en PDF. Nada más en el código escribe el nombre a mano.
library;

import 'package:flutter/foundation.dart';

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
const String legalDate = '18 de noviembre de 2026';

/// El servidor de valoraciones ya funciona (cuentos2.tuvendor.com, POST /v1/feedback): la versión de las tiendas
/// envía las valoraciones si un adulto lo permite. La política ya no dice que nada sale del teléfono.
const bool feedbackServerLive = true;

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

/// Lanzamiento: solo cuentos del catálogo grabado (`assets/catalogo/lanzamiento-es.json`, docs/31 paso A7).
/// «Explorar», las recomendaciones, los avisos y «Crear cuento» usan solo esos cuentos, y cada uno se cuenta siempre
/// igual (su semilla, sin el nombre del niño y sin preguntas) para que el texto sea el que se grabó. Con `false`, el
/// caldero vuelve a crear cuentos nuevos con el nombre del niño y sus preguntas.
const bool catalogOnly = true;

/// El catálogo fijo que lee la app (copia de `content/catalogo/`, la sincroniza `tools/sync_assets.sh`).
const String fixedCatalogAsset = 'assets/catalogo/lanzamiento-es.json';

/// Carpeta pública del audio grabado que no viene dentro de la app (`https://…/voz/es/`, con la barra final).
/// **Se llena en el paso A8** (Cloudflare R2, docs/31). Vacía = solo suenan los cuentos incluidos en la app; los demás
/// los dice la voz del teléfono.
const String recordedVoiceBaseUrl = '';

/// Raíz pública del almacén de contenido (`https://…/`, con la barra final; docs/34). De ahí la app lee, como mucho
/// una vez al día, `contenido/<idioma>/indice.json` y baja los paquetes, el catálogo y el manifiesto de voz nuevos;
/// si [recordedVoiceBaseUrl] está vacía, el audio sale de `voz/<idioma>/` en esta misma raíz. **Se llena en el paso
/// A8** (Cloudflare R2, docs/31). Vacía = apagado: la app usa solo lo que trae dentro.
const String contentBaseUrl = 'https://audio.tuvendor.com/';

/// La tienda del teléfono, para los textos de compra y cancelación.
String get storeName => defaultTargetPlatform == TargetPlatform.iOS
    ? 'la App Store'
    : 'Google Play';

/// Dónde se cancela la suscripción, en palabras de cada tienda.
String get storeCancelPath => defaultTargetPlatform == TargetPlatform.iOS
    ? 'Ajustes › tu nombre › Suscripciones'
    : 'Google Play › Pagos y suscripciones';

/// Identificador de la app en las tiendas.
const String appPackageId = 'com.mininoches.app';

/// La página de la tienda donde se cancela o cambia la suscripción (la de esta app, en Google Play).
Uri manageSubscriptionUrl() => defaultTargetPlatform == TargetPlatform.iOS
    ? Uri.parse('https://apps.apple.com/account/subscriptions')
    : Uri.parse('https://play.google.com/store/account/subscriptions'
        '?sku=$subscriptionProductId&package=$appPackageId');
