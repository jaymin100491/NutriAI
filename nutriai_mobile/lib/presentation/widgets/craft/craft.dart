import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_theme.dart';

/// Soft entrance used across premium surfaces.
extension CraftMotion on Widget {
  Widget craftIn({int delayMs = 0, int durationMs = 420}) {
    return animate(delay: delayMs.ms)
        .fadeIn(duration: durationMs.ms, curve: Curves.easeOutCubic)
        .slideY(begin: 0.06, end: 0, duration: durationMs.ms, curve: Curves.easeOutCubic);
  }
}

class CraftShimmer extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius? radius;

  const CraftShimmer({
    super.key,
    required this.height,
    this.width,
    this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE8E4DC),
      highlightColor: const Color(0xFFF7F4EF),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: radius ?? BorderRadius.circular(18),
        ),
      ),
    );
  }
}

class CraftEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const CraftEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.chipBg,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(icon, size: 34, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                height: 1.45,
                color: AppTheme.textSecondaryColor,
              ),
            ),
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: 22),
              FilledButton(onPressed: onCta, child: Text(ctaLabel!)),
            ],
          ],
        ),
      ),
    ).craftIn();
  }
}

class CraftErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const CraftErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return CraftEmptyState(
      icon: Icons.cloud_off_outlined,
      title: 'Couldn’t load this',
      body: message,
      ctaLabel: 'Try again',
      onCta: onRetry,
    );
  }
}

/// Clinician-grade provenance / trust strip.
class TrustBanner extends StatelessWidget {
  final bool verified;
  final String title;
  final String subtitle;
  final List<String> sources;

  const TrustBanner({
    super.key,
    required this.verified,
    required this.title,
    required this.subtitle,
    this.sources = const [],
  });

  @override
  Widget build(BuildContext context) {
    final bg = verified ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0);
    final accent = verified ? AppTheme.successColor : AppTheme.warningColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                verified ? Icons.verified_rounded : Icons.info_outline_rounded,
                size: 18,
                color: accent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: sources
                  .map(
                    (s) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        s,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class CraftSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;

  const CraftSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: AppTheme.ink,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (action != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              action!,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

class ProvenanceChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const ProvenanceChip({
    super.key,
    required this.label,
    this.icon = Icons.menu_book_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.chipBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
