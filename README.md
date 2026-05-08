# infra

Kubernetes-манифесты для проекта «База знаний». GitOps через ArgoCD по схеме app-of-apps.

## Структура

```
root/                  # ArgoCD Application-манифесты (app-of-apps)
│   keycloak.yaml
│   postgres.yaml
│   rabbitmq.yaml
│   ...
│   graduation/        # микросервисы приложения
│   monitoring/        # Prometheus, Grafana, Loki, Alloy
│
apps/                  # Kubernetes-манифесты (Deployment, Service, Ingress, ...)
    keycloak/
    postgres/
    rabbitmq/
    graduation/
        frontend/
        gateway/
        article/
        rag/
        documentation/
    observability/
    cert-manager/
    metallb/
    storage/
    argocd/
```

## Gitflow

Вся работа ведётся в ветке `master`. ArgoCD отслеживает репозиторий и автоматически применяет изменения в кластер при каждом пуше.

```
git push → ArgoCD sync → kubectl apply
```

**Исключение — кастомный образ Keycloak.** При изменении файлов в `apps/keycloak/theme/` или `apps/keycloak/Dockerfile` запускается GitHub Actions:

```
push → CI build → docker push ghcr.io/dan9191/infra/keycloak:<sha>
     → CI обновляет apps/keycloak/deployment.yaml [skip ci]
     → ArgoCD sync → новый pod
```

## Sealed Secrets

Секреты шифруются через [Bitnami Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) и хранятся в репозитории.

**Получить публичный ключ кластера:**
```shell
kubeseal --fetch-cert \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system \
  > pub-cert.pem
```

**Создать и зашифровать секрет:**
```shell
kubectl create secret generic my-secret \
  --namespace my-namespace \
  --from-literal=key=value \
  --dry-run=client -o yaml > secret.yaml

kubeseal --cert pub-cert.pem --format yaml < secret.yaml > sealed-secret.yaml
```

Готовый `sealed-secret.yaml` кладётся в соответствующую папку в `apps/` и коммитится.

## Keycloak

После первого деплоя кастомной темы нужно вручную включить её в админке:

**Realm `graduation`** → Realm settings → Themes → Login theme → `graduation` → Save

Создание постоянного администратора (выполняется один раз):
```shell
kubectl exec -it -n keycloak <pod-name> -- bash

/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 --realm master \
  --user admin --password <password>

/opt/keycloak/bin/kcadm.sh create users -r master -s username=admin2 -s enabled=true
/opt/keycloak/bin/kcadm.sh set-password -r master --username admin2 --new-password '<password>'
```

Затем в UI: дать `admin2` роль `realm-admin` → верифицировать email → удалить временного `admin`.