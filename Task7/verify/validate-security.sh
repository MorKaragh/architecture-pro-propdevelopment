#!/bin/bash

set -e

NAMESPACE="audit-zone"

echo "=== Детальная проверка безопасности подов ==="
echo ""

# Получаем все поды в namespace
pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

if [ -z "$pods" ]; then
    echo "В namespace $NAMESPACE нет подов"
    exit 0
fi

for pod in $pods; do
    echo "Проверка пода: $pod"
    echo "----------------------------------------"
    
    # Проверка securityContext
    echo "Security Context:"
    kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[0].securityContext}' | jq '.' 2>/dev/null || echo "  (не удалось получить)"
    
    # Проверка volumes
    echo ""
    echo "Volumes:"
    kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.volumes[*].name}' | tr ' ' '\n' | while read vol; do
        if [ ! -z "$vol" ]; then
            vol_type=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath="{.spec.volumes[?(@.name=='$vol')]}")
            if echo "$vol_type" | grep -q "hostPath"; then
                echo "  ✗ $vol: использует hostPath (нарушение!)"
            else
                echo "  ✓ $vol: безопасный тип"
            fi
        fi
    done
    
    # Проверка статуса
    echo ""
    echo "Статус:"
    kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.status.phase}' && echo ""
    
    echo ""
done

echo "=== Проверка завершена ==="

