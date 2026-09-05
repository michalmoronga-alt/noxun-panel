# Materiály, ABS a katalóg

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Katalóg materiálov a pások, dekorové skupiny, migrácia a zdravie katalógu, pravidlové ABS defaulty a Demos konektor.

### materials.rb

katalóg materiálov a dedenie projekt→skrinka→dielec (projektové defaulty v NOXUN dict na MODELI).

#### KOV-C2a — 4. materiálový kanál `:drawer` (v0.9.30)

`PROJECT_KEYS` má štvrtý kľúč **`default_drawer_material_id`** = materiál DIELCOV ZÁSUVIEK (dno · chrbát · boky boxu · vnútorné čelo). Fallback je **UNI 16 mm**
(`UNI_ZASUVKA_16`) — obe rady receptov (Atira aj Quadro V6) stavajú na 16 mm doske — a keďže `PROTECTED_SHEET_IDS = PROJECT_FALLBACK.values`, je ID **nezmazateľné**.
`CabinetBuilder.effective_materials` vracia navyše **`eff_drawer`**; v C2a ho **nič nekonzumuje** (dielce zásuviek emituje až C2b).

**KOV-C2b (v0.9.31) — kanál sa ZAPOJIL.** Pribudla ÚROVEŇ SKRINKY (config kľúč **`drawer_material_id`**, `CONFIG_SCHEMA` 5) a plná reťaz dedenia
`part_override → skrinka → projekt → UNI 16` presne ako pri tele/čele/chrbte. Hrúbka je **VSTUP receptu**, nie odvodenina plánu: `CabinetBuilder.drawer_thicknesses(cfg, eff)`
ju vyrieši **PRED** `Construction.build_plan` a pošle ju ako `part_thicknesses` (`{ part_key => mm }`) — bez toho by 18 mm materiál pri Atire ticho prešiel a Quadro by
počítalo predok/chrbát z nesprávnej hrúbky dna (Codex #301 kolo 3 P1). Materiál mimo `thickness_supported` receptu = RED `drawer_thickness_unsupported`, žiadne dielce.
**UI kanála doplnené v C2b (Codex #304 kolo 1 P1).** `MaterialsDialog::TARGETS` má štvrtý kľúč `default_drawer_material_id` → `['drawer_material_id', 'drawer_bottom', nil]`
(rola je len zástupná — o prípustnosti hrúbky rozhoduje RECEPT, nie `thickness_ok_for?`) a Štúdio má **jeden riadok „Zásuvky"** v predvoľbách projektu, v tom istom vzore
ako Čelá/Chrbát (vertikálny priestor je vzácny — žiadny nový blok). JS mapa `mdProjectSelectId` má `md_drawer`, kombo dostalo kontext `drawer` s predvolenou hrúbkou **16**
(jediná, ktorú prijme každý vydaný systém). Guard test iteruje `TARGETS` a vyžaduje pre KAŽDÝ kľúč riadok v `studio.html` aj záznam v JS mape.

**PREFLIGHT PER SYSTÉM (nie D-46 mechanicky).** D-46 vetva porovnáva hrúbku ČELA (18) a o receptoch nevie, takže sa sem nedá použiť. Namiesto nej:
`drawer_thickness_any_system?` je **tvrdá** brána novej predvoľby — doska, ktorú neprijme ani jeden vydaný systém (napr. 25 mm), sa neuloží vôbec a hláška menuje povolené
hrúbky (16 a 18). Keď dosku niektorý systém prijme, ale zákazka používa systém, ktorý ju **neprijme**, `drawer_change_plan` vráti zoznam systémov aj skriniek a predvoľba sa
uloží **až po potvrdení** (`offer_drawer_change` — ten istý pending kontrakt a tá istá lišta ako D-46, líši sa len veta: menuje systém, jeho povolené hrúbky a počet skriniek).
Zdrojom čísel je `Recipes.supported_thicknesses` ([hardware.md](hardware.md)), nikdy konštanta v UI.

Kanál mal v C2a **len projektovú úroveň**: config kľúč skrinky ani výber v Štúdiu neexistovali. Preto ho
`MaterialsDialog::TARGETS` **nepozná** a akcia `set_project_material` ho odmietne („Neznámy projektový materiál") — vedomá diera, nie opomenutie. Čo naň už reaguje:
`Materials.project_defaults`, delete guard (`used_material_ids`) a **„Nahradiť UNI…"** — `materials_replace_uni` má preň vlastný riadok v `RU_PROJECT_LABELS` („Zásuvky") aj
vlastnú vetvu v `ru_project_target_issue` (rozsah doskového materiálu; bez nej by 4. kanál spadol do `else`, teda do pravidiel ČIEL). Či recept hrúbku prijme
(Atira 16, Quadro V6 16/18), rozhoduje `thickness_supported` receptu — až v C2b.

**`thickness_ok_for?` pozná 4 nové roly** (`CabinetBuilder::DRAWER_ROLES` = `drawer_bottom` · `drawer_back` · `box_side` · `drawer_inner_front`) a správa sa pri nich ako pri
čelách: berú KATALÓGOVÚ hrúbku svojho materiálu, lebo hrúbka je **vstup receptu**, nie konštrukčná konštanta korpusu. V `BuildPlan::ROLES` roly **od C2b sú** (`plan_schema` 4), a keďže `cabinet_builder` sa načítava PRED `drawer_recipes`, väzbu na `Recipes::ROLE_*` drží **guard test**, nie referencia (rovnaký vzor ako
`hardware_sets` ↔ `Fronts`).

#### CRUD katalógu (V0.4.7)

CRUD katalógu (V0.4.7): server-generované ID (transliterácia, kolízie -2/-3), hrúbka existujúceho materiálu NEMENNÁ (= nový variant), delete guard (PROTECTED_SHEET_IDS + scan
použitia v modeli/overridoch/dielcoch/doskách/šablónach).

#### D-41 dekorové skupiny (V0.5-E)

dekor = strážený kľúč väzby materiál↔ABS (trim, near-match guard aj bez medzier, dekor/typ/šírka pri edite NEMENNÉ, `rename_decor` atomicky celú skupinu — ID sa nemenia, zákaz
duplicitných variant identít, `catalog_revision` baseline guard okna). ABS s voliteľnou šírkou (variant = dekor+šírka+hrúbka, ID `..._22X10`); **deterministický picker**
`abs_for_decor(decor, th, part_thickness)`: najmenšia šírka ≥ hrúbka+2 → univerzálna bez šírky → nil (**nikdy užšia**; tie-break abs_id; buildery odovzdávajú katalógovú hrúbku
sheetu — čelá 18/19). `add_decor_batch` (parse-all-validate-all, tolerančný dedup 0,01, 1 atomický zápis; **D-42:** štruktúrované `sheet_variants[{type,thickness}]`/`edge_variants`
— typ per variant, strict Float parsovanie).

#### D-42 dodávateľské polia (V0.5-F)

`code` + `supplier` voliteľné na doske aj ABS (merge-safe, trim, prázdne = kľúč preč; duplicitný pár kód+dodávateľ vyžaduje `allow_duplicate_code` — aj pri patchi LEN dodávateľa).

**Cena nil = „nezadaná" ≠ 0** (`normalize_price` — nečíslo sa odmieta, kľúč sa neukladá; batch/ensure cenu neuvádzajú).

**`patch_record`** — bezpečný inline patch (PATCHABLE whitelist — identita sa patchom nikdy nemení, merge s čerstvým záznamom pred validáciou, `record_rev` baseline per RIADOK →
`:conflict` pri cudzej zmene; **ŠT-2c: zmena CENY ruší `price_checked_at`** — ručne prepísaná cena už nie je cena overená voči stránke dodávateľa a prepočet cien by taký záznam
inak považoval za čerstvý; `demos_url` sa patchom zmeniť nedá, takže podmienka „bez zmeny väzby“ platí vždy). `set_decor_manufacturer` (výrobca = vlastnosť dekoru, atomicky
skupina). `model_decor_usage` (read-only scan part/board snapshotov BEZ šablón, ráta kusy s quantity — pás „Použité v projekte").

#### ŠT-2c 2c-2a — save_decor (D-69 jednotný editor dekoru)

JEDNA atomická zapisovacia cesta pre CELÝ formulár „Upraviť…“ (identita skupiny + riadky dosiek + riadky ABS). Vzor atomicity je `add_decor_batch_v3` (jeden zámok, validate-all,
JEDEN `write_unlocked`), rozšírený o EDIT existujúcich riadkov a o skupinové polia v TEJ ISTEJ transakcii.

Kontrakt má **10 bodov** (zapracovaný slepý audit ŠT-2c, číslované aj v kóde): **1** allowlist vstupu (`SAVE_DECOR_KEYS` + `SAVE_DECOR_SHEET_KEYS`/`SAVE_DECOR_EDGE_KEYS`) —
server-owned polia (`price_checked_at`, `uni`/`uni_role`, `source_*`, `group_id`/`color`/`family`/`decor`/`manufacturer` na RIADKU) sa **strhávajú**; **2** riadok nesie
`material_id`/`abs_id` + `row_rev`, alebo NIČ (= nový variant); **3** brány PRED zámkom (`catalog_read_only?`, `schema_write_allowed?`); **4** POD zámkom `catalog_schema_on_disk`,
`base_rev` == `catalog_revision` a `row_rev` KAŽDÉHO riadku (nesúlad = `:stale`, zmiznutý záznam = `:conflict`); **5** validate-all bez fail-fast — všetky chyby NARAZ ako `[{row,
field, msg}]` (`row` = `nil` pre skupinové pole, inak `"sheets:<i>"`/`"edges:<i>"`); **6** validácie = **zjednotenie dnešných brán** (`validate_sheet_attrs`/`validate_edge_attrs`,
`duplak_edit_error`, `uni_edit_error`, `uni_group?`, near-match a kolízia obchodnej identity skupiny, dup variant vo formulári, `code`+`supplier` cez `allow_duplicate_code`); **7**
riadok s ID mení LEN NEIDENTITNÉ polia (typ, hrúbka, štruktúra, šírka pásky a formát pri `format_in_identity?` type sú nemenné — rozhoduje `identity_edit_error`), riadok bez ID je
nový variant s plnými create guardmi a **záznam, ktorý vo formulári nie je, sa NEMAŽE** (mazanie ostáva na delete preflighte); **8** skupinové polia (číslo dekoru, výrobca, názov,
farba) sa aplikujú CELEJ skupine v tej istej transakcii a **PRED riadkami** — inak by záznam prestavaný z riadku prepísal práve premenovaný dekor; **9** zmena ceny ruší
`price_checked_at` (editor `demos_url` NEMENÍ — väzba na dodávateľa má vlastnú autoritu, rozhodnutie auditu #4); **10** `[:ok, {group_id, created[], updated[], skipped[]}]` |
`[:invalid|:stale|:conflict|:code_conflict|:catalog_read_only|:write_failed, {...}]`, pri `:ok` presne JEDEN `write_unlocked` (a pri „bez zmien“ ani ten — zbytočný bump revízie by
všetkým otvoreným formulárom zneplatnil baseline).

Nový riadok **dedí štruktúru po skupine** (nie je to stĺpec); skupina s VIACERÝMI štruktúrami je nerozhodnuteľná a povie to nahlas. `universal` na ABS ostáva **patch-only** (audit
#8) a `uni_abs_id` z návrhu **zaniklo**.

**Po review 2c-2a:** brány **3** bežia dvakrát — pred zámkom ako rýchle odmietnutie (nedržať zámok pre požiadavku bez šance) a **znova POD zámkom**, lebo medzi čítaním cache a
zápisom sa stav katalógu môže zmeniť (cudzí proces, boot cutover); `price_checked_at` ruší aj zmena **kódu a dodávateľa** (dátum hovorí „cena TOHTO kódu u TOHTO dodávateľa bola
vtedy overená“) — rovnaké pravidlo aj v `patch_record`; update vetva dorovná **závislé dupláky** v TEJ ISTEJ transakcii cez zdieľané `sync_duplaks_in!` (jediná autorita, delí ju s
`upsert_sheet_with_duplak_sync` — inak by zdroj mal nový formát a duplák starý a odhad platní by účtoval plochu podľa vymysleného formátu); **druhý výskyt toho istého ID** vo
formulári je chyba validate-all (tichý prepis + klamlivý počet zmien); a **nový riadok sa zakladá len pre typy bez ďalšej identity** — zástena (rub) a PD (hranová úprava) hlásia
„pridaj cez + variant“, lebo editor tie stĺpce nemá a založil by neúplný variant, ktorý sa tvári hotovo (`sd_new_row_type_error`).

**ŠT-2c 2c-2b — DRUHÝ REŽIM `create` („Pridať ručne", D-69 KOMPLET):** tá istá cesta, iný začiatok — skupina PRÁVE VZNIKÁ. Všetkých 10 bodov platí rovnako (allowlist, brány pred aj
pod zámkom, `base_rev`, validate-all, JEDEN `write_unlocked`, `code_conflict` cez `allow_duplicate_code`), navyše sa rozhoduje **identita skupiny** (`save_decor_create_group`):
číslo dekoru je **povinné**, near-match a kolízia identifikátora idú **JEDNOU autoritou s dávkou** (`resolve_batch_group` — žiadna druhá kópia pravidiel), **existujúca skupina sa
nezakladá druhý raz** (hláška posiela na „Upraviť…“; ten istý dekor u INÉHO výrobcu je legitímna nová skupina), **prázdny formulár** neprejde a **značková skupina potrebuje aspoň
jednu dosku** (výrobcu nesie doska, štandard 7.5 — zrkadlo `add_decor_batch_v3`).

Riadok so **skrytým ID** je v `create` chyba (`save_decor_create_no_ids`) — bez nej by editovacia vetva ticho prepísala cudzí záznam a presunula ho do práve zakladanej skupiny.
Riadky idú **tou istou cestou** ako nové riadky editu (`save_decor_new_sheet`/`_edge`), takže zástena a PD hlásia „pridaj cez + variant“ aj tu. Nová skupina smie mať **práve jednu
štruktúru povrchu** (`save_decor_create_structures`) — dvojštruktúrová skupina je pre editor nerozhodnuteľná (`sd_new_structure`), takže by vznikla rovno ako slepá ulička, do
ktorej sa už nedá pridať riadok inak než cez „+ variant".

Skupinové polia nesie `save_decor_create_plan` (**farba** + **smer dekoru**): farba ide do `attrs` PRVÉHO záznamu a ďalšie ju už derivujú cez `enforce_group_color!` z dát v ruke;
**validácia farby aj smeru je ZDIEĽANÁ s editom** (`sd_color_plan` vrátane UNI zámku + `sd_grain_plan` — dve kópie toho istého pravidla by sa časom rozišli).

**`save_decor_code_conflict` dostáva aj v create nezávislý snímok stavu spred dávky** (rovnako ako edit): s prázdnym snímkom by sa každý záznam katalógu tváril ako „zmenený touto
dávkou" a jediná stará, vedome potvrdená duplicita kód+dodávateľ by zablokovala založenie každého ďalšieho dekoru (nález review 2c-2b #1). Odpoveď `:ok` nesie navyše `mode:
'create'` a `group_id` NOVEJ skupiny — klient podľa nich skočí na jej dlaždicu (echo katalógu ide **pred** `MD.editSaved`, inak by skok padol do prázdna). `base_rev` je pri
`create` jediný možný guard a je potrebný: ten istý dekor mohol medzitým založiť niekto iný. Testy: `tests/pure/test_st2c_save_decor.rb` + `tests/pure/test_st2c_create.rb` (obe
mutačné — odstránenie brány = pad).

#### PICKER-2/3 — identita variantovej rodiny pre vyhľadávač

`variant_family_key` · `row_family_ctx` · `row_label_disambiguated` — odpoveď na otázku **„čo ešte JE ten istý materiál v inej hrúbke"**. Vyhľadávač (`ui/js/nx_combo.js`) z nej
skladá jeden riadok na dekor s hrúbkami na čipoch; hranicu **nesmie hádať klient** — vidí vždy len to, čo je práve v selecte. Kľúč = **kanonická identita dosky BEZ hrúbky**:
skupinová časť z `record_group_key` + `identity_norm` nad dekorom, štruktúrou, typom a príponou formátu/rubu (`sheet_label_suffix`). Zložky sú kanonické **všetky** (PICKER-3): typ
aj štruktúru porovnáva katalógový kontrakt case-insensitive, takže `DTDL`/`dtdl` a `ST9`/`st9` sú ten istý materiál a v surovom tvare dávali dva riadky s rovnakou menovkou.
Skupinová časť ostáva presne kanonická **aj so symbolovými značkami** — v SCHEMA 1 je surový dekor súčasťou katalógovej identity, takže normalizovať ho tam by zlúčilo to, čo
katalóg drží oddelene. UNI záznamy dostávajú unikátny kľúč (nezlučujú sa vôbec). Medzery sa neodstraňujú: `ST9` a `ST 9` sú dva zápisy (od preklepov je `decor_conflict`).

`row_family_ctx(sheets, schema, virtual:)` je kontext pre CELÝ payload (vzor `Panel.label_ctx`): pre každú dekorovú menovku zoznam rodín, pre každú rodinu jej hrúbky. Nad ním
`row_label_disambiguated` pridáva **typ** pri kolízii menovky a **hrúbku len vtedy, keď ju riadok neukáže čipmi**. Parameter `virtual:` (PICKER-3, pole `[zdroj, hrúbka]`) nesie
hrúbky, ktoré riadok zastupuje, hoci v katalógu ešte nie sú — **virtuálne dupláky `duplak2:` (D-49)**; bez nich rodina s jednou kúpenou hrúbkou platila za jednovariantnú a menovka
tvrdila „… 18 mm", hoci riadok dostal čip „36 duplák" a po jeho výbere vložil 36. Panel ich berie z tej istej autority ako `duplak_offers` (`duplak_offer_sources(2)`), aby sa oba
zdroje nemohli rozísť. Testy: `tests/pure/test_picker3_rodina.rb` (aj opačný smer — že sa nezlialo nič reálne rôzne), `tests/pure/test_picker2_used_ids.rb`.

#### Remap ABS

`remap_edges` + `CabinetBuilder.remap_part_edge_overrides!` — ručné ABS zladené s dekorom nasledujú materiál pri KAŽDEJ zmene (dielec cez old_overrides snapshot / korpus /
projektová predvoľba; kontrast a vedomé „bez ABS" nedotknuté). `ensure_edge_for_sheet` dovytvorí 1,0 pásku len zo štandardov AUTO_WIDTHS s presahom (katalógový zápis MIMO undo —
vedomý kontrakt).

### materials_catalog.rb

Zo splitu `materials_*`: CRUD+batch.

**KOV-C2a — UNI záznam 4. kanála a `ensure_drawer_uni!` (v0.9.30).** `UNI_SEED` má šiesty riadok `UNI_ZASUVKA_16` / „Zásuvka UNI" / rola `drawer` / 16 mm; fresh install aj
`UNI_APPEND_IDS` používajú **to isté ID** (je nové, žiadna legacy väzba naň neukazuje, takže dva tvary ako pri `K009`/`UNI_KORPUS_18` netreba). Pre EXISTUJÚCE inštalácie má
kanál **vlastnú migráciu s vlastným markerom** `drawer_uni_seed.done`: `ensure_uni_records!` končí na prvom riadku pri `uni_seed.done`, takže cez ňu by sa nový záznam
nedoplnil nikdy. `ensure_drawer_uni!` je idempotentná (2× beh = 1 záznam), beží z bootu `main.rb` vo VLASTNOM chránenom bloku a **nikdy neprepisuje** — ale
na dva druhy kolízie odpovedá RÔZNE (Codex #303 P2): **obsadené ID** znamená, že záznam pod `UNI_ZASUVKA_16` existuje, takže `PROJECT_FALLBACK` na niečo ukazuje a migrácia
je hotová (`:noop`, marker sa zapíše); **obsadená SKUPINA pod iným ID** by nechala fallback ukazovať na neexistujúce ID, a to je **fail-closed**: marker sa **nezapíše**,
vráti sa `:conflict` s hláškou a ďalší štart to skúsi znova (po premenovaní cudzieho záznamu sa doplní sám). Kolízia sa meria **celou identitou skupiny** (`group_identity_key`
= výrobca + dekor, STANDARD §7.1), nie samotným dekorom (Codex #303 kolo 2 P2): „Egger + Zásuvka UNI" je INÁ skupina než seed („" + Zásuvka UNI), takže kolízia to nie je —
inak by taký legitímny záznam vracal `:conflict` pri každom štarte a fallback ID by nevzniklo NIKDY. Porovnáva sa proti identite **seed záznamu**, nie proti konštante. Kto si UNI zásuvku vedome zmaže, tomu sa nevráti.

### materials_decor.rb

Zo splitu `materials_*`: skupinové operácie + `ensure_edge_for_sheet`.

### materials_abs.rb

Zo splitu `materials_*`: picker/remap.

### materials_demos_create.rb

Zo splitu `materials_*`: atomické založenie rodiny z Demosu.

### materials_project.rb

Zo splitu `materials_*`: projektové defaulty + mapy `decor_key_by_material_id` / **`decor_key_by_abs_id`** — kľúč dekorovej skupiny pre pás „Použité v projekte" a rozpis „Kde sa
používa"; obe SCHEMA-aware, aby počty a zoznam ukazovali na tú istú skupinu.

### materials_replace_uni.rb

**M-B2 „Nahradiť UNI…"** (`materials_replace_uni`): scan+čistá klasifikácia, rozpis dopadu pred potvrdením, SHA256 odtlačok plánu, all-or-nothing, 1 undo (skrinky+dosky+predvoľby).

**GHOST-D1 — brána schémy PRED normalizáciou.** Dávka dosku najprv `BoardBuilder.normalize`-uje a až potom prestavuje (`rebuild_in_operation`), lenže normalizácia je uzavretý
whitelist: zahodí `config_schema` **aj neznáme polia**, takže doska z novšej verzie by prešla ticho a projekt by skončil **čiastočne migrovaný**. Kontrola preto beží už
v `replace_uni_classify` — nad **RAW uloženým configom** zo scanu, pred akoukoľvek prácou s ním — a doska s vyššou schémou ide do `blocked` plánu (dôvod `:board_schema`,
hláška „doska je z novšej verzie Noxun — aktualizuj plugin"). Keďže apply je **all-or-nothing** (neprázdny `blocked` zastaví celú náhradu ešte pred operáciou), znamená to:
model sa nedotkne **vôbec**, nie „doska sa preskočí". Poslednou záchytnou sieťou je ten istý guard priamo v `BoardBuilder.rebuild_in_operation`.

**Korelácia otázky a odpovede (R-23.1, review #273):** rozpis dopadu prichádza **asynchrónne** (`MD.replaceUniOffer`) a modál si otvára sám, takže Escape medzi otázkou
a odpoveďou by ho vrátil späť aj s rozpisom, ktorý používateľ práve zahodil. Otázka (`replace_uni_preview` aj `replace_uni_apply`) preto nesie číslo `gen` a server ho vracia
v **každej** odpovedi — klient zobrazí len odpoveď na **poslednú** otázku. **`gen` je per-request, nie per-relácia** (review kolo 2): rastie pri otvorení, zatvorení **aj pri každej
jednotlivej otázke**. Na úrovni relácie by dve rýchle „Ukázať dopad" (cieľ A → zmena variantu → cieľ B) niesli to isté číslo, pomalšia odpoveď A by prešla ako platná, spotrebovala
čakanie a čerstvá B by prepadla — a potvrdiť by sa dal plán pre **starší cieľ**, teda zápis do modelu podľa niečoho iného, než je na obrazovke. Ten istý vzor ako revízia náhľadov
šablón. Testy: `tests/js/test_replace_uni.js`.

### materials_* — spoločný kontrakt (SCHEMA · UNI · duplák · Demos väzba)

Kontrakt, ktorý zdieľajú `materials.rb` aj celý split `materials_*` vyššie.

**SCHEMA: 2 skupiny = povinný baseline po cutoveri; markery 3 duplák · 4 zástena · 5 demos polia · 6 image_url · 7 UNI · 8 PD hranová úprava + protiťahová zástena = LAZY podľa
OBSAHU** (`SCHEMA_CURRENT` v materials.rb). Demos väzba na zázname: `demos_url` + `price_checked_at` (cena = pohyblivá cache; `manual_demos_url` sanitize + kanonické porovnanie —
D-71).

**UNI (SCHEMA 7, M-B1):** 5 rolí Korpus·Čelo·Dekor2·HDF·Doska; hrúbka záznamu je len default roly — pri stavbe dielca sa NEviaže (hrúbku určuje DIELEC; identita záznamu v katalógu
hrúbku štandardne obsahuje); ABS/nákupné polia pre UNI zakázané server-side; semafor ORANGE „materiál neurčený".

**D-49 duplák automaticky:** virtuálne položky `duplak2:<id>` v selectoch tela/dielca/dosky (samostatné pole payloadu — vklad dosky a projektové selecty ich nevidia),
`ensure_duplak_for` s guardmi (UNI/typ/kolízia s kupovanou), duplák nededí uni/demos polia.

**ŠT-2a:** obidva tieto zápisy z Inspectora (`ensure_missing_abs` v `panel/actions_parts.rb`, `resolve_virtual_material` v `panel/resolvers.rb`) idú **JEDNOU fan-out cestou
`Panel.broadcast_catalog_change` → `MaterialsDialog.after_catalog_change`** — vlastný refresh (`push_materials` + `MaterialsDialog.push_state`) obišiel sekciu Materiály v Štúdiu a
nechal jej **starý `catalog_rev`**, takže jej najbližší zápis by server odmietol hláškou „Katalóg sa medzitým zmenil"; fan-out navyše invaliduje cache kontroly hrán a obnoví čísla
Štúdia. Vetva `:exists_regular` (identitu drží kupovaná doska) fan-out **nerobí** — nič sa nezapísalo.

**M-C (SCHEMA 8):** `pd_edge_subtype` (postforming/abs — z Demos parametra „Typ pracovnej dosky" alebo edit formulára; len PD, enum, guard aj v normalize) +
`abs_default_suppression` = jedna autorita „nelepiteľných" (KOMPAKT vždy · PD-postforming) pre resolve_edges, semafor (`abs_impossible?` headless dvojník + potlačenie uložených
abs_* warnings), modal aj `ensure_edge_for_sheet` (`:abs_suppressed`); zmena materiálu dosky na nelepiteľný ČISTÍ hrany; **`density` per TYP v TYPE_REGISTRY** + `density_for`
(UNI/„iný" = nil) — spotrebuje dávka D (pri návrhu D density SNAPSHOT do modelu).

**D-72:** protiťahová zástena — `zastena_decor_parts` + `zastena_counterbalance?` gate (single len s „protitah" markerom), záznam s príznakom `single_sided` (first-fill rubu
zakázaný; párová stránka sa s ním nezhoduje).

**D-73:** KOMPAKT má `format_in_identity` (formát = identita variantu ako PD).

**D-74:** name_search labely formátované (`abs_dims_hint`/`sheet_dims_hint` s dedup-sufix heuristikami, consumed kontrakt) + `open_search_url` (sanitize server).

**Medziprocesový zámok `with_catalog_lock`:** blokujúci `flock(LOCK_EX)` nad **sidecar súborom** `materials.lock` v `Materials.dir` — nikdy nie nad samotným `materials.json`,
ktorého `rename` by zámok stratil; `test_dir_override` presmeruje aj zámok, takže izolované testy nesúťažia so živým katalógom. Je **reentrantný** (hĺbkový počítadlo): druhý
`flock` toho istého súboru cez ďalší handle by sa v JEDNOM procese zablokoval sám o seba, a mutátory držia zámok cez `load + write_unlocked`. **Od 1b-6c sa nezískaný zámok
neprehliada** — `flock` vracia `false`, keď ho filesystem nepodporuje, a tichým pokračovaním by kritická sekcia bežala BEZ zámku; namiesto toho letí `IOError` a volajúci sa
rozhodne (zápis nastavení ho preloží na `false`, viď `production_core` v [outputs.md](outputs.md)). Ten istý zámok používa aj zápis **`vepo_settings.json`** — je to ten istý
priečinok a **jeden širší zámok** nevyrobí poradie dvoch zámkov ani riziko zaseknutia; kritické sekcie sú v ms a **nikdy sa cez ne nedrží modálne okno**.

### materials_migration.rb

**2A-2: jednorazová migrácia katalógu na SCHEMA 2** (štandard §7.1): `migrate_to_schema2!` — surové čítanie, kanonická mapa (heuristika len fallback s reportom), deterministický
`group_id` (GRP-SHA256, navždy zmrazený), jediná nerozhodnuteľná položka = atomický NO-OP; ostrý beh = nemenná záloha → CAS kontrola bajtov → zápis so schema 2. Od 2A-4b ju spúšťa
boot (nižšie); `Materials.test_dir_override` = izolácia katalógu VÝHRADNE pre testy.

### materials_health.rb

**2A-4a/4b: stav katalógu + ostrý cutover.** `assess_catalog!` (matica :ok | :read_only — hybrid marker 2 / novšia schéma / poškodený JSON zamknú mutácie priamo v zápisovej ceste,
čítanie beží), obnova primáru z `.bak`, `restore_pre_schema2!` (rollback: aktuálny súbor sa odloží ako `materials.rolledback-*`, nasadí sa predmigračná záloha + jednorazový
`migration_hold.json`).

**`boot_cutover!`** volá main.rb pri KAŽDOM štarte vo vlastnom chránenom bloku (zlyhanie nezhodí menu/observer; žiadny messagebox — log + bannery okna Materiály): hold →
skip+assess; legacy → ostrá migrácia; `:undecidable` → katalóg beží ďalej legacy dual-mode (mutácie sa NEzamykajú); poškodenie → read-only. `unusable_edges_count` = server-side
počet pások bez štruktúry a bez universal (banner O2). Seedy sú od 2A-4b natívne SCHEMA 2 (fresh install nemigruje).

### abs_rules.rb

pravidlové ABS defaulty podľa roly (free_panel aj rail_front/rail_back = 1 pozdĺžna 1,0 mm). Rozsah je **GLOBÁLNY** (`%APPDATA%\NOXUN\Engine\abs_rules.json`) — spoločný pre všetky
zákazky a zmena **neprestaví** už postavené skrinky (na rozdiel od pravidiel kovania, ktoré majú projektový snapshot).

**KOV-A1 — `SEED_VERSION` 2 → 3** (história: 1 = `free_panel`, 2 = D-30 dlhá hrana výstuh, **3 = roly čiel `flap` a `false_front`**). Obe nové roly majú v `SEED_RULES` **4 hrany
1,0 mm** ako dvierka a rovnaké `EDGE_LABELS` (Ľavá/Pravá/Dolná/Horná) aj `edge_sides` (`EDGE_SIDES_FRONT` — dĺžka čela beží zvisle). Bez bumpu by ich `merge_seed_roles` na
existujúcich inštaláciách **nikdy nedoplnil** (`ensure_seeded` zapisuje len keď súbor chýba) a výklop by sa postavil bez olepu. Merge doplní **len chýbajúce roly** — používateľom
upravené hodnoty ostávajú nedotknuté a jednorazová rail migrácia (`file_version < 2`) sa týmto bumpom **neopakuje**. V prehľade ABS pravidiel (sekcia `rules` Štúdia) sa nové roly
volajú **„Výklop/sklop"** a **„Blenda"** — názov roly `flap` je zámerne neutrálny, lebo tú istú rolu nesie výklop aj sklop (detail v [outputs.md](outputs.md), `ROLE_LABELS`).

**KOV-C2a — `SEED_VERSION` 3 → 4: roly dielcov zásuviek** (checkpoint #11). `drawer_bottom` je **bez ABS** (dno sadá na prírubu zargy, hrana nie je vidieť), `drawer_back`,
`box_side` a `drawer_inner_front` majú **L1 1,0 mm = horná dlhá hrana**; ostatné hrany sú vedome bez olepu, sú skryté v boxe. `EDGE_LABELS` sú per rola úprimné: dno leží
a prirodzenú „prednú" hranu nemá (neutrálne „Pozdĺžna/Priečna" ako doska), zvyšné tri STOJA a ich L1 je **Horná**. K tomu patrí **tretia mapa strán
`EDGE_SIDES_STANDING`** (`L1 → top`): stojace dielce majú dĺžku vodorovne ako ležiace, ale ich olepená hrana je HORE, takže v `EDGE_SIDES_LYING` (kde `L1 → bottom`) by 2D
karta kreslila pásku na opačnú stranu, než hovorí pravidlo aj label. `drawer_bottom` leží a lying mapu si ponecháva. Bump verzie je nutný z rovnakého dôvodu ako pri
`flap`/`false_front` — bez neho by `merge_seed_roles` roly na existujúcich inštaláciách nikdy nedoplnil a zásuvka by sa postavila BEZ olepu. Roly sú aj v
`RulesDialog::ABS_ROLE_ORDER` (na konci, za čelami) a v `ProductionCore::ROLE_LABELS` („Dno zásuvky", „Chrbát zásuvky", „Bok boxu", „Vnútorné čelo zásuvky") — prehľad ABS
pravidiel ich číta zo seedu, takže bez názvov by ukázal holé identifikátory. Dielce samotné ešte **nikto neemituje** (to je C2b).

**UI konzument od ŠT-3b-2a: skupina „ABS podľa roly dielca" v sekcii `rules` okna ŠTÚDIO — LEN NA ČÍTANIE** (editor pravidiel ABS v pluginu neexistuje a hint sekcie to priznáva).
Riadok skladá SERVER (`RulesDialog.abs_rule_row`) z `EDGE_LABELS` + `ProductionCore.role_label`; hovorí o **HRÚBKE** („predná 1,0 mm"), **nikdy o páske ani dekore** — ten sa
dopočíta z materiálu dielca až pri stavbe. Poradie rolí určuje `RulesDialog::ABS_ROLE_ORDER` (rola z novšej verzie sa pripojí na koniec, nezamlčí sa).

**ŠT-3b-2b:** k prehľadu pribudla ZÁPISOVÁ cesta „vrátiť na pravidlo" — nemaže sa jedna hrana, ale CELÝ kľúč `edges` dielca (riadok je o dielci; jednu hranu vracia karta dielca cez
„podľa pravidla"), a výsledok sa hlási zo SNAPSHOTU po prestavbe, nie z pravidla — pri potlačených defaultoch (kompakt/postforming) alebo dekore bez pásky vyjde „bez olepu" a
používateľ to vidí hneď.

**Pozor:** `AbsRules.rules` má vedľajší efekt zápisu (`ensure_seeded`) — volať LEN mimo `model.start_operation`.

**Zápis pod medziprocesovým zámkom (1d/R-08).** Modul nemá používateľský editor, ale zapisuje sám: `ensure_seeded` a **self-heal** v `rules` (normalizácia + doplnenie nových
default rolí). Aj to je „prečítaj → uprav → zapíš", takže dve inštancie SketchUpu si vedeli prepísať rolu navzájom. Od tejto dávky beží `write` pod zdieľaným sidecar zámkom
`materials.lock` (`Materials.with_catalog_lock` — mechanika a dôvody v [hardware.md](hardware.md), odsek `hardware_sets.rb`), self-heal pod ním číta súbor NANOVO a merge
prepočíta (keď ho medzitým urobila druhá inštancia, nezapisuje sa nič), a `ensure_seeded` kontroluje existenciu súboru dvakrát — rýchlo a ešte raz pod zámkom. `dir` sa od tejto
dávky pýta `Materials.dir`, takže zámok a dáta sú VŽDY v jednom priečinku aj pod `test_dir_override` (dovtedy izolovaný in-SketchUp test menil ŽIVÉ ABS pravidlá používateľa).
Zlyhaný zámok = `false`, nikdy tichý úspech. Testy: `tests/pure/test_r08_zamky.rb`.

**Brána degradovaného súboru (1d/R-11, v0.9.2).** Poškodený `abs_rules.json` s platnou `.bak` sa číta zo ZÁLOHY (recovery `JsonFileStore`) — a keďže modul sa **sám** self-healuje
(normalizácia + doplnenie nových default rolí), jeho najbližší zápis by primár prepísal obsahom odvodeným od STARŠEJ zálohy a všetky medzitým upravené role by zmizli. `write` má
preto hneď po zámku `degraded_write_blocked?` a odmietnutie vracia `false`; dôvod (celá cesta k súboru + čo s tým) je vo **`AbsRules.write_block_reason`**. Modul nemá používateľský
editor, takže hláška ide zatiaľ len do Ruby konzoly — a **iba pri ZMENE stavu**, lebo self-heal sa o zápis pokúsi pri každom načítaní pravidiel. Kontrakt `JsonFileStore.degraded?`
(priamo z disku, I/O chyby vyletia) je v [model-a-identita.md](model-a-identita.md). Testy: `tests/pure/test_r11_degradovana_zaloha.rb`.

### demos/ — Demos konektor (core/demos/*.rb)

Demos konektor (V0.6 dávky B + M-A). Jednotlivé moduly konektora majú vlastné odseky nižšie.

Params stránok pások NIE SÚ autoritatívne pre identitu rodiny dosky — parser ich môže naplniť číslom dekoru VÝROBCU PÁSKY (Rehau 79098 ≠ 5981); dekor pásky sa dokazuje slugom,
params sa na identitu nikdy nepoužijú.

### sitemap_cache.rb

~48k URL lokálne, watchdog refresh.

### slug_matcher.rb

JEDNA autorita klasifikácie typu z URL slugu — prefixy dtdl/mdf/kompakt/pd/abs…, digit guard článkov.

### name_search.rb

offline živé zhody bez diakritiky.

### client.rb

fetch, Crawl-delay 3 s, allowlist; `/vyhledavani` zakázané robots.

### product_parser.rb

HTML → parametre/kód/cena s DPH/image_url; fixtures v testoch.

### family.rb

rodina dekoru z 1 fetchu: Dosky/ABS/Mimo systému.

### lookup.rb

match variantu — bound fetch cez `demos_url` väzbu PRED sitemap fázou, D-70; pásky = dekor v slugu, brand check len dosky.

### image_cache.rb

lokálna cache fotiek dekorov.
