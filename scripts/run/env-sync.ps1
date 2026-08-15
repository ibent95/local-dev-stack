<#
.SYNOPSIS
  Sync .env to .env.example - keep YOUR values, match the example's variables,
  ordering and comments. Windows counterpart of scripts/run/env-sync.sh (same
  rules); invoked by scripts/run/env-sync.bat.

  env-sync.ps1 [-DryRun] [-Quiet]

  Rules:
    * Every variable in .env.example must exist in .env at the same position.
    * YOUR value wins: the value is kept from .env. Inline comments follow
      .env.example, so the comments stay in sync when the example changes
      (a '#' only starts a comment when preceded by whitespace, so values
      like PASSWORD=abc#def are never touched).
    * Variables missing from .env are added with the example's default value.
    * Variables that only exist in .env (dropped from the example) are kept,
      appended at the end under a marker comment - nothing is ever deleted.
    * Structure (standalone comments / blank lines / order) follows
      .env.example, so standalone comments you added to .env are not carried
      over - edit .env.example if you want to change the structure.
#>
[CmdletBinding()]
param(
  [switch]$DryRun,
  [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$Root     = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # scripts/run -> repo root
$Example  = Join-Path $Root '.env.example'
$EnvFile  = Join-Path $Root '.env'

function Get-Lines([string]$path) {
  # Read a file as UTF-8 (no BOM) and return its lines without line endings.
  [System.IO.File]::ReadAllLines($path, (New-Object System.Text.UTF8Encoding($false)))
}

function Split-Line([string]$line) {
  # Dotenv comment rule: a '#' starts a comment only when preceded by
  # whitespace, so values like PASSWORD=abc#def survive untouched.
  # Returns @{ value; comment } where 'comment' keeps the original spacing.
  $m = [regex]::Match($line, '^(.*[^\s])\s+#(.*)$')
  if ($m.Success) {
    return @{ value = $m.Groups[1].Value; comment = $line.Substring($m.Groups[1].Length) }
  }
  return @{ value = $line; comment = '' }
}

if (-not (Test-Path $Example)) {
  Write-Host "env-sync: $Example not found"
  exit 1
}
if (-not (Test-Path $EnvFile)) {
  if ($DryRun) {
    Write-Host 'env-sync: .env missing - dry run: would create it from .env.example'
  } else {
    Copy-Item $Example $EnvFile
    Write-Host 'env-sync: no .env found - created from .env.example.'
  }
  exit 0
}

# Match the example's line endings (the repo ships CRLF; keep whatever it uses).
$exampleLines = Get-Lines $Example
$EOL = "`n"
$exampleBytes = [System.IO.File]::ReadAllBytes($Example)
for ($i = 0; $i -lt $exampleBytes.Length; $i++) {
  if ($exampleBytes[$i] -eq 10) {
    if ($i -gt 0 -and $exampleBytes[$i - 1] -eq 13) { $EOL = "`r`n" }
    break
  }
}

# --- Pass 1: index .env (key -> full line; first occurrence wins; keep order).
$cur = @{}
$order = [System.Collections.Generic.List[string]]::new()
foreach ($line in (Get-Lines $EnvFile)) {
  $m = [regex]::Match($line, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=')
  if ($m.Success -and -not $cur.ContainsKey($m.Groups[1].Value)) {
    $cur[$m.Groups[1].Value] = $line
    $order.Add($m.Groups[1].Value)
  }
}

# --- Pass 2: rebuild from the example, substituting your values.
# Values stay yours; inline comments follow the example so .env comments stay
# in sync with .env.example.
$out = New-Object System.Text.StringBuilder
$added = [System.Collections.Generic.List[string]]::new()
foreach ($line in $exampleLines) {
  $m = [regex]::Match($line, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=')
  if ($m.Success) {
    $k = $m.Groups[1].Value
    if ($cur.ContainsKey($k)) {
      $userLine = $cur[$k]
      $ex = Split-Line $line
      if ($ex.comment -ne '') {
        # Example carries an inline comment -> YOUR value + the example's
        # comment (spacing preserved), so the comment is always current.
        $us = Split-Line $userLine
        [void]$out.Append($us.value + $ex.comment + $EOL)
      } elseif ($userLine -match '^(.*[^\s])\s+#(.*)$') {
        # Example has no inline comment -> drop the stale user comment.
        [void]$out.Append($Matches[1] + $EOL)
      } else {
        [void]$out.Append($userLine + $EOL)
      }
      $cur.Remove($k)
    } else {
      [void]$out.Append($line + $EOL)
      $added.Add($k)
    }
  } else {
    [void]$out.Append($line + $EOL)
  }
}

# --- Pass 3: .env-only variables (not in the example) - append, never drop.
$extra = [System.Collections.Generic.List[string]]::new()
foreach ($k in $order) {
  if ($cur.ContainsKey($k)) {
    $extra.Add($k)
    if ($extra.Count -eq 1) {
      [void]$out.Append($EOL + '# --- kept from .env (not in .env.example) ---' + $EOL)
    }
    [void]$out.Append($cur[$k] + $EOL)
  }
}

# --- Apply.
$newText = $out.ToString()
$oldText = [System.IO.File]::ReadAllText($EnvFile, (New-Object System.Text.UTF8Encoding($false)))

if ($newText -ceq $oldText) {
  if (-not $Quiet) { Write-Host 'env-sync: no changes - .env already matches .env.example (values untouched).' }
  exit 0
}

if ($DryRun) {
  Write-Host 'env-sync: DRY RUN - .env would be rewritten to match .env.example:'
  $oldLines = $oldText -split "`r?`n"
  $newLines = $newText -split "`r?`n"
  $max = [Math]::Max($oldLines.Count, $newLines.Count)
  for ($i = 0; $i -lt $max; $i++) {
    $o = if ($i -lt $oldLines.Count) { $oldLines[$i] } else { '<missing>' }
    $n = if ($i -lt $newLines.Count) { $newLines[$i] } else { '<missing>' }
    if ($o -cne $n) { Write-Host "- $o"; Write-Host "+ $n" }
  }
} else {
  [System.IO.File]::WriteAllText($EnvFile, $newText, (New-Object System.Text.UTF8Encoding($false)))
  Write-Host 'env-sync: synced .env to .env.example (values kept).'
}
if ($added.Count -gt 0) { Write-Host ('  + added from example: ' + ($added -join ' ')) }
if ($extra.Count -gt 0) { Write-Host ('  = kept (in .env only, appended at end): ' + ($extra -join ' ')) }
exit 0
