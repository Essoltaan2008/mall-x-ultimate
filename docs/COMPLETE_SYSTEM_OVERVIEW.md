# 🏬 MallX — Complete System Overview
## Final Technical Reference | Phase 13 | Excellence86

---

## 🏗️ Architecture Summary

```
┌─────────────────────────────────────────────────────────────┐
│                        CLIENTS                               │
│  Flutter (Customer)  │  Next.js (Admin)  │  Flutter (Driver) │
└──────────┬───────────┴──────────┬────────┴────────┬──────────┘
           │                      │                  │
           ▼           ┌──────────▼──────────────────▼──────────┐
    ┌──────────────┐   │         Nginx (Rev Proxy + SSL)         │
    │  SignalR Hub │   │    Rate Limiting | WebSocket Support     │
    │  /hubs/orders│   └──────────────────┬──────────────────────┘
    │  /hubs/drivers│                      │
    └──────────────┘                       ▼
           ▲            ┌─────────────────────────────────────────┐
           │            │      ASP.NET Core 8 API                 │
           │            │   Clean Architecture | DDD | CQRS        │
           └────────────│                                          │
                        │  ┌──────────┐  ┌──────────┐            │
                        │  │ Services │  │Middleware│            │
                        │  │  (Phase  │  │Exception │            │
                        │  │  1-12)   │  │Logging   │            │
                        │  └──────────┘  └──────────┘            │
                        └──────────┬──────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    ▼              ▼               ▼
             ┌──────────┐  ┌──────────┐   ┌──────────────┐
             │PostgreSQL│  │  Redis   │   │  External    │
             │   16     │  │    7     │   │  Services    │
             │70+ tables│  │ Cache+   │   │ Paymob/FCM/  │
             │8 SQL files│ │ SignalR  │   │ Twilio/Claude│
             └──────────┘  └──────────┘   └──────────────┘
```

---

## 📁 Complete File Inventory

### Backend (C# — ASP.NET Core 8)
```
backend/
├── API/
│   ├── Controllers/
│   │   ├── MallControllers.cs          ← Auth, Cart, Orders, Store, Admin
│   │   ├── Phase2Controllers.cs        ← Payment, Commission
│   │   ├── Phase3/Phase3Controllers.cs ← Restaurant, Booking, Rating
│   │   ├── Phase4/Phase4Controllers.cs ← Loyalty, Promotions, Devices, Geo
│   │   ├── Phase6/Phase6Controllers.cs ← Browse, Map, Search, Driver
│   │   ├── Phase8/Phase8Controllers.cs ← AI Chat, Analytics
│   │   ├── Phase9/Phase9Controllers.cs ← Wallet, Referral, WhatsApp, SuperAdmin
│   │   ├── Phase10/Phase10Controllers.cs ← Notifications, Reviews, Reorder
│   │   └── Phase11/Phase11Controllers.cs ← CSV Export
│   └── Program.cs                      ← Full service registration
├── Application/
│   ├── DTOs/MallDTOs.cs
│   └── Services/
│       ├── CartService.cs
│       ├── MallCustomerAuthService.cs
│       ├── MallOrderService.cs
│       ├── Phase2/ CommissionService + PaymentService
│       ├── Phase3/ RestaurantService + BookingService + RatingService
│       ├── Phase4/ LoyaltyService + PromotionService
│       ├── Phase5/ CacheService
│       ├── Phase6/ StoreBrowsingService + MallMapService
│       ├── Phase8/ MallAIService + AnalyticsService
│       ├── Phase9/ WalletService + Phase9Services (Referral+WA+SuperAdmin)
│       ├── Phase10/ Phase10Services (Notifications+Reviews+Reorder)
│       ├── Phase11/ ExportService
│       └── Phase12/ OrderOrchestrationService
├── Domain/
│   ├── Mall/MallEntities.cs + Phase2Entities.cs
│   ├── Restaurant/Phase3Entities.cs
│   └── Loyalty/Phase4Entities.cs
├── Hubs/
│   ├── SignalRHubs.cs                  ← OrderTrackingHub + DriverLocationHub
│   └── MallOrderHub.cs                ← Additional hub methods
└── Infrastructure/
    ├── BackgroundJobs/Phase5Jobs.cs    ← 5 background services
    ├── Caching/RedisCacheService.cs
    └── Middleware/Middlewares.cs
```

### Database (PostgreSQL 16)
```
database/
├── phase1_mallx_migration.sql          ← Mall, Customers, Cart, Orders
├── phase2/phase2_commission_payments.sql ← Payments, Commission, Drivers
├── phase3/phase3_restaurant_booking_ratings.sql
├── phase4/phase4_loyalty_promotions_push.sql
├── phase6/phase6_map_search_drivers.sql
├── phase9/phase9_wallet_referral_subscriptions.sql
├── phase10/phase10_notifications_reviews_reorder.sql
├── seed/demo_seed_data.sql             ← 6 stores, 5 customers, coupons
└── performance/performance_indexes.sql ← 35+ production indexes
```

### Flutter (Customer + Driver Apps)
```
flutter/lib/
├── main.dart + main_v2.dart
├── core/theme/app_theme.dart
├── data/services/api_service.dart
├── providers/providers.dart + all_providers.dart
├── routes/app_router.dart              ← All named routes + guards
└── screens/
    ├── auth/login_screen.dart
    ├── home/main_nav_screen.dart
    ├── restaurant/restaurant_screens.dart
    ├── booking/booking_rating_screens.dart
    ├── loyalty/loyalty_promotions_screens.dart
    ├── map/search_map_screens.dart     ← FTS search + mall map CustomPainter
    ├── tracking/realtime_tracking.dart ← SignalR order tracking
    ├── ai_chat/ai_chat_screen.dart     ← Claude streaming
    ├── store_owner/store_owner_screens.dart ← Store owner app
    ├── wallet/wallet_referral_screens.dart  ← Onboarding + wallet + referral
    ├── notifications/notifications_screen.dart
    └── driver/driver_app.dart         ← GPS + order pickup/deliver
```

### Next.js Frontend (Admin Dashboards)
```
frontend/pages/
├── mall-admin/
│   ├── index.tsx                       ← KPIs + charts + commission table
│   ├── analytics.tsx                   ← Full analytics (5 tabs, 5 periods)
│   ├── promotions/index.tsx            ← Coupons + Flash + Push campaigns
│   └── settlements/index.tsx          ← Monthly commission settlements
├── store/dashboard.tsx                 ← Store orders + queue + analytics
└── superadmin/index.tsx                ← Multi-mall + create mall
```

### Tests, CI, Infra
```
tests/
├── MallXTests.cs      ← 12 tests: Auth, Cart, Loyalty, Coupons, Ratings, Integration
└── Phase10Tests.cs    ← 28 tests: Wallet, Notifications, Reviews, Reorder, Referral

ci/github-actions.yml  ← Backend + Flutter + Frontend + Docker + Deploy
docker/
├── docker-compose.prod.yml
├── nginx.prod.conf     ← WebSocket + SignalR + rate limiting + gzip
└── .env.example
monitoring/health-dashboard.html   ← Auto-refresh HTML monitor
website/index.html                 ← MallX landing page (dark, responsive, RTL)
docs/INTEGRATION_GUIDE.md
```

---

## 🚀 Deployment Checklist

### Pre-deployment
- [ ] Fill all values in `docker/.env`
- [ ] Run SQL migrations in order (phase1 → phase10)
- [ ] Load demo seed data: `database/seed/demo_seed_data.sql`
- [ ] Run performance indexes: `database/performance/performance_indexes.sql`
- [ ] Configure Firebase project + download `google-services.json`
- [ ] Get Paymob API keys from dashboard
- [ ] Get Anthropic API key for AI features
- [ ] Configure Twilio for WhatsApp (optional)

### Flutter Config
- [ ] Replace `YOUR_SERVER_IP` in 3 files:
  - `lib/data/services/api_service.dart`
  - `lib/screens/tracking/realtime_tracking.dart`
  - `lib/screens/ai_chat/ai_chat_screen.dart`
  - `lib/screens/driver/driver_app.dart`
- [ ] Add Firebase `google-services.json` to `android/app/`
- [ ] Update `android/app/build.gradle` applicationId
- [ ] `flutter pub get && flutter build apk --release`

### Backend Config
- [ ] All services registered in `Program.cs` (see Middlewares.cs comments)
- [ ] `appsettings.Production.json` with all keys
- [ ] Health check: `GET /health` returns `{"status":"Healthy"}`

### Production
```bash
cd docker
cp .env.example .env && nano .env
docker-compose -f docker-compose.prod.yml up -d --build
curl http://localhost/health
```

---

## 📊 Complete API Reference (60+ Endpoints)

### Customer Authentication
```
POST /api/mall/auth/register    → Register new customer
POST /api/mall/auth/login       → Login + get JWT
POST /api/mall/auth/refresh     → Refresh token
GET  /api/mall/auth/me          → Current customer profile
```

### Cart & Orders
```
GET    /api/mall/cart              → Get cart
POST   /api/mall/cart/items        → Add item
PUT    /api/mall/cart/items        → Update quantity
DELETE /api/mall/cart/items/{id}   → Remove item
POST   /api/mall/orders/checkout   → Place order
GET    /api/mall/orders            → Order history
GET    /api/mall/orders/{id}       → Order details
PATCH  /api/mall/store/orders/{id}/status → Update status (store)
```

### Mall Discovery
```
GET /api/mall/{mallId}                    → Mall home + featured
GET /api/mall/{mallId}/stores             → Browse stores (filter/sort)
GET /api/mall/{mallId}/stores/{id}        → Store detail
GET /api/mall/{mallId}/stores/{id}/products → Products catalog
GET /api/mall/{mallId}/search             → Full-text search
GET /api/mall/{mallId}/search/trending    → Trending searches
GET /api/mall/{mallId}/map               → Interactive mall map
GET /api/mall/{mallId}/map/floors/{id}   → Single floor
```

### Restaurant
```
GET  /api/mall/stores/{id}/menu             → Restaurant menu
POST /api/mall/store/restaurant/menu        → Add menu item
PATCH /api/mall/store/restaurant/menu/{id}/toggle → Toggle availability
GET  /api/mall/store/restaurant/queue        → Restaurant queue
PATCH /api/mall/store/restaurant/queue/{id}/advance → Advance ticket
```

### Booking
```
GET  /api/mall/bookings/stores/{id}/services     → List services
GET  /api/mall/bookings/stores/{id}/availability → Available slots
POST /api/mall/bookings                           → Create booking
GET  /api/mall/bookings/my                        → My bookings
DELETE /api/mall/bookings/{id}                    → Cancel booking
GET  /api/mall/store/bookings                     → Store day schedule
PATCH /api/mall/store/bookings/{id}/status        → Update status
```

### Loyalty & Promotions
```
GET  /api/mall/loyalty/wallet      → Points + tier + history
POST /api/mall/loyalty/redeem      → Redeem points for discount
GET  /api/mall/promotions          → Active coupons + flash sales
POST /api/mall/promotions/coupon/apply → Apply coupon
POST /api/mall/admin/promotions/coupons    → Create coupon
POST /api/mall/admin/promotions/flash-sales → Create flash sale
POST /api/mall/admin/campaigns             → Send push notification
POST /api/mall/geo/checkin                 → Geo-fence check-in
POST /api/mall/devices/register            → Register FCM token
```

### Wallet & Referral
```
GET  /api/mall/wallet           → Wallet balance + transactions
POST /api/mall/wallet/topup     → Top up wallet
POST /api/mall/wallet/spend     → Pay from wallet
GET  /api/mall/wallet/history   → Transaction history
GET  /api/mall/referral/code    → Get referral code
POST /api/mall/referral/apply   → Apply referral code
```

### Ratings & Reviews
```
GET  /api/mall/ratings/stores/{id}              → Store rating summary
POST /api/mall/ratings                           → Submit store rating
POST /api/mall/ratings/{id}/reply               → Store reply
GET  /api/mall/products/{id}/reviews            → Product reviews
POST /api/mall/products/{id}/reviews            → Submit product review
POST /api/mall/products/{id}/reviews/{rid}/helpful → Mark helpful
```

### Notifications & Saved Orders
```
GET  /api/mall/notifications           → Notification center
GET  /api/mall/notifications/unread-count → Badge count
PATCH /api/mall/notifications/{id}/read  → Mark read
POST /api/mall/notifications/mark-all-read
GET  /api/mall/saved-orders            → Saved order templates
POST /api/mall/saved-orders            → Save order as template
POST /api/mall/saved-orders/{id}/reorder → One-tap reorder
```

### AI Assistant
```
POST /api/mall/{mallId}/ai/chat        → Chat (standard)
POST /api/mall/{mallId}/ai/chat/stream → Chat (SSE streaming)
GET  /api/mall/{mallId}/ai/chat/quick-replies → Quick replies
```

### Analytics & Export (Admin)
```
GET /api/mall/admin/analytics              → Full analytics (KPIs + charts)
GET /api/mall/admin/analytics/chart        → Revenue time-series
GET /api/mall/store/analytics              → Store-level analytics
GET /api/mall/admin/export/orders          → Export orders CSV
GET /api/mall/admin/export/commissions     → Export commissions CSV
GET /api/mall/admin/export/customers       → Export customers CSV
GET /api/mall/admin/export/loyalty         → Export loyalty CSV
GET /api/mall/admin/export/products        → Export product catalog CSV
```

### SuperAdmin
```
GET  /api/superadmin/overview                  → Platform overview
POST /api/superadmin/malls                     → Create mall
GET  /api/superadmin/malls/{id}/subscriptions  → Store subscriptions
POST /api/superadmin/stores/{id}/suspend       → Suspend store
POST /api/superadmin/stores/{id}/activate      → Activate store
GET/PUT /api/superadmin/settings/{key}         → Platform settings
```

### Real-time (SignalR)
```
WS /hubs/orders  → Join order room / store room
   Events: OrderStatusChanged, DriverAssigned, NewOrderReceived

WS /hubs/drivers → Driver location updates
   Methods: UpdateLocation, TrackDriver, StopTracking
   Events: DriverLocationUpdated
```

---

## 🎯 Background Jobs Schedule

| Job | Schedule | Purpose |
|-----|----------|---------|
| LoyaltyExpiryJob | Daily 02:00 UTC | Expire inactive loyalty points |
| AnalyticsSnapshotJob | Daily 23:55 UTC | Save daily KPI snapshot |
| CampaignSchedulerJob | Every 1 min | Send scheduled push campaigns |
| FlashSaleCleanupJob | Every 5 min | Deactivate expired flash sales + coupons |
| QueueCleanupJob | Every 15 min | Cancel stale queue tickets (>2h) |

---

## 🧪 Test Summary (40+ tests)

```
Phase 1-6 Tests (MallXTests.cs):
  CustomerAuth:    Register ✅ | Duplicate ✅ | Login ✅ | WrongPass ✅ | Lockout ✅
  Cart:            Add ✅ | AddSame ✅ | ExceedStock ✅ | Remove ✅ | Empty ✅
  Loyalty:         Earn ✅ | Silver1.5x ✅ | TierUpgrade ✅ | Redeem20% ✅ | GetWallet ✅
  Coupons:         Apply ✅ | Expired ✅ | PerCustomer ✅
  Ratings:         Submit ✅ | Duplicate ✅ | Summary ✅
  Booking:         Create ✅ | Cancel ✅
  Integration:     CartToCheckout→Split→StockDeduct ✅

Phase 9-12 Tests (Phase10Tests.cs):
  Wallet:          GetNew ✅ | TopUp ✅ | BelowMin ✅ | AboveMax ✅ |
                   Spend ✅ | Insufficient ✅ | Refund ✅ | Accumulate ✅
  Notifications:   Create ✅ | GetWithCount ✅ | MarkRead ✅ | MarkAll ✅ |
                   OrderStatus ✅ | TierUpGold ✅ | BulkCreate ✅
  ProductReviews:  Submit ✅ | InvalidStars ✅ | Duplicate ✅ |
                   Helpful++ ✅ | GetWithSummary ✅ | StoreReply ✅
  Reorder:         Save ✅ | GetList ✅ | Delete ✅ | WrongOwner ✅
  Referral:        GetCreate ✅ | SameCode ✅ | Apply ✅ |
                   OwnCode ✅ | Invalid ✅ | Duplicate ✅
  LoyaltyExpiry:   Expired ✅ | ActiveNotExpired ✅
```

---

## 🌟 Key Architectural Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Base framework | MesterXPro v2 | 60% reusable — no rebuild |
| DB migration | ALTER TABLE | Zero downtime, backward compat |
| Customer auth | Separate JWT | B2C isolated from B2B |
| Real-time | SignalR + Redis backplane | Native .NET, scale-out ready |
| Mobile | Flutter | Existing project files |
| Admin UI | Next.js 14 | Existing stack |
| AI | Anthropic Claude SSE | MallX system prompt ready |
| Payments | Paymob first | Egyptian market leader |
| Cache | Redis 7 | Already in MesterXPro stack |
| Geo distance | Haversine | No external map API needed |
| Search | PostgreSQL FTS | No Elasticsearch needed for MVP |

---

*MallX — كل اللي محتاجه في مول واحد 🏬*
*Excellence86 | 13 Phases | ~26,000 Lines | 93+ Files*
