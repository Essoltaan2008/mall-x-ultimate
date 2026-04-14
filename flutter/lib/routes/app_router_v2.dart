import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../screens/auth/login_screen.dart';
import '../screens/home/main_nav_screen.dart';
import '../screens/restaurant/restaurant_screens.dart';
import '../screens/booking/booking_rating_screens.dart';
import '../screens/loyalty/loyalty_promotions_screens.dart';
import '../screens/map/search_map_screens.dart';
import '../screens/tracking/realtime_tracking.dart';
import '../screens/ai_chat/ai_chat_screen.dart';
import '../screens/store_owner/store_owner_screens.dart';
import '../screens/wallet/wallet_referral_screens.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/driver/driver_app.dart';
import '../screens/orders/orders_screen.dart';
import '../screens/promotions/promotions_screen.dart';
import '../screens/store/store_screen.dart';
import '../screens/ratings/rating_screen.dart';
import '../screens/checkout/checkout_screen.dart';

// ══════════════════════════════════════════════════════════════════════════
//  COMPLETE APP ROUTER v2 — All routes wired
// ══════════════════════════════════════════════════════════════════════════
class AppRouter {
  AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  // ── Route constants ───────────────────────────────────────────────────
  static const onboarding    = '/onboarding';
  static const login         = '/login';
  static const home          = '/home';
  static const storeMenu     = '/store-menu';
  static const storeDetail   = '/store';       // product grid
  static const checkout      = '/checkout';
  static const trackOrder    = '/track-order';
  static const orders        = '/orders';
  static const promotions    = '/promotions';
  static const booking       = '/booking';
  static const bookingRate   = '/booking/rate';
  static const rateStore     = '/rate-store';
  static const loyalty       = '/loyalty';
  static const mallMap       = '/mall-map';
  static const search        = '/search';
  static const aiChat        = '/ai-chat';
  static const storeOwner    = '/store-owner';
  static const wallet        = '/wallet';
  static const referral      = '/referral';
  static const notifications = '/notifications';
  static const driverApp     = '/driver';

  // ── Route generator ────────────────────────────────────────────────────
  static Route<dynamic> generate(RouteSettings settings) {
    final args = settings.arguments as Map<String, dynamic>? ?? {};

    switch (settings.name) {

      case onboarding:
        return _slide(const OnboardingScreen());

      case login:
        return _fade(const LoginScreen());

      case home:
        return _fade(const MainNavScreen());

      // ── Store ─────────────────────────────────────────────────────────
      case storeDetail:
      case storeMenu:
        return _slide(StoreDetailScreen(
          storeId:   args['storeId']   ?? '',
          storeName: args['storeName'] ?? '',
        ));

      // ── Checkout ─────────────────────────────────────────────────────
      case checkout:
        return _slide(const CheckoutScreen());

      case trackOrder:
        return _slide(RealtimeOrderTracker(
          orderId:     args['orderId']     ?? '',
          orderNumber: args['orderNumber'] ?? '',
          accessToken: args['accessToken'] ?? '',
        ));

      // ── Orders ────────────────────────────────────────────────────────
      case orders:
        return _slide(const OrdersScreen());

      // ── Promotions ────────────────────────────────────────────────────
      case promotions:
        return _slide(const PromotionsScreen());

      // ── Booking ───────────────────────────────────────────────────────
      case booking:
        return _slide(BookingScreen(
          storeId:   args['storeId']   ?? '',
          storeName: args['storeName'] ?? '',
        ));

      // ── Rating ────────────────────────────────────────────────────────
      case bookingRate:
      case rateStore:
        return _slide(RatingScreen(
          mallOrderId: args['mallOrderId'] ?? '',
          storeId:     args['storeId']     ?? '',
          storeName:   args['storeName']   ?? '',
        ));

      // ── Restaurant ────────────────────────────────────────────────────
      case '/restaurant':
        return _slide(RestaurantMenuScreen(
          storeId:   args['storeId']   ?? '',
          storeName: args['storeName'] ?? '',
        ));

      // ── Loyalty & Promotions ──────────────────────────────────────────
      case loyalty:
        return _slide(const LoyaltyWalletScreen());

      // ── Map & Search ──────────────────────────────────────────────────
      case mallMap:
        return _slide(MallMapScreen(mallId: args['mallId'] ?? ''));
      case search:
        return _slide(SearchScreen(mallId: args['mallId'] ?? ''));

      // ── AI Chat ───────────────────────────────────────────────────────
      case aiChat:
        return _slide(MallAIChatScreen(mallId: args['mallId'] ?? ''));

      // ── Store Owner ───────────────────────────────────────────────────
      case storeOwner:
        return _fade(const StoreOwnerApp());

      // ── Wallet & Referral ─────────────────────────────────────────────
      case wallet:
        return _slide(WalletScreen(mallId: args['mallId'] ?? ''));
      case referral:
        return _slide(ReferralScreen(mallId: args['mallId'] ?? ''));

      // ── Notifications ─────────────────────────────────────────────────
      case notifications:
        return _slide(const NotificationsScreen());

      // ── Driver ────────────────────────────────────────────────────────
      case driverApp:
        return _fade(DriverApp(driverId: args['driverId'] ?? ''));

      default:
        return _slide(_NotFoundScreen(route: settings.name ?? ''));
    }
  }

  // ── Transition helpers ────────────────────────────────────────────────
  static PageRoute _slide(Widget screen) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, anim, __, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child),
    transitionDuration: const Duration(milliseconds: 280),
  );

  static PageRoute _fade(Widget screen) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
    transitionDuration: const Duration(milliseconds: 200),
  );

  // ── Static navigation helpers ─────────────────────────────────────────
  static Future<T?> push<T>(String route, [Map<String, dynamic>? args]) =>
      navigatorKey.currentState!.pushNamed<T>(route, arguments: args);

  static Future<T?> replace<T>(String route, [Map<String, dynamic>? args]) =>
      navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
          route, arguments: args);

  static void pop<T>([T? result]) =>
      navigatorKey.currentState?.pop(result);

  static void popToHome() =>
      navigatorKey.currentState?.pushNamedAndRemoveUntil(home, (_) => false);
}

class _NotFoundScreen extends StatelessWidget {
  final String route;
  const _NotFoundScreen({required this.route});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('404')),
    body: Center(child: Text('Route not found: $route',
      style: const TextStyle(color: Colors.grey))));
}
