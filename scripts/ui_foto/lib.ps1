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
