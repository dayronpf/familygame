import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart'
    show AgeProfile, normalizeChildName;
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../narration/narrator.dart';
import '../ui/voice_services.dart';

/// Un idioma de la app. Cada idioma es una versión propia de los cuentos (no una traducción leída por otra voz),
/// así que solo se ofrecen los que tienen cuentos: hoy, español.
class AppLanguage {
  const AppLanguage(this.code, this.name);

  final String code;

  /// Su nombre en ese idioma («Español», «English»…).
  final String name;
}

const List<AppLanguage> supportedLanguages = [AppLanguage('es', 'Español')];

/// Idioma que se usará dado el del sistema: el mismo si hay cuentos en él y, si no, el primero disponible.
String resolveLanguage(String system) => supportedLanguages
    .firstWhere((l) => l.code == system, orElse: () => supportedLanguages.first)
    .code;

/// Velocidad de lectura que elige la familia; se aplica **sobre** la del perfil de edad.
enum ReadingSpeed {
  slow('Lenta', 0.85),
  normal('Normal', 1.0),
  fast('Rápida', 1.15);

  const ReadingSpeed(this.label, this.factor);

  final String label;
  final double factor;

  static ReadingSpeed byName(String? name) => ReadingSpeed.values
      .firstWhere((s) => s.name == name, orElse: () => ReadingSpeed.normal);
}

/// Un niño: edad, idioma, voz y velocidad. La primera versión muestra uno solo, pero el modelo ya guarda una lista
/// para poder tener varios por cuenta.
class ChildProfile {
  const ChildProfile({
    this.id = 'principal',
    this.name = '',
    this.age = AgeProfile.defaultId,
    this.language = 'es',
    this.voice,
    this.speed = ReadingSpeed.normal,
    this.heroGender,
    this.asksQuestions = true,
  });

  factory ChildProfile.fromJson(Map<String, Object?> j) => ChildProfile(
        id: (j['id'] as String?) ?? 'principal',
        name: (j['nombre'] as String?) ?? '',
        age: AgeProfile.byId(j['edad'] as String?)?.id ?? AgeProfile.defaultId,
        language: resolveLanguage((j['idioma'] as String?) ?? 'es'),
        voice: j['voz'] == null
            ? null
            : TtsVoice(
                name: j['voz']! as String,
                locale: (j['voz_idioma'] as String?) ?? 'es',
              ),
        speed: ReadingSpeed.byName(j['velocidad'] as String?),
        heroGender: switch (j['genero']) {
          'm' => 'm',
          'f' => 'f',
          _ => null,
        },
        asksQuestions: j['preguntas'] != false,
      );

  final String id;

  /// Cómo se llama el niño (puede estar vacío). Si se escribe, es el protagonista de sus cuentos; solo vive en el
  /// teléfono: nunca viaja con la valoración.
  final String name;

  /// `m` o `f`: el protagonista de los cuentos es un niño o una niña. `null` = lo decide la semilla.
  final String? heroGender;

  /// Si en los cuentos con camino elegible se le pregunta al niño (por defecto sí). Apagado: elige la app.
  final bool asksQuestions;

  /// Id del perfil de edad (`2-3`, `4-5`, `6-8`, `9-12`).
  final String age;
  final String language;

  /// `null` = la primera voz del teléfono en ese idioma.
  final TtsVoice? voice;
  final ReadingSpeed speed;

  ChildProfile copyWith({
    String? name,
    String? age,
    String? language,
    Object? voice = _keep,
    ReadingSpeed? speed,
    Object? heroGender = _keep,
    bool? asksQuestions,
  }) =>
      ChildProfile(
        asksQuestions: asksQuestions ?? this.asksQuestions,
        id: id,
        name: name ?? this.name,
        age: age ?? this.age,
        language: language ?? this.language,
        voice: identical(voice, _keep) ? this.voice : voice as TtsVoice?,
        speed: speed ?? this.speed,
        heroGender: identical(heroGender, _keep)
            ? this.heroGender
            : heroGender as String?,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'nombre': name,
        'edad': age,
        'idioma': language,
        'voz': voice?.name,
        'voz_idioma': voice?.locale,
        'velocidad': speed.name,
        'genero': heroGender,
        if (!asksQuestions) 'preguntas': false,
      };

  /// Nombre listo para el cuento (recortado y sin símbolos), o `null` si no hay.
  String? get heroName => normalizeChildName(name);

  /// Cómo se llama en las listas: su nombre o, si no lo tiene, «Niño 2» (según su lugar).
  String label(int index) => heroName ?? 'Niño ${index + 1}';

  /// Cómo suena el narrador para este niño: velocidad del perfil de edad × la lectura que eligió la familia.
  VoiceConfig get voiceConfig => VoiceConfig(
        voice: voice,
        speed: (AgeProfile.byId(age)?.speed ?? 0.9) * speed.factor,
      );

  static const Object _keep = Object();
}

/// Dónde se guardan los ajustes (solo en el teléfono).
abstract class SettingsStore {
  Future<String?> read();
  Future<void> write(String json);
}

class MemorySettingsStore implements SettingsStore {
  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String json) async => value = json;
}

class PrefsSettingsStore implements SettingsStore {
  PrefsSettingsStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'settings.v1';

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String json) => _prefs.setString(_key, json);
}

/// Ajustes de la familia: lo que pregunta el wizard y lo que se cambia después en Ajustes. Se leen al empezar
/// cada cuento, así que un cambio vale para el siguiente sin reiniciar la app.
class AppSettings extends ChangeNotifier {
  AppSettings(this._store, {String systemLanguage = 'es'})
      : _systemLanguage = systemLanguage,
        _profiles = [ChildProfile(language: resolveLanguage(systemLanguage))];

  final SettingsStore _store;
  final String _systemLanguage;

  List<ChildProfile> _profiles;
  int _active = 0;
  bool _wizardDone = false;
  bool _music = true;
  double _musicVolume = 0.22;
  bool _loaded = false;

  /// Si el idioma del sistema no está entre los disponibles (el wizard avisa).
  bool get systemLanguageUnavailable =>
      !supportedLanguages.any((l) => l.code == _systemLanguage);

  /// `wizard_completado`: el wizard sale solo la primera vez que se abre la app.
  bool get wizardDone => _wizardDone;
  List<ChildProfile> get profiles => List.unmodifiable(_profiles);
  ChildProfile get child => _profiles[_active];
  bool get music => _music;

  /// Volumen del sonido de fondo (0–1); bajito para que mande la voz.
  double get musicVolume => _musicVolume;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _store.read();
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, Object?>;
        _wizardDone = j['wizard_completado'] == true;
        _music = j['musica'] != false;
        _musicVolume =
            ((j['volumen_musica'] as num?) ?? 0.22).toDouble().clamp(0.0, 1.0);
        final list = [
          for (final p in (j['perfiles'] as List<Object?>? ?? const []))
            ChildProfile.fromJson(p! as Map<String, Object?>),
        ];
        if (list.isNotEmpty) {
          _profiles = list;
          _active =
              ((j['activo'] as num?) ?? 0).toInt().clamp(0, list.length - 1);
        }
      }
    } catch (_) {
      // Ajustes ilegibles: se empieza de cero (el wizard vuelve a salir).
    }
    notifyListeners();
  }

  /// Cambia al niño activo (el de siempre: Ajustes y el inicio hablan de él).
  Future<void> updateChild({
    String? age,
    String? language,
    Object? voice = ChildProfile._keep,
    ReadingSpeed? speed,
    String? name,
    Object? heroGender = ChildProfile._keep,
    bool? asksQuestions,
  }) =>
      updateProfile(
        _active,
        asksQuestions: asksQuestions,
        age: age,
        language: language,
        voice: voice,
        speed: speed,
        name: name,
        heroGender: heroGender,
      );

  /// Cambia a cualquier niño de la lista.
  Future<void> updateProfile(
    int index, {
    String? age,
    String? language,
    Object? voice = ChildProfile._keep,
    ReadingSpeed? speed,
    String? name,
    Object? heroGender = ChildProfile._keep,
    bool? asksQuestions,
  }) {
    if (index < 0 || index >= _profiles.length) return Future.value();
    _profiles = [..._profiles]..[index] = _profiles[index].copyWith(
        age: age,
        language: language,
        voice: voice,
        speed: speed,
        name: name,
        heroGender: heroGender,
        asksQuestions: asksQuestions,
      );
    notifyListeners();
    return _save();
  }

  /// Qué niño está activo (la lista se guarda con el orden en que se añadieron).
  int get activeIndex => _active;

  /// Cuántos niños se pueden tener (el teléfono es de una familia, no de una escuela).
  static const int maxChildren = 6;

  /// Añade un niño y lo deja activo. Hereda el idioma, la voz y la velocidad del activo: lo que se escucha es del
  /// teléfono, no del niño. Devuelve su lugar en la lista, o `null` si ya no caben más.
  Future<int?> addChild(
      {String name = '', String? age, String? heroGender}) async {
    if (_profiles.length >= maxChildren) return null;
    final base = child;
    final id = 'nino-${DateTime.now().microsecondsSinceEpoch}';
    _profiles = [
      ..._profiles,
      ChildProfile(
        id: id,
        name: name,
        age: age ?? base.age,
        language: base.language,
        voice: base.voice,
        speed: base.speed,
        heroGender: heroGender,
      ),
    ];
    _active = _profiles.length - 1;
    notifyListeners();
    await _save();
    return _active;
  }

  /// Pasa al niño de [index].
  Future<void> selectChild(int index) {
    if (index < 0 || index >= _profiles.length || index == _active) {
      return Future.value();
    }
    _active = index;
    notifyListeners();
    return _save();
  }

  /// Quita a un niño (siempre queda al menos uno). Devuelve su id para que se limpie lo que guardó, o `null`.
  Future<String?> removeChild(int index) async {
    if (_profiles.length <= 1 || index < 0 || index >= _profiles.length) {
      return null;
    }
    final gone = _profiles[index];
    _profiles = [..._profiles]..removeAt(index);
    if (index < _active) {
      _active--;
    } else if (_active >= _profiles.length) {
      _active = _profiles.length - 1;
    }
    notifyListeners();
    await _save();
    return gone.id;
  }

  Future<void> setMusic({bool? on, double? volume}) {
    if (on != null) _music = on;
    if (volume != null) _musicVolume = volume.clamp(0.0, 1.0);
    notifyListeners();
    return _save();
  }

  /// El wizard terminó (o se saltó): se anotan las elecciones y no vuelve a salir.
  Future<void> completeWizard({
    String? language,
    TtsVoice? voice,
    String? age,
    String? name,
    String? heroGender,
  }) {
    _wizardDone = true;
    _profiles = [..._profiles]..[_active] = child.copyWith(
        language: language,
        voice: voice,
        age: age,
        name: name,
        heroGender: heroGender,
      );
    notifyListeners();
    return _save();
  }

  Future<void> _save() => _store.write(jsonEncode({
        'wizard_completado': _wizardDone,
        'musica': _music,
        'volumen_musica': _musicVolume,
        'activo': _active,
        'perfiles': [for (final p in _profiles) p.toJson()],
      }));
}

/// Pone los ajustes (y cómo se crean las voces) al alcance de cualquier pantalla: el cine, el holograma y el
/// wizard los leen al abrirse.
class SettingsScope extends InheritedNotifier<AppSettings> {
  const SettingsScope({
    super.key,
    required AppSettings settings,
    this.voices = const VoiceServices(),
    required super.child,
  }) : super(notifier: settings);

  final VoiceServices voices;

  static AppSettings? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier;

  static VoiceServices voicesOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<SettingsScope>()?.voices ??
      const VoiceServices();

  /// Escucha los cambios (para pantallas que se redibujan con ellos).
  static AppSettings? watch(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsScope>()?.notifier;
}
