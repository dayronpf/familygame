import 'package:flutter/material.dart';

import 'moral_style.dart';

/// Tarjeta grande y redonda para elegir lo que aprende hoy el protagonista (un toque, se marca con un visto).
class MoralTile extends StatelessWidget {
  const MoralTile({
    super.key,
    required this.name,
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final MoralStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.97,
        duration: const Duration(milliseconds: 160),
        child: Material(
          color: selected ? style.color : style.color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Stack(
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 78),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.85)
                          : style.color.withValues(alpha: 0.55),
                      width: selected ? 3 : 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withValues(alpha: 0.9)
                              : style.color.withValues(alpha: 0.28),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(style.icon,
                            color: selected ? style.color : Colors.white,
                            size: 24),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                name,
                                maxLines: 1,
                                style: text.titleMedium!.copyWith(
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: selected
                                      ? const Color(0xFF1B1233)
                                      : Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              style.blurb,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall!.copyWith(
                                height: 1.15,
                                color: selected
                                    ? const Color(0xFF2A1F4A)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 8,
                    right: 10,
                    child: Icon(Icons.check_circle,
                        size: 20, color: Color(0xFF1B1233)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
