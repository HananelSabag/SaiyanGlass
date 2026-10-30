# Taskbar Styler overrides on top of the LiquidGlass theme, and turning off
# Translucent Windows. Windhawk keeps mod settings under HKLM, so this runs elevated.
$root = 'SOFTWARE\Windhawk\Engine\Mods'
$now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

$glassPill = '<WindhawkBlur BlurAmount="8" TintColor="#5C0C0D10" TintSaturation="1.4"/>'
$bubble = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#30FFFFFF" Offset="0"/><GradientStop Color="#12FFFFFF" Offset="1"/></LinearGradientBrush>'
$bubbleHover = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#4AFFFFFF" Offset="0"/><GradientStop Color="#22FFFFFF" Offset="1"/></LinearGradientBrush>'
$bubbleEdge = '<LinearGradientBrush StartPoint="0,0" EndPoint="0,1"><GradientStop Color="#90FFFFFF" Offset="0"/><GradientStop Color="#1AFFFFFF" Offset="0.45"/><GradientStop Color="#45FFFFFF" Offset="1"/></LinearGradientBrush>'
$bubbleStyles = @(
    "Background:=$bubble",
    "Background@PointerOver:=$bubbleHover",
    'Background@Pressed:=<SolidColorBrush Color="#1AFFFFFF"/>',
    'BorderThickness=1',
    "BorderBrush:=$bubbleEdge",
    'CornerRadius=12'
)

$controlStyles = @(
    # Tray back on the right edge (the theme places it right after the dock).
    @{ target = 'SystemTray.SystemTrayFrame'; styles = @('HorizontalAlignment=Right', 'Margin=0,0,12,0') },
    # Darker glass behind text-heavy capsules so clock, language and weather read well.
    @{ target = 'StackPanel#SystemTrayFrameGrid, Grid#SystemTrayFrameGrid'; styles = @("Background:=$glassPill") },
    # Weather capsule sized to its icon, temperature and description.
    @{ target = 'Taskbar.AugmentedEntryPointButton#AugmentedEntryPointButton > Taskbar.TaskListButtonPanel#ExperienceToggleButtonRootPanel'; styles = @("Background:=$glassPill", 'MinWidth=56', 'MaxWidth=240', 'Margin=-620,0,0,0') },
    @{ target = 'Windows.UI.Xaml.Controls.Grid#AugmentedEntryPointContentGrid'; styles = @('Margin=10,0,14,0', 'HorizontalAlignment=Left') },
    # A glass bubble around every app icon, and around Start / Task View.
    @{ target = 'Grid#IconPanel@CommonStates > Border#BackgroundElement, Taskbar.TaskListLabeledButtonPanel@CommonStates > Border#BackgroundElement'; styles = $bubbleStyles },
    @{ target = 'Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Grid > Border#BackgroundElement, Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Border#BackgroundElement'; styles = $bubbleStyles }
)

$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\windows-11-taskbar-styler\Settings", $true)
foreach ($name in $key.GetValueNames()) { if ($name -like 'controlStyles*') { $key.DeleteValue($name) } }
for ($i = 0; $i -lt $controlStyles.Count; $i++) {
    $key.SetValue("controlStyles[$i].target", $controlStyles[$i].target, 'String')
    for ($j = 0; $j -lt $controlStyles[$i].styles.Count; $j++) { $key.SetValue("controlStyles[$i].styles[$j]", $controlStyles[$i].styles[$j], 'String') }
}
$key.Close()
$mod = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\windows-11-taskbar-styler", $true); $mod.SetValue('SettingsChangeTime', $now, 'DWord'); $mod.Close()

# Window glass only for File Explorer (explorer.exe), with the system acrylic
# backdrop and no accent-colored controls; every other app keeps its normal look.
$tws = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\translucent-windows\Settings", $true)
$tws.SetValue('RenderingMod.ThemeBackground', 1, 'DWord')
$tws.SetValue('RenderingMod.SysColors', 0, 'DWord')
$tws.SetValue('RenderingMod.AccentColorControls', 0, 'DWord')
$tws.SetValue('BackgroundEffects.type', 'acrylicsystem', 'String')
$tws.SetValue('FlyoutsEffects', 1, 'DWord')
$tws.Close()
$tw = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\translucent-windows", $true)
$tw.SetValue('IncludeCustom', 'explorer.exe', 'String')
$tw.SetValue('IncludeExcludeCustomOnly', 1, 'DWord')
$tw.SetValue('Disabled', 0, 'DWord')
$tw.SetValue('SettingsChangeTime', $now, 'DWord')
$tw.Close()
