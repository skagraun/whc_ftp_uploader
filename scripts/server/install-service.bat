@echo off
:: ============================================================
:: WHC FTP Uploader telepitese Windows Scheduled Task-kent
::
:: KET kulon task jon letre:
::   1) "<TaskNev>"         - a webszerver (health check + kezi
::                            "Futtatas most" gomb + a run-upload API
::                            maga). Rendszerinditaskor ("onstart")
::                            indul es folyamatosan fut.
::   2) "<TaskNev>-Trigger" - az orankenti (vagy tetszoleges
::                            intervallumu) FTP feltoltes tenyleges
::                            inditoja. Csak meghivja a mar futo
::                            webszerver /api/run-upload vegpontjat,
::                            majd kilep - nem fut folyamatosan.
::                            EZ adja az utemezest, NEM az alkalmazas
::                            maga (nincs beepitett cron tobbe).
::
:: Rendszergazdakent (Administrator) futtasd!
::
:: Elofeltetelek:
::   - Node.js telepitve a szerveren (csak a node.exe kell hozza,
::     npm install NEM szukseges - a deploy-package onmagaban futtathato)
::   - Az app deploy-package-e mar ki van csomagolva a vegleges mappajaba
::   - Van egy .env fajl (a .env.example alapjan) ebben a mappaban,
::     kitoltve ennek a peldanynak/telephelynek/BG-nek megfelelo
::     WATCH_DIR / FTP_* / PORT / RUN_UPLOAD_TOKEN ertekekkel
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

if not exist "%APP_DIR%_trigger-upload.bat" (
    echo HIBA: _trigger-upload.bat nem talalhato itt: %APP_DIR%
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
:: portja es sajat task nevei vannak, nem zavarjak egymast.
set /p TASK_NAME="Task nev alapja (Enter = WHC-FTP-Uploader): "
if "%TASK_NAME%"=="" set TASK_NAME=WHC-FTP-Uploader

set /p INTERVAL_MIN="Feltoltes gyakorisaga percben (Enter = 60): "
if "%INTERVAL_MIN%"=="" set INTERVAL_MIN=60

echo A Task Scheduler ezzel a felhasznaloi fiokkal fogja futtatni a folyamatokat.
echo Ird be a felhasznalonevet (pl. AD\szolgaltatas.user):
set /p RUN_USER="> "
echo.

schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
schtasks /delete /tn "%TASK_NAME%-Trigger" /f >nul 2>&1

echo [1/2] "%TASK_NAME%" (webszerver, rendszerinditaskor) letrehozasa...
schtasks /create /tn "%TASK_NAME%" /tr "cmd /c \"%APP_DIR%_run.bat\"" /sc onstart /ru %RUN_USER% /rp * /rl HIGHEST /f
if %errorlevel% neq 0 (
    echo HIBA: Nem sikerult letrehozni a webszerver taskot!
    pause
    exit /b 1
)

echo [2/2] "%TASK_NAME%-Trigger" (feltoltes inditasa %INTERVAL_MIN% percenkent) letrehozasa...
schtasks /create /tn "%TASK_NAME%-Trigger" /tr "cmd /c \"%APP_DIR%_trigger-upload.bat\"" /sc minute /mo %INTERVAL_MIN% /ru %RUN_USER% /rp * /rl HIGHEST /f
if %errorlevel% neq 0 (
    echo HIBA: Nem sikerult letrehozni a trigger taskot!
    pause
    exit /b 1
)

echo.
echo ===========================================
echo   Telepites kesz!
echo ===========================================
echo.
echo Webszerver inditasa most:  schtasks /run /tn "%TASK_NAME%"
echo Feltoltes inditasa kezzel: schtasks /run /tn "%TASK_NAME%-Trigger"
echo Leallitas:                 stop.bat "%TASK_NAME%"
echo.
pause
