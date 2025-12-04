#!/bin/bash

# Скрипт для создания ролей и ClusterRole в Kubernetes
# Применяет YAML файлы из директории yaml/roles/

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROLES_DIR="$SCRIPT_DIR/yaml/roles"

echo -e "${GREEN}Создание ролей Kubernetes...${NC}"
echo ""

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Ошибка: kubectl не найден. Установите kubectl для продолжения.${NC}"
    exit 1
fi

# Создание namespace для доменов
NAMESPACES=("client-services" "tenant-services" "finance" "data")

echo -e "${YELLOW}Создание namespace для доменов...${NC}"
for ns in "${NAMESPACES[@]}"; do
    if kubectl get namespace "$ns" &> /dev/null; then
        echo -e "  Namespace ${ns} уже существует"
    else
        kubectl create namespace "$ns"
        echo -e "  ✓ Создан namespace: ${ns}"
    fi
done
echo ""

# Применение ClusterRole
echo -e "${YELLOW}Применение ClusterRole...${NC}"
CLUSTER_ROLES_DIR="$ROLES_DIR/clusterroles"
if [ -d "$CLUSTER_ROLES_DIR" ]; then
    for yaml_file in "$CLUSTER_ROLES_DIR"/*.yaml; do
        if [ -f "$yaml_file" ]; then
            role_name=$(grep -E "^  name:" "$yaml_file" | head -1 | awk '{print $2}')
            echo -e "  Применение: $(basename "$yaml_file") (${role_name})"
            kubectl apply -f "$yaml_file"
        fi
    done
else
    echo -e "${RED}  Ошибка: директория $CLUSTER_ROLES_DIR не найдена${NC}"
    exit 1
fi
echo ""

# Применение Role для каждого namespace
echo -e "${YELLOW}Применение Role для каждого namespace...${NC}"
ROLES_DIR_LOCAL="$ROLES_DIR/roles"
if [ -d "$ROLES_DIR_LOCAL" ]; then
    for yaml_template in "$ROLES_DIR_LOCAL"/*.yaml; do
        if [ -f "$yaml_template" ]; then
            role_name=$(grep -E "^  name:" "$yaml_template" | head -1 | awk '{print $2}')
            for ns in "${NAMESPACES[@]}"; do
                # Создаём временный файл с подстановкой namespace
                temp_file=$(mktemp)
                sed "s/NAMESPACE_PLACEHOLDER/$ns/g" "$yaml_template" > "$temp_file"
                
                echo -e "  Применение: $(basename "$yaml_template") -> namespace: ${ns} (${role_name})"
                kubectl apply -f "$temp_file"
                rm "$temp_file"
            done
        fi
    done
else
    echo -e "${RED}  Ошибка: директория $ROLES_DIR_LOCAL не найдена${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Все роли созданы!${NC}"
echo ""
echo -e "${YELLOW}Созданные ClusterRole:${NC}"
kubectl get clusterroles | grep -E "propdev-|operations-engineer|security-auditor" || true
echo ""
echo -e "${YELLOW}Созданные Role:${NC}"
for ns in "${NAMESPACES[@]}"; do
    echo "  Namespace: $ns"
    kubectl get roles -n "$ns" 2>/dev/null | tail -n +2 || echo "    (нет ролей)"
done
