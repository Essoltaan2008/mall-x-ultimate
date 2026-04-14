import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../data/services/api_service.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/common/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  ORDERS HISTORY SCREEN
// ══════════════════════════════════════════════════════════════════════════
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});
  @override State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final _api    = ApiService();
  List<Map> _orders = [];
  bool _loading = true;
  int  _page    = 1;
  bool _hasMore = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) { _page = 1; _hasMore = true; }
    setState(() => _loading = true);
    try {
      final res = await _api.get(
        '${ApiEndpoints.orders}?page=$_page&size=20');
      final items = List<Map>.from(res.data['data'] ?? []);
      setState(() {
        if (refresh) _orders = items;
        else _orders.addAll(items);
        _hasMore = items.length >= 20;
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('طلباتي')),
    body: _loading && _orders.isEmpty
      ? const ShimmerList()
      : _orders.isEmpty
        ? EmptyState(
            emoji: '📦', title: 'لا توجد طلبات بعد',
            subtitle: 'ابدأ التسوق واستمتع بتجربة MallX',
            buttonLabel: 'تسوق الآن',
            onAction: () => AppRouter.pop())
        : RefreshIndicator(
            onRefresh: () => _load(refresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _orders.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                if (i == _orders.length) {
                  _page++;
                  _load();
                  return const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()));
                }
                return _OrderCard(order: _orders[i]);
              })));
}

// ── Order Card ────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final Map order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status  = order['status'] as String? ?? 'Placed';
    final color   = AppTheme.statusColor(status);
    final placed  = DateTime.tryParse(order['placedAt'] ?? '');

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: order['id']))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border),
          borderLeft: Border(right: BorderSide(color: color, width: 3))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(order['orderNumber'] ?? '',
                style: const TextStyle(
                  color: AppTheme.textPri,
                  fontWeight: FontWeight.w800, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8)),
                child: Text(kOrderStatusAr[status] ?? status,
                  style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.storefront_outlined, color: AppTheme.textSec, size: 13),
              const SizedBox(width: 5),
              Expanded(child: Text(
                List<Map>.from(order['storeOrders'] ?? [])
                  .map((s) => s['storeName']).join(' + '),
                style: const TextStyle(color: AppTheme.textSec, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              if (placed != null)
                Text(
                  '${placed.day}/${placed.month}/${placed.year} '
                  '${placed.hour}:${placed.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(color: AppTheme.textMut, fontSize: 11)),
              Text('${order['total'] ?? 0} ${AppStrings.egpUnit}',
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ]))));
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  ORDER DETAIL SCREEN
// ══════════════════════════════════════════════════════════════════════════
class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  const OrderDetailScreen({super.key, required this.orderId});
  @override State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _api = ApiService();
  Map? _order;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await _api.get(ApiEndpoints.order(widget.orderId));
      setState(() { _order = res.data['data']; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _reorder() async {
    // Save as reorder template then navigate to cart
    try {
      await _api.post(ApiEndpoints.savedOrders, data: {
        'name':        'إعادة طلب ${_order!['orderNumber']}',
        'mallOrderId': widget.orderId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ تمت إضافة العناصر للسلة!')));
      AppRouter.pop();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: ShimmerList());
    if (_order == null) return Scaffold(
      appBar: AppBar(), body: const ErrorState(message: 'تعذر تحميل الطلب'));

    final status    = _order!['status'] as String? ?? '';
    final placed    = DateTime.tryParse(_order!['placedAt'] ?? '');
    final delivered = DateTime.tryParse(_order!['deliveredAt'] ?? '');
    final storeOrders = List<Map>.from(_order!['storeOrders'] ?? []);
    final canReorder = _order!['canReorder'] == true;
    final canRate    = _order!['canRate']    == true;

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب ${_order!['orderNumber']}'),
        actions: [
          if (status == 'Placed' || status == 'Confirmed')
            TextButton(
              onPressed: _showCancelDialog,
              child: const Text('إلغاء',
                style: TextStyle(color: AppTheme.error))),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Status Banner ──────────────────────────────────────────────
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.statusColor(status).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.statusColor(status).withOpacity(0.25))),
            child: Row(children: [
              Text(_statusEmoji(status),
                style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(kOrderStatusAr[status] ?? status,
                  style: TextStyle(
                    color: AppTheme.statusColor(status),
                    fontSize: 18, fontWeight: FontWeight.w900)),
                if (placed != null)
                  Text(
                    'بُدئ: ${placed.day}/${placed.month}/${placed.year}',
                    style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
                if (delivered != null)
                  Text(
                    'تسليم: ${delivered.day}/${delivered.month}/${delivered.year}',
                    style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
              ])),
            ])),

          const SizedBox(height: 16),

          // ── Store Orders ───────────────────────────────────────────────
          const Text('المحلات والمنتجات',
            style: TextStyle(color: AppTheme.textPri,
              fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 8),
          ...storeOrders.map((so) => _StoreOrderCard(storeOrder: so)),

          const SizedBox(height: 16),

          // ── Delivery Info ──────────────────────────────────────────────
          if (_order!['deliveryAddress'] != null)
            _InfoSection('عنوان التوصيل', [
              ('📍', _order!['deliveryAddress'] ?? ''),
              if (_order!['driverName'] != null)
                ('🚗', 'السائق: ${_order!['driverName']}'),
            ]),

          // ── Payment Summary ────────────────────────────────────────────
          _InfoSection('ملخص الدفع', [
            ('💳', kPaymentAr[_order!['paymentMethod']] ?? _order!['paymentMethod'] ?? ''),
            ('🚗', '${kFulfillmentAr[_order!['fulfillmentType']] ?? ''} — رسوم ${_order!['deliveryFee'] ?? 0} ج.م'),
          ]),

          // ── Price Breakdown ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border)),
            child: Column(children: [
              _priceRow('المجموع', '${_order!['subtotal'] ?? 0} ج.م'),
              if ((_order!['deliveryFee'] as num? ?? 0) > 0)
                _priceRow('التوصيل', '${_order!['deliveryFee']} ج.م'),
              if ((_order!['discountAmount'] as num? ?? 0) > 0)
                _priceRow('الخصم', '-${_order!['discountAmount']} ج.م',
                  color: AppTheme.secondary),
              const Divider(color: AppTheme.border, height: 16),
              _priceRow('الإجمالي', '${_order!['total'] ?? 0} ج.م',
                bold: true),
            ])),

          const SizedBox(height: 20),

          // ── Action Buttons ─────────────────────────────────────────────
          if (status == 'Delivered' || status == 'PickedUp') ...[
            ElevatedButton.icon(
              onPressed: () => AppRouter.push(AppRouter.trackOrder, {
                'orderId':     widget.orderId,
                'orderNumber': _order!['orderNumber'] ?? '',
                'accessToken': '',
              }),
              icon: const Icon(Icons.location_on_outlined, size: 18),
              label: const Text('تتبع الطلب'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50))),
            const SizedBox(height: 10),
          ],
          if (canRate) ...[
            OutlinedButton.icon(
              onPressed: () {
                final firstStore = storeOrders.isNotEmpty ? storeOrders.first : null;
                AppRouter.push(AppRouter.rateStore, {
                  'mallOrderId': widget.orderId,
                  'storeId':     firstStore?['storeId'] ?? '',
                  'storeName':   firstStore?['storeName'] ?? '',
                });
              },
              icon: const Icon(Icons.star_outline, size: 18),
              label: const Text('قيّم طلبك'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accent,
                side: const BorderSide(color: AppTheme.accent),
                minimumSize: const Size(double.infinity, 50))),
            const SizedBox(height: 10),
          ],
          if (canReorder)
            OutlinedButton.icon(
              onPressed: _reorder,
              icon: const Icon(Icons.replay_outlined, size: 18),
              label: const Text('إعادة الطلب'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.secondary,
                side: const BorderSide(color: AppTheme.secondary),
                minimumSize: const Size(double.infinity, 50))),

          const SizedBox(height: 24),
        ])),
    );
  }

  Future<void> _showCancelDialog() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد أنك تريد إلغاء الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('لا')),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('نعم، إلغاء',
              style: TextStyle(color: AppTheme.error))),
        ]));

    if (confirm == true && mounted) {
      try {
        await _api.patch(ApiEndpoints.updateStatus(widget.orderId),
          data: {'status': 'Cancelled', 'note': 'إلغاء من العميل'});
        _load();
      } catch (_) {}
    }
  }

  Widget _InfoSection(String title, List<(String, String)> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: const TextStyle(
          color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 14))),
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: rows.map((r) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Text(r.$1, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 8),
              Expanded(child: Text(r.$2,
                style: const TextStyle(
                  color: AppTheme.textSec, fontSize: 13))),
            ]))).toList())),
    ]);

  Widget _priceRow(String label, String val,
      {bool bold = false, Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(color: AppTheme.textSec, fontSize: 13)),
      Text(val, style: TextStyle(
        color: color ?? AppTheme.textPri, fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ]));

  static String _statusEmoji(String s) => switch(s) {
    'Placed'    => '📋', 'Confirmed' => '✅',
    'Preparing' => '👨‍🍳', 'Ready'     => '🎁',
    'PickedUp'  => '🚗', 'Delivered' => '🏠',
    'Cancelled' => '❌', _ => '📦',
  };
}

// ── Store Order Card ───────────────────────────────────────────────────────
class _StoreOrderCard extends StatelessWidget {
  final Map storeOrder;
  const _StoreOrderCard({required this.storeOrder});

  @override
  Widget build(BuildContext context) {
    final status = storeOrder['status'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.statusColor(status).withOpacity(0.06),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12), topLeft: Radius.circular(12))),
          child: Row(children: [
            const Icon(Icons.storefront_outlined, color: AppTheme.textSec, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(storeOrder['storeName'] ?? '',
              style: const TextStyle(
                color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.statusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(8)),
              child: Text(kOrderStatusAr[status] ?? status,
                style: TextStyle(
                  color: AppTheme.statusColor(status),
                  fontSize: 10, fontWeight: FontWeight.w700))),
          ])),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: List<Map>.from(storeOrder['items'] ?? []).map((item) =>
              Padding(padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6)),
                    child: Center(child: Text('${item['quantity']}',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11, fontWeight: FontWeight.w800)))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item['productName'] ?? '',
                    style: const TextStyle(color: AppTheme.textSec, fontSize: 13))),
                  Text('${item['total']} ج.م',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600, fontSize: 12)),
                ]))).toList())),
      ]));
  }
}
