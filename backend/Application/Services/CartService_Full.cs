using MesterX.Application.DTOs;
using MesterX.Domain.Entities.Mall;
using MesterX.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace MesterX.Application.Services;

public interface ICartService
{
    Task<ApiResponse<CartDto>> GetCartAsync(Guid customerId, Guid mallId, CancellationToken ct = default);
    Task<ApiResponse<CartDto>> AddItemAsync(AddToCartRequest req, Guid customerId, Guid mallId, CancellationToken ct = default);
    Task<ApiResponse<CartDto>> UpdateQtyAsync(Guid productId, int qty, Guid customerId, Guid mallId, CancellationToken ct = default);
    Task<ApiResponse<CartDto>> RemoveItemAsync(Guid productId, Guid customerId, Guid mallId, CancellationToken ct = default);
    Task<ApiResponse>          ClearCartAsync(Guid customerId, Guid mallId, CancellationToken ct = default);
}

public class CartService : ICartService
{
    private readonly MesterXDbContext _db;
    private readonly ILogger<CartService> _log;

    public CartService(MesterXDbContext db, ILogger<CartService> log)
    { _db = db; _log = log; }

    // ──────────────────────────────────────────────────────────────────────
    //  GET CART
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CartDto>> GetCartAsync(
        Guid customerId, Guid mallId, CancellationToken ct = default)
    {
        var cart = await _db.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.CustomerId == customerId && c.MallId == mallId, ct);

        if (cart == null)
            return ApiResponse<CartDto>.Ok(EmptyCart(customerId));

        return ApiResponse<CartDto>.Ok(await BuildCartDtoAsync(cart, ct));
    }

    // ──────────────────────────────────────────────────────────────────────
    //  ADD ITEM
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CartDto>> AddItemAsync(
        AddToCartRequest req, Guid customerId, Guid mallId, CancellationToken ct = default)
    {
        // Validate product exists and belongs to store
        var product = await _db.Products.AsNoTracking()
            .Include(p => p.StockItems)
            .FirstOrDefaultAsync(p => p.Id == req.ProductId && p.TenantId == req.StoreId
                && p.IsActive && !p.IsDeleted, ct);

        if (product == null)
            return ApiResponse<CartDto>.Fail("المنتج غير موجود أو غير متاح.");

        // Check available stock
        var availableQty = product.StockItems.Sum(s => s.AvailableQuantity);
        if (availableQty < req.Quantity)
            return ApiResponse<CartDto>.Fail(
                $"الكمية المتاحة من المنتج '{product.Name}' هي {availableQty} فقط.");

        // Get or create cart
        var cart = await _db.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.CustomerId == customerId && c.MallId == mallId, ct);

        if (cart == null)
        {
            cart = new Cart { Id = Guid.NewGuid(), CustomerId = customerId, MallId = mallId };
            _db.Carts.Add(cart);
        }

        // Check if product already in cart
        var existing = cart.Items.FirstOrDefault(i => i.ProductId == req.ProductId);
        if (existing != null)
        {
            var newQty = existing.Quantity + req.Quantity;
            if (newQty > availableQty)
                return ApiResponse<CartDto>.Fail(
                    $"لا يمكن إضافة أكثر من {availableQty} من '{product.Name}'.");

            existing.Quantity  = newQty;
            existing.Total     = product.SalePrice * newQty;
            existing.UnitPrice = product.SalePrice;
        }
        else
        {
            cart.Items.Add(new CartItem
            {
                Id          = Guid.NewGuid(),
                CartId      = cart.Id,
                StoreId     = req.StoreId,
                ProductId   = req.ProductId,
                ProductName = product.Name,
                Quantity    = req.Quantity,
                UnitPrice   = product.SalePrice,
                Total       = product.SalePrice * req.Quantity,
                Note        = req.Note,
            });
        }

        cart.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        _log.LogDebug("Cart {CartId}: added {Qty}x {Product}", cart.Id, req.Quantity, product.Name);
        return ApiResponse<CartDto>.Ok(await BuildCartDtoAsync(cart, ct));
    }

    // ──────────────────────────────────────────────────────────────────────
    //  UPDATE QUANTITY
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CartDto>> UpdateQtyAsync(
        Guid productId, int qty, Guid customerId, Guid mallId, CancellationToken ct = default)
    {
        if (qty <= 0) return await RemoveItemAsync(productId, customerId, mallId, ct);

        var cart = await _db.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.CustomerId == customerId && c.MallId == mallId, ct);
        if (cart == null)
            return ApiResponse<CartDto>.Fail("السلة غير موجودة.");

        var item = cart.Items.FirstOrDefault(i => i.ProductId == productId);
        if (item == null)
            return ApiResponse<CartDto>.Fail("المنتج غير موجود في السلة.");

        // Validate stock
        var stock = await _db.Set<Domain.Entities.Core.StockItem>().AsNoTracking()
            .Where(s => s.ProductId == productId)
            .SumAsync(s => s.AvailableQuantity, ct);
        if (qty > stock)
            return ApiResponse<CartDto>.Fail($"الكمية المتاحة {stock} فقط.");

        item.Quantity  = qty;
        item.Total     = item.UnitPrice * qty;
        cart.UpdatedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        return ApiResponse<CartDto>.Ok(await BuildCartDtoAsync(cart, ct));
    }

    // ──────────────────────────────────────────────────────────────────────
    //  REMOVE ITEM
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CartDto>> RemoveItemAsync(
        Guid productId, Guid customerId, Guid mallId, CancellationToken ct = default)
    {
        var cart = await _db.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.CustomerId == customerId && c.MallId == mallId, ct);
        if (cart == null)
            return ApiResponse<CartDto>.Ok(EmptyCart(customerId));

        var item = cart.Items.FirstOrDefault(i => i.ProductId == productId);
        if (item != null)
        {
            cart.Items.Remove(item);
            cart.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }

        return ApiResponse<CartDto>.Ok(await BuildCartDtoAsync(cart, ct));
    }

    // ──────────────────────────────────────────────────────────────────────
    //  CLEAR
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse> ClearCartAsync(
        Guid customerId, Guid mallId, CancellationToken ct = default)
    {
        var cart = await _db.Carts
            .Include(c => c.Items)
            .FirstOrDefaultAsync(c => c.CustomerId == customerId && c.MallId == mallId, ct);

        if (cart != null)
        {
            _db.Set<CartItem>().RemoveRange(cart.Items);
            cart.Items.Clear();
            cart.UpdatedAt = DateTime.UtcNow;
            await _db.SaveChangesAsync(ct);
        }

        return ApiResponse.Ok();
    }

    // ──────────────────────────────────────────────────────────────────────
    //  HELPERS
    // ──────────────────────────────────────────────────────────────────────
    private async Task<CartDto> BuildCartDtoAsync(Cart cart, CancellationToken ct)
    {
        // Group items by store
        var storeIds = cart.Items.Select(i => i.StoreId).Distinct().ToList();
        var stores   = await _db.Tenants.AsNoTracking()
            .Where(t => storeIds.Contains(t.Id))
            .Select(t => new { t.Id, t.Name })
            .ToListAsync(ct);

        var storeMap = stores.ToDictionary(s => s.Id, s => s.Name);

        var subtotal    = cart.Items.Sum(i => i.Total);
        var itemCount   = cart.Items.Sum(i => i.Quantity);
        var deliveryFee = itemCount > 0 ? 15m : 0m;   // default — real logic in checkout
        var total       = subtotal + deliveryFee;

        var storeGroups = cart.Items
            .GroupBy(i => i.StoreId)
            .Select(g => new CartStoreGroupDto
            {
                StoreId   = g.Key,
                StoreName = storeMap.GetValueOrDefault(g.Key, "—"),
                StoreType = "Retail",
                Subtotal  = g.Sum(i => i.Total),
                Items     = g.Select(i => new CartItemDto
                {
                    ProductId   = i.ProductId,
                    ProductName = i.ProductName ?? "—",
                    Quantity    = i.Quantity,
                    UnitPrice   = i.UnitPrice,
                    Total       = i.Total,
                    Note        = i.Note,
                    InStock     = true,
                }).ToList(),
            }).ToList();

        return new CartDto
        {
            Id          = cart.Id,
            CustomerId  = cart.CustomerId,
            ItemCount   = itemCount,
            Subtotal    = subtotal,
            DeliveryFee = deliveryFee,
            Total       = total,
            Stores      = storeGroups,
            UpdatedAt   = cart.UpdatedAt,
        };
    }

    private static CartDto EmptyCart(Guid customerId) => new()
    {
        Id = Guid.Empty, CustomerId = customerId,
        ItemCount = 0, Subtotal = 0, DeliveryFee = 0, Total = 0,
        Stores = [], UpdatedAt = DateTime.UtcNow,
    };
}
