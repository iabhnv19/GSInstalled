$ErrorActionPreference = "Stop"
$repoRaw    = "https://raw.githubusercontent.com/iabhnv19/GSInstalled/main"
$installDir = Join-Path $HOME ".get-shit-installed"
$mainScript = Join-Path $installDir "get-shit-installed.ps1"
$dataDir    = Join-Path $installDir "data"
$catalogSrc = "$repoRaw/data/applications.json"
$catalogDst = Join-Path $dataDir "applications.json"
$profilePath = $PROFILE

Write-Host ""
Write-Host "  GSInstalled - Bootstrapper" -ForegroundColor Yellow
Write-Host "  Installing the 'gsi' command..." -ForegroundColor Cyan

# --- Download files ---
New-Item -ItemType Directory -Path $installDir -Force | Out-Null
New-Item -ItemType Directory -Path $dataDir    -Force | Out-Null

Write-Host "  Downloading main script..." -ForegroundColor DarkGray
Invoke-WebRequest -Uri "$repoRaw/get-shit-installed.ps1" -OutFile $mainScript
Write-Host "  Downloading catalog..." -ForegroundColor DarkGray
Invoke-WebRequest -Uri $catalogSrc -OutFile $catalogDst

# --- Patch $PROFILE ---
$profileDir = Split-Path -Parent $profilePath
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}
if (-not (Test-Path $profilePath)) {
    New-Item -ItemType File -Path $profilePath -Force | Out-Null
}

$markerStart = "# >>> GSInstalled >>>"
$markerEnd   = "# <<< GSInstalled <<<"
$profileText = Get-Content -Path $profilePath -Raw -ErrorAction SilentlyContinue
if ($null -eq $profileText) { $profileText = "" }

$block = "# >>> GSInstalled >>>`r`nfunction gsi {`r`n    & `"`$HOME\.get-shit-installed\get-shit-installed.ps1`" @args`r`n}`r`n# <<< GSInstalled <<<"

if ($profileText.Contains($markerStart) -and $profileText.Contains($markerEnd)) {
    $pattern = "(?s)# >>> GSInstalled >>>.*?# <<< GSInstalled <<<"
    $profileText = [regex]::Replace(
        $profileText,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $block.TrimEnd() }
    )
} else {
    if ($profileText.Length -gt 0 -and -not $profileText.EndsWith("`n")) { $profileText += "`r`n" }
    $profileText += "`r`n$block`r`n"
}
Set-Content -Path $profilePath -Value $profileText -Encoding utf8

# --- Done ---
Write-Host ""
Write-Host "  Installed successfully!" -ForegroundColor Green
Write-Host "  'gsi' is now available in every new PowerShell window." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Launching now..." -ForegroundColor DarkGray
Write-Host ""

$resolvedMain = Join-Path $HOME ".get-shit-installed\get-shit-installed.ps1"
if (-not (Test-Path $resolvedMain)) { throw "Main script not found at: $resolvedMain" }
& $resolvedMain @args

