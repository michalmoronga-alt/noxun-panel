<#
.SYNOPSIS
  Noxun Engine - SkAgent doctor. Diagnostika a bezpecne upratanie MCP portu (VBO SkAgent bridge).

.DESCRIPTION
  Bridge VBO SkAgent bezi na main threade SketchUpu a drzi TCP port (default 7891).
  Ked SketchUp zamrzne, proces port drzi dalej, ale /health uz neodpoveda -> nova
  instancia VBO si potichu vezme nahodny port a MCP na fixnom 7891 ostane mrtve.
  Skript zisti drzitela portu (zdroj pravdy = Get-NetTCPConnection), overi /health
  (aj ze odpoved je naozaj VBO bridge v SketchUpe) a pri mrtvom/zamrznutom drzitelovi
  ponukne kill s viacnasobnymi bezpecnostnymi poistkami.

  BEZPECNOST (zakazka sa NIKDY nesmie stratit):
    - Zivy bridge, ktoreho okno NEvyzera testovaci, sa NIKDY nezabije - len varuje.
    - Zamrznute PODOZRIVE okno (mozna zakazka) sa NEzabije ani s -Force; kill vyzaduje
      interaktivne vypisane potvrdenie ('zabit'). -Force plati LEN na zamrznute testovacie okno.
    - Pred kazdym killom re-verifikacia (rovnaky PID drzi port, rovnaky StartTime, /health
      stale mrtvy) - proti TOCTOU race a recyklacii PID.
    - Viac vlastnikov portu / necitatelny drzitel = nejednoznacne -> nic sa nezabija.

  Exit kody:
    0 = zdravy bridge v testovacom okne, alebo mrtvy testovaci drzitel uspesne odstraneny
    1 = bridge nebezi (na porte nikto nepocuva)
    2 = mrtvy drzitel NEODSTRANENY (chyba prepinac, nejednoznacne, alebo kill/uvolnenie zlyhalo)
    3 = bezpecnostne zastavenie (zive/podozrive okno, neznama odpoved na porte, kill zruseny raceom)

.PARAMETER Port
  TCP port bridge (default 7891).

.PARAMETER Kill
  Ponukne zabitie mrtveho drzitela. Interaktivne pyta potvrdenie; v neinteraktivnej
  session (automatizacia) sa bez -Force NEzabija.

.PARAMETER Force
  Zabije mrtve TESTOVACIE okno bez potvrdenia. Na zive/podozrive/zamrznute-zakazkove okno NEMA vplyv.

.PARAMETER Quiet
  Minimalny vystup (diagnosticky sum sa potlaci; bezpecnostne a vysledkove hlasky ostavaju).

.EXAMPLE
  powershell -File scripts\skagent_doctor.ps1
.EXAMPLE
  powershell -File scripts\skagent_doctor.ps1 -Kill
#>
param(
  [int]$Port = 7891,
  [switch]$Kill,
  [switch]$Force,
  [switch]$Quiet
)

# --- vypis (rescpektuje -Quiet) ------------------------------------------------
function Say([string]$msg, [string]$color = 'Gray') {
  if (-not $Quiet) { Write-Host $msg -ForegroundColor $color }
}
# Bezpecnostne / vysledkove hlasky - vzdy viditelne (aj v -Quiet).
function SayAlways([string]$msg, [string]$color = 'Gray') {
  Write-Host $msg -ForegroundColor $color
}

# --- ZUZENA heuristika testovacieho okna (nález Codex #1: '*test*'/'*Untitled*' su
#     prilis siroke - "Contest Kitchen", neulozena zakazka). Ukotvene vzory:
#     'enginetests' (testovaci projekt) a 'untitled test' (Michalovo test okno). ------
function Test-IsTestWindow([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return $false } # bez titulu -> radsej varuj
  $lc = $t.ToLowerInvariant()
  if ($lc -like '*enginetests*') { return $true }
  if ($lc -like '*untitled test*') { return $true }
  return $false
}

# --- je session naozaj interaktivna? (konzervativne - Read-Host by inak v automatizacii
#     zablokoval alebo zlyhal). Prompt povol LEN v potvrdenom interaktivnom ConsoleHost. -
function Test-Interactive {
  try { if ($Host.Name -ne 'ConsoleHost') { return $false } } catch { return $false }
  try { if ([Environment]::UserInteractive -eq $false) { return $false } } catch {}
  try { if ([Console]::IsInputRedirected) { return $false } } catch {}
  return $true
}

# --- dedupnute platne PID-y, ktore POCUVAJU na porte (IPv4/IPv6 moze duplikovat) -----
function Get-ListenerPids([int]$p) {
  $c = @(Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue)
  return @($c | Select-Object -ExpandProperty OwningProcess -Unique |
      Where-Object { $_ -and ($_ -ne 0) } | ForEach-Object { [int]$_ })
}

# --- doplnkova info z info.json (pid+port posledneho startu; NIE zdroj pravdy) --------
function Show-InfoJson {
  $p = Join-Path $env:APPDATA 'VBO\SkAgent\mcp\info.json'
  if (-not (Test-Path $p)) { return }
  try {
    $j = Get-Content -Raw $p -ErrorAction Stop | ConvertFrom-Json
    if (($null -ne $j.pid) -or ($null -ne $j.port)) {
      Say ("info.json (posledny start): pid={0} port={1}" -f $j.pid, $j.port) DarkGray
    }
  } catch {
    Say "info.json existuje, ale neda sa precitat." DarkGray
  }
}

# --- /health check -> objekt alebo $null (mrtvy/zamrznuty) ---------------------------
function Get-Health([int]$p) {
  try {
    return Invoke-RestMethod -Uri ("http://127.0.0.1:{0}/health" -f $p) -TimeoutSec 3 -ErrorAction Stop
  } catch {
    return $null
  }
}

# --- je /health odpoved naozaj VBO bridge? (nález #7: iny HTTP 200 nestaci) -----------
function Test-HealthValid($h, [int]$p) {
  if ($null -eq $h) { return $false }
  $okFlag = ($h.ok -eq $true) -or ($h.running -eq $true)
  # Codex GH #63 P2: cudzia sluzba moze vratit nenumericky 'port' -> [int] cast by
  # zhodil skript PRED exit 3 vetvou. TryParse: neparsovatelny port = NEvalidny bridge.
  $portOk = $true
  if ($null -ne $h.port) {
    $n = 0
    if ([int]::TryParse([string]$h.port, [ref]$n)) { $portOk = ($n -eq $p) } else { $portOk = $false }
  }
  return ($okFlag -and $portOk)
}

# ================================ HLAVNA LOGIKA ================================

# 1) Kto drzi port? (zdroj pravdy)
$pids = Get-ListenerPids $Port
if ($pids.Count -eq 0) {
  Say "Bridge nebezi - na porte $Port nikto nepocuva." Yellow
  Say "V SketchUpe zapni Extensions -> VBO SkAgent -> Toggle Bridge (LEN v testovacom okne)." Yellow
  exit 1
}
if ($pids.Count -gt 1) {
  # nález #6: viac vlastnikov = nejednoznacne -> nic nezabijat
  SayAlways ("POZOR: port {0} drzi VIAC procesov ({1}) - nejednoznacne, nic sa nezabija." -f $Port, ($pids -join ', ')) Yellow
  SayAlways "Over rucne, ktory je zamrznuty SketchUp, a zabi konkretny PID." Yellow
  exit 2
}
$procId = $pids[0]

# 2) Proces drzitela
$proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
if (-not $proc) {
  # nález #5: Get-Process zlyhal != volny port. Re-query listenera.
  $recheck = Get-ListenerPids $Port
  if ($recheck -contains $procId) {
    SayAlways ("Port {0} drzi PID {1}, ale proces sa neda precitat (Access denied/systemovy) - NEZABIJAM." -f $Port, $procId) Yellow
    SayAlways "Over rucne a pripadne zabi z administratorskej konzoly." Yellow
    exit 2
  }
  Say "Port $Port hlasil PID $procId, ale proces uz zmizol (uvolnuje sa)." Yellow
  exit 1
}

$title = $proc.MainWindowTitle
$titleDisp = if ([string]::IsNullOrWhiteSpace($title)) { '(bez titulu)' } else { $title }
$startTime = try { $proc.StartTime } catch { $null }
$responding = try { $proc.Responding } catch { $null }

Say "== SkAgent doctor - port $Port ==" Cyan
Say ("PID:        {0}" -f $proc.Id)
Say ("Proces:     {0}" -f $proc.ProcessName)
Say ("Okno:       {0}" -f $titleDisp)
Say ("Start:      {0}" -f $(if ($null -eq $startTime) { 'n/a' } else { $startTime }))
Say ("Responding: {0}" -f $(if ($null -eq $responding) { 'n/a' } else { $responding }))
Show-InfoJson

# 3) /health -> zije main thread a je to naozaj VBO bridge?
$health = Get-Health $Port

if ($null -ne $health) {
  # Nieco na porte ODPOVEDA. Over, ze je to VBO bridge v SketchUpe (nález #7).
  $validVbo = (Test-HealthValid $health $Port) -and ($proc.ProcessName -like '*SketchUp*')
  if (-not $validVbo) {
    SayAlways ""
    SayAlways ("PORT {0} odpoveda, ale NEVYZERA to ako VBO bridge v SketchUpe." -f $Port) Red
    SayAlways ("  proces={0}  health.ok={1}  health.running={2}  health.port={3}" -f $proc.ProcessName, $health.ok, $health.running, $health.port) Yellow
    SayAlways "Podozrivy stav - NIC sa nezabija. Over rucne, co drzi port." Yellow
    exit 3
  }

  if (Test-IsTestWindow $title) {
    # (a) zdravy bridge v testovacom okne
    Say ""
    Say "OK: bridge bezi a odpoveda v testovacom okne." Green
    Say ("uptime_sec={0}  requests={1}  SU={2}" -f $health.uptime_sec, $health.requests, $health.sketchup_version) Green
    if ($Quiet) { SayAlways ("skagent_doctor: OK port {0} PID {1} ('{2}')" -f $Port, $procId, $titleDisp) Green }
    exit 0
  }

  # (b) zdravy, ale okno NEvyzera testovaci -> mozna zakazka
  SayAlways ""
  SayAlways ("!!! VAROVANIE: bridge bezi v okne '{0}' - mozno ZAKAZKA !!!" -f $titleDisp) Red
  SayAlways "Prikazy cez MCP by sa vykonali TAM (v tomto okne)." Red
  SayAlways "Prepni bridge do testovacieho okna: v tomto okne Toggle Bridge VYPNI, v testovacom ZAPNI." Yellow
  SayAlways "Proces sa NEZABIJA (zije a moze drzat neulozenu pracu)." Yellow
  exit 3
}

# (c) --- /health NEODPOVEDA -> mrtvy/zamrznuty drzitel ---
SayAlways ""
SayAlways ("PROBLEM: port {0} drzi PID {1}, ale /health NEODPOVEDA (mrtvy/zamrznuty bridge)." -f $Port, $procId) Red
SayAlways "Nova instancia VBO by si vzala nahodny port -> MCP na fixnom $Port ostane mrtve." Yellow

# Codex GH #63 P2: aj MRTVY drzitel musi vyzerat ako SketchUp (healthy vetva to uz
# overuje). Inak je to cudzi proces na porte a kill by zabil nesuvisiacu aplikaciu.
if ($proc.ProcessName -notlike '*SketchUp*') {
  SayAlways ("Drzitel '{0}' (PID {1}) NIE JE SketchUp - cudzi proces, NIC sa nezabija." -f $proc.ProcessName, $procId) Yellow
  SayAlways "Over rucne, co bezi na porte, a uvolni ho manualne (alebo zmen mcp_port v Dashboarde VBO)." Yellow
  exit 3
}

$looksTest = Test-IsTestWindow $title
$interactive = Test-Interactive
$doKill = $false

if ($looksTest) {
  # zamrznute TESTOVACIE okno — kill je bezpecny
  if ($Force) {
    $doKill = $true
  } elseif ($Kill -and $interactive) {
    $ans = Read-Host "Zabit zamrznuty testovaci bridge PID $procId ? [a/N]"
    if ($ans -match '^(a|ano|y|yes)$') { $doKill = $true }
  } elseif ($Kill) {
    SayAlways "Neinteraktivna session: pre kill zamrznuteho testovacieho okna pouzi -Force." Yellow
  } else {
    Say ""
    Say "Rucne zabitie (zamrznute testovacie okno):" Yellow
    Say ("  Stop-Process -Id {0} -Force" -f $procId)
    Say "Alebo znova:  scripts\skagent_doctor.ps1 -Kill" Yellow
  }
} else {
  # zamrznute PODOZRIVE okno (mozna ZAKAZKA) — nález #2: -Force sa VEDOME ignoruje
  SayAlways ("!!! POZOR: zamrznute okno '{0}' NEVYZERA testovaci - MOZNA ZAKAZKA !!!" -f $titleDisp) Red
  SayAlways "Zabitim procesu STRATIS neulozenu pracu. -Force sa tu VEDOME ignoruje." Yellow
  if ($Kill -and $interactive) {
    $ans = Read-Host "Naozaj zabit PID $procId ? Napis presne 'zabit' pre potvrdenie"
    if ($ans -ceq 'zabit') { $doKill = $true }
  } else {
    SayAlways "Kill NEvykonany (podozrive okno + neinteraktivne alebo bez -Kill)." Yellow
    SayAlways "Ak si ISTY, ze je to zamrznuty testovaci SketchUp, zabi rucne:" Yellow
    SayAlways ("  Stop-Process -Id {0} -Force" -f $procId)
    exit 2
  }
}

if (-not $doKill) {
  exit 2
}

# --- TOCTOU re-verifikacia tesne pred killom (nález #3) ---
if (-not ((Get-ListenerPids $Port) -contains $procId)) {
  SayAlways "PID $procId uz nedrzi port $Port (medzitym sa zmenil vlastnik) - kill ZRUSENY." Yellow
  exit 3
}
$proc2 = Get-Process -Id $procId -ErrorAction SilentlyContinue
if (-not $proc2) {
  SayAlways "Proces $procId medzitym zmizol - netreba nic zabijat." Green
  exit 0
}
$st2 = try { $proc2.StartTime } catch { $null }
if (($null -ne $startTime) -and ($null -ne $st2) -and ($st2 -ne $startTime)) {
  SayAlways "PID $procId bol recyklovany (iny StartTime) - kill ZRUSENY." Yellow
  exit 3
}
if ($null -ne (Get-Health $Port)) {
  SayAlways "Bridge medzitym ozil (/health odpovedal) - kill ZRUSENY." Yellow
  exit 3
}

# --- KILL ---
try {
  Stop-Process -Id $procId -Force -ErrorAction Stop
  SayAlways "Proces $procId zabity." Green
} catch {
  SayAlways ("Kill zlyhal: {0}" -f $_.Exception.Message) Red
  exit 2
}

# Retry loop na uvolnenie portu (max ~5 s).
$released = $false
for ($i = 0; $i -lt 10; $i++) {
  Start-Sleep -Milliseconds 500
  if ((Get-ListenerPids $Port).Count -eq 0) { $released = $true; break }
}
if ($released) {
  SayAlways "Port $Port uvolneny - spusti SketchUp a zapni Toggle Bridge v testovacom okne." Green
  exit 0
}

# nález #4: port sa neuvolnil -> chybovy kod + aktualny vlastnik (NIE optimisticke exit 0)
$owner = (Get-ListenerPids $Port) -join ', '
SayAlways ("Proces zabity, ale port {0} je STALE obsadeny (PID: {1}). Skus znova o chvilu." -f $Port, $owner) Red
exit 2
