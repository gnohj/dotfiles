# DnD toggle Shortcuts

The DnD sketchybar widget's click action (`items/widgets/dnd-click.sh`) toggles Focus by running two macOS Shortcuts: **`FocusOn`** and **`FocusOff`**.

Focus _detection_ is shortcut-free (`items/widgets/dnd.sh` reads a Control Center preference), so the widget shows correct state on any machine with no setup. Only _toggling_ needs these shortcuts — macOS has no clean CLI to set Focus.

## To make toggling reproducible on a fresh machine

Export the two shortcuts into this folder (one time), commit them, and `run_once_after_import-focus-shortcuts.sh` will import whichever is missing on a new machine (one "Add Shortcut" click each).

1. Open **Shortcuts.app**
2. Select **FocusOn** → **File → Export…** → save as `FocusOn.shortcut` here (`~/.local/share/chezmoi/dot_config/sketchybar/shortcuts/`)
3. Repeat for **FocusOff** → `FocusOff.shortcut`
4. `cza` / commit

Each shortcut is a single **Set Focus** action (`is.workflow.actions.dnd.set`) with `Enabled = 1` (FocusOn) or `Enabled = 0` (FocusOff). Recreatable by hand in Shortcuts.app if the exports are ever lost.

Note: on personal Macs signed into the same Apple ID, these usually sync via iCloud automatically, making the import a no-op.
