@echo off
:: ============================================================
:: Ezt hivja a Windows Task Scheduler oranta (kulon "Trigger" task,
:: lasd install-service.bat) - ez a tenyleges FTP feltoltes inditoja.
:: Nem magat a feltoltest vegzi, csak meghivja a mar futo webszerver
:: /api/run-upload vegpontjat, ugyanugy, mint a felulet "Futtatas
:: most" gombja. Ha a webszerver (masik, "onstart" task) epp nem fut,
:: ez a hivas hibat fog adni - a webszerver task allapotat erdemes
:: kulon monitorozni.
::
:: FIGYELEM: a RUN_UPLOAD_TOKEN erteke ne tartalmazzon idezojelet
:: vagy egyeb batch-specialis karaktert (%%, ^, &, |, stb.).
:: ============================================================

setlocal enabledelayedexpansion
cd /d "%~dp0"

set PORT=3000
set RUN_UPLOAD_TOKEN=

if exist ".env" (
    for /f "usebackq eol=# tokens=1,* delims==" %%A in (".env") do (
        if "%%A"=="PORT" set "PORT=%%B"
        if "%%A"=="RUN_UPLOAD_TOKEN" set "RUN_UPLOAD_TOKEN=%%B"
    )
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "try { $r = Invoke-RestMethod -Method Post -Uri 'http://localhost:%PORT%/api/run-upload' -Headers @{ 'x-run-token' = '%RUN_UPLOAD_TOKEN%' } -TimeoutSec 300; Write-Output ($r | ConvertTo-Json -Compress) } catch { Write-Error $_; exit 1 }"

exit /b %errorlevel%
