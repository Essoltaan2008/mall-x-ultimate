-- ═══════════════════════════════════════════════════════════════════════════
-- PHASE 4: Feature Flags System + Phase 5: Monetization Engine
-- Run AFTER phase10 migration
-- ═══════════════════════════════════════════════════════════════════════════

BEGIN;

-- ──────────────────────────────────────────────────────────────────────────
--  FEATURE FLAGS (master list of all platform features)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS feature_flags (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key         VARCHAR(100) UNIQUE NOT NULL,   -- e.g. "restaurant"
    name        VARCHAR(200) NOT NULL,           -- Arabic display name
    description TEXT,
    category    VARCHAR(50)  NOT NULL DEFAULT 'Core',
    is_active   BOOLEAN NOT NULL DEFAULT TRUE,
    default_on  BOOLEAN NOT NULL DEFAULT TRUE,   -- default state for new malls
    sort_order  INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_feature_flags_key ON feature_flags(key);
CREATE INDEX IF NOT EXISTS idx_feature_flags_category ON feature_flags(category, sort_order);

-- ──────────────────────────────────────────────────────────────────────────
--  TENANT FEATURES (per-mall overrides)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS tenant_features (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mall_id     UUID NOT NULL REFERENCES malls(id) ON DELETE CASCADE,
    feature_id  UUID NOT NULL REFERENCES feature_flags(id) ON DELETE CASCADE,
    is_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(mall_id, feature_id)
);

CREATE INDEX IF NOT EXISTS idx_tenant_features_mall ON tenant_features(mall_id);
CREATE INDEX IF NOT EXISTS idx_tenant_features_lookup ON tenant_features(mall_id, feature_id);

-- ──────────────────────────────────────────────────────────────────────────
--  PLANS (monetization)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS plans (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key             VARCHAR(50) UNIQUE NOT NULL,  -- free|basic|pro|enterprise
    name_ar         VARCHAR(100) NOT NULL,
    name_en         VARCHAR(100) NOT NULL,
    monthly_price   DECIMAL(10,2) NOT NULL DEFAULT 0,
    yearly_price    DECIMAL(10,2) NOT NULL DEFAULT 0,
    max_products    INT NOT NULL DEFAULT 10,   -- -1 = unlimited
    max_stores      INT NOT NULL DEFAULT 1,
    max_users       INT NOT NULL DEFAULT 2,
    max_branches    INT NOT NULL DEFAULT 1,
    commission_rate DECIMAL(5,4) NOT NULL DEFAULT 0.10,
    has_analytics   BOOLEAN NOT NULL DEFAULT FALSE,
    has_ai          BOOLEAN NOT NULL DEFAULT FALSE,
    has_export      BOOLEAN NOT NULL DEFAULT FALSE,
    has_whatsapp    BOOLEAN NOT NULL DEFAULT FALSE,
    is_popular      BOOLEAN NOT NULL DEFAULT FALSE,
    sort_order      INT NOT NULL DEFAULT 0,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO plans (key, name_ar, name_en, monthly_price, yearly_price,
    max_products, max_stores, max_users, max_branches, commission_rate,
    has_analytics, has_ai, has_export, is_popular, sort_order)
VALUES
    ('free',       'مجاني',     'Free',       0,    0,     10,   1,  2,  1, 0.10, FALSE, FALSE, FALSE, FALSE, 1),
    ('basic',      'أساسي',     'Basic',     199, 1990,   200,  3, 10,  3, 0.05, FALSE, FALSE, FALSE, FALSE, 2),
    ('pro',        'احترافي',   'Pro',       499, 4990,  2000, 15, 50, 10, 0.03, TRUE,  FALSE, TRUE,  TRUE,  3),
    ('enterprise', 'مؤسسي',     'Enterprise',999, 9990,   -1,  -1, -1, -1, 0.015,TRUE,  TRUE,  TRUE,  FALSE, 4)
ON CONFLICT (key) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────────
--  MALL SUBSCRIPTIONS (tenant → plan mapping)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mall_subscriptions (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    mall_id             UUID NOT NULL REFERENCES malls(id) ON DELETE CASCADE,
    plan_id             UUID NOT NULL REFERENCES plans(id),
    status              VARCHAR(30) NOT NULL DEFAULT 'Trial',  -- Trial|Active|Suspended|Cancelled
    billing_cycle       VARCHAR(20) NOT NULL DEFAULT 'Monthly', -- Monthly|Yearly
    amount              DECIMAL(10,2) NOT NULL DEFAULT 0,
    trial_ends_at       TIMESTAMPTZ,
    current_period_start TIMESTAMPTZ,
    current_period_end  TIMESTAMPTZ,
    next_billing_at     TIMESTAMPTZ,
    auto_renew          BOOLEAN NOT NULL DEFAULT TRUE,
    cancelled_at        TIMESTAMPTZ,
    cancel_reason       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_mall_subscriptions_active
    ON mall_subscriptions(mall_id) WHERE status IN ('Trial','Active');

CREATE INDEX IF NOT EXISTS idx_mall_subscriptions_renewal
    ON mall_subscriptions(next_billing_at) WHERE status = 'Active';

-- ──────────────────────────────────────────────────────────────────────────
--  USAGE METRICS (track limits in real-time)
-- ──────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS mall_usage_metrics (
    mall_id         UUID PRIMARY KEY REFERENCES malls(id) ON DELETE CASCADE,
    products_count  INT NOT NULL DEFAULT 0,
    stores_count    INT NOT NULL DEFAULT 0,
    users_count     INT NOT NULL DEFAULT 0,
    orders_this_month INT NOT NULL DEFAULT 0,
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────────────────────────────
--  SEED DEFAULT FEATURES (all platform features)
-- ──────────────────────────────────────────────────────────────────────────
INSERT INTO feature_flags (key, name, category, default_on, sort_order) VALUES
    ('customer_auth',   'تسجيل دخول العملاء',      'Core',       TRUE,  1),
    ('cart',            'سلة التسوق',               'Core',       TRUE,  2),
    ('orders',          'نظام الطلبات',             'Core',       TRUE,  3),
    ('checkout',        'الدفع والشراء',             'Core',       TRUE,  4),
    ('restaurant',      'قائمة الطعام والمطعم',     'Operations', TRUE,  5),
    ('booking',         'حجز المواعيد',             'Operations', TRUE,  6),
    ('delivery',        'خدمة التوصيل',             'Operations', TRUE,  7),
    ('pos',             'نقطة البيع',               'Operations', FALSE, 8),
    ('payments',        'الدفع الإلكتروني',         'Finance',    TRUE,  9),
    ('wallet',          'المحفظة الإلكترونية',      'Finance',    TRUE,  10),
    ('commissions',     'نظام العمولات',             'Finance',    TRUE,  11),
    ('loyalty',         'نقاط الولاء',              'CRM',        TRUE,  12),
    ('promotions',      'العروض والكوبونات',         'CRM',        TRUE,  13),
    ('referral',        'نظام الإحالة',              'CRM',        FALSE, 14),
    ('notifications',   'مركز الإشعارات',           'CRM',        TRUE,  15),
    ('ai_assistant',    'المساعد الذكي',             'Advanced',   FALSE, 16),
    ('analytics',       'لوحة التحليلات',           'Advanced',   TRUE,  17),
    ('mall_map',        'خريطة المول التفاعلية',    'Advanced',   FALSE, 18),
    ('reviews',         'تقييمات المنتجات',          'Advanced',   TRUE,  19),
    ('whatsapp',        'إشعارات واتساب',           'Advanced',   FALSE, 20),
    ('geo_fencing',     'الإشعارات الجغرافية',      'Advanced',   FALSE, 21),
    ('flash_sales',     'العروض المحدودة',           'Advanced',   TRUE,  22),
    ('export',          'تصدير البيانات',            'Advanced',   FALSE, 23)
ON CONFLICT (key) DO NOTHING;

-- ──────────────────────────────────────────────────────────────────────────
--  FUNCTION: Initialize mall with default features + subscription
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION initialize_mall_defaults(p_mall_id UUID)
RETURNS VOID AS $$
DECLARE
    v_feature_id UUID;
    v_plan_id    UUID;
BEGIN
    -- Create default ON tenant_features for this mall
    FOR v_feature_id IN
        SELECT id FROM feature_flags WHERE default_on = TRUE AND is_active = TRUE
    LOOP
        INSERT INTO tenant_features (mall_id, feature_id, is_enabled)
        VALUES (p_mall_id, v_feature_id, TRUE)
        ON CONFLICT (mall_id, feature_id) DO NOTHING;
    END LOOP;

    -- Create trial subscription on Basic plan
    SELECT id INTO v_plan_id FROM plans WHERE key = 'basic' LIMIT 1;
    INSERT INTO mall_subscriptions (
        mall_id, plan_id, status, trial_ends_at,
        current_period_start, current_period_end, next_billing_at, amount)
    VALUES (
        p_mall_id, v_plan_id, 'Trial',
        NOW() + INTERVAL '14 days',
        NOW(), NOW() + INTERVAL '14 days',
        NOW() + INTERVAL '14 days', 0)
    ON CONFLICT DO NOTHING;

    -- Initialize usage metrics
    INSERT INTO mall_usage_metrics (mall_id) VALUES (p_mall_id)
    ON CONFLICT DO NOTHING;
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────────────────────────────────
--  VIEW: mall plan status (easy join for API)
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_mall_plan_status AS
SELECT
    m.id                 AS mall_id,
    m.name               AS mall_name,
    p.key                AS plan_key,
    p.name_ar            AS plan_name_ar,
    ms.status            AS sub_status,
    ms.trial_ends_at,
    ms.current_period_end,
    ms.next_billing_at,
    p.max_products,
    p.max_stores,
    p.max_users,
    p.commission_rate,
    p.has_analytics,
    p.has_ai,
    p.has_export,
    p.has_whatsapp,
    COALESCE(um.products_count, 0) AS products_used,
    COALESCE(um.stores_count, 0)   AS stores_used,
    COALESCE(um.users_count, 0)    AS users_used
FROM malls m
LEFT JOIN mall_subscriptions ms ON m.id = ms.mall_id
    AND ms.status IN ('Trial','Active')
LEFT JOIN plans p ON ms.plan_id = p.id
LEFT JOIN mall_usage_metrics um ON m.id = um.mall_id
WHERE m.is_active = TRUE;

-- ──────────────────────────────────────────────────────────────────────────
--  TRIGGER: Update usage metrics when products change
-- ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_products_usage()
RETURNS TRIGGER AS $$
DECLARE
    v_mall_id UUID;
BEGIN
    -- Get mall_id from tenant → EF Property
    SELECT EF_PROPERTY(t.id, 'MallId') INTO v_mall_id
    FROM tenants t WHERE t.id = COALESCE(NEW.tenant_id, OLD.tenant_id)
    LIMIT 1;

    IF v_mall_id IS NOT NULL THEN
        INSERT INTO mall_usage_metrics (mall_id, products_count, updated_at)
        VALUES (v_mall_id,
            (SELECT COUNT(*) FROM products
             WHERE tenant_id IN (SELECT id FROM tenants WHERE EF_PROPERTY(id,'MallId') = v_mall_id)
             AND is_active AND NOT is_deleted), NOW())
        ON CONFLICT (mall_id) DO UPDATE
        SET products_count = EXCLUDED.products_count, updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;

-- ──────────────────────────────────────────────────────────────────────────
--  PERFORMANCE INDEXES
-- ──────────────────────────────────────────────────────────────────────────
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_tenant_features_fast
    ON tenant_features(mall_id, feature_id, is_enabled);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_plans_active
    ON plans(is_active, sort_order) WHERE is_active = TRUE;

SELECT 'Phase 4+5 migration complete ✅' AS status;
