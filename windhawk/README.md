# The look (Windhawk + desktop icons)

One command applies everything, asking once for elevation (Windhawk keeps mod
settings under HKLM):

```powershell
.\apply-look.ps1            # from the repo root
.\apply-look.ps1 -Restore   # puts the original desktop icons back
```

Re-run it when a Windows or app update resets something. The output goes to
`%TEMP%\saiyanglass-apply.log`.

## Pieces

- `glass.ps1` - the shared glass: dark glass (70% tint) behind anything with
  text, so white text reads on white wallpapers too, and light bubbles for items.
  Also `Set-WindhawkMod`, which writes a mod's settings and makes it reload.
- `apply-liquid-glass.ps1` - LiquidGlass2 theme for the Taskbar Styler and the
  Start Menu Styler.
- `tune-taskbar.ps1` - on top of the theme: tray on the right edge, dark glass
  and semibold text behind the clock, language and weather, a glass bubble around
  each app icon, the weather mirrored to the left edge, darker menus, tooltips
  and window previews, and fixes for two theme bugs that paint the keyboard
  layout panel and the snap layout suggestions red. The weather shift follows
  the dock width, so it stays 12px from the left as apps open and close;
  `-Mode debug` prints the layout widths in the clock if it ever needs
  recalibrating (the 329.5 in the default `-WeatherShift` was measured on a
  2560px-wide screen).
- `tune-shell.ps1` - File Explorer Styler (LiquidGlass theme, acrylic over the
  whole window, glass right-click menu, also on the desktop) and Notification
  Center Styler (LiquidGlass, dark glass panels with light item bubbles).
- `..\desktop\desktop-icons.ps1` - every desktop shortcut and folder, and the
  Recycle Bin, on a glass bubble; the shortcut arrow hidden. The icons are
  rendered once into `%LOCALAPPDATA%\SaiyanGlass\desktop-icons` (with the
  originals and a backup of every changed setting), so nothing runs afterwards.
  Loose files keep their own icons. A program update can rewrite its shortcut;
  re-run to put it back on glass.

Translucent Windows (window glass) is installed but disabled: it made File
Explorer flat gray with black bars.

Undo the Windhawk part by disabling the mods in Windhawk, or uninstalling it.

## Cost

Measured on this PC: explorer idles at 0.05-0.2% CPU, the same range as before
any mod (applying the desktop icons rebuilds the icon cache, about a minute of
~1%); Windhawk 0% CPU, ~15 MB per process; ShellExperienceHost, ShellHost and
Start 0% at idle.
