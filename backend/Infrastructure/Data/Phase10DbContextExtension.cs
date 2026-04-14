using MesterX.Application.Services.Phase10;
using MesterX.Application.Services.Phase9;
using MesterX.API.Middleware;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace MesterX.Infrastructure.Data;

// ══════════════════════════════════════════════════════════════════════════
//  DBCONTEXT EXTENSION — Phase 10 + Phase 9 Entities
//  Paste these OnModelCreating calls into MesterXDbContext
// ══════════════════════════════════════════════════════════════════════════

/*  ADD TO MesterXDbContext.cs:
 *
 *  public DbSet<CustomerNotification>    CustomerNotifications    { get; set; }
 *  public DbSet<ProductReview>           ProductReviews           { get; set; }
 *  public DbSet<ProductRatingSummary>    ProductRatingSummaries   { get; set; }
 *  public DbSet<SavedOrder>              SavedOrders              { get; set; }
 *  public DbSet<CustomerActivity>        CustomerActivities       { get; set; }
 *  public DbSet<ApiRequestLog>           ApiRequestLogs           { get; set; }
 *  public DbSet<CustomerWallet>          CustomerWallets          { get; set; }
 *  public DbSet<WalletTransaction>       WalletTransactions       { get; set; }
 *  public DbSet<ReferralProgram>         ReferralPrograms         { get; set; }
 *  public DbSet<ReferralCode>            ReferralCodes            { get; set; }
 *  public DbSet<ReferralUse>             ReferralUses             { get; set; }
 *  public DbSet<WhatsappMessage>         WhatsappMessages         { get; set; }
 *  public DbSet<StoreSubscriptionEntity> StoreSubscriptions       { get; set; }
 *  public DbSet<PlatformSetting>         PlatformSettings         { get; set; }
 */

public static class Phase10DbContextExtension
{
    public static ModelBuilder ConfigurePhase10Entities(this ModelBuilder mb)
    {
        // ─── Customer Notifications ────────────────────────────────────
        mb.Entity<CustomerNotification>(e =>
        {
            e.ToTable("customer_notifications");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).HasColumnName("id");
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.Category).HasColumnName("category")
                .HasConversion<string>();
            e.Property(x => x.Title).HasColumnName("title").HasMaxLength(200).IsRequired();
            e.Property(x => x.Body).HasColumnName("body").IsRequired();
            e.Property(x => x.ImageUrl).HasColumnName("image_url");
            e.Property(x => x.ActionType).HasColumnName("action_type").HasMaxLength(50);
            e.Property(x => x.ActionId).HasColumnName("action_id").HasMaxLength(100);
            e.Property(x => x.IsRead).HasColumnName("is_read").HasDefaultValue(false);
            e.Property(x => x.ReadAt).HasColumnName("read_at");
            e.Property(x => x.CreatedAt).HasColumnName("created_at")
                .HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.CustomerId, x.IsRead, x.CreatedAt })
                .HasDatabaseName("idx_notif_customer");
        });

        // ─── Product Reviews ───────────────────────────────────────────
        mb.Entity<ProductReview>(e =>
        {
            e.ToTable("product_reviews");
            e.HasKey(x => x.Id);
            e.Property(x => x.ProductId).HasColumnName("product_id").IsRequired();
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallOrderId).HasColumnName("mall_order_id");
            e.Property(x => x.Stars).HasColumnName("stars").IsRequired();
            e.Property(x => x.Title).HasColumnName("title").HasMaxLength(100);
            e.Property(x => x.Body).HasColumnName("body");
            e.Property(x => x.Images).HasColumnName("images")
                .HasConversion(
                    v => string.Join(",", v ?? Array.Empty<string>()),
                    v => v.Split(",", StringSplitOptions.RemoveEmptyEntries));
            e.Property(x => x.IsVerifiedPurchase).HasColumnName("is_verified_purchase")
                .HasDefaultValue(false);
            e.Property(x => x.HelpfulCount).HasColumnName("helpful_count").HasDefaultValue(0);
            e.Property(x => x.IsPublished).HasColumnName("is_published").HasDefaultValue(true);
            e.Property(x => x.StoreReply).HasColumnName("store_reply");
            e.Property(x => x.StoreRepliedAt).HasColumnName("store_replied_at");
            e.Property(x => x.CreatedAt).HasColumnName("created_at")
                .HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.ProductId, x.IsPublished, x.CreatedAt })
                .HasDatabaseName("idx_product_reviews_product");
        });

        // ─── Product Rating Summary ────────────────────────────────────
        mb.Entity<ProductRatingSummary>(e =>
        {
            e.ToTable("product_rating_summary");
            e.HasKey(x => x.ProductId);
            e.Property(x => x.ProductId).HasColumnName("product_id");
            e.Property(x => x.AvgStars).HasColumnName("avg_stars").HasPrecision(3, 2);
            e.Property(x => x.TotalReviews).HasColumnName("total_reviews");
            e.Property(x => x.FiveStar).HasColumnName("five_star");
            e.Property(x => x.FourStar).HasColumnName("four_star");
            e.Property(x => x.ThreeStar).HasColumnName("three_star");
            e.Property(x => x.TwoStar).HasColumnName("two_star");
            e.Property(x => x.OneStar).HasColumnName("one_star");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at")
                .HasDefaultValueSql("NOW()");
        });

        // ─── Saved Orders ──────────────────────────────────────────────
        mb.Entity<SavedOrder>(e =>
        {
            e.ToTable("saved_orders");
            e.HasKey(x => x.Id);
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
            e.Property(x => x.ItemsJson).HasColumnName("items").IsRequired();
            e.Property(x => x.TotalEst).HasColumnName("total_est").HasPrecision(12, 2);
            e.Property(x => x.LastOrdered).HasColumnName("last_ordered");
            e.Property(x => x.OrderCount).HasColumnName("order_count").HasDefaultValue(0);
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.CustomerId, x.IsActive })
                .HasDatabaseName("idx_saved_orders");
        });

        // ─── Customer Wallet ───────────────────────────────────────────
        mb.Entity<CustomerWallet>(e =>
        {
            e.ToTable("customer_wallets");
            e.HasKey(x => x.Id);
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.Balance).HasColumnName("balance").HasPrecision(14, 2);
            e.Property(x => x.TotalToppedUp).HasColumnName("total_topped_up").HasPrecision(14, 2);
            e.Property(x => x.TotalSpent).HasColumnName("total_spent").HasPrecision(14, 2);
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => new { x.CustomerId, x.MallId })
                .IsUnique().HasDatabaseName("idx_wallet_customer_mall_unique");
        });

        // ─── Wallet Transactions ───────────────────────────────────────
        mb.Entity<WalletTransaction>(e =>
        {
            e.ToTable("wallet_transactions");
            e.HasKey(x => x.Id);
            e.Property(x => x.WalletId).HasColumnName("wallet_id").IsRequired();
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallOrderId).HasColumnName("mall_order_id");
            e.Property(x => x.Type).HasColumnName("type")
                .HasConversion<string>();
            e.Property(x => x.Status).HasColumnName("status")
                .HasConversion<string>().HasDefaultValue(WalletTxnStatus.Completed);
            e.Property(x => x.Amount).HasColumnName("amount").HasPrecision(12, 2);
            e.Property(x => x.BalanceBefore).HasColumnName("balance_before").HasPrecision(12, 2);
            e.Property(x => x.BalanceAfter).HasColumnName("balance_after").HasPrecision(12, 2);
            e.Property(x => x.Reference).HasColumnName("reference").HasMaxLength(100);
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasOne(x => x.Wallet).WithMany(w => w.Transactions)
                .HasForeignKey(x => x.WalletId).OnDelete(DeleteBehavior.Cascade);

            e.HasIndex(x => new { x.WalletId, x.CreatedAt })
                .HasDatabaseName("idx_wallet_txn_wallet_date");
        });

        // ─── Referral Program ──────────────────────────────────────────
        mb.Entity<ReferralProgram>(e =>
        {
            e.ToTable("referral_programs");
            e.HasKey(x => x.Id);
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.Name).HasColumnName("name").HasMaxLength(100).IsRequired();
            e.Property(x => x.ReferrerRewardPts).HasColumnName("referrer_reward_pts").HasDefaultValue(200);
            e.Property(x => x.RefereeRewardPts).HasColumnName("referee_reward_pts").HasDefaultValue(100);
            e.Property(x => x.ReferrerWalletEgp).HasColumnName("referrer_wallet_egp").HasPrecision(8, 2);
            e.Property(x => x.RefereeDiscountPct).HasColumnName("referee_discount_pct").HasPrecision(5, 2);
            e.Property(x => x.MinOrderToUnlock).HasColumnName("min_order_to_unlock").HasPrecision(12, 2);
            e.Property(x => x.IsActive).HasColumnName("is_active").HasDefaultValue(true);
            e.Property(x => x.ValidFrom).HasColumnName("valid_from").HasDefaultValueSql("NOW()");
            e.Property(x => x.ValidTo).HasColumnName("valid_to");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
        });

        // ─── Referral Code ─────────────────────────────────────────────
        mb.Entity<ReferralCode>(e =>
        {
            e.ToTable("referral_codes");
            e.HasKey(x => x.Id);
            e.Property(x => x.CustomerId).HasColumnName("customer_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.Code).HasColumnName("code").HasMaxLength(20).IsRequired();
            e.Property(x => x.UsesCount).HasColumnName("uses_count").HasDefaultValue(0);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => x.Code).IsUnique().HasDatabaseName("idx_referral_codes_code");
            e.HasIndex(x => new { x.CustomerId, x.MallId }).IsUnique();
        });

        // ─── Referral Use ──────────────────────────────────────────────
        mb.Entity<ReferralUse>(e =>
        {
            e.ToTable("referral_uses");
            e.HasKey(x => x.Id);
            e.Property(x => x.ProgramId).HasColumnName("program_id").IsRequired();
            e.Property(x => x.ReferrerId).HasColumnName("referrer_id").IsRequired();
            e.Property(x => x.RefereeId).HasColumnName("referee_id").IsRequired();
            e.Property(x => x.MallOrderId).HasColumnName("mall_order_id");
            e.Property(x => x.ReferrerRewarded).HasColumnName("referrer_rewarded").HasDefaultValue(false);
            e.Property(x => x.RefereeRewarded).HasColumnName("referee_rewarded").HasDefaultValue(false);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasOne<ReferralProgram>().WithMany()
                .HasForeignKey(x => x.ProgramId);
            e.HasIndex(x => new { x.RefereeId, x.ProgramId })
                .IsUnique().HasDatabaseName("idx_referee_program_unique");
        });

        // ─── WhatsApp Messages ─────────────────────────────────────────
        mb.Entity<WhatsappMessage>(e =>
        {
            e.ToTable("whatsapp_messages");
            e.HasKey(x => x.Id);
            e.Property(x => x.Phone).HasColumnName("phone").HasMaxLength(20).IsRequired();
            e.Property(x => x.Template).HasColumnName("template").HasMaxLength(100).IsRequired();
            e.Property(x => x.VariablesJson).HasColumnName("variables");
            e.Property(x => x.Status).HasColumnName("status")
                .HasConversion<string>().HasDefaultValue(WhatsappStatus.Queued);
            e.Property(x => x.ProviderMsgId).HasColumnName("provider_msg_id").HasMaxLength(100);
            e.Property(x => x.ErrorMessage).HasColumnName("error_message");
            e.Property(x => x.SentAt).HasColumnName("sent_at");
            e.Property(x => x.DeliveredAt).HasColumnName("delivered_at");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
        });

        // ─── Platform Settings ─────────────────────────────────────────
        mb.Entity<PlatformSetting>(e =>
        {
            e.ToTable("platform_settings");
            e.HasKey(x => x.Key);
            e.Property(x => x.Key).HasColumnName("key").HasMaxLength(100).IsRequired();
            e.Property(x => x.Value).HasColumnName("value").IsRequired();
            e.Property(x => x.Description).HasColumnName("description");
            e.Property(x => x.UpdatedAt).HasColumnName("updated_at").HasDefaultValueSql("NOW()");
        });

        // ─── Store Subscriptions ───────────────────────────────────────
        mb.Entity<StoreSubscriptionEntity>(e =>
        {
            e.ToTable("store_subscriptions");
            e.HasKey(x => x.Id);
            e.Property(x => x.StoreId).HasColumnName("store_id").IsRequired();
            e.Property(x => x.MallId).HasColumnName("mall_id").IsRequired();
            e.Property(x => x.PlanId).HasColumnName("plan_id").IsRequired();
            e.Property(x => x.BillingCycle).HasColumnName("billing_cycle")
                .HasConversion<string>().HasDefaultValue(SubBillingCycle.Monthly);
            e.Property(x => x.Status).HasColumnName("status")
                .HasConversion<string>().HasDefaultValue(SubStatus.Trial);
            e.Property(x => x.Amount).HasColumnName("amount").HasPrecision(12, 2);
            e.Property(x => x.TrialEndsAt).HasColumnName("trial_ends_at");
            e.Property(x => x.CurrentPeriodStart).HasColumnName("current_period_start");
            e.Property(x => x.CurrentPeriodEnd).HasColumnName("current_period_end");
            e.Property(x => x.NextBillingAt).HasColumnName("next_billing_at");
            e.Property(x => x.AutoRenew).HasColumnName("auto_renew").HasDefaultValue(true);
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");

            e.HasIndex(x => x.StoreId).IsUnique();
        });

        // ─── API Request Log ───────────────────────────────────────────
        mb.Entity<ApiRequestLog>(e =>
        {
            e.ToTable("api_request_log");
            e.HasKey(x => x.Id);
            e.Property(x => x.Endpoint).HasColumnName("endpoint").HasMaxLength(200);
            e.Property(x => x.Method).HasColumnName("method").HasMaxLength(10);
            e.Property(x => x.StatusCode).HasColumnName("status_code");
            e.Property(x => x.DurationMs).HasColumnName("duration_ms");
            e.Property(x => x.CustomerId).HasColumnName("customer_id");
            e.Property(x => x.IpAddress).HasColumnName("ip_address").HasMaxLength(50);
            e.Property(x => x.UserAgent).HasColumnName("user_agent").HasMaxLength(250);
            e.Property(x => x.ErrorMsg).HasColumnName("error_msg");
            e.Property(x => x.CreatedAt).HasColumnName("created_at").HasDefaultValueSql("NOW()");
        });

        return mb;
    }
}
