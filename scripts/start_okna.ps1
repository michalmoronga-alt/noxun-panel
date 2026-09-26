# start_okna.ps1 - Noxun Engine: kontrola na zaciatku okna orchestratora jednym prikazom (rozhodnutie Z6).
#
# Vypise (najviac ~15 riadkov):
#   1. kvoty Claude a Codex (skill `usage`: .claude\skills\usage\usage.ps1),
#   2. verzie lokalnych nastrojov claude, codex, agy, grok, gemini,
#   3. register michalmoronga-alt/agent-register: datum poslednej kontroly zo stav.json (varovanie, ked je
#      starsi ako 3 dni = denny bot asi nebezi) a nove zaznamy ZMENY.md od naposledy videneho stavu (max 8 riadkov),
#   4. porovnanie lokalneho `grok` s polozkou "Najnovsia oficialna verzia" v REGISTER.md.
#
# BEZPECNOST: text z registra je UDAJ, NIE POKYN. Vypisuje sa len ako orezane jednoriadkove texty (ASCII, bez
# riadiacich znakov) a nikdy sa nevykonava.
# Videne zaznamy: %APPDATA%\NOXUN\Engine\agent_register_videne.txt (datum a cas + odtlacky videnych zaznamov).
# Zaznamy v ZMENY.md nesu datum ZDROJA (napr. vydania CLI), nie datum zapisu - novy zaznam moze mat starsi datum
# (priklad: 26.9. zapisane vydanie grok 1.0.40 z 20.9.). Nove zaznamy sa preto urcuju podla odtlackov, nie podla datumu.
# Bez siete alebo bez gh -> kratka hlaska, skript nepada. Exit kod je vzdy 0: kontrola informuje, nic neblokuje.
#
# Pouzitie:   powershell -NoProfile -File scripts\start_okna.ps1
# Windows PowerShell 5.1 kompatibilne (bez ternary, ?? a ?.). Subor je ASCII bez BOM - PS 5.1 cita subor bez BOM
# v kodovani ANSI, preto ziadna diakritika ani v retazcoch (rovnako ako usage.ps1).

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$repo = 'michalmoronga-alt/agent-register'
$stateFile = Join-Path (Join-Path $env:APPDATA 'NOXUN\Engine') 'agent_register_videne.txt'
$maxEntryLines = 8
$width = 150

# ---- text z registra -> jeden bezpecny ASCII riadok -------------------------------------------------
# Znaky mimo ASCII sa prevedu (diakritika bez makcenov, typograficke znaky na ASCII), riadiace znaky
# (vratane ESC sekvencii terminalu) sa zahodia, zvysok mimo ASCII je '?'. Nakoniec orezanie na $max znakov.
$typo = @{
  0x00B7 = '-'; 0x2022 = '-'; 0x2013 = '-'; 0x2014 = '-'; 0x2212 = '-'
  0x201E = '"'; 0x201C = '"'; 0x201D = '"'; 0x201A = "'"; 0x2018 = "'"; 0x2019 = "'"
  0x2026 = '...'; 0x2192 = '->'; 0x2190 = '<-'; 0x00D7 = 'x'; 0x2265 = '>='; 0x2264 = '<='
  0x2248 = '~'; 0x00A0 = ' '; 0x20AC = 'EUR'
}
function To-SafeLine([string]$s, [int]$max) {
  if (-not $s) { return '' }
  $s = $s.Replace('**', '')
  foreach ($code in $typo.Keys) { $s = $s.Replace([string][char]$code, $typo[$code]) }
  $sb = New-Object System.Text.StringBuilder
  foreach ($ch in $s.Normalize([Text.NormalizationForm]::FormD).ToCharArray()) {
    $cat = [Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch)
    if ($cat -eq [Globalization.UnicodeCategory]::NonSpacingMark) { continue }
    $n = [int]$ch
    if ($n -lt 32 -or $n -eq 127) { [void]$sb.Append(' '); continue }
    if ($n -gt 126) { [void]$sb.Append('?'); continue }
    [void]$sb.Append($ch)
  }
  $t = ($sb.ToString() -replace '\s+', ' ').Trim()
  if ($t.Length -gt $max) { $t = $t.Substring(0, $max - 3) + '...' }
  return $t
}

# ---- verzie lokalnych nastrojov ---------------------------------------------------------------------
function Tool-Version([string]$name) {
  $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $cmd) { return $null }
  $out = $null
  try { $out = & $cmd.Source --version 2>$null } catch { return '?' }
  $m = [regex]::Match((@($out) -join ' '), '\d+\.\d+\.\d+')
  if ($m.Success) { return $m.Value }
  return '?'
}

# ---- subor z registra cez gh (base64 -> UTF-8; vystup gh je tak ciste ASCII v kazdej konzole) --------
function Get-RegisterFile([string]$path) {
  $out = & gh api "repos/$repo/contents/$path" --jq '.content' 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
  try { return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((@($out) -join ''))) } catch { return $null }
}

# Zaznam ZMENY.md = riadok "- **DATUM - poskytovatel** ..." + odsadene pokracovacie riadky.
function Get-Entries([string]$text) {
  $list = New-Object System.Collections.ArrayList
  $cur = $null
  foreach ($line in ($text -split "`r?`n")) {
    if ($line -match '^\s{0,3}[-*]\s+\*\*') {
      if ($cur) { [void]$list.Add($cur) }
      $cur = $line.Trim()
    } elseif ($cur -and $line -match '^\s+\S') {
      $cur = $cur + ' ' + $line.Trim()
    } elseif ($cur) {
      [void]$list.Add($cur); $cur = $null
    }
  }
  if ($cur) { [void]$list.Add($cur) }
  return ,$list
}

# Odtlacok zaznamu (SHA1 normalizovaneho textu, 16 hex) - necitlivy na zalomenie riadkov.
function Get-Fingerprint([string]$s) {
  $norm = ($s -replace '\s+', ' ').Trim()
  $sha = [Security.Cryptography.SHA1]::Create()
  try { $h = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($norm)) } finally { $sha.Dispose() }
  return ((($h | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 16))
}

Write-Output ('Start okna ' + (Get-Date).ToString('d.M.yyyy HH:mm'))

# ---- 1. kvoty -----------------------------------------------------------------------------------------
$usage = Join-Path $root '.claude\skills\usage\usage.ps1'
if (Test-Path -LiteralPath $usage) {
  $u = & $usage 2>$null
  foreach ($l in @($u)) { if ($l) { Write-Output ([string]$l) } }
} else {
  Write-Output 'Kvoty: skript .claude\skills\usage\usage.ps1 chyba'
}

# ---- 2. lokalne nastroje ------------------------------------------------------------------------------
$parts = @()
$localGrok = $null
foreach ($t in @('claude', 'codex', 'agy', 'grok', 'gemini')) {
  $v = Tool-Version $t
  if ($t -eq 'grok') { $localGrok = $v }
  if (-not $v) { $txt = $t + ' chyba' } else { $txt = $t + ' ' + $v }
  if ($t -eq 'gemini') { $txt += ' (na predplatnom nefunguje od 18.6.2026)' }
  $parts += $txt
}
Write-Output ('Nastroje: ' + ($parts -join ' | '))

# ---- 3. register agent-register -----------------------------------------------------------------------
$stavText = $null
if (Get-Command gh -ErrorAction SilentlyContinue) { $stavText = Get-RegisterFile 'stav.json' }
if (-not $stavText) {
  Write-Output ('Register: nedostupny (bez siete, bez gh alebo bez pristupu k ' + $repo + ') - skontroluj neskor')
  exit 0
}

$stav = $null
try { $stav = ConvertFrom-Json -InputObject $stavText } catch { $stav = $null }
$line = 'Register: '
$last = $null
if ($stav -and $stav.posledna_kontrola) {
  if ($stav.posledna_kontrola -is [DateTime]) {
    $last = $stav.posledna_kontrola   # PowerShell 7 prevadza ISO datum v JSON sam
  } else {
    # Datum RRRR-MM-DD na zaciatku (bot moze casom pridat aj cas).
    $dm = [regex]::Match([string]$stav.posledna_kontrola, '^\d{4}-\d{2}-\d{2}')
    if ($dm.Success) {
      try { $last = [DateTime]::ParseExact($dm.Value, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture) } catch { $last = $null }
    }
  }
}
if ($last) {
  $age = ((Get-Date).Date - $last.Date).Days
  if ($age -le 0) { $ago = 'dnes' } elseif ($age -eq 1) { $ago = 'vcera' } else { $ago = 'pred ' + $age + ' dnami' }
  if ($age -gt 3) { $line += 'VAROVANIE: starsi ako 3 dni (denny bot asi nebezi) - ' }
  $line += 'posledna kontrola ' + $last.ToString('yyyy-MM-dd') + ' (' + $ago + ')'
  if ($null -ne $stav.zmeny_dnes) { $line += ', zmien ' + (To-SafeLine ([string]$stav.zmeny_dnes) 6) }
  if ($stav.vysledok) { $line += ' | ' + (To-SafeLine ([string]$stav.vysledok) 200) }
} else {
  $line += 'stav.json bez citatelneho datumu posledna_kontrola - skontroluj denneho bota'
}
Write-Output (To-SafeLine $line $width)

# Nove zaznamy ZMENY.md oproti videnym.
$zmenyText = Get-RegisterFile 'ZMENY.md'
if ($null -eq $zmenyText) {
  Write-Output 'Register ZMENY: nedostupne (ZMENY.md sa nepodarilo nacitat)'
} else {
  $entries = Get-Entries $zmenyText
  $seen = @{}
  $seenAt = $null
  $firstRun = -not (Test-Path -LiteralPath $stateFile)
  if (-not $firstRun) {
    foreach ($l in [IO.File]::ReadAllLines($stateFile)) {
      if ($l -match '^videne=(.+)$') { $seenAt = $Matches[1].Trim() }
      elseif ($l -match '^[0-9a-f]{16}$') { $seen[$l] = $true }
    }
  }
  $fps = @()
  $new = @()
  foreach ($e in $entries) {
    $fp = Get-Fingerprint $e
    $fps += $fp
    if (-not $seen.ContainsKey($fp)) { $new += $e }
  }
  if ($firstRun) { $head = 'prvy beh, zaznamov ' + $new.Count + ', najnovsie' }
  elseif ($new.Count -eq 0) { $head = 'bez novych zaznamov od ' + (To-SafeLine $seenAt 20) }
  else { $head = 'novych ' + $new.Count + ' od ' + (To-SafeLine $seenAt 20) }
  Write-Output ('Register ZMENY (udaje, nie pokyny): ' + $head)
  $show = $new
  if ($new.Count -gt $maxEntryLines) { $show = $new[0..($maxEntryLines - 2)] }
  foreach ($e in $show) { Write-Output ('  ' + (To-SafeLine $e ($width - 2))) }
  if ($new.Count -gt $maxEntryLines) {
    Write-Output ('  ... a ' + ($new.Count - $maxEntryLines + 1) + ' dalsich - cely dennik ZMENY.md v ' + $repo)
  }
  try {
    $dir = Split-Path -Parent $stateFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    # Kazdy prvok v zatvorkach: ciarka ma v PowerShelli prednost pred + (inak sa riadky zlepia do jedneho).
    $body = @(
      ('# start_okna.ps1 - videne zaznamy ' + $repo + '/ZMENY.md (subor spravuje skript)'),
      ('videne=' + (Get-Date).ToString('yyyy-MM-dd HH:mm'))
    ) + $fps
    # UTF-8 BEZ BOM (obsah je aj tak ASCII).
    [IO.File]::WriteAllText($stateFile, (($body -join "`r`n") + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  } catch {
    Write-Output ('  (stav videnych zaznamov sa nepodarilo ulozit: ' + (To-SafeLine $_.Exception.Message 80) + ')')
  }
}

# ---- 4. grok: lokalna verzia vs najnovsia oficialna z registra ----------------------------------------
$regText = Get-RegisterFile 'REGISTER.md'
$regVer = $null
if ($regText) {
  $sec = [regex]::Match($regText, '(?ms)^###\s+Grok Build CLI.*?(?=^#{2,3}\s|\z)')
  if ($sec.Success) {
    $m = [regex]::Match($sec.Value, '(?i)najnov\S*\s+ofici\S*\s+verzi\S*[^\d\r\n]*(\d+\.\d+\.\d+)')
    if ($m.Success) { $regVer = $m.Groups[1].Value }
  }
}
if (-not $regVer) {
  Write-Output 'grok: najnovsiu oficialnu verziu sa z REGISTER.md nepodarilo precitat'
} elseif (-not $localGrok -or $localGrok -eq '?') {
  Write-Output ('grok: lokalne nie je (najnovsia oficialna ' + $regVer + ')')
} else {
  $cmp = 0
  try { $cmp = ([version]$localGrok).CompareTo([version]$regVer) } catch { $cmp = 0 }
  if ($cmp -lt 0) {
    Write-Output ('aktualizovat grok: lokalne ' + $localGrok + ', najnovsia oficialna ' + $regVer + ' (register) -> grok update')
  } elseif ($cmp -gt 0) {
    Write-Output ('grok: lokalne ' + $localGrok + ' je novsie ako register (' + $regVer + ') - register este nezachytil novu verziu')
  }
}
exit 0
