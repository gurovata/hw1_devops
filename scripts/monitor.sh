#!/usr/bin/env bash

if [ "$#" -ne 1 ]; then
    echo "Использование: $0 имя_сервиса"
    exit 1
fi

service=$1

if ! load_state=$(systemctl show "$service" --property=LoadState --value 2>/dev/null); then
    echo "Не удалось проверить сервис. Скрипт нужен для Linux с systemd."
    exit 1
fi

if [ "$load_state" = "not-found" ] || [ -z "$load_state" ]; then
    echo "Сервис $service не найден."
    exit 1
fi

if systemctl is-active --quiet "$service"; then
    echo "Сервис $service работает."
else
    echo "Сервис $service неактивен. Последние 10 записей:"
    if ! journalctl -u "$service" -n 10 --no-pager; then
        echo "Не удалось прочитать журнал сервиса."
    fi
fi

if [ ! -r /var/log/syslog ]; then
    echo "Файл /var/log/syslog отсутствует или недоступен для чтения."
    exit 1
fi

read -r now year < <(date '+%s %Y')
from=$((now - 3600))

error_count=$(grep -i 'error' /var/log/syslog | awk -v now="$now" -v from="$from" -v year="$year" '
BEGIN {
    split("Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec", names, " ")
    for (i = 1; i <= 12; i++) {
        months[names[i]] = i
    }
}
{
    if (substr($1, 5, 1) == "-" && substr($1, 11, 1) == "T") {
        split(substr($1, 1, 19), parts, /[-T:]/)
        stamp = parts[1] " " parts[2] " " parts[3] " " parts[4] " " parts[5] " " parts[6]
        if ($1 ~ /Z$/ || $1 ~ /[+-][0-9][0-9]:[0-9][0-9]$/) {
            timestamp = mktime(stamp, 1)
            if ($1 !~ /Z$/) {
                zone = substr($1, length($1) - 5)
                offset = substr(zone, 2, 2) * 3600 + substr(zone, 5, 2) * 60
                if (substr(zone, 1, 1) == "+") {
                    timestamp -= offset
                } else {
                    timestamp += offset
                }
            }
        } else {
            timestamp = mktime(stamp)
        }
    } else if ($1 in months) {
        split($3, clock, ":")
        stamp = months[$1] " " $2 " " clock[1] " " clock[2] " " clock[3]
        timestamp = mktime(year " " stamp)
        if (timestamp > now) {
            timestamp = mktime((year - 1) " " stamp)
        }
    } else {
        next
    }

    if (timestamp >= from && timestamp <= now) {
        count++
    }
}
END { print count + 0 }
')

echo "Количество строк с error в /var/log/syslog за последний час: $error_count"

