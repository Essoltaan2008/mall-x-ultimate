import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════════════════
//  SHIMMER LOADER — skeleton loading state
// ══════════════════════════════════════════════════════════════════════════
class ShimmerBox extends StatelessWidget {
  final double? width, height;
  final double  radius;
  const ShimmerBox({super.key, this.width, this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
    baseColor:      AppTheme.card,
    highlightColor: AppTheme.border,
    child: Container(
      width:  width, height: height,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(radius)),
    ));
}

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const ShimmerBox(width: 48, height: 48, radius: 12),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
          ShimmerBox(height: 14, radius: 4),
          SizedBox(height: 8),
          ShimmerBox(height: 11, width: 120, radius: 4),
        ])),
      ]),
      const SizedBox(height: 12),
      const ShimmerBox(height: 11, radius: 4),
      const SizedBox(height: 6),
      const ShimmerBox(height: 11, width: 200, radius: 4),
    ]));
}

class ShimmerList extends StatelessWidget {
  final int count;
  const ShimmerList({super.key, this.count = 4});
  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: count,
    itemBuilder: (_, __) => const ShimmerCard());
}

class ShimmerGrid extends StatelessWidget {
  final int count;
  const ShimmerGrid({super.key, this.count = 6});
  @override
  Widget build(BuildContext context) => GridView.builder(
    padding: const EdgeInsets.all(16),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12,
      childAspectRatio: 0.85),
    itemCount: count,
    itemBuilder: (_, __) => Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Expanded(child: ShimmerBox(width: double.infinity, height: double.infinity, radius: 0)),
        const Padding(padding: EdgeInsets.all(10), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            ShimmerBox(height: 12, radius: 4),
            SizedBox(height: 6),
            ShimmerBox(height: 12, width: 60, radius: 4),
          ])),
      ])));
}

// ══════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ══════════════════════════════════════════════════════════════════════════
class EmptyState extends StatelessWidget {
  final String   emoji;
  final String   title;
  final String?  subtitle;
  final String?  buttonLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    this.subtitle,
    this.buttonLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 96, height: 96,
          decoration: BoxDecoration(
            color: AppTheme.card, shape: BoxShape.circle,
            border: Border.all(color: AppTheme.border)),
          child: Center(child: Text(emoji,
            style: const TextStyle(fontSize: 40)))),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(
          color: AppTheme.textPri, fontSize: 18, fontWeight: FontWeight.w700),
          textAlign: TextAlign.center),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: const TextStyle(
            color: AppTheme.textSec, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center),
        ],
        if (buttonLabel != null && onAction != null) ...[
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(180, 48)),
            child: Text(buttonLabel!)),
        ],
      ])));
}

// ══════════════════════════════════════════════════════════════════════════
//  ERROR STATE
// ══════════════════════════════════════════════════════════════════════════
class ErrorState extends StatelessWidget {
  final String?  message;
  final VoidCallback? onRetry;
  const ErrorState({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, color: AppTheme.error, size: 52),
        const SizedBox(height: 16),
        Text(message ?? 'حدث خطأ ما. حاول مجدداً.',
          style: const TextStyle(color: AppTheme.textSec, fontSize: 14),
          textAlign: TextAlign.center),
        if (onRetry != null) ...[
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('إعادة المحاولة'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              minimumSize: const Size(160, 44))),
        ],
      ])));
}

// ══════════════════════════════════════════════════════════════════════════
//  LOADING BUTTON
// ══════════════════════════════════════════════════════════════════════════
class LoadingButton extends StatelessWidget {
  final bool     loading;
  final String   label;
  final VoidCallback? onPressed;
  final Color?   color;
  final IconData? icon;

  const LoadingButton({
    super.key,
    required this.loading,
    required this.label,
    this.onPressed,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton(
    onPressed: loading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: color ?? AppTheme.primary,
      minimumSize: const Size(double.infinity, 52)),
    child: loading
      ? const SizedBox(width: 22, height: 22,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
          ],
          Text(label, style: const TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
        ]));
}

// ══════════════════════════════════════════════════════════════════════════
//  RATING STARS
// ══════════════════════════════════════════════════════════════════════════
class RatingStars extends StatelessWidget {
  final double rating;
  final int    total;
  final double size;
  const RatingStars({super.key, required this.rating,
    this.total = 0, this.size = 14});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ...List.generate(5, (i) => Icon(
        i < rating.floor()
          ? Icons.star
          : (i < rating && rating % 1 >= 0.5)
            ? Icons.star_half
            : Icons.star_border,
        color: const Color(0xFFF59E0B), size: size)),
      if (total > 0) ...[
        const SizedBox(width: 4),
        Text('(${total})',
          style: TextStyle(color: AppTheme.textSec, fontSize: size * 0.85)),
      ],
    ]);
}

// ══════════════════════════════════════════════════════════════════════════
//  PRICE TAG
// ══════════════════════════════════════════════════════════════════════════
class PriceTag extends StatelessWidget {
  final double price;
  final double? originalPrice;
  final double fontSize;

  const PriceTag({super.key, required this.price,
    this.originalPrice, this.fontSize = 16});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text('${price.toStringAsFixed(0)} ج.م',
        style: TextStyle(
          color: AppTheme.primary, fontWeight: FontWeight.w900,
          fontSize: fontSize)),
      if (originalPrice != null && originalPrice! > price) ...[
        const SizedBox(width: 6),
        Text('${originalPrice!.toStringAsFixed(0)} ج.م',
          style: TextStyle(
            color: AppTheme.textSec, fontSize: fontSize * 0.75,
            decoration: TextDecoration.lineThrough)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.12),
            borderRadius: BorderRadius.circular(5)),
          child: Text(
            '-${(((originalPrice! - price) / originalPrice!) * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              color: AppTheme.error, fontSize: fontSize * 0.65,
              fontWeight: FontWeight.w700))),
      ],
    ]);
}

// ══════════════════════════════════════════════════════════════════════════
//  BADGE (unread notification count)
// ══════════════════════════════════════════════════════════════════════════
class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int      count;
  final Color?   iconColor;
  final double   size;

  const BadgeIcon({super.key, required this.icon,
    required this.count, this.iconColor, this.size = 22});

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(icon, color: iconColor ?? AppTheme.textSec, size: size),
      if (count > 0)
        Positioned(
          top: -4, left: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(8)),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              count > 99 ? '99+' : '$count',
              style: const TextStyle(
                color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center))),
    ]);
}

// ══════════════════════════════════════════════════════════════════════════
//  NETWORK IMAGE WITH FALLBACK
// ══════════════════════════════════════════════════════════════════════════
class MallNetworkImage extends StatelessWidget {
  final String? url;
  final double? width, height;
  final double  radius;
  final IconData fallbackIcon;
  final Color?  fallbackBg;

  const MallNetworkImage({
    super.key,
    this.url,
    this.width, this.height,
    this.radius = 10,
    this.fallbackIcon = Icons.image_outlined,
    this.fallbackBg,
  });

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return _fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url!,
        width: width, height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallback(),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            width: width, height: height,
            color: AppTheme.card,
            child: const Center(child: SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary))));
        },
      ));
  }

  Widget _fallback() => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      width: width, height: height,
      color: fallbackBg ?? AppTheme.surface,
      child: Icon(fallbackIcon, color: AppTheme.textSec,
        size: (width ?? 40) * 0.4)));
}

// ══════════════════════════════════════════════════════════════════════════
//  TIER BADGE
// ══════════════════════════════════════════════════════════════════════════
class TierBadge extends StatelessWidget {
  final String tier;
  final bool   showEmoji;
  const TierBadge({super.key, required this.tier, this.showEmoji = true});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.tierColor(tier);
    final emoji = AppTheme.tierEmoji(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border:       Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (showEmoji) ...[Text(emoji, style: const TextStyle(fontSize: 12)), const SizedBox(width: 4)],
        Text(tier, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]));
  }
}
