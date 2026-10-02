# UI — Inspector, Štúdio a lifecycle okien

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Údržba:** dávka, ktorá mení sekciu, kontext alebo modul, prepíše **JEHO odsek na mieste** — nikdy append na koniec súboru.
> Odsek opisuje **aktuálny kontrakt a pasce**, nie priebeh prác: čísla PR, kolá review, verzie a zaniknuté riešenia patria do
> [../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md). Súbor má strop veľkosti a historické značky smú stáť len v sekcii
> **„História"** na konci (stráži `tests/pure/test_docs_navigacia.rb`).
> **Plné pôvodné znenie (pred upratovaním H5a)** — každá pasca s dôvodom, priebeh dávok, review kolá, zaniknuté okná — je v archíve
> [../../SYSTEM/archiv/UI_LIFECYCLE_historia_do_v0.17.md](../../SYSTEM/archiv/UI_LIFECYCLE_historia_do_v0.17.md) pod **rovnomennými
> alebo pôvodnými nadpismi** (odsek nižšie ho menuje). Číta sa len Grepom, keď treba „prečo je to takto".

Dve okná pluginu — **Inspector** (`panel.html` + `panel.rb` + `ui/panel/*.rb`: čo je označené a čo s tým) a **Štúdio** (`studio.html` +
`studio_dialog.rb`: celá zákazka v 14 sekciách) — ich kostra, kontexty, karty, sekcie, zdieľané JS komponenty a životný cyklus. Tretím
HtmlDialogom je len malý **Z-dialog** nástrojov (`Tools::ZDialog` v `mower.rb`). Pri KAŽDEJ UI práci sa k tomuto súboru povinne číta
[../UI_DIZAJN.md](../UI_DIZAJN.md) §1–§3.

**Mapa súboru (Grep podľa nadpisu):** zdieľané komponenty (`### Paleta a téma`, `### Zdieľaný combobox`, `### D-15 modal`, `### Escape reťaz`) ·
nástroje (`### tools.rb` …) · Inspector (`### Inspector — kostra`, `### Kontext Korpus`, `### Kontext Zóny`, `### Kontext Čelá`, `### Kontext Kovanie`,
karty) · súbory Inspectora (`### panel.rb`, `### payloads.rb`, `### actions_*.rb`) · Štúdio (`### studio_dialog.rb`, `### Sekcia <NÁZOV> v Štúdiu`
pre všetkých 14 sekcií + serverový modul sekcie `### <súbor>_dialog.rb`) · lifecycle okien (`### Veľkosť okna pri otvorení`, `### updater.rb`) ·
`## História`.

## Vrstva UI a zdieľané komponenty

### Súbory UI vrstvy

`panel.rb` (centrálne callbacky Inspectora) + `ui/panel/*.rb` domény + `studio_dialog.rb` (Štúdio) + `ui/js/*.js` moduly + zdieľaný `ui/css/panel.css`.
Serverové moduly sekcií Štúdia nesú historické mená `*_dialog.rb` — vlastné okno už nemajú (sekcia „História").

### Dizajn

Tokeny `--nx-*` (farby VÝHRADNE cez tokeny; `--nx-state-*` len semafor sekcie Kontrola, nemiešať s ABS/status významami) · `ui/js/icons.js` inline SVG sprite
(Lucide subset + vlastné + firemné logo `#i-logo`; licencie v THIRD_PARTY_NOTICES.md) · **žiadne emoji v UI chrome — vždy sprite ikony** ·
**komponentový rádius 6 px** · pravidlá: `docs/UI_DIZAJN.md` — **čítať pri KAŽDEJ UI práci**.

### Paleta a téma (UI-01)

Výber/aktívny stav nesie firemný **NOXUN teal** (`--nx-select…`, `--nx-part-border/bg` = **výberová rodina**); primárna akcia zostáva zelená. Kreslené farby 2D
náhľadu (`preview.js`) sú **zrkadlom** týchto tokenov — SVG atribúty nevedia `var()`, takže zmena tokenu je zmena na dvoch miestach (vzor `EdgeCheck::COLORS`).

**Téma** (`noxun` | `lucia`) prepína **VÝHRADNE výberovú rodinu** — danger/warn/ok/ABS/edge/semafor sa ňou nikdy nemenia. Žije v
`%APPDATA%\NOXUN\Engine\ui_theme.json` (**nikdy v .skp** — Michal a Lucia otvárajú tie isté zákazky); whitelist a fallback na `noxun` sú v Ruby
(`Engine.normalize_ui_theme` / `get_ui_theme` / `set_ui_theme` v main.rb) a zrkadlovo v JS (`nxThemeName`).

- **Do okna** ide cestou fitu: okno si ju po načítaní HTML vypýta (`sketchup.nx_theme()` v `ui/js/win_fit.js` — jediný skript načítaný VO VŠETKÝCH oknách;
  `execute_script` pred `show` nefunguje) a Ruby odpovie `nxThemeApply(<meno>)`. Callback registruje spoločný boot hook `Engine.register_dialog_fit`,
  takže nové okno tému dostane automaticky. `nxThemeApply` pred nasadením ZHODÍ všetky témové prepisy (návrat na `:root`).
- **Prepínač** žije v koliesku raily: `nx_set_ui_theme` → `Engine.apply_ui_theme` = uloženie + **`broadcast_ui_theme` do VŠETKÝCH otvorených okien**
  (register `Engine.register_dialog_theme`). Zoznam sa **čistí pri každej registrácii aj rozoslaní** (`prune_theme_dialogs` — zavretý dialóg ani jeho
  closure sa nedrží) a okno sa **prihlási znova pri `nx_theme`** (pred `show` ešte nie je `visible?`).
- Panel si tému **nedrží ani nenasadzuje** — farby nasadzuje výhradne `nxThemeApply`, JS len číta `data-nx-theme` z koreňa (aktívne tlačidlo).

### Zdieľaný combobox materiálov a ABS (D-85 / UI-03, ui/js/nx_combo.js)

**Čo robí:** JEDEN vyhľadávací výber dekoru a ABS pásky pre celý plugin — Inspector (telo/čelá/chrbát `cab_*`, materiál dielca `pcMaterial` + 4 hrany,
materiál dosky `bc_material` + 4 hrany, vkladací `ib_material`) aj Štúdio (predvoľby projektu `md_body`/`md_front`/`md_back` v sekcii Materiály,
`data-nx-combo="decor"`, pripája ich `scan` po každom `fillSelect`). Okno sekcie Materiály má na editáciu katalógu vlastný suggest (`#mdSgBox`).

**Kontrakt:**
- `<select>` **NENAHRÁDZA — obaľuje ho**: select ostáva v DOM (skrytý ATRIBÚTOM `data-nx-combo`, nie triedou — panel prepisuje `className` pri override `ovr`)
  a je **jediným zdrojom pravdy**. Možnosti sa čítajú z jeho `<option>`/`<optgroup>` (hrúbkové filtre D-45, ABS skupiny, serverové texty „(podľa pravidla — …)",
  dupláky D-49, `disabled` „(nekompatibilné)" platia bez duplikátu) a výber ide **cestou natívneho kliku** — `sel.value` + `dispatchEvent('change')`. Preto
  platia nezmenené všetky guardy na `change` (E-03 hrúbka a D-86 smer dekoru vo vkladacej karte, D-41 modal chýbajúcej pásky, identita `cabinet_id`/`board_id`,
  potvrdzovacia lišta D-46 a `model_guid`).
- **Programové vrátenie hodnoty** (pending) `change` nespúšťa → volá sa most **`NXCombo.sync(sel)`**, inak by trigger ukazoval neplatnú hodnotu.
- „Je pole obsluhované?" = `nxFieldBusy` = **fokus ALEBO otvorený popup** — živý refresh katalógu (`refreshInsertBoardMaterials`) nesmie prekresliť ponuku
  pod rukami. Synchronizácia triggera: **`MutationObserver`** na `childList` selectu + **explicitné `nxComboSync()`** na konci každého renderu karty
  (zmena samotnej `value`/`disabled` observer nespustí).
- **„Použité v projekte"** je odvodený zoznam ID zo servera (`Materials.used_material_ids` / `used_abs_ids` mínus zdroje globálnych šablón — čisté čítanie,
  žiadny zápis). Panel: v `materials_payload.used_ids` a **na vyžiadanie pri otvorení ponuky** (`sketchup.nx_used_ids()` → `Panel.push_used_ids` →
  `NX.setUsedIds`, vymení len zoznam). **Pull, nie push** — plný scan modelu do horúcej cesty `push_selected` nepatrí (guard test). Štúdio: hotový zoznam
  `StudioDialog#mat_used_ids` → `mat.used_ids` z **už zozbieraného kusovníka** (`collected[:records]`, žiadny druhý prechod; dielec bez `owner_id` sa
  nevyhadzuje — otázka je „je materiál v zákazke?").
- Farbu štvorčeka dáva hostiteľ resolverom (`nxComboColorOf` — katalógová farba je pole `[r,g,b]` → `nxRgbHex`; ABS podľa hrúbky); do `style` ide len hex.
  „Naposledy použité" = `localStorage` počítača (`nx_recent_decor`/`nx_recent_abs`, max 5, len ID).
- **Sync zvonka** (serverový push cez `scan`, prestavba `<option>`ov, odchod z okna) otvorený popup **ZAVRIE** — inak by klik potvrdil voľbu starého kontextu.
  Popup je `position: fixed` nad `body` (nič ho neoreže), výber `mousedown`-om (`blur` by ho zavrel skôr); `<datalist>` v CEF nefunguje.
- **Šírka ponuky** = `nxComboPopWidth(fieldW, viewportW)`: obsahová šírka okna, strop čitateľnosti **620 px**, nikdy užšia než pole; položka nesie celý
  názov aj v `title`.
- **Perzistentné telo sekcie Štúdia:** odpojené pole `scan` nielen odregistruje, ale **rozbalí** (`detach` — tlačidlo preč, select späť na miesto obalu);
  inak by návrat obalil ten istý select druhýkrát. Sekcia Materiály `scan` nespúšťa, kým je telo odpojené.

**Riadok = dekor, hrúbka = čip.** Varianty toho istého dekoru a **typu dosky** sa zlučujú do jedného riadku s čipmi hrúbok (`18 | 36 | 36 duplák`):
- **Hranicu rodiny určuje katalóg, nie klient:** server posiela **`row_key`** (`Materials.variant_family_key` = kanonická `record_group_key` · dekor · štruktúra ·
  typ · prípona formátu a rubu; všetky zložky kanonické bez ohľadu na veľkosť písmen; UNI záznamy sa nezlučujú) a menovku **`row_label`**
  (`Panel.sheet_row_label`). Dekor + typ nestačí — rovnaké číslo dekoru u dvoch výrobcov či formát v identite by dali dva nerozlíšiteľné čipy s cudzou cenou.
  Bez `row_key` (starší payload) sa padá na dekor + typ; **čip nikdy nezmení typ**. Detail kľúča: [materials.md](materials.md).
- **Rozdelené riadky sú pomenované rozdielne:** `Materials.row_label_disambiguated` nad `Materials.row_family_ctx` (raz na payload) pridá pri kolízii **typ**
  a **hrúbku len keď ju riadok neukáže čipmi**; kontext počíta aj s **virtuálnymi duplákmi** (`virtual:` z tej istej autority ako `duplak_offers`). Pravidlo
  žije v CORE — klient vidí len to, čo je v selecte.
- Zoskupenie robí čistá `nxComboDecorRows(items, meta)`; metadáta variantu (`decor · type · thickness · duplak`) dodáva hostiteľ cez `setVariantResolver`
  (Inspector `nxComboVariantOf` nad `sheetRecOf`, Štúdio nad `MD_SHEETS`); bez resolvera ponuka nezoskupuje. **ABS sa nezoskupuje.**
- **Duplák má dva tvary:** virtuálna ponuka `duplak2:<zdroj>` a uložený záznam s bežným `material_id` rozpoznaný VÝHRADNE podľa `source_material_id` —
  payload ho zrkadlí ako `duplak` a oba hostitelia čítajú `rec.duplak === true` (`MD_SHEETS` surové `source_material_id` nemá). Čip nesie aj hrúbku
  („36 duplák" / „54 duplák"); hľadanie hľadá zhodu hrúbky najprv **medzi duplákmi**.
- **Predvolená hrúbka je vec kontextu** (`data-nx-combo-ctx`: `body`/`front` → najtenšia konštrukčná podľa katalógu · `back` → 3 · `worktop` → 38; chýbajúca
  = najtenšia konštrukčná) a **duplák sa nepredvolí NIKDY**. Prednosť pri kreslení riadku: **dotaz menujúci konkrétny variant (ID alebo label,
  `nxComboVariantFromQuery`) → výslovný dotaz o hrúbke → kliknutý čip (`OPEN.chip`, prežije prekreslenie po písmene) → hodnota selectu → kontext**.
- **Kontext radí aj riadky:** `nxComboSortByCtx` (stabilné radenie podľa `nxComboCtxRank`, beží pred delením na sekcie; sekcia „Naposledy použité" dostáva
  `ctx` až v `nxComboSections`, čerstvosť je tie-breaker) a `nxComboFirstCtx(items, ctx, q)` = kurzor po dopísaní dotazu: **riadok s hrúbkou, ktorú dotaz
  menuje → riadok podľa kontextu → prvý vyberateľný** (číslo dekoru hrúbku nemenuje). Bez kontextovej hrúbky sa poradie servera nemení. Nekontextové riadky
  sa **nefiltrujú** (semafor varuje, neblokuje).
- **Zlúčenie nič neschová:** `searchExtra` nesie hrúbky, slovo „duplák" a `value` aj `label` každého variantu; členstvo v skupinách „Použité v projekte" /
  „Naposledy použité" cez **všetky** varianty (`nxComboRowIds`) a predvolenú hrúbku nemení. Klik na čip je **zúženie, nie výber** (`preventDefault` +
  `stopPropagation`, ponuka ostáva otvorená, do selectu nič, prekreslí sa len riadok — `redrawRow`).
- **Nedostupný variant je `aria-disabled`, nikdy `disabled`** (vzor D-78): klik dopíše dôvod pod čipy (`.cbchipmsg`, serverový label; `.cbopt { flex-wrap: wrap }`).
  Klávesnica: **šípky vľavo/vpravo** (`moveChip`, fokus ostáva v hľadaní, na krajoch sa necyklí); nedostupný čip prvé stlačenie **zastaví a oznámi**
  (`announceChip`, `role="status" aria-live="polite"`), druhé pokračuje.
- **Výsledkom voľby je `material_id` konkrétneho variantu** — serverové cesty ani E-03 (hrúbku určuje reálny materiál) sa nemenia.

Testy: `tests/js/test_ui03_combobox.js`, `tests/pure/test_ui03_combobox.rb`, `tests/js/test_picker2_chips.js`, `tests/js/test_picker2_chips_dom.js`,
`tests/js/test_picker3_kontext.js`, `tests/js/test_picker3_kontext_dom.js`, `tests/pure/test_picker2_used_ids.rb`, `tests/pure/test_picker3_rodina.rb`.
Vzhľad: mockup `SYSTEM/zdroje/ui20/mockup_inspector_c.html` + `docs/UI_DIZAJN.md`. Plné znenie: archív, rovnomenný odsek.

### D-15 modal — zdieľaná kostra „pridávačiek" (ui/js/nx_modal.js)

**Čo robí:** JEDNA kostra všetkých okien typu „pridaj / uprav niečo" v oboch oknách (`window.NXModal` + `module.exports`): `mhead` (titulok + podtitul + ×) ·
`mbody` (polia) · `mfoot` (Zrušiť + **zelené** potvrdenie). **Esc aj klik na scrim zatvárajú**, fokus ide do prvého poľa (alebo `initialFocus`) a pri zatvorení
sa vracia na spúšťač. Inštancie sa líšia LEN poľami (`fields` = `{key, label, type, value, placeholder, options, …}`); šírky karty `size: 'sm'|'md'|'wide'`.
Inštancie: drafty rozpočtu („Pridať položku", „Pridať spotrebič", `budDraftFields`), ⋯ editor riadku rozpočtu, D-69 editor materiálu, položka a set kovania
v katalógu (`hw:item:new`, sety), ručná položka kovania v Inspectore. CSS žije v **zdieľanom `panel.css`** (karta `.nxmcard` — `.nxmodal` je v `panel.css`
scrim starších modalov; z-vrstvy `--nx-z-scrim` / `--nx-z-suggest` pri `.nxscrim`) — `studio.html` kópiu mať nesmie. Kotva **`#nxModalRoot`** je v oboch
oknách mimo prekresľovaných sektorov; `nx_modal.js` sa načítava **za** `nx_esc.js` a **pred** `core.js`/`hardware.js`/`studio.js` (stráži
`tests/js/test_r23_escape.js`).

**Typy polí:** `text` · `select` (voliteľný tvrdý `disabled`, keď je zámok invariant — dôvod do `hint`) · `group` (nadpis sekcie formulára) · `checkbox` ·
`color` · `rows` (repeater) · `lookup` (našepkávač nad serverovým zoznamom) · `custom` (vlastný uzol volajúceho). Ploché pole smie mať **`action:`**
`{act, key, label, title}` = malé tlačidlo za vstupom (klik spracuje volajúci, `data-action`). **Pravidlo: nevratný zápis nesmie spúšťať `change`/blur —
potrebuje explicitné tlačidlo** (klik na „Zrušiť" vyvolá najprv blur poľa).

**Kontrakt `values()`:** ploché polia sú **reťazce**, `checkbox` boolean, `rows` pole hashov (čítané **z DOM**, nie zo stavu), `lookup` **LEN `value`**
zo skrytého poľa `nxm_<key>` (nikdy názov ani cena z obrazovky), `custom` to, čo vráti `read(host)` (bez `read` hodnotu nemá), `group` v hodnotách nie je.
**Identita sa nikdy neodvodzuje od kódu, ktorý používateľ práve prepisuje** — existujúce riadky nesú skryté kľúče (`material_id`, `row_rev`).
`focusables()` vylučuje `type="hidden"` a berie len `a[href]` (inline SVG `<use href>` by inak chytil Tab); `aria-disabled` prvky sa nevyhadzujú.

**Životný cyklus:**
- **`submit` modal NEZATVÁRA** — pošle hodnoty cez `onSubmit`, zatvára volajúci až po potvrdení servera (rozpočet: `NX.budgetResult(op, true)`);
  odmietnutie nechá hodnoty na mieste. Prekreslenie sekcie po zápise modal nezhodí (kotva mimo `#secbody`).
- **Zámok odoslania `OPEN.busy`:** prvý `submit` zamkne a zošedí potvrdzovacie tlačidlo, ďalšie sa zahadzujú; odomyká **výhradne volajúci**
  `NXModal.setBusy(false)` v oboch vetvách výsledku (+ poistka v `budAfterPush`). Bez neho by dvojitý Enter poslal druhú mutáciu s čerstvou generáciou.
- **`onClose`** je súčasť kontraktu: volá sa **až po skutočnom zatvorení** (`OPEN` je `null`), výnimka v ňom sa do kostry nepremietne. `open` najprv
  zatvára predchádzajúci modal → **volajúci nastavuje svoj stav až ZA `NXModal.open`**.
- **Fokus ostáva v karte** (Tab cyklí); **Escape modal spotrebuje** (`stopImmediatePropagation` — oba listenery visia na `document`); Escape handler Štúdia
  je navyše podmienený `!nxModalOpen()`. Fázové okno prepočtu cien `#budPrModal` kostru **nepreberá** (životný cyklus riadi server, vo fáze `run` sa Escapom
  zavrieť nesmie).
- **Prekreslenie modalu** (závislý select, „+ Vytvoriť…", iná sada polí) = volajúci zavolá `open` znova s tým, čo už používateľ napísal
  (`hwManualCtxSwitch`, `hwItemCtxSwitch`). Pritom: `onClose` musí vedieť, že ide o prekreslenie; podáva **`trigger:`** = pôvodný spúšťač (inak fokus
  skončí na odpojenom uzle); **`baseFields`** (polia z prvého otvorenia) + **`skipMemory: true`** (pamäť sa nevlieva späť a pás „Predvyplnené…" sa
  nerozsvieti, zápis do pamäte beží ďalej; „Začať odznova" kreslí z `baseFields`). `generation()` odlíši nový formulár aj po zatvorení — stará
  produktová odpoveď neoživí editor.

**Pamäť rozpísaných hodnôt** (drží komponent; `budDraftMemory(kind)` je len prístupový bod nad `NXModal.memory`):
- `memoryKey` = **`<okno/doména>:<mode>[:<cieľ>]`** (`bud:custom`, `bud:appliance`, `mat:edit:H3303`); slot = všetko okrem posledného segmentu, keď sú
  aspoň tri — `mat:edit:A` a `mat:edit:B` sa delia o slot a otvorenie iného dekoru starý koncept hneď zahodí (`dropForeign`).
- Pamätá sa pri odoslaní aj zatvorení, **len polia odlišné od východiskových** (`defaultsOf`/`sameValue`; `custom` cez `sameJson`). Predvyplnenie je
  **vidno** (pás `.mmemo` + „Začať odznova"). Maže **výhradne volajúci** po potvrdení servera (`setBusy(false, {clear:true})` alebo `clearMemory(key)`;
  `clearMemory` dočasne zhasne zápis `memSkip`, prvý `input`/`change` ho zapáli). Volajúci podáva **východiskové** polia (predvypĺňa kostra).
- `lookup`: rozpísaný dotaz bez výberu sa pamätá pod sufixom **`__q`** (do `values()` sa nedostane); obnovená prázdna hodnota vyčistí zobrazený text;
  východiskový text má jednu definíciu `lookupInitialQuery`.
- Editory **existujúcich** záznamov (⋯ editor riadku rozpočtu, úprava položky kovania) idú **bez `memoryKey`** — formulár sa vždy plní z čerstvého payloadu.

**`lookup`:** kostra dostane `search(query, done)` a položky `{value, text, hint}`; **písanie po výbere výber zahadzuje**, **staršia odpoveď sa ignoruje**
(`seq`), voliteľný `onPick(item)` ohlási výber (začiatok ďalšieho serverového kroku). Ponuka je vlastná vrstva (Escape zatvára najprv ju, šípky, Enter
vyberá a formulár neodošle, orezanie „… ďalších N") a je **v toku dokumentu**, nie `position: fixed` (karta má vlastný scroll). Chyba servera sadá na pole
hľadania `nxm_<key>_q`.

**`custom`:** kostra vykreslí hostiteľa `#nxmc_<key>` a zavolá `render(host, value)`; po `open`/`memReset` kreslí zo **špecifikácie**, `redrawCustom(key)` na
žiadosť volajúceho z `read()`; `f.value` sa nikdy neprepisuje (volajúci podáva kópiu stavu, napr. `hwsCloneMembers`). Chyba servera `row = "<key>:<index>"`
ide na uzol `data-nxm-row`; kliky vnútri patria delegácii volajúceho.

**Repeater `rows`:** pod-polia `cols`, tlačidlá `+`/`−` (pri `min` je `−` `aria-disabled` s dôvodom v `.mrnote`), vlastný prefix id `nxmr_`, duplicitný kľúč
sa ohlási do konzoly, delegovaný klik **nemá catch-all vetvu**. Stĺpec smie byť `readonly` podľa riadku (`roWhen`, `roTitle`; nikdy `disabled`), bunky majú
`aria-label`, hlavička nesie tú istú šírkovú triedu ako bunka (`colCls`; `mshort`/`mtiny`/`mcheckcol`).
- **`rowKey`** páruje pamäť na čerstvé riadky a pamätá **výhradne editovateľné bunky**; server-owned `row_rev` z pamäte nikdy nevylezie (`trimRowsValue` +
  `mergeRowsMemory`; riadok, ktorý v katalógu už nie je, sa zahodí).
- **Pamäť je po bunkách:** odloží sa len bunka odlišná od východiskového riadku a k nej **`_base`** (proti čomu sa písalo); `_base` sa nikdy nekreslí ani
  neodosiela (`readRows` číta len `data-nxm-col`).
- **Kolízia bunky sa nerieši ticho:** zmenil ju používateľ aj katalóg → `_conflict`, trieda **`conf`** (nie `bad`), `title` + `aria-invalid`, pás **`.mrconf`**
  s „Prevziať z katalógu" / „Ponechať moju" (`data-nxm-confcol`). **`submit` s nerozhodnutou kolíziou zápis nepustí** (`conflictCount()` > 0 → `.merrtop`).
- **Východiskové riadky (`base`) sú vždy čerstvý katalóg** — „proti čomu sa písalo" žije v stave `OPEN.flags[pole][rowKey].wrote`; štítky riadku
  (`flagsOfRows`/`applyFlags`, `_note`) žijú v `OPEN.flags`, nie v DOM, a `rowDel` volá `syncFlags(key)`.
- API: `setRows(key, rows, {base})` (zotavenie z konfliktu; `ownSpecField` rozdvojí zdieľané polia), `baseRows(key)`, `conflicts()`,
  `showErrors([{row, field, msg}])` / `clearErrors()` (`row = null` pod pole, `"<kľúč>:<index>"` pod `.mrline`, inak `.merrtop`; ďalšie volanie prepíše).

**Prekryvné ovládače vnútri karty** (`#mdSgBox`): Escape patrí najprv im (`ev.stopPropagation()` na inpute), scroll listener v **capture** fáze na `window`,
písanie našepkávač vracia; vrstvenie z jednej definície (`var(--nx-z-suggest, 80)`).

**⋯ editor riadku rozpočtu** je inštancia tejto kostry (`budMoreFields`/`budMoreAttrs` + `budOpenMore`/`budCloseMore`; spotrebič má len adresu), mutácia
`budget_mutate` → `custom_update`/`appliance_update`. **Korelácia odpovede:** tie isté operácie posiela aj inline editácia bunky, takže výsledok sa na modal
vzťahuje len pri `BUD_MORE.sent` (`budMoreAwaiting`, vrátane `NXModal.isOpen()`); `BUD_MORE` čistí `budOpenMore` a `budAfterPush`, keď modal už nie je otvorený.

Testy: `tests/pure/test_st1c_ponuka.rb`, `tests/pure/test_st2c_modal.rb`, `tests/js/test_st1c_ponuka.js`, `tests/js/test_st2c_modal.js`,
`tests/js/test_st2c_editor.js`, `tests/js/test_st2d_kde.js` (mini-DOM `tests/js/minidom.js`). Plné znenie: archív, „D-15 modal…" a „ZÁMOK ODOSLANIA OPEN.busy".

### Escape reťaz ručných modálov (R-23.1, ui/js/nx_esc.js)

**Čo robí:** Escape pre modály **mimo** kostry D-15 (`absModal` v Inspectore; `mdRestoreModal`, `mdDeleteModal`, `mdUniModal`, `demosModal`, `hwDelModal`
v Štúdiu) — **JEDEN dokumentový handler s prioritným zoznamom vrstiev** pre obe okná (`nx_esc.js` v `panel.html` aj `studio.html`, vždy **pred**
`nx_modal.js` a `studio.js` — stráži `tests/js/test_r23_escape.js`).

- **Jedno stlačenie = najvyššia otvorená vrstva.** Cudzie vrstvy majú dve triedy: **(a) skutočné modály** (kostra D-15, `nxdaModal`/`tplModal`/`simModal`/
  `cfgModal` s vlastným handlerom, `budPrModal`) — reťaz pri nich **nerobí nič**; **(b) flyouty a menu** (warnpanel, rohové menu ABS a tagov, `ecMenu`/`vepoMenu`,
  combobox D-85; z-index ≤ 55, `.nxmodal` 60) blokujú **len keď žiadny náš modál otvorený nie je**. Combobox v žiadnom z tých šiestich modálov nie je (test);
  keby pribudol, patrí do (a). Vlastnú vrstvu reťaz **spotrebuje** (`stopImmediatePropagation`).
- Medzi vlastnými vrstvami rozhoduje **dokumentové poradie** (`topOpen()` = posledný otvorený uzol, `compareDocumentPosition`), nie poradie tabuľky `OWN`.
- **Escape = klik na „Zrušiť"**, nie `display:none` (`mddCancel` ruší Demos fetch, `absModalChoose('cancel')` vráti hodnotu selectu, `mdUniClose`, `hwDelClose()`).
  Otvorenosť sa pozná z `style.display !== 'none'`.
- **Vedomé obmedzenie:** fokus sa po Escape nevracia (spúšťač sa nikde neukladá); `nxdaModal` má Escape len pri fokuse v poli hľadania. Oneskorená
  `MD.confirmDelete`, ktorá otvorí modál po odchode zo sekcie, je samostatná otvorená chyba toku (reťaz ju len nezhoršuje).

### Observery panela

(`ui/panel/selection.rb`) — panel počúva **`SelObserver`** (zmena výberu) a **`PanelModelObserver`** (`onTransactionUndo`/`Redo`/`Abort`), lebo **Späť/Znova
nevystrelí selection event**. Lifecycle oboch je **atomický**: `attach_observer` (anti-double remove→add, rollback už pripojenej polovice) a `detach_observer`
(vlastný chránený krok pre KAŽDÝ observer — zlyhanie jedného nesmie preskočiť druhý ani predčasne vynulovať `@observer_model`).

- Callback transakcie je **tenký**: nič nečíta ani nemení, označí pending a naplánuje `UI.start_timer(0)` refresh — **viac undo/redo za sebou = JEDEN push** (coalescing).
- Guard „ten istý a zároveň aktívny dokument" sa overuje **dvakrát** (v callbacku aj pred pushom); `@suspend_selection_sync` sa testuje až v timeri a udalosť
  sa len odloží. Push je **VŽDY `dedup: false`** (dedup = zásah do modelu, z observer cesty zakázaný) — refresh nepridáva undo krok.
- Undo/Redo označia `history: true`; odložený refresh pred stavom výberu pošle `NX.historyRefresh(doc)`: zhodný dokument zruší rozpracovaný návrh, timer
  aj naviazanú akciu (oneskorený preflight/ack neobnoví hodnoty spred Undo). Abort vlastného apply značku nemá (jeho odmietací ack zachová novší edit).
  Detach odstráni aj značku histórie.

### SketchUp toolbar (UI-02, žije v main.rb — NIE je vlastný modul)

`Engine.install_toolbar` skladá toolbar „Noxun Engine" so 4 tlačidlami — **logo** (prepínač Inspectora: `Panel.dialog_alive?` → `Panel.hide` / `Panel.show`) ·
**Štúdio** (`StudioDialog.show`) · **ABS kontrola hrán** (`EdgeCheck.toggle`) · **Vložiť** (`Panel.show_insert`). Ikony sú **samostatné SVG**
v `noxun_engine/ui/icons/` s pevnou `#37474f` (`currentColor` mimo HTML = čierna). `noxun_logo.svg` a symbol `#i-logo` v `icons.js` nesú **tie isté krivky**,
líšia sa len viewBoxom (toolbar ~12 % vnútorný okraj) a `currentColor`; zhodu kriviek a logo **24 px** v hlavičke stráži `tests/pure/test_ui02_toolbar.rb`.

- Zapnutý stav nesie **`set_validation_proc`** (`MF_CHECKED`, `MF_GRAYED` bez kontroly hrán) — lacný a **nikdy nepustí výnimku** (`Engine.toolbar_state`).
- Prepnutie ABS ide cez zdieľanú **`Engine.toggle_edge_check`** → `EdgeCheck.toggle` → `Engine.broadcast_edge_check` obom oknám (lišta Kontroly v Štúdiu,
  rail Inspectora `Panel.push_edge_check`); tou istou metódou ide klik z panela (`nx_edge_toggle` → `Panel.handle_edge_toggle`) aj zo Štúdia (`do_edge_check`).
  Stav posiela obom oknám aj `EdgeCheck.notify_count_changed` a pri prepnutí dokumentu `EdgeCheck.notify_state_changed`.
- **Z toolbaru sa do modelu NEZAPISUJE**: žiadny `start_operation`, `Panel.show_insert` čistí výber pod `suspend_selection_sync`, refresh `dedup: false`.
  Dvojitú registráciu pri reloade drží `@toolbar` memo.

## Nástroje v modeli — toolbar „Noxun Nástroje" (`noxun_engine/tools/`)

### tools.rb

**JEDINÝ registrátor** nástrojov (`Tools.install!(parent_menu)`) a ich **spoločná vrstva**. Toolbar je zámerne **druhý** — toolbar enginu do modelu nezapisuje,
nástroje model menia. Poradie: −90° · +90° · 180° · Z = 0 · Z posun… · Kópia vľavo · Kópia vpravo · Prisunúť vľavo · Prisunúť vpravo; tie isté `UI::Command`
obsluhujú **toolbar aj submenu** Extensions → Noxun Engine → **Nástroje** (submenu sa podáva parametrom — druhé `add_submenu('Noxun Engine')` by vyrobilo druhé
menu). Idempotencia: **`file_loaded?` guard + `@toolbar` memo**. Trojstav `get_last_state`: `TB_NEVER_SHOWN` → `show`, `TB_VISIBLE` → `restore`, `TB_HIDDEN` →
nič. **Každý z 9 príkazov má restart latch aktualizácie** (`Engine.update_restart_pending?`). Ikony: `noxun_engine/ui/icons/tools/` (7 PNG Mowera, 2 SVG Snapera).

**Poradie preflightov (kontrakt):** výber jednej inštancie/skupiny → `route` (edit kontext → vnorený → druh objektu) → `settle!` → `mutate`.
- **`Tools.settle!`**: (1) `ScaleWatch.flush_pending!(model)` dovedie observer do pokoja, (2) transformácia sa číta **znova** a musí byť rigidná
  (`CabinetBuilder.rigid_matrix?`) — inak nástroj odmietne.
- **`Tools.mutate`** je jediné miesto, kde nástroje menia model: nad NOXUN objektom celá operácia pod `ScaleWatch.guard`, v tej istej operácii sa presunú ghost
  zóny (`Zones.move_ghost`) a **až po úspešnom commite** `ScaleWatch.remember_transform`.
- Hlásenia sú **nemodálne** — status bar + `UI::Notification` (`Engine.extension`).

### mower_calc.rb

**Čisté jadro** Mowera (bez `UI::*`/`Sketchup::*`, mm Float, v zozname `tests/helper.rb`): znamienko a posun kópie po **lokálnej osi X**, `z_delta_mm`, `route`
(`:edit_context` · `:nested` · `:cabinet` · `:board` · `:legacy`), `pending_decision` (token, lehota handshaku) a **prípona názvu kópie**: najbližšia voľná
v celom modeli, **VÝHRADNE PÍSMENOVÁ** — `a`…`z`, `aa`…`zz`, `aaa`… (bijektívna sústava so základom 26, číslo sa v prípone neobjaví). Základ sa odvodí zo zdroja
bez prípony kópie (len **medzera + jedno alebo dve malé ASCII písmená**): „Skrinka a" → „Skrinka b"; **číslo na konci názvu sa neodstráni nikdy** („Dolná 900" →
„Dolná 900 a"), veľké písmeno ani slovo tiež nie. Základ sa oreže tak, aby prípona prežila `sanitize_name` (`NAME_MAX_LEN` 80, synchro s `CabinetBuilder`
stráži guard).

### mower.rb

SketchUp vrstva Mowera + **Z-dialog**. Rotácie (pivot = stred obálky, **svetová Z**) a Z posun platia len v root kontexte (`transform_entities` interpretuje
transformáciu globálne iba tam).

**Kópia NOXUN korpusu = cesta „Vložiť kópiu"**: `Store.config` → `newer_config?` brána (R-12) → `config_to_params` → `rekey_hardware_manual` →
`CabinetBuilder.build(model, params, transform: src.transformation * translation(Units.vector(±šírka, 0, 0)), appearance_source: src)` →
`Panel.push_selected(model, dedup: false)` — kópia má vlastnú identitu (Inspector, kusovník) a zachová vzhľad aj pri novšej knižničnej revízii. Krok je **šírka
korpusu z configu**, nie bbox (čelo so záporným `gap_sides` či úchytka smú presahovať). Kópia **dosky** nie je podporovaná (`BoardBuilder.build` polohu
neprijíma); nie-NOXUN objekty idú legacy cestou (DC `lenx` / bounds, `add_instance`).

**Dve poistky kópie z toolbaru** (klik ide mimo JS):
1. **Bežiaca ghost session sa ruší** (`GhostTool.cancel_session('kópia nástrojom')`, ako `Panel.handle_insert_copy`).
2. **Handshake s Inspectorom pred čítaním configu** (auto-apply má 400 ms debounce): pri otvorenom paneli server drží čakajúcu kópiu pod tokenom
   (`start_cabinet_copy`) a pošle `NX.flushForNative(token, {kind, dir})`. JS odpovedá v každej vetve: červené pole / rozpísaný výraz → `native_flush_done`
   `'invalid'` (kópia sa odmietne) · nič na flush → `'nothing'` · rozpísané edity → `apply_all` s `native_op` a kópia beží v tom callbacku. **Smer je vždy zo
   servera** (echo klienta je len korelačný kľúč; token čistí `manual_token`). Bez odpovede do **2 s** kópia odmietnutá „Inspector neodpovedal".
   Pending handshake drží pôvodný model aj source handle; dokončenie vyžaduje ten istý aktívny model, platný source a nezmenené CAB ID. JS vetvy stráži
   `tests/js/test_nastroje1_flush.js` (číta funkciu priamo zo `form.js`).

**`Tools::ZDialog`** (Z posun v mm): callbacky **pred `show`**, unikátny `preferences_key`, `set_on_closed` → `nil`, `applyZ` pod
`Engine.update_locked?(:tools_z)` a účasť vo **všetkých troch zoznamoch bariéry aktualizácie** (`SupplierSettingsDialog.close_plugin_dialogs`,
`SupplierSettingsDialog.dialogs_closed?`, post-swap `Engine.close_all_dialogs`; guard test).

### snap_calc.rb

**Čisté jadro** Snapera: AABB sweep nad obálkami v lokálnom ráme cieľa. Prekážka sa počíta, len keď sa kryje s cieľom v **hĺbke (Y) aj výške (Z)** (dotyk nie je
prekryv). **Kontajner nie je nikdy kandidát** — jeho obálka je zjednotenie detí; je len schránka na zostup (lenivý `children` `Proc`), gap počítajú **listy**,
obálka kontajnera slúži len na predvýber (koridor + `reaches?`, nadmnožina). Na **strope hĺbky (8)** platí obálka ako kandidát (medzera nanajvýš pesimistická).
Prahy: `TOUCH` 0,2 mm · `WARN` 10 m · `BLOCK` 20 m; `verdict` → `:none` · `:touching` · `:ok` · `:far` · `:too_far` podľa **svetovej** vzdialenosti.

### snaper.rb

SketchUp vrstva Snapera — zbiera geometriu a rozhoduje **viditeľnosť**: `Model#drawing_element_visible?` **pod `rescue`** (pred SU 2026.0 hádže výnimku pri
kontajneri na konci cesty) s fallbackom `hidden?` + `layer.visible?` + `Tags.folder_hidden?` po celej ceste; po prvej výnimke sa natívna cesta vypne jednosmerným
zámkom `@native_visibility`. Obálka cudzieho kontajnera = rekurzívne z **viditeľných** listov (hĺbka 8); predvýber cez `definition.bounds` ako nadmnožinu; tou
istou traverzou aj bounds cieľa. **NOXUN korpus (cieľ aj prekážka) sa meria logickou obálkou** `CabinetBuilder.envelope` (nominálne š × h × v) — presahujúce
čelo slotu umývačky ani telo spotrebiča doraz neskracujú a výsledok nezávisí od zapnutých tagov; traverza platí len pre cudziu geometriu.

### legacy_cleanup.rb

**Boot migrácia starých inštalácií** Mowera a Snapera (sú súčasťou balíka enginu): odstráni **presne štyri ciele** (`noxun_mower_loader.rb` · `Noxun_Mower/` ·
`snaper.rb` · `snaper/`) v odovzdanom priečinku `Plugins`; beží z `main.rb` **pred registráciou toolbarov** vo vlastnom chránenom bloku (zlyhanie nezhodí menu
ani toolbar). Boot, nie updater — swap vykonáva ešte starý kód. **Čisté jadro** (cesty ako parametre, hlášky konštanty; zobrazenie cez `message_for`). Boot
volá **`boot!`** (zapamätá `boot_marker_path` / `boot_result`), testy `run!`.

- **Zlyhanie nie je hotovo:** každý cieľ má postkontrolu existencie, kľúč do markera sa zapíše až po overenej neprítomnosti všetkých štyroch; inak stav `failed`
  a opakovanie pri ďalšom boote.
- **Marker mimo swapovaného stromu:** `%APPDATA%\NOXUN\Engine\legacy_cleanup.json` (`JsonFileStore` + `.bak`, zápis pod `Materials.with_catalog_lock`), kľúč =
  normalizovaná cesta `Plugins` (`Updater.normalize_path` + `downcase`, každá inštalácia SketchUpu zvlášť). Vedomá odchýlka od R-11: poškodený marker s platnou
  `.bak` zápisy nezastaví.
- **Reštart je povinný** (legacy toolbary ostávajú v pamäti) — hláška log + status + `UI::Notification`, nikdy blokujúci modal. Druhý kanál je
  `INSTALL_noxun_engine.ps1` (tie isté štyri cesty s postkontrolou, končí pokynom „Reštartuj SketchUp"). Testy: `tests/pure/test_nastroje1b_legacy.rb` +
  in-SU `run_tools1b`.

## Inspector — kostra a kontexty

### Inspector — kostra (UI-B1, ui/js/shell.js)

**Čo to je:** vľavo **rail** kontextov (Korpus · Zóny · Čelá · Kovanie + prepínače kontrol a koliesko), vpravo jednoradová sticky hlavička (logo + identita +
⚠ chip) a obsah v **4 sektoroch** `S1 Náhľad · S2 Základné · S3 Materiály · S4 Nastavenia`. Kostra v `panel.html` je **STATICKÁ** — prepínanie mení len triedy
a atribúty na `<body>`; `innerHTML` re-render kostry je zakázaný (listenery, otvorené comboboxy, rozpísané hodnoty, fokus) a stráži to guard test.

**Stav a identita:**
- `NXShell` drží dva oddelené stavy: `selectionMode` zo servera (`insert|cab|part|board` = body classes) a `viewContext` z UI (`korpus|zony|cela|kovanie`, platný
  len pri `cab`, zrkadlený do atribútu `data-view-ctx` na `<body>`), plus **typ označenej skrinky** (`setCabType` z `NX.loadSelected`).
- **Identita výberu** (`<model_guid>|cab:<id>` / `…|part:<cab>/<role_key>` / `…|board:<id>` / `none`) sa odvodzuje v JEDINOM mieste `setUiMode(mode, sel)`.
  **Nová identita ⇒ reset kontextu na Korpus** (aj vrstiev náhľadu `NXLayers.reset`); **echo push tej istej identity kontext ani zbalenia NEMENÍ**
  (auto-apply, Späť/Znova, refresh katalógu). Dielec vynúti zónový náhľad; jednozónová skrinka auto-ukáže kartu Zóna.
- **Identitu dokumentu nesie každý push** (`Panel.model_guid`) — ID (`CAB-001`, `BRD-001`) sú jedinečné len v rámci modelu. Hodnotou je token **`DocKey`**
  ([model-a-identita.md](model-a-identita.md)), nie `Model#guid` (mení sa pri každom uložení); identita sa mení len s objektom modelu. Tú istú identitu nesú
  asynchrónne callbacky panela (`clear_selection`, `nx_edge_toggle`, …) a server ich pri nezhode odmietne a len obnoví stav.
- **Kontext, ktorý typ nemá** (`ctxLockedBy` — typ bez vnútra `zones: none` z registra `NXTypes`, dôvod = `zones_reason`; dnes slot umývačky nemá Zóny): autoritou je **guard v `setCtx`** (klik, Enter, medzerník), `effectiveCtx()`
  zakázaný kontext ticho zhodí na Korpus (pamäť ostáva) a tlačidlo dostane **dôvod** do bubliny aj `aria-label`.

**Rail:**
- Pri `part`/`board` ukáže **dočasnú položku** s krížikom a kontexty zosivejú (`aria-disabled`, guard v `setViewContext`). Krížik je samostatné `<button>` vedľa
  ukazovateľa; dielec → `select_cabinet` → `handle_select_cabinet`, doska → `clear_selection` → `handle_clear_selection` (výber sa čistí pod
  `suspend_selection_sync`, refresh `dedup: false`, žiadny undo krok). Krížik dosky **najprv flushne rozpísané edity** (`flushBoardEditsNow`) a nesie identitu
  dosky (server overí, že je stále vybratá tá istá).
- Popis kontextu a dôvod neaktívnosti idú do bubliny `.railtip` a `aria-label` (natívny `title` sa na raile nepoužíva).
- **Prepínače kontrol** (rovnaký vzor, stav drží server — pull v `push_init`, push cez `NX.set…`): **ABS kontrola** `nx_edge_toggle` → `Engine.toggle_edge_check`
  (`NX.setEdgeCheck`) · **Kontrola kresby** `railKresba` → `nx_grain_toggle` → `Engine.toggle_grain_check` (`NX.setGrainCheck`, `NXShell.grainRail`) ·
  **Smer otvárania** `railSmer` → `nx_direction_toggle` → `Panel.handle_direction_toggle` → `Engine.toggle_direction_check` (`NX.setDirectionCheck`,
  `NXShell.directionRail`). Detail kontrol: odseky `grain_check` / `direction_check` v [construction.md](construction.md).
- **Flyout roh ABS** (`.railfly .railbtn::after` trojuholník + samostatné tlačidlo `#railAbsMore` cez pravý dolný kvadrant 17 × 16 px): klik na ikonu = toggle,
  klik na roh = **3-stavové nastavenie — TO ISTÉ ako lišta sekcie Kontrola v Štúdiu** (markup zo zdieľaného `ui/js/edge_menu.js` `NXEdgeMenu.menuHtml`, štýly
  v `panel.css`). Zápis `nx_edge_option` → `Panel.handle_edge_option` (whitelist kľúča, výslovný boolean, prísny guard dokumentu) → `Engine.set_edge_check_option`
  (`%APPDATA%` + `broadcast_edge_check` obom oknám). Zatvára klik mimo a Escape (`bindEdgeMenu` v `boot.js`); **nikdy dve kópie naraz** (`Engine.close_edge_menu`).
  Testy `tests/pure/test_abs_rail_3stav.rb`, `tests/js/test_abs_rail_3stav.js`, in-SU `run_d104`.
- **Viditeľnosť tagov** (`railTagy` v obale `.railmenu`, nie `.railfly`): celé tlačidlo otvára okno so zoznamom NOXUN tagov (`#railTagsMenu`, čistý modul
  `ui/js/tag_menu.js`). Zápis `nx_tag_visible` → `Panel.handle_tag_visible` (prísny guard, whitelist `Tags::KEYS`, výslovný boolean) → `Engine.set_tag_visible` →
  `Tags.set_visible` (**jedna operácia = jeden krok Späť**) → `broadcast_tags`. Stav pull v `push_init` (`tags`) a push pri každom `push_selected`; `LayersObserver`
  sa nepridáva (zmena v natívnom okne Tags sa prejaví pri ďalšom pushi). Obrysy zón (kľúč `zony`) prepína **jediný ovládač — toto okno** (`nxApplyTags` nasadzuje ikonu raily);
  checkbox pod náhľadom zanikol (H6a). Testy `tests/pure/test_d27_tagy.rb`, `tests/js/test_d27_tagy.js`, in-SU `run_d27`; modul `tags.rb` v [construction.md](construction.md).
- **Koliesko** otvára modal `#cfgModal` (Vzhľad = téma · Rozmerové rady = editor `DimSeries` · O plugine = logo + verzia) — zámerne nie piaty kontext (nastavenia
  počítača nepatria do stavového stroja a musia ísť aj bez výberu). Rady chodia v `push_init` (`ui_settings`) a malým pushom `NX.setUiSettings` (mení len
  ponuky a stav prepínača). **Téma v tomto payloade nie je a nesmie pribudnúť** (`nxSyncThemeButtons` len presvieti tlačidlá). **Dve okná (H10b/R-35):** editor
  pripne rady, ktoré ukázal, do `NXDIM_BASE` (kópia) **len** v `nxFillSeriesEditor` (otvorenie kolieska a odpoveď `refill_editor`); push témy ani init pin nemenia.
  „Uložiť rady" posiela cez čistú `NXDim.changes(texts, base)` len rady, ktorých normalizovaná podoba sa líši od pinu, a ku každému pôvodnú hodnotu (`{series, base}`;
  rad bez pinu ide s `base: null` → server `:stale_client`); bez zmeny server nevolá, polia zjednotí z pinu a status povie „Rozmerové rady sa nezmenili.". „Predvolené"
  mení len polia. Výsledok uloženia ukazuje aj riadok `#serStatus` priamo v sekcii (`nxSeriesStatus`; plní ho `series_status` z odpovede, otvorenie kolieska ho skryje,
  push témy ho nemení). Testy `tests/js/test_uib3_korpus.js`, `tests/js/test_h10b_rady.js`, `tests/pure/test_uib3_rady.rb`, `tests/pure/test_h10b_rady.rb`.

**Sektory:**
- `<details data-key="s1…s4">`, zbalenie v `localStorage`. Viditeľnosť S2/S3 rozhoduje čistá **`NXShell.sectorVis(mode, ctx)`** — Základné a Materiály patria
  kontextu **Korpus** (+ vkladanie); v Zónach/Čelách/Kovaní ich nahrádza **odkaz `#s1Link` v lište Náhľadu** (H6b: rozmery skrinky, klik = Korpus; vráti ho
  `sectorVis().link`). CSS nad `#secBasic`/`#secMat` je **zrkadlom** tejto funkcie (guard `tests/pure/test_uib1_kostra.rb` + matica `tests/js/test_uib1_kostra.js`).
- **Odkaz `#s1Link` (H6b, O6):** statický `<button hidden data-nx-usage="ctx:korpus" onclick="nxS1Link(event)">` v `<summary>` S1 s textom `#s1LinkTxt` (elipsa) a ikonou
  `arrow-right`. `nxSectorMetaApply` ho ukáže len pri `mode = cab` a kontexte Zóny/Čelá/Kovanie (`sectorMeta().s1link` = `metaDims(dims)`, **tá istá funkcia a polia
  ako lišta Základné**; nekompletné rozmery → bez odkazu), zároveň skryje `#s1Meta` (názov projekcie). `nxS1Link` = `nxTipStop` (klik nezbalí sektor) +
  `setViewContext('korpus')`. Bublina (`title` aj `aria-label`) = `NXShell.s1LinkTitle(material)` — „Materiál korpusu: … — klik otvorí kontext Korpus"; popis dekoru
  si `bridge.js` drží ako **dáta** (`s1LinkSrc.material_id`) a prekladá až v `renderS1Link` (volá ho `setS1Link` pri pushi skrinky aj `NX.setMaterials`, takže
  premenovanie dekoru zmení bublinu). Poistka `.nx-inspector .sect > .secthead [hidden] { display: none; }` (pasca D-137).
- Skupiny S4 nesú `data-s4="<kontext>"` a sú v rámci kontextu **exkluzívne** (`NXShell.exclusiveClose`, kľúč `nxsec_s4.<ctx>.<key>`), výnimka `data-s4-solo`.
- **Lišta sektora nesie META súhrn** (`NXShell.sectorMeta`, čítaný živo z panela cez `nxSectorMetaApply` — žiadna cache textu, žiadne nové serverové dáta);
  obnovuje ho `nxShellApply`, `refreshHardwareManual`, jeden delegovaný `input`/`change` listener (`NX_META_FIELDS` vrátane `top_mode`, `bottom_mode`, `back_mode` a polí medzier `fr_gap*`)
  a programové cesty, ktoré menia obsah: `renderZoneTree` (aj prázdny strom), `renderHardware` (blok `finally`), `updateFrontMeta`, `updateCabfrontMeta`.
  **S4 je vždy SÚHRN OBSAHU kontextu** (H6b, O12; otvorená skupina ho nemení, názov skupiny sa už nezbiera): `nxMetaContent(mode, ctx)` zbiera len živý stav aktuálneho
  kontextu — Korpus hodnoty selectov `top_mode`/`bottom_mode`/`back_mode` (slot umývačky `!NXTypes.carcass` = bez súhrnu), Zóny listy z `computeZones()` (bez 4. úrovne
  `deep`) a ich police, Čelá `nxFrontCounts()` + `nxCabfrontText()`, Kovanie `hwItems` + `nxHwSummary` + počet ručných položiek (`hwManualView`). Skladajú ho čisté funkcie `metaKorpus`/`metaZones`/
  `metaFronts`/`metaHardware` v `shell.js` cez `sectorMeta` (Node testy `tests/js/test_h6b_suhrny.js`); formát v UI_DIZAJN §5.1.
- Akcie **z náhľadu** najprv rozbalia cestu k cieľu (`nxRevealTarget`).
- Scroll je dokumentový (rail `position: fixed`, hlavička sticky, warnpanel je overlay v hlavičke). CSS kostry je scopnuté pod `.nx-inspector` na `<html>`.
  Pätička s verziou z Ruby. Testy: `tests/js/test_uib1_kostra.js`, `tests/pure/test_uib1_kostra.rb`, in-SU `run_uib1`.
- **Spodok panela a pomocné texty (H6a):** akcie „Vložiť kópiu" a „Uložiť šablónu" sú dve `ghostbtn` v jednom `.cabacts` (viditeľné len `body.mode-cab`;
  akcie `insertCopySelected()` / `openSaveTemplateModal()` bez zmeny). **`#status`** je `hidden` bez správy: `NX.setStatus(msg, err)` (`bridge.js`) nastaví
  `textContent`, triedu `ok`/`err` a `hidden = (msg prázdna po trim)`; `NX.setStatus('')` (`hardware.js`) vetu schová, „Pripravené." nie je; Štúdio má vlastný
  `#status`. Legenda „Rozmery" (`#basicCard > legend`) je skrytá pri `mode-cab`. **„?" pod náhľadom** je statický `#pvHelp` v `.pvbar` (pred `#pvCam`); `data-tip`
  mu nasadzuje `nxShellApply` z čistej `NXShell.pvHelpText(mode, ctx)` (Zóny a dielec = zónová veta, Čelá, Kovanie, inak len gestá). **„?" v hlavičkách** skupín
  Štruktúra zón, Položky, Sety, Pravidlá (`.ghdr` + `.gtools` + `.nxtip r`, klik cez `nxTipStop` skupinu nezbalí) a `#s3Help` v lište Materiálov (len `mode-cab`,
  súrodenec `#s3Meta`). Testy `tests/pure/test_h6a_html.rb`, `test_h6a_texty.rb` (inventár viet `tests/fixtures/h6_texty.json`), `tests/js/test_h6a_napovedy.js`.

### D-08 kontexty

Korpus · Zóny · Čelá · Kovanie sú tlačidlá **railu** (atribút `data-view-ctx`). Kontext prepína náhľad AJ viditeľné skupiny S4 cez CSS; v `preview.js` je len
prevod `cabTabPreview(ctx)` → režim náhľadu (`cab | zones | fronts | hw`). Kontext sa **nepamätá cez zmenu výberu** (nová identita → Korpus).

### Kontext Korpus (UI-B3, ui/js/settings.js · form.js · core.js · bridge.js)

**Čo robí:** sektory **Základné** (rozmery a dopočítané údaje), **Materiály** (telo/čelá/chrbát) a **Nastavenia** (skupiny Strop · Dno & podstavec · Chrbát)
označenej alebo vkladanej skrinky. Dáta: `cabinet_payload` (`payloads.rb`), zápis auto-apply cez `apply` (`actions_cabinet.rb`).

**Základné** je `.basicgrid` — **vľavo VSTUPY** (Šírka · Výška · Hĺbka · Sokel · Hrúbka; `.rowc` s ikonou), **vpravo `.infocol` = dopočítané ÚDAJE ako TEXT**
(Vnút. šírka · Vnút. hĺbka · Úložná výška · Dielcov · Materiál m² · Hmotnosť). **Výstupy nikdy nevyzerajú ako vstupy** (`<b>` s ID `av_width`/`av_depth`/
`av_height`, zapisuje `setOut()`). Polia držia ID aj change cestu (`oninput="onField()"`, zámky D-39, výrazy `expr.js`; každé číselné pole v `#basicCard` musí
byť v `bindExprFields` — guard `test_rohb1_ovladace.js`, výnimka `aprMountVal`).
- **Rozmerový rad** je len PONUKA (`.pbtn` → `.miniopts`, najviac jedna otvorená): voľba zapíše hodnotu a vystrelí pôvodný `input`. Žiadna nová zapisovacia
  logika; **hrúbka rad nemá** (určuje ju materiál).
- **Čísla informačného stĺpca počíta server**: `parts_count` + `parts_area_m2` + `weight_kg` / `weight_estimated_parts` / `weight_estimated_density` z
  `Panel.cabinet_stats` (čisté čítanie snapshotov s filtrom ako `Bom.collect`; hmotnosť cez `Bom.weight_totals` — jeden vzorec pre plán aj Inspector), tranzientné.
  **Hmotnosť** formátuje čistá **`nxCabWeight(c)`** (`core.js`): `12,4 kg` · `≈ 12,4 kg` s tooltipom o odhade · `—` bez dát; zapisuje `setCabInfo` v `bridge.js`
  a `setCabInfo(null)` z `loadBoard`/`clearSelected`; vo vkladaní sa vynuluje; nie je klikateľná.
- **Klikateľné sú len údaje, ktoré niekam vedú:** „Dielcov" → `nx_select_parts` → `Panel.handle_select_parts` (zmena výberu pod `suspend_selection_sync`, žiadny
  undo krok, prísny guard `model_guid` + `cabinet_id`, **flush handshake ako „Vložiť kópiu"** — červené pole akciu zastaví) · „Materiál" → `openStudio('bom',
  cabinet_id)` (Štúdio na Kusovníku, ID skrinky predvyplní hľadanie). Bez označenej skrinky `aria-disabled`.
- **Riadok Nohy** (`#legsRow`, cez oba stĺpce, jeden riadok, dlhý názov orezaný s `title`): povie, aké nohy skrinka dostane. **Text skladá SERVER**
  ([hardware.md § `legs_summary`](hardware.md)), `tone: 'warn'` = trieda `.warn`, `tone: 'none'` riadok skryje; viditeľnosť ide s riadkom Sokel
  (`nxLegsApplyVisibility`). (a) **Označená skrinka:** `legs_summary` z `HardwareSets.legs_summary_from_purchase(params['hardware'])` + select setu nôh
  (`hwCabOptionList` + `hwSetSelectHtml`, zápis existujúcou akciou `set_hardware_set`); `renderLegsRow` beží až za `renderHardware`. (b) **Vkladanie:** čítací
  callback `insert_legs_preview` → `handle_insert_legs_preview` (žiadna operácia, žiadny zápis), odpoveď `NX.insertLegsPreview` s generáciou `gen`; payload
  `INSERT_LEGS_KEYS` = `type · width · height · depth · floor_height · plinth_mode` + `INSERT_LEGS_HW_KEYS` = `hardware_sets · hardware_set_defs` šablóny
  (zdroj `NXInsert.hardwarePayload()`), debounce 150 ms; jeden zdroj `nxLegsInsertDims()` plní payload aj kľúč `nxLegsInsertPeek`. Server: `CabinetBuilder.normalize`
  + `Construction.cabinet_hw_ctx` + `HardwareRules.evaluate` + `Panel.item_purchase`; kovanie šablóny číta `insert_legs_template_hw` **tou istou bránou ako vklad**
  (`read_template_mapping` + `assess_set_defs`) a ide do `HardwareSets.state_with_template_sets` ako prospektívny stav. Override sa vo vkladaní neponúka.
  **Text je VÝSTUP** — do `collectAll()` ani vkladacieho payloadu sa nedostane (`test_kovg2_nohy_ui.js`, `test_insert_state.js`). **Odchod z riadku = skryť aj
  zneplatniť** (`nxLegsInsertReset` z `loadSelected`, `loadBoard`, `clearSelected`, `materializeInsertBoardCard` a prechod na hornú skrinku zdvihne generáciu);
  odpoveď sa prijme len pri type s nohami (`nxLegsTypeHasLegs` = známy typ registra s `on_floor` — dnes `lower`, `corner_blind`; `nxLegsApplyVisibility(t)`
  dostáva skutočný typ a skryje riadok pri `!onFloor`). `NX.setHardwareSets` prekreslí vetu pri označenej skrinke a bez nej
  volá `nxLegsInsertInvalidate` (mapovanie, definícia setu a názvy nie sú v kľúči).
- **Krížová kontrola výšky** (`form.js` `cabinetHeightError` na konci `validateFields`): výška je **celková vrátane sokla**; `markHeightError` zočervená
  **dvojicu Výška + Podstavec** s dôvodom v `title`, apply sa zablokuje. Zrkadlo dvoch Ruby pravidiel cez zdieľanú `nxInteriorZ` (`core.js`): svetlé vnútro
  `<= MIN_AVAIL_H` (10 mm) a pri vrchu „dve výstuhy" `NX_MIN_INTERIOR_H` (20 mm) — zhodu stráži `tests/pure/test_s1e0_min_vyska.rb`. **Prázdne pole nie je nula:**
  `cabFieldOrDefault(id)` číta `DEFAULTS[getType()]` (= `CabinetBuilder::LOWER_DEFAULTS` / `UPPER_DEFAULTS` zo `sync.rb`); kým predvoľby neprišli, kontrola mlčí.
  JS sada `tests/js/test_s1e0_min_vyska.js`.
- **Typ badge** v hlavičke je readonly (`nxCabInfo(c).type` = `NXTypes.label` — `label` registra servera, neznámy typ = Dolná) — typ určuje šablóna/vkladanie. Mini-modal „Uložiť ako
  šablónu" nesie **Názov + Typ** (`handle_save_template_as`, whitelist) a drží identitu skrinky aj dokumentu (`tplModalGuid`); červené pole uloženie zastaví.

**Rohová skrinka** (`#cornerRow` nad Nohami, slúži označenej aj vkladacej karte): **Dverová časť** · **CR 1 / CR 2** (`.crin`) · prepínač strany
(`#cornerSideL`/`#cornerSideR`, `aria-pressed`) · `?`. Viditeľnosť rieši `applyVisibility`, stav prepínača `nxCornerRowSync` z registra `cornerDraft`. Polia idú
bežnou cestou poľa (výrazy, validácia, debounce, `CONSTRUCTION_FIELDS` s `onlyIf:'corner'`; `CORNER_FIELDS` sa validujú len pri type s rohovou zostavou).
- **`cabinetCornerError`**: rozsah poľa (`CORNER_RANGES` 250–800 / 50–250) a **najmenšia šírka** `D + c1 + th2 + 2t` = presne `Construction.corner_fit_width`
  (`nxCornerMinWidth` / `nxCornerFitError`, tá istá veta ako server); pri nezmestení červená šírka, dverová časť a CR 1 (`nxCornerBoxesSync`), veta ide do
  `nxCabFieldError`. Hrúbky: th2 z payloadu (`corner_th2`) alebo `corner_ctx` preflightu, t pri vkladaní z `corner_ctx`, inak z poľa (`nxCornerT`).
- Výstup **„Šírka dverí"** (`#infCornerDoor`, len pri označenej rohovej; číslo `corner_preview.door_w` zo servera, „—" kým nepríde; klik `onInfoCornerDoor` → Čelá,
  karta F1). Súhrn lišty nesie „dvere vľavo 450" (`nxMetaDims` → `corner`).
- **Prepínač strany `onCornerSide`:** klik na zvolenú stranu nič nerobí. Označená rohová: najprv `nxCabinetAction` (dopíše rozpísané, červené pole zastaví; počas
  debounce či odoslaného apply sa vykoná po potvrdenom apply), potom `sketchup.corner_side` s `switch_token` a **len** `{cabinet_id, corner_side, switch_token,
  model_guid}`; novú stranu ukáže až push servera. Kým beží (`cornerSwitch`): skupiny Čelá zamknuté (`nxCornerSwitchLock` — `inert` + `aria-busy`), auto-apply
  sa odkladá (natívna kópia dostane `invalid`), iné akcie čakajú, druhý klik nič nepošle. Koniec = korelovaná `NX.cornerSideResult` (cudzí token sa ignoruje;
  pri `holdDraft` sa čelá, strana a otvor prevezmú zo servera a až potom ide odložený apply) alebo zmena identity (`nxFrontDraftReset`). Vkladanie: zmena
  registra + zrkadlo návrhu čiel (odsek „Vkladacia karta").

**Slot umývačky** (ten istý `.basicgrid`, iný obsah): vľavo Trieda (`dw_class` 600/450) · Šírka · **Výška linky** (`height`, `#lblHeight`) · Hĺbka · **Telo V**
(`dw_body_height`) · **Sokel** (`dw_front_bottom`); vpravo výstupy Telo · **Čelo V** · **Medzera hore** (tlačidlo `onInfoDwGap` → Čelá, pole „hore") · **Pod
doskou** (jantár pri ✗) · Trieda · Dielcov · Hmotnosť čela.
- **Všetky čísla počíta server** (`Panel.slot_payload`), zapisuje `renderSlotInfo` v `bridge.js`. **Čelo V je stav poslednej stavby** (`dw_front_height`,
  `slot_front_info`); odvodená hodnota cez `CabinetBuilder.dw_front_eval`. „Pod doskou" = ten istý predikát ako Kontrola `dw_height_fit`.
- Krížová kontrola pri slote vráti vetu `nxSlotFrontEval` (zrkadlo `dw_front_eval`, rozsah 300–1200) a `markHeightError` označí Výšku linky + Sokel slotu;
  schéma medzier slotu skryje „medzi" a „dole" (`SLOT_HIDDEN_GAPS`).
- **Polia slotu sa validujú len v type bez korpusu** (`!NXTypes.carcass`, dnes `dishwasher`; `SLOT_FIELDS` — skryté pole by inak blokovalo inú skrinku); pri
  prepnutí na slot `nxFillSlotFields(t)` dosadí do prázdneho/mimorozsahového poľa `DEFAULTS[t]` (= `CabinetBuilder::DISHWASHER_DEFAULTS`), platnú hodnotu
  neprepíše; `applyInsertLockValues` pri slote nedosadzuje zámok hrúbky ani sokla (`SLOT_NO_LOCK`).
- **Viditeľnosť riadkov má jednu autoritu `applyVisibility(t)`** (`SLOT_ONLY_ROWS` / `SLOT_HIDDEN_ROWS`): slot nemá Sokel korpusu `#fhRow`, soklovú skupinu,
  Hrúbku, vnútorné rozmery, Úložnú výšku, Materiál m², Nohy ani riadky komína a zapustenia. **Limity sú per typ** (`limits` registra servera,
  `NXTypes.get(t).limits`: šírka 300–1200, výška linky 500–1200 = `CabinetBuilder::DW_WIDTH_RANGE`/`DW_HEIGHT_RANGE`); kontrola výšky proti soklu sa slotu netýka.

**Nastavenia korpusu** (skupiny Strop · Dno & podstavec · Chrbát):
- **Strop:** `#topSetbackRow` „Zapustenie vpredu" (`top_front_setback`) pod Konštrukciou; pri „Bez stropu" ho `toggleTopSetback` skryje a hodnota sa pamätá.
- **Chrbát:** `#backSetbackRow` „Komín vzadu" (`back_setback`) má pevné miesto pre každý režim chrbta; tooltip `#backSetbackTip` skladá `backSetbackTipText`
  (minimum podľa režimu a voľný kanál). Select `#back_mode`: Naložený · Vložený · V drážke · **Z líšt** (`rails`) · Bez chrbta. `#backRailRow` „Výška líšt"
  (`back_rail_height`) sedí na mieste `#backThRow` (nikdy nie naraz; `toggleBackTh`, hodnoty sa pamätajú). **H sa validuje len pri aktívnych lištách**
  (`RAIL_FIELDS` + `backRailsActive`) a skryté neplatné H `collectConstruction` neposiela. Veta pod materiálom chrbta `#cabBackNote` (`backMaterialNote`):
  „(nepoužije sa — chrbát z líšt je z korpusu)" / „(nepoužije sa — bez chrbta)".
- **Súhrn v zbalenej hlavičke** (`#topMeta`, `#backMeta`, `.ghdr` + `.gtools`) len pri nenulovej hodnote (`setbackMetaTexts`). Slot umývačky riadky skrýva.
- **JS zrkadlá** (`core.js`): `nxBackSetback`/`nxTopFrontSetback` (0–300), `nxBackStop`, `nxSideDepth`, **`nxInteriorDepth`** (jediná JS autorita Vnút. hĺbky;
  pri lištách `R − t`), `nxRailGeom`, `nxBackRails`, `nxBackRailHeight` (20–300, inak 100), `nxSetbackError` = `nxSetbacksOnlyError || nxBackRailsError` = tie isté
  vety ako Ruby `Construction.setback_error` (fixtúry `tests/fixtures/kona_cases.json`, `konb_cases.json`). Validácia `cabinetSetbackError` / `cabinetCheckCarcass`
  (neskončí pri X = Y = 0, keď sú lišty) zočervená pole komína/zapustenia či lišty (`markRailError`) a veta ide do stavového riadku.
- **Tri JS zoznamy mimo `CONSTRUCTION_FIELDS`** musia niesť nové polia konštrukcie: most `currentCarcass`, `pvGeom` (cez `pvSetbackDepths` — hĺbky dielcov pre
  odhad `nxDraftStats`) a `bindExprFields` (boot.js). **Riedky config:** položky `CONSTRUCTION_FIELDS` nesú `dflt` (0, lišty 100), takže skrinka bez kľúča pole
  nastaví na predvoľbu — inak by apply ticho zapísal hodnotu predtým označenej skrinky. Testy `tests/js/test_kona_komin.js`, `tests/js/test_konb_listy.js`.

Plné znenie: archív, „Obsah Korpusu — Základné v dvoch stĺpcoch + koliesko".

### Náhľad = kontextová projekcia + spodný pás (UI-B2, ui/js/preview.js)

**Čo robí:** sektor S1 — každý kontext kreslí **svoj** pohľad (výmena, nie vrstvenie): **Korpus** čelný rez s kótami (Š dole, V vpravo, sokel/telo vľavo,
hĺbka kótou nad náznakom skosenia; **bez „mm"**) · **Zóny** zónová schéma + kóty šírok stĺpcov · **Čelá** predný pohľad + kóty výšok riadkov a medzier · **Kovanie** projekcia
s pozíciami (záves = krúžok s krížikom na závesovej hrane · výsuv = koľajnica „L" pri OBOCH bokoch + telo šuflíka · nohy = obdĺžniky v pásme sokla; **bez textov** —
súhrn položiek je v lište sektora Kovanie, H6b) · **Dielec** hrany s ABS (`#partSvg`) · **vkladanie** projekcia `insert`. Zoom/pan/fit, výška rastie s oknom, debounce prekreslenia 500 ms.

**Žiadne nové dáta:** kreslí sa výhradne z payloadov panela — rozmery formulára, `front_items`, `config.hardware` (`hwItems` z toho istého pushu), strom zón;
odvodenie robia čisté funkcie `nxHwMarks` / `nxSlideGeom` / `nxHwSummary` / `nxFrontDims` / `nxZoneSpans`. **Kovanie sa nečíta z geometrie** a značka je
orientačná. Všetky vrstvy berú geometriu z **jedného** `pvGeom()`.

**Kóty v px (H6c · D-02):** `viewBox` ostáva v **mm** modelu (`rx = PV_PAD + x`, `PV_PAD` 14 mm; ťahanie priečky, výber zóny a klik na značku sa nezmenili), ale
každý popis a čiara kót majú **stálu veľkosť na obrazovke**. `sceneSize()` zloží **obsah v mm** (korpus ∪ čelá s presahom ∪ rohová zostava `pvCornerExtent` ∪
referencie `nxRefExtent`; Kovanie len čo kreslí: nohy pod korpusom `nxHwLowestZ`, pri sokli > 0 nič, bez sokla 70 mm; geometria nohy `nxLegGeom`) a **okraje v px**
(obsah zahŕňa aj **zapnuté dokreslené vrstvy** — chip Čelá = `frontsExtent` s presahom, chip Kovanie = nohy `nxHwLowestZ` — v Korpuse, Zónach aj Čelách, aby ich fit neorezal a kóta šírky nešla cez ne;
`pvCabMargins`: korpus a vkladanie l 46 · r 40 · t 30 pri skosení (inak 8) · b 28, rohová b + `DIM_ROW_PX` 18 · čelá l 34 · r 40 · t 8 · b 28 · zóny b 28 len pri
1 < stĺpcoch ≤ 8 · Kovanie 0 · doska r 40 · b 28) čistou **`nxDimScene(content, margins, rect)`**: mierka `s` je najväčšia, pri ktorej sa zmestí obsah aj okraje + 6 px
vzduchu (`PV_PAD_PX`), scéna je obsah rozšírený o `(okraj + vzduch) / s`, takže `meet` dá `viewBox` presne mierku `s` (neplatný vstup → `s` = 0,05). `rect` je rozmer
`#preview` z `getBoundingClientRect` (`pvRect`); pod 50 px (zbalený sektor, skrytý panel, Node) sa kreslí na referencii **404 × 323** a `pvLastRect` sa zabudne.
`applyViewBox` nastaví `viewBox` aj **`pvS` = `min(rect.w / pvView.w, rect.h / pvView.h)`** (pri zoome iná než pri fite) a `pvBaseZ` (najnižší kreslený bod — vodorovné
kóty visia 18 px pod ním, aj pod presahom čela, D11). Kóty kreslia `pvDimH` / `pvDimV` / `pvText` s veľkosťou v px (`font-size = px / pvS`, `DIM_FONT_PX` 11, medzery
`DIM_GAP_FONT_PX` 10, čiara 1 px `non-scaling-stroke`, značky ±4 px, odsadenia `DIM_OFF_PX` 18 / `DIM_OFF_V_PX` 20 / hĺbka `DIM_DEPTH_OFF_PX` 12). Zmestenie popisu rieši čistá
**`pvFitLabel(lenPx, labels, fontPx)`** (odhad šírky `0,56 · font · znaky`, rezerva 4 px): zvislá kóta dlhý → krátky → **číslo vodorovne vedľa kóty**, vodorovná dlhý →
krátky vždy nad čiarou; popis čela `pvFrontLabel` v troch stupňoch („F1 · zásuvka 760" → „F1 · 760" → „F1", panel < 12 px popis nemá); čísla medzier Čiel
`nxSpreadLabels` (rozostup ≥ 11 px, zhluk sa pri hornom okraji **scény** `pvSceneTop` — nie priblíženého výrezu — vráti nadol); popis zóny a číslo pásma chladničky sa nakreslia, len keď sa zmestia. **Rad susedných vodorovných kót**
(stĺpce zón, dverová časť + CR 1 rohovej) kreslí `pvDimHRow`: popis, ktorý sa nezmestí do svojho úseku, sa nevnúti nad susedov — skúsi druhý pruh pod čiarou (len zóny) a keď je
obsadený, vynechá sa (pri priblížení sa dokreslí; vedomé obmedzenie pri extrémnych rozmeroch); aj popisy, čo sa zmestia, sa kontrolujú voči obsadenému miestu (úseky z rôznych radov zón sa prekrývajú); samostatná kóta (Š, H, doska) ostáva s textom vždy nad čiarou (`pvDimH`). **Doska:** obrys a šípky smeru dekoru majú hrúbku v px
(`non-scaling-stroke`), hrot šípky je orezaný na rozstup šípok — obrys aj šípky sú celé vo `viewBox` aj pri doske 10 × 10 mm; text „bez smeru dekoru" sa pri doske užšej než text vynechá. **Prekreslenie:**
Ctrl+koliesko po zmene `viewBox` volá `pvScheduleRender()` (najviac raz za snímku cez `requestAnimationFrame`, bez neho `setTimeout` 16; počas `dragState` nič),
`ResizeObserver` na `#preview` volá `pvOnResize(w, h)` (prekreslí pri zmene ≥ 1 px a obe strany ≥ 50 px; bez `ResizeObserver` sa nič neregistruje); posun pohľadu (pan)
mierku nemení, preto neprekresľuje. Testy `tests/js/test_h6c_koty.js` + golden `tests/fixtures/h6c_koty/`.

- **Výsuv:** geometria `nxSlideGeom` (pätka dovnútra, telo za pätkami, pomer z výšky čela); **anker = vnútorné líca bokov `x = t … W−t`** (výsuv drží bok, nie
  čelo; `2t ≥ W` padá na celý korpus); vetva `slide_rail` v `hwMarkSvg` má priehľadnú hit-oblasť `.hwhit` (hover CSS ju vynecháva).
- **Strana pántov** = čistá `nxHingeSide(wkey, idx, n, entry)`: krajné krídla viackrídlových dvierok odvodené (`left`/`p1` vľavo, `right`/posledné vpravo),
  jednokrídlové a stredné krídla čítajú **stav smeru zo slotu servera** (`front_slots`, `pvHingeSlots`, `frontDirSymbol`). Zdroj = **uložené sloty** označenej
  skrinky (`frontSlotsSaved` z `nxAdoptCabinetDraft`), bez nich sloty posledného preflightu. **Neurčené** = značka `unknown` (jantárový kruh s „?"), **bez kľúča
  smeru = žiadna značka** (strana sa nehádá).
- **Projekcia `insert`:** šablóna tak, ako bude vložená; čelá sú vrstva zapnutá defaultne (`NXLayers.DEFAULT_ON`); serverové čelá vtedy nie sú (`frontItems` je
  `null`), dopočíta ich čistý **`nxFrontsResolve`** (zrkadlo `Fronts.layout`). Doska: `renderInsertBoardPreview` so šípkami smeru dekoru, kótami 11 px a scénou `pvBoardScene` (obsah = doska, okraje r 40 · b 28 px).
- **Čelný otvor** (`{x0, w, z0, h}`) je **serverový** (`Construction.front_opening`): payload označenej skrinky nesie `front_opening` (`Panel.front_opening_payload`),
  každá odpoveď preflightu `opening` pre aktuálnu revíziu; plnia globál `frontOpening` (`core.js`, mimo `holdDraft`), `nxFrontDraftReset` ho zahodí a reset bez
  materializácie karty si ho vypýta znova (`nxInsertDraftResume`). `pvGeom` cez `nxFrontOpeningFor(type, W, op)` vloží `fx0`/`fw` a **všetci čitatelia šírky
  čiel** merajú od otvoru. Iné typy než rohová dostanú vždy `{x0: 0, w: W}` (parita `tests/js/test_roha2_vkladanie.js`). Rohová bez známeho otvoru čelá nekreslí
  (`frontsPending`). Dverová časť je živé pole — mení signatúru preflightu (`corner_door_w`).
- **Kresba rohovej zostavy:** geometriu počíta server (`Panel.corner_preview_json` nad `Construction.corner_parts`), panel ju len kreslí — globál `cornerPreview`
  z payloadu a z každého preflightu (`nxFrontDraftData` pri rohovej posiela `corner_cr1`/`corner_cr2`, `top_mode`/`rail_*`); `pvCornerPreview` ju vráti len pri
  rohovej (parita `test_rohb2_nahlad.js`). `drawCornerAssembly`: blenda tlmená a šrafovaná (`pvCornerHatch`), výstuha a CR 2 ako 18 mm pásy, CR 1 čelový pás,
  bublina servera v `<title>`, nezmestená zostava (`fits === false`) v červenej. Korpus kreslí zostavu aj dvere (`pointer-events="none"`) a kóty (`drawCornerDims`);
  Čelá a Kovanie dielce korpusu tlmia; Zóny zostavu nekreslia.
- **Slot umývačky:** `drawSlotBase` (telo so základňou prerušovane, línia linky) nahrádza `drawCarcass` v každom kontexte; `drawSlotDetail` (čelo s odvodenou
  výškou z `nxSlotFrontEval`, kóty) len v Korpuse a vo vkladaní; cesty bez serverových čiel majú projekciu `nxSlotFrontItems`. Scéna `nxSlotExtent` obsiahne aj
  trčiace telo. Rozmery generického tela sú zrkadlom Ruby (`PV_DW_BODY`, `PV_DW_BASE_H`, `PV_DW_BASE_SIDE`; guard test).
- **Kontrolná geometria chladničky** (`preview.appliances[]`, kolekcia adresovaná `item_id`): `{item_id, label, box{x,z,w,h}, bands[…], split{…} | nil, state}` v mm
  a súradniciach korpusu; geometria z `Construction.appliance_niche_references` (tá istá ako builder), verdikt z Kontroly. `drawApplianceRefs` len v Korpuse: box
  prerušovane (teal, pri `clash` jantár), pásma dverí (číslo pásma 11 px, len keď sa pásmo zmestí na výšku písma), pásmo prípustnej hrany (konce pásma a „hrana NNN" v jednom stĺpci vpravo **dovnútra boxu** — `pvApplLabels`:
  rozotlačené, „hrana 695" → „695" → nič podľa šírky boxu v px; číslo pásma sa pri kolízii s nimi vynechá); `na`/`unknown`/`unsatisfiable` pásmo nekreslí;
  model bez údajov o dverách má `bands` prázdne. Scéna `nxRefExtent`. Globál `applPreview` plní `bridge.js`, chýbajúci kľúč = prázdne pole, odchod z výberu ho zahodí.
- **Značka kovania má `data-owner`** (`owner_part_key`): klik → `nxHwMarkPick` v `hardware.js` (označí vlastníka a dotiahne jeho box v Kovaní).

**Spodný pás** (`.pvbar`, `renderPvBar`): **chipy vrstiev** Zóny·Čelá·Kovanie·Olep — chip kontextu je základ, ostatné sa prisvietia ako ghost (tlmené,
`pointer-events: none`); Olep mimo kontextu Dielec a chip bez dát sú `aria-disabled` s vysvetlením. Stav per kontext v `NXLayers`, nová identita ho resetuje.
Vpravo **„?"** (`#pvHelp`, gestá podľa režimu a kontextu — `NXShell.pvHelpText`; pod náhľadom už nie je riadok `.pvhint` ani checkbox obrysov zón), **kamera** a **fit**. Kamera = čisté čítanie: `nx_camera_focus` → `Panel.handle_camera_focus` (`view.camera.set` čelne + `view.zoom(entity)`; žiadny
`start_operation`, výber sa nemení; prísny guard `model_guid` + `cabinet_id`). Chipy prepínajú vrstvy náhľadu, nie tagy modelu.

**Ťahanie priečky:** `pointerdown` + **pointer capture**, koniec na `pointerup`/`pointercancel`/strate fokusu cez jediné `endDivListeners`. **Magnet** 1/4 · 1/2 ·
3/4 cez zdieľanú `nxZoneSnapCum` (tá istá geometria ako pole „Prvá zóna"), prah v pixeloch podľa zoomu, **Alt ho vypína** (rozhodne sa pred aplikáciou); ukladá
sa mm Float 0,01 (`nxRound2`).

Testy: `tests/js/test_uib2_nahlad.js`, `tests/pure/test_uib2_nahlad.rb`, in-SU `run_uib2`.

### Kontext Zóny (UI-C2, panel.html + ui/js/actions.js + ui/js/zone_tree.js)

**Čo robí:** strom zón skrinky a úpravy listovej/delenej zóny. Poradie skupín je záväzné — **Štruktúra zón NAVRCH** (`data-s4-solo`, mimo exkluzivity), pod
ňou **Delenie zóny · Police · Vnútro** (Vnútro je rezervovaný slot bez polí). Kostra je statická: JS píše len `#zoneTree` / `#zoneFields` a stavy uzlov.
Serverová strana: `actions_zones.rb`.

- Strom kreslí spojnice vnorenými `.zkids`; **úroveň nad `MAX_LEVELS` je neklikateľný varovný riadok** (`.znode.deep`) — strom sa nikdy neoreže.
- **Aktivita ovládačov je pravidlo:** dlaždice delenia (2/3 stĺpce · 2/3 riadky) a pilulky políc 0–6 sú aktívne **len na listovej zóne** (inak `aria-disabled`
  s dôvodom), pole **„Prvá zóna" len na delenej** (skratka na pole 1: vyplnená hodnota pole zamkne, prázdna odomkne). To isté vynucuje server.
- **Presná cesta nezmestiteľnú hodnotu odmietne** (`nxZoneExactCuts`) — zvyšok sa dorovná do posledného odomknutého poľa, presnosť 0,01 mm. Zlomkové presety
  (`nxZoneFractionOptions`) z tej istej geometrie; nedosiahnuteľný zlomok sa neponúka.
- **Draft režim vkladania má plnú paritu** (listovosť, hĺbka, strop políc sa kontrolujú lokálne; každá draftová vetva volá `nxDraftChanged()`).
- **Všetky zónové callbacky idú cez `nxZonePayload`** (pridá `model_guid` + `cabinet_id`).
- **Rohová skupinu „Delenie zóny" nemá** (`applyVisibility` pri `corner_blind` skryje `details[data-key="zsplit"]`; `body.mode-cab [data-s4][hidden]` v `panel.css`).

Testy: `tests/js/test_uic2_zony.js`, `tests/pure/test_uic2_zony.rb`, in-SU `run_uic2`.

### actions_zones.rb — zónové akcie servera

Handlery `split_zone` · `set_zone_shelves` · `clean_zone` · `set_zone_field` · `select_zone` idú cez spoločný vstup **`zone_ctx`**, ktorý **prísne** overí
dokument (`model_guid`), skrinku (`cabinet_id`) a **formát celého `zone_id`** (ID zón sa medzi dokumentmi opakujú).
- **`Panel.zone_path` vracia pri poškodenom ID `nil`, nie koreň** (inak by „Vyčistiť zónu" zmazalo celé vnútro).
- **Rohová delenie nepozná:** `split_refusal` pri type s vnútrom `zones: shelves_only` (register `CabinetTypes`, dnes rohová; H12b) vráti
  `Construction::CORNER_ZONES_MSG` (obe osi) ešte pred kontrolou listu; police ostávajú; invariant drží aj `Construction.validate!`.
- **`apply_zone_mod` vetví návratovú hodnotu mutácie:** `false` = strom sa nezmenil ⇒ chybový status a **žiadny rebuild**; úspech sa hlási až po úspešnej
  mutácii. Presnú príčinu skladá `split_refusal` („zóna je už delená…", „strom má najviac 3 úrovne").
- `handle_set_zone_field` pred zápisom volá `ZoneTree.validate_cuts` so **svetlým priestorom zóny z plánu** (`zone_clear_span` — cesta buildera; zlyhanie plánu =
  kontrola súčtu sa preskočí); status presnej cesty číta z `cuts[index]`.
- **`zone_depth_note`** pridá ORANGE varovanie k vloženiu (`handle_insert`) aj k aplikácii šablóny, keď má strom viac než `MAX_LEVELS` úrovní — vloženie sa
  povolí, orezanie je zakázané.

### Kontext Čelá (UI-C3, panel.html + ui/js/form.js + ui/js/core.js + ui/js/settings.js + ui/js/preview.js)

**Čo robí:** zoznam čiel označenej (alebo vkladanej) skrinky s kartou každého čela a spoločné nastavenia čiel skrinky. **Dve skupiny v záväznom poradí**
(`test_uic3_cela.rb`): **Čelá** (`data-key="fronts"`) · **Spoločné pre skrinku** (`cabfront`: riadok **Materiál čiel** `cab_front_c` + schéma medzier
`.gapdiag`). Dáta: `cabinet_payload` (`front_items`, `front_slots`, `front_drawer`, `front_lift`, `front_opening`), zápis `collectFronts` → `apply_all` (jeden krok
Späť) po čítacom preflighte `front_preflight` (nižšie).

**Hlavičky skupín:** `#frontMeta` („3 čelá · 1 bez smeru"; počet z DOM, „bez smeru" výhradne zo `front_slots`; text `frontCountText(n, unset)` z `core.js`, ten istý ide
do lišty sektora, počty `nxFrontCounts`) + akcia **„všetkým"**; `#cabfrontMeta` (`cabfrontMetaText(decor, gaps, {slot})`, H6b O7: „F206 ST9 · medzera 3 · okraje 2 ·
dole -20" — dekor = prvé dve slová časti pred „ · ", celý názov v `title`, okraje spoločná hodnota + výnimky, slot bez medzery a okraja dole; text skladá `nxCabfrontText`), zámok limitu presahov `#edgeLimitLock` (stav v ikone `lock`/`lock-open`, `title`, `aria-pressed`, `amber`) a ikona
„Predvolené" `#frontGapsReset`. **Každé tlačidlo v `<summary>` musí `preventDefault()` aj `stopPropagation()`** (`nxTipStop`), inak klik skupinu zbalí.

**Materiál čiel** má v tomto kontexte druhý ovládač `cab_front_c` (sektor Materiály patrí Korpusu) — tá istá hodnota, synchro drží každá cesta, ktorá siaha na
`cab_front`; zmena dekoru prekreslí meta (`setCabinetMaterials`/`clearCabinetMaterials` → `updateCabfrontMeta`).

**Riadok čela `.frow`** je **CSS grid so stálymi stĺpcami** `22px minmax(0,1fr) 112px 22px`, riadky 1 = názov · 2 = súhrn · 3 = karta. Deti sa kladú do mriežky
priamo a hľadajú **výhradne cez triedy** (obrátený render D-23 a `closest('.frow')` platia): `.fnum` (F1 dole) · `.ftname` (tlačidlo karty: `.ftico` + `.ftl` +
`.fchev`) · `.fsubwrap` (súhrn `.fsub` + koncovka kovania `.fhwlink` — súrodenci, nie vnorené) · `.hbox` · `.fdel`. **Stredný stĺpec je jediný rastúci**;
rozpočet pri 470 px stráži `tests/pure/test_smoke1_riadky.rb` (nový ovládač si musí nájsť miesto v mriežke). Medzi čelami hairline `.frow + .frow` bez nového
vertikálneho priestoru.
- **Súhrn `.fsub`** — „1 krídlo (auto) · smer? · bez úchytky · Sensys klasik · 2 ks →" — skladá čistá **`frontRowSummary(item, entry, hw, reg, drawer, corner)`**
  (`core.js`, vracia pole častí), `form.js` kreslí (`updateFrontRowSummary`). **Počet krídel hovorí server** (`front_slots[fid].wings_n`; bez záznamu „auto").
  **Smer** len z uloženej hodnoty a **len cez aktívne sloty** (`front_slots[fid].slots`) — dormantné `wing_directions` sa neťahajú; bez slotov rozhoduje skalárny
  `direction` pri jednom krídle, a keď server `wings_n` nedodal, bez ohľadu na počet. Legacy čelo bez kľúča nedostane slovo ani badge. Obnovuje sa pri light pushi
  aj plnom renderi pod `keepGaps` guardom.
- Klik na súhrn = karta na tabe **Čelo**, klik na `.fhwlink` = karta na tabe **Kovanie**; bez naviazaného kovania je koncovka `hidden`.
- **Pole výšky `.hbox`** = jeden box s konštantnou šírkou 112 px `[chip AUTO][hodnota][mm][šípka radu]`; chip `.fauto` je tlačidlo (`frontHeightAuto`) len pri
  vypísanej hodnote, „mm" vždy, placeholder „≈ N" kurzívou, pevná hodnota tučná. **Zamknuté ⇔ vypísané** (`collectFronts` posiela `locked: hasH`); chip pole
  vyprázdni pôvodnou udalosťou `input`. Výškový rad `vyska_cela` nesú riadky v atribútoch `data-dim-key` + `data-dim-input` (`nxDimFillRow`).
- Živý náhľad výrazu `.exprhint` je **overlay** pod poľom (nie flex položka).
- **Pridávanie:** rad šiestich ikon „Pridať: typ" (`renderFrontAddTypes` z `FRONT_CARD_TYPES` + `FRONT_TYPE_ICON`, popisok „Pridať čelo", `.addrow`) → `addFrontKind`;
  rad sa pri echu neprestavia. Maže sa krížikom konkrétneho riadku.
- **Tooltip `.nxtip`** (spoločný komponent): obsah v `data-tip`, hover aj fokus, šírka 250 px, `.r` zarovnaná vpravo. **Pomocný text = tooltip, stavová veta ostáva
  viditeľná**; v kontexte Čelá je jediný `.hint` = `frontDraftMessage` (guard `test_d130a_zoznam_ciel.rb`).

**Karta čela `.fcard`** = posledný potomok `.frow` (tretí riadok mriežky, priamo pod svojím riadkom), otvorená **najviac jedna**, drží sa cez **identitu čela**
(`openFrontCardId`), bez hlavičky.
- **Dva taby** (`frontCardModel` vracia `tabs`, `rows` = Čelo, `hwRows` = Kovanie; `openFrontCardTab`): **Čelo** = typegrid, krídla, smer, otváranie, konštrukcia,
  zásuvka, úchytka · **Kovanie** = vyriešený set, chipy zámkov osí, technický detail, ponuka verzie receptu, „Otvoriť v Kovaní". Default Čelo pri otvorení inej
  karty (aj deep-link `nxFocusFront`), `refreshFrontCards` tab **zachová**; prepnutie tabu nič nezapisuje; badge „smer?" sedí na tabe Čelo. **Červená stavová veta
  stojí v oboch taboch**, jantárové odporúčanie a `locked_note` len v Kovaní. Tab Kovanie má každý fyzický typ vrátane blendy (chýba pri `none`); prázdny stav sa
  neodvodzuje len z `hwRows` — poradie: text (`frontHwBadge` + `frontHwBuy`) → box vlastníka → „Bez kovania."
- **Typegrid** = 6 dlaždíc (Dvierka · Zásuvka · Výklop · Sklop · Blenda · **Bez čela**; `FRONT_TYPE_TIP`); typ žije v `dataset.frontType`, ikonu typu prekladá
  jediná mapa `FRONT_TYPE_ICON` (mení sa `href` v `<use>`). Kontextové riadky `.prow`: **Krídla** (auto · 1–4, len dvierka; hodnota v `dataset.frontWings`, legacy
  bez kľúča = `auto`; `onFrontWings` → `frontExtraOnWings` → `refreshFrontCards` → `onField`) · **Smer** (Ľavé · Neurčené ⚠ · Pravé) pri slote `single` ·
  **Krídlo 2/3** (2/4, 3/4) pre stredné krídla · **Otváranie** (Klasické · Tip-On) · **Konštrukcia** + **Zásuvka** · **Úchytka**. Výber **setu** v karte nie je
  (patrí položke kovania). Klik na už nasadenú hodnotu sa zahodí (`aria-pressed`).
- **Kde sa smer pýta, rozhoduje VÝHRADNE SERVER** (`front_slots` = `front_id → { wings_n, slots }` z `Fronts.direction_slots`): neprázdne `slots` → tie krídla ·
  `slots == []` a `wings_n == 2` → veta o dvojkrídle · `slots == []` a `wings_n` null alebo chýbajúci kľúč → karta mlčí. `state` je len zdroj badge.
- **„Neurčené" vzniká výhradne štyrmi akciami** cez čisté funkcie `frontExtraOnTypeChange` · `frontExtraOnWings` · `frontExtraOnSegrow` (vracajú nový objekt):
  „Pridať: Dvierka" (`addFrontRow` pri `userAdd`), prepnutie dlaždice na dvierka bez uloženého smeru, klik na „Neurčené", prepnutie na 3/4 krídla (len chýbajúce
  stredné krídla). Render ani echo nezapíšu nič, návrat nič nemaže (dormant). Literál `FRONT_DIR_UNSET` žije len v `core.js` (allowlist `test_kova1_cela.rb`).
- **Pass-through:** `addFrontRow` odkladá `direction`, `wing_directions`, `opening_mode`, `drawer`, `lift` a `profile_edge` do `row.dataset.frontExtra` (len prítomné
  kľúče) a `collectFronts` ich vráti **bez defaultu** (`frontExtraSet`, prázdny objekt dataset odstráni) — kľúč, ktorý config nemal, sa nesmie objaviť.
- **Fokus prežije prekreslenie karty** (`card.innerHTML`): `frontCardFocusKey` / `frontCardFocusSelector` podľa logickej identity (`data-t`, `data-k`+`data-v`+`data-w`,
  `data-tab`, `data-pc`), len keď fokus ležal v tej istej karte; `focus({ preventScroll: true })`.
- **Otvorená karta patrí konkrétnej skrinke:** čistá `frontCardKeepOpen(prevCabId, nextCabId, openId)` volaná v `bridge.js` pred `renderFronts` (pri zmene dokumentu
  predchodca `null`); doska, prázdny výber aj návrh vkladania kartu zatvárajú. Testy `tests/js/test_kova2a_karta.js`, `tests/pure/test_kova2a_karta.rb`.
- **„Otvoriť v Kovaní"** prepne kontext a doskočí na box vlastníka (`hwBoxByGroup(hwFrontGroup(fid))` — kľúč skupiny skladá jedna funkcia, `.hwfocus`); keď box
  neexistuje, tlačidlo ostáva `aria-disabled` s dôvodom a klik nerobí nič (`onFrontOpenHardware`); `openFrontHardware` overí box pred prepnutím kontextu.

**Zásuvka v karte** (zdroj **výhradne server** — `front_drawer`, karta nič neodvodzuje):
- `ok` → jeden read-only riadok („Atira · H70 · NL 470 · 30 kg · SiSy · recept v1") + rozbaliteľný „Technický detail" (vety receptu, „Balenie: <set>" a členovia
  z jediného rozpisu `HardwareSets.explain`; **nosnosť v balení nie je** — vydáva ju len recept) + jantárový riadok pri odporúčaní synchronizácie · `conflict` →
  **červená veta stavby namiesto hodnôt** · `stale` → červená „prestav skrinku" · `pending` / chýbajúci kľúč → mlčí. Ikonu `alert` nesie len červený a jantárový riadok.
- Veta **„Zásuvka bez klasifikácie"** len keď chýbajú **všetky** klasifikačné polia (konštrukcia · variant · otváranie) **a** server o zásuvke nič nepovedal
  (predikát panela = predikát servera `Recipes.recipe_key_for`).
- **Chipy zámkov osí** (`H144 výška`, `NL 470`, pri Quadre `box 360`) — ten istý markup `hwAxHtml` ako sekcia Kovanie, riadok `kind: 'axes'` z čistej
  `frontDrawerAxesRow`, **len keď server poslal stav osí (`axes`) aj identitu zápisu (`lock`)**. Chipy má aj konfliktná karta; vonkajšia červená veta sa potlačí,
  keď ju doslovne opakuje os v konflikte (`frontDrawerAxesSay`). `locked_note` menuje zamknuté osi; `Recipes.explain_stored(params, axes:)` pri zámku netvrdí vzorec.
  Kontrakt chipov a kliku: „Kontext Kovanie".
- **Ponuka novej verzie receptu** `.dwup` (úplne naspodku, pod jantárovým odporúčaním) vzniká **výhradne z kľúča `upgrade`** (`frontDrawerUpgradeRow`; bez neho nič);
  markup a klik v `hardware.js` (`hwUpHtml`, `data-ax`/`data-axc`). Klik pošle čítaciu otázku `drawer_upgrade_impact` s tokenom (`NX.hwUpgradeImpact`); pri odmietnutí
  preflightu len veta do statusu, pri `ok: true` kostra D-15 „Prejsť na novú verziu receptu" s tabuľkou dopadu na toto čelo („teraz → po prechode", nezmenené
  stlmené; `type: 'custom'` bez `read`). Potvrdenie `upgrade_drawer_recipe` s vlastným tokenom (`NX.hwUpgradeResult`), okno sa zatvára až po potvrdení a počas
  odoslania je zamknuté aj proti zatvoreniu (`busyLock`). **Zápis smie presadiť len to, čo používateľ videl:** server k dopadu pribalí **odtlačok**
  (`Digest::SHA256` nad identitou a celým dopadom), klient ho len vráti, server ho pred zápisom prepočíta; nezhoda **aj chýbajúci** odtlačok = odmietnutie „stav
  skrinky sa medzitým zmenil — otvor náhľad znova" a panel sa prekreslí. Keď zmenu odhalí až `prepare`, hláška je tá istá s pripojeným dôvodom
  (`upgrade_stale_reason`, len pri `from_preview`). Odmietnutie nezapíše nič; jediné `start_operation` je v `CabinetBuilder.rebuild` za oboma bránami.
- Testy: `tests/pure/test_kovc2c_karta.rb`, `tests/js/test_kovc2c_karta.js`.

**Výklop v karte:** typ `lift` má segment **„Systém" (HK top | HL top)** a jeden read-only riadok vyriešeného výklopu s „Technickým detailom"; **sklop (`fall`)
systém nemá**. Zápis cez dormant polia (`FRONT_EXTRA_KEYS` → `collectFronts` → `Fronts.normalize_items`); `frontExtraOnSegrow` prepisuje kópiu objektu `lift`.
Jediná výnimka z pravidla „kľúč, ktorý config nemá, sa nevyrobí": prepnutie typu **na** výklop materializuje `hk_top` (to isté zapíše `Fronts.normalize_config`);
uložená hodnota sa neprepisuje. Zdroj = server `front_lift` (`frontLiftRows`): `ok` → riadok + detail (+ jantár navyše pri ORANGE) · `conflict`/`stale` → červený
inforow s vetou servera namiesto riadku · `incomplete` → červený inforow **nad** zhrnutím, ktoré ostáva · `pending` / chýbajúci kľúč → mlčí. Veta „Mechanizmus vyberá
automat…" len keď server o výklope nič nepovedal. HL top + Tip-On sa nastaviť dá — karta to hneď povie červenou, bránu drží server. **Set výklopu** (aj tmavý) sa
vyberá pri položke v kontexte Kovanie (triedny kľúč `HardwareSets.class_key_for`, `compat.owners['front:<id>/flap']`, owner kľúč
`class:lift|<mode>|<system>@front:<id>/flap`). Testy `tests/pure/test_kove2_ui.rb`, `tests/js/test_kove2_karta.js`.

**Rohová** má v dverovej časti **jedny dvierka** (server iný stav odmieta): `nxSlotFrontsLock` skryje „Pridať čelo" a ukáže vetu `#frontOneDoor`, krížik je
`aria-disabled` s dôvodom (`delFrontRow` vráti `false`), výška na čítanie. Karta dostane `opts.corner` (`nxCornerCardSide`): iné dlaždice a krídla 2–4 zamknuté,
smer sa volá **„Pánty": Pri boku / Pri rohu** (`frontCornerDirOptions`, hodnoty `left`/`right`, slovo `frontCornerHingeWord`; predvoľbu dosadzuje len server);
súhrn „pánty pri rohu / pri boku". **Slot umývačky:** `nxSlotFrontsLock` schová „Pridať čelo", krížik aj chip AUTO, výška na čítanie, riadok „Dvere umývačky"
(`frontRowLabel`/`frontRowIcon`), karta bez dlaždíc (`frontCardModel(…, { slot: true })`) — vynucuje server (`Panel.slot_fronts_refusal`; výška sa neposudzuje).
Preflight slotu počíta s virtuálnym otvorom a riadok kanonizuje `slot_fronts!` s výškou z `dw_front_eval` (`slot_preflight_fronts`).

**Náhľad v kontexte Čelá:** popis typu má jedno miesto `PV_FRONT_TYPE_DESC` + `frontTypeDesc(type)` (fallback „dvierka" len pre neznámy typ). **Symboly otvárania**
(`drawFrontSymbols`): prerušovaná čiara = pohyb, plná = dielec; farba `PV_SELECT_ACCENT`, „neurčené" jantárový kruh s „?". Tvar = **dve čiary z rohov strany
pántov do stredu voľnej hrany** (per krídlo; krajné krídla odvodené, stredné podľa slotov; legacy čelo bez symbolu), výklop „V", sklop „Λ", zásuvka prerušované X,
blenda plné X. **Geometria má jediný zdroj** `frontSymbolShape(sym)` v `core.js` (jednotkový štvorec, `FRONT_SYM_INSET = 0,05`) a tú istú tabuľku má Ruby overlay
`DirectionCheck::SHAPES` — obe sa porovnávajú s `tests/fixtures/front_symbol_shapes.json`. Čo kresliť, rozhodujú `frontWingSymbols` · `frontDirSymbol` ·
`frontTypeSymbol`; `preview.js` stav smeru neinterpretuje (guard). Popis čela má halo farbou výplne.

Plné znenie: archív, „Kontext Čelá (UI-C3, …)".

#### Úchytky a návrh čiel s potvrdením (D-96 / D-120; form.js, core.js, preview.js, bridge.js)

**Úchytka má jediné miesto stavu — kartu čela:** riadok „Úchytka" = Profil + Hrana vedľa seba (`.phalf`; `onFrontCardProfile` / `onFrontCardEdge`). Hromadná
zmena je **akcia** — popover „všetkým" `#frontBulkPop` (Rozsah · Profil · Hrana · veta · **„Použiť na N"**): selecty nič nezapisujú, zapisuje len „Použiť"
(`onFrontBulkApply`, jeden `onField`, jeden krok Späť); hrana sa nasadí, len keď je platná pre celý rozsah (`frontProfileScopeEdges`). Popover stojí mimo `<summary>`
ako dieťa `<details>` (trigger skupinu najprv otvorí), ukotvený `right: 6px`; zatvára klik mimo, Escape a „Použiť"; fokus sa vracia na tlačidlo len keď bol
v popoveri; `aria-haspopup="dialog"` + `aria-expanded`. **Escape sa spotrebuje** (`preventDefault` + `stopImmediatePropagation`). **Poradie skriptov v `panel.html` je
kontrakt:** `nx_esc.js` → `form.js` → `boot.js`.
- Oba ovládače zapisujú `dataset.frontProfile`/`frontProfileEdge` a `collectFronts`; žiadny uložený hromadný default. `frontProfileCommon(items, scope, key)` vracia
  zmiešaný stav, `frontProfileStateText` zoskupuje profil aj hranu. Formulár prenáša prítomné `profile_edge` bez dopĺňania defaultu; zmena hrany profil nezapne,
  zmena profilu zachová platnú hranu; pri zmene typu na neaplikovateľnú hranu karta vyžiada inú (nezvolí top). `PROFILELESS_FRONT_TYPES` zrkadlí Ruby (len `none`).
- Náhľad kreslí fyzické `profile_edges` (top/bottom skracuje výšku, left/right šírku, `free` bez resolved hrán nič neodhaduje; `nxProfilePanel`).

**Návrh a potvrdenie:** `front_preflight` je čistý callback Panelu nad aktuálnymi rozmermi a čelami — vráti resolved riadky, fyzické hrany, smerové sloty, otvor,
kresbu rohovej aj chybu **bez zápisu, Undo a katalógov**. `nxFrontDraftAsk` koreluje dokument, `cabinet_id` alebo `insert_session`, revíziu a podpis formulára;
staré odpovede návrh nepotvrdia. `nxFrontPreflightResult` aktualizuje sloty, kartu a náhľad; neurčený smer sa nikdy neodhadne.
- **`nxCabinetAction`** spája preflight → `apply_all` → potvrdenie `front_apply_token` → jednu naviazanú akciu. Čakajúci/neplatný návrh blokuje aj exportné relaye,
  úpravu cez Štúdio, šablónu a native flush; zlyhaný apply nepustí pokračovanie; novší edit zneplatní starú akciu.
- Echo tej istej skrinky pri rozpísanom/in-flight stave neprepíše konštrukciu ani riadky; pri odmietnutí sa obnoví len bez novšieho editu. Zmena dokumentu, výberu
  alebo vkladacej relácie návrh zahodí; reset zachytí odmietací callback naviazanej akcie a raz ho zavolá. Server pri zápise znovu počíta a v `ensure` vracia výsledok.
- Výber zo Štúdia (`studioRelay` → `studio_do_select`) vráti `flush_blocked`; `ProductionCore.do_select` oznámi dôvod a výber nevykoná. Aplikovanie šablóny zo Štúdia
  ide `StudioDialog.handle_tpl` → `NX.studioRelayTemplate` → tá istá bariéra → `studio_do_template` (server overí dokument a tú istú jednu vybranú skrinku; bez
  otvoreného Inspectora priamy handler).
- Odložené uloženie šablóny patrí konkrétnemu otvoreniu modalu — zatvorenie, nové otvorenie aj zmena názvu, typu či voľby kovania ho zrušia.

#### Schéma medzier a jantárové podfarbenie (N26, ČELÁ-A / D-119)

Štyri okraje: formulár odosiela `gap_left`/`gap_right` (legacy `gap_sides` len pre chýbajúcu stranu); validácia, odomykanie limitu, reset aj echo guard `keepGaps`
platia pre oba. `pvGeom` nesie `gapLeft`/`gapRight` (kresba čiel, kóty, ghost, fit, odhad plochy, značky kovania); koľajnice výsuvov ostávajú na vnútorných lícach
bokov. **Schéma `.gapdiag`** = obrys korpusu (`.gd-box`, dva `.gd-front`) a päť polí `fr_gap*` umiestnených na hranách (`fr_gap` v strede, jantárový); ID,
`LIMITS`, `attachExprField`, `keepGaps`, `resetFrontGaps` (3/2/2/2/2) a serverové kľúče sú bežné. Špecificita: `.nx-inspector .row .gapdiag input.gd`.
Medzery v projekcii Čelá sa podfarbia jantárovo pri **kurzore v poli schémy** (`NX_GAP_FIELDS`, `focusin`/`focusout` v capture) **alebo hoveri nad `.gapdiag`**
(`mouseover`/`mouseout` v capture, `relatedTarget`); pásy z toho istého `nxFrontDims`, farby `PV_GAP_*` = zrkadlo tokenov `--nx-warn-*`.

### Kontext Kovanie (UI-C4, panel.html + ui/js/hardware.js + ui/panel/selection.rb)

**Čo robí:** kovanie označenej skrinky — položky z pravidiel podľa vlastníka, ručne pridané položky, sety a pravidlá. Tri skupiny v **záväznom poradí**:
**Položky z pravidiel** (`hwitems`) · **Sety** (`hwsets`) · **Pravidlá** (`hwrules`). Kostra je statická, JS píše obsah kontajnerov `#hwRows`, `#hwSetRows`
a riadok Nôh `#legsRow` (Základné) — `refreshHardwareSets` obnovuje selecty vo **všetkých troch**. **Meta skupín (H6b/H18):** `#hwItemsMeta`
(„6 ks", pri ručných „· 2 ručne"; `hwItemsMetaText`) a `#hwSetsMeta` („podľa projektu" / „1 vlastný" …; `hwSetsMetaText` = súčet serverových
`own_count`, počtu rôznych víťazných vlastných kľúčov; mŕtvy či zatienený výber a typ bez položky sa nerátajú) plní `hwMetaApply` na konci
`renderHardware`, v `refreshHardwareSets` a `refreshHardwareManual`; skupina Pravidlá meta nemá. Dáta: `cabinet_payload` (`config.hardware`, `purchase`,
`compat`, `hardware_manual_view`, `front_drawer` …); zápis existujúcimi akciami `set_hardware_override` / `set_hardware_set` (`actions_hardware.rb`) a `apply_all`.
Detail domény: [hardware.md](hardware.md).

**Ľahký push `NX.setHardwareSets`** (zmena setov, mapovania alebo katalógu v Štúdiu — `HardwareCatalogDialog.push_items` → `Panel.push_hardware_sets`) obnoví ponuky
setov, nákupné riadky (`refreshHardwarePurchase`), **ručné položky** (`manual_view` → `refreshHardwareManual`, len vlastný blok; `plan_parts_by_key` sa volá len
keď ad-hoc položky sú), **`front_drawer`** (`refreshFrontDrawer` vymení záznam a prekreslí len otvorenú kartu; záznam nesie `axes` a `lock` —
`Panel.front_drawer_refresh`; plán sa stavia len pri klasifikovanej zásuvke) a **`legs_summary`** (`renderLegsRow` až za `refreshHardwareSets`). Chýbajúci kľúč sa
ničoho nedotkne; `{}` = „skrinka zásuvky nemá". Žiadny plný push, žiadny krok Späť.

**Položky sú boxy podľa vlastníka** (`.hwbox`): „Skrinka" · box každého čela (obe krídla = jeden box) · „Vnútro skrinky" (podperky políc a ostatní). Je to len
**zobrazenie** — identita položky (`owner_part_key`, `generic_type`, `rule_id`) a zápisové cesty sa nemenia; `refreshHardwarePurchase` páruje cez
`.hwrow[data-owner…]`. Kľúč skupiny je odvodený (`hwGroupKeyOf`: prázdny → `cab`, `front:<id>/…` → `front:<id>`, inak `inside`). Hlavička berie prvú časť
`owner_label` („Čelo F2"), riadok druhú; poradie Skrinka → čelá podľa `frontItems` → Vnútro; meta = počet položiek.
- **Hlavička je natívne `<button>` a súrodenec tela boxu** (ovládače v boxe k nej nedobublajú); box sa nezbaľuje. Trieda `.hwbox` (`.hwown` je popis vlastníka v riadku).
- `.hwname` jednoriadkový s ellipsis a `title`; selecty `.hwsetsel`, `.hwnlsel` šírkou podľa obsahu v medziach; súčet stôp stráži `tests/pure/test_smoke1_riadky.rb`.
- **Podperky políc** vo „Vnútre" sú od 2 políc (`HW_PINS_MIN`) zbalené pod súhrnný riadok (`<details class="hwgrp">`, stav v `localStorage` `nx_hw_shelfpins_open`);
  pod ním pôvodné `.hwitem` riadky. Delia sa `items` aj `offs` (vypnutá polica prispeje 0 ks a zapne štítok **„upravené"** — jantár, nie semafor). Jadro
  `hwShelfPinSummary`, `hwSplitShelfPins` (`tests/js/test_smoke1_ui.js`).
- **Prisvietenie cieľa skoku** `hwFlash` (`hwfocus`, `HW_FLASH_MS` 1600 ms) svieti najviac na **jednom** uzle; cieľ z Kontroly = celá `.hwitem`, inak `.hwrow`, hľadaná
  výhradne podľa serverovej adresy (`hwRowSelector`) a `hwRowKindOk` (nezhoda s `orphan` = zastaraný payload → nesvieti nič).
- **Klik na hlavičku** → `nx_select_hw_owner` → `Panel.handle_select_hw_owner`: prázdne `part_keys` = celá skrinka, inak výrobné dielce s daným `part_key` v rozsahu
  kusovníka (`manufactured_parts`). Čisté čítanie + zmena výberu pod `suspend_selection_sync`, žiadny undo krok, prísny guard; má **flush handshake** (rozpísaný edit
  by po výbere prestavil skrinku a stratil vlastníka; neplatné pole akciu zastaví); **odmietnutý rozpísaný edit má prednosť** (`@last_apply_error` sa spotrebuje
  a ukáže); čiastočný výsledok sa hlási ako upozornenie s pomenovaním chýbajúcich. **Vedomá odchýlka:** po výbere sa **nevolá `push_selected`** (panel by prepol
  na kartu Dielec a box by zmizol); zosúladí ho najbližší bežný push. Tou istou cestou ide oko v riadku warnpanelu (`origin`).
- **Box ↔ značka v náhľade:** trieda `hov` na oboch stranách nasadzuje jedna funkcia `hwPaintHover` (`bindHwOwnerHover` raz na `#hwRows`, `hwHoverByOwner` z náhľadu);
  `renderPreview` sa počas hoveru nevolá a obe prestavby zvýraznenie zhasnú.

**Ručne pridané položky** (ad-hoc kovanie mimo setov, `config['hardware_manual']`): blok `.hwman` pod boxmi — nadpis „Ručne pridané" len keď položky sú, riadky vo
vzore `.hwitem` + `.hwbuy` **bez** identitných atribútov `data-owner`/`data-type`/`data-rule`, posledné ghost tlačidlo „Pridať konkrétnu položku (mimo setov)";
bez označenej skrinky blok nevzniká.
- **Panel nepočíta nič:** `hardware_manual_view[]` (`Panel.hardware_manual_view`) nesie živý názov a cenu z katalógu (cena sa v configu neukladá), popis vlastníka
  (`PartKeys.human_label`), `owner_missing` (jediná funkcia `Bom.manual_items_for`) a `catalog_missing`; chipy „ručná" · „bez vlastníka" · „chýba v katalógu"
  (jantár). Ponuka „Patrí k" = `hardware_manual_owners[]` (celá skrinka + čelá a zónové dielce aktuálneho plánu; korpusové dielce a surový kľúč sa neponúkajú;
  dvojznačný popis dostane prívesok zóny len v tejto ponuke). Oba kľúče sú len na čítanie — `collectAll` o nich nevie.
- **Modal** = kostra D-15 (`hw:manual:add` / `hw:manual:edit:<id>`): Patrí k · Zdroj (Z katalógu / Voľná položka) · katalóg cez `lookup` (`hw_manual_search` — čítacia
  cesta s `gen`; **neaktívne položky sa neponúkajú** — `drop_inactive` znižuje aj `total`, zápisová cesta ich ale ponecháva) · voľná Názov · MJ · Cena s DPH ·
  Množstvo · Poznámka. Cena katalógovej položky sa needituje ani neposiela. Prepnutie Zdroja = prekreslenie modalu; hodnoty nesie **draft** `HW_MAN.draft`
  (`hwManualMergeDraft` — nevykreslené kľúče sa neprepisujú), nevybraný dotaz sa číta z poľa hľadania; hodnoty neaktívneho zdroja sú len pre obrazovku
  (`hwManualRecord`). MJ zrkadlia `HardwareCatalog::UNITS` (stráži `tests/pure/test_kovh2_payload.rb`).
- **Zápis nemení kanál:** JS zostaví nový zoznam (add = prázdne `id`, prideľuje server; edit nahradí jednu; delete vynechá; nenájdené `id` → `null` a zápis sa zastaví)
  a pošle ho `collectAll()` → `apply_all`; čakajúci debounce sa **ruší, nie flushuje** (jedna zmena = jeden krok Späť). Payload nesie `manual_op {kind, id, token}`
  s **vlastným rastúcim tokenom** (server ho len vráti; uzavretý tvar, `MANUAL_TOKEN_MAX`) a `handle_apply_all` odpovedá `NX.hwManualResult(ok, msg, op)` **v každej
  vetve**; pri odmietnutí až **po `push_selected`** (modal ostáva otvorený, `hwManual` drží uložený zoznam), úspech modal zatvorí (`setBusy(false, {clear: true})`).
  Po výnimke prestavby rescue vetva pushne pred odpoveďou a výnimku ďalej `raise`-uje.
- **Mazanie bez potvrdenia** (poistka = krok Späť); status menuje odstránenú položku (`manual_removed_label` z uloženého zoznamu) a hláška výsledku nesie aj varovania
  prestavby (`warn_suffix` zdieľaný so `status_with_warnings`).
- **Modal patrí jednej skrinke:** `hwManualDropIfForeign` (v `hardware.js`) ho zavrie pri zmene **identity** (iná skrinka, dokument, doska, prázdny výber) a zahodí
  bežiace hľadanie; echo tej istej skrinky ho zavrieť nesmie.
- Testy: `tests/js/test_kovh2_adhoc_ui.js`, `tests/pure/test_kovh2_payload.rb`, in-SU `run_kovh2`.

**Chipy zámkov osí** — jeden markup na dvoch miestach: `hwAxHtml(axes, ident)` kreslí `.hwax` (obal s identitou zápisu) + `.axchips` + pri konflikte `.axconf`; volá ho
riadok položky výsuvu (`hwItemHtml`, medzi `.hwrow` a nákupom), riadok osiroteného zásahu (`hwOffHtml`, obalený do `.hwitem`) a karta čela.
- **Stav je serverový enum** `auto` | `locked` | `conflict` (iné = `auto`): `locked` jantár so zatvoreným zámkom, `conflict` červená, `auto` neutrálny s otvoreným.
- **Hodnota do zápisu ide vždy zo servera** (`data-val` = `axes[os].value`, hodnota z `options` alebo `proposal`), nikdy z textu chipu.
- Klik na `auto` zamkne zobrazenú hodnotu; klik na `locked`/`conflict` pošle `value: null` = odomknutie **len tejto osi**. Iná hodnota z `<select class="axsel">` s
  výhradne serverovými `options`; pri prázdnej ponuke (`blocked_by: 'height'`) select nie je a ide veta „najprv vyrieš výšku". **Os v `conflict` nemá ponuku.**
- **Konflikt:** červený riadok s vetou servera (`axes[os].message`), cesty von **„Nahradiť za …"** (len pri `proposal`, cez kostru D-15 `okLabel: 'Nahradiť'`;
  náhrada ostáva zamknutá) a **„Odomknúť"**.
- Zápis existujúcou akciou `set_hardware_override` (`field` `height_variant` / `box_height` / `nominal_length`) cez `hwSend` → `nxDocPayload`; panel si stav osi
  nepamätá. **Modal náhrady zatvára až potvrdenie servera:** `onSubmit` zamkne okno a pripne `ax_token` (`a<N>`), server vráti `NX.hwAxResult(ok, msg, token)`
  v každej vetve `handle_set_hardware_override` (len keď token prišiel), `onHwAxResult` porovnáva token; odmietnutie okno odomkne a hlášku ukáže v ňom.
- **Os `box` má pole, nie ponuku** (spojitý rozsah 58–360 mm): `hwAxNumHtml` = `<input class="axnum" data-axc="num">`; Enter alebo blur so **zmenenou** hodnotou
  zapíše (`onHwAxNum`), prázdne/nezmenené nepošle nič (nikdy `value: null`); v `conflict` a pri neurčiteľnom rozsahu sa pole nekreslí. Platnosť určuje len server
  (`Recipes.box_range`); klient overuje text prísne (`hwAxNum`: trim → čiarka → `^\d+(\.\d+)?$` → konečné a kladné). **Jedna editácia = jeden zápis:** po odoslaní
  `data-sent` + `disabled` (neodomyká sa, echo kreslí nové pole); `onmousedown` na `.hwax` označí `data-skipblur`, aby klik na iný ovládač radu neposlal aj blur.
- **Fokus prežije prekreslenie:** ovládače nesú `data-ax` + `data-axc` (`chip` · `sel` · `num` · `fix` · `unlock`), kľúč `a:<os>|<druh>` bez hodnoty.
- Testy: `tests/js/test_kovd2b_ui.js`, `tests/pure/test_kovd2b_payload.rb`, in-SU `run_kovd2b`.

**Riadok osiroteného zásahu** (`hwOffHtml`; `hwDisabledOffs` filtruje na `orphan`, `hwOffLabel`, `hwOffName` z `orphan_label`): `disabled` → „obnoviť"
(`onHwEnable`) · `invalid` a `dormant` → „zrušiť" (`onHwOrphanReset`, `reset: true`) · `part_material` → „zrušiť" vlastnou akciou. Dormantný riadok nesie zámok
a pod sebou serverovú poznámku `orphan_note` (`.axnote`; bez kľúča druhý riadok nie je) a chipy osí nedostáva. **Box zaniknutého vlastníka:** pri
`orphan_owner_gone: true` a vlastnom `owner_label` („(už neexistuje) · …") prepne `hwBoxGone(g)` hlavičku na statický `div` bez oka a `onHwOwnerPick`.

Testy kontextu: `tests/js/test_uic4_kovanie.js`, `tests/pure/test_uic4_kovanie.rb`, in-SU `run_uic4`. Plné znenie: archív, „Kontext Kovanie (UI-C4, …)".

### Riadok „Spotrebič" v Inspectore (ui/js/appliance_row.js + ui/panel/payloads.rb)

**Čo robí:** v Základných skrinky (a v karte dosky `#boardApplRows` — varná doska, drez) ukáže **jeden riadok cez oba stĺpce na každý viazaný spotrebič**, riadok
„očakáva" pre nesplnené očakávanie (`appliance_expects[]`, slot umývačky vždy) a **posledný riadok voľby „očakáva"**. Vzor riadku Nôh — žiadny sektor ani nadpis.
Veta riadku voľby: pri prázdnom zozname je pomocná („bez spotrebiča — nastav „očakáva"…") a `aprRowHtml` ju kreslí ako „?" za výberom (`.nxtip inl r`); pri neprázdnom
zozname je to stav („očakáva rúru") a ostáva viditeľný `.aptxt` pod riadkom (H6a; text aj payload zo servera bez zmeny).
Blok sa skrýva len pri kuse mimo matice vlastníkov a pri slote (ten voľbu nemá); skrinka a doska majú riadok voľby aj bez očakávaní (inak by sa očakávanie bez
šablóny nedalo zapnúť). Zápisy: `actions_appliance.rb` ([actions_appliance.rb](#actions_appliancerb)).

**Payload** `cabinet_payload.appliance_rows[]` / `board_payload.appliance_rows[]` skladá server (`Panel.appliance_rows`): `{state: 'bound'|'expected'|'expects',
item_id, category, category_label, text, sub, tone: 'ok'|'warn'|'', link, placeholder, options[], all, all_note}`; viazaný riadok navyše **`check`** = verdikt
(`{state, niche{state, axes, axis_texts, text}, door_split{state, edge, range, recommended, source, text}, text}`) a pri chladničke **`mount`**.
- **Riadok voľby** nesie úplný aktuálny zoznam a `options[]` = matica druhu v kanonickom poradí ako **príkazy** `{value: 'add:<kód>'|'del:<kód>', code, op, text,
  disabled}`; viazaná kategória `disabled` s dôvodom („− rúra (priradená — najprv odpoj)"). **Prvá voľba je neutrálny súhrn** (`placeholder`). **Klient posiela úplný
  nový zoznam** (`aprExpectsNext(current, value)` nad `data-apr-expects`). **Dve poistky proti rýchlym voľbám:** po odoslaní sa ovládač zamkne (odomkne ho čerstvá
  karta, ktorú server pošle aj pri odmietnutí) a snapshot `data-apr-expects` sa posunie optimisticky.
- **Splnenú kategóriu určuje tá istá funkcia ako zber** (`ApplianceBinding.bound_categories`, obojsmerný dôkaz) — osirelý záznam či recyklované ID riadok „očakáva"
  nepotlačia.
- Kontext nesie **`pid`** (`data-apr-pid` z `cabinet_pid` / `board_pid`). **Kontext vlastníka drží DOM** (`data-apr-kind` / `data-apr-id`), nie globál.
  **Popisky kategórií v JS nežijú** (text skladá server; Node sada nad zdrojom `appliance_row.js` a `templates.js`).
- **Tón viazaného riadku** sa pýta na tie isté vstupy ako `Validation.check_appliance_bound` a na ten istý verdikt `ApplianceChecks.verdict` (test porovnáva oba smery
  nad jednou fixtúrou): ORANGE len pri `clash`/`unsatisfiable`; pri chýbajúcom bloku niky má známy konflikt prednosť pred vetou „kontrola sa nedá urobiť". Vetu skladá
  server do `sub`; **JS o nike ani delení nevie nič**. Filter ponuky a verdikt merajú tou istou toleranciou (`ApplianceChecks` `AXES`, `axis_fits?`, `AXIS_TOL` 0,5 mm).
- **Ponuka modelov** = položky zákazky danej kategórie bez fyzického vlastníka, filtrované podľa niky vs vnútro skrinky len po osiach, ktoré kategória kontroluje (rúra
  a mikrovlnka Š + H, chladnička Š/V/H); skrinka s viac zónami vypne výškový filter (riadok to prizná). **Filter nie je brána** (nesediaci model ostáva s dôvodom,
  „— zobraziť všetky (N)"); **prvá voľba je neutrálna** („vyber model…").
- **Zápis** `set_appliance_owner` → `ApplianceBinding.apply!` (jeden krok Späť). Viazaný riadok má „odpojiť" (ikona `unlink`), nie druhý `<select>` (výmena modelu patrí
  do Štúdia — vedomá odchýlka od mockupu R9). **Ikona odkazu** → `openStudio('appl', 'appliance:<uuid>')`.
- **Echo:** riadok sa neobnovuje ľahkým pushom; po zápise z Rozpočtu alebo z pohľadu „V zákazke" posiela server celú kartu (`budget_geometry_proc` so zdvihom
  generácie pri prestavbe, `budget_card_proc` bez zdvihu pri väzbe na dosku). **Odchod z kontextu riadky zahodí** (`clearApplianceRows` aj s kontextom vlastníka).
- **Výška osadenia chladničky:** čip „osadenie 150 mm" (`mount: {value, text}`) len pri **obojsmernej väzbe** (`appliance_mount_editable?` = ten istý dôkaz ako
  serverový cieľ akcie); iná kategória, slot, doska, sirota ani jednostranný záznam čip nedostanú. Klik otvorí **statický** `#aprMountPop` za `#applRows` (prežije
  prekreslenie), ktorý pri otvorení **zachytí** dokument, vlastníka (druh, ID, PID), `item_id` a pôvodnú hodnotu. Zapisuje **výhradne „Použiť"/Enter, nikdy blur**;
  Escape (z ktoréhokoľvek prvku, spotrebuje sa), „Zrušiť" a klik mimo zrušia bez zápisu; neplatné či nezmenené číslo nič nepošle; fokus sa vracia na čip len keď
  bol v popoveri. `aprMountSync` nechá popover žiť len nad tým istým dokumentom, kusom a riadkom; zatvára ho aj `clearApplianceRows` a `nxDropDocState`
  (`aprMountClose`). CSS `.aprmountpop[hidden] { display: none }`.

Plné znenie: archív, „Riadok „Spotrebič" v Inspectore".

### Karta dielca (UI-D1, panel.html + ui/js/part_card.js + ui/panel/actions_parts.rb)

**Čo robí:** pri označenom dielci skrinky ukáže jeho rozmery, materiál, smer dekoru a hrany a dovolí ich zmeniť. Poradie: **Základné hore** (`#pcBasic`) · Materiál ·
hrany · **rad akcií dole** („Označiť v modeli", „Použiť na podobné…"). Dáta: `part_card` payload (`Panel.part_grain_payload`, `part_cut_payload`, hrany D-102),
zápis `set_part_material` / `set_part_edge` / `set_part_edges_all` / `set_part_grain` (`actions_parts.rb`).

- **Meno roly skladá server** (H12d): payload nesie `role_label` (`PartKeys.role_label` — rovnaké slovo ako stĺpec Rola v Kusovníku); hlavička karty
  (`#pcName`, `#pcName2`), veta modalu „Použiť na podobné…" a položka raily (`nxTempLabel` v `bridge.js` — v režime `part` je `sel` vždy payload karty)
  ho len vypíšu cez `pcRoleText` (`pc.role_label || pc.role`). JS mapu mien rolí nemá (guard T3f v `tests/pure/test_h12d_mena_roli.rb`); payload bez kľúča
  ukáže surovú rolu. `pc.role` ostáva pre vlastnosti roly (`isFront`, hrany).

- **Rozmery dielca sú VÝSTUP** — informačné riadky `.inforow` v mriežke `.basicgrid`/`.infocol` (nikdy polia). **„Do nárezu"** pod Hrúbkou len pri platnom
  `cut_size` (napr. chrbát v drážke): Dĺžka/Šírka ostávajú rozmer modelu, texty skladá server (`Panel.part_cut_payload`: `cut_text`, `cut_title`, `model_title`).
- **Preklik na dekor** (`#pcMatLink`/`#bcMatLink`, `.matlink`, v existujúcom riadku): `nxDecorLinkState` → `openStudio('mat', material_id)` (funkcia v `part_card.js`,
  karta dosky ju volá); bez rozhodnutého materiálu `aria-disabled`; ABS pásky sa neprelinkúvajú.
- **Smer dekoru je VSTUP** — segment `#pcGrainRow` (`.pcgrain`) `inherit | length | width`; zápis `set_part_grain` → `Panel.handle_set_part_grain` (enum guard
  `CabinetBuilder::GRAIN_OVERRIDES`, guard dokumentu aj skrinky, jedna prestavba = jeden krok Späť). **Texty skladá server** (`Panel.part_grain_payload`): dedený
  stav ukazuje výsledok („Podľa materiálu — pozdĺžna"), každá voľba nesie v tooltipe **výrobný rozmer** (počítaný z rozmeru do nárezu `Bom.cut_dims`).
  **Autoritou zobrazeného výsledku je snapshot dielca** (`grain_effective` = `cfg['grain_direction']`), katalóg dáva len prospektívne `grain_pending`
  (`CabinetBuilder.effective_grain`) — rozdiel karta povie hintom. Sentinel dedenia na drôte je **`__inherit__`** (`nxGrainWire`, zhodu zamyká test). Chýbajúce
  `grain_options` segment zamknú a popisy vrátia na neutrálnu zálohu; materiál bez smeru segment zamkne (`aria-disabled` + hint) a klik odvedie na materiálový
  combobox (`onPartInfoGrain` → `nxRevealTarget` + `NXCombo.open`). Ručný zásah je jantárový `.ovr`. Stav segmentu: čistá `nxGrainSegmentState`.
- Po zmene katalógu `push_materials` pošle aj čerstvý payload karty (`push_part_card` → `NX.setPartCard`; čisté čítanie, bez označeného dielca nič).
- **Hranový riadok** začína ikonou `#i-edge` so štyrmi rotáciami `data-rot`; uhol dáva **strana v 2D náhľade** (`pc.edge_sides` = `AbsRules.edge_sides`).
- **„Hrúbka" klikateľná nie je** (určuje ju materiál korpusu).

**Zápisové guardy karty** (zápis do modelu aj do globálneho katalógu ABS ide až za nimi; odmietnutie nevyrobí krok Späť):
- **Jedna brána `part_target_error(model, cab, params, rk, what)`**: **dokument** (`model_guid`), **cieľ zmeny** (vo výbere musí byť dielec s kľúčom karty — výber
  presunutý na skrinku = odmietnutie, inak by sa prestavalo vnorené dvojča) a **odpojenosť**. Stojí za `existing_params` + `canonical_part_key`, pred
  `virtual_duplak_probe`/`ensure_missing_abs`. Prázdny výber je odmietnutie; bulk olep má vlastnú tichú vetvu `if part.nil?` pre stale echo.
- **Odpojenosť `detached_part_error`** (`nested_part?` — vnorený dielec má za rodiča definíciu skrinky) prechádzajú VŠETKY zápisové cesty: hrana
  (`handle_set_part_edge`), bulk olep (`handle_set_part_edges_all`, odmietnutie hlási), materiál, smer dekoru aj zdroj „Použiť na podobné" (`similar_context`).
  Hláška menuje čo sa nezmenilo a čo robiť. Dôvod: zápis by inak zmenil vnorené dvojča a do objednávky by išla páska, ktorú nikto nevidel.
- **„Označiť v modeli"** (`nx_select_part` → `Panel.handle_select_part`): čisté čítanie + zmena výberu, prísny guard dokumentu aj skrinky, dielec podľa `part_key`.

**„Použiť na podobné…"** (`#simModal`) prenáša **výhradne olep hrán**. **Definícia „podobný" žije len na serveri:** rovnaká **rola** + rovnaký **výsledný materiál**
(`material_id` zo snapshotu) v rozsahu `cabinet` | `project` (`SIMILAR_SCOPES`), okrem zdroja; kandidáti z `regenerated_parts` (len vnorené dielce — tie, ktoré
prestavba naozaj prekreslí). **„Celý projekt" = zákazka** (`Panel.job_cabinets`, top-level); skrinka s odpojeným dielcom sa v oboch rozsahoch **preskočí**
a vymenuje (`similar_parts_map` vracia `[mapa, preskočené]`, vetu skladá `similar_skipped_text` → `#simSkipped`).
- **Živý počet aj zápis idú jednou funkciou `similar_parts_map`**; JS posiela len `role_key + scope`, odpoveď `NX.setSimilarCount` prijme len posledný dopyt
  (rastúci token `req`, vrátený aj z chybovej vetvy; chyba nesie požadovaný rozsah).
- Zápis = **jedna operácia** `CabinetBuilder.rebuild_many` (jeden krok Späť naprieč skrinkami); prenáša sa záznam overridu (prázdny override vráti ciele na pravidlo),
  `edge_warnings` cieľa sa zahodia, vo výbere ostáva zdrojový dielec (`focus_part`). Modal drží identitu z času otvorenia, zatvára sa pri inom dielci či odchode
  z `mode-part`; pri tej istej identite sa počet vypýta znova. **Enter modal neodchytáva.**

Testy: `tests/pure/test_uid1_dielec.rb`, `tests/js/test_uid1_dielec.js`, `tests/pure/test_abs_odpojeny_dielec.rb`, in-SU `run_uid1` a `run_k1`.
Plné znenie: archív, „Karta dielca (UI-D1, …)".

### Vkladacia karta — šablóny, typ a doska (UI-C1a/C1b/C1c; ui/panel/payloads.rb + ui/panel/actions_templates.rb + ui/js/insert_state.js · form.js · board_card.js)

**Čo robí:** v režime vkladania (`Panel.show_insert`, nič nie je označené) vyberie typ objektu, šablónu a rozmery a vloží skrinku (ghost na kurzore) alebo dosku.
Typy v jednom rade segmentových tlačidiel: **Dolná · Horná · Rohová · Umývačka · Doska** (HTML statické, guard `test_h12c_js.rb` ho porovná s registrom —
`label`, `ui_order`; typy vkladania = `NXInsert.insertTypes()` = `NXTypes.ids()` zo servera + `board`, skladá sa **pri volaní**, nie pri načítaní — A1).
**Autorita typu je čistý stav** `NXInsert.insertType()/setInsertType` (DOM je zrkadlo; neznámy typ aj pred `NX.init` = dolná, `NXTypes.norm`). Zmena typu korpusu zahodí korpusovú šablónu (ponuka je typovo filtrovaná),
prepnutie Korpus↔Doska výbery nezahadzuje (sklady `template`/`boardTemplate`).

**Knižnica:** `Panel.template_list` posiela celú knižnicu; záznam nesie `kind` (`cabinet` | `board`), `used_seq` (`TemplateUsage.map`, do súboru šablón sa nezapisuje;
`usage: false` ho vynechá — sekcia Šablóny Štúdia), odvodené `hardware: {has, labels}` (`TemplateStore.hardware_tile_summary`), `construction: {has, text}`
a `vent_note`. Filter podľa druhu robí klient (`NXInsert.templatesForType` / `templateGroups` nad `templateKind`; typ slotovej šablóny sa nesklápa na `lower`) aj server.
- **Dlaždice** v `<details data-key="itpl">`: „Naposledy použité" (max 3 podľa `used_seq`) + „Všetky šablóny". **Mriežka sa prestavuje len pri zmene typu alebo
  novej knižnici** (`renderTemplateTiles(force)`, `dataset.forType`); výber prepína len triedu `.on` (zahodený uzol by druhému kliku dvojkliku vzal cieľ). Klik
  aj **dvojklik** chytá jedna delegácia na `#tplTiles`; dvojklik volá tú istú validovanú `insertCabinet()`/`insertBoard()` ako zelené tlačidlo.
- Kresba dlaždice je schéma z configu (`nxTplGlyph`) bez farieb; dosková má badge hrúbky (`nxTplBadge`), kovanie ikonu `wrench` (`nxTplHardwareBadge`); tooltip
  `nxTplTitle` = súhrn konštrukcie · kovanie („zámky sa neprenášajú") · vetranie · umiestnenie dosky. `setTplMeta` pri šablóne s kovaním použije `#tplHint`
  (max 80 znakov, celé v `title`). **PNG náhľad a schéma zdieľajú box** `.tplpic` (38 px, `object-fit: cover`): `<img>` je v dlaždici od začiatku bez `src`
  a len sa odkrýva (`.tplpic.has`, `onerror` triedu odoberie); pull `nxTplPreviewPlan`/`nxTplPreviewStore` — bez `preview_rev` sa nepýta, cache per revízia
  vrátane zápornej odpovede.

**Insert payload a pečiatka použitia:** payload nesie identitu šablóny (`template_kind` + `template_name`); `Panel.take_template_ref!` ju odstráni pred builderom
a `stamp_template_used` po úspešnom vložení záznam znovu nájde, overí druh a opečiatkuje (samostatná operácia mimo `start_operation`, zlyhanie len log; potom
`push_templates`). Pri korpuse ide pečiatka až po **kliku** ghostu a presne raz (`PlacementSession#stamp_once!`). **Deklarovaná šablóna, ktorá medzitým zmizla,
vklad odmietne** (`TemplateStore.find(*tpl_ref).nil?` pred stavbou); vklad bez referencie ide ďalej.
- **Autoritou slotových polí je uložený záznam šablóny**, nie CEF: `Panel.apply_template_slot_fields!` doplní chýbajúce `dw_*` (a polia rohovej) a prevezme
  `appliance_expects[]`. Vložený slot nikdy nenesie väzbu na konkrétny spotrebič.
- **Preflighty tela a chrbta sa slotu netýkajú** (`Panel.slot_params?` — preskočia sa pred prvým čítaním materiálu, aj `insert_thickness_preflight`); remap ABS
  overridov ostáva a hrúbku čela stráži `CabinetBuilder.validate_material_thickness!`.

**Rohová vo vkladaní:** karta sa materializuje z predvolieb typu s rohovou zostavou (`nxCornerDefaults` = `DEFAULTS[id]` registra, `corner_insert_defaults`
s `corner_th2`) alebo zo šablóny; dverová časť a CR sú polia
`#cornerRow` (bežný zber), **strana** je stav registra `cornerDraft` (`nxSetCornerDraft`) a do payloadu ju výslovne pridá `insertCabinet` len pri rohovej. Prepnutie
strany zrkadlí aj **návrh čiel** (`nxCornerMirrorFronts`: okraje vľavo ↔ vpravo, smer pántov, strana profilu; `unset` a chýbajúci kľúč ostávajú). Riadok Nohy
platí aj pre rohovú. **Strana klávesom D počas ghostu:** ghost ohlási stranu (`NX.ghostCornerSide` → `nxGhostCornerSide`), prepne ju **tá istá `onCornerSide`**
(nová strana zo stavu karty `nxCornerSide`) a karta pošle ten istý payload ako „Vložiť" (`nxInsertPayload`) callbackom `ghost_corner_side` →
`Panel.handle_ghost_corner_side` (ghost prevesí na nový plán s prevzatou polohou; označená skrinka, iný typ karty či červené pole kláves odmietnu). Pásik ghostu
nesie `#gbCorner` (`corner_label`, `nxGhostCornerText`), nápoveda `NX_GHOST_HELP.corner`. Odhad pripočíta zostavu (`nxCornerStatsAdd` nad `corner_preview.stats`).

**Modal „Uložiť ako šablónu"** (nad označenou skrinkou): Názov · Typ (`#tplSaveType`: Dolná/Horná + Umývačka a Rohová, ktoré sú **zamknuté** a ponúkajú sa len nad
sebou — `nxTplTypeLock` = `template_type: locked` + vety `template_lock` z registra; server prepína len prepínateľné typy, `apply_template_type!` pri slote nerobí
nič) · **Očakáva** (pri type, ktorý je sám vlastníkom spotrebiča — `appliance_owner: slot`) (skupina checkboxov `#tplSaveExpects`
`fridge · oven · microwave`; pri slote veta „Slot umývačky očakáva umývačku vždy" a `expects` sa neposiela; chýbajúci kľúč = očakávania sa nemenia). Predvyplní sa
z `appliance_expects[]` skrinky (`cabApplianceExpects`), autoritou je modal. Validácia `Panel.apply_template_expects!` pred `TemplatePreviews.capture`
aj `TemplateStore.upsert`. Uloženie čaká na flush (`nxCabinetAction`); zmena polí ruší odložené uloženie.

**Kovanie šablóny v insert stave — dva zoznamy kľúčov, ani jeden default:** `NXInsert.HARDWARE_KEYS` (`hardware_sets`, `hardware_set_defs` — mapy, `plainMap`)
a `HARDWARE_LIST_KEYS` (`hardware_manual` — pole, `plainList`). Prázdne = `null` = kľúč sa **neposiela** (guard test); zmrazené definície bez mapovania sa nulujú,
ad-hoc položky nie. `insertCabinet()` vymaže z payloadu `hardware_manual` pred priložením šablónových kľúčov (`collectAll()` nesie echo označenej skrinky).
V korpusovej karte je ad-hoc kovanie pass-through: `bridge.js` odloží `hwManual` presne zo servera (`Array.isArray(...) ? ... : null` — **nikdy `|| []`**,
inak by apply položky zmazal), `collectAll()` ho pošle len keď existuje, odchod z korpusu pamäť vyčistí.

**Doska vo vkladaní** (`board_card.js`):
- Kontrakt hrúbky doskovej šablóny (`core/templates.rb board_tpl`) plní `applyBoardTemplate`: `material_id: nil` predvyplní UNI materiál roly „Doska"
  (`uniBoardSheetId` nad `uni_role`) a **až potom** dosadí hrúbku šablóny. Autoritou hrúbky ostáva `BoardBuilder.insert_thickness_for` (pri reálnom materiáli
  katalóg — karta to povie). Smer dekoru zo šablóny je vedomá voľba (príznak D-86).
- **Rozpísané hodnoty proti živému refreshu katalógu** (`NX.setMaterials` → `refreshInsertBoardMaterials`): hrúbka sa zapíše len podľa
  `insertThicknessShouldWrite` (pri nezmenenom UNI materiáli drží draft), smer dekoru podľa `insertGrainShouldWrite` (pri nezmenenom materiáli drží vedomú voľbu).
  Marker „pre ktorý materiál je pole zosynchronizované" je **vlastný pre každé pole** a pri zápise potlačenom fokusom sa neposúva (`insertMatMarkAdvances`);
  krok smeru je automat `insertGrainSync` (`tests/js/test_e03_board_insert.js`).
- **Orientácia** (`Naležato · Nastojato · Na stenu`, `#insBoardOriRow` / `data-ins-ori`): autoritou je `NXInsert.boardOrientation()/setBoardOrientation`, nastavuje sa
  **explicitne pri každej materializácii karty** (`materializeInsertBoardCard` pred `applyBoardTemplate`); payload nesie `orientation` vždy, server ju prepustí do
  `BoardBuilder.norm_orientation`.
- **Zámky D-39** majú rozsah: doska má vlastné `length`/`width` vo vlastnom úložisku a do Ruby nejdú (`Panel::INSERT_LOCK_FIELDS` je korpusový).

**Informačný stĺpec pri vkladaní** nesie **odhad** `nxDraftStats` (značka ≈; serverový `cabinet_stats` číta snapshoty vloženej skrinky); pri doske hrúbka
a plocha. Zelené **Vložiť** je posledné v karte. Náhľad: projekcia `insert` (odsek Náhľad).

Testy: `tests/js/test_insert_state.js`, `tests/js/test_uic1b_vkladanie.js`, `tests/js/test_uid2_nahlady.js`, `tests/js/test_uic1c_orientacia.js`,
`tests/pure/test_uic1a_sablony.rb`, `tests/pure/test_uic1b_vkladanie.rb`, `tests/pure/test_uid2_nahlady.rb`, `tests/pure/test_uic1c_orientacia.rb`, in-SU `run_uid2`
(kamera, `write_image`, žiadny undo krok) a `run_uic1c`. Plné znenie: archív, „Vkladacia karta — …", „UI-C1b", „UI-C1c".

### Karta označenej dosky (ui/js/board_card.js + ui/panel/actions_board.rb)

Karta Doska pri označenej samostatnej doske: rozmery, materiál a hrany, orientácia. Všetky zápisy nesú echo `board_id` a idú cez guard dokumentu (odsek
`actions_board.rb`). **Orientácia** (`#boardOriRow`, `data-bc-ori`; `syncOrientationSegments`) → `set_board_orientation` → `Panel.handle_set_board_orientation`:
odmietne neznámu požadovanú aj uloženú hodnotu, rovnaká hodnota = no-op, inak jedna prestavba s deltou transformácie = jeden krok Späť +
`ScaleWatch.remember_transform`; pred odoslaním `flushBoardEditsNow`. Payload `Panel.board_payload` nesie `orientation` + `orientation_label` a meno roly `role_label` (`PartKeys.role_label`, H12d — JS ho neprekladá); neznámu hodnotu
nepreklasifikuje (žiadny segment nesvieti).

### Klikateľnosť a deep-linky (UI-D3, ui/js/bridge.js + shell.js + boot.js + ui/studio_dialog.rb)

Zásada kontraktu: **všetko informačné je klikateľné a vedie tam, kam ukazuje** (klikateľné údaje karty Korpus: odsek „Kontext Korpus").

**Warnpanel:** ⚠ chip v hlavičke otvára **overlay** `#warnList.warnpanel` (`position: absolute` vnútri sticky `<header class="nxhdr">`); výška ohraničená
viewportom, scrolluje len `.wrows`. Viditeľnosť mení jedna funkcia `setWarnPanel` cez **triedu `.open`** (nie inline `display` — prebíjal by `display: flex`);
zavretý stav je default v CSS. Zatváranie: `bindWarnPanel` v `boot.js` (klik mimo, Escape s fokusom na chip; klik v paneli a na chip zastaví bublanie). Merač
D-25 (`usage.js`) počíta klik v **capture** fáze, inak by mu overlaye vypadli.
- Riadky skladá čistá **`NXShell.warnRows`** z upozornení stavby (`cabinet_payload['warnings']`, kontrakt `code/severity/message/part_key/data`); upozornenie bez
  textu sa zahodí, `part_key` sa nikdy neupravuje. Nález o **nepostavenom dielci** (`WARN_PART_NOT_BUILT` = `part_skipped_degenerate`, `shelf_skipped_shallow_zone`)
  spadne na korpus — nový kód nepostaveného dielca patrí sem a do testu (rovnako drží `ui/production_core.rb`).
- **Oko v riadku** ide existujúcou cestou `nx_select_hw_owner` s `origin: 'warn'` (`SELECT_OWNER_NOUNS`; neznámy pôvod = `hardware`) a s flush handshake.

**Deep-link do Štúdia:** `openStudio(section, anchor)` → `NXShell.studioOpenLink(...)` → `open_studio` → `Panel.studio_link_of` → `StudioDialog.show(open_section:,
anchor:)`. Panel posiela **iba meno**, autoritou whitelistu je Ruby (`StudioDialog::SECTIONS`); `NXShell.studioSection` filtruje registrom `NXStudioSections`. Cieľ sa odloží
(`@pending_section`/`@pending_anchor`) a **jednorazovo ho spotrebuje najbližší `push_state`** (polia `open_section`/`anchor` v `NX.setStudio`); kotva cestuje len so
sekciou; bez deep-linku (rail, toolbar) je `nil` a sekcia sa nemení. Cesty: warnpanel → „Otvoriť v Štúdiu → Kontrola" (`openStudio('ctrl')`) · „Materiál"
v info stĺpci → `bom` s kotvou ID skrinky · preklik na dekor → `mat` s `material_id`.

**Názov zákazky** sa edituje na jedinom mieste — v hlavičke Štúdia (odsek okna ŠTÚDIO, „Hlavička — názov zákazky"); JS ho do exportu neposiela ako názov, len ako
kontrolu `expect` (autorita `ExportSettings.project_name`, od H7a v jadre).

Testy: `tests/pure/test_uid3_klikatelnost.rb`, `tests/pure/test_st1a_studio.rb`, `tests/js/test_uid3_klikatelnost.js`, `tests/js/test_st1a_studio.js`, in-SU `run_st1a`.

### Výrazy v rozmerových poliach

`expr.js` parser bez eval (`650-36` + Enter, živý náhľad `= 614`, šípky ±1/±10); surový výraz neopúšťa JS; auto-apply s identity guardom (snapshot cabinet/board id).
Statické polia pripája `bindExprFields` (boot.js) menovitým zoznamom — **nové rozmerové pole doň musí pribudnúť**, inak by debounce pri písaní `50-20` odoslal
medzistav `50-2`.

### D-41 modal chýbajúcej ABS

(`absModal` v paneli): zmena materiálu/bulk olep na dekor bez použiteľnej 1,0 pásky → „Vytvoriť a pokračovať / Bez ABS / Zrušiť". JS `absUsableExists` je len UX
zrkadlo — **autorita je server** (flag `create_missing_abs`, kontroly PRED katalógovým zápisom); part callbacky nesú `cabinet_id` identity guard.

## Súbory Inspectora — panel.rb + ui/panel/*.rb

Register serverovej strany Inspectora. Kontrakty kontextov a kariet sú v odsekoch vyššie — tieto nadpisy sú rozcestník „ktorý súbor patrí ku ktorému odseku"
a poistka, aby žiadny nový súbor nezostal mimo mapy (guard test). `actions_zones.rb` má vlastný odsek pri Kontexte Zóny.

### panel.rb

Centrálne callbacky Inspectora (`Panel.*`) — vstupný bod všetkých volaní `sketchup.*` z panela (`UI::HtmlDialog`, `STYLE_DIALOG`). Kontrakty sú v odsekoch kontextov
a kariet; zápisové handlery idú cez guard dokumentu (`sync.rb`).

### payloads.rb

Doména panela: **skladanie payloadov pre klienta** (`cabinet_payload`, `board_payload`, `part_card`, `template_list`, `materials_payload`). Všetko sú **čisté
projekcie** uloženého configu a plánu — žiadny zápis. Kontrakt vkladacej karty a knižnice: odsek „Vkladacia karta".

- **`front_slots`** (`front_slots_payload`): `front_id → { 'wings_n', 'slots' }` z jedinej definície aplikovateľnosti smeru `Fronts.direction_slots` nad uloženým
  `front_items`; `state` prechádza nezmenený (nil = legacy, `unset` = vedome neurčené, `left`/`right`). **`wings_n` je súčasťou záznamu**, pri neznámom počte `nil`
  (`{ nil, [] }` = priznané neznámo). Server je autoritou na „kde sa smer pýta"; zo slotov kreslí aj náhľad Kovania stranu pántov.
- **`front_opening`** (`front_opening_payload` → `Construction.front_opening`, serializuje `opening_json` v `actions_cabinet.rb`): čelný otvor uloženého stavu
  `{x0, w, z0, h}`; poškodený config = nulová šírka, výnimka = `nil`.
- **`corner_th2`** (len pri rohovej): účinná hrúbka CR 2 (`corner_th2_payload` = `CabinetBuilder.aux_part_thicknesses` → override dielca → čelový kanál → 18).
  Predvoľby vkladania `DEFAULTS.corner_blind` = `corner_insert_defaults(model)` (`CORNER_DEFAULTS` + `corner_th2`).
- **`corner_preview`** (len pri rohovej; uložený stav `corner_preview_stored`, živé polia v odpovedi preflightu): čistá `corner_preview_json(params,
  part_thicknesses)` = `CabinetBuilder.normalize` → `Construction.corner_parts` nad `interior_dims` (jediná autorita, parita s plánom `test_rohb2_nahlad.rb`
  a modelom in-SU `run_rohb2`) → `parts` `{role, x0, x1, z0, z1, title}` (blenda, výstuha, CR 1, CR 2; výstuha závesov sa nekreslí), `dims`, `fits`/`need`
  (`corner_fit_width`), `door_w` (otvor − okraje z `Fronts.resolve_layout`), `stats` (`count`/`area`). Iný typ aj chyba = `nil`.
- **`slot_payload`, `cabinet_stats`, `legs_summary`, `appliance_rows`, `preview.appliances[]`** — odseky „Kontext Korpus", „Náhľad" a „Riadok Spotrebič".
  Od H12b: `slot_payload` len pri type bez korpusu (`!CabinetTypes.carcass?`), druh riadkov spotrebiča = `appliance_owner` typu, `template_config_from` polia
  rohovej pri `corner?` a komín/zapustenie/lišty pri `carcass?`.
- **`template_list`** (vkladacia karta, `push_init`, `push_templates`; Štúdio cez `tile_row`) — od H12b každý záznam **korpusovej** šablóny nesie aditívny
  **`type_word`** (`template_type_word(rec)` = `word` z registra, neznámy/prázdny/chýbajúci typ „dolná"; doska kľúč nemá). Od H12c ho Štúdio zobrazí na dlaždici
  (`tplTypeWord` — bez kľúča prázdne, okno typ samo neprekladá).
- **`front_drawer`** (`front_drawer_payload`, len čelá, ktoré `Recipes.classified?` pozná ako zásuvku; do `front_slots` sa nezlučuje): položka výsuvu
  `source: 'recipe'` → `state: 'ok'` + `text` a `detail` (`Recipes.explain_stored(params, axes:)` z uložených parametrov a pripnutého receptu; nečitateľný recept =
  prázdny zoznam) · `drawer_conflicts` čela → `conflict` s vetou stavby · `config_schema < DRAWER_ACTIVATION_SCHEMA` → `stale` · inak `pending`; `sync` sa viaže na
  čelo cez `warnings[].data.front_id`; zlyhanie = `{}`. Vety „čo je v balení": `drawer_buy_lines` → `item_purchase` → `HardwareSets.explain` s kontextom
  `drawer_buy_ctx` (raz na payload, lenivo) **zhodným s nákupným riadkom** (pri projekte bez snapshotu a nepoužiteľnej knižnici `blocked: true` ako
  `decorate_hardware_purchase`). Kľúč **`upgrade`** (`attach_front_drawer_upgrade`) len keď existuje vydaná vyššia verzia pripnutého receptu (`active_ref == :known` ·
  `latest_for` · `Recipes.upgrade?`) a len pri `state: 'ok'`; nesie `cabinet_id` a `front_id` (identitu skladá server); dopad sa tu nepočíta (samostatný callback).
- **`axes` a `lock`** — `drawer_axes_index` jedným prechodom čiel dá `by_owner` (stav osí; `drawer_axes_map` je tenký obal) a `idents` (identita zápisu
  `owner_part_key` · `slide` · `recipe:<id>`) — druhý prechod by znamenal druhé `Recipes.load`. Index sa počíta **pred** `front_drawer_payload` (aj vo
  `front_drawer_refresh`). Osi visia na položke výsuvu (`attach_drawer_axes`, len `source: 'recipe'`), na riadku ručného zásahu (`attach_override_axes` — pri
  konflikte položka nevznikne) a na `front_drawer[fid]` (`attach_front_drawer_axes`, `lock` = identita + `cabinet_id`). Os nesie `state` (`auto` | `locked` |
  `conflict`), `value`, `options` (len hodnoty, ktoré sa dajú zamknúť a zmestia sa), pri konflikte `message` a `proposal`. **Os v `conflict` má vždy `message`**
  (uložený dôvod len pri zhode kódu, inak `Recipes.height_lock_problem` / `nl_lock_problem`); návrh mení len opravovanú os, bez platnej náhrady `proposal: nil`.
  **Quadro nemá kľúč `height`, Atira nemá `box`.** Os **`box`** = `{ state, value, min, max, message?, proposal? }` z jedinej `Recipes.box_range` (skutočná hrúbka dna);
  `max` = automat = `proposal` pri konflikte; prázdny/neurčiteľný rozsah = `nil`. Pri konflikte výšky je ponuka NL prázdna (`blocked_by: 'height'`). Kontext sa
  prepočítava z plánu (`CabinetBuilder.drawer_axis_contexts` → `Construction.drawer_contexts`) — tými istými číslami ako `Recipes.resolve`. **Osi dostane len
  záznam pripnutého receptu** (`active_lock_rules`); dormantný zámok iného receptu ostáva v zozname bez chipov a `hardware_overrides_payload` (s tým istým indexom)
  ho označí `orphan_kind: 'dormant'` s `orphan_label` a `orphan_note`.
- **`front_lift`** (`front_lift_payload`, riadky typu `lift`; zrkadlo `front_drawer_payload`): uložený dôvod z `hardware_conflicts` vlastníka `front:<id>/flap`
  s kódom z registra `BuildPlan::HW_CONFLICT_CODES` → `conflict` · položka `HardwareSets.lift_item?` → `ok` · jej absencia → `stale` **podľa `Bom.flap_stale_front?`**
  (tá istá autorita ako RED `flap_stale`, vrátane výnimky pre úplnú ručnú zostavu `HardwareSets.manual_flap_assemblies`) · inak `pending`. ORANGE len z `warnings`
  čela s kódom z `LIFT_WARN_CODES`. Text (`lift_row_text`) a detail (`lift_detail_lines`) výhradne z uložených dát; **štítok `lift_source_tag`** = `automat` len pri
  chránenom seed pravidle (`HardwareRules.protected_lift_item?`), `ručne` pri `source: 'manual'`, inak žiadny; čísla, ktoré na položke nie sú, sa nedopočítavajú;
  KH a KB tým istým vzorcom ako kontext pravidiel. Expanzia raz (`item_expansion` → `buy_lines`); záznam s `reason == lift_set_incomplete` → `state: 'incomplete'`
  s vetou `Validation.lift_incomplete_sentence` (tá istá ako Kontrola). Nesie ho aj ľahký push.
- **`hardware_set_options` a owner výbery:** typ z kľúča a rozsah vlastníka cez `HardwareSets.mapping_key_type` a `owner_scoped_key?`.
  `own_count` = rôzne víťazné vlastné kľúče z `item_mapping_source` nad položkami daného typu. `owner_overrides` prenáša plochých vlastníkov;
  pri klasifikovaných dvierkach skutočný `hinge@krídlo` číta `compat.owners`, pri ostatných klasifikovaných položkách owner triedny kľúč.
  Poškodený plochý výber nesie `invalid` a text „neplatný výber (uložený výber)"; poškodený skrinkový výber aj `override_label` a `owner_default_label`.
  **Uložené vs. účinné overridy (H18):** pri chýbajúcom snapshote a nekompatibilnej knižnici sú účinné `{}` (`hw_purchase_blocked?` / `hw_purchase_overrides`,
  zdieľané s `decorate_hardware_purchase` a `drawer_buy_ctx`). Hlavička a dedenie z účinných; uložená hodnota zostáva viditeľná. Stav `:invalid` ako predtým.
- **`compat`** (`nil` = plochý zoznam): `cab` a `owners[owner_part_key]` s `class_key` · `class_label` · `scope_label` · `none_label` · `options`
  (`HardwareSets.class_set_options`, kompatibilné a aktívne) · `current` · `stored` + `value_text` (uložená hodnota mimo ponuky — `disabled`).
  `none_label` cez `hardware_source_none_label`: sonda bez vlastného kľúča, pri skrinke aj bez vlastníka; zdroj `cab_class` = „skrinky", `cab` =
  „staršieho výberu skrinky", projektové úrovne a žiadny zdroj = „projektu". `current` je ID celej voľby (aj selektora), nie výsledný set z pásma.
  **`cab` len pri jednej nenulovej triede**; zmiešaná skrinka `cab: null` → riadok skrinky sa nekreslí (`hwCabRowOff`, `hwDropSetRow`), Sety odkážu na čelo.
  JS iba kreslí, posiela pôvodné `set_id` / `value`; kľúč skladá `HardwareSets.apply_cabinet_override`. H18 jeho zápis nemení (D-150 čaká na Q2).
  Testy `test_kovd1b_ui` a `test_h18_sety_pravda` (Ruby + JS).

Plné znenie: archív, „payloads.rb".

### resolvers.rb

Doména panela: rozlíšenie virtuálnych materiálov (`resolve_virtual_material`). Fan-out cesta po zápise do katalógu je v [materials.md](materials.md), odsek
„materials_* — spoločný kontrakt".

### selection.rb

Doména panela: observery výberu a transakcií, kamera a serverové cesty zmeny výberu (`handle_select_parts`, `handle_select_hw_owner`, `handle_camera_focus`,
`handle_clear_selection`; „Označiť v modeli" karty dielca `handle_select_part` žije v `actions_parts.rb`). Kontrakty: odseky „Observery panela", „Kontext Kovanie",
„Náhľad", „Karta dielca".

### sync.rb

Doména panela: **všetky pushe Ruby → JS** (`push_init`, `push_selected`, `push_templates`, `push_materials`, `push_part_card`, `push_hardware_sets`, `set_status`)
+ identita dokumentu (`model_guid`) a malé echo kanály prepínačov raily (`push_edge_check`, `push_grain_check`, `push_tags`). Zásada: **echo push nesmie prekresliť
rozpísaný formulár** — katalógové a stavové zmeny majú vlastné úzke kanály. `push_selected` nesie aj `push_tags(tags_state(model))` (Späť/Znova, prepnutie dokumentu,
zmena výberu). `push_init` posiela predvoľby typov (`defaults` → JS `DEFAULTS`) cez **`init_defaults(model)`** = `CabinetBuilder::DEFAULTS_BY_TYPE` v poradí
`IDS` (tie isté objekty ako `*_DEFAULTS`), typ s rohovou zostavou cez `corner_insert_defaults(model)` (+ `corner_th2`) — H12b, JSON bajtovo ako predtým (golden
`panel.json`). **Od H12b nesie aj `cabinet_types`** = `CabinetTypes.client_payload` (register typov pre klienta, zmluva `tests/fixtures/h12_cabinet_types.json`);
od H12c ho JS nasadí **prvým príkazom `NX.init`** do `NXTypes` (odsek CONSTRUCTION_FIELDS → JS register typu) — pred predvoľbami a výberom.

**Deep-link kanály Kontroly** sú dva a len na čítanie: `push_focus_front(front_id)` otvorí kartu čela, `push_focus_hardware(target)` prisvieti riadok v Kovaní
(adresa `owner_part_key` + `generic_type` + `rule_id` + `orphan`); server si nič nepamätá; zatvorený Inspector ani neúplná adresa nedostanú nič.

**Guard identity dokumentu `foreign_document?(data, model, what)`** — jediný guard, ktorým prechádza **každý zápisový handler panela** (porovnanie robí zdieľaný
`DocKey.foreign?` v prísnom režime). Panel je jeden pre všetky dokumenty, callback je asynchrónny a ID sú jedinečné len v rámci modelu, takže echo
`cabinet_id`/`board_id` prepnutie dokumentu nezachytí. Porovnanie je **prísne** (prázdny guid = okno bez dobehnutého `NX.init`, nezapisuje); nezhoda = **hláška**
(`set_status` + `Engine.log`). Klientsky protipól **`nxDocPayload(obj, guid)`** v `shell.js` je jediné miesto, kde zápisový payload dostáva `model_guid`
(`nxZonePayload` pridáva aj `cabinet_id`); in-SU runner posiela ten istý tvar (helper `pg(model, hash)`). Rozsah stráži `tests/pure/test_r02_doc_guard.rb`;
`handle_set_part_grain` má vlastný, tvarom starší guard.
- **Zachytená identita, nie identita pri odoslaní:** odložené cesty čítajú `nxDocGuid()` pri naplánovaní a podávajú ju druhým argumentom — auto-apply korpusu
  (`form.js`, `guidSnapshot`) a polia karty dosky (`board_card.js`, `boardPending.guid`); karta dielca berie `partCard.model_guid`. Prázdny reťazec je platná
  zachytená hodnota (helper sa vetví na `undefined`/`null`).
- **Rozpracovaný stav pri prepnutí dokumentu — tri obrany:** (1) **`nxSetModelGuid` je jediný detektor zmeny dokumentu** a pri zmene spustí `nxDropDocState()`
  (`cancelCabinetEdits` · `cancelBoardEdits` · `dropCabRename` + `closeCabRenameEditor` · `absModalCloseSilent` · `closeSaveTemplateModal` · `closeSimilarModal` ·
  vynulovanie `cabEditsInFlight` · `blur` aktívneho prvku); echo tej istej identity nezahodí nič. **Každý nový pending buffer, editor alebo modal patrí do tohto
  zoznamu** (vedome mimo: `insertLocksTimer`, `previewTimer`, draft vkladacej karty). (2) **Vlastná zachytená identita v každom bufferi** (`applyPendingGuid`,
  `boardPending.guid` kľúčovaný dvojicou dokument+doska, `renameGuid`, `boardTarget()`/`partTarget()`, `tplModalGuid`, `simFor.guid`). (3) Serverový
  `foreign_document?`.
- **Poradie v pushi je kontrakt:** `nxSetModelGuid` je **prvý príkaz** `loadSelected`, `loadBoard`, `clearSelected` aj `init` (stoja na tom `keepGaps` a test „iná
  doska"); volanie v `setUiMode` je poistka. Závierku `cabEditsInFlight` nuluje **výhradne `nxDropDocState`**, nie `cancelCabinetEdits` (beží aj v jednodokumentovom
  flow).

Plné znenie: archív, „sync.rb".

### actions_appliance.rb

**Tri akcie panela k spotrebičom** — tri rôzne veci: `set_appliance_owner` (väzba — mení položku zákazky aj geometriu), `set_appliance_expects` (očakávanie — len
vyhlásenie v configu) a `set_appliance_mount` (výška osadenia chladničky — prestavba bez zmeny položky zákazky). UI: odsek „Riadok Spotrebič v Inspectore".

**`set_appliance_owner`** — priradenie modelu z riadku „Spotrebič" alebo odpojenie (skrinka, slot umývačky, doska). Súbor **nezapisuje**: deleguje na
`ApplianceBinding.apply!` (`move` / `unbind`) — jediný transakčný vstup väzby (položka rozpočtu + `appliance_refs[]` vlastníka + prestavba = **jedna operácia, jeden
krok Späť**). **Cieľ väzby skladá server z výberu, nie z payloadu:** klient posiela `item_id` a echo `cabinet_id` / `board_id`; druh (`cabinet` vs `slot`), ID aj
`persistent_id` sa čítajú z označenej entity (druh = vlastnosť typu `appliance_owner` z registra `CabinetTypes` — H12b; tá istá vlastnosť odmieta montáž
pri slote a určuje druh očakávaní). Dokument overuje `foreign_document?` nahlas, nezhodné echo vráti „Výber sa medzitým zmenil" a obnoví kartu. Po úspechu
`push_selected`; otvorené Štúdio sa dozvie cez transakčný observer (zožltne „Obnoviť").

**`set_appliance_expects`** = **config-only zápis vo vlastnej operácii, jeden krok Späť, bez prestavby.** Payload: `expects[]` (úplný nový zoznam), echo
`cabinet_id` / `board_id` a `pid` z času vykreslenia riadku. **Poradie guardov je kontrakt:**
1. identita dokumentu (`foreign_document?`),
2. **bariéra observera** (`ApplianceBinding.observer_idle?` → `ScaleWatch.flush_pending!` — dedup kópií môže práve meniť `cabinet_id`),
3. **cieľ sa číta až potom** a overuje celý: druh + ID + `persistent_id`, jednoznačnosť, nie odpojený dielec, config ani novší, **ani starší** (marker sa config-only
   zápisom neposúva → „najprv ju prestav…", [construction.md](construction.md) `write_config_keys!`); **prázdne echo ani chýbajúci `pid` sa netolerujú**,
4. striktná validácia proti matici druhu (`ApplianceBinding.validate_expects` — [appliances.md](appliances.md)),
5. **viazanú kategóriu odstrániť nedáš** (`appliance_expects_locked`) — len pre očakávania, ktoré na kuse naozaj sú (prienik viazané ∩ uložené mínus nový zoznam),
6. nezmenený výsledok = **žiadna operácia** („Očakávanie sa nezmenilo").

Zapisuje `CabinetBuilder.write_config_keys!` / `BoardBuilder.write_config_keys!` pod `CabinetBuilder.guarded` v jednej `start_operation` (výnimka = `abort`). Po
úspechu `push_selected(dedup: false)` **a** `StudioDialog.refresh_if_open(bump: true)` (zmenili sa dáta Kontroly). **Každé odmietnutie posiela čerstvú kartu**
(`appliance_expects_refused` → `push_selected(dedup: false)`, potom červený status) — klient ovládač po odoslaní zamkne a odomkne ho až nový payload.

**`set_appliance_mount`** = **prestavba vo vlastnej operácii, jeden krok Späť.** Payload: `item_id`, echo `cabinet_id` + `pid`, nová `value` a **pôvodná `prev`** — všetko
zachytené pri otvorení popoveru, dokument cez `nxDocPayload(…, zachytený guid)`. Poradie: dokument → bariéra observera → **cieľ** (`appliance_mount_target`:
označená skrinka, echo ID + PID, nie slot, jednoznačné ID, nie odpojený dielec, nie novší config, **práve jeden** záznam `fridge` s tým `item_id` a živá položka
zákazky tejto skrinky — obojsmerný dôkaz `ref_matches?`) → **hodnota** (`appliance_mount_value`: konečné číslo 0–2000 mm, zaokrúhlené na 0,1) → **echo pôvodnej
hodnoty** (`|prev − aktuálne| < 0,05`, inak „Osadenie sa medzitým zmenilo") → nezmenené po zaokrúhlení = žiadna operácia. Zápis `appliance_mount_write`:
`CabinetBuilder.ensure_root_context` **pred** operáciou → `guarded` → `start_operation(APPL_MOUNT_OP)` → `write_appliance_refs!` (`appliance_mount_refs` mení len tento
kus; 0 kľúč zmaže) → `commit`; výnimka = `abort_safely` + čerstvá karta. Po úspechu `push_selected` + `StudioDialog.refresh_if_open(bump: true)`; odmietnutia cestou
`appliance_expects_refused`.

### actions_board.rb

Doména panela: vloženie a kreslenie samostatnej dosky a zápisové cesty jej karty (polia · materiál · ABS hrana · olep všetkých 4 · orientácia). **Dve úrovne identity
so zámerne rôznou hlasnosťou:** dokument overuje spoločná brána **`guarded_board`** cez `foreign_document?` **nahlas**; echo `board_id`, výber bez dosky a „v Inspectore
vyhrala skrinka" sa zahadzujú **ticho** (log).

- **Brána schémy stojí vo vstupnej bráne `guarded_board`** (hneď za dokumentom, kontextom a echom `board_id`) — cesty karty pred rebuildom menia globálny katalóg
  (`resolve_virtual_material` → `ensure_duplak_for`, `ensure_missing_abs`), čo sa nedá vrátiť; doska z novšej verzie odmietne **každú** zápisovú cestu nahlas.
  **Karta je vtedy read-only:** `Panel.board_payload` primieša `board_newer_flag` (`newer_config` + serverová `newer_config_note`) a `applyBoardReadOnly`
  (`board_card.js`, na konci `renderBoardCard`) zamkne všetky ovládače (`disabled`) a ukáže `#bcNewer`. Testy `tests/js/test_ghost_d1_karta.js`.
- **„Vložiť dosku" nevkladá hneď:** `handle_insert_board` pripraví zmrazený `BoardPlan` a zavesí ghost; doska vznikne klikom (`GhostTool` →
  `BoardBuilder.commit_insert`). **Poradie:** `foreign_document?` úplne prvý → šablónový ref + **downgrade brána** `newer_template_refusal` nad **uloženým RAW
  záznamom** (proti `BoardBuilder::BOARD_CONFIG_SCHEMA`) → `prepare_insert` → session `subject: :board` s orientáciou z karty. Vyššia schéma = odmietnutie bez
  session a pečiatky. Po commite `ghost_after_commit_board` (výber, status s umiestnením, `push_selected`, `stamp_once!`).
- **„Nakresliť" = samostatný callback `draw_board`** (whitelistovaný serverom; `insert_board` ostáva pre vloženie a dvojklik doskovej šablóny). Poradie: dokument →
  šablónový ref + downgrade brána → **zámky fáz** → `prepare_insert` → session `interaction: :drawing`. Zámky = pole `locks` (snapshot `locksFlat('board')`),
  whitelist `GhostTool::Calc.draw_locks` (len `length`/`width`, Numeric, v `BoardBuilder::LIMITS`) **pri štarte** — inak sa session nespustí. Zámky žijú len v
  session; whitelist parametrov karty `BOARD_INSERT_PARAM_KEYS` je jeden pre obe cesty a `locks` v ňom nie sú. Po commite hlási aj vzniknuté rozmery. Kontrakt fáz:
  [construction.md § ghost_tool.rb](construction.md).
- Karta má **dve akcie v jednom riadku** „Vložiť dosku" · „Nakresliť" (pri korpuse je „Nakresliť" skryté `body:not([data-insert-kind="board"])`); obe idú cestou
  `buildInsertBoardPayload`, kreslenie pridá `locks` (`buildDrawBoardPayload` prijme len konečné čísla). Testy `tests/js/test_ghost_d2_karta.js`.

### actions_cabinet.rb

Doména panela: vloženie skrinky (`handle_insert`, `handle_insert_copy`), premenovanie (`handle_rename_cabinet`), zápisy konštrukcie a čiel (`handle_apply`,
`handle_apply_fronts`, `handle_apply_all` = auto-apply), čítací preflight čiel (`handle_front_preflight`), prepínač strany rohovej (`handle_corner_side`), prevesenie
ghostu (`handle_ghost_corner_side`) a hromadná prestavba zastaraných chrbtov (`back_rebuild_stale` z Kontroly — plán a texty `ProductionCore.back_stale_*`, zápis
`rebuild_many` = jedna operácia, výber skriniek až po `ScaleWatch.flush_pending!`). Materiálové preflighty (D-45: telo → chrbát → remap ABS) a zámky vkladacej karty:
odseky „Kontext Korpus" a „Vkladacia karta". **Poradie guardov: identita dokumentu PRVÁ**, až potom echo `cabinet_id`.

- **Typ cez register `CabinetTypes` (H12b, [construction.md](construction.md), odsek `cabinet_types.rb`):** „slot" = typ bez korpusu (`!carcass?` — preflight:
  sokel 0, `slot_preflight_opening`, kanonizácia riadku slotu; `slot_params?` bez tela a chrbta; typ zo šablóny sa prevezme), rozsahy preflightu = `limits` typu
  (inak 200–3000), „rohová" = `corner?` (zdroj preflightu, šablóna, prepínač strany), čelá = `fronts` (`slot_fixed` → `slot_fronts_refusal`, `corner_one_door` →
  `corner_fronts_refusal`), zmena typu = identita surová a zámok `type_locked` aspoň jedného (`corner_change_refusal`). `TEMPLATE_TYPE_WORDS` je odvodené z `word`
  (poradie `IDS`). Výsledky bajtovo ako pred H12b (golden `panel.json`, matica H12a).
- **Kópia** (`handle_insert_copy`) prenáša overenú zdrojovú skrinku samostatným `appearance_source:` do buildera (zachová živé materiály a ABS, vlastná identita
  a definícia); vzhľadový zdroj sa nikdy nepridáva do params/configu ani payloadu. Ruší bežiacu ghost session hneď na začiatku.
- **Rohová na serveri:** `PARAM_KEYS` pozná `corner_side`/`corner_door_w`/`corner_cr1`/`corner_cr2`; JS posiela dverovú časť a CR len pri rohovej (`only`
  v `CONSTRUCTION_FIELDS`), stranu **nikdy**; `handle_apply` kopíruje len prítomné kľúče. **`corner_change_refusal(params, data)`** odmietne zmenu typu z/na rohovú a
  zmenu strany (`CORNER_TYPE_MSG` / `CORNER_SIDE_MSG`) pred prepisom params (0 krokov Späť, resync) — v `handle_apply` aj `handle_apply_all` a pri šablóne inej strany.
  **`corner_fronts_refusal(params, incoming)`**: čelá rohovej = jeden riadok `door`/`auto`/jedno krídlo (`CabinetBuilder.corner_fronts_ok?`) a medzera pri rohu 1–20
  (`corner_gap_ok?`). **`corner_template_refusal(tpl_ref)`** odmietne rohovú šablónu s porušeným invariantom čiel pred ghostom.
- **`handle_corner_side`** (callback `corner_side`, jediná cesta, ktorá stranu mení): dokument → označená skrinka s povinným echom `cabinet_id`
  (`corner_side_target`) → **bariéra observera** `ScaleWatch.flush_pending!` pred čítaním configu (neúspech = `CORNER_SIDE_BUSY_MSG`) → po bariére znova dokument
  a cieľ → typ rohová → platná strana. Rovnaká strana = nič; zmena = jedna operácia `CabinetBuilder.rebuild(..., op_name: CORNER_SIDE_OP)` nad
  `CabinetBuilder.corner_mirror_params` ([construction.md](construction.md)); výnimka = `abort_safely` + resync. **Korelovaná odpoveď:** server v `ensure` každej
  vetvy pošle `NX.cornerSideResult({model_guid, cabinet_id, switch_token, ok})` až po pushi stavu.
- **Preflight čiel** (`front_preflight_result(data, stored)`): otvor pre každý typ cez `Construction.front_opening` (`preflight_opening_cfg`) — pri rohovej strana
  z uloženého configu, dverová časť zo živého formulára (`preflight_door_w` / `preflight_corner_mm`: živé pole v `CORNER_RANGES`, inak uložená; pri vkladaní
  orezaná `CabinetBuilder.norm_corner_mm`) a živá šírka. Odpoveď nesie `opening` (cez `opening_json`, zapísaný hneď po výpočte — nesie ho aj odmietnutie), pri
  rohovej **`corner_ctx` `{th2, t}`** (`corner_preflight_ctx`; pri vkladaní hrúbka tak, ako ju upraví vklad) a **`corner_preview`** (len keď je `opening`
  a `corner_ctx`; vstup `corner_preview_params`, živý strop `CORNER_PREVIEW_LIVE_KEYS`). Pri vkladaní berie `corner_preflight_src` stranu a dverovú časť z payloadu.
  `TEMPLATE_TYPE_WORDS` (z registra) pozná „rohová".
- **`handle_ghost_corner_side`** (callback `ghost_corner_side`): dokument → živá session rohovej v tomto dokumente → `handle_insert(payload, keep_point: true)`
  (tá istá cesta ako „Vložiť") → keď nová session nevznikla, stará sa zruší. Nič nezapisuje.

#### Vloženie skrinky = ghost na kurzore (GHOST V1-04)

**„Vložiť" nevkladá hneď:** `handle_insert` pripraví **zmrazený plán** (`CabinetBuilder.prepare_insert`) a zavesí ghost skrinky na kurzor; skrinka vznikne až klikom.
**Poradie je kontrakt:** guard dokumentu → šablónový ref → kovanie šablóny (`take_insert_hardware!`) → preflighty D-45/D-76 → materiál → `prepare_insert` → zrušenie
starej session → nová session + `push_tool` + status. **Preflighty bežia práve raz a Tool ich neopakuje.** Druhou obranou je guard v `commit_insert` (plán z iného
dokumentu odmietne). Poznámku preflightov vypisuje až `ghost_after_commit`.

**Švy panela voči `GhostTool`:** `ghost_freeze_hardware` (sprievodný blok vnútri operácie vloženia — výnimka ruší celú operáciu) · `ghost_insert_failed` (commit padol
na guardoch stavby, model nezmenený) · `ghost_after_commit` (výber novej CAB, status s varovaniami, `push_selected`, `stamp_once!`) · **Ghost pásik** (informačný).

**Ghost pásik** (`ui/js/ghost_bar.js`, push `Panel.push_ghost` → `NX.setGhost`; každý push stav celý prepíše): jeden riadok **samostatne medzi sektorom Náhľad
a Základné** — mimo každého `<details>` aj kontextovo skrývaného rodiča; viditeľnosť má jediného vlastníka, atribút `hidden` (guard
`tests/pure/test_ghost_vkladanie.rb`). Štartuje `hidden`, `active = false` ho schová pri každom konci session.
- **Skrinka:** piktogram štyroch kotiev, otočenie, režim výšky, **editovateľné pole zamknutej výšky** (→ `ghost_lock_z` → `handle_ghost_lock_z`: guard dokumentu prvý,
  validácia mm Float 0–3000 na oboch stranách, neplatný vstup nič nemení) a „i" (`#i-info`). Segment **nôh** `gbLegs` (`legs_short` + `legs_tone`, len pre
  subjekt `cabinet`, `'none'` sa neposiela; text skladá server `HardwareSets.legs_summary` cez `Panel.legs_preview_summary` s definíciami setov zo session
  `s.hardware['defs']`). Hodnota sa počíta **lenivo raz za session** (`PlacementSession#legs_summary`, sentinel `:unset`) a memo zhadzuje
  `GhostTool.invalidate_legs_summary!` z hookov `Panel.push_hardware_sets` a `RulesDialog.after_model_write`. Segment **strany dverí** `gbCorner` pri rohovej
  (`corner_side` + `corner_label`).
- **Doska** (`subject: 'board'`): kabinetové ovládače výšky (`gbMode`, `gbLockWrap`) skryté, v tom istom riadku **umiestnenie** `gbOri`; `ghost_lock_z` sa pre dosku
  neposiela a server ho odmieta (`unless s.cabinet?`). Po ↑/↓ v modeli klient prestaví `NXInsert.boardOrientation` bez resetu karty.
- **Kreslenie** (`interaction: 'drawing'`): namiesto kotiev fáza s hodnotou `gbPhase` (`phase` · `phase_label` · `phase_value` · `phase_locked`; neznáma hodnota „—").
- Push bez `subject`/`interaction` sa správa ako umiestňovanie skrinky. Pásik nikdy nenarastie o riadok. Testy `tests/js/test_ghost_d1_pasik.js`,
  `tests/js/test_ghost_d2_pasik.js`, `tests/js/test_kovg2_nohy_ui.js`, `tests/pure/test_kovg2_nohy_ui.rb`.

**Zmeny vo vkladacej karte sa do bežiacej session nepremietajú** (snapshot je zmrazený, status to prizná); druhé „Vložiť" starú session zruší a založí novú —
výnimkou je kláves strany rohovej. **Konce životného cyklu session** (všetky = 0 mutácií, 0 krokov Späť): druhé „Vložiť" · zavretie Inspectora (`set_on_closed`) ·
File > New / Open (`PanelAppObserver`, bezpodmienečne) · aktivácia iného dokumentu (`Panel.on_model_switched`) · `onCancel` · `deactivate` (prepnutie nástroja) ·
`handle_insert_copy`; nová doskovú session ukončí starú cez `GhostTool.start`. Kontrakt nástroja: [construction.md § ghost_tool.rb](construction.md).

Auto-apply hlási nezhodu dokumentu **nahlas** (na rozdiel od tichého echa výberu).

### actions_hardware.rb

Doména panela: ručné zásahy do kovania (`handle_set_hardware_override` — zápis po poliach s merge záznamu identity) a výber setu na skrinke či dielci
(`handle_set_hardware_set`). Pravidlá a sety: [hardware.md](hardware.md); UI: „Kontext Kovanie". Obe cesty overujú dokument **pred** `cabinet_id` a zápis beží ako
jeden rebuild = jeden krok Späť.
Po zrušení výberu `hw_set_status_msg` neutrálne hlási „výber zrušený"; dedenie vysvetľuje riadok setu. Telo `handle_set_hardware_set` zostáva
v H18 nezmenené (zdrojový guard), vrátane existujúceho problému zápisu pri klasifikovanom krídle (D-150).

- **`OVERRIDE_FIELDS`** (`quantity` · `disabled` · `nominal_length` · `height_variant` · `box_height`) sa **musí zhodovať** s `CabinetBuilder::OVERRIDE_CONTENT_KEYS`
  (guard test).
- **Receptová cesta zámkov osí:** validácia sa delí podľa `rule_id` — projektové pravidlo cez `series_value?` (rad `fit_series`), receptová položka
  (`recipe:<id>`) cez `recipe_lock_context`: vlastník → **pripnutý** recept (`Recipes.active_ref` nad `recipe_refs`) → **výsledná výška** (`recipe_result_height`:
  platný uložený výškový zámok · `params.height_variant` emitovanej položky · automatická výška z čerstvého `ctx`; zámok v konflikte výsledná výška nie je) → rad
  tej výšky. Všetko z **čerstvého serverového stavu**, nikdy z payloadu; svetlé rozmery tou istou cestou ako payload `axes`. Nesediaci `rule_id`, Quadro výškový
  zámok a výška mimo `height_variants` sa odmietajú.
- **`recipe_box_value`**: na Atire odmietnutie, hodnota strict (`Float(raw, exception: false)` + `finite?` + `> 0`), zaokrúhlenie na 0,1 mm a až potom rozsah proti
  čerstvému `ctx` cez `Recipes.box_range`; neurčiteľný kontext = odmietnutie. `recipe_lock_context` číta `drawer_axis_ctx` pre všetky systémy.
- **Odomknutie osi** = `field` + `value: null` (`merge_override` zmaže jedno pole, druhý zámok prežije); `reset: true` ostáva pre `disabled`/`quantity` a osirotené zásahy.
- **Odpoveď čakajúcemu modalu:** payload z potvrdenia náhrady nesie `ax_token`; server ho len vracia v `NX.hwAxResult(ok, msg, token)` (uzavretý tvar `axis_token`,
  `AXIS_TOKEN_MAX`) **v každej vetve** (`axis_fail`; úspech `push_axis_result` až za `push_selected`); bez tokenu nič.
- **Upgrade receptu jedného čela** — `handle_upgrade_drawer_recipe` mení presne jeden záznam `recipe_refs` jedného čela (payload `{cabinet_id, front_id, from, to}`;
  mapu klient neposiela — `SERVER_DRAWER_KEYS`). Overí: klasifikovaná zásuvka · záznam `:known` a rovný `from` · cieľ vydaný · `Recipes.upgrade?(from, to)` (rovnaký
  systém a otváranie, vyššia verzia). Callbacky: zápisový `upgrade_drawer_recipe` (odpoveď `push_upgrade_result` → `NX.hwUpgradeResult` v každej vetve, token
  `up_token` čítaný pred prvým návratom, až za `push_selected`) a **čítací** `drawer_upgrade_impact` (žiadna operácia; `push_upgrade_impact` → `NX.hwUpgradeImpact`,
  `ok: false` + `reason`).
- **Preflight, nie rollback:** konflikt receptu nie je výnimka (`build_plan` ho vráti ako dáta a `rebuild` by commitol), preto `drawer_upgrade_prepare` postaví cieľ
  **nasucho** tými istými funkciami ako stavba (`CabinetBuilder.normalize` → `drawer_thicknesses` → `Construction.build_plan` → `Recipes.resolve`) a tou istou
  expanziou ako nákup (`HardwareSets.expand`); odmietne hrúbku, neplatný zámok po preadresovaní, `no_fit`, prekážku aj chýbajúci kit. Odmietnutie = nič sa nezapíše.
  Dopad ide z toho istého stavu (`side`, `lock`, identita); terajšiu stranu stavia ten istý `drawer_dry_plan`; dielce kľúčované **`part_key`, nie rolou**; výšku
  emituje `drawer_upgrade_height` s `kind` (`variant` / `box`). Odtlačok potvrdenia: odsek „Kontext Čelá".
- **Preadresovanie zámkov** `readdress_recipe_locks` (`recipe:<v1>` → `recipe:<v2>` so zachovanými hodnotami) s **kolíznou bránou** (iný obsah na cieľovom
  `rule_id` = odmietnutie); dormantné zámky iných receptov sa nedotýkajú. Zápis = jedna operácia `CabinetBuilder.rebuild` (ref + zámky + prestavba).
  **`UPGRADE_LOCK_AXES`** (`height` → `height_variant`, `box` → `box_height`, `nl` → `nominal_length`) je zrkadlo osí payloadu a polí `OVERRIDE_FIELDS` (guard test).

### actions_materials.rb

Doména panela: materiály **označenej skrinky** (`handle_set_cabinet_material` — override projektovej predvoľby pre telo/čelo/chrbát; materiál tela riadi hrúbku
korpusu, D-45) a echo prepínače kontrol hrán a kresby (`handle_edge_toggle`, `handle_edge_option`, `handle_grain_toggle`). Projektové predvoľby žijú v Štúdiu
(sekcia Materiály). Katalóg: [materials.md](materials.md). Guard dokumentu beží **pred** echom `cabinet_id` (zámena materiálu tela mení aj hrúbku).

### actions_parts.rb

Doména panela: zápisové cesty karty dielca. Kontrakt a guardy (dokument · cieľ zmeny · odpojenosť): odsek „Karta dielca". **Identita dokumentu je prvá**
(`part_target_error` hľadá cieľ v aktívnom dokumente); `handle_set_part_grain` má vlastný, tvarom starší guard (`data['model_guid']` inline), ostatné tri cesty
idú cez `foreign_document?`.

### actions_settings.rb

Doména panela: **nastavenia počítača z kolieska raily** (`%APPDATA%`, nie zákazky) — do modelu sa nezapisuje a žiadna cesta neotvára operáciu. `handle_set_ui_theme`
(whitelist v Ruby `Engine.normalize_ui_theme`; odpoveď nejde zvlášť — `apply_ui_theme` rozošle tému všetkým oknám; zlyhanie zápisu sa nehlási ako úspech) a
`handle_set_dim_series` — od H10b/R-35 `DimSeries.update!(data['series'], data['base'])` (len zmenené rady + pôvodné hodnoty; normalizáciu robí výhradne `DimSeries`).
`push_ui_settings(refill_editor: true, series_status:)` ide pri **každom** výsledku (editor ukáže uložený stav a znova pripne pôvodné hodnoty;
`series_status` = tá istá veta pre riadok `#serStatus` v sekcii modalu, ktorý `#status` prekrýva), veta cez `case`: `:ok` „Rozmerové rady
uložené." / bez zmeny „…sa nezmenili." · `:conflict` červené „Rozmerové rady (Šírky) medzitým zmenilo iné okno SketchUpu — nič sa neuložilo. Editor ukazuje aktuálne uložené
rady, zmenu zadaj znova." (rozpis sa stratí) · `:stale_client` červené „Okno je z predošlej verzie pluginu…" · `:blocked` dôvod brány `DimSeries.write_block_reason` ·
`:write_failed` „…(disk/práva)". Panel `DimSeries.set(` nevolá. Nastavenia chodia aj v `push_init` (`ui_settings`). UI: odsek „Inspector — kostra" (koliesko).

### actions_templates.rb

Doména panela: šablóny a ručné odfotenie náhľadu (`Panel.capture_preview_for`). Kontrakt: odsek „Vkladacia karta" a [model-a-identita.md](model-a-identita.md)
(`template_previews.rb`). Žije tu aj **`handle_tag_visible`** — jediný handler viditeľnosti NOXUN tagov pre oba ovládače (okno tagov v raile, checkbox ghost zón).
- **Typ šablóny rohovej a slotu je zamknutý:** `apply_template_type!` pri type `template_type: locked` (register `CabinetTypes` — slot aj rohová) vráti skôr;
  prepnúť sa dá len medzi `TEMPLATE_SWITCH_TYPES` (= `ids_where(:template_type, 'switchable')`, dolná a horná), veta „Uložená ako …" z `word.upcase`
  (`TEMPLATE_TYPE_LABELS`); chýbajúci typ = `FALLBACK`, `''` ostáva (H12b, matica H12a golden). Druh vlastníka očakávaní (`apply_template_expects!`) =
  `appliance_owner` typu. `template_config_from` (payloads) zapisuje pri rohovej výslovne všetky štyri polia rohovej.
- **Mini-modal uloženia** (`#tplModal`): checkbox „Uložiť aj kovanie (sety a ručné položky)" — default zapnutý, pamäť `localStorage['noxun.tpl.with_hardware']`;
  `saveTemplateAs` posiela boolean `with_hardware` (chýbajúci = zapnuté), `handle_save_template_as` ho po guardoch posunie do `template_config_from`
  a `template_save_hardware_note`. Vypnuté = bez setov, definícií a ručných položiek; poškodený zdroj pri zapnutej voľbe = konštrukcia bez kovania s jasnou hláškou.
  Materiály skrinky sa prenášajú, individuálne úpravy dielcov a **ručné zámky nie** (hint to uvádza).

### actions_usage.rb

Doména panela: **merač používania panela** (D-25, callback `usage_flush` → `handle_usage_flush`; payload z `usage.js` `{"counts": {"kluc_prvku": n}}` bez hodnôt
polí). Merač je **neviditeľný**: vlastný `begin/rescue` len s logom a nikdy `set_status` — chyba merača (ani pád loggera) nesmie rušiť prácu. Ukladanie: `usage_stats.rb`.

## Štúdio — okno a sekcie

### studio_dialog.rb + ui/studio.html + ui/js/studio.js — okno ŠTÚDIO

**Čo to je:** jedno okno celej zákazky (kontrakt `SYSTEM/zdroje/ui20/UI20_KONTRAKT.md`, sekcia ŠTÚDIO KONCEPT; vizuálna referencia
`SYSTEM/zdroje/ui20/mockup_studio.html`) — ľavá navigácia, obsah sekcie vpravo. **Štrnásť živých sekcií** (`SECTIONS` = `bom ctrl buy budget offer cut mat hw appl
rules tpl sup bset about`): Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Nárezový plán (skupina výstupy) · Materiály · Kovanie · Spotrebiče ·
Pravidlá · Šablóny (katalógy) · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine (nastavenia). Každá sekcia má odsek **`### Sekcia <NÁZOV> v Štúdiu`** nižšie.
Okno je `UI::HtmlDialog` (`STYLE_DIALOG`); obsah `1060 × 640` ⇒ `width/height 1076 × 680`, `min_width 1076`. Vstupy: toolbar „Štúdio", menu, deep-linky
z Inspectora (`StudioDialog.show(open_section:, anchor:)`).

**Navigácia a sekcie:**
- O sekcii rozhoduje **uzavretý whitelist v Ruby**, klient posiela iba kľúč. Poradie, skupiny, ikony, názvy, nápovedy, badge a hlášku „Obnoviť" berú navigácia,
  hlavička aj filter z **registra `NXStudioSections`** (odsek `ui/js/studio_sections.js` nižšie) — vlastný zoznam sekcií nedrží žiadny iný súbor.
  **Prepnutie sekcie má jednu cestu** `studioSwitchSection(id, guid)` pre klik aj deep-link: neznáme id = `false` (nič sa nestane); inak pri zmene sekcie
  kontextové háčiky dokumentu (`hwProductContextChanged`, `mdManualContextChanged`) → zhasnutie menu lišty (`closeSectionMenus`) → `leave` opúšťanej sekcie →
  `studioSec = id` → `enter` novej (napr. „O plugine" = práve jeden check verzie). Nekreslí: `studioGoSection(id)` (globál na `window` — navigácia, chip
  Rozpočtu, nález Kontroly) kreslí `render()` **len po úspešnom prepnutí**; deep-link v `NX.setStudio` navyše aplikuje **kotvu** a kreslí vždy (plný payload).
  **Lištu a telo** kreslí `renderTools` / `renderBody` z riadka registra (`tools`, `body`) — vetvu podľa id nemajú; Kusovník, Kontrolu a Nákup kreslí
  `studio.js` sám pomenovanými háčikmi z vlastnej tabuľky `OWN_HOOKS`.
  Neaktívna položka navigácie dnes nie je; vetva `disabled` (`aria-disabled` s dôvodom) ostáva poistkou. Ikony položiek sú **jedinečné** (Nastavenia rozpočtu
  `sliders-horizontal` — vedomá odchýlka od mockupu, ten istý symbol nesie tlačidlo „Nastavenia" v Rozpočte a akcia nálezu Kontroly `layout_settings`; Pravidlá
  `settings`; Kovanie `hammer` ako rail Inspectora). Zbalená navigácia `nx_studio_nav` v `localStorage`.
- Sekcie s formulármi (Materiály, Kovanie, Pravidlá, Rozpočet, Spotrebiče…) majú **perzistentné telo** — jeden uzol naklonovaný raz zo `<template>`, ktorý pri
  odchode zo sekcie z `#secbody` vypadne a pri návrate sa vráti; `NX.setStudio` ho neprekresľuje (rozpísané hodnoty prežijú push). Modály sekcií žijú v kotvách
  **mimo `#secbody`** (`#nxModalRoot`, `#matModalRoot`, `#hwModalRoot`).
- **Okno má `@ready`**: `false` pri vzniku a zatvorení, `true` v `ready` callbacku pred prvým pushom; `js` podľa neho rozhoduje (`return false unless @ready`) —
  CEF `execute_script` pred načítaním HTML zahodí.

**Čísla a kanál okna:** čísla nesie zdieľané jadro **`ProductionCore`** ([outputs.md](outputs.md)); **server je autorita čísel aj textov** — medzisúčty zo
`sheets`, súčtový riadok z `totals`, popisky z `materials_meta`; **JS neprepočítava žiadnu sumu**. Kanál okna je vlastný: `@generation`, relay
`NX.studioRelay`/`studioRelayExport` → `studio_do_select`/`studio_do_export` v `panel.rb` s **flush handshakom** (červené pole panela export zastaví;
`flush_blocked`). Nesúlad generácie = re-push + status, nikdy ticho. Verejný čítač `StudioDialog.generation` používajú zápisové akcie sekcií (klik zo zastaraného
zoznamu sa nevykoná); generáciu zdvíha výhradne `push_state`.

**REFRESH INVARIANT (záväzné miesto) — rozhoduje, či sa menia čísla zákazky:**
- **Plný push so zdvihom generácie** — zápis mení kusovník, rozpočet alebo ponuku. Patria sem aj **uloženie pravidiel kovania** (modelový zápis:
  `HardwareRules.set_project_rules` beží vnútri `CabinetBuilder.rebuild_many(op_name: 'NOXUN: pravidla kovania')` = jedna undo operácia; rebuild číta projektový
  snapshot `hardware_rules`; `HardwareRules.write` do `%APPDATA%` je len globálna predvoľba) a **sadzby dodávateľa** (`supplier_settings.json`, mimo modelu, ale menia
  sumy → `SupplierSettingsDialog#refresh_studio(bump: true)`).
- **Plný refresh bez zdvihu (`bump: false`) + echo** — zápis môže meniť čísla, ale nie identitu riadkov: **katalóg materiálov** (`MaterialsDialog.after_catalog_change`
  → `push_mat_catalog` + `StudioDialog.refresh_if_open(bump: false)`); rozkliknutý riadok ani rozrobený export nesmú zastarať kvôli oprave ceny.
- **Samotné echo sekcie** — zápis nemení čísla zákazky (knižnica šablón `TPL.init`) a **odmietnutý zápis** (`push_section_echo`). **Výnimka:** odmietnutie pre
  **prepnutý dokument** (`model_guid` mismatch) ide plným pushom `refresh_studio(bump: false)`.
- Po zápise do modelu dostanú čerstvé čísla obaja odberatelia v poradí `Panel.push_selected` → `refresh_if_open(bump: true)` (vzor
  `refresh_studio_after_model_write`).

**Životnosť dlhých behov nie je jednotná:** Demos fetch katalógu (`HardwareCatalogDialog`, `MaterialsDialog`) zhasína zatvorenie okna, prepnutie dokumentu aj
**odchod zo sekcie** (`hw_leave`/`mat_leave`); **prepočet cien** (`price_refresh_alive_proc`) zámerne prežíva prepnutie modelu (ceny idú do globálneho katalógu)
a kontroluje len živú inštanciu okna — leave hook Rozpočtu neexistuje.

**„Obnoviť"** (`refresh_bom` → `do_refresh_bom`) hlášku **vždy zhodí**: po úspešnom `push_state` echo „Prepočítané.", pri výnimke chybová hláška + `log_error`
(vlastný `rescue`). Tlačidlo má **jeden markup pre všetky miesta** — `refreshBtnHtml(stale, tip, attrs)` v `studio.js` (Rozpočet a Ponuka cez most
`budRefreshBtnHtml`). Jantárový stav: odsek `StudioModelWatch`.

**Deep-link** — kontraktové meno `NX.studioOpen(section, anchor)`, reálna funkcia panela `openStudio(section, anchor)` (`ui/js/actions.js`) → `open_studio` →
`StudioDialog::SECTIONS` (klient filtruje registrom `NXStudioSections`). Sekcia sa odloží do `@pending_section` a **jednorazovo ju spotrebuje najbližší
`push_state`**; `anchor` sa spotrebuje so sekciou podľa jej riadka registra (`anchor`): Kusovník predvyplní hľadanie a Materiály otvoria detail dekoru **pred**
vykreslením (menia stav, z ktorého sa kreslí), Rozpočet a Spotrebiče doscrollujú a prisvietia riadok **po** ňom (dotaz do DOM); neúspech = hláška `miss`.
Prechod ide tou istou cestou ako klik (`studioSwitchSection`) — kotvu má len deep-link.

**Zápis čísel a jednotiek celého okna** žije v `studio.js` — blok `nxf*` (`nxfMoney`, `nxfMoneyIn`, `nxfQty`, `nxfUnit`, `nxfQtyUnit`, `nxfMm`, `nxfDim`, `nxfDec`;
pravidlá: `docs/UI_DIZAJN.md` „Zápis čísel a jednotiek"). Sú to globály súboru (sekčné skripty `budget.js`, `proj_materials.js`, `hw_catalog.js`, `demos_diff.js`,
`rules.js` sa načítavajú za ním), v Node cez `require`; bez neho kreslí každá sekcia núdzový zápis s čiarkou, ktorý nič neskryje. Mení sa len zápis — payload,
XLSX, CSV ani VEPO nie. Test `tests/js/test_h4a_format.js`.

**Texty:** bez vývojárskeho žargónu a VEĽKÝCH písmen (slovník `docs/UI_DIZAJN.md` §1); guard `tests/pure/test_h4b_texty_vzhlad.rb` ich hľadá v reťazcoch UI, nie
v komentároch; správanie `tests/js/test_h4b_texty_vzhlad.js`. **Hľadanie** (Kusovník, Materiály, Kovanie, Spotrebiče ×2) má krátky hint „Hľadať…", rozsah nesie
`title` + `aria-label`.

**Rohové nastavenie tlačidiel** (zóna `.cornerzone` zdieľaná s railom Inspectora a lištou Kontroly, obsah okna vlastný): zatvára klik mimo a Escape — **v jednom
listeneri** s `ecMenu`/`vepoMenu` a až za modalovou brankou `nxModalOpen`.

**Hlavička — názov zákazky (H7b, mockup `SYSTEM/zdroje/bloky/HARDENING/MOCKUP_H7_NAZOV_ZAKAZKY.html`, O1–O9):** pravá časť hlavičky KAŽDEJ sekcie je
`jobHeadHtml(vepo, verzia, zobrazený)` (`studio.js`, čistá funkcia) — „Zákazka" · `<button id="jobName" class="jobname src-<zdroj>">` s ceruzkou · dovetok · „· v<verzia>"
(zanikol `#stModel` „zákazka: <súbor>"). Zdroj skladá **server** (`vepo.source`): `set` zadaný (tučne) · `file` podľa súboru (sivé „podľa súboru") · `default` predvolený
„projekt" (jantárová `.jdot`, kurzíva, „zadaj názov"); **čakajúci názov** (`vepo.pending`, poškodený súbor nastavení pri prvom uložení — Q2 predvolené áno, čaká na
potvrdenie Michala) = ako zadaný + bodka + „neuložené k súboru", tooltip = serverová `vepo.notice`. Tooltipy ostatných podôb skladá JS z `vepo.source`/`vepo.file`
a verzie. **Editor na mieste** (vzor `bridge.js` `startCabRename`): klik/Enter/medzerník na `#jobName` → `<input id="jobEdit" class="jobinp" maxlength="120">` (fokus,
označený text, dovetok preč), **zachytí `ST.model_guid`** (R-02). Enter alebo blur → editor sa **hneď zavrie**, hlavička **optimisticky** ukáže odoslaný text a
`sendVepoOpts({ project }, zachytený guid)` (jediná cesta zápisu `studio_set_vepo_opts`); nezmenený text (po orezaní) nič neposiela; stráž `jobSending` = Enter + blur
jeden zápis. Escape na poli (`onkeydown` s `preventDefault` + `stopPropagation`) zruší bez zápisu — dokumentová reťaz (`nx_esc.js`, menu VEPO) ho nedostane.
**Plný push počas písania:** ten istý dokument → `renderHead` editor **neprepíše** (len nadpis a nápoveda sekcie); iný dokument → editor zmizne bez odoslania
(`dropJobEdit`). **Echo** `push_vepo_bar` → `NX.setVepoBar`: obnoví `ST.vepo` a `VEPO_EXPECT`, hlavičku (ak sa v nej nepíše) a **na mieste** (`jobRefreshExports`)
bodku a tooltip štyroch exportov — lišta sa neprekresľuje (fokus v hľadaní a otvorené menu VEPO ostanú); `#mergeChk` ako doteraz. Echo ide po zápise názvu či 18 + 36
(aj pri zlyhaní — O8) a **po každom exporte** (obaly `do_export`/`do_hw_csv`/`do_budget_xlsx`/`do_cp_xlsx` v `ensure`, aj pri odmietnutí); generáciu nedvíha.
**Štyri exporty** (VEPO, CSV kovania, XLSX rozpočtu, cenová ponuka): bodka `.xdot` a tooltip z jednej funkcie `nxJobExport(kind)` (`JOB_EXPORTS`, aj pre `budget.js`
cez `budJob`) — dnešný text + meno priečinka/súboru zo **servera** (`vepo.export_names`, klient nič neodvodzuje); bodka **len pri `default`** (pri čakajúcom nie).
**`expect` (audit H7 §16 B2, §17 C1):** každé zo štyroch exportných volaní nesie `expect: nxVepoExpect()` = `{ project, merge, source }` z klientskej premennej
`VEPO_EXPECT` (nastaví ju payload/echo, commit editora a zmena `#mergeChk` — nikdy DOM; `source` = zdroj, ktorý hlavička práve ukazuje); server export bez zhody
**nespustí**, automatický → automatický názov (napr. model sa medzitým uložil) toleruje (odsek `production_core.rb` v outputs.md). Klik na export z otvoreného editora = mousedown → blur (zápis) → click (export s napísaným textom); poradie callbackov SketchUpu nie je oficiálne
zdokumentované ani overené sondou — pri obrátenom poradí server export odmietne a stačí klik znova (súbor pod neuloženým názvom nevznikne). Testy
`tests/js/test_h7b_hlavicka.js` (verný režim `minidom.faithful(true)`), `tests/pure/test_h7b_nazov_zakazky.rb`.

Testy okna: `tests/pure/test_st1a_studio.rb`, `tests/js/test_st1a_studio.js`, in-SU `run_st1a`. Plné znenie (vrátane zaniknutých premostení a okien): archív,
„studio_dialog.rb + ui/studio.html + ui/js/studio.js — okno ŠTÚDIO (ŠT-1a)".

### ui/js/studio_sections.js — register sekcií Štúdia

**Čo to je:** jediný zoznam sekcií okna Štúdio na klientovi (`window.NXStudioSections`, v Node `module.exports`) — čisté API bez DOM a bez závislostí, riadky
aj skupiny zmrazené. **Autorita whitelistu ostáva Ruby** `StudioDialog::SECTIONS`; register je prezentácia v tom istom poradí. Zhodu (aj poradie) stráži
nezávislá fixtúra `tests/fixtures/h14_studio_sections.json` (vznikla zo starého kódu, nikdy ju nevyrába generátor z registra): JS test ju porovná s registrom,
Ruby test so `SECTIONS` — žiadny regex nad zdrojom druhej strany.

**Riadok:** `id` · `grp` (`job` ZÁKAZKA, `catalogs` KATALÓGY, `settings` NASTAVENIA) · `ic` (ikona spritu, každá iná) · `t` (názov v navigácii = nadpis) ·
`hint` (len doplnok tooltipu navigácie, dnes `cut`) · `badge` (`ctrl` = semafor zákazky `ST.counts`, `appl` = `ST.appl.job.counts`) · `head` (nápoveda
hlavičky) · `refresh` (hláška počas „Obnoviť"; bez nej `REFRESH_DEFAULT` „Prepočítavam kusovník…" — Šablóny vedome, Q1 H14) · `module` (súbor, ktorý sekciu
kreslí) · `data` (kľúč payloadu `NX.setStudio`; guard overí, že ho `push_state` skladá — skladanie payloadu ostáva v Ruby explicitné).
**Háčiky (mená funkcií):** `tools` / `body` (lišta a telo; `stale: true` = lišta dostane príznak neaktuálnosti ako argument — `cut`, `mat`, `hw`, `rules`,
`tpl`) · `missing` (núdzový text tela, keď sekčný modul chýba; lišta je vtedy prázdna) · `leave` (`mat`, `hw`, `appl` — modály mimo tela, beh na serveri) ·
`enter` (`about` — check verzie) · `anchor` `{ fn, phase: 'before'|'after', miss }` (len deep-link: `bom`, `mat` pred vykreslením, `budget`, `appl` po ňom).
**Rozlíšenie v čase volania:** háčiky sekcií s `module: 'studio.js'` (`bom`, `ctrl`, `buy`) z tabuľky `OWN_HOOKS` v `studio.js` (pri `require` v Node nie sú
jeho funkcie globálmi) — chýbajúci vlastný háčik je **chyba programu** (vyletí, zachytí `errors.js`), nie prázdna lišta; ostatné cez `fn(meno)`.

**API:** `ids()` · `has(id)` (len reťazec zo zoznamu — nie `null`, číslo ani `'__proto__'`) · `get(id)` (riadok alebo `null`) · `groups()` (`[{ grp, t, items }]`)
· `inModule(file)` · `fn(meno)` (globálna funkcia **v čase volania**, len vlastná vlastnosť globálu — `let`/`const` ani zdedené meno nenájde)
· `REFRESH_DEFAULT`. Zoznamy sú vždy nové polia a konzumenti si ich pýtajú **až pri použití** (poučenie H12) — pri načítaní si berú len referenciu na objekt.

**Kto číta:** `studio.js` (`renderNav`, `renderHead`, `navItem`, `navCounts` cez `badge`, `requestRefresh`, `renderTools`/`renderBody`, jediná cesta prechodu
`studioSwitchSection` — whitelist, `leave`/`enter` — a kotvy deep-linku),
`shell.js` (`NXShell.studioSection` — filter „Otvoriť v Štúdiu", funguje hneď, nečaká na `NX.init`), `studio_settings.js` (`ssActive` =
`inModule('studio_settings.js')`). **Poradie načítania:** `studio.html` za `icons.js` a **pred** `studio.js`, `panel.html` **pred** `shell.js`; inde sa nenačítava
(guard). Keby chýbal, skripty sa načítajú a chyba sa prejaví až pri prvom použití (zachytí ju `errors.js`).

**Ako pridať sekciu:** kontrolný zoznam [rozsirovacie-body.md](rozsirovacie-body.md) §4. Testy: `tests/js/test_h14a_register.js` (register = fixtúra, API),
`tests/pure/test_h14a_register.rb` (parita R4, guardy R5: zoznam sekcií mimo registra, neznáme id vo volaní, poradie skriptov),
`tests/js/test_h14b_prepnutie.js` (háčiky existujú pred špehmi a patria súboru `module`, `OWN_HOOKS` v Node, kotvy len v deep-linku, neznáme id bez zápisu do okna),
`tests/pure/test_h14b_prepnutie.rb` (guard: `studio.js` nevetví podľa id sekcie mimo ozveny Kontroly, háčiky iných súborov nevolá menom), golden
`tests/js/test_h14_golden.js` + `tests/pure/test_h14_studio_sekcie.rb` (navigácia, prechody, kotvy, hlášky a payload bez zmeny).

### StudioModelWatch — indikátor neaktuálnosti okna („Obnoviť" zožltne)

Štúdio čísla **neprepočítava samo** — po zmene modelu (prestavba z Inspectora, posun, Späť/Znova) tlačidlo „Obnoviť" **zožltne**, aby sa neexportovalo zo starých
čísel. Okno má **vlastný `Sketchup::ModelObserver`** (commit · undo · redo · abort; trieda pod guardom `defined?(Sketchup::ModelObserver)`).
`PanelModelObserver` ani `ScaleWatch` sa na to nepoužívajú (prvý počuje len Späť/Znova/Abort, druhý filtruje vlastné prestavby).
- **Callback je prázdny:** `@epoch += 1` a latch `UI.start_timer(0)` — žiadne čítanie ani zápis modelu; burst commitov = jeden `js`.
- **Porovnanie epoch:** `push_state` si ukladá `@pushed_epoch = @epoch` **až na konci** (po `fresh_collect`, keď payload odišiel) — transakcie spustené samotným
  prepočtom (zápis rozpočtu s `bump: false`) sa tým pohltia. Flush posiela `NX.markStale()` len pri `@epoch > @pushed_epoch`, so živým oknom a **dvojitým guardom
  dokumentu** (`txn_model_ok?` v callbacku aj v timeri).
- **Lifecycle = život okna:** attach v `ensure_dialog` (anti-double `remove → add`, vlastný rescue), detach v `set_on_closed`, prevesenie a nulovanie epochy pri
  prepnutí dokumentu (`on_model_changed`) — epocha je per dokument. Žiadny `Engine` broadcast.
- **Klient** drží `staleFlag` (stav okna); `NX.markStale()` prekreslí len lištu aktívnej sekcie, zhadzuje ho **výhradne plný payload** `setStudio` (echá nie).
  Jantár cez `--nx-warn*`. Signál znamená „možno neaktuálne" (aj posun cudzieho objektu ho vyvolá).
- Žiadny prepočet, zápis ani krok Späť. Testy `tests/pure/test_stale_obnovit.rb`, `tests/js/test_stale_obnovit.js`, in-SU `run_stale` (commit = 1 · burst 3 = 1 ·
  vlastný tick prepočtu = 0 · zápis rozpočtu = 0 · Späť/Znova = 1 · cudzí dokument = 0 · po zatvorení okna 0).

### Sekcia KUSOVNÍK v Štúdiu (Š1–Š6)

**Čo robí:** zoznam všetkých výrobných dielcov zákazky v troch pohľadoch **Dielce · Platne · ABS**, hľadanie (aj zúženie na skrinku z Inspectora), voliteľné
stĺpce, klik na riadok označí dielce v modeli, VEPO export (názov zákazky je v hlavičke okna). **Dáta:** `push_state` posiela kľúče kusovníka na najvyššej
úrovni payloadu (`studio_dialog.rb`, zber `Bom` + `ProductionCore`): `rows` (`ProductionCore.rows_with_roles`; každý riadok nesie pole `refs` na entity
v modeli), `sheets`, `edging` (pohľad ABS), `summary`, `sheet_estimate`, `totals`, `materials_meta`, `edges_meta`, `vepo`; klient ich drží v `ST` (`ST.rows` …) — kontrakt výstupov a VEPO: [outputs.md](outputs.md), [../../SYSTEM/VEPO_KONTRAKT.md](../../SYSTEM/VEPO_KONTRAKT.md);
stĺpce: `UI20_KONTRAKT.md` Š2. **JS:** `studio.js` — `partsTable` / `sheetsTable` / `absTable`, `COLS` + `cellValue` + `activeCols`, `bomToolsHtml(vepo, st)`,
`vepoBtnHtml`/`vepoMenuHtml`, `cutLinkHtml`, `absCompact`/`absFull`.

- **Lišta** = čistá funkcia `bomToolsHtml(vepo, st)` (stav argumentom): `[Dielce · Platne · ABS] · [hľadanie] · ⟶ · [VEPO export ▸roh] · [Stĺpce] · [Obnoviť]`.
  Pole „Projekt" zaniklo (H7b, O2) — názov zákazky sa upravuje v hlavičke okna; zápis `studio_set_vepo_opts` → `%APPDATA%` a **cielené echo** `push_vepo_bar` →
  `NX.setVepoBar` (nedvíha generáciu — inak by klik hneď po editácii názvu spadol na „Dáta okna sa medzitým zmenili"); stav checkboxu sa nasadzuje pri **každom** pushi.
  Exporty názov z JS neberú (autorita `ExportSettings.project_name`), posielajú len kontrolu `expect`. Od H7a zápis vracia výsledok: zlyhanie (poškodený súbor
  nastavení, zámok) okno povie červeno s dôvodom a echo `setVepoBar` ukáže uloženú pravdu (odsek `export_settings.rb` v outputs.md). Tlačidlo VEPO nesie bodku
  a tooltip s menom priečinka (odsek okna ŠTÚDIO).
- **Rohové nastavenie VEPO** (`.cornerzone` v pravom dolnom rohu tlačidla, `.vepofly`): jediný prepínač **„18+36 spolu"**; otvorenosť čisto klientska
  (`vepoMenuOpen`); hodnotu nasadzuje echo `NX.setVepoBar` aj do otvoreného okna.
- **Stĺpce:** voliteľné stĺpce v `localStorage` `nx_bom_cols`, zbalené skupiny `nx_bom_groups` (len zobrazovacie veci počítača). Tabuľka Dielce má triedu `parts`,
  bunky a hlavičky `c-<kľúč>` (`colCls`). **Pevné rozloženie len pri predvolených stĺpcoch:** `partsTableClass(cols)` pridá `fixed`, keď sú zapnuté len stĺpce
  z `PARTS_FIXED_COLS` (Dielec, Skrinka, Dĺžka, Šírka, Hr., ks, ABS) — šírky Dĺžka/Šírka 64 px, Hr. 52, ks 44, ABS 190, akcie 56, Skrinka 22 %, Dielec zvyšok,
  textové bunky sa zalamujú (`overflow-wrap: anywhere`). So zapnutým Smerom dekoru alebo Rolou `fixed` nie je (automatické rozloženie).
- **Zápis čísel:** dĺžka a šírka celé mm (`nxfDim` = VEPO `rounded_dims`), **hrúbka skutočná** (`nxfMm`: 18,6; obchodnú 18/36 nesie VEPO) v hlavičke skupiny,
  stĺpci „Hr." (`cellNumText`) aj pohľade Platne; ABS hrúbka „0,8 mm" / „1 mm", bm na 2 desatinné. **Bunka ABS:** `absCompact` vráti „0,8 dookola", keď všetky štyri
  kódy nesú tú istú pásku so známou hrúbkou (`absAround`), inak plný kompakt; titulok `absFull`. Kódy `L1/L2/W1/W2` sa **zámerne neprekladajú** na strany (pri každej
  role iná fyzická hrana — kreslí ju karta dielca).
- **Súčtový riadok neukazuje súčet platní** (sčítaval by platne rôznych dekorov) — pohľady Dielce aj Platne majú preklik **„Nárezový plán"** (`cutLinkHtml`,
  `data-nav="cut"` → `studioGoSection('cut')`). `totals.plates_min/max` v payloade ostali nevyužité a `studio.js` ich čítať nesmie (`tests/js/test_h3_zobrazenie.js`).
  Stĺpec „Odhad platní" po materiáloch v pohľade Platne ostáva (orientačný).
- **Pohľad Platne** skladá riadky zo `sheets` **aj** `sheet_estimate` (duplák len z lepených dielcov sa reálne nakupuje). **Pohľad ABS** nemá „bm s rezervou" ani
  „€/bm" (patria Rozpočtu; dopočet rezervy v klientovi je zakázaný — hovorí to hint).
- **Kotva z Inspectora** (ID skrinky) predvyplní hľadanie; vymazanie filtra prežije refresh. **Klik na riadok** → `studio_do_select` cez relay panela (generácia
  okna, flush handshake) — výber nič nezapisuje.
- **Vedomé odchýlky:** stĺpec „Poznámka" neexistuje (nie je zdroj); exporty XLSX/CSV kusovníka v lište nie sú, kým nebudú reálne (kontrakt Š5).

Testy: `tests/pure/test_st1a_studio.rb`, `tests/js/test_st1a_studio.js`, `tests/js/test_h4a_format.js`, `tests/js/test_h3_zobrazenie.js`, in-SU `run_st1a`.

### Sekcia KONTROLA v Štúdiu (Š8–Š11)

**Čo robí:** semafor nálezov zákazky (RED/ORANGE/zelená), zoznam nálezov s klikom do modelu a kontextovými opravami, prepínače kontrol (hrany, kresba, smer
otvárania). **Dáta:** v tom istom pushi ako Kusovník (`control` · `counts` · `edge_check` · `grain_check` · `direction_check`) — prepnutie sekcie na server nechodí;
každý prepínač má lacné echo (`push_edge_check` / `push_grain_check` / `push_direction_check`), ktoré prekreslí len lištu. Nálezy skladá `Validation`
([outputs.md](outputs.md)). **JS:** `studio.js` — `semaforHtml(counts, filter, list)`, `ctrlListHtml`, `ctrlRowHtml`, `greenChipParts`, `ctrlOrangeRowCount`,
`edgeCheckInfoText`.

- **Š8 semafor:** tri chipy — červený a oranžový sú **filtre** (`ctrlFilter`, stav okna; filter len skrýva — index riadku ostáva indexom do serverového poľa), zelený
  „N zo M skriniek bez nálezu" je informačný. **Čísla sú serverové** (`Validation.counts`: `cabinets`/`clean`; menovateľ = skutočný počet skriniek zo zberu
  `collected[:cabinets]`, nie dĺžka `placements`). Predložku dáva `skZo(n)`; `cabinets === 0` = „0 skriniek v modeli", `clean` null = „—". Oranžový chip: „10 nálezov
  v 5 riadkoch · skontroluj pred objednávkou" — **počet riadkov je jediné číslo, ktoré počíta klient** (vedomá výnimka: je to údaj o zozname, nie o dátach;
  `ctrlOrangeRowCount` zo zdieľaného predikátu `ctrlUniGrouped`, parita pod testom). Prijatý limit: nález „dva kusy na jednom mieste" nesie `owner_id` prvého
  vlastníka skupiny.
- **Skupina „Nenahradené UNI materiály"** (ORANGE `uni_material`, predvolene zbalená, s počtom dielcov): `ctrlListHtml` ju vloží na miesto prvého UNI nálezu, deti
  `ctrlRowHtml` s indexom do serverového poľa; hlavička len prepína (`aria-expanded`, drží fokus); `ctrlUniOpen` prežije filter aj payload toho istého dokumentu.
  Semafor, badge, validácia, dedup ani exporty sa nemenia. Testy `tests/js/test_d122_uni_skupina.js`.
- **Š9 riadok:** bodka závažnosti · text · miesto · akcie. Klik a **oko** = `nx_select` s `problem_key` (stabilný kľúč, nie pids; jadro `ProductionCore.do_select`),
  **ceruzka** = to isté + `focus_inspector`. Rovnaké jadro majú všetky klik-selecty okna, každý s vlastnou adresou: `parts_key` (Kusovník), `hw_key` (generika),
  `material_key`/`abs_key` („Kde sa používa"), `rule_ref` (Pravidlá), `source_ref` (pôvod v Nákupe).
- **Kontextové opravy len tam, kde existujú:** UNI nález → **„Nahradiť UNI…"** (`replace_uni` → `MaterialsDialog.request_replace_uni`); rozpočtový nález → sekcia
  Rozpočet (`studioGoSection('budget')` + `budGoto(budget_section)`); ORANGE `layout_settings` → sekcia Nastavenia rozpočtu (`data-act="bset"`, bez oka a ceruzky);
  RED „chrbát v drážke zo staršej verzie" (`back_cut`, `fix: 'rebuild_stale'`) → **„Prestaviť zastarané skrinky"** (`data-act="rebuild"`) — **zápis do modelu
  s flush handshakom**: `back_rebuild_stale` → `StudioDialog.handle_back_rebuild_stale` → `NX.studioRelayBackRebuild` → `studio_do_back_rebuild` →
  `Panel.back_rebuild_stale`; server overí `gen`, `flush_blocked`, `model_guid` a pokoj observera, skrinky vyberie z čerstvého zberu a prestaví `rebuild_many` (jeden
  krok Späť), preskočené vymenuje; klient drží `ctrlRebuildBusy`, zhodí ho každý plný push (každá vetva končí `repush`).
- **Š10 lišta:** **jeden riadok** s tromi prepínačmi — „Zvýrazniť hrany" s rohovým nastavením (zdieľaný `edge_menu.js`, `.ecmenu-studio`; otvorenie zavrie kópiu
  v raile — `edge_menu_open` → `Engine.close_edge_menu(:studio)`; zatvára klik mimo a Escape), „Smer kresby", „Smer otvárania" (`dcBtn`/`data-dc`,
  `directionBtnHtml` + `directionCheckText`). Text lišty skladá `edgeCheckInfoText` z častí **zapnutých** prepínačov (`edgeCheckText`, `.gcinfo`, `.dcinfo`) spojených
  „ · "; veta „Vypnuté — v modeli nie je nič nakreslené." len keď nie je zapnuté nič.
- **Š11 badge:** položka navigácie nesie živé RED/ORANGE počty z tých istých `counts` (čistá zákazka badge nekreslí).
- **Deep-link → karta čela:** ceruzka pri RED náleze smeru otvárania vyberie **vlastníka (korpus)** a len pri otvorenom Inspectore pošle `NX.focusFront(front_id)`
  (`PartKeys.front_id`); klient prepne na Čelá, otvorí kartu a doscrolluje; neznáme ID = nič. Rozhoduje server: `ProductionCore.select_target_item` adresuje nález
  bez `part_key` (vetva `pids_for_problem` pre korpusové nálezy); obyčajný klik označí dielec (`front_focus_status`).
- **Deep-link → riadok v Kovaní:** nález s konkrétnym riadkom nesie adresu v `data` (`owner_part_key` + `generic_type` + `rule_id` + `orphan`) zo
  **`Validation.hw_target`** (`stable_key` sa nemení): vypnuté kovanie (`orphan: true`), `hardware_unmapped`, `drawer_kit`, `hardware_code` zo setového zdroja
  (ad-hoc nie) a konflikt zásuvky len pri kóde z `Recipes::OVERRIDE_CONFLICT_CODES` a **práve jednom** zásahu výsuvu. `ProductionCore.do_select` adresu prepošle
  (`hw_focus_target`, vetva kovania pred kartou čela) → `Panel.push_focus_hardware` → `NX.focusHardware` → `nxFocusHardware` (kontext Kovanie, riadok, `hwFlash`);
  neexistujúci riadok = nič. Výber = vlastník (korpus).

Testy: `tests/pure/test_st1b_kontrola.rb`, `tests/js/test_st1b_kontrola.js` (+ `test_d104`/`test_d105`/`test_k2`/`test_abs_rail_3stav`), `tests/pure/test_kovd4_ui.rb`,
`tests/js/test_kovd4_ui.js`, in-SU `run_st1b`. Komentár v `studio.js` odkazuje na tento odsek (výnimka počtu riadkov). Plné znenie: archív, „Sekcia KONTROLA v Štúdiu".

### Sekcia NÁKUP KOVANIA v Štúdiu (Š7)

**Čo robí:** nákupný zoznam kovania zákazky zo setov (kategórie ako medzihlavičky, riadok mimo katalógu jantárovo, súčet „len známe ceny" s počtom nezadaných),
zoznam **„Bez kódov"** a **generika podľa pravidiel** s klikom na vlastníka; CSV export (bodka a tooltip s menom súboru, `expect` — odsek okna ŠTÚDIO) a „Obnoviť"
v lište. **Dáta:** payload `hardware` a `hardware_sets`
z `ProductionCore` (expanzia setov [hardware.md](hardware.md), výstupy [outputs.md](outputs.md)). **JS:** `studio.js` — `buySection`, `price`, `hwManualMark`,
`hwSourceGroups`, `hwStopOwners`/`hwStopCount`, `hwMissWhere`/`hwMissWhereTitle`; CSS `.hwsec`/`.hwbanner`/`.hwcat`/`.hwmiss`/`.hwsum` v `studio.html` (tokeny).

- **Okno hovorí po slovensky, CSV nie:** popisky skladá jadro `ProductionCore.hardware_sets_labeled(hw_exp)` — **nová kópia** s `category_label`
  (`HardwareCatalog.category_label`) a slovenským `label` nemapovanej položky (`HardwareRules.label_for`); vstup `hw_exp` sa nemutuje (čítajú ho plán, Rozpočet,
  Kontrola, spotrebiče). CSV kovania (`do_hw_csv`) počíta nákup nanovo s kódom kategórie a je bajtovo rovnaké (test `kovh_golden`). Generika: stĺpec Parametre
  zo serverového `params_text` (fallback `params_label`), stĺpec **„Kde" = zlúčený pôvod zo servera** (`where`, „CAB-003 ×2", ručná sa nezleje s pravidlovou,
  tooltip `manual_note`); `breakdown` (`owner_pid`) ostáva pre klik-select. **Klient nesčítava.**
- **Zápis:** ceny cez `nxfMoney`, množstvá cez `nxfQty` (necelé množstvo kovania v metroch sa neskryje). Jednotku katalógu (`m`, `par`, `sada`…) prekladá
  `nxfHwUnitCode` (`studio.js`, mapa `NXF_HW_UNIT`) — **JS zrkadlo `Budget::HW_UNIT_LABELS`** (`core/budget.rb`), aby Nákup písal jednotku ako Rozpočet („bm",
  „pár", „set"); neznáma jednotka ostáva surová (Ruby jadro ju počíta ako `KS`). Zhodu máp stráži paritný test `tests/pure/test_hw_unit_zrkadlo.rb`.
- Tabuľky preberajú `.bomtab` Štúdia s markerom **`.hwtab`** (ruka a hover len na `tr.hwgen`). Riadok generiky je `tr.hwgen` — žiadny `<tr>` nesmie niesť triedu, ktorej
  `panel.css` dáva flex/grid (guard `tests/pure/test_tr_flex_kolizia.rb`).
- **Chip „ručná" a pôvod:** riadok s ručnými kusmi (`adhoc_quantity > 0`) alebo voľná položka nesie chip „ručná" (voľná má v Kóde pomlčku). Klik na riadok rozbalí
  **„Pôvod"** — zdroje **zoskupené per skrinku** (`hwSourceGroups`: „CAB-3 · 6 ks: F1 · dvierka ľavé · set … ×2 · …", poradie prvého výskytu, `owner_part_key: null`
  = „celá skrinka", zdroj bez `cabinet_id` v tlmenej skupine „—"). `owner_label` dopĺňa server (`ProductionCore.decorate_source_owners` z `cabinet_fronts`).
  **Zdroje sú klikateľné** (`data-src-cab` + `data-src-key` → `nx_select` so `source_ref` + `focus_inspector: true`; delegácia spracuje `[data-src-cab]` pred
  `tr.hwbuyrow`); klik Inspector neotvára, len zdvihne — pri zavretom to povie status. **Pamäť rozkliku prežíva push** (kľúč = identita riadku: `free_key` alebo
  `code` malými písmenami), maže sa len pri zmene dokumentu.
- **„Bez kódov":** položka výsuvu z receptu bez kitu je **zastavujúca** (`tr.hwstop`, červená) s vetou nad tabuľkou o počte zásuviek a odkazom na Kontrolu;
  závažnosť určuje server príznakom `blocks_export` (`HardwareSets.unmapped_entry`). **Veta počíta zásuvky, tabuľka riadky** (`hwStopOwners` dedupuje podľa
  `cabinet_id` + `owner_part_key`). Stĺpec „kde" ukazuje serverový `owner_label` (`ProductionCore.decorate_unmapped` → `owner_label_for`), surový kľúč ostáva
  v `title`; pole je aditívne a CSV sa nemení.
- **Export** vlastným kanálom okna: `hw_csv_export` → `handle_hw_csv` → `NX.studioRelayHwCsv` (flush handshake) → `studio_do_hw_csv` → `ProductionCore.do_hw_csv`.
  Klik na generiku → `nx_select` s `hw_key`.

Testy: `tests/pure/test_st1c_nakup.rb`, `tests/js/test_st1c_nakup.js`, `tests/js/test_d93_nl_override.js`, `tests/js/test_d94_povod.js`, `tests/pure/test_d94_povod.rb`,
in-SU `run_st1c` a `run_d94`. Plné znenie: archív, „Sekcia NÁKUP KOVANIA v Štúdiu".

### Sekcia ROZPOČET v Štúdiu (Š12–Š13)

**Čo robí:** rozpočet zákazky po sekciách (Materiál, ABS, Kovanie, Služby, Spotrebiče, vlastné položky…), režim *€ · €€ · €€€*, DPH, prepočet cien, ručné overenie cien
dosiek a ABS, spotrebiče s vlastníkom, XLSX rozpočtu (bodka a tooltip s menom súboru cez `budJob`, `expect` cez `budExpect` — odsek okna ŠTÚDIO). **Jediná sekcia, ktorá cez rozpočet zapisuje do modelu** (1 zmena = 1 krok Späť). **Dáta:** payload `budget`
z `ProductionCore` / `Budget` ([outputs.md](outputs.md)); mutácie `budget_mutate` → `StudioDialog.do_budget` → `ProductionCore.do_budget`. **JS:** `ui/js/budget.js`
(prefix `bud*`/`BUD_*`, načítava sa **až za `studio.js`** — `studio.js` priraďuje celé `window.NX`; guard test).

**Lišta a telo:** `budToolsHtml` (prepínače *s DPH/bez DPH* a režim, „Prepočítať ceny", „Obnoviť", XLSX rozpočtu, „Nastavenia" s ikonou `sliders-horizontal`
ako položka `bset`) a `budDrawBody` (veľký súčet, jantárové chipy, zbaliteľné sekcie); `budRerender()` kreslí oboje a fokus obnovuje **raz** (`budCaptureFocus` na
začiatku, `budRestoreFocus` na konci).
- **„Prepočítať ceny"** (`budPriceBtnHtml`) je **jantárové, keď zákazka nesie staré ceny** — čistá projekcia poľa `stale` (`budStaleLabel` do tooltipu, `.bstalebtn`,
  `--nx-warn*`, nikdy zelená); počas behu `disabled` bez jantáru. Fázové okno prepočtu `#budPrModal` riadi server (vo fáze `run` sa Escapom nezatvára). Pri samých
  ručných cenách hlavné tlačidlo „Skontrolovať ceny" otvorí zoznam (`budPrStart`); čip „N cien na kontrolu" podľa `counts.manual_pending` (`budManualPending`).
- **Jantárový chip súčtu** počíta **všetky** rozpočtové nálezy a vedie do sekcie Kontrola (chip spotrebičov je skratka na ich sekciu); nález kategórie `budget`
  v Kontrole otvorí `budget_section`. Preklik na ponuku `budCpLinkHtml` (suma + stav + šípka).
- **Zápis množstiev:** `budQty`/`budUnit`/`budMoneyIn` → `nxfQty`/`nxfUnit`/`nxfMoneyIn` (`budNxf`); kódy MJ v payloade, serverová `poznamka` aj XLSX sa nemenia.
  Peňažné polia majú hodnotu `nxfMoneyIn` a za poľom „€" (`BUD_EUR_AFTER`); `budParse(nxfMoneyIn(x)) === x` stráži test; `budFmtEur` = dvojča `nxfMoney`.
- **Kanály:** mutácia ide **priamo** (bez flush handshake); **oba XLSX exporty** handshake majú (`budget_xlsx`/`cp_xlsx` → `NX.studioRelayBudget`/`studioRelayCp` →
  `studio_do_budget_xlsx`/`studio_do_cp_xlsx`).
- **Generačný kontrakt:** push po mutácii rozpočtu = `push_state(bump: false)` (plný payload, generácia sa nedvíha — `rows`/`refs` sa nemenia); každá iná zmena
  generáciu zdvihne a mutácia so starým `gen` sa odmietne; prvý push zdvihne vždy. Fronta zápisov `BUD_BUSY`/`BUD_QUEUE` sa uvoľňuje **výhradne v `NX.setStudio`**
  (echá `gen` nenesú); poistný timer `BUD_BUSY_MS` 6 s. **Položka fronty nesie `{op, extra, doc, gen}` z okamihu kliknutia** (`budSend`), odošle sa s nimi;
  `budDocSwitched` pri každej zmene dokumentu vyhodí zápisy iného dokumentu a `budAfterPush` cudzí zápis neodošle (dôsledok: odmietne sa aj zápis, ktorý čakal za
  mutáciou zdvíhajúcou generáciu — používateľ klikne znova). Mutácia spotrebiča s prestavbou vracia `geometry_changed` → push `bump: true` + čerstvá karta
  Inspectora (`Panel.push_selected(dedup: false)`).
- **Modály** = kostra D-15: „Pridať položku", „Pridať spotrebič" (`budDraftFields`), ⋯ editor riadku (bez `memoryKey`; korelácia `BUD_MORE.sent`) — odsek „D-15
  modal".

**Nekompatibilné dáta rozpočtu** (zákazka z novšieho pluginu alebo poškodený marker `budget_std`): payload nesie `budget.budget_std` (`{ state, blocked, reason }`,
`Budget.std_payload`) a klient **v Rozpočte aj Ponuke** (1) kreslí trvalý banner `budStdBannerHtml`, (2) jedným prechodom `budStdDisable(box)` po každom kreslení
vypne ovládače zo zoznamu **`BUD_STD_OFF`** (nový ovládač, ktorý zapisuje zákazku, patrí doň), (3) poistka v `budSend`, `budXlsx`, `budCpExport`. Zapnuté ostávajú
DPH, „Obnoviť", „Prepočítať ceny" a tlačidlá `mat-*` (zapisujú katalóg, nie zákazku). Autorita je server (`BudgetStore.write!`, `ProductionCore.budget_std_block`),
text má jeden zdroj `BudgetStore.std_block_reason`; odmietnutie kanálom `NX.budgetResult(op, false)`.

**Ceny podľa plánu:** checkbox „ceny podľa plánu" v `<summary>` sekcie Materiál (`label.bappl` so `stopPropagation`) + tooltip `BUD_PLAN_TIP` (`.nxtip`; `details.bsec`
povolí `overflow: visible` cez `:has`); stav z `budget.plan_prices`, mutácia `plan_prices {enabled}`, ovládač v `BUD_STD_OFF`. Značka zdroja množstva
`budQtyTagHtml` (`.qtag.plan` / `.qtag.est`, tooltip serverový `qty_tip`) len pri riadku s `qty_source`. Po Späť sa checkbox a ceny vrátia až po „Obnoviť"
(in-SU `st1c_plan_prices`). Materiál bez formátu (sklo aj doska) sa počíta podľa plochy (`Budget.area_priced?`).

**Ručné ceny dosiek a ABS · materiál podľa plochy** (všetko projekcia payloadu): ikona odkazu pred názvom (`budMatLinkHtml(r, kind)`, `.hw-product-link` + `.bmatlink`:
`demos` / `product` sivá, `missing` jantárová; UNI, duplák a chýbajúci záznam ikonu nemajú) · stĺpec **„Overená"** (`budMatCheckHtml` → tlačidlo `.bver` „ručne 18.9."
/ „ručne 45 dní" / „neoverená"; tooltip `budMatTip` = kópia `mdManualTip`, parity test `tests/js/test_ceny_m2_budget.js`) · riadok podľa plochy (`qty_basis: 'area'`,
MJ „m²") · zoznam starých cien (`budStaleActionHtml`: „Overiť cenu" `data-action="mat-manual-check"` alebo obnovenie z Demosu). **Kliky `mat-*` obsluhuje
`proj_materials.js`**: `demos` → `open_demos_url`, `product` → `mat_product_open` (URL nikdy od klienta), `missing` → `mdProductFromBudget` (formulár variantu
v Materiáloch s kurzorom v poli odkazu), „Overiť cenu" → `mdManualRequest` so `section: 'budget'` (formulár ostáva v Rozpočte s rovnakým životným cyklom).
Ikona produktu kovania a `hw-manual-check`: odsek „Sekcia KOVANIE".

**Spotrebič v rozpočte:** modal „Pridať spotrebič" — `catalog_id` (`lookup`, prvé pole) · `typ` · `nazov` · `dodavatel` · `cena` · `owner` · `customer_supplied`;
⋯ editor má vlastníka a prepínač (kód ani poznámku nie).
- **Kategórie ani ponuka vlastníkov nie sú v klientovi:** `budApplTypes(b)` z `budget.appliance_types`, `budOwnerOptions(b, cat)` z `budget.appliance_owners`
  (`matrix` + `options` + `job_label`); hodnota `<druh>:<id>` → `budOwnerPayload` `{kind, id, pid}` — **PID je povinný**.
- **„Len zákazka" je prvá voľba a predvoľba** — `budDraftCommit` posiela `owner` len pri fyzickom kuse. Zmena kategórie prekreslí ponuku (`budApplCtxSwitch`).
- Našepkávač `sketchup.appl_lookup({q, gen})` → `StudioDialog.handle_appl_lookup` → `ProductionCore.appliance_lookup` (top 20) → `NX.applLookupResult` (čítanie;
  `onPick` predvyplní polia z `data`, stará generácia sa zahodí). Klient neposiela snapshot ani kategóriu modelu — len `catalog_id`.
- **Modal patrí dokumentu** (zachytený `model_guid`; `budDocSwitched` ho zavrie a zahodí frontu aj dotaz). **Zmena vlastníka** = vlastná akcia `appliance_owner`
  (`budMoreCommit` podľa `budOwnerDirty`); `appliance_update` vlastníka nenesie. Uložený vlastník mimo ponuky dostane výslovnú voľbu navrchu (`budOwnerOptionsFor`).
  Riadok nesie adresu `data-brow="appliance:<uuid>"` pre deep-link.

Testy: `tests/pure/test_st1c_rozpocet.rb`, `tests/js/test_budget_ui.js`, `tests/js/test_np4_ceny.js`, `tests/js/test_ceny_m2_budget.js`, `tests/js/test_s1b1_rozpocet.js`,
`tests/pure/test_s1b1_vazba.rb`, in-SU `run_st1c` (operácie × jeden krok Späť, gen a guid guardy, XLSX guardy) a `run_s1b1`. Plné znenie: archív, „Sekcia ROZPOČET
v Štúdiu" a jeho podnadpisy.

### Sekcia CENOVÁ PONUKA v Štúdiu (Š14–Š15)

**Čo robí:** zákaznícka **projekcia** toho istého rozpočtu — suma ponuky (s priznaným režimom DPH), položky rečou zákazníka, zlúčené v zostave, zaokrúhlenie, XLSX
„Cenová ponuka (zákazník)". **Dáta:** `budget.cp_preview`; mutácia `cp_group` (per-riadok prepínač „samostatne", 1 zmena = 1 krok Späť); export `do_cp_xlsx` (vlastný
dokument Ruby `CpExport.price_sheet`). **JS:** ten istý `budget.js` (`budOfferHtml`, `budOfferToolsHtml`, `budCpTableHtml`, `budCpAmountHtml`) — jeden formát a jeden
kanál.

- Tabuľka: **Položka · Množstvo · MJ · Spolu · V ponuke** („Spolu" = suma riadku). Bunka sumy `budCpAmountHtml`: **„v cene" výhradne pri `kind: 'fixed'`
  s nulou** (Zameranie, Vizualizácie — náklad je rozpustený v zostave). Riadok `info` (spotrebič, ktorý dodáva zákazník) aj `assembly` s nulou ukazujú **0,00 €**;
  neznáma cena „—". XLSX ponuky sa týmto nemení (poznámka pod tabuľkou rozdiel prizná).
- **Ponuka sa needituje** — chýbajúca cena sa dopĺňa v Rozpočte (jantárový guard „Suma ponuky je podhodnotená…" s preklikom). Celý varovný pás `budWarnChips(b)` je
  aj tu (tie isté čísla; ciele: staré ceny a spotrebiče → Rozpočet, upozornenia → Kontrola).
- Zoznam „Zlúčené v zostave" je v `BUD_OPEN` pod `cp_merged` (otvorený prežije prekreslenie). Prepínač DPH sa nezdvojuje; riadok zaokrúhlenia je jedno serverové číslo
  v oboch sekciách. Lišta: „Cenová ponuka (zákazník)" (bodka, tooltip s menom súboru a `expect` ako XLSX rozpočtu) + „Obnoviť". Platí aj banner a vypnutie pri nekompatibilných dátach (odsek Rozpočet).

Testy: `tests/pure/test_st1c_ponuka.rb`, `tests/js/test_st1c_ponuka.js`, in-SU `run_st1c` (`st1c_offer`).

### Sekcia NÁREZOVÝ PLÁN v Štúdiu (`cut`, ui/js/sheet_layout.js)

**Čo robí:** plán rozkroja platní po materiáloch — súhrn, karty materiálov s malými platňami, detail platne v tom istom okne, nezaradené a odmietnuté dielce
s dôvodom, preklik na nastavenia prerezu. Vzhľad: mockup `SYSTEM/archiv/bloky/NAREZ/MOCKUP_NAREZ_2026-09-28.html`. **Dáta:** `push_state` spočíta plán **raz**
(`ProductionCore.layout_for` z toho istého `collected`, `bom`, `smap` a expanzie kovania) a ten istý plán dostane Rozpočet (`budget_payload(…, layout)`) aj sekcia
(`sheet_layout_payload` → `sheet_layout`). Výpočet: [outputs.md](outputs.md) (`sheet_layout`).
- **Kompaktný tvar:** mená riadkov raz v `rows` (`k` natívny kľúč riadku kusovníka, `c` obdĺžniky, pri dupláku `q` a `m` + `fl × fw`), platne `p: [[riadok, x, y]]`
  na 0,1 mm + `o` najväčší zvyšok, `unplaced`/`rejected`/`conflicts` s ľudským dôvodom `t` zo servera, `phrase` = `SheetLayout.count_phrase` (tá istá veta ide do
  Rozpočtu a XLSX). Globálny stav (`blocked`, `without_material`) = **banner nad kartami** aj pri prázdnom zozname. Chyba plánu = `{ok: false}` a veta v sekcii
  (rozpočet ani exporty nezhodí). Detail sa neťahá lenivo (celý push ~2000 dielcov ≈ 377 kB, `push_state` ≈ 105 ms).
- **Klient kreslí, nepočíta:** `sheet_layout.js` (prefix `np`, volá ho `studio.js` cez háčiky riadka `cut` v registri (`npRenderTools` / `npRenderBody`), `NX.setStudio` neobaľuje) — predvolene
  otvorená prvá karta a každá s problémom; **zbalená karta SVG nevytvára**; zbalenie v `localStorage` `nx_np_closed` (try/catch); detail = stav okna `npDetail`
  (pri novom pushi sa overí). Jediné odvodené je **upozornenie na poslednú platňu** (aspoň 2 platne a posledná pod 20 % alebo najviac 2 dielce).
- Karta hovorí „v rozpočte N" **číslom hotového rozpočtu** toho istého pushu (`budget_qty` + `budget_src`, `npBudgetNote`); zdroj `area` = „v rozpočte 0,90 m² podľa
  plochy".
- **SVG je téma-bezpečné:** farby len CSS triedy `.np-*` s tokenmi v `studio.html` (šrafy ako `<pattern>` v skrytom `<svg>`); jediná dátová farba je vzorka dekoru
  v HTML štvorčeku mimo SVG.
- **Lišta:** „Obnoviť" + chip „prerez · orez · duplák" z `params` → `studioGoSection('bset')`; pri predvolených hodnotách (`seed_fallback`/`unreadable`) jantárový.
- **Oko = výber, nie zápis:** `nx_select` s `parts_key` = natívny kľúč riadku (`Bom.row_key`) + `origin: 'cut'` (`refs_for`, relay panela; `cut_select_status`).

Testy: `tests/pure/test_np3_sekcia.rb`, `tests/js/test_np3_sekcia.js`.

### Jeden push kanál nad modelom

Zber modelu (`fresh_collect` + `Bom.compute` + katalógy) beží pri refreshi Štúdia **raz** a všetky sekcie berú dáta z neho. **Pravidlo pre nové sekcie:** čokoľvek
nové, čo potrebuje dáta z modelu, sa priveze v `Bom.collect` (aditívny kľúč, napr. `manual_overrides`, `cabinet_fronts`) a do payloadu sekcie ide **z už hotového
`collected`** — druhý sken modelu kvôli jednej sekcii je zakázaný. Zdieľaná cache zberu ostáva kandidátom na optimalizáciu.

### Sekcia MATERIÁLY v Štúdiu (`mat`)

**Čo robí:** katalóg dosiek a ABS pások (dlaždice dekorov podľa výrobcu + pás „Použité v projekte", detail dekoru s inline bunkami, „Kde sa používa"), predvoľby
materiálov projektu (Korpus · Čelá · Chrbát · Zásuvky), hromadná kresba čiel, pridanie z Demosu, ručné založenie dekoru, duplák, UNI prepínač, mazanie a vrátenie
katalógu. **Server:** telo akcií ostáva v **`MaterialsDialog`** (odsek `materials_dialog.rb`), Štúdio registruje tie isté mená callbackov a volá
`MaterialsDialog.dispatch(name, payload, sink)` — whitelist je jediný (`MaterialsDialog::SECTION_ACTIONS`), `sink` presmeruje odpoveď (`MD.*`). **JS:**
`ui/js/proj_materials.js` (`matRenderBody`, `mdRenderAll`, `matToolsHtml`, `mdWhereHtml`), `demos_diff.js` („Aktualizovať z Demosu"), `demos_add.js` („Pridať
z Demosu"), `md_appearance.js` (vzhľad). Vstupy: menu „Materiály projektu", tlačidlo panela a preklik dekoru → `openStudio('mat'[, id])`.

**Telo a kanál:**
- Telo kreslí sekcia sama — **jeden uzol zo `<template id="matBodyTpl">`**, `NX.setStudio` ho neprekresľuje (rozpísaný „+ variant" ani bunka ceny sa nestratia;
  fokus a dirty baseline obnovuje `mdRenderAll`). Modály v `#matModalRoot` mimo `#secbody`. Sekcia `scan` comboboxov nespúšťa, kým je telo odpojené.
- **Lišta** = čistá `matToolsHtml(state)`: `[Pridať z Demosu] · [Pridať ručne] · [hľadanie] · [zoskupenie] · ⟶ · [Obnoviť] · [⋯]`; primárne je „Pridať z Demosu";
  hľadanie a zoskupenie drží aj premenná (`MD_Q`/`MD_MODE`). Bannery (read-only katalóg · nepoužiteľné ABS · cutover) sú prvé riadky obsahu.
- **Ponuka „⋯"** (`mdMoreHtml(open)`, `.mdmore`/`.mdmoremenu`) nesie núdzové **„Vrátiť katalóg pred migráciou…"** — len pri `backup && !ro`, bez položky sa „⋯"
  nekreslí. Otvorenie lištu prekreslí, zatvorenie nie (len odstráni uzol a prepne `aria-expanded`). Zatvára klik mimo, Tab, odchod zo sekcie (`matCloseModals`)
  a Escape (zavrie len ponuku, vráti fokus na „⋯"; `mdMoreOpen` je medzi `FLYOUT_FLAGS` v `nx_esc.js`). Výber najprv ponuku zavrie a otvorí potvrdzovací
  `mdRestoreModal` → `restore_pre_schema2`. V read-only režime nesie akciu banner.
- **Kanál je delený:** katalógové echo `push_mat_catalog` → `NX.setMatCatalog` prepíše **len katalóg**, nepočíta a **nedvíha generáciu**; plný `push_state` nesie
  modelový kontext sekcie (`mat`: predvoľby, počet skriniek, `model_guid`, `used`, `used_ids`, `front_grain`) a **celý katalóg len pri prvom pushi okna a po
  prepnutí dokumentu** (`@mat_full_pending` — gasí sa len keď katalóg v odoslanom payloade naozaj bol; `mat_payload` má vlastný rescue).
- Generácia okna chodí do sekcie druhým parametrom `matApplyState(m, gen)`.

**Predvoľby projektu:** rozbalené od prvého zobrazenia (`open` len v šablóne); štyri skupiny so vzorkami 115 × 115 px a `NXCombo` (`md_body`/`md_front`/`md_back`);
celý serverový label sa zalamuje; jedna `mdConfirmBar` pod mriežkou. `mdRenderProjectPreview` odvodzuje obrázok/meta z hodnoty selectu a presného `material_id`
(fallback `MD_SHEETS`; volajú ho `mdRenderAll`, `mdSetProjectSelect`, `onProjMaterial`); obrázok len z `image_file` servera cez `mdImageSrc`; UNI nesie text
„Pracovný materiál UNI". Potvrdzovanie, `model_guid` guard, dedenie a Undo idú pôvodnými cestami (1 predvoľba = 1 krok Späť).

**Kresba čiel** (riadok pod predvoľbami — **hromadná akcia, ktorá prestavia model**, nie predvoľba; platí pre čelá, ktoré v zákazke sú teraz): select (Podľa materiálu /
Pozdĺžna / Priečna) + `md_front_grain_apply` → `fronts_grain_all` `{gen, model_guid, grain}`. Vlastný `cb(dlg, …)` a **flush handshake ako exporty**:
`handle_fronts_grain_all` → `NX.studioRelayFrontsGrain` → flush → `studio_do_fronts_grain` → `StudioDialog.do_fronts_grain_all` → `MaterialsDialog.fronts_grain_all`
(červené pole zastaví). Stav riadku a počet počíta server (`mat.front_grain` `{count, cabinets, by, skipped}`); chýbajúci = „stav sa nepodarilo zistiť" + `disabled`.
**Zámok tlačidla:** klik → `Prestavujem…` + `disabled`, odomkne ho až **nový plný push** (každá serverová vetva vrátane odmietnutia a `rescue` posiela `repush`);
**katalógové echo zámok nepustí** a druhý klik pred pushom nepošle nič — inak by z jednej voľby vznikli dva kroky Späť.

**Ručné založenie dekoru** („Pridať ručne") otvára D-69 editor v režime `create` (`mdCreateOpen` → `mdCreateFields`/`mdCreatePayload`, `memoryKey: 'mat:create'`);
stĺpce repeaterov sú jedna definícia `mdSheetCols`/`mdEdgeCols`, prázdny formulár má navyše **Štruktúra** a **Smer dekoru**. Úspech zatvorí modal, zahodí pamäť
a otvorí detail nového dekoru; odmietnutie `:stale` má vlastnú hlášku a `mdEditRefresh` len omladí baseline. Formulár s preset čipmi je **len „+ variant"**
do existujúcej skupiny (typy mimo identity editora — zástena, PD — a skupiny s viacerými štruktúrami). Testy `tests/js/test_st2c_create.js`.

**„Kde sa používa"** (koniec detailu dekoru, `mdWhereHtml`): riadok na vlastníka (`CAB-004 · Bok ľavý · Dno · Polica` + počet) a na každú použitú pásku, oboje
s okom. Dáta = rozpis toho istého zberu: `mat_used_where(collected)` (bez druhého skenu) → `{ kľúč skupiny => { owners: [{owner_id, parts, roles,
material_ids}], edges: {abs_id => {parts, objects}} } }`; roly skladá server (`ProductionCore.role_label`), páska sa ráta za dielec. **`parts` = kusy do výroby,
`objects` = entity v modeli** — pri rozdiele riadok ukáže obe. `used` = `mat_used` + `Materials.decor_key_by_material_id` z toho istého `collected`;
`used_ids` = `mat_used_ids(collected)` (`{sheets, edges}`, dielec bez `owner_id` sa nevyhadzuje). Mapy `decor_key_by_*` stavia `mat_payload` raz
(`Materials.decor_key_by_abs_id` pre pásky). Katalógový payload (`MaterialsDialog.full_catalog_payload`) nesie `row_label` a `row_key` z tých istých metód ako panel.
- **Oko** ide cestou kliku v Kusovníku (`nx_select` cez relay, generácia, žiadne `pids` z DOM): `ProductionCore.refs_for` vetvy `material_key` a `abs_key` (reťazec
  alebo pole) s nepovinným zúžením `owner_id`. **Chýbajúci `owner_id` = bez zúženia, prázdny = vlastník bez identity** (riadok odpojeného dielca sa nekreslí —
  `mat_used_where_owner`). Adresa sa hľadá v BOM riadkoch, teda v **efektívnom** materiáli (aj dedený). Nič nezapisuje.
- **Kotva sekcie** (`openStudio('mat', id)`) otvorí detail dekoru (`matOpenAnchor` → `mdAnchorGroupKey` preloží `material_id`/`abs_id`/kľúč skupiny); neúspech nie je
  tichý — status „Tento dekor už v katalógu nie je — otvorené v zozname materiálov."

**Demos toky** (modály v `#matModalRoot`): **životnosť dlhého behu je viazaná na sekciu** — `demos_alive_proc(session)` sa pýta session tokenu a živého Štúdia;
token zhasína zatvorenie okna (`MaterialsDialog.on_ui_closed`), prepnutie dokumentu a **odchod zo sekcie** (klik aj deep-link → `studioSwitchSection` → háčik `leave` = `matOnLeaveSection` → `mat_leave` →
`cancel_demos_on_leave`, hláška „Sťahovanie z Demosu zrušené…"). Poradie v `matOnLeaveSection`: **najprv `mat_leave` na server, potom lokálne zatvorenie modálov**.

**„Nahradiť UNI…"** beží v jednom okne: nález Kontroly → `ProductionCore.replace_uni` → `MaterialsDialog.request_replace_uni` → `StudioDialog.show(open_section: 'mat')`;
požiadavka sa odloží (`@pending_replace_uni`) a spustí ju `show` (okno už `ready`) alebo `ready` callback až za prvým `push_state`; jednorazová, zomiera so zatvorením
okna aj prepnutím modelu.

Testy: `tests/pure/test_st2a_mat.rb`, `tests/pure/test_st2d_kde.rb`, `tests/js/test_st2a_mat.js`, `tests/js/test_st2d_kde.js`, in-SU `run_st2b` a `run_st2d`.
Plné znenie: archív, odsek okna Štúdio (pasáže ŠT-2a…ŠT-2d) a „materials_dialog.rb".

### materials_dialog.rb

**Serverová autorita katalógu materiálov pre sekciu `mat` Štúdia** (vlastné okno už nemá — sekcia „História"; modul sa nepremenúva). Štúdio preposiela akcie cez
`dispatch(name, payload, sink)` — uzavretý whitelist **`SECTION_ACTIONS`** (katalógové bunky a formuláre, Demos toky `demos_lookup`/`demos_manual_url`/`demos_apply`/
`demos_cancel`/`demos_name_search`/`demos_family*`, `open_search_url`, `replace_uni_preview`/`replace_uni_apply`, `save_decor`, `mat_product_open`, `mat_manual_*`,
vzhľad). `handle_save_sheet`/`handle_save_edge` sú **edit-only** (nové dekory a varianty idú editorom D-69 alebo „+ variant"). Doména: [materials.md](materials.md).

- **Adresát odpovede:** `with_client(sink)` presmeruje `js` na volajúceho **na čas jedného synchrónneho volania** (`ensure` povinné); mimo neho ide všetko do Štúdia
  (`studio_js` → `StudioDialog.mat_js`). Na tom stojí Demos: `dispatch` beh len naštartuje, emity dobiehajú z `UI.start_timer` bez sinku.
- **`after_catalog_change` má jednu cestu:** jeden `catalog_payload` → `StudioDialog.push_mat_catalog`, plus `Panel.push_materials`, `EdgeCheck.invalidate!` a plný payload
  Štúdia s `bump: false`.
- **Štyri cesty menia model** a všetky obnovujú najprv Inspector (`Panel.push_selected`) a až potom plný push Štúdia so zdvihom generácie: projektová predvoľba
  a „Nahradiť UNI…" (`refresh_studio_after_model_write`), aplikovanie vzhľadu (`materials_appearance_dialog.rb` `appearance_refresh_model` →
  `refresh_studio_after_model_write`) a Kresba čiel (`fronts_grain_all` — `rebuild_many`, potom `repush` Štúdia, ktorý odomkne tlačidlo).
- **Životný cyklus** hlási Štúdio: `on_ui_closed` (session bump + zahodenie odloženej požiadavky), `cancel_demos_on_leave` (odchod zo sekcie počas behu) a
  `on_model_changed` zo `scale_observer`; `@demos_running` stráži, aby hláška o zrušení prišla len keď naozaj niečo bežalo.
- **Predvoľby projektu** (`TARGETS`: telo, čelá, chrbát a `default_drawer_material_id`): preflight zásuviek **per systém** (čísla z receptu) — doska, ktorú neprijme
  žiadny systém, sa neuloží; doska, ktorú neprijme systém použitý v zákazke, až po potvrdení v lište `MD.confirmDefault` (pending kontrakt D-46). Vkladanie má vlastný
  preflight `MaterialsDialog.drawer_material_issue` (volá `Panel.handle_insert` pred `prepare_insert`).
- **`save_decor`** = jedna akcia na celý formulár „Upraviť…" detailu dekoru. Handler si guardy **zámerne nerobí** — celý kontrakt vrátane `base_rev` a `row_rev` každého
  riadku beží pod zámkom v `Materials.save_decor`. Odpovede: `MD.editSaved` (zavri + zahoď pamäť) · `MD.editErrors` (chyby k poliam, okno ostáva) · `MD.editBlocked`
  (odomkni, riadky sa dorovnajú z čerstvého katalógu; pri kolízii vlastná hláška) · `MD.editDuplicateCode` (druhé „Uložiť" potvrdí duplicitu kódu).
  **`mdEditRefresh` prelieva len bunky, ktorých sa používateľ dotkol:** porovnanie s `NXModal.baseRows(key)` (`mdSameCell`) — netknutá bunka dostane čerstvú hodnotu,
  zmenená si nechá používateľovu, zmenená oboma ide do modalu ako kolízia (`_conflict` + `_wrote`); `setRows` dostáva ako `base` čerstvé riadky. Test
  `tests/js/test_1b7_kolizia_buniek.js`.
- **Formulár variantu (ceruzka)** — `handle_save_sheet`/`handle_save_edge` robia pred zámkom len `schema_ok?`; kontrola schémy a revízie, načítanie, merge, pravidlá
  odkazu a zápis bežia v `save_sheet_locked`/`save_edge_locked` pod **jedným** `Materials.with_catalog_lock`. Baseline = **`row_rev` riadku z otvorenia** (prázdny =
  konflikt). Konflikt pošle najprv `push_catalog`, potom `MD.formConflict(kind, id)` a status. Pred merge sa strhnú server-owned polia (`FORM_STRIP_KEYS`:
  `price_checked_at`, `price_check_method`, `product_link`, `price_check`, `price_display`, `row_rev`, `label`, `row_label`, `row_key`, `image_file`).
  **`product_url`** (`apply_product_url!`): nie text / neplatný = celý save odmietnutý, prázdny = zmazanie, chýbajúci = bez zmeny; pri výslednej Demos URL sa uložený
  odkaz nemení. Odmietnutý odkaz → `MD.formRejected(kind)` (klient otvorí formulár s rozpísanými hodnotami — `mdReopenFromAttempt` — a kurzorom v poli odkazu).
  Klientska `mdProductUrlLocalError` zrkadlí `URI.parse` (fixtúra `tests/fixtures/ceny_m1_product_urls.json`, Ruby aj Node). Odpovede skladá `form_save_reply` až po
  uvoľnení zámku. Pod tým istým zámkom: echo zobrazenej €/m² (`Materials.sheet_price_echo?`), `form_price_check_note!` = `reconcile_manual_check!` (zmena ceny, kódu,
  dodávateľa, odkazu, formátu, dekoru u dodávateľa či nová Demos URL zruší ručné overenie — `MANUAL_CLEARED_MSG`) alebo `demos_stamp_edit!` (zmena pri Demos väzbe
  zruší dátum z Demosu — `DEMOS_STAMP_CLEARED_MSG`). Bunka (`handle_patch`) povie vetu z `manual_cleared`; echo bez zápisu = „Cena sa nezmenila.".
- **`mat_product_open`** otvorí `UI.openURL` len pre čerstvý ručný záznam s platným odkazom (URL od klienta sa neprijíma), inak status + `push_catalog`.
- **„Overiť cenu"** (`mat_manual_prepare` → `MD.manualReady(snapshot)` — echo `kind, id, token, section, model_guid` + čerstvý `item`, nič nezapisuje, cudzí model =
  `item: nil` · `mat_manual_open` → `UI.openURL` len pri tej istej `row_rev`, neúspech otvorenia = stále `ok` s `opened: false` a vetou (neblokuje) ·
  `mat_manual_confirm` → schéma, model (`DocKey.foreign?` → `stale_model`), `Materials.confirm_manual_price`; `:ok` → `after_catalog_change` + status s cenou a dátumom).
  Odpoveď `MD.manualResult` (`phase`, `ok`, `status`, `msg`, `errors`, snímok; výnimka vráti `error` s tokenom). Tok nepoužíva Demos session. Sekcia v echu je `mat`
  alebo `budget`.
- **Payload** `full_catalog_payload(stale_days)`: `row_rev` zo surového záznamu, `row_label`/`row_key` z tých istých metód ako panel, `product_link` (len ručné záznamy,
  `product_link_extra!`), `price_display` na každom riadku, `price_check` pri ručnom (`manual_price_extra!`); `catalog_payload` nesie `stale_days` (fail-soft 30).

**Klient** (`proj_materials.js`) — slot troch ikon `mdSlotHtml` (duplák/univerzálna · Demos alebo odkaz · overenie): `mdProductBtn` (sivá = otvorí server, jantárová =
formulár s kurzorom v poli odkazu), `mdCheckBtn` (sivá = čerstvá, jantárová `is-pending`; read-only katalóg `aria-disabled` s dôvodom, nikdy `disabled`), tooltip
`mdManualTip`. Pole „Odkaz na produkt" má živý zámok podľa poľa Demos URL (`mdProductLockSync`); `mdEditing.rev` echo neomladí. **Formulár „Overiť cenu ručne"**
(NXModal, `busyLock`, bez pamäte, pole `custom` `price`): dodávateľ + odkaz, položka, prepínač **za platňu | za m²**, pole ceny, živý prepočet (`mdManualCalc`),
„Oproti katalógu" (`mdManualDiff`, `mdDecCents` — tým istým pravidlom ako server), poznámka (`mdManualNote`). Stav `{mode, text, touched, src}`: prepnutie bez písania
dá text zvoleného režimu presne zo `price_display`, po písaní ide napísané číslo v jeho režime (`mdManualValue`). Prepočty zrkadlia server (`mdPlateAmount`,
`mdHalfUpText` = `display_m2`, `mdRubyRound2` = `Budget.price_per_plate`; parita `tests/fixtures/ceny_m1b_parity/`); €/m² na 2 desatinné (`mdM2Shown`). S odkazom
sa 25 ms po otvorení volá `mat_manual_open`, potvrdenie čaká na odpoveď (`browserPending`). Odpovede s cudzím tokenom, sekciou alebo dokumentom sa zahodia; `conflict`
otvorí nový formulár. Životný cyklus: `matCloseModals` → `mdManualClose`; `studio.js` volá `mdManualContextChanged`. `MD_CLIENT_SCHEMA = 12`. `mdManualRequest`
pustí sekcie `mat` aj `budget`.

Plné znenie: archív, „materials_dialog.rb".

### materials_appearance_dialog.rb + ui/js/md_appearance.js

**Vzhľad dekorovej skupiny v sekcii Materiály** — jeden vstup pri povrchu skupiny pre dosky aj ABS všetkých hrúbok (aj prázdna štruktúra a skupina len s ABS);
UNI zostáva pracovnou farbou. Okno je **kompaktný overlay pri tlačidle** (kotva mimo prekresľovaného tela sekcie; nie ďalší HtmlDialog): náhľad, katalógová farba
a štyri explicitné akcie. Pomocný text pred priradením obrázka upozorní na vodorovnú kresbu; orientácia obrázka sa nemení.

- Ruby časť patrí `MaterialsDialog` (jeho allowlist/dispatch). **Session** zachytí model, `DocKey`, inštanciu Štúdia, kotvu, fresh scope/baseline a presný zdroj.
  **Prepare iba číta** (nedopĺňa materiál, nenačítava SKM, neotvára operáciu, nemení výber); náhľad živého materiálu môže vzniknúť v súkromnom dočasnom adresári
  a odpoveď nesie obrázok, nikdy klientom určenú cestu. Chýbajúci súbor má pravdivú hlášku.
- **Každé „Priradiť textúru" / „Upraviť v SketchUpe" vytvára nový pracovný materiál** (SKM prenesie pôvodný natívny obsah, príprava a Apply v jednej operácii; starý sa
  neprepisuje). Výmena obrázka na textúrovanom zdroji zachová fyzickú šírku aj výšku. Edit po commite vyberie materiál a otvorí natívny panel Materiály.
- **Uložiť** používa zachytený zdroj (nie `materials.current`): najprv publikuje knižnicu a prejde na nový descriptor, potom samostatné Apply priradí revíziu modelu;
  chyba Apply nemení úspech publikácie (ponúkne opakovanie tej istej revízie). Reset po publikácii color zabudne starý natívny zdroj. Knižničný zápis nie je modelové Späť.
- Plošná farba ide skupinovou cestou `mdColorSave` → `set_decor_color`; voliteľný `appearance_context` pridá overenie vlastníctva a korelovanú odpoveď aj pri
  odmietnutí. Baseline vzhľadu RGB neobsahuje (vlastná zmena farby session neruší).
- **Každá odpoveď nesie token** otvorenia, session, akcie a dokumentu/sekcie/kotvy; klient preverí vlastníctvo pred odomknutím. Busy zamyká akcie, farbu, krížik, scrim
  aj Escape; odchod zo sekcie alebo zmena dokumentu vlastníctvo zneplatní. Overlay je pre `NXEsc` cudzia vrstva a pre Štúdio otvorený modal; fokus sa vracia na
  aktuálny trigger (vlastníctvo patrí logickému cieľu, nie DOM uzlu). Server ruší session pri close/model/Studio/leave.

### Sekcia KOVANIE v Štúdiu (`hw`)

**Čo robí:** katalóg kovania — pohľady **Položky** (strom kategórií) a **Sety** (dlaždice), hľadanie, filter kategórie, prepínač „neaktívne", „Nová položka",
predvoľby setov projektu, overenie cien a otvorenie produktu. **Server:** telo akcií v **`HardwareCatalogDialog`** (odsek `hardware_catalog_dialog.rb`;
`SECTION_ACTIONS` je jediný whitelist, `hw_sink` presmeruje odpoveď, `hw_js` je most pre asynchrónne emity). **JS:** `ui/js/hw_catalog.js` (`hwRenderTools`,
`hwRenderBody`, `hwToolsHtml(state)`, `mdhRenderTree`, `mdhRow`, `mdhDetail`, modal položky), `HWSETS` (sety a ich editor). Vstupy: menu „Katalóg kovania"
a tlačidlo panela → `openStudio('hw')` / `StudioDialog.show(open_section: 'hw')`. Doména: [hardware.md](hardware.md) (`hardware_catalog.rb`, `hardware_sets.rb`).

**Telo a kanál:** telo = jeden uzol zo `<template id="hwBodyTpl">` (iba `#hwList`), modál mazania v `#hwModalRoot`; stav lišty aj v premenných
`HW_VIEW`/`HW_Q`/`HW_CAT`/`HW_INACTIVE`. `ready` posiela `studio.js` z `window.onload` (`window.NX_HW_SECTION` je prihlásenie do režimu sekcie); väzby na uzly lišty
sú **delegácia na `document`**. **Payload `hw_payload(model)`:** `sets` v každom pushi (riadia Nákup), **celý katalóg len pri prvom pushi, po prepnutí dokumentu
a po ručnom „Obnoviť"** (`@hw_full_pending`, gasí sa len keď katalóg naozaj odišiel). Katalógové echo `push_hw_catalog` → `NX.setHwCatalog` nepočíta a nedvíha
generáciu.

**Predvoľby setov projektu** (pohľad Sety) sú **modelový zápis**: po ňom `after_sets_change(model)` → `refresh_if_open(bump: true)` — a to stačí (`Panel.push_selected`
sa nevolá, geometria sa nemení; jantár „Obnoviť" po vlastnom zápise nezožltne). **`merge_seed` NO-OP nevolá `after_sets_change` vôbec.** Po Ctrl+Z sekcia
zostarne jantárom (push-po-undo neexistuje; snapshot predvolieb nemá `revision` guard — posledný vyhráva). Render setov je rozdelený: `HWSETS.setData` (plný push,
kreslí `hwRenderBody`) vs. `HWSETS.init` (echo po odmietnutom zápise `NX.setHwSets`); `hwsRenderSets`/`hwsRenderProj` držia snapshot fokusu (chýbajúci atribút je
súčasť identity `:not([…])`). Testy `tests/pure/test_st3a_hw.rb`, `tests/js/test_st3a_hw.js`, in-SU `run_st3a`.

**Pohľad Položky = strom** (`mdhRenderTree` z poslednej odpovede servera `MDH.tree`): hlavička kategórie `.hwgrphead` (+ `total`/`shown`), `.hwsub` „Výrobca · Rada",
riadky `mdhRow` (inline bunky, `row_rev` guard, `keepFocus`). Klik na hlavičku prepne `HW_EXPAND[key]` a vypýta nový strom; „Načítať ďalšie (N)" zvýši `HW_MORE[leaf]`
o `LEAF_PAGE`. Plochý prijímač `MDH.results` ostáva pre `hw_search`. Filter čistí `MDH.created` aj v premenných.

**Modal položky** (D-15, `hw:item:new`; „Nová položka" aj „Upraviť"): poradie **Démos → kód → názov → cena → MJ → kategória → výrobca → rada → poznámka**.
- Úprava: kód chýba (identita, je v podtitule), **bez pamäte**, posiela `patch` **len so zmenenými poľami** + `from: 'modal'` (inak by zmazal `price_checked_at`),
  `row_rev` skryto v stave; prázdny patch = „Nič sa nezmenilo.".
- **Démos** (`lookup`): náhľad vedie na **serverový proposal** (`pid`); po `MDH.demosPreview` sa modal prekreslí predvyplnený (výrobca len ako návrh z
  `manufacturer_guess`, rada nikdy) — prekreslenie nie je zatvorenie (`HW_REOPEN`). Zmena kódu/názvu/ceny/MJ robí z položky ručnú (`hw_create` namiesto
  `hw_demos_create`). Zmena poľa Démos **zneplatní proposal**; kým nový náhľad nedobehne (`HW_DEMOS_WAIT`, nastavuje spoločný `mdhDemosLoad`), zápis sa nepustí.
  Náhľad má **klientsku generáciu** (stará odpoveď sa zahodí), vymazanie poľa pošle `hw_demos_cancel`. Proposal zaniká len keď ho zápis spotreboval
  (`usedProposal`) alebo po vymazaní poľa — Escape ho nezmaže.
- **„+ Vytvoriť výrobcu/radu…"** (posledná voľba selectu) → pole s tlačidlom **„Vytvoriť"** (`action:` kostry); zápis len tlačidlom alebo Enterom, **nikdy
  `change`/blur**, a položku pritom neuloží. Server odpovie `MDH.taxonomy` s kanonickým menom (token — výsledok zavretého okna nevyberie hodnotu v otvorenom).
  Rada je závislý select (bez výrobcu nie; zmena výrobcu zahodí cudziu radu). **Degradovaná taxonómia** (`write_blocked`) skryje len „+ Vytvoriť…". **Nedostupná
  taxonómia zamyká klasifikáciu** (`hwTaxLocked()` — uložená hodnota ako jediná voľba, payload `manufacturer`/`series` vôbec neobsahuje).
- **Výsledok** `MDH.itemResult(ok, msg, errors, op, token)` — prijme sa len presná zhoda tokenu; `true` zavrie a zahodí koncept, `false` nechá otvorené s chybami pri
  poliach. **Konflikt rebasuje** (`hwItemStale` → prekreslenie z čerstvej položky); **rebase je výhradne táto cesta** — UI prekreslenia (`hwItemRedraw`) držia
  baseline a revíziu z otvorenia, vedomú obnovu robí `hwItemRebase`.
- Editor ukazuje **efektívnu kategóriu** (`hwEffectiveCategory`, mapa `tree_category_of`); cena sa parsuje celá (`hwPriceKey`, neplatná = chyba pri `price`).
- Odchod zo sekcie modal zatvára (`hwCloseModals` — aj modal setu cez `HWSETS.closeModal()`).
- Testy `tests/pure/test_kovb2_katalog.rb`, `tests/js/test_kovb2_katalog.js`, in-SU `run_kovb2`.

**Pohľad Sety = dlaždice** (kompaktný riadok): názov · chipy klasifikácie alebo „nezaradený" · „neaktívny" · Upraviť · Zmazať (dvojklikové potvrdenie). Neaktívny
set sa neponúka ako nový výber (server `set_options`, globálna tabuľka `hwsGlobalOptions`), použitý ostáva. **Editor setu = modal D-15**, ktorý si **pripína
revíziu a základnú definíciu pri otvorení** (`hwsPinRev`; vnútorné prekreslenia ich neomladzujú).
- Polia kontextovo: použitie → otváranie → konštrukcia (len zásuvka) → výrobca → rada (závislá, voliteľná) → názov + Aktívny/Neaktívny + členovia; `generic_type`
  len keď ho server nemá z čoho odvodiť (`USE_TYPE_GENERIC`). Zmena klasifikácie prekreslí modal (`HWS_REOPEN`). **Klasifikácia sa posiela vždy celá**; prechod na
  „— nezaradený —" maže celý klasifikačný blok (`hwsApplyUseType`), `generic_type` ostáva. Auto-návrh názvu len kým ho človek neprepísal.
- **Člen**: „Ako sa určí kód?" (pevný · podľa NL · podľa pásma parametra) a „Koľko?" (`per: unit|owner`), jedno „+ Pridať člena"; prepnutie spôsobu zahodí polia
  druhého (XOR). Zoznam je pole `custom`; `hwsBandRow`/`hwsParamSelect` zdieľa editor výberu setu.
- **Živý náhľad expanzie** (pole `custom` bez `read`): `hws_preview` s generáciou a **tokenom modalu** (cudzí token/stará generácia = zahodiť), debounce ~300 ms,
  nezamyká Uložiť; štruktúrované chyby pri poliach; vzorové parametre len to, čo zadal človek (prázdna NL = server `preview_nl`).
- **Výsledok** `HWSETS.setResult(ok, msg, errors, token, conflict)`; konflikt draft nezahodí a ponúkne „Obnoviť" (pri novom sete len prepne pripnutú revíziu).
  „+ Vytvoriť výrobcu/radu…" tou istou cestou `hw_tax_create_*`; `emit_tax` posiela dva samostatné skripty (`MDH.taxonomy`, `HWSETS.taxonomy`).
- Testy `tests/pure/test_kovb3_nahlad.rb`, `tests/js/test_kovb3_modal.js`, `tests/js/test_st2c_modal.js`, in-SU `run_kovb3`.

**Odkaz na produkt a ručné overenie ceny:** ikona „Otvoriť produkt" pri každej položke aj pri jej riadku v Rozpočte — s URL otvorí externý prehliadač, bez nej
jantár a editor kódu s fokusom na adrese (pôvodný draft, revízia a token; oneskorená odpoveď sa po odchode zo sekcie, zmene dokumentu či inom formulári
neprijme; Demos väzba nezapisuje cenu ani dátum). **`hw-manual-check`** (Katalóg aj Rozpočet) otvorí spoločný NXModal (kód/názov/dodávateľ, cena s DPH za MJ,
predchádzajúce overenie) a po príprave otvorí produkt; potvrdenie čaká na úspešnú odpoveď pokusu o otvorenie; výslovné potvrdenie k dnešku pošle cenu a revíziu,
čas určí server; `busyLock`, odmietnutie odomkne, konflikt obnoví záznam bez opätovného odoslania.

Plné znenie: archív, odsek okna Štúdio (pasáže ŠT-3a, KOV-B2, KOV-B3, CENY-KOV) a „hardware_catalog_dialog.rb".

### hardware_catalog_dialog.rb

**Serverová autorita katalógu kovania pre sekciu `hw` Štúdia** (vlastné okno už nemá — sekcia „História"; modul sa nepremenúva). Vstup: uzavretý whitelist
**`SECTION_ACTIONS`** + `dispatch(name, payload, sink)` + `with_client(sink)` (`ensure` povinné); **`ready` vo whiteliste zámerne nie je** (prepísal by callback Štúdia —
prvotný stav nesie `push_state` pod kľúčom `hw`). `js` bez sinku padá na `studio_js`; `hw_js` je verejný most pre asynchrónne emity. Doména: [hardware.md](hardware.md).

- **Asynchrónne behy** (cena z Demosu, náhľad produktu) si adresáta pamätajú (`run_target` = **session token** `@section_session` zachytený pri štarte behu) — token
  zhasína zatvorenie Štúdia (`on_ui_closed`), prepnutie dokumentu (`on_model_changed` zo `scale_observer` — vetva ostáva, lebo musí zneplatniť bežiaci beh) a odchod zo
  sekcie (`cancel_runs_on_leave` z `hw_leave`, so statusom). Príznak bežiaceho behu nesie **identitu behu** (`mark_running` vydá `run_id`, `clear_running(target, id)`
  zhasne len pri zhode); výslovné `hw_demos_cancel` gasí bez identity. Generačné počítadlá `@gen` (cena) a `@demos_gen` (náhľad).
- **Refresh:** `after_sets_change` → `StudioDialog.refresh_if_open(bump: !model.nil?)` (knižničný zápis bez zdvihu, modelový zápis predvolieb so zdvihom);
  `push_items(refresh_studio: true)` = echo sekcie + plný push Štúdia `bump: false` (ceny vstupujú do Rozpočtu) + `Panel.push_hardware_sets`; jediný volajúci
  s `refresh_studio: false` je `price_refresh_after_proc`. `sets_payload(model)` berie model argumentom.
- **Odmietnutý zápis setov** (`:conflict`, `:not_found`, neznáme zlyhanie; aj odmietnutý `reset_project`) ide na **`resync_sets`** (`StudioDialog.push_hw_sets` →
  `NX.setHwSets`, jeden `sets_payload`, bez zdvihu generácie a bez plného pushu); úspešný zápis setov ide plným `push_state` (mení aj nákup).
- **Undo kontrakt modelových zápisov predvolieb projektu** (`hws_map_project`, `hws_merge_seed`, `hws_reset_project`): jedna cesta zatvorenia operácie
  `abort_open_operation` — handler drží `op[:open]` a `rescue` ruší výhradne operáciu, ktorú otvoril a nezavrel.
- **Mapovanie podľa triedy v predvoľbách projektu:** `sets_payload` nesie `class_rows = { project: [...], global: [...] }` — hotové riadky pre všetky
  `HardwareSets::CLASS_MAPPING_KEYS` (popisok, `options` z `class_set_options`, `current`, `stored` + `value_text`, `unset_label`/`none_label`/`none_value`/`none_send`).
  JS ich kreslí do tabuľky `.hwsmap` za generické typy. **Dve prázdne voľby:** `''` = „nenastavené" (kľúč sa zmaže; pri závese sa dedí legacy `hinge`) a sentinel
  `none_value` = „vedome bez setu" (pri zásuvke RED `drawer_kit_missing`); vybranú rozhoduje `hwsMapClassSelectedId`. Zápis existujúcimi `handle_map_project`/
  `handle_map_global` s poľom **`mapping_key`** (typ cez `HardwareSets.mapping_key_type`, validácia `class_key_value_problem`). Editor pásiem pre triedne riadky nie je.

Plné znenie: archív, „hardware_catalog_dialog.rb".

### Sekcia SPOTREBIČE v Štúdiu (`appl`)

**Čo robí:** dva pohľady — **Katalóg** modelov spotrebičov **tohto počítača** (`%APPDATA%`, tretí per-PC katalóg vedľa materiálov a kovania; bez cien) a **V zákazke**
(čo je v tejto zákazke a kde). **Server:** `ApplianceDialog` (odsek `appliance_dialog.rb`); doména [appliances.md](appliances.md). **JS:** `ui/js/appliances.js`
(prefix `ap*` / `AP_*`) — načítava sa **až za** `studio.js` (obaľuje `NX.setStudio` a dopĺňa `window.NX` o `applTree`/`applCard`/`applResult`; poradie stráži guard
test). Ikona `appliance`.

- **Badge navigácie** = `appl.job.counts` zo servera — počet **riadkov** pohľadu „V zákazke", ktoré treba vybaviť (nevybraný model · zaniknutý vlastník · nález
  Kontroly); `navCounts('appl')` len číta hotový blok.
- **Lišty:** Katalóg `[V zákazke · Katalóg]` · „Nový spotrebič" · hľadanie (debounce 200 ms) · „vyradené" · `sechint`; V zákazke: segment · „Pridať do zákazky" ·
  hľadanie · kategória · súhrn zo servera. Hľadania sú čisto klientske (lišta sa počas písania neprekresľuje). **Žiadne „Obnoviť"** a žiadny `staleFlag`.

**Pohľad „V zákazke":** tabuľka Kategória · Model · Vlastník · Kontrola · Cena z Rozpočtu · akcie. Riadky, **poradie**, tóny, texty aj ceny skladá server
(`ApplianceDialog.job_view`) z hotových výsledkov toho istého pushu: `Bom.collect[:appliances]` (stavy `bound|job|owner_missing|expected_missing`), payload Rozpočtu
(ceny, „dodáva zákazník", `appliance_owners`) a Kontroly (kategória `appliance`); vlastné čítanie len položiek zákazky (`BudgetStore.appliances`). Žiadny druhý sken.
Poradie: skrinky → dosky → sloty → „len zákazka". „Nevybraný" má akciu „vybrať…", „vlastník zmizol" „Odpojiť"; kategórie bez kontroly majú stav `evidencia`.
- **Zápisy idú kanálom Rozpočtu** (`budget_mutate` → `ProductionCore.apply_budget_op` → `ApplianceBinding.apply!`): sekcia vlastnú zápisovú cestu nemá — „Pridať do
  zákazky", editor, „Odpojiť" a „Zmazať" volajú funkcie `budget.js`. **Jeden modal, dve vstupné miesta:** „Pridať do zákazky" aj „Do zákazky" v karte katalógu
  otvárajú D-15 modal Rozpočtu (`budOpenDraft('appliance', …)`, z karty predvyplnený `catalog_id`); vyradený záznam tlačidlo nemá. Ceruzka = editor položky
  Rozpočtu (`budOpenApplEdit` → `budOpenMore(..., full: true)`). Odkaz a technický list otvára server (`appl_open_url`), v okne nie je `href`.
- **Oko** = `appl_job_select` (čisté čítanie, označí vlastníka a doramuje) s **guardom zastaraného pohľadu**: klient posiela identitu payloadu tabuľky
  (`model_guid` + `gen` z `AP_JOB_DOC`), server odmieta nezhodu (`DocKey.foreign?` + `StudioDialog.generation`); prázdny údaj sa netoleruje.
- Po zápise príde bežný `push_state` s Rozpočtom aj `appl.job`. **`job` chodí len plným pushom** (klient `if (p.job) AP_JOB = p.job`). Tvar `job`: `rows[]`
  (`{state, item_id, category, category_label, model, model_sub, owner{kind,id,pid}, owner_label, owner_desc, tone, status_text, status_title, price_text,
  customer_supplied, shop_url, sheet_url, actions{select,edit,remove,unbind,assign,shop,sheet}}`) · `total` · `warn` · `counts{red,orange,total}` · `summary` ·
  `subtotal_text` · `subtotal_included` · `categories`. **`shop_url` je z položky zákazky** (snapshot katalógu až fallback), `sheet_url` zo snapshotu.
  **`actions.assign` len keď je vlastník v serverovej ponuke vlastníkov** (inak dôvod v `model_sub`).
- **Deep-link z Kontroly:** nález s `data.route = 'appl'` (`ProductionCore::ROUTE_SECTIONS`); kotva `appliance:<uuid>` prepne na „V zákazke" a riadok prisvieti —
  spotrebuje sa raz a aplikuje **až po `render()`**; zaniknutý riadok okno prizná.

**Katalóg:** strom po kategóriách (zbalenie = stav okna) a karta z blokov Telo · Nika · Čelo/dvere · Montáž — **len tých, ktoré kategória má** — plus Odkazy, Prílohy,
Poznámka; prázdny blok s priznanou vetou. Prílohy = dlaždice (miniatúra z lazy kanála, PDF ikona, náhľad s teal rámom; akcie pri hoveri aj `:focus-within`).
- **Refresh:** zmena katalógu = **echo sekcie** (`NX.applTree` + `NX.applCard`), nikdy `push_state` a bez zdvihu generácie; echo **kreslí len pri aktívnej sekcii**
  (`studioActiveSection() === 'appl'` — `#secbody`/`#sectools` sú zdieľané), inak sa stav len uloží.
- **Kto čo vlastní:** server obsah, poradie, počty, texty, polia formulára; klient pohľad (vybraný záznam, hľadanie, „vyradené", zbalené skupiny, cache miniatúr) —
  pamäť okna, nový dokument ju nezhadzuje.
- **Modal Nový/Upraviť** = kostra D-15 (`appl:create` / `appl:edit:<id>`, `wide`); zápis modal nezatvára, zatvorí `NX.applResult(true, …)` s tokenom. Kategória sa
  pri úprave meniť nedá; pri novom zázname zmena `nxm_category` prekreslí modal s prenesenými hodnotami (`skipMemory: true`, `baseFields`). **Mazanie** = D-15 danger
  modal (nikdy `UI.messagebox`), tombstone vrátiteľný „Obnoviť"; bez kostry sa nevyradí nič (fail closed).
- **Stav katalógu** (`:read_only` / `:degraded`) = banner nad stromom a vypnuté zápisy; príznak `writable` chodí v každom payloade sekcie.

Testy: `tests/pure/test_s1a2_sekcia.rb`, `tests/pure/test_s1b2_pohlad.rb`, `tests/js/test_s1a2_sekcia.js`, `tests/js/test_s1b2_pohlad.js`, in-SU `run_s1a2`
a `run_s1b2`. Plné znenie: archív, „Sekcia SPOTREBIČE v Štúdiu".

### appliance_dialog.rb

**Serverová autorita sekcie `appl` — modul bez okna** (žiadny `DLG_KEY`, HtmlDialog ani položka menu). Vstup: uzavretý whitelist `SECTION_ACTIONS` (`appl_tree` ·
`appl_card` · `appl_create` · `appl_patch` · `appl_delete` · `appl_restore` · `appl_attach` · `appl_thumbnail` · `appl_remove_attachment` · `appl_open_url` ·
`appl_open_attachment` · `appl_leave`, a `appl_job_select`) + `dispatch(name, payload, sink)` + `with_client(sink)` s povinným `ensure`; **`ready` vo whiteliste nie je**.
Je **jediným vstupom do `ApplianceCatalog`** a pravidlá katalógu neduplikuje (validácia, `rev` guard, prílohy, seed: [appliances.md](appliances.md)) — žije tu len UI:
zloženie stromu a karty, texty polí, preklad statusov, chyby pri poli. Pohľad „V zákazke" skladá `job_view` (odsek sekcie).

- **`tree_payload`** skladá celé zoskupenie aj poradie (kategórie v poradí `CATEGORIES`, `ApplianceCatalog.sort_records`, `total`, skupina **Vyradené** len pri
  `include_deleted`), podtitul `summary_line` a `title`. `gen` dotazu klienta server len echuje.
- **`card_payload`** nesie bloky (`body` · `niche` · `front` · `install`) **len neprázdne podľa `ROWS`** s riadkami `{label, value, unit, derived}` (`value: null` = list
  to nekótuje → „—"), odkazy, prílohy a `fields`. **`ROWS[kategória][blok]` je jediný zoznam polí** — z neho karta aj formulár (`form_fields` + `FIELD_LABELS`); doska
  a drez majú `body` aj `niche` prázdne (hodnoty v zázname ostávajú, len sa nekreslia).
- **Kľúč poľa modalu = cesta chyby katalógu** (`dims.niche.width_min`) — `NXModal.showErrors` posadí hlášku bez prekladovej tabuľky. Formulár pre všetky kategórie
  (`form_payload`) chodí len na vyžiadanie (`appl_tree` s `form: true`).
- **Formulár dostáva bezstratovú hodnotu, karta zaokrúhlenú** (`fmt_input` vs `fmt_mm`); `appl_patch` nesie len polia zmenené oproti baseline (`apChangedFields`),
  prázdny patch sa neodošle.
- **`NX.applResult(ok, msg, errors, op, token, info)`** — pri `:conflict` nesie `info` čerstvú `rev`; výnimka v tokenizovanej akcii (`TOKEN_ACTIONS` = `appl_create` ·
  `appl_patch`) posiela `applResult` tiež (inak by modal ostal zamknutý). Zámok obnovuje aj echo karty.
- **Lazy miniatúry:** `data:` URI len pre prílohy `image`/`thumbnail`, len na vyžiadanie (`thumbs: true`) a len chýbajúce (`have`), najviac `THUMB_BATCH` (6). Primárne
  `Sketchup::ImageRep` (zmenšenie na `THUMB_MAX_PX` 96 px cez dočasné PNG), inak pôvodný súbor pod `THUMB_MAX_BYTES` (256 kB) so správnymi magic bytes, inak `null`
  (platná odpoveď, klient ju cachuje). Cache podľa nemenného id prílohy; klient sa pýta po každom vykreslení tela.
- **`appl_open_url` overuje schému na serveri** (`URI::HTTP` + host); v karte nie je `href`. **`appl_attach`** volá `UI.openpanel` priamo v callbacku (filter PDF
  a obrázkov, jeden súbor; `nil` = „Nič sa nepriložilo."); druh z prípony (`pdf` → `sheet`, inak `image`).
- **Stav pohľadu drží server v tvare od klienta** (`@view_query`, `@view_deleted`, `@view_gen`); `appl_leave` aj `on_ui_closed` ho zabudnú. Klient preberá najvyššiu
  videnú generáciu (`AP_GEN = max(AP_GEN, gen)`).

Plné znenie: archív, „appliance_dialog.rb".

### Sekcia PRAVIDLÁ v Štúdiu (`rules`)

**Čo robí:** editor pravidiel kovania projektu („Kovanie podľa rozmerov", Š17) + read-only bloky ABS pravidiel podľa roly a ručných zásahov. Akcie v lište
(`rulesToolsHtml`, čistá funkcia): **Uložiť a prestavať skrinky · „aj ako globálnu predvoľbu" · Načítať globálne · Doplniť nové predvolené**. **Server:**
`RulesDialog` (odsek `rules_dialog.rb`), payload `rules_payload(model, collected)` — model aj hotový zber argumentom, žiadny druhý sken; **chodí celý pri každom
pushi** (malý JSON, bez západky). **JS:** `ui/js/rules.js` (`rdApplyState`, `rdRender`, `rdRenderExtra`, `rdCollectRules`, `rdGuardHtml`). Doména:
[hardware.md](hardware.md) (`hardware_rules.rb`).

- Telo = jeden uzol zo `<template id="rulesBodyTpl">`. **Formulár prežije push:** `rdApplyState` porovnáva odtlačok `RD_SEED` a prekresľuje len keď sa pravidlá
  **na modeli** zmenili (uloženie, Späť, prepnutie dokumentu, odmietnutie); inak nasadí len meta riadok. „Načítať globálne" odtlačok **neobnovuje** (zmena formulára,
  ktorá ešte neplatí).
- **Pin revízie GLOBÁLU `RD_GLOBAL_REV` (H10a/R-35)** — verzia globálnych predvolieb, ktorú okno naozaj VIDELO; žije mimo `RD_META` a mimo projektovej obnovy
  formulára. **Posunie sa LEN:** (a) pri prvom naplnení sekcie (`null` → `global_rev` z payloadu, aj `''`, keď sa globál nedal prečítať), (b) pri naplnení, ktoré
  zobrazuje globál (`source: 'global'`, `rdSetState` — aj vynútené echo), (c) na pokyn servera `RD.setGlobalRev(rev)` (Načítať globálne, obnova po H-PRE/H-INH/H-UNK/
  H-RACE, vlastné úspešné uloženie globálu; prázdna revízia sa ignoruje). **Neposunie sa** pri projektovom `rdSetState` (uloženie len do projektu, Späť/Znova, prepnutie
  dokumentu, Doplniť nové predvolené), pri pokojnom pushi (`rdApplyState` s nezmenenými pravidlami) ani pri `RD.setRules` — inak by okno potvrdilo cudzí globál, ktorý
  nevidelo, a ďalšie „aj ako globálnu" by ho bez konfliktu prepísalo (audit BLOCKER 1). `rdSaveRules` posiela kľúč `global_rev` **vždy** (`''` pred prvým naplnením;
  chýbajúci kľúč = pre server starý DOM, H-OLD). Getter pre Node testy `rdGlobalRev()`. Pri konflikte globálu server **neposiela echo** — rozpísané hodnoty ostanú vo
  formulári; hlášky (`RulesDialog::GLOBAL_*_TEXT`) a tabuľka predkontroly: [hardware.md](hardware.md) (`hardware_rules.rb`, odsek H10a).
- **Read-only bloky** (`abs` = ABS podľa roly, `overrides` = jantárové riadky ručných zásahov) majú vlastné uzly a `rdRenderExtra` pri **každom** pushi, mimo
  `rdRender`/`RD_SEED`; poradie skupín ABS nad kovaním.
- **Uloženie** = modelový zápis (`HardwareRules.set_project_rules` v `CabinetBuilder.rebuild_many`, jedna undo operácia), potom `Panel.push_selected` →
  `refresh_if_open(bump: true)`; zápisové akcie majú guard generácie `StudioDialog.generation`.
- Riadok pravidla `vysuvy-nl-podla-hlbky` má titulok **„Výsuv — staré zákazky bez systému zásuvky"** (`rdRuleTitle`) a hint; `rdLabel` je spoločný slovník typov so
  serverovou `HardwareRules.label_for` (guard test). Pravidlo sa nemaže.
- **Editor door guardov** pravidla `bands` (`rdGuardHtml`, zbalený `<details>` so súhrnom `rdGuardSummary`, otvorenosť `RD_GUARD_OPEN` podľa `rule_id`): `width_plus
  {over, add}` · `width_warn_over` · `weight_bands [{max, quantity}]` · `finite`; kreslí sa pri `kind: 'bands'` s výstupom `hinge` a pri každom `bands`, ktoré guard
  už nesie. `RD_GUARD_KEYS` = zrkadlo `HardwareRules::DOOR_GUARD_KEYS` (guard test). Pomocná veta bloku („Platí pre dvierka…", `RD_GUARD_HELP`) je „?"
  (`.studio .nxtip`) v `<summary>` za súhrnom; klik naň blok nezbalí.
- **Tvar zo snapshotu nesmie zhodiť sekciu:** `weight_bands`, `bands` aj `series` prechádzajú bránou `rdArr`; zlý tvar = prázdna tabuľka s jantárovým hintom (`.rgbad`)
  a v lište „neplatný tvar" (`rdWeightBroken`); opraví ho uloženie. Pri zbalení bloku `rdGuardToggle` → `rdGuardRefresh` prevezme formulár zberom `rdSyncFromForm`
  a prepíše len text `.rgsum` (bez `rdRender`).
- **Zber `rdCollectGuards` neposiela tvar, ktorý by server ticho zahodil:** nevyplnený kľúč sa nezapíše (prázdna šírka = guard preč, chýbajúci počet = 1,
  odškrtnuté `finite` = kľúč preč); vedome pridané hmotnostné pásmo s prázdnymi kg ide ako `null` a uloženie sa odmietne (`rdValidate` → `rdWeightProblem`, server
  `HardwareRules.weight_bands_problem`). `rdCollectRules` pracuje na **kópii celého pravidla** — neznáme kľúče (aj `floor_height_min`) prežijú.
- Pásma korpusového pravidla na šírku majú hint **„Pásma podľa šírky korpusu."** (`rdWidthHint`, len `bands` + `input: 'width'` + rola `cabinet`); `rdRoleDesc`
  pozná prah `applies_to.floor_height_min`. Editor prahu neexistuje.

Testy: `tests/pure/test_st3b_rules.rb`, `tests/js/test_st3b_rules.js`, `tests/pure/test_kovf2_editor_zavesy.rb`, `tests/js/test_kovf2_editor_zavesy.js`,
`tests/js/test_kovg1b_editor_nohy.js`, `tests/pure/test_h10a_globalne_pravidla.rb`, `tests/js/test_h10a_pin.js`, in-SU `run_st3b` a `run_h10a`. Plné znenie: archív, odsek okna Štúdio (pasáže ŠT-3b, D-118b, KOV-F2, KOV-G1b) a „rules_dialog.rb".

### rules_dialog.rb

**Serverová autorita sekcie `rules` Štúdia** (vlastné okno už nemá — sekcia „História"); `js` bez sinku padá na `studio_js`. Vstupy: menu „Pravidlá kovania" →
`StudioDialog.show(open_section: 'rules')`, tlačidlo panela → `openStudio('rules')`. Modul nemá asynchrónny beh, preto nemá ani vetvu `on_model_changed`
v `scale_observer` (sekciu obslúži plný push Štúdia; `rules_payload` dostane podaný model). Doména: [hardware.md](hardware.md) (`hardware_rules.rb`).

- **Rozsah hromadného zápisu = zákazka:** `handle_save` aj „Doplniť nové predvoľby" (`handle_merge_seed`) berú skrinky zo `Panel.job_cabinets_split` (top-level cez
  `Ids.top_level_scan`), nie z `cabinets(model)` (ten by našiel aj korpus vnorený v cudzom komponente). Skrinka s **odpojeným dielcom** sa do `rebuild_many`
  nedostane, ale **snapshot pravidiel sa zapíše aj tak** (`rebuild_many` otvára operáciu aj s prázdnym zoznamom); status ju vymenuje
  (`Panel.detached_skipped_tail`, `Ids::DETACHED_PART_REASON`). Päta sekcie hlási „skriniek zákazky" (`Panel.job_cabinets`); `cabinets(model)` ostáva len na čítanie.
- **`RulesDialog.after_model_write`** (za operáciou prestavby) zneplatní aj memo nôh ghost pásika.
- **Globálna revízia (H10a/R-35):** `rules_payload` nesie `global_rev` a `@baseline_source`; `handle_save` = `baseline_state` → identita → odtlačok projektu →
  `rules_problems` → **`global_precheck`** (pri „aj ako globálnu" alebo projekte, ktorý preberá globál; konflikt = nič sa nezapíše, žiadna operácia, žiadne echo,
  `RD.setGlobalRev`) → prestavba → globál cez `HardwareRules.save_library!` vyhodnotený `case`-om (H-RACE). `push_global` pošle `RD.setRules` + `RD.setGlobalRev`
  v jednom skripte (`global_rev_script`, guard na starý DOM). Okno nevolá `HardwareRules.write(` (guard test). Detail: [hardware.md](hardware.md).
- **Veta rozsahu pravidla viazaného na typ skrinky (H12b, R2.6):** `rules_payload` nesie kľúč **`type_scope`** = **pole po riadkoch `rules`** (veta | `nil`,
  `type_scope_list`; H12c, predrecenzia P3 — nie mapa podľa `rule_id`, ktoré môže byť duplicitné alebo chýbať) — „na hornú skrinku" / „na spodnú skrinku",
  keď filter `applies_to.cabinet_type` pravidla s rolou `cabinet` obsahuje **práve jeden** z typov `TYPE_SCOPE_PHRASES` (doslovne pôvodný `rdRoleDesc`; inak
  `nil` a klient pokračuje ďalšími filtrami). Vety sú akuzatív so slovom „spodnú" (terminológia F3), preto nie sú v registri typov. `push_global` (Načítať
  globálne) pošle v tom istom skripte to isté pole nad **globálnymi** pravidlami v poradí `RD.setRules` (`type_scope_script` → `RD.setTypeScope`, guard pre DOM
  bez prijímača). **Klient (H12c):** riadok `i` dostane vetu z pozície `i` (`rdRuleDesc(i)` = `rdRoleDesc(r, rdScopeAt(i))`), sám typ neprekladá; poradie
  riadkov formulár drží (`rdCollectRules` ide po `.rrule` v poradí vykreslenia). Pole `RD_TYPE_SCOPE` nasadí **len naplnenie formulára** (`rdSetState` —
  `RD.init`, `setSection(force)`, zmena pravidiel na modeli) a `RD.setTypeScope` (prepíše len popisy riadkov `.rid`, rozpísané hodnoty ostanú); lacné echo nad
  tými istými pravidlami (`rdSetExtra`) ho **neprepíše** — formulár môže práve ukazovať načítaný globál.
- **`ui/js/rules.js`** je prefixovaný `rd*`/`RD_*` (globály `el`/`esc` by kolidovali so `studio.js`); prijímače `RD.init`/`RD.setRules`/`RD.setStatus` si mená ponechali.

Plné znenie: archív, „rules_dialog.rb".

### Sekcia ŠABLÓNY v Štúdiu (`tpl`)

**Čo robí:** správa knižnice šablón (Š18) — dlaždice korpusových aj doskových šablón s náhľadom, súhrnom kovania, konštrukcie a očakávaných spotrebičov; akcie
**Použiť** (na označenú skrinku), **Odfotiť/Prefotiť** náhľad, **Premenovať** a **Zmazať** (D-15 danger modal). Doskové šablóny sa dajú len premenovať a zmazať
(apply/odfotiť sa im nezobrazujú). **Ukladanie novej šablóny je len v Inspectore** (mini-modal „Uložiť ako šablónu"). Tlačidlá sú vždy aktívne a verdikt (nič
neoznačené, iný typ, viac označených) dáva server pri kliku. **Server:** `TemplatesDialog` (odsek `templates_dialog.rb`; `SECTION_ACTIONS = tpl_apply · tpl_delete ·
tpl_capture · tpl_rename · tpl_preview`). **JS:** `ui/js/templates.js` (`TPL.init`). **Kontrakt knižnice, premenovania, náhľadov a kanálov** (vrátane stavového echa
`TPL.init`, ktoré kreslí len pri `studioActiveSection() === 'tpl'`, vlastného PNG kanála a refreshu `apply` = plný push `bump: true` vs. zmena knižnice = echo
`push_library_echo` bez zdvihu): [model-a-identita.md](model-a-identita.md), odseky `templates.rb` a `template_previews.rb`.

- Dlaždica nesie odvodené kľúče zo servera (`tile_row`): `{name, preview_rev, config, hardware, appliance_expects, construction, vent_note}` + pri korpusovej
  šablóne **`type_word`** (slovo typu zo servera, H12b; doska kľúč nemá; `templates.js` ho od H12c zobrazí cez `tplTypeWord` — vlastnú mapu slov nemá) — poradie stráži `test_st3c_tpl.rb`; `TILE_CONFIG_KEYS` je orezaný (typ a tri rozmery). `templates.js` kreslí pri názve ikonu `wrench` s `aria-label` a súhrnom v `title` (aj
  upozornenie na neprenosné zámky), riadok konštrukcie `.stplmeta.stplkon` len pri neprázdnom súhrne a vetu o vetraní do `title`. Nič z toho sa do
  `templates.json` nezapisuje. Popisky kategórií spotrebičov skladá server.
- Vstupy: menu „Šablóny" → `StudioDialog.show(open_section: 'tpl')`, správa šablón vo vkladacej karte → `openStudio('tpl')`.

Testy: `tests/pure/test_st3c_tpl.rb` (+ sady v [model-a-identita.md](model-a-identita.md)).

### templates_dialog.rb

**Serverová autorita sekcie `tpl` Štúdia** (vlastné okno už nemá — sekcia „História"; modul sa nepremenúva). `find`/`upsert`/`delete`/`set_preview` majú vlastný `kind`
guard (`KINDS = cabinet | board`); apply a odfotenie len pre `cabinet`.
- **`handle_apply` odmietne šablónu z novšej verzie:** kontroluje sa **RAW config uloženého záznamu** (`CabinetBuilder.newer_config?`) pred merge aj `rebuild_many`;
  hláška z jediného zdroja `CabinetBuilder.newer_config_message`. Tú istú kontrolu má vklad zo šablóny (`Panel.newer_template_refusal`) a „Vložiť kópiu" / „Uložiť ako
  šablónu". Detail: [construction.md](construction.md), odsek `cabinet_builder.rb`.
- **Typový guard použitia šablóny (H12b, audit H12 A2):** čistá `template_type_refusal(cab_cfg, tpl_cfg)` porovnáva **identitu** (`template_type_id`: chýbajúci
  typ = `CabinetTypes::FALLBACK`, `''` aj neznámy typ ostávajú surové — šablóna s `type: ''` sa na dolnú nepoužije a naopak, ako vždy); slovo typu vo vete je
  oddelená **normalizácia** (`CabinetTypes.prop … :word`, neznámy aj prázdny = „dolná"). **Nie** `id_or_default` (to by `''` zlialo s dolnou). Obojsmerná
  matica: `test_h12b_panel.rb` + golden `panel.json`.
- **Šablóna na rohovú skrinku:** `corner_template_apply_refusal(cab_cfg, tpl_cfg)` (čistá, `CabinetTypes.corner?` oboch) odmietne šablónu inej strany aj šablónu
  s porušeným invariantom čiel; `merge_template` — chýbajúci kľúč rohovej v šablóne = zachovaj hodnotu cieľa.
- **`tile_row`** skladá odvodené kľúče dlaždice z tých istých funkcií ako Inspector (`TemplateStore.hardware_tile_summary`, `construction_summary` z účinných hodnôt,
  `ventilation_note`, slovo typu `Panel.template_type_word` — H12b); celé definície setov do Štúdia nechodia.
- Odfotenie: `tpl_capture` → `TemplatesDialog.handle_capture` → `Panel.capture_preview_for(kind, name)` (z práve jednej označenej skrinky, dáta šablóny sa nemenia).

Plné znenie: archív, „templates_dialog.rb".

### Sekcia DODÁVATEĽ / DEMOS v Štúdiu (`sup`)

**Čo robí:** ukazuje **stav väzby na dodávateľa Demos** a vedie tam, kde väzba naozaj žije (deep-linky `studioGoSection` do Materiálov a Rozpočtu). **Vedome nemá
ani jedno editovateľné pole** — väzba nastavenia nemá (verejný cenník bez prihlásenia, cenového pásma a DPH — firma je neplatca, katalógové ceny sú konečné), odstup
dotazov je konštanta `DemosClient::CRAWL_DELAY_S` a väzba je vlastnosť konkrétneho dekoru či kovania (vedomá odchýlka od wireframu mockupu). **Server:**
`SupplierSettingsDialog` (odsek `supplier_settings_dialog.rb`) — jeden payload pre sekcie `sup` · `bset` · `about`. **JS:** `ui/js/studio_settings.js`.

### Sekcia NASTAVENIA ROZPOČTU v Štúdiu (`bset`)

**Čo robí:** globálne nastavenia aktívneho dodávateľa (`%APPDATA%\NOXUN\Engine\supplier_settings.json`) — sadzby služieb, režimové hodnoty €/€€/€€€, štandardné
koncové riadky, prah veku cien, krok zaokrúhlenia, **prerez píly, orez okraja platne a prídavok dupláku** (parametre nárezového plánu a Kontroly). Do zákazky sa
**nemrazia**. Vstupy: položka navigácie, tlačidlo „Nastavenia" s ikonou posuvníkov (`sliders-horizontal`) v lište Rozpočtu (čisté `studioGoSection('bset')`), chip nárezového plánu, nález Kontroly `layout_settings`, menu „Nastavenia
rozpočtu" → `StudioDialog.show(open_section: 'bset')`. **Server:** `SupplierSettingsDialog` (`ss_save`, `ss_reload`); validácia serverová
(`SupplierSettings.patch_active!`, all-or-nothing). **JS:** `ui/js/studio_settings.js` (`ssRenderBody`, `ssApplyState`, `ssModeCells`, `ssModeHeads`, `ssFieldBad`,
`ssRangeError`).

- **Skalárne polia** (`SS_SCALARS` = `[kľúč, popis, jednotka, tooltip?]`, zhodu kľúčov so `SCALAR_DEFAULTS` stráži Ruby guard) majú `inputmode="decimal"` a tooltip
  `.nxtip.inl` (`data-tip`; `.studio .nxtip` v `studio.html`, `white-space: pre-line`). **Klientska kontrola rozsahu** z `scalar_ranges` (`SupplierSettings::SCALAR_RANGES`
  + dni): pole mimo rozsahu zčervená (`.bad`), „Uložiť" povie dôvod; autoritou je server.
- **Stav súboru** `settings_state` (`ok | degraded | newer | fallback | unreadable` + veta) = banner hneď po otvorení; pri `SS_WRITE_BLOCK_STATES` (`newer`/`degraded`/
  `unreadable`) červený `hwbanner-stop` „Uloženie je vypnuté." a „Uložiť" `aria-disabled` s dôvodom (tlmený vzhľad bez hoveru); `fallback` jantárový bez vypnutia
  zápisu.
- **Prázdna bunka režimu ukazuje platnú sadzbu:** payload nesie `effective` (`{rates, rows}` = presne `SupplierSettings.rate` / `row_rate`); `ssModeCells` dá prázdnej
  bunke `placeholder` a tooltip „Prázdne — platí základ (17)", hodnota ostáva `''`. Hlavičky `ssModeHeads` v poradí `SS_STATE.modes` („Položka · Základ · € nízky ·
  €€ štandard · €€€ vysoký").
- Kontrakt revízie, pinu a prepočtu: odsek `supplier_settings_dialog.rb`. Testy `tests/js/test_np2_nastavenia.js`.

### supplier_settings_dialog.rb

**Serverová autorita troch sekcií Štúdia — `sup`, `bset` a `about`** (vlastné okno už nemá — sekcia „História"; modul sa nepremenúva). Uzavretý whitelist
**`SECTION_ACTIONS = ss_save · ss_reload · updater_check · updater_set_dir · updater_apply`** (prefixované mená — `save`/`reload`/`ready` by kolidovali s callbackmi
okna). **Jeden payload nesie všetky tri sekcie** (globálne, model nepotrebujú); `settings: nil` je signál chyby (nie „nič nové").

- **Optimistický zámok:** payload nesie `revision` aktívneho dodávateľa, uloženie ju vracia, nezhoda = odmietnutie + načítanie nanovo. **Klient posiela revíziu
  pripnutú na stav, nad ktorým sa začalo písať** (`SS_BASE_REV`): pin sa berie **pri fokuse poľa** (`focusin` — fokus zmrazí zobrazený obsah), push ho neprepisuje;
  uvoľní ho `SS.saved()` (potvrdenie, odmietnutie, reload) a **prekreslenie tela z čerstvého stavu, keď pin nikto nevyužil**. Miesto uvoľnenia je jediné — v
  `ssRenderBody` tesne pred `box.innerHTML = ''`, za strážou `ssTyping()`, s podmienkou `!ssDirty()` (prekreslenie nastáva aj bez pushu — odchod a návrat do sekcie).
- **Klient:** rozpísané hodnoty prežijú plný push a zanikajú výhradne na `SS.saved()`; telo sa neprekresľuje, kým používateľ píše; kreslí sa len do práve otvorenej
  sekcie (`#secbody`/`#sectools` sú zdieľané); `settings: nil` = chybový stav (formulár skrytý, uložiť sa nedá, „Obnoviť" ostáva). Rozlišuje sa prítomnosť kľúča.
- **Odmietnutie rozpísané hodnoty zahadzuje** (`SS.saved()` pred `refresh_studio`); baseline sa obnovuje až pri úspešnom zostavení payloadu.
- **Po úspešnom zápise sa Štúdio prepočíta so zdvihom generácie** (sadzby sú vstup rozpočtu). **Hláška sa vetví podľa výsledku prepočtu** (`refresh_and_report`):
  `refresh_studio` vracia boolean „klient to naozaj dostal" — pri `false` červená veta „Nastavenia sú ULOŽENÉ, ale rozpočet sa NEPREPOČÍTAL… klikni na Obnoviť";
  rovnako odmietacia vetva aj `handle_reload`.
- Tri akcie `updater_*` patria sekcii `about` (odsek `updater.rb`, UI vrstva).

Plné znenie: archív, „supplier_settings_dialog.rb".

### Sekcia O PLUGINE v Štúdiu (`about`)

**Čo robí:** logo, verzia a priečinok nastavení + **aktualizácia pluginu jedným klikom** (cesta k distribučnému priečinku, kontrola verzie, „Aktualizovať"). **Server:**
`SupplierSettingsDialog` (`updater_check`, `updater_set_dir`, `updater_apply`) nad jadrom `updater.rb`. **JS:** `ui/js/about.js` (markup), `ui/js/studio_settings.js`
(stav a akcie), hooky v `studio.js`. Kontrakt UI vrstvy updatera: odsek `updater.rb` nižšie.

### ui/js/about.js — „O plugine"

**Jeden obsah, dva vstupy** (kontrakt Š19): markup stavia zdieľaný builder `nxAboutHtml(info, updater)` načítaný v `panel.html` aj `studio.html` — koliesko Inspectora
má hostiteľa `#cfgAbout` (plní ho `NX.init` → `nxAboutFill('cfgAbout', info)`), sekcia `about` ho plní z payloadu (`nxAboutFill(host, about, updMerged())`). Blok
updatera `nxUpdaterHtml(updater)` sa pripojí **len v sekcii Štúdia** (jediné zapisovateľné miesto mimo `bset`; v koliesku by bolo mŕtve tlačidlo). Dáta (verzia
a priečinok nastavení) dáva výhradne server; verzia sa píše **„v0.17.x"** (malé „v" — aj pätička Inspectora `bridge.js` `verline` a stav updatera). Pravidlá
`.aboutrow`/`.aboutlogo`/`.aboutname` v `css/panel.css` nie sú scopnuté pod `.nx-inspector`. Licencie a diagnostika sa tu nepridávajú (vedomá odchýlka od mockupu).

### updater.rb — aktualizácia pluginu jedným klikom (D-52a jadro · D-52b1 kontrola · D-52b2 aplikovanie)

**Čisté jadro** (pri načítaní nesiaha na `Sketchup.*` ani `UI.*`, všetky cesty ako parametre; testy nad TEMP sandboxom). **Balík = kópia repa** (`noxun_engine.rb` +
strom `noxun_engine/`), **jednotka atomicity je celý balík** (nový strom so starým loaderom je zakázaný stav). **Rozloženie v `Plugins`:** `noxun_engine.new/` +
`noxun_engine.rb.new` (staging) · `noxun_engine.old/` + `noxun_engine.rb.old` · `noxun_engine.update.json` (marker) · `noxun_engine.update.lock` ·
`noxun_engine.leases/<pid>.lease`.

**Dve fázy:** **`prepare!`** (kanonické hranice → zámok → marker → manifest zo zdroja → staging **kópiou** do `.new` → validácia proti manifestu byte-for-byte →
rozhodnutie o verzii) je **worker-safe** a živej generácie sa nedotýka, vracia **tiket**; **`commit!`** (len renamey + latch) beží v hlavnom vlákne. Medzi fázami drží
exkluzivitu **marker** a rozhoduje **nonce** (náhodná identita prípravy v markeri aj tikete); nezhoda = odmietnutie bez dotyku cudzích artefaktov. Nedokončená
príprava → **`abort_prepared!`** (uprace len vlastný staging). `apply!` = obal `prepare!` + `commit!` (testy).
- **Swap:** (3) `noxun_engine` → `.old` → (4) `.new` → `noxun_engine` → (5a) záloha loadera **kópiou** `.rb` → `.rb.old` (bokový súbor + `fsync`) → (5b) jediný
  atomický `File.rename('.rb.new', '.rb')` (`noxun_engine.rb` existuje v každom okamihu) → (6) `.old` sa maže po úspechu (zlyhanie = úspech s poznámkou).
  **Bod commitu = úspešný rename loadera** → hneď `Engine.restart_required!`.
- **Jedno pravidlo po kroku 3:** buď (A) plný rollback overený na disku, bez latchu, alebo (B) latch + zachované `.new`, `.old` a marker pre boot recovery — každá
  chybová cesta končí v `abort_after_move!` (guard test: za krokom 3 žiadny iný `raise Refused`). Pri zlyhanom rollbacku sa nič nemaže a hláška rozlíši „reštartuj"
  vs. „spusti INSTALL". `.old` maže len `discard_previous!` a len keď stojí živý strom aj loader.
- **VERSION sa číta zo staged stromu** (loader krížovo s `main.rb`, porovnanie číselne po segmentoch; chýbajúca, neplatná aj duplicitná definícia = chyba; pred
  commitom celý sken `assert_single_version!`). **Downgrade je zakázaný** (`:newer | :same | :older`, `:older` = odmietnutie).
- **Kanonické hranice:** cieľ `Engine.plugin_dir` + súrodenecký loader; odmieta sa zdroj == cieľ, vnorenie, prípona `.new`/`.old`, symlink/junction/reparse point a únik
  relatívnej cesty z manifestu. Koncové lomítko sa nestrihá pri koreňoch (`/`, `X:/`, `//server/share`).
- **Zámok a lease:** vlastný `noxun_engine.update.lock` (`flock`, `LOCK_NB` — nikdy čakanie). Každá inštancia zapíše lease **už v loaderi na začiatku bootu pod
  zámkom**; lease nesie `{std, pid, exe, started_at}` a `live_leases` overí cez `tasklist /FI "PID eq N" /FO CSV /NH`, že PID patrí SketchUpu s tým istým image name
  (výstup binárne, kontrola exit statusu; „mŕtvy" len odpoveď bez CSV riadkov). Kontrola dvakrát (vstup a tesne pred swapom). **Fail-closed:** boot bez zapísaného
  lease vráti `:lease_failed` a plugin sa nenačíta; nezistiteľný stav lease = `Refused`.
- **Restart latch:** (1) `Engine.update_restart_pending?` odmietne všetky vstupné body (toolbar, `Panel.show`, `Panel.show_insert`, `StudioDialog.show`) natívnou
  hláškou; (2) generické `cb` wrappery (`Panel.cb`, `StudioDialog.cb`) volajú `Engine.update_locked?(:panel/:studio)` — hláška raz za okno. Latch je jednosmerný.
- **Nastavenie cesty:** `updater_settings.json` v `%APPDATA%\NOXUN\Engine` (`{std, source_dir}`, `JsonFileStore` + `.bak`), zápis pod `Materials.with_catalog_lock`,
  nad degradovaným súborom odmietnutý; zlyhanie vracia `nil`.
- **Recovery po páde žije v loaderi** (`Noxun::Engine::Boot`, len `File`/`FileUtils`, pred registráciou extensionu; guard `tests/pure/test_d52a_updater.rb`).
  **Strom na disku musí zodpovedať práve vykonávanému loaderu:** stojí `.new` → vráti starú generáciu · `.old` a VERSION `.rb` ≠ strom → rollback stromu · `.old`
  a VERSION sedí → dokončí upratanie (rozhoduje obsah VERSION; nečitateľná = rollback). **Recovery nikdy nemaže živý `.rb`** — starú verziu loadera vracia
  atomickým prepisom (`File.rename` cez existujúci cieľ: `restore_loader!`, `finish_leftovers!`), takže `Plugins` nie sú ani na okamih bez bootovateľného loadera.
  Nesúlad po oprave = plugin sa v tomto okne nenačíta. **Marker sa maže
  overene** (`clear_marker`; prežitý marker = `cleanup_pending` / `:marker_stuck`; `marker_note` dopĺňa vetu do `Refused` správ). **Boot stavy:** `:idle`, `:done`
  → registrácia; `:busy` (čaká max ~5 s), `:restart`, `:lease_failed`, `:marker_stuck`, `:error` → bez registrácie s natívnou hláškou. **`:unsupported`**
  (H11b, F-02) = SketchUp starší ako 2026: **poradie je gate → recovery** — kontrola minima (`SketchupMinimum.check`, mimo `module Boot`, `MIN_SKETCHUP_MAJOR = 26`)
  beží PRED `Boot.recover!`, takže nepodporovaný SketchUp nesiahne na zámok, lease ani strom; jedna hláška (`Boot.announce` s textom z `SketchupMinimum.message`)
  a bez registrácie. Zdroj verzie je číselné `Sketchup.version_number` (major = číslo / 100 000 000), reťazec `Sketchup.version` je záloha a krížová kontrola;
  **neznáma alebo rozporná verzia = fail-open** (plugin sa načíta, riadok v konzole). Inštalátor má to isté minimum (`$MinSketchupYear`, `-ResolveOnly` = len výpis cieľa). Porovnanie generácie beží
  aj na `:idle` (cudzí proces mohol aktualizáciu medzitým dokončiť a upratať), ale blokuje **len dokázaný nesúlad** — keď sa verzia stromu zistiť nedá (chýbajúci
  alebo nečitateľný `main.rb`), plugin sa načíta normálne a chybu samotného `main.rb` ohlási SketchUp pri jeho načítaní (`Sketchup.require` extensionu);
  chyby vnútorných súborov načítaných z validného `main.rb` hlási obal `AppLifecycle.require_part` (odsek `app_lifecycle.rb`). Zámok sa berie pri každom boote.

**UI vrstva — sekcia „O plugine"** (server `supplier_settings_dialog.rb`, klient `about.js` + `studio_settings.js`):
- **Kontrola verzie je explicitná akcia** (nie súčasť payloadu): spúšťa ju vstup do sekcie (klik aj deep-link → `studioSwitchSection` → háčik `enter` riadka `about` = `ssOnAboutEnter()`) a uloženie
  cesty. Beží **vo vlákne s deadline** (vo vlákne len `Updater.check`; výsledok nasadzuje `UI.start_timer` každých 0,2 s, po 4 s „zdroj neodpovedal"); vlákno sa
  nezabíja. **Token = (cesta, inštancia Štúdia `StudioDialog.instance_token`, sekvencia)**; **jeden bežiaci dotaz na jednu cestu** (`updater_worker` — živý beh sa
  zdieľa, hotový zahadzuje).
- **Aplikuje sa len to, čo bolo skontrolované:** server pri úspešnom doručení zapíše `{dir, token, state, dlg}`, klient pri klike vracia `checked_path` + `check_token`;
  `apply!` len keď stav je `newer`, cesta = uložená, okno to isté a hodnoty sedia; doklad sa **spotrebuje**. Doklad viaže aj verziu (porovnanie s `ticket['to']`
  po `prepare!`, nezhoda = `abort_prepared!`). Klient zahodí výsledok, keď push prinesie inú `about.updater.source_dir`.
- **Pole cesty** má vlastný namespace `data-updater-edit` (nie `data-ss`); rozpísaná cesta prežije push (`UPD_DIRTY`), zaniká na `SS.updater({saved:true})` len keď je
  v poli stále odoslaná hodnota (`UPD_SENT`); rozpísaná cesta **zamyká tlačidlo okamžite** (`updPaint()`); `updSyncField` dorovná pole na cestu zo servera, keď nie
  je nič rozpísané. Stav `newer` / `same` / `older` / `checking` / `error` — tlačidlo vždy `aria-disabled`, nikdy `disabled`.
- **Bariéra pred swapom je jediná cesta k aplikovaniu:** klik → D-15 potvrdenie (bez `nx_modal.js` sa nespustí) → `Panel.hide` + `StudioDialog.hide` → timer čaká na
  **`dialog_closed?`** oboch (dobehnutý `set_on_closed`, nie viditeľnosť; limit 3 s, potom zrušenie) → **`Updater.prepare!` vo vlákne** (`UPDATER_STAGE_S` 60 s) →
  **druhá bariéra** `commit_when_closed` → `Updater.commit!` v hlavnom vlákne. **Single-flight:** `@updater_apply_inflight` pred zatvorením okien, spotrebovaný doklad,
  odložené čakanie overí `Engine.restart_required?`. **Počas behu sa okná neotvárajú** (`Engine.update_in_progress?` vo všetkých troch vstupoch); príznak uvoľňuje
  jediné miesto `updater_done!`. Zlyhané upratanie prípravy prizná `abort_note`. Ďalšie účastníky bariéry: `Tools::ZDialog` (odsek `mower.rb`).
- **Výsledok ide výhradne natívne** (`UI.messagebox`; guard zakazuje v `updater_run_apply` `set_status`, `push_updater` aj `js(`); neúspech sa vetví podľa latchu
  (`updater_failure_text`). Testovacie seamy `SupplierSettingsDialog.test_clock / test_spawn / test_schedule / test_notify` (v produkcii `nil`).
- **Hranice:** žiadny auto-check na pozadí, auto-reload, downgrade, podpisovanie balíka ani sync knižníc.

Plné znenie: archív, „updater.rb — …" a „UI vrstva — sekcia „O plugine" v Štúdiu".

## Okná — lifecycle

### app_lifecycle.rb

**Životný cyklus pluginu v procese SketchUpu (F-01) — čistý Ruby, prvý načítaný súbor pluginu. Dnes len načítanie súborov s jednou hláškou**; ukončovanie
SketchUpu (pád #1117 na 2026.2) tu zatiaľ nie je — rieši ho dávka H11c (záložný návrh Z1 s vlastným auditom, nižšie).
- **Načítanie:** `main.rb` najprv **bootstrapom** načíta tento súbor (Ruby `require` s absolútnou cestou, vlastná chybová vetva `rescue StandardError, ScriptError`
  + **sentinel** `AppLifecycle::LOADED` na poslednom riadku súboru = vykonal sa celý). Chyba bootstrapu = jedna hláška o základnom súbore (`Engine::BOOTSTRAP_MESSAGE`)
  a zvyšok `main.rb` sa nevykoná. Potom **95 súborov `main.rb` a 14 častí `ui/panel.rb`** ide cez **`AppLifecycle.require_part 'noxun_engine/…'`** = Ruby `require`
  s absolútnou cestou `<Plugins>/<path>.rb` (rovnaká semantika na 2026.0 aj 2026.2; `Sketchup.require` chyby do 2026.1 prehltne a vráti `true`, od 2026.2 ich
  prepustí). Návrat `true` (načítaný) / `false` (už bol) / `nil` (chyba): záznam `{path, class, message, backtrace(6)}` do `failures` (alebo do `record:`), riadok
  v konzole, **nikdy nevyhodí** (`StandardError` + `ScriptError`; `Interrupt` prejde) a **pokračuje sa ďalším súborom** (diagnostika celého rozsahu). Plugin sa
  **nešifruje** (`.rbe`/`.rbs` Ruby `require` nenačíta; guard). Kontrakt platí pre súbory načítané z validného `main.rb` — syntax chyba samotného `main.rb` ostáva
  v réžii SketchUpu.
- **Fail-closed init:** `Engine.init_allowed?` (memo na proces) pustí init (migrácie, menu, toolbar, observery) **len** keď `failures` je prázdne; inak
  **`announce_failures!`** = **jedna** hláška na proces („Noxun Engine sa nenačítal celý — chyba v súbore … (spolu N)… Reštartuj SketchUp; ak to nepomôže,
  nainštaluj plugin znova.") a plugin je v tomto okne SketchUpu vypnutý (rozhodnutie Michala Q1). **Jediná podporovaná obnova = reštart SketchUpu** (ručný reload
  by nechal `panel.rb` v require cache bez jeho častí). Nový súbor pluginu = riadok v `main.rb` **aj** v zmrazenom zozname `tests/pure/test_h11a_nacitanie.rb` (T6).
  `reset_for_tests!` volajú len testy (guard).

#### Zatvorenie okna vs. ukončenie SketchUpu (zmerané, rieši H11c)

Hooky `set_on_closed` Inspectora (`panel.rb`) a Štúdia (`studio_dialog.rb`) sa pri ukončení SketchUpu **volajú** a na 26.0.429 prídu **PRED**
`AppObserver#onQuit` (poradie B) — quit test H11a cez `Sketchup.quit` aj Súbor > Koniec: stopa `hook:studio` · `hook:inspector` (pri `Sketchup.quit` niekedy aj
`pop:executed` z timera) · až potom `on_quit`, exit kód 0. Príznak z `onQuit` by preto hooky pri ukončení nezachytil; v 2026.2 `pop_tool` z hooku padá (#1117).
Riešenie je **záložný návrh Z1** v dávke **H11c** (hook nástroj nepopne, ghost sa ukončí sám pri ďalšom vstupe) s vlastným auditom, keď bude SketchUp 2026.2.

**Quit test** (`scripts\run_su_tests.ps1 -QuitProbe`, s `-QuitMenu` cesta Súbor > Koniec cez `send_action` 57665 → `tests/sketchup/su_quit_probe.rb`):
kópia ENGINEtests.skp, Inspector + Štúdio + ghost, **inštrumentácia žije len v sonde** (vlastný `AppObserver#onQuit`, obaly `Panel.detach_observer`,
`StudioDialog.detach_stale_observer`, `GhostTool.pop_tool`), stopa cez vopred otvorený handle do `quit_trace.txt`, uloženie run-kópie, ukončenie; verdikt **až po
zániku procesu** = **záznam, nie brána**: skript vypíše `QUIT-TEST: ZAZNAM` so stopou, exit kódom a poradím (`A` = `on_quit` pred hookmi okien, `B` =
hooky pred `on_quit`); exit 0 len pri ukončení s kódom 0 a presne 1× `on_quit`, inak 1 (0xC0000374 = 1). Kritériá PASS/FAIL pre záložný návrh Z1 **prepíše H11c**.
In-SU: `run_h11a` (P1 brána načítania, Q7) a `run_h11a_async` (Q1 ručné zatvorenie) v `su_runner.rb`.

### Satelitné okná

**Plugin má dve okná — Inspector a Štúdio** (plus malý Z-dialog nástrojov); samostatné satelitné okná už nie sú (ich zoznam a zánik: sekcia „História"). Ďalšie okno
je **rozhodnutie, nie vedľajší účinok dávky** — guard test kontroluje počet aj mená. Obe okná idú spoločným boot hookom `Engine.register_dialog_fit` (téma + dorovnanie
veľkosti; guard test). **Každé okno, ktoré ukazuje čísla zákazky, musí byť vo všetkých refresh cestách** — prepnutie modelu (`scale_observer`), zápis katalógu
materiálov (`materials_dialog`), sadzby (`supplier_settings_dialog` → `refresh_studio` → `StudioDialog.refresh_if_open(bump: true)`), sety a položky kovania
(`hardware_catalog_dialog` `push_items`/`after_sets_change`), prepočet cien (`price_refresh_after_proc` v `studio_dialog.rb`) — inak zamrzne na starých číslach
(guard test). Serverové moduly sekcií Štúdia s menom `*_dialog.rb` sú opísané pri svojich sekciách vyššie.

### Veľkosť okna pri otvorení (D-77)

`width`/`height` v `HtmlDialog.new` platia **len pri prvom otvorení** — potom rozhoduje veľkosť zapamätaná pod `preferences_key`; `min_width`/`min_height` bránia len
ručnému zmenšovaniu. Každé okno preto deklaruje v HTML **obsahové minimum** `window.NX_FIT_MIN` a `ui/js/win_fit.js` po načítaní zmeria viewport; keď nesedí, pošle
`nx_fit` a `Engine.register_dialog_fit` (main.rb — spoločný boot hook okna, registruje aj `nx_theme`) okno cez `set_size` dorovná **oboma smermi**: nahor po
deklarované minimum a nadol po dostupnú plochu obrazovky.
- **Plocha má prednosť pred minimom**; medzi minimom a plochou sa nesiaha na nič (vedomá voľba používateľa); fit beží **len raz pri načítaní**; keď plocha nie je známa,
  okno sa smie len zväčšiť. Rámik sa dopočíta z rozdielu outer/inner. JS je len merač — hodnoty mimo 240…2600 px Ruby zahodí. Test `tests/js/test_d77_okno_fit.js`.
- **D-51:** jedna pravda je obsahový viewport v `NX_FIT_MIN`; rozmery `HtmlDialog.new` sú vonkajšie (obsah + rámik) — Inspector obsah **470 × 810** ⇒ `width/height
  486 × 850`, `min_width 486`; Štúdio obsah **1060 × 640** ⇒ `1076 × 680`, `min_width 1076`. Tabuľka D-51 je v `docs/UI_DIZAJN.md`, stráži
  `tests/pure/test_uib1_kostra.rb`.

## Ostatné

### CONSTRUCTION_FIELDS

Jediný zoznam polí konštrukcie = `CONSTRUCTION_FIELDS` v `core.js` ↔ `Panel::PARAM_KEYS` (nové pole na 1 + 1 mieste; navyše tri JS zoznamy mimo neho — odsek
„Kontext Korpus", Nastavenia korpusu). Pole smie niesť `onlyIf: '<predikát NXTypes>'` (H12c; dnes `'corner'`) — `collectConstruction` ho pošle **len** pri
type, ktorý predikát splní (inak ani kľúč; parita payloadu `test_rohb1_ovladace.js`): tak idú `corner_door_w`/`corner_cr1`/`corner_cr2` (`dflt` = `CORNER_DEFAULTS`).
Strana rohovej v zozname nie je (prepínač s vlastnou akciou). Položky nesú `dflt` (riedky config).

**JS register typu skrinky `NXTypes` (`core.js`, H12c)** — JS **nemá vlastný zoznam ani porovnanie mena typu**; typy a ich vlastnosti dostáva od servera
(`cabinet_types` = `CabinetTypes.client_payload`, [construction.md](construction.md#cabinet_typesrb)) **prvým príkazom `NX.init`** (`NXTypes.set`, pred
predvoľbami a výberom — M15). API: `ids()` · `known(t)` · `norm(t)` (neznámy, chýbajúci a `''` = `FALLBACK` dolná — jediná konštanta typu) · `get(t)` · `has(t,
kľúč, hodnota)` · `idsWhere` · `label` · `hangs` (visí, `hang_z > 0` — „len horná") · `onFloor` (stojí na podlahe — horná ani slot nie) · `carcass` (má korpus —
slot nie) · `corner` (rohová zostava). **Jedna vlastnosť na miesto, presná množina** (package H12 §0.4/R2.1): sokel 0 v `currentCarcass` a krížovej kontrole =
`hangs`, sokel návrhu čiel, kresba a riadky Sokel/Nohy = `!onFloor`, telo/chrbát/komín/lišty a polia slotu = `carcass`, rohová = `corner`, symbol a karta čiel =
`fronts`, otvor čiel = `front_opening`, „Delenie zóny" = `zones: shelves_only`, rail Zóny = `zones: none` (+ `zones_reason`), zámok typu šablóny = `template_type`
+ `template_lock`, očakávania šablóny = `appliance_owner`, rozsahy = `limits`. **A1 (audit H12):** skripty Inspectora bežia pred `sketchup.ready()`, preto
**žiadny odvodený zoznam sa neskladá pri načítaní** (`NXInsert.insertTypes()` sa pýta pri volaní); pred doručením registra platí **neutrálny profil = dolná**
(žiadne bliknutie zlého UI). Neznámy surový typ z payloadu (`loadSelected`) sa číta ako dolná; surový ostáva len `NXShell.cabType` (rail sa pýta cez `NXTypes`). Filter šablón
vkladacej karty (`templateType`/`templatesForType`) porovnáva **normalizované** typy (`NXTypes.norm` — neznámy a chýbajúci = dolná), rovnako ako predtým.
Výnimky guardu `test_h12c_js.rb` (allowlist s dôvodom): bootstrap `DEFAULTS` pred `NX.init`, `FALLBACK` a hodnota zostavy v registri. Štúdio register nemá —
slovo typu šablóny (`type_word`) a vetu rozsahu pravidla (`type_scope`) skladá server. HTML (tlačidlá typu, `<select>` modalu) ostáva **statické** (D5) a guard
ho porovná s registrom (`label`, `ui_order`). Mimo registra typu: `part_card.js` `isFront` (vlastnosť roly — H13 mapa) a `rdRoleDesc` roly; mená rolí karta dostane zo servera (`role_label`, H12d).
Sady: golden `test_h12_golden.js` (správanie pred/po bajtovo), `test_h12c_typy.js` (register, A1, M15, matica), Node sady plnia register z fixtúry
(`tests/js/nx_types_fixture.js`). Typy dnes: `lower` · `upper` · `dishwasher` · `corner_blind`.

### Trvalé UI pravidlo (Michal 20.7.2026): VERTIKÁLNY priestor panela je vzácny

Plné znenie a autorita: [../UI_DIZAJN.md](../UI_DIZAJN.md) §1 Princípy (tu len odkaz).

### usage_stats.rb

**Merač používania panela (D-25)** — lokálne počítadlá interakcií s prvkami Inspectora (podklad pre budúci režim Jednoduchý/Rozšírený). Ukladá **výhradne
identifikátory prvkov a počty** (žiadne hodnoty polí ani názvy projektov) do `%APPDATA%\NOXUN\Engine\usage_stats.json` (`JsonFileStore`, `.bak`; SCHEMA 1:
`first_seen`, `last_seen`, `counts`). `record(counts)` nikdy nevyhadzuje; `merge` sčíta dávky a zachová neznáme polia, súbor s novšou schémou sa neprepisuje;
`sanitize_counts` ticho zahodí vadné hodnoty; read-modify-write chráni `flock` na **sidecar** zámku (dve inštancie SketchUpu). Klient `ui/js/usage.js` počíta
kliky v capture fáze a posiela dávku `usage_flush` (handler `actions_usage.rb`). Koreň `UsageStats.dir` = `Materials.dir` (jediný koreň; súpis
[kniznice.md](kniznice.md)).

## História

Vyhradená sekcia — jediné miesto súboru, kde smú stáť historické značky (čísla PR, kolá review, zaniknuté okná). **Plné pôvodné znenie tejto mapy do v0.17.4**
(priebeh dávok ŠT-1…ŠT-4, UI-A…UI-D, KOV-*, ROH-*, S1-*, NP-*, CENY-*, H3a–H4b, dôvody každej pasce a nálezy review) je v archíve
[../../SYSTEM/archiv/UI_LIFECYCLE_historia_do_v0.17.md](../../SYSTEM/archiv/UI_LIFECYCLE_historia_do_v0.17.md); priebeh dávok je v
[../../SYSTEM/archiv/KRONIKA.md](../../SYSTEM/archiv/KRONIKA.md).

**Zaniknuté okná** (fáza ŠTÚDIO, ŠT-1c…ŠT-4a — obsah každého je dnes sekciou Štúdia, serverový modul ostal pod pôvodným menom a nepremenúva sa):

| Zaniknuté okno | Súbory, ktoré zanikli | Dnes |
|---|---|---|
| Výroba (ZANIKLO v ŠT-1c PR B3) | `production_dialog.rb`, `production.html`, `js/production.js`, premostenia `PRODUCTION_BRIDGES`, deep-link na tab | sekcie Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka; jadro `production_core.rb` ([outputs.md](outputs.md)) |
| Materiály projektu (ŠT-2b) | `proj_materials.html`, `DLG_KEY`, `mat_open_window`, `MAT_BRIDGE_STATUS` | sekcia Materiály, modul `materials_dialog.rb` |
| Katalóg kovania (ŠT-3a-2) | `hardware_catalog.html`, `hw_open_window`, `HW_BRIDGE_STATUS`, `win_js`, `push_sets` | sekcia Kovanie, modul `hardware_catalog_dialog.rb` |
| Pravidlá kovania (ŠT-3b-1) | `rules.html`, `open_rules`, `openRulesDialog` | sekcia Pravidlá, modul `rules_dialog.rb` |
| Šablóny (ŠT-3c-1) | `templates.html`, `js/templates_dialog.js`, `open_templates`, `openTemplatesDialog` | sekcia Šablóny, modul `templates_dialog.rb` |
| Nastavenia dodávateľa (ŠT-4a) | `supplier_settings.html`, `js/supplier_settings.js`, `ProductionCore.open_budget_settings` | sekcie Dodávateľ/Demos · Nastavenia rozpočtu · O plugine, modul `supplier_settings_dialog.rb` |

Spolu s posledným satelitom zanikli **premostenia** v navigácii Štúdia (`WINDOW_BRIDGES`, `BRIDGE_STATUS`, `do_bridge`, `bridge_window`, `studio_bridge`) aj klientske
`goto`. V registri používateľa ostávajú osirotené `preferences_key` zaniknutých okien (`NoxunEngineProduction`, `noxun_engine_hw_catalog_v1`, `noxun_engine_rules`,
`noxun_engine_templates`, `noxun_engine_supplier_settings`) — zapamätané veľkosti, ktoré SketchUp už nikdy nepoužije. Modul `appliance_dialog.rb` okno nemal nikdy.

