# Noxun Engine — lokalne spustenie headless testov.
# Vyzaduje standalone Ruby 3.2 (rovnaka verzia ako SketchUp 2026 embedded).
$ErrorActionPreference = 'Stop'

$ruby = Get-Command ruby -ErrorAction SilentlyContinue
if (-not $ruby) {
  Write-Host 'Ruby nie je nainstalovane.' -ForegroundColor Yellow
  Write-Host 'Instalacia:  winget install RubyInstallerTeam.Ruby.3.2'
  Write-Host 'Alternativa: sadu spusti GitHub Actions pri kazdom pushi,'
  Write-Host 'alebo v SketchUp test okne:  load "C:/APP DEV/RUBY/ENGINE/tests/run_all.rb"'
  exit 1
}

& ruby (Join-Path $PSScriptRoot '..\tests\run_all.rb')
exit $LASTEXITCODE
