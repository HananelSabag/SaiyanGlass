# The SaiyanGlass design tokens: the one place that sets how every surface
# looks (taskbar, Start, File Explorer, the menus, quick settings and
# notifications, the flyouts, the desktop icons). Every other script reads
# from here; change a value here and re-run apply-look.ps1.
#
# Roles:
#   Glass   dark glass behind anything with text, so white text reads on any
#           wallpaper (a 70% tint gives about 3:1 on white, with SemiBold).
#   Clear   nearly clear glass for surfaces that hold only icons (the dock).
#   Bubble  light glass that marks an item: controls and the app icons on the
#           dock and the desktop carry one at rest; rows in lists and menus
#           get one on hover.
#   Rim     the one edge: bright top, faint sides, soft bottom. Every glass
#           surface and every bubble has it, 1px.
$Tokens = [ordered]@{
    GlassTint       = '#B30B0C10'
    GlassSaturation = 1.3
    BlurSmall       = 10    # capsules, tooltips
    BlurLarge       = 18    # panels, menus, flyouts
    ClearTint       = '#14090909'
    ClearBlur       = 3
    ClearSaturation = 1.2
    # Top and bottom of the bubble's gradient, by state.
    BubbleRest      = '#30FFFFFF', '#12FFFFFF'
    BubbleHover     = '#4AFFFFFF', '#22FFFFFF'
    BubblePressed   = '#1AFFFFFF'
    # Rim stops: color, offset.
    Rim             = @('#90FFFFFF', 0), @('#1AFFFFFF', 0.45), @('#45FFFFFF', 1)
    RimThickness    = 1
    # Corner radius by element size. Capsules (taskbar capsules, tooltips,
    # search boxes, headers) are always pills: half their height.
    RadiusPanel     = 24    # Start, notification center, quick settings, dialogs, Alt+Tab
    RadiusMenu      = 16    # menus, jump lists, flyouts, previews, toasts, cards
    RadiusItem      = 12    # bubbles: dock icons, tiles, buttons, desktop icons
    RadiusRow       = 8     # rows: menu items, list items, tabs, nav items
    ItemSize        = 40    # the dock bubble's height, for the desktop icon's radius
    TextWeight      = 'SemiBold'
    FontFamily      = 'Segoe UI Variable Text'
    # The desktop icon has no glass behind it, so its bubble brings its own: a
    # base of dark glass, fill and rim a third stronger, a sheen on the top
    # half, a soft shadow and a dark hairline that holds it on white wallpapers.
    DesktopBase     = 0x24
    DesktopLift     = 1.33
    DesktopSheen    = 0x30
    DesktopHairline = 0x38
}

function New-Blur([int]$Blur, [string]$Tint, [double]$Saturation) {
    "<WindhawkBlur BlurAmount=`"$Blur`" TintColor=`"$Tint`" TintSaturation=`"$Saturation`"/>"
}
function New-Gradient([object[]]$Stops) {
    $s = foreach ($stop in $Stops) { "<GradientStop Color=`"$($stop[0])`" Offset=`"$($stop[1])`"/>" }
    "<LinearGradientBrush StartPoint=`"0,0`" EndPoint=`"0,1`">$($s -join '')</LinearGradientBrush>"
}

$Glass = New-Blur $Tokens.BlurSmall $Tokens.GlassTint $Tokens.GlassSaturation
$GlassPanel = New-Blur $Tokens.BlurLarge $Tokens.GlassTint $Tokens.GlassSaturation
$GlassClear = New-Blur $Tokens.ClearBlur $Tokens.ClearTint $Tokens.ClearSaturation
$Bubble = New-Gradient (@($Tokens.BubbleRest[0], 0), @($Tokens.BubbleRest[1], 1))
$BubbleHover = New-Gradient (@($Tokens.BubbleHover[0], 0), @($Tokens.BubbleHover[1], 1))
$BubblePressed = "<SolidColorBrush Color=`"$($Tokens.BubblePressed)`"/>"
$Rim = New-Gradient $Tokens.Rim
$RimThickness = $Tokens.RimThickness
$Radius = @{ Panel = $Tokens.RadiusPanel; Menu = $Tokens.RadiusMenu; Item = $Tokens.RadiusItem; Row = $Tokens.RadiusRow }
$TextWeight = $Tokens.TextWeight

# The same tokens for the web content of Start's search results.
function ConvertTo-Rgba([string]$argb) {
    $a = [Convert]::ToInt32($argb.Substring(1, 2), 16) / 255
    $r, $g, $b = 3, 5, 7 | ForEach-Object { [Convert]::ToInt32($argb.Substring($_, 2), 16) }
    [string]::Format([Globalization.CultureInfo]::InvariantCulture, 'rgba({0}, {1}, {2}, {3:0.##})', $r, $g, $b, $a)
}
$Css = @{
    Glass = ConvertTo-Rgba $Tokens.GlassTint
    Bubble = "linear-gradient($(ConvertTo-Rgba $Tokens.BubbleRest[0]), $(ConvertTo-Rgba $Tokens.BubbleRest[1]))"
    BubbleHover = "linear-gradient($(ConvertTo-Rgba $Tokens.BubbleHover[0]), $(ConvertTo-Rgba $Tokens.BubbleHover[1]))"
    Rim = "$($Tokens.RimThickness)px solid $(ConvertTo-Rgba $Tokens.Rim[0][0])"
    RimSoft = "$($Tokens.RimThickness)px solid $(ConvertTo-Rgba $Tokens.Rim[2][0])"
}

# Style lists for the roles, for a Border-like target (Background, BorderBrush,
# CornerRadius). States need the target to name its visual state group
# (Target@CommonStates).
function Get-SurfaceStyles([int]$CornerRadius, [string]$Material = $GlassPanel) {
    "Background:=$Material", "BorderBrush:=$Rim", "BorderThickness=$RimThickness", "CornerRadius=$CornerRadius"
}
function Get-BubbleStyles([int]$CornerRadius = $Radius.Item, [switch]$States) {
    "Background:=$Bubble", "BorderBrush:=$Rim", "BorderThickness=$RimThickness", "CornerRadius=$CornerRadius"
    if ($States) { "Background@PointerOver:=$BubbleHover", "Background@Pressed:=$BubblePressed" }
}
# A row: no bubble at rest, one on hover.
function Get-RowStyles([int]$CornerRadius = $Radius.Row) {
    "CornerRadius=$CornerRadius", "Background@PointerOver:=$Bubble", "Background@Pressed:=$BubblePressed"
}

# Writes a styler mod's settings and makes Windhawk reload them. Windhawk keeps
# mod settings under HKLM, so callers run elevated.
function Set-WindhawkMod {
    param([string]$Mod, [hashtable]$Settings = @{}, [string[]]$Constants = @(), [object[]]$ControlStyles = @(), [object[]]$WebStyles = @())
    $root = "SOFTWARE\Windhawk\Engine\Mods\$Mod"
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("$root\Settings", $true)
    if (-not $key) { throw "The Windhawk mod $Mod is not installed" }
    foreach ($name in $key.GetValueNames()) {
        if ($name -like 'controlStyles*' -or $name -like 'styleConstants*' -or $name -like 'webContentStyles*') { $key.DeleteValue($name) }
    }
    foreach ($name in $Settings.Keys) { $key.SetValue($name, $Settings[$name], 'String') }
    for ($i = 0; $i -lt $Constants.Count; $i++) { $key.SetValue("styleConstants[$i]", $Constants[$i], 'String') }
    foreach ($list in @{ name = 'controlStyles'; items = $ControlStyles }, @{ name = 'webContentStyles'; items = $WebStyles }) {
        for ($i = 0; $i -lt $list.items.Count; $i++) {
            $key.SetValue("$($list.name)[$i].target", $list.items[$i].target, 'String')
            $styles = @($list.items[$i].styles)
            for ($j = 0; $j -lt $styles.Count; $j++) { $key.SetValue("$($list.name)[$i].styles[$j]", $styles[$j], 'String') }
        }
    }
    $key.Close()
    # Windhawk reloads a mod's settings when this timestamp changes.
    $modKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($root, $true)
    $modKey.SetValue('SettingsChangeTime', [int][DateTimeOffset]::UtcNow.ToUnixTimeSeconds(), 'DWord')
    $modKey.Close()
}
