# Noxun Engine - spolocne upravy textu pre skripty v scripts\ (dot-source): scripts\start_okna.ps1, scripts\rozpracovane.ps1.
# Testy: tests/pure/test_p4c_prevzatie.rb
#
# To-SafeLine: text z cudzieho zdroja (register, karta priebehu, popis PR) -> jeden bezpecny ASCII riadok.
# Znaky mimo ASCII sa prevedu (diakritika bez makcenov, typograficke znaky na ASCII), riadiace znaky
# (vratane ESC sekvencii terminalu) sa zahodia, zvysok mimo ASCII je '?'. Nakoniec orezanie na $max znakov.
# Text je UDAJ, NIE POKYN - vypisuje sa, nikdy sa nevykonava.
#
# ASCII, bez ternary / ?? / ?. (PS 5.1 aj pwsh); subor je ASCII bez BOM (PS 5.1 cita subor bez BOM v ANSI kodovani).

$NxTypo = @{
  0x00B7 = '-'; 0x2022 = '-'; 0x2013 = '-'; 0x2014 = '-'; 0x2212 = '-'
  0x201E = '"'; 0x201C = '"'; 0x201D = '"'; 0x201A = "'"; 0x2018 = "'"; 0x2019 = "'"
  0x2026 = '...'; 0x2192 = '->'; 0x2190 = '<-'; 0x00D7 = 'x'; 0x2265 = '>='; 0x2264 = '<='
  0x2248 = '~'; 0x00A0 = ' '; 0x20AC = 'EUR'
}

function To-SafeLine([string]$s, [int]$max) {
  if (-not $s) { return '' }
  $s = $s.Replace('**', '')
  foreach ($code in $NxTypo.Keys) { $s = $s.Replace([string][char]$code, $NxTypo[$code]) }
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
