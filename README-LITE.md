# OmniRoute Lite

**Low-RAM optimized fork of [OmniRoute](https://github.com/diegosouzapw/OmniRoute)**

Built for VPS with ≤1GB RAM. Same features, fraction of the memory.

## What's Different

| | Stock OmniRoute | OmniRoute Lite |
|---|---|---|
| Idle RAM | ~1GB+ | **~200-350MB** |
| Node heap | 1024MB | **256MB** |
| Redis | Required | **Optional** (in-memory fallback) |
| Chromium | Included | **Removed** |
| CLI tools | Included | **Removed** |
| Docker image | ~2.6GB | **~1.5GB** (estimated) |
| Build method | Build locally | **GitHub Actions** (7GB RAM) |

## Features Preserved

- ✅ All 291 providers
- ✅ Dashboard (login, combos, providers, logs, quota)
- ✅ API endpoint `/v1/chat/completions`
- ✅ RTK + Caveman compression
- ✅ Proxy pool
- ✅ SQLite storage
- ✅ Request logs
- ✅ Streaming (SSE)

## Quick Start

### Pull from GHCR

```bash
# Create .env
cp .env.lite.example .env
# Edit .env with your settings (JWT_SECRET, INITIAL_PASSWORD)

# Run
docker pull ghcr.io/dianrestu/omniroute-lite:latest
docker compose -f docker-compose.lite.yml up -d
```

### Build Locally (needs 4GB+ RAM)

```bash
docker compose -f docker-compose.lite.yml build
docker compose -f docker-compose.lite.yml up -d
```

## Environment Variables

| Variable | Default | Description |
|---|---|---|
| `OMNIROUTE_MEMORY_MB` | `256` | Node.js heap ceiling (MB) |
| `REDIS_URL` | _(empty)_ | Redis URL. Empty = in-memory rate limiter |
| `PORT` | `20128` | Server port |
| `JWT_SECRET` | _(required)_ | JWT signing secret |
| `INITIAL_PASSWORD` | _(required)_ | Dashboard admin password |
| `ENABLE_REQUEST_LOGS` | `false` | Enable request logging |

### Ultra-Low RAM (128MB)

If 256MB is still too much, uncomment these in `.env`:

```env
OMNIROUTE_MEMORY_MB=128
PROMPT_CACHE_MAX_SIZE=20
PROMPT_CACHE_MAX_BYTES=524288
SEMANTIC_CACHE_MAX_SIZE=25
SEMANTIC_CACHE_MAX_BYTES=1048576
STREAM_HISTORY_MAX=10
```

## Architecture

```
┌─────────────────────────────────┐
│  GitHub Actions (7GB RAM)       │
│  Build with Dockerfile.lite     │
│  Push to ghcr.io/dian/          │
│  omniroute-lite:latest          │
└──────────┬──────────────────────┘
           │ docker pull
┌──────────▼──────────────────────┐
│  VPS (1GB RAM)                  │
│  OmniRoute Lite container       │
│  ~200-350MB idle RAM            │
│  Port 20128                     │
└─────────────────────────────────┘
```

## Credits

- [OmniRoute](https://github.com/diegosouzapw/OmniRoute) by diegosouzapw — MIT License
- Lite optimizations by dianrestu

## License

MIT License — same as upstream OmniRoute.
