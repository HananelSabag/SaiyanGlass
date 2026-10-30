#pragma once
#include <windows.h>

#include <cstdint>
#include <string>

#include "../common/settings.h"

namespace sg {

// What the wallpaper looks like, measured once per wallpaper change.
struct Analysis {
    bool ok = false;
    bool neutral = true;      // no meaningful color (grayscale / very dark art)
    double hue = 240;         // OKLCH hue of the dominant color family, softened toward its anchor
    double hue2 = 240;        // second strongest family, or hue
    bool hasSecond = false;
    double chroma = 0;        // OKLCH chroma of the dominant color
    double confidence = 0;    // share of colorful weight in the dominant family
    double lumTaskbar = 0.2;  // robust relative luminance of the area behind the taskbar
    double lumStart = 0.2;    // ... and behind Start
    std::wstring family = L"neutral";
    std::wstring family2;
    DWORD ms = 0;
};

// Decodes the image with WIC, emulates "Fill" on the primary screen and
// samples ~14k pixels in OKLCH. `startRect` is in screen pixels.
Analysis AnalyzeImage(const std::wstring& path, SIZE screen, int taskbarHeight, RECT startRect);

// The glass to render: a dark (or, in light mode, light) tint carrying a hint
// of the wallpaper's hue, and how strongly it covers the blurred backdrop.
struct GlassLook {
    uint32_t tint = 0x15171C;     // 0xRRGGBB
    uint32_t accent = 0xFFFFFF;   // for previews in the settings window
    uint32_t accent2 = 0xFFFFFF;
    double alpha = 0.26;          // on the plain desktop
    double alphaBusy = 0.4;       // with a maximized window or Start / search open
    bool guarded = false;         // alpha was raised for readability
};
GlassLook BuildLook(const Settings& s, const Analysis& a, bool lightMode);

std::wstring ColorHex(uint32_t argb);

}  // namespace sg
