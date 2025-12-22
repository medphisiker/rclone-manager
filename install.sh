#!/bin/bash
# Скрипт автоматической установки Rclone Manager

set -e

echo "=== Установка Rclone Manager ==="
echo ""

# Проверка прав
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  Запустите скрипт от имени root (sudo)"
    exit 1
fi

# Проверка rclone
echo "Проверка rclone..."
if ! command -v rclone &> /dev/null; then
    echo "❌ rclone не установлен. Установите сначала:"
    echo "   curl https://rclone.org/install.sh | sudo bash"
    exit 1
fi
echo "✓ rclone найден"

# Проверка systemd
echo "Проверка systemd..."
if ! command -v systemctl &> /dev/null; then
    echo "❌ systemd не найден"
    exit 1
fi
echo "✓ systemd найден"

# Определение текущего пользователя
CURRENT_USER=$(whoami)
if [ "$SUDO_USER" ]; then
    CURRENT_USER=$SUDO_USER
fi

HOME_DIR="/home/$CURRENT_USER"
PROJECT_DIR="$HOME_DIR/projects/rclone-manager"

echo "Пользователь: $CURRENT_USER"
echo "Домашняя директория: $HOME_DIR"
echo "Проект: $PROJECT_DIR"
echo ""

# Создание директорий
echo "Создание директорий..."
mkdir -p "$HOME_DIR/mnt/yandex_disk"
mkdir -p "$HOME_DIR/mnt/mail_ru"
mkdir -p "$HOME_DIR/mnt/google_drive"
mkdir -p "$HOME_DIR/.cache/rclone"
mkdir -p "$HOME_DIR/.config/systemd/user"
chown -R "$CURRENT_USER:$CURRENT_USER" "$HOME_DIR/mnt" "$HOME_DIR/.cache/rclone"
echo "✓ Директории созданы"

# Установка скрипта
echo "Установка rclone_manager.sh..."
cp "$PROJECT_DIR/rclone_manager.sh" "/usr/local/bin/rclone_manager.sh"
chmod +x "/usr/local/bin/rclone_manager.sh"
chown "$CURRENT_USER:$CURRENT_USER" "/usr/local/bin/rclone_manager.sh"
echo "✓ Скрипт установлен в /usr/local/bin/rclone_manager.sh"

# Установка шаблонов сервисов
echo "Установка шаблонов systemd сервисов..."

# Шаблон read-only
cp "$PROJECT_DIR/rclone-ro@.service" "$HOME_DIR/.config/systemd/user/"
chown "$CURRENT_USER:$CURRENT_USER" "$HOME_DIR/.config/systemd/user/rclone-ro@.service"

# Шаблон read-write
cp "$PROJECT_DIR/rclone-rw@.service" "$HOME_DIR/.config/systemd/user/"
chown "$CURRENT_USER:$CURRENT_USER" "$HOME_DIR/.config/systemd/user/rclone-rw@.service"

echo "✓ Шаблоны сервисов установлены"

# Добавление алиасов
echo "Добавление алиасов в .bashrc..."
ALIASES="
# Rclone Manager Aliases
alias rmro='rclone_manager.sh ro'
alias rmrw='rclone_manager.sh rw'
alias rmt='rclone_manager.sh toggle'
alias rms='rclone_manager.sh st'
"

if ! grep -q "Rclone Manager Aliases" "$HOME_DIR/.bashrc"; then
    echo "$ALIASES" >> "$HOME_DIR/.bashrc"
    echo "✓ Алиасы добавлены в $HOME_DIR/.bashrc"
else
    echo "⚠️  Алиасы уже существуют в .bashrc"
fi

# Перезагрузка systemd
echo "Перезагрузка systemd..."
sudo -u "$CURRENT_USER" systemctl --user daemon-reload
echo "✓ systemd перезагружен"

# Проверка конфигурации rclone
echo ""
echo "Проверка конфигурации rclone..."
sudo -u "$CURRENT_USER" rclone config show

echo ""
echo "=== Установка завершена ==="
echo ""
echo "📋 Следующие шаги:"
echo "1. Проверьте конфигурацию rclone: rclone config show"
echo "2. Если облака не настроены, выполните: rclone config"
echo "3. Перезапустите терминал или выполните: source ~/.bashrc"
echo ""
echo "🚀 Использование:"
echo "   rclone_manager.sh ro    # Подключить все в read-only"
echo "   rclone_manager.sh st    # Показать статус"
echo "   rmro                    # Алиас для read-only"
echo "   rms                     # Алиас для статуса"
echo ""
echo "🔒 Безопасность: Всегда используйте read-only режим по умолчанию!"
