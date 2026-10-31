# The taskbar and its flyouts (menus, tooltips, window previews, Alt+Tab, task
# view, snap layouts, the volume display) on the LiquidGlass2 theme, restyled
# with the tokens from glass.ps1. Runs elevated.
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

# Capsules keep the theme's pill radius; the rim and the glass come from the tokens.
$capsule = @("Background:=$Glass", "BorderBrush:=$Rim", "BorderThickness=$RimThickness")
# Hover never grows an icon: the tray icons keep the theme's size and get a
# bubble instead, like everything else.
function Get-Scale([double]$s) { "<ScaleTransform ScaleX=`"$s`" ScaleY=`"$s`"/>" }
$trayHover = @("Background@PointerOver:=$Bubble", "Background@Pressed:=$BubblePressed", "CornerRadius=$($Radius.Menu)")
$inputSwitcher = 'WindowsInternal.ComposableShell.Experiences.TextInput.Common.InputSwitcher > ContentControl > ContentPresenter > Grid'
$switcher = 'WindowsInternal.ComposableShell.Experiences.Switcher'

$controlStyles = @(
    # Layout widths, used to place the weather.
    @{ target = 'Taskbar.TaskbarFrame'; styles = @('ActualWidth=>sgFrameW') },
    @{ target = 'Taskbar.TaskbarFrame > Grid#RootGrid'; styles = @('ActualWidth=>sgRootW') },
    @{ target = 'Microsoft.UI.Xaml.Controls.ItemsRepeater#TaskbarFrameRepeater'; styles = @('ActualWidth=>sgRepW') },

    # The dock: clear glass, the bubble around every app icon and around
    # Start / Task View. The theme's soft ring around the dock stays.
    @{ target = 'Taskbar.TaskbarFrame > Grid#RootGrid > Taskbar.TaskbarBackground > Grid > Rectangle#BackgroundFill'; styles = @("Fill:=$GlassClear", "Stroke:=$Rim", "StrokeThickness=$RimThickness") },
    @{ target = 'Grid#IconPanel@CommonStates > Border#BackgroundElement, Taskbar.TaskListLabeledButtonPanel@CommonStates > Border#BackgroundElement'; styles = Get-BubbleStyles -States },
    @{ target = 'Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Grid > Border#BackgroundElement, Taskbar.ExperienceToggleButton > Taskbar.TaskListButtonPanel@CommonStates > Border#BackgroundElement'; styles = Get-BubbleStyles -States },

    # Tray on the right edge (the theme places it right after the dock).
    @{ target = 'SystemTray.SystemTrayFrame'; styles = @('HorizontalAlignment=Right', 'Margin=0,0,12,0') },
    @{ target = 'StackPanel#SystemTrayFrameGrid, Grid#SystemTrayFrameGrid'; styles = $capsule },
    @{ target = 'SystemTray.NotifyIconView > Grid@CommonStates'; styles = @("RenderTransform@PointerOver:=$(Get-Scale 1.2)") },
    @{ target = 'SystemTray.OmniButton#ControlCenterButton > Grid@CommonStates'; styles = @("RenderTransform@PointerOver:=$(Get-Scale 1.2)") },
    @{ target = 'SystemTray.OmniButton#NotificationCenterButton > Grid@CommonStates'; styles = @("RenderTransform@PointerOver:=$(Get-Scale 1.05)") },
    @{ target = 'SystemTray.ChevronIconView > Grid#ContainerGrid@'; styles = @("RenderTransform@PointerOver:=$(Get-Scale 1.28)") },
    @{ target = 'SystemTray.NotifyIconView@CommonStates > Grid#ContainerGrid > Border#BackgroundBorder, SystemTray.NotifyIconView@CommonStates > Grid > Border#BackgroundBorder'; styles = $trayHover },
    @{ target = 'SystemTray.OmniButton#ControlCenterButton@CommonStates > Grid > Border#BackgroundBorder, SystemTray.OmniButton#NotificationCenterButton@CommonStates > Grid > Border#BackgroundBorder'; styles = $trayHover },

    # Weather capsule: fixed width, kept out of the dock's width by the theme's
    # negative margin, then shifted to the left edge. A render shift does not
    # change layout, so the formula can follow the dock width safely.
    @{ target = 'Taskbar.AugmentedEntryPointButton#AugmentedEntryPointButton > Taskbar.TaskListButtonPanel#ExperienceToggleButtonRootPanel'; styles = $capsule + @('Width=236', 'MinWidth=236', 'MaxWidth=236', "Margin=$WeatherMargin", "RenderTransform:=<TranslateTransform X=`"$WeatherShift`" Y=`"0`"/>") },
    @{ target = 'Windows.UI.Xaml.Controls.Grid#AugmentedEntryPointContentGrid'; styles = @('Margin=10,0,14,0', 'HorizontalAlignment=Left') },

    # Text on glass.
    @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock'; styles = @("FontWeight=$TextWeight") },
    @{ target = 'SystemTray.TextIconContent > Grid > TextBlock'; styles = @("FontWeight=$TextWeight") },
    @{ target = 'Border#LargeTicker2 > AdaptiveCards.Rendering.Uwp.WholeItemsPanel > TextBlock'; styles = @("FontWeight=$TextWeight") },

    # Menus, tooltips, the tray overflow and the volume display.
    @{ target = 'MenuFlyoutPresenter'; styles = @("CornerRadius=$($Radius.Menu)") },
    @{ target = 'MenuFlyoutPresenter > Border'; styles = Get-SurfaceStyles $Radius.Menu },
    @{ target = 'MenuFlyoutItem, MenuFlyoutSubItem, ToggleMenuFlyoutItem'; styles = @("FontWeight=$TextWeight", "CornerRadius=$($Radius.Row)") },
    @{ target = 'MenuFlyoutItem > Grid#LayoutRoot@CommonStates, MenuFlyoutSubItem > Grid#LayoutRoot@CommonStates, ToggleMenuFlyoutItem > Grid#LayoutRoot@CommonStates'; styles = Get-RowStyles },
    @{ target = 'Windows.UI.Xaml.Controls.FlyoutPresenter'; styles = @("CornerRadius=$($Radius.Menu)") },
    @{ target = 'Windows.UI.Xaml.Controls.ToolTip > Windows.UI.Xaml.Controls.ContentPresenter#LayoutRoot'; styles = $capsule + @("FontWeight=$TextWeight") },
    @{ target = 'Border#OverflowFlyoutBackgroundBorder'; styles = @("Background:=$GlassPanel", "BorderBrush:=$Rim", "BorderThickness=$RimThickness") },
    @{ target = 'Grid#ConfirmatorMainGrid'; styles = $capsule },
    @{ target = 'TextBlock#confirmatorText'; styles = @("FontWeight=$TextWeight") },
    @{ target = 'Windows.UI.Xaml.Shapes.Rectangle#HorizontalTrackRect'; styles = @("Fill:=$Bubble", "Stroke:=$Rim", "StrokeThickness=$RimThickness") },

    # Window previews: a menu-sized panel, a bubble on the hovered preview.
    @{ target = 'Taskbar.TaskbarBackground#HoverFlyoutBackgroundControl > Grid > Rectangle#BackgroundFill'; styles = @("Fill:=$GlassPanel", "Stroke:=$Rim", "StrokeThickness=$RimThickness", "RadiusX=$($Radius.Menu)", "RadiusY=$($Radius.Menu)") },
    @{ target = 'Taskbar.TaskbarBackground#HoverFlyoutBackgroundControl > Grid > Rectangle#BackgroundStroke'; styles = @('Visibility=Collapsed') },
    @{ target = 'Border#HoverFlyoutBackground, ContentPresenter#HoverFlyoutContent'; styles = @("CornerRadius=$($Radius.Menu)") },
    @{ target = 'Taskbar.TaskItemThumbnailView@CommonStates > Grid > Border#BackgroundBorder, Taskbar.TaskItemThumbnailView@CommonStates > Border#BackgroundBorder'; styles = Get-RowStyles $Radius.Item },
    @{ target = 'Border#ThumbnailVisualHost'; styles = @("CornerRadius=$($Radius.Row)") },
    @{ target = 'Windows.UI.Xaml.Controls.Button#CloseButton'; styles = @("Background:=$Glass", "BorderBrush:=$Rim") },

    # Alt+Tab, task view and snap.
    @{ target = "$switcher.AltTab > Grid#ModalRootGrid > Border#BackgroundElement"; styles = @("CornerRadius=$($Radius.Panel)") },
    @{ target = "$switcher.AltTab > Grid#ModalRootGrid > Border#BackgroundElement > $switcher.SwitchItemList"; styles = Get-SurfaceStyles $Radius.Panel },
    @{ target = "$switcher.SwitchItemListViewItem > Grid > Border"; styles = @("Background:=$Bubble", "BorderBrush:=$Rim", "BorderThickness=$RimThickness", "CornerRadius=$($Radius.Menu)") },
    @{ target = 'Windows.UI.Xaml.Controls.Button#SwitchItemElementCloseButton'; styles = @("Background:=$Glass") },
    @{ target = 'Border#VirtualDesktopBarBackground'; styles = Get-SurfaceStyles $Radius.Panel },
    @{ target = "$switcher.VirtualDesktopElementThemed > Grid#MainGrid > Border#MainBorder, $switcher.NewVirtualDesktopElementThemed > Grid#MainGrid > Border#MainBorder"; styles = @("CornerRadius=$($Radius.Item)") },
    @{ target = "$switcher.VirtualDesktopElementThemed > Grid#MainGrid > Border#BorderHighlight, $switcher.NewVirtualDesktopElementThemed > Grid#MainGrid > Border#BorderHighlight"; styles = Get-BubbleStyles },
    @{ target = 'Windows.UI.Xaml.Controls.Border#SnapBarBorder'; styles = $capsule },
    @{ target = "$switcher.SnapAssistList > Grid > Border#ListBackground"; styles = Get-SurfaceStyles $Radius.Panel },
    @{ target = 'Windows.UI.Xaml.Controls.Border#SnapPickerBorder'; styles = Get-SurfaceStyles $Radius.Menu },
    @{ target = 'Windows.UI.Xaml.Controls.Border#LayoutBorder'; styles = Get-BubbleStyles },
    @{ target = 'Windows.UI.Xaml.Controls.Grid#LayoutGrid > Windows.UI.Xaml.Controls.Button'; styles = @("BorderBrush:=$Rim", "BorderThickness=$RimThickness", "CornerRadius=$($Radius.Row)") },
    @{ target = 'Windows.UI.Xaml.Controls.Grid#LayoutGrid > Windows.UI.Xaml.Controls.Button@CommonStates > Windows.UI.Xaml.Controls.Grid#RootGrid'; styles = @("Background@PointerOver:=$BubbleHover", "Background@Pressed:=$BubblePressed") },
    @{ target = 'Windows.UI.Xaml.Controls.Button#WindowGroupSuggestionButton@CommonStates > Windows.UI.Xaml.Controls.Grid#RootGrid'; styles = @("Background@PointerOver:=$BubbleHover", "Background@Pressed:=$BubblePressed") },
    # Two theme bugs paint the keyboard layout list and the snap layout
    # suggestions red.
    @{ target = $inputSwitcher; styles = @("Background:=$GlassPanel") },
    @{ target = "$inputSwitcher > Grid"; styles = @('Background=Transparent') },
    @{ target = 'SnapLayout.SnapLayoutControl#SuggestionSnapLayout Windows.UI.Xaml.Controls.Border#LayoutBorder'; styles = @("Background:=$Bubble") }
)
if ($Mode -eq 'debug') {
    $controlStyles += @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock#TimeInnerTextBlock'; styles = @('Text=C{{containerGridWidth}} F{{sgFrameW}}') }
    $controlStyles += @{ target = 'SystemTray.DateTimeIconContent > Grid#ContainerGrid > StackPanel > TextBlock#DateInnerTextBlock'; styles = @('Text=R{{sgRootW}} I{{sgRepW}}') }
}

Set-WindhawkMod 'windows-11-taskbar-styler' -Settings @{ theme = 'LiquidGlass2' } -ControlStyles $controlStyles
