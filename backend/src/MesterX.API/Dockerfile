# ═══════════════════════════════════════════════════════════════════════════
#  MallX Backend Dockerfile
#  Multi-stage build: SDK → Build → Publish → Runtime
# ═══════════════════════════════════════════════════════════════════════════

# ── Stage 1: Restore & Build ─────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:8.0-alpine AS build
WORKDIR /src

# Copy solution + project files first (cache layer for restore)
COPY ["src/MesterX.API/MesterX.API.csproj",           "src/MesterX.API/"]
COPY ["src/MesterX.Application/MesterX.Application.csproj", "src/MesterX.Application/"]
COPY ["src/MesterX.Domain/MesterX.Domain.csproj",      "src/MesterX.Domain/"]
COPY ["src/MesterX.Infrastructure/MesterX.Infrastructure.csproj", "src/MesterX.Infrastructure/"]

# Restore all projects
RUN dotnet restore "src/MesterX.API/MesterX.API.csproj" \
    --runtime linux-musl-x64

# Copy full source
COPY . .

# Build in Release mode
RUN dotnet build "src/MesterX.API/MesterX.API.csproj" \
    --configuration Release \
    --no-restore \
    --output /build

# ── Stage 2: Publish ─────────────────────────────────────────────────────
FROM build AS publish
RUN dotnet publish "src/MesterX.API/MesterX.API.csproj" \
    --configuration Release \
    --runtime linux-musl-x64 \
    --self-contained true \
    --no-build \
    --output /publish \
    /p:PublishSingleFile=true \
    /p:PublishTrimmed=false

# ── Stage 3: Final runtime ───────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine AS final
WORKDIR /app

# Security: non-root user
RUN adduser --disabled-password --gecos '' mallx && chown -R mallx /app
USER mallx

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:5000/health || exit 1

# Port
EXPOSE 5000

# Environment defaults (override in docker-compose)
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_RUNNING_IN_CONTAINER=true
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# Copy published output
COPY --from=publish /publish .

# Create logs dir
RUN mkdir -p logs && chown mallx logs

ENTRYPOINT ["./MesterX.API"]
