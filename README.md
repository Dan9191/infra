apps/ — каталоги приложений/инфры. Пока положим плейсхолдеры values.yaml, позже наполним по шагам (начнём с MetalLB).

root/ — «корневые» директории для App-of-Apps.


### Настройка sealed секрета на примере Postgres
В шифровании так же используется название секрета и пространство имен

1. Применение sealed-secrets.yaml
2. Забираем публичный ключ
```shell
kubeseal --fetch-cert \
  --controller-name sealed-secrets-controller \
  --controller-namespace kube-system \
  > pub-cert.pem
```
3. Создаём обычный Secret
```shell
kubectl create secret generic postgres-secret \
  --namespace postgres \
  --from-literal=postgres-password='12345' \
  --dry-run=client -o yaml > secret.yaml
```

4. Шифруем его
```shell
kubeseal \
  --cert pub-cert.pem \
  --format yaml \
  < ghcr-secret.yaml \
  > sealed-ghcr-secret.yaml
```
5. Кладём в apps/postgres/sealed-secret.yaml

### Создание постоянного админа в keycloak
1. залогиниться под admin + пароль, задаваемый при создании
2. получить pod запущенного экземпляра
```shell
kubectl  get pods -n keycloak
```
3. Подключиться к pod'у
```shell
kubectl exec -it -n keycloak keycloak-db768f54c-xtj7r -- bash
```
4. Используем kcadm.sh (на образе Keycloak он есть):
```shell
/opt/keycloak/bin/kcadm.sh config credentials \
  --server http://localhost:8080 \
  --realm master \
  --user admin \
  --password admin123
```
5. Создаём нового постоянного администратора:
```shell
/opt/keycloak/bin/kcadm.sh create users -r master -s username=admin2 -s enabled=true
/opt/keycloak/bin/kcadm.sh set-password -r master --username admin2 --new-password 'SuperSecurePass123'
```
6. Потом зашел через ui, дал пользователю admin2 роль realm-admin -> верифицировал email -> удалил admin
7. Создать Realm graduation
8. Клиенты: graduation-frontend, graduation-token
9. Роли: graduation.admin, graduation.user
10. Создать пользователя с постоянным паролем и верифицированным email

### RabbitMQ
```shell
kubectl port-forward svc/rabbitmq 15672:15672 -n rabbitmq
```

### Настройка image updater
1. Установим image updater (пример: root/image-updater.yaml)
2. Создаем токен для чтения образов: Settings → Developer settings → Personal access tokens → Tokens (classic),
выбираем права read:packages и repo
3. Генерируем секрет для выгрузки контейнеров
```shell
kubectl create secret docker-registry ghcr-secret \
   --namespace argocd \
   --docker-server=ghcr.io \
   --docker-username=Dan9191 \
   --docker-password=YOUR_GITHUB_TOKEN \
   --dry-run=client -o yaml > ghcr-secret.yaml
```
4. Запечатываем его
```shell
kubeseal \
--cert pub-cert.pem \
--format yaml \
< image-updater-git-secret.yaml \
> sealed-image-updater-git-secret.yaml
```
5. Перемещаем в apps/argocd/sealed-ghcr-secret.yaml
6. Аналогичный шаг для токена с доступом на изменение репозитория
```shell
kubectl create secret generic image-updater-git \
  --namespace argocd \
  --from-literal=username=Dan9191 \
  --from-literal=password=YOUR_GITHUB_TOKEN \
  --dry-run=client -o yaml > image-updater-git-secret.yaml
```
6. Создаем argo-cd app, чтобы добавить в кластер этот секрет (пример: root/cluster-secrets.yaml)
