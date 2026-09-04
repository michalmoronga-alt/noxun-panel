# Konštrukcia, geometria a observery modelu

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Plánovač, buildery, strom zón, modulové výpočty (police, čelá), kontrakt osí dielca a prekrytia (`Sketchup::Overlay`) nad modelom vrátane absorpcie scale.

## Plánovanie a stavba

### construction.rb

plánovač cfg→BuildPlan (kovanie sa vyhodnocuje po vyradení degenerovaných dielcov; `support_type`).

### cabinet_builder.rb

**ŠEV VKLADANIA (R-03, v0.8.20): `prepare_insert` → `commit_insert`; `build` je len ich kompozícia** a správanie všetkých doterajších volajúcich je nezmenené.
`prepare_insert(model, params)` vydá **zmrazený `InsertPlan`** (config + `home_z`) — *žiadna* mutácia modelu, entít, ID ani Undo stacku, a **zámerne ani `ensure_root_context`**
(ghost hover nesmie používateľovi zatvárať otvorený komponent). Config je **hlboká kópia s rekurzívnym freeze** vrátane vnorených hashov, polí aj stringov, a **v tomto poradí**:
`enum_val` vracia `v.to_s`, čo je pri Stringu ten istý objekt ako vstup, takže priamy freeze by zmrazil `params` volajúceho. Plán si drží **referenciu na `Sketchup::Model`** ako identitu
dokumentu — nie `guid`, ten sa mení pri každom uložení (lekcia #261/#264).

`commit_insert(model, plan, transform:, &block)` je jediné miesto, kde vklad mení model, a **poradie krokov je súčasť kontraktu**: (1) guard identity dokumentu — plán z iného okna
sa odmieta ešte pred zatvorením edit kontextu (cross-document vklad nikdy) · (2) validácia explicitného `transform` **a hneď snapshot** — prijme sa len konečná pravotočivá RIGIDNÁ transformácia (`rigid_matrix?` nad 16 číslami z `to_a`: jednotkové a navzájom
kolmé osi, determinant +1, nulová perspektíva a prvok `[15] == 1`); scale/skos/zrkadlo by postavili korpus, ktorého geometria nesedí s configom, a scale observer by ho pod guardom ani
nezachytil — tichá výrobná chyba. **`[15]` je uniformný mierkový deliteľ:** moderný SketchUp ho drží kanonický (1.0) a rovnomernú mierku premieta do osí, takže `scaling(2)` padne už
na jednotkovosti osí — kontrola `[15]` je ochrana pred **nekanonickou/legacy maticou** (surové pole, matica zo staršieho súboru), ktorá mierku nesie práve tam. **`Geom::Transformation`
je mutovateľná (`set!`)**, preto sa `to_a` číta práve raz a z tých istých overených čísel sa vyrobí kanonický snapshot (`snapshot_insert_transform!`); ďalej sa pracuje **výhradne
so snapshotom** — inak by sprievodný blok (H2), ktorý beží už po validácii, mohol transform prepísať na mierku a korpus by vznikol zväčšený pod `guarded` guardom ·
(3) `ensure_root_context` **a kontrola postcondition** (helper po výnimke/20 iteráciách ticho vracia nil — bez kontroly by korpus skončil v cudzom komponente) · (4) až teraz ID a
`next_x` · (5) operácia + **transparentný scale-lock follow-up, oboje VNÚTRI `guarded`** (zápis scale-lock atribútov mimo guardu by cez `EntitiesObserver#onElementModified` založil
oneskorený dirty tik a transparentný presun ghost zón by zasiahol Undo po dokončenom vložení); `ScaleWatch.attach_one` je až za guardom. Do stavby ide **pracovná (nezmrazená) kópia**
plánu: `PartKeys.migrate_overrides` zdieľa vnorené hashe overridov a `resolve_part` v nich in-place upratuje sticky `edge_warnings`.
`build` volá `ensure_root_context` **PRED** `prepare_insert`, aby pri výnimke z `normalize` používateľ skončil v roote presne ako doteraz; commit si root ešte raz idempotentne overí.

**Signatúra `build(model, params = nil, transform: nil, **kw, &block)` je kompatibilná zámerne.** Pred R-03 nemala metóda žiadny keyword parameter, takže Ruby 3 prevádzalo
`build(model, type: 'lower', width: 600)` na **pozičný hash** a takto sa volať dá. Holý `transform:` by tieto volania rozbil (`unknown keyword`), preto je `params` voliteľný a zvyšné
keywordy sa zbierajú do `**kw`: keď `params` chýba, použijú sa **ony** ako parametre skrinky. Jediné **rezervované** meno je `transform` (nie je to parameter korpusu — `normalize`
ho nepozná); kto by ho v params predsa len chcel, musí params poslať pozične. Params dvakrat (pozične aj keywordmi) je `ArgumentError`, nie tiché zliatie.
**Vedomé hranice R-03:** kontrakt čistoty `prepare_insert` je uzko formulovaný na *model, entity, ID a Undo* — `normalize` cez `Materials.normalized_abs_id` môže siahnuť na katalóg
na disku a logovať, a `Construction.build_plan` sa do prepare **nepresúva** (validačné chyby by sa zobrazili pred hardware blokom a pred commit-time snapshotmi). Súradnice
obálky/kotvy (`bounds_mm`) plán zámerne **nenesie** — uzavrie ich až GHOST dávka proti `BuildPlan`u. In-SU dôkazy: sekcia `run_r03` + `run_r03_async` (`su_runner.rb`).

**KÓPIA NÁSTROJOM (NÁSTROJE-1, v0.9.24)** ide **tým istým švom** ako „Vložiť kópiu" v paneli — `Store.config` → `newer_config?` (R-12) → `config_to_params` →
`rekey_hardware_manual` → `build(model, params, transform:)`. Rozdiel je len v **polohe**: `transform` je `src.transformation * translation(Units.vector(±šírka, 0, 0))`, teda
posun o **šírku korpusu z configu po VLASTNEJ osi X** zdroja. Preto pri akejkoľvek rotácii sedí susednosť **obálok korpusov** — a nie bbox inštancie: čelo so záporným
`gap_sides` alebo úchytka smie šírku korpusu presahovať, takže sľub „dotyk bbox" neplatí (Codex #288; in-SU `run_tools1` to meria X-rozsahom korpusov aj prekryvom bboxov).
Kópia teda dostane vlastnú definíciu, nové sekvenčné CAB id a je **jeden krok Späť**. Toto je pointa D-20: legacy `add_instance(ent.definition, tr)` vyrábal kópiu **bez
identity**. `rigid_matrix?` sa od tejto dávky používa aj mimo vkladu — je to autorita rigidity pre cache `ScaleWatch` aj pre preflight nástrojov (nižšie).

**DOPREDNÝ GUARD CONFIGU (R-12, v0.9.3): `CONFIG_SCHEMA` + `guard_newer_config!`.** Config korpusu je uzavretý whitelist (`normalize` + `cabinet_config`), takže zákazka
z NOVŠIEHO pluginu prišla pri prvej prestavbe ticho o všetko, čomu táto verzia nerozumie — a uložením stratu zvečnila; `plan_schema` verzuje tranzientný tvar plánu
a `part_key_schema` len kľúče dielcov, takže kompatibilitu **configu** nevyjadrí ani jeden. Marker `config_schema` sa preto zapisuje v **jedinom zápisovom bode** —
`cabinet_config` (cez `write_cabinet_attrs` ním ide vklad AJ prestavba) — a **vždy ako aktuálna hodnota**; z params sa zámerne nepreberá (payload z CEF nie je autorita).
`guard_newer_config!` stojí v `rebuild_in_operation` vedľa `guard_unknown_hardware!`, číta **RAW uložený config entity** a pri vyššom čísle odmieta **prestavbu**; legacy
config bez markera (0) prechádza a **čítanie, výber, kusovník, VEPO ani exporty sa neblokujú**. Hlášku všetkých ciest skladá jediný zdroj `newer_config_message`.
**`dedup_copies` novšiu kópiu PRESKOČÍ** (kontrola pred `start_operation`, takže žiadna zrušená operácia ani krok Späť) a pokračuje zvyškom: výnimka by cez `rescue`
okolo celej metódy vyhladovala ostatné — kompatibilné — duplicity a follow-up tik sa už neplánuje. **Priznaný dôsledok:** preskočená kópia si necháva zdieľané
`cabinet_id`, takže Kontrola drží ORANGE `duplicate_identity` a zliate ID zastaví nákupné/cenové exporty (brána P0-2) — vedome: tichý orez výrobných dát je horší
než zastavený export.
**Štyri stratové cesty BEZ rebuildu majú vlastné odmietnutie** (guard nad cieľovou inštanciou by ich nechytil): použitie šablóny a vklad zo šablóny (autorita je
**uložený záznam**, nie payload — JS prenáša len známe polia), „Vložiť kópiu" (`config_to_params` → `build`) a „Uložiť ako šablónu" (`template_config_from` je ďalší
uzavretý whitelist). Šablónový config marker **nesie**, inak by šablóna z novšej verzie vyzerala ako legacy. In-SU dôkazy: sekcia `run_r12` + `run_r12_async`.
**História markera:** `1` = R-12 zavedenie · **`2` = KOV-A1** (nové typy čela `lift`/`fall`/`blind` a nové polia položky `direction`/`wing_directions`/`opening_mode`/`drawer`) —
tichá strata ktoréhokoľvek z nich by zmenila výrobu alebo zahodila vedome určený smer, čo je presne prípad z disciplíny bumpu (STANDARD §2.5) · **`3` = KOV-H1** (ad-hoc kovanie
`hardware_manual[]`) — tichá strata by ODOBRALA POLOŽKU Z OBJEDNÁVKY. **Dôsledok pre prax:** model uložený s markerom 3 odmietne prestavať starší plugin, preto sa pred prvým
takým modelom aktualizujú **obe PC** (D-52 updater). K bumpu 3 patrí **EXPORTNÁ brána** (`Bom.collect` → `newer_configs` → `ProductionCore.export_blockers`, viď
[outputs.md](outputs.md)): sama prestavbová brána nestačila, lebo starší plugin by zákazku so schémou 3 bez problémov **vyexportoval** — len bez ad-hoc kovania (audit #15 BLOCKER 3).
· **`4` = KOV-B1** (sety s KLASIFIKÁCIOU cestujú v šablónach cez `hardware_set_defs` a projektový snapshot má `std` 3) — starší plugin by pri použití takej šablóny zmrazil do
.skp OREZANÝ set a nikto by už nevedel, že tam niečo bolo. Čísla sa prideľujú **sekvenčne podľa poradia mergov** (audit #17 FIX 5 — KOV-H1 vzala 3). K bumpu 4 patrí **DOPREDNÁ
brána** `HardwareSets.assess_set_defs` ([hardware.md](hardware.md)): R-12 marker odmietne novšiu šablónu SPÄTNE, `assess_set_defs` odmietne nečitateľné definície DOPREDU —
pri vklade aj pri použití, vždy PRED akoukoľvek operáciou, takže model sa nezmení ani o krok Späť.

**AD-HOC KOVANIE `hardware_manual[]` (KOV-H1, v0.9.18).** Ďalšie pole configu, nie nový zápisový kanál (audit #15 BLOCKER 1): panel ho posiela v `collectAll()` presne ako čelá,
takže ide cestou `apply_all` → `normalize` → **rebuild** — jeden krok Späť, guardy dokumentu aj skrinky, R-12, `push_selected(dedup: false)`. Cena je prestavba geometrie pri
pridaní položky (stovky ms) — vedome prijaté; „zápis configu bez rebuildu" je kandidát v [AUDIT_REGISTER](../../SYSTEM/AUDIT_REGISTER.md), nie súčasť H.

`norm_hardware_manual(raw, strict_owners: false, plan_keys: nil)` je **uzavretý whitelist** (`MANUAL_KEYS`) položky
`{id, owner_part_key|nil, source, code, name, unit, price_eur_vat?, qty, note}` a má **dva režimy**:

- **čítacia cesta** (default — rebuild, kópia, legacy config): nepoužiteľná položka vypadne s logom, `qty` musí byť **celé** číslo 1–999, MJ ide cez jedinú autoritu
  `HardwareCatalog.canonical_unit` (MJ mimo slovníka sa NEPREKLOPÍ na tiché „ks" — cena za balenie/meter by sa tvárila ako cena za kus), `note` sa orezáva na 200 znakov;
- **zápisová cesta** (`strict_owners: true`, panelový ADD/EDIT cez `Panel.manual_preflight` PRED rebuildom): každé odmietnutie je **`ManualRejected`** = odmieta sa **celá zmena**,
  žiadny tichý drop.

**Prísne sa kontrolujú LEN nové a reálne zmenené záznamy** (`strict_ids:`, review #283 P2-A). Panel posiela v každom `collectAll()` **celý uložený zoznam** — je to echo, nie
diff. Keby sa prísne validoval celý, nezmenené položky by sa posudzovali, akoby ich používateľ práve pridal: po zmiznutí kódu z katalógu by neprešla **žiadna ďalšia editácia
skrinky** a zmazanie čela-vlastníka by sa odmietlo namiesto toho, aby položka prežila ako `owner_missing` (čo B4 výslovne chce). Zúženie počíta čistá
**`manual_strict_subset(stored, submitted)`**: porovnáva odoslané záznamy s uloženým zoznamom podľa `id` + **odtlačku obsahu** (`manual_fingerprint`) a vracia ID, ktoré treba
overiť prísne. Odtlačok porovnáva **normalizované** hodnoty (`„2"` a `2` nie je zmena) a pri `source: 'catalog'` **zámerne vynecháva `name`/`unit`** — tie vlastní server, takže
premenovanie položky v katalógu nesmie z nezmenenej položky spraviť „upravenú"; pri voľnej položke sú to naopak údaje používateľa a ich zmena **je** editácia. Záznam **bez id**
je prísny vždy (uložené záznamy id majú, takže bez neho nemôže ísť o echo) a **duplicitné id** v odoslanom zozname je tiež prísne (druhý taký záznam je reálne nová položka).
`strict_ids: nil` = prísne sa kontroluje všetko (legacy volanie).

Štyri pravidlá kontraktu, ktoré rozhodli audit #15:

- **`source: 'catalog'` — klientovi sa verí LEN kód** (FIX 12). `name`/`unit` doplní **server** z katalógu podľa kódu; **cena sa NEUKLADÁ NIKDY** (BLOCKER 2) — položka sa oceňuje
  živou cenou katalógu ako každý iný nákupný riadok. Kód mimo katalógu sa pri ADD/EDIT **odmieta** („použi voľnú položku"), pri rebuilde sa zachová **snapshot** `name`/`unit`
  z configu, aby položka po zmiznutí kódu z katalógu nezmizla z objednávky.
- **`source: 'free'`** — `name` povinné, MJ zo slovníka, `price_eur_vat` Float ≥ 0 alebo nil („bez ceny", nikdy 0 — STANDARD §11.3), `code` je **vždy prázdny** (voľná položka sa
  nesmie tváriť ako katalógový kód a zliať sa s ním).
- **`owner_part_key`** (BLOCKER 4): `nil` = patrí celej skrinke. Existencia v pláne sa kontroluje **STRIKTNE len pri ADD/EDIT**; `normalize`/rebuild kľúč **nikdy nezahodí** —
  dielec mohol zaniknúť a `Bom.collect` to prizná ako `owner_missing` (ORANGE, položka ostáva v nákupe). Tichý drop by znamenal odobrať kus z objednávky.
- **`id`** je `PartKeys.segment`-bezpečný a unikátny v rámci skrinky; `normalize` **dopĺňa len chýbajúce a kolidujúce** (prvý výskyt si svoje drží). Nové ID pre všetky položky dáva
  **výhradne `rekey_hardware_manual`**, volaný len tam, kde z existujúcej skrinky vzniká NOVÁ — `dedup_copies` a „Vložiť kópiu" (FIX 10). V `normalize` sa nevolá **nikdy** (stráži
  mutačný test): prestavba by inak menila identitu položiek.

Round-trip drží štyri cesty: `normalize` (`hardware_manual:`) · `cabinet_config` · `config_to_params` · `Panel.template_config_from` (položky **cestujú so šablónou**; legacy
šablóna bez kľúča položky cieľa **nezmaže** — `merge_template` má rovnakú vetvu ako `plinth_recess`/`name`). Klientská strana je čistý pass-through **bez defaultov** (vzor A1),
viď [ui-lifecycle.md](ui-lifecycle.md).
**Allowlisty rolí (KOV-A1):** `PART_TAGS` (`flap`/`false_front` → `Noxun/Čelá`), `thickness_ok_for?` (18 / 18,6 / 19 mm ako ostatné čelá), `base_material_for` (čelný materiál)
a `materialized_part` (prepis hrúbky boxu, polohy pred korpusom aj výrobného údaja) poznajú obe nové roly.
**Charakterizácia scale cesty (nález behu, platí aj pre `guard_unknown_hardware!`):** absorpcia beží v **transparentnej** operácii pripojenej k používateľovmu Scale
kroku, takže `abort_safely` zruší **aj ten** — v okamihu, keď `process_dirty` výnimku chytí, transformácia už zväčšená nie je a `reject_scale` sa **nespustí**. Model
je teda korektne obnovený a undo stack čistý, ale **hlášku používateľ nedostane**. Je to prevzatá vlastnosť observera (dávka R-12 ju nezaviedla); zmena by siahala do
observer/undo lifecycle, a preto patrí do vlastnej audit-povinnej dávky.

**K1/D-108 smer dekoru dielca:** `effective_grain(sheet, override)` je JEDINÁ autorita efektívneho smeru (`override → materiál`) a `resolve_part` ho **materializuje RAZ** do
snapshotu dielca.

**Rotácia sa tu NEROBÍ** — `pd[:prod]` aj rozmery na entite ostávajú GEOMETRICKÉ (osi deskriptora, `part_faces`/D-88/D-104/hover a kovanie na nich stoja); výmenu dĺžka↔šírka +
dvojíc hrán robí až VEPO a zrkadlovo `validation.fits_on_sheet?`, a nikde inde (dvojitý swap = dielec objednaný v pôvodnej orientácii). Povolené hodnoty overridu drží konštanta
`GRAIN_OVERRIDES` (`length`/`width` — „bez smeru" je vlastnosť materiálu, nie voľba na dielci); `norm_overrides` ju používa ako **whitelist**, takže neznáma hodnota (aj z novšej
verzie pluginu) do configu neprejde.

**Materiál bez smeru override IGNORUJE, ale NEMAŽE** — rozhodnutie používateľa prežije dočasný UNI/jednofarebný materiál a s dekorom ožije. Chýbajúci kľúč = dedenie, takže staré
modely sú platné a ich otvorenie nezapisuje nič. Ďalej: regenerate; vizuál nôh **a úchytkových profilov (D-90)** ako **proxy** (kind hardware, production_class none, manufactured
false — zdroj pravdy súpisu je VÝHRADNE `config.hardware[]` korpusu). Profil: definícia per (profil, dĺžka) `NOXUN_PROFILE_<ID>_L<dĺžka>` s recykláciou podľa mena + odtlačok
`PROFILE_GEOM_REV` (zmena obrysu prekreslí staré definície), kotva = zadná rovina čela (Y 0) a vrch PÔVODNÉHO čela. **TAG profilu je tag jeho ČELA, nie Kovania** (D-116, Michal 3.9.):
`part_tag(model, pd[:role])` — úchytka je s čelom zrastená, takže pri skrytí tagu „Čelá" musí zmiznúť s ním (predtým visela vo vzduchu). **Vedomý dôsledok: prepínač tagu Kovanie ju už
neschová** — patrí k čelu, nie k nohám (tie na `hardware_tag` ostávajú). Dáta proxy sa tým NEMENIA (súpis, nákup ani dĺžka rezu sa tagu nedotýkajú) a staré zákazky sa preznačia pri
najbližšej prestavbe — proxy vzniká pri každom rebuilde nanovo, takže žiadna migrácia netreba. Stráži in-SU sekcia `run_d116`.

**PRERUŠENIE STAVBY** (`abort_safely`): výnimka kdekoľvek vnútri `build`/`rebuild` ruší CELÚ operáciu a **neprehĺta sa** — volajúci sa o nej dozvie. Rollback vracia geometriu
(inštanciu aj definície dielcov) **a zároveň modelové atribúty**, teda aj projektové snapshoty kovania, ktoré `build_into` cestou `HardwareRules.ensure_project_rules!` /
`HardwareSets.ensure_project_state!` stihol zapísať — preto sa smú volať len vnútri operácie volajúceho. Zafixované scenárom `CH4` (`run_char`; sonda necháva `build_into` dobehnúť
celé a hodí výnimku až nad hotovým torzom, inak by test kontroloval prázdnu definíciu). **Obe cesty sú prejdené zvlášť:** `CH4a` = `build` (čerstvá definícia, žiadna živá
inštancia) · `CH4c` = `rebuild` nad **živou** skrinkou, kde `rebuild_in_operation` robí `cdef.entities.clear!` **pred** stavbou, takže v okamihu výnimky je definícia
používateľovho korpusu prázdna — scenár overuje, že sa vráti inštancia, config, geometria dielec po dielci aj transformácia a že zlyhaná prestavba nenechá krok Späť
(kvalifikované sondou undo stacku, nie počtom korpusov). Bez `CH4c` by rollback špecifický pre `rebuild` mohol používateľovi korpus vygumovať pri zelenej bráne.

**KÓPIA A `*N` NÁSOBENIE** sú zafixované `CH1`/`CH2` tej istej sady: kópia dostáva vlastné `cabinet_id`, vlastnú definíciu (`make_unique`) a prepočítané `part_id`, kým `part_key`
ostáva ROLOU. Config prežije kopírovanie kompletný **až na odvodenú identitu zón** — `zone_tree` skladá z `cabinet_id` polia `id` aj `parent`; trvalým kľúčom je `stable_id`
(= `node_id` stromu), lebo cez `PartKeys.zone` vstupuje do `part_key`, ktorým sú kľúčované `part_overrides` (`migrate_overrides`). Po `*N` musí kusovník ukázať násobené množstvo —
násobenie sa meria až vo výrobnom výstupe, nie na počte inštancií. **`CH2` ide VERNOU sekvenciou nástroja, nie skratkou:** najprv jedna Move+Ctrl kópia vo vlastnej commitnutej
operácii → spracovanie observerom → **interné Undo nástroja** (kópia musí zmiznúť CELÁ) → až potom pole troch kópií v jednej operácii. Skok rovno na tri kópie by neodhalil, že
dedup po tej prvej kópii pridal vlastný undo krok — vtedy interné undo trafí jeho, kópia prežije ako „zombie" a pole k nej pridá ďalšiu skrinku (živá chyba D-103; pre dosky to
meria `async S6`).

### ghost_tool.rb

**GHOST VKLADANIE (V1-04): skrinka sa kladie KLIKOM, nie tlačidlom.** Modul drží tri vrstvy — `GhostTool` (vlastník session + čisté API pre panel), `GhostTool::Calc`
(**čistá matematika bez SketchUpu** — kotvy, obálka, kanonická matica, ray × rovina zámku; testovateľná headless), `PlacementSession` (stav jedného vkladu) a `GhostTool::Tool`
(SketchUp `Tool`). Ghost je **výhradne viewport grafika `draw`** — žiadna dočasná `ComponentInstance`, žiadna entita, žiadne ID a **žiadny krok Späť pred klikom**.

**JEDEN vlastník session.** Modul drží NAJVIAC JEDNU session (`GhostTool.session`). Nesie: zmrazený `InsertPlan` (R-03 `prepare_insert`) · snapshot kovania zo šablóny
(`take_insert_hardware!`) · šablónový ref · pôvodný model · **stav `:active` → `:committing` → `:committed` | `:cancelled`** · `rotation_index` (0..3) · `anchor` · `z_mode` ·
poslednú platnú polohu s príznakom `placeable`. **Terminálne stavy sú idempotentné** — druhý klik aj druhý cancel sú no-op, takže dvojklik nikdy nevyrobí dve skrinky.
Identita dokumentu je **objekt `Sketchup::Model`, nie `guid`** (mení sa pri každom uložení — lekcia #261/#264), takže Ctrl+S ghost nezruší.
**Všetky konce životného cyklu rušia starú session PRED čímkoľvek ďalším:** druhé „Vložiť" (nová session s čerstvým snapshotom) · zavretie Inspectora (`set_on_closed`) ·
**File > New / Open** · aktivácia iného dokumentu · `onCancel` 0/1/2 · `deactivate` · iný spôsob vloženia (`handle_insert_copy`, `handle_insert_board`).

**Prepnutie dokumentu má DVE obrany a Windows drží tú prvú.** `GhostTool.on_document_replaced` (volá ho `PanelAppObserver#onNewModel`/`#onOpenModel` ešte pred prepnutím
observerov) ruší session **bezpodmienečne** — Windows drží jeden dokument na proces a pri File > Open smie **recyklovať ten istý `Sketchup::Model` objekt**, takže porovnanie
identity by vrátilo „ten istý dokument" a session by prežila do cudzej zákazky (`commit_insert` by prešiel z rovnakého dôvodu). Porovnanie objektom
(`GhostTool.on_model_switched`, cesta `onActivateModel`) je **druhá obrana pre macOS multi-dokument**; tam musí platiť opak — aktivácia toho istého dokumentu ghost rušiť nesmie.
Na `guid` sa spoľahnúť **nedá ani ako na kľúč, ani ako na doplnok identity**: mení ho každé uloženie, takže by Ctrl+S ghost zabil (package to zakazuje). Ghost môže existovať len
s otvoreným Inspectorom a ten `PanelAppObserver` vždy pripája (`attach_observer` → `ensure_app_observer`), takže prvá obrana je vždy aktívna.
Slot session sa uvoľňuje aj nad stavom `:committing` — commit prerušený výnimkou **mimo `StandardError`** by ho inak držal až do reštartu.

**ZÁVÄZNÁ tabuľka kotiev.** Predná rovina korpusu je **vždy lokálne Y = 0** (čelá majú záporné Y a do kotiev NEVSTUPUJÚ; plinth recess ani presah čela rovinu Y = 0 nemenia).
Dolná `under_sides` → spodok tela je DNO na `floor_height`; dolná `between_sides` → boky stoja na zemi, spodok je Z = 0; **horná normalizuje `floor_height` na 0**, takže oba
varianty dna majú spodnú kotvu na Z = 0 (`UPPER_HANG_Z` je SVETOVÁ výška originu, nie lokálna kotva). Poradie cyklovania (Alt): ľavá-dolná → pravá-dolná → pravá-horná → ľavá-horná.

**Transform sa skladá VŽDY NANOVO z celočíselného stavu** (`rotation_index % 4`), nikdy inkrementálnym násobením: `COS`/`SIN` sú tabuľky presných 0/±1, takže matica prejde
`CabinetBuilder.rigid_matrix?` (R-03, `RIGID_TOL` 1e-6) bez numerického šumu aj po stovkách otočení. **Free Z:** `translation = picked − R(anchor)`. **Zámok typu (↓):**
`translation.z = lock_plane_z` NAPEVNO — **lokálne Z kotvy sa NEODČÍTA** (origin skrinky drží zamknutú výšku; default je domáca výška typu: dolná 0, horná `UPPER_HANG_Z`),
X/Y sa berie z bodu pod kurzorom (hybrid nižšie). **Oba typy ŠTARTUJÚ v `:locked`.**
`Calc` počíta v mm; `to_inch_matrix` prevedie **len transláciu** (rotačná časť je bezrozmerná).

**Kotva je VŽDY pod kurzorom — aj po Alt (GHOST-FB2).** Translácia sa skladá z *aktuálnej* kotvy a *aktuálneho* kliknutého bodu, takže prepnutie kotvy skrinku **presunie**
tak, aby nová kotva skočila pod myš; rotácia sa tým točí okolo kurzora. Je to **jedno pravidlo pre celé ovládanie** a platí vo všetkých 4 kotvách × 4 rotáciách × oboch
režimoch (headless dôkaz). V zámku to platí pre X/Y — Z drží zámok, to je jeho zmysel.

**Zámok výšky je HYBRID: snap na geometrii najprv, rovina až ako fallback (GHOST-FB1).** `pick_locked` sa najprv pýta `InputPoint.pick` presne ako Move; keď snap sedí na
**reálnej geometrii**, vezme si z neho **X/Y** a **Z prepíše zámkom** (`Calc.lock_point`). Inak sa počíta dnešný priesečník lúča s **rovinou zámku** (svetový rám, nie
drawing axes) — preto ghost sedí pod kurzorom aj v úplne prázdnom modeli. Bez hybridu nemalo vkladanie v zámku **žiadne prichytávanie**: v rovine Z = 0 nie je pri dolnej
skrinke so soklom čoho sa chytiť, a roh susednej skrinky leží 720 mm nad ňou.

**Brána `ip_on_geometry?` (`vertex` / `edge` / `face`) je podstatná, nie kozmetická.** „Voľný" bod inference — bod na podlahovej rovine **kreslenia** tam, kde nie je nič —
by v zámku **klamal** a in-SU sada to zmerala na štyroch miestach naraz: hornej skrinke leží rovina zámku 1400 mm nad podlahou, takže X/Y z podlahy ju **odsunú od kurzora**
(`run_ghost` 3); pri **otočených drawing axes** ju odsunú tiež, hoci zámok má držať svetový rám (6); a v **degenerovanom pohľade** (rovina za kamerou, walk pohľad) by taký
bod **obišiel guardy** `MIN_SIN` / `MAX_REACH` a spravil nepoložiteľný stav položiteľným (8, 8b). Zdravotný strop (`sane_point?`) platí **obom** cestám — bodu z inference
aj výsledku so zamknutým Z. Inference sa pýtame v **oboch** režimoch, takže `@ip` je vždy čerstvý a `draw` z neho kreslí **natívne zvýraznenie snapu**
(`@ip.draw` + `view.tooltip`, len keď `display?`) — farby a tvary rohu/stredu/hrany sú konvencia SketchUpu, vlastnú grafiku snapov si nekreslíme.

**Zamknutá výška je prestaviteľná a pamätá sa (GHOST-FB3/FB4).** `PlacementSession#lock_plane_z` je default `plan.home_z`, ale Ghost pásik Inspectora ju smie prepísať
(`set_lock_z!`, validácia `Calc.lock_z_value`: mm Float, rozsah `LOCK_Z_MIN_MM`..`LOCK_Z_MAX_MM` = 0–3000; neplatný vstup **nič nemení**). Zmena platí okamžite pre živý
ghost aj pre commit. Kotva, rotácia, režim výšky a zamknuté výšky (**per typ** skrinky) žijú v **modulovej pamäti `GhostTool.memory`** — per proces, do vypnutia
SketchUpu, **bez zápisu na disk aj do modelu**: je to pracovný návyk jedného sedenia, nie údaj zákazky (inak by sa cudzia zákazka otvorila s cudzími kotvami). Nová session
z nej štartuje; `reset_memory!` (testy, in-SU teardown) vráti továrenské hodnoty. Stav session ide do panela cez `GhostTool.push_state` → `Panel.push_ghost` → `NX.setGhost`
— pri každom konci session s `active = false`, takže pásik zmizne.

**Degenerované lúče** (`Calc.ray_plane`) majú **dve nezávislé brány** — samotné „`|dir.z|` nad epsilon" je mŕtvy strážca: pri normalizovanom vektore ho prejde aj lúč jeden
pixel pod horizontom (`dz` ≈ 1e-4) a `t` vyjde rádovo 10⁶, takže by klik položil korpus **kilometre od originu** (`rigid_matrix?` transláciu nijako neobmedzuje). Priesečník preto
platí len keď (a) je lúč voči rovine dostatočne **sklonený** — `|dz| / |dir| > MIN_SIN` (1e-3 ≈ 0,057°; podiel, takže na jednotkovosti smeru nezáleží), (b) `t >= 0` (rovina PRED
kamerou) a (c) výsledok je v **zdravom dosahu** `MAX_REACH_MM` (1 km od kamery aj od originu). Ten istý strop (`Calc.sane_point?`) platí aj pre **free inference** — bod na
extrémne vzdialenej geometrii sa nesmie stať polohou. Inak ghost **drží poslednú platnú polohu**, `placeable = false` (stlmená kresba) a **klik NECOMMITNE** — status povie prečo.
Platí aj pre hornú rovinu `UPPER_HANG_Z` s kamerou nad ňou.

**Tool lifecycle.** Aktivácia `model.tools.push_tool` (NIE `select_tool` — pôvodný nástroj sa zachová) + `UI.start_timer(0) { Sketchup.focus }` (CEF by si po HtmlDialog callbacku
vzal fokus späť a klávesy by nefungovali). Koniec = **presne jedno `pop_tool`** cez `GhostTool.end_tool`; z Tool callbackov **odložené** timerom, z panela (`start`) **synchrónne** —
inak by odložený pop zhodil práve pushnutý nový nástroj. Prepnutie na iný nástroj chodí cez `deactivate` (nie `onCancel`) a **nepopuje**; `suspend`/`resume` (Orbit/Pan) session
DRŽÍ. `getExtents` vracia obálku ghostu (bez nej by ho SketchUp orezal mimo bounds).

**`pop_tool` odoberá VRCH STACKU, nie našu inštanciu** — preto nestačí držať referenciu na vlastný nástroj. Keby medzitým niekto (iný extension v `onTransactionCommit`, natívny
nástroj) pushol nástroj **nad** nás, slepý pop by zhodil **jeho** a ghost by ostal visieť aktívny bez session. Nástroj si preto sám drží príznak **„som vrch stacku"**
(`on_top?`: `activate`/`resume` → true, `suspend`/`deactivate` → false) a `pop_tool` bez neho **nepopne nič** — ukončenie sa **odloží** (`request_finish!`) a dokoná sa pri
najbližšom `resume`, teda presne keď sa vrch stacku vráti k nám. `active_tool_id` sa na rozhodovanie **nepoužíva** (nemapuje sa spoľahlivo na inštanciu). `detach!`/`attached?`
robia pop navyše idempotentným.

**Odložené ukončenie je viazané na INŠTANCIU, nie na globálny stav.** `resume` s `finish_pending` popne **seba** (`GhostTool.pop_tool(self)`, odložene timerom), nie „aktívny
nástroj": pri druhom „Vložiť" počas **suspendovaného** ghostu (cudzí nástroj nad ním) sa starý nástroj popnúť nedá, session mu zanikne a `@active_tool` medzitým prepíše NOVÝ
ghost — globálne `end_tool` by starú inštanciu už nepoznalo a tá by ostala visieť ako vrch stacku bez session, kým používateľ ručne neprepne nástroj. Z rovnakého dôvodu je
nástroj **viazaný na svoju session** (`live_session` porovnáva identitu objektu): nástroj bez vlastnej živej session **nekreslí, nevlastní klávesy a klik ignoruje** — starý
ghost tak nikdy neobsluhuje ani nekreslí session, ktorá patrí novému. Globálna session sa číta na **jedinom mieste** — v `activate`, kde sa na ňu nástroj viaže.

**Klávesy:** ←/→ rotácia ∓90° (na PRVÝ down; `repeat > 1` vracia true bez zmeny), ↓ zámok, ↑ voľná výška, **Alt (`VK_MENU`/`VK_ALT`) cykluje kotvy** — zachytáva sa down AJ up
a vracia true (minimalizuje aktiváciu menu-baru Windows). Klávesu vlastníme len so **živou** session; ostatné vracajú `false`. **Hranica testovania:** headless ani in-SU sada
nedokáže overiť, či Windows Alt do Toolu naozaj **doručí** a či sa pritom neaktivuje menu lišta — testy overujú len správanie handlera. Systémové doručenie Alt patrí
**Michalovmu smoke checklistu** (`SYSTEM/PLAN.md`, sekcia GHOST, bod 2); zapísaný fallback pri zlyhaní je **TAB** (Scope OUT dávky, cyklovanie kotiev je preto jedna volateľná
metóda `PlacementSession#cycle_anchor!`). **Každý Tool callback je obalený** (`guarded`) — výnimka v callbacku sa inak ticho prehltne a nástroj „záhadne" prestane kresliť.
**V `draw` sa NIKDY nevolá `Construction.build_plan`** — obálka je 8 bodov spočítaných RAZ zo zmrazeného configu.
**Farby ghostu:** obrys neutrálna tmavá (`OUTLINE_RGB`), kotva rodina výberu (`ANCHOR_RGB`), nepoložiteľný stav stlmený (`DIM_RGB`) a **predná stena JASNÁ ZELENÁ**
(`FRONT_RGB = #00C85A`, v0.8.25). Pôvodný tmavý teal `--nx-select` v modeli **splýval** s obrysom ghostu aj s čiernymi hranami geometrie (Michalov živý test 31.8.) —
orientácia ghostu sa nedala prečítať. Zelená je jediná „kričiaca" farba ghostu a v modeli nekoliduje s ničím; ghost nemá výplň, kreslí sa len `GL_LINE_LOOP`.

**Commit ide výhradne cez šev R-03** `CabinetBuilder.commit_insert(model, plan, transform:)` so sprievodným blokom (H2/D-76 zmrazenie setov kovania) — žiadny vlastný zápis do
modelu, žiadny nový selection mechanizmus. Po úspechu `Panel.ghost_after_commit` (výber, status, `push_selected`, pečiatka šablóny cez `stamp_once!`) beží **mimo operácie**
a jeho zlyhanie NESMIE zabrániť zatvoreniu committed session. **Žiadny ručný `StudioModelWatch` notify** — stale signalizáciu rieši `onTransactionCommit` sám.
**Vedomý posun oproti stavu pred ghostom:** guardy STAVBY (`Fronts.validate_layout!`, interior validácie) bežia až v commite, takže konflikt „zámok × šablóna" (F8) sa ohlási
pri KLIKU, nie pri stlačení „Vložiť" (hláška je tá istá — `Panel.ghost_insert_failed`); `Construction.build_plan` sa do `prepare_insert` zámerne nepresúva (hranica R-03).
Zlyhaný commit session **končí** (preflighty už prebehli, opakovaný klik by zlyhal rovnako). Programatická cesta `CabinetBuilder.build` (`Placement.next_x` fallback)
a `handle_insert_copy` sú GHOSTom **nedotknuté**. Testy: `tests/pure/test_ghost_vkladanie.rb`, in-SketchUp sekcie `run_ghost` a `run_ghost_async`.

### board_builder.rb

samostatná doska (V0.4.7): `kind: board`, id BRD-xxx, rola `free_panel`, config = superset dielca korpusu (kusovník/VEPO majú jeden svet); materiál snapshot z katalógu, hrúbka VŽDY
z materiálu; manufactured true + production_class sheet na inštancii.

**ORIENTÁCIA (UI-C1c, `config['orientation']`: `leziaca` | `stojaca` | `na_stenu`) je VÝHRADNE TRANSFORMÁCIA INŠTANCIE** — geometria v definícii ostáva ležiaca (`draw_board`: dĺžka
X, šírka Y, hrúbka Z), takže osi deskriptora (`PartFaces::AXES_LYING`), mapa hrán D-88, farbenie ABS, kusovník aj VEPO sú orientáciou **nedotknuté**; do `descriptor.prod`,
`descriptor.axes`, agregačného kľúča kusovníka ani `AbsRules.edge_sides` sa **nikdy** nedostane (je to údaj umiestnenia, nie výroby — STANDARD 3.3).

Matice (`orientation_matrix(orientation, thickness_mm)`): **ležiaca** = identita; **stojaca** = `R_x(+90°)` a potom posun o `thickness` po +Y — telo v X = 0..dĺžka, Y = 0..hrúbka,
Z = 0..šírka, **dekorová plocha má normálu −Y** (mieri dopredu, leží v rovine Y=0) a spodná dlhá hrana sadne na Z=0; **na_stenu** = **zámerne tá istá matica** ako stojaca (enum je
údaj umiestnenia so sémantikou — zadná plocha je pri stene v +Y, budúce prisatie/elevácia; testy tieto dva stavy rozlišujú **poľom v configu, nikdy bboxom**). Zmena orientácie je
**DELTA**, nie absolútna matica: `T_new = T_current × inverse(O_old) × O_new` (obe z rovnakej hrúbky, takže sa `O_old` presne vykráti) — ručné otočenie/posun používateľa preto
prežije a opakované prepnutie **nekumuluje**; pole eviduje LEN pluginom aplikovanú orientáciu.

**Rebuild transformáciu nemení** (`rebuild_in_operation` orientáciu neaplikuje druhýkrát; `transform:` je vždy finálna transformácia od volajúceho). Guard slovníka
(`norm_orientation`, jediná autorita pre insert aj edit): chýbajúca/prázdna ⇒ `leziaca`, **explicitná neznáma ⇒ výnimka** (žiadna tichá preklasifikácia configu z novšej verzie).

**Vedomá odchýlka:** keď sa medzi dvomi prepnutiami zmení hrúbka, transformácia sa neprepočítava — v Y ostane rozdiel starej a novej hrúbky (rádovo mm; poloha je vec umiestnenia,
prepočet pri každom rebuilde by dosku posúval pod rukami).

### placement.rb

top-level umiestňovanie

### zones.rb

ghost boxy (predvolene VYPNUTÉ, klik na zóny cez 2D náhľad; ghost skupiny žijú PRIAMO v `model.entities`, takže holý počet entít modelu sa zónovou zmenou legitímne mení).

**Vlastný `set_visible` tu od D-27 (v0.8.13) NIE JE** — viditeľnosť tagu `Noxun/Zóny` prepína spoločná cesta `Tags.set_visible` (nižšie), tá istá, akou sa prepínajú ostatné NOXUN
tagy. Dva ovládače nad jedným tagom (checkbox „Zobraziť zóny (ghost) v modeli" v sektore Náhľad a okno tagov v raile) tak nemajú ani dva stavy, ani dve undo semantiky. `visible?`
ostáva (číta `TAG` aj legacy `OLD_TAG`) a `migrate_tag` beží ďalej pri stavbe ghostov.

### tags.rb

**D-27 (v0.8.13): viditeľnosť NOXUN tagov modelu z panela.** Modul tagy **netvorí ani nepremenúva** — tvoria ich buildery (`CabinetBuilder.part_tag` / `hardware_tag`,
`BoardBuilder.board_tag`, `Zones.sync_ghost`); vie ich iba **nájsť a prepnúť**. Sedem kľúčov (`ROWS`: korpus · chrbat · cela · vnutro · kovanie · dosky · zony) a **mená sa čítajú
za behu z konštánt builderov** (`const_defined?` guard) — v module nie je opísaný ani jeden reťazec, takže premenovanie tagu v builderi sa sem premietne samo.

`state(model)` je **čisté čítanie** (žiadna operácia, žiadny zápis): riadky **len za tagy, ktoré v modeli naozaj sú** (D-78 — mŕtve tlačidlo je horšie než žiadne), každý s `visible`
(vlastná viditeľnosť) a `folder_hidden` (nadradený **priečinok tagov** je skrytý — tag je zapnutý, no vidieť ho aj tak nie je; priečinok sa nikdy nezapína automaticky, môže niesť
cudzie tagy). `hidden` = počet tagov, ktoré v modeli nevidno — podľa neho svieti ikona v raile.

`set_visible(model, key, visible)` je **jediná zapisovacia cesta**: whitelist kľúča (`KEYS`), výslovný boolean, a keďže **viditeľnosť tagu sa ukladá do .skp** (na rozdiel od
`edge_check`/`grain_check`, ktoré kreslia overlay NAD modelom — lekcia D-103), beží v `start_operation`/`commit_operation` = **presne jeden krok Späť**, s **abort vetvou** (výnimka
nesmie nechať otvorenú transakciu). Keď sa nič nemení (neznámy kľúč, tag neexistuje, hodnota už platí), **operácia sa vôbec neotvorí** — v ponuke Späť nepribudne prázdny krok.
Dve vedomé výnimky: tag `Noxun/Zóny` sa **smie založiť z panela** (`CREATABLE_KEYS` — checkbox ghost zón to vedel aj pred D-27; v modeli bez ghostov tag ešte neexistuje a bez toho
by sa checkbox po kliknutí vracal späť), a pre ten istý kľúč sa **tolerantne číta aj legacy `Zones::OLD_TAG`** (`NOXUN_SLOTY`), inak by staršia zákazka tag „nenašla". Skrytie
**aktívneho** tagu prepne kreslenie na Untagged **vedome a v tej istej operácii** (SketchUp to inak spraví sám a ticho) a vráti to v `active_reset` — panel to povie v statuse.

Server je jediný zdroj stavu: `Engine.set_tag_visible` → `broadcast_tags` → `Panel.push_tags`; PULL pri otvorení panela (`push_init` pole `tags`) a push pri **každom**
`push_selected` (Späť/Znova, prepnutie dokumentu, zmena výberu — tag sa dá skryť aj natívnym oknom Tags). **Známe obmedzenie:** buildery tag po zmazaní všetkých jeho dielcov
nerušia, takže v ponuke môže ostať tag bez geometrie; počítanie použitia by znamenalo rekurzívny sken modelu pri každom pushi. Testy: `tests/pure/test_d27_tagy.rb`,
`tests/js/test_d27_tagy.js`, in-SketchUp sekcia `run_d27`.

### zone_tree.rb

strom zón (štandard §1 a §5), čisto výpočtový modul (mm Float). Uzol = `{ id, generation, split, shelves, children }`; delenie `split = { axis, count, cuts[] }`, `cuts[i] = { size,
locked }` = jedno pole odspodu/zľava.

**Police sú MODUL listovej zóny — zónu nedelia** (`Shelves::MAX`, od UI-C2 **6**).

**Mutačné guardy (UI-C2):** `set_split!` aj `set_shelves!` bežia **VÝHRADNE na LISTE** (`leaf?`) a `set_split!` navyše len do `MAX_LEVELS = 3` úrovní (N22) — opakované delenie by
ticho zmazalo celý podstrom aj s materiálmi a ABS dielcov, preto je jedinou deštruktívnou cestou `clear_zone!`. Guard je **serverový**, HTML `disabled` sa za ochranu nepovažuje;
mutácia vracia `true/false` a volajúci to **musí vetviť** (odmietnutie = žiadny rebuild).

**`sanitize` hĺbku NIKDY neorezáva** — legacy strom aj šablóna z novšej verzie sa musia dať prečítať aj postaviť (orezanie by zmazalo dielce živej zákazky); hĺbku hlási `depth` a
panel ju rieši varovaním.

**Geometria zlomkov a magnetu je JEDNA funkcia** (`clear_space` · `cum_for_fraction` · `snap_cum` · `fraction_options`): zlomok aj magnet hovoria o tom istom — kde má sedieť
**STRED priečky** (`frac*span`), a výsledný **rozmer poľa sa meria vo SVETLOM priestore** (`span − (count−1)*t`), takže 1/2 pri dvoch poliach dá `(span−t)/2`, nie `span/2` (mockup
rátal nahrubo — rozdiel 9 mm na boku). Zrkadlo žije v `ui/js/zone_tree.js` (`NXZ` + `nxZone*`), zhodu čísel stráži test.

**Vstup z panela sa validuje PRÍSNE** (`validate_cuts` + `strict_mm`): konečné číslo, `>= MIN_FIELD`, súčet na svetlý priestor s toleranciou `FIELD_EPS` 0,01 mm; `sanitize_cuts`
ostáva zámerne tolerantná (je to **opravná** vrstva legacy stromov), ale zapisovacia cesta tolerantná byť nesmie — `'650-36'.to_f` by ticho vyrobilo 650 a stolár iný nábytok.
`resolve_fields` drží kumulatívny clamp zamknutých polí; `validate_split!`/`validate_shelves!` rebuild radšej **odmietnu**, než by ticho zmenšovali.

### front_profiles.rb

**D-90 úchytkové profily** (UKW-7): JEDINÝ zdroj konštánt — skrátenie čela (36 mm), názvy pre UI (`options` do `push_init`) a presný prierez pre vizuál (`geometry`: 83 bodov,
19,181 × 37,419 mm). Registry je rozšíriteľný (nový profil = nový záznam); `'none'` v ňom NIE je — je to neutrál a zároveň default chýbajúceho kľúča (žiadna migrácia starých
configov). Číta ho fronts (matematika panelu), pravidlá kovania (dĺžka rezu) aj builder (proxy geometria).

## Modules (`noxun_engine/modules/`)

### shelves.rb

police v zónach: rovnomerné rozloženie v svetlej výške (`n` políc ⇒ `n+1` medzier).

**`MAX = 6`** (UI-C2, pills 0–6 kontraktu UI 2.0) — strop, **nie numerický fallback**: kto chce viac priehradiek, zónu rozdelí. Číslo má **dve zrkadlá** (`NXZ.MAX_SHELVES` v
`ui/js/zone_tree.js` a pilulky v `ui/js/actions.js`) a ich zhodu stráži test; geometrickú stránku vysokých počtov chráni `ZoneTree.validate_shelves!` (zóna musí mať `n*t +
(n+1)*MIN_FIELD` svetlej výšky, inak sa rebuild odmietne).

### fronts.rb

čelá fixed/auto s lockmi, „bez čela", krídla 1–4, **úchytkový profil na hornej hrane (D-90 — riadok drží výšku, skracuje sa PANEL; `profile_band` je podklad vizuálu aj náhľadu)**.

**KOV-A1 — TYPY:** `items[].type` ∈ `door` · `drawer_front` · `lift` (výklop) · `fall` (sklop) · `blind` (blenda) · `none`; neznámy typ sa (ako doteraz) sklopí na `door`.
`lift`/`fall` → rola **`flap`**, kľúč `front:F#/flap`, suffix `FLAP-#`, názvy „Výklop #" / „Sklop #"; `blind` → rola **`false_front`**, kľúč `front:F#/blind`, suffix `BLIND-#`.
Oba typy majú **identickú panelovú matematiku ako zásuvkové čelo** (1 panel cez celý otvor, `wings_n` 1, `AXES_FRONT`). **Vedomý limit A1:** úchytkový `profile` je pre
`lift`/`fall`/`blind` (aj `none`) normalizovaný na `none` — profilové pravidlo D-90 pozná len dvierka a zásuvku, inak by vznikol falošný `profile_rule_missing`
(profil na pohyblivom čele = KOV-E/F). UI ich sprístupní až KOV-A2; v A1 vznikajú len cez config/API a select typu ich nesie ako **neaktívne** voľby.

**KOV-A1 — ŠTYRI NOVÉ POLIA POLOŽKY (trojstav + dormant):** `direction` (smer otvárania = **strana pántov**, `left` = pánty vľavo) · `wing_directions` (`{p2, p3}` pre stredné
krídla 3/4-krídlových dvierok) · `opening_mode` (`classic|tipon`) · `drawer` (`{construction: metal|wood|other, variant: standard|internal}`, pod-polia nezávisle).
**TROJSTAV smeru (audit #14 B1):** kľúč CHÝBA = legacy — **nikdy sa nedopĺňa** a nikdy nedá nález · `unset` = vedome neurčené (RED) · `left`/`right` = vyriešené.
`unset` vzniká VÝHRADNE používateľskou akciou (A2) alebo z **poškodenej hodnoty** (neznámy neprázdny string → `unset`, fail-visible; `nil`/`''`/iný typ → kľúč sa zahodí).
Neplatný `opening_mode` a `drawer` bez platného pod-poľa → kľúč preč (tam žiadny „neurčený" stav neexistuje). **DORMANT (B3):** všetky štyri sa v configu držia bez ohľadu na
aktuálny typ a počet krídel, takže prepnutie typu alebo `1 ↔ 2 ↔ auto` hodnotu nezahodí; po návrate sa obnoví. Guard test stráži, že **žiadna cesta v Ruby ani JS** nedopĺňa
default smeru a že literál `unset` žije len v `fronts.rb` (výrobca) a `bom.rb` (čitateľ).

**`Fronts.direction_slots(resolved_item)` = JEDINÁ definícia „kde sa smer pýta"** — čistá funkcia nad **resolved** položkou (`front_items`), rozhoduje **efektívny `wings_n`**
(auto okolo 600 mm na čelnom otvore), nikdy surové `wings`: 1 krídlo → `single` · 2 → `[]` (odvodené Ľ+P) · 3 → `p2` · 4 → `p2`+`p3` · ne-dvierka → `[]`. Vracia
`[{wing:, part_key:, state:}]`, kde `state` `nil` = legacy. Čítajú ju `Bom.collect` (A1), overlay aj karta čela (A2) — **nikde inde sa o aplikovateľnosti nerozhoduje**.
Resolved položka navyše nesie `flap_dir` (`up` pre `lift`, `down` pre `fall`) — odvodený z typu, **nie je to default smeru** (O1 sa týka strany pántov).

## Osi dielca a prekrytia v modeli

### part_faces.rb

**D-88: JEDINÝ kontrakt „hrana → plocha kvádra"** (+ **D-104** `axes_for_snapshot`/`face_rect_mm` — vedomá legacy výnimka pre ČÍTANIE už postavenej zákazky: kandidáti podľa ROLY,
overené proti kvádru, akceptuje sa výhradne jednoznačná zhoda). Osi dielca (ktorá os boxu je dĺžka/šírka/hrúbka) sú **EXPLICITNÝ údaj deskriptora** (`axes:` z konštánt
`AXES_UPRIGHT/LYING/FRONT/WALL`) — zapisuje ich ten, kto box stavia (construction, zone_tree, fronts, board_builder), NIKDY sa neodvodzujú z hodnôt rozmerov (štvorcové čelo je
nerozhodnuteľné). Mapovanie: L1/L2 = min/max osi ŠÍRKY, W1/W2 = min/max osi DĹŽKY, plochy kolmé na hrúbku = veľké dekorové. `BuildPlan` tvar osí validuje; `verified_axes` navyše
kontroluje zhodu s box/prod — pri nezhode sa **nefarbí nič** (radšej žiadna farba než farba na zlej hrane).

### edge_check.rb

**D-104/D-105 kontrola hrán:** zvýraznenie stavu olepu priamo v modeli cez `Sketchup::Overlay` (SU 2023+, celý `edge_overlay.rb` pod guardom) — **žiadna operácia, žiadny undo krok,
nič v .skp**, sken je read-only (žiadny dedup tik).

**TRI STAVY** (`classify_edges`): `missing` (pravidlo žiada + páska chýba — vrátane vedome zrušeného olepu) · `extra` (pravidlo nežiada + páska chýba) · `taped` (páska je).

**Sada ABS pravidiel je jedinou autoritou**; materiál mimo katalógu / UNI / nelepiteľný sa preskočí vo VŠETKÝCH troch stavoch cez **zdieľané**
`Validation.abs_impossible?`/`uni_sheet?` (KOMPAKT nikdy nesvieti oranžovo). `flagged_edges` = kontrakt D-104 (`missing`). Všetky tri stavy sa kreslia PLNOU plôškou (`OUTLINE_ONLY`
prázdne — Michalov test 11.8. vyvrátil predpoklad o „mazanici": tenká linka je pri dieloch vedľa seba nečitateľná a prekrýva ju modré zvýraznenie výberu); farby `COLORS` sú
zrkadlom tokenov `--nx-edge-*` (stráži test). Identita výskytu = (skrinka, dielec) cez `entityID`, NIKDY `persistent_id` (kópie pred dedup tikom ho zdieľajú).

**Filter „len vybrané"** patrí VÝHRADNE zelenej — `build_selection_filter` berie výber + **`model.active_path`** (kópie zdieľajú definíciu, takže vnorený dielec má rovnaké
`entityID` — kontext rozhoduje, ktorý výskyt); prázdny výber = zelená sa nekreslí + hint. Prepínače žijú v `%APPDATA%\NOXUN\Engine\edge_check.json` (`set_option` = whitelist +
striktný boolean), **NIKDY v modeli**.

**Vstupné body 3-stavového nastavenia sú od ŠT-1b DVA VIDITEĽNÉ + jedna serverová cesta navyše** — rohový trojuholník pri tlačidle „Zvýrazniť hrany" v **lište sekcie Kontrola okna
ŠTÚDIO** (ŠT-1b, tvar podľa schváleného mockupu) a rohový trojuholník pri ABS kontrole v **raile Inspectora** (v0.7.28); okno Výroba svoju kópiu (chevron, D-105) stratilo v ŠT-1b
spolu s tabom Kontrola a **v ŠT-1c PR B3 zaniklo celé** — vstupné body sú teda presne dva. Všetky majú **JEDEN zdroj stavu aj JEDEN markup**: zapisuje sa výhradne cez
`Engine.set_edge_check_option` (zrkadlo `toggle_edge_check`), ktorá po zápise rozpošle čerstvý `ui_state` **obom klientom** (`broadcast_edge_check` → `StudioDialog` + `Panel`);
okná preto nikdy nesmú volať `EdgeCheck.set_option` priamo (obišlo by to broadcast a počty inde by zamrzli — stráži test).

**ŠT-1c PR A — fix živej chyby (audit #2):** tým istým broadcastom rozposielajú aj `EdgeCheck.notify_state_changed` (prepnutie dokumentu) a `notify_count_changed` (prepočet po
`draw` alebo zmene výberu). Dovtedy mali **vlastný zoznam okien**, ktorý poznal len (dnes už zaniknutú) Výrobu a Inspector — lišta sekcie Kontrola v Štúdiu preto po prepočte cache
držala staré počty, hoci prepínač aj model už hovorili niečo iné. Nové okno sa odteraz pridáva na JEDINOM mieste (`main.rb`); stráži to `tests/pure/test_st1c_nakup.rb` a
in-SketchUp `run_st1c`. Samotné UI prepínačov kreslí zdieľaný `ui/js/edge_menu.js`, **spúšťač je tvarom per okno** (rohová zóna railu vs. rohová zóna tlačidla v lište sekcie) a
otvorenie na jednom mieste zavrie ostatné cez `Engine.close_edge_menu(source)` — vetvy `:panel` · `:production` · `:studio`.

**Telá akcií (toggle, nastavenie, guardy) žijú v `ProductionCore`** — obe okná sú len tenké obaly nad vlastným `@generation`.

**Sken beží len** pri zapnutí, po `ModelObserver` dirty a po `invalidate!` (katalóg) — prepínač ani zmena výberu ho NESPÚŠŤAJÚ (prepočíta sa `view_payload` = filter + predpočítané
GL polia); `extents` berie všetky tri stavy z celej cache.

**`EdgeSelectionWatch` (D-103 lekcia): reakcia na výber NEVOLÁ `Panel.push_selected` ani `ScaleWatch.request_dedup` a nespúšťa žiadnu operáciu** — len zahodí filter, pošle počty a
invaliduje pohľad. Rozsah = top-level ako `Bom.collect`; prechod modelom `each_part` je **zdieľaný** — číta ho aj `grain_check` (K2), aby „čo je výrobný dielec" žilo na jednom
mieste.

**ŽIVOTNÝ CYKLUS OVERLAYA — VEDOMÁ ZMENA ŠT-1b:** overlay sa vypína **už len pri prepnutí modelu** (`EngineAppObserver`) a keď ho používateľ vypne. Zatvorenie okna zvýraznenie
**NEVYPÍNA** (vedomá zmena ŠT-1b) — trvalým vstupným bodom prepínača je rail Inspectora, takže zatvorenie Štúdia by inak zhaslo zvýraznenie zapnuté úplne inde. Kontrakt „vypneš a
nič v modeli neostane" drží ďalej: stav žije v `%APPDATA%`, v `.skp` neostáva **nikdy nič** a vypnúť sa dá z railu aj zo sekcie Kontrola. Štúdio z rovnakého dôvodu žiadne
`disable!` pri zatvorení **nepridáva** (trvalý vstupný bod je rail).

**Prijatý dôsledok (review #11):** keď používateľ zavrie **všetky** okná pluginu so zapnutým zvýraznením, overlay v modeli ostane kresliť a **v tej chvíli nemá viditeľný vypínač**
— zhasne ho otvorenie Inspectora či Štúdia (a prepnutie modelu). Je to vedomé: alternatíva „zhasni pri zatvorení posledného okna" by zhasínala aj vtedy, keď používateľ zavrie len
jedno z dvoch okien, a stav sa nikdy nezapisuje do `.skp`.

### grain_check.rb

(+ `GrainOverlay`/`GrainModelWatch` v `edge_overlay.rb`) — **K2/D-87: SMER KRESBY v modeli.** Prepínač „Smer kresby" v **lište sekcie Kontrola okna ŠTÚDIO** (do ŠT-1b v okne Výroba
→ tab KONTROLA) nakreslí na každý výrobný dielec rovnobežné čiary v smere kresby dekoru — jeden pohľad na celú zákazku (blenda vs. dvere na prvý pohľad). Je to **POHĽAD, nie
dáta**: `Sketchup::Overlay` NAD modelom — žiadna operácia, žiadny undo krok, nič v .skp; po vypnutí aj po zatvorení okna v modeli neostane nič.

**ZDROJ SMERU je VÝHRADNE snapshot dielca** (`grain_direction`, teda výsledok `CabinetBuilder.effective_grain` z K1) — katalóg sa tu **nikdy nečíta**, takže odpojený dielec aj
stará zákazka sa zobrazia presne tak, ako pôjdu do výroby; `none`/chýbajúca/neznáma hodnota = dielec sa **preskočí** (počíta sa do `skipped`, nekreslí sa nič). Geometriu určujú
**osi deskriptora** cez zdieľané `PartFaces.axes_for_snapshot` — nikdy „tá dlhšia strana" (štvorcové čelo je nerozhodnuteľné); neoveriteľné osi = **nekreslí sa nič** a priznajú sa
cez `unresolved`. Čisté jadro je `segments_mm` (usečky v lokálnych mm) + `line_count`: **3–5 čiar podľa rozmeru NAPRIEČ kresbou** (<200 mm = 3 · <500 = 4 · inak 5), rozostup
rovnomerný, odsadenie od hrán 6 % dĺžky, kreslí sa na **OBE dekorové plochy** s posunom `OUT_MM = 0,6` von (z-fighting; menšie než `HoverEdge::OUT_MM`, takže hover hrany ostáva
navrchu).

**Farba `COLOR = #37474f`** (token `--nx-ink-strong`) je tmavá neutrálna — vedomé rozhodnutie K2: nesmie sa miešať s tromi stavmi olepu (`EdgeCheck::COLORS` červená/oranžová/zelená
— stráži test), fialová v modeli splývala s modrým zvýraznením výberu (lekcia D-105) a teal je rodina `--nx-select` aj stavu „olepené"; slabinou je veľmi tmavý dekor, kde kontrast
klesá.

**Sken beží len** pri zapnutí a po `ModelObserver` dirty (prestavba, Späť/Znova) — prepočet je lazy v `draw`, `view_payload` drží hotové GL pole a `extents` obal kresby.

**Prepínač si pamätá POČÍTAČ** (`%APPDATA%\NOXUN\Engine\grain_check.json`, NIKDY .skp): `toggle` zapíše výsledný stav, `restore!` ho obnoví **pri otvorení okna, ktoré prepínač
zobrazuje — od ŠT-1b je to ŠTÚDIO** (`StudioDialog.show`, ešte PRED prvým `push_state`, inak by lišta hlásila vypnuté a v modeli by sa kreslilo; v ŠT-1c PR B3 zaniklo aj posledné
`restore_grain_check` okna Výroba spolu s oknom).

**Zatvorenie okna kresbu NEVYPÍNA** (vedomá zmena ŠT-1b — rovnaký dôvod ako pri zvýraznení hrán): Štúdio `disable!` nepridáva. Prepnutie dokumentu overlay vypne
(`EngineAppObserver` → `on_model_changed`). Server je jediná autorita čísel — JS (`grainBtnHtml`/`grainCheckText`) len zobrazuje; guardy relayu (`gen` + `model_guid`) sú
**zdieľané** s kontrolou hrán (`edge_check_guard`).

**VSTUPNÉ BODY sú od ŠT-1b prepínač v lište sekcie Kontrola (ŠTÚDIO) a tlačidlo „Kontrola kresby" v raile Inspectora — a majú JEDEN zdroj stavu** (presné zrkadlo ABS kontroly z
UI-B1): prepína sa výhradne cez `Engine.toggle_grain_check` a nový stav rozpošle `Engine.broadcast_grain_check` **obom klientom naraz** (`StudioDialog.push_grain_check` +
`Panel.push_grain_check`; tretím bolo okno Výroba, ktéré zaniklo v ŠT-1c PR B3), takže zapnutie z railu je okamžite vidieť v otvorenom Štúdiu a naopak. Telo prepnutia aj guardy
žijú v `ProductionCore.do_grain_check` — okno je tenký obal nad vlastným `@generation`. Tou istou cestou idú aj **prepočet po prestavbe** (`notify_count_changed`) a **vypnutie pri
prepnutí dokumentu** (`notify_state_changed`) — core nesmie posielať stav len jednému oknu, inak by druhé zamrzlo na starých číslach (stráži test).

Rail si **žiadny vlastný stav nedrží**: pull v `push_init` (`grain_check`), push cez `NX.setGrainCheck`, prisvietenie aj text bubliny počíta čistá funkcia `NXShell.grainRail` z
toho istého `GrainCheck.ui_state`. Klik z railu ide `nx_grain_toggle` → `Panel.handle_grain_toggle` s **prísnym guardom dokumentu** (asynchrónny callback HtmlDialogu by inak zapol
kresbu v cudzom modeli) a hláškou pri SketchUpe bez Overlay API — nikdy ticho mŕtve tlačidlo. Ikona `#i-grain` (dielec so šrafovaním = miniatúra toho, čo overlay kreslí) je
**spoločná pre rail aj Štúdio** (pôvodný `rows-3` bol náhrada, kým vlastný symbol neexistoval). Testy: `tests/pure/test_k2_smer_kresby.rb`, `tests/js/test_k2_smer_kresby.js`,
in-SketchUp sekcia `run_k2`.

### direction_check.rb

(+ `DirectionOverlay`/`DirectionModelWatch` v `edge_overlay.rb`) — **KOV-A2b: SMER OTVÁRANIA v modeli.** Prepínač „Smer otvárania" nakreslí na **prednú plochu každého čela** symbol toho, ako sa
otvára. Od **D-115** je to stolárska konvencia: **dve čiary z ROHOV strany pántov do STREDU protiľahlej (voľnej) hrany** — dvierka `><`, výklop „V", sklop „Λ", zásuvka prerušované X, blenda
**plné X** (jediný plný symbol, lebo sa nehýbe). Je to **POHĽAD, nie
dáta**: `Sketchup::Overlay` NAD modelom — žiadna operácia, žiadny undo krok, nič v .skp; po vypnutí v modeli neostane nič. Vlastný modul (nie ďalší stav K2) zámerne: K2 hovorí o smere **kresby
dekoru**, toto o smere **otvárania** — a obe sa dajú zapnúť naraz nad tým istým čelom.

**ZDROJ JE ULOŽENÝ CONFIG, nikdy geometria:** pre každú top-level inštanciu `cabinet` sa číta `front_items` a `Fronts.direction_slots` (KOV-A1 = **jediná** definícia „kde sa smer pýta"); dielec sa
dohľadá medzi vnorenými `kind: part` podľa `part_key` (tá istá cesta ako `ProductionCore.pids_in_cabinet`). Kreslí sa **per INŠTANCIA** — dve skrinky so zdieľaným `cabinet_id` majú každá svoj config
a každá svoju kresbu. Trojstav A1 platí bez výnimky (**R-39: žiadny default ani heuristika — ani v overlayi**): `left`/`right` → čiary z rohov pántov · `unset` → prerušovaný kruh + „?" · **kľúč chýba (legacy) →
nekreslí sa NIČ**. Krajné krídla 2/3/4-krídlových dvierok sú **ODVODENÉ** (A1 variant a: p1 pánty vľavo, posledné vpravo). Výber symbolu (`dir_symbol`/`type_symbol`/`wing_symbols`) je **zrkadlo**
`frontDirSymbol`/`frontTypeSymbol`/`frontWingSymbols` z `ui/js/core.js` — čo vidno v náhľade karty, to je aj v modeli (stráži test nad spoločnými fixtúrami). **D-115: zásuvkové čelo už symbol MÁ**
(`xdash`, kanonický kľúč `front:F#/panel` z `Fronts.panels_for`) — do „krídel" sa však NERÁTA (`WING_SYMBOLS`), takže počty v raile aj v lište Kontroly ostávajú o dvierkach.

**Geometria:** symbol leží na ploche **MIN osi hrúbky** (tá, na ktorú sa pozerá používateľ) posunutej o `OUT_MM = 0,7` von — viac než `EdgeCheck::OUT_MM` (0,5), aby ho neprekryla plôška olepu, a
menej než `HoverEdge::OUT_MM` (0,9), takže hover hrany ostáva navrchu. Osi určuje zdieľané `PartFaces.axes_for_snapshot` (čelo = `AXES_FRONT`); neoveriteľné osi = **nekreslí sa nič** (D-88). **TVAR má JEDINÝ zdroj** (D-115):
`SHAPES` je tabuľka úsečiek v **jednotkovom štvorci** panelu (u po šírke 0→1 zľava doprava, v po výške 0→1 **zdola nahor**; rohy odsadené o `CORNER_INSET = 0,05`, stredy hrán presne 0,5) plus
príznak `dashed` = jediné pravidlo kresby (**prerušovaná = pohyb, plná = dielec**); `shape_unit` ju vydá, `plan_2d` ju premietne na panel a pre `unknown` (bez úsečiek) padne na `ring_2d`. Tú istú
tabuľku má JS (`frontSymbolShape` v `ui/js/core.js`) a **obe strany sa porovnávajú s fixtúrou `tests/fixtures/front_symbol_shapes.json`** — do D-115 bolo overené len MENO symbolu a kresby sa
naozaj rozišli (Ruby šípka s hrotom, JS holý chevron). Celý tvar žije v čistej vrstve, takže sa dá testovať bez SketchUpu. Prerušované sa kreslí `line_stipple = '-'`; pero sa po kreslení
**vracia do východzieho stavu**, inak by prerušovane kreslili aj prekrytia za nami.

**Farby:** `COLOR = #880e4f` (tmavá malinová) pre vyriešené symboly — nie tri stavy olepu (`EdgeCheck::COLORS`), nie `GrainCheck::COLOR` (#37474f — obe prekrytia môžu byť zapnuté naraz), nie teal
rodina výberu/`HoverEdge`, nie fialová/modrá (v modeli splýva s modrým zvýraznením výberu, lekcia D-105); najbližší sused je smer kresby (vzdialenosť 99 v RGB, viac než už prijatá dvojica
kresba/hover 81). `COLOR_UNSET = #e65100` (token `--nx-warn-fg`) pre kruh a „?" — **ten istý jantár, akým svieti badge „smer?"** v Inspectorovi, takže panel a model hovoria jednou farbou; priznaná
blízkosť k `EdgeCheck::EXTRA` je vedomá (rozhoduje odstup „neurčené" vs „vyriešené" = 140, a stavy olepu sú tenké plôšky NA HRANÁCH, kým „?" je glyf v STREDE čela). Vzájomnú odlišnosť všetkých
farieb prekrytí stráži guard test.

**Sken beží len** pri zapnutí a po `ModelObserver` dirty (prestavba, Späť/Znova) — prepočet je lazy v `draw`, `view_payload` drží tri hotové GL polia (prerušované · plné · „neurčené") plus kotvy
textov a `extents` obal kresby. Skryté čelá (tag `Noxun/Čelá`) sa preskakujú **zdieľanou** bránkou `EdgeCheck.drawable?`.

**Prepínač si pamätá POČÍTAČ** (`%APPDATA%\NOXUN\Engine\direction_check.json`, NIKDY .skp); `restore!` ho obnoví pri `StudioDialog.show` **pred prvým `push_state`**. **VSTUPNÉ BODY sú dva a majú
JEDEN zdroj stavu** (presné zrkadlo K2): tlačidlo `railSmer` v raile Inspectora (`nx_direction_toggle` → `Panel.handle_direction_toggle` s prísnym guardom dokumentu a hláškou pri SketchUpe bez
Overlay API) a prepínač v lište sekcie Kontrola v Štúdiu (`direction_check_toggle` → `ProductionCore.do_direction_check`, identity guard `gen` + `model_guid` **zdieľaný** s kontrolou hrán).
Prepína sa výhradne cez `Engine.toggle_direction_check` a nový stav rozpošle `Engine.broadcast_direction_check` **obom klientom naraz**; tou istou cestou idú aj prepočet po prestavbe
(`notify_count_changed`) a vypnutie pri prepnutí dokumentu (`notify_state_changed` z `EngineAppObserver`) — stráži test. Texty skladá SERVER (`ProductionCore.direction_check_status`); JS
(`NXShell.directionRail`, `directionBtnHtml`/`directionCheckText`) len zobrazuje čísla. Ikona `#i-direction` je **spoločná pre rail aj Štúdio**. Testy: `tests/pure/test_kova2b_smer_overlay.rb`,
`tests/js/test_kova2b_smer_overlay.js`, in-SketchUp sekcia `run_kova2b`.

### hover_edge.rb

(+ `HoverEdgeOverlay` v `edge_overlay.rb`) — **D-89 (a): hrana pod kurzorom.** Hover nad hranou v karte dielca/dosky rozsvieti tú istú hranu priamo v modeli. Je to **POHĽAD, nie
dáta**: `Sketchup::Overlay` NAD modelom — žiadna operácia, žiadny zápis, žiadny undo krok, nič v .skp (lekcia D-103, vzor D-104/D-105).

**Nič sa nehľadá:** zvýrazňuje sa hrana toho dielca, ktorý je práve VYBRATÝ (karta je jeho zrkadlo), takže žiadny scan modelu — jedna plôška, nulová cena. Svetová transformácia ide
cez `model.edit_transform * ent.transformation` (vnorený dielec po dvojkliku do skrinky). Geometria hrany používa **zdieľaný kontrakt `PartFaces`** (`axes_for_snapshot` +
`face_rect_mm`) — ten istý, akým kreslí D-104; neoveriteľné osi = **nekreslí sa nič** („radšej žiadna farba než farba na zlej hrane"). `OUT_MM = 0,9` je **väčšie** než
`EdgeCheck::OUT_MM` (0,5), aby bol hover vidno aj nad zapnutou kontrolou olepu; farba `COLOR` je **výber** (`--nx-select`), zámerne NIE `EdgeCheck::COLORS` (tie hovoria o stave
olepu a nesmú sa miešať).

Životný cyklus: `show(model, code)` registruje overlay pri prvom rozsvietení, `hide` len zhasne (overlay ostáva — add/remove pri každom pohybe myšou je zbytočná práca), `release`
odpojí (zatvorenie panela `set_on_closed`, prepnutie dokumentu `Panel.on_model_switched`). Callback `nx_hover_edge` (`ui/panel/actions_parts.rb`) má **prísny guard dokumentu** ako
`nx_edge_toggle` a **nepíše status** (hover je pohyb myšou, nie akcia). JS strana (`part_card.js`) posiela **len ZMENU** kódu hrany — inak by každý `mouseover` bežal cez most do
Ruby.

### edge_overlay.rb

Súbor, v ktorom žijú triedy prekrytí (`Sketchup::Overlay`) — celý je pod guardom dostupnosti API (SU 2023+). Bývajú v ňom overlay kontroly olepu (kontrakt a pasce sú v odseku
`edge_check.rb`), `GrainOverlay`/`GrainModelWatch` (odsek `grain_check.rb`), `DirectionOverlay`/`DirectionModelWatch` (odsek `direction_check.rb`) a `HoverEdgeOverlay` (odsek
`hover_edge.rb`). Spoločné pre všetky: **žiadna operácia, žiadny zápis, žiadny undo krok, nič v .skp**.

## Observery

### scale_observer.rb

(ScaleWatch) — absorpcia scale pre kind {cabinet, board}: doska mapuje lokálne osi X→length/Y→width, Z sa zahadzuje (hrúbku riadi materiál); shear guard; scale maska
`scaletool`=120 aj na definícii = čisté osi. Mapovanie je **lokálne**, takže platí aj pre otočenú dosku (UI-C1c) — používateľov scale v globálnom Z stojacej dosky skončí v jej
ŠÍRKE.

**BARIÉRA PRED MUTÁCIOU NÁSTROJA — `flush_pending!(model)` (NÁSTROJE-1, v0.9.24).** `guard` zabráni len NOVÝM udalostiam; už naplnené fronty (`@dirty`, `@added`, `@requested`,
`@prune_models`) a bežiaci debounce timer zostávajú — a keď timer dobehne PO operácii nástroja, jeho **transparentná** reakcia (dedup kópií, presun ghost zón) sa prilepí na krok
používateľa, ktorý s ňou nemá nič spoločné. Každý nástroj preto pred polohovou mutáciou NOXUN objektu počká, kým je observer v **POKOJI** = žiadny naplánovaný timer **a** prázdne
fronty **VŠETKÝCH** dokumentov (multi-model: pokoj sa nesmie vyhlásiť podľa `@last_model`). Je to **bariéra, nie jedno spracovanie**: `process_dirty` môže pri čerstvej kópii nájsť
staršiu duplicitu a naplánovať follow-up — nový timer s prázdnymi frontami by po operácii nástroja spustil transparentný dedup nad `@last_model`. Preto follow-up od tejto dávky
zaraďuje **KONKRÉTNY `mdl` do `@requested` PRED `schedule`** (predtým volal holý `schedule`, teda plánoval iba čas). Každá iterácia najprv timer **zastaví** (`@timer` na `nil`)
a zvýši generáciu, takže ani prežívší callback už nič nespustí; strop je `FLUSH_MAX_ITERATIONS` (5) → vráti `false` a **nástroj operáciu odmietne**, pričom fronty ostávajú
nedotknuté (bariéra do nich sama nikdy nesiaha — vyprázdňuje ich výhradne `process_dirty`). Headless dôkazy: `tests/pure/test_nastroje1_observer.rb`; in-SU `run_tools1`
(stará duplicita + čerstvá kópia) a `run_tools1_async` (nástroj spustený DO debounce okna po rotácii aj po natívnom Move).

**Stabilná transformácia** (`@stable_transforms`, z nej `reject_scale` obnovuje polohu) sa aktualizuje po každej úspešnej absorpcii, presune, **po úspešnom commite orientačnej
zmeny** (`Panel.handle_set_board_orientation` volá `remember_transform`) **aj po úspešnej mutácii nástroja** (`Tools.mutate` — pod guardom ju observer nezachytí, takže bez toho by
neskôr odmietnutá šikmá mierka obnovila polohu spred príkazu) — bez toho by najbližší odmietnutý scale vrátil dosku do polohy PRED otočením, kým config už nesie novú
orientáciu. **RIGIDITA SA OD v0.9.24 VYNUCUJE PRIAMO NA HRANICI CACHE:** `remember_transform` uloží len maticu, ktorá prejde `CabinetBuilder.rigid_matrix?`, a `attach_one` sa už
nespolieha na podmienku `unless scaled?`. Tá kontrolovala **iba dĺžky osí**, takže **šmyková** matica (jednotkové, ale nekolmé osi — nenulový skalárny súčin) do cache prešla
a `reject_scale` by ňou korpus „obnovil" do stavu, ktorému nezodpovedá žiadna platná geometria (audit 2/3 FIX 2). Kľúč je `[model.object_id, entityID]` — **`guid` sa ako kľúč
použiť NEDÁ** (review #261, P1): SketchUp ho mení **pri každom uložení** dokumentu (rovnaký dôvod, prečo
kľúčom názvu zákazky je CESTA — `tests/pure/test_st1a_studio.rb`), takže by Ctrl+S naraz zneplatnil všetky zapamätané polohy a upratovanie by staré záznamy už ani nenašlo.
Cache má **dve čistiace cesty** (R-04, v0.8.17): `forget_dead_transforms` na **erase tiku** (jeden prechod definíciami daného dokumentu; kľúče entít, ktoré už nežijú, padnú — a
keď cache pre ten dokument nemá kľúč, model sa vôbec nečíta) a `forget_detached_models` pri **zmene dokumentu**, ktorá beží **výhradne na Windows/SDI** (`Sketchup.platform`):
tam File>New/Open nahradí jediný dokument procesu, takže ide preč **celá** cache (záznamy nového dokumentu ešte neexistujú — naplní ich `attach_all` hneď za tým). Rozhoduje sa
podľa **`guid` ako detektora zmeny** (nie ako kľúča): `model_switched` sa pri ukladaní nespúšťa, takže iný guid v tejto ceste znamená naozaj iný dokument — a súčasne to
zneškodňuje prípad, keď by sa `object_id` zatvoreného dokumentu recykloval na nový. Guid aktívneho dokumentu **seeduje `install`** a neznáme `prev` sa **nechápe ako „nič nerob"**,
ale ako dôvod vyčistiť — inak by prvé File>New/Open po štarte pluginu nechalo v cache celý práve zaniknutý dokument.
Na macOS sa cache dokumentu v pozadí **nečistí zámerne** — ten dokument žije ďalej a môže mať rozbehnutý debounce, takže zmazanie záznamu by odmietnutému scale vzalo presnú
polohu (`clean_transform` pri scale okolo pivotu vráti posunutý origin).

**Multi-model kľúčovanie udalostí** (R-01, v0.8.17): `@dirty` aj `@added` sú kľúčované `[model.object_id, entityID]` (`event_key`) — holé `entityID` je lokálne pre dokument, takže
dve inštancie z dvoch dokumentov v jednom debounce okne (macOS) si udalosť prepísali a jedna sa stratila. Tu `object_id` **stačí**, lebo hodnotou je živá entita, ktorá svoj model
drží po celý debounce. Požiadavky o prune sú **množina dokumentov** `@prune_models` (vzor `@requested`) namiesto pôvodných jediných slotov `@need_prune` + `@erase_model`; ciele
počíta `prune_targets` a **každý cieľ má vlastný `begin/rescue`** — fronty sú v tom momente už vyprázdnené, takže výnimka nad jedným (napr. zatváraným) dokumentom by inak vzala
aj všetky ostatné požiadavky toho tiku. Erase, ktorého dokument sa **nedal zistiť** (entita je pri `onEraseEntity` už neplatná), ide do množiny ako **sentinel `nil`** a v tiku sa
rozhodne fallbackom `@last_model → touched_models.first → Sketchup.active_model` — ten sa **pridá** k známym cieľom, nie až keď je množina prázdna. **Priznaný zvyšok:** dva
*neznáme* erasy z dvoch dokumentov splynú aj naďalej; spoľahlivý pôvod by vyžadoval per-model observer držiaci silnú referenciu na každý otvorený dokument (register **R-36**).

`CH6` maže **mimo `ScaleWatch.guard`**, teda skutočnou erase cestou: v guarde `notify_erase` okamžite vracia, takže mazanie cez testovací
`cleanup` by správanie cache „dokázalo" aj vtedy, keby ju nikto neupratoval — scenár preto vloží vlastnú operáciu s `erase!`, počká na debounce a kontroluje **konkrétny
kľúč**, nie len počet; a hneď za tým **Späť**, ktoré musí vrátiť skrinku AJ jej záznam (upratovanie nesmie byť jednosmerné).
`EngineAppObserver` notifikuje dialógy viazané na model (File>New/Open/Activate) a **ako prvé** pustí záznamy zaniknutého dokumentu (Windows) — až potom `attach_all`, ktorý cache
pre nový dokument rovno naplní.

**Charakterizované sadou `CHAR`** (`tests/sketchup/su_runner.rb`, `run_char` — dávka 1b-2, brána H bloku 1b; zapisuje DNEŠNÉ správanie, aby mal hardening bloku 1d a GHOST Tool
vrstva pevnú pôdu): absorpcia scale je **jeden** undo krok a nepridáva vlastný (`CH3`, `CH5`); dedup kópie aj `*N` násobenia sa lepí na paste krok, takže jedno Undo vráti celú
dávku (`CH1`, `CH2`); **oneskorený tik po Undo nepridá krok Späť — a meria sa to sondou undo stacku** (pomenovaná operácia so známym modelovým atribútom, položená pred meraný
úsek; keď ju ďalšie Späť odstráni, medzitým nikto nič nekomitol). Zhodný zoznam `cabinet_id` na tento dôkaz NESTAČÍ: netransparentný prune/dedup tik commitne operáciu bez zmeny
identít (`CH1`, `CH4c`); aktivácia **toho istého** dokumentu prekrytia NEzhasína (guard `same_model?`), kým udalosť o dokumente s iným `guid` ich zhasnúť MUSÍ (`CH6`); **od 1b-3 (brána
G) je `ScaleWatch` — spolu s `Panel.push_selected` → `request_dedup` — JEDINÁ cesta, ktorá dedup vykonáva: čítacie cesty okien identitu neopravujú, len ju priznajú v Kontrole
(`CH7`, guard `tests/pure/test_1b3_citanie.rb`).** **Padnutý
`CHAR` test neznamená „oprav test", ale „správanie sa zmenilo — povedz prečo".** Dve vetvy sa na Windows spustiť nedajú a sú zapísané ako MANUÁLNE scenáre priamo v INFO riadkoch
behu: **Znova (Ctrl+Y)** po scale (Ruby API nemá na Windows spoľahlivú redo akciu — PLAN blok 3) a **dva otvorené dokumenty naraz** (macOS; Windows drží jeden dokument na proces —
guardy `event_key`, `notify_erase`/`prune_targets` a `refresh_panel` v `scale_observer.rb`, ich dátovú štruktúru `CH6` overuje aspoň priamo: množina `@requested` aj množina
`@prune_models` vrátane sentinelu).
