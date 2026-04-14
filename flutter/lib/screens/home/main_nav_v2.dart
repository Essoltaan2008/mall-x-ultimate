import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import '../../data/services/api_service.dart';
import '../../widgets/common/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  MAIN NAVIGATION — bottom nav with 5 tabs
// ══════════════════════════════════════════════════════════════════════════
class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});
  @override State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      await auth.loadCurrentUser();
      await context.read<CartProvider>().fetch();
      await context.read<NotificationProvider>().fetchUnreadCount();
      await context.read<LoyaltyProvider>().fetch(auth.mallId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifCount = context.watch<NotificationProvider>().unreadCount;
    final cartCount  = context.watch<CartProvider>().itemCount;

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          _HomeTab(),
          _CategoriesTab(),
          _CartTab(),
          _ProfileTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(children: [
              _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home,
                label: 'الرئيسية', index: 0, current: _tab,
                onTap: () => setState(() => _tab = 0)),
              _NavItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view,
                label: 'المحلات', index: 1, current: _tab,
                onTap: () => setState(() => _tab = 1)),
              _NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag,
                label: 'السلة', index: 2, current: _tab, badge: cartCount,
                onTap: () => setState(() => _tab = 2)),
              _NavItem(icon: Icons.person_outline, activeIcon: Icons.person,
                label: 'حسابي', index: 3, current: _tab, badge: notifCount,
                onTap: () => setState(() => _tab = 3)),
            ]),
          ))),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String   label;
  final int      index, current;
  final int      badge;
  final VoidCallback onTap;

  const _NavItem({required this.icon, required this.activeIcon,
    required this.label, required this.index, required this.current,
    this.badge = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sel = index == current;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 6),
        badge > 0
          ? BadgeIcon(icon: sel ? activeIcon : icon,
              count: badge, iconColor: sel ? AppTheme.primary : AppTheme.textMut)
          : Icon(sel ? activeIcon : icon,
              color: sel ? AppTheme.primary : AppTheme.textMut, size: 22),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(
          color: sel ? AppTheme.primary : AppTheme.textMut,
          fontSize: 10,
          fontWeight: sel ? FontWeight.w700 : FontWeight.normal)),
        const SizedBox(height: 4),
      ])));
  }
}

// ══════════════════════════════════════════════════════════════════════════
//  HOME TAB
// ══════════════════════════════════════════════════════════════════════════
class _HomeTab extends StatefulWidget {
  const _HomeTab();
  @override State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final _api = ApiService();
  Map? _homeData;
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadHome(); }

  Future<void> _loadHome() async {
    try {
      final auth = context.read<AuthProvider>();
      final res  = await _api.get('/mall/${auth.mallId}');
      setState(() { _homeData = res.data['data']; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final loyalty = context.watch<LoyaltyProvider>();
    final notifs  = context.watch<NotificationProvider>();

    return Scaffold(
      body: _loading ? const ShimmerList() : RefreshIndicator(
        onRefresh: _loadHome,
        child: CustomScrollView(slivers: [

          // ── App Bar ────────────────────────────────────────────────
          SliverAppBar(
            floating: true, pinned: false,
            backgroundColor: AppTheme.surface,
            title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('مرحباً بك في', style: TextStyle(
                color: AppTheme.textSec, fontSize: 12)),
              Text(auth.customer?['mallName'] ?? 'MallX',
                style: const TextStyle(
                  color: AppTheme.textPri, fontSize: 16, fontWeight: FontWeight.w900)),
            ]),
            actions: [
              IconButton(
                icon: BadgeIcon(
                  icon:  Icons.notifications_outlined,
                  count: notifs.unreadCount),
                onPressed: () => AppRouter.push(AppRouter.notifications)),
              IconButton(
                icon: const Icon(Icons.search, color: AppTheme.textSec),
                onPressed: () => AppRouter.push(AppRouter.search,
                  {'mallId': auth.mallId})),
            ],
          ),

          SliverToBoxAdapter(child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // ── Loyalty Card ───────────────────────────────────────
              if (auth.isLoggedIn)
                GestureDetector(
                  onTap: () => AppRouter.push(AppRouter.loyalty),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.tierColor(loyalty.tier).withOpacity(0.3),
                          AppTheme.surface],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppTheme.tierColor(loyalty.tier).withOpacity(0.3))),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          TierBadge(tier: loyalty.tier),
                          const Spacer(),
                          Text(loyalty.tierAr, style: TextStyle(
                            color: AppTheme.tierColor(loyalty.tier),
                            fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: 8),
                        Text('${loyalty.points}', style: TextStyle(
                          color: AppTheme.tierColor(loyalty.tier),
                          fontSize: 32, fontWeight: FontWeight.w900)),
                        Text('نقطة = ${loyalty.egpValue.toStringAsFixed(2)} ج.م',
                          style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
                        if (loyalty.nextTier != null && loyalty.pointsToNext > 0) ...[
                          const SizedBox(height: 8),
                          Text('${loyalty.pointsToNext} نقطة للـ ${loyalty.nextTier}',
                            style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: _tierProgress(loyalty),
                            backgroundColor: AppTheme.border,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.tierColor(loyalty.tier)),
                            minHeight: 4,
                          ),
                        ],
                      ])),
                      const SizedBox(width: 16),
                      const Icon(Icons.chevron_left, color: AppTheme.textSec),
                    ]))),

              const SizedBox(height: 20),

              // ── Flash Sales ────────────────────────────────────────
              if ((_homeData?['banners'] as List?)?.isNotEmpty == true) ...[
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Row(children: [
                    Icon(Icons.flash_on, color: Color(0xFFF59E0B), size: 18),
                    SizedBox(width: 4),
                    Text('عروض محدودة', style: TextStyle(
                      color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 15)),
                  ]),
                  TextButton(
                    onPressed: () => AppRouter.push(AppRouter.promotions),
                    child: const Text('الكل', style: TextStyle(
                      color: AppTheme.primary, fontSize: 12))),
                ]),
                SizedBox(height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (_homeData!['banners'] as List).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final b = (_homeData!['banners'] as List)[i];
                      return Container(
                        width: 240, padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(int.parse((b['backgroundColor'] ?? '#F59E0B')
                                .replaceFirst('#', '0xFF'))).withOpacity(0.25),
                              AppTheme.card,
                            ]),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.border)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(b['title'] ?? '', style: const TextStyle(
                            color: AppTheme.textPri, fontWeight: FontWeight.w800)),
                          if (b['subtitle'] != null)
                            Text(b['subtitle'], style: const TextStyle(
                              color: AppTheme.textSec, fontSize: 11)),
                        ]));
                    })),
                const SizedBox(height: 20),
              ],

              // ── Featured Stores ────────────────────────────────────
              _storeSection('⭐ أبرز المحلات',
                List<Map>.from(_homeData?['featured'] ?? []), auth),

              _storeSection('🍔 المطاعم',
                List<Map>.from(_homeData?['restaurants'] ?? []), auth),

              _storeSection('🛍️ المتاجر',
                List<Map>.from(_homeData?['retail'] ?? []), auth),

              _storeSection('💇 الخدمات',
                List<Map>.from(_homeData?['services'] ?? []), auth),

              // ── Quick Actions ─────────────────────────────────────
              const SizedBox(height: 8),
              Row(children: [
                _quickAction('🗺️', 'خريطة\nالمول', () => AppRouter.push(AppRouter.mallMap,
                  {'mallId': auth.mallId})),
                const SizedBox(width: 10),
                _quickAction('🤖', 'مساعد\nالذكاء', () => AppRouter.push(AppRouter.aiChat,
                  {'mallId': auth.mallId})),
                const SizedBox(width: 10),
                _quickAction('📦', 'طلباتي', () => AppRouter.push(AppRouter.home)),
                const SizedBox(width: 10),
                _quickAction('🔖', 'إعادة\nالطلب', () => AppRouter.push(AppRouter.home)),
              ]),
              const SizedBox(height: 20),
            ]))),
        ])));
  }

  double _tierProgress(LoyaltyProvider loyalty) {
    final pts = loyalty.points;
    if (pts >= 5000) return 1.0;
    if (pts >= 1000) return (pts - 1000) / 4000;
    return pts / 1000.0;
  }

  Widget _storeSection(String title, List<Map> stores, AuthProvider auth) {
    if (stores.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 10),
        child: Text(title, style: const TextStyle(
          color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 15))),
      SizedBox(height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: stores.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, i) => _StoreCard(store: stores[i], mallId: auth.mallId))),
      const SizedBox(height: 20),
    ]);
  }

  Widget _quickAction(String emoji, String label, VoidCallback onTap) =>
    Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
        child: Column(children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(
            color: AppTheme.textSec, fontSize: 10), textAlign: TextAlign.center),
        ]))));
}

class _StoreCard extends StatelessWidget {
  final Map store; final String mallId;
  const _StoreCard({required this.store, required this.mallId});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => AppRouter.push(AppRouter.storeMenu, {
      'storeId':   store['id'],
      'storeName': store['name'],
    }),
    child: Container(
      width: 130,
      decoration: BoxDecoration(
        color: AppTheme.card, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border)),
      child: Column(children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(12), topLeft: Radius.circular(12)),
          child: Container(height: 64, color: AppTheme.surface,
            child: const Center(child: Icon(Icons.storefront_outlined,
              color: AppTheme.textSec, size: 28)))),
        Padding(padding: const EdgeInsets.all(8), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(store['name'] ?? '', style: const TextStyle(
            color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 12),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          if ((store['avgRating'] as num? ?? 0) > 0)
            Row(children: [
              const Icon(Icons.star, color: Color(0xFFF59E0B), size: 11),
              Text(' ${(store['avgRating'] as num).toStringAsFixed(1)}',
                style: const TextStyle(color: AppTheme.textSec, fontSize: 10)),
            ]),
        ])),
      ])));
}

// ══════════════════════════════════════════════════════════════════════════
//  CATEGORIES TAB (Browse Stores)
// ══════════════════════════════════════════════════════════════════════════
class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('المحلات')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        ...['Restaurant','Retail','Service'].map((type) {
          final labels = {'Restaurant':'🍔 المطاعم','Retail':'🛍️ المتاجر','Service':'💇 الخدمات'};
          return GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => _StoreListScreen(mallId: auth.mallId, storeType: type))),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border)),
              child: Row(children: [
                Text(labels[type]!, style: const TextStyle(
                  color: AppTheme.textPri, fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                const Icon(Icons.chevron_left, color: AppTheme.textSec),
              ])));
        }),
      ]));
  }
}

class _StoreListScreen extends StatelessWidget {
  final String mallId, storeType;
  const _StoreListScreen({required this.mallId, required this.storeType});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppTheme.storeTypeAr(storeType))),
    body: const Center(child: Text('قائمة المحلات')));
}

// ══════════════════════════════════════════════════════════════════════════
//  CART TAB
// ══════════════════════════════════════════════════════════════════════════
class _CartTab extends StatelessWidget {
  const _CartTab();
  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('السلة (${cart.itemCount})')),
      body: cart.isEmpty
        ? EmptyState(
            emoji: '🛒', title: 'السلة فارغة',
            subtitle: 'أضف منتجات من محلاتك المفضلة',
            buttonLabel: 'تسوق الآن',
            onAction: () {})
        : Column(children: [
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: cart.stores.length,
              itemBuilder: (_, i) => _CartStoreGroup(group: cart.stores[i]))),
            // Checkout button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.surface,
                border: Border(top: BorderSide(color: AppTheme.border))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('الإجمالي', style: TextStyle(
                    color: AppTheme.textPri, fontWeight: FontWeight.w700)),
                  Text('${cart.total.toStringAsFixed(2)} ج.م',
                    style: const TextStyle(color: AppTheme.primary,
                      fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => AppRouter.push('/checkout'),
                  child: const Text('إتمام الطلب')),
              ])),
          ]));
  }
}

class _CartStoreGroup extends StatelessWidget {
  final Map group;
  const _CartStoreGroup({required this.group});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(bottom: 8),
        child: Text(group['storeName'] ?? '',
          style: const TextStyle(
            color: AppTheme.textSec, fontWeight: FontWeight.w600, fontSize: 12))),
      ...List<Map>.from(group['items'] ?? []).map((item) =>
        _CartItemRow(item: item)),
      const SizedBox(height: 12),
    ]);
}

class _CartItemRow extends StatelessWidget {
  final Map item;
  const _CartItemRow({required this.item});
  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final qty  = item['quantity'] as int? ?? 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['productName'] ?? '', style: const TextStyle(
            color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 13)),
          PriceTag(price: (item['unitPrice'] as num?)?.toDouble() ?? 0),
        ])),
        Row(children: [
          _QtyBtn(Icons.remove, () => cart.updateQty(item['productId'], qty - 1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text('$qty', style: const TextStyle(
              color: AppTheme.textPri, fontWeight: FontWeight.w800, fontSize: 15))),
          _QtyBtn(Icons.add, () => cart.updateQty(item['productId'], qty + 1)),
        ]),
      ]));
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _QtyBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: 28, height: 28,
      decoration: BoxDecoration(color: AppTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border)),
      child: Icon(icon, color: AppTheme.primary, size: 16)));
}

// ══════════════════════════════════════════════════════════════════════════
//  PROFILE TAB
// ══════════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();
  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final loyalty = context.watch<LoyaltyProvider>();
    final customer= auth.customer;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي'),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_outlined),
            onPressed: () => AppRouter.push(AppRouter.notifications)),
        ]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Profile card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: AppTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border)),
          child: Row(children: [
            CircleAvatar(radius: 28, backgroundColor: AppTheme.primary.withOpacity(0.15),
              child: Text(
                (customer?['firstName'] as String? ?? 'U')[0].toUpperCase(),
                style: const TextStyle(color: AppTheme.primary,
                  fontSize: 22, fontWeight: FontWeight.w900))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${customer?['firstName'] ?? ''} ${customer?['lastName'] ?? ''}',
                style: const TextStyle(color: AppTheme.textPri,
                  fontWeight: FontWeight.w800, fontSize: 16)),
              Text(customer?['email'] ?? '',
                style: const TextStyle(color: AppTheme.textSec, fontSize: 12)),
              const SizedBox(height: 6),
              TierBadge(tier: loyalty.tier),
            ])),
          ])),

        const SizedBox(height: 16),

        // Menu items
        ...[
          ('⭐', 'نقاط الولاء',       AppRouter.loyalty),
          ('💰', 'محفظتي',           AppRouter.wallet),
          ('🎁', 'إحالة صديق',       AppRouter.referral),
          ('📦', 'طلباتي',           ''),
          ('🔔', 'الإشعارات',         AppRouter.notifications),
          ('🗺️', 'خريطة المول',      AppRouter.mallMap),
          ('🤖', 'المساعد الذكي',     AppRouter.aiChat),
        ].map((item) => ListTile(
          leading: Text(item.$1, style: const TextStyle(fontSize: 20)),
          title:   Text(item.$2, style: const TextStyle(
            color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: const Icon(Icons.chevron_left, color: AppTheme.textSec),
          onTap:   () {
            if (item.$3.isEmpty) return;
            AppRouter.push(item.$3, {'mallId': auth.mallId});
          })),

        const Divider(color: AppTheme.border),

        ListTile(
          leading: const Text('🚪', style: TextStyle(fontSize: 20)),
          title:   const Text('تسجيل الخروج', style: TextStyle(
            color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 14)),
          onTap: () async {
            await context.read<AuthProvider>().logout();
            AppRouter.replace(AppRouter.login);
          }),
      ]));
  }
}
