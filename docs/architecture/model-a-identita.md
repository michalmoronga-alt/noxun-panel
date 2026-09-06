# Model, identita a perzistencia

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Jadro dátového kontraktu: prevod jednotiek, identifikátory, prístup k `NOXUN` dictionary, identita dielcov, kontrakt plánu, atomický zápis súborov a knižnica šablón.

## Základ dát

### units.rb

JEDINÉ miesto mm↔Length konverzií.

### ids.rb

identifikátory entít (CAB-xxx, BRD-xxx).

**`duplicates_of` / `duplicate_cabinets` / `duplicate_boards`** vracajú NOVŠIE inštancie (vyšší `entityID`) zdieľajúce ID — pôvodná si identitu podrží (STANDARD §2.3/§9.3: kópia
dostane nové id). **Od 1b-3 (brána G bloku 1b) ich číta výhradne ZÁPISOVÁ cesta** — dedup tik `ScaleWatch` a `Panel.push_selected` → `request_dedup`. Čítacie cesty okien identitu
NEOPRAVUJÚ: duplicitu zbiera `Bom.collect` do kľúča `identities` a Kontrola ju prizná ako ORANGE `duplicate_identity` (detail v [outputs.md](outputs.md)).

### doc_key.rb

**STABILNÁ identita dokumentu pre identity guardy** (1d/R-02b). `DocKey.key(model)` vydá token `nxdoc-<random>`; **rotuje ho UDALOSŤ výmeny dokumentu, nie život Ruby objektu** —
`DocKey.invalidate(model)` volajú `PanelAppObserver#onNewModel`/`#onOpenModel` **aj** `ScaleWatch::EngineAppObserver` (prvý garantuje poradie voči pushu do panela, druhý je
nainštalovaný vždy a kryje Štúdio a dialógy bez Inspectora; že rotujú dvaja, nevadí — udalosť je **ohraničená Ruby tickom**, takže vyrobí najviac jeden token, viac nižšie).
Volajú ho cez **`Engine.on_document_replaced`** (žije v `core/doc_key.rb`, aby ho vedela spustiť aj headless sada) — jedno miesto so **zoznamom pamätí viazaných na objekt
modelu**: identita `DocKey` a most názvu zákazky `SESSION_KEY_BRIDGE` (`outputs.md`). Obe stáli na tej istej falzifikovanej premise, preto majú spoločný cleanup a **každá ďalšia
taká pamäť doň musí pribudnúť — okrem tých, ktoré upratuje vlastná zdokumentovaná cesta** (`GhostTool` session sa ruší priamo v observeroch kvôli vlastnej hláške a poradiu voči
nástrojovému stacku; `ScaleWatch` cache transformácií čistí `forget_detached_models`, viď priznaná hranica tam).
**`onActivateModel` NEROTUJE** (macOS prepnutie medzi už otvorenými dokumentmi) a **uloženie, prvé uloženie ani Save As identitu NEMENIA**. Je to JEDINÝ
zdroj hodnoty poľa `model_guid` v payloadoch — meno poľa na drôte je historické (kontrakt R-02 sa nemenil), no hodnotou už NIE JE `Sketchup::Model#guid`, lebo ten sa mení pri
KAŽDOM uložení a Ctrl+S do 400 ms po úprave poľa panela vyzeral ako prepnutie dokumentu (edit sa zahodil, `nxDropDocState` zmazal rozpísaný stav; rovnako trpel baseline Pravidiel,
guardy Štúdia aj okno Materiály).

**PREČO udalosťou a nie životom objektu (review #267 P1-1):** prvá verzia stavila na „nový dokument = nový `Model` objekt". **Windows drží jeden dokument na proces a pri
File > Open smie ten istý objekt RECYKLOVAŤ** — to je v repe auditované už pri GHOST vkladaní (`construction.md` nižšie, `PanelAppObserver`, review #268 P2-2, in-SU GHOST 10).
Na recyklovanom objekte by nový dokument zdedil starý token a **padli by všetky tri obrany R-02 naraz**: `nxSetModelGuid` by zmenu nezbadal (rovnaká hodnota = žiadne
`nxDropDocState`), zachytená identita v bufferi by sedela a `foreign_document?` by zápis pustil — oneskorený apply by ticho pristál v cudzej zákazke.

**JEDEN EVENT = JEDEN TOKEN, ohraničené RUBY TICKOM** (review delty #267 P2-N1, oprava mechanizmu review v2 P2-1). Rotujú dvaja observeri a poradie SketchUp negarantuje;
naivné „zmaž záznam" nestačí, lebo callbacky observerov **nie sú len oznámenie — ony rovno notifikujú klientov**, takže medzi dve rotácie sa reálne vmestí `key()` a hodnota sa
zapečie do už odoslaného pushu: Štúdio by dostalo token A, panel token B, prvý klik v Štúdiu by v SPRÁVNOM dokumente skončil falošným „model sa prepol" a `hw_sets.js` by
projektové drafty zahodil druhýkrát — už nad novým dokumentom. `Engine.on_document_replaced` preto spustí cleanupy **raz za tick**: druhý observer toho istého eventu vidí
otvorenú udalosť a vráti sa. Nulový timer (`UI.start_timer(0, false)`) udalosť zavrie pri najbližšom prechode message loopom — teda určite **až po** všetkých observeroch jedného
eventu a určite **pred** ďalším File > New/Open (ten vyžaduje akciu používateľa). Poistka `DOC_EVENT_MAX_S`: keby timer nikdy neprišiel, zaseknutá udalosť by už nikdy nepustila
rotáciu — čo je presne návrat P1 — preto sa po sekunde považuje za zavretú. Headless (a in-SU scenáre, ktoré chcú odsimulovať dva eventy) zatvárajú tick priamo cez
`Engine.end_document_event`; je to **seam**, ktorý robí presne to isté ako timer.

> **Prečo NIE „epocha odvodená z modelu".** Medziverzia skúšala značku z `Model#guid` a bola to **diera** (review v2, P2-1): `guid` je **obsah .skp súboru**, takže **kópia zákazky
> nesie ten istý guid**, kým sa neuloží. File > Open kópie nad recyklovaným objektom by dal zhodnú značku, rotácia by sa vynechala a nový dokument by zdedil identitu starého —
> teda celý pôvodný nález P1 späť, len tichšie. To isté platilo pre re-open toho istého súboru (revert) a pre Untitled → Untitled. **Tick nečíta z modelu žiadnu hodnotu**, takže
> túto triedu dier nemá.

**Pasce, ktoré tvar modulu určili:** (1) token sa NIKDY nezapisuje do modelu/.skp — zápis pri otvorení panela by špinil čistý dokument (dirty + undo + zákaz zápisov z push ciest,
lekcia D-103) a token v súbore by prežil kópiu zákazky (dve kópie = jedna identita). Runtime token túto pascu nemá a **kópiu .skp chráni bezpodmienečná rotácia na `onOpenModel`**:
otvorenie kópie je výmena dokumentu ako každá iná, takže nová identita vznikne **bez ohľadu na to, či SketchUp objekt recykloval a či kópia nesie ten istý `guid`** (nesie —
guid je obsah súboru; práve na tom stroskotala epocha odvodená z modelu). (2) Identita sa neviaže na život objektu, ale na **dokument**: rotuje ju výhradne udalosť
New/Open, `onActivateModel` nie a **uloženie, prvé uloženie ani Save As nie** (Codex audit R-02b, BLOCKER 3 — klient držiaci identitu do plného payloadu, sekcia Materiály, by sa
po bezdôvodnej rotácii odmietal donekonečna; Save As je stále ten istý rozrobený dokument). **Save As výslovne** (námietka Codex kola 3 na #267, zamietnutá): je to pokračovanie
TOHO ISTÉHO dokumentu — identický obsah, iná cesta, žiadny observer. **Edit naplánovaný pred Save As sa aplikuje do premenovaného súboru — a je to žiaduce, je to ten istý
dokument;** rotácia by vrátila presne pôvodný bug R-02 (rozpísaná úprava sa pri uložení ticho zahodí ako „patrí inému dokumentu"). Z pôvodného súboru sa navyše nestane druhé
otvorené okno, takže niet komu identitu prekrížiť. (3) Registry drží SILNÚ referenciu + `equal?` (recyklácia `object_id` po GC) a **živý
dokument sa NIKDY nevyhadzuje** (BLOCKER 2 — vytlačený živý by po návrate dostal nový token a klient by zahodil drafty); upratuje sa len `valid? == false` záznam. (4) Chyba/ne-model
= `''` — **fail-closed obojsmerne**: odmieta sa aj prázdny kľúč SERVERA (BLOCKER 1, `'' == ''` by pustilo zápis bez identity). (5) Token je náhodný (unikátny naprieč sedeniami),
lebo `ProductionCore#project_session_key` persistuje `guid:<hodnota>` do `vepo_settings.json` — deterministický čítač by po reštarte kolidoval.

**`DocKey.foreign?(claimed, model, tolerate_blank_client: false)` je JEDINÝ porovnávač identity** (review #267 P3-2) — cezeň idú VŠETKY guardy: `Panel.foreign_document?`, zóny,
tagy, karty dielca a dosky, šablóny, Štúdio, Pravidlá, Materiály aj okno katalógu kovania. **Fail-closed na strane servera platí bez výnimky**: keď sa identita aktívneho dokumentu
nedá prečítať (`key` vráti `''`), zápis končí — predtým mala túto poistku len `foreign_document?` a ~20 priamych porovnaní ju obchádzalo. Jediný povolený rozdiel medzi guardmi je
pomenovaný `tolerate_blank_client:` (prázdny údaj z klienta = starší cachovaný DOM Štúdia/Materiálov, kryje ho generačný zámok) — vedomé rozhodnutie, nie vedľajší produkt tvaru
výrazu. Plošný test stráži, že sa ručné porovnanie identity do pluginu nevráti. Producenti hodnoty: `Panel.model_guid`,
`ProductionCore#model_guid`, `MaterialsDialog#model_guid`, `RulesDialog#model_guid`, okno katalógu kovania, `Materials.replace_uni_scan`. `core/scale_observer.rb` používa surový
guid ďalej — je to detektor zmeny dokumentu v ceste, ktorá pri ukladaní nebeží (rozhodnutie R-04); to isté platí pre `same_model?` v `edge_check`/`grain_check`/`hover_edge`, ktoré
porovnáva dve **súčasne držané** referencie v jednom okamihu (`equal?` má prednosť, guid je len záloha pre nový Ruby obal toho istého dokumentu). **Od kola 3 review #267 záloha
vyžaduje zhodný guid A zhodnú cestu:** guid je obsah .skp súboru, takže dve **súčasne otvorené kópie** tej istej zákazky ho majú rovnaký (macOS) — bez cesty by dva rôzne
dokumenty vyšli ako jeden a prekrytie by sa od prepnutého okna neodpojilo. Nie je to zápisová diera (ide o lifecycle prekrytí, nie o identitu zápisu), preto zostáva vedomou
výnimkou v `NX_DK_GUID_ALLOWED`, ale správanie stráži behaviorálna sada nad všetkými tromi modulmi.

**GHOST vkladanie stojí na tom istom fakte o Windows:** `GhostTool` session drží priamo objekt modelu (`@model`, porovnania cez `equal?`) a ruší sa cez `onNewModel`/`onOpenModel`
**bezpodmienečne** — práve preto, že porovnanie identity by pri recyklovanom objekte session omylom nechalo žiť. DocKey rotuje v tých istých dvoch callbackoch a z toho istého dôvodu.
S guidom ghost nikdy nepracoval; prípravná fáza `Panel.handle_insert` ide cez ten istý `foreign_document?` ako všetky ostatné zapisovacie handlery. Pod starým guidom by ju naopak
Ctrl+S medzi otvorením panela a stlačením „Vložiť" **odmietol** hláškou „panel patrí inému dokumentu" — DocKey to rieši spolu so zvyškom guardov.

**Testy:** `tests/pure/test_doc_key.rb` — behaviorálna sada nad stub modelmi (vrátane rotácie nad **recyklovaným** objektom a idempotencie dvoch observerov) + zdrojové kontrakty
producentov a observerov (`onActivateModel` nesmie rotovať; `invalidate` musí byť PRED pushom) + **plošný sken celého `noxun_engine/**/*.rb`**: každý nový výskyt `.guid` musí buď
test zhodiť, alebo si ho autor vedome dopíše do `NX_DK_GUID_ALLOWED` (zoznam nesmie klamať ani opačným smerom — odstránený výskyt test tiež nahlási). Sken vynecháva len riadky,
ktoré sú CELÉ komentárom: pôvodné strihanie `#` až do konca riadku prepúšťalo `"#{model.guid}"` (interpolácia začína `#`), čo je podchytené mutačným testcasom. Polovičná migrácia
identity je horšia než žiadna: časť guardov by Ctrl+S rozhodilo a časť nie. **In-SU sekcia `run_dockey`** overuje to isté v reálnom SketchUpe — vrátane probe `Model#valid?`
a reprodukcie recyklácie cez skutočný `PanelAppObserver#onOpenModel` (vzor scenára GHOST 10).

### store.rb

prístup k `NOXUN` dictionary.

### part_keys.rb

stabilná identita dielcov + `valid?` (aj `board/` prefix).

**`migrate_overrides` kľúče neexistujúcich dielcov ZACHOVÁVA** (zmena konštrukcie nesmie zahodiť ručné nastavenia, kým sa dielec môže vrátiť) — dôsledok: zoznamy ručných zásahov
musia mŕtve kľúče **odfiltrovať jointom s reálnymi dielcami** (`Bom.collect_manual_overrides`, ŠT-3b-2a), nie ich zobraziť.

**KOV-A1 — dva nové `kind`-y čela:** `front:F#/flap` (výklop aj sklop — jedna rola `flap`, typ rozlišuje resolved čelo) a `front:F#/blind` (blenda, rola `false_front`).
Sú **ADITÍVNE**, takže `PartKeys::SCHEMA` sa **nebumpuje** (staré kľúče sa nemenia) a `valid?` ich prijíma existujúcim `front:` pravidlom. Vlastný kľúč (namiesto `front:F#/panel`)
je vedomé rozhodnutie auditu #14 (BLOCKER 5): kolízia so zásuvkovým čelom by po prepnutí typu ticho presmerovala override aj kovanie na iný dielec. **Overridy sú per kind**, takže
pri prepnutí typu ostávajú **dormant pod starým kľúčom** (vzor `migrate_overrides`) a po návrate sa obnovia — nikdy sa neprenášajú.
`human_label` má vetvy `/flap` → „F2 · **výklop**" alebo „**sklop**" (podľa `type` resolved čela; bez zhody neutrálne „výklop/sklop" — nikdy sa nič neodhaduje) a `/blind` → „F2 · blenda".

**KOV-C2b — štyri kľúče vyrábaných dielcov zásuvky:** `front:F#/drawer_bottom` · `/drawer_back` · `/drawer_inner_front` a `/box_side:left|right` (variant nesie stranu — bez
neho by dva boky Quadro boxu mali rovnaký kľúč). Sú **ADITÍVNE**, takže `PartKeys::SCHEMA` sa **znova nebumpuje**; `human_label` k nim pridáva číslo čela („F2 · dno zásuvky",
„F2 · bok boxu ľavý"). Kľúče sú deterministické z `front_id` + roly, preto sa dajú zložiť **bez plánu** — na tom stojí výpočet hrúbok kanála `:drawer` PRED plánom
(`CabinetBuilder.drawer_thicknesses`, [materials.md](materials.md)).

**KOV-A2b — `front_id(key)`:** čistý parser, ktorý z kľúča dielca vytiahne ID čela (`front:F2/wing:single` → `F2`), inak `nil`. Formát kľúča je kontrakt tohto modulu, takže druhý
parser inde by sa časom rozišiel; jediný čitateľ je zatiaľ deep-link „klik na RED nález otvorí kartu čela" (`ProductionCore.do_select` → `Panel.push_focus_front`).

### build_plan.rb

**ZÁVÄZNÝ kontrakt plánu** (SCHEMA 4, MIN_DIM, validátor, `warnings[]`, hardware string-keyed s GENERIC_TYPES/limitmi/referenčnou integritou ownera). Geometria, kusovník aj VEPO
čítajú TEN ISTÝ plán.

**`GENERIC_TYPES` + `lift` a `SCHEMA` 2 → 3 (KOV-B1, v0.9.19).** Slovník typov kovania dostal `lift` (výklopy a sklopy) — presunuté z KOV-E podľa auditu #17 BLOCKER 2, lebo
kanonická mapa `use_type → generic_type` v `hardware_sets.rb` ho potrebuje UŽ TERAZ (inak sa výklopový set nedá uložiť). PRAVIDLÁ ani seed mapovanie k nemu zatiaľ NIE SÚ — tie
prinesie KOV-E; slovník je tu preto, aby už nebol potrebný ďalší bump kontraktu. Rozšírenie je pre STARŠÍ plugin neznámy typ, ktorý jeho `guard_unknown_hardware!` odmietne, takže
plán, ktorý ho môže niesť, už nie je plánom schémy 2 — odtiaľ bump. Slovenský názov („Výklop / sklop") žije v troch mapách naraz (`HardwareRules.label_for`,
`Validation::HW_LABELS`, `ui/js/rules.js`) a paritu stráži guard, ktorý iteruje `GENERIC_TYPES` — nie opísaný zoznam.

**`SCHEMA` 3 → 4 (KOV-C2b, v0.9.31): DIELCE ZÁSUVIEK.** `ROLES` dostali `drawer_bottom` · `drawer_back` · `box_side` · `drawer_inner_front` (zhodné s `Recipes::ROLE_*`
aj `CabinetBuilder::DRAWER_ROLES` — väzbu drží guard test), materiálový signál dielca pozná **`:drawer`** (4. kanál) a `HW_SOURCES` má **`recipe`**. Položka výsuvu z receptu
smie navyše niesť voliteľné **`locked: true`** — a to VÝHRADNE pri `source: 'recipe'` a len keď existuje platný NL zámok (Astra #19 N11: inak by každá zásuvka hlásila „ručne
prepísané"). Plán má aditívny kľúč **`drawer_conflicts`** (fail-closed dôvody; validuje `validate_drawer_conflicts!` proti registru `Recipes::DRAWER_BLOCKERS`) a dva
zápisové kanály pre builder — `drawer_writes` a `drawer_override_writes`. Rozšírenie je pre STARŠÍ plugin neznáma rola aj neznámy `source`, takže plán, ktorý ich môže niesť,
už nie je plánom schémy 3 — odtiaľ bump.

**`hardware_set_key_type` pozná prefix `class:`** (triedny kľúč mapovania setov, [hardware.md](hardware.md)): vracia z neho prvý segment, takže `class:lift|classic` prestavbu
neblokuje a `class:sliding|classic` z novšej verzie áno. `parse_hardware_set_key` pre triedny kľúč vracia `nil` — nie je to výber podľa typu ani podľa dielca.

## Perzistencia a nastavenia počítača

### json_file_store.rb

Spoločná perzistencia malých JSON katalógov v `%APPDATA%\NOXUN\Engine` (materiály, šablóny, sety a pravidlá kovania, ABS, rozmerové rady, nastavenia dodávateľa). Modul rieši
**atomicitu**, nie súbeh — medziprocesový zámok je nad ním (`Materials.with_catalog_lock`, sidecar `materials.lock`, 1d/R-08).

- **Zápis** ide `tmp → fsync → `.bak` → rename`: nikdy neexistuje okno, v ktorom by bol cieľový súbor neúplný. `preserve_valid_backup` odloží PREDCHÁDZAJÚCI obsah do `.bak`, ale
  **len keď sa parsuje** — poškodený primár nesmie prepísať poslednú dobrú zálohu.
- **Čítanie** má sekundovú cache (`CHECK_INTERVAL`) kľúčovanú expandovanou cestou; položka sa invaliduje podľa podpisu súboru (mtime + veľkosť) alebo ručne cez `reload!` /
  `invalidate`. Hodnota je **deep-frozen**, `read(copy: true)` vracia kópiu. Cudzí proces cache nezhodí — preto každá zapisovacia cesta číta pod zámkom NANOVO (`reload!`).
- **`.bak` recovery:** `read_primary_or_backup` pri poškodenom primári prečíta zálohu, takže panel sa neotvorí prázdny.
- **`degraded?(path)` (1d/R-11)** je odpoveď na tienistú stranu tej recovery: keď sa číta zo zálohy, najbližší zápis by primár prepísal obsahom odvodeným od **staršej** zálohy
  a všetko medzi zálohou a poškodením by zmizlo. `degraded?` je pravda **práve vtedy**, keď primár EXISTUJE a NEPARSUJE sa a zároveň existuje parsovateľná `.bak`. Chýbajúci primár
  s platnou zálohou degraded NIE JE (nič sa nestratilo — zhodne s `HardwareCatalog.assess!`) a poškodený primár BEZ zálohy tiež nie (niet z čoho čo stratiť; volajúci sa správajú
  ako doteraz, prvý zápis súbor samoopraví). Dve vlastnosti sú **kontrakt**: (1) číta **priamo z disku**, mimo sekundovej cache — cachovaná hodnota spred poškodenia by bránu
  otvorila presne v okamihu, keď má stáť; (2) **I/O chyby sa nerescue-ujú** (`false` znamená „smieš zapísať", a nedostupný súbor o zdraví primára nehovorí nič) — rescue je len
  pre `JSON::ParserError` (poškodený obsah) a `Errno::ENOENT` (súbor nie je), zvyšok vyletí a skončí v rescue vetve volajúceho ako NEÚSPEŠNÝ zápis.
- **Guard NEŽIJE tu.** `write` sa nemení; bránu volá **každý z piatich volajúcich na jednom mieste svojej zapisovacej cesty, POD zámkom** tesne pred zápisom (cachovaný stav nie je
  dôkaz — lekcia R-07). Odkazy: `hardware_sets` / `hardware_rules` v [hardware.md](hardware.md), `abs_rules` v [materials.md](materials.md), `supplier_settings`
  v [outputs.md](outputs.md), `dim_series` nižšie. Testy: `tests/pure/test_r11_degradovana_zaloha.rb`.
- **Priznaný zvyšok (R-11):** TOCTOU okno voči zapisovateľom, ktorí `materials.lock` ignorujú (ručný editor, antivírus) — uzavrel by ho až CAS/podpis tesne pred `rename`; vedome
  sa nerieši.

### dim_series.rb

**UI-B3 (N6) rozmerové rady**: bežné hodnoty ponúkané šípkou pri rozmerových poliach panela (`sirka`/`vyska`/`hlbka`/`sokel`/`vyska_cela` — posledný použije UI-C3). Je to
nastavenie **POČÍTAČA** (`%APPDATA%\NOXUN\Engine\dim_series.json`, zápis `JsonFileStore` atomicky + `.bak`), **NIKDY nie zákazky** — presne ako téma UI-01. `normalize` je jediná
autorita (HTML nie je ochrana): nečíslo von, hodnota mimo **10…3000 mm sa ZAHODÍ** (nie oreže — orezanie by do ponuky vložilo číslo, ktoré používateľ nenapísal; spodná hranica 10
mm chytá preklep „140,5"), **celé mm** (desatinná bodka sa zaokrúhli, **čiarka je v editore ODDEĽOVAČ hodnôt, nie desatinná**), bez duplicít, vzostupne, strop `MAX_VALUES`;
**prázdny rad je platný výsledok** (rad sa dá vypnúť), ale **chýbajúci kľúč padne na DEFAULT** a neznámy kľúč sa zahodí.

Chýbajúci aj poškodený súbor = predvolená sada (nikdy výnimka); **zlyhanie zápisu vracia `nil`** — volajúci to musí povedať nahlas, tichý fallback by ohlásil úspech, ktorý sa
nestal (to isté platí pre `Engine.set_ui_theme`). Modul o modeli nevie — rad je len **ponuka**, zápis hodnoty ide existujúcou cestou poľa v paneli.

**1d/R-08:** `set` beží pod tým istým zdieľaným sidecar zámkom ako ostatné katalógy priečinka (`Materials.with_catalog_lock`, `materials.lock` — mechanika v
[hardware.md](hardware.md), odsek `hardware_sets.rb`); nezískaný zámok skončí ako `nil`, teda ako každé iné zlyhanie zápisu. **Priznaný zvyšok:** rad je ÚPLNÁ NÁHRADA — panel
posiela celý objekt a súbor nemá revíziu, takže dve otvorené okná sa nad ním stále prebíjajú „posledný vyhráva". Zámok ich zápisy len SERIALIZUJE; revízia + konfliktová vetva sú
UI kontrakt a register ich vedie ako **R-35**.

**1d/R-11:** `set` má hneď po zámku bránu degradovaného súboru (`degraded_write_blocked?`) — poškodený primár s platnou `.bak` sa číta zo ZÁLOHY, takže zápis by rady prepísal
STARŠÍM obsahom. Odmietnutie končí ako každé iné zlyhanie (`nil`; dvojica `[nil, dôvod]` by rozbila volajúcich a `[false, dôvod]` by bola v Ruby pravdivá), ale KONKRÉTNY dôvod si
panel vezme z **`DimSeries.write_block_reason`** a ukáže ho namiesto všeobecného „disk/práva" — náprava je oprava alebo zmazanie jedného súboru, nie hľadanie problému s právami.

## Knižnica šablón

### templates.rb

(UI od ŠT-3c-1 = **sekcia `tpl` Štúdia**, okno „Šablóny" ZANIKLO) — knižnica šablón (`%APPDATA%\NOXUN\Engine\templates.json` + `.bak`, zápis cez `JsonFileStore`).

**Identita záznamu je DVOJICA `(kind, name)`** (UI-C1a): `kind` = `cabinet` | `board` žije **na úrovni záznamu**, takže dosková „Zástena" a korpusová „Zástena" sú dve rôzne šablóny
a nikdy sa neprepíšu — `find`/`upsert`/`delete` preto dostávajú **oba** údaje. Doskový záznam nesie navyše **redundantne `config['type'] = 'board'`**: starší klient (panel pred
UI-C1) filtruje ponuku podľa `config.type`, takže doskovú šablónu neponúkne ako korpusovú.

Marker súboru `std`: **1** = pred UI-C1a (len korpusové, bez `kind`), **2** = `kind` na zázname + seed 3 doskových šablón (`Diel` 18/800/600 · `Pracovná doska` 38/2600/600 ·
`Zástena` 10/2600/580 — **kanonické polia dosky** `length`/`width`/`thickness`/`grain_direction` podľa STANDARD 8.3), **3** (UI-C1c) = doskové šablóny nesú `config['orientation']`
(seed: `Diel` → `stojaca`, `Pracovná doska` → `leziaca`, `Zástena` → `na_stenu`; slovník je `BoardBuilder::ORIENTATIONS`).

**Kontrakt doskovej šablóny:** `material_id` je v configu **explicitne `nil`**, nie chýbajúci kľúč — **šablóna bez materiálu = vloženie cez UNI mechanizmus (E-03 odomknutá hrúbka),
aby deklarovaná hrúbka VŽDY platila; reálny materiál si používateľ vyberie v karte a hrúbka sa prispôsobí — implementuje C1b.** Bez tohto zapísaného kontraktu by builder dosadil
projektový default a `insert_thickness_for` (autorita reálneho materiálu) by hrúbku šablóny zahodil — Pracovná doska aj Zástena by sa vložili na 18 mm. Migrácia je **lazy pri prvom
`load`**, **STUPŇOVANÁ podľa STARÉHO markera** (`migrate!` si ho prečíta PRED zápisom) a robí sa **JEDNÝM atomickým zápisom pod jedným zámkom**: `old_std < 2` ⇒ doseje doskové
šablóny (už s orientáciou), `old_std < 3` ⇒ `fill_orientations`.

Seed je **markerový, nie obsahový** — viaže sa na prechod `std<2 → 2`, takže sa nikdy neopakuje a zmazanú doskovú šablónu plugin nevráti (existujúcu rovnomennú doskovú šablónu
nikdy neprepíše).

**`fill_orientations` (2 → 3)** doplní kontraktovú orientáciu **len záznamu, ktorý je preukázateľne nedotknutý seed std 2** — musí sedieť **meno AJ odtlačok**
(`length`/`width`/`thickness`, `material_id` explicitne `nil`, `grain_direction: 'length'`); všetko ostatné bez poľa dostane `leziaca` (premenovaný seed aj upravený rovnomenný
záznam — **vedomé obmedzenie**, radšej rovná doska než zle otočená).

**Explicitná orientácia — aj neznáma — ostáva nedotknutá** (rovnaká zásada ako pri `kind`), korpusových šablón sa fill netýka vôbec. `load(migrate: false)` je **čisté čítanie** —
scan katalógu materiálov aj dry-run migrácie ABS bežia v horúcich cestách a nesmú spustiť zápis.

**Forward guard** (vzor `usage_stats`): `std` vyšší než `STD` = súbor z novšej verzie pluginu ⇒ **režim len na čítanie** (`upsert`/`delete`/`touch_used` odmietnu a zalogujú —
volajúci **musí** návratovú hodnotu vetviť, inak ohlási falošný úspech); neznáme top-level kľúče **aj neznáme kľúče záznamu** prežijú každý zápis.

**Explicitný neznámy `kind` sa nikdy nepreklasifikuje** — záznam z novšej verzie (napr. `assembly`) normalizáciu aj zápis prežije nedotknutý, ale žiadny filter `cabinet`/`board` ho
nezachytí, takže sa nikde neponúkne ani neaplikuje (tichý prevod na korpus by dovolil vložiť ho ako skrinku); JS `NXInsert.templateKind` je zrkadlom tohto pravidla.

**Zámok:** celý read-modify-write (`upsert`/`delete` aj lazy migrácia) beží pod **sidecar `flock`om** `templates.json.lock` — dve inštancie SketchUpu si inak mohli čerstvo uloženú
šablónu prepísať stale snapshotom. Zámok je **reentrantný** (verejná operácia ho berie raz, vnútorné kroky `load → ensure_current → migrate!` bežia pod ním — druhý `flock` v tom
istom procese by sa zablokoval sám na sebe) a migrácia používa **dvojitú kontrolu**: rýchly test markera bez zámku, samotný zápis až pod zámkom nad čerstvo prečítaným stavom.

**UI-D2 — PNG náhľad je súbor, nie kľúč záznamu:** schéma sa kvôli nemu **nemenila** (`std` ostáva 3), obrázky žijú v `template_previews\` (modul `template_previews`). `upsert` má
**4. pozičný** parameter `preview` (`:keep` = obrázka sa nedotýkaj · `String` = cesta k capture temp súboru · `nil` = capture zlyhal ⇒ starý PNG **zmazať**); pozičný je zámerne —
`config` sa bežne odovzdáva ako holý hash a Ruby 3 by ho pri kľúčovom parametri zhltol ako keywords. `delete` maže PNG **so záznamom** (jediné miesto, cez ktoré záznam mizne — nie
UI handler). Obrázok sa mení **pod tým istým `flock`om** ako záznam, takže sa dvojica záznam+obrázok nemôže rozísť medzi dvoma inštanciami; **odmietnutý zápis** (forward guard,
chyba disku) sa uloženého PNG **nedotkne** a len upratá nepoužitý temp súbor.

**SMOKE PACK 1** pridal `set_preview(kind, name, tmp)` — jediná cesta, ktorá mení **len obrázok** (ručné „Odfotiť" v okne Šablóny): beží pod tým istým zámkom, `templates.json`
nechá **byte-nezmenený** a keď záznam medzitým zmizol alebo je súbor v režime len na čítanie, vráti `false` a temp zahodí (žiadny osirelý PNG).

**Používa `TemplatePreviews.attach`, NIE `replace`** (Codex #183 P2): obe volajú ten istý `move_into_place`, ale líšia sa tým, čo urobia pri **zlyhaní presunu** — `replace`
(upsert) starý PNG **zmaže**, lebo config sa práve zmenil a obrázok už patrí inému tvaru skrinky; `attach` ho **nechá**, lebo config sa nemenil a doterajší náhľad je stále platný
(neúspešné „Prefotiť" nesmie pripraviť používateľa o to, čo už mal).

**ŠT-3c-1 — SEKCIA `tpl` V ŠTÚDIU (Š18), okno ZANIKLO:** jediné UI knižnice je sekcia; `templates.html`, `js/templates_dialog.js`, `UI::HtmlDialog`, `DLG_KEY`, `ensure_dialog`,
`show`, `register_callbacks` aj `push_state` sú PREČ, modul `TemplatesDialog` ostal ako **serverová autorita** (nepremenúva sa — vzor audit #21) s uzavretým `SECTION_ACTIONS =
tpl_apply · tpl_delete · tpl_capture · tpl_rename · tpl_preview`.

**UKLADANIE novej šablóny sa do sekcie NEPRENIESLO** — jediný vstup ostáva mini-modal Inspectora (`Panel.handle_save_template_as`), lebo má po ruke označenú skrinku; dve
zapisovacie cesty k tomu istému súboru by sa časom rozišli (priznané v PR).

**VÝBER sekcia NESLEDUJE** (audit N27): vetva `TemplatesDialog.on_selection_changed` v `Panel.push_selected` zanikla — žila len kým žil Inspector. Tlačidlá sú preto VŽDY aktívne a
verdikt („nič nie je označené", „iný typ", „označených je viac") dáva SERVER pri kliku (vzor `Panel.capture_preview_for`, pravidlo D-78).

**Doskové šablóny:** sekcia ich ZOBRAZUJE a **prvý raz ich vie aj ZMAZAŤ** (`KINDS = cabinet | board`, kind chodí z klienta ale server ho pustí len z uzavretého zoznamu) — dovtedy
ich nespravovala žiadna cesta; `apply`/`odfotiť` im **nezobrazuje** (nie disabled — vôbec; vedomá odchýlka od mockupu, ktorý kreslí 4 akcie všade) a serverové `kind == cabinet`
guardy ostávajú.

**Mazanie sa potvrdzuje D-15 modálom** (`nx_modal.js`, nový nepovinný `danger: true` = červené potvrdenie podľa UI_DIZAJN) — `UI.messagebox`/`UI.inputbox` v callbacku HtmlDialogu
by zablokovali celý kanál okna (audit N28); text doskovej hovorí, že sa už NIKDY nevráti (knižnica ju sama nedoplní).

**Refresh má DVE cesty:** `apply` mení MODEL ⇒ `Panel.push_selected` + plný push Štúdia `bump: true`; zmena KNIŽNICE (zmazanie, nový náhľad, uloženie z Inspectora) ⇒ **lacné echo
sekcie** `push_library_echo` (`TPL.init`) + `Panel.push_templates`, bez zdvihu generácie — knižnica s kusovníkom nesúvisí. *(Echo sa do 1b-4 volalo `refresh_if_open` a meno KLAMALO
— žiadne „if open" v tele nie je a byť nemôže: server o otvorenej sekcii nevie NIC, guard je od #225 na klientovi. Okenné `StudioDialog.refresh_if_open` si meno drží, tam sa
viditeľnosť okna naozaj testuje.)*

**Echo je STAVOVÉ, kým sekcia nie je otvorená** (review #225 P1): `#secbody` a `#sectools` sú ZDIEĽANÉ uzly celého okna, takže `TPL.init` kreslí len keď `studioActiveSection() ===
'tpl'` — inak by uloženie šablóny z Inspectora prepísalo rozpísaný formulár Rozpočtu (a navigácia by pritom ukazovala Rozpočet). Autoritou aktívnej sekcie je `studio.js`; ostatné
sekcie tento problém nemajú, lebo kreslia do vlastných uzlov, ktoré sú mimo sekcie odpojené. Vstupné body: menu „Šablóny" → `StudioDialog.show(open_section: 'tpl')`, tlačidlo
správy šablón vo vkladacej karte → `openStudio('tpl')`; `open_templates` (panel.rb) aj `openTemplatesDialog` (materials.js) sú preč. Osirotený `preferences_key`
`noxun_engine_templates` v registri používateľa ostáva — zapamätaná veľkosť okna, ktoré už neexistuje (precedens `NoxunEngineProduction`, `noxun_engine_hw_catalog_v1`,
`noxun_engine_rules`).

**ŠT-3c-2 — PREMENOVANIE (`tpl_rename`, ceruzka na dlaždici OBOCH druhov):** mení **identitu** perzistovaného záznamu, preto je celé v `TemplateStore.rename` a nie v UI. Je to
**in-place `map` nad deep-kópiou záznamu**, ktorý mení výhradne `rec['name']` — **nikdy `upsert`**: ten stavia záznam nanovo cez `record()`, takže by zahodil neznáme kľúče záznamu
z novšej verzie a presunul ho **na koniec** zoznamu (dlaždice by sa používateľovi preskupili, hoci premenoval jednu).

**Všetky guardy bežia pod JEDNÝM `with_lock`** (lekcia `save_decor`): `refuse_write` ⇒ `:readonly` → staré meno neexistuje ⇒ `:missing` → nové meno obsadené (rovnaký `kind`) ⇒
`:exists` → `write_list` → **až po úspešnom zápise** presun PNG. Návrat je **symbol** (`:ok · :unchanged · :missing · :exists · :readonly · :failed`) a mapuje sa cez
`res.is_a?(Symbol) ? res : :failed` — `with_lock` pri výnimke vracia `false` a to by prepadlo cez všetky vetvy `case`.

**„Meno sa nezmenilo" je vlastný výsledok `:unchanged` a rozhoduje sa AŽ POD ZÁMKOM, za guardmi** (review #226 NOTE 1): skratka pred zámkom tvrdila „hotovo" aj o šablóne, ktorá
vôbec neexistuje, aj o knižnici v režime len na čítanie — teda presne v situáciách, v ktorých sa premenovať nedá.

**Zlyhanie PNG NEROBÍ z premenovania chybu** (záznam už nové meno má) a starý obrázok sa **nemaže**; handler porovná `TemplatePreviews.rev_for` pred a po a povie pravdu („náhľad sa
nepreniesol — odfoť ho znova"). Pečiatka `TemplateUsage.rename` beží **mimo tohto zámku** (iný súbor, best-effort).

**`delete` dostal ten istý jednoriadkový `find` guard** (N1): mazanie neexistujúcej šablóny dovtedy vracalo `true`, lebo `write_list` úspešne zapísal **nezmenený** zoznam — a UI
hlásilo „Šablóna vymazaná" o niečom, čo tam nebolo (napr. po zmazaní z druhej inštancie); obe akcie majú odteraz vlastnú hlášku a obnovu zoznamu.

**Klient:** ceruzka je **mimo vetvy `if (isCab)`** — doskovú šablónu dnes nepremenuje nič iné; D-15 modal má **jediné pole predvyplnené súčasným menom**, na server ide pod kľúčom
**`new_name`** (`template` znamená v sekcii meno SÚČASNÉ) a **nezatvára sa odoslaním**: zatvorí ho až `TPL.renameSaved()` (`setBusy(false, {clear:true})` + `close`), odmietnutie
príde ako `TPL.renameError(msg,'name')` (`setBusy(false)` + `showErrors`, modal ostáva s rozpísaným menom); **zmiznutá šablóna je tretia odpoveď — `TPL.renameClosed()`** (review
#226 NOTE 3): modal sa zavrie **bez** úspechovej hlášky, lebo meno neexistujúcej šablóny nie je čo opravovať, a rozpísané sa pritom nezabúda (nebol to potvrdený zápis, len zánik
cieľa).

Premenovanie mení KNIŽNICU, nie model: ide teda lacným echom (`after_change` → `TPL.init` + `Panel.push_templates`), **žiadny `start_operation`, žiadny bump generácie a žiadny krok
Späť**.

**Review #226 doplnil tri veci:** (1) po úspešnom premenovaní ide do panela `Panel.push_template_renamed` **pred** echom — vkladacia karta drží zvolenú šablónu **menom**
(`NXInsert.state.template` / `boardTemplate`), takže bez prehodenia by vkladala pod starou, už neplatnou identitou (bez pečiatky použitia) a po prekreslení karty by ticho spadla na
predvolené rozmery; prijímač `NX.renameTemplate` mení **len voľbu**, a to len keď sedí. (2) **Odpoveď servera je viazaná na odoslanie, ktoré ju vyvolalo** — klient drží token
`TPL_REN` (vzniká pri odoslaní, zaniká pri prijatí odpovede **aj pri otvorení ľubovoľného ďalšieho modalu**), lebo kým sa čaká na zámok súboru, používateľ stihne modal zavrieť
Escapom a otvoriť iný — a `renameSaved` by mu ten **cudzí rozpísaný formulár zavrel**. Zahodená odpoveď nie je stratená: hlášku nesie aj status sekcie.

(3) **Mazanie klasifikuje „zmizla" až po návrate zo zámku** — pred-kontrola `find` beží mimo zámku, takže medzi ňou a zamknutým `delete` môže šablónu zmazať druhá inštancia;
`false` sa preto ešte raz overí `find`om a až potom sa hlási novšia schéma/disk (spoločné telo `template_gone`).

### template_usage (modul TemplateUsage, žije v core/templates.rb)

(modul `TemplateUsage`, žije v `core/templates.rb`) — poradie „naposledy použité" pre vkladaciu kartu vo **VLASTNOM** súbore `template_usage.json` (`{ std, seq, entries: {
"kind:name" => poradie } }`). Je to **monotónne počítadlo, nie časová pečiatka** — poradie nezávisí od systémových hodín ani od rozlíšenia času (dve vloženia v tej istej sekunde
majú jasné poradie), `next_seq` je vždy o 1 nad najvyšším známym číslom, takže ručne skrátený súbor poradie nezvráti.

**Vlastný súbor je invariant, nie detail:** súbor šablón musí po vložení zo šablóny ostať **byte-nezmenený** (N11) a použitie je údaj **tohto počítača** — do budúcej zdieľanej
knižnice šablón (D-48) nepatrí. Zápis je read-modify-write pod `flock`om na sidecar zámku a súbor s novšou schémou sa neprepisuje.

**ŠT-3c-2 — `rename(kind, old, new)` PRENÁŠA pečiatku, nepečiatkuje znova:** `stamp` by šablóne pridelil **najvyššie** číslo, teda by ju premenovanie povýšilo na „naposledy
použitú" a preskladalo dlaždice; prenáša sa preto **pôvodné** `seq`, kolízia kľúča (nové meno pečiatku už má) sa rieši `max` a **`seq` sa nebumpuje** — premenovanie nie je
použitie. `stamp` aj `rename` idú cez **jediný privátny mutátor `with_entries`** (privátny naozaj — `private_class_method`, lebo `module_function` inak robí zo všetkého verejnú
modulovú metódu a jediný mutátor by sa dal obísť zvonku; review #226 NOTE 6) (forward guard, `sanitize_entries`, `prune`, zachovanie neznámych kľúčov na jednom mieste — dva
zapisovače by sa časom rozišli a práve forward guard by v tom druhom chýbal); blok vracia `seq` na zápis, alebo `nil` = nezapisovať.

Beh je **mimo zámku šablón** a **best-effort**: zlyhanie pečiatky nikdy nemení výsledok premenovania (šablóna len spadne na koniec poradia).

**Známe obmedzenie (N5):** meno dlhšie než `MAX_KEY_LENGTH` kľúč nedostane, takže pečiatku stráca — pre-existujúce správanie `key_for`. `TemplateStore.touch_used(kind, name)` volá
panel **PO úspešnom vložení a MIMO `model.start_operation`**; jeho zlyhanie **nikdy** nemení výsledok vkladania (len log), po úspechu ide `push_templates`.

### template_previews.rb

(UI-D2, modul `TemplatePreviews`) — **reálne PNG náhľady dlaždíc šablón**. Obrázky žijú ako súbory v `%APPDATA%\NOXUN\Engine\template_previews\` (capture ide cez podpriečinok
`tmp\`), takže schéma `templates.json` sa nemenila.

**Sémantika je vedomé rozhodnutie:** náhľad je **kontextová fotografia aktuálneho pohľadu dorámovaná na skrinku** (`view.zoom(ent)`), nie izolovaný render — izolovaný by vyžadoval
skrývanie zvyšku modelu, čiže zápisy a undo kroky, pričom šablóna sa typicky ukladá hneď po postavení skrinky na obrazovke; zákryt inou geometriou alebo rez rovinou = nedokonalý
náhľad, akceptované (zapísané aj v `SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`).

**Kamera:** pred `write_image` sa robí **nezávislá kópia CELEJ kamery** (eye/target/up + `perspective?` + `fov`/`height` + `aspect_ratio`) a obnovuje sa v `ensure` — aj keď
`write_image` vráti `false`, aj pri výnimke; `write_image` prepisuje **aj `aspect_ratio`**, takže obnova samotného eye/target/up nestačí, a `fov` vs. `height` sa obnovuje podľa
režimu. Celý capture je **čistý pohľad**: žiadna `model.start_operation`, žiadny zápis, **žiadny undo krok** (zásada D-103/D-104/D-105). Render je štandardný 240×160 (3:2,
`antialias`) — **nie** `source: :framebuffer` (nepodporuje vlastné rozmery) — a jeho **Boolean** návratová hodnota sa kontroluje explicitne (absencia výnimky nie je dôkaz úspechu).

**Identita súboru:** `<kind>-<slug>-<sha1_16>.png`, kde **autorita je hash** (prvých 16 hex `SHA1("kind:name")`) a `slug` (whitelist `[a-z0-9-]`, strop 40 znakov, vzor
`VepoExport.slug`) je len čitateľnosť — žiadne meno šablóny teda nemôže uniknúť z priečinka ani zraziť dve šablóny do jedného súboru; výsledná cesta má navyše **containment check**
(`expand_path` musí ležať v `dir`).

**Transport do panela je dvojkanálový:** `template_list(previews: true)` pripája **transientné `preview_rev`** (odtlačok mtime+veľkosť, `nil` = bez náhľadu) cez `t.merge` — presne
ako `used_seq`, takže sa do `templates.json` nikdy nezapíše (neznáme kľúče záznamu by inak zápis prežili a schéma by sa ticho rozšírila); samotné PNG si panel vypýta **osobitne**
(`nx_template_preview` → `Panel.push_template_preview` → data URI) **raz na revíziu**, server pritom overí **PNG magic bytes + tvrdý limit 64 kB**. Zápis a mazanie PNG patria **do
`TemplateStore`** (pod jeho zámkom), nie do UI. Seed doskových šablón náhľady nemá a board save z UI neexistuje — mimo rozsahu.

**SMOKE PACK 1 (6A) pridal RUČNÉ odfotenie k UŽ ULOŽENEJ šablóne** (Michal 20.8.: staré šablóny fotku nemajú a jediná cesta k nej bola uložiť šablónu nanovo, čím sa prepísal aj jej
config). Cesta: sekcia `tpl` Štúdia → `tpl_capture` → `TemplatesDialog.handle_capture` → **`Panel.capture_preview_for(kind, name)`** (`ui/panel/actions_templates.rb`) →
`TemplatePreviews.capture` → **`TemplateStore.set_preview`**. `set_preview` je jediná cesta, ktorá mení **VÝHRADNE obrázok** — beží pod tým istým sidecar zámkom, záznam nechá
byte-nezmenený a šablóne, ktorá medzitým zmizla, osirelý PNG nedá (temp sa zahodí).

Guardy sú **serverové**: existujúca šablóna druhu `cabinet` + **PRÁVE JEDNA priamo označená** NOXUN skrinka (`Panel.selected_cabinets` berie len `Store.kind == 'cabinet'` zo
selection — nie `find_cabinet`, ktorý by dielec dorozriešil na jeho skrinku a vybral by za používateľa). `capture_preview_for` vracia `[ok, správa]`, hlášku vypisuje VOLAJÚCE UI
(panel aj sekcia `tpl` majú vlastný status riadok) — jedna logika, dva statusové kanály.

**Prečo v správe šablón (dnes sekcia `tpl` Štúdia, do ŠT-3c-1 okno) a nie ako ikona na dlaždici panela** (pôvodné zadanie): dlaždice žijú vo **vkladacej karte**, ktorá je viditeľná
výhradne keď **nie je označené nič** (`clearSelected` → `setUiMode('insert')`, `body.mode-cab #insertCard { display: none }`) — kamera by tam nemala ako nájsť skrinku, ktorú má
odfotiť, a bola by to trvalo mŕtva ikona. V správe šablón výber v modeli a zoznam šablón existujú súčasne (rovnako to funguje pri „Použiť"); od ŠT-3c-1 to platí pre sekciu `tpl`
Štúdia. Okno preto od SMOKE PACKU 1 pýta `template_list(kind: 'cabinet', previews: true)` — podľa `preview_rev` rozlíši **„Odfotiť" vs. „Prefotiť"**; panel `previews: true`
používal už od UI-D2. In-SU dôkaz: sekcia `run_smoke1` (guardy výberu, PNG vznikne, záznam sa nezmení, kamera obnovená, **žiadny undo krok**).

**Presun temp súboru na finálne meno (`move_into_place`) nesmie klamať** (sweep review): `FileUtils.mv(..., force: true)` neznamená „prepíš", ale „chyby **ignoruj**" — zlyhanie
presunu tak prešlo ticho a metóda vrátila `true`, takže `replace` nechal v configu nový tvar skrinky so **starým** obrázkom, `attach` potvrdil prefotenie, ktoré sa nestalo, a temp
súbor ostal visieť v `%TEMP%`. Presun teraz chybu **nesie von** a výsledok sa navyše overí na disku — a to **cez zdroj** (`tmp` musí zmiznúť): keď na cieli starý náhľad už je,
samotná existencia cieľového súboru o novom presune nehovorí nič. Rozdiel oboch ciest ostáva zámerný: `replace` (config sa zmenil) starý PNG **zmaže**, `attach` (mení sa výhradne
obrázok) ho **nechá** — a obe zahodia nepoužitý temp.

**Samotný presun ide od v0.7.25 cez STAGING (`stage_then_rename`, Codex #186 P2)** — priznať chybu nestačilo, lebo cieľ mohol byť poškodený už v okamihu, keď chyba vznikla:
`FileUtils.mv` medzi **zväzkami** (presmerovaný `%TEMP%` vs. `%APPDATA%`) nie je rename, ale **streamovaná kópia priamo do cieľového súboru**, takže došlé miesto alebo I/O chyba v
polovici starý PNG **oreže** a „nedeštruktívny" `attach` pripraví používateľa aj o náhľad, ktorý mal. Nový PNG sa preto skompletizuje ako **`<cieľ>.new` v tom istom priečinku**,
overí (`valid_file?` = PNG magic + limit, plus dôkaz že `tmp` zmizol) a až potom sa premenuje — **`File.rename` v rámci jedného priečinka je atomický**, takže cieľ je vždy buď celý
starý, alebo celý nový.

Pred štartom sa `.new` maže (zvyšok po predchádzajúcom páde) a `rescue` ho upratuje aj pri chybe a **znovu vyhodí** — obe cesty tak ďalej rozhodujú o osude starého PNG samy, len už
nad **nedotknutým** súborom.

**ŠT-3c-1 — sekcia `tpl` má VLASTNÝ PNG kanál:** panelový `Panel.push_template_preview` sa použiť NEDAL — má guard `dialog_alive?` INSPECTORA a odpoveď posiela prijímaču panela
(`NX.setTemplatePreview`), takže v Štúdiu by náhľady chodili len kým je otvorený Inspector. Sekcia preto má vlastný callback `tpl_preview`, vlastný prijímač `TPL.setPreview` a
vlastnú cache per revízia v klientovi (pýta sa RAZ na `preview_rev`, **záporná odpoveď sa cachuje tiež** — inak by sa sekcia pýtala donekonečna).
Limit **64 kB + PNG magic bytes** drží naďalej `TemplatePreviews.data_uri` — obchádzať ani duplikovať sa NESMIE.

**Kanál je od 1b-4 DÁVKOVANÝ a má RETRY** (rozhoduje čisté jadro `tplPreviewPlan(data, cache, asked, now, limit)`, Node testy):
- **`TPL_ASKED` drží ČAS odoslania, nie `true`.** Jednosmerná značka znamenala, že **stratená odpoveď** (výnimka v handleri, okno zaniknuté v okamihu odpovede) nechala dlaždicu
  **navždy na schéme** — po `TPL_ASK_TIMEOUT_MS` (8 s) sa dotaz smie zopakovať. Značka vzniká **výhradne keď dotaz naozaj odišiel**: bez mosta do Ruby by revízia ostala „vypýtaná"
  a nepožiadal by o ňu už nikto (tá istá pasca je pomenovaná aj v panelovom `refreshTemplatePreviews`).
- **Najviac `TPL_ASK_BATCH` (4) dotazov na prechod**, ďalšia dávka o `TPL_ASK_GAP_MS`. Data URI má strop 64 kB, takže knižnica s 20 šablónami znamenala **~1,3 MB cez most v jednom
  nádychu** pri vstupe do sekcie. Rozmery ani rozloženie sa tým nemenia (obrázok aj schéma zdieľajú ten istý box — UI-D2), ale piata a ďalšia dlaždica drží schému o niečo dlhšie a
  fotka sa doplní o chvíľu neskôr; je to vedomá výmena.
- **Časovač dávky sa pri ODCHODE zo sekcie zastaví** (review #241 P3-1): callback `tplScheduleAsk` sa pýta `tplIsActive()` a mimo sekcie **nič neposiela a reťaz neobnovuje** —
  inak by pri veľkej knižnici bežala cudzia prevádzka na moste popri práci používateľa v inej sekcii. Návrat do sekcie dávkovanie obnoví normálnou cestou (`tplRenderBody` →
  `tplRequestPreviews`); rozpracované dotazy medzitým vypršia timeoutom, takže sa o ne sekcia prihlási znova.
- **Odpoveď sa nasadí LEN na dlaždicu s TOU ISTOU revíziou** — mapa `TPL_DOM` (identita → uzol) nesie od 1b-4 aj `rev`. Kým sa čakalo na disk, mohla prísť nová knižnica
  (prefotená šablóna = nová `preview_rev`) a starý obrázok by ukazoval tvar, ktorý šablóna už nepostaví.

**Payload sekcie je OREZANÝ NA TVAR DLAŽDICE (1b-4):** `tpl_payload` beží v **KAŽDOM plnom pushi** okna (každý prepočet kusovníka, každý zápis rozpočtu), a dlaždica z celého
záznamu kreslí len meno, typ, tri rozmery a náhľad. `tile_row` preto prepustí **uzavretý zoznam kľúčov** `TILE_CONFIG_KEYS` (`type · width · height · depth`) a zvyšok configu
(`zone_tree`, `fronts`, `hardware_sets`, `hardware_set_defs`, materiály — jeho najväčšia časť) do okna **nejde**; celý záznam si vyzdvihne až akcia, ktorá ho naozaj potrebuje
(`handle_apply` číta zo skladu, nie z payloadu). Zoznam sa pýta s **`usage: false`** — poradie „Naposledy použité" kreslí len panel, takže sekcia nepotrebuje ani čítanie
`TemplateUsage`. **Podmieniť payload otvorenou sekciou sa NEDÁ** (server o otvorenej sekcii nevie a `push_state` posiela všetky sekcie naraz), orezanie je preto jediná cesta, ktorá
nezavedie druhú pravdu.

**ŠT-3c-2 — `rename(kind, old, new)`:** meno je súčasťou identity súboru (`slug` + hash z „kind:name"), takže premenovanie záznamu bez presunu obrázka by šablónu pripravilo o fotku
a novú by sa dalo získať už len ručným prefotením.

**Nerobí sa re-capture** — obrázok je ten istý, mení sa len meno súboru: `rm_f("<cieľ>.new")` (zvyšok po padnutom `stage_then_rename`) → `rm_f(cieľ)` (sirota po šablóne, ktorá už
neexistuje) → **`File.rename`** (v rámci jedného priečinka atomický) → overenie `File.file?(cieľ)`. `FileUtils.mv(force: true)` sa **nepoužíva zámerne** (ignoroval by chybu a mohol
nechať cieľ v polovičnom stave), containment oboch ciest drží `path_for` a zdroj bez obrázka je `false` bez akéhokoľvek zásahu.

**Cieľ sa čistí VŽDY — aj keď zdroj náhľad nemá** (review #226 P2): identita súboru je odvodená od mena, takže po zmazanej šablóne toho mena (alebo po prerušenom zápise) môže na
cieli ležať cudzí PNG; keby sa `rm_f` robilo až za kontrolou zdroja, premenovaná šablóna **bez** fotky by tú sirotu zdedila a `rev_for` by ju na novej identite našiel ako jej
vlastnú. Volá sa **z `TemplateStore.rename` pod jeho zámkom, až po úspešnom zápise zoznamu**.

## Bez vlastného odseku

### debug.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Read-only dump stavu enginu pre bugcatch (`Noxun::Engine::Debug.report`); popis použitia je v `CLAUDE.md`, sekcia Testovanie.
