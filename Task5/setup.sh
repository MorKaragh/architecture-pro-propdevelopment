#!/bin/bash

# Используем set -e только для части setup, для тестов отключим
set -e

echo "=== Подготовка и тестирование задания 5 ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Проверка, что kubectl доступен
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Ошибка: kubectl не найден. Установите kubectl и повторите попытку.${NC}"
    exit 1
fi

# Проверка и запуск minikube
echo "Проверка состояния minikube..."
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Ошибка: minikube не найден. Установите minikube и повторите попытку.${NC}"
    exit 1
fi

MINIKUBE_RESTARTED=false
if ! minikube status &> /dev/null; then
    echo -e "${YELLOW}Minikube не запущен. Запускаю minikube с Calico для поддержки NetworkPolicy...${NC}"
    minikube start --network-plugin=cni --cni=calico
    MINIKUBE_RESTARTED=true
    echo -e "${GREEN}✓${NC} Minikube запущен с Calico"
else
    echo -e "${GREEN}✓${NC} Minikube уже запущен"
    
    # Проверяем, установлен ли Calico (проверяем и поды, и CNI конфигурацию)
    CALICO_ENABLED=false
    if kubectl get pods -n kube-system 2>/dev/null | grep -q "calico"; then
        CALICO_ENABLED=true
    elif kubectl get daemonset -n kube-system calico-node 2>/dev/null >/dev/null 2>&1; then
        CALICO_ENABLED=true
    elif minikube ssh -- "grep -q calico /etc/cni/net.d/*.conflist 2>/dev/null" 2>/dev/null; then
        CALICO_ENABLED=true
    fi
    
    if [ "$CALICO_ENABLED" = false ]; then
        echo -e "${YELLOW}Calico не найден. Пересоздаю кластер с Calico для поддержки NetworkPolicy...${NC}"
        echo -e "${YELLOW}Это может занять несколько минут...${NC}"
        minikube stop
        minikube delete
        minikube start --network-plugin=cni --cni=calico
        MINIKUBE_RESTARTED=true
        echo -e "${GREEN}✓${NC} Кластер пересоздан с Calico"
    else
        echo -e "${GREEN}✓${NC} Calico уже установлен"
    fi
fi

# Проверка подключения к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Ошибка: Не удалось подключиться к кластеру Kubernetes.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Подключение к кластеру установлено"

# Если minikube был перезапущен, ждем готовности Calico
if [ "$MINIKUBE_RESTARTED" = true ]; then
    echo -e "${YELLOW}Ожидание готовности Calico (это может занять 1-2 минуты)...${NC}"
    sleep 30
    
    # Ждем появления подов Calico
    for i in {1..15}; do
        # Проверяем наличие подов Calico (могут называться calico-node, calico-kube-controllers и т.д.)
        if kubectl get pods -n kube-system 2>/dev/null | grep -E "calico|tigera" | grep -q "Running"; then
            echo -e "${GREEN}✓${NC} Calico готов"
            break
        fi
        # Также проверяем CNI конфигурацию
        if minikube ssh -- "grep -q calico /etc/cni/net.d/*.conflist 2>/dev/null" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Calico CNI настроен"
            # Даем еще немного времени на запуск подов
            sleep 20
            break
        fi
        if [ $i -lt 15 ]; then
            echo -e "${YELLOW}Ожидание готовности Calico... ($i/15)${NC}"
            sleep 10
        else
            echo -e "${YELLOW}⚠ Предупреждение: Calico может еще не полностью готов${NC}"
        fi
    done
fi

# Финальная проверка Calico
CALICO_ENABLED=false
if kubectl get pods -n kube-system 2>/dev/null | grep -E "calico|tigera" | grep -q "Running"; then
    CALICO_ENABLED=true
    echo -e "${GREEN}✓${NC} Calico работает"
elif kubectl get daemonset -n kube-system calico-node 2>/dev/null >/dev/null 2>&1; then
    CALICO_ENABLED=true
    echo -e "${GREEN}✓${NC} Calico DaemonSet найден"
elif minikube ssh -- "grep -q calico /etc/cni/net.d/*.conflist 2>/dev/null" 2>/dev/null; then
    CALICO_ENABLED=true
    echo -e "${GREEN}✓${NC} Calico CNI настроен"
else
    echo -e "${YELLOW}⚠ Предупреждение: Calico может быть не полностью установлен${NC}"
    echo -e "${YELLOW}   NetworkPolicy могут не работать${NC}"
fi

echo ""

# Получаем директорию скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# ============================================
# ЧАСТЬ 1: ПОДГОТОВКА СРЕДЫ
# ============================================
echo -e "${BLUE}=== Часть 1: Подготовка среды ===${NC}"
echo ""

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
    echo -e "${RED}Ошибка: Файл $POLICY_FILE не найден!${NC}"
    exit 1
fi

kubectl apply -f "$POLICY_FILE"
echo -e "${GREEN}✓${NC} Сетевые политики применены"

# Небольшая задержка для применения политик
echo "Ожидание применения сетевых политик..."
sleep 5
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

# ============================================
# ЧАСТЬ 2: ТЕСТИРОВАНИЕ
# ============================================
# Отключаем set -e для тестов, чтобы скрипт продолжал работу даже при провале тестов
set +e

echo -e "${BLUE}=== Часть 2: Тестирование ===${NC}"
echo ""

# Запускаем тесты из отдельного файла
TEST_SCRIPT="${SCRIPT_DIR}/test.sh"
if [ -f "$TEST_SCRIPT" ]; then
    bash "$TEST_SCRIPT"
    TEST_EXIT_CODE=$?
else
    echo -e "${RED}Ошибка: Файл тестов $TEST_SCRIPT не найден!${NC}"
    TEST_EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}Нажмите Enter для выхода...${NC}"
read

# Выходим с кодом возврата тестов
exit $TEST_EXIT_CODE
