-- ═══════════════════════════════════════════════════════════════════════════
-- MallX Phase 10 — Notifications Center + Product Reviews + Reorder + Activity
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
--  IN-APP NOTIFICATIONS CENTER
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TYPE notif_category AS ENUM (
    'Order','Delivery','Loyalty','Promo','Booking',
    'Payment','Referral','System','Wallet'
);

CREATE TABLE customer_notifications (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID          NOT NULL REFERENCES mall_customers(id) ON DELETE CASCADE,
    mall_id     UUID          NOT NULL REFERENCES malls(id),
    category    notif_category NOT NULL DEFAULT 'System',
    title       VARCHAR(200)  NOT NULL,
    body        TEXT          NOT NULL,
    image_url   TEXT,
    action_type VARCHAR(50),              -- OpenOrder | OpenBooking | OpenPromo | OpenWallet
    action_id   VARCHAR(100),
    is_read     BOOLEAN       DEFAULT FALSE,
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ   DEFAULT NOW()
);
CREATE INDEX idx_notif_customer  ON customer_notifications(customer_id, is_read, created_at DESC);
CREATE INDEX idx_notif_unread    ON customer_notifications(customer_id, mall_id)
    WHERE is_read = FALSE;

-- Unread count cache (maintained by triggers)
CREATE TABLE customer_notif_count (
    customer_id  UUID PRIMARY KEY REFERENCES mall_customers(id) ON DELETE CASCADE,
    unread_count INTEGER DEFAULT 0,
    updated_at   TIMESTAMPTZ DEFAULT NOW()
);

-- Auto update unread count
CREATE OR REPLACE FUNCTION update_notif_count()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO customer_notif_count (customer_id, unread_count)
    VALUES (NEW.customer_id,
        (SELECT COUNT(*) FROM customer_notifications
         WHERE customer_id = NEW.customer_id AND NOT is_read))
    ON CONFLICT (customer_id) DO UPDATE SET
        unread_count = EXCLUDED.unread_count,
        updated_at   = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_notif_count
AFTER INSERT OR UPDATE ON customer_notifications
FOR EACH ROW EXECUTE FUNCTION update_notif_count();

-- ═══════════════════════════════════════════════════════════════════════════
--  PRODUCT-LEVEL REVIEWS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE product_reviews (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id      UUID         NOT NULL REFERENCES products(id),
    store_id        UUID         NOT NULL REFERENCES tenants(id),
    customer_id     UUID         NOT NULL REFERENCES mall_customers(id),
    mall_order_id   UUID         REFERENCES mall_orders(id),
    stars           SMALLINT     NOT NULL CHECK (stars BETWEEN 1 AND 5),
    title           VARCHAR(100),
    body            TEXT,
    images          TEXT[],
    is_verified_purchase BOOLEAN  DEFAULT FALSE,  -- from actual order
    helpful_count   INTEGER       DEFAULT 0,
    is_published    BOOLEAN       DEFAULT TRUE,
    store_reply     TEXT,
    store_replied_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ   DEFAULT NOW(),
    UNIQUE(product_id, customer_id, mall_order_id)
);
CREATE INDEX idx_product_reviews_product ON product_reviews(product_id, is_published, created_at DESC);
CREATE INDEX idx_product_reviews_store   ON product_reviews(store_id, created_at DESC);

-- Product rating summary (auto-updated by trigger like store)
CREATE TABLE product_rating_summary (
    product_id    UUID PRIMARY KEY REFERENCES products(id),
    avg_stars     NUMERIC(3,2) DEFAULT 0,
    total_reviews INTEGER      DEFAULT 0,
    five_star     INTEGER      DEFAULT 0,
    four_star     INTEGER      DEFAULT 0,
    three_star    INTEGER      DEFAULT 0,
    two_star      INTEGER      DEFAULT 0,
    one_star      INTEGER      DEFAULT 0,
    updated_at    TIMESTAMPTZ  DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_product_rating()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO product_rating_summary
        (product_id, avg_stars, total_reviews, five_star, four_star, three_star, two_star, one_star)
    SELECT NEW.product_id,
        ROUND(AVG(stars)::NUMERIC, 2), COUNT(*),
        COUNT(*) FILTER (WHERE stars=5), COUNT(*) FILTER (WHERE stars=4),
        COUNT(*) FILTER (WHERE stars=3), COUNT(*) FILTER (WHERE stars=2),
        COUNT(*) FILTER (WHERE stars=1)
    FROM product_reviews WHERE product_id = NEW.product_id AND is_published
    ON CONFLICT (product_id) DO UPDATE SET
        avg_stars = EXCLUDED.avg_stars, total_reviews = EXCLUDED.total_reviews,
        five_star = EXCLUDED.five_star, four_star = EXCLUDED.four_star,
        three_star= EXCLUDED.three_star, two_star = EXCLUDED.two_star,
        one_star  = EXCLUDED.one_star, updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_product_rating
AFTER INSERT OR UPDATE ON product_reviews
FOR EACH ROW EXECUTE FUNCTION update_product_rating();

-- ═══════════════════════════════════════════════════════════════════════════
--  REORDER / SAVED ORDERS
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE saved_orders (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID         NOT NULL REFERENCES mall_customers(id) ON DELETE CASCADE,
    mall_id     UUID         NOT NULL REFERENCES malls(id),
    name        VARCHAR(100) NOT NULL DEFAULT 'طلبي المفضل',
    items       JSONB        NOT NULL,   -- [{storeId, productId, qty, price}]
    total_est   NUMERIC(12,2),
    last_ordered TIMESTAMPTZ,
    order_count INTEGER      DEFAULT 0,
    is_active   BOOLEAN      DEFAULT TRUE,
    created_at  TIMESTAMPTZ  DEFAULT NOW(),
    updated_at  TIMESTAMPTZ  DEFAULT NOW()
);
CREATE INDEX idx_saved_orders ON saved_orders(customer_id, is_active);

-- ═══════════════════════════════════════════════════════════════════════════
--  CUSTOMER ACTIVITY LOG (for AI personalization)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE customer_activity (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id UUID         NOT NULL REFERENCES mall_customers(id) ON DELETE CASCADE,
    mall_id     UUID         NOT NULL REFERENCES malls(id),
    event_type  VARCHAR(50)  NOT NULL,  -- ViewStore|ViewProduct|AddToCart|Search|OpenNotif
    entity_type VARCHAR(30),
    entity_id   UUID,
    metadata    JSONB,
    created_at  TIMESTAMPTZ  DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE customer_activity_recent
    PARTITION OF customer_activity
    FOR VALUES FROM (NOW() - INTERVAL '30 days') TO (NOW() + INTERVAL '30 days');

CREATE INDEX idx_activity ON customer_activity (customer_id, event_type, created_at DESC);

-- ═══════════════════════════════════════════════════════════════════════════
--  API REQUEST LOG (for monitoring & rate limiting)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE api_request_log (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    endpoint    VARCHAR(200),
    method      VARCHAR(10),
    status_code INTEGER,
    duration_ms INTEGER,
    customer_id UUID,
    ip_address  VARCHAR(50),
    user_agent  VARCHAR(250),
    error_msg   TEXT,
    created_at  TIMESTAMPTZ DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE api_request_log_recent
    PARTITION OF api_request_log
    FOR VALUES FROM (NOW() - INTERVAL '7 days') TO (NOW() + INTERVAL '7 days');

CREATE INDEX idx_api_log_endpoint ON api_request_log(endpoint, created_at DESC);
CREATE INDEX idx_api_log_errors   ON api_request_log(status_code, created_at DESC)
    WHERE status_code >= 400;

COMMIT;
