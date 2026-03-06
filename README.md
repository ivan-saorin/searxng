# searxng — private instance with JSON API

Personal SearXNG deployment for local/private use. JSON API enabled for programmatic access (MindMy/MCP). Web UI available simultaneously.

## Stack

| Service  | Image                                    | Purpose              |
| -------- | ---------------------------------------- | -------------------- |
| SearXNG  | `docker.io/searxng/searxng:latest`       | Search engine        |
| Valkey   | `docker.io/valkey/valkey:8-alpine`       | In-memory DB (limiter / cache) |
| Caddy    | `docker.io/library/caddy:2-alpine`       | Reverse proxy (optional, network_mode: host) |

> Caddy is included in the compose file but is **optional** for local use. SearXNG is directly accessible on port 8080 without it.

## Key configuration decisions

- **JSON API enabled** — `search.formats: [html, json]` in `searxng/settings.yml`
- **Limiter disabled** — `server.limiter: false` — no Redis required for rate limiting, no bot detection blocking API clients
- **Port bound to all interfaces** (`8080:8080`) — reachable from other Docker containers on the same host
- **HTTP base URL** — `http://` not `https://` for local use; change `.env` if adding TLS via Caddy

## First-time setup

**1. Generate a real secret key**

Linux/macOS:
```bash
SECRET=$(openssl rand -hex 32)
sed -i "s|REPLACE_WITH_OUTPUT_OF: openssl rand -hex 32|$SECRET|g" searxng/settings.yml
```

Windows (PowerShell):
```powershell
$secret = -join ((New-Object Security.Cryptography.RNGCryptoServiceProvider).GetBytes(32) | ForEach-Object { "{0:x2}" -f $_ })
(Get-Content searxng/settings.yml) -replace 'REPLACE_WITH_OUTPUT_OF: openssl rand -hex 32', $secret | Set-Content searxng/settings.yml
```

**2. First-run capability note**

On the very first `docker compose up`, the container needs to write `uwsgi.ini` to `/etc/searxng/`. If it fails with a permissions error, temporarily comment out `cap_drop: - ALL` in `docker-compose.yaml` for the `searxng` service, run once, then re-enable it.

**3. Start**

```bash
docker compose pull        # grab latest images
docker compose up -d
```

**4. Verify**

```bash
# Web UI
open http://localhost:8080

# JSON API
curl "http://localhost:8080/search?q=test&format=json"
```

## JSON API usage

```
GET http://localhost:8080/search?q=<query>&format=json
GET http://localhost:8080/search?q=<query>&format=json&categories=general
GET http://localhost:8080/search?q=<query>&format=json&language=en
```

Key response fields: `results[].url`, `results[].title`, `results[].content`

**From another Docker container on the same host:**
```
http://searxng:8080/search?q=<query>&format=json
```
(use the container name as hostname when on the same Docker network)

## Update

```bash
docker compose pull
docker compose up -d
```

> Avoid pinning to a specific date tag unless you hit a regression. The `latest` tag is rebuilt multiple times per day from master. Notable past issue: January 2025 builds had a JSON circular-reference serialization bug (fixed in subsequent builds).

## Troubleshooting

**Getting HTML back instead of JSON?**
- Confirm `json` is in `search.formats` in `settings.yml`
- Confirm `server.limiter: false` is set
- Restart the container after any `settings.yml` change: `docker restart searxng`

**Container-to-container requests return HTML silently?**
- Bot detection can downgrade responses even with the limiter off if the client sends no browser-like headers
- Fix: ensure `limiter: false` is set (already done), or add the Docker subnet to `pass_ip` in `searxng/limiter.toml`

**Port not reachable from other containers?**
- The port must be `8080:8080` not `127.0.0.1:8080:8080` — the latter binds only to localhost

## Logs

```bash
docker compose logs -f searxng
docker compose logs -f redis     # valkey logs under this alias
docker compose logs -f caddy
```

## File structure

```
searxng/
├── docker-compose.yaml        # main stack definition
├── .env                       # SEARXNG_HOSTNAME, UWSGI workers
├── Caddyfile                  # reverse proxy config (optional)
├── Dockerfile.searxng         # unused — config is volume-mounted
├── searxng/
│   ├── settings.yml           # main config: formats, limiter, secret_key
│   ├── settings-default.yml   # reference copy of upstream defaults
│   └── limiter.toml           # bot detection / IP allowlist config
```
