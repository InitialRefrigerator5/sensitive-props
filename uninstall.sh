#!/system/bin/busybox sh

MODPATH="${0%/*}"

# Find install-recovery.sh and set permissions back to default
find /vendor/bin /system/bin -name install-recovery.sh -exec chmod 0755 {} \;

# Revert permissions for other files/directories
chmod 644 /proc/cmdline
chmod 644 /proc/net/unix
chmod 755 /system/addon.d
chmod 755 /sdcard/TWRP

BACKUP_BOOT="$MODPATH/original-boot.img"

if [ -f "$BACKUP_BOOT" ]; then
  echo "- Найден оригинальный boot.img: $BACKUP_BOOT"
  echo "- Начинается восстановление..."
  
  # Прошиваем оригинальный boot.img обратно
  magiskboot flash "$BACKUP_BOOT"
  
  if [ $? -eq 0 ]; then
    echo " "
    echo "-> Оригинальный boot.img успешно восстановлен."
    echo " "
  else
    echo " "
    echo "! ОШИБКА: Не удалось прошить оригинальный boot.img!"
    echo "! Возможно, вам потребуется восстановить его вручную!"
    echo " "
  fi
else
  echo " "
  echo "! ВНИМАНИЕ: Резервная копия original-boot.img не найдена!"
  echo "! Невозможно автоматически восстановить boot.img."
  echo "! Убедитесь, что вы прошили стоковый boot.img вручную."
  echo " "
fi

echo "-----------------------------------------------------------"
