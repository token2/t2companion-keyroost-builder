<#
.SYNOPSIS
  Produces a ready-to-upload Token2 documentation site from a clean keyroost
  checkout (Windows). Nothing is committed back to keyroost.

.DESCRIPTION
  1. clones keyroost (upstream or your fork) at a chosen ref,
  2. copies the repo's docs/ folder into a fresh OUTPUT directory,
  3. overlays the Token2 changes: installs the Token2 OTP applet page, adds it
     to every page's nav, adds the "About this edition" fork notice to
     index.html, and (optionally) repoints absolute links to your host,
  4. leaves OUTPUT ready to upload to your web host as-is.

  Requires: git and python (3.8+).

.EXAMPLE
  .\build-token2-docs.ps1
  .\build-token2-docs.ps1 -Repo https://github.com/token2/keyroost.git -Out token2-docs-site -BaseUrl https://www.token2.swiss/kr-docs
#>
param(
  [string]$Repo    = "https://github.com/framefilter/keyroost.git",
  [string]$Ref     = "main",
  [string]$Out     = ".\token2-docs-site",
  [string]$BaseUrl = "https://www.token2.swiss/kr-docs"
)

$ErrorActionPreference = "Stop"
$SelfDir = Split-Path -Parent $MyInvocation.MyCommand.Path

function Say($m) { Write-Host "> $m" -ForegroundColor Magenta }

# Run git so its normal stderr progress ("Cloning into ...") is NOT treated as a
# terminating error. Only a non-zero exit code is a real failure.
function Invoke-Git {
  $old = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try { & git @args 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray } }
  finally { $ErrorActionPreference = $old }
  if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') failed (exit $LASTEXITCODE)" }
}

if (Test-Path $Out) { throw "output dir '$Out' already exists - remove it or pass -Out" }

# 1. clone into a temp dir (we only need docs/).
$Tmp = Join-Path ([IO.Path]::GetTempPath()) ("krdocs_" + [Guid]::NewGuid().ToString("N").Substring(0,8))
New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
try {
  Say "Cloning $Repo @ $Ref"
  $repoPath = Join-Path $Tmp "repo"
  try {
    Invoke-Git clone --depth 1 --branch $Ref $Repo $repoPath
  } catch {
    Invoke-Git clone $Repo $repoPath
    Invoke-Git -C $repoPath checkout $Ref
  }

  $repoDocs = Join-Path $Tmp "repo\docs"
  if (-not (Test-Path $repoDocs)) { throw "the repo has no docs/ folder" }

  # 2. copy docs/ into the fresh output dir.
  Say "Copying docs/ into $Out"
  New-Item -ItemType Directory -Force -Path $Out | Out-Null
  Copy-Item -Recurse -Force (Join-Path $repoDocs "*") $Out
  $Out = (Resolve-Path $Out).Path

  # Drop internal developer notes that aren't part of the public site.
  foreach ($f in @("BRINGUP.md","DEVICE-RESEARCH.md","PROTOCOL.md")) {
    $fp = Join-Path $Out $f
    if (Test-Path $fp) { Remove-Item -Force $fp; Say "Removed internal note: $f" }
  }

  # 3. overlay the Token2 changes in place.
  Say "Applying Token2 documentation overlay"
  $pyArgs = @("--docs", $Out, "--page", (Join-Path $SelfDir "token2-otp.html"))
  if ($BaseUrl -ne "") { $pyArgs += @("--base-url", $BaseUrl) }
  python (Join-Path $SelfDir "apply_docs_branding.py") @pyArgs
}
finally {
  Remove-Item -Recurse -Force $Tmp -ErrorAction SilentlyContinue
}

Say "Done."
Write-Host ""
Write-Host "  Ready-to-upload site:  $Out"
Write-Host "  Upload the entire contents of that folder to your web host."
if ($BaseUrl -ne "") { Write-Host "  Absolute links repointed to: $BaseUrl" }
