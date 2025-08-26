<# 
  Setup-R-RStudio.ps1
  One-click setup for PowerShell 7 (if needed), R, RStudio, (optional) Rtools, Git, Quarto,
  CRAN mirror, and bootstrap package installation on Windows 11.
#>

function Ensure-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Re-launching with Administrator privileges..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName  = (Get-Process -Id $PID).Path
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    $psi.Verb      = "RunAs"
    try {
      [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
      Write-Error "Failed to elevate: $_"
      exit 1
    }
    exit 0
  }
}
Ensure-Admin

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force

function Ensure-Winget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget was not found. Please install 'App Installer' from Microsoft Store, then re-run."
    exit 1
  }
  try { winget source update | Out-Null } catch {}
}
Ensure-Winget

function Ensure-PS7 {
  if ($PSVersionTable.PSEdition -ne "Core" -or $PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "Installing/updating PowerShell 7 via winget..."
    winget install --id Microsoft.Powershell --source winget --accept-package-agreements --accept-source-agreements -h
    $pwsh = (Get-Command pwsh -ErrorAction SilentlyContinue)?.Source
    if (-not $pwsh) {
      $possible = @(
        "$Env:ProgramFiles\PowerShell\7\pwsh.exe",
        "$Env:ProgramFiles\PowerShell\7-preview\pwsh.exe",
        "$Env:LocalAppData\Microsoft\WindowsApps\pwsh.exe"
      )
      $pwsh = $possible | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $pwsh) {
      Write-Error "Couldn't locate pwsh.exe after installation."
      exit 1
    }
    Write-Host "Re-launching this script under PowerShell 7..."
    & $pwsh "-NoProfile" "-ExecutionPolicy" "Bypass" "-File" "$PSCommandPath"
    exit 0
  } else {
    Write-Host "Running under PowerShell $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
  }
}
Ensure-PS7

function Ensure-Package {
  param([Parameter(Mandatory=$true)][string]$Id)
  $listed = winget list --id $Id --source winget 2>$null
  if ($LASTEXITCODE -eq 0 -and $listed) {
    Write-Host "Already installed: $Id"
  } else {
    Write-Host "Installing: $Id"
    winget install --id $Id --source winget --accept-package-agreements --accept-source-agreements -h
  }
}

Ensure-Package -Id "RProject.R"
Ensure-Package -Id "RStudio.RStudio"
try { Ensure-Package -Id "Git.Git" } catch {}
try { Ensure-Package -Id "Quarto.Quarto" } catch {}

$possibleRToolsIds = @("RProject.Rtools","r-project.rtools","RTools.RTools")
foreach ($rid in $possibleRToolsIds) {
  try {
    winget show --id $rid --source winget *> $null
    if ($LASTEXITCODE -eq 0) { Ensure-Package -Id $rid; break }
  } catch {}
}

$docs = [Environment]::GetFolderPath("MyDocuments")
$rprofilePath = Join-Path $docs ".Rprofile"
if (-not (Test-Path $rprofilePath)) {
@'
options(
  repos = c(CRAN = "https://cloud.r-project.org"),
  download.file.method = "wininet"
)
'@ | Out-File -FilePath $rprofilePath -Encoding UTF8
  Write-Host "Created $rprofilePath"
}

$scriptDir = Split-Path -Parent $PSCommandPath
$bootstrapPath = Join-Path $scriptDir "bootstrap.R"
$bootstrapR = @'
pkgs <- c(
  "tidyverse","data.table","sf","ggplot2","ggnewscale","viridis","terra",
  "CoordinateCleaner","SDMtune","furrr","blockCV","usdm","geodata","spocc",
  "plotROC","dplyr","stringr","readr","lubridate","devtools","remotes","here",
  "janitor","renv"
)

to_install <- setdiff(pkgs, rownames(installed.packages()))
if (length(to_install)) {
  install.packages(to_install, dependencies = TRUE)
} else {
  message("All requested packages already installed.")
}

if (requireNamespace("pkgbuild", quietly=TRUE)) pkgbuild::has_build_tool(debug = TRUE)
'@
$bootstrapR | Out-File -FilePath $bootstrapPath -Encoding UTF8
Write-Host "Wrote $bootstrapPath"

$rscript = Get-Command Rscript -ErrorAction SilentlyContinue
if ($rscript) {
  Write-Host "Running bootstrap via Rscript..."
  & $rscript.Source "$bootstrapPath"
} else {
  Write-Warning "Couldn't find Rscript. Open RStudio later and run: source('bootstrap.R')"
}

Write-Host "`nDone! Launch RStudio when ready."
