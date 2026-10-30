# Windhawk setup (current look)

The look on this PC comes from three Windhawk mods. These scripts write their
settings (Windhawk keeps them under HKLM, so run elevated):

1. `apply-liquid-glass.ps1` - LiquidGlass theme for the Taskbar Styler and the Start Menu Styler.
2. `tune-taskbar.ps1` - on top of the theme: tray on the right edge, darker glass
   behind the weather and tray text, a glass bubble around each app icon, the
   weather capsule moved left, and Translucent Windows limited to File Explorer
   (system acrylic, no accent-colored controls).

Undo: disable the mod in Windhawk, or uninstall Windhawk. Nothing outside
Windhawk's own settings is changed.

Idle cost measured on this PC (taskbar explorer process): ~0.1-0.2% CPU, the same
range as before any mod; Windhawk itself 0% CPU, ~4 MB.
