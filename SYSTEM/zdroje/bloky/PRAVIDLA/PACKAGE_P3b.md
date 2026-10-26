# Package P3b — postupy: skilly `uzaver-bloku` a `smoke`, ORCHESTRATOR.md pod strop, WORKFLOW ako mapa (blok PRAVIDLA, 26.10.2026)

> **Trieda S** · profil `implementator-stredny` · **len pravidlá, skilly, dokumentácia a testy — kód pluginu sa nemení** (VERSION ani `?v=` nie).
> Štartuje z čerstvého mainu **po mergi P3a** ([PACKAGE_P3a.md](PACKAGE_P3a.md) — `.claude/rules/`, `docs/HOOKY.md`, IMPLEMENTATOR ≤ 8 kB).
> Vstupy: [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 3 (riadky „Uzáver bloku", „Lokálne hooky", „Kvóty", „Autonómne bloky"), § 5 (G1, G2),
> § 6 (orchestrátor ~22 kB pravidiel spolu), § 7 (riadky smoke 94 bodov, `_dev` 3,7 GB, nepushnutý zápisník) · [ROLY.md](ROLY.md) § 3.1 ·
> nálezy nočnej hliadky pravidiel P-2026-10-23-2 a P-2026-10-23-3 (vetva `claude/hliadka`, `hliadka/pravidla/2026-10-23.md`).

## 1 · Cieľ

1. **Skill `uzaver-bloku`** (`.claude/skills/uzaver-bloku/SKILL.md`, ≤ 500 riadkov, frontmatter `name` + `description` ako ostatné skilly):
   postup uzáveru bloku krok za krokom. **Telo = presun** z [ORCHESTRATOR.md](../../../pravidla/roly/ORCHESTRATOR.md) (sekcia Uzáver bloku,
   z Autonómnych blokov odrážky „Uzáver bloku = variant B" a „Uzáver pri plnom kontexte", z Toku bloku veta o presune priečinka bloku po
   uzávere) — v ORCHESTRATOR.md po presune ostane **jedna veta**: kedy (hneď po poslednej dávke), poistka (nový blok až po smoke PASS alebo
   „ideme ďalej") a odkaz na skill. Vzor reálneho uzáveru: blok HARDENING (`SYSTEM/archiv/HARDENING_ZAVER_2026-10-11.md`,
   `SYSTEM/archiv/bloky/HARDENING/`, KRONIKA Grepom „uzáver" pri v0.18.0). Nové kroky (len tieto, nič ďalšie nevymýšľaj):
   - **zostavenie smoke checklistu** do záverečného dokumentu (body s ID po skupinách, formát podľa skillu `smoke`);
   - **upratanie** (NAVRH § 7: `_dev` 3,7 GB, worktrees ~1 GB, chyby „cesta príliš dlhá"): skript nič nemaže sám — orchestrátor vypíše
     zoznam kandidátov (veľké run kópie a dočasné modely v `_dev`, worktree zmergovaných vetiev cez `git worktree list`) s veľkosťou a
     **maže až po súhlase Michala**; `_dev\ENGINEtests.skp`, Michalove zákazky a smoke modely sa nikdy nenavrhujú. Worktree len cez
     `git worktree remove` / `prune` (nie mazanie priečinka).
2. **Skill `smoke`** (`.claude/skills/smoke/SKILL.md`): ako orchestrátor vedie smoke bloku s Michalom. Telo z praxe (NAVRH § 7 riadky „Smoke 94 bodov"
   a „smoke zápisník bol v nepushnutej vetve"; vzor zápisníka vetva `claude/smoke-hardening-af4163`, `SYSTEM/archiv/bloky/HARDENING/SMOKE_ZAPISNIK_*.md`):
   - **zápisník** `SMOKE_ZAPISNIK_<dátum>.md` v priečinku bloku (po uzávere `SYSTEM/archiv/bloky/<BLOK>/`) — stav bodu PASS / FAIL / VYNECHANÉ
     (kto rozhodol) / ZOSTÁVA + dôkaz; postrehy `S1…`; **po každom sedení commit a push** vetvy `docs/smoke-<blok>` (nová session dostane cestu
     k zápisníku a vetvu, nie len slovo);
   - **Michal najprv škrtne** nerelevantné body (otázka po skupinách) — vynechané sa zapíšu s dôvodom;
   - **rozdelenie bodov:** overiteľné agentom (runner, export test, fotenie okien, bridge — **len v ENGINEtests alebo testovacom modeli `_dev`,
     nikdy v zákazke**; pred exportom over cieľový priečinok, aby nemieril do reálneho projektu) vs. ručné u Michala (vizuál, UX, dielňa);
   - **nálezy** → dočasná skupina „smoke po uzávere" v DOGFOODING, opravy x.y.z; **smoke PASS** (Michalovo slovo) → dokumentačné PR so
     zápisníkom: STAV „smoke PASS", KRONIKA.
   Skill neobsahuje pravidlá, ktoré už majú domov (testovanie len v ENGINEtests = AGENTS.md; brány = DEFINICIE) — odkazuje.
3. **`ORCHESTRATOR.md` ≤ 8 kB** (dnes 13,9 kB), bez straty pravidla:
   - Uzáver bloku → skill `uzaver-bloku` (bod 1).
   - **Inštalácia mainu:** popis hooku `po_merge.js` (čo vloží, odkiaľ berie údaje, že nič nespúšťa) → `docs/HOOKY.md` (vznikol v P3a); v roli
     ostane pravidlo — kedy inštalovať, značka nasadenia `%TEMP%\noxun_nasadene.txt`, hook to po mergi konštatuje.
   - **Ukazovateľ kontextu:** popis hooku `context_meter.js` → `docs/HOOKY.md`; v roli ostanú prahy 75 % a 90 % a čo robiť.
   - **Kvóty a štart okna:** podrobnosti `start_okna.ps1` (čo všetko vypíše) → skill `usage` (ak tam ešte nie sú); v roli ostane „štart okna =
     jedna kontrola `start_okna.ps1`" a „pred drahým krokom stav kvót; prahy a reakcie len v skille `usage`".
   - **Autonómne bloky:** odrážka Retro → jedna veta s odkazom na skill `retro` (pravidlá retro mení P5, tu len presun).
   - Ostatné (karta, delegovanie a merge, tabuľka „Keď Michal neodpovie", tok bloku, bezpečnosť) **ostáva**; skrátiť len zjavné opakovania
     v rámci súboru. Podpisová veta „Hlavné okno je orchestrátor" (G4) ostáva prvou vetou.
   - **Keď 8 kB nejde bez straty pravidla:** nerež význam — dočasne vlastný strop **10 kB len pre ORCHESTRATOR.md** (NAVRH § 6 počíta
     s ~22 kB pravidiel orchestrátora spolu s AGENTS a DEFINICIE), zmeraná veľkosť a zoznam, čo by sa muselo vypustiť, do § 4 nižšie;
     orchestrátor to predloží Michalovi.
4. **WORKFLOW.md = mapa bez kópií pravidiel** (NAVRH § 8, P3): v § 1, § 3–§ 8 a § 10 nahradiť každú vetu, ktorá **opakuje** pravidlo z AGENTS.md,
   roly, DEFINICIE alebo skillu, odkazom na jeho domov (diagramy, tabuľky „kto · kedy · kde je pravidlo" a vysvetlenie toku pre ľudí ostávajú).
   **Nemeniť:** § 2 Obsadenie rolí (číta ho mod usage-bar; presun do `OBSADENIE.md` = P5) a § 9 Retro (prepracuje P5). Stĺpec „Kde je pravidlo"
   v § 6 a § 7 opraviť na nové domovy (P3a: `.claude/rules/`, `docs/HOOKY.md`; P3b: skilly).
5. **Nález hliadky P-2026-10-23-2 — jeden domov bloku OBMEDZENIE NÁSTROJOV:** text bloku žije v **jednom súbore** `scripts/agy/obmedzenie.txt`
   (UTF-8 bez BOM, jeden riadok), z ktorého ho berie beh v obale (`SYSTEM/pravidla/typy/agy-reserser.md`: `OBM="$(cat "$S/obmedzenie.txt")"`)
   aj v skille `antigravity-outside-in` (krok 1 a 2 — odkaz na súbor namiesto doslovného textu). Diagnostika prázdneho výstupu: **vysvetlenie**
   ostáva v skille (Pasce), obal si ponechá len svoj vykonateľný krok 4 (meranie packetu, čo vrátiť) a jeho odrážka v Pasciach o prázdnom
   packete sa nahradí odkazom na skill. Potom `ruby scripts/generuj_typy_agentov.rb`.
6. **Nález hliadky P-2026-10-23-3 — história v pravidle (v rozsahu P3b):** zo skillu `antigravity-outside-in` (ktorý P3b aj tak mení) presunúť
   dátumy, čísla PR a verzie nástroja („overené 22.–23.10.2026, agy 1.4.5", „Michal 3.9.2026", „rozhodnutie Z8, 26.9.2026", „pilot 3.9." …) do
   KRONIKY; v skille ostane len platné znenie (rozhodnutie môže ostať menované kódom, napr. „Z8", bez dátumu). Nové skilly `uzaver-bloku`
   a `smoke` sa píšu bez histórie. **Ostatné skilly** (`codex-audit`, `codex-po-pr`, `predrecenzia`, `retro`, `usage`) a rozšírenie G2 na všetky
   skilly sú **mimo rozsahu** — riadok do PLAN k P6.
7. **Odkazy:** Grep na `ORCHESTRATOR.md#uzaver-bloku`, „Uzáver bloku", „ORCHESTRATOR.md, Uzáver", „context_meter", „po_merge", „OBMEDZENIE NÁSTROJOV"
   v `AGENTS.md`, `SYSTEM/pravidla/`, `.claude/rules/`, `SYSTEM/WORKFLOW.md`, skilloch a `docs/` — každý vedie na nové miesto (napr. IMPLEMENTATOR.md
   § Verzia odkazuje na postup uzáveru bloku → skill `uzaver-bloku`). **IMPLEMENTATOR.md má po P3a 8170 B pri strope 8192 B** — oprava odkazu
   nesmie strop prekročiť (kratší odkaz, nie nový text).

## 2 · Stráže a testy (`tests/pure/`)

1. **G1** (`test_pravidla_velkost.rb`): strop `SYSTEM/pravidla/roly/*.md` 14 → **8 kB** (prípadná výnimka ORCHESTRATOR 10 kB podľa § 1 bod 3 ako
   samostatný riadok s komentárom bez histórie); nové skilly ≤ 500 riadkov (NAVRH G1) — strop pre `.claude/skills/*/SKILL.md`.
2. **G2:** do `NX_PRAV_HISTORY_SCAN` pridať `.claude/skills/uzaver-bloku/**/*.md`, `.claude/skills/smoke/**/*.md` a
   `.claude/skills/antigravity-outside-in/**/*.md`.
3. **Stráž jedného domova OBM:** test, že doslovný text bloku (prvé slová „OBMEDZENIE NÁSTROJOV:" s dvojbodkou) je v repe len v
   `scripts/agy/obmedzenie.txt` (Grep cez `.claude/`, `SYSTEM/`, `scripts/` okrem toho súboru = 0) a že obal ho číta z tohto súboru.
4. G4 (`--check`), `test_docs_navigacia`, encoding guard, headless `ruby tests/run_all.rb` + `scripts\run_js_tests.ps1` zelené. In-SU netreba.

## 3 · Hotovo, keď

1. **Mapa presunu** `SYSTEM/zdroje/bloky/PRAVIDLA/P3b_MAPA.md`: každá veta odstránená z ORCHESTRATOR.md, WORKFLOW.md, skillu
   `antigravity-outside-in` a obalu `agy-reserser` → kde je teraz (alebo „história → KRONIKA"); odchýlky s dôvodom.
2. Veľkosti po zmene (bajty bez CR) v PR popise: ORCHESTRATOR, WORKFLOW, nové skilly, `antigravity-outside-in`, telo `agy-reserser`.
3. Stráže § 2 zelené, `--check` bez rozdielu.
4. **KRONIKA** odsek navrch (P3b + história presunutá z `antigravity-outside-in` + výsledok smoke pravidiel oblastí po P3a, ak ho orchestrátor
   dodá v zadaní) · **PLAN** blok 10: riadok P3b `✅ … — PR #?`; k P6 pripísať „história a dátumy v ostatných skilloch + G2 na všetky skilly
   (hliadka P-2026-10-23-3)" · **STAV** „Robí sa / Ďalší krok" (ďalej P4 stroje).

## 4 · Brány a výsledok (vyplní implementátor)

- Audit návrhu: nepovinný (D2). Predrecenzia: **akceptačný krok** — slepý recenzent overí mapu presunu proti `git diff main...HEAD`
  (nič nestratené, skilly bez nových pravidiel mimo § 1, obal `agy-reserser` po zmene funkčne rovnaký — príkaz behu skladá ten istý prompt).
- Pred PR **STOP** a report orchestrátorovi; PR až na pokyn cez `scripts\otvor_pr.ps1`.
- **Mimo rozsahu:** hooky a guardy G5–G11 (P4), retro a hodnotenia, `OBSADENIE.md` (P5), história v ostatných skilloch (P6).

