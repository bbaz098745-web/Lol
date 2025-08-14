#!/bin/bash

PROCESS_NAME="code"
MAX_MEM_MB=1536 # 1.5 جيجا

start_boost() {
    echo -n "تشغيل تحسين الأداء لـ VS Code؟ (Y/n): "
    read choice
    if [[ "$choice" != "Y" && "$choice" != "y" ]]; then
        echo "إلغاء العملية."
        exit 0
    fi

    PID=$(pgrep -x "$PROCESS_NAME")
    if [ -z "$PID" ]; then
        echo "VS Code غير شغال!"
        exit 1
    fi

    echo "إعطاء أولوية قصوى لـ VS Code..."
    renice -n -20 -p $PID >/dev/null

    # مراقبة استهلاك الرام مرة واحدة
    MEM_USAGE=$(pmap $PID | tail -n 1 | awk '/[0-9]K/{print $2}' | sed 's/K//')
    if [ "$MEM_USAGE" -gt $((MAX_MEM_MB * 1024)) ]; then
        echo "تحذير: VS Code تجاوز 1.5GB من الرام! إيقاف مؤقت..."
        kill -STOP $PID
        sleep 2
        kill -CONT $PID
    fi

    # خفض أولوية العمليات الأخرى الثقيلة مؤقتًا
    echo "خفض أولوية العمليات الأخرى..."
    for other_pid in $(ps -eo pid,comm --sort=-%cpu | awk '$2 != "'$PROCESS_NAME'" {print $1}' | head -n 20); do
        renice -n 10 -p $other_pid >/dev/null
    done

    echo "تم تحسين الأداء لـ VS Code."
}

stop_boost() {
    echo "إرجاع الأولويات للوضع الطبيعي..."
    for p in $(ps -eo pid --no-headers); do
        renice -n 0 -p $p >/dev/null 2>&1
    done
    echo "تمت إعادة الوضع الطبيعي."
}

if [[ "$1" == "off" ]]; then
    stop_boost
else
    start_boost
fi