# Noxun Engine - spustenie in-SketchUp test runnera (tests/sketchup/su_runner.rb).
# Overena slucka: INSTALL deploy -> samostatna instancia SketchUp s -RubyStartup
# nad KOPIOU _dev/ENGINEtests.skp -> poll na koncovy marker -> vypis vysledku.
# Testovacie okno SketchUpu NEZATVARAME (pravidlo repa) - zavrie ho pouzivatel.
#
# Paralelne behy (nalez 30.8.2026): kazdy beh ma VLASTNY run_* priecinok
# (vysledok, boot.rb, kopia modelu, AppData sandbox), aby si dva behy
# neprepisovali subory. SketchUp Plugins adresar je vsak JEDEN pre vsetky behy
# a deploy sa izolovat neda — druhy sucasny beh by prepisal nasadeny plugin
# (prvy by potom testoval cudzi kod). Preto CELY beh drzi vyhradny deploy.lock
# a druhy beh sa odmietne s jasnou hlaskou (exit 2) namiesto tichej kolizie.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$su = 'C:\Program Files\SketchUp\SketchUp 2026\SketchUp\SketchUp.exe'
if (-not (Test-Path $su)) { Write-Host "CHYBA: SketchUp nenajdeny: $su"; exit 1 }

$model = Join-Path $repo '_dev\ENGINEtests.skp'
if (-not (Test-Path $model)) { Write-Host "CHYBA: testovaci model chyba: $model (vytvor prazdny ENGINEtests.skp)"; exit 1 }

$workRoot = Join-Path $env:TEMP 'noxun_su_tests'
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

# Zamok: exkluzivne otvoreny subor (FileShare::Read — drzitel pise, ostatni len
# citaju info). Pri pade procesu OS handle zatvori, takze "staly" lock po
# spadnutom behu nevznika — dalsi beh subor normalne prevezme (FileMode Create).
$lockPath = Join-Path $workRoot 'deploy.lock'
$lockStream = $null
try {
  $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
} catch [System.IO.IOException] {
  # ReadAllText tu NEfunguje (zdiela len Read a kolidoval by s Write pristupom
  # drzitela) — citat treba so share maskou ReadWrite.
  $holder = ''
  try {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
    $holder = $sr.ReadToEnd().Trim()
    $sr.Close()
  } catch {}
  Write-Host 'CHYBA: iny beh in-SU testov prave bezi — zdielany SketchUp Plugins adresar sa neda izolovat.'
  if ($holder) { Write-Host ('  Drzitel zamku: ' + $holder) }
  Write-Host ('  Zamok: ' + $lockPath)
  Write-Host '  Pockaj, kym beziaci beh dobehne (max ~8 min), a spusti skript znova.'
  exit 2
}

$exitCode = 1
try {
  $lockInfo = 'PID={0} start={1} repo={2}' -f $PID, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $repo
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockInfo)
  $lockStream.Write($bytes, 0, $bytes.Length)
  $lockStream.Flush()

  # Deploy az POD zamkom — od tejto chvile je v Plugins kod tohto behu.
  & (Join-Path $repo 'INSTALL_noxun_engine.ps1')
  # INSTALL konci pri chybe cez `exit 1` (nie vynimkou) — `&` to nezhodi volajuceho,
  # preto explicitna kontrola. Ziadny nativny prikaz pred tymto miestom nebezi,
  # takze $LASTEXITCODE nemoze byt zvyskovy z ineho volania.
  if ($LASTEXITCODE) { throw "CHYBA: deploy pluginu zlyhal (INSTALL_noxun_engine.ps1, exit $LASTEXITCODE)." }

  # Best-effort upratanie run_* priecinkov starsich ako 1 den (kopie modelu su velke).
  Get-ChildItem $workRoot -Directory -Filter 'run_*' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
    ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false -ErrorAction Stop } catch {} }

  $work = Join-Path $workRoot ('run_{0}_{1}' -f (Get-Date -Format 'yyyyMMdd_HHmmss'), $PID)
  New-Item -ItemType Directory -Force -Path $work | Out-Null
  $out = Join-Path $work 'su_result.txt'
  # Meno kopie MUSI zacinat na "ENGINEtests" — guard_model? v su_runner.rb inak testy preskoci.
  $modelCopy = Join-Path $work ('ENGINEtests_run_{0}.skp' -f $PID)
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

  Write-Host "Spustam SketchUp (model: $(Split-Path $modelCopy -Leaf), work: $work)..."
  Start-Process -FilePath $su -ArgumentList '-RubyStartup', "`"$boot`"", "`"$modelCopy`""

  $deadline = (Get-Date).AddMinutes(8)
  $finished = $false
  while ((Get-Date) -lt $deadline) {
    if ((Test-Path $out) -and (Select-String -Path $out -Pattern 'KONIEC SUBORU' -Quiet)) {
      $finished = $true
      break
    }
    Start-Sleep -Seconds 5
  }
  if ($finished) {
    Write-Host ''
    Get-Content $out -Encoding UTF8 | Write-Host
    # SKIP alebo nula PASS = zlyhanie (Codex review PR #20): beh bez testov nesmie byt zeleny.
    $failed = (Select-String -Path $out -Pattern '^FAIL:' | Measure-Object).Count
    $skipped = (Select-String -Path $out -Pattern '^SKIP:' | Measure-Object).Count
    $passed = (Select-String -Path $out -Pattern '^PASS:' | Measure-Object).Count
    if ($failed -gt 0) { Write-Host "VYSLEDOK: $failed FAIL" }
    elseif ($skipped -gt 0) { Write-Host 'VYSLEDOK: SKIP (testy nebezali) — povazovane za zlyhanie' }
    elseif ($passed -eq 0) { Write-Host 'VYSLEDOK: ziadny PASS — povazovane za zlyhanie' }
    else { Write-Host "VYSLEDOK: OK ($passed PASS)"; $exitCode = 0 }
  } else {
    Write-Host 'TIMEOUT po 8 min.'
    if (Test-Path $out) { Get-Content $out | Write-Host }
  }
} finally {
  # Zamok sa uvolnuje az PO vyhodnoteni — SketchUp nacitava plugin pocas celeho
  # startu a skorsie uvolnenie by pustilo cudzi deploy pod rozbehnuty beh.
  if ($lockStream) { $lockStream.Close() }
  Remove-Item $lockPath -Force -ErrorAction SilentlyContinue -Confirm:$false
}
exit $exitCode
