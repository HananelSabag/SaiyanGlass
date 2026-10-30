# Applies the LiquidGlass themes to Windhawk's taskbar and Start menu stylers.
# Windhawk keeps mod settings under HKLM, so this runs elevated.
$now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
foreach ($mod in 'windows-11-taskbar-styler', 'windows-11-start-menu-styler') {
    $key = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$mod"
    Set-ItemProperty -Path "$key\Settings" -Name 'theme' -Value 'LiquidGlass2' -Type String
    # Windhawk reloads a mod's settings when this timestamp changes.
    Set-ItemProperty -Path $key -Name 'SettingsChangeTime' -Value $now -Type DWord
}
