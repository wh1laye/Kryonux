#!/bin/busybox sh
/bin/busybox --install -s /bin
export PATH=/bin
mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev 2>/dev/null
mount -t securityfs securityfs /sys/kernel/security 2>/dev/null
echo "KRYONK-START"
echo "KRYONK-UNAME: $(uname -r)"
echo "KRYONK-PROC: $(cat /proc/kryonk 2>/dev/null | tr '\n' ' ')"
echo "KRYONK-BORE: $(cat /proc/sys/kernel/sched_bore 2>/dev/null || echo none)"
echo "KRYONK-LOCKDOWN: $(cat /sys/kernel/security/lockdown 2>/dev/null || echo none)"
echo "KRYONK-LSM: $(cat /sys/kernel/security/lsm 2>/dev/null || echo none)"
echo "KRYONK-DONE"
sync
poweroff -f
echo o > /proc/sysrq-trigger
sleep 30
