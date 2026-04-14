// ══════════════════════════════════════════════════════════════════════════
//  MALLX APP CONSTANTS
//  Single source of truth for all configuration values
// ══════════════════════════════════════════════════════════════════════════

/// ── Server configuration ───────────────────────────────────────────────
///  Replace YOUR_SERVER_IP before building for release.
///  For Android emulator on same machine use: 10.0.2.2
///  For physical device: use your machine's LAN IP (e.g. 192.168.1.x)
const String kServerHost = 'YOUR_SERVER_IP';
const String kServerPort = '5000';
const String kBaseUrl    = 'http://$kServerHost:$kServerPort/api';
const String kHubBaseUrl = 'http://$kServerHost:$kServerPort';

/// ── Mall slug (from demo seed data) ───────────────────────────────────
const String kMallSlug = 'mallx-demo';

/// ── API timeout (seconds) ─────────────────────────────────────────────
const int kConnectTimeoutSec = 30;
const int kReceiveTimeoutSec = 30;
const int kStreamTimeoutSec  = 120; // for AI streaming

// ══════════════════════════════════════════════════════════════════════════
//  API ENDPOINT CONSTANTS
// ══════════════════════════════════════════════════════════════════════════
class ApiEndpoints {
  ApiEndpoints._();

  // ── Auth ──────────────────────────────────────────────────────────────
  static const register      = '/mall/auth/register';
  static const login         = '/mall/auth/login';
  static const refresh       = '/mall/auth/refresh';
  static const me            = '/mall/auth/me';

  // ── Cart ──────────────────────────────────────────────────────────────
  static const cart          = '/mall/cart';
  static const cartItems     = '/mall/cart/items';
  static String cartItem(String productId) => '/mall/cart/items/$productId';

  // ── Orders ────────────────────────────────────────────────────────────
  static const checkout      = '/mall/orders/checkout';
  static const orders        = '/mall/orders';
  static String order(String id)       => '/mall/orders/$id';
  static String orderTrack(String id)  => '/mall/orders/$id/track';

  // ── Mall Discovery ────────────────────────────────────────────────────
  static String mallHome(String mallId)   => '/mall/$mallId';
  static String mallStores(String mallId) => '/mall/$mallId/stores';
  static String mallStore(String mallId, String storeId) => '/mall/$mallId/stores/$storeId';
  static String mallSearch(String mallId) => '/mall/$mallId/search';
  static String mallMap(String mallId)    => '/mall/$mallId/map';
  static String aiChat(String mallId)     => '/mall/$mallId/ai/chat';
  static String aiStream(String mallId)   => '/mall/$mallId/ai/chat/stream';
  static String quickReplies(String mallId) => '/mall/$mallId/ai/chat/quick-replies';

  // ── Restaurant ────────────────────────────────────────────────────────
  static String storeMenu(String storeId)  => '/mall/stores/$storeId/menu';
  static const  restaurantQueue = '/mall/store/restaurant/queue';
  static String advanceTicket(String id)   => '/mall/store/restaurant/queue/$id/advance';

  // ── Booking ───────────────────────────────────────────────────────────
  static String availability(String storeId) => '/mall/bookings/stores/$storeId/availability';
  static const  bookings     = '/mall/bookings';
  static const  myBookings   = '/mall/bookings/my';
  static String cancelBooking(String id)     => '/mall/bookings/$id';

  // ── Loyalty ───────────────────────────────────────────────────────────
  static const loyaltyWallet  = '/mall/loyalty/wallet';
  static const loyaltyRedeem  = '/mall/loyalty/redeem';
  static const promotions     = '/mall/promotions';
  static const couponApply    = '/mall/promotions/coupon/apply';

  // ── Wallet ────────────────────────────────────────────────────────────
  static const wallet         = '/mall/wallet';
  static const walletTopUp    = '/mall/wallet/topup';
  static const walletSpend    = '/mall/wallet/spend';
  static const walletHistory  = '/mall/wallet/history';

  // ── Referral ─────────────────────────────────────────────────────────
  static const referralCode   = '/mall/referral/code';
  static const referralApply  = '/mall/referral/apply';

  // ── Notifications ─────────────────────────────────────────────────────
  static const notifications     = '/mall/notifications';
  static const unreadCount       = '/mall/notifications/unread-count';
  static const markAllRead       = '/mall/notifications/mark-all-read';
  static String markRead(String id) => '/mall/notifications/$id/read';

  // ── Reviews ───────────────────────────────────────────────────────────
  static String productReviews(String productId)  => '/mall/products/$productId/reviews';
  static String reviewHelpful(String productId, String reviewId)
      => '/mall/products/$productId/reviews/$reviewId/helpful';

  // ── Saved Orders ─────────────────────────────────────────────────────
  static const savedOrders      = '/mall/saved-orders';
  static String reorder(String id)  => '/mall/saved-orders/$id/reorder';
  static String deleteSaved(String id) => '/mall/saved-orders/$id';

  // ── Devices (FCM) ─────────────────────────────────────────────────────
  static const registerDevice = '/mall/devices/register';

  // ── Store Owner ───────────────────────────────────────────────────────
  static const storeOrders     = '/mall/store/orders/incoming';
  static String updateStatus(String id) => '/mall/store/orders/$id/status';
  static const storeBookings   = '/mall/store/bookings';
  static const storeAnalytics  = '/mall/store/analytics';

  // ── SignalR Hub URLs ──────────────────────────────────────────────────
  static const hubOrders  = '/hubs/orders';
  static const hubDrivers = '/hubs/drivers';
}

// ══════════════════════════════════════════════════════════════════════════
//  STORAGE KEYS
// ══════════════════════════════════════════════════════════════════════════
class StorageKeys {
  StorageKeys._();
  static const accessToken  = 'access_token';
  static const refreshToken = 'refresh_token';
  static const onboarded    = 'onboarded';
  static const mallId       = 'mall_id';
  static const customerId   = 'customer_id';
  static const themeMode    = 'theme_mode';
  static const language     = 'language';
  static const fcmToken     = 'fcm_token';
  static const lastCartSync = 'last_cart_sync';
}

// ══════════════════════════════════════════════════════════════════════════
//  APP STRINGS (Arabic)
// ══════════════════════════════════════════════════════════════════════════
class AppStrings {
  AppStrings._();
  static const appName       = 'MallX';
  static const appTagline    = 'كل اللي محتاجه في مول واحد';
  static const loading       = 'جاري التحميل...';
  static const retry         = 'إعادة المحاولة';
  static const error         = 'حدث خطأ ما';
  static const networkError  = 'تحقق من اتصالك بالإنترنت';
  static const success       = 'تمت العملية بنجاح';
  static const cancel        = 'إلغاء';
  static const confirm       = 'تأكيد';
  static const save          = 'حفظ';
  static const delete        = 'حذف';
  static const edit          = 'تعديل';
  static const close         = 'إغلاق';
  static const back          = 'رجوع';
  static const next          = 'التالي';
  static const done          = 'تم';
  static const addToCart     = 'أضف للسلة';
  static const checkout      = 'إتمام الطلب';
  static const orderPlaced   = 'تم تقديم طلبك!';
  static const noData        = 'لا توجد بيانات';
  static const emptyCart     = 'السلة فارغة';
  static const loginRequired = 'يجب تسجيل الدخول أولاً';
  static const egpUnit       = 'ج.م';
  static const pointsUnit    = 'نقطة';
}

// ══════════════════════════════════════════════════════════════════════════
//  FULFILLMENT + ORDER STATUS MAPS (Arabic labels)
// ══════════════════════════════════════════════════════════════════════════
const Map<String, String> kFulfillmentAr = {
  'Delivery': '🚗 توصيل',
  'Pickup':   '🏪 استلام',
  'InStore':  '🏬 داخل المول',
};

const Map<String, String> kPaymentAr = {
  'Cash':   '💵 كاش عند الاستلام',
  'Card':   '💳 بطاقة',
  'Fawry':  '🟡 فوري',
  'Wallet': '💰 المحفظة',
  'Points': '⭐ نقاط الولاء',
};

const Map<String, String> kOrderStatusAr = {
  'Placed':    'تم الاستلام',
  'Confirmed': 'مؤكد',
  'Preparing': 'قيد التحضير',
  'Ready':     'جاهز',
  'PickedUp':  'في الطريق',
  'Delivered': 'تم التسليم ✅',
  'Cancelled': 'ملغى',
};

const Map<String, String> kTierAr = {
  'Bronze': 'برونزي 🥉',
  'Silver': 'فضي 🥈',
  'Gold':   'ذهبي 🥇',
};
