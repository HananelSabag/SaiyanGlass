# SaiyanGlass

A liquid-glass taskbar that follows the wallpaper: each time the Dragon Ball
slideshow changes, SaiyanGlass measures the new image and adjusts the glass so
it picks up a hint of its color and the taskbar text stays readable.

## How it works

```
wallpaper changes ──> SaiyanGlass.exe (background, no window)
                        │  samples the wallpaper (WIC, OKLCH)
                        │  computes tint, darkening, blur
                        ▼
                      TranslucentTB settings.json ──> TranslucentTB draws the taskbar
```

- **SaiyanGlass.exe**: the background host. It sleeps until something happens:
  the wallpaper file changes (`ReadDirectoryChangesW`), light/dark mode or the
  display changes, or a command arrives from the settings window. There is no
  polling and no timer loop. It writes TranslucentTB's settings only when the
  result differs.
- **SaiyanGlassSettings.exe**: the control window (XAML Islands, dark, high-DPI).
  It runs only while open.
- **TranslucentTB** (free, Microsoft Store) draws the taskbar. SaiyanGlass never
  loads anything into Explorer or Start.

### The glass

- **Readability guard**: measures the brightness of the wallpaper area behind the
  taskbar (mean plus 90th percentile of blocks) and darkens only as much as
  needed for 4.5:1 contrast of white text, capped at 60%.
- **Tint**: the dominant hue family of the art (gold, crimson, blue, violet,
  green), with skin tones damped, carried only as a hint in the glass. Warm
  hues get less hue so the glass never turns brown.
- With a maximized window or with Start or search open, the glass gets a bit
  denser.

## Build

Requires Visual Studio 2022+ or Build Tools with `VC.Tools.x86.x64` and a
Windows 11 SDK.

```powershell
.\build.ps1            # out\Release
.\build.ps1 -Install   # build and install for the current user
```

## Install, restore, remove

| What | How |
| --- | --- |
| Install | `SaiyanGlass.exe --install` copies the program to `%LOCALAPPDATA%\Programs\SaiyanGlass`, adds Start menu shortcuts and a per-user startup entry, and starts the host. No admin needed. |
| Restore previous look | Start menu > SaiyanGlass > **Restore previous look**, or `SaiyanGlass.exe --restore`. Puts back the TranslucentTB settings you had before (`settings.before-saiyanglass.json`). Works even if the host is not running. |
| Turn back on | `SaiyanGlass.exe --enable` |
| Startup only | `SaiyanGlass.exe --startup on` or `--startup off` (or Task Manager > Startup apps) |
| Status | `SaiyanGlass.exe --status` |
| Uninstall | `SaiyanGlass.exe --uninstall [--keep-settings]` |

What SaiyanGlass changes on the system: its own files, the `HKCU\...\Run\SaiyanGlass`
value, two Start menu shortcuts, and TranslucentTB's `settings.json` (backed up
first). It does not touch Windows personalization, the wallpapers or the slideshow.

## Limits

- The Start menu keeps Windows' own acrylic. Styling it would require loading
  code into StartMenuExperienceHost, which this project deliberately doesn't do.
- While SaiyanGlass is on, it owns the TranslucentTB look. Changes made in
  TranslucentTB's own menu are overwritten at the next wallpaper change.

## Repository

- `src/host`: background host and command line
- `src/settings`: settings window
- `src/common`: settings file shared by both
- `tools/measure.ps1`: performance measurement (CPU, memory, GPU of the shell processes)
- `bench/results`: measurements (`baseline-*` were taken before anything was installed)
- `prototype`: the visual and color-analysis prototype used to design the look
