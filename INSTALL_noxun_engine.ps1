# Noxun Engine installer — skopiruje plugin do SketchUp 2026 Plugins zlozky.
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
$suRoot = Join-Path $env:APPDATA 'SketchUp'
$dest   = Join-Path $suRoot 'SketchUp 2026\SketchUp\Plugins'

if (-not (Test-Path $dest)) {
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
Get-ChildItem $destPlug -Recurse -File | ForEach-Object {
  $rel = $_.FullName.Substring($destPlug.Length).TrimStart('\')
  if (-not $srcRel.ContainsKey($rel)) {
    Remove-Item $_.FullName -Force
    Write-Host ('  odstranene (uz nie je sucastou pluginu): ' + $rel) -ForegroundColor DarkYellow
  }
}

Write-Host 'HOTOVO. Plugin nainstalovany.' -ForegroundColor Green
Write-Host 'Restartuj SketchUp, alebo v Ruby konzole: load "noxun_engine.rb"'
Write-Host ''
