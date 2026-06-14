<#
.SYNOPSIS
  Build the Windows installer (Setup .exe) for the rebranded keyroost GUI.

.DESCRIPTION
  1. ensures a release build exists (builds it if not),
  2. fills the placeholders in token2-companion.iss with real paths/values,
  3. compiles it with Inno Setup's iscc.exe into a single Setup .exe.

  Requires: Rust toolchain (to build), and Inno Setup 6 installed
  (https://jrsoftware.org/isdl.php) so iscc.exe is available. The script looks
  for iscc.exe on PATH and in the default install location.

.EXAMPLE
  .\build-installer.ps1 -Project ..\..\token2-companion-keyroost -Version 0.4.0
#>
param(
  [string]$Project = "..\..\token2-companion-keyroost",
  [string]$Name    = "Token2 Companion Rust version - Keyroost",
  [string]$AppId   = "{{A7E3F1C2-7B40-4D2E-9C1A-7B2E03260001}}",
  [string]$Version = "0.4.0",
  [string]$Icon    = ""
)

$ErrorActionPreference = "Stop"
$SelfDir = Split-Path -Parent $MyInvocation.MyCommand.Path
function Say($m) { Write-Host "> $m" -ForegroundColor Magenta }

$Project = (Resolve-Path $Project).Path

# 1. build if needed
$rel = Join-Path $Project "target\release"
if (-not (Test-Path (Join-Path $rel "keyroost.exe"))) {
  Say "Building release binaries"
  Push-Location $Project
  try { cargo build --release --locked -p keyroost -p keyroostctl } finally { Pop-Location }
}
if (-not (Test-Path (Join-Path $rel "keyroost.exe"))) { throw "keyroost.exe not found after build" }

# Icon: default to the rebrand app icon if present.
if ($Icon -eq "") {
  $cand1 = Join-Path $SelfDir "..\branding\icon-256.png"
  $cand2 = Join-Path $Project "crates\keyroost\assets\branding\app-icon.png"
  # Inno wants an .ico; if we only have PNG, convert via the bundled helper.
  $icoOut = Join-Path $SelfDir "app.ico"
  if (Test-Path $cand1) { $pngForIco = (Resolve-Path $cand1).Path }
  elseif (Test-Path $cand2) { $pngForIco = (Resolve-Path $cand2).Path }
  else { $pngForIco = "" }
  if ($pngForIco -ne "") {
    Say "Creating .ico from $([IO.Path]::GetFileName($pngForIco))"
    python (Join-Path $SelfDir "png_to_ico.py") $pngForIco $icoOut
    $Icon = $icoOut
  }
}
if ($Icon -eq "" -or -not (Test-Path $Icon)) { throw "no icon (.ico) available; pass -Icon path\to.ico" }
$Icon = (Resolve-Path $Icon).Path

# 2. fill the .iss template
$outDir = Join-Path $Project "dist"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$iss = Get-Content (Join-Path $SelfDir "token2-companion.iss") -Raw
$iss = $iss.Replace("@APP_NAME@", $Name).
            Replace("@APP_ID@", $AppId).
            Replace("@APP_VERSION@", $Version).
            Replace("@SRC_DIR@", $rel).
            Replace("@ICON_FILE@", $Icon).
            Replace("@OUTPUT_DIR@", (Resolve-Path $outDir).Path)
$issOut = Join-Path $SelfDir "token2-companion.filled.iss"
Set-Content -Path $issOut -Value $iss -Encoding UTF8

# 3. find iscc.exe and compile
$iscc = Get-Command iscc.exe -ErrorAction SilentlyContinue
if (-not $iscc) {
  foreach ($p in @("${env:ProgramFiles(x86)}\Inno Setup 6\iscc.exe",
                   "$env:ProgramFiles\Inno Setup 6\iscc.exe")) {
    if (Test-Path $p) { $iscc = $p; break }
  }
}
if (-not $iscc) {
  throw "iscc.exe (Inno Setup 6) not found. Install from https://jrsoftware.org/isdl.php"
}
$isccPath = if ($iscc -is [string]) { $iscc } else { $iscc.Source }

Say "Compiling installer"
& $isccPath $issOut
if ($LASTEXITCODE -ne 0) { throw "iscc failed (exit $LASTEXITCODE)" }

Say "Done."
Write-Host "  Installer: $outDir\token2-companion-keyroost-setup.exe"
