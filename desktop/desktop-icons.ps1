# Puts every desktop shortcut and folder, and the Recycle Bin, on a glass bubble
# like the app icons on the taskbar, and hides the shortcut arrow. The icons are
# rendered once into %LOCALAPPDATA%\SaiyanGlass\desktop-icons, so nothing runs
# afterwards. Runs elevated: the Public Desktop and the arrow are machine-wide.
#   -Restore  puts every original icon back
param([switch]$Restore)

$store = Join-Path $env:LOCALAPPDATA 'SaiyanGlass\desktop-icons'
# Part of each icon's file name: bump it when the bubble changes, so Explorer's
# icon cache can't keep showing the old one.
$design = 'v1'
$backupFile = Join-Path $store 'backup.json'
$recycleBin = '{645FF040-5081-101B-9F08-00AA002F954E}'
$recycleBinKey = "Software\Microsoft\Windows\CurrentVersion\Explorer\CLSID\$recycleBin\DefaultIcon"
$shellIconsKey = 'SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Shell Icons'

Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Text;

public static class GlassIcons {
    [StructLayout(LayoutKind.Sequential)] struct SIZE { public int cx, cy; }
    [StructLayout(LayoutKind.Sequential)] struct BITMAP { public int bmType, bmWidth, bmHeight, bmWidthBytes; public ushort bmPlanes, bmBitsPixel; public IntPtr bmBits; }
    [StructLayout(LayoutKind.Sequential)] struct BITMAPINFOHEADER { public int biSize, biWidth, biHeight; public short biPlanes, biBitCount; public int biCompression, biSizeImage, biXPelsPerMeter, biYPelsPerMeter, biClrUsed, biClrImportant; }

    [ComImport, Guid("bcc18b79-ba16-442f-80c4-8a59c30c463b"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellItemImageFactory { [PreserveSig] int GetImage(SIZE size, int flags, out IntPtr phbm); }

    [ComImport, Guid("000214F9-0000-0000-C000-000000000046"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    interface IShellLinkW {
        void GetPath([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile, int cch, IntPtr pfd, uint fFlags);
        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);
        void GetDescription([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName, int cch);
        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);
        void GetWorkingDirectory([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir, int cch);
        void SetWorkingDirectory([MarshalAs(UnmanagedType.LPWStr)] string pszDir);
        void GetArguments([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs, int cch);
        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);
        void GetIconLocation([Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath, int cch, out int piIcon);
        void SetIconLocation([MarshalAs(UnmanagedType.LPWStr)] string pszIconPath, int iIcon);
        void SetRelativePath([MarshalAs(UnmanagedType.LPWStr)] string pszPathRel, uint dwReserved);
        void Resolve(IntPtr hwnd, uint fFlags);
        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }
    [ComImport, Guid("00021401-0000-0000-C000-000000000046")] class CShellLink { }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, PreserveSig = false)]
    static extern void SHCreateItemFromParsingName(string path, IntPtr pbc, [In] ref Guid riid, [MarshalAs(UnmanagedType.Interface)] out IShellItemImageFactory ppv);
    [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern void SHChangeNotify(int eventId, uint flags, string item1, IntPtr item2);
    [DllImport("gdi32.dll")] static extern int GetObject(IntPtr h, int c, ref BITMAP bm);
    [DllImport("gdi32.dll")] static extern int GetDIBits(IntPtr hdc, IntPtr hbm, uint start, uint lines, [Out] byte[] bits, ref BITMAPINFOHEADER bmi, uint usage);
    [DllImport("gdi32.dll")] static extern bool DeleteObject(IntPtr h);
    [DllImport("user32.dll")] static extern IntPtr GetDC(IntPtr hwnd);
    [DllImport("user32.dll")] static extern int ReleaseDC(IntPtr hwnd, IntPtr dc);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] static extern uint PrivateExtractIcons(string file, int index, int cx, int cy, IntPtr[] icons, int[] ids, uint count, uint flags);
    [DllImport("user32.dll")] static extern bool DestroyIcon(IntPtr h);

    // The icon Explorer shows for a file, link or folder, without overlays.
    public static Bitmap ShellImage(string path, int size) {
        Guid iid = typeof(IShellItemImageFactory).GUID;
        IShellItemImageFactory factory;
        SHCreateItemFromParsingName(path, IntPtr.Zero, ref iid, out factory);
        IntPtr hbm;
        int hr = factory.GetImage(new SIZE { cx = size, cy = size }, 0x4 /* SIIGBF_ICONONLY */, out hbm);
        Marshal.ReleaseComObject(factory);
        if (hr != 0) Marshal.ThrowExceptionForHR(hr);
        try { return FromHBitmap(hbm); } finally { DeleteObject(hbm); }
    }

    // An icon from a "file,index" location (a negative index is a resource id).
    public static Bitmap ResourceIcon(string file, int index, int size) {
        var icons = new IntPtr[1];
        var ids = new int[1];
        if (PrivateExtractIcons(Environment.ExpandEnvironmentVariables(file), index, size, size, icons, ids, 1, 0) == 0 || icons[0] == IntPtr.Zero)
            throw new FileNotFoundException("No icon " + index + " in " + file);
        try { using (var icon = Icon.FromHandle(icons[0])) return icon.ToBitmap(); } finally { DestroyIcon(icons[0]); }
    }

    // Shell bitmaps carry premultiplied alpha, which Image.FromHbitmap drops.
    static Bitmap FromHBitmap(IntPtr hbm) {
        var bm = new BITMAP();
        GetObject(hbm, Marshal.SizeOf(typeof(BITMAP)), ref bm);
        int w = bm.bmWidth, h = bm.bmHeight;
        var header = new BITMAPINFOHEADER { biSize = 40, biWidth = w, biHeight = -h, biPlanes = 1, biBitCount = 32 };
        var bits = new byte[w * h * 4];
        IntPtr dc = GetDC(IntPtr.Zero);
        GetDIBits(dc, hbm, 0, (uint)h, bits, ref header, 0);
        ReleaseDC(IntPtr.Zero, dc);
        bool hasAlpha = false;
        for (int i = 3; i < bits.Length && !hasAlpha; i += 4) hasAlpha = bits[i] != 0;
        if (!hasAlpha) for (int i = 3; i < bits.Length; i += 4) bits[i] = 255;
        using (var premultiplied = new Bitmap(w, h, PixelFormat.Format32bppPArgb)) {
            var data = premultiplied.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppPArgb);
            Marshal.Copy(bits, 0, data.Scan0, bits.Length);
            premultiplied.UnlockBits(data);
            var result = new Bitmap(w, h, PixelFormat.Format32bppArgb);
            using (var g = Graphics.FromImage(result)) g.DrawImage(premultiplied, 0, 0, w, h);
            return result;
        }
    }

    static GraphicsPath Round(RectangleF r, float radius) {
        var p = new GraphicsPath();
        float d = radius * 2;
        p.AddArc(r.X, r.Y, d, d, 180, 90);
        p.AddArc(r.Right - d, r.Y, d, d, 270, 90);
        p.AddArc(r.Right - d, r.Bottom - d, d, d, 0, 90);
        p.AddArc(r.X, r.Bottom - d, d, d, 90, 90);
        p.CloseFigure();
        return p;
    }

    // The taskbar bubble at 256px: white glass with a bright top edge, a soft
    // shadow and a dark hairline so it also reads on white wallpapers.
    public static Bitmap Glass(Image icon) {
        const int S = 256;
        const float radius = 62, iconSize = 148;
        var r = new RectangleF(16, 12, 224, 224);
        var bmp = new Bitmap(S, S, PixelFormat.Format32bppArgb);
        using (var g = Graphics.FromImage(bmp))
        using (var bubble = Round(r, radius)) {
            g.SmoothingMode = SmoothingMode.AntiAlias;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;

            for (int i = 1; i <= 10; i++)
                using (var p = Round(new RectangleF(r.X - i, r.Y - i + 6, r.Width + 2 * i, r.Height + 2 * i), radius + i))
                using (var b = new SolidBrush(Color.FromArgb(5, 0, 0, 0)))
                    g.FillPath(b, p);
            // The shadow stays outside: clear it under the glass.
            g.CompositingMode = CompositingMode.SourceCopy;
            using (var b = new SolidBrush(Color.Transparent)) g.FillPath(b, bubble);
            g.CompositingMode = CompositingMode.SourceOver;

            var body = RectangleF.Inflate(r, 0, 1);
            using (var b = new SolidBrush(Color.FromArgb(0x24, 0x0B, 0x0C, 0x10))) g.FillPath(b, bubble);
            using (var b = new LinearGradientBrush(body, Color.FromArgb(0x40, 255, 255, 255), Color.FromArgb(0x14, 255, 255, 255), LinearGradientMode.Vertical))
                g.FillPath(b, bubble);
            g.SetClip(bubble);
            var sheen = new RectangleF(r.X, r.Y, r.Width, r.Height * 0.5f);
            using (var b = new LinearGradientBrush(RectangleF.Inflate(sheen, 0, 1), Color.FromArgb(0x30, 255, 255, 255), Color.FromArgb(0, 255, 255, 255), LinearGradientMode.Vertical))
                g.FillRectangle(b, sheen);
            g.ResetClip();

            g.DrawImage(icon, new RectangleF(r.X + (r.Width - iconSize) / 2, r.Y + (r.Height - iconSize) / 2, iconSize, iconSize));

            using (var outer = Round(RectangleF.Inflate(r, 1, 1), radius + 1))
            using (var pen = new Pen(Color.FromArgb(0x38, 0, 0, 0), 2))
                g.DrawPath(pen, outer);
            using (var inner = Round(RectangleF.Inflate(r, -1.5f, -1.5f), radius - 1.5f))
            using (var edge = new LinearGradientBrush(body, Color.White, Color.White, LinearGradientMode.Vertical)) {
                edge.InterpolationColors = new ColorBlend {
                    Colors = new[] { Color.FromArgb(0xB0, 255, 255, 255), Color.FromArgb(0x24, 255, 255, 255), Color.FromArgb(0x58, 255, 255, 255) },
                    Positions = new[] { 0f, 0.45f, 1f }
                };
                using (var pen = new Pen(edge, 3)) g.DrawPath(pen, inner);
            }
        }
        return bmp;
    }

    // A PNG-compressed .ico with every size Explorer asks for.
    public static void WriteIco(Image master, string path) {
        int[] sizes = { 256, 128, 96, 64, 48, 32, 24, 16 };
        var pngs = new byte[sizes.Length][];
        for (int i = 0; i < sizes.Length; i++) {
            using (var s = new Bitmap(sizes[i], sizes[i], PixelFormat.Format32bppArgb)) {
                using (var g = Graphics.FromImage(s)) {
                    g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                    g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                    g.DrawImage(master, 0, 0, sizes[i], sizes[i]);
                }
                using (var ms = new MemoryStream()) { s.Save(ms, ImageFormat.Png); pngs[i] = ms.ToArray(); }
            }
        }
        WriteIcoFile(path, sizes, pngs);
    }

    // A fully transparent icon in the classic format: empty color bits and an
    // AND mask that keeps everything underneath. Explorer draws the shortcut
    // overlay through the mask, so a PNG blank icon shows up as a black square.
    public static void WriteBlankIco(string path) {
        int[] sizes = { 256, 64, 48, 32, 24, 16 };
        var images = new byte[sizes.Length][];
        for (int i = 0; i < sizes.Length; i++) {
            int s = sizes[i], maskStride = (s + 31) / 32 * 4;
            using (var ms = new MemoryStream())
            using (var w = new BinaryWriter(ms)) {
                w.Write(40); w.Write(s); w.Write(s * 2); w.Write((short)1); w.Write((short)32);
                w.Write(0); w.Write(s * s * 4 + maskStride * s); w.Write(0); w.Write(0); w.Write(0); w.Write(0);
                w.Write(new byte[s * s * 4]);
                var mask = new byte[maskStride * s];
                for (int k = 0; k < mask.Length; k++) mask[k] = 0xFF;
                w.Write(mask);
                w.Flush();
                images[i] = ms.ToArray();
            }
        }
        WriteIcoFile(path, sizes, images);
    }

    static void WriteIcoFile(string path, int[] sizes, byte[][] images) {
        using (var w = new BinaryWriter(File.Create(path))) {
            w.Write((short)0); w.Write((short)1); w.Write((short)sizes.Length);
            int offset = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++) {
                byte dim = (byte)(sizes[i] >= 256 ? 0 : sizes[i]);
                w.Write(dim); w.Write(dim); w.Write((byte)0); w.Write((byte)0);
                w.Write((short)1); w.Write((short)32); w.Write(images[i].Length); w.Write(offset);
                offset += images[i].Length;
            }
            foreach (var image in images) w.Write(image);
        }
    }

    public static string GetLinkIcon(string lnk) {
        var link = (IShellLinkW)new CShellLink();
        try {
            ((IPersistFile)link).Load(lnk, 0);
            var sb = new StringBuilder(1024);
            int index;
            link.GetIconLocation(sb, sb.Capacity, out index);
            return sb + "," + index;
        } finally { Marshal.ReleaseComObject(link); }
    }

    // Changes only the icon; everything else in the shortcut is kept as is.
    public static void SetLinkIcon(string lnk, string file, int index) {
        var link = (IShellLinkW)new CShellLink();
        try {
            var persist = (IPersistFile)link;
            persist.Load(lnk, 2 /* STGM_READWRITE */);
            link.SetIconLocation(file, index);
            persist.Save(lnk, true);
        } finally { Marshal.ReleaseComObject(link); }
        NotifyPath(lnk);
    }

    public static void NotifyPath(string path) { SHChangeNotify(0x2000 /* SHCNE_UPDATEITEM */, 0x5 /* SHCNF_PATHW */, path, IntPtr.Zero); }
    public static void NotifyAll() { SHChangeNotify(0x08000000 /* SHCNE_ASSOCCHANGED */, 0x1000 /* SHCNF_FLUSH */, null, IntPtr.Zero); }
}
'@

function Get-Id([string]$text) {
    $sha = [Security.Cryptography.SHA1]::Create()
    ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($text.ToLowerInvariant()))) -replace '-', '').Substring(0, 16)
}

function Split-IconLocation([string]$location) {
    $i = $location.LastIndexOf(',')
    if ($i -lt 0) { return $location, 0 }
    return $location.Substring(0, $i), [int]$location.Substring($i + 1)
}

# Renders the item's own icon once and keeps it, so later runs never put a
# bubble inside a bubble; then builds the glass version from it.
function New-GlassIcon([string]$id, [scriptblock]$render) {
    $original = Join-Path $store "originals\$id.png"
    if (-not (Test-Path -LiteralPath $original)) {
        $bmp = & $render
        $bmp.Save($original, [Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
    $ico = Join-Path $store "icons\$id-$design.ico"
    if (-not (Test-Path -LiteralPath $ico)) {
        $source = [Drawing.Image]::FromFile($original)
        $glass = [GlassIcons]::Glass($source)
        [GlassIcons]::WriteIco($glass, $ico)
        $glass.Dispose()
        $source.Dispose()
    }
    $ico
}

function Set-FolderIcon([string]$dir, [string]$ico) {
    $ini = Join-Path $dir 'desktop.ini'
    $lines = if ([IO.File]::Exists($ini)) { [IO.File]::ReadAllLines($ini) } else { @() }
    $out = New-Object Collections.Generic.List[string]
    $placed = $false
    foreach ($line in $lines) {
        if ($line -match '^\s*(IconResource|IconFile|IconIndex)\s*=') { continue }
        $out.Add($line)
        if (-not $placed -and $line -match '^\s*\[\.ShellClassInfo\]\s*$') { $out.Add("IconResource=$ico,0"); $placed = $true }
    }
    if (-not $placed) { $out.Insert(0, "IconResource=$ico,0"); $out.Insert(0, '[.ShellClassInfo]') }
    if ([IO.File]::Exists($ini)) { [IO.File]::SetAttributes($ini, 'Normal') }
    [IO.File]::WriteAllLines($ini, $out, [Text.Encoding]::Unicode)
    [IO.File]::SetAttributes($ini, 'Hidden, System')
    # Explorer reads desktop.ini only for read-only or system folders.
    $folder = [IO.DirectoryInfo]$dir
    $folder.Attributes = $folder.Attributes -bor [IO.FileAttributes]::ReadOnly
    [GlassIcons]::NotifyPath($dir)
}

New-Item -ItemType Directory -Force (Join-Path $store 'icons'), (Join-Path $store 'originals') | Out-Null
$backup = @{}
if (Test-Path $backupFile) {
    (Get-Content $backupFile -Raw -Encoding UTF8 | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $backup[$_.Name] = $_.Value }
}

if ($Restore) {
    foreach ($key in @($backup.Keys)) {
        $value = $backup[$key]
        try {
            if ($key -like 'link:*') {
                $lnk = $key.Substring(5)
                if (Test-Path -LiteralPath $lnk) { $file, $index = Split-IconLocation $value; [GlassIcons]::SetLinkIcon($lnk, $file, $index) }
            } elseif ($key -like 'folder:*') {
                $dir = $key.Substring(7)
                $ini = Join-Path $dir 'desktop.ini'
                if ([IO.File]::Exists($ini)) { [IO.File]::SetAttributes($ini, 'Normal') }
                if ($null -ne $value.ini) {
                    [IO.File]::WriteAllText($ini, $value.ini, [Text.Encoding]::Unicode)
                    [IO.File]::SetAttributes($ini, 'Hidden, System')
                } elseif ([IO.File]::Exists($ini)) { [IO.File]::Delete($ini) }
                if (-not $value.readOnly) {
                    $folder = [IO.DirectoryInfo]$dir
                    $folder.Attributes = $folder.Attributes -band (-bnot [IO.FileAttributes]::ReadOnly)
                }
                [GlassIcons]::NotifyPath($dir)
            } elseif ($key -eq 'recyclebin') {
                if ($value.existed) {
                    $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($recycleBinKey)
                    foreach ($name in '', 'empty', 'full') {
                        $v = $value.$(if ($name) { $name } else { 'default' })
                        if ($v) { $k.SetValue($name, $v, 'ExpandString') } elseif ($k.GetValue($name)) { $k.DeleteValue($name) }
                    }
                    $k.Close()
                } else { [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($recycleBinKey, $false) }
            } elseif ($key -eq 'arrow') {
                $k = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($shellIconsKey)
                if ($value.value) { $k.SetValue('29', $value.value, 'String') } elseif ($null -ne $k.GetValue('29')) { $k.DeleteValue('29') }
                $k.Close()
            }
            $backup.Remove($key)
            "restored $key"
        } catch { "failed   $key : $($_.Exception.Message)" }
    }
} else {
    $desktops = [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')
    foreach ($item in Get-ChildItem -LiteralPath $desktops -Force) {
        if ($item.Name -eq 'desktop.ini' -or ($item.Attributes -band [IO.FileAttributes]::Hidden)) { continue }
        try {
            if ($item.Extension -eq '.lnk') {
                $key = "link:$($item.FullName)"
                $current = [GlassIcons]::GetLinkIcon($item.FullName)
                if (-not $backup.ContainsKey($key)) {
                    if ($current.StartsWith($store, [StringComparison]::OrdinalIgnoreCase)) { "kept     $($item.Name) (already glass)"; continue }
                    $backup[$key] = $current
                }
                $ico = New-GlassIcon (Get-Id $item.FullName) { [GlassIcons]::ShellImage($item.FullName, 256) }
                if ($current -ne "$ico,0") { [GlassIcons]::SetLinkIcon($item.FullName, $ico, 0) }
                "glass    $($item.Name)"
            } elseif ($item.PSIsContainer) {
                $key = "folder:$($item.FullName)"
                $ini = Join-Path $item.FullName 'desktop.ini'
                if (-not $backup.ContainsKey($key)) {
                    $backup[$key] = @{
                        ini = $(if ([IO.File]::Exists($ini)) { [IO.File]::ReadAllText($ini) } else { $null })
                        readOnly = [bool]($item.Attributes -band [IO.FileAttributes]::ReadOnly)
                    }
                }
                $ico = New-GlassIcon (Get-Id $item.FullName) { [GlassIcons]::ShellImage($item.FullName, 256) }
                Set-FolderIcon $item.FullName $ico
                "glass    $($item.Name)\"
            } else {
                "left     $($item.Name) (a file keeps its own icon)"
            }
        } catch { "failed   $($item.Name): $($_.Exception.Message)" }
    }

    try {
        $rb = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($recycleBinKey)
        if (-not $backup.ContainsKey('recyclebin')) {
            $backup['recyclebin'] = @{
                existed = [bool]$rb
                default = $(if ($rb) { $rb.GetValue('', $null, 'DoNotExpandEnvironmentNames') })
                empty = $(if ($rb) { $rb.GetValue('empty', $null, 'DoNotExpandEnvironmentNames') })
                full = $(if ($rb) { $rb.GetValue('full', $null, 'DoNotExpandEnvironmentNames') })
            }
        }
        if ($rb) { $rb.Close() }
        $system = Get-ItemProperty "Registry::HKEY_CLASSES_ROOT\CLSID\$recycleBin\DefaultIcon"
        $original = $backup['recyclebin']
        $emptyFile, $emptyIndex = Split-IconLocation $(if ($original.empty -and $original.empty -notlike "$store*") { $original.empty } else { $system.Empty })
        $fullFile, $fullIndex = Split-IconLocation $(if ($original.full -and $original.full -notlike "$store*") { $original.full } else { $system.Full })
        $emptyIco = New-GlassIcon 'recyclebin-empty' { [GlassIcons]::ResourceIcon($emptyFile, $emptyIndex, 256) }
        $fullIco = New-GlassIcon 'recyclebin-full' { [GlassIcons]::ResourceIcon($fullFile, $fullIndex, 256) }
        $isFull = (New-Object -ComObject Shell.Application).Namespace(10).Items().Count -gt 0
        $k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($recycleBinKey)
        $k.SetValue('empty', "$emptyIco,0", 'ExpandString')
        $k.SetValue('full', "$fullIco,0", 'ExpandString')
        $k.SetValue('', $(if ($isFull) { "$fullIco,0" } else { "$emptyIco,0" }), 'ExpandString')
        $k.Close()
        'glass    Recycle Bin'
    } catch { "failed   Recycle Bin: $($_.Exception.Message)" }

    try {
        $k = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($shellIconsKey)
        if (-not $backup.ContainsKey('arrow')) { $backup['arrow'] = @{ value = $k.GetValue('29') } }
        $blank = Join-Path $store 'blank.ico'
        [GlassIcons]::WriteBlankIco($blank)
        $k.SetValue('29', "$blank,0", 'String')
        $k.Close()
        'hidden   shortcut arrow'
    } catch { "failed   shortcut arrow: $($_.Exception.Message)" }
}

$backup | ConvertTo-Json -Depth 4 | Set-Content $backupFile -Encoding UTF8
[GlassIcons]::NotifyAll()
& "$env:SystemRoot\System32\ie4uinit.exe" -show
