@echo off
:: ============================================================
:: WHC FTP Uploader - Frissito script
:: Leallitja a webszerver taskjat, ratolti az uj buildet a meglevo
:: telepitesre (a .env es a logok erintetlenul maradnak), majd
:: ujrainditja. A "<TaskNev>-Trigger" (orankenti inditasi) taskot
:: nem kell kulon leallitani/ujrainditani - az csak idonkent fut le
:: roviden, es a kovetkezo futasakor magatol a friss fajlokat hasznalja.
::
:: Rendszergazdakent (Administrator), a MAR TELEPITETT app mappajabol
:: futtasd (ahol korabban az install-service.bat is futott).
::
:: Hasznalat: update-app.bat <uj-deploy-package-mappa> [TaskNev]
:: Pelda:     update-app.bat C:\temp\deploy-package
::            update-app.bat C:\temp\deploy-package WHC-FTP-Uploader-BG2
:: ============================================================

if "%~1"=="" (
    echo Hasznalat: update-app.bat ^<deploy-package-mappa^> [TaskNev]
    echo Pelda: update-app.bat C:\temp\deploy-package
    pause
    exit /b 1
)

set SOURCE=%~1
set APP_DIR=%~dp0
set TASK_NAME=%~2
if "%TASK_NAME%"=="" set TASK_NAME=WHC-FTP-Uploader

echo ===========================================
echo   WHC FTP Uploader - Frissites
echo ===========================================
echo Forras: %SOURCE%
echo Cel:    %APP_DIR%
echo Task:   %TASK_NAME%
echo.

if not exist "%SOURCE%\server.js" (
    echo HIBA: server.js nem talalhato itt: %SOURCE%
    echo Bizonyosodj meg, hogy a deploy-package mappara mutatsz.
    pause
    exit /b 1
)

echo [1/3] Task leallitasa...
schtasks /end /tn "%TASK_NAME%" >nul 2>&1
timeout /t 3 /nobreak >nul

echo [2/3] Uj fajlok masolasa (a .env es a LOG mappa erintetlen marad)...
robocopy "%SOURCE%" "%APP_DIR%" /E /XD LOG uploaded /XF .env /NFL /NDL /NJH /NJS /NC /NS

echo [3/3] Ujrainditas...
schtasks /run /tn "%TASK_NAME%"

timeout /t 3 /nobreak >nul

echo.
echo ===========================================
echo   Frissites kesz!
echo ===========================================
pause
