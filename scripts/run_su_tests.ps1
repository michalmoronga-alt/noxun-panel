# Noxun Engine - spustenie in-SketchUp test runnera (tests/sketchup/su_runner.rb).
# Overena slucka: INSTALL deploy -> samostatna instancia SketchUp s -RubyStartup
# nad KOPIOU _dev/ENGINEtests.skp -> poll na koncovy marker -> vypis vysledku.
# Testovacie okno SketchUpu predvolene NEZATVARAME (pravidlo repa) - zavrie ho
# pouzivatel; volitelny prepinac -CloseWhenDone (nizsie) to meni.
#
# Paralelne behy (nalez 30.8.2026): kazdy beh ma VLASTNY run_* priecinok
# (vysledok, boot.rb, kopia modelu, AppData sandbox), aby si dva behy
# neprepisovali subory. SketchUp Plugins adresar je vsak JEDEN pre vsetky behy
# a deploy sa izolovat neda — druhy sucasny beh by prepisal nasadeny plugin
# (prvy by potom testoval cudzi kod). Preto CELY beh drzi vyhradny deploy.lock
# a druhy beh sa odmietne s jasnou hlaskou (exit 2) namiesto tichej kolizie.
#
# -CloseWhenDone (nalez 20.9.2026): pri autonomnych davkach bezi runner 5-10x
# za den a kazda idle instancia drzi ~1,5 GB - 12 otvorenych instancii nechalo
# 5 GB z 32 a novy beh uviazol (Welcome obrazovka, ziadny su_result.txt).
# S prepinacom si instancia po zapisani koncoveho markera SAMA (v boot.rb,
# teda vnutri SketchUpu) zbavi priznaku zmien - ulozi run-KOPIU modelu na jej
# vlastnu cestu (povodny _dev model sa nikdy nedotkne; zaloha pri zlyhani =
# `Model#close(true)`, na Windows podla API dokumentacie File/New bez otazky)
# - a ukonci sa cez `Sketchup.quit` (pyta sa LEN pri neulozenych zmenach;
# `send_action` je deprecated a nepouziva sa). Marker je BRANA: bez neho sa
# instancia nezatvara (visiaci beh ostava na diagnostiku) a skript proces
# NIKDY nezabija - po markeri len pocka na jeho zanik (max 120 s) a ak
# neskonci, nahlasi to. Predvolene VYPNUTY, aby sa nezmenilo dnesne
# spravanie (idle okno ostane otvorene).
#
# ZNAMY STAV (3 plne behy 20.9.2026, vzdy 2813 PASS / 0 FAIL): po CELEJ
# testovacej sade konci teardown SketchUpu 2026 pri quit padom 0xC0000374
# (heap corruption v ntdll) - az PO zapisani vysledku a ulozeni kopie; proces
# zanikne do par sekund, neostane ziadny helper proces, dialog ani recovery
# subor, Windows si to len ticho zapise do WER. Sondy s malym modelom (aj
# s otvorenym Inspectorom/Studiom, overlaymi add+remove, nastrojmi a s
# upratanim pluginu pred quit) koncia s kodom 0 - pricina je v stave po celej
# relacii a izolovat sa nepodarila (File/New vs. save, okna, overlay ani
# nastroje to nie su). Skript exit kod instancie vypise (aj hex), ale verdikt
# testov sa nim NEMENI - ten je hotovy skor.
param([switch]$CloseWhenDone)
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
  # "Iny beh bezi" = LEN sharing/lock violation (Win32 0x20/0x21). Ostatne
  # IOException (zla cesta, plny disk...) su realne chyby, nie kontencia —
  # tie nesmu dostat hlasku "pockaj na beziaci beh", ktory neexistuje.
  $hr = $_.Exception.HResult -band 0xFFFF
  if (($hr -ne 0x20) -and ($hr -ne 0x21)) {
    Write-Host ('CHYBA: deploy.lock sa neda otvorit: ' + $_.Exception.Message)
    Write-Host ('  Zamok: ' + $lockPath)
    exit 1
  }
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
  Write-Host 'CHYBA: iny beh in-SU testov prave bezi - zdielany SketchUp Plugins adresar sa neda izolovat.'
  if ($holder) { Write-Host ('  Drzitel zamku: ' + $holder) }
  else { Write-Host '  Drzitel zamku: (este sa nestihol zapisat)' }
  Write-Host ('  Zamok: ' + $lockPath)
  Write-Host '  Pockaj, kym beziaci beh dobehne (max ~8 min), a spusti skript znova.'
  exit 2
} catch [System.UnauthorizedAccessException] {
  # Napr. deploy.lock existuje ako PRIECINOK, alebo chybaju prava.
  Write-Host ('CHYBA: deploy.lock sa neda otvorit: ' + $_.Exception.Message)
  Write-Host ('  Zamok: ' + $lockPath)
  exit 1
}

$exitCode = 1
try {
  $lockInfo = 'PID={0} start={1} repo={2}' -f $PID, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $repo
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($lockInfo)
  $lockStream.Write($bytes, 0, $bytes.Length)
  $lockStream.Flush()

  # Sentinel predchadzajuceho behu (Codex review P2): deploy.lock zije len so
  # SKRIPTOM — po jeho timeoute/kille vsak odpojena instancia SketchUpu moze
  # testy stale VYKONAVAT a novy beh by jej prepisal Plugins. Sentinel nesie
  # PID instancie + cestu vysledku: kym instancia zije a marker konca nie je
  # zapisany, dalsi beh sa odmietne. Uspesne dobehnuty beh neblokuje nic
  # (marker existuje) — idle okno moze ostat otvorene (pravidlo repa).
  $sentinel = Join-Path $workRoot 'last_run.txt'
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
      # Kontrola mena chrani pred recyklovanym PID (iny proces s tym istym
      # cislom). Presne -eq, nie -like 'SketchUp*': wildcard by matchol aj
      # kratkovezke sketchup_webhelper procesy, ktore PID recykluju najviac.
      if ($p -and ($p.ProcessName -eq 'SketchUp')) { $prevAlive = $true }
    }
    $prevDone = $prevOut -and (Test-Path $prevOut) -and (Select-String -Path $prevOut -Pattern 'KONIEC SUBORU' -Quiet)
    if ($prevAlive -and -not $prevDone) {
      Write-Host ('CHYBA: instancia SketchUpu z predchadzajuceho behu (PID ' + $prevSuPid + ') stale bezi a jej testy NEDOBEHLI (chyba koncovy marker).')
      Write-Host ('  Vysledok predchadzajuceho behu: ' + $prevOut)
      Write-Host '  Zavri visiacu instanciu (alebo pockaj na dobeh) a spusti skript znova.'
      exit 2
    }
  }

  # Deploy az POD zamkom — od tejto chvile je v Plugins kod tohto behu.
  # INSTALL konci pri chybe cez `exit 1` (nie vynimkou) — `&` to nezhodi volajuceho,
  # preto explicitna kontrola. $LASTEXITCODE je ale SESSION-globalny a dedi sa aj
  # od prikazov, ktore bezali PRED tymto skriptom (INSTALL na uspesnej ceste exit
  # nevola a hodnotu nemeni), takze bez resetu by zvyskovy nenulovy kod zhodil
  # beh po USPESNOM deployi.
  $global:LASTEXITCODE = 0
  & (Join-Path $repo 'INSTALL_noxun_engine.ps1')
  if ($LASTEXITCODE) {
    Write-Host "CHYBA: deploy pluginu zlyhal (INSTALL_noxun_engine.ps1, exit $LASTEXITCODE)."
    exit 1
  }

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
  $closeLog = Join-Path $work 'close.log'
  # boot.rb sa sklada zo SINGLE-QUOTED here-stringov (PowerShell v nich nic
  # neinterpoluje, takze Ruby `#{}` ani `$` nic nerozbije) a cesty sa dosadia
  # cez Replace (hodnoty su uz escapovane pre Ruby literal). Zatvaracie `'@`
  # MUSI byt na zaciatku riadku - preto su tie bloky bez odsadenia.
  $bootHead = @'
ENV['APPDATA'] = '__NOXUN_APPDATA__'
ENV['NOXUN_SU_OUT'] = '__NOXUN_OUT__'
'@
  # -CloseWhenDone: samozatvorenie bezi VNUTRI SketchUpu (Ruby timer), nie zo
  # skriptu - skript by musel proces zabit a to je zakazane. Timer sa instaluje
  # PRED `load` runnera, aby marker zachytil aj ked runner zlyha uz pri nacitani.
  $closeBlock = @'
# -CloseWhenDone (run_su_tests.ps1): po koncovom markeri v su_result.txt sa
# instancia SAMA zbavi priznaku zmien (ulozi run-kopiu modelu; zaloha = File/New)
# a ukonci SketchUp. Bez markera sa nikdy nezatvara (visiaci beh ostava na
# diagnostiku); proces nikto nezabija.
module NoxunSuClose
  OUT = '__NOXUN_OUT__'
  LOG = '__NOXUN_CLOSE_LOG__'
  MARKER = '=== KONIEC SUBORU ==='
  POLL_S = 2.0  # perioda kontroly markera
  GRACE_S = 3.0 # po markeri: nechat dobehnut debounce timery observerov (0,2 s) + rezerva

  class << self
    def log(msg)
      File.open(LOG, 'a') { |f| f.puts("#{Time.now.strftime('%H:%M:%S')} #{msg}") }
    rescue StandardError
      nil
    end

    # binread: vysledok nesie lubovolne bajty z hlasok testov - include?
    # nad ASCII markerom tak nikdy nespadne na kodovani.
    def marker_written?
      File.exist?(OUT) && File.binread(OUT).include?(MARKER)
    rescue StandardError
      false
    end

    def start
      log("cakam na marker: #{OUT}")
      @timer = UI.start_timer(POLL_S, true) do
        begin
          if marker_written?
            UI.stop_timer(@timer)
            log("marker zapisany -> zatvaram o #{GRACE_S} s")
            UI.start_timer(GRACE_S, false) { close_and_quit }
          end
        rescue StandardError => ex
          log("tick: #{ex.class}: #{ex.message}")
        end
      end
    end

    # Krok 1: zbavit sa priznaku zmien, aby sa Sketchup.quit nepytal "ulozit?".
    # Primarne ULOZENIM run-kopie modelu na jej vlastnu cestu: kopia zije len
    # v run_* priecinku (povodny _dev model sa nikdy nedotkne), nevymiena sa
    # dokument (ziadne onNewModel eventy pluginu) a ulozeny stav ostava na
    # diagnostiku. Model#close(true) (= na Windows File/New bez otazky) je
    # ZALOHA, ked ulozenie neprejde. Krok 2 az v DALSOM ticku timera, aby
    # ulozenie/File/New dobehlo.
    def close_and_quit
      model = Sketchup.active_model
      log("pred close: modified=#{model ? model.modified? : 'nil'} path=#{model ? model.path.inspect : 'nil'}")
      saved = false
      if model && !model.path.to_s.empty?
        begin
          saved = model.save ? true : false
        rescue StandardError => ex
          log("save kopie: #{ex.class}: #{ex.message}")
        end
      end
      log("save run-kopie -> #{saved}")
      unless saved
        model.close(true) if model
        log('zaloha: close(true) = File/New')
      end
      UI.start_timer(1.0, false) { quit_now }
    rescue StandardError => ex
      log("close: #{ex.class}: #{ex.message}")
    end

    # Poistka: keby bol dokument pred quit stale "spinavy" (save zlyhal a po
    # File/New by plugin nieco zapisal v onNewModel), Sketchup.quit by cakal na
    # klik v dialogu "ulozit zmeny?". Ulozenie dokumentu ako stub do run
    # priecinka (nikdy nie povodny model) priznak zmien zmaze. Sonda 20.9.2026
    # nad umyselne zaspinenym dokumentom: stub ulozeny, exit 0.
    def quit_now
      model = Sketchup.active_model
      dirty = model ? model.modified? : false
      log("po close: modified=#{dirty} path=#{model ? model.path.inspect : 'nil'}")
      if dirty
        begin
          stub = File.join(File.dirname(OUT), 'closing_stub.skp')
          log("stub save #{model.save(stub) ? 'OK' : 'ZLYHAL'}: #{stub}")
        rescue StandardError => ex
          log("stub save: #{ex.class}: #{ex.message}")
        end
      end
      log('Sketchup.quit')
      Sketchup.quit
    rescue StandardError => ex
      log("quit: #{ex.class}: #{ex.message}")
    end
  end
end
NoxunSuClose.start
'@
  # `load` v begin/rescue: SyntaxError/LoadError (ScriptError) NIE su
  # StandardError - rescue v su_runner.rb by ich nechytil a beh by skoncil
  # 8-min timeoutom bez markera (s -CloseWhenDone navyse visiacou instanciou).
  # FAIL riadok + marker = rychly a citatelny vysledok; bez prepinaca ostane
  # okno otvorene ako doteraz.
  $bootLoad = @'
begin
  load '__NOXUN_RUNNER__'
rescue ScriptError, StandardError => ex
  begin
    File.open('__NOXUN_OUT__', 'a') do |f|
      f.puts("FAIL: boot: load su_runner.rb zlyhal: #{ex.class}: #{ex.message} @ #{Array(ex.backtrace).first}")
      f.puts('=== KONIEC SUBORU ===')
    end
  rescue StandardError
    nil
  end
end
'@
  $bootText = $bootHead + "`n"
  if ($CloseWhenDone) { $bootText += $closeBlock + "`n" }
  $bootText += $bootLoad + "`n"
  $bootText = $bootText.Replace('__NOXUN_APPDATA__', $appdataRb).Replace('__NOXUN_OUT__', $outRb)
  $bootText = $bootText.Replace('__NOXUN_RUNNER__', $runner).Replace('__NOXUN_CLOSE_LOG__', (ConvertTo-RubySq $closeLog))
  $bootText = $bootText -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText($boot, $bootText, (New-Object System.Text.UTF8Encoding($false)))

  Write-Host "Spustam SketchUp (model: $(Split-Path $modelCopy -Leaf), work: $work)..."
  $suProc = Start-Process -FilePath $su -ArgumentList '-RubyStartup', "`"$boot`"", "`"$modelCopy`"" -PassThru
  # .NET pasca: bez skoreho dotyku Handle je ExitCode po zaniku procesu null.
  $null = $suProc.Handle
  # Sentinel sa zapisuje hned po starte (pod zamkom) — pri kille skriptu ostane
  # a ochrani beziacu instanciu pred deployom dalsieho behu (vid vyssie).
  [System.IO.File]::WriteAllLines($sentinel,
    [string[]]@(('pid={0}' -f $suProc.Id), ('out={0}' -f $out)),
    (New-Object System.Text.UTF8Encoding($false)))

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
    # Testy dobehli (marker je v $out) — sentinel uz nema co chranit. Zmazanie
    # brani falosnemu bloku, keby $out neskor zmizol (napr. cistenie %TEMP%)
    # a idle okno este zilo.
    Remove-Item $sentinel -Force -ErrorAction SilentlyContinue -Confirm:$false
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
    if ($CloseWhenDone) {
      # Marker je zapisany -> boot.rb instanciu zatvara SAM (save kopie + quit).
      # Skript LEN caka; kill je zakazany (viz hlavicka). Zamok drzime aj pocas
      # cakania - dalsi beh nesmie deployovat pod instanciu, ktora este zije.
      $closeWaitS = 120
      Write-Host ('Cakam na samozatvorenie instancie SketchUpu (PID ' + $suProc.Id + ', max ' + $closeWaitS + ' s)...')
      if ($suProc.WaitForExit($closeWaitS * 1000)) {
        $suExit = $suProc.ExitCode
        if ($suExit -eq 0) {
          Write-Host ('Instancia SketchUpu (PID ' + $suProc.Id + ') skoncila cisto (exit kod 0).')
        } else {
          # Pad v teardowne SketchUpu AZ PO zapisani vysledku (viz hlavicka) - verdikt testov je uz hotovy.
          Write-Host ('Instancia SketchUpu (PID ' + $suProc.Id + ') skoncila s exit kodom ' + $suExit + ' (0x' + ('{0:X8}' -f $suExit) + ') - pad v teardowne PO zapisani vysledku, verdikt testov to nemeni.')
        }
      } else {
        Write-Host ('POZOR: instancia SketchUpu (PID ' + $suProc.Id + ') sa do ' + $closeWaitS + ' s NEZAVRELA sama - skript ju NEZABIJA, zavri ju rucne.')
      }
      if (Test-Path $closeLog) { Get-Content $closeLog -Encoding UTF8 | ForEach-Object { Write-Host ('  close.log: ' + $_) } }
      else { Write-Host ('  close.log chyba (' + $closeLog + ') - boot.rb sa k zatvaraniu nedostal.') }
    }
  } else {
    Write-Host 'TIMEOUT po 8 min.'
    if (Test-Path $out) { Get-Content $out | Write-Host }
    # Zamok drzi tento skript, nie SketchUp — jeho ukoncenim sa uvolni. Kym
    # instancia zije bez koncoveho markera, dalsi beh odmietne SENTINEL.
    Write-Host 'POZOR: instancia SketchUpu pravdepodobne STALE BEZI - dalsi beh sa sam odmietne, kym nedobehne alebo ju nezavries.'
    if ($CloseWhenDone) { Write-Host '  -CloseWhenDone: instancia sa zavrie sama, AK sa koncovy marker este objavi; bez markera ostava otvorena na diagnostiku.' }
  }
} finally {
  # Zamok sa uvolnuje az PO vyhodnoteni — SketchUp nacitava plugin pocas celeho
  # startu a skorsie uvolnenie by pustilo cudzi deploy pod rozbehnuty beh.
  if ($lockStream) { $lockStream.Close() }
  # Remove-Item je len kozmetika (FileMode::Create stale subor prevezme aj bez
  # mazania). POZOR pri buducich upravach: FileShare::Read NEobsahuje
  # FILE_SHARE_DELETE, takze zamok medzicasom prevzaty novym behom sa zmazat
  # NEDA (IOException) a SilentlyContinue to ticho zje — to je ZAMER, mazanie
  # nesmie vytrhnut subor novemu drzitelovi.
  Remove-Item $lockPath -Force -ErrorAction SilentlyContinue -Confirm:$false
}
exit $exitCode
