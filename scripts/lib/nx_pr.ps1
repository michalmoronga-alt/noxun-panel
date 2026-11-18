# Noxun Engine - pomocne funkcie pre scripts\otvor_pr.ps1 (dot-source).
# Testy: tests/pure/test_p4a_skripty.rb
#
# Dolezite: doplnenie cisla PR meni IBA riadky, ktore vetva pridala voci base (z `git diff -U0`),
# a LEN v subroch zo zoznamu $NxPrNumberFiles - `PR #?` sa inde (aj v starych zaznamoch
# tychto suborov) vyskytuje ako TEXT pravidla a nesmie sa prepisat. Polozka so `*` je vzor cesty (`*` = jeden usek
# cesty, ako :(glob) v gite a G7_FILES v .claude/hooks/straz.js): rozvinie sa na subory zmenene vetvou.
#
# ASCII, bez ternary / ?? / ?. (PS 5.1 aj pwsh).

# Subory, v ktorych davka pise cislo PR (SYSTEM/pravidla/roly/IMPLEMENTATOR.md, Verzia a uzaver: "Cislo PR").
$NxPrNumberFiles = @(
  'SYSTEM/PLAN.md',
  'SYSTEM/STAV.md',
  'SYSTEM/archiv/KRONIKA.md',
  'SYSTEM/archiv/DOGFOODING_vyriesene.md',
  'SYSTEM/zdroje/bloky/*/kronika/*.md'
)
$NxPrPlaceholder = 'PR #?'

# Nativny prikaz s kontrolovanym stderr (PS 5.1 + EAP Stop by inak z kazdeho riadku stderr urobil chybu).
# Vracia @{ code; out } - out = pole riadkov stdout.
function Invoke-NxNative([string]$Exe, [string[]]$ArgList, [switch]$Quiet) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $global:LASTEXITCODE = 0
    if ($Quiet) { $out = & $Exe @ArgList 2>$null } else { $out = & $Exe @ArgList }
    return @{ code = [int]$global:LASTEXITCODE; out = @($out) }
  } finally {
    $ErrorActionPreference = $old
  }
}

# Cisla riadkov (1-based, vo verzii HEAD), ktore vetva pridala alebo zmenila v $RelPath voci $BaseRef.
function Get-NxAddedLineNumbers([string]$Repo, [string]$BaseRef, [string]$RelPath) {
  $r = Invoke-NxNative 'git' @('-C', $Repo, 'diff', '--no-color', '--no-ext-diff', '-U0', "$BaseRef...HEAD", '--', $RelPath)
  if ($r.code -ne 0) { throw "git diff zlyhal pre $RelPath (exit $($r.code))" }
  $nums = New-Object System.Collections.Generic.List[int]
  foreach ($l in $r.out) {
    $m = [regex]::Match([string]$l, '^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@')
    if (-not $m.Success) { continue }
    $start = [int]$m.Groups[1].Value
    $count = 1
    if ($m.Groups[2].Success) { $count = [int]$m.Groups[2].Value }
    for ($i = 0; $i -lt $count; $i++) { $nums.Add($start + $i) }
  }
  return $nums.ToArray()
}

# V $RelPath nahradi `PR #?` cislom len na riadkoch $Lines. Vracia pocet upravenych riadkov.
# S -DryRun nic nezapise. Zachova konce riadkov (LF aj CRLF) a kodovanie UTF-8 bez BOM.
function Set-NxPrNumberInFile([string]$Repo, [string]$RelPath, [int[]]$Lines, [string]$Number, [switch]$DryRun) {
  $path = Join-Path $Repo $RelPath
  if (-not (Test-Path -LiteralPath $path)) { return 0 }
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $text = [System.IO.File]::ReadAllText($path, $utf8)
  $parts = [regex]::Split($text, '(?<=\n)')
  $count = 0
  foreach ($n in $Lines) {
    $i = $n - 1
    if ($i -lt 0 -or $i -ge $parts.Length) { continue }
    if ($parts[$i].Contains($NxPrPlaceholder)) {
      $parts[$i] = $parts[$i].Replace($NxPrPlaceholder, "PR #$Number")
      $count++
    }
  }
  if ($count -gt 0 -and -not $DryRun) {
    [System.IO.File]::WriteAllText($path, ($parts -join ''), $utf8)
  }
  return $count
}

# Polozky $NxPrNumberFiles: presne cesty ostanu, vzor so `*` sa rozvinie na pridane alebo zmenene subory vetvy.
function Resolve-NxPrFiles([string]$Repo, [string]$BaseRef) {
  $out = @()
  foreach ($f in $NxPrNumberFiles) {
    if (-not $f.Contains('*')) { $out += $f; continue }
    $r = Invoke-NxNative 'git' @('-C', $Repo, 'diff', '--name-only', '--no-renames', '--diff-filter=AM', "$BaseRef...HEAD", '--', ":(glob)$f")
    if ($r.code -ne 0) { throw "git diff zlyhal pre $f (exit $($r.code))" }
    foreach ($l in $r.out) { $p = ([string]$l).Trim(); if ($p) { $out += $p } }
  }
  return $out
}

# Zo zmenenych suborov vetvy (voci $BaseRef) doplni cislo PR. Vracia pole [pscustomobject] { file; replaced }
# len pre subory, v ktorych sa nieco nahradilo (alebo by sa nahradilo pri -DryRun).
function Update-NxPrNumber([string]$Repo, [string]$BaseRef, [string]$Number, [switch]$DryRun) {
  $changed = @()
  foreach ($f in @(Resolve-NxPrFiles $Repo $BaseRef)) {
    $lines = @(Get-NxAddedLineNumbers $Repo $BaseRef $f)
    if ($lines.Count -eq 0) { continue }
    $c = Set-NxPrNumberInFile $Repo $f $lines $Number -DryRun:$DryRun
    if ($c -gt 0) { $changed += [pscustomobject]@{ file = $f; replaced = $c } }
  }
  return $changed
}

# Karta priebehu (SYSTEM/pravidla/sablony/PRIEBEH.md) v commite s cislom PR: `Stav: v review (PR #N)` a
# `Dalsi krok: review PR #N, merge robi orchestrator` (s diakritikou - znaky z kodov, subor je ASCII).
# Menia sa LEN karty, ktore vetva pridala alebo zmenila voci $BaseRef; vracia pole ciest zmenenych (alebo by sa zmenili pri -DryRun) kariet.
$NxCardSpecs = @(':(glob)SYSTEM/zdroje/bloky/*/priebeh/*.md', ':(glob)SYSTEM/zdroje/opravy/priebeh/*.md')

function Update-NxCardState([string]$Repo, [string]$BaseRef, [string]$Number, [switch]$DryRun) {
  $labelNext = ([string][char]0x010E) + 'al' + ([string][char]0x0161) + ([string][char]0x00ED) + ' krok'
  $valueNext = 'review PR #' + $Number + ', merge rob' + ([string][char]0x00ED) + ' orchestr' + ([string][char]0x00E1) + 'tor'
  $valueState = 'v review (PR #' + $Number + ')'
  $r = Invoke-NxNative 'git' (@('-C', $Repo, 'diff', '--name-only', '--no-renames', '--diff-filter=AM', "$BaseRef...HEAD", '--') + $NxCardSpecs)
  if ($r.code -ne 0) { throw "git diff zlyhal pre karty priebehu (exit $($r.code))" }
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  $done = @()
  foreach ($l in $r.out) {
    $rel = ([string]$l).Trim()
    if (-not $rel) { continue }
    $path = Join-Path $Repo $rel
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $text = [System.IO.File]::ReadAllText($path, $utf8)
    $new = ([regex]'(?m)^(Stav[ \t]*:)[^\r\n]*').Replace($text, ('${1} ' + $valueState), 1)
    $new = ([regex]('(?m)^(' + [regex]::Escape($labelNext) + '[ \t]*:)[^\r\n]*')).Replace($new, ('${1} ' + $valueNext), 1)
    if ($new -ne $text) {
      if (-not $DryRun) { [System.IO.File]::WriteAllText($path, $new, $utf8) }
      $done += $rel
    }
  }
  return $done
}
