import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/api_constants.dart';
import '../../data/services/api_service.dart';
import '../../providers/providers.dart';
import '../../routes/app_router.dart';
import '../../widgets/common/common_widgets.dart';

// ══════════════════════════════════════════════════════════════════════════
//  SEARCH SCREEN — Full-text search across all stores + products
// ══════════════════════════════════════════════════════════════════════════
class SearchScreen extends StatefulWidget {
  final String mallId;
  const SearchScreen({super.key, required this.mallId});
  @override State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api        = ApiService();
  final _ctrl       = TextEditingController();
  final _focus      = FocusNode();

  List<Map> _results   = [];
  List<String> _trending = [];
  List<String> _history  = [];
  bool  _searching = false;
  bool  _loaded    = false;
  Timer? _debounce;

  String _filter = 'all'; // all | stores | products | services

  @override
  void initState() {
    super.initState();
    _loadTrending();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose(); _focus.dispose(); _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    try {
      final res = await _api.get(
        '${ApiEndpoints.mallSearch(widget.mallId)}/trending');
      setState(() {
        _trending = List<String>.from(res.data['data']?['terms'] ?? []);
        _history  = List<String>.from(res.data['data']?['myHistory'] ?? []);
      });
    } catch (_) {}
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) { setState(() { _results = []; _loaded = false; }); return; }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(q));
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final res = await _api.get(
        ApiEndpoints.mallSearch(widget.mallId),
        params: {'q': q, 'filter': _filter, 'size': '30'});
      setState(() {
        _results  = List<Map>.from(res.data['data']?['results'] ?? []);
        _loaded   = true;
        _searching= false;
      });
    } catch (_) { setState(() => _searching = false); }
  }

  void _selectQuery(String q) {
    _ctrl.text = q;
    _search(q);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 0,
      title: Container(
        height: 40,
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border)),
        child: TextField(
          controller:  _ctrl,
          focusNode:   _focus,
          onChanged:   _onChanged,
          onSubmitted: _search,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText:    'ابحث عن منتجات، محلات، خدمات...',
            border:      InputBorder.none,
            filled:      false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
            suffixIcon: _ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: AppTheme.textSec),
                  onPressed: () {
                    _ctrl.clear();
                    setState(() { _results = []; _loaded = false; });
                  })
              : null))),
      actions: [
        TextButton(
          onPressed: () => AppRouter.pop(),
          child: const Text('إلغاء',
            style: TextStyle(color: AppTheme.textSec, fontSize: 13))),
      ],
    ),
    body: Column(children: [

      // ── Filter chips ─────────────────────────────────────────────────
      if (_ctrl.text.isNotEmpty)
        SizedBox(height: 44, child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          children: [
            for (final f in [
              ['all',      'الكل'],
              ['products', '🛍️ منتجات'],
              ['stores',   '🏪 محلات'],
              ['services', '💇 خدمات'],
            ])
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: GestureDetector(
                  onTap: () { setState(() => _filter = f[0]); _search(_ctrl.text); },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _filter == f[0] ? AppTheme.primary : AppTheme.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _filter == f[0]
                        ? AppTheme.primary : AppTheme.border)),
                    child: Text(f[1], style: TextStyle(
                      color: _filter == f[0] ? Colors.white : AppTheme.textSec,
                      fontSize: 12, fontWeight: FontWeight.w600))))),
          ])),

      // ── Body ─────────────────────────────────────────────────────────
      Expanded(child: _ctrl.text.isEmpty
        ? _EmptyState(
            trending: _trending, history: _history, onTap: _selectQuery)
        : _searching
          ? const Center(child: CircularProgressIndicator(
              strokeWidth: 2, color: AppTheme.primary))
          : !_loaded
            ? const SizedBox.shrink()
            : _results.isEmpty
              ? EmptyState(
                  emoji: '🔍', title: 'لا نتائج لـ "${_ctrl.text}"',
                  subtitle: 'جرب كلمة بحث مختلفة')
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ResultCard(
                    item: _results[i], query: _ctrl.text))),
    ]));
}

// ── Empty / Trending state ─────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final List<String> trending, history;
  final Function(String) onTap;
  const _EmptyState({required this.trending, required this.history, required this.onTap});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (history.isNotEmpty) ...[
        const Text('🕐 عمليات البحث الأخيرة', style: TextStyle(
          color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8,
          children: history.map((q) => GestureDetector(
            onTap: () => onTap(q),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.card, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.history, color: AppTheme.textMut, size: 13),
                const SizedBox(width: 5),
                Text(q, style: const TextStyle(
                  color: AppTheme.textSec, fontSize: 12)),
              ])))).toList()),
        const SizedBox(height: 20),
      ],
      if (trending.isNotEmpty) ...[
        const Text('🔥 الأكثر بحثاً الآن', style: TextStyle(
          color: AppTheme.textPri, fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        ...trending.asMap().entries.map((e) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: e.key < 3
                ? AppTheme.accent.withOpacity(0.15) : AppTheme.surface,
              borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('${e.key + 1}',
              style: TextStyle(
                color: e.key < 3 ? AppTheme.accent : AppTheme.textMut,
                fontWeight: FontWeight.w800, fontSize: 12)))),
          title: Text(e.value, style: const TextStyle(
            color: AppTheme.textSec, fontSize: 14)),
          trailing: const Icon(Icons.trending_up, color: AppTheme.textMut, size: 14),
          onTap: () => onTap(e.value))),
      ],
      if (trending.isEmpty && history.isEmpty)
        const EmptyState(emoji: '🔍', title: 'ابحث عن أي شيء',
          subtitle: 'منتجات، مطاعم، خدمات، محلات...'),
    ]));
}

// ── Result Card ────────────────────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final Map    item;
  final String query;
  const _ResultCard({required this.item, required this.query});

  @override
  Widget build(BuildContext context) {
    final type     = item['type'] as String? ?? 'product'; // product | store | service
    final name     = item['name']     as String? ?? '';
    final subtitle = item['subtitle'] as String? ?? '';
    final price    = (item['price'] as num?)?.toDouble();
    final rating   = (item['rating'] as num?)?.toDouble();
    final imageUrl = item['imageUrl'] as String?;

    final icon = type == 'store'   ? '🏪'
               : type == 'service' ? '💇'
               : '🛍️';
    final color = type == 'store'   ? AppTheme.primary
                : type == 'service' ? AppTheme.secondary
                : AppTheme.accent;

    return GestureDetector(
      onTap: () {
        if (type == 'store') {
          AppRouter.push(AppRouter.storeDetail, {
            'storeId':   item['id'],
            'storeName': name,
          });
        } else {
          // Navigate to store containing this product
          AppRouter.push(AppRouter.storeDetail, {
            'storeId':   item['storeId'],
            'storeName': item['storeName'] ?? '',
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.card, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border)),
        child: Row(children: [
          // Thumbnail
          Container(
            width: 60, height: 60,
            margin: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(icon, color))
                : _placeholder(icon, color))),

          // Info
          Expanded(child: Padding(
            padding: const EdgeInsets.only(right: 4, top: 10, bottom: 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Highlighted name
              _HighlightedText(text: name, query: query),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: const TextStyle(
                  color: AppTheme.textSec, fontSize: 11),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Row(children: [
                if (rating != null) ...[
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 11),
                  Text(' ${rating.toStringAsFixed(1)} ',
                    style: const TextStyle(color: AppTheme.textSec, fontSize: 11)),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6)),
                  child: Text(icon, style: const TextStyle(fontSize: 10))),
              ]),
            ]))),

          // Price
          if (price != null)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 4),
              child: PriceTag(price: price, fontSize: 14)),
        ])));
  }

  Widget _placeholder(String icon, Color color) => Container(
    color: color.withOpacity(0.1),
    child: Center(child: Text(icon, style: const TextStyle(fontSize: 24))));
}

// ── Text highlight widget ──────────────────────────────────────────────────
class _HighlightedText extends StatelessWidget {
  final String text, query;
  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    if (query.isEmpty) return Text(text, style: const TextStyle(
      color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 14));

    final lower = text.toLowerCase();
    final qLower= query.toLowerCase();
    final idx   = lower.indexOf(qLower);

    if (idx < 0) return Text(text, style: const TextStyle(
      color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 14));

    return RichText(text: TextSpan(children: [
      TextSpan(text: text.substring(0, idx),
        style: const TextStyle(color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 14)),
      TextSpan(text: text.substring(idx, idx + query.length),
        style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w800, fontSize: 14,
          backgroundColor: Color(0x1A3B82F6))),
      TextSpan(text: text.substring(idx + query.length),
        style: const TextStyle(color: AppTheme.textPri, fontWeight: FontWeight.w600, fontSize: 14)),
    ]));
  }
}
