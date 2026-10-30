#include "accent.h"

#include <wincodec.h>
#include <wrl/client.h>

#include <algorithm>
#include <cmath>
#include <cwchar>
#include <vector>

using Microsoft::WRL::ComPtr;

namespace sg {
namespace {

constexpr double kPi = 3.14159265358979323846;

double ToLin(double c) { return c <= 0.04045 ? c / 12.92 : std::pow((c + 0.055) / 1.055, 2.4); }
double ToSrgb(double c) { return c <= 0.0031308 ? 12.92 * c : 1.055 * std::pow(c, 1 / 2.4) - 0.055; }

void LinToOklab(double r, double g, double b, double& L, double& A, double& B) {
    double l = std::cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    double m = std::cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    double s = std::cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
}

// OKLCH -> 0xRRGGBB, reducing chroma until the color fits in sRGB.
uint32_t Oklch(double L, double C, double hDeg) {
    double r = 0, g = 0, b = 0;
    for (int i = 0; i < 40; ++i) {
        double h = hDeg * kPi / 180, A = C * std::cos(h), B = C * std::sin(h);
        double l = L + 0.3963377774 * A + 0.2158037573 * B, m = L - 0.1055613458 * A - 0.0638541728 * B, s = L - 0.0894841775 * A - 1.2914855480 * B;
        l = l * l * l, m = m * m * m, s = s * s * s;
        r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s;
        g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s;
        b = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s;
        if (r > -0.0005 && g > -0.0005 && b > -0.0005 && r < 1.0005 && g < 1.0005 && b < 1.0005) break;
        C *= 0.92;
    }
    auto q = [](double v) { return static_cast<uint32_t>(std::lround(std::clamp(ToSrgb(std::clamp(v, 0.0, 1.0)), 0.0, 1.0) * 255)); };
    return (q(r) << 16) | (q(g) << 8) | q(b);
}

void RgbToOklch(uint32_t rgb, double& L, double& C, double& h) {
    double A, B;
    LinToOklab(ToLin(((rgb >> 16) & 255) / 255.0), ToLin(((rgb >> 8) & 255) / 255.0), ToLin((rgb & 255) / 255.0), L, A, B);
    C = std::hypot(A, B);
    h = std::fmod(std::atan2(B, A) * 180 / kPi + 360, 360);
}

double RelLum(uint32_t rgb) {
    return 0.2126 * ToLin(((rgb >> 16) & 255) / 255.0) + 0.7152 * ToLin(((rgb >> 8) & 255) / 255.0) + 0.0722 * ToLin((rgb & 255) / 255.0);
}

double Smooth(double e0, double e1, double x) {
    double t = std::clamp((x - e0) / (e1 - e0), 0.0, 1.0);
    return t * t * (3 - 2 * t);
}

double HueDist(double a, double b) {
    double d = std::fmod(std::fabs(a - b), 360);
    return d > 180 ? 360 - d : d;
}

double HueLerp(double a, double b, double t) {
    double d = std::fmod(b - a + 540, 360) - 180;
    return std::fmod(a + d * t + 360, 360);
}

// Transformation families (OKLCH hue ranges) and the hue each one leans toward.
struct Family {
    const wchar_t* name;
    double anchor;
};
constexpr Family kFamilies[] = {{L"crimson", 24}, {L"gold", 86}, {L"green", 150}, {L"blue", 238}, {L"violet", 308}};

int FamilyOf(double h) {
    if (h >= 345 || h < 40) return 0;
    if (h < 115) return 1;
    if (h < 175) return 2;
    if (h < 280) return 3;
    return 4;
}

constexpr int kW = 640, kH = 360;  // analysis canvas (a quarter of 2560x1440)

// Blend of mean and 90th percentile of block means: acrylic blur averages
// locally, but bright spots still shine through.
double RegionLum(const std::vector<uint8_t>& px, RECT rc) {
    rc.left = std::clamp<LONG>(rc.left, 0, kW), rc.right = std::clamp<LONG>(rc.right, 0, kW);
    rc.top = std::clamp<LONG>(rc.top, 0, kH), rc.bottom = std::clamp<LONG>(rc.bottom, 0, kH);
    std::vector<double> blocks;
    for (LONG by = rc.top; by < rc.bottom; by += 12)
        for (LONG bx = rc.left; bx < rc.right; bx += 16) {
            double sum = 0;
            int n = 0;
            for (LONG y = by; y < std::min<LONG>(by + 12, rc.bottom); ++y)
                for (LONG x = bx; x < std::min<LONG>(bx + 16, rc.right); ++x) {
                    const uint8_t* p = &px[(y * kW + x) * 3];  // BGR
                    sum += 0.0722 * ToLin(p[0] / 255.0) + 0.7152 * ToLin(p[1] / 255.0) + 0.2126 * ToLin(p[2] / 255.0);
                    ++n;
                }
            if (n) blocks.push_back(sum / n);
        }
    if (blocks.empty()) return 0.2;
    std::sort(blocks.begin(), blocks.end());
    double mean = 0;
    for (double v : blocks) mean += v;
    mean /= blocks.size();
    double p90 = blocks[std::min(blocks.size() - 1, static_cast<size_t>(blocks.size() * 0.9))];
    return 0.5 * mean + 0.5 * p90;
}

bool Decode(const std::wstring& path, std::vector<uint8_t>& px) {
    ComPtr<IWICImagingFactory> wic;
    ComPtr<IWICBitmapDecoder> dec;
    ComPtr<IWICBitmapFrameDecode> frame;
    if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&wic))) ||
        FAILED(wic->CreateDecoderFromFilename(path.c_str(), nullptr, GENERIC_READ, WICDecodeMetadataCacheOnDemand, &dec)) ||
        FAILED(dec->GetFrame(0, &frame)))
        return false;
    UINT w = 0, h = 0;
    frame->GetSize(&w, &h);
    if (!w || !h) return false;
    // Fill: scale to cover, then crop the center. Scaling first lets the JPEG
    // decoder decode at reduced size.
    double s = std::max(static_cast<double>(kW) / w, static_cast<double>(kH) / h);
    UINT sw = std::max<UINT>(kW, static_cast<UINT>(std::ceil(w * s))), sh = std::max<UINT>(kH, static_cast<UINT>(std::ceil(h * s)));
    ComPtr<IWICBitmapScaler> scaler;
    ComPtr<IWICBitmapClipper> clipper;
    ComPtr<IWICFormatConverter> conv;
    WICRect crop{static_cast<INT>((sw - kW) / 2), static_cast<INT>((sh - kH) / 2), kW, kH};
    if (FAILED(wic->CreateBitmapScaler(&scaler)) || FAILED(scaler->Initialize(frame.Get(), sw, sh, WICBitmapInterpolationModeFant)) ||
        FAILED(wic->CreateBitmapClipper(&clipper)) || FAILED(clipper->Initialize(scaler.Get(), &crop)) || FAILED(wic->CreateFormatConverter(&conv)) ||
        FAILED(conv->Initialize(clipper.Get(), GUID_WICPixelFormat24bppBGR, WICBitmapDitherTypeNone, nullptr, 0, WICBitmapPaletteTypeCustom)))
        return false;
    px.resize(kW * kH * 3);
    return SUCCEEDED(conv->CopyPixels(nullptr, kW * 3, static_cast<UINT>(px.size()), px.data()));
}

}  // namespace

std::wstring ColorHex(uint32_t argb) {
    wchar_t buf[16];
    swprintf_s(buf, L"#%06X", argb & 0xFFFFFF);
    return buf;
}

Analysis AnalyzeImage(const std::wstring& path, SIZE screen, int taskbarHeight, RECT startRect) {
    Analysis a;
    ULONGLONG t0 = GetTickCount64();
    std::vector<uint8_t> px;
    if (!Decode(path, px)) return a;

    // Hue histogram over a 160x90 box-filtered grid.
    struct Px {
        double L, C, h, w;
    };
    std::vector<Px> samples;
    samples.reserve(160 * 90);
    double hist[72] = {}, total = 0, all = 0;
    for (int gy = 0; gy < 90; ++gy)
        for (int gx = 0; gx < 160; ++gx) {
            double r = 0, g = 0, b = 0;
            for (int y = gy * 4; y < gy * 4 + 4; ++y)
                for (int x = gx * 4; x < gx * 4 + 4; ++x) {
                    const uint8_t* p = &px[(y * kW + x) * 3];
                    b += ToLin(p[0] / 255.0), g += ToLin(p[1] / 255.0), r += ToLin(p[2] / 255.0);
                }
            double L, A, B;
            LinToOklab(r / 16, g / 16, b / 16, L, A, B);
            double C = std::hypot(A, B), h = std::fmod(std::atan2(B, A) * 180 / kPi + 360, 360);
            double dx = gx / 159.0 - 0.5, dy = gy / 89.0 - 0.5;
            double pos = 0.6 + 0.4 * std::exp(-(dx * dx / (2 * 0.09) + dy * dy / (2 * 0.1225)));
            all += pos;
            if (C < 0.035 || L < 0.12) continue;
            // Hair and auras should beat large areas of skin.
            double skin = (h > 35 && h < 80 && C < 0.11 && L > 0.55) ? 0.25 : 1.0;
            double w = (C - 0.035) * Smooth(0.12, 0.35, L) * (1 - Smooth(0.92, 0.99, L)) * pos * skin;
            if (w <= 0) continue;
            hist[static_cast<int>(h / 5) % 72] += w;
            total += w;
            samples.push_back({L, C, h, w});
        }

    double win[72] = {};
    for (int i = 0; i < 72; ++i)
        for (int j = -6; j <= 5; ++j) win[i] += hist[(i + j + 72) % 72];
    int p1 = 0;
    for (int i = 1; i < 72; ++i)
        if (win[i] > win[p1]) p1 = i;
    int p2 = -1;
    for (int i = 0; i < 72; ++i) {
        if (HueDist(i * 5, p1 * 5) < 45) continue;
        if (p2 < 0 || win[i] > win[p2]) p2 = i;
    }
    auto peak = [&](int p, double& hue, double& C, double& weight) {
        double sx = 0, sy = 0, sw = 0, sc = 0;
        for (auto& s : samples) {
            if (HueDist(s.h, p * 5 + 2.5) > 30) continue;
            sx += s.w * std::cos(s.h * kPi / 180), sy += s.w * std::sin(s.h * kPi / 180), sw += s.w, sc += s.C * s.w;
        }
        hue = sw ? std::fmod(std::atan2(sy, sx) * 180 / kPi + 360, 360) : p * 5;
        C = sw ? sc / sw : 0;
        weight = sw;
    };
    double h1, c1, w1, h2 = 0, c2 = 0, w2 = 0;
    peak(p1, h1, c1, w1);
    if (p2 >= 0) peak(p2, h2, c2, w2);

    a.ok = true;
    a.neutral = total / all < 0.004;
    a.confidence = total > 0 ? w1 / total : 0;
    int f1 = FamilyOf(h1);
    a.family = a.neutral ? L"neutral" : kFamilies[f1].name;
    a.hue = HueLerp(h1, kFamilies[f1].anchor, 0.4);
    a.chroma = c1;
    a.hasSecond = p2 >= 0 && w2 > 0.35 * w1;
    if (a.hasSecond) {
        int f2 = FamilyOf(h2);
        a.hue2 = HueLerp(h2, kFamilies[f2].anchor, 0.4);
        a.family2 = kFamilies[f2].name;
    } else {
        a.hue2 = a.hue;
    }

    // Screen -> analysis canvas.
    double sx = static_cast<double>(kW) / std::max<LONG>(1, screen.cx), sy = static_cast<double>(kH) / std::max<LONG>(1, screen.cy);
    a.lumTaskbar = RegionLum(px, {0, static_cast<LONG>(kH - taskbarHeight * sy), kW, kH});
    a.lumStart = RegionLum(px, {static_cast<LONG>(startRect.left * sx), static_cast<LONG>(startRect.top * sy), static_cast<LONG>(startRect.right * sx),
                                static_cast<LONG>(startRect.bottom * sy)});
    a.ms = static_cast<DWORD>(GetTickCount64() - t0);
    return a;
}

GlassLook BuildLook(const Settings& s, const Analysis& a, bool lightMode) {
    GlassLook look;
    double intensity = s.intensity / 100.0;
    double hue = a.hue, hue2 = a.hue2, chroma = std::clamp(a.chroma, 0.08, 0.14) * (0.6 + 0.4 * a.confidence) * intensity;
    bool neutral = s.tint == TintMode::Neutral || (s.tint == TintMode::Auto && (a.neutral || !a.ok));
    if (s.tint == TintMode::Fixed) {
        double L, C, h;
        RgbToOklch(s.fixedColor, L, C, h);
        hue = hue2 = h;
        chroma = std::min(0.14, C) * intensity;
    }
    if (neutral) chroma = 0;

    // Dark warm tints read as muddy brown, so the glass carries only a hint of
    // hue, less for warm hues.
    bool warm = hue < 120 || hue > 340;
    double bodyC = std::min(warm ? 0.02 : 0.04, chroma * 0.35);
    look.tint = lightMode ? Oklch(0.95, bodyC * 0.6, hue) : Oklch(0.16, bodyC, hue);
    look.accent = neutral ? Oklch(0.86, 0, 0) : Oklch(0.80, std::max(chroma, 0.06), hue);
    look.accent2 = neutral ? Oklch(0.78, 0, 0) : Oklch(0.76, std::max(chroma, 0.06) * 0.9, hue2);

    // Readability guard: the cover needed so that white (in light mode, black)
    // taskbar text keeps 4.5:1 over the brightest likely part of the backdrop.
    // Capped so the glass never turns into a solid bar.
    double lt = RelLum(look.tint), bg = a.lumTaskbar;
    double needed = !lightMode ? (bg <= 0.183 ? 0.0 : (bg - 0.183) / (bg - lt)) : (bg >= 0.40 ? 0.0 : (0.40 - bg) / (lt - bg));
    needed = std::clamp(needed, 0.0, 0.60);
    double base = s.opacity / 100.0;
    look.alpha = s.guard ? std::max(base, needed) : base;
    look.guarded = s.guard && needed > base;
    look.alphaBusy = std::min(0.75, look.alpha + 0.12);
    return look;
}
}  // namespace sg
