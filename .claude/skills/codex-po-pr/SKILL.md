---
name: codex-po-pr
description: Po odoslaní PR — budík ~10 min, kontrola Codex GH review (nálezy sú v review threadoch, nie komentoch), oprava nálezov, reply s commit hashom, hlásenie Michalovi „môžeš mergovať".
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
5. **Hlásenie Michalovi** (po slovensky, zrozumiteľné z mobilu BEZ čítania diffu): čo PR mení z pohľadu používateľa · stav testov · výsledok Codex review (počet nálezov + ako vyriešené) · explicitne „**môžeš mergovať**" + pripomienka **„Delete branch"** pri mergi (prevencia stacked pasce — nezmazaná vetva po mergi base PR nechá ďalšie PR v reťazi mimo main).

## Pasce

- MERGED v `gh pr list` ≠ obsah v maine — po Michalovom „zmergované" vždy `git fetch` + `git log origin/main`.
- Stacked PR: ak base vetva nebola zmazaná, over `gh pr view <N> --json baseRefName` a prípadne `gh pr edit <N> --base main`.
- Slovenský text do PR/replies vždy cez `--body-file` alebo `-f body=` (nie here-string v PowerShelli).
