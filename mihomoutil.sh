#!/bin/bash
# ==============================================================================
#   mihomoutil — панель управления MihomoUtil
#   Ставится установщиком Mihomo-setup.sh. Обновление: mihomoutil --update
# ==============================================================================
# === START_OF_UTIL ===
CY=$'\033[1;36m'
GR=$'\033[1;32m'
YL=$'\033[1;33m'
RD=$'\033[1;31m'
DM=$'\033[0;90m'
RS=$'\033[0m'
BG=$'\033[1;38;5;16;107m'
# Цвета главного меню (по образцу): WT — белый, BW — жирно-белый, GY — серый,
# HDR — чёрный текст на ярко-белом (плашки секций)
WT=$'\033[0;37m'
BW=$'\033[1;37m'
GY=$'\033[0;90m'
HDR=$'\033[1;38;5;16;107m'

REPO_UTIL="https://raw.githubusercontent.com/K-a-R-e-N/Mihomo-Install-Script/main/mihomoutil.sh"
REPO_API="https://api.github.com/repos/K-a-R-e-N/Mihomo-Install-Script/commits?path=mihomoutil.sh&per_page=1"
SETUP_API="https://api.github.com/repos/K-a-R-e-N/Mihomo-Install-Script/commits?path=Mihomo-setup.sh&per_page=1"

CONF=/etc/mihomo
SLOT1=$CONF/warp_1.yaml
SLOT2=$CONF/warp_2.yaml
SLOT3=$CONF/warp_3.yaml
SLOT4=$CONF/warp_4.yaml
SLOT5=$CONF/warp_5.yaml
LINK=$CONF/warp.yaml
RULES=$CONF/rules.yaml
CFGS=$CONF/config.yaml
SETUP_MARK=$CONF/.setup_commit
UTIL_FILE=/usr/local/bin/mihomoutil
ERR_COUNT_FILE=/tmp/mihomo_err_count
LAST_ERR_FILE=/tmp/mihomo_last_err
INFORMER=/etc/profile.d/mihomoutil_motd.sh
PROXY_PORT=7890

if [ "$EUID" -ne 0 ]; then exec sudo "$0" "$@"; fi

[ -f "$ERR_COUNT_FILE" ] || echo "0" > "$ERR_COUNT_FILE"
[ -f "$LAST_ERR_FILE" ] || echo "Ошибок нет" > "$LAST_ERR_FILE"

# --- Миграция старых слотов (warp_primary/warp_backup -> warp_1/warp_2) ---
if [ -f "$CONF/warp_primary.yaml" ] && [ ! -s "$SLOT1" ]; then
    mv -f "$CONF/warp_primary.yaml" "$SLOT1" 2>/dev/null
fi
if [ -f "$CONF/warp_backup.yaml" ] && [ ! -s "$SLOT2" ]; then
    mv -f "$CONF/warp_backup.yaml" "$SLOT2" 2>/dev/null
fi
if [ ! -s "$SLOT1" ]; then
    printf 'proxies:\n  - name: "EMPTY-SLOT-1"\n    type: socks5\n    server: 127.0.0.1\n    port: 1\n' > "$SLOT1"
fi
if [ -L "$LINK" ] && [ ! -e "$LINK" ]; then
    for _i in 1 2 3 4 5; do
		if [ -s "$CONF/warp_${_i}.yaml" ] && ! grep -q "EMPTY-SLOT" "$CONF/warp_${_i}.yaml" 2>/dev/null; then
            ln -sfn "$CONF/warp_${_i}.yaml" "$LINK"; break
        fi
    done
    if [ ! -e "$LINK" ]; then ln -sfn "$SLOT1" "$LINK"; fi
fi

function RU2EN {
    printf '%s' "$1" | sed 's|[йЙ]|q|g; s|[цЦ]|w|g; s|[уУ]|e|g; s|[кК]|r|g; s|[еЕ]|t|g; s|[нН]|y|g; s|[гГ]|u|g; s|[шШ]|i|g; s|[щЩ]|o|g; s|[зЗ]|p|g; s|[хХ]|[|g; s|[ъЪ]|]|g; s|[фФ]|a|g; s|[ыЫ]|s|g; s|[вВ]|d|g; s|[аА]|f|g; s|[пП]|g|g; s|[рР]|h|g; s|[оО]|j|g; s|[лЛ]|k|g; s|[дД]|l|g; s|[яЯ]|z|g; s|[чЧ]|x|g; s|[сС]|c|g; s|[мМ]|v|g; s|[иИ]|b|g; s|[тТ]|n|g; s|[ьЬ]|m|g'
}

function charlen {
    local s="$1"
    local LC_ALL=C LANG=C
    local bytes=${#s}
    local cont
    cont=$(printf '%s' "$s" | od -An -tx1 | tr -s ' ' '\n' | grep -cE '^[89ab][0-9a-f]$')
    echo $(( bytes - cont ))
}

function FrameTitle {
    local t="$1" w=80 len pad pad2 sp1 sp2 fill blank
    len=$(charlen "$t")
    pad=$(( (w - 2 - len) / 2 )); [ "$pad" -lt 0 ] && pad=0
    pad2=$(( w - 2 - len - pad ))
    sp1=$(printf '%*s' "$pad" '')
    sp2=$(printf '%*s' "$pad2" '')
    fill=""
    if [ $((w-2)) -gt 0 ]; then fill=$(printf '%.0s▒' $(seq 1 $((w-2)))); fi
    blank=$(printf '%*s' "$((w-2))" '')
    echo -e "${CY}╔${fill}╗${RS}"
    echo -e "${CY}║${RS}${BG}${blank}${RS}${CY}║${RS}"
    echo -e "${CY}║${RS}${BG}${sp1}${t}${sp2}${RS}${CY}║${RS}"
    echo -e "${CY}║${RS}${BG}${blank}${RS}${CY}║${RS}"
    echo -e "${CY}╚${fill}╝${RS}"
}

function SubTitle {
    local t="$1" w=64 len total l r fill_l fill_r fill
    len=$(charlen "$t")
    total=$(( w - 8 - len )); [ "$total" -lt 2 ] && total=2
    l=$(( total / 2 )); r=$(( total - l ))
    fill_l=""; [ "$l" -gt 0 ] && fill_l=$(printf '%.0s═' $(seq 1 $l))
    fill_r=""; [ "$r" -gt 0 ] && fill_r=$(printf '%.0s═' $(seq 1 $r))
    fill=""
    if [ $((w-2)) -gt 0 ]; then fill=$(printf '%.0s═' $(seq 1 $((w-2)))); fi
    echo -e "${CY}╔══${fill_l}  ${t}  ${fill_r}╗${RS}"
    echo -e "${CY}╚${fill}╝${RS}"
}

function is_filled { [ -s "$1" ] && ! grep -q "EMPTY-SLOT" "$1" 2>/dev/null && grep -qE 'private-key[[:space:]]*:|server[[:space:]]*:' "$1" 2>/dev/null; }
function svc_on { systemctl is-active --quiet mihomo 2>/dev/null; }
function auto_on { systemctl is-enabled mihomo 2>/dev/null | grep -q enabled; }
function active_slot {
    local l=$(readlink "$LINK" 2>/dev/null)
    case "$l" in
        *warp_1*|*warp_primary*) echo 1 ;;
        *warp_2*|*warp_backup*) echo 2 ;;
        *warp_3*) echo 3 ;;
        *warp_4*) echo 4 ;;
        *warp_5*) echo 5 ;;
        *) echo 1 ;;
    esac
}

function domains_list {
    sed -n "s/.*DOMAIN-SUFFIX,\([^']*\).*/\1/p" "$RULES" 2>/dev/null
}
function restart_q { systemctl restart mihomo > /dev/null 2>&1; }
function get_act {
    local _a
    read -rp "  ${BW}Действие:${RS} " _a
    _a=$(RU2EN "$_a")
    printf '%s' "$_a"
}
function pause { local _p; echo -n "Нажмите Enter для возврата..."; read _p; }
function empty_slot_content {
    printf 'proxies:\n  - name: "EMPTY-SLOT-%s"\n    type: socks5\n    server: 127.0.0.1\n    port: 1\n' "$1"
}
function BackgroundWatchdog {
    while true; do
        [ -f "$RULES" ] || { sleep 5; continue; }
        local domains=$(domains_list)
        if [ -z "$domains" ]; then echo "0" > "$ERR_COUNT_FILE"; sleep 5; continue; fi
        local current_errors=0 last_failed_domain=""
        for d in $domains; do
            local code=$(curl -4 -s -o /dev/null -w "%{http_code}" --socks5-hostname 127.0.0.1:$PROXY_PORT --connect-timeout 3 "https://$d")
            if [ "$code" != "200" ] && [ "$code" != "301" ] && [ "$code" != "302" ] && [ "$code" != "403" ]; then
                current_errors=$((current_errors + 1)); last_failed_domain="$d"
            fi
            sleep 2
        done
        echo "$current_errors" > "$ERR_COUNT_FILE"
        if [ "$current_errors" -gt 0 ]; then
            echo "$last_failed_domain" > "$LAST_ERR_FILE"
            local a=$(active_slot) cand
            for cand in 1 2 3 4 5; do
                [ "$cand" = "$a" ] && continue
                if is_filled "$CONF/warp_${cand}.yaml"; then
                    ln -sfn "$CONF/warp_${cand}.yaml" "$LINK"
                    restart_q
                    break
                fi
            done
        else
            echo "Ошибок нет" > "$LAST_ERR_FILE"
        fi
        sleep 5
    done
}

function install_informer {
    cat > "$INFORMER" << 'EOF_INFO'
# Информер MihomoUtil (создается утилитой mihomoutil)
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
}

function HelpBody {
    echo -e "  ${CY}Панель управления:${RS} команда mihomoutil (без аргументов)"
    echo ""
    echo -e "  ${DM}── Сайты и режимы ──${RS}"
    echo -e "    --list            Показать текущую таблицу доменов из rules.yaml"
    echo -e "    --add [домен]     Внести адрес в обход (пример: --add google.com)"
    echo -e "    --remove [домен]  Убрать адрес из списка обхода"
    echo -e "    --bulk            Редактировать список одним блоком (вставка списка)"
    echo -e "    --check           Быстрый тест доступности всех сайтов"
    echo -e "    --mode-selective  Режим: обход только по списку сайтов"
    echo -e "    --mode-global     Режим: весь трафик"
    echo ""
    echo -e "  ${DM}── Профили и служба ──${RS}"
    echo -e "    --config-num1..5  Сделать активным Профиль №1-№5"
    echo -e "    --keys-1..5       Ввести/заменить ключи Профиля №1-№5"
    echo -e "    --start / --stop  Запустить / остановить фоновую службу шлюза"
    echo -e "    --enable / --disable  Автозапуск туннеля при загрузке системы"
    echo -e "    --ssh-enable / --ssh-disable  Информер статуса при SSH-входе"
    echo ""
    echo -e "  ${DM}── Обслуживание ──${RS}"
    echo -e "    --update          Обновить панель с GitHub (ядро не переустанавливается)"
    echo -e "    --logs            Живые логи ядра Mihomo в реальном времени"
    echo ""
    echo -e "  ${DM}Подсказка: если забыли переключить раскладку, меню все равно поймет"
    echo -e "  русские буквы — набирайте как есть, ответ придет латиницей.${RS}"
}


function ShowHelp {
    echo -e "${CY}Использование: mihomoutil [АРГУМЕНТ]${RS}"
    echo ""
    HelpBody
}

function HelpScreen {
    clear
    FrameTitle " СПРАВКА ПО УТИЛИТЕ MIHOMOUTIL "
    echo ""
    HelpBody
    echo ""
    pause
}

function ViewSites {
    clear
    FrameTitle " СПИСОК САЙТОВ В ОБХОДЕ "
    echo ""
    local n=0 d
    while read -r d; do
        [ -z "$d" ] && continue
        n=$((n+1))
        echo -e "   ${GY}(${BW}$n${GY})${RS} ${WT}$d${RS}"
    done < <(domains_list)
    [ "$n" -eq 0 ] && echo -e "   ${RD}Список пуст${RS}"
    echo ""
    pause
}

function AddSiteMenu {
    local nd
    clear
    FrameTitle " ДОБАВЛЕНИЕ ДОМЕНА "
    echo ""
    echo -n "Введите домен для добавления (0 — отмена): "
    read nd
    nd=$(RU2EN "$nd")
    [ "$nd" = "0" ] && return
    if ! printf '%s' "$nd" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'; then
        echo -e "  ${RD}[ОШИБКА] Некорректный домен — повторите ввод${RS}"
        sleep 2; return
    fi
    if domains_list | grep -qx "$nd"; then
        echo -e "  ${YL}[ВНИМАНИЕ] Домен $nd уже в списке${RS}"
        sleep 2; return
    fi
    if ! grep -q '^payload:' "$RULES" 2>/dev/null; then printf 'payload:\n' > "$RULES"; fi
    sed -i "/^payload:/a\\  - 'DOMAIN-SUFFIX,$nd'" "$RULES"
    restart_q
    echo -e "  ${GR}[Готово] Домен $nd добавлен, служба перезапущена${RS}"
    sleep 2
}

function BulkEditMenu {
    local tmp d first added=0 bad=0 dup=0
    clear
    FrameTitle " МАССОВОЕ РЕДАКТИРОВАНИЕ СПИСКА "
    echo ""
    echo -e "  Вставьте список доменов (каждый с новой строки) и завершите вводом ${GR}Ctrl + D${RS}."
    echo -e "  ${YL}Enter${RS} — отмена."
    echo ""
    tmp=$(mktemp)
    local first=""
    if read -r first; then
        first=$(printf '%s' "$first" | tr -d '\r\t ')
        if [ -z "$first" ]; then
            rm -f "$tmp"; echo -e "  ${YL}[Отменено]${RS}"; sleep 2; return
        fi
        printf '%s\n' "$first" > "$tmp"
        cat >> "$tmp" 2>/dev/null
    fi
    if ! grep -q '[^[:space:]]' "$tmp" 2>/dev/null; then
        rm -f "$tmp"; echo -e "  ${YL}[Отменено]${RS}"; sleep 2; return
    fi
    while read -r d; do
        d=$(printf '%s' "$d" | tr -d ' \r')
        [ -z "$d" ] && continue
        d=$(printf '%s' "$d" | sed 's|https\?://||; s|/.*||')
        if ! printf '%s' "$d" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9.-]*$'; then
            bad=$((bad+1)); continue
        fi
        if domains_list | grep -qx "$d"; then
            dup=$((dup+1)); continue
        fi
        if ! grep -q '^payload:' "$RULES" 2>/dev/null; then printf 'payload:\n' > "$RULES"; fi
        sed -i "/^payload:/a\\  - 'DOMAIN-SUFFIX,$d'" "$RULES"
        added=$((added+1))
    done < "$tmp"
    rm -f "$tmp"
    restart_q
    echo ""
    echo -e "  ${GR}[Готово] Добавлено: $added${RS} | Пропущены дубли: $dup | Некорректные строки: $bad"
    sleep 3
}


function RemoveSiteMenu {
    local nd _ln
    clear
    FrameTitle " УДАЛЕНИЕ ДОМЕНА "
    echo ""
    local n=0 d
    while read -r d; do
        [ -z "$d" ] && continue
        n=$((n+1)); echo -e "   ${GY}(${BW}$n${GY})${RS} ${WT}$d${RS}"
    done < <(domains_list)
    [ "$n" -eq 0 ] && echo -e "   ${RD}Список пуст${RS}"
    echo ""
    echo -n "Номер или домен для удаления (0 — отмена): "
    read nd
    nd=$(RU2EN "$nd")
    [ "$nd" = "0" ] && return
    if printf '%s' "$nd" | grep -qE '^[0-9]+$'; then
        nd=$(domains_list | sed -n "${nd}p")
        [ -z "$nd" ] && { echo -e "  ${RD}[ОШИБКА] Нет такого номера${RS}"; sleep 2; return; }
    fi
    if ! grep -qF "DOMAIN-SUFFIX,$nd'" "$RULES"; then
        echo -e "  ${YL}[ВНИМАНИЕ] Домена $nd нет в списке${RS}"
        sleep 2; return
    fi
    for _ln in $(grep -nF "DOMAIN-SUFFIX,$nd'" "$RULES" | cut -d: -f1 | sort -rn); do sed -i "${_ln}d" "$RULES"; done
    restart_q
    echo -e "  ${GR}[Готово] Домен $nd удален, служба перезапущена${RS}"
    sleep 2
}

function FullCheckMenu {
    clear
    FrameTitle " ТЕСТ ДОСТУПНОСТИ САЙТОВ "
    echo ""
    echo -e "  Опрос сайтов через порт шлюза $PROXY_PORT (VPN-интерфейс):"
    echo ""
    local n=0 fails=0 d code
    while read -r d; do
        [ -z "$d" ] && continue
        code=$(curl -4 -s -o /dev/null -w "%{http_code}" --socks5-hostname 127.0.0.1:$PROXY_PORT --connect-timeout 6 "https://$d")
        n=$((n+1))
        if [ "$code" = "200" ] || [ "$code" = "301" ] || [ "$code" = "302" ] || [ "$code" = "403" ]; then
            echo -e "   ${GR}[ДОСТУПЕН]${RS}  $d"
        else
            echo -e "   ${RD}[НЕДОСТУПЕН]${RS}  $d  (HTTP: $code)"
            fails=$((fails+1))
        fi
        sleep 1
    done < <(domains_list)
    echo ""
    if [ "$n" -eq 0 ]; then
        echo -e "  ${YL}Список пуст — добавьте домены в пункте 2 или 3${RS}"
    elif [ "$fails" -gt 0 ]; then
        echo -e "  ${RD}Итог: СБОЕВ $fails из $n. Детали — клавиша L (живые логи ядра)${RS}"
    else
        echo -e "  ${GR}Итог: все $n сайтов доступны${RS}"
    fi
    echo ""
    pause
}

function SwitchProfile {
    local t="$1"
    local f="$CONF/warp_${t}.yaml"
    if ! is_filled "$f"; then
        echo -e "  ${RD}[ОШИБКА] Профиль №$t пуст — введите ключи (11/22/33/44/55)${RS}"
        sleep 2; return
    fi
    if [ "$(active_slot)" = "$t" ]; then
        echo -e "  ${YL}[ВНИМАНИЕ] Профиль №$t уже активен — переключение не требуется${RS}"
        sleep 2; return
    fi
    ln -sfn "$f" "$LINK"
    restart_q
    echo -e "  ${GR}[Готово] Активен Профиль №$t, служба перезапущена${RS}"
    sleep 2
}

function InputKeysSlot {
    local f="$1" num="$3" tmp first cmd j
    while true; do
        clear
        FrameTitle " Профиль №$num — ВВОД КОНФИГУРАЦИИ "
        echo ""
        echo -e "  Скопируйте ${GR}весь текст${RS} со страницы ${CY}warp-generation.github.io${RS}"
        echo -e "  под кнопкой ${GR}Clash${RS} и вставьте сюда одним куском."
        echo -e "  Завершите ввод нажатием ${GR}Ctrl + D${RS}."
        echo -e "  ${DM}Скрипт сам вырежет нужный блок и очистит экран от лишнего текста.${RS}"
        echo ""
        echo -e "  ${YL}Enter${RS} — пропустить этот шаг."
        echo -e "  ${RD}D / Delete / Clear${RS} — очистить профиль (удалить ключи с диска)."
        echo ""
        tmp=$(mktemp)
        local first=""
        if read -r first; then
            first=$(printf '%s' "$first" | tr -d '\r\t ')
            if [ -z "$first" ]; then
                rm -f "$tmp"
                echo -e "  ${YL}[Шаг пропущен — ключи не изменены]${RS}"
                sleep 2
                return 1
            fi
            cmd=$(printf '%s' "$first" | tr '[:upper:]' '[:lower:]')
            if [ "$cmd" = "d" ] || [ "$cmd" = "delete" ] || [ "$cmd" = "clear" ]; then
                rm -f "$tmp"
                rm -f "$f"
                if [ "$(active_slot)" = "$num" ]; then
                    for j in 1 2 3 4 5; do
                        if [ "$j" != "$num" ] && [ -s "$CONF/warp_${j}.yaml" ] && ! grep -q "EMPTY-SLOT" "$CONF/warp_${j}.yaml" 2>/dev/null; then ln -sfn "$CONF/warp_${j}.yaml" "$LINK"; break; fi
                    done
                    if [ ! -e "$LINK" ]; then
                        empty_slot_content 1 > "$SLOT1"
                        ln -sfn "$SLOT1" "$LINK"
                    fi
                    restart_q
                    echo -e "  ${GR}[Готово] Профиль №$num удален с диска, активирован доступный профиль${RS}"
                else
                    echo -e "  ${GR}[Готово] Профиль №$num удален с диска${RS}"
                fi
                sleep 2
                return 1
            fi
            printf '%s\n' "$first" > "$tmp"
            cat >> "$tmp" 2>/dev/null
        fi
        if ! grep -q '[^[:space:]]' "$tmp" 2>/dev/null; then
            rm -f "$tmp"
            echo -e "  ${YL}[Шаг пропущен — ключи не изменены]${RS}"
            sleep 2
            return 1
        fi
        tr -d '\r' < "$tmp" > "$tmp.clean"
        if ! grep -q '^proxies:' "$tmp.clean"; then
            rm -f "$tmp" "$tmp.clean" "$tmp.out"
            echo -e "  ${RD}[ОШИБКА] Блок proxies: не найден — конфигурация НЕ сохранена${RS}"
            echo -e "  ${RD}Похоже, вы скопировали раздел AWG 2.0 — нужен текст под кнопкой Clash${RS}"
            sleep 4
            continue
        fi
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
        if [ $? -ne 0 ] || [ "$(grep -cE '^[[:space:]]*-[[:space:]]*name:' "$tmp.out")" -lt 1 ] \
           || [ "$(grep -c 'private-key:' "$tmp.out")" -lt 1 ]; then
            rm -f "$tmp" "$tmp.clean" "$tmp.out"
            echo -e "  ${RD}[ОШИБКА] Ключи не распознаны (нет блока warp-common или private-key).${RS}"
            echo -e "  ${RD}Вставьте текст целиком под кнопкой Clash и повторите${RS}"
            sleep 4
            continue
        fi
        NPROXY=$(grep -cE '^[[:space:]]*-[[:space:]]*name:' "$tmp.out")
        tee "$f" < "$tmp.out" > /dev/null
        chmod 600 "$f" 2>/dev/null
        rm -f "$tmp" "$tmp.clean" "$tmp.out"
        clear
        echo -e "  ${GR}[Готово] Ключи сохранены в Профиль №$num (прокси: $NPROXY)${RS}"
        echo -e "  ${DM}Файл профиля: $f${RS}"
        sleep 2
        return 0
    done
}


function ClearAll {
    local yn i
    echo -n "Точно удалить ключи из ВСЕХ ПЯТИ профилей? (y/n): "
    read yn; yn=$(RU2EN "$yn")
    if [ "$yn" != "y" ]; then echo -e "  ${DM}Отменено${RS}"; sleep 1; return; fi
    for i in 1 2 3 4 5; do rm -f "$CONF/warp_${i}.yaml"; done
    empty_slot_content 1 > "$SLOT1"
    ln -sfn "$SLOT1" "$LINK"
    restart_q
    echo -e "  ${GR}[Готово] Все профили удалены с диска, активен Профиль №1${RS}"
    sleep 2
}


function ProfilesMenu {
    while true; do
        clear
        FrameTitle " ПРОФИЛИ WARP "
        local a=$(active_slot) i pt sp pad st col
        echo ""
        echo -e "  ${BW}Сейчас активен:${RS} ${GR}Профиль №$a${RS}"
        echo ""
        for i in 1 2 3 4 5; do
            if [ "$i" = "$a" ]; then
                col="${GY}(${GR}$i${GY})${RS} ${WT}Выбран профиль №$i${RS}"
                pt="Выбран профиль №$i"
                st="${GR}[ АКТИВЕН ]${RS}"; stt="[ АКТИВЕН ]"
            elif is_filled "$CONF/warp_${i}.yaml"; then
                col="${GY}(${BW}$i${GY})${RS} ${WT}Выбрать профиль №$i${RS}"
                pt="Выбрать профиль №$i"
                st="${GR}[ ГОТОВ ]${RS}"; stt="[ ГОТОВ ]"
            else
                col="${GY}(${BW}$i${GY})${RS} ${WT}Выбрать профиль №$i${RS}"
                pt="Выбрать профиль №$i"
                st="${RD}[ ПУСТ ]${RS}"; stt="[ ПУСТ ]"
            fi
            pad=$(( 46 - 6 - $(charlen "$pt") - $(charlen "$stt") )); [ "$pad" -lt 1 ] && pad=1
            sp=$(printf '%*s' "$pad" '')
            echo -e "  ${col}${sp}${st}  ${GY}|${RS}  ${GY}(${YL}$i$i${GY})${RS} ${YL}Изменить${RS} / ${RD}Удалить${RS}"
        done
        echo ""
        echo -e "  ${GY}(${BW}0${GY})${RS} ${WT}Назад${RS} ${GY}(или Enter)${RS}"
        echo -e "                              ${GY}(${RD}C${GY})${RS} ${RD}Удалить ключи для всех профилей${RS}"
        echo ""
        local c; c=$(get_act)
        case "$c" in
            1) SwitchProfile 1 ;;
            2) SwitchProfile 2 ;;
            3) SwitchProfile 3 ;;
            4) SwitchProfile 4 ;;
            5) SwitchProfile 5 ;;
            11) InputKeysSlot "$SLOT1" "Профиль №1" 1 && restart_q ;;
            22) InputKeysSlot "$SLOT2" "Профиль №2" 2 && restart_q ;;
            33) InputKeysSlot "$SLOT3" "Профиль №3" 3 && restart_q ;;
            44) InputKeysSlot "$SLOT4" "Профиль №4" 4 && restart_q ;;
            55) InputKeysSlot "$SLOT5" "Профиль №5" 5 && restart_q ;;
            c|C) ClearAll ;;
            0|"") return ;;
            *) echo -e "  ${RD}[ОШИБКА] Неверный ввод — повторите${RS}"; sleep 1 ;;
        esac
    done
}


function ToggleMode {
    local m new
    m=$(grep "^mode:" "$CFGS" 2>/dev/null | awk '{print $2}')
    if [ "$m" = "global" ]; then new="rule"; else new="global"; fi
    sed -i "s/^mode: .*/mode: $new/" "$CFGS"
    restart_q
    if [ "$new" = "global" ]; then
        echo -e "  ${GR}[Готово] Режим изменен: Глобальный — весь трафик через VPN${RS}"
    else
        echo -e "  ${GR}[Готово] Режим изменен: Обход по списку сайтов${RS}"
    fi
    sleep 2
}

function ToggleService {
    if svc_on; then
        systemctl stop mihomo
        echo -e "  ${YL}[Готово] Туннель остановлен${RS}"
    else
        systemctl start mihomo
        echo -e "  ${GR}[Готово] Туннель запущен${RS}"
    fi
    sleep 2
}

function ToggleAutostart {
    if auto_on; then
        systemctl disable mihomo > /dev/null 2>&1
        echo -e "  ${YL}[Готово] Автозапуск отключен${RS}"
    else
        systemctl enable mihomo > /dev/null 2>&1
        echo -e "  ${GR}[Готово] Автозапуск включен${RS}"
    fi
    sleep 2
}

function ToggleSSH {
    if [ -f "$INFORMER" ]; then
        rm -f "$INFORMER"
        echo -e "  ${YL}[Готово] Информер SSH удален${RS}"
    else
        install_informer
        echo -e "  ${GR}[Готово] Информер SSH установлен${RS}"
    fi
    sleep 2
}
function SettingsMenu {
    while true; do
        clear
        FrameTitle " НАСТРОЙКИ СЛУЖБЫ "
        echo ""
        local st_txt st_col au_txt au_col ssh_txt ssh_col
        if svc_on; then st_txt="Работает"; st_col=$GR; else st_txt="Остановлен"; st_col=$YL; fi
        if auto_on; then au_txt="Включен"; au_col=$GR; else au_txt="Выключен"; au_col=$YL; fi
        if [ -f "$INFORMER" ]; then ssh_txt="Включена"; ssh_col=$GR; else ssh_txt="Выключена"; ssh_col=$YL; fi
        menu_item 1 "Туннель службы (Сам обход через VPN)" "${st_col}[ ${st_txt} ]${RS}"
        menu_item 2 "Автозапуск Mihomo при загрузке" "${au_col}[ ${au_txt} ]${RS}"
        menu_item 3 "Состояние Mihomo при входе по SSH" "${ssh_col}[ ${ssh_txt} ]${RS}"
        echo ""
        echo -e "  ${GY}Нажмите номер — состояние переключится сразу.${RS}"
        echo ""
        echo -e "  ${GY}(${BW}0${GY})${RS} ${WT}Назад${RS} ${GY}(или Enter)${RS}"
        echo ""
        local c; c=$(get_act)
        case "$c" in
            1) ToggleService ;;
            2) ToggleAutostart ;;
            3) ToggleSSH ;;
            0|"") return ;;
            *) echo -e "  ${RD}[ОШИБКА] Неверный ввод — повторите${RS}"; sleep 1 ;;
        esac
    done
}

function LogsScreen {
    clear
    FrameTitle " ЖИВЫЕ ЛОГИ ЯДРА MIHOMO "
    echo ""
    echo -e "  ${DM}Выход из просмотра: Ctrl + C${RS}"
    echo ""
    journalctl -u mihomo.service -f --no-pager
    pause
}

function ApplyUtilUpdate {
    local sha="$1" tmp nc _r
    nc=$(date +%s)
    tmp=$(mktemp)
    env -i curl -sL -H "Cache-Control: no-cache" --connect-timeout 15 -o "$tmp" "${REPO_UTIL}?nc=${nc}" 2>/dev/null
    if [ -s "$tmp" ] && bash -n "$tmp" 2>/dev/null; then
        cp -f "$tmp" "$UTIL_FILE.new"
        mv -f "$UTIL_FILE.new" "$UTIL_FILE"
        chmod 755 "$UTIL_FILE" 2>/dev/null
        if [ -n "$sha" ]; then printf '%s\n' "$sha" > "$CONF/.util_commit"; fi
        echo -e "        ${GR}[Готово] Панель обновлена${RS}"
        rm -f "$tmp"
        echo ""
        echo -n "Нажмите Enter — панель запустится заново... "
        read _r
        kill "$WD_PID" 2>/dev/null
        exec "$UTIL_FILE"
    else
        echo -e "        ${RD}[ОШИБКА] Файл на GitHub поврежден — обновление отменено${RS}"
    fi
    rm -f "$tmp"
}


function RunUpdateCore {
    clear
    FrameTitle " ПРОВЕРКА ОБНОВЛЕНИЙ С GITHUB "
    echo ""
    echo -en "  ${DM}# #${RS} Проверка обновлений утилиты mihomoutil на GitHub... "
    local nc=$(date +%s)
    local util_sha=$(env -i curl -s -H "Cache-Control: no-cache" --connect-timeout 10 "${REPO_API}&nc=${nc}" 2>/dev/null | grep '"sha"' | head -n1 | cut -d'"' -f4)
    local util_mark=$(cat "$CONF/.util_commit" 2>/dev/null)
    if [ -n "$util_sha" ]; then
        echo -e "${GR}[Готово]${RS}"
        if [ -n "$util_mark" ] && [ "$util_sha" = "$util_mark" ]; then
            echo -e "        ${DM}Обновлений не обнаружено — у вас последняя версия${RS}"
        elif [ -n "$util_mark" ]; then
            echo -e "        ${YL}Доступна новая версия панели — устанавливаю...${RS}"
            ApplyUtilUpdate "$util_sha"
        else
            local tmp0
            tmp0=$(mktemp)
            env -i curl -sL -H "Cache-Control: no-cache" --connect-timeout 15 -o "$tmp0" "${REPO_UTIL}?nc=${nc}" 2>/dev/null
            if [ -s "$tmp0" ] && bash -n "$tmp0" 2>/dev/null && diff -q "$tmp0" "$UTIL_FILE" > /dev/null 2>&1; then
                printf '%s\n' "$util_sha" > "$CONF/.util_commit"
                rm -f "$tmp0"
                echo -e "        ${DM}Обновлений не обнаружено — у вас последняя версия${RS}"
            elif [ -s "$tmp0" ] && bash -n "$tmp0" 2>/dev/null; then
                rm -f "$tmp0"
                local yn
                echo ""
                echo -e "        ${YL}На GitHub найден другой файл панели.${RS}"
                echo -n "        Установить версию с GitHub? (y/n): "
                read yn; yn=$(RU2EN "$yn")
                if [ "$yn" = "y" ]; then
                    echo -e "        ${YL}Устанавливаю...${RS}"
                    ApplyUtilUpdate "$util_sha"
                else
                    echo -e "        ${DM}Отменено — сначала залейте свою версию в репозиторий${RS}"
                fi
            else
                rm -f "$tmp0"
                echo -e "        ${RD}[ОШИБКА] Файл на GitHub поврежден — обновление отменено${RS}"
            fi
        fi
    else
        echo -e "${YL}[API недоступен]${RS}"
        echo -e "        ${DM}Резервная проверка по содержимому файла...${RS}"
        local tmp1
        tmp1=$(mktemp)
        env -i curl -sL -H "Cache-Control: no-cache" --connect-timeout 15 -o "$tmp1" "${REPO_UTIL}?nc=${nc}" 2>/dev/null
        if [ -z "$(cat "$tmp1" 2>/dev/null)" ]; then
            echo -e "        ${RD}GitHub недоступен — проверьте интернет и повторите позже${RS}"
        elif bash -n "$tmp1" 2>/dev/null && diff -q "$tmp1" "$UTIL_FILE" > /dev/null 2>&1; then
            echo -e "        ${DM}Обновлений не обнаружено — у вас последняя версия${RS}"
        elif bash -n "$tmp1" 2>/dev/null; then
            echo -e "        ${YL}Доступна новая версия панели — устанавливаю...${RS}"
            ApplyUtilUpdate ""
        else
            echo -e "        ${RD}[ОШИБКА] Файл на GitHub поврежден — обновление отменено${RS}"
        fi
        rm -f "$tmp1"
    fi
    echo ""
    echo -en "  ${DM}# #${RS} Проверка установщика Mihomo-setup.sh на GitHub... "
    local setup_remote=$(env -i curl -s -H "Cache-Control: no-cache" --connect-timeout 10 "${SETUP_API}&nc=${nc}" 2>/dev/null | grep '"sha"' | head -n1 | cut -d'"' -f4)
    local setup_local=$(cat "$SETUP_MARK" 2>/dev/null)
    if [ -z "$setup_remote" ]; then
        echo -e "${YL}[Нет связи]${RS}"
    elif [ -z "$setup_local" ]; then
        echo -e "${YL}[Нет метки]${RS}"
        echo -e "        ${YL}Метка версии установщика не найдена. Один раз переустановите:${RS}"
        echo -e "        ${YL}cd ~/Mihomo-Install-Script && git pull && sudo bash Mihomo-setup.sh${RS}"
    elif [ "$setup_remote" = "$setup_local" ]; then
        echo -e "${GR}[Готово]${RS}"
        echo -e "        ${DM}Обновлений не обнаружено — у вас последняя версия${RS}"
    else
        echo -e "${YL}[Есть обновление]${RS}"
        echo -e "        ${YL}Установщик обновился на GitHub. Для обновления выполните:${RS}"
        echo -e "        ${YL}cd ~/Mihomo-Install-Script && git pull && sudo bash Mihomo-setup.sh${RS}"
    fi
    echo ""
    pause
}

GEO_CACHE=/tmp/mihomo_geo_ru.txt

# --- Внешний IP с кэшем на 10 минут, чтобы перерисовка меню не тормозила ---
function get_geo_line {
    local line
    if [ -f "$GEO_CACHE" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$GEO_CACHE" 2>/dev/null || echo 0) ))
        if [ "$age" -lt 600 ]; then
            line=$(cat "$GEO_CACHE" 2>/dev/null)
            if [ -n "$line" ]; then printf '%s' "$line"; return; fi
        fi
    fi
    local resp ip country isp
    resp=$(curl -4 -s --connect-timeout 3 --max-time 6 "http://ip-api.com/json/?fields=query,country,isp&lang=ru")
    ip=$(printf '%s' "$resp" | grep -o '"query":"[^"]*"' | cut -d'"' -f4)
    country=$(printf '%s' "$resp" | grep -o '"country":"[^"]*"' | cut -d'"' -f4)
    isp=$(printf '%s' "$resp" | grep -o '"isp":"[^"]*"' | cut -d'"' -f4)
    if [ -n "$ip" ]; then
        line=$(printf '%s\t%s, %s' "$ip" "$country" "$isp")
        printf '%s' "$line" > "$GEO_CACHE" 2>/dev/null
    else
        line=$(printf '%s\t-' "Не определено")
    fi
    printf '%s' "$line"
}

function menu_item {
    local n="$1" t="$2" s="$3"
    if [ -z "$s" ]; then
        echo -e "  ${GY}(${BW}${n}${GY})${RS} ${WT}${t}${RS}"
        return
    fi
    local pad=$(( 57 - 7 - $(charlen "$t") )); [ "$pad" -lt 1 ] && pad=1
    local sp=$(printf '%*s' "$pad" '')
    echo -e "  ${GY}(${BW}${n}${GY})${RS} ${WT}${t}${RS}${sp}${s}"
}

function Menu {
    clear
    FrameTitle " ПАНЕЛЬ УПРАВЛЕНИЯ И АВТОМАТИЗАЦИИ MIHOMOUTIL "
    echo ""
    local mode_str=$(grep "^mode:" "$CFGS" 2>/dev/null | awk '{print $2}')
    local prof=$(active_slot)
    local err_count=$(cat "$ERR_COUNT_FILE" 2>/dev/null || echo "0")
    local last_err=$(cat "$LAST_ERR_FILE" 2>/dev/null || echo "Ошибок нет")
    local n_dom=$(domains_list | grep -c .)
    local geo=$(get_geo_line)
    local geo_ip geo_info
    geo_ip=$(printf '%s' "$geo" | cut -f1)
    geo_info=$(printf '%s' "$geo" | cut -f2)
    local ssh_txt ssh_col
    if [ -f "$INFORMER" ]; then ssh_txt="Вкл"; ssh_col=$GR; else ssh_txt="Выкл"; ssh_col=$YL; fi

    local st_txt st_col au_txt au_col mode_txt mode_col
    if svc_on; then st_txt="Запущен"; st_col=$GR; else st_txt="Остановлен"; st_col=$RD; fi
    if auto_on; then au_txt="Вкл"; au_col=$GR; else au_txt="Выкл"; au_col=$YL; fi
    if [ "$mode_str" = "global" ]; then
        mode_txt="Глобальный режим"; mode_col=$YL
    else
        mode_txt="По списку сайтов"; mode_col=$CY
    fi

    local div fill
    div=$(printf '%.0s─' $(seq 1 78))
    echo -e " ${GY}${div}${RS}"
    echo -e "  ${WT}Статус Mihomo: ${st_col}${st_txt}${RS} ${GY}|${RS} ${WT}Автозапуск: ${au_col}${au_txt}${RS} ${GY}|${RS} ${WT}Инфо-строка по SSH: ${ssh_col}${ssh_txt}${RS}"
    echo -e " ${GY}${div}${RS}"
    echo ""
    if [ "$geo_info" = "-" ]; then
        echo -e "  ${WT}Внешний IP: ${YL}Не определено${RS}"
    else
        echo -e "  ${BW}Внешний IP: ${YL}${geo_ip}${RS} ${GY}(${geo_info})${RS}"
    fi
    if [ "$err_count" -gt 0 ]; then
        echo -e "  ${BW}Шлюз связи: ${RD}НЕДОСТУПЕН${RS} ${GY}(сбоев: ${err_count}, последний: ${last_err})${RS}"
        echo -e "              ${YL}Для повторной проверки нажмите клавишу T${RS}"
    else
        echo -e "  ${BW}Шлюз связи: ${GR}ДОСТУПЕН${RS} ${GY}(сбоев: 0)${RS}"
    fi
    echo ""

    # Секции: плашка ■ на белом фоне + подчёркивание до 79-й колонки
    local sec1=" ■ МАРШРУТИЗАЦИЯ И ОБХОД БЛОКИРОВОК "
    local sec2=" ■ УПРАВЛЕНИЕ ТРАФИКОМ И СИСТЕМОЙ "
    fill=$(printf '%*s' $(( 79 - 2 - $(charlen "$sec1") )) '' | tr ' ' '_')
    echo -e "  ${HDR}${sec1}${RS}${BW}${fill}${RS}"

    # Пункты: значения прижаты к 57-й колонке, как в образце
    local pad
    local d1="Список сайтов в обходе"
    local v1
    if [ "$n_dom" -gt 0 ]; then v1="[ ${CY}Доменов: ${n_dom}${RS} ${WT}]"; else v1="[ ${RD}список пуст${RS} ${WT}]"; fi
    pad=$(( 57 - 7 - $(charlen "$d1") )); [ "$pad" -lt 1 ] && pad=1
    echo -e "  ${GY}(${BW}1${GY})${RS} ${WT}${d1}${RS}$(printf '%*s' "$pad" '')${WT}${v1}${RS}"
    echo -e "  ${GY}(${BW}2${GY})${RS} ${WT}Добавить один домен${RS}"
    echo -e "  ${GY}(${BW}3${GY})${RS} ${WT}Добавить домены списком${RS}"
    echo -e "  ${GY}(${BW}4${GY})${RS} ${WT}Удалить домены${RS}"
    echo ""
    fill=$(printf '%*s' $(( 79 - 2 - $(charlen "$sec2") )) '' | tr ' ' '_')
    echo -e "  ${HDR}${sec2}${RS}${BW}${fill}${RS}"
    local d5="Профили с конфигурациями WARP"
    pad=$(( 57 - 7 - $(charlen "$d5") )); [ "$pad" -lt 1 ] && pad=1
    echo -e "  ${GY}(${BW}5${GY})${RS} ${WT}${d5}${RS}$(printf '%*s' "$pad" '')${WT}[ ${CY}Выбран: №${prof}${RS} ${WT}]${RS}"
    local d6="Режим обхода"
    pad=$(( 57 - 7 - $(charlen "$d6") )); [ "$pad" -lt 1 ] && pad=1
    echo -e "  ${GY}(${BW}6${GY})${RS} ${WT}${d6}${RS}$(printf '%*s' "$pad" '')${WT}[ ${mode_col}${mode_txt}${RS} ${WT}]${RS}"
    echo -e "  ${GY}(${BW}7${GY})${RS} ${WT}Настройки (туннель, автозапуск, SSH-информер)${RS}"
    echo ""
    echo -e " ${GY}${div}${RS}"
    echo -e " ${GY}[${BW}E${GY}]${WT},${GY}[${BW}Enter${GY}]${WT}-${RD}Выход${RS}      ${GY}[${BW}T${GY}]${WT}-${GR}Тест сети${RS}   ${GY}[${BW}L${GY}]${WT}-Логи   ${GY}[${BW}U${GY}]${WT}-Обновление   ${GY}[${BW}H${GY}]${WT}-Справка${RS}"
    echo -e " ${GY}${div}${RS}"
    echo ""
}


if [ "$#" -gt 0 ]; then
    case "$1" in
        -h|--help) ShowHelp; exit 0 ;;
        --list)
            if [ -f "$RULES" ]; then
                domains_list
                [ -z "$(domains_list)" ] && echo "Список пуст."
            else echo "Список пуст."; fi
            exit 0 ;;
        --add)
            if [ -z "$2" ]; then echo "Укажите домен!"; exit 1; fi
            new_d=$(echo "$2" | tr -d ' ')
            if [ ! -f "$RULES" ]; then echo "payload:" > "$RULES"; fi
            if domains_list | grep -qx "$new_d"; then echo "Уже есть в списке."; exit 0; fi
            sed -i "/^payload:/a\\  - 'DOMAIN-SUFFIX,$new_d'" "$RULES"
            restart_q
            echo "Домен $new_d добавлен и применен."
            exit 0 ;;
        --remove)
            if [ -z "$2" ]; then echo "Укажите домен!"; exit 1; fi
            new_d=$(echo "$2" | tr -d ' ')
            if ! grep -qF "DOMAIN-SUFFIX,$new_d'" "$RULES"; then echo "Домена нет в списке."; exit 0; fi
            for _ln in $(grep -nF "DOMAIN-SUFFIX,$new_d'" "$RULES" | cut -d: -f1 | sort -rn); do sed -i "${_ln}d" "$RULES"; done
            restart_q
            echo "Домен $new_d удален и применен."
            exit 0 ;;
        --bulk) BulkEditMenu; exit 0 ;;
        --check) FullCheckMenu; exit 0 ;;
        --mode-selective)
            sed -i 's/^mode: .*/mode: rule/' "$CFGS"
            restart_q
            echo "Шлюз переведен в режим обхода по списку сайтов."
            exit 0 ;;
        --mode-global)
            sed -i 's/^mode: .*/mode: global/' "$CFGS"
            restart_q
            echo "Шлюз переведен в глобальный режим (Все через VPN)."
            exit 0 ;;
        --config-num1) SwitchProfile 1; exit 0 ;;
        --config-num2) SwitchProfile 2; exit 0 ;;
        --config-num3) SwitchProfile 3; exit 0 ;;
        --config-num4) SwitchProfile 4; exit 0 ;;
        --config-num5) SwitchProfile 5; exit 0 ;;
        --keys-1) InputKeysSlot "$SLOT1" "Профиль №1" 1 && restart_q; exit 0 ;;
        --keys-2) InputKeysSlot "$SLOT2" "Профиль №2" 2 && restart_q; exit 0 ;;
        --keys-3) InputKeysSlot "$SLOT3" "Профиль №3" 3 && restart_q; exit 0 ;;
        --keys-4) InputKeysSlot "$SLOT4" "Профиль №4" 4 && restart_q; exit 0 ;;
        --keys-5) InputKeysSlot "$SLOT5" "Профиль №5" 5 && restart_q; exit 0 ;;
        --start) systemctl start mihomo && echo "Служба запущена."; exit 0 ;;
        --stop) systemctl stop mihomo && echo "Служба остановлена."; exit 0 ;;
        --enable) systemctl enable mihomo > /dev/null 2>&1 && echo "Автозапуск включен."; exit 0 ;;
        --disable) systemctl disable mihomo > /dev/null 2>&1 && echo "Автозапуск отключен."; exit 0 ;;
        --ssh-enable) install_informer; echo "Информер SSH приветствия успешно внедрен."; exit 0 ;;
        --ssh-disable) rm -f "$INFORMER"; echo "Информер SSH приветствия полностью удален."; exit 0 ;;
        --update) RunUpdateCore; exit 0 ;;
        --logs) journalctl -u mihomo.service -f --no-pager; exit 0 ;;
        *) ShowHelp; exit 0 ;;
    esac
fi

BackgroundWatchdog & WD_PID=$!
trap 'kill "$WD_PID" 2>/dev/null' EXIT INT TERM

while true; do
    Menu
    c=$(get_act)
    case "$c" in
        1) ViewSites ;;
        2) AddSiteMenu ;;
        3) BulkEditMenu ;;
        4) RemoveSiteMenu ;;
        5) ProfilesMenu ;;
        6) ToggleMode ;;
        7) SettingsMenu ;;
        t|T) FullCheckMenu ;;
        h|H) HelpScreen ;;
        u|U) RunUpdateCore ;;
        l|L) LogsScreen ;;
        e|E|"") clear; exit 0 ;;
        *) echo -e "  ${RD}[ОШИБКА] Неверный ввод — повторите${RS}"; sleep 1 ;;
    esac
done
# === END_OF_UTIL ===
