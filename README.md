# r-setup-windows
# you (or anyone else) can set up a fresh Windows 11 machine with

$raw = "https://raw.githubusercontent.com/estanzel/Bootstrappign/main/Setup-R-RStudio.ps1"
Invoke-WebRequest $raw -OutFile Setup-R-RStudio.ps1
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
.\Setup-R-RStudio.ps1
