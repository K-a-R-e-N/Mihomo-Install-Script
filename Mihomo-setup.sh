#!/bin/bash
# ==============================================================================
#   Mihomo-setup.sh — установщик ядра Mihomo (Clash Meta / AmneziaWG)
#   Debian / Ubuntu / Armbian и другие 64-битные системы (amd64, arm64).
#   Панель ставится отдельным файлом mihomoutil.sh с GitHub.
#   Обновление панели: mihomoutil -> пункт U (без переустановки ядра)
# ==============================================================================

green=$'\033[92m'
yellow=$'\033[93m'
red=$'\033[91m'
cyan=$'\033[96m'
dim=$'\033[90m'
reset=$'\033[0m'
bg_header=$'\033[30;47m'

REPO_RAW="https://raw.githubusercontent.com/K-a-R-e-N/Mihomo-Install-Script/main"
REPO_API="https://api.github.com/repos/K-a-R-e-N/Mihomo-Install-Script/commits"
SILENT_INSTALL=false
if [ "$1" = "--silent" ]; then
    SILENT_INSTALL=true
fi

cd ~ || exit 1
clear

function ZagolovokInstall {
local t="Развертывание системы сетевой автоматизации MihomoUtil" w=80
local len=${#t} pad pad2 fill blank
pad=$(( (w - 2 - len) / 2 )); [ "$pad" -lt 0 ] && pad=0
pad2=$(( w - 2 - len - pad ))
fill=$(printf '%.0s▒' $(seq 1 $((w-2))))
blank=$(printf '%*s' "$((w-2))" '')
echo -e "${cyan}╔${fill}╗${reset}"
echo -e "${cyan}║${reset}${bg_header}${blank}${reset}${cyan}║${reset}"
echo -e "${cyan}║${reset}${bg_header}$(printf '%*s' "$pad" '')${t}$(printf '%*s' "$pad2" '')${reset}${cyan}║${reset}"
echo -e "${cyan}║${reset}${bg_header}${blank}${reset}${cyan}║${reset}"
echo -e "${cyan}╚${fill}╝${reset}"
}

# Рамки-подзаголовки единой ширины: обе линии всегда одинаковой длины,
# весь блок отодвинут от левого края на 2 пробела.
function SubTitle {
local t="$1" w=74 len pad pad2 fill_l fill_r
len=${#t}
pad=$(( (w - 4 - len) / 2 )); [ "$pad" -lt 2 ] && pad=2
pad2=$(( w - 4 - len - pad )); [ "$pad2" -lt 2 ] && pad2=2
fill_l=$(printf '═%.0s' $(seq 1 $pad))
fill_r=$(printf '═%.0s' $(seq 1 $pad2))
echo -e "  ${cyan}╔${fill_l}  ${t}  ${fill_r}╗${reset}"
}

function SubBottom {
echo -e "  ${cyan}╚$(printf '═%.0s' $(seq 1 74))╝${reset}"
}

ZagolovokInstall
echo ""
echo -e "  ${dim}# # Для работы скрипта необходимы права суперпользователя.${reset}"
sudo -v || exit 1
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_PID=$!
cleanup() { if kill -0 "$SUDO_PID" 2>/dev/null; then kill "$SUDO_PID" 2>/dev/null; fi; }
trap cleanup EXIT
clear

ZagolovokInstall

echo ""
echo -en "  ${dim}# #${reset} Анализ системы и резервное копирование текущих конфигураций..."
sudo mkdir -p /tmp/mihomo_bak
for f in warp_1.yaml warp_2.yaml warp_3.yaml warp_4.yaml warp_5.yaml warp_primary.yaml warp_backup.yaml rules.yaml; do
    if [ -f "/etc/mihomo/$f" ]; then sudo cp -f "/etc/mihomo/$f" /tmp/mihomo_bak/; fi
done
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Полная деинсталляция старых системных служб и очистка путей..."
sudo systemctl disable --now amneziawg > /dev/null 2>&1
sudo systemctl disable --now mihomo > /dev/null 2>&1
sudo killall -9 awg awg-quick mihomo > /dev/null 2>&1
sudo rm -f /etc/update-motd.d/99-mihomoutil
sudo rm -f /etc/profile.d/mihomoutil_motd.sh
sudo rm -rf /usr/local/bin/mihomo /usr/local/bin/mihomoutil /etc/systemd/system/mihomo.service
sudo systemctl daemon-reload > /dev/null 2>&1
echo -e " ${green}[Готово]${reset}"

OLD_IP=$(curl -4 --connect-timeout 4 -s ifconfig.me)
if [ -z "$OLD_IP" ]; then OLD_IP="Не удалось определить"; fi

echo -en "\n" ; echo -en "  ${dim}# #${reset} Подготовка каталогов и восстановление ваших настроек..."
sudo mkdir -p /usr/local/bin /etc/mihomo || exit 1
if [ -f /tmp/mihomo_bak/warp_1.yaml ]; then sudo mv -f /tmp/mihomo_bak/warp_1.yaml /etc/mihomo/; fi
if [ -f /tmp/mihomo_bak/warp_2.yaml ]; then sudo mv -f /tmp/mihomo_bak/warp_2.yaml /etc/mihomo/; fi
if [ -f /tmp/mihomo_bak/warp_3.yaml ]; then sudo mv -f /tmp/mihomo_bak/warp_3.yaml /etc/mihomo/; fi
if [ -f /tmp/mihomo_bak/warp_4.yaml ]; then sudo mv -f /tmp/mihomo_bak/warp_4.yaml /etc/mihomo/; fi
if [ -f /tmp/mihomo_bak/warp_5.yaml ]; then sudo mv -f /tmp/mihomo_bak/warp_5.yaml /etc/mihomo/; fi
if [ -f /tmp/mihomo_bak/warp_primary.yaml ] && [ ! -s /etc/mihomo/warp_1.yaml ]; then
    sudo mv -f /tmp/mihomo_bak/warp_primary.yaml /etc/mihomo/warp_1.yaml
fi
if [ -f /tmp/mihomo_bak/warp_backup.yaml ] && [ ! -s /etc/mihomo/warp_2.yaml ]; then
    sudo mv -f /tmp/mihomo_bak/warp_backup.yaml /etc/mihomo/warp_2.yaml
fi
if [ -f /tmp/mihomo_bak/rules.yaml ] && [ ! -s /etc/mihomo/rules.yaml ]; then
    sudo mv -f /tmp/mihomo_bak/rules.yaml /etc/mihomo/rules.yaml
fi
sudo rm -rf /tmp/mihomo_bak
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Поиск актуального релиза ядра на серверах GitHub API..."
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_NAME="linux-amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH_NAME="linux-arm64"
else
    echo -e " ${red}[ОШИБКА] Архитектура $ARCH не поддерживается — нужна 64-битная ОС (amd64 или arm64)${reset}"
    exit 1
fi

LATEST_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep "browser_download_url" | grep "$ARCH_NAME" | grep -v -i "compatible" | grep -v ".deb" | head -n 1 | cut -d '"' -f 4)
if [ -z "$LATEST_URL" ]; then
    LATEST_URL=$(curl -s https://api.github.com/repos/MetaCubeX/mihomo/releases | grep "browser_download_url" | grep "$ARCH_NAME" | grep -v -i "compatible" | grep -v -i "alpha" | grep -v -i "beta" | grep -v ".deb" | head -n 1 | cut -d '"' -f 4)
fi
if [ -z "$LATEST_URL" ]; then
    echo -e " ${red}[ОШИБКА] Не удалось получить адрес релиза — проверьте сеть и повторите${reset}"
    exit 1
fi
echo -e " ${green}[Готово]${reset}"

EXT="${LATEST_URL##*.}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Скачивание стабильного бинарного пакета ядра..."
sudo curl -sL -o /usr/local/bin/mihomo_download.$EXT "$LATEST_URL"
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Распаковка архива и развертывание исполняемого файла..."
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

if [ "$SILENT_INSTALL" = true ]; then
    echo ""
    echo -e "  ${green}[Тихая установка: автоматически выбран режим обхода по списку сайтов]${reset}"
    START_MODE="rule"
else
    clear
    ZagolovokInstall
    echo ""
    SubTitle " ВЫБОР РЕЖИМА СЕТЕВОГО ОБХОДА "
    echo -e "  1 — Обход по списку сайтов (только домены из rules.yaml)"
    echo -e "  2 — Глобальный режим (весь трафик через VPN)"
    SubBottom
    echo ""
    echo -e "  * Если нажать Enter — то по умолчанию выберется первый пункт"
    echo ""
    printf "  ${yellow}Ваш выбор: ${reset}"
    read INIT_MODE_CHOICE
    if [ "$INIT_MODE_CHOICE" = "2" ]; then
        START_MODE="global"
    else
        START_MODE="rule"
    fi
    echo ""
    echo ""
    if [ "$START_MODE" = "global" ]; then
        echo -e "  ${green}[Выбран режим: Глобальный — весь трафик через VPN]${reset}"
    else
        echo -e "  ${green}[Выбран режим: Обход по списку сайтов]${reset}"
    fi
fi

if [ ! -s /etc/mihomo/rules.yaml ]; then
echo -en "\n" ; echo -en "  ${dim}# #${reset} Создание стартового списка сайтов (rules.yaml)..."
sudo tee /etc/mihomo/rules.yaml > /dev/null << 'EOF'
payload:
  - 'DOMAIN-SUFFIX,homebridge.io'
EOF
echo -e " ${green}[Готово]${reset}"
fi

echo -en "\n" ; echo -en "  ${dim}# #${reset} Подготовка слотов профилей WARP и активной ссылки..."
for i in 1 2 3 4 5; do
    if [ ! -s "/etc/mihomo/warp_$i.yaml" ]; then
        sudo tee "/etc/mihomo/warp_$i.yaml" > /dev/null << EOF
proxies:
  - name: "EMPTY-SLOT-$i"
    type: socks5
    server: 127.0.0.1
    port: 1
EOF
        sudo chmod 600 "/etc/mihomo/warp_$i.yaml"
    fi
done

CURRENT_LINK=$(readlink /etc/mihomo/warp.yaml 2>/dev/null)
if [ "$CURRENT_LINK" != "/etc/mihomo/warp_1.yaml" ] && [ "$CURRENT_LINK" != "/etc/mihomo/warp_2.yaml" ] && [ "$CURRENT_LINK" != "/etc/mihomo/warp_3.yaml" ] && [ "$CURRENT_LINK" != "/etc/mihomo/warp_4.yaml" ] && [ "$CURRENT_LINK" != "/etc/mihomo/warp_5.yaml" ]; then
    sudo rm -f /etc/mihomo/warp.yaml
    sudo ln -s /etc/mihomo/warp_1.yaml /etc/mihomo/warp.yaml
fi

sudo rm -f /etc/mihomo/warp_primary.yaml /etc/mihomo/warp_backup.yaml
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Генерация системного манифеста config.yaml (Режим: $START_MODE)..."
sudo tee /etc/mihomo/config.yaml > /dev/null << EOF
mixed-port: 7890
allow-lan: true
mode: $START_MODE
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
  enhanced-mode: fake-ip
  nameserver:
    - 8.8.8.8
    - 1.1.1.1

proxy-providers:
  warp_provider:
    type: file
    path: ./warp.yaml
    health-check:
      enable: true
      url: http://cp.cloudflare.com/generate_204
      interval: 300

rule-providers:
  custom_rules:
    type: file
    behavior: classical
    path: ./rules.yaml

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
  - RULE-SET,custom_rules,WARP
  - MATCH,DIRECT
EOF
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Скачивание панели управления с GitHub (mihomoutil.sh)..."
sudo curl -sL -o /usr/local/bin/mihomoutil "$REPO_RAW/mihomoutil.sh"
if [ ! -s /usr/local/bin/mihomoutil ]; then
    echo -e " ${red}[ОШИБКА] Панель не скачалась — проверьте mihomoutil.sh в репозитории${reset}"
    exit 1
fi
if ! bash -n /usr/local/bin/mihomoutil > /dev/null 2>&1; then
    echo -e " ${red}[ОШИБКА] Файл панели поврежден на GitHub — установка остановлена${reset}"
    exit 1
fi
sudo chmod +x /usr/local/bin/mihomoutil
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Фиксация версии установщика для проверки обновлений..."
SETUP_SHA=$(curl -s "$REPO_API?path=Mihomo-setup.sh&per_page=1" | grep -m1 '"sha"' | cut -d '"' -f 4)
if [ -n "$SETUP_SHA" ]; then
    echo "$SETUP_SHA" | sudo tee /etc/mihomo/.setup_commit > /dev/null
    echo -e " ${green}[Готово]${reset}"
else
    echo "нет-ответа" | sudo tee /etc/mihomo/.setup_commit > /dev/null
    echo -e " ${yellow}[Готово] Метка не получена — проверка установщика подскажет переустановку${reset}"
fi

echo -en "\n" ; echo -en "  ${dim}# #${reset} Установка фоновой службы systemd..."
sudo tee /etc/systemd/system/mihomo.service > /dev/null << 'EOF'
[Unit]
Description=Mihomo Proxy Service
After=network.target

[Service]
ExecStart=/usr/local/bin/mihomo -d /etc/mihomo
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload > /dev/null 2>&1
sudo systemctl enable mihomo > /dev/null 2>&1
sudo systemctl start mihomo > /dev/null 2>&1
echo -e " ${green}[Готово]${reset}"

echo -en "\n" ; echo -en "  ${dim}# #${reset} Установка SSH-информера статуса..."
sudo tee /etc/profile.d/mihomoutil_motd.sh > /dev/null << 'EOF_INFO'
# Информер MihomoUtil (создается установщиком Mihomo-setup.sh)
if [ -t 1 ] && [ -n "$PS1" ]; then
  if systemctl is-active --quiet mihomo; then
    s="РАБОТАЕТ"; mc="\033[92m"
  else
    s="ОСТАНОВЛЕН"; mc="\033[91m"
  fi
  m="По списку сайтов"
  if [ "$(grep '^mode:' /etc/mihomo/config.yaml 2>/dev/null | awk '{print $2}')" = "global" ]; then
    m="Глобальный (весь трафик)"
  fi
  printf "\033[36mMihomo:\033[0m VPN-туннель ${mc}%s\033[0m | Режим: %s | Панель: \033[4;36mmihomoutil\033[0m\n" "$s" "$m"
fi
EOF_INFO
sudo chmod +x /etc/profile.d/mihomoutil_motd.sh
echo -e " ${green}[Готово]${reset}"

if [ "$SILENT_INSTALL" != true ]; then
    clear
    ZagolovokInstall
    echo ""
    SubTitle " ИМПОРТ КОНФИГУРАЦИИ AMNEZIAWG "
    echo -e "  Скопируйте ${green}весь текст${reset} со страницы ${cyan}warp-generation.github.io${reset}"
    echo -e "  под кнопкой ${green}Clash${reset} и вставьте сюда одним куском."
    echo -e "  Завершите ввод нажатием ${green}Ctrl + D${reset}."
    echo -e "  ${dim}Скрипт сам вырежет нужный блок и очистит экран от лишнего текста.${reset}"
    echo ""
    echo -e "  ${yellow}Enter или S — пропустить (ключи можно добавить позже через панель).${reset}"
    SubBottom
    echo ""
    printf "  Вставка: "
    tmp=$(mktemp)
    read -r FIRST_LINE
    FIRST_LINE=$(printf '%s' "$FIRST_LINE" | tr -d '\r')
    if [ -z "$FIRST_LINE" ] || [ "$FIRST_LINE" = "S" ] || [ "$FIRST_LINE" = "s" ]; then
        rm -f "$tmp"
        echo ""
        echo ""
        echo -e "  ${yellow}[Шаг пропущен — ключи не изменены]${reset}"
    else
        if printf '%s' "$FIRST_LINE" | grep -q ':'; then
            printf '%s\n' "$FIRST_LINE" >> "$tmp"
            cat >> "$tmp"
            grep -vE '[а-яА-ЯёЁ]' "$tmp" | tr -d '\r' > "$tmp.clean" 2>/dev/null
            if grep -q '^proxies:' "$tmp.clean"; then
                awk '
                    BEGIN { started=0; inanch=0; n=0; bad=0 }
                    {
                        line=$0
                        if (inanch) {
                            if (line ~ /^[ \t]+[^ \t]/) { s=line; sub(/^[ \t]+/, "", s); anchor[n++]=s; next }
                            inanch=0
                        }
                        if (!started && line ~ /^[A-Za-z_][A-Za-z0-9_-]*:[ \t]*&[A-Za-z0-9_-]+[ \t]*$/) { inanch=1; next }
                        if (!started && line ~ /^proxies:/) { started=1; print line; next }
                        if (started) {
                            if (line ~ /^(proxy-groups|rules):/) exit
                            if (line ~ /^[ \t]*<<:[ \t]*\*[A-Za-z0-9_-]+/) {
                                if (n == 0) bad=1
                                ind = substr(line, 1, index(line, "<<") - 1)
                                for (k=0; k<n; k++) print ind anchor[k]
                            } else print line
                        }
                    }
                    END { if (bad || !started) exit 9 }
                ' "$tmp.clean" > "$tmp.out" 2>/dev/null
                if [ "$(wc -l < "$tmp.out")" -ge 3 ] && [ "$(grep -c 'private-key:' "$tmp.out")" -ge 1 ]; then
                    sudo tee /etc/mihomo/warp_1.yaml < "$tmp.out" > /dev/null
                    sudo chmod 600 /etc/mihomo/warp_1.yaml
                    sudo systemctl restart mihomo > /dev/null 2>&1
                    echo ""
                    echo ""
                    echo -e "  ${green}[Готово] Ключи сохранены в Профиль №1 — текст конфигурации стерт с экрана${reset}"
                else
                    echo ""
                    echo ""
                    echo -e "  ${yellow}[Блок пуст — ключи не сохранены, добавьте позже через панель]${reset}"
                fi
            else
                echo ""
                echo ""
                echo -e "  ${yellow}[Блок proxies: не найден — добавьте ключи позже через панель]${reset}"
            fi
        else
            echo ""
            echo ""
            echo -e "  ${yellow}[Это не конфигурация — добавьте ключи позже через панель]${reset}"
        fi
    fi
    rm -f "$tmp" "$tmp.clean" "$tmp.out" 2>/dev/null
fi

sudo systemctl restart mihomo > /dev/null 2>&1
sleep 2

clear
ZagolovokInstall
echo ""
HAS_KEYS=false
for _i in 1 2 3 4 5; do
    if sudo test -s "/etc/mihomo/warp_$_i.yaml" && ! sudo grep -q "EMPTY-SLOT" "/etc/mihomo/warp_$_i.yaml" 2>/dev/null; then
        HAS_KEYS=true
    fi
done
if [ "$HAS_KEYS" != true ]; then
    echo -e "  ${yellow}Ключи не введены — финальная проверка доступности пропущена.${reset}"
    echo -e "  Конфигурацию можно добавить позже через панель: ${green}mihomoutil${reset} -> Профили WARP."
    echo ""
fi
if [ "$HAS_KEYS" = true ]; then
SubTitle " ФИНАЛЬНАЯ ПРОВЕРКА ДОСТУПНОСТИ "
echo -e "  Опрос сайтов из списка через порт шлюза 7890 (VPN-интерфейс):"
echo ""
FAILS=0
TOTAL=0
while read -r d; do
    [ -z "$d" ] && continue
    code=$(curl -4 -s -o /dev/null -w "%{http_code}" --socks5-hostname 127.0.0.1:7890 --connect-timeout 6 "https://$d")
    TOTAL=$((TOTAL+1))
    if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "403" ]; then
        echo -e "   ${green}[ДОСТУПЕН]${reset}  $d"
    else
        echo -e "   ${red}[НЕДОСТУПЕН]${reset}  $d  (HTTP: $code)"
        FAILS=$((FAILS+1))
    fi
    sleep 1
done < <(sed -n "s/.*DOMAIN-SUFFIX,\([^']*\).*/\1/p" /etc/mihomo/rules.yaml)
echo ""
if [ "$TOTAL" -eq 0 ]; then
    echo -e "  ${yellow}Список пуст — добавьте домены через панель (пункт 2)${reset}"
elif [ "$FAILS" -gt 0 ]; then
    echo -e "  ${red}Итог: сбоев $FAILS из $TOTAL. Если сбои у всех — проверьте ключи (пункт 5)${reset}"
else
    echo -e "  ${green}Итог: все $TOTAL сайтов доступны${reset}"
fi
SubBottom
fi

echo ""
SubTitle " УСТАНОВКА ЗАВЕРШЕНА "
echo -e "  Версия ядра:        ${green}${FINAL_VER:-неизвестна}${reset}"
echo -e "  Внешний IP:         $OLD_IP"
echo -e "  Режим сети:         ${green}$([ "$START_MODE" = "global" ] && echo "Глобальный — весь трафик через VPN" || echo "Обход по списку сайтов")${reset}"
echo -e "  Панель управления:  ${green}mihomoutil${reset}  ${dim}(запуск из любого места)${reset}"
echo -e "  Служба:             ${green}sudo systemctl status mihomo${reset}"
SubBottom
echo ""
echo -n "Нажмите Enter для запуска панели mihomoutil (0 — выход): "
read FINAL_WAIT
if [ "$FINAL_WAIT" != "0" ]; then
    kill "$SUDO_PID" 2>/dev/null
    clear
    exec mihomoutil
fi
clear
