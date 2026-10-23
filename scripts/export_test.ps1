# Noxun Engine - EXPORT TEST (H19, blok 9 HARDENING): porovnanie vystupov 4 exportov
# Studia (VEPO, CSV kovania, XLSX rozpoctu, XLSX ponuky) medzi K a P nad tou istou
# kopiou testovacej zakazky. Nahradzuje rucne exporty R9 z PACKAGE_H17.
#
#   P = AKTUALNY CHECKOUT repa (to, co sa testuje; nasadi sa z neho),
#   K = -Base (git ref, predvolene origin/main; dociasny `git worktree add --detach`
#       do kratkej cesty v %TEMP%\nxkp\<beh>\t - checkout pouzivatela sa NEMENI,
#       worktree sa po behu odstrani; -KeepWork ho ponecha).
#
# Beh: snimka profilu %APPDATA%\NOXUN (len citanie, raz) -> pre K aj P CERSTVA kopia
# snimky ako ENV['APPDATA'] (realny profil sa nemeni, oba behy maju rovnake data) ->
# deploy stromu (INSTALL_noxun_engine.ps1) -> kopia modelu POD ROVNAKYM MENOM -> SketchUp
# -RubyStartup boot.rb "<kopia>" -> sonda tests/sketchup/su_export_probe.rb (4x do_*,
# okna vyberu nahradene) -> koncovy marker -> SketchUp sa ukonci SAM (proces sa NIKDY
# nezabija; po markeri sa caka na jeho zanik max 120 s) -> porovnanie
# scripts/export_compare.rb (pravidla R9.3). Na konci ostane nasadeny P.
#
# Zamok: ten isty ako run_su_tests.ps1 a ui_foto.ps1 (%TEMP%\noxun_su_tests\deploy.lock +
# sentinel last_run.txt) - beh nesmie kolidovat s in-SU testami ani s fotenim okien.
# exit 2 = iny beh prave bezi (pockaj a spusti znova).
#
# Pouzitie: powershell -NoProfile -File scripts\export_test.ps1 [-Base <ref>] [-Model <.skp>] [-KeepWork]
#   -Model predvolene <repo>\_dev\export_test\zakazka.skp (_dev je gitignorovany; vo worktree
#   sa zakazka hlada aj v hlavnom checkoute - scripts\lib\nx_paths.ps1).
# Vystup: `EXPORT-TEST: P == K` / `EXPORT-TEST: P != K` + zoznam rozdielov + porovnanie
# viet statusu. Exit 0 = zhodne, 1 = rozdiel alebo chyba behu, 2 = zamok.
param(
  [string]$Base = 'origin/main',
  [string]$Model = '',
  [switch]$KeepWork
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'nx_paths.ps1')
$su = 'C:\Program Files\SketchUp\SketchUp 2026\SketchUp\SketchUp.exe'
if (-not (Test-Path $su)) { Write-Host "CHYBA: SketchUp nenajdeny: $su"; exit 1 }

# Zakazka: _dev\export_test\zakazka.skp tohto checkoutu, vo worktree z hlavneho checkoutu
# (_dev je gitignorovany - scripts\lib\nx_paths.ps1).
$zakSeg = @('_dev', 'export_test', 'zakazka.skp')
if (-not $Model) { $Model = Resolve-NxDevFile $repo $zakSeg }
if (-not $Model -or -not (Test-Path -LiteralPath $Model)) {
  if ($Model) { Write-Host "CHYBA: model testovacej zakazky chyba: $Model" }
  else { Write-Host (Get-NxMissingDevMessage 'model testovacej zakazky' $repo $zakSeg) }
  Write-Host '  Skopiruj tam .skp zakazky, na ktorej sa maju exporty porovnat (priecinok _dev je gitignorovany),'
  Write-Host '  alebo ho zadaj cez -Model <cesta>. Pouzije sa jeho KOPIA, original sa nemeni.'
  exit 1
}
$Model = (Resolve-Path -LiteralPath $Model).Path

$ruby = $null
$rubyCmd = Get-Command ruby -ErrorAction SilentlyContinue
if ($rubyCmd) { $ruby = $rubyCmd.Source }
elseif (Test-Path 'C:\Ruby32-x64\bin\ruby.exe') { $ruby = 'C:\Ruby32-x64\bin\ruby.exe' }
if (-not $ruby) { Write-Host 'CHYBA: Ruby nenajdeny (standalone Ruby v C:\Ruby32-x64 alebo ruby v PATH).'; exit 1 }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Host 'CHYBA: git nenajdeny.'; exit 1 }

$baseSha = (& git -C $repo rev-parse --verify --quiet ($Base + '^{commit}')) | Select-Object -First 1
if ($LASTEXITCODE -or -not $baseSha) { Write-Host "CHYBA: -Base '$Base' sa neda rozlisit na commit."; exit 1 }

$workRoot = Join-Path $env:TEMP 'noxun_su_tests'
New-Item -ItemType Directory -Force -Path $workRoot | Out-Null

# Zamok: exkluzivne otvoreny subor (FileShare::Read), rovnaky ako v run_su_tests.ps1.
$lockPath = Join-Path $workRoot 'deploy.lock'
$lockStream = $null
try {
  $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Create,
    [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
} catch [System.IO.IOException] {
  $hr = $_.Exception.HResult -band 0xFFFF
  if (($hr -ne 0x20) -and ($hr -ne 0x21)) {
    Write-Host ('CHYBA: deploy.lock sa neda otvorit: ' + $_.Exception.Message)
    exit 1
  }
  $holder = ''
  try {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open,
      [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
    $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
    $holder = $sr.ReadToEnd().Trim()
    $sr.Close()
  } catch {}
  Write-Host 'CHYBA: iny beh (in-SU testy, foto okien alebo export test) prave bezi - zdielany SketchUp Plugins adresar sa neda izolovat.'
  if ($holder) { Write-Host ('  Drzitel zamku: ' + $holder) }
  Write-Host ('  Zamok: ' + $lockPath)
  Write-Host '  Pockaj, kym beziaci beh dobehne, a spusti skript znova.'
  exit 2
} catch [System.UnauthorizedAccessException] {
  Write-Host ('CHYBA: deploy.lock sa neda otvorit: ' + $_.Exception.Message)
  exit 1
}

$exitCode = 1
$run = $null
$kTree = $null
try {
  $lockInfo = 'PID={0} start={1} repo={2} export_test' -f $PID, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $repo
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockInfo)
  $lockStream.Write($bytes, 0, $bytes.Length)
  $lockStream.Flush()

  # Sentinel predchadzajuceho behu (vzor run_su_tests.ps1): zijuca instancia bez koncoveho
  # markera blokuje dalsi deploy.
  $sentinel = Join-Path $workRoot 'last_run.txt'
  if (Test-Path $sentinel) {
    $prev = @{}
    Get-Content $sentinel -Encoding UTF8 | ForEach-Object {
      $kk, $vv = $_ -split '=', 2
      if ($kk) { $prev[$kk] = $vv }
    }
    $prevSuPid = 0
    [void][int]::TryParse([string]$prev['pid'], [ref]$prevSuPid)
    $prevOut = [string]$prev['out']
    $prevAlive = $false
    if ($prevSuPid -gt 0) {
      $pp = Get-Process -Id $prevSuPid -ErrorAction SilentlyContinue
      if ($pp -and ($pp.ProcessName -eq 'SketchUp')) { $prevAlive = $true }
    }
    $prevDone = $prevOut -and (Test-Path $prevOut) -and (Select-String -Path $prevOut -Pattern 'KONIEC SUBORU' -Quiet)
    if ($prevAlive -and -not $prevDone) {
      Write-Host ('CHYBA: instancia SketchUpu z predchadzajuceho behu (PID ' + $prevSuPid + ') stale bezi a jej beh NEDOBEHOL (chyba koncovy marker).')
      Write-Host ('  Vysledok predchadzajuceho behu: ' + $prevOut)
      Write-Host '  Zavri visiacu instanciu (alebo pockaj na dobeh) a spusti skript znova.'
      $exitCode = 2
      exit 2
    }
  }

  # --- pracovny koren (KRATKA cesta: MAX_PATH pri checkoute K) ---------------------
  $kpRoot = Join-Path $env:TEMP 'nxkp'
  New-Item -ItemType Directory -Force -Path $kpRoot | Out-Null
  Get-ChildItem $kpRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-1) } |
    ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false -ErrorAction Stop } catch {} }
  & git -C $repo worktree prune
  $run = Join-Path $kpRoot (Get-Date -Format 'yyMMdd_HHmmss')
  New-Item -ItemType Directory -Force -Path $run | Out-Null

  # --- snimka profilu (raz, len citanie zdroja) --------------------------------------
  $snap = Join-Path $run 'snap'
  New-Item -ItemType Directory -Force -Path $snap | Out-Null
  $profDir = Join-Path $env:APPDATA 'NOXUN'
  if (Test-Path $profDir) { Copy-Item $profDir $snap -Recurse -Force }
  else {
    New-Item -ItemType Directory -Force -Path (Join-Path $snap 'NOXUN') | Out-Null
    Write-Host "POZOR: profil $profDir neexistuje - oba behy zacnu s prazdnym profilom."
  }

  # --- strom K ---------------------------------------------------------------------------
  $kTree = Join-Path $run 't'
  & git -C $repo -c core.longpaths=true worktree add --detach --quiet $kTree $baseSha
  if ($LASTEXITCODE -or -not (Test-Path (Join-Path $kTree 'INSTALL_noxun_engine.ps1'))) {
    Write-Host "CHYBA: git worktree add pre K ($baseSha) zlyhal."
    exit 1
  }

  $probe = Join-Path $repo 'tests\sketchup\su_export_probe.rb'
  if (-not (Test-Path $probe)) { Write-Host "CHYBA: sonda chyba: $probe"; exit 1 }

  function ConvertTo-RubySq([string]$s) {
    return ($s -replace '\\', '/') -replace "'", "\'"
  }
  function Get-TreeVersion([string]$tree) {
    $m = [regex]::Match((Get-Content (Join-Path $tree 'noxun_engine.rb') -Raw -Encoding UTF8), "VERSION\s*=\s*'([^']+)'")
    if ($m.Success) { return $m.Groups[1].Value }
    return '?'
  }

  $bootLoad = @'
ENV['APPDATA'] = '__APPDATA__'
ENV['NOXUN_EXPORT_OUT'] = '__OUT__'
ENV['NOXUN_EXPORT_LOG'] = '__LOG__'
ENV['NOXUN_EXPORT_WORK'] = '__WORK__'
begin
  load '__PROBE__'
rescue ScriptError, StandardError => ex
  begin
    File.open('__LOG__', 'a:UTF-8') do |f|
      f.puts("FAIL: boot: load sondy zlyhal: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
      f.puts('=== KONIEC SUBORU ===')
    end
  rescue StandardError
    nil
  end
  UI.start_timer(3.0, false) { Sketchup.quit }
end
'@

  # Jeden beh (K alebo P): deploy -> sonda -> marker -> samoukoncenie SketchUpu.
  function Invoke-Side([string]$Label, [string]$Tree) {
    $r = @{ Label = $Label; Version = (Get-TreeVersion $Tree); Work = (Join-Path $run $Label); Hung = $false; Fails = @() }
    $r.Out = Join-Path $r.Work 'out'
    $r.Log = Join-Path $r.Work 'probe_log.txt'
    Write-Host ('--- beh {0}: v{1} ({2}) ---' -f $Label, $r.Version, $Tree)
    $global:LASTEXITCODE = 0
    & (Join-Path $Tree 'INSTALL_noxun_engine.ps1') | Out-Null
    if ($LASTEXITCODE) { $r.Fails += "deploy pluginu zlyhal (exit $LASTEXITCODE)"; return $r }
    New-Item -ItemType Directory -Force -Path $r.Out | Out-Null
    $modelCopy = Join-Path $r.Work (Split-Path $Model -Leaf)
    Copy-Item -LiteralPath $Model $modelCopy -Force
    $appdata = Join-Path $r.Work 'AppData'
    New-Item -ItemType Directory -Force -Path $appdata | Out-Null
    Copy-Item (Join-Path $snap 'NOXUN') $appdata -Recurse -Force
    $bootText = $bootLoad.Replace('__APPDATA__', (ConvertTo-RubySq $appdata)).Replace('__OUT__', (ConvertTo-RubySq $r.Out))
    $bootText = $bootText.Replace('__LOG__', (ConvertTo-RubySq $r.Log)).Replace('__WORK__', (ConvertTo-RubySq $r.Work))
    $bootText = $bootText.Replace('__PROBE__', (ConvertTo-RubySq $probe)) -replace "`r`n", "`n"
    $boot = Join-Path $r.Work 'boot.rb'
    [System.IO.File]::WriteAllText($boot, $bootText, (New-Object System.Text.UTF8Encoding($false)))
    $proc = Start-Process -FilePath $su -ArgumentList '-RubyStartup', "`"$boot`"", "`"$modelCopy`"" -PassThru
    $null = $proc.Handle
    [System.IO.File]::WriteAllLines($sentinel,
      [string[]]@(('pid={0}' -f $proc.Id), ('out={0}' -f $r.Log)),
      (New-Object System.Text.UTF8Encoding($false)))
    $deadline = (Get-Date).AddMinutes(6)
    $finished = $false
    while ((Get-Date) -lt $deadline) {
      if ((Test-Path $r.Log) -and (Select-String -Path $r.Log -Pattern 'KONIEC SUBORU' -Quiet)) { $finished = $true; break }
      Start-Sleep -Seconds 3
    }
    if (-not $finished) {
      $r.Fails += 'TIMEOUT 6 min bez koncoveho markera - instancia SketchUpu mozno STALE BEZI (skript ju NEZABIJA, zavri ju rucne)'
      $r.Hung = $true
      return $r
    }
    Remove-Item $sentinel -Force -ErrorAction SilentlyContinue -Confirm:$false
    if (-not $proc.WaitForExit(120000)) {
      $r.Fails += ('instancia SketchUpu (PID ' + $proc.Id + ') sa do 120 s nezavrela sama - skript ju NEZABIJA, zavri ju rucne')
      $r.Hung = $true
    }
    foreach ($l in (Get-Content $r.Log -Encoding UTF8)) { if ($l -like 'FAIL:*') { $r.Fails += $l } }
    return $r
  }

  $k = Invoke-Side 'K' $kTree
  $p = $null
  if (-not $k.Hung) { $p = Invoke-Side 'P' $repo }

  # --- porovnanie --------------------------------------------------------------------------
  Write-Host ''
  $verdictOk = $false
  if ($p) {
    $report = Join-Path $run 'report.txt'
    & $ruby (Join-Path $repo 'scripts\export_compare.rb') $k.Out $p.Out '--log-k' $k.Log '--log-p' $p.Log '--out' $report | Out-Null
    $cmpExit = $LASTEXITCODE
    if (Test-Path $report) { Get-Content $report -Encoding UTF8 | ForEach-Object { Write-Host $_ } }
    else { Write-Host 'CHYBA: porovnavac nevytvoril report.'; $cmpExit = 1 }
    $verdictOk = ($cmpExit -eq 0)
  }
  foreach ($side in @($k, $p)) {
    if ($side -and $side.Fails.Count -gt 0) {
      Write-Host ('CHYBY behu {0}:' -f $side.Label)
      $side.Fails | ForEach-Object { Write-Host ('  - ' + $_) }
      $verdictOk = $false
    }
  }
  Write-Host ''
  if ($verdictOk) { Write-Host 'EXPORT-TEST: P == K'; $exitCode = 0 }
  else { Write-Host 'EXPORT-TEST: P != K'; $exitCode = 1 }
  Write-Host ('  K = {0} (v{1}, {2})' -f $Base, $k.Version, $baseSha.Substring(0, 8))
  if ($p) { Write-Host ('  P = checkout {0} (v{1}) - ostava NASADENY v SketchUpe' -f $repo, $p.Version) }
  else { Write-Host ('  P sa nespustil; v SketchUpe ostava nasadeny K (v{0}) - nasad P: INSTALL_noxun_engine.ps1' -f $k.Version) }
  Write-Host ('  pracovny priecinok: ' + $run)
} finally {
  if ($kTree -and (Test-Path $kTree) -and -not $KeepWork) {
    try { & git -C $repo worktree remove --force $kTree } catch {}
    if (Test-Path $kTree) { try { Remove-Item $kTree -Recurse -Force -Confirm:$false -ErrorAction Stop } catch {} }
    try { & git -C $repo worktree prune } catch {}
  }
  if ($lockStream) { $lockStream.Close() }
  Remove-Item $lockPath -Force -ErrorAction SilentlyContinue -Confirm:$false
}
exit $exitCode
