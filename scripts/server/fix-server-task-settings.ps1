# ============================================================
# A webszerver taskot sima "schtasks /create"-tel hozzuk letre (mert
# az megbizhatoan elfogadja a domain felhasznalo/jelszo parost), DE
# az igy letrehozott task alapertelmezetten 3 nap utan magatol
# leallna ("Stop the task if it runs longer than: 3 days"), ami a
# folyamatosan futo webszervernek NEM jo.
#
# Ez a script UTOLAG, a mar letrehozott taskon modositja csak a
# Settings reszet (korlatlan futasi ido + ujrainditas hiba eseten) -
# ehhez NEM kell ujra jelszo, mert a task "Principal"-jat
# (felhasznalo/jelszo) nem erintjuk, csak a Settings-et.
#
# Az install-service.bat hivja meg, kozvetlenul a webszerver task
# "schtasks /create" -es letrehozasa utan.
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$TaskName
)

$ErrorActionPreference = "Stop"

$Task = Get-ScheduledTask -TaskName $TaskName

$Task.Settings.ExecutionTimeLimit = "PT0S"   # PT0S = korlatlan (nincs 3 napos leallitas)
$Task.Settings.RestartCount = 3
$Task.Settings.RestartInterval = "PT1M"      # ha vaskaratlanul kilepne, 1 percenkent probalja ujrainditani, max 3x

Set-ScheduledTask -TaskName $TaskName -Settings $Task.Settings | Out-Null

Write-Host "OK: '$TaskName' beallitasai frissitve (korlatlan futasi ido)."
