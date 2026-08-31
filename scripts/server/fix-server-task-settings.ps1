# ============================================================
# A webszerver taskot sima "schtasks /create"-tel hozzuk letre (mert
# az megbizhatoan elfogadja a domain felhasznalo/jelszo parost), DE
# az igy letrehozott task alapertelmezetten 3 nap utan magatol
# leallna ("Stop the task if it runs longer than: 3 days"), ami a
# folyamatosan futo webszervernek NEM jo.
#
# Ez a script UTOLAG, egy MAR LETEZO taskon modositja csak a Settings
# reszet (korlatlan futasi ido + ujrainditas hiba eseten). Barmikor
# kulon is futtathato egy mar telepitett taskra, nem kell hozza
# ujratelepiteni semmit.
#
# FONTOS: a modern "ScheduledTasks" PowerShell modul (Set-ScheduledTask
# / Register-ScheduledTask) ezen a rendszeren "user name or password
# is incorrect" hibat dob jelszavas (stored password) logon tipusu
# taskokra, meg akkor is, ha nem is adunk meg jelszot - ez a modul egy
# ismert korlatja. Ezert itt a regi, COM-alapu Task Scheduler API-t
# hasznaljuk (Schedule.Service), ami kifejezetten tamogatja azt az
# esetet, hogy a mar eltarolt jelszot ujra felhasznalja frissiteskor,
# ha a userId-t megadjuk, de a password-ot uresen hagyjuk.
#
# Hasznalat (Adminisztratorkent):
#   powershell -ExecutionPolicy Bypass -File fix-server-task-settings.ps1 -TaskName "WHC-FTP-Uploader"
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$TaskName
)

$ErrorActionPreference = "Stop"

# TASK_CREATE_OR_UPDATE
$TASK_CREATE_OR_UPDATE = 6
# TASK_LOGON_PASSWORD - ures jelszoval a Task Scheduler ujrahasznalja
# a mar eltarolt jelszot ehhez a felhasznalohoz.
$TASK_LOGON_PASSWORD = 1

$Service = New-Object -ComObject "Schedule.Service"
$Service.Connect()
$RootFolder = $Service.GetFolder("\")
$Task = $RootFolder.GetTask($TaskName)
$Definition = $Task.Definition

$Definition.Settings.ExecutionTimeLimit = "PT0S"   # PT0S = korlatlan (nincs 3 napos leallitas)
$Definition.Settings.RestartCount = 3
$Definition.Settings.RestartInterval = "PT1M"      # ha vaskaratlanul kilepne, 1 percenkent probalja ujrainditani, max 3x

$UserId = $Definition.Principal.UserId

$RootFolder.RegisterTaskDefinition(
    $TaskName,
    $Definition,
    $TASK_CREATE_OR_UPDATE,
    $UserId,
    $null,
    $TASK_LOGON_PASSWORD
) | Out-Null

Write-Host "OK: '$TaskName' beallitasai frissitve (korlatlan futasi ido)."
