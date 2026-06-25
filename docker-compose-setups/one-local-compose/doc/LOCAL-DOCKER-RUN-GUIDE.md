# One Local Docker Run Guide

The single source of truth for running the Authentz platform locally with Docker Compose.

Everything runs from one directory and one compose file:

- Working directory: `~/Documents/Work/one-local-compose/`
- Compose file: `one-local.docker-compose.yml`
- Makefile: `Makefile` (targets like `preflight`, `up-local-detached`, `health-local`, `down-local`)
- Preflight script: `scripts/local-compose-preflight.sh`

Run **all** `make` and `docker compose -f one-local.docker-compose.yml` commands from `one-local-compose/`. Do not use `docker run`.

---

## 1. Overview

A single compose project, **`authentz-local-platform`**, runs **6 services** — 5 application repos built from source plus a Postgres image. The 5 app repos live as **siblings** of `one-local-compose/` under the Work root and are referenced with `../<repo>` build contexts.

### Ports

All host ports bind to **`127.0.0.1`** only (not exposed on the LAN).

| Compose service | Repo folder | Host port | Container port | Health endpoint | `start_period` |
|-----------------|-------------|-----------|----------------|-----------------|----------------|
| `frontend-next` | `authentz-frontend-next` | 3000 | 3000 | `GET /` | 60s |
| `python-flask-api` | `authentz-python-flask-api` | 5000 | 5000 | `GET /health` | 90s |
| `video-processing` | `video-processing` | 5001 | 5000 | `GET /` | 180s |
| `speech-to-text-streaming` | `Speech-to-text-streaming` | 7000 | 8000 | `GET /health/live` | 30s |
| `laravel-backend` | `authentz-laravel-backend` | 8000 | 8000 | `GET /up` | 60s |
| `postgres` | *(image `postgres:16-alpine`)* | 5433 *(via `POSTGRES_PORT`)* | 5432 | `pg_isready -U postgres -d central-auth-db` | — |

Compose project name: **`authentz-local-platform`**. Running containers are named `authentz-local-platform-<service>-1` (e.g. `authentz-local-platform-python-flask-api-1`).

**Startup order:** `postgres` must be healthy before `speech-to-text-streaming` starts (Alembic migrations). `frontend-next` waits for `python-flask-api` to start (not necessarily healthy).

### Network

All six services share the Docker bridge network **`authentz_local_network`**.

- **Browser → services:** use **host ports** (e.g. `http://localhost:5000/api`, `http://127.0.0.1:7000`). Docker service names are **not** resolvable from the browser.
- **Container → container:** services reach each other by **compose service name + container port**. Example: STT connects to Postgres via `postgresql+psycopg2://postgres:postgres@postgres:5432/central-auth-db`.
- **Postgres scope:** the local `postgres` container exists for **Speech-to-text-streaming only** (`central-auth-db`). **Laravel does not use it** — it loads DB credentials from AWS Secrets Manager / remote **RDS** at startup.

### Shared AWS resources (`~/.aws` mount)

AWS-backed services bind-mount the host **`~/.aws`** directory **read-only** into the container at **`/root/.aws`**. No AWS keys are stored in the repo or compose file. Containers call shared AWS resources (Secrets Manager, SSM, etc.) using your local SSO session.

```yaml
x-aws-common: &aws-common
  volumes:
    - ${AWS_SHARED_CREDENTIALS_DIR:-${HOME}/.aws}:/root/.aws:ro
  environment:
    AWS_PROFILE: ${AWS_PROFILE:-741448925364_AdministratorAccess}
    AWS_DEFAULT_REGION: ${AWS_DEFAULT_REGION:-eu-west-2}
```

| Service | AWS mount | Profile used |
|---------|-----------|--------------|
| `python-flask-api` | Yes | `dev` (via `env=dev` in app `.env`) |
| `laravel-backend` | Yes | `741448925364_AdministratorAccess` |
| `speech-to-text-streaming` | Yes | `741448925364_AdministratorAccess` |
| `video-processing` | Yes | `741448925364_AdministratorAccess` |
| `frontend-next` | No | — |
| `postgres` | No | — |

### `Dockerfile.dev` per repo

Compose builds each app from that repo's **`Dockerfile.dev`** (context = repo root), tuned for local Mac/CPU dev. Each repo's root **`Dockerfile`** remains the **production** image and is left untouched.

| Repo | Local build | Why not the production `Dockerfile` locally |
|------|-------------|----------------------------------------------|
| `authentz-python-flask-api` | `Dockerfile.dev` | Prod omits `libev-dev`, Playwright, curl; heavier base |
| `authentz-frontend-next` | `Dockerfile.dev` | Prod is multi-stage `npm run build` + `start`, not dev HMR |
| `authentz-laravel-backend` | `Dockerfile.dev` | Prod is php-fpm + nginx + supervisor |
| `Speech-to-text-streaming` | `Dockerfile.dev` | Prod bakes `.env` at build; local uses compose `env_file` + Alembic entrypoint |
| `video-processing` | `Dockerfile.dev` | Prod uses `nvidia/cuda` — not viable on Apple Silicon / Mac without GPU |

STT runs migrations on start via `Speech-to-text-streaming/docker/scripts/stt-migrate.sh` (mounted as the compose entrypoint).

### Expected layout

```
Work/
├── one-local-compose/          ← run make / docker compose here (canonical)
│   ├── one-local.docker-compose.yml
│   ├── Makefile
│   ├── .env.example
│   ├── scripts/local-compose-preflight.sh
│   └── doc/LOCAL-DOCKER-RUN-GUIDE.md   ← this guide
├── authentz-frontend-next/
├── authentz-laravel-backend/
├── authentz-python-flask-api/
├── Speech-to-text-streaming/
└── video-processing/
```

> Historical note: this stack briefly lived under `project-tooling-monorepo/docker-compose-setups/one-local-compose/` and was moved back to the Work root so build contexts and `env_file` paths are simple `../<repo>` sibling references. A redirect stub may remain in the monorepo.

---

## 2. Prerequisites

- **Docker Desktop** (or Docker Engine + Compose v2)
- **AWS CLI v2** with SSO configured
- Valid AWS SSO sessions for **both** profiles: `dev` and `741448925364_AdministratorAccess`
- All 5 application repos checked out as **siblings** of `one-local-compose/`

One-time AWS CLI setup, then log in to both profiles:

```bash
aws configure sso

aws sso login --profile dev
aws sso login --profile 741448925364_AdministratorAccess
```

Both profiles must exist in `~/.aws/config`. Refresh whenever the SSO session expires (see [Troubleshooting](#6-troubleshooting)).

---

## 3. How environment is stored

There are three layers of configuration. **No secrets are committed** — AWS credentials come from your host `~/.aws` session.

### Compose-level `.env` (optional on Mac/Linux)

Copy the template in `one-local-compose/`:

```bash
cp .env.example .env
```

`.env.example` contents:

```env
AWS_PROFILE=741448925364_AdministratorAccess
AWS_DEFAULT_REGION=eu-west-2
POSTGRES_PORT=5433
NEXT_PUBLIC_API_URL=http://localhost:5000/api
# Windows only: AWS_SHARED_CREDENTIALS_DIR=C:/Users/YourName/.aws
```

On Mac/Linux the defaults work without a `.env`. On **Windows**, `${HOME}` may be unset in Compose, so set `AWS_SHARED_CREDENTIALS_DIR` (forward slashes) to point at your `.aws` directory.

### Per-repo env files (loaded via compose `env_file`)

Each app loads its own env file from its repo. These are **not** committed to this repo — they live in the sibling app repos:

| Service | `env_file` path | Notes |
|---------|-----------------|-------|
| `python-flask-api` | `../authentz-python-flask-api/.env` | `env=dev` selects the AWS profile |
| `speech-to-text-streaming` | `../Speech-to-text-streaming/.env` | compose adds `CENTRAL_DATABASE_URL`, `ALLOWED_ORIGINS`, etc. |
| `laravel-backend` | `../authentz-laravel-backend/.env.dev` | compose overrides `APP_ENV=local`, `APP_URL` |
| `frontend-next` | `../authentz-frontend-next/.env.local` | OAuth client creds from Secrets Manager `authentz/allsecrets` |
| `video-processing` | *(none)* | config injected via compose `environment` + AWS mount |

### AWS profiles (shared resources)

The `~/.aws` directory is mounted read-only into the AWS-backed containers (see [Overview](#shared-aws-resources-aws-mount)). The default compose profile is `741448925364_AdministratorAccess` and the default region is `eu-west-2`; Flask uses the `dev` profile via `env=dev` in its app `.env`.

---

## 4. How to execute

### Daily start (no rebuild)

```bash
cd ~/Documents/Work/one-local-compose
make preflight       # validate both AWS profiles (aws sts get-caller-identity)
make up-local        # preflight + docker compose up -d
make health-local    # curl all 5 HTTP health endpoints
make ps-local        # container status
```

### First-time start (build all images)

```bash
cd ~/Documents/Work/one-local-compose
make up-local-detached   # preflight + docker compose up --build -d
make ps-local
make health-local
```

Initial builds can take **5–30+ minutes** (Flask/Playwright and video-processing PyTorch/dlib are the slowest). `up-local-detached` and `build-local` enable BuildKit (`DOCKER_BUILDKIT=1`).

> **Do not run multiple `make up-local-detached` or `docker compose up --build` in parallel** (e.g. from several terminals or agents). Parallel runs race on container names and leave stale containers. Use one terminal; if a build fails, stop extras before retrying (see [Troubleshooting](#6-troubleshooting)).

### Status, logs, stats

```bash
make ps-local        # docker compose ps
make logs-local      # follow all logs (tail 100)
make stats-local     # live CPU / memory / network
```

### Stop

```bash
make down-local      # docker compose down
```

### Make targets reference

| Target | Underlying command |
|--------|--------------------|
| `make preflight` | `./scripts/local-compose-preflight.sh` |
| `make up-local` | preflight + `docker compose ... up -d` |
| `make up-local-detached` | preflight + `docker compose ... up --build -d` |
| `make up-local-build` | `docker compose ... up --build` (foreground, no preflight) |
| `make up-local-quick` | preflight + `docker compose ... up -d` |
| `make build-local` | `docker compose ... build --parallel` (no start) |
| `make down-local` | `docker compose ... down` |
| `make ps-local` | `docker compose ... ps` |
| `make logs-local` | `docker compose ... logs -f --tail=100` |
| `make stats-local` | `docker compose ... stats` |
| `make health-local` | curl `:5000/health`, `:5001/`, `:3000/`, `:7000/health/live`, `:8000/up` |
| `make restart-flask` | restart `python-flask-api` + tail logs |
| `make restart-stt` | restart `speech-to-text-streaming` |
| `make restart-laravel` | restart `laravel-backend` |
| `make restart-frontend` | restart `frontend-next` |
| `make restart-postgres` | restart `postgres` |

### Raw compose equivalents

```bash
./scripts/local-compose-preflight.sh
docker compose -f one-local.docker-compose.yml up -d            # daily
docker compose -f one-local.docker-compose.yml up -d --build    # build + start
docker compose -f one-local.docker-compose.yml ps
docker compose -f one-local.docker-compose.yml logs -f --tail=100
docker compose -f one-local.docker-compose.yml down
docker compose -f one-local.docker-compose.yml down -v          # also reset Postgres data
```

### Health checks

`make health-local` probes:

| URL | Service |
|-----|---------|
| `http://127.0.0.1:5000/health` | python-flask-api |
| `http://127.0.0.1:5001/` | video-processing |
| `http://127.0.0.1:3000/` | frontend-next |
| `http://127.0.0.1:7000/health/live` | speech-to-text-streaming |
| `http://127.0.0.1:8000/up` | laravel-backend |

```bash
curl -f http://127.0.0.1:5000/health
curl -f http://127.0.0.1:5001/
curl -f http://127.0.0.1:3000/
curl -f http://127.0.0.1:7000/health/live
curl -f http://127.0.0.1:8000/up
```

---

## 5. Rebuild a single project

Use the **compose service name** (not the repo folder name). `--no-deps` avoids restarting dependents; `--force-recreate` replaces the running container after an image change.

| Repo folder | Compose service |
|-------------|-----------------|
| `authentz-python-flask-api` | `python-flask-api` |
| `authentz-laravel-backend` | `laravel-backend` |
| `authentz-frontend-next` | `frontend-next` |
| `Speech-to-text-streaming` | `speech-to-text-streaming` |
| `video-processing` | `video-processing` |

### Build then start (cache enabled)

```bash
docker compose -f one-local.docker-compose.yml build python-flask-api
docker compose -f one-local.docker-compose.yml up -d --no-deps python-flask-api
```

### One-shot rebuild + recreate

```bash
docker compose -f one-local.docker-compose.yml up -d --build --no-deps --force-recreate python-flask-api
```

### Build from scratch (`--no-cache`)

```bash
docker compose -f one-local.docker-compose.yml build --no-cache python-flask-api
docker compose -f one-local.docker-compose.yml up -d --no-deps --force-recreate python-flask-api
```

Substitute any service name (`laravel-backend`, `frontend-next`, `speech-to-text-streaming`, `video-processing`).

### Postgres (image only — no build)

```bash
docker compose -f one-local.docker-compose.yml pull postgres
docker compose -f one-local.docker-compose.yml up -d --no-deps --force-recreate postgres
```

### Restart without rebuilding

```bash
make restart-flask          # or restart-stt / restart-laravel / restart-frontend / restart-postgres
docker compose -f one-local.docker-compose.yml restart video-processing   # no make target
```

After any rebuild:

```bash
docker compose -f one-local.docker-compose.yml ps
make health-local
```

### Clean slate (full reset of this project)

```bash
docker compose -f one-local.docker-compose.yml down -v --rmi all --remove-orphans
```

Scoped to the `authentz-local-platform` compose project only. For system-wide cleanup run `docker system prune -a --volumes` separately.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| `ExpiredTokenException` in Flask logs / Flask crash-loop | SSO session expired (Flask loads AWS at import time) | Re-run both `aws sso login` commands, `make preflight`, then `make restart-flask` |
| `make preflight` fails | One profile invalid/expired | Run the `aws sso login --profile <name>` the script prints |
| `ProfileNotFound (dev)` inside a container | `dev` missing from `~/.aws/config` | Add the `dev` profile and `aws sso login --profile dev` |
| AWS works on host but not in container (Windows) | `${HOME}` unset in Compose | Set `AWS_SHARED_CREDENTIALS_DIR` in `.env` |
| `pip` download timeout during image build (often `scipy` on `python-flask-api`) | Transient PyPI / network slowness during `docker compose build` | Re-run `make up-local-detached` — Docker reuses cached layers; only failed steps rebuild. Avoid starting a second parallel build. |
| `Conflict. The container name "authentz-local-platform-…-1" is already in use` | Interrupted build or parallel `compose up` left a stale container | `make down-local`, then a single `make up-local-detached`. Or remove the named container: `docker rm -f authentz-local-platform-<service>-1` |
| Multiple `compose up` / `make up-local-detached` still running | Parallel terminals or agents started full stack builds | Check `ps aux \| grep -E 'compose up\|make up-local'`. Stop extra processes; run `make down-local` once, then one `make up-local-detached` |
| video-processing slow to become healthy (~3 min) | First build + Secrets Manager / model load at import time | Wait — `start_period: 180s`. Check `docker compose ... logs -f video-processing` |
| Laravel `/up` slow or flaky | Remote RDS via AWS secrets, network/VPN latency | Allow up to the `start_period: 60s`; ensure VPN/network is up and credentials valid |
| Port already in use (5433) | Local Postgres on 5432/5433 | Set `POSTGRES_PORT` in `.env` |
| Port already in use (5001 or others) | Orphaned container or other process | `lsof -i :5001`, `docker ps`; stop the holder or `make down-local` / `docker compose ... down --remove-orphans` |
| Frontend loads but API calls fail | Flask not healthy, or wrong API URL | Confirm `:5000/health` is healthy and `NEXT_PUBLIC_API_URL=http://localhost:5000/api` |

### Preflight details

`scripts/local-compose-preflight.sh` runs `aws sts get-caller-identity` for both `dev` and `741448925364_AdministratorAccess`. It exits `0` when both are valid, or prints the exact `aws sso login` commands and exits non-zero otherwise. It never prints secret values.

```bash
make preflight
# or directly:
./scripts/local-compose-preflight.sh
```

### Known local-only limitations

- Flask requires valid AWS credentials at import time; expired SSO tokens crash-loop it until refreshed.
- Laravel uses **remote RDS** via AWS secrets — the local `postgres` container is for STT only.
- STT runs Alembic migrations on container start, so first boot is slower.
- video-processing loads Secrets Manager + model/DB config at import time; first build and health check can take several minutes (`start_period: 180s`).
- Large Python dependency downloads (Flask, video-processing) can fail on slow networks; retrying the same build usually succeeds with layer cache.
- Only one full-stack `compose up --build` should run at a time — parallel runs cause container-name conflicts and orphaned containers.
- Browser calls must use `localhost`/`127.0.0.1` host ports, never Docker service names.

---

## Appendix: running natively (without Docker)

For per-repo debugging you can run a service directly on the host instead of in compose. This is optional and not the supported path — prefer the Docker stack above. Typical native entrypoints:

| Repo | Native run | Native port |
|------|------------|-------------|
| `authentz-python-flask-api` | `gunicorn --bind 0.0.0.0:5001 -w 1 --threads 4 -t 300 run:app` | 5001 |
| `Speech-to-text-streaming` | `uvicorn app.main:app --host 0.0.0.0 --port 8000` | 8000 |
| `video-processing` | `python app.py` | 5000 |
| `authentz-frontend-next` | `npm run dev` | 8080 |
| `authentz-laravel-backend` | `php artisan serve --host=127.0.0.1 --port=9000` | 9000 |

Each requires its own venv/`npm ci`/`composer install`, a valid AWS profile exported in the shell (`export AWS_PROFILE=...`), and the repo's `.env`. Native ports differ from the Docker host ports above.
