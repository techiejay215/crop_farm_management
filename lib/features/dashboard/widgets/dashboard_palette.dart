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
  static const Color ink      = Color(0xFF1A202C);
  static const Color inkSoft  = Color(0xFF4A5568);
  static const Color inkMuted = Color(0xFF718096);
  static const Color inkFaint = Color(0xFFA0AEC0);

  // ─── Surfaces ────────────────────────────────────────
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color surfaceTint     = Color(0xFFF6FBF7);
  static const Color surfaceTintWarm = Color(0xFFFBF8F2);
  static const Color canvas          = Color(0xFFF8F9FA);
  static const Color hairline        = Color(0xFFE2E8F0);
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
  static const Color iconGreen      = Color(0xFF0B5D3B);
  static const Color iconGreenTint  = Color(0xFFF0FFF4);

  static const Color iconOlive      = Color(0xFF556B2F);
  static const Color iconOliveTint  = Color(0xFFF0F5E8);

  static const Color iconFresh      = Color(0xFF1F8A5B);
  static const Color iconFreshTint  = Color(0xFFC5E6D5);

  static const Color iconGold       = Color(0xFFB7791F);
  static const Color iconGoldTint   = Color(0xFFFEFCBF);

  static const Color iconEarth      = Color(0xFF7A5A2E);
  static const Color iconEarthTint  = Color(0xFFE6D6B8);

  static const Color iconSlate      = Color(0xFF3E5F4A);
  static const Color iconSlateTint  = Color(0xFFCFDDD2);

  static const Color iconBlue       = Color(0xFF2C5282);
  static const Color iconBlueTint   = Color(0xFFEBF8FF);

  static const Color iconTeal       = Color(0xFF285E61);
  static const Color iconTealTint   = Color(0xFFE6FFFA);

  static const Color iconPurple     = Color(0xFF553C9A);
  static const Color iconPurpleTint = Color(0xFFE9D8FD);

  static const Color iconBerry      = Color(0xFF97266D);
  static const Color iconBerryTint  = Color(0xFFFED7E2);

  static const Color iconRed        = Color(0xFFC53030);
  static const Color iconRedTint    = Color(0xFFFED7D7);

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

  static const LinearGradient heroOverlayGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xA80B5D3B),
      Color(0x550B5D3B),
      Color(0x120B5D3B),
    ],
    stops: [0.0, 0.55, 1.0],
  );

  static LinearGradient cardGradient(Color tint) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.white,
        tint.withValues(alpha: 0.3),
      ],
    );
  }

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
      color: Color(0x0A000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Color(0x05000000),
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> liftedShadow = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];

  // ─── Shared icon chip ────────────────────────────────
  static BoxDecoration iconChip(
    Color accent,
    Color tint, {
    double radius = 14,
  }) {
    return BoxDecoration(
      color: tint,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accent.withValues(alpha: 0.15),
        width: 1,
      ),
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

  // ===========================================================================
  // DESKTOP KPI / SIDEBAR ALIASES  (new)
  // ===========================================================================
  static const Color kpiGreenIcon  = iconGreen;
  static const Color kpiGreenBg    = iconGreenTint;
  static const Color kpiBlueIcon   = iconBlue;
  static const Color kpiBlueBg     = iconBlueTint;
  static const Color kpiPurpleIcon = iconPurple;
  static const Color kpiPurpleBg   = iconPurpleTint;
  static const Color kpiGoldIcon   = iconGold;
  static const Color kpiGoldBg     = iconGoldTint;

  static const Color sidebarActive = Color(0xFFE4F1E9);
  static const Color sidebarBg     = Color(0xFFF4F8F5);
}