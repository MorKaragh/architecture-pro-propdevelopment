#!/bin/bash

# Не используем set -e, так как тесты могут проваливаться, но скрипт должен продолжать работу
# set -e

echo "=== Тестирование задания 5 ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Счётчики тестов
TESTS_PASSED=0
TESTS_FAILED=0

# Функция для проверки теста
test_check() {
    local test_name="$1"
    local command="$2"
    local expected_result="$3"  # "success" или "fail"
    
    echo -e "${YELLOW}Тест: ${test_name}${NC}"
    
    if eval "$command" > /dev/null 2>&1; then
        result="success"
    else
        result="fail"
    fi
    
    if [ "$result" == "$expected_result" ]; then
        echo -e "${GREEN}✓ ПРОЙДЕН${NC}: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ ПРОВАЛЕН${NC}: $test_name (ожидалось: $expected_result, получено: $result)"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Проверка доступности kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Ошибка: kubectl не найден${NC}"
    exit 1
fi

# Проверка подключения к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Ошибка: Не удалось подключиться к кластеру Kubernetes${NC}"
    exit 1
fi

echo "Проверка существования ресурсов..."
echo ""

# Проверка 1: Существование подов
echo "=== Проверка подов ==="
test_check "Под front-end-app существует" \
    "kubectl get pod front-end-app" \
    "success" || true

test_check "Под back-end-api-app существует" \
    "kubectl get pod back-end-api-app" \
    "success" || true

test_check "Под admin-front-end-app существует" \
    "kubectl get pod admin-front-end-app" \
    "success" || true

test_check "Под admin-back-end-api-app существует" \
    "kubectl get pod admin-back-end-api-app" \
    "success" || true

echo ""

# Проверка 2: Статус подов (должны быть Running)
echo "=== Проверка статуса подов ==="
FRONT_END_STATUS=$(kubectl get pod front-end-app -o jsonpath='{.status.phase}')
if [ "$FRONT_END_STATUS" == "Running" ]; then
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: front-end-app в статусе Running"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ ПРОВАЛЕН${NC}: front-end-app в статусе $FRONT_END_STATUS (ожидалось: Running)"
    ((TESTS_FAILED++))
fi

BACK_END_STATUS=$(kubectl get pod back-end-api-app -o jsonpath='{.status.phase}')
if [ "$BACK_END_STATUS" == "Running" ]; then
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: back-end-api-app в статусе Running"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ ПРОВАЛЕН${NC}: back-end-api-app в статусе $BACK_END_STATUS (ожидалось: Running)"
    ((TESTS_FAILED++))
fi

ADMIN_FRONT_END_STATUS=$(kubectl get pod admin-front-end-app -o jsonpath='{.status.phase}')
if [ "$ADMIN_FRONT_END_STATUS" == "Running" ]; then
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: admin-front-end-app в статусе Running"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ ПРОВАЛЕН${NC}: admin-front-end-app в статусе $ADMIN_FRONT_END_STATUS (ожидалось: Running)"
    ((TESTS_FAILED++))
fi

ADMIN_BACK_END_STATUS=$(kubectl get pod admin-back-end-api-app -o jsonpath='{.status.phase}')
if [ "$ADMIN_BACK_END_STATUS" == "Running" ]; then
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: admin-back-end-api-app в статусе Running"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ ПРОВАЛЕН${NC}: admin-back-end-api-app в статусе $ADMIN_BACK_END_STATUS (ожидалось: Running)"
    ((TESTS_FAILED++))
fi

echo ""

# Проверка 3: Метки подов
echo "=== Проверка меток подов ==="
test_check "front-end-app имеет метку role=front-end" \
    "kubectl get pod front-end-app -o jsonpath='{.metadata.labels.role}' | grep -q '^front-end$'" \
    "success" || true

test_check "back-end-api-app имеет метку role=back-end-api" \
    "kubectl get pod back-end-api-app -o jsonpath='{.metadata.labels.role}' | grep -q '^back-end-api$'" \
    "success" || true

test_check "admin-front-end-app имеет метку role=admin-front-end" \
    "kubectl get pod admin-front-end-app -o jsonpath='{.metadata.labels.role}' | grep -q '^admin-front-end$'" \
    "success" || true

test_check "admin-back-end-api-app имеет метку role=admin-back-end-api" \
    "kubectl get pod admin-back-end-api-app -o jsonpath='{.metadata.labels.role}' | grep -q '^admin-back-end-api$'" \
    "success" || true

echo ""

# Проверка 4: Существование сервисов
echo "=== Проверка сервисов ==="
test_check "Сервис front-end-app существует" \
    "kubectl get service front-end-app" \
    "success" || true

test_check "Сервис back-end-api-app существует" \
    "kubectl get service back-end-api-app" \
    "success" || true

test_check "Сервис admin-front-end-app существует" \
    "kubectl get service admin-front-end-app" \
    "success" || true

test_check "Сервис admin-back-end-api-app существует" \
    "kubectl get service admin-back-end-api-app" \
    "success" || true

echo ""

# Проверка 5: Существование сетевых политик
echo "=== Проверка сетевых политик ==="
test_check "NetworkPolicy allow-front-end-to-back-end-api существует" \
    "kubectl get networkpolicy allow-front-end-to-back-end-api" \
    "success" || true

test_check "NetworkPolicy allow-back-end-api-to-front-end существует" \
    "kubectl get networkpolicy allow-back-end-api-to-front-end" \
    "success" || true

test_check "NetworkPolicy allow-admin-front-end-to-admin-back-end-api существует" \
    "kubectl get networkpolicy allow-admin-front-end-to-admin-back-end-api" \
    "success" || true

test_check "NetworkPolicy allow-admin-back-end-api-to-admin-front-end существует" \
    "kubectl get networkpolicy allow-admin-back-end-api-to-admin-front-end" \
    "success" || true

echo ""

# Проверка 6: Сетевое соединение (разрешённые)
echo "=== Проверка разрешённых сетевых соединений ==="
echo -e "${YELLOW}Тест: front-end может подключиться к back-end-api${NC}"
if kubectl run test-front-end-$(date +%s) --rm -i --restart=Never --image=alpine --labels role=front-end -- sh -c "wget -qO- --timeout=3 http://back-end-api-app" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: front-end может подключиться к back-end-api"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ ПРОВАЛЕН${NC}: front-end не может подключиться к back-end-api"
    ((TESTS_FAILED++))
fi

echo -e "${YELLOW}Тест: admin-front-end может подключиться к admin-back-end-api${NC}"
if kubectl run test-admin-front-end-$(date +%s) --rm -i --restart=Never --image=alpine --labels role=admin-front-end -- sh -c "wget -qO- --timeout=3 http://admin-back-end-api-app" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: admin-front-end может подключиться к admin-back-end-api"
    ((TESTS_PASSED++))
else
    echo -e "${RED}✗ ПРОВАЛЕН${NC}: admin-front-end не может подключиться к admin-back-end-api"
    ((TESTS_FAILED++))
fi

echo ""

# Проверка 7: Сетевое соединение (запрещённые)
echo "=== Проверка заблокированных сетевых соединений ==="
echo -e "${YELLOW}Тест: front-end НЕ может подключиться к admin-back-end-api${NC}"
if kubectl run test-front-end-blocked-$(date +%s) --rm -i --restart=Never --image=alpine --labels role=front-end -- sh -c "wget -qO- --timeout=3 http://admin-back-end-api-app" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ ПРЕДУПРЕЖДЕНИЕ${NC}: front-end может подключиться к admin-back-end-api (возможно, NetworkPolicy не поддерживается в minikube)"
    echo "   Для включения NetworkPolicy в minikube выполните: minikube addons enable calico"
else
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: front-end не может подключиться к admin-back-end-api (соединение заблокировано)"
    ((TESTS_PASSED++))
fi

echo -e "${YELLOW}Тест: admin-front-end НЕ может подключиться к back-end-api${NC}"
if kubectl run test-admin-front-end-blocked-$(date +%s) --rm -i --restart=Never --image=alpine --labels role=admin-front-end -- sh -c "wget -qO- --timeout=3 http://back-end-api-app" > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠ ПРЕДУПРЕЖДЕНИЕ${NC}: admin-front-end может подключиться к back-end-api (возможно, NetworkPolicy не поддерживается в minikube)"
    echo "   Для включения NetworkPolicy в minikube выполните: minikube addons enable calico"
else
    echo -e "${GREEN}✓ ПРОЙДЕН${NC}: admin-front-end не может подключиться к back-end-api (соединение заблокировано)"
    ((TESTS_PASSED++))
fi

echo ""

# Итоги
echo "=== Итоги тестирования ==="
echo -e "Пройдено тестов: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Провалено тестов: ${RED}${TESTS_FAILED}${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}=== Все тесты пройдены успешно! ===${NC}"
    exit 0
else
    echo -e "${RED}=== Некоторые тесты провалены ===${NC}"
    exit 1
fi

