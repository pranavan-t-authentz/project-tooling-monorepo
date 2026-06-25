# One Local Compose

Unified Authentz local Docker platform (**6 services**: 5 app repos + Postgres). Application repos remain as sibling checkouts under the Work root.

## Quick start

```bash
cd ~/Documents/Work/one-local-compose
cp .env.example .env   # optional on Mac/Linux
make preflight
make up-local-detached # first time (build + start)
make health-local
```

All `make` targets run from **`one-local-compose/`** (there is no delegating Makefile at the Work root).

## Layout

| Path | Purpose |
| --- | --- |
| `one-local.docker-compose.yml` | Unified stack (all 6 services, including video-processing on port 5001) |
| `Makefile` | `make up-local`, `make health-local`, etc. |
| `.env.example` | Optional compose-level env overrides |
| `scripts/local-compose-preflight.sh` | AWS profile validation before start |
| `doc/LOCAL-DOCKER-RUN-GUIDE.md` | Single run guide (overview, env, commands, troubleshooting) |

Each application repo provides a **`Dockerfile.dev`** for local Mac/CPU development. Production **`Dockerfile`** files in those repos are unchanged (CUDA, nginx, Next.js prod build, etc.).

## Documentation

| Guide | Purpose |
| --- | --- |
| [`doc/LOCAL-DOCKER-RUN-GUIDE.md`](doc/LOCAL-DOCKER-RUN-GUIDE.md) | **Single source of truth** — overview, prerequisites, env, run/rebuild commands, troubleshooting (plus a native-run appendix) |

## Rebuild video-processing only

```bash
cd ~/Documents/Work/one-local-compose
docker compose -f one-local.docker-compose.yml up -d --build --no-deps video-processing
```

## Repo layout assumption

Compose paths expect this Work root layout:

```
Work/
├── one-local-compose/          ← run make here (canonical)
│   ├── one-local.docker-compose.yml
│   ├── Makefile
│   ├── .env.example
│   ├── scripts/
│   └── doc/
├── authentz-frontend-next/
├── authentz-laravel-backend/
├── authentz-python-flask-api/
├── Speech-to-text-streaming/
└── video-processing/
```
