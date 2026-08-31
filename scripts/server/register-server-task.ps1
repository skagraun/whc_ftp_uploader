# ============================================================
# A webszerver taskot ezzel regisztraljuk (nem sima "schtasks
# /create"-tel), mert a webszervernek VEGTELEN ideig kell futnia,
# a sima schtasks altal letrehozott task viszont a Windows alapertelmezese
# szerint 3 nap utan magatol leallna ("Stop the task if it runs
# longer than: 3 days" - ezt kozvetlenul schtasks paranccsal nem
# lehet kikapcsolni, csak PowerShell-lel vagy egyedi XML task
# definicioval).
#
# Az install-service.bat hivja meg ezt a scriptet a webszerver
# taskhoz; a percenkenti/oranta "-Trigger" taskhoz nem kell, mert az
# amugy is masodpercek alatt lefut, sosem futna bele a 3 napos limitbe.
# ============================================================

param(
    [Parameter(Mandatory = $true)][string]$TaskName,
    [Parameter(Mandatory = $true)][string]$AppDir,
    [Parameter(Mandatory = $true)][string]$RunUser
)

$ErrorActionPreference = "Stop"

$SecurePass = Read-Host -AsSecureString "Jelszo ehhez a felhasznalohoz ($RunUser)"
$BSTR = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
$PlainPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue

$RunBat = Join-Path $AppDir "_run.bat"
$Action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$RunBat`""
$Trigger = New-ScheduledTaskTrigger -AtStartup

# ExecutionTimeLimit = TimeSpan.Zero -> "korlatlan futasi ido" (nincs
# 3 napos automatikus leallitas). RestartCount/RestartInterval: ha a
# folyamat vaskaratlanul kilepne, a Task Scheduler ujraprobalja inditani.
$Settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit ([TimeSpan]::Zero) `
    -RestartCount 3 `
    -RestartInterval (New-TimeSpan -Minutes 1) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -User $RunUser `
    -Password $PlainPass `
    -RunLevel Highest `
    -Force | Out-Null

$PlainPass = $null

Write-Host "OK: '$TaskName' letrehozva (korlatlan futasi idovel)."
