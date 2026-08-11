---
name: codex-po-pr
description: Po odoslaní PR — budík ~10 min, kontrola Codex GH review (nálezy sú v review threadoch, nie komentoch), oprava nálezov, reply s commit hashom; po splnení brán (CI zelené + review vybavené) merge robí Claude a výsledok ide do denného reportu.
---

# Codex review po PR

GitHub Codex review beží automaticky na každý PR. **Nálezy sú v REVIEW THREADOCH** — `gh pr view --json comments` ich NEUKÁŽE. Signály: 👀 emotikon = review beží; 👍 = OK bez nálezov; review komentáre = nálezy na vyriešenie.

## Postup

1. **Po `git push` + `gh pr create`** (PR popis po slovensky cez `--body-file`, nie here-string): nastav budík — Bash `sleep 600` s `run_in_background: true`; medzitým pokračuj v inej práci.
2. **Po budíku over stav:**
   - `gh pr view <N> --comments` — ak 👀 a nič viac, review ešte beží → krátky druhý budík (~3 min).
   - Nálezy (review thready):
     ```
     gh api graphql -f query='query { repository(owner:"michalmoronga-alt", name:"noxun-panel") { pullRequest(number:<N>) { reviewThreads(first:50) { nodes { isResolved path line comments(first:10) { nodes { databaseId author { login } body } } } } } } }'
     ```
3. **Každý nález:** posúď závažnosť (P1/P2/P3), oprav vo vetve PR, commit + push. Over testy: headless `ruby tests/run_all.rb` vždy; `scripts/run_su_tests.ps1` pri zmenách builderov/observerov (výsledkový grep až PO dobehu — output sa dopisuje). Pri zmene css/js bumpni `?v=` cache-bust.
4. **Odpovedz v threade s hashom opravy:**
   ```
   gh api repos/michalmoronga-alt/noxun-panel/pulls/<N>/comments/<databaseId>/replies -f body="Opravené v <hash> — <krátko čo a ako>."
   ```
   Ak nález vedome neopravuješ, odpovedz prečo.
5. **Merge robí Claude (od RETRO 12.8.):** keď sú OBE brány splnené — **CI zelené** (`gh pr checks <N>`) + **všetky nálezy vyriešené** (opravené s reply, alebo zdôvodnené prečo nie) — zmerguj: `gh pr merge <N> --merge` (vetvu maže repo automaticky). Potom over `git fetch` + `git log origin/main --oneline -3`, že merge commit v maine naozaj je.
6. **Záznam do denného reportu** (nahrádza niekdajšie hlásenie „môžeš mergovať"): čo PR mení z pohľadu používateľa · stav testov · výsledok Codex review (počet nálezov + ako vyriešené). Report sa Michalovi posiela súhrnne na konci bloku, zrozumiteľný z mobilu bez čítania diffu.

**Pravidlo 3 kôl:** ak review ide do 3. kola opráv, PR bol zle narezaný — zavri ho a rozdeľ na menšie celky, neiteruj (lekcia PR #93 s 10 kolami).

## Pasce

- MERGED v `gh pr list` ≠ obsah v maine — po mergi vždy `git fetch` + `git log origin/main`.
- Stacked PR: ak base vetva nebola zmazaná, over `gh pr view <N> --json baseRefName` a prípadne `gh pr edit <N> --base main`. (Repo má „Delete branch on merge" zapnuté, takže pasca hrozí len pri ručne vytvorených reťaziach.)
- Slovenský text do PR/replies vždy cez `--body-file` alebo `-f body=` (nie here-string v PowerShelli).
