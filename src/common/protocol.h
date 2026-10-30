// Messages between SaiyanGlass.exe (host / command line) and
// SaiyanGlassSettings.exe. Transport: WM_COPYDATA to the host's hidden window;
// dwData carries the command, lpData the payload.
#pragma once
#include <cstdint>

namespace sg {

inline constexpr wchar_t kHostWindowClass[] = L"SaiyanGlass.Host";
inline constexpr wchar_t kSingleInstanceMutex[] = L"Local\\SaiyanGlass.Host.SingleInstance";

enum Command : uint32_t {
    // settings / command line -> host
    HostReload = 201,     // re-read settings.ini and apply
    HostRestore = 202,    // put back the look from before SaiyanGlass, set enabled=0, keep running
    HostExit = 203,       // restore and exit
    HostStatus = 204,     // payload: ReplyTo. Host answers with MsgStatus.
    HostReanalyze = 205,  // sample the wallpaper again now

    // host -> settings / command line
    MsgStatus = 101,  // UTF-16 text, key=value lines
};

struct ReplyTo {
    uint64_t hwnd;
};

}  // namespace sg
