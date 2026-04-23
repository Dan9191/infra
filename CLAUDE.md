# Infra — GitOps Kubernetes (graduation project)

## What this repo is

GitOps infra repo for a graduation project. ArgoCD watches this repo and syncs everything to the cluster. The cluster runs on a single bare-metal node at **155.212.128.137**.

GitHub: `https://github.com/Dan9191/infra` (user: Dan9191)

## Repo layout

```
root/        # ArgoCD Application manifests (app-of-apps pattern)
apps/        # Actual Kubernetes manifests, grouped by component
```

`root/` contains one `.yaml` per component; each points ArgoCD at the corresponding `apps/<component>/` directory. Adding a new service means creating both `root/<service>.yaml` and `apps/<service>/`.

## Cluster components

| Component | Namespace | Notes |
|---|---|---|
| ArgoCD | `argocd` | GitOps controller + image updater |
| Sealed Secrets | `kube-system` | Bitnami controller, decrypts SealedSecret resources |
| MetalLB | `metallb-system` | L2 mode, single IP pool: `155.212.128.137` |
| ingress-nginx | — | Handles all Ingress objects |
| cert-manager | — | Let's Encrypt via ACME HTTP-01 |
| local-path-provisioner | — | Provides PVCs for stateful services |
| PostgreSQL | `postgres` | Single instance, shared by all services |
| RabbitMQ | `rabbitmq` | Used for article→rag event pipeline |
| Keycloak | `keycloak` | Auth server, realm: `graduation` |

## Graduation app microservices

All images are in GHCR: `ghcr.io/dan9191/graduation-work/<service>`  
ArgoCD Image Updater tracks digests and writes back to `main` automatically.

| Service | Namespace | Port | Ingress host |
|---|---|---|---|
| frontend | `graduation-frontend` | — | `mos-hack.ru` |
| gateway | `graduation-gateway` | 8033 | `api.mos-hack.ru` |
| article | `graduation-article` | 8093 | — (internal) |
| rag | `graduation-rag` | 8094 | — (internal) |
| documentation | `graduation-documentation` | — | `docs.mos-hack.ru` |

**Gateway** routes `/knowledge/**` → article-service and `/embedding/**` → rag-service.

**Article** publishes events to RabbitMQ exchange `article.exchange` / queue `article.outbox.queue`; **rag** consumes them to build embeddings.

**RAG** uses GigaChat API (Sber): embedding model `EmbeddingsGigaR`, LLM `GigaChat-2-Max`. API credentials are stored in a SealedSecret (`sealed-models-secret.yaml`).

## Domain & TLS

Domain: **mos-hack.ru**

| Host | Service |
|---|---|
| `mos-hack.ru` | frontend |
| `api.mos-hack.ru` | gateway |
| `auth.mos-hack.ru` | keycloak |
| `docs.mos-hack.ru` | documentation |

TLS via cert-manager. Two ClusterIssuers: `letsencrypt-staging` and `letsencrypt-prod`. Each service has its own Certificate resource in `apps/cert-manager/`.

## Secrets — Sealed Secrets workflow

All secrets in the repo are `SealedSecret` objects encrypted with the cluster's public key (`pub-cert.pem` at repo root). Never commit plain `Secret` YAMLs.

```bash
# Fetch public cert
kubeseal --fetch-cert \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system > pub-cert.pem

# Create and seal a secret
kubectl create secret generic my-secret \
  --namespace my-ns \
  --from-literal=key=value \
  --dry-run=client -o yaml \
| kubeseal --cert pub-cert.pem --format yaml > apps/my-app/sealed-my-secret.yaml
```

Each SealedSecret is namespace+name scoped — it only decrypts in the namespace it was sealed for.

## Image updater

ArgoCD Image Updater is configured per-Application in `root/graduation/*.yaml` annotations:
- Strategy: `digest` (tracks latest digest on the same tag)
- Pull secret: `ghcr-secret` (SealedSecret in `apps/argocd/`)
- Write-back: commits updated digest back to this repo via `image-updater-git` secret

## Keycloak setup notes

- Realm: `graduation`
- Clients: `graduation-frontend` (public), `graduation-token` (confidential)
- Roles: `graduation.admin`, `graduation.user`
- Persistent admin: `admin2` (the initial `admin` user was deleted after setup)
- Keycloak connects to shared Postgres (`postgres` DB, `public` schema)

## Database

Single Postgres instance in `postgres` namespace. Services use separate schemas:
- Article service: schema `article_service`
- RAG service: schema `rag`
- Keycloak: default `public`

Postgres password is a SealedSecret; each namespace that needs it has its own sealed copy (sealed per namespace).

## RabbitMQ

Admin UI: `kubectl port-forward svc/rabbitmq 15672:15672 -n rabbitmq`  
Credentials: `admin` / `admin123` (set in ConfigMaps — not a secret).

## Common operations

```bash
# Check ArgoCD sync status
kubectl get applications -n argocd

# Watch a deployment rollout
kubectl rollout status deployment/<name> -n <namespace>

# Get logs
kubectl logs -n <namespace> deployment/<name>

# Seal a new secret
kubectl create secret generic <name> --namespace <ns> --from-literal=<k>=<v> \
  --dry-run=client -o yaml | kubeseal --cert pub-cert.pem --format yaml > apps/<app>/sealed-<name>.yaml
```
