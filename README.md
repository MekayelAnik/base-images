# Base Images Mirror

Centralized Docker base image mirror from Docker Hub to GitHub Container Registry (GHCR).

## Purpose

Avoids Docker Hub pull rate limits by mirroring base images to GHCR, which has unlimited pulls with `GITHUB_TOKEN` in GitHub Actions.

## Mirrored Images

| Source (Docker Hub) | GHCR Mirror | Used By |
|:-------------------|:------------|:--------|
| `node:current-alpine` | `ghcr.io/mekayelanik/base-images/node:current-alpine` | context7-mcp-docker |
| `node:22-slim` | `ghcr.io/mekayelanik/base-images/node:22-slim` | gitnexus-docker |
| `node:22-alpine` | `ghcr.io/mekayelanik/base-images/node:22-alpine` | (spare) |
| `golang:1.26-alpine` | `ghcr.io/mekayelanik/base-images/golang:1.26-alpine` | db-MCP-server-docker |
| `alpine:latest` | `ghcr.io/mekayelanik/base-images/alpine:latest` | db-MCP-server-docker |
| `python:3-slim` | `ghcr.io/mekayelanik/base-images/python:3-slim` | codegraphcontext-mcp-docker |

## Schedule

Images are mirrored automatically every **Sunday at 3am UTC**.

## Manual Trigger

Go to **Actions** > **Mirror Base Images to GHCR** > **Run workflow**

## Usage in Other Repos

Set the `BASE_IMAGE_DEFAULT` GitHub variable in your repo to use the GHCR mirror:

```
ghcr.io/mekayelanik/base-images/node:22-slim
```

## Adding New Images

Edit `.github/workflows/mirror-base-images.yml` and add the image to the `matrix.image` list.
