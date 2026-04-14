import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';

// ══════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS SCREEN
// ══════════════════════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _api    = ApiService();
  List<Map> _notifs = [];
  int  _unread  = 0;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/mall/notifications');
      setState(() {
        final data = res.data['data'] as Map;
        _unread = data['unreadCount'] ?? 0;
        _notifs = List<Map>.from(data['items'] ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _markRead(String id) async {
    await _api.patch('/mall/notifications/$id/read');
    setState(() {
      final idx = _notifs.indexWhere((n) => n['id'] == id);
      if (idx >= 0) {
        _notifs[idx] = Map.from(_notifs[idx])..['isRead'] = true;
        _unread = (_unread - 1).clamp(0, 999);
      }
    });
  }

  Future<void> _markAllRead() async {
    await _api.post('/mall/notifications/mark-all-read');
    setState(() {
      _notifs = _notifs.map((n) => Map.from(n)..['isRead'] = true).toList();
      _unread = 0;
    });
  }

  static const _categoryColors = {
    'Order':    Color(0xFF3B82F6),
    'Delivery': Color(0xFF8B5CF6),
    'Loyalty':  Color(0xFFF59E0B),
    'Promo':    Color(0xFFEF4444),
    'Booking':  Color(0xFF10B981),
    'Payment':  Color(0xFF06B6D4),
    'Referral': Color(0xFF8B5CF6),
    'Wallet':   Color(0xFF10B981),
    'System':   Color(0xFF64748B),
  };

  static const _categoryIcons = {
    'Order':    Icons.receipt_long_outlined,
    'Delivery': Icons.delivery_dining,
    'Loyalty':  Icons.star_outline,
    'Promo':    Icons.local_offer_outlined,
    'Booking':  Icons.calendar_today_outlined,
    'Payment':  Icons.payment_outlined,
    'Referral': Icons.people_outline,
    'Wallet':   Icons.account_balance_wallet_outlined,
    'System':   Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('الإشعارات'),
          if (_unread > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error, borderRadius: BorderRadius.circular(10)),
              child: Text('$_unread', style: const TextStyle(
                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800))),
          ]
        ]),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('قراءة الكل', style: TextStyle(
                color: AppTheme.primary, fontSize: 13))),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifs.isEmpty
              ? _EmptyNotifications()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    itemCount: _notifs.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: AppTheme.border),
                    itemBuilder: (_, i) {
                      final n     = _notifs[i];
                      final cat   = n['category'] as String? ?? 'System';
                      final color = _categoryColors[cat] ?? AppTheme.textSec;
                      final icon  = _categoryIcons[cat]  ?? Icons.notifications_none;
                      final isRead= n['isRead'] as bool? ?? false;

                      return Dismissible(
                        key: Key(n['id']),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: AppTheme.primary,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 20),
                          child: const Icon(Icons.check, color: Colors.white)),
                        onDismissed: (_) => _markRead(n['id']),
                        child: InkWell(
                          onTap: () {
                            if (!isRead) _markRead(n['id']);
                            _handleAction(n['actionType'], n['actionId']);
                          },
                          child: Container(
                            color: isRead ? Colors.transparent : AppTheme.primary.withOpacity(0.04),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  width: 44, height: 44,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12)),
                                  child: Icon(icon, color: color, size: 20)),
                                const SizedBox(width: 12),

                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(children: [
                                        Expanded(
                                          child: Text(n['title'] ?? '',
                                            style: TextStyle(
                                              color: AppTheme.textPri,
                                              fontWeight: isRead
                                                  ? FontWeight.normal
                                                  : FontWeight.w700,
                                              fontSize: 14))),
                                        Text(n['timeAgo'] ?? '',
                                          style: const TextStyle(
                                            color: AppTheme.textSec, fontSize: 11)),
                                      ]),
                                      const SizedBox(height: 4),
                                      Text(n['body'] ?? '',
                                        style: const TextStyle(
                                          color: AppTheme.textSec, fontSize: 13,
                                          height: 1.4),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    ])),

                                // Unread dot
                                if (!isRead) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      shape: BoxShape.circle)),
                                ],
                              ]),
                          ),
                        ),
                      );
                    }),
                ),
    );
  }

  void _handleAction(String? type, String? id) {
    // Navigation would be handled by the main router
    // e.g. Navigator.pushNamed(context, '/orders/$id');
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 80, height: 80,
        decoration: BoxDecoration(
          color: AppTheme.card, shape: BoxShape.circle,
          border: Border.all(color: AppTheme.border)),
        child: const Icon(Icons.notifications_none,
            color: AppTheme.textSec, size: 36)),
      const SizedBox(height: 16),
      const Text('لا توجد إشعارات بعد',
          style: TextStyle(color: AppTheme.textPri, fontSize: 16,
              fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      const Text('ستظهر هنا جميع إشعاراتك',
          style: TextStyle(color: AppTheme.textSec, fontSize: 13)),
    ]));
}

// ══════════════════════════════════════════════════════════════════════════
//  PRODUCT REVIEW WIDGET  (embeds inside product screen)
// ══════════════════════════════════════════════════════════════════════════
class ProductReviewsWidget extends StatefulWidget {
  final String productId;
  const ProductReviewsWidget({super.key, required this.productId});
  @override State<ProductReviewsWidget> createState() => _ProductReviewsWidgetState();
}

class _ProductReviewsWidgetState extends State<ProductReviewsWidget> {
  final _api = ApiService();
  Map? _data;
  bool _loading = true;
  bool _showForm = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get('/mall/products/${widget.productId}/reviews');
      setState(() { _data = res.data['data']; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()));

    final avg    = (_data?['avgStars'] as num?)?.toDouble() ?? 0;
    final total  = _data?['totalReviews'] as int? ?? 0;
    final reviews= List<Map>.from(_data?['reviews'] ?? []);
    final breakdown = Map<String,int>.from(_data?['breakdown'] ?? {});

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Summary ──────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border)),
        child: Row(children: [

          // Big number
          Column(children: [
            Text(avg.toStringAsFixed(1), style: const TextStyle(
              color: AppTheme.textPri, fontSize: 48, fontWeight: FontWeight.w900)),
            Row(children: List.generate(5, (i) => Icon(
              i < avg.round() ? Icons.star : Icons.star_border,
              color: const Color(0xFFF59E0B), size: 16))),
            const SizedBox(height: 4),
            Text('$total تقييم', style: const TextStyle(
              color: AppTheme.textSec, fontSize: 12)),
          ]),

          const SizedBox(width: 20),

          // Breakdown bars
          Expanded(child: Column(
            children: [5, 4, 3, 2, 1].map((star) {
              final count = breakdown['$star'] ?? 0;
              final frac  = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Text('$star', style: const TextStyle(
                    color: AppTheme.textSec, fontSize: 11)),
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 10),
                  const SizedBox(width: 6),
                  Expanded(child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: frac, minHeight: 6,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFF59E0B))))),
                  const SizedBox(width: 6),
                  SizedBox(width: 20, child: Text('$count',
                    style: const TextStyle(color: AppTheme.textSec, fontSize: 10),
                    textAlign: TextAlign.right)),
                ]));
            }).toList())),
        ])),

      const SizedBox(height: 14),

      // Write review button
      OutlinedButton.icon(
        onPressed: () => setState(() => _showForm = !_showForm),
        icon: Icon(_showForm ? Icons.close : Icons.edit_outlined, size: 16),
        label: Text(_showForm ? 'إلغاء' : 'اكتب تقييماً',
            style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.primary,
          side: const BorderSide(color: AppTheme.primary),
          minimumSize: const Size(double.infinity, 40))),

      // Write review form
      if (_showForm)
        _ReviewForm(
          productId: widget.productId,
          onSubmit: () { setState(() => _showForm = false); _load(); }),

      const SizedBox(height: 14),

      // Reviews list
      if (reviews.isEmpty)
        const Center(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('لا توجد تقييمات بعد. كن أول من يقيّم!',
            style: TextStyle(color: AppTheme.textSec))))
      else
        ...reviews.map((r) => _ReviewCard(review: r,
          productId: widget.productId,
          onHelpful: () => _api.post(
            '/mall/products/${widget.productId}/reviews/${r["id"]}/helpful')
              .then((_) => _load()))),
    ]);
  }
}

class _ReviewForm extends StatefulWidget {
  final String productId;
  final VoidCallback onSubmit;
  const _ReviewForm({required this.productId, required this.onSubmit});
  @override State<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<_ReviewForm> {
  final _api      = ApiService();
  final _titleCtrl= TextEditingController();
  final _bodyCtrl = TextEditingController();
  int   _stars    = 0;
  bool  _submitting = false;

  @override void dispose() { _titleCtrl.dispose(); _bodyCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_stars == 0) return;
    setState(() => _submitting = true);
    try {
      await _api.post('/mall/products/${widget.productId}/reviews', data: {
        'productId': widget.productId,
        'storeId':   '00000000-0000-0000-0000-000000000000',
        'stars':     _stars,
        'title':     _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        'body':      _bodyCtrl.text.trim().isEmpty  ? null : _bodyCtrl.text.trim(),
      });
      widget.onSubmit();
    } catch (_) {} finally { if (mounted) setState(() => _submitting = false); }
  }

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('تقييمك', style: TextStyle(
        color: AppTheme.textPri, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (i) => GestureDetector(
          onTap: () => setState(() => _stars = i + 1),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Icon(i < _stars ? Icons.star : Icons.star_border,
              color: const Color(0xFFF59E0B), size: 36))))),
      const SizedBox(height: 12),
      TextField(controller: _titleCtrl, decoration: const InputDecoration(
        hintText: 'عنوان التقييم (اختياري)')),
      const SizedBox(height: 8),
      TextField(controller: _bodyCtrl, maxLines: 3,
        decoration: const InputDecoration(hintText: 'شارك تجربتك بالتفصيل...')),
      const SizedBox(height: 12),
      ElevatedButton(
        onPressed: _stars == 0 || _submitting ? null : _submit,
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 44)),
        child: _submitting
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('إرسال التقييم')),
    ]));
}

class _ReviewCard extends StatelessWidget {
  final Map review;
  final String productId;
  final VoidCallback onHelpful;
  const _ReviewCard({required this.review, required this.productId, required this.onHelpful});

  @override
  Widget build(BuildContext context) {
    final stars = review['stars'] as int? ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: AppTheme.primary.withOpacity(0.15),
            child: Text((review['authorName'] as String? ?? '؟')[0],
              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(review['authorName'] ?? '',
                style: const TextStyle(color: AppTheme.textPri,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              if (review['isVerified'] == true) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                  child: const Text('✓ موثق', style: TextStyle(
                    color: AppTheme.secondary, fontSize: 9, fontWeight: FontWeight.w700))),
              ],
            ]),
            Row(children: List.generate(5, (i) => Icon(
              i < stars ? Icons.star : Icons.star_border,
              color: const Color(0xFFF59E0B), size: 12))),
          ])),
          Text(review['timeAgo'] ?? '',
            style: const TextStyle(color: AppTheme.textSec, fontSize: 10)),
        ]),
        if (review['title'] != null) ...[
          const SizedBox(height: 8),
          Text(review['title'], style: const TextStyle(
            color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 14)),
        ],
        if (review['body'] != null) ...[
          const SizedBox(height: 6),
          Text(review['body'], style: const TextStyle(
            color: AppTheme.textSec, fontSize: 13, height: 1.5)),
        ],
        // Store reply
        if (review['storeReply'] != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primary.withOpacity(0.2))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.storefront_outlined, color: AppTheme.primary, size: 14),
              const SizedBox(width: 8),
              Expanded(child: Text(review['storeReply'],
                style: const TextStyle(color: AppTheme.textSec, fontSize: 12))),
            ])),
        ],
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onHelpful,
          child: Row(children: [
            const Icon(Icons.thumb_up_outlined, color: AppTheme.textSec, size: 14),
            const SizedBox(width: 4),
            Text('مفيد (${review['helpfulCount'] ?? 0})',
              style: const TextStyle(color: AppTheme.textSec, fontSize: 12)),
          ])),
      ]));
  }
}
