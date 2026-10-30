# Prototype wallpaper analysis (design exploration only; the shipping
# implementation lives in src/host/accent.cpp and uses WIC).
#
# For every wallpaper it emulates the "Fill" position on a 2560x1440 screen,
# writes a preview JPEG, derives a restrained accent in OKLCH space, and
# estimates the tint opacity needed under the taskbar and Start so that white
# text keeps a contrast ratio of at least 4.5:1.
param(
    [string]$Source = 'C:\Users\hanan\Wallpapers\Dragon Ball 2K',
    [string]$Out = (Join-Path $PSScriptRoot '.cache'),
    [int]$ScreenW = 2560,
    [int]$ScreenH = 1440
)

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Globalization;
using System.Text;

public static class Accent {
    static double ToLin(double c) { return c <= 0.04045 ? c / 12.92 : Math.Pow((c + 0.055) / 1.055, 2.4); }
    static double ToSrgb(double c) { return c <= 0.0031308 ? 12.92 * c : 1.055 * Math.Pow(c, 1 / 2.4) - 0.055; }

    public static void LinToOklab(double r, double g, double b, out double L, out double A, out double B) {
        double l = Math.Pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3.0);
        double m = Math.Pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3.0);
        double s = Math.Pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3.0);
        L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
        A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
        B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    }

    static void OklabToLin(double L, double A, double B, out double r, out double g, out double b) {
        double l = L + 0.3963377774 * A + 0.2158037573 * B;
        double m = L - 0.1055613458 * A - 0.0638541728 * B;
        double s = L - 0.0894841775 * A - 1.2914855480 * B;
        l = l * l * l; m = m * m * m; s = s * s * s;
        r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
        g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
        b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
    }

    // OKLCH -> sRGB hex, reducing chroma until the color is inside the sRGB gamut.
    public static string Hex(double L, double C, double hDeg) {
        double r = 0, g = 0, b = 0;
        for (int i = 0; i < 40; i++) {
            double h = hDeg * Math.PI / 180;
            OklabToLin(L, C * Math.Cos(h), C * Math.Sin(h), out r, out g, out b);
            if (r >= -0.0005 && g >= -0.0005 && b >= -0.0005 && r <= 1.0005 && g <= 1.0005 && b <= 1.0005) break;
            C *= 0.92;
        }
        Func<double, int> q = v => (int)Math.Round(Math.Max(0, Math.Min(1, ToSrgb(Math.Max(0, Math.Min(1, v))))) * 255);
        return string.Format("#{0:X2}{1:X2}{2:X2}", q(r), q(g), q(b));
    }

    public static double RelLum(string hex) {
        int v = Convert.ToInt32(hex.Substring(1), 16);
        double r = ToLin(((v >> 16) & 255) / 255.0), g = ToLin(((v >> 8) & 255) / 255.0), b = ToLin((v & 255) / 255.0);
        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    static double Smooth(double e0, double e1, double x) {
        double t = Math.Max(0, Math.Min(1, (x - e0) / (e1 - e0)));
        return t * t * (3 - 2 * t);
    }

    static double HueDist(double a, double b) { double d = Math.Abs(a - b) % 360; return d > 180 ? 360 - d : d; }

    static double HueLerp(double a, double b, double t) {
        double d = ((b - a + 540) % 360) - 180;
        return (a + d * t + 360) % 360;
    }

    // Transformation families as OKLCH hue ranges with an anchor hue.
    static readonly string[] FamName = { "crimson", "gold", "green", "blue", "violet" };
    static readonly double[] FamAnchor = { 24, 86, 150, 238, 308 };

    static int Family(double h) {
        if (h >= 345 || h < 40) return 0;
        if (h < 115) return 1;
        if (h < 175) return 2;
        if (h < 280) return 3;
        return 4;
    }

    // Robust luminance of a screen region: blend of mean and 90th percentile of
    // 64x48 block means (acrylic blur averages locally, bright spots still show).
    static double RegionLum(Bitmap bmp, Rectangle rc) {
        var blocks = new List<double>();
        BitmapData d = bmp.LockBits(rc, ImageLockMode.ReadOnly, PixelFormat.Format24bppRgb);
        try {
            int bw = 64, bh = Math.Min(48, rc.Height);
            byte[] row = new byte[d.Stride];
            double[,] acc = new double[(rc.Width + bw - 1) / bw, (rc.Height + bh - 1) / bh];
            int[,] cnt = new int[acc.GetLength(0), acc.GetLength(1)];
            for (int y = 0; y < rc.Height; y += 2) {
                System.Runtime.InteropServices.Marshal.Copy(d.Scan0 + y * d.Stride, row, 0, d.Stride);
                for (int x = 0; x < rc.Width; x += 2) {
                    double lum = 0.0722 * ToLin(row[x * 3] / 255.0) + 0.7152 * ToLin(row[x * 3 + 1] / 255.0) + 0.2126 * ToLin(row[x * 3 + 2] / 255.0);
                    acc[x / bw, y / bh] += lum; cnt[x / bw, y / bh]++;
                }
            }
            for (int i = 0; i < acc.GetLength(0); i++)
                for (int j = 0; j < acc.GetLength(1); j++)
                    if (cnt[i, j] > 0) blocks.Add(acc[i, j] / cnt[i, j]);
        } finally { bmp.UnlockBits(d); }
        blocks.Sort();
        double mean = 0; foreach (double v in blocks) mean += v; mean /= blocks.Count;
        double p90 = blocks[(int)Math.Min(blocks.Count - 1, Math.Floor(blocks.Count * 0.9))];
        return 0.5 * mean + 0.5 * p90;
    }

    // Tint alpha needed so that alpha*tint + (1-alpha)*backdrop stays at or
    // below the goal luminance (white text contrast ~6:1).
    static double NeededAlpha(double backdrop, double tint, double goal) {
        if (backdrop <= goal) return 0;
        return Math.Min(0.95, (backdrop - goal) / (backdrop - tint));
    }

    static string F(double v) { return v.ToString("0.###", CultureInfo.InvariantCulture); }

    public static string Analyze(string path, string previewPath, int sw, int sh) {
        using (var src = new Bitmap(path))
        using (var screen = new Bitmap(sw, sh, PixelFormat.Format24bppRgb))
        using (var small = new Bitmap(160, 90, PixelFormat.Format24bppRgb)) {
            // Fill: scale to cover, crop the center.
            double scale = Math.Max((double)sw / src.Width, (double)sh / src.Height);
            double cw = sw / scale, ch = sh / scale;
            var crop = new RectangleF((float)((src.Width - cw) / 2), (float)((src.Height - ch) / 2), (float)cw, (float)ch);
            using (var g = Graphics.FromImage(screen)) {
                g.InterpolationMode = InterpolationMode.HighQualityBicubic;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(src, new RectangleF(0, 0, sw, sh), crop, GraphicsUnit.Pixel);
            }
            using (var g = Graphics.FromImage(small)) {
                g.InterpolationMode = InterpolationMode.HighQualityBilinear;
                g.PixelOffsetMode = PixelOffsetMode.HighQuality;
                g.DrawImage(screen, new Rectangle(0, 0, 160, 90), new Rectangle(0, 0, sw, sh), GraphicsUnit.Pixel);
            }
            var enc = Array.Find(ImageCodecInfo.GetImageEncoders(), e => e.MimeType == "image/jpeg");
            var ep = new EncoderParameters(1); ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, 88L);
            screen.Save(previewPath, enc, ep);

            double[] hist = new double[72];
            var px = new List<double[]>();
            double total = 0, all = 0;
            for (int y = 0; y < 90; y++) {
                for (int x = 0; x < 160; x++) {
                    Color c = small.GetPixel(x, y);
                    double L, A, B;
                    LinToOklab(ToLin(c.R / 255.0), ToLin(c.G / 255.0), ToLin(c.B / 255.0), out L, out A, out B);
                    double C = Math.Sqrt(A * A + B * B);
                    double h = (Math.Atan2(B, A) * 180 / Math.PI + 360) % 360;
                    double dx = x / 159.0 - 0.5, dy = y / 89.0 - 0.5;
                    double pos = 0.6 + 0.4 * Math.Exp(-(dx * dx / (2 * 0.3 * 0.3) + dy * dy / (2 * 0.35 * 0.35)));
                    all += pos;
                    if (C < 0.035 || L < 0.12) continue;
                    // Hair and auras should beat large areas of skin, so light,
                    // low-chroma warm tones are damped.
                    double skin = (h > 35 && h < 80 && C < 0.11 && L > 0.55) ? 0.25 : 1.0;
                    double w = (C - 0.035) * Smooth(0.12, 0.35, L) * (1 - Smooth(0.92, 0.99, L)) * pos * skin;
                    if (w <= 0) continue;
                    hist[(int)(h / 5) % 72] += w; total += w;
                    px.Add(new double[] { L, C, h, w });
                }
            }

            // Windowed (+-30 deg) hue mass, then the two strongest separated peaks.
            double[] sm = new double[72];
            for (int i = 0; i < 72; i++) for (int j = -6; j <= 5; j++) sm[i] += hist[(i + j + 72) % 72];
            int p1 = 0; for (int i = 1; i < 72; i++) if (sm[i] > sm[p1]) p1 = i;
            int p2 = -1; for (int i = 0; i < 72; i++) { if (HueDist(i * 5, p1 * 5) < 45) continue; if (p2 < 0 || sm[i] > sm[p2]) p2 = i; }

            Func<int, double[]> peak = p => {
                double sx = 0, sy = 0, sw2 = 0, sl = 0, sc = 0;
                foreach (var q in px) {
                    if (HueDist(q[2], p * 5 + 2.5) > 30) continue;
                    double r = q[2] * Math.PI / 180;
                    sx += q[3] * Math.Cos(r); sy += q[3] * Math.Sin(r); sw2 += q[3]; sl += q[0] * q[3]; sc += q[1] * q[3];
                }
                if (sw2 == 0) return new double[] { p * 5, 0, 0, 0 };
                return new double[] { (Math.Atan2(sy, sx) * 180 / Math.PI + 360) % 360, sl / sw2, sc / sw2, sw2 };
            };
            double[] a1 = peak(p1);
            double[] a2 = p2 >= 0 ? peak(p2) : new double[] { 0, 0, 0, 0 };
            double colorfulness = total / all;           // how much of the image is chromatic at all
            double confidence = total > 0 ? a1[3] / total : 0;

            bool neutral = colorfulness < 0.004;
            int fam = Family(a1[0]);
            double hue = HueLerp(a1[0], FamAnchor[fam], 0.4);
            double accC = Math.Max(0.08, Math.Min(0.14, a1[2])) * (0.6 + 0.4 * confidence);
            string accent = neutral ? Hex(0.86, 0, 0) : Hex(0.80, accC, hue);
            string tint = neutral ? Hex(0.17, 0, 0) : Hex(0.17, Math.Min(0.045, accC * 0.35), hue);
            string tintNeutral = Hex(0.17, 0, 0);

            // 0.183 = relative luminance at which white text reaches 4.5:1 (WCAG AA).
            double goal = 0.183, lt = RelLum(tint);
            double lumTaskbar = RegionLum(screen, new Rectangle(0, sh - 48, sw, 48));
            double lumStart = RegionLum(screen, new Rectangle(851, 502, 858, 890));

            var sb = new StringBuilder();
            sb.Append("{");
            sb.AppendFormat("\"hue\":{0},\"rawHue\":{1},\"family\":\"{2}\",\"neutral\":{3},", F(hue), F(a1[0]), neutral ? "neutral" : FamName[fam], neutral ? "true" : "false");
            sb.AppendFormat("\"confidence\":{0},\"colorfulness\":{1},\"peakL\":{2},\"peakC\":{3},", F(confidence), F(colorfulness), F(a1[1]), F(a1[2]));
            sb.AppendFormat("\"secondary\":{0},", p2 >= 0 && a2[3] > 0.35 * a1[3] ? "{\"hue\":" + F(a2[0]) + ",\"family\":\"" + FamName[Family(a2[0])] + "\",\"share\":" + F(a2[3] / total) + "}" : "null");
            sb.AppendFormat("\"accent\":\"{0}\",\"tint\":\"{1}\",\"tintNeutral\":\"{2}\",", accent, tint, tintNeutral);
            sb.AppendFormat("\"lumTaskbar\":{0},\"lumStart\":{1},\"alphaTaskbar\":{2},\"alphaStart\":{3}", F(lumTaskbar), F(lumStart), F(NeededAlpha(lumTaskbar, lt, goal)), F(NeededAlpha(lumStart, lt, goal)));
            sb.Append("}");
            return sb.ToString();
        }
    }
}
'@

New-Item -ItemType Directory -Force $Out | Out-Null
$entries = @()
$sw = [Diagnostics.Stopwatch]::StartNew()
Get-ChildItem $Source -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|bmp)$' } | Sort-Object Name | ForEach-Object {
    $preview = Join-Path $Out ($_.BaseName + '.jpg')
    $t = [Diagnostics.Stopwatch]::StartNew()
    $json = [Accent]::Analyze($_.FullName, $preview, $ScreenW, $ScreenH)
    $entries += '{"file":' + (ConvertTo-Json $_.Name) + ',"preview":' + (ConvertTo-Json ('.cache/' + $_.BaseName + '.jpg')) + ',"ms":' + $t.ElapsedMilliseconds + ',' + $json.Substring(1)
}
Set-Content -Path (Join-Path $PSScriptRoot 'wallpapers.local.js') -Encoding UTF8 -Value ("window.WALLPAPERS = [`n" + ($entries -join ",`n") + "`n];")
"Analyzed $($entries.Count) wallpapers in $([int]$sw.Elapsed.TotalSeconds) s"