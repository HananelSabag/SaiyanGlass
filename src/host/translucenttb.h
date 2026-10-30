// TranslucentTB draws the taskbar; SaiyanGlass decides how it should look and
// writes that into TranslucentTB's settings.json, which TranslucentTB reloads
// on its own. Before the first write the user's file is copied to
// settings.before-saiyanglass.json, and Restore copies it back.
#pragma once
#include <string>

#include "../common/settings.h"
#include "accent.h"

namespace sg {

// RoamingState\settings.json of the Microsoft Store package, empty if not installed.
std::wstring TranslucentTBSettingsPath();
bool TranslucentTBRunning();

// Returns false (with a reason) when TranslucentTB isn't installed or the file
// can't be written. Writes nothing if the content would not change.
bool ApplyToTranslucentTB(const Settings& s, const GlassLook& look, std::wstring& error);
bool RestoreTranslucentTB(std::wstring& error);

}  // namespace sg
