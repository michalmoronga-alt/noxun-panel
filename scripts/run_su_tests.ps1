# Noxun Engine - spustenie in-SketchUp test runnera (tests/sketchup/su_runner.rb).
# Overena slucka: INSTALL deploy -> samostatna instancia SketchUp s -RubyStartup
# nad KOPIOU _dev/ENGINEtests.skp -> poll na koncovy marker -> vypis vysledku.
# Testovacie okno SketchUpu NEZATVARAME (pravidlo repa) - zavrie ho pouzivatel.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$su = 'C:\Program Files\SketchUp\SketchUp 2026\SketchUp\SketchUp.exe'
if (-not (Test-Path $su)) { Write-Host "CHYBA: SketchUp nenajdeny: $su"; exit 1 }

$model = Join-Path $repo '_dev\ENGINEtests.skp'
if (-not (Test-Path $model)) { Write-Host "CHYBA: testovaci model chyba: $model (vytvor prazdny ENGINEtests.skp)"; exit 1 }

& (Join-Path $repo 'INSTALL_noxun_engine.ps1')

$work = Join-Path $env:TEMP 'noxun_su_tests'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$out = Join-Path $work 'su_result.txt'
Remove-Item $out -Force -ErrorAction SilentlyContinue -Confirm:$false
$modelCopy = Join-Path $work ("ENGINEtests_run_" + (Get-Date -Format 'HHmmss') + '.skp')
Copy-Item $model $modelCopy -Force

$runner = (Join-Path $repo 'tests\sketchup\su_runner.rb') -replace '\\', '/'
$outRb = $out -replace '\\', '/'
$boot = Join-Path $work 'boot.rb'
$lines = @(
  "ENV['NOXUN_SU_OUT'] = '$outRb'",
  "load '$runner'"
)
[System.IO.File]::WriteAllLines($boot, [string[]]$lines, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Spustam SketchUp (model: $(Split-Path $modelCopy -Leaf))..."
Start-Process -FilePath $su -ArgumentList '-RubyStartup', "`"$boot`"", "`"$modelCopy`""

$deadline = (Get-Date).AddMinutes(8)
while ((Get-Date) -lt $deadline) {
  if ((Test-Path $out) -and (Select-String -Path $out -Pattern 'KONIEC SUBORU' -Quiet)) {
    Write-Host ''
    Get-Content $out -Encoding UTF8 | Write-Host
    $failed = (Select-String -Path $out -Pattern '^FAIL:' | Measure-Object).Count
    if ($failed -gt 0) { Write-Host "VYSLEDOK: $failed FAIL"; exit 1 }
    Write-Host 'VYSLEDOK: OK'
    exit 0
  }
  Start-Sleep -Seconds 5
}
Write-Host 'TIMEOUT po 8 min.'
if (Test-Path $out) { Get-Content $out | Write-Host }
exit 1
