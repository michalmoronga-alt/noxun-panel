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

# Izolacia perzistencie (Codex review PR #20): NOXUN katalogy (materials/abs_rules/templates)
# citaju ENV['APPDATA'] pri KAZDOM volani -> presmerovanie v bootstrape ochrani realne katalogy
# vyvojara pred seed/normalizacnymi zapismi testov. SketchUp Plugins sa nacitavaju z nativneho
# profilu (nie z Ruby ENV), takze plugin sa nacita normalne. NEROBIT v zivej user session!
$appdata = Join-Path $work 'AppData'
New-Item -ItemType Directory -Force -Path $appdata | Out-Null

# Escapovanie pre Ruby single-quoted literaly (Codex review PR #20): apostrof v ceste
# (napr. C:\Users\O'Neil) by inak vygeneroval nevalidny bootstrap a 8 min timeout.
function ConvertTo-RubySq([string]$s) {
  return ($s -replace '\\', '/') -replace "'", "\'"
}
$runner = ConvertTo-RubySq (Join-Path $repo 'tests\sketchup\su_runner.rb')
$outRb = ConvertTo-RubySq $out
$appdataRb = ConvertTo-RubySq $appdata
$boot = Join-Path $work 'boot.rb'
$lines = @(
  "ENV['APPDATA'] = '$appdataRb'",
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
    # SKIP alebo nula PASS = zlyhanie (Codex review PR #20): beh bez testov nesmie byt zeleny.
    $failed = (Select-String -Path $out -Pattern '^FAIL:' | Measure-Object).Count
    $skipped = (Select-String -Path $out -Pattern '^SKIP:' | Measure-Object).Count
    $passed = (Select-String -Path $out -Pattern '^PASS:' | Measure-Object).Count
    if ($failed -gt 0) { Write-Host "VYSLEDOK: $failed FAIL"; exit 1 }
    if ($skipped -gt 0) { Write-Host 'VYSLEDOK: SKIP (testy nebezali) — povazovane za zlyhanie'; exit 1 }
    if ($passed -eq 0) { Write-Host 'VYSLEDOK: ziadny PASS — povazovane za zlyhanie'; exit 1 }
    Write-Host "VYSLEDOK: OK ($passed PASS)"
    exit 0
  }
  Start-Sleep -Seconds 5
}
Write-Host 'TIMEOUT po 8 min.'
if (Test-Path $out) { Get-Content $out | Write-Host }
exit 1
