# Noxun Engine installer — skopiruje plugin do SketchUp 2026 Plugins zlozky
# a odstrani stare samostatne instalacie Mower/Snaper (NASTROJE-1 T1b).
# Bezpecne pre opakovane spustenie: prepise len kodove subory pluginu.

$ErrorActionPreference = 'Stop'

$src     = $PSScriptRoot
$loader  = Join-Path $src 'noxun_engine.rb'
$plugdir = Join-Path $src 'noxun_engine'

if (-not (Test-Path $loader) -or -not (Test-Path $plugdir)) {
  Write-Host 'CHYBA: noxun_engine.rb alebo zlozka noxun_engine sa nenasla vedla skriptu.' -ForegroundColor Red
  exit 1
}

# Ciel: SketchUp 2026 Plugins (podla zadania). Ak chyba, skus najnovsiu verziu.
#
# NOXUN_INSTALL_DEST je VYHRADNE testovacia poistka (NASTROJE-1 T1b): dovoli
# spustit skript nad DOCASNOU kopiou Plugins stromu a overit upratanie legacy
# ciest bez toho, aby sa siahlo na zivu instalaciu. V beznom behu premenna
# nastavena NIE JE a ciel ostava realny Plugins priecinok.
$suRoot = Join-Path $env:APPDATA 'SketchUp'
$dest   = Join-Path $suRoot 'SketchUp 2026\SketchUp\Plugins'

if ($env:NOXUN_INSTALL_DEST) {
  $dest = $env:NOXUN_INSTALL_DEST
  if (-not (Test-Path -LiteralPath $dest)) {
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
  }
  Write-Host ('POZOR: ciel prepisany cez NOXUN_INSTALL_DEST (testovaci rezim): ' + $dest) -ForegroundColor Yellow
}
elseif (-not (Test-Path $dest)) {
  $fallback = @()
  if (Test-Path $suRoot) {
    $fallback = Get-ChildItem $suRoot -Directory |
      Where-Object { $_.Name -match '^SketchUp \d{4}$' } |
      Sort-Object Name -Descending |
      ForEach-Object { Join-Path $_.FullName 'SketchUp\Plugins' } |
      Where-Object { Test-Path $_ }
  }
  if ($fallback.Count -eq 0) {
    Write-Host 'CHYBA: Nenasla sa SketchUp Plugins zlozka v APPDATA.' -ForegroundColor Red
    exit 1
  }
  $dest = $fallback[0]
}

Write-Host ''
Write-Host 'Noxun Engine installer' -ForegroundColor Cyan
Write-Host ('  Zdroj : ' + $src)
Write-Host ('  Ciel  : ' + $dest)
Write-Host ''

Copy-Item $loader -Destination $dest -Force

$destPlug = Join-Path $dest 'noxun_engine'
if (-not (Test-Path $destPlug)) { New-Item -ItemType Directory -Path $destPlug | Out-Null }
Copy-Item (Join-Path $plugdir '*') -Destination $destPlug -Recurse -Force

# ZRKADLENIE (ŠT-2b): kopirovanie samo o sebe nikdy nic nezmazalo, takze subory
# zaniknutych casti pluginu (napr. `ui/production.html` po ŠT-1c alebo
# `ui/proj_materials.html` po ŠT-2b) v cieli ostavali navzdy — a pri hladani
# chyby vyzerali ako ziva sucast pluginu. Ciel je VYHRADNE zlozka pluginu,
# takze sa nemoze zmazat nic cudzie.
$srcRel = @{}
Get-ChildItem $plugdir -Recurse -File | ForEach-Object {
  $srcRel[$_.FullName.Substring($plugdir.Length).TrimStart('\')] = $true
}
# Review #3: mazanie NESMIE zhodit skript. Kopirovanie uz prebehlo, plugin je
# nainstalovany — zamknuty subor (otvoreny SketchUp, antivirus, indexer) je
# kozmeticky problem, nie dovod skoncit chybou pri `$ErrorActionPreference =
# 'Stop'`. Preto try/catch s konkretnou hlaskou.
Get-ChildItem $destPlug -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($destPlug.Length).TrimStart('\')
  if (-not $srcRel.ContainsKey($rel)) {
    try {
      Remove-Item $_.FullName -Force -ErrorAction Stop
      Write-Host ('  odstranene (uz nie je sucastou pluginu): ' + $rel) -ForegroundColor DarkYellow
    } catch {
      Write-Host ('  nepodarilo sa odstranit (subor je zamknuty): ' + $rel) -ForegroundColor Yellow
    }
  }
}
# Prazdny priecinok po zmazanom obsahu (napr. cely zaniknuty modul) by ostal
# visiet — od najhlbsieho po najplytkejsi, aby sa upratali aj vnorene.
Get-ChildItem $destPlug -Recurse -Directory |
  Sort-Object { $_.FullName.Length } -Descending |
  ForEach-Object {
    if (-not (Get-ChildItem $_.FullName -Force | Select-Object -First 1)) {
      try {
        Remove-Item $_.FullName -Force -ErrorAction Stop
        Write-Host ('  odstraneny prazdny priecinok: ' +
                    $_.FullName.Substring($destPlug.Length).TrimStart('\')) -ForegroundColor DarkYellow
      } catch {
        Write-Host ('  nepodarilo sa odstranit (priecinok je zamknuty): ' +
                    $_.FullName.Substring($destPlug.Length).TrimStart('\')) -ForegroundColor Yellow
      }
    }
  }

# UPRATANIE STARYCH INSTALACII (NASTROJE-1 T1b): Mower a Snaper su od tejto
# verzie sucastou balika enginu, takze ich samostatne instalacie musia z
# `Plugins` zmiznut — inak by SketchUp registroval dva toolbary navyse.
# Toto je DRUHY kanal upratania; prvy je boot migracia v samotnom plugine
# (`noxun_engine/tools/legacy_cleanup.rb`), ktora bezi pri kazdom starte.
#
# POSTKONTROLA JE POVINNA: `Remove-Item` v try/catch chybu prehltne, takze
# jediny dokaz o zmazani je opakovany `Test-Path`. Zamknuty subor (beziaci
# SketchUp) preto NIE JE „HOTOVO" — vypise sa varovanie s cestami.
$legacyTargets = @('noxun_mower_loader.rb', 'Noxun_Mower', 'snaper.rb', 'snaper')
$legacyFailed = @()
foreach ($name in $legacyTargets) {
  $legacyPath = Join-Path $dest $name
  if (-not (Test-Path -LiteralPath $legacyPath)) { continue }
  try {
    Remove-Item -LiteralPath $legacyPath -Recurse -Force -ErrorAction Stop
  } catch {
    # Chyba sa neriesi tu — rozhoduje az postkontrola nizsie.
  }
  if (Test-Path -LiteralPath $legacyPath) {
    $legacyFailed += $legacyPath
  } else {
    Write-Host ('  odstraneny stary plugin: ' + $name) -ForegroundColor DarkYellow
  }
}

Write-Host ''
if ($legacyFailed.Count -gt 0) {
  Write-Host 'POZOR: plugin je nainstalovany, ale STARE pluginy sa nepodarilo odstranit:' -ForegroundColor Yellow
  foreach ($legacyPath in $legacyFailed) { Write-Host ('  ' + $legacyPath) -ForegroundColor Yellow }
  Write-Host 'Zavri SketchUp a spusti skript znova, alebo cesty zmaz rucne.' -ForegroundColor Yellow
  Write-Host 'Noxun Engine sa o to pokusi aj sam pri dalsom starte SketchUpu.' -ForegroundColor Yellow
} else {
  Write-Host 'HOTOVO. Plugin nainstalovany.' -ForegroundColor Green
}
# Ziadny hint na zivy `load "noxun_engine.rb"` (audit 3 FIX 3): po uprataní by
# nacital loader do BEZIACEHO procesu, kde uz `@loaded`/`file_loaded?` drzia
# registraciu preskocenu — takze by nezaregistroval toolbar enginu a legacy
# toolbary by z pamate neodstranil. Jedina spravna odpoved je restart.
Write-Host 'Restartuj SketchUp.'
Write-Host ''
