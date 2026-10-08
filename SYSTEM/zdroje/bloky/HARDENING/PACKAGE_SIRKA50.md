# PACKAGE · Šírka skrinky od 50 mm + 2 nohy pod úzkou dolnou (ŠÍRKA 50, v0.17.28)

Dávka mimo tabuľky H1–H17 na pokyn Michala (7.–8.10.2026), zaradená do bloku 9 ako H18 (vzor ad hoc dávky). Trieda **Ť** (výrobná/cenová +
audit-povinná: `CONFIG_SCHEMA` 22 → 23 a seed pravidiel kovania 7 → 8). Audit návrhu: Codex `gpt-6.1-sol` 8.10.2026 (výsledok zapracovaný do
zadania nižšie). Zadanie a package žili v pamäti orchestrátora; do repa ich prenáša implementačná vetva `feat/sirka-50mm`, aby priečinok bloku
bol úplný. **Pri rozpore platí zadanie (§1).**

## 1. Zadanie po audite (brief)

Repo michalmoronga-alt/noxun-panel, z čerstvého `origin/main`. Vetva `feat/sirka-50mm`. Výrobná + audit-povinná (CONFIG_SCHEMA + seed
pravidiel kovania). Pravidlá: CLAUDE.md (povinné čítanie riadkov „buildery…", „kovanie…", „zmenu Ruby kódu"), DC netreba.
**Plný package s rozhodnutiami a sondou:** `C:\Users\PC\.claude\projects\C--APP-DEV-RUBY-ENGINE\memory\podklady\PACKAGE_sirka50.md`
(prečítaj celý). Tento brief je jeho finálna verzia po audite (Codex gpt-6.1-sol, 8.10.2026) — pri rozpore platí brief.

### Rozhodnutia Michala
- Najmenšia **šírka** dolnej aj hornej skrinky (typy bez vlastných `limits`) **200 → 50 mm**. Umývačka, rohová, výška 80, hĺbka 150 bez zmeny.
- **Úzka dolná skrinka (šírka < 200 mm) = 2 nohy v strede šírky (vpredu + vzadu), v nákupe 2 ks.**
- **Jedna dávka/PR** (audit BLOCKER 1: šírka nesmie ísť von bez pravidla nôh).

### Časť A — šírka
1. `CabinetBuilder::MIN[:width]` 50.0 (cabinet_builder.rb ~436–446, komentár), `ScaleWatch::MIN['width']` 50.0 (scale_observer.rb ~18–30),
   `form.js` `LIMITS.width` [50,3000] (+ komentáre).
2. **Panel: krížová kontrola šírka × hrúbka** = zrkadlo `Construction.validate!` (construction.rb:2109: chyba ak `w <= 2t + 10`), červené pole
   s rovnakou hláškou ako Ruby. JS test behaviorálne: 50/18 prejde, 50/20 a 60/25 odmietne.
3. `actions_cabinet.rb` `front_preflight_result` (~55–80): fallback rozsahy šírky AJ výšky z `CabinetBuilder::MIN` (výška dnes chybne 200).
4. `Construction.min_valid_width` (~1775): fallback ponechaj chránený `defined?(CabinetBuilder)` (audit NOTE 7) — len nech nie je magické 200,
   ak sa to dá bez zmeny poradia načítania; inak len komentár.
5. **`CONFIG_SCHEMA` 22 → 23** + záznam histórie (precedens 15): starší plugin by 50–199 ticho klampol na 200. Aktivačné konštanty bez zmeny.
   STANDARD tabuľka schém + §2.5 história, `docs/architecture/construction.md`.
6. Testy: `test_s1e0_min_vyska.rb` — dnešné asserty clampu na 200 / schéma ≥ 15 / porovnanie 14 prepíš (audit FIX 5); nové regresie: uložená
   aj šablónová šírka 50–199 mm so schémou 23 sa zachová, config so schémou 23 starší plugin (22) odmietne (`newer_config?`).

### Časť B — nohy
7. Pravidlo `nohy-zakladne` (hardware_rules.rb ~95–160): nové pásmo **šírka < 200 → 2**, 200–999 → 4, ≥ 1000 → 6. **Pozor (audit FIX 4):**
   konvencia pásiem je inkluzívne `v <= max` — `max 199` by šírke 199,5 dala 4. Zvoľ zápis, ktorý dá 199 → 2, 199,5 → 2, 200 → 4 (napr.
   `max 199.999…` s komentárom, alebo existujúci mechanizmus `min` — over v kóde). Test 199 / 199,5 / 200.
8. **SEED_VERSION 7 → 8** s komentárom v histórii; `merge_seed` migruje LEN preukázateľne neupravené seed pravidlo (vlastné úpravy
   používateľa zachovať — over, ako to robí bump v6 KOV-G1b, a sprav to rovnako). Nová konštanta proveniencie (vzor `LEG_WIDTH_SEED_VERSION`).
9. `Bom.leg_stale_issue` / `leg_stale_message` (bom.rb ~871–940): nová proveniencia v8 + úzky symptóm (skrinka < 200 mm s uloženými 4
   nohami a snapshotom < v8 → ORANGE „prestav skrinku"); hláška počíta 2/4/6. Pôvodné migračné hranice (v6) nemeniť (audit FIX 3).
   Príchyt sokla ostáva (1 ks na začaté 4 nohy → aj pri 2 nohách 1).
10. **Kreslenie** `draw_legs` / `leg_xs` (cabinet_builder.rb ~2648–2685): pri 2 nohách na úzkej skrinke **stred šírky, predná + zadná**
    pozícia; pri plytkej skrinke (jeden rad) sa 2 nohy nesmú prekryť (audit FIX 2: dnes pri účinnej hĺbke 150 a šírke 150 stredy 30 mm
    od seba pri priemere 50). Zohľadni predný sokel. Keď sa 2 odlišné pozície fyzicky nezmestia, nekresli prekryté valce — riešenie
    navrhni (napr. kresliť 1 valec + warning v pláne), **ale počet v nákupe ostáva podľa pravidla (2)** a uveď to v PR.
11. Testy: pásma, migrácia seedu (neupravené vs. upravené pravidlo), leg_stale v8, pozície nôh (x stred, rôzne y, plytká skrinka).

### Uzáver a brány
- VERSION patch 2× + `?v=` (form.js sa mení), STAV, KRONIKA, odseky architektúry (`cabinet_builder`, `scale_observer`, `hardware_rules`,
  `bom`), STANDARD §6 (nohy) a schémy, Grep tvrdení „200 mm" o šírke a „4/6 nôh" v docs (CLAUDE.md checklist).
- headless + **každá** JS sada zvlášť; **in-SU test povinný** (`scripts\run_su_tests.ps1 -CloseWhenDone`): postav dolnú 50 a 150 mm
  (2 nohy, pozície), hornú 50 mm, Mierka šírky na 50 mm, undo. Doplň in-SU scenár do sady, nie jednorazovo.
- Pred PR **nečakaj na predrecenziu sám** — po dokončení vráť orchestrátorovi vetvu + SHA (predrecenziu spúšťa orchestrátor); PR otvor
  až na pokyn. Trailer commitu = tvoj skutočný model.

## 2. Package a sonda orchestrátora (7.10.2026)

Trieda podľa Matice výberu: **Ť** (zmena schémy = audit-povinná; mení prípustný rozmer dielcov = výrobná). Hlavný profil `implementator`
(Opus high); shadow Sonnet high + Grok (limity voľné).

### Rozhodnutie Michala (7.10.2026)
Najmenšia **šírka** skrinky 200 → **50 mm** pre **dolnú aj hornú** (všetky typy BEZ vlastných `limits` v registri `CabinetTypes`).
Umývačka (`limits` 300–1200) a rohová (`min_valid_width` sonda) bez zmeny. Výška (80) a hĺbka (150) bez zmeny.

### Sonda na kóde (orchestrátor, 7.10.2026, headless, bez zápisu do modelu)
Dočasne `CabinetBuilder::MIN[:width] = 50`, `normalize` + `Construction.build_plan`:
- dolná/horná 50/80/100/150 mm, hrúbka 18 → plán prejde (`validate!` OK). 50 mm: boky 18, dno 50 (pod bokmi) / 14 (medzi), strop 14,
  chrbát overlay 50 / groove 14 → vnútro 14 mm.
- 50 mm s dvierkami, policami (2), vystuhami `two_rails` upright, chrbtom z list, soklom vpredu → všetko prejde.
- hrúbka 25/30/50 pri šírke 50 a 36 pri 60 → `RuntimeError "Sirka je prilis mala vzhladom na hrubku materialu."` (existujúca stráž
  `2t >= w`, ostáva — žiadny nový clamp hrúbky).

### Zmeny
1. `CabinetBuilder::MIN[:width]` 200.0 → 50.0 (+ komentár S1-E0 nad ním: šírka od 50 podľa rozhodnutia 7.10.).
2. `ScaleWatch::MIN['width']` (core/scale_observer.rb) → 50.0.
3. `ui/js/form.js` `LIMITS.width` → `[50,3000]` (+ komentáre „200" v okolí).
4. `Construction.min_valid_width` fallback `200.0` → zladiť (ideálne bez magického čísla).
5. **Nájdená nezhoda (oprav v tej istej dávke):** `ui/panel/actions_cabinet.rb` `front_preflight_result` — fallback rozsahy pre
   korpus `[200.0, 3000.0]` pre šírku AJ výšku. Výška má od S1-E0 minimum 80, preflight ju teda odmieta pod 200. Fallback odvodiť
   z `CabinetBuilder::MIN` (šírka 50, výška 80), horná hranica 3000 ostáva.
6. **`CONFIG_SCHEMA` 22 → 23** (precedens schémy 15 = S1-E0 výška 200→80): starší plugin (schéma 22) má `MIN[:width]` 200 a skrinku
   50–199 mm by pri prvej prestavbe **ticho rozšíril na 200** → iné dielce (dno, strop, chrbát, čelá). Brány tie isté ako pri 5–22
   (`newer_config?`, `ProductionCore.export_blockers`). Aktivačné konštanty (5/9/11/19/20) bez zmeny. Záznam do histórie schém
   v komentári `CONFIG_SCHEMA` + STANDARD tabuľka schém (§ riadok `CABINET CONFIG_SCHEMA`, dnes 22) + `docs/architecture/construction.md`.
7. Guard `tests/pure/test_s1e0_min_vyska.rb`: dnes fixuje šírku 200 („šírka a hĺbka sa nemenia") → upraviť na 50 a doplniť prípad
   50 mm dolná + horná (plán prejde) a 50 mm s hrúbkou 25 (zrozumiteľná chyba). Plus test schémy (vzor `test_r12_config_schema.rb`).
8. Uzáver kódovej dávky podľa CLAUDE.md (VERSION patch 2× + `?v=`, STAV, KRONIKA, odseky architektúry, Grep tvrdení „200" o šírke
   v docs/STANDARD/UI_DIZAJN/POJMY).

### Nálezy prerušeného auditu (gpt-6-astra, 7.10. 23:05 — limit) + rozhodnutia Michala
9. **Panel pustí šírku, ktorú stavba odmietne** (50 mm / hrúbka 20) → `form.js` krížová kontrola šírka vs. hrúbka (zrkadlo Ruby stráže
   `w <= 2t + 10` — `Construction.validate!` construction.rb:2109, overené 8.10.; audit r2 opravil pôvodné „2t >= w"; „Šírka je príliš
   malá vzhľadom na hrúbku materiálu"), červené pole hneď v paneli. Pri 50 mm teda prejde hrúbka najviac < 20 mm.
10. **Nohy pri úzkej dolnej skrinke** — pri 50 mm sa 4 nohy kreslia do 2 rovnakých polôh. **Michal 7.10.: úzka skrinka má 2 nohy
    v strede šírky** (vpredu + vzadu v osi), **v nákupe 2 ks**. **Michal 8.10.: hranica = šírka pod 200 mm → 2 nohy.** Počet nôh žije
    v pravidle kovania `nohy-zakladne` (pásma podľa šírky, hardware_rules.rb ~95–160) → nové pásmo < 200 → 2, seed v8 + migrácia,
    `Bom.leg_stale_issue`. **Delenie (orchestrátor 8.10.): PR A = šírka + panel + schéma, PR B = nohy; B hneď po A.** Prah, kedy 4 → 2, navrhne implementátor z geometrie nôh (keď by sa
    nohy prekrývali); výrobná zmena (kovanie/nákup) → in-SU + test počtu. **Audit r2 (8.10.):** over aj PLYTKÉ skrinky — zníženie
    4 → 2 nemusí samo odstrániť prekrytie (predná a zadná noha v hĺbke); rieši sa rovnakým pravidlom aj po hĺbke.

### Otázky pre audit
- Je bump schémy nutný a dostatočný (precedens 15)? Treba niečo pre šablóny / kópiu / Lucia na staršej verzii?
- Iné miesta, kde žije spodná hranica šírky (JS náhľad, ghost tool, rozdelenie zón `ZoneTree::MIN_FIELD`, Kontrola, sety kovania,
  šuflíky — recepty s min šírkou, závesy na úzkych dvierkach)? Rozbije niečo 50 mm, čo sonda neukázala (napr. vnútro 14 mm a zóny,
  Kontrola, VEPO export dielca 14 mm)?
- Má plugin úzku skrinku (napr. < 100 mm) len pustiť, alebo pri čelách/šuflíkoch hlásiť v Kontrole?

### Testy / brány
headless + všetky JS sady; **in-SU test povinný** (builder, scale observer): postaviť dolnú a hornú 50 mm, Mierka na 50 mm, undo.
Predrecenzia povinná (Ť). Codex-po-pr.

## 3. Implementácia — odchýlky a vedomé rozhodnutia

- **Hranica pásma úzkej skrinky = `max 199,999`** (`HardwareRules::LEG_NARROW_MAX_MM`): žiadny nový kľúč pásma (`min`, `max_exclusive`) — starší
  plugin by ho ignoroval. Šírka 199,9995 by dostala 4 nohy (vedomá hranica, šírky sú v praxi celé mm alebo desatiny). V editore Pravidiel sa pásmo
  ukáže ako „do 199,999 mm → 2 ks".
- **Mierka pod hranicu `validate!` (napr. 50 mm pri hrúbke 25) sa odmietne** — `reject_scale` vráti skrinku a hláška povie „Sirka je prilis mala
  vzhladom na hrubku materialu." (vzor D-120: neplatný Scale = rollback). Config-aware klamp šírky ostáva len pri rohovej. Pokus rozšíriť sondu
  na každý korpus (klamp na 61 mm) zmenil existujúce správanie in-SU scenára CELA-B (neplatný Scale s úzkymi dvierkami sa namiesto rollbacku
  klampol), preto sa nezaviedol — otázka pre Michala, či ho chce ako samostatnú dávku.
- **Polohy nôh = `Construction.leg_layout`** (čistá funkcia, builder len kreslí). Keď sa valce nezmestia (plytká úzka skrinka so soklom vpredu),
  kreslí sa ich menej a plán pridá info warning `legs_drawn_merged` (Kontrola ho nehlási — `BUILD_INFO_ONLY`); **počet v nákupe ostáva podľa
  pravidla**. Vedľajší dôsledok: plytká skrinka 200–269 mm so 4 nohami sa už nekreslí so štyrmi prekrytými valcami, ale s dvoma.
- **Golden H12 a H16 regenerované vedome** — rozdiel je výlučne `config_schema` 22 → 23, minimum šírky 200 → 50 (H12) a SHA `hardware_rules.json`
  (seed v8) a `templates.json` (schéma v šablónach) v oboch formátoch H16 (kompaktný variant odvodený transformáciou prázdnych kontajnerov, overenou
  na pôvodných SHA všetkých troch rozdielnych súborov).

## 10. Smoke (Michal)

1. Inspector: dolná skrinka šírka 50 → postaví sa, v modeli 2 nohy v strede šírky (vpredu a vzadu), v Nákupe 2 nohy + 1 príchyt sokla.
2. Dolná 150 → to isté; dolná 200 → 4 nohy ako doteraz.
3. Šírka 50 a hrúbka 20 (alebo 60 a 25) → šírka aj hrúbka zočervenajú s vetou „Šírka je príliš malá…", Aplikovať nič nezmení.
4. Horná skrinka 50 mm → postaví sa bez nôh.
5. Mierka: dolnú 600 stiahnuť na ~50 → skrinka 50 s 2 nohami; jedno Späť vráti 600 so 4 nohami. (Pri hrúbke 25 Mierka na 50 → hláška, skrinka ostane.)
6. Stará zákazka (pravidlá spred tejto verzie) + nová úzka skrinka → Kontrola ORANGE „…pred pravidlom 2/4/6 (šírka 150 → 2 nohy + 1 príchyt sokla)";
   po „Doplniť nové predvoľby" a prestavbe zhasne.
