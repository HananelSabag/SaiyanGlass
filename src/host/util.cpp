#include "util.h"

#include <aclapi.h>
#include <sddl.h>
#include <shlobj.h>
#include <tlhelp32.h>

#include <cstdarg>
#include <cstdio>

namespace sg {

void Out(const wchar_t* fmt, ...) {
    wchar_t buf[2048];
    va_list ap;
    va_start(ap, fmt);
    int n = _vsnwprintf_s(buf, _TRUNCATE, fmt, ap);
    va_end(ap);
    if (n < 0) n = static_cast<int>(wcslen(buf));

    HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
    DWORD type = h && h != INVALID_HANDLE_VALUE ? GetFileType(h) : FILE_TYPE_UNKNOWN;
    if (type == FILE_TYPE_PIPE || type == FILE_TYPE_DISK) {
        std::string u = ToUtf8(std::wstring(buf, n));
        DWORD written;
        WriteFile(h, u.data(), static_cast<DWORD>(u.size()), &written, nullptr);
        return;
    }
    static bool attached = AttachConsole(ATTACH_PARENT_PROCESS) != FALSE;
    if (attached) {
        DWORD written;
        WriteConsoleW(GetStdHandle(STD_OUTPUT_HANDLE), buf, n, &written, nullptr);
    }
}

std::wstring ExeDir() {
    wchar_t path[MAX_PATH];
    DWORD n = GetModuleFileNameW(nullptr, path, MAX_PATH);
    std::wstring s(path, n);
    return s.substr(0, s.find_last_of(L'\\'));
}

std::wstring LocalAppData() {
    PWSTR p = nullptr;
    std::wstring s;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &p))) s = p;
    CoTaskMemFree(p);
    return s;
}

std::wstring DataDir() { return LocalAppData() + L"\\SaiyanGlass"; }
std::wstring ProgramDir() { return LocalAppData() + L"\\Programs\\SaiyanGlass"; }

bool EnsureDir(const std::wstring& path) {
    int r = SHCreateDirectoryExW(nullptr, path.c_str(), nullptr);
    return r == ERROR_SUCCESS || r == ERROR_ALREADY_EXISTS || r == ERROR_FILE_EXISTS;
}

std::wstring ProcessName(DWORD pid) {
    std::wstring name;
    if (HANDLE p = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid)) {
        wchar_t path[MAX_PATH];
        DWORD n = MAX_PATH;
        if (QueryFullProcessImageNameW(p, 0, path, &n)) {
            name.assign(path, n);
            name = name.substr(name.find_last_of(L'\\') + 1);
        }
        CloseHandle(p);
    }
    return name;
}

DWORD FindProcess(const wchar_t* exeName) {
    DWORD session = 0;
    ProcessIdToSessionId(GetCurrentProcessId(), &session);
    DWORD found = 0;
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap == INVALID_HANDLE_VALUE) return 0;
    PROCESSENTRY32W pe{sizeof(pe)};
    for (BOOL ok = Process32FirstW(snap, &pe); ok; ok = Process32NextW(snap, &pe)) {
        DWORD s = 0;
        if (_wcsicmp(pe.szExeFile, exeName) == 0 && ProcessIdToSessionId(pe.th32ProcessID, &s) && s == session) {
            found = pe.th32ProcessID;
            break;
        }
    }
    CloseHandle(snap);
    return found;
}

std::string ToUtf8(const std::wstring& s) {
    if (s.empty()) return {};
    int n = WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0, nullptr, nullptr);
    std::string r(n, '\0');
    WideCharToMultiByte(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), r.data(), n, nullptr, nullptr);
    return r;
}

std::wstring FromUtf8(const std::string& s) {
    if (s.empty()) return {};
    int n = MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), nullptr, 0);
    std::wstring r(n, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, s.data(), static_cast<int>(s.size()), r.data(), n);
    return r;
}

}  // namespace sg
