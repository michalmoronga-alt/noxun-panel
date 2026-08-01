# Noxun Engine — roadmapa (živý dokument, aktualizované 2.8.2026)

> Princíp: **najprv všeobecný základ pre všetko, potom vyostrovanie.** Regenerate pattern robí konštrukčné zmeny lacnými — drahé je len meniť DÁTOVÝ MODEL (atribúty, identita, hrany), preto ten je uzamknutý štandardom vopred a detaily geometrie sa doladia iteráciami z klikania.

## Kde sme (2.8.2026)

- Plugin **v0.5.26** — v rámci V0.6 hotové: **2A (SCHEMA 2 skupiny + cutover, PR #89–#93)**, **2B (duplák #94 / zástena #95 — SCHEMA 3/4 lazy)**, **dávka B Demos lookup KOMPLET** (#96 core · #97 B-2a server s overením slug+parametre+výrobca a atomickým `apply_demos_batch`, **SCHEMA 5** = pohyblivá cenová cache · #98 B-2b UI „Aktualizovať z Demosu" v detaile dekoru), **dávka C katalóg kovania KOMPLET** (#99 C-1 server `HardwareCatalog` · #100 C-2 okno „Katalóg kovania") a **dávka M-A „Pridať z Demosu" KOMPLET**: **M-A1 server** (#101 — `DemosNameSearch` offline hľadanie v sitemap cache s memoizovaným indexom, `DemosFamily` rodina dekoru z 1 fetchu + all-or-nothing create orchestrátor, `Materials.create_group_from_demos` atomické založenie s kódmi/cenami s DPH/URL väzbami pod 1 zámkom, **SCHEMA 6** = `image_url` + `DemosImageCache` lokálna cache obrázkov, watchdog fix prvého sitemap refreshu), **M-A2 okno** (#102 — modal „Pridať z Demosu": jedno pole URL/názov so živými návrhmi, rodina Dosky/ABS/Mimo systému s čistým výberom a auto-návrhom 1 mm pásky, progres so Zrušiť, skok na detail; dlaždice s reálnou fotkou dekoru z lokálnej cache; **potvrdenie mazania s rozpisom** — Halifax lekcia; „ručne…" ostáva záložná cesta) a **M-B1 UNI pracovné materiály** (#103 — **SCHEMA 7** `uni`/`uni_role`: 5 UNI skupín Korpus·Čelo·Dekor2·HDF·Doska, hrúbku UNI dielca určuje DIELEC (doska aj 12 mm, pole v karte odomknuté), fresh seed natívne UNI + jednorazové doplnenie do existujúcich katalógov BEZ prepisu živých dát (marker `uni_seed.done`, rollback ho maže), ABS pre UNI zakázané server-side všetkými cestami (ensure/batch/formulár), semafor ORANGE „materiál neurčený" s potlačením ABS hluku vrátane uložených build warnings, odhad platní „(orientačne — UNI)", UNI bez nákupných polí; **P1 fix: guard „Vytvoriť pásku" porovnáva klienta so SCHEMA_GROUPS, nie s rastúcim markerom**).
- Testy: **751 headless + 603 JS v 16 sadách (CI na každý push) + ~140 in-SketchUp scenárov**.
- **M-A3a HOTOVÁ (PR #106, v0.5.21)** — opravy zakladania z Demosu zo smoke testu 1.8.: D-64 ABS pásky tretích strán (dekor sa dokazuje slugom mimo koncových rozmerov, brand check len dosky) · D-65 slug prefixy (analýza 47 956 slugov: +dtd-laminovana/mdfl/mdfs/kd-in/kd-ex/pracovni-deska/absl; jedna autorita klasifikácie; filter článkov bez číslic) · D-58 páska dedí štruktúru rodiny. Návrh cez Codex audit (2 BLOCKER zapracované: D-55 fallback identity zamietnutý, open-URL re-sanitize do M-A3b).
- **M-A3b HOTOVÁ (PR #108, v0.5.22)** — viditeľnosť väzieb: D-59 „už v katalógu“ podľa kódu (informatívne, nie zámok) · D-60 ikona väzby s dátumom + „Otvoriť u dodávateľa“ (URL len zo servera, re-sanitize — audit BLOCKER) + D-56 badge dlaždice · D-62 fotka v detaile · D-63 dvojriadkové názvy + tooltip · D-55 výrazný pás existujúcej skupiny.
- **M-A3c HOTOVÁ (PR #109, v0.5.23)** — editor variantov (BLOKERY smoke F8100): D-67 vlastný suggest dropdown namiesto CEF datalistu (mousedown, šípky/Enter/Escape, diakritika; typ, výrobca aj inline editor) · D-68 pruh „Formát výnimiek“ pre dopísané hrúbky — zástena 9,2 sa dá založiť; nová gramatika desatinnej čiarky (9,2 = 9,2 mm, koniec tichého rozpadu 9,20 → 9+20). **M-A3 KOMPLET.**
- **M-A3d HOTOVÁ (PR #111, v0.5.24)** — D-70: „Aktualizovať z Demosu“ číta uloženú väzbu (variant s demos_url priamo, match len pre nezviazané; funguje aj bez sitemap; zastaraná väzba = jasná hláška viditeľná v modáli — review fix) — mechanický základ „Prepočítať ceny“ dávky E.
- **M-A3e HOTOVÁ (PR #112, v0.5.25)** — D-71: pole „Demos URL“ v edit formulári variantu (ručné previazanie; sanitize, zmena/zmazanie ruší dátum overenia, UNI bez poľa; batch vedome bez URL — previaže sa editom po vytvorení). D-49 potvrdené Michalom (duplák automaticky — návrhová dávka pred/pri M-B2).
- **M-B2 HOTOVÁ (PR #114, v0.5.26)** — UNI viditeľnosť + „Nahradiť UNI…“: sekcia „Pracovné (UNI)“ navrchu katalógu (oba režimy) + UNI badge na dlaždici a v detaile; tlačidlo **„Nahradiť UNI…“** = hromadná zámena UNI za reálny dekor v CELOM modeli — server scan (explicitné roly korpusov, dielcové overridy, dosky, projektové predvoľby vrátane recyklovaných fallback ID) + čistá klasifikácia s rozpisom dopadu PRED potvrdením (počty skriniek/dosiek, prevzatia hrúbky, ABS remap so snapshotom overridov, chrbát vlastnou cestou — Codex audit 3B+4F+1N zapracovaný); potvrdenie viazané SHA256 odtlačkom plánu (zmena čohokoľvek medzi ponukou a potvrdením = čerstvá ponuka), all-or-nothing pri blokujúcich dielcoch, celá dávka = 1 undo (skrinky + dosky + predvoľby v jednej operácii). Ďalej zvážiť **D-66 zástena z Demosu** (mini dávka) a **D-49 duplák automaticky**; potom **D — mapovanie flagov kovania → zoznamy kódov setov** (⚠ pred D user-debata s Michalom; SET A kompletný 104717+106412+105408+105425), potom E (ceny v sumári + „Prepočítať ceny“).
- Ďalej: **V0.6 KOVANIE fáza 2** · UI 2.0 (OCL smer, D-50) · V1.0 zostavy.

## Hotové etapy (kompakt)

Plné pôvodné texty: [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

| Etapa | Hotové | Obsah v skratke | PR |
|---|---|---|---|
| V0.1 klikateľný základ | 15.7. | panel, dolný korpus z Ruby, police, dvierka, ghost zóny, 1-krok Undo | — |
| V0.2a jadro korpusu | 16.7. | scale→prestavba, konštrukčné varianty, horná skrinka | — |
| V0.2b členenie/čelá/šablóny | 16.7. | strom zón + priečky, čelá fixed/auto s lockmi, šablóny | — |
| V0.2c UX panela | 16.7. | 2D náhľad, auto-apply, tagy, osové scale, opravy | #2–#5 |
| V0.3 materiály a ABS | 17.7. | katalóg, dedenie projekt→skrinka→dielec, hrany L1/L2/W1/W2 | #6–#9 |
| V0.3.1–.3 stabilizácia dát | 17.7. | hrúbky, identita part_key, ABS 1/2 mm | #10–#12 |
| V0.3.4 stabilizácia pred kovaním | 17.7. | testy+CI, panel split, BuildPlan kontrakt, SU runner, undo fixy | #13–#21 |
| V0.4 kovanie fáza 1 | 18.7. | pravidlá fixed/bands/fit_series, projektový snapshot, overrides | #23–#26 |
| V0.4.5 Inspector + satelity | 18.7. | kontextový Inspector, náhľad zoom/pan/fit, satelitné okná | #27–#30 |
| V0.4.7 samostatná doska | 19.7. | kind board, ABS editor, scale absorpcia, výrazy v poliach | #31–#35 |
| V0.4.7 dogfood dávky | 19.–21.7. | D-01…D-40 (zápisník), režimové taby, hlavička+tokeny+ikony, MCP diagnostika | #37–#69 |
| V0.5 výstupy v0 | 19.–21.7. | kusovník, okno Výroba, VEPO CSV (validovaný 2-kolovo s OCL), odhad platní, semafor | #47–#65 |
| V0.5-E dekorové skupiny | 23.7. | šírka ABS + deterministický picker, dekor = kľúč skupiny, remap pri zmene materiálu | #70–#73 |
| V0.5-F dekorový katalóg UI | 24.7. | mriežka dlaždíc, kód+dodávateľ, cena „nezadaná", inline bunky s patch protokolom, preset-čipy | #74–#77 |
| **Uzáver V0.5** | 24.7. | verzia 0.5.0, hooky, docs reštruktúra + archív, hardening | #79+ |

## Pred nami

### V0.6 — KATALÓGY A CENY (štart 30.7. dávkou 2A)

**Pred 2A: D-46 — projektová predvoľba s inou hrúbkou (v0.5.4) — HOTOVÉ (PR #86, 30.7.)** — potvrdzovacia lišta Potvrdiť/Zrušiť namiesto tvrdého stopu; dediace skrinky prevezmú hrúbku v 1 undo kroku (návrh cez Codex audit 2B+5F+2N, 30.7.).

**Dávka 2A — identita variantov a skupín (dizajn cez Codex audit 6B+7F+2N, 30.7.; štandard §7.1/§7.5 aktualizovaný — SCHEMA 2). Verzie: 2A-1 = 0.5.5 a ďalej per PR:**
- **2A-0** dizajn do dokumentov (štandard, roadmapa, pojmy, migračná mapa) — *tento PR*
- **2A-1** jadro identity: `group_id` na doskách aj ABS, `structure`/`decor_name` polia, kanonické identity helpery (group/sheet/edge_identity_key — jedna normalizácia), register kanonických typov (dvojvrstvové typy — rozhodnuté 30.7.), PD formát v identite + mutabilita, nové ID generovanie (opaque kontrakt), catalog SCHEMA marker + nemenná záloha `materials.pre-schema-2.json`, `catalog_schema` guard mutácií
- **2A-2** migrácia — **HOTOVÉ (PR #89, 30.7., v0.5.6 — DORMANTNÝ engine, žiadna produkčná cesta ho nevolá; aktivácia až 2A-4)**: explicitná mapa (**SCHVÁLENÁ Michalom 30.7.** — zápisník „2A migračná mapa": zmazať osirotenú pásku „Pracovna doska" ✓, zlúčiť „Halifax Tabakový PD" do skupiny ✓) + heuristika len fallback s reportom, nerozhodnuteľná položka = atomický NO-OP celej migrácie (deterministický `group_id`, nemenná záloha, CAS kontrola), fixtures testy (replika živého katalógu) + SU scenár, kompatibilita starých modelov = zachovanie VŠETKÝCH nezmazaných ID + lookup test (starý .skp → BOM/validácia/rebuild/remap); navyše RED semafor `abs_missing` + `:schema_read_only` guard ensure cesty
- **2A-3** výberové cesty so štruktúrou — **2A-3a Ruby jadro HOTOVÉ (PR #90, v0.5.7; dual-mode: pri katalógu SCHEMA 1 sa správanie nemení, jediná vedomá výnimka AUTO_WIDTHS 22→23 globálne)**: schema-aware hrúbky ABS {0,4…2,0}, picker `abs_for_sheet` (skupina → presná NEPRÁZDNA štruktúra → `universal` → nič + strojový reason; NIKDY cross-structure, prázdna≠zhoda), resolver nominálnych tried (jednotka 0,8→1→1,2 · dvojka 2→1,5 s ORANGE upozornením · 0,4 nikdy automaticky — ani pri remape, reason `abs_04_manual`), warnings plumbing (resolve → plán → config → Bom.collect vrátane DOSKY → KONTROLA), remap so starým AJ novým sheetom (kontrast/cudzia štruktúra/nil nedotknuté), pick_body_sheet + back preflight so štruktúrnym guardom (schéma ako parameter), `ensure_edge_for_sheet` tvorí resolverom (hrúbka používaná skupinou, štruktúra dosky, universal sa nenastavuje). **2A-3b HOTOVÉ (PR #91, v0.5.8; dual-mode trvá)**: batch schema 3 — `decor` = číslo + `decor_name` + `structure`/`universal` per variant, kompatibilná matica server-side (katalóg 1 prijíma len batch 1/2, katalóg 2 len plne validný batch 3), skupina cez kanonickú identitu výrobca+číslo (existujúca preberá `group_id`, nová deterministicky `group_id_for` — dosky aj pásky dávky sa stretnú v jednej skupine), universal konflikt = chyba celej dávky; JS zrkadlo — `catalog_schema` v materials_payload (+`group_id`/`structure`/`universal` na záznamoch), absUsableExists/absModal podľa hierarchie skupina→štruktúra→universal s triedou jednotka {0,8;1;1,2}, filter Odporúčané = presná štruktúra + universal (cudzia štruktúra skupiny do „Ostatné"); `ensure_edge_for_sheet` pri doske bez štruktúry tvorí pásku s `universal: true` (§7.5)
- **2A-4** cutover katalógu + UI — rozdelené po Codex audite cutoveru (NO-GO 4B+7F, 31.7.): **2A-4a server hardening HOTOVÉ (PR #92, v0.5.9; dual-mode trvá — bez behu `assess_catalog!` sa správanie nemení a katalóg sa neprepína)**: stavový aparát katalógu (:ok | :read_only — hybrid marker 2, novšia schéma či poškodený JSON zamknú mutácie priamo v zápisovej ceste, čítanie beží ďalej), obnova primáru z `.bak` (chýbajúci aj poškodený primár; torzo sa odkladá bokom), seed len pre skutočne panenský stav, `restore_pre_schema2!` (otestovaný rollback: aktuálny súbor sa odloží ako `materials.rolledback-*`, nasadí sa predmigračná záloha, jednorazový `migration_hold.json` zabráni okamžitej re-migrácii pri ďalšom boote), skupinové operácie cez `group_id` (rename/výrobca/usage — text len jednoznačný fallback; dve skupiny s rovnakým číslom dekoru sa nemiešajú), `patch_record` atomicky pod zámkom nad čerstvým diskom, `:conflict` migrácie reklasifikovaný (cudzia hotová schéma 2 = `:already`; stále legacy = 1 retry celej transformácie) · **2A-4b OSTRÝ CUTOVER — HOTOVÉ (PR #93, 31.7., v0.5.10; koniec dual-mode defaultu — seedy aj boot sú SCHEMA 2)**: `boot_cutover!` pri každom štarte (vlastný chránený blok mimo hlavnej inicializácie, žiadny messagebox — log + banner v okne Materiály; hold flag po rollbacku migráciu RAZ preskočí; `:undecidable` = katalóg beží ďalej legacy dual-mode BEZ zámku mutácií; hybrid/poškodenie = read-only), seeds natívne schema 2 (K009→PW, W1000→ST9+`Biela`, HDF bez štruktúry; `group_id_for` parita s migráciou; universal seedy NIE — O3), MD_CLIENT_SCHEMA 2 + batch UI v3 (číslo+názov+výrobca+štruktúra per variant+universal checkbox; textové výnimky parsuje klient do štruktúrovaných variantov), karta skupiny (dlaždice podľa `group_id` — rovnaké číslo dvoch výrobcov = 2 dlaždice; detail so sekciami per štruktúra; universal toggle cez `patch_record` s F7 vetvami), banner nepoužiteľných pások (server-side count pri každom refreshi) + read-only banner s tlačidlom „Obnoviť predmigračnú zálohu" (modal), štruktúra v labeloch + výrobca LEN pri kolízii čísla (VEPO exportný label NEMENNÝ — zlatý bajtový test; štruktúra len v LOG display labeli), **D-47** hlavička panela (3 taby rovnako široké s ikonami + Materiály·Výroba rovnako široké, pod 400 px icon-only)
- Verzie: D-46 = 0.5.4 · 2A-1+ = 0.5.5 a ďalej per PR; **0.6.0 až pri uzávere celej etapy V0.6**

**Ďalšie dávky V0.6 (po 2A):**
- **2B-1 duplák — HOTOVÉ (v0.5.11, PR #94, 31.7.)** — D-43: variant „zdvojený zo zdroja" (`source_material_id` + násobič 2–3, všetko ostatné derivované zo zdroja a nemenné, bez nákupných polí); väzba vo výrobnom snapshote (`config.material_source`, carry-over pri rebuilde bez katalógu); odhad platní prelieva plochu ×násobič do zdroja (`doubled_m2`), kusovník/VEPO bez zmeny; katalóg SCHEMA 3 LAZY (staré plugin verzie od prvého dupláku read-only); UI: tlačidlo vrstvičiek pri DTDL/MDF doske + riadok väzby v detaile. Návrh cez Codex audit 2B+10F+1N (31.7.) — batch čip „+duplák" vedome odložený (pridá sa, ak si ho dogfooding vypýta).
- **2B-2 zástena — HOTOVÉ (v0.5.12, 31.7.)** — dva dekory líce/rub: `back_decor`+`back_structure` vo variant identite (po vyplnení nemenné, first-fill prázdnych na legacy záznamoch s dup kontrolou); formát v identite aj pre zástenu cez register flag `format_in_identity` (PD+Zástena, jeden helper na všetkých identity miestach — kľúč, edit guard, batch parse/dedup, ID generátor, VEPO disambiguácia); rub v VEPO labeli („K551 RT ZASTENA /K552"); back polia len pre typ zástena (server); katalóg SCHEMA 4 LAZY pri prvom rube (bump podľa OBSAHU centrálne v zápisovej ceste). Audit nálezy F10–F12 z 2B auditu zapracované.
- **B** Demos lookup — **rozhodnuté 31.7. (živý prieskum + Michal):** sitemap cache (47 958 URL) → match slugu podľa identity variantu → fetch produktu (Crawl-delay 3 s, allowlist) → Ruby parser (HTML fixtures v testoch) → diff&apply; „Súvisiaci sortiment" naplní celú dekorovú skupinu z 1 fetchu; `/vyhledavani` sa NEpoužíva (robots.txt) — „zadaj kód" rieši paste URL fallback. **Zmeny Michal 31.7. večer: ceny S DPH ako Demos (prepínač s/bez v sumári — staré „bez DPH" rozhodnutie zrušené) a ceny sú POHYBLIVÁ CACHE** (katalóg drží kód+URL+posledná cena s dátumom; „Prepočítať ceny" v zákazke = dávka E, mechanika fetchu = B) · **C** kovanie katalóg (koncepty z KOVANIE na ENGINE infraštruktúre: položky, search; ceny **S DPH** ako Demos — zosúladené so štandardom §7.1, pôvodné „bez DPH" tu bolo zastarané; use_count odložený do D — audit C; **bundles NESKÔR** — Michal 31.7., sety = mapovanie v D) · **D** mapovanie flagov→kódy (pamätá sa; vzor hardware_rules) · **E** ceny v sumári = prvá kompletná cenová ponuka (materiál+ABS+kovanie+sadzby; **montáž = count_max zaokrúhlený NAHOR na celé platne × 5,8 × sadzba, prepísateľné reálnym nákupom** — Michal 31.7.; **sadzby služieb: globálne „Nastavenia dodávateľa", NEmrazia sa do zákazky, architektúra na viac dodávateľov** — Michal 31.7.)
- **Seed 2.0:** knižnica z najobjednávanejších materiálov z Gmailu (po 2A migrácii)

- Prevzatie CatalogStore/search/Demos import z KOVANIE · mapovanie flagov na konkrétne kódy (pamätá sa) · ceny v sumári.
- **Otvorená otázka (debata 24.7., rozpracovať pred štartom):** „zadaj kód → načítaj dáta" — demos-trade.sk má verejné vyhľadávanie (kód → 1 položka aj dekor → celá skupina s cenami bez loginu) + Konfigurátor cenníkov na Démos24Plus (hromadný export za loginom). Zvážiť hybrid: hromadný seed z cenníka + per-kód dohľadanie. Viď zápisník uzáveru. *(Pozn. 29.7.: /vyhledavani je v robots.txt disallowed — lookup pôjde cez produktové stránky.)*
- **Knižnica z reálnych objednávok (Michal 30.7.):** po napojení Gmailu vytiahnuť z mailov NAJOBJEDNÁVANEJŠIE materiály a postaviť ostrú knižnicu podľa nich (aktuálny katalóg je len testovací — migrácia 2A ho smie pokojne preskladať). Zaradenie: seed 2.0 po 2A migrácii.
- **Pracovné dosky ako súčasť dekorovej skupiny** (Michal 24.7.): rovnaké dekory, iný rozmer/typ (PD 4100×600/920/38, HPDB hrana š.45, DTDL 36 = 2× zlepená 18) — dátovo pripravené cez `sheet_variants` s typom per variant (D-42); doriešiť pri katalógu.
- Z prenesených záväzkov zvážiť: smer otvárania + typ závesu, hmotnostné tabuľky, „použiť na podobné" pre kovanie.

### V0.4.8 — Konštrukčné možnosti z 06 (otvorená, neplánovaná)

Zostávajúce zadanie z [06_PANEL_NASTAVENIA_navrh.md](06_PANEL_NASTAVENIA_navrh.md): rohové spoje dna/stropu per strana (vľavo/vpravo vložené/naložené) · chrbát s poldrážkou · „bez dielca" varianty (bez boku/dna/stropu — otvorené niky s validáciou) · per-dielec hrúbky a odsadenia (vpredu/vzadu). *(Medzery/presahy čiel z pôvodného rozsahu sú hotové — D-07 + D-22.)* Zaradenie rozhodne Michal (kandidát: po V0.6).

### V1.0 — Zostavy a stabilizácia

Spájanie/zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, rohové situácie — snaper logika) · **soklová lišta v celku pre celý segment** · **obklady a krycie prvky segmentu**: pilastre (priznaný/skrytý + rýchly nástroj), pracovné dosky a horné krycie dosky na pár klikov na označený segment · ABS vizuálny režim (farebné hrany, klik-edit) · migrácia/oprava starých modelov · test na kompletnej reálnej zákazke.

### Neskôr (po V1)

Zásuvkové bloky (dočasne DC Atira most) · vnútorné vybavenie (koše, tyče…) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy/etikety · CNC · injecting dát do knižníc v dávkach (kódy, materiály, kovania, spotrebiče — architektúru pripraviť skôr).

## Prenesené záväzky (z uzavretých etáp — nestratiť)

- **Seed reálnych dekorov** do katalógu dodá Michal pri testovaní D-42 (zoznam materiálov pripravuje — debata 24.7.).
- **V0.4 odložené kovanie témy:** hmotnostné Blum tabuľky (chýba hustota materiálu) · smer otvárania a typ závesu (naložené/vložené/tip-on) · automatika počtu nôh podľa šírky (zmena JSON pravidla). → zvážiť vo V0.6.
- **„Použiť na podobné"** (odstránené PR #14) — vráti sa premyslené až s kovaním (V0.6+).
- **V0.4.7 vedome neobsahuje** (→ V1.0 zostavy): attachment/segmenty, automatické krycie dosky, pracovné dosky cez segment.
- **Nárezový plán fáza 2** (guillotine, kerf, orezky, orientácia dekoru): OpenCutList je GPL (kód neprebrať, algoritmus áno); D-19 kontrakt pripravený (vstup = dielce). → po V0.6.
- **Redo správanie zlúčených operácií** — Ruby API nemá na Windows spoľahlivú redo akciu; manuálne overiť Ctrl+Y pri hardeningu (otvorené pozorovanie zo 17.7.).

## Pravidlo pre postrehy (Michal)

**Píš postrehy HNEĎ, keď ich vidíš — hocikedy, hociktorú tému.** Nemusíš strážiť, čo je kedy v pláne — ja každý postreh zaradím: buď do bežiacej etapy (ak sa týka), alebo do backlogu nižšie s označením etapy. Nič sa nestratí. Krátka veta stačí („boky majú stáť na dne, nohy pod tým") — doplňujúce otázky si vyžiadam sám.

**Triedenie hlásení (dohoda 25.7.):** bežiaca etapa · priebežné dopĺňanie · celková vízia · **odklad do V1** — kým sa k V1 dostaneme, zbierame dáta, a z odložených tém sa potom poskladajú ďalšie bloky V1–V2. Trvalé fakty domény (stolárske poznatky, pojmy) idú do [09_POJMY.md](09_POJMY.md).

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.

## Backlog postrehov (otvorené)

Vyriešené riadky sú v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md); operatívne postrehy z dogfoodingu žijú ako D-čísla v [08_DOGFOODING.md](08_DOGFOODING.md).

| Dátum | Postreh | Zaradenie |
|---|---|---|
| 15.7. | Spájanie korpusov: zarovnanie čelných hrán (default), voliteľne zadných; pripájacie body; rohová sa nepája na rohový styk | V1.0 zostavy (štandard otvorený bod 7) |
| 15.7. | Rohová a vysoká/potravinová skrinka ako nové TYPY builderov | po V1.0 (odvodia sa od dolnej/hornej) |
| 16.7. | **Pilaster** (bočná krycia/obkladová doska): skrutkuje sa zvnútra, zakrýva biely korpus a spoje; variant **priznaný** vs. **skrytý** (čelá presahujú); ideálne rýchly nástroj | V1.0 zostavy — obklady segmentu; rola `pilaster` do štandardu pri implementácii |
| 16.7. | **Pracovné dosky + horné krycie dosky**: vloženie na pár klikov na OZNAČENÝ SEGMENT (cez viac skriniek, ako soklová lišta) | V1.0 zostavy; production_class sheet, dĺžka zo segmentu; katalógová stránka PD sa rieši už vo V0.6 (dekorové skupiny) |
| 16.7. | Zóny priamo vo viewporte (variant B vízie) — nadstavba 2D náhľadu | neskoršie verzie (A = 2D náhľad hotový) |
| 16.7. | **Stráž kolízií** — diely sa prekrývajú / vyskočia mimo box → upozorniť kde a prečo | validačná vrstva semaforu (bbox check dielcov zatiaľ neimplementovaný) |
| 16.7. | **Interact pre čelá**: dráhy otvárania, klik = otvorenie, merač kolízií pri otvorení — prezentácia, kontrola | po V1.0 (dáta máme: origin čiel na hrane pántu; premyslieť pri kovaní — typ pántu = dráha) |
| 16.7. | Náhľad povýšiť na „otvárací náhľad" panela so zobrazovaním zvolených elementov | neskoršie verzie — [07_UI_VIZIA.md](07_UI_VIZIA.md) |
| 16.7. | Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zle funguje | odložené — rieši sa s knižnicou/editorom typov |
| 17.7. | Redo po zlúčených transparentných operáciách overiť manuálne (Ctrl+Y) | hardening uzáveru V0.5 (viď prenesené záväzky) |
| 19.7. | Injecting dát po V1: kódy, materiály, kovania, spotrebiče, vybavenie do knižníc v dávkach — dovtedy pripraviť architektúru | po V1.0 — plán napĺňania knižníc (súvisí s Demos konektorom V0.6) |
| 20.7. | Nárezový plán fáza 2 (guillotine, kerf, orezky, orientácia dekoru) — vlastná heuristika v čistom Ruby | po V0.6 (D-19 kontrakt pripravený) |
