#!/bin/bash

# Скрипт для создания пользователей Kubernetes с сертификатами
# Создаёт реальных пользователей для PropDevelopment

set -e

# Цвета для вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="$SCRIPT_DIR/users-certs"
KUBECONFIG_DIR="$SCRIPT_DIR/users-kubeconfig"

echo -e "${GREEN}Создание пользователей Kubernetes для PropDevelopment...${NC}"
echo ""

# Список пользователей и их групп
declare -A USERS=(
    ["devops-engineer"]="devops"
    ["developer-sales"]="developers:client-services"
    ["ops-engineer"]="operations"
    ["business-analyst"]="viewers"
    ["product-owner-utilities"]="product-owners:tenant-services"
    ["security-specialist"]="security"
)

# Создаём директории для сертификатов и kubeconfig
mkdir -p "$CERTS_DIR"
mkdir -p "$KUBECONFIG_DIR"

# Определяем путь к CA сертификатам Minikube
MINIKUBE_CA_CERT="${HOME}/.minikube/ca.crt"
MINIKUBE_CA_KEY="${HOME}/.minikube/ca.key"

# Проверяем наличие CA сертификатов
if [ ! -f "$MINIKUBE_CA_CERT" ] || [ ! -f "$MINIKUBE_CA_KEY" ]; then
    echo -e "${RED}Ошибка: CA сертификаты Minikube не найдены!${NC}"
    echo "Ожидаемые файлы:"
    echo "  - $MINIKUBE_CA_CERT"
    echo "  - $MINIKUBE_CA_KEY"
    echo ""
    echo "Убедитесь, что Minikube запущен: minikube start"
    exit 1
fi

# Получаем информацию о кластере
CLUSTER_NAME=$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')
CLUSTER_SERVER=$(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

if [ -z "$CLUSTER_NAME" ] || [ -z "$CLUSTER_SERVER" ]; then
    echo -e "${RED}Ошибка: Не удалось определить параметры кластера${NC}"
    exit 1
fi

echo -e "${YELLOW}Используется кластер: ${CLUSTER_NAME}${NC}"
echo -e "${YELLOW}Сервер: ${CLUSTER_SERVER}${NC}"
echo ""

# Функция для создания пользователя
create_user() {
    local username=$1
    local group=$2
    
    echo -e "${BLUE}Создание пользователя: $username (группа: $group)${NC}"
    
    # 1. Генерируем приватный ключ
    openssl genrsa -out "$CERTS_DIR/${username}.key" 2048 2>/dev/null
    
    # 2. Создаём запрос на сертификат (CSR)
    openssl req -new -key "$CERTS_DIR/${username}.key" \
        -out "$CERTS_DIR/${username}.csr" \
        -subj "/CN=${username}/O=${group}" 2>/dev/null
    
    # 3. Подписываем сертификат с помощью CA Minikube
    openssl x509 -req -in "$CERTS_DIR/${username}.csr" \
        -CA "$MINIKUBE_CA_CERT" \
        -CAkey "$MINIKUBE_CA_KEY" \
        -CAcreateserial \
        -out "$CERTS_DIR/${username}.crt" \
        -days 365 \
        -extensions v3_req \
        -extfile <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
EOF
) 2>/dev/null
    
    # 4. Создаём kubeconfig файл для пользователя
    KUBECONFIG_FILE="$KUBECONFIG_DIR/${username}-kubeconfig.yaml"
    
    # Устанавливаем credentials
    kubectl config set-credentials "$username" \
        --client-certificate="$CERTS_DIR/${username}.crt" \
        --client-key="$CERTS_DIR/${username}.key" \
        --kubeconfig="$KUBECONFIG_FILE" \
        >/dev/null 2>&1
    
    # Устанавливаем cluster
    kubectl config set-cluster "$CLUSTER_NAME" \
        --server="$CLUSTER_SERVER" \
        --certificate-authority="$MINIKUBE_CA_CERT" \
        --embed-certs=true \
        --kubeconfig="$KUBECONFIG_FILE" \
        >/dev/null 2>&1
    
    # Устанавливаем context
    kubectl config set-context "${username}-context" \
        --cluster="$CLUSTER_NAME" \
        --user="$username" \
        --kubeconfig="$KUBECONFIG_FILE" \
        >/dev/null 2>&1
    
    # Устанавливаем текущий context
    kubectl config use-context "${username}-context" \
        --kubeconfig="$KUBECONFIG_FILE" \
        >/dev/null 2>&1
    
    echo -e "  ${GREEN}✓${NC} Приватный ключ: $CERTS_DIR/${username}.key"
    echo -e "  ${GREEN}✓${NC} Сертификат: $CERTS_DIR/${username}.crt"
    echo -e "  ${GREEN}✓${NC} Kubeconfig: $KUBECONFIG_FILE"
    echo ""
}

# Создаём всех пользователей
for user in "${!USERS[@]}"; do
    create_user "$user" "${USERS[$user]}"
done

# Очищаем временные CSR файлы
rm -f "$CERTS_DIR"/*.csr

echo -e "${GREEN}✓ Все пользователи созданы!${NC}"
echo ""
echo -e "${YELLOW}Созданные файлы:${NC}"
echo "  Сертификаты: $CERTS_DIR/"
echo "  Kubeconfig:  $KUBECONFIG_DIR/"
echo ""
echo -e "${YELLOW}Использование kubeconfig файлов:${NC}"
echo ""
for user in "${!USERS[@]}"; do
    echo "  # Использовать kubeconfig для пользователя $user:"
    echo "  export KUBECONFIG=$KUBECONFIG_DIR/${user}-kubeconfig.yaml"
    echo "  kubectl get pods"
    echo ""
done

echo -e "${YELLOW}Или добавить в текущий kubeconfig:${NC}"
echo ""
for user in "${!USERS[@]}"; do
    echo "  kubectl config set-credentials $user \\"
    echo "    --client-certificate=$CERTS_DIR/${user}.crt \\"
    echo "    --client-key=$CERTS_DIR/${user}.key"
    echo ""
    echo "  kubectl config set-context ${user}-context \\"
    echo "    --cluster=$CLUSTER_NAME \\"
    echo "    --user=$user"
    echo ""
done

echo -e "${YELLOW}Переключение между пользователями:${NC}"
echo "  kubectl config use-context <username>-context"
echo ""
echo -e "${GREEN}Список пользователей для использования в RoleBinding/ClusterRoleBinding:${NC}"
for user in "${!USERS[@]}"; do
    echo "  - $user"
done
