# Renders res\SaiyanGlass.ico (a glass orb with a gold-to-blue core) at the
# usual icon sizes, stored as PNG frames.
param([string]$Out = (Join-Path (Split-Path $PSScriptRoot) 'res\SaiyanGlass.ico'))
Add-Type -AssemblyName System.Drawing

function Frame([int]$s) {
    $bmp = New-Object System.Drawing.Bitmap $s, $s
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'
    $r = [single]($s * 0.22)
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2; $w = $s - 1
    $path.AddArc(0, 0, $d, $d, 180, 90); $path.AddArc($w - $d, 0, $d, $d, 270, 90)
    $path.AddArc($w - $d, $w - $d, $d, $d, 0, 90); $path.AddArc(0, $w - $d, $d, $d, 90, 90); $path.CloseFigure()
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Point 0, 0), (New-Object System.Drawing.Point $s, $s), ([System.Drawing.Color]::FromArgb(255, 30, 32, 40)), ([System.Drawing.Color]::FromArgb(255, 12, 13, 18))
    $g.FillPath($bg, $path)
    $m = $s * 0.18; $o = $s - 2 * $m
    $orb = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.PointF $m, $m), (New-Object System.Drawing.PointF ($s - $m), ($s - $m)), ([System.Drawing.Color]::FromArgb(255, 255, 201, 74)), ([System.Drawing.Color]::FromArgb(255, 58, 184, 255))
    $g.FillEllipse($orb, $m, $m, $o, $o)
    $hl = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, 255, 255, 255))
    $g.FillEllipse($hl, $m + $o * 0.18, $m + $o * 0.1, $o * 0.5, $o * 0.28)
    if ($s -ge 32) {
        $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(70, 255, 255, 255)), ([single][Math]::Max(1, $s / 64))
        $g.DrawPath($pen, $path)
    }
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    , $ms.ToArray()
}

$sizes = 16, 24, 32, 48, 64, 256
$frames = $sizes | ForEach-Object { , (Frame $_) }
$fs = [System.IO.File]::Create($Out); $bw = New-Object System.IO.BinaryWriter $fs
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]; $b = if ($s -ge 256) { 0 } else { $s }
    $bw.Write([byte]$b); $bw.Write([byte]$b); $bw.Write([byte]0); $bw.Write([byte]0)
    $bw.Write([uint16]1); $bw.Write([uint16]32); $bw.Write([uint32]$frames[$i].Length); $bw.Write([uint32]$offset)
    $offset += $frames[$i].Length
}
foreach ($f in $frames) { $bw.Write($f) }
$bw.Close(); "Saved $Out"