import 'package:flutter/material.dart';

import 'palette.dart';

/// Cómo se ve cada enseñanza: un color, un icono y una frase corta que entiende un niño.
class MoralStyle {
  const MoralStyle(this.color, this.icon, this.blurb);

  final Color color;
  final IconData icon;
  final String blurb;

  static const MoralStyle surprise =
      MoralStyle(Palette.surprise, Icons.auto_awesome, 'Una sorpresa');

  static const Map<String, MoralStyle> _byId = {
    'honestidad':
        MoralStyle(Color(0xFF5DA9FF), Icons.balance, 'Decir la verdad'),
    'generosidad':
        MoralStyle(Color(0xFFFF8FB1), Icons.volunteer_activism, 'Compartir'),
    'valentia': MoralStyle(
        Color(0xFFFF9F5A), Icons.shield_outlined, 'Dar el primer paso'),
    'humildad':
        MoralStyle(Color(0xFF7ED6A1), Icons.spa_outlined, 'Pedir ayuda'),
    'perseverancia':
        MoralStyle(Color(0xFFFFD166), Icons.trending_up, 'Intentarlo otra vez'),
    'amistad': MoralStyle(
        Color(0xFF6FE3D0), Icons.people_outline, 'Cuidar a los amigos'),
  };

  static MoralStyle of(String id) =>
      _byId[id] ??
      const MoralStyle(
          Color(0xFF7ED6A1), Icons.favorite_outline, 'Una enseñanza');
}
