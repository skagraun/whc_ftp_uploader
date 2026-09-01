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
set NODE_ENV=production
cd /d "%~dp0"
if not exist "%~dp0LOG" mkdir "%~dp0LOG"
powershell -NoProfile -Command "node server.js 2>&1 | Tee-Object -FilePath '%~dp0LOG\server-console.log' -Append"
