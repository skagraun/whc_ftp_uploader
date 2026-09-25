# ============================================================
# Az orankenti feltoltes tenyleges inditoja (a _trigger-upload.bat
# hivja, azt pedig a "<TaskNev>-Trigger" scheduled task).
# Meghivja a mar futo webszerver /api/run-upload vegpontjat.
#
# MIERT KULON PS1: korabban ez egy egysoros powershell hivas volt a
# .bat-ban, ami hiba eseten csak 1-es kilepesi koddal kilepett. A
# Task Scheduler ezt is "Task completed"-kent naplozza, igy ha a
# webszerver leallt, a feltoltes NAPOKIG csendben nem futott le (se
# napi log, se e-mail - azokat ugyanis a webszerver irja/kuldi, ami
# eppen nem futott). Most a hibat ez a script maga naplozza
# (LOG\trigger.log) es maga kuld rola e-mailt, a webszervertol
# fuggetlenul.
# ============================================================

$ErrorActionPreference = "Stop"
$appDir = $PSScriptRoot

# --- .env beolvasasa (ugyanazok az ertekek, amiket a szerver is hasznal) ---
$envVars = @{}
$envFile = Join-Path $appDir ".env"
if (Test-Path $envFile) {
    foreach ($line in Get-Content $envFile) {
        $t = $line.Trim()
        # ures es komment sorok kihagyasa
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        $idx = $t.IndexOf("=")
        if ($idx -lt 1) { continue }
        $key = $t.Substring(0, $idx).Trim()
        # az ertek korul esetleg levo idezojeleket levagjuk (dotenv is igy csinalja)
        $val = $t.Substring($idx + 1).Trim().Trim('"').Trim("'")
        $envVars[$key] = $val
    }
}

function Get-EnvValue($name, $default) {
    if ($envVars.ContainsKey($name) -and $envVars[$name] -ne "") { return $envVars[$name] }
    return $default
}

$port  = Get-EnvValue "PORT" "3000"
$token = Get-EnvValue "RUN_UPLOAD_TOKEN" ""

# --- Sajat log (az app mappa LOG\trigger.log fajljaba) ---
# Szandekosan NEM a WATCH_DIR\LOG napi logba irunk: az a feltoltes
# logja, ezt pedig a szerver irja - itt csak a trigger oldali hibakat
# rogzitjuk, hogy utolag is lathato legyen, mikor nem ert el a szerver.
$logDir = Join-Path $appDir "LOG"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$logFile = Join-Path $logDir "trigger.log"

function Write-TriggerLog($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg
    try { Add-Content -Path $logFile -Value $line -Encoding UTF8 } catch { }
    Write-Output $line
}

# --- E-mail riasztas, ha a szervert nem ertuk el ---
# Ugyanazokat az SMTP_* / ALERT_EMAIL_TO ertekeket hasznalja, mint a
# szerver sajat hiba-ertesitoje. Ha ezek nincsenek beallitva, csak
# naplozunk. Az e-mail kuldes hibaja sem allitja meg a scriptet.
function Send-Alert($errorText) {
    $smtpHost = Get-EnvValue "SMTP_HOST" ""
    $to       = Get-EnvValue "ALERT_EMAIL_TO" ""
    if ($smtpHost -eq "" -or $to -eq "") {
        Write-TriggerLog "SMTP_HOST vagy ALERT_EMAIL_TO nincs beallitva - nem kuldok e-mailt."
        return
    }
    $from     = Get-EnvValue "SMTP_FROM" "whc-ftp-uploader@opmobility.com"
    $smtpPort = [int](Get-EnvValue "SMTP_PORT" "25")
    $body = @(
        "A feltoltes orankenti inditasa nem sikerult ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')).",
        "Szerver: $env:COMPUTERNAME, port: $port, app mappa: $appDir",
        "",
        "Hiba: $errorText",
        "",
        "Valoszinu ok: a webszerver task nem fut, vagy nem valaszol.",
        "Ellenorzes: http://localhost:$port/api/health",
        "Reszletek: $appDir\LOG\server-console.log es $logFile"
    ) -join "`r`n"
    try {
        # Send-MailMessage "elavult", de Windows PowerShell 5.1-ben megbizhatoan
        # mukodik a belso, hitelesites nelkuli relay-jel.
        Send-MailMessage -SmtpServer $smtpHost -Port $smtpPort -From $from -To $to `
            -Subject "[WHC FTP Uploader] A webszerver nem erheto el - $env:COMPUTERNAME" `
            -Body $body -Encoding UTF8
        Write-TriggerLog "Riaszto e-mail elkuldve: $to"
    } catch {
        Write-TriggerLog "Riaszto e-mail kuldese NEM sikerult: $($_.Exception.Message)"
    }
}

# --- A tenyleges hivas ---
try {
    $r = Invoke-RestMethod -Method Post -Uri "http://localhost:$port/api/run-upload" `
        -Headers @{ "x-run-token" = $token } -TimeoutSec 300
    Write-Output ($r | ConvertTo-Json -Compress)
    exit 0
} catch {
    $errText = $_.Exception.Message
    Write-TriggerLog "HIBA: /api/run-upload hivas sikertelen: $errText"
    Send-Alert $errText
    exit 1
}
