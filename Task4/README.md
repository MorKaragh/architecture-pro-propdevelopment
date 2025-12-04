# Настройка RBAC для Kubernetes кластера PropDevelopment

Настройка ролевого доступа (RBAC) в Kubernetes для компании PropDevelopment.

## Структура

- `roles_table.md` - таблица ролей с описанием прав
- `create-users.sh` - создание пользователей с сертификатами
- `create-roles.sh` - создание ролей и namespace
- `create-bindings.sh` - создание привязок ролей к пользователям
- `test-rbac.sh` - автоматическое тестирование
- `yaml/` - YAML конфигурации ролей и привязок

## Быстрый старт

```bash
# 1. Создание пользователей
./create-users.sh

# 2. Создание ролей и namespace
./create-roles.sh

# 3. Создание привязок
./create-bindings.sh

# 4. Тестирование (опционально)
./test-rbac.sh
```

## Роли

- **cluster-admin** - полный доступ (DevOps, ИБ)
- **namespace-admin** - полный доступ к namespace (Product Owners)
- **developer** - управление ресурсами в namespace (Разработчики)
- **operations-engineer** - мониторинг и просмотр секретов (привилегированная)
- **viewer** - только чтение (Бизнес-аналитики, BI-аналитики, Менеджеры)
- **security-auditor** - аудит и просмотр секретов (привилегированная)

## Пользователи

| Пользователь | Роль | Namespace |
|-------------|------|-----------|
| devops-engineer | cluster-admin | Все |
| security-specialist | security-auditor | Все |
| ops-engineer | operations-engineer | Все |
| business-analyst | viewer | Все |
| product-owner-utilities | namespace-admin | tenant-services |
| developer-sales | developer | client-services |

## Проверка

```bash
# Проверка ролей
kubectl get clusterroles | grep -E "propdev-|operations-engineer|security-auditor"
kubectl get roles --all-namespaces

# Проверка привязок
kubectl get clusterrolebindings
kubectl get rolebindings --all-namespaces

# Проверка прав доступа
export KUBECONFIG=users-kubeconfig/devops-engineer-kubeconfig.yaml
kubectl auth can-i "*" "*" --all-namespaces
```

## Требования

- Kubernetes кластер (Minikube)
- `kubectl` и `openssl`
- Права администратора кластера

## Примечания

- Сертификаты и kubeconfig файлы создаются в `users-certs/` и `users-kubeconfig/`
- Для Minikube скрипт использует CA из `~/.minikube/`
