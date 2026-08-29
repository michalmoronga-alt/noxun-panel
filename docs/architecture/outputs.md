# Výstupy — kontrola, kusovník, VEPO, nákup a rozpočet

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Kontrolný semafor a zdieľané čisté jadro výstupov zákazky. Kontrakt plánu, z ktorého všetky výstupy čítajú, žije v [model-a-identita.md](model-a-identita.md) (`build_plan.rb`,
`part_keys.rb`); UI sekcie Štúdia, ktoré tieto výstupy zobrazujú, sú v [ui-lifecycle.md](ui-lifecycle.md).

### validation.rb

**kontrolný semafor (V0.5-D):** RED = materiál mimo katalógu / hrúbkový drift / nezmestí sa na platňu (s rešpektom smeru dekoru) / ABS páska hrany mimo katalógu (2A-2 `abs_missing`
— len keď volajúci dodá ABS katalóg cez `edges:`) · ORANGE = čelo/voľná doska bez ABS „skontroluj" / vypnuté kovanie (owner_part_key identita) / build warnings / **`duplicate_identity`
(1b-3): dva top-level kusy toho istého druhu so ZHODNÝM ID** — kópia, ktorej ešte nikto nepridelil vlastnú identitu. Hlása ID, počet kusov aj výrobný dôsledok (záznamy oboch kusov
majú rovnaké `owner_id`, takže expanzia setov s `per: 'owner'` započíta položku LEN RAZ — do objednávky by šlo menej kovania). Vstup je `identities:` z `Bom.collect` (jeden záznam na
INŠTANCIU; `nil` = kontrola sa preskočí, vzor `placements:`), klik-adresa je zdieľaná s D-103 (`dup_kind` + `dup_owner_ids` → `pids_for_duplicate`). Dôsledok sa hovorí **podmienene**
(precedens `CAT_MATERIAL`): zliatie vlastníkov v kusovníku platí vždy, podpočítané kovanie len pri sete s členom účtovaným na vlastníka. **Nikdy sa nič neopravuje** — oprava patrí
zápisovej ceste (`fresh_collect` nižšie). Kritérium má **jeden zdroj**: verejná `Validation.duplicate_identities(identities)` → `[[kind, id, počet], …]`, z ktorej stavia nálezy
Kontroly **aj** varovanie statusu exportov, ktoré `Validation.run` nevolajú (odsek `production_core.rb`). JEDINÝ kanonický
zoznam; deterministický dedup + counts VÝHRADNE zo servera; sekcia KONTROLA v Štúdiu s klik-selectom cez stabilnú identitu a fallbackom na vlastníka; sekcia KONTROLA vo VEPO LOGu;
**RED nikdy neblokuje export** — semafor varuje, nezastavuje. *(Jedinou výnimkou v celom repe je finálny zápis súboru s cenou alebo objednávkou: `duplicate_identities` má od P0-HF
dva verejné pohľady — `duplicate_owner_ids` (len `KIND_CABINET`, zlieva vlastníkov kovania → **zastaví zápis**, odsek `production_core.rb`) a `duplicate_plain_ids` (zvyšok →
len varovanie). Podmienka je tá istá, aká rozhoduje o znení nálezu v `duplicate_id_item`, takže sa hláška a brána nemôžu rozísť.)*

### production_core.rb — zdieľané čisté jadro výstupov zákazky (ŠT-1a PR A)

kusovník, súpisy platní/ABS a VEPO export sa sťahovali z okna Výroba do nového okna **Štúdio**; aby obe okná čítali **tie isté čísla**, čistí pomocníci prešli do jedného modulu
`Noxun::Engine::ProductionCore` (`module_function`).

**Od ŠT-1c PR B3, keď okno Výroba zaniklo, je jadro JEDINOU implementáciou** — Štúdio aj rail Inspectora ho volajú priamo.

Sú tam: **VEPO rodina** (`vepo_settings`/`save_vepo_settings` nad `%APPDATA%\NOXUN\Engine\vepo_settings.json`, `vepo_materials` s celou kaskádou rozlíšenia labelov,
`vepo_base_label`, `vepo_disambiguate`/`vepo_disambiguate_variants`, `vepo_group_key`, `vepo_edge_thicknesses`, `default_project_name`), **mapy katalógov** pre `Validation.run`
(`sheets_map` → `{}` pri chybe, `edges_map` → **`nil`** pri chybe, lebo prázdna mapa by falošne označila každú olepenú hranu), identita dokumentu `model_guid` a **výberové
resolvery** klik→entita (`pids_for_problem` vrátane fallbacku na vlastníka pri nepostavenom dielci, `pids_for_duplicate` pre D-103, `refs_for` — od ŠT-2d aj vetvy
`material_key`/`abs_key` s nepovinným `owner_id`, ktoré hľadajú dielce podľa **efektívneho materiálu z BOM** pre „Kde sa používa"; detail v odseku sekcie MATERIÁLY; **od ŠT-3b-2a
`pids_for_override`** — oko pri jantárovom riadku sekcie Pravidlá adresuje dvojicou **(owner_id, part_key)** a **znovupoužíva telo `pids_for_problem`** [prázdny kľúč = celý
korpus]; vetva `rule_ref` v `do_select` je vlastná zámerne — override v kusovníku vlastný riadok mať nemusí, napr. vypnuté kovanie; od ŠT-3b-2b beží **bez `fresh_collect`** — hľadá
podľa identity, takže plný sken modelu bol čistá réžia).

**ZÁVÄZNÝ kontrakt modulu: žiadny okenný stav** — `@dialog`, `@generation` ani `@pending_*` sem nepatria (dve okná nad jedným jadrom by si ich prepisovali); stráži to guard test,
ktorý v `production_core.rb` nepripustí ani jednu inštančnú premennú. Do ŠT-1c PR B3 si `ProductionDialog` ponechával **tenké obaly s pôvodnými menami, signatúrami AJ
privátnosťou** (aby bol refactor bez zmeny správania); s oknom zanikli a volajúci — panel, pure testy aj in-SketchUp runner — idú na jadro priamo. Loader (`main.rb`) načítava jadro
**PRED** oknom Štúdio, ktoré ho volá.

**PR B dávky ŠT-1a sem doplnil aj TELÁ akcií** — `fresh_collect`, `hardware_expansion`, `control_suffix` a hlavne `do_export`/`do_select`: obe okná robia presne to isté, len s
vlastným stavom, takže okno odovzdáva svoj kontext **explicitne** (`generation:` — token guardu B4 · `status:` — lambda do TOHO okna · `repush:` — „obnov, ak žiješ"). Dva takmer
rovnaké exporty by sa časom rozišli a rozdiel by sa ukázal až na výrobnom výstupe.

**`fresh_collect` JE ČISTÉ ČÍTANIE (1b-3, brána G bloku 1b) — telo je `Bom.collect(model)` a nič viac.** Z tejto cesty sa **nesmie** zapísať do modelu, otvoriť operácia ani
pribudnúť krok Späť; platí to pre „Obnoviť", `push_state`, klik-select aj všetky štyri exporty. Stráži to guard test `tests/pure/test_1b3_citanie.rb`, ktorý v **celej UI vrstve**
nepripustí volanie `dedup_copies` (formulácia nad priečinkom, nie nad zoznamom mien metód). *Do 1b-3 tu bežal dedup tik — vznikol 19.7.2026 (GH #48 P2) ako zrkadlo vtedajšieho
`Panel.push_selected`, ktorý dedup tiež vykonával priamo; ten sa toho 9.8. vzdal (D-103) a od vtedy opravu len ŽIADA u observera, kým čítacia cesta si ju držala ďalej. Obyčajné
„Obnoviť" tak potichu prečíslovalo ID kópií a pridalo krok Späť.* **Oprava identity žije výhradne v ZÁPISOVEJ ceste:** dedup tik `ScaleWatch` po kopírovaní (transparentný ku kroku
používateľa) a `Panel.push_selected` po zápise z panela (`ScaleWatch.request_dedup`). Kým oprava nedobehne, duplicitnú identitu **prizná Kontrola** (`duplicate_identity`, ORANGE). Guard preto zakazuje v tomto module
**aj token `request_dedup`** (oneskorená oprava je stále oprava) a pripúšťa `Panel.push_selected` výhradne s `dedup: false`; to isté platí pre `studio_dialog.rb`.

**Nález v Kontrole však NESTAČÍ (review #240 P2-1):** kto klikne „Nákupný zoznam kovania", sa do Kontroly nepozerá — a práve to CSV ide dodávateľovi. Exporty, ktoré `Validation.run`
nevolajú, preto skladajú vlastné varovanie: **`dup_id_suffix(collected)`** (strop tri ID + „a ďalšie N", vzor `control_suffix`) ide do statusu `do_hw_csv` a `do_budget_xlsx`
a **zároveň farbí status na varovanie**. **Cenová ponuka sufix NEMÁ** — má vlastný zoznam dôvodov `cp_warnings` (GH #139: jeden zoznam, ktorý riadi aj farbu), takže duplicita ide do
neho; jeho posledný parameter `collected` je nepovinný (legacy volanie nič nemení). **VEPO sufix nemá tiež** — `Validation.run` volá, takže nález už nesie `control_suffix` aj sekcia
KONTROLA vo VEPO LOGu.

**FINÁLNA BRÁNA PRED ZÁPISOM SÚBORU (P0-HF, externý Codex audit 29.8.2026).** Spoločný koreň oboch P0 nálezov bol jeden: **systém poznal chybný finálny výstup a napriek tomu ho
uložil.** Rozpočet aj cenová ponuka sa zapísali na disk a AŽ POTOM sa vyhodnotilo, že riadky nemajú cenu, že „Nábytková zostava" vyšla záporná alebo že suma nesedí s rozpočtom;
nákupný CSV rovnako vznikol aj nad zliatymi vlastníkmi kovania. Súbor, ktorý už existuje, sa dá odoslať dodávateľovi aj zákazníkovi — červený status pod ním prišiel neskoro. Brána
sa volá **pred `savepanel`** (picker sa pri chybe ani neotvorí) a má **dve vetvy**, ktorých rozdiel je záväzný:

*(1) TVRDÁ — `export_blockers(collected:, cp:)`.* Stavy, ktoré sú VŽDY chyba a **nedajú sa potvrdiť**: duplicitné ID **skrinky** (`collected:` — CSV kovania, rozpočet, ponuka),
záporná „Nábytková zostava" a nesúlad ponuky s rozpočtom (`cp:` — len ponuka). Nedáva zmysel poslať dodávateľovi objednávku, o ktorej vieme, že je podpočítaná. Hláška
`export_blocked_status` musí povedať **oboje**: že súbor NEVZNIKOL (inak ho používateľ ide hľadať na disk) a **prečo + kde to opraviť**.

*(2) POTVRDITEĽNÁ — `export_confirmations(budget:)`.* Dnes jediný dôvod: **riadky bez ceny**. STANDARD §11.3 hovorí, že neznáma cena sa NIKDY nenahradí nulou, ale má sa **priznať**
(„medzisúčet je len zo známych cien a súhrn nahlas povie, že nie je úplný") — **rozpracovaný rozpočet je legitímny stav zákazky** a plošný tvrdý blok by používateľovi bral výstup,
na ktorý má právo (nález Codex review PR #250 proti auditu). Default je teda zastavené, ale **cesta von existuje**: `export_confirm_status` ponúkne druhý klik, ten pošle
`confirm_unpriced` a hotový súbor podhodnotenie **prizná v statuse** (`export_confirmed_notes`; status ostáva červený). **Potvrdenie overuje SERVER** (`export_confirmed?` — presne
`true`, nie „true"), takže starý DOM ani cudzí volajúci nemajú ako podhodnotený súbor vyrobiť ticho; klient (`budNeedsConfirm` v `js/budget.js`, dva nezávislé kľúče pre rozpočet
a ponuku) je len UX a jeho ozbrojenie **ruší každý čerstvý payload** (`NX.setStudio` → `budDisarm`) — potvrdenie platí pre čísla, ktoré používateľ videl.

**Je to VEDOMÉ PREVRÁTENIE rozhodnutia dávky 1b-3** („export dobehne + červený status"), ktoré charakterizoval `tests/pure/test_1b3_citanie.rb`. Rozdiel je v predmete: 1b-3 riešila
**nález Kontroly** (varovanie o modeli), táto brána **číslo v hotovom platnom dokumente**. Semafor sa nemení — **KONTROLA naďalej len varuje a nikdy neblokuje** (RED nezastaví ani
VEPO); výnimka platí VÝHRADNE pre finálny zápis súboru s cenou alebo objednávkou. **VEPO bránu nedostáva** (audit ho výslovne vyníma): je to rezací výstup, nie cena ani objednávka,
duplicitná identita jeho čísla neskresľuje a chybné riadky vyhadzuje sám do LOGu — blokovať ho bez samostatného dôkazu by len zastavilo výrobu. **Firewall interných pojmov bránou
tiež nie je** (STANDARD §11.3: hlási a neblokuje) a počíta sa až nad hotovým hárkom.

**Predikát MUSÍ rozlíšiť skrinku od dosky.** Kovanie účtované na vlastníka (`per: 'owner'`) podpočíta len zliatie **skriniek** — doska kovanie nemá, takže objednávke nehrozí nič
a export ju nezastaví; kusovník ju však s dvojníčkou zlieva, preto sa prizná ako **neblokujúce** varovanie. `dup_id_suffix` aj `cp_warnings` preto od P0-HF hovoria **len o doskách**
a vetu o kovaní nemajú (do 29.8. `kind` zahadzovali a tvrdili ju aj nad doskou — seed A7 sweepu). Kritérium má **jeden zdroj** v `validation.rb`: `duplicate_owner_ids`
(blokuje) a `duplicate_plain_ids` (varuje) sú dva pohľady na tú istú `duplicate_identities`. Tvrdé dôvody tým **vypadli z `cp_warnings`** — jeden dôvod žije v jednom zozname,
dva zoznamy o tej istej veci by sa časom rozišli; `cp_warnings(hits, collected, confirmed)` drží už len firewall, duplicitnú dosku a **potvrdené** riadky bez ceny. Kontrakt strážia
`tests/pure/test_p0hf_brany.rb` (pri každom dôvode sa meria **prázdny priečinok**, nie text statusu) a `tests/js/test_p0hf_potvrdenie.js` (dvojkrokový klik).
`do_select` navyše pozná príznak **`focus_inspector`** (ceruzka riadku Kusovníka, Š3): po výbere zdvihne Inspector cez `Panel.bring_to_front` — **nikdy ho neotvára**, výber sa tým
nemení a do modelu sa nezapisuje nič.

**`project_names` (ŠT-1a, audit #1):** názov projektu je od tejto dávky **serverový údaj** — mapa v `vepo_settings.json` (nastavenie POČÍTAČA, žiadny zápis do modelu, žiadny krok
Späť).

**Kľúčom je NORMALIZOVANÁ CESTA súboru, nie `model.guid`** — SketchUp guid **mení po každom uložení** modelu, takže na guid kľúči by sa názov po Ctrl+S ticho stratil a v súbore by
rástli mŕtve záznamy (nález review P1). Normalizácia je `\`→`/` + `downcase` (Windows nerozlišuje ani veľkosť písmen, ani smer lomítka).

**Neuložený model cestu nemá** a dostane náhradný kľúč `guid:<guid>`, ktorý platí len v rámci sedenia; čítanie naň padá ako na záložku (pomenoval som Untitled a potom ho uložil) a
**prvý zápis s platnou cestou ho zmigruje** — záznam sadne na cestu a guid kľúč sa zmaže.

**Ctrl+S ale mení cestu AJ guid NARAZ (1b-6a):** po prvom uložení sa záznam pod *starým* guid kľúčom z modelu už nedá nájsť — záložka hľadala `guid:<nový guid>` a našla prázdno,
takže názov zadaný pred prvým uložením sa ticho stratil a všetky štyri exporty sa pomenovali podľa `.skp` súboru namiesto zákazky (výrobná P2). Most drží **pamäť procesu**
`SESSION_KEY_BRIDGE` (`object_id` modelu → posledný kľúč sedenia, pod ktorým sa názov zapísal), overená **identitou objektu** (`equal?`, čisté porovnanie referencií) — cudzí
dokument rozrobený názov zdediť nemôže, Windows SketchUp pri File > New/Open model zničí a vytvorí nový. Prvé čítanie po uložení záznam **adoptuje a hneď zmigruje na cestu**
(`adopt_session_name`) a most sa spotrebuje; **bez migrácie** by názov žil len do konca sedenia a po reštarte by sa stratil aj tak. Kľúče sedenia sa spotrebujú pri prvom čítaní s
platnou cestou **vždy** — aj keď cesta už svoj názov má: ten **má prednosť** a rozpísaný názov ho neprepíše, ale musí zaniknúť, inak by sa o pár minút vynoril pri „Uložiť ako" na
čerstvej ceste (review #243 P2-2). Most sa zahadzuje **až po úspešnom zápise** — `save_vepo_settings` vracia `true`/`false` a pri zamknutom súbore či plnom disku ostáva most nažive,
takže sa migrácia zopakuje hneď, ako zápis prejde (review #243 P2-1). Zápisová cesta upratuje to isté
(`save_project_name` maže VŠETKY kľúče sedenia zákazky, nielen ten podľa aktuálneho guid). Most **nie je zakázaný okenný stav**: nie je to stav okna ani medzivýsledok výpočtu, ale
údaj o dokumente, ktorý sa z modelu po uložení prečítať nedá — obe okná z neho čítajú to isté a nemajú si ho ako prepísať; je to konštanta (nie `@ivar`) aj kvôli guard testu, ktorý
tu inštančné premenné nepripúšťa, a je zhora ohraničená (`SESSION_BRIDGE_MAX`). Prázdna hodnota **aj hodnota zhodná s defaultom zmaže záznam**, takže sa pomenovanie vráti
na názov `.skp` a premenovanie súboru sa v okne prejaví samo. Číta ho **všetky štyri exporty** (VEPO, CSV kovania, XLSX rozpočtu, XLSX cenovej ponuky) — z DOM sa `project`
**prestal posielať**, inak by dve okná mali dve pravdy a tá istá zákazka by sa v dvoch výstupoch volala inak. `merge_18_36` ostáva globálny a číta sa rovnakou cestou.

**Zápis `vepo_settings.json` má JEDNY dvere (1b-6c):** súbor je nastavenie POČÍTAČA so **šiestimi zapisovateľmi** — `save_merge_18_36`, štyri zápisy `last_dir` (VEPO, CSV kovania,
XLSX rozpočtu, XLSX cenovej ponuky) a mapa `project_names` — a menil sa read-modify-write **bez medziprocesového zámku**. Dve inštancie SketchUpu zdieľajú jeden `%APPDATA%`, takže
zápis jednej vedel zmazať zákazku pomenovanú v druhej; `JsonFileStore` rieši **atomicitu** (tmp+rename, `.bak`), **nie súbeh** — a jeho sekundová cache navyše skryje čerstvý zápis
suseda. Každý zápis preto ide cez **`update_vepo_settings`**: `Materials.with_catalog_lock` (jeden sidecar `.lock` nad tým istým priečinkom, reentrantný — detail v
[materials.md](materials.md)) + čítanie súboru **nanovo vnútri zámku** (`JsonFileStore.reload!`); blok dostane čerstvé nastavenia a vráti hash na zlúčenie, `nil` = netreba
zapisovať. **Čítania sa nezamykajú** (hot push panela by zámok platil zbytočne), ale **štyri exporty si na začiatku vypýtajú čerstvý súbor** (`refresh_vepo_settings`) — hotový
CSV/XLSX sa už ďalším čítaním nezahojí. Zámok sa cez export **zámerne nedrží**: cesta otvára modálny `savepanel` a druhá inštancia by čakala, kým používateľ klikne.

**Štyri pravidlá tých dverí, každé zaplatené nálezom auditu:** *(1)* zápisová cesta číta **strikto** (`vepo_settings_for_write`) — lenivé `{}` z neprečítateľného súboru by sa
zlúčilo s novými `attrs` a zmazalo `project_names`, `merge_18_36` aj `last_dir`; chýbajúci súbor je legitímne prázdno, existujúci a nečitateľný (alebo nie-Hash) **zastaví zápis**.
*(2)* Celá zamknutá úprava je v `rescue` — aj zlyhanie `.lock` je len zalogovaný `false` (kontext logu nesie **fázu** lock/read/block/write), nikdy výnimka do okna či exportu.
*(3)* Mapu názvov cez `save_vepo_settings` **zapísať nejde** (odovzdaný odtlačok by čerstvú mapu prepísal celú) — na to je `update_project_names`, ktoré blok kŕmi čerstvou mapou;
stráži to guard test. *(4)* Názov sa počíta **aj pred zámkom**: keď sa `.lock` nedá vziať, blok pod ním nikdy nebeží, a bez tohto fallbacku by všetky štyri exporty dostali meno
`.skp` súboru namiesto zákazky. Keď blok **bežal**, `project_name` vracia **čerstvú** hodnotu spod zámku (`effective_project_name` nad čerstvou mapou) — inak by sa export
pomenoval podľa `.skp` napriek tomu, že súbor už drží správny názov (review #243, kolo 3).

**`materials_meta`/`edges_meta` (audit #4)** sú kontrakt skupín Kusovníka: per `material_id` (resp. `abs_id`) label, katalógová farba ako **pole `[r,g,b]`** (nie CSS reťazec —
prevod robí klient, ktorý farbu kreslí), hrúbka a príznak UNI; materiál mimo katalógu sa pomenuje **svojím ID** a farbu nedostane (radšej žiadna vzorka než náhodná).

**Menovka skupiny musí byť JEDNOZNAČNÁ (1b-6b, triáž #33):** `material_label` je len ľudský názov dekoru (číslo + štruktúra + názov), takže dva **rôzne výrobné materiály** —
iný výrobca, typ, formát platne alebo rub zásteny — z neho dostali identickú hlavičku, a práve podľa nej sa v Štúdiu objednáva. Menovky preto skladá `material_labels`
(resp. `edge_labels` pre pásky) **kolíznym pásom**: bez kolízie je výsledok bajtovo dnešný text (bežná zákazka žiadny šum navyše nedostane), pri kolízii sa eskaluje na
**panelovú menovku** — `Panel.raw_row_label` (výrobca pri kolízii cez `label_base` + prípona formátu/rubu `Materials.sheet_label_suffix`) → `Panel.sheet_label` (navyše typ
a hrúbka: ten istý dekor v DTDL aj kompakte) → poistka `[material_id]` (vzor VEPO: dve hlavičky sa nesmú zliať ani nad nezmyselným katalógom); pásky eskalujú na
`Panel.abs_label` (štruktúra + výrobca pri kolízii). **Žiadna vlastná logika menoviek vo výstupoch** — panel a výstupy nesmú mať dve pravdy o tom, ako sa materiál volá.
**Kolízny kľúč je to, čo riadok skupiny UKÁŽE: menovka + hrúbka** (hrúbka má v hlavičke aj v súpise Platní vlastné miesto), takže dve hrúbky toho istého dekoru — najbežnejší
prípad zákazky — rozlíšenie nedostanú. Kontext kolízie výrobcov (`Panel.label_ctx`) sa stavia **až pri prvej kolízii** (sentinel `:panel`), takže nekolízna zákazka kvôli
hlavičkám katalóg nečíta vôbec; jeho zlyhanie sa len zaloguje a menovky ostanú dnešné. Stráži to `tests/pure/test_1b6b_hlavicky.rb`. *Rozpočet a cenová ponuka majú vlastné
menovky (`Budget.sheet_label`, `CpExport.material_label`) — sú v `core/`, kam panelový aparát nedosiahne, a ostávajú kandidátom pre audit 1c.*

**`rows_with_roles`** dopĺňa voliteľný stĺpec „Rola" **read-only obohatením** — záznamy sa zoskupia TÝM ISTÝM `Bom.row_key`, akým vznikli riadky, pretože pridať rolu do kľúča
agregácie by zmenilo kusovník **aj VEPO** (a párovanie beží cez Ruby hash: kľúč riadku je POLE, v JSON by sa už nespárovalo). SK názvy rolí sú `ROLE_LABELS` — jedna autorita, JS
žiadny preklad enumu nemá.

**ŠT-1b sem pridala celý zvyšok KONTROLY: `control_payload`** (Validation.run nad čerstvým zberom **+ zlúčenie s upozorneniami rozpočtu cez `Validation.with_budget`**) je **jediné
miesto, kde vzniká číslo semaforu** — číta ho sekcia Kontrola v Štúdiu, badge navigácie **aj `do_export`** (status aj sekcia KONTROLA vo VEPO LOGu; do review #1 mal export vlastný
`Validation.run` **bez** rozpočtových nálezov a hlásil preto iné číslo než semafor), takže žiadne z týchto miest nemôže ukázať vlastné číslo; s ním sem prešli aj `budget_payload` a
`hardware_catalog_items` (rozpočet sa počíta kvôli svojim ORANGE nálezom, hotový odhad platní sa mu odovzdáva, aby nevznikol druhý výpočet).

**`replace_uni`** (skratka „Nahradiť UNI…" → `MaterialsDialog.request_replace_uni`) a **zdieľané telá prepínačov** `edge_check_guard` (dostupnosť Overlay API + `identity_guard`) ·
`identity_guard` (generácia okna + dokument — zdieľa ho aj kresba, ktorá si dostupnosť overuje **vlastnú** a hlási ju vetou o kresbe, nie o hranách) · `do_edge_check` ·
`do_edge_check_option` · `do_grain_check` + texty statusov (`edge_check_status`, `EDGE_OPTION_LABELS`/`edge_check_option_status`, `grain_check_status`, `grain_part_plural`). Okno
odovzdáva svoj stav **explicitne** — okrem `generation:`/`status:`/`repush:` aj **`echo:`** (malý push stavu prepínača do TOHO okna) a pri kresbe `grain_echo:`; guard tak nemá
**žiadny okenný stav** a obe okná sú nad ním len obaly.

Názvy stavov majú **jediný zdroj** `ProductionCore::EDGE_OPTION_LABELS` — rail Inspectora aj `js/edge_menu.js` ich čítajú odtiaľ (do ŠT-1c PR B3 sa rail pýtal cez tenký obal okna
Výroba).

**ŠT-1c PR A sem pridala dve veci zo zaniknutého tabu Kovanie:** `hardware_labeled` (generika kovania obohatená o SERVEROVÉ texty `label` — `HardwareRules.label_for` — a
`params_label` — „rez 597 mm", D-90; obohatenie zmizlo z `push_state` okna Výroba, aby dva klienty nemohli mať dve pravdy o tom, ako sa položka volá) a **telo `do_hw_csv`**
(nákupný CSV zoznam; rovnaký tvar ako `do_export` — `generation:`/`status:`/`repush:` — takže okno je nad ním len obal).

**VEDOMÁ ZMENA (audit #15):** CSV kovania dostalo **generačný guard**, ktorý predtým nemalo — je to nákupný dokument a nesmie vzniknúť z okna so zastaranými dátami (ostatné tri
exporty ho majú odjakživa); odmietnutie nie je tiché, okno sa obnoví a povie to.

**ŠT-1c PR B1 sem presunula CELÝ ROZPOČET — a s ním JEDINÚ cestu, ktorá zapisuje do modelu:** `do_budget` (12 operácií cez `apply_budget_op` → `BudgetStore`, jedna mutácia =
**jeden krok Späť**), oba XLSX exporty (`do_budget_xlsx`, `do_cp_xlsx` + `cp_warnings`/`cp_status`/`fmt_eur`), `budget_open_url` (adresa sa **dohľadáva v modeli** podľa ID položky
a znova sanitizuje — z klienta nechodí), `open_budget_settings` a celý beh **prepočtu cien** (`do_price_refresh` + `price_refresh_reject`/`_emit`/`_targets`/`_cancel`/`_status`).

Tvar odovzdania stavu je ten istý ako všade inde, len bohatší: okrem `generation:`/`status:`/`repush:` aj **`result:`** (echo `NX.budgetResult(op, ok)` **PRED** čerstvým payloadom
— odmietnutý zápis nesmie zavrieť rozpísaný draft, GH #138 P2) a pri prepočte cien **`emit:`** (fázové okno), **`alive:`** (beh visí na TEJ ISTEJ inštancii okna) a **`after:`**
(refresh ciest po dobehnutí — ceny sa menia globálne, takže čerstvé čísla dostanú katalóg materiálov, panel aj katalóg kovania; piaty prijímateľ — okno Výroba, ktoré potrebovalo
čerstvé `counts` pre svoj ⚠ chip — zanikol s oknom v ŠT-1c PR B3). Guard mutácie je zámerne **tolerantný na prázdny `model_guid`** (starší cachovaný DOM), ale nezhodné ID odmieta.

Kontrakt stráži `tests/pure/test_st1a_core.rb`, `tests/pure/test_st1a_studio.rb`, `tests/pure/test_st1b_kontrola.rb`, `tests/pure/test_st1c_nakup.rb` a
`tests/pure/test_st1c_rozpocet.rb`.

## Bez vlastného odseku

### bom.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Zber modelu a agregácia riadkov kusovníka (`Bom.collect`, `Bom.compute`, `Bom.row_key`); správanie je popísané v odsekoch, ktoré ho volajú.

**Zber je JEDEN prechod modelu a jeho aditívne kľúče majú KAŽDÝ svojho čitateľa** — `collect` popri `records`/`hardware` vracia aj `hardware_overrides`, `manual_overrides`,
`cabinet_sets`, `placements`, `identities` a `warnings`; `compute()` ich **ignoruje** (tvar výstupu ani SCHEMA `.skp` sa nimi nemenia), číta ich `Validation.run` a payloady sekcií.
Pravidlo, ktoré z toho platí pre každý ďalší zásah: **záznam nesie presne to, čo jeho čitateľ naozaj číta.** Pole bez čitateľa je pozvánka pre budúci kód postaviť sa naň — preto
z `manual_overrides['abs']` v 1b-4 vypadli `material_id` aj `pid` (adresa jantárového riadku je zámerne identita `owner_id` + `part_key`, nikdy persistent_id). Detail kontraktu
jantárových riadkov — čo je zdrojom ABS overridu, ako sa páruje kovanie a v akom poradí sa riadky kreslia — žije v [hardware.md](hardware.md), odsek `hardware_rules.rb`
(sekcia ŠT-3b-2a a štyri pravidlá riadku z 1b-4).

**`identities` (1b-3):** `collect` nesie popri `placements` aj **jeden záznam na INŠTANCIU** top-level skrinky/dosky (`{kind, id}`, prázdne ID sa zahadzuje) — z toho `Validation`
robí nález `duplicate_identity`. Kľúč je **aditívny** (kto ho nepozná, nič nestratí), zbiera sa v tom istom prechode a `compute()` ho ignoruje; pri doskách sa — rovnako ako
`placements` — plní **pred** filtrom `manufactured`, lebo zdieľané ID je chyba identity aj pri dočasne nevyrábanej doske.

### sheet_estimate.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Odhad počtu platní (2B-1/D-43) — zmienky v odseku `production_core.rb` a v sekcii Kusovník v [ui-lifecycle.md](ui-lifecycle.md).

### budget.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### budget_store.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### price_refresh.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Beh prepočtu cien voči Demosu — zmienky v odseku `production_core.rb`.

### supplier_settings.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Globálne nastavenia dodávateľa (sadzby, režimy €/€€/€€€, prah veku cien); UI je v [ui-lifecycle.md](ui-lifecycle.md), odsek o sekciách `sup`/`bset`/`about`.

### vepo_export.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### cp_export.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### xlsx_writer.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_
