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

**Člen účtovaný na vlastníka a jeho stopa v riadku (P0-HF, review #252 P2).** `expand_members` počíta člena `per: 'unit'` ako `quantity × qty`, ale člena **`per: 'owner'`** len
**raz na `[owner_id, owner_part_key, set_id, code]`** (audit B3: druhé pravidlo s tým istým vlastníkom TipOn nezdvojí). Práve tento dedup je **jediný mechanizmus, ktorým dve
fyzické skrinky so zdieľaným `cabinet_id` dostanú položku raz namiesto dvakrát** — a teda jediný dôvod, prečo duplicitná identita smie zastaviť nákupný/cenový export. Aby to brána
vedela rozhodnúť namiesto hádania, `add_row` značí zdroj riadku príznakom **`per_owner`**: kľúč je **aditívny**, zapisuje sa **len keď je pravdivý**, a má presne jedného čitateľa —
`ProductionCore.dup_partition` ([outputs.md](outputs.md)). Bez neho by sa blokoval aj export zákazky, ktorá má samé `per: 'unit'` členy a spočíta sa správne aj so zdieľaným ID.
