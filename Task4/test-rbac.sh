#!/bin/bash

# Скрипт для тестирования RBAC конфигурации PropDevelopment
# Проверяет создание пользователей, ролей, привязок и прав доступа

# Не используем set -e, чтобы скрипт продолжал работу при ошибках в тестах

# Определяем, запущен ли скрипт напрямую или через source
# Если через source, используем return вместо exit
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Скрипт запущен напрямую
    USE_EXIT=true
else
    # Скрипт запущен через source
    USE_EXIT=false
fi

# Функция для безопасного выхода
safe_exit() {
    local code=$1
    if [ "$USE_EXIT" = true ]; then
        exit $code
    else
        return $code
    fi
}

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/users-certs"
KUBECONFIG_DIR="$SCRIPT_DIR/users-kubeconfig"

# Счётчики
TESTS_PASSED=0
TESTS_FAILED=0

# Функция для вывода результата теста
test_result() {
    local test_name=$1
    local result=$2
    local message=$3
    
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${GREEN}→${NC} $message"
        fi
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        if [ -n "$message" ]; then
            echo -e "  ${RED}→${NC} $message"
        fi
        ((TESTS_FAILED++))
    fi
}

# Функция для проверки существования файла
check_file_exists() {
    local file=$1
    if [ -f "$file" ]; then
        return 0
    else
        return 1
    fi
}

# Функция для проверки команды kubectl
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}Ошибка: kubectl не найден${NC}"
        echo -e "${YELLOW}Установите kubectl для продолжения${NC}"
        safe_exit 1
        return $?
    fi
    
    # Сбрасываем KUBECONFIG для проверки подключения к кластеру
    unset KUBECONFIG
    
    if ! kubectl cluster-info &> /dev/null; then
        echo -e "${RED}Ошибка: не удалось подключиться к кластеру${NC}"
        echo -e "${YELLOW}Убедитесь, что кластер запущен:${NC}"
        echo -e "  - Для Minikube: minikube start"
        echo -e "  - Проверьте: kubectl cluster-info"
        safe_exit 1
        return $?
    fi
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Тестирование RBAC для PropDevelopment${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Проверка kubectl
check_kubectl
test_result "Проверка подключения к кластеру" 0 "kubectl работает"

echo ""
echo -e "${YELLOW}1. Проверка создания пользователей${NC}"
echo "----------------------------------------"

# Список пользователей
declare -a USERS=(
    "devops-engineer"
    "developer-sales"
    "ops-engineer"
    "business-analyst"
    "product-owner-utilities"
    "security-specialist"
)

# Проверка сертификатов и kubeconfig файлов
for user in "${USERS[@]}"; do
    key_file="$CERTS_DIR/${user}.key"
    crt_file="$CERTS_DIR/${user}.crt"
    kubeconfig_file="$KUBECONFIG_DIR/${user}-kubeconfig.yaml"
    
    if check_file_exists "$key_file" && check_file_exists "$crt_file" && check_file_exists "$kubeconfig_file"; then
        test_result "Пользователь $user" 0 "Сертификаты и kubeconfig созданы"
    else
        test_result "Пользователь $user" 1 "Отсутствуют файлы сертификатов или kubeconfig"
    fi
done

echo ""
echo -e "${YELLOW}2. Проверка аутентификации пользователей${NC}"
echo "----------------------------------------"

# Проверка аутентификации для каждого пользователя
for user in "${USERS[@]}"; do
    kubeconfig_file="$KUBECONFIG_DIR/${user}-kubeconfig.yaml"
    
    if [ -f "$kubeconfig_file" ]; then
        export KUBECONFIG="$kubeconfig_file"
        if kubectl auth whoami &> /dev/null; then
            username=$(kubectl auth whoami 2>/dev/null | grep "Username" | awk '{print $2}')
            if [ "$username" == "$user" ]; then
                test_result "Аутентификация $user" 0 "Пользователь: $username"
            else
                test_result "Аутентификация $user" 1 "Ожидался $user, получен $username"
            fi
        else
            test_result "Аутентификация $user" 1 "Не удалось аутентифицироваться"
        fi
        unset KUBECONFIG
    fi
done

echo ""
echo -e "${YELLOW}3. Проверка namespace${NC}"
echo "----------------------------------------"

NAMESPACES=("client-services" "tenant-services" "finance" "data")

for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        test_result "Namespace $ns" 0 "Существует"
    else
        test_result "Namespace $ns" 1 "Не найден"
    fi
done

echo ""
echo -e "${YELLOW}4. Проверка ClusterRole${NC}"
echo "----------------------------------------"

declare -a CLUSTER_ROLES=(
    "propdev-cluster-admin"
    "operations-engineer"
    "security-auditor"
    "propdev-viewer"
)

for role in "${CLUSTER_ROLES[@]}"; do
    if kubectl get clusterrole "$role" &> /dev/null; then
        test_result "ClusterRole $role" 0 "Создана"
    else
        test_result "ClusterRole $role" 1 "Не найдена"
    fi
done

echo ""
echo -e "${YELLOW}5. Проверка Role в namespace${NC}"
echo "----------------------------------------"

for ns in "${NAMESPACES[@]}"; do
    for role in "developer" "namespace-admin"; do
        if kubectl get role "$role" -n "$ns" &> /dev/null; then
            test_result "Role $role в $ns" 0 "Создана"
        else
            test_result "Role $role в $ns" 1 "Не найдена"
        fi
    done
done

echo ""
echo -e "${YELLOW}6. Проверка ClusterRoleBinding${NC}"
echo "----------------------------------------"

declare -a CLUSTER_BINDINGS=(
    "devops-cluster-admin-binding"
    "security-auditor-binding"
    "operations-engineer-binding"
    "business-analyst-viewer-binding"
)

for binding in "${CLUSTER_BINDINGS[@]}"; do
    if kubectl get clusterrolebinding "$binding" &> /dev/null; then
        test_result "ClusterRoleBinding $binding" 0 "Создана"
    else
        test_result "ClusterRoleBinding $binding" 1 "Не найдена"
    fi
done

echo ""
echo -e "${YELLOW}7. Проверка RoleBinding${NC}"
echo "----------------------------------------"

if kubectl get rolebinding developer-sales-binding -n client-services &> /dev/null; then
    test_result "RoleBinding developer-sales-binding" 0 "В namespace client-services"
else
    test_result "RoleBinding developer-sales-binding" 1 "Не найдена"
fi

if kubectl get rolebinding product-owner-utilities-admin-binding -n tenant-services &> /dev/null; then
    test_result "RoleBinding product-owner-utilities-admin-binding" 0 "В namespace tenant-services"
else
    test_result "RoleBinding product-owner-utilities-admin-binding" 1 "Не найдена"
fi

echo ""
echo -e "${YELLOW}8. Проверка прав доступа${NC}"
echo "----------------------------------------"

# Проверка devops-engineer (cluster-admin)
export KUBECONFIG="$KUBECONFIG_DIR/devops-engineer-kubeconfig.yaml"
if kubectl auth can-i "*" "*" --all-namespaces &> /dev/null; then
    result=$(kubectl auth can-i "*" "*" --all-namespaces 2>/dev/null)
    if [ "$result" == "yes" ]; then
        test_result "devops-engineer: полный доступ" 0 "Cluster-admin права работают"
    else
        test_result "devops-engineer: полный доступ" 1 "Ожидался 'yes', получен '$result'"
    fi
else
    test_result "devops-engineer: полный доступ" 1 "Не удалось проверить права"
fi
unset KUBECONFIG

# Проверка ops-engineer (может читать секреты)
export KUBECONFIG="$KUBECONFIG_DIR/ops-engineer-kubeconfig.yaml"
if kubectl auth can-i get secrets --all-namespaces &> /dev/null; then
    result=$(kubectl auth can-i get secrets --all-namespaces 2>/dev/null)
    if [ "$result" == "yes" ]; then
        test_result "ops-engineer: доступ к секретам" 0 "Может читать секреты (привилегированная группа)"
    else
        test_result "ops-engineer: доступ к секретам" 1 "Ожидался 'yes', получен '$result'"
    fi
else
    test_result "ops-engineer: доступ к секретам" 1 "Не удалось проверить права"
fi
unset KUBECONFIG

# Проверка business-analyst (не может читать секреты)
export KUBECONFIG="$KUBECONFIG_DIR/business-analyst-kubeconfig.yaml"
result=$(kubectl auth can-i get secrets --all-namespaces 2>&1)
if echo "$result" | grep -q "yes"; then
    test_result "business-analyst: нет доступа к секретам" 1 "Ожидался 'no', получен 'yes'"
elif echo "$result" | grep -q "no"; then
    test_result "business-analyst: нет доступа к секретам" 0 "Правильно ограничен (viewer без секретов)"
else
    # Если команда вернула ошибку, это тоже означает отсутствие прав
    test_result "business-analyst: нет доступа к секретам" 0 "Правильно ограничен (viewer без секретов)"
fi
unset KUBECONFIG

# Проверка developer-sales (может создавать deployments в своём namespace)
export KUBECONFIG="$KUBECONFIG_DIR/developer-sales-kubeconfig.yaml"
if kubectl auth can-i create deployments -n client-services &> /dev/null; then
    result=$(kubectl auth can-i create deployments -n client-services 2>/dev/null)
    if [ "$result" == "yes" ]; then
        test_result "developer-sales: создание deployments в client-services" 0 "Права в своём namespace работают"
    else
        test_result "developer-sales: создание deployments в client-services" 1 "Ожидался 'yes', получен '$result'"
    fi
else
    test_result "developer-sales: создание deployments в client-services" 1 "Не удалось проверить права"
fi

# Проверка developer-sales (не может создавать deployments в чужом namespace)
result=$(kubectl auth can-i create deployments -n tenant-services 2>&1)
if echo "$result" | grep -q "yes"; then
    test_result "developer-sales: нет прав в tenant-services" 1 "Ожидался 'no', получен 'yes'"
elif echo "$result" | grep -q "no"; then
    test_result "developer-sales: нет прав в tenant-services" 0 "Правильно ограничен (только свой namespace)"
else
    # Если команда вернула ошибку, это тоже означает отсутствие прав
    test_result "developer-sales: нет прав в tenant-services" 0 "Правильно ограничен (только свой namespace)"
fi
unset KUBECONFIG

# Проверка security-specialist (может читать секреты)
export KUBECONFIG="$KUBECONFIG_DIR/security-specialist-kubeconfig.yaml"
if kubectl auth can-i get secrets --all-namespaces &> /dev/null; then
    result=$(kubectl auth can-i get secrets --all-namespaces 2>/dev/null)
    if [ "$result" == "yes" ]; then
        test_result "security-specialist: доступ к секретам" 0 "Может читать секреты (привилегированная группа)"
    else
        test_result "security-specialist: доступ к секретам" 1 "Ожидался 'yes', получен '$result'"
    fi
else
    test_result "security-specialist: доступ к секретам" 1 "Не удалось проверить права"
fi
unset KUBECONFIG

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Результаты тестирования${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Пройдено:${NC} $TESTS_PASSED"
echo -e "${RED}Провалено:${NC} $TESTS_FAILED"
echo ""

TOTAL_TESTS=$((TESTS_PASSED + TESTS_FAILED))
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ Все тесты пройдены успешно!${NC}"
    safe_exit 0
else
    echo -e "${RED}✗ Некоторые тесты провалились${NC}"
    echo -e "${YELLOW}Проверьте вывод выше для деталей${NC}"
    safe_exit 1
fi

