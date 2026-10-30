#include "settings.h"

#include <windows.h>
#include <shlobj.h>

#include <cwchar>

namespace sg {
namespace {

constexpr wchar_t kSection[] = L"glass";

std::wstring Read(const std::wstring& file, const wchar_t* key) {
    wchar_t buf[64] = {};
    GetPrivateProfileStringW(kSection, key, L"", buf, 64, file.c_str());
    return buf;
}

bool ReadBool(const std::wstring& file, const wchar_t* key, bool def) {
    auto v = Read(file, key);
    if (v == L"1" || _wcsicmp(v.c_str(), L"true") == 0) return true;
    if (v == L"0" || _wcsicmp(v.c_str(), L"false") == 0) return false;
    return def;
}

int ReadInt(const std::wstring& file, const wchar_t* key, int def, int lo, int hi) {
    auto v = Read(file, key);
    if (v.empty()) return def;
    wchar_t* end = nullptr;
    long n = wcstol(v.c_str(), &end, 10);
    if (!end || *end) return def;
    return n < lo ? lo : n > hi ? hi : static_cast<int>(n);
}

void Write(const std::wstring& file, const wchar_t* key, const std::wstring& value) {
    WritePrivateProfileStringW(kSection, key, value.c_str(), file.c_str());
}

}  // namespace

PresetValues PresetFor(Preset p) {
    switch (p) {
        case Preset::Clear: return {14, 10};
        case Preset::Frosted: return {40, 28};
        default: return {26, 16};
    }
}

const wchar_t* TintModeName(TintMode m) { return m == TintMode::Fixed ? L"fixed" : m == TintMode::Neutral ? L"neutral" : L"auto"; }

const wchar_t* PresetName(Preset p) {
    switch (p) {
        case Preset::Clear: return L"clear";
        case Preset::Frosted: return L"frosted";
        case Preset::Custom: return L"custom";
        default: return L"balanced";
    }
}

std::wstring DataDirectory() {
    PWSTR p = nullptr;
    std::wstring dir;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &p))) dir = std::wstring(p) + L"\\SaiyanGlass";
    CoTaskMemFree(p);
    SHCreateDirectoryExW(nullptr, dir.c_str(), nullptr);
    return dir;
}

std::wstring SettingsPath() { return DataDirectory() + L"\\settings.ini"; }

Settings LoadSettings() {
    Settings s;
    auto f = SettingsPath();
    s.enabled = ReadBool(f, L"enabled", s.enabled);
    auto tint = Read(f, L"tint");
    s.tint = tint == L"fixed" ? TintMode::Fixed : tint == L"neutral" ? TintMode::Neutral : TintMode::Auto;
    auto color = Read(f, L"fixedColor");
    if (color.size() == 7 && color[0] == L'#') {
        wchar_t* end = nullptr;
        unsigned long c = wcstoul(color.c_str() + 1, &end, 16);
        if (end && !*end) s.fixedColor = static_cast<uint32_t>(c);
    }
    auto preset = Read(f, L"preset");
    s.preset = preset == L"clear" ? Preset::Clear : preset == L"frosted" ? Preset::Frosted : preset == L"custom" ? Preset::Custom : Preset::Balanced;
    auto pv = PresetFor(s.preset);
    s.opacity = ReadInt(f, L"opacity", pv.opacity, 0, 100);
    s.blur = ReadInt(f, L"blur", pv.blur, 0, 40);
    s.intensity = ReadInt(f, L"intensity", s.intensity, 0, 100);
    s.guard = ReadBool(f, L"guard", s.guard);
    s.topLine = ReadBool(f, L"topLine", s.topLine);
    return s;
}

bool SaveSettings(const Settings& s) {
    auto f = SettingsPath();
    wchar_t color[16];
    swprintf_s(color, L"#%06X", s.fixedColor & 0xFFFFFF);
    Write(f, L"enabled", s.enabled ? L"1" : L"0");
    Write(f, L"tint", TintModeName(s.tint));
    Write(f, L"fixedColor", color);
    Write(f, L"preset", PresetName(s.preset));
    Write(f, L"opacity", std::to_wstring(s.opacity));
    Write(f, L"blur", std::to_wstring(s.blur));
    Write(f, L"intensity", std::to_wstring(s.intensity));
    Write(f, L"guard", s.guard ? L"1" : L"0");
    Write(f, L"topLine", s.topLine ? L"1" : L"0");
    return WritePrivateProfileStringW(nullptr, nullptr, nullptr, f.c_str()) != FALSE;  // flush
}

}  // namespace sg
