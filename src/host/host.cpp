// The background host: started at sign-in, never shows a window, and sleeps in
// MsgWaitForMultipleObjectsEx until something relevant happens:
//   - the wallpaper file changes (ReadDirectoryChangesW on the Themes folder)
//   - light/dark mode or display changes (WM_SETTINGCHANGE / WM_DISPLAYCHANGE)
//   - a command from the settings window or the command line (WM_COPYDATA)
// Each event re-samples the wallpaper if needed and rewrites TranslucentTB's
// settings only when the result differs.
#include "host.h"

#include <shlobj.h>
#include <shobjidl.h>

#include <cwchar>
#include <string>

#include "../common/protocol.h"
#include "../common/settings.h"
#include "accent.h"
#include "install.h"
#include "translucenttb.h"
#include "util.h"

namespace sg {
namespace {

enum : UINT { WM_APP_WALLPAPER = WM_APP + 1, WM_APP_COMMAND };
enum : UINT_PTR { TimerWallpaper = 1 };

struct HostState {
    HWND hwnd = nullptr;
    Settings settings;
    Analysis analysis;
    GlassLook look;
    std::wstring wallpaperSource;
    std::wstring state = L"starting";
    HANDLE dir = INVALID_HANDLE_VALUE;
    OVERLAPPED ov{};
    alignas(DWORD) BYTE buf[4096];
};
HostState g;

void Log(const wchar_t* fmt, ...) {
    wchar_t msg[1024];
    va_list ap;
    va_start(ap, fmt);
    _vsnwprintf_s(msg, _TRUNCATE, fmt, ap);
    va_end(ap);
    SYSTEMTIME st;
    GetLocalTime(&st);
    wchar_t line[1200];
    swprintf_s(line, L"%04u-%02u-%02u %02u:%02u:%02u  %s\r\n", st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, msg);
    std::string u = ToUtf8(line);
    HANDLE f = CreateFileW((DataDir() + L"\\host.log").c_str(), FILE_APPEND_DATA, FILE_SHARE_READ, nullptr, OPEN_ALWAYS, 0, nullptr);
    if (f != INVALID_HANDLE_VALUE) {
        DWORD w;
        WriteFile(f, u.data(), static_cast<DWORD>(u.size()), &w, nullptr);
        CloseHandle(f);
    }
}

void RotateLog() {
    std::wstring path = DataDir() + L"\\host.log";
    WIN32_FILE_ATTRIBUTE_DATA fa;
    if (GetFileAttributesExW(path.c_str(), GetFileExInfoStandard, &fa) && fa.nFileSizeLow > 512 * 1024)
        MoveFileExW(path.c_str(), (DataDir() + L"\\host.old.log").c_str(), MOVEFILE_REPLACE_EXISTING);
}

bool LightMode() {
    DWORD v = 0, size = sizeof(v);
    RegGetValueW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize", L"SystemUsesLightTheme", RRF_RT_REG_DWORD, nullptr,
                 &v, &size);
    return v != 0;
}

std::wstring WindowsBuild() {
    wchar_t build[32] = {};
    DWORD size = sizeof(build), ubr = 0, usize = sizeof(ubr);
    RegGetValueW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", L"CurrentBuild", RRF_RT_REG_SZ, nullptr, build, &size);
    RegGetValueW(HKEY_LOCAL_MACHINE, L"SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion", L"UBR", RRF_RT_REG_DWORD, nullptr, &ubr, &usize);
    return std::wstring(build) + L"." + std::to_wstring(ubr);
}

std::wstring ThemesDir() {
    PWSTR roaming = nullptr;
    std::wstring dir;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr, &roaming))) dir = std::wstring(roaming) + L"\\Microsoft\\Windows\\Themes";
    CoTaskMemFree(roaming);
    return dir;
}

// ---------------------------------------------------------------------------

std::wstring CurrentWallpaperSource() {
    std::wstring result;
    IDesktopWallpaper* dw = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_DesktopWallpaper, nullptr, CLSCTX_ALL, IID_PPV_ARGS(&dw)))) {
        LPWSTR id = nullptr, path = nullptr;
        if (SUCCEEDED(dw->GetMonitorDevicePathAt(0, &id)) && SUCCEEDED(dw->GetWallpaper(id, &path)) && path) result = path;
        CoTaskMemFree(id);
        CoTaskMemFree(path);
        dw->Release();
    }
    return result;
}

void Analyze() {
    SIZE screen{GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)};
    int taskbar = 48;
    if (HWND tray = FindWindowW(L"Shell_TrayWnd", nullptr)) {
        RECT r;
        if (GetWindowRect(tray, &r)) taskbar = r.bottom - r.top;
    }
    RECT start{(screen.cx - 858) / 2, screen.cy - taskbar - 12 - 890, (screen.cx + 858) / 2, screen.cy - taskbar - 12};
    auto a = AnalyzeImage(ThemesDir() + L"\\TranscodedWallpaper", screen, taskbar, start);
    g.wallpaperSource = CurrentWallpaperSource();
    if (!a.ok) {
        Log(L"wallpaper analysis failed");
        return;
    }
    g.analysis = a;
    Log(L"wallpaper %s: %s%s%s, brightness behind taskbar %.2f, %u ms", g.wallpaperSource.c_str(), a.family.c_str(), a.hasSecond ? L"+" : L"",
        a.family2.c_str(), a.lumTaskbar, a.ms);
}

void Apply() {
    if (!g.settings.enabled) {
        std::wstring error;
        g.state = RestoreTranslucentTB(error) ? L"off (your own TranslucentTB look)" : error;
        return;
    }
    g.look = BuildLook(g.settings, g.analysis, LightMode());
    std::wstring error;
    if (ApplyToTranslucentTB(g.settings, g.look, error))
        g.state = TranslucentTBRunning() ? L"active" : L"saved (TranslucentTB is not running)";
    else
        g.state = error;
}

void Restore() {
    std::wstring error;
    g.state = RestoreTranslucentTB(error) ? L"restored" : error;
    Log(L"restore: %s", g.state.c_str());
}

// ---------------------------------------------------------------------------
// Wallpaper file watcher.

void ArmWatcher();

void CALLBACK OnDirChange(DWORD error, DWORD bytes, OVERLAPPED*) {
    if (error == ERROR_OPERATION_ABORTED) return;
    bool relevant = bytes == 0;  // overflow: assume it changed
    for (auto* p = reinterpret_cast<FILE_NOTIFY_INFORMATION*>(g.buf); bytes && p;) {
        std::wstring name(p->FileName, p->FileNameLength / sizeof(wchar_t));
        if (name.rfind(L"TranscodedWallpaper", 0) == 0) relevant = true;
        p = p->NextEntryOffset ? reinterpret_cast<FILE_NOTIFY_INFORMATION*>(reinterpret_cast<BYTE*>(p) + p->NextEntryOffset) : nullptr;
    }
    if (relevant) PostMessageW(g.hwnd, WM_APP_WALLPAPER, 0, 0);
    ArmWatcher();
}

void ArmWatcher() {
    if (g.dir == INVALID_HANDLE_VALUE) {
        g.dir = CreateFileW(ThemesDir().c_str(), FILE_LIST_DIRECTORY, FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING,
                            FILE_FLAG_BACKUP_SEMANTICS | FILE_FLAG_OVERLAPPED, nullptr);
        if (g.dir == INVALID_HANDLE_VALUE) return;
    }
    ReadDirectoryChangesW(g.dir, g.buf, sizeof(g.buf), FALSE, FILE_NOTIFY_CHANGE_LAST_WRITE | FILE_NOTIFY_CHANGE_FILE_NAME | FILE_NOTIFY_CHANGE_SIZE,
                          nullptr, &g.ov, OnDirChange);
}

// ---------------------------------------------------------------------------
// Status and commands.

std::wstring StatusText() {
    auto& a = g.analysis;
    wchar_t buf[2048];
    swprintf_s(buf,
               L"windows=%s\nenabled=%d\nstate=%s\nstartup=%d\nlightMode=%d\ntranslucenttb.installed=%d\ntranslucenttb.running=%d\n"
               L"wallpaper=%s\nfamily=%s\nfamily2=%s\nconfidence=%.2f\nbrightnessBehindTaskbar=%.2f\nanalysisMs=%u\n"
               L"tint=%s\naccent=%s\naccent2=%s\nglass=%.0f%%\nglassBusy=%.0f%%\nreadabilityRaised=%d\nblur=%d\n",
               WindowsBuild().c_str(), g.settings.enabled, g.state.c_str(), IsStartupEnabled(), LightMode(), !TranslucentTBSettingsPath().empty(),
               TranslucentTBRunning(), g.wallpaperSource.c_str(), a.family.c_str(), a.family2.c_str(), a.confidence, a.lumTaskbar, a.ms,
               ColorHex(g.look.tint).c_str(), ColorHex(g.look.accent).c_str(), ColorHex(g.look.accent2).c_str(), g.look.alpha * 100, g.look.alphaBusy * 100,
               g.look.guarded, g.settings.blur);
    return buf;
}

void HandleCommand(uint32_t cmd, HWND replyTo) {
    switch (cmd) {
        case HostReload:
            g.settings = LoadSettings();
            Apply();
            break;
        case HostRestore:
            g.settings = LoadSettings();
            g.settings.enabled = false;
            SaveSettings(g.settings);
            Restore();
            break;
        case HostExit:
            Restore();
            Log(L"exit requested");
            DestroyWindow(g.hwnd);
            break;
        case HostReanalyze:
            Analyze();
            Apply();
            break;
        case HostStatus:
            if (replyTo) {
                std::wstring text = StatusText();
                COPYDATASTRUCT cds{MsgStatus, static_cast<DWORD>((text.size() + 1) * sizeof(wchar_t)), const_cast<wchar_t*>(text.c_str())};
                DWORD_PTR r;
                SendMessageTimeoutW(replyTo, WM_COPYDATA, reinterpret_cast<WPARAM>(g.hwnd), reinterpret_cast<LPARAM>(&cds), SMTO_ABORTIFHUNG, 2000, &r);
            }
            break;
    }
}

LRESULT CALLBACK WndProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    switch (msg) {
        case WM_COPYDATA: {
            auto cds = reinterpret_cast<COPYDATASTRUCT*>(lp);
            HWND replyTo = nullptr;
            if (cds->cbData >= sizeof(ReplyTo)) replyTo = reinterpret_cast<HWND>(static_cast<ReplyTo*>(cds->lpData)->hwnd);
            PostMessageW(hwnd, WM_APP_COMMAND, cds->dwData, reinterpret_cast<LPARAM>(replyTo));  // answer the sender immediately
            return TRUE;
        }
        case WM_APP_COMMAND:
            HandleCommand(static_cast<uint32_t>(wp), reinterpret_cast<HWND>(lp));
            return 0;
        case WM_APP_WALLPAPER:
            SetTimer(hwnd, TimerWallpaper, 600, nullptr);  // the file is written in several steps
            return 0;
        case WM_TIMER:
            KillTimer(hwnd, wp);
            Analyze();
            Apply();
            return 0;
        case WM_SETTINGCHANGE:
            if (lp && wcscmp(reinterpret_cast<const wchar_t*>(lp), L"ImmersiveColorSet") == 0) Apply();
            if (wp == SPI_SETDESKWALLPAPER) SetTimer(hwnd, TimerWallpaper, 600, nullptr);
            return 0;
        case WM_DISPLAYCHANGE:
            SetTimer(hwnd, TimerWallpaper, 1000, nullptr);  // new geometry: re-measure behind the taskbar
            return 0;
        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

}  // namespace

int RunBackground() {
    HANDLE mutex = CreateMutexW(nullptr, TRUE, kSingleInstanceMutex);
    if (GetLastError() == ERROR_ALREADY_EXISTS) return 0;  // already running

    EnsureDir(DataDir());
    RotateLog();
    Log(L"host start, Windows %s", WindowsBuild().c_str());

    WNDCLASSEXW wc{sizeof(wc)};
    wc.lpfnWndProc = WndProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kHostWindowClass;
    RegisterClassExW(&wc);
    // Hidden top-level window (never shown) so broadcasts like WM_SETTINGCHANGE reach us.
    g.hwnd = CreateWindowExW(WS_EX_TOOLWINDOW, kHostWindowClass, L"SaiyanGlass", WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, wc.hInstance, nullptr);
    if (!g.hwnd) return 1;

    g.settings = LoadSettings();
    Analyze();
    Apply();
    Log(L"state: %s", g.state.c_str());
    ArmWatcher();
    SetProcessWorkingSetSize(GetCurrentProcess(), static_cast<SIZE_T>(-1), static_cast<SIZE_T>(-1));  // drop start-up pages

    for (;;) {
        MsgWaitForMultipleObjectsEx(0, nullptr, INFINITE, QS_ALLINPUT, MWMO_ALERTABLE | MWMO_INPUTAVAILABLE);
        MSG m;
        while (PeekMessageW(&m, nullptr, 0, 0, PM_REMOVE)) {
            if (m.message == WM_QUIT) {
                if (g.dir != INVALID_HANDLE_VALUE) CancelIoEx(g.dir, nullptr), CloseHandle(g.dir);
                ReleaseMutex(mutex);
                CloseHandle(mutex);
                return 0;
            }
            DispatchMessageW(&m);
        }
    }
}

}  // namespace sg
