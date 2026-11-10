# Security Policy

## Supported versions

| Version | Supported |
|---------|-----------|
| Latest (`main`) | ✅ |
| Older commits | ❌ |

Always use the latest version via the one-liner install.

## What this project does

GSInstalled downloads and runs PowerShell code from GitHub. It:

- Downloads files to `~\.get-shit-installed\`
- Patches your PowerShell `$PROFILE` with a `gsi` function
- Installs applications through **WinGet** only — it never downloads and executes arbitrary URLs from the catalog
- Optionally removes old application versions from the registry (after explicit typed confirmation)

**Read [`install.ps1`](install.ps1) and [`get-shit-installed.ps1`](get-shit-installed.ps1) before running them.** Both are short and plain PowerShell — no obfuscation.

## Reporting a vulnerability

If you discover a security vulnerability, **please do not open a public Issue.**

Instead, report it privately:

1. Go to the **Security** tab of this repo → **Report a vulnerability**
2. Or contact the maintainer directly via GitHub: [@iabhnv19](https://github.com/iabhnv19)

Please include:

- A description of the vulnerability
- Steps to reproduce it
- Potential impact

You will receive a response within **48 hours**. If the report is confirmed, a fix will be prioritized and a patched version released as soon as possible.

## Security best practices for users

- **Always read scripts before running them**, especially one-liners from the internet.
- Run only the `main` branch URL — not forks or unknown mirrors.
- If your machine is managed (work/school), consult your IT department before running.
