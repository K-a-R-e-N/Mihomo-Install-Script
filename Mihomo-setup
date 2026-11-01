#!/bin/bash
yellow=$(tput setaf 3 2>/dev/null || tput setf 6)
red=$(tput setaf 1 2>/dev/null || tput setf 4)
green=$(tput setaf 2 2>/dev/null || tput setf 2)
cyan=$(tput setaf 6 2>/dev/null || tput setf 3)
dim=$(tput setaf 8 2>/dev/null || tput setf 8)
bg_text=$(tput setaf 0 2>/dev/null; tput setab 7 2>/dev/null)
reset=$(tput sgr0)

cd ~ || exit 1 ; clear

function ZagolovokInstall {
echo -e "${yellow}██████████████════════════════════════════════════════════════════════██████████████${reset}"
echo -e "           Установка и инициализация провайдера туннеля Mihomo Alpha           "
echo -e "${yellow}██████████████════════════════════════════════════════════════════════██████████████${reset}"
}

function ZagolovokSuccess {
local ver=$1
local bg_success=$(tput setaf 0 2>/dev/null; tput setab 7 2>/dev/null)
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"
echo -e "  ${bg_success} УСПЕШНО: Ядро Mihomo интегрировано в систему! ${reset}            ${dim}[Ядро: ${ver}]${reset}"
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"
}

ZagolovokInstall
echo "  # # Для работы скрипта необходимы права суперпользователя."
sudo -v || exit 1
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
cleanup() { if kill -0 "$SUDO_PID" 2>/dev/null; then kill "$SUDO_PID" 2>/dev/null; fi; }
trap cleanup EXIT
clear

ZagolovokInstall

# Замеряем чистый IPv4 до включения прокси (Плейсхолдер . применен)
OLD_IP=$(curl -4 --connect-timeout 4 -s ifconfig.me)
if [ -z "$OLD_IP" ]; then OLD_IP="Не удалось определить"; fi

sudo systemctl disable --now amneziawg > /dev/null 2>&1
sudo systemctl disable --now mihomo > /dev/null 2>&1
sudo killall -9 awg awg-quick mihomo > /dev/null 2>&1

echo -en "\n" ; echo -n "  # # Подготовка директорий операционной системы..."
sudo mkdir -p /usr/local/bin /etc/mihomo || exit 1
sudo rm -f /usr/local/bin/mihomo.xz /usr/local/bin/mihomo.gz /usr/local/bin/mihomo /usr/local/bin/mihomoimport
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -n "  # # Поиск актуального релиза ядра на серверах GitHub API..."
LATEST_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep "browser_download_url" | grep "linux-arm64" | grep -v -i "compatible" | grep -v ".deb" | head -n 1 | cut -d '"' -f 4)
if [ -z "$LATEST_URL" ]; then
    LATEST_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases | grep "browser_download_url" | grep "linux-arm64" | grep -v -i "compatible" | grep -v -i "alpha" | grep -v -i "beta" | grep -v ".deb" | head -n 1 | cut -d '"' -f 4)
fi
echo -e " ${green}[Готово]${reset}"

# ИСПРАВЛЕНО: Сначала определяем расширение, а затем качаем файл
EXT="${LATEST_URL##*.}"

echo -en "\n" ; echo -n "  # # Скачивание стабильного бинарного пакета..."
sudo wget -q -O /usr/local/bin/mihomo_download.$EXT "$LATEST_URL"
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -n "  # # Распаковка архива и развертывание исполняемого файла..."
if [ "$EXT" = "xz" ]; then
    sudo unxz -f /usr/local/bin/mihomo_download.xz > /dev/null 2>&1
    sudo mv /usr/local/bin/mihomo_download /usr/local/bin/mihomo
elif [ "$EXT" = "gz" ]; then
    sudo gunzip -f /usr/local/bin/mihomo_download.gz > /dev/null 2>&1
    sudo mv /usr/local/bin/mihomo_download /usr/local/bin/mihomo
else
    sudo mv /usr/local/bin/mihomo_download.$EXT /usr/local/bin/mihomo > /dev/null 2>&1
fi
sudo chmod +x /usr/local/bin/mihomo
echo -e " ${green}[Готово]${reset}"

FINAL_VER=$(/usr/local/bin/mihomo -v 2>/dev/null | head -n 1 | awk '{print $3}')

echo -en "\n" ; echo -n "  # # Генерация системного манифеста маршрутизации config.yaml..."
sudo tee /etc/mihomo/config.yaml > /dev/null << 'EOF'
mixed-port: 7890
allow-lan: true
mode: rule
log-level: info
ipv6: false

tun:
  enable: true
  stack: gvisor
  dns-hijack:
    - "any:53"
  auto-route: true
  auto-detect-interface: true
  bypass-lan: true

dns:
  enable: true
  listen: 0.0.0.0:53
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1
    - 114.114.114.114

proxy-providers:
  warp_provider:
    type: file
    path: ./warp.yaml
    health-check:
      enable: true
      url: http://cp.cloudflare.com/generate_204
      interval: 300

proxy-groups:
- name: WARP
  type: select
  use:
    - warp_provider

rules:
  - GEOIP,lan,DIRECT,no-resolve
  - DOMAIN-SUFFIX,raspberrypi.org,DIRECT
  - DOMAIN-SUFFIX,raspberrypi.com,DIRECT
  - DOMAIN-SUFFIX,raspbian.org,DIRECT
  - DOMAIN-SUFFIX,debian.org,DIRECT
  - MATCH,WARP
EOF
echo -e " ${green}[Готово]${reset}"
# АВТОМАТИЧЕСКАЯ СБОРКА И ПЕРЕНОС НА ТИВНОЙ УТИЛИТЫ ИМПОРТА В СИСТЕМУ
echo -en "\n" ; echo -n "  # # Развертывание и сборка нативной утилиты mihomoimport..."
sudo tee /usr/local/bin/mihomoimport > /dev/null << 'EOF'
#!/bin/bash
yellow=$(tput setaf 3 2>/dev/null || tput setf 6)
red=$(tput setaf 1 2>/dev/null || tput setf 4)
green=$(tput setaf 2 2>/dev/null || tput setf 2)
cyan=$(tput setaf 6 2>/dev/null || tput setf 3)
dim=$(tput setaf 8 2>/dev/null || tput setf 8)
bg_text=$(tput setaf 0 2>/dev/null; tput setab 7 2>/dev/null)
reset=$(tput sgr0)

if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi

clear
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"
echo -e "                УТИЛИТА ОБНОВЛЕНИЯ КОНФИГУРАЦИИ AMNEZIAWG / WARP                "
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"

sudo systemctl stop mihomo > /dev/null 2>&1
OLD_IP=$(curl -4 --connect-timeout 4 -s ifconfig.me)
if [ -z "$OLD_IP" ]; then OLD_IP="Не удалось определить (нет сети)"; fi

echo -en "\n"
echo -e "  ${bg_text}┌─────────────────────────────────────────────────────────────────────────┐${reset}"
echo -e "  ${bg_text}│            📥 ИНСТРУКЦИЯ ПО ИНИЦИАЛИЗАЦИИ ЗАЩИЩЕННОГО ТУННЕЛЯ:          │${reset}"
echo -e "  ${bg_text}├─────────────────────────────────────────────────────────────────────────┤${reset}"
echo -e "  ${bg_text}│  1. Откройте в браузере сайт: warp-generation.github.io                 │${reset}"
echo -e "  ${bg_text}│  2. Нажмите кнопку 'Clash -> AWG 2.0' и полностью скопируйте текст.     │${reset}"
echo -e "  ${bg_text}│  3. Вставьте скопированную конфигурацию прямо сюда, в окно терминала.   │${reset}"
echo -e "  ${bg_text}│  4. После вставки нажмите Enter, а затем комбинацию клавиш: Ctrl + D    │${reset}"
echo -e "  ${bg_text}└─────────────────────────────────────────────────────────────────────────┘${reset}"
echo ""

TMP_INPUT=$(mktemp)
chmod 666 "$TMP_INPUT"
cat > "$TMP_INPUT"

clear
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"
echo -e "                УТИЛИТА ОБНОВЛЕНИЯ КОНФИГУРАЦИИ AMNEZIAWG / WARP                "
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"

if [ ! -s "$TMP_INPUT" ] || ! grep -q "proxies" "$TMP_INPUT"; then
    rm -f "$TMP_INPUT"
    echo -e "\n  ${yellow}[ОТМЕНА] Новая конфигурация не была введена. Возврат к старым ключам...${reset}\n"
    sudo systemctl start mihomo > /dev/null 2>&1
    exit 0
fi

mv "$TMP_INPUT" /etc/mihomo/warp.yaml
sudo systemctl start mihomo > /dev/null 2>&1

spinner=( '╱' '─' '╲' '│' )
for i in {1..40}; do
    sym=${spinner[$i % 4]}
    printf "\r  ${yellow}%s${reset} # # Авторизация в Cloudflare и проверка сетевых маршрутов..." "$sym"
    sleep 0.15
done

NEW_IP=$(curl -4 --connect-timeout 5 -s ifconfig.me)
HB_TEST=$(curl -4 --connect-timeout 5 -s -o /dev/null -w "%{http_code}" https://google.com)

clear
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"
echo -e "                       ИТОГОВЫЙ ОТЧЕТ ПРОВЕРКИ МАРШРУТИЗАЦИИ                        "
echo -e "${cyan}██████████████════════════════════════════════════════════════════════██████████████${reset}"

echo -e "\n  ${green}█████████████████████████████████████████████████████████████████████████████${reset}"
echo -e "   • Исходный IP провайдера:     ${yellow}$OLD_IP${reset}"
echo -e "   • Текущий защищенный IP WARP:  ${green}$NEW_IP${reset}"
if [ "$HB_TEST" = "200" ] || [ "$HB_TEST" = "301" ] || [ "$HB_TEST" = "302" ]; then
    echo -e "   • Доступ к внешней сети:       ${green}[ОК] Заблокированные ресурсы успешно ожили!${reset}"
else
    echo -e "   • Доступ к внешней сети:       ${red}[СБОЙ СВЯЗИ] Проверьте ключи на сервере.${reset}"
fi
echo -e "  ${green}█████████████████████████████████████████████████████████████████████████████${reset}\n"

exit 0
EOF

# Выдаем системные права на запуск созданной утилиты внутри инсталлятора
sudo chmod +x /usr/local/bin/mihomoimport
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -n "  # # Регистрация и развертывание фонового демона службы..."
sudo tee /etc/systemd/system/mihomo.service > /dev/null << EOF
[Unit]
Description=Mihomo Daemon
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
echo -e " ${green}[Готово]${reset}"

sleep 1.2
clear
ZagolovokSuccess "$FINAL_VER"

echo -e "  ${bg_text}┌─────────────────────────────────────────────────────────────────────────┐${reset}"
echo -e "  ${bg_text}│            📥 ИНСТРУКЦИЯ ПО ИНИЦИАЛИЗАЦИИ ЗАЩИЩЕННОГО ТУННЕЛЯ:          │${reset}"
echo -e "  ${bg_text}├─────────────────────────────────────────────────────────────────────────┤${reset}"
echo -e "  ${bg_text}│  1. Откройте в браузере сайт: warp-generation.github.io                 │${reset}"
echo -e "  ${bg_text}│  2. Нажмите кнопку 'Clash -> AWG 2.0' и полностью скопируйте текст.     │${reset}"
echo -e "  ${bg_text}│  3. Вставьте скопированная конфигурацию прямо сюда, в окно терминала.   │${reset}"
echo -e "  ${bg_text}│  4. После вставки нажмите Enter, а затем комбинацию клавиш: Ctrl + D    │${reset}"
echo -e "  ${bg_text}└─────────────────────────────────────────────────────────────────────────┘${reset}"
echo ""

TMP_INPUT=$(mktemp)
chmod 666 "$TMP_INPUT"
cat > "$TMP_INPUT"

clear
ZagolovokSuccess "$FINAL_VER"

if [ ! -s "$TMP_INPUT" ] || ! grep -q "proxies" "$TMP_INPUT"; then
    rm -f "$TMP_INPUT"
    sudo touch /etc/mihomo/warp.yaml
    echo -e "\n  ${yellow}[ПРОПУЩЕНО] Ввод отменен. Настройка отложена.${reset}\n"
    exit 0
fi

sudo mv "$TMP_INPUT" /etc/mihomo/warp.yaml
sudo systemctl enable --now mihomo > /dev/null 2>&1

spinner=( '╱' '─' '╲' '│' )
for i in {1..30}; do
    sym=${spinner[$i % 4]}
    printf "\r  ${yellow}%s${reset} # # Проверка пинга и инициализация защищенного интерфейса..." "$sym"
    sleep 0.1
done

NEW_IP=$(curl -4 --connect-timeout 4 -s ifconfig.me)
HB_TEST=$(curl -4 --connect-timeout 4 -s -o /dev/null -w "%{http_code}" https://google.com)

clear
ZagolovokSuccess "$FINAL_VER"
echo -e "\n  ${green}█████████████████████████████████████████████████████████████████████████████${reset}"
echo -e "   • Исходный IP провайдера:     ${yellow}$OLD_IP${reset}"
echo -e "   • Текущий защищенный IP WARP:  ${green}$NEW_IP${reset}"
if [ "$HB_TEST" = "200" ] || [ "$HB_TEST" = "301" ] || [ "$HB_TEST" = "302" ]; then
    echo -e "   • Доступ к внешней сети:       ${green}[ОК] Заблокированные ресурсы успешно ожили!${reset}"
else
    echo -e "   • Доступ к внешней сети:       ${red}[СБОЙ СВЯЗИ] Проверьте ключи на сервере.${reset}"
fi
echo -e "  ${green}█████████████████████████████████████████████████████████████████████████████${reset}\n"
exit 0
