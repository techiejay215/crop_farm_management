import 'package:flutter/material.dart';

class DPalette {
  DPalette._();

  // ─── Brand ───────────────────────────────────────────
  static const Color brand       = Color(0xFF0B5D3B);
  static const Color brandDeep   = Color(0xFF063A22);
  static const Color brandMid    = Color(0xFF0E6E47);
  static const Color brandLight  = Color(0xFF147A52);

  static const Color sage        = Color(0xFFD5E9DC);
  static const Color sageSoft    = Color(0xFFEAF4EE);
  static const Color sageDeep    = Color(0xFFBFDCC9);

  // ─── Ink ─────────────────────────────────────────────
  static const Color ink      = Color(0xFF0F1A15);
  static const Color inkSoft  = Color(0xFF3A4640);
  static const Color inkMuted = Color(0xFF6B7873);
  static const Color inkFaint = Color(0xFF96A29C);

  // ─── Surfaces ────────────────────────────────────────
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color surfaceTint     = Color(0xFFF6FBF7);
  static const Color surfaceTintWarm = Color(0xFFFBF8F2);
  static const Color canvas          = Color(0xFFF4F7F4);
  static const Color hairline        = Color(0xFFDCE7E0);
  static const Color hairlineStrong  = Color(0xFFC9D9CF);

  // ─── Financial ───────────────────────────────────────
  static const Color revenue     = brand;
  static const Color revenueTint = Color(0xFFE4F1E9);
  static const Color revenueEdge = Color(0xFFC2DACC);

  static const Color expense     = Color(0xFF9A6A17);
  static const Color expenseTint = Color(0xFFF6EBD3);
  static const Color expenseEdge = Color(0xFFE5D2A8);
  static const Color gold        = Color(0xFFD6A63A);

  static const Color profit      = brand;
  static const Color profitTint  = Color(0xFFE4F1E9);
  static const Color profitEdge  = Color(0xFFC2DACC);

  static const Color alert     = Color(0xFF9A6A17);
  static const Color alertTint = Color(0xFFF6EBD3);
  static const Color alertEdge = Color(0xFFE5D2A8);

  // ─── Icon colour families ────────────────────────────
  // Green — home, net profit, brand identity
  static const Color iconGreen      = Color(0xFF0B5D3B);
  static const Color iconGreenTint  = Color(0xFFC8E2D2);

  // Olive — crops, growing things
  static const Color iconOlive      = Color(0xFF4A7C3F);
  static const Color iconOliveTint  = Color(0xFFD6E5CA);

  // Fresh — sales, transactions
  static const Color iconFresh      = Color(0xFF1F8A5B);
  static const Color iconFreshTint  = Color(0xFFC5E6D5);

  // Gold — expenses, harvest
  static const Color iconGold       = Color(0xFFA8761E);
  static const Color iconGoldTint   = Color(0xFFF0DFB8);

  // Earth — labour, wages
  static const Color iconEarth      = Color(0xFF7A5A2E);
  static const Color iconEarthTint  = Color(0xFFE6D6B8);

  // Slate — misc / settings
  static const Color iconSlate      = Color(0xFF3E5F4A);
  static const Color iconSlateTint  = Color(0xFFCFDDD2);

  // ─── NEW — Blue: farms, revenue ──────────────────────
  static const Color iconBlue       = Color(0xFF1E5B96);
  static const Color iconBlueTint   = Color(0xFFD2E4F5);

  // ─── NEW — Teal: yield, production ───────────────────
  static const Color iconTeal       = Color(0xFF0E6E78);
  static const Color iconTealTint   = Color(0xFFC9E4E8);

  // ─── NEW — Purple: analytics, margin, more ──────────
  static const Color iconPurple     = Color(0xFF5B3D8F);
  static const Color iconPurpleTint = Color(0xFFE1D7F0);

  // ─── NEW — Berry: pending, owed, alerts ─────────────
  static const Color iconBerry      = Color(0xFF92376A);
  static const Color iconBerryTint  = Color(0xFFF0D4E1);

  // ─── Legacy chip aliases ─────────────────────────────
  static const Color chipGreen   = sage;
  static const Color chipAmber   = Color(0xFFF2E4C4);
  static const Color chipNeutral = Color(0xFFE8EEEA);

  // ─── Gradients ───────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [brandDeep, brand, brandMid],
    stops: [0.0, 0.55, 1.0],
  );

  /// Much lighter than before — image shows through clearly on the right,
  /// only dark enough on the left for the white text to stay readable.
  static const LinearGradient heroOverlayGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xA80B5D3B),   // was 0xE0 — 25% lighter
      Color(0x550B5D3B),   // was 0xA6 — 50% lighter
      Color(0x120B5D3B),   // was 0x33 — 65% lighter
    ],
    stops: [0.0, 0.55, 1.0],
  );

  // ─── Elevation ───────────────────────────────────────
  static List<BoxShadow> softShadow({Color? tint}) => [
        BoxShadow(
          color: (tint ?? brand).withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, 4),
        ),
      ];

  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x140B5D3B),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> liftedShadow = [
    BoxShadow(
      color: Color(0x1A0B5D3B),
      blurRadius: 22,
      offset: Offset(0, 8),
    ),
  ];

  // ─── Shared icon chip ────────────────────────────────
  static BoxDecoration iconChip(
    Color accent,
    Color tint, {
    double radius = 14,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(tint, Colors.white, 0.55)!,
          tint,
        ],
      ),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accent.withValues(alpha: 0.18),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.13),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // ===========================================================================
  // LEGACY ALIASES
  // ===========================================================================
  static const Color forest      = brandDeep;
  static const Color forestMid   = brandMid;
  static const Color leaf        = brand;
  static const Color leafBright  = brandMid;
  static const Color leafSoft    = Color(0xFFA8D4B8);
  static const Color leafWhisper = sage;
  static const Color leafFaint   = sageSoft;

  static const Color chipBlue    = sage;
  static const Color sky         = brand;
  static const Color rose        = alert;
}