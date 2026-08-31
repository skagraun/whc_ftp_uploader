@echo off
:: Ezt a wrapper scriptet hivja a Windows Scheduled Task.
:: A sajat mappajabol inditja el az appot, hogy a relativ utvonalak
:: (.env, src/server/*) helyesen feloldodjanak.
set NODE_ENV=production
cd /d "%~dp0"
node server.js
