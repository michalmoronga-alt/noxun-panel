# Noxun Engine - spolocne hladanie ciest pre skripty v scripts\ (dot-source).
# Testy: tests/pure/test_p4a_skripty.rb
#
# Problem (4 retro zaznamy): _dev\ je gitignorovany, takze v GIT WORKTREE (kde agenti
# pracuju) nie je ani testovaci model, ani zakazka na export test. Hlavny checkout ho
# ma. Resolve-NxDevFile skusi najprv _dev v aktualnom checkoute, potom v hlavnom
# checkoute (rodic spolocneho .git adresara); vrati cestu alebo ''.
#
# Skript je ASCII (Windows PowerShell 5.1 cita .ps1 bez BOM v systemovej kodovej
# stranke) a bez ternary / ?? / ?. (kompatibilny s PS 5.1 aj pwsh).

# Dve skusane cesty (aktualny checkout, hlavny checkout) pre $Segments pod _dev.
# Hlavny checkout = rodic `git rev-parse --git-common-dir`; ked sa nezisti, druha je ''.
# $Segments su casti cesty ako pole (@('_dev','ENGINEtests.skp')) - nezavisle od separatora.
function Get-NxDevCandidates([string]$Repo, [string[]]$Segments) {
  $first = $Repo
  foreach ($s in $Segments) { $first = Join-Path $first $s }
  $second = ''
  try {
    $common = (& git -C $Repo rev-parse --path-format=absolute --git-common-dir 2>$null)
    if ($common) {
      $main = Split-Path ([string]$common).Trim() -Parent
      $second = $main
      foreach ($s in $Segments) { $second = Join-Path $second $s }
    }
  } catch {}
  return @($first, $second)
}

# Prva existujuca cesta z kandidatov; '' ked ziadna neexistuje.
function Resolve-NxDevFile([string]$Repo, [string[]]$Segments) {
  foreach ($c in (Get-NxDevCandidates $Repo $Segments)) {
    if ($c -and (Test-Path -LiteralPath $c)) { return $c }
  }
  return ''
}

# Testovaci model in-SU testov a fotenia okien: _dev\ENGINEtests.skp.
function Resolve-NxTestModel([string]$Repo) {
  return (Resolve-NxDevFile $Repo @('_dev', 'ENGINEtests.skp'))
}

# Hlaska pre chybajuci subor: menuje OBE skusane cesty.
function Get-NxMissingDevMessage([string]$What, [string]$Repo, [string[]]$Segments) {
  $c = Get-NxDevCandidates $Repo $Segments
  $same = $false
  if ($c[1]) {
    $cmp = [System.StringComparison]::Ordinal
    if ([System.IO.Path]::DirectorySeparatorChar -eq '\') { $cmp = [System.StringComparison]::OrdinalIgnoreCase }
    $same = [string]::Equals([System.IO.Path]::GetFullPath($c[0]), [System.IO.Path]::GetFullPath($c[1]), $cmp)
  }
  # V hlavnom checkoute su obe cesty rovnake - vypise sa len jedna.
  if ($same) { return "CHYBA: $What chyba. Skusena cesta (hlavny checkout):`n  $($c[0])" }
  $m = "CHYBA: $What chyba. Skusene cesty:`n  1. $($c[0])  (aktualny checkout)"
  if ($c[1]) { $m += "`n  2. $($c[1])  (hlavny checkout - vo worktree je _dev len tam)" }
  else { $m += "`n  2. (hlavny checkout sa nepodarilo zistit cez git)" }
  return $m
}
