# GSInstalled

A PowerShell-based, terminal software installer for Windows. It uses WinGet for standard packages and keeps a JSON catalog so applications can be added without changing the installer engine.

## One-line Install

Open **PowerShell** and run:

```powershell
irm https://raw.githubusercontent.com/iabhnv19/GSInstalled/main/install.ps1 | iex
```

This will:
- Download the installer to `~\.get-shit-installed\`
- Register a `gsi` command in your PowerShell profile
- Launch the interactive menu immediately

After that, open any new PowerShell window and type:

```powershell
gsi
```

## Requirements

- Windows 10 (recent supported build) or Windows 11
- PowerShell 5.1 or PowerShell 7
- WinGet (Microsoft App Installer) for WinGet-managed packages
- Internet access

## Manual Run

If you prefer to clone and run locally:

```powershell
git clone https://github.com/iabhnv19/GSInstalled.git
cd GSInstalled
Set-ExecutionPolicy -Scope Process Bypass
.\get-shit-installed.ps1
```

Useful command-line options:

```powershell
.\get-shit-installed.ps1 -List
.\get-shit-installed.ps1 -Update
.\get-shit-installed.ps1 -Search Python
```

## Selection

- Enter application numbers separated by commas, e.g. `1,3,5`
- `A` selects all entries in the current list
- `N` selects none
- `Q` goes back
- Installation requires a separate confirmation

## Catalog

Edit `data/applications.json` to add or modify entries.

- `type: winget`: requires an exact WinGet package ID in `id`.
- `type: custom`: handled by a reviewed custom action in the script.
- `type: manual`: displays instructions/source URL but does not execute an installer.

Package IDs can change or be unavailable by region/source. Verify with:

```powershell
winget search "application name"
winget show --id PACKAGE.ID --exact
```

## Important Notes

- **GCC** entry installs MSYS2 only. Open the MSYS2 UCRT64 terminal and install GCC with:
  `pacman -S --needed mingw-w64-ucrt-x86_64-gcc`
- **WSL2** may require administrator privileges, virtualization support, and a restart.
- **Docker Desktop** requires WSL2 or a supported Hyper-V configuration.
- **JupyterLab** is listed as a manual Python package install: `py -m pip install jupyterlab`
- **TLauncher** is a manual entry. Review third-party software carefully before installing it.
- WinGet uninstall support varies by package. Review each application's data-retention behavior before uninstalling.
- The installer does not bypass UAC or silently elevate itself.

## Logs

Runtime logs are saved in `logs/`. Installation summaries are appended to `logs/history.csv`.

## Safety

Review the catalog and package IDs before installing. This project invokes WinGet and a small, explicit WSL command. It does not download and execute arbitrary URLs from the catalog.

## Old-Version Cleanup

The menu includes **Find / remove old application versions**. It scans Windows uninstall registry records for duplicate application names with different versions, keeps the newest detected version, and offers older entries for review.

- MSI packages with a recognized Windows Installer product GUID can be removed through `msiexec` after an explicit typed confirmation.
- EXE/vendor-specific uninstallers are not executed automatically because their silent switches and behavior differ. Remove those through Windows Settings > Apps > Installed apps.
- Detection is heuristic. Side-by-side versions may be intentional, and not every application's leftover update/cache files appear in uninstall records.
- Review every candidate before removal. This is not a general-purpose disk/cache cleaner.

## Keyboard Navigation

The interactive menus support keyboard navigation:

- **Up / Down arrows**: move through menu items or applications (within a column)
- **Space**: toggle an application selection
- **Enter**: confirm the current selection
- **Esc**: go back or exit the current menu
- **A**: select all applications in the current list
- **N**: clear the current selection

The application list is shown in **multiple columns** (up to 4, chosen from your terminal width), filled top-to-bottom. If it still does not fit, it is split into pages.

- **Left / Right arrows**: jump between columns
- **PageUp / PageDown**: switch pages
- **Home / End**: first / last app

## Smooth Terminal Rendering

The interactive menus use incremental console updates. Only the previous and current selection rows are repainted; the visible list is redrawn only when scrolling.

## License

[MIT](LICENSE)
