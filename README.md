apps/ — каталоги приложений/инфры. Пока положим плейсхолдеры values.yaml, позже наполним по шагам (начнём с MetalLB).

root/ — «корневые» директории для App-of-Apps.


### Настройка секрета для Postgres

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
  < secret.yaml \
  > sealed-secret.yaml
```
5. Кладём в apps/postgres/sealed-secret.yaml