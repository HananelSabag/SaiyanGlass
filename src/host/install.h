#pragma once
#include <windows.h>

#include <string>

namespace sg {

// Startup is a per-user Run value. Task Manager's "Startup apps" switch writes
// StartupApproved\Run; a disabled entry there counts as off.
bool IsStartupEnabled();
bool SetStartup(bool on);

// Copies the binaries to %LOCALAPPDATA%\Programs\SaiyanGlass, creates the Start
// menu shortcuts, registers startup and starts the host.
int Install();

// Restores the shell, removes startup, shortcuts, binaries and (unless
// keepSettings) the data folder. DLLs still mapped in a running shell process
// are removed at the next sign-in by a one-time RunOnce entry.
int Uninstall(bool keepSettings);

HWND FindHost();
bool StartHost();  // starts "<ProgramDir or ExeDir>\SaiyanGlass.exe --background"

}  // namespace sg
