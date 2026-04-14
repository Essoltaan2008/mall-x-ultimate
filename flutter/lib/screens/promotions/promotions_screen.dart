import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../data/services/api_service.dart';
import '../../widgets/common/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  PROMOTIONS SCREEN — Flash Sales + Coupons
// ══════════════════════════════════════════════════════════════════════════
class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});
  @override State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late TabController _tabs;
  Map? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }
  @override void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    try {
      final res = await _api.get(ApiEndpoints.promotions);
      setState(() { _data = res.data['data']; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final flashes = List<Map>.from(_data?['flashSales'] ?? []);
    final coupons = List<Map>.from(_data?['coupons']    ?? []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض والكوبونات'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: '⚡ فلاش سيل (${flashes.length})'),
            Tab(text: '🎟️ كوبونات (${coupons.length})'),
          ])),
      body: _loading
        ? const ShimmerList()
        : TabBarView(controller: _tabs, children: [
            _FlashSalesTab(flashes: flashes),
            _CouponsTab(coupons: coupons),
          ]));
  }
}

// ── Flash Sales Tab ────────────────────────────────────────────────────────
class _FlashSalesTab extends StatelessWidget {
  final List<Map> flashes;
  const _FlashSalesTab({required this.flashes});

  @override
  Widget build(BuildContext context) {
    if (flashes.isEmpty) return EmptyState(
      emoji: '⚡', title: 'لا توجد فلاش سيل الآن',
      subtitle: 'عد لاحقاً للحصول على عروض حصرية محدودة');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: flashes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _FlashCard(flash: flashes[i]));
  }
}

class _FlashCard extends StatefulWidget {
  final Map flash;
  const _FlashCard({required this.flash});
  @override State<_FlashCard> createState() => _FlashCardState();
}

class _FlashCardState extends State<_FlashCard> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _calcRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _calcRemaining());
  }
  @override void dispose() { _timer?.cancel(); super.dispose(); }

  void _calcRemaining() {
    final ends = DateTime.tryParse(widget.flash['endsAt'] ?? '');
    if (!mounted) return;
    setState(() {
      _remaining = ends != null
        ? ends.difference(DateTime.now())
        : Duration.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final orig   = (widget.flash['originalPrice'] as num?)?.toDouble() ?? 0;
    final flash  = (widget.flash['flashPrice']    as num?)?.toDouble() ?? 0;
    final pct    = orig > 0 ? ((orig - flash) / orig * 100).round() : 0;
    final limit  = widget.flash['quantityLimit'] as int? ?? 0;
    final sold   = widget.flash['quantitySold']  as int? ?? 0;
    final avail  = limit - sold;
    final expired = _remaining.isNegative;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expired ? AppTheme.border : AppTheme.accent.withOpacity(0.4))),
      child: Column(children: [
        // Header with timer
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: expired
                ? [AppTheme.border, AppTheme.surface]
                : [AppTheme.accent.withOpacity(0.2), AppTheme.surface]),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16), topLeft: Radius.circular(16))),
          child: Row(children: [
            Text(expired ? '⏰' : '⚡',
              style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(child: Text(
              widget.flash['titleAr'] ?? widget.flash['title'] ?? '',
              style: const TextStyle(
                color: AppTheme.textPri, fontWeight: FontWeight.w800))),
            if (!expired)
              _CountdownChip(remaining: _remaining),
          ])),

        // Price + stock
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${flash.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(width: 8),
                Text('${orig.toStringAsFixed(0)} ج.م',
                  style: const TextStyle(
                    color: AppTheme.textMut, fontSize: 14,
                    decoration: TextDecoration.lineThrough)),
              ]),
              const SizedBox(height: 6),
              // Stock bar
              if (limit > 0) ...[
                Text('تبقّى $avail من $limit',
                  style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: avail / limit,
                    minHeight: 6,
                    backgroundColor: AppTheme.border,
                    valueColor: AlwaysStoppedAnimation(
                      avail < limit * 0.2 ? AppTheme.error : AppTheme.secondary))),
              ],
            ])),
            const SizedBox(width: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10)),
              child: Text('-$pct%',
                style: const TextStyle(
                  color: AppTheme.error,
                  fontWeight: FontWeight.w900, fontSize: 18))),
          ])),
      ]));
  }
}

class _CountdownChip extends StatelessWidget {
  final Duration remaining;
  const _CountdownChip({required this.remaining});

  @override
  Widget build(BuildContext context) {
    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    final txt = h > 0
      ? '${h}س ${m.toString().padLeft(2,'0')}د'
      : '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: h < 1 ? AppTheme.error.withOpacity(0.15) : AppTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: h < 1 ? AppTheme.error.withOpacity(0.4) : AppTheme.accent.withOpacity(0.4))),
      child: Text(txt,
        style: TextStyle(
          color: h < 1 ? AppTheme.error : AppTheme.accent,
          fontWeight: FontWeight.w800, fontSize: 12,
          fontFamily: 'monospace')));
  }
}

// ── Coupons Tab ────────────────────────────────────────────────────────────
class _CouponsTab extends StatelessWidget {
  final List<Map> coupons;
  const _CouponsTab({required this.coupons});

  @override
  Widget build(BuildContext context) {
    if (coupons.isEmpty) return EmptyState(
      emoji: '🎟️', title: 'لا توجد كوبونات متاحة',
      subtitle: 'تابع عروض المول للحصول على خصومات حصرية');

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: coupons.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CouponCard(coupon: coupons[i]));
  }
}

class _CouponCard extends StatefulWidget {
  final Map coupon;
  const _CouponCard({required this.coupon});
  @override State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  bool _copied = false;

  void _copy() async {
    // Would use Clipboard.setData in real app
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2),
      () { if (mounted) setState(() => _copied = false); });
  }

  @override
  Widget build(BuildContext context) {
    final type    = widget.coupon['discountType'] as String? ?? '';
    final value   = (widget.coupon['discountValue'] as num?)?.toDouble() ?? 0;
    final code    = widget.coupon['code'] as String? ?? '';
    final expiry  = DateTime.tryParse(widget.coupon['validTo'] ?? '');
    final minOrd  = (widget.coupon['minOrderValue'] as num?)?.toDouble() ?? 0;

    final displayVal = type == 'Percentage' ? '${value.toStringAsFixed(0)}%'
        : type == 'FreeDelivery' ? 'توصيل مجاني 🚗'
        : '${value.toStringAsFixed(0)} ج.م';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
      child: Row(children: [
        // Left colored section
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary.withOpacity(0.3), AppTheme.primary.withOpacity(0.1)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(14), bottomRight: Radius.circular(14))),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(displayVal,
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.w900, fontSize: 16),
              textAlign: TextAlign.center),
            const Text('خصم', style: TextStyle(
              color: AppTheme.textSec, fontSize: 10)),
          ])),

        // Dashed separator
        CustomPaint(
          size: const Size(1, 60),
          painter: _DashedLinePainter()),

        // Right content
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.coupon['name'] ?? '',
              style: const TextStyle(
                color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 4),
            if (minOrd > 0)
              Text('بحد أدنى ${minOrd.toStringAsFixed(0)} ج.م',
                style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
            if (expiry != null)
              Text('حتى ${expiry.day}/${expiry.month}/${expiry.year}',
                style: const TextStyle(color: AppTheme.textMut, fontSize: 10)),
          ]))),

        // Code + copy button
        Padding(
          padding: const EdgeInsets.only(left: 12, right: 8),
          child: GestureDetector(
            onTap: _copy,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _copied
                  ? AppTheme.secondary.withOpacity(0.12)
                  : AppTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _copied ? AppTheme.secondary : AppTheme.border)),
              child: Column(children: [
                Text(code,
                  style: TextStyle(
                    color: _copied ? AppTheme.secondary : AppTheme.primary,
                    fontWeight: FontWeight.w900, fontSize: 13,
                    letterSpacing: 1)),
                const SizedBox(height: 2),
                Text(_copied ? 'تم!' : 'نسخ',
                  style: TextStyle(
                    color: _copied ? AppTheme.secondary : AppTheme.textSec,
                    fontSize: 9)),
              ]))),
        ),
      ]));
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 1;
    const dashH = 5.0, gapH = 4.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gapH;
    }
  }
  @override bool shouldRepaint(_) => false;
}
