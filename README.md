# Base Images Mirror

Centralized Docker base image mirror from Docker Hub to GitHub Container Registry (GHCR).

## Purpose

Avoids Docker Hub pull rate limits by mirroring base images to GHCR, which has unlimited pulls with `GITHUB_TOKEN` in GitHub Actions.

## Mirrored Images

Configured via the `BASE_IMAGES` GitHub repository variable (comma-separated):

```
node:current-alpine, node:22-slim, node:22-alpine, node:alpine, golang:1.26-alpine, alpine:latest, python:3-slim, debian:bookworm-slim, debian:trixie-slim, debian:stable-slim
```

| Source (Docker Hub) | GHCR Mirror | Used By |
|:-------------------|:------------|:--------|
| `node:current-alpine` | `ghcr.io/mekayelanik/base-images/node:current-alpine` | context7-mcp-docker |
| `node:22-slim` | `ghcr.io/mekayelanik/base-images/node:22-slim` | gitnexus-docker |
| `node:alpine` | `ghcr.io/mekayelanik/base-images/node:alpine` | MCP docker repos (time, fetch, brave, etc.) |
| `golang:1.26-alpine` | `ghcr.io/mekayelanik/base-images/golang:1.26-alpine` | db-MCP-server-docker |
| `alpine:latest` | `ghcr.io/mekayelanik/base-images/alpine:latest` | nfs-server, samba-server, proftpd, db-MCP |
| `python:3-slim` | `ghcr.io/mekayelanik/base-images/python:3-slim` | codegraphcontext-mcp-docker |
| `debian:bookworm-slim` | `ghcr.io/mekayelanik/base-images/debian:bookworm-slim` | ispyagentdvr |
| `debian:trixie-slim` | `ghcr.io/mekayelanik/base-images/debian:trixie-slim` | ispyagentdvr, vllm-cpu |
| `debian:stable-slim` | `ghcr.io/mekayelanik/base-images/debian:stable-slim` | ispyagentdvr |

## Adding / Removing Images

1. Go to **Settings > Variables > Actions** in this repo
2. Edit the `BASE_IMAGES` variable
3. Add or remove images (comma-separated)
4. Trigger the workflow

No code changes needed.

## Trigger

- **cron-job.org**: POST to `https://api.github.com/repos/MekayelAnik/base-images/dispatches` with body `{"event_type": "mirror-base-images"}`
- **Manual**: Actions > Mirror Base Images to GHCR > Run workflow

## Usage in Other Repos

Set `BASE_IMAGE_DEFAULT` variable in your repo:

```
ghcr.io/mekayelanik/base-images/node:22-slim
```
