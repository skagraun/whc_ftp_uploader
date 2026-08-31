@echo off
:: Leallit egy adott nevu scheduled task-ot (egy peldanyt).
:: Szandekosan NEM hasznal "taskkill /im node.exe"-t, mert az az
:: adott gepen futo OSSZES node folyamatot kilone - beleertve egy
:: masik telephely/BG peldanyat is, ha ugyanazon a szerveren futna.
:: Hasznalat: stop.bat [TaskNev]
set TASK_NAME=%~1
if "%TASK_NAME%"=="" set TASK_NAME=WHC-FTP-Uploader

schtasks /end /tn "%TASK_NAME%"
echo "%TASK_NAME%" leallitva (ha futott).
pause
