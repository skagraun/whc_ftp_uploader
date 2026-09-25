@echo off
:: Ezt a wrapper scriptet hivja a Windows Scheduled Task.
:: A sajat mappajabol inditja el az appot, hogy a relativ utvonalak
:: (.env, src/server/*) helyesen feloldodjanak.
::
:: A konzol kimenetet (hibak, stack trace-ek is) egy log fajlba IS
:: kiirjuk - a Task Scheduler alapbol eldobja a kimenetet, igy ha a
:: folyamat elszallna indulaskor (pl. hianyzo .env mezo, portutkozes),
:: ne kelljen vakon nyomozni: nezd meg a LOG\server-console.log-ot.
:: Kezzel futtatva (dupla katt / cmd-bol) is latszik elo a kimenet.
::
:: AUTOMATIKUS UJRAINDITAS: ha a node folyamat barmilyen okbol kilep
:: (pl. egy el nem kapott hiba miatt elszall), 30 mp mulva ujrainditjuk.
:: Korabban ilyenkor a szerver napokig allt, amig valaki kezzel el nem
:: inditotta, es kozben egyetlen feltoltes sem futott le. (A Task
:: Scheduler sajat "ujrainditas hiba eseten" beallitasat ezen a gepen
:: nem tudtuk megbizhatoan beallitani, lasd fix-server-task-settings.ps1.)
:: A "schtasks /end" (stop.bat, update-app.bat) ezt a cmd.exe-t oli
:: meg, igy a ciklussal egyutt all le - nem inditja ujra a node-ot.
set NODE_ENV=production
cd /d "%~dp0"
if not exist "%~dp0LOG" mkdir "%~dp0LOG"

:loop
:: Az "ujrainditas" sort is Tee-Object-tel irjuk a logba (nem cmd-s
:: "echo >>"-vel): a Tee-Object UTF-16 kodolassal ir, egy kozbeiktatott
:: ANSI sor utan a fajl tobbi resze olvashatatlan krix-kraxxa valna.
:: Start-Sleep-et hasznalunk "timeout" helyett, mert a timeout parancs
:: hibaval azonnal kilep, ha nincs interaktiv konzol (Task Scheduler
:: alatt nincs).
powershell -NoProfile -Command "node server.js 2>&1 | Tee-Object -FilePath '%~dp0LOG\server-console.log' -Append; ('[{0}] A node folyamat kilepett, ujrainditas 30 mp mulva...' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) | Tee-Object -FilePath '%~dp0LOG\server-console.log' -Append; Start-Sleep -Seconds 30"
goto loop
