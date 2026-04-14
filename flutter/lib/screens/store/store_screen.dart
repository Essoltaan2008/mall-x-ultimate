import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../data/services/api_service.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/common/common_widgets.dart';
import 'package:provider/provider.dart';

// ══════════════════════════════════════════════════════════════════════════
//  STORE DETAIL SCREEN — Products / Menu + Add to Cart
// ══════════════════════════════════════════════════════════════════════════
class StoreDetailScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  const StoreDetailScreen({super.key, required this.storeId, required this.storeName});
  @override State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final _api = ApiService();
  Map? _store;
  List<Map> _products = [];
  List<Map> _categories = [];
  String? _selectedCat;
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final auth = context.read<AuthProvider>();
      final res  = await _api.get(
        ApiEndpoints.mallStore(auth.mallId, widget.storeId));
      setState(() {
        _store      = res.data['data'];
        _products   = List<Map>.from(_store?['products']   ?? []);
        _categories = List<Map>.from(_store?['categories'] ?? []);
        _loading    = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  List<Map> get _filtered {
    var list = _products;
    if (_selectedCat != null)
      list = list.where((p) => p['categoryId'] == _selectedCat).toList();
    if (_search.isNotEmpty)
      list = list.where((p) =>
        (p['name'] as String).toLowerCase().contains(_search.toLowerCase())).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final storeType = _store?['storeType'] as String? ?? 'Retail';
    final isRestaurant = storeType == 'Restaurant';

    return Scaffold(
      body: _loading ? const ShimmerList() : CustomScrollView(slivers: [

        // ── Store Header (SliverAppBar) ──────────────────────────────
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            title: Text(widget.storeName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.storeTypeColor(storeType).withOpacity(0.4),
                    AppTheme.bg,
                  ],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter)),
              child: Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Text(isRestaurant ? '🍔' : storeType == 'Service' ? '💇' : '🛍️',
                    style: const TextStyle(fontSize: 52)),
                  if (_store?['avgRating'] != null)
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                      Text(' ${(_store!['avgRating'] as num).toStringAsFixed(1)}'
                        ' (${_store!['totalRatings']}) · '
                        '${AppTheme.storeTypeAr(storeType)}',
                        style: const TextStyle(color: AppTheme.textSec, fontSize: 12)),
                    ]),
                ]))),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => showSearch(
                context: context,
                delegate: _ProductSearchDelegate(_products, _addToCart))),
          ],
        ),

        // ── Category Filter ──────────────────────────────────────────
        if (_categories.isNotEmpty)
          SliverToBoxAdapter(child: SizedBox(height: 50,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final isAll = i == 0;
                final cat   = isAll ? null : _categories[i - 1];
                final sel   = _selectedCat == cat?['id'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCat = cat?['id']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isAll ? _selectedCat == null : sel)
                        ? AppTheme.primary : AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (isAll ? _selectedCat == null : sel)
                          ? AppTheme.primary : AppTheme.border)),
                    child: Text(
                      isAll ? 'الكل' : '${cat?['icon'] ?? ''} ${cat?['name'] ?? ''}',
                      style: TextStyle(
                        color: (isAll ? _selectedCat == null : sel)
                          ? Colors.white : AppTheme.textSec,
                        fontSize: 12, fontWeight: FontWeight.w600))));
              }))),

        // ── Product Grid ─────────────────────────────────────────────
        _filtered.isEmpty
          ? const SliverToBoxAdapter(child: EmptyState(
              emoji: '📭', title: 'لا توجد منتجات في هذا القسم'))
          : SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10, crossAxisSpacing: 10,
                  childAspectRatio: 0.82),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _ProductCard(
                    product: _filtered[i],
                    onAdd: () => _addToCart(_filtered[i])),
                  childCount: _filtered.length))),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ]),

      // ── Cart FAB ────────────────────────────────────────────────────
      floatingActionButton: Consumer<CartProvider>(
        builder: (_, cart, __) => cart.itemCount == 0
          ? const SizedBox.shrink()
          : FloatingActionButton.extended(
              onPressed: () => AppRouter.push('/checkout'),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
              label: Text('السلة (${cart.itemCount}) — ${cart.total.toStringAsFixed(0)} ج.م',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)))),
    );
  }

  Future<void> _addToCart(Map product) async {
    final cart   = context.read<CartProvider>();
    final err    = await cart.addItem(
      productId: product['id'],
      storeId:   widget.storeId,
      quantity:  1,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err == null
          ? '✅ تمت الإضافة للسلة!'
          : err),
        backgroundColor: err == null ? AppTheme.secondary : AppTheme.error,
        duration: const Duration(seconds: 1)));
    }
  }
}

// ── Product Card ──────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Map product;
  final VoidCallback onAdd;
  const _ProductCard({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final price    = (product['salePrice'] as num?)?.toDouble() ?? 0;
    final origPric = (product['originalPrice'] as num?)?.toDouble();
    final inStock  = (product['stockQuantity'] as int? ?? 1) > 0;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProductDetailScreen(product: product))),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(14), topLeft: Radius.circular(14)),
              child: MallNetworkImage(
                url: product['imageUrl'],
                width: double.infinity, height: double.infinity,
                radius: 0,
                fallbackIcon: Icons.fastfood_outlined))),

          // Info
          Expanded(flex: 2, child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Text(product['name'] ?? '',
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPri, fontSize: 12,
                  fontWeight: FontWeight.w600, height: 1.3)),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                PriceTag(price: price, originalPrice: origPric, fontSize: 13),
                GestureDetector(
                  onTap: inStock ? onAdd : null,
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: inStock ? AppTheme.primary : AppTheme.border,
                      borderRadius: BorderRadius.circular(8)),
                    child: Icon(
                      inStock ? Icons.add : Icons.block,
                      color: Colors.white, size: 16))),
              ]),
            ]))),
        ])));
  }
}

// ── Product Detail Screen ─────────────────────────────────────────────────
class ProductDetailScreen extends StatelessWidget {
  final Map product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final price   = (product['salePrice'] as num?)?.toDouble() ?? 0;
    final origP   = (product['originalPrice'] as num?)?.toDouble();
    final inStock = (product['stockQuantity'] as int? ?? 1) > 0;
    final rating  = (product['avgRating'] as num?)?.toDouble() ?? 0;
    final reviews = product['totalReviews'] as int? ?? 0;

    return Scaffold(
      appBar: AppBar(title: Text(product['name'] ?? '')),
      body: SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          MallNetworkImage(
            url: product['imageUrl'],
            width: double.infinity, height: 240, radius: 0,
            fallbackIcon: Icons.image_outlined),

          Padding(padding: const EdgeInsets.all(16), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name + rating
            Text(product['name'] ?? '',
              style: const TextStyle(
                color: AppTheme.textPri, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Row(children: [
              if (rating > 0) ...[
                RatingStars(rating: rating, total: reviews, size: 14),
                const SizedBox(width: 12),
              ],
              Text(inStock ? '✅ متوفر' : '❌ نفد',
                style: TextStyle(
                  color: inStock ? AppTheme.secondary : AppTheme.error,
                  fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 12),
            // Price
            PriceTag(price: price, originalPrice: origP, fontSize: 22),
            const SizedBox(height: 16),
            // Description
            if (product['description'] != null) ...[
              const Text('الوصف', style: TextStyle(
                color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 6),
              Text(product['description'],
                style: const TextStyle(
                  color: AppTheme.textSec, fontSize: 14, height: 1.6)),
              const SizedBox(height: 20),
            ],
            // Specs
            if (product['sku'] != null)
              _specRow('كود المنتج', product['sku']),
            if (product['categoryName'] != null)
              _specRow('الفئة', product['categoryName']),
          ])),

          // Reviews Section
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('التقييمات', style: TextStyle(
              color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 14))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ProductReviewsWidget(productId: product['id'] ?? '')),

          const SizedBox(height: 90),
        ])),

      // Add to cart button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.border))),
        child: Consumer<CartProvider>(
          builder: (_, cart, __) => LoadingButton(
            loading: cart.loading,
            label: inStock
              ? '🛒 أضف للسلة — ${price.toStringAsFixed(0)} ج.م'
              : '❌ غير متوفر',
            onPressed: inStock ? () async {
              final err = await cart.addItem(
                productId: product['id'],
                storeId:   product['storeId'] ?? '',
                quantity:  1);
              if (context.mounted)
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(err ?? '✅ تمت الإضافة للسلة!'),
                  backgroundColor: err == null ? AppTheme.secondary : AppTheme.error));
            } : null))),
    );
  }

  Widget _specRow(String label, String val) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text('$label: ', style: const TextStyle(
        color: AppTheme.textSec, fontSize: 13)),
      Text(val, style: const TextStyle(
        color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 13)),
    ]));
}

// ── Product Search Delegate ───────────────────────────────────────────────
class _ProductSearchDelegate extends SearchDelegate<Map?> {
  final List<Map> products;
  final Function(Map) onAdd;
  _ProductSearchDelegate(this.products, this.onAdd);

  @override String get searchFieldLabel => 'ابحث عن منتج...';
  @override List<Widget>? buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')
  ];
  @override Widget? buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back), onPressed: () => close(context, null));

  @override
  Widget buildResults(BuildContext context) => _buildList();
  @override
  Widget buildSuggestions(BuildContext context) => _buildList();

  Widget _buildList() {
    final filtered = products.where((p) =>
      (p['name'] as String? ?? '').toLowerCase().contains(query.toLowerCase())).toList();
    if (filtered.isEmpty) return const EmptyState(emoji: '🔍', title: 'لا نتائج');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filtered.length,
      itemBuilder: (_, i) => ListTile(
        leading: MallNetworkImage(
          url: filtered[i]['imageUrl'], width: 44, height: 44, radius: 8),
        title: Text(filtered[i]['name'] ?? ''),
        subtitle: Text('${(filtered[i]['salePrice'] as num?)?.toStringAsFixed(0)} ج.م',
          style: const TextStyle(color: AppTheme.primary)),
        trailing: IconButton(
          icon: const Icon(Icons.add_circle_outline, color: AppTheme.primary),
          onPressed: () => onAdd(filtered[i]))));
  }
}

// ── ProductReviewsWidget (stub — full impl in notifications_screen.dart) ──
class ProductReviewsWidget extends StatelessWidget {
  final String productId;
  const ProductReviewsWidget({super.key, required this.productId});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.card, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border)),
    child: const Text('اضغط لعرض التقييمات',
      style: TextStyle(color: AppTheme.textSec, fontSize: 13)));
}
