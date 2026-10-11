import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/night_background.dart';
import '../ui/palette.dart';

/// El PDF «Holograma en casa» (tamaño carta, con las plantillas a escala 100 %). Lo genera
/// `tools/guide/make_holograma_pdf.py`.
const String guideAsset = 'assets/guides/holograma-en-casa.pdf';
const String guideFileName = 'holograma-en-casa.pdf';

/// Cómo se entrega el PDF: por defecto con el menú de compartir del teléfono (guardar en Archivos, WhatsApp,
/// correo, imprimir…). Las pruebas ponen uno de mentira.
typedef GuideSender = Future<void> Function(Uint8List pdf);

Future<void> shareGuidePdf(Uint8List pdf) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(pdf, mimeType: 'application/pdf', name: guideFileName)
      ],
      fileNameOverrides: const [guideFileName],
      subject: 'Holograma en casa',
      text:
          'Holograma en casa: instrucciones y plantillas para imprimir en tamaño carta.',
    ),
  );
}

/// Pantalla «Holograma en casa»: qué es, que se hace con un adulto (hay tijeras), los materiales y el PDF para
/// descargar con las instrucciones y la plantilla.
class HologramGuidePage extends StatelessWidget {
  const HologramGuidePage(
      {super.key, this.bundle, this.sender = shareGuidePdf});

  final AssetBundle? bundle;
  final GuideSender sender;

  Future<void> _download(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await (bundle ?? rootBundle).load(guideAsset);
      await sender(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir el PDF. Inténtalo de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    Widget bullet(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3, right: 10),
                child: Icon(Icons.circle, size: 8, color: Palette.amber),
              ),
              Expanded(child: Text(t, style: text.bodyLarge)),
            ],
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Holograma en casa')),
      body: NightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B2A8A), Color(0xFF6B4FD8)],
                        ),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.view_in_ar,
                              size: 56, color: Palette.amber),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              'Haz una pirámide de plástico transparente y mira los cuentos «flotar» sobre la pantalla.',
                              style: text.titleMedium!
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      key: const Key('guide-adult-warning'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1D6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFFE08A00), width: 2),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.content_cut,
                              color: Color(0xFFB36B00)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Solo con un adulto presente. Hay que usar tijeras y recortar plástico: '
                              'el adulto corta y los niños ayudan a marcar, medir y pegar la cinta.',
                              style: text.bodyLarge!.copyWith(
                                color: const Color(0xFF3A2606),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('Qué necesitas',
                        style: text.titleLarge!
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    bullet(
                        'Plástico transparente y liso: lámina de acetato, cubierta de carpeta o la caja de un CD.'),
                    bullet(
                        'La plantilla impresa en papel tamaño carta, al 100 %.'),
                    bullet(
                        'Tijeras (las usa el adulto) y un marcador de punta fina.'),
                    bullet('Cinta adhesiva transparente y una regla.'),
                    bullet(
                        'Una habitación a media luz y la pantalla con el brillo al máximo.'),
                    const SizedBox(height: 18),
                    Text('En el PDF encuentras',
                        style: text.titleLarge!
                            .copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    bullet(
                        'La lista completa de materiales y el paso a paso con dibujos.'),
                    bullet(
                        'Dos plantillas a tamaño real para recortar: teléfono y tableta.'),
                    bullet(
                        'Cómo colocar la pirámide y qué hacer si la imagen se ve al revés.'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 60,
                      child: FilledButton.icon(
                        key: const Key('guide-download'),
                        onPressed: () => _download(context),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Descargar el PDF'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Formato carta (8,5 × 11 pulgadas). Al imprimir elige «Tamaño real» o 100 %.',
                      textAlign: TextAlign.center,
                      style: text.bodySmall!.copyWith(color: Palette.mutedText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
