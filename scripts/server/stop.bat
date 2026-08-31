@echo off
:: Leallitja egy peldany mindket taskjat:
::   - a webszerver taskot ("<TaskNev>") - ez fut, ezt le is allitjuk
::   - a feltoltes-inditasi taskot ("<TaskNev>-Trigger") - ez nem fut
::     folyamatosan (csak idonkent villan fel es fut le), ezert ezt
::     letiltjuk (disable), hogy ne probalkozzon egy leallitott
::     webszerver /api/run-upload vegpontjat hivni.
:: Ujrainditashoz: schtasks /run /tn "<TaskNev>" + schtasks /change
:: /tn "<TaskNev>-Trigger" /enable (vagy futtasd ujra az
:: install-service.bat-ot).
::
:: Szandekosan NEM hasznal "taskkill /im node.exe"-t, mert az az
:: adott gepen futo OSSZES node folyamatot kilone - beleertve egy
:: masik telephely/BG peldanyat is, ha ugyanazon a szerveren futna.
:: Hasznalat: stop.bat [TaskNev]
set TASK_NAME=%~1
if "%TASK_NAME%"=="" set TASK_NAME=WHC-FTP-Uploader

schtasks /end /tn "%TASK_NAME%"
schtasks /change /tn "%TASK_NAME%-Trigger" /disable >nul 2>&1

echo "%TASK_NAME%" leallitva, "%TASK_NAME%-Trigger" letiltva (ha leteztek).
pause
