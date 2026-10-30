# Windhawk setup (current look)

The look on this PC comes from three Windhawk mods. These scripts write their
settings (Windhawk keeps them under HKLM, so run elevated):

1. `apply-liquid-glass.ps1` - LiquidGlass theme for the Taskbar Styler and the Start Menu Styler.
2. `tune-taskbar.ps1` - on top of the theme: tray on the right edge, darker glass
   (70%) behind the weather and tray text so white text reads on white wallpapers
   too, semibold text, a glass bubble around each app icon, and the weather
   capsule mirrored to the left edge. Run it as:

   ```powershell
   .\tune-taskbar.ps1 -Mode final -WeatherShift '{{329.5-(containerGridWidth-sgRepW)/2}}'
   ```

   The shift follows the dock width, so the weather stays 12px from the left as
   apps open and close. `-Mode debug` prints the layout widths in the clock if it
   ever needs recalibrating (the 329.5 was measured on a 2560px-wide screen).

Translucent Windows (window glass) is installed but disabled: it made File
Explorer flat gray with black bars.

Undo: disable the mod in Windhawk, or uninstall Windhawk. Nothing outside
Windhawk's own settings is changed.

Idle cost measured on this PC (taskbar explorer process): ~0.1-0.2% CPU, the same
range as before any mod (0.18% after the final taskbar tuning); Windhawk itself
0% CPU, ~15 MB per process.

