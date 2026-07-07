# Gimbal Pro 60 FPS patch

Скрипты для локального применения минимального патча `30 fps -> 60 fps` к установленному APK `com.jxrobot.android.smoothcam`.

## Что делает патч

Патч ограничен основным путем записи видео:

- меняет fps в `TextureMovieEncoder`;
- заставляет обычный `MediaRecorder` использовать `60`;
- выставляет `Camera1` preview fps range `60000/60000` перед стартом записи;
- меняет только видимые UI-подписи `30fps` на `60fps`.

Патч намеренно не трогает video/photo editor, `VideoClipper`, `GLVideoEncoder`, `TimeLapseEncoder`, `MediaVideoEncoder`, bitrate и ресурсы приложения.

## Требования

- Windows PowerShell;
- `adb` в `PATH`;
- Java;
- `apktool`;
- `uber-apk-signer` или другой локальный signer, совместимый с командой в скрипте;
- телефон с установленным оригинальным приложением и включенной USB-отладкой.

Сторонние инструменты не включены в репозиторий. Скачивайте их отдельно из официальных источников.

## Локальная сборка

Из корня репозитория:

```powershell
.\scripts\build-from-phone.ps1 `
  -Apktool "C:\apktool\apktool.bat" `
  -SignerJar "C:\path\to\uber-apk-signer.jar"
```

Скрипт:

1. вытянет установленный APK/split APK с телефона;
2. декомпилирует только `base.apk` через `apktool -r`;
3. применит минимальный smali-патч;
4. пересоберет `base.apk`;
5. переподпишет весь комплект APK одним локальным ключом.

Результат будет в `work\signed\`.

## Установка на телефон

```powershell
.\scripts\build-from-phone.ps1 `
  -Apktool "C:\apktool\apktool.bat" `
  -SignerJar "C:\path\to\uber-apk-signer.jar" `
  -Install
```

Если на телефоне стоит оригинальная версия с другой подписью, Android не позволит обновить ее поверх. Для чистой установки:

```powershell
.\scripts\build-from-phone.ps1 `
  -Apktool "C:\apktool\apktool.bat" `
  -SignerJar "C:\path\to\uber-apk-signer.jar" `
  -Install `
  -ForceUninstall
```

`-ForceUninstall` удалит данные приложения `com.jxrobot.android.smoothcam` перед установкой, если обновление поверх не пройдет из-за подписи.
