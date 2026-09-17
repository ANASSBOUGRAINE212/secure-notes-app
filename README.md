# Secure Notes

A small notes app I built to learn my way through a full DevSecOps pipeline — went from a basic CRUD app to microservices, containers, Kubernetes, GitOps, and infrastructure-as-code. It's overkill for what the app actually does (create/read/update/delete notes), and that's kind of the point — the app is simple on purpose so the infrastructure around it could be the actual focus.

## What it does

- Register and log in with email/password (bcrypt-hashed, obviously)
- Create, edit, and delete personal notes
- Notes are scoped per user — you can't see or touch anyone else's, even by guessing an ID

## How it's built

Split into two independent services that don't share a database:

- **auth-service** — owns registration, login, and the `users` table. Issues JWTs.
- **notes-service** — owns notes CRUD and the `notes` table. Never talks to auth-service directly — it just verifies JWTs using the same signing secret both services share.

A small **gateway** (nginx) sits in front and routes `/auth/*` and `/notes/*` to the right service, so the frontend only ever has to know about one address.

```
secure-notes/
├── auth-service/       FastAPI, owns users + login
├── notes-service/       FastAPI, owns notes
├── gateway/               nginx, path-based routing
├── frontend/               plain HTML/CSS/JS, no framework
├── docker/                 docker-compose for local multi-container testing
├── kubernetes/              manifests for a real cluster
├── terraform/                 AWS-shaped infra (ECR, S3, VPC, EKS, RDS) — runs against MiniStack, not real AWS
├── argocd/                     points ArgoCD at kubernetes/ for GitOps sync
└── .gitlab-ci.yml               build, scan, test, and auto-update k8s image tags
```

## Running it

There are three ways to run this, depending on what you're testing.

### 1. Manual (no Docker)

Each service runs in its own venv, talking to its own local Postgres database.

```bash
./start.sh
```

This spins up both services and streams their logs together, tagged `[auth]` / `[notes]`. Needs two Postgres databases created beforehand (`auth_db`, `notes_db`) and each service's own `.env` with its `DATABASE_URL` + a shared `JWT_SECRET`. Frontend hits `localhost:8001` / `localhost:8002` directly in this mode.

### 2. Docker Compose

Everything — both databases, both services, the gateway, and the frontend — as six containers.

```bash
docker compose -f docker/docker-compose.yml --env-file .env up --build
```

Needs a root `.env` with the combined DB variables (see `.env.example`). In this mode the frontend talks through the gateway on `localhost:8080` instead of hitting each service directly — flip the two `const` lines at the top of `frontend/app.js` depending on which mode you're testing.

### 3. Kubernetes

Manifests live in `kubernetes/`, applied in this rough order: namespace → secrets → both databases → both services → gateway → frontend → ingress. Needs images actually pushed to a registry first — the `image:` fields are placeholders until that happens. `argocd/application.yaml` points ArgoCD at this folder for GitOps-style auto-sync once there's a cluster and a registry to point at.

## Testing

```bash
cd auth-service && pytest tests/ -v
cd notes-service && pytest tests/ -v
```

Both use an in-memory SQLite database for tests, so no real Postgres needed to run them. notes-service's tests mint their own JWT locally using the shared test secret, since it doesn't issue tokens itself.

## The DevSecOps side

This is really where most of the actual learning happened:

- **CI** (`.gitlab-ci.yml`) — builds all four images, runs pytest for both services, scans dependencies (both GitLab's built-in scanner and OWASP Dependency-Check, deliberately redundant so I could compare them), scans images with Trivy, then on `main` auto-commits the new image tags into `kubernetes/*.yaml`
- **CD** — ArgoCD watches that same `kubernetes/` folder and syncs the cluster to match, with self-healing turned on
- **Dockerfiles** are hardened — multi-stage builds, non-root users, nginx running unprivileged
- **Terraform** manages ECR, S3, VPC, EKS, and RDS, but pointed at MiniStack (a free local AWS emulator) rather than real AWS, so none of it costs anything or needs real credentials
- **Kubernetes deployments** have resource limits and liveness/readiness probes, so a stuck pod actually gets restarted instead of quietly hanging forever

