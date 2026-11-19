import 'package:flutter/material.dart';

import '../brand.dart';
import '../ui/night_background.dart';
import '../ui/palette.dart';
import '../ui/splash_page.dart';
import 'access.dart';
import 'paywall_page.dart';
import 'purchases.dart';

/// La oferta que sale una sola vez, al terminar el asistente: qué trae la suscripción y la prueba gratis. Todo cabe en
/// la pantalla sin desplazar, con una ✕ pequeña arriba y un «Ahora no» debajo del botón (se entra a los cuentos
/// gratis sin pagar nada).
///
/// Aquí no se compra: «Probar gratis» abre el muro de pago, y la compra la autoriza la tienda. Si la tienda no tiene
/// planes (versión de pruebas, sin conexión), no se ofrece nada y se pasa directo al inicio.
class TrialOfferPage extends StatefulWidget {
  const TrialOfferPage({super.key, required this.onClose});

  /// Se llama al terminar, haya suscripción o no.
  final VoidCallback onClose;

  @override
  State<TrialOfferPage> createState() => _TrialOfferPageState();
}

class _TrialOfferPageState extends State<TrialOfferPage>
    with SingleTickerProviderStateMixin {
  List<PlanOption>? _plans;
  bool _closed = false;
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _in.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final p = PurchasesScope.of(context);
    List<PlanOption> plans;
    try {
      plans = p == null ? const [] : await p.plans();
    } catch (_) {
      plans = const [];
    }
    if (!mounted) return;
    if (plans.isEmpty || AccessScope.read(context).premium) {
      _close();
      return;
    }
    setState(() => _plans = plans);
    if (MediaQuery.of(context).disableAnimations) {
      _in.value = 1;
    } else {
      _in.forward();
    }
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    widget.onClose();
  }

  Future<void> _try() async {
    await openPaywall(context);
    if (mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final plans = _plans;
    final trial = plans == null
        ? 0
        : plans.map((p) => p.trialDays).fold<int>(0, (a, b) => a > b ? a : b);
    return Scaffold(
      body: NightBackground(
        child: SafeArea(
          child: plans == null
              ? const SizedBox.expand()
              : FadeTransition(
                  opacity: CurvedAnimation(parent: _in, curve: Curves.easeOut),
                  child: SlideTransition(
                    position:
                        Tween(begin: const Offset(0, 0.04), end: Offset.zero)
                            .animate(CurvedAnimation(
                                parent: _in, curve: Curves.easeOutCubic)),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
                          child: Column(
                            children: [
                              // Todo lo de arriba cabe en lo que queda: en pantallas pequeñas (o con letra grande)
                              // se encoge un poco en vez de obligar a desplazar; los botones nunca se tapan.
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, box) => Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: SizedBox(
                                        width: box.maxWidth,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            SizedBox(
                                              width: 170,
                                              height: 150,
                                              child: CustomPaint(
                                                painter: StorybookPainter(
                                                    intro: 1, t: 0.3),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              trial > 0
                                                  ? '¡Listo! Su prueba de $trial días gratis los espera'
                                                  : '¡Listo! Ya pueden empezar',
                                              key: const Key('offer-title'),
                                              textAlign: TextAlign.center,
                                              style: text.headlineSmall!
                                                  .copyWith(
                                                      fontWeight:
                                                          FontWeight.w800),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Con la suscripción se abren todos los cuentos de $appName.',
                                              textAlign: TextAlign.center,
                                              style: text.bodyMedium!.copyWith(
                                                  color: Palette.mutedText),
                                            ),
                                            const SizedBox(height: 16),
                                            const _Benefit(
                                                icon: Icons.auto_stories,
                                                text:
                                                    'Cuentos originales para dormir, narrados y con dibujos animados'),
                                            const _Benefit(
                                                icon: Icons.favorite,
                                                text:
                                                    'Una enseñanza distinta cada noche'),
                                            const _Benefit(
                                                icon: Icons.new_releases,
                                                text:
                                                    'Cuentos nuevos que van llegando'),
                                            _Benefit(
                                                icon:
                                                    Icons.notifications_active,
                                                text: trial > 0
                                                    ? 'Te avisamos 2 días antes de que termine la prueba. Cancela cuando quieras.'
                                                    : 'Cancela cuando quieras en $storeName.'),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: FilledButton(
                                  key: const Key('offer-try'),
                                  onPressed: _try,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(28)),
                                    textStyle: text.titleLarge!
                                        .copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(trial > 0
                                        ? 'Probar $trial días gratis'
                                        : 'Ver la suscripción'),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              TextButton(
                                key: const Key('offer-skip'),
                                onPressed: _close,
                                style: TextButton.styleFrom(
                                  foregroundColor: Palette.mutedText,
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text('Ahora no'),
                              ),
                            ],
                          ),
                        ),
                        // La ✕ para cerrar: pequeña pero siempre a la vista
                        Positioned(
                          top: 2,
                          right: 4,
                          child: IconButton(
                            key: const Key('offer-close'),
                            tooltip: 'Cerrar',
                            onPressed: _close,
                            iconSize: 20,
                            visualDensity: VisualDensity.compact,
                            color: Palette.mutedText,
                            icon: const Icon(Icons.close),
                          ),
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

class _Benefit extends StatelessWidget {
  const _Benefit({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Palette.amber.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Palette.amber, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
        ],
      ),
    );
  }
}
