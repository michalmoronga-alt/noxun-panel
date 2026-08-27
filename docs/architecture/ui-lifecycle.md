# UI — Inspector, Štúdio a lifecycle okien

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

Dve okná pluginu (Inspector · Štúdio), ich kostra, kontexty, karty, sekcie, zdieľané JS komponenty a životný cyklus dialógov. Pri KAŽDEJ UI práci sa k tomuto súboru povinne číta
[../UI_DIZAJN.md](../UI_DIZAJN.md).

## Vrstva UI a zdieľané komponenty

### Súbory UI vrstvy

`panel.rb` (centrálne callbacky) + `ui/panel/*.rb` domény + `ui/js/*.js` moduly + `panel.css`.

### Dizajn

tokeny `--nx-*` (farby VÝHRADNE cez tokeny; `--nx-state-*` rezervované pre semafor, nemiešať s ABS/status významami) · `ui/js/icons.js` inline SVG sprite (Lucide subset + vlastné +
firemné logo `#i-logo`; licencie v THIRD_PARTY_NOTICES.md) · **žiadne emoji v UI chrome — vždy sprite ikony** · **komponentový rádius 6 px** · pravidlá: `docs/UI_DIZAJN.md` —
**čítať pri KAŽDEJ UI práci**.

### Paleta a téma (UI-01)

výber/aktívny stav nesie firemný **NOXUN teal** (`--nx-select…`, `--nx-part-border/bg` = **výberová rodina**); primárna akcia zostáva zelená. Kreslené farby 2D náhľadu
(`preview.js`) sú **zrkadlom** týchto tokenov — SVG atribúty nevedia `var()`, takže zmena tokenu je zmena na dvoch miestach (rovnaký vzor ako `EdgeCheck::COLORS`).

**Téma** (`noxun` | `lucia`) prepína **VÝHRADNE výberovú rodinu** — danger/warn/ok/ABS/edge/semafor sa ňou nikdy nemenia. Žije v `%APPDATA%\NOXUN\Engine\ui_theme.json` (**nikdy v
.skp** — Michal a Lucia otvárajú tie isté zákazky), whitelist a fallback na `noxun` sú v Ruby (`Engine.normalize_ui_theme` / `get_ui_theme` / `set_ui_theme` v main.rb) a zrkadlovo
v JS (`nxThemeName`). Do okna sa dostane rovnakou cestou ako fit: okno si ju po načítaní HTML vypýta (`sketchup.nx_theme()` v `ui/js/win_fit.js` — jediný skript načítaný VO
VŠETKÝCH oknách; `execute_script` pred `show` nefunguje) a Ruby odpovie `nxThemeApply(<meno>)`. Callback registruje spoločný boot hook `Engine.register_dialog_fit` (historické
meno, D-77), takže nové okno tému dostane automaticky. `nxThemeApply` pred nasadením ZHODÍ všetky témové prepisy (návrat na `:root` — inak by po prepnutí späť ostali zvyšky).

**UI prepínač (UI-B3)** žije v koliesku raily: klik volá `nx_set_ui_theme` → `Engine.apply_ui_theme` = uloženie (`set_ui_theme`) + **`broadcast_ui_theme` do VŠETKÝCH otvorených
okien** (register `Engine.register_dialog_theme`, teda každé okno cez `register_dialog_fit`). Zoznam okien sa **čistí pri každej registrácii aj pri každom rozoslaní**
(`prune_theme_dialogs`) — referencia na zavretý dialóg (aj s jeho callback closure) sa nesmie držať; okno sa navyše **prihlási znova pri `nx_theme`** (medzi registráciou a `show`
ešte nie je `visible?`, takže by ho čistenie mohlo vyhodiť). Bez rozoslania by panel zmenil farbu a satelity ostali na starej až do ďalšieho otvorenia. Panel si tému **nedrží ani
nenasadzuje** — farby nasadzuje výhradne `nxThemeApply`, JS len číta `data-nx-theme` z koreňa, aby vedel, ktoré tlačidlo je aktívne.

### Zdieľaný combobox materiálov a ABS (D-85 / UI-03, ui/js/nx_combo.js)

JEDEN komponent pre VŠETKY výbery dekoru a ABS pásky v paneli — telo/čelá/chrbát (`cab_*`), materiál dielca (`pcMaterial`) + 4 hrany, materiál dosky (`bc_material`) + 4 hrany,
vkladací materiál (`ib_material`). Komponent `<select>` **NENAHRÁDZA — obaľuje ho**: pôvodný select ostáva v DOM (skrytý cez ATRIBÚT `data-nx-combo`, nie triedu — panel selectom
prepisuje `className` pri override `ovr`) a je naďalej **jediným zdrojom pravdy**. Možnosti sa čítajú z jeho `<option>`/`<optgroup>`, takže **všetka existujúca logika platí bez
duplikátu** (hrúbkové filtre D-45, ABS skupiny D-36/2A-3b, serverové texty „(podľa pravidla — …)" D-102, dupláky D-49, `disabled` „(nekompatibilné)"), a výber ide **presne tou
istou cestou ako natívny klik** — `sel.value` + `dispatchEvent('change')`.

Preto **prežívajú nedotknuté všetky guardy na `change`**: E-03 hrúbka a D-86 smer dekoru vo vkladacej karte, D-41 modal chýbajúcej pásky, identity guardy `cabinet_id`/`board_id`.
Jediná úprava guardov: „je pole obsluhované?" už neznamená len fokus selectu, ale `nxFieldBusy` = **fokus ALEBO otvorený popup** (`refreshInsertBoardMaterials`) — živý refresh
katalógu nesmie prekresliť ponuku pod rukami píšuceho. Synchronizácia triggera má dva kanály: **`MutationObserver`** na `childList` selectu (panel prekresľuje `<option>`y bez
akejkoľvek udalosti; callback beží až po dobehnutí bloku, takže vidí aj dosadenú `value`) a **explicitné `nxComboSync()`** na konci každého renderu karty (zmena samotnej
`value`/`disabled` observer nespustí).

Dáta si komponent nedrží: „Použité v projekte" je **odvodený zoznam ID zo servera** (`Materials.used_material_ids` / `used_abs_ids` mínus zdroje z globálnych šablón — čisté čítanie
configov, ŽIADNA zmena schémy ani zápis do modelu). Chodí **dvoma kanálmi**: v `materials_payload.used_ids` (init + `push_materials`) a — pretože sa mení pri KAŽDOM zápise
materiálu vrátane Späť/Znova a vkladania — **na vyžiadanie pri otvorení ponuky** (`sketchup.nx_used_ids()` → `Panel.push_used_ids` → `NX.setUsedIds`, ktoré vymení LEN zoznam a
prekreslí už otvorený popup, žiadny render karty).

**Pull, nie push:** zoznam sa číta pár desiatok krát za sedenie, kým `push_selected` beží pri každom kliku vo výbere — plný scan modelu (5 prechodov cez `definitions`) do tejto
horúcej cesty nepatrí (stráži to guard test). Farbu štvorčeka dáva panel resolverom (`nxComboColorOf` — dekor z katalógu cez `nxRgbHex`, lebo katalógová farba je pole `[r,g,b]`,
nie CSS reťazec; ABS podľa hrúbky), a do `style` prejde len hex (úzky whitelist). „Naposledy použité" je `localStorage` tohto počítača (`nx_recent_decor`/`nx_recent_abs`, max 5,
len ID — nikdy model ani `%APPDATA%`).

**Sync zvonka (serverový push cez `scan`, prestavba `<option>`ov, odchod z okna) otvorený popup ZAVRIE** — drží položky z času otvorenia, takže by klik potvrdil voľbu starého
kontextu do nového (natívna rozbaľovačka sa pri prestavbe správa rovnako). Popup je `position: fixed` nad `body` (žiadny `overflow:auto` predok ho neoreže — D-67 FIX 7, D-105),
výber `mousedown`-om (`blur` by ho zavrel skôr — D-67 FIX 4), `<datalist>` v CEF nefunguje vôbec. Čisté funkcie (normalizácia bez diakritiky, sekcie, filter, klávesnica, recents)
testuje `tests/js/test_ui03_combobox.js`, serverový a inventúrny kontrakt `tests/pure/test_ui03_combobox.rb`. Vzhľad a správanie sú 1:1 mockup
`SYSTEM/zdroje/ui20/mockup_inspector_c.html`; pravidlá v `docs/UI_DIZAJN.md`. Okno **Materiály** má vlastný suggest (D-67) a komponent zámerne nepreberá.

**PICKER-1 (25.8.):** komponent používajú aj **predvoľby projektu v sekcii Materiály** (`md_body`/`md_front`/`md_back` v `studio.html` majú `data-nx-combo="decor"`, `scan` ich
pripája po každom `fillSelect`) — jeden vyhľadávač, jedna pravda; dovtedy to boli holé `<select>`y bez hľadania.

**Kontrakt D-46 sa nemenil:** komponent posiela `change` rovnakou cestou ako natívny select, takže potvrdzovacia lišta aj `model_guid` guard bežia nezmenené; programové vrátenie
hodnoty (pending) `change` **nespúšťa** a preto pribudol most **`NXCombo.sync(sel)`** — natívny select sa prekreslí sám, vyhľadávač má vlastný trigger a bez sync by ukazoval
hodnotu, ktorá už neplatí.

**Šírka ponuky je pravidlo, nie konštanta** (`nxComboPopWidth(fieldW, viewportW)`, čistá funkcia): ponuka je taká široká, ako je obsahová oblasť okna (viewport mínus okraje),
orezaná **stropom čitateľnosti 620 px**, a **nikdy nie je užšia než pole** — v paneli (~470 px) tak prekryje celú šírku, v Štúdiu ide po strop. Dovtedajšie `max(šírka poľa, 270)`
orezávalo dlhé názvy dekorov tak, že dve podobné varianty sa nedali rozlíšiť (Michal 25.8.). Položka nesie celý názov aj v `title` — v úzkom okne sa riadok môže orezať aj tak.

**Životný cyklus nad PERZISTENTNÝM telom sekcie** (review #230 P2): odchod zo sekcie telo **odpojí** z dokumentu a návrat ho vráti aj s rozpísaným formulárom. `scan` preto odpojené
pole nielen odregistruje, ale **rozbalí** (`detach` — tlačidlo preč, select späť na miesto obalu, obal preč, `tabindex`/`aria-hidden` zrušené); inak by v odpojenom strome ostal
osirelý obal s tlačidlom a návrat by ten istý select obalil **druhýkrát** — používateľ by videl dva ovládače a s každým ďalším katalógovým echom o jeden viac. `detach` je aj
**verejný most** pre hostiteľa. Sekcia Materiály navyše scan **nespúšťa, kým je telo odpojené** (vtedy je aj `mdRenderAll` no-op).

**PICKER-2 (25.8.) — RIADOK JE DEKOR, hrúbka je čip:** varianty toho istého dekoru a toho istého **typu dosky** sa zlučujú do jedného riadku a hrúbky visia na jeho konci ako čipy
(`18 | 36 | duplák`).

**HRANICU URČUJE KATALÓG, NIE KLIENT** (review #231 P1): identitu variantovej rodiny skladá server (`Materials.variant_family_key` = skupina/výrobca · dekor · štruktúra · typ ·
prípona formátu a rubu; UNI záznamy dostávajú unikátny kľúč, teda sa nezlučujú vôbec) a posiela ju v oboch payloadoch ako **`row_key`** spolu s dekorovou menovkou **`row_label`**
(`Panel.sheet_row_label` — to isté, čo nesie `sheet_label` pred časťou „· TYP hrúbka mm", vrátane výrobcu pri kolízii). Skupinovú časť kľúča dáva **kanonická `record_group_key`**,
nie holé `group_id`: hybridný katalóg môže mať záznamy bez `group_id` a kanonický kľúč vtedy padá na dvojicu výrobca + dekor — s holým `group_id` by Egger 5981 a Kronospan 5981
skončili v jednej rodine (review #231 kolo 2). **Kanonické sú VŠETKY zložky kľúča, nielen skupinová** (PICKER-3): katalógový kontrakt porovnáva typ aj štruktúru bez ohľadu na
veľkosť písmen, takže `DTDL`/`dtdl` a `ST9`/`st9` v surovom tvare dávali **dva riadky s rovnakou menovkou**. Detail kľúča žije v [materials.md](materials.md).

Dekor + typ na hranicu **NESTAČÍ**: v SCHEMA 2 sa to isté číslo dekoru legálne opakuje u dvoch výrobcov, tá istá skupina má viac štruktúr a typy s formátom v identite (PD, zástena)
sa líšia formátom alebo rubom — zlúčené by dali **dva čipy s rovnakou hrúbkou**, nerozlíšiteľné, s cudzou cenou aj povrchom (tá istá pasca, ktorej `sheet_label_suffix` predišiel v
labeloch, GH #95 P1). Bez `row_key` (starší payload) sa padá na dekor + typ. HDF 3 mm ani kompakt teda nie sú „tenšia verzia" DTDL toho istého dekoru a **čip nikdy nezmení typ**.

**Rozdelené riadky musia byť aj POMENOVANÉ rozdielne** (review #231 kolo 2): ten istý dekor v DTDL 18/36 + HDF 3 + kompakte dá tri riadky, ktoré by s holou dekorovou menovkou mali
identické meno — a jednovariantný riadok čipy vôbec nekreslí, takže by sa nedali odlíšiť. Rozhoduje o tom **`Materials.row_label_disambiguated`** nad kontextom
`Materials.row_family_ctx` (postavený RAZ na payload, vzor `label_ctx`): pri kolízii dekorovej menovky pribudne **typ**, a **hrúbka len vtedy, keď ju riadok neukáže čipmi** (jediná
v rodine) — pri viacerých by menovka klamala. Pravidlo žije v CORE, nie v okne: je to rozhodnutie nad celým katalógom (jeden záznam naň neodpovie) a klient ho spraviť **nemôže** —
vidí vždy len to, čo je práve v selecte. **Kontext počíta aj s VIRTUÁLNYMI duplákmi** (PICKER-3, parameter `virtual:` — panel ich berie z tej istej autority ako `duplak_offers`):
ponuka `duplak2:` v `Materials.sheets` nie je, takže rodina s jednou kúpenou hrúbkou platila za jednovariantnú a menovka tvrdila „… 18 mm" aj potom, čo riadok dostal čip
„36 duplák" a po jeho výbere vložil 36. *(Zvažovaná alternatíva „potlač hrúbku vždy, keď riadok dostane čipy" padla: server nevie, ktoré varianty v konkrétnom selecte prežijú
hrúbkové filtre D-45, takže by o tom musel rozhodovať klient orezávaním serverového textu.)*

Zoskupenie robí čistá `nxComboDecorRows(items, meta)`; metadáta variantu (`decor · type · thickness · duplak`) dodáva **hostiteľ** cez `setVariantResolver` — komponent žiadny
katalóg nepozná, takže bez resolvera vyzerá ponuka presne ako pred PICKER-2 (Inspector: `nxComboVariantOf` nad `sheetRecOf`; Štúdio: nad `MD_SHEETS`; **ABS sa nezoskupuje** —
hrúbka pásky je jej vlastnosť, nie variant dekoru).

**DUPLÁK MÁ DVA TVARY a oba musia byť rozpoznané:** virtuálna ponuka `duplak2:<zdroj>` (ešte nie je v katalógu, pozná sa podľa tvaru ID) a **uložený záznam s bežným
`material_id`**, ktorý sa pozná VÝHRADNE podľa `source_material_id` — payload ho preto zrkadlí ako `duplak` (panel) a **Príznak čítajú OBAJA hostitelia rovnako** (`rec.duplak ===
true`): `MD_SHEETS` v Štúdiu je ZÚŽENÝ `Panel.materials_payload`, v ktorom surové `source_material_id` nie je — čítať duplák z neho znamenalo, že uložený duplák je v Štúdiu
neviditeľný (review #231, kolá 1 a 3). Bez príznaku by vyzeral ako kúpená hrubá doska, nedal by sa nájsť hľadaním „duplák" a mohol by sa aj predvoliť. Čip duplákov nesie **aj
hrúbku** („36 duplák" / „54 duplák") — rodina môže mať duplák ×2 aj ×3 a dva čipy so samotným slovom by boli nerozlíšiteľné (review #231 kolo 2). **A rovnako to musí čítať aj
HĽADANIE** (PICKER-3): pri slovnom dotaze sa najprv hľadá zhoda hrúbky **medzi duplákmi** a až potom sa padá na prvý — inak „54 duplák" preselektovalo 36 mm (slovo sa čítalo skôr
než číslo) a Enter vložil iný materiál za iné peniaze.

**Predvolená hrúbka je vec KONTEXTU** (`data-nx-combo-ctx` na selecte: `body`/`front` → najtenšia konštrukčná podľa katalógu, nie natvrdo 18 · `back` → 3 · `worktop` → 38;
chýbajúca kontextová hrúbka = najtenšia konštrukčná, **žiadne hádanie „najbližšej hrubšej"**), a **duplák sa nepredvolí NIKDY** — ani keď je v riadku najtenší, ani keď sedí na
kontextovú hrúbku: je to zdvojená doska za dvojnásobok a vyberá sa **vedomým klikom na čip**. Poradie prednosti pri kreslení riadku: **dotaz menujúci konkrétny variant (jeho ID
alebo label) → výslovný dotaz o hrúbke → kliknutý čip → hodnota, ktorú select nesie → kontext**.

**PICKER-3 (E): KONTEXT RADÍ AJ RIADKY, nielen hrúbky vnútri riadku.** Dovtedy vedel vybrať hrúbku v rodine, ale nie uprednostniť riadok HDF 3 pred riadkom DTDL 18 toho istého
dekoru — a `md_back` v Štúdiu je naplnený **všetkými** doskami, takže po napísaní dekoru vyhral DTDL a Enter vložil 18 mm chrbát. Dve časti, obe čisté funkcie: `nxComboSortByCtx`
(**stabilné** radenie podľa `nxComboCtxRank` — riadok s kontextovou hrúbkou má rank 0, ostatné 1; beží **pred delením na sekcie**, takže sa uplatní vnútri každej z nich a členstvo
v „Použité v projekte" sa nemení; **sekcia „Naposledy použité" dostáva `ctx` až do `nxComboSections`** — svoje poradie si prepisuje podľa čerstvosti, takže bez toho by v nej
kontext ticho zanikol a hore by stála naposledy použitá DTDL 18. Čerstvosť je tam tie-breaker **medzi rovnocennými**, review #236 kolo 1) a `nxComboFirstCtx(items, ctx, q)` = kam sadne **kurzor** po dopísaní dotazu: **riadok s hrúbkou, ktorú dotaz MENUJE → riadok podľa kontextu →
prvý vyberateľný**. Samotné radenie by nestačilo — sekcie „Použité v projekte" a „Naposledy použité" stoja NAD katalógom, takže bez kurzorového pravidla by Enter v poli pre chrbát
vložil použitú DTDL 18. Prvý stupeň drží sľub PICKER-2 „výslovný dotaz > kontext" aj o poschodie vyššie a **pýta sa dát, nie tvaru dotazu**: číslo dekoru („K018", „H3303") hrúbku
nemenuje, kým „18" so zhodným variantom áno; nedostupný variant riadok nevytiahne. Bez kontextovej hrúbky (`body`, `front`, ABS, chýbajúci atribút) sa **poradie servera nemení ani
o riadok**. *(Zamietnuté: FILTROVAŤ nekontextové riadky — 18 mm chrbát je nezvyklý, nie zakázaný, a filter by legitímnu voľbu schoval; v tomto repe semafor varuje, nikdy
neblokuje.)*

Prvý stupeň (`nxComboVariantFromQuery`) pribudol v review kole 3: materiálové ID sú zámerne neprehľadné a pred zlúčením sa dal každý variant vybrať samostatne, takže dotaz „ZXQ"
musí vložiť **práve ten** variant — nie predvolenú hrúbku rodiny; ID pritom môže obsahovať číslo patriace inej hrúbke, preto stojí **pred** hrúbkovým čítaním. Nejednoznačný dotaz
(sedí na viac variantov, napr. samotný názov dekoru) nevyberá nič a rozhodne hrúbkové pravidlo. Dotaz je hore zámerne (review #231 P2): kto po kliku na 18 napíše „36", chce 36 —
sľub „dotaz preselektuje to, čo Enter vloží" nesmie prestať platiť len preto, že predtým klikol na iný čip. Kliknutý čip sa pamätá pod kľúčom riadku (`OPEN.chip`), takže **prežije
prekreslenie po každom písmene v hľadaní**, kým dotaz o hrúbke mlčí.

**Zlúčenie nesmie nič schovať:** riadok nesie v `searchExtra` hrúbky, slovo „duplák" **a `value` aj `label` KAŽDÉHO variantu** — pred zlúčením sa hľadalo cez hodnotu každej
položky, takže dotaz na neprehľadné ID („H3303_36") fungoval a po zlúčení by prestal (review #231 P2) (dotaz „36" riadok nájde **a rovno preselektuje čip 36**), a členstvo v
skupinách „Použité v projekte"/„Naposledy použité" sa posudzuje cez **VŠETKY varianty** riadku (`nxComboRowIds`) — inak by projekt s 36 mm dekor v skupine nenašiel, hoci ho
používa; zaradenie do skupiny pritom **predvolenú hrúbku nemení** (skupina je zaradenie, nie voľba za používateľa). Klik na čip je **zúženie výberu, nie výber**: `preventDefault` +
`stopPropagation`, ponuka ostáva otvorená, do selectu sa nezapisuje nič a prekreslí sa iba ten jeden riadok (`redrawRow` — celý render by zahodil scroll aj rozpísaný dotaz).

**Nedostupný variant je `aria-disabled`, nikdy natívne `disabled`** (vzor D-78): natívny atribút by čip vyhodil z klávesnice a klik by nemal čo povedať — takto sa ním nedá prepnúť,
ale klik **dopíše dôvod** pod čipy (`.cbchipmsg`, text je serverový label varianta, napr. „(nekompatibilné)"; riadok ponuky sa preto zalamuje — `.cbopt { flex-wrap: wrap }` — inak
by hláška sedela za čipmi a `overflow: hidden` popupu by ju orezal) a dôvod prežije prekreslenie po písmene rovnako ako vybraný čip.

**Z klávesnice sa čipy ovládajú šípkami vľavo/vpravo** (`moveChip`): fokus zostáva v poli hľadania a `Tab` ponuku zatvára, takže bez toho by boli tlačidlá čipov pre klávesnicu
nedosiahnuteľné (review #231 P2). Na krajoch sa **necyklí** — slepým stláčaním sa nedá skončiť na dupláku. **Nedostupný variant sa už NEPRESKAKUJE ticho** (PICKER-3 D): prvé
stlačenie na ňom **zastane a dôvod oznámi** (`announceChip` — text je serverový label varianta, hláška je `role="status" aria-live="polite"`, takže ju čítačka prečíta bez presunu
fokusu), druhé v tom istom smere pokračuje ďalej. Bez toho sa človek od klávesnice k vysvetleniu, ktoré myš dostane klikom, nedostal vôbec — a zastavenie bez pokračovania by bolo
zaseknutie. Úspešné prepnutie čipu pamäť „už odznelo" vynuluje.

**Výsledkom voľby je `material_id` KONKRÉTNEHO variantu** — čip je čisto klientske zúženie, `change` ide tou istou cestou ako natívny výber, takže serverové cesty ani kontrakt E-03
(hrúbku určuje reálny materiál) sa nemenia. Tým **zaniklo vedomé obmedzenie PICKER-1**: skupina „Použité v projekte" je aj v Štúdiu — nemapuje sa nič, server posiela hotový zoznam
ID (`StudioDialog#mat_used_ids` → `mat.used_ids`, tvar zhodný s panelovým `used_ids_payload`), takže hostiteľský hook je v oboch oknách ten istý jednoriadkový výber. Zdrojom je
**UŽ zozbieraný kusovník** (`collected[:records]`, žiadny druhý prechod modelom — presne to, čo ŠT-2a raz odstránilo) a na rozdiel od `used_where` sa dielec **bez `owner_id`
nevyhadzuje**: tam ide o klikateľného vlastníka, tu o otázku „je tento materiál v zákazke?".

Testy: `tests/js/test_picker2_chips.js` (zoskupenie, defaulty, dotaz, skupiny), `tests/js/test_picker2_chips_dom.js` (čipy v otvorenej ponuke, klik, potvrdenie, klávesnica),
`tests/js/test_picker3_kontext.js` (rank · stabilné radenie · kurzor · duplák podľa hrúbky), `tests/js/test_picker3_kontext_dom.js` (čo Enter naozaj vloží v poli pre chrbát),
`tests/pure/test_picker2_used_ids.rb`, `tests/pure/test_picker3_rodina.rb`.

### D-15 modal — zdieľaná kostra „pridávačiek" (ui/js/nx_modal.js, ŠT-1c PR B2)

schválený vzor kontraktu UI 2.0 — JEDNA kostra pre všetky okná typu „pridaj niečo": `mhead` (titulok + podtitul + ×) · `mbody` (polia) · `mfoot` (Zrušiť + **zelené** potvrdenie);
**Esc aj klik na scrim zatvárajú**, fokus ide do **prvého poľa** a pri zatvorení sa vracia **na spúšťač**. Komponent je vo vzore `edge_menu.js`: markup, texty aj správanie na
jednom mieste, inštancie sa líšia LEN poľami (`fields` = deklaratívny zoznam `{key, label, type, value, placeholder, options}`), a je **globálny `window.NXModal`** +
`module.exports` (testovateľný v Node).

**ŠT-2c PR 2c-1 — príprava pre D-69 editor materiálu:** k `text`/`select` pribudli typy **`group`** (nadpis sekcie formulára — dlhý formulár bez predelov sa číta ako kopa políčok),
**`checkbox`**, **`color`** (vzorka + text `#RRGGBB`) a **`rows`** (repeater: `cols` = pod-polia riadku, tlačidlá `+`/`−`), plus šírkové varianty karty `size: 'sm'|'md'|'wide'`
(`small` je alias `sm`, starý `small: false` = `md`; šírky sedia pri `.nxmcard` v `studio.html`).

**TVAR `values()` je kontrakt (audit ŠT-2c #14):** ploché polia ostávajú **reťazcami** (spätná kompatibilita draftov rozpočtu), `checkbox` je **boolean**, `rows` **pole hashov**,
`group` v hodnotách **vôbec nie je**. `rows` čítajú hodnoty **z DOM** (nie z držaného stavu), lebo každé `+`/`−` kontajner prekresľuje — inak by pridanie riadku ticho zmazalo
rozpísané riadky nad ním; existujúce riadky nesú **skryté kľúče** (`hidden`, typicky `material_id`/`row_rev`), podľa ktorých server odlíši úpravu variantu od nového, takže
**identita sa nikdy neodvodzuje od kódu, ktorý používateľ práve prepisuje**. Do `focusables()` pribudlo vylúčenie `type="hidden"` a `[href]` sa zúžilo na `a[href]` — inline SVG
ikona (`<use href="#i-…">`) ten selektor spĺňa a Tab by cyklil na kus ikony vnútri potvrdzovacieho tlačidla; `aria-disabled` prvky sa naopak **nevyhadzujú**.

Kontajner repeatera má **vlastný prefix id `nxmr_`**, aby sa kľúč riadkov nezrazil s kľúčom plochého poľa, a duplicitný kľúč v specifikácii sa **ohlási do konzoly** (inak by sa
hodnoty ticho prepisovali). Pri dosiahnutom `min` je tlačidlo **−** `aria-disabled` s **dôvodom** (D-78: klik ho napíše do `.mrnote`), nie tvrdý `disabled`, ktorý by ho vyhodil z
klávesnice a mlčal. Delegovaný klik **nemá catch-all vetvu** (`else if (a === 'close')` + varovanie) — „všetko ostatné = zavri" znamenalo, že tlačidlo s preklepom v `data-nxm-act`
zmazalo rozpísaný formulár.

**PRVÁ inštancia sú drafty rozpočtu** — „Pridať položku" a „Pridať spotrebič" (`budDraftFields` je čistá funkcia, validácia ostáva **serverová**, klient stráži len povinné pole);
ďalšie (D-69 editor materiálu, položka/set kovania) sa napoja bez kopírovania.

**KONTRAKT (audit #9):** komponent spravuje **výhradne modaly, ktoré si ho vyžiadajú** — fázové okno prepočtu cien `#budPrModal` ho **nepreberá**, lebo jeho životný cyklus riadi
server a vo fáze `run` sa Escapom zavrieť nesmie (beh by ostal visieť bez okna); a Escape handler Štúdia (`ecMenu`) je preto podmienený `!nxModalOpen()` — oba listenery visia na
`document` a `stopPropagation` medzi nimi **nefunguje** (tá istá lekcia ako pri zatváraní `ecMenu` klikom mimo).

**`submit` modal NEZATVÁRA** (audit #10): pošle hodnoty cez `onSubmit` a zatvorenie je rozhodnutie volajúceho — rozpočet ho zavrie **len** na `NX.budgetResult(op, true)`, takže
odmietnutý zápis nechá používateľovi jeho hodnoty na mieste (opraviť číslo, nie písať formulár znova). Kotva `#nxModalRoot` žije **mimo `#secbody`**, takže prekreslenie sekcie po
zápise modal nezhodí.

#### ZÁMOK ODOSLANIA OPEN.busy (review #2)

patrí do komponentu, nie do rozpočtu: `sketchup.*` je asynchrónne, takže bez neho by dvojitý Enter poslal druhú mutáciu do fronty klienta (`BUD_BUSY`/`BUD_QUEUE`), tá by odišla **s
čerstvou generáciou** a server by ju **prijal** — položka dvakrát a dva kroky Späť. Rovnakú pascu by inak zdedila každá ďalšia pridávačka. Prvý `submit` zamkne a **zošedí
potvrdzovacie tlačidlo** (bežiaci zápis musí byť vidno), ďalšie sa zahadzujú; odomyká **výhradne volajúci** cez `NXModal.setBusy(false)` v **oboch** vetvách výsledku (úspech
zatvára, odmietnutie odomyká) — plus poistka v `budAfterPush`, keby Ruby callback spadol pred `budgetResult`.

**FOKUS ZOSTÁVA V KARTE (review #7):** Tab z posledného prvku cyklí na prvý (a Shift+Tab naopak) — bez toho by skočil do tabuľky za modalom, ktorú používateľ práve nemôže ovládať.

**Escape modal SPOTREBUJE** (`stopImmediatePropagation`, review #10): `stopPropagation` by nestačilo — oba listenery visia na tom istom uzle (`document`) a ten ich nezastaví;
funguje to preto, že `nx_modal.js` sa načítava pred `studio.js` (stráži guard test), a podmienka `!nxModalOpen()` v Štúdiu ostáva ako druhá poistka pre opačné poradie.

**Rozpísané hodnoty prežijú zatvorenie (review #3+#4, sklad presunutý v ŠT-2c #12):** pamäť drží **komponent**, nie volajúci — je to súčasť kontraktu D-15, takže ju každá ďalšia
pridávačka dostane rovnakú (`BUD_DRAFT_VALUES` v `budget.js` zanikol, ostal len tenký prístupový bod `budDraftMemory(kind)` nad `NXModal.memory`). Kľúč `memoryKey` má konvenciu
**`<okno/doména>:<mode>[:<cieľ>]`** (`bud:custom`, `bud:appliance`, `mat:edit:H3303`) a slot — to, čo sa navzájom prepisuje — je všetko okrem **posledného** segmentu, keď sú
segmenty aspoň tri: `bud:custom` a `bud:appliance` sú preto nezávislé, kým `mat:edit:A` a `mat:edit:B` sa delia o jeden slot, takže otvorenie editora **iného** dekoru starú
rozpísanú verziu zahodí **hneď** (`dropForeign`) a formulár je čistý — inak by sa hodnoty dekoru A predvyplnili do dekoru B a uložili do nesprávneho záznamu.

Zapamätáva sa pri **odoslaní aj zatvorení**, ale **len polia, ktoré sa líšia od východiskových hodnôt** podanej specifikácie (`defaultsOf`/`sameValue`) — predvoľba `<select>`u ani
„Počet = 1" nie sú nič, čo by používateľ rozpísal, takže otvoriť a zavrieť okno pamäť nezaloží.

**Predvyplnenie z pamäte je VIDNO** (`fromMemory` → pás `.mmemo` „Predvyplnené z rozpísaného konceptu" + `memreset` „Začať odznova", ktorý vráti východiskové hodnoty a pamäť
zahodí) — pohodlie nesmie byť pasca, inak by používateľ v editore materiálu uložil cenu písanú minule. Maže **výhradne volajúci** signálom „server potvrdil": `setBusy(false,
{clear:true})` alebo `clearMemory(key)` — a `clearMemory` zároveň **dočasne** zhasína zápis (`memSkip`), inak by `close()` pamäť hneď zapísal späť; **prvý `input`/`change` v karte
ho zapáli späť**, aby scenár „uložil som a píšem ďalšiu položku" nebol tichou stratou. Volajúci podáva polia **východiskové** (`budDraftFields(kind, null)`) — predvyplnenie robí
kostra, inak by nemala proti čomu porovnávať default.

**Pozor na mená tried:** mockup kreslí kartu ako `.nxmodal`, lenže `panel.css` toto meno už používa pre SCRIM starších modalov — karta sa preto volá **`.nxmcard`**,
`mhead`/`mbody`/`mfoot`/`mrow` ostávajú doslovné.

**Prekryvné ovládače vnútri karty** (našepkávač `#mdSgBox` z `proj_materials.js`; audit ŠT-2c #10/#11) majú **opačné** pravidlo než okno za modalom: Escape patrí **najprv im** a
stačí `ev.stopPropagation()` na inpute (dokumentový poslucháč modalu je na **inom** uzle — `stopImmediatePropagation` by zastavil len ďalších poslucháčov toho istého inputu a
formulár by sa aj tak zavrel); scroll listener musí byť v **capture** fáze na `window`, lebo `scroll` z vnútorného kontajnera (`.mbody`) nebublá a `position: fixed` overlay by
ostal visieť nad cudzím riadkom (capture tam bol už z D-67; ŠT-2c doplnila dôvod do komentára a behaviorálny test); písanie našepkávač naopak **vracia** — `input` ho obnoví aj po
Escape, inak by jedno stlačenie pole „vyplo" na celú editáciu; a vrstvenie sa odvodzuje z **jednej** definície — `--nx-z-scrim`/`--nx-z-suggest` žijú pri `.nxscrim` v
`studio.html`, `panel.css` číta `var(--nx-z-suggest, 80)` (vlastné číslo by pri prvej zmene scrimu poslalo dropdown pod modal: viditeľný, neklikateľný).

**ŠT-2c PR 2c-2a** doplnila do repeatera tri veci, ktoré si vypýtal prvý reálny spotrebiteľ (D-69 editor dekoru): stĺpec smie byť **`readonly` podľa RIADKU** (`roWhen` = kľúč,
ktorého prítomnosť riadok „zamkne“, `roTitle` = dôvod do tooltipu) — identitné pole existujúceho variantu sa needituje, ale ostáva **čitateľné a zamerateľné** (`readonly`, nikdy
`disabled`, aby hodnota nezmizla z klávesnice ani z čítačky); bunky dostali **`aria-label`** (nadpis je nad stĺpcom, nie pri poli, takže bez neho čítačka hlási len „textové pole“);
a **hlavička nesie TÚ ISTÚ šírkovú triedu ako bunka** (`colCls`, review 2c-1 #8 — inak nadpis „Cena“ visí nad polovicou tabuľky; triedy `mshort`/`mtiny`/`mcheckcol` sú v
`studio.html` v scope `.mrline`/`.mrcols`).

Riadky dostali **`rowKey`** (kľúč identity riadku) — pamäť rozpísaného formulára si podľa neho páruje hodnoty na ČERSTVÉ riadky a **zapamätá si výhradne editovateľné stĺpce**:
server-owned skryté polia (`row_rev`) z pamäte nikdy nevyliezajú späť, inak by formulár odosielal zastaraný odtlačok a zápis by sa **už nikdy nepodaril** (`trimRowsValue` +
`mergeRowsMemory`; riadok, ktorý v čerstvom katalógu nie je, sa z pamäte zahodí).

**PAMÄŤ JE PO BUNKÁCH, NIE PO RIADKOCH (1b-7, sweep #9 — cenové P2).** Do 1b-7 stačila jedna zmenená bunka na to, aby si pamäť odložila **všetky** editovateľné stĺpce **všetkých**
riadkov; pri ďalšom otvorení sa vliali do čerstvého katalógu a `row_rev` pritom ostal čerstvý — optimistický zámok teda prekážku nevidel a *Uložiť* **ticho vrátilo cenu, ktorú
medzitým priniesla „Aktualizovať z Demosu"**. Reálny scenár: otvor editor → oprav jednu hodnotu → **Esc** → aktualizuj ceny → otvor ten istý dekor → Ulož. Dnes `trimRowsValue(f,
rows, baseRows)` odloží **iba bunku, ktorá sa líši od východiskového riadku**, a ku každej pridá **`_base`** = hodnota, proti ktorej ju používateľ písal (`sameCell` porovnáva
boolean aj reťazec); riadok bez zmeny sa nepamätá vôbec. `_base` sa nikdy nevykresľuje ani neodosiela — `readRows` číta výhradne uzly s `data-nxm-col`.

**KOLÍZIA BUNKY sa nerieši ticho.** Keď `mergeRowsMemory` zistí, že tú istú bunku zmenil používateľ **aj** katalóg (`_base` ≠ čerstvá hodnota **a zároveň** výsledky sa naozaj líšia
— zhodná hodnota na oboch stranách kolízia nie je), riadok dostane **`_conflict`** = `{stĺpec: hodnota v katalógu}`: bunka sa označí triedou **`conf`** (nie `bad` — tú `clearErrors`
pri každom kole serverovej validácie zhasne), dostane `title` aj `aria-invalid` vo **všetkých** vetvách `rowCellHtml` a pod riadkom sa rozvinie pás **`.mrconf`** s dvojicou *tvoja ×
v katalógu* a dvoma rozhodnutiami — **„Prevziať z katalógu"** / **„Ponechať moju"**. **`submit` s nerozhodnutou kolíziou zápis NEPUSTÍ** (`conflictCount()` > 0 → hláška do
`.merrtop`, `onSubmit` sa nevolá, zámok sa nezapína). Rozhodovacie tlačidlá nesú **`data-nxm-confcol`**, nie `data-nxm-col` — `readRows` číta každý taký uzol v riadku a prázdna
`value` tlačidla by hodnotu bunky vymazala.

**VÝCHODISKOVÉ RIADKY (`base`) SÚ VŽDY ČERSTVÝ KATALÓG.** Prvá verzia opravy 1b-7 do nich pri kolízii ukladala starú hodnotu, aby kolízia prežila Esc — lenže z `base` kreslí aj
„Začať odznova", takže reset nakreslil **starú hodnotu s čerstvým `row_rev`** a nasledujúci zápis prešiel cez oba zámky (P1 interného review kola 1). „Proti čomu používateľ písal"
preto žije v **stave**: riadok ho nesie ako `_wrote` len do `flagsOfRows`, ktorý ho uloží do `OPEN.flags[pole][rowKey].wrote`, a `remember()` ho odtiaľ berie ako `_base`
zapamätanej bunky. Vďaka tomu nerozhodnutá kolízia **prežije Esc**, rozhodnutie ju **zahodí** (odteraz sa písalo proti hodnote, ktorú používateľ videl — a tou je už `base`), do
`base` sa **nikdy nič nezapisuje** a `memReset` z neho dostane presne to, čo je dnes v katalógu — vrátane riadkov, ktoré doniesol `setRows` po zotavení z konfliktu.

**Štítky riadku žijú v STAVE `OPEN.flags`, nie v DOM** (`flagsOfRows`/`applyFlags`, kľúč = hodnota `rowKey`): kontajner sa pri každom `+`/`−` prekresľuje z `readRows`, ktorý číta
len bunky — bez registra by jedno pridanie riadku zhaslo pás kolízie aj štítky `_note` a zápis by prešiel bez rozhodnutia. Stav sa preto musí **synchronizovať s obrazovkou**:
`conflictCount()` počíta výhradne nad `readRows` a `rowDel` navyše volá `syncFlags(key)` — inak by zmazanie kolízneho riadku nechalo zámok zápisu visieť na bunke, ktorú už nemá
kto rozhodnúť (P2 interného review; v zotavovacej ceste tam ani nie je „Začať odznova", takže jediným východiskom by bolo zavrieť okno).

**`setRows(key, rows, {base})`** vymieňa obsah repeatera za behu (zotavenie z konfliktu) — pozor, `withMemory` vracia pri prázdnej pamäti TEN ISTÝ objekt, takže `spec` aj `base`
zdieľajú polia; `ownSpecField` ich pred zápisom rozdvojí, inak by sa hodnoty používateľa prepísali východiskovými. Riadok smie niesť **`_note`** = štítok (nie hodnota — `readRows`
ho nečíta), ktorým sa označí záznam zmenený ZVONKU. Volajúci si vie vypýtať **`baseRows(key)`** (proti čomu používateľ písal) a **`conflicts()`** (počet nerozhodnutých buniek).
Pribudlo aj **`showErrors([{row, field, msg}])`/`clearErrors()`**: server validuje CELÝ formulár naraz a modal sa pri odmietnutí
NEZATVÁRA, takže hláška musí pristáť pri tom poli, ktorého sa týka — `row = null` ide pod `.mrow` plochého poľa, `"<kľúč>:<index>"` pod príslušný `.mrline`, nezaraditeľná do
zberného pásu `.merrtop` navrchu tela; každé ďalšie volanie predošlé chyby PREPÍŠE.

**ŠT-2d — ⋯ EDITOR RIADKU ROZPOČTU je štvrtá inštancia (audit #22):** v ŠT-1c PR B2 ostal vedome bokom (bol jediný svojho druhu a kostra vtedy nevedela, čo potreboval); odkedy v
okne žijú tri D-15 modaly, štvrtý vlastnoručný markup by znamenal **dva modalové svety v jednom okne** — iný Escape, iný fokus, iný scrim.
`budModalHtml`/`budRenderModal`/`budModalSave` a vetvy `modal_save`/`modal_close` zanikli, ostali čisté `budMoreFields`/`budMoreAttrs` (spotrebič má **len adresu** — kód ani
poznámku jeho záznam nenesie) + `budOpenMore`/`budCloseMore`.

**Ide BEZ `memoryKey`:** pamäť rozpísaných hodnôt patrí *zakladaniu* (Escape nesmie zahodiť rozpísanú položku), pri editore existujúceho riadku by bola pascou — predvyplnila by
hodnoty písané do iného riadku a uložili by sa do nesprávneho záznamu; formulár sa preto **vždy plní z čerstvého payloadu**. Mutácia ide **nezmenenou** cestou `budget_mutate` →
`custom_update`/`appliance_update` (1 zmena = 1 krok Späť); zatvára ho až **potvrdenie servera** (`NX.budgetResult(op, true)`), odmietnutie modal necháva otvorený a len pustí
zámok.

**KORELÁCIA ODPOVEDE (review #1) — inak by modal zatváral CUDZÍ zápis:** `custom_update`/`appliance_update` posiela aj **inline editácia bunky** v tabuľke (blur ceny/popisu), takže
`budgetResult` sa smie na modal vzťahovať len vtedy, keď odoslanie prišlo Z NEHO — `BUD_MORE.sent` sa zapne v `budMoreCommit`, vetva výsledku ho vyžaduje (`budMoreAwaiting`,
vrátane `NXModal.isOpen()`) a po vybavení zhasne.

**`BUD_MORE` sa čistí aj bez odpovede (review #2):** `NXModal.close()` sa rozpočtu neohlási, takže modal zavretý Escapom/klikom vedľa by nechal stav visieť — upratuje ho
`budOpenMore` na začiatku a `budAfterPush` (čerstvý payload) vtedy, keď už modal nie je otvorený. Testy: `tests/pure/test_st1c_ponuka.rb`, `tests/pure/test_st2c_modal.rb`,
`tests/js/test_st1c_ponuka.js`, `tests/js/test_st2c_modal.js`, `tests/js/test_st2c_editor.js`, `tests/js/test_st2d_kde.js` (mini-DOM je od 2c-2a zdieľaný v `tests/js/minidom.js`)
(mini-DOM s naozajstným parsovaním HTML a bublaním udalostí — repeater ani Escape nasepkavača sa na stubovanom `querySelector` overiť nedajú).

### Observery panela

(`ui/panel/selection.rb`) — panel počúva DVE veci: `SelObserver` (zmena výberu) a **`PanelModelObserver` (D-101: `onTransactionUndo`/`Redo`/`Abort`)**, lebo **Späť/Znova nevystrelí
žiadny selection event** a Inspector inak visel na predošlom stave až do prekliku výberu. Lifecycle oboch je **atomický**: attach/detach v jednej dvojici (`attach_observer` s
anti-double remove→add a rollbackom už pripojenej polovice pri zlyhaní; `detach_observer` s **vlastným chráneným krokom pre KAŽDÝ observer** — zlyhanie jedného remove nesmie
preskočiť druhý ani predčasne vynulovať `@observer_model`). Callback transakcie je **tenký**: v observer kontexte sa nič nečíta ani nemení, len sa označí pending a naplánuje
`UI.start_timer(0)` refresh (vzor `EdgeCheck.request_redraw`) — **viac rýchlych undo/redo za sebou = JEDEN push** najnovšieho stavu (coalescing).

Guard „ten istý a zároveň aktívny dokument" sa overuje **dvakrát** (v callbacku aj tesne pred pushom — oneskorená udalosť zo starého dokumentu nesmie prepísať Inspector aktívneho);
`@suspend_selection_sync` sa testuje až v timeri a udalosť **nezahadzuje** (refresh sa len odloží). Push je **VŽDY `dedup: false`** — dedup žiada `ScaleWatch.request_dedup` (zásah
do modelu) a z observer cesty je zakázaný (lekcia D-103); refresh preto nepridáva žiadny undo krok.

### SketchUp toolbar (UI-02, žije v main.rb — NIE je vlastný modul)

`Engine.install_toolbar` skladá toolbar „Noxun Engine" so 4 tlačidlami podľa kontraktu UI 2.0 (N4) — **logo** (prepínač Inspectora: `Panel.dialog_alive?` → `Panel.hide` /
`Panel.show`) · **Štúdio** (`StudioDialog.show` — jediné okno výstupov zákazky) · **ABS kontrola hrán** (prepínač existujúceho `EdgeCheck.toggle`) · **Vložiť**
(`Panel.show_insert`). Ikony sú **samostatné SVG** v `noxun_engine/ui/icons/` (`noxun_logo/studio/abs/insert.svg`) — sprite `icons.js` sem nesiaha a `currentColor` je tu zakázaný
(mimo HTML by ikona bola čierna), preto majú pevnú `#37474f`.

**Značka má dve podoby a JEDNU kresbu:** `noxun_logo.svg` (toolbar) a symbol `#i-logo` v sprite `icons.js` (hlavička panela + koliesko „O plugine") nesú **tie isté krivky**
zrolovanej značky z originálneho SVG webu — líšia sa **len viewBoxom** (toolbarová ikona má navyše ~12 % vnútorný okraj, aby v tlačidle nelícovala s hranou; sprite ho nepotrebuje)
a tým, že sprite kreslí `currentColor`. Zhodu kriviek aj veľkosť loga v hlavičke (**24 px** podľa kontraktu UI 2.0) stráži `tests/pure/test_ui02_toolbar.rb`.

**Zapnutý stav nesie `set_validation_proc`** (`MF_CHECKED`, `MF_GRAYED` keď kontrola hrán v danom SketchUpe nie je) — proc beží pri každom prekreslení UI, takže je lacný a **nikdy
nepustí výnimku von** (`Engine.toolbar_state`). Prepnutie ABS **NEROBÍ toolbar sám** — volá zdieľanú `Engine.toggle_edge_check` (UI-B1): tá zavolá `EdgeCheck.toggle` a novým stavom
cez `Engine.broadcast_edge_check` obslúži **všetkých klientov naraz** — ŠTÚDIO (lišta sekcie Kontrola) aj rail Inspectora (`Panel.push_edge_check`). Tou istou metódou ide klik z
panela (`nx_edge_toggle` → `Panel.handle_edge_toggle`) aj zo Štúdia (`do_edge_check`), takže sa cesty nemôžu rozísť; oba pushe sú defenzívne (`js` má vlastný guard).

Po prepočte cache posiela stav obom oknám aj `EdgeCheck.notify_count_changed`; pri **prepnutí dokumentu** (`on_model_changed` → `disable!`) ho rozpošle
`EdgeCheck.notify_state_changed` — bez toho by okná ďalej hlásili zapnuté zvýraznenie nad novým modelom a ďalší klik by ho zapol namiesto vypnutia.

**Z toolbaru sa do modelu NEZAPISUJE** (lekcia D-103/D-105): žiadny `start_operation`, `Panel.show_insert` čistí výber pod `suspend_selection_sync` a panel obnovuje s `dedup:
false`. Dvojitú registráciu pri reloade drží `@toolbar` memo (guard test `tests/pure/test_ui02_toolbar.rb`).

## Inspector — kostra a kontexty

### Inspector — kostra (UI-B1, ui/js/shell.js)

vľavo **rail** kontextov, vpravo jednoradová sticky hlavička (logo + identita + ⚠ chip) a obsah v **4 sektoroch** (`S1 Náhľad · S2 Základné · S3 Materiály · S4 Nastavenia`). Kostra
v `panel.html` je **STATICKÁ** — prepínanie mení iba triedy a atribúty na `<body>`; `innerHTML` re-render kostry je zakázaný (zabil by listenery, otvorené comboboxy D-85, rozpísané
hodnoty aj fokus) a stráži to guard test.

**Dva oddelené stavy** drží `NXShell`: `selectionMode` zo servera (`insert|cab|part|board` = dnešné body classes) a `viewContext` z UI (`korpus|zony|cela|kovanie`, platný LEN pri
`cab`, zrkadlí sa do `data-view-ctx` na `<body>` — atribút, nie class, prežije prepis `body.className`).

**Identita výberu** sa odvodzuje z payloadu (`<model_guid>|cab:<id>` / `…|part:<cab>/<role_key>` / `…|board:<id>` / `none`) v JEDINOM mieste zmeny režimu (`setUiMode(mode, sel)`).

**Identitu dokumentu nesie každý push** (`Panel.model_guid`) — ID sú jedinečné len v rámci modelu (`Ids.next_board_id` počíta v každom dokumente od začiatku), takže dva otvorené
dokumenty bežne obsahujú `CAB-001` aj `BRD-001`; bez guidu by prepnutie dokumentu vyzeralo ako echo push a panel by ostal v starom kontexte. Ten istý guid nesú aj **asynchrónne
callbacky panela** (`clear_selection`, `nx_edge_toggle`) a server ich pri nezhode odmietne a len obnoví stav: **nová identita ⇒ reset kontextu na Korpus**, **echo push tej istej
identity kontext ani zbalenia NEMENÍ** (auto-apply, Späť/Znova, refresh po zmene katalógu).

Pri `part`/`board` rail ukáže **dočasnú položku** s krížikom a kontexty **zosivejú** (guard v `setViewContext` + `aria-disabled`, vzor D-78 — HTML `disabled` sa nepoužíva); krížik
pri dielci ide existujúcou cestou `select_cabinet` → `handle_select_cabinet`, pri doske novým `clear_selection` → `handle_clear_selection` (výber sa čistí pod
`suspend_selection_sync` a refresh je `dedup: false` — vzor `Panel.show_insert`, žiadny zápis do modelu ani undo krok). Krížik dosky **najprv flushne rozpísané edity**
(`flushBoardEditsNow` — 400 ms debounce; `NX.clearSelected` ich cez `cancelBoardEdits` inak ticho zahodí, rovnaký handshake ako majú relay cesty Štúdia) a **nesie identitu dosky**
— callback HtmlDialogu je asynchrónny, takže server pred vyčistením overí, že je stále vybratá TÁ ISTÁ doska; inak výber nechá a panel len obnoví.

Krížik je **samostatné `<button>` vedľa** ukazovateľa (tlačidlo v tlačidle je neplatné HTML a `span` s `role="button"` nejde aktivovať klávesnicou); popis kontextu aj dôvod jeho
neaktívnosti idú do **vlastnej bubliny** `.railtip` a do `aria-label` — natívny `title` sa na raile zámerne nepoužíva (zdvojený tooltip). Akcie **z náhľadu** (klik na čelo, na
hranu dielca/dosky, na zónu) najprv **rozbalia cestu k cieľu** (`nxRevealTarget` otvorí všetkých `<details>` predkov) — zbalený sektor by fokus zhltol a combobox by sa otváral z
nulovej plochy.

**Rail ABS kontroly** je funkčný prepínač (`nx_edge_toggle` → zdieľaná `Engine.toggle_edge_check`); stav si panel **nedrží** — pull v `push_init` (`edge_check`) a push cez
`NX.setEdgeCheck`.

**Od v0.7.28 má FLYOUT ROH** (kontrakt UI 2.0 „shell so stavom a šípkou", vedomá odchýlka UI-B1 tým zaniká): v pravom dolnom rohu ikony je malý **plný trojuholník** (pseudo-prvok
`.railfly .railbtn::after`, 6 px — vzor flyoutu nástrojov SketchUp/Photoshop) a nad ním **samostatné tlačidlo `#railAbsMore`** pokrývajúce celý pravý dolný **kvadrant** (17 × 16 px
— 6 px trojuholník by bol pre myš neterč; vnorené tlačidlo je neplatné HTML, preto sused v obale `.railfly`).

Klik na ikonu = **toggle sa nemení**, klik na roh otvorí **3-stavové nastavenie** — a je to **TO ISTÉ nastavenie, aké má lišta sekcie Kontrola v Štúdiu**, nie druhá kópia: markup
kreslí zdieľaný `ui/js/edge_menu.js` (`NXEdgeMenu.menuHtml`, líši sa len id uzla, trieda polohy `.ecmenu-rail` a meno handlera), štýly sú v **zdieľanom** `panel.css` (zámerne
NEscopnuté pod `.nx-inspector` — satelitné okná o raile nevedia) a stav aj počty nesie výhradne server. Zápis ide `nx_edge_option` → `Panel.handle_edge_option` (whitelist kľúča +
**výslovný boolean** + prísny guard dokumentu, hláška bez Overlay API) → **zdieľaná `Engine.set_edge_check_option`**, ktorá zapíše do `%APPDATA%` a **rozpošle nový stav obom
oknám** (`broadcast_edge_check`) — preto sa zmena z railu okamžite prejaví v otvorenom Štúdiu aj naopak, vrátane živých počtov.

Okno zatvára **klik mimo a Escape** (`bindEdgeMenu` v `boot.js`, vzor warnpanelu; fokus sa vracia na roh) a **nikdy nestoja dve kópie naraz** — otvorenie na jednom mieste zavrie to
druhé (`nx_edge_menu_open` / `edge_menu_open` → `Engine.close_edge_menu(source)` → `NX.closeEdgeMenu`). Kľúč merača rohového kliku je vlastný (`rail:abs-nastavenie`). Testy:
`tests/pure/test_abs_rail_3stav.rb`, `tests/js/test_abs_rail_3stav.js`, in-SketchUp sekcia `run_d104` (blok 9d).

**Pod ňou stojí od v0.7.27 druhý funkčný prepínač „Kontrola kresby"** (`railKresba`, ikona `grain`, kľúč merača `rail:kresba`) — ten istý vzor s tou istou zdieľanou logikou, len
pre smer kresby (`nx_grain_toggle` → `Engine.toggle_grain_check`, pull `grain_check`, push `NX.setGrainCheck`, prisvietenie z čistej `NXShell.grainRail`); detail je v odseku
**grain_check**.

**Sektory sú `<details data-key="s1…s4">`** (zbalenie v `localStorage`, prežije echo aj zatvorenie panela); **viditeľnosť S2/S3 rozhoduje čistá funkcia `NXShell.sectorVis(mode,
ctx)`** — Základné a Materiály sú vlastnosti SKRINKY a patria kontextu **Korpus** (+ vkladanie), v Zónach/Čelách/Kovaní ich nahrádza **tenký kontextový riadok `#ctxNote`** so
súhrnom skrinky a preklikom cez `setViewContext('korpus')`; CSS pravidlá nad `#secBasic`/`#secMat` sú **zrkadlom** tejto funkcie (UI-B1 dala do CSS mapu len pre režim výberu a
kontextovú časť ticho vynechala — odtiaľ regresia opravená v 0.7.8; guard v `tests/pure/test_uib1_kostra.rb` + matica v `tests/js/test_uib1_kostra.js`).

Súhrn riadku skladá `NXShell.ctxNoteText` z rozmerov payloadu a popisu dekoru z katalógu (`sheetLabelOf`; prázdny `material_id` = „dekor dedí z projektu") — **žiadne nové serverové
dáta**; riadok si nesie viditeľnosť inline (vzor `renderPartCard`), CSS ho v `part`/`board`/`insert` drží skrytý ako poistku; **skupiny S4 nesú `data-s4="<kontext>"`** a sú v rámci
kontextu **EXKLUZÍVNE** (`NXShell.exclusiveClose`, kľúč `nxsec_s4.<ctx>.<key>`), výnimka `data-s4-solo` (strom zón) — sektory samotné sú nezávislé.

**Lišta každého sektora nesie vpravo META SÚHRN** toho, čo je vnútri (S1 názov kreslenej projekcie · S2 „900 × 720 × 560 · sokel 100" · S3 popisy materiálov · S4 otvorená skupina
menom, inak počet zbalených) — vidno ho rovnako zbalený aj rozbalený (vzor mockupu). Texty skladá **čistá funkcia `NXShell.sectorMeta`** (bez DOM, testovaná v
`tests/js/test_uib_meta.js`), stav do nej číta `nxSectorMetaApply` **zo ŽIVÉHO panela** (polia S2, materiálové selecty S3, otvorený `<details>` v S4) — **žiadna cache textu**
(hotový reťazec by po premenovaní dekoru ukazoval starý názov, lekcia Codex #171 P2) **a žiadne nové serverové dáta**.

Obnovuje sa na troch miestach: `nxShellApply` (režim, kontext, každý push), **jeden delegovaný `input`/`change` listener** na ID polí a selectov (meta je len zobrazenie — do
zapisovacích ciest `form.js`/`materials.js` nesiaha) a `toggle` v `bindDetails` (`toggle` nebublinkuje, delegácia ho nezachytí).

**Scroll ostáva dokumentový** (rail je `position: fixed` ľavý stĺpec, hlavička sticky, `scroll-padding-top` a warnpanel je od UI-D3 **overlay v hlavičke**, takže `scrollTo` pri
otvorení zaniklo). CSS kostry je scopnuté pod `.nx-inspector` na `<html>` — `panel.css` zdieľajú satelity. Pätička s verziou (z Ruby); fit žije od UI-B2 v spodnom páse náhľadu (nie
ako rohový overlay); náhľady `#partSvg`/`#boardSvg` patria do S1, karty s poľami do S4. Čisté jadro testuje `tests/js/test_uib1_kostra.js`, kontrakt kostry
`tests/pure/test_uib1_kostra.rb`, serverovú stranu sekcia `run_uib1` in-SketchUp runnera. Náhľad so zoom/pan/fit v `preview.js` (výška rastie s oknom panela, debounce prekreslenia
500 ms). Karta zóny pod náhľadom; karta dielca s omrvinkou ‹CAB›; karta Doska v `board_card.js` s guardom oneskorených zápisov (echo board_id).

**Vkladacia karta dosky (tiež `board_card.js`) drží rozpísané hodnoty proti živému refreshu katalógu** (`NX.setMaterials` → `refreshInsertBoardMaterials`): katalógová predvoľba sa
do poľa zapíše len vtedy, keď na to má právo — hrúbka podľa `insertThicknessShouldWrite` (E-03: pri nezmenenom UNI materiáli drží draft), **smer dekoru podľa
`insertGrainShouldWrite` (D-86: pri nezmenenom materiáli drží vedomú voľbu — príznak „používateľ siahol" z `onchange`, ktorý po dosadení predvoľby padá)**. Hrúbkový guard sa na
smer použiť NEDÁ (pri rovnakom reálnom materiáli vracia `true`, lebo pole je zamknuté — smer sa však dá meniť pri každom materiáli).

**Marker „pre ktorý materiál je pole zosynchronizované" je VLASTNÝ pre každé pole** a pri zápise potlačenom výhradne fokusom sa **neposúva** (`insertMatMarkAdvances` — Codex #163
P2): inak by sa výmena materiálu počas fokusu stratila a ďalšie refreshe by ju tvárili ako „bez zmeny". Odložený zápis dokončí `onblur` selektu alebo ďalší refresh. Všetky funkcie
sú čisté (krok smeru celý ako automat `insertGrainSync`) a testované (`tests/js/test_e03_board_insert.js`).

**UI-C1b** vkladaciu kartu prekreslila (segmentové tlačidlá typu, dlaždice šablón, dvojstĺpcové rozmery dosky, projekcia `insert`) — detail je v odseku **„Vkladacia karta —
šablóny, typ a doska“** nižšie.

### D-08 kontexty

Korpus·Zóny·Čelá·Kovanie: režimové taby v hlavičke **nahradil rail** (UI-B1) a atribút `data-cab-tab` sa premenoval na `data-view-ctx`. Kontext prepína náhľad AJ viditeľné skupiny
S4 cez CSS; v `preview.js` ostal už len prevod `cabTabPreview(ctx)` → režim náhľadu (`cab | zones | fronts | hw`). Kontext sa **nepamätá cez zmenu výberu** — nová identita ho
vracia na Korpus (A1); dielec vynúti zónový náhľad; jednozónová skrinka auto-ukáže kartu Zóna (D-03).

### Obsah Korpusu — Základné v dvoch stĺpcoch + koliesko (UI-B3, ui/js/settings.js)

sektor **Základné** je `.basicgrid` — **vľavo VSTUPY** (Šírka·Výška·Hĺbka·Sokel·Hrúbka; kompaktné riadky `.rowc` s ikonou zo spritu), **vpravo `.infocol` = dopočítané ÚDAJE ako
TEXT** (Vnút. šírka · Vnút. hĺbka · Úložná výška · Dielcov · Materiál m² · Hmotnosť „—"). Zásada „**výstupy nikdy nevyzerajú ako vstupy**": tri readonly `<input>`y svetlých
rozmerov sa stali `<b>` s **rovnakými ID** (`av_width`/`av_depth`/`av_height`) a zapisuje ich `setOut()` (textContent), nie `setVal()`.

**Polia si držia svoje ID aj svoju change cestu** (`oninput="onField()"`, zámky D-39, výrazy `expr.js`) — dávka do nich nesiahla.

**Rozmerový rad (N6)** je len PONUKA: šípka `.pbtn` otvorí `.miniopts` (naraz najviac jedna, klik mimo zatvára), voľba **zapíše hodnotu do poľa a vystrelí pôvodnú udalosť `input`**
— ďalej beží presne to, čo pri písaní rukou (validácia, expr hint, debounce apply, synchronizácia zámkov).

**Žiadna nová zapisovacia logika a žiadny callback do Ruby pri výbere hodnoty.** Hrúbka rad zámerne NEMÁ (určuje ju materiál — D-45). Čísla informačného stĺpca počíta **server**:
`cabinet_payload` nesie `parts_count` + `parts_area_m2` z `Panel.cabinet_stats` — čisté čítanie snapshotov dielcov s **rovnakým filtrom ako `Bom.collect`** (`kind=part` +
`manufactured` + `production_class=sheet`, takže proxy kovania sa do počtu nedostane); hodnoty sú **tranzientné** (do configu ani snapshotu sa neukladajú, žiadna zmena schémy).

**Klikateľné sú len tie údaje, ktoré niekam vedú (N13):** „Dielcov" → `nx_select_parts` → `Panel.handle_select_parts` = **čisté čítanie + zmena výberu** pod
`suspend_selection_sync` a refresh `dedup: false` (vzor `ProductionCore.do_select`; **žiadny `start_operation`, žiadny krok Späť**), s prísnym guardom `model_guid` + `cabinet_id`
(asynchrónny callback). Klik má **rovnaký flush handshake ako „Vložiť kópiu"** (Codex audit UI-B3): zmena výberu si vypýta push celej skrinky, ktorý prepíše formulár — rozpísaný
edit (400 ms debounce) by sa bez flushu ticho stratil, a **červené pole akciu zastaví** (flush by ju aj tak neaplikoval).

**„Materiál" od UI-D3 vedie do KUSOVNÍKA** — `openStudio('bom', cabinet_id)` otvorí ŠTÚDIO rovno na sekcii Kusovník a **ID skrinky ide ako kotva**, ktorá predvyplní hľadanie (sľub
UI-D3 o filtri na jednu skrinku sa tým splnil; status to povie nahlas aj s tým, ako sa zúženie zruší). Bez označenej skrinky sú riadky `aria-disabled` (nie HTML `disabled` — vzor
D-78).

**Typ badge** v hlavičke je readonly (`nxCabInfo(c).type`, slovenské názvy typu žijú na jednom mieste) — typ sa nastavuje výhradne šablónou/vkladaním; mini-modal „Uložiť ako
šablónu" preto nesie **Názov + Typ** a `handle_save_template_as` typ zapíše do `config['type']` uloženej šablóny (whitelist v Ruby; odlišnosť od skrinky povie status — rozmery a
konštrukcia ostávajú z tejto skrinky). Modal drží identitu **skrinky AJ dokumentu** (`tplModalGuid`, prísny serverový guard) — ID skriniek sa naprieč dokumentmi opakujú, takže
modal otvorený nad jedným modelom by po prepnutí uložil skrinku z iného; a **červené pole uloženie zastaví** (flush by edity neaplikoval a šablóna by vznikla zo starých hodnôt s
hláškou o úspechu).

**Koliesko raily** otvára **modal** `#cfgModal` (Vzhľad = prepínač témy · Rozmerové rady = editor `DimSeries` · O plugine = logo + verzia z Ruby) — vedome NIE piaty kontext raily:
nastavenia počítača nepatria do stavového stroja `NXShell` („čo je označené × čo chce používateľ vidieť") a musia byť dostupné aj bez označeného objektu; „Upraviť rad…" v ponuke
otvára ten istý modal rovno na sekcii Rady. Rady chodia do panela v `push_init` (`ui_settings`) a po zmene malým pushom `NX.setUiSettings` — ten mení **len ponuky a stav
prepínača**, nikdy neprekresľuje kartu (vzor `NX.setUsedIds`).

**Téma v tomto payloade NIE JE** (a nesmie pribudnúť): farby nasadzuje výhradne `nxThemeApply` kanálom `win_fit.js` a JS len číta `data-nx-theme` z koreňa — druhý kanál by znamenal
dva zdroje pravdy o farbe okna; push po zmene témy tu slúži len na **presvietenie tlačidiel** (`nxSyncThemeButtons`). Čisté jadro (normalizácia radu zrkadliaca Ruby, texty stĺpca,
kostra) testuje `tests/js/test_uib3_korpus.js`, serverovú stranu a perzistenciu `tests/pure/test_uib3_rady.rb`.

### Náhľad = kontextová projekcia + spodný pás (UI-B2, ui/js/preview.js)

každý kontext kreslí **svoj** pohľad (výmena, nie vrstvenie) — **Korpus** čelný rez s kótami (Š dole, V vpravo, sokel/telo vľavo, hĺbka kótou na náznaku skosenia hornej plochy),
**Zóny** zónová schéma + kóty šírok stĺpcov, **Čelá** predný pohľad + kóty výšok riadkov a medzier, **Kovanie** NOVÁ projekcia s pozíciami (záves = krúžok s krížikom na závesovej
hrane · **výsuv = koľajnica „L" pri OBOCH bokoch + telo šuflíka medzi nimi** — schválené Michalom 20.8. nad mini náhľadom, nahradilo pás naprieč čelom; geometriu skladá čistá
funkcia `nxSlideGeom` (pätka dovnútra, telo odsadené ZA pätkami, všetko pomer z výšky čela ⇒ pri viacerých zásuvkách nad sebou telá rastú s čelami); **ankerom sú VNÚTORNÉ LÍCA
BOKOV `x = t … W−t`** — tie isté, aké kreslí `drawCarcass` — nie `fr_gap_sides`, lebo výsuv drží bok, nie čelo (Codex #184 P2: pri medzere 2 mm a hrúbke 18 by koľajnica ležala na
doske boku, pri zápornom presahu čela až mimo korpusu); nezmyselná hrúbka (`2t ≥ W`) padá na celý korpus, nie na stratenú značku, kresbu vetva `slide_rail` v `hwMarkSvg` —
koľajnica je ťah, preto má navyše **priehľadný široký duplikát `.hwhit`** ako hit-oblasť a hover CSS ho vynecháva (`path:not(.hwhit)`) · nohy = obdĺžniky v pásme sokla) + súhrn
položiek pod ňou, **Dielec** hrany s ABS (`#partSvg`, nezmenené).

**UI-C1b pridala projekciu `insert`**: pri korpuse sa kreslí **šablóna tak, ako bude vložená** (čelný rez s kótami + čelá), pričom čelá sú **prepínateľná vrstva zapnutá defaultne**
(`NXLayers.DEFAULT_ON`) — po zhasnutí vidno vnútro šablóny; server resolved čelá v tomto režime NEEXISTUJÚ (`frontItems` je `null` — pasca Codex FIX 11), preto ich dopočíta **čistý
draft resolver** `nxFrontsResolve` (zrkadlo `Fronts.layout`: fixné výšky sa sčítajú, zvyšok sa delí medzi AUTO riadky, čelá idú odspodu). Pri **doske** kreslí
`renderInsertBoardPreview` obdĺžnik so **šípkami smeru dekoru** (N10) z polí vkladacej karty a vlastnou scénou `pvBoardScene` (miesto na kóty vpravo a dole); všetky chipy vrstiev
sú vtedy neaktívne s vysvetlením. Sektor Náhľad sa už pri vkladaní dosky **neskrýva**.

**Žiadne nové dáta:** kreslí sa výhradne z payloadov, ktoré panel už dostáva — rozmery formulára, `front_items`, **`config.hardware` (uložený do `hwItems` pri tom istom pushi,
ktorý plní sekciu kovania)** a strom zón; odvodenie (pozícia značky z `owner_part_key` + `generic_type`, medzera ako rozdiel susedných čiel, dedup stĺpcov zón) sú **čisté funkcie**
`nxHwMarks` / `nxSlideGeom` / `nxHwSummary` / `nxFrontDims` / `nxZoneSpans`. Kovanie sa ani tu **nečíta z geometrie** (invariant) a značka je **orientačná** — strana závesu
jednokrídlových dvierok v dátach nie je, preto tooltip pomenúva vlastníka presne.

**UI-C4 dala značke `data-owner`** (ten istý `owner_part_key`, ktorý už prišiel v payloade — žiadne nové dáta): klik ide na `nxHwMarkPick` v `hardware.js`, teda označí vlastníka v
modeli a dotiahne jeho box v sekcii Kovanie; keď box neexistuje (sekcia ešte nemá dáta), ostáva pôvodné správanie z UI-B2 — popis položky v statuse. Geometriu berú všetky vrstvy z
**jedného** `pvGeom()`, aby sa dve kresby nemohli rozísť; scéna (`sceneSize`) si pre každú projekciu rezervuje presne toľko miesta, koľko jej kóty potrebujú (drag priečok počíta
cez `viewMapping`, takže rozšírenie scény ho nemení).

**Spodný pás** (`.pvbar`, statická kostra v `panel.html`, obsah kreslí `renderPvBar`): vľavo **chipy vrstiev** Zóny·Čelá·Kovanie·Olep — chip kontextu je **základ** (nedá sa
zhasnúť), ostatné sa dajú **prisvietiť ako ghost** (tlmené čiarkované linky, `pointer-events: none`, žiadne výplne ani kliky); **Olep** je mimo kontextu Dielec **neaktívny s
vysvetlením** (hranové dáta nesie iba `part_card`) a rovnako je neaktívny každý chip bez dát — `aria-disabled`, nie HTML `disabled` (vzor D-78). Stav chipov je **per kontext v
pamäti okna** (`NXLayers`) a **nová identita výberu ho resetuje** rovnakou cestou ako `viewContext` (`setUiMode` → `NXShell.track` → `NXLayers.reset`), echo push ho nemení. Vpravo
**kamera (N7)** a **fit** — fit sa sem presunul z rohového overlayu (jedno miesto ovládania, čistá plocha SVG).

**Kamera je čisté čítanie:** `nx_camera_focus` → `Panel.handle_camera_focus` (`ui/panel/selection.rb`) postaví čelný pohľad (`view.camera.set` — oko v −Y od stredu obálky, hore +Z)
a doramuje `view.zoom(entity)`; kamera **nie sú dáta modelu**, takže ŽIADNY `start_operation`, žiadny zápis a **žiadny krok Späť** (lekcia D-103), a výber sa nemení. Guard je
**prísny** ako pri `clear_selection` — payload nesie `model_guid` aj `cabinet_id` (callback HtmlDialogu je asynchrónny a ID skriniek sa naprieč dokumentmi opakujú); nezhoda = len
hláška.

**D-27 tým NIE JE uzavreté** — chipy prepínajú vrstvy náhľadu, nie tagy modelu. Čisté jadro testuje `tests/js/test_uib2_nahlad.js`, zdrojové guardy
`tests/pure/test_uib2_nahlad.rb`, serverovú stranu sekcia `run_uib2` in-SketchUp runnera.

**UI-C2 zmenila ťahanie priečky:** delegácia beží na `pointerdown` (bez `pointerId` sa nedá nastaviť **pointer capture**, a bez capture visiaci `mouseup` mimo okna nechal ťahanie
zaseknuté aj s neuloženým stavom) a drag končí na `pointerup`/`pointercancel`/strate fokusu — vždy cez jediné `endDivListeners`.

**Magnet (N20)** prilepí priečku na 1/4 · 1/2 · 3/4 cez **zdieľanú** `nxZoneSnapCum`, teda tú istú geometriu, akou počíta pole „Prvá zóna“ (poloha priečky a číslo v poli sa nemôžu
rozísť); prah je **v pixeloch prepočítaných aktuálnym zoomom** (pri priblíženom pohľade musí ísť doladiť na desatiny mm) a **Alt ho vypína — rozhodne sa PRED aplikáciou**. Ukladá
sa mm Float 0,01 (`nxRound2`), nie celé mm.

### Kontext Zóny (UI-C2, panel.html + ui/js/actions.js + ui/js/zone_tree.js)

poradie skupín je záväzné — **Štruktúra zón NAVRCH** (`data-s4-solo`, teda mimo exkluzivity: strom sa nesmie zatvoriť pri otvorení inej skupiny), pod ňou **Delenie zóny · Police ·
Vnútro**. Kostra je STATICKÁ (A4): JS píše len obsah `#zoneTree` / `#zoneFields` a stavy existujúcich uzlov.

**Strom kreslí spojnice** vnorenými kontajnermi `.zkids` (odsadenie paddingom by čiaru nakresliť nevedelo; prázdny kontejner listu sa nezobrazuje); **úroveň nad `MAX_LEVELS` je
NEklikateľný varovný riadok** (`.znode.deep`) — legacy strom sa nikdy neoreže, len sa prizná.

**Aktivita ovládačov je pravidlo, nie kozmetika:** dlaždice delenia (2/3 stĺpce · 2/3 riadky) a pilulky políc 0–6 sú aktívne **LEN na listovej zóne** (na delenej sú viditeľné, ale
`aria-disabled` s vysvetlením — vzor D-78; klik na ne povie dôvod, nemlčí), pole **„Prvá zóna“ naopak žije len na DELENEJ zóne** (edituje jej pole 1). To isté pravidlo vynucuje
server (`ui/panel/actions_zones.rb`) — HTML `disabled` sa za ochranu stavu nepovažuje.

**„Prvá zóna“ je skratka na pole 1** (B5: vyplnená hodnota pole ZAMKNE, prázdna odomkne — vzor Čelá „zamknuté ⇔ vypísané“); úplná cesta so zámkom KAŽDÉHO poľa ostáva v
`#zoneFields` pod ňou.

**Presná cesta (N21) nezmestiteľnú hodnotu ODMIETNE** (`nxZoneExactCuts`) — žiadne tiché zmenšenie; zvyšok sa deterministicky dorovná do POSLEDNÉHO odomknutého poľa a všetko sa
ukladá s presnosťou 0,01 mm. Zlomkové presety (1/4 · 1/3 · 1/2) skladá `nxZoneFractionOptions` z tej istej zdieľanej geometrie a **nedosiahnuteľný zlomok sa neponúka**; ponuka je
bežná `.miniopts` (otvorená je vždy najviac jedna, zatvára ju `nxDimCloseMenus`).

**Draft režim vkladania má PLNÚ paritu** (F10): server tam neexistuje, takže listovosť, hĺbka aj strop políc sa kontrolujú lokálne **pred** vetvou draft/server a každá draftová
vetva volá `nxDraftChanged()`.

**Všetky zónové callbacky idú cez `nxZonePayload`** — jedno miesto, ktoré k requestu pridá `model_guid` + `cabinet_id`.

**Vnútro je rezervovaný slot** (bez polí, po V1). Čisté jadro testuje `tests/js/test_uic2_zony.js`, serverový a kostrový kontrakt `tests/pure/test_uic2_zony.rb`, živý model sekcia
`run_uic2` in-SketchUp runnera.

### actions_zones.rb — zónové akcie servera

všetky handlery (`split_zone` · `set_zone_shelves` · `clean_zone` · `set_zone_field` · `select_zone`) prechádzajú spoločným vstupom **`zone_ctx`**, ktorý **PRÍSNE** overí identitu
dokumentu (`model_guid`) aj skrinky (`cabinet_id`) a **formát celého `zone_id`**. ID zón sa medzi dokumentmi opakujú (`CAB-001-Z1.2` je v každom projekte), takže oneskorený
callback CEF by po prepnutí dokumentu prestaval cudzí model.

**`Panel.zone_path` vracia pri poškodenom ID `nil`, NIE koreň** — dovtedajší fallback `[1]` znamenal, že preklep alebo orezaný reťazec poslal „Vyčistiť zónu“ na koreň a zmazal celé
vnútro skrinky.

**`apply_zone_mod` vetví návratovú hodnotu mutácie**: `false` = strom sa nezmenil ⇒ chybový status a **žiadny rebuild** (predtým sa skrinka prestavala a status hlásil úspech), a
volajúci hlási úspech až po úspešnej mutácii. Presnú príčinu odmietnutia skladá handler sám (`split_refusal`) — používateľ dostane „zóna je už delená, najprv Vyčistiť“ alebo „strom
má najviac 3 úrovne“, nie „nepodarilo sa“. `handle_set_zone_field` pred zápisom volá `ZoneTree.validate_cuts` so **svetlým priestorom zóny z PLÁNU** (`zone_clear_span` — tá istá
cesta, akou počíta builder, takže sa kontrola a stavba nemôžu rozísť; zlyhanie plánu = kontrola súčtu sa preskočí, ostatné pravidlá platia), a status presnej cesty číta z
**`cuts[index]`**, nie z prázdneho `size` (predtým hlásil „auto“ aj pri presnom rozmere).

**`zone_depth_note`** pridáva ORANGE varovanie k vloženiu (`handle_insert`) aj k aplikácii šablóny (`TemplatesDialog`), keď má strom viac než `MAX_LEVELS` úrovní — vloženie sa
**povolí**, orezanie je zakázané.

### Kontext Čelá (UI-C3, panel.html + ui/js/form.js + ui/js/core.js + ui/js/settings.js + ui/js/preview.js)

tri skupiny v **záväznom poradí** — **Zoznam čiel** (`data-key="fronts"`) · **Úchytky** (`fhandles`) · **Medzery a presahy** (`fgaps`). Riadok čela `.frow` je od SMOKE PACKU 1
**STĹPEC**: hore `.fmain` = ovládače v **pevnom, NEZALAMOVACOM** rade, pod ním riadok naviazaného kovania `.fhw`. Predtým bol `.frow` jeden zalamovací rad a pri **vypísanej** výške
(pribudlo „mm" + chip AUTO) súčet presiahol šírku panela — krížik `.fdel` padol o riadok nižšie a riadok sa rozbil (Michalov smoke test 20.8.). `.fmain` nesie: `.fnum` (kanonická
pozícia F1 dole — D-23) · **`.ftico` ikonu typu (N27**, mapa `FRONT_TYPE_ICON` je jediné miesto prekladu typ→symbol; mení sa `href` v `<use>`, nie innerHTML) · `select.ftype` ·
**`.dwrap` s úzkym poľom výšky (46 px, hodnota vpravo)** + šípkou **výškového radu (N25)** · `.funit` „mm" a **chip `.fauto`** · `select.fw` · **`.fprof` INDIKÁTOR profilu** ·
`.fdel`.

**`select.ftype` je JEDINÝ rastúci prvok** (`flex: 1 1 0`), všetko ostatné má pevnú stopu — riadok tak využije celú šírku a zároveň sa nikdy nezalomí; súčet stôp + medzier pri
obsahu 470 px stráži guard `tests/pure/test_smoke1_riadky.rb` (spadne pri pridaní ďalšieho ovládača, nie až na Michalovej obrazovke).

**Živý náhľad výrazu `.exprhint`** („= 450" pri `300+150`) je v riadku čela **overlay** (`position: absolute` pod poľom, `z-index` pod `.miniopts`, `pointer-events: none`) — ako
flex položka pridal do radu ~34 px, na ktoré `nowrap` už nemá rezervu, takže by riadok pretiekol presne tak, ako predtým zalamoval (Codex #183 P2). Je to ten istý vzor ako
`.miniopts` a warnpanel: *rozbaľovacie okno je overlay, nie nový riadok.* Medzi čelami je **hairline predel** `.frow + .frow` (`--nx-border-soft`) **bez nového vertikálneho
priestoru** — pôvodné `margin: 4px 0` sa presunulo do `padding: 2px 0 1px` + 1 px linka; predel leží **pod celým čelom**, teda aj pod riadkom kovania.

**ZÁMOK PRI VÝŠKE ZANIKOL: zamknuté ⇔ vypísané** — `collectFronts` posiela `locked: hasH`, takže jediná pravda o zámku je to, čo používateľ vidí (rovnaké pravidlo ako pole „Prvá
zóna" z UI-C2); chip AUTO pole vyprázdni a ohlási to **pôvodnou udalosťou `input`**, takže výrazy (`expr.js`), validácia aj debounce apply bežia nezmenene.

**Výškový rad `vyska_cela`** existoval od UI-B3, ale nebol napojený — riadky vznikajú za behu, preto svoju mini-ponuku nesú v **atribútoch** (`data-dim-key` + `data-dim-input`) a
plní ich `nxDimFillRow` (settings.js) **tou istou cestou** ako statické polia, takže úprava radu v koliesku sa premietne aj do už vykreslených riadkov.

**Naviazané kovanie** je JEDEN drobný riadok `.fhw` **vnútri `.frow`** (druhý potomok stĺpca, ellipsis, plný text v `title`) — DOM zoznamu tak ostáva „jeden `.frow` = jedno čelo" a
obrátený render D-23 platí bez zmeny; text skladajú dva **existujúce** zdroje (`frontHwBadge` z plánu + `frontHwBuy` = `purchase.set_name` z D-92), klik prepne kontext na Kovanie a
doskočí na **box vlastníka** (`hwBoxByGroup(hwFrontGroup(fid))` — kľúč skupiny skladá JEDNA funkcia pre render aj pre skok, takže sa nemôžu rozísť; `.hwfocus` krátke zvýraznenie).

**D-84:** tlačidlá `+ pridaj dvere` / `+ pridaj čelo` posielajú typ do nového riadku; odoberacie tlačidlo aj `removeLastFront` zanikli.

**Materiál čiel** má DRUHÝ ovládač (`cab_front_c`) priamo v zozname, lebo sektor Materiály patrí kontextu Korpus a tu je skrytý — tá istá hodnota, dva vstupné body, synchro drží
každá cesta, ktorá siaha na `cab_front`.

**Výklop** je v ponuke typov ako **disabled** voľba s upozornením (rola `flap` potrebuje vlastnú cestu cez builder/ABS/kusovník — vedomá odchýlka, dôvod v
`SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`); popis voľby je krátky zámerne — celá veta žije v `title` selectu a v hinte skupiny. *(Pôvodný dôvod „dlhý text by rad zalomil" po SMOKE
PACKU 1 zanikol: `flex-basis` selectu je 0 a rad sa nezalamuje. Krátky popis ostáva preto, že select je najužší prvok riadku a orezaná voľba nič nepovie.)*

### Úchytky = D-96 (form.js refreshFrontProfileUI / onFrontProfilePick + čisté funkcie v core.js)

profil sa už **necyklí ikonou v riadku** (pri viacerých profiloch a budúcej voľbe hrany osadenia by to bolo nepoužiteľné) — nastavuje sa v skupine pre **ROZSAH** (`all` / `door` /
`drawer_front`). Čisté funkcie: `frontProfileScopeItems` (typ `none` do rozsahu NIKDY nepatrí — rovnako to robí Ruby normalize) · `frontProfileCommon` → `'<id>'` | `''` (prázdny
rozsah) | `null` (rôzne → **disabled** voľba „(rôzne)", nikdy tichý výber) · `frontProfileStateText` (veta „UKW-7: F1, F2 · bez profilu: F3"). Zápis ide do **tých istých dát**
(`row.dataset.frontProfile`) a ďalej `collectFronts` → `apply_all`, takže server ostáva autoritou a nepribudlo žiadne nové pole ani callback. Aktivita sekcie závisí **výhradne od
obsahu rozsahu**, NIE od `selectedCabId` — `refreshFrontProfileUI` beží z `renderFronts`, teda ešte pred tým, než `loadSelected` nastaví identitu.

**Hrana osadenia sa neponúka**, kým ju registry (`core/front_profiles.rb`) nepozná.

### N26 medzery jantárovo (preview.js)

pri **otvorenej** skupine „Medzery a presahy" (alebo kurzore v jej poli) sa medzery v projekcii Čelá podfarbia jantárovo. Stav sa **číta z DOM** (`details[data-key="fgaps"].open`),
nedrží sa bokom — zbalenie skupiny zhasne zvýraznenie bez ďalšej synchronizácie; `toggle` NEBUBLÁ, preto listener v capture fáze. Pásy vznikajú z **toho istého** `nxFrontDims`,
ktorým sa už kótuje (žiadny nový výpočet, žiadne nové dáta); farby `PV_GAP_*` sú zrkadlom tokenov `--nx-warn-bg-soft` / `--nx-warn` / `--nx-warnchip-fg`.

### Kontext Kovanie (UI-C4, panel.html + ui/js/hardware.js + ui/panel/selection.rb)

tri skupiny v **záväznom poradí** — **Položky z pravidiel** (`data-key="hwitems"`) · **Sety** (`hwsets`) · **Pravidlá** (`hwrules`); kostra je STATICKÁ, JS píše len obsah **dvoch**
kontajnerov `#hwRows` a `#hwSetRows` (preto `refreshHardwareSets` obnovuje selecty v OBOCH — inak by novo pridaný set typu v skupine Sety ostal neviditeľný až do ďalšieho označenia
skrinky).

**Položky sú BOXY PODĽA VLASTNÍKA** (`.hwbox`): „Skrinka" · box KAŽDÉHO čela · spoločný box „Vnútro skrinky" pre ostatných vlastníkov (podperky políc). Je to **len ZOBRAZENIE tých
istých dát** — identita položky (`owner_part_key`, `generic_type`, `rule_id`), zápisové cesty (`set_hardware_override`, `set_hardware_set`), D-92 nákupný riadok aj D-93 zámok NL sú
nedotknuté; `refreshHardwarePurchase` ďalej páruje riadky cez `.hwrow[data-owner…]`. Kľúč skupiny je **ODVODENÝ** z `owner_part_key` (`hwGroupKeyOf`: prázdny → `cab`,
`front:<id>/…` → `front:<id>` (obe krídla = JEDEN box), inak `inside`) — žiadne nové serverové pole. Hlavička berie **PRVÚ časť** serverového `owner_label` („F2 · zásuvkové čelo" →
„Čelo F2"), riadok v boxe **DRUHÚ** („zásuvkové čelo") — číslo čela sa tak nikdy neopakuje dvakrát pod sebou; vo „Vnútre" ostáva v riadku CELÝ popis, lebo hlavička ho nenesie.

Poradie boxov: Skrinka → čelá **v poradí zoznamu čiel** (`frontItems`) → Vnútro; čelo mimo zoznamu (starý payload) sa nikdy nestratí. Meta v hlavičke je **počet** položiek (typy sú
vypísané hneď pod ňou — opakovať ich by bola redundancia).

**Hlavička je natívne `<button>` a SÚRODENEC tela boxu, nie jeho predok** — klik na select setu, zámok NL či pole počtu k nej nemá ako dobublať, takže žiadny budúci ovládač v boxe
nemusí pamätať na `stopPropagation` (štrukturálne silnejšie než ho pridávať). Box sa **nezbaľuje** — na skrátenie panela stačí exkluzivita skupín S4.

**SMOKE PACK 1 pridal dve veci a ani jedna sa nedotkla dát:** (1) **`.hwname` je jednoriadkový s ellipsis** a plný popis nesie `title` — bez orezu dlhý label („Výsuv zásuvkové
čelo") pretiekol a **prekryl** select dĺžky/setu pri default šírke 470 px; selecty (`.hwsetsel`, `.hwnlsel`) majú šírku **podľa obsahu v medziach** (`flex: 0 1 auto` + min/max,
vzor UX-03) a súčet stôp riadku stráži `tests/pure/test_smoke1_riadky.rb`. (2) **Podperky políc sú v boxe „Vnútro skrinky" ZBALENÉ pod jeden súhrnný riadok** („Podperky políc — 5
políc: 20 ks") — natívny `<details class="hwgrp">`, aby ho `nxRevealTarget` vedel otvoriť pri budúcom deep-linku; zbalené je default, stav rozkliku žije v **localStorage POČÍTAČA**
(`nx_hw_shelfpins_open`, rovnaký dôvod ako sektory a téma).

Pod rozklikom sú **pôvodné `.hwitem` riadky**, takže počet per polica sa edituje ďalej a `refreshHardwarePurchase` ich nájde (páruje selektorom, nie indexom detí). Delí sa **oboje
— `items` aj `offs`** (Codex #183 P2): vypnutá polica je stále polica, takže patrí pod ten istý rozklik a do počtu; do súhrnu prispieva **0 ks** a vždy zapína „upravené" (vypnutie
je ručný zásah). Bez toho by pri piatich policiach s jednou vypnutou súhrn tvrdil „4 police" a piata by visela vedľa neho. Zoskupuje sa **len vo `inside`** a **až od 2 políc
spolu** (`HW_PINS_MIN` — rozklik nad jediným riadkom je klik navyše bez zisku); ručne upravená polica rozsvieti v súhrne jantárový štítok **„upravené"** (odchýlka od pravidla, nie
chyba — semaforové `--nx-state-*` sa sem nemiešajú). Čisté jadro (`hwShelfPinSummary`, `hwSplitShelfPins`, texty) testuje `tests/js/test_smoke1_ui.js`.

Trieda je `.hwbox` (nie `.hwown` z mockupu): `.hwown` už označuje popis vlastníka VNÚTRI riadku a dva významy jednej triedy by sa poprali. Klik na hlavičku má **flush handshake**
ako „Dielcov" (`onInfoParts`), ale z iného dôvodu: nie kvôli prepísaniu formulára (táto cesta push nevyvolá), ale kvôli **výberu** — rozpísaný edit čaká 400 ms a keby timer dobehol
až PO výbere, `handle_apply_all` by skrinku prestaval a `finish_cab` by reselectol celý korpus, takže by sa práve kliknutý vlastník ticho stratil; neplatné pole akciu **zastaví**.

**Klik na hlavičku → `nx_select_hw_owner` → `Panel.handle_select_hw_owner`** (`ui/panel/selection.rb`): prázdne `part_keys` = celá skrinka (`reselect`), inak `parts_by_keys` =
výrobné dielce s daným `part_key` v **rovnakom rozsahu ako kusovník** (`manufactured_parts` — vnorené AJ odpojené). Je to **čisté čítanie + zmena výberu** pod
`suspend_selection_sync`: žiadny `start_operation`, žiadny zápis, **žiadny krok Späť** (lekcia D-103), prísny guard `model_guid` + `cabinet_id` (asynchrónny callback), nenájdený
kľúč sa **prizná hláškou** a výber nezhodí.

**Odmietnutý rozpísaný edit má prednosť** (rovnaký guard ako `handle_select_parts`): keď je `@last_apply_error` nastavený, akcia sa nevykoná, príznak sa **spotrebuje** a používateľ
dostane pôvodný dôvod — hlásiť nad ním úspech by prekrylo jedinú správu, ktorá hovorí pravdu o tom, prečo sa úprava nezapísala.

**Čiastočný výsledok sa neodmieta, ale ani nezamlčí** (Codex #179 P2): box môže niesť VIAC kľúčov (obe krídla, všetky police vo „Vnútre") a ukázať dve krídla z troch je stále to,
čo používateľ chcel — status sa preto pýta **označených dielcov** (`part_key` vybratých entít), nie žiadaných kľúčov, chýbajúce **pomenuje** a hlásenie sa označí ako upozornenie
(zásada „nikdy netvrdiť zhodu, ktorá neplatí").

**VEDOMÁ ODCHÝLKA — po výbere sa NEVOLÁ `push_selected`:** identita výberu je autoritou režimu panela, takže označený DIELEC by panel prepol na kartu Dielec a box, z ktorého sa
práve klikalo, by zmizol pod rukami. Panel už zobrazuje TÚ ISTÚ skrinku (dielec je jej súčasť), takže sa nič nerozchádza vo veci — len rail nedostane dočasnú položku; vzor je
`EdgeSelectionWatch`, ktorý na zmenu výberu tiež zámerne nepusha.

**Najbližší bežný push** (Späť/Znova, zmena katalógu, ďalší klik v modeli) panel zosúladí a vtedy sa karta Dielec ukáže — je to prijatá cena za to, že sekcia počas práce nezmizne.

**Obojsmerné prepojenie box ↔ značka** beží CSS triedou `hov` nad už vykresleným SVG **aj nad boxom** — obe strany nasadzuje **jedna** funkcia `hwPaintHover` (smery sa nemôžu
rozísť; vzor `setFrontHover`/`clearFrontHover` z D-23), zapína ju delegácia `bindHwOwnerHover` (viazaná RAZ na statický `#hwRows`) a z druhej strany `hwHoverByOwner` z delegácie
náhľadu — náhľad o konvencii boxov nevie a pýta sa jedného miesta pravdy. `renderPreview` sa počas hoveru NIKDY nevolá (lekcia D-23) a **obe prestavby** (`renderPreview` aj
`renderHardware`) zvýraznenie zhasnú, lebo im zaniknú uzly, na ktorých visí. Čisté jadro (skladanie skupín, poradie, texty) testuje `tests/js/test_uic4_kovanie.js`, zdrojové a
serverové invarianty `tests/pure/test_uic4_kovanie.rb`, živý model sekcia `run_uic4` in-SketchUp runnera (guardy identity, správne dielce, žiadna zmena modelu, žiadny undo krok).

**UI-D3** tú istú cestu prebralo aj pre **oko v riadku warnpanelu** (pole `origin` mení iba podstatné mená v statusoch) — jedna cesta, jedny guardy.

### Karta dielca (UI-D1, panel.html + ui/js/part_card.js + ui/panel/actions_parts.rb)

karta má poradie podľa kontraktu UI 2.0 — **Základné hore** (`#pcBasic`) · Materiál · hrany · **rad akcií dole**.

**ŠT-2d — preklik na DEKOR:** vedľa výberu materiálu (dielca aj dosky, `#pcMatLink`/`#bcMatLink`, trieda `.matlink`) stojí ikona, ktorá otvorí Štúdio na sekcii Materiály **priamo
na detaile toho dekoru** (`nxDecorLinkState` → `openStudio('mat', material_id)`; funkcia žije v `part_card.js` a `board_card.js` ju volá — jedna cesta, dva vstupné body). Ikona je
**v existujúcom riadku** (pravidlo vertikálneho priestoru), pri dielci bez rozhodnutého materiálu je `aria-disabled` s dôvodom (D-78), a **ABS pásky sa neprelinkúvajú** — hrana má
vlastný tok. Rozmery dielca sú **VÝSTUP** (počíta ich korpus), preto sú to informačné riadky `.inforow` v tej istej mriežke `.basicgrid`/`.infocol` ako Základné korpusu — nikdy
polia („výstup nikdy nevyzerá ako vstup"); pôvodný jednoriadkový `#pcDim` zanikol.

**`Smer dekoru` je od K1 (D-108, v0.7.23) VSTUP** — pôvodná vedomá odchýlka UI-D1 („smer je len informácia") tým skončila. Je to statický segment `#pcGrainRow` v riadkovom tvare
„popisok + ovládač" (trieda `.pcgrain`, rovnaká mriežka ako `Materiál`, takže karta nenarástla o samostatný riadok) s tromi voľbami `inherit | length | width`; zápis ide vlastným
callbackom `set_part_grain` → `Panel.handle_set_part_grain` (enum guard proti `CabinetBuilder::GRAIN_OVERRIDES`, guard dokumentu aj skrinky, **jedna prestavba = jeden krok Späť**,
vzor D-35).

**Všetky texty skladá server** (`Panel.part_grain_payload`, vzor D-102): dedený stav ukazuje **VÝSLEDOK** („Podľa materiálu — pozdĺžna", nie prázdne „dedí") a každá voľba nesie v
tooltipe **výrobný rozmer** (2000×250 vs 250×2000) — presne ten rozdiel, ktorý pri incidente 19.8.2026 vyšiel najavo až v objednávke.

**Autoritou zobrazeného výsledku je SNAPSHOT dielca** (`grain_effective` = `cfg['grain_direction']`), nikdy živý katalóg: ten sa medzi prestavbami mení (materiál sa dá zmazať,
`grain` prepísať, `.skp` otvoriť na stroji bez toho záznamu) a dopočet by tvrdil iný smer aj iný výrobný rozmer, než s akým dielec ide do VEPO. Katalóg dáva len **prospektívny**
údaj `grain_pending` (čo by vyšlo pri najbližšej prestavbe, cez tú istú `CabinetBuilder.effective_grain`); keď sa rozíde so snapshotom, karta to **povie hintom**, nezamlčí.

**Sentinel dedenia na drôte je `__inherit__`** (ten istý ako pri hranách) — segment používa UI token `inherit` a prekladá ho `nxGrainWire`; zhodu oboch strán zamyká test, lebo
rozídenie by server odmietlo ako neznámy smer a override by aj s rotáciou vo VEPO ticho ostal.

**Zápisová cesta má tri guardy a od v0.7.25 ich drží JEDNA spoločná brána `part_target_error(model, cab, params, rk, what)`** (`what` = predmet zmeny do hlášky): **dokument**
(`model_guid` — ID skriniek sa naprieč dokumentmi opakujú), **cieľ zmeny** (vo výbere musí byť dielec a jeho kľúč musí sedieť s kľúčom karty — výber sa medzi klikom a callbackom
mohol posunúť) a **odpojenosť**. Do v0.7.24 to bol grainový `grain_target_error` a ostatné cesty mali len odpojenostný guard; **Codex #186 (P1) ukázal, že delenie na „prísnu" a
„voľnejšiu" cestu nedrží**: keď sa výber presunie z dielca na **skrinku**, `find_cabinet` ju nájde, ale `find_selected_part` vráti `nil` — a voľnejšia cesta by podľa starého
`role_key` prestavala **vnorené dvojča**, teda presne tá škoda, ktorú mal guard zastaviť.

**Prázdny výber je preto ODMIETNUTIE, nie priepustná vetva** („o odpojenosti sa bez dielca nedá tvrdiť nič" bola nesprávna otázka — brána netvrdí o odpojenosti, ale o **cieli
zmeny**). Brána stojí **až za** `existing_params` + `canonical_part_key` (potrebuje kanonický kľúč), ale **pred** akýmkoľvek zápisom aj pred
`virtual_duplak_probe`/`ensure_missing_abs`. Bulk olep si necháva vlastnú **tichú** vetvu `if part.nil?` — tam ide o stale echo z prekliku, nie o akciu, ktorú by bolo čo hlásiť
(odpojenosť však hlási nahlas, viď nižšie).

**ODPOJENOSŤ je od v0.7.24 spoločný guard `detached_part_error` a prechádzajú ním VŠETKY zápisové cesty karty** — ABS hrana (`handle_set_part_edge`), bulk olep
(`handle_set_part_edges_all`), materiál dielca (`handle_set_part_material`), smer dekoru aj **zdroj** „Použiť na podobné" (`similar_context`, teda živý počet aj zápis). Dielec
vytiahnutý na najvyššiu úroveň sa cez kartu meniť **nedá** a povie to nahlas: `find_cabinet` jeho vlastníka podľa `cabinet_id` nájde, takže bez guardu by prestavba zmenila **iný,
vnorený** dielec toho istého `part_key`, kým vybraný odpojený by si držal svoj snapshot a do VEPO šiel po starom — pri hlásení o úspechu (tá istá lekcia ako `regenerated_parts` v
UI-D1). Pri ABS to nie je kozmetika: z pluginu sa objednávajú reálne zákazky, takže tichý zápis na dvojča pošle do objednávky **pásku, ktorú nikto nevidel na obrazovke**.

Odpojenosť sa pozná podľa rodiča (`nested_part?` — vnorený dielec má za rodiča definíciu skrinky), hláška menuje **čo** sa nezmenilo aj **čo robiť** (vrátiť dielec do skrinky,
alebo zmenu urobiť na dielci v nej), guard stojí **pred** akýmkoľvek zápisom do modelu **aj pred tvorbou ABS v globálnom katalógu** (ten je mimo undo) a jeho odmietnutie **nevyrobí
žiadny krok Späť**. Vetva `part.nil?` v samotnom `detached_part_error` ostáva len ako **poistka** — chýbajúci výber odmieta každý volajúci sám (brána hláškou, bulk tichým
zahodením), takže mlčky prejsť je bezpečné jedine vtedy, keď už niekto pred ňou povedal nie. Bulk olep pritom odmietnutie **hlási** (na rozdiel od tichého zahodenia stale echa) —
používateľ práve klikol a musí vedieť, že sa neolepilo nič.

Chýbajúce `grain_options` v payloade segment **zamknú a popisy vrátia na neutrálnu zálohu z kostry** — nikdy nenechajú tooltip s výrobným rozmerom predošlého dielca. Po zmene
katalógu posiela `push_materials` **aj čerstvý payload karty** (`push_part_card` → `NX.setPartCard`): `NX.setMaterials` prekresľuje kartu z **cachovaného** payloadu, takže serverom
skladané údaje (zámok, hint, výrobné rozmery, texty hrán D-102) by inak zamrzli až do ďalšieho prekliku výberu. Je to **čisté čítanie** (žiadna operácia, žiadny dedup, lekcia
D-103) a bez označeného dielca **neposiela nič** — schovanie karty patrí výhradne `push_selected`. Ručný zásah je jantárový (`.ovr` — rovnaký jazyk ako `select.ovr`), materiál bez
smeru segment **zamkne cez `aria-disabled`** (vzor D-78, nikdy HTML `disabled`) + hint, a klik v zamknutom stave nezapisuje, ale odvedie na materiálový combobox
(`onPartInfoGrain`).

Čistý stav segmentu počíta `nxGrainSegmentState` (Node testy); chýbajúci payload segment **zamkne** — radšej nič než náhodný stav.

**Hranový riadok začína ikonou `#i-edge`** — JEDNA kresba a **štyri rotácie** cez `data-rot` (CSS, nie štyri ikony); uhol dáva **strana v 2D náhľade** (`pc.edge_sides` =
`AbsRules.edge_sides`, jediný zdroj pravdy o orientácii dielca), takže ikona ukazuje presne tú hranu, ktorú náhľad nad zoznamom farebne kreslí — **vedomá odchýlka** od pevnej mapy
„predná 0°·zadná 180°·ľavá 90°·pravá 270°" z mockupu, ktorá by pri ležiacich dielcoch aj výstuhách ukazovala inú stranu než náhľad (a pre roly s labelmi „Pozdĺžna/Priečna" by
neexistovala). Hover hrany do modelu (D-89a) ostal nezmenený.

**„Označiť v modeli"** (`nx_select_part` → `Panel.handle_select_part`) je **čisté čítanie + zmena výberu**: žiadny `start_operation`, žiadny zápis, **žiadny krok Späť** (lekcia
D-103, vzor `handle_select_parts`/`handle_select_hw_owner`), prísny guard **dokumentu aj skrinky** a dielec sa hľadá podľa `part_key` (skrinka sa medzitým mohla prestavať).

**„Použiť na podobné…"** je mini-modal (`#simModal`, vzor D-14): prenáša **VÝHRADNE olep hrán** — materiál, rozmery ani smer dekoru sa nedotknú.

**Definícia „podobný" je záväzná a žije len na serveri:** rovnaká **rola** + rovnaký **výsledný materiál** (`material_id` zo snapshotu dielca) v zvolenom rozsahu (`cabinet` |
`project`, whitelist `SIMILAR_SCOPES`), okrem zdroja; rovnaká rola je podmienka, nie kozmetika (kódy `L1/L2/W1/W2` znamenajú pri každej role inú fyzickú hranu —
`AbsRules::EDGE_LABELS`), samostatné dosky do výberu nepatria. Kandidátov berie **`regenerated_parts`** = výhradne dielce **vnorené v definícii korpusu**, teda tie, ktoré prestavba
naozaj prekreslí; `manufactured_parts` vracia navyše **odpojené** dielce (vytiahnuté na najvyššiu úroveň, viazané už len atribútom `cabinet_id`) a tie by `rebuild_many` nezmenil —
počítať ich by znamenalo sľúbiť zmenu olepu, ktorú by výrobné dáta (kusovník, VEPO) nikdy nedostali (Codex #180 P1).

**ZDROJ dostal rovnakú ochranu až v0.7.24** (`detached_part_error` v `similar_context`): olep zdroja sa číta podľa `part_key` z `params`, teda z overridu **vnoreného dvojčaťa** —
hromadná zmena spustená nad odpojeným dielcom by po projekte rozniesla olep, ktorý používateľ na karte nikdy nevidel.

**Živý počet aj zápis idú JEDNOU funkciou `similar_parts_map`** — inak by modal sľúbil iný počet, než sa zapíše; JS posiela len `role_key + scope` (žiadny zoznam cieľov) a odpoveď
chodí cez `NX.setSimilarCount`, ktorá prijme **len odpoveď na posledný odoslaný dopyt** — každý dopyt nesie rastúci **token `req`** a server ho vracia nezmenený (aj z chybovej
vetvy); kontrola samotného rozsahu nestačila, lebo po prepnutí `cabinet → project → cabinet` alebo po znovuotvorení modalu nad iným dielcom má oneskorená odpoveď rovnaký rozsah a
prepísala by stav nového cieľa (Codex #180 P2). Chybová odpoveď navyše nesie **požadovaný** rozsah — rozsah aj token sa čítajú pred akoukoľvek rizikovou prácou, inak by chyba pri
„celom projekte" prišla označená ako `cabinet`, klient by ju zahodil a modal by navždy visel na „počítam".

Zápis je **JEDNA operácia** cez `CabinetBuilder.rebuild_many` = **jeden krok Späť** aj naprieč skrinkami (vzor D-35, nikdy slučka rebuildov), prenáša sa **záznam overridu**
(prázdny override zdroja teda ciele **vráti na pravidlo** — je to tiež rozhodnutie), `edge_warnings` cieľa sa zahodia (patria starým hranám) a po prestavbe ostáva vo výbere
**zdrojový dielec** (`focus_part`). Modal si drží identitu z času otvorenia a zatvára sa pri prekreslení karty na iný dielec aj pri odchode z `mode-part`; pri prekreslení s **tou
istou** identitou (Späť/Znova, zmena katalógu) sa počet **zhodí na „počítam" a vypýta znova** — inak by okno sľubovalo číslo, ktoré už neplatí (Codex #180 P2).

**Enter modal neodchytáva** — nemá textové pole, takže Enter správne aktivuje to tlačidlo, na ktorom stojí fokus; globálny odchyt by Enter nad „Zrušiť" premenil na použitie
hromadnej zmeny (Codex #180 P1). Guardy a texty testuje `tests/pure/test_uid1_dielec.rb`, čisté funkcie `tests/js/test_uid1_dielec.js`, živý zápis a undo sekcia `run_uid1`
in-SketchUp runnera.

**Odpojený dielec má vlastnú sadu `tests/pure/test_abs_odpojeny_dielec.rb`** (jedno miesto hlášky, brána pred zápisom na každej ceste, chýbajúci dielec vo výbere ako odmietnutie +
správanie samotného guardu) a živý scenár v sekcii `run_k1`: vytiahnutý dielec označený → hrana, bulk, materiál aj „Použiť na podobné" odmietnuté, vnorené dvojča nezmenené, žiadny
krok Späť; a **výber presunutý na skrinku** → hrana ani materiál neprejdú (v0.7.25).

**UI-D3** k tomu pridalo preklik zo „Smeru dekoru" na materiálový combobox tej istej karty (`nxRevealTarget` + `NXCombo.open` — vzor kliku na hranu v náhľade).

**Od K1 (D-108) je z neho len záchranná cesta zamknutého stavu:** smer je vstup, takže preklik už nie je hlavná akcia — spustí sa výhradne pri materiáli **bez** smeru, keď sa
segment nedá použiť a kresba sa naozaj mení inde (klik vtedy nič nezapisuje).

**„Hrúbka" klikateľná NIE JE** — určuje ju materiál KORPUSU a ten sa v režime dielca z panela otvoriť nedá (sektor Materiály patrí kontextu Korpus), takže by preklik nemal kam
viesť.

### Vkladacia karta — šablóny, typ a doska (UI-C1a dáta + UI-C1b UI; ui/panel/payloads.rb + ui/panel/actions_templates.rb + ui/js/insert_state.js · form.js · board_card.js)

payload `Panel.template_list` posiela panelu **celú knižnicu** — každý záznam nesie `kind` (`cabinet` | `board`) a `used_seq` (poradové číslo posledného použitia, `nil` = nikdy;
číslo dopĺňa `TemplateUsage.map`, do súboru šablón sa nikdy nezapisuje). Filter podľa druhu robí **klient aj server**: dlaždice panela (`NXInsert.templatesForType` /
`templateGroups` nad čistou `templateKind`) aj správa šablón; **sekcia `tpl` Štúdia si od ŠT-3c-1 pýta OBA druhy** (`template_list(kind: 'cabinet')` + `kind: 'board'`, aby sa
doskové dali aspoň zmazať) a druh vetví akcie: apply/odfotiť len `cabinet`, mazanie oba — serverové guardy nad `KINDS` ostávajú. **`usage:` (1b-4)** rozhoduje, či sa k záznamom
dopočíta `used_seq`: default `true` (panel z neho skladá „Naposledy použité"), sekcia Štúdia si pýta `usage: false` — poradie nekreslí a `TemplateUsage.map` je ďalšie čítanie
súboru v každom pushi okna.

**Insert payload nesie identitu použitej šablóny** (`template_kind` + `template_name` — korpus aj doska): `Panel.take_template_ref!` ich z payloadu **odstráni ešte pred builderom**
(do configu skrinky ani dosky nepatria) a `stamp_template_used` po úspešnom vložení záznam **znovu nájde**, overí druh a opečiatkuje — medzitým zmazaná alebo prepísaná šablóna =
vloženie prebehlo, pečiatka sa ticho vynechá. Pečiatka je **samostatná operácia mimo `start_operation`** a jej zlyhanie nikdy nemení výsledok vkladania (len log); po nej ide
`push_templates`, takže sa poradie „Naposledy použité“ prekreslí bez reštartu.

#### UI-C1b (vzhľad a správanie karty)

typ vkladania je **jedna voľba z troch** (`Dolná · Horná · Doska`) v segmentových tlačidlách — dvojica rádií `ikind`+`ctype` zanikla a **autorita je čistý stav**
`NXInsert.insertType()/setInsertType` (DOM je len zrkadlo; `getType()` v `core.js` už rádiá nečíta). Zmena **typu korpusu** zahodí korpusovú šablónu (ponuka je typovo filtrovaná —
D-32), prepnutie Korpus↔Doska výbery **nezahadzuje** (každý druh má vlastný sklad `template`/`boardTemplate`).

Šablóny sú **dlaždicová mriežka** v zrolovateľnej sekcii (`<details data-key="itpl">`) s dvomi skupinami — „Naposledy použité“ (max 3 podľa `used_seq` desc, stabilný tie-break
poradím knižnice) a „Všetky šablóny“; **mriežka sa prestavuje LEN pri zmene typu alebo novej knižnici** (`renderTemplateTiles(force)`, stráži to `dataset.forType`) — výber prepína
iba triedu `.on` (Codex FIX 14 a pasca CEF: klik, ktorý zahodí uzol, by druhému kliku dvojkliku nenechal cieľ). Klik a **dvojklik (N17)** chytá **jedna delegácia** na `#tplTiles` a
dvojklik volá **tú istú validovanú** `insertCabinet()`/`insertBoard()` ako zelené tlačidlo (žiadny `sketchup.*` z handlera dlaždice); klik na už vybranú dlaždicu je no-op, nie
odznačenie.

Kresba dlaždice je **schéma z configu** (`nxTplGlyph` — riadky čiel / krídla / police) a **nenesie ani jednu farbu** — obrys aj výplň dávajú tokeny v `panel.css`; dosková dlaždica
má badge hrúbky.

**UI-D2 — PNG náhľad a schéma zdieľajú TEN ISTÝ box** (`.tplpic`, výška 38 px, `object-fit: cover` = orez, nie deformácia), takže **výška dlaždice sa nikdy nemení** (pravidlo
„vertikálny priestor panela je vzácny“). `<img>` je v dlaždici **od začiatku bez `src`** a len sa odkrýva (`.tplpic.has`) — obrázok sa nikdy nevkladá ani neodstraňuje dodatočne,
lebo výmena uzla by uprostred dvojkliku odpojila cieľ udalosti (tá istá pasca CEF ako FIX 14); `onerror` triedu odoberie, takže **zlyhané načítanie končí pri schéme, nikdy pri
prázdnom boxe**. Pull rieši čisté jadro `nxTplPreviewPlan`/`nxTplPreviewStore` (Node testy): dlaždica bez `preview_rev` sa nepýta vôbec, cache je **per revízia** (prepis šablóny =
nová `rev` = nový pull, starý obrázok sa už nikdy nenasadí) a **záporná odpoveď servera sa cachuje tiež**, inak by sa panel pýtal donekonečna.

**Zámky D-39 dostali rozsah**: korpusové kľúče sú nezmenené, doska má **vlastné** `length`/`width` vo **vlastnom úložisku** (Codex FIX 12) a do Ruby **nikdy neidú** — serverový
whitelist `Panel::INSERT_LOCK_FIELDS` je korpusový a zostáva ním, takže doskový zámok drží hodnotu len v UI pri prepnutí šablóny.

**Kontrakt hrúbky doskovej šablóny** (zapísaný v `core/templates.rb board_tpl`) plní `applyBoardTemplate`: šablóna s `material_id: nil` predvyplní **UNI materiál roly „Doska“**
(`uniBoardSheetId` nad novým poľom payloadu `uni_role`) a **až potom** dosadí hrúbku šablóny — poradie je kontrakt, lebo `onInsertBoardMaterial` by draft prepísal katalógovým
defaultom.

**Žiadna nová autorita hrúbky nevznikla**: rozhoduje ďalej `BoardBuilder.insert_thickness_for` (pri reálnom materiáli hrúbku určuje katalóg — karta to povie nahlas namiesto tichého
ignorovania). Smer dekoru zo šablóny sa značí ako **vedomá voľba** (D-86 príznak), takže ho živý refresh katalógu neprepíše. Informačný stĺpec Základných nesie pri vkladaní
**odhad** (`nxDraftStats` — veľké plošné dielce z configu a stromu zón, značka ≈), lebo serverový dopočet `Panel.cabinet_stats` číta snapshoty už vloženej skrinky a builder sa
kvôli informačnému riadku nespúšťa; pri doske sú v ňom hrúbka (zrkadlo poľa v Materiáloch) a plocha. Zelené **Vložiť** je posledné v karte (za rozmermi aj materiálom).

Čisté jadro testuje `tests/js/test_insert_state.js` + `tests/js/test_uic1b_vkladanie.js` + `tests/js/test_uid2_nahlady.js`, zdrojové invarianty `tests/pure/test_uic1a_sablony.rb` +
`tests/pure/test_uic1b_vkladanie.rb` + `tests/pure/test_uid2_nahlady.rb`; kameru, `write_image` a „žiadny undo krok“ overuje **iba** in-SketchUp sekcia `run_uid2`
(`tests/sketchup/su_runner.rb`).

#### UI-C1c (orientácia dosky v paneli)

trojica segmentových tlačidiel (`Naležato · Nastojato · Na stenu`) stojí **dvakrát** — v karte vkladania (`#insBoardOriRow`, `data-ins-ori`) aj na karte označenej dosky
(`#boardOriRow`, `data-bc-ori`); kostra je statická, JS len prepína triedu `.on` a `aria-pressed` (`syncOrientationSegments`), popisy nesú `aria-label` + `title` z HTML.

**Vo vkladaní je autoritou čistý stav** `NXInsert.boardOrientation()/setBoardOrientation` (žiadne DOM pole) a **orientácia sa nastavuje EXPLICITNE pri KAŽDEJ materializácii karty**
— `materializeInsertBoardCard` volá `setBoardOrientation(orientationOf(tp ? tp.config : null))` **pred** `applyBoardTemplate`, takže „Bez šablóny“ ani šablóna bez poľa nezdedia
orientáciu predošlého draftu (Codex FIX 8); insert payload nesie `orientation` **vždy** a serverový whitelist `handle_insert_board` ju prepustí do `BoardBuilder.norm_orientation`
(jediná autorita slovníka).

**Na karte označenej dosky** ide klik vlastným callbackom `set_board_orientation` → `Panel.handle_set_board_orientation`: guard echo `board_id` ako ostatné doskové akcie,
odmietnutie neznámej **požadovanej aj uloženej** hodnoty, no-op pri rovnakej hodnote (žiadny prázdny undo krok), inak **jedna prestavba s deltou transformácie = jeden krok Späť** +
`ScaleWatch.remember_transform`. Pred odoslaním sa flushne čakajúci debounce ostatných polí (`flushBoardEditsNow` — callbacky sa vykonávajú v poradí odoslania). Payload karty
(`Panel.board_payload`) nesie `orientation` + `orientation_label`; **neznámu hodnotu payload nepreklasifikuje** a karta vtedy nerozsvieti žiadny segment. Dosková **dlaždica
šablóny** hovorí o umiestnení v **tooltipe** (`nxTplOrientationNote`/`nxTplTitle`) — badge ostáva hrúbka, aby dlaždica nenarástla o riadok.

Testy: `tests/js/test_uic1c_orientacia.js`, `tests/pure/test_uic1c_orientacia.rb` a **in-SketchUp sekcia `run_uic1c`** (matice, svetové osi, normála dekoru, kotviace roviny, delta,
scale/dedup, nedotknutý kusovník).

### Klikateľnosť a deep-linky (UI-D3, ui/js/bridge.js + shell.js + boot.js + ui/studio_dialog.rb)

dotiahnutie zásady kontraktu „všetko informačné je klikateľné a vedie tam, kam ukazuje".

**(1) Warnpanel (N5):** ⚠ chip v hlavičke otvára **OVERLAY** `#warnList.warnpanel` — `position: absolute` **vnútri `<header class="nxhdr">`** (sticky predok = kotva). Predtým to
bol blokový `.warnlist` pod hlavičkou, ktorý otvorením posunul celý obsah nadol (vertikálny priestor je vzácny) a musel si pomáhať `scrollTo(0,0)`; to zaniklo. Výška je
**ohraničená viewportom** a scrolluje sa **len zoznam riadkov** (`.wrows`) — panel je mimo dokumentového toku, takže pri mnohých nálezoch by spodné riadky aj cesta von skončili pod
okrajom okna a scroll dokumentu by ich nedotiahol (Codex #182 P2).

Riadky skladá **čistá funkcia `NXShell.warnRows`** z už prijatých upozornení stavby (BuildPlan kontrakt `code/severity/message/part_key/data` v `cabinet_payload['warnings']`) —
**žiadne nové serverové dáta**; upozornenie bez textu sa zahodí (oko by sľúbilo skok a nepovedalo prečo) a `part_key` sa **nikdy neupravuje** (nesie `:` aj `/`).

**Nález o dielci, ktorý sa nikdy nepostavil, spadne na korpusovú úroveň** (`WARN_PART_NOT_BUILT` — `part_skipped_degenerate` z `construction.rb` **a `shelf_skipped_shallow_zone` zo
`zone_tree.rb`**): plán taký dielec vyradí, ale kľúč si v upozornení ponechá — poslať ho na výber by bola akcia, ktorá **nemôže uspieť**, tak sa označí skrinka (Codex #182 P2).
Zoznam je úzky a explicitný, nie heuristika; **druhý kód doplnil sweep review** — plytká zóna police nepostaví a panel na tom riadku končil hláškou „Dielec sa v modeli nenašiel",
hoci serverová strana (`ui/production_core.rb`) obe kódy držala spolu už predtým. Nový kód nepostaveného dielca patrí **sem a do testu**.

**Oko v riadku ide EXISTUJÚCOU serverovou cestou `nx_select_hw_owner`** (prázdne kľúče = celá skrinka, inak `parts_by_keys`) — druhý handler s vlastnými guardmi by sa časom
rozišiel; líšia sa len **podstatné mená v statusoch** (`SELECT_OWNER_NOUNS`, pole `origin` v payloade: `warn` → „Nález … panel ostáva pri skrinke", `hardware` → pôvodné znenie;
neznámy/chýbajúci pôvod padá na `hardware`). Klik má **rovnaký flush handshake** ako „Dielcov" a box vlastníka (červené pole akciu zastaví). Zatváranie je **jedna delegácia**
(`bindWarnPanel` v `boot.js`): klik mimo + Escape (fokus späť na chip), klik vnútri panela aj na samotný chip **zastavuje bublanie** — inak by sa panel v tom istom kliku otvoril a
hneď zavrel.

Kvôli tomu **merač D-25 počíta klik v CAPTURE fáze** (`usage.js`) — v bubble fáze by mu celý warnpanel (a každý budúci overlay so zatváraním klikom mimo) ticho vypadol z odpočtu,
podľa ktorého sa rozhoduje o režimoch panela (Codex #182 P2). Viditeľnosť mení **jedna funkcia** `setWarnPanel`, takže `aria-expanded` na chipe hovorí pravdu bez ohľadu na to,
ktorá cesta panel zavrela — a od sweep review prepína **triedu `.open`, nie inline `display`**: inline `display: block` prebíjalo `display: flex` z CSS, panel prestal byť stĺpcovým
flexom, `.wrows` už nebola flex položka a `min-height: 0` nemalo čo obmedziť, takže **scroller vyššie bol mŕtvy** a dlhý zoznam sa aj tak neposúval.

Zavretý stav je default v CSS (`display: none`), kostra v `panel.html` inline štýl **nenesie** a `setWarnPanel` prípadnú starú inline hodnotu (CEF cache) vyčistí; `warnPanelOpen`
číta tú istú triedu, akou sa stav nastavuje.

**(2) Deep-linky do okien (od ŠT-1a DVA ciele):** vzor je v oboch prípadoch rovnaký — panel posiela **iba meno**, autoritou whitelistu je **Ruby**, JS zoznam je jeho **zrkadlo**
(zhodu stráži guard test), a cieľ sa **neposiela hneď**: okno po `show` ešte nemusí mať načítané HTML, takže `execute_script` by prišiel do prázdna. Odkladá sa a **spotrebuje ho
najbližší `push_state`**, jednorazovo — bez vynulovania by každý ďalší refresh vrátil používateľa tam, odkiaľ medzitým odišiel.

**(a) Okno ŠTÚDIO:** `openStudio(section, anchor)` posiela `NXShell.studioOpenLink(...)` → `open_studio` → `Panel.studio_link_of` → `StudioDialog.show(open_section:, anchor:)`;
whitelist `StudioDialog::SECTIONS` ↔ `NXShell.STUDIO_SECTIONS`, odklad `@pending_section`/`@pending_anchor` → polia `open_section`/`anchor` v payloade `NX.setStudio`.

**Kotva cestuje LEN so sekciou** (bez nej nemá kam sadnúť).

**(b) Deep-link na TAB okna Výroba ZANIKOL (ŠT-1c PR B3):** `openProductionDialog` · `NXShell.studioLink`/`STUDIO_TABS` · `Panel.studio_tab_of` · `ProductionDialog::TABS` — všetko
odišlo spolu s oknom (taby sa vysťahovali postupne: `rows`/`sheets`/`edging` v ŠT-1a, `control` v ŠT-1b, `hardware` v ŠT-1c PR A, `budget` v PR B1).

**Deep-link zostal jeden — na SEKCIU Štúdia.** Bez neho (rail Štúdio, toolbar) je hodnota `nil` a sekcia sa **nemení**. Cesty: ⚠ warnpanel → „Otvoriť v Štúdiu → Kontrola" →
**ŠTÚDIO, sekcia `ctrl`** (`openStudio('ctrl')`; do ŠT-1b viedol do okna Výroba na tab `control`) · **„Materiál" v info stĺpci → Štúdio, sekcia `bom`, kotva = ID skrinky** — tým sa
**splnil sľub UI-D3**, že filter kusovníka na jednu skrinku príde so Štúdiom (status to povie nahlas aj s tým, ako sa zúženie zruší).

**(3) Názov projektu (ŠT-1a):** klikateľný vstup existuje **na jedinom mieste** — v lište Kusovníka v Štúdiu; JS ho **neposiela do žiadneho exportu** (autoritou je
`ProductionCore.project_name`). Kontrakt a zrkadlá testuje `tests/pure/test_uid3_klikatelnost.rb` + `tests/pure/test_st1a_studio.rb`, čisté funkcie
`tests/js/test_uid3_klikatelnost.js` + `tests/js/test_st1a_studio.js`; **ŠT-1a in-SketchUp beh POTREBOVALA** (nová serverová cesta na zmenu výberu z nového okna — sekcia
`run_st1a`).

### Výrazy v rozmerových poliach

`expr.js` parser bez eval (`650-36` + Enter, živý náhľad `= 614`, šípky ±1/±10); surový výraz neopúšťa JS; auto-apply s identity guardom (snapshot cabinet/board id).

### D-41 modal chýbajúcej ABS

(`absModal` v paneli): zmena materiálu/bulk olep na dekor bez použiteľnej 1,0 pásky → „Vytvoriť a pokračovať / Bez ABS / Zrušiť". JS `absUsableExists` je len UX zrkadlo —
**autorita je server** (flag `create_missing_abs`, kontroly PRED katalógovým zápisom); part callbacky nesú `cabinet_id` identity guard.

## Súbory Inspectora — panel.rb + ui/panel/*.rb

Register serverovej strany Inspectora. Kontrakty a pasce žijú v tematických odsekoch vyššie — tieto nadpisy sú rozcestník „ktorý súbor patrí ku ktorému odseku" a zároveň poistka,
aby žiadny nový súbor nezostal mimo mapy (stráži guard test). `actions_zones.rb` má vlastný odsek vyššie („zónové akcie servera").

### panel.rb

Centrálne callbacky Inspectora (`Panel.*`) — vstupný bod všetkých volaní `sketchup.*` z panela. Jednotlivé kontrakty sú v odsekoch kontextov a kariet vyššie.

### payloads.rb

Doména panela: skladanie payloadov pre klienta. Kontrakt vkladacej karty a knižnice šablón je v odseku „Vkladacia karta — šablóny, typ a doska".

### resolvers.rb

Doména panela: rozlíšenie virtuálnych materiálov (`resolve_virtual_material`). Fan-out cesta po zápise do katalógu je v [materials.md](materials.md), odsek
„materials_* — spoločný kontrakt".

### selection.rb

Doména panela: observery výberu a transakcií, kamera a serverové cesty zmeny výberu. Kontrakty sú v odsekoch „Observery panela", „Kontext Kovanie (UI-C4…)" a „Náhľad = kontextová
projekcia + spodný pás (UI-B2…)".

### sync.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### actions_board.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### actions_cabinet.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### actions_hardware.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### actions_materials.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### actions_parts.rb

Doména panela: zápisové cesty karty dielca. Kontrakt a všetky guardy (dokument · cieľ zmeny · odpojenosť) sú v odseku „Karta dielca (UI-D1…)".

### actions_settings.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

### actions_templates.rb

Doména panela: šablóny a ručné odfotenie náhľadu (`Panel.capture_preview_for`). Kontrakt je v odseku „Vkladacia karta — šablóny, typ a doska" a v
[model-a-identita.md](model-a-identita.md), odsek `template_previews.rb`.

### actions_usage.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

## Štúdio — okno a sekcie

### studio_dialog.rb + ui/studio.html + ui/js/studio.js — okno ŠTÚDIO (ŠT-1a)

cieľové JEDNO okno zákazky (kontrakt `SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`, sekcia ŠTÚDIO KONCEPT) — ľavá navigácia, obsah sekcie vpravo.

**Živých je DVANÁSŤ sekcií** (`SECTIONS` = `bom ctrl buy budget offer mat hw rules tpl sup bset about`) — od ŠT-4a je sekciou KAŽDÁ položka navigácie okrem Nárezového plánu (fáza
2): **KUSOVNÍK** (Š1–Š6, pohľady **Dielce · Platne · ABS**), od ŠT-1b **KONTROLA** (Š8–Š11), od ŠT-1c PR A **NÁKUP KOVANIA** (Š7 — presun tabu Kovanie 1:1), od ŠT-1c PR B1
**ROZPOČET** (Š12–Š13) a od ŠT-1c PR B2 **CENOVÁ PONUKA** (Š14–Š15; každá má vlastný odsek nižšie); od ŠT-3c-1 **ŠABLÓNY** (`tpl`) a od **ŠT-4a NASTAVENIA** (`sup` · `bset` ·
`about`, Š19 — posledná skupina navigácie).

**PREMOSTENIA ZANIKLI CELE** (`WINDOW_BRIDGES`, `BRIDGE_STATUS`, `do_bridge`, `bridge_window`, klientske `bridge:`/`bridgeTo`/`.nbridge` aj callback `studio_bridge`): premostenie
bol dočasný most do satelitu, ktorý ešte žil — ŠT-4a odstránila **posledný satelit**, takže niet kam premosťovať a most bez oboch koncov by bol mŕtvy kód, ktorý prežije prvé „to sa
ešte zíde".

**`PRODUCTION_BRIDGES` (premostenia do TABOV okna Výroba) v ŠT-1c PR B3 ZANIKLI úplne** — konštanta aj vetva `do_bridge`; všetkých päť obsahov je sekciami tohto okna, takže nie je
kam premosťovať.

**REFRESH INVARIANT — čo ide echom a čo plným pushom** (spresnené review #228; toto je záväzné miesto, nie kronika): rozhoduje **ČI SA MENIA ČÍSLA ZÁKAZKY**, nie to, či zápis
smeruje do modelu.

**Plný push so zdvihom generácie** ide vždy, keď zápis zmení kusovník, rozpočet alebo ponuku.

**Uloženie pravidiel kovania je MODELOVÝ zápis:** `HardwareRules.set_project_rules(model, rules)` beží **vnútri** `CabinetBuilder.rebuild_many(op_name: 'NOXUN: pravidla kovania')`,
takže pravidlá **aj prestavaná geometria sú JEDNA undo operácia** a rebuild potom číta **výhradne projektový snapshot** (`NOXUN` dict na modeli, kľúč `hardware_rules` — STANDARD
§V0.4 „Zdroje pravidiel a reprodukovateľnosť"); `HardwareRules.write(rules)` do `%APPDATA%` je len **dodatočná globálna predvoľba pre ďalšie projekty** a jej zlyhanie mení iba
hlášku. Klasifikovať pravidlá ako „externý zápis" by zviedlo budúcu prácu obísť reprodukovateľnosť alebo undo.

**Uloženie sadzieb dodávateľa** je naopak naozaj zápis MIMO modelu (`%APPDATA%\NOXUN\Engine\supplier_settings.json`), a aj tak ide plným pushom s bumpom
(`SupplierSettingsDialog#refresh_studio(bump: true)`) — mení sumy rozpočtu aj ponuky.

**PLNÝ REFRESH BEZ ZDVIHU generácie (`bump: false`) + echo** patrí zápisu, ktorý čísla meniť MÔŽE, ale **nemení IDENTITU riadkov**: typicky **katalóg materiálov** —
`MaterialsDialog.after_catalog_change` posiela `push_mat_catalog` (echo) **a k tomu** `StudioDialog.refresh_if_open(bump: false)`, lebo oprava ceny či formátu platne zmení sumy
Rozpočtu/Ponuky aj odhad platní. Generácia sa nedvíha **nie preto, že sa čísla nemenia**, ale preto, že sa nemenia `rows`/`refs` (dielec drží svoje `material_id`) — rozkliknutý
riadok Kusovníka ani rozrobený export inej sekcie preto nesmie zastarať len preto, že niekto opravil cenu.

**Samotné echo sekcie BEZ plného pushu** patrí zápisu, ktorý čísla zákazky naozaj nemení (knižnica šablón `TPL.init`), a **odmietnutému zápisu** (nič sa nezmenilo —
`push_section_echo`). Klasifikovať katalóg, pravidlá či nastavenia ako „lacné echo" by nechalo súčty projektu stáť na starých číslach.

**VÝNIMKA v odmietacích vetvách:** keď dôvodom odmietnutia je **prepnutý dokument** (`model_guid` mismatch), ide **plný push** `refresh_studio(bump: false)` — cudzí dokument je
cudzí pre VŠETKY sekcie okna, takže echo jednej by nechalo Kusovník, Kontrolu aj Rozpočet na dátach iného projektu.

**ŽIVOTNOSŤ DLHÝCH BEHOV nie je jednotná** (spresnené review #228): Demos fetch katalógu (`HardwareCatalogDialog`, `MaterialsDialog`) zhasína zatvorenie okna, **prepnutie
dokumentu** aj **odchod zo sekcie** (`hw_leave`/`mat_leave`), lebo výsledok patrí sekcii a dokumentu.

**Prepočet cien (`price_refresh_alive_proc`) je ZÁMERNE iný**: prežíva prepnutie modelu (ceny idú do GLOBÁLNEHO katalógu, nie do zákazky) a kontroluje jedine to, že žije **tá istá
inštancia okna Štúdio**; odchod zo sekcie Rozpočet ho **neruší** — taký leave hook neexistuje. Predpokladať pri ňom rovnakú hranicu ako pri Demose by znamenalo spoliehať sa na
ochranu, ktorá tam nie je.

**Klientske `goto`** (položka, ktorej obsah bol ČASŤOU inej sekcie) zaniklo v PR B2 spolu s náhľadom ponuky vnútri Rozpočtu — každá položka navigácie je odvtedy buď sekcia, alebo
premostenie, alebo má dôvod. Prepnutie sekcie z kódu má **jedno miesto** `studioGoSection(id)` (globálne na `window`, lebo ho volá aj `budget.js`, ktorý sa načítava až za
`studio.js`).

**Jediná `aria-disabled` položka je (a od ŠT-4a jediná neživá vôbec) Nárezový plán** („fáza 2", vzor D-78 — žiadne mŕtve tlačidlo bez dôvodu). O cieli premostenia rozhoduje
**uzavretý whitelist v Ruby**, klient posiela iba kľúč.

**Čísla nesie zdieľané jadro `ProductionCore`** (do ŠT-1c PR B3 z neho čítalo aj okno Výroba); **kanál okna je vlastný** (audit #3): vlastný `@generation`, vlastný relay
`NX.studioRelay`/`studioRelayExport` → `studio_do_select`/`studio_do_export` v `panel.rb`, s **identickým flush handshakom** (červené pole panela export zastaví). Cudzí push tak
nemôže zhodiť guard druhého okna; nesúlad generácie končí **re-pushom a statusom**, nikdy ticho.

**„Obnoviť" (`refresh_bom` → `do_refresh_bom`) hlášku VŽDY zhodí** — klient si pred volaním nastaví per-sekčné „Prepočítavam…" a o výsledku sa sám nemá ako dozvedieť (prepočet beží
na serveri), takže po úspešnom `push_state` prichádza echo `„Prepočítané."` a pri výnimke chybová hláška + `log_error`. Kým to callback nerobil (holý `push_state`), „Prepočítavam…"
v okne viselo aj po dobehnutom prepočte a vyzeralo to ako zamrznuté okno (SMOKE 22.8.). `rescue` je vedome aj napriek spoločnému `rescue` v `cb` — hláška nesmie ostať visieť ANI
pri výnimke a chyba patrí do logu s menom tejto cesty.

**Deep-link** — kontraktové meno je `NX.studioOpen(section, anchor)` (UI20_KONTRAKT §3), **reálna funkcia panela sa volá `openStudio(section, anchor)`** (`ui/js/actions.js`; skladá
payload cez `NXShell.studioOpenLink`) → `open_studio` → `StudioDialog::SECTIONS` (JS zrkadlo `NXShell.STUDIO_SECTIONS`, zhodu stráži guard test): sekcia sa odkladá do
`@pending_section` a **spotrebuje ju najbližší `push_state`** (jednorazovo — inak by každý refresh vrátil používateľa tam, odkiaľ medzitým odišiel); `anchor` (ID skrinky z N13
„Materiál") **predvyplní hľadanie Š6** a spotrebuje sa spolu so sekciou, takže používateľovo vymazanie filtra prežije refresh.

**Server je autorita čísel aj textov:** medzisúčty skupín idú z `sheets`, súčtový riadok z `totals` (vrátane rozsahu odhadu platní), popisky z `materials_meta` — **JS neprepočítava
žiadnu sumu**. Klient si pamätá výhradne zobrazovacie veci TOHTO počítača (`localStorage`: voliteľné stĺpce `nx_bom_cols`, zbalené skupiny `nx_bom_groups`, zbalená navigácia
`nx_studio_nav`) — nikdy model.

**Editovateľný názov projektu a checkbox „18+36 spolu" žijú v lište Kusovníka** (`studio_set_vepo_opts` → zápis do `%APPDATA%`).

**Lišta Kusovníka je od SMOKE dávky (22.8.) čistá funkcia `bomToolsHtml(vepo, st)`** — stav (pohľad · hľadanie · otvorené menu) chodí ARGUMENTOM, rovnaký vzor ako zdieľaný
`edge_menu.js`, takže sa dá testovať bez DOM.

**Poradie:** `[Dielce · Platne · ABS] · [Projekt] · [hľadanie] · ⟶ · [VEPO export ▸roh] · [Stĺpce] · [Obnoviť]` — vľavo „čo pozerám", vpravo „čo s tým robím".

**Checkbox „18+36 spolu" sa presťahoval z lišty do ROHOVÉHO NASTAVENIA tlačidla VEPO** (`vepoBtnHtml`/`vepoMenuHtml`, vzor „flyout roh" UI_DIZAJN §5.11): klik na telo exportuje,
klik na `.cornerzone` v pravom dolnom rohu otvorí malé okno s jediným prepínačom.

**Klikacia zóna je ZDIEĽANÁ** s railom Inspectora aj lištou Kontroly (`panel.css .cornerzone`), **obsah okna vlastný** — `edge_menu.js` kreslí 3-stavovú kontrolu hrán, tu je jeden
checkbox, takže spoločný komponent by bol natiahnutý. Otvorenosť je čisto klientska (`vepoMenuOpen`, nikam sa neukladá), zatvára ju klik mimo `.vepofly` a Escape — obe v **JEDNOM**
listeneri s `ecMenu` (dva listenery na `document` si `stopPropagation` neodovzdajú) a **až za** modalovou brankou (`nxModalOpen`). Hodnotu checkboxu nasadzuje echo `NX.setVepoBar`
aj do OTVORENÉHO okna (uzol je v DOM vždy, skrýva ho trieda).

**Pole „Projekt" má viditeľný štítok a vlastný rám** (`.prjbox .prjlbl`) — je to jediný vstup v lište plnej tlačidiel a pomenúva zákazku pre všetky exporty. Zápis **nerobí plný
`push_state`**: ten zdvíha `@generation`, takže prvý klik alebo export hneď po editácii názvu (`change` tesne pred `click`) by zaručene spadol na „Dáta okna sa medzitým zmenili" —
hoci kusovník sa nezmenil, zmenila sa **lišta**. Ide preto **cielené echo `push_vepo_bar` → `NX.setVepoBar`** (vzor `push_edge_check`), ktoré prepíše len obsah lišty a generáciu
nechá tak; hodnotu inputu pritom nasadí **len keď v ňom používateľ práve nepíše**. Stav checkboxu sa nasadzuje z payloadu pri **KAŽDOM** pushi (audit #16), takže sa lišta nemôže
rozísť s tým, čo platí pre exporty.

Pohľad **Platne** skladá riadky z **oboch** zdrojov — `sheets` (materiály s vlastnými výrobnými dielcami) **aj** `sheet_estimate` (2B-1/D-43: duplák, ktorého plocha vznikla len z
lepených dielcov, vlastné dielce nemá, ale **reálne sa nakupuje**) — inak by ten nákup z tabuľky zmizol a súčtový riadok, ktorý ráta cez všetky položky odhadu, by s ňou nesedel.

**Vedomé odchýlky ŠT-1a:** stĺpec „Poznámka" **neexistuje** (v Ruby preň nie je zdroj) · exporty **XLSX/CSV kusovníka boli viditeľné `aria-disabled`** s dôvodom — **SMOKE 22.8. ich
z lišty ODSTRÁNILA** (verdikt Michal): D-78 platí na sľub, ktorý príde hneď, tieto dva viseli neaktívne celý blok ŠT-1 a v okne pôsobili ako rozbité tlačidlá; vrátia sa **s reálnym
exportom** (vlastná dávka, kontrakt Š5 revízia 22.8.) · pohľad **ABS nemá stĺpce „bm s rezervou" a „€/bm"** — obe čísla patria do payloadu **rozpočtu** a teda do JEHO sekcie ABS
(od ŠT-1c PR B1 je Rozpočet o jeden klik vedľa); dopočítať rezervu v klientovi je zakázané, takže sa to povie hintom pod tabuľkou.

Kódy hrán `L1/L2/W1/W2` sa v stĺpci ABS **zámerne neprekladajú** na „predná/zadná" — ten istý kód znamená pri každej role inú fyzickú hranu (`part_faces`), takže pevný preklad by
pri policiach a dnách klamal; fyzickú stranu kreslí karta dielca v Inspectore.

**D-51:** obsah `1060 × 640` ⇒ `width/height 1076 × 680`, `min_width 1076`.

**Tlačidlo „Obnoviť" má od 22.8. JEDEN markup pre všetkých päť miest** — zdieľaný helper `refreshBtnHtml(stale, tip, attrs)` v `studio.js` (Kusovník · Kontrola · Nákup ho volajú
priamo, Rozpočet a Ponuka cez most `budRefreshBtnHtml` v `budget.js`, ktorý si ho v Node testoch berie `require`-om); päť kópií toho istého tlačidla by znamenalo päť miest, kde sa
jantárový stav časom rozíde.

**ŠT-2a — šiesta živá sekcia: MATERIÁLY (`mat`, prvá zo skupiny KATALÓGY).** Obsah je **presun 1:1** z okna „Materiály projektu": dlaždice dekorov podľa výrobcu + pás „Použité v
projekte", detail dekoru s inline bunkami (patch protokol `row_rev` nezmenený), predvoľby projektu s `model_guid` guardom, batch „Nový dekor", duplák, universal toggle, delete
preflight aj rollback predmigračnej zálohy.

**ŠT-2c 2c-2b — batchové ZAKLADANIE dekoru z tejto sekcie ZANIKLO:** „Pridať ručne" otvára D-69 editor v režime `create` (`mdCreateOpen` → `mdCreateFields`/`mdCreatePayload`,
`memoryKey: 'mat:create'` = vlastný slot, takže rozpísaný nový dekor a rozpísaná úprava iného sa neprepisujú), formulár s preset čipmi ostal **výhradne ako „+ variant"** do
EXISTUJÚCEJ skupiny (`mdOpenDecorForm` bez kľúča už len povie, kde sa dekor zakladá) — je to cesta pre typy, ktorých identitu editor nepokrýva (zástena = rub, PD = hranová úprava)
a pre skupiny s viacerými štruktúrami. S create vetvou zanikli aj **pole farby** (skupina tam vždy existuje a server jej farbu vnucuje) a **localStorage pamäť „poslednej použitej
sady"** — dve pamäte rozpísaného dekoru (localStorage + `NXModal`) by znamenali dve verzie a žiadnu istotu, ktorá sa odošle.

**Stĺpce repeaterov sú JEDNA definícia** (`mdSheetCols`/`mdEdgeCols`) pre oba vstupy D-69; prázdny formulár má navyše skupinové polia **Štruktúra** (klient ju vlieva do zakladaných
riadkov — je to identita variantu a dopísať sa už nedá) a **Smer dekoru**. Úspešné založenie zatvorí modal, zahodí pamäť rozpisu a **otvorí detail nového dekoru** (ceny sa dopĺňajú
tam). Odmietnutie `:stale` má v create **vlastnú hlášku** („Katalóg sa medzitým zmenil — skús uložiť znova.") a `mdEditRefresh` len omladí baseline: dorovnávať niet čo, v katalógu
ešte žiadny náš riadok nie je — hláška editu by o tom klamala. Testy: `tests/js/test_st2c_create.js`.

**ŠT-2b — okno ZANIKLO a sekcia prevzala VŠETKO.** `proj_materials.html`, HtmlDialog, `DLG_KEY`, položka menu aj panelové tlačidlo sú preč (menu „Materiály projektu" a tlačidlo
panela vedú deep-linkom `openStudio('mat')`); `mat_open_window` aj `MAT_BRIDGE_STATUS` zanikli spolu s ním. Do sekcie sa presťahovali **Demos toky** (`demos_diff.js` =
„Aktualizovať z Demosu", `demos_add.js` = „Pridať z Demosu"; ich modály sú v `#matModalRoot`) a **„Nahradiť UNI…"**.

**Životnosť dlhého behu je viazaná na SEKCIU — vedomé rozhodnutie dávky (audit #5):** `demos_alive_proc(session)` sa pýta už len session tokenu a toho, či Štúdio žije; token
zhasína **zatvorenie okna** (`MaterialsDialog.on_ui_closed` z `set_on_closed` — ABA guard), **prepnutie dokumentu** a **odchod zo sekcie** (`studioGoSection` → `matOnLeaveSection`
→ `mat_leave` → `cancel_demos_on_leave`). Odchod počas sťahovania beh **zruší a povie to** („Sťahovanie z Demosu zrušené — opustil si sekciu Materiály."); alternatívy — nechať
bežať na pozadí alebo pýtať potvrdenie pri každom prepnutí — sú horšie: modál by sa vrátil nad cudziu sekciu, resp. by otravoval.

Poradie v `matOnLeaveSection` je záväzné: **najprv `mat_leave` na server, až potom lokálne zatvorenie modálov** — opačne by `nxdaClose` poslal `demos_family_cancel` skôr, server by
už nemal čo rušiť a používateľ by sa nedozvedel, že mu sťahovanie skončilo.

**„Nahradiť UNI…" beží v JEDNOM okne:** nález Kontroly → `ProductionCore.replace_uni` → `MaterialsDialog.request_replace_uni` → `StudioDialog.show(open_section: 'mat')`; požiadavka
sa **odkladá** (`@pending_replace_uni`) a spúšťa ju buď `show` (keď okno už bežalo a hlásilo `ready`), alebo `ready` callback **až za prvým `push_state`** — klient potrebuje celý
katalóg, aby k `uni_id` našiel dlaždicu. Je jednorazová a zomiera so zatvorením okna aj s prepnutím modelu.

**Sekcia si kreslí telo SAMA** (`matRenderBody` v `ui/js/proj_materials.js`, vzor `budRenderBody`): telo je **JEDEN uzol naklonovaný raz zo `<template id="matBodyTpl">`**, ktorý
pri prepnutí sekcie z `#secbody` len vypadne a pri návrate sa vráti — `NX.setStudio` ho **nikdy neprekresľuje**, takže rozpísaný formulár „+ variant" ani rozpísaná bunka ceny sa
nestratia (audit #2; fokus a dirty baseline obnovuje `mdRenderAll`).

**Modály sekcie žijú v kotve `#matModalRoot` MIMO `#secbody`** (vzor `#nxModalRoot`).

**Lišta je čistá funkcia `matToolsHtml(state)`** — `[Pridať z Demosu] · [Pridať ručne] · [hľadanie] · [zoskupenie] · ⟶ · [Obnoviť zálohu] · [Obnoviť]`; **primárnym tlačidlom je od
ŠT-2b zase „Pridať z Demosu"** (ŠT-2a mu rolu dočasne odobrala, lebo vtedy len premosťoval do okna — najvýraznejšie tlačidlo novej sekcie nesmie viesť preč); hľadanie a zoskupenie
si preto držia hodnotu **aj v premennej** (`MD_Q`/`MD_MODE`), lebo lištu prekresľuje každý push. Bannery (read-only katalóg · nepoužiteľné ABS · cutover) sú **prvé riadky obsahu**,
obsah podtitulu `#mdline` prevzal hint sekcie.

**KANÁL je zámerne delený:** katalógové echo `push_mat_catalog` → `NX.setMatCatalog` (vzor `push_vepo_bar`) prepíše **len katalóg**, negeneruje prepočet a **NEDVÍHA generáciu** —
oprava ceny nemení `rows`/`refs`, takže rozkliknutý riadok Kusovníka ani rozrobený export inej sekcie po nej nesmie zastarať (audit #4); plný `push_state` nesie **modelový kontext
sekcie** (`mat`: predvoľby, počet skriniek, `model_guid`, `used`) a **celý katalóg len pri prvom pushi okna a po prepnutí dokumentu** (`@mat_full_pending`) — inak by sa `row_rev`
každého záznamu počítal pri KAŽDOM prepočte kusovníka (audit #15).

**`used` vzniká z UŽ zozbieraného `collected`** (`mat_used` + `Materials.decor_key_by_material_id`), nie druhým `Ids` skenom modelu ako v okne; počíta teda to, čo je naozaj vo
výrobe — ten istý zdroj ako Kusovník.

**Telo akcií katalógu ostáva v `MaterialsDialog`** (audit #21 — modul sa NEPREMENÚVA): Štúdio registruje **tie isté mená callbackov** a volá `MaterialsDialog.dispatch(name,
payload, sink)`; whitelist je JEDINÝ (`MaterialsDialog::SECTION_ACTIONS`) a `sink` presmeruje odpoveď (`MD.*`) tomu, kto sa pýtal — okno má tie isté prijímače, lebo beží na tom
istom `proj_materials.js`. Okno dostalo **`@ready`** (vzor MaterialsDialog, audit #8): `false` pri vzniku aj zatvorení, `true` v `ready` callbacku **pred prvým pushom** — a **`js`
podľa neho reálne rozhoduje** (`return false unless @ready`): CEF `execute_script` poslaný pred načítaním HTML potichu zahodí, takže push pred `ready` sa priznane zahodí aj tu
(`false` = „klient to nedostal", `do_refresh_bom` sa podľa toho rozhoduje). Bez toho by to bola mŕtva premenná, na ktorej má ŠT-2b postaviť odloženú požiadavku „Nahradiť UNI…".

**Západka `@mat_full_pending` sa gasí len vtedy, keď katalóg v odoslanom payloade REÁLNE bol** — `mat_payload` má vlastný rescue (vracia `nil` + zápis do logu) a holé „odoslalo sa"
by pri jeho zlyhaní nechalo sekciu navždy prázdnu a bez hlášky.

**ŠT-2d — „KDE SA POUŽÍVA" (posledná dávka fázy ŠT-2):** detail dekoru dostal na koniec sekciu **„Kde sa používa"** (`mdWhereHtml`, schválený bod konceptu MATERIÁLY, mockup ju
kreslí rovnako) — riadok na každého vlastníka (`CAB-004 · Bok ľavý · Dno · Polica` + počet dielcov) a riadok na každú **použitú pásku** rodiny, oboje s **okom**. Dáta sú **rozpis
toho istého čísla, ktoré už nesie `used`**: `mat_used_where(collected)` beží v tom istom prechode zberom (žiadny druhý sken modelu, audit #15) a vracia `{ kľúč skupiny => { owners:
[{owner_id, parts, roles, material_ids}], edges: {abs_id => {parts, objects}} } }`; **roly skladá SERVER** (`ProductionCore.role_label` — klient preklad enumu rol nemá) a páska sa
ráta **za dielec, nie za hranu**.

**Dve čísla, dve otázky (review #6):** `parts` = kusy do výroby, `objects` = koľko entít sa v modeli naozaj označí — doska s `quantity: 3` je 3 kusy, ale jeden objekt. Riadok ukáže
jedno číslo, kým sa rovnajú, inak prizná obe (`3 ks · 1 objekt`) a tooltip oka hovorí **tým istým slovom ako stavový riadok** („označí 3 položky" ↔ „Vybraných N položiek v
modeli.").

**PICKER-2** k tomu pridalo tretí pohľad na ten istý zber — **`mat_used_ids(collected)`** (`mat.used_ids` = `{sheets, edges}`, holé ID bez počtov): to je otázka vyhľadávača
predvolieb („je tento materiál v zákazke?"), nie rozpis vlastníkov, preto sa tu dielec **bez `owner_id` nevyhadzuje**. Tvar je zhodný s panelovým `used_ids_payload`, takže skupina
„Použité v projekte" vyzerá v oboch oknách rovnako. Katalógový payload Štúdia (`MaterialsDialog.full_catalog_payload`) navyše nesie **`row_label` a `row_key` z TÝCH ISTÝCH dvoch
metód, aké volá panel** (`Panel.sheet_row_label`, `Materials.variant_family_key`) — keby si každé okno skladalo hranicu zlučovania samo, ponuka by sa v Inspectore a v Štúdiu
zlučovala inak a nikto by si toho nevšimol, kým by sa nevybral zlý materiál.

Mapy `decor_key_by_*` stavia **`mat_payload` raz** a podáva ich počtom aj rozpisu (review #5) — dva nezávislé prechody katalógom pri každom pushi by sa navyše mohli rozísť. Kľúč
skupiny pások dáva nová `Materials.decor_key_by_abs_id` (zrkadlo `decor_key_by_material_id` — vlastné odvodenie by mohlo ukázať na inú skupinu než pás „Použité v projekte").

**Oko ide TOU ISTOU cestou ako klik v Kusovníku** (`nx_select` cez relay panela, generácia okna, žiadne `pids` z DOM): `ProductionCore.refs_for` dostalo vetvy **`material_key`** a
**`abs_key`** (obe smú byť reťazec ALEBO pole — dekor mával viac hrúbkových variantov) s nepovinným zúžením `owner_id`.

**Pozor na rozdiel „kľúč CHÝBA" vs „kľúč je PRÁZDNY" (review #4):** chýbajúci `owner_id` = *bez zúženia*, prázdna hodnota = *zúženie na vlastníka bez identity* — keby sa oboje
bralo rovnako, riadok odpojeného dielca (bez `cabinet_id`) by ticho označil celý dekor. Taký riadok už zoznam ani nekreslí (`mat_used_where_owner` ho preskočí; v počtoch `used`
dielec ostáva), serverová vetva je druhá poistka.

**Adresa je `material_id`/`abs_id` a hľadá sa v BOM riadkoch, teda v EFEKTÍVNOM (snapshotovom) materiáli — nie v textových menovkách dekorov (`used_material_ids` a spol., audit
#14):** dielec, ktorý materiál iba **dedí po korpuse**, nemá v `part_overrides` nič, takže menovková cesta by ho nenašla a v modeli by sa označila polovica skrinky bez jediného
slova. Selekcia **nič nezapisuje** a nepridáva krok Späť (rovnaké pravidlo ako `parts_key`/`hw_key`).

**Deep-link z karty dielca (nová funkcia, audit #9):** materiál v karte dielca aj dosky má **ikonu prekliku** (`.matlink`, `nxDecorLinkState`/`nxDecorLinkGo` v `part_card.js` —
jedna funkcia, dva vstupné body) → `openStudio('mat', <material_id>)`.

**Kotva sekcie `mat` sa spotrebuje INAK než kotva Kusovníka** — nie ako text hľadania, ale ako **otvorenie detailu dekoru** (`matOpenAnchor` → `mdAnchorGroupKey` preloží
`material_id`/`abs_id`/kľúč skupiny na skupinu); jednorazovosť ostáva (server ju v ďalšom pushi neposiela, takže návrat do dlaždíc prežije refresh).

**Neúspešné otvorenie NIE JE tichý no-op (review #3):** dekor sa mohol medzitým zmazať alebo premenovať, takže `matOpenAnchor` vracia `false` a Štúdio to povie statusom („Tento
dekor už v katalógu nie je — otvorené v zozname materiálov.") — inak by preklik z Inspectora skončil v dlaždiciach bez slova a vyzeral by ako pokazené tlačidlo. Dielec **bez
rozhodnutého materiálu** má tlačidlo `aria-disabled` s dôvodom (D-78), **ABS pásky karty sa NEPRELINKÚVAJÚ** (hrana má vlastný tok — D-41 modal, picker).

Testy: `tests/pure/test_st1a_studio.rb`, `tests/pure/test_st2a_mat.rb`, `tests/pure/test_st2d_kde.rb`, `tests/js/test_st1a_studio.js`, `tests/js/test_st2a_mat.js`,
`tests/js/test_st2d_kde.js`, in-SketchUp sekcie `run_st1a`, `run_st2b` (kanál sink/Štúdio, životnosť Demos behu, tok „Nahradiť UNI…", predvoľba = 1 krok Späť) a `run_st2d` (výber
podľa materiálu vrátane **dedeného**, výber podľa ABS, zúženie na vlastníka, jednorazová kotva, ⋯ editor = 1 krok Späť).

**ŠT-3a-1 — siedma živá sekcia: KOVANIE (`hw`, druhá zo skupiny KATALÓGY; ikona `hammer` — tá istá ako rail Inspectora, kontrakt „Ikony navigácie").** *(Odsek popísuje PRVÚ
polovicu dávky — od ŠT-3a-2 už žiadne okno „Katalóg kovania" NEEXISTUJE; čo sa tým zmenilo, hovorí odsek nasledujúci za týmto.)* Obsah je **presun 1:1** z okna „Katalóg kovania"
(Š16): pohľady **Položky · Sety** ako segment v lište sekcie, hľadanie + filter kategórie + prepínač „neaktívne" v lište, „Nová položka" ako primárna akcia.

**Premostenie `hw` v navigácii ZANIKLO** (`WINDOW_BRIDGES` aj `BRIDGE_STATUS`); okno vtedy ešte žilo a otváralo ho premostenie Z VNÚTRA sekcie (`hw_open_window` +
`HW_BRIDGE_STATUS`), lebo tri MODELOVÉ zápisy predvolieb setov projektu sa presúvali až v ŠT-3a-2 — **oboje už neexistuje** a menu „Katalóg kovania" aj tlačidlo panela vedú do
sekcie.

**Sekcia si kreslí lištu aj telo SAMA** (`hwRenderTools`/`hwRenderBody` v `ui/js/hw_catalog.js`, vzor `matRenderBody`): telo je **JEDEN uzol naklonovaný raz zo `<template
id="hwBodyTpl">`**, ktorý `NX.setStudio` **nikdy neprekresľuje** — rozpísaný formulár novej položky ani rozpísaný editor setu tak push zo servera nezmaže; modál potvrdenia mazania
žije v kotve `#hwModalRoot` MIMO `#secbody`. Stav lišty (pohľad · hľadanie · kategória · neaktívne) žije aj v premenných (`HW_VIEW`/`HW_Q`/`HW_CAT`/`HW_INACTIVE`, vzor
`MD_Q`/`MD_MODE`), lebo lištu prekresľuje každý push; `hwToolsHtml(state)` je čistá funkcia a „Obnoviť" ide zdieľaným `refreshBtnHtml`.

**`sketchup.ready` na konci `hw_catalog.js` bolo v ŠT-3a-1 iba POTLAČENÉ** príznakom `window.NX_HW_SECTION` (žijúce okno bolo bez neho prázdne) — **v ŠT-3a-2 zaniklo CELÉ** (vzor
`proj_materials.js` po ŠT-2b); `ready` posiela `studio.js` z `window.onload` a príznak ostáva ako čítateľné prihlásenie sa do režimu sekcie. Priame väzby `addEventListener` na
`#hwSearch`/`#hwCategory`/`#hwInactive`/`#hn_demos` sa zmenili na **delegáciu na `document`** — v sekcii tie uzly pri načítaní ešte neexistujú (lišta) alebo zanikajú pri každom
prekreslení.

**Payload sekcie `hw_payload(model)`:** `sets` chodia v KAŽDOM pushi (riadia nákupný zoznam sekcie Nákup), **celý katalóg len pri prvom pushi okna, po prepnutí dokumentu a po
ručnom „Obnoviť"** (`@hw_full_pending` — inak by sa `row_rev` každej položky počítal pri každom prepočte kusovníka; západka padne LEN keď katalóg v odoslanom payloade REÁLNE bol).
Ručné „Obnoviť" západku zdvíha zámerne: sekcia `hw` nemá z modelu čo prepočítať a bez toho by jej tlačidlo klamalo.

**Kanál je delený rovnako ako pri Materiáloch:** katalógové echo `push_hw_catalog` → `NX.setHwCatalog` **negeneruje prepočet a NEDVÍHA generáciu**, plný `push_state` nesie modelový
kontext. Telo akcií zostáva v `HardwareCatalogDialog` (`SECTION_ACTIONS` je JEDINÝ whitelist, `hw_sink` presmeruje odpoveď, `hw_js` je verejný most pre asynchrónne emity — vzor
`mat_js`). Testy: `tests/pure/test_st3a_hw.rb`, `tests/js/test_st3a_hw.js` (in-SketchUp sekcia `run_st3a` pribudla až s ŠT-3a-2 — ŠT-3a-1 nemala ani jednu novú zapisovaciu cestu do
modelu).

**ŠT-3a-2 — sekcia `hw` je ÚPLNÁ a okno „Katalóg kovania" ZANIKLO.** Do sekcie pribudli tri **MODELOVÉ zápisy** (predvoľby setov projektu), takže blok „Predvoľby projektu" v
pohľade Sety už **nie je read-only** — `HWS_PROJ_RO` aj premostenie `hw_open_window`/`HW_BRIDGE_STATUS` **zanikli**.

**Po modelovom zápise ide `after_sets_change(model)` → `refresh_if_open(bump: true)` — a to STAČÍ:** predvoľba setu nemení GEOMETRIU, takže `Panel.push_selected` (dedup kópií) sa
vedome NEVOLÁ; jantár „Obnoviť" po vlastnom prepočte NEZOŽLTNE, lebo `push_state` si `@pushed_epoch` ukladá AŽ po zbere a vlastnú transakciu tak pohltí.

**`merge_seed` NO-OP nevolá `after_sets_change` VÔBEC** (ani `bump: false` push): nič sa nezmenilo, takže plný prepočet by bol zbytočný a zdvih generácie by zneplatnil rozkliknutý
riadok Kusovníka po akcii, ktorá NIč neurobila — status stačí.

**Po Ctrl+Z sekcia číslami zostarne a povie to jantárom** (`StudioModelWatch` → `markStale`); push-po-undo v Štúdiu neexistuje a nezavádza sa (precedens Rozpočtu) — pri zápise zo
zastaraného UI platí „posledný vyhráva“, lebo snapshot predvolieb `revision` guard nemá. Vstupné body okna presmerované: menu „Katalóg kovania" a tlačidlo panela vedú
`openStudio('hw')` / `StudioDialog.show(open_section: 'hw')`. Testy: `tests/pure/test_st3a_hw.rb`, `tests/js/test_st3a_hw.js`, in-SketchUp sekcia **`run_st3a`** (zápis predvoľby =
1 krok Späť, NO-OP `merge_seed` bez pushu aj bez undo kroku, jantár po vlastnom zápise nezožltne, payload nesie novú hodnotu v `hw.sets`).

**ŠT-3a-3 — render setov je ROZDELENÝ:** `HWSETS.setData` (iba dáta) vs. `HWSETS.render` (kreslenie); plný push volá `setData` a telo sekcie kreslí `hwRenderBody` hneď za ním, kým
`HWSETS.init` (dáta + render) ostáva pre ECHO, po ktorom už žiadny render nepríde (`NX.setHwSets` po odmietnutom zápise). Predtým sa zoznam setov aj predvolieb kreslil pri KAžDOM
pushi **dvakrát**. `hwsRenderSets`/`hwsRenderProj` navyše držia **snapshot fokusu** (vzor `mdhRender`) — v okne sa prekresľovalo len po zápise, v sekcii pri každom pushi, takže
používateľovi mizol kurzor z rozpísaného editora setu; chýbajúci atribút je súčasťou identity (`:not([…])`), inak by sa fokus vrátil do rovnomenného poľa v inom riadku.

**Hodnoty rozpísaného formulára prežijú push** — `#hn_category` aj `#hn_unit` majú `keep` (`mdhRenderEnums` beží pri každom pushi a bez neho by sa kategória aj MJ prepli na PRVÚ v
zozname), a `MDH.created` čistí filter **aj v premenných** `HW_Q`/`HW_CAT`, nielen v uzloch lišty — inak by najbližší push nakreslil lištu so STARÝM filtrom nad NEFILTROVANÝM
zoznamom.

**ŠT-3b-1 — ôsma živá sekcia: PRAVIDLÁ (`rules`, tretia zo skupiny KATALÓGY).** Presun formulára zaniknutého okna „Pravidlá kovania" (Š17, skupina „Kovanie podľa rozmerov"): akcie
**Uložiť a prestavať skrinky · „aj ako globálnu predvoľbu" · Načítať globálne · Doplniť nové predvolené** sú v LIŠTE sekcie (`rulesToolsHtml` — čistá funkcia, stav chodí
argumentom), telo je **JEDEN uzol naklonovaný raz zo `<template id="rulesBodyTpl">`**.

**Formulár prežije push:** `rdApplyState` porovnáva odtlačok pravidiel (`RD_SEED`) a prekresľuje LEN vtedy, keď sa pravidlá NA MODELI naozaj zmenili (vlastné uloženie, Späť,
prepnutie dokumentu, odmietnutý zápis) — inak sa nasadí len meta riadok (zdroj, počet skriniek). „Načítať globálne" odtlačok ZAMERNE NEobnovuje: je to zmena formulára, ktorá ešte
NEPLATÍ, a najbližší push by ju inak potichu vrátil.

**Payload chodí CELÝ pri každom pushi** (`rules_payload(model, collected)` — model AJ hotový zber ARGUMENTOM, lekcia F4; **žiadny druhý sken modelu**) — **žiadna západka
`full_pending`**: pravidlá sú malý JSON (jednotky záznamov, žiadne `row_rev` per položku ako katalóg), takže druhý kanál by bol drahší než payload.

**ŠT-3b-2a — read-only bloky sekcie** (`abs` = pravidlá ABS podľa roly, `overrides` = jantárové riadky ručných zásahov) majú **VLASTNÉ DOM uzly a vlastnú render funkciu
`rdRenderExtra`, ktorá beží pri KAŽDOM pushi** (vzor `rdSrcLine`) — zámerne MIMO `rdRender`/`RD_SEED`: ručný zásah v Inspectore pravidlá NEMENÍ, takže odtlačok formulára je ten
istý a riadok by sa inak objavil až po prepnutí sekcie; naopak rozpísaného formulára sa `rdRenderExtra` nesmie dotknúť. Poradie skupín je **ABS nad kovaním** (mockup), telo ostáva
JEDEN uzol `#rulesBody`.

**ŠT-3b-2b:** okno dostalo VEREJNÝ čítač `StudioDialog.generation` — zapisové akcie sekcie potrebujú ten istý guard, aký má klik v Kusovníku (klik zo zastaraného zoznamu sa nesmie
vykonať); generáciu zdvíha naďalej VÝHRADNE `push_state`. Po zápise do modelu dostanú čerstvé čísla **obaja odberatelia** — `Panel.push_selected` (pravidlá menia kovanie v sekcii
Kovanie Inspectora) a `refresh_if_open(bump: true)` (prestavba VŠETKÝCH korpusov mení kusovník, nákupný zoznam aj rozpočet), a to v TOMTO poradí (vzor
`refresh_studio_after_model_write`). Testy: `tests/pure/test_st3b_rules.rb`, `tests/js/test_st3b_rules.js`, in-SketchUp sekcia **`run_st3b`**.

### StudioModelWatch — indikátor neaktuálnosti okna (22.8., „Obnoviť" zožltne)

Štúdio čísla **neprepočítava samo** — kým sa nestlačí „Obnoviť", visia v ňom čísla z posledného prepočtu. Model sa medzitým mohol zmeniť (prestavba skrinky z Inspectora, posun,
Späť/Znova) a okno vyzeralo **úplne rovnako**, takže sa dalo exportovať VEPO, objednávku aj cenovú ponuku zo starých čísel. Okno má preto **vlastný `Sketchup::ModelObserver`** (4
hooky: commit · undo · redo · abort; trieda je pod guardom `defined?(Sketchup::ModelObserver)`, lebo headless testy súbor requirujú bez SketchUpu — vzor `edge_overlay.rb`).

**`PanelModelObserver` ani `ScaleWatch` sa nedotkli**: prvý počuje LEN Späť/Znova/Abort, druhý vedome filtruje vlastné prestavby — ani jeden teda nevidí hlavný prípad.

**Callback je prázdny** (pravidlá observerov + lekcia D-103): `@epoch += 1` a latch `UI.start_timer(0)` — žiadne čítanie ani zápis modelu, burst commitov = **jeden** `js` do okna
(vzor `Panel.request_txn_refresh`).

**Jadro riešenia je POROVNANIE EPOCH:** `push_state` si ukladá `@pushed_epoch = @epoch` **až na konci** (po `fresh_collect`, a len keď payload naozaj odošiel) — transakcie, ktoré
spustil **sám prepočet okna**, sú tým už započítané a flush ich **pohltí sám**; žiadne volacie miesto nepotrebuje výnimku ani „suspend" prepínač. *(Od 1b-3 má prepočet okna už len
JEDEN taký zdroj — zápis rozpočtu s `bump: false`. Druhým býval dedup kópií vo `fresh_collect`; ten zanikol, lebo čítanie do modelu nezapisuje, a in-SketchUp scenár `STALE (c)`
odvtedy meria opak: „Obnoviť" nad modelom s duplikátmi model NEZMENÍ a tlačidlo aj tak nezožltne.)* Flush posiela `NX.markStale()` len pri
`@epoch > @pushed_epoch`, so **živým oknom** a **dvojitým guardom dokumentu** (`txn_model_ok?` — overuje sa v callbacku aj znova v timeri, dokument sa môže prepnúť medzi udalosťou
a timerom).

**Lifecycle = presne život okna:** attach v `ensure_dialog` (anti-double `remove → add`, každý krok vlastný rescue — vzor `EdgeCheck.attach_observer`), detach v `set_on_closed`,
prevesenie + nulovanie epochy pri prepnutí dokumentu (`on_model_changed`) — **epocha je per dokument**.

**Žiadny `Engine` broadcast** (vedome): epocha má jedného vlastníka.

**Klient** drží `staleFlag` (stav OKNA — nikam sa neukladá); `NX.markStale()` prekreslí **len lištu aktívnej sekcie** (tabuľka aj zoznam nálezov sú stále tie čísla, čo prišli
naposledy), zhadzuje ho **výhradne plný payload** `setStudio` (pred `render()`) — echá (`setVepoBar`, `setEdgeCheck`, `setGrainCheck`, `budgetResult`) čísla nenesú, takže stav
nezhadzujú. Jantár ide cez tokeny `--nx-warn*` (tá istá trieda vzhľadu ako jantárové „Prepočítať ceny"); **zelená vedome nie je** — významové farby ostávajú semaforu Kontroly.

**PRIZNANÁ ŠÍRKA SIGNÁLU** (tooltip aj tento odsek): server nevie, či zmena naozaj hla kusovníkom — posun cudzieho objektu tick vyvolá tiež. Signál hovorí **„možno neaktuálne", nie
„určite zmenené"**; radšej jantár navyše než export zo starých čísel.

**Žiadny prepočet, žiadny zápis, žiadny krok Späť** — tick je čistý JS signál. Testy: `tests/pure/test_stale_obnovit.rb` (kontrakt observera, latch, epochy, lifecycle),
`tests/js/test_stale_obnovit.js` (dva stavy tlačidla, echá, päť miest), **in-SketchUp sekcia `run_stale`** (dôkazová zásada D-101 — počítadlá vstupov aj odoslaných signálov: commit
= 1 · burst 3 = 1 · vlastný tick prepočtu = 0 · zápis rozpočtu = 0 · Späť/Znova = 1 · cudzí dokument = 0 · po zatvorení okna 0 vstupov).

### Sekcia KONTROLA v Štúdiu (ŠT-1b, Š8–Š11)

presun tabu Kontrola z okna Výroba — **obsah sa presúva, nekopíruje** (tab aj s lištou prepínačov tam zanikol).

**Š8 semafor** = tri chipy, z ktorých **červený a oranžový sú FILTRE** (druhý klik zruší, `ctrlFilter` je stav OKNA — nikam sa neukladá) a zelený je informačný „skriniek bez
nálezu".

**Všetky tri čísla sú serverové** — `Validation.counts` dostalo od tejto dávky **zelené číslo** (`cabinets`/`clean` = počet korpusov mínus vlastníci s nálezom).

**Menovateľ je skutočný počet skriniek zo zberu (`collected[:cabinets]`)**, nie dĺžka zoznamu ID z `placements`: `Bom.add_placement` záznam vynecháva (prázdne ID, degenerované
rozmery) a rovnaké ID zbiera raz, takže poškodená skrinka či dve kópie s tým istým ID by počet skriniek **ticho zmenšili** (nález review #2). Množina ID z `placements` slúži len na
rozhodnutie „ktoré ID patrí skrinke"; bez nej sa zelené číslo nepočíta vôbec a tvar `counts` sa **nemení** (legacy volania sú nedotknuté), `with_budget` ho prenáša ďalej, lebo
rozpočtový nález vlastníka nemá.

**Prijatý limit (review #8):** nález „dva kusy na jednom mieste" nesie `owner_id` prvého vlastníka skupiny, takže zo skupiny „špiní" zelené číslo len jedna skrinka — rozpad na viac
vlastníkov by zmenil `stable_key` (a s ním klik-select aj dedup), pričom nález aj tak vedie k oprave celej skupiny. Filter **LEN skrýva** — poradie ani dedup neurčuje klient, a
index riadku ostáva indexom do **serverového** poľa, inak by klik pri zapnutom filtri adresoval iný nález.

**Š9 riadok**: bodka závažnosti · text · miesto · akcie vpravo. Klik na riadok aj **oko** = `nx_select` s `problem_key` (stabilný kľúč, nie pids — po flushi editov by už neplatili;
jadro je `ProductionCore.do_select`), **ceruzka** = to isté + `focus_inspector`.

**Kontextová oprava je len tam, kde existuje:** UNI nález ponúka **„Nahradiť UNI…"** cez vlastný callback `replace_uni` → `MaterialsDialog.request_replace_uni` (**plne funkčný
modal**, nie sľub), rozpočtový nález nemá entitu v modeli a **od ŠT-1c PR B1 vedie do SEKCIE Rozpočet toho istého okna** (`studioGoSection('budget')` + `budGoto(budget_section)` —
server skladá adresu, klik zostáva v okne; premostenie do okna Výroba zaniklo spolu s ním).

**Š10 lišta sekcie** nesie OBA prepínače: „Zvýrazniť hrany" ako tlačidlo s **rohovým trojuholníkom** (klik na telo prepína, klik na roh otvára 3-stavové nastavenie — zdieľaný
`edge_menu.js`, od ŠT-1c PR B3 **druhá (a posledná) inštancia**, poloha cez `.ecmenu-studio`) a „Smer kresby" (K2/D-87). Zatvára ich **klik mimo aj Escape** (vzor `bindEdgeMenu` v
raile) a otvorenie zavrie kópiu v raile (`edge_menu_open` → `Engine.close_edge_menu(:studio)`; tretia inštancia — okno Výroba — zanikla v ŠT-1c PR B3, takže sú už len dve).

**Š11 badge**: navigačná položka Kontrola nesie živé RED/ORANGE počty **z tých istých `counts`** ako semafor (čistá zákazka badge nekreslí). Payload sekcie chodí **v tom istom
pushi ako Kusovník** (`control` · `counts` · `edge_check` · `grain_check`) — prepnutie sekcie je čisto zobrazovacie a nesmie chodiť na server.

**Vedomé odchýlky:** režim „diel po diele" (D-95) je mimo dávky (blok KONTROLA+VÝROBA). Testy: `tests/pure/test_st1b_kontrola.rb`, `tests/js/test_st1b_kontrola.js` (+ presunuté
sady `test_d104`/`test_d105`/`test_k2`/`test_abs_rail_3stav`), in-SketchUp sekcia `run_st1b`.

### Sekcia NÁKUP KOVANIA v Štúdiu (ŠT-1c PR A, Š7)

presun tabu Kovanie z okna Výroba — a na rozdiel od ostatných sekcií **bez akéhokoľvek redizajnu**: kontrakt Š7 ho zakazuje, nákupný zoznam sa prekreslí až s blokom KOVANIE. Sekcia
vznikla preto, aby okno Výroba mohlo zaniknúť — čo sa v PR B3 aj stalo. Obsah je znak po znaku ten istý — **nákupný zoznam zo setov** (kategórie ako medzihlavičky, riadok mimo
katalógu jantárovo, súčet „len známe ceny" s priznaným počtom nezadaných), **zoznam „Bez kódov"** (dôvod `reason_sk` aj rozmer `params_label` skladá server) a **generika podľa
pravidiel** s klik-selectom vlastníka.

Presunulo sa **všetko naraz**: render (`buySection` v `studio.js`), pomocníci `price`/`hwManualMark`, CSS `.hwsec`/`.hwbanner`/`.hwcat`/`.hwmiss`/`.hwsum` (z inline štýlov
`production.html` do `studio.html`, pevné hexy prepísané na `--nx-*` tokeny — okno má dve témy) aj payload polia `hardware` a `hardware_sets`, ktoré okno Výroba **prestalo
dostávať** (a v PR B3 zaniklo celé).

**Odchýlky od „1:1", všetky vedomé:** CSV export nesedí v hlavičke tabuľky, ale v **lište sekcie** (kontrakt §3 — exporty patria sekcii) a je pri ňom **„Obnoviť"** (prestavba
skrinky z Inspectora sem sama nedorazí — bez neho by sa nákupný zoznam dal exportovať zo starých počtov bez cesty k čerstvým); tabuľky preberajú `.bomtab` **Štúdia** (rovnaký
vzhľad ako Kusovník vedľa nich), ale nesú marker **`.hwtab`**, ktorý vracia ruku a hover **výhradne riadku generiky `tr.hwgen`** — `.bomtab tbody tr` má v Štúdiu afordanciu kvôli
Kusovníku, kým tu je klikateľný jediný typ riadku (pôvodné okno dávalo ruku tiež len `tr.bomrow`/`tr.hwrow`).

Riadok generiky sa v0.7.58 premenoval z `tr.hwrow` na `tr.hwgen`: `.hwrow` je v zdieľanom panel.css **flex riadok** kovania Inspectora/Katalógu a `<tr>` s `display: flex` strácal
zarovnanie stĺpcov s hlavičkou (guard `tests/pure/test_tr_flex_kolizia.rb` stráži, že žiadny `<tr>` nenesie triedu, ktorej panel.css dáva flex/grid). Export ide **vlastným kanálom
okna** — `hw_csv_export` → `handle_hw_csv` → `NX.studioRelayHwCsv` (flush handshake: červené pole panela export zastaví) → `studio_do_hw_csv` → `ProductionCore.do_hw_csv`; klik na
riadok generiky ide **existujúcou cestou** `nx_select` s `hw_key` (`refs_for` nájde vlastníkov v čerstvom BOM). Navigačná položka `buy` prestala byť premostením. Testy:
`tests/pure/test_st1c_nakup.rb`, `tests/js/test_st1c_nakup.js`, `tests/js/test_d93_nl_override.js` (presunutá sada znamienka ručného zásahu), in-SketchUp sekcia `run_st1c`.

### Sekcia ROZPOČET v Štúdiu (ŠT-1c PR B1, Š12–Š13)

presun posledného tabu okna Výroba — a **JEDINÁ sekcia, ktorá zapisuje do modelu** (1 zmena = 1 krok Späť). Obsah je 1:1 (Š12), **kód nie**: render `js/budget.js` sa rozrezal na
**lištu sekcie** (`budToolsHtml` — prepínače *s DPH/bez DPH* a režim *€ · €€ · €€€*, „Prepočítať ceny", „Obnoviť", XLSX rozpočtu a ⚙; **„Prepočítať ceny" kreslí `budPriceBtnHtml` a
je JANTÁROVÉ, keď zákazka nesie staré ceny** — SMOKE 22.8.: rozpočet vyzeral rovnako s čerstvými aj s polročnými cenami, takže sa z neho dalo objednávať bez varovania. Je to
**čistá projekcia poľa `stale`**, ktoré payload už nesie (ten istý zdroj ako jantárový chip pri súčte aj zoznam starých riadkov) — **žiaden nový výpočet, žiadne meranie veku v
klientovi**; počet aj prah skladá `budStaleLabel` do tooltipu, farba ide cez `--nx-warn*` tokeny (`.bstalebtn`) a **zelená sa nepoužíva** — významové farby ostávajú semaforu
Kontroly.

Počas behu prepočtu je tlačidlo `disabled` a jantár sa nekreslí: dve signalizácie naraz by si protirečili) a **telo** (`budDrawBody` — veľký súčet, jantárové chipy, zbaliteľné
sekcie); `budRerender()` kreslí oboje naraz, lebo DPH aj režim menia aj lištu.

**Obnova fokusu má JEDNO miesto na prekreslenie** (review PR #198 #5): `budDraw*` len kreslí, `budRerender` robí jeden `budCaptureFocus` na začiatku a jeden `budRestoreFocus` na
konci — kým mala každá polovica vlastnú dvojicu, jedno prekreslenie ju spravilo dvakrát a druhý `capture` už mohol snímať `<body>`. Súbor sa načítava **AŽ ZA `studio.js`** (stráži
guard test): `studio.js` priraďuje celé `window.NX = {…}`, takže v opačnom poradí by prepísal obal aj `budgetResult`/`priceRefresh` a rozpočet by po prvom zápise zamrzol. Prefixy
`bud*`/`BUD_*` sú tam preto, že oba súbory bežia v JEDNOM globálnom scope (kolízia mena `renderBody` medzi `studio.js` a `budget.js`).

#### GENERAČNÝ KONTRAKT (audit #1) — najdôležitejšia vec dávky

budget-iniciovaný push ide `push_state(bump: false)` — payload je **plný** (Kontrola dostane čerstvé rozpočtové ORANGE), ale **generácia okna sa nedvíha**. Mutácia rozpočtu totiž
nemení `rows`/`refs`, takže rozkliknutý riadok Kusovníka ani rozrobený export inej sekcie nesmie zastarať len preto, že niekto prepísal sumu. Ochranu proti **zastaranému zápisu**
drží to, že KAŽDÁ iná zmena (model, katalóg, prepnutie dokumentu, refresh z iného okna) generáciu bumpne ako doteraz — a mutácia so starým `gen` sa odmietne. Prvý push generáciu
zdvihne vždy (`gen 0` = „žiadne dáta"). Fronta zápisov (`BUD_BUSY`/`BUD_QUEUE`, GH #138 P2) sa preto uvoľňuje **VÝHRADNE v `NX.setStudio`** (audit #6) — malé echá
`setVepoBar`/`setEdgeCheck`/`setGrainCheck` čerstvú `gen` nenesú a zápis odoslaný na ne by server odmietol ako zastaraný.

Poistný timer `BUD_BUSY_MS = 6 s` je len záchranná sieť: in-SketchUp meranie dáva push ~3 ms a celú mutáciu vrátane repushu ~4 ms.

#### Kanály

mutácia ide **priamo** (`budget_mutate` → `StudioDialog.do_budget` → `ProductionCore.do_budget`) — nie je to export a flush handshake by pri každom prepise sumy zbytočne prehnal
rozpísané edity panela; **oba XLSX exporty** naopak handshake majú (`budget_xlsx`/`cp_xlsx` → `NX.studioRelayBudget`/`studioRelayCp` → `studio_do_budget_xlsx`/`studio_do_cp_xlsx` →
jadro), lebo čísla hárku musia sedieť s modelom PO flushi.

**Odchýlky od „1:1", všetky vedomé:** prepínače a exporty sú v **lište sekcie** (kontrakt §3), takže stĺpcový obal `.bswitch` a pätka `.bfoot` zanikli a v tele ostal veľký súčet s
chipmi · pribudlo **„Obnoviť"** (prestavba skrinky z Inspectora sem sama nedorazí — rovnaký dôvod ako v Kusovníku a Nákupe) · **jantárový chip súčtu vedie do sekcie Kontrola** a
jeho rozbaľovací zoznam nálezov zanikol — bola to druhá kópia zoznamu, ktorý od ŠT-1b žije o kúsok vedľa.

**Chip preto počíta VŠETKY rozpočtové nálezy, nie „zvyšok"** (review #2): kým mal vlastný zoznam, spotrebičové upozornenie sa z počtu odpočítavalo, lebo malo vyššie vlastný chip —
odkedy klik vedie do Kontroly, musí ukazovať presne to číslo, ktoré tam používateľ uvidí (chip spotrebičov ostáva ako **špecifická skratka** na ich sekciu rozpočtu; `counts` a
`Validation.with_budget` sa nemenia). Opačným smerom: nález kategórie `budget` v Kontrole prepne na Rozpočet a otvorí `budget_section` nálezu) · **⚙ ostáva** ako kontextová skratka
k sadzbám (#20), hoci to isté okno otvára aj položka navigácie.

**PR B2 dokončil dve odložené veci:** inline drafty vlastnej položky a spotrebiča nahradil **D-15 modal** (nižšie) a náhľad cenovej ponuky sa presunul do **vlastnej sekcie** — v
tele Rozpočtu po ňom ostal len **tenký preklik** `budCpLinkHtml` (suma ponuky + stav + šípka), takže druhá kópia tabuľky, ktorá by sa časom rozišla, neexistuje. S ňou odišiel z
lišty aj export „Cenová ponuka (zákazník)" — patrí sekcii, ktorá dokument vyrába (a lišta tým schudla o najdlhší popisok, review PR #198 #4). Testy:
`tests/pure/test_st1c_rozpocet.rb`, `tests/js/test_budget_ui.js`, in-SketchUp sekcia `run_st1c` (12 operácií × „jeden krok Späť", gen a guid guardy, odmietnutý zápis nechá draft
otvorený, dôkaz `bump: false` klikom v Kusovníku so starou generáciou, XLSX guardy bez dialógu, meranie #19).

### Sekcia CENOVÁ PONUKA v Štúdiu (ŠT-1c PR B2, Š14–Š15)

do PR B1 to bol zbaliteľný náhľad vnútri Rozpočtu (E-b2), od PR B2 je to **vlastná sekcia `offer`** — zákaznícka **projekcia** toho istého rozpočtu. Kreslí ju **ten istý
`js/budget.js`** (`budOfferHtml` + `budOfferToolsHtml`) zámerne: dáta sú ten istý payload (`budget.cp_preview`), sumy ten istý formát a zápisy tá istá cesta — druhý súbor by
znamenal druhú kópiu formátovania a druhý kanál na server.

**Žiadny nový serverový kód:** payload aj mutácia `cp_group` existujú od E-b2, `do_cp_xlsx` od PR B1; pribudlo len `SECTIONS += offer` (+ obe JS zrkadlá). Obsah podľa mockupu:
**suma ponuky** s priznaným režimom DPH a poznámkou „z Rozpočtu" · **položky rečou zákazníka** (`budCpTableHtml`) s **per-riadok prepínačom „samostatne"** — tou istou mutáciou, akú
predtým posielala šípka v náhľade (1 zmena = 1 krok Späť), len rečou používateľa namiesto ikony · zbalený zoznam **„Zlúčené v zostave"** · riadok **zaokrúhlenia** · **jantárový
guard** „Suma ponuky je podhodnotená — X riadkov rozpočtu nemá cenu" s preklikom **do Rozpočtu** (Š15 „upravuj pri zdroji" — ponuka sa needituje, chýbajúca cena sa dopĺňa tam, kde
vznikla) · **priznaný wireframe „Dokument ponuky (DOCX/PDF)"** (Š14: generátor je vedome až po V1, D-78 zakazuje mŕtve tlačidlo bez dôvodu).

V lište sekcie je **„Cenová ponuka (zákazník)"** (presun z lišty Rozpočtu — tlačidlo si nechalo meno z mockupu, presťahovalo sa len k dokumentu, ktorý vyrába) a **„Obnoviť"**
(zdieľaný `#refreshBtn`; ponuka zo starých rozmerov by išla zákazníkovi).

#### Varovný pás patrí AJ sem (review #1)

odkedy je export zákazníckeho dokumentu jedine v tejto sekcii, kreslí sa v nej celý `budWarnChips(b)` — staré ceny, spotrebiče aj rozpočtové upozornenia. Sú to **tie isté čísla**
ako v Rozpočte (jedno miesto, jeden výpočet); mení sa **len cieľ kliku**, lebo v ponuke sa needituje nič: staré ceny → Rozpočet (tam je „Prepočítať ceny"), spotrebiče → Rozpočet
rovno na ich sekciu (`data-section` + `budGoto`), upozornenia → Kontrola. Bez toho by sa dala ponuka poslať zákazníkovi z neaktuálnych cien bez jediného slova. Zoznam **„Zlúčené v
zostave"** je v `BUD_OPEN` pod kľúčom `cp_merged` (review #8) — štandardne zbalený, ale po otvorení prežije prekreslenie, inak by sa po každom prepnutí „samostatne" sám zabalil a
fokus (`data-bkey="sep:…"`) by spadol na `<body>` práve tam, kde sa kliká najviac.

**Vedomé odchýlky:** prepínač DPH sa **nezdvojil** — ponuka je projekcia rozpočtu a dve miesta na prepínanie toho istého čísla by ukazovali dva stavy; v akom režime sa suma
zobrazuje, priznáva `<small>` pri nej. Riadok zaokrúhlenia stojí **v oboch sekciách** — je to JEDNO serverové číslo v dvoch úlohách (v Rozpočte vysvetľuje, ako sa súčet stal
konečnou sumou; v Ponuke je to riadok dokumentu), nie dve pravdy. Testy: `tests/pure/test_st1c_ponuka.rb`, `tests/js/test_st1c_ponuka.js`, in-SketchUp sekcia `run_st1c`
(`st1c_offer`).

### JEDEN push kanál nad modelom (uzavretá nota ŠT-1a, audit #15)

kým žilo okno Výroba aj Štúdio, ten istý zber modelu (`fresh_collect` + `Bom.compute` + katalógy) bežal pri každom refreshi **dvakrát** — raz pre každé okno. Bolo to vedome
akceptované ako dočasný stav a **ŠT-1c PR B3 ho zrušila zánikom okna Výroba**: pipeline beží raz. Zdieľaná cache (musela by vedieť, kedy je zber zastaraný — undo, dedup tik, zmena
katalógu) tým prestala byť naliehavá; ostáva ako kandidát na optimalizáciu, nie ako záplata dvojitého behu.

**Dôsledok pre nové sekcie (ŠT-3b-2a):** čokoľvek nové, čo potrebuje dáta z modelu, sa priveze v `Bom.collect` (aditívny kľúč — `manual_overrides`) a do payloadu sekcie ide **z už
hotového `collected`**; druhý sken modelu kvôli jednej sekcii je zakázaný.

## Okná — lifecycle a zaniknuté satelity

### Satelitné okná

od **ŠT-4a sú DVE** (Inspector · Štúdio) — **SATELITY ZANIKLI VŠETKY** a je to konečný stav: každý ďalší nárast tohto čísla znamená NOVÉ okno, teda rozhodnutie, nie vedľajší účinok
dávky (stráži guard test, ktorý kontroluje aj MENÁ oboch). Obe idú spoločným boot hookom `Engine.register_dialog_fit` (téma UI-01 + dorovnanie veľkosti D-77) — stráži to guard
test.

**Zoznam sa od tejto dávky ZMENŠUJE:** `studio_dialog.rb` (vyššie) je ich cieľový nástupca a satelit zaniká vždy až vtedy, keď je jeho obsah plne v Štúdiu (poradie: ŠT-1b Kontrola
· ŠT-1c Rozpočet+Nákup ⇒ **okno Výroba ZANIKLO v ŠT-1c PR B3** · ŠT-2 Materiály · ŠT-3 Kovanie/Pravidlá/Šablóny · **ŠT-4a Nastavenia — POSLEDNÝ satelit**). Kým satelit žil,
otváralo ho **premostenie v navigácii Štúdia** (uzavretý whitelist `WINDOW_BRIDGES`); s posledným satelitom zanikla aj celá tá mašinéria.

**KAŽDÉ okno, ktoré ukazuje čísla zákazky, musí byť vo VŠETKÝCH refresh cestách** (`scale_observer` prepnutie modelu · `materials_dialog` zápis katalógu ·
`supplier_settings_dialog` sadzby (od ŠT-4a to nie je okno, ale SEKCIA — cesta `refresh_studio` → `StudioDialog.refresh_if_open(bump: true)` je tá istá, len beží zvnútra) ·
`hardware_catalog_dialog` sety a položky (od ŠT-3a-1 `push_items`/`after_sets_change` obsluhujú OBA ciele — okno aj sekciu `hw`) · `price_refresh_after_proc` v `studio_dialog.rb`
po prepočte cien) — okno, ktoré v niektorej chýba, zamrzne na starých číslach a používateľ to zistí až na objednávke (stráži guard test).

Jednotlivé žijúce okná (každé má vlastný odsek nižšie):

### production_dialog.rb — okno Výroba (ZANIKLO v ŠT-1c PR B3)

**Okno Výroba (`production_dialog.rb` + `production.html` + `js/production.js`) ZANIKLO v ŠT-1c PR B3** — jeho päť obsahov (Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová
ponuka) sú sekcie Štúdia, telá akcií žijú v `production_core.rb` a všetky vstupné body (položka menu, päť relayov panela, `productionRelay*`, deep-link na tab, vetvy v broadcastoch
aj v refresh cestách) sú preč. Osirotený `preferences_key` `'NoxunEngineProduction'` v registri používateľa ostáva — je to zapamätaná veľkosť okna, ktoré už neexistuje, a SketchUp
ho nikdy nepoužije (dôvod v `SYSTEM/archiv/KRONIKA.md`).

### materials_dialog.rb

**`materials_dialog.rb` — od ŠT-2b už NIE JE OKNO** (ostal serverový modul; obsah je sekcia `mat` Štúdia, popis je tu kvôli histórii): katalóg = mriežka dlaždíc podľa výrobcu + pás
„Použité v projekte" — jediné echo je `push_catalog` BEZ scanu modelu; hľadanie názov/výrobca/kód/dodávateľ; klik na dlaždicu → detail dekoru s editovateľnými bunkami
kód/cena/dodávateľ — patch protokol s `row_rev`, dirty bunka si baseline drží aj cez refresh, re-render neprepíše aktívny input, prázdna bunka pole VYMAŽE; batch „Nový dekor" cez
preset-čipy + zapamätaná posledná sada (localStorage len UX); predvoľby projektu v `<details>` s `model_guid` guardom; guard hrúbok/typu; živý sync `NX.setMaterials` bez resetu
formulára.

**ŠT-2b — OKNO ZANIKLO, MODUL ŽIJE (audit #21 — NEPREMENÚVA sa):** `proj_materials.html`, `UI::HtmlDialog`, `DLG_KEY`, `ensure_dialog`, `register_callbacks` aj `dialog_js` sú preč;
ostala **jediná serverová autorita katalógu**.

Sekcia posiela tie isté payloady pod tými istými menami a Štúdio ich preposiela cez `dispatch(name, payload, sink)` — uzavretý whitelist `SECTION_ACTIONS` (ŠT-2b doňho pribudli
**Demos toky** `demos_lookup`/`demos_manual_url`/`demos_apply`/`demos_cancel`/`demos_name_search`/`demos_family*`, `open_search_url` a
**`replace_uni_preview`/`replace_uni_apply`**; **`add_sheet`/`add_edge` ZANIKLI** — create cesta formulára bola z UI nedosiahnuteľná (formulár sa otvára výhradne s id existujúceho
záznamu, nové dekory/varianty idú batchom v3) a jej payload nenesie `group_id`, takže nad SCHEMA ≥ 2 by zápis skončil na `write_unlocked` completeness guarde len s generickým
„Uloženie zlyhalo"; `handle_save_sheet`/`handle_save_edge` sú preto **edit-only** a chýbajúci záznam vracia hlášku s návodom na batch), telá handlerov ostávajú tu; **ŠT-2c 2c-2a
pribudlo `save_decor`** — JEDNA akcia na CELÝ formulár „Upraviť…“ detailu dekoru.

Handler si guardy **zámerne nerobí**: `catalog_write_ok?` by brány (read-only, schéma, baseline) vyhodnotil MIMO zámku a medzi kontrolou a zápisom by sa katalóg stihol zmeniť —
celý kontrakt vrátane `base_rev` a `row_rev` každého riadku beží POD zámkom v `Materials.save_decor`. Odpoveď má tri prijímače podľa toho, čo má modal urobiť s rozpísaným
formulárom: `MD.editSaved` (zavri + zahoď pamäť), `MD.editErrors` (chyby k poliam, okno OSTÁVA), `MD.editBlocked` (odomkni, hodnoty ostávajú **a riadky sa dorovnajú z čerstvého
katalógu** — baseline omladne, riadky zmenené zvonku dostanú štítok, takže „ulož znova“ je splniteľné; bez toho by konflikt nemal cestu von) + `MD.editDuplicateCode` (druhé
„Uložiť“ potvrdí duplicitu kódu)).

**`mdEditRefresh` prelieva LEN bunky, ktorých sa používateľ dotkol (1b-7, sweep #8 — cenové P2).** Do 1b-7 kopírovalo zotavenie z konfliktu do čerstvého katalógového riadku
**všetky** editovateľné stĺpce starého formulára — aj tie, ktoré používateľ nikdy nepísal. Riadok si pritom nesie **čerstvý `row_rev`** (`row_rev` je v `hidden`, nie v `cols`)
a `mdEditBase.rev` omladne, takže ďalšie *Uložiť* prešlo cez **oba** zámky a **ticho vrátilo cenu/kód/formát, ktorý medzitým prišiel zvonku** — štítok „zmenené mimo editora"
síce svietil, ale čerstvú hodnotu neukázal. Dnes sa každá bunka porovná s **`NXModal.baseRows(key)`** (východisko, proti ktorému používateľ písal, `mdSameCell`): netknutá bunka
dostane **čerstvú** hodnotu, zmenená si nechá používateľovu, a bunka zmenená **oboma** (a naozaj na inú hodnotu) ide do modalu ako **kolízia** (`_conflict` + `_wrote`) — pás *tvoja × v katalógu* s rozhodnutím a
zablokovaným zápisom. `setRows` dostáva ako `base` **čerstvé katalógové riadky** — stará hodnota ide výhradne do stavu modalu (`_wrote`), lebo z `base` kreslí „Začať odznova"
a stará hodnota s čerstvým `row_rev` by prebehla cez oba zámky (P1 interného review). `editBlocked` má pre kolíziu **vlastnú hlášku**, ktorá pýta rozhodnutie namiesto „ulož
znova". Testy: `tests/js/test_1b7_kolizia_buniek.js`.

**Adresát odpovede:** `with_client(sink)` presmeruje `js` na volajúceho **na čas jedného synchrónneho volania** (`ensure` je povinné — visiaci sink by zdedila nasledujúca, aj
asynchrónna odpoveď); **mimo neho ide všetko do Štúdia** (`studio_js` → `StudioDialog.mat_js`, tenký verejný most, lebo kanálové `js` Štúdia je private). Práve na tom stojí Demos:
`dispatch` beh len **naštartuje** a vráti sa, emity dobiehajú z `UI.start_timer` už bez sinku.

**`after_catalog_change` má JEDNU cestu** — jeden `catalog_payload` (druhý by znamenal druhý `Materials.load` a druhý výpočet `row_rev`) ide `StudioDialog.push_mat_catalog`-om do
sekcie, plus `Panel.push_materials`, `EdgeCheck.invalidate!` a plný payload Štúdia s **`bump: false`** (katalógový zápis nemení model, takže pending klik ostáva platný).

**`push_state` / `state_payload` / `push_state_both` ZANIKLI** spolu s druhým UI — a s nimi aj **druhý sken modelu** `Materials.model_decor_usage`, ktorý okno robilo pri každom
plnom pushi: modelový kontext sekcie (predvoľby, počty, `used`) nesie `StudioDialog#mat_payload` z už zozbieraného kusovníka (review ŠT-2a #4).

**Dve cesty menia MODEL** (projektová predvoľba, apply „Nahradiť UNI…") — obe volajú `refresh_studio_after_model_write` (plný push **so zdvihom** generácie) zámerne **až za
`Panel.push_selected`**: dedup identity kópií, ktorý si panel vyžiada u observera, je oneskorený a jantárové „Obnoviť" by inak zožltlo hneď po prepočte.

**Životný cyklus** už nehlási vlastný `set_on_closed`, ale Štúdio: `on_ui_closed` (zatvorené okno — session bump + zahodenie odloženej požiadavky), `cancel_demos_on_leave` (odchod
zo sekcie počas behu — session bump + status) a `on_model_changed` zo `scale_observer` (prepnutý dokument), pričom `@demos_running` stráži, aby sa hláška o zrušení objavila len
vtedy, keď naozaj niečo bežalo).

### templates_dialog.rb

**`templates_dialog.rb` — od ŠT-3c-1 už NIE JE OKNO** (ostal serverový modul; obsah je sekcia `tpl` Štúdia — popis nižšie v odseku `templates`;
história okna: **UI-C1a: okno spravuje VÝHRADNE korpusové šablóny** — payload je `Panel.template_list(kind: 'cabinet', previews: true)` a `find`/`upsert`/`delete`/`set_preview`
majú vlastný `kind` guard, HTML nie je ochrana, takže doskovú šablónu sa odtiaľ nedá použiť, vymazať ani odfotiť.

**SMOKE PACK 1:** riadok má tretie tlačidlo **„Odfotiť" / „Prefotiť"** (podľa `preview_rev`) — pridá k šablóne náhľad z **práve jednej označenej** skrinky bez toho, aby prepísalo
jej dáta; je **vždy aktívne** (vzor D-78 — dôvod, prečo to teraz nejde, povie server v statuse), text namiesto ikony preto, že toto okno sprite `icons.js` nenačítava).

### hardware_catalog_dialog.rb

**ŠT-3a-1 — `hardware_catalog_dialog.rb` OKNO vtedy ešte ŽILO, ale prestalo byť jediným UI** *(od ŠT-3a-2 už NIE JE OKNO — ostal serverový modul; popis je tu kvôli histórii a čo sa
zmenilo, hovorí odsek nižšie)*: obsah (položky + sety) prevzala sekcia `hw` Štúdia a modul dostal druhý vstup — uzavretý whitelist `SECTION_ACTIONS` + `dispatch(name, payload,
sink)` + `with_client(sink)` (`ensure` je povinné — visiaci sink by zdedila nasledujúca, aj asynchrónna odpoveď). Telá handlerov sa NEPRESÚVALI a modul sa NEPREMENOVÁVA (vzor audit
#21 zo ŠT-2a).

**`ready` v whiteliste ZÁMERNE NIE JE:** Štúdio registruje callbacky pod tými istými menami, takže by prepísal jeho vlastný `ready` a okno by prestalo dostať prvý push — prvotný
stav sekcie preto nesie `push_state` pod kľúčom `hw`.

**V whiteliste NIE SÚ ani tri MODELOVÉ zápisy** (`hws_map_project`, `hws_merge_seed`, `hws_reset_project`): v pohľade Sety sa blok „Predvoľby projektu" zobrazí READ-ONLY
(`HWS_PROJ_RO` v `hw_sets.js`, hodnota je vypísaná — výstup nikdy nevyzerá ako vstup) a zapisovacie ovládanie nahrádza premostenie **„Upraviť v okne Katalóg kovania…"**
(`hw_open_window` → `HW_BRIDGE_STATUS`, vzor `MAT_BRIDGE_STATUS`; D-78 — tlačidlo nie je mŕtve, vedie tam, kde obsah naozaj je, a status prizná dávku ŠT-3a-2, ktorá ho presunie).

**Adresát odpovede:** `with_client(sink)` na čas jedného synchrónneho volania, mimo neho vtedy OKNO (`win_js`, dnes už `studio_js`); **asynchrónny beh si adresáta pamätá sam**
(`run_target`) — pre okno platil pôvodný okno-guard (`@dialog.equal?(dlg) && visible?`, dnes zanikol), pre sekciu SESSION TOKEN `@section_session`, ktorý zhasína zatvorenie Štúdia
(`on_ui_closed`), prepnutie dokumentu (`on_model_changed`) a ODCHOD zo sekcie (`cancel_runs_on_leave` z `hw_leave`; odchod počas behu ho zruší a **povie to statusom** — obe cesty
preč zo sekcie, klik v navigácii aj deep-link, volajú ten istý hook). Generačné počítadlá `@gen` (cena) a `@demos_gen` (náhľad) boli vtedy SPOLOČNÉ pre okno aj sekciu vedome —
server drží JEDEN cenový návrh per kód a JEDEN proposal store, takže dva súbežné behy by si aj tak siahali na to isté (od ŠT-3a-2 je klient už len jeden).

**OPRAVA nálezu auditu:** `after_sets_change` volalo `StudioDialog.on_model_changed(model)` — to je vetva PREPNUTIA DOKUMENTU (prevesí observer, zdvihne `@mat_full_pending`); dnes
ide `StudioDialog.refresh_if_open(bump: !model.nil?)` — knižničný zápis bez zdvihu generácie, modelový zápis predvolieb projektu so zdvihom.

**ŠT-3a-2 z tejto cesty odstránila aj `push_sets`** — sekcia dostáva sety plným pushom, panel `Panel.push_hardware_sets` ostáva. `push_items(refresh_studio: true)` posielal okno +
echo sekcie + plný push Štúdia `bump: false` (vetva okna od ŠT-3a-2 zanikla) (ceny kovania vstupujú do ROZPOČTU, identita riadkov sa nemení); jediný volajúci s `refresh_studio:
false` je `price_refresh_after_proc`, ktorý `push_state` robí sám.

**Zotavovacia obnova setov (review P1 #1):** `hws_save_set`/`hws_delete_set` sú v `SECTION_ACTIONS`, takže odmietnutý zápis (`:conflict`, `:not_found`, neznáme zlyhanie) musí
obnoviť OBE UI — vlastná cesta `resync_sets` (okno `win_js` + sekcia `StudioDialog.push_hw_sets` → `NX.setHwSets`, jeden `sets_payload`, **bez** zdvihu generácie a **bez** plného
pushu — nič sa nezapísalo). Bez toho by hláška tvrdila „obnovené", ale sekcia by držala starú `revision` a zacyklila sa v konfliktoch. `push_sets` ostal cestou po ÚSPEŠNOM zápise
(okno; sekcia dostáva sety plným `push_state`, lebo menia aj nákupný zoznam).

**Príznak bežiaceho behu sekcie zhasína aj vtedy, keď výsledok nemá komu prísť** (review P2 #3 + kolo 2): príznak nesie **identitu behu** — `mark_running` vydá monotónne `run_id` a
`clear_running(target, id)` zhasne **len pri jeho zhode**, takže prekonaný beh nezhasne príznak živého a beh zabitý konkurenčnou generáciou sa uprace tiež; výslovné
`hw_demos_cancel` gasí zámerne bez identity (ruší to, čo v sekcii práve beží). Bez toho by odchod zo sekcie vypísal falošné „Zrušené: …" po behu, ktorý dávno skončil.

**ŠT-3a-2 — `hardware_catalog_dialog.rb` už NIE JE OKNO** (ostal serverový modul; obsah je sekcia `hw` Štúdia): `hardware_catalog.html`, `UI::HtmlDialog`, `DLG_KEY`,
`ensure_dialog`, `show`, `register_callbacks`, `win_js` aj okno-guardy asynchrónnych behov sú PREČ. `run_target` nesie už len **session token** zachytený pri ŠTARTE behu (ABA),
identitu behu drzí `run_id` v `mark_running`/`clear_running`. `push_sets` (win-only echo) **zanikol a všetkých päť** jeho volaní v zotavovacích vetvách modelových handlerov prešlo
na `resync_sets` — odmietnutý zápis musí obnoviť UI, ktoré oň požiadalo, a to je už len sekcia. `js` bez sinku padá na `studio_js`.

**Vetva `HardwareCatalogDialog.on_model_changed` v `scale_observer` OSTÁVA** (precedens `MaterialsDialog`) — telo už nerobí refresh UI (ten robí Štúdio plným pushom), ale MUSÍ
zneplatniť bežiaci serverový beh: bez toho by výsledok sťahovania z Demosu dobehol do NOVÉHO dokumentu s dátami starého. `sets_payload(model)` berie model ARGUMENTOM (pri prepnutí
dokumentu by inak sekcia dostala predvoľby starého dokumentu vedľa kusovníka nového). Osirotený `preferences_key` `noxun_engine_hw_catalog_v1` v registri používateľa ostáva — je to
zapamätaná veľkosť okna, ktoré už neexistuje, a SketchUp ho nikdy nepoužije (precedens `NoxunEngineProduction`).

**ŠT-3a-3 — undo kontrakt modelových zápisov má JEDNU cestu zatvorenia operácie** (`abort_open_operation`): všetky tri handlery si držia príznak `op[:open]` a `rescue` ruší
**výhradne operáciu, ktorú handler otvoril a ešte nezavrel**. Bez toho nechala výnimka medzi `start_operation` a `commit_operation` operáciu OTVORENÚ (ďalší zápis by sa do nej
pribalil a jeden krok Späť by vrátil OBA), a bezpodmienečný `abort_operation` v `handle_merge_seed` mohol naopak zrušiť zápis, ktorý už bol commitnutý.

**Odmietnutý `reset_project` ide na `resync_sets`**, nie na plný push — nič sa nezapísalo.

### rules_dialog.rb

**`rules_dialog.rb` — od ŠT-3b-1 už NIE JE OKNO** (ostal serverový modul; obsah je sekcia `rules` Štúdia, popis ďalej v odseku `hardware_rules`).

**ŠT-3b-1 — `rules_dialog.rb` už NIE JE OKNO** (ostal serverový modul; obsah je sekcia `rules` Štúdia): `rules.html`, `UI::HtmlDialog`, `DLG_KEY`, `ensure_dialog`, `show`,
`register_callbacks` aj `push_state` sú PREČ; `js` bez sinku padá na `studio_js`.

**Vetva `RulesDialog.on_model_changed` v `scale_observer` ZANIKLA** — a to je rozdiel oproti `MaterialsDialog`/`HardwareCatalogDialog`, ktorých vetvy ostali: tento modul nemá
**žiadny asynchrónny beh**, takže po prepnutí dokumentu nie je čo rušiť — sekciu obslúži plný push Štúdia z toho istého broadcastu (`rules_payload` dostane PODANÝ model). Vstupné
body: menu „Pravidlá kovania" → `StudioDialog.show(open_section: 'rules')`, tlačidlo panela → `openStudio('rules')`; `open_rules` (panel.rb) aj `openRulesDialog` (hardware.js) sú
preč. Osirotený `preferences_key` `noxun_engine_rules` v registri používateľa ostáva — zapamätaná veľkosť okna, ktoré už neexistuje (precedens `NoxunEngineProduction` a
`noxun_engine_hw_catalog_v1`).

**`ui/js/rules.js` sa NEDAL presunúť 1:1** — definoval globálne `el` a `esc`, teda PRESNE tie, ktoré má `studio.js`; v spoločnom okne by si prepísali cudziu funkciu a padlo by
niečo úplne iné než pravidlá. Celý súbor je preto prefixovaný `rd*`/`RD_*` (vzor `bud*`, `mdh*`), PRIJÍMAČE `RD.init`/`RD.setRules`/`RD.setStatus` si mená PONECHALI (jedna pravda o
mene kanála) a `sketchup.ready` z neho zaniklo.

### supplier_settings_dialog.rb

**`supplier_settings_dialog.rb` — od ŠT-4a už NIE JE OKNO** (ostal serverový modul; obsah sú TRI sekcie Štúdia):
`supplier_settings.html`, `js/supplier_settings.js`, `UI::HtmlDialog`, `DLG_KEY`, `ensure_dialog`, `show`, `register_callbacks` aj `push_state` sú PREČ a modul sa **NEPREMENÚVA**
(audit #21).

**Čo edituje:** GLOBÁLNE nastavenia aktívneho dodávateľa (`%APPDATA%\NOXUN\Engine\supplier_settings.json`) — sadzby služieb, režimové hodnoty €/€€/€€€, štandardné koncové riadky,
prah veku cien, krok zaokrúhlenia; do zákazky sa **nemrazia** (rozpočet je pohyblivý obraz cien).

**Uzavretý whitelist `SECTION_ACTIONS = ss_save · ss_reload`** — mená sú prefixované zámerne: `save`/`reload`/`ready` sú príliš všeobecné na to, aby žili v JEDNOM priestore
callbackov okna vedľa akcií ostatných sekcií (`ready` by dokonca prepísal vlastný callback Štúdia).

**Baseline revízia prežila presun** (optimistický zámok): payload nesie `revision` aktívneho dodávateľa, uloženie ju vracia a nezhoda = odmietnutie + načítanie nanovo — nikdy tichý
prepis cudzej zmeny.

**Klient posiela revíziu PRIPNUTÚ na stav, nad ktorým sa začalo písať** (`SS_BASE_REV`, review #227 P1): plný push chodí pri každej zmene modelu a `SS_STATE.revision` s ním
omladne, takže bez pinu by zámok prešiel a cudzia zmena (druhá inštancia, ručný zásah do súboru) by zmizla bez slova.

**Pin sa berie UŽ PRI FOKUSE poľa** (`focusin`), nie pri prvom písmene (review #227 kolo 2): fokus ZMRAZÍ zobrazený obsah (telo sa neprekresľuje), takže push, ktorý medzitým
dorazí, vymení `SS_STATE` pod starými hodnotami — pripnutie až pri prvom písmene by teda pripútalo NOVÚ revíziu k STARÉMU obsahu a zápis by prešiel. Push pin **neprepisuje**;
uvoľní ho `SS.saved()` (potvrdenie, odmietnutie, reload) — **a tiež prekreslenie tela z čerstvého stavu, keď pin NIKTO NEVYUŽIL** (review #227 kolo 3, dorovnané dávkou 1b-1): keď nie je
nič rozpísané, obsah sa prekreslí z čerstvého stavu, takže držať starú revíziu by znamenalo **falošný konflikt** nad hodnotami, ktoré používateľ vidí — a zahodenú prácu
(`SS.saved()` rozpis pri odmietnutí zahadzuje). Kontrakt kola 2 tým ostáva nedotknutý: **pod kurzorom je obsah zmrazený a pin sa drží**, takže cudziu zmenu nemožno ticho prepísať.

**Uvoľňuje sa v `ssRenderBody`, nie v `ssApplyState`** (oprava dlhu 1b-A, PLAN blok 1b odrážka A): pin patrí k OBSAHU NA OBRAZOVKE, a ten sa prekresľuje aj **bez nového pushu** —
odchod zo sekcie a návrat cez `studioGoSection` → `render` → `renderBody`. Kým kontrola žila v ceste pushu, prežil zastaraný pin práve túto cestu (fokus nezmeneného poľa → cudzia
zmena a push, prekreslenie potlačené → odchod a návrat) a sekcia potom ukazovala čerstvé hodnoty, ale ukladala proti starej revízii: **falošný konflikt a stratená editácia**.
Miesto uvoľnenia je **jedno jediné** — riadok tesne pred `box.innerHTML = ''`, teda za strážou `ssTyping()`; podmienka je preto len `!ssDirty()`. Je to zámerné: posun uvoľnenia
PRED tú stráž (predtým sémanticky ekvivalentná mutácia, ktorú držal len tvarový guard) dnes zhodí behaviorálny test „pod kurzorom pin ostáva".

**Odmietnutie rozpísané hodnoty ZAHADZUJE** (`SS.saved()` pred `refresh_studio` — presne ako to robilo okno): bez toho by prežili push, prekryli čerstvé čísla a druhý klik by ich
ticho prepísal, hoci hláška hovorí „formulár je načítaný nanovo" — hláška a správanie sa musia zhodovať; baseline sa obnovuje **až pri úspešnom zostavení payloadu** (lekcia
ŠT-3b-2c2 B4 — inak by sa server a klient rozišli a každé ďalšie uloženie by sa navždy odmietalo).

**Validácia je serverová** (`SupplierSettings.patch_active!`, all-or-nothing).

**Po úspešnom zápise sa Štúdio PREPOČÍTA** so zdvihom generácie — sadzby sú **vstup** rozpočtu, nie jeho mutácia; in-SU dôkaz je zmena súčtu automatických služieb, nie prítomnosť
volania.

**Hláška sa VETVÍ podľa výsledku prepočtu** (`refresh_and_report`, oprava dlhu 1b-A): zápis do súboru a obnova obrazovky sú DVE veci. Plný push môže zlyhať (výnimka pri
zostavovaní payloadu, `execute_script` do okna, ktoré ešte neohlásilo `ready`) a keďže `SS.saved()` už rozpis zahodil, na obrazovke vtedy ostanú STARÉ čísla — „Rozpočet je
prepočítaný." by nad nimi bolo klamstvo. Zlyhanie preto povie pravdu („Nastavenia sú ULOŽENÉ, ale rozpočet sa NEPREPOČÍTAL… klikni na Obnoviť") a je červené. To isté platí pre
**odmietaciu** vetvu (tvrdí „formulár je načítaný nanovo") aj pre **`handle_reload`**. `refresh_studio` preto vracia BOOLEAN „klient to naozaj dostal" — nedostupné `StudioDialog`,
zavreté okno aj zachytená výnimka sú `false`. *Zamietnutá alternatíva: samostatné echo nastavení po zápise — potrebovalo by nový klientsky prijímač a čísla rozpočtu by aj tak
ostali staré, takže by hláška o „prepočítanom rozpočte" klamala ďalej.*

**JEDEN payload nesie všetky tri sekcie** (`sup`/`bset`/`about`) — sú to tri pohľady na ten istý malý dokument a model nepotrebujú (globálne, ako šablóny).

**`bset`** je presun formulára 1:1.

**`sup` (Dodávateľ / Demos) vedome NEMÁ ani jedno editovateľné pole:** väzba na Demos žiadne nastavenia nemá (verejný cenník — žiadne prihlásenie, žiadne cenové pásmo, žiadna DPH:
firma je neplatca a katalógové ceny sú konečné), odstup dotazov je KONŠTANTA slušného správania (`DemosClient::CRAWL_DELAY_S`) a väzba je vlastnosť konkrétneho dekoru/kovania.
Sekcia preto ukazuje STAV a **vedie** tam, kde väzba naozaj žije (deep-linky `studioGoSection` do Materiálov a Rozpočtu) — vymyslené polia by sľubovali nastavenia, ktoré
neexistujú; **vedomá odchýlka od wireframu mockupu**, ktorý kreslí cenové pásmo aj DPH.

**Klient (`ui/js/studio_settings.js`) sa proti oknu zmenil v troch veciach:** (1) rozpísané hodnoty **prežijú plný push** a zanikajú výhradne na potvrdenie servera `SS.saved()` — v
okne push chodil len pri otvorení a po uložení, v Štúdiu chodí pri každej zmene modelu, takže pôvodné „init = reset formulára" by ticho zahodilo rozpísané sadzby; (2) telo sa
**neprekresľuje, kým používateľ píše** do jeho poľa; (3) kreslí sa LEN do práve otvorenej sekcie (`#secbody`/`#sectools` sú zdieľané uzly — lekcia review #225 P1); (4) **`settings:
nil` je SIGNÁL, nie „nič nové"** (review #227 P2): keď server payload nevie zostaviť (chyba disku), sekcia prejde do chybového stavu, formulár skryje a povie to — formulár, ktorý
vyzerá aktuálne a aktuálny nie je, je horší než hláška; nad neznámym stavom sa navyše nedá **uložiť**, ale **„Načítať nanovo" v lište OSTÁVA** (review #227 kolo 2) — je to jediná
cesta, ako sa z prechodnej chyby disku zotaviť bez zatvorenia Štúdia, a hláška v tele na ňu odkazuje menom.

Rozlišuje sa PRÍTOMNOSŤ kľúča `settings`, nie pravdivosť hodnoty.

**⚙ v lište Rozpočtu** už neotvára okno: je to čisté klientske `studioGoSection('bset')` a serverová cesta `ProductionCore.open_budget_settings` aj callback `budget_settings`
zanikli. Vstupný bod menu „Nastavenia rozpočtu" ostáva ako zaužívaná skratka, ale vedie na `StudioDialog.show(open_section: 'bset')`. Osirotený `preferences_key`
`noxun_engine_supplier_settings` v registri používateľa ostáva (precedens `NoxunEngineProduction`, `noxun_engine_hw_catalog_v1`, `noxun_engine_rules`, `noxun_engine_templates`).

### ui/js/about.js — „O plugine"

**„O plugine" (`ui/js/about.js`) je JEDEN OBSAH s DVOMA VSTUPMI** (kontrakt Š19): markup stavia zdieľaný builder `nxAboutHtml(info)`, ktorý načítava panel.html aj studio.html —
koliesko Inspectora má už len prázdneho hostiteľa `#cfgAbout` a plní ho `NX.init` (`nxAboutFill`), sekcia `about` ho plní z payloadu.

Dáta (verzia + priečinok nastavení) dáva VÝHRADNE server — do ŠT-4a stála cesta `%APPDATA%\NOXUN\Engine` v HTML natvrdo. Kópia markupu by sa pri prvej úprave rozišla a používateľ
by videl dva rôzne „O plugine". Tri pravidlá `.aboutrow`/`.aboutlogo`/`.aboutname` sa preto v `css/panel.css` **odscopovali z `.nx-inspector`** — v Štúdiu (root bez tej triedy) by
sa obsah inak rozsypal.

**Vedomá odchýlka od wireframu mockupu:** licencie tretích strán a diagnostika (`Debug.report`) sa **nepridávajú** — v koliesku dnes nie sú, takže by to nebolo zrkadlo, ale nový
obsah v oboch vstupoch (patrí do vlastnej dávky).

### Veľkosť okna pri otvorení (D-77)

`width`/`height` v `HtmlDialog.new` platia **len pri prvom otvorení** — potom rozhoduje veľkosť zapamätaná pod `preferences_key`, a `min_width`/`min_height` bránia iba ručnému
zmenšovaniu. Okno, ktoré raz ostalo malé, sa preto otváralo odseknuté donekonečna. Každé okno má v HTML deklarované **obsahové minimum** `window.NX_FIT_MIN` a `ui/js/win_fit.js` po
načítaní zmeria viewport; keď je menší, pošle `nx_fit` a `Engine.register_dialog_fit` (main.rb — od UI-01 spoločný boot hook okna, registruje aj `nx_theme`) okno cez `set_size`
dorovná. Dorovnáva sa **oboma smermi**: **nahor po deklarované minimum** a **nadol po dostupnú plochu obrazovky** — okno zapamätané z väčšieho monitora (alebo po znížení
rozlíšenia/DPI cez remote desktop) je inak orezané obrazovkou, čo je tá istá choroba (Codex #164 P2).

**Plocha má prednosť pred minimom** (nikdy nad ňu — na malej ploche je stropom plocha, aj keď je menšia než minimum); **medzi minimom a plochou sa nesiaha na nič** (veľkosť okna v
tomto pásme je vedomá voľba používateľa) a fit beží **len raz pri načítaní**, nie pri zmene obsahu (okno by pod rukami skákalo). Keď plocha nie je známa, okno sa smie len zväčšiť.
Rámik okna sa dopočíta z rozdielu outer/inner, aby sa fit pri ďalšom otvorení neopakoval. JS je len merač — hodnoty mimo 240…2600 px Ruby zahodí. Čisté jadro je testované
(`tests/js/test_d77_okno_fit.js`).

**D-51 (UI-B1):** jedna pravda je **obsahový** viewport v `NX_FIT_MIN`; rozmery `HtmlDialog.new` sú **vonkajšie** (obsah + rámik okna) a musia mu zodpovedať — pre Inspector obsah
**470 × 810** ⇒ `width/height 486 × 850`, `min_width 486`. Trojica je zapísaná v `docs/UI_DIZAJN.md` (tabuľka D-51) a stráži ju `tests/pure/test_uib1_kostra.rb`.

## Ostatné

### CONSTRUCTION_FIELDS

Jediný zoznam polí = `CONSTRUCTION_FIELDS` v core.js ↔ `Panel::PARAM_KEYS` (nové pole na 1+1 mieste).

### Trvalé UI pravidlo (Michal 20.7.2026): VERTIKÁLNY priestor panela je vzácny

pred každým novým tlačidlom/poľom/riadkom POVINNE zvážiť umiestnenie do existujúceho radu, rohu náhľadu, ikony či kontextu; rast do výšky len v krajných prípadoch.

### usage_stats.rb

_(zatiaľ nezdokumentované — doplniť pri najbližšom zásahu)_

Merač D-25 (počítanie klikov v UI, `ui/js/usage.js`) — zmienky sú v odseku o klikateľnosti a deep-linkoch a v odseku `templates.rb`.
