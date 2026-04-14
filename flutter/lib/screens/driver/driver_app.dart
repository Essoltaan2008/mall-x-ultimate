import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:signalr_netcore/signalr_client.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/api_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// ══════════════════════════════════════════════════════════════════════════
//  DRIVER APP — Main Screen
//  GPS tracking + order pickup list + status updates
// ══════════════════════════════════════════════════════════════════════════

const String _hubUrl    = 'http://YOUR_SERVER_IP:5000/hubs/drivers';
const String _serverUrl = 'http://YOUR_SERVER_IP:5000';

class DriverApp extends StatefulWidget {
  final String driverId;
  const DriverApp({super.key, required this.driverId});
  @override State<DriverApp> createState() => _DriverAppState();
}

class _DriverAppState extends State<DriverApp> with WidgetsBindingObserver {
  final _api     = ApiService();
  final _storage = const FlutterSecureStorage();

  // State
  bool    _isOnline    = false;
  bool    _tracking    = false;
  double? _lat, _lng;
  int     _activeOrders = 0;
  List<Map> _orders    = [];

  // Hub
  HubConnection? _hub;
  Timer? _locationTimer;
  StreamSubscription<Position>? _posStream;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadOrders();
    _connectHub();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _posStream?.cancel();
    _hub?.stop();
    super.dispose();
  }

  Future<void> _connectHub() async {
    final token = await _storage.read(key: 'access_token');
    _hub = HubConnectionBuilder()
        .withUrl('$_hubUrl?access_token=$token',
            options: HttpConnectionOptions(
              transport: HttpTransportType.WebSockets,
              skipNegotiation: true))
        .withAutomaticReconnect()
        .build();

    await _hub!.start();
    await _hub!.invoke('JoinDriverRoom', args: [widget.driverId]);
  }

  Future<void> _loadOrders() async {
    try {
      final res = await _api.get('/mall/store/orders/incoming');
      setState(() {
        _orders = List<Map>.from(res.data['data'] ?? [])
          .where((o) => o['status'] == 'Ready' || o['status'] == 'PickedUp')
          .toList();
        _activeOrders = _orders.length;
      });
    } catch (_) {}
  }

  Future<void> _toggleOnline() async {
    if (_isOnline) {
      _stopTracking();
    } else {
      final hasPermission = await _requestLocationPermission();
      if (!hasPermission) {
        _showSnack('يجب السماح بالوصول للموقع');
        return;
      }
      _startTracking();
    }
    setState(() => _isOnline = !_isOnline);
  }

  Future<bool> _requestLocationPermission() async {
    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied)
      status = await Geolocator.requestPermission();
    return status == LocationPermission.always ||
           status == LocationPermission.whileInUse;
  }

  void _startTracking() {
    setState(() => _tracking = true);
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    ).listen((pos) async {
      if (!mounted) return;
      setState(() { _lat = pos.latitude; _lng = pos.longitude; });

      // Push to SignalR
      await _hub?.invoke('UpdateLocation', args: [
        widget.driverId, pos.latitude, pos.longitude,
      ]);
    });
  }

  void _stopTracking() {
    setState(() => _tracking = false);
    _posStream?.cancel();
    _posStream = null;
  }

  Future<void> _pickupOrder(String mallOrderId, String orderNum) async {
    try {
      await _api.patch('/mall/store/orders/$mallOrderId/status',
        data: {'status': 'PickedUp', 'note': 'السائق استلم الطلب'});
      _showSnack('✅ تم تسجيل استلام طلب $orderNum');
      _loadOrders();
    } catch (_) { _showSnack('❌ تعذر التحديث'); }
  }

  Future<void> _deliverOrder(String mallOrderId, String orderNum) async {
    try {
      await _api.patch('/mall/store/orders/$mallOrderId/status',
        data: {'status': 'Delivered', 'note': 'تم التسليم'});
      _showSnack('🎉 تم تسليم طلب $orderNum بنجاح!');
      _loadOrders();
    } catch (_) { _showSnack('❌ تعذر التحديث'); }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg),
        duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: Row(children: [
          const Text('تطبيق السائق'),
          if (_tracking) ...[
            const SizedBox(width: 10),
            Container(
              width: 8, height: 8,
              decoration: const BoxDecoration(
                color: AppTheme.secondary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            const Text('GPS', style: TextStyle(
              color: AppTheme.secondary, fontSize: 11)),
          ],
        ]),
        actions: [
          Padding(padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadOrders)),
        ],
      ),
      body: Column(children: [

        // ── Online Toggle ─────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _isOnline
                ? [AppTheme.secondary.withOpacity(0.25), AppTheme.surface]
                : [AppTheme.card, AppTheme.surface],
              begin: Alignment.topCenter, end: Alignment.bottomCenter),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isOnline
                ? AppTheme.secondary.withOpacity(0.4) : AppTheme.border)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _isOnline ? '🟢 أنت متاح' : '⚫ أنت غير متاح',
                style: TextStyle(
                  color: _isOnline ? AppTheme.secondary : AppTheme.textSec,
                  fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 4),
              Text(
                _isOnline
                  ? 'يمكن تعيين طلبات لك الآن'
                  : 'فعّل للاستقبال والتتبع',
                style: const TextStyle(color: AppTheme.textSec, fontSize: 13)),
              if (_lat != null && _lng != null) ...[
                const SizedBox(height: 4),
                Text(
                  '📍 ${_lat!.toStringAsFixed(4)}, ${_lng!.toStringAsFixed(4)}',
                  style: const TextStyle(color: AppTheme.textSec, fontSize: 10)),
              ],
            ])),
            GestureDetector(
              onTap: _toggleOnline,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 64, height: 34,
                decoration: BoxDecoration(
                  color: _isOnline ? AppTheme.secondary : AppTheme.border,
                  borderRadius: BorderRadius.circular(17)),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  alignment: _isOnline
                    ? Alignment.centerLeft : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.all(3),
                    width: 28, height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      _isOnline ? Icons.navigation : Icons.navigation_outlined,
                      color: _isOnline ? AppTheme.secondary : AppTheme.textSec,
                      size: 16)),
                )),
            ),
          ]),
        ),

        // ── Stats ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            _statCard('الطلبات النشطة', '$_activeOrders', Icons.assignment_outlined, AppTheme.primary),
            const SizedBox(width: 10),
            _statCard('حالة الموقع', _tracking ? 'نشط' : 'متوقف',
              Icons.location_on_outlined,
              _tracking ? AppTheme.secondary : AppTheme.textSec),
          ].map((w) => Expanded(child: w)).toList())),

        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(alignment: Alignment.centerRight,
            child: Text('طلبات للاستلام والتوصيل', style: TextStyle(
              color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 15)))),
        const SizedBox(height: 8),

        // ── Orders List ───────────────────────────────────────────────
        Expanded(
          child: _orders.isEmpty
            ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.delivery_dining, color: AppTheme.textSec, size: 56),
                const SizedBox(height: 16),
                Text(_isOnline ? 'لا توجد طلبات حالياً' : 'فعّل التتبع لاستقبال الطلبات',
                  style: const TextStyle(color: AppTheme.textSec)),
              ]))
            : RefreshIndicator(
                onRefresh: _loadOrders,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _orders.length,
                  itemBuilder: (_, i) => _OrderDriverCard(
                    order: _orders[i],
                    onPickup:  () => _pickupOrder(
                        _orders[i]['id'], _orders[i]['orderNumber']),
                    onDeliver: () => _deliverOrder(
                        _orders[i]['id'], _orders[i]['orderNumber']),
                  ),
                )),
        ),
      ]),
    );
  }

  Widget _statCard(String label, String val, IconData icon, Color color) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(val, style: TextStyle(
            color: color, fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: const TextStyle(
            color: AppTheme.textSec, fontSize: 10)),
        ]),
      ]));
}

// ─── Order Card for Driver ────────────────────────────────────────────────
class _OrderDriverCard extends StatelessWidget {
  final Map order;
  final VoidCallback onPickup, onDeliver;
  const _OrderDriverCard({
    required this.order, required this.onPickup, required this.onDeliver});

  @override
  Widget build(BuildContext context) {
    final status   = order['status'] as String? ?? '';
    final isReady  = status == 'Ready';
    final isPicked = status == 'PickedUp';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isReady ? AppTheme.secondary.withOpacity(0.4)
               : isPicked ? AppTheme.primary.withOpacity(0.4)
               : AppTheme.border),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isReady ? AppTheme.secondary.withOpacity(0.08)
                 : AppTheme.primary.withOpacity(0.06),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(14), topLeft: Radius.circular(14))),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(order['orderNumber'] ?? '',
                style: const TextStyle(
                  color: AppTheme.textPri, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 2),
              Text(
                isReady  ? '✅ جاهز للاستلام من المحل' :
                isPicked ? '🚗 في الطريق للعميل' : status,
                style: TextStyle(
                  color: isReady ? AppTheme.secondary : AppTheme.primary,
                  fontSize: 12, fontWeight: FontWeight.w600)),
            ])),
            Text('${order['total'] ?? 0} ج.م',
              style: const TextStyle(
                color: AppTheme.primary, fontWeight: FontWeight.w900, fontSize: 16)),
          ])),

        // Details
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (order['customerName'] != null)
              _row(Icons.person_outline, order['customerName']),
            if (order['deliveryAddress'] != null)
              _row(Icons.location_on_outlined, order['deliveryAddress']),
            if (order['customerPhone'] != null)
              _row(Icons.phone_outlined, order['customerPhone']),

            if ((order['storeOrders'] as List?)?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              const Text('المحلات للاستلام:',
                style: TextStyle(color: AppTheme.textSec, fontSize: 11)),
              ...(order['storeOrders'] as List).map((so) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(children: [
                  const Icon(Icons.storefront_outlined,
                    color: AppTheme.textSec, size: 12),
                  const SizedBox(width: 6),
                  Text(so['storeName'] ?? '',
                    style: const TextStyle(
                      color: AppTheme.textSec, fontSize: 12)),
                ]))),
            ],

            const SizedBox(height: 12),
            if (isReady)
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onPickup,
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('استلمت الطلب من المحل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondary,
                    padding: const EdgeInsets.symmetric(vertical: 12))))
            else if (isPicked)
              SizedBox(width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onDeliver,
                  icon: const Icon(Icons.home, size: 16),
                  label: const Text('تم التسليم للعميل ✅'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12)))),
          ])),
      ]));
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(children: [
      Icon(icon, color: AppTheme.textSec, size: 14),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(
        color: AppTheme.textSec, fontSize: 13),
        maxLines: 2, overflow: TextOverflow.ellipsis)),
    ]));
}
