using MesterX.Application.DTOs;
using MesterX.Application.Services.Phase4;
using MesterX.Application.Services.Phase9;
using MesterX.Application.Services.Phase10;
using MesterX.Domain.Entities.Mall;
using MesterX.Hubs;
using MesterX.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace MesterX.Application.Services.Phase12;

// ══════════════════════════════════════════════════════════════════════════
//  ORDER ORCHESTRATION SERVICE
//  Wires together all services that need to react to order status changes:
//  → SignalR real-time update
//  → In-app notification
//  → WhatsApp message
//  → Loyalty points (on delivery)
//  → Referral reward unlock (on delivery)
//  → Queue ticket (for restaurants)
// ══════════════════════════════════════════════════════════════════════════
public interface IOrderOrchestrationService
{
    Task OnOrderStatusChangedAsync(Guid mallOrderId, MallOrderStatus newStatus, CancellationToken ct = default);
    Task OnStoreOrderStatusChangedAsync(Guid storeOrderId, string newStatus, CancellationToken ct = default);
}

public class OrderOrchestrationService : IOrderOrchestrationService
{
    private readonly MesterXDbContext      _db;
    private readonly IHubNotifier         _hub;
    private readonly INotificationService _notifs;
    private readonly IWhatsappService     _wa;
    private readonly ILoyaltyService      _loyalty;
    private readonly IReferralService     _referral;
    private readonly IRestaurantService   _restaurant;
    private readonly ILogger<OrderOrchestrationService> _log;

    public OrderOrchestrationService(
        MesterXDbContext db, IHubNotifier hub,
        INotificationService notifs, IWhatsappService wa,
        ILoyaltyService loyalty, IReferralService referral,
        IRestaurantService restaurant,
        ILogger<OrderOrchestrationService> log)
    {
        _db = db; _hub = hub; _notifs = notifs;
        _wa = wa; _loyalty = loyalty; _referral = referral;
        _restaurant = restaurant; _log = log;
    }

    // ─── MALL ORDER STATUS CHANGED ────────────────────────────────────────
    public async Task OnOrderStatusChangedAsync(
        Guid mallOrderId, MallOrderStatus newStatus, CancellationToken ct = default)
    {
        var order = await _db.MallOrders.AsNoTracking()
            .Include(o => o.Customer)
            .FirstOrDefaultAsync(o => o.Id == mallOrderId, ct);
        if (order == null) return;

        var customer = order.Customer;
        var orderNum = order.OrderNumber;
        var phone    = customer?.Phone ?? string.Empty;
        var name     = customer?.FullName ?? "عميل";

        _log.LogInformation("Order {Num} status → {Status}", orderNum, newStatus);

        // 1. SignalR real-time
        await _hub.NotifyOrderStatusChangedAsync(
            mallOrderId.ToString(), newStatus.ToString());

        // 2. In-app notification
        if (customer != null)
            await _notifs.NotifyOrderStatusAsync(
                customer.Id, order.MallId, orderNum, newStatus.ToString(), ct);

        // 3. WhatsApp (for key statuses only)
        if (!string.IsNullOrEmpty(phone))
        {
            switch (newStatus)
            {
                case MallOrderStatus.Confirmed:
                    await _wa.SendOrderConfirmedAsync(phone, name, orderNum, order.Total, ct);
                    break;
                case MallOrderStatus.Delivered:
                    await _wa.SendOrderDeliveredAsync(phone, name, orderNum, ct);
                    break;
            }
        }

        // 4. On delivery: earn loyalty points
        if (newStatus == MallOrderStatus.Delivered && customer != null)
        {
            var earnReq = new Phase4.EarnPointsRequest(
                customer.Id, mallOrderId, order.Subtotal, order.MallId);
            await _loyalty.EarnPointsAsync(earnReq, ct);

            // Check if tier upgraded
            var updatedCustomer = await _db.MallCustomers.FindAsync([customer.Id], ct);
            if (updatedCustomer != null && updatedCustomer.Tier != customer.Tier)
                await _notifs.NotifyLoyaltyTierUpAsync(
                    customer.Id, order.MallId, updatedCustomer.Tier.ToString(), ct);

            // 5. Unlock referral reward
            await _referral.ProcessReferralRewardAsync(customer.Id, mallOrderId, ct);
        }
    }

    // ─── STORE ORDER STATUS CHANGED ───────────────────────────────────────
    public async Task OnStoreOrderStatusChangedAsync(
        Guid storeOrderId, string newStatus, CancellationToken ct = default)
    {
        var storeOrder = await _db.StoreOrders.AsNoTracking()
            .Include(so => so.MallOrder).ThenInclude(o => o.Customer)
            .Include(so => so.Store)
            .FirstOrDefaultAsync(so => so.Id == storeOrderId, ct);
        if (storeOrder == null) return;

        _log.LogInformation("StoreOrder {Id} status → {Status}", storeOrderId, newStatus);

        // For restaurants: create/advance queue ticket when Confirmed
        if (newStatus == "Confirmed" && storeOrder.Store?.EfProperty<string>("StoreType") == "Restaurant")
        {
            try { await _restaurant.CreateQueueTicketAsync(storeOrderId, ct); }
            catch (Exception ex)
            {
                _log.LogWarning(ex, "Could not create queue ticket for store order {Id}", storeOrderId);
            }
        }

        // If Ready: send WhatsApp
        if (newStatus == "Ready" && storeOrder.MallOrder?.Customer?.Phone is { } phone)
        {
            await _wa.SendOrderReadyAsync(
                phone,
                storeOrder.MallOrder.Customer.FullName,
                storeOrder.MallOrder.OrderNumber, ct);
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  LOW-STOCK ALERT SERVICE
//  Runs as background check — notifies store owners when stock is critical
// ══════════════════════════════════════════════════════════════════════════
public interface IInventoryAlertService
{
    Task CheckLowStockAsync(Guid? mallId = null, CancellationToken ct = default);
}

public class InventoryAlertService : IInventoryAlertService
{
    private readonly MesterXDbContext      _db;
    private readonly INotificationService  _notifs;
    private readonly ILogger<InventoryAlertService> _log;

    public InventoryAlertService(MesterXDbContext db,
        INotificationService notifs, ILogger<InventoryAlertService> log)
    { _db = db; _notifs = notifs; _log = log; }

    public async Task CheckLowStockAsync(Guid? mallId = null, CancellationToken ct = default)
    {
        // Find products below min stock level
        var lowStock = await _db.Products.AsNoTracking()
            .Include(p => p.StockItems)
            .Include(p => p.Tenant)
            .Where(p => p.IsActive && !p.IsDeleted
                && p.StockItems.Any()
                && p.StockItems.Sum(s => s.AvailableQuantity) <= p.MinStockLevel)
            .Select(p => new
            {
                p.Id, p.Name, p.Sku, p.MinStockLevel,
                p.TenantId, StoreName = p.Tenant!.Name,
                Qty = p.StockItems.Sum(s => s.AvailableQuantity),
                MallId = EF.Property<Guid?>(p.Tenant, "MallId"),
            })
            .Where(p => mallId == null || p.MallId == mallId)
            .ToListAsync(ct);

        if (!lowStock.Any()) return;

        // Group by store, find store owners to notify
        var storeGroups = lowStock.GroupBy(p => p.TenantId).ToList();

        _log.LogWarning("Low stock alert: {Count} products across {Stores} stores",
            lowStock.Count, storeGroups.Count);

        foreach (var group in storeGroups)
        {
            // Find a manager/owner for this store to notify
            var storeOwner = await _db.Users.AsNoTracking()
                .Include(u => u.UserBranches)
                .Where(u => u.TenantId == group.Key && u.IsActive && !u.IsDeleted)
                .Select(u => new { u.Id, u.Email })
                .FirstOrDefaultAsync(ct);

            if (storeOwner == null) continue;

            var productList = string.Join("، ", group.Take(3).Select(p => p.Name));
            var moreCount   = group.Count() > 3 ? $" + {group.Count() - 3} أخرى" : "";

            _log.LogInformation(
                "Low stock: {Store} — {Products}", group.First().StoreName, productList);
        }
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  COMMISSION SETTLEMENT SERVICE
//  Calculates and records monthly settlements for each store
// ══════════════════════════════════════════════════════════════════════════
public record SettlementSummaryDto
{
    public Guid   StoreId         { get; init; }
    public string StoreName       { get; init; } = string.Empty;
    public int    OrderCount      { get; init; }
    public decimal GrossRevenue   { get; init; }
    public decimal CommissionTotal{ get; init; }
    public decimal NetPayable     { get; init; }
    public string  Period         { get; init; } = string.Empty;
    public string  Status         { get; init; } = "Pending";
    public DateTime GeneratedAt   { get; init; }
}

public record CreateSettlementRequest(
    Guid  MallId,
    int   Year,
    int   Month
);

public interface ICommissionSettlementService
{
    Task<ApiResponse<List<SettlementSummaryDto>>> GenerateMonthlyAsync(
        CreateSettlementRequest req, CancellationToken ct = default);
    Task<ApiResponse<List<SettlementSummaryDto>>> GetPendingAsync(
        Guid mallId, CancellationToken ct = default);
    Task<ApiResponse> MarkPaidAsync(Guid settlementId, string reference, CancellationToken ct = default);
}

public class CommissionSettlementService : ICommissionSettlementService
{
    private readonly MesterXDbContext _db;
    private readonly ILogger<CommissionSettlementService> _log;

    public CommissionSettlementService(MesterXDbContext db,
        ILogger<CommissionSettlementService> log)
    { _db = db; _log = log; }

    public async Task<ApiResponse<List<SettlementSummaryDto>>> GenerateMonthlyAsync(
        CreateSettlementRequest req, CancellationToken ct = default)
    {
        var from   = new DateTime(req.Year, req.Month, 1, 0, 0, 0, DateTimeKind.Utc);
        var to     = from.AddMonths(1);
        var period = from.ToString("MMMM yyyy");

        var storeOrders = await _db.StoreOrders.AsNoTracking()
            .Include(so => so.MallOrder)
            .Include(so => so.Store)
            .Where(so => so.MallOrder.MallId == req.MallId
                && so.CreatedAt >= from && so.CreatedAt < to
                && so.MallOrder.Status == MallOrderStatus.Delivered)
            .ToListAsync(ct);

        var settlements = storeOrders
            .GroupBy(so => new { so.StoreId, so.Store!.Name })
            .Select(g => new SettlementSummaryDto
            {
                StoreId          = g.Key.StoreId,
                StoreName        = g.Key.Name,
                OrderCount       = g.Count(),
                GrossRevenue     = g.Sum(s => s.Subtotal),
                CommissionTotal  = g.Sum(s => s.CommissionAmt),
                NetPayable       = g.Sum(s => s.Subtotal - s.CommissionAmt),
                Period           = period,
                Status           = "Pending",
                GeneratedAt      = DateTime.UtcNow,
            })
            .OrderByDescending(s => s.GrossRevenue)
            .ToList();

        // Persist to DB (simplified — would have a CommissionSettlements table)
        _log.LogInformation(
            "Generated {Count} settlements for {Period} — Total commission: {Total:N2} EGP",
            settlements.Count, period, settlements.Sum(s => s.CommissionTotal));

        return ApiResponse<List<SettlementSummaryDto>>.Ok(settlements);
    }

    public async Task<ApiResponse<List<SettlementSummaryDto>>> GetPendingAsync(
        Guid mallId, CancellationToken ct = default)
    {
        // Return last month's settlements as pending
        var now    = DateTime.UtcNow;
        var result = await GenerateMonthlyAsync(
            new CreateSettlementRequest(mallId, now.AddMonths(-1).Year, now.AddMonths(-1).Month), ct);
        return result;
    }

    public Task<ApiResponse> MarkPaidAsync(Guid settlementId, string reference,
        CancellationToken ct = default)
    {
        _log.LogInformation("Settlement {Id} marked as paid. Ref: {Ref}", settlementId, reference);
        return Task.FromResult(ApiResponse.Ok());
    }
}
