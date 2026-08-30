# AUDIT REGISTER — zliaty výstup bloku 1c (29. 8. 2026)

> **Autorita zásobníka pre blok 1d.** Vznikol zliatím a dedupom troch nezávislých auditov nad `main` v0.8.13 (`dc2d53f`):
> **[E]** externý Codex ([zdroje/AUDIT_2026-08_externy_codex.md](zdroje/AUDIT_2026-08_externy_codex.md), spúšťal Michal) ·
> **[F]** Fable prechod (osi 1/3/4 — observery, production_core, identita; interné overenie s dôkazmi) ·
> **[S]** slepý subagent (osi 2/5/6 — sety, perzistencia, UI vzory) — plus kandidáti zo sweepu
> ([zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md), značky A/B/C) a 4 protinázory Codex review #250
> (dispozície v threadoch PR #250). Podklad a pravidlá auditu: [zdroje/AUDIT_2026-08_podklad.md](zdroje/AUDIT_2026-08_podklad.md).
>
> **Údržba:** položky sa vybavujú dávkami bloku 1d ([PLAN.md](PLAN.md)) — vyriešená položka dostane riadok „✅ dávka/PR"
> a pri uzávere bloku sa presunie do sekcie „Vyriešené" na konci. Pravidlo 1d: rieši sa LEN výrobné riziko alebo
> ponechaný V1 rozsah; dávka bez menovanej funkcie/dlhu sa nerobí. Čísla riadkov = stav k `dc2d53f`
> (kód sa odvtedy hýbe — pri práci sa orientuj podľa MIEN metód; nové položky citujú mená, nie čísla).

## P0 — eskalované ako okamžité hotfix dávky · **✅ OBA HOTOVÉ dávkou P0-HF (PR #252, v0.8.14, 29.8.)**

- **P0-1 · Exporty sa zapíšu pred cenovou bránou** (rozpočet/ponuka XLSX so známou chybnou cenou) — [E:P0-HF-01].
  **Korekcia z review #250:** brána je dvojvrstvová — TVRDÝ blok len pre vždy-chybné stavy (záporná zostava, nesúlad súm),
  CHÝBAJÚCA CENA = explicitné potvrdenie („Exportovať aj tak — N riadkov bez ceny"), lebo STANDARD §11.3 drží rozpracovaný
  rozpočet exportovateľný. → *✅ PR #252: tvrdá vetva (záporná zostava, nesúlad súm) + potvrdzovaná vetva
  (riadky bez ceny — druhý klik viazaný na počet, ktorý používateľ videl).*
- **P0-2 · Export s duplicitnou identitou dobehne s podpočítaným kovaním** (CSV kovania/rozpočet/ponuka; `per: owner`
  dedup na `owner_id`) — [E:P0-HF-02 ≡ A3]; prevracia vedomý kompromis 1b-3 (#240). Tvrdý blok; predikát rozlišuje
  skrinku od dosky; VEPO sa neblokuje. → *✅ PR #252 (`dup_partition` — blokuje len ID, ktorých sety majú
  reálne `per: 'owner'` člena). Zvyšná presnosť predikátu = **R-34** (✅ #262, v0.8.18 — blokuje až REÁLNE zliatie).*

## Os GHOST — observery · undo · vkladanie (blok 1d PRED blokom GHOST)

### R-01 · P1 · core · `core/scale_observer.rb:101-134, 111-118, 531-534`
Multi-model stav observera (macOS vetva): `@dirty`/`@added` kľúčované holým `entityID` → kolízia dvoch dokumentov
v debounce okne stráca udalosť; `@need_prune` + `@erase_model` + `@last_model` sú jediné sloty → dva erasy v dvoch
dokumentoch sa zlejú; `onEraseEntity` nesie `nil` model (entita je pri erase už invalid) a fallback mieri do
nesprávneho dokumentu. Windows vetva nedotknutá. [E:R-01 + F-01 potvrdené dôkazmi + Codex #250]
**Návrh:** kľúč `[model.object_id, entityID]` (vzor `transform_key` UŽ v súbore) + prune ako množina modelov;
spracovanie po modeloch; 2 model-stub testy + macOS smoke. Spolu s R-04. **Odhad: M.**
**✅ dávkou 1d/R-01+R-04 (PR #261, v0.8.17)** — `@dirty`/`@added` kľúčuje `event_key` = `[model.object_id, entityID]`;
`@need_prune` + `@erase_model` nahradila **množina `@prune_models`** a ciele počíta `prune_targets`, každý s vlastným
`begin/rescue`. Codex audit návrhu vrátil **3 BLOCKERY** — všetky zapracované: (1) pôvodný nápad získať dokument
v `onEraseEntity` cez `Sketchup.active_model` je **zamietnutý** (erase chodí aj z undo/zatvárania, kde je aktívny už iný
dokument); (2) kombinácia „známy dokument + neznámy erase" by sentinel **stratila**, keby sa fallback púšťal až pri
prázdnej množine — pridáva sa vždy; (3) mazanie cache pri prepnutí dokumentu by na macOS vzalo polohu dokumentu
v pozadí — beží preto len na Windows/SDI. **Priznaný zvyšok = R-36.**

### R-02 · P1 (macOS) / P3 (Windows) · ui · `ui/panel/actions_cabinet.rb` · `actions_hardware.rb` · `actions_board.rb` · `ui/js/actions.js:385-411`
Zapisovacie handlery bez guardu identity dokumentu — payload nenesie `model_guid`, server berie
`Sketchup.active_model`; oneskorený callback po prepnutí dokumentu zapíše do nesprávneho modelu. Dotknutých je
14 handlerov (cabinet 6 · hardware 2 · board 6); insert je najkritickejší (GHOST). Kontrast: parts, materials,
templates, zones aj selection guard MAJÚ. [E:R-02 + F-02 ROZŠÍRENÉ]
**Návrh:** zdieľaný guard (vzor tagov/`part_target_error`) + `model_guid` do payloadov — jedna mechanická dávka. **S/M.**
**✅ dávkou 1d/R-02 (PR #264, v0.8.19)** — jeden zdieľaný guard `Panel.foreign_document?` (v `ui/panel/sync.rb` pri
`model_guid`) a jedno klientske miesto `nxDocPayload` (v `ui/js/shell.js`, obdoba `nxZonePayload`). Guard prešiel do
**18** handlerov: cabinet 6 · hardware 2 · board 6 (z toho 5 cez spoločnú bránu `guarded_board` — nie 5 kópií) · a po
**Codex review kola 1 (2× P1)** aj materiál skrinky + tri cesty karty dielca (materiál, hrana, olep všetkých 4), ktoré
register zaradil medzi „guard MAJÚ" nesprávne — mali len echo `cabinet_id`. Druhý P1 kola 1: `nxDocPayload` čítal
mutovateľný globál až pri ODOSLANÍ, takže **debounced** edity (auto-apply, polia dosky; 400 ms) by sa po prepnutí
dokumentu opečiatkovali novým guidom a guard by ich pustil — identita sa preto **zachytáva pri naplánovaní**.
**Kolo 2 (4× P1, jedna rodina)** doplnilo systémovú odpoveď: `nxSetModelGuid` je jediný detektor zmeny dokumentu a pri
skutočnej zmene spúšťa `nxDropDocState()` — zahodí všetok rozpracovaný stav (pending buffery, inline editor názvu,
modaly); echo push tej istej identity nezahodí nič. Druhá obrana = vlastná zachytená identita v každom bufferi
(`applyPendingGuid` aj pre okamžitý flush · `boardPending` kľúčovaný dvojicou dokument+doska · `renameGuid` ·
`boardTarget`/`partTarget` pre modal ABS). **Kolo 3 (1× P1)** doriešilo PORADIE: identita dokumentu je prvý príkaz
`loadSelected` aj `loadBoard` a `sameDoc` je priamo v podmienke `keepGaps` — inak sa stavové rozhodnutie pushu spraví
skôr, než centrálne zahodenie vôbec zbehne. Priznaný zvyšok: `Model#guid` sa mení pri KAŽDOM uložení — vlastnosť
celého vzoru (zóny, tagy, Štúdio ju majú tiež), nie tejto dávky. Dávka išla na **4 kolá review** — vedomá odchýlka
od pravidla 3 kôl (konvergujúce nálezy jedného mechanizmu; precedens UI-B1), zdôvodnenie v KRONIKE.
Porovnanie je **prísne** (vzor `handle_tag_visible` / `zone_ctx`): prázdny guid = okno bez dobehnutého `NX.init`
a to nesmie zapisovať nikam. Nezhoda je **hláška**, nie tiché zahodenie — a to aj v auto-apply, kde sa echo výberu
ďalej zahadzuje ticho (prepnutie dokumentu je zriedkavé, presun výberu bežný). Poradie je súčasť opravy: dokument
sa overuje PRED echom `cabinet_id`/`board_id`, lebo `CAB-001` je v každej zákazke. In-SU runner posiela ten istý
tvar payloadu (helper `pg(model, hash)`), takže sada testuje reálnu cestu, nie výnimku.
**✅ priznaný zvyšok dávkou 1d/R-02b (PR #267, v0.8.21)** — hodnota `model_guid` už nie je `Model#guid` (menil sa
pri KAŽDOM uložení → Ctrl+S do 400 ms po úprave poľa vyzeral ako prepnutie dokumentu a edit sa zahodil), ale token
nového `core/doc_key.rb` viazaný na OBJEKT modelu: New/Open = nová identita, uloženie/prvé uloženie/Save As ju
NEMENIA. Nič sa nezapisuje do modelu/.skp; JS aj tvar payloadov nezmenené. Codex audit návrhu: 3 BLOCKERy
(fail-closed obojsmerne · žiadne vytláčanie živých dokumentov z registry · žiadna rotácia identity počas života
okna — preto Save As identitu drží) + 2 FIXy (headless load, migrácia priamych `model.guid` miest v runneri
a sadách). Detail v `docs/architecture/model-a-identita.md` (### doc_key.rb) a KRONIKE.

### R-03 · P1 · core · `core/cabinet_builder.rb:107-138` + `ui/panel/actions_cabinet.rb:286-324`
`build` zlieva normalize → ID → `next_x` → operáciu → geometriu; `transform:` má len `rebuild`. Tool nemá čo
bezpečne držať pred klikom (žiadny čistý pripravený objekt) ani ako položiť skrinku na finálny transform.
[E:R-03 + F-03 potvrdené]
**Návrh:** šev `prepare_insert` (čisté preflighty, nemenný snapshot, bez ID/entít/undo) + `build(..., transform:)`
/ `commit_insert`; hardware freeze ostáva v commit operácii. **Odhad: L.**
**✅ dávkou 1d/R-03 (PR #265, v0.8.20)** — `prepare_insert` vydá **zmrazený `InsertPlan`** (rekurzívny freeze vrátane vnorených hashov, polí aj stringov — a **až po hlbokej kópii**,
lebo `enum_val` vracia pri Stringu ten istý objekt ako vstup a priamy freeze by zmrazil `params` volajúceho); plán si drží **referenciu na `Sketchup::Model`**, nie `guid` (ten sa mení
pri každom uložení — lekcia #261/#264). `commit_insert` má **záväzné poradie**: guard dokumentu → validácia RIGIDNÉHO transformu → `ensure_root_context` **s kontrolou postcondition**
(helper po 20 iteráciách ticho vracia nil) → ID a `next_x` → operácia; **scale-lock ostal VNÚTRI `guarded`** bloku (mimo neho by zápis DC atribútov cez `onElementModified` založil
oneskorený dirty tik). Validátor `rigid_matrix?` je čistá funkcia nad 16 číslami z `to_a`; kontrola prvku `[15]` chytá **nekanonickú/legacy maticu**, ktorá nesie mierku tam (moderný SketchUp `[15]` drží
kanonický a `scaling(2)` padne už na jednotkovosti osí). `Geom::Transformation` je **mutovateľná** (`set!`), preto sa hneď po validácii robí **snapshot** z tých istých overených
čísel a ďalej sa pracuje len s ním — inak by sprievodný blok mohol transform po validácii prepísať na mierku a korpus by vznikol zväčšený pod `guarded` guardom.
Do stavby ide **pracovná nezmrazená kópia** plánu — `resolve_part` upratuje sticky `edge_warnings` in-place. `actions_cabinet.rb` sa nedotkla, správanie volajúcich je nezmenené
(vrátane volania `build(model, type:, width:)`, ktoré Ruby prevádza na pozičný hash — signatúra ho drží cez `params = nil` + `**kw`);
`bounds_mm` plán zámerne nenesie (uzavrie ho GHOST dávka). **Tvrdý blocker GHOST tým padol.**
*(30.8.2026: **GHOST na ňom naozaj naštartoval** — implementačná dávka v0.8.21 postavila `core/ghost_tool.rb` priamo nad týmto švom; kotvy a obálku si uzavrela sama
v `GhostTool::Calc` proti configu plánu, `bounds_mm` v pláne teda nepribudlo. Detail: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **GHOST VKLADANIE**.)*

### R-04 · P3 · core · `core/scale_observer.rb:500-513`
`@stable_transforms` bez delete cesty — rastie cez erase aj zánik dokumentov (in-SU test rast charakterizuje).
[E:R-13 + F-04 + C1] **Návrh:** prune pri erase/model detach; otočiť charakterizačný test. Spolu s R-01. **S.**
**✅ dávkou 1d/R-01+R-04 (PR #261, v0.8.17)** — dve cesty: `forget_dead_transforms` na erase tiku (jeden prechod
definíciami; nič nerobí, keď cache pre ten dokument kľúč nemá) a `forget_detached_models` pri zmene dokumentu
**len na Windows/SDI**. Kľúčom ostáva `object_id`: Codex audit navrhoval `guid` (kvôli recyklácii `object_id` po GC),
ale **GH review #261 to zachytilo ako P1** — SketchUp mení `Model#guid` pri KAŽDOM uložení (rovnaký dôvod, prečo je
kľúčom názvu zákazky cesta), takže by Ctrl+S naraz zneplatnil všetky zapamätané polohy. `guid` sa preto používa len
ako **detektor zmeny dokumentu** v `forget_detached_models` (tá cesta pri ukladaní nebeží) — a tým je ošetrená aj
recyklácia `object_id`. `CH6` je otočený na čistenie **a doplnený o Späť** — po vrátení zmazania musí byť záznam naspäť.

*Poznámka pre GHOST zadanie: po R-01–R-03 ostávajú produktové rozhodnutia z konceptu 09A (Tab vs. Alt/Option,
počiatočný Z režim, Orbit suspend/resume, onCancel, getExtents) — idú do task package 1e, nie do registra.*

## Os KOVANIE — dátový model setov (blok 1d PRED blokom KOVANIE)

### R-05 · P1 · core · `core/hardware_sets.rb:1042-1117, 1188-1220` + `core/validation.rb:585-601`
Pomer „1 ks na N nôh" (D-109) sa do schémy nezmestí: `expand` nemá agregačnú fázu (člen sa materializuje per
položka, pomer sa z jednej položky vyčísliť nedá), rozsah zaokrúhľovania nie je nikde definovaný a BUDÚCE zaokrúhlenie
(dnes v `expand` žiadne nie je — hrozba je prospektívna) by rozbilo invariant `Σ sources.quantity ==
row.quantity`, na ktorom BUDE stáť rozklik D-94 (invariant sa dnes nikde nekontroluje; ORANGE na
`validation.rb:~624` kontroluje chýbajúce kódy, nie súčty — spresnenie GLM review 30.8.). `explain` (panel) by ukázal číslo, ktoré v nákupe nevznikne. [E:R-04 + S-01 + S-02 + S-04]
**Návrh:** rozdeliť `expand` na zbernú (emisné deskriptory + akumulácia bázy) a materializačnú fázu bez zmeny
podpisu; pomerový zdroj vlastný tvar (`basis_quantity` + `ratio`), invariant priznať „len unit/owner"; `explain`
pri pomere číslo NEUVÁDZA („1 ks na 4 nohy — počet určí súpis"). Žiadne desatinné qty.
**POZOR (review #251 kolo 2): rozsah zaokrúhľovania (per zákazka vs per skrinka) je pri viacerých skrinkách
materiálne pozorovateľné rozhodnutie, ktoré znenie D-109 necháva OTVORENÉ — register ho NEPREDROZHODUJE.
Rozhodne USER-debata o setoch (agenda KOVANIE); do zadania D-109 vstúpi až jej výsledok.** **Odhad: M.**

### R-06 · P1 · core · `core/hardware_sets.rb:1196-1210` + `hardware_rules.rb:20-22, 520-530` + `hardware_catalog_dialog.rb:432`
Dĺžkové kovanie sa dá namapovať na set a nacení sa ako KUSY: `cut_length_mm` sa v hardware_sets NIKDY nečíta,
subtotal je `price × quantity`; editor ponúka aj typ `handle` a katalóg pozná MJ „m". Drží to len seed (handle
nemapovaný) — jedno uloženie setu = aktívna cenová chyba. [S-05]
**Návrh:** brána HNEĎ (ORANGE `length_unsupported` pri `cut_length_mm` + kusový set; **S**) · plný `per: 'length'`
(Σ cut_length_mm, MJ m) v tej istej dávke ako R-05 — rovnaká agregačná fáza (**M**). Kým nie je jedno z toho,
`handle` sa nesmie mapovať.
**✅ brána dávkou 1d/R-06a (PR #256, v0.8.15)** — `expand` aj `explain` položku s `cut_length_mm` odklonia do ORANGE
`length_unsupported` (rozmer v texte), rozpočet ani CP ju nenacenia; editor typ `handle` NEzakazuje (kusová úchytka je
legitímna, a brána v editore by nedosiahla na sety v staršom .skp). **Plný `per: 'length'` ostáva s R-05** a smie bránu
stlmiť až tá istá dávka, ktorá prinesie dĺžkovú materializáciu.

### R-07 · P1 · core · `core/hardware_sets.rb:96-97, 241-255, 314-330, 536-537, 611-629, 1388-1408, 1529-1535`
Globálna knižnica setov: `load` `std` NEČÍTA, `write` stampuje vždy `std: 1` aj pri obsahu vyžadujúcom 2 (marker
klame); `normalize_members` člena s neznámym tvarom TICHO zahodí a `project_state_status` porovnáva len počet
SETOV a mapovaní (členov nie) → starší plugin knižnicu prečíta, oreže a prvý zápis stratu zvecní. Snapshot na modeli má oboje správne.
[E:R-05 + S-08 + S-03]
**Návrh:** prevziať `HardwareCatalog.assess!` vzor 1:1 (novší std = read-only s hláškou; std z obsahu cez
`snapshot_std`); + kontrola počtu ČLENOV v `project_state_status` (2 riadky). D-109 pridá `STD_RATIO` do
`STD_SUPPORTED` + obsahovú detekciu. Round-trip a downgrade-gate testy. **Odhad: M.**
**✅ dávkou 1d/R-07 (PR #266, v0.8.21)** — knižnica má STAV (`library_state` `:ok`/`:read_only` + SK dôvod a kód
`:newer`/`:foreign`/`:unknown_shape`/`:duplicate`/`:unreadable`/`:unexpected_shape`), maticu počíta čistá **fail-closed**
`assess_library_doc` (jej vetva má vlastný kód a hláška „súbor NEMAŽ, nahlás problém" — padne do nej aj chyba pluginu nad
zdravým súborom). Codex audit návrhu pridal
2 BLOCKERY a 3 FIXy, všetky zapracované: **(B2)** brána sa vyhodnocuje **pod zámkom nad čerstvo prečítaným súborom pred
KAŽDÝM zápisom** — cachované `:ok` nie je dôkaz (druhá inštancia môže súbor medzitým nahradiť); jedno miesto v `write`
kryje všetky zapisovacie cesty. **(B1)** read-only knižnica sa nesmie ani POUŽIŤ:
`global_default_state` vracia **nil** (odmietnu `ensure_project_state!`/`set_project_mapping!`/`add_project_sets!`/global
fallback `resolve_set_def`), `merge_project_sets_seed!` aj `freeze_template_sets!` majú `:blocked`, `template_set_defs` nil,
a súpis bez snapshotu skončí ORANGE **`library_incompatible`** (nový kód v `UNMAPPED_REASONS`; panel ide cez tú istú bránu
vrátane **neuplatnenia overridu skrinky**, aby sa so súpisom nerozišiel). Platný projektový snapshot beží ďalej.
**(F3)** seed-merge sa nad read-only knižnicou nerobí a nikdy sa nevracia SEED. **(F4)** detektor straty má DVE vrstvy —
**whitelist kľúčov** (nové pole) + **round-trip `normalize_sets`/`members_lost?`** (nová HODNOTA známeho kľúča, napr.
`per: 'length'`, vrátane počtu položiek radu `code_by_nl`); mapovanie cez `parse_mapping` bez `set_ids` (odkaz na zmazaný
set nie je strata). Obe vrstvy používa aj `project_state_status`. **(F5)** `sets_payload` nesie `library_state` +
`library_reason`, sekcia `hw` ukazuje dôvod bannerom a vypína globálne mutácie. `write` stampuje `std` podľa OBSAHU;
**priznané (NOTE 7):** historický `std: 1` s novým obsahom sa neopravuje sám — marker sa povýši prvým legitímnym zápisom.
**Interné slepé review (2×P1, 3×P2, 2×P3)** doplnilo: stav sa **NECACHUJE** a `read_library` pri read-only vracia **prázdno**
(`load` je bezpečný z princípu; samostatná „bezpečná" metóda zanikla — stačilo raz siahnuť na `load`); poškodený primár
**bez zálohy** ostáva **samoopravný ako na maine** (read-only s cestou v hláške až keď sa nedá prečítať ani `.bak`).
**Verifikácia delty** našla ďalšie 1×P2 + 2×P3: guard šablón bol príliš široký (jedna mŕtva referencia brala kovanie
šablóne aj nad ZDRAVOU knižnicou a hláška klamala) — zúžený na pokazený ZDROJ; zrušená cache rozbehla záplavu logu —
`log_skip` je počas brány stíšený a dôvod ide do konzoly len pri ZMENE stavu; duplicitné `set_id` dostalo vlastný dôvod
„oprav súbor". **Codex potvrdzovacie kolo** (1×P1 + 1×P2 + 1×P3) pridalo TRETIU vrstvu detektora — **typy hodnôt známych
kľúčov** (`code_by_nl` ako pole prešlo whitelistom aj round-tripom, lebo ne-mapa sa počítala ako „nula položiek";
`['future'].to_s` by sa pritom stalo objednaným „kódom") — a **fail-closed** bránu: výnimka v detektore (`qty: true` →
`NoMethodError`) končí ako `:read_only`, nie ako výnimka, ktorú by `load` zachytil a `library_read_only?` vyvolala znova
(súpis by skončil ako `nil`, teda BEZ oranžového priznania). Typová ochrana je aj vo `validate_member` — spoločnom tele
čítacích ciest, ktoré cez bránu nejdú. Degraded/`.bak` (**R-11**) sa **nerieši**, len sa mu nezavadzia (nový dôvod patrí
do tej istej matice s vlastným kódom). Testy `tests/pure/test_r07_kniznica_brana.rb` (26 scenárov: dvojinštančný +
reprodukcie nálezov review; mutačne overené, že padnú na regresii — okrem poradia *čítanie → rozhodnutie*, ktoré je pri
necachovanom stave nepozorovateľné a ostáva obranou do hĺbky) + `tests/js/test_r07_kniznica_ui.js`.

### R-08 · P1 · core · `core/json_file_store.rb:36-43` + sets/rules/abs_rules/dim_series/supplier_settings
Read-modify-write globálnych katalógov bez medziprocesového zámku (revision check mimo zámku; globálne mapovanie
bez revision) — dve inštancie SketchUpu si prepíšu zmeny. Materials/Templates/usage_stats + `vepo_settings`
(1b-6c) už sidecar flock vzor MAJÚ. [E:R-06]
**Návrh:** zjednotiť na `lock → fresh read → revision check/merge → atomic write` (vzor 1b-6c/`materials.lock`);
začať setmi a pravidlami kovania. **Odhad: M.**
**✅ dávkou 1d/R-08 (PR #258, v0.8.16)** — všetkých 5 súborov: každý zápis (vrátane `ensure_seeded` a seed-merge v `load`)
beží pod zdieľaným sidecar zámkom `materials.lock`, pod ním sa číta NANOVO a merge sa PREPOČÍTA; kontrola revízie sa
presunula DOVNÚTRA zámku (`save_set!`, `delete_set!`, a nová revízia aj v `patch_active!` — dovtedy len v okne).
Codex audit návrhu pridal 5 blockerov, ktoré sú zapracované: **dir všetkých 5 modulov = `Materials.dir`** (zámok a dáta
v jednom priečinku aj pod `test_dir_override` — in-SU test dovtedy menil ŽIVÉ ABS/kovanie pravidlá) · **dvojitý check
v `ensure_seeded`** (oneskorený seeder neprepíše cudziu zmenu) · **`HardwareSets.load_with_revision`** (knižnica a revízia
z JEDNÉHO stavu súboru — dovtedy payload spájal staré sety s novou revíziou) · **revízia aj pre globálne mapovanie setov**
(`:ok`/`:conflict`/`false`). **Zvyšok priznaný ako R-35** (úplná náhrada bez revízie: globálne pravidlá kovania a rozmerové
rady). Testy `tests/pure/test_r08_zamky.rb` (16 scenárov vrátane reálneho dvojprocesového `flock`; 9 mutácií overených).

### R-09 · P3 · core · `hardware_sets.rb:325` · `hardware_rules.rb:216`
`seed_version` sa stampuje konštantou → starší plugin ju ZNÍŽI a novší znova doseje zámerne zmazané seed
sety/pravidlá. Katalóg má F8 vzor (zachovať uloženú hodnotu, bump len nahor). [S-11] **Návrh:** prevziať F8 vzor. **S.**

### R-10 · P3 · ui · `ui/js/hw_sets.js:39-43, 754`
`set_id` (zamŕza do snapshotov v .skp) vzniká na klientovi slugom s try/catch okolo `normalize` → ten istý názov
môže dať inú identitu (rozpor s pravidlom „ID generuje server"). [S-06]
**Návrh (spresnené review #251):** slug generuje `HardwareSets.save_set!` výhradne pri CREATE (klient posiela len
meno + `create: true`); EXISTUJÚCI set sa ďalej identifikuje svojím nemenným `set_id` — ten sa nikdy neprepočítava
z mena (premenovanie identitu nemení). **S.**

## Os PERZISTENCIA — dopredná kompatibilita a integrita (pred D-48/shared library; časť pred KOVANÍM)

### R-11 · P2 · core · `core/json_file_store.rb:79-87` + 5 volajúcich
Poškodený primár sa ticho číta zo zálohy a najbližší zápis ho prepíše STARŠÍM obsahom (strata všetkého medzi
zálohou a poškodením). HardwareCatalog má správny vzor (degraded = read-only, GH #99); sets, rules, abs_rules,
dim_series a supplier ho nemajú. [S-07] **Návrh:** `JsonFileStore.degraded?(path)` + write guard na jednom mieste. **M.**

### R-12 · P2 · core · `core/cabinet_builder.rb:227-233, 1241-1289, 1560-1610`
Prestavba zákazky z NOVŠIEHO pluginu ticho stratí dáta: configy sú uzavreté whitelisty a dopredný guard existuje
len pre kovanie (`guard_unknown_hardware!`); `plan_schema`/`part_key_schema` sa na „novšie než moje" nekontrolujú.
Riziko pre rolu `flap`: rola v `BuildPlan::ROLES` JE, ale neznámy typ čela sa pretypuje na `door`
(`fronts.rb:313`) a whitelisty ostatné nové polia ticho stratia (spresnenie GLM 30.8.). [S-09; súvisí E:R-07]
**Návrh (spresnené review #251 kolo 2):** zovšeobecniť na `guard_newer_config!` (odmietne prestavbu,
čítanie/export beží) — ale existujúce markery kompatibilitu configu NEDOKÁŽU (`BuildPlan::SCHEMA` verzuje
tranzientný tvar plánu, `part_key_schema` len kľúče dielcov): builder musí začať zapisovať VLASTNÝ
`config_schema` marker a guard porovnáva ten. **S/M.**

### R-13 · P2 · core · `core/store.rb:9-10, 28-49` + STANDARD §2.1
`NOXUN/std` na entite sa VŠADE píše a NIKDE nečíta — záväzný bod štandardu bez implementácie; čítacia vrstva
nerozlišuje legacy/current/newer/invalid. **Rozhodnutie Michala:** doplniť čítanie (ORANGE „dielec z inej verzie
štandardu" vo Validation), alebo pole zo štandardu vypustiť — stav „píšem, nečítam" je najhoršia možnosť.
[E:R-07 + S-10] **Návrh:** podľa rozhodnutia; ORANGE variant **S**.

### R-14 · P2 · core · `core/budget_store.rb:428-466`
Dáta rozpočtu v zákazke (8 NOXUN kľúčov) bez verzie formátu — prvý klik v Rozpočte nad zákazkou z novšieho
pluginu ticho odreže neznáme polia (pasca pre spotrebiče S1). [S-12]
**Návrh:** `budget_std` + dopredný guard (read-only s hláškou), tvar ako R-12. **S.**

## Os VÝSTUPY — production_core · rozpočet · ponuka (pred D-95/KONTROLA+VÝROBA)

### R-15 · P2 · ui · `ui/production_core.rb` (1834 r.)
Jadro výstupov mieša výpočty s UI (savepanel, výber entít, fokus, statusy, BudgetStore mutácie) — D-95, exporty
aj renderer ponuky závisia od UI vrstvy. [E:R-08 + F-05]
**Návrh:** žiadny hromadný presun — vyrezať neutrálny `OutputPackage` (BOM + odhady + hardware + validácia +
rozpočet), dialógy/fokus/statusy ostávajú v UI orchestrátore. **Podmienka poradia: až PO P0 bránach** (menia tie
isté miesta). **Odhad: L.**

### R-16 · P2 · core · `core/budget.rb:164-200` + `core/cp_export.rb:305-370`
Menovky materiálov v core sú vlastné a chudobnejšie než Štúdio/VEPO (bez výrobcu/rubu) — rozpočet je NÁKUPNÝ
dokument a dvaja výrobcovia toho istého dekoru majú identický riadok. **Podmienka z review #250: DVE úrovne** —
production-unique (smie eskalovať až na `[material_id]`) vs customer-safe (ponuka interný fallback nikdy
nedostane). [E:R-09 + C14 + #250]
**Návrh:** kolízny aparát presunúť z Panel do `Materials` s dvoma projekciami; kolízny test dvoch výrobcov. **M.**

### R-17 · P2 · core · `core/validation.rb:690-719`
Zelené číslo semaforu nadhodnocuje čistý stav: `dirty` sa počíta cez množinu `cabinet_id` — dve skrinky so
spoločným ID / skrinka bez ID nemajú vlastnú identitu; skrinka bez placementu je vždy „čistá". [E:R-11 + A5/B10]
**Návrh (spresnené review #251 kolo 2):** per-instance token NIE z placements — `Bom.add_placement` skrinku
s prázdnym ID/degenerovanými rozmermi zámerne vynecháva, čiže presne chybný scenár by v zdroji chýbal.
Token brať priamo zo zberu inštancií (`Bom.collect` entita / persistent id); test dvoch kópií s jedným ID +
entity bez ID. **M.**

### R-18 · P2/P3 · ui · `ui/js/budget.js:1392-1397, 1441-1472, 1557-1568`
`BUD_MORE.sent = true` pred reálnym odoslaním + korelácia výsledku len podľa MENA operácie → skorší inline zápis
zavrie ⋯ modal ako „uložené"; odmietnutý zaradený zápis stratí hodnoty. [E:R-10 + A6]
**Návrh:** request token prenesený serverovým echom (vzor 1b-7 kolízie); regresia „inline beží → submit ⋯ →
prvá odpoveď modal nezavrie". **S.**

### R-19 · P3 · ui/core · `ui/production_core.rb` → `dup_id_suffix` / `cp_warnings`
Varovanie o duplicite zahadzovalo `kind`. **✅ ČIASTOČNE dávkou P0-HF (#252)** — znenie je odvtedy neutrálne
(„zlieva do jedného vlastníka"), nepravdivý text o kovaní pre dosky už neexistuje (spresnenie GLM 30.8.).
OSTÁVA: rozlíšiť `kind` v texte + zjednotiť fyzicky duplicitnú vetu do jednej privátnej metódy. [A7 + C6]
**Návrh:** jedna privátna metóda s rozlíšeným `kind`. **S.**

### R-20 · P3 · ui · `ui/production_core.rb` → `materials_meta` (~:811 na dc2d53f) · `ui/js/studio.js:1147-1268`
UNI katalógová hrúbka sa kreslí ako hrúbka skupiny/nákupného riadku (je len default roly); zdroj duplákov zo
`sheet_estimate` sa v Platniach kreslí ako holé ID bez hrúbky/farby. [B4 + B5]
**Návrh:** `materials_meta` doplniť o sheet_estimate zdroje; hlavičku značiť poctivo. **S.**

### R-21 · P3 · ui · `ui/js/studio.js:1276-1313`
Súhrny Platní/ABS (a hlavičky skupín pri hľadaní) ignorujú filter — hlásia celoprojektové čísla bez označenia.
[E:R-14 + A4/B6] **Návrh:** medzisúčet z filtrovaných riadkov alebo explicitné „celkom". **S.**

### R-22 · P3 · ui/docs · `ui/production_core.rb` (komentár ~:1851; `firewall_hits` už beží pred zápisom)
Firewall CP: kontrakt OSTÁVA report-only (STANDARD §11.3; dispozícia #250). Vyhodnotenie `firewall_hits` UŽ
beží pred `XlsxWriter.write_book` (spresnenie GLM 30.8.) — OSTÁVA: HLÁSIŤ používateľovi pred vznikom súboru
(dnes status príde až po ňom) + opraviť klamlivý blokový komentár „ide do statusu aj do logu" v
`production_core.rb` (log nevzniká; známy dlh Docs cleanup C). [E:R-12 korigované #250]
**Návrh:** hlásenie pred vznikom súboru, nezastavovať; opraviť komentár. **S.**

## Os UI VZORY a drobné dlhy

### R-23 · P2 · ui · `panel.html` / `studio.html` (10 modálov) vs `nx_modal.js`
10 ručných modálov mimo kostry; 5 štúdiových nemá VLASTNÝ Escape (dokumentový handler pozná len NXModal — reprodukcia úzka, ale kontrakt „Escape zatvára modál" neplatí); `absModal` bez Escape; Tab-trap 3× skopírovaný. [S-13]
**Návrh:** (1) Escape reťaz hneď (**S**) · (2) `confirm` tvar v nx_modal + zrušiť kópie Tab-trapu (**M**) ·
(3) kostru prevziať pri D-110.

### R-24 · P3 · ui · 11× HTML-escaper (5× `esc` + 6 premenovaných klonov) · 2× cssEscape · 4× normText
Trojica elementárnych pomocníkov naklonovaná po moduloch; normalizácie sa už rozišli; v `hw_sets.js:41` sú
kombinujúce znaky U+0300–U+036F vložené v regexe SUROVO (NFC nástroj ho ticho pokazí). [S-14 + S-15]
**Návrh:** `ui/js/nx_text.js` + tenké aliasy; surový regex prepísať na escapovaný zápis
(backslash-u0300 až backslash-u036f — len ASCII, žiadne neviditeľné znaky; presne ako v `nx_combo.js:55`). **S.**

### R-25 · P3 · ui · `ui/js/bridge.js:325-329`
`studioRelay` (klik na riadok) nemá guard rozpísanej editácie Inspectora, ktorý majú 4 exportné relaye. [B9]
**Návrh:** rovnaký `validateFields` guard. **S.**

### R-26 · P3 · ui · `ui/studio_dialog.rb:161-167` + `core/grain_check.rb:367-373`
`GrainCheck.restore!` pri otvorení Štúdia nerozposiela stav → rail tvrdí opak. [B11 ≡ C7]
**Návrh:** `broadcast_grain_check` aj v restore ceste. **S.**

### R-27 · P3 · ui · `ui/rules_dialog.rb:192-228` + `ui/js/studio.js:139` + UI20_KONTRAKT
Texty: nominálna trieda ABS písaná ako „1,0 mm"; „pravidlo sa neuplatní" pri čiastočnom override nepresné; hint
„Rozpočet je jediná sekcia, ktorá mení model" už neplatí. [B7 + B13 + B8] **Návrh:** textová dávka + kontrakt. **S.**

### R-28 · P3 · core · `core/bom.rb:197-207`
Mŕtvy hardware override sa kreslí ako aktívne rozhodnutie (filter len na existenciu dielca, nie zhodu so živým
pravidlom — kontrast `apply_overrides`). [B3] **Návrh:** párovať proti vyhodnoteným položkám. **S.**

### R-29 · P3 · ui · `ui/js/studio.js`
Scroll sekcie neprežije prepnutie (UI20_KONTRAKT riadok 67 — súbor nemá §-číslovanie). [B15] **Návrh:** scrollTop per sekcia. **S.**

### R-30 · P3 · ui · `actions_parts.rb` / `actions_hardware.rb`
Jantárové riadky sa po zápise z Inspectora neobnovia — KOLÍZIA so zámerným ručným refreshom Štúdia: rozhodnutie
o kontrakte okna, nie bugfix. [B12] **Návrh:** rozhodnúť pri D-95 (kontrola je hlavný konzument).

## IDENTITA a proces

### R-31 · P3 · core/kontrakt
Identita zákazky je trojitá (cesta + guid kľúč + most v pamäti) — stabilné ID zákazky v NOXUN dictionary by
kaskádu zrušilo. Zmena dátového kontraktu ⇒ vlastná dávka s auditom; `project_name` je navyše čítanie so
zápisovým vedľajším účinkom a migrácia „pri uložení" = observer (audit-povinná). [C10 + C11 + C12]
**Návrh:** zvážiť pri V1 DOTIAHNUTÍ; nie pred GHOST/KOVANÍM.

### R-32 · P2 · docs
18 stub odsekov architektúry — najväčšia diera presne pri moduloch pod zásahom (hardware_sets, výstupy, panel
akcie). Kostry kontraktov pre všetkých 18 dodal externý audit (tabuľka v
[zdroje/AUDIT_2026-08_externy_codex.md](zdroje/AUDIT_2026-08_externy_codex.md)). [E:R-15]
**Návrh:** dopĺňať TESNE PRED prvým zásahom do modulu (overiť proti kódu), nie slepým hromadným prepisom.

### R-33 · P3 · docs/plán · testy
Hygiena: D-87 bez vlastného nadpisu v DOGFOODING_vyriesene [B16] · XLSX/CSV kusovníka bez vlastníka v PLANe [B17] ·
testové dlhy CHAR/st1b: zapamätaný grain prepínač po `run_st1b`, komentár CH4 side-effectu, teardown overlayov vo
walk rescue, CH4c východiskový assert, CH2 `valid?` guard [B18 + C2 + C3 + C8 + C9].
**Návrh:** jedna docs + jedna test-only dávka. **S.**

### R-34 · P3 · core · `core/hardware_sets.rb` (expanzia, príznak `per_owner`)
Presnosť predikátu P0-2 brány (z review #252, kolo 3): `per_owner` sa označuje pri KAŽDOM vydanom owner členovi,
nie až vo vetve, kde `owner_seen[key]` reálne preskočí duplikát — dve inštancie so zdieľaným `cabinet_id` ale
rôznym `owner_part_key` majú správne množstvá a brána ich napriek tomu zastaví. Zlyháva výhradne bezpečným smerom
(falošne pozitívne, len v už ORANGE-označenom stave). Návrh opravy je v threade #252.
**Návrh:** označovať `owner_id` až pri reálnom preskoku duplikátu. **S.**
**✅ dávkou 1d/R-34 (PR #262, v0.8.18)** — `owner_seen` drží **už vydaný zdrojový záznam** riadku a druhý zásah na ten istý kľúč mu `per_owner` doznačí; `add_row` príznak sám
nepíše a vracia `src`. Duplicitné ID **bez** reálneho zlievania export prepustí (ORANGE nález Kontroly ostáva), **so** zlievaním blokuje ako doteraz; `dup_partition` sa
nemenil v koncepte. **Review #262 P1 dávku rozšíril:** zdieľané ID kazí objednávku aj druhou cestou — `cabinet_sets` má na ID jeden slot, takže pri **rozídených** override
mapách expanzia použije mapu jednej inštancie na obe a neisté sú rovno KÓDY. Zber to hlási aditívnym kľúčom `cabinet_set_conflicts` (`Bom.note_cabinet_sets`; zhodné mapy
konflikt nie sú) a brána také ID blokuje aj bez zliatia owner člena — **kolo 2 (P2) to zúžilo na rozdiel v kľúči, ktorým si skrinka kovanie naozaj mapuje** (rozídený typ,
ktorý nepoužíva, neblokuje; neznámy rozdiel blokuje). Zvyšok priznaný v KRONIKE: či sa override rovná projektovej predvoľbe, brána nevie — vyžadovalo by to druhý výklad
precedencie vedľa `HardwareSets.resolve_set_id`. **Priznaný zvyšok:** dve pravidlá na tej istej skrinke (dedup B3) sú od dvoch inštancií nerozlíšiteľné —
expanzia vidí len `owner_id` — takže príznak dostanú tiež; rozlíšenie by vyžadovalo identitu inštancie až v `Bom.collect` (zásah do kontraktu, nie hygiena predikátu).

### R-35 · P2 · core/ui · `core/hardware_rules.rb:write` + `core/dim_series.rb:set` (+ ich okná)
Zvyšok po R-08 (z Codex auditu dávky 1d/R-08, nálezy #3 a #6): tieto dva súbory sa zapisujú ako **ÚPLNÁ NÁHRADA
obsahu** — okno Pravidlá posiela CELÉ pole pravidiel („aj ako globálna predvoľba"), panel posiela CELÝ objekt
rozmerových radov, a **ani jeden z nich nemá revíziu**. Medziprocesový zámok z R-08 ich zápisy serializuje (a chráni
pred preplietaním so seed-merge cestou), ale dve súbežne otvorené okná sa nad nimi stále prebíjajú „posledný vyhráva"
— prvá zmena zanikne bez slova. Nejde teda o dieru v zámku, ale o chýbajúci **optimistický zámok v UI kontrakte**.
**Návrh:** vzor, ktorý sety aj nastavenia dodávateľa už majú — `global_revision` (SHA odtlačok súboru) do payloadu
sekcie → klient ju posiela späť → porovnanie POD zámkom → `:conflict` a načítanie formulára nanovo. Pri rozmerových
radoch je alternatíva zápis PO KĽÚČOCH (rad je nezávislý per rozmer), ktorý revíziu nepotrebuje. **Odhad: S/M.**

### R-36 · P3 (macOS) · core · `core/scale_observer.rb` — `onEraseEntity` · `notify_erase`
Zvyšok po R-01: pri `onEraseEntity` je entita **už neplatná**, takže jej dokument sa nedá zistiť. Taká požiadavka ide
do množiny ako sentinel `nil` a v tiku ju rozhodne fallback — takže **dva NEZNÁME erasy z dvoch dokumentov splynú**
(prepisovanie ZNÁMYCH požiadaviek R-01 odstránila). Dôsledok na macOS: v jednom z dvoch dokumentov ostanú osirotené
ghost zóny do najbližšieho erase v ňom. Windows sa netýka (jeden dokument na proces).
**Návrh:** zviazať dokument s observerom už pri `attach_one` (per-model `CabinetEntityObserver`). **POZOR — to je
presne dôvod odloženia:** observer by držal **silnú referenciu na každý otvorený dokument**, takže zatvorený dokument
by sa neuvoľnil; riešenie potrebuje aj cestu, ktorá registráciu pri zániku dokumentu spoľahlivo zruší (na macOS na to
nie je udalosť). Robiť až s GHOST/Tool vrstvou, ktorá multi-model lifecycle rieši tak či tak. **Odhad: M.**

## Vyriešené počas blokov 1b/1c/1d (záznam — nevybavovať; sem sa presúvajú aj ✅ položky pri uzávere 1d)

B1 názov projektu (1b-6a, #244) · B2 hlavičky materiálov (1b-6b, #247) · A1/A2 tichý návrat ceny dekoru
(1b-7, #246) · B14/C13 zámok vepo_settings (1b-6c, #248) · C4/C5 (#187, commit e83abe4) · D-27 tagy z panela (#249).

## Odporúčané poradie pre 1d (zhoda [E] aj [F/S])

1. **P0 hotfix** (✅ #252) → 2. **pred GHOST:** ~~R-01+R-04~~ (✅ #261) → ~~R-02~~ (✅ #264) → ~~R-03~~ (✅ #265 — **tvrdý blocker GHOST padol**) *(GHOST package upresňuje: tvrdý
blocker je len R-03 — GHOST smie na Windows štartovať hneď po ňom; R-01 je macOS vetva, R-02 je na Windows P3
a R-04 je platformovo nezávislá hygiena — všetky tri sa dorobia v 1d nezávisle od GHOST štartu)* → 3. **pred KOVANÍM:** ~~R-06 brána~~ (✅) ·
~~R-07~~ (✅ #266) · ~~R-08~~ (✅) · potom R-05 (+R-06 plný) ako D-109 šev → 4. **pred D-95/VÝROBOU:** R-17, R-16, R-22, po etapách R-15 →
5. **perzistencia:** R-11 → R-12 → R-14 (R-13 po rozhodnutí Michala) → 6. **UI/hygiena:** ~~R-34~~ (✅ #262) ·
R-23.1 Escape (S, hocikedy) · R-18 · zvyšok podľa kapacity. R-32 kostry priebežne pred každým zásahom.

**Otvorené rozhodnutia Michala:** R-05 (rozsah zaokrúhľovania pomeru per zákazka vs per skrinka — rozhodne
USER-debata o setoch, PRED implementáciou D-109) · R-13 (`std` na entite: čítať vs vypustiť) · R-30 (jantárové
riadky vs ručný refresh — pri D-95).
