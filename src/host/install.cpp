#include "install.h"

#include <shlobj.h>
#include <shobjidl.h>

#include <cwchar>

#include "../common/protocol.h"
#include "../common/settings.h"
#include "ipc.h"
#include "translucenttb.h"
#include "util.h"

namespace sg {
namespace {

constexpr wchar_t kRunKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
constexpr wchar_t kApprovedKey[] = L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved\\Run";
constexpr wchar_t kRunValue[] = L"SaiyanGlass";
const wchar_t* kFiles[] = {L"SaiyanGlass.exe", L"SaiyanGlassSettings.exe"};

std::wstring HostExePath() {
    std::wstring installed = ProgramDir() + L"\\SaiyanGlass.exe";
    if (GetFileAttributesW(installed.c_str()) != INVALID_FILE_ATTRIBUTES) return installed;
    return ExeDir() + L"\\SaiyanGlass.exe";
}

std::wstring ShortcutDir() {
    PWSTR p = nullptr;
    std::wstring dir;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Programs, 0, nullptr, &p))) dir = std::wstring(p) + L"\\SaiyanGlass";
    CoTaskMemFree(p);
    return dir;
}

bool MakeShortcut(const std::wstring& lnk, const std::wstring& target, const wchar_t* args, const wchar_t* description) {
    IShellLinkW* link = nullptr;
    if (FAILED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&link)))) return false;
    link->SetPath(target.c_str());
    link->SetArguments(args);
    link->SetDescription(description);
    link->SetWorkingDirectory(ProgramDir().c_str());
    link->SetIconLocation(target.c_str(), 0);
    IPersistFile* file = nullptr;
    bool ok = SUCCEEDED(link->QueryInterface(IID_PPV_ARGS(&file))) && SUCCEEDED(file->Save(lnk.c_str(), TRUE));
    if (file) file->Release();
    link->Release();
    return ok;
}

void StopHost() {
    HWND host = FindHost();
    if (!host) return;
    DWORD pid = 0;
    GetWindowThreadProcessId(host, &pid);
    SendCommand(host, HostExit, nullptr, 0);
    if (HANDLE p = OpenProcess(SYNCHRONIZE | PROCESS_TERMINATE, FALSE, pid)) {
        if (WaitForSingleObject(p, 8000) == WAIT_TIMEOUT) TerminateProcess(p, 1);
        CloseHandle(p);
    }
}

}  // namespace

HWND FindHost() { return FindWindowW(kHostWindowClass, nullptr); }

bool StartHost() {
    std::wstring exe = HostExePath();
    std::wstring cmd = L"\"" + exe + L"\" --background";
    STARTUPINFOW si{sizeof(si)};
    PROCESS_INFORMATION pi{};
    if (!CreateProcessW(exe.c_str(), cmd.data(), nullptr, nullptr, FALSE, DETACHED_PROCESS, nullptr, nullptr, &si, &pi)) return false;
    CloseHandle(pi.hThread);
    CloseHandle(pi.hProcess);
    for (int i = 0; i < 50 && !FindHost(); ++i) Sleep(100);
    return FindHost() != nullptr;
}

bool IsStartupEnabled() {
    wchar_t value[MAX_PATH * 2] = {};
    DWORD size = sizeof(value);
    if (RegGetValueW(HKEY_CURRENT_USER, kRunKey, kRunValue, RRF_RT_REG_SZ, nullptr, value, &size) != ERROR_SUCCESS) return false;
    BYTE approved[12] = {};
    DWORD asize = sizeof(approved);
    if (RegGetValueW(HKEY_CURRENT_USER, kApprovedKey, kRunValue, RRF_RT_REG_BINARY, nullptr, approved, &asize) == ERROR_SUCCESS && (approved[0] & 1))
        return false;  // disabled in Task Manager
    return true;
}

bool SetStartup(bool on) {
    HKEY run;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, kRunKey, 0, nullptr, 0, KEY_SET_VALUE, nullptr, &run, nullptr) != ERROR_SUCCESS) return false;
    LSTATUS st;
    if (on) {
        std::wstring cmd = L"\"" + HostExePath() + L"\" --background";
        st = RegSetValueExW(run, kRunValue, 0, REG_SZ, reinterpret_cast<const BYTE*>(cmd.c_str()), static_cast<DWORD>((cmd.size() + 1) * sizeof(wchar_t)));
        // Our own entry only: clear a "disabled" mark Task Manager may have left.
        HKEY approved;
        if (RegOpenKeyExW(HKEY_CURRENT_USER, kApprovedKey, 0, KEY_SET_VALUE, &approved) == ERROR_SUCCESS) {
            RegDeleteValueW(approved, kRunValue);
            RegCloseKey(approved);
        }
    } else {
        st = RegDeleteValueW(run, kRunValue);
        if (st == ERROR_FILE_NOT_FOUND) st = ERROR_SUCCESS;
    }
    RegCloseKey(run);
    return st == ERROR_SUCCESS;
}

int Install() {
    std::wstring dst = ProgramDir();
    EnsureDir(dst);
    if (_wcsicmp(ExeDir().c_str(), dst.c_str()) != 0) {
        StopHost();
        for (auto f : kFiles) {
            std::wstring from = ExeDir() + L"\\" + f, to = dst + L"\\" + f;
            if (!CopyFileW(from.c_str(), to.c_str(), FALSE)) {
                // A file still in use (e.g. by an old settings window): move it aside.
                MoveFileExW(to.c_str(), (to + L".old").c_str(), MOVEFILE_REPLACE_EXISTING);
                if (!CopyFileW(from.c_str(), to.c_str(), FALSE)) {
                    Out(L"install: cannot copy %s (%u)\n", f, GetLastError());
                    return 1;
                }
            }
        }
    }
    std::wstring sc = ShortcutDir();
    EnsureDir(sc);
    MakeShortcut(sc + L"\\SaiyanGlass.lnk", dst + L"\\SaiyanGlassSettings.exe", L"", L"SaiyanGlass settings");
    MakeShortcut(sc + L"\\Restore previous look.lnk", dst + L"\\SaiyanGlass.exe", L"--restore",
                 L"Turn SaiyanGlass off and put back your previous taskbar look");
    SetStartup(true);
    WritePrivateProfileStringW(L"install", L"programDir", dst.c_str(), (DataDir() + L"\\state.ini").c_str());
    WritePrivateProfileStringW(L"install", L"shortcuts", sc.c_str(), (DataDir() + L"\\state.ini").c_str());
    WritePrivateProfileStringW(L"install", L"runValue", L"HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run\\SaiyanGlass",
                               (DataDir() + L"\\state.ini").c_str());
    bool started = StartHost();
    Out(L"installed to %s, startup on, host %s\n", dst.c_str(), started ? L"running" : L"NOT running");
    return started ? 0 : 1;
}

int Uninstall(bool keepSettings) {
    StopHost();
    std::wstring error;
    RestoreTranslucentTB(error);
    SetStartup(false);
    std::wstring sc = ShortcutDir();
    DeleteFileW((sc + L"\\SaiyanGlass.lnk").c_str());
    DeleteFileW((sc + L"\\Restore previous look.lnk").c_str());
    RemoveDirectoryW(sc.c_str());

    // Files: whatever can't be deleted now (this exe, DLLs mapped in the
    // shell) goes at next sign-in.
    std::wstring dir = ProgramDir();
    std::wstring cleanup = L"cmd.exe /c rmdir /s /q \"" + dir + L"\"";
    if (!keepSettings) cleanup += L" & rmdir /s /q \"" + DataDir() + L"\"";
    HKEY once;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, L"Software\\Microsoft\\Windows\\CurrentVersion\\RunOnce", 0, nullptr, 0, KEY_SET_VALUE, nullptr, &once, nullptr) ==
        ERROR_SUCCESS) {
        RegSetValueExW(once, L"SaiyanGlassCleanup", 0, REG_SZ, reinterpret_cast<const BYTE*>(cleanup.c_str()),
                       static_cast<DWORD>((cleanup.size() + 1) * sizeof(wchar_t)));
        RegCloseKey(once);
    }
    std::wstring now = L"cmd.exe /c ping -n 3 127.0.0.1 >nul & " + cleanup.substr(8);
    STARTUPINFOW si{sizeof(si)};
    PROCESS_INFORMATION pi{};
    if (CreateProcessW(nullptr, now.data(), nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
    }
    Out(L"uninstalled: taskbar look restored, startup and shortcuts removed; files are being deleted\n");
    return 0;
}

}  // namespace sg
