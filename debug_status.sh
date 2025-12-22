#!/bin/bash
# Отладочный скрипт для проверки статуса сервисов

CLOUDS=("yandex_disk" "mail_ru" "google_drive")

check_service_status() {
    local cloud=$1
    local mode=$2
    local service_name="rclone-${mode}@${cloud}.service"
    
    echo "Checking $service_name..."
    
    if systemctl --user is-active --quiet "$service_name"; then
        echo "  -> ACTIVE"
        return 0
    else
        echo "  -> INACTIVE"
        return 1
    fi
}

get_current_mode() {
    local cloud=$1
    echo "Getting mode for $cloud..."
    
    for mode in ro rw; do
        if check_service_status "$cloud" "$mode"; then
            echo "$mode"
            return 0
        fi
    done
    
    echo "off"
    return 1
}

echo "=== START DEBUG ==="
for cloud in "${CLOUDS[@]}"; do
    echo "Processing cloud: $cloud"
    mode=$(get_current_mode "$cloud")
    echo "Result mode: $mode"
    echo "-------------------"
done
echo "=== END DEBUG ==="