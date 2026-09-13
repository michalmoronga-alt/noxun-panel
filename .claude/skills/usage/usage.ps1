# usage.ps1 - kompaktny stav kvot Claude + Codex pre orchestratora (skill `usage`).
#
# Cita CodexBar CLI (codexbar-cli.exe usage -p <provider> --json), vypise 2-3 riadky
# a volitelne zapise riadok do lokalneho logu behov (JSONL, mimo repa):
#   %APPDATA%\NOXUN\Agent\usage_log.jsonl
#
# Pouzitie:
#   usage.ps1                                  # len vypis
#   usage.ps1 -Label "audit D-128" -Phase before
#   usage.ps1 -Label "audit D-128" -Phase after   # + delta oproti poslednemu `before` s tym istym Label
#   usage.ps1 -Gate codex -MinRemaining 10     # exit 3, ked Codex weekly zostatok < 10 %
#   usage.ps1 -Json                            # surovy JSON oboch providerov (na debug, ~2 kB)
#
# Windows PowerShell 5.1 kompatibilne (bez ternary, bez ?? ).

param(
  [string]$Label = '',
  [ValidateSet('', 'before', 'after')][string]$Phase = '',
  [ValidateSet('', 'claude', 'codex')][string]$Gate = '',
  [int]$MinRemaining = 10,
  [switch]$Json
)

$ErrorActionPreference = 'Continue'
$cli = Join-Path $env:LOCALAPPDATA 'Programs\CodexBar\codexbar-cli.exe'
if (-not (Test-Path $cli)) {
  Write-Output "CodexBar CLI nenajdene: $cli (nainstaluj CodexBar alebo uprav cestu v usage.ps1)"
  exit 2
}

# Native stderr (WARN o cookies) ide do nul cez cmd - PS 5.1 by ho inak zabalil do NativeCommandError.
function Fetch-Once([string]$p) {
  $raw = cmd /c "`"$cli`" usage -p $p --json 2>nul"
  if (-not $raw) { return $null }
  try {
    $arr = @(ConvertFrom-Json -InputObject ($raw -join "`n"))
    if ($arr.Count -ge 1) { return $arr[0] } else { return $null }
  } catch { return $null }
}

# CodexBar obcas vrati `{"error": "..."}` (docasny vypadok OAuth/cookies) - jeden retry po 3 s,
# potom sa dovod PRIZNA v riadku providera (skratene), nikdy sa nevymysla stav.
function Fetch-Provider([string]$p) {
  $o = Fetch-Once $p
  if ($null -eq $o -or $o.error) { Start-Sleep -Seconds 3; $o2 = Fetch-Once $p; if ($o2) { $o = $o2 } }
  return $o
}

function Err-Text($o) {
  if ($null -eq $o) { return 'CodexBar nevratil data' }
  if ($o.error) { $e = [string]$o.error; if ($e.Length -gt 110) { $e = $e.Substring(0, 110) + '...' }; return 'docasne nedostupne: ' + $e }
  return 'CodexBar nevratil data'
}

function Pct($w) {
  if ($null -eq $w -or $null -eq $w.used_percent) { return $null }
  return [int][math]::Round([double]$w.used_percent)
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

$claude = Fetch-Provider 'claude'
$codex  = Fetch-Provider 'codex'

if ($Json) {
  Write-Output (ConvertTo-Json -InputObject @{ claude = $claude; codex = $codex } -Depth 8 -Compress)
  exit 0
}

# ---- Claude ---------------------------------------------------------------
$cl = @{ plan = $null; session = $null; weekly = $null; fable = $null; reset_session = $null; reset_weekly = $null }
if ($claude -and $claude.usage) {
  $u = $claude.usage
  $cl.plan = $u.login_method
  $cl.session = Pct $u.primary
  $cl.weekly = Pct $u.secondary
  $cl.reset_session = $u.primary.resets_at
  $cl.reset_weekly = $u.secondary.resets_at
  $fable = $null
  foreach ($x in @($u.extra_rate_windows)) { if ($x.id -like '*fable*') { $fable = $x.window } }
  if ($fable) { $cl.fable = Pct $fable }
  $line = 'Claude  ' + $cl.plan + ' | ' + (Win-Text 'session' $u.primary) + ' | ' + (Win-Text 'weekly' $u.secondary)
  if ($fable) { $line += ' | Fable-only ' + $cl.fable + ' %' }
  if ($claude.pace -and $claude.pace.primary) { $line += ' | tempo: ' + $claude.pace.primary.stage }
  Write-Output $line
} else {
  Write-Output ('Claude  ' + (Err-Text $claude))
}

# ---- Codex ----------------------------------------------------------------
$cx = @{ plan = $null; session = $null; weekly = $null; reset_session = $null; reset_weekly = $null }
if ($codex -and $codex.usage) {
  $u = $codex.usage
  $cx.plan = $u.login_method
  $cx.weekly = Pct $u.secondary
  $cx.reset_weekly = $u.secondary.resets_at
  if ($u.primary -and -not $u.primary.is_informational) { $cx.session = Pct $u.primary; $cx.reset_session = $u.primary.resets_at }
  $sess = 'session -'
  if ($null -ne $cx.session) { $sess = Win-Text 'session' $u.primary }
  elseif ($u.primary -and $u.primary.reset_description) { $sess = 'session: ' + $u.primary.reset_description }
  $line = 'Codex   ' + $cx.plan + ' | ' + $sess + ' | ' + (Win-Text 'weekly' $u.secondary)
  if ($codex.pace -and $codex.pace.secondary) {
    $st = $codex.pace.secondary.stage
    $will = 'vydrzi do resetu'
    if ($codex.pace.secondary.willLastToReset -eq $false) { $will = 'NEVYDRZI do resetu' }
    $line += ' | tempo: ' + $st + ', ' + $will
  }
  Write-Output $line
} else {
  Write-Output ('Codex   ' + (Err-Text $codex) + ' (vypadok prihlasenia CodexBaru byva docasny, skus o chvilu)')
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
    # Delta oproti poslednemu `before` s rovnakym Label. Zaporna delta = medzitym bol reset (Michal: resety chodia aj nahodne).
    $prev = $null
    foreach ($l in (Get-Content $log)) {
      try { $o = ConvertFrom-Json -InputObject $l } catch { continue }
      if ($o.label -eq $Label -and $o.phase -eq 'before') { $prev = $o }
    }
    if ($prev) {
      $parts = @()
      if ($null -ne $prev.codex.weekly -and $null -ne $cx.weekly) { $parts += ('Codex weekly {0:+#;-#;0} %' -f ($cx.weekly - $prev.codex.weekly)) }
      if ($null -ne $prev.claude.session -and $null -ne $cl.session) { $parts += ('Claude session {0:+#;-#;0} %' -f ($cl.session - $prev.claude.session)) }
      if ($null -ne $prev.claude.fable -and $null -ne $cl.fable) { $parts += ('Fable-only {0:+#;-#;0} %' -f ($cl.fable - $prev.claude.fable)) }
      $dur = ''
      try { $dur = ' za ' + [int]((Get-Date) - [DateTime]::Parse($prev.ts)).TotalMinutes + ' min' } catch {}
      $row.delta = ($parts -join ', ')
      Write-Output ('Spotreba "' + $Label + '"' + $dur + ': ' + ($parts -join ', ') + '  (zaporne = medzitym reset)')
    }
  }
  Add-Content -Path $log -Value (ConvertTo-Json -InputObject $row -Depth 5 -Compress) -Encoding UTF8
}

# ---- Brana (volitelne) ----------------------------------------------------
if ($Gate) {
  $used = $null
  if ($Gate -eq 'codex') { $used = $cx.weekly } else { $used = $cl.weekly }
  if ($null -eq $used) {
    Write-Output ('BRANA ' + $Gate + ': stav nedostupny -> rozhodni rucne')
    exit 4
  }
  $rem = 100 - $used
  if ($rem -lt $MinRemaining) {
    Write-Output ('BRANA ' + $Gate + ': zostatok weekly ' + $rem + ' % < ' + $MinRemaining + ' % -> NESPUSTAJ (nahradna brana)')
    exit 3
  }
  Write-Output ('BRANA ' + $Gate + ': zostatok weekly ' + $rem + ' % -> OK')
}
exit 0
