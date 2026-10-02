# PACKAGE H6 · Priestor v Inspectore (D-01 · D-02 · D-05) — blok 9 HARDENING

> **Autorita:** mockup `MOCKUP_H6_INSPECTOR.html` (časti A–I) schválený Michalom s odchýlkami v `ROZHODNUTIA_H6_H7_2026-10-02.md` — **rozhodnutia majú
> prednosť pred mockupom.** Platí: **O1 = variant B** („Vložiť kópiu" a „Uložiť šablónu" ostávajú dole, vedľa seba v jednom riadku, text „Uložiť ako šablónu
> do knižnice" → „Uložiť šablónu", žiadne ikony v hlavičke) · **O2 = A** (stavová veta ostáva na konci panela, ukáže sa len so správou, žiadny pás pri spodku
> okna) · **O3 = B** (pätka s verziou ostáva) · **O4–O13 = A** (odporúčanie mockupu). Zdroje: triedenie D-01 (CU-04, CU-11, GR-22, CS-10), D-02 (CU-02),
> D-05 (CU-10). Blok 9 (`SYSTEM/PLAN.md`, riadok H6): **bez zmeny dát, výroby a cien** — mení sa rozloženie, texty a písmo kót.
> **Trieda (§5):** UI dávka · **výrobná/cenová NIE** · **audit návrhu NIE** · predrecenzia H6a nie / H6b podľa skutočného diffu / H6c áno · **in-SU nie je
> brána** · fotky `scripts\ui_foto.ps1 -Shoot` povinné (payload z Ruby sa nemení → `-Record` netreba) · `codex-po-pr` bez výnimky.
> **Verzia:** každá časť = patch podľa mainu pri štarte (dnes `0.17.15`) + všetky `?v=` v `ui/*.html` + prepis STAV.
> **Stav kódu:** sonda nad `main` **`108c808c`** (v0.17.15, po PR #451). Čísla riadkov mockupu (časť I) sú z v0.17.0 — nižšie sú **prepočítané**.

---

## 0 · Sonda na kóde (headless, 2.10.2026)

Snapshot `git archive main` do scratchpadu (`h6src/`, hlavný checkout sa nemenil), Grep + čítanie funkcií a **Node sonda kót** `HARDENING/sonda_h6_kot.js`
(načíta `core.js` + `preview.js` z mainu do `vm`, vykreslí projekcie, z `viewBox` a `font-size` spočíta px pri náhľade 404 × 323). Do modelu ani repa sa nič nezapísalo.

### 0.1 Tvrdenia mockupu (časť I) proti mainu

| # | Tvrdenie mockupu | Dnes na maine (súbor · funkcia · riadok) | Verdikt |
|---|---|---|---|
| S1 | Pás `#ctxNote` `panel.html:457`, CSS `:1477–1485` | `panel.html:457` (+ komentár :450–456, `data-nx-usage="ctx:korpus"`), CSS **:1495–1504** | POSUN |
| S2 | text `shell.js:138` `ctxNoteText`, viditeľnosť `:125` `sectorVis`, plnenie `:551–565` | `ctxNoteText` :137, `sectorVis` :124 (kľúč `note`), `nxSetCtxNote` :543, `nxCtxNoteApply` :550; dáta `bridge.js` `setCtxNote` :952, `renderCtxNote` :963 (drží `material_id`, Codex #171 P2), volania :544, :757, :827, :865, :957 | POSUN |
| S4 | lišty: `PV_TITLE` :157, `metaDims` :180–195, `metaGroups` :214–224, `nxMetaGroups` :622, `nxSectorMetaApply` :634 | `PV_TITLE` :156, `metaTitle` :167, `metaDims` :179, `metaMaterials` :200, `metaGroups` :213, `sectorMeta` :226, `nxMetaDims` :569, `nxMetaGroups` :614, `nxSectorMetaApply` :626, `NX_META_FIELDS` :646 | POSUN |
| S5 | Klik v `<summary>` potrebuje `preventDefault + stopPropagation` (vzor `nxTipStop`) | `nxTipStop` je **`form.js:2432`** (globál), použitie napr. `panel.html:659` | PRAVDA |
| S6 | Kópia/šablóna `panel.html:914`, `:916`; viditeľnosť `panel.css:1168–1172` | `panel.html:914`, `:916` (triedy `ghostbtn wide insertmore` / `savetpl`); CSS **:1186–1190** (`body.mode-cab … display:block`) | POSUN |
| S7 | Akcie `insertCopySelected` `actions.js:468` (:473), `openSaveTemplateModal` `form.js:1765` | `actions.js:468`/`:473` · **`form.js:1780`** · in-SU volá `Panel.handle_insert_copy` priamo (`su_runner.rb:514`, `:5289` …) — tlačidlo netestuje | POSUN |
| S8 | Status `panel.html:1063`, pätka `:1068`, `NX.setStatus` `bridge.js:891`, `#verline` :301, Ruby `sync.rb:615–617`, CSS :592–594, :1157 | `#status` **:1064** („Pripravené."), pätka **:1069**, `NX.setStatus` **`bridge.js:896`**, `#verline` **:304**, Ruby `set_status` **`sync.rb:624–626`**, CSS **:605–607**, `.nxfoot` **:1175** | POSUN |
| S9 | — | **Nové:** `hardware.js:1533` volá `NX.setStatus('')` (dnes prázdny zelený box s `min-height`) · vzor „prázdna veta je skrytá" už existuje: `#serStatus` (H10b, `panel.css:609–612`) · pasca `display` vs `[hidden]` (D-137, `panel.css:296–298`) | FAKT |
| S10 | Nápoveda `.pvhint` `panel.html:120`, CSS :537, :2188–2196 | `panel.html:120` (spany `.ph-zones`, `.ph-fronts`), CSS **:550** a **:2205–2217** (vrátane `body.mode-part` — dielec ukazuje zónovú vetu) | POSUN |
| S11 | Ghost zón `panel.html:121–127` „Zobraziť zóny (ghost) v modeli" | `panel.html:121–127`, text je už **„Zobraziť obrysy zón v modeli"** (H4 D-07); JS `toggleZones` `actions.js:482–492`, synchro `nxApplyTags` **`shell.js:1017–1023`**; CSS `.zoneline` **dvakrát** (:602–604 aj :1173) + `:1513`; rail má štítok **„Zóny (obrysy)"** (`core/tags.rb:47`); komentár `panel.rb:149–152` | POSUN |
| S12 | Testy ghostu `test_d27_tagy.rb:291`, `test_usage.js:118` | navyše `test_d27_tagy.rb:162–167`; `test_usage.js:118` je syntetický element (§0.2) | PRAVDA + 1 |
| S13 | Hinty `panel.html:262` (Rozmery), :395 (+`materials.js:18`, :33), :574–575, :761–764, :776–777, :785–786 | všetky PRAVDA; `cabMatHint` píše `materials.js:18–19` (s výberom pomocná veta, bez výberu **stavová** „Označ skrinku pre nastavenie jej materiálov.") a :33 | PRAVDA |
| S14 | Spotrebič `payloads.rb:313–315` + `appliance_row.js:81–90` | `Panel.appliance_expects_text` **`payloads.rb:314–318`** (prázdne → pomocná veta, inak „očakáva rúru" = stav); kreslí `aprRowHtml` vetva `expects` `appliance_row.js:81–89` (`.aptxt soft`). Serverový text pripína `test_s1b2_pohlad.rb:473` — **dá sa riešiť len v JS** (payload bez zmeny) | PRAVDA |
| S15 | `.nxtip` `panel.css:271–300`; princíp UI_DIZAJN §1 :48–52 | `.nxtip` **:284–313** · princíp **UI_DIZAJN:75–79** · Štúdio: `.studio .nxtip` (`studio.html:86–102`), vzor `ssTip` (`studio_settings.js:218`) | POSUN |
| S16 | Kóty `pvDimH/pvDimV/pvText` :704–726 (20/18 mm, odsadenie 9–10 mm, čiara 1,4 mm) | **:705–727** PRAVDA · Korpus `renderCabOutline` **:1148–1162** · čelá :1042 (`bez čela`), :1077 (popis), `drawFrontDims` **:1220–1244** · zóny :972, :981 · kovanie `drawHwBase` **:1270–1280** · doska `renderInsertBoardPreview` :1496–1531 · rohová `drawCornerDims` :478–488 | POSUN |
| S17 | — | **Nové texty náhľadu mimo mockupu** (rovnaký problém mm písma): `drawSlotDetail` :787–803 (umývačka, `pvDimV/H` bez veľkosti = 20 mm) · `drawApplianceRefs`/`drawApplianceSplit` :812–868 (S1-F: čísla pásiem 20 mm, `hrana NNN` a hranice pásma 18 mm, odsadenia v mm) · `renderFrontsPreview` :1024 („Čelá: nastav v sekcii Čelá", 20 mm) | FAKT |
| S18 | scéna `sceneSize` :225–273, `DIM_EXT` :134, `DIM_TOP` :136, `PV_PAD` :2, `viewMapping` :281, zoom/pan :1724–1740, :1753–1760 | `sceneSize` **:226–274** (rezervy v mm: `DIM_EXT 70`, `DIM_TOP 34`, `DIM_DEPTH_OFF 14`, Čelá −34/−46/+70, Zóny −46, Kovanie **−96**), `PV_PAD` :2 (mm, posun súradníc — používa ho aj ťahanie priečky), `viewMapping` :282, zoom **:1725–1741**, pan **:1752–1763** | POSUN |
| S19 | Zoom a posun menia len `viewBox`, kresba sa neprekreslí | PRAVDA — `renderPreview` sa volá z `schedulePreview` (500 ms, `form.js:452`), `fitPreview`, `setViewContext`; **na zoom, posun ani zmenu veľkosti okna nie** | PRAVDA |
| S20 | Súhrny: `cabfrontMetaText` `core.js:583–598`, `updateFrontMeta` `form.js:3087`, `nxHwSummary` `preview.js:1422`, voľby korpusu `panel.html:477–481/:506–509/:532–538`, sety `hardware.js:447–455` | `cabfrontMetaText` **`core.js:634`** (`CABFRONT_DECOR_MAX 14` → „H1180 ST37 Du…"), `updateCabfrontMeta` `form.js:113`, `updateFrontMeta` **`form.js:3105`**, `nxHwSummary` **:1423**, `top_mode` :477, `bottom_mode` :505, `back_mode` :532, `hwCabOptionList` **`hardware.js:449–456`**; payload setov `payloads.rb:2253–2275` (`override_set_id`, `override_selector`, `owner_overrides`) · existujú aj skupinové meta `#topMeta`/`#backMeta` (`setbackMetaTexts` `form.js:1183`) — ostávajú | POSUN |
| S21 | Pravidlá kovania `rules.js:606–614` (CS-10) | veta „Platí pre dvierka…" je **`rules.js:684–685`** v `rdGuardHtml` (:649) — blok `<details class="rgrd">` so súhrnom `.rgsum` v `<summary>` a `ontoggle`; stavová `.hint.rgbad` :680 ostáva. V `rules.js` sú ďalšie pomocné `.hint` (:256, :749, :759, :768) → §14 F3 | POSUN |
| S22 | Strom zón: počty | `computeZones()` dáva listy so `shelves`; slová `shelfWord` `actions.js:316` („polica/police/políc"); `renderZoneTree` :290 | FAKT |
| S23 | Dnešné px kót (mockup časť E) | **Sonda potvrdila:** spodná 800×864 Š/V **6,5 px**, sokel/telo/H **5,3** · horná 800×720 **7,8 / 6,4** · vysoká 600×2100 **3,0 / 2,5** · Čelá 800 popis/kóty **6,2**, medzery **5,2** · Čelá vysoká **2,7 / 2,2** · Zóny `764×…` **7,6** · Kovanie súhrn **6,2**, veta **4,9** | PRAVDA |
| S24 | — | **Mŕtva vetva** `preview.js:1161` („hĺbka … mm" pri `sk = 0`): `pvDepthSkew` pri D > 0 vráti ≥ 24 (sonda: D = 1 → 24) | FAKT → H6c ju zruší |
| S25 | — | Kostra Inspectora **nesmie použiť `innerHTML` v `shell.js`** (guard `test_uib1_kostra.rb` „A4") → odkaz v lište sa robí **statickým** prvkom v HTML, JS píše len `textContent`/`title`/`hidden` | FAKT |

### 0.2 Testy, ktoré dnes pripínajú to, čo H6 mení

| Test | Čo pripína | Časť | Zásah |
|---|---|---|---|
| `tests/pure/test_d27_tagy.rb:162–167`, `:291` | `toggleZones` + `nxApplyTags` nasadzuje `zonesChk` | H6a | prepísať: checkbox zanikol, jediný ovládač tagu `zony` = okno tagov; serverové guardy bez zmeny |
| `tests/js/test_usage.js:118` | syntetický `INPUT#zonesChk` pre `changeKey` | — | bez zmeny (D17) |
| `tests/js/test_kovf2_editor_zavesy.js:279` | `.rgbad` (stavová veta) | H6a | bez zmeny + nový assert „?" (R10) |
| `tests/pure/test_s1b2_pohlad.rb:473` | serverový text prázdneho očakávania | — | bez zmeny (rieši sa v JS, D4) |
| `tests/pure/test_uib1_kostra.rb:241–278` | `#ctxNote`, `#ctxNoteSum`, `#ctxNoteLink` (button, `setViewContext('korpus')`), CSS mimo Korpusu, dáta `material_id` + `renderCtxNote` v `setMaterials` | H6b | prepísať na odkaz v lište Náhľadu; test „drží DÁTA, nie text" ostáva (zmení sa len cieľ) |
| `tests/pure/test_uib1_kostra.rb:155–186` | `s1Meta…s4Meta` plní `shell.js`, `function nxMetaGroups()` existuje a neskáče solo strom, programové cesty volajú `nxSectorMetaApply()` | H6b | prepísať guard zberu (S4 už neberie skupiny) + doplniť nové programové cesty (R6) |
| `tests/js/test_uib1_kostra.js:140–184` | matica `sectorVis` (`note`), `ctxNoteText` | H6b | `note` → `link`, `ctxNoteText` → `s1LinkTitle` |
| `tests/js/test_uib_meta.js:31–42`, `:72–90` | S1 názvy projekcií, S4 „N skupín · všetko zbalené" / názov otvorenej skupiny | H6b | S1 ostáva (+ nový `s1link`); S4 prepísať na súhrny obsahu (O12) |
| `tests/js/test_d130b_spolocne.js:37–48`, `:188–195`; `tests/pure/test_d130b_spolocne.rb:104`, `:151–152` | formát „Dub Halifax · 3 · 2/2/0/0", elipsa 14 znakov | H6b | prepísať na O7; `.rb` len správa assertu |
| `tests/js/test_rohb2_nahlad.js:416–420` | S2 rohovej „… · dvere vľavo 450" | — | bez zmeny (S1 odkaz ho preberá) |
| `tests/js/test_uib2_nahlad.js:213–215` | `nxHwSummary` | — | bez zmeny (lišta Kovanie ho len znovu použije) |
| `tests/js/test_uib2_nahlad.js:229–240` | `pvDepthDimZ`/`pvSceneTopZ` (mm rezerva nad skosením) | H6c | prepísať na px model (R1, R6) |
| `tests/js/test_uic1b_vkladanie.js:129–133` | `pvBoardScene` rezerva vpravo/dole > 26 mm | H6c | prepísať na px |
| `tests/pure/test_uic1b_vkladanie.rb:133–136` | zdroj `sceneSize` obsahuje `insertFrontsExtent()` | H6c | musí ostať pravdou (rozsah čiel vkladania) |
| `tests/js/test_rohb2_nahlad.js:149–196` | presné súradnice textov kót rohovej (`y="751"`, `y="787"`, „Š 1100 mm") | H6c | prepísať na relatívne (rad 2 pod radom 1, text bez „mm", 11 px) |
| `tests/js/test_roha2_vkladanie.js:163` | `<text x="889"…>F1 · dvierka` (vodorovný stred v mm) | H6c | ostáva (poloha popisu je v súradniciach obsahu); pri skrátení popisu prepísať |
| `tests/js/test_s1f_preview.js:93`, `:127`, `:137–139` | „hrana 695", počet `<text>` bez pásiem | H6c | texty ostávajú, overiť |
| `tests/js/test_s1e_slot.js:359–365`, `:381`, `:405` | `nxSlotExtent` (obsah, nie rezerva), počet `<text>` | H6c | bez zmeny |

In-SU sada (`su_runner.rb`) **nepripína** žiadny z dotknutých textov ani kót (Grep `ctxNote|zonesChk|pvhint|Pripravené|font-size|Š [0-9]` — 0 výskytov).

---

## 1 · Cieľ

Inspector ukáže viac práce na jednej obrazovke a jeho kóty sa dajú prečítať. **Pomocné texty idú do „?"** (stavové vety ostávajú viditeľné), opakovaný pás
„Skrinka … upravíš v Korpuse" nahradia **klikateľné rozmery v lište Náhľadu**, spodné tlačidlá stoja **v jednom riadku**, „Pripravené." zmizne, **zbalený
sektor povie obsah** („strop 2 výstuhy · boky na dne · chrbát v drážke"), súhrn „Spoločné" je čitateľný („F206 ST9 · medzera 3 · okraje 2 · dole -20")
a **kóty majú vždy 11 px** na obrazovke (aj pri vysokej skrinke a pri zoome), bez „mm". **Nič sa nepočíta inak, žiadny údaj nezmizne** (mockup časť G).

**Očakávaná úspora výšky** (odhad z mockupu prepočítaný na O1 B · O2 A · O3 B; presne zmeria R0/T7 cez `ui_foto` — výška obsahu „long" fotky):

| Kontext | Čo zmizne | ≈ px |
|---|---|---|
| Korpus | nápoveda gest 20 · „Rozmery" 22 · veta spotrebiča 17 · veta materiálov 21 · tlačidlá v 1 riadku 39 · „Pripravené." 40 | **≈ 160** |
| Čelá | nápoveda 20 · pás 50 · tlačidlá 39 · status 40 | **≈ 150** |
| Zóny | nápoveda 2 riadky 30 · obrysy zón 22 · pás 50 · nápoveda stromu 33 · tlačidlá 39 · status 40 | **≈ 215** |
| Kovanie | nápoveda 20 · pás 50 · tlačidlá 39 · status 40 (+ 30–55 pri otvorenej skupine) | **≈ 150** |
| Bez výberu | nápoveda 20 · status 40 | **≈ 60** |

## 2 · Rez a odhad — **tri časti, sekvenčne z čerstvého `main`, každá samostatný PR** (D1)

| Časť | Obsah (body Michala) | Kód pluginu (+/−) | Testy | Predrecenzia | Odhad |
|---|---|---|---|---|---|
| **H6a · nápovedy, spodok, status (D-01 bez pásu + CS-10)** | O1 B, O2 A, O3 B, O4, O5 (všetky „?"), O8, O13; veta „klik na značku…" z kresby do „?" | ~+150 / −90 | ~250 | **nie** (< 300, žiadny nový ovládací prvok — §5) | ½ dňa |
| **H6b · lišty sektorov a súhrny (D-05 + pás D-01)** | O6, O7, O9 (súhrn do lišty, z kresby preč, rezerva len na nohy), O12, skupinové meta Kovania | ~+230 / −90 | ~350 | **podľa skutočného diffu** (odhad ~320 → pravdepodobne áno) | ¾ dňa |
| **H6c · kóty náhľadu (D-02)** | O10, O11 + texty náhľadu mimo mockupu (S17) + mŕtva vetva (S24) | ~+260 / −110 | ~400 | **áno** (> 300) | ¾–1 deň |

Poradie **a → b → c**: H6a je čisto presun textov a CSS (najmenšie riziko), H6b pridáva čisté funkcie súhrnov, H6c mení kreslenie. Každá časť sama osebe je
hotový stav (žiadne dočasné dvojité údaje okrem jedného: medzi H6a a H6b ostáva v kresbe Kovania súhrn položiek — veta „klik na značku…" už nie).

## 3 · Scope IN

1. **H6a:** `panel.html` (spodný blok, `#status`, legend Rozmery, `.pvhint` → „?" v `.pvbar`, `.zoneline` preč, „?" v hlavičkách Štruktúra zón / Položky /
   Sety / Pravidlá a v lište Materiály), `panel.css`, `shell.js` (`pvHelpText`, zánik synchra `zonesChk`), `actions.js` (zánik `toggleZones`), `bridge.js`
   (`setStatus`), `materials.js`, `appliance_row.js`, `preview.js` (len riadok vety o značkách), `rules.js` (CS-10), komentár `panel.rb:149–152`.
2. **H6b:** `panel.html` (statický odkaz v lište S1, `#ctxNote` preč, `.ghdr` + meta skupín Kovania), `panel.css`, `shell.js` (`sectorVis.link`,
   `sectorMeta` s `s1link` a obsahovým S4, zánik `metaGroups`/`nxMetaGroups`), `bridge.js` (`renderCtxNote` → titulok odkazu), `core.js`
   (`cabfrontMetaText` O7), `form.js` (meta hooky, `title` dekoru), `hardware.js` (meta Položky/Sety), `actions.js` (hook stromu zón), `preview.js`
   (`drawHwBase` bez textov, rezerva Kovania).
3. **H6c:** `preview.js` (px model kót, všetky texty náhľadu, prekreslenie po zoome a zmene veľkosti), prípadne `boot.js` (registrácia pozorovateľa veľkosti).
4. Fixtúry/golden R0, guardy, mutácie, fotky, dokumentácia §11 — v každej časti jej diel.

## 4 · Scope OUT

- **Dáta, payloady `NX.init`/`NX.loadSelected`, Ruby logika, výpočty, exporty** — nič. Serverový text spotrebiča (`appliance_expects_text`) ostáva.
- **Štúdio** okrem jednej vety CS-10 v Pravidlách (O13) — `#status` Štúdia s „Pripravené." ostáva (O2 platí pre Inspector, §14 F5).
- Hlavička `#idbar`/`setIdbar` (O1 B — žiadne ikony v hlavičke), pätka a `#verline` (O3 B), rail a okno tagov (O8 len odoberá druhý ovládač).
- Karta dielca a dosky (`#partSvg`, `#boardSvg` — vlastný pevný `viewBox`, písmo ~14 px), modály, vkladacia karta okrem legendy Rozmery.
- Ostatné pomocné `.hint` mimo mockupu (§14 F2, F3), terminológia „Spodná skrinka" (§14 F1 — výrobná hranica).
- Zmena textov stavových viet a ich trvania (zelená veta ostáva, kým nepríde ďalšia — ako dnes).

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: NIE** (hranice 1.10.2026): mení sa rozloženie, popisky, súhrny v lištách a písmo kót; žiadny vzorec, rozmer, počet, hrana, `row_key`,
  export ani číslo, podľa ktorého sa objednáva či cenotvorí. Súhrny sú **popisný čítací text** zo živého stavu panela (precedens `rows_with_roles`); súhrn
  kovania v lište je ten istý `nxHwSummary`, aký dnes kreslí náhľad.
- **Audit návrhu: NIE** — žiadny dátový kontrakt, schéma, migrácia, observer/undo ani nový modul (H6c ostáva v `preview.js`).
- **Nový ovládací prvok: NIE** v žiadnej časti — „?" nič nespúšťa ani nezapisuje; odkaz v lište Náhľadu je **presun** existujúceho `#ctxNoteLink` s tou istou
  akciou (`setViewContext('korpus')`); tlačidlá kópie a šablóny sa len preusporiadajú (rovnaká akcia); checkbox obrysov sa **odoberá**.
- **Predrecenzia:** H6a **nie** (< 300 riadkov kódu pluginu); H6b **povinná, ak `git diff main...HEAD --stat` kódu pluginu (bez testov a docs) > 300** —
  orchestrátor rozhodne podľa skutočného čísla; H6c **áno** (> 300).
- **In-SU: nie je brána** (žiadna časť nemení Ruby spúšťač — buildery, observery, undo, geometriu ani Ruby stranu akcií panela; Ruby sa mení len komentárom
  a verziou). Odobratý checkbox volal serverovú cestu `nx_tag_visible`, ktorá ostáva a používa ju rail (`run_d27` v plnej sade).
- **Fotky okien: povinné** v každej časti — `-Shoot` na čerstvom `main` pred časťou a na hlave vetvy po nej (5 fotiek Inspectora: bez výberu, Korpus, Zóny,
  Čelá, Kovanie; H6a aj Štúdio → Pravidlá). Payload z Ruby sa nemení → `-Record` netreba (keď úspešná nahrávka ešte nie je, začať `-Record`).
- **Kvóty:** pred štartom každej časti `usage` (pravidlá CLAUDE.md „Kvóty").

### 5.1 Závislosti — overiť proti mainu pred každou časťou

- **H7** (názov zákazky) mení Štúdio (hlavička, lišta Kusovníka) — s H6 sa stretne len v `?v=` a v `studio.html` (O13 mení `rules.js`). Slovo „projekt" v H6
  textoch („dediť z projektu", „podľa projektu") je **projektová predvoľba**, nie názov zákazky — H7 O9 sa ich netýka.
- **H12d** (karta dielca) — bez kolízie. **H14** (register Štúdia, v maine) — bez kolízie.
- Ak medzi časťami pribudne v `panel.html` nový `.hint` alebo text v náhľade, časť ho zaradí podľa pravidla §1 (pomocný → „?", stavový → viditeľný).

---

## 6 · Požiadavky

### H6a · nápovedy, spodok, status

**R0 · Inventár pomocných textov (1. commit, zelený na starom kóde)**
- **R0.1** Fixtúra `tests/fixtures/h6_texty.json`: doslovné pomocné vety, ktoré H6a presúva — `pvhint` (3 časti: zóny, čelá, gestá), veta „klik na značku…"
  (`preview.js:1279`), nápoveda stromu zón, nápovedy Položky/Sety/Pravidlá Kovania (text bez HTML, ikona → slovo podľa D15), veta materiálov s výberom
  (`materials.js:18`), prázdne očakávanie spotrebiča (server), veta CS-10 (`rules.js:684–685`). Pri každej `kind: "help"`. Zvlášť zoznam **stavových viet,
  ktoré ostávajú viditeľné** (`kind: "status"`): „Označ skrinku pre nastavenie jej materiálov.", „očakáva …" (neprázdne), `.rgbad`, `#cabBackNote`,
  `#frontDraftMessage`. Fixtúru nevyrába generátor z nového kódu.
- **R0.2** Test `tests/pure/test_h6a_texty.rb` (+ JS časť v `tests/js/test_h6a_texty.js` pre texty skladané v JS): **každá pomocná veta je v Inspectore
  dosiahnuteľná** — v statickom HTML/JS ako text riadku **alebo** v `data-tip`/výstupe čistej funkcie nápovedy. Zelený pred aj po (invariant „žiadny údaj nezmizne").

**R1 · Spodný blok (O1 B)** — tlačidlá `.insertmore` a `.savetpl` (`panel.html:914`, `:916`) v jednom `<div class="cabacts">`: dve `ghostbtn` rovnakej šírky (`flex: 1 1 0`, medzera 6 px),
ikony `copy`/`star` ostávajú, texty **„Vložiť kópiu"** a **„Uložiť šablónu"**; `onclick` bez zmeny (`insertCopySelected()`, `openSaveTemplateModal()`),
`title` kópie bez zmeny, šablóna dostane `title` „Uloží označenú skrinku ako šablónu do knižnice". Viditeľnosť **len `body.mode-cab`** (pravidlo presunuté
z `.insertmore`/`.savetpl` na `.cabacts`, scopnuté `.nx-inspector`). Na šírke 470 px sa obe zmestia bez zalomenia (overí fotka).

**R2 · Stavová veta (O2 A)** — `<div id="status" hidden></div>` (bez „Pripravené."). `NX.setStatus(msg, err)`: `textContent = msg`, trieda `ok/err`,
`hidden = String(msg == null ? '' : msg).trim() === ''`. CSS poistka `.nx-inspector #status[hidden] { display: none; }` (pasca D-137). Ruby `set_status`
bez zmeny; `NX.setStatus('')` (`hardware.js:1533`) vetu schová. Štúdio sa nemení.

**R3 · Pätka (O3 B)** — `footer.nxfoot` a `#verline` bez zmeny (guard, že ostali).

**R4 · Nadpis „Rozmery" (O4)** — CSS `.nx-inspector body.mode-cab #basicCard > legend { display: none; }`; vo vkladaní ostáva. HTML bez zmeny.

**R5 · „?" pod náhľadom (O5)** — `.pvhint` zaniká (HTML + CSS :550, :2205–2217). V `.pvbar` za `.pvsp` a **pred** `#pvCam` statické
`<button type="button" class="nxtip r" id="pvHelp" aria-label="Pomoc k náhľadu" onclick="nxTipStop(event)">` s ikonou `help-circle`. Text `data-tip`
skladá čistá **`NXShell.pvHelpText(mode, ctx)`** a nasadzuje ho `nxShellApply` cez `setAttribute` (žiadny `innerHTML`, S25):

| Stav | Text |
|---|---|
| `part` (dielec — náhľad je zónový) alebo `cab` + `zony` | „Klik na zónu = výber (police, delenie) · ťahaj priečku = posun (magnet 1/4 · 1/2 · 3/4, Alt ho vypne) · Ctrl+koliesko = zoom · ťahaj plochu = posun pohľadu" |
| `cab` + `cela` | „Klik na čelo = jeho riadok v zozname · Ctrl+koliesko = zoom · ťahaj plochu = posun pohľadu" |
| `cab` + `kovanie` | „Klik na značku = označí vlastníka v modeli · pozície sú orientačné · Ctrl+koliesko = zoom · ťahaj plochu = posun pohľadu" |
| ostatné (`cab`+`korpus`, `insert`, `board`) | „Ctrl+koliesko = zoom · ťahaj plochu = posun pohľadu" |

Veta „klik na značku…" zaniká z kresby (`preview.js:1279`, jeden `pvText`); rezerva scény Kovania sa v H6a nemení (rieši H6b R5).

**R6 · „?" v hlavičkách skupín (O5)** — `<summary>` skupín **Štruktúra zón**, **Položky z pravidiel**, **Sety**, **Pravidlá** dostane `class="ghdr"`
a `<span class="gtools">` s `<button type="button" class="nxtip r" aria-label="Pomoc" data-tip="…" onclick="nxTipStop(event)">` (vzor `panel.html:659`);
`.hint` z tela týchto skupín zaniká. **Názov skupiny ostáva priamym textom `<summary>`** (pravidlo `NXShell.groupTitle`, ui-lifecycle „Sektory"). Texty doslovne
podľa R0.1 (Položky: D15). Do `.gtools` Kovania pribudne v H6b `.meta`; H6a nechá miesto (prázdny `.meta` sa nepridáva).

**R7 · Materiály (mockup bod 7)** — v lište S3 za `#s3Meta` statické `<button type="button" class="nxtip r" id="s3Help" aria-label="Pomoc"
data-tip="Materiály tejto skrinky — prázdne = dediť z projektu." onclick="nxTipStop(event)">`, viditeľné **len `body.mode-cab`**
(`.nx-inspector body:not(.mode-cab) #s3Help { display: none; }`). `#cabMatHint`: pri `on` (označená skrinka) `hidden = true`, bez výberu text „Označ skrinku pre
nastavenie jej materiálov." a `hidden = false` (stavová veta). `materials.js:18–19` a `:33` upravia aj `hidden`.

**R8 · Spotrebič (mockup bod 6)** — `aprRowHtml` vetva `expects`: keď `(r.expects || []).length === 0`, namiesto `<span class="aptxt soft">` sa vykreslí
`<button type="button" class="nxtip inl r" aria-label="Pomoc" data-tip="<aprEsc(r.text)>" onclick="nxTipStop(event)">` + ikona; pri neprázdnom zozname ostáva
`.aptxt` s „očakáva …" (stav). Payload ani Ruby sa nemenia (D4). Platí aj pre riadok v karte dosky (rovnaká funkcia).

**R9 · Obrysy zón (O8)** — `.zoneline` s `#zonesChk` zaniká (HTML :121–127 + komentár), `toggleZones` (`actions.js:482–492`) zaniká, blok `zonesChk`
v `nxApplyTags` (`shell.js:1017–1023`) zaniká, CSS `.zoneline` (:602–604, :1173, :1513) zaniká, komentár `panel.rb:149–152` povie „okno tagov v raile".
Server (`nx_tag_visible`, whitelist, guard dokumentu) bez zmeny. Žiadny iný kód `zonesChk` nečíta (Grep v DoD).

**R10 · Pravidlá kovania v Štúdiu (O13, CS-10)** — v `rdGuardHtml` (`rules.js:649–686`) veta „Platí pre dvierka. Hmotnostné pásma iba upozorňujú — počet
závesov riadi tabuľka výšok. Prázdne pole = kontrola je vypnutá." zaniká ako `.hint` a ide do `<summary>` bloku „Kontroly dvierok" ako `.studio .nxtip`
(`<button type="button" class="nxtip" aria-label="Pomoc" data-tip="…" onclick="event.preventDefault();event.stopPropagation()">` + `help-circle`, vzor
`ssTip`); `.rgsum` a `ontoggle` bez zmeny; `.hint.rgbad` ostáva viditeľná. Ostatné `.hint` v `rules.js` sa nemenia (D12).

### H6b · lišty sektorov a súhrny

**R0 · Charakterizácia (1. commit, zelená na starom kóde)** — golden `tests/fixtures/h6b_suhrny.json` z dnešných čistých funkcií nad 8 stavmi (spodná
800×864×520 s 100, horná, vysoká 2100, rohová vľavo 450, umývačka 60, neúplné rozmery, materiál dedený, prázdne kovanie): výstupy **`metaDims`** (S2) a
**`nxHwSummary`**. Test `tests/js/test_h6b_suhrny.js` ich prepočíta — **tieto funkcie sa v H6b nemenia** a lišta S1 a S4 Kovania ich len znovu použijú
(R1, R2). Fixtúru nevyrába nový kód.

**R1 · Rozmery v lište Náhľadu namiesto pásu (O6)**
- **R1.1** `#ctxNote` (HTML :450–457) a CSS `.ctxnote`/`.ctxlink` (:1495–1504) zaniknú. Do `<summary>` sektora S1 za `#s1Meta` pribudne statický
  `<button type="button" class="metalink" id="s1Link" hidden data-nx-usage="ctx:korpus" onclick="nxS1Link(event)"><span id="s1LinkTxt"></span><svg class="ic"
  aria-hidden="true"><use href="#i-arrow-right"/></svg></button>`. `nxS1Link(ev)` = `nxTipStop(ev)` + `setViewContext('korpus')` (ten istý guard ako rail).
  Kľúč merača `ctx:korpus` ostáva (kontinuita štatistiky).
- **R1.2** `NXShell.sectorVis(mode, ctx)` vráti `{ basic, mat, link }` (kľúč `note` → `link`, rovnaká matica). `NXShell.sectorMeta` vráti navyše
  **`s1link`** = `metaDims(dims)` (tá istá funkcia a vstup ako S2), **len** pri `mode = cab` a `ctx ∈ {zony, cela, kovanie}`, inak `''`. `s1` ostáva názov
  projekcie (fallback). `nxSectorMetaApply`: pri neprázdnom `s1link` `#s1Link.hidden = false`, `#s1LinkTxt.textContent = s1link`, `#s1Meta.hidden = true`;
  inak naopak. Žiadny `innerHTML` (S25).
- **R1.3** Bublina = `title` aj `aria-label` odkazu: **`NXShell.s1LinkTitle(material)`** → „Materiál korpusu: <popis> — klik otvorí kontext Korpus"
  (bez materiálu „… dekor dedí z projektu …"). Dáta ostávajú v `bridge.js` (`ctxNoteSrc` s `material_id`, preklad až pri kreslení `renderCtxNote`, volanie
  v `NX.setMaterials`) — mení sa len cieľ (titulok odkazu namiesto riadku); `nxSetCtxNote` → `nxSetS1LinkTitle`. `NXShell.ctxNoteText` zaniká.
- **R1.4** CSS `.nx-inspector .sect > .secthead .metalink`: `margin-left: auto`, bez rámika a pozadia, farba `--nx-select`, podčiarknutie pri hoveri,
  `min-width: 0`, text `#s1LinkTxt` s elipsou (ikona mimo elipsy), fokus `outline 2px --nx-select`; tokeny, žiadny hex. Poistka
  `.nx-inspector .sect > .secthead [hidden] { display: none; }` (pasca D-137 — `display` pravidlo by prebilo `hidden`).

**R2 · Lišta S4 = vždy súhrn obsahu (O12, D-05)** — `metaGroups` a `nxMetaGroups` zaniknú; `NXShell.sectorMeta` dostane vstup `content` (zbiera ho DOM obal,
skladajú čisté funkcie, nič sa necachuje) a `s4` = podľa kontextu (dielec/doska `''` ako dnes):

| Kontext | Text | Zdroj (živý stav) | Pravidlá |
|---|---|---|---|
| Korpus | „strop 2 výstuhy · boky na dne · chrbát v drážke" | hodnoty selectov `top_mode`, `bottom_mode`, `back_mode` | slová: `full` plný strop · `two_rails` strop 2 výstuhy · `none` bez stropu · `under_sides` boky na dne · `between_sides` dno medzi bokmi · `overlay` chrbát naložený · `inset` chrbát vložený · `groove` chrbát v drážke · `rails` chrbát z líšt · `none` bez chrbta; neznáma hodnota = časť vypadne; typ bez korpusu (`!NXTypes.carcass`) = `''` (D6) |
| Zóny | „1 zóna · prázdna" / „2 zóny · 3 police" | `computeZones()` — listy (bez `deep`) a súčet `shelves` | 1 zóna / 2–4 zóny / 5+ zón · `shelfWord`; 1 list bez políc = „1 zóna · prázdna"; viac listov bez políc = len počet zón |
| Čelá | „1 čelo · F206 ST9 · medzera 3 · okraje 2" | počet a „bez smeru" **tou istou cestou ako `updateFrontMeta`** (vytiahnuť do čistej `frontCountText(n, unset)`) + `cabfrontMetaText` (R3) | 0 čiel = „bez čiel" (D6) |
| Kovanie | „Nohy 4× · Výsuv 1× · Príchyt sokla 1×" | `nxHwSummary(hwItems)` | `hwItems === null` = `''`; prázdne pole = „bez kovania" (D6) |

**R3 · „Spoločné pre skrinku" (O7)** — `cabfrontMetaText(decor, g, opts)`: dekor = **prvé dve slová** názvu (`cabfrontDecorShort`, bez elipsy; prázdny dekor
vypadne), `medzera <mmLabel(gap)>`, okraje: všetky štyri rovnaké → `okraje <v>`; inak základ = najčastejšia hodnota (zhoda počtu → prvá v poradí hore, dole,
vľavo, vpravo) a za ňou výnimky `· <strana> <v>` v tom istom poradí („okraje 2 · dole -20"); keď je každá hodnota iná → „hore 2 · dole -20 · vľavo 0 ·
vpravo 1". Čísla `mmLabel` (ako v poli, D7). Pri slote (`opts.slot`) vypadne `medzera` aj `dole` (polia sú skryté, server ich drží na 0 — D6). `g == null` = `''`.
`#cabfrontMeta` dostane `title` = celý názov dekoru (bez dekoru `title` zmizne). `CABFRONT_DECOR_MAX` zaniká.

**R4 · Meta skupín Kovania** — `.gtools` z H6a R6 dostanú `<span class="meta" id="hwItemsMeta">` a `id="hwSetsMeta"`; plní `renderHardware` čistými funkciami
v `hardware.js` (export pre Node):
- **Položky:** súčet `max(0, parseInt(quantity))` cez `hwItems` → „6 ks"; pri `hwManualView.length = m > 0` navyše „ · m ručne" (D14); bez skrinky `''`.
- **Sety:** počet typov so skrinkovým výberom (`override_set_id` alebo `override_selector`) + počet výberov pri čele (`owner_overrides` — implementátor overí
  tvar na payloade) → „1 vlastný / 2–4 vlastné / 5+ vlastných", inak „podľa projektu"; prázdna ponuka `''` (D13).
- Skupina **Pravidlá** meta nemá.

**R5 · Kresba Kovania bez textov (O9)** — `drawHwBase` nekreslí súhrn ani náhradnú vetu „Skrinka zatiaľ nemá kovanie"; rezerva scény `hw` = len to, čo kreslí
(nohy pod korpusom pri `fh = 0`: `min(0, najnižšia značka)`), nie −96 mm. Kresba sa tým zväčší (fotka). Súhrn je v lište (R2).

**R6 · Živá obnova** — `nxSectorMetaApply()` sa volá aj na konci `renderZoneTree`/`refreshZoneUI`, `renderHardware`, `updateFrontMeta`,
`updateCabfrontMeta` (typeof guard); `NX_META_FIELDS` + `top_mode`, `bottom_mode`, `back_mode`, `fr_gap`, `fr_gap_top`, `fr_gap_bottom`, `fr_gap_left`,
`fr_gap_right`. Push (`NX.loadSelected` → `setUiMode` → `nxShellApply`) už obnovu má — dáta (`hwItems`, strom zón, `writeConstruction`) sa nastavia skôr
(overené poradie `bridge.js:683–759`).

### H6c · kóty náhľadu

**R0 · Golden kót (1. commit, zelený na starom kóde)** — generátor `tests/fixtures/h6c_koty/generate.js` (ručne, vzor `kova_golden`) vykreslí nad starým
kódom 12 prípadov (Korpus: spodná, horná, vysoká 2100, rohová vľavo/vpravo, umývačka; Čelá: spodná 1 zásuvka, vysoká 1400 + 593, s presahom dole −20; Zóny
4 stĺpce s policami; Kovanie; vkladaná doska 2600 × 600; chladnička S1-F) a zapíše **zoznam popisov kót a textov** (`<text>` obsah) po projekciách.
Test `tests/js/test_h6c_koty.js` porovná nový výstup s goldenom po normalizácii **len** odstránením „ mm" (O11) a povolených skrátení R3 (dlhý → krátky popis
je zapísaný v goldene ako pár). **Žiadna kóta nesmie pribudnúť ani zmiznúť** (okrem mŕtvej vetvy S24, ktorá sa v goldene neobjaví).

**R1 · Px model scény** — konštanty v `preview.js`: `DIM_FONT_PX = 11`, `DIM_GAP_FONT_PX = 10`, `DIM_TICK_PX = 4`, `DIM_OFF_PX = 18` (vodorovná kóta pod
obrysom) a `20` (zvislá vedľa), `DIM_TXT_PX = 5` (text nad vodorovnou čiarou) a `9` (stred textu vedľa zvislej), `DIM_ROW_PX = 18` (druhý rad — rohová),
`PV_PAD_PX = 6`. `DIM_EXT`, `DIM_TOP`, `DIM_DEPTH_OFF`, `PV_CORNER_DIM_Z`, `PV_CORNER_WIDTH_Z` zaniknú (mm → px). `PV_PAD` (mm, posun súradníc pre ťahanie
priečky) ostáva.
- **R1.1** Čistá **`nxDimScene(content, margins, rect)`**: `content` = rozsah obsahu v mm (dnešný `sceneSize` **bez** rezerv kót: korpus, čelá a ich presahy,
  skosenie hĺbky, slot, chladnička `nxRefExtent`, nohy), `margins = {l, r, t, b}` v px podľa projekcie, `rect = {w, h}` px. Mierka
  `s = min((w − 2·PAD − l − r) / cw, (h − 2·PAD − t − b) / ch)`, scéna = obsah rozšírený o `(m + PAD) / s` na každej strane. Pri `meet` má výsledný `viewBox`
  presne mierku `s` (dôkaz v teste: `min(w / vb.w, h / vb.h) = s`). Neplatné/≤ 0 → `s` = 0,05 (scéna sa nezrúti).
- **R1.2** Okraje (px): Korpus/vkladanie `l 46 · r 40 · t 30 (pri skosení) · b 28` (+18 pri rohovej) · Čelá `l 34 · r 40 · t 8 · b 28` · Zóny `b 28` len pri
  1 < stĺpcoch ≤ 8 · Kovanie 0 · doska `r 40 · b 28` · slot ako Korpus. `sceneSize()` = `nxDimScene(...)` s `rect` z R1.3; zoom limity (`base.w / 8 … ×3`)
  ostávajú nad touto scénou.
- **R1.3** `rect` = `svg.getBoundingClientRect()`; keď `w < 50` alebo `h < 50` (zbalený S1, skrytý panel, Node) → **referencia 404 × 323** (okno 850 px, D8).
- **R1.4** Mierka pri kreslení = `min(rect.w / pvView.w, rect.h / pvView.h)` (rovnaká ako `viewMapping`) — pri zoome iná než pri fite; všetky px veličiny kót
  sa prevádzajú `px / s` práve touto mierkou.

**R2 · Kóty v px** — `pvDimH/pvDimV/pvText` berú veľkosť v **px** (prevod `/ s` vnútri): `font-size = 11 / s` (medzery Čiel 10 / s), čiara `stroke-width="1"`
s `vector-effect="non-scaling-stroke"`, značky ±4 px, text 5 px nad / 9 px vedľa. Poloha kótovacích čiar: vodorovná `DIM_OFF_PX` pod **najnižším kresleným
prvkom projekcie** (obrys aj čelá s presahom — D11), zvislá `DIM_OFF_PX` vpravo/vľavo od obrysu, hĺbka `12 px` nad skosením, rohová: rad 1 (dverová časť, CR 1)
`18 px` pod skrinkou, šírka o `DIM_ROW_PX` nižšie.

**R3 · Zmestí sa? (O10)** — čistá `pvFitLabel(lenPx, labels, fontPx)`; šírka textu = `0,56 · font · počet znakov` (D10):
- zvislá kóta: dlhý popis („V 864", „sokel 100", „telo 764") → krátky (len číslo) → keď ani ten, **číslo vodorovne vedľa kóty** (vľavo od ľavých kót, vpravo
  od pravých, stred výšky); vodorovná: dlhý → krátky, text vždy nad čiarou (D9);
- popis čela: „F1 · zásuvka 760" → „F1 · 760" → „F1"; pri výške panela < 12 px popis nie je; halo (`paint-order`) ostáva;
- čísla medzier Čiel 10 px vpravo zarovnané 6 px vľavo od otvoru, **bez prekryvu** (zoradené podľa výšky, rozostup ≥ 11 px — vzor mockupu);
- popis zóny „764×646" 11 px len keď sa zmestí (`šírka textu ≤ šírka zóny v px − 4` a výška zóny ≥ 13 px).

**R4 · Bez „mm" (O11)** — „Š 800", „V 864", „H 520", „sokel 100", „telo 764"; ostatné kóty sú čísla. Mŕtva vetva „hĺbka … mm" (S24) zaniká.

**R5 · Ostatné texty náhľadu (S17, D-02 „každá kóta")** — `drawSlotDetail` (kóty), `drawApplianceRefs`/`drawApplianceSplit` (čísla pásiem, hranice,
„hrana NNN"; odsadenia 4/6/16 mm → px), „Čelá: nastav v sekcii Čelá", „F1 · bez čela 760", vkladaná doska (kóty a „bez smeru dekoru", `pvBoardFont`
zaniká) → 11 px tým istým modelom. Symboly v kresbe („?" v značke závesu a v čele, `hwMarkSvg`, `drawFrontSymbols`) sú geometria — **nemenia sa**.

**R6 · Prekreslenie (O10)** — (1) **Ctrl+koliesko:** po zmene `viewBox` sa naplánuje `renderPreview()` cez `requestAnimationFrame` (najviac raz za snímku;
fallback `setTimeout 16`); (2) **zmena veľkosti** `#preview` (okno, rozbalenie S1): `ResizeObserver` na `#preview` → to isté naplánovanie, len keď sa šírka
alebo výška zmenila o ≥ 1 px a obe sú ≥ 50 (bez `ResizeObserver` — Node — sa nič neregistruje); (3) **posun** (pan) mierku nemení → bez prekreslenia.
Prekreslenie počas ťahania priečky (`divDrag`) sa neplánuje (ťahanie si kreslí samo). Hover zvýraznenie po prekreslení zanikne (dnešné správanie `renderPreview`).

**R7 · Nič sa neoreže** — pre všetky prípady R0 × `rect ∈ {404 × 210, 404 × 323, 404 × 640, 300 × 323}` leží odhadnutý obdĺžnik každého `<text>`
(šírka R3, výška = font) **vnútri `viewBox`** (fit) a `font-size · s ∈ [10,99; 11,01]` (medzery 10 ± 0,01).

---

## 7 · Testy a DoD

**Spoločné:** `ruby tests/run_all.rb` + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + `ruby scripts/encoding_guard.rb --repo`.
**PR vypíše každý prepísaný assert z §0.2 a jeho náhradu** (nemazať, nahradiť ekvivalentom).

### H6a
- **T0** R0 (`test_h6a_texty.rb`/`.js`) zelený v 1. commite a bez zmeny fixtúry do konca.
- **T1** HTML guard (vzor `test_d130a_zoznam_ciel.rb:99–116`): v skupinách Štruktúra zón, Položky, Sety, Pravidlá **0× `class="hint"`**; v `panel.html` nie je
  `pvhint`, `zoneline`, `zonesChk`, „Pripravené."; `#status` má `hidden`; `.cabacts` obsahuje práve dve tlačidlá s `insertCopySelected()` a
  `openSaveTemplateModal()` a textami „Vložiť kópiu" / „Uložiť šablónu"; každé nové `.nxtip` má `aria-label`, `data-tip` (okrem `#pvHelp`) a `nxTipStop`;
  `footer.nxfoot` + `#verline` existujú; CSS: `.cabacts` len `mode-cab`, `#status[hidden]`, legenda `#basicCard` skrytá len `mode-cab`, `#s3Help` len `mode-cab`.
- **T2** Node: `NXShell.pvHelpText` — matica 4 režimy × 5 kontextov (vrátane `part` = zónový text, neznámy kontext = Korpus); `nxShellApply` nasadí `data-tip`
  na `#pvHelp` (mini-DOM, vzor `test_uib1_kostra.js`).
- **T3** `NX.setStatus`: `''`, `'  '`, `null` → `hidden`; text → viditeľný, trieda `ok/err`; Štúdio `setStatus` nedotknuté (Grep).
- **T4** `aprRowHtml`: `expects: []` → `.nxtip` s `data-tip` = text servera a **žiadne** `.aptxt`; `expects: ['oven']` → `.aptxt` „očakáva rúru" ako dnes.
- **T5** `materials.js`: s výberom `#cabMatHint.hidden`, bez výberu viditeľná stavová veta.
- **T6** `rules.js`: `rdGuardHtml` má v `<summary>` `.nxtip` s vetou CS-10 a v tele žiadny `.hint` okrem `.rgbad`; `test_kovf2_editor_zavesy.js:279` zelený.
- **T7** `test_d27_tagy.rb` prepis: `toggleZones` ani `zonesChk` v `ui/` nie sú; `nx_tag_visible` a guardy servera ostávajú; okno tagov ponúka kľúč `zony`.
- **Mutácie (PR priloží beh každej):** M1 späť `<div class="pvhint">` → T1 · M2 `#status` bez `hidden` v HTML → T1 · M3 `setStatus` bez skrytia prázdnej → T3 ·
  M4 `.cabacts` viditeľné aj vo vkladaní → T1 · M5 `pvHelpText` pre `part` vráti základ → T2 · M6 `.hint` späť v Sety → T1 · M7 text tooltipu Pravidiel
  zmenený o slovo → T0 · M8 `aprRowHtml` zahodí prázdny text (žiadny tooltip) → T0, T4 · M9 `nxApplyTags` znovu číta `zonesChk` → T7 · M10 veta materiálov
  skrytá aj bez výberu → T5.

### H6b
- **T0** R0 golden `metaDims`/`nxHwSummary` bez zmeny.
- **T1** `sectorVis` matica s `link` (prepis `test_uib1_kostra.js:140–173`); `sectorMeta.s1link` = `s2` pre `cab` × {zony, cela, kovanie}, `''` inde; rohová
  „… · dvere vľavo 450" aj v `s1link`.
- **T2** S4 súhrny: Korpus všetky kombinácie 3 selectov (3 × 2 × 5) + neznáma hodnota + slot; Zóny (1 prázdna, 1 s policou, 2/5 zón, 0 políc / 1 / 3 / 5);
  Čelá (0, 1, 2 čelá, „bez smeru"); Kovanie (`null`, `[]`, 3 typy); **otvorená skupina súhrn nemení** (O12) — rovnaký výstup pri `open` aj zbalenej.
- **T3** `cabfrontMetaText` O7: rovnaké okraje, jedna výnimka, 2 : 2 (prvá v poradí vyhrá), všetky rôzne, desatinné (2,5), záporné, bez dekoru, dekor 1 slovo,
  slot, `null`; DOM: `#cabfrontMeta.title` = celý dekor.
- **T4** meta Kovania: Položky (súčet, nulové a nečíselné množstvá, ručné), Sety (žiadny, 1 skrinkový, selector, výber pri čele, 5+).
- **T5** odkaz S1: statický `<button id="s1Link">` v `<summary>` S1, `data-nx-usage="ctx:korpus"`, `onclick` cez `nxTipStop` + `setViewContext('korpus')`
  (Node: klik prepne kontext a **nezbalí** sektor — `defaultPrevented`); titulok z `s1LinkTitle` po `NX.setMaterials` s premenovaným dekorom sa zmení
  (prepis testu „drží DÁTA"); `#ctxNote` v HTML/CSS/JS nie je.
- **T6** kresba Kovania: žiadny `<text>` súhrnu ani náhradnej vety; scéna `hw` bez rezervy −96 (pri `fh > 0` `minZ = 0` − padding).
- **T7** obnova: `nxSectorMetaApply()` volajú `actions.js` (strom zón), `hardware.js`, `form.js` (obe meta Čiel) — rozšírenie guardu `test_uib1_kostra.rb:177–186`;
  `NX_META_FIELDS` obsahuje 8 nových polí.
- **Mutácie:** M1 `s1link` aj v Korpuse → T1 · M2 klik odkazu bez `preventDefault` → T5 · M3 S4 pri otvorenej skupine vráti jej názov → T2 · M4 `two_rails`
  → „plný strop" → T2 · M5 Zóny rátajú aj `deep` → T2 · M6 výnimka okrajov v inom poradí → T3 · M7 elipsa dekoru späť → T3 · M8 Sety ignorujú `override_selector`
  → T4 · M9 `drawHwBase` kreslí súhrn → T6 · M10 `renderHardware` bez `nxSectorMetaApply()` → T7 · M11 `renderCtxNote` vypadne zo `setMaterials` → T5.

### H6c
- **T0** R0 golden popisov bez zmeny generátora (len normalizácia „ mm" a páry skrátení).
- **T1** `nxDimScene`: 6 rozmerov obsahu × 4 `rect` × okraje → mierka `min(w/vb.w, h/vb.h) = s` (±1e-9); neplatný vstup nezrúti scénu.
- **T2** R7 invariant (bez orezania, 11/10 px) pre všetky prípady R0 × 4 `rect`; navyše po **zoome** (`pvView` × 0,5 a × 2, `pvUserView = true`, `renderPreview`)
  `font-size · s' = 11`.
- **T3** `pvFitLabel`: dlhý / krátky / vedľa; popis čela 3 stupne + nízky panel; medzery Čiel bez prekryvu (vysoká skrinka s 5 medzerami); popis zóny sa nekreslí,
  keď sa nezmestí.
- **T4** bez „mm" v žiadnom `<text>` náhľadu (všetky prípady R0); dim `<g>` má `vector-effect="non-scaling-stroke"` a `stroke-width="1"`.
- **T5** prekreslenie: wheel s Ctrl naplánuje práve jedno prekreslenie na snímku (stub `requestAnimationFrame`), pan nenaplánuje; `ResizeObserver` stub —
  zmena 1 px prekreslí, rovnaká veľkosť nie, `w < 50` nie; ťahanie priečky nenaplánuje.
- **T6** prepisy §0.2 (`test_rohb2_nahlad.js` relatívne súradnice, `test_uib2_nahlad.js` hĺbka, `test_uic1b_vkladanie.js` doska); `test_uic1b_vkladanie.rb:133` zelený.
- **Mutácie:** M1 `font-size` bez `/ s` → T2 · M2 mierka z fitu namiesto `pvView` → T2 (zoom) · M3 okraj Korpus `l = 0` → T2 (orezanie) · M4 fallback `rect` vypnutý
  → T1/T2 (Node) · M5 „mm" späť v šírke → T4, T0 · M6 `pvFitLabel` bez „vedľa" → T3 · M7 medzery bez rozostupu → T3 · M8 wheel bez prekreslenia → T5 · M9 pan
  prekresľuje → T5 · M10 kóta šírky Čiel na pevnom −26 mm (nie pod presahom) → T2/T3 · M11 chladnička ostane v mm → T2 · M12 kóta zmizne (vynechaný `pvDimV`) → T0.

### DoD každej časti
Jej T0–T7 zelené · mutácie v PR · fotky T8 · dokumentácia §11 · PR popis: čo uvidí stolár, trieda, „Predrecenzia" (keď beží), mutácie, náhrady testov 1:1,
fotky a **namerané px** (výška obsahu „long" fotky pred/po pre 5 kontextov; H6c px kót z fotky Korpusu a Čiel).
**T8 · Fotky:** `powershell -NoProfile -File scripts\ui_foto.ps1 -Shoot` na čerstvom `main` pred časťou a na hlave vetvy po nej; porovnať kontaktné hárky;
cesty do reportu orchestrátorovi (do gitu nie). Fotka s červeným pásom = chyba prehrania → oprava, nie tichá fotka.

## 8 · In-SU — nie je brána

Žiadna časť nemení Ruby spúšťač (§5). `run_su_tests.ps1` sa ako brána nespúšťa; `run_uib1`, `run_uib2`, `run_d27` ostávajú v plnej sade (nepripínajú dotknuté
texty — §0.2). Ručné overenie v SketchUpe je smoke §10. Ak by implementácia predsa zmenila Ruby mimo komentára (napr. payload), **trieda sa prehodnotí**
(fotky `-Record`, in-SU podľa spúšťača) a orchestrátor sa to dozvie pred PR.

## 9 · Riziká

- **H6a:** stratený pomocný text (R0 invariant) · tooltip orezaný predkom s `overflow: hidden` (lišta S3 `.meta` má elipsu — „?" je **súrodenec**, nie dieťa;
  overí fotka a smoke) · `?` v `<summary>` zbalí skupinu (T1 `nxTipStop`) · šírka dvoch tlačidiel pri 470 px (fotka).
- **H6b:** stale meta po programovej zmene (T7 + guard) · S4 pre slot/neznámy typ (D6) · odkaz v lište zbalí sektor (T5) · dlhé rozmery rohovej (elipsa, celý
  text v `title` S2 ostáva v Korpuse).
- **H6c:** orezanie kót pri malom okne alebo vysokej skrinke (R7, T2) · `getBoundingClientRect` = 0 pri zbalenom S1 (fallback + `ResizeObserver` po rozbalení) ·
  výkon prekresľovania pri koliesku (rAF, max 1 / snímka) · strata hoveru po zoome (prijaté) · odhad šírky textu 0,56 (Segoe UI 11 px) — reálne písmo sa môže
  líšiť o ±10 % → rezerva 4 px v `pvFitLabel`; fotka v headless Chrome **nie je CEF** (písmo sa môže líšiť) → smoke.
- **Zmiešané PC (Lucia):** žiadne dáta ani `%APPDATA%` sa nemenia — bez rizika.

## 10 · Smoke checklist pre Michala (testovací model, po každej časti jej body)

**Po H6a**
1. Označ dolnú skrinku → dole **jeden riadok** „Vložiť kópiu" · „Uložiť šablónu"; kópia sa vloží, „Uložiť šablónu" otvorí to isté okno ako predtým.
2. Pod panelom **nie je „Pripravené."**; zmeň šírku → zelená veta sa ukáže na konci; daj do šírky nezmysel a klikni „Vložiť kópiu" → červená veta. Pätka s verziou je.
3. Pri označenej skrinke nie je nadpis „Rozmery"; pri vkladaní (nič neoznačené) je.
4. **„?" vedľa kamery** pod náhľadom: v Korpuse, Zónach, Čelách, Kovaní a pri označenom dielci povie iné gestá; bublina sa dá otvoriť aj klávesom Tab.
5. Zóny: riadok „Zobraziť obrysy zón v modeli" nie je; rail → oko → „Zóny (obrysy)" prepína obrysy ako predtým (aj Späť).
6. „?" v hlavičkách Štruktúra zón, Položky z pravidiel, Sety, Pravidlá — klik na „?" skupinu **nezbalí**; text pod skupinami už nie je.
7. Materiály: „?" v lište (len pri označenej skrinke); pri vkladaní veta „Označ skrinku pre nastavenie jej materiálov." ostáva.
8. Spotrebič bez očakávania → „?" v riadku; nastav „očakáva rúru" → veta „očakáva rúru" je viditeľná.
9. Štúdio → Pravidlá → rozbaľ „Kontroly dvierok" → veta „Platí pre dvierka…" je v „?" v hlavičke bloku; klik na „?" blok nezbalí.

**Po H6b**
1. Zóny / Čelá / Kovanie: pás „Skrinka … upravíš v Korpuse" nie je; v lište Náhľadu „800 × 864 × 520 · sokel 100 →" — klik otvorí Korpus, bublina ukáže
   materiál korpusu; premenuj dekor v Štúdiu → Materiály a bublina povie nový názov.
2. Korpus, lišta Nastavenia: „strop 2 výstuhy · boky na dne · chrbát v drážke" (podľa skrinky); zmeň chrbát → lišta sa zmení hneď; otvor skupinu → lišta ostáva súhrn.
3. Zóny: „1 zóna · prázdna"; rozdeľ na 2 stĺpce a do jedného daj 3 police → „2 zóny · 3 police"; Späť → späť.
4. Čelá: lišta „1 čelo · F206 ST9 · medzera 3 · okraje 2"; okraj dole −20 → „… okraje 2 · dole -20" aj v „Spoločné pre skrinku"; bublina nad súhrnom = celý dekor.
5. Kovanie: lišta „Nohy 4× · Výsuv 1× · …"; kresba **bez textov a väčšia**; Položky „6 ks", Sety „podľa projektu" (po vlastnom sete „1 vlastný").
6. Rohová: lišta Náhľadu povie aj „dvere vľavo 450".

**Po H6c**
1. Spodná, horná a vysoká 2100 (Korpus): kóty **rovnako veľké ako text panela**, bez „mm", celé v okne.
2. Ctrl+koliesko priblíž a oddiaľ: písmo kót ostane rovnaké (doladí sa hneď po kroku); ťahaj plochu — kóty idú s kresbou.
3. Zmeň výšku okna Inspectora a zbaľ/rozbaľ Náhľad → kóty ostanú 11 px a celé.
4. Čelá vysokej skrinky: popis „F2 · 593", čísla medzier sa neprekrývajú; čelo s presahom dole −20 → kóta šírky je pod ním.
5. Zóny so 4 stĺpcami (kóty šírok), umývačka, rohová, vkladaná doska (kóty, „bez smeru dekoru"), chladnička v skrinke (pásma, „hrana …") — všetko čitateľné.

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** v `ui/*.html` → T0–T8 → **architektúra na mieste** (prepis odsekov, nie
dopisovanie na koniec):
- **H6a:** `docs/UI_DIZAJN.md` §1 (:75–79 — doplniť vetu „aj nápovedy gest a skupín; v Štúdiu `.studio .nxtip`") · §5.1 (:448–505 — spodný blok: tlačidlá
  v jednom riadku, status len so správou, pätka) · §5.2 Spodný pás (:572–588 — „?" vedľa kamery, text podľa kontextu) · §5.3 (:594 — legenda Rozmery len pri
  vkladaní) · §5.13 (:1447 — „Jeden stav, dva ovládače" → **jeden ovládač** v raile) · §5.10 (nápovedy skupín v „?") · `docs/architecture/ui-lifecycle.md`
  odsek „Inspector — kostra" (:358–359 checkbox zaniká; :377 pätička + status), „Náhľad" (:509–512 „?" v páse), „Kontext Kovanie", „Riadok Spotrebič",
  „Sekcia PRAVIDLÁ v Štúdiu" · `docs/architecture/construction.md:945` (dva ovládače → jeden) · komentár `panel.rb:149–152`.
- **H6b:** UI_DIZAJN §5.1 (:473–493 — meta S1 = rozmery s preklikom mimo Korpusu, S4 = súhrn obsahu, `#ctxNote` zaniká) · §5.2 tabuľka (:518 Kovanie „pod
  projekciou súhrn" → v lište) · §5.7 (súhrn „Spoločné" O7) · §5.10 (meta Položky/Sety) · §4 inventár (:326–327 `arrow-right` aj „rozmery skrinky v lište
  Náhľadu → Korpus") · ui-lifecycle „Inspector — kostra / Sektory" (:369–375), „Kontext Čelá" (:561 formát), „Kontext Kovanie", „Náhľad" (:476–481 súhrn
  položiek z kresby preč).
- **H6c:** UI_DIZAJN §5.2 (:523–526 — „kóty 11 px na obrazovke (medzery 10), čiara 1 px, bez jednotky; nezávislé od veľkosti skrinky a zoomu; dlhý popis sa
  skráti") · §3 typografia (riadok kót náhľadu) · ui-lifecycle „Náhľad" (:479–481 `sceneSize` → `nxDimScene` px okraje, prekreslenie po zoome/zmene veľkosti,
  fallback 404 × 323).
- **Grepom prehľadať tvrdenia o zoznamoch**, ktoré časť mení (`zonesChk`, `ctxNote`, `pvhint`, „všetko zbalené", „Pripravené", „jednotka len", `DIM_EXT`,
  „upravíš v Korpuse") v `docs/`, `SYSTEM/` (bez archívu) a komentároch kódu — opraviť každý výskyt. UI_DIZAJN **bez historických značiek** mimo „Histórie".
- **Prepis STAV** → **KRONIKA** odsek navrch „Záznamy dávok" → **PLAN** riadok H6 s časťami (✅ + PR) → package (a pri H6c surový výstup predrecenzie) do
  `SYSTEM/zdroje/bloky/HARDENING/` → DOGFOODING: H6 nerieši žiadne otvorené D-číslo (zdroje sú triedenie D-01/D-02/D-05) — overiť Grepom, nič nepresúvať.
- **PR popis:** čo uvidí stolár (pred/po fotky), trieda, „Predrecenzia" (H6b/H6c), mutácie, náhrady testov 1:1, namerané px. Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Tri časti** (a nápovedy/spodok · b lišty/súhrny · c kóty) namiesto dvoch | každá má iný druh rizika (CSS presuny · čisté funkcie · kreslenie); H6a+H6b spolu ~550 riadkov kódu — jeden PR by bol ťažký na review; H6a vyjde bez predrecenzie. Fallback: a+b spolu, ak orchestrátor chce menej PR | **áno** |
| D2 | „?" pod náhľadom = **jeden statický `.nxtip`**, text skladá čistá `NXShell.pvHelpText` (nie CSS prepínanie spanov) | testovateľné v Node, jeden zdroj textu, žiadny `innerHTML` | krátko |
| D3 | Skrytie prázdneho statusu scopnuté pod `.nx-inspector`; Štúdio nechá „Pripravené." | O2 hovorí o paneli; CSS `#status` zdieľa aj Štúdio | nie |
| D4 | Spotrebič riešený **len v JS** (`aprRowHtml`) — serverový text a payload bez zmeny | bez Ruby zmeny, bez `-Record`, test `test_s1b2_pohlad.rb:473` ostáva | nie |
| D5 | Odkaz v lište S1 = statický `<button>` s textom z `metaDims` (rovnaký ako S2), bublina natívny `title` + `aria-label`, ikona `arrow-right`, `sectorVis.note` → `link`, kľúč merača `ctx:korpus` ostáva | O6 „tie isté rozmery ako lišta Základné"; guard „žiadny `innerHTML` v kostre"; bublina nesie sekundárny údaj (materiál je v Korpuse) | **áno** |
| D6 | Okrajové prípady súhrnov: slot → S4 Korpus `''` a „Spoločné" bez medzery a okraja dole · 0 čiel → „bez čiel" · kovanie `[]` → „bez kovania" | nič sa nevymýšľa; slot tie polia skrýva | krátko |
| D7 | Čísla v súhrne „Spoločné" cez `mmLabel` (mínus ako v poli: „-20"), nie U+2212 z mockupu | súhrn sa číta vedľa poľa, ktoré píše „-20"; žiadny nový formátovač | krátko |
| D8 | Px model kót: uzavretá mierka s px okrajmi (`nxDimScene`), `rect` z `getBoundingClientRect`, fallback **404 × 323**, prekreslenie cez rAF po zoome a `ResizeObserver`; pan bez prekreslenia | O10 A (11 px aj pri zoome); `viewBox` ostáva v mm → ťahanie priečky a výber zóny sa nemenia | **áno** |
| D9 | Vodorovné kóty: popis vždy nad čiarou (dlhý → krátky); „vedľa" len pre zvislé | mockup definuje „vedľa" pre zvislé; vodorovné čísla sú krátke | nie |
| D10 | Šírka textu = odhad `0,56 · font · znaky` (parita s mockupom), nie meranie DOM | deterministické v Node aj v headless fotke | nie |
| D11 | Kóta šírky Čiel/Korpusu sa kladie pod **najnižší kreslený prvok** (presah čela), nie na pevné −26 mm | pri px písme by sa kóta inak prekryla s presahom; mení len polohu kóty | krátko |
| D12 | O13 = **jedna veta** (Kontroly dvierok); ostatné pomocné `.hint` v `rules.js` → §14 F3 | Michal schválil „jedna veta do ?" | nie |
| D13 | Sety: „vlastný" = skrinkový výber (`override_set_id`/`override_selector`) + výber pri čele (`owner_overrides`) | mockup „1 vlastný"; implementátor overí tvar `owner_overrides` na payloade a v PR | krátko |
| D14 | Položky: „N ks" zo súčtu `hwItems` + „· M ručne" pri ručných položkách | „súčet počtov položiek" (mockup F); ručné sú v tej istej skupine | krátko |
| D15 | Tooltip Položiek: inline ikonu `rotate-ccw` a tučné písmo nahradí text („tlačidlo so šípkou späť vráti pravidlo") | `data-tip` je čistý text | nie |
| D16 | Súhrn Zón: listy bez `deep`, súčet políc, slovné tvary 1 / 2–4 / 5+ | zhodné so stromom (`renderZoneTree`, `shelfWord`) | nie |
| D17 | `test_usage.js:118` (syntetické `zonesChk`) bez zmeny | čistá funkcia, na HTML nezávisí | nie |

## 13 · Otázky pre Michala

Žiadna otázka **neblokuje** H6 — mockup aj odpovede O1–O13 pokrývajú celý rozsah. Jedna na zaradenie mimo H6 (do odpovede platí návrh):

- **Q1 · „Spodná skrinka" vs. typ „Dolná" (F1).** V hlavičke Inspectora stojí automatický názov „Spodná skrinka 800" vedľa štítku typu „Dolná". Ten názov ide aj
  do Kusovníka a exportov, takže jeho zmena je **výrobná** (mení texty v exportoch aj starších zákaziek s automatickým názvom). **Návrh:** H6 ho nemení;
  samostatná malá dávka „Dolná skrinka 800" (s predrecenziou) po H6, alebo do zásobníka po V1 — rozhodneš ty.

## 14 · Nálezy mimo scope

- **F1 · Terminológia „Spodná/Dolná" (F3 z PACKAGE_H12 §14, Michal: „dolná").** V Inspectore: meno skrinky v hlavičke (`setIdbar` → `cabNameCellHtml`, text
  zo servera = živý predvolený názov `CabinetTypes` `auto_name: 'Spodná skrinka %{w}'`, `core/cabinet_types.rb:52`; ručný názov sa neukladá, kým je
  automatický — `sanitize_name` `cabinet_builder.rb:3116–3122`) vedľa štítku `label: 'Dolná'`. Mimo Inspectora: Kusovník (`bom.rb` číta predvolený/zobrazovaný
  názov), poznámky seedu kovania „4 ks na spodnú skrinku" (`hardware_catalog.rb:1465`, `:1926`), Pravidlá „na spodnú skrinku" (`rules_dialog.rb:81`).
  **Nepatrí do H6** — zmena mení obsah exportu (výrobná hranica). Dávka musí: zmeniť `auto_name`, rozšíriť `AUTO_NAME_RE` (`cabinet_builder.rb:150`) tak, aby
  „spodná" aj „dolná" ostali automatické, rozhodnúť seed poznámok (dáta katalógu) a zapísať pojem do `SYSTEM/POJMY.md` → Q1.
- **F2** Ďalšie pomocné `.hint` v Inspectore mimo mockupu: `#zoneSplitHint`/`#zoneShelfHint` (mix stavu a pomoci, píše `actions.js:81–101`), Vnútro
  (`panel.html:634`), `#tplHint` (vkladanie), doska vo vkladaní (`:224`), `#pcBasicHint` (dielec) — kandidáti na „?" po V1 (stavové časti ostávajú).
- **F3** `rules.js` — ďalšie pomocné `.hint` (:256 Výklopy, :749 šírkové pásma, :759 rad dĺžok, :768 úchytka) — ten istý vzor CS-10; mimo O13.
- **F4** Mŕtva vetva „hĺbka … mm" (`preview.js:1161`) — **zaniká v H6c** (R4).
- **F5** Štúdio má vlastný `#status` s „Pripravené." (`studio.html:1283`) — O2 platí pre Inspector; zjednotenie je samostatné rozhodnutie.
- **F6** CSS `.zoneline` je v `panel.css` dvakrát (:602–604 a :1173) — zanikne celé v H6a (R9).
- **F7** Zelená stavová veta ostáva viditeľná, kým nepríde ďalšia (aj hodiny) — O2 A to nemení; prípadné zhasnutie po čase = po V1.
- **F8** Karty dielca a dosky (`part_card.js:351–363`, `board_card.js:390–392`) majú pevný `viewBox` 300 × 200 a písmo 11–12 jednotiek (~14 px) — čitateľné, mimo D-02.

---

## 15 · Potvrdenie orchestrátora (2.10.2026) · MÁ PREDNOSŤ

- **§12:** D1 áno (rez **H6a → H6b → H6c**, každá samostatný PR z čerstvého mainu po mergi predchodcu) · D5 áno · D8 áno · D2, D6, D7, D11, D13, D14 áno ·
  ostatné bez výhrad. Audit návrhu netreba (UI, bez zmeny kontraktu).
- **Predrecenzia:** H6b a H6c **povinná**; H6a podľa pravidla nie (< 300 riadkov, bez nového ovládacieho prvku) — orchestrátor ju môže spustiť aj tak
  (nový model implementátora). Implementátor po pushi **STOP, PR neotvára**, kým orchestrátor nepovie.
- **Q1 (automatický názov „Spodná skrinka" vs typ „Dolná"):** mimo H6 — ide do Kusovníka a exportov (výrobná hranica) → **zásobník Po V1**, otázka pre Michala v reporte.
- **Rozhodnutia Michala** (`ROZHODNUTIA_H6_H7_2026-10-02.md`) skopíruje implementátor **H6a** ako novú sekciu na koniec `SYSTEM/zdroje/bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md`
  a mockupy `MOCKUP_H6_INSPECTOR.html` + `MOCKUP_H7_NAZOV_ZAKAZKY.html` do `SYSTEM/zdroje/bloky/HARDENING/` s rámčekom „platí" hore (odkaz na sekciu rozhodnutí
  a odchýlky O1/O2/O3 v H6). Package H6 do `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H6.md`, brief do `briefy/`.
