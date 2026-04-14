-- ═══════════════════════════════════════════════════════════════════════════
-- MallX Performance Indexes
-- Run after all phase migrations for production optimization
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ── ORDERS (most queried table) ──────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mall_orders_customer_date
    ON mall_orders(customer_id, placed_at DESC)
    WHERE is_deleted = FALSE OR is_deleted IS NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mall_orders_mall_status_date
    ON mall_orders(mall_id, status, placed_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mall_orders_number
    ON mall_orders(order_number);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_store_orders_mall_order
    ON store_orders(mall_order_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_store_orders_store_status
    ON store_orders(store_id, status, created_at DESC);

-- ── CART (hot path — every add/view) ────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_carts_customer
    ON carts(customer_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cart_items_cart
    ON cart_items(cart_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_cart_items_product
    ON cart_items(product_id);

-- ── CUSTOMERS (auth lookups) ─────────────────────────────────────────────
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_customers_email_unique
    ON mall_customers(email)
    WHERE NOT is_deleted;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_customers_mall_tier
    ON mall_customers(mall_id, tier)
    WHERE NOT is_deleted;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_customers_phone
    ON mall_customers(phone)
    WHERE phone IS NOT NULL;

-- ── PRODUCTS (catalog browsing) ──────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_tenant_active
    ON products(tenant_id, is_active, is_deleted, sale_price);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_sku
    ON products(sku, tenant_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_products_barcode
    ON products(barcode)
    WHERE barcode IS NOT NULL;

-- ── STOCK (availability checks) ──────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stock_product_available
    ON stock_items(product_id, available_quantity)
    WHERE available_quantity > 0;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_stock_branch_low
    ON stock_items(branch_id, product_id)
    WHERE available_quantity <= min_stock_level;

-- ── LOYALTY (wallet & points) ─────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loyalty_accounts_customer
    ON loyalty_accounts(customer_id, mall_id);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_points_txn_account_date
    ON points_transactions(account_id, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_loyalty_expiry
    ON loyalty_accounts(points_expire_at)
    WHERE points_expire_at IS NOT NULL AND available_points > 0;

-- ── NOTIFICATIONS (unread badge) ─────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_notifs_customer_unread
    ON customer_notifications(customer_id, created_at DESC)
    WHERE NOT is_read;

-- ── RATINGS (store page) ─────────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_ratings_store_recent
    ON ratings(store_id, created_at DESC)
    WHERE is_published;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_product_reviews_product_recent
    ON product_reviews(product_id, created_at DESC)
    WHERE is_published;

-- ── PROMOTIONS (hot check on every checkout) ─────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_coupons_code_valid
    ON coupons(code, status, valid_to)
    WHERE status = 'Active';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_flash_sales_live
    ON flash_sales(mall_id, is_active, ends_at)
    WHERE is_active AND ends_at > NOW();

-- ── BOOKINGS (schedule view) ─────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_staff_date
    ON bookings(staff_id, booked_date, start_time)
    WHERE status NOT IN ('Cancelled', 'NoShow');

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_bookings_store_today
    ON bookings(store_id, booked_date)
    WHERE status NOT IN ('Cancelled', 'NoShow');

-- ── QUEUE TICKETS ────────────────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_queue_store_active
    ON queue_tickets(store_id, ticket_number)
    WHERE status IN ('Waiting', 'Preparing');

-- ── ANALYTICS (reporting queries) ────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_mall_orders_placed_mall
    ON mall_orders(mall_id, placed_at)
    INCLUDE (total, status, subtotal);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_store_orders_created_store
    ON store_orders(store_id, created_at)
    INCLUDE (subtotal, commission_amt);

-- ── SEARCH (trending queries) ────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_trending_searches_mall_date
    ON trending_searches(mall_id, date DESC, search_count DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_search_history_customer
    ON customer_search_history(customer_id, created_at DESC);

-- ── WALLET (balance checks) ──────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_wallet_customer_mall
    ON customer_wallets(customer_id, mall_id)
    WHERE is_active;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_wallet_txn_wallet_date
    ON wallet_transactions(wallet_id, created_at DESC);

-- ── REFERRAL ────────────────────────────────────────────────────────────
CREATE UNIQUE INDEX CONCURRENTLY IF NOT EXISTS idx_referral_codes_code
    ON referral_codes(code);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_referral_uses_referee
    ON referral_uses(referee_id, program_id);

-- ── API LOG (monitoring) ────────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_log_status_date
    ON api_request_log(status_code, created_at DESC)
    WHERE status_code >= 400;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_api_log_endpoint_date
    ON api_request_log(endpoint, created_at DESC);

-- ── PARTITIONED TABLE INDEXES ────────────────────────────────────────────
-- (partitioned tables need indexes on each partition)
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_activity_customer_event
    ON customer_activity(customer_id, event_type, created_at DESC);

-- ── ANALYZE statistics after index creation ───────────────────────────────
ANALYZE mall_orders;
ANALYZE store_orders;
ANALYZE products;
ANALYZE stock_items;
ANALYZE mall_customers;
ANALYZE loyalty_accounts;
ANALYZE points_transactions;
ANALYZE customer_notifications;
ANALYZE coupons;
ANALYZE flash_sales;
ANALYZE bookings;
ANALYZE ratings;
ANALYZE product_reviews;

COMMIT;

-- ── VACUUM & REINDEX (run separately during maintenance window) ───────────
-- VACUUM ANALYZE;
-- REINDEX DATABASE mallxpro;

-- ── Performance verification queries ─────────────────────────────────────
/*
-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC
LIMIT 30;

-- Find missing indexes (sequential scans on large tables)
SELECT
    schemaname,
    tablename,
    seq_scan,
    seq_tup_read,
    idx_scan,
    n_live_tup
FROM pg_stat_user_tables
WHERE seq_scan > 100
  AND n_live_tup > 1000
ORDER BY seq_tup_read DESC
LIMIT 20;

-- Check table sizes
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(quote_ident(tablename))) AS total_size,
    pg_size_pretty(pg_relation_size(quote_ident(tablename))) AS table_size,
    pg_size_pretty(pg_indexes_size(quote_ident(tablename))) AS indexes_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(quote_ident(tablename)) DESC;
*/
