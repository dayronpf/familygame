import 'dart:async';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'art/story_stage.dart';
import 'narration/narrator.dart';
import 'narration/playback.dart';
import 'player_support.dart';
import 'ui/palette.dart';

/// «Leemos juntos»: el adulto lee en voz alta (o lo leen entre todos) mientras el niño mira el dibujo. Texto grande en
/// colores de noche, una escena por página: se avanza con un deslizamiento o con un toque, sin que nada suene solo.
///
/// Con **turnos** la voz del teléfono lee una escena y le toca al adulto la siguiente, y así: cada uno lee sus
/// páginas y el cuento sigue sin que nadie tenga que leerlo entero.
class SharedReadingPage extends StatefulWidget {
  const SharedReadingPage({
    super.key,
    required this.story,
    this.art,
    this.setups = const [],
    this.narrator,
    this.animate = true,
    this.turns = false,
  });

  final Story story;
  final StageArt? art;
  final List<StageSetup?> setups;
  final Narrator? narrator;
  final bool animate;

  /// Si empieza con turnos entre la voz y el adulto.
  final bool turns;

  @override
  State<SharedReadingPage> createState() => _SharedReadingPageState();
}

class _SharedReadingPageState extends State<SharedReadingPage>
    with SingleTickerProviderStateMixin {
  late final StageClock _clock = StageClock(this);
  late final List<PlayScene> _scenes = playScenes(widget.story, widget.setups);
  late final Narrator _narrator = widget.narrator ?? narratorFor(context);
  final PageController _pages = PageController();
  late bool _turns = widget.turns;
  int _page = 0;
  int _sentence = -1;
  bool _reading = false;
  int _token = 0; // cada lectura nueva invalida a la anterior
  double _size = 26;

  static const double minSize = 20;
  static const double maxSize = 42;

  @override
  void initState() {
    super.initState();
    enterShowMode(immersive: false);
    if (_turns) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startTurn());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _clock.muted = !widget.animate || MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _token++;
    _narrator.stop();
    _pages.dispose();
    _clock.dispose();
    leaveShowMode();
    super.dispose();
  }

  /// Le toca a la voz en las páginas pares (la primera, la tercera…) cuando hay turnos.
  bool _voiceTurn(int page) => _turns && page.isEven;

  Future<void> _stopReading() async {
    _token++;
    if (_reading || _sentence >= 0) {
      setState(() {
        _reading = false;
        _sentence = -1;
      });
    }
    await _narrator.stop();
  }

  /// La voz lee la página [page] frase a frase (resaltando la que suena). Con [thenAdvance], al terminar pasa a la
  /// siguiente, que le toca al adulto.
  Future<void> _read(int page, {required bool thenAdvance}) async {
    final token = ++_token;
    await _narrator.stop();
    if (!mounted || token != _token) return;
    setState(() => _reading = true);
    final sc = _scenes[page];
    // el título se dice solo en la primera página
    if (page == 0 && widget.story.title != null) {
      await _narrator.speak(normalizeForVoice(widget.story.title!));
      if (!mounted || token != _token) return;
    }
    for (var i = 0; i < sc.sentences.length; i++) {
      setState(() => _sentence = i);
      final voice = normalizeForVoice(sc.sentences[i]);
      if (voice.isNotEmpty) await _narrator.speak(voice);
      if (!mounted || token != _token) return;
    }
    setState(() {
      _reading = false;
      _sentence = -1;
    });
    if (thenAdvance && page < _scenes.length - 1) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted || token != _token) return;
      _go(page + 1);
    }
  }

  void _startTurn() {
    if (_voiceTurn(_page)) _read(_page, thenAdvance: true);
  }

  void _go(int page) {
    _pages.animateToPage(
      page.clamp(0, _scenes.length - 1),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  void _onPage(int page) {
    setState(() => _page = page);
    _stopReading().then((_) {
      if (mounted && page == _page) _startTurn();
    });
  }

  void _toggleTurns() {
    setState(() => _turns = !_turns);
    _stopReading().then((_) {
      if (mounted) _startTurn();
    });
  }

  Widget _pageBody(int i, TextTheme text) {
    final sc = _scenes[i];
    final setup = sc.setup;
    final base = text.headlineSmall!.copyWith(
      fontSize: _size,
      height: 1.55,
      color: Palette.cream,
    );
    final current = i == _page ? _sentence : -1;
    final voiceTurn = _voiceTurn(i);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (i == 0 && widget.story.title != null) ...[
            Text(
              widget.story.title!,
              style: text.headlineMedium!
                  .copyWith(color: Palette.amber, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
          ],
          if (setup != null) ...[
            StoryStage(
              setup: setup,
              clock: _clock.value,
              art: widget.art,
              animate: widget.animate,
            ),
            const SizedBox(height: 16),
          ],
          if (sc.isMoral)
            Text('Enseñanza',
                style: text.labelLarge!.copyWith(color: Palette.amber)),
          Text.rich(
            TextSpan(children: [
              for (var s = 0; s < sc.sentences.length; s++)
                TextSpan(
                  text: s == sc.sentences.length - 1
                      ? sc.sentences[s]
                      : '${sc.sentences[s]} ',
                  style: base.copyWith(
                    color: current < 0 || s == current
                        ? base.color
                        : base.color!.withValues(alpha: 0.5),
                    fontWeight:
                        s == current ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
            ]),
            key: ValueKey('shared-text-$i'),
          ),
          if (_turns) ...[
            const SizedBox(height: 18),
            _TurnBanner(
              key: ValueKey('shared-turn-$i'),
              voice: voiceTurn,
              reading: voiceTurn && _reading && i == _page,
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final last = _scenes.length - 1;
    return Scaffold(
      backgroundColor: Palette.skyTop,
      appBar: AppBar(
        backgroundColor: Palette.skyTop,
        title: const Text('Leemos juntos'),
        actions: [
          IconButton(
            key: const Key('shared-text-smaller'),
            icon: const Icon(Icons.text_decrease),
            tooltip: 'Letra más pequeña',
            onPressed: _size <= minSize
                ? null
                : () =>
                    setState(() => _size = (_size - 3).clamp(minSize, maxSize)),
          ),
          IconButton(
            key: const Key('shared-text-bigger'),
            icon: const Icon(Icons.text_increase),
            tooltip: 'Letra más grande',
            onPressed: _size >= maxSize
                ? null
                : () =>
                    setState(() => _size = (_size + 3).clamp(minSize, maxSize)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const Key('shared-page-view'),
                controller: _pages,
                itemCount: _scenes.length,
                onPageChanged: _onPage,
                itemBuilder: (_, i) => _pageBody(i, text),
              ),
            ),
            LinearProgressIndicator(
              value: (_page + 1) / _scenes.length,
              minHeight: 3,
              backgroundColor: Colors.white12,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton(
                    key: const Key('shared-prev'),
                    icon: const Icon(Icons.chevron_left),
                    iconSize: 36,
                    color: Palette.cream,
                    tooltip: 'Escena anterior',
                    onPressed: _page == 0 ? null : () => _go(_page - 1),
                  ),
                  Expanded(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        Text(
                          '${_page + 1} de ${_scenes.length}',
                          style: text.bodyMedium!
                              .copyWith(color: Palette.mutedText),
                        ),
                        FilterChip(
                          key: const Key('shared-turns'),
                          label: const Text('Turnos con la voz'),
                          selected: _turns,
                          onSelected: (_) => _toggleTurns(),
                        ),
                        if (!_turns)
                          IconButton(
                            key: const Key('shared-listen'),
                            icon: Icon(_reading
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_outlined),
                            color: Palette.amber,
                            tooltip: _reading
                                ? 'Parar la voz'
                                : 'Escuchar esta escena',
                            onPressed: _reading
                                ? _stopReading
                                : () => _read(_page, thenAdvance: false),
                          ),
                      ],
                    ),
                  ),
                  if (_page >= last)
                    FilledButton.icon(
                      key: const Key('shared-done'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check),
                      label: const Text('Terminar'),
                    )
                  else
                    IconButton(
                      key: const Key('shared-next'),
                      icon: const Icon(Icons.chevron_right),
                      iconSize: 36,
                      color: Palette.cream,
                      tooltip: 'Escena siguiente',
                      onPressed: () => _go(_page + 1),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Escucha» (le toca a la voz) o «Te toca leer» (le toca al adulto).
class _TurnBanner extends StatelessWidget {
  const _TurnBanner({super.key, required this.voice, required this.reading});

  final bool voice;
  final bool reading;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: voice ? Palette.card : Palette.amber.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(voice ? Icons.record_voice_over : Icons.menu_book,
              color: voice ? Palette.teal : Palette.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              voice
                  ? (reading
                      ? 'Escuchamos esta escena…'
                      : 'Esta escena la lee la voz')
                  : 'Te toca leer esta escena en voz alta',
              style: text.titleMedium!.copyWith(color: Palette.cream),
            ),
          ),
        ],
      ),
    );
  }
}
