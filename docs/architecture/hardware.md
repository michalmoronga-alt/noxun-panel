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

**Katalóg je GLOBÁLNY** (`%APPDATA%`), takže nezávisí od dokumentu — zákazky sa dotýka až cez sety (`hardware_sets`, projektový snapshot na modeli).

**Od ŠT-3a-2 ho ukazuje JEDINÉ UI:** sekcia `hw` okna Štúdio (Š16 — pohľady Položky · Sety). Okno „Katalóg kovania" ZANIKLO; serverová autorita ostala v
`hardware_catalog_dialog.rb` (modul sa NEPREMENOVÁVA — vzor audit #21 zo ŠT-2a), a to vrátane **troch MODELOVÝCH zápisov** predvolieb setov projektu (`hws_map_project` ·
`hws_merge_seed` · `hws_reset_project`), ktoré sú od tejto dávky v `SECTION_ACTIONS`. Každý z nich je `start_operation` … `commit_operation` (**1 zmena = 1 krok Späť**) a každý má
serverový `model_guid` guard — zápis zo zastaraného UI sa odmietne a stav sa obnoví (`resync_sets`).

## Bez vlastného odseku

### hardware_sets.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Sety kovania + projektový snapshot predvolieb na modeli; zmienky sú v odsekoch `hardware_rules.rb` a `hardware_catalog.rb` a v [ui-lifecycle.md](ui-lifecycle.md) (sekcia `hw`
Štúdia).

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
