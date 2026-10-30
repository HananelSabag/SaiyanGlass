#include "translucenttb.h"

#include <windows.h>

#include <algorithm>
#include <cwchar>

#include "util.h"

namespace sg {
namespace {

constexpr wchar_t kBackupName[] = L"settings.before-saiyanglass.json";

std::string ReadAll(const std::wstring& path) {
    std::string data;
    HANDLE f = CreateFileW(path.c_str(), GENERIC_READ, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, 0, nullptr);
    if (f == INVALID_HANDLE_VALUE) return data;
    LARGE_INTEGER size{};
    if (GetFileSizeEx(f, &size) && size.QuadPart < 1 << 20) {
        data.resize(static_cast<size_t>(size.QuadPart));
        DWORD read = 0;
        if (!ReadFile(f, data.data(), static_cast<DWORD>(data.size()), &read, nullptr)) read = 0;
        data.resize(read);
    }
    CloseHandle(f);
    return data;
}

// One WriteFile into the existing file (rather than replace-by-rename), so
// TranslucentTB's watcher sees a plain modification of settings.json.
bool WriteAll(const std::wstring& path, const std::string& data) {
    HANDLE f = CreateFileW(path.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr, OPEN_ALWAYS, 0, nullptr);
    if (f == INVALID_HANDLE_VALUE) return false;
    DWORD written = 0;
    bool ok = WriteFile(f, data.data(), static_cast<DWORD>(data.size()), &written, nullptr) && written == data.size() && SetEndOfFile(f);
    CloseHandle(f);
    return ok;
}

std::string Color(uint32_t rgb, double alpha) {
    char buf[16];
    snprintf(buf, sizeof(buf), "#%02X%06X", static_cast<unsigned>(std::clamp(alpha, 0.0, 1.0) * 255 + 0.5), rgb & 0xFFFFFF);
    return buf;
}

std::string Appearance(const char* name, int enabled, const char* accent, const std::string& color, bool peek, bool line, int blur, bool rules) {
    char buf[512];
    snprintf(buf, sizeof(buf), "  \"%s\": {\n%s    \"accent\": \"%s\",\n    \"color\": \"%s\",\n    \"show_peek\": %s,\n    \"show_line\": %s,\n    \"blur_radius\": %d.0%s\n  },\n",
             name, enabled < 0 ? "" : enabled ? "    \"enabled\": true,\n" : "    \"enabled\": false,\n", accent, color.c_str(), peek ? "true" : "false",
             line ? "true" : "false", blur,
             rules ? ",\n    \"rules\": {\n      \"window_class\": {},\n      \"window_title\": {},\n      \"process_name\": {}\n    }" : "");
    return buf;
}

}  // namespace

std::wstring TranslucentTBSettingsPath() {
    std::wstring packages = LocalAppData() + L"\\Packages\\";
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW((packages + L"*TranslucentTB*").c_str(), &fd);
    std::wstring found;
    if (h != INVALID_HANDLE_VALUE) {
        do {
            std::wstring candidate = packages + fd.cFileName + L"\\RoamingState\\settings.json";
            if (GetFileAttributesW(candidate.c_str()) != INVALID_FILE_ATTRIBUTES) {
                found = candidate;
                break;
            }
        } while (FindNextFileW(h, &fd));
        FindClose(h);
    }
    return found;
}

bool TranslucentTBRunning() { return FindProcess(L"TranslucentTB.exe") != 0; }

bool ApplyToTranslucentTB(const Settings& s, const GlassLook& look, std::wstring& error) {
    std::wstring path = TranslucentTBSettingsPath();
    if (path.empty()) {
        error = L"TranslucentTB is not installed (Microsoft Store)";
        return false;
    }
    std::wstring backup = path.substr(0, path.find_last_of(L'\\') + 1) + kBackupName;
    if (GetFileAttributesW(backup.c_str()) == INVALID_FILE_ATTRIBUTES && !CopyFileW(path.c_str(), backup.c_str(), TRUE)) {
        error = L"cannot back up TranslucentTB settings";
        return false;
    }

    const char* accent = s.blur > 0 ? "blur" : "clear";
    int blur = std::max(1, s.blur), busyBlur = std::max(1, s.blur + 4);
    std::string json;
    json += "// Managed by SaiyanGlass. Your own settings are kept in settings.before-saiyanglass.json\n";
    json += "// and come back when SaiyanGlass is turned off or restored.\n{\n";
    json += "  \"$schema\": \"https://TranslucentTB.github.io/settings.schema.json\",\n";
    json += Appearance("desktop_appearance", -1, accent, Color(look.tint, look.alpha), false, s.topLine, blur, false);
    json += Appearance("visible_window_appearance", 0, accent, Color(look.tint, look.alpha), true, s.topLine, blur, true);
    json += Appearance("maximized_window_appearance", 1, accent, Color(look.tint, look.alphaBusy), true, s.topLine, busyBlur, true);
    json += Appearance("start_opened_appearance", 1, accent, Color(look.tint, look.alphaBusy), true, s.topLine, busyBlur, false);
    json += Appearance("search_opened_appearance", 1, accent, Color(look.tint, look.alphaBusy), true, s.topLine, busyBlur, false);
    json += Appearance("task_view_opened_appearance", 1, "normal", "#00000000", false, true, 9, false);
    json += Appearance("battery_saver_appearance", 0, "opaque", "#00000000", true, false, 9, false);
    json += "  \"ignored_windows\": {\n    \"window_class\": [],\n    \"window_title\": [],\n    \"process_name\": []\n  },\n";
    json += "  \"disable_saving\": false,\n  \"verbosity\": \"warn\"\n}\n";

    if (ReadAll(path) == json) return true;
    if (!WriteAll(path, json)) {
        error = L"cannot write " + path;
        return false;
    }
    return true;
}

bool RestoreTranslucentTB(std::wstring& error) {
    std::wstring path = TranslucentTBSettingsPath();
    if (path.empty()) return true;  // nothing of ours to undo
    std::wstring backup = path.substr(0, path.find_last_of(L'\\') + 1) + kBackupName;
    std::string original = ReadAll(backup);
    if (original.empty()) return true;  // never applied
    if (ReadAll(path) == original) return true;
    if (!WriteAll(path, original)) {
        error = L"cannot restore " + path;
        return false;
    }
    return true;
}

}  // namespace sg
