import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

/// Preguntas para conversar al terminar el cuento: tres, sobre su enseñanza, con el nombre del protagonista. Son
/// abiertas (no hay respuesta correcta) y sirven para que el adulto y el niño hablen un ratito antes de dormir.
/// Cambian de un cuento a otro (se eligen con la semilla), pero el mismo cuento siempre trae las mismas.
List<String> talkQuestions(Story story) {
  final hero = story.cast['hero'];
  final name = hero is Character ? hero.given : 'el protagonista';
  final pool = _questions[story.moral.id] ?? _general;
  final seed = story.recipe.seed.abs();
  final picked = <String>[];
  for (var i = 0; picked.length < 3 && i < pool.length; i++) {
    final q = pool[(seed + i * 3) % pool.length];
    if (!picked.contains(q)) picked.add(q);
  }
  // Siempre una pregunta sobre ellos mismos al final
  picked[picked.length - 1] = _aboutYou[seed % _aboutYou.length];
  return [for (final q in picked) q.replaceAll('{h}', name)];
}

const _general = [
  '¿Qué parte del cuento te gustó más?',
  '¿Qué crees que sintió {h} al final?',
  '¿Qué habrías hecho tú en el lugar de {h}?',
  '¿Cambiarías algo del final?',
];

const _aboutYou = [
  '¿Alguna vez te pasó algo parecido?',
  '¿Qué habrías hecho tú?',
  '¿A quién te recuerda {h}?',
  '¿Qué le dirías a {h} si lo conocieras?',
];

const Map<String, List<String>> _questions = {
  'honestidad': [
    '¿Por qué crees que a {h} le costó decir la verdad?',
    '¿Cómo se sintió {h} después de decir la verdad?',
    '¿Qué habría pasado si {h} hubiera seguido escondiéndolo?',
    '¿Es fácil decir la verdad cuando nos equivocamos?',
    '¿Quién ayudó a {h} a ser sincero?',
  ],
  'generosidad': [
    '¿Qué compartió {h} y por qué?',
    '¿Cómo se sintieron los demás cuando {h} compartió?',
    '¿Qué te gusta compartir a ti?',
    '¿Compartir nos deja con menos o con más?',
    '¿Hubo alguien que no quería compartir? ¿Qué le pasó?',
  ],
  'valentia': [
    '¿Qué le daba miedo a {h}?',
    '¿Qué hizo {h} para sentirse más valiente?',
    '¿Ser valiente es no tener miedo?',
    '¿Quién acompañó a {h} cuando tenía miedo?',
    '¿Qué haces tú cuando algo te da miedo?',
  ],
  'humildad': [
    '¿Por qué crees que {h} pidió ayuda?',
    '¿Qué aprendió {h} de los demás?',
    '¿Es bueno reconocer que no sabemos algo?',
    '¿Hubo alguien que presumía? ¿Qué le pasó?',
    '¿Quién te enseña cosas a ti?',
  ],
  'perseverancia': [
    '¿Qué le salió mal a {h} al principio?',
    '¿Por qué {h} no se rindió?',
    '¿Qué te ayuda a ti a seguir intentando?',
    '¿Qué cosa te costó mucho aprender?',
    '¿Qué habría pasado si {h} se hubiera rendido?',
  ],
  'amistad': [
    '¿Quién fue buen amigo de {h} en el cuento?',
    '¿Qué hicieron juntos que no podían hacer solos?',
    '¿Qué hace que alguien sea un buen amigo?',
    '¿Cómo se arreglaron cuando hubo un problema?',
    '¿Quiénes son tus amigos y qué te gusta hacer con ellos?',
  ],
};

/// La tarjeta «Para conversar» con las preguntas del cuento.
class TalkQuestionsCard extends StatelessWidget {
  const TalkQuestionsCard({super.key, required this.story});

  final Story story;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      key: const Key('talk-questions'),
      color: scheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.forum_outlined, color: scheme.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Para conversar',
                      style: text.labelLarge!.copyWith(color: scheme.primary)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final q in talkQuestions(story))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('•  ', style: text.bodyLarge),
                    Expanded(child: Text(q, style: text.bodyLarge)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
