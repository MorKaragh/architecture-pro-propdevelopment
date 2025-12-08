# Task 7: Аудит безопасности подов с PodSecurity и OPA Gatekeeper

## Описание

Это задание демонстрирует настройку многоуровневой защиты кластера Kubernetes с использованием:
- **PodSecurity Admission** для базовой защиты на уровне namespace
- **OPA Gatekeeper** для расширенной политики безопасности

## Структура проекта

```
Task7/
├── 01-create-namespace.yaml          # Namespace с PodSecurity restricted
├── insecure-manifests/               # Небезопасные манифесты (для тестирования)
│   ├── 01-privileged-pod.yaml
│   ├── 02-hostpath-pod.yaml
│   └── 03-root-user-pod.yaml
├── secure-manifests/                 # Исправленные безопасные манифесты
│   ├── 01-secure.yaml
│   ├── 02-secure.yaml
│   └── 03-secure.yaml
├── gatekeeper/
│   ├── constraint-templates/         # Шаблоны политик Gatekeeper
│   │   ├── privileged.yaml
│   │   ├── hostpath.yaml
│   │   └── runasnonroot.yaml
│   └── constraints/                  # Применение политик
│       ├── privileged.yaml
│       ├── hostpath.yaml
│       └── runasnonroot.yaml
├── verify/                           # Скрипты проверки
│   ├── verify-admission.sh
│   └── validate-security.sh
├── audit-policy.yaml                 # Политика аудита Kubernetes
└── README_FOR_REVIEWER.md
```

## Требования безопасности

### PodSecurity Admission (уровень namespace)
- **enforce: restricted** — строгая политика на уровне namespace

### OPA Gatekeeper (дополнительные правила)
1. **Запрет privileged контейнеров** — `privileged: true` запрещён
2. **Требование runAsNonRoot** — контейнеры должны запускаться от непривилегированного пользователя
3. **Обязательный readOnlyRootFilesystem** — корневая файловая система только для чтения
4. **Запрет hostPath** — монтирование путей хоста запрещено

## Установка и настройка

### 1. Создание namespace

```bash
kubectl apply -f 01-create-namespace.yaml
```

### 2. Установка OPA Gatekeeper

```bash
# Установка Gatekeeper
kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml

# Ожидание готовности
kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n gatekeeper-system --timeout=90s
```

### 3. Применение Constraint Templates

```bash
kubectl apply -f gatekeeper/constraint-templates/
```

Дождитесь готовности CRD:
```bash
kubectl wait --for condition=established crd/k8srequiredsecuritycontexts.constraints.gatekeeper.sh
kubectl wait --for condition=established crd/k8srequiredvolumes.constraints.gatekeeper.sh
kubectl wait --for condition=established crd/k8srequiredrunasnonroot.constraints.gatekeeper.sh
```

### 4. Применение Constraints

```bash
kubectl apply -f gatekeeper/constraints/
```

## Тестирование

### Проверка отклонения небезопасных манифестов

```bash
# Попытка развернуть небезопасные поды (должны быть отклонены)
kubectl apply -f insecure-manifests/01-privileged-pod.yaml
# Ожидаемый результат: ошибка валидации

kubectl apply -f insecure-manifests/02-hostpath-pod.yaml
# Ожидаемый результат: ошибка валидации

kubectl apply -f insecure-manifests/03-root-user-pod.yaml
# Ожидаемый результат: ошибка валидации
```

### Развертывание безопасных манифестов

```bash
kubectl apply -f secure-manifests/
```

### Автоматическая проверка

```bash
chmod +x verify/verify-admission.sh
./verify/verify-admission.sh
```

### Детальная проверка безопасности

```bash
chmod +x verify/validate-security.sh
./verify/validate-security.sh
```

## Ожидаемые результаты

### Небезопасные манифесты должны быть отклонены

1. **01-privileged-pod.yaml** — отклонён из-за `privileged: true`
2. **02-hostpath-pod.yaml** — отклонён из-за использования `hostPath`
3. **03-root-user-pod.yaml** — отклонён из-за `runAsUser: 0`

### Безопасные манифесты должны пройти валидацию

Все три безопасных манифеста должны:
- Пройти валидацию PodSecurity Admission
- Пройти валидацию OPA Gatekeeper
- Успешно развернуться в namespace `audit-zone`

## Проверка работы Gatekeeper

```bash
# Проверка статуса constraints
kubectl get constraints -n audit-zone

# Проверка violations
kubectl describe k8srequiredsecuritycontexts require-security-contexts
kubectl describe k8srequiredvolumes forbid-hostpath
kubectl describe k8srequiredrunasnonroot require-runasnonroot
```

## Аудит

Политика аудита настроена в `audit-policy.yaml` для отслеживания:
- Создания и обновления подов в namespace `audit-zone`
- Событий Gatekeeper
- Отклонённых запросов

## Исправления в безопасных манифестах

### 01-secure.yaml (исправление privileged)
- Удалён `privileged: true`
- Добавлен `runAsNonRoot: true`
- Добавлен `readOnlyRootFilesystem: true`
- Добавлен `runAsUser: 1000`
- Добавлены writable volumes для временных файлов

### 02-secure.yaml (исправление hostPath)
- Заменён `hostPath` на `emptyDir`
- Добавлены все необходимые security contexts
- Настроены writable volumes

### 03-secure.yaml (исправление root user)
- Изменён `runAsUser: 0` на `runAsUser: 1000`
- Добавлен `runAsNonRoot: true`
- Добавлен `readOnlyRootFilesystem: true`
- Настроены writable volumes

## Примечания

- Все контейнеры используют `capabilities.drop: ["ALL"]` для минимальных привилегий
- Используется `seccompProfile.type: RuntimeDefault` для дополнительной безопасности
- Writable volumes (emptyDir) используются только для необходимых директорий (tmp, cache, run)

