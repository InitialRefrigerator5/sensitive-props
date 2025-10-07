#!/bin/sh
PATH=/data/adb/ap/bin:/data/adb/ksu/bin:/data/adb/magisk:$PATH

if [ "$API" -lt 29 ]; then
  abort "! Only support Android 10+ devices"
fi

if [ "$BOOTMODE" != true ]; then
  ui_print "-----------------------------------------------------------"
  ui_print " "
  ui_print "! Пожалуйста, устанавливайте этот модуль через Magisk Manager."
  ui_print " "
  abort "-----------------------------------------------------------"
fi

ui_print " "
ui_print "**********************************************"
ui_print "*      Патчер boot.img для oem.rc     *"
ui_print "**********************************************"
ui_print " "

ui_print "- Creating boot.img backup..."
ui_print "- Saving in $MODPATH/original-boot.img"
ui_print "Boot image path: $BOOTIMAGE"

if [ -f "$MODPATH/original-boot.img" ]; then
  ui_print "- An old backup was found. Delete it."
  rm -f "$MODPATH/original-boot.img"
fi

cp "$BOOTIMAGE" "$MODPATH/original-boot.img"
if [ $? -ne 0 ]; then
  abort "! ERROR: Failed to create boot.img backup!"
fi

# 2. Подготовка
PATCH_DIR=$TMPDIR/patch
mkdir -p "$PATCH_DIR"

# Распаковываем наш rc-файл из модуля
unzip -o "$ZIPFILE" 'oem.rc' -d "$MODPATH" >&2

# 3. Распаковка boot.img
ui_print "- Распаковка текущего boot.img..."
magiskboot unpack "$BOOTIMAGE" "$PATCH_DIR"
if [ $? -ne 0 ]; then
  # Если распаковка не удалась, восстанавливаем чистоту
  rm -rf "$PATCH_DIR"
  rm -f "$MODPATH/original-boot.img"
  abort "! ОШИБКА: Не удалось распаковать boot.img!"
fi

# 4. Внесение изменений в ramdisk
ui_print "- Добавление my_service.rc в ramdisk..."
RAMDISK_DIR=$PATCH_DIR/ramdisk
mkdir -p "$RAMDISK_DIR/overlay.d"
cp "$MODPATH/oem.rc" "$RAMDISK_DIR/overlay.d/"

# 5. Сборка нового boot.img
ui_print "- Сборка нового new-boot.img..."
magiskboot repack "$PATCH_DIR" "$MODPATH/new-boot.img"
if [ $? -ne 0 ]; then
  rm -rf "$PATCH_DIR"
  rm -f "$MODPATH/original-boot.img"
  abort "! ОШИБКА: Не удалось собрать new-boot.img!"
fi

# 6. Прошивка нового boot.img
ui_print "- Прошивка new-boot.img в текущий слот..."
magiskboot flash "$MODPATH/new-boot.img"
if [ $? -ne 0 ]; then
  ui_print "! ОШИБКА: Не удалось прошить new-boot.img!"
  ui_print "! Попробуем восстановить оригинальный boot.img..."
  magiskboot flash "$MODPATH/original-boot.img"
  abort "! Прошивка не удалась. Изменения отменены."
fi

# 7. Очистка временных файлов
ui_print "- Очистка..."
rm -rf "$PATCH_DIR"
rm -f "$MODPATH/new-boot.img"
rm -f "$MODPATH/oem.rc"


# Set Module permissions
set_perm_recursive "$MODPATH" 0 0 0755 0644

# Running the service early using busybox
[ -f "$MODPATH/service.sh" ] && sh "$MODPATH/service.sh" 2>&1

ui_print " "
ui_print "-> Патчинг успешно завершен!"
ui_print "-> Перезагрузите устройство для применения изменений."
ui_print "-> Please uninstall this module before dirty-flashing/updating the ROM."
