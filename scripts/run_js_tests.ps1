# Noxun Engine - VSETKY JS sady jednym prikazom (P4a, blok PRAVIDLA).
#
#   powershell -NoProfile -File scripts\run_js_tests.ps1 [-FailFast] [-Dir <priecinok>] [-TimeoutSec 300]
#
# Spusti KAZDY tests/js/test_*.js zvlast (`node <subor>`) - `node tests/js/test_*.js` by
# spustil len PRVY subor, zvysok su pre neho argumenty. Worktree izolacia agentov navyse
# odmieta zlozene prikazy (slucka v bashi), preto jeden skript.
#
# Vystup: riadok `PASS <sada>` / `FAIL <sada>` na kazdu sadu (pri FAIL koniec vystupu sady)
# a suhrn `JS: N sad, M PASS, K FAIL`.
# Exit kod: 0 = vsetky sady presli, 1 = aspon jedna zlyhala (alebo node chyba/timeout).
# Predvolene sa bezi DO KONCA (jeden beh ukaze vsetky padnute sady); -FailFast skonci po
# prvom zlyhani (ako CI slucka).
# CI (.github/workflows/tests.yml) spusta tie iste sady bash sluckou - tento skript je len
# lokalny pohodlny vstup; pravidlo "kazda sada zvlast" je rovnake.
# ASCII, bez ternary / ?? / ?. (PS 5.1 aj pwsh).
param(
  [switch]$FailFast,
  [string]$Dir = '',
  [int]$TimeoutSec = 300
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (-not $Dir) { $Dir = Join-Path (Join-Path $repo 'tests') 'js' }
if (-not (Test-Path -LiteralPath $Dir)) { Write-Host "CHYBA: priecinok sad neexistuje: $Dir"; exit 1 }

$nodeCmd = Get-Command node -ErrorAction SilentlyContinue
if (-not $nodeCmd) { Write-Host 'CHYBA: node nenajdeny v PATH.'; exit 1 }
$node = $nodeCmd.Source

$suites = @(Get-ChildItem -LiteralPath $Dir -Filter 'test_*.js' -File | Sort-Object Name)
if ($suites.Count -eq 0) { Write-Host "CHYBA: v $Dir nie su ziadne test_*.js sady."; exit 1 }

# Jedna sada: node v samostatnom procese, stdout aj stderr zachytene (asynchronne - plna rura nezablokuje).
function Invoke-NxJsSuite([string]$file) {
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $node
  $psi.Arguments = '"' + $file + '"'
  $psi.WorkingDirectory = $repo
  $psi.UseShellExecute = $false
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.CreateNoWindow = $true
  $p = New-Object System.Diagnostics.Process
  $p.StartInfo = $psi
  [void]$p.Start()
  $outTask = $p.StandardOutput.ReadToEndAsync()
  $errTask = $p.StandardError.ReadToEndAsync()
  $done = $p.WaitForExit($TimeoutSec * 1000)
  if (-not $done) {
    try { $p.Kill() } catch {}
    return @{ ok = $false; code = -1; text = "TIMEOUT po $TimeoutSec s" }
  }
  $p.WaitForExit()
  return @{ ok = ($p.ExitCode -eq 0); code = $p.ExitCode; text = ($outTask.Result + $errTask.Result) }
}

$pass = 0
$fail = 0
$failed = @()
foreach ($s in $suites) {
  $r = Invoke-NxJsSuite $s.FullName
  if ($r.ok) {
    $pass++
    Write-Host ('PASS ' + $s.Name)
  } else {
    $fail++
    $failed += $s.Name
    Write-Host ('FAIL ' + $s.Name + ' (exit ' + $r.code + ')')
    $lines = @(($r.text -split "`r?`n") | Where-Object { $_ -ne '' })
    $tail = $lines | Select-Object -Last 25
    foreach ($l in $tail) { Write-Host ('  | ' + $l) }
    if ($FailFast) { break }
  }
}

Write-Host ('JS: {0} sad, {1} PASS, {2} FAIL' -f ($pass + $fail), $pass, $fail)
if ($fail -gt 0) { Write-Host ('Padnute: ' + ($failed -join ', ')); exit 1 }
exit 0
