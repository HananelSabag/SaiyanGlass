// SaiyanGlass.exe - background host and command line.
//
//   SaiyanGlass.exe                 open the settings window (starts the host if needed)
//   SaiyanGlass.exe --background    the host itself (what runs at sign-in)
//   SaiyanGlass.exe --restore       put back the look from before SaiyanGlass and turn it off
//   SaiyanGlass.exe --enable        turn it back on
//   SaiyanGlass.exe --startup on|off
//   SaiyanGlass.exe --status
//   SaiyanGlass.exe --install | --uninstall [--keep-settings]
//   SaiyanGlass.exe --analyze <image>   print the analysis of an image
//   SaiyanGlass.exe --exit
#include <windows.h>
#include <objbase.h>
#include <shellapi.h>

#include <string>

#include "../common/protocol.h"
#include "../common/settings.h"
#include "accent.h"
#include "host.h"
#include "install.h"
#include "ipc.h"
#include "translucenttb.h"
#include "util.h"

using namespace sg;

namespace {

// Works even when the host is gone or hung: then it restores the file itself.
int RunRestore() {
    Settings s = LoadSettings();
    s.enabled = false;
    SaveSettings(s);
    bool viaHost = false;
    if (HWND host = FindHost()) {
        viaHost = SendCommand(host, HostRestore, nullptr, 0);
        if (!viaHost) {
            DWORD pid = 0;
            GetWindowThreadProcessId(host, &pid);
            if (HANDLE p = OpenProcess(PROCESS_TERMINATE, FALSE, pid)) {
                TerminateProcess(p, 1);
                CloseHandle(p);
            }
        }
    }
    Sleep(300);
    std::wstring error;
    bool ok = RestoreTranslucentTB(error);
    Out(L"%s; run --enable to turn SaiyanGlass back on\n", ok ? L"restored your previous taskbar look" : error.c_str());
    return ok ? 0 : 1;
}

int RunEnable() {
    Settings s = LoadSettings();
    s.enabled = true;
    SaveSettings(s);
    if (HWND host = FindHost()) {
        SendCommand(host, HostReload, nullptr, 0);
        Out(L"enabled\n");
        return 0;
    }
    bool ok = StartHost();
    Out(L"enabled, host %s\n", ok ? L"started" : L"FAILED to start");
    return ok ? 0 : 1;
}

int RunStatus() {
    HWND host = FindHost();
    if (!host) {
        Out(L"host: not running\nstartup=%d\n", IsStartupEnabled());
        return 1;
    }
    ReplyWindow reply;
    ReplyTo r{reinterpret_cast<uint64_t>(reply.hwnd())};
    SendCommand(host, HostStatus, &r, sizeof(r), reply.hwnd());
    std::wstring text;
    reply.WaitFor(MsgStatus, 5000, text);
    Out(L"%s", text.c_str());
    return 0;
}

int RunAnalyze(const wchar_t* file) {
    SIZE screen{GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN)};
    RECT start{(screen.cx - 858) / 2, screen.cy - 48 - 12 - 890, (screen.cx + 858) / 2, screen.cy - 48 - 12};
    auto a = AnalyzeImage(file, screen, 48, start);
    if (!a.ok) {
        Out(L"cannot decode %s\n", file);
        return 1;
    }
    auto look = BuildLook(LoadSettings(), a, false);
    Out(L"family=%s%s%s confidence=%.2f brightnessBehindTaskbar=%.3f ms=%u tint=%s glass=%.0f%% busy=%.0f%%\n", a.family.c_str(),
        a.hasSecond ? L" second=" : L"", a.family2.c_str(), a.confidence, a.lumTaskbar, a.ms, ColorHex(look.tint).c_str(), look.alpha * 100,
        look.alphaBusy * 100);
    return 0;
}

int OpenSettings() {
    if (!FindHost()) StartHost();
    std::wstring exe = ExeDir() + L"\\SaiyanGlassSettings.exe";
    return reinterpret_cast<INT_PTR>(ShellExecuteW(nullptr, L"open", exe.c_str(), nullptr, nullptr, SW_SHOWNORMAL)) > 32 ? 0 : 1;
}

}  // namespace

int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
    int argc = 0;
    PWSTR* argv = CommandLineToArgvW(GetCommandLineW(), &argc);
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    std::wstring cmd = argc > 1 ? argv[1] : L"";
    auto arg = [&](int i) { return argc > i ? std::wstring(argv[i]) : std::wstring(); };
    int rc = 0;

    if (cmd.empty() || cmd == L"--settings")
        rc = OpenSettings();
    else if (cmd == L"--background")
        rc = RunBackground();
    else if (cmd == L"--restore")
        rc = RunRestore();
    else if (cmd == L"--enable")
        rc = RunEnable();
    else if (cmd == L"--startup" && (arg(2) == L"on" || arg(2) == L"off")) {
        bool ok = SetStartup(arg(2) == L"on");
        Out(L"startup %s: %s\n", arg(2).c_str(), ok ? L"ok" : L"failed");
        rc = ok ? 0 : 1;
    } else if (cmd == L"--status")
        rc = RunStatus();
    else if (cmd == L"--install")
        rc = Install();
    else if (cmd == L"--uninstall")
        rc = Uninstall(arg(2) == L"--keep-settings");
    else if (cmd == L"--analyze" && argc > 2)
        rc = RunAnalyze(argv[2]);
    else if (cmd == L"--exit") {
        if (HWND h = FindHost()) SendCommand(h, HostExit, nullptr, 0);
    } else
        Out(L"usage: SaiyanGlass [--background | --restore | --enable | --startup on|off | --status | --install | --uninstall [--keep-settings] | "
            L"--analyze <image> | --exit]\n");

    CoUninitialize();
    LocalFree(argv);
    return rc;
}
