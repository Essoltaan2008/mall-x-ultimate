namespace MesterX.Application.DTOs;

// ══════════════════════════════════════════════════════════════════════════
//  API RESPONSE — the foundation used by EVERY service return type
// ══════════════════════════════════════════════════════════════════════════
public class ApiResponse
{
    public bool    Success   { get; init; }
    public string? Error     { get; init; }
    public string? Message   { get; init; }
    public DateTime Timestamp{ get; init; } = DateTime.UtcNow;

    public static ApiResponse Ok(string? message = null) => new() { Success = true,  Message = message };
    public static ApiResponse Fail(string error)         => new() { Success = false, Error   = error   };
}

public class ApiResponse<T> : ApiResponse
{
    public T? Data { get; init; }

    public new static ApiResponse<T> Ok(T data, string? message = null) => new()
        { Success = true, Data = data, Message = message };
    public new static ApiResponse<T> Fail(string error) => new()
        { Success = false, Error = error };
}

public class PagedResponse<T>
{
    public bool     Success    { get; init; }
    public List<T>  Items      { get; init; } = [];
    public int      TotalCount { get; init; }
    public int      Page       { get; init; }
    public int      PageSize   { get; init; }
    public int      TotalPages => (int)Math.Ceiling((double)TotalCount / PageSize);
    public bool     HasNext    => Page < TotalPages;
    public string?  Error      { get; init; }

    public static PagedResponse<T> Ok(List<T> items, int total, int page, int size)
        => new() { Success = true, Items = items, TotalCount = total, Page = page, PageSize = size };
    public static PagedResponse<T> Fail(string error)
        => new() { Success = false, Error = error };
}
