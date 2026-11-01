# uni-book-store-gitops

GitOps configuration for **uni-book-store** (Lab 5). Desired cluster state lives
here; Argo CD reconciles minikube to it. No manual `helm upgrade` / `kubectl apply`
of the app — the only hand-applied object is `bootstrap/root.yaml`.

```
bootstrap/root.yaml              # App-of-Apps (applied once by hand)
argocd-apps/uni-book-store.yaml  # the app Application (managed by root)
charts/uni-book-store/           # the Lab-4 Helm chart
  values-minikube.yaml           # GHCR images + existingSecret (no plaintext secrets)
```

Images are published to GHCR by the app repos' GitHub Actions (tags like `1.0.0`,
never only `latest`), so the cluster pulls them directly — no `minikube image load`.

## One-time setup

```bash
minikube start
minikube addons enable ingress

# Argo CD
kubectl create namespace argocd
kubectl apply -n argocd --server-side --force-conflicts \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl -n argocd rollout status deploy/argocd-server

# Argo CD CLI + login + change the admin password
brew install argocd
kubectl -n argocd port-forward svc/argocd-server 8080:443 &   # separate terminal
argocd admin initial-password -n argocd
argocd login localhost:8080 --username admin --insecure
argocd account update-password
kubectl -n argocd delete secret argocd-initial-admin-secret

# Private gitops repo only:
# argocd repo add https://github.com/volodymyrDobry/uni-book-store-gitops.git \
#   --username volodymyrDobry --password <read-only PAT>
```

### Secrets (kept out of Git — existingSecret pattern)

```bash
kubectl create namespace uni-book-store
kubectl -n uni-book-store create secret generic uni-book-store-secret \
  --from-literal=SPRING_DATASOURCE_PASSWORD=S3cr3tP@ssw0rd_demo \
  --from-literal=POSTGRES_PASSWORD=S3cr3tP@ssw0rd_demo \
  --from-literal=S3_ACCESS_KEY=test --from-literal=S3_SECRET_KEY=test
kubectl -n uni-book-store create secret generic uni-book-store-keycloak-secret \
  --from-literal=KEYCLOAK_ADMIN_PASSWORD=admin \
  --from-literal=KC_DB_PASSWORD=keycloak_demo_pw \
  --from-literal=POSTGRES_PASSWORD=keycloak_demo_pw
```

## Bootstrap

```bash
kubectl apply -f bootstrap/root.yaml    # the only manual apply
argocd app list
argocd app get uni-book-store
kubectl -n uni-book-store get pods
```

Open the app: keep `sudo minikube tunnel` running, add
`127.0.0.1 uni-book-store.local keycloak.local` to `/etc/hosts`, browse
`http://uni-book-store.local/` (login `testuser` / `password`). The version shows
in the UI footer and at `/actuator/info` on each service.

## Demo flows (Lab 5 §5–6)

**Release via Git** — publish `1.1.0` images (push a `v1.1.0` tag in the app repos),
then here:
```bash
# charts/uni-book-store/values-minikube.yaml: tag "1.0.0" -> "1.1.0"
git commit -am "Release 1.1.0" && git push
argocd app get uni-book-store --refresh
```

**Drift / selfHeal** — `kubectl -n uni-book-store scale deploy/uni-book-store-order-service --replicas=5`
→ `OutOfSync`. Uncomment `selfHeal: true` in `argocd-apps/uni-book-store.yaml`, push,
repeat the scale → Argo CD restores it.

**Synced + Degraded** — set a tag to `9.9.9`, push → `Synced` but `Degraded`
(`ImagePullBackOff`). Roll back with `git revert <commit> && git push`;
`argocd app history uni-book-store`.
