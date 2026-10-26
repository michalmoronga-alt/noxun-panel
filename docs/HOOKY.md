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

## Hooky hlavného okna

Pripomienka po mergi a ukazovateľ kontextu patria hlavnému oknu (orchestrátor) a sú opísané v
[ORCHESTRATOR.md](../SYSTEM/pravidla/roly/ORCHESTRATOR.md).
