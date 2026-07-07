# Gimbal Pro 2 60 FPS patch

Репозиторий: [Quake1011/GimbalPro2_60fps_patch](https://github.com/Quake1011/GimbalPro2_60fps_patch)

Простой локальный патч для приложения **Gimbal Pro** / `com.jxrobot.android.smoothcam`.

Цель: пересобрать приложение на вашем компьютере так, чтобы основной режим записи видео использовал **60 fps** вместо **30 fps**.

## Главное

Этот репозиторий **не содержит приложение** и **не распространяет APK**.

Здесь лежат только скрипты, которые:

1. берут оригинальное приложение с вашего телефона;
2. применяют маленький патч `30 fps -> 60 fps`;
3. собирают APK обратно;
4. устанавливают его обратно на телефон.

## Для кого это

Подойдет, если вы:

- хотите попробовать 60 fps в Gimbal Pro;
- готовы подключить телефон к компьютеру по USB;
- можете один раз запустить PowerShell-команду;
- понимаете, что это неофициальная модификация.

Если вы разработчик, скрипты можно читать и менять вручную. Если вы не разработчик, просто следуйте инструкции ниже.

## Что меняется

Патч трогает только основной путь записи видео:

- основной encoder записи;
- обычный `MediaRecorder`;
- Camera1 preview fps range;
- подписи в интерфейсе, где было `30fps`.

Патч специально **не трогает**:

- редактор фото;
- редактор видео;
- экспорт/обрезку видео;
- таймлапс;
- slow motion;
- bitrate;
- ресурсы приложения.

Это сделано, чтобы снизить риск поломки функций, которые не относятся к обычной записи видео.

## Что нужно установить

Нужен Windows-компьютер и 4 инструмента:

1. **ADB**  
   Нужен, чтобы вытащить приложение с телефона и установить измененную версию обратно.

2. **Java**  
   Нужна для запуска `apktool` и signer.

3. **apktool**  
   Нужен, чтобы разобрать и собрать APK.

4. **uber-apk-signer**  
   Нужен, чтобы подписать APK после сборки.

Эти инструменты не входят в репозиторий. Их нужно скачать отдельно из официальных источников.

## Где скачать инструменты

Скачивайте инструменты только с официальных страниц или GitHub-репозиториев проектов.

| Инструмент | Где скачать | Что выбрать |
| --- | --- | --- |
| ADB / Android Platform Tools | [developer.android.com/tools/releases/platform-tools](https://developer.android.com/tools/releases/platform-tools) | ZIP для Windows. Внутри будет `adb.exe`. |
| Java | [adoptium.net/temurin/releases](https://adoptium.net/temurin/releases) | Windows x64, JDK 17 или новее. |
| Java, альтернативный вариант | [oracle.com/java/technologies/downloads](https://www.oracle.com/java/technologies/downloads/) | Oracle JDK для Windows, если не хотите ставить Temurin. |
| apktool | [apktool.org/docs/install](https://apktool.org/docs/install/) | Инструкция по установке. Для Windows обычно нужен `apktool.jar` и wrapper `apktool.bat`. |
| apktool releases | [github.com/iBotPeaches/Apktool/releases](https://github.com/iBotPeaches/Apktool/releases) | Последний стабильный `.jar`. |
| uber-apk-signer | [github.com/patrickfav/uber-apk-signer/releases](https://github.com/patrickfav/uber-apk-signer/releases) | Последний `uber-apk-signer-*.jar` / `signer-*.jar`. |

После установки проверьте, что команды работают:

```powershell
adb version
java -version
```

Для `apktool` путь можно не добавлять в `PATH`, потому что он передается в скрипт явно через `-Apktool`.

## Подготовка телефона

1. Установите оригинальное приложение Gimbal Pro на телефон.
2. Включите режим разработчика на телефоне.
3. Включите **USB debugging** / **Отладка по USB**.
4. Подключите телефон к компьютеру.
5. На телефоне подтвердите доверие к компьютеру, если появится запрос.

На Xiaomi/HyperOS может понадобиться включить еще:

- **Install via USB** / **Установка через USB**;
- **USB debugging (Security settings)**, если такой пункт есть.

## Быстрый запуск

Откройте PowerShell в папке репозитория.

Пример:

```powershell
git clone https://github.com/Quake1011/GimbalPro2_60fps_patch.git
cd GimbalPro2_60fps_patch
```

Запустите сборку:

```powershell
.\scripts\build-from-phone.ps1 `
  -Apktool "C:\apktool\apktool.bat" `
  -SignerJar "C:\tools\uber-apk-signer.jar"
```

Замените пути на свои:

- `C:\apktool\apktool.bat` - путь к вашему apktool;
- `C:\tools\uber-apk-signer.jar` - путь к вашему signer jar.

После успешной сборки готовые файлы будут здесь:

```text
work\signed\
```

Папка `work` добавлена в `.gitignore`. Ее не нужно заливать на GitHub.

## Сборка и установка одной командой

Чтобы сразу установить результат на телефон:

```powershell
.\scripts\build-from-phone.ps1 `
  -Apktool "C:\apktool\apktool.bat" `
  -SignerJar "C:\tools\uber-apk-signer.jar" `
  -Install
```

Если Android напишет, что подписи не совпадают, это нормально. Оригинальное приложение подписано ключом разработчика, а локальная сборка подписывается вашим ключом.

В таком случае нужна чистая установка:

```powershell
.\scripts\build-from-phone.ps1 `
  -Apktool "C:\apktool\apktool.bat" `
  -SignerJar "C:\tools\uber-apk-signer.jar" `
  -Install `
  -ForceUninstall
```

Важно: `-ForceUninstall` удалит установленное приложение и его данные перед установкой измененной версии.

## Частые ошибки

### `adb not found`

ADB не установлен или не добавлен в `PATH`.

Проверьте:

```powershell
adb devices
```

Если команда не работает, установите Android Platform Tools и добавьте папку с `adb.exe` в `PATH`.

### Телефон не виден

Проверьте:

```powershell
adb devices
```

Если устройство в статусе `unauthorized`, разблокируйте телефон и подтвердите запрос отладки по USB.

### `INSTALL_FAILED_UPDATE_INCOMPATIBLE`

На телефоне стоит оригинальное приложение с другой подписью.

Решение: запустить команду с `-ForceUninstall`.

### `INSTALL_FAILED_USER_RESTRICTED`

Телефон блокирует установку через USB.

Обычно помогает:

- разблокировать телефон;
- подтвердить установку на экране;
- включить **Install via USB** в настройках разработчика;
- на Xiaomi/HyperOS временно отключить ограничения безопасности для USB-установки.

### После установки приложение просит разрешения заново

Это нормально после чистой установки. Android считает измененную сборку новым установленным приложением.

## Что можно заливать на GitHub

Можно:

- `README.md`;
- `LICENSE`;
- `THIRD_PARTY_NOTICES.md`;
- `docs/`;
- `scripts/`;
- `.gitignore`.

Нельзя заливать без отдельного разрешения правообладателя:

- оригинальные APK;
- измененные APK;
- split APK;
- папку `work/`;
- декомпилированные smali-файлы приложения;
- ресурсы приложения;
- signer jar;
- ключи подписи.

Перед публикацией проверьте:

```powershell
git status --ignored
```

В Git должны попасть только файлы из этого репозитория, а не локальные сборки.

## Лицензия

MIT-лицензия относится только к скриптам и документации в этом репозитории.

Она не относится к приложению Gimbal Pro, его APK, ресурсам, коду, названию или другим файлам правообладателя.

## Источники и документация

- Android Platform Tools / ADB: [developer.android.com/tools/releases/platform-tools](https://developer.android.com/tools/releases/platform-tools)
- Документация ADB: [developer.android.com/tools/adb](https://developer.android.com/tools/adb)
- USB debugging на Android: [developer.android.com/studio/debug/dev-options](https://developer.android.com/studio/debug/dev-options)
- Запуск и настройка реального Android-устройства: [developer.android.com/studio/run/device](https://developer.android.com/studio/run/device)
- Android app signing: [developer.android.com/studio/publish/app-signing](https://developer.android.com/studio/publish/app-signing)
- Apktool install guide: [apktool.org/docs/install](https://apktool.org/docs/install/)
- Apktool releases: [github.com/iBotPeaches/Apktool/releases](https://github.com/iBotPeaches/Apktool/releases)
- uber-apk-signer releases: [github.com/patrickfav/uber-apk-signer/releases](https://github.com/patrickfav/uber-apk-signer/releases)
- Eclipse Temurin Java builds: [adoptium.net/temurin/releases](https://adoptium.net/temurin/releases)
- Oracle Java downloads: [oracle.com/java/technologies/downloads](https://www.oracle.com/java/technologies/downloads/)

## Дисклеймер

Это неофициальный патч. Используйте его на свой риск.

Репозиторий не связан с разработчиками Gimbal Pro и не содержит их файлов. Чтобы распространять готовый измененный APK, нужно отдельное право от владельца приложения.
