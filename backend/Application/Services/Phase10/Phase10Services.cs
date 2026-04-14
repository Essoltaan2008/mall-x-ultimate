using MesterX.Application.DTOs;
using MesterX.Infrastructure.Caching;
using MesterX.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using System.ComponentModel.DataAnnotations;
using System.Text.Json;

namespace MesterX.Application.Services.Phase10;

// ══════════════════════════════════════════════════════════════════════════
//  DOMAIN ENTITIES
// ══════════════════════════════════════════════════════════════════════════
public enum NotifCategory
{
    Order, Delivery, Loyalty, Promo, Booking,
    Payment, Referral, System, Wallet
}

public class CustomerNotification
{
    [Key] public Guid   Id         { get; set; } = Guid.NewGuid();
    [Required] public Guid CustomerId { get; set; }
    [Required] public Guid MallId    { get; set; }
    public NotifCategory Category    { get; set; } = NotifCategory.System;
    [Required, MaxLength(200)] public string Title { get; set; } = string.Empty;
    [Required] public string Body    { get; set; } = string.Empty;
    public string? ImageUrl          { get; set; }
    public string? ActionType        { get; set; }
    public string? ActionId          { get; set; }
    public bool   IsRead             { get; set; } = false;
    public DateTime? ReadAt          { get; set; }
    public DateTime CreatedAt        { get; set; } = DateTime.UtcNow;
}

public class ProductReview
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    [Required] public Guid ProductId   { get; set; }
    [Required] public Guid StoreId     { get; set; }
    [Required] public Guid CustomerId  { get; set; }
    public Guid? MallOrderId           { get; set; }
    public short Stars                 { get; set; }
    public string? Title               { get; set; }
    public string? Body                { get; set; }
    public string[]? Images            { get; set; }
    public bool IsVerifiedPurchase     { get; set; } = false;
    public int HelpfulCount            { get; set; } = 0;
    public bool IsPublished            { get; set; } = true;
    public string? StoreReply          { get; set; }
    public DateTime? StoreRepliedAt    { get; set; }
    public DateTime CreatedAt          { get; set; } = DateTime.UtcNow;
}

public class ProductRatingSummary
{
    [Key] public Guid ProductId  { get; set; }
    public decimal AvgStars      { get; set; } = 0;
    public int TotalReviews      { get; set; } = 0;
    public int FiveStar          { get; set; } = 0;
    public int FourStar          { get; set; } = 0;
    public int ThreeStar         { get; set; } = 0;
    public int TwoStar           { get; set; } = 0;
    public int OneStar           { get; set; } = 0;
    public DateTime UpdatedAt    { get; set; } = DateTime.UtcNow;
}

public class SavedOrder
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    [Required] public Guid CustomerId  { get; set; }
    [Required] public Guid MallId      { get; set; }
    [Required, MaxLength(100)] public string Name { get; set; } = "طلبي المفضل";
    public string ItemsJson            { get; set; } = "[]";   // JSON array
    public decimal? TotalEst           { get; set; }
    public DateTime? LastOrdered       { get; set; }
    public int OrderCount              { get; set; } = 0;
    public bool IsActive               { get; set; } = true;
    public DateTime CreatedAt          { get; set; } = DateTime.UtcNow;
    public DateTime UpdatedAt          { get; set; } = DateTime.UtcNow;
}

public class CustomerActivity
{
    [Key] public Guid Id { get; set; } = Guid.NewGuid();
    [Required] public Guid CustomerId { get; set; }
    [Required] public Guid MallId     { get; set; }
    [MaxLength(50)] public string EventType { get; set; } = string.Empty;
    public string? EntityType         { get; set; }
    public Guid? EntityId             { get; set; }
    public string? MetadataJson       { get; set; }
    public DateTime CreatedAt         { get; set; } = DateTime.UtcNow;
}

// ══════════════════════════════════════════════════════════════════════════
//  NOTIFICATION SERVICE
// ══════════════════════════════════════════════════════════════════════════
public record NotifDto
{
    public Guid   Id          { get; init; }
    public string Category    { get; init; } = string.Empty;
    public string CategoryAr  { get; init; } = string.Empty;
    public string Title       { get; init; } = string.Empty;
    public string Body        { get; init; } = string.Empty;
    public string? ImageUrl   { get; init; }
    public string? ActionType { get; init; }
    public string? ActionId   { get; init; }
    public bool   IsRead      { get; init; }
    public string TimeAgo     { get; init; } = string.Empty;
    public DateTime CreatedAt { get; init; }
}

public record NotifListDto
{
    public int              UnreadCount { get; init; }
    public List<NotifDto>   Items       { get; init; } = [];
}

public record CreateNotifRequest(
    Guid        CustomerId,
    Guid        MallId,
    NotifCategory Category,
    string      Title,
    string      Body,
    string?     ImageUrl   = null,
    string?     ActionType = null,
    string?     ActionId   = null
);

public interface INotificationService
{
    Task<ApiResponse<NotifListDto>>  GetNotificationsAsync(Guid customerId, int page, int size, CancellationToken ct = default);
    Task<ApiResponse<int>>           GetUnreadCountAsync(Guid customerId, CancellationToken ct = default);
    Task<ApiResponse>                MarkReadAsync(Guid customerId, Guid notifId, CancellationToken ct = default);
    Task<ApiResponse>                MarkAllReadAsync(Guid customerId, CancellationToken ct = default);
    Task<ApiResponse>                CreateAsync(CreateNotifRequest req, CancellationToken ct = default);
    Task                             CreateBulkAsync(IEnumerable<CreateNotifRequest> reqs, CancellationToken ct = default);

    // Pre-built notification helpers
    Task NotifyOrderStatusAsync(Guid customerId, Guid mallId, string orderNum, string status, CancellationToken ct = default);
    Task NotifyLoyaltyTierUpAsync(Guid customerId, Guid mallId, string newTier, CancellationToken ct = default);
    Task NotifyWalletTopUpAsync(Guid customerId, Guid mallId, decimal amount, CancellationToken ct = default);
    Task NotifyFlashSaleAsync(Guid customerId, Guid mallId, string title, Guid saleId, CancellationToken ct = default);
}

public class NotificationService : INotificationService
{
    private readonly MesterXDbContext _db;
    private readonly ICacheService    _cache;
    private readonly ILogger<NotificationService> _log;

    public NotificationService(MesterXDbContext db, ICacheService cache,
        ILogger<NotificationService> log)
    { _db = db; _cache = cache; _log = log; }

    public async Task<ApiResponse<NotifListDto>> GetNotificationsAsync(
        Guid customerId, int page, int size, CancellationToken ct = default)
    {
        var notifs = await _db.Set<CustomerNotification>()
            .AsNoTracking()
            .Where(n => n.CustomerId == customerId)
            .OrderByDescending(n => n.CreatedAt)
            .Skip((page - 1) * size).Take(size)
            .ToListAsync(ct);

        var unread = await _db.Set<CustomerNotification>()
            .CountAsync(n => n.CustomerId == customerId && !n.IsRead, ct);

        return ApiResponse<NotifListDto>.Ok(new NotifListDto
        {
            UnreadCount = unread,
            Items       = notifs.Select(MapNotif).ToList(),
        });
    }

    public async Task<ApiResponse<int>> GetUnreadCountAsync(
        Guid customerId, CancellationToken ct = default)
    {
        var cacheKey = $"notif:unread:{customerId}";
        var cached   = await _cache.GetAsync<int?>(cacheKey, ct);
        if (cached.HasValue) return ApiResponse<int>.Ok(cached.Value);

        var count = await _db.Set<CustomerNotification>()
            .CountAsync(n => n.CustomerId == customerId && !n.IsRead, ct);
        await _cache.SetAsync(cacheKey, count, TimeSpan.FromMinutes(2), ct);
        return ApiResponse<int>.Ok(count);
    }

    public async Task<ApiResponse> MarkReadAsync(
        Guid customerId, Guid notifId, CancellationToken ct = default)
    {
        var notif = await _db.Set<CustomerNotification>()
            .FirstOrDefaultAsync(n => n.Id == notifId && n.CustomerId == customerId, ct);
        if (notif == null) return ApiResponse.Fail("الإشعار غير موجود.");

        notif.IsRead = true;
        notif.ReadAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        await _cache.DeleteAsync($"notif:unread:{customerId}");
        return ApiResponse.Ok();
    }

    public async Task<ApiResponse> MarkAllReadAsync(
        Guid customerId, CancellationToken ct = default)
    {
        await _db.Set<CustomerNotification>()
            .Where(n => n.CustomerId == customerId && !n.IsRead)
            .ExecuteUpdateAsync(s => s
                .SetProperty(n => n.IsRead, true)
                .SetProperty(n => n.ReadAt, DateTime.UtcNow), ct);
        await _cache.DeleteAsync($"notif:unread:{customerId}");
        return ApiResponse.Ok();
    }

    public async Task<ApiResponse> CreateAsync(CreateNotifRequest req, CancellationToken ct = default)
    {
        _db.Set<CustomerNotification>().Add(new CustomerNotification
        {
            CustomerId = req.CustomerId, MallId = req.MallId,
            Category   = req.Category,  Title  = req.Title,
            Body       = req.Body,       ImageUrl  = req.ImageUrl,
            ActionType = req.ActionType, ActionId  = req.ActionId,
        });
        await _db.SaveChangesAsync(ct);
        await _cache.DeleteAsync($"notif:unread:{req.CustomerId}");
        return ApiResponse.Ok();
    }

    public async Task CreateBulkAsync(
        IEnumerable<CreateNotifRequest> reqs, CancellationToken ct = default)
    {
        var list = reqs.Select(req => new CustomerNotification
        {
            CustomerId = req.CustomerId, MallId = req.MallId,
            Category   = req.Category,  Title  = req.Title,
            Body       = req.Body,       ImageUrl  = req.ImageUrl,
            ActionType = req.ActionType, ActionId  = req.ActionId,
        }).ToList();

        await _db.Set<CustomerNotification>().AddRangeAsync(list, ct);
        await _db.SaveChangesAsync(ct);

        // Invalidate cache for all customers
        foreach (var id in list.Select(n => n.CustomerId).Distinct())
            await _cache.DeleteAsync($"notif:unread:{id}");
    }

    // ─── Helpers ──────────────────────────────────────────────────────────
    public async Task NotifyOrderStatusAsync(Guid customerId, Guid mallId,
        string orderNum, string status, CancellationToken ct = default)
    {
        var (title, body, icon) = status switch
        {
            "Confirmed"  => ("✅ تم تأكيد طلبك", $"طلبك #{orderNum} تم تأكيده من المحل", "order"),
            "Preparing"  => ("👨‍🍳 طلبك قيد التحضير", $"جاري تحضير طلبك #{orderNum} الآن", "order"),
            "Ready"      => ("🎉 طلبك جاهز!", $"طلبك #{orderNum} جاهز للاستلام أو التوصيل", "order"),
            "PickedUp"   => ("🚗 السائق في الطريق", $"السائق استلم طلبك #{orderNum}", "delivery"),
            "Delivered"  => ("✅ تم التسليم!", $"وصل طلبك #{orderNum} بنجاح. شكراً لك! ❤️", "order"),
            "Cancelled"  => ("❌ تم إلغاء الطلب", $"تم إلغاء طلبك #{orderNum}", "order"),
            _ => ("🔔 تحديث الطلب", $"حالة طلبك #{orderNum} تغيرت", "order")
        };
        var category = icon == "delivery" ? NotifCategory.Delivery : NotifCategory.Order;
        await CreateAsync(new(customerId, mallId, category, title, body, null, "OpenOrder", orderNum), ct);
    }

    public async Task NotifyLoyaltyTierUpAsync(Guid customerId, Guid mallId,
        string newTier, CancellationToken ct = default)
    {
        var (emoji, benefit) = newTier switch
        {
            "Silver" => ("🥈", "تمتع بـ 1.5x نقاط على كل مشترياتك!"),
            "Gold"   => ("🥇", "تمتع بـ 2x نقاط + توصيل مجاني على كل الطلبات!"),
            _ => ("🏅", "تمتع بمزايا مستواك الجديد!")
        };
        await CreateAsync(new(customerId, mallId, NotifCategory.Loyalty,
            $"{emoji} ترقية! أصبحت في مستوى {newTier}",
            $"تهانينا! وصلت لمستوى {newTier}. {benefit}",
            null, "OpenWallet", null), ct);
    }

    public async Task NotifyWalletTopUpAsync(Guid customerId, Guid mallId,
        decimal amount, CancellationToken ct = default)
        => await CreateAsync(new(customerId, mallId, NotifCategory.Wallet,
            "💰 تم شحن محفظتك",
            $"تم إضافة {amount:N0} ج.م لمحفظتك بنجاح.",
            null, "OpenWallet", null), ct);

    public async Task NotifyFlashSaleAsync(Guid customerId, Guid mallId,
        string title, Guid saleId, CancellationToken ct = default)
        => await CreateAsync(new(customerId, mallId, NotifCategory.Promo,
            $"⚡ فلاش سيل: {title}",
            "عرض محدود! لا تفوّت الفرصة — الكمية محدودة 🔥",
            null, "OpenPromo", saleId.ToString()), ct);

    // ─── Mapper ──────────────────────────────────────────────────────────
    private static NotifDto MapNotif(CustomerNotification n) => new()
    {
        Id         = n.Id,        Title  = n.Title,      Body = n.Body,
        Category   = n.Category.ToString(),
        CategoryAr = CategoryAr(n.Category),
        ImageUrl   = n.ImageUrl, ActionType = n.ActionType, ActionId  = n.ActionId,
        IsRead     = n.IsRead,   TimeAgo    = TimeAgo(n.CreatedAt),
        CreatedAt  = n.CreatedAt,
    };

    private static string CategoryAr(NotifCategory c) => c switch
    {
        NotifCategory.Order    => "الطلبات",
        NotifCategory.Delivery => "التوصيل",
        NotifCategory.Loyalty  => "نقاط الولاء",
        NotifCategory.Promo    => "العروض",
        NotifCategory.Booking  => "الحجوزات",
        NotifCategory.Payment  => "الدفع",
        NotifCategory.Referral => "الإحالات",
        NotifCategory.Wallet   => "المحفظة",
        _                      => "إشعار",
    };

    private static string TimeAgo(DateTime dt)
    {
        var diff = DateTime.UtcNow - dt;
        if (diff.TotalMinutes < 1)  return "الآن";
        if (diff.TotalMinutes < 60) return $"منذ {(int)diff.TotalMinutes} دقيقة";
        if (diff.TotalHours   < 24) return $"منذ {(int)diff.TotalHours} ساعة";
        if (diff.TotalDays    < 7)  return $"منذ {(int)diff.TotalDays} يوم";
        return dt.ToString("dd/MM/yyyy");
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  PRODUCT REVIEW SERVICE
// ══════════════════════════════════════════════════════════════════════════
public record SubmitProductReviewRequest(
    Guid   ProductId,
    Guid   StoreId,
    Guid?  MallOrderId,
    short  Stars,
    string? Title,
    string? Body,
    string[]? Images
);

public record ProductReviewDto
{
    public Guid    Id              { get; init; }
    public string  AuthorName      { get; init; } = string.Empty;
    public short   Stars           { get; init; }
    public string? Title           { get; init; }
    public string? Body            { get; init; }
    public string[]? Images        { get; init; }
    public bool    IsVerified      { get; init; }
    public int     HelpfulCount    { get; init; }
    public string? StoreReply      { get; init; }
    public string  TimeAgo         { get; init; } = string.Empty;
    public DateTime CreatedAt      { get; init; }
}

public record ProductReviewsDto
{
    public Guid   ProductId        { get; init; }
    public decimal AvgStars        { get; init; }
    public int    TotalReviews     { get; init; }
    public Dictionary<int, int> Breakdown { get; init; } = new();
    public List<ProductReviewDto> Reviews { get; init; } = [];
}

public interface IProductReviewService
{
    Task<ApiResponse<ProductReviewDto>>  SubmitAsync(Guid customerId, SubmitProductReviewRequest req, CancellationToken ct = default);
    Task<ApiResponse<ProductReviewsDto>> GetReviewsAsync(Guid productId, int page, int size, CancellationToken ct = default);
    Task<ApiResponse>                    MarkHelpfulAsync(Guid customerId, Guid reviewId, CancellationToken ct = default);
    Task<ApiResponse>                    ReplyAsync(Guid storeId, Guid reviewId, string reply, CancellationToken ct = default);
}

public class ProductReviewService : IProductReviewService
{
    private readonly MesterXDbContext _db;
    private readonly ICacheService    _cache;
    private readonly ILogger<ProductReviewService> _log;

    public ProductReviewService(MesterXDbContext db, ICacheService cache,
        ILogger<ProductReviewService> log)
    { _db = db; _cache = cache; _log = log; }

    public async Task<ApiResponse<ProductReviewDto>> SubmitAsync(
        Guid customerId, SubmitProductReviewRequest req, CancellationToken ct = default)
    {
        if (req.Stars is < 1 or > 5)
            return ApiResponse<ProductReviewDto>.Fail("التقييم بين 1 و 5 نجوم فقط.");

        // Verify purchased if order provided
        bool isVerified = false;
        if (req.MallOrderId.HasValue)
        {
            isVerified = await _db.StoreOrders.AsNoTracking()
                .AnyAsync(so => so.MallOrder.Id == req.MallOrderId
                    && so.MallOrder.CustomerId == customerId
                    && so.MallOrder.Status == MallOrderStatus.Delivered
                    && so.Items.Any(i => i.ProductId == req.ProductId), ct);
        }

        // Duplicate check
        var dup = await _db.Set<ProductReview>().AnyAsync(
            r => r.ProductId == req.ProductId && r.CustomerId == customerId
                 && r.MallOrderId == req.MallOrderId, ct);
        if (dup) return ApiResponse<ProductReviewDto>.Fail("لقد قيّمت هذا المنتج مسبقاً.");

        var customer = await _db.MallCustomers.FindAsync([customerId], ct);
        var review   = new ProductReview
        {
            ProductId         = req.ProductId, StoreId = req.StoreId,
            CustomerId        = customerId,     MallOrderId = req.MallOrderId,
            Stars             = req.Stars,      Title = req.Title?.Trim(),
            Body              = req.Body?.Trim(), Images = req.Images,
            IsVerifiedPurchase= isVerified,
        };
        _db.Set<ProductReview>().Add(review);
        await _db.SaveChangesAsync(ct);
        await _cache.DeleteAsync($"product:reviews:{req.ProductId}");

        _log.LogInformation("Product review: {Stars}⭐ for product {Id}", req.Stars, req.ProductId);
        return ApiResponse<ProductReviewDto>.Ok(MapReview(review, customer?.FullName ?? "عميل"));
    }

    public async Task<ApiResponse<ProductReviewsDto>> GetReviewsAsync(
        Guid productId, int page, int size, CancellationToken ct = default)
    {
        var cacheKey = $"product:reviews:{productId}:{page}";
        return await _cache.GetOrSetAsync(cacheKey, async () =>
        {
            var summary = await _db.Set<ProductRatingSummary>()
                .AsNoTracking()
                .FirstOrDefaultAsync(s => s.ProductId == productId, ct);

            var reviews = await _db.Set<ProductReview>()
                .AsNoTracking()
                .Where(r => r.ProductId == productId && r.IsPublished)
                .OrderByDescending(r => r.IsVerifiedPurchase)
                .ThenByDescending(r => r.HelpfulCount)
                .ThenByDescending(r => r.CreatedAt)
                .Skip((page - 1) * size).Take(size)
                .ToListAsync(ct);

            var customerIds = reviews.Select(r => r.CustomerId).Distinct().ToList();
            var names = await _db.MallCustomers.AsNoTracking()
                .Where(c => customerIds.Contains(c.Id))
                .ToDictionaryAsync(c => c.Id, c => c.FullName, ct);

            return ApiResponse<ProductReviewsDto>.Ok(new ProductReviewsDto
            {
                ProductId    = productId,
                AvgStars     = summary?.AvgStars ?? 0,
                TotalReviews = summary?.TotalReviews ?? 0,
                Breakdown    = new Dictionary<int, int>
                {
                    { 5, summary?.FiveStar  ?? 0 }, { 4, summary?.FourStar  ?? 0 },
                    { 3, summary?.ThreeStar ?? 0 }, { 2, summary?.TwoStar   ?? 0 },
                    { 1, summary?.OneStar   ?? 0 },
                },
                Reviews = reviews.Select(r =>
                    MapReview(r, names.GetValueOrDefault(r.CustomerId) ?? "عميل")).ToList(),
            });
        }, TimeSpan.FromMinutes(5), ct);
    }

    public async Task<ApiResponse> MarkHelpfulAsync(
        Guid customerId, Guid reviewId, CancellationToken ct = default)
    {
        var review = await _db.Set<ProductReview>().FindAsync([reviewId], ct);
        if (review == null) return ApiResponse.Fail("التقييم غير موجود.");
        review.HelpfulCount++;
        await _db.SaveChangesAsync(ct);
        await _cache.DeleteAsync($"product:reviews:{review.ProductId}");
        return ApiResponse.Ok();
    }

    public async Task<ApiResponse> ReplyAsync(
        Guid storeId, Guid reviewId, string reply, CancellationToken ct = default)
    {
        var review = await _db.Set<ProductReview>()
            .FirstOrDefaultAsync(r => r.Id == reviewId && r.StoreId == storeId, ct);
        if (review == null) return ApiResponse.Fail("التقييم غير موجود.");
        review.StoreReply     = reply.Trim();
        review.StoreRepliedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        await _cache.DeleteAsync($"product:reviews:{review.ProductId}");
        return ApiResponse.Ok();
    }

    private static ProductReviewDto MapReview(ProductReview r, string authorName) => new()
    {
        Id          = r.Id,          Stars     = r.Stars,
        AuthorName  = authorName,    Title     = r.Title,
        Body        = r.Body,        Images    = r.Images,
        IsVerified  = r.IsVerifiedPurchase,
        HelpfulCount= r.HelpfulCount, StoreReply = r.StoreReply,
        TimeAgo     = TimeAgo(r.CreatedAt),
        CreatedAt   = r.CreatedAt,
    };

    private static string TimeAgo(DateTime dt)
    {
        var diff = DateTime.UtcNow - dt;
        if (diff.TotalDays < 1)  return "اليوم";
        if (diff.TotalDays < 7)  return $"منذ {(int)diff.TotalDays} أيام";
        if (diff.TotalDays < 30) return $"منذ {(int)(diff.TotalDays / 7)} أسابيع";
        return dt.ToString("MM/yyyy");
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  REORDER SERVICE
// ══════════════════════════════════════════════════════════════════════════
public record SavedOrderDto
{
    public Guid    Id           { get; init; }
    public string  Name         { get; init; } = string.Empty;
    public int     ItemCount    { get; init; }
    public decimal TotalEst     { get; init; }
    public int     OrderCount   { get; init; }
    public string? LastOrdered  { get; init; }
    public List<SavedOrderItemDto> Items { get; init; } = [];
}

public record SavedOrderItemDto
{
    public Guid   StoreId     { get; init; }
    public string StoreName   { get; init; } = string.Empty;
    public Guid   ProductId   { get; init; }
    public string ProductName { get; init; } = string.Empty;
    public int    Quantity    { get; init; }
    public decimal Price      { get; init; }
    public bool   Available   { get; init; }
}

public record SaveOrderRequest(string Name, Guid MallOrderId);

public interface IReorderService
{
    Task<ApiResponse<List<SavedOrderDto>>> GetSavedOrdersAsync(Guid customerId, CancellationToken ct = default);
    Task<ApiResponse<SavedOrderDto>>       SaveOrderAsync(Guid customerId, SaveOrderRequest req, CancellationToken ct = default);
    Task<ApiResponse>                      ReorderAsync(Guid customerId, Guid savedOrderId, CancellationToken ct = default);
    Task<ApiResponse>                      DeleteSavedOrderAsync(Guid customerId, Guid savedOrderId, CancellationToken ct = default);
}

public class ReorderService : IReorderService
{
    private readonly MesterXDbContext _db;
    private readonly ILogger<ReorderService> _log;

    public ReorderService(MesterXDbContext db, ILogger<ReorderService> log)
    { _db = db; _log = log; }

    public async Task<ApiResponse<List<SavedOrderDto>>> GetSavedOrdersAsync(
        Guid customerId, CancellationToken ct = default)
    {
        var saved = await _db.Set<SavedOrder>()
            .AsNoTracking()
            .Where(s => s.CustomerId == customerId && s.IsActive)
            .OrderByDescending(s => s.OrderCount)
            .ToListAsync(ct);

        var dtos = new List<SavedOrderDto>();
        foreach (var s in saved)
            dtos.Add(await MapSavedAsync(s, ct));
        return ApiResponse<List<SavedOrderDto>>.Ok(dtos);
    }

    public async Task<ApiResponse<SavedOrderDto>> SaveOrderAsync(
        Guid customerId, SaveOrderRequest req, CancellationToken ct = default)
    {
        // Load order
        var order = await _db.MallOrders.AsNoTracking()
            .Include(o => o.StoreOrders).ThenInclude(so => so.Items)
            .FirstOrDefaultAsync(o => o.Id == req.MallOrderId
                && o.CustomerId == customerId, ct);
        if (order == null) return ApiResponse<SavedOrderDto>.Fail("الطلب غير موجود.");

        var items = order.StoreOrders.SelectMany(so => so.Items.Select(i => new
        {
            storeId     = so.StoreId,
            productId   = i.ProductId,
            quantity    = i.Quantity,
            price       = i.UnitPrice,
        })).ToList();

        var saved = new SavedOrder
        {
            CustomerId = customerId,
            MallId     = order.MallId,
            Name       = req.Name,
            ItemsJson  = JsonSerializer.Serialize(items),
            TotalEst   = order.Subtotal,
        };
        _db.Set<SavedOrder>().Add(saved);
        await _db.SaveChangesAsync(ct);

        _log.LogInformation("Order saved as template: {Name} for customer {Id}", req.Name, customerId);
        return ApiResponse<SavedOrderDto>.Ok(await MapSavedAsync(saved, ct));
    }

    public async Task<ApiResponse> ReorderAsync(
        Guid customerId, Guid savedOrderId, CancellationToken ct = default)
    {
        var saved = await _db.Set<SavedOrder>()
            .FirstOrDefaultAsync(s => s.Id == savedOrderId && s.CustomerId == customerId, ct);
        if (saved == null) return ApiResponse.Fail("الطلب المحفوظ غير موجود.");

        var items = JsonSerializer.Deserialize<List<JsonElement>>(saved.ItemsJson) ?? [];

        // Add all items to cart
        foreach (var item in items)
        {
            var productId = Guid.Parse(item.GetProperty("productId").GetString()!);
            var storeId   = Guid.Parse(item.GetProperty("storeId").GetString()!);
            var qty       = item.GetProperty("quantity").GetInt32();

            // Check availability first
            var inStock = await _db.Products.AsNoTracking()
                .Include(p => p.StockItems)
                .AnyAsync(p => p.Id == productId && p.IsActive && !p.IsDeleted
                    && p.StockItems.Any(s => s.AvailableQuantity >= qty), ct);
            if (!inStock) continue;

            // Reuse cart logic (simplified: add directly)
            var cart = await _db.Carts.FirstOrDefaultAsync(
                c => c.CustomerId == customerId, ct);
            if (cart == null)
            {
                cart = new Cart { CustomerId = customerId, MallId = saved.MallId };
                _db.Carts.Add(cart);
                await _db.SaveChangesAsync(ct);
            }

            var existing = await _db.CartItems
                .FirstOrDefaultAsync(ci => ci.CartId == cart.Id && ci.ProductId == productId, ct);
            if (existing != null)
                existing.Quantity += qty;
            else
                _db.CartItems.Add(new CartItem
                {
                    CartId = cart.Id, StoreId = storeId,
                    ProductId = productId, Quantity = qty,
                });
        }

        saved.OrderCount++;
        saved.LastOrdered = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        _log.LogInformation("Reorder: saved order {Id} for customer {CustomerId}", savedOrderId, customerId);
        return ApiResponse.Ok("تم إضافة العناصر للسلة! تحقق منها قبل الدفع.");
    }

    public async Task<ApiResponse> DeleteSavedOrderAsync(
        Guid customerId, Guid savedOrderId, CancellationToken ct = default)
    {
        var saved = await _db.Set<SavedOrder>()
            .FirstOrDefaultAsync(s => s.Id == savedOrderId && s.CustomerId == customerId, ct);
        if (saved == null) return ApiResponse.Fail("غير موجود.");
        saved.IsActive  = false;
        saved.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);
        return ApiResponse.Ok();
    }

    private async Task<SavedOrderDto> MapSavedAsync(SavedOrder s, CancellationToken ct)
    {
        var rawItems = JsonSerializer.Deserialize<List<JsonElement>>(s.ItemsJson) ?? [];
        var dtoItems = new List<SavedOrderItemDto>();

        foreach (var item in rawItems)
        {
            var productId = Guid.Parse(item.GetProperty("productId").GetString()!);
            var storeId   = Guid.Parse(item.GetProperty("storeId").GetString()!);
            var qty       = item.GetProperty("quantity").GetInt32();
            var price     = item.GetProperty("price").GetDecimal();

            var product = await _db.Products.AsNoTracking()
                .Include(p => p.StockItems)
                .FirstOrDefaultAsync(p => p.Id == productId, ct);
            var store = await _db.Tenants.AsNoTracking()
                .Select(t => new { t.Id, t.Name })
                .FirstOrDefaultAsync(t => t.Id == storeId, ct);

            dtoItems.Add(new SavedOrderItemDto
            {
                StoreId     = storeId,
                StoreName   = store?.Name ?? string.Empty,
                ProductId   = productId,
                ProductName = product?.Name ?? string.Empty,
                Quantity    = qty,
                Price       = price,
                Available   = product?.IsActive == true && !product.IsDeleted
                    && product.StockItems.Any(si => si.AvailableQuantity >= qty),
            });
        }

        return new SavedOrderDto
        {
            Id          = s.Id,
            Name        = s.Name,
            ItemCount   = dtoItems.Count,
            TotalEst    = s.TotalEst ?? dtoItems.Sum(i => i.Price * i.Quantity),
            OrderCount  = s.OrderCount,
            LastOrdered = s.LastOrdered?.ToString("dd/MM/yyyy"),
            Items       = dtoItems,
        };
    }
}
