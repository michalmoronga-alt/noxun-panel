# Noxun Engine - ciste pomocne funkcie fotenia okien (dot-source zo scripts/ui_foto.ps1).
# Bez vedlajsich ucinkov okrem zapisu markera - testuje ich tests/pure/test_ui_foto.rb
# cez pwsh/powershell (CI ubuntu ma pwsh).

# Marker USPESNEJ nahravky: zapisuje ho ui_foto.ps1 -Record AZ po validacii (bez FAIL
# riadku, index.json existuje). Nahravka bez markera (FAIL pri stavbe kuchyne, timeout,
# zlyhany boot) sa NIKDY nevyberie ako predvolena pre -Shoot (Codex #434 P2) - explicitne
# -Rec <priecinok> ju stale prehra (napr. starsia nahravka prototypu).
$NxRecOkMarker = 'NAHRAVKA_OK.txt'

function Set-NxRecOk([string]$recDir, [string]$info) {
  $utf8 = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path $recDir $NxRecOkMarker), $info, $utf8)
}

# Najnovsia USPESNA nahravka v $root (rec_* s index.json AJ markerom). '' ked ziadna.
function Find-NxLatestRec([string]$root) {
  $d = Get-ChildItem $root -Directory -Filter 'rec_*' -ErrorAction SilentlyContinue |
    Where-Object { (Test-Path (Join-Path $_.FullName 'index.json')) -and (Test-Path (Join-Path $_.FullName $NxRecOkMarker)) } |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($d) { return $d.FullName }
  return ''
}

# -Only: ciarkou/medzerou oddelene id alebo vzory (studio_*). Prazdne = vsetko.
# Vzor, ktory nezodpoveda ziadnej fotke, je chyba (preklep nesmie ticho nafotit nic).
function Select-NxShots($shots, [string]$only) {
  $pats = @($only -split '[,;\s]+' | Where-Object { $_ })
  if ($pats.Count -eq 0) { return @($shots) }
  $sel = @($shots | Where-Object { $id = $_.id; @($pats | Where-Object { $id -like $_ }).Count -gt 0 })
  foreach ($p in $pats) {
    if (@($shots | Where-Object { $_.id -like $p }).Count -eq 0) {
      throw ("-Only: '" + $p + "' nezodpoveda ziadnej fotke. Platne id: " + (($shots | ForEach-Object { $_.id }) -join ', '))
    }
  }
  return $sel
}

# Verdikt jednej fotky pre harok: ok | err | none (bez reportu) + zoznam chyb.
# $rep = report prehravaca (nx_stub.js). Report sa posiela po prehrani (`replay`), po
# ustaleni (`settled`) a pri kazdej neskorej chybe (`late`); ked prisiel LEN `replay`,
# stranka pred fotkou nedobehla do ustalenia - obsah ani neskore chyby nie su overene
# (Codex #434 P2), takze karta je CHYBA, nie OK.
function Get-NxShotStatus([bool]$pngOk, $rep) {
  $errs = @()
  $status = 'ok'
  if (-not $pngOk) { $status = 'err'; $errs += 'Chrome nevytvoril fotku.' }
  if (-not $rep) {
    if ($status -eq 'ok') { $status = 'none' }
  } else {
    if (@($rep.errors).Count -gt 0) { $status = 'err'; $errs += @($rep.errors | ForEach-Object { [string]$_ }) }
    if (@('settled', 'late') -notcontains [string]$rep.stage) {
      $status = 'err'; $errs += ('prehravac nedobehol do ustalenia pred fotkou (stav: ' + [string]$rep.stage + ')')
    }
  }
  return @{ status = $status; errors = @($errs) }
}
