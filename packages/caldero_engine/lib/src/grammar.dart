import 'models.dart';

/// Un token de plantilla no se pudo resolver.
class TemplateException implements Exception {
  TemplateException(this.message);

  final String message;

  @override
  String toString() => 'TemplateException: $message';
}

final RegExp _token = RegExp(r'\{(\w+)(?:\.(\w+))?\}');

/// Pone en mayúscula la primera letra.
String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Formas gramaticales de una entidad (género, artículos y contracciones).
Map<String?, String> grammaticalForms(Entity e) {
  final masculine = e.gender == Gender.m;
  final art = masculine ? 'el' : 'la';
  final indef = masculine ? 'un' : 'una';
  final noun = e.noun;
  final forms = <String?, String>{
    null: e is Character ? e.given : noun,
    'noun': noun,
    'el': '$art $noun',
    'un': '$indef $noun',
    'del': masculine ? 'del $noun' : 'de la $noun',
    'al': masculine ? 'al $noun' : 'a la $noun',
    'en': 'en $art $noun',
    'o': masculine ? 'o' : 'a',
  };
  if (e is Character) {
    forms['trait'] = e.trait[masculine ? 'm' : 'f']!;
    // `{rol.gesto}`, `{rol.miedo}`… (frases propias del personaje); aquí, la primera forma.
    for (final a in e.attrs.entries) {
      forms[a.key] = a.value.first;
    }
  }
  for (final k in ['el', 'un', 'en']) {
    forms[capitalize(k)] = capitalize(forms[k]!);
  }
  return forms;
}

/// Elige una de las formas de un atributo con varias (`clave` = `rol.atributo`).
typedef AttrChooser = String Function(String key, List<String> options);

/// Sustituye los tokens de [template] con el [cast] dado. Si un atributo del personaje tiene varias
/// formas, [choose] decide cuál (sin él, la primera).
String renderTemplate(
  String template,
  Map<String, Entity> cast, {
  AttrChooser? choose,
}) {
  return template.replaceAllMapped(_token, (m) {
    final role = m.group(1)!;
    final attr = m.group(2);
    final entity = cast[role];
    if (entity == null) {
      throw TemplateException(
        'rol desconocido «$role» en: ${_excerpt(template)}',
      );
    }
    var value = grammaticalForms(entity)[attr];
    if (entity is Character && attr != null) {
      final options = entity.attrs[attr];
      if (options != null && options.length > 1 && choose != null) {
        value = choose('$role.$attr', options);
      }
    }
    if (value == null) {
      throw TemplateException(
        'la forma «$role.$attr» no existe para ${entity.id}',
      );
    }
    return value;
  });
}

String _excerpt(String s) => s.length <= 50 ? s : '${s.substring(0, 50)}…';
