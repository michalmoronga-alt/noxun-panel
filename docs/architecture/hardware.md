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

**KOV-C2b (v0.9.31) — R2 EXKLUZIVITA.** `evaluate(..., suppress_slide_owners:)` dostáva množinu `owner_part_key` čiel, ktoré už majú položku výsuvu **z receptu**, a pravidlá
s `output: 'slide'` sa na nich **nevyhodnocujú** — inak by zásuvka mala dva výsuvy (jeden s kitom, jeden legacy bez dielcov). Potlačenie sa priznáva **jedným** `info`
warningom `legacy_slide_suppressed` na stavbu; Kontrola ho zámerne neukazuje (`Validation::BUILD_INFO_ONLY`) — používateľ nemá čo opravovať. Potlačenie platí aj vtedy,
keď recept skončil **konfliktom** (fail-closed: čelo nedostane ani legacy výsuv).

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
neprázdny rad `series`. Kritérium visí na **`kind`, nie na prítomnosti kľúča `bands`** — `kind` je jediná autorita toho, ktorá vetva vyhodnotenia sa spustí, a `normalize_rules`
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
- **Seed (`SEED_VERSION` 1):** Hettich · Blum · Grass · Strong · Ostatné a ich rady (Sensys, InnoTech Atira, Quadro, AvanTech YOU, AXILO; CLIP top, AVENTOS, TANDEMBOX, LEGRABOX,
  MERIVOBOX, TIP-ON; Nova Pro, Tiomos; StrongMax). Merge dopĺňa LEN chýbajúce mená, nikdy neprepisuje a nad read-only ani degradovaným súborom sa nerobí; `ensure_seeded` má
  DVOJITÝ check (rýchly + pod zámkom), takže oneskorený seeder neprepíše reálnu zmenu.
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
(classic|tipon|other, kde `other` = „neuplatňuje sa" pri nohách, podperkách a zavesení) · `drawer_construction` (metal|wood|other, **len pri zásuvke**) · `manufacturer` ·
`series` · `active`. Slovníky sú UZAVRETÉ (neznáma hodnota = obsah novšej verzie, nie nová kategória) a s čelami držia JEDNU doménovú pravdu — `Fronts` sa načítava PO
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

**Marker `std` má TRI hodnoty a je LAZY podľa obsahu.** `1` = len legacy tvary · `2` = pásma člena alebo selector v mapovaní (GH #131) · **`3` = set s KTORÝMKOĽVEK kľúčom mimo
`LEGACY_SET_KEYS`** (každé klasifikačné pole aj `active` samostatne) **alebo mapovanie s triednym kľúčom `class:`**. Čisto legacy obsah ostáva na svojom pôvodnom std, takže
spätná čitateľnosť sa zbytočne neblokuje; obsah so `std: 3` je pre starší plugin `:read_only` (knižnica) a `:invalid` (snapshot) — NIKDY čiastočné čítanie. Tú istú funkciu
(`snapshot_std`) používa zápis knižnice aj zápis snapshotu: marker musí hovoriť o obsahu rovnako v `%APPDATA%` aj v .skp.

**TRIEDNY kľúč mapovania `class:<generic_type>|<opening_mode>[|<drawer_construction>]`** (KOV-B1, pripravené pre KOV-D — „výsuvy TipOn majú iný set než klasické"). Tvar je
uzavretý: tretí segment má LEN `slide`, `@owner` sufix je zakázaný (výber na úrovni dielca je iný pojem), segmenty sa trimujú a downcasujú. Pozná ho **jediný parser**
(`parse_mapping` ho rozpozná PRED `parse_hardware_set_key`), prijímajú ho všetky mapy (globálna, snapshot aj cabinet override), počíta s ním whitelist brány, `snapshot_std`,
`referenced_set_ids` aj `mapping_types_by_set` — ale **`resolve_set_id`, `expand` ani `explain` ho NEČÍTAJÚ** a zapisovacie cesty ho nepíšu. Účelom tejto dávky je výhradne
**bezstratový round-trip** a správny marker, takže KOV-D už nebude potrebovať ďalší bump. `BuildPlan.hardware_set_key_type` z neho vracia prvý segment (starší plugin prefix
nepozná, takže mu z toho istého kľúča vyjde neznámy typ a prestavbu zablokuje — presne to chceme), `BuildPlan.parse_hardware_set_key` vracia `nil`.

**KOV-C2b (v0.9.31) — RECEPTOVÁ POLOŽKA A RED `drawer_kit_missing`.** Zásuvkovú položku už **emituje** `Construction` (`source: 'recipe'`, `rule_id: recipe:<recipe_id>`,
`quantity: 1`, voliteľné `locked: true` pri platnom NL zámku). Pre výber setu platí presne mechanika C2a nižšie; navyše: **každý** dôvod nemapovania sa pre `source: 'recipe'`
povyšuje na **RED `drawer_kit_missing`** (`unmapped_entry`), pôvodný dôvod cestuje v `base_reason` a text skladá `unmapped_reason_sk` z NEHO (žiadny druhý preklad tých istých
príčin). Dôvod: dielce sú už postavené na konkrétnu NL — chýbajúci kit nie je „nenacenené kovanie", ale **nevyrobiteľná** objednávka, preto blokuje aj VEPO.
`note_manual` berie `locked: true` ako dnešné `source: 'manual'` (dĺžka je ručne určená); bez zámku receptová položka znamienko NEMÁ (Astra #19 N11).

**KOV-C2a (v0.9.30) — TRIEDNY KĽÚČ SA ZAČAL ČÍTAŤ, `height_variant`, `MAPPING_ADDITIONS`, `std` 4.** Príprava aktivácie zásuviek: mení sa výber setu pre položku, ktorá nesie
klasifikáciu zásuvky, ale **žiadne dnešné pravidlo ju nenesie**, takže výstupy existujúcich zákaziek boli CONTENT-identické (stráži to golden `seed_kniznica` aj vlastný
charakterizačný test). Päť častí:

- **Kto je „zásuvková" položka.** `class_key_for(it, gt)` = položka má v `params` OBE polia `opening_mode` a `drawer_construction` → kanonický kľúč
  `class:slide|<opening_mode>|<drawer_construction>`. Inak `nil` a celá vetva je mŕtva.
- **Precedencia je KRATŠIA a bez fallbacku.** Pre takú položku číta `resolve_mapping_value` **cabinet override s triednym kľúčom → projekt**, a keď mapovanie chýba, vráti
  `nil` s dôvodom **`class_unmapped`** („Pravidlá → Doplniť nové predvoľby"). Na generický `slide` **NIKDY nepadne** — H70 kit k zásuvke H176 by bol zlý nákup, a mlčky.
  Owner-level `slide@…` sa pre ňu vedome IGNORUJE (`class:…@owner` parser odmieta a generický `slide@owner` je práve ten zakázaný fallback; owner-scoped tvar definuje až KOV-D).
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
- **Kompatibilita vybraného setu (`set_incompatible_info`)** beží v `expand` AJ v `explain` (panel a súpis sa nesmú rozísť) hneď za `set_type_mismatch` a porovnáva
  `opening_mode`, `drawer_construction`, **`manufacturer` + `series` ↔ `params.system`** (uzavretý `SYSTEM_IDENTITY`: `atira` → Hettich/InnoTech Atira, `quadro_v6` →
  Hettich/Quadro; neznámy systém = fail-closed) a **`height_variant` setu ↔ `params.height_variant`** (presne, bez zaokrúhľovania). Bez toho by triedny kľúč sám nedokázal, že
  set patrí k TOMUTO systému a TEJTO výške — Antaro/StrongBox raz budú zdieľať `class:slide|classic|metal` s Atirou a pásmo H176 vs. H70 má rovnaké NL 470. Nesúlad =
  **nemapovaná položka s dôvodom, NIKDY iný set**; nové ORANGE dôvody `class_unmapped` a `set_incompatible` majú vety v `unmapped_reason_sk` aj vo
  `Validation.check_hardware_expansion`. Povýšenie na RED `drawer_kit_missing` prinesie C2b.

Testy: `tests/pure/test_kovc2a_kanal_sety.rb` (23 testov + 4 overené mutácie vrátane completeness nad radmi receptov: pre KAŽDÚ bunku `nl_series_by_height`/`nl_series` každého
vydaného receptu existuje v seede set vybraný triednym kľúčom a v ňom kit kód).

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

**Register brány `DRAWER_BLOCKERS` (11 kódov)** = `CONFLICT_CODES` (10, ktoré produkuje resolver) **+ 1 MIGRAČNÝ**. Delí sa na `BUILD_BLOCKERS` (9 fail-closed konfliktov
STAVBY: zásuvka nevydala ani dielec ani položku) a `ALL_EXPORT_BLOCKERS` = `drawer_kit_missing` (vzniká až v NÁKUPE) **+ `drawer_stale`** — jediný kód, ktorý neprodukuje
resolver ani nákup, ale **čítanie modelu** (`Bom.collect`): skrinka uložená pred aktiváciou receptov (`config_schema < CabinetBuilder::DRAWER_ACTIVATION_SCHEMA`) má
klasifikovanú zásuvku, takže v .skp **nie sú** receptové dielce a výsuv je legacy — kusovník aj VEPO by boli neúplné a ticho. Nápravou je **prestavba** skrinky.
`BLOCKER_LABELS` drží krátky slovenský názov pre bránu exportu — plnú vetu (ktorá hodnota kde nesedí) skladá recept a nesie ju nález Kontroly.

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
`[:unknown, id]` (RED `drawer_recipe_unknown`) · `[:missing, nil]`.

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
neprázdne `ctx[:obstructions]` → `drawer_obstruction` · **jedna výška** (Atira: najvyšší variant s `min_clear_height ≤ clear_height`; Quadro: `box_height = clear_height − 40`
a čelo/chrbát `box_height − t_dna − 12 ≥ 30`) · **jedna NL** (najdlhšia z radu TEJ výšky s `min_depth ≤ clear_depth`) · **NL zámok** z `hardware_overrides`
(`generic_type slide`, `rule_id` `vysuvy-nl-podla-hlbky` alebo `recipe:<id>`, pole `nominal_length`): v rade a zmestí sa → drží, inak `nl_lock_invalid` — **nikdy tichá
zmena**; záznam s `disabled: true` zámok **nenesie** (ten istý kontrakt ako `HardwareRules.override_nominal_length`) · nosnosť bunky · dielce · kontrola každého rozmeru
proti `MIN_DIM`. Porovnania sú **inkluzívne a bez EPS** nad nezaokrúhlenou hodnotou z `context_for`
(105,00 platí, 104,995 padá). **Atomicita:** akýkoľvek konflikt ⇒ `parts = []` a `hardware_params = {}`.

**Dielce.** Atira presne 2: `drawer_bottom` `(LB − 2·EB − 51,5) × (NL + 10)` a `drawer_back` `(LB − 2·EB − 63) × rear_height`. Quadro 5: `box_side` ×2 `NL × box_height`,
`drawer_bottom` `SKW × NL`, `drawer_inner_front` a `drawer_back` `SKW × (box_height − t_dna − 12)`, kde `SKW = LB − 46`. ABS per rola z receptu (dno bez, ostatné horná dlhá
hrana 1,0). `hardware_params` (`recipe_id`, `system`, `height_variant` | `box_height`, `nominal_length`, `load`, `opening`) je podklad pre **jednu** položku výsuvu, ktorú
skladá C2. `explain` sú slovenské vety pre Inspector.

**`CONFLICT_CODES`** = register 10 kódov brány `DRAWER_BLOCKERS` z package KOV-C. C1 ich len **produkuje**; napojenie na `export_blockers`, `hardware_issues` a Kontrolu je
úloha C2 — v C1 preto `drawer_kit_missing` ani `drawer_override_invalid` nikto nevyrába, sú tu len ako jediné miesto pravdy o množine kódov.
