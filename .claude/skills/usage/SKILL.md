---
name: usage
description: Aktuálny stav kvót Claude (session 5 h, weekly, Fable-only) a Codex (weekly) v 2 riadkoch cez CodexBar CLI — pre plánovanie orchestrácie (kedy sa resetuje, koľko ostáva, brána pred Codex auditom / GH kolom) a voliteľný lokálny log spotreby behov. Volať na začiatku okna a pred každým drahým krokom.
---

# Kvóty — stav pre orchestrátora (od 13.9.2026)

**Prečo:** orchestrátor má plánovať bloky podľa okien resetu (Claude session 5 h · Claude weekly · Codex weekly) a nespúšťať Codex kolá naslepo, keď je týždenná kvóta na dne. Zdroj dát je **CodexBar** (Michalova appka v tray; má aj CLI `codexbar-cli.exe`). Výstup je zámerne **2 riadky** — nikdy celá história; JSON len na debug.

## Volanie

PowerShell tool (skript je PS 5.1 kompatibilný, cesta relatívne k rootu repa):

```
& ".claude\skills\usage\usage.ps1"                                   # len stav
& ".claude\skills\usage\usage.ps1" -Label "<beh>" -Phase before      # stav + riadok do logu
& ".claude\skills\usage\usage.ps1" -Label "<beh>" -Phase after       # stav + delta oproti `before` s tým istým Label
& ".claude\skills\usage\usage.ps1" -Gate codex -MinRemaining 10      # brána: exit 3 = nespúšťaj
```

Výstup (príklad):

```
Claude  Claude Max 5x | session 15 % (reset 13.9. 13:50 o 3h 14m) | weekly 5 % (reset 19.9. 21:00 o 6d 10h) | Fable-only 7 % | tempo: farbehind
Codex   Pro Lite | session: No active 5h session | weekly 97 % (reset 19.9. 10:25 o 5d 23h) | tempo: farahead, NEVYDRZI do resetu
```

Percentá sú **použité** (used), nie zostatok. Časy resetu sú lokálne.

## Kedy volať (povinné)

1. **Na začiatku okna** (spolu s STAV/PLAN) — do prvej správy Michalovi jednou vetou, ak niečo obmedzuje plán (napr. Codex weekly > 85 %).
2. **Pred Codex auditom** (`codex-audit` krok 3): `-Label "audit <dávka>" -Phase before -Gate codex`. Exit 3 = **neposielaj**; ohlás a pokračuj s prísnejšou vlastnou kontrolou / odlož audit po resete. Po výsledku `-Phase after`.
3. **Pred vyžiadaním GH kola** (`codex-po-pr`, `@codex review`) a pred `gh pr ready`: `-Gate codex`. Exit 3 = GH kolo sa nevyžiada, platí **náhradná brána** (slepý Opus reviewer s reprodukciami + interná delta-verifikácia; vzor 31.8. a 9.9.2026) a do PR sa zapíše, prečo.
4. **Pred spustením implementačného subagenta** (drahé Claude okno): pozri Claude session/weekly a Fable-only — ak session > 80 % a reset je ďaleko, povedz to Michalovi pred štartom.

## Ako čítať

- **Codex „session: No active 5h session" / „Authentication required" / stav nedostupný** = dočasný výpadok prihlásenia CodexBaru (Michal 13.9.: bežné, v appke je všetko aktuálne). Neblokuje; rozhoduj podľa weekly, alebo skús o chvíľu znova.
- **Codex weekly resety chodia aj náhodne** (Michal 13.9.) — delta v logu môže byť záporná; skript to prizná („zaporne = medzitym reset").
- `tempo` = odhad CodexBaru (farbehind / slightlybehind / farahead …) a či kvóta vydrží do resetu.
- Brána `-Gate` pracuje s **weekly** oknom; prah `-MinRemaining` predvolene 10 %.

## Log behov (voliteľný, lokálny, mimo repa)

`%APPDATA%\NOXUN\Agent\usage_log.jsonl` — jeden riadok na volanie s `-Label` (ts, label, phase, percentá a resety oboch providerov; pri `after` aj `delta`). Účel: po pár týždňoch vedieť, koľko weekly percent stojí Astra audit, GH kolo alebo implementačná dávka → lepší odhad pri plánovaní. Nič viac sa z toho nerobí, kým Michal nepovie, že to má hodnotu (zhodnotenie po ~2 týždňoch; ak nič nepovie, log zostáva len ako dáta).

## Pasce

- **Claude OAuth usage endpoint je rate-limitovaný** (zistené 13.9.: po ~6 volaniach za pár minút vráti CodexBar `error: … rate limited`, skript to prizná ako „docasne nedostupne"). Volaj skill **najviac raz za niekoľko minút** — nie v slučke, nie pri každom kroku; appka CodexBar si stav sama obnovuje.
- CodexBar CLI píše WARN o cookies do stderr — skript ho odfiltruje cez `cmd /c … 2>nul` (PS 5.1 by ho zabalil do NativeCommandError). Nevolaj `codexbar-cli.exe` priamo s `2>&1`.
- `usage -p all` vypíše ~80 providerov s chybami — vždy len `claude` / `codex` (skript to robí).
- Cesta CLI: `%LOCALAPPDATA%\Programs\CodexBar\codexbar-cli.exe`; chýba = exit 2 (skript to povie).
