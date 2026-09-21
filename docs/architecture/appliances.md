# Spotrebiče — katalóg modelov

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Katalóg konkrétnych modelov spotrebičov tohto počítača (rozmery z listov výrobcov, odkazy, prílohy) a snapshot, ktorým si ich zákazka
odkopíruje k sebe. Väzba do zákazky a slot umývačky **už fungujú** (S1-A2 katalóg → S1-E slot → S1-B1 väzba → S1-B2 UI); kontrolné telo chladničky a
očakávania zo šablón prídu v S1-F a S1-C. **UI je sekcia `appl` v Štúdiu** — dva pohľady: **Katalóg** (modely tohto PC) a **V zákazke** (čo je v tejto
zákazke a kde).

### UI sekcie

**Jediné UI katalógu je sekcia `appl` okna ŠTÚDIO** (S1-A2) a jediný vstup do tohto modulu je `ui/appliance_dialog.rb` — kontrakt sekcie, payloady, lazy kanál miniatúr
a pravidlá echa sú v [ui-lifecycle.md](ui-lifecycle.md) (odseky `appliance_dialog.rb` a „Sekcia SPOTREBIČE v Štúdiu"). Pre tento modul z toho platia tri veci:

- **UI nikdy neobchádza pravidlá katalógu.** Validáciu, `rev` guard, tombstone, prílohy aj seed rieši výhradne `appliance_catalog.rb`; sekcia jeho statusy iba prekladá
  na vety a chyby posiela k poľu modalu. `field` z `[:invalid, {message:, field:}]` je **cesta** (`dims.niche.width_min`) a presne tak sa volá aj kľúč poľa vo formulári,
  takže medzi katalógom a modalom neexistuje prekladová tabuľka, ktorá by mohla zaostať.
- **Zmena katalógu NEDVÍHA generáciu okna Štúdio.** Katalóg spotrebičov nevstupuje do žiadneho čísla zákazky (zákazka si drží **snapshot**, nie odkaz na
  živý záznam), takže zápis posiela len echo sekcie (`NX.applTree` + `NX.applCard`), nie plný `push_state`. Platí to aj po S1-B2: pohľad „V zákazke“
  chodí **plným pushom** (patrí dokumentu) a echo katalógu ho nikdy neprepisuje.
- **Prílohy do UI chodia ako `data:` URI, nikdy ako cesta.** CEF súbory zo systému čítať nesmie; obrázok sa posiela zmenšený (`Sketchup::ImageRep`, max 96 px) a len na
  vyžiadanie karty, PDF vôbec — otvára ho `open_attachment` cez systémový prehliadač. `attachment_path_for` tak ostáva jediným resolverom ciest pre živý záznam
  aj pre zákazkový snapshot.

### Slot umývačky (S1-E)

**Prvý spotrebič, ktorý má v modeli vlastnú geometriu.** Slot je **nový typ korpusu** `dishwasher` (`CabinetBuilder`, detail v
[construction.md](construction.md)) a v tomto module figuruje preto, že je to **doménová referencia**: to, čo v modeli stojí, si kupuje zákazník a plugin
to nevyrába ani neobjednáva.

- **Čo slot vyrába:** jediný dielec — **čelo** (rola `false_front`, kľúč `front:F1/blind`), s úchytkou, materiálom a ABS ako každé iné čelo.
  Kusovník, VEPO, nákup aj rozpočet z neho vidia **jeden riadok**.
- **Čo slot NEvyrába:** telo umývačky. Kreslí sa ako `kind: 'reference'` · `role: 'appliance_body'` · `production_class: 'reference'` ·
  `manufactured: false` (STANDARD §8.1) z **dvoch boxov** — telo podľa triedy a pod ním **fixná základňa 200 mm**, odsadená 50 mm spredu a 20 mm
  do strán (zóna nôh a soklu spotrebiča). Telo sa **nikdy nedeformuje** podľa slotu; keď je širšie, trčí a Kontrola to prizná.
- **Generické rozmery tela** (`Construction::DW_CLASSES`): trieda **600** → 598 × 555, telo 820 · trieda **450** → 448 × 550, telo 815. Je to
  **jediná tabuľka** pre builder, zber aj náhľad (JS zrkadlo `PV_DW_BODY`) — a platí, **kým slot nemá priradený model**; payload to priznáva textom
  „generické 60“.
- **S1-B2: telo z PRIRADENÉHO MODELU.** Keď slot nesie väzbu na umývačku (`appliance_refs[]` kategórie `dishwasher` s blokom `body`), šírku a hĺbku tela
  určuje **katalógový list**, nie trieda; **výšku určuje vždy používateľ** (`dw_body_height` — nastaviteľné nohy sú rozsah, nie jedno číslo). Vyberá to
  **jedna funkcia pre celý engine — `Construction.dw_body_dims(cfg)`** (`{w:, d:, label:, source: 'generic'|'catalog', item_id:}`), ktorú volajú
  **všetci, čo o tele niečo tvrdia**: builder (`dw_body_reference` → referencia so `source: 'catalog'` a `item_id` v configu referencie), Inspector
  (`Panel.slot_payload` → „448 × 820 × 550 · Bosch SPV6EMX05E“, rozsah výšky tela z listu ako hint pri poli „Telo V“ a verdikt triedy — `class_state` má **tri**
  hodnoty `ok · mismatch · unknown`, lebo model bez triedy v liste sa nesmie zafarbiť nazeleno: „nevieme“ nie je „sedí“, presne ako pri `Validation`) aj Kontrola
  (`Bom.appliance_slot_record` → `dw_body_fit` meria telo, ktoré v slote **naozaj stojí**). Druhá kópia toho výberu by znamenala, že model ukazuje jedno
  telo a semafor kontroluje iné. Zmena aj odpojenie väzby prestavia slot v **tej istej** operácii (S1-B1), takže je to jeden krok Späť.
- **Kľúče väzby rezervuje `CONFIG_SCHEMA` 16** (skrinka; doska cez `BOARD_CONFIG_SCHEMA` 2) a **napĺňajú ich S1-B/F/C bez ďalšieho bumpu**. Kľúče
  prežijú prestavbu, materiály aj absorpciu scale; väzbu na **konkrétny** spotrebič zahodí jediný helper `CabinetBuilder.strip_appliance_refs!`
  v troch kopírovacích vstupoch (natívna kópia, kópia nástrojom, „Vložiť kópiu") — kópia sa správa ako „očakáva", ale nevlastní ten istý kus.
- **Kontroly slotu sú PRESNE DVE** (rozhodnutie Michal 20.9.2026), obe ORANGE a **bez exportnej brány**: `dw_body_fit` (telo sa nezmestí do šírky
  slotu) a `dw_height_fit` (**nastavená** výška tela > výška linky). Výška čela, jeho presah nad telo, sokel ani hmotnosť sa **nekontrolujú**.
  Detail v [outputs.md](outputs.md).
- **Šablóny:** `TemplateStore` STD 5 seeduje **„Umývačka 60"** a **„Umývačka 45"** — korpusové záznamy s `config['config_schema']`, bez ktorého by
  starší plugin typ nepoznal a `norm_type` by mu ho sklopil na `lower` (zo slotu by vznikol plný korpus). Detail v
  [model-a-identita.md](model-a-identita.md).

### Zákazka — UI (S1-B2)

**Spotrebič zákazky je vidieť na TROCH miestach a všetky tri kreslia to isté z toho istého zdroja.** Kontrakt každého z nich (payloady, akcie, echo) je
v [ui-lifecycle.md](ui-lifecycle.md); sem patrí to, čo z toho platí pre doménu:

- **Štúdio → Spotrebiče → „V zákazke“** = celá zákazka v tabuľke (kategória · model · vlastník · Kontrola · cena · akcie), vrátane riadkov, ktoré
  položku ešte **nemajú** („nevybraný“ pre kus s očakávaním) a ktoré **stratili vlastníka** („vlastník zmizol“). Skladá ju server ako **projekciu už
  hotového zberu, rozpočtu a kontroly** toho istého pushu — žiadny druhý sken modelu a žiadne číslo, ktoré by počítal niekto druhý.
- **Inspector — riadok „Spotrebič“** pri skrinke, slote aj doske: jeden riadok per viazaný model + riadok „očakáva“. Je to **jediné miesto, kde sa
  spotrebič priraďuje z modelu** (výber zo spotrebičov zákazky danej kategórie); ponuka je filtrovaná podľa niky, ale **filter nie je brána**.
- **Rozpočet → „Spotrebiče a vybavenie“** ostáva miestom, kde spotrebič **stojí peniaze** (cena, „dodáva zákazník“, do SPOLU len s prepínačom).

**JEDEN TRANSAKČNÝ VSTUP, JEDEN KANÁL.** Všetky zápisy (pridať · zmeniť model · presunúť · odpojiť · zmazať) idú cez `ApplianceBinding.apply!` a do neho
sa chodí **jednou cestou** — `budget_mutate` → `ProductionCore.apply_budget_op`. Sekcia Spotrebiče **vlastnú zápisovú akciu nemá** (jej jediná akcia
navyše, `appl_job_select`, len označuje vlastníka v modeli) a panel dodáva iba to, čo jadro nevie: **ktorá entita je označená**
([actions_appliance.rb](ui-lifecycle.md#actions_appliancerb)). Preto má každá zmena **jeden krok Späť** a rovnaké guardy bez ohľadu na to, odkiaľ prišla.

**Čo zákazka o modeli vie, vie zo SNAPSHOTU.** Názov, rozmery, odkaz na obchod aj technický list v pohľade „V zákazke“ sú z kópie uloženej pri väzbe —
zmena či vyradenie záznamu v katalógu nimi nepohne (a vyradený model sa **nepriradí**: `snapshot_for` vráti `:deleted`).

### Očakávania (`appliance_expects[]`, S1-C)

**Očakávanie je vyhlásenie „sem patrí rúra“ — nie väzba.** Nekreslí nič, nič nestojí a nevie o konkrétnom kuse; jeho jediný dôsledok je **ORANGE
`appliance_missing`** v Kontrole a riadok „nevybraný“ v pohľade „V zákazke“, kým spotrebič nedostane. Práve preto sa dá nastaviť aj na skrinke, v ktorej
ešte nič nestojí — návrh ide ďalej, len sa nezabudne.

- **JEDNA REPREZENTÁCIA: `config['appliance_expects']`** (zoznam kanonických kódov kategórií). **Aj šablóna ich nesie tam** — záznam šablóny žiadny
  vlastný kľúč nemá, takže `TemplateStore::STD` ostáva **5** a knižnica sa staršiemu pluginu nezamyká pre zápis (starší plugin od S1-E, teda od schémy 16,
  očakávania číta aj vkladá správne). Dve reprezentácie by znamenali dve pravdy, ktoré sa pri každom vklade musia zladiť.
- **MATICA je tá istá ako pri väzbe** (`ApplianceBinding::OWNER_MATRIX`, odvodzuje ju `expectable_categories(kind)`): skrinka `fridge|oven|microwave`,
  doska `hob|sink`, **slot vždy presne `['dishwasher']`**, `hood` a `other` sa očakávať nedajú vôbec (nemajú fyzického vlastníka). Očakávať sa nesmie to,
  čo sa k tomu istému kusu nedá ani priradiť — inak by Kontrola žiadala niečo, čo sa nedá splniť. Slotu ho **dosadzuje builder** (implicitne, kľúč
  v configu ani v seed šablónach nie je), takže stará aj nová slotová šablóna hovoria to isté.
- **DÔKAZ SPLNENIA je ten istý obojsmerný dôkaz ako `bound`** (`ApplianceBinding.ref_matches?`): kategória je splnená len vtedy, keď existuje **položka
  zákazky s vlastníkom = táto entita** A entita nesie jej `item_id` v `appliance_refs[]`. Ani recyklované ID vlastníka, ani osirelý záznam v refs po
  zmazanej položke dôkazom nie je — oboje by očakávanie ticho „splnilo“ a semafor by mlčal. Zbiera to `Bom.appliance_expected_records`
  (`state: 'expected_missing'`) v **tom istom** prechode skriniek, žiadny druhý sken.
- **NÁLEZ JE PER NESPLNENÚ KATEGÓRIU:** `stable_key = "appliance|<owner_id>|missing|<kategória>"`, takže skrinka s rúrou aj mikrovlnkou má **dva** riadky
  — sú to dve samostatné veci na opravu. Klik mieri na **vlastníka** (`owner_id` + `owner_pid`): na rozdiel od siroty ho poznáme, záznam vznikol z tej
  entity, ktorá v modeli stojí. Nález **neblokuje export** (spotrebič sa nevyrába).
- **ZÁPIS je CONFIG-ONLY a má vlastnú akciu `set_appliance_expects`** (nie `ApplianceBinding.apply!` — žiadna položka zákazky sa nemení).
  `CabinetBuilder.write_config_keys!` / `BoardBuilder.write_config_keys!` zachovajú celý config a bežia v **jednej** operácii pod `guarded` = jeden krok Späť,
  **bez prestavby**. **Marker `config_schema` sa pritom NEPOSÚVA** (Codex #385 kolo 1, P1): je to proveniencia STAVBY, ktorú čítajú stale guardy zásuviek, závesov
  a výklopov — tiché posunutie by zhaslo RED nálezy aj blokáciu exportov. Kus na **staršej schéme** sa preto odmietne ešte pred operáciou („najprv ju prestav,
  potom nastav očakávanie") — schému migruje výhradne prestavba plným plánom. Guardy a poradie sú v [ui-lifecycle.md](ui-lifecycle.md) (`actions_appliance.rb`).
- **VIAZANÚ kategóriu sa odstrániť nedá** — najprv odpoj spotrebič. Bránou je server a rozhoduje **ten istý** dôkaz, takže osirelý záznam očakávanie
  **nezamkne** (inak by ho po zmazanej položke nikto nikdy nedostal preč). **Zámok sa pritom týka LEN očakávaní, ktoré na kuse naozaj sú** (Codex #385 kolo 2):
  priradený spotrebič a očakávanie sú **dve nezávislé veci** — skrinka môže mať viazanú rúru bez toho, aby ju kedy „očakávala". Rozdiel sa preto počíta
  z prieniku **viazané ∩ dnes uložené** mínus nový zoznam; kým sa porovnávala celá väzba, taká skrinka nemohla pridať očakávanie mikrovlnky (nový zoznam
  `['microwave']` sa tváril ako odstránenie rúry). Ponuka voľby hovorí to isté: viazaná, ale neočakávaná kategória sa ponúka ako **„+"** a zamknuté je len
  `del:` pri kategórii, ktorá v `appliance_expects[]` už je.
- **ŠABLÓNY:** `Panel.template_config_from` očakávania prenáša a `appliance_refs[]` **nikdy**; vloženie ich berie zo **ULOŽENÉHO záznamu**
  (`apply_template_slot_fields!`, E7), nie z CEF payloadu, a **deklarovaná šablóna, ktorá medzitým zmizla, vklad odmietne** (inak by vznikla iná skrinka,
  než si používateľ vybral). `TemplatesDialog.merge_template` (aplikovanie na existujúcu skrinku) **zjednocuje** očakávania cieľa a šablóny a väzby cieľa
  **zachováva** — prepis by ticho zahodil to, na čo Kontrola upozorňuje, a odpájanie by bola strata dát. Kópia skrinky očakávania **ponecháva** (E4).

### appliance_catalog.rb

**Tretí per-PC katalóg** (S1-A1) vedľa materiálov a kovania: `%APPDATA%\NOXUN\Engine\appliances.json` cez `JsonFileStore` (atomický zápis, `.bak`,
sekundová cache) a **vlastný sidecar zámok** `appliances.json.lock`. Zámok je reentrantný (`with_lock`, vzor `TemplateStore`) a **nikdy sa nevnára do
iného katalógového zámku** — poradie zámkov je deadlock, preto má každý katalóg svoj. **`flock`, ktoré vráti `false`** (filesystem bez podpory zámkov,
presmerovaný sieťový share), zámok NEZNAMENÁ: kritická sekcia sa nespustí a mutácia skončí `[:locked, …]` — inak by dve inštancie SketchUpu písali
do katalógu naraz. Cesta ide cez `Materials.dir`; `test_dir_override` (iba testy)
presmeruje JSON aj prílohy do izolovaného priečinka a in-SketchUp sekcia ho vo `ensure` vždy vracia na `nil`.

**Záznam.** Identita = serverové UUID `id`. `category` je z uzavretej sady `CATEGORIES` (`fridge oven microwave dishwasher hob sink hood other`) —
sú to **kanonické kódy pre celý engine** (S1-B na ne migruje slovenské kódy rozpočtu) a `CATEGORY_LABELS` je jediný zdroj SK popiskov (guard test stráži
paritu, neznámy kód sa neprekladá). Ďalej `manufacturer`, `name`, `shop_urls[]`, `sheet_urls[]` (http/https, max 20 × 500 znakov), `note`, `dims`,
`derived[]`, `attachments[]`, `seed`, `created_at`, `updated_at`, `deleted_at`. **`category` sa nastavuje LEN pri `create!`** — patch s kategóriou je
`:invalid`, lebo zmenou kategórie by sa zmenil význam polí v `dims` a v zázname by ostali čísla, ktoré ho už nevalidujú.

**`dims` = štyri bloky** (jazyk listov výrobcov): `body` (telo) · `niche` (nika, `*_min`/`*_max`) · `front` (čelo, presahy alebo výrez — obsah je
**per kategória**) · `install` (montáž: systém dverí, strana pántu, trieda umývačky, sokel, rozsah výšky tela). **Každé pole je voliteľné a chýbajúci
kľúč znamená „list to nekótuje"** — nikdy sa nedosadzuje default a `nil` sa neukladá. Rúra/mikro nesú presah čela **spolu s referenciou**
(`overhang_ref` = `body` | `niche`), pretože Whirlpool kótuje presah voči telu a Bosch voči nike; druhú referenciu si engine dopočíta len vtedy, keď
pozná telo aj niku. Validácia: mm Float 0–5000 (kg 0–100), enumy, `*_min ≤ *_max` (plus dvojica `cutout_depth`/`cutout_depth_max`, ktorú výrobca kótuje
inak). **Kľúče mimo whitelistu kategórie — aj celé neznáme bloky — sa zachovajú, ale nevalidujú** (dopredná kompatibilita) — a to **výhradne tie, ktoré už
sú v uloženom zázname**: kľúč, ktorý prinesie vstup klienta a nepozná ho ani whitelist kategórie, ani súbor, je `:invalid` s cestou poľa. Bez toho by
preklep vo formulári (`cutout_dept`) skončil ako „uložené" a číslo by ticho zmizlo. Explicitné `null` **maže**: nad poľom kľúč, nad blokom celý blok
a nad `dims` celé rozmery. `derived[]` menuje cesty polí, ktorých hodnota je odvodená, nie z listu (napr. `body.width` pri Bosch BFL7221B1); cesta sa
overuje **proti schéme danej kategórie** (blok → pole → prípadne pole vnútri `furniture_doors`), takže `body.wdith` ani pole cudzej kategórie neprejde.
Schéma, nie aktuálny obsah `dims` — inak by výsledok závisel od poradia patchu.

**`rev` je odtlačok obsahu, nie počítadlo** — `Digest::SHA1` uloženého záznamu, prvých 12 hex znakov. Do súboru sa **neukladá**; počíta sa pri čítaní
a vracia v `list`/`find`/`search` aj vo výsledku každej mutácie. Po obnove z `.bak` sa tak revízia pre iný obsah nezopakuje (počítadlo by to nezaručilo).
**Každá mutácia vyžaduje `rev:`** (`patch!`, `delete!`, `restore!`, `attach!`, `set_thumbnail!`, `remove_attachment!`) a server ho za klienta **nikdy
nedosadí** — prázdna alebo stará revízia je `:conflict` a nič sa nezapíše. Mutácia beží pod zámkom, invaliduje cache, prečíta **čerstvý** dokument
a až potom zapisuje.

**Stav katalógu — `assess!`** (`:ok` | `:read_only` | `:degraded`): chýba primár aj `.bak` = prvá inštalácia → seed · chýba primár, `.bak` je = **nie je**
prvá inštalácia (číta sa záloha, žiadny seed, prvý zápis primár obnoví) · poškodený primár + platná `.bak` = `:degraded` (číta sa záloha, **zápisy stoja**,
inak by prepísali primár obsahom spred poškodenia) · poškodený primár bez zálohy, cudzí tvar, chýbajúci alebo nečíselný `std`, **`std` > `STD` (forward
guard)**, nečitateľný záznam a duplicitné identity = `:read_only` s dôvodom.

**Uložený záznam sa posudzuje TÝM ISTÝM validátorom ako zápis** (`stored_record_issue` volá tie isté funkcie ako `build_record` a `attach!`), takže sa
čítacia a zápisová cesta nemôžu rozísť: identita · **`category` z uzavretej sady** (bez známej kategórie niet proti čomu validovať `dims` ani `derived` —
všetko by prepadlo ako „dopredne kompatibilné") · položky `attachments[]` (Hash, `id`, `name`, `kind` z enumu, `file` ako jediný segment a **prípona podľa
druhu** — uložený náhľad nad PDF neprejde rovnako ako pri `attach!`) · **`derived[]` vždy, aj keď záznam nemá `dims`** · **`dims` validáciou známych polí**
(ručná úprava `"width": "oops"`, `min > max`, neznámy enum — dôvod nesie **cestu poľa**). Neznáme kľúče ostávajú dopredne kompatibilné: prenesú sa bez
interpretácie a **ani dvojice `*_min`/`*_max` sa nad nimi nekontrolujú** — `foo_min`/`foo_max` z novšej implementácie môže znamenať čokoľvek a jeden taký
pár by inak zhodil celý katalóg do read-only a zablokoval aj nesúvisiaci patch. **Záloha sa v degradovanom stave posudzuje tou istou maticou ako primár** — `.bak`, ktorá sa síce parsuje, ale je z novšej verzie
alebo nečitateľná, nie je „čítaj zálohu, zápisy stoja", ale `:read_only` (nie je z čoho čítať). **Zlyhaný prvý seed** (nezapisovateľný
`%APPDATA%`, plný disk) je tiež `:read_only` — prázdny „zdravý" katalóg by pri prvom zápise vznikol **bez deviatich modelov** a marker `seed_version` by
ich už nikdy nedosial. Tá istá kontrola (`stored_document_issue`) beží nad čerstvým dokumentom
**pod zámkom pred každým zápisom** — cachovaný `:ok` nie je dôkazom aktuálneho stavu súboru; stav `:read_only` naopak zastaví mutáciu **aj keď súbor
neexistuje**. A keď pod zámkom zmizne **primár aj `.bak`** (upratovanie `%APPDATA%`, sync, obnova), mutácia najprv spustí **cestu prvej inštalácie** a až
nad naseedovaným dokumentom zapíše svoju zmenu — inak by katalóg vznikol prázdny so stampnutým `seed_version` a deväť modelov by sa už nikdy nedosialo.

**Založenie pri štarte.** Katalóg posudzuje (a nad čistou inštaláciou zakladá) už boot blok `main.rb` — vlastný chránený `begin/rescue` vedľa
`Materials.boot_cutover!`, takže poškodený alebo nezapisovateľný katalóg nikdy nezhodí menu, toolbar ani observer. Bez toho by `appliances.json`
vznikol až pri prvom otvorení sekcie Štúdia (S1-A2).

**Tombstone.** `delete!` zapíše `deleted_at` a záznam ostáva v súbore: zákazka, ktorá model použila, nesmie prísť o jeho rozmery ani prílohy. `list`
a `search` ho vynechajú (`include_deleted: true` ho vráti), `find` ho nájde vždy, `snapshot_for` ho odmietne (`:deleted`). `restore!` ho vráti — s tým
istým `rev` guardom.

**Prílohy** žijú v `%APPDATA%\NOXUN\Engine\appliances\<id>\`, teda **mimo stromu `Plugins/noxun_engine`, ktorý `Updater.swap!` pri aktualizácii celý
vymieňa**. Názov súboru je `<uuid prílohy>_<sanitized>.<ext>` (ASCII slug, prípony `pdf jpg jpeg png webp`), je **nemenný a nikdy sa nerecykluje**:
už obsadený cieľ sa neprepíše ani vtedy, keď je to sirota po odobranej prílohe (snapshot zákazky na ňu môže odkazovať) → `:copy_failed`. Poradie
publikácie: staging `<uuid>.tmp` **v cieľovom priečinku** → kontrola veľkosti stagingu → `File.rename` na finálny názov → až potom zápis JSON pod tým
istým zámkom; zlyhanie zápisu zmaže sirotu a vráti `:write_failed` (nikdy „úspech" s odkazom na neexistujúci súbor). Limit 25 MB sa kontroluje na zdroji
**aj na uloženej kópii** (zdroj sa medzitým mohol zväčšiť) a `bytes` v zázname je veľkosť kópie. **Druh určuje príponu** (`KIND_EXTS`): `sheet` berie
`pdf jpg jpeg png webp`, ale `image` a `thumbnail` **len obrázok** — PDF ako náhľad by UI nevykreslilo a dlaždica by ostala prázdna bez dôvodu; chyba
patrí poľu `kind`, lebo súbor je v poriadku. Náhľad je **najviac jeden** (`set_thumbnail!` prepína `image` ↔ `thumbnail` a rozhoduje sa podľa **prípony
súboru**, nie podľa dnešného druhu — záznam z cudzieho zápisu môže mať `image` nad PDF). `remove_attachment!` odoberá záznam zo zoznamu, **súbor vedome
ostáva** — bez indexu zákaziek sa nedá overiť, či naň niekto neodkazuje, a jeho meno tým ostáva navždy obsadené.

**Otvorenie prílohy** ide cez jeden resolver: `attachment_path_for(ref)` nad referenciou `{id, kind, file, name}` — **nezávislý od aktuálneho zoznamu
príloh**, takže zákazkový snapshot otvorí súbor aj po `remove_attachment!`. `file` musí byť jediný segment (žiadne `..`, `/`, `\`, absolútna cesta)
a výsledná cesta prechádza containment testom; chýbajúci súbor je `:missing_file` s cestou, nikdy ticho. `open_attachment(id, attachment_id)` deleguje
na ten istý resolver a volá `UI.openURL("file:///…")` s **URI kódovaním a doprednými lomkami** — holá Windows cesta s medzerami a diakritikou sa
systémovému prehliadaču neodovzdá spoľahlivo (overené in-SketchUp sekciou `run_s1a1`). Nezakódované ostávajú len `/` a `:`; **UNC cesta**
(`\\server\share\…`, teda `%APPDATA%` na sieťovom disku) si necháva hostiteľa — `file://server/share/…` s **dvoma** lomkami, lebo tri by z nej urobili
neexistujúcu lokálnu cestu.

**`snapshot_for(id)` pre zákazku (S1-B)** je čisté čítanie: hlboká kópia s **explicitným whitelistom** (`catalog_id`, `category`, `manufacturer`, `name`,
`shop_urls`, `sheet_urls`, `note`, `dims`, `derived`, `attachments` ako nemenné referencie, `seed`, `catalog_std`, `snapshot_at`) — žiadny stav katalógu
(`rev`, `updated_at`, `deleted_at`) do zákazky neprejde a neskoršia zmena katalógu snapshotom nepohne. Stavy: `:not_found` · `:deleted` (vyradený model
sa nepriraďuje) · `:unsupported` (`std` z novšieho pluginu alebo nečitateľný dokument). `:degraded` snapshot dovolí, ale **len keď záloha prejde tou istou
maticou ako primár** — inak by sa `.bak` z novšej verzie dostala do zákazky označená naším `catalog_std`. Zdroj sa overuje **čerstvo z disku**
a ten istý prečítaný dokument ide rovno do výberu záznamu — **žiadne druhé čítanie cez `JsonFileStore`**, ktoré by v okne sekundovej cache
(`CHECK_INTERVAL`) vrátilo stav spred zápisu druhej inštancie SketchUpu. Zákazka si snapshot odkladá, takže cachovaný záznam by v nej ostal natrvalo.
**I/O chyba pri čítaní** (sharing violation, nedostupný presmerovaný `%APPDATA%`, sieťový disk offline) sa prizná stavom `:unsupported` — `JsonFileStore`
ju zámerne prepúšťa von, ale von z katalógu nikdy nevyletí holá výnimka: kontrakt `[status, info]` platí aj tu.

**Seed je markerový** (`SEED_VERSION`, vzor `TemplateStore`): seje sa **výhradne pri prvej inštalácii** (chýba primár aj `.bak`), **nikdy opakovane** — zmazaný seed
záznam sa už nevráti a používateľská úprava sa neprepíše. Sadu tvorí **9 overených modelov** (2 rúry, 2 mikrovlnky, chladnička, 2 umývačky, varná doska,
digestor) s hodnotami a odkazmi výhradne zo `SYSTEM/zdroje/next_sessions/SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md`; čo list nekótuje, v seede nie je,
a odvodené hodnoty sú vymenované v `derived`. **Drez Blanco Legra XL 6 S sa nesedúje** (list výrobcu nie je overený, OVERENIE §12) — kategória `sink`
aj jej polia existujú od tejto dávky a Michal ho pridá ručne. Marker `SEED_VERSION` cestuje s dokumentom; doplnenie sady v budúcej dávke pobeží ako **seed patch
pri prechode markera** (vzor `HardwareCatalog.apply_seed_patches!`) — dnes taký patch neexistuje, lebo sada je prvá.

**Odpovede majú jeden tvar** `[status, info]`, kde `info` je Hash so symbolovými kľúčmi: `:ok` → `{record:}` / `{records:}` / `{snapshot:}` / `{path:}`,
`:invalid` → `{message:, field:}` (pole je **cesta**, napr. `dims.niche.width_min` — modal D-15 kreslí chybu pri poli), ostatné statusy
(`:conflict :not_found :deleted :read_only :degraded :too_large :copy_failed :write_failed :locked :unsupported :missing_file :open_failed`) nesú aspoň
`{message:}`. `with_lock` nikdy nevracia holé `false` von — zlyhanie zámku je `[:locked, {message:}]`.

**Pasce.** Dve varianty niky (stĺp × pod pracovnou doskou) sa **nesmú zliať do jedného rozsahu** — záznam nesie jednu niku a druhú variantu drží
poznámka (rúry v seede). Kategória sa nemení, preto sa `dims` nikdy nevalidujú proti inej sade polí, než pod akou vznikli. `search` porovnáva bez
diakritiky aj SK popisok kategórie („umyvacka" nájde `dishwasher`) a radí deterministicky názov → výrobca → `id`.

### appliance_binding.rb

**Jediný transakčný vstup pre spotrebič v zákazke** (S1-B1). Spotrebič má dve strany: **položku rozpočtu**
(`budget_appliances[]` na modeli) a **vlastníka** (skrinka · slot umývačky · doska), ktorý o väzbe vie —
nesie ju vo svojom configu v `appliance_refs[]`. Keby sa tie dve strany zapisovali každá vo vlastnej operácii,
jedno Späť by vrátilo len jednu z nich a zákazka by ostala v stave, ktorý v reálnej kuchyni neexistuje
(položka tvrdí, že rúra je v CAB-3, a skrinka o nej nevie).

- **Jedna operácia, jedno Späť.** `apply!(model, model_guid:, op:, item_id:, attrs:, catalog_id:, owner:)` má
  **práve jednu** `start_operation` (SketchUp nemá vnorené operácie — `start_operation` v otvorenej operácii ju
  ticho ukončí). V nej sa zapíše položka (`BudgetStore.write!` v režime `in_operation: true` — **neotvára,
  nekomituje ani neabortuje** a výnimku prepúšťa von), odstráni sa záznam u pôvodného vlastníka, pridá sa
  u nového a obaja sa prestavajú. Výnimka = `abort_operation` **celej** operácie; vracia sa
  `{ok:, errors:, item:, geometry_changed:}`.
- **`op` ∈ `create` · `patch` · `rebind_model` · `move` · `unbind` · `remove`.** `ProductionCore.apply_budget_op`
  sem smeruje **všetky** spotrebičové operácie okna — aj položky „len zákazka".
  `BudgetStore.add/update/remove_appliance!` sú odvtedy **vnútorné** funkcie volané pod `in_operation: true`
  (a s `trusted: true`, lebo `catalog_id`, `snapshot` ani `owner` z klienta nikdy nechodia).
  **Vlastníka smú niesť LEN `OWNER_OPS` = `create · move · unbind · rebind_model`** — `patch` a `remove`
  s vlastníkom v payloade sa **odmietajú** (nie ignorujú): dvaja vlastníci v jednom zápise sú nejednoznační
  a tichý výber jedného z nich by spotrebič presunul bez toho, aby o to niekto požiadal.
  **To isté platí pre model z katalógu:** `catalog_id` smú niesť len `CATALOG_OPS` = `create · rebind_model`.
  Pri operácii, ktorá snapshot neukladá, by matica bežala nad kategóriou **katalógu**, ale uložila by sa
  **stará** — chladnička by prešla ako umývačka na slot.
- **Guardy bežia PRED `start_operation`** (odmietnutá mutácia nesmie založiť krok Späť — vzor D-133/D-134):
  identita dokumentu (`DocKey.foreign?`, rovnaká tolerancia prázdneho klientskeho údaja ako rozpočet) · verzia
  dát rozpočtu (`BudgetStore.std_block_reason`) · existencia položky a strop `MAX_APPLIANCES` · **matica**
  kategória → vlastník · **pokoj observera** (`ScaleWatch.flush_pending!` — dedup kópií môže práve meniť
  identitu skriniek) · **identita cieľa** · **stav pôvodného vlastníka**.
  `CabinetBuilder.ensure_root_context` beží tesne pred operáciou — `rebuild_in_operation` to (na
  rozdiel od `rebuild`) nerobí, takže väzba počas vnoreného editovania by inak porušila prestavbu.
  **Volá sa len vtedy, keď sa naozaj prestavuje skrinka alebo slot** (`rebuilds_cabinet?`): zatvorenie
  rámu vyhodí používateľa z komponentu, ktorý práve edituje, a úprava ceny, príznaku či väzba na **dosku**
  (zápis configu bez prestavby) mu to spraviť nesmie.
- **Identita vysloveného cieľa = PID + ID + druh, a PID je POVINNÝ.** Fyzický cieľ (`cabinet|slot|board`)
  bez platného `pid` sa odmieta hláškou „zastaraná ponuka vlastníkov — otvor modal znova": ID sa recyklujú,
  takže hľadanie podľa neho samotného by spotrebič pripojilo na entitu, ktorá po zaniknutej skrinke iba
  zdedila číslo. Ponuka vlastníkov PID vždy nesie. Ďalej platí: dva kusy s tým istým ID = „nejednoznačná
  identita", odpojený dielec a config z novšej verzie sa odmietajú.
- **Kategória, proti ktorej beží matica, sa musí rovnať tej, ktorá sa NAOZAJ uloží.** Preto sa `typ`
  z formulára pri operáciách meniacich vlastníka (`move · unbind · rebind_model`) **odmieta** — inak by
  matica prešla nad starou kategóriou a zápis uložil novú (chladnička by sa dostala do slotu ako umývačka).
  Pri `create` sa **neznámy kód odmietne** (nikdy sa ticho nenahradí defaultom) a uložený typ je presne
  `plan[:category]` — teda to, čo maticou prešlo (legacy kód je v tom okamihu už prevedený na kanón).
- **Matica `OWNER_MATRIX`** obmedzuje len **fyzických** vlastníkov: `fridge|oven|microwave` → skrinka ·
  `dishwasher` → slot · `hob|sink` → doska · `hood|other` → nič. **`job` („len zákazka") je legitímny stav
  každej kategórie** a v matici preto nie je. Platí v ponuke vlastníkov (`owner_options_map` — odpojené
  skrinky a configy z novšej verzie sa **neponúkajú**) aj na serveri; klientsky payload nie je ochrana.
- **S1-C: OČAKÁVANIA čítajú TÚ ISTÚ maticu.** `expectable_categories(kind)` ju **odvodzuje** z `OWNER_MATRIX`
  (slot má výnimku v opačnom smere — `SLOT_EXPECTS` = vždy presne `dishwasher`), `expectable?` je predikát
  a `validate_expects(raw, kind)` je **striktná validácia vstupu akcie**: `nil` ani ne-pole **nie je**
  „zruš očakávania" (to je chyba klienta), explicitné `[]` je legitímne zrušenie, neznámy kód aj kód mimo
  matice sa odmietnu s vetou, výsledok je dedup v **kanonickom poradí** (dva rovnaké kódy aj preskupený zoznam
  sú ten istý stav — inak by vznikol prázdny krok Späť). Druhá tabuľka by dovolila očakávať spotrebič, ktorý sa
  k tomu kusu nikdy nedá priradiť. `bound_categories(entry, items)` vracia kategórie, ktoré sú na entite
  **naozaj** splnené — nad tým istým `ref_matches?`, takže osirelý záznam očakávanie nezamkne.
- **Štyri stavy pôvodného vlastníka:** (a) **platný** (entita existuje + jej refs nesú `item_id`) → prestaví sa ·
  (b) **nezapisovateľný** (odpojený dielec, novšia verzia) → **celá operácia sa odmietne** · (c) **zaniknutá
  väzba** (ID už patrí inému kusu bez refs) → tá skrinka sa **nedotkne**, položka len zmení vlastníka ·
  (d) **nejednoznačný** — v modeli žije **viac** kusov s tým istým uloženým ID (poškodený alebo importovaný
  model): keď väzbu nesie **práve jeden**, použije sa on; inak sa celá operácia **odmietne pred**
  `start_operation` („nejednoznačná identita vlastníka CAB-3 — prestav skrinky"), lebo tichý preskok by nechal
  staré refs visieť na oboch kusoch. `patch` (cena, názov, príznak) sa väzby nedotýka, a preto ho **nesmie**
  zastaviť ani zamknutý, ani zaniknutý vlastník — cena siroty sa musí dať opraviť.
- **Implicitne nesený cieľ sa NEHĽADÁ podľa ID.** `rebind_model` bez vysloveného vlastníka zapíše refs
  výhradne do **tej entity, ktorú overil `resolve_previous`**. Hľadanie podľa uloženého ID by pri recyklovanom
  ID pripojilo spotrebič na **cudziu** skrinku; keď pôvodný vlastník zanikol, refs sa **neprepisujú** —
  aktualizuje sa len snapshot položky a Kontrola hlási sirotu ďalej.
- **„Nezmenený vlastník" sa neposudzuje len podľa `kind` + `id`.** Uložený vlastník **bez platnej väzby**
  (`prev == nil` — entita zanikla alebo jej refs položku nenesú) nie je platný vlastník, takže vyslovený
  fyzický cieľ je vtedy **vždy nový** — aj keď má to isté ID, ktoré recykloval po zaniknutej skrinke.
  Navyše `rewrite_ref?` zapíše záznam vždy, keď **overený cieľ položku ešte nenesie**; cieľ, ktorý ju už má,
  sa zbytočne neprestavuje. Bez toho by „úspešný" presun siroty na recyklované ID nechal sirotu sirotou.
- **`rebind_model` s modelom inej kategórie sa ODMIETA**, nikdy automaticky neodpája („model inej kategórie —
  najprv odpoj spotrebič").
- **Dôkaz väzby má JEDNU funkciu pre celý engine — `ref_matches?(entry, owner, item_id)`** (zhoda **druhu**,
  zhoda **ID** a uuid v `refs`). Samotné uuid dôkazom nie je: `cabinet_id` zdieľa skrinka aj **slot** (v modeli
  sú oba `kind: 'cabinet'`, rozlišuje ich typ v configu), takže skrinkový záznam na entite, ktorá je dnes slot
  s tým istým číslom, by sa tváril ako platná väzba — a mutácie vlastníka by ju nenašli (hľadajú podľa druhu).
  Tú istú funkciu volá `Bom.collect` (`appliance_bound?`) aj binding (`carries_item?` nad `owner_entry_for`,
  ktorý druh a ID číta **z entity**, nie z toho, čo tvrdí položka) — zber a mutácie tak riešia identitu rovnako.
- **Kontrakt záznamu `appliance_refs[]`** (číta ho S1-B2 telo slotu, S1-F box chladničky, S1-C očakávania):
  `{item_id, category, manufacturer, name, body{width,height,depth}, niche{width_min…depth_max},
  bands{door_bottom_offset, door_lower, door_gap, door_upper}, furniture_doors{lower_min,lower_max,gap_ref},
  install{dishwasher_class, door_system,hinge_side}, snapshot_at}`. **Chýbajúce pole = kľúč chýba, nikdy 0** —
  nula je rozmer, „nevieme" nie je. **`manufacturer` a `name`** pribudli s S1-F (Codex #384 kolo 1, P2): bez
  nich sa **referencia v modeli nemala ako pomenovať** a každý box niky sa volal „Chladnička", takže dva boxy
  v jednej skrinke sa nedali rozoznať. Rozšírenie je **aditívne** — záznam uložený pred ním mená nemá a label
  vtedy padne na popisok kategórie (`Construction.niche_ref_label`).
- **Zapisovače refs.** Skrinka a slot idú cez `CabinetBuilder.write_appliance_refs!` (config → `normalize` →
  `rebuild_in_operation`; protiváha `strip_appliance_refs!`), **doska cez `BoardBuilder.write_appliance_refs!`** —
  zápis samotného configu **bez prestavby** (väzba jej geometriu nemení), ale **s pečiatkou
  `config_schema: BOARD_CONFIG_SCHEMA`**: doska uložená starším pluginom nesie schému 1 a tá by väzbu pri
  najbližšej prestavbe ticho zahodila. Prázdny zoznam kľúč **odstráni** (legacy kus nikdy nedostane prázdne pole).
- **`geometry_changed`** je `true` len vtedy, keď sa naozaj prestavovalo (skrinka/slot). Štúdio vtedy zdvihne
  generáciu (`push_state(bump: true)`) a pošle čerstvú kartu Inspectora (`Panel.push_selected(dedup: false)`);
  cenové zmeny ostávajú pri dnešnom `bump: false`.
- **Ponuka vlastníkov cestuje v payloade rozpočtu** (`appliance_owners` = `matrix` + `options` per druh +
  `job_label`), nie samostatným kanálom: patrí k dokumentu, ktorý payload priniesol, takže prepnutie zákazky ju
  vymení samo a modal nikdy neponúka skrinku z inej zákazky.

### appliance_checks.rb

**Jediná autorita verdiktu niky a delenia čiel** (S1-F). O tom, či sa chladnička do skrinky zmestí a kde smie ležať hrana medzi dolným a horným čelom,
hovoria **dve** miesta — Kontrola (`Validation`, ORANGE nálezy) a riadok „Spotrebič“ v Inspectore (`Panel.appliance_rows`). Keby si každé počítalo svoje,
semafor a karta by mohli nad tou istou skrinkou tvrdiť iné číslo. Tento modul preto drží **všetky vzorce aj všetky vety**; volajúci už len kreslí.
Je **čistý**: žiadne IO, žiadny SketchUp objekt, žiadny zápis. Vstupom je **záznam zberu** (`Bom.collect[:appliances]`) s kompletným výpočtovým kontextom;
Inspector si ten istý záznam skladá z uloženého configu cez **`context(cfg)`** — tá istá funkcia, takže druhá pravda nevznikne.

- **`context(cfg)`** → `{interior, z_lo, gap, single_zone, fronts_pair}`. `interior` a `z_lo` z `Construction.interior_dims`; `gap` a `fronts_pair`
  z **jedného** `Fronts.resolve_layout` (druhý výpočet by mohol dať iný default škáry — Codex #376 kolo 2 P2). Slot umývačky vnútro nemá, preto vracia `{}`.
- **`single_zone?(cfg)`** — autoritou je **koreň stromu zón** (`zone_tree.split`); ploché `zones` sú len jeho projekcia a slúžia legacy skrinke bez stromu.
  Ten **istý** predikát používa filter ponuky modelov aj verdikt: inak by ponuka filtrovala podľa výšky, ktorú by verdikt vzápätí označil za nekontrolovateľnú.
- **`niche_verdict(rec)`** → stav per os `ok | clash | unknown | skip` (+ celkový `na`, keď sa nika danej kategórie ani vlastníka netýka). Osi per kategória
  drží `AXES`: chladnička **šírka · výška · hĺbka**, rúra a mikrovlnka **šírka · hĺbka** (ich výška je vec zón, rozhodnutie 7). `skip` má **len výška** a **len**
  pri viacerých zónach. Agregácia: `clash` > `unsatisfiable` > `unknown` > `skip` > `na` > `ok`. Texty **menujú overené osi** („šírka, výška a hĺbka ✓“,
  „výška nekontrolovaná — skrinka má viac zón“) a nikdy netvrdia, že je montáž priechodná: overená je **obálka niky**, nie police ani vnútorné vybavenie (FIX F13).
- **Porovnanie osi má JEDNO miesto — `axis_state` / `axis_fits?` / `axis_check`** (Codex #384 kolo 1, P2) a **jednu toleranciu `AXIS_TOL` = 0,5 mm**. Používa ho
  verdikt **aj filter ponuky modelov** (`Panel.appliance_axis_reason`). Kým mala ponuka vlastné porovnanie na 0,5 mm a verdikt vlastné na 0,01 mm, model
  ponúknutý ako „zmestí sa" dostal hneď po väzbe ORANGE „nezmestí sa". Pol milimetra je hranica, pod ktorou je rozdiel vec zaokrúhlenia listu, nie montáže.
  Z toho istého dôvodu žije aj **tabuľka osí `AXES` len tu** — panel si ju nekopíruje. „Nevieme" (list číslo nedáva) nie je „nesedí": `axis_fits?` vtedy vracia `true`.
- **`door_split_verdict(rec)`** → `ok | clash | na | unknown | unsatisfiable`. **Hrana je VRCH DOLNÉHO ČELA** meraný od dna niky: `bounds[lower][:z1] − z_lo`
  (nezaokrúhlené `Fronts` hranice, tolerancia `EPS` = 0,01). Prípustné pásmo praxe je **`[D + 10, D + G − s − 10]`**, kde `D = door_bottom_offset + door_lower`
  (spodok + dolné dvere **spotrebiča**), `G = door_gap` a `s` je normalizovaná škára čiel; **10 mm je presah nábytkových dverí cez hranu dverí spotrebiča
  na oboch stranách** (konštanta enginu `OVERLAP_MIN`, Michal 19.9.2026). Stred pásma je **odporúčanie**. Prázdny interval (`G < s + 20`) je **`unsatisfiable`**:
  bez pásma a bez odporúčania, s vetou, ktorá menuje rozstup aj škáru (FIX F8).
- **Výkres výrobcu má prednosť.** Keď snapshot nesie `furniture_doors`, `lower_min`/`lower_max` sú **výšky dolných nábytkových dverí** (rozmer dielca), takže
  sa do niky prevádzajú cez **spodnú hranu dolného čela**: `bounds[lower][:z0] + h − z_lo`. Tá môže začínať **pod** nikou (sokel 100 + dno 18 + medzera 2 = 16 mm
  pod dnom niky) — `lower_z0` to nesie (FIX F2). Čiastočný blok = jednostranný rozsah, prázdny blok = vzorec praxe; `gap_ref` je len informácia a keď sa líši
  od škáry projektu, text to prizná.
- **Aplikovateľnosť dvojice čiel** (FIX F6): delenie sa počíta **len** pri práve dvoch čelách typu `door` nad sebou. Zásuvka, výklop, sklop, blenda ani riadok
  bez čela panel dverí netvoria — stav je `na` s dôvodom („delenie sa netýka: zásuvka“).
- **`findings(rec, computed = nil)`** vyrába vety Kontroly — **výhradne pre `clash` a `unsatisfiable`** (FIX F7 + F9). `unknown`, `skip` a `na` sú informácia
  pre riadok Spotrebič, nie ORANGE.
- **Informačné stavy sa v riadku naozaj ZOBRAZUJÚ** (Codex #384 kolo 1, P2). `verdict_text` skladá vetu z niky **aj** z delenia vrátane `unknown` — používateľ
  má vedieť, **prečo** sa delenie neodporúča („list nedáva rozmery dverí spotrebiča"), inak riadok o ňom ticho mlčal a nedalo sa rozoznať „je to v poriadku"
  od „nekontroluje sa". Tón riadku sa tým nemení (warn je len `clash` a `unsatisfiable`). Jediný stav, ktorý sa **nezobrazuje**, je `na`: „delenie sa netýka"
  je vlastnosť skrinky (zásuvka namiesto dvierok), nie modelu, a riadok je o modeli.
