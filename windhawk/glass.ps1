# Shared glass for every Windhawk styler setting. Dark glass sits behind text so
# white text reads on any wallpaper (a 70% tint gives about 3:1 on white);
# light bubbles mark items, like the app icons on the taskbar.
$GlassText = '<WindhawkBlur BlurAmount="10" TintColor="#B30B0C10" TintSaturation="1.3"/>'
$GlassPanel = '<WindhawkBlur BlurAmount="18" TintColor="#B30B0C10" TintSaturation="1.3"/>'
$Bubble = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#30FFFFFF" Offset="0"/><GradientStop Color="#12FFFFFF" Offset="1"/></LinearGradientBrush>'
$BubbleHover = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#4AFFFFFF" Offset="0"/><GradientStop Color="#22FFFFFF" Offset="1"/></LinearGradientBrush>'
$BubblePressed = '<SolidColorBrush Color="#1AFFFFFF"/>'
$BubbleEdge = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#90FFFFFF" Offset="0"/><GradientStop Color="#1AFFFFFF" Offset="0.45"/><GradientStop Color="#45FFFFFF" Offset="1"/></LinearGradientBrush>'

# Writes a styler mod's settings and makes Windhawk reload them. Windhawk keeps
# mod settings under HKLM, so callers run elevated.
function Set-WindhawkMod {
    param([string]$Mod, [hashtable]$Settings = @{}, [string[]]$Constants = @(), [object[]]$ControlStyles = @())
    $root = "SOFTWARE\Windhawk\Engine\Mods\$Mod"
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\Settings", $true)
    if (-not $key) { throw "The Windhawk mod $Mod is not installed" }
    foreach ($name in $key.GetValueNames()) {
        if ($name -like 'controlStyles*' -or $name -like 'styleConstants*') { $key.DeleteValue($name) }
    }
    foreach ($name in $Settings.Keys) { $key.SetValue($name, $Settings[$name], 'String') }
    for ($i = 0; $i -lt $Constants.Count; $i++) { $key.SetValue("styleConstants[$i]", $Constants[$i], 'String') }
    for ($i = 0; $i -lt $ControlStyles.Count; $i++) {
        $key.SetValue("controlStyles[$i].target", $ControlStyles[$i].target, 'String')
        for ($j = 0; $j -lt $ControlStyles[$i].styles.Count; $j++) {
            $key.SetValue("controlStyles[$i].styles[$j]", $ControlStyles[$i].styles[$j], 'String')
        }
    }
    $key.Close()
    # Windhawk reloads a mod's settings when this timestamp changes.
    $modKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($root, $true)
    $modKey.SetValue('SettingsChangeTime', [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), 'DWord')
    $modKey.Close()
}
