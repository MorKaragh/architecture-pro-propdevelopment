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
├── setup.sh                     # Скрипт подготовки среды и тестирования
├── test.sh                      # Скрипт тестирования (используется внутри setup.sh)
└── non-admin-api-allow.yaml     # Файл с сетевыми политиками
```

## Порядок выполнения

### Запуск задания

Запустите скрипт `setup.sh` для автоматической подготовки среды и тестирования:

```bash
cd Task5
./setup.sh
```

**Что делает скрипт:**

1. **Проверка окружения:**
   - Проверяет доступность kubectl и minikube
   - Автоматически запускает minikube, если он не запущен
   - Проверяет подключение к кластеру

2. **Подготовка среды:**
   - Удаляет существующие ресурсы (для чистой установки)
   - Создаёт 4 сервиса (pods) с метками:
     - `front-end-app` (role=front-end)
     - `back-end-api-app` (role=back-end-api)
     - `admin-front-end-app` (role=admin-front-end)
     - `admin-back-end-api-app` (role=admin-back-end-api)
   - Ожидает готовности всех подов
   - Применяет сетевые политики из `non-admin-api-allow.yaml`
   - Выводит информацию о созданных ресурсах

3. **Тестирование:**
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

**Результат:**
- Скрипт выводит итоговую статистику: количество пройденных и проваленных тестов
- В конце ожидает нажатия Enter перед закрытием терминала

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

## Очистка ресурсов

Для удаления всех созданных ресурсов:

```bash
kubectl delete pod front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app
kubectl delete service front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app
kubectl delete networkpolicy allow-front-end-to-back-end-api allow-back-end-api-to-front-end allow-admin-front-end-to-admin-back-end-api allow-admin-back-end-api-to-admin-front-end
```

Скрипт setup.sh автоматически очищает ресурсы перед созданием новых.