# Claude Code PostToolUse hook (Edit|Write) — Noxun Engine.
# Kontroluje IBA prave editovany subor: (1) ruby -c syntax pre .rb,
# (2) encoding guard pre .rb/.js/.html/.css/.md/.ps1 — rovnake kontroly ako
# tests/pure/test_encoding_guard.rb (valid UTF-8, mojibake signatury, C1 znaky)
# + BOM (konvencia repa: UTF-8 BEZ BOM).
# POZOR (vedomy kontrakt): PostToolUse subor NEVRACIA — edit uz je zapisany.
# Hook je RYCHLA SPATNA VAZBA pre agenta (exit 2 + stderr -> agent chybu hned
# opravi); vynucovanie ostava na CI (testy bezia na kazdy push/PR).
# Fail-open: bez ruby / bez file_path / necitatelny stdin -> exit 0
# (hook nikdy nesmie blokovat nesuvisiacu pracu).
$ErrorActionPreference = 'Stop'
try {
  $raw = [Console]::In.ReadToEnd()
  if (-not $raw) { exit 0 }
  $payload = $raw | ConvertFrom-Json
  $file = $payload.tool_input.file_path
  if (-not $file -or -not (Test-Path -LiteralPath $file)) { exit 0 }
} catch { exit 0 }

$ext = [System.IO.Path]::GetExtension($file).ToLowerInvariant()
$problems = @()

# --- 1) ruby -c pre .rb --------------------------------------------------
if ($ext -eq '.rb') {
  $ruby = 'C:\Ruby32-x64\bin\ruby.exe'
  if (-not (Test-Path $ruby)) {
    $cmd = Get-Command ruby -ErrorAction SilentlyContinue
    $ruby = if ($cmd) { $cmd.Source } else { $null }
  }
  if ($ruby) {
    # PS 5.1 pasca: 2>&1 na native exe + ErrorActionPreference Stop = pad skriptu.
    $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & $ruby -c $file 2>&1 | ForEach-Object { $_.ToString() }
    $ErrorActionPreference = $ea
    if ($LASTEXITCODE -ne 0) {
      $problems += "ruby -c syntax chyba: $($out -join ' | ')"
    }
  }
}

# --- 2) encoding guard (zhodna logika s tests/pure/test_encoding_guard.rb) ---
if ($ext -in @('.rb', '.js', '.html', '.css', '.md', '.ps1')) {
  $bytes = [System.IO.File]::ReadAllBytes($file)
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
    $problems += 'UTF-8 BOM na zaciatku suboru (konvencia repa: UTF-8 bez BOM - typicka pasca Out-File/Set-Content)'
  }
  $strict = New-Object System.Text.UTF8Encoding($false, $true)
  try { [void]$strict.GetString($bytes) } catch {
    $problems += 'subor nie je validne UTF-8'
  }
  # Byte-level kontrola cez latin1 projekciu (1 bajt = 1 znak). Vzory sa
  # skladaju z kodov, aby skript sam neobsahoval mojibake bajty.
  $latin1 = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
  function B { param([int[]]$c) (($c | ForEach-Object { [char]$_ }) -join '') }
  $sig = @(
    (B 0xC3,0xA2) + '[' + (B 0xC2) + (B 0xE2) + ']'
    (B 0xC4,0x82) + '[' + (B 0xCB) + (B 0xC2) + (B 0xC4) + (B 0xC5) + ']'
    (B 0xC4,0xB9) + '[' + (B 0xCB) + (B 0xC2) + (B 0xA0) + '-' + (B 0xBF) + ']'
    (B 0xC4,0x8C,0xCB,0x87)
    (B 0xC3,0x84) + '[' + (B 0xC2) + (B 0xC4) + (B 0xC5) + ']'
    (B 0xC3,0x85) + '[' + (B 0xC2) + (B 0xC4) + (B 0xC5) + ']'
    (B 0xC3,0x82,0xC2)
  ) -join '|'
  $c1 = (B 0xC2) + '[' + (B 0x80) + '-' + (B 0x9F) + ']'
  if ([regex]::IsMatch($latin1, $sig)) { $problems += 'mojibake signatura (double-encoding diakritiky)' }
  if ([regex]::IsMatch($latin1, $c1))  { $problems += 'C1 kontrolny znak U+0080..U+009F (zvysok zleho prekodovania)' }
}

if ($problems.Count -gt 0) {
  [Console]::Error.WriteLine("post_edit_check [$file]:")
  $problems | ForEach-Object { [Console]::Error.WriteLine("  - $_") }
  exit 2
}
exit 0
