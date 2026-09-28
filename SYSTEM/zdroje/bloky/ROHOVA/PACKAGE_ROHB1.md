# Package ROH-B1 · ovládače rohovej a prepínač strany dverí (K3)

> **Blok 8 · K3 ROHOVÁ SKRINKA**, tretia kódová dávka. **Package v1** (28.9.2026 ~11:45). Podklady v `SYSTEM/zdroje/bloky/ROHOVA/`: rozhodnutia
> [ROZHODNUTIA_MICHALA_2026-09-27.md](ROZHODNUTIA_MICHALA_2026-09-27.md) (R1–R9), **schválený mockup** (Michal 28.9. 11:28: „pozrel som mock, všetko sedí"
> — O1–O12 podľa návrhu; súbor `scratchpad/mockup_rohova.html` → implementátor ho pridá do priečinka ako `MOCKUP_ROHOVA_2026-09-28.html`), packages
> [PACKAGE_ROHA1.md](PACKAGE_ROHA1.md) (kontrakt) a [PACKAGE_ROHA2.md](PACKAGE_ROHA2.md) (vkladanie, náhľad s otvorom). Main `90b8b8ac` (v0.14.2).
> **Trieda:** nové ovládacie prvky v UI + akcia panela zapisujúca do modelu + **premapovanie uložených ručných hrán pri prepnutí strany** (výrobné dáta —
> hrany) → **predrecenzia povinná**, **in-SU brána**, `codex-audit` (dobrovoľný, risk-based kvôli premapovaniu hrán) · GH Codex review. Kontrakt
> (polia, schéma) sa **nemení**. Verzia → **v0.14.3**.

## Cieľ (z pohľadu stolára)

- Pri označenej rohovej je v **Základné → Rozmery jeden riadok** (O3 B1) cez oba stĺpce ako riadok Nohy: **Dverová časť** · **CR** (šírka CR 1, hĺbka CR 2)
  · **strana dverí** (vľavo / vpravo) · tooltip `?`. Ten istý riadok je aj vo **vkladacej karte** pri type Rohová (O4 A1) — stranu zvolíš už pred vložením.
- **Prepnutie strany** (O5): zrkadlí celú rohovú zostavu aj dvere, skrinka ostane stáť na mieste, **pánty ostanú voči rohu** (pri rohu → pri rohu, pri boku →
  pri boku), **okraje čiel sa prehodia** (vonkajší ostane vonkajší), **ručne zmenená hrana prejde so zrkadlom**, **jeden krok Späť**.
- **Rozsahy** (O2): dverová časť 250–800, CR 50–250; skrinka aspoň **dverová časť + CR 1 + hrúbka CR 2 + 2 × hrúbka korpusu** (pri 450 / 80 / 18 = 584);
  mimo rozsahu pole zčervená a skrinka sa neprestaví — minimum šírky už nie je pevné 584 (P3-2 z A1), ale z konfigurácie a skutočnej hrúbky CR 2.

## Scope IN

1. **Riadok rohovej v Inspectore** (`panel.html` Základné → Rozmery, vzor riadku Nohy `legsRow :325` — cez oba stĺpce): tri číselné polia (`corner_door_w`,
   `corner_cr1`, `corner_cr2`; ikony šírky/hĺbky podľa mockupu, sekcia B1) + dvojstavový prepínač strany (ikony ◧ / ◨, `aria-pressed`, tooltip
   „Dvere vľavo / vpravo — zrkadlí celú rohovú zostavu") + `?` s vetou z mockupu. Viditeľnosť **len pri rohovej** cez jedinú autoritu `applyVisibility`
   (`form.js`); rad sa pri iných typoch nezobrazí a **nič neposiela**.
2. **Polia do JS `CONSTRUCTION_FIELDS`** — teraz majú DOM; zber (`collectConstruction`) ich pošle **len pri type `corner_blind`** (A1 C6: pri iných typoch nikdy,
   chýbajúci prvok nesmie ísť ako `null`). Server ich už pozná (`PARAM_KEYS`, `normalize`); round-trip pole ↔ config (vrátane šablóny a vkladania — A2 `cornerDraft`
   sa pri vkladaní berie z riadku, nie len z predvolieb).
3. **Živý náhľad a preflight:** zmena dverovej časti/CR → preflight otvoru (A2 mechanika, `opening` v odpovedi) a náhľad sa prekreslí; pri vkladaní rovnako.
4. **Minimum šírky (O2 + P3-2):** payload označenej skrinky a predvoľby vkladania nesú **`corner_th2`** (účinná hrúbka CR 2 z A1 `corner_thicknesses`) a JS
   počíta minimum `D + c1 + th2 + 2t` — **test parity** s `Construction.min_valid_width` (th2 18 / 19, obe strany, D/CR krajné hodnoty); pevné
   `TYPE_LIMITS.corner_blind.width [584, …]` (`form.js:181`) nahradí toto minimum. Pole mimo rozsahu → červené + stavová veta s minimom (vzor ostatných polí).
5. **Prepínač strany = samostatná serverová akcia** (napr. `handle_corner_side(payload)` — identita dokumentu R-02, `cabinet_id` echo, vzor `handle_apply`):
   jedna operácia = **jeden krok Späť**, prestavba; pri chybe abort bez stopy. Pri zmene strany zo `side` na `side'`:
   - `corner_side` = `side'`;
   - **čelá:** `gap_left` ↔ `gap_right` (vonkajší okraj ostane vonkajší, okraj pri rohu pri rohu — O11); **smer pántov** dverí zrkadlom `left` ↔ `right`
     (`unset` ostane `unset`; chýbajúci kľúč nechá predvoľbu rohovej); ak riadok nesie explicitnú stranu úchytkového profilu (`profile_edge` `left`/`right`),
     zrkadlom tiež; ostatné polia riadku (ID, profil, zámky) bez zmeny;
   - **ručné hrany** (`part_overrides[key]['edges']` + `edge_warnings`) **podľa osí dielca** (Codex Q4 z krížového auditu — nie všeobecný swap): dielce, ktoré sa
     zrkadlením presúvajú a majú dlhé hrany v X (**`AXES_FRONT`**: krídlo dverí `front:F1/wing:*`, `cabinet/cr:1`, `cabinet/corner_panel`) → **`L1` ↔ `L2`**
     (vrch/spodok `W1`/`W2` bez zmeny); stojace dielce zostavy (`AXES_UPRIGHT`: `cabinet/hinge_rail`, `cabinet/corner_rail`, `cabinet/cr:2` — hrany predná/zadná
     a vrch/spodok) **bez zmeny**; dielce korpusu (boky, dno, strop, výstuhy, chrbát, lišty, sokel, police) sa nepresúvajú → **bez zmeny**. Materiál, smer dekoru
     a ručné kovanie sa nemenia (kľúče ostávajú).
   - **Iné cesty zmenu strany ďalej odmietajú** (`handle_apply`, `handle_apply_all`, šablóna na existujúcu rohovú — A1), len veta sa zmení na
     „Stranu dverí zmeň prepínačom v riadku rohovej." (`CORNER_SIDE_MSG`, `actions_cabinet.rb:34`; `templates_dialog.rb:546`).
6. **Vkladacia karta:** ten istý riadok (O4 A1) — polia a strana idú do návrhu vkladania (`cornerDraft`), preflight a náhľad vkladania ich použijú; vložená rohová
   má zvolenú stranu (bez premapovania — nová skrinka). Predvoľby z `DEFAULTS` (dvere vľavo 450 / 80 / 80).
7. **Dokumentácia:** schválený mockup do priečinka (`MOCKUP_ROHOVA_2026-09-28.html` s rámčekom „schválené 28.9. — O1–O12 podľa návrhu") + do
   `ROZHODNUTIA_MICHALA_2026-09-27.md` nový riadok **R10** (mockup schválený, O1–O12 stručne, O8: A1 pridal navyše ORANGE upozornenie — vratná voľba, čaká
   na Michalov pokyn) a §3 otázky označiť ako zodpovedané; `docs/UI_DIZAJN.md` (riadok rohovej, prepínač), `docs/architecture/ui-lifecycle.md` (riadok,
   zber polí, prepínač), `construction.md`/`outputs.md` len ak sa mení serverová logika (prepínač strany — nový odsek alebo prepis odseku `actions_cabinet`).

## Scope OUT (ROH-B2)

Kresba rohovej zostavy v náhľade (blenda šrafovaná, CR 1, CR 2 a rohová výstuha ako pásy), náhľad v Korpuse s dverami a CR (O12), karta Čelá rohovej
(veta „jedny dvierka", zámky, pánty „Pri boku / Pri rohu" — O10), „šírka dverí 446" v pravom stĺpci a súhrn „dvere vľavo 450" (O12), klávesa strany
pri vkladaní (O12), ikona z mockupu (O4), odhad „≈ dielcov" s rohovou zostavou, skrytie delenia zón pri rohovej. Rozhodnutie o ORANGE O8 (čaká na Michala).

## Testy a DoD

- **JS** `tests/js/test_rohb1_ovladace.js`: riadok viditeľný len pri rohovej (Inspector aj vkladanie), zber polí len pri rohovej (dolná/horná/slot nič
  nepošlú — parita payloadu s mainom), minimum šírky = server (parita tabuľkou), prepínač strany volá samostatný callback a neposiela iné polia, zmena polí
  spustí preflight. Každú JS sadu zvlášť.
- **Headless** (napr. `tests/pure/test_rohb1_strana.rb`): premapovanie pri prepnutí — `gap_left/right`, smer (`left`/`right`/`unset`/chýbajúci), `profile_edge`,
  hrany podľa osí (krídlo, CR 1, blenda `L1↔L2`; výstuhy, CR 2 a korpus bez zmeny; `edge_warnings` spolu s hranou), dvojité prepnutie = pôvodný config
  (identita), odmietnutie iných ciest s novou vetou, identita dokumentu, neexistujúca/nerohová skrinka.
- **In-SU** `run_rohb1` (runner `-CloseWhenDone`; worktree najprv dostane kópiu `_dev\ENGINEtests.skp`): rohová vľavo s ručnými hranami na dverách, CR 1,
  blende a výstuhe závesov a s vonkajším okrajom 0 / pri rohu 2 → prepnutie → geometria plán ↔ model (zrkadlo), hrany na **správnych fyzických stranách**
  (ABS vo výstupe dielca), smer pántov pri rohu, okraje prehodené, **1 krok Späť** vráti presne pôvodný stav; prepnutie späť = pôvodný config; vloženie rohovej
  so stranou vpravo z vkladacej karty (cesta panela) = 1 krok Späť.
- **Mutácie** (min. 5): swap hrán aj pri `AXES_UPRIGHT` · bez swapu okrajov · smer bez zrkadla · `unset` → strana · zber polí aj pri dolnej.

## Riziká

Premapovanie hrán je výrobné — chyba = páska na zlej hrane. Preto: jediná funkcia premapovania s tabuľkou podľa osí, test „dvakrát prepnúť = identita",
in-SU s ručnými hranami. Náhľad v A2 kreslí len dvere — pravú zostavu uvidí Michal v modeli (kresba v B2).

## Smoke pre Michala (po B1)

1. Označ rohovú → v Rozmeroch riadok **Dverová časť 450 · CR 80 / 80 · ◧** → prepni na ◨ → skrinka ostane na mieste, dvere a CR lišta sú vpravo, pánty pri rohu;
   Ctrl+Z vráti jedným krokom. 2. Zmeň dverovú časť na 500 → dvere 496, slepá časť sa zúži. 3. Daj šírku 580 → pole zčervená (minimum 584). 4. Vo vkladacej karte
   zvoľ Rohová + ◨ → vloží sa pravá rohová. 5. Ručne zmeň ABS na ľavej hrane dverí → prepni stranu → páska je na tej istej (teraz pravej) fyzickej hrane pri boku.

## Checklist uzáveru

Bump v0.14.3 + všetky `?v=` → testy (headless, JS, in-SU) → dokumentácia (bod 7) → STAV/KRONIKA/PLAN (riadok **ROH-B1** v bloku 8 ✅ `PR #?` — PLAN dnes
má jeden riadok ROH-B, rozdeľ ho na B1 a B2) → číslo PR samostatným commitom. Package + audit návrhu do `SYSTEM/zdroje/bloky/ROHOVA/`.

## Sonda pred auditom (krok 0, 28.9.2026 ~11:50, main `90b8b8ac`)

| Tvrdenie | Výsledok |
|---|---|
| `Construction.min_valid_width` = `D + c1 + th2 + 2t` (bod 4, JS zrkadlo) | 450/80/80 vľavo aj vpravo t 18 → **584 = 584** · 300/50/120 → **404 = 404** · 600/120/50 vpravo t 25 → **788 = 788** · 800/250/250 → **1104 = 1104** (th2 18) |
| hrany `AXES_FRONT` (krídlo dverí, CR 1, blenda) | `front_door`, `cr_front`, `corner_blind_panel`: **L1 „Ľavá", L2 „Pravá"**, W1 „Dolná", W2 „Horná" → zrkadlo = `L1 ↔ L2` |
| hrany `AXES_UPRIGHT` (výstuha závesov; rovnako rohová výstuha, CR 2) | `hinge_rail`: **L1 „Predná", L2 „Zadná"**, W1/W2 dolná/horná → zrkadlo **bez zmeny** |
| kľúč jednokrídlových dverí | `front:<id>/wing:single` (`fronts.rb:254`); 2 krídla `…/wing:left|right` — rohová má vždy 1 krídlo (A1) |
| formát ručnej hrany | `part_overrides[key]['edges'] = {L1: kód|nil, …}` + `edge_warnings` (STANDARD §7.2, `:1138–1143`) |

## Audit návrhu ROH-B1 (Codex `gpt-6-astra`, dobrovoľný, 28.9.2026 ~12:20) — 0 BLOCKER · 5 FIX · 2 NOTE, všetko do implementácie

Surový výstup: [AUDIT_ROHB1_2026-09-28.md](AUDIT_ROHB1_2026-09-28.md).

| # | Nález | Zapracovanie (záväzné pre implementáciu) |
|---|---|---|
| 1 FIX | prepínač nemá poradie voči auto-apply — rozpísaný formulár by po echu prepísal zrkadlené čelá starými | prepnutie **až po potvrdenom auto-apply** (vzor `nxCabinetAction`, `form.js:566`): flush rozpísaného → prepnutie → korelované prijatie nového stavu; ďalšie edity počas prepínania odložiť; test klik počas debounce aj počas odoslaného apply |
| 2 FIX | vkladanie „bez premapovania" rozbije čelá šablóny (asymetrické medzery, explicitný smer) | pri prepnutí strany **vkladacieho návrhu** zrkadliť aj `gap_left/right`, explicitný `direction` a `profile_edge` (výnimka „bez premapovania" platí len pre `part_overrides` — nová skrinka ich nemá); test obe strany šablóny s asymetrickými medzerami |
| 3 FIX | nový handler bez bariéry observera — oneskorená absorpcia Scale by sa prilepila k prepnutiu | `ScaleWatch.flush_pending!` **pred načítaním východiskového configu** (precedens `actions_appliance.rb:189`), pri neúspechu odmietnutie, po bariére znova overiť dokument a cieľovú skrinku; in-SU **Scale → okamžité prepnutie → Späť/Znova** |
| 4 FIX | minimum šírky z predvolených hrúbok nestačí (šablóna/projekt: korpus 25, čelový 19 → 599, nie 584) | minimum formulára z **účinných `t` aj `th2` aktuálneho návrhu** (šablóna, dedenie, zámok hrúbky); obnoviť po zmene materiálov |
| 5 FIX | `min_valid_width` sonduje celé mm, presná hranica je `corner_fit_width` (`construction.rb:658`) — 584,6 vs 585 | minimum formulára = **presné** `corner_fit_width` (parita testom aj s desatinnými D/CR/th2); celé mm ostávajú len pre klamp Scale |
| 6 NOTE | živý preflight označenej rohovej berie celý uložený config (`actions_cabinet.rb:120`) — živá zmena D nedôjde do otvoru | pri označenej rohovej: **strana** zo servera (uložený config), **rozmery D/CR zo živého formulára**; test výsledného otvoru, nie len odoslania |
| 7 NOTE | remap hrán musí zachovať rozdiel „chýba" vs `nil` (`nil` vypína ABS) | `{L1: X}` → **iba** `{L2: X}` (nepridávať `L1: nil`), `edge_warnings` spolu s hranou; test riedkej mapy |
