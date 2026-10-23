# Straz pre agy (PreToolUse): pusti len webove nastroje, ostatne zamietne (model pokracuje cez web).
# Kopiruje sa do <priecinok behu>/.agents/ spolu s hooks.json (skill antigravity-outside-in). Zamietnutia sa zapisuju do len_web.log.
$raw = [Console]::In.ReadToEnd()
try { $name = ($raw | ConvertFrom-Json).toolCall.name } catch { $name = '' }
Add-Content -Path "$PSScriptRoot\len_web.log" -Value ("{0} {1}" -f (Get-Date -Format s), $name)
if ($name -in @('search_web','read_url_content')) { '{"decision":"allow"}' }
else { '{"decision":"deny","reason":"Zablokovane: v tejto reserse je povoleny len web (search_web, read_url_content). Pokracuj bez tohto nastroja."}' }
