#!/bin/bash

# Используем set -e только для части setup, для тестов отключим
set -e

echo "=== Подготовка и тестирование задания 4 (RBAC) ==="
echo ""

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Получаем директорию скрипта
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Проверка, что kubectl доступен
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}Ошибка: kubectl не найден. Установите kubectl и повторите попытку.${NC}"
    exit 1
fi

# Проверка, что openssl доступен
if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Ошибка: openssl не найден. Установите openssl и повторите попытку.${NC}"
    exit 1
fi

# Проверка и запуск minikube
echo "Проверка состояния minikube..."
if ! command -v minikube &> /dev/null; then
    echo -e "${RED}Ошибка: minikube не найден. Установите minikube и повторите попытку.${NC}"
    exit 1
fi

if ! minikube status &> /dev/null; then
    echo -e "${YELLOW}Minikube не запущен. Запускаю minikube...${NC}"
    minikube start
    echo -e "${GREEN}✓${NC} Minikube запущен"
else
    echo -e "${GREEN}✓${NC} Minikube уже запущен"
fi

# Проверка подключения к кластеру
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}Ошибка: Не удалось подключиться к кластеру Kubernetes.${NC}"
    exit 1
fi

echo -e "${GREEN}✓${NC} Подключение к кластеру установлено"
echo ""

# ============================================
# ЧАСТЬ 1: ПОДГОТОВКА СРЕДЫ
# ============================================
echo -e "${BLUE}=== Часть 1: Подготовка среды ===${NC}"
echo ""

# Проверка наличия необходимых скриптов
REQUIRED_SCRIPTS=("create-users.sh" "create-roles.sh" "create-bindings.sh")
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$SCRIPT_DIR/$script" ]; then
        echo -e "${RED}Ошибка: Файл $script не найден!${NC}"
        exit 1
    fi
    if [ ! -x "$SCRIPT_DIR/$script" ]; then
        chmod +x "$SCRIPT_DIR/$script"
    fi
done

# 1. Создание пользователей
echo -e "${YELLOW}Шаг 1: Создание пользователей...${NC}"
bash "$SCRIPT_DIR/create-users.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при создании пользователей${NC}"
    exit 1
fi
echo ""

# 2. Создание ролей и namespace
echo -e "${YELLOW}Шаг 2: Создание ролей и namespace...${NC}"
bash "$SCRIPT_DIR/create-roles.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при создании ролей${NC}"
    exit 1
fi
echo ""

# 3. Создание привязок
echo -e "${YELLOW}Шаг 3: Создание привязок ролей к пользователям...${NC}"
bash "$SCRIPT_DIR/create-bindings.sh"
if [ $? -ne 0 ]; then
    echo -e "${RED}Ошибка при создании привязок${NC}"
    exit 1
fi
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
TEST_SCRIPT="${SCRIPT_DIR}/test-rbac.sh"
if [ -f "$TEST_SCRIPT" ]; then
    if [ ! -x "$TEST_SCRIPT" ]; then
        chmod +x "$TEST_SCRIPT"
    fi
    bash "$TEST_SCRIPT"
    TEST_EXIT_CODE=$?
else
    echo -e "${RED}Ошибка: Файл тестов $TEST_SCRIPT не найден!${NC}"
    TEST_EXIT_CODE=1
fi

echo ""

# Пауза перед завершением, если терминал интерактивный
if [ -t 0 ]; then
    echo -e "${BLUE}Нажмите Enter для выхода...${NC}"
    read
fi

# Выходим с кодом возврата тестов
exit $TEST_EXIT_CODE

