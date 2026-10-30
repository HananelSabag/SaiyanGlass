# Taskbar Styler overrides on top of the LiquidGlass theme. Windhawk keeps mod
# settings under HKLM, so this runs elevated.
#   -Mode debug  shows the layout widths in the clock (to position the weather)
#   -Mode final  the normal look
param([ValidateSet('debug', 'final')][string]$Mode = 'final', [string]$WeatherMargin = '-400,0,0,0', [string]$WeatherShift = '0')
$root = 'SOFTWARE\Windhawk\Engine\Mods'
$now = [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

# Text capsules get a darker glass than the dock so white text reads on any wallpaper.
$textPill = '<WindhawkBlur BlurAmount="10" TintColor="#B30B0C10" TintSaturation="1.3"/>'
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
    # Layout widths, used to place the weather.
    @{ target = 'Taskbar.TaskbarFrame'; styles = @('ActualWidth=>sgFrameW') },
    @{ target = 'Taskbar.TaskbarFrame > Grid#RootGrid'; styles = @('ActualWidth=>sgRootW') },
    @{ target = 'Microsoft.UI.Xaml.Controls.ItemsRepeater#TaskbarFrameRepeater'; styles = @('ActualWidth=>sgRepW') },
    # Tray on the right edge (the theme places it right after the dock).
    @{ target = 'SystemTray.SystemTrayFrame'; styles = @('HorizontalAlignment=Right', 'Margin=0,0,12,0') },
    @{ target = 'StackPanel#SystemTrayFrameGrid, Grid#SystemTrayFrameGrid'; styles = @("Background:=$textPill") },
    # Weather capsule: darker glass, fixed width, kept out of the dock's width by
    # the theme's negative margin, then shifted to the left edge. A render shift
    # does not change layout, so the formula can follow the dock width safely.
    @{ target = 'Taskbar.AugmentedEntryPointButton#AugmentedEntryPointButton > Taskbar.TaskListButtonPanel#ExperienceToggleButtonRootPanel'; styles = @("Background:=$textPill", 'Width=236', 'MinWidth=236', 'MaxWidth=236', "Margin=$WeatherMargin", "RenderTransform:=<TranslateTransform X=`"$WeatherShift`" Y=`"0`"/>") },
    @{ target = 'Windows.UI.Xaml.Controls.Grid#AugmentedEntryPointContentGrid'; styles = @('Margin=10,0,14,0', 'HorizontalAlignment=Left') },
    # Slightly bolder text on the glass.
    @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock'; styles = @('FontWeight=SemiBold') },
    @{ target = 'SystemTray.TextIconContent > Grid > TextBlock'; styles = @('FontWeight=SemiBold') },
    @{ target = 'Border#LargeTicker2 > AdaptiveCards.Rendering.Uwp.WholeItemsPanel > TextBlock'; styles = @('FontWeight=SemiBold') },
    # A glass bubble around every app icon, and around Start / Task View.
    @{ target = 'Grid#IconPanel@CommonStates > Border#BackgroundElement, Taskbar.TaskListLabeledButtonPanel@CommonStates > Border#BackgroundElement'; styles = $bubbleStyles },
    @{ target = 'Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Grid > Border#BackgroundElement, Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Border#BackgroundElement'; styles = $bubbleStyles }
)
if ($Mode -eq 'debug') {
    $controlStyles += @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock#TimeInnerTextBlock'; styles = @('Text=C{{containerGridWidth}} F{{sgFrameW}}') }
    $controlStyles += @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock#DateInnerTextBlock'; styles = @('Text=R{{sgRootW}} I{{sgRepW}}') }
}

$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\windows-11-taskbar-styler\Settings", $true)
foreach ($name in $key.GetValueNames()) { if ($name -like 'controlStyles*') { $key.DeleteValue($name) } }
for ($i = 0; $i -lt $controlStyles.Count; $i++) {
    $key.SetValue("controlStyles[$i].target", $controlStyles[$i].target, 'String')
    for ($j = 0; $j -lt $controlStyles[$i].styles.Count; $j++) { $key.SetValue("controlStyles[$i].styles[$j]", $controlStyles[$i].styles[$j], 'String') }
}
$key.Close()
$mod = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\windows-11-taskbar-styler", $true); $mod.SetValue('SettingsChangeTime', $now, 'DWord'); $mod.Close()
