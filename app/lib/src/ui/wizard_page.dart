import 'package:caldero_engine/caldero_engine.dart' show AgeProfile;
import 'package:flutter/material.dart';

import '../narration/narrator.dart';
import '../settings/app_settings.dart';
import 'night_background.dart';
import 'palette.dart';
import 'voice_picker.dart';
import 'voice_services.dart';

/// Wizard de primer uso (menos de un minuto): idioma, voz del narrador, edad del niño y un resumen. Solo sale la
/// primera vez; todo se cambia después en Ajustes. «Saltar» deja los valores por defecto: idioma del sistema,
/// primera voz y perfil 4–5.
class WizardPage extends StatefulWidget {
  const WizardPage({
    super.key,
    required this.settings,
    required this.voices,
    required this.agesWithStories,
    required this.onDone,
  });

  final AppSettings settings;
  final VoiceServices voices;

  /// Perfiles de edad para los que el pack tiene cuentos (el wizard avisa si se elige otro).
  final Set<String> agesWithStories;
  final VoidCallback onDone;

  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  static const int summaryStep = 3;
  int _step = 0;
  late String _language = widget.settings.child.language;
  TtsVoice? _voice;
  String? _voiceName;
  String _age = AgeProfile.defaultId;

  Future<void> _finish({required bool skipped}) async {
    await widget.settings.completeWizard(
      language: skipped ? resolveLanguage(_language) : _language,
      voice: skipped ? null : _voice,
      age: skipped ? AgeProfile.defaultId : _age,
    );
    widget.onDone();
  }

  void _go(int step) => setState(() => _step = step);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 48,
                      child: _step == 0
                          ? null
                          : IconButton(
                              key: const Key('wizard-back'),
                              tooltip: 'Atrás',
                              onPressed: () => _go(_step - 1),
                              icon: const Icon(Icons.arrow_back),
                            ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i <= summaryStep; i++)
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: i == _step ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i <= _step
                                    ? Palette.amber
                                    : Palette.cardSoft,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: _step == summaryStep
                          ? null
                          : TextButton(
                              key: const Key('wizard-skip'),
                              onPressed: () => _finish(skipped: true),
                              child: const Text('Saltar'),
                            ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _stepBody(text),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(TextTheme text) {
    switch (_step) {
      case 0:
        return _frame(
          text,
          icon: Icons.language,
          title: '¿En qué idioma les contamos los cuentos?',
          body: Column(
            children: [
              if (widget.settings.systemLanguageUnavailable)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Todavía no tenemos el idioma de tu teléfono. Por ahora los cuentos son en Español.',
                    key: const Key('language-unavailable'),
                    style: text.bodyMedium!.copyWith(color: Palette.amber),
                  ),
                ),
              for (final l in supportedLanguages)
                _ChoiceCard(
                  key: Key('language-${l.code}'),
                  title: l.name,
                  selected: _language == l.code,
                  onTap: () => setState(() => _language = l.code),
                ),
            ],
          ),
        );
      case 1:
        return _frame(
          text,
          icon: Icons.record_voice_over,
          title: '¿Quién les cuenta el cuento?',
          body: VoicePicker(
            services: widget.voices,
            selected: _voice,
            speed: AgeProfile.byId(_age)?.speed ?? 0.9,
            onSelected: (o) => setState(() {
              _voice = o.voice;
              _voiceName = o.name;
            }),
          ),
        );
      case 2:
        final have = widget.agesWithStories;
        final resolved = have.contains(_age)
            ? _age
            : (AgeProfile.byId(_age) == null ? _age : _nearest(have, _age));
        return _frame(
          text,
          icon: Icons.child_care,
          title: '¿Qué edad tiene el niño?',
          body: Column(
            children: [
              for (final p in AgeProfile.all)
                _ChoiceCard(
                  key: Key('age-${p.id}'),
                  title: p.label,
                  subtitle: p.blurb,
                  selected: _age == p.id,
                  onTap: () => setState(() => _age = p.id),
                ),
              if (!have.contains(_age))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Por ahora nuestros cuentos son para ${AgeProfile.byId(resolved)?.label ?? 'otras edades'}. '
                    'Los contaremos con la voz y el ritmo de su edad hasta que lleguen los suyos'
                    '${(AgeProfile.byId(_age)?.order ?? 0) < (AgeProfile.byId(resolved)?.order ?? 0) ? ', y algunos tienen sustos suaves: mejor leerlos juntos' : ''}.',
                    key: const Key('age-note'),
                    style: text.bodyMedium!.copyWith(color: Palette.amber),
                  ),
                ),
            ],
          ),
        );
      default:
        final age = AgeProfile.byId(_age);
        final lang = supportedLanguages.firstWhere(
          (l) => l.code == _language,
          orElse: () => supportedLanguages.first,
        );
        return _frame(
          text,
          icon: Icons.checklist,
          title: 'Todo listo',
          body: Column(
            children: [
              _SummaryRow(
                  icon: Icons.language, label: 'Idioma', value: lang.name),
              _SummaryRow(
                icon: Icons.record_voice_over,
                label: 'Voz',
                value: _voiceName ?? voiceFriendlyNames.first,
                key: const Key('summary-voice'),
              ),
              _SummaryRow(
                icon: Icons.child_care,
                label: 'Edad',
                value: age?.label ?? _age,
              ),
              const SizedBox(height: 8),
              Text(
                'Todo esto se puede cambiar después en Ajustes.',
                style: text.bodyMedium!.copyWith(color: Palette.mutedText),
              ),
            ],
          ),
        );
    }
  }

  String _nearest(Set<String> have, String wanted) {
    final want = AgeProfile.byId(wanted)!;
    final candidates = AgeProfile.all.where((p) => have.contains(p.id)).toList()
      ..sort((a, b) =>
          (a.order - want.order).abs().compareTo((b.order - want.order).abs()));
    return candidates.isEmpty ? wanted : candidates.first.id;
  }

  Widget _frame(
    TextTheme text, {
    required IconData icon,
    required String title,
    required Widget body,
  }) {
    final summary = _step == summaryStep;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            children: [
              Icon(icon, size: 44, color: Palette.amber),
              const SizedBox(height: 12),
              Text(
                title,
                style: text.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Palette.cream,
                ),
              ),
              const SizedBox(height: 20),
              body,
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
          child: summary
              ? Row(
                  children: [
                    // «Cambiar» toma el ancho de su palabra (nunca se parte en dos líneas); «Empezar» el resto
                    OutlinedButton(
                      key: const Key('wizard-change'),
                      onPressed: () => _go(0),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                      ),
                      child: const Text('Cambiar', softWrap: false),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        key: const Key('wizard-start'),
                        onPressed: () => _finish(skipped: false),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(56),
                        ),
                        child: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('Empezar', softWrap: false),
                        ),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: const Key('wizard-next'),
                    onPressed: () => _go(_step + 1),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Siguiente', softWrap: false),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = selected ? Palette.amberDark : Palette.cream;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        selected: selected,
        label: title,
        child: Material(
          color: selected ? Palette.amber : Palette.card,
          borderRadius: BorderRadius.circular(22),
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: text.titleLarge!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: fg,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: text.bodyMedium!.copyWith(color: fg),
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_circle : Icons.circle_outlined,
                    color: fg,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: Palette.amber),
          const SizedBox(width: 12),
          Text(label,
              style: text.titleMedium!.copyWith(color: Palette.mutedText)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: text.titleMedium!.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
