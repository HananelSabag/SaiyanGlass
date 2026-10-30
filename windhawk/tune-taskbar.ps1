# Taskbar Styler overrides on top of the LiquidGlass2 theme. Runs elevated.
#   -Mode debug  shows the layout widths in the clock (to position the weather)
#   -Mode final  the normal look
param(
    [ValidateSet('debug', 'final')][string]$Mode = 'final',
    [string]$WeatherMargin = '-400,0,0,0',
    # Keeps the weather 12px from the left edge as the dock width changes
    # (calibrated on a 2560px-wide screen, see -Mode debug).
    [string]$WeatherShift = '{{329.5-(containerGridWidth-sgRepW)/2}}'
)
. "$PSScriptRoot\glass.ps1"

$bubbleStyles = @(
    "Background:=$Bubble",
    "Background@PointerOver:=$BubbleHover",
    "Background@Pressed:=$BubblePressed",
    'BorderThickness=1',
    "BorderBrush:=$BubbleEdge",
    'CornerRadius=12'
)
$inputSwitcher = 'WindowsInternal.ComposableShell.Experiences.TextInput.Common.InputSwitcher > ContentControl > ContentPresenter > Grid'

$controlStyles = @(
    # Layout widths, used to place the weather.
    @{ target = 'Taskbar.TaskbarFrame'; styles = @('ActualWidth=>sgFrameW') },
    @{ target = 'Taskbar.TaskbarFrame > Grid#RootGrid'; styles = @('ActualWidth=>sgRootW') },
    @{ target = 'Microsoft.UI.Xaml.Controls.ItemsRepeater#TaskbarFrameRepeater'; styles = @('ActualWidth=>sgRepW') },
    # Tray on the right edge (the theme places it right after the dock).
    @{ target = 'SystemTray.SystemTrayFrame'; styles = @('HorizontalAlignment=Right', 'Margin=0,0,12,0') },
    @{ target = 'StackPanel#SystemTrayFrameGrid, Grid#SystemTrayFrameGrid'; styles = @("Background:=$GlassText") },
    # Weather capsule: darker glass, fixed width, kept out of the dock's width by
    # the theme's negative margin, then shifted to the left edge. A render shift
    # does not change layout, so the formula can follow the dock width safely.
    @{ target = 'Taskbar.AugmentedEntryPointButton#AugmentedEntryPointButton > Taskbar.TaskListButtonPanel#ExperienceToggleButtonRootPanel'; styles = @("Background:=$GlassText", 'Width=236', 'MinWidth=236', 'MaxWidth=236', "Margin=$WeatherMargin", "RenderTransform:=<TranslateTransform X=`"$WeatherShift`" Y=`"0`"/>") },
    @{ target = 'Windows.UI.Xaml.Controls.Grid#AugmentedEntryPointContentGrid'; styles = @('Margin=10,0,14,0', 'HorizontalAlignment=Left') },
    # Slightly bolder text on the glass.
    @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock'; styles = @('FontWeight=SemiBold') },
    @{ target = 'SystemTray.TextIconContent > Grid > TextBlock'; styles = @('FontWeight=SemiBold') },
    @{ target = 'Border#LargeTicker2 > AdaptiveCards.Rendering.Uwp.WholeItemsPanel > TextBlock'; styles = @('FontWeight=SemiBold') },
    # A glass bubble around every app icon, and around Start / Task View.
    @{ target = 'Grid#IconPanel@CommonStates > Border#BackgroundElement, Taskbar.TaskListLabeledButtonPanel@CommonStates > Border#BackgroundElement'; styles = $bubbleStyles },
    @{ target = 'Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Grid > Border#BackgroundElement, Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Border#BackgroundElement'; styles = $bubbleStyles },
    # Menus, tooltips and window previews: the theme's tint is too light for
    # text on bright wallpapers.
    @{ target = 'MenuFlyoutPresenter > Border'; styles = @("Background:=$GlassPanel") },
    @{ target = 'Windows.UI.Xaml.Controls.ToolTip > Windows.UI.Xaml.Controls.ContentPresenter#LayoutRoot'; styles = @("Background:=$GlassText") },
    @{ target = 'Taskbar.TaskbarBackground#HoverFlyoutBackgroundControl > Grid > Rectangle#BackgroundFill'; styles = @("Fill:=$GlassPanel") },
    # Keyboard layout panel: the theme paints its list red (a bug in the theme).
    @{ target = $inputSwitcher; styles = @("Background:=$GlassPanel") },
    @{ target = "$inputSwitcher > Grid"; styles = @('Background=Transparent') },
    # Snap layout suggestions: the same bug.
    @{ target = 'SnapLayout.SnapLayoutControl#SuggestionSnapLayout Windows.UI.Xaml.Controls.Border#LayoutBorder'; styles = @('Background:=<WindhawkBlur BlurAmount="15" TintColor="#30505050"/>') }
)
if ($Mode -eq 'debug') {
    $controlStyles += @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock#TimeInnerTextBlock'; styles = @('Text=C{{containerGridWidth}} F{{sgFrameW}}') }
    $controlStyles += @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock#DateInnerTextBlock'; styles = @('Text=R{{sgRootW}} I{{sgRepW}}') }
}

Set-WindhawkMod 'windows-11-taskbar-styler' -ControlStyles $controlStyles
