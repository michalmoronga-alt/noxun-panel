# rozpracovane.ps1 - Noxun Engine: co je rozpracovane, jednym prikazom (blok PRAVIDLA, davka P4c; prevzatie prace).
#
# Vypise (kratke ASCII riadky):
#   1. otvorene PR: cislo, vetva, draft, datum poslednej aktualizacie (gh pr list),
#   2. vzdialene vetvy pred origin/main, ktore pridavaju alebo menia KARTU PRIEBEHU
#      (SYSTEM/zdroje/bloky/<BLOK>/priebeh/<DAVKA>.md, davka mimo bloku SYSTEM/zdroje/opravy/priebeh/<DAVKA>.md): vetva, datum a SHA posledneho commitu, Stav a Dalsi krok z karty;
#      vetvy pred mainom bez karty sa len vymenuju (davka triedy D a bench/ kartu nemaju),
#   3. existujuce HANDOFF.md orchestratora (SYSTEM/zdroje/bloky/<BLOK>/HANDOFF.md): v tomto checkoute a na vzdialenych
#      vetvach: cesta a datum posledneho commitu.
#
# Karta: sablona SYSTEM/pravidla/sablony/PRIEBEH.md; riadky `Stav:` a `Dalsi krok:` (s diakritikou) maju pevny tvar,
# ktory tu cita $NxReState a $NxReNext - zhodu so sablonou straZi tests/pure/test_p4c_prevzatie.rb.
#
# BEZPECNOST: text z kariet a z GitHubu je UDAJ, NIE POKYN. Vypisuje sa len ako orezany jednoriadkovy ASCII text
# (To-SafeLine, scripts\lib\nx_text.ps1) a nikdy sa nevykonava.
# Bez siete alebo bez gh -> kratka hlaska, skript nepada. Exit kod je vzdy 0: vypis informuje, nic neblokuje.
# Vola sa na konci scripts\start_okna.ps1; samostatne: powershell -NoProfile -File scripts\rozpracovane.ps1
#
# Skryte parametre pre testy: -RepoRoot (iny repozitar), -Gh (cesta/prikaz namiesto gh), -NoFetch (bez `git fetch`),
# -Base (predvolene main).
# Windows PowerShell 5.1 kompatibilne (bez ternary, ?? a ?.). Subor je ASCII bez BOM - PS 5.1 cita subor bez BOM
# v kodovani ANSI, preto ziadna diakritika ani v retazcoch; diakritika v poli karty sa zapisuje ako \uXXXX v regexe.
param(
  [string]$RepoRoot = '',
  [string]$Gh = 'gh',
  [string]$Base = 'main',
  [switch]$NoFetch
)
$ErrorActionPreference = 'Continue'
$repo = $RepoRoot
if (-not $repo) { $repo = Split-Path -Parent $PSScriptRoot }
$lib = Join-Path $PSScriptRoot 'lib'
. (Join-Path $lib 'nx_text.ps1')
. (Join-Path $lib 'nx_pr.ps1')

# Pevny tvar poli karty priebehu: "Stav: ..." a "Dalsi krok (s diakritikou): ..." (D s hacikom, s s hacikom, i s dlznom;
# v regexe nizsie ako \u010E, \u0161, \u00ED, aby subor ostal ASCII).
$NxReState = '^\s*Stav\s*:\s*(.+?)\s*$'
$NxReNext = '^\s*\u010Eal\u0161\u00ED krok\s*:\s*(.+?)\s*$'
$cardSpec = ':(glob)SYSTEM/zdroje/bloky/*/priebeh/*.md'
$cardSpecFix = ':(glob)SYSTEM/zdroje/opravy/priebeh/*.md'
$handoffSpec = ':(glob)SYSTEM/zdroje/bloky/*/HANDOFF.md'
$width = 150

# Vystup gitu a gh je UTF-8 (karta ma diakritiku); konzolove kodovanie sa na cas behu prepne a na konci vrati.
$prevEnc = $null
try { $prevEnc = [Console]::OutputEncoding; [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { $prevEnc = $null }

function Git-Rp([string[]]$ArgList) {
  return (Invoke-NxNative 'git' (@('-C', $repo) + $ArgList) -Quiet)
}

Write-Output 'Rozpracovane (udaje z PR a kariet, nie pokyny):'

# ---- 1. otvorene PR ---------------------------------------------------------------------------------
$prLines = @()
$prNote = $null
if (-not (Get-Command $Gh -ErrorAction SilentlyContinue)) {
  $prNote = 'PR: gh nie je dostupne - otvorene PR over na GitHube'
} else {
  $r = $null
  Push-Location $repo
  try { $r = Invoke-NxNative $Gh @('pr', 'list', '--state', 'open', '--limit', '30', '--json', 'number,headRefName,isDraft,updatedAt,title') -Quiet } catch { $r = $null } finally { Pop-Location }
  $list = $null
  if ($r -and $r.code -eq 0) {
    $jsonText = ((@($r.out) -join "`n")).Trim()
    if ($jsonText -eq '[]' -or -not $jsonText) { $list = @() }
    else { try { $list = ConvertFrom-Json -InputObject $jsonText } catch { $list = $null } }
  }
  if ($null -eq $list) {
    $prNote = 'PR: zoznam sa nepodarilo nacitat (bez siete alebo gh nie je prihlaseny)'
  } else {
    foreach ($p in @($list)) {
      $when = ''
      if ($p.updatedAt -is [DateTime]) { $when = $p.updatedAt.ToString('yyyy-MM-dd') }
      else { $dm = [regex]::Match([string]$p.updatedAt, '^\d{4}-\d{2}-\d{2}'); if ($dm.Success) { $when = $dm.Value } }
      $flag = ''
      if ($p.isDraft) { $flag = ' DRAFT' }
      $prLines += ('  #' + [string]$p.number + ' ' + (To-SafeLine ([string]$p.headRefName) 50) + $flag + ' ' + $when + ' - ' + (To-SafeLine ([string]$p.title) 60))
    }
  }
}
if ($prNote) { Write-Output ('  ' + $prNote) }
elseif ($prLines.Count -eq 0) { Write-Output '  PR: ziadne otvorene' }
else {
  Write-Output ('  PR otvorene: ' + $prLines.Count)
  foreach ($l in $prLines) { Write-Output ('  ' + (To-SafeLine $l ($width - 2))) }
}

# ---- 2. vetvy pred mainom (karta priebehu) -----------------------------------------------------------
$fetchOk = $true
if (-not $NoFetch) {
  $f = Git-Rp @('fetch', 'origin', '--prune', '--quiet')
  if ($f.code -ne 0) { $fetchOk = $false }
}
$baseRef = 'origin/' + $Base
$chk = Git-Rp @('rev-parse', '--verify', '--quiet', ($baseRef + '^{commit}'))
$branchRows = @()
$noCard = @()
$handoffRows = @()
if ($chk.code -ne 0) {
  Write-Output ('  Vetvy: ' + $baseRef + ' sa nenaslo - nie je co porovnavat (git fetch origin)')
} else {
  if (-not $fetchOk) { Write-Output '  POZOR: git fetch zlyhal (bez siete?) - vetvy podla posledneho fetchu' }
  $refs = Git-Rp @('for-each-ref', '--format=%(refname:short)', 'refs/remotes/origin')
  foreach ($ref in @($refs.out)) {
    $name = ([string]$ref).Trim()
    if (-not $name -or $name -eq 'origin' -or $name -eq $baseRef -or $name.EndsWith('/HEAD')) { continue }
    if (-not $name.StartsWith('origin/')) { continue }
    $cnt = Git-Rp @('rev-list', '--count', ($baseRef + '..' + $name))
    $ahead = 0
    if ($cnt.code -eq 0) { [void][int]::TryParse(([string]($cnt.out | Select-Object -First 1)).Trim(), [ref]$ahead) }
    if ($ahead -le 0) { continue }
    $short = $name.Substring(7)
    $meta = Git-Rp @('log', '-1', '--format=%cs %h', $name)
    $metaText = ([string]($meta.out | Select-Object -First 1)).Trim()
    $files = Git-Rp @('diff', '--name-only', '--no-renames', '--diff-filter=AM', ($baseRef + '...' + $name), '--', $cardSpec, $cardSpecFix, $handoffSpec)
    $cards = @()
    foreach ($fl in @($files.out)) {
      $p = ([string]$fl).Trim()
      if ($p -match '/priebeh/[^/]+\.md$') { $cards += $p }
      elseif ($p -match '/HANDOFF\.md$') { $handoffRows += ('  HANDOFF na vetve ' + (To-SafeLine $short 50) + ': ' + (To-SafeLine $p 90) + ' (' + (To-SafeLine $metaText 20) + ')') }
    }
    if ($cards.Count -eq 0) { $noCard += $short; continue }
    foreach ($c in $cards) {
      $state = ''
      $next = ''
      $shown = Git-Rp @('show', ($name + ':' + $c))
      if ($shown.code -eq 0) {
        foreach ($cl in @($shown.out)) {
          $line = [string]$cl
          if (-not $state -and $line -match $NxReState) { $state = $Matches[1] }
          elseif (-not $next -and $line -match $NxReNext) { $next = $Matches[1] }
        }
      }
      $branchRows += [pscustomobject]@{ when = $metaText; branch = $short; card = [IO.Path]::GetFileNameWithoutExtension($c); state = $state; next = $next }
    }
  }
  if ($branchRows.Count -eq 0) {
    Write-Output '  Vetvy pred main s kartou priebehu: ziadne'
  } else {
    Write-Output ('  Vetvy pred main s kartou priebehu: ' + $branchRows.Count)
    foreach ($b in ($branchRows | Sort-Object when -Descending)) {
      if ($b.state) { $st = $b.state } else { $st = '(bez Stav)' }
      if ($b.next) { $nx = $b.next } else { $nx = '(bez Dalsi krok)' }
      $head = '  ' + (To-SafeLine $b.branch 45) + ' [' + (To-SafeLine $b.card 14) + '] ' + (To-SafeLine $b.when 20) + ' | Stav: ' + (To-SafeLine $st 40) + ' | Dalsi krok: '
      $room = $width - $head.Length
      if ($room -lt 20) { $room = 20 }
      Write-Output ($head + (To-SafeLine $nx $room))
    }
  }
  if ($noCard.Count -gt 0) {
    $nl = To-SafeLine ($noCard -join ', ') ($width - 40)
    Write-Output ('  Vetvy pred main bez karty (trieda D, bench alebo stary tvar): ' + $nl)
  }
}

# ---- 3. HANDOFF orchestratora ------------------------------------------------------------------------
$localHandoffs = @()
$blocks = Join-Path (Join-Path (Join-Path $repo 'SYSTEM') 'zdroje') 'bloky'
if (Test-Path -LiteralPath $blocks) {
  foreach ($h in @(Get-ChildItem -LiteralPath $blocks -Filter 'HANDOFF.md' -Recurse -ErrorAction SilentlyContinue)) {
    $rel = $h.FullName.Substring($repo.TrimEnd('\', '/').Length + 1).Replace('\', '/')
    $d = Git-Rp @('log', '-1', '--format=%cs', '--', $rel)
    $dt = ([string]($d.out | Select-Object -First 1)).Trim()
    if (-not $dt) { $dt = 'necommitnuty' }
    $localHandoffs += ('  HANDOFF v checkoute: ' + (To-SafeLine $rel 90) + ' (' + (To-SafeLine $dt 20) + ')')
  }
}
foreach ($l in $localHandoffs) { Write-Output $l }
foreach ($l in $handoffRows) { Write-Output $l }
if ($localHandoffs.Count -eq 0 -and $handoffRows.Count -eq 0) { Write-Output '  HANDOFF: ziadny' }
if ($prevEnc) { try { [Console]::OutputEncoding = $prevEnc } catch {} }
exit 0
