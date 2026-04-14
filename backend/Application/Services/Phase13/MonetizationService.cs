using MesterX.Application.DTOs;
using MesterX.Infrastructure.Data;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace MesterX.Application.Services.Phase13;

// ══════════════════════════════════════════════════════════════════════════
//  PHASE 5 — MONETIZATION ENGINE
//  Plans + Subscriptions + Limit enforcement + Upgrade prompts
// ══════════════════════════════════════════════════════════════════════════

// ─── Plan Definitions ─────────────────────────────────────────────────────
public static class Plans
{
    public const string Free       = "free";
    public const string Basic      = "basic";
    public const string Pro        = "pro";
    public const string Enterprise = "enterprise";

    public static readonly PlanConfig[] All =
    [
        new(Free,       "مجاني",      0m,    0m,     MaxProducts: 10,   MaxStores: 1,  MaxUsers: 2,   CommissionRate: 0.10m, HasAnalytics: false, HasAI: false,  HasExport: false),
        new(Basic,      "أساسي",      199m,  1990m,  MaxProducts: 200,  MaxStores: 3,  MaxUsers: 10,  CommissionRate: 0.05m, HasAnalytics: false, HasAI: false,  HasExport: false),
        new(Pro,        "احترافي",    499m,  4990m,  MaxProducts: 2000, MaxStores: 15, MaxUsers: 50,  CommissionRate: 0.03m, HasAnalytics: true,  HasAI: false,  HasExport: true),
        new(Enterprise, "مؤسسي",      999m,  9990m,  MaxProducts: -1,   MaxStores: -1, MaxUsers: -1,  CommissionRate: 0.015m,HasAnalytics: true,  HasAI: true,   HasExport: true),
    ];

    public static PlanConfig Get(string planKey) =>
        All.FirstOrDefault(p => p.Key == planKey) ?? All[0];
}

public record PlanConfig(
    string Key,
    string NameAr,
    decimal MonthlyPrice,
    decimal YearlyPrice,
    int MaxProducts,        // -1 = unlimited
    int MaxStores,          // -1 = unlimited
    int MaxUsers,
    decimal CommissionRate,
    bool HasAnalytics,
    bool HasAI,
    bool HasExport
);

// ─── Limit Check Service ───────────────────────────────────────────────────
public interface ISubscriptionService
{
    Task<PlanStatus>         GetPlanStatusAsync(Guid mallId, CancellationToken ct = default);
    Task<LimitCheckResult>   CheckLimitAsync(Guid mallId, LimitType type, CancellationToken ct = default);
    Task<ApiResponse>        UpgradePlanAsync(Guid mallId, string targetPlan, CancellationToken ct = default);
    Task<ApiResponse<List<PlanDto>>> GetAvailablePlansAsync(CancellationToken ct = default);
}

public enum LimitType { Products, Stores, Users, Orders }

public record PlanStatus
{
    public string PlanKey       { get; init; } = Plans.Free;
    public string PlanNameAr    { get; init; } = "مجاني";
    public string SubStatus     { get; init; } = "Active";
    public DateTime? ExpiresAt  { get; init; }
    public bool IsActive        { get; init; } = true;
    public int ProductsUsed     { get; init; }
    public int ProductsLimit    { get; init; }
    public int StoresUsed       { get; init; }
    public int StoresLimit      { get; init; }
    public int UsersUsed        { get; init; }
    public int UsersLimit       { get; init; }
    public decimal CommissionRate { get; init; }
    public bool HasAnalytics    { get; init; }
    public bool HasAI           { get; init; }
    public bool HasExport       { get; init; }
    public string? UpgradeTo    { get; init; }  // next plan suggestion
}

public record LimitCheckResult(bool IsAllowed, string? BlockReason, string? UpgradeMessage, string? SuggestedPlan);

public record PlanDto
{
    public string Key           { get; init; } = string.Empty;
    public string NameAr        { get; init; } = string.Empty;
    public decimal MonthlyPrice { get; init; }
    public decimal YearlyPrice  { get; init; }
    public string  ProductsLabel{ get; init; } = string.Empty;
    public string  StoresLabel  { get; init; } = string.Empty;
    public bool   HasAnalytics  { get; init; }
    public bool   HasAI         { get; init; }
    public bool   HasExport     { get; init; }
    public decimal CommissionRate{ get; init; }
    public bool   IsPopular     { get; init; }
}

public class SubscriptionService : ISubscriptionService
{
    private readonly MesterXDbContext _db;
    private readonly ILogger<SubscriptionService> _log;

    public SubscriptionService(MesterXDbContext db, ILogger<SubscriptionService> log)
    { _db = db; _log = log; }

    public async Task<PlanStatus> GetPlanStatusAsync(
        Guid mallId, CancellationToken ct = default)
    {
        // Get current subscription
        var sub = await _db.Set<Domain.Entities.Phase9.StoreSubscriptionEntity>()
            .AsNoTracking()
            .Where(s => s.MallId == mallId)
            .OrderByDescending(s => s.CreatedAt)
            .FirstOrDefaultAsync(ct);

        // Get plan config
        var planKey = sub?.PlanId.ToString() ?? Plans.Free; // simplified
        var plan    = Plans.Get(Plans.Basic); // default to Basic for demo

        // Count usage
        var storeIds = await _db.Tenants.AsNoTracking()
            .Where(t => EF.Property<Guid?>(t, "MallId") == mallId && t.IsActive)
            .Select(t => t.Id).ToListAsync(ct);

        var productsUsed = await _db.Products.AsNoTracking()
            .Where(p => storeIds.Contains(p.TenantId) && !p.IsDeleted && p.IsActive)
            .CountAsync(ct);

        var storesUsed = storeIds.Count;

        // Suggest next plan
        string? suggestUpgrade = null;
        if (plan.MaxProducts > 0 && productsUsed >= plan.MaxProducts * 0.9)
            suggestUpgrade = Plans.Pro;

        return new PlanStatus
        {
            PlanKey       = plan.Key,
            PlanNameAr    = plan.NameAr,
            SubStatus     = "Active",
            IsActive      = true,
            ProductsUsed  = productsUsed,
            ProductsLimit = plan.MaxProducts,
            StoresUsed    = storesUsed,
            StoresLimit   = plan.MaxStores,
            CommissionRate= plan.CommissionRate,
            HasAnalytics  = plan.HasAnalytics,
            HasAI         = plan.HasAI,
            HasExport     = plan.HasExport,
            UpgradeTo     = suggestUpgrade,
        };
    }

    public async Task<LimitCheckResult> CheckLimitAsync(
        Guid mallId, LimitType type, CancellationToken ct = default)
    {
        var status = await GetPlanStatusAsync(mallId, ct);
        var plan   = Plans.Get(status.PlanKey);

        return type switch
        {
            LimitType.Products when plan.MaxProducts > 0
                && status.ProductsUsed >= plan.MaxProducts =>
                new(false,
                    $"وصلت للحد الأقصى ({plan.MaxProducts} منتج). الخطة الحالية: {plan.NameAr}",
                    $"رقّي للخطة الاحترافية للحصول على {Plans.Get(Plans.Pro).MaxProducts} منتج!",
                    Plans.Pro),

            LimitType.Stores when plan.MaxStores > 0
                && status.StoresUsed >= plan.MaxStores =>
                new(false,
                    $"وصلت للحد الأقصى ({plan.MaxStores} محل). الخطة الحالية: {plan.NameAr}",
                    "رقّي لإضافة محلات أكثر!",
                    Plans.Pro),

            _ => new(true, null, null, null)
        };
    }

    public async Task<ApiResponse> UpgradePlanAsync(
        Guid mallId, string targetPlan, CancellationToken ct = default)
    {
        var plan = Plans.All.FirstOrDefault(p => p.Key == targetPlan);
        if (plan == null) return ApiResponse.Fail("خطة غير موجودة.");

        _log.LogInformation("Mall {MallId} requested upgrade to {Plan}", mallId, targetPlan);
        // In production: create payment intent → on success → update subscription
        return ApiResponse.Ok($"تم طلب الترقية إلى خطة {plan.NameAr}. سيتم التواصل معك قريباً.");
    }

    public Task<ApiResponse<List<PlanDto>>> GetAvailablePlansAsync(CancellationToken ct = default)
    {
        var dtos = Plans.All.Select(p => new PlanDto
        {
            Key           = p.Key,
            NameAr        = p.NameAr,
            MonthlyPrice  = p.MonthlyPrice,
            YearlyPrice   = p.YearlyPrice,
            ProductsLabel = p.MaxProducts < 0 ? "غير محدود" : $"{p.MaxProducts} منتج",
            StoresLabel   = p.MaxStores   < 0 ? "غير محدود" : $"{p.MaxStores} محل",
            HasAnalytics  = p.HasAnalytics,
            HasAI         = p.HasAI,
            HasExport     = p.HasExport,
            CommissionRate= p.CommissionRate,
            IsPopular     = p.Key == Plans.Pro,
        }).ToList();

        return Task.FromResult(ApiResponse<List<PlanDto>>.Ok(dtos));
    }
}

// ─── Plan Limit Middleware ─────────────────────────────────────────────────
/// <summary>
/// Checks plan limits before write operations (adding products, stores, etc.)
/// </summary>
public class PlanLimitMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<PlanLimitMiddleware> _log;

    // Write endpoints that should check limits
    private static readonly Dictionary<string, LimitType> _limitChecks = new()
    {
        ["/api/store/products"] = LimitType.Products,    // POST only
    };

    public PlanLimitMiddleware(RequestDelegate next, ILogger<PlanLimitMiddleware> log)
    { _next = next; _log = log; }

    public async Task InvokeAsync(HttpContext ctx, ISubscriptionService subSvc)
    {
        // Only check on write operations
        if (ctx.Request.Method == "POST" || ctx.Request.Method == "PUT")
        {
            var mallId = ExtractMallId(ctx);
            if (mallId != Guid.Empty)
            {
                var path = ctx.Request.Path.Value?.ToLower() ?? "";
                foreach (var (pattern, limitType) in _limitChecks)
                {
                    if (path.Contains(pattern))
                    {
                        var check = await subSvc.CheckLimitAsync(mallId, limitType);
                        if (!check.IsAllowed)
                        {
                            _log.LogWarning("Limit exceeded: {Type} for mall {Mall}", limitType, mallId);
                            ctx.Response.StatusCode = 402; // Payment Required
                            ctx.Response.ContentType = "application/json";
                            await ctx.Response.WriteAsync(JsonSerializer.Serialize(new
                            {
                                success        = false,
                                error          = check.BlockReason,
                                upgradeMessage = check.UpgradeMessage,
                                suggestedPlan  = check.SuggestedPlan,
                                requireUpgrade = true,
                            }));
                            return;
                        }
                    }
                }
            }
        }

        await _next(ctx);
    }

    private static Guid ExtractMallId(HttpContext ctx)
    {
        var claim = ctx.User.FindFirst("mall_id")?.Value;
        return Guid.TryParse(claim, out var g) ? g : Guid.Empty;
    }
}

// ─── Subscription Controller ───────────────────────────────────────────────
namespace MesterX.API.Controllers.Phase13.Subscriptions
{
    using Microsoft.AspNetCore.Authorization;
    using Microsoft.AspNetCore.Mvc;
    using System.Security.Claims;

    [ApiController, Route("api/mall/subscription")]
    public class SubscriptionController : ControllerBase
    {
        private readonly ISubscriptionService _svc;
        private Guid MallId => Guid.TryParse(
            User.FindFirstValue("mall_id"), out var g) ? g : Guid.Empty;

        public SubscriptionController(ISubscriptionService svc) => _svc = svc;

        /// <summary>Get current plan status + usage + limits</summary>
        [Authorize, HttpGet("status")]
        public async Task<IActionResult> Status(CancellationToken ct) =>
            Ok(await _svc.GetPlanStatusAsync(MallId, ct));

        /// <summary>Get all available plans for upgrade comparison</summary>
        [HttpGet("plans")]
        public async Task<IActionResult> Plans(CancellationToken ct) =>
            Ok(await _svc.GetAvailablePlansAsync(ct));

        /// <summary>Request upgrade to a specific plan</summary>
        [Authorize(Roles = "PlatformOwner,CompanyOwner"), HttpPost("upgrade")]
        public async Task<IActionResult> Upgrade(
            [FromBody] UpgradePlanRequest req, CancellationToken ct)
        {
            var result = await _svc.UpgradePlanAsync(MallId, req.Plan, ct);
            return result.Success ? Ok(result) : BadRequest(result);
        }
    }

    public record UpgradePlanRequest(string Plan);
}
