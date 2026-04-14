using System.Text;
using MesterX.Application.DTOs;
using MesterX.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace MesterX.Application.Services.Phase11;

// ──────────────────────────────────────────────────────────────────────────
//  EXPORT SERVICE — CSV + simple tabular exports for admin reports
// ──────────────────────────────────────────────────────────────────────────
public record ExportRequest(
    string Type,          // Orders | Commissions | Customers | Loyalty | Products
    DateTime From,
    DateTime To,
    Guid? StoreId = null,
    string Format = "csv" // csv | tsv
);

public record ExportResult
{
    public byte[]  Data        { get; init; } = [];
    public string  FileName    { get; init; } = string.Empty;
    public string  ContentType { get; init; } = "text/csv";
    public int     RowCount    { get; init; }
}

public interface IExportService
{
    Task<ApiResponse<ExportResult>> ExportAsync(Guid mallId, ExportRequest req, CancellationToken ct = default);
}

public class ExportService : IExportService
{
    private readonly MesterXDbContext _db;
    private readonly ILogger<ExportService> _log;

    public ExportService(MesterXDbContext db, ILogger<ExportService> log)
    { _db = db; _log = log; }

    public async Task<ApiResponse<ExportResult>> ExportAsync(
        Guid mallId, ExportRequest req, CancellationToken ct = default)
    {
        var sep = req.Format == "tsv" ? "\t" : ",";

        var result = req.Type.ToLowerInvariant() switch
        {
            "orders"      => await ExportOrdersAsync(mallId, req, sep, ct),
            "commissions" => await ExportCommissionsAsync(mallId, req, sep, ct),
            "customers"   => await ExportCustomersAsync(mallId, req, sep, ct),
            "loyalty"     => await ExportLoyaltyAsync(mallId, req, sep, ct),
            "products"    => await ExportProductsAsync(mallId, req.StoreId, sep, ct),
            _ => null
        };

        if (result == null)
            return ApiResponse<ExportResult>.Fail("نوع التصدير غير مدعوم.");

        _log.LogInformation("Exported {Type}: {Rows} rows for mall {MallId}",
            req.Type, result.RowCount, mallId);
        return ApiResponse<ExportResult>.Ok(result);
    }

    // ─── ORDERS ──────────────────────────────────────────────────────────
    private async Task<ExportResult> ExportOrdersAsync(
        Guid mallId, ExportRequest req, string sep, CancellationToken ct)
    {
        var orders = await _db.MallOrders.AsNoTracking()
            .Include(o => o.Customer)
            .Include(o => o.StoreOrders).ThenInclude(so => so.Store)
            .Where(o => o.MallId == mallId
                && o.PlacedAt >= req.From && o.PlacedAt <= req.To)
            .OrderByDescending(o => o.PlacedAt)
            .ToListAsync(ct);

        var sb = new StringBuilder();
        sb.AppendLine(Cols(sep,
            "رقم الطلب", "التاريخ", "اسم العميل", "الهاتف",
            "طريقة الاستلام", "طريقة الدفع", "الحالة",
            "المجموع الفرعي", "رسوم التوصيل", "الخصم", "الإجمالي",
            "المحلات"));

        foreach (var o in orders)
        {
            var stores = string.Join(" | ", o.StoreOrders.Select(s => s.Store?.Name ?? "?"));
            sb.AppendLine(Cols(sep,
                o.OrderNumber,
                o.PlacedAt.ToString("yyyy-MM-dd HH:mm"),
                o.Customer?.FullName ?? "",
                o.Customer?.Phone    ?? "",
                o.FulfillmentType.ToString(),
                o.PaymentMethod.ToString(),
                o.Status.ToString(),
                o.Subtotal.ToString("N2"),
                o.DeliveryFee.ToString("N2"),
                o.DiscountAmount.ToString("N2"),
                o.Total.ToString("N2"),
                stores));
        }

        return MakeResult(sb, $"orders_{req.From:yyyyMMdd}_{req.To:yyyyMMdd}.csv", orders.Count);
    }

    // ─── COMMISSIONS ─────────────────────────────────────────────────────
    private async Task<ExportResult> ExportCommissionsAsync(
        Guid mallId, ExportRequest req, string sep, CancellationToken ct)
    {
        var storeOrders = await _db.StoreOrders.AsNoTracking()
            .Include(so => so.MallOrder)
            .Include(so => so.Store)
            .Where(so => so.MallOrder.MallId == mallId
                && so.CreatedAt >= req.From && so.CreatedAt <= req.To
                && (req.StoreId == null || so.StoreId == req.StoreId))
            .OrderBy(so => so.Store!.Name)
            .ThenByDescending(so => so.CreatedAt)
            .ToListAsync(ct);

        var sb = new StringBuilder();
        sb.AppendLine(Cols(sep,
            "المحل", "رقم الطلب", "التاريخ", "الإجمالي", "نسبة العمولة", "العمولة", "الصافي"));

        foreach (var so in storeOrders)
        {
            var rate = so.Subtotal > 0 ? so.CommissionAmt / so.Subtotal : 0;
            sb.AppendLine(Cols(sep,
                so.Store?.Name ?? "",
                so.MallOrder?.OrderNumber ?? "",
                so.CreatedAt.ToString("yyyy-MM-dd"),
                so.Subtotal.ToString("N2"),
                rate.ToString("P1"),
                so.CommissionAmt.ToString("N2"),
                (so.Subtotal - so.CommissionAmt).ToString("N2")));
        }

        // Summary row
        sb.AppendLine(Cols(sep,
            "الإجمالي", "", "",
            storeOrders.Sum(s => s.Subtotal).ToString("N2"),
            "",
            storeOrders.Sum(s => s.CommissionAmt).ToString("N2"),
            storeOrders.Sum(s => s.Subtotal - s.CommissionAmt).ToString("N2")));

        return MakeResult(sb, $"commissions_{req.From:yyyyMMdd}_{req.To:yyyyMMdd}.csv", storeOrders.Count);
    }

    // ─── CUSTOMERS ────────────────────────────────────────────────────────
    private async Task<ExportResult> ExportCustomersAsync(
        Guid mallId, ExportRequest req, string sep, CancellationToken ct)
    {
        var customers = await _db.MallCustomers.AsNoTracking()
            .Where(c => c.MallId == mallId && !c.IsDeleted
                && c.CreatedAt >= req.From && c.CreatedAt <= req.To)
            .OrderByDescending(c => c.CreatedAt)
            .ToListAsync(ct);

        var sb = new StringBuilder();
        sb.AppendLine(Cols(sep,
            "الاسم الأول", "الاسم الأخير", "البريد الإلكتروني", "الهاتف",
            "المستوى", "نقاط الولاء", "تاريخ التسجيل", "آخر تسجيل دخول"));

        foreach (var c in customers)
        {
            sb.AppendLine(Cols(sep,
                c.FirstName, c.LastName, c.Email, c.Phone ?? "",
                c.Tier.ToString(), c.LoyaltyPoints.ToString(),
                c.CreatedAt.ToString("yyyy-MM-dd"),
                c.LastLoginAt?.ToString("yyyy-MM-dd") ?? "—"));
        }

        return MakeResult(sb, $"customers_{req.From:yyyyMMdd}.csv", customers.Count);
    }

    // ─── LOYALTY TRANSACTIONS ─────────────────────────────────────────────
    private async Task<ExportResult> ExportLoyaltyAsync(
        Guid mallId, ExportRequest req, string sep, CancellationToken ct)
    {
        var txns = await _db.Set<Domain.Entities.Phase4.PointsTransaction>()
            .AsNoTracking()
            .Include(t => t.Account).ThenInclude(a => a.Customer)
            .Where(t => t.Account.MallId == mallId
                && t.CreatedAt >= req.From && t.CreatedAt <= req.To)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync(ct);

        var sb = new StringBuilder();
        sb.AppendLine(Cols(sep,
            "العميل", "البريد", "المصدر", "النقاط", "الرصيد بعد", "التاريخ", "التفاصيل"));

        foreach (var t in txns)
        {
            sb.AppendLine(Cols(sep,
                t.Account?.Customer?.FullName ?? "",
                t.Account?.Customer?.Email   ?? "",
                t.Source.ToString(),
                t.Points.ToString("+0;-0"),
                t.BalanceAfter.ToString(),
                t.CreatedAt.ToString("yyyy-MM-dd HH:mm"),
                t.Description ?? ""));
        }

        return MakeResult(sb, $"loyalty_{req.From:yyyyMMdd}_{req.To:yyyyMMdd}.csv", txns.Count);
    }

    // ─── PRODUCTS ─────────────────────────────────────────────────────────
    private async Task<ExportResult> ExportProductsAsync(
        Guid mallId, Guid? storeId, string sep, CancellationToken ct)
    {
        var allStoreIds = storeId.HasValue
            ? new List<Guid> { storeId.Value }
            : await _db.Tenants.AsNoTracking()
                .Where(t => EF.Property<Guid?>(t, "MallId") == mallId && t.IsActive)
                .Select(t => t.Id).ToListAsync(ct);

        var products = await _db.Products.AsNoTracking()
            .Include(p => p.Tenant)
            .Include(p => p.StockItems)
            .Where(p => allStoreIds.Contains(p.TenantId) && !p.IsDeleted)
            .OrderBy(p => p.Tenant!.Name).ThenBy(p => p.Name)
            .ToListAsync(ct);

        var sb = new StringBuilder();
        sb.AppendLine(Cols(sep,
            "المحل", "اسم المنتج", "الكود", "الباركود",
            "سعر البيع", "سعر التكلفة", "نسبة الربح",
            "الكمية المتاحة", "الحد الأدنى", "الحالة"));

        foreach (var p in products)
        {
            var qty    = p.StockItems.Sum(s => s.AvailableQuantity);
            var margin = p.CostPrice > 0
                ? ((p.SalePrice - p.CostPrice) / p.CostPrice * 100)
                : 0;
            sb.AppendLine(Cols(sep,
                p.Tenant?.Name ?? "",
                p.Name, p.Sku, p.Barcode ?? "",
                p.SalePrice.ToString("N2"),
                p.CostPrice.ToString("N2"),
                margin.ToString("N1") + "%",
                qty.ToString(),
                p.MinStockLevel.ToString(),
                p.IsActive ? "نشط" : "متوقف"));
        }

        return MakeResult(sb, $"products_catalog.csv", products.Count);
    }

    // ─── HELPERS ─────────────────────────────────────────────────────────
    private static string Cols(string sep, params string[] cols)
    {
        // Wrap cells that contain sep or quotes in double quotes
        var escaped = cols.Select(c =>
        {
            c = c.Replace("\"", "\"\"");
            return c.Contains(sep) || c.Contains("\"") || c.Contains("\n")
                ? $"\"{c}\"" : c;
        });
        return string.Join(sep, escaped);
    }

    private static ExportResult MakeResult(StringBuilder sb, string fileName, int rows)
    {
        // Add BOM for Arabic Excel compatibility
        var bom  = Encoding.UTF8.GetPreamble();
        var data = Encoding.UTF8.GetBytes(sb.ToString());
        var full = new byte[bom.Length + data.Length];
        Buffer.BlockCopy(bom,  0, full, 0,          bom.Length);
        Buffer.BlockCopy(data, 0, full, bom.Length,  data.Length);

        return new ExportResult
        {
            Data        = full,
            FileName    = fileName,
            ContentType = "text/csv; charset=utf-8",
            RowCount    = rows,
        };
    }
}
