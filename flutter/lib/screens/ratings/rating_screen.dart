import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../data/services/api_service.dart';
import '../../routes/app_router.dart';
import '../../widgets/common/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  RATING SCREEN — Post-order rating: store + delivery + experience
// ══════════════════════════════════════════════════════════════════════════
class RatingScreen extends StatefulWidget {
  final String mallOrderId;
  final String storeId;
  final String storeName;
  const RatingScreen({
    super.key,
    required this.mallOrderId,
    required this.storeId,
    required this.storeName,
  });
  @override State<RatingScreen> createState() => _RatingScreenState();
}

class _RatingScreenState extends State<RatingScreen> {
  final _api     = ApiService();
  final _comment = TextEditingController();
  int  _storeStars    = 0;
  int  _deliveryStars = 0;
  int  _expStars      = 0;
  bool _loading       = false;
  bool _submitted     = false;

  @override
  void dispose() { _comment.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_storeStars == 0) {
      _showError('يرجى تقييم المحل على الأقل');
      return;
    }
    setState(() => _loading = true);
    try {
      await _api.post('/mall/ratings', data: {
        'storeId':        widget.storeId,
        'mallOrderId':    widget.mallOrderId,
        'storeStars':     _storeStars,
        'deliveryStars':  _deliveryStars > 0 ? _deliveryStars : null,
        'experienceStars':_expStars      > 0 ? _expStars      : null,
        'comment':        _comment.text.trim().isEmpty ? null : _comment.text.trim(),
      });
      setState(() { _submitted = true; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
      _showError('تعذر إرسال التقييم. حاول مجدداً.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AppTheme.error));
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessPage(storeName: widget.storeName);

    return Scaffold(
      appBar: AppBar(title: const Text('قيّم طلبك')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Header ──────────────────────────────────────────────────
          Center(child: Column(children: [
            const Text('⭐', style: TextStyle(fontSize: 52)),
            const SizedBox(height: 10),
            Text('كيف كانت تجربتك مع ${widget.storeName}؟',
              style: const TextStyle(
                color: AppTheme.textPri, fontSize: 17, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text('تقييمك يساعدنا على التحسين المستمر',
              style: TextStyle(color: AppTheme.textSec, fontSize: 13)),
          ])),
          const SizedBox(height: 32),

          // ── Store Rating ─────────────────────────────────────────────
          _RatingSection(
            emoji:    '🏪',
            label:    'جودة المحل والمنتجات',
            required: true,
            stars:    _storeStars,
            onRate:   (v) => setState(() => _storeStars = v),
          ),
          const SizedBox(height: 20),

          // ── Delivery Rating ──────────────────────────────────────────
          _RatingSection(
            emoji:    '🚗',
            label:    'سرعة ودقة التوصيل',
            required: false,
            stars:    _deliveryStars,
            onRate:   (v) => setState(() => _deliveryStars = v),
          ),
          const SizedBox(height: 20),

          // ── Experience Rating ────────────────────────────────────────
          _RatingSection(
            emoji:    '✨',
            label:    'تجربة التطبيق والخدمة العامة',
            required: false,
            stars:    _expStars,
            onRate:   (v) => setState(() => _expStars = v),
          ),
          const SizedBox(height: 24),

          // ── Comment ──────────────────────────────────────────────────
          const Text('تعليق (اختياري)', style: TextStyle(
            color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 8),
          TextField(
            controller:  _comment,
            maxLines:    4,
            maxLength:   300,
            decoration:  const InputDecoration(
              hintText: 'شارك تجربتك بالتفصيل... ما أعجبك؟ ما يمكن تحسينه؟'),
          ),
          const SizedBox(height: 24),

          // ── Emoji Reactions ──────────────────────────────────────────
          const Text('كيف تصف تجربتك؟', style: TextStyle(
            color: AppTheme.textSec, fontSize: 12)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
            for (final e in ['😍','😊','😐','😕','😡'])
              GestureDetector(
                onTap: () {
                  final rating = ['😍','😊','😐','😕','😡'].indexOf(e);
                  setState(() {
                    _storeStars    = 5 - rating;
                    _deliveryStars = 5 - rating;
                    _expStars      = 5 - rating;
                  });
                },
                child: Text(e, style: const TextStyle(fontSize: 32))),
          ]),
          const SizedBox(height: 24),

          // ── Submit ────────────────────────────────────────────────────
          LoadingButton(
            loading: _loading,
            label:   'إرسال التقييم',
            onPressed: _submit,
            icon: Icons.star,
          ),
          const SizedBox(height: 12),
          Center(child: TextButton(
            onPressed: () => AppRouter.pop(),
            child: const Text('تخطي', style: TextStyle(color: AppTheme.textMut)))),
          const SizedBox(height: 24),
        ])));
  }
}

// ── Rating Section Widget ──────────────────────────────────────────────────
class _RatingSection extends StatelessWidget {
  final String   emoji, label;
  final bool     required;
  final int      stars;
  final Function(int) onRate;
  const _RatingSection({
    required this.emoji, required this.label, required this.required,
    required this.stars, required this.onRate});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: stars > 0 ? AppTheme.accent.withOpacity(0.3) : AppTheme.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(
          color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 13)),
        if (required) ...[
          const SizedBox(width: 4),
          const Text('*', style: TextStyle(color: AppTheme.error, fontSize: 14)),
        ],
        const Spacer(),
        if (!required)
          const Text('اختياري', style: TextStyle(
            color: AppTheme.textMut, fontSize: 10)),
      ]),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) => GestureDetector(
          onTap: () => onRate(i + 1),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                i < stars ? Icons.star : Icons.star_border,
                key: ValueKey('$i-$stars'),
                color: const Color(0xFFF59E0B),
                size: 36)))))),
      if (stars > 0) ...[
        const SizedBox(height: 8),
        Center(child: Text(_ratingLabel(stars),
          style: TextStyle(
            color: AppTheme.accent, fontSize: 12,
            fontWeight: FontWeight.w700))),
      ],
    ]));

  static String _ratingLabel(int s) => switch(s) {
    1 => 'سيئ جداً 😡',
    2 => 'سيئ 😕',
    3 => 'متوسط 😐',
    4 => 'جيد 😊',
    5 => 'ممتاز 😍',
    _ => '',
  };
}

// ── Success Page ────────────────────────────────────────────────────────────
class _SuccessPage extends StatelessWidget {
  final String storeName;
  const _SuccessPage({required this.storeName});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('🌟', style: TextStyle(fontSize: 72)),
        const SizedBox(height: 20),
        const Text('شكراً على تقييمك!',
          style: TextStyle(
            color: AppTheme.textPri, fontSize: 24, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center),
        const SizedBox(height: 10),
        Text('رأيك يساعد $storeName والعملاء الآخرين',
          style: const TextStyle(color: AppTheme.textSec, fontSize: 14),
          textAlign: TextAlign.center),
        const SizedBox(height: 32),
        // Loyalty bonus hint
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.secondary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.secondary.withOpacity(0.3))),
          child: Row(children: [
            const Text('⭐', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('+5 نقاط!',
                style: TextStyle(color: AppTheme.secondary,
                  fontWeight: FontWeight.w800)),
              Text('حصلت على نقاط مكافأة لتقييمك',
                style: TextStyle(color: AppTheme.textSec, fontSize: 12)),
            ])),
          ])),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () => AppRouter.popToHome(),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 50)),
          child: const Text('العودة للرئيسية')),
      ])))));
}
