# Kovanie — pravidlá, katalóg a sety

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Pravidlá kovania (projektový snapshot na modeli), globálny katalóg položiek a sety, z ktorých vzniká nákupný zoznam.

### hardware_rules.rb

pravidlá kovania (V0.4): Ruby vzory `fixed`/`bands`/`fit_series` parametrizované JSON pravidlami; **projektový snapshot na modeli** (kľúč `hardware_rules` — rebuild
reprodukovateľný z .skp; globál `%APPDATA%` len default nových projektov + seed-merge); `hardware_overrides` v configu korpusu s identitou (owner_part_key, generic_type, rule_id).

**KOV-W (v0.9.47) — vstup `weight` (`INPUT_WEIGHT`, kg).** Vedľa `height`/`width` (prod rozmery dielca) vie `input_value` čítať aj **hmotnosť dielca** z anotácie plánu
(`pd[:weight_kg]`, viď [construction.md](construction.md)) — pripravené pre závesy (KOV-F) a výklopy (KOV-E), kde o kovaní rozhoduje hmotnosť čela. Konštanta je **jediná
autorita názvu**; nie je to kontextový kľúč (`CONTEXT_KEYS`), lebo hodnota patrí DIELCU, nie korpusu. Hmotnosť čela je počítaná z **katalógovej hrúbky** (25 mm čelo teda
vyjde ťažšie než placeholderových 18 mm — pásmo sa nesmie určiť z podhodnotenej váhy). Keď plán bežal **bez materiálov** (starí volajúci), kľúč na deskriptore nie je a platí
existujúca cesta „neznámy vstup": položka **nevznikne** + `info` warning `hardware_rule_skipped`. Žiadne seed pravidlo ho zatiaľ nepoužíva.

**KOV-F1 (v0.9.48) — NOXUN TABUĽKA ZÁVESOV + voliteľné door guardy pravidla `bands`.** Seed `zavesy-podla-vysky` dostal tabuľku
**849 → 2 · 1700 → 3 · 2200 → 4 · 2400 → 5 · 2600 → 6 · 2800 → 7** (výška ≤ max, inkluzívne; 849 < h < 850 → 3) a k nej **VOLITEĽNÉ** kľúče
(`DOOR_GUARD_KEYS`): `width_plus {over, add}` (šírka **krídla** > 600 mm → +1, bez podmienky výšky) · `width_warn_over` (ORANGE `door_wide`) ·
`weight_bands` (Hettich pásma, vo V1 **len varujú**) · `finite`. **ŽIADNY nový `kind`** (Sol audit kolo 2 BLOCKER 1): starší plugin by neznámy kind
preskočil a dvierka by dostali NULA závesov — a to aj pri NOVOM vložení skrinky, lebo čítače pravidiel `std` ignorujú. Preto ostáva aj **catch-all
pásmo `nil → 7`**: starý čítač ráta podľa tabuľky (bez +1 a bez varovaní), nikdy nulu; `normalize_rules` mu nové kľúče **zachová** (vetva „neznáme
kľúče") a jeho `compute` ich nevidí. Hranica downgrade je vedomá (knižnice sú per PC, updater D-52 drží obe PC aktuálne — „starší plugin s novšou
knižnicou" je downgrade na tom istom PC, riziko do D-48).

**`finite` = catch-all znamená „MIMO tabuľky".** Pre NOVÝ čítač zásah catch-all pásma **vydá položku** s jeho počtom (riadok v Kovaní MUSÍ existovať,
inak nemá kde vzniknúť ručný zámok — Sol kolo 2 BLOCKER 2) a navyše vydá **KONFLIKT `door_height_out_of_table`** (`DOOR_OUT_OF_TABLE`), ktorý ide
uloženým nosičom `hardware_conflicts` do configu ([construction.md](construction.md)) a odtiaľ do RED Kontroly aj do exportnej brány
([outputs.md](outputs.md)). Validátor zápisu („pásmo všetko nad je povinné") sa **nemení** — catch-all je stále prítomný.

**KONEČNÁ tabuľka BEZ číselného pásma je fail-closed (Codex #329 kolo 3 P2).** Editor pásma mazať dovoľuje a catch-all zmazať nejde, takže sa dá dôjsť
k tabuľke, v ktorej ostalo iba pásmo „všetko nad" + skrytý `finite`. Predtým `out_of_table_conflict` na takom tvare konflikt POTLAČIL (`top` nil), takže
každé čelo ticho dostalo catch-all počet a nikde nebol RED. Odteraz platí OBOJE: zápisová brána taký tvar **odmietne** (viď nižšie) a v evaluácii je
**mimo tabuľky KAŽDÉ čelo** — položka s catch-all počtom + RED s vlastnou vetou („tabuľka nemá ani jedno číselné pásmo"). Ručný zámok počtu ho zhasína
rovnako ako pri nadvýške.

**Door guardy bežia AŽ NAD VÝSLEDNÝMI položkami (`door_guards`, čistá funkcia).** `evaluate` ich volá po `apply_overrides` a vracia z nich
`{items:, warnings:, conflicts:}`. Dôvod je vecný: hmotnostné pásmo sa musí porovnávať s počtom **PO ručnom zámku** (inak by varovalo aj vtedy, keď si
používateľ počet už zdvihol) a konflikt „mimo tabuľky" musí ručný zámok **ZHASNÚŤ**. Zámok sa hľadá v RUČNÝCH ZÁSAHOCH (`quantity_locked?` = záznam
`hardware_overrides` s platným poľom `quantity`, ten istý výklad a poradie „posledný vyhráva" ako v `apply_overrides`), **nie** cez `source: 'manual'` na
položke — ten nesie aj override, ktorý menil iba `nominal_length`, a taký o počte nepovedal nič (Codex #329 kolo 2 P2). Varovania **počet
NEMENIA**: `door_wide` · `door_wider_than_high` („nemá to byť výklop?") · `hinge_weight_more` (pásmo chce viac než výsledný počet) ·
`hinge_weight_max` (nad posledným pásmom); neznáma hmotnosť = **INFO** `hinge_weight_unknown` v `Validation::BUILD_INFO_ONLY` (plán bez materiálov je
legitímny stav, ORANGE na každých dvierkach by bol hluk).

**`STD` 1 → 2 a FORWARD BRÁNA čítačov.** Dokument (knižnica aj projektový snapshot) s vyšším `std` sa **číta** (zákazka sa musí dať dokončiť), ale
**nikdy sa doň nezapisuje** ani nemerguje seed: `doc_std_unsupported?` je jediná autorita otázky, `read_rules` pri nej seed-merge vynechá,
`newer_write_blocked?` je druhá zápisová brána knižnice (pod zámkom, vedľa degradovaného súboru) a `project_std_unsupported?` chráni snapshot. Bez nej
by tolerantná `normalize_rules` ticho zahodila pole, ktorému nerozumieme, a prvý zápis by stratu zvečnil (vzor `HardwareSets` `STD_SUPPORTED`).
**Nekompatibilná knižnica sa do projektu NEZMRAZÍ** (Codex #329 kolo 2 P1, vzor R-07 `HardwareSets.ensure_project_state!`): `read_rules` vracia
`[pravidlá, changed, blocked]`, `load_state` ten príznak podáva ďalej a `ensure_project_rules!` pri ňom snapshot **nevytvorí** — inak by sa do .skp
zapísal náš `std` nad obsahom, ktorý už prešiel našou `normalize_rules` (`normalize_bands` drží len `max`/`quantity`), budúce polia by ticho zmizli
**a brána by sa už nikdy nespustila**. Stavba beží ďalej nad prečítaným obsahom (tabuľka `bands` je forward-čitateľná zámerne a nikdy nevydá nulu), ale
`CabinetBuilder.attach_rules_state_warning!` k nej pridá ORANGE `hardware_rules_library_incompatible` („aktualizuj plugin") — protajšok `library_incompatible`
pri setoch. Autorita stavu je `library_incompatible_without_snapshot?(model)`; projekt s vlastným snapshotom je zdravý bez ohľadu na knižnicu.
**Príznak `blocked` prežije aj DRUHÉ čítanie (Codex #329 kolo 3 P2).** `persist_seed_merge!` číta knižnicu pod zámkom ZNOVA (read-modify-write) a vracia
**tú istú dvojicu** `[pravidlá, blocked]` ako `load_state`. Kým sa tretia hodnota zahadzovala a `blocked` sa hlásilo natvrdo `false`, stačilo, aby knižnicu
medzi prvým čítaním a zámkom nahradil novší plugin — a `ensure_project_rules!` by orezané pravidlá zmrazil do .skp.

**PROJEKTOVÝ snapshot z novšieho pluginu = TRVALÝ RED (Codex #329 kolo 3 P1).** Knižnicu chráni ORANGE vyššie, ale projekt, ktorý snapshot UŽ MÁ (rollback
pluginu, zákazka od kolegu s novšou verziou), bol dovtedy neviditeľný: `ensure_project_rules!` snapshot prečítal a `library_incompatible_without_snapshot?`
bol `false` LEN preto, že snapshot existuje. Starší čítač tak prestaval skrinky svojou schémou a vydal nákup, rozpočet aj ponuku s degradovanými počtami.
`Bom.rules_snapshot_issue(model)` (autorita stavu je `project_std_unsupported?`) preto vydáva RED **`hardware_rules_snapshot_incompatible`** — kód nemá
vlastníka (je to stav CELÉHO projektu, preto ho Kontrola aj brána adresujú bez ID) a stojí v novom registri `BuildPlan::HW_RULES_BLOCKERS`. Nález je
**trvalý**: snapshot sa neprepisuje ani nezmrazuje (zápisové cesty ho odmietajú), takže prestavba ho nezhasne — jediná náprava je aktualizácia pluginu.
Detail brány v [outputs.md](outputs.md).

**`HINGE_TABLE_STD` = 2 a `pre_hinge_table_rules?`.** Samostatná konštanta (nie `STD`): hovorí, OD KTOREJ verzie formátu nesie seed pravidlo závesov door
guardy. `pre_hinge_table_rules?(model)` sa pýta PROJEKTOVÉHO snapshotu, a keď ho projekt nemá, globálnej knižnice (neznámy/poškodený stav = `false`,
fallback sú `SEED_RULES`, ktoré tabuľku už nesú). Rozhoduje **verzia formátu, nie obsah pravidla**: vedomý používateľský rule bez guardov uložený PO F1 je
rozhodnutie, nie zaostalosť — a každý zápis snapshotu (Uložiť v Pravidlách aj „Doplniť nové predvoľby") pečatí aktuálny `std`. Čitateľ je `hinge_stale`
([outputs.md](outputs.md)).

**Hranica downgrade:** knižnice sú per PC a updater (D-52) drží obe PC aktuálne, takže „starší plugin s novšou knižnicou" je downgrade na tom istom PC —
vedomé riziko do D-48. Preto kind ostáva `bands` (starý čítač ráta podľa tabuľky, catch-all 7) a nové čítače `std` honorujú.

**Seed sa nahrádza LEN v presnom starom tvare + PREKRYV.** `LEGACY_SEED_SHAPES` (nový register pravidiel, vzor `HardwareSets`) drží v1..v3 tvar tabuľky
(900/1400/1900 → 2/3/4/5); do globálnej knižnice aj do projektového snapshotu („Doplniť nové predvoľby") sa nový tvar dostane iba tam, kde je pravidlo
preukázateľne nedotknuté. **`seed_additions`** navyše seed **nedoplní**, keď rolu už obsluhuje INÉ zapnuté pravidlo s `output: hinge` (`OVERLAP_OUTPUT`)
— dvoje závesov na tých istých dvierkach je dvojitý nákup. Taký prekryv `evaluate` **prizná** ORANGE `hardware_rule_overlap` a uplatní **prvé** pravidlo
v poradí. Úzko na `hinge` zámerne: dve úchytkové pravidlá na jednej role sú legitímny stav. `SEED_VERSION` 3 → 4.

**Klasifikácia položky závesu.** `part_params` pre `output: hinge` vydá `params {use_type: 'door', opening_mode}`; otváranie pochádza z anotácie plánu
(`Construction.annotate_front_modes!`, vzor KOV-W `weight_kg`), dielec bez nej je legacy čelo a platí `classic`. Korpusová úroveň (`pd` nil) params
nedostane — záves bez dielca nemá otváranie, podľa ktorého by sa vyberal set.

**KOV-E1b (v0.9.54) — VÝKLOPY: kind `lift_class`, filter `flap_dir`, dve nové seed pravidlá.** Štvrtý vzor (`KINDS + lift_class`) nevydáva POČET, ale
**KLASIFIKÁCIU**: `params {use_type: 'lift', lift_system, opening_mode, lift_class, arm_class (HL), rod_count, rod_extension}`, `quantity` vždy 1. Kód z triedy robí až
set (`code_by_param`, E1a) — pravidlo žiadny kód nepozná. Seed `vyklopy-aventos` (`applies_to {role: 'flap', flap_dir: 'up'}`) nesie:
`handle_allowance_kg` **0,5 kg** (pripočíta sa pri OBOCH systémoch — Blum LF aj HL tabuľka rátajú s úchytkou, Astra BLOCKER 3) · **`classes`** HK top
(LF = KH × hmotnosť; 22K2300 420–1610 · 22K2500 930–2800 · 22K2700 1730–5200 · 22K2900 3200–9000, inkluzívne, **v prekryve vyhráva najslabšia**) ·
**`mechanisms`** HL top (max-pásma podľa KH: < 390 → 22L2200, ≤ 580 → 22L2500) · **`arms`** HL top (`kh_min`/`kh_max` + `kg_min`/`kg_max`; 300–340 · 340–390 ·
390–540 · 480–580, v prekryve KH **najslabšie ramená, ktoré hmotnosť pokryjú**) · `rod_double_from_kb_mm` **1100** (KB ≥ → 2 tyče + predĺženie) ·
**`eligibility`** per systém (HK `kh 205–600`, `kb ≤ 1800`; HL `kh 300–580`, `kb ≤ 1800`, `depth_min 264` = vnútorná hĺbka).
**`max_exclusive`** je jediný spôsob, ako sú Blum pásma 300–339 / 340–389 SPOJITÉ bez diery pri 339,5: horná hranica do pásma nepatrí. Normalizácia
(`normalize_lift_rule!`) tabuľky typovo očistí (riadok bez kódu alebo bez čísel **vypadne**) a **zoradí** — poradie je významové, lebo rozhoduje o „najslabšej".
Zápisová brána (`lift_problem`) odmietne prázdnu tabuľku, obrátené pásmo a **dieru medzi pásmami ramien**.

**`applies_to.flap_dir` a druhé seed pravidlo `zavesy-sklop`.** Rola `flap` je spoločná pre výklop aj sklop, preto `apply_rule` filtruje čelá podľa smeru: pravidlo
BEZ filtra platí na oba (dnešné správanie), deskriptor bez smeru filtru **nevyhovie**. Sklop je z pohľadu kovania dvierka, takže dostane kópiu tabuľky závesov
(`bands` + door guardy) s `applies_to {role: 'flap', flap_dir: 'down'}` a položkou `params.use_type = 'door'` — set si hľadá tým istým triednym kľúčom `class:hinge|…`
ako dvierka (vzpery `use_type: 'fall'` sú mimo V1). Dva dôsledky pre door guardy: `door_wider_than_high` sa na rolu `flap` **neuplatní** (širšie než vyššie je pri sklope
norma) a `door_label` hovorí „Sklop", nie „Dvierka".

**Prekryv sa porovnáva podľa (výstup, rola, SMER) — `OVERLAP_OUTPUTS = hinge + lift`** (Codex #331 kolo 3 P1, delta audit Sol BLOCKER 2). Kľúč skladá `overlap_key`
a rozhoduje `overlap_conflict?` (prázdny smer = wildcard, pretína sa s oboma) — a **tie isté dve funkcie** používa `seed_additions` aj runtime vetva v `evaluate`.
Kým sa runtime prekryv pýtal len na rolu, skoršie pravidlo `hinge/flap/up` by potlačilo `zavesy-sklop` **aj na skrinke, kde je len sklop** (nula závesov, iba ORANGE),
a `lift` sa nekontroloval vôbec (dve rôzne pomenované výklopové pravidlá = dva mechanizmy na jednom čele). Vlastné pravidlo len pre `down` seed výklopov nepotlačí.

**Položky seed pravidla výklopov sú PLNÝ AUTOMAT** (Astra FIX 11, rozsah zúžený Codex #331 kolo 2 P1). Výklop je zostava, takže „vypnúť" ani „ručný počet" na ňom
neexistuje: `apply_overrides` záznam s `rule_id == 'vyklopy-aventos'` **ignoruje** a prizná ORANGE `lift_override_ignored`, a `CabinetBuilder.norm_hardware_overrides`
ho pri normalizácii configu **vyčistí so záznamom v logu**. **Vlastné** `lift` pravidlá používateľa a ich overridy ostávajú ÚČINNÉ — ochrana je viazaná na `rule_id`
seedu, nie na typ kovania.

**`STD` 2 → 3 a `SEED_VERSION` 4 → 5.** `std` chráni ZÁPIS: starší plugin kind `lift_class` nepozná (výklop by ostal bez položky — vedomé riziko do D-48) a filter smeru
IGNORUJE, takže by `zavesy-sklop` uplatnil na každé čelo `flap` vrátane výklopu. **`SEED_VERSION` sa bumpuje SAMOSTATNE** (delta audit Sol FIX 5): `merge_seed` migráciu
preskočí pri `from_version >= SEED_VERSION`, takže bez bumpu by existujúca knižnica nové seed pravidlá nedala ani novým projektom. `LEGACY_SEED_SHAPES` sa
**nerozširuje** — obe pravidlá sú nové a starší tvar, ktorý by sa dal „obnoviť", neexistuje.

**`LIFT_SEED_VERSION` = 5 a `effective_seed_version(model)` (Codex #333 kolo 1 P1).** Jediná autorita otázky „s akým seedom sa TERAZ stavia": rozhoduje projektový
snapshot (`project_doc` → `seed_version`, chýbajúci kľúč = 0), a keď ho projekt nemá, dedí knižnicu (`library_seed_version` — čítanie ju MIGRUJE, takže je to aspoň naša
`SEED_VERSION`; výnimka je knižnica z novšieho pluginu, ktorú `read_rules` zámerne nemerguje). Hodnotu si **ukladá stavba** do configu skrinky
(`rules_seed_version`, [construction.md](construction.md)) a číta ju migračná brána `flap_stale` ([outputs.md](outputs.md)) — sama schéma configu nestačí, lebo
prestavba so starým snapshotom zapíše novú schému a nevydá nič. `LIFT_SEED_VERSION` je **pevné číslo** (ako `HINGE_TABLE_STD`): budúci bump seedu na hranici nič nemení.

**ÚPLNÁ RUČNÁ ZOSTAVA NA ČELE `flap` VYPÍNA AUTOMAT (Codex #333 kolá 1 a 2).** `evaluate(..., manual_flap_owners:)` dostáva mapu `{ owner_part_key => { 'lift'|'hinge' => true } }`
(pripravuje ju `CabinetBuilder` — [construction.md](construction.md)) a `apply_rule` na takom čele položku **nevydá**; `manual_flap_warnings` prizná
JEDEN ORANGE `flap_manual_hardware` na (čelo, druh). Je to ten istý vzor ako `suppress_slide_owners`, ale iný dôvod: ad-hoc katalógový riadok sa v nákupe **zlieva so
setovým podľa kódu** (`HardwareSets.add_adhoc_row` sčítava množstvá), takže stará skrinka s ručne pridaným výklopom by po prestavbe objednala mechanizmus dvakrát.
Fail-closed smerom k človeku: platí RUČNÝ záznam (ten je vedomý), automat sa prizná ORANGE-om. **Úzko len na rolu `flap`** — ručný záves na DVIERKACH správanie F1
nemení (automat beží ďalej ako doteraz).

**`HardwareSets.flap_set_codes` / `manual_flap_assemblies` — JEDEN zdieľaný predikát (Codex #333 kolo 2 P1).** Kým to boli dva predikáty (builder podľa kategórie
katalógu, `Bom` podľa akéhokoľvek owner-bound záznamu), jedna ručne pridaná **krytka** vypla automat aj jeho tvrdé kontroly a naopak **úchytka alebo voľná poznámka**
zhasla migračnú RED `flap_stale`. Od kola 2 platí jedna definícia: **ručná zostava je úplná LEN s mechanizmom**. `flap_set_codes(state)` prejde `SEED_SETS`
**+ sety projektového snapshotu** (`FLAP_USE_TYPES`: `lift` → `use_type lift`, `hinge` → `use_type door`) a vráti `{ druh => { 'mechanism' => {kód}, 'members' => {kód} } }`;
mechanizmus je **prvý člen `per: 'unit'`** (poradie členov je záväzné — pri výklope je to `code_by_param lift_class`, pri sklope samotný záves), `members` sú všetky kódy
setu (podklad ORANGE `flap_manual_duplicate`). Ramená, tyče, krytky, Tip-On ani úchytky zostavu netvoria. `manual_flap_assemblies(manual, codes)` z toho urobí mapu
`{ owner_part_key => { druh => true } }` — číta LEN pamäť a modelový atribút (**žiadne IO**), takže ho zvládne aj zber: `Bom.collect` si kódy vypýta RAZ na zber (vzor
`rules_stale`) a odovzdá ich do `flap_stale_issue` ([outputs.md](outputs.md)). Katalóg (a s ním „živý zdroj, ktorý sa mohol zmeniť") už v tejto ceste nefiguruje.

**ALE ZLIATIE KÓDOV SA PÝTA ÚČINNÉHO SETU — `HardwareSets.flap_emitted_codes` (Codex #333 kolo 3 P2).** `flap_set_codes` odpovedá za **všetky** výklopové a závesové sety
(seed aj snapshot), takže ako podklad ORANGE `flap_manual_duplicate` klamal: HK čelo s ručne pridanou **HL stabilizačnou tyčou** (507365) dostávalo varovanie „nákup to
spočíta", hoci jeho HK set taký kód nikdy nevydá. `flap_emitted_codes(hardware_items, state, overrides:)` preto ide **tou istou cestou ako `expand`** a vráti
`{ owner_part_key => { 'lift'|'hinge' => { kód => true } } }`: účinný set podľa precedencie (`resolve_set_id` — owner override > triedny override skrinky > triedny kľúč
projektu) a jeho brány (`generic_type` setu, `set_incompatible_info`, `length_unsupported?`), potom **rozlíšenie členov podľa parametrov položky** — `code_by_param`
(`lift_class` / `arm_class`) dá presne jeden kód a `quantity_from` s nulou (predĺženie tyče pod prahom 1100 mm) znamená, že sa člen **nevydá**. Katalóg netreba (kódy sú
v sete, parametre v položke) a **IO tiež nie**, takže to zvládne stavba. `overrides` je mapa **jednej** skrinky (`config.hardware_sets`) — položky plánu ešte `owner_id`
nenesú (dopisuje ho až `Bom.collect`), preto sa použije pre každé `owner_id`. Bez snapshotu setov (nekompatibilná knižnica) je mapa prázdna a varovanie nevznikne —
správne, taký nákup je celý ORANGE `library_incompatible` a nemá s čím zliať. `flap_set_codes` ostáva tam, kde je otázka iná („je tento kód vôbec mechanizmus?").

**Nečíselný skalár výklopu NEZHODÍ dokument (Codex #333 kolo 2 P2).** `normalize_lift_rule!` prehnal `handle_allowance_kg` a `rod_double_from_kb_mm` cez `to_f` —
na Hash/Array/`true` (pokazený alebo cudzí snapshot) to **vyhodí výnimku**, `project_rules` ju odchytil, vrátil `nil` a `ensure_project_rules!` potom projektové pravidlá
**ticho nahradil globálnou knižnicou**. Od kola 2 ich čistí `normalize_lift_scalar!` s tou istou typovou kontrolou ako bunky tabuliek (`lift_row?`): nečíselná hodnota sa
nehádže preč ani nehádže — kľúč **ostáva s hodnotou `nil`**. Je to vzor `weight_bands` (KOV-F2): normalizácia nechá tvar, ktorý brána odmietne, takže `lift_problem`
o probleme povie (`LIFT_SCALARS` → „rezerva na úchytku musí byť číslo") a uloženie takého pravidla neprejde; vypnuté pravidlo sa nekontroluje, takže cesta von existuje.
Čitatelia (`lift_allowance`, `lift_rod_count`) sú typovo bezpeční už dnes: `nil` = žiadna rezerva / jedna tyč, nikdy hádanie.

**Klientska parita validácie výklopu (Codex #333 kolo 1 P2).** `rdValidate` má vetvu `lift_class` (`rdLiftProblem`) s tými istými kritériami ako `lift_problem`
(prázdne `classes`/`mechanisms`/`arms`, obrátený rozsah, diera medzi pásmami ramien, **záporná `handle_allowance_kg`** — tá by hmotnosť znížila a vybrala slabší
mechanizmus) a rovnakým predfiltrom riadkov ako `lift_row?`. Výklop sa v UI zatiaľ needituje, ale sekcia ukladá **všetky** pravidlá naraz, takže bez tejto vetvy by
klient uloženie pustil, server ho zamietol a read-only tabuľku by nebolo kde opraviť. Vypnutie pokazeného pravidla ostáva možné (`enabled: false` sa nevaliduje).
Spoločný kontrakt je `tests/fixtures/rules_validation_parity.json` — keď sa kritériá rozídu, padne práve jedna zo sád. **Od kola 3 (P2) zrkadlí klient aj typovú
kontrolu skalárov:** `RD_LIFT_SCALARS` je kópia serverovej mapy `LIFT_SCALARS` a nečíselná hodnota (kľúč, ktorý normalizácia nechala ako `null`) padne rovnako ako na
serveri. Predtým `rdLiftNum(...) || 0` bral pokazenú rezervu ako **nulu** a prah tyče netypoval vôbec — Save prešiel klientom a server ho zamietol.

**KOV-E2 (v0.9.55) — EDITOR pravidla `lift_class` a tri nové kritériá brány.** Read-only veta z E1b **zanikla**: v sekcii Pravidlá má výklopové pravidlo **formulár**
presne vo vzore door guardov z F2 — zbalený `<details>` (`rdLiftHtml`, `RD_LIFT_OPEN` kľúčované `rule_id`) so **súhrnom v lište** („HK 4 triedy · HL 2 + 4 ramená · tyč od
1100 mm · rezerva 0,5 kg"), skaláre, tri tabuľky (triedy HK · mechanizmy HL · ramená HL, každá s „+ riadok" a „✕") a **spôsobilosť per systém** (`RD_LIFT_ELIG` je zrkadlo
`ELIGIBILITY_KEYS`). `RD_LIFT_KEYS` je zrkadlo serverových kľúčov (`LIFT_SCALARS` + `classes`/`mechanisms`/`arms`/`eligibility`) — guard test zhodu stráži. **Zber
(`rdCollectLift`) je bezstratový aj v tom, čo NIE JE pole formulára:** `max_exclusive` (Blum má spojité pásma 300–339 a 340–389) cestuje cez `data-mx` na riadku a tooltip
hornej hranice o ňom hovorí; bez toho by sa dve pásma ramien začali **prekrývať** a automat by pri hraničnej výške vybral iné ramená. **Prázdne pole = kritérium sa
nezapíše** (vzor F2), nekladná hodnota spôsobilosti ide preč rovnako ako v `normalize_lift_eligibility` — tvar „klient pošle, server ticho zahodí" nevzniká. Poškodený tvar
(hash namiesto poľa) sekciu **nezhodí** (lekcia Codex #330) a uložením sa z pravidla odpratá.

Brána (`lift_problem`) dostala **tri kritériá naviac**, všetky nad tvarom PO normalizácii a všetky zrkadlené v `rdLiftProblem`: **nekladný `rod_double_from_kb_mm`**
(`lift_rod_count` žiada kladné číslo, takže by pravidlo ticho tvrdilo „druhá tyč nikdy" — a pri **nule** by súhrn v lište zároveň písal „tyč od 0 mm", teda „druhá tyč
vždy"; „žiadne zdvojenie" sa hovorí **prázdnym poľom**, Codex #334 kolo 1 P2 — a tyč je nákupná položka) · **záporná hodnota v ktorejkoľvek tabuľke**
(`lift_negative_row`; `lift_row?` prepustí každé konečné číslo, takže „LF od −500" by prešlo) · **spôsobilosť s obrátenou výškou** (`lift_eligibility_problem`; každé kladné
číslo normalizácia nechá, takže `kh_min 600` a `kh_max 205` by prežilo a systém by nebol použiteľný **nikdy**, bez slova o dôvode). `kh_min == kh_max` je legitímne.
Poradie sa nevynucuje (server zoraďuje) a **prekryv sa nekontroluje zámerne** — HK triedy Blumu sa prekrývajú a ramená 480–540 tiež; kontrolovaná je len **spojitosť**
(`arms_gap_problem`). **Zápisová cesta má odteraz DVE brány (Codex #334 kolo 1 P2).** `rules_problems` sa pýta tvaru PO normalizácii, a preto **nevidí riadok, ktorý normalizácia zahodila**:
kto v tabuľke rozpíše riadok a vyplní len kód (alebo len jednu hranicu), uložil by ho bez slova a po prestavbe by riadok zmizol. Odhodenie je pri **čítaní** správne
(legacy snapshot sa musí dať prečítať a hádať sa nesmie), pri **uložení** je to tiché zahodenie práce — preto pred normalizáciou stojí `HardwareRules.lift_input_problems`
nad **surovým** vstupom a kontroluje **výhradne** nedopísaný riadok (`lift_partial_row?`, tabuľky a ich ľudské názvy drží `LIFT_TABLES`, zrkadlo v `rules.js` je
`RD_LIFT_TABLES`). **Úplne prázdny riadok je pohodlie editora** (pridám, rozmyslím si to) a mlčky sa zahadzuje na oboch stranách. Volajúci je **jediný** — `handle_save`
v `rules_dialog.rb`; stavba ani seed validáciu nevolajú. Fixtúra parity sa preto pýta **oboch brán naraz** (klient má na obe jednu odpoveď `rdValidate`).

**Hint pod editorom hovorí, čo uloženie SKUTOČNE robí (Codex #334 kolo 2 P2).** Tvrdil, že „po uložení sa skrinky neprestavia — prestav ich"; uloženie pravidiel v Štúdiu
pritom prestavuje **všetky** skrinky (`RulesDialog.handle_save` → `CabinetBuilder.rebuild_many`, **jeden** krok Späť) a status hlási ich počet. Výzva na ďalšiu prestavbu
posielala človeka robiť prácu, ktorá je už hotová, a protirečila tlačidlu lišty **„Uložiť a prestavať skrinky"**. Znenie je odteraz „Uloženie prestaví všetky skrinky, takže
nové hodnoty platia hneď."; ostatné hinty sekcie (pásma F2, rad výsuvov) taký omyl nemali — hovoria o kritériách, nie o prestavbe.

Nové prípady sú v `tests/fixtures/rules_validation_parity.json`. Testy: `tests/pure/test_kove2_ui.rb`, `tests/js/test_kove2_rules_editor.js`.

**KOV-G1b (v0.9.59) — NOHY PODĽA ŠÍRKY, PRÍCHYT SOKLA a filter `applies_to.floor_height_min`.** Seed `nohy-zakladne` už nie je `fixed 4`, ale
**`bands` s `input: 'width'`** (`max 999 → 4`, catch-all `→ 6`; konvencia „< 1000" je tá istá ako 849 pri závesoch, takže **neceločíselná** šírka
999,5 padne do horného pásma — šírky korpusov sú v praxi celé milimetre a radšej o nohu viac). `applies_to.support %w[legs plinth]` aj
`params_from_context {height: floor_height}` **ostávajú**: šírka rieši POČET, výška sokla naďalej KÓD (set `nohy-podla-sokla`, G1a). Nové seed pravidlo
**`prichyt-sokla`** (`PLINTH_CLIP_RULE_ID`) vydáva `plinth_clip` rovnakými pásmami (`999 → 1`, catch-all `→ 2`) = **1 ks na začaté 4 nohy** (rozhodnutie
O3; žiadny pomerový člen, D-109 ostáva po V1). Platí **len pri samostatnej soklovej lište**: `support %w[legs]` (sokel vpredu je súčasť korpusu a lišta
neexistuje) a **`floor_height_min` 55,0** — pod tým je klzák 17–20 mm, ktorý žiadnu lištu nemá. Zóna 20–55 mm ostáva vedome nepokrytá **SETOM** (ORANGE
„doplň pásmo" z G1a), pravidlo tam nohy vydáva ako doteraz.

**`floor_height_min` je VOLITEĽNÝ filter `applies_to`, nie nový `kind`** (vzor `flap_dir` z E1b): `apply_rule` ho pre rolu `cabinet` vyhodnocuje vedľa
`support`/`cabinet_type` cez `floor_height_ok?` — jedinú autoritu otázky. Kontext **bez použiteľnej výšky** filtru NEVYHOVIE (hádať by znamenalo objednať
príchyt ku klzáku). `normalize_rules` prah typovo očistí (`normalize_floor_height_min!`): konečné **kladné** číslo → Float (mm), čokoľvek iné sa **zahodí
aj s kľúčom** + `Engine.log` — pravidlo potom platí BEZ prahu, rovnako ako pravidlo, ktoré prah nikdy nemalo (vzor `width_warn_over`). Vedomý dôsledok:
pokazený prah znamená príchyt aj tam, kde lišta nie je — taký riadok je v Nákupe **vidno** (na rozdiel od ticho chýbajúceho kovania) a editor prahu
neexistuje, takže sa tam dá dostať len ručnou úpravou JSON. **STARŠÍ PLUGIN kľúč ZACHOVÁ, ale NEUPLATNÍ** (vetva „neznáme kľúče" v `normalize_rules`),
takže by príchyt vydal aj pri sokli 17 mm; `std` sa **nemení** (žiadny nový kind), takže táto hranica downgrade je vedomá — rovnaké riziko ako pri
`flap_dir` (knižnice sú per PC, updater D-52; D-48).

**`SEED_VERSION` 5 → 6 a `LEGACY_SEED_SHAPES['nohy-zakladne']`.** Bez bumpu by `merge_seed` migráciu preskočil a existujúca knižnica by nové pravidlá
nedala ani novým projektom. Starý tvar nôh (`fixed 4`, v1..v5) je v `LEGACY_SEED_SHAPES`, takže **preukázateľne nedotknuté** pravidlo dostane nový tvar
(knižnica sama, projektový snapshot až cez „Doplniť nové predvoľby" → `project_seed_plan`); používateľom upravené (napr. 5 nôh) sa **nikdy** neprepíše.
**`OVERLAP_OUTPUTS` = `hinge + lift + plinth_clip`:** vlastné zapnuté pravidlo na `plinth_clip` doplnenie seedu zastaví (inak dvojitý nákup) a runtime
prekryv prizná ORANGE `hardware_rule_overlap` s vetou „druhé pravidlo **príchytov sokla**" (`overlap_noun`). `leg` v registri zámerne NIE JE — pravidlo
nôh existuje od v1 (doplnenie podľa `rule_id` ho nezduplikuje) a dve legitímne pravidlá nôh by začali hlásiť ORANGE.

**`LEG_WIDTH_SEED_VERSION` = 6** je pevné číslo (ako `LIFT_SEED_VERSION`) pre migračnú bránu `leg_stale` — ORANGE „skrinka má nohy spočítané ešte pred
pravidlom 4/6" ([outputs.md](outputs.md)). Editor pravidiel: [ui-lifecycle.md](ui-lifecycle.md). Testy: `tests/pure/test_kovg1b_nohy_pravidla.rb`,
`tests/js/test_kovg1b_editor_nohy.js`, in-SketchUp sekcia `run_kovg`.


**KOV-C2b (v0.9.31) — R2 EXKLUZIVITA.** `evaluate(..., suppress_slide_owners:)` dostáva množinu `owner_part_key` čiel, ktoré už majú položku výsuvu **z receptu**, a pravidlá
s `output: 'slide'` sa na nich **nevyhodnocujú** — inak by zásuvka mala dva výsuvy (jeden s kitom, jeden legacy bez dielcov). Potlačenie sa priznáva **jedným** `info`
warningom `legacy_slide_suppressed` na stavbu; Kontrola ho zámerne neukazuje (`Validation::BUILD_INFO_ONLY`) — používateľ nemá čo opravovať. Potlačenie platí aj vtedy,
keď recept skončil **konfliktom** (fail-closed: čelo nedostane ani legacy výsuv).

**KOV-C2b — OSIROTENÝ ručný zásah (Codex #304 P1).** Panel stavia editovateľné riadky Kovania z **emitovaných** položiek, takže záznam `hardware_overrides`, ku ktorému
žiadna položka nevznikla, by nemal kde byť — a používateľ by ho nevedel zrušiť. Pri fail-closed zásuvke je to slepá ulička: `drawer_override_invalid` (ručný počet ≠ 1,
vypnutie) aj `nl_lock_invalid` (zámok mimo radu) položku **nevydajú**, takže exporty ostanú zablokované, kým sa klasifikácia nevráti späť. Preto o osirotenosti rozhoduje
**server**: `HardwareRules.override_orphan_kind(ov, items, conflict_owners)` je čistá funkcia, ktorá vráti `nil` (záznam má svoju položku), **`'disabled'`** (vypnutá
kategória, D-92 — náprava „obnoviť") alebo **`'invalid'`** (vlastník je v uloženom `drawer_conflicts`, teda položka fail-closed nevznikla — náprava **zrušiť celý záznam**,
lebo môže niesť počet aj zámok naraz). `Panel.hardware_overrides_payload` z nej robí `orphan`/`orphan_kind` v payloade, `hardware.js` filtruje **na `orphan`** (staré
pravidlo „len `disabled`" ostáva len ako fallback pre payload bez kľúča) a riadok `invalid` volá **existujúcu** serverovú akciu `reset` — po nej prestavba konflikt
už nevydá. Hlášky konfliktov na túto cestu odkazujú doslovne (`Construction::ORPHAN_HINT`), aby sa text riadku a text nálezu nemohli rozísť.

**Tretí druh: `part_material`.** Do toho istého zoznamu patrí aj **materiálový override dielca zásuvky**, ktorého čelo je v `drawer_conflicts`
(`Panel.orphan_part_material_rows`). Dôvod je ten istý a ešte tvrdší: karta dielca sa dá otvoriť len pre dielec **vo výbere**, ale po fail-closed konflikte ten dielec
**neexistuje** — zlý záznam z uloženého modelu by teda nemal cestu von a exporty by ostali zablokované aj po reopen. Riadok volá vlastnú serverovú akciu
`reset_part_override`, ktorá si osirotenosť **znovu overí** — a to nad **uloženým** configom (`CabinetBuilder.orphan_drawer_part_overrides`: drawer rola · čelo
v `drawer_conflicts`), takže živý override nezmaže nikdy: keď čelo v konflikte nie je, jeho dielce stoja a override sa mení na karte dielca.

**Prečo NIE „part_key nie je v pláne" (Codex #304, in-SU FAIL).** Prvá verzia sa pýtala `plan_parts_by_key`, lenže ten stavia plán **bez** `part_thicknesses`, teda
s UNI 16 fallbackom — a práve ten dielec, ktorého 18 mm override konflikt spôsobil, v takom pláne **vždy existuje**. Riadok sa preto odfiltroval a reset sa odmietol
(headless to neodhalilo, lebo test bol len source-guard). Autorita je uložený `drawer_conflicts`: zapisuje sa v tej istej operácii ako geometria, emisia je per čelo
**atomická**, takže „čelo je v konflikte" znamená „žiadny jeho dielec neexistuje" — presnejšie, než sa dá dopočítať.

**D-93 ručný NL výsuvu:** polia zásahu (`quantity` · `disabled` · `nominal_length`) sú NEZÁVISLÉ (zápis PO POLIACH, `disabled` ostatné polia nezahadzuje), **zámok = existencia poľa
`nominal_length`**; `fit_series` emituje položku aj pri hĺbke pod minimom radu, ak zámok existuje (`rule_nominal_length` = hodnota automatu, nil = nevie) + ORANGE build warning
`hardware_manual_no_fit`; SET validuje presnú zhodu s radom projektového snapshotu, uložená hodnota mimo radu sa NIKDY nemaže. Nákupné CSV bez zmeny — znamienko žije v sekcii Nákup
kovania v Štúdiu (`manual_quantity`/`manual_note`).

**UI od ŠT-3b-1: sekcia `rules` okna ŠTÚDIO** — satelitné okno „Pravidlá kovania" ZANIKLO, serverová autorita ostala v `ui/rules_dialog.rb` (modul sa NEPREMENOVÁVA — vzor audit #21
zo ŠT-2a) s uzavretým whitelistom `SECTION_ACTIONS` — po ŠT-3b-2b je v ňom **päť** akcií (`save_rules · load_global · merge_seed · reset_abs_override · reset_hw_override`; presnú
rovnosť stráži headless sada aj in-SU runner).

**Uloženie = zápis snapshotu + prestavba VŠETKÝCH korpusov v JEDNEJ operácii** (`rebuild_many` s blokom) — jeden krok Späť vráti pravidlá aj geometriu naraz; „aj ako globálnu
predvoľbu" navýše zapíše `%APPDATA%` knižnicu (preferencia, NIE súčasť undo).

**Globálna knižnica pod medziprocesovým zámkom (1d/R-08).** `write` aj seed-merge v `load` bežia pod zdieľaným sidecar zámkom `materials.lock`
(`Materials.with_catalog_lock` — mechanika a dôvody sú v odseku `hardware_sets.rb` nižšie), seed-merge navyše pod ním číta súbor NANOVO a merge prepočíta; `ensure_seeded` má
dvojitý check. `dir` sa od tejto dávky pýta `Materials.dir` — kým si ho modul rátal sám, `test_dir_override` presmeroval zámok do sandboxu, ale zápis ostal v ŽIVOM `%APPDATA%`
(izolovaný in-SketchUp test tak upravoval reálne pravidlá používateľa). **Priznaný zvyšok:** `write(rules)` je ÚPLNÁ NÁHRADA obsahu — okno posiela celé pole a globálna knižnica
nemá revíziu, takže dve súbežne otvorené okná sa nad ňou stále prebíjajú „posledný vyhráva". Zámok ich zápisy serializuje, nič viac; doriešenie vedie
[AUDIT_REGISTER.md](../../SYSTEM/AUDIT_REGISTER.md) ako **R-35**.

**Brána degradovaného súboru (1d/R-11, v0.9.2).** `write` má hneď po zámku `degraded_write_blocked?` — poškodený primár s platnou `.bak` sa číta zo ZÁLOHY, takže zápis by pravidlá prepísal STARŠÍM
obsahom. Odmietnutie je `false` (návratový tvar sa nemení — `[false, dôvod]` by bolo v Ruby pravdivé a ternárky volajúcich by ohlásili úspech) a KONKRÉTNY dôvod si volajúci vezme z
**`HardwareRules.write_block_reason`**: okno Pravidlá ho pri „aj ako globálna predvoľba" ukáže namiesto „globálny zápis zlyhal!". Mechanika a celý kontrakt `JsonFileStore.degraded?` sú v odseku
`hardware_sets.rb` nižšie a v [model-a-identita.md](model-a-identita.md) (`json_file_store.rb`).

**BASELINE guard formulára stojí na `model.guid`** (ŠT-3b-1; predtým `model.path`, ktorý dva NEULOŽENÉ modely nerozlíši — oba majú prázdny path) **+ zhoda aktuálnych pravidiel
modelu s baseline** (chytí undo snapshotu aj súbežnú zmenu inou cestou); baseline sa obnovuje pri KAžDOM zostavení payloadu. Odmietnutý zápis NIC nezapíše; **od ŠT-3b-2c1 sa
formulár načíta nanovo LACNÝM ECHOM sekcie** (`push_section_echo(force: true)`), nie plným `bump: false` pushom. *(Pôvodný dôvod — plný push deduplikoval ID kópií, takže odmietnutie
model ZMENILO — od 1b-3 už neplatí: zber je čisté čítanie. Echo ostáva, lebo je lacné a nezdvíha generáciu okna.)*

**NO-OP „Doplniť nové predvolené" nerobí ŽiADEN push** (lekcia F8 zo ŠT-3a-2).

**ŠT-3b-2a (čítanie):** sekcia má aj druhú skupinu Š17 — **ABS podľa roly dielca** (nad kovaním, podľa mockupu) a pod OBOMA skupinami **jantárové riadky ručných zásahov**
(`overrides` v payloade). Riadok znamená „**tu rozhodol človek**", nie „je to zle": žiadna ⚠, žiadny vstup do počtov Kontroly (stavy olepu hlási EdgeCheck/Kontrola) — len chip
„override" + **oko** (výber v modeli). Zdroj ABS overridu je **PRÍTOMNOSŤ kľúča `edges` v `part_overrides[part_key]` configu KORPUSU** (nikdy vyriešený snapshot na entite dielca —
ten ho má vždy); dosky sú mimo (`board_builder` mapu hrán vždy doresolvuje, prítomnosť nič nehovorí). Zber ide v jednom prechode `Bom.collect` (`manual_overrides`, vlastný `rescue`
— nesmie zhodiť formulár), riadky sú **zoskupené po skrinkách so stropom** `MAX_OVERRIDE_ROWS` a súhrnom.

**Štyri pravidlá riadku, ktoré ustálila 1b-4:**
- **PORADIE JE DETERMINISTICKÉ a RADÍ SA PRED STROPOM** (`sort_override_rows`: skrinka → dielec → položka, posledný kľúč je poradové číslo, lebo `sort_by` v Ruby nie je stabilné).
  Dovtedy sa riadky brali v poradí entít v modeli, takže vloženie či zmazanie hocijakej skrinky zoznam preskladalo — a pri viac než `MAX_OVERRIDE_ROWS` zásahoch aj **vymenilo,
  ktoré riadky ešte vidno**. Číslo v identite (`CAB-1000` vs. `CAB-999`) sa radí ako číslo. Radenie **nededuplikuje**: dva riadky s rovnakou identitou ostávajú dva (zdvojenie pri
  duplicitnej identite je samostatný kandidát registra, KRONIKA 1b-3).
- **`disabled` VÍŤAZÍ, takže riadok vypisuje víťaza** (`hw_override_bits`). Polia záznamu sú nezávislé (D-93), ale neplatia naraz: `HardwareRules.apply_overrides` položku pri
  `disabled` zahodí (`next nil`) ešte PRED prepisom počtu aj dĺžky, takže „vypnuté · počet 6 ks" tvrdilo, že sa niečo počíta. Uložené, ale neuplatnené polia sa **nezamlčujú** —
  priznajú sa v zátvorke („uložený počet sa neuplatní"), lebo šípka „vrátiť na pravidlo" zruší aj ich.
- **Katalóg ABS pások sa stavia LENIVO:** `ProductionCore.edges_map` (celý `Materials.edges` do mapy) slúži VÝHRADNE na preklad `abs_id` → názov pásky v ABS riadkoch, takže sa
  volá až keď taký riadok existuje — bez ručných hrán zákazka za mapu neplatí. *(Duplicitu s `control_payload`/`budget_payload`/`edges_meta` to neodstraňuje — tie mapu potrebujú
  vždy a zdieľanie jednej inštancie naprieč celým pushom je zásah do kontraktu výstupov, teda vlastná dávka.)*
- **Záznam nesie PRESNE to, z čoho sa riadok kreslí.** `material_id` a `pid` v ABS zázname boli mŕtve polia: riadok hovorí o rozhodnutí človeka (nie o materiáli) a adresa „oka" je
  zámerne IDENTITA (`owner_id` + `part_key`), nikdy persistent_id — „žiadne pids z DOM" (`rdSelectOverride`). Pole, ktoré nikto nečíta, zvádza budúci kód postaviť sa naň.

**ŠT-3b-2b — „VRÁTIŤ NA PRAVIDLO" (zápis):** šípka v jantárovom riadku zahodí ručné rozhodnutie a nechá platiť pravidlo; potvrdenie sa NEPÝTA (poistkou je JEDEN krok Späť, kontrakt
mockupu). Akcie `reset_abs_override` · `reset_hw_override` sú v uzavretom `SECTION_ACTIONS` (presnú rovnosť stráži aj in-SU runner).

**Adresa je IDENTITA, nie výber v modeli** (cabinet_id + part_key, pri kovaní + generic_type/rule_id) — cesty Inspectora stoja na označení a po zápise ho prepíšu, čo je pre zoznam
v okne nepoužiteľné; **výber sa preto NEMENÍ** (žiadny reselect) a ak ho prestavba zhodí, prizná to status.

**Guardy pred zápisom** (`reset_context`, jedno miesto pre obe akcie): generácia okna (klik zo zastaraného zoznamu), `model_guid` (tolerantne na prázdny údaj), a **NEJEDNOZNAČNÉ
`cabinet_id` = ODMIETNUTIE** — čerstvá kópia má do dedup tiku to isté id, „vezmi prvú" by prestavala skrinku, na ktorú nikto neklikol, a spustiť dedup tu by otvorilo DRUHÚ operáciu
(z jedného kliku dva kroky Späť).

**Zápis = `rebuild_many(model, [[cab, params]])` = jeden krok Späť** (override aj geometria), po ňom `Panel.push_selected` + `refresh_studio(bump: true)` (vzor 3b-1).

**JEDNO TELO ZÁPISU** (audit B4): ABS ide cez `Panel.reset_part_edges!` (zmazanie `edges` + `edge_warnings` + `store_override`), ktoré volá aj „Použiť na podobné" s prázdnym
zdrojom; kovanie cez `Panel.merge_override(..., :all, nil)`, teda tú istú mutáciu ako reset v Inspectore — zdieľa sa TELO, nie okenné guardy (tie sú per vstupný bod).

**Status hovorí VÝSLEDOK** (F13): číta SNAPSHOT po prestavbe („podľa pravidla: predná 1,0 mm" / „podľa pravidla bez olepu" pri suppression/UNI; pri kovaní počet z pravidla, resp.
„nepočíta nič"), plus dôsledky, ktoré z riadku nevidno — zrušenie „vypnuté" **vracia položku do nákupu (mení cenu)** a zámok dĺžky **mimo dnešného radu sa stratí nenávratne**.

**ŠT-3b-2c1 — BRÁNA TVARU PRAVIDIEL PRI ULOŽENÍ:** čistá `HardwareRules.rules_problems(rules)` (bez IO) sa volá **výhradne** v `handle_save`, **až PO `normalize_rules`** (validuje
sa presne to, čo sa zapíše). Vynucuje sa: `kind == 'bands'` so `enabled != false` ⇒ neprázdne pásma a medzi nimi **pásmo „všetko nad"** (`max: null`); `kind == 'fit_series'` ⇒
neprázdny rad `series`; **KOV-F1 (Codex #329 kolo 3 P2):** `bands` so `finite: true` navyše potrebuje **aspoň jedno ČÍSELNÉ pásmo** — konečná tabuľka,
v ktorej ostal len catch-all, nie je tabuľka (catch-all by dal svoj počet každému čelu a každé by zároveň bolo „mimo tabuľky"); **KOV-F2 (v0.9.51):** keď pravidlo
nesie `weight_bands`, musí to byť **použiteľná tabuľka** — neprázdna (`weight_bands_problem`), každé pásmo s **kilogramami > 0** a **žiadne dve pásma s rovnakou
hmotnosťou** (druhé by bolo mŕtve). **Codex #330 (v0.9.52):** kľúč `weight_bands` sa pritom normalizuje **v každom tvare**, nie len keď je poľom — hash, reťazec či číslo
z pokazeného alebo cudzieho snapshotu sa mení na **prázdne pole**, aby editor v paneli vždy dostal tabuľku a nie tvar, nad ktorým padne (viď [ui-lifecycle.md](ui-lifecycle.md));
použiteľné pásmo tým nezaniká (pásma sú Hash v poli) a prázdnu tabuľku brána ďalej **odmieta**, takže nezmysel v modeli ticho neostane. Tri kritériá vyššie sú práve tie tvary,
ktoré `normalize_rules` **nechá tak**: poradie zoraďuje sama (neusporiadané pásma teda **nie sú
chyba používateľa**) a pásmo s neplatným počtom **zahodí** — keď vypadnú všetky, chytí to vetva „prázdne". Neplatný `width_plus`/`width_warn_over` sa do brány
nikdy nedostane (normalizácia ho zahodí — kontrakt F1 „radšej žiadny guard než hádanie"), takže do modelu sa nezmysel nedostane ani bez vety; editor taký tvar
navyše **ani neposiela** (prázdne alebo nekladné pole = kontrola vypnutá, chýbajúci počet = 1 — viď [ui-lifecycle.md](ui-lifecycle.md)). Kritérium visí na
**`kind`, nie na prítomnosti kľúča `bands`** — `kind` je jediná autorita toho, ktorá vetva vyhodnotenia sa spustí, a `normalize_rules`
neznáme kľúče zachováva, takže záznam smie niesť oba kľúče naraz (novšia verzia formátu, cudzí či legacy snapshot, zvyšok po zmene `kind` vo formulári) a validovať mu treba len to,
čo sa naozaj použije; vypnuté pravidlo sa nekontroluje a neznámy `kind` z novšej verzie uloženie neblokuje.

**Do `normalize_rules` validácia NEPATRÍ** — má dvanásť volajúcich a väčšina z nich číta, takže by legacy snapshot z .skp pri čítaní ticho orezala; `ensure_project_rules!` ani
`merge_project_seed!` ju tiež nevolajú (builder nesmie odmietnuť stavbu). Legacy deravý snapshot sa teda **číta a stavia**, len sa nedá znova uložiť bez opravy — hláška preto
**adresuje konkrétne pravidlo** menom (používateľ meniaci iné pravidlo narazí na cudzí riadok; priznané). Nekompletný tvar **nie je tichý** (kusovník hlási `hardware_rule_skipped`,
Kontrola ORANGE) — brána existuje preto, že odmietnuť ho raz pri uložení je lacnejšie než ORANGE na každej skrinke. Klientska `rdValidate` je zrkadlo tých istých kritérií, paritu
stráži spoločná fixtúra `tests/fixtures/rules_validation_parity.json` (číta ju Ruby aj JS sada).

**Odmietnutý SAVE** (baseline vetva) ide na `push_section_echo(force: true)` — bez dedupu, ale s **vynúteným** prekreslením formulára a omladením odtlačku; je to jediná vetva, kde
sa rozpísané hodnoty vedome strácajú (guid-mismatch vetva ostáva na plnom pushi, lebo prepnutý dokument je cudzí pre všetky sekcie okna).

**ŠT-3b-2c2 — ODTLAČOK PRAVIDIEL (`rules_rev`):** payload sekcie nesie krátky hash normalizovaných pravidiel (`HardwareRules.rules_rev` = SHA1 kanonického JSON, 12 znakov — vzor
`HardwareCatalog.record_rev`), klient ho **iba drží a pri uložení vracia**. Vlastný výpočet na klientovi je vylúčený z princípu: Ruby serializuje `900.0`, JS `900`, takže bajtové
porovnanie by nikdy nesedelo. Odtlačok sa počíta **LEN z `rules`** — nie z celého payloadu; inak by „zožltol" pri každom ručnom zásahu v Inspectore (menia sa `overrides`, nie
pravidlá) a používateľ by nemohol uložiť pravidlá len preto, že si medzitým prestavil hranu.

Serializácia je **kanonická** (kľúče rekurzívne zoradené podľa PRÍTOMNOSTI kľúča — nie cez `||`, to by zhltlo `false` a `null` by dalo ten istý odtlačok; poradie polí zachované) —
poradie kľúčov je náhodný dôsledok toho, odkiaľ záznam prišiel, a bez zoradenia by ten istý stav dal iný odtlačok.

**Je to DRUHÁ vrstva popri `@baseline_rules`, nie náhrada:** porovnanie obsahu je hashové (necitlivé na poradie pravidiel a na kľúče, ktoré normalizácia zjednotí), odtlačok je
citlivý na serializovaný tvar; baseline sa pýta prvý.

**Prázdny odtlačok sa NETOLERUJE, keď server odtlačok už vydal** (review #224, Codex P2 — vedomá odchýlka od pôvodného zadania): premisa „baseline tú vetvu kryje" neplatí, lebo
`@baseline_*` je stav MODULU, nie klienta — každý push ho posunie na aktuálny stav modelu, takže starší cachovaný DOM by cez `baseline_valid?` prešiel a prepísal novšie pravidlá
svojím starým formulárom. Odmietnutie je pritom samoliečivé (echo nesie čerstvý odtlačok, druhý klik prejde); DOM z predošlej verzie prijímač echa nemá, preto mu hláška hovorí
zavrieť a otvoriť Štúdio. Tolerancia ostáva len na stav, kým server žiadny odtlačok nevydal.

**„Načítať globálne" odtlačok NEPREPISUJE:** globálne predvoľby nie sú stav projektu, takže uloženie po nich by serveru tvrdilo, že formulár vznikol z aktuálnych pravidiel — a
prepísalo by cudziu zmenu.

**Konflikt = `push_section_echo(force: true)`** (formulár sa prekreslí, `RD_SEED` aj odtlačok omladnú) a **druhé znenie statusu pri opakovanom konflikte** (`@rev_conflicts`, nuluje
ho úspešné uloženie) — rovnaká veta druhýkrát by používateľa nechala točiť sa dokola.

**Audit B4:** `rules_payload` obnovuje baseline aj odtlačok **až na konci úspešného zostavenia**; keby ich posunul pred telom, `rescue → nil` by roztvorilo nožnice (server nový
stav, klient starý ⇒ večné odmietanie), preto `rescue` vetva baseline nemení. Schéma .skp sa nemení a žiadna migrácia nie je — odtlačok žije len v payloade okna.

**Dva vedomé zostatky z ŠT-3b-2c2:** (1) guid-mismatch repush ide cez `refresh_studio` → `fresh_collect` — **a to je od 1b-3 (stabilizačná revízia, brána G) neškodné: zber už dedup
nespúšťa, takže plný push okna model nemení.** Zostatok tým zanikol. (2) Echo obnoví LEN sekciu pravidiel — ostatné sekcie po konflikte ostávajú na svojich číslach; sú však stále platné (nič sa nezapísalo) a keby ich zmenila iná cesta, tá
po sebe pushne sama, prípadne to prizná jantárové „Obnoviť".

**F14:** existencia odpojeného dvojčaťa sa prizná statusom (prestavba ho neprekreslí — do výstupu ide po starom), nikdy tichý úspech; identita dvojčaťa ide **cez `twin_identity`
(part_key → legacy role_key → part_id bez prefixu skrinky)**, nie cez surový `part_key` — inak by sa legacy dielec neprizná.

**ODMIETNUTIE NESIAHA NA MODEL (review #222):** repush odmietnutého kliku ide **lacným echom sekcie** (`push_section_echo` → `Bom.collect` → `RD.setSection`), NIE plným pushom okna.
*Historicky to bola otázka správnosti — plný push šiel cez `fresh_collect` a ten cez `dedup_copies`, takže odmietnutý klik prečísloval ID kópií a pridal krok Späť presne v scenári,
kde hláška tvrdí opak. Od 1b-3 je čítacia cesta čistá, takže ostáva len dôvod ceny: prepočítavať celý kusovník a rozpočet za klik, ktorý nič nezmenil, je zbytočné.* Texty statusov skladajú ČISTÉ funkcie `abs_result_text` / `hw_result_text` (fixtúrami merateľné; zhoda vlastníka pri kovaní je `present_str`-semantika ako `ov_match?`).

**Obmedzenie priznané v #222 je od 1b-3 VYRIEŠENÉ:** refresh po zápise už cez `dedup_copies` nejde, takže iná neupratná kópia v dokumente nemôže vložiť svoje prečíslovanie NAD náš
commit — prvé Ctrl+Z vracia reset, presne ako status sľubuje. `Panel.push_selected` si dedup naďalej **vyžiada** u observera (`request_dedup`) a ten ho urobí **transparentne**, takže
samostatný vrchol undo stacku z neho nevznikne.

### hardware_catalog.rb

katalóg kovania (V0.6 dávka C): položky s kódmi a cenami s DPH, serverové vyhľadávanie (JS len renderuje vrátené poradie), `row_rev` guard riadku, **„no silent caps" (TEST-1)** —
`search_with_total` vracia okrem stránky aj POČET zhôd, takže orezanie sa dá priznať číslom; ZOZNAM (prázdny dotaz bez kategórie) má vyšší strop `EMPTY_TOP` než hľadanie
(`SEARCH_TOP`) a hint o orezaní sa vypisuje pri KAŽDOM orezaní.

**`pin`** = kód práve založenej položky: klient ho pošle, **server** ju zaradí navrch (kontrakt „JS poradie nikdy nedopĺňa" ostáva) a klient ju len vizuálne zvýrazní.

**Žiadosť je JEDNORAZOVÁ** (review #229): `MDH_PIN_REQ` spotrebuje najbližší dotaz a hneď sa zabudne, kým `MDH_PIN` je to, čo server POTVRDIL pre práve vykreslený zoznam — bez toho
by sa pin posielal pri každom ďalšom hľadaní a nesúvisiaci dotaz (iný text, iná kategória, prepnuté neaktívne) by novú položku ďalej ťahal navrch a zvýrazňoval až do znovuotvorenia
okna — bez toho nová položka (`use_count` 0) prepadla za strop a z UI zmizla bez slova, cenový návrh z Demosu s `pid` (JS hodnoty NIKDY neposiela) a stav katalógu `ok`/`read_only`.

**Strom Kategória → Výrobca → Rada (KOV-B2, v0.9.23) — `build_tree`.** Pohľad Položky v Štúdiu už neposiela `hw_search`, ale **`hw_tree`**: server skladá CELÉ zoskupenie
aj poradie (kontrakt „JS poradie nikdy nedopĺňa" platí na každej úrovni) a klient kreslí presne to, čo dostal. Dôvod je D-110: plochý zoznam s tichým stropom znamenal, že
položka za poradím `SEARCH_TOP` sa dala nájsť už LEN hľadaním.

- **Kľúč uzla je CESTA** `KATEGÓRIA|Výrobca|Rada` (kategória = sám kód). Klient ňou pýta rozbalenie (`expand`) a ďalšiu stránku listu (`more`); odpoveď je
  `{ q, gen, groups[], total, shown, pin, leaf_page }`, kde `groups[] = { key, label, open, total, shown, manufacturers[{ key, label, total, shown, series[{ key, label, total, shown, codes[], more }] }] }`.
- **„Žiadne tiché stropy" na KAŽDEJ úrovni:** `total` = koľko ich tam je, `shown` = koľko ich naozaj prišlo. Stránkuje sa **LIST (rada)**, nie celý strom — najviac `LEAF_PAGE`
  (50) kódov a orezaný list to prizná `more: true`. **Zbalená kategória neposiela kódy vôbec** (`shown` 0), ale `total` nesie ďalej — inak by hlavička mlčala o tom, čo v nej je.
- **Poradie:** kategórie v poradí `CATEGORIES`; výrobcovia abecedne bez diakritiky, zberná značka „Ostatné" predposledná a **položky BEZ výrobcu úplne posledné** (`— bez výrobcu`);
  rady abecedne, `— bez rady` posledná. V liste platí poradie `score_item` (pri dotaze) alebo **podľa názvu** (prázdny dotaz) — nie `use_count`, ktorý v strome nič nehovorí.
- **Filter kategórie používa TÚ ISTÚ mapu ako strom** (`tree_category_of`, review #290/2 P2) — nie doslovné porovnanie uloženej hodnoty. Položka s neznámou kategóriou (staršie
  alebo cudzie zápisy, ktoré čítacia cesta zámerne drží čitateľné) sa v strome ukazuje pod „Ostatné"; keby filter porovnával doslovne, po zapnutí filtra „Ostatné" by **zmizla** —
  a to je práve tá položka, ktorú človek filtrovaním hľadá.
- **Hľadanie roztvára LEN zhody:** pri neprázdnom `q` sa vracajú iba skupiny so zhodami a majú `open: true`; pri prázdnom platí `expand` klienta. Klient si serverové rozbalenie
  zapamätá **iba pri prázdnom dotaze** — inak by jedno hľadanie roztvorilo katalóg natrvalo.
- **`pin` je v odpovedi VŽDY** (aj keď filtru nevyhovuje), **navrchu SVOJHO listu** a jeho kategória je rozbalená; `gen` sa iba ECHUJE (hľadanie je debounced, pomalšie kolo
  nesmie prepísať čerstvejší strom). `hw_search` a jeho prijímač `MDH.results` **ostávajú** ako verejný kontrakt katalógu.
- **`CATEGORY_LABELS`** je JEDINÝ zdroj SK popiskov kategórií (strom, filter v lište, select v modale aj `state_payload`); kód ostáva identitou a neznámy kód sa NEPREKLADÁ.
  Guard test stráži, že mapa pokrýva `CATEGORIES` presne.

**Výsledok zápisu pre modal.** `MDH.itemResult(ok, msg, errors, op, token)` — `token` je identita JEDNÉHO odoslania: klient ho posiela v payloade `hw_create`/`hw_patch`/
`hw_demos_create`, server ho iba **echuje** a klient prijme len presnú zhodu (review #290 P2 — inak odpoveď zavretého okna zavrela okno otvorené teraz). Patch z inline bunky
riadku (`from` != `'modal'`) žiadny `itemResult` nedostáva. **Pole chyby sa prekladá** na kľúč modalu (`item_code`→`code`, `name_sk`→`name`, `price_eur_vat`→`price`,
`demos_url`→`demos`; zvyšok 1:1) — inak by `NXModal.showErrors` vstup nenašiel a bežné odmietnutia by pristáli v zbernom páse bez označeného poľa (review #290/3 P2).

**Stav taxonómie v payloade** nesie DVA nezávislé príznaky: `read_only` (obsah sa nedá čítať — modal klasifikáciu **zamkne**) a `write_blocked` (obsah sa číta, ale zapísať sa
nedá — modal skryje len „+ Vytvoriť…"). Degradovaná taxonómia je práve ten druhý stav a bez neho by UI ponúkalo akciu, ktorá vždy skončí `:write_failed`.

**Štruktúrované chyby (KOV-B2).** `normalize_item`, `create_item`, `patch_item` aj `taxonomy_refusal` vracajú TRETÍM prvkom **pole**, ktorého sa odmietnutie týka (`item_code`,
`name_sk`, `price_eur_vat`, `unit`, `category`, `manufacturer`, `series`) — modal D-15 ju kreslí PRI POLI a bez toho by „rada nepatrí výrobcovi" pristála v zbernom páse nad
formulárom. Tvar je spätne kompatibilný: volajúci, ktorý pole nepotrebuje, ďalej rozbaľuje len `status, info`.

**Démos → výrobca (KOV-B2).** Proposal z `demos_preview!` nesie navyše **`manufacturer_guess`** = značka stránky (`itemprop="brand"`) preložená cez `HardwareTaxonomy
.resolve_classification` na KANONICKÉ meno; neznáma značka aj nekompatibilná taxonómia = `nil` (fail-closed — návrh, ktorý by sa nedal uložiť, sa nedáva). **Radu neháda
nikto** — inferencia z breadcrumbu je mimo V1. `create_from_demos!` prijíma `manufacturer:`/`series:` a overuje ich rovnako ako `create_item`, kým **kód, názov, cena a MJ
pochádzajú VŽDY z proposalu** (FIX 12 z KOV-H1). Keď používateľ niektorý z nich v modale prepíše, **nie je to už overená položka**: klient ju posiela bežným `hw_create`, teda
BEZ `demos_url` aj BEZ `price_checked_at` (tie `create_item` z klientskych atribútov aj tak zahadzuje).

**Katalóg je GLOBÁLNY** (`%APPDATA%`), takže nezávisí od dokumentu — zákazky sa dotýka až cez sety (`hardware_sets`, projektový snapshot na modeli).

**Od ŠT-3a-2 ho ukazuje JEDINÉ UI:** sekcia `hw` okna Štúdio (Š16 — pohľady Položky · Sety). Okno „Katalóg kovania" ZANIKLO; serverová autorita ostala v
`hardware_catalog_dialog.rb` (modul sa NEPREMENOVÁVA — vzor audit #21 zo ŠT-2a), a to vrátane **troch MODELOVÝCH zápisov** predvolieb setov projektu (`hws_map_project` ·
`hws_merge_seed` · `hws_reset_project`), ktoré sú od tejto dávky v `SECTION_ACTIONS`. Každý z nich je `start_operation` … `commit_operation` (**1 zmena = 1 krok Späť**) a každý má
serverový `model_guid` guard — zápis zo zastaraného UI sa odmietne a stav sa obnoví (`resync_sets`).

**Výrobca a rada položky (KOV-B1, v0.9.19).** Položka nesie VOLITEĽNÉ `manufacturer` a `series` — kanonické názvy z `hardware_taxonomy.rb` (nie id: názov cestuje medzi PC bez
joinu). Obe sú v `PATCHABLE`, prirodzene cestujú v `record_rev` a **hľadanie ich tokenizuje** (`score_item` — dotaz „hettich" či „atira" položku nájde; bez toho by mal strom
KOV-B2 filter, ktorý sa hľadaním nedá zopakovať). Skrutky ani podperky výrobcu mať nemusia — prázdna hodnota znamená, že kľúč **sa neuloží**.

Tri veci, ktoré k tomu patria:

- **`SCHEMA_CURRENT` je 2, ale marker je LAZY podľa OBSAHU** (`schema_for`, vzor `HardwareSets.snapshot_std` a materiálov): katalóg BEZ výrobcov sa stampuje `1` a staršie verzie
  ho čítajú ďalej; akonáhle má ktorákoľvek položka výrobcu alebo radu, stampuje sa `2` a starší plugin ho odmietne ako read-only („aktualizuj plugin"), NIKDY ticho neoreže.
  Spätná čitateľnosť sa teda blokuje len tam, kde je čo stratiť.
- **Ne-String hodnota = nečitateľné položky.** `valid_stored_item?` vyžaduje String (alebo chýbajúci kľúč) — novšia verzia môže dať `manufacturer` iný TVAR (objekt s id
  a názvom) a naše čítanie by ho ticho zmenilo na nezmyselný reťazec. `assess!` z toho urobí `:read_only`.
- **Členstvo v taxonómii sa overuje pri `create_item` aj `patch_item`** nad EFEKTÍVNOU dvojicou (patch prebíja uložené): neprázdny výrobca musí v zozname existovať a rada mu musí
  patriť, inak `[:invalid, dôvod]`; nekompatibilná taxonómia je fail-closed (položka s výrobcom sa neuloží, položka bez neho prejde). Kontrola beží **ZÁMERNE MIMO katalógového
  zámku** — taxonómia má vlastný sidecar (`materials.lock`) a vnoriť ho do katalógového by vyrobilo PORADIE zámkov, teda presne to riziko, kvôli ktorému majú katalógy jeden
  spoločný sidecar. Stráži to zdrojový guard v `tests/pure/test_hardware_catalog.rb`.

**SEED v3 — dáta z Démosu (D-118, v0.9.43).** Manifest `SEED_ROWS` má odteraz **deväť polí**
(`[kód, názov, kategória, MJ, cena|nil, poznámka|nil, výrobca|nil, rada|nil, demos_url|nil]`) a **114 riadkov**: pôvodných 60 z D1 + **54 kódov, ktoré používajú seed sety
zásuviek** (vrátane PTOs modulov `352908`/`352909` a opravenej antracitovej K-sady `357889`). Každý riadok je overený proti PRODUKTOVEJ STRÁNKE demos-trade.sk (7.9.2026):
kód sa našiel ako „Kód sortimentu", názov je H1 stránky a cena je hodnota **s DPH** — čítal ich TEN ISTÝ `DemosProductParser`, akým beží „Overiť cenu", preto je
`SEED_PRICE_CHECKED_AT` legitímny server stamp a dostáva ho **len riadok, ktorý má cenu AJ `demos_url`** (F5 „dátum patrí konkrétnej väzbe"). **Kategória ostáva NAŠA**
(93240 „Bystrica" = `SPOJOVACI_MATERIAL`, hoci Démos ju vedie pod závesmi — debata 2.8.); z webu je názov, cena, MJ, výrobca, rada a URL. `SEED_INACTIVE` = štyri kódy, ktoré
Démos už nepozná: riadok **ostáva** (staré zákazky ho majú v nákupe), len je `active: false` s dôvodom v poznámke.

**Migrácia v2 → v3** (`apply_seed_patch_v3`, `SEED_SET_VERSION` 3) drží dva kontrakty z patchu v1 → v2:

- **Plný seed sa do existujúceho katalógu NELEJE** — dopĺňa sa LEN vymenovaný `SEED_PATCH_V3_ADD` (tých 54). Kto si seed položku zmazal, nedostane späť nič iné.
- **Prepísať existujúci riadok sa smie len vtedy, keď je preukázateľne NÁŠ:** všetky `SEED_MATCH_FIELDS` sedia s `SEED_ROWS_V2` (zmrazená kópia v2 manifestu) **a** riadok nemá
  vlastnú Démos väzbu **a** nemá vlastnú klasifikáciu (`manufacturer`/`series` — tie v `SEED_MATCH_FIELDS` nie sú, takže bez tejto podmienky by patch prepísal výrobcu, ktorého
  tam dal používateľ; Astra #21 BLOCKER 1). Zápis je `cur.merge(rec)`, takže `use_count` aj ručne VYPNUTÁ aktívnosť prežijú a položka sa nikdy nezapne späť.

Dôsledok, ktorý patrí do poznámok k vydaniu: katalóg bez klasifikácie sa doplnením výrobcov stampuje na `SCHEMA_CLASSIFIED`, teda **starší plugin ho odteraz číta ako read-only**
(„aktualizuj plugin") — nikdy ticho neoreže.

**SEED v4 — VÝKLOPY AVENTOS (KOV-E1a, v0.9.53).** Manifest má **137 riadkov**: k v3 pribudlo **23 kódov Blum AVENTOS** zo `SYSTEM/zdroje/demos/SEED_AVENTOS_v2_2026-09-09.md`
(HK top mechanizmy `22K2x00` a `22K2x00T`, krytky HK `22K8000` v troch farbách, Tip-On jednotky 76 mm šedá a čierna, HL top mechanizmy `22L2x00`, ramená `22L3x00`,
stabilizačná tyč `22Q1076U`, predlžovací diel `22Q080Z` a krytky HL `22.8000`). Kategória je `VYKLOPY`, výrobca `Blum`, rada `AVENTOS` (Tip-On jednotky `TIP-ON`) a poznámka
nesie rozsah, podľa ktorého sa trieda vyberá (`LF 420–1610`, `KH 300–339 · 1,5–9 kg vrát. úchytky`). **Ceny sú s DPH zo zberu 9.9.2026 cez Démos LBX API**, preto tieto riadky
nesú **vlastný** `SEED_PRICE_CHECKED_AT_V4` — spoločný stamp by starším 60 riadkom prepísal ich skutočný dátum overenia (7.9.), a dátum patrí konkrétnej väzbe.

**Migrácia v3 → v4** (`apply_seed_patch_v4`, `SEED_SET_VERSION` 4) je LEN DOPĹŇAJÚCA: neosviežuje ani jeden existujúci riadok. Kódy `347827`, `13781` a `250831` v katalógu už
boli, takže sa ich dávka **nedotkla** (vrátane toho, že `250831` ostáva v kategórii `ZAVESY` — je to tá istá Tip-On jednotka ako pri závesoch). Kto si niektorý z 23 kódov
medzitým založil sám, ostáva mu jeho vlastný záznam.

**SEED v5 — NOHY 17–220 mm a PRVÝ CUDZÍ DODÁVATEĽ (KOV-G1a, v0.9.58).** Manifest má **146 riadkov**: k v4 pribudlo **9 kódov nôh a príchytu sokla** (rozhodnutia Michal
9.9.2026) — `272212` STRONG klzák 17 mm šedý z Démosu a **osem Häfele AXILO od QUATRO LM** (nohy H60/H100/H125/H150/H180/H200, platnička `9079`, príchyt sokla `950`).
Riadok `367823` (noha AXILO 150 z Démosu) dostal v manifeste **výrobcu Häfele a radu AXILO**. **Manifest má preto DESIATY prvok — dodávateľa** (`nil` = `Demos`, historická
predvoľba všetkých 137 riadkov); `supplier` je existujúce pole položky (patchovateľné, chodí do rozpočtu ako „dodávateľ"), nie nové pole katalógu.

**Quatro LM riadky NEMAJÚ `demos_url`, a preto ani `price_checked_at`.** Nie je to opomenutie: `Demos.sanitize_url` má allowlist hostov, takže adresu z `quatrolm.sk` by
„Overiť cenu" odmietla — a `check_price!` položku bez väzby končí vetou „položka nemá adresu produktu". Cena sa pri nich obnovuje **ručne** a **adresa dodávateľa žije
v POZNÁMKE riadku** v tvare `… · Quatro LM · https://quatrolm.sk/p/…` (poznámka je viditeľná v katalógu aj v hľadaní — `score_item` ju tokenizuje). Ceny sú **s DPH**
(Quatro LM zobrazuje bez DPH: 0,65 → 0,80), overené 9.9.2026.

**Migrácia v4 → v5** (`apply_seed_patch_v5`, `SEED_SET_VERSION` 5) má tri kroky a každý vlastnú, úzku podmienku „ruky preč od používateľskej úpravy": **(1) add-if-absent**
deviatich kódov (`SEED_PATCH_V5_ADD`) — kto si niektorý založil sám, ostáva mu jeho záznam, a kto si seed položku zmazal, nedostane späť nič iné; **(2) enrichment riadku
`367823`** o výrobcu a radu, ale **LEN keď sú OBE prázdne** (vzor v3, Astra #21 BLOCKER 1) — nič iné na riadku sa nemení (názov, cena, `use_count`, ručne vypnutá aktívnosť);
**(3) oprava dvojice `Hettich`+`AXILO`** na `Häfele`+`AXILO`. Tretí krok je náprava nekonzistencie, ktorú spôsobila NAŠA zmena: radu AXILO presunula spod Hettichu migrácia
taxonómie, takže položka s tou dvojicou by v modáli už neprešla („rada nepatrí výrobcovi") a v selecte rád by sa pod Hettichom AXILO ani neponúkla. Mení sa **výhradne
výrobca** a **výhradne pri presnej zhode oboch mien** (`HardwareTaxonomy.same_name?`); zo stromu katalógu položka **nezmizne ani bez opravy** (strom zoskupuje podľa reťazcov
NA POLOŽKE, nie podľa taxonómie) — opraviteľnosť je jediný dôvod kroku. **Vlastníka rady dáva ŽIVÁ taxonómia, nikdy resolvnutý seed** (Codex #337 N2,
`HardwareTaxonomy.series_owner` — číta uložený súbor BEZ seedovania a bez zápisu): keď má používateľ AXILO naviazané na vlastného výrobcu, migrácia taxonómie mu to zámerne
nechá, ale seed riadok `367823` sa vtedy resolvne na „Häfele BEZ rady" — a odvodiť z toho vlastníka by znamenalo prepísať jeho položky na dvojicu, ktorá v jeho taxonómii
NEEXISTUJE. Krok 3 preto beží **len keď taxonómia naozaj hovorí „AXILO patrí Häfele"**, a zapisuje jej ULOŽENÝ zápis mena (JS filtruje presným reťazcom); pri cudzej väzbe
alebo pri ešte nezaloženej taxonómii sa nevykoná vôbec.

### hardware_taxonomy.rb

**Jediný zoznam prípustných výrobcov a rád kovania (KOV-B1, v0.9.19; audit #17 BLOCKER 4).** Set aj položka katalógu nesú `manufacturer`/`series` ako reťazec — keby si ho každý
písal sám, vznikla by za mesiac zbierka „Hettich" / „hettich" / „Hettch" a strom katalógu (KOV-B2) ani filtre (KOV-D) by na nich nesadli. Súbor
`%APPDATA%\NOXUN\Engine\hardware_taxonomy.json` = `{ std, schema, seed_version, manufacturers[], series[] }` (+ `.bak`), teda **globálny** — kontrakt je preto rovnaký ako
u knižnice setov (R-07/R-08/R-11) a katalógu (GH #99).

- **Identita mena je `Materials.slug`** — case-insensitive a bez diakritiky („Hettich" == „hettich" == „HETTICH"). `name` je KANONICKÝ zobrazovaný tvar (prvé zapísané znenie)
  a práve on sa ukladá do setov a položiek.
- **Rada patrí PRESNE JEDNÉMU výrobcovi**, takže slug rady je **globálne unikátny** — inak by sa z uloženého reťazca „Sensys" nedalo zistiť, či je to Hettich alebo Blum.
  V súbore je to invariant brány: ten istý slug dvakrát = `:duplicate`, rada bez existujúceho výrobcu = `:unknown_shape`.
- **Matica stavov** (vzor `HardwareSets`): `:ok` · `:degraded` (poškodený primár + platná `.bak` — číta sa, do SÚBORU sa nezapisuje) · `:read_only` (cudzí `std`, novšia `schema`,
  neznámy tvar, duplicita). Čistá `assess_doc(doc)` je bez IO a **fail-closed** (výnimka = `:unexpected_shape` s hláškou „súbor NEMAŽ, nahlás"); `assess` nad ňou dopĺňa degraded.
  Stav sa **NECACHUJE** (`state` ho vyhodnocuje pri každom použití), `state_code`/`state_reason` sú výsledok poslednej kontroly a log ide do konzoly len pri ZMENE stavu.
  Z `:read_only` súboru `load` vracia **PRÁZDNO a nikdy seed** — cudzie defaulty by prvý zápis zvečnil (lekcia R-07 P1-1).
- **API je LEN create** (register R-35, audit #17 FIX 10): `create_manufacturer!` a `create_series!` → `[:ok | :exists | :invalid | :conflict | :write_failed, …]`. Rename a delete
  vo V1 NEEXISTUJÚ — museli by prejsť všetky sety, položky, snapshoty v .skp aj šablóny a bez toho by za sebou nechali osirelé reťazce. „Úplná náhrada" obsahu (vzor pravidiel
  kovania) sa tu vedome nezavádza: dve otvorené okná by si ju prebili.
- **Zápis:** `with_catalog_lock` → `JsonFileStore.reload!` → **znovu posúdená brána nad čerstvým dokumentom** → prípadná revízia (`load_with_revision` dáva obsah aj odtlačok
  z JEDNÉHO stavu súboru) → atomický zápis. Do súboru zapisuje **jediné miesto** (`write`); zlyhaný `flock` je IOError a končí ako `:write_failed`, nikdy ako tichý úspech.
- **Seed (`SEED_VERSION` 3, KOV-G1a):** Hettich · Blum · Grass · Strong · **Häfele** · **Tulip** · Ostatné a ich rady (Sensys, InnoTech Atira, Quadro, AvanTech YOU; **AXILO
  pod Häfele**; CLIP top, AVENTOS,
  TANDEMBOX, LEGRABOX, MERIVOBOX, TIP-ON; Nova Pro, Tiomos; StrongMax, **StrongBox**). Tulip a StrongBox pribudli s katalógovým seedom v3 — bez nich by šesť úchytiek/vešiakov
  a päť StrongBoxov nemalo výrobcu a strom katalógu by ich zhodil pod „— bez výrobcu". Merge dopĺňa LEN chýbajúce mená, nikdy neprepisuje a nad read-only ani degradovaným
  súborom sa nerobí; `ensure_seeded` má DVOJITÝ check (rýchly + pod zámkom), takže oneskorený seeder neprepíše reálnu zmenu.
- **JEDNORAZOVÁ MIGRÁCIA VLASTNÍKA RADY — `migrate_axilo_owner!` (KOV-G1a).** Seed v1 viedol **AXILO pod Hettichom**, hoci je to **Häfele** program. „Doplniť chýbajúce mená"
  na to nestačí: rada v súbore už je, takže by pod Hettichom ostala navždy — a set nôh aj deväť nových katalógových riadkov nesú dvojicu Häfele/AXILO, ktorá by v takej
  taxonómii NEEXISTOVALA (`create_item` aj `save_set!` by ich odmietli vetou „rada nepatrí výrobcovi"). Presun preto beží **vnútri `merge_seed`, PRED dopĺňaním rád** (po ňom
  by ho add-if-absent krok preskočil) a dotkne sa **LEN záznamu, ktorý je PRESNE starý seed tvar**: meno doslovne `AXILO` **a** vlastník ekvivalentný `Hettich` (vzor
  `LEGACY_SEED_SHAPES` v `hardware_sets.rb`). Premenovaná („AXILO plus") alebo inak naviazaná rada = **ruky preč** + info log. Nový vlastník sa berie z **UŽ ULOŽENÉHO** zápisu
  výrobcu (keď má používateľ „HÄFELE", rada zapísaná naším „Häfele" by v selectoch rád zmizla — JS filtruje presným reťazcom, Codex #320 kolo 2 P2); keď výrobca ešte
  neexistuje, doplní sa v tom istom kroku. Jednorazovosť stráži `seed_version` (2 → **3**), takže návrat rady pod Hettich sa už nikdy neprepíše.
- **`series_owner(rada)` — KOMU RADA V ŽIVEJ TAXONÓMII PATRÍ** (Codex #337 N2/N3). Migrácie (katalógová oprava dvojice Hettich+AXILO, klasifikácia seed setov) sa musia pýtať
  taxonómie, nie odvodzovať vlastníka z toho, čo im vrátil `resolve_classification` nad NAŠÍM seedom: pri cudzej väzbe rady vráti resolve nášho výrobcu BEZ rady, a migrácia by
  z toho usúdila „vlastník je Häfele". Predikát číta **LEN uložený dokument** — bez `ensure_seeded`, teda **bez zápisu** (pýta sa „odporuje mi taxonómia?", nie „založ mi ju")
  — a nad read-only súborom aj nad neexistujúcim súborom vracia `nil`, čo volajúci vykladajú ako „nemáme sa čoho chytiť, nič nemeníme".
- **`resolve_classification(manufacturer, series)`** → `[kanonický výrobca|nil, kanonická rada|nil, errors]` je spoločný kontrakt pre set aj položku katalógu
  (`check_classification` je nad ňou len wrapper na chyby). Zhoda je case-insensitive a bez diakritiky, ale **uložiť sa smie VÝHRADNE kanonický zápis zo zoznamu** —
  zapisovacie cesty (`HardwareSets.save_set!`, `HardwareCatalog.create_item`/`patch_item`) preto berú mená odtiaľto; inak by vedľa „Hettich" vyrástol „hettich" a padol by
  invariant jediného mena, na ktorom stojí zoskupenie (B2) aj filtre (D). Kľúče sa pritom LEN prepisujú, nikdy nedopĺňajú (rada je voliteľná a patch mení len to, čo nesie).
  Volajúci si musí NAJPRV overiť `read_only?` — nad nekompatibilnou taxonómiou vracia `load` prázdno a kontrola by hlásila „výrobca nie je v zozname" namiesto skutočného dôvodu.

Zápis do taxonómie je zápis do globálneho súboru, takže v SketchUpe **nerobí krok Späť**. Testy: `tests/pure/test_kovb1_taxonomia.rb` (vrátane REÁLNEHO dvojprocesového `flock`)
a in-SketchUp sekcia `run_kovb1`.

### hardware_sets.rb

Sety kovania (mapovacie pravidlo generický typ → kódy katalógu) + projektový snapshot predvolieb na modeli; nadväzujúce zmienky sú v odsekoch `hardware_rules.rb`
a `hardware_catalog.rb` a v [ui-lifecycle.md](ui-lifecycle.md) (sekcia `hw` Štúdia).

**KLASIFIKÁCIA SETU (KOV-B1, v0.9.19).** Set už nie je len „mapovanie typu na kódy" — nesie AJ to, NA ČO sa používa: `use_type` (door|drawer|lift|fall|other) · `opening_mode`
(classic|tipon|other, kde `other` = „neuplatňuje sa" pri nohách, podperkách a zavesení) · `drawer_construction` (metal|wood|other, **len pri zásuvke**) · `lift_system`
(hk_top|hl_top, **len pri výklope** — KOV-E1a) · `manufacturer` · `series` · `active`. Slovníky sú UZAVRETÉ (neznáma hodnota = obsah novšej verzie, nie nová kategória) a s čelami držia JEDNU doménovú pravdu — `Fronts` sa načítava PO
`hardware_sets`, takže väzbu drží guard test, nie referencia.

Šesť pravidiel, na ktorých kontrakt stojí:

- **ALL-OR-NOTHING** (audit #17 FIX 6). Klasifikácia buď ÚPLNE chýba (legacy „nezaradený" set — správa sa presne ako pred KOV-B1), alebo je ÚPLNÁ a kontextovo platná.
  Čiastočný tvar zápis ODMIETNE: polovičná klasifikácia by v editore vyzerala ako hotové zaradenie a filtre KOV-D by na ňu nesadli. **Rada je VOLITEĽNÁ** (vedomá odchýlka od
  mockupu): podperky, klzáky ani „Bystrica" žiadnu radu nemajú a vynútená rada by do taxonómie priniesla vymyslené mená.
- **`generic_type` je ODVODENÝ** kanonickou mapou `USE_TYPE_GENERIC` (`door→hinge` · `drawer→slide` · `lift/fall→lift`; `other` → explicitný typ) — audit #17 BLOCKER 2. Chýbajúci
  sa doplní, nesediaci je chyba s vetou, ktorá menuje OBE strany. Je to jediná autorita vzťahu; dva protirečivé zápisy o tom istom sete sa uložiť nedajú.
- **Čítanie je tolerantné, ale CELÉ-ALEBO-VÔBEC.** Neúplný, nekonzistentný alebo neznámy klasifikačný blok sa zahodí CELÝ (`log_skip`) a set sa číta ako nezaradený —
  `generic_type` (a teda EXPANZIA a NÁKUP) sa pritom **NIKDY nemení**. Tichý orez to nie je: stratu prizná 4. vrstva detektora nižšie.
- **`active` je SPARSE** (audit #17 FIX 7): default je „aktívny", ukladá sa LEN `false`. **`expand`, `explain` ani `resolve_set_id` ho NEČÍTAJÚ** — existujúce mapovanie,
  snapshot aj šablóna expandujú deep-equal so setom bez príznaku. Od KOV-B3 ho číta **jediné miesto: `set_options`**, teda PONUKA nového výberu (predvoľby projektu v Štúdiu
  a override skrinky v paneli). Neaktívny set sa už nenúka — ale **referencovaný set v ponuke OSTÁVA** (`referenced_ids`), inak by select ukazoval prázdno tam, kde projekt
  hodnotu má, a prvý klik vedľa by ju ticho prepísal. Globálnu tabuľku filtruje tá istá myšlienka v UI (`hwsGlobalOptions`).
- **KOV-D1b — ponuka pre TRIEDNY kľúč (`class_set_options`).** `set_options` vracia sety JEDNÉHO TYPU; triedny kľúč je užší (menuje aj otváranie a konštrukciu) a pri sete
  s `height_variant` sa hodnotou NIKDY nesmie stať pevný set. `class_set_options(class_key, globals, snapshot_sets, referenced_ids)` preto stavia ponuku sám: berie
  `set_options` (rovnaká precedencia snapshot > global), **odfiltruje neaktívne aj tie referencované** (na rozdiel od `set_options` — F10: ponuka NOVÉHO výberu ich niesť nesmie,
  uloženú hodnotu ukazuje volajúci osobitne cez `mapping_value_text`), nechá len sety sediace triede a rozdelí ich: set **bez** `height_variant` = PEVNÁ voľba, sety **s ním**
  = jedna voľba za RODINU, teda pásmový selektor `height_variant` s jedným pásmom na výšku (`min == max`, `height_selector_for`). **Rodina je `(manufacturer, series, názov bez
  tokenu `H<číslo>`)`** (`family_stem`) — klasifikácia farbu ani vyhotovenie nenesie (Atira biela a antracit majú všetky klasifikačné polia zhodné), takže jediný údaj, ktorý ich
  odlíši, je názov. Je to **POHĽAD, nie pravda**: uložená hodnota je vždy zoznam reálnych `set_id` a každé pásmo znovu validuje zápisová cesta (`class_key_value_problem`
  v globále/projekte, `classified_value_problem` v override skrinky), takže zle zgrupovaná ponuka nevie vyrobiť zlý nákup — najhoršie zle POPÍSANÚ voľbu. Sprievodné čisté
  funkcie: `mapping_option_id` (stabilný token hodnoty pre `<select>`; rovnaká hodnota = rovnaký token), `mapping_value_text` (ľudský text uloženej hodnoty — chýbajúcu
  definíciu PRIZNÁ, nikdy nenahradí), `class_key_label` (popisok kľúča z `HardwareRules.label_for` + `CLASS_OPTIONS`), `CLASS_MAPPING_KEYS` (= kľúče `MAPPING_ADDITIONS`,
  jediný zoznam tried, na ktoré sa dá mapovať). `height_variant` v `PARAM_OPTIONS` nie je (nie je to os výberu člena), preto má vlastný 2. pád v `selector_by`.
- **Trieda nepomenúva SYSTÉM — bránou je `set_system`** (Codex #310 kolo 1 P2-4). Triedny kľúč nesie len otváranie a konštrukciu, ale **receptová položka vždy nesie
  `params['system']`**, a `set_incompatible_info` podľa neho porovnáva výrobcu a radu (`SYSTEM_IDENTITY`). Set cudzej rady s rovnakým otváraním aj konštrukciou (napr. Blum
  Legrabox, `metal`/`classic`) by teda prešiel výberom aj zápisom a padol by až pri expanzii — zásuvka RED, export stojí. `set_system(set)` je **reverzné čítanie tej istej
  jedinej autority** `SYSTEM_IDENTITY` (`[výrobca, rada] → system`, `same_name?` bez diakritiky) a stojí na OBOCH miestach: `class_set_options` taký set **neponúkne**
  a `class_key_value_problem` ho **odmietne pred zápisom** (globál aj projekt). Legacy set bez klasifikácie systém nemá (`nil`) — pre triedny kľúč sa aj tak neponúka, lebo
  neprejde už kontrolou otvárania.
- **`save_set!` MERGUJE klasifikáciu z uloženého setu.** Do KOV-B3 posielal editor len štyri kľúče (`set_id`, `name`, `generic_type`, `members`), takže bez merge by KAŽDÁ úprava
  člena ticho zhodila zaradenie — presne tá trieda tichej straty, ktorú dávka riešila (a je to jedna z mutácií sady). Kľúč, ktorý vo vstupe VÔBEC NIE JE, sa preberie z uloženého
  setu; kľúč prítomný s `nil`/`''` (a `active: true`) je VEDOMÉ vymazanie. Až merged tvar ide do validácie, takže all-or-nothing platí nad tým, čo sa naozaj uloží. Validácia preto
  beží **až pod zámkom** (uložený set sa smie čítať len čerstvo — R-08). **Modal KOV-B3 posiela klasifikáciu VŽDY CELÚ** (všetkých päť kľúčov, aj prázdnych) — vynechať
  `drawer_construction` pri prepnutí zo zásuvky na dvierka by znamenalo prevziať starú hodnotu z uloženého setu a set by už nikdy neprešiel validáciou.
- **Taxonómia sa kontroluje LEN v `save_set!`** (zápis do globálnej knižnice). `validate_set` ostáva ČISTÁ (žiadne IO) — používa ju aj zápis projektového snapshotu a čítanie
  šablón, ktoré cestujú medzi PC s INOU taxonómiou; vynútiť ju tam by znamenalo, že zákazku z iného počítača sa nedá otvoriť. Nekompatibilná taxonómia je fail-closed:
  klasifikovaný set sa uložiť nedá (`[:write_failed, dôvod taxonómie]`), legacy set áno; degradovaná taxonómia sa čítať smie, takže kontrola nad ňou beží normálne.

**Chyby sú ŠTRUKTUROVANÉ** (kontrakt pre KOV-B3, audit #17 FIX 13): `validate_set_detailed` a `save_set!` vracajú `[{ 'row' => nil|index člena, 'field' => …, 'msg' => SK veta }]`,
takže editor vie chybu ukázať PRI POLI. `save_set!` je TROJICA `[status, info, errors]` — dvojprvkové destruovanie u volajúcich (`status, info = …`) tým nie je dotknuté
(Ruby prebytočný prvok zahodí) a stráži to test. **Od KOV-B3 tretí prvok naozaj cestuje na obrazovku:** `handle_set_save` ho posiela ako `HWSETS.setResult(ok, msg, errors,
token, conflict)` — `token` je identita JEDNÉHO odoslania (odpoveď zavretého okna nesmie zavrieť okno otvorené teraz) a `conflict` je vlastný príznak, pri ktorom modal draft
NEZAHADZUJE, ale ponúkne obnovu.

**ŽIVÝ NÁHĽAD EXPANZIE — `preview_expansion` (KOV-B3).** Editor setu ukazuje, ČO SA REÁLNE OBJEDNÁ, ešte pred uložením. Cesta je zámerne TÁ ISTÁ ako v nákupe: draft prejde
`validate_set_detailed`, normalizovaný tvar sa vloží do **dočasného stavu** `{ 'mapping' => {gt => set_id}, 'sets' => {set_id => draft} }` nad **syntetickým vlastníkom**
(`PREVIEW_OWNER`, `quantity 1`, vzorové `params`) a spustí sa **`expand`**. Výsledok je preto deep-equal s tým, čo by `expand` vydal PO uložení toho istého setu (test to porovnáva
riadok po riadku) — druhý výklad nákupu nevzniká (lekcia R-06a „panel a súpis sa nesmú rozísť"). Tri veci sú kontrakt: **(1) žiadne IO** — funkcia je čistá, katalóg dostáva
`catalog:`/`lookup:` od volajúceho a nikdy nevolá `save_set!`, snapshot ani zápis (stráži to stub zámku aj `write`, ktorý si volanie ZAPÍŠE — `save_set!` má vlastný `rescue`,
v ktorom by sa výnimka stratila); **(2) počíta sa z DRAFTU**, nie z uloženého setu (mutácia sady: náhľad setu, ktorý v knižnici ešte nie je); **(3) chyby sú tá istá štruktúra
`{row, field, msg}`**, takže editor ich ukáže pri poli. **Text skladá server** (`preview_text`): prvý riadok povie, NA ČOM sa počítalo, ďalšie sú nákupné riadky a ORANGE dôvody
idú cez `unmapped_reason_sk` — teda presne tie vety, aké ukáže súpis. Vzorové parametre (`PREVIEW_SAMPLE`: NL 470, výška čela 176, výška sokla 100) smie klient prepísať, ale
LEN kľúče z `PREVIEW_PARAM_KEYS` (cudzí kľúč by sa dostal do `it['params']` a mohol by obísť bránu dĺžkového kovania). Keď NL nepodal človek, vyberie sa **najbližšia vyššia
existujúca** dĺžka radu (inak najdlhšia) — rad 260–350 by inak hlásil falošný ORANGE „nemá kód pre NL 470". UI vrstvu popisuje [ui-lifecycle.md](ui-lifecycle.md).

**Popisky uzavretých slovníkov žijú v core** (`CLASS_OPTIONS` + `class_label`, KOV-B3): jeden zoznam pre select editora aj chip dlaždice, klient ho dostáva v payloade
(`sets_payload['class_options']`) a vlastný nemá — druhý zoznam v JS by sa pri prvom pribudnutom type rozišiel s doménovou pravdou. `USE_TYPE_SK` (2./4. pád do vety servera)
je iná vrstva a zostáva oddelene. Neznáma hodnota (obsah novšej verzie) sa **neprekladá** — vypíše sa tak, ako prišla.

**Marker `std` má ŠESŤ hodnôt a je LAZY podľa obsahu.** `1` = len legacy tvary · `2` = pásma člena alebo selector v mapovaní (GH #131) · **`3` = set s KTORÝMKOĽVEK kľúčom mimo
`LEGACY_SET_KEYS`** (každé klasifikačné pole aj `active` samostatne) **alebo mapovanie s triednym kľúčom `class:`**. Čisto legacy obsah ostáva na svojom pôvodnom std, takže
spätná čitateľnosť sa zbytočne neblokuje; obsah so `std: 3` je pre starší plugin `:read_only` (knižnica) a `:invalid` (snapshot) — NIKDY čiastočné čítanie. Ďalšie hodnoty
pridali neskoršie dávky: `4` = `height_variant` (KOV-C2a) · `5` = vyhradená bunka `none` — od KOV-G1a **v rade `code_by_nl` AJ v kódovom pásme `param_bands`**, jeden marker
pre obe miesta (D-118b, KOV-G1a) · **`6` = tvary výklopov** (`code_by_param`, `quantity_from`, `lift_system` — KOV-E1a). Tú istú funkciu (`snapshot_std`) používa zápis knižnice aj zápis snapshotu: marker musí hovoriť o obsahu rovnako v `%APPDATA%` aj v .skp.

**TRIEDNY kľúč mapovania `class:<generic_type>|<opening_mode>[|<tretí segment>]`** (KOV-B1 zaviedol tvar, KOV-C2a čítanie, KOV-D1a zápis, KOV-E1a výklopy). Tvar je uzavretý:
tretí segment majú LEN `slide` (konštrukcia zásuvky, voliteľný) a `lift` (systém výklopu, **povinný**), segmenty sa trimujú a downcasujú. Pozná ho **jediný parser** (`parse_mapping` ho rozpozná PRED `parse_hardware_set_key`), prijímajú ho všetky mapy
(globálna, snapshot aj cabinet override), počíta s ním whitelist brány, `snapshot_std`, `referenced_set_ids` aj `mapping_types_by_set`.
`BuildPlan.hardware_set_key_type` z neho vracia prvý segment (starší plugin prefix nepozná, takže mu z toho istého kľúča vyjde neznámy typ a prestavbu zablokuje — presne to
chceme), `BuildPlan.parse_hardware_set_key` vracia `nil` (preto sa kľúč mapovania nikde nečíta cez neho, ale cez `HardwareSets.mapping_key_type` / `owner_scoped_key?`).

**KOV-D1a (v0.9.34) — OWNER TRIEDNY KĽÚČ, TRIEDNE ZÁPISY, NEAKTÍVNY SET.** K triednemu kľúču smie pribudnúť sufix **`@front:<id>/panel`** — vlastný kit pre JEDNO čelo
(KOV-E1a pridala **`@front:<id>/flap`** pre výklop; pár trieda ↔ dielec drží `CLASS_OWNER_PART`):

- **Kde smie žiť.** VÝHRADNE v `config.hardware_sets` skrinky (`parse_mapping(allow_owner: true)`). Globálna knižnica aj projektový snapshot ho pri zápise ODMIETNU a pri
  čítaní zahodia s logom. Triedna časť sa normalizuje, **owner ostáva doslovne** (part_key je identita dielca, nie enum) a musí mať tvar panela čela — override na zóne či
  doske by resolver nikdy neprečítal. Pri normalizácii configu skrinky sa navyše kontroluje, či čelo ten dielec **dnes naozaj vyrába**: `prune_missing_owners` dostáva
  z `CabinetBuilder.norm_hardware_sets` mapu `{id čela => dielec}` (`Fronts.class_owner_part`: `drawer_front` → `panel`, `lift`/`fall` → `flap`, dvierka, blenda a `none`
  → nič) a kľúč, ktorý jej nesedí, vypadne s logom (vzor `prune_none_front_overrides`). Samotné ID nestačí (Codex #332 kolo 3 P2): čelo s tým istým ID prepnuté z výklopu
  na dvierka už `/flap` nemá — kľúč by tam ostal mŕtvy a po návrate na výklop by ticho OŽIL so starým setom. Legacy composite `typ@owner` sa pruning nedotýka.
  **Log rozlišuje DVA dôvody** (interná delta P3): mapa nesie `nil` aj pre EXISTUJÚCE čelo, ktoré žiadny triedny dielec nevyrába (dvierka, blenda, „bez čela"),
  takže o existencii rozhoduje PRÍTOMNOSŤ KĽÚČA — „čelo v skrinke už nie je" vs. „čelo už taký dielec nevyrába". Bez toho by prepnutie výklopu na dvierka logovalo,
  že čelo zmizlo.
- **Precedencia pre receptovú položku je TROJÚROVŇOVÁ:** owner triedny → triedny (skrinka) → projektový snapshot. Na nižšiu úroveň sa ide **LEN pri NEPRÍTOMNOM kľúči**;
  prítomná hodnota, ktorá sa nedá rozložiť (chýbajúce pásmo, nekompatibilný set), končí ako `unmapped` s dôvodom → RED `drawer_kit_missing`. Na generický `slide`/`slide@owner`
  sa naďalej NIKDY nepadá.
- **Zápis (`apply_cabinet_override`).** Pre KLASIFIKOVANÉ položky sa už nepíše generický `slide@owner` (resolver by ho neprečítal — tichý no-op), ale owner triedny kľúč;
  kľúč zloží **`override_class_key`** a len vtedy, keď všetky položky tej identity nesú ROVNAKÚ klasifikáciu (zmiešaná skrinka ostáva na generickom kľúči). Hodnotou smie byť
  aj **selektor podľa `height_variant`** (Atira; Quadro pevný `set_id`) — akcia panela `handle_set_hardware_set` ho prijme v poli `value` a do snapshotu zmrazí KAŽDÝ
  referencovaný set. **Validácia beží PRED zápisom** (`classified_value_problem` / `band_set_problem`): každé pásmo sa overí proti klasifikácii cieľového čela (otváranie,
  konštrukcia, systém), výška setu musí patriť do pásma, ktoré ho vydáva, selektor musí mať pásmo pre AKTUÁLNU výšku a neaktívna definícia sa odmietne — forged payload sa do
  configu nedostane vôbec.
- **Triedne zapisovacie operácie (Astra #20 F9).** `set_global_mapping!` aj `set_project_mapping!` prijímajú **kľúč mapovania** (generický typ ALEBO validovaný triedny kľúč;
  owner triedny NIE) cez `write_mapping_key`; typ pre kontrolu setov číta jediná autorita `mapping_key_type` — kľúč sa nikdy neskladá z typu ani naopak. Mení sa **JEDEN**
  kľúč, ostatné mapovania aj definície ostávajú a definície všetkých pásiem selektora sa zmrazia v tom istom zápise. Globál ostáva predvoľbou nových projektov.
- **Neaktívny set (Astra #20 F10).** `inactive_ref` je **jediná autorita** otázky „dá sa tento set novo vybrať" a beží na všetkých troch zapisovacích cestách — pri override
  skrinky **pred** vetvením na klasifikovaný/legacy, takže neaktívny set neprejde ani na legacy položke (Codex #308 kolo 1 P1). **Už uložená hodnota sa zachová** (prepis toho
  istého kľúča na seba prejde) a `expand`/`explain` sú na `active` naďalej slepé — deaktivácia setu teda NEMENÍ nákup existujúcej zákazky.
- **Validácia platí pre VŠETKY dotknuté položky, nie pre prvú** (Codex #308 kolo 1 P2). Override skrinky bez ownera platí pre všetky zásuvky tej triedy, a tie môžu mať rôzne
  výšky: selektor, ktorý vyhovuje H70, ale nie H144, sa **neuloží** a hláška povie, ktorého dielca sa to týka. Vo výškovom selektore navyše smie stáť **len set s platným
  `height_variant`** — set bez neho by prešiel (probe by výšku zhodila, kontrola pásma by sa preskočila) a expanzia by ho vzápätí odmietla ako `drawer_kit_missing`.
- **Owner výber upratuje LEGACY kľúč** (Codex #308 kolo 1 P2). Pri zápise aj zrušení klasifikovaného owner výberu sa z mapy odstráni aj `typ@owner` — pre klasifikovanú
  položku je mŕtvy (resolver ho nečíta), no po upgrade skrinky by v configu ostal a karta čela by ho ďalej ukazovala ako aktuálnu voľbu. Legacy položka si svoj kľúč ponecháva.
- **PRÍTOMNÝ kľúč s nepoužiteľnou hodnotou = `mapping_invalid`, nikdy nižšia úroveň** (Codex #308 kolo 2 P1). Čítacia normalizácia cabinet override mapy takú položku
  **nezahadzuje**, ale nechá ako **marker** `{ 'invalid' => dôvod }` (jediný tvar s týmto významom; zapisovacia cesta ho nikdy nezapíše ako voľbu, `parse_mapping_value` ho
  odmieta, a **neodstráni** ho — odstránením je len explicitné vymazanie kľúča používateľom). `present_mapping_value?` ho považuje za prítomný, takže **precedencia sa na ňom
  zastaví**, `value_set_ids` z neho nevydá nič a `resolve_set_id` vráti nový dôvod `mapping_invalid` (pri receptovej položke povýšený na RED). Normalizácia je idempotentná.
  Je to presne to isté pravidlo ako pri `recipe_refs`: **o „chýba" rozhoduje prítomnosť kľúča, nie použiteľnosť hodnoty**.
- **Marker sa NEZAPÍNA prepínačom — plynie z `allow_owner`** (Codex #308 kolo 3 P1). Samostatný `keep_invalid` flag stačilo zabudnúť na jednom z pätnástich volaní
  `normalize_mapping`/`parse_mapping` (`apply_cabinet_override`, `Panel.cabinet_set_overrides`, `HardwareSets.explain`, `TemplatesDialog.merge_hardware_sets` ho aj naozaj
  zabudli) a marker sa **ticho stratil pri prvej úprave iného kovania** — teda presne tá tichá zmena, ktorej má brániť. Preto parameter neexistuje a platí väzba:
  **`allow_owner: true` má PRÁVE cabinet override mapa**, jediná mapa s nižšou úrovňou pod sebou. Knižnica, projektový snapshot a šablóna (`allow_owner: false`) nižšiu
  úroveň nemajú a ich detektory strát (`map_errors`, `norm_map.length != mapping.length`, `read_template_mapping`) by marker naopak **rozbil** — preto tam nepatrí. Väzbu
  strážia dva testy aj dve mutácie (marker nikde / marker všade).
- **Neaktívny set sa porovnáva ZÁVÄZKOM, nie ID** (Codex #308 kolo 2 P2). `mapping_commitments` rozloží hodnotu na `[param, min, max, set_id]` (pevná voľba na
  `['fixed', set_id]`) a uložená neaktívna referencia sa zachová, len **kým sa jej efektívne mapovanie nezmení**. Posun či rozšírenie pásma alebo prechod z pevnej voľby na
  selektor je **nový výber** — inak by sa neaktívny set ticho objednal do zákaziek, pre ktoré nebol vybraný.
- **Triedny zápis validuje sety proti klasifikácii kľúča** (`class_key_value_problem`, Codex #308 kolo 2 P2) — v `set_global_mapping!` aj `set_project_mapping!`: otváranie,
  konštrukcia, `height_variant` vo vnútri svojho pásma a zákaz **pevnej** voľby setu s výškovým variantom. Je to vlastná funkcia, nie `classified_value_problem`: tá porovnáva
  set s konkrétnou položkou (jej `system` a aktuálnou výškou), kým triedny kľúč nesie len otváranie a konštrukciu; zdieľajú sa spodné pravidlá, nie vstup.
- **Zmiešaná skrinka sa jedným kľúčom zapísať nedá** (vlastný prechod diffu). Keď položky tej identity nesú rôznu klasifikáciu (alebo klasifikované + legacy), `override_class_key`
  vráti dôvod a zápis sa **odmietne** s vetou „vyber set na konkrétnom čele" — generický kľúč by klasifikované položky nečítali (tichý no-op) a triedny by minul legacy.
- **Šablóny a duplicitné ID (Codex #307 kolo 2).** `TemplatesDialog.merge_hardware_sets` sa už nepýta `BuildPlan.parse_hardware_set_key` (pre `class:` vracia nil, záznam by
  vypadol a kit by sa ticho zmenil), ale `HardwareSets.owner_scoped_key?` — jediná autorita otázky „patrí tento záznam cieľu". `ProductionCore.override_keys_in_use` registruje
  pri klasifikovanej položke triedny AJ owner triedny kľúč, takže dve skrinky so spoločným ID a rôznym owner overridom bránu duplicít nepodliezajú.
- **`CONFIG_SCHEMA` 5 → 6** ([construction.md](construction.md)) — starší plugin owner kľúč zahodí, no `unknown_generic_types` z neho stále prečíta podporovaný `slide`, takže
  by prestavbu nezastavil (Astra #20 B1). `DRAWER_ACTIVATION_SCHEMA` ostáva 5. Testy: `tests/pure/test_kovd1a_mapovanie.rb` (34 testov + 8 overených mutácií) a in-SU sekcia
  `run_kovd1a` (Undo aj Redo vracajú mapovanie, snapshot a nákupný kód naraz).

**KOV-C2b (v0.9.31) — RECEPTOVÁ POLOŽKA A RED `drawer_kit_missing`.** Zásuvkovú položku už **emituje** `Construction` (`source: 'recipe'`, `rule_id: recipe:<recipe_id>`,
`quantity: 1`, voliteľné `locked: true` pri platnom NL zámku). Pre výber setu platí presne mechanika C2a nižšie; navyše: **každý** dôvod nemapovania sa pre `source: 'recipe'`
povyšuje na **RED `drawer_kit_missing`** (`unmapped_entry`), pôvodný dôvod cestuje v `base_reason` a text skladá `unmapped_reason_sk` z NEHO (žiadny druhý preklad tých istých
príčin). Dôvod: dielce sú už postavené na konkrétnu NL — chýbajúci kit nie je „nenacenené kovanie", ale **nevyrobiteľná** objednávka, preto blokuje aj VEPO.
`note_manual` berie `locked: true` ako dnešné `source: 'manual'` (dĺžka je ručne určená); bez zámku receptová položka znamienko NEMÁ (Astra #19 N11).
**KOV-C2c (v0.9.33)** k tomu pridáva aditívny príznak **`blocks_export: true`** na TOM ISTOM zázname: sekcia Nákup z neho kreslí červený riadok namiesto jantárového
„nenacenené" (detail v [ui-lifecycle.md](ui-lifecycle.md)). Je to **len zobrazovací príznak** — bránu exportu drží ďalej `ProductionCore.export_blockers` nad
`Recipes::DRAWER_BLOCKERS`; nákupný CSV kontrakt sa nemení.

**KOV-C2a (v0.9.30) — TRIEDNY KĽÚČ SA ZAČAL ČÍTAŤ, `height_variant`, `MAPPING_ADDITIONS`, `std` 4.** Príprava aktivácie zásuviek: mení sa výber setu pre položku, ktorá nesie
klasifikáciu zásuvky, ale **žiadne dnešné pravidlo ju nenesie**, takže výstupy existujúcich zákaziek boli CONTENT-identické (stráži to golden `seed_kniznica` aj vlastný
charakterizačný test). Päť častí:

- **Kto je „zásuvková" položka.** `class_key_for(it, gt)` = položka má v `params` OBE polia `opening_mode` a `drawer_construction` → kanonický kľúč
  `class:slide|<opening_mode>|<drawer_construction>`. Inak `nil` a celá vetva je mŕtva.
- **Precedencia je KRATŠIA a bez fallbacku.** Pre takú položku číta `resolve_mapping_value` **cabinet override s triednym kľúčom → projekt**, a keď mapovanie chýba, vráti
  `nil` s dôvodom **`class_unmapped`** („Pravidlá → Doplniť nové predvoľby"). Na generický `slide` **NIKDY nepadne** — H70 kit k zásuvke H176 by bol zlý nákup, a mlčky.
  Owner-level `slide@…` sa pre ňu vedome IGNORUJE (generický `slide@owner` je práve ten zakázaný fallback). **Od KOV-D1a** je pred cabinet triednym kľúčom ešte OWNER triedny
  `class:…@front:<id>/panel` — precedencia je teda trojúrovňová (viď odsek KOV-D1a vyššie).
- **`height_variant` = šieste klasifikačné pole, jediné VOLITEĽNÉ.** Celé číslo z uzavretého `DRAWER_HEIGHT_VARIANTS` (70 · 144 · 176), povolené LEN pri `use_type: 'drawer'`
  (Quadro V6 varianty nemá a pole mu legitímne chýba). Je v `CLASS_KEYS`, lebo ten zoznam je kontrakt troch vecí naraz (whitelist `SET_KEYS`, typová kontrola
  v `incompatible_set?`, merge v `save_set!`) — výnimku „všetky alebo žiadne" pre neho drží `classify`. **Nie je os výberu** (tou ostáva pásmový selektor mapovania), slúži
  výhradne na OVERENIE pri expanzii. Round-trip prežije všetkými zápisovými cestami: globálny `save_set!` (editor pole nepozná, takže ho `merge_class_keys` preberie
  z uloženého setu — a pri prepnutí zo zásuvky na dvierka ho SERVER odstráni, inak by set už nikdy neprešiel validáciou), projektový snapshot, cabinet override aj šablóna.
  Stratu chytá **piata vrstva detektora** v `classification_lost?` (kontrola „žiadny klasifikačný kľúč" by ju prehliadla — zvyšok klasifikácie pole prežije).
- **`std` 4 (`STD_HEIGHT_VARIANT`) je LAZY podľa obsahu** a testuje sa PRVÝ (najvyšší marker vyhráva): dostane ho len knižnica/snapshot, v ktorej NIEKTORÝ set pole naozaj
  nesie. Obsah s triednym kľúčom bez neho ostáva na 3, čisto legacy na 1/2. Pre starší plugin je std 4 `:read_only` (knižnica) a `:invalid` (snapshot).
- **Seed `SEED_VERSION` 2 → 3 a nový kontrakt `MAPPING_ADDITIONS`.** Pribudlo **8 klasifikovaných drawer setov** (Atira 3 výšky × 2 otvárania s `code_by_nl` z draftu #13 §1,
  Quadro V6 × 2 z §2) — legacy `vysuv-atira-biela-h70` ostáva **nedotknutý** pre legacy mapovanie `slide`, nové sety majú vlastné ID. `MAPPING_MIGRATIONS` vie iba NAHRADIŤ
  hodnotu pri existujúcom kľúči, chýbajúci `class:` kľúč nevytvorí — preto druhý, užší kontrakt **`MAPPING_ADDITIONS` (add-if-absent)**: kľúč sa do globálu doplní LEN keď
  chýba (používateľské mapovanie sa NIKDY neprepíše) a LEN keď sú v knižnici VŠETKY sety, na ktoré hodnota ukazuje (čiastočný selektor by ticho menil výber). Do projektu ho
  prenesie až vedomé **„Doplniť nové predvoľby"** (`merge_project_sets_seed!`, existujúci mechanizmus — kľúče mapovania sú preň nepriehľadné reťazce, takže netreba nič nové).
  `seed_library` ich merguje aj do ČERSTVEJ knižnice — a **`ensure_seeded` seeduje cez `seed_library`, nie cez samotnú `SEED_MAPPING`** (odhalil to in-SketchUp beh: pôvodná
  cesta zapisovala len legacy kľúče, takže fresh install by zásuvky nemapoval, kým upgrade cez `merge_seed` áno — presne ten rozchod dvoch ciest, ktorému sa dávka vyhýba).
  Dôsledok na `std`: čerstvá knižnica je **4** (seed nesie sety s `height_variant`) a **`global_default_state` zmrazí triedne mapovania aj drawer sety do snapshotu KAŽDÉHO
  nového projektu**, takže aj ten je od tejto dávky std 4. Existujúce projekty sa nemenia — do nich ich prenesie až vedomé „Doplniť nové predvoľby". Hodnota pre Atiru **musí byť pásmový selektor podľa `height_variant`**;
  pevný `set_id` by po prerastení zásuvky H70 → H176 objednal H70 kit (klasifikácia opening/construction je pri oboch rovnaká), preto ho `resolve_set_id` odmietne ako
  `set_incompatible` / `height_selector`. Quadro (bez variantu) pevný `set_id` smie.
- **Seed `SEED_VERSION` 3 → 4 (KOV-D1c, v0.9.36) — ALTERNATÍVNA RODINA „Atira antracit".** Pribudlo **6 setov** `atira-antracit-h{70,144,176}-{sisy,p2o}` s kódmi z draftu
  #13 §1 (tabuľka „Antracit kity Atira", Démos 6.9.2026). Klasifikácia je ZHODNÁ s bielou (farbu ani vyhotovenie klasifikácia nenesie), takže rodiny odlišuje **výhradne názov**
  („Atira antracit H70 — klasické" → `family_stem` „Atira antracit — klasické"); `class_set_options` preto od tejto dávky ponúka pre `class:slide|classic|metal`
  a `class:slide|tipon|metal` **dve rodiny**. **`MAPPING_ADDITIONS` sa NEMENÍ** — predvoľba nového projektu ostáva biela a antracit si používateľ vyberá vedome (Pravidlá Štúdia
  alebo karta čela). Katalóg kovania sa nemení tiež (kódy v ňom nie sú ani pri bielej — položka bez katalógu je „bez ceny", `catalog_missing`).
- **Čiastočná rodina je LEGITÍMNY dátový stav.** Antracit nemá kód pre každú bunku radov receptov v1 (SiSy H176 350/520/620, všetky NL 620) — taká bunka má v `code_by_nl`
  kľúč **NEPRÍTOMNÝ**, nikdy prázdny reťazec a nikdy kód inej farby či dĺžky. Expanzia z nej urobí RED `drawer_kit_missing` (`base_reason` `nl_missing`, „nákup nenašiel kit
  výsuvu k postaveným dielcom") a export stojí — to je ZÁMER: tichá zámena by objednala bielu K-sadu k antracitovej zákazke. **Completeness test** („KAŽDÁ bunka radov v1 má kit
  kód", `tests/pure/test_kovc2a_kanal_sety.rb`) preto platí LEN pre predvolenú bielu rodinu; antracit stráži vlastná sada `tests/pure/test_kovd1c_antracit.rb` (tabuľková fixtúra
  = druhý, nezávislý zápis kódov + kontrola SUROVÉHO literálu `SEED_SETS`, lebo normalizácia prázdnu hodnotu ticho zahodí). NL 260/300 z tabuľky sa neseedujú — sú mimo radov v1.
- **Vyhradená bunka `SKIP_CODE` = „vedome bez kódu" (D-118b, v0.9.44).** Hodnota `'none'` v `code_by_nl` znamená **„táto dĺžka kód nemá a ani mať nemá"** → `member_code`
  vráti `[nil, nil]` (existujúca vetva „člen sa preskočí"). **Chýbajúci kľúč ostáva NEMAPOVANÝ** (ORANGE / pri recepte RED) — je to tá istá rodina ako „prítomná neplatná
  hodnota ≠ neprítomná" z KOV-D. Dôvod je dátový: rad Atira **PTOs** potrebuje modul P2O na každej dĺžke OKREM 620 mm, kde je kit typu `PTO` a modul má v sebe; vynechaný kľúč
  by hlásil chýbajúci kód tam, kde žiadny nepatrí. Kódy sú číselné, takže kolízia nehrozí; ako **pevný `code`** je `'none'` odmietnutý
  (`validate_member`) — inak by `member_code` vrátil doslovný „none" do nákupu. V **kódovom pásme** (`param_bands`) ho D-118b odmietalo z jedného dôvodu (`skip_code_present?`
  sa naň nepýtal, takže obsah by dostal nižší marker kompatibility, Codex #321 kolo 3); **KOV-G1a ho tam povolila** spolu s markerom — ale aspoň JEDNO pásmo (resp. jedna
  bunka radu) musí mať skutočný kód, inak je to člen, ktorý nikdy nič neobjedná (Codex #337 N1). **Táto kontrola platí LEN pri PÍSANÍ setu** (`validate_set_detailed(authoring: true)`
  → editor `save_set!` a jeho náhľad `preview_expansion`; JS zrkadlo `hwsAllSkip` beží tiež len pri odoslaní) — **Codex #337 kolo 2 N1**: verzie so sentinelom takého člena uložiť
  DOVOLILI, takže tolerantné čítanie (`normalize_sets`) aj hromadný prepis už uloženého obsahu (`validate_sets` → `write` pri seed-merge, `write_project_state` pri zmrazení
  snapshotu) ho ZACHOVAJÚ. Inak by ho čítanie zahodilo, detektor `members_lost?` by videl zmenu počtu a **celá** legacy knižnica by skončila ako read-only (snapshot ako
  `:invalid`) skôr, než beh stihne čokoľvek povedať. Že taký člen nič nevydá, hlási RUNTIME (`members_all_skipped`); opravu si vyžiada až prvý pokus ten set uložiť.
  V selektore mapovania (`set_id`) sa nekontroluje — tam je to legitímne meno setu. V rade sa ukladá kanonicky malými písmenami. Súpis členov (`explain`) preskočený člen
  **prizná** (`skipped: true` → „bez kódu (netreba)"), aby karta pri NL 620 nemlčala; nákupné CSV z neho
  nemá žiadny riadok.
- **`std` 5 (`STD_SKIP_CODE`) — marker kompatibility sentinelu.** Testuje sa ÚPLNE PRVÝ (najvyšší marker vyhráva) a dostane ho len knižnica/snapshot, v ktorých sa `'none'`
  naozaj vyskytuje. **Bez neho by starší plugin obsah prijal** a z bunky `none` vyrobil nákupný riadok s neexistujúcim kódom (overené sondou nad v0.9.42: knižničná aj šablónová
  brána taký dokument prijmú a `member_code` vráti `["none", nil]`). Šablóny nesú definície setov v `hardware_set_defs`, tie marker `std` nemajú — preto k tejto dávke patrí
  aj **`CabinetBuilder::CONFIG_SCHEMA` 7 → 8** (brány sú existujúce: dopredný `newer_config?` + exportná `ProductionCore.export_blockers`).
- **Fail-closed, keď set nevydá NIČ (`members_skipped`).** Keby mala receptová položka výsuvu preskočené VŠETKY členy, expanzia by vrátila prázdne `rows`, prázdne `unmapped`
  a cenu 0 — zásuvka postavená, nákup prázdny, Kontrola ticho (Astra #21 BLOCKER 3). `expand_members` preto sleduje, či vôbec niečo vydal, a pri položke so `source: 'recipe'`
  zapíše `members_skipped`, ktorý sa štandardnou cestou povýši na RED `drawer_kit_missing` s `blocks_export`. Preskočenie JEDNÉHO člena je legitímne. **Od KOV-G1a (Codex #337
  N1) nemlčí ani položka z PRAVIDIEL** — dostane ORANGE `members_all_skipped` (viď sekciu KOV-G1a nižšie); RED cesty receptu a výklopu sa nemenia.
- **Seed `SEED_VERSION` 4 → 5 (D-118b) — PRVÝ seed, ktorý MENÍ obsah existujúcich setov.** Tri veci: (1) `atira-antracit-h70-sisy` NL 470 **`348777` → `357889`** (348777 nie je
  K-sada — čelné kovanie treba dokúpiť, overené na produktovej stránke), (2) šesť Tip-On setov dostalo **druhý člen „PTOs mechanizmus"** (`352908` pre 30 kg, `352909` pre 50 kg
  kit H176/520, `none` pri NL 620) — K-sada ostáva PRVÝM členom, lebo completeness test KOV-C2a číta `members.first`, (3) legacy `vysuv-atira-biela-h70` sa premenoval na
  **„Výsuv (staré zákazky)"**. Doteraz vedel `merge_seed` iba DOPLNIŤ chýbajúci set, preto pribudol krok **`replace_untouched_seed_sets`**: nahradí LEN set, ktorého
  normalizovaný tvar je PRESNE niektorý predošlý seed tvar (`LEGACY_SEED_SHAPES`, teraz osem záznamov) — akákoľvek úprava používateľa (aj len premenovanie) znamená ruky preč
  a info log. **Projektové snapshoty sa nemenia SAMY**: hotová zákazka si nesie kódy, s ktorými bola objednaná. Do rozpracovanej ju dostane **vedomé „Doplniť nové predvoľby"** —
  a to od tejto dávky nielen dopĺňa chýbajúce kľúče, ale aj **osvieži definície, ktoré sú v snapshote ešte presne predošlým seed tvarom** (`refresh_untouched_project_sets`,
  tá istá podmienka „nedotknutý tvar" ako v knižnici; používateľom upravená definícia ostáva). **Zdrojom je NAČÍTANÁ globálna knižnica, nie konštanta `SEED_SETS`** — akcia
  kopíruje global do projektu, takže set zmazaný v globále sa nesmie vzkriesiť a vlastné globálne kódy sa nesmú prepísať zabudovaným seedom (Codex #321 kolo 2). Bez toho by akcia, ktorá má opravu priniesť, vrátila „nič sa nedopĺňalo"
  a zákazka by ďalej objednávala bez modulu (Codex #321 P1). Status akcie **pomenuje aj počet aktualizovaných setov** — tichá zmena objednávacieho kódu je zakázaná.
- **Kompatibilita vybraného setu (`set_incompatible_info`)** beží v `expand` AJ v `explain` (panel a súpis sa nesmú rozísť) hneď za `set_type_mismatch` a porovnáva
  `opening_mode`, `drawer_construction`, **`manufacturer` + `series` ↔ `params.system`** (uzavretý `SYSTEM_IDENTITY`: `atira` → Hettich/InnoTech Atira, `quadro_v6` →
  Hettich/Quadro; neznámy systém = fail-closed) a **`height_variant` setu ↔ `params.height_variant`** (presne, bez zaokrúhľovania). Bez toho by triedny kľúč sám nedokázal, že
  set patrí k TOMUTO systému a TEJTO výške — Antaro/StrongBox raz budú zdieľať `class:slide|classic|metal` s Atirou a pásmo H176 vs. H70 má rovnaké NL 470. Nesúlad =
  **nemapovaná položka s dôvodom, NIKDY iný set**; nové ORANGE dôvody `class_unmapped` a `set_incompatible` majú vety v `unmapped_reason_sk` aj vo
  `Validation.check_hardware_expansion`. Povýšenie na RED `drawer_kit_missing` prinesie C2b.
  **Dôvod (`detail`) prekladá JEDNA tabuľka `INCOMPATIBLE_DETAIL_SK`** cez `incompatible_detail_sk` — čítajú ju Nákup a panel (`unmapped_reason_sk` / `explain`),
  Kontrola (`Validation`, vrátane RED položiek závesov a výklopov) aj validácia override skrinky (`band_set_problem`); neznámy detail = fallback „iná klasifikácia"
  (`INCOMPATIBLE_DETAIL_FALLBACK_SK`), nikdy vymyslená veta. **Od v0.9.56 má metóda jedinú definíciu** — dovtedy boli v module dve (KOV-C2a tabuľka + inline hash
  z KOV-D1a), Ruby ticho brala druhú, takže tabuľka bola mŕtvy kód, `height_selector` (pevný `set_id` pre zásuvku s výškovým variantom) ostával bez vety „výber setu nie je
  podľa výšky zásuvky" a KOV-F1/E1a dopisovali každý detail na obe miesta. Duplicitné `def` stráži **AST guard** v `tests/pure/test_guards.rb` (`NxTest::DupDefs`): sken celého
  pluginu s kľúčom **plná cesta modulu + meno metódy**, takže duplicitu neschová ani znovuotvorený modul v inom súbore (`module Noxun::Engine::X` = vnorené moduly), `class << self`
  a `def self.x` sú jeden singleton scope (`class << KONST` iný), `module_function` (aj `module_function def x`) vytvára aj singleton kópiu, `private def x` sa skenuje ako holý
  `def`, dve definície vo **vzájomne výlučných** vetvách `if`/`unless`/`case` nie sú duplicita (nepodmienená + podmienená, dve v tej istej vetve alebo pod nezávislými `if` áno)
  a `def` v tele metódy sa neskenuje — hranice drží vlastný self-test. **Priznané limity:** `define_method`/`alias_method` scanner nesleduje; vetvy rozlišuje riadkom uzla
  `if`/`case` (dva nezávislé `if` na jednom riadku s definíciami v rôznych vetvách by bral ako výlučné). Úplnosť tabuľky (každý `detail` zo zdrojáku má vetu a naopak — kľúče sa čítajú z AST vrátane slučky
  nad `%w[…]`; symbolový kľúč `detail:` ani interpolovanú hodnotu scanner nevidí, v `hardware_sets.rb` sa nepoužívajú; `height_selector` end-to-end, rovnaký podmet vety
  v Nákupe aj Kontrole) stráži `tests/pure/test_incompatible_detail_sk.rb`.
  **Od v0.9.57 veta pri `height_selector` MENUJE odmietnutý pevný set.** Dovtedy znela v Nákupe, paneli aj Kontrole „set „“ nesedí so zásuvkou (výber setu nie je podľa
  výšky zásuvky)" — `resolve_set_id` vracal `set_id` nil a `unmapped_entry` preberal z `info` len `param value member_index member_label detail class_key`. Teraz resolver
  odmietnutý set posiela v **`info['set_id']`** (prvý prvok ostáva `nil`: set NIE JE účinný, nič sa z neho neobjedná, kontrakt `[nil, 'set_incompatible']` platí ďalej —
  `effective_flap_set` ani iné volania, ktoré čítajú len `sid`, sa nemenia) a `unmapped_entry` ho preberie **LEN keď resolver set nevybral (`sid` nil) a LEN ako neprázdny
  String** — účinný set má vždy prednosť a záznamy bez `set_id` v `info` (`class_unmapped`, `mapping_invalid`, `selector_unresolved`, …) ostávajú bez mena ako doteraz
  (golden fixtúry a testy C2a/D1a nezmenené). Platí pre obe úrovne (projektové mapovanie aj override skrinky). Selektor podľa **iného** parametra jeden set nemá, preto meno
  nenesie (zápisová cesta triedneho kľúča, `class_key_value_problem`, ho pre set s výškovým variantom aj tak odmieta). Stráži R6 v `tests/pure/test_incompatible_detail_sk.rb`
  (obe úrovne, prednosť účinného setu, neplatné hodnoty, mutácie M4 overené ručne).

Testy: `tests/pure/test_kovc2a_kanal_sety.rb` (23 testov + 4 overené mutácie vrátane completeness nad radmi receptov: pre KAŽDÚ bunku `nl_series_by_height`/`nl_series` každého
vydaného receptu existuje v seede set vybraný triednym kľúčom a v ňom kit kód).

**KOV-F1 (v0.9.48) — TRIEDA `hinge`, SENTINEL `none`, MIGRÁCIA MAPOVANIA.** Set závesu sa vyberá podľa **spôsobu otvárania čela** (Tip-On dvierka chcú
P2O set bez tlmenia + piest), takže pribudlo päť vecí:

- **Seed sety `zaves-klasik` / `zaves-p2o` sú KLASIFIKOVANÉ** (`use_type: 'door'`, `opening_mode: 'classic'|'tipon'`, Hettich Sensys) a
  `MAPPING_ADDITIONS` má **`class:hinge|classic` → `zaves-klasik`** a **`class:hinge|tipon` → `zaves-p2o`**. `SEED_VERSION` 5 → 6; do existujúcej
  knižnice aj snapshotu ich prenesie iba nedotknutý seed tvar (`LEGACY_SEED_SHAPES` + „Doplniť nové predvoľby").
- **Triedny kľúč `hinge` je DVOJSEGMENTOVÝ** (`class:hinge|<opening_mode>`, bez konštrukcie zásuvky). `class_set_match?` je jediné miesto, kde sa
  rozhoduje, či set patrí do ponuky triedy: pre `slide` platí doterajšie „musí mať systém a konštrukciu", pre `hinge` **„musí byť set na dvierka"** —
  požiadavka „vydaný systém zásuviek" by závesové sety z ponuky vyhodila úplne (Sol kolo 2 FIX 3). Tú istú vetvu má aj zápisová validácia
  `class_key_value_problem`. **Per-krídlo triedny override je MIMO F1**: `owner_scoped_class_head?` ho v parseri odmieta a UI ho neponúka (owner triedny
  kľúč ostáva výhradou zásuviek).
- **PRECEDENCIA závesu je PÄŤSTUPŇOVÁ**: override vlastníka (`hinge@front:F1/wing:left`) → **triedny override skrinky** → **generický override skrinky
  `hinge`** → triedny kľúč projektu → **legacy `hinge`**. Dva rozdiely oproti zásuvke sú vecné: vlastný set NA SKRINKE nikdy ticho nespadne na projektový
  default (Codex #327 kolo 2), a na konci reťaze stojí legacy `hinge` — bez neho by KAŽDÁ existujúca zákazka po prestavbe stratila závesy (položky sú
  odteraz klasifikované, ale snapshot triedny kľúč ešte nemá). Prázdny výsledok preto pri závese znamená dnešné `no_set`, nie `class_unmapped`.
- **Sentinel `MAPPING_NONE = { 'none' => true }` = „vedome bez setu".** Je to **samostatný kontrakt**, nie členská bunka `code_by_nl` (`SKIP_CODE` — zhoda
  reťazca je náhoda). Zmazať kľúč nestačí: pri reťazovej precedencii by chýbajúci kľúč znamenal „padni nižšie", teda presný opak voľby. **Je to HASH, nie
  reťazec (Codex #329 kolo 1):** `set_id` je ľubovoľný neprázdny reťazec, takže vlastný set s ID `none` (aj `NONE`) sú platné dáta — reťazcový sentinel by
  takú voľbu preklasifikoval na „bez nákupu", teda dvierka bez závesov. Hodnota mapovania je buď **reťazec** (= `set_id`), alebo **objekt** (= selektor),
  takže objektový sentinel sa s ID setu prekryť nemôže a **žiadna migrácia dát netreba**. Jediná autorita otázky je `mapping_none?` (presne jeden kľúč
  `none` s hodnotou `true`). Sentinel prežije `parse_mapping` (round-trip), `normalize_mapping`, resolver (`set_none` — vlastný dôvod, NIKDY set z nižšej
  úrovne) aj editor. **Zmrazenie ho musí kopírovať výslovne:** `global_default_state` (predvoľby nového projektu) aj `merge_project_sets_seed!`
  („Doplniť nové predvoľby") preskakujú mapovanie s prázdnym zoznamom referencií — a sentinel na žiadny set neukazuje, takže bez vlastnej vetvy by z oboch
  ciest **vypadol** a projekt by spadol na legacy `hinge` (Codex #329 kolo 1). Kopíruje sa kľúč, definície nie je čo. **Nový `std` marker k tomu nepatrí:**
  starší plugin sentinel nepozná, ale obe cesty zlyhajú zatvorene a s hláškou — knižničná brána `incompatible_mapping_entry?` → „aktualizuj plugin",
  snapshot `norm_map.length != mapping.length` → `:invalid`.
- **UI rozlišuje „nenastavené" a „vedome bez setu" (Codex #329 kolo 1).** Riadok triedneho mapovania nesie `unset_label` (prázdna hodnota = kľúč sa zmaže,
  pri závese sa **dedí legacy `hinge`**, takže nákup závesy MÁ), `none_label` + `none_value` (TOKEN voľby v selecte) a `none_send` (**HODNOTA**, ktorú JS
  pošle späť — panel doménovú hodnotu nikdy neskladá sám). Jedna spoločná voľba by pri chýbajúcom kľúči tvrdila „vedome bez setu", hoci závesy sa objednajú.
- **Migrácia `hinge_class_v1` je JEDNORAZOVÁ** (`migrate_hinge_classes!` v `ensure_project_state!`, značka v poli `migrations` snapshotu):
  `class:hinge|classic` = **účinné legacy mapovanie projektu** (kto má vlastný záves, ten si ho podrží; neklasifikovaný set kľúč NEVYROBÍ a položky idú
  legacy cestou + ORANGE poznámka `hinge_set_unclassified` v novom aditívnom kľúči `expansion['notes']`), `class:hinge|tipon` = `zaves-p2o`, ale **len keď
  používateľ vlastný Tip-On set nemá**. Existujúci kľúč sa **NIKDY neprepíše**.

**Nesúlad klasifikácie závesu je RED, nie ORANGE.** `hinge_incompatible_info` rozlišuje dva stavy: **nezaradený (legacy) set nie je nesúlad** — je to stav
pred KOV-F1 a nákup beží ďalej (kódy set má), len sa prizná ORANGE poznámkou; **definitívny nesúlad** (klasifikovaný set, ktorý čelu odporuje — Tip-On čelo
na klasickom sete, alebo set, ktorý nie je na dvierka) je `HINGE_SET_MISMATCH` = **RED**, položka ostáva NEMAPOVANÁ a export stojí — tlmený záves bez piestu
by znamenal dvierka, ktoré sa nedajú otvoriť tak, ako sú navrhnuté. Dôvod vzniká pri **EXPANZII** (teda aj po zmene mapovania bez prestavby), preto ho
exportná brána číta z `expansion['unmapped']` rovnako ako `drawer_kit_missing` (Codex #327 kolo 3). **Set NESPRÁVNEHO TYPU je pri dvierkach ten istý
prípad (Codex #329 kolo 1):** vetva `set['generic_type'] != gt` v `expand` beží **skôr** než kontrola klasifikácie, takže set na nohy pod závesovým kľúčom
(mapovanie zo šablóny + vlastná definícia projektu) by skončil ako ORANGE `set_type_mismatch` a nákup bez závesov by odišiel von. Pre `door_item?` sa preto
hlási `HINGE_SET_MISMATCH` s `detail: 'generic_type'`; položka bez klasifikácie (legacy zákazka) ostáva na pôvodnom ORANGE.

**Door guardy sa berú z PRVÉHO pravidla s daným `rule_id` (Codex #329 kolo 1).** `evaluate` pri duplicitnom `rule_id` použije prvé pravidlo (druhé prizná
ORANGE `hardware_rule_duplicate` a preskočí), takže index `by_rule` v `door_guards` musí byť **first-entry-wins** — zápis „posledný vyhráva" by priniesol
guardy z pravidla, ktoré položku vôbec nevydalo (falošná RED nadvýška alebo naopak potlačené varovania).

Testy: `tests/pure/test_kovf_zavesy.rb` (39 testov, 21 pomenovaných mutácií) + JS `tests/js/test_kovf_ui.js` (dve prázdne voľby riadku, sentinel ako
hodnota zo servera) + in-SketchUp sekcia `run_kovf`.

**KOV-E1a (v0.9.53) — VÝKLOPY: DVA NOVÉ TVARY ČLENA, `lift_system`, OWNER `/flap`, BRÁNA ÚPLNOSTI.** Výklop je ZOSTAVA (mechanizmus + čelný príchyt + krytky, pri Tip-One
navyše jednotka, pri HL top ramená a stabilizačná tyč), a mechanizmus sa vyberá podľa TRIEDY, ktorú spočíta pravidlo (`vyklopy-aventos` príde v E1b). Preto:

- **Člen setu má odteraz ŠTYRI spôsoby, ako určiť kód** (XOR — práve jeden): pevný `code` · rad `code_by_nl` · pásma `param_bands` · **`code_by_param`**
  = `{ "param": "lift_class", "codes": { "22K2300": "347810", … } }`. Kľúče sú REŤAZCE a zhoda je PRESNÁ (`text_param` → `strip`, nikdy zaokrúhlenie ani „najbližší" kód —
  tá istá filozofia ako „presný NL kľúč, nikdy sused"). **Chýbajúci kľúč je VŽDY chyba**: sentinel `SKIP_CODE` sa sem NEDEDÍ, lebo výklop nemá „vedome bez kódu" — mechanizmus,
  ktorý sa nenašiel, znamená neúplnú zostavu, nie zámer.
- **`quantity_from` = POČET Z PARAMETRA položky** (`"rod_count"`). Je to NEZÁVISLÉ od spôsobu určenia kódu (tyč má pevný kód a premenlivý počet), preto vlastný kľúč a nie
  ďalší druh v XOR. Hodnota musí byť **celé nezáporné číslo**: `0` = **člen sa VEDOME NEVYDÁ** (rozhodne sa PRED `add_row`, takže riadok s počtom 0 vôbec nevznikne — `finalize`
  ho nezahadzuje; HL top pod šírkou korpusu 1100 mm teda nemá riadok `507366` vôbec), chýbajúca, necelá alebo záporná hodnota = **nevyriešený člen** (`quantity_unresolved`).
  Kombinuje sa s `per: 'owner'` — tyč je na ČELO, nie na kus, takže dve pravidlá s výstupom `lift` na jednom čele ju nezdvoja (existujúci dedup `(korpus, vlastník, set, kód)`).
  **PORADIE JE KONTRAKT (Codex #332 kolo 1 P2):** počet sa vyhodnocuje PRED `member_code` — v `expand_members` aj v `explain_members`. Člen, ktorý sa vedome nevydá, svoj kód
  rozlíšiť NEMUSÍ; opačné poradie by pri predlžovacom diele s počtom 0 hlásilo chýbajúcu triedu (RED `lift_set_incomplete`) na zákazke, kam ten diel vôbec nepatrí.
- **KLASIFIKOVANÝ VÝKLOP BEZ SYSTÉMU JE NEPLATNÁ KLASIFIKÁCIA, nie legacy položka (Codex #332 kolo 3 P1).** Keď položka nesie `params.use_type == 'lift'`, ale triedny kľúč
  z nej nevznikne (chýba `lift_system` alebo `opening_mode`), `resolve_set_id` sa zastaví HNEĎ — vlastným dôvodom **`lift_system_missing`** (bránou vyššie teda RED
  s `blocks_export`) a bez toho, aby sa vôbec pozrel do mapovania. Prepad na generický `lift` by v prestavanej zákazke, ktorá si legacy mapovanie oprávnene drží, ticho
  vydal LEGACY set — teda kovanie, o ktorom nikto nedokáže, že k systému čela patrí. **Veta menuje OBA dôvody** („výklop nemá určený spôsob otvárania alebo systém
  (HK top / HL top)" — interná delta P3): chýbať môže otváranie aj systém a hláška o samotnom systéme by posielala opravovať pole, ktoré je v poriadku. Je JEDNA
  a rovnaká v Nákupe (`unmapped_reason_sk`), v Kontrole (`Validation`) aj v mape detailov (`incompatible_detail_sk` nad jedinou tabuľkou `INCOMPATIBLE_DETAIL_SK`
  — od v0.9.56 má metóda jedinú definíciu, viď odsek KOV-C2a vyššie).
  Rovnaký dôvod má aj `set_incompatible_info`, ale **DNES je tá vetva nedosiahnuteľná** (expanzia aj súpis zastanú skôr v `resolve_set_id`, `band_set_problem` beží
  len nad existujúcim triednym kľúčom) — necháva sa ako fail-closed poistka pre budúce volanie, nie ako „tá istá odpoveď na zápisovej ceste".
  **Legacy výklop (bez `params.use_type`) sa tým NEMENÍ** — ide dnešnou generickou cestou. (Pozor na dve rôzne veci: grandfather
  z kola 2 sa týka SETU bez `lift_system` pri ČÍTANÍ knižnice; toto je POLOŽKA. Obe sú fail-closed smerom k exportu.)
- **BRÁNA ÚPLNOSTI `lift_set_incomplete` (Astra BLOCKER 1).** Pri položke s `generic_type == 'lift'` sa **KAŽDÝ** dôvod nemapovania povýši na RED s `blocks_export`
  (`unmapped_entry`, presný vzor receptového `drawer_kit_missing`) — vrátane chýbajúceho setu a chýbajúceho mapovania; pôvodný dôvod cestuje v `base_reason`. Riadky ostatných
  členov v zozname **ostávajú** (rovnako ako pri zásuvke), ale von sa nedostanú: kód je v `BuildPlan::HW_LIFT_BLOCKERS` aj vo `from_expansion`
  (`ProductionCore.hardware_blockers`), takže nákup kovania, rozpočet aj cenová ponuka STOJA a „krytky bez mechanizmu" NIKDY neopustia plugin. **VEPO beží ďalej** — geometria
  čela je správna (tá istá úvaha ako pri závesoch). Vetu skladá `Validation.lift_incomplete_sentence` (RED, kategória `hardware_incomplete`) a menuje čelo, systém aj člena;
  `lift_incomplete_item` z nej robí nález Kontroly a **kartu čela v Inspectore ňou hovorí `Panel.lift_incomplete_note`** — jedno znenie, dva odbery (Codex #334 kolo 2 P2).
  Kontrola vetu predsadí **lokátorom** skrinky (je to zoznam cez celý projekt), karta nie (stojí v tej skrinke); dôvod a náprava sú slovo za slovom rovnaké.
  Aby karta o závažnosti vôbec vedela, vracia `explain` popri preložených `problems` aj **surové záznamy `unmapped`** (aditívny kľúč, `explain_problem` ich zapisuje **naraz**,
  takže sa nemôžu rozísť) — z preloženej vety sa RED od ORANGE odlíšiť nedá.
  **Set, ktorý nevydal ANI JEDEN riadok, je RED tiež** (Codex #332 kolo 2 P2): nula je platné vynechanie JEDNÉHO člena, ale keď na nulu vyjdú VŠETCI členovia
  (alebo ich set preskočí), expanzia by vrátila 0 riadkov aj 0 nemapovaných a exporty by prešli s výklopom BEZ kovania. Fallback `members_skipped` (dovtedy
  len pre receptové položky) preto platí aj pre `generic_type: lift` — v `expand_members` aj v `explain_members`, aby sa panel a súpis nerozišli — a
  štandardnou cestou sa povýši na RED `lift_set_incomplete` s `blocks_export`. Veta (Nákup aj Kontrola) hovorí o POČTOCH, nie o dĺžke: „set X nevydal pre
  tento výklop ani jednu položku". **Dedup `per: 'owner'` sa počíta ako VYDANÉ** (Codex #332 kolo 4 P2): keď set zložený len z členov na vlastníka
  vydá zostavu prvým pravidlom, druhé pravidlo na tom istom čele nájde všetkých členov v `owner_seen` a nepridá nič — to NIE JE prázdny set a fallback
  sa naň nevzťahuje (inak by RED zastavil export nad KOMPLETNOU zostavou).
  **Dôvod `class_unmapped` má DVA zdroje a DVE nápravy** (Codex #332 kolo 1 P2) — rozlišuje ich `HardwareSets.class_unmapped_lift?`, JEDNA autorita pre Nákup
  (`unmapped_reason_sk`) aj pre vetu Kontroly: **resolver-level** (chýba triedny kľúč `class:lift|…`; záznam nesie `class_key` a nemá `param` ani `set_id`) → „výklop nemá
  predvolený set — Pravidlá → Doplniť nové predvoľby", **member-level** (`code_by_param` bez kódu triedy; `param` aj `set_id` sú prítomné) → „set X nemá kód pre …".
  Bez rozlíšenia znela veta „set „“ nemá kód" a Nákup ju označoval ako zásuvku.
- **Klasifikačné pole `lift_system` (`hk_top` | `hl_top`)** je **POVINNÉ pri `use_type: 'lift'` a ZAKÁZANÉ inde** — presne tá istá logika ako `drawer_construction` pri zásuvke
  (sklop `fall` systém nemá, vzpery sú mimo V1). Je v `CLASS_KEYS`, `SET_KEYS`, `SET_KEY_ORDER`, `CLASS_OPTIONS` aj vo whitelistoch šablón; jeho stratu chytá **vlastná vrstva**
  v `classification_lost?` (kontrola „žiadny klasifikačný kľúč" by ju prehliadla, a bez systému by HL set vyzeral ako HK).
  **Povinnosť platí LEN pri ZÁPISE — čítanie legacy tvar UZNÁVA** (Codex #332 kolo 2 P1). Set `use_type: lift` bez `lift_system` mohol vzniknúť vo v0.9.52
  (pole vtedy neexistovalo); keby nová povinnosť platila aj pri čítaní, `read_set_classification` by klasifikáciu zahodila, `classification_lost?` by celý
  súbor označil za nekompatibilný (knižnica read-only, snapshot `:invalid`) a používateľ by sa z toho nedostal. `classify` má preto prepínač `legacy_lift:` —
  zapína ho VÝHRADNE čítacia cesta: klasifikácia ostane platná a systém je „neurčený" (kľúč sa neuloží). Taký set triednemu kľúču `class:lift|…|hk_top` NIKDY
  nesadne (porovnanie s prázdnym reťazcom zlyhá), ostáva použiteľný cez legacy generické mapovanie `lift` a v editore sa dá dopracovať: modal má pri
  `use_type: lift` **select „3 · Systém výklopu"** (`hw_sets.js`, presný vzor `drawer_construction` pri zásuvke), ktorý sa posiela VŽDY (aj prázdny —
  `save_set!` merguje) a `validate_set` ho pri zápise stále VYŽADUJE.
- **Triedny kľúč `lift` je TROJSEGMENTOVÝ a tretí segment znamená INÉ než pri zásuvke:** `class:lift|<opening_mode>|<lift_system>`. `parse_class_head` preto validuje tretí
  segment PODĽA TYPU (`slide` → konštrukcia, `lift` → systém) a **`class:lift|tipon|hl_top` ODMIETA** vetou „HL top Tip-On neexistuje" (Blum ani Démos ho nemajú). Platné kľúče
  sú tri a všetky sú v `MAPPING_ADDITIONS` (add-if-absent, existujúca voľba sa nikdy neprepíše): `class:lift|classic|hk_top` → `vyklop-hk-klasik` · `class:lift|tipon|hk_top`
  → `vyklop-hk-tipon` · `class:lift|classic|hl_top` → `vyklop-hl-klasik`. Ponuku filtruje `class_set_match?` vetvou pre `lift` (typ použitia + systém; požiadavka „vydaný systém
  zásuviek" sa výklopu netýka) a zápis stráži `class_key_value_problem`. **Doplnenie predvoľby overuje DEFINÍCIU, nielen existenciu `set_id`** (Codex #332 kolo 1 P1,
  `mapping_seed_ref_ok?`): knižnica mohla mať pod tým istým ID vlastný, nezaradený set — `merge_seed` ho správne nechá tak, a default sa mu preto NENASADÍ. Referencia musí
  sedieť tou istou autoritou, akou sa set ponúka v Pravidlách (`class_set_match?` = typ použitia + otváranie + tretí segment) a jej členovia musia byť čitateľní
  (`incompatible_member?`). Nesediaca definícia = kľúč sa nedoplní a položka skončí `class_unmapped` (brána + veta „Doplniť nové predvoľby"), nikdy tichý zlý nákup.
  **Predikát je JEDEN a beží na KAŽDEJ ceste, ktorá predvoľbu inštaluje** (`mapping_seed_value_ok?` — Codex #332 kolo 4 P1): čerstvá knižnica (`seed_library`), seed-merge
  knižnice (`add_mapping_seed`), snapshot nového projektu (`global_default_state`) aj „Doplniť nové predvoľby" (`merge_project_sets_seed!`) — a vyhodnocuje sa nad definíciou,
  ktorá bude ÚČINNÁ V CIEĽOVOM dokumente: snapshot si vlastnú definíciu s rovnakým `set_id` ponechá, takže kontrola nad knižnicou by bránu obišla. Vedomé zápisy (Pravidlá,
  šablóna, lazy migrácia závesov) ostávajú na zápisovej autorite `class_key_value_problem` nad TÝM ISTÝM cieľovým dokumentom.
  **Príznak `active` do tejto brány NEVSTUPUJE** (`class_set_match?(…, ignore_active: true)` — interná delta P2): invariant KOV-B3 hovorí, že neaktívnosť mení
  VÝHRADNE ponuky NOVÉHO výberu. Keby rozhodovala aj o inštalácii predvoľby, deaktivovanie setu v knižnici by bola **slepá ulička** — kľúč by v nej ostal, nový
  projekt ani „Doplniť nové predvoľby" by ho nedostali a každý taký výklop by skončil RED `lift_set_incomplete` bez cesty von. Rozhoduje teda len klasifikácia
  (typ použitia + otváranie + tretí segment) a čitateľnosť členov; kolízia s NEZARADENOU definíciou ostáva odmietnutá aj pri neaktívnom sete.
- **OWNER kľúč `@front:<id>/flap`** (tak sa vyberá TMAVÝ set pre JEDNO čelo — UI príde v E2). `CLASS_OWNER_RE` pozná `panel|flap` a **`CLASS_OWNER_PART` páruje triedu s dielcom**
  (`slide` → `panel`, `lift` → `flap`): krížom by kľúč ukazoval na dielec, ktorý tá trieda nikdy nemá, a resolver by ho nikdy neprečítal. Parse, zápisová validácia, resolver aj
  pruning zmazaného čela sa `/flap` naučili v JEDNEJ dávke (Astra FIX 6). K tomu patrí **`CabinetBuilder::CONFIG_SCHEMA` 9 → 10**: owner mapovanie je perzistentná hodnota
  v `config.hardware_sets`, ktorú by starší plugin (jeho `parse_class_key` `/flap` nepozná) pri prestavbe ticho zahodil a čelo by dostalo biely set (Codex #331 kolo 2 P1).
- **Šesť seed setov** `vyklop-hk-klasik{,-tmavy}` · `vyklop-hk-tipon{,-tmavy}` · `vyklop-hl-klasik{,-tmavy}` (`SEED_VERSION` 6 → 7). Poradie členov je ZÁVAZNÉ — **mechanizmus je
  PRVÝ** (súpis aj nákup začínajú tým, čo výklop naozaj drží). Farba NIE JE klasifikačné pole (Démos ju nesie len v názve položky), takže tmavý set **triedny kľúč nemá** —
  vyberá sa per čelo. Do existujúcej knižnice ich prenesie `merge_seed` (doplní CHÝBAJÚCE), do projektu vedomé „Doplniť nové predvoľby"; set s rovnakým `set_id` od používateľa
  sa nikdy neprepíše.
- **`std` 6 (`STD_LIFT_FORMS`) — FAIL-CLOSED downgrade.** Marker je LAZY podľa obsahu (`lift_forms_present?`, testuje sa ÚPLNE PRVÝ — najvyšší vyhráva) a dostane ho len obsah,
  ktorý naozaj nesie `code_by_param`, `quantity_from` alebo `lift_system`. Starší čítač taký set **ODMIETNE** (`incompatible_member?` cez whitelist `MEMBER_KEYS`,
  `assess_set_defs` pri šablóne) → knižnica/snapshot/šablóna sú preň len na čítanie s hláškou „aktualizuj plugin". **Tiché „tyč 1 ks" NEEXISTUJE** — správanie je odmietnutie
  a testuje sa charakterizáciou so simulovaným starým `MEMBER_KEYS` (Astra FIX 8).
- **Editor setov nové tvary UPRAVUJE (KOV-E2; read-only režim z E1a ZANIKOL).** E1a člena novšieho tvaru nerozoberala na polia, len ho odkladala celý (`is_locked` + `raw`),
  dlaždica mala vypnuté „Upraviť" a vetu „úprava príde neskôr" — po E2 by tá veta klamala a set výklopu by sa nedal opraviť. Odteraz je **stratégia kódu select so ŠTYRMI
  voľbami** (`HWS_KINDS` + `param`); pri „podľa triedy položky" pribudne **výber parametra** (`lift_class` / `arm_class` / „iné (vypíšem)" — `hwsParamSplit`/`hwsParamJoin`,
  sentinel `__other__` sa na server **nikdy** neposiela) a tabuľka **hodnota → kód** (`hws-c-add`/`hws-c-del`; poradie tried sa **netriedi** — „22K2300" nie je číslo
  a abecedné poradie by tabuľku Blumu preusporiadalo). **„Počet z parametra"** (`quantity_from`) je **druhý riadok hlavičky člena**, nie štvrtá otázka v prvom rade (ten je
  už plný a piaty ovládač by ho pretiekol), a je **nezávislý od stratégie kódu** — prepnutie kódu ho nezahadzuje (tyč má pevný kód a premenlivý počet). Úplne prázdny riadok
  tabuľky sa zahadzuje (vzor radu NL), **čiastočne vyplnený ide na server**, aby používateľ dostal konkrétnu vetu: validácia je all-or-nothing na SERVERI
  (`validate_member` / `validate_code_by_param`) a HTML `disabled` nie je ochrana. **Jediná výnimka z „autoritou je server" je DUPLICITNÁ hodnota v tabuľke člena**
  (`hwsMemberProblems`, Codex #334 kolo 1 P2): `code_by_param.codes` aj `code_by_nl` idú na server ako **mapa**, takže druhý riadok s tou istou triedou (dĺžkou) prepíše
  prvý už pri skladaní payloadu — server duplicitu **nikdy neuvidí**, uloženie prejde a prvé priradenie po refreshi ticho zmizne. Kontrola preto beží nad **poľom riadkov**
  pred zložením mapy a chyba pristane pri tom členovi. **Druhá výnimka z toho istého dôvodu je PRÁZDNY vlastný názov parametra** (Codex #334 kolo 2 P2): voľba
  „iné (vypíšem)" žije **len v editore** a `hwsParamJoin` z nej pri prázdnom texte spraví prázdny reťazec — pri `quantity_from` sa kľúč do payloadu **vôbec nezapíše**,
  takže server dostane platného člena s **pevným počtom**, uloží ho bez slova a voľba po refreshi ticho zmizne; pri `code_by_param` odíde prázdny `param`, ktorý server
  síce odmietne, ale nepovie, ktorý člen a ktorá voľba to spôsobila. Obe stráži klient, kým ešte vidí **stav editora** (select + textové pole), nie až jeho výsledok. Súhrn člena aj živý náhľad nové tvary čítajú („podľa lift_class",
  „počet podľa rod_count"); `preview_expansion` si vzorovú triedu a počet doplní z DRAFTU, takže náhľad neukazuje samé ORANGE riadky.
  **Súhrn skladá KÓD a POČET NEZÁVISLE (Codex #332 kolo 3 P2):** `hwsMemberCodeText` (jedna zo štyroch stratégií `code` | `code_by_nl` | `param_bands` | `code_by_param`)
  + `hwsMemberQtyText` (`quantity_from`, inak `×qty`). Skorý return podľa stratégie zamlčal dynamický počet, resp. pri rade NL a pásmach vypísal `m.code` (`undefined`)
  a kódy schoval — a súhrn je pritom to, čo používateľ číta v dlaždici setu bez otvárania editora. Pri výpise kódov sa samozrejmé „×1" vynecháva (bol by
  to len šum za posledným kódom radu) a `per: 'owner'` sa píše neutrálne **„na vlastníka"** — od výklopov je vlastníkom aj `front:F#/flap`, nie len dvierka.
- **Dočasná ZÁPISOVÁ brána z E1a ZANIKLA (KOV-E2).** `save_set!` odmietal zmenu členov setu, ktorý nesie nový tvar (`new_shape_members?`), lebo editor pre ne neexistoval —
  po E2 by bola jedinou prekážkou opravy setu výklopu (zmenený kód triedy v Démose, nová trieda). Ochranou ostáva to, čou bola vždy: **validácia obsahu**
  (`validate_set_detailed` → XOR stratégií kódu, úplnosť tabuľky tried, názov parametra), nie zákaz zápisu.

Testy: `tests/pure/test_kove1a_data.rb` (34 testov, 25 pomenovaných mutácií vrátane golden charakterizácie „existujúca zákazka nakupuje presne ako pred dávkou")
+ `tests/pure/test_kove2_ui.rb` (zápis zmeneného člena setu výklopu prejde, nezmysel neprejde)
+ JS `tests/js/test_hw_sets_code_by_param.js` (bezstratový round-trip cez editor, editovateľnosť, „iné (vypíšem)", súhrn vrátane 4 kombinácií kód × `quantity_from`).


**KOV-G1a (v0.9.58) — NOHY 17–220 mm, SENTINEL V KÓDOVOM PÁSME, TYP `plinth_clip`.** Rozhodnutia Michala 9.9.2026 sú dátové, nie behové (pravidlo počtu nôh 4/6 a pravidlo
príchytu prináša až G1b):

- **Seed `nohy-podla-sokla` má NOVÝ TVAR (`SEED_VERSION` 7 → 8).** Člen **noha** má sedem pásiem (`17–20 → 272212` STRONG klzák · `55–90 → 9069` · `91–115 → 9078` ·
  `116–140 → 9077` · `141–170 → 9076` · `171–190 → 9027` · `191–220 → 9075` Häfele AXILO) a pribudol druhý člen **platnička** (`17–20 → none` · `55–220 → 9079`), lebo
  platnička sa skrutkuje do dna ku KAŽDEJ nohe AXILO. **Zóna 20–55 mm je VEDOME nepokrytá** (nič vhodné neexistuje) a hlási sa existujúcou cestou `param_band_missing` →
  ORANGE `hardware_unmapped` s vetou o **výške sokla**. Pásma sú **celočíselné rozsahy s hranicami VRÁTANE**, takže neceločíselná výška medzi nimi (90,5) je tiež ORANGE —
  vedomá vlastnosť, nie diera: výšky sokla sú v praxi z rozmerového radu a „najbližšie pásmo" by objednalo inú nohu (tá istá filozofia ako presný kľúč radu NL, nikdy sused).
  Pri 90,5 pritom **platnička kód MÁ** (jej pásmo 55–220 je spojité) — ORANGE dostane len noha, a to je presne tá veta, ktorú má človek vidieť.
- **`none` v KÓDOVOM PÁSME `param_bands` = „v tomto pásme člen vedome nevznikne"** — tá istá sémantika ako v rade `code_by_nl` (D-118b): `member_code` vráti `[nil, nil]`,
  žiadny riadok a **ŽIADNY nález**. Rozdiel oproti CHÝBAJÚCEMU pásmu (ORANGE) je zámer. D-118b to tu ešte **zakazovalo**, a to z jediného dôvodu: `skip_code_present?` sa
  na pásma nepýtalo, takže by obsah dostal nižší marker a starší plugin by z bunky vyrobil nákupný riadok s neexistujúcim kódom „none". Predikát ich odteraz prehľadáva
  (`member_skip_code?`), takže **marker `std` 5 platí pre obe miesta** a nový marker netreba. Ako **pevný `code`** ostáva `none` zakázané (člen, ktorý nikdy nič nevydá, je
  tichý nezmysel) a v selektore mapovania (`set_id`) sa nekontroluje vôbec (tam je to legitímne meno setu). Hodnota sa ukladá **kanonicky malými písmenami**; súpis (`explain`)
  preskočeného člena **prizná** („bez kódu (netreba)") a editor v `hw_sets.js` ho v súhrne píše ako **„bez kódu"** (v selektore setov NIE — tam by to klamalo).
- **Člen musí mať aspoň JEDEN skutočný kód — pri PÍSANÍ setu** (Codex #337 N1, spresnené kolom 2). Sentinel hovorí „TU žiadny kód nepatrí"; keď ho má člen vo VŠETKÝCH pásmach
  (alebo v celom rade `code_by_nl`), je to člen, ktorý nikdy nič neobjedná — ten istý tichý nezmysel ako pevný `code: none`. `validate_param_bands` aj `validate_code_by_nl` taký
  tvar **odmietajú LEN pod príznakom `authoring: true`**, ktorý nesie `validate_set_detailed` z jediných dvoch miest, kde set píše používateľ: **`save_set!`** a jeho náhľad
  **`preview_expansion`** (aby náhľad nehovoril niečo iné než uloženie). **Editor to povie ešte skôr** (`hwsMemberProblems` → `hwsAllSkip`, „všetky kódy sú „none"" pri TOM
  členovi) — a beží tiež len pri odoslaní, takže JS zrkadlo a server sedia.
  **Prečo NIE aj pri čítaní (Codex #337 kolo 2 N1):** verzie, ktoré sentinel zaviedli, takého člena uložiť DOVOLILI — často vedľa úplne normálnych členov. Keby ho tolerantné
  čítanie (`normalize_sets` → `validate_member`) zahodilo, detektor `members_lost?` by uvidel zmenu počtu a **celá** knižnica by sa stala `:read_only` (projektový snapshot
  `:invalid`, šablóna `:lossy`) — používateľ by prišiel o všetky sety kvôli jednému členovi, a to ešte predtým, než by mu behová poistka `members_all_skipped` stihla čokoľvek
  povedať. Z toho istého dôvodu kontrolu **NEMÁ ani hromadný prepis už uloženého obsahu** (`validate_sets` → `write` pri seed-merge a `write_project_state` pri zmrazení
  snapshotu): tie len ukladajú, čo v knižnici už je, a odmietnutie by projekt nechalo navždy bez snapshotu. Opravu si teda vyžiada až prvý pokus ten set **uložiť z editora**.
- **Keď set nevydá pre BEŽNÚ položku ANI JEDEN riadok, je to viditeľný ORANGE `members_all_skipped`** (Codex #337 N1). Doteraz mali fail-closed fallback len receptová zásuvka
  (RED `drawer_kit_missing`) a výklop (RED `lift_set_incomplete`); položka z pravidiel — napríklad **noha** — skončila s prázdnym nákupom a **BEZ jediného dôvodu**, takže
  nákup, Kontrola aj cenová ponuka o tom kovaní nepovedali ani slovo. Vlastný dôvod (nie `members_skipped`) preto, že ten cestuje v `base_reason` receptu (veta o DĹŽKE) a
  výklopu (veta o POČTOCH) — spoločné znenie by pri jednom z nich klamalo. Veta menuje pásma a kódy („set … nevydal pre túto položku ani jeden riadok"), Kontrola je ORANGE
  (nenacenené, export beží ďalej) a **súpis v karte hovorí to isté** (`explain` ide tou istou cestou — panel a súpis sa nesmú rozísť).
- **Nový generický typ `plinth_clip` („Príchyt sokla")** v `BuildPlan::GENERIC_TYPES` + seed set **`prichyt-sokla-axilo`** (`use_type: other`, `opening_mode: other`,
  Häfele/AXILO, jediný člen `950 ×1 per unit`) + mapovanie `plinth_clip → prichyt-sokla-axilo` v `SEED_MAPPING` (čerstvá knižnica) **aj v `MAPPING_ADDITIONS`** (add-if-absent
  do už založenej knižnice a — cez „Doplniť nové predvoľby" — do projektu). Precedens je `lift` z KOV-B1: **`BuildPlan::SCHEMA` 4 → 5**, lebo položka s neznámym typom je pre
  starší plugin dôvod zastaviť prestavbu (`guard_unknown_hardware!`), a set aj mapovanie s ním odmietnu existujúce brány — knižnica `:read_only`, snapshot `:invalid`,
  šablóna `:lossy` (`normalize_sets` set neznámeho typu zahodí a detektor straty to vidí). **Bez pravidla položka nevzniká** — to je v poriadku a rovnaké ako sety výklopov
  pred KOV-E1b.
- **Generický kľúč sa doplní LEN na set TOHO TYPU** (Codex #337 N4, `mapping_seed_ref_ok?` → `generic_type_ref_ok?`). Pri NEtriednom kľúči stačila doteraz samotná PRÍTOMNOSŤ
  `set_id` — a to prestalo stačiť vo chvíli, keď `MAPPING_ADDITIONS` dostali generický kľúč: používateľ už môže mať vlastný set s ID `prichyt-sokla-axilo`
  a `generic_type: 'hinge'` (`merge_seed` mu ho správne nechá), predvoľba by mu aj tak sadla a každý príchyt by skončil `set_type_mismatch` namiesto objednaných kusov. Typ sa
  z kľúča číta JEDINÝM parserom (`BuildPlan.parse_hardware_set_key`, teda aj tvar `leg@front:F1/panel`); neznámy tvar = kľúč sa nedoplní. Brána je spoločná pre knižnicu,
  snapshot nového projektu aj „Doplniť nové predvoľby" (`mapping_seed_value_ok?`) a odmietnutie sa **loguje** (`add_mapping_seed`), aby po upgrade nechýbala predvoľba bez stopy.
- **`CLASS_MAPPING_KEYS` už NIE JE celý `MAPPING_ADDITIONS`**, ale jeho podmnožina s prefixom `class:`. `plinth_clip` je generický kľúč (príchyt spôsob otvárania nemá) a do
  tabuľky TRIEDNYCH mapovaní v Pravidlách nepatrí: `class_key_label` by mu vrátil `nil` (riadok bez popisku) a `class_set_options` by ho rozkladala ako triedny kľúč. Svoj
  riadok má medzi generickými typmi (`generic_types` z `BuildPlan::GENERIC_TYPES`).
- **Klasifikácia seed setu sa pred inštaláciou overí proti ŽIVEJ taxonómii** (Codex #337 N3, `seed_sets_resolved`). Seed sety nesú dvojicu výrobca/rada natvrdo
  (Hettich/Sensys, Blum/AVENTOS, Häfele/AXILO), ale taxonómia cudziu väzbu rady **zámerne zachováva**: keď má používateľ radu naviazanú na vlastného výrobcu, naša dvojica
  v jeho taxonómii NEEXISTUJE. Hromadný zápis seedu `taxonomy_refusal` nevolá (tá je pre VEDOMÝ zápis jedného setu), takže by sa taká klasifikácia do knižnice uložila a
  **každá neskoršia úprava toho setu cez `save_set!` by skončila hláškou „rada … patrí výrobcovi …"** — set by sa nedal ani opraviť. Preto: keď `HardwareTaxonomy.series_owner`
  povie, že rada patrí INÉMU výrobcovi, odchádza zo setu **CELÁ klasifikácia** (je all-or-nothing — set bez výrobcu je neplatný tvar, nie „polovične zaradený") a set sa
  nainštaluje ako **nezaradený** + info log. **Kódy a typ sa nemenia**, takže nákup ide ďalej; nesadne mu len TRIEDNA predvoľba (`mapping_seed_ref_ok?`) — fail-closed, presne
  ako pri každej inej nesediacej definícii. Keď sa taxonómia čítať nedá alebo radu ešte nepozná, klasifikácia **ostáva** (seed taxonómie ju vzápätí doplní a jej odobratie by
  zbytočne odpojilo triedne predvoľby závesov a výklopov). Rovnaká, jediná sada ide do VŠETKÝCH seed ciest — `seed_library` (čerstvá inštalácia), doplnenie chýbajúceho setu,
  `replace_untouched_seed_sets` aj `migrate_mapping` (inak by set, ktorému taxonómia zaradenie odobrala, už nikdy „nesedel s naším seedom" a migrácia by stála).
- **PORADIE: taxonómia sa doseeduje PRED klasifikáciou seed setov** (Codex #337 kolo 2 N2). `seed_sets_resolved` volá na začiatku `HardwareTaxonomy.ensure_seeded`. Pri bežnom
  upgrade z taxonómie **v2** je v uloženom zápise rada AXILO ešte pod **Hettichom** — pod Häfele ju presunie až migrácia `migrate_axilo_owner!` vo vnútri `ensure_seeded`,
  a `series_owner` ju **zámerne nespúšťa** (je to čistý dotaz bez zápisu). Bez tohto poradia by sa náš set `prichyt-sokla-axilo` (Häfele/AXILO) javil ako odporujúci, prišiel by
  o klasifikáciu — a knižnica by sa vzápätí zapísala so `seed_version` 8, takže **seed-merge setov by sa už nikdy nezopakoval** a set by ostal navždy nezaradený. Poradie je
  vidieť v `ProductionCore.hardware_expansion`: `HardwareSets.load` beží **pred** `HardwareCatalog.items` (ktorý taxonómiu doseeduje tiež), takže prvý na rade je práve tento kód.
  **R-07 sa nemení:** nad read-only/degradovanou taxonómiou `ensure_seeded` nič nezapíše, `series_owner` vráti `nil` a klasifikácia ostáva — presne ako doteraz. **Vlastný
  výrobca rady sa neprebíja** (migrácia presúva LEN presný starý seed tvar), takže používateľ s „AXILO → Moja firma" dostane set ďalej ako nezaradený.
- **Migrácia:** starý (v2..v7) tvar setu nôh je v `LEGACY_SEED_SHAPES`, takže `replace_untouched_seed_sets` nedotknutú knižnicu aktualizuje a používateľom upravený set
  (stačí premenovanie) nechá tak. **Projektové snapshoty sa nemenia samy** — do rozpracovanej zákazky nový tvar aj predvoľbu príchytu prenesie vedomé **„Doplniť nové
  predvoľby"** (`refresh_untouched_project_sets` + `add_mapping_seed`, existujúci mechanizmus). Dôsledok, ktorý patrí do poznámok k vydaniu: **skrinka so soklom 150 mm
  objedná po prestavbe AXILO H150 + platničku (9076 + 9079) namiesto demosovskej nohy 367823** — golden charakterizácia `seed_kniznica` je preto vedome pregenerovaná.

Testy: `tests/pure/test_kovg1a_nohy_data.rb` (36 sád + 14 overených mutácií, vrátane tabuľkovej fixtúry výšok sokla ako druhého nezávislého zápisu) +
JS `tests/js/test_hw_sets.js` (sentinel v pásme).

**BEZSTRATOVÁ BRÁNA DEFINÍCIÍ SETOV V ŠABLÓNE — `assess_set_defs` (audit #17 BLOCKER 1).** `hardware_set_defs` išli doteraz LEN cez tolerantný `normalize_sets`, teda cez cestu,
ktorá neznámy obsah ticho oreže; od KOV-B1 by starší plugin zmrazil do .skp set BEZ klasifikácie. Šablóna je dátový súbor MIMO modelu (môže byť ručne upravená alebo z novšej
verzie), takže sa číta **bezstratovo alebo vôbec** — rovnako ako mapovanie v `read_template_mapping`. Čistá funkcia vracia `[:ok, {set_id => norm}]` alebo `[:lossy, [názvy]]`
a používa TEN ISTÝ detektor ako knižnica. Volá sa na OBOCH cestách a VŽDY **pred akoukoľvek operáciou**: `Panel.take_insert_hardware!` (vklad — pred `prepare_insert` aj pred
ghost session; vlastný status `:lossy_defs` = vlastná hláška) a `TemplatesDialog.handle_apply` (použitie — pred `rebuild_many`). Odmietnutie preto znamená „model sa nezmenil ani
o krok Späť"; poradie stráži zdrojový guard a in-SketchUp sekcia `run_kovb1`. K bráne patrí bump `CabinetBuilder::CONFIG_SCHEMA` na **4** ([construction.md](construction.md)),
ktorý tú istú šablónu odmietne aj SPÄTNE. **Opakovaný `set_id` v poli definícií je tiež strata, nikdy prepis:** brána by inak posúdila POSLEDNÚ definíciu, kým
`collect_set_defs` (cez `normalize_sets`) drží PRVÚ — do .skp by teda sadli iné kódy, než ktoré prešli kontrolou.

**Detektor straty má ŠTYRI vrstvy** (od KOV-C2a päť — piata je `height_variant` v tej istej funkcii, viď vyššie) — tri pôvodné (nižšie, R-07) plus **`classification_lost?`**: `use_type` je ZNÁMY kľúč so SKALÁRNOU hodnotou, takže whitelist aj počty by
hodnotu z novšej verzie (`use_type: 'sliding'`) prepustili a tolerantné čítanie by celý blok ticho zahodilo. Porovnáva sa RAW definícia s výsledkom `normalize_sets`: raw má
neprázdny ktorýkoľvek klasifikačný kľúč a normalizovaný set klasifikáciu nemá → STRATA; rovnako raw `active: false` bez príznaku v normalizovanom. Beží vo **VŠETKÝCH TROCH
bránach** — `assess_library_doc`, `project_state_status` aj `assess_set_defs` — tri cesty k tým istým dátam sa nesmú rozísť. Dôsledok: knižnica z novšej verzie je `:read_only
:unknown_shape`, snapshot `:invalid` a šablóna odmietnutá, nikdy tichý orez.

Testy klasifikácie: `tests/pure/test_kovb1_sety.rb` (vrátane charakterizácie „klasifikovaná kópia SEED knižnice nakupuje deep-equal" a piatich overených mutácií), golden
odtlačok `tests/fixtures/kovh_golden/seed_kniznica.json` a in-SketchUp sekcia `run_kovb1`. Náhľad, štruktúru chýb a filter ponuky strážia `tests/pure/test_kovb3_nahlad.rb`,
`tests/js/test_kovb3_modal.js` a in-SketchUp sekcia `run_kovb3` (dve okná nad tým istým setom, zápis do knižnice bez kroku Späť).

**AD-HOC KANÁL: konkrétne kovanie MIMO setov (KOV-H1, v0.9.18).** `expand` má druhý vstup **`manual_items:`** — ad-hoc položky zákazky (`Bom.collect` kľúč `hardware_manual`, tvar
drží `cabinet_builder.rb`). Sú to položky, ktoré do skrinky pridal človek: konkrétny katalógový kód alebo voľná položka s vlastným názvom a cenou. Kanál beží **PRED set
rezolúciou** a je zámerne samostatný — nikdy `resolve_set_id`, nikdy `generic_type 'custom'`, nikdy `note_manual`. (`note_manual` je D-93 **znamienko ručného zásahu do počtu/dĺžky
SETOVEJ položky**, teda úplne iný pojem so vstupom `source == 'manual'`; audit #15 FIX 7 to oddelil natvrdo. Ad-hoc pôvod nesie `origin: 'adhoc'` na ZDROJI riadku a stráži to
mutačný test.)

Tri pravidlá, na ktorých kanál stojí:

- **Katalógová položka je BEŽNÝ riadok podľa kódu.** `add_adhoc_row` ju zlieva do `rows[code.downcase]` presne ako `add_row`, takže sa **spojí so setovým riadkom rovnakého kódu**
  a cena je JEDNA a **živá z katalógu** (`row_join`). To je audit #15 BLOCKER 2: pôvodný návrh držal cenu v snapshote configu a agregácia podľa kódu by na jednom nákupnom riadku
  zmiešala dve ceny. V configu ostáva len kód + snapshot názvu/MJ. Riadok navyše nesie **`adhoc_quantity`** (koľko kusov z neho je ručných) — bez neho by sa z riadku nedalo
  zistiť, že ho človek doplnil.
- **Voľná položka má VLASTNÝ riadok** pod kľúčom **`free:<cabinet_id>:<id>`** (`add_free_row`): `code` je prázdny (nesmie sa tváriť ako katalógový kód a zliať sa s ním), `free:
  true`, `free_key` = ten kľúč, názov/MJ/cena zo snapshotu a **nikdy `missing`** — cenu zadal používateľ, takže riadok nie je „bez názvu a ceny". Neznáma cena ostáva `nil`
  (subtotal `nil`, súhrn to prizná v `unknown_prices`), NIKDY nula (STANDARD §11.3).
- **Kód, ktorý z katalógu ZMIZOL, je `catalog_missing`, nie `missing`** (audit #15 FIX 6). `row_join` si na riadku pozrie privátny `adhoc_snapshot` (názov + MJ z configu, `finalize`
  ho z payloadu maže ako `manual_auto`): keď existuje, riadok dostane názov a MJ zo snapshotu, cenu `nil` a príznak `catalog_missing`. Dôvod je vecný — riadok **má názov**, takže
  ho cenová ponuka nesmie preskočiť a v CSV nemá ostať holý kód; chýba mu LEN cena a Kontrola to prizná ORANGE.

Invariant **`Σ sources.quantity == row.quantity`** platí aj tu (jeden zdroj na výskyt položky); ad-hoc zdroj má `generic_type`/`rule_id`/`set_id` **`nil`** (položka žiadny set ani
pravidlo nemá a predstierať opak by rozbilo rozklik pôvodu v Nákupe) a navyše `origin: 'adhoc'` + `manual_id`. `unmapped` sa ad-hoc **netýka** — položka má kód alebo názov od
človeka, takže nemapovaná byť nemôže. **`finalize` zoraďuje s kľúčom riadku ako posledným rozhodcom**: voľné riadky majú prázdny `code` aj `category`, takže bez neho by ich
nestabilný `sort_by` medzi behmi preusporiadal; pre setové riadky je to no-op (kľúč = `code.downcase`).

**Nákupný CSV sa NEMENÍ** (audit #15 FIX 13): žiadny nový stĺpec — pôvod žije v sekcii Nákup Štúdia (rozklik zdrojov) a v `sources`. Voľná položka je v CSV riadok s **prázdnym
kódom** a názvom zo snapshotu. Že zákazka BEZ ad-hoc položiek dáva **bajtovo** ten istý CSV a štrukturálne tú istú expanziu, dokazuje golden charakterizácia
`tests/fixtures/kovh_golden/` (generátor sa spúšťa ručne; rozdiel je nález, nie šum).

**Globálna knižnica žije pod medziprocesovým zámkom (1d/R-08).** Súbor `%APPDATA%\NOXUN\Engine\hardware_sets.json` menili DVE inštancie SketchUpu naraz a robili to štýlom
„prečítaj → uprav → zapíš" **bez zámku** — set uložený v jednom okne zmizol bez slova, keď to druhé okno o chvíľu niečo uložilo. Od tejto dávky ide **každý** zápis
(`write` · `save_set!` · `delete_set!` · `set_global_mapping!` · seed-merge v `load` · `ensure_seeded`) cez `lock → čerstvé čítanie → kontrola revízie → atomický zápis`, kde
zámok je **jeden zdieľaný sidecar** `materials.lock` pre celý priečinok (`Materials.with_catalog_lock`, vzor 1b-6c — vlastný `.lock` na súbor by vyrobil poradie zámkov a s ním
riziko zaseknutia). Čítanie bez zápisu sa **nezamyká** (hot cesty `expand`/`explain`/payloadov); seed-merge zámok berie len vtedy, keď naozaj ide zapisovať, a **pod ním merge
prepočíta** — keď ho medzitým urobila druhá inštancia, nezapisuje sa nič.

Tri veci, ktoré samotné obalenie zámkom NEVYRIEŠILO a preto majú vlastnú mechaniku:
- **kontrola revízie je AŽ POD zámkom** — kým sedela pred ním, druhá inštancia stihla medzi ňou a zápisom uložiť svoje a my sme to zmazali s hláškou „uložené";
- **`load_with_revision`** — payload sekcie berie knižnicu aj jej revíziu z JEDNÉHO stavu súboru; kým to boli dve volania, cudzí zápis medzi nimi vyrobil payload so STARÝMI
  setmi a NOVOU revíziou, taký formulár prešiel guardom a prepísal zmenu, ktorú používateľ nikdy nevidel;
- **`set_global_mapping!` má odteraz tiež revíziu** (`:ok` / `:conflict` / `false`) — dve otvorené okná meniace ten istý typ kovania si predvoľbu inak ticho prepísali. Editor
  pásiem si revíziu **PRIPÍNA pri otvorení** (`hwsPinRev`) a Uložiť posiela ju, nie čerstvú: rozpísaný draft plný push zámerne prežíva, takže omladená revízia by guard urobila
  slepým presne v scenári, na ktorý je (lekcia #227 P1). Priamy výber zo selectu draft nemá a používa aktuálnu — select prekresľuje každý push spolu s ňou. A **konflikt je jediný
  prípad, kedy sa rozpísaný editor ZAHADZUJE** (`HWSETS.mapConflict`, po čerstvom payloade sekcie): s pripnutou zastaranou revíziou by každý ďalší klik konfliktoval donekonečna,
  hoci hláška sľubuje „obnovené, vyber znova". Pri `:invalid` a zlyhanom zápise editor rozpísaný ZOSTÁVA (hodnoty sa majú opraviť, nie stratiť);
- **`ensure_seeded` kontroluje dvakrát** (rýchlo, a potom ešte raz pod zámkom) — oneskorený seeder by inak naslepo prepísal seedom reálnu zmenu, ktorú medzitým niekto uložil.

Zámok, ktorý sa nepodarí vziať, je **IOError** — každá zapisovacia cesta ho premení na svoj NEÚSPEŠNÝ výsledok (`false` / `:write_failed`), nikdy na tichý úspech, a seed-merge
vetva pri ňom vráti **skutočnú knižnicu** (nikdy seed — inak by používateľ videl cudzie defaulty a prvý úspešný zápis by ich zvečnil). Testy: `tests/pure/test_r08_zamky.rb`
(vrátane REÁLNEHO dvojprocesového `flock` scenára).

**Kompatibilitná BRÁNA globálnej knižnice (1d/R-07, v0.8.21).** Knižnica je globálna (`%APPDATA%`), takže ju zdieľajú **všetky verzie pluginu** na profile — a staršia verzia ju čítala bez pohľadu na
marker `std`, neznámy tvar člena ticho zahodila a prvým zápisom stratu **zvečnila** (zápis navyše stampoval `std: 1` aj nad obsahom, ktorý bez novších tvarov čítať nejde, takže marker klamal aj dopredu).
Od tejto dávky má knižnica **STAV** (vzor `HardwareCatalog.assess!`): `library_state` = `:ok` | `:degraded` (1d/R-11, nižšie) | `:read_only`, `library_state_reason` (hotová SK veta pre používateľa)
a `library_state_code`
(`:newer` · `:foreign` · `:unknown_shape` · `:duplicate` · `:unreadable` · `:unexpected_shape` · `:degraded`). Maticu počíta ČISTÁ `assess_library_doc(doc)` nad dokumentom — bez IO, takže sa dá vyhodnotiť aj nad
súborom čerstvo prečítaným pod zámkom — a **fail-closed**: čokoľvek, čo v nej vyletí (cudzia hodnota, ktorá rozbije normalizáciu), končí ako `:read_only`, nikdy ako výnimka. Bez toho by ju `load`
zachytil, zavolal `library_read_only?`, tá by ju vyvolala znova a nákupný súpis by skončil ako `nil` — teda BEZ oranžového priznania. Tá vetva má **vlastný kód `:unexpected_shape`**, nie `:unreadable`:
padne do nej aj obyčajná chyba pluginu nad úplne zdravým súborom, takže jej hláška hovorí „nič sa nezapisuje, súbor NEMAŽ, nahlás problém" — nikdy nenavádza knižnicu zmazať.

Štyri veci, ktoré rozhodujú, či je brána naozaj brána:
- **Stav sa NECACHUJE a `load` je bezpečný z princípu.** Zapamätané `:ok` je presne tá pasca, ktorú brána rieši: súbor mohol medzitým vymeniť iný proces, takže volajúci by sa rozhodol podľa STARŠIEHO
  verdiktu nad NOVŠÍM obsahom. `library_state` preto vyhodnocuje pri každom použití (súbor pod tým drží sekundová cache `JsonFileStore`, takže **verdikt aj obsah pochádzajú z jedného dokumentu** — to je
  invariant, na ktorom celá brána stojí), a **`read_library` pri `:read_only` vracia PRÁZDNO**. Skorší návrh vydával „parsovateľný obsah" a mal na bezpečné čítanie druhú metódu (`usable_library`) —
  stačilo raz siahnuť na `load` a pracovalo sa s orezanými dátami. **Jedna cesta = jedna pravda:** poradie u volajúcich je vždy *najprv `load`, potom rozhodnutie*.
- **Kontrola beží POD ZÁMKOM pred KAŽDÝM zápisom.** Brána sedí v `write` — pod `Materials.with_catalog_lock` (R-08), po `JsonFileStore.reload!`, nad **čerstvo prečítaným** dokumentom. Jedno miesto kryje
  všetky zapisovacie cesty (`save_set!` · `delete_set!` · `set_global_mapping!` · seed-merge · `ensure_seeded`), lebo všetky končia tu; tri mutátory majú navyše **vlastnú bránu hneď po zámku** — bez nej
  by sa rozhodovali nad prázdnou knižnicou a `delete_set!` by hlásil zavádzajúce `:not_found` namiesto zlyhania. Odmietnutie je vždy ich NEÚSPEŠNÝ výsledok (`false` / `:write_failed`), nikdy tichý úspech.
- **Read-only knižnica sa nesmie ani POUŽIŤ.** Zákaz zápisu sám o sebe nechráni: nákup by sa ďalej počítal z **orezaných** dát. `global_default_state` vracia **nil** (a s ňou odmietnu
  `ensure_project_state!` · `set_project_mapping!` · `add_project_sets!` · `resolve_set_def` fallback na global), `merge_project_sets_seed!` aj `freeze_template_sets!` vracajú vlastné **`:blocked`**
  a `template_set_defs` **nil**. Súpis bez projektového snapshotu skončí ORANGE **`library_incompatible`** (`expand(..., no_set_reason:)`; ostatné dôvody sa nemenia) — a **panel hovorí to isté**:
  `Panel.decorate_hardware_purchase` pri blokovanej knižnici **neuplatní ani override skrinky** (ukazuje na set_id, ktorého definícia by musela prísť práve z nej) a ten istý kód posiela do `explain`
  (`no_set_reason:`). Bez toho by panel radil „priraď set" tam, kde je príčina úplne iná (panel a súpis sa rozísť nesmú, lekcia R-06a). **PLATNÝ projektový snapshot funguje ďalej** — jeho zdrojom je .skp.
  **Hranica je úzka:** `template_set_defs` vracia nil LEN pri pokazenom ZDROJI (`:invalid` snapshot alebo blokovaná knižnica). Jedna nerozložiteľná referencia nad zdravými zdrojmi (kópia korpusu
  z iného modelu, medzitým zmazaný set) sa iba **vynechá** — šablóna ju nenesie a pri aplikácii skončí ORANGE `set_missing`, presne ako sľubuje kontrakt GH #133 P2. Zahodiť kvôli nej celé kovanie
  šablóny by bola strata bez dôvodu a hláška volajúceho („sety projektu sú poškodené — obnov ich") by nad zdravým projektom klamala a poslala používateľa na Obnoviť, ktoré prepíše snapshot.
- **Seed-merge sa nad read-only knižnicou NEROBÍ** (`read_library` posudzuje stav PRED mergom): do novšieho súboru by sme primiešali svoje default sety a migrácie mapovania, teda presne tú tichú zmenu,
  pred ktorou brána chráni. V tej istej vetve sa **nikdy nevracia SEED** — inak by používateľ videl cudzie defaulty a prvý zápis by ich zvečnil (platí aj pre `rescue` vetvu `load`).

**Detektor straty má TRI vrstvy, lebo whitelist sám nestačí.** (1) **Whitelist kľúčov** (`SET_KEYS` · `MEMBER_KEYS` · `PARAM_BANDS_KEYS` · `BAND_KEYS`) chytí NOVÉ POLE novšej verzie. (2) **Typy hodnôt
známych kľúčov** (`bad_type?`): kľúč, ktorý poznáme, môže v novšej verzii niesť iný TVAR — `code_by_nl` ako pole (štruktúrovaný rad popri fallback kóde), `qty` ako objekt. Normalizácia taký údaj buď
zahodí bez stopy, alebo — horšie — pretypuje na nezmysel: `['future'].to_s` by sa stalo „kódom", ktorý sa objedná. Skalár je String alebo Numeric (číslo v JSONe je legitímna legacy podoba kódu aj
počtu); `true`/`false`, pole a objekt skalár NIE SÚ. Bez tejto vrstvy diera unikala aj round-tripu, lebo `members_lost?` počítal ne-mapu ako „nula položiek" (dnes vracia sentinel, ktorý sa nikdy
nezhoduje). (3) **Round-trip porovnanie** (`normalize_sets` + `members_lost?`) chytí novú HODNOTU známeho kľúča správneho typu — `per: 'length'` prejde whitelistom aj typmi a normalizácia člena ho
ticho zahodí.
Round-trip beží **so stíšeným `log_skip`** (`without_skip_log`): brána sa vyhodnocuje pri každom použití knižnice, takže bez stíšenia by nekompatibilná knižnica zapísala tú istú vetu do konzoly pri
každom payloade; skutočné čítanie (`read_library`) loguje ďalej. **Typová ochrana žije aj v `validate_member`** (nie len v bráne) — je to spoločné telo VŠETKÝCH čítacích ciest (cabinet override
v configu, definície zo šablóny, `normalize_members` pri každej prestavbe) a tie cez bránu knižnice nejdú: `qty.to_i` nad `true` by inak zhodilo stavbu skrinky namiesto toho, aby ten člen odmietlo. Z rovnakého dôvodu ide do konzoly aj **dôvod read-only iba pri ZMENE stavu**. **Duplicitné `set_id`** má vlastný kód `:duplicate`
a hlášku „oprav súbor" — „aktualizuj plugin" by tam nepomohlo, s verziou to nesúvisí (vzor katalógu, GH #99 P2).
Porovnáva sa počet setov, počet členov a **počet položiek radu `code_by_nl`** (nečíselný kľúč radu sa zahadzuje po jednom, takže samotný počet členov to nechytí). Mapovanie ide cez `parse_mapping`
**bez `set_ids`** — chyby tvaru sú strata, ale odkaz na už zmazaný set NIE (`delete_set!` mapovanie čistí zámerne). Legacy **konverzie hodnôt** (dopĺňaný `per`, chýbajúce `qty`, číslo namiesto stringu)
prejdú. Whitelisty sú **kontrakt**: každé nové pole člena/pásma sa musí doplniť do nich, inak si vlastný zápis vyrobí read-only stav. **Obe vrstvy používa aj `project_state_status`**, takže snapshot
a knižnica sa v tom, čo považujú za stratu, nerozídu.

`write` stampuje `std` podľa **OBSAHU** (`snapshot_std`, tá istá funkcia ako pre snapshot — marker musí hovoriť o obsahu rovnako v .skp aj v `%APPDATA%`). **Priznané:** historický súbor so `std: 1` a obsahom,
ktorý už vyžaduje 2, sa **neopravuje sám** — čítať sa dá ďalej (std 1 je podporovaná hodnota) a marker sa povýši prirodzene prvým legitímnym zápisom; bez mutácie sa súboru nikto nedotkne.
**Poškodený súbor:** primár BEZ zálohy je **čistý stav** (`read_library_doc` vráti nil) — nie je z čoho čo stratiť a `main` sa tak správal odjakživa (`load` spadne do seedu a prvý zápis súbor
**samoopraví**). Zavrieť ho do read-only by používateľa poslalo do slepej uličky: zápis odmietnutý, seed nedostupný a nič mu nepovie, že stačí zmazať jeden súbor. Keď sa nedá prečítať **ani záloha**,
ostáva `:read_only` s dôvodom, ktorý **menuje celú cestu k súboru**.
UI: `sets_payload` nesie `library_state` + `library_reason`, sekcia `hw` Štúdia pri read-only **knižnicu nevykreslí vôbec**
(zobrazený obsah by už bol orezaný), namiesto zavádzajúceho „Knižnica setov je prázdna." ukáže **dôvod** a vypne globálne mutácie; odmietnutie na serveri mapuje `library_blocked_txt` na konkrétnu hlášku
a rovnaký dôvod dostane aj výber setu v paneli, poznámka pri ukladaní šablóny a aplikácia šablóny — tá **nesmie vyhodiť výnimku** (zhodila by celé vkladanie skrinky; kontrakt znie „stavba beží ďalej,
len bez snapshotu"). Testy: `tests/pure/test_r07_kniznica_brana.rb` (dvojinštančný scenár, reprodukcie interného review a charakterizácia zdravej std-1 knižnice) a `tests/js/test_r07_kniznica_ui.js`.

**DEGRADOVANÁ knižnica — poškodený primár + PLATNÁ `.bak` (1d/R-11, v0.9.2).** `JsonFileStore` pri poškodenom primári ticho číta zálohu, takže knižnica sa načíta a vyzerá zdravo — a najbližší zápis
by primár prepísal obsahom odvodeným od **STARŠEJ zálohy** (všetky sety uložené medzi zálohou a poškodením by zmizli). Od tejto dávky je to **`:degraded`**, tretia hodnota tej istej matice
s vlastným kódom `:degraded`.

- **Prečo NIE `:read_only`.** Read-only stavy hovoria „obsahu NEROZUMIEME" (novšia verzia, orezané dáta) — tam sa obsah nesmie ani použiť. Tu je obsah zálohy **plnohodnotný**, len je STARŠÍ ako to,
  čo sa nedá prečítať. Zákazka sa musí dať dokončiť, preto degraded knižnica **sa číta** (`read_library` vracia dáta, nie prázdno), **dá sa zmraziť do projektu** (`global_default_state` vracia stav)
  a projektové predvoľby sa menia ďalej — to sú zápisy do MODELU. Zakázané sú **VÝHRADNE zápisy do globálneho SÚBORU**: `save_set!` · `delete_set!` · `set_global_mapping!` · seed-merge ·
  `ensure_seeded`, teda presne to, čo by primár prepísalo.
- **Dve osi = dva predikáty.** `library_read_only?` (smiem obsah POUŽIŤ?) sa nemení a používajú ho cesty o použití; `library_write_blocked?` (smiem zapísať do SÚBORU?) je pravda pre `:read_only`
  **aj** `:degraded` a používajú ho zapisovacie cesty vrátane troch mutátorov a UI handlerov.
- **Kde matica žije.** `assess_library_doc` je ČISTÁ funkcia nad DOKUMENTOM (bez IO) — degraded je ale vlastnosť SÚBOROV na disku (dokument sa parsuje bez problému, veď pochádza zo zálohy), takže
  kontrola sedí vo vrstve NAD ňou: `assess_library(doc)` doplní výsledok dokumentovej matice a zvažuje degraded **len keď dokument dopadol `:ok`**. `apply_library_state` tak stále zapisuje jediný
  výsledok — dva dôvody sa nemôžu prebíjať a `:read_only` nikdy nespadne na nižší stupeň. Stav sa (ako v R-07) **NECACHUJE** a pred zápisom sa vyhodnocuje znova pod zámkom.
- **Log iba pri ZMENE stavu.** Seed-merge sa nad degradovanou knižnicou pokúsi zapísať pri KAŽDOM `load`, takže bezpodmienečné logovanie odmietnutia by zaplavilo Ruby konzolu; používateľ sa o dôvode
  dozvie z UI, nie z logu.
- **UI:** sekcia `hw` sety **ZOBRAZÍ** (na rozdiel od read-only) a k nim dá oranžový banner „knižnica je poškodená — číta sa záloha, globálne zápisy sú vypnuté"; vypnuté sú `+ Nový set`, `Upraviť`,
  `Zmazať` a globálne predvoľby, kým `Doplniť nové predvoľby` a projektový výber setu bežia ďalej (`hwsLibDegraded` / `hwsLibWriteBlocked`, `HWS_WRITE_ACTIONS` ⊂ `HWS_LIB_ACTIONS`).
- **Náprava pre používateľa:** opraviť alebo zmazať jeden súbor — dôvod menuje celú cestu. Po zmazaní poškodeného primára sa číta záloha a prvý zápis súbor obnoví.

Testy: `tests/pure/test_r11_degradovana_zaloha.rb` + `tests/js/test_r11_degradovana_ui.js`.

**Člen účtovaný na vlastníka a stopa REÁLNEHO zliatia (P0-HF, review #252 P2; spresnené 1d/R-34).** `expand_members` počíta člena `per: 'unit'` ako `quantity × qty`, ale člena
**`per: 'owner'`** len **raz na `[owner_id, owner_part_key, set_id, code]`** (audit B3: druhé pravidlo s tým istým vlastníkom TipOn nezdvojí). Práve tento dedup je **jediný
mechanizmus, ktorým dve fyzické skrinky so zdieľaným `cabinet_id` dostanú položku raz namiesto dvakrát** — a teda jediný dôvod, prečo duplicitná identita smie zastaviť
nákupný/cenový export. Aby to brána vedela rozhodnúť namiesto hádania, nesie zdroj riadku príznak **`per_owner`**: kľúč je **aditívny**, zapisuje sa **len keď je pravdivý**,
a má presne jedného čitateľa — `ProductionCore.dup_partition` ([outputs.md](outputs.md)). Bez neho by sa blokoval aj export zákazky, ktorá má samé `per: 'unit'` členy
a spočíta sa správne aj so zdieľaným ID.

Príznak značí **výhradne vetva reálneho preskoku**, nie každý vydaný owner člen (R-34): `owner_seen[key]` drží **už vydaný zdrojový záznam** a druhý zásah na ten istý kľúč mu
`per_owner` doznačí — preto `add_row` vracia `src` a sám príznak nikdy nepíše. Rozdiel je vidieť na dvoch inštanciách so zdieľaným `cabinet_id`, ale **rôznym `owner_part_key`**:
kľúč sa nezhoduje, TipOn vznikne dvakrát, množstvá sú správne — a do R-34 ich brána napriek tomu zastavila. **Priznaný zvyšok:** expanzia vidí len `owner_id`, takže **dve
pravidlá na tej istej fyzickej skrinke** (B3) sú od dvoch inštancií nerozlíšiteľné a príznak dostanú tiež; pri duplicitnom ID to ostáva falošne pozitívne, teda **bezpečným
smerom** (radšej zastaviť, než poslať podpočítanú objednávku). Testy: `tests/pure/test_hardware_sets.rb` (bez zliatia / s reálnym preskokom) a `tests/pure/test_p0hf_brany.rb`
(brána nad **reálnou** expanziou + invariant Σ zdrojov = množstvo riadku).

**Brána dĺžkového kovania (1d/R-06a, v0.8.15).** Expanzia setu vie **len kusy** (`PER_KINDS` = `unit`/`owner`, subtotal = `cena × počet`), ale položka úchytkového profilu (D-90)
nesie **dĺžku rezu** v `params['cut_length_mm']` a jej katalógová cena je **za meter**. Takú položku preto `expand` do naceneného riadku **nepustí**: predikát
**`length_unsupported?`** (jediná podmienka = kladná `cut_length_mm`; názov kľúča drží `HardwareRules::LENGTH_PARAM`, hardware_sets si ho neopisuje) ju odkloní do
**ORANGE `length_unsupported`**, teda do sekcie NEMAPOVANÉ, ktorá už rozmer nesie. Poradie kontrol je zámerné — `set_missing` a `set_type_mismatch` majú prednosť (sú
konkrétnejšie), brána stojí až za nimi. **`explain` má tú istú bránu** (panel a súpis sa nesmú rozísť — inak by panel rozpísal kódy s cenou za meter pri položke, ktorá v nákupe
nevznikne). Rozpočet aj cenová ponuka čítajú tie isté `rows`, takže sa k položke nedostanú. Text hovorí **prečo, aký rozmer a čo s tým** (`unmapped_reason_sk` +
`Validation.check_hardware_expansion`), rozmer berie z jediného zdroja `params_label`.

Brána je **serverová zámerne**: kontrola v editore setov by nedosiahla na sety už uložené v staršom `.skp`. Typ `handle` sa v editore **nezakazuje** — kusová úchytka je legitímne
mapovanie a zákaz typu by ju vzal tiež; nebezpečná je len položka s dĺžkou rezu. **Plný režim `per: 'length'`** (Σ mm, MJ „m") patrí k R-05 v bloku KOVANIE a bránu smie stlmiť
**až tá istá dávka**, ktorá prinesie dĺžkovú materializáciu — inak sa položka vráti presne do kusového násobenia.

### drawer_recipes.rb

**KOV-C1 — nemenné recepty zásuviek** (`Noxun::Engine::Recipes`). Čisté Ruby: žiadne SketchUp API, žiadny zápis do modelu ani na disk.
**Od KOV-C2b (v0.9.31) je modul ZAPOJENÝ:** `Construction.build_plan` ho volá pre každé klasifikované zásuvkové čelo (`drawer_pass`, viď
[construction.md](construction.md)) a z neho vznikajú dielce v pláne aj **jedna** položka výsuvu.

**Register brány `DRAWER_BLOCKERS` (12 kódov od KOV-D2a)** = `CONFLICT_CODES` (11, ktoré produkuje resolver) **+ 1 MIGRAČNÝ**. Delí sa na `BUILD_BLOCKERS` (10 fail-closed konfliktov
STAVBY: zásuvka nevydala ani dielec ani položku) a `ALL_EXPORT_BLOCKERS` = `drawer_kit_missing` (vzniká až v NÁKUPE) **+ `drawer_stale`** — jediný kód, ktorý neprodukuje
resolver ani nákup, ale **čítanie modelu** (`Bom.collect`): skrinka uložená pred aktiváciou receptov (`config_schema < CabinetBuilder::DRAWER_ACTIVATION_SCHEMA`) má
klasifikovanú zásuvku, takže v .skp **nie sú** receptové dielce a výsuv je legacy — kusovník aj VEPO by boli neúplné a ticho. Nápravou je **prestavba** skrinky.
`BLOCKER_LABELS` drží krátky slovenský názov pre bránu exportu — plnú vetu (ktorá hodnota kde nesedí) skladá recept a nesie ju nález Kontroly.

**`supported_thicknesses(system)` / `thickness_ok_for_system?`** = čisté funkcie nad najnovším vydaným receptom systému: **PRIENIK** `thickness_supported` cez všetky roly
(jeden materiálový kanál kŕmi všetky roly naraz, takže hrúbka dobrá len pre dno by pri Quadre padla na boku). Atira → `[16]`, Quadro V6 → `[16, 18]`. Číta ich preflight
projektovej predvoľby zásuviek ([materials.md](materials.md)); neznámy systém = `[]`, teda fail-closed.

**`explain_stored(params)` (KOV-C2c, v0.9.33)** = vety „prečo práve tieto čísla" pre **kartu čela**. `resolve` skladá `explain` počas stavby, ale plán ho nenesie a do configu
sa neukladá (schéma sa v C2c nemení), preto sa detail skladá **znova** — a to výhradne z toho, čo sa dá **dokázať**: z uložených `params` položky výsuvu a z **pripnutého**
receptu (`load(params['recipe_id'])`). Preto sú vety **užšie** než `explain` v `resolve`: svetlé rozmery skrinky sa neukladajú, takže sa netvrdia. Neznámy alebo nečitateľný
recept vráti **prázdny zoznam** — karta radšej nekreslí nič, než by ukázala vymyslené číslo. Čistá funkcia (číta len dátový pack), takže je headless testovateľná.

**Dve vrstvy, jedna zodpovednosť každá:** fyzika (rozmery dielcov, výšky, rad NL) žije v **recepte**, objednávacie kódy v **setoch** (`hardware_sets`). Nákup nikdy nemení
fyzický návrh: rad NL v recepte = rad, ktorý Noxun reálne kupuje, žiadni kandidáti ani fallback. **EB je pevné per recept** (Atira 10,5 · Quadro V6 23) — zmena hrúbky boku
mení iba svetlú šírku, engine nikdy nehľadá iný runner (mapa KD → EB neexistuje).

**Dátový pack `noxun_engine/data/recipes/`.** Jeden recept = jeden systém × jedno otváranie × verzia; `recipe_id` = `<system>_<opening>_v<version>` (validuje sa proti
poliam v súbore). V1 vydáva `atira_sisy_v1` · `atira_p2o_v1` · `quadro_v6_sisy_v1` · `quadro_v6_p2o_v1`. JSON nesie **len čísla, reťazcové enumy a polia** — vzorce sú
pomenované konštanty v Ruby, v súbore je nanajvýš dokumentačný `formula_doc`.

**Nemennosť.** `RELEASED.json` = register `{ recipe_id => sha256 }`. `load` číta **výhradne** registrované recepty a odtlačok súboru musí sedieť — nezhoda, neregistrované ID
aj chýbajúca bunka schémy končia výnimkou `Recipes::RecipeError`, **nikdy tichým defaultom**. Odtlačok sa počíta nad obsahom s normalizovanými koncami riadkov (repo beží
s `core.autocrlf=true`, surový bajtový hash by v CI padal). **Schéma sa validuje prísne pri načítaní**, nie až pri výpočte: `thickness_supported` musí mať **presnú** množinu
rolí svojej rodiny (`metal_box` = dno + chrbát; `wood_undermount` = dno + 2 boky + vnútorné čelo + chrbát) — chýbajúca aj prebytočná rola je odmietnutie receptu, inak by
chyba vyplávala až ako `drawer_no_fit` nad hotovou zákazkou. Testy navyše strážia, že **inventár `data/recipes/*.json` (všetko okrem registra, aj súbor s menom, ktoré parser
nepozná) == množina kľúčov registra**, a **golden fixtúra**
(`tests/pure/fixtures/kovc1_golden.json`) fixuje výsledky `resolve` pre KAŽDÝ vydaný recept — SHA JSON-u zmenu interpretácie v Ruby nezachytí. Oprava alebo rozšírenie =
**nový súbor `_v2`**; vydané verzie sa nikdy nemažú ani nemenia (reprodukovateľnosť starých zákaziek bez projektového snapshotu).

**Čisté funkcie.** `load` · `released` · `inventory` · `latest_for(system, opening)` (najvyššia vydaná verzia) · `sibling(recipe_id, system, opening)` (**rovnaká** verzia pre
inú kombináciu, inak `nil` — prepnutie klasifikácie tam a späť nikdy ticho nepovýši pripnutý recept) · `active_ref(refs_map, system, opening)` → `[:known, id]` ·
`[:unknown, id]` (RED `drawer_recipe_unknown`) · `[:missing, nil]` · `upgrade?(from_id, to_id)` (KOV-D3a — jediná pravda o smere upgradu: **rovnaký** systém aj otváranie
a **vyššia** verzia; rovnaká alebo nižšia je `false`, teda žiadny downgrade).

**`pick_ref` pri mape s VIAC verziami (KOV-D3a, Astra #20 F12).** Chýbajúci záznam sa dopĺňa **súrodencom rovnakej verzie**, a keď mapa nesie viac verzií naraz (po upgrade
jedného otvárania žije `sisy` na v2 a `p2o` ešte na v1), rozhoduje **stabilné pravidlo, nie poradie kľúčov v Hashi**: berie sa **najnižšia dostupná** súrodenecká verzia,
a to **výhradne z validovaných záznamov** (poškodený `:unknown` pin výber nikdy neovplyvní — D1a). Novo klasifikované čelo tak nikdy „neskočí" na novšiu fyziku len preto,
že ju medzitým dostala iná kombinácia; povýšenie ostáva výhradne explicitnou akciou. Bez súrodenca platí `latest_for`.

**`release_note` (KOV-D3a).** Jediné **voliteľné** pole schémy: autorská poznámka vydania — od **KOV-D3b** ju nesie ponuka v karte čela aj hlavička potvrdzovacieho okna
(`front_drawer[fid].upgrade.release_note`, `Panel.drawer_upgrade_offer`). Recepty v1 ho vynechávajú, preto neprítomnosť
**nie je** chyba (`recipe[:release_note]` je `nil`); prítomné pole sa už validuje prísne ako každé iné — nie `String`, prázdne po orezaní alebo dlhšie než `RELEASE_NOTE_MAX`
(400 znakov) je odmietnutie **celého** receptu.

**Register sa číta RAZ za prechod (`with_register_cache`, KOV-D3b, Codex #315 kolo 1 P2).** `active_ref`, `latest_for` aj `load` čítajú `RELEASED.json` **každý zvlášť** —
pri desiatich zásuvkach je to 20+ synchrónnych čítaní disku na **jeden** push panela (vrátane echa po každom edite). Blok `Recipes.with_register_cache` drží už prečítaný
register po dobu **jedného** prechodu; mimo neho je cache `nil`, takže zmena registra **medzi** pushmi sa vždy prejaví, a poškodený register sa **nezakešuje** (validácia beží
pred zápisom do cache, takže padá pri každom volaní). Nemennosť obsahu receptu tým netrpí — `load` odtlačok súboru overuje aj proti registru z cache. Používa ho
`Panel.attach_front_drawer_upgrade`, ktorý navyše zdieľa metadáta cieľa medzi zásuvkami s rovnakou kombináciou `system|opening`.

**Testovací seam pre priečinok receptov (KOV-D3a).** Všetky čítacie funkcie majú `dir:` (C1 vzor), ale panelové akcie ani stavba ho neposielajú — čítajú default. Ten má
**jediné** prepínacie miesto: modulovú premennú `@test_dir` (`active_dir` · `test_dir=` · `with_test_dir`). Nastavujú ju **výhradne testy a in-SU runner**, nikdy UI, config
ani payload; v produkcii je vždy `nil`, takže platí `DIR`. Vďaka nej sa dá celý rámec upgradu overiť nad **fixtúrnym registrom** `tests/fixtures/recipes_d3a`
(`atira_sisy_v1` = bajtová kópia produkčného + dočasné `v2`…`v5` a `quadro_v6_sisy_v2`), zatiaľ čo **produkčný register žiadnu v2 nemá** — stráži to guard test
(D3a/D3b sú **latentný rámec**, produkčná v2 vznikne až s reálnou dátovou zmenou).

**`recipe_key_for(front_item)` = rozhodovacia tabuľka, nikdy dve cesty naraz.** `[:legacy, nil]` pre iný typ než zásuvka, zásuvku **bez jediného** klasifikačného poľa
(`construction`, `opening_mode`, `system` **aj `variant`** chýbajú) a pre `construction other` — legacy cesta ostáva CONTENT-identická a resolver sa nevolá.
`[:ok, {system, opening}]` keď je `construction` **aj** `opening_mode` (`metal → atira`, `wood → quadro_v6`; `classic → sisy`, `tipon → p2o`).
`[:conflict, kód, hláška]` inak — kód je vždy z `CONFLICT_CODES`, hláška je slovenská veta pre Kontrolu v C2: `drawer_unclassified` pri **akejkoľvek čiastočnej**
klasifikácii (polia sa editujú nezávisle) a `drawer_internal_unsupported` pri `variant internal` (aj keď je `variant` **jediné** vyplnené pole).

**Explicitný `drawer.system` je kontrolovaný, nie autoritatívny.** Je to hodnota z configu, teda aj zo stale alebo podvrhnutého payloadu, preto **nikdy neprepíše mapu
konštrukcie**: `metal` musí byť `atira`, `wood` musí byť `quadro_v6`, nesúlad (aj neznámy systém) = `drawer_unclassified` s hláškou „systém nezodpovedá konštrukcii".
Tiché prepnutie systému by k dielcom jedného systému objednalo kovanie druhého.

**`resolve(recipe, ctx, part_thicknesses, overrides)`** → `{height_variant, box_height, nl, load, parts, hardware_params, conflicts, explain}`. Poradie krokov: KD mimo
`kd_supported` → `drawer_kd_unsupported` · hrúbka role mimo `thickness_supported` (`part_thicknesses` je **VSTUP**, nie odvodená hodnota) → `drawer_thickness_unsupported` ·
neprázdne `ctx[:obstructions]` → `drawer_obstruction` · **jedna výška** · **rad NL TEJ výšky** · **jedna NL** · nosnosť bunky · dielce · kontrola každého rozmeru
proti `MIN_DIM`.

**ZÁMKY OSÍ a ich poradie (KOV-D2a, Astra #20 B2).** Zásuvka má **dve** osi ručného zámku a obe žijú v tom istom zázname `hardware_overrides`
(`generic_type slide`, `owner_part_key front:<id>/panel`): `nominal_length` (D-93; `rule_id` `vysuvy-nl-podla-hlbky` **alebo** `recipe:<id>`) a `height_variant`
(KOV-D2a; **výhradne** `rule_id recipe:<id>` a **výhradne Atira** — Quadro výškové varianty nemá, `box_height` plynie z geometrie). Zámok = **existencia platného poľa**;
záznam s `disabled: true` zámok **nenesie** (ten istý kontrakt ako `HardwareRules.override_nominal_length`). Poradie je záväzné, lebo **rad NL JE per výška**:

1. **zamknutá alebo automatická výška** — zamknutá musí existovať v pripnutom recepte **a zmestiť sa** (`min_clear_height ≤ clear_height`), inak RED
   `height_lock_invalid` **bez dielcov aj výsuvu**; automat berie najvyšší variant, ktorý sa zmestí (Quadro: `box_height = clear_height − 40`, čelo/chrbát
   `box_height − t_dna − 12 ≥ 30`);
2. **rad NL tej výšky** (`series_for`);
3. **zamknutá alebo automatická NL** — zamknutá sa overuje proti radu **VÝSLEDNEJ** výšky: zamknutá 520 po automatickom prechode H70 → H144 (rad H144 520 nemá) je
   `nl_lock_invalid`, **nikdy návrat na H70 ani zmena NL**; automat berie najdlhšiu z radu s `min_depth ≤ clear_depth`.

Dôvod, prečo zámok neplatí, skladá **jediná** funkcia per os — `height_lock_problem` a `nl_lock_problem`. Číta ich `resolve` (RED nález) **aj** payload osí (hláška chipu),
takže sa nemôžu rozísť; payload ich potrebuje preto, že zásuvka môže mať **skoršie** zlyhanie resolvera (prekážka, hrúbka, KD) a uložené `drawer_conflicts` o zámku vtedy
nevedia vôbec. Opačné poradie krokov by pri zmene výšky ticho posunulo NL. Vety `explain` znejú „Výška: H144 (ručný zámok)" / „NL: 470 (ručný zámok)". Emitovaná položka výsuvu **ostáva
`source: 'recipe'`** a nesie `locked: true` ako **súhrn** „aspoň jedna os je zamknutá" — receptový zámok **nikdy** neprechádza `HardwareRules.apply_overrides` (ten by pri NL
prepol zdroj na `manual` a nákup by prestal povyšovať chýbajúci kit na blocker; Astra #20 F7). Porovnania sú **inkluzívne a bez EPS** nad nezaokrúhlenou hodnotou z `context_for`
(105,00 platí, 104,995 padá). **Atomicita:** akýkoľvek konflikt ⇒ `parts = []` a `hardware_params = {}`.

**Pamäť PRI PRECHODE NA DVIERKA A SPÄŤ (pravidlo KOV-D4).** Zásuvkové polia sa prechodom na iný typ čela **nezahadzujú** — pravidlo má tri časti a všetky sú fail-closed:

1. **Pamäť patrí ROVNAKÉMU ID čela.** Serverové polia (`drawer.system`, `drawer.recipe_refs`) sa po klientskom payloade pripájajú späť **podľa `front_id`**
   (`Fronts.reattach_server_drawer_fields`) — čelo s **novým** ID pamäť nedostane a recept mu pripne až stavba. `system` sa navyše nepripája pri **zmenenej konštrukcii**
   (kov ↔ drevo), inak by čelo natrvalo uviazlo v `drawer_unclassified`.
2. **Zámok ostáva viazaný na SVOJ recept.** `lock_value` / `height_lock_value` prijmú záznam **výhradne** s `rule_id` pripnutého receptu (`recipe:<id>`; NL navyše legacy
   `vysuvy-nl-podla-hlbky`). Pri návrate na zásuvku s **tým istým** receptom sa zámok znovu **validuje stavbou** — teda tou istou cestou ako pri prvom zápise, nikdy sa
   „obnoví" bez overenia.
3. **Dormantný zámok iného receptu sa NIKDY nezobrazí ako aktívny.** Zmena otvárania (`classic` ↔ `tipon`) pripne **iný** recept a starý záznam ostane dormantný: resolver
   ho nepoužije a payload mu **nedá chipy osí** (`Panel.attach_override_axes` porovnáva `rule_id` proti `idents` pripnutého receptu). Ukázať naň stav aktuálneho receptu
   a zapisovať na cudzí `rule_id` je presne tá tichá zámena, ktorej celý package bráni. Záznam **ostáva v configu** a keď je osirotený, riadok ručných zásahov ho ukáže
   s tlačidlom „zrušiť".

**Dielce.** Atira presne 2: `drawer_bottom` `(LB − 2·EB − 51,5) × (NL + 10)` a `drawer_back` `(LB − 2·EB − 63) × rear_height`. Quadro 5: `box_side` ×2 `NL × box_height`,
`drawer_bottom` `SKW × NL`, `drawer_inner_front` a `drawer_back` `SKW × (box_height − t_dna − 12)`, kde `SKW = LB − 46`. ABS per rola z receptu (dno bez, ostatné horná dlhá
hrana 1,0). `hardware_params` (`recipe_id`, `system`, `height_variant` | `box_height`, `nominal_length`, `load`, `opening`) je podklad pre **jednu** položku výsuvu, ktorú
skladá C2. `explain` sú slovenské vety pre Inspector.

**`OVERRIDE_CONFLICT_CODES` (KOV-D4)** = podmnožina troch kódov, ktorých **nápravou je riadok ručného zásahu** v Kovaní: `nl_lock_invalid` · `height_lock_invalid` ·
`drawer_override_invalid`. Presne tie, ktorých veta už riadok menuje (`LOCK_HINT`, `Construction::ORPHAN_HINT`) — a jediné, pri ktorých smie deep-link Kontroly mieriť na záznam
`hardware_overrides`. Je to **whitelist**: pri hrúbke, prekážke, KD, poškodenom pine či `drawer_stale` by reset zásahu konflikt nevyriešil (a riadok ani nemusí byť osirotený),
takže blacklist by tichú chybu zdedil každému budúcemu kódu.

**`CONFLICT_CODES`** = register 11 kódov brány `DRAWER_BLOCKERS` (KOV-C 10 + `height_lock_invalid` z KOV-D2a). C1 ich len **produkuje**; napojenie na `export_blockers`, `hardware_issues` a Kontrolu je
úloha C2 — v C1 preto `drawer_kit_missing` ani `drawer_override_invalid` nikto nevyrába, sú tu len ako jediné miesto pravdy o množine kódov.
