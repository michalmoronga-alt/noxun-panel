# Grok + OCR vs. GitHub Codex review — výsledok benchmarku (10 PR)

Referencia = nálezy GH Codex review na presne tej istej hlave. Overenie v izolovaných kópiách repa (HEAD = „to“).
Všetkých 18 nálezov Codexu som overil v kóde ako reálne (niektoré sú okrajové scenáre, žiadny nie je planý).

## Tabuľka po PR

| PR | Codex | Grok | Zhody | Čiastočne | Grok minul | Grok navyše (pravdivé / sporné / plané) |
|---|---|---|---|---|---|---|
| 466 | 1 | 1 | 0 | 0 | 1 | 1 (1 / 0 / 0) |
| 457 | 3 | 1 | 1 | 0 | 2 | 0 |
| 456 | 1 | 0 | 0 | 0 | 1 | 0 |
| 455 | 2 | 2 | 1 | 0 | 1 | 1 (1 / 0 / 0) |
| 454 | 1 | 0 | 0 | 0 | 1 | 0 |
| 438 | 3 | 0 | 0 | 0 | 3 (z toho 1 vylúčený súbor) | 0 |
| 434 | 4 | 1 | 1 | 0 | 3 | 0 |
| 465 | 3 | 3 | 2 | 0 | 1 | 1 (1 / 0 / 0) |
| 453 | 0 | 0 | 0 | 0 | 0 | 0 |
| 437 | 0 | 0 | 0 | 0 | 0 | 0 |
| **Spolu** | **18** | **8** | **5** | **0** | **13** | **3 (3 / 0 / 0)** |

## Súhrn

- **Záchyt:** 5 / 18 = **28 %** (plné zhody 5, čiastočné 0). Bez jedného nálezu, ktorý minul kvôli výberu súborov OCR (438, vylúčené `.md`): 5 / 17 = **29 %**.
- **Presnosť Groka:** 8 / 8 = **100 %** pravdivých (5 zhôd s Codexom + 3 vlastné pravdivé nálezy).
- **Plané poplachy:** **0**.
- **Zhoda na „čistých“ PR:** 453 a 437 — Codex aj Grok bez nálezov (2/2 zhodne).
- **Jediný P1 Codexu** (465, duplicitná tabuľka modelov) Grok **minul**.
- Z 8 PR, kde Codex niečo našiel, vrátil Grok v 3 nulu (456, 454, 438) a v ďalších 3 len časť (457: 1 z 3, 434: 1 z 4, 455: 1 z 2) — chyby typu „zabudnutá vetva / chybový stav / súbežnosť“ prehliada.

## Párovanie nálezov

### PR 466 (šírka 50, nohy úzkej skrinky)
- **Codex bom.rb:917 (P2) — upravené pravidlo nôh hlásené ako zastarané → MINUL** (súbor bol v review). Reálny: `HardwareRules` riadok 992–994 vráti `:none` bez posunu verzie, keď sa nič nepridalo ani neobnovilo, takže upravené pravidlo so 4 nohami pod 200 mm nechá ORANGE nález, ktorý tlačidlo „Doplniť nové predvoľby“ nezhasne; okrajový, ale skutočný.
- **Grok construction.rb:1921 (P3) — hláška vždy viní sokel → PRAVDIVÝ.** `narrow_leg_ys` kreslí pri úzkej skrinke najviac 2 valce, takže pri 4 nohách v nákupe (starý snímok pravidiel alebo ručné 4) sa warning spustí aj keď sa obe zmestia a text „sa za soklom nezmestia“ je vecne nepravdivý; len text, nízka závažnosť (v maine stále neopravené).

### PR 457 (názov zákazky)
- **Codex production_core.rb:3285 (P2) — budget/ponuka/kovanie znova čítajú názov po bráne → ZHODA** s Grokom production_core.rb:1847 (rovnaký problém, Grok vymenoval všetky tri exporty a aj test, ktorý to zamyká).
- **Codex production_core.rb:229 (P2) — nenormalizovaný názov nad 120 znakov v menách exportov → MINUL** (súbor v review). Reálny: `vepo_payload` posiela `project` normalizovaný, ale `export_file_names(project, …)` dostáva surový; okrajový prípad (názov > 120 znakov).
- **Codex studio.js:1413 (P2) — blur nezmeneného editora prepíše novší názov → MINUL** (súbor v review). Reálny: `commitJobEdit` porovnáva s aktuálnym `ST.vepo`, nie s hodnotou pri otvorení, takže refresh z inej inštancie počas otvoreného editora + blur vráti starý názov; vyžaduje súbežnú zmenu.

### PR 456 (ExportSettings)
- **Codex export_settings.rb:203 (P2) — poškodený `project_names` sa pri skalárnom zápise neopraví → MINUL** (súbor v review). Reálny: `fresh.merge(attrs)` nechá `project_names: []` a `JsonFileStore.write` (json_file_store.rb:79–88) výsledok nekontroluje — vráti `:ok`, súbor ostane poškodený.

### PR 455 (kóty v náhľade)
- **Codex preview.js:836 (P2) — vodorovná kóta sa vynúti aj do úzkeho úseku → ZHODA** s Grokom preview.js:836 (rovnaké miesto, rovnaká podstata, Grok uviedol aj konkrétny prípad 6 stĺpcov pri min. výške).
- **Codex preview.js:233 (P2) — obrys malej dosky orezaný (2 mm ťah v mierke modelu) → MINUL** (súbor v review). Reálny: `pvBoardScene` má okraj l:0/t:0 a obrys dosky `stroke-width="2"` bez `non-scaling-stroke`; prejaví sa len pri veľmi malých doskách (desiatky mm).
- **Grok preview.js:856 (P2) — zvislé kóty výšok čiel padnú do vodorovného fallbacku a prekrývajú sa → PRAVDIVÝ.** `pvDimV` (r. 844–860) dá číslo vodorovne do stredu úseku bez rozostupu; fallback nastane pod ~16 px a prekryv pri úseku < ~11 px (písmo 11 px), napr. 40 mm čelá vo vysokej skrini alebo 100 mm šuflíky pri min. výške náhľadu (~0,08 px/mm). Zrkadlový problém k zhodnému nálezu, Codex ho nemal.

### PR 454 (súhrny Inspectora)
- **Codex hardware.js:863 (P2) — legacy override sa nepočíta vedľa compat → MINUL** (súbor v review). Reálny: `class_compat_payload` (payloads.rb:2312–2316) preskočí vlastníkov s `nil` triedou a JS vetva `if (o.compat)` potom ignoruje `owner_overrides`; dopad len na počet v hlavičke Sety („podľa projektu“ namiesto „1 vlastný“).

### PR 438 (texty a vzhľad H4b)
- **Codex docs/architecture/ui-lifecycle.md:2465 (P2) — dokumentácia popisuje pevné rozloženie a šírky, ktoré kód nemá → MINUL — VYLÚČENÝ SÚBOR** (OCR vyradil `.md`, chyba výberu súborov, nie Groka). Reálny: CSS má `.c-cab 22 %` a žiadne šírky 96/120 px, `partsTableClass` pri voliteľných stĺpcoch `fixed` vynechá.
- **Codex studio.js:1106 (P2) — Ruby stav prepínača smeru stále píše „bez smeru (legacy)“ → MINUL** (súbor v review; koreň v production_core.rb:3303 mimo zmenených riadkov). Reálny, žargón v jednej stavovej hláške.
- **Codex materials_dialog.rb:427 (P2) — chyba vrátenia katalógu stále hovorí „legacy katalóg“ → MINUL** (súbor v review; koreň v materials_health.rb:458, ktorý v diffe nie je). Reálny, žargón v chybovej vetve.

### PR 434 (ui_foto skripty)
- **Codex ui_foto.ps1:290 (P2) — odmietnutá nahrávka sa použije ako predvolená → ZHODA** s Grokom ui_foto.ps1:289 (rovnaký problém aj návrh — značka úspechu; v maine dnes `NAHRAVKA_OK.txt`).
- **Codex record.rb:110 (P2) — pri chybe štartu sa SketchUp nezavrie → MINUL** (súbor v review). Reálny: rescue v r. 108–110 zapíše marker, ale nevolá `close_and_quit` → visiaca inštancia mimo zámku.
- **Codex nx_stub.js:130 (P2) — neskoré chyby po 400 ms sa do reportu nedostanú → MINUL** (súbor v review). Reálny: report sa uzavrie po `wait(400)`, Chrome beží s `--virtual-time-budget=8000`.
- **Codex ui_foto.ps1:347 (P2) — súbežné behy v tej istej sekunde zdieľajú `shots_<čas>` → MINUL** (súbor v review). Reálny: `$outDir` nemá PID na rozdiel od `site_`/`chrome_` (v maine dnes `shots_<čas>_<PID>`).

### PR 465 (matica agentov — len dokumentácia, tu OCR `.md` pustil)
- **Codex implementator-stredny.md:24 (P2) — Sonnet profil opravuje aj P1 → ZHODA** s Grokom (ten istý rozpor s eskaláciou, aj odkaz na implementator-lahky.md).
- **Codex WORKFLOW.md:92 (P2) — triedy Ľ/S/Ť sa prekrývajú bez prednosti → ZHODA** s Grokom WORKFLOW.md:93 (rovnaká podstata a rovnaký návrh „Ť prebíja“; v maine dnes doplnené).
- **Codex WORKFLOW.md:94 (P1) — druhá kópia modelov mimo tabuľky Obsadenie rolí → MINUL** (súbor v review). Reálny a podľa pravidiel repa závažný (porušenie „jediného zdroja“); v maine stĺpec odstránený.
- **Grok WORKFLOW.md:103 (P2) — shadow beh vs. postup profilov (vetva, PR) → PRAVDIVÝ** (jadro). Profily Sonnet/Opus v kroku 2 a 7 vždy zakladajú `feat/…` a otvárajú PR, takže shadow beh by otvoril druhé PR; v maine bol neskôr doplnený režim „Shadow beh“ bez PR presne kvôli tomu. Časť o názve vetvy `-grok` vs `-<model>` je slabšia (len konkretizácia).

### PR 453, 437
- Codex 0, Grok 0 — zhodne čisté.

## Rozpis podľa druhu súborov

| Oblasť | Codex nálezov | Grok chytil | Grok navyše (pravdivé) |
|---|---|---|---|
| Ruby kód pluginu (core/ui .rb) | 6 (466, 457×2*, 456, 438×2) | 1 | 1 |
| JS / UI (preview, studio, hardware) | 4 (457, 455×2, 454) | 1 | 1 |
| Skripty (PowerShell, Ruby a JS nástroje) | 4 (434) | 1 | 0 |
| Dokumentácia / pravidlá (.md) | 4 (465×3, 438 docs) | 2 | 1 |

\* 457: jeden nález v Ruby chytil (gate), normalizáciu nie. 438 #2 je ukotvený v studio.js, ale koreň je v Ruby (production_core.rb:3303), preto je v riadku Ruby.

## Záver

Grok + OCR je **presný, ale málo citlivý**: všetkých 8 jeho nálezov je pravdivých (0 planých poplachov, 3 vlastné pravdivé nálezy navyše), no zachytil len **5 z 18 (28 %)** nálezov Codexu a minul aj jediný P1. Najslabší je v Ruby a JS kóde pluginu pri chybách typu „zabudnutá vetva“ — chybové a záložné cesty (rescue bez zavretia, poškodený súbor, legacy vlastníci), súbežnosť (refresh počas editácie, dva behy naraz) a dôsledky mimo zmenených riadkov (stará hláška v inom súbore); v troch kódových PR s nálezmi Codexu (456, 454, 438) vrátil nulu. Relatívne najlepší je pri dokumentácii a pravidlách (465: 2 z 3 + 1 pravdivý navyše) a pri vizuálnych/geometrických JS chybách, kde vie dať konkrétny číselný scenár; navyše OCR štandardne vyradí `.md`, takže dokumentačné nálezy v kódových PR systematicky stratí (438). **Ako náhrada Codexu pre ľahké dávky zatiaľ nie** — pri ~30 % záchyte by väčšina P2 prešla do mainu; použiteľný je ako **doplnkový druhý recenzent** (lacný, bez šumu, občas nájde niečo, čo Codex nemá) alebo ako náhradná brána len pre čisto dokumentačné a textové dávky, a aj tam s pustenými `.md` súbormi.
