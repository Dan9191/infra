# Observability Stack

Стек: **Prometheus** (метрики) + **Loki** (логи) + **Alloy** (сбор логов) + **Grafana** (визуализация).  
Всё разворачивается через ArgoCD из этого репо.

---

## Структура файлов

```
root/monitoring/
  grafana.yaml       # ArgoCD Application — Grafana (Helm)
  prometheus.yaml    # ArgoCD Application — Prometheus (Helm)
  alloy.yaml         # ArgoCD Application — Alloy (manifests из git)
  loki.yaml          # ArgoCD Application — Loki (manifests из git)

apps/observability/
  alloy/
    alloy-configmap.yaml          # конфиг Alloy (какие неймспейсы читать)
    alloy-deployment.yaml
    alloy-service-account.yaml
    alloy-cluster-role.yaml
    alloy-cluster-role-binding.yaml
    kustomization.yaml
  loki/
    loki-config.yaml              # конфиг Loki (retention и хранилище)
    loki-deployment.yaml
    loki-pvc.yaml
    loki-service.yaml
    kustomization.yaml

apps/cert-manager/
  certificate-grafana.yaml        # TLS сертификат для grafana.mos-hack.ru
```

---

## 1. ArgoCD Applications

Grafana и Prometheus деплоятся через Helm чарты напрямую из публичных репозиториев.  
Alloy и Loki — через kustomize из этого репо.

Все четыре Application лежат в `root/monitoring/` и подхватываются app-of-apps.

---

## 2. TLS сертификат для Grafana

Добавлен в `apps/cert-manager/certificate-grafana.yaml`:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: grafana-mos-hack
  namespace: observability
spec:
  secretName: grafana-tls
  dnsNames:
    - grafana.mos-hack.ru
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
```

Добавить в `apps/cert-manager/kustomization.yaml`:
```yaml
- certificate-grafana.yaml
```

> В Helm values Grafana аннотацию `cert-manager.io/cluster-issuer` **не** ставить — она конфликтует с явным Certificate.

---

## 3. Grafana

Доступна по адресу `https://grafana.mos-hack.ru`.  
Логин: `admin` / `prom-operator`.

### Datasources (задаются в Helm values, не вручную)

```yaml
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        url: http://prometheus-server.observability.svc.cluster.local
        access: proxy
        isDefault: true
      - name: Loki
        type: loki
        url: http://loki.observability.svc.cluster.local:3100
        access: proxy
```

### Дашборды (подгружаются автоматически при деплое)

| ID | Название | Datasource |
|----|----------|------------|
| 4701 | JVM (Micrometer) — heap, GC, threads, HTTP | Prometheus |
| 17175 | Spring Boot Observability — Spring Boot 3 + OTEL | Prometheus |
| 18042 | Loki Logs Explorer | Loki |

Задаются в Helm values через `dashboardProviders` + `dashboards`.  
Дашборды, добавленные вручную, **пропадут при следующем синке** (`selfHeal: true`).

---

## 4. Prometheus

Helm chart `prometheus-community/prometheus` v25.27.0.

### Retention

```yaml
server:
  retention: 14d
```

### Скрейп Spring Boot сервисов

Prometheus использует аннотации на pod template. Добавить в `deployment.yaml` каждого Spring Boot сервиса:

```yaml
template:
  metadata:
    annotations:
      prometheus.io/scrape: "true"
      prometheus.io/path: /actuator/prometheus
      prometheus.io/port: "8093"   # порт конкретного сервиса
```

В самом приложении (`application.yaml`) должно быть:

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,prometheus
  endpoint:
    prometheus:
      enabled: true
```

### Проверка что сервисы скрейпятся

```bash
kubectl port-forward svc/prometheus-server 9090:80 -n observability
```
Открыть `http://localhost:9090/targets` — graduation-сервисы должны быть в состоянии `UP`.

---

## 5. Loki

Деплоится из `apps/observability/loki/`.  
Хранилище: PVC с `local-path`, данные в `/loki/chunks`.

### Retention

В `apps/observability/loki/loki-config.yaml`:

```yaml
chunk_store_config:
  max_look_back_period: 336h   # должно совпадать с retention_period

table_manager:
  retention_deletes_enabled: true
  retention_period: 336h       # 14 дней
```

> `max_look_back_period` обязан совпадать с `retention_period` — иначе compactor не удаляет старые чанки.

### Проверка что логи доходят

```bash
kubectl port-forward svc/loki 3100:3100 -n observability
curl http://localhost:3100/ready
curl http://localhost:3100/loki/api/v1/labels
```

Если `labels` возвращает `namespace`, `pod`, `container` — логи есть.

---

## 6. Alloy

Деплоится из `apps/observability/alloy/` как Deployment (не DaemonSet).  
Использует `loki.source.kubernetes` — читает логи через Kubernetes API, не с диска ноды.

### Конфигурация неймспейсов

В `apps/observability/alloy/alloy-configmap.yaml` — список неймспейсов для сбора логов:

```alloy
discovery.kubernetes "pods" {
  role = "pod"
  namespaces {
    names = ["graduation-article", "graduation-rag", "graduation-gateway"]
  }
}
```

Добавить новый сервис — просто добавить его неймспейс в этот список.

### Лейблы которые Alloy ставит на логи

`container`, `pod`, `namespace`, `node`, `app`, `instance`, `job`

### Применение изменений конфига

После обновления ConfigMap в кластере под нужно рестартовать:

```bash
kubectl rollout restart deployment/alloy -n observability
```

### Диагностика через Alloy UI

```bash
kubectl port-forward deployment/alloy 12345:12345 -n observability
```

Открыть `http://localhost:12345` — показывает состояние каждого компонента пайплайна и количество обработанных логов.

---

## 7. Добавление нового сервиса в observability

### Метрики (Prometheus)

1. Добавить аннотации в `template.metadata` Deployment (см. раздел 4).
2. Убедиться что в приложении открыт endpoint `/actuator/prometheus`.

### Логи (Loki / Alloy)

1. Добавить неймспейс сервиса в список `names` в `alloy-configmap.yaml`.
2. Закоммитить, запушить, дождаться синка ArgoCD.
3. Рестартовать Alloy: `kubectl rollout restart deployment/alloy -n observability`.

---

## 8. Типичные проблемы

| Симптом | Причина | Решение |
|---------|---------|---------|
| Дашборд пустой, в Explore логи есть | Переменная `cluster` в дашборде пустая | Использовать дашборд 18042 вместо 15141 |
| Prometheus не скрейпит сервис | Нет аннотаций на pod template | Добавить `prometheus.io/scrape` аннотации |
| Alloy читает старые неймспейсы | ConfigMap обновился, под не рестартовал | `kubectl rollout restart deployment/alloy -n observability` |
| Вручную добавленный дашборд пропал | ArgoCD selfHeal перезаписал Grafana | Добавить дашборд в Helm values через `gnetId` |
| Loki не удаляет старые логи | `max_look_back_period` не совпадает с `retention_period` | Выставить оба значения одинаково |
