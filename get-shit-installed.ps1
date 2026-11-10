[CmdletBinding()]
param(
    [switch]$List,
    [switch]$Update,
    [string]$Search
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$CatalogPath = Join-Path $Root "data\applications.json"
$LogDir = Join-Path $Root "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$LogPath = Join-Path $LogDir ("get-shit-installed-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".log")

function Write-Log([string]$Message) {
    $line = "[{0}] {1}" -f (Get-Date -Format "HH:mm:ss"), $Message
    Add-Content -Path $LogPath -Value $line
}
function Pause-Menu { Write-Host ""; Read-Host "Press ENTER to continue" | Out-Null }
function Get-Catalog {
    if (-not (Test-Path $CatalogPath)) { throw "Catalog not found: $CatalogPath" }
    return @(Get-Content -Raw -Path $CatalogPath | ConvertFrom-Json)
}
function Test-WinGet {
    return [bool](Get-Command winget.exe -ErrorAction SilentlyContinue)
}
function Ensure-WinGet {
    if (-not (Test-WinGet)) {
        Write-Host "WinGet was not found. Install/update App Installer from Microsoft Store first." -ForegroundColor Red
        return $false
    }
    return $true
}
function Write-Banner {
    param([string]$Subtitle = "WINDOWS SOFTWARE INSTALLER")

    # NOTE: the art must live in a single-quoted here-string (@' ... '@).
    # The closing '@ MUST be at the very start of its line.
    $artText = @'
                              *$:::::::::::::::::::::::::::::::::::::$$$$$$:::***$$:
             :***%%%%###################%$$$$$$  ::::::::: :::   ::$$$$%####@@@@@@@@#@@@@@@@#####%%**
         :*%#@@@@####%%%%%%%%%%%%%%%%%%####@@@#%                 %#@@@@###%%%%%%%%%%%%%%%%%%%%%###@@@@%**:
      *%*%@@#$*:                            *%@@#              :#@@%*:                             *$@@#***:
    :%% *@@*  $                               *@@#:$$*$$$$$$$$*#@@*                                $ :@@% :$*:
   *%$* #@#     $                              *@@$$$::    $$$%@@*                                $   %@@**$$$:
   $$$$$#@%      $                             *@@$           $@@*                               $    *@#$$$$$:
    $$$$%@%       $$                           %@#            *@@#                              $     *@@$
       *@@%         $                         :@@% $*         *%@@*                           $$$     *@@*
       :@@#         $                         %@@$$$          :$#@#                           $$      *@@*
        #@@:       ::                        *@@$$$             $@@%                                  #@#
        *@@%                                *@@$$                $@@%                                *@@%
         %@@:                              :#@#                   %@@*                               %@@:
         :@@#                             *#@#:                    %@@*                             *@@%
          *@@%                           *@@%:                      %@@%:                          *@@%
           *@@#*                       *#@@$                         *@@@%:                     :*#@@#
            *%@@#%%****::  :::::***%%%#@@%*                           :%@@@#%%****:::::::****%%##@@#*
              :*%##@@@@@@@@@@@@@@@@@##%*:                                *%##@@@@@@@@@@@@@@@@@##%%*:::
              ::::**********************::                           :::::::***************:::::
'@

    # split into lines and drop empty ones
    $art = @($artText -split "`r?`n" | Where-Object { $_.Trim() -ne "" })
    $artWidth = ($art | Measure-Object -Property Length -Maximum).Maximum

    Write-Host ""
    if ([Console]::WindowWidth -gt $artWidth) {
        foreach ($line in $art) { Write-Host $line -ForegroundColor Yellow }
        Write-Host ""
        Write-Host ((" " * 20) + "G E T   S H I T   I N S T A L L E D") -ForegroundColor Yellow
    } else {
        # terminal too narrow for the logo
        Write-Host "  G E T   S H I T   I N S T A L L E D" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host ("  " + $Subtitle + "   |   Made with <3 by Abhinav") -ForegroundColor DarkGray
    Write-Host ""
}
function Show-Catalog {
    param([object[]]$Items)
    $i = 1
    foreach ($app in $Items) {
        $source = if ($app.type -eq "winget") { "WinGet" } elseif ($app.type -eq "custom") { "Custom" } else { "Manual" }
        Write-Host (" {0,2}. {1,-31} [{2}]" -f $i, $app.name, $source)
        $i++
    }
}

# ---- multi-column selection grid -------------------------------------------
# Items fill DOWN each column first (like `ls`), then continue in the next column.
# Columns are chosen automatically from the terminal width. If the list still
# does not fit on screen it is split into pages (PageUp / PageDown).
function Get-GridLayout {
    param([object[]]$Items)
    $width  = [Math]::Max(40, [Console]::WindowWidth - 1)
    $height = [Console]::WindowHeight
    $longest = [int](($Items | ForEach-Object { ([string]$_.name).Length } | Measure-Object -Maximum).Maximum)
    $minCap = [Math]::Min($longest, 22)

    # one cell = " > [x] " (7 chars) + name (cap chars) + 2 chars of gap
    $cols = 1
    $cap = [Math]::Max(10, [Math]::Min($longest, $width - 9))
    foreach ($c in 4, 3, 2) {
        $candidate = [int][Math]::Floor($width / $c) - 9
        if ($candidate -ge $minCap) {
            $cols = $c
            $cap = [Math]::Min($candidate, $longest)
            break
        }
    }
    $maxRows = [Math]::Max(5, [Math]::Min(20, $height - 11))
    $rows = [Math]::Min($maxRows, [int][Math]::Ceiling($Items.Count / $cols))
    return @{
        Cols = $cols; Rows = $rows; Cap = $cap
        CellWidth = $cap + 9
        PerPage = $rows * $cols
        Width = $width
        Top = 0; Page = 0
    }
}
function Write-GridCell {
    param([hashtable]$L, [object[]]$Items, [int]$Index, [hashtable]$Selected, [int]$Cursor)
    if ([int][Math]::Floor($Index / $L.PerPage) -ne $L.Page) { return }
    $pos = $Index % $L.PerPage
    $col = [int][Math]::Floor($pos / $L.Rows)
    $row = $pos % $L.Rows
    $name = [string]$Items[$Index].name
    if ($name.Length -gt $L.Cap) { $name = $name.Substring(0, $L.Cap - 2) + ".." }
    $isSel = $Selected.ContainsKey([string]$Index)
    $mark = if ($isSel) { "[x]" } else { "[ ]" }
    $prefix = if ($Index -eq $Cursor) { " > " } else { "   " }
    $text = ("{0}{1} {2}" -f $prefix, $mark, $name).PadRight($L.Cap + 7)
    [Console]::SetCursorPosition($col * $L.CellWidth, $L.Top + $row)
    $color = if ($Index -eq $Cursor) { [ConsoleColor]::Cyan } elseif ($isSel) { [ConsoleColor]::Green } else { [ConsoleColor]::Gray }
    $old = [Console]::ForegroundColor
    [Console]::ForegroundColor = $color
    [Console]::Write($text)
    [Console]::ForegroundColor = $old
}
function Write-GridPage {
    param([hashtable]$L, [object[]]$Items, [hashtable]$Selected, [int]$Cursor)
    $blank = " " * $L.Width
    for ($r = 0; $r -lt $L.Rows; $r++) {
        [Console]::SetCursorPosition(0, $L.Top + $r)
        [Console]::Write($blank)
    }
    $first = $L.Page * $L.PerPage
    $last = [Math]::Min($Items.Count - 1, $first + $L.PerPage - 1)
    for ($j = $first; $j -le $last; $j++) {
        Write-GridCell -L $L -Items $Items -Index $j -Selected $Selected -Cursor $Cursor
    }
}
function Write-GridFooter {
    param([hashtable]$L, [object[]]$Items, [hashtable]$Selected, [int]$Cursor)
    $w = $L.Width
    $app = $Items[$Cursor]
    $detail = "  " + $app.category
    if ($app.description) { $detail += "  -  " + $app.description }
    if ($detail.Length -ge $w) { $detail = $detail.Substring(0, $w - 3) + ".." }
    $pages = [int][Math]::Ceiling($Items.Count / $L.PerPage)
    $status = "  Selected: {0} / {1}" -f $Selected.Count, $Items.Count
    if ($pages -gt 1) { $status += ("     Page {0}/{1}  (PgUp/PgDn)" -f ($L.Page + 1), $pages) }

    [Console]::SetCursorPosition(0, $L.Top + $L.Rows)
    [Console]::ForegroundColor = [ConsoleColor]::DarkCyan
    [Console]::Write($detail.PadRight($w))
    [Console]::SetCursorPosition(0, $L.Top + $L.Rows + 1)
    [Console]::ForegroundColor = [ConsoleColor]::Yellow
    [Console]::Write($status.PadRight($w))
    [Console]::SetCursorPosition(0, $L.Top + $L.Rows + 2)
    [Console]::ForegroundColor = [ConsoleColor]::DarkGray
    $help = "  Arrows move   SPACE select   ENTER install   ESC back   A all   N none"
    if ($help.Length -ge $w) { $help = $help.Substring(0, $w - 1) }
    [Console]::Write($help.PadRight($w))
    [Console]::ResetColor()
}
function Select-Applications {
    param([object[]]$Items, [string]$Prompt = "Select applications")
    if (-not $Items -or $Items.Count -eq 0) {
        Write-Host "No applications found." -ForegroundColor DarkYellow
        Start-Sleep -Seconds 1
        return @()
    }
    $Items = @($Items)
    $selected = @{}
    $cursor = 0
    $L = Get-GridLayout -Items $Items

    Clear-Host
    Write-Host ""
    Write-Host ("  GET SHIT INSTALLED  /  " + $Prompt) -ForegroundColor Yellow
    Write-Host "  Arrows move  SPACE select  ENTER confirm  ESC back  A all  N none" -ForegroundColor DarkGray
    Write-Host ""
    # reserve screen lines so the console never scrolls while we draw
    $reserve = $L.Rows + 4
    for ($i = 0; $i -lt $reserve; $i++) { Write-Host "" }
    $L.Top = [Console]::CursorTop - $reserve
    $endRow = $L.Top + $L.Rows + 3

    Write-GridPage -L $L -Items $Items -Selected $selected -Cursor $cursor
    Write-GridFooter -L $L -Items $Items -Selected $selected -Cursor $cursor

    while ($true) {
        $key = [Console]::ReadKey($true)
        $old = $cursor
        $moved = $false
        $col = [int][Math]::Floor($cursor / $L.Rows)
        $lastCol = [int][Math]::Floor(($Items.Count - 1) / $L.Rows)

        switch ($key.Key) {
            "UpArrow"    { if ($cursor -gt 0) { $cursor--; $moved = $true } }
            "DownArrow"  { if ($cursor -lt ($Items.Count - 1)) { $cursor++; $moved = $true } }
            "LeftArrow"  { if ($col -gt 0) { $cursor -= $L.Rows; $moved = $true } }
            "RightArrow" { if ($col -lt $lastCol) { $cursor = [Math]::Min($Items.Count - 1, $cursor + $L.Rows); $moved = $true } }
            "PageUp"     { $cursor = [Math]::Max(0, $cursor - $L.PerPage); $moved = ($cursor -ne $old) }
            "PageDown"   { $cursor = [Math]::Min($Items.Count - 1, $cursor + $L.PerPage); $moved = ($cursor -ne $old) }
            "Home"       { $cursor = 0; $moved = ($cursor -ne $old) }
            "End"        { $cursor = $Items.Count - 1; $moved = ($cursor -ne $old) }
            "Spacebar" {
                $k = [string]$cursor
                if ($selected.ContainsKey($k)) { $selected.Remove($k) } else { $selected[$k] = $true }
                Write-GridCell -L $L -Items $Items -Index $cursor -Selected $selected -Cursor $cursor
                Write-GridFooter -L $L -Items $Items -Selected $selected -Cursor $cursor
            }
            "Enter" {
                $result = @()
                foreach ($index in ($selected.Keys | Sort-Object { [int]$_ })) { $result += $Items[[int]$index] }
                [Console]::SetCursorPosition(0, $endRow)
                return @($result)
            }
            "Escape" {
                [Console]::SetCursorPosition(0, $endRow)
                return @()
            }
            default {
                if ($key.KeyChar -match '^[aA]$') {
                    $selected.Clear()
                    for ($i = 0; $i -lt $Items.Count; $i++) { $selected[[string]$i] = $true }
                    Write-GridPage -L $L -Items $Items -Selected $selected -Cursor $cursor
                    Write-GridFooter -L $L -Items $Items -Selected $selected -Cursor $cursor
                }
                elseif ($key.KeyChar -match '^[nN]$') {
                    $selected.Clear()
                    Write-GridPage -L $L -Items $Items -Selected $selected -Cursor $cursor
                    Write-GridFooter -L $L -Items $Items -Selected $selected -Cursor $cursor
                }
            }
        }

        if ($moved) {
            $newPage = [int][Math]::Floor($cursor / $L.PerPage)
            if ($newPage -ne $L.Page) {
                $L.Page = $newPage
                Write-GridPage -L $L -Items $Items -Selected $selected -Cursor $cursor
            } else {
                Write-GridCell -L $L -Items $Items -Index $old -Selected $selected -Cursor $cursor
                Write-GridCell -L $L -Items $Items -Index $cursor -Selected $selected -Cursor $cursor
            }
            Write-GridFooter -L $L -Items $Items -Selected $selected -Cursor $cursor
        }
    }
}

function Test-Installed([object]$App) {
    if ($App.type -ne "winget") { return $false }
    $output = & winget.exe list --id $App.id --exact --accept-source-agreements 2>$null | Out-String
    return ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($App.id))
}
function Install-One([object]$App) {
    Write-Host ""
    Write-Host ("==> {0}" -f $App.name) -ForegroundColor Cyan
    Write-Log ("START " + $App.name)
    try {
        if ($App.type -eq "winget") {
            if (Test-Installed $App) {
                Write-Host "Already installed. Skipping." -ForegroundColor DarkYellow
                Write-Log ("SKIP already installed: " + $App.name)
                return "Skipped"
            }
            & winget.exe install --id $App.id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
            if ($LASTEXITCODE -eq 0) {
                Write-Host "Installed successfully." -ForegroundColor Green
                Write-Log ("SUCCESS " + $App.name)
                return "Installed"
            }
            Write-Host ("Installation failed (exit code {0})." -f $LASTEXITCODE) -ForegroundColor Red
            Write-Log ("FAILED " + $App.name + " exit=" + $LASTEXITCODE)
            return "Failed"
        }
        if ($App.type -eq "custom" -and $App.name -eq "WSL2") {
            Write-Host "This runs the Windows WSL installer. It may request elevation and a restart." -ForegroundColor Yellow
            $confirm = Read-Host "Run 'wsl --install' now? (y/N)"
            if ($confirm -match '^(y|yes)$') {
                & wsl.exe --install | Out-Host
                $code = $LASTEXITCODE
                Write-Log ("WSL install command exit=" + $code)
                if ($code -eq 0) { return "Command completed" } else { return "Failed" }
            }
            return "Skipped"
        }
        Write-Host "This entry needs a manual or package-specific installation." -ForegroundColor Yellow
        if ($App.description) { Write-Host $App.description }
        if ($App.url) { Write-Host ("Official/source page: " + $App.url) -ForegroundColor Cyan }
        Write-Log ("MANUAL " + $App.name)
        return "Manual"
    } catch {
        Write-Host ("Error: " + $_.Exception.Message) -ForegroundColor Red
        Write-Log ("ERROR " + $App.name + " " + $_.Exception.Message)
        return "Failed"
    }
}
function Install-Selection([object[]]$Items) {
    if (-not $Items -or $Items.Count -eq 0) { Write-Host "Nothing selected."; return }
    Write-Host ""
    Write-Host "Selected applications:" -ForegroundColor Yellow
    $Items | ForEach-Object { Write-Host (" - " + $_.name) }
    $confirm = Read-Host "Start installation? (y/N)"
    if ($confirm -notmatch '^(y|yes)$') { return }
    if (-not (Ensure-WinGet) -and @($Items | Where-Object { $_.type -eq "winget" }).Count -gt 0) { return }
    $results = @()
    foreach ($app in $Items) {
        $status = Install-One $app
        $results += [pscustomobject]@{ Application = $app.name; Result = $status }
    }
    Write-Host ""
    Write-Host "INSTALLATION SUMMARY" -ForegroundColor Yellow
    $results | Format-Table -AutoSize
    $results | Export-Csv -NoTypeInformation -Append -Path (Join-Path $LogDir "history.csv")
    Pause-Menu
}
function Update-Apps {
    if (-not (Ensure-WinGet)) { Pause-Menu; return }
    Write-Host "Checking for application updates..." -ForegroundColor Cyan
    & winget.exe upgrade --all --silent --accept-package-agreements --accept-source-agreements
    Write-Log ("UPDATE ALL exit=" + $LASTEXITCODE)
    Pause-Menu
}
function Uninstall-Apps([object[]]$Catalog) {
    $items = @($Catalog | Where-Object { $_.type -eq "winget" })
    $selected = Select-Applications -Items $items -Prompt "Select apps to uninstall"
    if ($selected.Count -eq 0) { return }
    Write-Host "Uninstalling selected apps can remove software and data." -ForegroundColor Yellow
    $confirm = Read-Host "Type UNINSTALL to continue"
    if ($confirm -cne "UNINSTALL") { return }
    foreach ($app in $selected) {
        Write-Host ("Uninstalling " + $app.name) -ForegroundColor Cyan
        & winget.exe uninstall --id $app.id --exact --silent --accept-source-agreements
        Write-Log ("UNINSTALL " + $app.name + " exit=" + $LASTEXITCODE)
    }
    Pause-Menu
}

function Get-InstalledAppEntries {
    $paths = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $entries = @()
    foreach ($path in $paths) {
        $entries += Get-ItemProperty $path -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -and $_.DisplayVersion -and -not $_.SystemComponent } |
            ForEach-Object {
                [pscustomobject]@{
                    Name = [string]$_.DisplayName
                    Version = [string]$_.DisplayVersion
                    Publisher = [string]$_.Publisher
                    UninstallString = [string]$_.UninstallString
                    QuietUninstallString = [string]$_.QuietUninstallString
                    WindowsInstaller = [int]$_.WindowsInstaller
                    PSChildName = [string]$_.PSChildName
                    RegistryPath = [string]$_.PSPath
                }
            }
    }
    return @($entries | Sort-Object Name, Version -Unique)
}
function Get-OldVersionGroups {
    $entries = Get-InstalledAppEntries
    $groups = @()
    foreach ($group in ($entries | Group-Object { ($_.Name -replace '\s*\(.*?\)\s*$', '').Trim().ToLowerInvariant() })) {
        if ($group.Count -gt 1) {
            $versions = @($group.Group | Sort-Object {
                try { [version]$_.Version } catch { [version]"0.0" }
            } -Descending)
            if ($versions.Count -gt 1) {
                $groups += [pscustomobject]@{
                    Name = $versions[0].Name
                    Entries = $versions
                    Newest = $versions[0].Version
                    Older = @($versions | Select-Object -Skip 1)
                }
            }
        }
    }
    return @($groups)
}
function Remove-OldVersionEntry([object]$Entry) {
    # Only perform automatic removal for MSI packages with a valid product GUID.
    # EXE uninstallers have vendor-specific switches, so they are never guessed.
    if ($Entry.WindowsInstaller -eq 1 -and $Entry.PSChildName -match '^\{[0-9A-Fa-f-]{36}\}$') {
        Write-Host ("Removing MSI version {0} of {1}..." -f $Entry.Version, $Entry.Name) -ForegroundColor Yellow
        $productCode = $Entry.PSChildName
        & msiexec.exe /x $productCode /passive /norestart
        $code = $LASTEXITCODE
        Write-Log ("OLD VERSION MSI REMOVE " + $Entry.Name + " " + $Entry.Version + " exit=" + $code)
        if ($code -eq 0 -or $code -eq 3010) {
            Write-Host "Uninstall command completed." -ForegroundColor Green
            return "Removal requested"
        }
        Write-Host ("MSI uninstall returned exit code {0}." -f $code) -ForegroundColor Red
        return "Failed"
    }
    Write-Host ("Cannot safely automate removal of {0} {1}." -f $Entry.Name, $Entry.Version) -ForegroundColor DarkYellow
    Write-Host "Its uninstaller uses vendor-specific behavior. Remove it through Windows Settings > Apps > Installed apps."
    return "Manual removal required"
}
function Clean-OldVersions {
    Write-Host ""
    Write-Host "SCANNING INSTALLED APPLICATION VERSIONS" -ForegroundColor Cyan
    Write-Host "This checks Windows uninstall records for duplicate app names with different versions."
    $groups = Get-OldVersionGroups
    if ($groups.Count -eq 0) {
        Write-Host "No obvious duplicate-version installations were found." -ForegroundColor Green
        Write-Host "Note: this does not detect every app's leftover update/cache files."
        Pause-Menu
        return
    }
    $candidates = @()
    foreach ($group in $groups) {
        Write-Host ""
        Write-Host ("{0} (newest detected: {1})" -f $group.Name, $group.Newest) -ForegroundColor Yellow
        foreach ($old in $group.Older) {
            $candidates += $old
            Write-Host ("  {0}. {1} | {2} | {3}" -f $candidates.Count, $old.Version, $old.Publisher, $(if ($old.WindowsInstaller -eq 1) { "MSI: supported for assisted removal" } else { "manual uninstall only" }))
        }
    }
    Write-Host ""
    Write-Host "Only older duplicate entries are offered. The newest detected version is kept."
    Write-Host "Some applications intentionally install side-by-side versions; review before removing."
    $answer = Read-Host "Enter candidate numbers separated by commas (A=all listed older versions, Q=back)"
    if ($answer -match '^(q|quit|back)$' -or [string]::IsNullOrWhiteSpace($answer)) { return }
    if ($answer -match '^(a|all)$') { $chosen = @($candidates) }
    else {
        $chosen = @()
        $valid = $true
        foreach ($part in ($answer -split '[,\s]+' | Where-Object { $_ })) {
            $n = 0
            if (-not [int]::TryParse($part, [ref]$n) -or $n -lt 1 -or $n -gt $candidates.Count) { $valid = $false; break }
            $chosen += $candidates[$n - 1]
        }
        if (-not $valid) { Write-Host "Invalid selection." -ForegroundColor Red; Pause-Menu; return }
    }
    Write-Host ""
    Write-Host "Selected older-version entries:" -ForegroundColor Yellow
    $chosen | ForEach-Object { Write-Host (" - {0} {1} ({2})" -f $_.Name, $_.Version, $_.Publisher) }
    Write-Host ""
    Write-Host "This can remove software. Side-by-side installations may be intentional." -ForegroundColor Red
    $confirm = Read-Host "Type REMOVE OLD VERSIONS to continue"
    if ($confirm -cne "REMOVE OLD VERSIONS") { Write-Host "Cancelled."; return }
    foreach ($entry in $chosen) {
        $status = Remove-OldVersionEntry -Entry $entry
        Write-Log ("OLD VERSION CLEANUP " + $entry.Name + " " + $entry.Version + " result=" + $status)
    }
    Pause-Menu
}


function Select-ArrowMenu {
    param([string]$Title, [string[]]$Options, [switch]$Banner)
    $cursor = 0
    Clear-Host
    if ($Banner) { Write-Banner } else { Write-Host "" }
    Write-Host ("  " + $Title) -ForegroundColor Yellow
    Write-Host "  Use UP/DOWN and ENTER. ESC exits." -ForegroundColor DarkGray
    Write-Host ""
    for ($i = 0; $i -lt $Options.Count; $i++) { Write-Host "" }
    $base = [Console]::CursorTop - $Options.Count

    $drawRow = {
        param([int]$Index)
        $width = [Math]::Max(20, [Console]::WindowWidth - 2)
        $prefix = if ($Index -eq $cursor) { "  > " } else { "    " }
        $line = ($prefix + $Options[$Index]).PadRight($width - 1)
        [Console]::SetCursorPosition(0, $base + $Index)
        $old = [Console]::ForegroundColor
        [Console]::ForegroundColor = if ($Index -eq $cursor) { [ConsoleColor]::Cyan } else { [ConsoleColor]::Gray }
        [Console]::Write($line)
        [Console]::ForegroundColor = $old
    }
    for ($i = 0; $i -lt $Options.Count; $i++) { & $drawRow $i }

    while ($true) {
        $key = [Console]::ReadKey($true)
        $previous = $cursor
        switch ($key.Key) {
            "UpArrow" { if ($cursor -gt 0) { $cursor-- } }
            "DownArrow" { if ($cursor -lt ($Options.Count - 1)) { $cursor++ } }
            "Enter" { [Console]::SetCursorPosition(0, $base + $Options.Count); return $cursor }
            "Escape" { [Console]::SetCursorPosition(0, $base + $Options.Count); return ($Options.Count - 1) }
        }
        if ($previous -ne $cursor) {
            & $drawRow $previous
            & $drawRow $cursor
        }
    }
}

function Main {
    $catalog = Get-Catalog
    if ($List) { $catalog | Select-Object name, category, type, id | Format-Table -AutoSize; return }
    if ($Update) { Update-Apps; return }
    if ($Search) {
        $matches = @($catalog | Where-Object { $_.name -match [regex]::Escape($Search) -or $_.category -match [regex]::Escape($Search) })
        $selected = Select-Applications -Items $matches
        Install-Selection $selected
        return
    }
    while ($true) {
        $menuOptions = @(
            "Browse all applications",
            "Install by category",
            "Search applications",
            "Update installed applications",
            "Uninstall applications",
            "List application catalog",
            "Find / remove old application versions",
            "Exit"
        )
        $choiceIndex = Select-ArrowMenu -Title "MAIN MENU" -Options $menuOptions -Banner
        switch ($choiceIndex) {
            0 {
                $selected = Select-Applications -Items $catalog
                Install-Selection $selected
            }
            1 {
                $categories = @($catalog.category | Sort-Object -Unique)
                $categoryOptions = @($categories) + @("Back")
                $categoryIndex = Select-ArrowMenu -Title "SELECT CATEGORY" -Options $categoryOptions
                if ($categoryIndex -lt $categories.Count) {
                    $selected = Select-Applications -Items @($catalog | Where-Object category -eq $categories[$categoryIndex]) -Prompt $categories[$categoryIndex]
                    Install-Selection $selected
                }
            }
            2 {
                $term = Read-Host "Search name or category"
                $matches = @($catalog | Where-Object { $_.name -match [regex]::Escape($term) -or $_.category -match [regex]::Escape($term) })
                $selected = Select-Applications -Items $matches
                Install-Selection $selected
            }
            3 { Update-Apps }
            4 { Uninstall-Apps -Catalog $catalog }
            5 { $catalog | Select-Object name, category, type, id | Format-Table -AutoSize; Pause-Menu }
            6 { Clean-OldVersions }
            7 { return }
            default { Write-Host "Invalid option." -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}
try { Main } catch {
    Write-Host ("Fatal error: " + $_.Exception.Message) -ForegroundColor Red
    Write-Log ("FATAL " + $_.Exception.Message)
    exit 1
}
