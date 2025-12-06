#!/bin/bash

# Скрипт для запуска minikube с политиками аудита

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_POLICY_FILE="${SCRIPT_DIR}/audit-policy.yaml"
AUDIT_LOG_FILE="${SCRIPT_DIR}/audit.log"

# Проверяем наличие файла политики
if [ ! -f "$AUDIT_POLICY_FILE" ]; then
    echo "Ошибка: файл $AUDIT_POLICY_FILE не найден"
    exit 1
fi

echo "Настройка minikube с политиками аудита..."

# Создаем директорию для файлов minikube
MINIKUBE_FILES_DIR="${HOME}/.minikube/files/etc/ssl/certs"
echo "Создаем директорию для файлов minikube: ${MINIKUBE_FILES_DIR}"
mkdir -p "${MINIKUBE_FILES_DIR}"

# Копируем файл политики в директорию minikube
echo "Копируем файл политики аудита в ~/.minikube/files/etc/ssl/certs/..."
cp "${AUDIT_POLICY_FILE}" "${MINIKUBE_FILES_DIR}/audit-policy.yaml"

# Удаляем существующий кластер
if minikube status >/dev/null 2>&1; then
    echo "Останавливаем и удаляем существующий minikube..."
    minikube stop 2>/dev/null || true
    minikube delete
fi

minikube start   \
  --extra-config=apiserver.audit-policy-file=/etc/ssl/certs/audit-policy.yaml   \
  --extra-config=apiserver.audit-log-path=-\
  --extra-config=apiserver.audit-log-maxage=30 \
    --extra-config=apiserver.audit-log-maxbackup=10 \
    --extra-config=apiserver.audit-log-maxsize=100

echo "Ожидание готовности кластера..."
kubectl -- wait --for=condition=ready node --all --timeout=300s

# Проверяем, что файл политики доступен
echo "Проверка доступности файла политики..."
minikube ssh 'cat /etc/ssl/certs/audit-policy.yaml' > /dev/null && echo "✓ Файл политики доступен" || echo "✗ Файл политики не найден"

./simulate-incident.sh
kubectl logs kube-apiserver-minikube -n kube-system | grep audit.k8s.io/v1 > audit.log
python3 analyze-audit.py audit.log