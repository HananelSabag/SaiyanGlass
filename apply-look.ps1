# Applies the whole look in one elevated run: the Windhawk styler settings for
# the taskbar, Start, File Explorer and the notification panels, then the glass
# desktop icons. Re-run it when an update resets something.
#   -Restore  puts the desktop icons back (disable the Windhawk mods for the rest)
# The output goes to %TEMP%\saiyanglass-apply.log.
param([switch]$Restore)

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" + $(if ($Restore) { ' -Restore' } else { '' })
    try { Start-Process powershell.exe -ArgumentList $arguments -Verb RunAs -WindowStyle Hidden -Wait -ErrorAction Stop }
    catch { 'Nothing changed: the approval window was declined.'; return }
    Get-Content (Join-Path $env:TEMP 'saiyanglass-apply.log') -Encoding UTF8
    return
}

& {
    if (-not $Restore) {
        & "$PSScriptRoot\windhawk\apply-liquid-glass.ps1"
        & "$PSScriptRoot\windhawk\tune-taskbar.ps1"
        & "$PSScriptRoot\windhawk\tune-shell.ps1"
        'windhawk settings applied'
    }
    & "$PSScriptRoot\desktop\desktop-icons.ps1" -Restore:$Restore
} *>&1 | ForEach-Object { "$_" } | Set-Content (Join-Path $env:TEMP 'saiyanglass-apply.log') -Encoding UTF8
