#!/bin/bash

# Не используем set -e, чтобы иметь контроль над обработкой ошибок
set +e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NAMESPACE="audit-zone"
GATEKEEPER_NAMESPACE="gatekeeper-system"

# Функции для красивого вывода
print_header() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════════════${NC}\n"
}

print_step() {
    echo -e "${BOLD}${BLUE}▶${NC} ${BOLD}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

# Функция очистки
cleanup() {
    print_header "Очистка существующих ресурсов"
    
    # Удаление подов из audit-zone
    if kubectl get namespace $NAMESPACE &>/dev/null; then
        print_step "Удаление подов из namespace $NAMESPACE..."
        kubectl delete pods --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
        sleep 2
    fi
    
    # Удаление constraints
    print_step "Удаление Gatekeeper constraints..."
    kubectl delete -f gatekeeper/constraints/ --ignore-not-found=true 2>/dev/null || true
    sleep 2
    
    # Удаление constraint templates
    print_step "Удаление Gatekeeper constraint templates..."
    kubectl delete -f gatekeeper/constraint-templates/ --ignore-not-found=true 2>/dev/null || true
    sleep 3
    
    # Удаление namespace
    print_step "Удаление namespace $NAMESPACE..."
    kubectl delete namespace $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    sleep 2
    
    print_success "Очистка завершена"
}

# Функция установки Gatekeeper
install_gatekeeper() {
    print_header "Установка OPA Gatekeeper"
    
    if kubectl get namespace $GATEKEEPER_NAMESPACE &>/dev/null; then
        print_info "Gatekeeper уже установлен, пропускаем установку"
    else
        print_step "Установка Gatekeeper..."
        kubectl apply -f https://raw.githubusercontent.com/open-policy-agent/gatekeeper/release-3.14/deploy/gatekeeper.yaml
        
        print_step "Ожидание готовности Gatekeeper..."
        if kubectl wait --for=condition=ready pod -l control-plane=controller-manager -n $GATEKEEPER_NAMESPACE --timeout=120s 2>/dev/null; then
            print_success "Gatekeeper готов"
        else
            print_error "Gatekeeper не готов в течение 120 секунд"
            exit 1
        fi
    fi
}

# Функция настройки
setup() {
    print_header "Настройка безопасности"
    
    # Создание namespace
    print_step "Создание namespace $NAMESPACE с PodSecurity restricted..."
    kubectl apply -f 01-create-namespace.yaml
    print_success "Namespace создан"
    
    # Применение constraint templates
    print_step "Применение Constraint Templates..."
    kubectl apply -f gatekeeper/constraint-templates/
    print_success "Constraint Templates применены"
    
    # Ожидание готовности CRD
    print_step "Ожидание готовности CRD..."
    kubectl wait --for condition=established \
        crd/k8srequiredsecuritycontexts.constraints.gatekeeper.sh \
        crd/k8srequiredvolumes.constraints.gatekeeper.sh \
        crd/k8srequiredrunasnonroot.constraints.gatekeeper.sh \
        --timeout=60s 2>/dev/null || true
    print_success "CRD готовы"
    
    # Применение constraints
    print_step "Применение Constraints..."
    kubectl apply -f gatekeeper/constraints/
    print_success "Constraints применены"
    
    sleep 2
}

# Функция тестирования
test_insecure_manifests() {
    print_header "Тестирование небезопасных манифестов"
    
    local failed=0
    local passed=0
    
    # Тест 1: Privileged pod
    print_step "Тест 1: Privileged pod (должен быть отклонён)"
    output=$(kubectl apply -f insecure-manifests/01-privileged-pod.yaml 2>&1)
    if echo "$output" | grep -iE "(forbidden|denied|violation|error)" > /dev/null; then
        print_success "Privileged pod отклонён (как и ожидалось)"
        ((passed++))
    else
        print_error "Privileged pod НЕ был отклонён!"
        kubectl delete -f insecure-manifests/01-privileged-pod.yaml --ignore-not-found=true 2>/dev/null || true
        ((failed++))
    fi
    
    # Тест 2: HostPath pod
    print_step "Тест 2: HostPath pod (должен быть отклонён)"
    output=$(kubectl apply -f insecure-manifests/02-hostpath-pod.yaml 2>&1)
    if echo "$output" | grep -iE "(forbidden|denied|violation|error)" > /dev/null; then
        print_success "HostPath pod отклонён (как и ожидалось)"
        ((passed++))
    else
        print_error "HostPath pod НЕ был отклонён!"
        kubectl delete -f insecure-manifests/02-hostpath-pod.yaml --ignore-not-found=true 2>/dev/null || true
        ((failed++))
    fi
    
    # Тест 3: Root user pod
    print_step "Тест 3: Root user pod (должен быть отклонён)"
    output=$(kubectl apply -f insecure-manifests/03-root-user-pod.yaml 2>&1)
    if echo "$output" | grep -iE "(forbidden|denied|violation|error)" > /dev/null; then
        print_success "Root user pod отклонён (как и ожидалось)"
        ((passed++))
    else
        print_error "Root user pod НЕ был отклонён!"
        kubectl delete -f insecure-manifests/03-root-user-pod.yaml --ignore-not-found=true 2>/dev/null || true
        ((failed++))
    fi
    
    echo ""
    if [ $failed -eq 0 ]; then
        print_success "Все небезопасные манифесты корректно отклонены ($passed/3)"
        return 0
    else
        print_error "Некоторые небезопасные манифесты не были отклонены (Пройдено: $passed/3, Провалено: $failed/3)"
        return 1
    fi
}

# Функция тестирования безопасных манифестов
test_secure_manifests() {
    print_header "Тестирование безопасных манифестов"
    
    local failed=0
    local passed=0
    
    # Очистка старых подов
    kubectl delete pods --all -n $NAMESPACE --ignore-not-found=true 2>/dev/null || true
    sleep 2
    
    # Тест каждого безопасного манифеста
    for manifest in secure-manifests/*.yaml; do
        if [ ! -f "$manifest" ]; then
            continue
        fi
        pod_name=$(grep "name:" "$manifest" | head -1 | awk '{print $2}')
        print_step "Развертывание: $pod_name"
        
        output=$(kubectl apply -f "$manifest" 2>&1)
        if echo "$output" | grep -v "Warning" | grep -qE "(created|configured)"; then
            print_success "$pod_name успешно создан"
            
            # Ждем немного и проверяем статус
            sleep 3
            status=$(kubectl get pod "$pod_name" -n $NAMESPACE -o jsonpath='{.status.phase}' 2>/dev/null)
            if echo "$status" | grep -qE "Running|Pending|ContainerCreating"; then
                print_success "$pod_name проходит валидацию (статус: $status)"
                ((passed++))
            else
                print_warning "$pod_name создан, но статус неопределён"
                ((passed++))
            fi
        else
            print_error "$pod_name не удалось развернуть"
            echo "$output" | head -3
            ((failed++))
        fi
    done
    
    echo ""
    if [ $failed -eq 0 ]; then
        print_success "Все безопасные манифесты успешно развернуты ($passed/3)"
        return 0
    else
        print_error "Некоторые безопасные манифесты не удалось развернуть (Пройдено: $passed/3, Провалено: $failed/3)"
        return 1
    fi
}

# Функция проверки статуса
check_status() {
    print_header "Проверка статуса"
    
    print_step "Статус namespace:"
    if kubectl get namespace $NAMESPACE &>/dev/null; then
        enforce=$(kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null)
        echo "  Namespace: $NAMESPACE"
        echo "  PodSecurity Enforce: ${enforce:-<не установлен>}"
    else
        print_error "Namespace не найден"
    fi
    
    echo ""
    print_step "Статус подов:"
    kubectl get pods -n $NAMESPACE 2>/dev/null || print_warning "Поды не найдены"
    
    echo ""
    print_step "Статус Constraint Templates:"
    kubectl get constrainttemplates 2>/dev/null | tail -n +2 || print_warning "Constraint Templates не найдены"
    
    echo ""
    print_step "Статус Constraints:"
    kubectl get constraints -A 2>/dev/null | tail -n +2 || print_warning "Constraints не найдены"
}

# Функция вывода итогов
print_summary() {
    local insecure_result=$1
    local secure_result=$2
    
    print_header "Итоги тестирования"
    
    echo -e "${BOLD}Результаты:${NC}"
    echo ""
    
    if [ $insecure_result -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Небезопасные манифесты: ${GREEN}ВСЕ ОТКЛОНЕНЫ${NC}"
    else
        echo -e "  ${RED}✗${NC} Небезопасные манифесты: ${RED}ЧАСТИЧНО ПРОВАЛЕНЫ${NC}"
    fi
    
    if [ $secure_result -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} Безопасные манифесты: ${GREEN}ВСЕ РАЗВЕРНУТЫ${NC}"
    else
        echo -e "  ${RED}✗${NC} Безопасные манифесты: ${RED}ЧАСТИЧНО ПРОВАЛЕНЫ${NC}"
    fi
    
    echo ""
    
    if [ $insecure_result -eq 0 ] && [ $secure_result -eq 0 ]; then
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${GREEN}  ✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!${NC}"
        echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"
        return 0
    else
        echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${BOLD}${RED}  ✗ НЕКОТОРЫЕ ТЕСТЫ ПРОВАЛЕНЫ${NC}"
        echo -e "${BOLD}${RED}═══════════════════════════════════════════════════════════════${NC}\n"
        return 1
    fi
}

# Функция проверки и запуска minikube
check_minikube() {
    print_header "Проверка minikube"
    
    print_step "Проверка статуса minikube..."
    
    # Проверяем, доступен ли kubectl и кластер
    if kubectl cluster-info &>/dev/null; then
        print_success "Kubernetes кластер доступен"
        return 0
    fi
    
    # Если kubectl не работает, проверяем minikube
    if ! command -v minikube &>/dev/null; then
        print_error "minikube не установлен. Установите minikube для продолжения."
        return 1
    fi
    
    # Проверяем статус minikube
    if minikube status &>/dev/null; then
        # Пытаемся получить статус более детально
        host_status=$(minikube status -o json 2>/dev/null | grep -o '"Host":"[^"]*"' | cut -d'"' -f4 || echo "")
        if [ "$host_status" = "Running" ]; then
            print_info "Minikube запущен, но кластер недоступен. Пытаемся подключиться..."
            # Пытаемся использовать контекст minikube
            if kubectl config use-context minikube &>/dev/null; then
                if kubectl cluster-info &>/dev/null; then
                    print_success "Подключение к кластеру восстановлено"
                    return 0
                fi
            fi
        fi
    fi
    
    print_warning "Minikube не запущен или кластер недоступен, запускаем..."
    if minikube start 2>&1; then
        print_success "Minikube успешно запущен"
        
        # Ждем, пока кластер станет готовым
        print_step "Ожидание готовности кластера..."
        local max_attempts=30
        local attempt=0
        while [ $attempt -lt $max_attempts ]; do
            if kubectl cluster-info &>/dev/null; then
                print_success "Кластер готов к работе"
                return 0
            fi
            sleep 2
            ((attempt++))
        done
        
        print_error "Кластер не готов после $max_attempts попыток"
        return 1
    else
        print_error "Не удалось запустить minikube"
        return 1
    fi
}

# Главная функция
main() {
    print_header "Настройка и тестирование безопасности Kubernetes"
    print_info "Задание: Аудит безопасности подов с PodSecurity и OPA Gatekeeper"
    echo ""
    
    # Проверка и запуск minikube
    if ! check_minikube; then
        print_error "Не удалось запустить minikube. Убедитесь, что minikube установлен."
        exit 1
    fi
    
    # Очистка
    cleanup
    
    # Установка Gatekeeper
    install_gatekeeper
    
    # Настройка
    setup
    
    # Тестирование небезопасных манифестов
    test_insecure_manifests
    insecure_result=$?
    
    # Тестирование безопасных манифестов
    test_secure_manifests
    secure_result=$?
    
    # Небольшая задержка для стабилизации
    sleep 2
    
    # Проверка статуса
    check_status
    
    # Итоги
    print_summary $insecure_result $secure_result
    
    # Пауза перед завершением, если терминал интерактивный
    if [ -t 0 ]; then
        echo ""
        read -p "Нажмите Enter для завершения..."
    fi
    
    # Возвращаем код выхода на основе результатов
    if [ $insecure_result -eq 0 ] && [ $secure_result -eq 0 ]; then
        exit 0
    else
        exit 1
    fi
}

# Запуск
main

