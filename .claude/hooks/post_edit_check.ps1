# Claude Code PostToolUse hook (Edit|Write) - Noxun Engine.
# Kontroluje IBA prave editovany subor:
#   (1) ruby -c syntax pre .rb,
#   (2) kontrola kodovania pre .rb/.js/.html/.css/.md/.ps1 cez scripts/encoding_guard.rb
#       (BOM, validne UTF-8, mojibake signatury, C1/C0/NUL, cyrilicke homoglyfy, charset
#       v .html) - TU ISTU implementaciu vola CI test tests/pure/test_encoding_guard.rb
#       nad celym repozitarom, takze hook a test nemozu hovorit nieco ine. Do 27.9.2026
#       mal hook vlastnu kopiu signatur v PowerShelli a test nevidel docs/architecture/:
#       hook tam hlasil falosny poplach na spravnom slove PAMAT (velke A s dvoma bodkami
#       + velke T s makcenom), ktory CI nikdy nevidelo. Pravidla sa menia VYHRADNE
#       v scripts/encoding_guard.rb, nie tu.
# POZOR (vedomy kontrakt): PostToolUse subor NEVRACIA - edit uz je zapisany.
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
if ($ext -notin @('.rb', '.js', '.html', '.css', '.md', '.ps1')) { exit 0 }

$ruby = 'C:\Ruby32-x64\bin\ruby.exe'
if (-not (Test-Path $ruby)) {
  $cmd = Get-Command ruby -ErrorAction SilentlyContinue
  $ruby = if ($cmd) { $cmd.Source } else { $null }
}
if (-not $ruby) { exit 0 }

# Spusti ruby, vrati exit kod a riadky vystupu. PS 5.1 pasca: 2>&1 na native exe
# + ErrorActionPreference Stop = pad skriptu, preto docasne Continue. Prazdny riadok
# na stderr prichadza ako text 'System.Management.Automation.RemoteException' - sum.
function Invoke-Ruby([string[]]$RubyArgs) {
  $ea = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
  $out = @(& $ruby @RubyArgs 2>&1 | ForEach-Object { $_.ToString() } |
    Where-Object { $_ -ne 'System.Management.Automation.RemoteException' })
  $code = $LASTEXITCODE
  $ErrorActionPreference = $ea
  return @{ Code = $code; Out = $out }
}

$problems = @()

# --- 1) ruby -c pre .rb --------------------------------------------------
if ($ext -eq '.rb') {
  $r = Invoke-Ruby @('-c', $file)
  if ($r.Code -ne 0) { $problems += "ruby -c syntax chyba: $($r.Out -join ' | ')" }
}

# --- 2) kontrola kodovania: spolocna implementacia s CI testom ------------
# CLI kontrakt (scripts/encoding_guard.rb): exit 0 = cisto, 3 = nalezy ako riadky
# "subor: problem"; iny kod (1 = pad Ruby ci syntax chyba guardu) = guard sa
# nepodarilo spustit - povie sa to, nezamlci ani nevyda za nalez v subore.
$guard = Join-Path $PSScriptRoot '../../scripts/encoding_guard.rb'
if (Test-Path -LiteralPath $guard) {
  $r = Invoke-Ruby @($guard, $file)
  if ($r.Code -eq 3) {
    $prefix = "${file}: "
    foreach ($line in $r.Out) {
      if ($line.StartsWith($prefix)) { $line = $line.Substring($prefix.Length) }
      $problems += $line
    }
  } elseif ($r.Code -ne 0) {
    $problems += "kontrolu kodovania sa nepodarilo spustit (exit $($r.Code)): $($r.Out -join ' | ')"
  }
}

if ($problems.Count -gt 0) {
  [Console]::Error.WriteLine("post_edit_check [$file]:")
  $problems | ForEach-Object { [Console]::Error.WriteLine("  - $_") }
  exit 2
}
exit 0
