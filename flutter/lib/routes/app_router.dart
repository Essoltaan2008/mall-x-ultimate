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

// ─────────────────────────────────────────────────────────────────────────
//  APP ROUTER
// ─────────────────────────────────────────────────────────────────────────
class AppRouter {
  AppRouter._();

  static final navigatorKey = GlobalKey<NavigatorState>();

  // ── Route names ────────────────────────────────────────────────────────
  static const onboarding    = '/onboarding';
  static const login         = '/login';
  static const home          = '/home';
  static const storeMenu     = '/store-menu';
  static const booking       = '/booking';
  static const bookingRate   = '/booking/rate';
  static const rateStore     = '/rate-store';
  static const loyalty       = '/loyalty';
  static const promotions    = '/promotions';
  static const mallMap       = '/mall-map';
  static const search        = '/search';
  static const trackOrder    = '/track-order';
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
        return _slide(const OnboardingScreenImpl());

      case login:
        return _fade(const LoginScreen());

      case home:
        return _fade(const MainNavScreen());

      case storeMenu:
        return _slide(RestaurantMenuScreen(
          storeId:   args['storeId']   ?? '',
          storeName: args['storeName'] ?? 'القائمة',
        ));

      case booking:
        return _slide(BookingScreen(
          storeId:   args['storeId']   ?? '',
          storeName: args['storeName'] ?? 'الحجز',
        ));

      case bookingRate:
      case rateStore:
        return _slide(RatingScreen(
          mallOrderId: args['mallOrderId'] ?? '',
          storeId:     args['storeId']     ?? '',
          storeName:   args['storeName']   ?? '',
        ));

      case loyalty:
        return _slide(const LoyaltyWalletScreen());

      case promotions:
        return _slide(const PromotionsScreen());

      case mallMap:
        return _slide(MallMapScreen(mallId: args['mallId'] ?? ''));

      case search:
        return _slide(SearchScreen(mallId: args['mallId'] ?? ''));

      case trackOrder:
        return _slide(RealtimeOrderTracker(
          orderId:     args['orderId']     ?? '',
          orderNumber: args['orderNumber'] ?? '',
          accessToken: args['accessToken'] ?? '',
        ));

      case aiChat:
        return _slide(MallAIChatScreen(mallId: args['mallId'] ?? ''));

      case storeOwner:
        return _fade(const StoreOwnerApp());

      case wallet:
        return _slide(WalletScreen(mallId: args['mallId'] ?? ''));

      case referral:
        return _slide(ReferralScreen(mallId: args['mallId'] ?? ''));

      case notifications:
        return _slide(const NotificationsScreen());

      case driverApp:
        return _fade(DriverApp(driverId: args['driverId'] ?? ''));

      default:
        return _slide(_NotFoundScreen(route: settings.name ?? ''));
    }
  }

  // ── Helper builders ────────────────────────────────────────────────────
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

  // ── Navigation helpers ─────────────────────────────────────────────────
  static Future<T?> push<T>(String route, [Map<String, dynamic>? args]) =>
      navigatorKey.currentState!.pushNamed<T>(route, arguments: args);

  static Future<T?> replace<T>(String route, [Map<String, dynamic>? args]) =>
      navigatorKey.currentState!.pushReplacementNamed<T, dynamic>(
          route, arguments: args);

  static void pop<T>([T? result]) =>
      navigatorKey.currentState!.pop(result);

  static void popToHome() =>
      navigatorKey.currentState!.pushNamedAndRemoveUntil(home, (_) => false);
}

// ─────────────────────────────────────────────────────────────────────────
//  PLACEHOLDER SCREENS (to be replaced with real implementations)
// ─────────────────────────────────────────────────────────────────────────
class OnboardingScreenImpl extends StatelessWidget {
  const OnboardingScreenImpl({super.key});
  @override
  Widget build(BuildContext context) {
    // Delegate to wallet_referral_screens.dart OnboardingScreen
    return const OnboardingScreen();
  }
}

class _NotFoundScreen extends StatelessWidget {
  final String route;
  const _NotFoundScreen({required this.route});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('404')),
    body: Center(child: Text('Route not found: $route',
      style: const TextStyle(color: Colors.grey))),
  );
}
