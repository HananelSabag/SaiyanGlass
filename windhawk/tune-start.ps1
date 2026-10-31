# Start and its search on the LiquidGlass2 theme, brought in line with the rest:
# the same dark glass and rim as the quick settings and the menus, the panel
# radius instead of the theme's 50-62px, the nested glass containers
# flattened, and bubbles (not scaling) for hover. Runs elevated.
. "$PSScriptRoot\glass.ps1"

$rimStyles = @("BorderBrush:=$Rim", "BorderThickness=$RimThickness")
$bubbleStyles = @("Background:=$Bubble") + $rimStyles
$noGrow = "RenderTransform@PointerOver:=<ScaleTransform ScaleX=`"1`" ScaleY=`"1`"/>"
$flat = @('Background:=Transparent', 'BorderThickness=0')

# The theme's own constants, redefined: they reach every target that uses them.
$constants = @(
    "GlassDark=$GlassPanel",          # the menu, the side panel, menus, tooltips
    "GlassDark2=$GlassPanel",         # an open folder
    "GlassDarkSearchPage=$GlassPanel",
    "GlassDarkBottomTray=$Glass",     # the account and power bar floats over the list: a capsule
    "BorderBrush=$Rim",
    "BorderThickness=$RimThickness",
    "CornerRadius=$($Radius.Panel)",
    "fluidBorder=$Rim"
)

$controlStyles = @(
    # The menu: one panel of glass with the rim, and no glow ring around it.
    @{ target = 'Border#AcrylicBorder'; styles = @("CornerRadius=$($Radius.Panel)") },
    @{ target = 'Grid#Root > Border'; styles = $rimStyles + @("CornerRadius=$($Radius.Panel)") },
    @{ target = 'StartMenu.StartHome > Grid#PageRoot, Border#LayerBorder, Border#RootGridDropShadow, Border#TaskbarSearchBackground, Windows.UI.Xaml.PopupRoot'; styles = @("CornerRadius=$($Radius.Panel)") },
    @{ target = 'Border#StartDropShadow'; styles = @('Visibility=Collapsed') },
    @{ target = 'StartMenu.StartMenuCompanion#RightCompanion > Grid#CompanionRoot > Border#AcrylicBorder, Grid#CompanionRoot > Border#AcrylicOverlay, Border#RightCompanionDropShadow, Border#dropshadow'; styles = @("CornerRadius=$($Radius.Panel)") },
    @{ target = 'Border#AppBorder'; styles = $rimStyles + @("CornerRadius=$($Radius.Panel)") },
    @{ target = 'Windows.UI.Xaml.Controls.ContentDialog'; styles = Get-SurfaceStyles $Radius.Panel },

    # Containers inside the panel are flat; items carry the bubbles.
    @{ target = 'StartMenu.PinnedList#StartMenuPinnedList > Grid#Root > GridView#PinnedList > Border'; styles = $flat },
    @{ target = 'StartMenu.CategoryControl > Grid#RootGrid > Border'; styles = $bubbleStyles + @("CornerRadius=$($Radius.Menu)") },
    @{ target = 'Grid#NavPanePlaceholder'; styles = $rimStyles },

    # Section headers: bubble capsules with bold labels.
    @{ target = 'GridViewHeaderItem > Border > ContentPresenter#ContentPresenter > Button#Header > Border#Border'; styles = $bubbleStyles },
    @{ target = 'Grid#TopLevelSuggestionsListHeader, Grid#AllListHeading, Grid#MoreSuggestionsRoot > Grid[1]'; styles = $bubbleStyles },
    @{ target = 'TextBlock#AllListHeadingText, TextBlock#MoreSuggestionsListHeaderText, TextBlock#PinnedListHeaderText'; styles = @("FontWeight=$TextWeight") },

    # Tiles and list items: a bubble on hover, no scaling.
    @{ target = 'Grid#DroppedFlickerWorkaroundWrapper > Border#BackgroundBorder'; styles = @("Background@PointerOver:=$Bubble", "Background@Pressed:=$BubblePressed", "Background@Selected:=$Bubble") },
    @{ target = 'Border#BackgroundBorder'; styles = @("CornerRadius=$($Radius.Item)") },
    @{ target = 'Border#ContentBorder@CommonStates > Grid > Border#BackgroundBorder'; styles = @("BorderThickness=$RimThickness", "CornerRadius=$($Radius.Item)") },
    @{ target = 'ListViewItem > Grid@CommonStates > Border#BorderBackground'; styles = @("CornerRadius=$($Radius.Item)") },

    # Buttons and folders: bubbles at rest, brighter on hover, dimmer pressed.
    @{ target = 'Microsoft.UI.Xaml.Controls.DropDownButton > Grid@CommonStates'; styles = @(Get-BubbleStyles -States) + $noGrow },
    @{ target = 'Button#AddButton'; styles = @("Background:=$Bubble", "CornerRadius=$($Radius.Item)") },
    @{ target = 'Button#FolderPlate > Grid@CommonStates'; styles = @($noGrow) },
    @{ target = 'Button#FolderPlate > Grid@CommonStates > Border'; styles = @("Background@Normal:=$Bubble", "Background@PointerOver:=$BubbleHover", "Background@Pressed:=$BubblePressed", "BorderBrush:=$Rim", "CornerRadius=$($Radius.Item)") },
    @{ target = 'Border#FolderPlate'; styles = $bubbleStyles + @("CornerRadius=$($Radius.Item)") },
    @{ target = 'Button#ShowMoreSuggestionsButton > Grid@CommonStates'; styles = @(Get-BubbleStyles -States $Radius.Menu) + $noGrow },
    @{ target = 'Button#HideMoreSuggestionsButton > Grid@CommonStates'; styles = @($noGrow) },
    @{ target = 'Button#HideMoreSuggestionsButton > Grid@CommonStates > Border#BackgroundBorder'; styles = @(Get-BubbleStyles -States $Radius.Menu) },
    @{ target = 'Button#PrimaryButton@CommonStates'; styles = @(Get-BubbleStyles -States) + @("BorderBrush@PointerOver:=$Rim", "BorderBrush@Pressed:=$Rim", "FontWeight=$TextWeight") },
    @{ target = 'Button#SecondaryButton, Button#CloseButton'; styles = @(Get-BubbleStyles) + @("FontWeight=$TextWeight") },

    # Search boxes: bubble capsules, without the theme's dark inset.
    @{ target = 'StartMenu.SearchBoxToggleButton#SearchBoxToggleButton > Grid'; styles = $bubbleStyles },
    @{ target = 'StartMenu.SearchBoxToggleButton#SearchBoxToggleButton > Grid@CommonStates > Border#BorderElement'; styles = @('Background:=Transparent') },
    @{ target = 'Cortana.UI.Views.CortanaRichSearchBox#SearchTextBox > Grid@CommonStates > Border#BorderElement'; styles = @('Background:=Transparent') + $rimStyles },
    @{ target = 'Cortana.UI.Views.RichSearchBoxControl#SearchBoxControl > Grid#RootGrid'; styles = @("Background:=$Bubble") },
    @{ target = 'TextBox#MutableFolderNameTextBox > Grid@CommonStates > Border#BorderElement'; styles = $bubbleStyles },

    # Menus and tooltips, as on the taskbar.
    @{ target = 'MenuFlyoutPresenter, FlyoutPresenter'; styles = @("CornerRadius=$($Radius.Menu)") },
    @{ target = 'MenuFlyoutPresenter > Border'; styles = @("BorderBrush:=$Rim", "CornerRadius=$($Radius.Menu)") },
    @{ target = 'MenuFlyoutItem, MenuFlyoutSubItem, ToggleMenuFlyoutItem'; styles = @("FontWeight=$TextWeight", "CornerRadius=$($Radius.Row)") },
    @{ target = 'MenuFlyoutItem > Grid#LayoutRoot@CommonStates, MenuFlyoutSubItem > Grid#LayoutRoot@CommonStates, ToggleMenuFlyoutItem > Grid#LayoutRoot@CommonStates'; styles = Get-RowStyles },
    @{ target = 'ToolTip > ContentPresenter#LayoutRoot'; styles = @("Background:=$Glass", "BorderBrush:=$Rim", "FontWeight=$TextWeight") }
)

# Search results are web content: the same tokens as CSS.
$groupTitle = @("background: $($Css.Bubble) !important", "border: $($Css.Rim) !important")
$webStyles = @(
    @{ target = '.groupContainer:first-of-type .groupTitle, .groupContainer:nth-of-type(2) .groupTitle, div[data-region="TopApps"] .groupTitle, .groupContainer:nth-of-type(3) .groupTitle'; styles = $groupTitle + @('font-weight: 600 !important') },
    @{ target = '.groupContainer:nth-of-type(2) .suggsList, div[data-region="QuickActionList"] .suggsList, div[data-region="TrendingWebSearches"] .suggsList'; styles = @("background: $($Css.Bubble) !important", "border: $($Css.RimSoft) !important", "border-radius: $($Radius.Menu)px !important") },
    @{ target = '.groupContainer:nth-of-type(2) .suggestion'; styles = @('background: transparent !important', 'border: none !important', "border-radius: $($Radius.Row)px !important") },
    @{ target = 'div[data-region="TopApps"] .suggestion, .groupContainer:nth-of-type(3) .suggestion'; styles = @("background: $($Css.Bubble) !important", "border: $($Css.RimSoft) !important", "border-radius: $($Radius.Item)px !important") }
)

Set-WindhawkMod 'windows-11-start-menu-styler' -Settings @{ theme = 'LiquidGlass2' } -Constants $constants -ControlStyles $controlStyles -WebStyles $webStyles
