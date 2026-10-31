# File Explorer, its right-click menu (the desktop's too), and the quick
# settings, notification, calendar and jump list panels: Windhawk's LiquidGlass
# themes, restyled with the tokens from glass.ps1. Runs elevated.
. "$PSScriptRoot\glass.ps1"

$menu = Get-SurfaceStyles $Radius.Menu
$rimStyles = @("BorderBrush:=$Rim", "BorderThickness=$RimThickness")
$rows = @{ target = 'MenuFlyoutItem > Grid#LayoutRoot@CommonStates, MenuFlyoutSubItem > Grid#LayoutRoot@CommonStates, ToggleMenuFlyoutItem > Grid#LayoutRoot@CommonStates'; styles = Get-RowStyles }
$rowText = @{ target = 'MenuFlyoutItem, MenuFlyoutSubItem, ToggleMenuFlyoutItem'; styles = @("FontWeight=$TextWeight", "CornerRadius=$($Radius.Row)") }

# The whole window gets acrylic (the mod redraws the file list's text for it),
# the theme makes the bars transparent on top of it. Sidebar items, tabs and the
# bars are rows; the address bar and search box are capsules.
$capsule = 'CornerRadius=16'  # half the 32px bar
$overflow = 'CommandBarOverflowPresenter#SecondaryItemsControl > Grid#LayoutRoot'
Set-WindhawkMod 'windows-11-file-explorer-styler' -Settings @{
    theme = 'LiquidGlass'
    backgroundTranslucentEffect = $Tokens.ExplorerBackdrop
    backgroundTranslucentEffectRegion = ''
} -Constants @(
    "ElementBackground=$Bubble",
    "ElementBackground2=$Bubble",
    "ElementBorderBrush=$Rim",
    # The theme refers to this name without defining it.
    "ElementBorder=$Rim",
    "ElementBorderThickness=$RimThickness",
    "AccentBackground=$BubbleHover",
    "ButtonBackground2=$BubblePressed",
    "ElementCornerRadius=$($Radius.Row)"
) -ControlStyles @(
    # The right-click menu, in Explorer and on the desktop.
    @{ target = "Microsoft.UI.Xaml.Controls.Primitives.CommandBarFlyoutCommandBar > Grid#LayoutRoot > Grid#OuterContentRoot > Grid#ContentRoot > Grid#PrimaryItemsRoot"; styles = $menu },
    @{ target = 'Grid#OuterOverflowContentRootV2'; styles = @("CornerRadius=$($Radius.Menu)") },
    @{ target = "Grid#OuterOverflowContentRootV2 > Grid#OverflowContentRoot > $overflow"; styles = $menu },
    # Same target as the theme's, which would otherwise give the menu a bubble.
    @{ target = $overflow; styles = $menu },
    @{ target = 'Microsoft.UI.Xaml.Controls.AppBarButton, Microsoft.UI.Xaml.Controls.AppBarToggleButton'; styles = @("FontWeight=$TextWeight") },
    # Other menus and tooltips.
    @{ target = 'MenuFlyoutPresenter'; styles = @("CornerRadius=$($Radius.Menu)") },
    @{ target = 'MenuFlyoutPresenter > Border'; styles = $menu },
    $rowText,
    $rows,
    @{ target = 'ToolTip'; styles = @("Background:=$Glass", "FontWeight=$TextWeight") + $rimStyles },
    # Tabs: the open tab is the bubble, the others are rows.
    @{ target = 'TabViewItem > Grid#LayoutRoot@CommonStates'; styles = @('Background@Normal:=Transparent', "Background@PointerOver:=$Bubble", "Background@Selected:=$Bubble", "Background@PointerOverSelected:=$BubbleHover", "Background@PressedSelected:=$BubblePressed") },
    @{ target = 'Microsoft.UI.Xaml.Controls.Grid#FileExplorerAddressBarGrid'; styles = @($capsule) },
    @{ target = 'Microsoft.UI.Xaml.Controls.AutoSuggestBox#FileExplorerSearchBox > Microsoft.UI.Xaml.Controls.Grid#LayoutRoot > Microsoft.UI.Xaml.Controls.TextBox#TextBox'; styles = @($capsule) },
    @{ target = 'Microsoft.UI.Xaml.Controls.AutoSuggestBox#PART_AutoSuggestBox > Microsoft.UI.Xaml.Controls.Grid#LayoutRoot > Microsoft.UI.Xaml.Controls.TextBox#TextBox'; styles = @($capsule) }
)

# Panels get the panel radius and the rim; cards, toasts, jump lists and menus
# the menu radius; tiles and buttons the item radius. No accent color: hover
# is the brighter bubble. The theme's display fonts give way to the system font.
$font = "FontFamily=$($Tokens.FontFamily)"
Set-WindhawkMod 'windows-11-notification-center-styler' -Settings @{ theme = 'LiquidGlass' } -Constants @(
    "Background=$GlassPanel",
    "ElementBackground=$Bubble",
    "ElementBackground2=$Bubble",
    "AccentBackground=$BubbleHover",
    "BorderBrush=$Rim",
    "ElementBorderBrush=$Rim",
    "BorderThickness=$RimThickness",
    "ElementBorderThickness=$RimThickness",
    "CornerRadius=$($Radius.Menu)",
    "ElementCornerRadius=$($Radius.Item)"
) -ControlStyles @(
    @{ target = 'Grid#NotificationCenterGrid, Grid#CalendarCenterGrid'; styles = @("CornerRadius=$($Radius.Panel)") },
    @{ target = 'Grid#ControlCenterRegion, Windows.UI.Xaml.Controls.Grid#MediaTransportControlsRegion'; styles = @("CornerRadius=$($Radius.Panel)") + $rimStyles },
    @{ target = 'Border#ToastBackgroundBorder, Border#ToastBackgroundBorder2'; styles = $rimStyles },
    @{ target = 'JumpViewUI.SystemItemListViewItem > Grid#LayoutRoot > Border#BackgroundBorder, JumpViewUI.JumpListListViewItem > Grid#LayoutRoot > Border#BackgroundBorder'; styles = @("CornerRadius=$($Radius.Row)") },
    $rowText,
    $rows,
    # The theme tints these with the accent color.
    @{ target = 'Windows.UI.Xaml.Controls.Grid#RootGrid > Windows.UI.Xaml.Controls.ContentPresenter#ContentPresenter, Windows.UI.Xaml.Controls.Grid#WeekDayNames'; styles = @("Background:=$Bubble") },
    @{ target = 'Windows.UI.Xaml.Controls.StackPanel#PrimaryAndSecondaryTextContainer > Windows.UI.Xaml.Controls.TextBlock#Title'; styles = @($font, "FontWeight=$TextWeight") },
    @{ target = 'Windows.UI.Xaml.Controls.StackPanel#PrimaryAndSecondaryTextContainer > Windows.UI.Xaml.Controls.TextBlock#Subtitle, Windows.UI.Xaml.Controls.TextBlock#AppNameText'; styles = @($font) },
    # Sliders and switches are pills, their knobs round.
    @{ target = 'Windows.UI.Xaml.Shapes.Rectangle#HorizontalTrackRect, Windows.UI.Xaml.Shapes.Rectangle#HorizontalDecreaseRect'; styles = @('RadiusX=5', 'RadiusY=5') },
    @{ target = 'Windows.UI.Xaml.Shapes.Rectangle#OuterBorder, Windows.UI.Xaml.Shapes.Rectangle#SwitchKnobBounds'; styles = @('RadiusX=9', 'RadiusY=9') },
    @{ target = 'Windows.UI.Xaml.Shapes.Rectangle#SwitchKnobOff'; styles = @('RadiusX=7', 'RadiusY=7') },
    @{ target = 'Windows.UI.Xaml.Controls.Border#SwitchKnobOn'; styles = @('CornerRadius=7') }
)
