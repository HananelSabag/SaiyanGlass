#pragma once
#include <windows.h>

#include <cstdint>
#include <string>
#include <vector>

namespace sg {

// Writes to stdout when it is redirected (scripts, CI), otherwise to the
// console of the parent process if there is one. The host is a GUI-subsystem
// program so that starting it at sign-in never flashes a console window.
void Out(const wchar_t* fmt, ...);

std::wstring ExeDir();
std::wstring LocalAppData();
std::wstring DataDir();       // %LOCALAPPDATA%\SaiyanGlass
std::wstring ProgramDir();    // %LOCALAPPDATA%\Programs\SaiyanGlass
bool EnsureDir(const std::wstring& path);

std::wstring ProcessName(DWORD pid);
DWORD FindProcess(const wchar_t* exeName);  // first match in this session, 0 if none

std::string ToUtf8(const std::wstring& s);
std::wstring FromUtf8(const std::string& s);

}  // namespace sg
