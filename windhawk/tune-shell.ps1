# File Explorer, its right-click menu (the desktop's too) and the quick settings
# and notification panels: Windhawk's LiquidGlass themes, recolored with the
# taskbar's glass. Runs elevated.
. "$PSScriptRoot\glass.ps1"

# Light bubbles for items, dark glass for anything with text on it.
$itemConstants = @(
    "ElementBackground=$Bubble",
    "ElementBackground2=$Bubble",
    "ElementBorderBrush=$BubbleEdge",
    'ElementBorderThickness=1'
)
$menuStyles = @("Background:=$GlassPanel", 'BorderThickness=1', "BorderBrush:=$BubbleEdge", 'CornerRadius=14')

# The whole window gets acrylic (the mod redraws the file list's text for it),
# the theme makes the bars transparent on top of it.
Set-WindhawkMod 'windows-11-file-explorer-styler' -Settings @{
    theme = 'LiquidGlass'
    backgroundTranslucentEffect = 'acrylic'
    backgroundTranslucentEffectRegion = ''
} -Constants ($itemConstants + @(
    "AccentBackground=$BubbleHover",
    "ButtonBackground2=$BubblePressed",
    # The theme refers to this name without defining it.
    "ElementBorder=$BubbleEdge",
    'ElementCornerRadius=10'
)) -ControlStyles @(
    @{ target = 'Microsoft.UI.Xaml.Controls.Primitives.CommandBarFlyoutCommandBar > Grid#LayoutRoot > Grid#OuterContentRoot > Grid#ContentRoot > Grid#PrimaryItemsRoot'; styles = $menuStyles },
    @{ target = 'Grid#OuterOverflowContentRootV2'; styles = @('CornerRadius=14') },
    @{ target = 'Grid#OuterOverflowContentRootV2 > Grid#OverflowContentRoot > CommandBarOverflowPresenter#SecondaryItemsControl > Grid#LayoutRoot'; styles = $menuStyles },
    # Same target as the theme's, which would otherwise give the menu a bubble.
    @{ target = 'CommandBarOverflowPresenter#SecondaryItemsControl > Grid#LayoutRoot'; styles = $menuStyles },
    @{ target = 'MenuFlyoutPresenter > Border'; styles = $menuStyles }
)

Set-WindhawkMod 'windows-11-notification-center-styler' -Settings @{ theme = 'LiquidGlass' } -Constants ($itemConstants + @(
    "Background=$GlassPanel",
    "BorderBrush=$BubbleEdge",
    'BorderThickness=1',
    'CornerRadius=18',
    'ElementCornerRadius=12'
))
