# Lokálne hooky (Claude Code)

> Popis hookov repa pre ľudí a agentov. Konfigurácia je v `.claude/settings.json`, skripty v `.claude/hooks/`.
> Pravidlo pre implementátora je jedno: hook po Edit/Write hlási syntax a encoding — pri hláške chybu hneď oprav; vynucuje CI.

## Po každom Edit/Write — `post_edit_check.ps1`

PostToolUse po každom Edit/Write spustí `.claude/hooks/post_edit_check.ps1` — kontrola editovaného súboru:

- `ruby -c` syntax (`.rb`),
- encoding guard (`.rb`, `.js`, `.html`, `.css`, `.md`, `.ps1`): BOM, UTF-8, mojibake, C0/C1/NUL, cyrilické homoglyfy, charset.

**Jediná implementácia encoding guardu je `scripts/encoding_guard.rb`**, ktorú volá aj CI test `tests/pure/test_encoding_guard.rb`
nad celým repom; pravidlá sa menia len tam. Ručne: `ruby scripts/encoding_guard.rb --repo`.

Hook je rýchla spätná väzba: edit už je zapísaný, takže pri hláške chybu hneď oprav. Vynucovanie ostáva na CI.

## Hooky hlavného okna (orchestrátor)

Pravidlá, ktoré z nich plynú, sú v [ORCHESTRATOR.md](../SYSTEM/pravidla/roly/ORCHESTRATOR.md); tu je len opis hookov.

### Pripomienka po mergi — `po_merge.js`

PostToolUse na Bash s filtrom `gh pr merge` (hook si príkaz filtruje sám; v settings je len matcher Bash, bez poľa `if`). Po `gh pr merge <N>`
vloží hlavnému agentovi vecné konštatovanie v dvoch riadkoch: „PR #N menil plugin: áno/nie" (z `gh pr view`) a „Nasadený je <vetva> <sha>
(<čas>) → inštalácia mainu je potrebná / nie je potrebná". Údaje berie zo značky nasadenia `%TEMP%\noxun_nasadene.txt` (vetva, SHA, či bol
strom čistý, čas; zapisuje ju `INSTALL_noxun_engine.ps1`) a z porovnania kódu pluginu s `origin/main`; chýbajúca značka alebo neznámy stav
= „potrebná". Sama nič nespúšťa, pri chybe mlčí a príkaz nikdy neblokuje. Živé spustenie z Claude Code sa overuje pri reálnom merge.
Testy: `tests/js/test_po_merge.js`.

### Ukazovateľ kontextu — `context_meter.js`

Hook vloží hlavnému agentovi riadok `Kontext orchestrátora: 612k z 1M (61 %).` pri každej správe Michala a po nástroji len pri prechode
do vyššieho pásma (50–95 %); subagentov nechá na pokoji. Čo robiť od 75 % a 90 %, určuje ORCHESTRATOR.md (Ukazovateľ kontextu).
Testy: `tests/js/test_context_meter.js`.
