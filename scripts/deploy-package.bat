@echo off
:: ============================================================
:: WHC FTP Uploader - csomagolo script
:: Lebuildeli az appot (Next.js "standalone" modban) es osszerak
:: egy onmagaban futtathato mappat (deploy-package), amihez a
:: celszerveren NEM kell "npm install"-t futtatni - csak node.exe
:: kell hozza. Ezt a mappat kell kimasolni minden telephelyre/BG-hez.
:: Ezt a scriptet a FEJLESZTOI gepen futtasd, ahol npm elerheto.
:: ============================================================

setlocal

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set OUTPUT_DIR=%PROJECT_DIR%\deploy-package

echo ===========================================
echo   WHC FTP Uploader - Deploy Packager
echo ===========================================
echo.

echo [1/5] Next.js build (standalone)...
cd /d "%PROJECT_DIR%"
call npm run build
if %errorlevel% neq 0 (
    echo HIBA: a build sikertelen volt!
    pause
    exit /b 1
)

echo [2/5] Csomag mappa elokeszitese...
if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%"

echo [3/5] Standalone build masolasa...
xcopy /E /I /Q "%PROJECT_DIR%\.next\standalone\*" "%OUTPUT_DIR%\" >nul

:: A standalone build alapbol nem tartalmazza a statikus (.next/static)
:: es a public/ eszkozoket, ezeket kulon kell bemasolni.
mkdir "%OUTPUT_DIR%\.next\static" 2>nul
xcopy /E /I /Q "%PROJECT_DIR%\.next\static\*" "%OUTPUT_DIR%\.next\static\" >nul

if exist "%PROJECT_DIR%\public" (
    xcopy /E /I /Q "%PROJECT_DIR%\public\*" "%OUTPUT_DIR%\public\" >nul
)

echo [4/5] Sajat szerver + extra futasideju csomagok bemasolasa...
:: Felulirjuk a Next.js altal a standalone buildbe generalt, onmagaban
:: semmit nem tudo server.js-t a mi sajat szerverunkkel (lasd server.js).
copy /y "%PROJECT_DIR%\server.js" "%OUTPUT_DIR%\server.js" >nul

mkdir "%OUTPUT_DIR%\src\server" 2>nul
copy /y "%PROJECT_DIR%\src\server\env.js" "%OUTPUT_DIR%\src\server\" >nul
copy /y "%PROJECT_DIR%\src\server\uploader.js" "%OUTPUT_DIR%\src\server\" >nul

:: Ezeket a csomagokat csak a mi sajat server.js / env.js /
:: uploader.js kodunk hasznalja. A Next.js "standalone" tracing csak
:: a pages/API route-okbol tenylegesen elert importokat koveti, ezert
:: ezek automatikusan NEM kerulnek be a standalone node_modules-ba -
:: emiatt itt kezzel masoljuk be oket. Ha a package.json dependencies
:: listaja bovul (next/react/react-dom-on kivul barmi massal), ezt a
:: listat is boviteni kell!
mkdir "%OUTPUT_DIR%\node_modules" 2>nul
for %%P in (basic-ftp dotenv nodemailer) do (
    if exist "%PROJECT_DIR%\node_modules\%%P" (
        if exist "%OUTPUT_DIR%\node_modules\%%P" rmdir /s /q "%OUTPUT_DIR%\node_modules\%%P"
        xcopy /E /I /Q "%PROJECT_DIR%\node_modules\%%P" "%OUTPUT_DIR%\node_modules\%%P\" >nul
    ) else (
        echo FIGYELEM: node_modules\%%P nem talalhato - a csomagbol hianyozni fog ez a fuggoseg!
    )
)

echo [5/5] .env sablon es szerver-kezelo scriptek masolasa...
copy /y "%PROJECT_DIR%\.env.example" "%OUTPUT_DIR%\.env.example" >nul
copy /y "%SCRIPT_DIR%server\*.bat" "%OUTPUT_DIR%\" >nul 2>nul
copy /y "%SCRIPT_DIR%server\*.ps1" "%OUTPUT_DIR%\" >nul 2>nul

echo.
echo ===========================================
echo   Kesz! A csomag itt talalhato: %OUTPUT_DIR%
echo ===========================================
echo.
echo Kovetkezo lepesek:
echo   1. Masold ki a 'deploy-package' mappat a szerverre
echo   2. Hozz letre egy .env fajlt a server.js melle (.env.example alapjan),
echo      es toltsd ki a WATCH_DIR / FTP_* / PORT ertekeket erre a telephelyre/BG-re
echo   3. Elso telepites: install-service.bat futtatasa Adminisztratorkent
echo      Frissites:       update-app.bat ^<uj-deploy-package-mappa-utvonala^>
echo.
pause
