import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'rig_renderer.dart';
import 'scene_painter.dart';
import 'story_stage.dart';

/// Dibujo para colorear: la escena del cuento en líneas negras sobre blanco (sin colores, brillos ni luz), en
/// una imagen apaisada lista para imprimir en carta o A4. Sale del mismo arte de la app, así que es nuestro.
Future<Uint8List> coloringPagePng(StageSetup setup,
    {double width = 2200}) async {
  final view = setup.view;
  final height = width * view.height / view.width;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFFFF));
  final painter = ScenePainter(
    scene: setup.scene,
    actors: setup.actors,
    props: setup.props,
    ropes: setup.ropes,
    clock: ValueNotifier<double>(0),
    view: view,
  );
  CompiledShape.outline = true;
  try {
    painter.paint(canvas, Size(width, height));
  } finally {
    CompiledShape.outline = false;
  }
  final image =
      await recorder.endRecording().toImage(width.round(), height.round());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Cómo se entrega el dibujo: con el menú de compartir del teléfono (imprimir, guardar, enviar). Las pruebas ponen
/// uno de mentira.
typedef ColoringSender = Future<void> Function(Uint8List png, String title);

Future<void> shareColoringPage(Uint8List png, String title) async {
  final name =
      'para-colorear-${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.png';
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(png, mimeType: 'image/png', name: name)],
    fileNameOverrides: [name],
    subject: 'Para colorear: $title',
    text: 'Un dibujo de «$title» para imprimir y colorear.',
  ));
}
