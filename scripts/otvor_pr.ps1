# Noxun Engine - OTVORENIE PR jednym prikazom (P4a, blok PRAVIDLA; ROLY.md 8, otazka 1).
#
#   powershell -NoProfile -File scripts\otvor_pr.ps1 -Title "<nazov>" -BodyFile <popis.md> `
#       -CoAuthor "Claude <model> <noreply@anthropic.com>" [-Base main] [-Draft] [-WhatIf]
#
# Co spravi (v tomto poradi):
#   1. kontrola: vetva nie je main/master, strom bez necommitnutych zmien v sledovanych suboroch,
#      neexistuje OTVORENY PR pre vetvu (zatvoreny/zmergovany nevadi), popis existuje;
#   2. kvotova brana `.claude\skills\usage\usage.ps1 -Gate codex` - exit 3 = PR sa otvori ako
#      DRAFT (Codex draft nerecenzuje; dalej podla triedy davky: skill `usage`, sekcia
#      "Prahy a reakcie"); exit 2/4 (stav kvoty nedostupny) = tiez DRAFT s vypisom preco (draft sa
#      da neskor prepnut gh pr ready, bezici review kolo sa zastavit neda);
#      -NoDraftOnUnknownQuota to pri neznamom stave vypne;
#   3. `git push origin HEAD` (vetva musi byt na GitHube);
#   4. `gh pr create` (--base, --title, --body-file, pri brane alebo -Draft aj --draft);
#   5. v suboroch zmenenych vetvou voci base nahradi `PR #?` cislom PR - len v SYSTEM/PLAN.md,
#      SYSTEM/STAV.md, SYSTEM/archiv/KRONIKA.md, SYSTEM/archiv/DOGFOODING_vyriesene.md,
#      SYSTEM/zdroje/bloky/*/kronika/*.md (zaznam davky bloku) a len
#      na riadkoch, ktore vetva pridala (inde je `PR #?` text pravidla), samostatny commit
#      `docs: doplnit cislo PR #N` s trailerom Co-Authored-By: <CoAuthor>, push;
#   6. vypise URL, cislo PR, ci je draft, SHA commitu s cislom.
#
# -CoAuthor je POVINNY: skript nevie, aky model session beha (trailer ma niest skutocny model).
# Popis PR (-BodyFile) pise volajuci po slovensky; skript ho nemeni.
# -WhatIf: nic nezapise, nepushne ani nevytvori - vypise plan (aj kolko `PR #?` by sa nahradilo).
# Skusi len lokalne informacie (bez fetch, bez gh, bez zapisu usage logu).
#
# Skryte parametre pre testy: -RepoRoot (iny repozitar), -Gh (cesta/prikaz namiesto gh),
# -UsageScript (iny skript brany).
# Exit: 0 = hotovo (alebo -WhatIf), 1 = chyba (vypis hovori v akom stave ostal PR/vetva).
# Rucny postup ostava ako zaloha: najprv usage.ps1 -Gate codex (exit 3, 2 alebo 4 = gh pr create --draft),
# potom gh pr create a `PR #?` -> cislo samostatnym commitom.
# ASCII, bez ternary / ?? / ?. (PS 5.1 aj pwsh).
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [Parameter(Mandatory = $true)][string]$Title,
  [Parameter(Mandatory = $true)][string]$BodyFile,
  [Parameter(Mandatory = $true)][string]$CoAuthor,
  [string]$Base = 'main',
  [switch]$Draft,
  [switch]$NoDraftOnUnknownQuota,
  [string]$RepoRoot = '',
  [string]$Gh = 'gh',
  [string]$UsageScript = ''
)
$ErrorActionPreference = 'Stop'
$repo = $RepoRoot
if (-not $repo) { $repo = Split-Path $PSScriptRoot -Parent }
. (Join-Path (Join-Path $PSScriptRoot 'lib') 'nx_pr.ps1')
if (-not $UsageScript) { $UsageScript = Join-Path (Join-Path (Join-Path (Join-Path $repo '.claude') 'skills') 'usage') 'usage.ps1' }

function Stop-Nx([string]$msg) { Write-Host ('CHYBA: ' + $msg); exit 1 }
function Git-Nx([string[]]$ArgList, [switch]$Quiet) {
  return (Invoke-NxNative 'git' (@('-C', $repo) + $ArgList) -Quiet:$Quiet)
}

# --- 1. kontrola vstupov ----------------------------------------------------
if (-not (Test-Path -LiteralPath $BodyFile)) { Stop-Nx "popis PR neexistuje: $BodyFile" }
$BodyFile = (Resolve-Path -LiteralPath $BodyFile).Path
if ($CoAuthor -notmatch '^\S.* <[^<>\s]+@[^<>\s]+>$') {
  Stop-Nx "-CoAuthor ma mat tvar 'Claude <model> <noreply@anthropic.com>' (dostal som: '$CoAuthor')"
}
$r = Git-Nx @('rev-parse', '--abbrev-ref', 'HEAD') -Quiet
if ($r.code -ne 0) { Stop-Nx "nepodarilo sa zistit vetvu (git rev-parse): $repo" }
$branch = ([string]($r.out | Select-Object -First 1)).Trim()
if (-not $branch -or $branch -eq 'HEAD') { Stop-Nx 'hlava je odpojena (detached HEAD) - prepni sa na vetvu davky.' }
if ($branch -eq 'main' -or $branch -eq 'master' -or $branch -eq $Base) { Stop-Nx "vetva '$branch' nie je vetva davky - PR sa z nej neotvara." }
$r = Git-Nx @('status', '--porcelain', '--untracked-files=no')
if ($r.code -ne 0) { Stop-Nx 'git status zlyhal.' }
if (@($r.out | Where-Object { $_ }).Count -gt 0) { Stop-Nx 'su necommitnute zmeny v sledovanych suboroch - najprv commit (a push), potom otvor PR.' }

# Referencia base (lokalna; pri ostrom behu sa najprv fetchne).
if (-not $WhatIfPreference) {
  $r = Git-Nx @('fetch', 'origin', $Base, '--quiet') -Quiet
  if ($r.code -ne 0) { Write-Host "POZOR: git fetch origin $Base zlyhal - pouzije sa lokalna referencia origin/$Base." }
}
$baseRef = "origin/$Base"
$r = Git-Nx @('rev-parse', '--verify', '--quiet', "$baseRef^{commit}") -Quiet
if ($r.code -ne 0) {
  $baseRef = $Base
  $r = Git-Nx @('rev-parse', '--verify', '--quiet', "$baseRef^{commit}") -Quiet
  if ($r.code -ne 0) { Stop-Nx "base '$Base' (ani origin/$Base) sa neda rozlisit na commit." }
}

# --- 3. kvotova brana (pred vytvorenim PR) ----------------------------------
$isDraft = [bool]$Draft
$gateText = 'brana nebezala'
if (Test-Path -LiteralPath $UsageScript) {
  $global:LASTEXITCODE = 0
  if ($WhatIfPreference) { $gateOut = @(& $UsageScript -Gate codex) }
  else { $gateOut = @(& $UsageScript -Label ("otvor_pr " + $branch) -Phase before -Gate codex) }
  $gateExit = [int]$global:LASTEXITCODE
  foreach ($l in $gateOut) { Write-Host ('  usage: ' + $l) }
  if ($gateExit -eq 3) {
    $isDraft = $true
    $gateText = 'exit 3 - Codex weekly zostatok pod prahom: PR sa otvori ako DRAFT (Codex ho nerecenzuje); dalej podla triedy davky - skill usage, sekcia Prahy a reakcie'
  } elseif ($gateExit -eq 0) {
    $gateText = 'exit 0 - brana presla'
  } else {
    if ($NoDraftOnUnknownQuota) {
      $gateText = "exit $gateExit - stav kvoty nedostupny; -NoDraftOnUnknownQuota: PR sa otvori normalne"
    } else {
      $isDraft = $true
      $gateText = "exit $gateExit - stav kvoty nedostupny: PR sa otvori ako DRAFT (kolo Codexu, ktore bezi samo po otvoreni, sa zastavit neda; po overeni kvoty prepni gh pr ready, alebo spusti s -NoDraftOnUnknownQuota); skill usage, sekcia Prahy a reakcie"
    }
  }
} else {
  if ($NoDraftOnUnknownQuota) {
    $gateText = "skript brany nenajdeny ($UsageScript); -NoDraftOnUnknownQuota: PR sa otvori normalne"
  } else {
    $isDraft = $true
    $gateText = "skript brany nenajdeny ($UsageScript) - stav kvoty neznamy: PR sa otvori ako DRAFT (po overeni kvoty gh pr ready, alebo -NoDraftOnUnknownQuota)"
  }
}
Write-Host ('KVOTA: ' + $gateText)
if ($Draft) { Write-Host 'DRAFT: vyziadany parametrom -Draft' }

# --- WhatIf: plan a koniec --------------------------------------------------
if ($WhatIfPreference) {
  $changed = @(Update-NxPrNumber $repo $baseRef 'N' -DryRun)
  Write-Host "WHATIF: vetva '$branch' proti $baseRef"
  Write-Host ("WHATIF: git push origin HEAD; gh pr create --base $Base --head $branch --title `"$Title`" --body-file $BodyFile" + $(if ($isDraft) { ' --draft' } else { '' }))
  if ($changed.Count -eq 0) { Write-Host 'WHATIF: v zmenenych suboroch nie je PR #? - commit s cislom by sa nerobil' }
  foreach ($c in $changed) { Write-Host ("WHATIF: nahradil by sa 'PR #?' v {0} ({1}x)" -f $c.file, $c.replaced) }
  if ($changed.Count -gt 0) { Write-Host "WHATIF: commit 'docs: doplnit cislo PR #N' (Co-Authored-By: $CoAuthor) + git push origin HEAD" }
  Write-Host ('WHATIF: PR by bol ' + $(if ($isDraft) { 'DRAFT' } else { 'bezny (nie draft)' }))
  exit 0
}

# --- 1b. PR pre vetvu uz nesmie existovat -----------------------------------
Push-Location $repo
try {
  $r = Invoke-NxNative $Gh @('pr', 'view', $branch, '--json', 'number,state', '--jq', '.number,.state') -Quiet
} finally { Pop-Location }
# gh pr view vypise dva riadky (cislo, stav). Odmietne sa LEN otvoreny PR - zatvoreny alebo
# zmergovany PR pre rovnaku vetvu (napr. znovuotvorenie po zavreti) novemu PR nebrani.
$existing = @($r.out | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ })
if ($r.code -eq 0 -and $existing.Count -ge 2 -and $existing[0] -match '^\d+$' -and $existing[1] -eq 'OPEN') {
  Stop-Nx ("PR pre vetvu '$branch' uz existuje (otvoreny): #" + $existing[0] + ' - doplnenie cisla PR urob rucne.')
}

# --- 2. push vetvy ----------------------------------------------------------
$r = Git-Nx @('push', 'origin', 'HEAD')
if ($r.code -ne 0) { Stop-Nx 'git push vetvy zlyhal - PR sa nevytvoril.' }

# --- 4. gh pr create --------------------------------------------------------
$createArgs = @('pr', 'create', '--base', $Base, '--head', $branch, '--title', $Title, '--body-file', $BodyFile)
if ($isDraft) { $createArgs += '--draft' }
Push-Location $repo
try {
  $r = Invoke-NxNative $Gh $createArgs
} finally { Pop-Location }
$url = ''
foreach ($l in $r.out) { if (([string]$l) -match 'https?://\S+/pull/\d+') { $url = $Matches[0] } }
if ($r.code -ne 0 -and -not $url) { Stop-Nx 'gh pr create zlyhal - PR sa nevytvoril (vetva je pushnuta).' }
if (-not $url) { Stop-Nx ('gh pr create nevypisal URL PR (vystup: ' + (($r.out | ForEach-Object { [string]$_ }) -join ' | ') + ') - skontroluj PR rucne a cislo doplni rucne.') }
$number = ([regex]::Match($url, '/pull/(\d+)')).Groups[1].Value

# --- 5. cislo PR do suborov + samostatny commit -----------------------------
$commitSha = ''
try {
  $changed = @(Update-NxPrNumber $repo $baseRef $number)
  if ($changed.Count -gt 0) {
    $files = @($changed | ForEach-Object { $_.file })
    $r = Git-Nx (@('add', '--') + $files)
    if ($r.code -ne 0) { throw 'git add zlyhal' }
    $msgFile = [System.IO.Path]::GetTempFileName()
    try {
      $utf8 = New-Object System.Text.UTF8Encoding($false)
      [System.IO.File]::WriteAllText($msgFile, ("docs: doplnit cislo PR #$number`n`nCo-Authored-By: $CoAuthor`n"), $utf8)
      $r = Git-Nx @('commit', '-F', $msgFile)
      if ($r.code -ne 0) { throw 'git commit zlyhal' }
    } finally { Remove-Item -LiteralPath $msgFile -Force -ErrorAction SilentlyContinue }
    $r = Git-Nx @('rev-parse', 'HEAD') -Quiet
    $commitSha = ([string]($r.out | Select-Object -First 1)).Trim()
    $r = Git-Nx @('push', 'origin', 'HEAD')
    if ($r.code -ne 0) { throw "git push commitu s cislom zlyhal (commit $commitSha je lokalne)" }
  }
} catch {
  Write-Host ('CHYBA pri doplneni cisla PR: ' + $_.Exception.Message)
  Write-Host "PR #$number JE VYTVORENY ($url) - cislo PR dopln rucne (PR #? -> $number samostatnym commitom) a pushni."
  exit 1
}

# --- 6. vysledok ------------------------------------------------------------
Write-Host ''
Write-Host "PR: #$number  $url"
Write-Host ('DRAFT: ' + $(if ($isDraft) { 'ano' } else { 'nie' }))
if ($commitSha) { Write-Host "COMMIT s cislom: $commitSha" } else { Write-Host 'COMMIT s cislom: ziadny (v zmenenych suboroch nebolo PR #? na doplnenie)' }
exit 0
