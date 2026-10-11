# minipoll

A small three-tier polling app for the AKS capstone. Create a poll, share the link, watch votes arrive live.

| Tier | Tech | Port |
|---|---|---|
| Frontend | Static HTML/JS served by nginx (beige and light green UI) | 8080 |
| Backend | Node 20 + Express | 3000 |
| Database | PostgreSQL 16 | 5432 |

## Run locally
    docker compose up --build
Open http://localhost:8080

## API
- `POST /api/polls` body `{question, options:[...]}` returns `{id}`
- `GET /api/polls/:id` and `GET /api/polls/:id/results`
- `POST /api/polls/:id/vote` body `{optionId}`
- `GET /api/healthz` (liveness), `GET /api/readyz` (readiness, checks the DB)

## Backend environment variables
`DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_SSL` (set `true` for Azure PostgreSQL), `ENABLE_DEBUG`.
Tables are created automatically on startup.

## Frontend environment variable
`BACKEND_HOST` (default `backend:3000`): where nginx proxies `/api`. In Kubernetes, point it at the backend Service, or let the Ingress route `/api` and ignore it.

## Capstone notes
- Probes: liveness `/api/healthz` and readiness `/api/readyz` on the backend; `/healthz` on the frontend (port 8080).
- Containers run as non-root, so they fit strict pod security settings.
- Set `ENABLE_DEBUG=true` only for demos: `/api/debug/burn` (CPU load for the HPA) and `/api/debug/crash` (kills the pod to trigger restart alerts).
- Load test example: `hey -z 60s -c 50 http://localhost:8080/api/debug/burn`
- Next steps: Kubernetes manifests/Helm chart, then Terraform, then GitHub Actions.
