@echo off
:: ============================================================
:: Ezt hivja a Windows Task Scheduler oranta (kulon "Trigger" task,
:: lasd install-service.bat) - ez a tenyleges FTP feltoltes inditoja.
:: Nem magat a feltoltest vegzi, csak meghivja a mar futo webszerver
:: /api/run-upload vegpontjat, ugyanugy, mint a felulet "Futtatas
:: most" gombja.
::
:: A tenyleges logika a _trigger-upload.ps1-ben van: ha a webszerver
:: nem erheto el (nem fut, rossz port/token), az a hibat a
:: LOG\trigger.log-ba irja ES e-mailt kuld rola - korabban ilyenkor
:: a feltoltes napokig csendben nem futott le.
::
:: Ezt a .bat-ot megtartjuk (nem a .ps1-et hivja kozvetlenul a task),
:: hogy a mar telepitett taskokat ne kelljen ujra letrehozni.
:: ============================================================

cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0_trigger-upload.ps1"
exit /b %errorlevel%
