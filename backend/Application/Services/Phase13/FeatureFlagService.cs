using MesterX.Application.DTOs;
using MesterX.Infrastructure.Caching;
using MesterX.Infrastructure.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace MesterX.Application.Services.Phase13;

// ══════════════════════════════════════════════════════════════════════════
//  PHASE 4 — FEATURE FLAGS SYSTEM
//  Every module in MallX can be toggled ON/OFF per mall tenant.
//  Middleware blocks requests to disabled modules automatically.
// ══════════════════════════════════════════════════════════════════════════

// ─── Domain Entities ──────────────────────────────────────────────────────
namespace MesterX.Domain.Entities.Phase13
{
    /// <summary>Master list of all platform features/modules</summary>
    public class FeatureFlag
    {
        [Key] public Guid   Id          { get; set; } = Guid.NewGuid();
        [Required, MaxLength(100)]
        public string  Name        { get; set; } = string.Empty;  // e.g. "Restaurant"
        [MaxLength(50)]
        public string  Key         { get; set; } = string.Empty;  // e.g. "restaurant"
        [MaxLength(250)]
        public string? Description { get; set; }
        public string  Category    { get; set; } = "Core";        // Core|Operations|Finance|CRM|Advanced
        public bool    IsActive    { get; set; } = true;
        public bool    DefaultOn   { get; set; } = true;          // new tenants get this ON by default
        public int     SortOrder   { get; set; } = 0;
        public DateTime CreatedAt  { get; set; } = DateTime.UtcNow;
        public virtual ICollection<TenantFeature> TenantFeatures { get; set; } = [];
    }

    /// <summary>Per-tenant feature on/off toggle</summary>
    public class TenantFeature
    {
        [Key] public Guid   Id         { get; set; } = Guid.NewGuid();
        public Guid   MallId     { get; set; }
        public Guid   FeatureId  { get; set; }
        public bool   IsEnabled  { get; set; } = true;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
        public virtual FeatureFlag Feature { get; set; } = null!;
    }
}

// ─── All Platform Features ─────────────────────────────────────────────────
public static class Features
{
    // Core
    public const string Cart          = "cart";
    public const string Orders        = "orders";
    public const string Checkout      = "checkout";
    public const string CustomerAuth  = "customer_auth";

    // Operations
    public const string Restaurant    = "restaurant";
    public const string Booking       = "booking";
    public const string Delivery      = "delivery";
    public const string POS           = "pos";

    // Finance
    public const string Payments      = "payments";
    public const string Wallet        = "wallet";
    public const string Commissions   = "commissions";

    // CRM
    public const string Loyalty       = "loyalty";
    public const string Promotions    = "promotions";
    public const string Referral      = "referral";
    public const string Notifications = "notifications";

    // Advanced
    public const string AIAssistant   = "ai_assistant";
    public const string Analytics     = "analytics";
    public const string MallMap       = "mall_map";
    public const string Reviews       = "reviews";
    public const string WhatsApp      = "whatsapp";
    public const string GeoFencing    = "geo_fencing";
    public const string FlashSales    = "flash_sales";
    public const string Export        = "export";

    // All features with defaults
    public static readonly (string key, string name, string category, bool defaultOn)[] All =
    [
        (CustomerAuth,  "تسجيل دخول العملاء",     "Core",      true),
        (Cart,          "سلة التسوق",              "Core",      true),
        (Orders,        "الطلبات",                  "Core",      true),
        (Checkout,      "الدفع والشراء",            "Core",      true),
        (Restaurant,    "قائمة الطعام والمطعم",     "Operations",true),
        (Booking,       "حجز المواعيد",             "Operations",true),
        (Delivery,      "خدمة التوصيل",             "Operations",true),
        (POS,           "نقطة البيع",               "Operations",false),
        (Payments,      "الدفع الإلكتروني",         "Finance",   true),
        (Wallet,        "المحفظة الإلكترونية",      "Finance",   true),
        (Commissions,   "نظام العمولات",             "Finance",   true),
        (Loyalty,       "نقاط الولاء",              "CRM",       true),
        (Promotions,    "العروض والكوبونات",         "CRM",       true),
        (Referral,      "نظام الإحالة",              "CRM",       false),
        (Notifications, "مركز الإشعارات",           "CRM",       true),
        (AIAssistant,   "المساعد الذكي",             "Advanced",  false),
        (Analytics,     "لوحة التحليلات",           "Advanced",  true),
        (MallMap,       "خريطة المول التفاعلية",    "Advanced",  false),
        (Reviews,       "تقييمات المنتجات",          "Advanced",  true),
        (WhatsApp,      "إشعارات واتساب",           "Advanced",  false),
        (GeoFencing,    "الإشعارات الجغرافية",      "Advanced",  false),
        (FlashSales,    "العروض المحدودة",           "Advanced",  true),
        (Export,        "تصدير البيانات",            "Advanced",  false),
    ];
}

// ─── Feature Flag Service ──────────────────────────────────────────────────
public interface IFeatureFlagService
{
    Task<bool> IsEnabledAsync(Guid mallId, string featureKey, CancellationToken ct = default);
    Task<ApiResponse<List<FeatureFlagDto>>> GetAllFeaturesAsync(Guid mallId, CancellationToken ct = default);
    Task<ApiResponse> ToggleAsync(Guid mallId, string featureKey, bool enabled, CancellationToken ct = default);
    Task SeedDefaultFeaturesAsync(Guid mallId, CancellationToken ct = default);
}

public record FeatureFlagDto
{
    public Guid   FeatureId  { get; init; }
    public string Key        { get; init; } = string.Empty;
    public string Name       { get; init; } = string.Empty;
    public string Category   { get; init; } = string.Empty;
    public bool   IsEnabled  { get; init; }
    public string? Description { get; init; }
}

public class FeatureFlagService : IFeatureFlagService
{
    private readonly MesterXDbContext _db;
    private readonly ICacheService    _cache;
    private readonly ILogger<FeatureFlagService> _log;
    private const string CachePrefix = "features:";
    private static readonly TimeSpan CacheTtl = TimeSpan.FromMinutes(10);

    public FeatureFlagService(MesterXDbContext db, ICacheService cache,
        ILogger<FeatureFlagService> log)
    { _db = db; _cache = cache; _log = log; }

    public async Task<bool> IsEnabledAsync(Guid mallId, string featureKey,
        CancellationToken ct = default)
    {
        var cacheKey = $"{CachePrefix}{mallId}:{featureKey}";
        var cached   = await _cache.GetAsync<bool?>(cacheKey, ct);
        if (cached.HasValue) return cached.Value;

        var tenantFeat = await _db.Set<Domain.Entities.Phase13.TenantFeature>()
            .AsNoTracking()
            .Include(tf => tf.Feature)
            .FirstOrDefaultAsync(tf =>
                tf.MallId == mallId && tf.Feature.Key == featureKey, ct);

        bool result;
        if (tenantFeat == null)
        {
            // Use default from feature definition
            var feat = await _db.Set<Domain.Entities.Phase13.FeatureFlag>()
                .AsNoTracking()
                .FirstOrDefaultAsync(f => f.Key == featureKey, ct);
            result = feat?.DefaultOn ?? true;
        }
        else
        {
            result = tenantFeat.IsEnabled;
        }

        await _cache.SetAsync(cacheKey, result, CacheTtl, ct);
        return result;
    }

    public async Task<ApiResponse<List<FeatureFlagDto>>> GetAllFeaturesAsync(
        Guid mallId, CancellationToken ct = default)
    {
        var allFlags = await _db.Set<Domain.Entities.Phase13.FeatureFlag>()
            .AsNoTracking()
            .Where(f => f.IsActive)
            .ToListAsync(ct);

        var tenantFeatures = await _db.Set<Domain.Entities.Phase13.TenantFeature>()
            .AsNoTracking()
            .Where(tf => tf.MallId == mallId)
            .ToDictionaryAsync(tf => tf.FeatureId, tf => tf.IsEnabled, ct);

        var dtos = allFlags.OrderBy(f => f.Category).ThenBy(f => f.SortOrder)
            .Select(f => new FeatureFlagDto
            {
                FeatureId   = f.Id,
                Key         = f.Key,
                Name        = f.Name,
                Category    = f.Category,
                Description = f.Description,
                IsEnabled   = tenantFeatures.TryGetValue(f.Id, out var en) ? en : f.DefaultOn,
            }).ToList();

        return ApiResponse<List<FeatureFlagDto>>.Ok(dtos);
    }

    public async Task<ApiResponse> ToggleAsync(Guid mallId, string featureKey,
        bool enabled, CancellationToken ct = default)
    {
        var flag = await _db.Set<Domain.Entities.Phase13.FeatureFlag>()
            .FirstOrDefaultAsync(f => f.Key == featureKey, ct);
        if (flag == null)
            return ApiResponse.Fail($"الميزة '{featureKey}' غير موجودة.");

        var existing = await _db.Set<Domain.Entities.Phase13.TenantFeature>()
            .FirstOrDefaultAsync(tf => tf.MallId == mallId && tf.FeatureId == flag.Id, ct);

        if (existing == null)
        {
            _db.Set<Domain.Entities.Phase13.TenantFeature>().Add(new()
            {
                Id = Guid.NewGuid(), MallId = mallId, FeatureId = flag.Id,
                IsEnabled = enabled, UpdatedAt = DateTime.UtcNow,
            });
        }
        else
        {
            existing.IsEnabled = enabled;
            existing.UpdatedAt = DateTime.UtcNow;
        }

        await _db.SaveChangesAsync(ct);

        // Invalidate cache
        await _cache.DeleteAsync($"{CachePrefix}{mallId}:{featureKey}", ct);
        _log.LogInformation("Feature {Key} → {State} for mall {Mall}",
            featureKey, enabled ? "ON" : "OFF", mallId);

        return ApiResponse.Ok($"تم {(enabled ? "تفعيل" : "تعطيل")} الميزة '{flag.Name}'.");
    }

    public async Task SeedDefaultFeaturesAsync(Guid mallId, CancellationToken ct = default)
    {
        // Seed all feature flags into DB (master list)
        foreach (var (key, name, category, defaultOn) in Features.All)
        {
            var exists = await _db.Set<Domain.Entities.Phase13.FeatureFlag>()
                .AnyAsync(f => f.Key == key, ct);
            if (!exists)
            {
                _db.Set<Domain.Entities.Phase13.FeatureFlag>().Add(new()
                {
                    Id = Guid.NewGuid(), Key = key, Name = name,
                    Category = category, DefaultOn = defaultOn, IsActive = true,
                });
            }
        }
        await _db.SaveChangesAsync(ct);
        _log.LogInformation("Feature flags seeded for mall {Mall}", mallId);
    }
}

// ─── Feature Flag Middleware ───────────────────────────────────────────────
/// <summary>
/// Intercepts requests and checks if the required module is enabled for this mall.
/// Maps URL patterns to feature keys automatically.
/// </summary>
public class FeatureFlagMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<FeatureFlagMiddleware> _log;

    // Map URL path segments → feature key
    private static readonly Dictionary<string, string> _routeMap = new()
    {
        ["/restaurant"]   = Features.Restaurant,
        ["/booking"]      = Features.Booking,
        ["/loyalty"]      = Features.Loyalty,
        ["/promotions"]   = Features.Promotions,
        ["/wallet"]       = Features.Wallet,
        ["/referral"]     = Features.Referral,
        ["/ai/chat"]      = Features.AIAssistant,
        ["/analytics"]    = Features.Analytics,
        ["/mall-map"]     = Features.MallMap,
        ["/map"]          = Features.MallMap,
        ["/notifications"]= Features.Notifications,
        ["/export"]       = Features.Export,
        ["/geo"]          = Features.GeoFencing,
        ["/reviews"]      = Features.Reviews,
        ["/campaigns"]    = Features.Promotions,
        ["/flash-sales"]  = Features.FlashSales,
        ["/drivers"]      = Features.Delivery,
        ["/cart"]         = Features.Cart,
        ["/orders"]       = Features.Orders,
        ["/checkout"]     = Features.Checkout,
    };

    public FeatureFlagMiddleware(RequestDelegate next,
        ILogger<FeatureFlagMiddleware> log)
    { _next = next; _log = log; }

    public async Task InvokeAsync(HttpContext ctx,
        IFeatureFlagService featureService)
    {
        var path   = ctx.Request.Path.Value?.ToLower() ?? "";
        var mallId = ExtractMallId(ctx);

        if (mallId != Guid.Empty)
        {
            var requiredFeature = GetRequiredFeature(path);
            if (requiredFeature != null)
            {
                var enabled = await featureService.IsEnabledAsync(mallId, requiredFeature);
                if (!enabled)
                {
                    _log.LogWarning("Blocked: feature '{Feature}' disabled for mall {Mall}",
                        requiredFeature, mallId);
                    ctx.Response.StatusCode = 403;
                    ctx.Response.ContentType = "application/json";
                    await ctx.Response.WriteAsync(
                        $"{{\"success\":false,\"error\":\"هذه الخدمة غير مفعّلة في المول. تواصل مع إدارة المول.\"}}");
                    return;
                }
            }
        }

        await _next(ctx);
    }

    private static string? GetRequiredFeature(string path)
    {
        foreach (var (segment, feature) in _routeMap)
            if (path.Contains(segment)) return feature;
        return null;
    }

    private static Guid ExtractMallId(HttpContext ctx)
    {
        // Try route data
        if (ctx.Request.RouteValues.TryGetValue("mallId", out var routeMallId)
            && Guid.TryParse(routeMallId?.ToString(), out var g1)) return g1;

        // Try query string
        if (Guid.TryParse(ctx.Request.Query["mallId"].ToString(), out var g2)) return g2;

        // Try JWT claim
        var claim = ctx.User.FindFirst("mall_id")?.Value;
        if (Guid.TryParse(claim, out var g3)) return g3;

        return Guid.Empty;
    }
}

// ─── Feature Flag Controller ───────────────────────────────────────────────
namespace MesterX.API.Controllers.Phase13
{
    using Microsoft.AspNetCore.Authorization;
    using Microsoft.AspNetCore.Mvc;
    using System.Security.Claims;

    [Authorize(Roles = "PlatformOwner,CompanyOwner"), ApiController]
    [Route("api/mall/admin/features")]
    public class FeatureFlagsController : ControllerBase
    {
        private readonly IFeatureFlagService _svc;
        private Guid MallId => Guid.TryParse(
            User.FindFirstValue("mall_id"), out var g) ? g : Guid.Empty;

        public FeatureFlagsController(IFeatureFlagService svc) => _svc = svc;

        /// <summary>Get all features with current on/off status for this mall</summary>
        [HttpGet]
        public async Task<IActionResult> GetAll(CancellationToken ct)
        {
            var result = await _svc.GetAllFeaturesAsync(MallId, ct);
            return Ok(result);
        }

        /// <summary>Toggle a feature on or off for this mall</summary>
        [HttpPatch("{featureKey}")]
        public async Task<IActionResult> Toggle(
            string featureKey, [FromBody] ToggleFeatureRequest req,
            CancellationToken ct)
        {
            var result = await _svc.ToggleAsync(MallId, featureKey, req.Enabled, ct);
            return result.Success ? Ok(result) : BadRequest(result);
        }

        /// <summary>Seed default feature flags for this mall</summary>
        [HttpPost("seed")]
        [Authorize(Roles = "PlatformOwner")]
        public async Task<IActionResult> Seed(CancellationToken ct)
        {
            await _svc.SeedDefaultFeaturesAsync(MallId, ct);
            return Ok(new { success = true, message = "تم زرع الإعدادات الافتراضية." });
        }
    }

    public record ToggleFeatureRequest(bool Enabled);
}
