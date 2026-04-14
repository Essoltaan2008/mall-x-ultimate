using MesterX.Domain.Entities.Mall;
using MesterX.Domain.Entities.Phase2;
using MesterX.Domain.Entities.Phase3;
using MesterX.Domain.Entities.Phase4;
using Microsoft.EntityFrameworkCore;

namespace MesterX.Infrastructure.Data;

// ══════════════════════════════════════════════════════════════════════════
//  MALLX DB CONTEXT EXTENSION — Phase 1 to 6 Entity Mappings
//  Call this from MesterXDbContext.OnModelCreating:
//    modelBuilder.ConfigureMallXEntities();
// ══════════════════════════════════════════════════════════════════════════

/*  ADD THESE DbSet PROPERTIES TO MesterXDbContext:
 *
 *  // Phase 1 — Mall core
 *  public DbSet<Mall>              Malls           { get; set; }
 *  public DbSet<MallCustomer>      MallCustomers   { get; set; }
 *  public DbSet<Cart>              Carts           { get; set; }
 *  public DbSet<CartItem>          CartItems       { get; set; }
 *  public DbSet<MallOrder>         MallOrders      { get; set; }
 *  public DbSet<StoreOrder>        StoreOrders     { get; set; }
 *  public DbSet<OrderStatusHistory>OrderStatusHistories { get; set; }
 *
 *  // Phase 2
 *  public DbSet<PaymentTransaction>   PaymentTransactions   { get; set; }
 *  public DbSet<CommissionSettlement> CommissionSettlements { get; set; }
 *  public DbSet<DeliveryZone>         DeliveryZones         { get; set; }
 *  public DbSet<Driver>               Drivers               { get; set; }
 *
 *  // Phase 3
 *  public DbSet<MenuCategory>         MenuCategories        { get; set; }
 *  public DbSet<MenuItem>             MenuItems             { get; set; }
 *  public DbSet<QueueTicket>          QueueTickets          { get; set; }
 *  public DbSet<ServiceStaff>         ServiceStaff          { get; set; }
 *  public DbSet<Service>              Services              { get; set; }
 *  public DbSet<Booking>              Bookings              { get; set; }
 *  public DbSet<Rating>               Ratings               { get; set; }
 *  public DbSet<StoreRatingSummary>   StoreRatingSummaries  { get; set; }
 *
 *  // Phase 4
 *  public DbSet<LoyaltyAccount>       LoyaltyAccounts       { get; set; }
 *  public DbSet<PointsTransaction>    PointsTransactions    { get; set; }
 *  public DbSet<Coupon>               Coupons               { get; set; }
 *  public DbSet<CouponUse>            CouponUses            { get; set; }
 *  public DbSet<FlashSale>            FlashSales            { get; set; }
 *  public DbSet<CustomerDevice>       CustomerDevices       { get; set; }
 *  public DbSet<NotificationCampaign> NotificationCampaigns { get; set; }
 *  public DbSet<GeoFenceTrigger>      GeoFenceTriggers      { get; set; }
 *
 *  // Phase 6
 *  public DbSet<MallFloor>            MallFloors            { get; set; }
 *  public DbSet<StoreLocation>        StoreLocations        { get; set; }
 *  public DbSet<MapAmenity>           MapAmenities          { get; set; }
 *  public DbSet<TrendingSearch>       TrendingSearches      { get; set; }
 */

public static class MallXDbContextExtension
{
    public static ModelBuilder ConfigureMallXEntities(this ModelBuilder mb)
    {
        // ─── MALL ─────────────────────────────────────────────────────
        mb.Entity<Mall>(e =>
        {
            e.ToTable("malls");
            e.HasKey(x => x.Id);
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
            e.Property(x => x.NameAr).HasColumnName("name_ar").HasMaxLength(100);
            e.Property(x => x.Slug).HasColumnName("slug").HasMaxLength(50).IsRequired();
            e.Property(x => x.Address).HasColumnName("address");
            e.Property(x => x.GeoLat).HasColumnName("geo_lat").HasPrecision(9, 6);
            e.Property(x => x.GeoLng).HasColumnName("geo_lng").HasPrecision(9, 6);
            e.Property(x => x.GeoRadiusM).HasColumnName("geo_radius_m").HasDefaultValue(300);
            e.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(20);
            e.Property(x => x.Email).HasColumnName("email").HasMaxLength(100);
            e.Property(x => x.LogoUrl).HasColumnName("logo_url");
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");
            e.HasIndex(x => x.Slug).IsUnique().HasDatabaseName("idx_malls_slug");
        });

        // ─── MALL CUSTOMER ─────────────────────────────────────────────
        mb.Entity<MallCustomer>(e =>
        {
            e.ToTable("mall_customers");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.FirstName).HasColumnName("first_name").HasMaxLength(50).IsRequired();
            e.Property(x => x.LastName).HasColumnName("last_name").HasMaxLength(50).IsRequired();
            e.Property(x => x.Email).HasColumnName("email").HasMaxLength(150).IsRequired();
            e.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(20);
            e.Property(x => x.PasswordHash).HasColumnName("password_hash").IsRequired();
            e.Property(x => x.AvatarUrl).HasColumnName("avatar_url");
            e.Property(x => x.Tier).HasColumnName("tier")
                .HasConversion<string>().HasDefaultValue(CustomerTier.Bronze);
            e.Property(x => x.LoyaltyPoints).HasColumnName("loyalty_points").HasDefaultValue(0);
            e.Property(x => x.FailedLoginCount).HasColumnName("failed_login_count").HasDefaultValue(0);
            e.Property(x => x.LockoutUntil).HasColumnName("lockout_until");
            e.Property(x => x.LastLoginAt).HasColumnName("last_login_at");
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.IsDeleted).HasColumnName("is_deleted").HasDefaultValue(false);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => x.Email).IsUnique().HasDatabaseName("idx_customers_email_unique")
                .HasFilter("is_deleted = false");
            e.HasIndex(x => new { x.MallId, x.Tier }).HasDatabaseName("idx_customers_mall_tier");
            e.HasIndex(x => x.Phone).HasDatabaseName("idx_customers_phone")
                .HasFilter("phone IS NOT NULL");
        });

        // ─── CART ──────────────────────────────────────────────────────
        mb.Entity<Cart>(e =>
        {
            e.ToTable("carts");
            e.HasKey(x => x.Id);
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => x.CustomerId).HasDatabaseName("idx_carts_customer");
            e.HasMany(x => x.Items).WithOne().HasForeignKey(i => i.CartId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        mb.Entity<CartItem>(e =>
        {
            e.ToTable("cart_items");
            e.HasKey(x => x.Id);
            e.Property(x => x.CartId).HasColumnName("cart_id").IsRequired();
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.ProductId).HasColumnName("product_id").IsRequired();
            e.Property(x => x.ProductName).HasColumnName("product_name").HasMaxLength(200);
            e.Property(x => x.Quantity).HasColumnName("quantity").IsRequired();
            e.Property(x => x.UnitPrice).HasColumnName("unit_price").HasPrecision(12, 2);
            e.Property(x => x.Total).HasColumnName("total").HasPrecision(12, 2);
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.StoreOrderId).HasColumnName("store_order_id");

            e.HasIndex(x => x.CartId).HasDatabaseName("idx_cart_items_cart");
        });

        // ─── MALL ORDER ────────────────────────────────────────────────
        mb.Entity<MallOrder>(e =>
        {
            e.ToTable("mall_orders");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.OrderNumber).HasColumnName("order_number").HasMaxLength(30).IsRequired();
            e.Property(x => x.Status).HasColumnName("status")
                .HasConversion<string>().HasDefaultValue(MallOrderStatus.Placed);
            e.Property(x => x.FulfillmentType).HasColumnName("fulfillment_type").HasConversion<string>();
            e.Property(x => x.PaymentMethod).HasColumnName("payment_method").HasConversion<string>();
            e.Property(x => x.Subtotal).HasColumnName("subtotal").HasPrecision(14, 2);
            e.Property(x => x.DeliveryFee).HasColumnName("delivery_fee").HasPrecision(10, 2);
            e.Property(x => x.DiscountAmount).HasColumnName("discount_amount").HasPrecision(10, 2).HasDefaultValue(0);
            e.Property(x => x.Total).HasColumnName("total").HasPrecision(14, 2);
            e.Property(x => x.DeliveryAddress).HasColumnName("delivery_address");
            e.Property(x => x.DeliveryLat).HasColumnName("delivery_lat").HasPrecision(9, 6);
            e.Property(x => x.DeliveryLng).HasColumnName("delivery_lng").HasPrecision(9, 6);
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.PlacedAt).HasColumnName("placed_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.DeliveredAt).HasColumnName("delivered_at");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasOne(x => x.Customer).WithMany()
                .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Restrict);
            e.HasMany(x => x.StoreOrders).WithOne(s => s.MallOrder)
                .HasForeignKey(s => s.MallOrderId).OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.CustomerId, x.PlacedAt })
                .HasDatabaseName("idx_mall_orders_customer_date");
            e.HasIndex(x => x.OrderNumber).IsUnique().HasDatabaseName("idx_mall_orders_number");
            e.HasIndex(x => new { x.MallId, x.Status, x.PlacedAt })
                .HasDatabaseName("idx_mall_orders_mall_status");
        });

        // ─── STORE ORDER ───────────────────────────────────────────────
        mb.Entity<StoreOrder>(e =>
        {
            e.ToTable("store_orders");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallOrderId).HasColumnName("mall_order_id").IsRequired();
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.Status).HasColumnName("status")
                .HasConversion<string>().HasDefaultValue(StoreOrderStatus.Placed);
            e.Property(x => x.Subtotal).HasColumnName("subtotal").HasPrecision(12, 2);
            e.Property(x => x.CommissionAmt).HasColumnName("commission_amt").HasPrecision(10, 2);
            e.Property(x => x.CommissionRate).HasColumnName("commission_rate").HasPrecision(5, 4);
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasOne(x => x.Store).WithMany()
                .HasForeignKey(x => x.StoreId).OnDelete(DeleteBehavior.Restrict);
            e.HasMany(x => x.Items).WithOne()
                .HasForeignKey(i => i.StoreOrderId).OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => x.MallOrderId).HasDatabaseName("idx_store_orders_mall_order");
            e.HasIndex(x => new { x.StoreId, x.Status, x.CreatedAt })
                .HasDatabaseName("idx_store_orders_store_status");
        });

        // ─── LOYALTY ACCOUNT ───────────────────────────────────────────
        mb.Entity<LoyaltyAccount>(e =>
        {
            e.ToTable("loyalty_accounts");
            e.HasKey(x => x.Id);
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.LifetimePoints).HasColumnName("lifetime_points").HasDefaultValue(0);
            e.Property(x => x.RedeemedPoints).HasColumnName("redeemed_points").HasDefaultValue(0);
            e.Property(x => x.Tier).HasColumnName("tier").HasMaxLength(20).HasDefaultValue("Bronze");
            e.Property(x => x.PointsExpireAt).HasColumnName("points_expire_at");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasOne(x => x.Customer).WithMany()
                .HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.CustomerId, x.MallId }).IsUnique()
                .HasDatabaseName("idx_loyalty_accounts_customer_mall");
            e.HasIndex(x => x.PointsExpireAt).HasDatabaseName("idx_loyalty_expiry")
                .HasFilter("points_expire_at IS NOT NULL AND available_points > 0");
        });

        // ─── POINTS TRANSACTION ────────────────────────────────────────
        mb.Entity<PointsTransaction>(e =>
        {
            e.ToTable("points_transactions");
            e.HasKey(x => x.Id);
            e.Property(x => x.AccountId).HasColumnName("account_id").IsRequired();
            e.Property(x => x.MallOrderId).HasColumnName("mall_order_id");
            e.Property(x => x.Source).HasColumnName("source").HasConversion<string>();
            e.Property(x => x.Points).HasColumnName("points").IsRequired();
            e.Property(x => x.BalanceBefore).HasColumnName("balance_before");
            e.Property(x => x.BalanceAfter).HasColumnName("balance_after");
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasOne(x => x.Account).WithMany(a => a.Transactions)
                .HasForeignKey(x => x.AccountId).OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.AccountId, x.CreatedAt })
                .HasDatabaseName("idx_points_txn_account_date");
        });

        // ─── COUPON ────────────────────────────────────────────────────
        mb.Entity<Coupon>(e =>
        {
            e.ToTable("coupons");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.StoreId).HasColumnName("store_id");
            e.Property(x => x.Code).HasColumnName("code").HasMaxLength(30).IsRequired();
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.DiscountType).HasColumnName("discount_type").HasConversion<string>();
            e.Property(x => x.DiscountValue).HasColumnName("discount_value").HasPrecision(10, 2);
            e.Property(x => x.MinOrderValue).HasColumnName("min_order_value").HasPrecision(10, 2);
            e.Property(x => x.MaxUses).HasColumnName("max_uses");
            e.Property(x => x.UsesPerCustomer).HasColumnName("uses_per_customer").HasDefaultValue(1);
            e.Property(x => x.UsesCount).HasColumnName("uses_count").HasDefaultValue(0);
            e.Property(x => x.MinTier).HasColumnName("min_tier");
            e.Property(x => x.ValidFrom).HasColumnName("valid_from");
            e.Property(x => x.ValidTo).HasColumnName("valid_to").IsRequired();
            e.Property(x => x.Status).HasColumnName("status").HasConversion<string>()
                .HasDefaultValue(CouponStatus.Active);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.Code, x.Status, x.ValidTo })
                .HasDatabaseName("idx_coupons_code_valid");
        });

        // ─── FLASH SALE ────────────────────────────────────────────────
        mb.Entity<FlashSale>(e =>
        {
            e.ToTable("flash_sales");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.StoreId).HasColumnName("store_id");
            e.Property(x => x.Title).HasColumnName("title").HasMaxLength(150);
            e.Property(x => x.TitleAr).HasColumnName("title_ar").HasMaxLength(150).IsRequired();
            e.Property(x => x.OriginalPrice).HasColumnName("original_price").HasPrecision(12, 2);
            e.Property(x => x.FlashPrice).HasColumnName("flash_price").HasPrecision(12, 2);
            e.Property(x => x.QuantityLimit).HasColumnName("quantity_limit");
            e.Property(x => x.QuantitySold).HasColumnName("quantity_sold").HasDefaultValue(0);
            e.Property(x => x.StartsAt).HasColumnName("starts_at");
            e.Property(x => x.EndsAt).HasColumnName("ends_at").IsRequired();
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.MallId, x.IsActive, x.EndsAt })
                .HasDatabaseName("idx_flash_sales_live")
                .HasFilter("is_active = true");
        });

        // ─── MENU ITEM ─────────────────────────────────────────────────
        mb.Entity<MenuItem>(e =>
        {
            e.ToTable("menu_items");
            e.HasKey(x => x.Id);
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.CategoryId).HasColumnName("category_id");
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(150).IsRequired();
            e.Property(x => x.NameAr).HasColumnName("name_ar").HasMaxLength(150);
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.Price).HasColumnName("price").HasPrecision(10, 2).IsRequired();
            e.Property(x => x.PrepTimeMin).HasColumnName("prep_time_min").HasDefaultValue(15);
            e.Property(x => x.ImageUrl).HasColumnName("image_url");
            e.Property(x => x.IsAvailable).HasColumnName("is_available").HasDefaultValue(true);
            e.Property(x => x.IsFeatured).HasColumnName("is_featured").HasDefaultValue(false);
            e.Property(x => x.Tags).HasColumnName("tags")
                .HasConversion(
                    v => string.Join(",", v ?? Array.Empty<string>()),
                    v => v.Split(",", StringSplitOptions.RemoveEmptyEntries));
            e.Property(x => x.SortOrder).HasColumnName("sort_order").HasDefaultValue(0);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");
        });

        // ─── BOOKING ──────────────────────────────────────────────────
        mb.Entity<Booking>(e =>
        {
            e.ToTable("bookings");
            e.HasKey(x => x.Id);
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.ServiceId).HasColumnName("service_id").IsRequired();
            e.Property(x => x.StaffId).HasColumnName("staff_id");
            e.Property(x => x.BookingRef).HasColumnName("booking_ref").HasMaxLength(20).IsRequired();
            e.Property(x => x.BookedDate).HasColumnName("booked_date");
            e.Property(x => x.StartTime).HasColumnName("start_time");
            e.Property(x => x.EndTime).HasColumnName("end_time");
            e.Property(x => x.Status).HasColumnName("status").HasConversion<string>();
            e.Property(x => x.Price).HasColumnName("price").HasPrecision(10, 2);
            e.Property(x => x.Note).HasColumnName("note");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.StaffId, x.BookedDate, x.StartTime })
                .HasDatabaseName("idx_bookings_staff_date");
            e.HasIndex(x => new { x.StoreId, x.BookedDate })
                .HasDatabaseName("idx_bookings_store_today");
        });

        // ─── RATING ────────────────────────────────────────────────────
        mb.Entity<Rating>(e =>
        {
            e.ToTable("ratings");
            e.HasKey(x => x.Id);
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallOrderId).HasColumnName("mall_order_id");
            e.Property(x => x.StoreStars).HasColumnName("store_stars");
            e.Property(x => x.DeliveryStars).HasColumnName("delivery_stars");
            e.Property(x => x.ExperienceStars).HasColumnName("experience_stars");
            e.Property(x => x.Comment).HasColumnName("comment");
            e.Property(x => x.IsPublished).HasColumnName("is_published").HasDefaultValue(true);
            e.Property(x => x.StoreReply).HasColumnName("store_reply");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.StoreId, x.IsPublished, x.CreatedAt })
                .HasDatabaseName("idx_ratings_store_recent");
        });

        // ─── STORE RATING SUMMARY ──────────────────────────────────────
        mb.Entity<StoreRatingSummary>(e =>
        {
            e.ToTable("store_rating_summaries");
            e.HasKey(x => x.StoreId);
            e.Property(x => x.StoreId).HasColumnName("store_id");
            e.Property(x => x.AvgStars).HasColumnName("avg_stars").HasPrecision(3, 2);
            e.Property(x => x.TotalRatings).HasColumnName("total_ratings").HasDefaultValue(0);
            e.Property(x => x.FiveStar).HasColumnName("five_star").HasDefaultValue(0);
            e.Property(x => x.FourStar).HasColumnName("four_star").HasDefaultValue(0);
            e.Property(x => x.ThreeStar).HasColumnName("three_star").HasDefaultValue(0);
            e.Property(x => x.TwoStar).HasColumnName("two_star").HasDefaultValue(0);
            e.Property(x => x.OneStar).HasColumnName("one_star").HasDefaultValue(0);
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");
        });

        // ─── CUSTOMER DEVICE (FCM) ─────────────────────────────────────
        mb.Entity<CustomerDevice>(e =>
        {
            e.ToTable("customer_devices");
            e.HasKey(x => x.Id);
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.FcmToken).HasColumnName("fcm_token").IsRequired();
            e.Property(x => x.Platform).HasColumnName("platform").HasMaxLength(20);
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.CustomerId, x.IsActive })
                .HasDatabaseName("idx_devices_customer_active");
        });

        // ─── MALL FLOOR ────────────────────────────────────────────────
        mb.Entity<MallFloor>(e =>
        {
            e.ToTable("mall_floors");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.FloorNum).HasColumnName("floor_num").IsRequired();
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(50);
            e.Property(x => x.NameAr).HasColumnName("name_ar").HasMaxLength(50);
            e.Property(x => x.SvgMapUrl).HasColumnName("svg_map_url");
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
        });

        // ─── DRIVER ────────────────────────────────────────────────────
        mb.Entity<Driver>(e =>
        {
            e.ToTable("drivers");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
            e.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(20).IsRequired();
            e.Property(x => x.VehicleNumber).HasColumnName("vehicle_number").HasMaxLength(20);
            e.Property(x => x.CurrentLat).HasColumnName("current_lat").HasPrecision(9, 6);
            e.Property(x => x.CurrentLng).HasColumnName("current_lng").HasPrecision(9, 6);
            e.Property(x => x.IsAvailable).HasColumnName("is_available").HasDefaultValue(false);
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.LocationUpdatedAt).HasColumnName("location_updated_at");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
        });

        return mb;
    }
}

// ══════════════════════════════════════════════════════════════════════════
//  STORE RATING SUMMARY ENTITY (referenced in Phase 8 analytics)
// ══════════════════════════════════════════════════════════════════════════
namespace MesterX.Domain.Entities.Phase3
{
    public class StoreRatingSummary
    {
        public Guid    StoreId     { get; set; }
        public decimal AvgStars    { get; set; } = 0;
        public int     TotalRatings{ get; set; } = 0;
        public int     FiveStar    { get; set; } = 0;
        public int     FourStar    { get; set; } = 0;
        public int     ThreeStar   { get; set; } = 0;
        public int     TwoStar     { get; set; } = 0;
        public int     OneStar     { get; set; } = 0;
        public DateTime UpdatedAt  { get; set; } = DateTime.UtcNow;
    }
}
