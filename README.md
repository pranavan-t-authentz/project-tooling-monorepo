# Project Tooling Monorepo

Shared tooling, local Docker Compose setups, and proof-of-concept experiments for project infrastructure.

## Repository Structure

```
project-tooling-monorepo/
├── README.md
├── .gitignore
├── .editorconfig
│
├── docker-compose-setups/
│   └── one-local-compose/
│       ├── README.md
│       ├── docker-compose.yml
│       ├── .env.example
│       ├── scripts/
│       │   ├── up.sh
│       │   ├── down.sh
│       │   └── logs.sh
│       └── docs/
│           ├── setup-guide.md
│           ├── troubleshooting.md
│           └── architecture.md
│
├── pocs/
│   └── router-rest-shortcut-poc/
│       ├── README.md
│       ├── package.json
│       ├── src/
│       ├── tests/
│       └── docs/
│           └── findings.md
│
└── docs/
    ├── repo-guidelines.md
    └── contribution-guide.md
```

### Top-level areas

| Path | Purpose |
| --- | --- |
| `docker-compose-setups/` | Reusable local Docker Compose stacks for development |
| `pocs/` | Time-boxed experiments and spikes |
| `docs/` | Monorepo-wide guidelines and contribution docs |
