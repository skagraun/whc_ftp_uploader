@echo off
:: ============================================================
:: WHC FTP Uploader telepitese Windows Scheduled Task-kent
:: (rendszerinditaskor automatikusan elindul es folyamatosan fut -
:: EZ NEM egy oranta ismetlodo trigger! Az orankenti feltoltest az
:: alkalmazas maga utemezi belsoleg, a node-cron csomaggal. Ne adj
:: hozza kulon oranta triggert a Task Scheduler-ben!)
::
:: Rendszergazdakent (Administrator) futtasd!
::
:: Elofeltetelek:
::   - Node.js telepitve a szerveren (csak a node.exe kell hozza,
::     npm install NEM szukseges - a deploy-package onmagaban futtathato)
::   - Az app deploy-package-e mar ki van csomagolva a vegleges mappajaba
::   - Van egy .env fajl (a .env.example alapjan) ebben a mappaban,
::     kitoltve ennek a peldanynak/telephelynek/BG-nek megfelelo
::     WATCH_DIR / FTP_* / PORT ertekekkel
:: ============================================================

echo ===========================================
echo   WHC FTP Uploader - Telepito
echo ===========================================
echo.

:: Adminisztratori jogosultsag ellenorzese
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo HIBA: Futtasd Adminisztratorkent!
    pause
    exit /b 1
)

set APP_DIR=%~dp0

where node.exe >nul 2>&1
if %errorlevel% neq 0 (
    echo HIBA: node.exe nem talalhato a PATH-ban!
    pause
    exit /b 1
)

if not exist "%APP_DIR%_run.bat" (
    echo HIBA: _run.bat nem talalhato itt: %APP_DIR%
    pause
    exit /b 1
)

if not exist "%APP_DIR%.env" (
    echo FIGYELEM: nincs .env fajl itt: %APP_DIR%
    echo Masold at a .env.example -t .env nevre es toltsd ki, mielott elinditod a szolgaltatast.
    echo.
)

:: A task nevet azert kerdezzuk, mert igy tobb fuggetlen peldany is
:: futhat egymas mellett (pl. kulonbozo telephelyek/BG-k kulon
:: szervereken) - mindegyiknek sajat mappaja, sajat .env-je, sajat
:: portja es sajat task neve van, nem zavarjak egymast.
set /p TASK_NAME="Task neve (Enter = WHC-FTP-Uploader): "
if "%TASK_NAME%"=="" set TASK_NAME=WHC-FTP-Uploader

echo A Task Scheduler ezzel a felhasznaloi fiokkal fogja futtatni a folyamatot.
echo Ird be a felhasznalonevet (pl. AD\szolgaltatas.user):
set /p RUN_USER="> "
echo.

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

echo [1/1] "%TASK_NAME%" task letrehozasa...
schtasks /create /tn "%TASK_NAME%" /tr "cmd /c \"%APP_DIR%_run.bat\"" /sc onstart /ru %RUN_USER% /rp * /rl HIGHEST /f
if %errorlevel% neq 0 (
    echo HIBA: Nem sikerult letrehozni a taskot!
    pause
    exit /b 1
)

echo.
echo ===========================================
echo   Telepites kesz!
echo ===========================================
echo.
echo Inditas:   schtasks /run /tn "%TASK_NAME%"
echo Leallitas: stop.bat "%TASK_NAME%"
echo.
pause
