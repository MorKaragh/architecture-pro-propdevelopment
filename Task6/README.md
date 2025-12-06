# Настройка аудита Kubernetes в Minikube

Этот каталог содержит политику аудита для Kubernetes и скрипты для её настройки в Minikube.

## Быстрый старт

### Способ 1: Использование скрипта setup.sh (рекомендуется)

```bash
./setup.sh
```

Скрипт автоматически:
- Удалит существующий minikube кластер (если запущен)
- Запустит minikube с политиками аудита
- Выполнит симуляцию инцидента
- Извлечет логи аудита из kube-apiserver
- Запустит анализ логов

### Способ 2: Ручной запуск

Minikube автоматически монтирует файлы из `~/.minikube/files/` в соответствующие пути внутри виртуальной машины при старте.

```bash
# 1. Создать необходимые директории
mkdir -p ~/.minikube/files/etc/ssl/certs

# 2. Скопировать файл политики
cp audit-policy.yaml ~/.minikube/files/etc/ssl/certs/audit-policy.yaml

# 3. Остановить и удалить minikube (если запущен)
minikube stop 2>/dev/null || true
minikube delete 2>/dev/null || true

# 4. Запустить minikube с параметрами аудита
minikube start \
    --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml \
    --extra-config=apiserver.audit-log-path=- \
    --extra-config=apiserver.audit-log-maxage=30 \
    --extra-config=apiserver.audit-log-maxbackup=10 \
    --extra-config=apiserver.audit-log-maxsize=100
```

**Важные особенности:**
- Файл политики должен находиться в `~/.minikube/files/etc/ssl/certs/audit-policy.yaml`
- Логи аудита выводятся в stdout kube-apiserver (параметр `audit-log-path=-`)
- Для получения логов используйте: `kubectl logs kube-apiserver-minikube -n kube-system | grep audit.k8s.io/v1`

## Просмотр логов аудита

Поскольку логи аудита выводятся в stdout kube-apiserver, их нужно извлекать из логов пода:

### Извлечение логов аудита

```bash
# Извлечь все события аудита в файл
kubectl logs kube-apiserver-minikube -n kube-system | grep audit.k8s.io/v1 > audit.log

# Просмотр в реальном времени
kubectl logs -f kube-apiserver-minikube -n kube-system | grep audit.k8s.io/v1

# Просмотр последних записей
kubectl logs kube-apiserver-minikube -n kube-system | grep audit.k8s.io/v1 | tail -n 100
```

### Анализ логов

После извлечения логов можно запустить скрипт анализа:

```bash
python3 analyze-audit.py audit.log
```

Скрипт создаст:
- `analysis.md` - отчет по результатам анализа
- `audit-extract.json` - выжимка подозрительных событий

## Параметры аудита

- `audit-policy-file` - путь к файлу политики аудита внутри minikube (`/etc/ssl/certs/audit-policy.yaml`)
- `audit-log-path` - путь к файлу логов аудита (`-` означает вывод в stdout)
- `audit-log-maxage` - количество дней хранения старых логов (30)
- `audit-log-maxbackup` - количество резервных копий логов (10)
- `audit-log-maxsize` - максимальный размер файла лога в МБ (100)

> **Примечание:** В minikube используется вывод логов в stdout (`audit-log-path=-`), так как запись в файл может быть проблематичной. Логи извлекаются из stdout kube-apiserver через `kubectl logs`.

## Описание политики аудита

Политика `audit-policy.yaml` настроена на:

1. **RequestResponse** уровень для:
   - Операций с pods, secrets, configmaps, serviceaccounts
   - Операций с RBAC ресурсами (roles, rolebindings, clusterroles, clusterrolebindings)

2. **Metadata** уровень для всех остальных ресурсов

## Проверка работы аудита

После запуска minikube выполните несколько операций:

```bash
# Создать pod
kubectl run test-pod --image=nginx

# Создать secret
kubectl create secret generic test-secret --from-literal=key=value

# Проверить логи
kubectl logs kube-apiserver-minikube -n kube-system | grep audit.k8s.io/v1 | tail -n 50 | jq .
```

Или используйте скрипт симуляции инцидента:

```bash
./simulate-incident.sh
```

## Устранение проблем

### Если minikube не запускается

1. Проверьте, что файл политики скопирован в правильное место:
   ```bash
   ls -la ~/.minikube/files/etc/ssl/certs/audit-policy.yaml
   ```

2. Проверьте, что файл политики валиден:
   ```bash
   kubectl create --dry-run=client -f audit-policy.yaml
   ```

3. Проверьте логи minikube:
   ```bash
   minikube logs
   ```

### Если логи не появляются

1. Убедитесь, что политика загружена:
   ```bash
   minikube ssh 'cat /etc/ssl/certs/audit-policy.yaml'
   ```

2. Проверьте, что kube-apiserver запущен и логи доступны:
   ```bash
   kubectl get pods -n kube-system | grep kube-apiserver
   kubectl logs kube-apiserver-minikube -n kube-system | grep -i audit
   ```

3. Проверьте, что файл политики находится в правильной директории:
   ```bash
   # Файл должен быть в ~/.minikube/files/etc/ssl/certs/audit-policy.yaml
   # Он автоматически монтируется в /etc/ssl/certs/audit-policy.yaml внутри minikube
   ls -la ~/.minikube/files/etc/ssl/certs/
   ```

4. Убедитесь, что используется правильный путь в параметрах:
   ```bash
   # Должен быть указан путь /etc/ssl/certs/audit-policy.yaml
   # а не /etc/kubernetes/audit-policy.yaml
   ```

