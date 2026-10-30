// User settings, stored in %LOCALAPPDATA%\SaiyanGlass\settings.ini.
// Every value is validated on load; anything missing or malformed falls back
// to its default, so a damaged file can never stop the host from starting.
#pragma once
#include <cstdint>
#include <string>

namespace sg {

enum class TintMode { Auto, Fixed, Neutral };
enum class Preset { Clear, Balanced, Frosted, Custom };

struct Settings {
    bool enabled = true;
    TintMode tint = TintMode::Auto;
    uint32_t fixedColor = 0x3AA0FF;  // 0xRRGGBB
    Preset preset = Preset::Balanced;
    int opacity = 26;     // minimum glass darkening, 0..100
    int blur = 16;        // blur radius, 0 = clear glass without blur
    int intensity = 60;   // how much wallpaper hue the glass picks up, 0..100
    bool guard = true;    // darken more where the wallpaper behind the taskbar is bright
    bool topLine = true;  // thin highlight line along the top edge
};

struct PresetValues {
    int opacity, blur;
};
PresetValues PresetFor(Preset p);

std::wstring DataDirectory();  // %LOCALAPPDATA%\SaiyanGlass (created on demand)
std::wstring SettingsPath();
Settings LoadSettings();
bool SaveSettings(const Settings& s);

const wchar_t* TintModeName(TintMode m);
const wchar_t* PresetName(Preset p);

}  // namespace sg
