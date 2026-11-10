# Contributing to GSInstalled

Thank you for taking the time to contribute! 🎉

## Ways to contribute

- **Add apps to the catalog** — the most common contribution
- **Report bugs** — via GitHub Issues
- **Suggest features** — open an Issue with the `enhancement` label
- **Fix bugs / improve the script** — open a Pull Request

---

## Adding apps to the catalog

The app catalog lives in [`data/applications.json`](data/applications.json). Each entry looks like this:

```json
{
  "name": "App Name",
  "category": "Category Name",
  "type": "winget",
  "id": "Publisher.AppName",
  "description": "One-line description"
}
```

### Entry types

| Type | When to use |
|------|-------------|
| `winget` | App is available via `winget install --id <id> --exact` |
| `manual` | No winget package — provide instructions in `description` |
| `custom` | Requires a special install path — discuss in an Issue first |

### Before opening a PR for a new app

1. Verify the WinGet ID is correct and available:
   ```powershell
   winget search "app name"
   winget show --id Publisher.AppName --exact
   ```
2. Test the install on a clean machine or VM if possible.
3. Check the app isn't already in the catalog.
4. Keep `description` short (one line, no period at the end).

---

## Reporting bugs

Open an [Issue](../../issues/new?template=bug_report.md) and include:

- Windows version (`winver`)
- PowerShell version (`$PSVersionTable.PSVersion`)
- The full error message
- Steps to reproduce

---

## Pull Request process

1. Fork the repo and create a branch: `git checkout -b feat/my-change`
2. Make your changes.
3. Test locally:
   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\get-shit-installed.ps1
   ```
4. Open a PR against `main` with a clear description of what changed and why.
5. Keep PRs focused — one feature or fix per PR.

---

## Code style

- PowerShell: use `PascalCase` for functions, `$camelCase` for local variables
- JSON: 2-space indent, keep entries alphabetical within a category
- Comments should explain *why*, not *what*

---

## Need help?

Open an [Issue](../../issues) and tag it `question`. We're happy to help.
