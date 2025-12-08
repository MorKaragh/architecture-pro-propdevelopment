#!/bin/bash

set -e

echo "=== Подготовка среды для задания 5 ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Проверка, что kubectl доступен
if ! command -v kubectl &> /dev/null; then
    echo "Ошибка: kubectl не найден. Установите kubectl и повторите попытку."
    exit 1
fi

# Проверка подключения к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo "Ошибка: Не удалось подключиться к кластеру Kubernetes."
    exit 1
fi

echo -e "${GREEN}✓${NC} Подключение к кластеру установлено"
echo ""

# Получаем директорию скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Удаляем существующие ресурсы, если они есть (для чистой установки)
echo "Очистка существующих ресурсов (если есть)..."
kubectl delete pod front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app 2>/dev/null || true
kubectl delete service front-end-app back-end-api-app admin-front-end-app admin-back-end-api-app 2>/dev/null || true
kubectl delete networkpolicy allow-front-end-to-back-end-api allow-back-end-api-to-front-end allow-admin-front-end-to-admin-back-end-api allow-admin-back-end-api-to-admin-front-end 2>/dev/null || true
echo ""

# Создание сервисов с метками
echo "Создание сервисов..."
echo -e "${YELLOW}Создание front-end-app...${NC}"
kubectl run front-end-app --image=nginx --labels role=front-end --expose --port 80

echo -e "${YELLOW}Создание back-end-api-app...${NC}"
kubectl run back-end-api-app --image=nginx --labels role=back-end-api --expose --port 80

echo -e "${YELLOW}Создание admin-front-end-app...${NC}"
kubectl run admin-front-end-app --image=nginx --labels role=admin-front-end --expose --port 80

echo -e "${YELLOW}Создание admin-back-end-api-app...${NC}"
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80

echo ""
echo "Ожидание готовности подов..."
kubectl wait --for=condition=ready pod -l role=front-end --timeout=60s
kubectl wait --for=condition=ready pod -l role=back-end-api --timeout=60s
kubectl wait --for=condition=ready pod -l role=admin-front-end --timeout=60s
kubectl wait --for=condition=ready pod -l role=admin-back-end-api --timeout=60s

echo -e "${GREEN}✓${NC} Все поды готовы"
echo ""

# Применение сетевых политик
echo "Применение сетевых политик..."
POLICY_FILE="${SCRIPT_DIR}/non-admin-api-allow.yaml"

if [ ! -f "$POLICY_FILE" ]; then
    echo "Ошибка: Файл $POLICY_FILE не найден!"
    exit 1
fi

kubectl apply -f "$POLICY_FILE"
echo -e "${GREEN}✓${NC} Сетевые политики применены"
echo ""

# Вывод информации о созданных ресурсах
echo "=== Созданные ресурсы ==="
echo ""
echo "Поды:"
kubectl get pods -l role
echo ""
echo "Сервисы:"
kubectl get services -l role
echo ""
echo "Сетевые политики:"
kubectl get networkpolicies
echo ""

echo -e "${GREEN}=== Подготовка среды завершена успешно! ===${NC}"
echo ""
echo "Для тестирования запустите: ./test.sh"

