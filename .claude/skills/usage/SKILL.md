---
name: usage
description: Aktuálny stav kvót Claude (session 5 h, weekly, Fable-only) a Codex (weekly) v jednom riadku na providera cez CodexBar CLI — pre plánovanie orchestrácie (kedy sa resetuje, koľko ostáva, brána pred Codex auditom / GH kolom) a voliteľný lokálny log spotreby behov. Volať na začiatku okna a pred drahými krokmi, nie v slučke.
---

# Kvóty — stav pre orchestrátora (od 13.9.2026)

**Prečo:** orchestrátor má plánovať bloky podľa okien resetu (Claude session 5 h · Claude weekly · Codex weekly) a nespúšťať Codex kolá naslepo, keď je týždenná kvóta na dne (13.9.2026 nameraných 97 % použitých, reset 19.9.). Zdroj dát je **CodexBar** (Michalova appka v tray; má aj CLI `codexbar-cli.exe`). Výstup je zámerne **jeden riadok na providera** (+ voliteľne riadok „Spotreba" a riadok „BRANA") — nikdy história; JSON len na debug.

## Volanie

PowerShell tool (skript je PS 5.1 kompatibilný, čisté ASCII bez BOM; cesta relatívne k rootu repa):

```
& ".claude\skills\usage\usage.ps1"                                   # stav oboch providerov
& ".claude\skills\usage\usage.ps1" -Provider codex                   # len jeden provider
& ".claude\skills\usage\usage.ps1" -Gate codex                       # brána (číta LEN Codex): exit 3 = nespúšťaj
& ".claude\skills\usage\usage.ps1" -Label "<beh>" -Phase before      # stav + riadok do logu
& ".claude\skills\usage\usage.ps1" -Label "<beh>" -Phase after       # stav + delta oproti `before` s tým istým Label
& ".claude\skills\usage\usage.ps1" -Json                             # surový JSON (plán, percentá, resety, tempo) — debug
```

Výstup (príklad):

```
Claude  Claude Max 5x | session 27 % (reset 13.9. 13:50 o 2h 38m) | weekly 6 % (reset 19.9. 21:00 o 6d 9h) | Fable-only 9 % | tempo: farbehind
Codex   Pro Lite | session: No active 5h session | weekly 97 % (reset 19.9. 10:25 o 5d 23h) | tempo: farahead, NEVYDRZI do resetu
BRANA codex (weekly): zostatok 3 % < 10 % -> NESPUSTAJ (nahradna brana), exit 3
```

Percentá sú **použité** (used), nie zostatok; brána počíta **zostatok = 100 − použité** zo surovej hodnoty (90,5 % použitých = zostatok 9,5 %). Časy resetu sú lokálne.

## Exit kódy (PowerShell tool orámuje každý nenulový kód ako `<error>` — rozhoduje ČÍSLO)

| exit | význam | čo urobíš |
|---|---|---|
| 0 | OK; brána prešla alebo sa nepýtala | pokračuj |
| 2 | CodexBar CLI chýba (iný PC, cloud sandbox) | **NEblokuje** — rozhodni ručne, ohlás v reporte |
| 3 | brána NEPREŠLA (zostatok weekly < prah, predvolene 10 %) | **jediný blokujúci kód** — kolo/audit nespúšťaj, náhradná brána |
| 4 | stav providera brány dočasne nedostupný | **NEblokuje** — skús neskôr alebo rozhodni ručne (pri Codexe podľa appky CodexBar) |

## Kedy volať

1. **Na začiatku okna** (spolu s STAV/PLAN): `usage.ps1` bez parametrov — do prvej správy Michalovi jednou vetou, ak niečo obmedzuje plán (napr. Codex weekly > 85 %).
2. **Pred Codex auditom** (`codex-audit`, krok 3): `-Label "audit <dávka>" -Phase before -Gate codex` (číta oboch providerov kvôli logu). Exit 3 = **neposielaj**; ohlás a pokračuj s prísnejšou vlastnou kontrolou / odlož po resete — výnimka: audit-povinná dávka alebo P0/P1 fix → **spýtaj sa Michala**, môže kolo povoliť. Po výsledku (krok 5) `-Label "audit <dávka>" -Phase after`.
3. **Pred vyžiadaním GH kola** (`codex-po-pr`: `gh pr create` / `gh pr ready` / `@codex review`): `-Gate codex` (číta len Codex — nezaťažuje Claude endpoint). Exit 3 = kolo sa nevyžiada, platí **náhradná brána** (slepý Opus reviewer s reprodukciami + interná delta-verifikácia; vzor 31.8. a 9.9.2026) a do PR sa zapíše, prečo; tá istá výnimka pre audit-povinné/P1 ako v bode 2.
4. **Pred spustením implementačného subagenta** (drahé Claude okno): `-Label "dávka <názov>" -Phase before` — ak Claude session > 80 % a reset je ďaleko, povedz to Michalovi pred štartom; po reporte subagenta `-Phase after` (spotreba dávky do logu).

**Frekvencia:** Claude usage endpoint je rate-limitovaný (13.9.: po ~6 volaniach za pár minút vracia chybu). Preto brána číta len Codex, log sa robí len na začiatku/konci behu a skill sa nevolá v slučke ani pri každom kroku — typický PR flow = 2–3 volania, nie 10. Prázdny/„docasne nedostupne" Claude riadok je **normálny stav**, nie porucha; skript nerobí retry.

## Ako čítať

- **Codex „session: No active 5h session" / „Authentication required" / nedostupný** = dočasný výpadok prihlásenia CodexBaru (Michal 13.9.: bežné, v appke je všetko aktuálne). Neblokuje (exit 4); rozhoduj podľa weekly, alebo skús o chvíľu.
- **Codex weekly resety chodia aj náhodne** (Michal 13.9.) — delta v logu môže byť záporná; skript to prizná („zaporne = medzitym reset").
- `tempo` = odhad CodexBaru (farbehind / slightlybehind / farahead …) a či kvóta vydrží do resetu.
- `-Gate claude` gatuje **weekly** okno Claude (session sa negatuje — mení sa každých 5 h; pri subagentovi sa číta z riadku, bod 4).

## Log behov (voliteľný, lokálny, mimo repa)

`%APPDATA%\NOXUN\Agent\usage_log.jsonl` (UTF-8 bez BOM, jeden JSON na riadok) — riadok na každé volanie s `-Label` (ts, label, phase, percentá a resety oboch providerov; pri `after` aj `delta` = Codex weekly, Claude session/weekly, Fable-only). Ukladajú sa **len percentá a časy** — žiadny plán, e-mail ani identifikátor účtu. Účel: po pár týždňoch vedieť, koľko weekly percent stojí Astra audit alebo implementačná dávka (GH kolo sa samostatne nemeria — bolo by to ďalšie volanie za nič) → lepší odhad pri plánovaní. Nič viac sa z toho nerobí, kým Michal nepovie, že to má hodnotu (zhodnotenie po ~2 týždňoch). Log nerotuje a pri paralelných zápisoch (dva subagenti naraz) môže riadok vypadnúť — je to orientačná evidencia, nie účtovníctvo.

## Pasce

- CodexBar CLI píše WARN o cookies do stderr — skript ho odfiltruje cez `cmd /c … 2>nul` (PS 5.1 by ho zabalil do NativeCommandError). Nevolaj `codexbar-cli.exe` priamo s `2>&1`.
- `usage -p all` vypíše ~80 providerov s chybami — vždy len `claude` / `codex` (skript to robí).
- Cesta CLI: `%LOCALAPPDATA%\Programs\CodexBar\codexbar-cli.exe`; chýba = exit 2 (skript to povie).
- Encoding guard CI (`tests/pure/test_encoding_guard.rb`) od PR #363 skenuje aj `.claude/**/*.{md,ps1}` — `usage.ps1` musí ostať ASCII bez BOM, `.md` UTF-8 bez BOM.
