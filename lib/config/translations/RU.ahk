#Requires AutoHotkey v2.0

TM_Lang_RU() {
    return Map(
        ; --- MAIN UI BUTTONS ---
        "Set Launch Path", "Указать путь",
        "Profiles", "Профили",
        "Delete Game", "Удалить игру",
        "Emulators", "Эмуляторы",
        "Clear Path", "Очистить путь",
        "Restore Path", "Вернуть",
        "Window Manager", "Окна",
        "Focus", "Фокус",
        "Music", "Музыка",
        "Video", "Видео",
        "Gallery", "Галерея",
        "Database", "База данных",
        "Notes", "Заметки",
        "Browser", "Проводник",
        "Rec Audio", "Зап. аудио",
        "Rec Video", "Зап. видео",
        "Icon Manager", "Иконки",
        "Idle", "Простой",
        "Normal", "Нормальный",
        "High", "Высокий",
        "Realtime", "Реал-тайм",
        "Clone Wizard", "Мастер клона",
        "Patch Manager", "Менеджер патчей",
        "Purge Logs", "Очистить логи",
        "Purge List", "Очистить список",
        "View Logs", "Показать логи",
        "Show Games Config", "Конфиг игр",
        "View System Config", "Конфиг системы",
      "Sound Manager", "Менеджер звука",
      "Emulator Audio Config", "Настройки аудио эмулятора",
      "Hardware Output Mapping", "Сопоставление аппаратных выходов",
      "Route Game Audio (Strip 3)", "Маршрут аудио игры (Дорожка 3)",
      "Capture Backend", "Бэкенд захвата",
      "Backend:", "Бэкенд:",
      "Save", "Сохранить",
      "Refresh Device List ↻", "Обновить список устройств ↻",
      "Clear", "Очистить",
      "Mute", "Без звука",
      "Hard Reset (Relaunch VoiceMeeter App)", "Жёсткий сброс (перезапуск VoiceMeeter)",
      "Out A1", "Выход A1",
      "Out A2", "Выход A2",
      "Out A3", "Выход A3",
      "Install Loopback Helper", "Установить loopback helper",
      "Test Loopback 3s", "Проверить loopback 3 с",
      "Help", "Справка",
      "Check for Updates", "Проверить обновления",
      "Choose an option", "Выберите действие",
      "Status:", "Статус:",
      "Ready", "Готово",
      "Saved backend:", "Бэкенд сохранён:",
      "Capture backend saved:", "Бэкенд захвата сохранён:",
      "Loopback helper installed", "Loopback helper установлен",
      "Loopback install failed", "Не удалось установить loopback helper",
      "Install Error", "Ошибка установки",
      "Could not install loopback helper.", "Не удалось установить loopback helper.",
      "FFmpeg missing", "FFmpeg отсутствует",
      "Capture Test", "Тест захвата",
      "FFmpeg missing:", "FFmpeg отсутствует:",
      "Loopback helper missing", "Loopback helper отсутствует",
      "Loopback helper is missing and could not be installed.", "Loopback helper отсутствует и не может быть установлен.",
      "Running 3s loopback test...", "Выполняется тест loopback 3 с...",
      "Loopback test saved:", "Тест loopback сохранён:",
      "Loopback test capture saved", "Запись теста loopback сохранена",
      "Loopback test failed", "Тест loopback не удался",
      "Loopback test failed. No valid output file was generated.", "Тест loopback не удался. Валидный файл вывода не был создан.",
      "Update check finished", "Проверка обновлений завершена",
      "Update Check", "Проверка обновлений",
      "Update Decision", "Выбор обновления",
         "Apply All Updates", "Применить все обновления",
      "Install Helper", "Установить helper",
      "Download FFmpeg", "Скачать FFmpeg",
      "Download Nexus", "Скачать Nexus",
      "Skip", "Пропустить",
         "Helper local", "Локальный helper",
         "FFmpeg local", "Локальный FFmpeg",
         "Nexus local", "Локальный Nexus",
         "Latest", "Последняя",
         "Stable", "Стабильная",
         "Nightly", "Ночная",
         "Selected release", "Выбранный релиз",
         "None", "Нет",
        "Hide Advanced", "Скрыть",
        "Show Advanced Utilities", "Показать расширенные утилиты",
      "Patch", "Патч игры",
      "Wizard", "Мастер",
      "Build PS5 Linux Image", "Собрать образ PS5 Linux",
      "Open Balena Etcher", "Открыть Balena Etcher",
      "Open Build Guide", "Открыть инструкцию по сборке",
      "Build PS5 Linux image subtitle", "Соберите образ PS5 Linux в WSL, затем запишите .img через Balena Etcher.",

        ; --- ADVANCED UTILITIES ---
        "AT3 Convert", "Конв. AT3",
        "Pad Test", "Тест геймпада",
        "Hash Calc / Validator", "Хэш проверка",
        "Wipe List", "Очистить список",
        "Wipe Full List", "Очистить всё",

        ; --- GALLERY ---
        "Previous", "Назад", "Next", "Вперёд", "Slideshow", "Слайд-шоу", "Browse", "Обзор", "Delete", "Удалить",
        "Image", "Изображение", "Path", "Путь", "Size", "Размер",
        "GALLERY_HELP_1", "Нажмите Пробел, чтобы запустить слайд-шоу в полноэкранном режиме.",
        "GALLERY_HELP_2", "Дважды щёлкните по изображению для полноэкранного режима.",
        "GALLERY_HELP_3", "В полноэкранном режиме нажмите M для смены монитора.",
        "GALLERY_HELP_4", "Нажмите DELETE, чтобы удалить изображение в корзину.",

        "HELP_TEXT_SOUND_MANAGER", "
        (
1. РЕЖИМ АУДИО:
   - Auto сначала использует loopback helper.
   - Loopback захватывает текущее Windows-устройство воспроизведения.
   - DShow использует настроенное прямое устройство ввода.
   - Voicemeeter сохраняет старый сценарий маршрутизации.

2. НАСТРОЙКИ ЗВУКА WINDOWS:
   - Установите выход по умолчанию на колонки или наушники, которые хотите слышать.
   - Оставьте микрофон входом для голосовых команд.
   - Если воспроизведение идёт через не-умолчательное устройство, переключитесь на DShow или Voicemeeter.

3. LOOPBACK HELPER:
   - Нажмите Установить loopback helper, если встроенный helper отсутствует.
   - Нажмите Проверить loopback 3 с, чтобы убедиться, что системный звук захватывается.

4. ОБНОВЛЕНИЯ:
   - Используйте кнопку проверки, чтобы сравнить helper, FFmpeg и Nexus.

5. LEGACY ROUTING:
   - Voicemeeter остаётся доступным для тех, кому нужен ручной bus routing.
        )",

      "HELP_TEXT_PS5_LINUX_IMAGE", "
      (
Чтобы собрать свой образ в Windows, сначала выполните это в PowerShell от имени администратора для установки WSL:

   wsl --install

Установите Ubuntu. Сначала проверьте доступные дистрибутивы:

   wsl --list --online

Затем установите:

   wsl --install Ubuntu-26.04

Установите Docker:

   sudo apt update
   sudo apt install docker.io -y
   sudo service docker start
   sudo usermod -aG docker $USER

Далее клонируйте репозиторий и соберите образ:

   cd ~/
   git clone https://github.com/ps5-linux/ps5-linux-image
   cd ps5-linux-image
   chmod +x ./build_image.sh
   sudo bash ./build_image.sh --distro ubuntu2604

Готовый образ будет записан в:

   output/ps5-ubuntu2604.img

Запишите образ на USB:

- Минимальный размер накопителя: 64 ГБ. Внешний SSD настоятельно рекомендуется.
- Скачайте Balena Etcher (https://etcher.balena.io/), выберите файл .img,
  выберите USB-накопитель и нажмите Flash.
- Игнорируйте сообщение о форматировании.
      )",

            "HELP_TEXT_GAMEPAD", "
            (
         ОБЪЯСНЕНИЕ ОСЕЙ (Эмуляция Xbox 360)

         X и Y: Левый стик
         • X: Горизонталь (0=Влево, 50=Центр, 100=Вправо)
         • Y: Вертикаль (0=Вверх, 50=Центр, 100=Вниз)

         R: Правый стик (вертикаль)
         • В покое = 50, затем двигается к 0 или 100.

         Z: Триггеры L2 / R2
         • Оба триггера используют одну общую ось.
         • 50 = Ничего не нажато (или нажаты одинаково)
         • 100 = Левый триггер (L2) нажат полностью
         • 0 = Правый триггер (R2) нажат полностью

         POV: D-Pad (POV Hat)
         • Показывает угол в градусах x 100.
         • -1 = Ничего не нажато
         • 0 = Вверх
         • 9000 = Вправо
         • 18000 = Вниз
         • 27000 = Влево
            )",

        ; --- HELP TEXT ---
        "HELP_TEXT_MAIN", "
        (
1. ДОБАВЛЕНИЕ ИГР:
   - Нажмите 'Указать путь запуска', чтобы добавить основной исполняемый файл игры.
   - Для TeknoParrot выберите профиль в разделе 'Профили'.

2. ЭМУЛЯТОРЫ:
   - Нажмите 'Эмуляторы', чтобы настроить пути.

3. ЗАПУСК ИГР:
   - При выборе .ISO/EBOOT.BIN программа спросит, какой эмулятор использовать.
   - Либо выберите игру из списка и нажмите ▶️.

4. КОГДА ИГРА АКТИВНА:
   - Используйте 'Окна' для управления окном игры.
   - Используйте кнопки CPU для устранения лагов/фризов.
   - Burst делает быстрые скриншоты (макс. 99).

5. ЗАПИСЬ:
   - Записывайте только аудио или видео со звуком.

6. ИНСТРУМЕНТЫ:
   - Конвертер Atrac3: Конвертирует звук ATRAC3 в WAV.
   - Валидатор файлов: Проверяет MD5/SHA1 хэши ISO.
   - База поиска игр.

7. ГОРЯЧИЕ КЛАВИШИ:
   - Escape: Выход из игры.
  - Escape+1: Жёсткий перезапуск.
  - Control+L: Открыть журнал в реальном времени.
   - F8: Включает каталог голосовых команд.
   - F9: В режиме захвата показывает терминал ffmpeg.
   - F10: Показывает логи ffmpeg.
   - CTRL+SHIFT+A: Открывает менеджер аудио.

8. БЫСТРЫЙ ЗАПУСК:
   - Щёлкните правой кнопкой по иконке в трее для быстрого запуска.
   - Двойной щелчок по заголовку переключает в текстовый режим.

9. МАГНИТНЫЕ ОКНА:
   - Удерживайте Control на главном UI, чтобы отсоединить его.

T. УСТРАНЕНИЕ НЕПОЛАДОК:
   - Чтобы перезапустить игру, используйте 'Перезапуск игры'.
   - Используйте 'Показать логи' для поиска ошибок.
        )"
    )
}
