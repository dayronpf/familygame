# 25 · Compilar para iPhone

Hay **dos caminos**; los dos usan el mismo proyecto (`app/ios`, bundle id `com.calderodecuentos.cuentos`, iOS 15+, audio en segundo plano
activado en `Info.plist`).

## A. En tu Mac (lo más directo para instalar en tu iPhone)

Requisitos: Xcode instalado, Flutter 3.47.6 (la misma versión que el CI), CocoaPods y una cuenta de Apple Developer (o, solo para probar en tu
propio teléfono, un Apple ID gratuito: la app caduca a los 7 días).

```bash
cd app
flutter pub get
open ios/Runner.xcworkspace     # Xcode → Runner → Signing & Capabilities: elige tu Team y, si hace falta, cambia el Bundle Identifier
flutter run --release -d <tu iPhone>          # instala y abre la app en el iPhone conectado
# o, para subir a TestFlight / App Store:
flutter build ipa --release                   # deja build/ios/ipa/*.ipa; súbelo con Transporter o Xcode (Organizer)
```

Notas:
* Un agente de Claude Code **que corre en la nube (contenedor Linux) no puede compilar iOS**: no hay Xcode. Hay que lanzarlo en una sesión
  de Claude Code que corra **en tu Mac** (o a mano, con los comandos de arriba).
* Si cambias el nombre de la app, `python3 tools/rename_app.py "Nombre"` lo cambia en un solo sitio; el *bundle id* de iOS se cambia en Xcode.
* Primera vez en el iPhone: *Ajustes → General → VPN y gestión de dispositivos → confiar en tu cuenta de desarrollador*, y activar el *Modo
  desarrollador* (iOS 16+).

## B. En GitHub (sin firmar, para comprobar que compila)

El workflow `.github/workflows/ios.yml` («iOS (compilación de prueba)») compila en una máquina macOS de GitHub:
`flutter build ios --release --no-codesign` y guarda `Runner.app` (sin firmar) como artefacto. Se lanza **a mano** (Actions → *Run workflow*) o
cambiando `app/BUILD_IOS.txt` en una rama `claude/**`. **No se puede instalar tal cual en un iPhone**: iOS solo ejecuta apps firmadas.

Para que GitHub produzca un `.ipa` instalable hay que dar al repositorio, como *secrets*, el certificado de distribución (`.p12` en base64 y su
contraseña), el perfil de aprovisionamiento y el Team ID de tu cuenta de Apple, y añadir al workflow los pasos de importar el certificado y
`flutter build ipa` con un `ExportOptions.plist`. Eso no está hecho: son credenciales tuyas y no deben pasar por el agente ni estar en el repo.

## Qué conviene probar en iPhone (nada de esto se ha probado todavía)

* Voz del sistema (AVSpeechSynthesizer): voces en español, velocidad y el saludo del asistente.
* **Audio con la pantalla bloqueada**: en Android hay un servicio en primer plano; en iOS depende de `UIBackgroundModes: audio` y de la sesión
  de audio de `audioplayers`/`flutter_tts`. Comprobar que el cuento sigue sonando al bloquear y que el centro de control muestra «reproduciendo».
* Efectos de sonido mezclados con la voz (`mixWithOthers`), música de fondo y bajada gradual del temporizador de sueño.
* Brillo (`ScreenDimmer`) y pantalla encendida (`wakelock`) en cine y holograma.
* Compartir (`share_plus`) y la guía en PDF del holograma.
* Notch / *Dynamic Island* y barra inferior en el modo cine; tamaños de texto grandes.
* Requisitos de App Store para apps infantiles: [22](22-privacidad-y-tiendas.md) (Kids Category, etiqueta de privacidad).

## Android: APK de prueba y paquete firmado para Google Play

* El **APK de prueba** (`Android (APK de prueba)`) va firmado con una llave de prueba pública: sirve para instalar y actualizar encima, no para
  publicar.
* Para **Google Play** hace falta un `.aab` firmado con tu llave privada. El workflow `Android (release firmado)` lo compila **a mano** si guardas
  antes, como secretos del repositorio, el almacén de claves en base64 y sus contraseñas (la lista exacta y cómo crear la llave están en la
  cabecera de `.github/workflows/android-release.yml`). En local basta con crear `app/android/key.properties` (no se sube al repositorio) y
  `flutter build appbundle --release`. Guarda una copia de seguridad de la llave: sin ella no se puede actualizar la app.
* **Identificador de la app:** `com.calderodecuentos.cuentos` en Android y en iOS (antes iOS tenía `…calderoApp`; se unificó). Cámbialo en los dos
  sitios si registras otro en las tiendas.
* Prueba en emulador: `Android (emulador)` arranca la app real y recorre asistente, ajustes, privacidad y un cuento (`app/integration_test`).
