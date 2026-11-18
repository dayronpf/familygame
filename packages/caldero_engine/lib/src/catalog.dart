import 'engine.dart';
import 'models.dart';

/// Versión del formato de contenido que entiende este motor (paquetes, catálogo fijo y manifiesto de voz). El
/// contenido que llega del servidor (docs/34) dice en `indice.json` qué versión necesita (`motor`): si es mayor que
/// esta, la app no lo baja y sigue con lo que tiene. **Sube solo cuando cambia el formato** de forma que una app vieja
/// ya no lo entendería (un esquema de pack nuevo, una capacidad nueva en `features`…). `tools/content/publish.py` la
/// lee de aquí.
const int contentEngineVersion = 1;

/// Un cuento del catálogo fijo (docs/31, `content/catalogo/<nombre>.json`): una premisa de un paquete contada
/// siempre igual, para que el texto coincida letra por letra con la voz grabada. Es la **única** fuente de las
/// opciones con que se cuenta: la usan la herramienta que saca los textos para grabar (`bin/catalog_texts.dart`) y
/// la app.
class CatalogEntry {
  const CatalogEntry({
    required this.packId,
    required this.premiseId,
    required this.seed,
    this.title,
    this.age,
    this.valueId,
    this.heroName,
    this.heroGender,
    this.since,
    this.isNew = false,
  });

  /// Lee una entrada de la lista `cuentos` del catálogo. Con [catalogVersion], la entrada es nueva si entró en esa
  /// versión (`desde`).
  factory CatalogEntry.fromJson(
    Map<String, Object?> j, {
    String? catalogVersion,
  }) {
    final id = j['id']! as String;
    final parts = id.split(':');
    if (parts.length != 2 || parts.any((p) => p.isEmpty)) {
      throw FormatException('id de cuento del catálogo inválido: «$id»');
    }
    return CatalogEntry(
      packId: parts[0],
      premiseId: parts[1],
      seed: (j['semilla']! as num).toInt(),
      title: j['titulo'] as String?,
      age: j['edad'] as String?,
      valueId: j['valor'] as String?,
      heroName: j['heroe'] as String?,
      heroGender: j['generoHeroe'] as String?,
      since: j['desde'] as String?,
      isNew: catalogVersion != null &&
          catalogVersion.isNotEmpty &&
          j['desde'] == catalogVersion,
    );
  }

  final String packId;
  final String premiseId;
  final int seed;

  /// Datos informativos del catálogo (para revisarlo): no cambian el cuento.
  final String? title, age, valueId;

  /// Nombre que debe salir para el héroe (sirve para comprobar que el texto no cambió de héroe).
  final String? heroName;

  /// `m` o `f`: el género del héroe con que se grabó.
  final String? heroGender;

  /// Versión del catálogo en que entró el cuento (`desde`; `null` = desde el principio).
  final String? since;

  /// Entró en la versión actual del catálogo: lleva la insignia «Nuevo» (docs/34).
  final bool isNew;

  /// «paquete:premisa», la clave del cuento en el catálogo y en el manifiesto de la voz grabada.
  String get id => '$packId:$premiseId';

  /// Las opciones exactas con que se graba y se cuenta: su semilla, su premisa y el género del héroe; sin el
  /// nombre del niño, sin edad y sin preguntas.
  StoryOptions options() => StoryOptions(
        seed: seed,
        premiseId: premiseId,
        heroGender: heroGender,
        interactive: false,
      );

  /// El héroe con que salió [story] (`null` si no tiene).
  static String? heroOf(Story story) {
    final hero = story.cast['hero'];
    return hero is Character ? hero.given : null;
  }
}

/// El catálogo fijo de cuentos de un idioma (`content/catalogo/lanzamiento-es.json`).
class FixedCatalog {
  FixedCatalog({
    required this.version,
    required this.language,
    required this.entries,
    this.free = const [],
  }) : _byId = {for (final e in entries) e.id: e};

  factory FixedCatalog.fromJson(Map<String, Object?> j) {
    final version = j['version'] as String? ?? '';
    return FixedCatalog(
      version: version,
      language: j['idioma'] as String? ?? 'es',
      free: [
        for (final f in (j['gratis'] as List<Object?>? ?? const []))
          f! as String,
      ],
      entries: [
        for (final e in (j['cuentos'] as List<Object?>? ?? const []))
          CatalogEntry.fromJson(
            e! as Map<String, Object?>,
            catalogVersion: version,
          ),
      ],
    );
  }

  static final FixedCatalog empty =
      FixedCatalog(version: '', language: 'es', entries: const []);

  final String version;
  final String language;

  /// Los cuentos, en el orden del catálogo.
  final List<CatalogEntry> entries;

  /// Ids («paquete:premisa») de los cuentos gratis.
  final List<String> free;

  bool get isEmpty => entries.isEmpty;

  final Map<String, CatalogEntry> _byId;

  /// La entrada de «paquete:premisa», o `null` si no está en el catálogo.
  CatalogEntry? byId(String id) => _byId[id];

  CatalogEntry? entryFor(String packId, String premiseId) =>
      _byId['$packId:$premiseId'];

  bool contains(String id) => _byId.containsKey(id);

  /// Ids de los cuentos que entraron en esta versión (los que llevan «Nuevo»).
  List<String> get newIds => [
        for (final e in entries)
          if (e.isNew) e.id,
      ];
}

/// Compara dos versiones con puntos («1.10» > «1.9»): negativo si [a] es menor, 0 si son iguales, positivo si es
/// mayor. Lo que no es número cuenta como 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) =>
      [for (final p in v.split('.')) int.tryParse(p.trim()) ?? 0];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final c = (i < x.length ? x[i] : 0).compareTo(i < y.length ? y[i] : 0);
    if (c != 0) return c;
  }
  return 0;
}
