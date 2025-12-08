#!/bin/bash

# Диагностический скрипт для проверки Calico

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Диагностика Calico ===${NC}"
echo ""

# 1. Проверка minikube
echo -e "${BLUE}1. Проверка minikube:${NC}"
if minikube status &> /dev/null; then
    echo -e "${GREEN}✓${NC} Minikube запущен"
    minikube status
else
    echo -e "${RED}✗${NC} Minikube не запущен"
    exit 1
fi
echo ""

# 2. Проверка подов Calico
echo -e "${BLUE}2. Проверка подов Calico:${NC}"
CALICO_PODS=$(kubectl get pods -n kube-system 2>/dev/null | grep -E "calico|tigera" || echo "")
if [ -n "$CALICO_PODS" ]; then
    echo -e "${GREEN}✓${NC} Найдены поды Calico:"
    echo "$CALICO_PODS"
else
    echo -e "${RED}✗${NC} Поды Calico не найдены"
fi
echo ""

# 3. Проверка DaemonSet Calico
echo -e "${BLUE}3. Проверка DaemonSet Calico:${NC}"
if kubectl get daemonset -n kube-system calico-node 2>/dev/null >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} DaemonSet calico-node найден:"
    kubectl get daemonset -n kube-system calico-node
else
    echo -e "${RED}✗${NC} DaemonSet calico-node не найден"
fi
echo ""

# 4. Проверка CNI конфигурации
echo -e "${BLUE}4. Проверка CNI конфигурации:${NC}"
CNI_CONFIG=$(minikube ssh -- "cat /etc/cni/net.d/*.conflist 2>/dev/null | grep -i calico" 2>/dev/null || echo "")
if [ -n "$CNI_CONFIG" ]; then
    echo -e "${GREEN}✓${NC} Calico найден в CNI конфигурации:"
    minikube ssh -- "cat /etc/cni/net.d/*.conflist 2>/dev/null | grep -A 5 -B 5 -i calico" 2>/dev/null
else
    echo -e "${RED}✗${NC} Calico не найден в CNI конфигурации"
    echo "Текущая CNI конфигурация:"
    minikube ssh -- "cat /etc/cni/net.d/*.conflist 2>/dev/null" 2>/dev/null | head -20
fi
echo ""

# 5. Проверка NetworkPolicy
echo -e "${BLUE}5. Проверка NetworkPolicy:${NC}"
NP_COUNT=$(kubectl get networkpolicies -n default 2>/dev/null | wc -l)
if [ "$NP_COUNT" -gt 1 ]; then
    echo -e "${GREEN}✓${NC} Найдено NetworkPolicy: $((NP_COUNT - 1))"
    kubectl get networkpolicies -n default
else
    echo -e "${YELLOW}⚠${NC} NetworkPolicy не найдены"
fi
echo ""

# 6. Тест NetworkPolicy
echo -e "${BLUE}6. Тест работы NetworkPolicy:${NC}"
if kubectl get pods -n default front-end-app 2>/dev/null >/dev/null 2>&1; then
    echo "Проверяю блокировку трафика..."
    if kubectl run test-calico-check-$(date +%s) --rm -i --restart=Never --image=alpine --labels role=front-end -- sh -c "wget -qO- --timeout=2 http://admin-back-end-api-app" > /dev/null 2>&1; then
        echo -e "${RED}✗${NC} NetworkPolicy НЕ работают - трафик не заблокирован"
    else
        echo -e "${GREEN}✓${NC} NetworkPolicy работают - трафик заблокирован"
    fi
else
    echo -e "${YELLOW}⚠${NC} Тестовые поды не найдены. Запустите setup.sh сначала."
fi
echo ""

# Итог
echo -e "${BLUE}=== Итоговая диагностика ===${NC}"
CALICO_WORKING=false
if kubectl get pods -n kube-system 2>/dev/null | grep -E "calico|tigera" | grep -q "Running"; then
    CALICO_WORKING=true
fi

if [ "$CALICO_WORKING" = true ]; then
    echo -e "${GREEN}✓${NC} Calico установлен и работает"
else
    echo -e "${RED}✗${NC} Calico не работает"
    echo ""
    echo -e "${YELLOW}Рекомендации:${NC}"
    echo "1. Остановите minikube: minikube stop"
    echo "2. Удалите кластер: minikube delete"
    echo "3. Запустите с Calico: minikube start --network-plugin=cni --cni=calico"
    echo "Или просто запустите: ./setup.sh"
fi

