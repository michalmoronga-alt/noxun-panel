# Externý Codex audit kódu — blok 1c (29. 8. 2026)

> Samostatný pohľad určený na zlúčenie a deduplikáciu s ďalšími dvoma auditmi do `SYSTEM/AUDIT_REGISTER.md`.
> Audit je read-only voči aplikačnému kódu. Stav overený na `main` v0.8.13, commit `dc2d53f`.

## Aktuálny stav oproti zadaniu

- Zadanie vzniklo nad v0.8.5; audit bežal nad aktuálnou v0.8.13 po fast-forwarde o 16 commitov.
- Aktuálny headless balík: **1 999 PASS / 0 FAIL / 0 SKIP**. `SYSTEM/STAV.md` uvádza 1 998, teda je o jeden test pozadu.
- Posledný evidovaný in-SketchUp výsledok v stave projektu: **1 057 PASS / 0 FAIL / 0 SKIP**. V rámci read-only auditu sa SketchUp runner opakovane nespúšťal.
- Staré brány 1b A/G/H (nastavenia a status, čisté čítanie refreshu, charakterizácia observerov) sú uzavreté; tento audit ich neopakuje.
- Stubov „zatiaľ nezdokumentované“ už nie je 19, ale **18**. Doplnené boli okrem iného `ui/panel/sync.rb` a cesta šablón.
- `ui/production_core.rb` už nemá iba „1 200+“, ale **1 834 riadkov**.
- `SYSTEM/AUDIT_REGISTER.md` zatiaľ neexistuje; tento súbor je vstup, nie náhrada spoločného registra.

## P0 — okamžitá eskalácia mimo registra

### P0-HF-01 · P0 · core/ui · `ui/production_core.rb:1619, 1622-1626, 1670-1674, 1699-1708`

**Čo je zle:** Rozpočet XLSX sa zapíše na disk na riadku 1619 a až potom sa vyhodnotí, že niektoré riadky nemajú cenu. Cenová ponuka sa zapíše na riadku 1671 a až následne `cp_warnings` prizná podhodnotenú sumu, zápornú „Nábytkovú zostavu“ alebo nesúlad s rozpočtom. Výsledkom je normálne otvoriteľný finálny XLSX so známou chybnou cenou; červený status vznikne až po jeho vytvorení.

**Blokuje:** Aktívne reálne cenové výstupy; podľa definície zadania ide o P0, nie o položku čakajúcu na register.

**Návrh riešenia:** Pred `savepanel`/zápisom zaviesť finálnu cenovú bránu: chýbajúca cena, záporná zostava alebo nekonzistentná suma normálny export zastaví a vypíše konkrétne dôvody. Rovnakú bránu použiť pre rozpočet aj ponuku; test musí dokazovať, že pri chybe súbor vôbec nevznikne. **Odhad: S.**

### P0-HF-02 · P0 · core/ui · `core/hardware_sets.rb:1055-1065`; `ui/production_core.rb:1150-1159, 1619-1626, 1671-1674`

**Čo je zle:** Člen setu `per: owner` sa deduplikuje kľúčom z `owner_id`; dve fyzické skrinky so spoločným `cabinet_id` preto dostanú napríklad TipOn iba raz. Kód tento dôsledok pozná, ale nákupný CSV, rozpočet a cenovú ponuku najprv zapíše a varovanie zostaví až potom. Test `tests/pure/test_1b3_citanie.rb:227-279` navyše dnešné správanie výslovne charakterizuje ako varovanie, nie blokovanie.

**Blokuje:** Aktívna objednávka kovania a cena zákazky; hotový súbor obsahuje známy podpočet.

**Návrh riešenia:** Pred zápisom troch dotknutých výstupov zastaviť export pri duplicitnom ID skrinky, ktoré môže zlievať vlastníkov; používateľa poslať na konkrétny nález v Kontrole. Predikát musí rozlíšiť skrinku od dosky, aby doska nedostávala nepravdivý text o kovaní. VEPO netreba blokovať touto bránou bez samostatného dôkazu. **Odhad: S.**

## Nálezy pre register 1c

### R-01 · P1 · core · `core/scale_observer.rb:97-115, 129-135, 180-200`

**Čo je zle:** Komentáre deklarujú multi-model bezpečnosť pre macOS, ale `@dirty` a `@added` sú kľúčované iba `entityID`, ktoré je lokálne pre model. Udalosť z druhého dokumentu môže v tom istom debounce okne prepísať prvú. Mazanie má navyše iba jeden globálny príznak `@need_prune` a jeden `@erase_model`, takže dve mazania v rôznych dokumentoch sa zlejú do jedného spracovania.

**Blokuje:** GHOST — bezpečný Tool lifecycle a observer/undo disciplínu; na macOS aj dnešný dedup, scale a upratanie ghost zón. Windows vetva je týmto konkrétnym stretom nedotknutá, pretože proces drží jeden dokument.

**Návrh riešenia:** Kľúčovať dirty/added stav dvojicou `[model.object_id, entityID]` a prune požiadavky držať ako množinu modelov. Tick spracovať po modeloch a doplniť charakterizačný test dvoch modelových stubov plus manuálny macOS smoke. **Odhad: M.**

### R-02 · P1 · ui · `ui/js/actions.js:385-411`; `ui/panel/actions_cabinet.rb:286-309`

**Čo je zle:** Insert payload skrinky neposiela `model_guid`; oneskorený HtmlDialog callback na serveri bez guardu vezme aktuálny `Sketchup.active_model`. Na macOS tak prepnutie dokumentu medzi klikom v Inspectore a spracovaním callbacku môže vložiť draft z dokumentu A do dokumentu B. Susedné asynchrónne cesty už `model_guid` používajú, napríklad tagy a výber dielcov v `actions.js:433-461`.

**Blokuje:** GHOST a už dnes bezpečnosť vkladania pri viacerých dokumentoch.

**Návrh riešenia:** Pridať povinný `model_guid` do insert payloadu a serverový guard pred každým preflightom alebo zápisom. Placement session následne zachytí priamo model aj jeho identitu a pri prepnutí dokumentu sa zruší. **Odhad: S.**

### R-03 · P1 · core/ui · `core/cabinet_builder.rb:107-138`; `ui/panel/actions_cabinet.rb:286-309`

**Čo je zle:** Dnešné API spája normalizáciu, pridelenie ID, `Placement.next_x`, otvorenie operácie, zmrazenie snapshotov a vytvorenie geometrie do jedného okamžitého `build`. Handler rovnako spája validáciu draftu a commit. Neexistuje čistý pripravený objekt, ktorý môže Tool bezpečne držať bez zápisu, ani explicitný finálny transform; builder vždy použije `next_x`.

**Blokuje:** GHOST — pred klikom nesmie vzniknúť ID, snapshot, entity ani Undo krok; po kliku musí vzniknúť jedna skrinka rovno na finálnom transforme.

**Návrh riešenia:** Zaviesť úzky šev `prepare_insert` (čisté preflighty, nemenný snapshot) a kompatibilný `build(..., transform:)`/`commit_insert`; hardware freeze ostane v operácii commitu a template usage až po úspechu. Tool nesmie duplikovať výrobné pravidlá. **Odhad: L.**

### R-04 · P1 · core · `core/hardware_sets.rb:20-26, 86-105, 1042-1066, 1382-1424`

**Čo je zle:** Člen setu pozná iba `per: unit` a `per: owner`, `qty` je kladné celé číslo a expanzia má iba vetvy `quantity × qty` alebo `qty raz na vlastníka`. Pomer D-109 „1 ks na N nôh“ sa nedá vyjadriť bez zneužitia zlomkového množstva alebo bez logiky mimo schémy. `explain_members` má rovnaké binárne vetvenie, takže ani náhľad nemá pripravený kontrakt.

**Blokuje:** D-109 a redizajn KOVANIA.

**Návrh riešenia:** Pred implementáciou uzavrieť jednu explicitnú semantiku pomeru vrátane zdrojového počtu a zaokrúhlenia (pravdepodobne nahor); potom atomicky rozšíriť validáciu, normalizáciu, expanziu, vysvetlenie, UI a testy. Nepoužiť desatinné `qty`, lebo by skrylo pravidlo zaokrúhlenia. **Odhad: M.**

### R-05 · P1 · core · `core/hardware_sets.rb:86-97, 241-254, 314-326, 519-542, 619-628`

**Čo je zle:** Projektový snapshot správne používa obsahový marker `std` 1/2 a neznámu verziu odmietne. Globálny `%APPDATA%` súbor však vždy zapisuje `std: 1`, hoci seed aj používateľské sety môžu niesť `param_bands`/selectory vyžadujúce verziu 2; `load` marker vôbec nekontroluje a neznáme tvary normalizuje. Staršia alebo budúca verzia tak môže načítať iba časť setu a pri ďalšom zápise stratu zvecniť — presne riziko, ktoré komentár pri snapshotoch už pomenúva.

**Blokuje:** KOVANIE/D-109, bezpečný downgrade/upgrade a neskôr zdieľanú knižnicu.

**Návrh riešenia:** Použiť obsahový marker aj pre globálny súbor, pri D-109 pridať ďalšiu verziu a na load-e zaviesť „unsupported = read-only/odmietnuť“, nikdy seed fallback s možnosťou prepísania cudzieho formátu. Pridať round-trip a downgrade-gate test. **Odhad: M.**

### R-06 · P1 · core · `core/json_file_store.rb:36-43`; `core/hardware_sets.rb:337-407`; `core/hardware_rules.rb:210-220`; `core/abs_rules.rb:186-195`

**Čo je zle:** `JsonFileStore` garantuje atómový súbor a `.bak`, nie súbeh. Pri setoch sa revízia overí pred následným `load → modify → write`, ale celý sled nie je pod medziprocesovým zámkom; dve inštancie SketchUpu môžu obe prejsť guardom a posledný zápis zmaže prvú zmenu. Globálne mapovanie nemá ani revision parameter. Rovnaký nezamknutý zápis používajú pravidlá kovania, ABS pravidlá, rozmerové rady a dodávateľské nastavenia; materiály, šablóny a usage stats už správny sidecar `flock` vzor majú.

**Blokuje:** KOVANIE a spoľahlivosť globálnych katalógov; spláca perzistenčný dlh pred shared library. Na Windows je riziko aktuálne pri dvoch procesoch SketchUpu, aj keď každý proces drží iba jeden dokument.

**Návrh riešenia:** Zjednotiť write transakciu na `lock → fresh read → revision check/merge → atomic write`; revíziu kontrolovať vnútri zámku. Začať setmi a pravidlami kovania, potom rovnakým helperom pokryť ostatné globálne nastavenia. **Odhad: M.**

### R-07 · P2 · core · `core/store.rb:9-10, 28-49`

**Čo je zle:** Entity síce zapisujú `std`, ale čítacia vrstva ho nikdy neoveruje: `noxun?` rozhoduje iba podľa `kind` a `config` sa parsuje bez kompatibilitnej brány. Starý záznam, chýbajúci marker aj neznámy novší marker teda vyzerajú rovnako. Pri budúcej zmene formátu môže starší plugin novšiu entitu normalizovať a prestavať ako dnešný tvar.

**Blokuje:** Bezpečné otváranie starých/novších zákaziek a migračnú cestu pred V1/shared library.

**Návrh riešenia:** Zaviesť centrálny stav `legacy/current/newer/invalid`; legacy migrácie vykonávať iba vo výslovnej zapisovacej operácii a novšiu verziu držať read-only s jasnou Kontrolou. Migračné testy musia pokryť chýbajúci, aktuálny aj vyšší `std`. **Odhad: M.**

### R-08 · P2 · ui · `ui/production_core.rb:2-17, 712-733, 1042-1056, 1172-1235, 1495-1543`

**Čo je zle:** Súbor sa označuje za čisté jadro, ale v 1 834 riadkoch mieša zber a výpočty s `UI.select_directory`/`savepanel`, výberom entít, fokusom Inspectora, statusmi okna a mutáciami `BudgetStore`. D-95, exporty aj budúca ponuka tak musia závisieť od UI modulu a jeho textových callbackov; čisté jadro sa nedá použiť alebo testovať bez načítania tejto vrstvy.

**Blokuje:** KONTROLA + VÝROBA, neskorší renderer ponuky a stabilitu výstupov.

**Návrh riešenia:** Nerobiť hromadný presun. Najprv vyrezať jeden neutrálny `ProductionSnapshot/OutputPackage` (BOM, odhady, hardware, validácia, rozpočet), potom ponechať dialógy, fokus, status a file picker v UI orchestrátore; budget príkazy oddeliť ako vlastnú službu. **Odhad: L.**

### R-09 · P2 · core · `core/budget.rb:164-200, 715-721`; `core/cp_export.rb:305-370`; `ui/production_core.rb:845-937`

**Čo je zle:** Studio/VEPO už pri kolízii eskaluje menovku cez výrobcu, typ, formát, rub a nakoniec ID. Rozpočet si však skladá vlastný názov iba z `decor + type + thickness`; CP špecifikácia používa ďalší vlastný fallback a výrobcu nepridáva. Dva platné katalógové materiály rôznych výrobcov preto môžu byť v nákupnom/cenovom dokumente pomenované rovnako, hoci katalógová identita ich zámerne rozlišuje.

**Blokuje:** KONTROLA + VÝROBA a dôveryhodnosť rozpočtu/ponuky.

**Návrh riešenia:** Presunúť tvorbu jednoznačných ľudských názvov z `Panel` do core materiálového helpera a použiť ju v Studiu, VEPO, rozpočte aj CP. Kolízny test má vytvoriť rovnaký dekor/type/hrúbku pre dvoch výrobcov. **Odhad: M.**

### R-10 · P2 · ui · `ui/js/budget.js:1392-1397, 1441-1472, 1557-1568`

**Čo je zle:** Editor „⋯“ nastaví `BUD_MORE.sent = true` ešte pred `budSend`. Ak už prebieha iný zápis, jeho vlastný update iba skončí vo fronte; výsledok staršieho inline zápisu s rovnakým `op` sa potom mylne vyhodnotí ako odpoveď modalu a môže ho zavrieť. Queued zápis sa síce neskôr odošle, ale ak ho server odmietne, používateľ už nemá otvorené hodnoty na opravu. Existujúci test pokrýva cudzí výsledok pred submitom, nie submit počas `BUD_BUSY`.

**Blokuje:** Spoľahlivosť rozpočtových metadát; spláca UI/payload koreláciu.

**Návrh riešenia:** Označiť modal ako `sent` až pri reálnom odoslaní z fronty alebo pridať request token prenesený serverovým echom. Doplniť regresiu „inline update beží → submit ⋯ → prvá odpoveď modal nezavrie“. **Odhad: S.**

### R-11 · P2 · core · `core/validation.rb:690-718`; `tests/pure/test_st1b_kontrola.rb:164-183`

**Čo je zle:** Zelené číslo používa skutočný počet skriniek ako menovateľ, ale „špinavé“ skrinky počíta iba cez množinu dostupných `cabinet_id`. Dve skrinky so spoločným ID a skrinka bez ID preto nemajú samostatnú identitu; test vedome akceptuje, že jeden nález z dvojice zníži clean iba o jednu. Text „skrinky bez nálezu“ tak môže byť vyšší než skutočný počet čistých fyzických skriniek.

**Blokuje:** D-95 plošnú kontrolu — súhrnný semafor nesmie nadhodnotiť čistý stav zákazky.

**Návrh riešenia:** Počítať clean cez per-instance token z placementov (persistent ID/ref), pričom verejný stable key a klik-adresa nálezu môžu zostať nezmenené. Pridať test pre dve kópie s jedným ID a entitu bez ID. **Odhad: M.**

### R-12 · P2 · core/ui · `core/cp_export.rb:8-16`; `ui/production_core.rb:1636-1674, 1709-1712`

**Čo je zle:** Kontrakt CP tvrdí, že interný pojem sa do zákazníckeho dokumentu „NIKDY“ nedostane, ale export firewall hits iba spočíta, XLSX zapíše a potom ukáže varovanie. Blokový komentár navyše tvrdí „ide do statusu aj do logu“, hoci kód žiadny log nevytvára. V priečinku tak ostane zákaznícky dokument, o ktorom už exportér vie, že porušil vlastný firewall.

**Blokuje:** V1 dotiahnutie ponuky a zákaznícku kvalitu; spláca známy Docs cleanup C dlh.

**Návrh riešenia:** Firewall vyhodnotiť pred zápisom a pri hite export zastaviť s konkrétnymi termínmi. Klamlivý komentár zosúladiť so skutočným kontraktom; nevymýšľať trvalý log, ak ho STANDARD nepožaduje. **Odhad: S.**

### R-13 · P3 · core · `core/scale_observer.rb:500-512`; `tests/sketchup/su_runner.rb:9231-9266`

**Čo je zle:** `@stable_transforms` sa plní kľúčom `[model.object_id, entityID]`, ale nemá žiadnu čiastiacu cestu. In-SketchUp charakterizačný test výslovne dokazuje, že záznam prežije reálne používateľské zmazanie a cache rastie aj po zániku entít alebo dokumentov.

**Blokuje:** Hygiena/stabilita dlhých pracovných relácií; nie je to dnes dokázané výrobné riziko.

**Návrh riešenia:** Pri erase/prune odstrániť kľúče neplatných entít a pri detach modelu vyhodiť celý jeho prefix. Zachovať existujúci charakterizačný test, ale otočiť očakávanie na vyčistenie. **Odhad: S.**

### R-14 · P3 · ui · `ui/js/studio.js:235-260, 1132-1150`

**Čo je zle:** Hľadanie filtruje riadky v materiálovej skupine, no hlavička skupiny ďalej zobrazuje serverové `ks` a `m²` za celý nefiltrovaný materiál. Pri jednom zobrazenom riadku tak môže hlavička tvrdiť súčet desiatok skrytých dielcov bez označenia, že ide o celkový súčet.

**Blokuje:** Hygiena a čitateľnosť Kusovníka; nejde o chybu samotných exportovaných čísel.

**Návrh riešenia:** Pri aktívnom hľadaní buď doplniť viditeľný medzisúčet z filtrovaných riadkov, alebo jednoznačne označiť dnešnú hodnotu ako „celkom“. **Odhad: S.**

### R-15 · P2 · docs · `docs/architecture/ui-lifecycle.md:950-982, 1706-1708`; `docs/architecture/hardware.md:147-151`; `docs/architecture/outputs.md:156-211`; `docs/architecture/model-a-identita.md:284-288`

**Čo je zle:** V živej architektúre ostáva 18 explicitných stubov. Najväčšia diera je práve pri moduloch, ktoré audit pripravuje na zásah: `hardware_sets`, výstupy/rozpočet a rozdelené panelové akcie. Agent dnes musí odvodzovať autoritu, vstupy, zápisy a undo kontrakt priamo z veľkých súborov.

**Blokuje:** Bezpečnú implementáciu GHOST/KOVANIE/KONTROLA + VÝROBA; spláca dokumentačný dlh bloku 1c.

**Návrh riešenia:** Doplniť kostry nižšie ešte pred zásahom do príslušného modulu; každý odsek má povedať zodpovednosť, vstupy/výstupy, perzistenciu, undo a hlavné guardy. **Odhad: M.**

## Kostry kontraktov pre 18 stubov

| Modul | Minimálna kostra, ktorú treba zapísať do architektúry |
|---|---|
| `ui/panel/actions_board.rb` | Insert a mutácie dosky; serverové overenie identity/modelu, materiálová hrúbka, orientácia transformom, jedna operácia a následný cielený push. |
| `ui/panel/actions_cabinet.rb` | Insert/copy/edit korpusu, preflight materiálu a šablónového kovania, freeze snapshotu v tej istej operácii, selection/push po úspechu; doplniť nový model guard a prepare/commit šev. |
| `ui/panel/actions_hardware.rb` | Výber vlastníka a ručné hardware overrides; identita korpus + `owner_part_key` + generic/rule, rebuild pod selection guardom, žiadne slepé klientské množstvá. |
| `ui/panel/actions_materials.rb` | Projektové a korpusové materiálové voľby; server rozhoduje o katalógovej platnosti, hrúbke a rozsahu prestavby, zápis je jedna operácia. |
| `ui/panel/actions_settings.rb` | Nastavenia Inspectora a zdieľané prepínače; odlíšiť `%APPDATA%` preferencie bez Undo od tagov/modelových zápisov s Undo a broadcastom. |
| `ui/panel/actions_usage.rb` | Príjem allowlistovaných UI udalostí merača; žiadne modelové mutácie, iba agregácia do usage vrstvy. |
| `usage_stats.rb` | Denné počítadlá v `%APPDATA%`, merge read-modify-write pod sidecar flockom, reset/čítanie a pravidlá, čo sa nikdy nezbiera. |
| `hardware_sets.rb` | Globálna knižnica vs. projektový snapshot vs. cabinet override; versioned člen setu, mapovanie, bezstratové čítanie, expanzia z raw hardware a ORANGE unmapped kontrakt. |
| `bom.rb` | Jeden read-only prechod top-level modelom, records/placements/identities/hardware; `compute` agreguje iba cez kanonický `row_key`, bez opráv identity. |
| `sheet_estimate.rb` | Čistý odhad platní z BOM, formát/UNI fallback, zaokrúhlenie a duplák; výstup je odhad, nie optimalizovaný nárezový plán. |
| `budget.rb` | Čisté sekcie, totals a `budget_check`; ceny z katalógov/nastavení, chýbajúce ceny sa nepripočítajú a musia aktivovať finálnu exportnú bránu. |
| `budget_store.rb` | Projektové modelové atribúty rozpočtu; každá mutácia validovaná serverom a tvorí jeden Undo krok, stabilné row/source kľúče. |
| `price_refresh.rb` | Jedna asynchrónna session, token cieľa, cancel a terminálny event; sieťový výsledok sa smie aplikovať iba na stále rovnaký záznam/revíziu. |
| `supplier_settings.rb` | Globálni dodávatelia, režimy, sadzby a štandardné riadky; normalizácia, revision guard a po R-06 zamknutý fresh read-modify-write. |
| `vepo_export.rb` | Čistý renderer výrobných súborov/logu z hotového BOM a validácie; rozdelenie 18/36, jednoznačné menovky, žiadny sken ani zápis modelu. |
| `cp_export.rb` | Zákaznícka projekcia toho istého rozpočtu, automatický zvyšok zostavy, špecifikácia a firewall; P0/P2 brány musia prebehnúť pred XLSX zápisom. |
| `xlsx_writer.rb` | Nízkoúrovňový deterministický XLSX/ZIP writer; prijíma hotové bunky/hárky, nepozná zákazku, ceny ani UI a zapisuje až po doménových bránach. |
| `debug.rb` | Read-only diagnostický snapshot s pevným allowlistom; nesmie meniť model ani slúžiť ako produkčný dátový kontrakt. |

## Overené oblasti bez nového nálezu

- `JsonFileStore` chráni poslednú platnú `.bak`, poškodený primár ju neprepíše a dočasná cesta je unikátna pre proces/vlákno. Nález R-06 je o súbehu read-modify-write, nie o atomicite alebo recovery.
- Materiálový katalóg už má schema gate, read-only správanie pre novšiu schému, flock a predmigračnú zálohu. Audit nenašiel dôvod opakovať uzavreté 2A opravy.
- `part_key` je kanonický a `role_key` je zdokumentovaný kompatibilitný alias; BOM `row_key` je jedna autorita. Nový nález v tejto osi je modelová identita insert callbacku, nie alias samotný.
- Bežné formulárové modaly už používajú `NXModal` a materiálové/ABS selecty `NXCombo`. Fázový modal prepočtu cien ostáva vlastný zámerne, pretože počas behu sa nesmie zavrieť Escapom; toto kryje test.
- Selection relay zo Štúdia pred výberom flushne rozpracované edity a po flushi znovu dohľadá entity cez stabilné kľúče. Starý kandidát „klik zahodí draft Inspectora“ sa na v0.8.13 nepotvrdil.
- Windows observer vetva má jeden dokument na proces; multi-model nález R-01 je samostatne označený ako macOS vetva. Existujúce in-SketchUp testy observer/Undo ostávajú dôležitou regresnou bránou.

## Odporúčané poradie realizácie

1. **Samostatná hotfix dávka:** P0-HF-01 a P0-HF-02, vrátane testov „súbor nevznikol“.
2. **Pred GHOST:** R-01 → R-02 → R-03; potom uzavrieť otvorené produktové rozhodnutia z konceptu 09A (TAB vs. Alt/Option, počiatočný Z režim, Orbit suspend/resume, `onCancel` dôvody, focus a `getExtents`).
3. **Pred KOVANÍM:** R-05 a R-06 ako ochrana dát, potom R-04 ako samotný D-109 šev.
4. **Pred D-95/VÝROBOU:** R-11, R-09, R-12 a po etapách R-08.
5. **Hardening/persistencia:** R-07 a R-13; R-14 môže ísť ako malá UI dávka.
6. **Dokumentácia priebežne:** R-15 dopĺňať tesne pred prvým zásahom do každého modulu, nie jedným slepým prepisom bez overenia kódu.

## Celkové hodnotenie

Engine je po UI 2.0 a hardeningu citeľne stabilnejší než podklad v0.8.5: testy sú zelené, čítacie cesty už neopravujú model, payload identity sú prevažne zjednotené a recovery materiálov je silné. Najväčšie riziko už nie je „veľa malých chýb“, ale niekoľko konkrétnych miest, kde systém **pozná chybný finálny výstup a napriek tomu ho uloží**. Po uzavretí dvoch P0 brán sú hlavnými architektonickými švami modelovo viazaný placement session pre GHOST, verzovaný pomerový člen setu pre KOVANIE a neutrálne jadro výstupov oddelené od UI orchestrácie.
