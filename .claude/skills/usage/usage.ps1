# usage.ps1 - kompaktny stav kvot Claude + Codex pre orchestratora (skill `usage`).
#
# Cita CodexBar CLI (codexbar-cli.exe usage -p <provider> --json), vypise riadok za providera
# (+ volitelne riadok Spotreba a riadok BRANA) a volitelne zapise riadok do lokalneho logu
# behov (JSONL, mimo repa): %APPDATA%\NOXUN\Agent\usage_log.jsonl
#
# Pouzitie:
#   usage.ps1                                   # stav oboch providerov
#   usage.ps1 -Provider codex                   # len jeden provider (setri rate-limitovany Claude endpoint)
#   usage.ps1 -Label "audit D-128" -Phase before
#   usage.ps1 -Label "audit D-128" -Phase after   # + delta oproti poslednemu `before` s tym istym Label
#   usage.ps1 -Gate codex -MinRemaining 10      # brana: exit 3, ked Codex weekly ZOSTATOK < 10 %
#   usage.ps1 -Json                             # surovy JSON providerov (debug; plan, percenta, resety, tempo)
#
# Exit kody: 0 = OK (brana presla alebo sa nepytala) · 2 = CodexBar CLI chyba (NEblokuje - rozhodni
# rucne) · 3 = brana NEPRESLA (zostatok pod prahom) · 4 = stav providera brany nedostupny (NEblokuje -
# rozhodni rucne). Blokujuci je LEN exit 3.
#
# -Gate bez explicitneho -Provider cita LEN providera brany (menej volani na rate-limitovany endpoint).
# Windows PowerShell 5.1 kompatibilne (bez ternary, bez ??, bez ?.). Subor je ASCII bez BOM.

param(
  [ValidateSet('both', 'claude', 'codex')][string]$Provider = 'both',
  [string]$Label = '',
  [ValidateSet('', 'before', 'after')][string]$Phase = '',
  [ValidateSet('', 'claude', 'codex')][string]$Gate = '',
  [int]$MinRemaining = 10,
  [switch]$Json
)

$ErrorActionPreference = 'Continue'
$cli = Join-Path $env:LOCALAPPDATA 'Programs\CodexBar\codexbar-cli.exe'
if (-not (Test-Path $cli)) {
  Write-Output "CodexBar CLI nenajdene: $cli (nainstaluj CodexBar alebo uprav cestu v usage.ps1) - exit 2 NEblokuje, rozhodni rucne"
  exit 2
}

if ($Gate -and -not $PSBoundParameters.ContainsKey('Provider')) { $Provider = $Gate }
$wantClaude = ($Provider -ne 'codex')
$wantCodex  = ($Provider -ne 'claude')

# Native stderr (WARN o cookies) ide do nul cez cmd - PS 5.1 by ho inak zabalil do NativeCommandError.
# Ziadny retry: Claude usage endpoint je rate-limitovany, druhy request hned po chybe limit len prehlbuje.
# Chyba providera sa PRIZNA v jeho riadku (skratene), stav sa nikdy nevymysla.
function Fetch-Provider([string]$p) {
  $raw = cmd /c "`"$cli`" usage -p $p --json 2>nul"
  if (-not $raw) { return $null }
  try {
    $arr = @(ConvertFrom-Json -InputObject ($raw -join "`n"))
    if ($arr.Count -ge 1) { return $arr[0] } else { return $null }
  } catch { return $null }
}

function Err-Text($o) {
  if ($o -and $o.error) {
    $e = [string]$o.error
    if ($e.Length -gt 110) { $e = $e.Substring(0, 110) + '...' }
    return 'docasne nedostupne: ' + $e
  }
  return 'CodexBar nevratil data'
}

# Surova hodnota (Double) pre branu, zaokruhlena len na vypis.
function Raw-Pct($w) {
  if ($null -eq $w -or $null -eq $w.used_percent) { return $null }
  return [double]$w.used_percent
}
function Pct($w) {
  $r = Raw-Pct $w
  if ($null -eq $r) { return $null }
  return [int][math]::Round($r, [MidpointRounding]::AwayFromZero)
}

function Reset-Text($w) {
  if ($null -eq $w -or -not $w.resets_at) { return 'reset n/a' }
  try {
    $t = ([DateTime]::Parse($w.resets_at, [Globalization.CultureInfo]::InvariantCulture, 'AdjustToUniversal')).ToLocalTime()
    $d = $t - (Get-Date)
    if ($d.TotalMinutes -lt 0) { $left = 'uz teraz' }
    elseif ($d.TotalHours -lt 24) { $left = ('o {0}h {1:00}m' -f [int][math]::Floor($d.TotalHours), $d.Minutes) }
    else { $left = ('o {0}d {1}h' -f $d.Days, $d.Hours) }
    return ('reset {0} {1}' -f $t.ToString('d.M. HH:mm'), $left)
  } catch { return 'reset n/a' }
}

function Win-Text([string]$name, $w) {
  $p = Pct $w
  if ($null -eq $p) { return "$name -" }
  return ('{0} {1} % ({2})' -f $name, $p, (Reset-Text $w))
}

$claude = $null; $codex = $null
if ($wantClaude) { $claude = Fetch-Provider 'claude' }
if ($wantCodex)  { $codex  = Fetch-Provider 'codex' }

if ($Json) {
  Write-Output (ConvertTo-Json -InputObject @{ claude = $claude; codex = $codex } -Depth 8 -Compress)
  exit 0
}

# ---- Claude ---------------------------------------------------------------
$cl = @{ session = $null; weekly = $null; fable = $null; weekly_raw = $null; reset_session = $null; reset_weekly = $null }
if ($wantClaude) {
  if ($claude -and $claude.usage) {
    $u = $claude.usage
    $cl.session = Pct $u.primary
    $cl.weekly = Pct $u.secondary
    $cl.weekly_raw = Raw-Pct $u.secondary
    $cl.reset_session = $u.primary.resets_at
    $cl.reset_weekly = $u.secondary.resets_at
    foreach ($x in @($u.extra_rate_windows)) { if ($x.id -like '*fable*') { $cl.fable = Pct $x.window } }
    $line = 'Claude  ' + [string]$u.login_method + ' | ' + (Win-Text 'session' $u.primary) + ' | ' + (Win-Text 'weekly' $u.secondary)
    if ($null -ne $cl.fable) { $line += ' | Fable-only ' + $cl.fable + ' %' }
    if ($claude.pace -and $claude.pace.primary) { $line += ' | tempo: ' + $claude.pace.primary.stage }
    Write-Output $line
  } else {
    Write-Output ('Claude  ' + (Err-Text $claude) + ' (bezne pri rate limite endpointu - nie porucha)')
  }
}

# ---- Codex ----------------------------------------------------------------
$cx = @{ session = $null; weekly = $null; weekly_raw = $null; reset_session = $null; reset_weekly = $null }
if ($wantCodex) {
  if ($codex -and $codex.usage) {
    $u = $codex.usage
    $cx.weekly = Pct $u.secondary
    $cx.weekly_raw = Raw-Pct $u.secondary
    $cx.reset_weekly = $u.secondary.resets_at
    if ($u.primary -and -not $u.primary.is_informational) { $cx.session = Pct $u.primary; $cx.reset_session = $u.primary.resets_at }
    $sess = 'session -'
    if ($null -ne $cx.session) { $sess = Win-Text 'session' $u.primary }
    elseif ($u.primary -and $u.primary.reset_description) { $sess = 'session: ' + $u.primary.reset_description }
    $line = 'Codex   ' + [string]$u.login_method + ' | ' + $sess + ' | ' + (Win-Text 'weekly' $u.secondary)
    if ($codex.pace -and $codex.pace.secondary) {
      $will = 'vydrzi do resetu'
      if ($codex.pace.secondary.willLastToReset -eq $false) { $will = 'NEVYDRZI do resetu' }
      $line += ' | tempo: ' + $codex.pace.secondary.stage + ', ' + $will
    }
    Write-Output $line
  } else {
    Write-Output ('Codex   ' + (Err-Text $codex) + ' (vypadok prihlasenia CodexBaru byva docasny)')
  }
}

# ---- Log behov (volitelne) ------------------------------------------------
if ($Label) {
  $dir = Join-Path $env:APPDATA 'NOXUN\Agent'
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
  $log = Join-Path $dir 'usage_log.jsonl'
  $row = @{
    ts = (Get-Date).ToString('o'); label = $Label; phase = $Phase
    claude = @{ session = $cl.session; weekly = $cl.weekly; fable = $cl.fable; reset_session = $cl.reset_session; reset_weekly = $cl.reset_weekly }
    codex  = @{ session = $cx.session; weekly = $cx.weekly; reset_session = $cx.reset_session; reset_weekly = $cx.reset_weekly }
  }
  if ($Phase -eq 'after' -and (Test-Path $log)) {
    # Delta oproti poslednemu `before` s rovnakym Label. Zaporna delta = medzitym bol reset (resety chodia aj nahodne).
    $prev = $null
    foreach ($l in (Get-Content $log)) {
      if (-not $l) { continue }
      try { $o = ConvertFrom-Json -InputObject $l } catch { continue }
      if ($o.label -eq $Label -and $o.phase -eq 'before') { $prev = $o }
    }
    if ($prev) {
      $parts = @()
      if ($null -ne $prev.codex.weekly -and $null -ne $cx.weekly) { $parts += ('Codex weekly {0:+#;-#;0} %' -f ($cx.weekly - $prev.codex.weekly)) }
      if ($null -ne $prev.claude.session -and $null -ne $cl.session) { $parts += ('Claude session {0:+#;-#;0} %' -f ($cl.session - $prev.claude.session)) }
      if ($null -ne $prev.claude.weekly -and $null -ne $cl.weekly) { $parts += ('Claude weekly {0:+#;-#;0} %' -f ($cl.weekly - $prev.claude.weekly)) }
      if ($null -ne $prev.claude.fable -and $null -ne $cl.fable) { $parts += ('Fable-only {0:+#;-#;0} %' -f ($cl.fable - $prev.claude.fable)) }
      $dur = ''
      try { $dur = ' za ' + [int]((Get-Date) - [DateTime]::Parse($prev.ts)).TotalMinutes + ' min' } catch {}
      $row.delta = ($parts -join ', ')
      Write-Output ('Spotreba "' + $Label + '"' + $dur + ': ' + ($parts -join ', ') + '  (zaporne = medzitym reset)')
    }
  }
  # UTF-8 BEZ BOM (Add-Content -Encoding UTF8 by v PS 5.1 zapisal BOM a jq/node/python by na 1. riadku padli).
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::AppendAllText($log, (ConvertTo-Json -InputObject $row -Depth 5 -Compress) + [Environment]::NewLine, $utf8)
}

# ---- Brana (volitelne) - pocita zo SUROVEJ hodnoty (90,5 % pouzitych = zostatok 9,5 %, nie 10) ---
if ($Gate) {
  $used = $null
  if ($Gate -eq 'codex') { $used = $cx.weekly_raw } else { $used = $cl.weekly_raw }
  if ($null -eq $used) {
    Write-Output ('BRANA ' + $Gate + ': stav nedostupny -> exit 4, NEblokuje, rozhodni rucne')
    exit 4
  }
  $rem = 100 - $used
  if ($rem -lt $MinRemaining) {
    Write-Output ('BRANA ' + $Gate + ' (weekly): zostatok ' + ('{0:0.#}' -f $rem) + ' % < ' + $MinRemaining + ' % -> NESPUSTAJ (nahradna brana), exit 3')
    exit 3
  }
  Write-Output ('BRANA ' + $Gate + ' (weekly): zostatok ' + ('{0:0.#}' -f $rem) + ' % -> OK')
}
exit 0
