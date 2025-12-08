# Задание 5: Управление трафиком внутри кластера Kubernetes

Это задание демонстрирует использование сетевых политик (NetworkPolicy) для разграничения трафика между сервисами в кластере Kubernetes.

## Предварительные требования

1. **Kubernetes кластер** (например, minikube)
2. **kubectl** установлен и настроен
3. **CNI плагин с поддержкой NetworkPolicy** (например, Calico)

### ⚠️ Важно: Включение поддержки NetworkPolicy в minikube

По умолчанию minikube не поддерживает NetworkPolicy. Для работы сетевых политик необходимо включить CNI плагин, который их поддерживает.

**Рекомендуется использовать Calico:**

```bash
minikube addons enable calico
```

После включения аддона может потребоваться перезапуск кластера:

```bash
minikube stop
minikube start
```

> **Примечание:** Если NetworkPolicy не включен, тесты на блокировку трафика будут показывать предупреждения, но скрипты всё равно выполнятся и проверят остальные аспекты задания.

## Структура файлов

```
Task5/
├── README.md                    # Этот файл
├── task.txt                     # Описание задания
├── setup.sh                     # Скрипт подготовки среды
├── test.sh                      # Скрипт тестирования
└── non-admin-api-allow.yaml     # Файл с сетевыми политиками
```

## Порядок выполнения

### 1. Подготовка среды

Запустите скрипт `setup.sh` для автоматической подготовки среды:

```bash
cd Task5
./setup.sh
```

**Что делает скрипт:**
- Проверяет доступность kubectl и подключение к кластеру
- Удаляет существующие ресурсы (для чистой установки)
- Создаёт 4 сервиса (pods) с метками:
  - `front-end-app` (role=front-end)
  - `back-end-api-app` (role=back-end-api)
  - `admin-front-end-app` (role=admin-front-end)
  - `admin-back-end-api-app` (role=admin-back-end-api)
- Ожидает готовности всех подов
- Применяет сетевые политики из `non-admin-api-allow.yaml`
- Выводит информацию о созданных ресурсах

### 2. Тестирование

После успешной подготовки запустите скрипт `test.sh` для проверки корректности выполнения:

```bash
./test.sh
```

**Что проверяет скрипт:**
- ✅ Существование всех подов
- ✅ Статус подов (должны быть Running)
- ✅ Корректность меток на подах
- ✅ Существование всех сервисов
- ✅ Существование всех сетевых политик
- ✅ Разрешённые сетевые соединения:
  - front-end → back-end-api
  - admin-front-end → admin-back-end-api
- ✅ Заблокированные сетевые соединения:
  - front-end → admin-back-end-api (должно быть заблокировано)
  - admin-front-end → back-end-api (должно быть заблокировано)

**Результат тестирования:**
- Скрипт выводит итоговую статистику: количество пройденных и проваленных тестов
- Код возврата: 0 при успехе, 1 при наличии проваленных тестов

## Сетевые политики

Сетевые политики настроены так, чтобы разрешить трафик только между парами сервисов:

1. **front-end ↔ back-end-api** — разрешён трафик в обе стороны
2. **admin-front-end ↔ admin-back-end-api** — разрешён трафик в обе стороны
3. Все остальные соединения — заблокированы

Файл `non-admin-api-allow.yaml` содержит 4 NetworkPolicy:
- `allow-front-end-to-back-end-api`
- `allow-back-end-api-to-front-end`
- `allow-admin-front-end-to-admin-back-end-api`
- `allow-admin-back-end-api-to-admin-front-end`

## Ручное выполнение (без скриптов)

Если вы хотите выполнить задание вручную:

### Создание сервисов:

```bash
kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80
```

### Применение сетевых политик:

```bash
kubectl apply -f non-admin-api-allow.yaml
```

### Проверка соединений:

```bash
# Разрешённое соединение: front-end → back-end-api
kubectl run test-front-end --rm -i --restart=Never --image=alpine --labels role=front-end -- sh -c "wget -qO- --timeout=2 http://back-end-api-app"

# Заблокированное соединение: front-end → admin-back-end-api
kubectl run test-front-end-blocked --rm -i --restart=Never --image=alpine --labels role=front-end -- sh -c "wget -qO- --timeout=2 http://admin-back-end-api-app"
```

## Очистка ресурсов

Для удаления всех созданных ресурсов:

```bash
kubectl delete pod front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app
kubectl delete service front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app
kubectl delete networkpolicy allow-front-end-to-back-end-api allow-back-end-api-to-front-end allow-admin-front-end-to-admin-back-end-api allow-admin-back-end-api-to-admin-front-end
```

Или используйте скрипт setup.sh, который автоматически очищает ресурсы перед созданием новых.

## Устранение неполадок

### Проблема: Тесты на блокировку трафика не проходят

**Причина:** NetworkPolicy не поддерживается в текущей конфигурации кластера.

**Решение:** Включите CNI плагин с поддержкой NetworkPolicy:
```bash
minikube addons enable calico
minikube stop
minikube start
```

### Проблема: Поды не запускаются

**Причина:** Возможны проблемы с образом или ресурсами кластера.

**Решение:** 
- Проверьте доступность образа nginx: `kubectl pull nginx`
- Проверьте ресурсы кластера: `kubectl top nodes`
- Проверьте логи пода: `kubectl logs <pod-name>`

### Проблема: kubectl не найден

**Решение:** Установите kubectl согласно [официальной документации](https://kubernetes.io/docs/tasks/tools/).

## Дополнительная информация

- [Документация Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Документация Calico](https://docs.tigera.io/calico/latest/about/)
- [Minikube Addons](https://minikube.sigs.k8s.io/docs/handbook/addons/)

