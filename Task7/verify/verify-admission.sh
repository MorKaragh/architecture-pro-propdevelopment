#!/bin/bash

set -e

# Определяем директорию скрипта
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK7_DIR="$(dirname "$SCRIPT_DIR")"

NAMESPACE="audit-zone"
INSECURE_DIR="$TASK7_DIR/insecure-manifests"
SECURE_DIR="$TASK7_DIR/secure-manifests"

echo "=== Проверка PodSecurity Admission и Gatekeeper ==="
echo ""

# Проверка namespace
echo "1. Проверка namespace $NAMESPACE..."
if kubectl get namespace $NAMESPACE &>/dev/null; then
    echo "   ✓ Namespace существует"
    kubectl get namespace $NAMESPACE -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' | grep -q restricted && echo "   ✓ PodSecurity enforce: restricted" || echo "   ✗ PodSecurity enforce не установлен"
else
    echo "   ✗ Namespace не найден"
    exit 1
fi

echo ""
echo "2. Попытка развернуть небезопасные манифесты (должны быть отклонены)..."
echo ""

# Проверка privileged pod
echo "   Тест 1: Privileged pod"
if kubectl apply -f $INSECURE_DIR/01-privileged-pod.yaml 2>&1 | grep -iE "(denied|forbidden|violation|error)" > /dev/null; then
    echo "   ✓ Privileged pod отклонён (как и ожидалось)"
else
    echo "   ✗ Privileged pod не был отклонён!"
    kubectl delete -f $INSECURE_DIR/01-privileged-pod.yaml --ignore-not-found=true
fi

# Проверка hostPath pod
echo "   Тест 2: HostPath pod"
if kubectl apply -f $INSECURE_DIR/02-hostpath-pod.yaml 2>&1 | grep -iE "(denied|forbidden|violation|error)" > /dev/null; then
    echo "   ✓ HostPath pod отклонён (как и ожидалось)"
else
    echo "   ✗ HostPath pod не был отклонён!"
    kubectl delete -f $INSECURE_DIR/02-hostpath-pod.yaml --ignore-not-found=true
fi

# Проверка root user pod
echo "   Тест 3: Root user pod"
if kubectl apply -f $INSECURE_DIR/03-root-user-pod.yaml 2>&1 | grep -iE "(denied|forbidden|violation|error)" > /dev/null; then
    echo "   ✓ Root user pod отклонён (как и ожидалось)"
else
    echo "   ✗ Root user pod не был отклонён!"
    kubectl delete -f $INSECURE_DIR/03-root-user-pod.yaml --ignore-not-found=true
fi

echo ""
echo "3. Развертывание безопасных манифестов (должны пройти валидацию)..."
echo ""

# Развертывание безопасных подов
for manifest in $SECURE_DIR/*.yaml; do
    pod_name=$(grep "name:" $manifest | head -1 | awk '{print $2}')
    echo "   Развертывание: $pod_name"
    if kubectl apply -f $manifest; then
        echo "   ✓ $pod_name успешно развернут"
    else
        echo "   ✗ $pod_name не удалось развернуть"
    fi
done

echo ""
echo "4. Проверка статуса подов..."
kubectl get pods -n $NAMESPACE

echo ""
echo "=== Проверка завершена ==="

