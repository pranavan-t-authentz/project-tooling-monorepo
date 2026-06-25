# Project Tooling Monorepo

Shared tooling and proof-of-concept experiments for project infrastructure.

## Repository Structure

```
project-tooling-monorepo/
├── README.md
├── .gitignore
├── docker-compose-setups/
│   └── one-local-compose/
│       └── README.md          ← redirect; canonical stack is at Work root
├── docs/
└── pocs/
```

### Top-level areas

| Path | Purpose |
| --- | --- |
| `docker-compose-setups/one-local-compose/` | Legacy redirect stub — canonical stack lives at Work root |
| `docs/` | Monorepo documentation (reserved) |
| `pocs/` | Proof-of-concept experiments |

## One Local Compose (Authentz)

Unified local platform for 6 services (5 app repos + Postgres). **Canonical location:** `~/Documents/Work/one-local-compose/` (sibling to this monorepo and app repos).

```bash
cd ~/Documents/Work/one-local-compose
cp .env.example .env   # optional on Mac/Linux
make preflight
make up-local-detached # first time
make health-local
```

All `make` targets run from **`one-local-compose/`** only (there is no delegating Makefile at the Work root).

| File | Purpose |
| --- | --- |
| `one-local.docker-compose.yml` | Unified stack definition |
| `Makefile` | Local run targets (`up-local`, `health-local`, etc.) |
| `doc/LOCAL-DOCKER-RUN-GUIDE.md` | **Run guide** — overview, env, commands, troubleshooting |

Full guide: **`~/Documents/Work/one-local-compose/doc/LOCAL-DOCKER-RUN-GUIDE.md`**

Do not edit or run compose files under `docker-compose-setups/one-local-compose/` in this repo — that path is a redirect stub. See its [README](docker-compose-setups/one-local-compose/README.md) for the canonical location.

### Expected Work layout

```
Work/
├── one-local-compose/          ← run make here (canonical)
├── project-tooling-monorepo/
├── authentz-frontend-next/
├── authentz-laravel-backend/
├── authentz-python-flask-api/
├── Speech-to-text-streaming/
└── video-processing/
```
