#!/bin/bash

# Скрипт для создания RoleBinding и ClusterRoleBinding
# Применяет YAML файлы из директории yaml/bindings/

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINDINGS_DIR="$SCRIPT_DIR/yaml/bindings"

echo -e "${GREEN}Создание привязок ролей к пользователям...${NC}"
echo ""

# Проверка наличия kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Ошибка: kubectl не найден. Установите kubectl для продолжения.${NC}"
    exit 1
fi

# Применение ClusterRoleBinding
echo -e "${YELLOW}Применение ClusterRoleBinding...${NC}"
CLUSTER_BINDINGS_DIR="$BINDINGS_DIR/clusterrolebindings"
if [ -d "$CLUSTER_BINDINGS_DIR" ]; then
    for yaml_file in "$CLUSTER_BINDINGS_DIR"/*.yaml; do
        if [ -f "$yaml_file" ]; then
            binding_name=$(grep -E "^  name:" "$yaml_file" | head -1 | awk '{print $2}')
            echo -e "  Применение: $(basename "$yaml_file") (${binding_name})"
            kubectl apply -f "$yaml_file"
        fi
    done
else
    echo -e "${RED}  Ошибка: директория $CLUSTER_BINDINGS_DIR не найдена${NC}"
    exit 1
fi
echo ""

# Применение RoleBinding
echo -e "${YELLOW}Применение RoleBinding...${NC}"
ROLE_BINDINGS_DIR="$BINDINGS_DIR/rolebindings"
if [ -d "$ROLE_BINDINGS_DIR" ]; then
    for yaml_file in "$ROLE_BINDINGS_DIR"/*.yaml; do
        if [ -f "$yaml_file" ]; then
            binding_name=$(grep -E "^  name:" "$yaml_file" | head -1 | awk '{print $2}')
            namespace=$(grep -E "^  namespace:" "$yaml_file" | head -1 | awk '{print $2}')
            echo -e "  Применение: $(basename "$yaml_file") (${binding_name}) в namespace: ${namespace}"
            kubectl apply -f "$yaml_file"
        fi
    done
else
    echo -e "${RED}  Ошибка: директория $ROLE_BINDINGS_DIR не найдена${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✓ Все привязки созданы!${NC}"
echo ""
echo -e "${YELLOW}Созданные ClusterRoleBinding:${NC}"
kubectl get clusterrolebindings | grep -E "devops-|security-|operations-|business-analyst-" || true
echo ""
echo -e "${YELLOW}Созданные RoleBinding:${NC}"
kubectl get rolebindings --all-namespaces | grep -E "product-owner-|developer-sales" || true
echo ""
echo -e "${YELLOW}Проверка привязок:${NC}"
echo "  kubectl get clusterrolebindings"
echo "  kubectl get rolebindings --all-namespaces"
echo "  kubectl describe clusterrolebinding <binding-name>"
echo "  kubectl describe rolebinding <binding-name> -n <namespace>"
