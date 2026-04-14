import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';

// ══════════════════════════════════════════════════════════════════════════
//  CHECKOUT SCREEN
//  Shows: store order summary → address → payment → discount → confirm
// ══════════════════════════════════════════════════════════════════════════
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _api = ApiService();

  // Payment
  String _paymentMethod = 'Cash';
  bool   _useWallet     = false;
  bool   _usePoints     = false;

  // Coupon
  final _couponCtrl = TextEditingController();
  String? _couponCode;
  double  _couponDiscount = 0;
  String? _couponMsg;
  bool    _applyingCoupon = false;

  // Loyalty
  double  _pointsDiscount = 0;

  // Wallet
  double  _walletBalance  = 0;
  double  _walletDiscount = 0;

  // Address
  final _addressCtrl = TextEditingController();
  String _fulfillment = 'Delivery';

  // Placing
  bool _placing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadWalletBalance();
    });
  }

  @override
  void dispose() {
    _couponCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadWalletBalance() async {
    try {
      final auth = context.read<AuthProvider>();
      final res  = await _api.get('/mall/wallet?mallId=${auth.mallId}');
      setState(() => _walletBalance = (res.data['data']?['balance'] as num?)?.toDouble() ?? 0);
    } catch (_) {}
  }

  Future<void> _applyCoupon() async {
    if (_couponCtrl.text.trim().isEmpty) return;
    setState(() { _applyingCoupon = true; _couponMsg = null; });
    try {
      final cartProvider = context.read<CartProvider>();
      final orderId = '00000000-0000-0000-0000-000000000000'; // pre-checkout apply
      final res = await _api.post('/mall/promotions/coupon/apply', data: {
        'code':        _couponCtrl.text.trim().toUpperCase(),
        'mallOrderId': orderId,
      });
      if (res.data['success'] == true) {
        final data = res.data['data'];
        setState(() {
          _couponCode     = data['code'];
          _couponDiscount = (data['discountAmt'] as num?)?.toDouble() ?? 0;
          _couponMsg      = data['message'];
        });
      } else {
        setState(() => _couponMsg = res.data['error']);
      }
    } catch (e) {
      setState(() => _couponMsg = 'كود غير صالح');
    }
    setState(() => _applyingCoupon = false);
  }

  double get _subtotal => context.read<CartProvider>().total;
  double get _totalAfterDiscounts {
    var t = _subtotal;
    t -= _couponDiscount;
    if (_usePoints) t -= _pointsDiscount;
    if (_useWallet) t -= _walletDiscount;
    return t.clamp(0, double.infinity);
  }

  Future<void> _placeOrder() async {
    if (_fulfillment == 'Delivery' && _addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'أدخل عنوان التوصيل.');
      return;
    }

    setState(() { _placing = true; _error = null; });

    try {
      final orderProvider = context.read<OrderProvider>();
      final body = {
        'fulfillmentType': _fulfillment,
        'paymentMethod':   _paymentMethod,
        'deliveryAddress': _addressCtrl.text.trim(),
        'couponCode':      _couponCode,
        'useWallet':       _useWallet,
        'walletAmount':    _useWallet ? _walletDiscount : 0,
        'usePoints':       _usePoints,
        'pointsToRedeem':  _usePoints ? (_pointsDiscount * 100).round() : 0,
        'note':            null,
      };

      final result = await orderProvider.checkout(body);

      if (!mounted) return;

      if (result != null) {
        // Clear cart
        await context.read<CartProvider>().clear();

        // Navigate to tracking
        AppRouter.replace(AppRouter.trackOrder, {
          'orderId':     result['id'],
          'orderNumber': result['orderNumber'],
          'accessToken': await const FlutterSecureStorageHelper().getToken(),
        });
      } else {
        setState(() => _error = 'تعذر إتمام الطلب. حاول مجدداً.');
      }
    } catch (e) {
      setState(() => _error = 'حدث خطأ. تحقق من اتصالك وحاول مجدداً.');
    }

    if (mounted) setState(() => _placing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cart        = context.watch<CartProvider>();
    final loyalty     = context.watch<LoyaltyProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('إتمام الطلب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Order Summary ──────────────────────────────────────────────
          _SectionCard(
            title: '🛒 ملخص الطلب',
            child: Column(children: [
              ...cart.stores.expand((store) => [
                // Store header
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    const Icon(Icons.storefront_outlined,
                      color: AppTheme.textSec, size: 14),
                    const SizedBox(width: 6),
                    Text(store['storeName'] ?? '',
                      style: const TextStyle(
                        color: AppTheme.textSec, fontWeight: FontWeight.w600, fontSize: 12)),
                  ])),
                // Items
                ...List<Map>.from(store['items'] ?? []).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8, right: 20),
                  child: Row(children: [
                    Expanded(child: Text(
                      '${item['quantity']}× ${item['productName']}',
                      style: const TextStyle(color: AppTheme.textPri, fontSize: 13))),
                    Text('${item['total']} ج.م',
                      style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600)),
                  ]))),
              ]),
              const Divider(color: AppTheme.border),
              _PriceLine('المجموع الفرعي',   '${_subtotal.toStringAsFixed(2)} ج.م'),
              if (_couponDiscount > 0)
                _PriceLine('كوبون $_couponCode', '-${_couponDiscount.toStringAsFixed(2)} ج.م',
                  color: AppTheme.secondary),
              if (_usePoints && _pointsDiscount > 0)
                _PriceLine('نقاط الولاء',      '-${_pointsDiscount.toStringAsFixed(2)} ج.م',
                  color: AppTheme.secondary),
              if (_useWallet && _walletDiscount > 0)
                _PriceLine('المحفظة',           '-${_walletDiscount.toStringAsFixed(2)} ج.م',
                  color: AppTheme.secondary),
              const SizedBox(height: 4),
              _PriceLine('الإجمالي',
                '${_totalAfterDiscounts.toStringAsFixed(2)} ج.م',
                bold: true, color: AppTheme.primary),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Fulfillment ────────────────────────────────────────────────
          _SectionCard(
            title: '🚗 طريقة الاستلام',
            child: Column(children: [
              Row(children: [
                Expanded(child: _FulfillmentBtn(
                  label: 'توصيل للمنزل',
                  icon:  Icons.delivery_dining,
                  selected: _fulfillment == 'Delivery',
                  onTap: () => setState(() => _fulfillment = 'Delivery'),
                )),
                const SizedBox(width: 10),
                Expanded(child: _FulfillmentBtn(
                  label: 'استلام من المحل',
                  icon:  Icons.storefront_outlined,
                  selected: _fulfillment == 'Pickup',
                  onTap: () => setState(() => _fulfillment = 'Pickup'),
                )),
              ]),
              if (_fulfillment == 'Delivery') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    hintText: 'أدخل عنوان التوصيل بالتفصيل...',
                    prefixIcon: Icon(Icons.location_on_outlined)),
                  maxLines: 2,
                ),
              ],
            ]),
          ),

          const SizedBox(height: 12),

          // ── Payment Method ─────────────────────────────────────────────
          _SectionCard(
            title: '💳 طريقة الدفع',
            child: Column(children: [
              ...['Cash', 'Card', 'Fawry'].map((method) {
                final labels = {
                  'Cash':  '💵 كاش عند الاستلام',
                  'Card':  '💳 بطاقة ائتمانية',
                  'Fawry': '🟡 فوري',
                };
                return RadioListTile<String>(
                  title:    Text(labels[method]!,
                    style: const TextStyle(color: AppTheme.textPri, fontSize: 14)),
                  value:    method,
                  groupValue: _paymentMethod,
                  onChanged: (v) => setState(() => _paymentMethod = v!),
                  dense: true,
                  activeColor: AppTheme.primary,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ]),
          ),

          const SizedBox(height: 12),

          // ── Coupon ─────────────────────────────────────────────────────
          _SectionCard(
            title: '🎟️ كوبون خصم',
            child: Column(children: [
              Row(children: [
                Expanded(child: TextField(
                  controller: _couponCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'أدخل كود الكوبون...'),
                )),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _applyingCoupon ? null : _applyCoupon,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(80, 52),
                    backgroundColor: AppTheme.secondary),
                  child: _applyingCoupon
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('تطبيق')),
              ]),
              if (_couponMsg != null) ...[
                const SizedBox(height: 8),
                Text(_couponMsg!,
                  style: TextStyle(
                    color: _couponDiscount > 0 ? AppTheme.secondary : AppTheme.error,
                    fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ]),
          ),

          const SizedBox(height: 12),

          // ── Loyalty Points ─────────────────────────────────────────────
          if (loyalty.points > 0)
            _SectionCard(
              title: '⭐ نقاط الولاء',
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('لديك ${loyalty.points} نقطة',
                    style: const TextStyle(color: AppTheme.textPri, fontWeight: FontWeight.w600)),
                  Text('= ${loyalty.egpValue.toStringAsFixed(2)} ج.م (حتى 20% من الطلب)',
                    style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
                ])),
                Switch(
                  value:      _usePoints,
                  onChanged:  (v) => setState(() {
                    _usePoints     = v;
                    _pointsDiscount= v
                      ? (loyalty.egpValue).clamp(0, _subtotal * 0.2)
                      : 0;
                  }),
                  activeColor: AppTheme.primary,
                ),
              ]),
            ),

          const SizedBox(height: 12),

          // ── Wallet ─────────────────────────────────────────────────────
          if (_walletBalance > 0)
            _SectionCard(
              title: '💰 المحفظة',
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('رصيد المحفظة: ${_walletBalance.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(color: AppTheme.textPri, fontWeight: FontWeight.w600)),
                  const Text('يمكن استخدام كامل الرصيد',
                    style: TextStyle(color: AppTheme.textSec, fontSize: 11)),
                ])),
                Switch(
                  value:     _useWallet,
                  onChanged: (v) => setState(() {
                    _useWallet     = v;
                    _walletDiscount= v
                      ? _walletBalance.clamp(0, _subtotal)
                      : 0;
                  }),
                  activeColor: AppTheme.primary,
                ),
              ]),
            ),

          const SizedBox(height: 20),

          // ── Error ──────────────────────────────────────────────────────
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withOpacity(0.3))),
              child: Row(children: [
                const Icon(Icons.error_outline, color: AppTheme.error, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!,
                  style: const TextStyle(color: AppTheme.error, fontSize: 13))),
              ])),

          // ── Place Order Button ─────────────────────────────────────────
          ElevatedButton(
            onPressed: _placing || cart.isEmpty ? null : _placeOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            child: _placing
              ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('جاري تقديم الطلب...', style: TextStyle(fontWeight: FontWeight.w700)),
                ])
              : Text(
                  'تأكيد الطلب — ${_totalAfterDiscounts.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),

          const SizedBox(height: 8),
          const Center(child: Text(
            'بالضغط أنت توافق على شروط الاستخدام',
            style: TextStyle(color: AppTheme.textMut, fontSize: 11))),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.card, borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.border)),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 14)),
      const SizedBox(height: 12),
      child,
    ]));
}

class _PriceLine extends StatelessWidget {
  final String label, value;
  final bool bold;
  final Color? color;
  const _PriceLine(this.label, this.value,
    {this.bold = false, this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        color: AppTheme.textSec, fontSize: 13,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      Text(value, style: TextStyle(
        color: color ?? AppTheme.textPri, fontSize: 13,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600)),
    ]));
}

class _FulfillmentBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _FulfillmentBtn({required this.label, required this.icon,
    required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: selected ? AppTheme.primary.withOpacity(0.1) : AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: selected ? AppTheme.primary : AppTheme.border,
          width: selected ? 2 : 1)),
      child: Column(children: [
        Icon(icon, color: selected ? AppTheme.primary : AppTheme.textSec, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          color: selected ? AppTheme.primary : AppTheme.textSec,
          fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
      ])));
}

// ─────────────────────────────────────────────────────────────────────────
//  SECURE STORAGE HELPER (to get token for SignalR)
// ─────────────────────────────────────────────────────────────────────────
class FlutterSecureStorageHelper {
  const FlutterSecureStorageHelper();
  Future<String> getToken() async {
    const s = FlutterSecureStorage();
    return await s.read(key: 'access_token') ?? '';
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
