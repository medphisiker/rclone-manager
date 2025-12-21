#!/bin/bash
# Rclone Manager - Управление режимами доступа к облачным дискам
# Версия: 1.0.0

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Список поддерживаемых облаков
CLOUDS=("yandex_disk" "mail_ru")

# Пути к точкам монтирования
declare -A MOUNT_POINTS=(
    ["yandex_disk"]="$HOME/mnt/yandex_disk"
    ["mail_ru"]="$HOME/mnt/mail_ru"
)

# Показать использование
show_usage() {
    echo "Использование: $0 <команда> [облако]"
    echo ""
    echo "Команды:"
    echo "  ro [облако]    - Подключить все или указанное облако в read-only режиме"
    echo "  rw [облако]    - Подключить все или указанное облако в read-write режиме"
    echo "  toggle [облако] - Переключить режим для всех или указанного облака"
    echo "  st [облако]    - Показать статус всех или указанного облака"
    echo "  stop [облако]  - Остановить все или указанное облако"
    echo ""
    echo "Примеры:"
    echo "  $0 ro              # Все облака в read-only"
    echo "  $0 rw yandex_disk  # Yandex в read-write"
    echo "  $0 toggle mail_ru  # Переключить Mail.ru"
    echo "  $0 st              # Статус всех облаков"
}

# Проверка установки rclone
check_rclone() {
    if ! command -v rclone &> /dev/null; then
        echo -e "${RED}Ошибка: rclone не установлен${NC}"
        exit 1
    fi
}

# Проверка конфигурации rclone
check_config() {
    local cloud=$1
    if ! rclone config show "$cloud" &> /dev/null; then
        echo -e "${RED}Ошибка: Облако '$cloud' не настроено в rclone${NC}"
        return 1
    fi
    return 0
}

# Создать точку монтирования
create_mount_point() {
    local cloud=$1
    local mount_point="${MOUNT_POINTS[$cloud]}"
    
    if [ ! -d "$mount_point" ]; then
        echo -e "${YELLOW}Создание точки монтирования: $mount_point${NC}"
        mkdir -p "$mount_point"
    fi
}

# Проверить статус сервиса
check_service_status() {
    local cloud=$1
    local mode=$2
    local service_name="rclone@${cloud}-${mode}.service"
    
    if systemctl --user is-active --quiet "$service_name"; then
        return 0
    else
        return 1
    fi
}

# Получить текущий режим облака
get_current_mode() {
    local cloud=$1
    
    for mode in ro rw; do
        if check_service_status "$cloud" "$mode"; then
            echo "$mode"
            return 0
        fi
    done
    
    echo "off"
    return 1
}

# Запустить монтирование
mount_cloud() {
    local cloud=$1
    local mode=$2
    
    # Проверяем конфигурацию
    if ! check_config "$cloud"; then
        return 1
    fi
    
    # Создаем точку монтирования
    create_mount_point "$cloud"
    
    local service_name="rclone@${cloud}-${mode}.service"
    
    echo -e "${BLUE}Запуск $cloud в режиме $mode...${NC}"
    
    # Останавливаем другие режимы этого облака
    stop_cloud "$cloud" true
    
    # Запускаем сервис
    if systemctl --user start "$service_name"; then
        sleep 1
        if systemctl --user is-active --quiet "$service_name"; then
            echo -e "${GREEN}✓ $cloud успешно подключен в режиме $mode${NC}"
            return 0
        else
            echo -e "${RED}✗ Ошибка запуска сервиса${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Не удалось запустить сервис${NC}"
        return 1
    fi
}

# Остановить монтирование
stop_cloud() {
    local cloud=$1
    local quiet=$2
    
    local stopped=false
    
    for mode in ro rw; do
        local service_name="rclone@${cloud}-${mode}.service"
        
        if systemctl --user is-active --quiet "$service_name"; then
            if [ "$quiet" != "true" ]; then
                echo -e "${YELLOW}Остановка $cloud ($mode)...${NC}"
            fi
            
            systemctl --user stop "$service_name"
            stopped=true
        fi
    done
    
    if [ "$stopped" = "true" ] && [ "$quiet" != "true" ]; then
        echo -e "${GREEN}✓ $cloud остановлен${NC}"
    fi
}

# Показать статус
show_status() {
    local cloud=$1
    
    if [ -n "$cloud" ]; then
        # Статус конкретного облака
        local mode=$(get_current_mode "$cloud")
        
        case $mode in
            "ro")
                echo -e "${GREEN}✓ $cloud: READ-ONLY${NC}"
                ;;
            "rw")
                echo -e "${YELLOW}⚠ $cloud: READ-WRITE${NC}"
                ;;
            "off")
                echo -e "${RED}✗ $cloud: OFFLINE${NC}"
                ;;
        esac
    else
        # Статус всех облаков
        echo -e "${BLUE}Статус rclone облаков:${NC}"
        echo ""
        
        all_off=true
        for cloud in "${CLOUDS[@]}"; do
            mode=$(get_current_mode "$cloud")
            
            if [ "$mode" != "off" ]; then
                all_off=false
                case $mode in
                    "ro")
                        echo -e "  ${GREEN}✓${NC} $cloud: ${GREEN}READ-ONLY${NC}"
                        ;;
                    "rw")
                        echo -e "  ${YELLOW}⚠${NC} $cloud: ${YELLOW}READ-WRITE${NC}"
                        ;;
                esac
            fi
        done
        
        if [ "$all_off" = "true" ]; then
            echo -e "  ${RED}Все облака отключены${NC}"
        fi
        
        echo ""
        echo -e "${BLUE}Подсказка:${NC} Используйте 'rclone_manager.sh st <облако>' для детальной информации"
    fi
}

# Переключить режим
toggle_mode() {
    local cloud=$1
    local current_mode=$(get_current_mode "$cloud")
    
    case $current_mode in
        "off")
            echo -e "${YELLOW}Облако $cloud отключено, включаю в read-only режим${NC}"
            mount_cloud "$cloud" "ro"
            ;;
        "ro")
            echo -e "${YELLOW}Переключение $cloud на read-write...${NC}"
            mount_cloud "$cloud" "rw"
            ;;
        "rw")
            echo -e "${YELLOW}Переключение $cloud на read-only...${NC}"
            mount_cloud "$cloud" "ro"
            ;;
    esac
}

# Основная логика
main() {
    local command=$1
    local cloud=$2
    
    # Проверка rclone
    check_rclone
    
    # Обработка команд
    case "$command" in
        "ro")
            if [ -n "$cloud" ]; then
                mount_cloud "$cloud" "ro"
            else
                for c in "${CLOUDS[@]}"; do
                    mount_cloud "$c" "ro"
                done
            fi
            ;;
            
        "rw")
            if [ -n "$cloud" ]; then
                mount_cloud "$cloud" "rw"
            else
                for c in "${CLOUDS[@]}"; do
                    mount_cloud "$c" "rw"
                done
            fi
            ;;
            
        "toggle")
            if [ -n "$cloud" ]; then
                toggle_mode "$cloud"
            else
                for c in "${CLOUDS[@]}"; do
                    toggle_mode "$c"
                done
            fi
            ;;
            
        "st"|"status")
            show_status "$cloud"
            ;;
            
        "stop")
            if [ -n "$cloud" ]; then
                stop_cloud "$cloud" "false"
            else
                for c in "${CLOUDS[@]}"; do
                    stop_cloud "$c" "false"
                done
                echo -e "${GREEN}✓ Все облака остановлены${NC}"
            fi
            ;;
            
        "")
            show_usage
            ;;
            
        *)
            echo -e "${RED}Неизвестная команда: $command${NC}"
            show_usage
            exit 1
            ;;
    esac
}

# Запуск
main "$@"
