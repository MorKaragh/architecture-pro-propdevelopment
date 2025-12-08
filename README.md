# Architecture Pro PropDevelopment

## Структура проекта

### Task 1: Классификация данных

Анализ и классификация данных компании PropDevelopment по уровням конфиденциальности. Создана mind map с категоризацией данных (публичные, внутренние, конфиденциальные, секретные) и оценкой рисков для каждой категории.

**Файлы:**
- `mind-map.drawio` - диаграмма классификации данных
- `mind-map.png` - диаграмма картинкой

---

### Task 2: Чек-лист безопасности

Проверочный лист безопасности для оценки текущего состояния информационной безопасности компании. 

**Файлы:**
- `security_checklist.md` - чек-лист с ответами и комментариями

---

### Task 3: Требования к функциональности умного дома

Архитектурные требования для интеграции функциональности умного дома (интеллектуальный домофон и шлагбаум). 

**Файлы:**
- `requirements.md` - детальные требования к функциональности
- `context_and_containers.drawio` - диаграмма контекста и контейнеров
- `context.png`, `containers.png` - диаграммы картинками

---

### Task 4: Настройка RBAC для Kubernetes

Настройка ролевого доступа (RBAC) в Kubernetes кластере для различных ролей пользователей компании.

**Файлы:**
- `create-users.sh` - создание пользователей с сертификатами
- `create-roles.sh` - создание ролей и namespace
- `create-bindings.sh` - создание привязок ролей к пользователям
- `test-rbac.sh` - автоматическое тестирование RBAC
- `yaml/` - YAML конфигурации ролей и привязок

**Запуск:**

```bash
cd Task4

# 1. Создание пользователей
./create-users.sh

# 2. Создание ролей и namespace
./create-roles.sh

# 3. Создание привязок
./create-bindings.sh

# 4. Тестирование (опционально)
./test-rbac.sh
```

**Требования:**
- Kubernetes кластер (Minikube)
- `kubectl` и `openssl`
- Права администратора кластера

---

### Task 5: Управление трафиком внутри кластера Kubernetes

Демонстрация использования сетевых политик (NetworkPolicy) для разграничения трафика между сервисами в кластере Kubernetes. Настроены правила, разрешающие трафик только между определенными парами сервисов.

**Файлы:**
- `setup.sh` - скрипт подготовки среды и тестирования
- `test.sh` - скрипт тестирования (используется внутри setup.sh)
- `non-admin-api-allow.yaml` - файл с сетевыми политиками

**Запуск:**

```bash
cd Task5
./setup.sh
```

Скрипт автоматически:
- Проверяет и запускает minikube, если он не запущен
- Создаёт среду (поды, сервисы, сетевые политики)
- Проводит тестирование
- Ожидает нажатия Enter перед закрытием терминала

**Важно:** Для работы NetworkPolicy в minikube необходимо включить CNI плагин с поддержкой NetworkPolicy (например, Calico):

```bash
minikube addons enable calico
minikube stop
minikube start
```

**Требования:**
- Kubernetes кластер (Minikube)
- `kubectl`
- CNI плагин с поддержкой NetworkPolicy (Calico)

---

### Task 6: Настройка аудита Kubernetes

Настройка политики аудита для Kubernetes кластера в Minikube. Включает симуляцию инцидента безопасности и анализ логов аудита для выявления подозрительной активности.

**Файлы:**
- `setup.sh` - скрипт настройки minikube с политиками аудита
- `simulate-incident.sh` - скрипт симуляции инцидента
- `analyze-audit.py` - скрипт анализа логов аудита
- `audit-policy.yaml` - политика аудита Kubernetes
- `audit.log` - логи аудита (генерируется автоматически)
- `analysis.md` - отчет по результатам анализа (генерируется автоматически)

**Запуск:**

```bash
cd Task6

# Автоматическая настройка и запуск
./setup.sh
```

**Требования:**
- Minikube
- `kubectl`
- Python 3

---

### Task 7: Аудит безопасности подов с PodSecurity и OPA Gatekeeper

Настройка многоуровневой защиты кластера Kubernetes с использованием PodSecurity Admission и OPA Gatekeeper. Демонстрирует отклонение небезопасных манифестов и развертывание безопасных конфигураций.

**Файлы:**
- `setup.sh` - скрипт установки и настройки
- `01-create-namespace.yaml` - namespace с PodSecurity restricted
- `insecure-manifests/` - небезопасные манифесты (для тестирования)
- `secure-manifests/` - исправленные безопасные манифесты
- `gatekeeper/` - конфигурации OPA Gatekeeper (constraint templates и constraints)
- `verify/` - скрипты проверки
- `audit-policy.yaml` - политика аудита Kubernetes

**Запуск:**

```bash
cd Task7

# Полная установка и настройка
./setup.sh
```

**Требования:**
- Kubernetes кластер (Minikube)
- `kubectl`
- Доступ к интернету (для установки Gatekeeper)

---

## Общие требования

Для выполнения заданий с Kubernetes (Task 4-7) необходимо:

1. **Minikube** - локальный Kubernetes кластер
   ```bash
   minikube start
   ```

2. **kubectl** - утилита для работы с Kubernetes
   ```bash
   # Проверка версии
   kubectl version --client
   ```

3. **Python 3** (для Task 6)
   ```bash
   python3 --version
   ```

4. **openssl** (для Task 4)
   ```bash
   openssl version
   ```
