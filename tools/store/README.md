# Material para las fichas de las tiendas

* **Icono:** `python3 tools/art/make_app_icon.py` (dibujado por código) → `art/app_icon/icon-1024.png` y todos los tamaños de Android/iOS.
* **Capturas de teléfono** (`art/store/phone/`, 1236×2676 px; sirven para la ficha de App Store «6,7 pulgadas» y de Google Play):

  ```bash
  cd app
  UI_SCALE=3 UI_W=412 UI_H=892 UI_OUT=/tmp/ui flutter test test/ui_shots_manual_test.dart
  ```

  La herramienta `app/test/ui_shots_manual_test.dart` dibuja las pantallas reales de la app (con sus textos y dibujos) sin necesitar
  un teléfono. Copia a `art/store/phone/` las que quieras. Las de hoy (8-nov-2026): `0-bienvenida` (02_splash_b), `1-inicio` (03_home), `2-cuento` (07_story), `3-mis-cuentos` (09_mis_cuentos), `4-explorar` (05_explore), `5-edad` (12_wizard_edad) y `6-premios` (10_premios). Añade `FLUTTER_FONTS=<flutter>/bin/cache/artifacts/material_fonts` si Flutter no está en `/opt/flutter-sdk`.
  Son capturas de **widgets**, no del dispositivo: antes de publicar conviene sustituirlas por capturas reales de un iPhone y de un Android.
* **Textos legales públicos:** `python3 tools/legal/build_site.py site` y `.github/workflows/pages.yml` (GitHub Pages).
* Faltan (dependen de decisiones del dueño): el nombre definitivo, el titular y el correo de contacto (`app/lib/src/brand.dart`),
  la descripción de la ficha y la categoría (Kids / Familia). Ver [docs/22](../../docs/22-privacidad-y-tiendas.md).
