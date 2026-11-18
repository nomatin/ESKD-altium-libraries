# Component Browser Setup

1. Close Altium Designer.
2. Double-click `configure_component_browser.cmd`.
3. Once setup completes successfully, open Altium.

The utility configures the visible columns for both the ESKD and IEC libraries. Python and administrator privileges are not required.

**Settings are backed up automatically before every change** to `Backup/ComponentBrowser/`. If the backup cannot be saved, no settings are changed. If applying the settings fails, the previous settings are restored automatically.

**Restore:** close Altium and run `restore_component_browser.cmd` to restore the latest backup created before applying settings. To select another backup, drag its `settings.json` onto this CMD file. The current settings are also backed up before restoration.
