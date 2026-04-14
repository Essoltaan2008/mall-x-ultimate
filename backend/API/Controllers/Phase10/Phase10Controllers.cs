using System.Diagnostics;
using System.Security.Claims;
using MesterX.Application.DTOs;
using MesterX.Application.Services.Phase10;
using MesterX.Infrastructure.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;

// ══════════════════════════════════════════════════════════════════════════
//  REQUEST LOGGING MIDDLEWARE
// ══════════════════════════════════════════════════════════════════════════
namespace MesterX.API.Middleware;

public class RequestLoggingMiddleware
{
    private readonly RequestDelegate _next;
    private readonly IServiceScopeFactory _scope;
    private readonly ILogger<RequestLoggingMiddleware> _log;

    // Skip these endpoints (high frequency / no value logging)
    private static readonly HashSet<string> _skip = new(StringComparer.OrdinalIgnoreCase)
    {
        "/health", "/hubs/orders", "/hubs/drivers", "/favicon.ico", "/swagger"
    };

    public RequestLoggingMiddleware(RequestDelegate next, IServiceScopeFactory scope,
        ILogger<RequestLoggingMiddleware> log)
    { _next = next; _scope = scope; _log = log; }

    public async Task InvokeAsync(HttpContext ctx)
    {
        var path = ctx.Request.Path.Value ?? "";
        if (_skip.Any(s => path.StartsWith(s, StringComparison.OrdinalIgnoreCase)))
        {
            await _next(ctx);
            return;
        }

        var sw = Stopwatch.StartNew();
        await _next(ctx);
        sw.Stop();

        // Async log — don't block response
        _ = Task.Run(async () =>
        {
            try
            {
                using var svc = _scope.CreateScope();
                var db = svc.ServiceProvider.GetRequiredService<MesterXDbContext>();

                Guid? customerId = null;
                if (Guid.TryParse(ctx.User.FindFirstValue(ClaimTypes.NameIdentifier), out var cid))
                    customerId = cid;

                db.Set<ApiRequestLog>().Add(new ApiRequestLog
                {
                    Endpoint   = path,
                    Method     = ctx.Request.Method,
                    StatusCode = ctx.Response.StatusCode,
                    DurationMs = (int)sw.ElapsedMilliseconds,
                    CustomerId = customerId,
                    IpAddress  = ctx.Connection.RemoteIpAddress?.ToString(),
                    UserAgent  = ctx.Request.Headers.UserAgent.ToString().Truncate(250),
                    ErrorMsg   = ctx.Response.StatusCode >= 400 ? "Error response" : null,
                });
                await db.SaveChangesAsync();
            }
            catch { /* non-critical */ }
        });
    }
}

public class ApiRequestLog
{
    public Guid    Id         { get; set; } = Guid.NewGuid();
    public string? Endpoint   { get; set; }
    public string? Method     { get; set; }
    public int     StatusCode { get; set; }
    public int     DurationMs { get; set; }
    public Guid?   CustomerId { get; set; }
    public string? IpAddress  { get; set; }
    public string? UserAgent  { get; set; }
    public string? ErrorMsg   { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}

public static class StringExtensions
{
    public static string Truncate(this string s, int max)
        => s.Length <= max ? s : s[..max];
}

// ══════════════════════════════════════════════════════════════════════════
//  PHASE 10 CONTROLLERS
// ══════════════════════════════════════════════════════════════════════════
namespace MesterX.API.Controllers.Phase10;

[ApiController, Produces("application/json")]
public abstract class Phase10Base : ControllerBase
{
    protected Guid CustomerId => Guid.TryParse(
        User.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : Guid.Empty;
    protected Guid MallId => Guid.TryParse(
        User.FindFirstValue("mall_id"), out var id) ? id : Guid.Empty;
    protected Guid TenantId => Guid.TryParse(
        User.FindFirstValue("tenant_id"), out var id) ? id : Guid.Empty;
}

// ─── NOTIFICATIONS ────────────────────────────────────────────────────────
[Authorize, Route("api/mall/notifications")]
public class NotificationController : Phase10Base
{
    private readonly INotificationService _notifs;
    public NotificationController(INotificationService notifs) => _notifs = notifs;

    /// <summary>مركز الإشعارات — كل الإشعارات</summary>
    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] int page = 1, [FromQuery] int size = 20,
        CancellationToken ct = default)
        => Ok(await _notifs.GetNotificationsAsync(CustomerId, page, size, ct));

    /// <summary>عدد الإشعارات غير المقروءة</summary>
    [HttpGet("unread-count")]
    public async Task<IActionResult> UnreadCount(CancellationToken ct)
        => Ok(await _notifs.GetUnreadCountAsync(CustomerId, ct));

    /// <summary>تعليم إشعار كمقروء</summary>
    [HttpPatch("{notifId:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid notifId, CancellationToken ct)
        => Ok(await _notifs.MarkReadAsync(CustomerId, notifId, ct));

    /// <summary>تعليم كل الإشعارات كمقروءة</summary>
    [HttpPost("mark-all-read")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
        => Ok(await _notifs.MarkAllReadAsync(CustomerId, ct));
}

// ─── PRODUCT REVIEWS ──────────────────────────────────────────────────────
[Route("api/mall/products")]
public class ProductReviewController : Phase10Base
{
    private readonly IProductReviewService _reviews;
    public ProductReviewController(IProductReviewService reviews) => _reviews = reviews;

    /// <summary>تقييمات المنتج</summary>
    [HttpGet("{productId:guid}/reviews")]
    public async Task<IActionResult> GetReviews(
        Guid productId,
        [FromQuery] int page = 1, [FromQuery] int size = 10,
        CancellationToken ct = default)
        => Ok(await _reviews.GetReviewsAsync(productId, page, size, ct));

    /// <summary>إرسال تقييم منتج</summary>
    [Authorize, HttpPost("{productId:guid}/reviews")]
    public async Task<IActionResult> Submit(
        Guid productId, [FromBody] SubmitProductReviewRequest req,
        CancellationToken ct)
    {
        var result = await _reviews.SubmitAsync(CustomerId, req with { ProductId = productId }, ct);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    /// <summary>الضغط على "مفيد" لتقييم</summary>
    [Authorize, HttpPost("{productId:guid}/reviews/{reviewId:guid}/helpful")]
    public async Task<IActionResult> MarkHelpful(
        Guid productId, Guid reviewId, CancellationToken ct)
        => Ok(await _reviews.MarkHelpfulAsync(CustomerId, reviewId, ct));

    /// <summary>رد المحل على تقييم</summary>
    [Authorize, HttpPost("{productId:guid}/reviews/{reviewId:guid}/reply")]
    public async Task<IActionResult> Reply(
        Guid productId, Guid reviewId,
        [FromBody] StoreReplyRequest req, CancellationToken ct)
        => Ok(await _reviews.ReplyAsync(TenantId, reviewId, req.Reply, ct));
}

public record StoreReplyRequest(string Reply);

// ─── SAVED ORDERS / REORDER ───────────────────────────────────────────────
[Authorize, Route("api/mall/saved-orders")]
public class SavedOrderController : Phase10Base
{
    private readonly IReorderService _reorder;
    public SavedOrderController(IReorderService reorder) => _reorder = reorder;

    [HttpGet]
    public async Task<IActionResult> List(CancellationToken ct)
        => Ok(await _reorder.GetSavedOrdersAsync(CustomerId, ct));

    [HttpPost]
    public async Task<IActionResult> Save(
        [FromBody] SaveOrderRequest req, CancellationToken ct)
    {
        var result = await _reorder.SaveOrderAsync(CustomerId, req, ct);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    [HttpPost("{savedOrderId:guid}/reorder")]
    public async Task<IActionResult> Reorder(Guid savedOrderId, CancellationToken ct)
    {
        var result = await _reorder.ReorderAsync(CustomerId, savedOrderId, ct);
        return result.Success ? Ok(result) : BadRequest(result);
    }

    [HttpDelete("{savedOrderId:guid}")]
    public async Task<IActionResult> Delete(Guid savedOrderId, CancellationToken ct)
        => Ok(await _reorder.DeleteSavedOrderAsync(CustomerId, savedOrderId, ct));
}
