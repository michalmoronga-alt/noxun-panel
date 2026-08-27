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

**K1/D-108 smer dekoru dielca:** `effective_grain(sheet, override)` je JEDINÁ autorita efektívneho smeru (`override → materiál`) a `resolve_part` ho **materializuje RAZ** do
snapshotu dielca.

**Rotácia sa tu NEROBÍ** — `pd[:prod]` aj rozmery na entite ostávajú GEOMETRICKÉ (osi deskriptora, `part_faces`/D-88/D-104/hover a kovanie na nich stoja); výmenu dĺžka↔šírka +
dvojíc hrán robí až VEPO a zrkadlovo `validation.fits_on_sheet?`, a nikde inde (dvojitý swap = dielec objednaný v pôvodnej orientácii). Povolené hodnoty overridu drží konštanta
`GRAIN_OVERRIDES` (`length`/`width` — „bez smeru" je vlastnosť materiálu, nie voľba na dielci); `norm_overrides` ju používa ako **whitelist**, takže neznáma hodnota (aj z novšej
verzie pluginu) do configu neprejde.

**Materiál bez smeru override IGNORUJE, ale NEMAŽE** — rozhodnutie používateľa prežije dočasný UNI/jednofarebný materiál a s dekorom ožije. Chýbajúci kľúč = dedenie, takže staré
modely sú platné a ich otvorenie nezapisuje nič. Ďalej: regenerate; vizuál nôh **a úchytkových profilov (D-90)** ako **proxy** (kind hardware, production_class none, manufactured
false — zdroj pravdy súpisu je VÝHRADNE `config.hardware[]` korpusu). Profil: definícia per (profil, dĺžka) `NOXUN_PROFILE_<ID>_L<dĺžka>` s recykláciou podľa mena + odtlačok
`PROFILE_GEOM_REV` (zmena obrysu prekreslí staré definície), kotva = zadná rovina čela (Y 0) a vrch PÔVODNÉHO čela.

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
`edge_check.rb`), `GrainOverlay`/`GrainModelWatch` (odsek `grain_check.rb`) a `HoverEdgeOverlay` (odsek `hover_edge.rb`). Spoločné pre všetky tri: **žiadna operácia, žiadny zápis,
žiadny undo krok, nič v .skp**.

## Observery

### scale_observer.rb

(ScaleWatch) — absorpcia scale pre kind {cabinet, board}: doska mapuje lokálne osi X→length/Y→width, Z sa zahadzuje (hrúbku riadi materiál); shear guard; scale maska
`scaletool`=120 aj na definícii = čisté osi. Mapovanie je **lokálne**, takže platí aj pre otočenú dosku (UI-C1c) — používateľov scale v globálnom Z stojacej dosky skončí v jej
ŠÍRKE.

**Stabilná transformácia** (`@stable_transforms`, z nej `reject_scale` obnovuje polohu) sa aktualizuje po každej úspešnej absorpcii, presune **aj po úspešnom commite orientačnej
zmeny** (`Panel.handle_set_board_orientation` volá `remember_transform`) — bez toho by najbližší odmietnutý scale vrátil dosku do polohy PRED otočením, kým config už nesie novú
orientáciu. Kľúč je `[model.object_id, entityID]` a **nikto z cache nemaže** — záznamy zmazaných entít aj starých dokumentov v nej ostávajú (charakterizované, nie schválené: fixuje
to `CH6`, kandidát do registra 1c). `CH6` maže **mimo `ScaleWatch.guard`**, teda skutočnou erase cestou: v guarde `notify_erase` okamžite vracia, takže mazanie cez testovací
`cleanup` by prežitie záznamu „dokázalo" aj vtedy, keby cache upratoval erase observer — scenár preto vloží vlastnú operáciu s `erase!`, počká na debounce a kontroluje **konkrétny
kľúč**, nie len počet. `EngineAppObserver` notifikuje dialógy viazané na model (File>New/Open/Activate).

**Charakterizované sadou `CHAR`** (`tests/sketchup/su_runner.rb`, `run_char` — dávka 1b-2, brána H bloku 1b; zapisuje DNEŠNÉ správanie, aby mal hardening bloku 1d a GHOST Tool
vrstva pevnú pôdu): absorpcia scale je **jeden** undo krok a nepridáva vlastný (`CH3`, `CH5`); dedup kópie aj `*N` násobenia sa lepí na paste krok, takže jedno Undo vráti celú
dávku (`CH1`, `CH2`); **oneskorený tik po Undo nepridá krok Späť — a meria sa to sondou undo stacku** (pomenovaná operácia so známym modelovým atribútom, položená pred meraný
úsek; keď ju ďalšie Späť odstráni, medzitým nikto nič nekomitol). Zhodný zoznam `cabinet_id` na tento dôkaz NESTAČÍ: netransparentný prune/dedup tik commitne operáciu bez zmeny
identít (`CH1`, `CH4c`); aktivácia **toho istého** dokumentu prekrytia NEzhasína (guard `same_model?`), kým udalosť o dokumente s iným `guid` ich zhasnúť MUSÍ (`CH6`); **od 1b-3 (brána
G) je `ScaleWatch` — spolu s `Panel.push_selected` → `request_dedup` — JEDINÁ cesta, ktorá dedup vykonáva: čítacie cesty okien identitu neopravujú, len ju priznajú v Kontrole
(`CH7`, guard `tests/pure/test_1b3_citanie.rb`).** **Padnutý
`CHAR` test neznamená „oprav test", ale „správanie sa zmenilo — povedz prečo".** Dve vetvy sa na Windows spustiť nedajú a sú zapísané ako MANUÁLNE scenáre priamo v INFO riadkoch
behu: **Znova (Ctrl+Y)** po scale (Ruby API nemá na Windows spoľahlivú redo akciu — PLAN blok 3) a **dva otvorené dokumenty naraz** (macOS; Windows drží jeden dokument na proces —
guardy `scale_observer.rb:149-150, 194-200, 382-383`, ich dátovú štruktúru `CH6` overuje aspoň priamo).
