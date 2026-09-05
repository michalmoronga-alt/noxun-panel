# KOV-C — Codex audit návrhu pred implementáciou (5.9.2026, checkpoint #18)

> Stav: KONCEPT / audit checkpoint — nie implementačný spec. Codex CLI `codex exec` **gpt-6-astra** (prvé nasadenie Astry na KOVANIE; ~139 k tokenov) nad package KOV-C v `SYSTEM/PLAN.md`
> + FINAL §3/§4/§6 + dátový draft #13 + kód `construction.rb`, `hardware_rules.rb`, `build_plan.rb`, `cabinet_builder.rb`, `fronts.rb`, `hardware_sets.rb`, `materials_*`; dôkazy pripnuté na main `6f8b645` (v0.9.28).
> Prompt: `scratchpad/audit_kovc.md` (rola devil's advocate, 2 explicitné auditné otázky: definícia `clear_depth`, rez C2). Výsledok: **6 BLOCKER · 3 FIX-IN-C1 · 3 FIX-IN-C2 · 2 NOTE (odpovede)**.
> Reconcile orchestrátora nižšie; zapracované do package KOV-C v PLANe (verzia 2, 5.9.2026). Kolo 2 (Sol) nad verziou 2 = samostatný záznam nižšie.

## BLOCKERY + rozhodnutie orchestrátora

1. **C2 môže objednať nesprávny systém bez upozornenia** — `code_by_nl` kontroluje len NL (`hardware_sets.rb:2101`); recept Atira H176/NL470 prejde setom H70 a objedná `357696`. → **ROZHODNUTÉ (C2b):**
   už C2 overuje kompatibilitu vybraného setu so VŠETKÝMI rozhodujúcimi osami receptu (`system`, `height_variant`, `nominal_length`, `load`, `opening`) proti klasifikácii setu a jeho členom; neoveriteľný
   alebo nesúhlasný set = ORANGE `set_incompatible` + **tvrdá nákupná brána** (nákup CSV / rozpočet / CP zastavené, VEPO nie). Plné ovládanie výberu (per-height sety, defaulty) ostáva KOV-D.
2. **`plan_schema` bump neochráni zákazku pri downgrade** — guardy kontrolujú `config_schema` (`cabinet_builder.rb:518/549`); starší plugin by prestaval skrinku, zahodil dielce a obnovil legacy výsuv.
   → **ROZHODNUTÉ (C2a):** bump `CabinetBuilder::CONFIG_SCHEMA` 4 → **5** s prenosom nových polí (`drawer.recipe`, `drawer_recipes` závislosti) cez `normalize`, zápis, kópiu a šablóny; forward-version
   odmietnutie ako doteraz; výnimka „VEPO neblokovať" platí LEN pre drawer konflikty v podporovanej verzii, nikdy pre novší config. `PartKeys::SCHEMA` sa nebumpuje (tvar `front:<id>/<rola>` existuje).
3. **Vstupná klasifikácia nevie pomenovať recept** — čelo drží len `drawer.construction` (`metal|wood|other`), `variant` (`standard|internal`), `opening_mode` (`classic|tipon`); `norm_drawer` ostatné zahodí
   (`fronts.rb:497`). → **ROZHODNUTÉ (C1 kontrakt, C2a persistencia):** záväzná mapa klasifikácia → kľúč receptu: `construction metal → system atira` · `wood → quadro_v6_eb23` · `other → BEZ receptu`
   (legacy cesta, CONTENT-identická, žiadne dielce ani R2 potlačenie); `opening_mode classic → sisy` · `tipon → p2o` (**P2Os vyhodené úplne — Michal 5.9.2026: „ešte som sa nestretol s P2Os; pre výsuvy aj závesy ostávajú len 2 typy: Tip-On a tlmenie (SiSy), tretí variant neriešiť"**); `variant internal → tvrdý conflict `drawer_internal_unsupported`` (FINAL §3); `runner_variant` z KD korpusu (`eb_by_kd`), piny `mounting: slide_on`, `rear_type: wooden`.
   Kľúč receptu sa **persistuje per čelo** ako `drawer.recipe = {system, runner_variant, mounting, rear_type, recipe_version}` pri stavbe (C2a, CONFIG_SCHEMA 5); čiastočná klasifikácia (chýba
   construction alebo opening) = bez receptu + ORANGE `drawer_unclassified`; dormant drawer polia na dvierkach sa ignorujú (DORMANT_KEYS).
4. **Zrkadlo `ensure_project_rules!` porušuje fail-closed** — poškodený JSON = „chýba" → prepis globálnou predvoľbou (`hardware_rules.rb:324`); pri receptoch by rebuild zmenil výrobné rozmery.
   → **ROZHODNUTÉ (C1):** snapshot má 5 stavov **chýbajúci / platný / poškodený / novší / neúplný**; automatický seed LEN pri skutočnej absencii pri inicializácii projektu (prvá stavba drawer čela
   v projekte, vnútri operácie buildera); poškodený/novší/neúplný = žiadny fallback, žiadny zápis, RED `drawer_recipes_invalid` + tvrdá brána; `Recipes.resolve` dostáva **explicitne podaný
   validovaný snapshot** (nie `load(system)` z disku); povinné testy: poškodenie, novšia schéma a Undo prvého vloženia nikdy nespustia tiché preseedovanie pri čítaní/exporte.
5. **Šablóna s inou verziou receptu nemá bezpečnú cestu** — šablónový whitelist recepty neprenáša (`payloads.rb:531`); Atira v2 v šablóne vs v1 v projekte. → **ROZHODNUTÉ (C2a):** pravidlo kolízie =
   **fail-closed odmietnutie**: šablóna nesie svoj snapshot receptov (`hardware_recipe_defs` per systém, bezstratovo cez `assess_*` vzor setov); pri vložení sa porovná s projektovým snapshotom TOHO ISTÉHO
   systému — zhoda = OK, rozdiel = vloženie odmietnuté PRED akoukoľvek operáciou s hláškou „recept X v šablóne (v2) sa líši od projektu (v1) — zlúč recepty explicitne" (`merge_recipes_seed!` UI = KOV-D);
   projekt bez snapshotu preberie šablónový. Ghost session nesie závislosti; zlyhanie/Undo vráti snapshot aj stavbu spoločne (jedna operácia). Verzované identity (system@version) = NIE v V1.
6. **Sync tyč P2O sa odkladá spolu s bránou** — dátový draft ju pri širokých zásuvkách vyžaduje. → **ROZHODNUTÉ (C2b):** s prvou aktiváciou receptu P2O prichádza **detekcia povinnej súčasti**
   (`extras.sync_shaft.trigger`: šírka > `sync_rod_min_width` receptu AND opening = p2o) a **tvrdá nákupná brána** RED `drawer_sync_rod_missing`, kým položka nie je v nákupe; dĺžková položka
   a oceňovanie (R-06a) ostávajú KOV-D.

## FIX-IN-C1 (prijaté)

7. **Akceptačné čísla odporovali resolveru** (175 mm čelo nedosiahne H144 = 189; hĺbka 560 s 3 mm chrbtom = 557 → NL520; 900/KD18/EB10,5 → BB 791,5 a RB 780; hĺbka 300 = SiSy NL260 sedí).
   → Fixtúry = PLNE zadané konfigurácie (KD, chrbát, výška riadku), očakávané hodnoty odvodené zo vzorcov/tabuliek bez zaokrúhľovania na celé mm; smoke prepísaný (viď package).
8. **Hrúbky dielcov sú vstup geometrie** — builder tvorí plán PRED vyriešením materiálov a `part_overrides` (`cabinet_builder.rb:661/715`); `materialized_part` mení os Y (vonkajšie čelá). → C1 definuje
   vstup `part_thicknesses` (per rola; default z kanála `:drawer`, override z `part_overrides`) a prípustnosť zmiešaných hrúbok (Atira: dno aj chrbát 16; Quadro: boky/dno/predok/chrbát v
   `thickness_supported`, override mimo = conflict); C2 rieši hrúbky PRED plánovaním; `materialized_part` sa NEpreberá — nový čistý `drawer_part` bez posunu do −Y.
9. **Validácia packu je slabá** → C1 validuje: úplnosť DEKLAROVANÝCH kombinácií (každá `nl × opening × load` v `availability` má bunku v `min_depth` a `loads_by_nl`), odkazy medzi tabuľkami, konečné
   čísla, kladné rozmery; výber prebieha nad KOMPATIBILNÝMI kombináciami (nie najdlhšia NL a potom zistenie, že opening ju nepodporuje); emisia dielcov ATOMICKÁ (všetky alebo žiadny — dnešné
   vyradenie degenerovaného dielca v `construction.rb:66` nesmie nechať neúplný box s kovaním).

## FIX-IN-C2 (prijaté; zaradenie do rezu)

10. **Migrácia legacy overridov** (`disabled` + `quantity` na `vysuvy-nl-podla-hlbky`; `disabled` dnes položku odstráni) → C2b: `disabled` na drawer čele so systémom = conflict `drawer_override_disabled`
    (nikdy tiché zahodenie), `quantity ≠ 1` = conflict; kolízia legacy + existujúceho recipe zámku = conflict; zmena systému (metal ↔ wood) = zámky NL sa znovu validujú proti novému radu. **Server**
    (`actions_hardware.rb:31/78`) odmieta `quantity`/`disabled` mutácie pre `rule_id` `recipe:*` (read-only os) — test: jedna položka, množstvo 1, platný owner, odmietnutie na serveri.
11. **Jednotné mapovanie konfliktov → brána** → C2b: KAŽDÝ drawer conflict kód je v jednom registri `DRAWER_BLOCKERS` (`drawer_no_fit`, `drawer_thickness_unsupported`, `drawer_obstruction`,
    `drawer_internal_unsupported`, `nl_lock_invalid`, `drawer_override_disabled`, `drawer_recipes_invalid`, `set_incompatible`, `drawer_sync_rod_missing`) a `export_blockers` ho číta celý; exportný
    preflight = **čistá cesta nad projektovým snapshotom** (`Recipes.preflight(model)` bez `ensure!`, zápisu či opravy modelu) — dnešný „čerstvý zber" len číta uložené `hardware`/`front_items` (`bom.rb:106`).
12. **UNI/ABS seed upgrade** → C2a: samostatná idempotentná migrácia `ensure_drawer_uni!` (nie cez `ensure_uni_records!`, ktorý končí pri `uni_seed.done`), ochrana pred kolíziou ID, `UNI_ROLES` +
    `drawer`; ABS seed `SEED_VERSION` bump s presným mapovaním hornej dlhej hrany na os každého nového dielca; UNI = neurčený materiál bez auto-ABS → smoke „Kontrola bez nálezov" používa reálny dekor.

## NOTE — odpovede na auditné otázky

13. **`clear_depth`** = vnútorná použiteľná hĺbka = `interior[:back_front_y]` (montážna rovina Y = 0; hrúbka a odsadenie chrbta už odpočítané). Vendor rezervu (Atira KT, Quadro NL+13) **neodpočítať
    druhýkrát** — `min_depth` tabuľka sa porovnáva priamo s `clear_depth`. Kontrakt v schéme: „vzdialenosť od montážnej roviny po prednú plochu zadnej prekážky" (`interior_depth`); hraničné testy
    samostatne per režim chrbta × opening. Zdroje: Hettich Atira montážne rozmery (bk_555), Quadro EB23 montážny list (MTA_929680300).
14. **Rez C2** = **C2a** (materiálový kanál `:drawer`, deskriptory/roly/ABS, persistencia `drawer.recipe` + CONFIG_SCHEMA 5, šablónová kolízia, UNI migrácia — produkčný hook NEAKTÍVNY, výstupy
    CONTENT-identické) → **C2b** (naraz: aktivácia dielcov, jedna kompatibilná slide položka + kompatibilita setu, migrácia zámkov, sync tyč, všetky tvrdé brány; exit = in-SU zmena rozmerov +
    Undo/Redo, conflict → návrat s obnovenými overrides, kópia `*2`, šablónová kolízia, export bez súborov pri blokáde). Samostatné „dielce + materiál" s pôvodným nákupom = NIE (nekonzistentná zákazka).

## Rozhodnutia pre Michala (predvolené; môže vetovať)

- ~~P2Os v V1 nedosiahnuteľný, dáta ostávajú~~ → **ROZHODNUTÉ (Michal 5.9.2026, voľba A): P2Os sa z dát AJ z návrhu vyhadzuje úplne** — pre výsuvy aj závesy existujú len 2 typy otvárania (Tip-On = P2O, tlmenie = SiSy); vendor riadky P2Os v #10/#13 sú označené ako NESCHVÁLENÉ pre Noxun.
- **Kolízia receptov šablóna vs projekt = odmietnutie vloženia** s hláškou (explicitné zlúčenie v KOV-D), nie tichý prepis ani verzované identity.
- **Smoke čísla:** skrinka 900×720×**500** (KD 18, chrbát naložený) + čelo 175 → H70 (chrbát 65,5), NL470; dno 791,5×480, chrbát 780×65,5; hĺbka **250** → RED bez riešenia (NL260 potrebuje 279).

## Kolo 2 (Sol, 5.9.2026, nad verziou 2 `10ef736` + P2Os `07011bf`) — ZAPRACOVANÉ (verzia 3)

Kolo 1: **8/14 RESOLVED**, 5 PARTIAL (6 identita sync tyče · 7 Quadro smoke · 9 validácia bez výškovej osi · 10 remap `recipe:<old>` · 12 ABS hrany), **1 UNRESOLVED** (1 sety nenesú
system/height/load). **Nové: 3 BLOCKER** — (B1) natívne Copy/Paste medzi `.skp` dokumentmi stráca pôvod receptu → `recipe_digest` v configu, porovnanie so snapshotom cieľa, nezhoda = RED
`drawer_recipes_mismatch`; (B2) autorita `drawer.recipe` = SERVER (nanovo odvodené pri každej prestavbe, klient recept neprenáša); (B3) Quadro nemá `height_variant` → systémovo odlišná
výšková os (Atira variant, Quadro numerická `box_height` = clear − 40). **3 FIX** — (F4) úplný tvar slide položky (`owner_part_key front:<id>/panel`, quantity 1, rule_quantity, production_class,
manufactured, source recipe); (F5) hranice bez predčasného zaokrúhlenia (EPS 0,01 mm, nezaokrúhlená geometria); (F6) Quadro smoke: SKW = šírka dna/predku/chrbta, boky = NL × box_h.
**Reconcile:** #1 → C2a rozšíri klasifikáciu setov o voliteľné `height_variant`/`load` (sparse, len drawer), C2b overuje set cez construction/opening/manufacturer/series (+ Atira výška, load),
chýbajúca os = neoveriteľný → brána; #6 → recept emituje položku `sync_shaft` (`recipe:<system>:sync_shaft`, `cut_length`), nemapovaná = RED; #9 → validácia nad všetkými osami systému;
#10 → premapovanie `recipe:<old>` → `recipe:<new>` ak NL v rade; #12 → `L1` = horná dlhá hrana pre box_side/inner_front/back, dno bez. Odpovede na auditné otázky potvrdené (clear_depth, rez C2a/C2b).
Kolo 3 (Sol) nad verziou 3 = ČAKÁ.

## Kolo 3 (Sol, 5.9.2026, nad verziou 3 `9d3e00b`) — ZAPRACOVANÉ (verzia 4)

Kolo 2: **6/11 RESOLVED**, 5 PARTIAL. **6 nových BLOCKER (presnosť kontraktu):** (1) `drawer_recipes_mismatch` chýbal v registri → doplnený; (2) čiastočná klasifikácia bola ORANGE (fail-open) →
RED `drawer_unclassified` v registri; (3) `source: recipe` by BuildPlan odmietol a D-93 mení source na manual → enum rozšírený o `recipe`, zámok = `locked: true` (pôvod ≠ zámok),
`rule_nominal_length` povolené; (4) `sync_shaft` bez validného tvaru → nová enum hodnota, úplný tvar, `cut_length_mm` (`LENGTH_PARAM`) = dĺžková položka; (5) `recipe_digest` nad celým
validovaným záznamom (SHA-256 kanonickej serializácie); (6) dôveryhodná cesta receptu → `Fronts.stored_recipe(raw)` pred normalizáciou + `Fronts.write_recipe!` po resolveri. **2 FIX:** (7)
`context_for` z nezaokrúhlených zón (`raw_bounds`); (8) `materialized_part` sa pre drawer roly nepoužíva (rozpor C1/C2b odstránený). Residual: do KOV-D sa set vyberá len cez owner/generic
mapovanie (C2b smie zablokovať, nikdy ticho priradiť H70); reálne in-SU testy povinné (kópia medzi dokumentmi, seed + Undo, part_overrides, duplikáty). Kolo 4 (Sol, záverečné) = ČAKÁ.
