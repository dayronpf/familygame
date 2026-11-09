import 'package:flutter/material.dart';

import '../brand.dart';
import '../feedback/adult_gate.dart';
import '../legal/legal_page.dart';
import '../notifications/bedtime_reminder.dart';
import '../ui/night_background.dart';
import '../ui/palette.dart';
import '../ui/splash_page.dart';
import 'access.dart';
import 'purchases.dart';

/// Pone las compras al alcance del muro de pago (en las pruebas no hay tienda).
class PurchasesScope extends InheritedWidget {
  const PurchasesScope(
      {super.key, required this.purchases, required super.child});

  final PurchaseGateway? purchases;

  static PurchaseGateway? of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<PurchasesScope>()?.purchases;

  @override
  bool updateShouldNotify(PurchasesScope old) => old.purchases != purchases;
}

/// Abre el muro de pago, siempre detrás de la pregunta para adultos (nunca se le pide al niño que compre).
/// Devuelve `true` si al cerrar ya tiene todo abierto.
Future<bool> openPaywall(BuildContext context, {String? reason}) async {
  final access = AccessScope.read(context);
  if (access.premium) return true;
  if (!await askAdult(context) || !context.mounted) return false;
  final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PaywallPage(reason: reason),
  ));
  return ok == true || access.premium;
}

/// El muro de pago: qué incluye, la línea de tiempo honesta de la prueba (hoy / aviso el día 5 / cobro el día 7),
/// los planes con el precio real de la tienda, restaurar, canjear código y una ✕ siempre visible. Sin cuentas atrás.
class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key, this.reason, this.reminder});

  /// Por qué se abrió («Este cuento es de la suscripción»).
  final String? reason;
  final BedtimeReminder? reminder;

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  List<PlanOption>? _plans;
  String? _selected;
  PurchaseGateway? _purchases;
  bool _trialReminderSet = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final p = PurchasesScope.of(context);
    if (p != _purchases || _plans == null) {
      _purchases?.removeListener(_onPurchase);
      _purchases = p?..addListener(_onPurchase);
      _load();
    }
  }

  @override
  void dispose() {
    _purchases?.removeListener(_onPurchase);
    super.dispose();
  }

  Future<void> _load() async {
    final p = _purchases;
    if (p == null) {
      setState(() => _plans = const []);
      return;
    }
    try {
      final plans = await p.plans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _selected ??= plans.isEmpty ? null : plans.first.id;
      });
    } catch (_) {
      if (mounted) setState(() => _plans = const []);
    }
  }

  void _onPurchase() {
    if (!mounted) return;
    setState(() {});
    final access = AccessScope.read(context);
    if (_purchases?.state == PurchaseState.done && access.premium) {
      _remindTrialEnd(access.entitlement);
      Navigator.of(context).maybePop(true);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('¡Listo! Ya tienen todos los cuentos de $appName.')));
    }
  }

  /// Si empezó una prueba gratis, el aviso de que termina (dos días antes), como promete la pantalla.
  void _remindTrialEnd(Entitlement e) {
    if (_trialReminderSet || !e.trial || e.expiresAt == null) return;
    _trialReminderSet = true;
    final at = e.expiresAt!.toLocal().subtract(const Duration(days: 2));
    if (at.isAfter(DateTime.now())) {
      (widget.reminder ?? LocalBedtimeReminder())
          .trialEnding(at)
          .catchError((_) => false);
    }
  }

  void _legal(String title, String asset) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => LegalPage(title: title, asset: asset),
      ));

  Future<void> _redeem() async {
    final access = AccessScope.read(context);
    final messenger = ScaffoldMessenger.of(context);
    // En la versión de las tiendas se canjean los códigos de la tienda (Apple «offer codes», códigos promocionales de
    // Google Play): ni Apple ni Google permiten códigos propios que abran contenido de pago. Los códigos del servidor
    // quedan para las compilaciones de prueba.
    if (!access.devAvailable) {
      final handled = await _purchases?.redeemWithStore() ?? false;
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text(handled
              ? 'Cuando termines de canjear el código en la tienda, vuelve y toca «Restaurar compras».'
              : 'Los códigos se canjean en la tienda de tu teléfono.')));
      return;
    }
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.card,
        title: const Text('Canjear código'),
        content: TextField(
          key: const Key('redeem-field'),
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'MINI-XXXX-XXXX'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            key: const Key('redeem-ok'),
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Canjear'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty) return;
    final r = await access.redeem(code);
    if (!mounted) return;
    final text = switch (r.outcome) {
      StoreOutcome.ok => '¡Código canjeado! Ya tienen todos los cuentos.',
      StoreOutcome.invalid =>
        'Ese código no existe. Revisa que esté bien escrito.',
      StoreOutcome.used => 'Ese código ya se usó o caducó.',
      StoreOutcome.noServer =>
        'Esta versión no tiene servidor para canjear códigos.',
      StoreOutcome.unavailable => 'No pudimos conectar. Inténtalo más tarde.',
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
    if (r.outcome == StoreOutcome.ok) Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plans = _plans;
    final selected = plans?.where((p) => p.id == _selected).firstOrNull;
    final busy = switch (_purchases?.state) {
      PurchaseState.buying ||
      PurchaseState.verifying ||
      PurchaseState.loading =>
        true,
      _ => false,
    };
    final trial = selected?.trialDays ?? 7;
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
                children: [
                  SizedBox(
                    height: 190,
                    child: CustomPaint(
                      painter: StorybookPainter(intro: 1, t: 0.3),
                    ),
                  ),
                  Text('Todos los cuentos de $appName',
                      textAlign: TextAlign.center,
                      style: text.headlineSmall!
                          .copyWith(fontWeight: FontWeight.w800)),
                  if (widget.reason != null) ...[
                    const SizedBox(height: 6),
                    Text(widget.reason!,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge!.copyWith(color: Palette.amber)),
                  ],
                  const SizedBox(height: 18),
                  _Step(
                    icon: Icons.lock_open,
                    color: Palette.amber,
                    title: trial > 0
                        ? 'Hoy: prueba gratis'
                        : 'Hoy: acceso completo',
                    body:
                        'Todos los paquetes, crear cuentos nuevos cada noche y los que lleguen cada semana.',
                  ),
                  if (trial > 0) ...[
                    _Step(
                      icon: Icons.notifications_active,
                      color: Palette.teal,
                      title: 'Día ${trial - 2}: te avisamos',
                      body:
                          'Una notificación de que la prueba está por terminar. Cancela cuando quieras.',
                    ),
                    _Step(
                      icon: Icons.star,
                      color: const Color(0xFFFFA8D2),
                      title: 'Día $trial: empieza la suscripción',
                      body: 'Solo si no la cancelaste antes en Google Play.',
                      last: true,
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (plans == null)
                    const Center(child: CircularProgressIndicator())
                  else if (plans.isEmpty)
                    Container(
                      key: const Key('paywall-no-plans'),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: Palette.card,
                          borderRadius: BorderRadius.circular(18)),
                      child: Text(
                        'La suscripción aparecerá aquí cuando $appName esté publicada en Google Play. '
                        'Mientras tanto puedes canjear un código.',
                        textAlign: TextAlign.center,
                        style: text.bodyLarge,
                      ),
                    )
                  else
                    for (final p in plans)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _PlanCard(
                          plan: p,
                          selected: p.id == _selected,
                          onTap: () => setState(() => _selected = p.id),
                        ),
                      ),
                  const SizedBox(height: 8),
                  if (selected != null)
                    SizedBox(
                      height: 60,
                      child: FilledButton(
                        key: const Key('paywall-buy'),
                        onPressed:
                            busy ? null : () => _purchases?.buy(selected),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30)),
                          textStyle: text.titleLarge!
                              .copyWith(fontWeight: FontWeight.w800),
                        ),
                        child: busy
                            ? const CircularProgressIndicator()
                            : Text(selected.trialDays > 0
                                ? 'Probar ${selected.trialDays} días gratis'
                                : 'Suscribirme'),
                      ),
                    ),
                  if (_purchases?.message != null) ...[
                    const SizedBox(height: 10),
                    Text(_purchases!.message!,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium!.copyWith(color: Palette.amber)),
                  ],
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${selected.trialDays > 0 ? 'Gratis ${selected.trialDays} días; luego ' : ''}'
                      '${selected.price} ${selected.yearly ? 'al año' : 'al mes'}'
                      '${selected.monthlyEquivalent != null ? ' (${selected.monthlyEquivalent})' : ''}. '
                      'Se paga con tu cuenta de Google Play y se renueva sola hasta que la canceles en '
                      'Google Play › Pagos y suscripciones (al menos 24 horas antes de que termine el periodo).',
                      textAlign: TextAlign.center,
                      style: text.bodySmall!.copyWith(color: Palette.mutedText),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    children: [
                      // Las tiendas piden los términos y la privacidad a la vista donde se ofrece la suscripción
                      TextButton(
                        key: const Key('paywall-terms'),
                        onPressed: () => _legal('Términos de uso',
                            'assets/legal/terminos-de-uso.es.md'),
                        child: const Text('Términos de uso'),
                      ),
                      TextButton(
                        key: const Key('paywall-privacy'),
                        onPressed: () => _legal('Política de privacidad',
                            'assets/legal/politica-de-privacidad.es.md'),
                        child: const Text('Política de privacidad'),
                      ),
                      TextButton(
                        key: const Key('paywall-restore'),
                        onPressed: busy ? null : () => _purchases?.restore(),
                        child: const Text('Restaurar compras'),
                      ),
                      TextButton(
                        key: const Key('paywall-redeem'),
                        onPressed: busy ? null : _redeem,
                        child: const Text('Canjear código'),
                      ),
                    ],
                  ),
                ],
              ),
              Positioned(
                top: 4,
                right: 4,
                child: IconButton(
                  key: const Key('paywall-close'),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).maybePop(false),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    this.last = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color,
                child: Icon(icon, color: const Color(0xFF1B1233)),
              ),
              if (!last)
                Expanded(child: Container(width: 3, color: Palette.cardSoft)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: text.titleMedium!
                          .copyWith(fontWeight: FontWeight.w800)),
                  Text(body,
                      style:
                          text.bodyMedium!.copyWith(color: Palette.mutedText)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(
      {required this.plan, required this.selected, required this.onTap});

  final PlanOption plan;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      key: Key('plan-${plan.id}'),
      color: selected ? Palette.card : Palette.cardSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
            color: selected ? Palette.amber : Colors.transparent, width: 2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: Palette.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.yearly ? 'Anual' : 'Mensual',
                        style: text.titleMedium!
                            .copyWith(fontWeight: FontWeight.w800)),
                    if (plan.monthlyEquivalent != null)
                      Text(plan.monthlyEquivalent!,
                          style: text.bodySmall!
                              .copyWith(color: Palette.mutedText)),
                  ],
                ),
              ),
              Text(plan.price,
                  style:
                      text.titleMedium!.copyWith(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
