import 'dart:async';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'audio_only_page.dart';
import 'ui/palette.dart';

/// Varios cuentos seguidos en «Solo escuchar»: la lista de favoritos o la radio de cuentos (al azar, sin fin). Al
/// terminar uno, una pausa corta y empieza el siguiente; la música para dormir solo suena después del último.
class StoryQueuePage extends StatefulWidget {
  const StoryQueuePage({
    super.key,
    required this.title,
    required this.storyAt,
    this.length,
    this.gap = const Duration(seconds: 4),
    this.pageFor,
  });

  /// «Mis favoritos» o «Radio de cuentos».
  final String title;

  /// El cuento número [i] (desde 0), o `null` si no hay más.
  final Story? Function(int i) storyAt;

  /// Cuántos hay (`null` = sin fin, como la radio).
  final int? length;

  /// Silencio entre un cuento y el siguiente.
  final Duration gap;

  /// Cómo se arma la pantalla de cada cuento (las pruebas ponen una sin sonido).
  final Widget Function(Story story, bool last, VoidCallback onFinished)?
      pageFor;

  @override
  State<StoryQueuePage> createState() => _StoryQueuePageState();
}

class _StoryQueuePageState extends State<StoryQueuePage> {
  int _i = 0;
  Story? _story;
  Timer? _next;
  bool _between = false;

  @override
  void initState() {
    super.initState();
    _story = widget.storyAt(0);
  }

  @override
  void dispose() {
    _next?.cancel();
    super.dispose();
  }

  bool get _last => widget.length != null && _i >= widget.length! - 1;

  void _finished() {
    if (_last) return; // el último: se queda con la música para dormir
    setState(() => _between = true);
    _next = Timer(widget.gap, () {
      if (!mounted) return;
      final s = widget.storyAt(_i + 1);
      setState(() {
        _between = false;
        if (s != null) {
          _i++;
          _story = s;
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    if (story == null) {
      return const Scaffold(backgroundColor: Colors.black);
    }
    final page = widget.pageFor?.call(story, _last, _finished) ??
        AudioOnlyPage(
          key: ValueKey('queue-$_i'),
          story: story,
          onFinished: _finished,
          sleepMusic: _last,
        );
    return Stack(
      children: [
        KeyedSubtree(key: ValueKey('queue-page-$_i'), child: page),
        if (_between)
          Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: IgnorePointer(
              child: Text(
                'Ahora viene otro cuento…',
                key: const Key('queue-next'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(color: Palette.mutedText),
              ),
            ),
          ),
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          right: 16,
          child: IgnorePointer(
            child: Text(
              widget.length == null
                  ? widget.title
                  : '${widget.title} · ${_i + 1} de ${widget.length}',
              key: const Key('queue-title'),
              style: Theme.of(context)
                  .textTheme
                  .labelLarge!
                  .copyWith(color: Palette.mutedText.withValues(alpha: 0.7)),
            ),
          ),
        ),
      ],
    );
  }
}
