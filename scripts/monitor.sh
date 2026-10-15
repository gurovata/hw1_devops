#!/usr/bin/env bash
# Проверка сервиса и подсчёт ошибок в syslog за последний час.
# Пример: ./monitor.sh docker

if [ $# -ne 1 ]; then
    echo "Использование: $0 <имя_сервиса>"
    exit 1
fi

service=$1

if [ "$(systemctl show "$service" --property=LoadState --value)" != "loaded" ]; then
    echo "Сервис $service не найден"
    exit 1
fi

if systemctl is-active --quiet "$service"; then
    echo "Сервис $service работает"
else
    echo "Сервис $service не работает. Последние 10 строк лога:"
    journalctl -u "$service" -n 10 --no-pager
fi

if [ ! -r /var/log/syslog ]; then
    echo "Файл /var/log/syslog не найден или нет прав на чтение"
    exit 1
fi

# grep отбирает строки с error, awk переводит время строки в секунды и считает строки за последний час
since=$(date -d '1 hour ago' +%s)
errors=$(grep -i 'error' /var/log/syslog | awk -v since="$since" '
{
    if ($1 ~ /^[0-9]{4}-/) {
        # Ubuntu 24.04: 2026-10-15T16:07:43.545765+03:00
        t = substr($1, 1, 19)
        gsub(/[-T:]/, " ", t)
    } else {
        # Ubuntu 20.04/22.04: Oct 15 16:07:43
        month = (index("JanFebMarAprMayJunJulAugSepOctNovDec", $1) + 2) / 3
        split($3, hms, ":")
        t = strftime("%Y") " " month " " $2 " " hms[1] " " hms[2] " " hms[3]
    }
    if (mktime(t) >= since) count++
}
END { print count + 0 }')

echo "Ошибок в /var/log/syslog за последний час: $errors"
