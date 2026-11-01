# uni-book-store — Helm chart

Helm-чарт для всього стека **uni-book-store**, у паритеті з `docker compose`:
два мікросервіси Spring Boot (**book-management-service**, **order-service**),
React-SPA за nginx-шлюзом, PostgreSQL, Keycloak (+ власна БД), ActiveMQ та
LocalStack (S3). Параметризований для кількох середовищ (dev / prod).

## version vs appVersion

Два **незалежні** номери в `Chart.yaml`:

| Поле | Що версіонує | Значення |
|------|--------------|----------|
| `version` | сам **чарт** (пакування: шаблони, values) — підіймається при зміні чарта | `0.1.0` |
| `appVersion` | **застосунок**, який чарт розгортає (backend-образ) | `1.0.0` |

Приклад: правка шаблону без зміни коду → `version 0.1.0 → 0.2.0`, `appVersion` незмінний.
Нова версія застосунку → `appVersion 1.0.0 → 1.1.0`. `appVersion` також використовується як
**дефолтний тег образів** сервісів (`*.image.tag` = `.Chart.AppVersion`, якщо порожній).

## Параметри values

| Параметр | Опис | Default (dev) |
|----------|------|---------------|
| `bookManagement.replicaCount` | репліки book-management-service | `1` |
| `bookManagement.image.repository` / `.tag` | образ / тег (порожній → `appVersion`) | `book-management-service` / `1.0.0` |
| `bookManagement.containerPort` / `.service.port` | порт контейнера / Service | `8081` |
| `orderService.replicaCount` | репліки order-service | `1` |
| `orderService.image.repository` / `.tag` | образ / тег | `order-service` / `1.0.0` |
| `orderService.containerPort` / `.service.port` | порт контейнера / Service | `8083` |
| `frontend.image.repository` / `.tag` | образ SPA-шлюзу / тег | `uni-book-store-frontend` / `1.0.0` |
| `frontend.service.type` / `.nodePort` | тип Service / фіксований NodePort | `NodePort` / `30081` |
| `config.*` | спільні env (S3_REGION, S3_BUCKET, MANAGEMENT_*) | див. values.yaml |
| `secrets.s3AccessKey` / `.s3SecretKey` | ключі LocalStack (demo) | `test` / `test` |
| `postgres.auth.*` | БД застосунку (database/username/password) | `mydatabase` / `myuser` / demo |
| `postgres.persistence.enabled` / `.size` | **прапорець** PVC / розмір | `true` / `1Gi` |
| `activemq.image` / `.openwirePort` / `.consolePort` | брокер ActiveMQ | `apache/activemq-classic:6.2.0` / `61616` / `8161` |
| `localstack.image` / `.port` | емуляція S3 | `localstack/localstack:3` / `4566` |
| `keycloak.image` / `.adminUser` / `.adminPassword` | Keycloak (demo-креденшли) | `quay.io/keycloak/keycloak:25.0` / `admin` / `admin` |
| `keycloak.hostAliasIp` | IP вузла для `hostAlias` issuer-хоста (порожній → без alias) | `192.168.49.2` |
| `keycloakDb.auth.*` / `.persistence.*` | БД Keycloak / PVC | `keycloak` / `true` |
| `ingress.enabled` / `.className` | **прапорець** Ingress / IngressClass | `true` / `nginx` |
| `ingress.frontendHost` | хост SPA (точка входу) | `uni-book-store.local` |
| `ingress.keycloakHost` | хост Keycloak (спільний issuer) | `keycloak.local` |
| `postgresql.enabled` | увімкнути залежний чарт PostgreSQL (bitnami, Задача 9a) | `false` |

> **Чутливі значення** (`postgres.auth.password`, `keycloak.*Password`, S3-ключі) беруться
> з values і потрапляють у Secret — у шаблонах паролів немає. Реальні паролі у файлах
> значень **не зберігаються**.
>
> **Issuer Keycloak:** і браузер, і сервіси звертаються до одного хоста
> (`ingress.keycloakHost`), тому `iss` у токені збігається з валідацією на бекенді.
> Поди сервісів резолвлять цей хост у вузол через `hostAlias` (`keycloak.hostAliasIp`,
> зазвичай `minikube ip`).

## Встановлення

### dev

```bash
helm install uni-book-store helm/ -f helm/values-dev.yaml \
  --namespace uni-book-store --create-namespace
```

Легке середовище: 1 репліка, образ `1.0.0`, Ingress вимкнено (доступ через NodePort /
`minikube service`), ефемерна БД.

### prod

```bash
helm install uni-book-store-prod helm/ -f helm/values-prod.yaml \
  --namespace uni-book-store-prod --create-namespace
```

Важче середовище: 3 репліки, образ `1.1.0`, Ingress увімкнено
(`uni-book-store.example.com`), ClusterIP, durable БД (PVC 5Gi).

### Пріоритет значень

```
values.yaml  <  -f файл  <  --set
(дефолти)       (середовище)   (точкове перевизначення)
```

Приклад: `helm install ... -f helm/values-prod.yaml --set orderService.replicaCount=5`
→ `replicaCount = 5` (бо `--set` має найвищий пріоритет).

## Залежність (Задача 9a)

Чарт має необовʼязкову залежність від офіційного **bitnami/postgresql**
(`Chart.yaml → dependencies`, умова `postgresql.enabled`):

```bash
helm dependency update helm/     # завантажити залежність у helm/charts/
helm dependency list helm/
helm install uni-book-store helm/ -n uni-book-store --create-namespace \
  --set postgresql.enabled=true
```

Налаштовується через значення батьківського чарта (ключі `postgresql.*`).

## Життєвий цикл релізу

```bash
helm upgrade uni-book-store helm/ -f helm/values-dev.yaml --set orderService.image.tag=1.1.0 -n uni-book-store
helm history  uni-book-store -n uni-book-store
helm rollback uni-book-store 1 -n uni-book-store
helm uninstall uni-book-store -n uni-book-store
```

---

## Підтвердження виконання (скриншоти)

### 7. Перевірка та встановлення чарта

**7a — `helm lint`:**

![helm lint](../docs/lab4/img/7a-lint.webp)

**7b — `helm template` (порівняння з Lab 3):**

![helm template](../docs/lab4/img/7b-template.webp)

**7c — встановлення релізу + поди Running:**

![helm install](../docs/lab4/img/7c-install.webp)
![pods running](../docs/lab4/img/7c-pods-running.webp)

**7d — список/статус/значення релізу:**

![helm status + resources](../docs/lab4/img/7d-status-resources.webp)
![helm get values](../docs/lab4/img/7d-values.webp)

**7e — де Helm зберігає стан (Secret `helm.sh/release.v1`):**

![release secret](../docs/lab4/img/7e-release-secret.webp)

### 8. Життєвий цикл релізу

**8a — `--set` тег образу (ревізія 2):**

![upgrade --set tag](../docs/lab4/img/8a-upgrade-set-tag.webp)

**8b — `-f values-prod.yaml` (ревізія 3):**

![upgrade -f prod](../docs/lab4/img/8b-upgrade-prod.webp)

**8c — історія ревізій:**

![helm history](../docs/lab4/img/8c-history.webp)

**8d — відкат:**

![helm rollback](../docs/lab4/img/8d-rollback.webp)

**8e — видалення релізу:**

![helm uninstall](../docs/lab4/img/8e-uninstall.webp)

### 9a. Залежність від стороннього чарта (bitnami/postgresql)

![helm dependency](../docs/lab4/img/9a-dependency.webp)
![install з subchart](../docs/lab4/img/9a-install-subchart.webp)
