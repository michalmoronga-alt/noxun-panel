# Spotrebiče — katalóg modelov

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Katalóg konkrétnych modelov spotrebičov tohto počítača (rozmery z listov výrobcov, odkazy, prílohy) a snapshot, ktorým si ich zákazka
odkopíruje k sebe. Väzba do zákazky, slot umývačky, kontrolné telo chladničky a UI sekcia prídu v dávkach S1-A2 až S1-F.

### appliance_catalog.rb

**Tretí per-PC katalóg** (S1-A1) vedľa materiálov a kovania: `%APPDATA%\NOXUN\Engine\appliances.json` cez `JsonFileStore` (atomický zápis, `.bak`,
sekundová cache) a **vlastný sidecar zámok** `appliances.json.lock`. Zámok je reentrantný (`with_lock`, vzor `TemplateStore`) a **nikdy sa nevnára do
iného katalógového zámku** — poradie zámkov je deadlock, preto má každý katalóg svoj. Cesta ide cez `Materials.dir`; `test_dir_override` (iba testy)
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
inak). **Kľúče mimo whitelistu kategórie — aj celé neznáme bloky — sa zachovajú, ale nevalidujú** (dopredná kompatibilita). `derived[]` menuje cesty polí,
ktorých hodnota je odvodená, nie z listu (napr. `body.width` pri Bosch BFL7221B1).

**`rev` je odtlačok obsahu, nie počítadlo** — `Digest::SHA1` uloženého záznamu, prvých 12 hex znakov. Do súboru sa **neukladá**; počíta sa pri čítaní
a vracia v `list`/`find`/`search` aj vo výsledku každej mutácie. Po obnove z `.bak` sa tak revízia pre iný obsah nezopakuje (počítadlo by to nezaručilo).
**Každá mutácia vyžaduje `rev:`** (`patch!`, `delete!`, `restore!`, `attach!`, `set_thumbnail!`, `remove_attachment!`) a server ho za klienta **nikdy
nedosadí** — prázdna alebo stará revízia je `:conflict` a nič sa nezapíše. Mutácia beží pod zámkom, invaliduje cache, prečíta **čerstvý** dokument
a až potom zapisuje.

**Stav katalógu — `assess!`** (`:ok` | `:read_only` | `:degraded`): chýba primár aj `.bak` = prvá inštalácia → seed · chýba primár, `.bak` je = **nie je**
prvá inštalácia (číta sa záloha, žiadny seed, prvý zápis primár obnoví) · poškodený primár + platná `.bak` = `:degraded` (číta sa záloha, **zápisy stoja**,
inak by prepísali primár obsahom spred poškodenia) · poškodený primár bez zálohy, cudzí tvar, chýbajúci alebo nečíselný `std`, **`std` > `STD` (forward
guard)**, záznam bez identity a duplicitné identity = `:read_only` s dôvodom. Tá istá kontrola (`stored_document_issue`) beží nad čerstvým dokumentom
**pod zámkom pred každým zápisom** — cachovaný `:ok` nie je dôkazom aktuálneho stavu súboru.

**Tombstone.** `delete!` zapíše `deleted_at` a záznam ostáva v súbore: zákazka, ktorá model použila, nesmie prísť o jeho rozmery ani prílohy. `list`
a `search` ho vynechajú (`include_deleted: true` ho vráti), `find` ho nájde vždy, `snapshot_for` ho odmietne (`:deleted`). `restore!` ho vráti — s tým
istým `rev` guardom.

**Prílohy** žijú v `%APPDATA%\NOXUN\Engine\appliances\<id>\`, teda **mimo stromu `Plugins/noxun_engine`, ktorý `Updater.swap!` pri aktualizácii celý
vymieňa**. Názov súboru je `<uuid prílohy>_<sanitized>.<ext>` (ASCII slug, prípony `pdf jpg jpeg png webp`), je **nemenný a nikdy sa nerecykluje**:
už obsadený cieľ sa neprepíše ani vtedy, keď je to sirota po odobranej prílohe (snapshot zákazky na ňu môže odkazovať) → `:copy_failed`. Poradie
publikácie: staging `<uuid>.tmp` **v cieľovom priečinku** → kontrola veľkosti stagingu → `File.rename` na finálny názov → až potom zápis JSON pod tým
istým zámkom; zlyhanie zápisu zmaže sirotu a vráti `:write_failed` (nikdy „úspech" s odkazom na neexistujúci súbor). Limit 25 MB sa kontroluje na zdroji
**aj na uloženej kópii** (zdroj sa medzitým mohol zväčšiť) a `bytes` v zázname je veľkosť kópie. Náhľad je **najviac jeden** (`set_thumbnail!` prepína
`image` ↔ `thumbnail`). `remove_attachment!` odoberá záznam zo zoznamu, **súbor vedome ostáva** — bez indexu zákaziek sa nedá overiť, či naň niekto
neodkazuje, a jeho meno tým ostáva navždy obsadené.

**Otvorenie prílohy** ide cez jeden resolver: `attachment_path_for(ref)` nad referenciou `{id, kind, file, name}` — **nezávislý od aktuálneho zoznamu
príloh**, takže zákazkový snapshot otvorí súbor aj po `remove_attachment!`. `file` musí byť jediný segment (žiadne `..`, `/`, `\`, absolútna cesta)
a výsledná cesta prechádza containment testom; chýbajúci súbor je `:missing_file` s cestou, nikdy ticho. `open_attachment(id, attachment_id)` deleguje
na ten istý resolver a volá `UI.openURL("file:///…")` s **URI kódovaním a doprednými lomkami** — holá Windows cesta s medzerami a diakritikou sa
systémovému prehliadaču neodovzdá spoľahlivo (overené in-SketchUp sekciou `run_s1a1`).

**`snapshot_for(id)` pre zákazku (S1-B)** je čisté čítanie: hlboká kópia s **explicitným whitelistom** (`catalog_id`, `category`, `manufacturer`, `name`,
`shop_urls`, `sheet_urls`, `note`, `dims`, `derived`, `attachments` ako nemenné referencie, `seed`, `catalog_std`, `snapshot_at`) — žiadny stav katalógu
(`rev`, `updated_at`, `deleted_at`) do zákazky neprejde a neskoršia zmena katalógu snapshotom nepohne. Stavy: `:not_found` · `:deleted` (vyradený model
sa nepriraďuje) · `:unsupported` (`std` z novšieho pluginu alebo nečitateľný dokument); `:degraded` snapshot dovolí.

**Seed je markerový** (`SEED_VERSION`, vzor `TemplateStore`): seje sa pri prvej inštalácii a pri prechode markera, **nikdy opakovane** — zmazaný seed
záznam sa už nevráti a používateľská úprava sa neprepíše. Sadu tvorí **9 overených modelov** (2 rúry, 2 mikrovlnky, chladnička, 2 umývačky, varná doska,
digestor) s hodnotami a odkazmi výhradne zo `SYSTEM/zdroje/next_sessions/SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md`; čo list nekótuje, v seede nie je,
a odvodené hodnoty sú vymenované v `derived`. **Drez Blanco Legra XL 6 S sa nesedúje** (list výrobcu nie je overený, OVERENIE §12) — kategória `sink`
aj jej polia existujú od tejto dávky a Michal ho pridá ručne.

**Odpovede majú jeden tvar** `[status, info]`, kde `info` je Hash so symbolovými kľúčmi: `:ok` → `{record:}` / `{records:}` / `{snapshot:}` / `{path:}`,
`:invalid` → `{message:, field:}` (pole je **cesta**, napr. `dims.niche.width_min` — modal D-15 kreslí chybu pri poli), ostatné statusy
(`:conflict :not_found :deleted :read_only :degraded :too_large :copy_failed :write_failed :locked :unsupported :missing_file :open_failed`) nesú aspoň
`{message:}`. `with_lock` nikdy nevracia holé `false` von — zlyhanie zámku je `[:locked, {message:}]`.

**Pasce.** Dve varianty niky (stĺp × pod pracovnou doskou) sa **nesmú zliať do jedného rozsahu** — záznam nesie jednu niku a druhú variantu drží
poznámka (rúry v seede). Kategória sa nemení, preto sa `dims` nikdy nevalidujú proti inej sade polí, než pod akou vznikli. `search` porovnáva bez
diakritiky aj SK popisok kategórie („umyvacka" nájde `dishwasher`) a radí deterministicky názov → výrobca → `id`.
