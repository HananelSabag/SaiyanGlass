# Renders a contact sheet of every analyzed wallpaper with its derived accent,
# glass tint and detected family, for checking the analysis by eye.
param([string]$Out = (Join-Path $PSScriptRoot '.cache\contact-sheet.png'))

Add-Type -AssemblyName System.Drawing
$js = Get-Content (Join-Path $PSScriptRoot 'wallpapers.local.js') -Raw
$items = ($js -replace '^\s*window\.WALLPAPERS = ', '' -replace ';\s*$', '') | ConvertFrom-Json

$tw = 320; $th = 180; $label = 34; $cols = 5
$rows = [Math]::Ceiling($items.Count / $cols)
$bmp = New-Object System.Drawing.Bitmap ($cols * $tw), ($rows * ($th + $label))
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'ClearTypeGridFit'
$g.Clear([System.Drawing.Color]::FromArgb(18, 18, 20))
$font = New-Object System.Drawing.Font 'Segoe UI', 9
$white = [System.Drawing.Brushes]::Gainsboro

for ($i = 0; $i -lt $items.Count; $i++) {
    $it = $items[$i]
    $x = ($i % $cols) * $tw; $y = [Math]::Floor($i / $cols) * ($th + $label)
    $img = [System.Drawing.Image]::FromFile((Join-Path $PSScriptRoot $it.preview))
    $g.DrawImage($img, $x, $y, $tw, $th); $img.Dispose()
    $acc = [System.Drawing.ColorTranslator]::FromHtml($it.accent)
    $tint = [System.Drawing.ColorTranslator]::FromHtml($it.tint)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $tint), $x, ($y + $th), $tw, $label)
    $g.FillRectangle((New-Object System.Drawing.SolidBrush $acc), ($x + 6), ($y + $th + 7), 20, 20)
    $name = $it.file -replace '\.(png|jpe?g)$', ''
    if ($name.Length -gt 30) { $name = $name.Substring(0, 30) }
    $g.DrawString(("{0}  {1} {2:N0}° c{3:N2}" -f $name, $it.family, $it.rawHue, $it.confidence), $font, $white, ($x + 32), ($y + $th + 9))
}
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
"Saved $Out"