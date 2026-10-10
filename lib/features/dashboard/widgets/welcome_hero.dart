import 'package:flutter/material.dart';
import 'dashboard_palette.dart';

class WelcomeHero extends StatelessWidget {
  final String greeting;
  final String name;
  final String subtitle;
  final String? assetImage;
  final String? networkImage;
  final Widget? selector;
  final List<Widget>? meta;

  const WelcomeHero({
    super.key,
    required this.greeting,
    required this.name,
    required this.subtitle,
    this.assetImage,
    this.networkImage,
    this.selector,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        children: [
          Positioned.fill(child: _backgroundImage()),

          Positioned.fill(
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: DPalette.heroOverlayGradient),
            ),
          ),

          // Soft top-left highlight
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.9, -1.0),
                    radius: 1.5,
                    colors: [
                      Colors.white.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.20),
                        ),
                      ),
                      child: const Icon(
                        Icons.eco_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      greeting.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.78),
                        letterSpacing: 2.0,
                        shadows: const [
                          Shadow(
                            color: Color(0x66000000),
                            blurRadius: 4,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.7,
                    height: 1.05,
                    shadows: [
                      Shadow(
                        color: Color(0x80000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.35,
                    shadows: const [
                      Shadow(
                        color: Color(0x66000000),
                        blurRadius: 4,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (meta != null && meta!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: meta!,
                  ),
                ],
                if (selector != null) ...[
                  const SizedBox(height: 18),
                  selector!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundImage() {
    const fallback = DecoratedBox(
      decoration: BoxDecoration(gradient: DPalette.heroGradient),
    );

    if (assetImage != null) {
      return Image.asset(
        assetImage!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => networkImage != null
            ? _network(networkImage!, fallback)
            : fallback,
      );
    }
    if (networkImage != null) {
      return _network(networkImage!, fallback);
    }
    return fallback;
  }

  Widget _network(String url, Widget fallback) {
    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => fallback,
      frameBuilder: (context, child, frame, wasSyncLoaded) {
        if (wasSyncLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return const DecoratedBox(
          decoration: BoxDecoration(gradient: DPalette.heroGradient),
        );
      },
    );
  }
}

/// Polished transparent control used inside the hero.
class HeroSelectorContainer extends StatelessWidget {
  final Widget child;
  const HeroSelectorContainer({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.28),
        ),
      ),
      child: child,
    );
  }
}

/// Small glass pill used inside the hero for farm metadata.
class HeroChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const HeroChip({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: Colors.white.withValues(alpha: 0.92),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.95),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}