using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using MesterX.Application.DTOs;
using MesterX.Domain.Entities.Mall;
using MesterX.Domain.Entities.Phase4;
using MesterX.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.IdentityModel.Tokens;

namespace MesterX.Application.Services;

public interface IMallCustomerAuthService
{
    Task<ApiResponse<CustomerTokenResponse>> RegisterAsync(
        CustomerRegisterRequest req, CancellationToken ct = default);
    Task<ApiResponse<CustomerTokenResponse>> LoginAsync(
        string email, string password, string mallSlug, CancellationToken ct = default);
    Task<ApiResponse<CustomerTokenResponse>> RefreshAsync(
        string refreshToken, CancellationToken ct = default);
    Task<ApiResponse<CustomerDto>> GetMeAsync(
        Guid customerId, CancellationToken ct = default);
    Task<ApiResponse> LogoutAsync(
        Guid customerId, string refreshToken, CancellationToken ct = default);
}

public class MallCustomerAuthService : IMallCustomerAuthService
{
    private readonly MesterXDbContext   _db;
    private readonly ILogger<MallCustomerAuthService> _log;
    private readonly IConfiguration?   _cfg;

    private const int MaxFailedAttempts   = 5;
    private const int LockoutMinutes      = 15;
    private const int AccessExpiryMins    = 60;
    private const int RefreshExpiryDays   = 30;
    private const int SignupBonusPts      = 50;

    public MallCustomerAuthService(
        MesterXDbContext db,
        ILogger<MallCustomerAuthService> log,
        IConfiguration? cfg = null)
    { _db = db; _log = log; _cfg = cfg; }

    // ──────────────────────────────────────────────────────────────────────
    //  REGISTER
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CustomerTokenResponse>> RegisterAsync(
        CustomerRegisterRequest req, CancellationToken ct = default)
    {
        // Resolve mall by slug
        var mall = await _db.Malls.AsNoTracking()
            .FirstOrDefaultAsync(m => m.Slug == req.MallSlug && m.IsActive, ct);
        if (mall == null)
            return ApiResponse<CustomerTokenResponse>.Fail("المول غير موجود.");

        // Duplicate email check
        var exists = await _db.MallCustomers.AnyAsync(
            c => c.Email == req.Email.ToLower() && c.MallId == mall.Id && !c.IsDeleted, ct);
        if (exists)
            return ApiResponse<CustomerTokenResponse>.Fail(
                "البريد الإلكتروني مسجل مسبقاً. حاول تسجيل الدخول.");

        // Create customer
        var customer = new MallCustomer
        {
            Id           = Guid.NewGuid(),
            MallId       = mall.Id,
            FirstName    = req.FirstName.Trim(),
            LastName     = req.LastName.Trim(),
            Email        = req.Email.ToLower().Trim(),
            Phone        = req.Phone?.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(req.Password),
            Tier         = CustomerTier.Bronze,
            IsActive     = true,
            CreatedAt    = DateTime.UtcNow,
            UpdatedAt    = DateTime.UtcNow,
        };
        _db.MallCustomers.Add(customer);

        // Create loyalty account with signup bonus
        var loyaltyAccount = new LoyaltyAccount
        {
            Id             = Guid.NewGuid(),
            CustomerId     = customer.Id,
            MallId         = mall.Id,
            LifetimePoints = SignupBonusPts,
            RedeemedPoints = 0,
            Tier           = "Bronze",
            PointsExpireAt = DateTime.UtcNow.AddMonths(12),
        };
        _db.Set<LoyaltyAccount>().Add(loyaltyAccount);

        // Log signup bonus transaction
        _db.Set<PointsTransaction>().Add(new PointsTransaction
        {
            Id          = Guid.NewGuid(),
            AccountId   = loyaltyAccount.Id,
            Source      = PointsSource.Signup,
            Points      = SignupBonusPts,
            BalanceBefore= 0,
            BalanceAfter = SignupBonusPts,
            Description = "مكافأة التسجيل — أهلاً وسهلاً بك!",
            CreatedAt   = DateTime.UtcNow,
        });

        // Update customer loyalty points
        customer.LoyaltyPoints = SignupBonusPts;

        await _db.SaveChangesAsync(ct);

        // Apply referral code if provided
        if (!string.IsNullOrEmpty(req.ReferralCode))
        {
            try { await ApplyReferralAsync(customer, req.ReferralCode, mall.Id, ct); }
            catch (Exception ex)
            { _log.LogWarning(ex, "Referral code {Code} failed silently", req.ReferralCode); }
        }

        _log.LogInformation("New customer registered: {Email} in {Mall}", customer.Email, mall.Name);
        return await GenerateTokenResponseAsync(customer, mall.Id, ct);
    }

    // ──────────────────────────────────────────────────────────────────────
    //  LOGIN
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CustomerTokenResponse>> LoginAsync(
        string email, string password, string mallSlug, CancellationToken ct = default)
    {
        var mall = await _db.Malls.AsNoTracking()
            .FirstOrDefaultAsync(m => m.Slug == mallSlug && m.IsActive, ct);
        if (mall == null)
            return ApiResponse<CustomerTokenResponse>.Fail("المول غير موجود.");

        var customer = await _db.MallCustomers
            .FirstOrDefaultAsync(c =>
                c.Email == email.ToLower() && c.MallId == mall.Id && !c.IsDeleted, ct);

        if (customer == null)
            return ApiResponse<CustomerTokenResponse>.Fail("بريد إلكتروني أو كلمة مرور خاطئة.");

        // Lockout check
        if (customer.LockoutUntil.HasValue && customer.LockoutUntil > DateTime.UtcNow)
        {
            var mins = (int)(customer.LockoutUntil.Value - DateTime.UtcNow).TotalMinutes;
            return ApiResponse<CustomerTokenResponse>.Fail(
                $"الحساب مقفل مؤقتاً. حاول بعد {mins} دقيقة.");
        }

        // Password check
        if (!BCrypt.Net.BCrypt.Verify(password, customer.PasswordHash))
        {
            customer.FailedLoginCount++;
            if (customer.FailedLoginCount >= MaxFailedAttempts)
            {
                customer.LockoutUntil = DateTime.UtcNow.AddMinutes(LockoutMinutes);
                customer.FailedLoginCount = 0;
                await _db.SaveChangesAsync(ct);
                return ApiResponse<CustomerTokenResponse>.Fail(
                    $"تم قفل الحساب لمدة {LockoutMinutes} دقيقة بسبب كثرة المحاولات الخاطئة.");
            }
            await _db.SaveChangesAsync(ct);
            return ApiResponse<CustomerTokenResponse>.Fail("بريد إلكتروني أو كلمة مرور خاطئة.");
        }

        // Reset failed attempts
        customer.FailedLoginCount = 0;
        customer.LockoutUntil     = null;
        customer.LastLoginAt      = DateTime.UtcNow;
        customer.UpdatedAt        = DateTime.UtcNow;
        await _db.SaveChangesAsync(ct);

        _log.LogInformation("Customer login: {Email}", customer.Email);
        return await GenerateTokenResponseAsync(customer, mall.Id, ct);
    }

    // ──────────────────────────────────────────────────────────────────────
    //  REFRESH TOKEN
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CustomerTokenResponse>> RefreshAsync(
        string refreshToken, CancellationToken ct = default)
    {
        var stored = await _db.Set<CustomerRefreshToken>()
            .Include(r => r.Customer)
            .FirstOrDefaultAsync(r =>
                r.Token == refreshToken && r.ExpiresAt > DateTime.UtcNow && !r.IsRevoked, ct);

        if (stored == null)
            return ApiResponse<CustomerTokenResponse>.Fail("رمز التحديث غير صالح أو منتهي.");

        // Revoke old token (rotation)
        stored.IsRevoked = true;

        var mall = await _db.Malls.AsNoTracking()
            .FirstOrDefaultAsync(m => m.Id == stored.Customer.MallId, ct);

        await _db.SaveChangesAsync(ct);
        return await GenerateTokenResponseAsync(stored.Customer, stored.Customer.MallId, ct);
    }

    // ──────────────────────────────────────────────────────────────────────
    //  GET ME
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse<CustomerDto>> GetMeAsync(
        Guid customerId, CancellationToken ct = default)
    {
        var c = await _db.MallCustomers.AsNoTracking()
            .FirstOrDefaultAsync(x => x.Id == customerId && !x.IsDeleted, ct);
        if (c == null)
            return ApiResponse<CustomerDto>.Fail("العميل غير موجود.");

        return ApiResponse<CustomerDto>.Ok(ToDto(c));
    }

    // ──────────────────────────────────────────────────────────────────────
    //  LOGOUT
    // ──────────────────────────────────────────────────────────────────────
    public async Task<ApiResponse> LogoutAsync(
        Guid customerId, string refreshToken, CancellationToken ct = default)
    {
        var token = await _db.Set<CustomerRefreshToken>()
            .FirstOrDefaultAsync(r =>
                r.CustomerId == customerId && r.Token == refreshToken, ct);

        if (token != null)
        {
            token.IsRevoked = true;
            await _db.SaveChangesAsync(ct);
        }

        return ApiResponse.Ok("تم تسجيل الخروج.");
    }

    // ──────────────────────────────────────────────────────────────────────
    //  TOKEN GENERATION
    // ──────────────────────────────────────────────────────────────────────
    private async Task<ApiResponse<CustomerTokenResponse>> GenerateTokenResponseAsync(
        MallCustomer customer, Guid mallId, CancellationToken ct)
    {
        var (access, refresh) = GenerateTokens(customer, mallId);

        // Persist refresh token
        _db.Set<CustomerRefreshToken>().Add(new CustomerRefreshToken
        {
            Id         = Guid.NewGuid(),
            CustomerId = customer.Id,
            Token      = refresh,
            ExpiresAt  = DateTime.UtcNow.AddDays(RefreshExpiryDays),
            CreatedAt  = DateTime.UtcNow,
        });
        await _db.SaveChangesAsync(ct);

        return ApiResponse<CustomerTokenResponse>.Ok(new CustomerTokenResponse
        {
            AccessToken  = access,
            RefreshToken = refresh,
            ExpiresIn    = AccessExpiryMins * 60,
            Customer     = ToDto(customer),
        });
    }

    private (string access, string refresh) GenerateTokens(MallCustomer c, Guid mallId)
    {
        var secret  = _cfg?["Jwt:Secret"] ?? "dev-secret-must-be-at-least-64-chars-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";
        var issuer  = _cfg?["Jwt:Issuer"]   ?? "mallxpro";
        var audience= _cfg?["Jwt:Audience"] ?? "mallxpro-client";
        var key     = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secret));
        var creds   = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(JwtRegisteredClaimNames.Sub,   c.Id.ToString()),
            new Claim(JwtRegisteredClaimNames.Email, c.Email),
            new Claim("mall_id",     mallId.ToString()),
            new Claim("customer_id", c.Id.ToString()),
            new Claim("tier",        c.Tier.ToString()),
            new Claim(ClaimTypes.Role, "Customer"),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString()),
        };

        var token = new JwtSecurityToken(
            issuer:   issuer,
            audience: audience,
            claims:   claims,
            expires:  DateTime.UtcNow.AddMinutes(AccessExpiryMins),
            signingCredentials: creds);

        var accessToken  = new JwtSecurityTokenHandler().WriteToken(token);
        var refreshToken = Convert.ToBase64String(RandomNumberGenerator.GetBytes(64));
        return (accessToken, refreshToken);
    }

    private static CustomerDto ToDto(MallCustomer c) => new()
    {
        Id           = c.Id,
        FirstName    = c.FirstName,
        LastName     = c.LastName,
        Email        = c.Email,
        Phone        = c.Phone,
        Tier         = c.Tier.ToString(),
        LoyaltyPoints= c.LoyaltyPoints,
        MallId       = c.MallId,
        CreatedAt    = c.CreatedAt,
    };

    private async Task ApplyReferralAsync(
        MallCustomer referee, string code, Guid mallId, CancellationToken ct)
    {
        var refCode = await _db.Set<Domain.Entities.Phase9.ReferralCode>()
            .FirstOrDefaultAsync(r => r.Code == code && r.MallId == mallId, ct);
        if (refCode == null || refCode.CustomerId == referee.Id) return;

        var program = await _db.Set<Domain.Entities.Phase9.ReferralProgram>()
            .FirstOrDefaultAsync(p => p.MallId == mallId && p.IsActive, ct);
        if (program == null) return;

        // Award referee bonus
        referee.LoyaltyPoints += program.RefereeRewardPts;
        refCode.UsesCount++;
        await _db.SaveChangesAsync(ct);
    }
}

// ── Entities needed by AuthService ────────────────────────────────────────
namespace MesterX.Domain.Entities.Mall
{
    public class CustomerRefreshToken
    {
        public Guid     Id         { get; set; } = Guid.NewGuid();
        public Guid     CustomerId { get; set; }
        public string   Token      { get; set; } = string.Empty;
        public bool     IsRevoked  { get; set; } = false;
        public DateTime ExpiresAt  { get; set; }
        public DateTime CreatedAt  { get; set; } = DateTime.UtcNow;
        public virtual MallCustomer Customer { get; set; } = null!;
    }
}

// ── IJwtHelper interface (for tests) ──────────────────────────────────────
namespace MesterX.Application.Services
{
    public interface IJwtHelper
    {
        (string token, string refresh) GenerateTokens(MallCustomer c, Guid mallId);
    }
}
