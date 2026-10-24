# Package P4a — drobnosti, ktoré ušetria čas každej ďalšej dávke (blok PRAVIDLA, 23.10.2026)

> **Trieda S** (nové skripty a hook, žiadny kód pluginu — VERSION ani `?v=` sa nemenia) · profil `implementator-stredny`.
> Definície tried a brán: [SYSTEM/pravidla/DEFINICIE.md](../../../pravidla/DEFINICIE.md). Rozhodnutia: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 9 (bod 7: číslo PR
> skriptom, inštalácia len po zmene pluginu; bod 8: drobnosti hneď za P1a) · [ROLY.md](ROLY.md) § 8 (❓1 `otvor_pr.ps1` — áno).
> **Predrecenzia:** podľa D4 nepovinná (S, bez kódu pluginu, bez UI) — orchestrátor ju **napriek tomu spustí**, lebo hook beží pri každom príkaze agenta.

## 0 · Sonda (23.10.2026, hlava b8007d01)

| Tvrdenie | Overenie | Výsledok |
|---|---|---|
| `scripts/ui_foto.ps1` už vie vziať testovací model z hlavného checkoutu | `sed -n 76,95p` | áno — funkcia `Resolve-NxTestModel` (cez `git rev-parse --path-format=absolute --git-common-dir`) |
| `scripts/run_su_tests.ps1` model z hlavného checkoutu nevezme | r. 57–58 | `$model = Join-Path $repo '_dev\ENGINEtests.skp'`, inak `exit 1` |
| `scripts/export_test.ps1` rovnako | r. 36 | `_dev\export_test\zakazka.skp` len z aktuálneho checkoutu |
| CI spúšťa JS sady slučkou | `.github/workflows/tests.yml` r. 18–22 | `for f in tests/js/test_*.js; do node "$f" \|\| exit 1` |
| Existujúce hooky | `.claude/settings.json` | PostToolUse `Edit\|Write` (post_edit_check), `*` + UserPromptSubmit (context_meter) |

## 1 · Čo sa zmení (z pohľadu agentov)

1. **`scripts/run_js_tests.ps1`** — všetky JS sady jedným príkazom (izolácia worktree odmieta zložené príkazy; 5 retro záznamov). Spustí každý
   `tests/js/test_*.js` zvlášť, vypíše súhrn `JS: N sád, M PASS, K FAIL` a skončí kódom ≠ 0 pri prvom zlyhaní alebo na konci (vyber
   a zdokumentuj). Pravidlá (CLAUDE.md Testovanie, typy implementátorov, skilly) prepnúť na tento príkaz; bash slučku ponechať ako alternatívu len v CI.
2. **Testovací model z hlavného checkoutu** (4 retro záznamy) — `Resolve-NxTestModel` z `ui_foto.ps1` presunúť do spoločného
   `scripts/lib/nx_paths.ps1` (dot-source) a použiť v `run_su_tests.ps1`, `ui_foto.ps1` aj `export_test.ps1` (pre `_dev\export_test\zakazka.skp`
   rovnaký vzor). Hláška pri chýbajúcom modeli menuje obe skúšané cesty.
3. **`scripts/otvor_pr.ps1`** — jeden príkaz na otvorenie PR:
   - parametre: `-Title`, `-BodyFile`, `-CoAuthor "Claude <model> <noreply@anthropic.com>"` (povinný — skript model nevie), voliteľne `-Base main`;
   - kvótová brána `.claude/skills/usage/usage.ps1 -Gate codex` → exit 3 = PR ako **draft** a výpis, čo z toho plynie (odkaz na skill `usage`);
   - `gh pr create`; potom v súboroch zmenených vetvou voči base nahradí **`PR #?`** číslom PR (len v `SYSTEM/PLAN.md`, `SYSTEM/STAV.md`,
     `SYSTEM/archiv/KRONIKA.md`, `SYSTEM/archiv/DOGFOODING_vyriesene.md` — inde sa `PR #?` vyskytuje ako text pravidla), samostatný commit
     `docs: doplnit cislo PR #N` s trailerom `-CoAuthor`, push;
   - na konci vypíše URL PR, číslo, či je draft, a SHA commitu s číslom.
   - Pravidlá o čísle PR (CLAUDE.md Verzia a uzáver, `codex-po-pr`, typy implementátorov krok 7) prepnúť na tento skript — ručný postup ostane ako záloha jednou vetou.
4. **Pripomienka po mergi** — hook **PostToolUse** na Bash príkaz `gh pr merge <N>` (filter: pole `if` / `matcher` podľa docs Claude Code —
   **overiť na lokálnej verzii** `claude --version`; keď `if` nie je, hook dostane každý Bash a sám rýchlo skončí, keď príkaz nie je merge).
   Hook (`.claude/hooks/po_merge.js`, node, bez sieťových volaní okrem `gh pr view <N> --json files,mergedAt`) vloží `additionalContext`
   **ako vecné konštatovanie, nie rozkaz**, napr.: „PR #N zmergovaný. Zmenené súbory pluginu: áno/nie (noxun_engine/, ui/, noxun_engine.rb) —
   inštalácia mainu je potrebná / nie je potrebná. Hodnotenie úlohy pre PR #N zatiaľ nie je zapísané." (Záznam hodnotenia zavedie P5; dovtedy
   hook len konštatuje.) Pri akejkoľvek chybe hook mlčí (exit 0) — nikdy neblokuje.
   - Pravidlo „po KAŽDOM mergi nainštalovať main" (CLAUDE.md Verzia a uzáver) upraviť podľa rozhodnutia 7b: **len keď PR mení plugin**; hook to rozlíši.

## 2 · Testy

- `run_js_tests.ps1`: test, že nájde všetky sady a pri zlyhaní jednej vráti ≠ 0 (stačí pomocná falošná sada v dočasnom priečinku).
- `nx_paths.ps1`: test oboch vetiev (model v checkoute · model len v hlavnom checkoute) — vzor existujúcich PowerShell testov, ak sú; inak
  Ruby test v `tests/pure/`, ktorý skript spustí (`powershell -NoProfile -File …`) a na Linuxe (CI) sa korektne preskočí.
- `po_merge.js`: JS test v `tests/js/` — **povolený aj zakázaný prípad**: príkaz `gh pr merge 123 --merge --match-head-commit X` → kontext
  vznikne (so stubnutým `gh`), `gh pr view 123` / `git merge` / prázdny vstup → nič; zlyhanie `gh` → nič, exit 0.
- `otvor_pr.ps1`: suchý beh `-WhatIf` (nič nevytvorí, vypíše, čo by urobil) + test nahradenia `PR #?` na dočasných súboroch.
- Headless + všetky JS sady zelené (headless na Windows občas padá na `Errno::EACCES` v `json_file_store.rb` — známe, zopakovať, uviesť).

## 3 · Dokumentácia

- CLAUDE.md (Testovanie, Verzia a uzáver), typy implementátorov (kroky testov a PR), skilly `codex-po-pr` a `predrecenzia` (kde volajú JS sady
  alebo číslo PR) — nové príkazy namiesto ručných postupov. **Grep pred commitom:** „test_\*.js", „PR #?", „nainštalovať main", „ENGINEtests"
  cez CLAUDE.md, WORKFLOW, `.claude/agents`, `.claude/skills` — každé miesto, ktoré odporuje novému postupu, upraviť (podnet z P1a).
- Popis hookov (`docs/` alebo CLAUDE.md, sekcia Lokálne hooky) o jednu vetu doplniť.
- KRONIKA odsek navrch; PLAN riadok P4a `✅ … — PR #?` (číslo doplní už nový skript — prvé ostré použitie).

## 4 · Hotovo, keď

1. Testy zelené (vrátane nových), CI zelené na pushnutej vetve.
2. Vo worktree bez `_dev` `run_su_tests.ps1` nájde model z hlavného checkoutu (overiť len vyhľadaním cesty — `-WhatIf`/suchý beh, **SketchUp nespúšťať**).
3. PR tejto dávky je otvorený **skriptom `otvor_pr.ps1`** (dôkaz, že funguje) a číslo PR doplnil skript.
4. Grep z § 3 nenájde rozpor.
