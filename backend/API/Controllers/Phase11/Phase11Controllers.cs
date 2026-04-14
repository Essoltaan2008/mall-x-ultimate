using System.Security.Claims;
using MesterX.Application.Services.Phase11;
using MesterX.Application.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MesterX.API.Controllers.Phase11;

[Authorize(Roles = "PlatformOwner,CompanyOwner"), Route("api/mall/admin/export")]
[ApiController]
public class ExportController : ControllerBase
{
    private readonly IExportService _export;
    private Guid MallId => Guid.TryParse(
        User.FindFirstValue("mall_id"), out var id) ? id : Guid.Empty;

    public ExportController(IExportService export) => _export = export;

    [HttpGet("orders")]
    public async Task<IActionResult> Orders([FromQuery] string from,
        [FromQuery] string to, [FromQuery] string format = "csv", CancellationToken ct = default)
    {
        var result = await _export.ExportAsync(MallId,
            BuildReq("Orders", from, to, null, format), ct);
        if (!result.Success) return BadRequest(result);
        return File(result.Data!.Data, result.Data.ContentType, result.Data.FileName);
    }

    [HttpGet("commissions")]
    public async Task<IActionResult> Commissions([FromQuery] string from, [FromQuery] string to,
        [FromQuery] Guid? storeId = null, [FromQuery] string format = "csv", CancellationToken ct = default)
    {
        var result = await _export.ExportAsync(MallId,
            BuildReq("Commissions", from, to, storeId, format), ct);
        if (!result.Success) return BadRequest(result);
        return File(result.Data!.Data, result.Data.ContentType, result.Data.FileName);
    }

    [HttpGet("customers")]
    public async Task<IActionResult> Customers([FromQuery] string from,
        [FromQuery] string to, [FromQuery] string format = "csv", CancellationToken ct = default)
    {
        var result = await _export.ExportAsync(MallId,
            BuildReq("Customers", from, to, null, format), ct);
        if (!result.Success) return BadRequest(result);
        return File(result.Data!.Data, result.Data.ContentType, result.Data.FileName);
    }

    [HttpGet("loyalty")]
    public async Task<IActionResult> Loyalty([FromQuery] string from,
        [FromQuery] string to, [FromQuery] string format = "csv", CancellationToken ct = default)
    {
        var result = await _export.ExportAsync(MallId,
            BuildReq("Loyalty", from, to, null, format), ct);
        if (!result.Success) return BadRequest(result);
        return File(result.Data!.Data, result.Data.ContentType, result.Data.FileName);
    }

    [HttpGet("products")]
    public async Task<IActionResult> Products([FromQuery] Guid? storeId = null,
        [FromQuery] string format = "csv", CancellationToken ct = default)
    {
        var now = DateTime.UtcNow;
        var result = await _export.ExportAsync(MallId,
            new ExportRequest("Products", now.AddYears(-1), now, storeId, format), ct);
        if (!result.Success) return BadRequest(result);
        return File(result.Data!.Data, result.Data.ContentType, result.Data.FileName);
    }

    private static ExportRequest BuildReq(string type, string from, string to, Guid? store, string fmt)
        => new(type,
            DateTime.TryParse(from, out var f) ? f : DateTime.UtcNow.AddMonths(-1),
            DateTime.TryParse(to,   out var t) ? t : DateTime.UtcNow,
            store, fmt);
}
