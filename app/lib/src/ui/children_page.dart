import 'package:caldero_engine/caldero_engine.dart'
    show AgeProfile, maxChildNameLength, normalizeChildName;
import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../shelf/story_shelf.dart';
import 'palette.dart';

/// Lo que se pide al añadir o editar a un niño.
class ChildDraft {
  const ChildDraft(
      {this.name = '', this.age = AgeProfile.defaultId, this.gender});

  final String name;
  final String age;

  /// `m`, `f` o `null` (lo decide el cuento).
  final String? gender;
}

/// Colores de las caritas de cada niño (se reparten por su lugar en la lista).
const List<Color> childColors = [
  Color(0xFFFF9F5A),
  Color(0xFF5DA9FF),
  Color(0xFFFF8FB1),
  Color(0xFF6FE3D0),
  Color(0xFFB48CFF),
  Color(0xFFFFC857),
];

/// Una carita redonda con la inicial del niño.
class ChildAvatar extends StatelessWidget {
  const ChildAvatar(
      {super.key,
      required this.profile,
      required this.index,
      this.radius = 22});

  final ChildProfile profile;
  final int index;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final name = profile.heroName;
    return CircleAvatar(
      radius: radius,
      backgroundColor: childColors[index % childColors.length],
      child: name == null
          ? Icon(Icons.child_care, color: Palette.amberDark, size: radius)
          : Text(
              name.characters.first.toUpperCase(),
              style: TextStyle(
                color: Palette.amberDark,
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.95,
              ),
            ),
    );
  }
}

/// «Niños»: quién escucha los cuentos en este teléfono. Cada niño tiene su nombre, su edad, su género de protagonista y
/// sus propios cuentos guardados; la voz, la velocidad y la música son del teléfono. El activo es el del inicio.
class ChildrenPage extends StatelessWidget {
  const ChildrenPage({super.key, required this.settings, this.shelf});

  final AppSettings settings;

  /// Para borrar lo que guardó un niño cuando se le quita.
  final StoryShelf? shelf;

  Future<void> _add(BuildContext context) async {
    final draft = await showChildDialog(context, title: 'Añadir un niño');
    if (draft == null) return;
    await settings.addChild(
      name: draft.name,
      age: draft.age,
      heroGender: draft.gender,
    );
  }

  Future<void> _edit(BuildContext context, int index) async {
    final p = settings.profiles[index];
    final draft = await showChildDialog(
      context,
      title: 'Editar a ${p.label(index)}',
      initial: ChildDraft(name: p.name, age: p.age, gender: p.heroGender),
    );
    if (draft == null) return;
    await settings.updateProfile(
      index,
      name: draft.name,
      age: draft.age,
      heroGender: draft.gender,
    );
  }

  Future<void> _remove(BuildContext context, int index) async {
    final p = settings.profiles[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Quitar a ${p.label(index)}?'),
        content: const Text(
            'También se borran los cuentos que guardó. Esto no se puede deshacer.'),
        actions: [
          TextButton(
            key: const Key('child-remove-cancel'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('child-remove-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final id = await settings.removeChild(index);
    if (id != null) await shelf?.removeChild(id);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final kids = settings.profiles;
        return Scaffold(
          appBar: AppBar(title: const Text('Niños')),
          floatingActionButton: kids.length >= AppSettings.maxChildren
              ? null
              : FloatingActionButton.extended(
                  key: const Key('child-add'),
                  onPressed: () => _add(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir niño'),
                ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                Text(
                  'Toca a un niño para que los cuentos sean para él. La voz, la velocidad y la música son del teléfono.',
                  style: text.bodyMedium!.copyWith(color: Palette.mutedText),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < kids.length; i++)
                  _ChildTile(
                    key: ValueKey('child-${kids[i].id}'),
                    profile: kids[i],
                    index: i,
                    active: i == settings.activeIndex,
                    canRemove: kids.length > 1,
                    onTap: () => settings.selectChild(i),
                    onEdit: () => _edit(context, i),
                    onRemove: () => _remove(context, i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ChildTile extends StatelessWidget {
  const _ChildTile({
    super.key,
    required this.profile,
    required this.index,
    required this.active,
    required this.canRemove,
    required this.onTap,
    required this.onEdit,
    required this.onRemove,
  });

  final ChildProfile profile;
  final int index;
  final bool active;
  final bool canRemove;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final age = AgeProfile.byId(profile.age)?.label ?? profile.age;
    final hero = switch (profile.heroGender) {
      'm' => 'protagonista niño',
      'f' => 'protagonista niña',
      _ => 'protagonista al azar',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: active ? Palette.amber.withValues(alpha: 0.18) : Palette.card,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
            child: Row(
              children: [
                ChildAvatar(profile: profile, index: index, radius: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile.label(index),
                        style: text.titleLarge!
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text('$age · $hero',
                          style: text.bodyMedium!
                              .copyWith(color: Palette.mutedText)),
                    ],
                  ),
                ),
                if (active)
                  const Icon(Icons.check_circle, color: Palette.amber),
                PopupMenuButton<String>(
                  key: Key('child-menu-${profile.id}'),
                  tooltip: 'Más',
                  onSelected: (v) => v == 'edit' ? onEdit() : onRemove(),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    if (canRemove)
                      const PopupMenuItem(
                          value: 'remove', child: Text('Quitar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pide el nombre (opcional), la edad y si el protagonista es niño o niña. Devuelve `null` si se cancela.
Future<ChildDraft?> showChildDialog(
  BuildContext context, {
  required String title,
  ChildDraft initial = const ChildDraft(),
}) {
  return showDialog<ChildDraft>(
    context: context,
    builder: (context) => _ChildDialog(title: title, initial: initial),
  );
}

class _ChildDialog extends StatefulWidget {
  const _ChildDialog({required this.title, required this.initial});

  final String title;
  final ChildDraft initial;

  @override
  State<_ChildDialog> createState() => _ChildDialogState();
}

class _ChildDialogState extends State<_ChildDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial.name);
  late String _age = widget.initial.age;
  late String? _gender = widget.initial.gender;

  bool get _named => normalizeChildName(_name.text) != null;

  bool get _missingGender => _named && _gender == null;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const Key('child-name'),
              controller: _name,
              maxLength: maxChildNameLength,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre (opcional)',
                counterText: '',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            Text('Edad', style: text.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final p in AgeProfile.all)
                  ChoiceChip(
                    key: Key('child-age-${p.id}'),
                    label: Text(p.label.replaceAll(' años', '')),
                    selected: _age == p.id,
                    onSelected: (_) => setState(() => _age = p.id),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text('Protagonista', style: text.labelLarge),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                ChoiceChip(
                  key: const Key('child-gender-m'),
                  label: const Text('Niño'),
                  selected: _gender == 'm',
                  onSelected: (_) => setState(() => _gender = 'm'),
                ),
                ChoiceChip(
                  key: const Key('child-gender-f'),
                  label: const Text('Niña'),
                  selected: _gender == 'f',
                  onSelected: (_) => setState(() => _gender = 'f'),
                ),
                // Con su nombre el cuento no puede elegir al azar (el dibujo y el «solo/sola» le seguirían)
                if (!_named)
                  ChoiceChip(
                    key: const Key('child-gender-any'),
                    label: const Text('Al azar'),
                    selected: _gender == null,
                    onSelected: (_) => setState(() => _gender = null),
                  ),
              ],
            ),
            if (_missingGender)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Con su nombre, elige niño o niña.',
                  key: const Key('child-gender-needed'),
                  style: text.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const Key('child-cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('child-save'),
          onPressed: _missingGender
              ? null
              : () => Navigator.pop(
                    context,
                    ChildDraft(
                      name: normalizeChildName(_name.text) ?? '',
                      age: _age,
                      gender: _gender,
                    ),
                  ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
