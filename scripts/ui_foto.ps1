# Noxun Engine - FOTENIE OKIEN pre UI davky (D-10, blok 9 HARDENING, davka H2).
# Nastroj pre agentov, plugin sa nim nemeni. Jednym prikazom nafoti Inspector
# (bez vyberu + kontexty Korpus/Zony/Cela/Kovanie + karta dielca) a VSETKY sekcie Studia
# z realnych dat pluginu - bez interaktivneho SketchUpu, aj pri zamknutej obrazovke.
# Fotky idu do %TEMP% (report orchestratorovi -> Michal), NIKDY do gitu.
#
# Rezimy:
#   -Shoot (predvoleny)  vezme NAJNOVSIU USPESNU nahravku (so znackou NAHRAVKA_OK.txt,
#                        zapisuje ju -Record az po kontrole vysledku) alebo -Rec <priecinok>
#                        (aj starsia nahravka bez znacky). Ked ziadna uspesna nie je (napr.
#                        prvy beh po zavedeni znacky), zacni -Record. Skopiruje
#                        AKTUALNE noxun_engine/ui z tohto checkoutu do docasnej stranky,
#                        vlozi prehravac scripts/ui_foto/nx_stub.js (len do kopie, nikdy
#                        do repa), spusti lokalny server (python, len 127.0.0.1) a headless
#                        Chrome (fallback Edge) -> PNG: Inspector 486x850, Studio 1280x800,
#                        k tomu verzia "_long" na celu vysku obsahu + index.html
#                        kontaktny harok. Vystup %TEMP%\noxun_ui_foto\shots_<cas>_<PID>\.
#   -Record              NOVA nahravka v SketchUpe overenou sluckou runnera
#                        (SketchUp.exe -RubyStartup boot.rb <KOPIA _dev\ENGINEtests.skp>):
#                        deploy pluginu z tohto checkoutu, ukazkova kuchyna zo sablon,
#                        zaznam Ruby->JS (scripts/ui_foto/record.rb), instancia sa po
#                        koncovom markeri SAMA ulozi (len kopiu) a zavrie - proces sa
#                        NIKDY nezabija. Zdiela deploy.lock + sentinel s run_su_tests.ps1
#                        (exit 2 = iny beh prave bezi). Po nahravke rovno -Shoot
#                        (vypnes -NoShoot). Vystup %TEMP%\noxun_ui_foto\rec_<VERSION>_<cas>\.
#   -Only a,b            len podmnozina fotiek (id zo scripts/ui_foto/shots.json, napr.
#                        studio_cut,panel_cela; povolene aj zastupne znaky studio_*).
#   -FactoryData         nahravka nad cistym seedom katalogov (inak nad KOPIOU realnych
#                        katalogov %APPDATA%\NOXUN\Engine - povodne subory sa necitaju na zapis).
#
# Kedy co: zmena JS/CSS/HTML -> -Shoot (stara nahravka staci); zmena TVARU dat z Ruby
# (payload push_state, setStudio, ...) -> -Record (nahravka zastarala).
# HRANICE (aj v hlavicke harku): staticky stav (bez modalov, hoveru, rozbalenych
# ponuk), Chrome nie CEF (pismo/rozbalovacky sa mozu lisit), svetla tema. Ked
# prehranie skriptu v aktualnom UI padne, fotka nesie cerveny pas a harok kartu
# oznaci CHYBA (ziadna ticha prazdna fotka).
#
# Exit kody: 0 = OK, 1 = chyba (alebo aspon jedna fotka s problemom - harok je aj tak
# hotovy), 2 = iny beh SketchUpu drzi deploy.lock / visiaca instancia (pockaj).
param(
  [switch]$Record,
  [switch]$Shoot,
  [switch]$NoShoot,
  [string]$Rec = '',
  [string]$Only = '',
  [switch]$FactoryData
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$tool = Join-Path $PSScriptRoot 'ui_foto'
$fotoRoot = Join-Path $env:TEMP 'noxun_ui_foto'
New-Item -ItemType Directory -Force -Path $fotoRoot | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)
. (Join-Path $tool 'lib.ps1')  # Find-NxLatestRec, Select-NxShots, Set-NxRecOk, Get-NxShotStatus
# Fotka sa robi na konci virtualneho casu Chrome; prehravac posiela finalny report po
# SETTLE_MS (6000 ms, nx_stub.js) od prehrania - rozpocet musi byt s rezervou dlhsi.
$NxVirtualBudgetMs = 9500

function Get-NxVersion {
  $t = [System.IO.File]::ReadAllText((Join-Path $repo 'noxun_engine.rb'), $utf8)
  $m = [regex]::Match($t, "VERSION\s*=\s*'([^']+)'")
  if ($m.Success) { return $m.Groups[1].Value }
  return '0.0.0'
}

function Read-NxJson([string]$path) {
  return ([System.IO.File]::ReadAllText($path, $utf8) | ConvertFrom-Json)
}

# Best-effort upratanie docasnych priecinkov (kopie modelu su velke).
function Clear-NxOld([string]$filter, [int]$days) {
  Get-ChildItem $fotoRoot -Directory -Filter $filter -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-$days) } |
    ForEach-Object { try { Remove-Item $_.FullName -Recurse -Force -Confirm:$false -ErrorAction Stop } catch {} }
}

# Testovaci model: _dev\ENGINEtests.skp tohto checkoutu, vo worktree z HLAVNEHO
# checkoutu (_dev je gitignorovany a vo worktree nie je). Vracia '' ked chyba.
function Resolve-NxTestModel {
  $m = Join-Path $repo '_dev\ENGINEtests.skp'
  if (Test-Path $m) { return $m }
  try {
    $common = (& git -C $repo rev-parse --path-format=absolute --git-common-dir 2>$null)
    if ($common) {
      $main = Split-Path ($common.Trim() -replace '/', '\') -Parent
      $m2 = Join-Path $main '_dev\ENGINEtests.skp'
      if (Test-Path $m2) { return $m2 }
    }
  } catch {}
  return ''
}

function ConvertTo-RubySq([string]$s) {
  return ($s -replace '\\', '/') -replace "'", "\'"
}

# ---------------------------------------------------------------------------
# -Record
# ---------------------------------------------------------------------------
function Invoke-NxRecord {
  $su = 'C:\Program Files\SketchUp\SketchUp 2026\SketchUp\SketchUp.exe'
  if (-not (Test-Path $su)) { Write-Host "CHYBA: SketchUp nenajdeny: $su"; return @{ code = 1 } }
  $model = Resolve-NxTestModel
  if (-not $model) {
    Write-Host 'POZOR: _dev\ENGINEtests.skp sa nenasiel - nahravka pobezi v novom neulozenom modeli (moze ju zdrzat uvodna obrazovka SketchUpu).'
  }

  # ZDIELANY zamok s run_su_tests.ps1 (autorita a komentare: tam). Plugins adresar
  # je jeden, deploy sa izolovat neda -> naraz smie bezat len jeden beh.
  $suRoot = Join-Path $env:TEMP 'noxun_su_tests'
  New-Item -ItemType Directory -Force -Path $suRoot | Out-Null
  $lockPath = Join-Path $suRoot 'deploy.lock'
  $lockStream = $null
  try {
    $lockStream = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Create,
      [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
  } catch [System.IO.IOException] {
    $hr = $_.Exception.HResult -band 0xFFFF
    if (($hr -ne 0x20) -and ($hr -ne 0x21)) {
      Write-Host ('CHYBA: deploy.lock sa neda otvorit: ' + $_.Exception.Message)
      return @{ code = 1 }
    }
    $holder = ''
    try {
      $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::Open,
        [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
      $sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
      $holder = $sr.ReadToEnd().Trim()
      $sr.Close()
    } catch {}
    Write-Host 'CHYBA: iny beh SketchUpu (in-SU testy alebo nahravka) prave bezi - zdielany Plugins adresar sa neda izolovat.'
    if ($holder) { Write-Host ('  Drzitel zamku: ' + $holder) }
    Write-Host '  Pockaj, kym dobehne, a spusti skript znova.'
    return @{ code = 2 }
  } catch [System.UnauthorizedAccessException] {
    Write-Host ('CHYBA: deploy.lock sa neda otvorit: ' + $_.Exception.Message)
    return @{ code = 1 }
  }

  $res = @{ code = 1; rec = '' }
  try {
    $info = 'PID={0} start={1} repo={2} (ui_foto -Record)' -f $PID, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $repo
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($info)
    $lockStream.Write($bytes, 0, $bytes.Length)
    $lockStream.Flush()

    # Sentinel predchadzajuceho behu (ten isty subor a format ako runner).
    $sentinel = Join-Path $suRoot 'last_run.txt'
    if (Test-Path $sentinel) {
      $prev = @{}
      Get-Content $sentinel -Encoding UTF8 | ForEach-Object {
        $k, $v = $_ -split '=', 2
        if ($k) { $prev[$k] = $v }
      }
      $prevSuPid = 0
      [void][int]::TryParse([string]$prev['pid'], [ref]$prevSuPid)
      $prevOut = [string]$prev['out']
      $prevAlive = $false
      if ($prevSuPid -gt 0) {
        $p = Get-Process -Id $prevSuPid -ErrorAction SilentlyContinue
        if ($p -and ($p.ProcessName -eq 'SketchUp')) { $prevAlive = $true }
      }
      $prevDone = $prevOut -and (Test-Path $prevOut) -and (Select-String -Path $prevOut -Pattern 'KONIEC SUBORU' -Quiet)
      if ($prevAlive -and -not $prevDone) {
        Write-Host ('CHYBA: instancia SketchUpu z predchadzajuceho behu (PID ' + $prevSuPid + ') stale bezi a NEDOBEHLA.')
        Write-Host ('  Vysledok predchadzajuceho behu: ' + $prevOut)
        Write-Host '  Zavri visiacu instanciu (alebo pockaj na dobeh) a spusti skript znova.'
        $res.code = 2
        return $res
      }
    }

    $global:LASTEXITCODE = 0
    & (Join-Path $repo 'INSTALL_noxun_engine.ps1') | Out-Host
    if ($LASTEXITCODE) {
      Write-Host "CHYBA: deploy pluginu zlyhal (INSTALL_noxun_engine.ps1, exit $LASTEXITCODE)."
      return $res
    }

    Clear-NxOld 'work_*' 1
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $work = Join-Path $fotoRoot ('work_{0}_{1}' -f $stamp, $PID)
    $recDir = Join-Path $fotoRoot ('rec_{0}_{1}' -f (Get-NxVersion), $stamp)
    New-Item -ItemType Directory -Force -Path $work | Out-Null
    New-Item -ItemType Directory -Force -Path $recDir | Out-Null
    $result = Join-Path $work 'record_result.txt'

    # Izolovany %APPDATA% (vzor runnera): plugin cita ENV['APPDATA'] pri kazdom volani.
    # Predvolene KOPIA realnych katalogov (fotky ukazu skutocne sablony, materialy a
    # ceny), realne subory sa nikdy nezapisuju. Bez stavu aktualizacie, temy a lockov.
    $appdata = Join-Path $work 'AppData'
    $engDst = Join-Path $appdata 'NOXUN\Engine'
    New-Item -ItemType Directory -Force -Path $engDst | Out-Null
    $engSrc = Join-Path $env:APPDATA 'NOXUN\Engine'
    if ((-not $FactoryData) -and (Test-Path $engSrc)) {
      Get-ChildItem $engSrc -Force | Where-Object {
        $_.Name -notlike '*.lock' -and $_.Name -notlike '*.bak' -and
        $_.Name -notlike 'updater_settings*' -and $_.Name -notlike 'ui_theme*' -and $_.Name -notlike 'usage_stats*'
      } | ForEach-Object { Copy-Item $_.FullName -Destination $engDst -Recurse -Force }
      Write-Host ('Katalogy: KOPIA ' + $engSrc)
    } else {
      Write-Host 'Katalogy: cisty seed (-FactoryData)'
    }

    $modelCopy = ''
    if ($model) {
      # Meno MUSI zacinat na "ENGINEtests" - guard v record.rb inak nahravku odmietne.
      $modelCopy = Join-Path $work ('ENGINEtests_uifoto_{0}.skp' -f $PID)
      Copy-Item $model $modelCopy -Force
    }

    $boot = Join-Path $work 'boot.rb'
    $bootText = @'
ENV['APPDATA'] = '__APPDATA__'
ENV['NOXUN_UIFOTO_REC'] = '__REC__'
ENV['NOXUN_UIFOTO_RESULT'] = '__RESULT__'
begin
  load '__RECORD__'
rescue ScriptError, StandardError => ex
  begin
    File.open('__RESULT__', 'a') do |f|
      f.puts("FAIL: boot: load record.rb zlyhal: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
      f.puts('=== KONIEC SUBORU ===')
    end
  rescue StandardError
    nil
  end
  # Codex #434 P2: po markeri skript uvolni zamok - instancia nesmie ostat visiet.
  # Model sa nezmenil (record.rb sa ani nenacital), quit sa teda nepyta.
  UI.start_timer(2.0, false) { Sketchup.quit }
end
'@
    $bootText = $bootText.Replace('__APPDATA__', (ConvertTo-RubySq $appdata)).Replace('__REC__', (ConvertTo-RubySq $recDir))
    $bootText = $bootText.Replace('__RESULT__', (ConvertTo-RubySq $result)).Replace('__RECORD__', (ConvertTo-RubySq (Join-Path $tool 'record.rb')))
    $bootText = $bootText -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($boot, $bootText, $utf8)

    Write-Host "Spustam SketchUp (nahravka, work: $work)..."
    $argList = @('-RubyStartup', "`"$boot`"")
    if ($modelCopy) { $argList += "`"$modelCopy`"" }
    $suProc = Start-Process -FilePath $su -ArgumentList $argList -PassThru
    $null = $suProc.Handle
    [System.IO.File]::WriteAllLines($sentinel,
      [string[]]@(('pid={0}' -f $suProc.Id), ('out={0}' -f $result)), $utf8)

    $deadline = (Get-Date).AddMinutes(6)
    $finished = $false
    while ((Get-Date) -lt $deadline) {
      if ((Test-Path $result) -and (Select-String -Path $result -Pattern 'KONIEC SUBORU' -Quiet)) { $finished = $true; break }
      Start-Sleep -Seconds 3
    }
    if (-not $finished) {
      Write-Host 'TIMEOUT nahravky po 6 min.'
      if (Test-Path $result) { Get-Content $result -Encoding UTF8 | Write-Host }
      Write-Host 'POZOR: instancia SketchUpu pravdepodobne STALE BEZI - skript ju NEZABIJA; dalsi beh sa odmietne, kym ju nezavries.'
      return $res
    }
    Remove-Item $sentinel -Force -ErrorAction SilentlyContinue -Confirm:$false
    Write-Host ''
    Get-Content $result -Encoding UTF8 | Write-Host
    $failed = (Select-String -Path $result -Pattern '^FAIL:' | Measure-Object).Count
    Write-Host ('Cakam na samozatvorenie instancie SketchUpu (PID ' + $suProc.Id + ', max 120 s)...')
    if ($suProc.WaitForExit(120000)) {
      Write-Host ('Instancia SketchUpu skoncila (exit kod ' + $suProc.ExitCode + ').')
    } else {
      Write-Host ('POZOR: instancia SketchUpu (PID ' + $suProc.Id + ') sa do 120 s NEZAVRELA sama - skript ju NEZABIJA, zavri ju rucne.')
    }
    if ($failed -gt 0 -or -not (Test-Path (Join-Path $recDir 'index.json'))) {
      Write-Host "VYSLEDOK NAHRAVKY: $failed FAIL - nahravka nie je pouzitelna."
      return $res
    }
    # Marker uspechu AZ PO validacii - len taka nahravka moze byt predvolena pre -Shoot.
    Set-NxRecOk $recDir ('OK {0} PID={1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $PID)
    Write-Host ('VYSLEDOK NAHRAVKY: OK -> ' + $recDir)
    $res.code = 0
    $res.rec = $recDir
    return $res
  } finally {
    if ($lockStream) { $lockStream.Close() }
    Remove-Item $lockPath -Force -ErrorAction SilentlyContinue -Confirm:$false
  }
}

# ---------------------------------------------------------------------------
# -Shoot
# ---------------------------------------------------------------------------
function Find-NxBrowser {
  $cands = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'),
    (Join-Path $env:ProgramFiles 'Microsoft\Edge\Application\msedge.exe')
  )
  foreach ($c in $cands) { if ($c -and (Test-Path $c)) { return $c } }
  return ''
}

function Get-NxFreePort {
  $l = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
  $l.Start()
  $port = $l.LocalEndpoint.Port
  $l.Stop()
  return $port
}

function Stop-NxBrowserTree([string]$profileDir) {
  try {
    Get-CimInstance Win32_Process -Filter "Name='chrome.exe' OR Name='msedge.exe'" -ErrorAction Stop |
      Where-Object { $_.CommandLine -and $_.CommandLine.Contains($profileDir) } |
      ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction Stop } catch {} }
  } catch {}
}

function Invoke-NxShoot([string]$recDir) {
  if (-not $recDir) { $recDir = Find-NxLatestRec $fotoRoot }
  if (-not $recDir -or -not (Test-Path $recDir)) {
    Write-Host 'CHYBA: ziadna USPESNA nahravka - spusti najprv: scripts\ui_foto.ps1 -Record (alebo zadaj -Rec <priecinok>).'
    return 1
  }
  $recDir = (Resolve-Path $recDir).Path
  $browser = Find-NxBrowser
  if (-not $browser) { Write-Host 'CHYBA: Chrome ani Edge sa nenasiel.'; return 1 }
  $py = Get-Command python -ErrorAction SilentlyContinue
  if (-not $py) { $py = Get-Command py -ErrorAction SilentlyContinue }
  if (-not $py) { Write-Host 'CHYBA: python sa nenasiel (treba pre lokalny server).'; return 1 }

  $cfg = Read-NxJson (Join-Path $tool 'shots.json')
  $allShots = @($cfg.shots)
  try { $shots = @(Select-NxShots $allShots $Only) } catch { Write-Host ('CHYBA: ' + $_.Exception.Message); return 1 }

  Clear-NxOld 'site_*' 1
  Clear-NxOld 'chrome_*' 1
  Clear-NxOld 'shots_*' 14
  $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
  $outDir = Join-Path $fotoRoot ('shots_{0}_{1}' -f $stamp, $PID)
  $site = Join-Path $fotoRoot ('site_{0}_{1}' -f $stamp, $PID)
  $prof = Join-Path $fotoRoot ('chrome_{0}_{1}' -f $stamp, $PID)
  $reports = Join-Path $site '_reports'
  New-Item -ItemType Directory -Force -Path $outDir, $site, $prof, $reports | Out-Null

  # Docasna stranka: AKTUALNE ui/ z checkoutu (bez .rb) + stub + nahravka.
  $ui = Join-Path $repo 'noxun_engine\ui'
  Get-ChildItem $ui -Force | Where-Object { $_.Name -notlike '*.rb' -and $_.Name -ne 'panel' } |
    ForEach-Object { Copy-Item $_.FullName -Destination $site -Recurse -Force }
  Copy-Item (Join-Path $tool 'nx_stub.js') -Destination $site -Force
  foreach ($page in @('studio.html', 'panel.html')) {
    $p = Join-Path $site $page
    $html = [System.IO.File]::ReadAllText($p, $utf8)
    $rx = New-Object System.Text.RegularExpressions.Regex('(<meta\s+charset="[^"]*"\s*/?>)', 'IgnoreCase')
    if (-not $rx.IsMatch($html)) { Write-Host "CHYBA: $page nema <meta charset> - stub sa neda vlozit."; return 1 }
    $html = $rx.Replace($html, '$1<script src="nx_stub.js"></script>', 1)
    [System.IO.File]::WriteAllText($p, $html, $utf8)
  }
  $siteRec = Join-Path $site 'rec'
  New-Item -ItemType Directory -Force -Path $siteRec | Out-Null
  Get-ChildItem $recDir -File | Where-Object { $_.Name -match '^\d+_' } | ForEach-Object { Copy-Item $_.FullName -Destination $siteRec -Force }
  $recFiles = @(Get-ChildItem $siteRec -File | Where-Object { $_.Name -match '^\d+_' } | ForEach-Object { $_.Name } | Sort-Object)
  if ($recFiles.Count -eq 0) { Write-Host "CHYBA: nahravka $recDir nema ziadne subory NNNN_*."; return 1 }
  # index.json sa VZDY sklada nanovo z obsahu (aj pre starsiu nahravku bez neho).
  [System.IO.File]::WriteAllText((Join-Path $siteRec 'index.json'), (ConvertTo-Json -InputObject $recFiles -Compress), $utf8)

  $recVersion = '?'
  $recTime = (Get-Item $recDir).LastWriteTime.ToString('yyyy-MM-dd HH:mm')
  $metaPath = Join-Path $recDir 'meta.json'
  if (Test-Path $metaPath) {
    try { $rm = Read-NxJson $metaPath; $recVersion = [string]$rm.version; $recTime = [string]$rm.time } catch {}
  } else {
    $mv = [regex]::Match((Split-Path $recDir -Leaf), 'rec_(\d+\.\d+\.\d+)')
    if ($mv.Success) { $recVersion = $mv.Groups[1].Value }
  }

  $port = Get-NxFreePort
  $srv = Start-Process -FilePath $py.Source -ArgumentList @("`"$(Join-Path $tool 'serve.py')`"", "`"$site`"", $port, "`"$reports`"") -PassThru -WindowStyle Hidden
  $exit = 0
  $items = New-Object System.Collections.ArrayList
  try {
    $up = $false
    for ($i = 0; $i -lt 30; $i++) {
      try {
        $null = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri ("http://127.0.0.1:{0}/rec/index.json" -f $port)
        $up = $true; break
      } catch { Start-Sleep -Milliseconds 300 }
    }
    if (-not $up) { Write-Host 'CHYBA: lokalny server sa nespustil.'; return 1 }

    $modelPng = Join-Path $recDir 'model.png'
    if (Test-Path $modelPng) {
      Copy-Item $modelPng (Join-Path $outDir '00_model.png') -Force
      [void]$items.Add([pscustomobject]@{ id = 'model'; label = 'Model (SketchUp, ukazkova kuchyna)'; file = '00_model.png'; long = $null
                                          size = '1400x900'; status = 'ok'; errors = @() })
    }

    Write-Host ("Fotim {0} okien (prehliadac: {1}, nahravka: {2})..." -f $shots.Count, (Split-Path $browser -Leaf), $recDir)
    foreach ($s in $shots) {
      $idx = [array]::IndexOf($allShots, $s) + 1
      $size = $cfg.sizes.($s.kind)
      $w = [int]$size.width; $h = [int]$size.height
      $base = '{0:D2}_{1}' -f $idx, $s.id
      $q = 'upto={0}&kind={1}&shot={2}' -f [uri]::EscapeDataString($s.upto), $s.kind, $s.id
      if ($s.ctx) { $q += '&ctx=' + [uri]::EscapeDataString($s.ctx) }
      $url = 'http://127.0.0.1:{0}/{1}?{2}' -f $port, $size.page, $q
      $png = Join-Path $outDir ($base + '.png')
      $ok = Invoke-NxChrome $browser $prof $url $w $h $png
      $repPath = Join-Path $reports ($s.id + '.json')
      $rep = $null
      if (Test-Path $repPath) { try { $rep = Read-NxJson $repPath } catch {} }
      $verdict = Get-NxShotStatus $ok $rep
      $status = $verdict.status
      $errs = @($verdict.errors)
      $long = $null
      if ($ok -and $rep -and ([int]$rep.height -gt ($h + 24))) {
        $lh = [Math]::Min([int]$rep.height + 16, 12000)
        $lpng = Join-Path $outDir ($base + '_long.png')
        $lq = $q -replace 'shot=[^&]*', ('shot=' + $s.id + '_long')
        if (Invoke-NxChrome $browser $prof ('http://127.0.0.1:{0}/{1}?{2}' -f $port, $size.page, $lq) $w $lh $lpng) {
          $long = $base + '_long.png'
        }
      }
      if ($status -ne 'ok') { $exit = 1 }
      $tag = if ($status -eq 'ok') { 'OK   ' } elseif ($status -eq 'none') { 'BEZ REPORTU' } else { 'CHYBA' }
      Write-Host ('  {0} {1}{2}' -f $tag, $base, $(if ($long) { ' (+ long ' + $lh + ' px)' } else { '' }))
      foreach ($er in $errs) { Write-Host ('        ' + $er) }
      [void]$items.Add([pscustomobject]@{ id = $s.id; label = [string]$s.label; file = ($base + '.png'); long = $long
                                          size = ('{0}x{1}' -f $w, $h); status = $status; errors = @($errs) })
    }
  } finally {
    try { Stop-Process -Id $srv.Id -Force -ErrorAction Stop } catch {}
    Stop-NxBrowserTree $prof
    Start-Sleep -Milliseconds 500
    try { Remove-Item $site -Recurse -Force -Confirm:$false -ErrorAction Stop } catch {}
    try { Remove-Item $prof -Recurse -Force -Confirm:$false -ErrorAction Stop } catch {}
  }

  $head = ''
  try { $head = (& git -C $repo rev-parse --short HEAD 2>$null).Trim() } catch {}
  $dirty = ''
  try { if (& git -C $repo status --porcelain -- noxun_engine/ui 2>$null) { $dirty = ' + neulozene zmeny' } } catch {}
  $meta = [pscustomobject]@{
    ui = ('{0} ({1}{2})' -f (Get-NxVersion), $head, $dirty); rec_version = $recVersion; rec_time = $recTime
    shot_time = (Get-Date -Format 'yyyy-MM-dd HH:mm'); browser = (Split-Path $browser -Leaf); rec = $recDir
  }
  $data = ConvertTo-Json -Depth 6 -Compress -InputObject ([pscustomobject]@{ meta = $meta; items = @($items) })
  $tpl = [System.IO.File]::ReadAllText((Join-Path $tool 'sheet.html'), $utf8)
  [System.IO.File]::WriteAllText((Join-Path $outDir 'index.html'), $tpl.Replace('__NX_SHEET_DATA__', $data), $utf8)

  $nPng = @(Get-ChildItem $outDir -Filter '*.png').Count
  $nBad = @($items | Where-Object { $_.status -ne 'ok' }).Count
  Write-Host ''
  Write-Host ('Fotky: {0} PNG ({1} okien, {2} s problemom)' -f $nPng, @($items).Count, $nBad)
  Write-Host ('Harok: ' + (Join-Path $outDir 'index.html'))
  return $exit
}

function Invoke-NxChrome([string]$browser, [string]$prof, [string]$url, [int]$w, [int]$h, [string]$png) {
  if (Test-Path $png) { Remove-Item $png -Force -Confirm:$false }
  $a = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run', '--no-default-browser-check',
         '--disable-extensions', '--disable-sync', '--mute-audio', "--user-data-dir=`"$prof`"",
         "--window-size=$w,$h", ('--virtual-time-budget={0}' -f $NxVirtualBudgetMs), "--screenshot=`"$png`"", "`"$url`"")
  $p = Start-Process -FilePath $browser -ArgumentList $a -PassThru -WindowStyle Hidden
  if (-not $p.WaitForExit(90000)) {
    Stop-NxBrowserTree $prof
    return $false
  }
  return (Test-Path $png)
}

# ---------------------------------------------------------------------------
$code = 0
if ($Record) {
  $r = Invoke-NxRecord
  $code = [int]$r.code
  if ($code -eq 0 -and -not $NoShoot) { $code = Invoke-NxShoot $r.rec }
} else {
  $code = Invoke-NxShoot $Rec
}
exit $code
