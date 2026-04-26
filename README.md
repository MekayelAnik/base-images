# Base Images Mirror

[![Mirror Base Images to GHCR](https://github.com/MekayelAnik/base-images/actions/workflows/mirror-base-images.yml/badge.svg)](https://github.com/MekayelAnik/base-images/actions/workflows/mirror-base-images.yml)

Centralized Docker base image mirror from Docker Hub to GitHub Container Registry (GHCR).

## Purpose

Avoids Docker Hub pull rate limits by mirroring base images to GHCR, which has unlimited pulls with `GITHUB_TOKEN` in GitHub Actions.

## Mirrored Images

| Source (Docker Hub) | GHCR Mirror | Architectures | Used By | Status | Last Updated |
|:-------------------:|:-----------:|:-------------:|:-------:|:------:|:------------:|
| `alpine:latest` | `ghcr.io/mekayelanik/base-images/alpine:latest` | linux/386,linux/amd64 linux/arm/v6,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | db-mcp-server-docker | Mirrored | 2026-04-18 17:34 UTC |
| `debian:stable-slim` | `ghcr.io/mekayelanik/base-images/debian:stable-slim` | linux/386,linux/amd64 linux/arm/v5,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | vllm-cpu | Mirrored | 2026-04-22 05:33 UTC |
| `golang:alpine` | `ghcr.io/mekayelanik/base-images/golang:alpine` | linux/386,linux/amd64 linux/arm/v6,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | db-mcp-server-docker | Mirrored | 2026-04-18 17:34 UTC |
| `haproxy:lts` | `ghcr.io/mekayelanik/base-images/haproxy:lts` | linux/386,linux/amd64 linux/arm/v5,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | branch-thinking-mcp-docker, codegraphcontext-mcp-docker, gitnexus-docker, narsil-mcp-docker, serena-mcp-docker | Mirrored | 2026-04-25 00:33 UTC |
| `haproxy:lts-alpine` | `ghcr.io/mekayelanik/base-images/haproxy:lts-alpine` | linux/386,linux/amd64 linux/arm/v6,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | semgrep-mcp-docker, brave-search-mcp-docker, context7-mcp-docker, db-mcp-server-docker, duckduckgo-mcp-docker, fetch-mcp-docker, filesystem-mcp-docker, firecrawl-mcp-docker, knowledge-graph-mcp-docker, openapi-mcp-docker, perplexity-mcp-docker, redis-mcp-server-docker, sequential-thinking-mcp-docker, snyk-mcp-docker, time-mcp-docker, valkey-mcp-docker, vllm-cpu | Mirrored | 2026-04-25 00:33 UTC |
| `moby/buildkit:master` | `ghcr.io/mekayelanik/base-images/moby/buildkit:master` | linux/amd64,linux/arm/v7 linux/arm64,linux/ppc64le linux/riscv64,linux/s390x | branch-thinking-mcp-docker, brave-search-mcp-docker, codegraphcontext-mcp-docker, context7-mcp-docker, db-mcp-server-docker, duckduckgo-mcp-docker, fetch-mcp-docker, filesystem-mcp-docker, firecrawl-mcp-docker, gitnexus-docker, ispyagentdvr-docker, knowledge-graph-mcp-docker, narsil-mcp-docker, openapi-mcp-docker, perplexity-mcp-docker, redis-mcp-server-docker, semgrep-mcp-docker, sequential-thinking-mcp-docker, serena-mcp-docker, snyk-mcp-docker, time-mcp-docker, valkey-mcp-docker, vllm-cpu | Mirrored | 2026-04-26 11:33 UTC |
| `node:22-trixie-slim` | `ghcr.io/mekayelanik/base-images/node:22-trixie-slim` | linux/amd64,linux/arm64/v8 linux/ppc64le,linux/s390x | gitnexus-docker | Mirrored | 2026-04-22 09:33 UTC |
| `node:current-alpine` | `ghcr.io/mekayelanik/base-images/node:current-alpine` | linux/amd64,linux/arm64/v8 linux/s390x | context7-mcp-docker | Mirrored | 2026-04-18 17:34 UTC |
| `node:current-slim` | `ghcr.io/mekayelanik/base-images/node:current-slim` | linux/amd64,linux/arm64/v8 linux/ppc64le,linux/s390x | — | Mirrored | 2026-04-22 09:33 UTC |
| `node:current-trixie-slim` | `ghcr.io/mekayelanik/base-images/node:current-trixie-slim` | linux/amd64,linux/arm64/v8 linux/ppc64le,linux/s390x | narsil-mcp-docker | Mirrored | 2026-04-22 09:33 UTC |
| `node:lts-trixie-slim` | `ghcr.io/mekayelanik/base-images/node:lts-trixie-slim` | linux/amd64,linux/arm64/v8 linux/ppc64le,linux/s390x | — | Mirrored | 2026-04-22 09:33 UTC |
| `python:3-slim` | `ghcr.io/mekayelanik/base-images/python:3-slim` | linux/386,linux/amd64 linux/arm/v5,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | codegraphcontext-mcp-docker | Mirrored | 2026-04-24 08:33 UTC |
| `python:3.13-alpine` | `ghcr.io/mekayelanik/base-images/python:3.13-alpine` | linux/386,linux/amd64 linux/arm/v6,linux/arm/v7 linux/arm64/v8,linux/ppc64le linux/riscv64,linux/s390x | semgrep-mcp-docker | Mirrored | 2026-04-19 01:02 UTC |
| `rust:slim-trixie` | `ghcr.io/mekayelanik/base-images/rust:slim-trixie` | linux/386,linux/amd64 linux/arm/v7,linux/arm64/v8 linux/ppc64le,linux/riscv64 linux/s390x | narsil-mcp-docker | Mirrored | 2026-04-24 20:33 UTC |
| `tonistiigi/xx:master` | `ghcr.io/mekayelanik/base-images/tonistiigi/xx:master` | linux/386,linux/amd64 linux/arm/v5,linux/arm/v6 linux/arm/v7,linux/arm64 linux/loong64,linux/mips linux/mips64,linux/mips64le linux/mipsle,linux/ppc64le linux/riscv64,linux/s390x | db-mcp-server-docker | Mirrored | 2026-04-25 00:33 UTC |

## Adding / Removing Images

1. Go to **Settings > Variables > Actions** in this repo
2. Edit the `BASE_IMAGES` variable (comma-separated list)
3. Trigger the workflow — no code changes needed

## Trigger

- **cron-job.org**: POST to `https://api.github.com/repos/MekayelAnik/base-images/dispatches` with body `{"event_type": "mirror-base-images"}`
- **Manual**: Actions > Mirror Base Images to GHCR > Run workflow

## Usage in Other Repos

Set `BASE_IMAGE_DEFAULT` variable in your repo:

```
ghcr.io/mekayelanik/base-images/node:22-slim
```

---

*This README is auto-generated by the [mirror workflow](https://github.com/MekayelAnik/base-images/actions/workflows/mirror-base-images.yml). Do not edit manually.*
