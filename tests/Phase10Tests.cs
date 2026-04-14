using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using MesterX.Application.Services.Phase9;
using MesterX.Application.Services.Phase10;
using MesterX.Application.Services.Phase4;
using MesterX.Domain.Entities.Mall;
using MesterX.Infrastructure.Caching;
using MesterX.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace MallX.Tests.Phase10;

// ──────────────────────────────────────────────────────────────────────────
//  WALLET SERVICE TESTS
// ──────────────────────────────────────────────────────────────────────────
public class WalletServiceTests
{
    private readonly Mock<ICacheService> _cache = new();
    private readonly Mock<ILogger<WalletService>> _log = new();

    private static (MesterXDbContext db, MallCustomer customer, Mall mall) SetupWallet()
    {
        var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        return (db, customer, mall);
    }

    [Fact]
    public async Task GetWallet_NewCustomer_ShouldCreateEmptyWallet()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.GetWalletAsync(customer.Id, mall.Id);

        Assert.True(result.Success);
        Assert.Equal(0, result.Data!.Balance);
        Assert.Equal("0.00 ج.م", result.Data.BalanceLabel);
    }

    [Fact]
    public async Task TopUp_ValidAmount_ShouldIncreaseBalance()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.TopUpAsync(customer.Id, mall.Id,
            new TopUpRequest(200m, "Cash", null));

        Assert.True(result.Success);
        Assert.Equal(200m, result.Data!.Balance);
        Assert.Equal(200m, result.Data.TotalToppedUp);
    }

    [Fact]
    public async Task TopUp_BelowMinimum_ShouldFail()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.TopUpAsync(customer.Id, mall.Id,
            new TopUpRequest(5m, "Cash", null));

        Assert.False(result.Success);
        Assert.Contains("الحد الأدنى", result.Error);
    }

    [Fact]
    public async Task TopUp_AboveMaximum_ShouldFail()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.TopUpAsync(customer.Id, mall.Id,
            new TopUpRequest(6000m, "Cash", null));

        Assert.False(result.Success);
        Assert.Contains("الحد الأقصى", result.Error);
    }

    [Fact]
    public async Task Spend_WithSufficientBalance_ShouldDeductAndApplyToOrder()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        // Create wallet with 300 balance
        var wallet = new CustomerWallet
            { CustomerId = customer.Id, MallId = mall.Id, Balance = 300m };
        db.Set<CustomerWallet>().Add(wallet);

        var order = new MallOrder
        {
            Id = Guid.NewGuid(), CustomerId = customer.Id, MallId = mall.Id,
            OrderNumber = "MX-SPD-001", Total = 200m, Subtotal = 200m,
            Status = MallOrderStatus.Placed, DeliveryFee = 0,
        };
        db.MallOrders.Add(order);
        await db.SaveChangesAsync();

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.SpendAsync(customer.Id, new SpendFromWalletRequest(order.Id, 150m));

        Assert.True(result.Success);
        Assert.Equal(-150m, result.Data!.Amount);
        Assert.Equal(150m,  result.Data.BalanceAfter);

        // Verify order was discounted
        var updatedOrder = await db.MallOrders.FindAsync(order.Id);
        Assert.Equal(50m, updatedOrder!.Total);
    }

    [Fact]
    public async Task Spend_InsufficientBalance_ShouldFail()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var wallet = new CustomerWallet
            { CustomerId = customer.Id, MallId = mall.Id, Balance = 50m };
        db.Set<CustomerWallet>().Add(wallet);
        var order = new MallOrder
        {
            Id = Guid.NewGuid(), CustomerId = customer.Id, MallId = mall.Id,
            OrderNumber = "MX-INSUF", Total = 200m, Subtotal = 200m,
            Status = MallOrderStatus.Placed, DeliveryFee = 0,
        };
        db.MallOrders.Add(order);
        await db.SaveChangesAsync();

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.SpendAsync(customer.Id, new SpendFromWalletRequest(order.Id, 100m));

        Assert.False(result.Success);
        Assert.Contains("غير كافٍ", result.Error);
    }

    [Fact]
    public async Task Refund_ValidOrder_ShouldRestoreBalance()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var wallet = new CustomerWallet
            { CustomerId = customer.Id, MallId = mall.Id, Balance = 0m };
        db.Set<CustomerWallet>().Add(wallet);
        var order = new MallOrder
        {
            Id = Guid.NewGuid(), CustomerId = customer.Id, MallId = mall.Id,
            OrderNumber = "MX-REF-001", Total = 0m, Subtotal = 200m,
            Status = MallOrderStatus.Cancelled, DeliveryFee = 0,
        };
        db.MallOrders.Add(order);
        await db.SaveChangesAsync();

        var svc    = new WalletService(db, _cache.Object, _log.Object);
        var result = await svc.RefundToWalletAsync(
            customer.Id, order.Id, 200m, "إلغاء الطلب");

        Assert.True(result.Success);
        var updatedWallet = await db.Set<CustomerWallet>()
            .FirstAsync(w => w.CustomerId == customer.Id);
        Assert.Equal(200m, updatedWallet.Balance);
    }

    [Fact]
    public async Task MultipleTopUps_ShouldAccumulate()
    {
        var (db, customer, mall) = SetupWallet();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new WalletService(db, _cache.Object, _log.Object);
        await svc.TopUpAsync(customer.Id, mall.Id, new TopUpRequest(100m, "Cash", null));
        await svc.TopUpAsync(customer.Id, mall.Id, new TopUpRequest(50m,  "Cash", null));
        var result = await svc.TopUpAsync(customer.Id, mall.Id,
            new TopUpRequest(75m, "Cash", null));

        Assert.True(result.Success);
        Assert.Equal(225m, result.Data!.Balance);
        Assert.Equal(225m, result.Data.TotalToppedUp);
    }
}

// ──────────────────────────────────────────────────────────────────────────
//  NOTIFICATION SERVICE TESTS
// ──────────────────────────────────────────────────────────────────────────
public class NotificationServiceTests
{
    private readonly Mock<ICacheService>               _cache = new();
    private readonly Mock<ILogger<NotificationService>> _log  = new();

    [Fact]
    public async Task CreateNotification_ShouldPersistAndClearCache()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new NotificationService(db, _cache.Object, _log.Object);
        var result = await svc.CreateAsync(new CreateNotifRequest(
            customer.Id, mall.Id,
            NotifCategory.Order, "طلبك قيد التحضير",
            "الطاهي يحضر طلبك الآن 👨‍🍳"));

        Assert.True(result.Success);
        var count = await db.Set<CustomerNotification>()
            .CountAsync(n => n.CustomerId == customer.Id);
        Assert.Equal(1, count);
    }

    [Fact]
    public async Task GetNotifications_ShouldReturnUnreadCount()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new NotificationService(db, _cache.Object, _log.Object);
        await svc.CreateAsync(new CreateNotifRequest(
            customer.Id, mall.Id, NotifCategory.Order, "N1", "Body1"));
        await svc.CreateAsync(new CreateNotifRequest(
            customer.Id, mall.Id, NotifCategory.Promo, "N2", "Body2"));

        var result = await svc.GetNotificationsAsync(customer.Id, 1, 20);

        Assert.True(result.Success);
        Assert.Equal(2, result.Data!.UnreadCount);
        Assert.Equal(2, result.Data.Items.Count);
    }

    [Fact]
    public async Task MarkRead_ShouldSetIsReadTrue()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new NotificationService(db, _cache.Object, _log.Object);
        await svc.CreateAsync(new CreateNotifRequest(
            customer.Id, mall.Id, NotifCategory.Wallet, "شحن", "تم شحن 100 ج.م"));

        var notif = await db.Set<CustomerNotification>().FirstAsync();
        await svc.MarkReadAsync(customer.Id, notif.Id);

        var updated = await db.Set<CustomerNotification>().FindAsync(notif.Id);
        Assert.True(updated!.IsRead);
        Assert.NotNull(updated.ReadAt);
    }

    [Fact]
    public async Task MarkAllRead_ShouldClearAllUnread()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new NotificationService(db, _cache.Object, _log.Object);
        for (int i = 0; i < 5; i++)
            await svc.CreateAsync(new CreateNotifRequest(
                customer.Id, mall.Id, NotifCategory.System, $"Notif {i}", "Body"));

        await svc.MarkAllReadAsync(customer.Id);

        var unread = await db.Set<CustomerNotification>()
            .CountAsync(n => n.CustomerId == customer.Id && !n.IsRead);
        Assert.Equal(0, unread);
    }

    [Fact]
    public async Task NotifyOrderStatus_Delivered_ShouldCreateCorrectMessage()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new NotificationService(db, _cache.Object, _log.Object);
        await svc.NotifyOrderStatusAsync(customer.Id, mall.Id, "MX-001", "Delivered");

        var notif = await db.Set<CustomerNotification>().FirstAsync();
        Assert.Equal(NotifCategory.Order, notif.Category);
        Assert.Contains("تم التسليم", notif.Title);
        Assert.Equal("OpenOrder", notif.ActionType);
    }

    [Fact]
    public async Task NotifyLoyaltyTierUp_Gold_ShouldMentionFreeDelivery()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new NotificationService(db, _cache.Object, _log.Object);
        await svc.NotifyLoyaltyTierUpAsync(customer.Id, mall.Id, "Gold");

        var notif = await db.Set<CustomerNotification>().FirstAsync();
        Assert.Equal(NotifCategory.Loyalty, notif.Category);
        Assert.Contains("Gold", notif.Title);
        Assert.Contains("توصيل مجاني", notif.Body);
    }

    [Fact]
    public async Task CreateBulk_ShouldCreateMultipleNotifications()
    {
        using var db = TestDb.Create();
        var (c1, mall) = TestDb.Seed(db);
        var c2 = new MallCustomer
        {
            Id = Guid.NewGuid(), MallId = mall.Id,
            FirstName = "فاطمة", LastName = "علي",
            Email = "fatma@test.com",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Test123!"),
            Tier = CustomerTier.Bronze,
        };
        db.MallCustomers.Add(c2);
        await db.SaveChangesAsync();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc = new NotificationService(db, _cache.Object, _log.Object);
        await svc.CreateBulkAsync(new[]
        {
            new CreateNotifRequest(c1.Id, mall.Id, NotifCategory.Promo, "عرض", "خصم 30%"),
            new CreateNotifRequest(c2.Id, mall.Id, NotifCategory.Promo, "عرض", "خصم 30%"),
        });

        var total = await db.Set<CustomerNotification>().CountAsync();
        Assert.Equal(2, total);
    }
}

// ──────────────────────────────────────────────────────────────────────────
//  PRODUCT REVIEW SERVICE TESTS
// ──────────────────────────────────────────────────────────────────────────
public class ProductReviewServiceTests
{
    private readonly Mock<ICacheService>               _cache = new();
    private readonly Mock<ILogger<ProductReviewService>> _log = new();

    [Fact]
    public async Task SubmitReview_ValidStars_ShouldPersist()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        var store = new Domain.Entities.Core.Tenant
            { Id = Guid.NewGuid(), Name = "S", Slug = "s", IsActive = true };
        var product = new Domain.Entities.Core.Product
            { Id = Guid.NewGuid(), TenantId = store.Id, Name = "P", Sku = "P1", SalePrice = 50m };
        db.Tenants.Add(store); db.Products.Add(product);
        await db.SaveChangesAsync();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new ProductReviewService(db, _cache.Object, _log.Object);
        var result = await svc.SubmitAsync(customer.Id, new SubmitProductReviewRequest(
            product.Id, store.Id, null, 4, "جيد جداً", "منتج ممتاز ورائع", null));

        Assert.True(result.Success);
        Assert.Equal(4, result.Data!.Stars);
        Assert.Equal("جيد جداً", result.Data.Title);
    }

    [Fact]
    public async Task SubmitReview_InvalidStars_ShouldFail()
    {
        using var db = TestDb.Create();
        var (customer, _) = TestDb.Seed(db);
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new ProductReviewService(db, _cache.Object, _log.Object);
        var result = await svc.SubmitAsync(customer.Id, new SubmitProductReviewRequest(
            Guid.NewGuid(), Guid.NewGuid(), null, 6, null, null, null));

        Assert.False(result.Success);
        Assert.Contains("1 و 5", result.Error);
    }

    [Fact]
    public async Task SubmitReview_Duplicate_ShouldFail()
    {
        using var db = TestDb.Create();
        var (customer, _) = TestDb.Seed(db);
        var productId = Guid.NewGuid();
        var storeId   = Guid.NewGuid();
        db.Set<ProductReview>().Add(new ProductReview
        {
            ProductId = productId, StoreId = storeId,
            CustomerId = customer.Id, Stars = 4,
        });
        await db.SaveChangesAsync();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new ProductReviewService(db, _cache.Object, _log.Object);
        var result = await svc.SubmitAsync(customer.Id, new SubmitProductReviewRequest(
            productId, storeId, null, 5, null, null, null));

        Assert.False(result.Success);
        Assert.Contains("مسبقاً", result.Error);
    }

    [Fact]
    public async Task MarkHelpful_ShouldIncrementCount()
    {
        using var db = TestDb.Create();
        var (customer, _) = TestDb.Seed(db);
        var review = new ProductReview
        {
            ProductId = Guid.NewGuid(), StoreId = Guid.NewGuid(),
            CustomerId = customer.Id, Stars = 4, HelpfulCount = 2,
        };
        db.Set<ProductReview>().Add(review);
        await db.SaveChangesAsync();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new ProductReviewService(db, _cache.Object, _log.Object);
        await svc.MarkHelpfulAsync(customer.Id, review.Id);

        var updated = await db.Set<ProductReview>().FindAsync(review.Id);
        Assert.Equal(3, updated!.HelpfulCount);
    }

    [Fact]
    public async Task GetReviews_ShouldReturnSummaryAndList()
    {
        using var db = TestDb.Create();
        var (customer, _) = TestDb.Seed(db);
        var productId = Guid.NewGuid();
        var storeId   = Guid.NewGuid();

        db.Set<ProductRatingSummary>().Add(new ProductRatingSummary
        {
            ProductId    = productId, AvgStars = 4.2m, TotalReviews = 5,
            FiveStar = 2, FourStar = 2, ThreeStar = 1,
        });
        db.Set<ProductReview>().AddRange(new[]
        {
            new ProductReview { ProductId=productId, StoreId=storeId, CustomerId=customer.Id, Stars=5, IsPublished=true },
            new ProductReview { ProductId=productId, StoreId=storeId, CustomerId=Guid.NewGuid(), Stars=4, IsPublished=true },
        });
        await db.SaveChangesAsync();
        _cache.Setup(c => c.GetAsync<ProductReviewsDto>(It.IsAny<string>(), default))
              .ReturnsAsync((ProductReviewsDto?)null);

        var svc    = new ProductReviewService(db, _cache.Object, _log.Object);
        var result = await svc.GetReviewsAsync(productId, 1, 10);

        Assert.True(result.Success);
        Assert.Equal(4.2m, result.Data!.AvgStars);
        Assert.Equal(5,    result.Data.TotalReviews);
        Assert.Equal(2,    result.Data.Reviews.Count);
    }

    [Fact]
    public async Task StoreReply_ShouldPersistReply()
    {
        using var db = TestDb.Create();
        var (customer, _) = TestDb.Seed(db);
        var storeId = Guid.NewGuid();
        var review  = new ProductReview
        {
            ProductId = Guid.NewGuid(), StoreId = storeId,
            CustomerId = customer.Id, Stars = 3, IsPublished = true,
        };
        db.Set<ProductReview>().Add(review);
        await db.SaveChangesAsync();
        _cache.Setup(c => c.GetAsync<string>(It.IsAny<string>(), default))
              .ReturnsAsync((string?)null);

        var svc    = new ProductReviewService(db, _cache.Object, _log.Object);
        var result = await svc.ReplyAsync(storeId, review.Id, "شكراً على تقييمك! سنعمل على التحسين.");

        Assert.True(result.Success);
        var updated = await db.Set<ProductReview>().FindAsync(review.Id);
        Assert.Contains("شكراً", updated!.StoreReply);
        Assert.NotNull(updated.StoreRepliedAt);
    }
}

// ──────────────────────────────────────────────────────────────────────────
//  REORDER SERVICE TESTS
// ──────────────────────────────────────────────────────────────────────────
public class ReorderServiceTests
{
    private readonly Mock<ILogger<ReorderService>> _log = new();

    [Fact]
    public async Task SaveOrder_FromValidOrder_ShouldCreateTemplate()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);
        var store   = new Domain.Entities.Core.Tenant
            { Id = Guid.NewGuid(), Name = "Store", Slug = "st", IsActive = true };
        var product = new Domain.Entities.Core.Product
            { Id = Guid.NewGuid(), TenantId = store.Id, Name = "Pizza", Sku = "P1", SalePrice = 55m };
        db.Tenants.Add(store); db.Products.Add(product);

        var order = new MallOrder
        {
            Id = Guid.NewGuid(), CustomerId = customer.Id, MallId = mall.Id,
            OrderNumber = "MX-RO-001", Total = 110m, Subtotal = 110m,
            Status = MallOrderStatus.Delivered, DeliveryFee = 0,
        };
        db.MallOrders.Add(order);
        var storeOrder = new StoreOrder
        {
            Id = Guid.NewGuid(), MallOrderId = order.Id, StoreId = store.Id,
            Status = StoreOrderStatus.Delivered, Subtotal = 110m, CommissionAmt = 5.5m,
        };
        db.StoreOrders.Add(storeOrder);
        db.CartItems.Add(new CartItem
        {
            StoreOrderId = storeOrder.Id, ProductId = product.Id,
            ProductName = "Pizza", Quantity = 2, UnitPrice = 55m,
            Total = 110m, StoreId = store.Id,
        });
        await db.SaveChangesAsync();

        var svc    = new ReorderService(db, _log.Object);
        var result = await svc.SaveOrderAsync(customer.Id,
            new SaveOrderRequest("بيتزا الجمعة", order.Id));

        Assert.True(result.Success);
        Assert.Equal("بيتزا الجمعة", result.Data!.Name);
        Assert.Equal(0, result.Data.OrderCount);
    }

    [Fact]
    public async Task GetSavedOrders_ShouldReturnSavedTemplates()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        db.Set<SavedOrder>().Add(new SavedOrder
        {
            CustomerId = customer.Id, MallId = mall.Id,
            Name = "طلبي المعتاد",
            ItemsJson = System.Text.Json.JsonSerializer.Serialize(new object[] { }),
            TotalEst = 120m, OrderCount = 5,
        });
        await db.SaveChangesAsync();

        var svc    = new ReorderService(db, _log.Object);
        var result = await svc.GetSavedOrdersAsync(customer.Id);

        Assert.True(result.Success);
        Assert.Single(result.Data!);
        Assert.Equal("طلبي المعتاد", result.Data[0].Name);
        Assert.Equal(5, result.Data[0].OrderCount);
    }

    [Fact]
    public async Task DeleteSavedOrder_ShouldSoftDelete()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        var saved = new SavedOrder
        {
            CustomerId = customer.Id, MallId = mall.Id,
            Name = "طلب قديم", ItemsJson = "[]",
        };
        db.Set<SavedOrder>().Add(saved);
        await db.SaveChangesAsync();

        var svc    = new ReorderService(db, _log.Object);
        var result = await svc.DeleteSavedOrderAsync(customer.Id, saved.Id);

        Assert.True(result.Success);
        var deleted = await db.Set<SavedOrder>().FindAsync(saved.Id);
        Assert.False(deleted!.IsActive);
    }

    [Fact]
    public async Task DeleteSavedOrder_WrongCustomer_ShouldFail()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        var saved = new SavedOrder
        {
            CustomerId = Guid.NewGuid(), // different customer
            MallId = mall.Id, Name = "Saved", ItemsJson = "[]",
        };
        db.Set<SavedOrder>().Add(saved);
        await db.SaveChangesAsync();

        var svc    = new ReorderService(db, _log.Object);
        var result = await svc.DeleteSavedOrderAsync(customer.Id, saved.Id);

        Assert.False(result.Success);
    }
}

// ──────────────────────────────────────────────────────────────────────────
//  REFERRAL SERVICE TESTS
// ──────────────────────────────────────────────────────────────────────────
public class ReferralServiceTests
{
    private readonly Mock<ILoyaltyService>             _loyalty = new();
    private readonly Mock<IWalletService>              _wallet  = new();
    private readonly Mock<ILogger<ReferralService>>    _log     = new();

    [Fact]
    public async Task GetOrCreateCode_NewCustomer_ShouldGenerateCode()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        var svc    = new ReferralService(db, _loyalty.Object, _wallet.Object, _log.Object);
        var result = await svc.GetOrCreateCodeAsync(customer.Id, mall.Id);

        Assert.True(result.Success);
        Assert.NotEmpty(result.Data!.Code);
        Assert.Contains("http", result.Data.ShareUrl);
        Assert.Contains(result.Data.Code, result.Data.ShareMessage);
    }

    [Fact]
    public async Task GetOrCreateCode_ExistingCode_ShouldReturnSameCode()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        db.Set<ReferralCode>().Add(new ReferralCode
            { CustomerId = customer.Id, MallId = mall.Id, Code = "AHM1234" });
        await db.SaveChangesAsync();

        var svc = new ReferralService(db, _loyalty.Object, _wallet.Object, _log.Object);
        var r1  = await svc.GetOrCreateCodeAsync(customer.Id, mall.Id);
        var r2  = await svc.GetOrCreateCodeAsync(customer.Id, mall.Id);

        Assert.Equal("AHM1234", r1.Data!.Code);
        Assert.Equal("AHM1234", r2.Data!.Code);
    }

    [Fact]
    public async Task ApplyReferral_ValidCode_ShouldSucceedAndAwardPoints()
    {
        using var db = TestDb.Create();
        var (referrer, mall) = TestDb.Seed(db);

        // Referee (new customer)
        var referee = new MallCustomer
        {
            Id = Guid.NewGuid(), MallId = mall.Id,
            FirstName = "جديد", LastName = "عميل",
            Email = "new@test.com",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("Test123!"),
            Tier = CustomerTier.Bronze,
        };
        db.MallCustomers.Add(referee);

        db.Set<ReferralCode>().Add(new ReferralCode
            { CustomerId = referrer.Id, MallId = mall.Id, Code = "REF999" });
        db.Set<ReferralProgram>().Add(new ReferralProgram
        {
            MallId = mall.Id, Name = "Test Program",
            ReferrerRewardPts = 200, RefereeRewardPts = 100, IsActive = true,
        });
        await db.SaveChangesAsync();

        _loyalty.Setup(l => l.AwardBonusAsync(
            It.IsAny<Guid>(), It.IsAny<Guid>(),
            It.IsAny<PointsSource>(), It.IsAny<int>(),
            It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Returns(Task.CompletedTask);

        var svc    = new ReferralService(db, _loyalty.Object, _wallet.Object, _log.Object);
        var result = await svc.ApplyReferralAsync(referee.Id, "REF999", mall.Id);

        Assert.True(result.Success);
        // Verify loyalty award was called for referee
        _loyalty.Verify(l => l.AwardBonusAsync(
            referee.Id, mall.Id, PointsSource.Referral, 100, It.IsAny<string>(),
            It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ApplyReferral_OwnCode_ShouldFail()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        db.Set<ReferralCode>().Add(new ReferralCode
            { CustomerId = customer.Id, MallId = mall.Id, Code = "OWN123" });
        db.Set<ReferralProgram>().Add(new ReferralProgram
            { MallId = mall.Id, Name = "Prog", IsActive = true });
        await db.SaveChangesAsync();

        var svc    = new ReferralService(db, _loyalty.Object, _wallet.Object, _log.Object);
        var result = await svc.ApplyReferralAsync(customer.Id, "OWN123", mall.Id);

        Assert.False(result.Success);
        Assert.Contains("كودك الخاص", result.Error);
    }

    [Fact]
    public async Task ApplyReferral_InvalidCode_ShouldFail()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        var svc    = new ReferralService(db, _loyalty.Object, _wallet.Object, _log.Object);
        var result = await svc.ApplyReferralAsync(customer.Id, "BADCODE", mall.Id);

        Assert.False(result.Success);
        Assert.Contains("غير صالح", result.Error);
    }

    [Fact]
    public async Task ApplyReferral_AlreadyUsed_ShouldFail()
    {
        using var db = TestDb.Create();
        var (referrer, mall) = TestDb.Seed(db);

        var referee = new MallCustomer
        {
            Id = Guid.NewGuid(), MallId = mall.Id,
            FirstName = "T", LastName = "U", Email = "t@t.com",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("T"), Tier = CustomerTier.Bronze,
        };
        db.MallCustomers.Add(referee);

        var program = new ReferralProgram
            { MallId = mall.Id, Name = "P", IsActive = true };
        db.Set<ReferralCode>().Add(new ReferralCode
            { CustomerId = referrer.Id, MallId = mall.Id, Code = "REF456" });
        db.Set<ReferralProgram>().Add(program);
        db.Set<ReferralUse>().Add(new ReferralUse
            { ProgramId = program.Id, ReferrerId = referrer.Id, RefereeId = referee.Id });
        await db.SaveChangesAsync();

        var svc    = new ReferralService(db, _loyalty.Object, _wallet.Object, _log.Object);
        var result = await svc.ApplyReferralAsync(referee.Id, "REF456", mall.Id);

        Assert.False(result.Success);
        Assert.Contains("من قبل", result.Error);
    }
}

// ──────────────────────────────────────────────────────────────────────────
//  LOYALTY EXPIRY TESTS
// ──────────────────────────────────────────────────────────────────────────
public class LoyaltyExpiryTests
{
    private readonly Mock<ILogger<LoyaltyService>> _log = new();

    [Fact]
    public async Task ProcessExpiry_ExpiredPoints_ShouldZeroBalance()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        // Create expired account
        var account = new Domain.Entities.Phase4.LoyaltyAccount
        {
            CustomerId     = customer.Id,
            MallId         = mall.Id,
            LifetimePoints = 500,
            RedeemedPoints = 0,
            Tier           = "Bronze",
            PointsExpireAt = DateTime.UtcNow.AddDays(-1), // expired yesterday
        };
        db.Set<Domain.Entities.Phase4.LoyaltyAccount>().Add(account);
        await db.SaveChangesAsync();

        var svc = new LoyaltyService(db, _log.Object);
        await svc.ProcessExpiryAsync();

        var updated = await db.Set<Domain.Entities.Phase4.LoyaltyAccount>()
            .FindAsync(account.Id);
        Assert.Equal(0, updated!.AvailablePoints);
        Assert.Null(updated.PointsExpireAt);

        // Verify expiry transaction was created
        var txn = await db.Set<Domain.Entities.Phase4.PointsTransaction>()
            .FirstAsync(t => t.AccountId == account.Id);
        Assert.Equal(Domain.Entities.Phase4.PointsSource.Expiry, txn.Source);
        Assert.Equal(-500, txn.Points);
    }

    [Fact]
    public async Task ProcessExpiry_ActivePoints_ShouldNotExpire()
    {
        using var db = TestDb.Create();
        var (customer, mall) = TestDb.Seed(db);

        var account = new Domain.Entities.Phase4.LoyaltyAccount
        {
            CustomerId     = customer.Id,
            MallId         = mall.Id,
            LifetimePoints = 300,
            RedeemedPoints = 0,
            Tier           = "Bronze",
            PointsExpireAt = DateTime.UtcNow.AddMonths(6), // not expired
        };
        db.Set<Domain.Entities.Phase4.LoyaltyAccount>().Add(account);
        await db.SaveChangesAsync();

        var svc = new LoyaltyService(db, _log.Object);
        await svc.ProcessExpiryAsync();

        var updated = await db.Set<Domain.Entities.Phase4.LoyaltyAccount>()
            .FindAsync(account.Id);
        Assert.Equal(300, updated!.AvailablePoints); // unchanged
    }
}
