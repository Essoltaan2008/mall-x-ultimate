using System.Net;
using System.Text.Json;
using MesterX.Application.DTOs;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;

namespace MesterX.API.Middleware;

// ══════════════════════════════════════════════════════════════════════════
//  GLOBAL EXCEPTION MIDDLEWARE
//  Catches all unhandled exceptions and returns a consistent JSON response
// ══════════════════════════════════════════════════════════════════════════
public class GlobalExceptionMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<GlobalExceptionMiddleware> _log;

    public GlobalExceptionMiddleware(RequestDelegate next,
        ILogger<GlobalExceptionMiddleware> log)
    { _next = next; _log = log; }

    public async Task InvokeAsync(HttpContext ctx)
    {
        try
        {
            await _next(ctx);
        }
        catch (OperationCanceledException) when (ctx.RequestAborted.IsCancellationRequested)
        {
            // Client disconnected — not an error
            ctx.Response.StatusCode = 499;
        }
        catch (UnauthorizedAccessException ex)
        {
            _log.LogWarning(ex, "Unauthorized access: {Path}", ctx.Request.Path);
            await WriteError(ctx, HttpStatusCode.Unauthorized, "غير مصرح. يرجى تسجيل الدخول.");
        }
        catch (ArgumentException ex)
        {
            _log.LogWarning(ex, "Argument error: {Path}", ctx.Request.Path);
            await WriteError(ctx, HttpStatusCode.BadRequest, ex.Message);
        }
        catch (InvalidOperationException ex)
        {
            _log.LogWarning(ex, "Invalid operation: {Path}", ctx.Request.Path);
            await WriteError(ctx, HttpStatusCode.BadRequest, ex.Message);
        }
        catch (Exception ex)
        {
            _log.LogError(ex, "Unhandled exception: {Path} — {Message}",
                ctx.Request.Path, ex.Message);
            await WriteError(ctx, HttpStatusCode.InternalServerError,
                "حدث خطأ غير متوقع. الفريق التقني تم إخطاره.");
        }
    }

    private static async Task WriteError(HttpContext ctx, HttpStatusCode code, string message)
    {
        ctx.Response.StatusCode  = (int)code;
        ctx.Response.ContentType = "application/json";
        var response = ApiResponse.Fail(message);
        await ctx.Response.WriteAsync(JsonSerializer.Serialize(response,
            new JsonSerializerOptions { PropertyNamingPolicy = JsonNamingPolicy.CamelCase }));
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  TENANT MIDDLEWARE
//  Enriches requests with mall_id claim from tenant context
// ══════════════════════════════════════════════════════════════════════════
public class TenantMiddleware
{
    private readonly RequestDelegate _next;

    public TenantMiddleware(RequestDelegate next) => _next = next;

    public async Task InvokeAsync(HttpContext ctx)
    {
        // Tenant context already resolved by JWT claims
        // This middleware can be extended for subdomain-based multi-tenancy
        await _next(ctx);
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  FINAL PROGRAM.CS ADDITIONS — Register all Phase 9-12 services
//  Add these lines to the "Application Services" section of Program.cs
// ══════════════════════════════════════════════════════════════════════════
/*
// Phase 9 — Wallet, Referral, WhatsApp, SuperAdmin
builder.Services.AddScoped<IWalletService,        WalletService>();
builder.Services.AddScoped<IReferralService,       ReferralService>();
builder.Services.AddScoped<IWhatsappService,       WhatsappService>();
builder.Services.AddScoped<ISuperAdminService,     SuperAdminService>();

// Phase 10 — Notifications, Reviews, Reorder
builder.Services.AddScoped<INotificationService,   NotificationService>();
builder.Services.AddScoped<IProductReviewService,  ProductReviewService>();
builder.Services.AddScoped<IReorderService,        ReorderService>();

// Phase 11 — Export
builder.Services.AddScoped<IExportService,         ExportService>();

// Phase 12 — Orchestration, Alerts, Settlements
builder.Services.AddScoped<IOrderOrchestrationService,     OrderOrchestrationService>();
builder.Services.AddScoped<IInventoryAlertService,         InventoryAlertService>();
builder.Services.AddScoped<ICommissionSettlementService,   CommissionSettlementService>();

// Middleware (add before app.UseAuthentication())
app.UseMiddleware<GlobalExceptionMiddleware>();
app.UseMiddleware<RequestLoggingMiddleware>();
app.UseMiddleware<TenantMiddleware>();

// HTTP clients
builder.Services.AddHttpClient("Anthropic", c => {
    c.Timeout = TimeSpan.FromSeconds(60); // streaming needs longer timeout
});
builder.Services.AddHttpClient("Twilio", c => {
    c.Timeout = TimeSpan.FromSeconds(30);
});
*/
