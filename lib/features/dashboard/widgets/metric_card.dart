// lib/features/dashboard/widgets/metric_card.dart
import 'package:flutter/material.dart';
import 'dashboard_palette.dart';

// =============================================================================
// NEW: KPI CARD (Used exclusively on Desktop)
// Compact, watermark-decorated card matching the reference design.
// =============================================================================
class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String trendText;
  final IconData icon;
  final IconData? watermark;
  final Color iconColor;
  final Color iconBg;
  final Color trendColor;

  const KpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.trendText,
    required this.icon,
    this.watermark,
    required this.iconColor,
    required this.iconBg,
    this.trendColor = DPalette.iconGreen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DPalette.hairline),
        boxShadow: DPalette.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // Soft watermark illustration (bottom-right)
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(
              watermark ?? icon,
              size: 92,
              color: iconColor.withValues(alpha: 0.07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: iconBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: iconColor, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: iconColor,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: DPalette.ink,
                    letterSpacing: -0.9,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trendText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: trendColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ORIGINAL: PRIMARY METRIC CARD (Used on Mobile) — UNCHANGED
// =============================================================================
class PrimaryMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final String? badge;
  final IconData icon;
  final Color accent;
  final Color accentTint;

  const PrimaryMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.badge,
    required this.icon,
    this.accent = DPalette.iconGreen,
    this.accentTint = DPalette.iconGreenTint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 12, 11),
      decoration: BoxDecoration(
        color: Color.lerp(DPalette.surface, accentTint, 0.45)!,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.20), width: 1),
        boxShadow: DPalette.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: DPalette.iconChip(accent, accentTint, radius: 13),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: DPalette.ink,
                            letterSpacing: -0.9,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: DPalette.inkSoft,
                    letterSpacing: 0.05,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ORIGINAL: FINANCIAL METRIC CARD (Used on Mobile) — UNCHANGED
// =============================================================================
class FinancialMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;
  final Color? background;
  final Color? border;
  final IconData? icon;

  const FinancialMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.accentColor,
    this.background,
    this.border,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
      decoration: BoxDecoration(
        color: background ?? DPalette.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border ?? DPalette.hairline, width: 1),
        boxShadow: DPalette.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: accentColor.withValues(alpha: 0.22)),
                ),
                child: Icon(icon ?? Icons.circle_outlined,
                    size: 13, color: accentColor),
              ),
              const Spacer(),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: DPalette.inkMuted,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: DPalette.ink,
                letterSpacing: -0.6,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}