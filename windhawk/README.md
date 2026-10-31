# The look: one glass design system

Every surface (taskbar, Start, File Explorer, the right-click menus, quick
settings, notifications, the calendar, jump lists, the taskbar flyouts and
tooltips, and the desktop icons) is drawn from one set of tokens in
[`glass.ps1`](glass.ps1). Change a token there, re-run `apply-look.ps1`, and
every surface follows.

```powershell
.\apply-look.ps1            # from the repo root, one UAC prompt
.\apply-look.ps1 -Restore   # puts the original desktop icons back
```

Re-run it when a Windows or app update resets something. The output goes to
`%TEMP%\saiyanglass-apply.log`. Started from a packaged app (such as the Claude
desktop app) it relaunches itself through Explorer, because a packaged app's
writes to AppData and HKCU never reach the real ones.

## Roles

| Role | What it is | Where |
| --- | --- | --- |
| **Glass** | dark glass, `#B30B0C10` (70%), saturation 1.3; blur 10 on small surfaces, 18 on large ones | behind anything with text: taskbar capsules, Start, menus, tooltips, quick settings, notifications, previews, Alt+Tab |
| **Clear** | nearly clear glass, `#14090909`, blur 3 | the dock, which holds only icons |
| **Bubble** | white glass, `#30FFFFFF` to `#12FFFFFF` top to bottom | marks an item: controls and the app icons on the dock and the desktop carry one at rest; rows in lists and menus get one on hover |
| **Rim** | one 1px edge: `#90FFFFFF` at the top, `#1AFFFFFF` at the sides, `#45FFFFFF` at the bottom | every glass surface and every bubble |

70% dark glass gives white text about 3:1 on a white wallpaper, so text on
glass is SemiBold (the taskbar, menus, tooltips, Start's headers).

### States

| State | Item with a bubble | Row |
| --- | --- | --- |
| Rest | bubble | nothing |
| Hover | brighter bubble, `#4AFFFFFF` to `#22FFFFFF` | bubble |
| Pressed | dim bubble, `#1AFFFFFF` | dim bubble |
| Selected | | bubble |

Hover never grows an element and never uses the accent color. The themes' hover
scaling (Start, the tray icons) and their accent-colored hovers (Explorer,
quick settings) are replaced. Accent color stays only where it means "on".

### Corner radii

| Size | Radius | Used by |
| --- | --- | --- |
| Panel | 24 | Start, notification center, quick settings, calendar, dialogs, Alt+Tab, task view |
| Menu | 16 | menus, jump lists, flyouts, window previews, toasts, cards, Start's category boxes |
| Item | 12 | bubbles: dock icons, tiles, buttons, Start folders, desktop icons |
| Row | 8 | menu items, list items, Explorer tabs and sidebar items, thumbnails |
| Capsule | height / 2 | taskbar capsules, tooltips, search boxes, the address bar, section headers |

Nested shapes keep the same center: a row inside a 16px menu with 6-8px padding
gets 8.

### The desktop icon

A desktop icon can't blur the wallpaper behind it, so its bubble brings its
own glass: a base of the dark glass (`DesktopBase`), the bubble's fill and rim a
third stronger (`DesktopLift`), a sheen on the top half, a soft shadow and a
dark hairline that holds it on white wallpapers. Its radius is the item
radius scaled to the icon (12 of 40px). The `$design` version in
`desktop-icons.ps1` is part of each icon's file name; bump it after a change to
the bubble so Explorer's icon cache can't keep the old one.

## Pieces

- `glass.ps1`: the tokens, the brushes built from them, style helpers
  (`Get-SurfaceStyles`, `Get-BubbleStyles`, `Get-RowStyles`), the CSS versions
  for Start's search results, and `Set-WindhawkMod`, which writes a mod's
  settings under HKLM and makes Windhawk reload them.
- `tune-taskbar.ps1`: Taskbar Styler on the LiquidGlass2 theme. The dock with a
  bubble per app, the tray on the right edge, the weather capsule 12px from the
  left, menus, tooltips, window previews, the tray overflow, the volume display,
  Alt+Tab, task view and snap layouts. Also fixes two theme bugs that paint the
  keyboard layout panel and the snap layout suggestions red. The weather shift
  follows the dock width; `-Mode debug` prints the layout widths in the clock if
  it needs recalibrating (the 329.5 in `-WeatherShift` was measured on a
  2560px-wide screen).
- `tune-start.ps1`: Start Menu Styler on LiquidGlass2, brought in line with the
  rest: the panel glass and radius instead of the theme's thin glass and 50-62px
  corners, no glow ring, the nested glass containers flattened (items carry the
  bubbles), and the same tokens as CSS for the search results.
- `tune-shell.ps1`: File Explorer Styler (LiquidGlass, acrylic over the whole
  window) with the glass right-click menu, which also styles the desktop's;
  Notification Center Styler (LiquidGlass) for quick settings, notifications,
  the calendar, toasts and jump lists.
- `..\desktop\desktop-icons.ps1`: every desktop shortcut and folder, and the
  Recycle Bin, on a bubble; the shortcut arrow hidden (its blank icon keeps one
  pixel at alpha 1, a fully clear one punches a hole to the wallpaper). Icons
  are rendered once into `%LOCALAPPDATA%\SaiyanGlass\desktop-icons` with the
  originals and a backup of every changed setting. Loose files keep their own
  icons. A program update can rewrite its shortcut; re-run to put it back.

The themes themselves live in `C:\ProgramData\Windhawk\ModsSource\*.wh.cpp`
(`g_themeLiquidGlass2`, `g_themeLiquidGlass`, style constants at the end of each
theme). A user style with the same target, or a constant with the same name,
overrides the theme's value for that property only.

Not covered: the widgets board (no styling mod), the classic "Show more options"
menu (Win32), and window glass (Translucent Windows is installed but disabled:
it made File Explorer flat gray with black bars).

Undo the Windhawk part by disabling the mods in Windhawk, or uninstalling it.

## Cost

Measured on this PC after applying the system (2026-10-31, 30 s idle): explorer
0.10% CPU, Start 0.01%, ShellExperienceHost, ShellHost, SearchHost and Windhawk
0%. The same range as before any mod (0.05-0.2%). Nothing runs in the
background: the styles are set once and the icons are rendered once. Applying
the desktop icons rebuilds the icon cache, about a minute of ~1%.
