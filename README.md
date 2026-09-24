# ZefirkaVoice — голосовой пульт для Зефирки

Android-приложение на Flutter для управления устройством **Зефирка** (OSSM на ESP32) голосом.

Работает **офлайн**, распознаёт **русскую речь** через **Vosk**, отправляет команды на устройство по **WebSocket**.

---

## Что умеет

- 🎤 **Офлайн-распознавание речи** — русский язык, без интернета
- 🗣 **Wake word** — «малышка» активирует режим команд
- 📝 **Команды из JSON** — редактируются прямо в приложении
- 📡 **WebSocket** — отправка на OSSM
- 🎨 **Мятный дизайн** — в едином стиле с плеером
- 📴 **Работает без интернета** — модель Vosk скачивается один раз

---

## Архитектура

```

┌─────────────────┐    WebSocket    ┌──────────────────┐
│  ZefirkaVoice   │ ──────────────> │  Зефирка (OSSM)  │
│  (Android)      │   JSON-команды  │  (ESP32)         │
│  + Vosk         │                 │                  │
└─────────────────┘                 └──────────────────┘

```

**Компоненты:**

- **Flutter** — приложение
- **Vosk** — офлайн-распознавание речи
- **WebSocket** — связь с OSSM
- **GitHub Actions** — сборка APK в облаке

---

## Файлы проекта

| Файл | Что делает |
|---|---|
| `lib/main.dart` | Экран, Vosk, WebSocket, обработка команд |
| `lib/vosk_service.dart` | Распознавание речи, wake word |
| `lib/websocket_service.dart` | Отправка JSON на OSSM |
| `lib/commands_service.dart` | Чтение/запись `commands.json` |
| `lib/commands_editor_screen.dart` | Редактор команд (внутри приложения) |
| `lib/download_service.dart` | Скачивание модели Vosk |
| `assets/commands.json` | Дефолтные команды |
| `assets/girl.png` | Картинка ночного режима |
| `icon.png` | Иконка приложения |
| `.github/workflows/build.yml` | GitHub Actions — сборка APK |

---

## Протокол WebSocket

**Формат:** JSON-массив команд для прошивки OSSM.

**Пример:**
```json
[
  { "action": "setPattern", "pattern": 0 },
  { "action": "startPattern" }
]
```

Команды, которые понимает прошивка:

Action Параметры Что делает
startStreaming — Запустить стриминг (funscript)
stop — Остановить всё
move position, time, replace Позиция в стриминге
setPattern pattern (0-8) Выбрать паттерн
startPattern — Запустить паттерн
setSpeed speed (0-100) Скорость
setDepth depth (0-100) Глубина
setStroke stroke (0-100) Амплитуда
setSensation value (-100..100) Режим
home — Калибровка
disable — Отключить драйвер
get_status — Запрос статуса
version — Запрос версии

НЕ доступны через WebSocket (только кнопки на устройстве):

· Stealth ↔ Spread — кнопка MENU
· Wi-Fi STA ↔ AP — кнопка NEXT
· Экстренный стоп — кнопка ENTER

---

Паттерны StrokeEngine

Номер Название
0 Simple
1 Teasing
2 Robo
3 Half'n'Half
4 Deeper
5 Stop'n'Go
6 Insist
7 Jack Hammer
8 Stroke Nibbler

---

Зависимости

```yaml
dependencies:
  flutter: sdk
  permission_handler: ^12.0.3
  web_socket_channel: ^3.0.0
  path_provider: ^2.1.1
  vosk_flutter_fixed: ^0.1.4
  http: ^1.2.0
  archive: ^4.3.0

dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

---

Сборка

Автоматическая — через GitHub Actions при каждом коммите в main.

Вручную — Actions → Build APK → Run workflow.

Готовый APK — в артефактах сборки.

---

Установка и использование

1. Скачай APK из артефактов GitHub Actions.
2. Установи на Android-устройство (разреши установку из неизвестных источников).
3. При первом запуске — приложение скачает модель Vosk (~50 МБ).
4. Дай разрешение на микрофон.
5. Тап по экрану → картинка яркая → слушаю.
6. Скажи: «малышка старт» → команда отправлена на OSSM.
7. Тап ещё раз → картинка тусклая → стоп.

---

Настройка команд

Кнопка «команды» (сверху справа) → открывается редактор.

Формат commands.json:

```json
{
  "url": "ws://192.168.1.105:81",
  "wake_words": ["малышка", "малыш"],
  "commands": [
    {
      "phrases": ["старт", "пуск", "начни"],
      "json": "[{\"action\":\"startStreaming\"}]"
    }
  ]
}
```

Поля:

· url — адрес WebSocket OSSM
· wake_words — слова активации
· phrases — фразы, на которые реагирует команда
· json — что отправить на OSSM

Сохранил в редакторе → работает сразу. Без пересборки APK.

---

Известные решения

Проблемы, которые пришлось решить при разработке:

· compileSdk 37 для основного модуля — из-за permission_handler 12
· vosk_flutter_fixed — требует compileSdk 36 (патчится в build.yml)
· R8/Proguard — исключения для JNA и Vosk
· AndroidManifest — разрешения INTERNET, RECORD_AUDIO
· Vosk перезапуск — reinit() после сворачивания приложения и после стопа
· Чтение команд — из папки приложения (не из Download), без MANAGE_EXTERNAL_STORAGE
· Иконка — flutter_launcher_icons с adaptive (inset 25)

---

Что можно добавить

В планах:

· 🎨 UI: убрать/переместить элементы на экране
· 🎤 Улучшение распознавания — добавить варианты фраз
· 🔧 Расширение прошивки: setAcceleration, setDriverMode, setInvert
· 📖 README для всей экосистемы (прошивка + плеер + инструменты)
· 🌙 Тёмная тема / ночной режим в приложении
· 📊 Индикация состояния OSSM (READY / PATTERN / STREAM)

---

Связанные проекты

· Прошивка Зефирка — OSSM на ESP32 (не опубликована)
· Плеер Зефирка — HTML-плеер для видео и скриптов
· Инструменты — конвертер, редактор, конструктор, аудио-конструктор

---

Лицензия

Личный проект. Использование на свой риск.

```
