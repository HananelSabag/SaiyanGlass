# Applies the whole look in one elevated run: the Windhawk styler settings for
# the taskbar, Start, File Explorer and the notification panels, then the glass
# desktop icons. Re-run it when an update resets something.
#   -Restore  puts the desktop icons back (disable the Windhawk mods for the rest)
# The output goes to %TEMP%\saiyanglass-apply.log.
param([switch]$Restore)

$log = Join-Path $env:TEMP 'saiyanglass-apply.log'
$restoreArg = if ($Restore) { ' -Restore' } else { '' }

function Show-Log {
    for ($i = 0; $i -lt 300 -and -not (Test-Path $log); $i++) { Start-Sleep -Seconds 1 }
    Start-Sleep -Milliseconds 500
    Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue
}

# Started from a packaged (MSIX) app such as the Claude desktop app, writes to
# AppData and HKCU land in the app's private copy, even elevated, and Explorer
# never sees them. Relaunch through Explorer, which runs outside any package.
Add-Type -Namespace SaiyanGlass -Name Package -MemberDefinition '[DllImport("kernel32.dll", CharSet = CharSet.Unicode)] public static extern int GetCurrentPackageFullName(ref int length, System.Text.StringBuilder name);'
$length = 0
if ([SaiyanGlass.Package]::GetCurrentPackageFullName([ref]$length, $null) -ne 15700) {  # 15700: no package
    $cmd = Join-Path $env:TEMP 'saiyanglass-apply.cmd'
    Set-Content $cmd "@powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$restoreArg" -Encoding ASCII
    Remove-Item $log -ErrorAction SilentlyContinue
    Start-Process explorer.exe $cmd
    Show-Log
    return
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Remove-Item $log -ErrorAction SilentlyContinue
    try { Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"$restoreArg" -Verb RunAs -WindowStyle Hidden -Wait -ErrorAction Stop }
    catch { 'Nothing changed: the approval window was declined.' | Set-Content $log -Encoding UTF8 }
    Show-Log
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
} *>&1 | ForEach-Object { "$_" } | Set-Content $log -Encoding UTF8
