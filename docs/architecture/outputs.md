# Výstupy — kontrola, kusovník, VEPO, nákup a rozpočet

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Kontrolný semafor a zdieľané čisté jadro výstupov zákazky. Kontrakt plánu, z ktorého všetky výstupy čítajú, žije v [model-a-identita.md](model-a-identita.md) (`build_plan.rb`,
`part_keys.rb`); UI sekcie Štúdia, ktoré tieto výstupy zobrazujú, sú v [ui-lifecycle.md](ui-lifecycle.md).

### validation.rb

**kontrolný semafor (V0.5-D):** RED = materiál mimo katalógu / hrúbkový drift / nezmestí sa na platňu (s rešpektom smeru dekoru) / ABS páska hrany mimo katalógu (2A-2 `abs_missing`
— len keď volajúci dodá ABS katalóg cez `edges:`) · ORANGE = čelo/voľná doska bez ABS „skontroluj" / vypnuté kovanie (owner_part_key identita) / build warnings / **`duplicate_identity`
(1b-3): dva top-level kusy toho istého druhu so ZHODNÝM ID** — kópia, ktorej ešte nikto nepridelil vlastnú identitu. Hlása ID, počet kusov aj výrobný dôsledok (záznamy oboch kusov
majú rovnaké `owner_id`, takže expanzia setov s `per: 'owner'` započíta položku LEN RAZ — do objednávky by šlo menej kovania). Vstup je `identities:` z `Bom.collect` (jeden záznam na
INŠTANCIU; `nil` = kontrola sa preskočí, vzor `placements:`), klik-adresa je zdieľaná s D-103 (`dup_kind` + `dup_owner_ids` → `pids_for_duplicate`). Dôsledok sa hovorí **podmienene**
(precedens `CAT_MATERIAL`): zliatie vlastníkov v kusovníku platí vždy, podpočítané kovanie len pri sete s členom účtovaným na vlastníka. **Nikdy sa nič neopravuje** — oprava patrí
zápisovej ceste (`fresh_collect` nižšie). Kritérium má **jeden zdroj**: verejná `Validation.duplicate_identities(identities)` → `[[kind, id, počet], …]`, z ktorej stavia nálezy
Kontroly **aj** varovanie statusu exportov, ktoré `Validation.run` nevolajú (odsek `production_core.rb`). JEDINÝ kanonický
zoznam; deterministický dedup + counts VÝHRADNE zo servera; sekcia KONTROLA v Štúdiu s klik-selectom cez stabilnú identitu a fallbackom na vlastníka; sekcia KONTROLA vo VEPO LOGu;
**RED nikdy neblokuje export** — semafor varuje, nezastavuje. *(Jedinou výnimkou v celom repe je finálny zápis súboru s cenou alebo objednávkou: `duplicate_identities` má od P0-HF
dva verejné pohľady — `duplicate_owner_ids` (len `KIND_CABINET`, teda kusy, ktoré kovanie vôbec MAJÚ) a `duplicate_plain_ids` (zvyšok, vždy len varovanie). Kandidáta na blokovanie
ešte preosieva `ProductionCore.dup_partition` cez skutočnú expanziu — detail v odseku `production_core.rb`. Kind-ová podmienka je tá istá, aká rozhoduje o znení nálezu
v `duplicate_id_item`, takže sa hláška a brána nemôžu rozísť.)*

**KOV-A1 — RED kategória `front_direction` (`CAT_FRONT_DIR`), jediný RED BEZ brány.** Vstupom je aditívny `collected[:hardware_issues]` z `Bom.collect` (`nil`/chýbajúci =
kontrola sa preskočí, vzor `placements:`); `check_hardware_issues` spracuje **výhradne** kód `front_direction_unset` — ostatné kódy (KOV-C/D: `drawer_no_fit`, owner bez
resolved setu…) sa zámerne ignorujú, aby sa do Kontroly nedostali skôr než ich vlastná brána. `stable_key` = `front_direction|owner_id|part_key`, takže klik-select po prestavbe
nájde čerstvú entitu a dve inštancie so zdieľaným ID dajú **jeden** riadok; `owner_pid` sa nesie ako **extra pole mimo kľúča** (vzor `extra:` v `record_item`). Text (znenie podľa
schváleného mockupu, scéna 4) menuje čelo serverovým `label`-om aj skrinku, hovorí, že smer = **strana pántov**, a otvorene priznáva, že export zatiaľ nezastaví.
**Brána je pre-committed v [SYSTEM/AUDIT_REGISTER.md](../../SYSTEM/AUDIT_REGISTER.md) R-39** a pristane až s prvým výstupom, ktorý smer reálne spotrebuje (D-95 výrobné zadanie);
dovtedy platia tvrdé podmienky O1 — žiadny default ani heuristika smeru nikde v kóde a legacy configy vyňaté (guard testy v `tests/pure/test_kova1_cela.rb`).
`FRONT_ROLES` sa rozšírilo o `flap` a `false_front`, takže ORANGE „čelo bez ABS" a hrúbkové pravidlo čiel platia aj pre výklop, sklop a blendu.

**KOV-H1 — dve nové kategórie** (GHOST-D1: `newer_config` už menuje **Skrinku aj Dosku**). **RED `newer_config` (`CAT_NEWER_CFG`)**, na rozdiel od `front_direction` **bránu MÁ**: číta aditívny `collected[:newer_configs]` a hovorí, že
nákupný CSV, rozpočet ani cenová ponuka sa nedajú vyexportovať a treba aktualizovať plugin. V Kontrole je preto, aby to bolo vidno **skôr**, než používateľ doladí rozpočet a naraz
mu export odmietne vzniknúť; `stable_key` = `newer_config|owner_id`, klik mieri na skrinku. **ORANGE `hardware_adhoc` (`CAT_HW_ADHOC`)** číta aditívny `collected[:hardware_manual]`
a má jediný nález — **mŕtvy vlastník** (`owner_missing`): ručná položka je pripnutá na dielec, ktorý už neexistuje. Text menuje položku, hovorí, že **ostáva v nákupe**, a ponúka dve
cesty (prepnúť na iný dielec / zmazať); `part_key` je zámerne `nil`, takže klik-select označí SKRINKU (dielec už niet). Obe kontroly sa pri chýbajúcom kľúči celé preskočia (vzor
`placements:`). Tretia zmena je v `check_hardware_expansion`: riadok s **`catalog_missing`** (ad-hoc kód, ktorý z katalógu zmizol) ide **existujúcou** ORANGE cestou `hardware_code`,
len s vetou, ktorá menuje ručnú položku a hovorí „ostáva bez ceny" — nie „bez názvu a ceny", lebo názov má zo snapshotu.

### production_core.rb — zdieľané čisté jadro výstupov zákazky (ŠT-1a PR A)

kusovník, súpisy platní/ABS a VEPO export sa sťahovali z okna Výroba do nového okna **Štúdio**; aby obe okná čítali **tie isté čísla**, čistí pomocníci prešli do jedného modulu
`Noxun::Engine::ProductionCore` (`module_function`).

**Od ŠT-1c PR B3, keď okno Výroba zaniklo, je jadro JEDINOU implementáciou** — Štúdio aj rail Inspectora ho volajú priamo.

Sú tam: **VEPO rodina** (`vepo_settings`/`save_vepo_settings` nad `%APPDATA%\NOXUN\Engine\vepo_settings.json`, `vepo_materials` s celou kaskádou rozlíšenia labelov,
`vepo_base_label`, `vepo_disambiguate`/`vepo_disambiguate_variants`, `vepo_group_key`, `vepo_edge_thicknesses`, od v0.9.22 aj `vepo_edge_decors`/`vepo_sheet_decors` pre poznámku
o odlišnej ABS — D-112, detail v odseku `vepo_export.rb`; `default_project_name`), **mapy katalógov** pre `Validation.run`
(`sheets_map` → `{}` pri chybe, `edges_map` → **`nil`** pri chybe, lebo prázdna mapa by falošne označila každú olepenú hranu), identita dokumentu `model_guid` a **výberové
resolvery** klik→entita (`pids_for_problem` vrátane fallbacku na vlastníka pri nepostavenom dielci, `pids_for_duplicate` pre D-103, `refs_for` — od ŠT-2d aj vetvy
`material_key`/`abs_key` s nepovinným `owner_id`, ktoré hľadajú dielce podľa **efektívneho materiálu z BOM** pre „Kde sa používa"; detail v odseku sekcie MATERIÁLY; **od ŠT-3b-2a
`pids_for_override`** — oko pri jantárovom riadku sekcie Pravidlá adresuje dvojicou **(owner_id, part_key)** a **znovupoužíva telo `pids_for_problem`** [prázdny kľúč = celý
korpus]; vetva `rule_ref` v `do_select` je vlastná zámerne — override v kusovníku vlastný riadok mať nemusí, napr. vypnuté kovanie; od ŠT-3b-2b beží **bez `fresh_collect`** — hľadá
podľa identity, takže plný sken modelu bol čistá réžia).

**KOV-A1 — `owner_pid` scopuje klik na JEDEN výskyt.** Keď nález nesie `owner_pid` (Integer) a `scoped_owner_instance` overí, že ide o **živú top-level skrinku s tým istým
`cabinet_id`**, `pids_for_problem` hľadá dielec `part_key` **len v nej** (`pids_in_cabinet`); inak beží dnešná všeobecná vetva. Bez toho by klik na RED „dvierka bez určeného
smeru" pri dvoch skrinkách so zdieľaným ID označil dvierka v OBOCH a `owner_pid` (audit #14 FIX 11) by nerobil nič. Overenie je **fail-open**: chýbajúci/nečíselný kľúč, zaniknutá
entita, iný druh alebo nezhodné `cabinet_id` → všeobecná vetva, takže scope smie výber len ZÚŽIŤ, nikdy ho nevyprázdni. `pids_for_override` `owner_pid` neposiela, takže sa nemení.

**ZÁVÄZNÝ kontrakt modulu: žiadny okenný stav** — `@dialog`, `@generation` ani `@pending_*` sem nepatria (dve okná nad jedným jadrom by si ich prepisovali); stráži to guard test,
ktorý v `production_core.rb` nepripustí ani jednu inštančnú premennú. Do ŠT-1c PR B3 si `ProductionDialog` ponechával **tenké obaly s pôvodnými menami, signatúrami AJ
privátnosťou** (aby bol refactor bez zmeny správania); s oknom zanikli a volajúci — panel, pure testy aj in-SketchUp runner — idú na jadro priamo. Loader (`main.rb`) načítava jadro
**PRED** oknom Štúdio, ktoré ho volá.

**PR B dávky ŠT-1a sem doplnil aj TELÁ akcií** — `fresh_collect`, `hardware_expansion`, `control_suffix` a hlavne `do_export`/`do_select`: obe okná robia presne to isté, len s
vlastným stavom, takže okno odovzdáva svoj kontext **explicitne** (`generation:` — token guardu B4 · `status:` — lambda do TOHO okna · `repush:` — „obnov, ak žiješ"). Dva takmer
rovnaké exporty by sa časom rozišli a rozdiel by sa ukázal až na výrobnom výstupe.

**`fresh_collect` JE ČISTÉ ČÍTANIE (1b-3, brána G bloku 1b) — telo je `Bom.collect(model)` a nič viac.** Z tejto cesty sa **nesmie** zapísať do modelu, otvoriť operácia ani
pribudnúť krok Späť; platí to pre „Obnoviť", `push_state`, klik-select aj všetky štyri exporty. Stráži to guard test `tests/pure/test_1b3_citanie.rb`, ktorý v **celej UI vrstve**
nepripustí volanie `dedup_copies` (formulácia nad priečinkom, nie nad zoznamom mien metód). *Do 1b-3 tu bežal dedup tik — vznikol 19.7.2026 (GH #48 P2) ako zrkadlo vtedajšieho
`Panel.push_selected`, ktorý dedup tiež vykonával priamo; ten sa toho 9.8. vzdal (D-103) a od vtedy opravu len ŽIADA u observera, kým čítacia cesta si ju držala ďalej. Obyčajné
„Obnoviť" tak potichu prečíslovalo ID kópií a pridalo krok Späť.* **Oprava identity žije výhradne v ZÁPISOVEJ ceste:** dedup tik `ScaleWatch` po kopírovaní (transparentný ku kroku
používateľa) a `Panel.push_selected` po zápise z panela (`ScaleWatch.request_dedup`). Kým oprava nedobehne, duplicitnú identitu **prizná Kontrola** (`duplicate_identity`, ORANGE). Guard preto zakazuje v tomto module
**aj token `request_dedup`** (oneskorená oprava je stále oprava) a pripúšťa `Panel.push_selected` výhradne s `dedup: false`; to isté platí pre `studio_dialog.rb`.

**Nález v Kontrole však NESTAČÍ (review #240 P2-1):** kto klikne „Nákupný zoznam kovania", sa do Kontroly nepozerá — a práve to CSV ide dodávateľovi. Exporty, ktoré `Validation.run`
nevolajú, preto skladajú vlastné varovanie: **`dup_id_suffix(collected)`** (strop tri ID + „a ďalšie N", vzor `control_suffix`) ide do statusu `do_hw_csv` a `do_budget_xlsx`
a **zároveň farbí status na varovanie**. **Cenová ponuka sufix NEMÁ** — má vlastný zoznam dôvodov `cp_warnings` (GH #139: jeden zoznam, ktorý riadi aj farbu), takže duplicita ide do
neho; jeho posledný parameter `collected` je nepovinný (legacy volanie nič nemení). **VEPO sufix nemá tiež** — `Validation.run` volá, takže nález už nesie `control_suffix` aj sekcia
KONTROLA vo VEPO LOGu.

**FINÁLNA BRÁNA PRED ZÁPISOM SÚBORU (P0-HF, externý Codex audit 29.8.2026).** Spoločný koreň oboch P0 nálezov bol jeden: **systém poznal chybný finálny výstup a napriek tomu ho
uložil.** Rozpočet aj cenová ponuka sa zapísali na disk a AŽ POTOM sa vyhodnotilo, že riadky nemajú cenu, že „Nábytková zostava" vyšla záporná alebo že suma nesedí s rozpočtom;
nákupný CSV rovnako vznikol aj nad zliatymi vlastníkmi kovania. Súbor, ktorý už existuje, sa dá odoslať dodávateľovi aj zákazníkovi — červený status pod ním prišiel neskoro. Brána
sa volá **pred `savepanel`** (picker sa pri chybe ani neotvorí) a má **dve vetvy**, ktorých rozdiel je záväzný:

*(1) TVRDÁ — `export_blockers(dups:, cp:, newer:, drawer:)`.* Stavy, ktoré sú VŽDY chyba a **nedajú sa potvrdiť**: duplicitné ID **skrinky** (`dups:` — CSV kovania, rozpočet, ponuka),
záporná „Nábytková zostava" a nesúlad ponuky s rozpočtom (`cp:` — len ponuka) a **zákazka z NOVŠEJ verzie pluginu** (`newer:` — CSV kovania, rozpočet, ponuka). Nedáva zmysel poslať
dodávateľovi objednávku, o ktorej vieme, že je podpočítaná. Hláška `export_blocked_status` musí povedať **oboje**: že súbor NEVZNIKOL (inak ho používateľ ide hľadať na disk)
a **prečo + kde to opraviť**. Zoznamy ID majú **jedno znenie stropu** („tri ID + a ďalšie N") — `ids_text`, ktoré používa aj `dup_ids_text`.

**`newer:` je KOV-H1 hardening R-12 (audit #15 BLOCKER 3), a platí VŠEOBECNE** — aj pre zákazku bez ad-hoc kovania. R-12 dovtedy chránil len **prestavbu**: staršia verzia pluginu
zákazku so schémou vyššou než vlastná normálne **vyexportovala**, len bez toho, čomu nerozumie (pole configu je pre ňu neviditeľné), takže objednávka aj cena boli neúplné a nikto to
nemal ako zbadať. Zdrojom je aditívny `Bom.collect` kľúč **`newer_configs`** (`ProductionCore.newer_configs(collected)`). Potvrdiť sa to nedá: chýbajúce dáta sa nedajú „vziať na
vedomie", dá sa len aktualizovať plugin. **GHOST-D1 zmena: VEPO už výnimku NEMÁ.** Odkedy má aj **doska** vlastný kontrakt configu (`BoardBuilder::BOARD_CONFIG_SCHEMA`), môže
objekt z novšej verzie niesť **výrobné** pole, ktoré tento plugin nevidí — takže rezací výstup by bol ticho neúplný rovnako ako nákup. `do_export` (VEPO) preto volá
`newer_config_stop` **hneď po `fresh_collect` a pred `UI.select_directory`** (pri blokáde sa picker ani neotvorí). Že sú to práve **štyri** výstupy, stráži guard test
v `tests/pure/test_kovh1_adhoc.rb`.

**Táto brána sa vyhodnocuje HNEĎ po `fresh_collect`** — cez `newer_config_stop(collected)`, teda **pred expanziou, pred rozpočtom aj pred ich skorými návratmi** (review #283
P2-B). Dôvod: zákazka z novšej verzie nemusí vyexpandovať ani jeden **známy** nákupný riadok (alebo jej rozpočet vôbec nevznikne), takže skorý návrat „model nemá žiadne
kovanie" / „rozpočet sa nepodarilo zostaviť" by bránu **predbehol** a používateľ by sa nedozvedel ani ID skriniek, ani to, že má aktualizovať plugin. `newer:` preto do
**neskorého** `export_blockers` (spolu s `dups:`/`cp:`) už nechodí — skladá ho výhradne `newer_config_stop`, jedno miesto pre všetky štyri exporty.

**KOV-C2b (v0.9.31) — BRÁNA ZÁSUVIEK (`drawer:`).** Register `Recipes::DRAWER_BLOCKERS` (10 kódov) má dve polovice a každá blokuje **iné** výstupy:
**`BUILD_BLOCKERS` (9)** = fail-closed konflikty STAVBY — zásuvka nevydala ani dielec ani položku výsuvu, takže objednávka aj rozpočet by boli neúplné → nákupný CSV,
rozpočet, cenová ponuka. VEPO bránu **nepotrebuje**: chrániť netreba to, čo sa vôbec nevydalo. **`drawer_kit_missing` (1)** vzniká až v NÁKUPE (receptová položka bez setu
alebo bez kódu pre svoju NL) — dielce v modeli **ostávajú** (fyzika je správna), ale sú rezané na konkrétnu NL (BL = NL + 10, boky Quadro = NL), takže bez kitu tej NL sú
odpad → blokuje **VŠETKY štyri exporty VRÁTANE VEPO**.

Skladá to `drawer_blockers(collected, expansion, scope:)`: `scope: :all` číta konflikty stavby z aditívneho zberu `hardware_issues` (uložený nosič `drawer_conflicts`,
nižšie) **aj** kit z expanzie, `scope: :kit` iba kit. Poradie dôvodov určuje register (deterministicky, bez ohľadu na poradie zberu) a text stavia
`Recipes::BLOCKER_LABELS` + `ids_text` (ten istý strop „tri ID + a ďalšie N"). Hotovú hlášku vydáva **`drawer_stop`**, ktorý beží — rovnako ako `newer_config_stop` —
**pred pickerom**; VEPO si preto expanziu kovania počíta **hneď po zbere** a nižšie ju už len použije (žiadny druhý prepočet). Keď expanziu nemáme (chyba katalógu/setov)
a zákazka **má** aspoň jednu receptovú položku, brána je **fail-closed** (`drawer_expansion_unproven?`) — nedokázateľný stav zastavujeme, rovnako ako neznámu expanziu duplicít.

**Uložený nosič `drawer_conflicts` (Astra #19 F6).** Po fail-closed stavbe v modeli nezostane ani dielec ani položka, z ktorej by sa dôvod dal obnoviť — musí teda prežiť
v **configu**: `Construction.build_plan` ho vydá v `plan[:drawer_conflicts]` (tvar `{front_id, code, message, part_key}`, validuje `BuildPlan.validate_drawer_conflicts!`),
`CabinetBuilder.merge_final` ho uloží vedľa `warnings`/`hardware`, `Bom.drawer_conflict_issues` ho zlúči do `hardware_issues` a `Validation.check_hardware_issues` z neho
robí RED kategóriu **`drawer`**. Prežije tak save/reopen aj Undo. Neznámy kód (config z novšej verzie) sa **preskočí** — o takú zákazku sa stará brána `newer_configs`.
RED kategória **`drawer_kit`** vzniká paralelne z expanzie (`drawer_kit_item`) a veta menuje čelo, systém, výšku, NL aj dôvod.

*(2) POTVRDITEĽNÁ — `export_confirmations(budget:)`.* Dnes jediný dôvod: **riadky bez ceny**. STANDARD §11.3 hovorí, že neznáma cena sa NIKDY nenahradí nulou, ale má sa **priznať**
(„medzisúčet je len zo známych cien a súhrn nahlas povie, že nie je úplný") — **rozpracovaný rozpočet je legitímny stav zákazky** a plošný tvrdý blok by používateľovi bral výstup,
na ktorý má právo (nález Codex review PR #250 proti auditu). Default je teda zastavené, ale **cesta von existuje**: `export_confirm_status` ponúkne druhý klik, ten pošle
`confirm_unpriced` a hotový súbor podhodnotenie **prizná v statuse** (`export_confirmed_notes`; status ostáva červený). **Potvrdenie overuje SERVER** (`export_confirmed?`), takže
starý DOM ani cudzí volajúci nemajú ako podhodnotený súbor vyrobiť ticho; klient (`budNeedsConfirm` v `js/budget.js`, dva nezávislé kľúče pre rozpočet a ponuku) je len UX a jeho
ozbrojenie **ruší každý čerstvý payload** (`NX.setStudio` → `budDisarm`).

**`confirm_unpriced` je POČET, nie boolean (review #252 P1)** — a to je celý bod. Export medzi prvým a druhým klikom **flushne rozpísaný edit Inspectora a rozpočet prepočíta
z čerstvého modelu**, takže neviazaný `true` by autorizoval **iný, možno horšie podhodnotený dokument** a rozdiel by sa priznal až v statuse pod hotovým súborom — presne to, čo
P0-HF ruší. Server preto prijme len **presnú zhodu** s vlastným čerstvým `unpriced_count` (`true`, reťazec ani nula potvrdením nie sú). Keď sa čísla rozídu, export sa zastaví
a **okno sa OBNOVÍ** (`stop_for_confirmation` → `repush`): bez toho by opačný nesúlad — cachovaný payload tvrdí „0 bez ceny", čerstvý rozpočet ich má — potvrdenie nikdy neozbrojil
a export by sa zasekol navždy. Obnova zároveň potvrdenie odzbrojí, takže ďalší klik varuje už správnym číslom. Čistý export si obnovu nepýta (žiadna réžia navyše).

**Je to VEDOMÉ PREVRÁTENIE rozhodnutia dávky 1b-3** („export dobehne + červený status"), ktoré charakterizoval `tests/pure/test_1b3_citanie.rb`. Rozdiel je v predmete: 1b-3 riešila
**nález Kontroly** (varovanie o modeli), táto brána **číslo v hotovom platnom dokumente**. Semafor sa nemení — **KONTROLA naďalej len varuje a nikdy neblokuje** (RED nezastaví ani
VEPO); výnimka platí VÝHRADNE pre finálny zápis súboru s cenou alebo objednávkou. **VEPO bránu nedostáva** (audit ho výslovne vyníma): je to rezací výstup, nie cena ani objednávka,
duplicitná identita jeho čísla neskresľuje a chybné riadky vyhadzuje sám do LOGu — blokovať ho bez samostatného dôkazu by len zastavilo výrobu. **Firewall interných pojmov bránou
tiež nie je** (STANDARD §11.3: hlási a neblokuje) a počíta sa až nad hotovým hárkom.

**Zastaviť smie LEN SKUTOČNÁ kolízia — `dup_partition` (review #252 P2).** Objednávku podpočíta výhradne dedup člena `per: 'owner'` (`HardwareSets.expand_members`), takže blokovať
sa smie len duplicitné ID **skrinky, ktorej sety taký člen naozaj pridelili**. Doska kovanie nemá a skrinka so samými `per: 'unit'` členmi (klasický záves) sa spočíta správne aj
pri zdieľanom ID — zastaviť ich export by znamenalo brať používateľovi platný výstup. Dôsledok je teda **podmienený presne tak, ako ho popisuje odsek `validation.rb` vyššie**.
`dup_partition(collected, expansion)` vracia dvojicu **[blokujúce, varovacie]**: prvá polovica ide do `export_blockers`, druhá (dosky **aj** skrinky bez owner člena) do
`dup_id_suffix` / `cp_warnings` — kusovník ich zlieva do jedného vlastníka, takže sa priznajú, ale súbor nezastavia a **nikdy nedostanú vetu o kovaní** (do 29.8. sa `kind`
zahadzoval a veta sa tvrdila aj nad doskou — seed A7 sweepu). **Neznáma expanzia blokuje**: kolíziu nemožno ani dokázať, ani vyvrátiť, a pri objednávke je bezpečnejšie zastaviť.
Podklad nesie expanzia sama — zdroj riadku nesie príznak **`per_owner`** (aditívny kľúč, zapisuje sa len keď je pravdivý, jediný čitateľ je táto brána). **Od 1d/R-34 značí
`expand_members` až vetvu REÁLNEHO preskoku**, nie každý vydaný owner člen: dve inštancie so zdieľaným `cabinet_id`, ale rôznym `owner_part_key` sa nezlievajú, množstvá majú
správne a **export im prejde** (ORANGE nález Kontroly ostáva). So zhodným vlastníkom je to skutočná kolízia a blok platí ako doteraz — detail a priznaný zvyšok v odseku
`hardware_sets.rb` ([hardware.md](hardware.md)). **DRUHÁ blokujúca cesta — rozídené set overridy (review #262 P1):** `cabinet_sets` má na ID **jeden slot**, takže pri zdieľanom
`cabinet_id` posledná inštancia prepíše prvú a `resolve_set_id` použije tú jednu mapu na **obe** (kľúčom je `owner_id`) — vtedy sú neisté rovno **KÓDY**, nie len počty, a to sa
nedá ani dokázať, ani vyvrátiť. Také ID hlási zber v aditívnom kľúči **`cabinet_set_conflicts`** (`Bom.note_cabinet_sets`) a brána ich pridá k blokujúcim aj bez zliatia owner
člena; **zhodné (alebo nijaké) mapy konflikt nie sú** — bežná kópia skrinky dá rovnaký výsledok nech vyhrá ktorákoľvek. **Blokuje sa len rozdiel, ktorý tej skrinke naozaj mení
kód (review #262 P2):** záznam nesie KĽÚČE rozdielu a `conflict_matters?` ich porovná s kľúčmi, ktorými si skrinka kovanie skutočne mapuje — `override_keys_in_use` ich číta
z `collected[:hardware]` **presne tak, ako ich číta `resolve_mapping_value`**. Do KOV-C2a to boli `generic_type` a `generic_type@owner_part_key`; odvtedy platí vetvenie:
**klasifikovaná (receptová) položka registruje VÝHRADNE triedny kľúč `class:slide|…`** (`HardwareSets.class_key_for`), legacy položka naďalej dvojicu legacy kľúčov. Obe
strany sú nutné: bez triedneho kľúča by sa rozídená override mapa prepašovala ako „neškodná" a duplicitné ID skriniek by objednalo iný kit, než ktorý sa postavil
(Astra #19 F8); a naopak — zapísať receptovej položke aj `slide`/`slide@owner`, ktoré pre ňu resolver ignoruje, by znamenalo blokovať export kvôli rozdielu, ktorý jej kód
nijako nemení (Codex #303 P2). Rozídený `slide` na skrinke, ktorá má len závesy, teda neblokuje;
**neznámy rozdiel (prázdny zoznam kľúčov) blokuje** — rovnaká logika ako pri neznámej expanzii. Kľúč je aditívny: starší zber bez neho sa správa ako predtým. Blokujúca hláška
menuje **oba** dôsledky (TipOn započítaný raz · set podľa druhej skrinky). **Priznaný zvyšok:** či sa override rovná projektovej predvoľbe, brána nevie — mapovanie projektu
nie je súčasťou zberu a druhý výklad precedencie (`HardwareSets.resolve_set_id` je jediná autorita) by bol presne ten druhý verdikt o tej istej veci, ktorému sa tu vyhýbame.
Tvrdé dôvody **vypadli z `cp_warnings`** — jeden dôvod žije v jednom zozname, dva zoznamy o tej istej veci by sa časom rozišli; `cp_warnings(hits, dups, confirmed)` drží už len
firewall, neblokujúce duplicity a **potvrdené** riadky bez ceny. Kontrakt strážia `tests/pure/test_p0hf_brany.rb` (pri každom dôvode sa meria **prázdny priečinok**, nie text
statusu), `tests/pure/test_hardware_sets.rb` (príznak `per_owner`) a `tests/js/test_p0hf_potvrdenie.js` (dvojkrokový klik).
`do_select` navyše pozná príznak **`focus_inspector`** (ceruzka riadku Kusovníka, Š3): po výbere zdvihne Inspector cez `Panel.bring_to_front` — **nikdy ho neotvára**, výber sa tým
nemení a do modelu sa nezapisuje nič.

**`project_names` (ŠT-1a, audit #1):** názov projektu je od tejto dávky **serverový údaj** — mapa v `vepo_settings.json` (nastavenie POČÍTAČA, žiadny zápis do modelu, žiadny krok
Späť).

**Kľúčom je NORMALIZOVANÁ CESTA súboru, nie `model.guid`** — SketchUp guid **mení po každom uložení** modelu, takže na guid kľúči by sa názov po Ctrl+S ticho stratil a v súbore by
rástli mŕtve záznamy (nález review P1). Normalizácia je `\`→`/` + `downcase` (Windows nerozlišuje ani veľkosť písmen, ani smer lomítka).

**Neuložený model cestu nemá** a dostane náhradný kľúč `guid:<guid>`, ktorý platí len v rámci sedenia; čítanie naň padá ako na záložku (pomenoval som Untitled a potom ho uložil) a
**prvý zápis s platnou cestou ho zmigruje** — záznam sadne na cestu a guid kľúč sa zmaže.

**Ctrl+S ale mení cestu AJ guid NARAZ (1b-6a):** po prvom uložení sa záznam pod *starým* guid kľúčom z modelu už nedá nájsť — záložka hľadala `guid:<nový guid>` a našla prázdno,
takže názov zadaný pred prvým uložením sa ticho stratil a všetky štyri exporty sa pomenovali podľa `.skp` súboru namiesto zákazky (výrobná P2). Most drží **pamäť procesu**
`SESSION_KEY_BRIDGE` (`object_id` modelu → posledný kľúč sedenia, pod ktorým sa názov zapísal), overená **identitou objektu** (`equal?`, čisté porovnanie referencií).

> **`equal?` samo o sebe NESTAČÍ (1d/R-02b, review delty #267 P2-GLM).** Pôvodné zdôvodnenie „cudzí dokument názov zdediť nemôže, Windows pri File > New/Open model zničí
> a vytvorí nový" je **nepravdivé** — Windows drží jeden dokument na proces a `Sketchup::Model` objekt smie **recyklovať** (auditované pri GHOST vkladaní, review #268 P2-2).
> Na recyklovanom objekte vráti `equal?` true aj pre práve založený cudzí dokument, takže nový Untitled zdedil kľúč sedenia — a s ním **názov zákazky** predošlého dokumentu,
> ktorý by ticho odišiel do VEPO/CSV/XLSX. Most preto zahadzuje **`Engine.on_document_replaced`** (volajú ho oba AppObservery z `onNewModel`/`onOpenModel`, nikdy
> z `onActivateModel`, nikdy pri uložení) ešte **pred** notifikáciou okien; `equal?` tu ostáva ako druhá poistka proti recyklácii `object_id` po GC. Je to **ten istý koreň**
> ako pri identite dokumentu (`DocKey`), preto majú obe pamäte **jeden spoločný zoznam cleanupov** — každá ďalšia pamäť viazaná na objekt modelu doň musí pribudnúť.

Prvé čítanie po uložení záznam **adoptuje a hneď zmigruje na cestu**
(`adopt_session_name`) a most sa spotrebuje; **bez migrácie** by názov žil len do konca sedenia a po reštarte by sa stratil aj tak. Kľúče sedenia sa spotrebujú pri prvom čítaní s
platnou cestou **vždy** — aj keď cesta už svoj názov má: ten **má prednosť** a rozpísaný názov ho neprepíše, ale musí zaniknúť, inak by sa o pár minút vynoril pri „Uložiť ako" na
čerstvej ceste (review #243 P2-2). Most sa zahadzuje **až po úspešnom zápise** — `save_vepo_settings` vracia `true`/`false` a pri zamknutom súbore či plnom disku ostáva most nažive,
takže sa migrácia zopakuje hneď, ako zápis prejde (review #243 P2-1). Zápisová cesta upratuje to isté
(`save_project_name` maže VŠETKY kľúče sedenia zákazky, nielen ten podľa aktuálneho guid). Most **nie je zakázaný okenný stav**: nie je to stav okna ani medzivýsledok výpočtu, ale
údaj o dokumente, ktorý sa z modelu po uložení prečítať nedá — obe okná z neho čítajú to isté a nemajú si ho ako prepísať; je to konštanta (nie `@ivar`) aj kvôli guard testu, ktorý
tu inštančné premenné nepripúšťa, a je zhora ohraničená (`SESSION_BRIDGE_MAX`). Prázdna hodnota **aj hodnota zhodná s defaultom zmaže záznam**, takže sa pomenovanie vráti
na názov `.skp` a premenovanie súboru sa v okne prejaví samo. Číta ho **všetky štyri exporty** (VEPO, CSV kovania, XLSX rozpočtu, XLSX cenovej ponuky) — z DOM sa `project`
**prestal posielať**, inak by dve okná mali dve pravdy a tá istá zákazka by sa v dvoch výstupoch volala inak. `merge_18_36` ostáva globálny a číta sa rovnakou cestou.

**Zápis `vepo_settings.json` má JEDNY dvere (1b-6c):** súbor je nastavenie POČÍTAČA so **šiestimi zapisovateľmi** — `save_merge_18_36`, štyri zápisy `last_dir` (VEPO, CSV kovania,
XLSX rozpočtu, XLSX cenovej ponuky) a mapa `project_names` — a menil sa read-modify-write **bez medziprocesového zámku**. Dve inštancie SketchUpu zdieľajú jeden `%APPDATA%`, takže
zápis jednej vedel zmazať zákazku pomenovanú v druhej; `JsonFileStore` rieši **atomicitu** (tmp+rename, `.bak`), **nie súbeh** — a jeho sekundová cache navyše skryje čerstvý zápis
suseda. Každý zápis preto ide cez **`update_vepo_settings`**: `Materials.with_catalog_lock` (jeden sidecar `.lock` nad tým istým priečinkom, reentrantný — detail v
[materials.md](materials.md)) + čítanie súboru **nanovo vnútri zámku** (`JsonFileStore.reload!`); blok dostane čerstvé nastavenia a vráti hash na zlúčenie, `nil` = netreba
zapisovať. **Čítania sa nezamykajú** (hot push panela by zámok platil zbytočne), ale **štyri exporty si na začiatku vypýtajú čerstvý súbor** (`refresh_vepo_settings`) — hotový
CSV/XLSX sa už ďalším čítaním nezahojí. Zámok sa cez export **zámerne nedrží**: cesta otvára modálny `savepanel` a druhá inštancia by čakala, kým používateľ klikne.

**Štyri pravidlá tých dverí, každé zaplatené nálezom auditu:** *(1)* zápisová cesta číta **strikto** (`vepo_settings_for_write`) — lenivé `{}` z neprečítateľného súboru by sa
zlúčilo s novými `attrs` a zmazalo `project_names`, `merge_18_36` aj `last_dir`; chýbajúci súbor je legitímne prázdno, existujúci a nečitateľný (alebo nie-Hash) **zastaví zápis**.
*(2)* Celá zamknutá úprava je v `rescue` — aj zlyhanie `.lock` je len zalogovaný `false` (kontext logu nesie **fázu** lock/read/block/write), nikdy výnimka do okna či exportu.
*(3)* Mapu názvov cez `save_vepo_settings` **zapísať nejde** (odovzdaný odtlačok by čerstvú mapu prepísal celú) — na to je `update_project_names`, ktoré blok kŕmi čerstvou mapou;
stráži to guard test. *(4)* Názov sa počíta **aj pred zámkom**: keď sa `.lock` nedá vziať, blok pod ním nikdy nebeží, a bez tohto fallbacku by všetky štyri exporty dostali meno
`.skp` súboru namiesto zákazky. Keď blok **bežal**, `project_name` vracia **čerstvú** hodnotu spod zámku (`effective_project_name` nad čerstvou mapou) — inak by sa export
pomenoval podľa `.skp` napriek tomu, že súbor už drží správny názov (review #243, kolo 3).

**`materials_meta`/`edges_meta` (audit #4)** sú kontrakt skupín Kusovníka: per `material_id` (resp. `abs_id`) label, katalógová farba ako **pole `[r,g,b]`** (nie CSS reťazec —
prevod robí klient, ktorý farbu kreslí), hrúbka a príznak UNI; materiál mimo katalógu sa pomenuje **svojím ID** a farbu nedostane (radšej žiadna vzorka než náhodná).

**Menovka skupiny musí byť JEDNOZNAČNÁ (1b-6b, triáž #33):** `material_label` je len ľudský názov dekoru (číslo + štruktúra + názov), takže dva **rôzne výrobné materiály** —
iný výrobca, typ, formát platne alebo rub zásteny — z neho dostali identickú hlavičku, a práve podľa nej sa v Štúdiu objednáva. Menovky preto skladá `material_labels`
(resp. `edge_labels` pre pásky) **kolíznym pásom**: bez kolízie je výsledok bajtovo dnešný text (bežná zákazka žiadny šum navyše nedostane), pri kolízii sa eskaluje na
**panelovú menovku** — `Panel.raw_row_label` (výrobca pri kolízii cez `label_base` + prípona formátu/rubu `Materials.sheet_label_suffix`) → `Panel.sheet_label` (navyše typ
a hrúbka: ten istý dekor v DTDL aj kompakte) → poistka `[material_id]` (vzor VEPO: dve hlavičky sa nesmú zliať ani nad nezmyselným katalógom); pásky eskalujú na
`Panel.abs_label` (štruktúra + výrobca pri kolízii). **Žiadna vlastná logika menoviek vo výstupoch** — panel a výstupy nesmú mať dve pravdy o tom, ako sa materiál volá.
**Kolízny kľúč je to, čo riadok skupiny UKÁŽE: menovka + hrúbka** (hrúbka má v hlavičke aj v súpise Platní vlastné miesto), takže dve hrúbky toho istého dekoru — najbežnejší
prípad zákazky — rozlíšenie nedostanú. Kontext kolízie výrobcov (`Panel.label_ctx`) sa stavia **až pri prvej kolízii** (sentinel `:panel`), takže nekolízna zákazka kvôli
hlavičkám katalóg nečíta vôbec; jeho zlyhanie sa len zaloguje a menovky ostanú dnešné. Stráži to `tests/pure/test_1b6b_hlavicky.rb`. *Rozpočet a cenová ponuka majú vlastné
menovky (`Budget.sheet_label`, `CpExport.material_label`) — sú v `core/`, kam panelový aparát nedosiahne, a ostávajú kandidátom pre audit 1c.*

**`rows_with_roles`** dopĺňa voliteľný stĺpec „Rola" **read-only obohatením** — záznamy sa zoskupia TÝM ISTÝM `Bom.row_key`, akým vznikli riadky, pretože pridať rolu do kľúča
agregácie by zmenilo kusovník **aj VEPO** (a párovanie beží cez Ruby hash: kľúč riadku je POLE, v JSON by sa už nespárovalo). SK názvy rolí sú `ROLE_LABELS` — jedna autorita, JS
žiadny preklad enumu nemá (`part_card.js` má vlastnú mapu len ako fallback popisu karty a musí s ňou byť zhodný).
**KOV-A1:** rola **`flap` je spoločná pre výklop AJ sklop**, preto je jej názov neutrálny **„Výklop/sklop"** — „Výklop" by pri každom sklope klamal v stĺpci Rola kusovníka,
v karte dielca aj v prehľade ABS pravidiel. Konkrétny text vie povedať len TYP čela, nie rola: server ho skladá v `PartKeys.flap_label` (rovnaký neutrálny tvar bez zhody)
a od KOV-A2 aj karta čela. `false_front` = „Blenda" (blenda je jednoznačná).
**KOV-C2a:** pribudli názvy štyroch rolí dielcov zásuviek — **„Dno zásuvky" · „Chrbát zásuvky" · „Bok boxu" · „Vnútorné čelo zásuvky"**. **Od KOV-C2b ich plán emituje**,
takže tie isté názvy nesie kusovník aj VEPO; `PartKeys.human_label` k nim pridáva číslo čela („F2 · dno zásuvky", pri boku aj stranu).
**Nové ORANGE dôvody nemapovaného kovania** (`Validation.check_hardware_expansion`): **`class_unmapped`** = zásuvka nemá predvolený set pre svoje otváranie a konštrukciu (veta
navádza na existujúcu akciu „Pravidlá → Doplniť nové predvoľby"; na generický `slide` sa NIKDY nepadá) a **`set_incompatible`** = vybraný set klasifikáciou položke nesedí
(iný systém · iná výška · iné otváranie/konštrukcia · override skrinky nie je výškový selektor — dôvod pomenúva `HardwareSets.incompatible_detail_sk`). Povýšenie oboch na RED
`drawer_kit_missing` (a s ňou bránu exportov) priniesla C2b — pre položku so `source: 'recipe'` sa **každý** dôvod povyšuje na RED, pôvodný cestuje v `base_reason`.

**ŠT-1b sem pridala celý zvyšok KONTROLY: `control_payload`** (Validation.run nad čerstvým zberom **+ zlúčenie s upozorneniami rozpočtu cez `Validation.with_budget`**) je **jediné
miesto, kde vzniká číslo semaforu** — číta ho sekcia Kontrola v Štúdiu, badge navigácie **aj `do_export`** (status aj sekcia KONTROLA vo VEPO LOGu; do review #1 mal export vlastný
`Validation.run` **bez** rozpočtových nálezov a hlásil preto iné číslo než semafor), takže žiadne z týchto miest nemôže ukázať vlastné číslo; s ním sem prešli aj `budget_payload` a
`hardware_catalog_items` (rozpočet sa počíta kvôli svojim ORANGE nálezom, hotový odhad platní sa mu odovzdáva, aby nevznikol druhý výpočet).

**`replace_uni`** (skratka „Nahradiť UNI…" → `MaterialsDialog.request_replace_uni`) a **zdieľané telá prepínačov** `edge_check_guard` (dostupnosť Overlay API + `identity_guard`) ·
`identity_guard` (generácia okna + dokument — zdieľa ho aj kresba, ktorá si dostupnosť overuje **vlastnú** a hlási ju vetou o kresbe, nie o hranách) · `do_edge_check` ·
`do_edge_check_option` · `do_grain_check` + texty statusov (`edge_check_status`, `EDGE_OPTION_LABELS`/`edge_check_option_status`, `grain_check_status`, `grain_part_plural`). Okno
odovzdáva svoj stav **explicitne** — okrem `generation:`/`status:`/`repush:` aj **`echo:`** (malý push stavu prepínača do TOHO okna) a pri kresbe `grain_echo:`; guard tak nemá
**žiadny okenný stav** a obe okná sú nad ním len obaly.

Názvy stavov majú **jediný zdroj** `ProductionCore::EDGE_OPTION_LABELS` — rail Inspectora aj `js/edge_menu.js` ich čítajú odtiaľ (do ŠT-1c PR B3 sa rail pýtal cez tenký obal okna
Výroba).

**ŠT-1c PR A sem pridala dve veci zo zaniknutého tabu Kovanie:** `hardware_labeled` (generika kovania obohatená o SERVEROVÉ texty `label` — `HardwareRules.label_for` — a
`params_label` — „rez 597 mm", D-90; obohatenie zmizlo z `push_state` okna Výroba, aby dva klienty nemohli mať dve pravdy o tom, ako sa položka volá) a **telo `do_hw_csv`**
(nákupný CSV zoznam; rovnaký tvar ako `do_export` — `generation:`/`status:`/`repush:` — takže okno je nad ním len obal).

**VEDOMÁ ZMENA (audit #15):** CSV kovania dostalo **generačný guard**, ktorý predtým nemalo — je to nákupný dokument a nesmie vzniknúť z okna so zastaranými dátami (ostatné tri
exporty ho majú odjakživa); odmietnutie nie je tiché, okno sa obnoví a povie to.

**ŠT-1c PR B1 sem presunula CELÝ ROZPOČET — a s ním JEDINÚ cestu, ktorá zapisuje do modelu:** `do_budget` (12 operácií cez `apply_budget_op` → `BudgetStore`, jedna mutácia =
**jeden krok Späť**), oba XLSX exporty (`do_budget_xlsx`, `do_cp_xlsx` + `cp_warnings`/`cp_status`/`fmt_eur`), `budget_open_url` (adresa sa **dohľadáva v modeli** podľa ID položky
a znova sanitizuje — z klienta nechodí), `open_budget_settings` a celý beh **prepočtu cien** (`do_price_refresh` + `price_refresh_reject`/`_emit`/`_targets`/`_cancel`/`_status`).

Tvar odovzdania stavu je ten istý ako všade inde, len bohatší: okrem `generation:`/`status:`/`repush:` aj **`result:`** (echo `NX.budgetResult(op, ok)` **PRED** čerstvým payloadom
— odmietnutý zápis nesmie zavrieť rozpísaný draft, GH #138 P2) a pri prepočte cien **`emit:`** (fázové okno), **`alive:`** (beh visí na TEJ ISTEJ inštancii okna) a **`after:`**
(refresh ciest po dobehnutí — ceny sa menia globálne, takže čerstvé čísla dostanú katalóg materiálov, panel aj katalóg kovania; piaty prijímateľ — okno Výroba, ktoré potrebovalo
čerstvé `counts` pre svoj ⚠ chip — zanikol s oknom v ŠT-1c PR B3). Guard mutácie je zámerne **tolerantný na prázdny `model_guid`** (starší cachovaný DOM), ale nezhodné ID odmieta.

Kontrakt stráži `tests/pure/test_st1a_core.rb`, `tests/pure/test_st1a_studio.rb`, `tests/pure/test_st1b_kontrola.rb`, `tests/pure/test_st1c_nakup.rb` a
`tests/pure/test_st1c_rozpocet.rb`.

**Brány pred zápisom cenového súboru (P0-HF + 1d/R-14).** Oba XLSX exporty (`do_budget_xlsx`, `do_cp_xlsx`) majú pred `UI.savepanel` tri vrstvy v tomto poradí:
**(1) kompatibilita dát** — `budget_std_block(budget)` číta VÝHRADNE príznak `budget['budget_std']` z payloadu (nikdy sa nepýta modelu druhýkrát: hárok musí stáť na tých istých dátach, z akých vznikli jeho čísla) a pri novšom/poškodenom markeri export zastaví hláškou zo `BudgetStore`;
**(2) tvrdé blokery** `export_blockers` (záporná zostava, nesúlad ponuky s rozpočtom, zliate ID skriniek); **(3) potvrditeľné riadky bez ceny** `export_confirmations` (dvojkrokový export, STANDARD §11.3).
Rozdiel medzi (1) a (3) je vecný a zámerný: **blokuje sa NEKOMPATIBILNÁ VERZIA dát, nie rozpracovanosť rozpočtu** — tú štandard výslovne pripúšťa a rieši potvrdením. `do_export` (VEPO) ani `do_hw_csv` bránu (1) nemajú: rozpočtové dáta nenesú, takže ich orezanie neskresľuje (rovnaká výnimka ako pri VEPO v P0-HF; stráži to guard test).

## Bez vlastného odseku

### bom.rb

Zber modelu a agregácia riadkov kusovníka (`Bom.collect`, `Bom.compute`, `Bom.row_key`); správanie je popísané v odsekoch, ktoré ho volajú.

**`aggregate_rows` — `free_names` (aditívny kľúč, GH #287 P2, v0.9.22).** Riadok sa zlučuje podľa **výrobných parametrov** (`row_key`), takže dielec skrinky a samostatná doska
s rovnakými rozmermi, materiálom a hranami skončia v JEDNOM riadku — a `names` potom nepovedia, čo z toho je voľný text používateľa. Riadok preto nesie navyše `free_names`:
názvy, ktoré prispel aspoň jeden záznam **dosky**. Pôvod sa poznáva z toho, čo záznam už nesie, a v konzervatívnom smere (stačí jeden znak): `part_key` v namespace `board/`
(formálny kontrakt `PartKeys.board`; korpusové kľúče sú `cabinet/`, `zone:`, `front:`) **alebo** `owner_id` `BRD-<číslo>` (`Ids.next_board_id`). Kľúč je vždy prítomný (prázdne
pole, keď doska neprispela — čitateľ nemusí brániť) a **`row_key`, poradie ani počet riadkov sa ním nemenia**. Jediný čitateľ je `VepoExport.row_name` (voľné názvy sa
neskracujú ani nepárujú); kusovník, Štúdio ani ceny ho nečítajú.

**Zber je JEDEN prechod modelu a jeho aditívne kľúče majú KAŽDÝ svojho čitateľa** — `collect` popri `records`/`hardware` vracia aj `hardware_overrides`, `manual_overrides`,
`cabinet_sets`, **`cabinet_set_conflicts`**, `placements`, `identities` a `warnings`; `compute()` ich **ignoruje** (tvar výstupu ani SCHEMA `.skp` sa nimi nemenia), číta ich
`Validation.run` a payloady sekcií. **`cabinet_set_conflicts` (1d/R-34, review #262 P1)** je zoznam ID skriniek, ktorých override setov kovania sa medzi inštanciami **rozišiel** —
`cabinet_sets` má na ID jeden slot, takže pri zdieľanom ID by expanzia použila mapu jednej inštancie na obe. Rozhoduje o tom `Bom.note_cabinet_sets` (čistá funkcia, testovaná
headless): zhodné mapy — ani „obe bez overridu" — konflikt nie sú, chýbajúci override oproti prítomnému áno. Hodnotou je **zoznam kľúčov**, v ktorých sa inštancie rozišli
(`differing_override_keys`), aby brána vedela posúdiť, či sa rozdiel tej skrinky vôbec týka; porovnáva sa proti PRVEJ videnej inštancii (keď sa všetky rovnajú jej, rovnajú sa
navzájom). Jediný čitateľ je `ProductionCore.dup_partition`.
Pravidlo, ktoré z toho platí pre každý ďalší zásah: **záznam nesie presne to, čo jeho čitateľ naozaj číta.** Pole bez čitateľa je pozvánka pre budúci kód postaviť sa naň — preto
z `manual_overrides['abs']` v 1b-4 vypadli `material_id` aj `pid` (adresa jantárového riadku je zámerne identita `owner_id` + `part_key`, nikdy persistent_id). Detail kontraktu
jantárových riadkov — čo je zdrojom ABS overridu, ako sa páruje kovanie a v akom poradí sa riadky kreslia — žije v [hardware.md](hardware.md), odsek `hardware_rules.rb`
(sekcia ŠT-3b-2a a štyri pravidlá riadku z 1b-4).

**`identities` (1b-3):** `collect` nesie popri `placements` aj **jeden záznam na INŠTANCIU** top-level skrinky/dosky (`{kind, id}`, prázdne ID sa zahadzuje) — z toho `Validation`
robí nález `duplicate_identity`. Kľúč je **aditívny** (kto ho nepozná, nič nestratí), zbiera sa v tom istom prechode a `compute()` ho ignoruje; pri doskách sa — rovnako ako
`placements` — plní **pred** filtrom `manufactured`, lebo zdieľané ID je chyba identity aj pri dočasne nevyrábanej doske.

**`hardware_issues` (KOV-A1):** ďalší **aditívny** kľúč — TVRDÉ nálezy kovania. V A1 má jediný kód `front_direction_unset` (dvierka s vedome neurčeným smerom otvárania).
Zdrojom je **uložený `config['front_items']`** korpusu, presne ako kovanie z `config.hardware[]`: žiadne prepočítavanie plánu, žiadne čítanie geometrie, žiadny druhý prechod
modelom. Výpočet je vyčlenený do čistej `Bom.front_direction_issues(owner_id, owner_pid, front_items)` (headless testovateľná), ktorá o aplikovateľnosti rozhoduje **výhradne**
cez `Fronts.direction_slots` — jedinú definíciu (viď [construction.md](construction.md)). Nález vzniká LEN pri stave `unset`; legacy čelo (kľúč `direction` v configu nemá) má stav
`nil` a nález **nikdy** nedostane. Záznam nesie `code`, `severity`, `owner_id`, **`owner_pid`**, `part_key`, `front_id` a serverový `label` (`PartKeys.human_label`).
`owner_pid` = `persistent_id` konkrétnej inštancie (audit #14 FIX 11): pri dvoch skrinkách so zdieľaným `cabinet_id` je to jediný údaj, ktorým sa dá ukázať, KTORÁ z nich smer
nemá. `compute()` kľúč **ignoruje** — kusovník, nákup ani ceny sa ním nemenia ani o číslo (dokazuje golden charakterizácia `tests/fixtures/kova_golden/`). Jediný čitateľ je
`Validation.run`.

**`hardware_manual` (KOV-H1):** aditívny kľúč s **ad-hoc položkami kovania** (konkrétne kovanie mimo setov, `config['hardware_manual'][]` — tvar drží `cabinet_builder.rb`,
viď [construction.md](construction.md)). Zber ich obohatí o `owner_id`, **`owner_pid`** a **`owner_missing`** a robí to čistá `Bom.manual_items_for(owner_id, owner_pid, items, nested)`
(headless testovateľná) — v TOM ISTOM prechode, z už načítaného `ccfg`, nad mapou vnorených dielcov, ktorú si `collect` aj tak stavia pre `manual_overrides`. `owner_missing` znamená,
že položka je pripnutá na dielec, ktorý v skrinke **už nie je** (čelo sa zmazalo, konštrukcia sa zmenila). Položka sa **NEZAHADZUJE** (audit #15 BLOCKER 4): zahodiť ju by znamenalo
ticho odobrať kus z objednávky, preto ostáva v nákupe a `Validation` ju priznáva ORANGE. Položka bez vlastníka (patrí celej skrinke) `owner_missing` nikdy nemá. Čitatelia sú dvaja:
`Validation.run` a `ProductionCore.hardware_expansion` (posiela ich do `HardwareSets.expand(manual_items:)`); `compute()` kľúč ignoruje.

**`cabinet_fronts` (KOV-H2):** aditívna mapa `cabinet_id -> front_items` (resolved čelá poslednej stavby). Slúži **výhradne** na ľudský popis vlastníka v rozklikanom **pôvode**
nákupného riadku: `PartKeys.human_label` potrebuje resolved čelá, aby vedelo, že `front:Fmsi0wnix-1-3a3kxe` je „F1" — bez nich by v Štúdiu svietilo generované id. Zbiera sa v TOM
ISTOM prechode z už načítaného `ccfg` (žiadny druhý sken modelu) a **prvá inštancia vyhráva**: dve skrinky so zdieľaným `cabinet_id` sú samostatná chyba identity (rieši ju
`identities`), popisok sa kvôli nej nemá prečo hádať. Čitateľ je jediný — `ProductionCore.decorate_source_owners`, ktoré doplní **`owner_label`** do každého záznamu
`rows[].sources` expanzie (`nil` = kovanie celej skrinky). Je to **aditívne pole zdroja**: nákupný CSV, `Budget.hardware_section` ani cenová ponuka ho nečítajú, takže výstup
zákazky sa nemení ani o znak (drží to golden odtlačok `test_kovh_golden.rb`). `compute()` kľúč ignoruje.

**`newer_configs` (KOV-H1, R-12 exportná brána; rozšírené GHOST-D1):** aditívny zoznam objektov, ktorých uložený `config_schema` je **vyšší** než kontrakt tejto verzie. Vzniklo
z auditu #15 BLOCKER 3: R-12 chránil len **prestavbu**, takže staršia verzia pluginu zákazku zo schémy 3 normálne **vyexportovala** — len bez toho, čomu nerozumie, a objednávka
aj cena boli neúplné bez slova.

**Záznam nesie DRUH:** `{ 'kind' => 'cabinet' | 'board', 'id' => … }`. Zapisuje ho jediný helper `Bom.note_newer_config` (idempotentný, prázdne ID ignoruje) pre **skrinku**
(`CabinetBuilder.newer_config?` proti `CabinetBuilder::CONFIG_SCHEMA`) aj pre **dosku** (`BoardBuilder.newer_config?` proti `BoardBuilder::BOARD_CONFIG_SCHEMA` — dva **nezávislé**
kontrakty, čísla sa navzájom neporovnávajú). Doska sa priznáva **ešte pred filtrom `manufactured: true`**: tomu poľu už nemusíme rozumieť a tiché vynechanie budúceho výrobného
poľa je presne to, čomu brána zabraňuje. **Legacy tvar (holý String) sa ďalej číta ako skrinka**, takže staršie volania a headless testy sa nemenia
(`Validation.newer_config_entry` je jediný normalizátor).

**Blocker NESMIE zaniknúť spolu s ID (Codex #298 P1).** `note_newer_config` prázdne ID ignoruje, lenže entita s poškodenou identitou **ďalej prispieva známymi poľami do
`records`** — bez adresy by teda blocker vypadol a VEPO aj ostatné výstupy by pokračovali s ticho orezaným novším configom. Adresu preto skladá **`Bom.newer_address(inst, id)`**,
ktoré vracia **dvojicu `[id_do_hlášky, pid]`**: výrobné ID je prvou voľbou, a keď chýba, použije sa **stabilná adresa entity** — `persistent_id` (prežije save/reopen), fallback
`entityID` (`Bom.entity_pid`) — v ľudskom tvare **„bez ID (pid 12345)"**, takže Kontrola aj hláška brány povedia, čo v modeli hľadať. Platí pre **dosku aj skrinku** (tá istá
trieda chyby).

**PID sa nesie aj ŠTRUKTUROVANE, nie len v texte (Codex #298 kolo 2).** Záznam má `owner_pid` (a nesie ho **vždy**, aj keď ID existuje — pri dvoch objektoch so zdieľaným ID je
to jediný údaj, ktorým sa dá povedať, ktorý z nich to je; ten istý vzor ako `owner_pid` v KOV-A1). `Validation.newer_config_entry` preto vracia trojicu `[kind, id, owner_pid]`
a nález ho ďalej podáva klik-resolveru. Bez toho by `ProductionCore.pids_for_problem` hľadal entitu so **stored ID rovným ľudskému reťazcu** — nenašiel by nič a klik na RED
riadok by vždy skončil hláškou „zoznam sa medzitým zmenil". Resolver má preto pre `CAT_NEWER_CFG` vlastnú vetvu (**`newer_config_entity`**): nájde **top-level** NOXUN kus podľa
`persistent_id` a druh proti ID **neoveruje** (objekt z novšej verzie ho nemusí mať čitateľné). Legacy záznam bez `owner_pid` sa ďalej hľadá podľa ID.

Čitatelia: `ProductionCore.export_blockers(newer:)` — hlási „Skrinka CAB-001, Doska BRD-002" (`newer_ids_text`, ten istý strop „tri + a ďalšie N") a **zastaví VEPO, nákupný CSV,
rozpočet aj ponuku** — a `Validation` (RED `newer_config`, hláška menuje **úplný** zoznam dotknutých výstupov vrátane kusovníka, ktorý je nad takým objektom neúplný, aj keď sa
ďalej zobrazuje). `compute()` kľúč ignoruje.

### sheet_estimate.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Odhad počtu platní (2B-1/D-43) — zmienky v odseku `production_core.rb` a v sekcii Kusovník v [ui-lifecycle.md](ui-lifecycle.md).

### budget.rb

_(kostra založená dávkou 1d/R-14 — doplniť pri ďalších zásahoch)_

Čistý výpočet rozpočtu: `compute(bom, state, settings, …)` je funkcia bez modelu (BOM + katalógy + stav zákazky + sadzby dodávateľa → payload), `payload_for(model, …)` je jej tenká SketchUp nadstavba (`BudgetStore.state` + `SupplierSettings.active`).
Cenová ponuka je VIEW nad hotovým payloadom (`cp_preview`), nie druhý výpočet — STANDARD §11.3.

**Kompatibilita dát cestuje v payloade (1d/R-14).** `normalize_state` prijíma aj kľúč `std` (stav markera `budget_std` zo `BudgetStore.std_state`) a `compute` z neho skladá `payload['budget_std'] = { state, blocked, reason }`.
Je to **jediná cesta**, ktorou sa o nekompatibilných dátach dozvie ktokoľvek ďalej: banner sekcie Rozpočet aj Cenová ponuka (`ui/js/budget.js`) a brána oboch cenových exportov (`ProductionCore.budget_std_block`) čítajú TENTO kľúč — nikto sa nepýta modelu druhýkrát a nikto si stav neodvodzuje sám.
Stav bez kľúča (legacy volanie výpočtu, čisté testy) je `current`, teda **nikdy neblokuje** — výpočet kompatibilitu neposudzuje, len ju NESIE. Znenie hlášky skladá `BudgetStore.std_block_reason` (jeden textový zdroj pre mutácie, exporty aj UI).

**Ad-hoc kovanie v sekcii KOVANIE (KOV-H1, audit #15 FIX 8).** `hardware_section` preberá hotovú expanziu ako doteraz a **nič neexpanduje sama** — pribudli tri veci, všetky
aditívne: riadok, ktorého množstvo (aj čiastočne) pochádza z ručne pridaných položiek, nesie **`origin: 'adhoc'`**; **voľná** položka nesie `free: true` a — to je vecné — má
**vlastný kľúč riadku** `hw:free:<skrinka>:<id>` (kľúč je adresa ručného prepisu ceny v `BudgetStore`, a voľné položky kód nemajú, takže `hw:` by mali všetky rovnaký a druhá by
prepísala prvú). Poznámku riadku skladá `hardware_note`: `missing` = „kód nie je v katalógu kovania" (bez názvu aj ceny), **`catalog_missing`** = „ručne pridaná položka — kód už
nie je v katalógu (bez ceny)"; sú to dva rôzne stavy a dve rôzne vety. **Voľné položky sú mimo `stale_scan`** — nemajú kód, takže v katalógu nemajú čo porovnávať (vetva je
explicitná, aby to bol zámer, nie náhoda). Cenová ponuka voľný riadok **nepreskočí** (`CpExport.specification` filtruje `missing`, a voľná položka ňou nikdy nie je).

### budget_store.rb

_(kostra založená dávkou 1d/R-14 — doplniť pri ďalších zásahoch)_

Dáta rozpočtu **konkrétnej zákazky** v `NOXUN` dictionary na MODELI (cestujú so `.skp`): `budget_mode`, `budget_overrides`, `budget_std_multipliers` (cenové násobiče), `budget_viz_m2`, `budget_custom_items[]`, `budget_appliances[]`, `budget_appliances_included`, `budget_cp_overrides` — a od 1d/R-14 aj `budget_std`.
Každá z 12 mutácií má vlastnú malú metódu (`set_mode!`, `set_override!`, `add_custom_item!` …), validácia je serverová a beží **pred** otvorením operácie (chybný vstup neotvorí krok Späť), a všetky mutácie končia v jedinom zápisovom bode **`write!`** = jedna mutácia = jeden krok Späť.

**Verzia formátu dát `budget_std` (1d/R-14, v0.9.4).** Rozpočtové dáta sa čítajú cez uzavreté whitelisty (`build_custom` / `build_appliance` / `numeric_map`), takže zákazka uložená NOVŠÍM pluginom by prvým klikom v Rozpočte ticho prišla o polia, ktorým táto verzia nerozumie — a nasledujúci XLSX by niesol podhodnotené číslo. Preto:

- **`BUDGET_STD` (Integer) je verzia, ktorej rozumie táto verzia pluginu**, a zapisuje sa na model pod kľúčom `budget_std`. Meno `budget_std_multipliers` je NÁHODNÁ zhoda — sú to cenové násobiče, nie verzia.
- **Guard aj pečiatka žijú v JEDINOM choke pointe `write!`:** kontrola markera stojí tesne PRED `start_operation` (odmietnutá mutácia nezaloží žiadny krok Späť), marker sa zapisuje
  PO mutačnom bloku a EŠTE PRED `commit_operation` — **údaj a marker sú jedna operácia**, takže jeden Ctrl+Z vráti oboje a výnimka pri zápise markera abortuje celý krok (žiadny
  polovičný zápis). Marker sa zapisuje **vždy ako aktuálna hodnota**, nikdy sa nepreberá z uloženého stavu ani z klientskeho payloadu.
- **Nízkoúrovňové `write_attr` / `write_json` mimo `write!` vyhodia výnimku** (prepínač `@in_write`). Je to poistka pre BUDÚCU mutáciu (spotrebiče S1): kto by siahol na dict priamo, obišiel by dopredný guard aj marker.
- **Žiadny fail-open.** `legacy` je VÝHRADNE neprítomný atribút (číta sa cez sentinel `STD_MISSING`, nie cez tolerantné `read_attr`) — ten prejde a prvá mutácia marker získa.
  `''`, `'abc'`, `1.0`, `0`, `-1` aj výnimka pri čítaní sú `:invalid` a mutácie sa odmietajú **vlastnou hláškou** o poškodených dátach; vyššie číslo je `:newer` s hláškou
  o novšej verzii. Poškodená hodnota sa NIKDY neprepisuje potichu.
- **Čítanie sa neblokuje nikdy** — `state` novšiu zákazku prečíta a pridá do nej `'std'`; zastavené sú len mutácie a (cez payload) oba cenové exporty. VEPO a nákupný CSV kovania rozpočtové dáta nenesú, takže bránu nedostávajú.
- **Disciplína bumpu:** číslo sa zvýši pri každom rozšírení whitelistu rozpočtových dát o pole, ktorého tichá strata by poškodila cenu alebo objednávku (blok 4 = väzba spotrebiča na katalóg). Detail v STANDARD §11.3.

Testy: `tests/pure/test_r14_budget_std.rb` (19 scenárov, 7 mutácií overených) · `tests/js/test_r14_budget_std.js` (banner + vypnuté ovládače oboch sekcií) · in-SU `run_r14` a `run_r14_async` (undo atómovosť — headless fake model kroky Späť nevracia).

### price_refresh.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Beh prepočtu cien voči Demosu — zmienky v odseku `production_core.rb`.

### supplier_settings.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Globálne nastavenia dodávateľa (sadzby, režimy €/€€/€€€, prah veku cien); UI je v [ui-lifecycle.md](ui-lifecycle.md), odsek o sekciách `sup`/`bset`/`about`.

**Zápis pod medziprocesovým zámkom a revízia v JADRE (1d/R-08).** `patch_active!` je klasický „prečítaj → uprav → zapíš" nad `%APPDATA%\NOXUN\Engine\supplier_settings.json`
a kontrola revízie sedela **len v okne** (`supplier_settings_dialog.handle_save`) — medzi ňou a naším zápisom stihla druhá inštancia SketchUpu uložiť svoje sadzby a náš zápis ich
zmazal, pričom okno hlásilo „Nastavenia uložené". Od tejto dávky beží celé čítanie, kontrola revízie aj zápis **pod jedným zdieľaným sidecar zámkom** `materials.lock`
(`Materials.with_catalog_lock` — mechanika a dôvod jedného zámku sú v [hardware.md](hardware.md), odsek `hardware_sets.rb`) nad **čerstvo prečítaným** súborom; to isté platí pre
seed-merge v `load` a pre `ensure_seeded` (dvojitý check — rýchly a ešte raz pod zámkom).

- `patch_active!(patch, revision = nil)` vracia **`[ok, [chyby], status]`** so `status` z `:ok | :invalid | :conflict | :write_failed`. Tretí prvok je **aditívny**, doterajšie
  `ok, errors = ...` funguje ďalej. `revision` je **pozičný, nie kľúčový** parameter zámerne: metóda sa bežne volá s bezzátvorkovým hashom (`patch_active!('rates' => {...})`)
  a Ruby 3 by taký hash pri existencii kwargs poslal do nich — z volania by zmizol povinný `patch`.
- Okno kontroluje revíziu **naďalej aj u seba** (lacno, kvôli hláške a rozpísanému formuláru) a obe vetvy konfliktu končia v tej istej obsluhe `reject_stale` — jedna hláška,
  jedno správanie (`SS.saved()` + načítanie formulára nanovo).
- `write` vracia **presný výsledok** `JsonFileStore.write`, nie bezpodmienečné `true` — write guard z R-11 zápis odmieta **bez výnimky** a bezpodmienečné `true` by odmietnutie
  hlásilo ako uložené.
- `dir` sa pýta `Materials.dir`, aby zámok a dáta boli vždy v jednom priečinku (aj pod `test_dir_override`).

**Brána degradovaného súboru (1d/R-11, v0.9.2).** Poškodený `supplier_settings.json` s platnou `.bak` sa číta zo ZÁLOHY, takže uloženie sadzieb by primár prepísalo obsahom
odvodeným od STARŠEJ zálohy — a sadzby sú **cenové** dáta. `write` má preto hneď po zámku `degraded_write_blocked?` a vracia `false`. Dôvod sa **nesurfaceuje novým kanálom**:
`patch_active_locked!` si ho vypýta z `SupplierSettings.write_block_reason` a pošle existujúcim `[false, [dôvod], :write_failed]`, takže sekcia Nastavenia ukáže konkrétnu vetu
(„súbor je poškodený — číta sa záloha, zápisy sú vypnuté, oprav alebo zmaž `<cesta>`") namiesto „nastavenia sa nepodarilo uložiť". Kontrakt `JsonFileStore.degraded?` (číta priamo
z disku, I/O chyby vyletia ako neúspešný zápis) je v [model-a-identita.md](model-a-identita.md). Testy: `tests/pure/test_r11_degradovana_zaloha.rb`.

### vepo_export.rb

**Čo to je.** Rezací výstup pre objednávkový systém VEPO — CSV skupiny + LOG, priamo z `Bom.compute[:rows]` (bez OCL medzikroku). Formát je zdroj pravdy v
[SYSTEM/VEPO_KONTRAKT.md](../../SYSTEM/VEPO_KONTRAKT.md); modul je **čistý** (žiadny SketchUp, žiadne cesty pri stavbe) — katalógové lookupy dostáva ako mapy, čas a verziu ako
parametre. Na disk zapisuje `write` **atomickou výmenou celej dávky** (staging → dvojkrokový swap, rollback pri zlyhaní, guard cudzích súborov v cieli).

**Invarianty, ktoré sa nesmú porušiť.**
- **Rozmery sú HOTOVÉ** — žiadna aritmetika, hrúbku ABS si VEPO odratáva samo z kódov hrán (`—`/`=`). Oprava z 20.7.2026, overená krížovou validáciou proti starému flow.
- **Rotácia dekoru sa robí LEN tu** (`oriented`, grain `width` = swap dĺžka↔šírka A ZÁROVEŇ dvojíc hrán). Druhý swap kdekoľvek inde by znamenal objednať dielec otočený.
- **Bajty CSV** vznikajú výhradne cez `CSV.generate(col_sep: ';', force_quotes: true, row_sep: CRLF)`, UTF-8 bez BOM, bez hlavičky. Žiadne ručné skladanie reťazca.
- Riadok s neznámou ABS, chybnou hrúbkou, bez materiálu alebo s nekladným rozmerom **ide von z CSV** do `errors` (a do LOGu s dôvodom) — radšej neobjednať než objednať naslepo.

**Poznámka pre VEPO — 9. stĺpec (D-112, v0.9.22).** CSV má deviaty stĺpec `poznamka`, **vždy prítomný** (prázdny reťazec, keď riadok poznámku nemá). Skladá ho čistá
`abs_note(row, edge_decors, sheet_decors)`: pre každý kód hrany `L1 L2 W1 W2` porovná záznam pásky so záznamom dosky a pri **rozdiele** vypíše `ABS <dekor> <názov dekoru>` (viac
rôznych pások oddelené `, `, bez opakovania toho istého textu, v poradí hrán orientovaného riadku). **Neznáma páska, neznáma doska ani záznam bez použiteľnej identity poznámku
nevymýšľajú** — tie stavy hlási `validation` (ABS/materiál mimo katalógu, UNI) a oddiel vyradených riadkov. `universal` pásky sa **nevynímajú**: VEPO odvodzuje pásku z
materiálu, takže každý odlišný dekor musí vidieť. Mapy sú **voliteľné parametre** `edge_decors:` (`{abs_id => {'decor','decor_name','group_id'}}`) / `sheet_decors:`
(`{material_id => {'decor','group_id'}}`) s defaultom `{}` — starý volajúci dostane prázdny deviaty stĺpec (holý String v mape dosiek sa tolerantne prečíta ako samotný dekor,
`decor_record`). Skladá ich `ProductionCore.vepo_edge_decors` / `vepo_sheet_decors`; **UNI dosky sa do mapy nedávajú** — ich „dekor" je pracovný názov, porovnanie by označilo
každú pásku za odlišnú (tá istá zásada, akou `Validation` potláča ABS kontroly nad UNI doskou).

**Porovnáva sa SKUPINA, nie text kódu (`same_decor?`, GH #287 P1).** Záväzná identita väzby doska↔ABS je `group_id`: dekor je kľúč **skupiny** (D-41), nie globálne unikátny kód,
a katalóg vedome dovolí dvom výrobcom rovnaký kód v rôznych skupinách. Keď majú `group_id` **obe** strany, rozhoduje výhradne ono; inak (legacy záznam) platí **vedomý fallback**
na `decor_key` — normalizáciu **zhodnú s `Materials.decor_norm_key`** (medzery preč, lowercase), ktorej kópia v tomto module je zámerná (modul nesmie siahať na katalóg, ale
porovnanie musí byť to isté). Bez skupiny **aj** bez dekoru je záznam neporovnateľný (`identifiable?` → žiadna poznámka). Porovnanie len podľa textu by dosku zo skupiny A a pásku
zo skupiny B s rovnakým `W1000` vyhlásilo za zhodu — a poznámka by ticho chýbala, teda zlý olep z výroby.
Skupiny sa porovnávajú **kanonicky, nie surovo**: `ProductionCore` vkladá do máp kľúč prehnaný cez `Materials.identity_norm` a `vepo_export` má nad tým obrannú vrstvu `group_key`
s **tou istou** normalizáciou (trim, viacnásobné medzery na jednu, upcase) — rovnaký vzor, akým `decor_key` zrkadlí `decor_norm_key`. Bez nej by `grp-x` a `GRP-X` boli dve skupiny
a export by nahlásil poznámku o inej ABS, ktorá tam nie je. **Pozor na rozdiel oproti `decor_key`:** `group_key` medzery len zlučuje, neodstraňuje (presne ako `identity_norm`).

**Názov riadku (D-113, v0.9.22).** `row_name` skladá `"<krátke názvy> <skrinky>"` (napr. `Bok LP s1 s2`) a používa ho CSV **aj LOG** (chyby, poznámky). Tri čisté kroky:
`short_name` (tabuľka skratiek na PRESNÉ reťazce builderov — `construction.rb`, `zone_tree.rb`, `fronts.rb`; **neznámy názov ide bez zmeny**), `join_names` (združenie dvojíc
`Bok L`+`Bok P`→`Bok LP`, `Vyst P`+`Vyst Z`→`Vyst PZ`, `Dv<N> L`+`Dv<N> P`→`Dv<N> LP`, zvyšok cez `/`) a `owner_tokens` (`CAB-001`→`s1`, `BRD-007`→`d7`, unikátne a zoradené;
neznámy tvar ID sa nezahadzuje, ide celý a až za nimi). `append_owners` drží `NAME_MAX = 60`: skrinky pridáva, kým sa zmestia, nezmestené zhrnie ` +K` — **nikdy odseknutá
skratka v polovici**; keď je nad limit už samotná časť s názvami, platí pôvodný orez s `…`. Platí **len pre VEPO** — kusovník Štúdia nesie plné názvy.

**Voľné názvy dosiek sa neskracujú ani nepárujú (GH #287 P2).** Názov samostatnej dosky je **voľný text používateľa**, nie názov z buildera — tabuľka skratiek naň nesmie siahnuť
(doska `Bok lavy` nie je bok skrinky) a nesmie sa spárovať s dielcom skrinky do klamlivého `Bok LP`. Pôvod nesie riadok v aditívnom kľúči **`free_names`** z `Bom.aggregate_rows`
(riadok môže byť zliatok dosky a dielca skrinky, takže samotné `names` pôvod nepovedia); `join_names` drží pri každom tokene príznak „voľný" a páruje výhradne tokeny zo skratky
generovaného názvu. Keď ten istý reťazec prispela doska **aj** skrinka, platí konzervatívna cesta: pass-through bez skratky a bez páru.

**Čo poznámka ani názov NEROBIA.** Sú to len **zobrazenie riadku**: `Bom.row_key` (a teda zlučovanie a počet riadkov), grouping podľa materiálu a hrúbkovej skupiny, názvy
súborov, kódy hrán, obchodné hrúbky ani sekcia KONTROLA sa nemenia. Poradie oddielov LOGu: skupiny → vyradené riadky → **Poznámky pre VEPO** → KONTROLA.

**Testy:** `tests/pure/test_vepo_export.rb` (bajtové vzorky vrátane zlatej — jediný „schválený" obraz formátu, mení sa VÝHRADNE samostatným commitom s dôvodom),
`tests/pure/test_d112_d113_vepo.rb` (správanie poznámky, skratiek a orezu + mapy dekorov nad sandbox katalógom), in-SU `run_k1` (rotácia dekoru v reálnom CSV).

### cp_export.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### xlsx_writer.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_
