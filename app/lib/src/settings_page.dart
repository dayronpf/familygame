import 'dart:convert';

import 'package:caldero_engine/caldero_engine.dart';
import 'package:flutter/material.dart';

import 'feedback/feedback_service.dart';
import 'feedback/rating_event.dart';
import 'settings/app_settings.dart';
import 'shelf/story_shelf.dart';
import 'ui/children_page.dart';
import 'guide/holograma_guide.dart';
import 'share.dart';
import 'ui/voice_picker.dart';
import 'workshop_page.dart';
import 'brand.dart';
import 'legal/legal_page.dart';
import 'legal/my_data_page.dart';

/// Ajustes para adultos: permiso de valoraciones y transparencia total sobre qué se envía.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.feedback,
    this.bundle,
    this.shelf,
    this.agesWithStories = const {'6-8'},
  });

  final FeedbackService feedback;

  /// El estante de cuentos (para borrar los de un niño al quitarlo).
  final StoryShelf? shelf;

  /// Para abrir el Taller de personajes (herramienta de prueba).
  final AssetBundle? bundle;

  /// Edades para las que el pack tiene cuentos (si se elige otra, se avisa).
  final Set<String> agesWithStories;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool? _enabled;
  int _queued = 0;
  TextEditingController? _nameCtl;
  String? _nameFor;

  /// El campo del nombre conserva lo que se escribe aunque los ajustes se redibujen con cada letra; si se cambia de
  /// niño empieza uno nuevo con el nombre del otro.
  TextEditingController _nameController(String childId, String initial) {
    if (_nameFor != childId) {
      final old = _nameCtl;
      // el campo viejo aún está en pantalla durante este armado: se suelta después
      WidgetsBinding.instance.addPostFrameCallback((_) => old?.dispose());
      _nameCtl = TextEditingController(text: initial);
      _nameFor = childId;
    }
    return _nameCtl!;
  }

  @override
  void dispose() {
    _nameCtl?.dispose();
    super.dispose();
  }

  static final RatingEvent _example = RatingEvent(
    id: '3f2b8c1e-5a47-4d2e-9b0a-7c1d6e8f2a90',
    recipe: StoryRecipe(
      packId: 'medieval',
      packVersion: '1.0.0',
      engineVersion: engineVersion,
      seed: 482913,
      valueId: 'honestidad',
      cast: const {
        'hero': 'aldo',
        'helper': 'zafiro',
        'villain': 'codicio',
        'torre': 'castillo',
        'plaza': 'aldea',
        'item': 'campana',
      },
      fragmentIds: const [
        'campana.deseo.a',
        'campana.error.b',
        'campana.tentacion.a',
        'campana.escondite.a',
        'campana.ayuda.b',
        'campana.consejo.a',
        'campana.acusacion.a',
        'campana.verdad.b',
        'campana.consecuencia.a',
        'campana.cierre.b',
      ],
    ),
    rating: 5,
    day: '2026-10-08',
  );

  static final RatingEvent _exampleWithReasons = RatingEvent(
    id: '9c4d7e20-61b3-4f08-a2d5-1e8b3a6f7c42',
    recipe: StoryRecipe(
      packId: 'medieval',
      packVersion: '1.0.0',
      engineVersion: engineVersion,
      seed: 77120,
      valueId: 'valentia',
      cast: const {
        'hero': 'mara',
        'helper': 'bonifacio',
        'villain': 'sombra',
        'pueblo': 'aldea',
        'bosque': 'bosque',
        'item': 'linterna',
      },
      fragmentIds: const [
        'linterna.la_luz.b',
        'linterna.tormenta.a',
        'linterna.el_miedo.b',
        'linterna.el_paso.a',
        'linterna.el_bosque.a',
        'linterna.las_sombras.b',
        'linterna.el_roble.a',
        'linterna.la_chispa.b',
        'linterna.el_regreso.a',
        'linterna.cierre.b',
      ],
    ),
    rating: 2,
    day: '2026-10-08',
    reasons: const ['no_sense', 'repeated'],
  );

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final e = await widget.feedback.enabled;
    final q = await widget.feedback.queuedCount();
    if (!mounted) return;
    setState(() {
      _enabled = e;
      _queued = q;
    });
  }

  Future<void> _toggle(bool value) async {
    await widget.feedback.setEnabled(value);
    await _refresh();
    if (!mounted || value) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Listo. Se borró lo que esperaba para enviarse.')),
    );
  }

  /// Idioma, voz, edad, velocidad y música: lo mismo que pregunta el wizard. Se aplica al siguiente cuento.
  List<Widget> _storySettings(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final settings = SettingsScope.watch(context);
    if (settings == null) return const [];
    final child = settings.child;
    final profile = AgeProfile.byId(child.age)!;
    final hasStories = widget.agesWithStories.contains(child.age);
    return [
      ListTile(
        key: const Key('setting-children'),
        contentPadding: EdgeInsets.zero,
        leading: ChildAvatar(
            profile: child, index: settings.activeIndex, radius: 22),
        title: const Text('Niños'),
        subtitle: Text(settings.profiles.length == 1
            ? 'Solo ${child.label(0)}. Toca para añadir a otro niño.'
            : '${settings.profiles.length} niños · ahora: ${child.label(settings.activeIndex)}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                ChildrenPage(settings: settings, shelf: widget.shelf),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text('Cuentos y voz', style: text.titleMedium),
      const SizedBox(height: 4),
      Text('Los cambios valen desde el siguiente cuento.',
          style: text.bodySmall),
      const SizedBox(height: 12),
      Row(
        children: [
          const Icon(Icons.language),
          const SizedBox(width: 12),
          Expanded(child: Text('Idioma', style: text.bodyLarge)),
          DropdownButton<String>(
            key: const Key('setting-language'),
            value: child.language,
            items: [
              for (final l in supportedLanguages)
                DropdownMenuItem(value: l.code, child: Text(l.name)),
            ],
            onChanged: (v) {
              if (v != null) settings.updateChild(language: v);
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      Text('Voz del narrador', style: text.bodyLarge),
      const SizedBox(height: 8),
      VoicePicker(
        key: const Key('setting-voice'),
        services: SettingsScope.voicesOf(context),
        selected: child.voice,
        speed: child.voiceConfig.speed,
        onSelected: (o) => settings.updateChild(voice: o.voice),
      ),
      const SizedBox(height: 8),
      Text('Protagonista', style: text.bodyLarge),
      const SizedBox(height: 4),
      Text(
        'Si escribes el nombre del niño, será el héroe de sus cuentos. Se queda en este teléfono.',
        style: text.bodySmall,
      ),
      const SizedBox(height: 8),
      TextField(
        key: const Key('setting-name'),
        controller: _nameController(settings.child.id, settings.child.name),
        maxLength: maxChildNameLength,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          hintText: 'Nombre (opcional)',
          counterText: '',
          prefixIcon: Icon(Icons.edit_outlined),
        ),
        onChanged: (v) => settings.updateChild(name: v.trim()),
      ),
      const SizedBox(height: 10),
      SegmentedButton<String?>(
        key: const Key('setting-gender'),
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'm', label: Text('Niño')),
          ButtonSegment(value: 'f', label: Text('Niña')),
          ButtonSegment(value: null, label: Text('Al azar')),
        ],
        selected: {child.heroGender},
        onSelectionChanged: (v) => settings.updateChild(heroGender: v.first),
      ),
      const SizedBox(height: 16),
      Text('Edad del niño', style: text.bodyLarge),
      const SizedBox(height: 8),
      SegmentedButton<String>(
        key: const Key('setting-age'),
        showSelectedIcon: false,
        segments: [
          for (final p in AgeProfile.all)
            ButtonSegment(
                value: p.id, label: Text(p.label.replaceAll(' años', ''))),
        ],
        selected: {child.age},
        onSelectionChanged: (v) => settings.updateChild(age: v.first),
      ),
      const SizedBox(height: 6),
      Text(profile.blurb, style: text.bodySmall),
      if (!hasStories)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Por ahora todavía no hay cuentos de esta edad: te contamos los más cercanos.',
            key: const Key('setting-age-note'),
            style: text.bodySmall!
                .copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      if (child.age == '6-8' || child.age == '9-12')
        SwitchListTile(
          key: const Key('setting-questions'),
          contentPadding: EdgeInsets.zero,
          title: Text('Preguntas en el cuento', style: text.bodyLarge),
          subtitle: Text(
            child.asksQuestions
                ? 'En algunos cuentos el niño elige cómo sigue, entre 2 o 3 caminos. Si no contesta, elige la app.'
                : 'Apagado: la app elige el camino y el cuento no se detiene.',
            style: text.bodySmall,
          ),
          value: child.asksQuestions,
          onChanged: (v) => settings.updateChild(asksQuestions: v),
        ),
      const SizedBox(height: 16),
      Text('Velocidad de lectura', style: text.bodyLarge),
      const SizedBox(height: 8),
      SegmentedButton<ReadingSpeed>(
        key: const Key('setting-speed'),
        showSelectedIcon: false,
        segments: [
          for (final s in ReadingSpeed.values)
            ButtonSegment(value: s, label: Text(s.label)),
        ],
        selected: {child.speed},
        onSelectionChanged: (v) => settings.updateChild(speed: v.first),
      ),
      const SizedBox(height: 8),
      SwitchListTile(
        key: const Key('setting-music'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Música de fondo'),
        subtitle: const Text('Suena bajito mientras se cuenta el cuento.'),
        value: settings.music,
        onChanged: (v) => settings.setMusic(on: v),
      ),
      if (settings.music)
        Row(
          children: [
            const Icon(Icons.volume_down),
            Expanded(
              child: Slider(
                key: const Key('setting-music-volume'),
                value: settings.musicVolume.clamp(0.0, 0.6),
                max: 0.6,
                onChanged: (v) => settings.setMusic(volume: v),
              ),
            ),
            const Icon(Icons.volume_up),
          ],
        ),
      SwitchListTile(
        key: const Key('setting-effects'),
        contentPadding: EdgeInsets.zero,
        title: const Text('Efectos de sonido'),
        subtitle: const Text(
            'Un balido, un crujido, un chapoteo… suenan en los momentos del cuento en que se oyen.'),
        value: settings.effects,
        onChanged: settings.setEffects,
      ),
      ListTile(
        key: const Key('setting-downloads'),
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.offline_pin_outlined),
        title: const Text('Descargas'),
        subtitle: const Text(
            'Los cuentos ya están dentro de la app: funcionan sin internet.'),
      ),
    ];
  }

  void _openLegal(String title, String asset) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => LegalPage(title: title, asset: asset),
    ));
  }

  Future<Map<String, Object?>> _myData() async {
    final settings = SettingsScope.maybeOf(context);
    return {
      if (settings != null) 'ajustes': settings.exportJson(),
      if (widget.shelf != null) 'mis_cuentos': widget.shelf!.exportJson(),
      'valoraciones': await widget.feedback.exportJson(),
    };
  }

  void _openMyData() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MyDataPage(load: _myData),
    ));
  }

  /// Borra todo lo guardado en el teléfono (con confirmación) y vuelve al inicio, donde el asistente de
  /// bienvenida vuelve a salir.
  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        key: const Key('delete-dialog'),
        title: const Text('¿Borrar todo?'),
        content: const Text(
            'Se borrarán los perfiles de los niños, los cuentos guardados, los ajustes y las valoraciones que no se hayan enviado. No se puede deshacer.'),
        actions: [
          TextButton(
            key: const Key('delete-cancel'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('delete-confirm'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final settings = SettingsScope.maybeOf(context);
    final nav = Navigator.of(context);
    await settings?.resetAll();
    await widget.shelf?.clearAll();
    await widget.feedback.clearAll();
    if (!mounted) return;
    nav.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final enabled = _enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes para adultos')),
      body: SafeArea(
        child: enabled == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ..._storySettings(context),
                  const Divider(height: 32),
                  SwitchListTile(
                    key: const Key('feedback-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Ayudar a mejorar los cuentos'),
                    subtitle: const Text(
                        'Enviar la valoración (1 a 5) de forma anónima al terminar un cuento.'),
                    value: enabled,
                    onChanged: _toggle,
                  ),
                  if (enabled && _queued > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('Esperando para enviarse: $_queued',
                          style: text.bodySmall),
                    ),
                  const Divider(height: 32),
                  Text('Qué enviamos', style: text.titleMedium),
                  const SizedBox(height: 8),
                  const _Bullets(items: [
                    'La nota que dieron, de 1 a 5.',
                    'Si la nota es baja (3 o menos) y quieren contarlo, el motivo: se eligen entre cinco opciones («No tuvo sentido», «Se repitió», «Muy largo o muy corto», «Dio miedo», «No me gustó la enseñanza»). Nunca se envía texto escrito.',
                    'Qué cuento fue, solo con códigos: la enseñanza, los personajes, las partes que lo formaron y los caminos que eligió el niño. Con eso podemos mejorar las partes que no gustan.',
                    'El día (sin la hora) y la versión de la app.',
                  ]),
                  const SizedBox(height: 16),
                  Text('Qué NO enviamos', style: text.titleMedium),
                  const SizedBox(height: 8),
                  const _Bullets(items: [
                    'Nombres, edades, fotos, voz ni ubicación.',
                    'El texto del cuento.',
                    'Datos del teléfono, cuentas, ni identificadores de publicidad (no hay anuncios).',
                    'Nada que permita saber quién es su familia.',
                  ]),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    key: const Key('example-tile'),
                    tilePadding: EdgeInsets.zero,
                    title:
                        const Text('Ver un ejemplo exacto de lo que se envía'),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(_example.toJson()),
                          key: const Key('example-json'),
                          style:
                              text.bodySmall?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Con una nota baja y motivos elegidos:',
                            style: text.bodySmall),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ')
                              .convert(_exampleWithReasons.toJson()),
                          key: const Key('example-json-reasons'),
                          style:
                              text.bodySmall?.copyWith(fontFamily: 'monospace'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 32),
                  Text('Privacidad y datos', style: text.titleMedium),
                  const SizedBox(height: 4),
                  ListTile(
                    key: const Key('settings-privacy'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Política de privacidad'),
                    subtitle: const Text(
                        'Qué guarda la app, qué envía (solo si lo permiten) y para qué.'),
                    onTap: () => _openLegal('Política de privacidad',
                        'assets/legal/politica-de-privacidad.es.md'),
                  ),
                  ListTile(
                    key: const Key('settings-terms'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Términos de uso'),
                    onTap: () => _openLegal('Términos de uso',
                        'assets/legal/terminos-de-uso.es.md'),
                  ),
                  ListTile(
                    key: const Key('settings-my-data'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.fact_check_outlined),
                    title: const Text('Ver mis datos'),
                    subtitle: const Text(
                        'Todo lo que la app guarda en este teléfono, tal cual.'),
                    onTap: _openMyData,
                  ),
                  ListTile(
                    key: const Key('settings-delete-data'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline,
                        color: Theme.of(context).colorScheme.error),
                    title: const Text('Borrar los datos de este teléfono'),
                    subtitle: const Text(
                        'Perfiles, cuentos guardados, ajustes y valoraciones pendientes.'),
                    onTap: _confirmDelete,
                  ),
                  ListTile(
                    key: const Key('settings-licenses'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Licencias y créditos'),
                    subtitle: const Text(
                        'Sonidos de Kenney.nl y AntumDeluge (CC0) y componentes de código abierto.'),
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: appName,
                      applicationVersion: appVersion,
                      applicationLegalese:
                          'Cuentos, dibujos y música originales del proyecto. Efectos de sonido: grabaciones CC0 de Kenney.nl y de AntumDeluge (OpenGameArt) y sonidos sintetizados por el proyecto (CC0).',
                    ),
                  ),
                  const Divider(height: 32),
                  ListTile(
                    key: const Key('settings-share'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.ios_share),
                    title: const Text('Recomendar a un amigo'),
                    subtitle: const Text(
                        'Envía el enlace por WhatsApp, mensajes o correo.'),
                    onTap: () => shareApp(context),
                  ),
                  ListTile(
                    key: const Key('settings-guide'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.view_in_ar),
                    title: const Text('Holograma en casa (PDF)'),
                    subtitle: const Text(
                        'Instrucciones y plantilla para hacer la pirámide, en tamaño carta.'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            HologramGuidePage(bundle: widget.bundle),
                      ),
                    ),
                  ),
                  if (widget.bundle != null)
                    ListTile(
                      key: const Key('open-workshop'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.brush_outlined),
                      title: const Text('Taller de personajes (prueba)'),
                      subtitle: const Text(
                          'Herramienta para ver los dibujos y medir el rendimiento.'),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => WorkshopPage(bundle: widget.bundle!),
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text('$appName · versión $appVersion', style: text.bodySmall),
                ],
              ),
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(i)),
              ],
            ),
          ),
      ],
    );
  }
}
