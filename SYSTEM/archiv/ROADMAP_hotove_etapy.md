# Roadmapa — archív hotových etáp (plné texty)

> **ARCHÍV (založené 24.7.2026 pri uzávere V0.5).** Kompaktné riadky hotových etáp drží [KRONIKA.md](KRONIKA.md) (časová os) — tu sú plné pôvodné texty (história rozhodnutí, rozsahov a PR). Otvorené záväzky z týchto textov sú od 11.8.2026 zaradené do blokov [../PLAN.md](../PLAN.md) — tento súbor je čisto referenčný.

## BALÍK ČIEL — UZAVRETÝ (11.9.2026, v0.11.0, PR #347 + #349 + #350 + #351)

**Rozsah, mockup aj implementácia schválené 11.9.2026.** ČELÁ-A zlúčené (PR #347, v0.10.6); sekvenčné dávky ČELÁ-A → B1 → B2 → C.
Pôvodný PR #348 sa po treťom kole nálezov uzavrel a rozdelil podľa pravidla repozitára. Rozsah ani schválené správanie sa nemenia.
**B1 (#349, v0.10.7, zlúčené):** geometria, schéma 13, profily piatich typov, výroba/seed a čistenie neaplikovateľných seed zásahov; minimálny prenos hrany a náhľad.
Overenie B1: 3826 headless, 112 JS sád, in-SketchUp 2295 PASS / 0 FAIL, skutočný Inspector zachová hranu pri editácii výšky.
**B2 (#350, v0.10.8, zlúčené):** per-čelo aj hromadné ovládače, čítací callback, potvrdenie návrhu, všetky relaye a ich odmietacie odpovede. Overenie: 3830 headless, 113 JS sád, 2297 in-SU PASS a Inspector pri 470 px. Undo/Redo refresh zruší čakajúci návrh; abort vlastného apply naďalej chráni novší edit. Každá časť má vlastné testy/review a začína z čerstvého mainu.
**Audit ÁNO** pre A/B (config, geometria, profilový kontrakt a čítací callback); C je UI.
Podklad: [outside-in a reconcile](../zdroje/next_sessions/CELA_OUTSIDE_IN_2026-09-11.md).
Kontrola návrhu: [Astra audit a SOUND delta](../zdroje/next_sessions/CELA_AUDIT_2026-09-11.md).
Interaktívna lokálna ukážka `_dev/cela-plan/index.html` demonštruje ovládanie, nie výsledok implementácie.
Tento blok je úplné implementačné zadanie; ukážka nie je dátová ani geometrická autorita.

##### Schválené správanie (Michal 11.9.2026)
- D-119: hore/dole/vľavo/vpravo spoločné pre celú skrinku, NIE override jednotlivých čiel. Kladná hodnota = škára, záporná = presah. Dva páry polí v dvoch riadkoch; medzera medzi čelami
  osobitne ako dnes.
- D-120: jeden UKW profil na jednom okraji každého skutočného panela. Dostupný pre dvierka, zásuvkové čelá, výklop, sklop a blendu. Bez čela nemá profil.
- Pri zvislom profile dvierok je profil vždy OPROTI PÁNTOM. Dvojkrídlo má profily v strede. Pri 3/4 krídlach sa každé stredné krídlo riadi svojím určeným smerom. Neurčený smer sa nesmie
  odhadnúť.
- Dvierka: profil Hore / Dole / Bočná oproti pántom. Ne-dvierka: Hore / Dole / Vľavo / Vpravo. Pravidlo oproti pántom sa týka zvislých profilov dvierok; neobmedzuje schválené hornej/dolnej
  hrany výklopov a sklopov.
- Individuálny výber profilu a hrany v karte čela, hromadné nastavenie v skupine Úchytky. Rozdielne hodnoty ukázať ako Rôzne, nepremeniť na default.
- D-114: jeden rad šiestich existujúcich piktogramov priamo pridá typ Dvierka / Zásuvka / Výklop / Sklop / Blenda / Bez čela. Najviac jedna rozbalená karta, identita F#, AUTO/pevné výšky
  ostávajú.
- UKW-7 reduction36mm a prierez19.181×37.419mm sú existujúce interné hodnoty. Smer dekoru a ABS pod profilom sa nemenia. Žiadny nový profil, Gola, metrážové nacenenie, optimalizácia tyčí,
  CNC či per-čelo okraje.

##### ČELÁ-A — D-119, presahy od formulára po výrobu — IMPLEMENTOVANÉ, PR #347
Overenie: 3816 headless, 112 JS sád, in-SketchUp 2225 PASS / 0 FAIL; skutočný Inspector pri 470 px. Ďalšia dávka až po review/merge A.
Jedna užitočná dávka vrátane UI, schema a testov, následne samostatné review/merge podľa repo procesu.
- `Fronts.normalize_config`: nové `gap_left`, `gap_right` (mm Float). Pre KAŽDÚ chýbajúcu novú stranu použiť legacy `gap_sides`, inak GAP_EDGE=2. Nová explicitná nula musí vyhrať. Pri oboch
  nových hodnotách staré `gap_sides` nehrá rolu. Kanonický nový zápis `gap_sides` neukladá.
- `opening_w = width - gap_left - gap_right`; prvé krídlo začína na gap_left. Škáry medzi krídlami, count auto>600, fix/AUTO výšky, delenie odspodu, F identity bez zmeny. Limits ±100/±2000
  platia nezávisle na oboch stranách; konečné platné čísla kontroluje server.
- Prejsť všetky konzumenty `gap_sides`, vrátane troch čitateľov v preview.js a nxFrontDims, highlight N26, drawCarcass, kót, resetu, formulára, insert flow, panel load, migračného
  Fronts.migrate_legacy_config a testov. Kotvy skrinky a Mower krok zostávajú podľa korpusu, neodvodzujú sa z asymetrického čela.
- `CONFIG_SCHEMA` 11→12 pri tejto dávke; novšiu schému starší plugin odmietne prestavať/šablónovať. Samotný read/open nič nemigruje do modelu. Kontrola BuildPlan: deskriptory majú ten istý
  tvar, menia sa rozmery; BuildPlan::SCHEMA sa pre A nemení.
- Roundtrip: vytvorenie, apply/rebuild, scale, copy/paste, uloženie a aplikácia šablóny s/bez kovania, save/reopen, observer/Undo, pôvodné string aj hash fronts. `front_items` a náhľad nesmú
  zobraziť staré rozmery.
- Rozhodujúci príklad: korpus W600; ľavý=-18, pravý=2 → otvor616, x=-18; dve krídla pri gap3 → každé306.5, druhé x291.5. Legacy gap_sides=2 → oba2 a identická geometria/výstupy.
- Testy: čistá matematika + migrácia/roundtrip + JS formulár a náhľad + in-SU rozmery/pozície/Undo/copy/save-reopen. Plná headless, všetky JS, relevantné in-SU. Runtime patch bump + všetky
  HTML cache-bust, dotknutá architektúra a štandard.

##### ČELÁ-B — D-120, všetky hrany profilu
- Zachovať `items[].profile` ako ID (`none`/`ukw7`), pridať `items[].profile_edge` = `top|bottom|left|right|free`. `free` je sémantická voľba iba dvierok, skutočná hrana každého krídla sa
  odvodí z tej istej autority smerov, ktorú používa `Fronts.direction_slots`. Nesmie vzniknúť druhý výpočet pre UI alebo renderer.
- Starý platný profil bez `profile_edge` = top. Chýbajúce `profile` = none. Poškodená/neznáma prítomná hrana sa nesmie potichu zmeniť na top. Server ju odmietne na zapisovacej ceste; čítanie
  existujúcej zákazky naďalej používa uložené výrobné snapshoty. `none` nevytvára žiadny profilový dielec ani nákup.
- `CONFIG_SCHEMA` 12→13 pri B. Profil/hrana prejdú cez normalizáciu, params_from_config, cabinet_config, front_items, save/apply template, copy/paste, import/rebuild a náhľad. KOV-I voľba
  bez kovania naďalej odstráni hardvérové výbery/manuálne riadky podľa svojho kontraktu; nemení samotnú konštrukčnú geometriu čiel.
- `FrontProfiles` ostáva jediný register prierezu/reduction/labels/options. Rozšíri API na štyri skutočné hrany a výpočet panelu/pásma profilu pre celkový obrys krídla. Uložený `free`
  vyrieši Fronts PRED volaním geometrie. Staré top volania ostanú kompatibilné pre existujúce používateľské configy.
- Per krídlo zachovať celkový obrys a špáry; top/bottom odoberá36 z V, left/right odoberá36 zo Š. Bottom posunie panel hore36, left doprava36, top/right ponechajú origin v danej osi. Dĺžka
  rezu = celá dĺžka osadenej hrany; nie skrátený kolmý rozmer. Všetky rozmery mm Float; finálne výrobné zaokrúhlenie až na existujúcom mieste.
- Deskriptor pridá iba voliteľnú anotáciu `profile_edge` (už top/bottom/left/right). Existujúce top `profile_band` zostáva v pôvodnom tvare `{z,h}`. Spoločný helper v FrontProfiles odvodí zo
  skutočného panelu (`box`, `origin`), hrany a reduction celkový obrys, pásmo a dĺžku rezu. Nové redundantné uložené rozmery nevzniknú. BuildPlan::SCHEMA zostáva5 podľa pravidla aditívnych
  polí; samotné výrobné snapshoty profilové metadata neukladajú.
- **Kontrola rozmerov je vo Fronts PRED emission/vyradením dielcov v Construction**, per krídlo a v skutočne skrátenej osi. Neplatný/nekladný zvyšný rozmer odmietne celý rebuild. W200,
  left25,right25,gap3,4krídla →35.25mm pred profilom →-0.75mm po profile MUSÍ byť odmietnuté; nesmie zmiznúť panel. Existujúce varovanie malého panela zovšeobecniť na obe osi, nie iba výšku.
- Renderer nepoužije bbox: jednu kanonickú profilovú definíciu pre (id,dĺžka,geom_rev) osadí na základe explicitného edge/band. Pri obracaní musí zostať nos pred čelom (lokálne záporné Y);
  overiť zrkadlenie prierezu a opačnú bočnú hranu. Proxy nemení výrobu, dedí tag Čelá; part keys panela a HW owner zostávajú stabilné. Geom rev/caching podľa potreby pri zmenenom tvare
  definície, samotné osadenie nie je nový shape.
- `HardwareRules.flag_length_params` berie dĺžku zo spoločného profilového helpera (z `prod` podľa explicitnej hrany, súhlas s `box`). Legacy deskriptor bez novej hrany smie použiť
  doterajšiu top šírku; neplatná prítomná anotácia nesmie vyrobiť nákup s odhadnutou dĺžkou. UI/renderer/pravidlo nesmú mať rozdielne výklady hrany.
- Doplniť tri profilové seed pravidlá pre `flap/up`, `flap/down` a `false_front`, SEED_VERSION6→7. Existujúce dverové/zásuvkové rule_id zostávajú. Nové pravidlo sa nepridá, ak zapnuté
  vlastné `part_flag_length` pokrýva jeho rolu **a smer**; vlastné flap/down nesmie potlačiť flap/up. Vlastné pravidlo bez smeru pokrýva oba smery. Kusové úchytky môžu spoluexistovať.
  Zachovať vypnuté/upravené existujúce pravidlá a future read-only.
- Rovnaký predikát aplikovateľnosti (rola + flap_dir) musí používať evaluate aj `profile_rule_warnings`, inak nesediace pravidlo potlačí hlásenie chýbajúceho profilu. Vypnuté zodpovedajúce
  pravidlo sa hlási existujúcou cestou vypnutého kovania.
- Staré projektové snapshoty sa **automaticky nemenia**. `ensure_project_rules!` sa nerozširuje o migráciu. Používateľovi chýbajúce profilové pravidlo ukáže existujúce upozornenie s akciou
  **Pravidlá → Doplniť nové predvolené**; `project_seed_plan` a spoločná prestavba zapisujú snapshot aj skrinky v jednej Undo operácii. Overiť nový projekt, starý pred doplnením, po doplnení
  a Undo. Nákup/explain/rozpočet zachovajú `length_unsupported`; metráž sa nenaceňuje.
- UI podporu typov zrkadliť na Ruby/JS; vyhodiť lift/fall/blind z PROFILELESS_TYPES, none zostáva. Obe cesty (karta aj hromadné Úchytky) zapisujú rovnaké item dáta, žiadne uložené hromadné
  defaulty.
- Hromadný rozsah: Všetky, Dvierka, Zásuvkové, Výklopy, Sklopy, Blendy. Profil a hranu meniť SAMOSTATNE: samotná zmena hrany nepovolí profil na čele bez profilu; zmena druhu profilu zachová
  platnú hranu. Nové zapnutie z none implicitne top, pokiaľ už nebola vedome uložená platná hrana. Smiešaný rozsah ponúkne len hrany platné pre celý aktuálny rozsah, teda spravidla
  top/bottom; free len v dvierkach, left/right len ne-dvierka. Informačná veta odkáže na kartu/užší rozsah pre bočné hrany.
- Neurčený smer pri `free` sa NESMIE odhadnúť. **Bez nových uložených profilových konfliktov.** Rozpracovaný formulár zostáva v karte, model a jeho uložené výrobné snapshoty zostávajú
  posledné platné. Čistý Ruby preflight nad aktuálnymi rozmermi/fronts vyrieši count krídel a smerové sloty pomocou `Fronts.resolve_wings`/`direction_slots`, aj keď ešte nemožno postaviť
  profil. UI ponúkne presne chýbajúce smery. Až platný celý formulár ide jedným `apply_all` do modelu.
- Rovnaký read-only preflight slúži vkladaniu, načítanej šablóne aj úpravám existujúcej skrinky. Vracia resolved hrany, sloty a stav/hlásenie nad **aktuálnym návrhom**, nie nad starými
  front_items. `preview.js` prenáša direction/wing_directions/profile_edge a kreslí výsledok servera. Pred vložením nemožno používať staré sloty posledne vybranej skrinky.
- Preflight je jeden nový čítací callback existujúceho Panelu, bez zápisu/Undo/katalógovej inicializácie. Request/response nesú identitu dokumentu, vkladacia relácia alebo cabinet_id, a
  rastúcu revíziu návrhu. Uplatní sa iba posledná zhodná odpoveď; zmena výberu, typu vkladu, šablóny alebo modelu zneplatní starý request. Payload validovať rovnako prísne ako apply; server
  pri skutočnom zápise preflight zopakuje a nič neskráti podľa klientovej odpovede.
- Nevyriešený/čakajúci návrh patrí do existujúcej bariéry chýb formulára. Zakáže auto-apply, insert, exportný flush, uloženie/aplikáciu šablóny a native-copy/transform flush; nesmie sa
  zameniť za „nič na uloženie“. Najprv preflight → platný návrh → potvrdený apply → pokračovanie akcie. Stará odpoveď nesmie prepísať práve písané polia. Pri vedomej zmene výberu/režimu sa
  návrh zahodí v rámci existujúceho lifecycle, nikdy sa neprenesie na inú skrinku.
- Pri zmene typu a neaplikovateľnej hrane ostáva návrh otvorený s výzvou vybrať platnú hranu; žiadny free→left/top default. Pri zmene na none sa profil zneaktívni existujúcou normalizáciou,
  návrat vyžaduje explicitné zapnutie profilu. Zmeny1↔2↔3/4/AUTO zachovajú dormant smery a profil, a vypýtajú iba chýbajúce údaje. Direct API/rebuild neplatný stav odmietne; Scale využije
  existujúci rollback `reject_scale!`, nevytvorí poškodený config.
- Overiť všetky exportné a native flush vstupy, neskorý preflight, neúspešný apply a prepnutie dokumentu. Hromadné nastavenie nikdy nevytvorí čiastočný zápis skrinky. Žiadna nová kategória v
  hardware_conflicts, ani nové dočasne nesprávne výrobné panely.
- Presahy/škáry/total extents a front row bounds sa počítajú PRED skrátením panelu. `Fronts.bounds` používané receptom zásuvky sa nesmú zmeniť zo slotu na rozmer fyzického panela.
  Prehodnotiť výškové/šírkové vstupy závesov a výklopov, hmotnosť (dnes panel + existujúca allowance), kolízie hl_top, materiálovú hrúbku, ABS mapovanie a preview kóty: každý konzument musí
  dostať svoju doterajšiu veličinu.
- Rozhodujúci príklad: W600,V720,floor0,left=-18,right=2,gap3,top2,bottom2; dvojkrídlo má celkový obrys306.5×716, zvislé profily v strede, panely270.5×716; ľavý panel x=-18, pravý panel
  x327.5; rezy2×716. Top varianta má panely306.5×680 a rezy2×306.5. Žiadna rotácia grain ani strata ABS.
- Testy: štyri fyzické hrany na ne-dvierkach a top/bottom/free na dvierkach; všetky5 typov; 1/2/3/4/auto krídla a smery/neurčené; legacy top bajtovo identické výrobné údaje; invalid edge;
  transitions s otvorenou kartou; hromadný rôzny stav; šablóny s/bez kovania; copy, scale, Undo/Redo/save-reopen; exaktne4 osadenia prierezu a zhodná dĺžka proxy/nákup;
  starý/custom/vypnutý/future seed. Neplatný návrh blokuje každý flush/export, po oprave sa bariéra uvoľní až po apply. In-SU aj browser sú povinné.

##### ČELÁ-C — D-114, uzáver ovládania — IMPLEMENTOVANÉ, PR #351
Overenie: 3830 headless, 113 JS sád, skutočný Inspector pri 470 px; B2 geometria/Undo 2297 in-SU PASS nezmenená. Ručné Redo zostáva v živom pláne.
- Šesť type add ikon v jednom pôvodnom riadku, existujúci FRONT_TYPE_ICON a rovnaký addFrontKind. Door nové smer neurčené existujúcou cestou; none drží výšku a prázdnu niku.
- Všetko sa zmestí v470px Inspectore, horný rad čela sa nezalomí ani pri fixed výške/AUTO/missing-direction badge; type picker aj per-čelo profil žijú v jednej otvorenej karte.
- Upratať pomocné texty, súhrn Úchytiek s hranami a indikátor; klávesnica/labels/fokus pri echo/re-render. Nevyrábať nové satelitné okno ani nové UI témy.
- Runtime patch, cache-bust, celá headless a JS, browser smoke. In-SU len ak C zasiahne geometriu/lifecycle; samotné uzavretie balíka vyžaduje už hotový B in-SU dôkaz a používateľský smoke.

##### Mapa prenosu a rozhodujúce autority
| Cesta | Miesta a dôkaz |
|---|---|
| Vytvorenie/form/load/reset/bulk/card | ui/panel.html, ui/js/form.js, core.js, preview.js, insert_state.js, panel/actions_cabinet.rb; interaktívny browser test |
| Normalizácia a migrácia | modules/fronts.rb, CabinetBuilder.normalize_params/fronts_from_config/params_from_config; old/new roundtrip test |
| Geometria/uložené snapshoty | Fronts.layout/panels_for, Construction.build/bounds, BuildPlan.validate!, CabinetBuilder resolve_part/cabinet_config/render_front_profile; in-SU plan=entity |
| Šablóny/copy/scale | CabinetBuilder.template_config_from, Templates pripraviť/aplikovať, tools Mower, ScaleWatch; s/bez kovania a Undo |
| Kovanie a výstupy | HardwareRules evaluate/flag_length_params/seed/project rules; HardwareSets length gate; Bom/Validation/ProductionCore export guards; zhodná dĺžka+blokovanie konfliktu |
| Dátové kontrakty | SYSTEM/STANDARD §2/3/5.3/6/7.5/8/9/11; docs architecture construction/hardware/model-a-identita/ui-lifecycle/outputs |

##### Brány a uzáver

Outside-in a reconcile sú dokončené v rozsahu návrhu; geometrický probe kandidátneho osadenia je povinný pred prijatím B.
Prvé Astra kolo: 0 BLOCKER, 4 FIX-IN-B, 2 NOTE; všetkých šesť je v znení vyššie zapracovaných.
Kontrola zapracovania vrátane čítacej/flush cesty skončila **SOUND** (11.9.2026). Návrhová auditná brána je uzavretá.
Po každej dávke testy, aktuálne GH review/CI a čerstvý main podľa CLAUDE.md. Patch a všetky cache-bust zhodné s VERSION.
Uzáver celého balíka = minor podľa CLAUDE.md, vyriešené D-čísla presunúť do archívu až po skutočnej implementácii a overení.
Žiadny runtime test ani in-SU geometrický výsledok sa neodvodzuje z úspešného mockupu.

## Etapy

- ✅ **V0.1 — Klikateľný základ** (hotové 15.7.): panel, dolný korpus (Ruby regenerácia), police 0–4, dvierka 1/2/auto, ghost zóny, rebuild označeného, 1-krok Undo
- ✅ **V0.2a — Jadro korpusu** (hotové 16.7.): scale→automatická prestavba (celé mm, čistá transformácia, funguje aj na rotovanom) · konštrukčné varianty: dno pod bokmi (EU default) vs. medzi bokmi, vrch plný/2 výstuhy (orientácia flat/upright + offset — drezová/varná)/žiadny, chrbát naložený/vložený/drážka, sokel žiadny(nohy)/predný · **horná skrinka** (Z=1400) · spätná kompatibilita V0.1 · 18/18 kombinácií otestovaných
- ✅ **V0.2b — Členenie, čelá, šablóny** (hotové 16.7., v0.2.1): strom zón s klikateľnými ghost boxmi + priečky divider_v/h (rekurzívne, reálne dielce) · police = modul v zóne · čelá odspodu s fixed/auto + 🔒 locky, zásuvkové čelá, konverzia starých · šablóny (4 preddefinované + vlastné, %APPDATA% + .bak) · hrúbka chrbta HDF 3/pevný 18 · panel: základné/pokročilé skladacie sekcie
- ✅ **V0.2c — UX panela a zón + opravy** (hotové 16.7., v0.2.2): oprava teleportu · ghost zóny na 1 klik · interaktívny 2D náhľad · auto-apply · filtrovanie šablón · tagy dielov · osové scale handles · čitateľné zóny
- ✅ **V0.3 — Materiály a ABS (dáta)** (hotové 17.7., v0.3.0): materiálový katalóg (rodina/variant, JSON) · dedenie projekt→skrinka→dielec · ABS hrany L1/L2/W1/W2 s pravidlovými defaultmi podľa roly · per-dielec editor
- ✅ **V0.3.1 — stabilizácia dát** (hotové 17.7.): zhoda katalógovej a geometrickej hrúbky · smer dekoru vo výrobných dátach · atomický projektový prepočet s jedným Undo · validácia zón/čiel · bezpečná migrácia starých podlimitných čiel · zrozumiteľné zobrazenie dedenia v karte dielca
- ✅ **V0.3.2 — stabilná identita dielcov** (hotové 17.7.): trvalý `part_key` pre pevné dielce, zóny a čelá · migrácia starých override kľúčov bez straty neznámych údajov · materiál/ABS zostane na správnom čele po zmazaní susedného riadku a na správnej polici po úprave susednej zóny
- ✅ **V0.3.3 — ABS iba 1/2 mm** (hotové 17.7.): samočistenie aktívneho katalógu od nepodporovaných hrúbok · neplatné ABS priradenia sa zahodia bez tichej náhrady · pravidlá akceptujú iba 1 alebo 2 mm
- ✅ **V0.3.4 — Stabilizácia pred kovaním** (hotové 17.7., v0.3.4; PR #13–#21): docs sync štandardu s kódom · odstránené „Použiť na podobné" · **140 automatických testov + GitHub Actions CI** (headless sada, guard testy VERSION/mm, APPDATA sandbox) · **panel split** (panel.html → css + 10 JS modulov; panel.rb → 9 doménových súborov; CONSTRUCTION_FIELDS + PARAM_KEYS = nové pole na 1+1 mieste; verzia v UI z Ruby; AppObserver po File>New/Open/Activate) · **BuildPlan kontrakt** (`core/build_plan.rb`: schema 1, MIN_DIM, validátor s unikátnosťou part_key, `warnings[]` kanál, tvar `hardware[]` pre V0.4, prod sémantika) · **in-SketchUp runner** (`tests/sketchup/su_runner.rb` + `scripts/run_su_tests.ps1`, geometria plán↔model 1:1 + undo scenáre) · **undo fixy** (scale absorpcia aj dedup kópie = transparentné operácie → 1× undo vráti celý krok; S1/S2 tvrdé asserty)
- ✅ **V0.4 — Kovanie fáza 1 (pravidlá a flagy)** (18.7., PR #23–#26; pôvodne značené 🔨): rules engine s Ruby vzormi fixed/bands/fit_series parametrizovanými JSON pravidlami · seed: nohy 4 ks (sokel bez vplyvu, výška v params), závesy podľa výšky krídla ≤900:2/≤1400:3/≤1900:4/inak 5, výsuvy NL z radu podľa svetlej hĺbky −10 · **projektový snapshot pravidiel** (reprodukovateľnosť z .skp, undo drží pravidlá aj geometriu; globál = default nových projektov, seed-merge) · hardware_overrides (identita owner+typ+rule_id, šablóny ich zachovávajú) · BuildPlan schema 2 (string-keyed, sprísnený validátor) · vizuál nôh ako proxy (none/false — súpis číta config.hardware[]) · panel sekcia Kovanie (počty, ručný zásah, vypnutie) · dialóg Pravidlá kovania (pásma/rady, uložiť do projektu + globálne) · odložené na ďalšie fázy: hmotnostné Blum tabuľky (chýba hustota materiálu), smer otvárania a typ závesu (naložené/vložené/tip-on), automatika počtu nôh podľa šírky (zmena JSON pravidla)
- ✅ **V0.4.5 — UI konsolidácia (Inspector + satelity)** (hotové 18.7., v0.4.6; PR #27–#30, implementuje 05+06+07): panel = **Inspector** — obsah podľa výberu (vkladacia karta / korpus / zóna / dielec s omrvinkou ‹CAB›), identita + ⚠ upozornenia hore (klik = výpis) · **náhľad = fixné okno** so zoom kolieskom, posunom ťahaním a ⛶ fit (pohľad drží pri úpravách — koniec scrollovania cez vysoké skrine) · karta zóny hneď pod náhľadom · **satelitné okná**: Pravidlá kovania, Materiály projektu (predvoľby dedenia + guard hrúbok novej skrinky), Šablóny (typový guard, správa) · quick-pick šablóny vo vkladacej karte · badge kovania pri čelách · dilema 05 rozhodnutá: Inspector-first, Vkladač až s knižnicou modulov
- ✅ **V0.4.7 — Dogfooding: samostatná doska** (hotové 18.–19.7., v0.4.7; PR #31–#35): samostatný výrobný dielec `kind: board` (krycia doska, blenda, výplň, atypický prírez) — identita BRD-xxx + `part_key` `board/main`, rola `free_panel`, config = superset dielca korpusu (kusovník/VEPO budú mať jeden svet), materiál = snapshot z katalógu (hrúbka sa riadi materiálom; zmena materiálu prevedie ABS na nový dekor), ABS default 1 pozdĺžna 1,0 mm (seed-merge do existujúcich inštalácií) · **a)** dátový základ · **b)** builder + dedup kópií bez prekreslenia + Placement (top-level umiestňovanie) + per-entity transparent dedup (opravený aj korpusový undo bug) · **c)** UI karta Doska (prepínač Korpus/Doska, ABS editor s 2D náhľadom, guard oneskorených zápisov) · **d)** scale absorpcia (lokálne osi = výrobná pravda; hrúbka vždy z materiálu; shear guard; nemodálne hlásenia) · **e)** **matematické výrazy v rozmerových poliach** (`650-36` + Enter, živý náhľad `= 614`, JS parser s CI testami; identity guard auto-apply korpusu) + panel refresh po scale absorpcii. Autorita výrobného záznamu = snapshot na entite (štandard 8.3). NEobsahuje (V1.0): attachment/segmenty, auto krycie dosky, pracovné dosky cez segment. Proces: Codex devil's advocate pred každou iteráciou + GH review po každom PR (5×; chytené o.i. 2 reálne bugy existujúceho správania)
- ✅ **V0.4.7 dogfood — dávky postrehov 1–2** (hotové 19.7., stále v0.4.7; PR #37–#39): **veľké dogfood testovanie beží** — postrehy sa evidujú v živom zápisníku 08_DOGFOODING.md (trvalé D-čísla, PR #37) a riešia sa v malých dávkach · **dávka 1** (PR #38): scale úchopy len čisté osi — maska 120 + zápis na definíciu (D-06) · debounce 2D náhľadu 500 ms pri písaní (D-02) · náhľad rastie s veľkosťou okna panela (D-01) · ghost zóny predvolene vypnuté, klik na zóny cez 2D náhľad (D-04) · **dávka 2** (PR #39): plná správa katalógu materiálov v okne Materiály projektu (D-05, bloker reálnej zákazky) — CRUD dosiek aj ABS pások, serverom generované ID, hrúbka existujúceho materiálu nemenná (= nový variant), mazanie s guardom (chránené fallbacky + scan použitia v modeli/overridoch/dielcoch/doskách/šablónach), živý sync do panela · **dávka „noc na 19.7."** (PR #41 D-07 + #42 D-03): nastaviteľné medzery a presahy čiel (záporný okraj = presah, ±100 mm; medzera krídel z configu; fit náhľadu s presahmi) · police discoverability (jednozónová skrinka = karta Zóna rovno) · **dávka 3** (PR #43): **D-08 režimové taby Inspectora** — Korpus (kótovaný obrys Š/V/hĺbka) · Zóny · Čelá = režimy práce prepínajúce náhľad aj sekcie; tab sa pamätá cez zmeny výberu; dielec vynúti zónový náhľad · proces: repo skilly codex-audit/codex-po-pr (PR #40) + **auto-merge infra** (required CI check na maine, auto-delete vetiev) · ďalej: D-09 snap priečok, D-10 drag čiel
- ✅ **V0.4.7 dogfood — nočná fronta 19.→20.7.** (PR #50/#52/#54/#55): D-25 merač používania panela (lokálne počítadlá → podklad pre budúci režim Rozšírené) · D-18 čelo „BEZ" (otvorená nika v rade čiel, kovanie/výstupy nič) · D-24 krídla dvierok 1–4 (identita byte-stabilná, auto nemenené) · D-22 odomykateľný limit presahov (±100 → 🔓 ±2000 per korpus) · D-23 orientácia riadkov čiel (zoznam ako skrinka, sivé ≈ výšky, klik-sync s náhľadom) · D-21 výrazy v čelách = zistené ako už existujúce (V0.4.7e + D-07) · proces: Codex audit pred každou dávkou (spolu 12 auditov/review, 11 blockerov + 20 fixov zapracovaných), merge po zelenom review, `@codex review` mention pri nespustenom review
- ✅ **V0.5 — Výstupy v0** (hotové 19.–21.7.; PR #47/#48/#51/#53/#65): ✅ A interný kusovník + súpisy m²/bm/ks zo snapshotov (#47) · ✅ B okno Výroba s klik-selectom (#48) · ✅ C **VEPO CSV priamo** (#51 — HOTOVÉ rozmery, rotácia dekoru, merge 18+36, atomická dávka + LOG, byte-kompatibilné so starým exportérom) · ✅ D-19 odhad platní ako rozsah 10–25 % (#53) · ✅ **krížová validácia s OCL splnená** (20.7., 2-kolový zrkadlový test — 1. kolo chytilo omyl štandardu s odpočtom ABS, fix PR #58: VEPO dostáva HOTOVÉ rozmery; 2. kolo 26=26 s presnými zhodami) · ✅ **D semafor v0** (#65, nočná fronta 21.7.): KONTROLA tab v okne Výroba — 🔴 materiál mimo katalógu/hrúbkový drift/nezmestí sa na platňu · 🟠 čelo bez ABS/vypnuté kovanie/build warnings · klik-select cez stabilnú identitu, sekcia KONTROLA vo VEPO LOGu, **RED nikdy neblokuje export**
- ✅ **V0.4.7 dogfood — nočná fronta 21.7.** (PR #63–#69): MCP diagnostika (`skagent_doctor.ps1` + `Debug.report`) · D-40 fix DC observer pasce (scaletool zámok v transparentnej operácii ZA vložením) · D-29 sticky dvojradová hlavička + **design tokeny `--nx-*`** + **ikonový sprite icons.js** (Lucide subset, žiadne emoji v UI chrome) + `docs/UI_DIZAJN.md` · D-36 ABS optgroup „Odporúčané k dekoru" · #69 hotfix diakritiky panel.html + **encoding guard v CI**
- ✅ **V0.5-E — D-41 dekorové skupiny materiál↔ABS** (hotové 23.7.; PR #70–#73, návrh cez Codex audit 17 nálezov): **šírka ABS** (variant = dekor+šírka+hrúbka, ID `..._22X10`) + **deterministický picker** (najmenšia šírka ≥ hrúbka dielca +2 → univerzálna → nič, NIKDY užšia) · **dekor = strážený kľúč skupiny** (trim, near-match guard, immutable pri edite, `rename_decor` atomicky, dup zákaz, revision guard okna) · okno Materiály ako dekorové karty + batch „Nový dekor" · **centrálny remap ručných ABS pri KAŽDEJ zmene efektívneho materiálu** (dielec/korpus/projektová predvoľba; kontrast a „bez ABS" nedotknuté) · modal dovytvorenia chýbajúcej pásky (AUTO_WIDTHS 22/43, katalóg mimo undo = vedomý kontrakt) · SU runner 138/138
- ✅ **V0.5-F — D-42 dekorový katalóg UI** (hotové 24.7.; PR #74–#77, návrh cez vizuálne mockupy + Codex audit 6 blockerov): okno Materiály 640×560 = **mriežka dlaždíc** podľa výrobcu + pás **„Použité v projekte"** (kusy z aktívneho modelu) + hľadanie (názov/výrobca/kód/dodávateľ) · **kód + dodávateľ** na doske aj ABS (jeden preferovaný; merge-safe, duplicitný pár s potvrdením) · **cena „nezadaná" ≠ 0** (nil kontrakt pre budúcu cenovú ponuku) · detail dekoru s **inline bunkami** (patch protokol: whitelist polí, row_rev baseline per riadok — žiadny tichý prepis cudzej zmeny) · batch cez **preset-čipy** (typ per variant — PD 38) + zapamätaná posledná sada · **seed reálnych dekorov dodá Michal pri testovaní**

## Vyriešené riadky backlogu postrehov (pôvodná tabuľka)

| Dátum | Postreh | Zaradenie |
|---|---|---|
| 15.7. | EU konštrukcia: boky NA dne (váha na dno), nohy pod dnom, soklová lišta v celku pre segment; dno medzi boky = horné skrinky a špeciálne | ✅ V0.2a (default); soklová lišta segmentu žije v etape V1.0 |
| 15.7. | Scale nástroj → automatická prestavba s korektnými hrúbkami | ✅ V0.2a |
| 15.7. | Drezová: horné výstuhy NA VÝŠKU (max priestor pre umývadlo) | ✅ V0.2a (rails_orientation) |
| 15.7. | Varná doska: výstuhy 20 mm pod hornou hranou (zapustenie dosky) | ✅ V0.2a (rails_top_offset) |
| 15.7. | 3–4 typy pokryjú väčšinu projektov; rohová = určite samostatný typ; šatníky/atypy mimo | ✅ šablónový systém V0.2b; otvorená časť (rohová/vysoká po V1.0) presunutá do živého backlogu |
| 16.7. | Scale test rukou: funguje super, prestavba presne na mm | ✅ V0.2a potvrdená používateľom |
| 16.7. | Hrúbka chrbta ako nastavenie (HDF 3 / pevný 18) | ✅ V0.2b |
| 16.7. | Panel: len relevantné pre typ + rozmery označeného; pokročilé skrývať | ✅ V0.2b (skladacie sekcie) + trvalá zásada (žije v CLAUDE.md a zápisníku) |
| 16.7. | DILEMA UI: Vkladanie vs. Nastavenia | ✅ rozhodnuté — [05_DILEMA_ui_architektura.md](05_DILEMA_ui_architektura.md) (Inspector-first, V0.4.5) |
| 16.7. | Test V0.2b: funkčnosť super, UI „džungľa", BUG teleport | ✅ V0.2c |
| 16.7. | Zóny vízia: A) 2D náhľad v paneli vs. B) priamo vo viewporte | ✅ A hotové (V0.2c+); otvorená časť (B ako nadstavba) presunutá do živého backlogu |
| 16.7. | Tagy dielov (korpus/čelá/chrbty…) — hromadné operácie, dočasné HIDE | ✅ V0.2c |
| 16.7. | Scale len čisté osi X/Y/Z (bez kombinácií) | ✅ V0.2c + finálne D-06 (maska 120) |
| 16.7. | Zložka pluginu — konsolidovať súbory pod jednu strechu | ✅ PR #4 (SYSTEM + docs + zdroje v repe) |
| 16.7. | Vyhradený testovací projekt ENGINEtests.skp | ✅ zavedené (`_dev\`, gitignore, pravidlo v CLAUDE.md) |
| 16.7. | BUG: drag priečky funguje len raz | ✅ PR #2 + #3 (suspend_selection_sync) |
| 16.7. | UI mockup „NOXUN Furniture Engine" | ✅ rozpísané v [UI_VIZIA_2026-07.md](UI_VIZIA_2026-07.md) (od 26.8.2026 archív) |
| 16.7. | Materiály: povolené hrúbky na rodine; dielec mimo povolených → „!" v kusovníku | ✅ vyriešené INAK — dekorové skupiny D-41 (hrúbka = vlastnosť variantu materiálu) + hrúbkový drift ako RED v semafore V0.5-D |
| 16.7. | ABS UX v2: hrúbky 1/2 mm; odvodené od materiálu; predvolená ABS pre skrinku + výnimky | ✅ V0.3.3 (hrúbky) + dedenie + D-36 (odporúčané k dekoru) + D-41 (dekorové skupiny) |
| 17.7. | Undo/redo riziká (audit kódu) | ✅ undo opravené 17.7. (transparentné operácie, S1/S2 asserty); redo pozorovanie presunuté do živého backlogu |
| 17.7. | Zmazanie ABS záznamu ticho mení výrobné dáta | ✅ V0.3.4 (warnings kanál) |
| 17.7. | Tichá migrácia part_key môže ticho zlyhať | ✅ V0.3.4 (warnings + fixture test) |
| 17.7. | SCALE_TOOL_MASK = 7 nepotvrdená (alternatíva 120) | ✅ D-06 (PR #38) — maska 120 potvrdená vizuálne |
| 17.7. | „Použiť na podobné" úplne odstrániť | ✅ PR #14; poznámka „vráti sa premyslená s kovaním" presunutá do prenesených záväzkov (V0.6) |
| 19.7. | Toggle tagov z panela | žije ako **D-27** v zápisníku 08_DOGFOODING |
| 19.7. | Textúry materiálov pre render (Lucia) | žije ako **D-28** v zápisníku 08_DOGFOODING (po V0.6) |

## Blok 1 · UI 2.0 — štúdio okno a výbery (uzavretý v0.8.0, 24.8.2026)

> **Presunuté z [../PLAN.md](../PLAN.md) 26.8.2026** (dávka Docs cleanup B) — plný pôvodný
> text bloku vrátane zadania, implementačných dávok a vedomých odchýlok. PLAN drží od tejto
> dávky už len nehotové bloky. Otvorená časť, ktorá z bloku ostala (**PICKER-3**), je od
> 26.8.2026 hotová — jej plný text je na konci tohto súboru; dlhy fázy ŠTÚDIO sú v bloku
> **1b · STABILIZAČNÁ REVÍZIA** v živom PLAN.
> Text sa nemenil — upravené sú výhradne relatívne cesty odkazov (súbor leží o úroveň nižšie)
> a polohové slovo „nižšie" pri bloku 1b, ktoré po presune ukazovalo do prázdna (teraz odkaz na živý PLAN).

### 1 · UI 2.0 — štúdio okno a výbery — ✅ KOMPLET (v0.8.0, 24.8.2026)

**HOTOVO — CELÝ BLOK.** Inspector rework (UI-A…UI-D) aj fáza ŠTÚDIO (ŠT-1a…ŠT-4b, PR #192–#228) sú v maine: plugin má **dve okná** (Inspector + Štúdio s **dvanástimi živými sekciami**), **šesť satelitov zaniklo** (Výroba · Materiály projektu · Katalóg kovania · Pravidlá kovania · Šablóny · Nastavenia rozpočtu) a s posledným z nich aj celá mašinéria premostení. Plný uzáver fázy vrátane ustálených architektonických vzorov je v [archiv/KRONIKA.md](KRONIKA.md); dlhy fázy sú v bloku **1b · STABILIZAČNÁ REVÍZIA** v živom [PLAN.md](../PLAN.md). Pôvodné zadanie bloku ostáva zapísané kvôli histórii.

**Cieľ:** satelitné okná → jedno štúdio okno s toolbarom a bočnou navigáciou; výber materiálu/ABS na jeden klik namiesto scrollovania. **Koncept Inspectora je uzavretý** (Michal, 18.8.2026) — záväzný slovný kontrakt je [zdroje/ui20/UI20_KONTRAKT.md](../zdroje/ui20/UI20_KONTRAKT.md) (sekcie „SCHVÁLENÉ ROZHODNUTIA" a „FINÁLNY KONCEPT INSPECTOR C") a vizuálna referencia mockupy vedľa neho: [Inspector C v16](../zdroje/ui20/mockup_inspector_c.html) · [štúdio okno](../zdroje/ui20/mockup_ui20.html) · [dizajnový lístok](../zdroje/ui20/dizajnovy_listok.html); implementácia ide po dávkach nižšie. Podklad: merač používania D-25 (materiály/ABS vyše 400 interakcií, taby 287×, satelitné okná 234×) a [UI_VIZIA.md](UI_VIZIA_2026-07.md); cieľový obraz v [V1_VIZIA_priebeh_2026-08.md](V1_VIZIA_priebeh_2026-08.md) §6 *(§6 sa 26.8.2026 presunul zo živého `V1_VIZIA.md` sem)*.

**~~UI-B · Inspector kostra~~ — BLOK KOMPLET** (UI-B1 #168 · UI-B2 #169 · UI-B3 #170, v0.7.7): kostra (rail + 4 sektory), náhľad ako kontextová projekcia a obsah Korpusu vrátane kolieska. **Bugfix po teste (18.8., v0.7.8):** Základné a Materiály patria kontextu Korpus, ostatné kontexty majú kontextový riadok — nedotiahnutá mapa viditeľnosti z UI-B1. **Dotiahnutie voči kontraktu (18.8., v0.7.9):** logo v hlavičke aj v „O plugine" je zrolovaná značka z originálnych kriviek (24 px) a lišty sektorov nesú meta súhrny (projekcia · rozmery · materiály · otvorená skupina). Plné texty v [archiv/KRONIKA.md](KRONIKA.md).

**~~UI-C · Kontexty~~ — BLOK KOMPLET** (UI-C1 #174 · #175 · #176 · UI-C2 #177 · UI-C3 #178 · UI-C4 #179, **v0.7.16**): Inspector má hotové **všetky kontexty**. **C1 Vkladanie** — typové tlačidlá (Dolná · Horná · Doska), dlaždice šablón s „naposledy použitými" a dvojklikom (N16/N17), zámky D-39 pre dosku, doskové šablóny a orientácia dosky (naležato · nastojato · na stenu); reálne PNG náhľady dlaždíc ostávajú vedome v **UI-D2**. **C2 Zóny** — štruktúra navrchu so stromovými spojnicami a najviac 3 úrovňami (N22), delenie na štyri dlaždice, presné delenie prvej zóny v mm aj zlomkom (N21), magnet pri ťahaní priečky s vypnutím cez Alt (N20, **D-09 uzavreté**), police ako pilulky 0–6, rezervovaný slot „Vnútro". **C3 Čelá** — ikona typu (N27), chip **AUTO** namiesto zámku (zamknuté ⇔ vypísané), výškové rady (N25), naviazané kovanie pod riadkom, **D-84**, **D-96 Úchytky**, **N26** medzery jantárovo a **D-89a** hover hrany v MODELI (**D-89 uzavreté**). **C4 Kovanie** — položky ako **boxy podľa vlastníka** (Skrinka · každé čelo · Vnútro skrinky), klik na hlavičku boxu aj na značku v náhľade **označí vlastníka v modeli**, hover box ↔ značka, sekcia rozdelená na Položky · Sety · Pravidlá. Vedomé odchýlky od mockupu (Zóny: aktivita ovládačov a zámok poľa · Čelá: neaktívny výklop, chýbajúca hrana osadenia · Kovanie: panel po označení nepusha, „Vnútro skrinky" namiesto boxu na policu) sú zapísané v [zdroje/ui20/UI20_KONTRAKT.md](../zdroje/ui20/UI20_KONTRAKT.md); plné texty v [archiv/KRONIKA.md](KRONIKA.md).

**~~UI-D · Dotiahnutie~~ — BLOK KOMPLET** (UI-D1 #180 · UI-D2 #181 · UI-D3 #182, **v0.7.20**) — **a tým je INSPECTOR REWORK HOTOVÝ** (UI-A · UI-B · UI-C · UI-D). **D1 Dielec** — Základné hore ako dopočítané údaje, hranové ikony s rotáciou podľa 2D náhľadu, „Označiť v modeli" (bez zápisu a bez kroku Späť) a „Použiť na podobné…" (prenos **olepu hrán** na dielce s rovnakou rolou a materiálom, rozsah *táto skrinka / celý projekt* so živým počtom, celý zápis **jeden krok Späť**). **D2 Náhľady šablón** — pri uložení šablóny sa odfotí **skutočný pohľad na skrinku** a dlaždica ním nahradí schematickú kresbu; kamera sa vždy vráti presne tam, kde bola, a nevznikne ani jeden krok Späť; staršie šablóny aj neúspešné fotenie končia pri schéme (obrázky žijú ako súbory vedľa knižnice, schéma `templates.json` sa nemenila). **D3 Klikateľnosť a uzávery** — ⚠ chip otvára **warnpanel ako overlay** (nič neposunie), každý nález má **oko** na označenie dotknutého dielca v modeli a dole deep-link **„Otvoriť v Štúdiu → Kontrola"**; „Materiál" v info stĺpci otvára **Kusovník**; v karte dielca je „Smer dekoru" preklikom na materiál; `UI_DIZAJN.md` doplnený o všetko, čo bloky UI-A…D zaviedli. Vedomé odchýlky (smer dekoru ostal informáciou; rotácia hranovej ikony podľa náhľadu, nie podľa pevnej mapy; kontextová fotografia namiesto izolovaného renderu) sú v [zdroje/ui20/UI20_KONTRAKT.md](../zdroje/ui20/UI20_KONTRAKT.md); plné texty v [archiv/KRONIKA.md](KRONIKA.md).

**Rozhodnuté 20.8. nad HOTOVÝM panelom:** **D-26** (režimy *Jednoduchý / Rozšírený* vs. akordeóny „menej časté") je **ZAVRETÉ bez implementácie** — koncept zbalil obsah do exkluzívnych skupín sektorov a „Menej časté" v ňom neexistuje, prepínač by pridal druhú os skrývania nad už fungujúcu (plný text v [archiv/DOGFOODING_vyriesene.md](DOGFOODING_vyriesene.md)) · **per-dielec smer dekoru** dostal číslo **D-108** a vlastný blok **KRESBA** nižšie (uzavretý 21.8.).

**Po smoke teste 20.8. (Michal, hotový Inspector)** — opravný pack **SMOKE PACK 1** je hotový (PR #183, v0.7.21): rozbité riadky zoznamu čiel · prekrytý text v boxe kovania · podperky políc súhrnne s rozklikom · ručné „Odfotiť" náhľadu k existujúcej šablóne. Otvorené zvyšky z toho istého testu:
- ~~**Nové zobrazenie výsuvov v mini náhľade**~~ — **HOTOVÉ** (PR #184, v0.7.22): výsuv sa v projekcii Kovanie kreslí ako **koľajnica „L" pri oboch bokoch + telo šuflíka**, výšky tiel rastú s čelami. Schválené Michalom 20.8. nad mini náhľadom.

**~~BLOK KRESBA — smer dekoru~~ — BLOK KOMPLET** (K1 #185 · fixy #186 · #187 · K2 #188, **v0.7.26**) — dôvodom bol reálny incident z 19.8.: v objednávke naostro mala tenká horná blenda pozdĺžnu kresbu a vysoké úzke dvere pod ňou priečnu, a plugin to nevedel ani nastaviť, ani ukázať. **K1 · D-108** dala smer ako **vstup** — segment *Podľa materiálu / Pozdĺžna / Priečna* v karte dielca; override žije v `part_overrides['grain_direction']` (enum `length`/`width`), efektívny smer počíta `CabinetBuilder.effective_grain` a **materializuje sa raz do snapshotu dielca**, rotácia sa nepridala nikde (dĺžku/šírku a dvojice hrán vymieňa naďalej len VEPO a `fits_on_sheet`). **K2 · D-87** dala **kontrolu toho vstupu** — prepínač „Smer kresby" v okne Výroba → Kontrola nakreslí čiary v smere kresby na každý výrobný dielec (overlay nad modelom, žiadny krok Späť, po vypnutí nič neostane), kreslí **výhradne zo snapshotu** a materiál bez kresby preskočí. Z review K1 vyšla najavo výrobná pasca na odpojenom dielci — opravená (#186) a dotiahnutá (#187). **Po smoke teste K2 pribudol druhý vstupný bod prepínača — „Kontrola kresby" v raile Inspectora** (#189, v0.7.27): zdieľaná `Engine.toggle_grain_check` + broadcast obom oknám, teda **jeden zdroj stavu, dva vstupné body** (presné zrkadlo ABS kontroly z UI-B1); overlay logika sa nemenila. *Orientácia TEXTÚR podľa smeru dekoru ostáva v M-R — to je render, nie kontrola.* Plné texty v [archiv/KRONIKA.md](KRONIKA.md).

**~~ABS kontrola v raile — 3-stavové nastavenie~~ — HOTOVÉ** (PR #190, **v0.7.28**, 21.8.) — drobná dávka z debaty o ikone ABS kontroly. Michal si vybral **variant B: malý plný trojuholník v pravom dolnom rohu** ikony (flyout vzor nástrojov SketchUp/Photoshop); ikona `shell` ostáva a **toggle sa nemení** — klik na roh otvorí **3-stavové nastavenie kontroly hrán** (chýba podľa pravidla / mimo pravidla / olepené + „len vybrané" so živými počtami), teda presne to, čo má okno Výroba pod chevronom. Tým je **splnený pôvodný kontrakt UI 2.0 „ABS kontrola = shell so stavom a šípkou na 3-stavové nastavenie"** a vedomá odchýlka z UI-B1 zaniká. Kľúčové rozhodnutie: nastavenie sa **nekopírovalo** — vyčlenilo sa do zdieľaného komponentu (`ui/js/edge_menu.js` + štýly v zdieľanom `panel.css`) a **obe okná zapisujú jednou serverovou cestou** (`Engine.set_edge_check_option` → broadcast), takže stav aj počty sú vždy rovnaké a dve kópie okna nikdy nestoja na obrazovke naraz. Nový vzor „flyout roh" je zapísaný v [../docs/UI_DIZAJN.md](../../docs/UI_DIZAJN.md) §5.11.

**Fáza ŠTÚDIO — KONCEPT SCHVÁLENÝ 22.8.2026** *(sektorová debata 21.–22.8., 4 kolá nad
klikateľným mockupom, návrhy Š1–Š19 — všetko schválené; záväzný slovný kontrakt je sekcia
**ŠTÚDIO KONCEPT** v [zdroje/ui20/UI20_KONTRAKT.md](../zdroje/ui20/UI20_KONTRAKT.md), vizuálna
referencia [zdroje/ui20/mockup_studio.html](../zdroje/ui20/mockup_studio.html)).* Do konceptu sú
zapracované a ním uzavreté: **D-50** (OCL vzory — skupiny kusovníka, hover akcie, voliteľné
stĺpce, klik-select), **D-69** (jednotný editor materiálov: 3 vstupy → 1 formulár) a **D-15**
(pridávačky ako zdieľaný modal) + klik na materiál → zvýraznenie použitia; D-čísla sa vyriešia
implementáciou príslušných dávok. Vedomé odklady: Nákup kovania a Katalóg kovania **presun 1:1
bez redizajnu** (redizajn s blokom KOVANIE) · D-106 s okruhom rozpočtu · D-95 s blokom
KONTROLA+VÝROBA · DOCX/PDF generátor ponuky po V1.

Implementačné dávky (poradie presunov schválil Michal; každá dávka = plugin plne použiteľný,
satelit zaniká až po plnej náhrade):
- ~~**ŠT-1a** skelet Štúdia + sekcia **Kusovník**~~ — **HOTOVÉ** (PR #192 + #193, v0.7.30, 22.8.; audit aj review „slepým subagentom" — Codex mimo; serverový názov projektu, premostenia v navigácii; vedomé odchýlky: XLSX/CSV disabled, bez stĺpca Poznámka, ABS pohľad bez cien — plný text v [archiv/KRONIKA.md](KRONIKA.md)).
- ~~**ŠT-1b** sekcia **Kontrola**~~ — **HOTOVÉ** (PR #195, v0.7.32, 22.8.; jedno číslo cez zdieľaný control_payload vrátane rozpočtu, tretia inštancia edge_menu, zmena lifecycle overlayov — plný text v [archiv/KRONIKA.md](KRONIKA.md)).
- ~~**ŠT-1c** Rozpočet + Cenová ponuka + Nákup — zánik okna Výroba~~ — **HOTOVÉ** (PR #197–#200, v0.7.40, 22.8.; 4 PR podľa auditu — bump:false generačný kontrakt, D-15 modal kostra `nx_modal.js`, nová in-SU sada rozpočtu; plný text v [archiv/KRONIKA.md](KRONIKA.md)).
- ~~**ŠT-2** (M) sekcia **Materiály** + **D-69 editor** — okno Materiály zaniká.~~ — **HOTOVÉ (v0.7.57, 23.8.)** *Rez auditom na 4 PR:* ~~2a sekcia (kanál, obsah 1:1, #205)~~ · ~~2b Demos+UNI+zánik okna (#206, v0.7.48)~~ · ~~**2c D-69 editor** — 2c-1 rozšírenie nx_modal (#208) · 2c-2a atomická `Materials.save_decor` + „Upraviť…" (#212) · 2c-2b „Pridať ručne" (mode `create`) + zánik batchového zakladania (#213, v0.7.55)~~ — **HOTOVÉ, D-69 KOMPLET** · ~~**2d** „Kde sa používa" + deep-link z karty dielca + ⋯ editor rozpočtu na D-15 kostre (#214, v0.7.57)~~ — **CELÁ ŠT-2 HOTOVÁ** (23.8.; selektor cez efektívny materiál z BOM — dedené dielce sa označia tiež; nová in-SU sekcia `run_st2d`; plný text v [archiv/KRONIKA.md](KRONIKA.md)).
- ~~**ŠT-3** (M) **Kovanie · Pravidlá · Šablóny** (Š16–Š18) — tri okná zanikajú.~~ — **HOTOVÉ (v0.7.68, 24.8.)** *Rez (23.8.):* ~~**3a-1** sekcia Kovanie — čítanie + KATALÓGOVÉ zápisy, okno ešte žije (#216, v0.7.59)~~ · ~~**3a-2** modelové zápisy (predvoľby setov projektu) + **zánik okna Katalóg kovania** + in-SU sekcia `run_st3a` (#218, v0.7.60)~~ · ~~**3a-3** dlh sekcie Kovanie — rozdelenie „nastav dáta"/„kresli", jednotný `abort_open_operation`, odmietnutý reset cez `resync_sets`, čistenie filtra, lepkavá MJ, zhody Demosu po návrate (#219, v0.7.61)~~ — **ŠT-3a HOTOVÁ** · ~~**3b-1** sekcia Pravidlá — presun formulára „Kovanie podľa rozmerov", okno zaniká (#220, v0.7.62)~~ · **3b-2 — auditom narezaná (24.8.) na TRI PR:** ~~**3b-2a** skupina „ABS podľa roly" (read-only, texty skladá server) + jantárové riadky ručných zásahov BEZ akcií, len zobrazenie a oko + oprava klamlivého hintu (#221, v0.7.63)~~ · ~~**3b-2b** obe cesty **„vrátiť na pravidlo"** so zdieľaným zapisovacím telom, guardmi (dokument · generácia okna · nejednoznačné `cabinet_id` = odmietnutie) a in-SU scenármi (#222, v0.7.64)~~ · **3b-2c auditom narezaná na DVE:** ~~**3b-2c1** serverová validácia pásiem a radov (čistá `rules_problems` len v ceste uloženia) + parita s klientom cez spoločnú fixtúru + echo v save vetve + bezpodmienečná in-SU undo kontrola (#223, v0.7.65)~~ · ~~**3b-2c2** odtlačok pravidiel `rules_rev` zo servera (druhá vrstva pod baseline guardom; #224, v0.7.66)~~ — **CELÁ ŠT-3b HOTOVÁ** · **3c** Šablóny (Š18) — *rez:* ~~**3c-1** sekcia + existujúce akcie + zánik okna (#225, v0.7.67)~~ · ~~**3c-2** premenovanie šablóny — in-place rename pod jedným zámkom, presun PNG aj pečiatky „naposledy použité", D-15 modal, ktorý sa pri odmietnutí nezatvára (#226, v0.7.68)~~ — **CELÁ ŠT-3 HOTOVÁ**.
- ~~**ŠT-4** (S) **Nastavenia** (Š19) + upratanie.~~ — **HOTOVÉ (v0.8.0, 24.8.)** *Rez:* ~~**4a** sekcia Nastavenia (`sup` · `bset` · `about`) + **ZÁNIK POSLEDNÉHO SATELITU** — okno „Nastavenia rozpočtu" zaniklo, s ním celá mašinéria premostení (`WINDOW_BRIDGES`/`BRIDGE_STATUS`/`do_bridge`/`bridge_window`/`studio_bridge`/`.nbridge`), ⚙ Rozpočtu prepína sekciu a „O plugine" je zdieľaný obsah s dvoma vstupmi (#227, v0.7.69)~~ · ~~**4b uzáver fázy ŠTÚDIO** — docs, **minor bump 0.8.0** + `?v=`, README, KRONIKA plný uzáver fázy, STAV/PLAN, UI20_KONTRAKT (finálne vedomé odchýlky) (#228, v0.8.0)~~ — **CELÁ FÁZA ŠTÚDIO KOMPLET**. *(Upratanie `open_tab` → `studioOpen` sa ukázalo ako už hotové: v kóde pluginu nebol ani jeden živý výskyt — meno žije len v REFUTE guarde (`test_uid3_klikatelnost.rb`) a v historických zápisoch.)*


**~~PICKER — vyhľadávač materiálov~~ — HOTOVÉ (v0.8.3, 25.8.)** — dve drobné dávky z debaty nad testom v0.8.0, mimo blokov: ~~**PICKER-1** predvoľby projektu na `nx_combo` + šírka ponuky ako pravidlo (#230, v0.8.2)~~ · ~~**PICKER-2** riadok = dekor, hrúbka čipom (#231, v0.8.3) — zoskupenie v rámci rovnakého TYPU dosky, predvoľba podľa kontextu výberu, duplák výhradne vedomým klikom, hľadanie „36"/„duplák" preselektuje čip; pri tom zaniklo vedomé obmedzenie PICKER-1 — skupina „Použité v projekte" je aj v Štúdiu (`mat.used_ids` z už zozbieraného kusovníka)~~. Plné texty v [archiv/KRONIKA.md](KRONIKA.md).

*(Z vízie V1 sú v koncepte zapracované: header ako prístup ku všetkému UX-02 → UI-B1 · karta Zóna so smerovými ikonami UX-06 → UI-C2 · polia šírkou podľa obsahu UX-03 → UI-B1/UI-C.)*

*(Seed katalógu ako krok je ZRUŠENÝ (Michal 10.8.) — katalóg rastie sám prácou na zákazkách; skutočný problém „nájsť materiál aj v malom zozname" rieši D-85 — **hotová 18.8. (PR #167)**. Podklad kódov a cien ostáva v [zdroje/SEED_KATALOG_2026-07.md](../zdroje/SEED_KATALOG_2026-07.md).)*

## PICKER-3 · dorobenie vyhľadávača materiálov — HOTOVÉ (v0.8.5, 26.8.2026)

*(Plný text bloku tak, ako stál v [../PLAN.md](../PLAN.md) pred uzáverom — presunutý, nie skopírovaný.
Výsledok, rozhodnutia a zamietnuté alternatívy pri bodoch A a E sú v [KRONIKA.md](KRONIKA.md).)*

**Odčlenené z PR #231 podľa pravidla 3 kôl (25.8.)** — kolo 3 Codex review prinieslo osem
vecných nálezov; **ship-blockery sa opravili v #231**, zvyšok je tu. Dôvod rezu: bod **E**
je **návrhová zmena** (kontext výberu má radiť aj riadky medzi sebou), a tá si zaslúži
vlastný návrh + review, nie ďalšiu iteráciu v dobiehajúcom PR — doťahovačky idú s ňou,
aby sa okruh riešil naraz. Poradie určí Michal; nič z toho nie je blokujúce (vyhľadávač je
použiteľný), ale všetko je pomenované, aby sa to nestratilo.

- **A · Virtuálne dupláky v kontexte menovky riadku** (`noxun_engine/ui/panel/payloads.rb`, comment **3848691739**, P2). Kontext `row_fam_ctx` vidí len `Materials.sheets`, takže rodinu s jednou
  kúpenou hrúbkou plus virtuálnou ponukou `duplak2:` označí za jednovariantnú a server pošle menovku „Dekor · DTDL 18 mm". Klient potom na ten istý riadok pridá čip `36 duplák` — a po jeho výbere
  menovka riadku ďalej tvrdí 18 mm. Fix: postaviť kontext s virtuálnymi variantmi, alebo hrúbku v menovke potlačiť vždy, keď riadok čipy dostane.
- **B · Normalizovať VŠETKY zložky kľúča rodiny** (`noxun_engine/core/materials.rb`, comment **3848691741**, P2). Kanonická je zatiaľ len skupinová časť; `decor`, `structure`, `type` a prípona idú v
  surovom orezanom tvare. Katalógový kontrakt pritom identity typu a štruktúry porovnáva **bez ohľadu na veľkosť písmen**, takže `DTDL`/`dtdl` alebo `ST9`/`st9` dostanú rôzne kľúče a dekor sa v ponuke
  zjaví ako **dva riadky**. Fix: skladať rodinu z normalizovaných zložiek (ideálne z kanonickej identity dosky bez hrúbky).
- **C · Dotaz „54 duplák" musí trafiť SVOJ duplák** (`noxun_engine/ui/js/nx_combo.js`, comment **3848691744**, P2). Keď má rodina duplák ×2 aj ×3, slovo „duplák" v dotaze vráti **prvý** duplák (spravidla 36 mm) ešte pred prečítaním čísla. Riadok sa nájde, ale Enter vloží iný duplák, než dotaz menoval. Fix: pri slovnom dotaze najprv hľadať zhodu hrúbky medzi duplákmi a až potom padať na prvý.
- **D · Dôvod nedostupného čipu aj z KLÁVESNICE** (`noxun_engine/ui/js/nx_combo.js`, comment **3848691758**, P2). Po prechode na `aria-disabled` je čip fokusovateľný, ale jediná klávesová cesta (šípky
  vľavo/vpravo) nedostupné varianty **preskakuje** a `Tab` ponuku zatvára — človek od klávesnice sa teda k vysvetleniu, ktoré myš dostane klikom, nedostane. Fix: pustiť fokus do tlačidiel čipov, alebo
  dať klávesovú akciu, ktorá na nedostupnom čipe zastane a dôvod oznámi.
- **E · KONTEXT VÝBERU MÁ RADIŤ AJ RIADKY (návrhová zmena)** (`noxun_engine/ui/js/nx_combo.js`, comment **3848691761**, P2 — vecne najväčší). Kontext (`back` → 3 mm, `worktop` → 38) sa dnes uplatňuje
  **vnútri** už rozdelenej rodiny, takže nevie uprednostniť riadok HDF 3 pred riadkom DTDL 18 toho istého dekoru. V Štúdiu je `md_back` naplnený **všetkými** doskami bez zakázania nechrbtových
  variantov: po napísaní dekoru je prvý zhodný riadok spravidla DTDL, jeho predvoľba je 18 mm a Enter ju vloží — hoci kontext „chrbát" sľubuje HDF 3. Fix: kontext musí riadky **radiť alebo filtrovať**
  predtým, než sa vyberie aktívny riadok, nielen hľadať 3 mm vnútri každého z nich.
- ✅ **1c — AUDIT KÓDU** (hotové 29.8.2026; read-only, žiadny kód sa nemenil): tri nezávislé pohľady nad main v0.8.13 — externý Codex audit (spúšťal Michal, podklad `../zdroje/AUDIT_2026-08_podklad.md`, výstup `../zdroje/AUDIT_2026-08_externy_codex.md`: 2×P0 + R-01–R-15 + kostry 18 docs stubov) · Fable prechod (osi observery/production_core/identita — všetky externé nálezy v osiach potvrdené dôkazmi, R-02 rozšírený na 14 handlerov bez guardu dokumentu) · slepý subagent (osi sety/perzistencia/UI vzory — 15 nálezov S-01–S-15, o.i. dĺžkové kovanie nacenené ako kusy a chýbajúca dopredná kompatibilita knižníc). Zliate s dedupom + kandidátmi zo sweepu (`../zdroje/SWEEP_2026-08_kandidati.md`) do **`../AUDIT_REGISTER.md`**: 2×P0 eskalované ako okamžitá hotfix dávka (exportné brány) · 33 registrových položiek s prioritami, blokovanou funkciou a odhadmi · odporúčané poradie pre blok 1d · 2 otvorené rozhodnutia Michala. Proces: Codex review #250 nad samotným auditom priniesol 4 protinázory (najmä: brána exportu nesmie plošne blokovať legitímne rozpracovaný rozpočet — STANDARD §11.3 má prednosť; firewall CP ostáva report-only) — dispozície v threadoch PR #250, zapracované do registra aj do P0 dizajnu. Pôvodné zadanie bloku: tri pohľady → register R-čísel s väzbou na blokovanú funkciu; prioritné osi od budúcich funkcií dozadu (GHOST → KOVANIE → výstupy → identita → perzistencia → UI vzory → docs stuby); mimo záberu prepisy funkčného, premenovania, vizuál, výkon bez merania, nové funkcie.

  **Plné pôvodné znenie bloku 1c z PLAN.md (pred uzáverom):**

  > **Cieľ:** pripraviť plugin na naplánované funkcie a pomenovať všetky nedorobky. **Žiadny kód sa nemení** — výstupom je **register nálezov** (nový súbor `SYSTEM/AUDIT_REGISTER.md`, štýl DOGFOODINGu: R-číslo · závažnosť **P0 (len ako pointer na okamžitú hotfix dávku s výsledkom — nečaká v registri)** / P1–P3 · vrstva · súbor · **ktorú naplánovanú funkciu blokuje** · návrh riešenia). Audit, ktorý rovno opravuje, sa nedá kontrolovať.
  > - **Tri nezávislé pohľady:** externý Codex audit (spúšťa Michal; podklad: `../zdroje/AUDIT_2026-08_podklad.md`) · vlastný prechod (Fable) · slepý subagent. Nálezy sa zlejú do jedného registra s dedupom.
  > - **Vstup, ktorý už čaká:** `../zdroje/SWEEP_2026-08_kandidati.md` — nálezy z post-hoc sweepu #186–#226: sekcia **A** 7 z hlavnej session sweepu · sekcia **B** 18 z triáže review threadov (*z toho B1 je už vyriešené, otvorených 17*) · sekcia **C** 13 ďalších z bloku 1b (*C4 a C5 sú tiež už vyriešené*). Každý má adresu v kóde. **Prvý krok bloku 1c je preliať tento zoznam do registra**, v tomto poradí: **(1)** dedup (známe zhody sú v zozname vymenované) → **(2)** vyradiť to, čo je medzitým hotové alebo už má dávku → **(3)** overiť proti vtedajšiemu `main` (čísla riadkov sú k `0070697`, `ui/production_core.rb` sa medzitým posunul) → **(4)** až potom priradiť R-číslo, závažnosť, vrstvu a blokovanú funkciu.
  > - **Prioritné osi auditu** (od budúcich funkcií dozadu): observery/undo/Tool lifecycle (→ GHOST) · dátový model setov kovania (→ D-109/KOVANIE) · `ui/production_core.rb` — jadro výstupov v UI vrstve (→ Ponuka/plošná kontrola) · payload kontrakty a identita · perzistencia, `std` verzie, migrácie (→ shared library) · zjednotenie UI vzorov na nx_modal/nx_combo · VŠETKY aktuálne stub odseky architektúry (k 26.8. ich je 19; zoznam grepom, detail v podklade).
  > - **Mimo záberu** (zapísané aj v podklade): prepisovanie funkčných builderov a zapisovacích ciest · hromadné premenovania · vizuál Inspectora/Štúdia · predčasné abstrakcie pre neschválené funkcie (attachment/segmenty) · výkon bez merania.

## Blok GHOST VKLADANIE (V1-04) — HOTOVÉ (v0.9.0, 31.8.2026)

> **Presunuté z [../PLAN.md](../PLAN.md) 31.8.2026** pri uzávere bloku — v PLANe už neostáva.
> Nasleduje plný pôvodný text task package vrátane zadania, uzavretých volieb, smoke checklistu
> aj checklistu uzáveru. Text sa nemenil — upravené sú výhradne relatívne cesty odkazov
> (súbor leží o úroveň nižšie). Priebeh dávok, implementačný audit a poučenia sú
> v [KRONIKA.md](KRONIKA.md) (záznamy **GHOST VKLADANIE**, **GHOST-FB**, **GHOST-FB · POZÍCIA PÁSIKA**
> a **UZÁVER BLOKU GHOST VKLADANIE**).

**Výsledok uzáveru (31.8.2026, v0.9.0):**

- **Čo blok priniesol používateľovi:** skrinka sa už nekladie naslepo cez `next_x` mimo pohľadu — po „Vložiť" visí na kurzore
  ghost s čitateľnou zelenou prednou stenou a viditeľnou aktívnou kotvou, ←/→ ho otáčajú o 90°, ↓/↑ prepínajú výškový zámok
  a voľnú výšku, Alt cykluje kotvy a klik položí **jednu reálnu skrinku v jednom Undo kroku** presne tam, kde ghost stál.
  V zámku sa ghost prichytáva na rohy a hrany existujúcich skriniek (X/Y zo snapu, výšku drží zámok) a **Ghost pásik**
  pod sektorom Náhľad ukazuje kotvu, otočenie, režim a editovateľnú zamknutú výšku; nastavenia si pamätá do zatvorenia SketchUpu.
- **PR bloku:** **#265** (predpoklad R-03 — šev `prepare_insert` + `build(transform:)`, v0.8.20) · **#268** (Tool + PlacementSession
  + in-SU sada `run_ghost`, v0.8.22) · **#270** (GHOST-FB — hybrid snap v zámku, natívne zvýraznenie, kotva pod kurzorom,
  pamäť nastavení, Ghost pásik, v0.8.23/v0.8.24) · **#271** (pásik samostatne pod Náhľadom + jasná zelená predná stena, v0.8.25)
  · **uzáver bloku #272** (minor bump **v0.9.0**, presun tohto textu do archívu).
- **Testy pri uzávere:** **2217 headless** · **75 JS sád** · plný in-SketchUp beh **1217 PASS / 0 FAIL**.
- **Michalov smoke 31.8.2026 večer — PASS celý checklist:** základné body 1–6 (ghost na kurzore so šípkami hneď, rotácia okolo kotvy,
  ↓ domáca výška / ↑ voľná, **Alt prepína kotvy a menu lišta SketchUpu sa neaktivuje — zapísaný fallback TAB sa teda nepoužil**,
  klik = presne jedna skrinka a jeden Ctrl+Z ju vráti, Esc nič nevloží, orbit ghost prežije, horný korpus aj šablóna s kovaním
  aj vloženie z editácie skupiny) **a doplnkové body 7–11** z dávky GHOST-FB (snap vo výškovom zámku, kotva skočí pod kurzor,
  pásik viditeľný pod Náhľadom aj pri vklade dvojklikom na šablónu, pole výšky vrátane odmietnutia nezmyslu, pamäť nastavení).
- **Tým istým sedením potvrdené aj staršie odložené smoke testy** z blokov 1b/1d: **R-08** (dve okná SketchUpu, dva rôzne sety kovania —
  ostali oba) · **R-01+R-04** (skrinka so zónami, zmazanie, Ctrl+Z a neplatné zväčšenie) · **R-02** (dve okná — oneskorená zmena skončí
  hláškou „patrí inému dokumentu") · **R-07** (Štúdio → Kovanie → Sety vyzerá a funguje ako doteraz, banner sa neukázal).
- **V1_VIZIA bod 1 ostáva `[ ]`** podľa checklistu uzáveru — rozsah bodu nie je prázdny (zostavy a snap k susedom rieši blok „V1.0 zostavy").

**Pôvodný plný text bloku z [../PLAN.md](../PLAN.md):**

### GHOST VKLADANIE (V1-04) — TASK PACKAGE (1e, zapísané 29.8.2026, rev. po slepom review #254; štart na Michalovo „štartuj")

**STAV BLOKU (30.8.2026): implementačná dávka je ✅ HOTOVÁ — v0.8.22.** Modul `core/ghost_tool.rb` (GhostTool + Calc + PlacementSession + Tool), šev v `handle_insert`,
cancel pri zavretí Inspectora aj pri prepnutí dokumentu; **35 headless testov** novej sady + in-SU sekcie `run_ghost` (17 scenárov) a `run_ghost_async`,
plný beh **1184 PASS / 0 FAIL** (headless celkovo 2173, 74 JS sád).
Plný záznam — čo pridal implementačný audit (4 BLOCKER + 5 FIX), vedomý posun F8 hlášky na klik a ako je nástroj simulovaný v testoch: [archiv/KRONIKA.md](KRONIKA.md),
záznam **GHOST VKLADANIE**. **Blok ostáva OTVORENÝ do Michalovho smoke** (body nižšie); uzáver = samostatný malý PR s **minor bumpom 0.9.0** a presunom bloku do archívu.

**Dávka GHOST-FB (v0.8.23, 31.8.) — ✅ HOTOVÁ, blok ostáva otvorený.** Odpoveď na Michalov živý test: koreňom problémov bol výškový zámok bez prichytávania.
Pribudlo: **hybrid v zámku** (inference dá X/Y, zámok Z) + **natívne zvýraznenie snapov** (`ip.draw` + tooltip v oboch režimoch) · **kotva vždy pod kurzorom**
(aj po Alt) · **pamäť kotvy/rotácie/režimu/výšok** do vypnutia SketchUpu (bez zápisu na disk aj do modelu) · **Ghost pásik** v Inspectore s editovateľnou
zamknutou výškou (default dolná 0, horná 1400 = 850 + 550). Smoke body 7–11 nižšie.
**Následný fix (v0.8.25, 31.8.):** pásik sa presunul **z vnútra sektora Materiály** na samostatné miesto **pod sektor Náhľad** — pri vklade dvojklikom na šablónu
ho zbalený sektor schoval, takže o bežiacej session hovoril len status. Viditeľnosť riadi už len vlastný `hidden`; guard test to stráži.
Tou istou dávkou dostala **predná stena ghostu jasnú zelenú** (#00C85A) — pôvodný tmavý teal splýval s obrysom ghostu aj s čiernymi hranami modelu. Zvyšok ghost smoke = PASS.

**Cieľ:** vloženie skrinky tam, kde sa používateľ pozerá — po „Vložiť" visí ghost skrinky na kurzore,
klik ju položí ako jednu reálnu CAB v jednom Undo kroku. Koniec hľadania skriniek položených cez `next_x`
mimo pohľadu. Podklady: koncepty [09](../zdroje/next_sessions/09_GHOST_VKLADANIE.md) + [09A](../zdroje/next_sessions/09A_GHOST_EXTERNY_SKETCHUP_AUDIT.md)
— package z nich preberá schválený kontrakt s JEDNOU vedomou zmenou: ↓ pre horný korpus drží
`UPPER_HANG_Z`, nie podlahu (09 mal floor lock pre oba typy; zámok typu zachováva dnešné správanie buildera).
Otvorené voľby uzatvára nižšie.

**Predpoklady ([AUDIT_REGISTER.md](../AUDIT_REGISTER.md)):** TVRDÝ blocker **R-03** (šev `prepare_insert` +
`build(..., transform:)`) je **✅ HOTOVÝ (v0.8.20, 30.8.)** — package tým môže štartovať. Tool dostáva `prepare_insert`
(zmrazený plán viazaný na dokument, žiadny zásah do modelu pred klikom) a `commit_insert(..., transform:)`, ktorý prijme
len RIGIDNÚ transformáciu; `bounds_mm`/kotvy si GHOST dávka uzavrie sama proti `BuildPlan`u. **R-01** (✅ v0.8.17)
a **R-02** (✅ v0.8.19 — guard identity dokumentu má aj INSERT cesta, `foreign_document?` + `nxDocPayload`)
sú macOS-vetvové a **sú hotové**; **R-04** (✅ v0.8.17) bola hygiena bez platformového kvalifikátora a išla spolu
s R-01. Odchýlka od poradia registra je zapísaná aj v ňom.

**Scope IN:** SketchUp `Tool` — ghost = čistá viewport grafika cez `draw(view)` s **čitateľnou prednou stranou
a VIDITEĽNÝM aktívnym anchorom** (bez toho sa prepínanie kotiev nedá kontrolovať), `InputPoint` inference,
`getExtents` pre kreslenie mimo bounds · PlacementSession viazaná na `model_guid` (prepnutie dokumentu = cancel,
NIKDY cross-document insert) · rotácia ←/→ o 90° okolo aktívneho anchoru · 4 anchory na PREDNEJ rovine KORPUSU
(nie čiel; presné súradnice per konštrukčný variant určí implementačný audit proti BuildPlanu) · **Z režimy:
↓ = VÝŠKOVÝ ZÁMOK TYPU** (LOKÁLNY PLACEMENT ORIGIN korpusu — presne to, čo dnes kladie translácia buildera:
dolný na world Z=0, horný na `UPPER_HANG_Z` —
zámok drží Z bez ohľadu na inference; world rám, nie drawing axes; X/Y sa v zámku berie z ray×ROVINA ZÁMKU —
pri dolnej Z=0, pri hornej Z=`UPPER_HANG_Z`, aby ghost sedel pod kurzorom; funguje aj v prázdnom modeli)
**a ↑ = free Z** (plný inference point) — **oba typy ŠTARTUJÚ v zámku svojej domácej výšky** (zachováva dnešné
správanie: horná pristane na 1400, kým používateľ vedome nestlačí ↑) · commit VŽDY top-level v koreňovom ráme
(`ensure_root_context` vzor buildera — aj keď je používateľ v nested edit kontexte; in-SU scenár povinný) ·
commit = `prepare_insert` snapshot → `build(transform:)` + hardware freeze v TEJ ISTEJ operácii → select novej
CAB → push → template usage stamp až PO úspechu · **preflighty sa NEduplikujú do Tool triedy** (Tool rieši
polohu, nie výrobné pravidlá — 09 §3) · Escape/onCancel/Undo počas ghostu = 0 mutácií modelu, 0 Undo krokov ·
Orbit/Pan suspend/resume drží session · `Sketchup.focus` po štarte z HtmlDialogu (klávesy fungujú bez extra
kliku) · status bar nápoveda · po vložení tool KONČÍ cez štandardný tool stack (návrat do bežného SketchUp
workflow) a Inspector pokračuje editáciou novej CAB; po commite sa notifikuje aj StudioModelWatch (stale
signalizácia) — nielen ScaleWatch/dedup.

**Správanie Inspectora POČAS aktívnej session (uzavreté):** snapshot je zmrazený v `prepare_insert` — zmeny
vo vkladacej karte sa do bežiacej session NEPREMIETAJÚ (status to prizná) · druhý klik na „Vložiť" zruší starú
session a založí novú s čerstvým snapshotom · zavretie Inspectora session ZRUŠÍ (cancel, 0 mutácií).

**Scope OUT (vedome NErobí):** „vložiť vedľa vybranej" · snap k NOXUN korpusom · attachment/segmenty ·
auto-orientácia podľa steny · repeat-placement · ďalšie anchor body · 2D HUD/overlay framework ·
zmena `insert_copy` a board placementu · náhrada `Placement.next_x` (ostáva fallback pre programatické cesty).

**UZAVRETÉ VOĽBY package (Michal potvrdí pri „štartuj", inak platia tieto):** (1) cyklovanie anchorov =
**Alt/Option** (odporúčanie 09A — konvencia SketchUp Move gripov; TAB má verziové/fokusové pasce). POZOR:
Alt je na Windows systémová klávesa — **implementačný audit MUSÍ Alt overiť** (spolu s onCancel reasons a
arrow ownership) a in-SU sada ho testuje; zapísaný fallback = TAB, ak Alt neprejde. (2) Z režimy a štart podľa
Scope IN (výškový zámok typu; horná NIKDY neštartuje vo free Z). (3) Klávesy ← → ↑ ↓ Tool vedome preberá od
inference locku POČAS aktívneho ghostu; spotrebúvajú sa LEN klávesy, ktoré ghost vlastní.

**Dotknuté dáta/kontrakt → AUDIT: ÁNO (codex-audit pred implementáciou povinný).** Nový modul (Tool) + zásah
do insert lifecycle; dátový kontrakt entít sa NEMENÍ (CAB vzniká štandardným builderom), ale Tool lifecycle
je observer-citlivá oblasť. Implementačný audit navyše MUSÍ uzavrieť: presné anchor súradnice pre
under_sides/between_sides/upper a atypy · `onCancel` reasons pre podporované SU verzie · arrow-key ownership ·
funkčnosť Alt na Windows.

**Testy a DoD:** headless — čistá transform matematika (4 rotácie × 4 anchory; anchor ostáva na inference bode
po rotácii; zámok/free prechody nemenia X/Y; Escape v každom stave = nulový zápis). **In-SU POVINNÉ** (sekcia
`run_ghost`): pred klikom 0 NOXUN entít · klik = presne 1 CAB na očakávanom transforme · 1× Ctrl+Z vráti celé ·
nová CAB označená v Inspectore · lower (Z=0) aj upper (`UPPER_HANG_Z` pri zámku) · free Z na bode s nenulovým
Z · šablóna s materiálmi/kovaním + zámky karty · usage stamp len po úspechu · zámok pri otočených axes · ghost
ďaleko mimo bounds (getExtents) · prázdny model bez podlahovej face · Undo počas ghostu · prepnutie dokumentu =
bezpečný cancel · **nested edit context → commit top-level so správnym transformom** · Alt cyklovanie · druhé
„Vložiť" počas session · regresie: programatický `build` cez fallback, ScaleWatch/dedup nevyrobí druhú CAB ani
extra Undo. Mutačné overenie štandard. DoD = všetky scenáre zelené + smoke checklist Michala prejde.

**Odhad náročnosti: L** (po R-03; Tool + session + in-SU sada). Poradie cyklu anchorov určí implementácia
(kandidát z 09: ľavý spodný → pravý spodný → pravý horný → ľavý horný).
**Riziká:** Tool lifecycle (focus z CEF, onCancel/Undo, suspend/resume) — najväčšie, kryté in-SU scenármi ·
Alt na Windows (overí audit, fallback TAB) · geometria anchorov pri atypických konštrukciách (uzavrie audit) ·
SU verzie (pixely/klávesy — držať ghost čisto 3D). Rez dávky: Tool + session v JEDNEJ dávke, R-03 šev PREDTÝM
samostatne — nikdy nie jeden obrí PR.

**Smoke checklist pre Michala (po nasadení):** 1) „Vložiť" → ghost visí na kurzore, vidno prednú stranu aj
aktívnu kotvu, šípky fungujú HNEĎ (bez kliku do modelu). 2) ←/→ točí okolo kotvy, ↓ drží skrinku na domácej výške
(dolná na zemi, horná na 1400), ↑ ju pustí do voľnej výšky. **2b) Alt prepína kotvy (a vidno, ktorá je aktívna) — a menu lišta SketchUpu sa pritom NEAKTIVUJE.**
*(Systémové doručenie Alt sa programovo overiť nedá — testy overujú len handler, tento bod je jediný dôkaz; ak Alt neprejde, zapísaný fallback je TAB.)*
3) Klik položí skrinku presne tam, kde bol ghost; jeden Ctrl+Z ju celú vráti. 4) Esc nič nevloží a nič
nepribudne v Undo. 5) Počas ghostu si zorbituj pohľad — ghost prežije. 6) Skús horný korpus, šablónu s kovaním
a vloženie, keď si v editácii skupiny (skrinka musí skončiť top-level).

**Doplnok smoke checklistu po dávke GHOST-FB (v0.8.23, feedback z tvojho testu 30./31.8.):**
7) **Snap vo výškovom zámku** — nabehni myšou na roh susednej skrinky (aj keď je 720 mm nad zemou): musí sa objaviť
farebný bod a tooltip ako pri Move a ghost sa zarovná v X/Y s tým rohom, pričom **výšku drží zámok**.
8) **Kotva skočí pod kurzor** — Alt prepne kotvu a skrinka sa presunie tak, aby nová kotva bola presne pod myšou
(žiadne „skrinka ostala vedľa"). 9) **Pásik pod Náhľadom** — počas ghostu vidno hore v paneli (hneď pod sektorom Náhľad,
teda aj pri vklade **dvojklikom na šablónu**, keď sú sektory zbalené) riadok s kotvou, otočením, režimom
a poľom výšky; **po vložení aj po Esc zmizne**. 10) **Pole výšky** — napíš 20 mm a klikni: skrinka sadne na 20;
nezmysel („dvadsať", 9999) hodnotu nezmení a panel to povie. 11) **Pamäť** — po vložení stlač „Vložiť" znova:
kotva, otočenie, režim aj zamknutá výška ostanú tam, kde si ich nechal (do zatvorenia SketchUpu).

**Checklist uzáveru (blok GHOST sa uzatvára CELÝ):** **bump MINOR** (uzáver bloku podľa CLAUDE.md) + `?v=` →
testy (headless + JS ak UI + **plný in-SU beh**) → docs (`construction.md` odsek Tool/PlacementSession +
`ui-lifecycle.md` insert cesta + ARCHITEKTURA router riadok) → STAV/KRONIKA → **blok presunúť plným textom do
[archiv/ROADMAP_hotove_etapy.md](ROADMAP_hotove_etapy.md)** (v PLANe neostáva) → V1_VIZIA **bod 1 ostáva `[ ]`**
(rozsah bodu nie je prázdny — zostavy); hotovosť GHOST-u zaznamená KRONIKA a presun bloku do archívu.

## Blok KOVANIE — HOTOVÉ (v0.9.14 → v0.10.0, 2.–10.9.2026)

> **Presunuté z [../PLAN.md](../PLAN.md) 10.9.2026** pri uzávere bloku — v PLANe už neostáva.
> Nasleduje plný pôvodný text bloku vrátane všetkých task packages (slices 0 · A · H · B · C · D · W · F · E · G · I),
> uzavretých rozhodnutí, smoke checklistov a výsledkov jednotlivých dávok. Text sa nemenil — upravené sú výhradne
> relatívne cesty odkazov (súbor leží o úroveň nižšie), doplnený je výsledok poslednej dávky **KOV-I** a poznámky
> o dvoch položkách, ktoré hotové NIE SÚ a preto ostali v živom pláne (**D-114** balík Čiel + **Mimo V1** zásobník).
> Priebeh dávok, review kolá a poučenia sú v [KRONIKA.md](KRONIKA.md) (záznamy **KOV-A** … **KOV-G**, **KOV-W**,
> **D-118**, **D-121** a **UZÁVER BLOKU KOVANIE**); vyriešené postrehy v [DOGFOODING_vyriesene.md](DOGFOODING_vyriesene.md).

**Výsledok uzáveru (10.9.2026, v0.10.0):**

- **Čo blok priniesol používateľovi — plugin odteraz vie kovanie sám:** sety a katalógové položky sú **klasifikované**
  (typ použitia · otváranie · konštrukcia zásuvky · výrobca · rada) a katalóg so stromom Kategória → Výrobca → Rada aj
  editorom setu so živým náhľadom žije v Štúdiu · **zásuvka vzniká z nemenného receptu** (Atira, Quadro V6 — dielce,
  výška, NL a nosnosť z receptu, objednávacie kódy kitu zo setu kovania; žiadny fallback na inú NL kvôli chýbajúcemu kódu) a dá sa jej
  zamknúť os aj povýšiť recept · **závesy** sa počítajú podľa Noxun tabuľky a Tip-On má vlastný set · **výklopy**
  AVENTOS **HK top / HL top** si nájdu silový variant z výšky a **hmotnosti čela** (KOV-W dala hmotnosť dielcov aj čiel
  do Inspectora) · **nohy 4/6 podľa šírky korpusu** a **príchyt sokla** sa objavia už pri vkladaní, s vetou v Základných ·
  **šablóny** vedia uložiť aj kovanie (voľba + súhrn na dlaždici) · **ad-hoc kovanie** sa pridá k skrinke alebo čelu priamo
  v Inspectore · katalóg pozná **kódy, ktoré si plugin sám objednáva** (114 položiek zo seedu D-118 + AXILO/STRONG z KOV-G) ·
  **updater D-52** (Aktualizovať jedným klikom) bol vstupnou podmienkou celého bloku, lebo blok priniesol sériu schema bumpov.
- **PR bloku (50 PR, #277 → #340):** slice 0 **D-52 updater** #277–#279 (v0.9.14) · **KOV-A** čelá a smery #280–#282 + smoke fix #286 ·
  **KOV-H** ad-hoc kovanie #283 + #285 · **KOV-B** sety, katalóg, editor #284 + #290 + #297 · **KOV-C** recepty zásuviek #301–#306 ·
  **KOV-D** ovládanie zásuviek #307–#318 · **D-118** katalógový seed #319–#321 · **D-121** názvy dielcov a VEPO #324–#326 ·
  packages W/F/E #327 · **KOV-W** hmotnosť #328 · **KOV-F** závesy #329 + #330 · **KOV-E** výklopy #331–#334 + fixy #335/#336 ·
  **KOV-G** nohy a príchyty #337–#339 · **KOV-I** šablóny s kovaním #340 · **uzáver bloku** (minor bump **v0.10.0**, presun tohto textu do archívu).
- **Testy pri uzávere:** **3788 headless** · **105 JS sád** · in-SketchUp **2134 PASS / 0 FAIL** nad hlavou KOV-I `c6b0c94` (10.9.2026).
- **Kľúčové rozhodnutia bloku:** **O1–O3** z architektúry V1 · **nemenné recepty** (fyzika v recepte, objednávacie kódy v setoch —
  dve vrstvy, každá s jednou zodpovednosťou) · **nákup nikdy nemení fyzický návrh** (chýbajúci kód = RED a rozhodne človek) ·
  **EB pevné per recept** · príchyt sokla **1 ks na začaté 4 nohy zo šírky korpusu** (pomerová mechanika D-109 ostáva R-05 po V1) ·
  **R12: zámky sa do šablóny neprenášajú** a UI to priznáva · zóna sokla **20–55 mm ostáva vedome nepokrytá** (ORANGE, nie vymyslený produkt).
- **Čo z bloku NIE JE hotové a žije ďalej v [../PLAN.md](../PLAN.md):** **D-114** UI/UX balík kontextu Čelá (rad piktogramov
  namiesto textových tlačidiel, upratanie karty) spolu s **D-119** (presah dverí per strana) a **D-120** (úchytkový profil na
  ďalších hranách) — presunuté do bloku **4 · V1 DOTIAHNUTIE** · zoznam **Mimo V1** (D-109 pomer, plný `per:'length'`, HF,
  Antaro/Strong/TANDEM, inner drawer automatika) — presunutý do sekcie **Po V1 — zásobník**.

**Pôvodný plný text bloku z [../PLAN.md](../PLAN.md):**

### KOVANIE (zaradené Michalom 26.8.2026; architektúra + UX UZAVRETÉ 2.9.2026)

**Autorita bloku:** [zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](../zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)
(po cross-audite Codex/GLM/Opus + reconcile + rozhodnutia O1–O3) · **UX referencia:** [zdroje/ui20/mockup_kovanie_v1.html](../zdroje/ui20/mockup_kovanie_v1.html)
(schválený 2.9.) · vendor dáta: checkpoint #10 · detail fill: checkpoint #11. Otvorený postreh D-109 je v packages nižšie (D-110 ✅ vyriešená KOV-B2, **D-111 ✅ vyriešená KOV-G2**)
(D-109 mechanika = R-05 po V1, výsledok už dáva KOV-G1b). **Predpoklad prvého schema bumpu: D-52 updater** (blok 6 — štartovaný 2.9.).
Poradie slices: **0 (D-52 ✅) → A1 ✅ → A2 ✅ → H1 ✅ → B1 ✅ → H2 ✅ → B2 ✅ → B3 ✅ → C ✅ → D ✅ → W ✅ → F ✅ → E ✅ → G ✅ → I (POSLEDNÁ)** (B po Codex audite #17 rezaná na B1 dáta+std / B2 katalóg UI / B3 editor setu)
(KOV-A rezaná po Codex audite #14 na A1 dátová vrstva / A2 UI+overlay; otázka 3/4 krídel rozhodnutá Michalom 3.9. — variant a); **KOV-C package v2 (5.9.2026)** nahradil v13 z PR #300 po simplification review (zásady: nemenné recepty, kódy v setoch, žiadny fallback NL, pevné EB) — KOV-D revidovaná podľa neho.
**KOV-A je KOMPLET a v maine** (A1 PR #280 · A2a PR #281 · A2b PR #282 — plné texty packages v git histórii a v checkpointe #14; záznamy dávok v [archiv/KRONIKA.md](KRONIKA.md)).
Každý package sa pred štartom krátko audituje proti aktuálnemu mainu (read-only), implementuje subagent v worktree, brány podľa CLAUDE.md.

**Postrehy zo smoku 3.9. (Michal, v0.9.20; otvorené plné texty v [DOGFOODING.md](../DOGFOODING.md), skupina KOVANIE):** **✅ D-115** symboly smeru = čiary z rohov strany pántov
(nie šípky), v náhľade aj vo viewporte — **HOTOVÉ (PR #286, v0.9.21)**, tvar má jediný zdroj per jazyk nad spoločnou fixtúrou a zásuvka dostala prerušované X ·
**✅ D-116** úchytkové profily na tag Čelá (dnes Kovanie) — **HOTOVÉ (PR #286, v0.9.21)**, vedomý dôsledok: prepínač Kovanie ich už neschová ·
**D-114** rad piktogramov namiesto „+ pridaj dvere/čelo" + upratanie kontextu Čelá — **UI/UX balík na koniec bloku** (OTVORENÉ — pri uzávere bloku 10.9.2026 **presunuté do bloku 4 · V1 DOTIAHNUTIE** v [PLAN.md](../PLAN.md) aj s D-119 a D-120; tu ostáva len historický kontext). Michal 3.9. potvrdil v smoku bez chýb: zmeny
všetkých typov, trojkrídlo + Kontrola vedie na neurčené čelo, medzery, všetky voľby otvárania/konštrukcie.

- **✅ HOTOVÉ (PR #284, v0.9.19)** — **KOV-B1 · TASK PACKAGE „KATALÓG A SETY — DÁTA, KLASIFIKÁCIA, TAXONÓMIA, STD" (slice B, rez B1 po Codex audite #17; štart po KOV-H1):**
  **Cieľ:** set aj položka katalógu nesú klasifikáciu (typ použitia · otváranie · konštrukcia zásuvky · výrobca · rada · aktívny), knižnica má verzovanú taxonómiu
  výrobcov/rád, downgrade brány držia aj pre šablóny, a KOV-D má hotový tvar mapovacieho kľúča — **bez UI** (B2/B3). Nákup existujúcich zákaziek CONTENT-identický.
  Rozhodnutia: [zdroje/next_sessions/KOVANIE_KOVB_AUDIT_2026-09-03_17.md](../zdroje/next_sessions/KOVANIE_KOVB_AUDIT_2026-09-03_17.md) (B1–B4, FIX 5–10, 13-server).
  **Scope IN:** `hardware_sets` — polia setu `use_type` (door|drawer|lift|fall|other) · `opening_mode` (classic|tipon|other) · `drawer_construction` (metal|wood|other,
  len drawer) · `manufacturer` · `series` · `active` (sparse: ukladá sa len `false`) → `SET_KEYS` + `normalize_sets` (tolerantné čítanie) + `validate_set` (zápis: klasifikácia
  buď úplne chýba = legacy „nezaradený", alebo úplná a kontextovo platná; **`generic_type` je ODVODENÝ** kanonickou mapou `door→hinge · drawer→slide · lift/fall→lift ·
  other→explicitný`; nekonzistencia = odmietnutie) · **`GENERIC_TYPES + lift`** + `plan_schema` bump (presunuté z KOV-E; `guard_unknown_hardware!` chráni starší plugin) ·
  `snapshot_std` obsahová detekcia: bumpne LEN pri prítomnom klasifikačnom poli alebo `class:` kľúči v mapovaní (legacy ostáva na pôvodnom std) · `assess_library_doc`
  whitelist rozšírený (R-07) · **kanonický mapovací kľúč pre KOV-D** `class:<generic_type>|<opening_mode>[|<drawer_construction>]` v `parse_mapping` (round-trip, whitelist,
  std detekcia; nič ho zatiaľ nečíta) · `active` nečítajú `expand`/`explain` (existujúce mapovanie, snapshot a šablóna expandujú identicky). **Šablóny (B1 blocker):**
  `CONFIG_SCHEMA` **3 → 4**; pri použití/vklade šablóny bezstratová kontrola `hardware_set_defs` (`assess_set_defs`, ten istý detektor) — novší tvar = odmietnutie BEZ zápisu
  do modelu. **Taxonómia:** nový store `core/hardware_taxonomy.rb` + `%APPDATA%\NOXUN\Engine\hardware_taxonomy.json` `{std, schema, manufacturers[], series[]}`, prísny
  `assess!` (vzor `HardwareCatalog`), stavy `:ok/:degraded/:read_only`, fresh-read + revízia pod `Materials.with_catalog_lock`, `.bak`, seed (Hettich, Blum, Strong, Grass;
  rady Sensys, InnoTech Atira, Quadro, AvanTech YOU, AVENTOS, TANDEMBOX, LEGRABOX, MERIVOBOX, Nova Pro…), API len `create_manufacturer!`/`create_series!` (patch, CI dedup,
  rada ↔ presne jeden výrobca); rename/delete mimo V1. `hardware_catalog` — položka + `manufacturer`/`series` (whitelist, `SCHEMA_CURRENT` bump, `assess!`), hľadanie indexuje
  obe polia; serverový payload `save_set!` vracia štruktúrované chyby `{row, field, msg}` (kontrakt pre B3).
  **Scope OUT:** všetko UI (B2 katalóg, B3 editor setu), resolver/defaulty podľa klasifikácie (KOV-D), per-height sety, D-109, notifikácia novšej verzie snapshotu, rename/delete
  taxonómie, Démos parser zmeny (B2).
  **Audit:** HOTOVÝ (#17). Subagent začne read-only auditom proti aktuálnemu mainu (KOV-H1 už pristála: CONFIG_SCHEMA 3, `hardware_manual`).
  **Testy a DoD:** headless — round-trip nových polí setu a položky (globál · projektový snapshot · šablóna), kanonická mapa + validačná matica (každá nekonzistencia odmietnutá,
  legacy prejde), `active` sparse, `snapshot_std` per pole (každé samostatne bumpne; legacy nie), `class:` kľúč parse/round-trip + std, `GENERIC_TYPES lift` + plan_schema
  bump + guard staršieho pluginu, **downgrade**: knižnica/snapshot/šablóna s novými poľami → starší tvar = read-only/odmietnutie, nikdy orez (test „model sa nezmenil"),
  taxonómia (assess stavy, zámok — dvojprocesový flock vzor R-08, seed merge, dedup, rada↔výrobca integrita, degraded `.bak`), **charakterizácia**: starý set bez klasifikácie
  expanduje identicky (seed knižnica + fixtures), `expand`/`explain` ignorujú `active`; guardy (`SET_KEYS` kontrakt, `?v=`). In-SU — uloženie setu s klasifikáciou zo servera,
  šablóna s `hardware_set_defs` novej verzie odmietnutá bez zápisu (simulácia cez `assess_set_defs` nad payloadom), dve okná (R-08) nezmenené. Mutácie min. 4 (klasifikácia
  doplnená legacy setu · `active` uložené ako `true` · šablóna prejde bránou · `class:` kľúč zahodený pri round-tripe).
  **Riziká:** kolízia s R-35 (taxonómia len create) · veľkosť (ak by rástla, rezať B1a sety+šablóny / B1b taxonómia+katalóg).
  **Smoke pre Michala (B1 navonok neviditeľná):** Štúdio → Kovanie: sety a katalóg vyzerajú ako doteraz, nákup KLINIKA identický; nič nové sa nedá pokaziť.
  **Checklist uzáveru (v PR):** bump patch + `?v=` → testy vrátane in-SU → `hardware.md` (`hardware_sets`: klasifikácia, mapa, `class:` kľúč, std; nový odsek `hardware_taxonomy`;
  `hardware_catalog`) + ARCHITEKTURA router riadok → STANDARD §6 (klasifikácia, mapovací kľúč, taxonómia) → AUDIT_REGISTER (R-41 ostáva pre B3) → STAV/KRONIKA/PLAN (B1 ✅).

- **✅ HOTOVÉ (PR #290, v0.9.23)** — **KOV-B2 · TASK PACKAGE „KATALÓG — ZOSKUPENIE, MODAL POLOŽKY, DÉMOS" (slice B, rez B2; Audit: NIE, `codex-po-pr` povinné):**
  **Scope IN (mockup scéna 3):** serverové zoskupenie Kategória → Výrobca → Rada so `shown/total` na každej úrovni + „načítať ďalšie" (žiadne tiché stropy; test 500+ položiek
  nájde položku za poradím 200, `pin` zachovaný); hľadanie roztvára len zhody; modal Nová/Upraviť položka (D-15 vzor: štruktúrované chyby, busy lock, draft bez `row_rev`) s poradím
  polí kód → názov → cena → MJ → kategória → výrobca → rada → poznámka; **Démos**: `pid` proposal flow ostáva server-owned (kód/názov/cena/MJ), klient nastavuje len kategóriu,
  poznámku, výrobcu a radu; parser `brand` → kanonický výrobca cez taxonómiu na serveri (inak prázdne), Tip-On len schváleným pravidlom; ručne zmenený údaj nie je „overený";
  „+ Vytvoriť" výrobcu/radu z modalu = `create_*!` API B1. **Scope OUT:** editor setu (B3), logá, inferencia rady z breadcrumbu, rename/delete taxonómie.
  **Testy:** JS modal (validácia, kontext, chyby servera), strom + paginácia + hľadanie (čisté funkcie + minidom), Démos proposal bez regresie (`test_demos_*`); headless — strom
  a `shown/total`, hľadanie podľa výrobcu/rady, `create_*!` cez modal cestu; in-SU — založenie položky a výrobcu zo Štúdia = bez kroku Späť (globálne stores). Mutácie min. 3.
  **Smoke pre Michala:** katalóg: Závesy zbalené/rozbalené, hľadanie „tipon" roztvorí len Blum · založ položku s novým výrobcom cez „+ Vytvoriť" · Démos URL predvyplní kód/názov/
  cenu/MJ, výrobcu podľa značky. **Uzáver (v PR):** `hardware.md` + `ui-lifecycle.md` (modal, strom) → STAV/KRONIKA/PLAN (B2 ✅).

- **✅ HOTOVÉ (PR #297, v0.9.26) — KOV-B je tým KOMPLET a R-41 uzavretá** — **KOV-B3 · TASK PACKAGE „EDITOR SETU — KLASIFIKÁCIA, ČLENOVIA, ŽIVÝ NÁHĹAD" (slice B, rez B3; Audit: NIE, `codex-po-pr` povinné):**
  **Scope IN (mockup scéna 3):** modal Nový/Upraviť set: klasifikácia 1→6 kontextovo (`use_type` → odvodený `generic_type` zo servera, `drawer_construction` len pri zásuvke,
  rada podľa výrobcu), auto-návrh mena editovateľný; **pripnutá revízia + základná definícia pri otvorení** (R-41 — opravuje aj dnešný `HWS_EDIT`), konflikt = obnova/riešenie;
  editor člena: jedno „+ Pridať člena" → „Ako sa určí kód?" (pevný · `code_by_nl` · `param_bands`) + „Koľko?" (`per: unit|owner`), dátový tvar člena NEMENÍ (XOR, žiadne
  `code_by_height`); **živý náhľad expanzie**: server endpoint validuje odoslaný DRAFT, zostaví syntetického ownera a dočasné mapovanie bez IO, vracia request generation
  (staršia odpoveď neprepíše novšiu), text skladá server (vzor `explain`); pohľad Sety = dlaždice s chipmi klasifikácie + Aktívny/Neaktívny (neaktívny sa nenúka ako nový default;
  mapovanie podľa klasifikácie = KOV-D). **Scope OUT:** resolver, defaulty podľa klasifikácie, per-height sety (KOV-D).
  **Testy:** JS modal (3×2 kombinácie člena, kontextové polia, auto-názov, štruktúrované chyby, pripnutá revízia), náhľad = ten istý výsledok ako `expand` (headless), konflikt
  dvoch okien in-SU (R-08 vzor) + uloženie setu = bez kroku Späť. Mutácie min. 3 (revízia nepripnutá · náhľad číta uložený set namiesto draftu · `active` filtruje existujúce mapovanie).
  **Smoke pre Michala:** založ set: Zásuvka → Klasické → Kovové bočnice → Hettich → InnoTech Atira → navrhnuté meno → člen „K-sada podľa NL" → náhľad ukáže kód pre NL 470 ·
  starý set KLASIK má chip „nezaradený" a nákup KLINIKA dáva identické čísla · dve okná: úprava toho istého setu = konflikt s hláškou, nie tichý prepis.
  **Uzáver (v PR):** `hardware.md` + `ui-lifecycle.md` (editor, náhľad) → AUDIT_REGISTER R-41 ✅ → STAV/KRONIKA/PLAN (KOV-B komplet). *(D-110 je v archíve už od KOV-B2.)*
  **Vedomé odchýlky (v PR aj v KRONIKE):** klasifikácia sa posiela VŽDY CELÁ (aj prázdna `drawer_construction`) — vynechať ju by pri prepnutí zo zásuvky nechalo starú hodnotu
  z merge `save_set!` a set by už nikdy neprešiel validáciou; filter `active` sedí priamo v `set_options` (jediná UI ponuka, referencovaný set v nej ostáva), `expand`/`explain`/
  `resolve_set_id` ho ďalej nečítajú.

- **✅ HOTOVÉ (PR #285, v0.9.20)** — **KOV-H2 · TASK PACKAGE „AD-HOC KOVANIE — INSPECTOR UI" (slice H, rez H2; H1 je v maine od v0.9.18 — kontrakt `config['hardware_manual'][]` popisuje
  [../docs/architecture/construction.md](../../docs/architecture/construction.md), expanziu [../docs/architecture/hardware.md](../../docs/architecture/hardware.md)):**
  **Cieľ:** v kontexte Kovanie riadok „+ Pridať konkrétnu položku (mimo setov)" → D-15 modal (Patrí k: skrinka / čelo / zónový dielec — `human_label`; Zdroj: katalóg (existujúci
  combobox položiek, zobrazí živú cenu a MJ) / voľná (názov, MJ, cena, poznámka); množstvo); položky ako riadky s chipom „ručná", úprava a zmazanie = zmena configu cez apply
  (1 krok Späť); pôvod v sekcii Nákup Štúdia (rozklik zdrojov, chip „ručná"). Mockup scéna 2. **Audit:** NIE (UI nad kontraktom H1); `codex-po-pr` povinné.
  **Testy:** JS modal (validácia, kontextové polia, katalógový výber = len kód), riadky a chip, minidom round-trip cez `collectAll`; in-SU: pridať/upraviť/zmazať = po jednom kroku
  Späť. Mutácie min. 3. **Smoke pre Michala:** k F1 pridaj Bystricu 93240 ×2 z katalógu → Nákup ukáže riadok zliaty s ostatnými, rozklik pôvod „F1 · dvierka · ručná" · pridaj voľnú
  položku „zámok Abloy 12 €" ku skrinke → vlastný riadok, rozpočet ju započíta · zmeň šírku skrinky → položky ostali · kópia skrinky ich má · zmaž katalógovú položku z katalógu →
  riadok „chýba v katalógu" bez ceny · Ctrl+Z vráti každý krok. **Checklist uzáveru (v PR):** bump + `?v=` → testy → `ui-lifecycle.md` (modal, riadky, Nákup) → STAV/KRONIKA/PLAN
  (KOV-H komplet).

- **KOV-C · TASK PACKAGE „NEMENNÉ RECEPTY ZÁSUVIEK A ODVODENÉ DIELCE" (slice C; **v2 z 5.9.2026** — simplification review Michal + Claude nahradil package v13 z PR #300
  (4 CLI + 9 GH kôl nekonvergovalo; záznam [zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_18.md](../zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_18.md));
  predaudit Astra = checkpoint #19; in-SU povinné; rez C1 → C2):**
  **Cieľ:** zásuvkové čelo (klasifikované v KOV-A) dostane z **nemenného receptu** automaticky **vyrábané dielce** (Atira: dno + drevený chrbát; Quadro V6 EB23: 2 boky +
  dno + vnútorné čelo + chrbát), **jednu položku výsuvu** s číselnými parametrami (výška · NL · nosnosť · otváranie) a nákup k nej nájde kit kód v setoch z KOV-B.
  Nevyriešená zásuvka neemituje nič a je RED + tvrdý blocker (O2). Dáta: FINAL §4/§6 (FINAL §3 snapshot receptov + KD→EB a §8 VEPO výnimka pre chýbajúci set sú v2 PREKONANÉ — poznámka priamo v FINAL; Codex #301 kolo 2 P2), checkpointy #10 (vzorce), #11 (ABS, UNI 16, H70 = 105), #12 (kódy K-sád), draft #13 (§1 tabuľky kódov SiSy + Tip-On).
  **Zásady v2 (Michal 5.9.2026, záväzné):** (1) explicitné **nemenné recepty pre ~5 systémov** (Atira, Quadro, neskôr Antaro, TANDEM, StrongBox/Max), žiadny univerzálny
  resolver ani framework pre hypotetické systémy; (2) **fyzika v recepte, objednávacie kódy v setoch** (KOV-B) — dve vrstvy, každá s jednou zodpovednosťou;
  (3) **nákup nikdy nemení fyzický návrh**: žiadne kandidáty, žiadny fallback na inú NL kvôli chýbajúcemu kódu — rad NL v recepte = rad, ktorý Noxun reálne kupuje,
  chýbajúci kód = RED a používateľ rozhodne; (4) **EB je pevné per recept** (Atira 10.5, Quadro 23) — zmena hrúbky boku mení len svetlú šírku, z ktorej sa dielce počítajú,
  engine nikdy nehľadá iný runner (KD → EB mapa NEEXISTUJE); (5) systém je **explicitná hodnota** `drawer.system` popri `construction` (V1: metal → jediný kandidát Atira,
  wood → Quadro; UI predvyplní, hodnota sa uloží); (6) malý počet stavov, každé pravidlo auditovateľné z jedného JSON súboru.
  **C1 · jadro (čisté, bez zmeny výstupov) — ✅ HOTOVÉ (PR #302, v0.9.29, 5.9.2026):** modul + 4 recepty + register + `context_for` a raw hranice sú v maine; jediná vedomá odchýlka od textu nižšie je tvar konfliktu z `recipe_key_for` (`[:conflict, kód, hláška]` — kódy sa nerozšírili) a explicitný `drawer.system`, ktorý sa proti konštrukcii **overuje**, nie preberá. Nasleduje C2.
  **C1 · jadro (čisté, bez zmeny výstupov):** nový modul `core/drawer_recipes.rb` + recepty `noxun_engine/data/recipes/<recipe_id>.json`:
  `atira_sisy_v1`, `atira_p2o_v1`, `quadro_v6_sisy_v1`, `quadro_v6_p2o_v1` (jeden recept = jeden systém × jedno otváranie × verzia). Schéma receptu (validovaná pri načítaní,
  chýbajúca bunka = odmietnutie celého receptu, nikdy tichý default): `recipe_id` · `system` · `family` metal_box|wood_undermount · `opening` sisy|p2o · `eb` (číslo) ·
  `kd_supported` (Atira [16, 18, 19]; Quadro [16, 18, 19]) · `mounting: slide_on` · `rear_type: wooden` · `thickness_supported` per rola (Atira dno aj chrbát [16]; Quadro každý dielec
  [16, 18]) · vzorce ako konštanty (Atira: `BB = LB − 2EB − 51.5`, `RB = LB − 2EB − 63`, `BL = NL + 10`; Quadro: `SKW = LB − 46`, `SKL = NL`, `bottom_offset 12`, `box_clearance 40`,
  výška predku/chrbta `box_height − t_dna − 12`) · `height_variants` (Atira 70/144/176: `rear_height` 65.5/144/176, `min_clear_height` pre otváranie receptu — SiSy 105/189/221,
  Tip-On 108/192/224 (kity Démos sú vendor variant PTOs — prísnejšia z oboch tabuliek; Michal 5.9.), `railing` 0/1+1/1+1; Quadro bez variantov: `box_height = clear_height − 40`, `min_box_height` tak, aby predok/chrbát `box_height − t − 12` ≥ 30 mm — Astra #19 F3: svetlá výška 60 by dala −8 mm) · **`nl_series_by_height`** = Noxun rad podľa K-sád z #12 (atira_sisy: H70 [350, 420,
  470, 520] · H144 [350, 420, 470] (oprava 5.9. večer, sonda #12: SiSy H144/620 kit NEEXISTUJE — 357755 je PTO, teda Tip-On; rovnako SiSy H70/620) ·
  H176 [350, 420, 470, 520, 620]; atira_p2o: H70, H144, H176 zhodne [350, 420, 470, 520, 620] (kódy Démos od Michala 5.9. — KAŽDÁ bunka radov v1 má kit kód, draft #13 §1);
  quadro_v6_sisy [350, 400, 450, 500, 550]; quadro_v6_p2o [350, 400, 450]) ·
  `min_depth_by_nl` explicitná tabuľka (Atira NL + 15; Quadro NL + 13) · `load_by_cell` (Atira 30; 620 → 50; Tip-On H176/520 → 50, lebo kit existuje len ako 50 kg — hodnota bunky pre nákup/Inspector, geometriu nemení; Quadro 30) · `sync_min_width` 600 · `abs` per rola (dno bez;
  chrbát/boky/vnútorné čelo L1 1,0 mm horná dlhá hrana) · `source` tagy per hodnota. **Nemennosť:** register vydaných receptov `data/recipes/RELEASED.json` `{recipe_id → sha256}` — test v `tests/pure` overuje, že KAŽDÝ zaregistrovaný súbor existuje a sedí na SHA A že inventár `data/recipes/*.json` = množina registrovaných ID (nie len `_v1`; Astra #19 F10 + Codex #301 kolo 2
  P2); `Recipes.load`/`latest_for` načítajú VÝHRADNE registrované recepty + **golden test výsledkov `resolve` per vydaná verzia** (fixtúra vstup → dielce/NL),
  lebo SHA JSON nezachytí zmenu interpretácie v Ruby; zmena obsahu zhodí CI;
  oprava alebo rozšírenie = nový súbor `_v2`, staré verzie sa NIKDY nemažú ani nemenia (reprodukovateľnosť starých zákaziek bez snapshotu).
  Čisté funkcie: `Recipes.load(recipe_id)` · `Recipes.latest_for(system, opening)` · `Recipes.resolve(recipe, ctx, part_thicknesses, overrides)` (`part_thicknesses` per rola = VSTUP, nie odvodené z plánu) → `{height_variant (Atira číselné 70|144|176) |
  box_height (Quadro mm), nl, load, parts[], hardware_params, conflicts[], explain}` — **jedna výška** (najvyšší variant s `min_clear_height ≤ clear_height_raw`), **jedna NL**
  (najdlhšia z radu TEJ výšky s `min_depth ≤ clear_depth_raw`; porovnania inkluzívne s NEZAOKRÚHLENOU hodnotou, bez EPS: 105,00 platí, 104,995 padá); NL zámok
  z `hardware_overrides.nominal_length` (v rade výšky a zmestí sa → použije sa; inak conflict `nl_lock_invalid`, nikdy tichá zmena); hrúbka mimo `thickness_supported` =
  conflict `drawer_thickness_unsupported`; KD mimo `kd_supported` = `drawer_kd_unsupported`; žiadna výška/NL = `drawer_no_fit` s hláškou (napr. „Quadro P2O v1: hĺbka 300, najkratšia NL 350 potrebuje 363"); emisia dielcov ATOMICKÁ (všetky alebo žiadny); **každý rozmer každého dielca sa PRED emisiou overí proti `BuildPlan::MIN_DIM` a receptovému minimu — jediný neplatný rozmer =
  `drawer_no_fit` pre celú zásuvku** (existujúci per-dielec filter `part_skipped_degenerate` by atomicitu porušil; Astra #19 F3). `context_for(owner, plan, cfg)` v `construction.rb`:
  čistá fn z NEZAOKRÚHLENÝCH listových zón
  (`ZoneTree` odovzdá `raw_bounds`; projekcia `front_items` raw) → `{clear_width (listová zóna pretínajúca riadok), clear_height (prienik z-intervalu riadku s interiérom
  z_lo = floor + t … z_hi = height − t / rail_geometry a listovou zónou), clear_depth (= `back_front_y`), side_thickness (KD), obstructions[] (shelf / divider pretínajúci riadok →
  conflict `drawer_obstruction`)}`; named test: 16 mm offset riadok-vs-interiér.
  **Klasifikácia → recept — rozhodovacia tabuľka (Astra #19 F9, nikdy dve cesty naraz):** (1) typ ≠ zásuvka, alebo zásuvka BEZ AKÉHOKOĽVEK drawer poľa (`construction`, `opening_mode` aj `system` chýbajú = nedotknuté legacy čelo), alebo `construction other` → legacy cesta, CONTENT-identická, resolver sa nevolá; (2) `construction metal|wood` + `opening_mode` prítomné → resolver
  (`metal → system atira`, `wood → quadro_v6`; chýbajúci `drawer.system` server doplní default per construction a
  ZAPÍŠE = migrácia čiel klasifikovaných pred v2, vo V1 jediný kandidát); (3) akákoľvek ČIASTOČNÁ klasifikácia (`construction` bez `opening_mode` ALEBO `opening_mode` bez `construction` — polia sa editujú nezávisle; Codex #301 kolo 3 P1) → RED `drawer_unclassified`, žiadne dielce, žiadna slide položka ani legacy pravidlo; `opening_mode classic → sisy` ·
  `tipon → p2o` (len 2 typy otvárania — rozhodnutie 5.9.); `variant internal` = conflict `drawer_internal_unsupported`; čiastočná klasifikácia pri type zásuvka = RED
  `drawer_unclassified`; dormant drawer polia na dvierkach sa ignorujú. **`recipe_refs` per čelo** `drawer.recipe_refs = {"atira|sisy": "atira_sisy_v1", …}` (mapa systém|otváranie → `recipe_id`; aktívny záznam = aktuálna klasifikácia; Codex #301 kolo 2 P1: prepínanie klasifikácie tam a späť NIKDY nezmení už pripnutú verziu, lebo pôvodný záznam v mape ostáva): **3 stavy
  aktívneho záznamu** — chýbajúci
  (nové čelo → `latest_for`; NOVÁ kombinácia systém|otváranie na existujúcom čele → súrodenec ROVNAKEJ verzie ako už pripnuté záznamy, inak `latest_for`; návrat k skôr použitej kombinácii → jej PÔVODNÝ záznam z mapy) a zápis; známy → použi presne ten; neznámy → RED `drawer_recipe_unknown` („aktualizuj plugin"),
  bez dielcov. Autorita SERVER — DVE cesty, nie jedna normalizácia (Astra #19 B2): (i) **klientsky payload** z panela — handler akcie (`actions_*`) zahodí `recipe_refs` PRED zlúčením do configu (klientsky whitelist ho nepozná) **a uloženú mapu pripojí späť podľa ID čela** — `handle_apply_fronts`/`handle_apply_all` nahrádzajú `params['fronts']` vcelku (Codex #301 kolo 3 P1);
  test: stale/forged payload nikdy nezmení ani nevymaže mapu, čelo s novým ID mapu nemá; (ii) **uložený config** — `Fronts.normalize_config` ref BEZSTRATOVO zachováva (server-side whitelist), preto ho prežije prestavba, šablóna
  (`template_config_from`) aj natívny Copy/Paste; server pri prestavbe overí, že ref patrí k systému/otváraniu klasifikácie čela — aktívny záznam sa vyberá podľa klasifikácie čela z mapy `recipe_refs` (chýbajúci → súrodenec ROVNAKEJ verzie cez `Recipes.sibling`, inak `latest_for`; existujúci → presne ten); zmena verzie = VÝHRADNE explicitná akcia KOV-D (Codex #301 kolo 1 + 2
  P1: ani prepnutie SiSy → P2O → SiSy, ani systém s inou najnovšou verziou nesmie ticho povýšiť pripnutý recept); zápis len `Fronts.write_recipe_refs!` v TEJ ISTEJ operácii ako geometria; test: strata ref pri normalizácii = FAIL (po vydaní `_v2` by stav „chýbajúci → latest" ticho zmenil geometriu) —
  ten istý nemenný recept v každom dokumente, preto **žiadny projektový snapshot receptov, digest ani merge** (zavedú sa až keby recepty boli používateľsky editovateľné).
  Testy C1: tabuľkové testy vzorcov proti #10/#13 bez zaokrúhľovania (900/KD18 → LB 864, BB 791,5, RB 780, BL = NL + 10; **KD 16 → LB 868, BB 795,5 s EB stále 10.5**),
  hranice výšky/NL (175 → H70; H70 hĺbka 500 → 470, 560 → 520 (535 ≤ 560); H176 560 → 520; Quadro 497 → 450, 500 potrebuje 513), zámok v rade / mimo, context
  (offset, obstruction, listová zóna), stavy aktívneho záznamu `recipe_refs` (3) + návrat ku skôr použitej kombinácii vráti pôvodný záznam, validácia receptu (chýbajúca bunka), nemennosť (SHA), `latest_for` pri dvoch verziách.
  **C2a · príprava aktivácie (bez zmeny výstupov) — ✅ HOTOVÉ (PR #303, v0.9.30, 5.9.2026):** z bodov (b) a (d) nižšie je v maine všetko, čo sa dá spraviť BEZ zapnutia:
  4. materiálový kanál `:drawer` (`PROJECT_KEYS` + `default_drawer_material_id`, UNI 16 fallback `UNI_ZASUVKA_16` nemazateľný, `eff_drawer`, samostatná `ensure_drawer_uni!`
  s vlastným markerom, `thickness_ok_for?` pre 4 roly cez `CabinetBuilder::DRAWER_ROLES`) · ABS seed per rola (`SEED_VERSION` 4) · klasifikačné pole `height_variant` na setoch
  s lazy `std` 4 a piatou vrstvou `classification_lost?` · seed 8 klasifikovaných setov s kódmi + nový kontrakt `MAPPING_ADDITIONS` (add-if-absent) · čítanie triedneho kľúča
  v `resolve_mapping_value`/`resolve_set_id` a kompatibilita setu v `expand`/`explain` (ORANGE `class_unmapped` a `set_incompatible`) · `override_keys_in_use` + triedne kľúče ·
  completeness test nad radmi receptov. **Kanál nemá UI** (`MaterialsDialog::TARGETS` ho nepozná) a **nikto ho nekonzumuje** — dielce, položku výsuvu, blockery a RED
  `drawer_kit_missing` prináša C2b. Vedomé odchýlky od textu nižšie: `height_variant` je uzavretý enum `[70, 144, 176]` (nie voľné číslo) a `MAPPING_ADDITIONS` sa merguje aj do
  ČERSTVEJ knižnice (`seed_library`), inak by sa fresh install a upgrade rozišli. **Dátová oprava v tej istej dávke (sonda #12):** rad `atira_sisy_v1` H144 skrátený na
  [350, 420, 470] a kód 620 vyhodený zo seed setu `atira-biela-h144-sisy` — `357755` je PTO kit, teda Tip-On, a pre SiSy H144/620 (ani H70/620) kit neexistuje. Recept sa
  opravil NA MIESTE aj s prepočítaným odtlačkom v `RELEASED.json`, lebo v1 ešte nestojí v žiadnom projekte (C2b nie je v maine); **od aktivácie platí nemennosť bez výnimky**
  a oprava = nový `_v2`.
  **C2b · aktivácia — ✅ HOTOVÉ (PR #304, v0.9.31, 5.9.2026):** v maine sú body **(a), (b) UI časť, (c), (d) zvyšok, (e), (f), (g)** — resolver v `Construction.build_plan` (`drawer_pass`),
  dielce v pláne aj v modeli, JEDNA položka výsuvu `source: recipe` (+ `locked` pri zámku), R2 exkluzivita legacy `slide`, D-93 migrácia `rule_id`, RED `drawer_kit_missing`
  v nákupe, register `DRAWER_BLOCKERS` v `export_blockers` (`drawer_stop`, VEPO len na kit), uložený nosič `drawer_conflicts`, ORANGE `drawer_sync_recommended`,
  `CONFIG_SCHEMA` 4 → 5 a `plan_schema` 3 → 4, `recipe_refs`/`system` ako SERVEROVÉ polia. **Po Codex kole 1 pribudlo:** riadok „Zásuvky" v predvoľbách projektu Štúdia
  + `MaterialsDialog::TARGETS` s **preflightom per systém** (Atira 16, Quadro 16/18 — pôvodne plánované na C2c) a **11. kód registra `drawer_stale`** = MIGRAČNÝ:
  projekt uložený pred aktiváciou receptov, ktorý už má klasifikovanú zásuvku (**akékoľvek** drawer pole — predikát `Recipes.classified?`), je RED a blokuje VŠETKY exporty
  (vrátane VEPO), kým sa skrinka neprestaví. **Po kole 2 a 3:** hrúbky bokov Quadro sa čítajú pod oboma emitovanými kľúčmi (rôzne = fail-closed), remap ABS platí aj pre
  4. kanál a `drawer_material_id` cestuje vkladacou kartou aj „Nahradiť UNI…".
  **C2b-M · materiálový kanál zásuviek — ✅ HOTOVÉ (PR #305, v0.9.32, 6.9.2026; rozdelenie po 4. kole review, pravidlo 3 kôl):** bod C2 **(b) UI časť** je tým uzavretý. Výber
  **„Zásuvky"** v predvoľbách projektu Štúdia + `MaterialsDialog::TARGETS` + JS mapa `md_drawer` + kontext komba `drawer` = 16 · **preflight per systém** (Atira 16,
  Quadro 16/18; čísla z `Recipes.supported_thicknesses`) na VŠETKÝCH cestách — nová predvoľba, existujúca zákazka (potvrdenie), **„Nahradiť UNI…"** (systém KAŽDÉHO
  dotknutého čela, vrátane prípadu „UNI len v override dielca") a **vkladanie** (`MaterialsDialog.drawer_material_issue` pred ghostom) · `insert_state.js`
  `MATERIAL_KEYS` + `drawer_material_id` · remap ABS pri zmene predvoľby zásuviek. V #304 ostala aktivácia v engine a serverové cesty kľúča nutné pre integritu dát.
  **Vedomé odchýlky:** (1) `Fronts.norm_drawer` NEOVERUJE, či je ref registrovaný —
  robí to až `Recipes.active_ref` pri stavbe (inak by stav `drawer_recipe_unknown` bol mŕtvy a starší plugin by ticho pripol iný recept); (2) server-only sú OBE polia
  (`recipe_refs` aj `system`) — panel ich v C2b ani neposiela a server `system` deterministicky odvodí z konštrukcie; (3) dielce zásuviek nenesú `axes:` (farbenie ABS plôšok
  by pri stojacom dielci vyšlo na zlú hranu — PartFaces zásada „radšej žiadna farba"; farbenie = C2c/D); (4) povýšenie na `drawer_kit_missing` platí pre **každý** dôvod
  nemapovania receptovej položky, nielen pre tri menované (fail-closed — iný dôvod jej lepší výsledok nedá); (5) `legacy_slide_suppressed` sa v Kontrole zámerne
  NEZOBRAZUJE (`Validation::BUILD_INFO_ONLY`) — je to konštatovanie, nie nález. **Bod (h) = C2c.**
  **C2c · UI zásuviek — ✅ HOTOVÉ (PR #306, v0.9.33, 6.9.2026): tým je SLICE C KOMPLET.** Bod C2 **(h)** je uzavretý.
  `cabinet_payload` posiela nový VLASTNÝ kanál `front_drawer` (`front_id → { state, text, detail[], sync, message,
  locked_note }`) — karta čela z neho kreslí **jediný read-only riadok** „Atira · H70 · NL 470 · 30 kg · SiSy · recept v1“
  (Quadro = výška boxu) a vety receptu v **rozbaliteľnom** `<details>`. Vety skladá `Recipes.explain_stored` z ULOŽENÝCH
  `params` a PRIPNUTÉHO receptu, nikdy z prepočítanej geometrie; neznámy recept = prázdny zoznam. Konflikt **nahrádza**
  hodnoty červenou vetou stavby, `drawer_sync_recommended` pridáva jantárový riadok, config spred aktivácie receptov
  hovorí „prestav skrinku“. V **Nákupe** dostal záznam `drawer_kit_missing` serverový príznak `blocks_export` a jeho
  riadok je **červený** + veta, že sa nevytvorí ani VEPO.
  **Zistené v KROKu 0 a preto NEROBENÉ (už existovalo):** Kontrola RED/ORANGE riadky zásuviek aj preklik na čelo
  (ceruzka → výber skrinky + otvorená karta čela, KOV-A2b deep-link — `part_key` konfliktu je kľúč PANELA čela) ·
  značka ručného zámku v Nákupe (`note_manual` číta `locked: true` od #304) · materiálový kanál „Zásuvky“ a D-46
  preflight (#305, overené 1:1 — bez zmeny). **Vedomé odchýlky:** (1) `front_drawer` je samostatný kľúč, NIE rozšírenie
  `front_slots` (ten odpovedá výhradne na „kde sa pýta smer“); (2) `explain` sa NEUKLADÁ do configu ani do plánu —
  schéma sa v C2c nemení, preto sa vety skladajú znova a sú UŽŠIE než `explain` v `resolve` (svetlé rozmery skrinky sa
  neukladajú, takže sa netvrdia); (3) `blocks_export` je LEN zobrazovací príznak — bránu exportu drží ďalej
  `export_blockers`; (4) chipy zámkov osí z mockupu scény 1 sa NEROBILI (KOV-D), ručný zámok priznáva len veta pod
  riadkom. **Odložené na KOV-D:** highlight riadku Kontroly, UI mapovaní podľa klasifikácie, farbenie ABS hrán dielcov
  zásuviek (`axes:`), `owner_label` namiesto surového `part_key` v zozname „Bez kódov“ Nákupu.
  **C2b · aktivácia — pôvodné zadanie (mení výstupy LEN pre čelá so systémom; ostatné zákazky CONTENT-identické; NARAZ a–h):**
  (a) `Construction.build_plan` volá resolver pre každé drawer čelo so systémom → dielce do `plan.parts` s part_key `front:<id>/drawer_bottom` · `/drawer_back` ·
  `/box_side:left|right` · `/drawer_inner_front`; nové ROLES + `plan_schema` bump + `material signals` enum `:drawer` + `human_label` vetvy; `materialized_part` sa NEPOUŽÍVA
  (nový `drawer_part` s finálnou geometriou); **poradie stavby (Codex #301 kolo 3 P1):** `CabinetBuilder.build_into` dnes volá `Construction.build_plan` PRED `effective_materials` — pre drawer roly sa hrúbky kanála `:drawer` (+ `part_overrides`) vyriešia PRED plánom a odovzdajú receptu ako `part_thicknesses`; bez nich by 18 mm materiál pri Atire prešiel a Quadro by počítalo
  predok/chrbát s nesprávnou hrúbkou dna; test: override materiálu 18 → conflict, Quadro dno 18 → predok o 2 mm nižší;
  (b) **4. materiálový kanál `:drawer`**: `PROJECT_KEYS` + `default_drawer_material_id` (fallback UNI 16 mm, nemazateľný), `eff_drawer`, `ensure_drawer_uni!` (samostatná
  idempotentná; `ensure_uni_records!` končí pri `uni_seed.done`; ochrana ID), `UNI_ROLES` + drawer, `thickness_ok_for?` pre nové roly, D-46 reuse pre kanál len cez preflight
  per systém; ABS seed per rola z #11 (`SEED_VERSION` bump); **hrúbka = vstup receptu** — materiál mimo `thickness_supported` = conflict;
  (c) **jedna položka výsuvu** v úplnom tvare `BuildPlan`: `generic_type: slide`, `rule_id: recipe:<recipe_id>`, `owner_part_key: front:<id>/panel`, `quantity: 1`,
  `rule_quantity: 1`, `source: recipe` (enum bump), **`locked: true` LEN pri položke s platným osovým zámkom** (`nominal_length` override), nie na každej receptovej položke (Astra #19 N11: inak falošné „ručne prepísané"); zákaz zmeny množstva plynie zo `source: recipe`; spotrebitelia `note_manual` a payloady Nákupu/Inspectora berú `locked` ako dnešné
  `source manual`, `params {recipe_id, system, height_variant (číselné) | box_height, nominal_length, load, opening, opening_mode, drawer_construction}`; **R2 exkluzivita**:
  `HardwareRules.evaluate` potlačí `fit_series`/slide pravidlá pre čelá so systémom (warning `legacy_slide_suppressed` raz per zákazka); **migrácia D-93**: existujúci
  `nominal_length` override s `rule_id vysuvy-nl-podla-hlbky` na drawer čele sa v tej istej prestavbe premapuje na `recipe:<recipe_id>` a platí ako zámok (mimo radu →
  `nl_lock_invalid`); server odmieta `quantity`/`disabled` mutácie pre `rule_id recipe:*` (`actions_hardware.rb`); legacy override s `disabled` alebo `quantity ≠ 1` na recipe
  položke = RED `drawer_override_invalid` (jeden kód); charakterizačný test „jedno zásuvkové čelo → presne jedna slide položka s množstvom 1";
  (d) **výber setu = NÁKUP, nie stavba:** `HardwareSets.resolve_mapping_value` pre položky, ktoré nesú `opening_mode` + `drawer_construction` v params, číta **triedny kľúč**
  `class:slide|<opening_mode>|<drawer_construction>` (KOV-B1 ho už parsuje a round-tripuje; precedencia cabinet override (config `hardware_sets` s triednym kľúčom) → projekt; **owner-level override pre receptové položky v C NEEXISTUJE** — Codex #301 kolo 2 P1: `class:…@owner` parser odmieta a generický `slide@owner` je práve zakázaný fallback; owner-scoped tvar kľúča definuje
  KOV-D, ak bude per-čelo prepnutie potrebné; odhad < 30 riadkov); **hodnota mapovania pre receptové položky so `height_variant` musí byť na KAŽDEJ úrovni (cabinet / projekt) selektor podľa `height_variant`** (Astra #19 B1: pevný `set_id` v override skrinky by
  po prerastení zásuvky H70 → H176 objednal H70 kit k dielcom H176, lebo klasifikácia opening/construction je pri oboch rovnaká) — pevný `set_id` pre Atiru = RED `drawer_kit_missing` „override nie je selektor podľa výšky"; farba / 50 kg = ALTERNATÍVNY selektor (antracit per výška); Quadro (bez variantu) smie pevný `set_id`; expanzia navyše overí kód pre `nominal_length`;
  `override_keys_in_use` (R-34 ochrana kolidujúcich kópií v `production_core.rb`) rozšírená o triedne kľúče, ktoré resolver číta (Astra #19 F8)
  a pre `source: recipe` **NIKDY nepadá na generické `slide`** (set H70 pre zásuvku H176 by bol zlý kit) — chýbajúce triedne mapovanie = RED `drawer_kit_missing` s hláškou
  „Pravidlá → Doplniť nové predvolené" (existujúca akcia `merge_project_sets_seed!`, vždy explicitná, nikdy automatická migrácia snapshotu); **seed** (`SEED_VERSION` bump; std 3
  obsahom už existuje; **+ nový malý kontrakt `MAPPING_ADDITIONS` (add-if-absent) v `merge_seed`** — Astra #19 F7 + Codex #301 P1: `MAPPING_MIGRATIONS` vie len nahradiť `[from_set_id, to_set_id]` pri existujúcom kľúči a chýbajúci `class:` kľúč nevytvorí, takže „Doplniť nové predvolené" by nič neopravilo; `MAPPING_ADDITIONS = {class_key → hodnota}` sa do globálu doplní LEN ak
  kľúč chýba (používateľské mapovanie sa nikdy neprepíše), `merge_project_sets_seed!` ho prenesie do snapshotu projektu; test: starý globál + starý snapshot → po oboch mergoch triedny kľúč prítomný a zásuvka zelená): `class:slide|classic|metal` → selektor `{param:
  height_variant, bands: [70–70 → atira-biela-h70-sisy, 144–144 → atira-biela-h144-sisy, 176–176 → atira-biela-h176-sisy]}` — **NOVÉ klasifikované set ID**; legacy `vysuv-atira-biela-h70` ostáva NEDOTKNUTÝ pre legacy `slide` mapovanie (Codex #301 kolo 2 P1: oba merge ponechávajú existujúcu definíciu s rovnakým ID bez klasifikácie, kompatibilita by padla)
  (existujúci mechanizmus D-81 — žiadny nový tvar), `class:slide|tipon|metal` → selektor na `atira-biela-h70-p2o` / `-h144-p2o` / `-h176-p2o` (kódy PTOs z draftu #13), `class:slide|classic|wood` → `vysuv-quadro-v6-sisy`, `class:slide|tipon|wood` →
  `vysuv-quadro-v6-p2o`; sety nesú klasifikáciu (KOV-B1: `use_type drawer`, opening, construction, Hettich, rada + nové `height_variant` pri Atire) a `code_by_nl` z #12 (H70: 420 → 357695, 470 → 357696;
  H176: 420 → 357774, 470 → 357775, 620 → 357783; Quadro SiSy 400 → 317641, 450 → 317642, 500 → 317643; P2O 350 → 343031, 400 → 343033, 450 → 317644 …); **jediná nová klasifikačná metadáta na setoch: `height_variant` (číslo 70|144|176) pri `use_type drawer` výškového systému (Michal 5.9.: áno)** — NIE os výberu, len OVERENIE: expanzia odmietne set, ktorého `height_variant` ≠
  `params.height_variant` (Codex #301 kolo 3 P1: pásmo H176 → H70 set inak nemá čo odhaliť, oba majú NL 470); nové pole starší plugin orezáva → **lazy `std` 4 obsahom** (vzor KOV-B1 std 3; knižnica/snapshot bez poľa ostávajú na std ≤ 3, `classification_lost?` ho stráži); žiadne iné osi (`load`, `runner_variant`) na setoch
  (50 kg alebo antracit = alternatívny selektor per výška v override skrinky — nemení geometriu); kompatibilita = existujúca klasifikácia setu ↔ params položky **VRÁTANE systému a výšky: `manufacturer` + `series` setu ↔ `system` receptu, `height_variant` setu ↔ `params.height_variant`** (Codex #301 P1: Antaro/StrongBox budú zdieľať `class:slide|classic|metal` s Atirou — kým je
  v mape jeden systém per konštrukciu, triedny kľúč stačí a
  identita setu sa overí pri expanzii; rozšírenie kľúča o systém patrí dávke, ktorá pridá druhý kovový systém) (nesúlad opening/construction/system/height_variant = RED
  `drawer_kit_missing` s dôvodom); **completeness test (GLM M6):** každá bunka výška × NL z radov receptov v1 má v seede kód — všetky bunky radov v1 majú kit kód (Michal 5.9., draft #13 §1); budúca bunka bez kódu sa rieši DÁTOVO (kód alebo NL mimo radu), nikdy behovým fallbackom; chýbajúci kód pre vybranú NL v projekte = RED `drawer_kit_missing`;
  (e) **brány — jeden register `DRAWER_BLOCKERS` (10 kódov):** `drawer_unclassified` · `drawer_no_fit` · `drawer_obstruction` · `drawer_internal_unsupported` ·
  `drawer_thickness_unsupported` · `drawer_kd_unsupported` · `drawer_recipe_unknown` · `nl_lock_invalid` · `drawer_override_invalid` · `drawer_kit_missing`; `export_blockers` číta
  CELÝ register (test: každý kód zastaví blokované exporty, priečinok ostáva prázdny). Konflikty STAVBY (prvých 9) = fail-closed: žiadne dielce ani položka + RED do
  `hardware_issues` (kľúč z KOV-A); **uložený nosič (Astra #19 F6):** builder zapíše konflikty per čelo do configu v `merge_final` ako `drawer_conflicts` (vedľa `warnings`/`hardware`; tvar `[{front_id, code, message}]`), `Bom.collect` ich zlúči do `hardware_issues` — po fail-closed stavbe nezostane položka, z ktorej by sa dôvod obnovil; test save/reopen aj Undo (Kontrola ukáže
  RED aj po znovuotvorení) → blokujú HW CSV + rozpočet + CP, VEPO chráni fail-closed geometria. **`drawer_kit_missing` vzniká v NÁKUPE** (`Bom`/`HardwareSets.expand`:
  receptová položka bez setu alebo bez kódu pre svoju NL — dnešné ORANGE `no_set`/`nl_missing` sa pre `source: recipe` povyšuje na RED), dielce v modeli OSTÁVAJÚ (fyzika je správna),
  ale **blokuje VŠETKY exporty VRÁTANE VEPO** (BL = NL + 10, boky Quadro = NL — dielce rezané na NL bez kitu tej NL sú nepoužiteľné); prepočet ČERSTVÝ pri exporte z uložených
  položiek plánu + aktuálneho snapshotu setov projektu (existujúci vzor R9, žiadny nový preflight, žiadny `drawer_stale` — stavba sety nečíta, takže rozdiel nemôže vzniknúť);
  (f) **sync tyč P2O (Michal 5.9.2026 — MIMO V1 mechanika):** recept nesie `sync_min_width`; pri `opening p2o` a `clear_width ≥ prah` (inkluzívne, Hettich „od 600") stavba pridá
  **ORANGE** warning `drawer_sync_recommended` („zásuvka vyžaduje synchronizáciu — pridaj set cez ad-hoc kovanie", KOV-H kanál) — potvrditeľné pri exporte existujúcim dvojklikom;
  žiadny blocker, žiadny nový `generic_type`, žiadna dĺžka, capability ani cena za meter (plný režim `per: length` po V1, R-06a);
  (g) `CabinetBuilder::CONFIG_SCHEMA` 4 → 5 (`recipe_refs`, `source: recipe`, drawer roly) s forward-version odmietnutím a testom downgrade (starší plugin config 5 odmietne, nikdy
  ticho neodstráni dielce ani položku; `PartKeys::SCHEMA` sa nebumpuje); whitelisty šablón a `normalize_config` doplnené o `drawer.recipe_refs` a `drawer.system` (aditívne);
  (h) Inspector: karta zásuvky read-only riadok (systém · výška · NL · nosnosť · otváranie · recept v1) + `explain`; Kontrola RED/ORANGE riadky s dôvodom a navigáciou; Nákup:
  položka expanduje cez triedny kľúč (kód podľa výšky a NL, `note_manual` pri zámku).
  **Scope OUT:** zámky UI a zmena osí (D — v C platia len existujúce `nominal_length` overridy po migrácii) · prepínanie setu / systému / verzie receptu UI (D) · upgrade `recipe_refs`
  na novšiu verziu (D, explicitná akcia s textovým diffom konštánt) · sync tyč dĺžková a cenová (po V1) · Antaro/TANDEM/StrongBox/Max/Legrabox (recepty v ďalších dávkach, dáta
  v #12; kontrakt sa nemení) · vnútorné zásuvky (len klasifikácia + RED) · editor receptov · projektový snapshot receptov, digest, merge (len ak recepty budú editovateľné) ·
  KD → EB mapa, `runner_variant`, `orderable` · kandidáti / fallback NL · osi `load`/`runner_variant` na setoch a exact tabuľka (`height_variant` na sete je len overovacia metadáta, nie os výberu) · `drawer_stale` preflight ·
  dokonalý kolízny solver (obstruction stačí; atyp = vizuálna kontrola, #09).
  **Audit: HOTOVÝ — Astra predaudit 5.9.2026** (2 BLOCKER + 8 FIX + 1 NOTE, všetky zapracované malými pravidlami, ŽIADNY návrat k mechanizmu v13; záznam [zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_19.md](../zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_19.md)) → implementácia; nový modul + data pack, `plan_schema`/ROLES, `CONFIG_SCHEMA` 5, hardware kontrakt
  (`source recipe`, `locked`), brány. **In-SU POVINNÉ** (buildery, plán↔model, undo).
  **Testy a DoD C2:** headless — plán s dielcami (Atira 900×720×500, KD 18, čelo 175 → H70/470: dno 791,5×480, chrbát 780×65,5; **KD 16 → dno 795,5×480**; Quadro 900/KD18
  hĺbka 500 → NL 450: SKW 818, boky 450 × box_height, vnútorné čelo/chrbát 818 × (box_height − 16 − 12); hĺbka 560 Atira H176 čelo 300 → NL 520), 4. kanál (UNI fallback, override,
  hrúbka 18 pri Atire = conflict), ABS per rola, R2 (jedna položka; legacy potlačené; D-93 v rade aj mimo), fail-closed (nič sa neemituje + RED + blocker), **triedny výber**
  (H70 vs H176 iný set; wood iný set; chýbajúce triedne mapovanie = RED, NIE fallback na `slide`; cabinet override má prednosť; owner-level `slide@…` sa pre receptové položky IGNORUJE), `drawer_kit_missing` blokuje VEPO aj CSV
  s prázdnym priečinkom, completeness seedu, downgrade schémy 5, **charakterizácia**: zákazky bez drawer klasifikácie CONTENT-identické (kusovník/VEPO/nákup/rozpočet);
  JS — karta resolved riadok, Kontrola riadky; **in-SU** — stavba zásuvky s dielcami, rebuild po zmene hĺbky/výšky (iný variant/NL, žiadna duplicita, part_overrides prežijú),
  Ctrl+Z, kópia `*2` (ref prežije), šablóna uložiť/vložiť (drawer config + ref), plytká skrinka → žiadne dielce + RED + export zastavený s prázdnym priečinkom.
  Mutácie min. 4 (legacy nepotlačené · zámok mimo radu ticho padne na inú NL · dielce emitované pri conflict · recipe položka padne na generické `slide` mapovanie).
  **Riziká:** rozsah C2 (ak PR narastie, oddeliť C2a = materiálový kanál + ABS seed bez zmeny výstupov) · dátová úplnosť seedu (completeness test nad radmi v1) ·
  reálne .skp fixtures (D-93 zámok, legacy snapshot setov) treba vyrobiť PRED C2 · šablóna dnes neprenáša `hardware_overrides` (NL zámok) — vložená zásuvka sa rieši automatom (dielce aj kit konzistentne z tej istej NL), prenos zámkov = KOV-I R12 (Astra #19 F5, vedomé; test to potvrdí).
  **Smoke pre Michala:** skrinka 900×720×500 (KD 18), F2 zásuvkové čelo 175 (Kovové bočnice → Atira) → kusovník: dno 791,5×480 + chrbát 780×65,5 (H70), Kontrola bez nálezov,
  nákup 1× K-Atira 470 (357696) · zmeň bok na 16 → dno 795,5×480, kód rovnaký · zmeň hĺbku na 560 → NL 520, nákup 357697, dielce prepočítané, žiadny duplicitný riadok · drevený box (Quadro) → 5 dielcov: SKW 818, boky 450 × (svetlá výška − 40), nákup K-set V6 SiSy 450 (317642) · materiál zásuviek v projekte na bielu 16 → všetky dielce
  ju dedia · override skrinky na antracit set → iný kód, dielce rovnaké · plytká skrinka 250 → RED „bez riešenia", dielce zmiznú, CSV odmietne · Tip-On Atira pri hĺbke 500 → NL 470, nákup 357724 (PTOs kit), dielce rovnaké ako pri SiSy · P2O šírka 900 → ORANGE „pridaj synchronizačný set" · starý projekt bez triedneho mapovania → RED „Doplniť nové predvolené", po kliku zelené ·
  otvor KLINIKA → čísla identické.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `construction.md` (context_for, roly, resolver hook), `hardware.md` (recipes, R2, triedny kľúč, seed),
  `materials.md` (4. kanál), `outputs.md` (blockery, hardware_issues kódy, VEPO brána), `model-a-identita.md` (part_keys drawer, recipe_refs), ARCHITEKTURA router riadok
  (drawer_recipes) → STANDARD §5/§6/§7 doplnky (roly, drawer materiál, recepty) → STAV/KRONIKA/PLAN.

- **KOV-D · TASK PACKAGE „OVLÁDANIE ZÁSUVIEK — MAPOVANIE, ZÁMKY OSÍ, UPGRADE RECEPTU, DROBNOSTI" (slice D; štart po KOV-C ✅; **v2 z 6.9.2026** po Astra predaudite proti
  hotovému KOV-C — záznam [zdroje/next_sessions/KOVANIE_KOVD_AUDIT_2026-09-06_20.md](../zdroje/next_sessions/KOVANIE_KOVD_AUDIT_2026-09-06_20.md); **rez na MALÉ série D1a/D1b (+ dátová D1c) · D2a/D2b ·
  D3a/D3b · D4 · D5**, každá vlastný PR — jadro a UI vždy oddelene; poučenie z C2b):**
  **Cieľ:** používateľ ovláda zásuvku bez tichých zmien: vyberie set pre skrinku alebo čelo, zamkne výšku alebo NL, prejde na novšiu verziu receptu — vždy s viditeľným dopadom
  a jedným krokom Späť; resolver nikdy nemení potichu; nevyriešený stav = RED s cestou von. Mockup scény 1–2. Zásady KOV-C v2 platia (fail-closed, málo stavov, kódy v setoch,
  nákup nemení fyzický návrh).
  **Už hotové v KOV-C (NIE scope D):** triedny kľúč čítaný v resolve, per-height sety + seed + `MAPPING_ADDITIONS`, `drawer_kit_missing`, karta zásuvky s `explain_stored`,
  Kontrola ceruzka → čelo, osirotené zásahy so serverovým resetom, pamäť drawer polí pri prechode na dvierka (`none` čistí), sync tyč ORANGE.
  **D1a · MAPOVANIE — jadro (audit-povinné, schéma) — ✅ HOTOVÉ (v0.9.34, 6.9.2026):** (1) **owner-scoped triedny kľúč** `class:slide|<opening>|<construction>@front:<id>/panel` — povolený VÝHRADNE v
  `config.hardware_sets` skrinky (globál/projekt ho nemajú); triedna časť sa normalizuje, owner ostáva doslovne a validuje sa proti čelám skrinky; precedencia pre receptové položky
  **owner triedny → cabinet triedny → projektový snapshot**; na nižšiu úroveň sa ide LEN pri neprítomnom kľúči — neplatná hodnota, chýbajúce pásmo alebo nekompatibilný set = RED
  `drawer_kit_missing` (Astra #20 F8); pri Atire aj pod owner kľúčom selektor podľa `height_variant`, Quadro smie pevný set; existujúca akcia zapisujúca `slide@owner` (`handle_set_hardware_set` — dnes prijíma len reťazec `set_id` a zmrazí jednu definíciu) sa pre čelá so systémom prepne na triedny owner kľúč a **prijme aj validovaný selektor** (hodnota = selektor podľa
  `height_variant` pre Atiru, pevný set pre Quadro), zmrazí do snapshotu KAŽDÝ referencovaný set; test na úrovni akcie (Codex #307 P1); (2) **zapisovacie operácie** `set_global_mapping!`/`set_project_mapping!` prijmú validovaný triedny kľúč (mení sa JEDEN kľúč, ostatné
  zachované, definície všetkých setov selektora sa zmrazia do snapshotu — Astra #20 F9); globál ostáva predvoľbou nového projektu, existujúci snapshot sa mení len explicitne;
  (3) **`CONFIG_SCHEMA` 5 → 6** (nový tvar kľúča v `hardware_sets` configu; starší plugin by ho ticho orezal a použil automat — Astra #20 B1); `DRAWER_ACTIVATION_SCHEMA` ostáva 5;
  forward guard + downgrade test; (4) **neaktívny set** (Astra #20 F10): nedá sa NOVO vybrať, existujúca uložená voľba sa zobrazuje a zachováva, deaktivácia nemení nákup zákazky;
  neplatná aktuálna hodnota ostáva s chybou, nikdy sa nenahradí prvou kompatibilnou; (5) **oprava z C (Astra #20 B4):** prítomný, ale NEPLATNÝ záznam `recipe_refs` (nesúlad kľúča
  a receptu, neregistrované ID) = RED `drawer_recipe_unknown` bez dielcov — NIE zahodenie + súrodenec/latest (`norm_recipe_refs` záznam zachová ako neplatný, `pick_ref` ho vidí);
  neprítomný záznam ostáva „chýbajúci → súrodenec/latest". (6) **šablóny a duplicity (Codex #307 kolo 2 P1):** `TemplatesDialog.merge_hardware_sets` zachová owner triedny override cieľa (dnes `parse_hardware_set_key` pre `class:` vracia nil → záznam by vypadol a kit by sa ticho zmenil); `override_keys_in_use` registruje aj owner triedny kľúč (brána duplicitných ID); (7) **akcia
  zápisu validuje** každé pásmo selektora proti aktuálnej klasifikácii cieľového čela (opening/construction/system/height_variant) a odmietne neaktívne definície PRED zápisom — nie až expanzia (Codex #307 kolo 2 P2). Testy: precedencia 3 úrovní, owner kľúč mimo `hardware_sets` odmietnutý, downgrade, neaktívny set, neplatný ref = RED, šablóna zachová owner kľúč, duplicitné ID s
  rôznym owner kľúčom = blokované, forged selektor odmietnutý. **In-SU povinné aj pre D1a** (jedna operácia = owner mapovanie + zmrazenie setov + prestavba: Undo/Redo konzistencia mapovania a snapshotu — Codex #307 kolo 2 P1).
  **D1b · MAPOVANIE — UI — ✅ HOTOVÉ (v0.9.35, 6.9.2026):** Pravidlá Štúdia majú v EXISTUJÚCEJ tabuĺke mapovaní štyri riadky triednych kľúčov `class:slide|…` (globál aj
  projekt) a karta skrinky/čela ponúka **Set pre túto skrinku** / **Set pre toto čelo**; ponuku skladá server (`HardwareSets.class_set_options` — len kompatibilné, Atira ako
  **rodina** = selektor podľa `height_variant`, Quadro pevný set, neaktívny set NIKDY; uložená hodnota mimo ponuky sa zobrazí ako `disabled`). Zápis ide existujúcimi cestami
  (`set_global_mapping!`/`set_project_mapping!` s novým payload poľom `mapping_key` · `handle_set_hardware_set` s D1a kľúčmi); jadro (resolver, zámky, schéma, seed) sa NEMENILO.
  **Nosnosť ostala garantovaným údajom receptu** — rozpis balenia ju neuvádza (Astra #20 F11). K tomu **explain**: rozklik „Technický detail“ na karte zásuvky dostáva za vety
  receptu aj „čo je v balení“ z JEDINÉHO existujúceho rozpisu `HardwareSets.explain`. Alternatívna rodina overená **fixtúrou v testoch**; produkčný seed nedotknutý.
  **Produkčný antracit seed = samostatná dátová dávka PO D1b** z kódov Michala 6.9. (draft #13 §1: Tip-On H70/H144/H176 NL 350–520 kompletné, SiSy H144 kompletná, SiSy H70/H176
  čiastočné, NL 620 nikde) — **čiastočná rodina sa smie zaseedovať: bunka bez kódu = RED `drawer_kit_missing` s hláškou (explicitne, nikdy tichá zámena); completeness test platí len
  pre predvolenú bielu rodinu**. **Rodinu určuje (výrobca, rada, názov bez tokenu `H<číslo>`)** — klasifikácia farbu nenesie; antracit seed preto musí dať rodine vlastný názov
  (napr. „Atira antracit H70 — klasické“), inak by sa zlúčila s bielou. Testy: `tests/pure/test_kovd1b_ui.rb`, `tests/js/test_kovd1b_ui.js`.
  **D1c · DÁTA — PRODUKČNÝ ANTRACIT SEED — ✅ HOTOVÉ (v0.9.36, 6.9.2026):** `SEED_VERSION` 3 → 4 a **6 nových setov** `atira-antracit-h{70,144,176}-{sisy,p2o}` („Atira antracit
  H70 — klasické“ / „— Tip-On“) s kódmi z draftu #13 §1 (Démos 6.9.). Kódy **len pre bunky radov receptov v1** — chýbajúca bunka (SiSy H176 350/520/620, všetky NL 620) má kľúč
  v `code_by_nl` NEPRÍTOMNÝ → RED `drawer_kit_missing`, nikdy prázdny reťazec ani cudzí kód. **`MAPPING_ADDITIONS` nezmenené** (predvoľba ostáva biela), katalóg kovania
  nedotknutý, jadro/UI/recepty bez zmeny. Rozhodnutia Michala 6.9.: **357887 zaseedovať** (overené v Démose), **NL 260/300 nezapisovať** (mimo radov). Testy:
  `tests/pure/test_kovd1c_antracit.rb` (11 testov, tabuľková fixtúra = druhý zápis dát; mutácie: cudzí kód · prázdny reťazec · antracit v `MAPPING_ADDITIONS` · názov zlúčený s bielou).
  **D2a · ZÁMKY OSÍ — jadro — ✅ HOTOVÉ (v0.9.37, 6.9.2026):** (1) pole `height_variant` v `hardware_overrides` (Atira; Quadro výškový zámok NEponúka) — **`CONFIG_SCHEMA` 6 → 7** s downgrade testom (D1a už minula 6; plugin D1a by inak pole ticho zahodil whitelistom `norm_hardware_overrides` — Codex #307 P1); (2) **poradie resolvera**
  (Astra #20 B2): zamknutá výška alebo automatická výška → rad NL TEJ výšky → zamknutá NL alebo automatická NL → dielce → nákupný selektor; výška musí existovať v pripnutom recepte
  a zmestiť sa, inak RED bez dielcov aj výsuvu; príklad: zamknutá NL 520 po automatickom prechode H70 → H144 (rad H144 520 nemá) = konflikt, nikdy návrat na H70 ani zmena NL;
  (3) **receptová zapisovacia cesta NL** (Astra #20 F5): D-93 `series_value?` hľadá len projektové `fit_series` — doplniť úzku serverovú vetvu vlastník → pripnutý recept → výsledná
  výška → jej rad; identita a hodnota pre „zamknúť aktuálne" z čerstvého serverového stavu; (4) **stav per os server-side** (Astra #20 F7): položka ostáva `source: recipe`, nové
  receptové zámky NEidú cez `apply_overrides` (prepína zdroj na `manual`); `locked` = súhrn, payload nesie stav každej osi (auto | locked | conflict) — text karty podľa osi;
  (5) **náhrada** (Astra #20 F6): mení LEN opravovanú os, druhý zámok ostáva a znovu sa overí; ak platná náhrada pri druhom zámku neexistuje, potvrdenie sa neponúka; návrh sa
  počíta z receptu + geometrie, nikdy z dostupných kódov; **reset per os** (dnešný orphan reset zahadzuje celý záznam — po pridaní výšky by zmazal aj platný druhý zámok).
  Testy: `tests/pure/test_kovd2a_zamky.rb` (poradie výška → NL nad fixtúrami H70/H144 × 520, zámok drží / konflikt / návrh len jednej osi, reset per os, receptová NL cesta,
  per-os stav v payloade, schéma 7; 3 overené mutácie) + in-SU sekcia **`run_kovd2a`** (zámok výšky proti automatu H144 → H70 v jednej operácii, Späť aj Redo, NL mimo radu =
  RED bez dielcov a bez kitu, odomknutie jednej osi, kópia zámky nesie).
  **D2b · ZÁMKY — UI — ✅ HOTOVÉ (v0.9.38, 6.9.2026):** rad chipov osí (`hwAxHtml`) kreslí **JEDEN markup** na oboch miestach — riadok výsuvu aj riadok osiroteného zásahu
  v kontexte Kovanie a riadok zásuvky v karte čela; stav je VÝHRADNE serverový (`axes` z D2a) a **hodnota do zápisu ide z `axes.*.value` / `options` / `proposal`, nikdy
  z textu chipu** (`data-val`). Klik na `auto` zamkne zobrazenú hodnotu, klik na `locked`/`conflict` pošle `value: null` = odomknutie **LEN tejto osi** (nikdy `reset`);
  iná hodnota len z ponuky `options` (pri `blocked_by: 'height'` ponuka nie je a chip to prizná vetou). Konflikt = RED chip + RED riadok s **vetou zo servera** + „Nahradiť
  za …" LEN pri `proposal` → **D-15 potvrdenie** → zápis návrhu (náhrada ostáva zamknutá, druhý zámok sa nemení); „Odomknúť" je dostupné vždy, aj bez emitovanej položky.
  Zápis ide **existujúcou** akciou `set_hardware_override`; jadro (resolver, normalizácia, schéma, `drawer_axes_map`) sa **nemenilo**. Server-side pribudlo LEN aditívne:
  `front_drawer[fid]` nesie `axes` + `lock` (identita zápisu vrátane `cabinet_id`) — `drawer_axes_index` dáva stav aj identitu **jedným** prechodom (druhý by znamenal
  druhé `Recipes.load` na každý push) a **ľahký push** (`front_drawer_refresh`) nesie to isté, inak by zmena mapovania zmazala chipy z otvorenej karty.
  **Vedomá odchýlka od mockupu:** chipy „otváranie" a „nosnosť" sa nepridali (riadok zhrnutia ich už nesie) — zapísané v `zdroje/ui20/UI20_KONTRAKT.md` §7 bod 10.
  **Codex kolo 1 (4× P2):** modal náhrady sa zatváral **pred** potvrdením servera → odteraz sa len zamkne a čaká na `NX.hwAxResult` s **korelačným tokenom** (`ax_token`,
  vzor KOV-H2), odmietnutie ho odomkne a hlášku ukáže v ňom · pri zámkovom konflikte sa **veta nekreslila dvakrát** (vonkajšia sa potlačí, keď ju os doslovne opakuje) ·
  os v `conflict` už **nemá ponuku** (jediná cesta = náhrada s potvrdením) · chipy dostali **`data-axc`**, takže fokus prežije prekreslenie karty.
  Testy: `tests/pure/test_kovd2b_payload.rb`, `tests/js/test_kovd2b_ui.js` (mini-DOM) + `test_kova2a_karta.js` (fokus nad celou kartou) + in-SU sekcia **`run_kovd2b`**;
  8 overených mutácií.
  **D3a · UPGRADE RECEPTU — jedno čelo, jadro — ✅ HOTOVÉ (v0.9.39, 6.9.2026):** akcia `handle_upgrade_drawer_recipe` (payload `{cabinet_id, front_id, from, to}`, mapu klient
  neposiela) mení **jeden záznam** mapy jedného čela cez jediný prepisovací kanál `Fronts.set_recipe_ref!` (stavbová `write_drawer_fields!` naďalej len **dopĺňa chýbajúce**);
  overuje `:known` záznam == `from`, vydaný cieľ a `Recipes.upgrade?` (rovnaký systém aj otváranie + **vyššia** verzia). **Preflight PRED zápisom** (Astra #20 B3 — konflikt je
  DÁTA, `rebuild` ho commitne) beží tými istými funkciami ako stavba (`normalize` → `drawer_thicknesses` → `build_plan` → `resolve`) a **tou istou expanziou ako nákup**
  (`HardwareSets.expand`): hrúbka · preadresované zámky `recipe:<v1>` → `recipe:<v2>` s **kolíznou bránou** (iný alebo dormantný záznam na cieľovom `rule_id` = odmietnutie,
  nikdy tiché zlúčenie) · konflikt výšky/NL · chýbajúci kit ⇒ **neuloží sa NIČ a nevznikne krok Späť**. Úspech = jedna operácia (ref + zámky + prestavba), 1 Späť, Redo
  obnoví všetko súčasne. `pick_ref` má stabilné pravidlo (**najnižšia** dostupná súrodenecká verzia LEN z validovaných záznamov) a `release_note` je voliteľné pole schémy
  (≤ 400 znakov, prítomné sa validuje prísne). **Latentný rámec:** UI ani registrácia callbacku **nie sú** (D3b), produkčný register **žiadnu v2 nemá** (guard test) — všetko
  sa overuje nad fixtúrnym registrom `tests/fixtures/recipes_d3a` cez jediný len-testovací seam `Recipes.with_test_dir`. Testy: `tests/pure/test_kovd3a_upgrade.rb`
  (25 testov, 4 overené mutácie) + in-SU sekcia **`run_kovd3a`** (odmietnutie bez kroku Späť · upgrade s preadresovaným zámkom a geometriou v2 · Späť = 1 krok · Redo · kópia).
  **Pôvodné zadanie:** akcia mení **jeden záznam mapy `system|opening` jedného čela** (Astra #20 F12/F13; ostatné refs a dormant zámky
  nedotknuté); server overí očakávaný starý ref + cieľ rovnakého systému/otvárania; **preflight cieľa PRED zápisom**: hrúbky, oba zámky (preadresovanie `rule_id recipe:<v1> →
  recipe:<v2>`; kolidujúci override na cieľovom rule_id s inou hodnotou = odmietnutie), expanzia setu — **konflikt cieľového receptu alebo chýbajúci kit = upgrade sa NEULOŽÍ, ostáva
  v1 aj pôvodné zámky** (Astra #20 B3: `rebuild_many` konflikt receptu ako dáta commitne — preto preflight, nie rollback); úspešný výsledok = jedna operácia (ref + zámky + prestavba),
  1 Späť; **`pick_ref` pri mape s viacerými verziami** = stabilné pravidlo: najnižšia dostupná súrodenecká verzia LEN z VALIDOVANÝCH záznamov mapy — neplatný (RED) záznam nikdy neovplyvní výber súrodenca (Astra #20 F12, Codex #307 kolo 2 P1); **cieľ upgradu musí mať parsovanú verziu VYŠŠIU než starý ref** (rovnaká alebo nižšia = odmietnutie, žiadny downgrade — Codex #307 kolo 2
  P2); `release_note` = voliteľné pole schémy receptu validované v `Recipes.validate!` a prenášané do načítaného receptu (v1 ho smie vynechať). Hromadný projektový upgrade = samostatný PR PO D3b. **Dáta (Codex #307 P1):** v repe sú len recepty v1 a žiadny dôvod na v2 — D3a/D3b sú **latentný rámec** overený fixtúrnym registrom (dočasné `atira_sisy_v2` v testoch, ako C1); produkčná v2 vznikne
  až s reálnou dátovou zmenou (nová hodnota od výrobcu/Michala) a vtedy dostane `release_note`; DoD D3 = testy + in-SU nad fixtúrou, nie viditeľná ponuka v plugine.
  **D3b · UPGRADE — UI — ✅ HOTOVÉ (v0.9.40, 6.9.2026):** karta čela dostáva **aditívny** kľúč `front_drawer[fid].upgrade` — a to LEN keď pre pripnutý recept naozaj existuje
  **vydaná vyššia** verzia (`active_ref == :known` · `latest_for` · `Recipes.upgrade?`) a záznam je `state: 'ok'`; v produkcii teda **nikdy** (žiadna v2 neexistuje), takže payload
  je zhodný s D3a a karta nekreslí žiadny nový vertikálny blok. Ponuka = jeden `inforow` „Dostupný recept v2 — `release_note`" + ghost tlačidlo; klik pošle **čítací** callback
  `drawer_upgrade_impact` (žiadna operácia, žiadny zápis, žiadny krok Späť), ktorý cez `drawer_upgrade_prepare` vráti **dopad na TOTO čelo** — výška · NL · rozmery každého dielca ·
  objednávacie kódy · prenesené zámky, vždy „teraz → po prechode". Čísla skladá SERVER a berie ich z **toho istého nasucho postaveného stavu**, ktorý by sa aj zapísal (prepare
  vracia aditívne `side`/`lock`; terajšiu stranu stavia **ten istý** `drawer_dry_plan`) — žiadny druhý výpočet a žiadny textový diff konštánt. `ok:false` = potvrdenie sa
  **neponúkne**, len veta prečo. Potvrdenie je kostra D-15 (tabuľka ako zobrazovací `custom` blok), zápis ide na `upgrade_drawer_recipe` s vlastným tokenom a **okno zatvára až
  potvrdenie servera** (`NX.hwUpgradeResult` / `NX.hwUpgradeImpact` — dva vlastné kanály, nie zdieľané s D2b). Oba callbacky sú v paneli **zaregistrované** (D3a ich nechala
  latentné). **Po Codex kole 1:** zápis presadí **len to, čo používateľ videl** — dopad nesie `fingerprint` (odtlačok identity + celého dopadu), klient ho len vráti a server ho
  pred zápisom prepočíta; nezhoda aj chýbajúci odtlačok = odmietnutie a prekreslenie panela (`from` stráži len pripnutý recept, nie rozmery, materiály či mapovanie).
  Potvrdzovacie okno je počas zápisu zamknuté aj **proti zatvoreniu** (`busyLock` v kostre D-15, opt-in; zapnuté aj pre náhradu osi z D2b, ktorá dostala chýbajúci `rescue`).
  Dielce sú kľúčované `part_key` (Quadro má **dva** boky boxu) a výška emituje `kind` (`variant` pre Atiru, `box` v mm pre Quadro). Register receptov sa číta **raz za prechod**
  (`Recipes.with_register_cache` + memo cieľa per `system|opening`). Testy: `tests/pure/test_kovd3b_upgrade_ui.rb` (31), `tests/js/test_kovd3b_ui.js` (93 assertov, mini-DOM),
  16 overených mutácií + in-SU sekcia **`run_kovd3b`**.
  **Pôvodné zadanie:** info „dostupný recept v2" pri čele + ponuka s konkrétnym dopadom na TOTO čelo (výška, NL, rozmery dielcov, zachovanie zámkov; nie textový diff konštánt —
  verzia môže meniť prahy/rad/hrúbky/ABS bez zmeny `constants`, Astra #20 F13) + autorská poznámka vydania z receptu (`release_note`) + potvrdenie; **In-SU povinné: 1 Späť A Redo (Ctrl+Y) — po redo ref v2, preadresované zámky aj geometria konzistentné** (Codex #307 P2); to isté pre zámky v D2b.
  **D4 · UI DROBNOSTI — ✅ HOTOVÉ (v0.9.41, 6.9.2026):** (1) **adresa riadku Kovania v náleze** — `Validation.hw_target` pridáva do nálezu **aditívny** kľúč `data`
  (`owner_part_key` + `generic_type` + `rule_id` + `orphan`), `stable_key` sa NEMENÍ; nesú ho `hardware` (vypnutý zásah, `orphan: true`), `hardware_unmapped` a `drawer_kit`
  (živý riadok) a `drawer` (konflikt zásuvky) **len pri JEDINOM zásahu výsuvu vlastníka** — pri dormantnom zámku vedľa aktuálneho server **nehádá** a nález ostáva bez adresy.
  `do_select` ju iba prepošle novým čítacím kanálom `push_focus_hardware` → `NX.focusHardware` (vetva PRED kartou čela; výber v modeli je **vlastník**, ako pri čele);
  klient prepne kontext na Kovanie, doscrolluje a **krátko prisvieti** (`hwFlash` — od D4 svieti **najviac JEDEN** uzol, ďalší skok predchádzajúci sníma hneď; prisvieti aj
  `nxFocusFront`, trieda `hwfocus` + nová `.frow.hwfocus`). Neexistujúci alebo nesediaci riadok (`orphan` vs. trieda) = **nerobí sa nič**. (2) **`owner_label` v „Bez kódov"**
  zo `ProductionCore.decorate_unmapped` — ten istý `owner_label_for` ako nákupné riadky KOV-H2; identita (`cabinet_id + owner_part_key`), dedup zásuviek, `blocks_export`, počty
  aj poradie nezmenené, surový kľúč ostáva v `title`, CSV/VEPO **znak po znaku** rovnaké. (3) **pravidlo pamäte** (STANDARD §6, `hardware.md`): pamäť patrí rovnakému ID čela ·
  zámok je viazaný na svoj recept a pri návrate sa **znovu validuje stavbou** · dormantný zámok iného receptu sa **nikdy nezobrazí ako aktívny** — jediná chýbajúca časť
  (`Panel.attach_override_axes` dával chipy KAŽDÉMU receptovému záznamu) je opravená **čítacím** filtrom podľa `idents` pripnutého receptu; jadro (resolver, schéma, zámky)
  sa nemenilo. **Codex kolo 1 (2× P2):** deep-link na zásah dostanú **len konflikty, ktoré ten zásah spôsobil** — nový whitelist `Recipes::OVERRIDE_CONFLICT_CODES`
  (`nl_lock_invalid` · `height_lock_invalid` · `drawer_override_invalid`); pri hrúbke, prekážke, KD, poškodenom pine či `drawer_stale` by reset zásahu konflikt nevyriešil ·
  nález **„kód zo setu nie je v katalógu"** (`hardware_code`) mieri na svoj **živý riadok** kovania, ad-hoc zdroj ostáva na dnešnej ceste (ručné položky riadok s identitou nemajú).
  Testy: `tests/pure/test_kovd4_ui.rb`, `tests/js/test_kovd4_ui.js` (47 assertov), **10 overených mutácií** + in-SU sekcia **`run_kovd4`** (drawer → door → drawer, zmena otvárania).
  **D5 · ABS FARBENIE DIELCOV ZÁSUVIEK — ✅ HOTOVÉ (v0.9.42, 7.9.2026):** (1) **`axes:` pre všetky roly zásuvky** — `Construction.drawer_part_descriptor` ich dáva pomenovanou
  konštantou podľa umiestnenia boxu (dno `AXES_LYING`, chrbát a vnútorné čelo `AXES_WALL`, bok boxu **nová `AXES_WALL_DEPTH`** = rovina YZ, dĺžka NL po hĺbke); `ROLE_AXES` pozná
  všetky štyri roly (jeden kandidát na rolu), takže **stará zákazka bez `axes`** si ich dopočíta z kvádra. (2) **Orientácia hrán stojacich rolí (Astra #20 F15):** preklad kódu
  hrany na stenu kvádra žije v dvoch pomenovaných mapách `PartFaces::EDGE_FACES` (default) a **`STANDING_EDGE_FACES`** (L1 = MAXIMUM osi šírky = HORNÁ plocha, L2 dolná; W1/W2 sa
  nemenia); dostávajú ju výhradne roly v `PartFaces::STANDING_ROLES` a `AbsRules::STANDING_ROLES` je odteraz jeho **alias** (jediný literálny zoznam). Mapu číta farbenie plôšok
  (`CabinetBuilder.paint_edge_faces`) aj zvýraznenie Kontroly (`EdgeCheck`) a hover (`HoverEdge`) — všetky posielajú ROLU, vlastnú kópiu mapy nemá ani jeden (zdrojový guard).
  (3) **Recept, ABS pravidlá, schéma ani výstupy sa nemenia** — seed 4 (L1 = 1,0 mm) platí ďalej, `axes` žijú len v pláne (na entitu sa nezapisujú), takže kusovník aj VEPO CSV sú
  bajtovo identické a korpusové dielce mapujú hrany presne ako pred D5 (charakterizácia). Testy: `tests/pure/test_kovd5_abs_zasuvky.rb` (18), **5 overených mutácií** + in-SU
  sekcia **`run_kovd5`** (Atira chrbát páska HORE a dno bez, Quadro bok boxu aj vnútorné čelo HORE, Kontrola tá istá plôška, Späť/Redo, stará zákazka po prestavbe).
  **explain (Astra #20 N16):** existujúci `Recipes.explain_stored` + `HardwareSets.explain` (členovia, kódy) sa v D len sprístupnia (D1b/D2b), žiadny druhý explain ani snapshot.
  **Scope OUT / presunuté:** Tip-On dvierka `class:hinge|tipon` → **KOV-F** (Astra #20 F14: závesové položky nenesú `opening_mode`, potrebuje dvojsegmentový hinge resolver) ·
  hromadný projektový upgrade (po D3b) · viacosový diff-modal · pomer D-109 · lifty (E) · linear pricing a sync tyč dĺžková (po V1) · šablóny 🔧 (I) · editor receptov · snapshot receptov.
  **Audit:** predaudit HOTOVÝ (Astra, checkpoint #20; 4 BLOCKER + 13 FIX + 2 NOTE zapracované) — ďalšia brána = kód + testy + in-SU per rez; GH Codex kolo per PR podľa pravidla
  delta-verifikácie a 3 kôl (pri P1 v 3. kole rezať, nie iterovať).
  **Smoke pre Michala (po D2b/D3b):** vlož skrinku so zásuvkou → Nákup kód podľa NL a výšky · prepni set skrinky na alternatívnu rodinu (po doplnení dát; dovtedy fixtúra v testoch) → iný kód, dielce rovnaké, nosnosť nezmenená ·
  zamkni NL 420, zmeň hĺbku na 600 → NL 420 · zmenši hĺbku na 400 → RED + návrh 350, potvrď → 350 zamknuté, výškový zámok nedotknutý · zamkni výšku H70, zvýš čelo na 200 → H70 drží
  · „Prejsť na recept v2" (až po vydaní reálnej v2; dovtedy in-SU nad fixtúrou) ukáže dopad, potvrdenie = 1 Späť, Redo obnoví v2 konzistentne; pri konflikte cieľa sa neuloží nič · Kontrola: ceruzka zvýrazní riadok.
  **Checklist uzáveru (per PR):** bump patch + `?v=` → testy (+ in-SU pri D2/D3/D5) → `hardware.md` (mapovanie owner kľúč, zámky per os, upgrade), `ui-lifecycle.md` (chipy,
  modal, highlight), `model-a-identita.md` (CONFIG_SCHEMA 6 v D1a, 7 v D2a; `recipe_refs` neplatný záznam), `outputs.md`, **`construction.md` pri D5** (osi deskriptora, orientácia hrán `PartFaces`) → STANDARD §6/§8.3 → D-109/D-111 stav v DOGFOODING → STAV/KRONIKA/PLAN.

- **D-118 · Katalógový seed pre kódy setov — ✅ HOTOVÁ CELÁ** (Michal 7.9.; **D-118a** PR #320 v0.9.43 + **D-118b** PR #321 v0.9.44). Katalóg má 114 položiek s overeným
  názvom, cenou s DPH, URL, dátumom, výrobcom a radou; sety objednávajú správnu antracitovú K-sadu (`357889`) a Tip-On zásuvka aj **PTOs modul** (`352908`/`352909`).
  Plné znenie + čo z toho platí ďalej: [archiv/DOGFOODING_vyriesene.md](DOGFOODING_vyriesene.md).
- **✅ HOTOVÉ (PR #328, v0.9.47)** — **KOV-W · „HMOTNOSŤ DIELCOV A ČIEL + D-125":** jeden vzorec `Materials.weight_kg` (mm × hustota typu / 1e9) obsluhuje plán (aditívne
  `weight_kg`/`weight_estimated` na deskriptoroch — podklad pre závesy F a výklopy E cez nový vstup pravidla `weight`), súčet nad snapshotmi (`Bom.weight_totals`) aj
  riadok **Hmotnosť** v Inspectore (`12,4 kg` · `≈ 12,4 kg` s tooltipom · `—` len bez dielcov). Rozhodnutie Michala 8.9.2026: neznáma hustota (UNI · typ mimo registra ·
  materiál mimo katalógu) sa **nevynecháva, ráta sa ŤAŽŠIE** (`fallback_density` = max registra okrem kompaktu, nikde ako literál) a priznáva sa jedným ORANGE
  `weight_density_unknown` na skrinku (vzniká LEN za dielce, ktoré UNI nie sú — UNI už hlási `uni_material`; filtruje plán, nie Kontrola). Hmotnosť čela sa ráta
  z KATALÓGOVEJ hrúbky kanála/overridu (25 mm čelo = 22,5 kg, nie 16,2 z placeholderu 18 mm; pri UNI ostáva hrúbka dielca). Bez `materials:` sa plán správa ako predtým; do modelu
  ani do snapshotu sa hmotnosť neukladá (`plan_schema` bez bumpu, kusovník/VEPO/ceny nedotknuté). **D-125 tým vyriešená** — plné znenie a revízia zadania
  v [archiv/DOGFOODING_vyriesene.md](DOGFOODING_vyriesene.md).
- **D-119 · Presah dverí do strán per strana** (Lucia 6.9.2026, prvý test) — dnes jedna hodnota `gap_sides` pre obe strany; ľavá a pravá zvlášť (config čela, CONFIG_SCHEMA
  bump). Zaradenie: UI/UX balík Čiel (D-114) na konci bloku, skôr len ak blokuje prácu. Plné znenie v [DOGFOODING.md](../DOGFOODING.md).
- **D-120 · Úchytkový profil (UKW) aj na dolnej a bočných hranách** (Lucia 6.9.2026) — voľba hrany profilu (dnes len horná; registry `front_profiles` hranu nepozná → rozsah = config + registry/API + všetci konzumenti: Fronts, kovanie, renderer, UI). Zaradenie:
  **do balíka Čiel (D-114) — rozhodnuté 8.9.2026, NIE do KOV-F.** Plné znenie v [DOGFOODING.md](../DOGFOODING.md).
- **KOV-W · „HMOTNOSŤ DIELCOV A ČIEL" (pred F a E; MALÁ; v2 po Codex #327; debata 8.9.2026 → [zdroje/next_sessions/KOVANIE_DEBATA_E_F_2026-09-08.md](../zdroje/next_sessions/KOVANIE_DEBATA_E_F_2026-09-08.md)):**
  **BEZ nového modulu** — vzorec do `Materials` (`weight_kg(l, w, t, density)` = l × w × t [mm] × hustota [kg/m³] / 1e9; `fallback_density` = najvyššia hustota doskového typu
  v `TYPE_REGISTRY` okrem kompaktu, nikde ako literál; `density_or_fallback(rec)` → `[hustota, odhad?]`), súčty do `Bom` (`weight_totals(records, sheets)`), anotácia do
  plánu v `Construction` (`build_plan(..., materials:)` voliteľný vstup z buildera — per kanál `body/front/back/drawer` **hrúbka AJ hustota** z katalógového záznamu +
  per-part override, vzor `part_thicknesses`; **hmotnosť čela sa počíta z ROZLÍŠENEJ hrúbky kanála/override, nie z placeholder `FRONT_THICKNESS` 18 mm v deskriptore** —
  geometria sa nemení, builder materializuje hrúbku ako doteraz (Codex #327 kolo 2); každý deskriptor dostane aditívne `weight_kg` + `weight_estimated`;
  `HardwareRules.input_value` pozná vstup `'weight'`) · **JEDNA sémantika odhadu (Michal 8.9. nahrádza znenie
  D-125 zo 6.9.):** neznáma hustota (UNI, typ bez hustoty) = **fallback hustota, dielec DO SÚČTU VSTUPUJE ako ťažší odhad** a stav sa prizná: v pláne jeden ORANGE build
  warning `weight_density_unknown` na skrinku (pri UNI dielcoch potlačený ako ABS warningy — UNI už hlási `uni_material`), v Inspectore `≈ 12,4 kg` s tooltipom „N dielcov bez
  hustoty rátaných ako <hustota> — ťažší odhad"; `—` LEN bez výrobných dielcov; žiadne `weight_missing`, žiadne vylúčenie z medzisúčtu · **D-125:** payload Inspectora
  `weight_kg` + `weight_estimated_parts` + `weight_estimated_density` (aditívne) · **Audit ÁNO (Sol — mení kontrakt deskriptora `BuildPlan` a payload Inspectora, hoci aditívne; Codex #327 kolo 2)** · in-SU sekcia `run_kovw`
  (builder → plán) · Smoke: dvierka 1000 × 600 × 18 DTD 680 → 7,34 kg; čelo 2000 × 600 MDF 25 mm → 22,5 kg (nie 16,2 z 18 mm); skrinka s UNI dielcom → „≈" + ORANGE.
- **✅ KOV-F je KOMPLET (F1 PR #329, v0.9.48 · F2 PR #330, v0.9.51) — KOV-F · „ZÁVESY — NOXUN TABUĽKA + SET PODĽA OTVÁRANIA" (po W; v3 po Sol audite kolo 2 [2 BLOCKER + 4 FIX + 1 NOTE] — DVA PR: F1 jadro ✅, F2 editor ✅):**
  **F1 jadro — ✅ HOTOVÉ (PR #329, v0.9.48).** **Druh pravidla ostáva `bands`** — ŽIADNY nový kind (Sol kolo 2 BLOCKER 1: starší plugin vrátane NOVÉHO vloženia skrinky s aktualizovanou knižnicou by
  neznámy kind preskočil = nula závesov; čítače pravidiel `std` ignorujú, takže sa to nedá dohnať markerom). Seed `zavesy-podla-vysky` dostane novú tabuľku
  **`bands` [`{max: 849, quantity: 2}`, `{1700, 3}`, `{2200, 4}`, `{2400, 5}`, `{2600, 6}`, `{2800, 7}`, `{max: nil, quantity: 7}`] — výška ≤ max (Float, inkluzívne; 849 < h < 850 → 3); catch-all `nil → 7` ostáva kvôli STARÝM čítačom (dvere nad 2800 dostanú 7, nikdy nič — Codex #327 kolo 3)** a VOLITEĽNÉ polia,
  ktoré starší čítač zachová a ignoruje (`normalize_rules` neznáme kľúče drží): `width_plus: {over: 600, add: 1}` (šírka > 600 → +1, bez podmienky výšky) ·
  `width_warn_over: 800` (ORANGE `door_wide`) · `weight_bands` [`{7.7, 2}`, `{13.7, 3}`, `{17.1, 4}`, `{22.0, 5}`] (Hettich, z kódu oficiálnej kalkulačky) · `finite:
  true` (= pre NOVÝ čítač je catch-all „mimo tabuľky": zásah catch-all pásma = položka s jeho počtom + RED; validátor „potrebuje pásmo všetko nad" ostáva bez zmeny — Sol
  kolo 2 FIX 6 + Codex #327 kolo 3). Starší plugin teda ráta podľa novej tabuľky
  (len bez +1 a varovaní), NIKDY nulu; **`CONFIG_SCHEMA` 8 → 9** kvôli trvalému poľu `hardware_conflicts` a klasifikovaným závesom — starší plugin by nosič aj triedny
  kľúč pri prestavbe ticho zahodil a schému 8 zapísal späť (Codex #329) · **`HardwareRules::STD` bump + nový čítač od tejto verzie honoruje `std`** (snapshot/knižnica
  z novšieho pluginu = len na čítanie s hláškou, vzor setov) — chráni budúce zmeny · varovania ORANGE (nemenia počet): `door_wide`, `door_wider_than_high`
  („nemá to byť výklop?"), `hinge_weight_more` (hmotnostné pásmo chce viac než **VÝSLEDNÝ počet po override/zámku**), `hinge_weight_max` (nad posledným pásmom);
  `weight_kg` nil → `hinge_weight_unknown` v `BUILD_INFO_ONLY` (Sol kolo 2 NOTE 7); **hmotnosť vo V1 len varuje** (Michal 8.9.) · **nad tabuľkou (`finite` a zásah catch-all pásma): položka SA VYDÁ s počtom catch-all pásma (riadok v Kovaní existuje — Sol kolo 2 BLOCKER 2) + RED `door_height_out_of_table`** s uloženým nosičom
  `hardware_conflicts` v configu (aditívne pole `[{owner_part_key, code, message}]`, zapisuje builder v `merge_final` ako `drawer_conflicts`; `Bom.collect` ho zlúči do
  `hardware_issues`), kód ide do **JEDINÉHO registra brán `BuildPlan::HW_BLOCKERS`** (zásuvkové kódy z `Recipes::BUILD_BLOCKERS` + závesy + výklopy; `export_blockers` ho číta pre HW CSV, rozpočet XLSX aj cenovú ponuku — helper `drawer_blockers` sa zovšeobecní na `hardware_blockers`; Codex #327 kolo 3), NIE do VEPO zoznamu; existujúce zásuvkové brány bajtovo rovnaké (test); náprava = ručný zámok
  počtu (override) → RED zhasne; test reopen + Undo/Redo (Sol kolo 2 FIX 5) · **seed pravidlo** sa v globálnej knižnici nahradí LEN v presnom starom seed tvare
  (`LEGACY_SEED_SHAPES` pre pravidlá, vzor D-118b), projektový snapshot cez „Doplniť nové predvoľby"; **prekryv:** iné zapnuté pravidlo s výstupom `hinge` pre `front_door`
  → seed sa nedopĺňa + ORANGE `hardware_rule_overlap` (uplatní prvé) · **sety a mapovanie:** (1) úplná klasifikácia seed setov `zaves-klasik`/`zaves-p2o` (`use_type door` ·
  `opening_mode classic|tipon` · `manufacturer Hettich` · `series Sensys`) LEN v nedotknutom seed tvare, lazy std bump; (2) **triedny kľúč `hinge` dostane vlastnú vetvu v
  ponuke setov aj v zápisovej validácii** — bez systému zásuviek, klasifikácia = use_type + opening_mode + výrobca/rada (Sol kolo 2 FIX 3); (3) kľúče `class:hinge|classic` /
  `class:hinge|tipon` odvodené z účinného legacy mapovania projektu (vlastný set ostáva účinný; neklasifikovaný → legacy + ORANGE `hinge_set_unclassified`; `tipon` →
  `zaves-p2o` len bez vlastného tipon setu) — **migrácia JEDNORAZOVÁ** (značka v snapshote `migrations: ['hinge_class_v1']`), voľba „bez setu" ukladá **vyhradený sentinel
  mapovania `none`** (round-trip cez `parse_mapping`, zmrazenie snapshotu, resolver aj editor — samostatný kontrakt, nie členský `code_by_nl`; Codex #327 kolo 3), nie
  mazanie kľúča (Sol kolo 2 FIX 4); existujúci kľúč sa nikdy neprepíše; všetko idempotentne v `ensure_project_state!`; precedencia **override vlastníka
  > triedny override skrinky > generický override skrinky `hinge` (vlastný set skrinky NIKDY ticho nespadne na projektový default — Codex #327 kolo 2) > triedny kľúč
  projektu > legacy `hinge`**; expanzia overuje klasifikáciu — **definitívny nesúlad (Tip-On čelo na klasickom sete) = RED `hinge_set_mismatch`** — vzniká pri EXPANZII
  (aj keď sa mapovanie zmení po prestavbe), preto ho exportná brána číta z `expansion['unmapped']` rovnako ako `drawer_kit_missing` (Codex #327 kolo 3), s nápravou (vyber
  set / Doplniť nové predvoľby) · položka nesie `params.opening_mode` + `params.use_type =
  'door'`; piest 1 ks/krídlo ostáva `per: owner` · per-krídlo triedny override MIMO F · len naložený · úchytky MIMO V1 · Audit: v3 = 3. (posledné) kolo Sol PRED implementáciou
  · Testy: hranice 849/849,5/850 · 600/600,5 · 800/801 · explicitné `wings` · 2/3/4 krídla = rovnaký počet piestov · nad 22 kg · zámok pod hmotnostným pásmom → varovanie ·
  vlastný set prežije migráciu · sentinel `none` prežije prestavbu, reopen aj normalizáciu mapovania · **downgrade: starší čítač (`std` ignorovaný) dostane pri novom projekte závesy podľa tabuľky bez +1** ·
  in-SU `run_kovf`. Smoke: 1250 → 3; 850 → 3; 800 × 700 (1 krídlo) → 3; Tip-On → P2O + 1 piest; 850 široké → ORANGE; MDF 25 mm 2000 × 600 → ORANGE nad 22 kg; 2900 vysoké →
  7 + RED, zámok ho zhasne.
  **F2 editor — ✅ HOTOVÉ (PR #330, v0.9.51).** V Pravidlách je pri pravidle závesov (a pri každom `bands`, ktoré už guard nesie) **zbaliteľný blok „Kontroly dvierok"**
  so súhrnom v lište: šírka nad X → +N · varovanie nad šírku · tabuľka hmotností (pridať/odobrať riadok) · prepínač „tabuľka je konečná". **Validácia je spoločná**
  (Ruby `weight_bands_problem` + JS zrkadlo, parita cez `tests/fixtures/rules_validation_parity.json`): prázdna tabuľka hmotností · pásmo bez kilogramov · dve pásma
  s rovnakou hmotnosťou. **ODCHÝLKA od pôvodného znenia (vedomá):** vety pre `over`/`warn` ≤ 0 a `add` < 1 nevznikli — také stavy sa v editore nedajú vyrobiť (prázdne
  alebo nekladné pole = kontrola vypnutá, chýbajúci počet = 1, rovnaký clamp ako pri výškových pásmach) a serverová normalizácia taký guard aj tak zahodí (kontrakt F1),
  takže veta by bola mŕtva vetva a rozbila by paritu klient/server. **Poradie pásiem sa nevynucuje** — server ich zoraďuje sám. „Všetko nad" ostáva povinné aj s `finite`
  (rozhodnutie F1, Codex #329 kolo 3: catch-all drží starý čítač).
- **KOV-E · „VÝKLOPY HK top / HL top" ✅ KOMPLET (po F; v4 9.9.2026 — po Astra audite [zdroje/next_sessions/KOVANIE_KOVE_AUDIT_2026-09-09_ASTRA.md](../zdroje/next_sessions/KOVANIE_KOVE_AUDIT_2026-09-09_ASTRA.md) [4 BLOCKER + 7 FIX + 1 NOTE] a Codex GH #331 kolo 1 [2 P1 + 6 P2] + kolo 2 [4 P1 + 1 P2]; TRI PR: E1a dáta, E1b pravidlo + brány, E2 UI):**
  **Dáta (uzavreté 9.9.):** [zdroje/demos/SEED_AVENTOS_v2_2026-09-09.md](../zdroje/demos/SEED_AVENTOS_v2_2026-09-09.md) — **26 kódov Démos** (ceny s DPH 9.9., URL, MJ), z nich
  **23 nových** do `SEED_ROWS` (347827, 13781, 250831 už existujú — identita katalógu sa nemení); **hmotnostné limity HL top z Blum katalógu 2024/25** (verejný zdroj,
  e-services netreba): ramená 22L3200 KH 300–339 / 1,5–9 kg · 22L3500 340–389 / 1,75–10 kg · 22L3800 390–540 / 2–12,25 kg · 22L3900 480–580 / 2,5–14 kg — **hmotnosť
  VRÁTANE úchytky** (Astra BLOCKER 3, Codex P1). Rozhodnutia Michala: **len skrutkové varianty** · **HL top Tip-On NEEXISTUJE** (len klasický) · Tip-On jednotka 76 mm
  **BEZ adaptéra** (zavŕtava sa) · **stabilizačná tyč VŽDY** v HL sete, **od šírky korpusu KB ≥ 1100 mm 2× tyč + predlžovací diel** (delenie tyče medzi úzke skrinky =
  „Dĺžkové", mimo V1) · **farba setu = jedna voľba, zasahuje krytky aj Tip-On spolu:** biela (predvolená) | tmavá (= tmavo šedé krytky 347835 / 507345 + čierny Tip-On
  497007; čierne krytky Démos nemá, šedá sa nerieši) · príliš ľahké čelo = **ORANGE** · plný automat bez zámkov.
  **Definície (Astra FIX 5; Michal potvrdil 9.9.2026):** **KH = výška korpusu BEZ sokla** (`height − floor_height`, nezaokrúhlený Float — Blum KH je korpus, nie výrobná dĺžka
  čela 396 pri korpuse 400); **V1: výklop = JEDINÝ riadok čiel skrinky** — viac riadkov s výklopom = RED `lift_multirow_unsupported` (hint „rozdeľ na samostatnú skrinku");
  deskriptor dielca nesie `flap_dir` + `lift_system` explicitne (dnes žije `flap_dir` len na resolved čele).
  ✅ **E1a DÁTA — HOTOVO (PR #332, v0.9.53):** katalóg **23 riadkov** (`SEED_ROWS` 9 polí vzor D-118a, kategória VYKLOPY, výrobca Blum,
  rada AVENTOS, dátum 9.9.2026) cez migráciu (`seed_version` bump, používateľské položky sa neprepisujú) · **člen setu — dva nové tvary** (Codex P1, Astra FIX 8/9):
  **`code_by_param: { "param": "lift_class", "codes": { "22K2300": "347810", … } }`** (serializovaný selektor, string kľúče, `code XOR code_by_nl XOR param_bands XOR
  code_by_param`; chýbajúci kľúč = NEVYRIEŠENÝ člen) a **`quantity_from: "rod_count"`** (celé číslo ≥ 0 z `params`; `rod_extension` explicitne 0/1; **0 = člen sa VEDOME NEVYDÁ — rozhodne sa PRED `add_row`, žiadny
  riadok s počtom 0** [Codex #331 kolo 2 P2; test: HL pod 1100 nemá riadok 507366 vôbec]; chýbajúca/necelá hodnota = nevyriešený člen) — `MEMBER_KEYS` + obsahová detekcia `snapshot_std` (lazy bump); **downgrade je FAIL-CLOSED a taký sa aj testuje:** starší čítač
  (`incompatible_member?`) set s neznámym kľúčom označí NEKOMPATIBILNÝ → knižnica/snapshot len na čítanie s hláškou (žiadne tiché „tyč 1 ks"; Codex P2, Astra FIX 8) ·
  **klasifikácia:** nové pole `lift_system` (`hk_top|hl_top`) pri `use_type lift` (whitelist + round-trip guard), `parse_class_head` tretí segment pre `lift` = `lift_system`
  (pre `slide` ostáva konštrukcia zásuvky — validácia rozlišuje podľa typu), kľúče **`class:lift|classic|hk_top` · `class:lift|tipon|hk_top` · `class:lift|classic|hl_top`**
  (`class:lift|tipon|hl_top` validácia odmietne) · **owner výklopu** `front:<id>/flap` — `CLASS_OWNER_RE` + `parse_class_key` + `validate` + resolver + pruning sa učia
  `/flap` v JEDNEJ dávke (Astra FIX 6) **+ `CONFIG_SCHEMA` 9 → 10 UŽ V E1a** (Codex #331 kolo 2 P1: owner mapovanie `…@front:<id>/flap` v `config.hardware_sets` by starší
  plugin so schémou 9 ticho zahodil — `parse_class_key` `/flap` nepozná; E1b bumpne znova 10 → 11); **voľba tmavého setu = `config.hardware_sets` s kľúčom `class:lift|<mode>|<system>@front:<id>/flap` → set_id** (NIE `hardware_overrides` — Codex P2),
  precedencia ako F (owner > triedny override skrinky > triedny kľúč projektu) · **6 seed setov** (vzor antracit D1b): `vyklop-hk-klasik` (biela, predvolený pre kľúč) /
  `vyklop-hk-klasik-tmavy` · `vyklop-hk-tipon` / `-tmavy` · `vyklop-hl-klasik` / `-tmavy`; členovia: mechanizmus `code_by_param lift_class` {22K2300→347810, 22K2500→347811,
  22K2700→347812, 22K2900→347813; tipon 347814/347826/347827/347828; HL 22L2200→507351, 22L2500→507352} 1 sada · čelný príchyt 13781 1 pár · krytky (HK 347834 | tmavé 347835;
  HL 507343 | 507345) 1 sada · tipon: Tip-On 250831 | tmavá 497007 `per: owner` 1 ks (**bez adaptéra**) · HL: ramená `code_by_param arm_class` {22L3200→507355, 22L3500→507356,
  22L3800→507357, 22L3900→507358} 1 sada + tyč 507365 `quantity_from rod_count` + predĺženie 507366 `quantity_from rod_extension` · sety cez `LEGACY_SEED_SHAPES` / lazy std
  (vzor D-118b), projektový snapshot cez „Doplniť nové predvoľby" · **editor setov (hw_sets.js) člena `code_by_param`/`quantity_from` NESMIE zahodiť** (Astra FIX 10): sety
  s novým tvarom sú v editore **read-only** (badge „tvar novšej verzie — úprava v E2"), transport bezstratový · RED `lift_set_mismatch` pri EXPANZII (Tip-On čelo na klasickom
  sete, HL set na HK čele; vzor `hinge_set_mismatch`) · Testy: round-trip `code_by_param`/`quantity_from`/`lift_system`/owner `/flap` · starší čítač = nekompatibilný ·
  6 setov kompletné (každý kľúč `codes` má katalógový riadok) · `parse_class_head` `slide` vs `lift` tretí segment.
  **DELTA AUDIT SOL (9.9.2026, session `01a08558-c5d7-77e1-824d-1325ec6b5fcb`) — 5 ZÁVÄZNÝCH rozhodnutí pred E1b, všetky zapracované:**
  **(1)** vnútorná hĺbka pre eligibility HL ide z **`ctx['available_depth']`**, nie z `depth − chrbát` (drážka `GROOVE_OFFSET` by unikla, overlay chrbát by sa odčítal
  dvakrát) · **(2)** RUNTIME prekryv v `evaluate` sa porovnáva podľa **(output, role, `flap_dir`|wildcard)** a `OVERLAP_OUTPUT` platí pre `hinge` **aj** `lift` (dovtedy len
  rola a len `hinge`: skoršie `hinge/flap/up` pravidlo by potlačilo `zavesy-sklop` aj na skrinke len so sklopom a dve `lift` pravidlá by dali dva mechanizmy) ·
  **(3)** guard **nedostupnej expanzie** platí aj pre položky `lift` — vyriešené UŽ V E1a (`hardware_expansion_unproven?`, Codex #332 kolo 2 P1), v E1b sa len overuje
  end-to-end nad položkou z pravidla · **(4)** **`flap_stale` NIE podľa prítomnosti seed pravidiel, ale VÝHRADNE podľa proveniencie stavby** (`config_schema` < 11);
  skrinka prestavaná pod schémou 11 nie je stale nikdy — pri vedome vypnutom vlastnom výklopovom pravidle by RED nezhasla nikdy (`pre_lift_rules?` sa nezavádza) ·
  **(5)** **`HardwareRules::SEED_VERSION` 4 → 5** samostatne od `STD` — bez bumpu by `merge_seed` migráciu preskočil a existujúca knižnica by nové seed pravidlá nedala
  ani novým projektom.
  ✅ **E1b PRAVIDLO + BRÁNY — HOTOVO (PR #333, v0.9.54):** config čela `lift.system` (`hk_top` predvolene | `hl_top`,
  **CONFIG_SCHEMA 10 → 11** — 10 minula E1a; whitelisty šablón aditívne) + **`lift` bezstratovo na CELEJ ceste**: `FRONT_EXTRA_KEYS` (form.js) **A server** — `Fronts.normalize_items`
  (dnes kopíruje len smer/otváranie/zásuvku) + `DORMANT_KEYS`/`Fronts.layout` projekcia do resolved `front_items` (Codex #331 kolo 2 P1: inak prestavba HL ticho spadne na HK;
  Astra FIX 10) ·
  **sklop (`fall`) = závesy ako dvierka:** DRUHÉ seed pravidlo `zavesy-sklop` (rovnaké `bands` + door guardy ako F) s `applies_to: {role: flap, flap_dir: down}` —
  `applies_to.role` skalár, pravidlo dvierok ostáva na `front_door` (Codex #327 kolo 3); `apply_rule` sa naučí filter `flap_dir`; položky `params.use_type = 'door'`
  (sety `use_type fall` — vzpery — mimo V1; test: sklop nikdy nevydá `lift`) · nový rule kind **`lift_class`** (seed `vyklopy-aventos`, `applies_to: {role: flap, flap_dir:
  up}`), JEDNA položka `lift` per výklop s `params` {`lift_system`, `lift_class`, `arm_class` (HL), `rod_count`, `rod_extension` (0/1), `opening_mode`, `use_type: 'lift'`};
  JSON pravidla: `handle_allowance_kg` **0,5** (**pri OBOCH systémoch**, pripočíta sa pred min/max aj prekryvom — Blum LF aj HL tabuľka rátajú úchytku; Astra BLOCKER 3,
  Codex P1), `classes[]` HK (`22K2300` 420–1610 · `22K2500` 930–2800 · `22K2700` 1730–5200 · `22K2900` 3200–9000; Float, inkluzívne; prekryv = **najslabšia trieda, ktorá
  LF pokrýva**), HL `mechanisms[]` SPOJITÉ max-pásma (KH < 390 → `22L2200`, ≤ 580 → `22L2500`) a **`arms[]` SPOJITÉ** (Astra FIX 7): `[300,340)` 22L3200 (1,5–9 kg) ·
  `[340,390)` 22L3500 (1,75–10) · `[390,540]` 22L3800 (2–12,25) · od 480 aj 22L3900 (2,5–14) · `(540,580]` 22L3900 — v prekryve **najslabšie ramená, ktoré hmotnosť
  pokrývajú**; `rod_double_from_kb_mm` **1100** (KB ≥ → `rod_count` 2 + `rod_extension` 1, inak 1 + 0); **`eligibility`** per systém (Astra BLOCKER 4; hodnoty Blum,
  Michal potvrdil 9.9.2026): HK `kh_min 205 · kh_max 600 · kb_max 1800`, HL `kh_min 300 · kh_max 580 · kb_max 1800 · depth_min 264` (vnútorná hĺbka) · **HK: `LF = KH × (weight_kg +
  handle_allowance_kg)`** · **brány — jediný register `BuildPlan::HW_BLOCKERS`** (HW CSV + rozpočet + cenová ponuka; geometria a VEPO nie): RED `lift_class_missing`
  (LF/KH/kg mimo tabuľky alebo `weight_kg` nil — bez hmotnosti sa trieda NEDÁ určiť; položka `lift` sa vydá BEZ triedy → set ju nepreloží → brána úplnosti) · RED
  **`lift_set_incomplete`** (Astra BLOCKER 1): KAŽDÝ nevyriešený člen setu položky `lift` (chýbajúci kód triedy, `quantity_from` bez hodnoty, chýbajúci set/mapovanie)
  → `blocks_export` ako receptové položky + kód v `from_expansion` (`ProductionCore.hardware_blockers`) — nikdy „krytky bez mechanizmu" · RED
  `lift_dimension_unsupported` (eligibility) · RED `lift_multirow_unsupported` · RED `lift_combo_unsupported` (`hl_top` + Tip-On) · RED **`flap_stale`** (Astra BLOCKER 2 + Codex #331 kolo 2 P1):
  `flap_stale_issue` v `Bom.collect` (tretí vzor po `drawer_stale_issue`/`hinge_stale_issue`) — **aktivačná brána podľa verzie, nie podľa nájdenej položky** (`hinge_stale_issue`
  hľadá uložený záves a pri žiadnom mlčí): skrinka s čelom `flap` (**up AJ down**) postavená pred `HardwareRules::STD` E (config nesie std z poslednej stavby; chýba = staré) bez
  položky `lift` (up) / bez závesov `use_type door` na tom čele (down) = existujúca zákazka po upgrade (`ensure_project_rules!` seed nedopĺňa) → RED nákup/rozpočet/ponuka,
  náprava „Doplniť nové predvoľby + prestavba" · ORANGE `lift_light_front` (pod min: HK
  LF < 420 · HL kg < kg_min ramien; položka s najslabšou triedou) · ORANGE `hardware_rule_overlap` (iné zapnuté pravidlo s výstupom `lift` pre `flap` **A rovnakým smerom** `flap_dir up` (alebo bez filtra smeru) → seed sa nedopĺňa;
  `seed_additions` prekryv porovnáva `applies_to.role` AJ `flap_dir` — vlastné pravidlo len pre `down` (vzpery) seed NEPOTLAČÍ; Codex #331 kolo 3 P1; rovnako pre `zavesy-sklop` s `hinge`/`down`)
  · `door_wider_than_high` sa na výklop NEuplatňuje · **plný automat = položky zo seed pravidla `vyklopy-aventos` chránené ako receptové** (Astra FIX 11; rozsah zúžený podľa Codex #331 kolo 2 P1 — vlastné pravidlá
  s `output: lift` a ich overridy `(owner, lift, rule_id)` ostávajú ÚČINNÉ): `apply_overrides` pre `rule_id == 'vyklopy-aventos'` `disabled`/`quantity` ignoruje + ORANGE
  `lift_override_ignored`, neplatné overridy LEN toho pravidla normalizácia vyčistí so záznamom v logu · `HardwareRules::STD` bump (čítače od F `std`
  honorujú); **downgrade pravidla:** starší plugin kind `lift_class` nepozná → výklop bez položky (VEDOMÉ riziko do D-48; knižnice per PC, updater D-52) · Testy
  (headless, Float): LF 419,9/420 · 1610/1610,5 (→ 22K2500) · 1730 · 2800/2800,5 · 9000/9000,5 (RED) · KH 299/300 · **339,5 · 389,5** (ramená bez medzery) · 389/390
  (22L2200+22L3500 → 22L2500+22L3800) · 540/540,5 · 580/581 (RED) · kg 9,00/9,01 pri KH 320 **vrátane 0,5 rezervy** (RED — žiadne iné ramená) · 12,25/12,26 pri KH 500
  (22L3800 → 22L3900) · 14,00/14,01 (RED) · KB 1099/1100 (`rod_count` 1 → 2 + `rod_extension` 0 → 1) · KH 396 čelo v korpuse 400 → KH = 400 · korpus so soklom → KH bez
  sokla · KB 1801 / hĺbka 263 (HL) / KH 204 (HK) → RED eligibility · `weight_kg` nil → RED · HL + Tip-On → RED · dva riadky čiel s výklopom → RED · sklop nikdy `lift` ·
  chýbajúci kód člena → `lift_set_incomplete` blokuje export (nie „krytky samé") · stale skrinka bez položky → `lift_stale` · override `disabled` na položke `vyklopy-aventos` → ignorovaný + ORANGE, na vlastnom `lift` pravidle → účinný · `lift.system: hl_top` prežije
  `normalize_items` + prestavbu + reopen · sklop v starej zákazke bez závesov → `flap_stale` · HL pod 1100 → žiadny riadok 507366 · tmavý set v `config.hardware_sets` prežije prestavbu, reopen, Undo · in-SU `run_kove`. Smoke: výklop 600 × 400 v skrinke 400 → LF ≈ 400 × 3,4 = 1380 → 22K2300 +
  príchyt + krytky biela; Tip-On → 22K2300T + jednotka 250831; tmavý set → 347835 + 497007; ťažké čelo → 22K2700; HL 500 vysoká, 6 kg → 22L2500 + 22L3800 + 1 tyč; HL 1200
  široká → 2 tyče + predĺženie; KH 250 → RED; sklop → závesy; stará zákazka s výklopom alebo sklopom → RED `flap_stale`, „Doplniť nové predvoľby" + prestavba ju zhasne.
  **Uzáver E1b:** headless 3597 testov · 100 JS sád · in-SU beh 2055 PASS / 0 FAIL vrátane novej sekcie `run_kove` (27 PASS: HK 22K2300 + kompletný set · HL 22L2500 + 22L3800 + tyč · KB 1200 = 2 tyče
  + predĺženie · Späť/Redo · reopen · sklop dostane závesy · schéma 10 = RED + zastavené 3 výstupy, prestavba ho zhasne). **Odchýlky:** `LIFT_RULES_STD` marker
  sa NEZAVIEDOL (po delta audite FIX 4 ho nemá kto čítať — `flap_stale` ide podľa `config_schema`; `HardwareRules::STD` je 3) a `LEGACY_SEED_SHAPES` sa NEROZŠÍRILO
  (obe pravidlá sú nové, starší tvar na „obnovenie" neexistuje). Pri behu vyšli najavo aj 4 stale in-SU očakávania z E1a (`HardwareSets` std 5 → `STD_LIFT_FORMS` 6) —
  opravené v tej istej vetve.

  ✅ **E2 UI — HOTOVO (PR #334, v0.9.55):** v karte čela výklopu segment **Systém (HK top | HL top)** — sklop ho nemá — a **jeden read-only riadok** vyriešeného výklopu
  („AVENTOS HK top · 22K2300 · automat") s rozklikom **Technický detail** (otváranie, KH/KB tým istým vzorcom ako kontext pravidiel, tyč + predĺženie, balenie a kódy);
  RED dôvod je **doslovne tá istá veta**, akú vydá Kontrola (`hardware_conflicts` cez `BuildPlan::HW_CONFLICT_CODES`), ORANGE je riadok NAVIAC, `stale` ide podľa
  **`Bom.flap_stale_front?`** (tá istá autorita ako RED `flap_stale` — vrátane výnimky pre úplnú ručnú zostavu) · **výber setu vrátane tmavého** beží BEZ zmeny klienta (položka `lift` má triedny kľúč, takže
  `class_compat_payload` naplní `compat.owners['front:<id>/flap']` a existujúci picker D1b vykreslí len triedne kompatibilné sety; zápis pod owner triednym kľúčom
  `class:lift|<mode>|<system>@front:<id>/flap`, jeden krok Späť) · **editor `lift_class` v Pravidlách** (vzor F2: zbalený blok so súhrnom v lište, skaláre, tri tabuľky,
  spôsobilosť per systém; `max_exclusive` prechádza zberom bezstratovo cez `data-mx`) so **spoločnou Ruby/JS validáciou** — nové kritériá (nekladný prah tyče, záporná
  hodnota v tabuľke, spôsobilosť s obrátenou výškou, **nedopísaný riadok tabuľky**) v `rules_validation_parity.json` · **editor setov sa naučil `code_by_param` a `quantity_from`** (stratégia kódu = select
  so 4 voľbami, parameter `lift_class`/`arm_class`/vlastný, tabuľka hodnota → kód, „Počet z parametra" ako druhý riadok hlavičky člena); **read-only z E1a odpadol vrátane
  serverovej brány `new_shape_members?`** — ochranou ostáva validácia obsahu. **Odchýlky:** štítok je posledný segment textu riadku, nie samostatný badge (nový
  markup by pribudol bez zisku) — a hovorí o ZDROJI položky („automat" len pri chránenom seed pravidle, inak „ručne" alebo nič) · **LF/hmotnosť sa v technickom detaile NEDOPOČÍTAVAJÚ** — na položke uložené nie sú a druhý výpočet tej istej veličiny by sa s automatom
  rozišiel; pri probléme ich nesie veta konfliktu · prekryv tabuliek sa nevaliduje zámerne (Blum HK triedy aj ramená 480–540 sa prekrývajú — kontroluje sa len spojitosť) ·
  in-SU beh sa nekonal: dávka nepridala žiadnu novú zápisovú akciu panela (výber setu ide existujúcou `set_hardware_set`).
  **Fix kolo Codex #334 (1 P1 + 5 P2):** uzáver bloku do STAV/KRONIKY · zdieľaný predikát `Bom.flap_stale_items`/`flap_stale_front?` (karta a Kontrola hlásia stale rovnako) ·
  nekladný prah druhej tyče sa neuloží · duplicitná trieda v tabuľke člena setu padne na klientovi (server dostáva mapu) · nedopísaný riadok tabuľky výklopu odmietne
  **druhá brána nad surovým vstupom** (`HardwareRules.lift_input_problems` v `handle_save`, pred normalizáciou) · štítok zdroja položky (`lift_source_tag`).
  Uzáver: headless **3649 testov**, **102 JS sád**.
  · **KOV-E je KOMPLET** (E1a #332 · E1b #333 · E2 #334) · D-114 balík Čiel ostáva na koniec bloku.
- **KOV-G · „NOHY 4/6, PRÍCHYTY, SOKEL PRI VKLADANÍ" ✅ KOMPLET (10.9.2026; TRI PR: G1a dáta, G1b pravidlá, G2 UI — D-111 vyriešené):**
  ✅ **G1a DÁTA — HOTOVO (PR #337, v0.9.58):** set „Nohy podľa výšky sokla" má **sedem pásiem** (17–20 STRONG klzák 272212; 55–90 / 91–115 / 116–140 / 141–170 / 171–190 /
  191–220 Häfele **AXILO**) a druhého člena **platnička** (17–20 sentinel `none`, 55–220 kód 9079) · nový set **„Príchyt sokla AXILO"** + generický typ **`plinth_clip`**
  (`BuildPlan::SCHEMA` 4 → 5, precedens `lift`) · **sentinel `none` v pásme** `param_bands` (tá istá sémantika ako rad `code_by_nl` z D-118b — vyplnené pásmo `none` = člen sa
  vedome nevydá; zákaz z D-118b zanikol) · taxonómia dostala výrobcu **Häfele** a rada AXILO sa presunula spod Hettichu pod neho (jednorazová migrácia sa dotkne LEN presného
  starého seed tvaru) · katalóg **+9 riadkov** (272212 Démos, 8× AXILO od **Quatro LM** — desiaty prvok manifestu je dodávateľ, `nil` = Démos). **Zóna 20–55 mm ostáva vedome
  nepokrytá** → existujúca ORANGE cesta `param_band_missing` s vetou o výške sokla (rozhodnutie Michala 9.9.).
  **Review: TRI kolá (1 P1 + 3 P2 · 1 P1 + 2 P2 · čisté) — vedomá odchýlka od pravidla 3 kôl:** PR nebol zle narezaný, obe kolá tvrdo trafili **dátovú vrstvu** (kovanie by
  potichu zmizlo z nákupu; legacy set zamykal celú knižnicu; klasifikácia seed setov proti živej taxonómii) — teda presne to, čo sa v .skp zamrazí a spätne sa opravuje draho.
  ✅ **G1b PRAVIDLÁ — HOTOVO (PR #338, v0.9.59):** seed `nohy-zakladne` už nie je `fixed 4`, ale **`bands` podľa ŠÍRKY korpusu** (< 1000 mm → 4, od 1000 mm → 6) — platí pre
  **všetky** sety nôh, set rozhoduje len o produkte · nové pravidlo **`prichyt-sokla`** vydáva `plinth_clip` **tými istými pásmami** (1 / 2 = **1 ks na začaté 4 nohy**, O3 —
  bez pomerového člena, D-109 mechanika ostáva R-05) a platí **LEN pri samostatnej soklovej lište**: filter `support legs` + nový voliteľný `applies_to.floor_height_min`
  (55 mm — odkiaľ lišta na nohách AXILO existuje), klzák 17–20 mm príchyt nemá · `Bom.leg_stale_issue` = **ORANGE** (`LEG_STALE`, zámerne mimo `HW_ISSUE_BLOCKERS` — nohy
  výrobu nezastavujú): stará zákazka na nohách so seedom < 6 dostane „prestav ju" · editor Pravidiel dostal hint „Pásma podľa šírky korpusu." a popis roly s prahom sokla.
  **Review: 1 kolo (3 P2) + interná delta-verifikácia (5 P3).**
  ✅ **G2 UI — HOTOVO (PR #339, v0.9.60; D-111):** **jeden** riadok **„Nohy"** v Základných (cez oba stĺpce mriežky, viditeľnosť s riadkom Sokel) — vetu skladá **SERVER**
  (`HardwareSets.legs_summary` z výsledku `explain`, žiadny druhý výklad nákupu; dôvody sa zlievajú cez členov, takže sokel 40 mm dá JEDNU vetu Kontroly) · **dve cesty, jeden
  vzhľad**: označená skrinka = `legs_summary` z **už rozpísaných** položiek + **select setu nôh** (ten istý ovládač ako v Kovanie → Sety, existujúca akcia `set_hardware_set`),
  vkladanie = **čítací** callback `insert_legs_preview` (žiadna operácia, žiadny krok Späť, generácia dotazu, uzavretý payload) · **ghost pásik** dostal segment `gbLegs`
  (skrátený text, len subjekt `cabinet`, počíta sa lenivo raz za session).
  **Review: kolo 1 = 5 P2 + 1 P1 (uzáver bloku).** Fixy: náhľad pri vklade **zo šablóny** ukazoval projektovú predvoľbu → prospektívny stav setov
  (`state_with_template_sets` nad spoločnou `template_sets_selection`, projekt vyhráva) · prepnutie vkladania na **Dosku** nechalo visieť riadok skrinky · odpoveď v lete
  **odkryla riadok pri hornej** skrinke (generácia + typová poistka) · **ľahký push** neobnovil vetu riadku po zmene setu v Štúdiu · **memo pásika** neprežilo zmenu setov
  či pravidiel počas session (hooky `push_hardware_sets` / `after_model_write`).
  **Smoke (Michal):** skrinka 1200 → 6 nôh + 2 príchyty; sokel 150 → iný set nôh viditeľný už pri vkladaní; sokel 40 → oranžová veta o nepokrytej zóne; šablóna s vlastným
  setom nôh → riadok aj pásik hovoria o ňom, nie o predvoľbe projektu. **Audit NIE (risk-based).** Z bloku KOVANIE ostáva **KOV-I**.
- **✅ HOTOVÉ (PR #340, v0.9.61, 10.9.2026) — KOV-I · „ŠABLÓNY — ULOŽIŤ AJ KOVANIE" (po D; posledná dávka bloku):** v mini-modale ukladania šablóny pribudla voľba **„Uložiť aj kovanie (sety a ručné položky)"** (predvolene zapnutá, pamäť poslednej voľby na PC) — dovtedy sa kovanie zmrazovalo VŽDY. Dlaždice v Inspectore aj v Štúdiu ukazujú **ikonu a súhrn** uloženého kovania (`TemplateStore.hardware_summary`, čistá funkcia — žiadne nové perzistentné pole, `STD` ani `CONFIG_SCHEMA` sa nemenili; Štúdio dostáva len krátke texty, nie celé definície). **Poškodený zdroj setov = uloží sa konštrukcia BEZ celého kovania vrátane ručných položiek** a stav povie dôvod (rozhodnutie Michala 10.9.). **R12 rozhodnuté:** `hardware_overrides` (ručná NL, výška, počty) a mapovania na jednotlivé čelá sa **neprenášajú** a UI to priznáva — mapovanie čiel je mimo V1. Materiály korpusu/čiel/chrbta/zásuviek sa prenášajú ako doteraz (pôvodne plánovaný hint „Materiály sa neukladajú" by bol nepravdivý — text opravený). Nová in-SU sekcia `run_kovi` (save callback s kovaním aj bez neho, vloženie receptovej Atiry so zhodným systémom/receptom/NL/setom, projektový default, jeden krok Späť, poškodený snapshot). Pôvodné zadanie: checkbox „Uložiť aj kovanie" v mini-modale Inspectora (dnes freeze vždy → voľba) · 🔧 badge odvodený z prítomnosti
  `hardware_sets` snapshotu (žiadne nové pole) · hover súhrn + read-only detail pred vložením · **R12:** buď prenášať relevantné drawer overridy (`hardware_overrides` pre
  front kľúče) do šablóny, alebo v detaile priznať „zámky sa neprenášajú" — rozhodnúť v package audite · hard conflict blokuje uloženie S kovaním, geometria sa uloží.
  Audit NIE (whitelist šablóny sa rozširuje aditívne; overiť). Smoke: šablóna so zásuvkou má 🔧, po vložení rovnaký systém/NL; bez kovania = defaulty projektu.
- **Mimo V1** (FINAL §12): D-109 pomer (R-05), plný `per:'length'`, HF, Antaro/Strong/TANDEM (dáta pripravené v #10), inner drawer automatika. *(Pri uzávere bloku 10.9.2026 presunuté do sekcie **„Po V1 — zásobník"** v [PLAN.md](../PLAN.md) — tu ostáva ako súčasť pôvodného textu.)*

## CENY-KOV — odkazy a ručné overenie katalógového kovania (10.9.2026)

- **Ceny — CENY-KOV (schválené Michalom 10.9.2026; HOTOVÉ, PR #345/#346, v0.10.4–v0.10.5):** odkazy a ručné overenie **katalógového kovania**. Jeden hlavný odkaz na položku; viac URL a ručné overenie materiálov/ABS ostávajú zo
  zvyšku V1-03 v zásobníku. Voľné ad-hoc položky bez katalógového kódu sú mimo tejto dávky. **Audit ÁNO** — nové polia, lazy schema marker a úzka migrácia katalógu. Dve sekvenčné PR, druhé až z čerstvého main
  po prvom:
  - **CENY-KOV-A · Odkazy — HOTOVÉ, PR #345, v0.10.4:** každá položka (aj Demos) má malú SVG ikonu „Otvoriť produkt" v katalógu aj v Rozpočte. Uložený platný odkaz otvorí iba externý prehliadač; žiadny zápis ceny/dátumu. Chýbajúci odkaz
    = oranžová ikona s vysvetlením, klik otvorí úpravu konkrétnej položky s fokusom na doplnení adresy. Nové voliteľné `product_url` (http/https) pre položky bez Demos väzby; `demos_url` zostáva výlučne
    overovanou väzbou konektora. Uloženie/odstránenie URL ide existujúcim formulárom, revision guardom a zámkom; čítacia cesta pred otvorením adresu znovu overí. Schema 3 len pri novom obsahu chráni pred
    stratou údajov v staršom plugine. Známe Quatro LM odkazy možno previesť z presne pôvodných seed poznámok bez zmeny ceny, dátumu alebo vlastných úprav.
  - **CENY-KOV-B · Ručné overenie — HOTOVÉ, PR #346, v0.10.5:** samostatná akcia „Overiť cenu" z katalógu aj Rozpočtu pre položky bez Demos väzby; jeden spoločný formulár (kód/názov/dodávateľ, cena **s DPH za uvedenú MJ**, odkaz,
    posledné overenie). Pripraví formulár a otvorí web; spätný fokus sa nevynucuje. „Potvrdiť cenu k dnešku" uloží cenu + serverový dátum + ručný pôvod v jednom zápise, so stráženou revíziou a identitou
    požiadavky. Zrušenie, samotný preklik ani obyčajná úprava nič nepotvrdia. Zmena ceny/MJ/zdroja/dodávateľa ručné overenie zneplatní. Chýbajúca cena ostáva priznaná; zmena globálnej ceny sa prejaví pri
    prepočte aj v ostatných zákazkách.
  - **Spoločné pravidlo:** rovnaký nastaviteľný prah ako DEMOS (default 30 dní; vek ≥ prah = upozornenie). Ručne overená mladšia cena je aktuálna, pôvod je viditeľný. Automatický refresh nikdy neparsuje
    `product_url`. Pole `price_check_method: manual` a dátum chránia lazy schema 4; staré DEMOS potvrdenia ostávajú platné. Uloženie obnoví katalóg/panel/Rozpočet existujúcou cestou, bez modelového zápisu.
    Testy pokryjú deň 29/30, zrušenie, konflikt, prepnutie zákazky/sekcie, chýbajúcu cenu a nezmenené DEMOS/ABS/materiály.
  **Predimplementačný audit Astra (10.9.2026):** 0 BLOCKER, 1 FIX-IN-A, 2 FIX-IN-B; všetky prijaté. A overí celý čerstvý nefiltrovaný dokument pod zámkom, aby typovo poškodený riadok nezmizol pri úprave iného.
  B použije existujúci `busyLock` počas odoslaného potvrdenia a zneplatní čakajúcu požiadavku pri odchode z pôvodnej sekcie (aj Rozpočet, aj deep-link), zmene modelu alebo otvorení iného formulára.
  Pôvodná debata: [zdroje/next_sessions/V1_DEBATA_2026-09-06_VYSTUPY.md](../zdroje/next_sessions/V1_DEBATA_2026-09-06_VYSTUPY.md). Prepínač „na faktúru" je vyradený (existuje s DPH / bez DPH). **Mimo V1:** DOCX/PDF generátor ponuky a rodina dokumentov.
