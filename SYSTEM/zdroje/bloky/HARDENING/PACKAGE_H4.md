# PACKAGE H4 · jazyk, čísla a vzhľad (blok 9 HARDENING PO V1) — položky triedenia D-04 · D-06 · D-07 · D-08 · D-09 · D-11

> **Autorita:** triedenie Michala 1.10.2026 ([ROZHODNUTIA_MICHALA_2026-10-01.md](ROZHODNUTIA_MICHALA_2026-10-01.md), „návrh auditu = schválený smer"); dôkazy
> v tomto priečinku: `CROSS_AUDIT_A5_*` (CU-06, CU-12–CU-14), `CROSS_AUDIT_A3_*` (CS-09, CS-11), `CROSS_AUDIT_A2_*` (GR-21, GR-23), `TRIEDENIE_krizovy_audit_v1.html`;
> register `SYSTEM/AUDIT_REGISTER.md` R-24; fotky `screenshoty/` (Chrome, nie CEF).
> **POZOR — kolízia mien:** `D-04 … D-11` sú **položky triedenia HARDENING**, nie D-čísla `SYSTEM/DOGFOODING.md` (tie isté čísla tam majú staré vyriešené postrehy).
> V commitoch, KRONIKE a PR píš „H4 · D-04 (triedenie HARDENING)"; **do `DOGFOODING_vyriesene.md` sa nič nezapisuje**.
> **Stav kódu:** sonda nad pluginom **v0.17.0** (`origin/main b2dbb3a7`; PR #432 bol len dokumentácia). **H3 v maine ešte nie je** (package H3 píše iný autor
> paralelne) — H4 štartuje **až po mergi H3** a zladí sa s ním (§5.1).
> **Rez (odporúčanie §2):** **H4a** čísla (D-04 + D-11) → **H4b** texty a vzhľad (D-06 + D-07 + D-08 + D-09), každá z čerstvého `main`.
> **Trieda (§5):** H4a **výrobná/cenová (zobrazenie)** · H4b **bežná UI dávka s novým ovládacím prvkom** — obe: **predrecenzia povinná**, **audit návrhu nie**,
> **in-SU nie**, `codex-po-pr` bez výnimky.

---

## 0 · Sonda na kóde (1.10.2026, len čítanie)

Skripty: scratchpad `HARDENING/h4/sonda_h4.js` (+`sonda_h4_out.txt`) — `require` reálnych `studio.js`, `budget.js`, `proj_materials.js`, `hw_catalog.js`,
`demos_diff.js`; `HARDENING/h4/caps.js` (+`caps_out.txt`) — reťazce UI (nie komentáre) s VEĽKÝMI slovami a žargónom. Do modelu ani repa sa nezapisovalo.
Cesty nižšie sú relatívne k `noxun_engine/`.

### 0.1 Formátovače čísel dnes (D-04) — 9 vlastných, dva s bodkou

| # | Kde | Čo robí | Výsledok sondy |
|---|---|---|---|
| F1 | `ui/js/budget.js:80-90` `budFmtEur` | peniaze: 2 desatinné, čiarka, tisíce nezalomiteľnou medzerou, mínus U+2212, „ €", null → „—" | `1323.1 → "1 323,10 €"` — **vzor pre peniaze** (testy `tests/js/test_budget_ui.js:23-27`) |
| F2 | `ui/js/budget.js:92-95` `budFmtNum(v, dec)` | pevný počet desatinných, čiarka | `(2.4,0) → "2"` · `(70.94,1) → "70,9"` · `(4,2) → "4,00"` — **skrýva desatiny aj pridáva zbytočné** |
| F3 | `ui/js/budget.js:184-189` `budNumText` | hodnota do **editovateľného poľa**, max 3 desatinné, bez € | `68 → "68"`, `382.8 → "382,8"`, `40.987 → "40,987"` |
| F4 | `ui/js/studio.js:191-193` `num(v, dec)` | Kusovník, Kontrola; čiarka, predvolene **0 desatinných** | hrúbka 18,6 = **„19"** v hlavičke skupiny (`:1552`), stĺpci „Hr." (`:1569`) a pohľade Platne (`:1671`); pohľad ABS „1,0 mm" (`:1708`), bm 1 desatinné (`:1710`) |
| F5 | `ui/js/studio.js:325-329` `edgeThShort` | hrúbka pásky v ABS stĺpci, 1 desatinné | `0.45 → "0,5"` (sonda S-c) |
| F6 | `ui/js/proj_materials.js:190` `fmtNum` | Materiály — **bodka** (`String(f)`) | `sheetChipLabel → "DTDL 18.6"`, `edgeChipLabel → "23/0.8"` (S-e) |
| F7 | `ui/js/hw_catalog.js:77-80` `mdhFmtPrice` | ceny v katalógu kovania — **bodka** | `12.5 → "12.50 €"` (S-f; test `tests/js/test_hw_catalog.js`) |
| F8 | `ui/js/demos_diff.js:153-155` `mddFmtPrice` | ceny v „Aktualizovať z Demosu" — **bodka** | `18.994 → "18.99 €"` (S-f; test `tests/js/test_demos_diff.js:132`) |
| F9 | `ui/js/rules.js:104` (a ďalšie spájania `'…' + číslo`) | holé číslo v texte | „rezerva 0.5 kg" |

S čiarkou už sú (nemenia sa): `studio_settings.js:66,230`, `hw_sets.js:95`, `sheet_layout.js:64`, Inspector `core.js:1180` `mmLabel` (zrkadlo Ruby
`Materials.fmt_mm`, `core/materials_decor.rb:2167-2174`), `core.js:1718`, `hardware.js:54`, `appliance_row.js:156`.

**Jednotky Rozpočtu:** server posiela kódy `KS · BM · PLATŇA · M2 · FIX · SET · PÁR · BAL` (`core/budget.rb:49-56`) a okno ich píše surovo:
`budget.js:814` (Materiál, stĺpec MJ „PLATŇA"), `:850` (ABS), `:860` (kovanie), `:914` (Služby: `budFmtNum(r.mnozstvo, 2) + ' ' + r.mj` → „37,26 BM", „4,00 PLATŇA",
„0,00 FIX", „23,20 M2"). Stĺpec „Medzisúčet" Služieb a Štandardných riadkov je **editovateľné pole** s `budNumText` (`:908`, `:930`) → „40,99", „68", „382,8" bez €
(potvrdené na `screenshoty/studio_04_budget_long.png`).

**Čo sa NESMIE zmeniť (pasce):**
- **XLSX rozpočtu píše `r['mj']` a `r['poznamka']` zo servera** (`core/xlsx_writer.rb:440-457` — poznámka ide do názvu položky). Kódy MJ v payloade aj poznámky
  (napr. „4 platní × 5,8 m²" z `core/budget.rb:541`) sa preto **nemenia** — preklad jednotky je len v JS. Cenová ponuka má vlastný slovník (`core/cp_export.rb:61-63`).
- **VEPO zaokrúhľuje dĺžku a šírku na celé mm** (`core/vepo_export.rb:214-216` `rounded_dims`) a hrúbku na obchodnú 18/36 (`:126-132`). Kusovník dnes ukazuje L/Š
  na celé mm = zhodne s VEPO → **ostáva**. Hrúbku ukazuje zle („19" pri 18,6) → opraví sa na skutočnú „18,6" (nie obchodnú — tú nesie VEPO).
- `budParse` (`budget.js:177-182`) berie čiarku aj medzery → pole s „68,00" sa zapíše ako 68. Udalosť `change` (`budget.js:2394-2404`) vzniká len pri úprave,
  takže iný zápis v poli sám nič nezapíše.
- `proj_materials.js:2205` plní **vstupné pole** šírky pásky cez `fmtNum` — polia sa v H4 nemenia (okrem peňažných polí Rozpočtu).

### 0.2 ABS v Kusovníku (D-11)
Bunka = `absCompact` (`studio.js:331-341`), titulok = `absFull` (`:343-352`), kreslí `partsTable` (`studio.js:1565-1566`). Sonda S-b: štyri hrany
→ `"L1:0,8 · L2:0,8 · W1:0,8 · W2:0,8"`; S-b2: **dve rôzne pásky s rovnakou hrúbkou dávajú ten istý text** — kompakt dnes identitu pásky nenesie (len titulok).
Kódy hrán sa zámerne neprekladajú na strany (`studio.js:315-321`). Testy: `tests/js/test_st1a_studio.js:143-146`.

### 0.3 „Obnoviť" a „Obnoviť zálohu" (D-06)

- **„Obnoviť" (`refresh-cw`)** = jeden zdieľaný markup `refreshBtnHtml` (`studio.js:206-211`) v 10 sekciách (Kusovník, Kontrola, Nákup, Rozpočet, Ponuka,
  Nárezový plán, Materiály, Kovanie, Pravidlá, Šablóny — `budget.js:317`, `sheet_layout.js:126`, `proj_materials.js:3896`, `hw_catalog.js:1817`, `rules.js:1232`, `templates.js:190`).
- **Materiály: „Obnoviť zálohu"** (`info`) hneď vedľa, kým existuje predmigračná záloha (`s.backup && !s.ro`, `proj_materials.js:3885-3892`; príznak `MD_HAS_BACKUP`
  z payloadu Materiálov `:3420,:3910`). V núdzovom režime banner „Obnoviť predmigračnú zálohu" (`studio.html:1050`). Potvrdenie: modal `studio.html:897-905` →
  `mdRestoreConfirm` (`proj_materials.js:2863-2867`) → `sketchup.restore_pre_schema2` → `ui/materials_dialog.rb:420-429`.
- **Nastavenia rozpočtu: „Načítať nanovo"** (`rotate-ccw`, zahodí neuložené zmeny) — `studio_settings.js:625,633`, veta `:579`.
- **Iné akcie, iné mená (ostávajú):** „Načítať globálne" v Pravidlách (`rules.js:1222-1224`, naplní formulár predvoľbami), „Prepočítať ceny" v Rozpočte (`budget.js:485`).
- **„Obnoviť" s významom „vrátiť":** Spotrebiče — vrátenie vyradeného záznamu (`appliances.js:434-436`, veta `:743`); Inspector kovanie „obnoviť" (`hardware.js:643`);
  Sety „Obnoviť z globálnych predvolieb" (`hw_sets.js:1821`).
- **Spotrebiče:** prázdny stav radí „daj Obnoviť" (`appliances.js:544`), hoci lišta sekcie Obnoviť **nemá** (`apToolsHtml` `:218-232`).

### 0.4 Žargón a VEĽKÉ písmená (D-07) — tabuľka náhrad je v R-B2 (§6)
Sonda `caps.js` našla 73 riadkov (`caps_out.txt`); ručne doplnené dva hinty, ktoré regex nechytil (`studio.js:167`, `:182`). Mimo JS sú tri texty v **Ruby**
(len zobrazenie, žiadne dáta): `core/tags.rb:47` popisok tagu „Zóny (ghost)" (meno tagu v modeli je iný údaj — `tags.rb:38-39,147`),
`ui/panel/actions_cabinet.rb:865` status „…ghost sadne…", `ui/materials_dialog.rb:428` status po obnove zálohy.
**Verzia:** „V" + verzia v `about.js:35,36,110`, `bridge.js:301` (pätička Inspectora), `studio_settings.js:519`, `hw_catalog.js:503` (uzol `hwline` v `studio.html`
**neexistuje** — mŕtvy kód); „v" v `studio.js:1023`. Testy s „V0.9.11": `tests/js/test_d52b_updater_ui.js:153,501,521`.

### 0.5 Vzhľad (D-08, D-09)
- **Rozbaľovačky:** jediné spoločné pravidlo je `.row select` (`ui/css/panel.css:95`); `select` mimo `.row` má vzhľad prehliadača. Dotknuté: „Podľa výrobcu"
  (`proj_materials.js:3881`), „Kresba čiel" (`studio.html:1105`), „Všetky kategórie" (`hw_catalog.js:1833`, `appliances.js:248`), „očakáva: —"
  (`appliance_row.js:57`, Inspector), set nôh (`hardware.js:474`, CSS `panel.css:1750` `max-width:150px`).
- **Hľadanie** (`studio.html:143-147` `.searchbox` min 150 px): `proj_materials.js:3879` „Hľadať dekor, výrobcu alebo kód", `hw_catalog.js:1805` „Hľadať kód, názov,
  dodávateľa" (orezané na fotkách), `studio.js:1354`, `appliances.js:226,246`.
- **Stĺpce Kusovníka:** `.bomtab` bez pevného rozloženia (`studio.html:234-245`) → každá skupina materiálu má vlastné šírky (`screenshoty/studio_01_bom.png`). Stĺpce
  sú voliteľné (kontrakt UI20 **Š2**: default Dielec·Skrinka·Dĺžka·Šírka·Hr.·ks·ABS, voliteľné Smer dekoru·Rola; `studio.js:78-88`).
- **Mazacie glyfy namiesto ikony** (UI_DIZAJN §1 „žiadne emoji/unicode glyfy v ovládaní"): `hw_sets.js:969,1037,1100,1780` („×"), `rules.js:150,600,669` („✕").
- **HTML `disabled` na primárnej akcii** (UI_DIZAJN §1, vzor D-78): `studio.html:929` `mddApplyBtn` + `demos_diff.js:289-290,334-335,356-357`.
- **Ikony navigácie** (sonda S-h): `budget:euro`, **`bset:euro`**, **`rules:settings`** (`studio.js:103,131,139`). Ozubené koleso (`settings`) už nesú **Pravidlá** —
  priamy presun kolesa na Nastavenia rozpočtu (návrh GR-23) by vyrobil **novú dvojicu rovnakých ikon**. Koleso vedie na Nastavenia rozpočtu aj z tlačidla
  „Nastavenia" v lište Rozpočtu (`budget.js:463-465`) a z nálezu Kontroly (`studio.js:458-461`). Mockup Štúdia má `bset: euro` (`SYSTEM/zdroje/ui20/mockup_studio.html:811`;
  kontrakt „ostatné podľa mockupu", `UI20_KONTRAKT.md:524`).

### 0.6 NEOVERENÉ (sonda nepotvrdila)
- Pretečenie výberu nôh a systémový vzhľad rozbaľovačiek **v CEF** (fotky sú z Chrome) — overiť pred opravou (§9).
- Či kovanie s MJ `BM` (jednotka `m`) má v reálnej zákazke necelé množstvo (dnes by „2,4" ukázalo „2", F2) — formátovač to pokryje tak či tak.
- Ktoré funkcie prepíše H3 (package H3 zatiaľ neexistuje) — zoznam predpokladaných prekryvov je v §5.1.

---

## 1 · Cieľ

Okno Štúdia píše čísla a jednotky **všade rovnako** (desatinná čiarka, celé kusy bez „,00", peniaze vždy s € a dvomi desatinnými, jednotky malými písmenami
„bm · m² · ks · platne · paušál"), **nič neskrýva** (hrúbka 18,6 už nie je „19", bm ABS 70,94 už nie je „70,9") a nič nepočíta inak. Stĺpec ABS pri dvierkach
povie „0,8 dookola". Núdzové „vrátiť katalóg pred migráciou" už nestojí vedľa bežného „Obnoviť"; texty sú bez vývojárskeho žargónu a kričania; rozbaľovačky,
hľadanie, stĺpce Kusovníka, mazacie tlačidlá a ikona Nastavení rozpočtu majú jednotný vzhľad. **Dáta, výpočty, XLSX, CSV a VEPO sa nemenia.**

## 2 · Rez a odhad veľkosti

| Dávka | Položky | Súbory (odhad zmenených riadkov kódu pluginu) | Spolu |
|---|---|---|---|
| **H4a · čísla** | D-04, D-11 | `studio.js` formátovač + Kusovník + ABS (~100) · `budget.js` (~45) · `proj_materials.js` (~12) · `hw_catalog.js` + `demos_diff.js` (~8) · `rules.js` (~6) · `studio.html` CSS (~4) | **~175** |
| **H4b · texty a vzhľad** | D-06, D-07, D-08, D-09 | ⋯ menu + modal (~65) · slovník textov (~50 v ~15 súboroch + 3 Ruby) · `panel.css`/`studio.html` rozbaľovačky, hľadanie, stĺpce (~45) · ikony mazania (~20) · CS-11 (~15) · ikona (~6) · verzia (~6) | **~210** |

Spolu ~385 riadkov + ~25 upravených testov s pripnutými textami + nové testy a dokumentácia ≈ **viac ako 1 deň** → **rez H4a → H4b** (odporúčanie). Dôvody:
H4a je **výrobná/cenová (zobrazenie)** a potrebuje vlastnú charakterizáciu; H4b je čisto UI; každá polovica má menší diff na review. Poradie: **H4a prvá**
(formátovač potom použijú aj texty H4b).

## 3 · Scope IN

- **[H4a] D-04** jeden formátovač okna Štúdio + jeho nasadenie v Rozpočte (Materiál, ABS, Kovanie, Služby, Štandardné riadky, Vlastné položky, Spotrebiče),
  Kusovníku (pohľady Dielce/Platne/ABS — hrúbky, bm), Materiáloch (štítky hrúbok a formátov), Kovaní (ceny), „Aktualizovať z Demosu" (ceny), Pravidlách (kg, mm v súhrnoch).
- **[H4a] D-11** „0,8 dookola" v bunke ABS Kusovníka.
- **[H4b] D-06** presun núdzového vrátenia katalógu, premenovanie obnov s iným významom, „Načítať nanovo" → „Obnoviť".
- **[H4b] D-07** slovník náhrad, zdôraznenie tučným namiesto VEĽKÝCH písmen, verzia jednotne „v0.17.x".
- **[H4b] D-08** základný štýl `select`, výber nôh, krátke „Hľadať…", pevné šírky stĺpcov Kusovníka, ikona `x` namiesto glyfov, `aria-disabled` pre `mddApplyBtn`.
- **[H4b] D-09** odlišná ikona Nastavení rozpočtu.
- Dokumentácia: `docs/UI_DIZAJN.md` (nový odsek zápisu čísel + §4 ikony), odseky dotknutých sekcií v `docs/architecture/ui-lifecycle.md`.

## 4 · Scope OUT

- **XLSX, CSV, VEPO, Cenová ponuka XLSX** (vlastné formátovanie v Ruby) · **payload z Ruby** (kódy MJ, `poznamka`, `qty_tip`, `message_sk`; výnimka = 3 zobrazovacie texty H4b v R-B3) · **výpočty**
  (budget, bom, sheet_estimate) · Inspector mimo verzie, textov D-07 a štýlu `select` (Inspector má vlastné `mmLabel`/`nxFmtMm`, sú s čiarkou).
- **Vstupné polia** okrem peňažných polí Rozpočtu (R-A4) — hodnoty v poliach Materiálov, Pravidiel a Nastavení ostávajú.
- **Položky H3** (A-01 platne a súčtový riadok Kusovníka, A-02 tabuľka Cenovej ponuky, A-03 Kontrola, A-04 Nákup kovania, A-06 log, A-07 sadzby v Nastaveniach
  rozpočtu) — H4 v nich len **prevezme formátovač a slovník**, ak H3 nechá čísla/texty, ktoré ich potrebujú (§5.1).
- R-24 (zlúčenie escaperov do `nx_text.js`), R-27 („1,0 mm" v Pravidlách), štítok „override" (kontraktový pojem UI20 Š17), množné číslo v serverovej poznámke
  „4 platní" (ide aj do XLSX) — §14.

## 5 · Trieda podľa CLAUDE.md

| Otázka | H4a | H4b |
|---|---|---|
| Výrobná/cenová? | **ÁNO (zobrazenie)** — mení sa zápis množstiev a cien, podľa ktorých sa objednáva: bm ABS 70,9 → 70,94, kovanie „2" → „2,4" pri necelom množstve, hrúbka „19" → „18,6", MJ „PLATŇA" → „platne". Výpočet ani export sa nemení (hranica „aj keď sa mení len to, čo okno ukazuje" z H1/B-09). | nie — texty, farba, ikona, rozloženie |
| Nový ovládací prvok? | nie | **áno** — tlačidlo „⋯" s ponukou (variant A, §6 R-B1) |
| > 300 riadkov kódu? | nie (~175) | nie (~210) |
| Audit návrhu (`codex-audit`)? | **nie** — žiadny kontrakt, schéma, migrácia, observer; **žiadny nový modul** (formátovač žije v `studio.js`, vzor `refreshBtnHtml`). *Ak orchestrátor zvolí samostatný súbor `nx_fmt.js`, je to nový modul → audit povinný + riadok v rozcestníku.* | nie |
| Slepá predrecenzia? | **povinná** (výrobná/cenová) | **povinná** (nový ovládací prvok; CS-11 mení stráž dvojitého odoslania) |
| In-SU brána? | **nie** — JS/CSS, žiadny builder, observer, undo, geometria ani zápis do modelu | **nie** — 3 Ruby texty (status, popisok tagu) nie sú spúšťač in-SU |
| Texty z Ruby? | nie | **áno, 3 reťazce** (`core/tags.rb:47`, `ui/panel/actions_cabinet.rb:865`, `ui/materials_dialog.rb:428`) — len zobrazenie |
| Verzia | patch po H3 + všetky `?v=` | patch po H4a + všetky `?v=` |

### 5.1 Závislosť na H3 (H4 ide po mergi H3 a zladí sa)
Pred prácou `git log`/`git diff` H3 nad týmito miestami a prevziať jeho znenie: `studio.js` `totalRow` (`:1590`), `sheetsTable` (`:1637`, súčet „NIE nárezový
plán" `:1684`), `semaforHtml`/`ctrlSection` (`:365-390`, `:1510-1530`, sechint `:1289`), `buySection` (`:700-780`); `budget.js` `budCpTableHtml` (`:1436-1450`)
a veta „(PLAN, blok V1)" (`:1432`); `studio_settings.js` tabuľka sadzieb a hint `:316`. Pravidlo: **texty, ktoré H3 prepísal, sa neprepisujú znova**; ak H3 nechal
v novom kóde číslo alebo jednotku, použije sa formátovač H4a; ak H3 vlastný formátovač pridal, H4a ho zjednotí (alias), nie zdvojí.

**Zladenie pri H4a (krok 0, implementátor, 1.10.2026, main `6c862c1b` = v0.17.2 s H3a + H3b):** H3a vlastný formátovač nepridal; jeho texty sa neprepisujú.
Čísla, ktoré H3a nechal, idú cez formátovač: `totalRow` „ABS spolu" bm `num(t.bm,1)` → `nxfQty(…,'BM')` (2 desatinné, zhodne s pohľadom ABS); `sheetsTable`
súčet m² (už 2 desatinné) a stĺpec „Odhad platní" (orientačný rozsah na 1 desatinné) **bez zmeny**; `budCpTableHtml` množstvo `budFmtNum(…,0)` → `nxfQty(…,'KS')`
(server posiela celé čísla → rovnaký výstup; MJ ponuky má vlastný slovník v Ruby, ostáva); `buySection` cena `price()` → `nxfMoney` (tisíce, „−")
a množstvá `num()` → `nxfQty` (necelé kovanie v metroch sa neskryje); semafor Kontroly (celé počty) a tabuľka sadzieb `studio_settings.js` (vstupné polia)
**bez zmeny**. Zámer, dáta ani čísla sa zladením nemenia.

---

## 6 · Požiadavky

### H4a

**R-A1 · Formátovač okna Štúdio** — blok „ZÁPIS ČÍSEL A JEDNOTIEK (H4 · D-04)" v `ui/js/studio.js` pri `num` (`:191`), globálne funkcie + `module.exports`
(sekcie ho dostanú rovnako ako `refreshBtnHtml`; v Node `require('./studio.js')` — `demos_diff.js` si require pridá). Pravidlá (**rovnaké hodnoty, len zápis**):

| Funkcia | Použitie | Pravidlo |
|---|---|---|
| `nxfMoney(v)` | sumy, ceny za MJ | **presne `budFmtEur`** (2 desatinné, čiarka, tisíce ` `, mínus `−` U+2212, „ €"; null/''/NaN → „—"; **0 → „0,00 €"**). `budFmtEur` ostane ako alias (testy F1 bez zmeny). |
| `nxfMoneyIn(v)` | hodnota **peňažného poľa** | čiarka, **bez tisícov a bez €**, min 2 / max 3 desatinné (zachová presnosť `budNumText`), mínus ASCII `-` (kvôli `budParse`); null → '' |
| `nxfQty(v, mj)` | množstvo podľa kódu MJ | **kusové** `KS PLATŇA SET PÁR BAL FIX`: celé → bez desatinných, necelé → max 2 desatinné bez koncových núl (**nikdy nezaokrúhli na celé**); **merné** `BM M2`: vždy 2 desatinné; neznámy kód: max 3 bez koncových núl; null → „—" |
| `nxfUnit(mj, n)` | text jednotky | `KS→ks · BM→bm · M2→m² · SET→set · PÁR→pár · BAL→bal`; `PLATŇA`: bez `n` „platňa", inak 1 „platňa" / 2–4 „platne" / 0, 5+ „platní" / necelé „platne"; `FIX`: bez `n` „paušál", 1 „paušál" / 2–4 „paušály" / 0, 5+ „paušálov"; neznámy kód bez zmeny |
| `nxfQtyUnit(v, mj)` | „množstvo jednotka" | `nxfQty + ' ' + nxfUnit(mj, v)` |
| `nxfMm(v)` | hrúbky, mm v texte | max 2 desatinné bez koncových núl (zrkadlo `mmLabel`/`Materials.fmt_mm`); null → „—" |
| `nxfDim(v)` | dĺžka a šírka dielca | celé mm, polovica nahor (= VEPO `rounded_dims`); **bez oddeľovača tisícov** — dnešný zápis |
| `nxfDec(v, max)` | ostatné čísla v texte (kg, %) | max `max` desatinných bez koncových núl, čiarka |

Oddeľovač tisícov **len pri peniazoch**. Zaokrúhlenie peňazí rovnakým algoritmom ako `budFmtEur` (hodnoty chodia zo servera už na centy — výstup sa nemení).
Záporné množstvá sa nepredpokladajú; ak prídu, `−`.

**R-A2 · Rozpočet** (`budget.js`): Materiál `:813-814` → `nxfQty(r.mnozstvo, area ? 'M2' : r.mj)` + `nxfUnit(area ? 'M2' : r.mj)`; ABS `:849-850` → `nxfQty(…,'BM')`
(2 desatinné) + „bm"; Kovanie `:859-860` → `nxfQty(r.mnozstvo, r.mj)` + `nxfUnit(r.mj)`; Služby `:914` → `nxfQtyUnit(r.mnozstvo, r.mj) + ' × ' + cena`
(„37,26 bm × 1,10 €", „4 platne × 17,00 €", „0 ks × 50,00 €", „0 paušálov × 100,00 €", „23,20 m² × 16,50 €"). Serverová poznámka za bodkou ostáva, ako je.

**R-A3 · Kusovník** (`studio.js`): hlavička skupiny `:1552` a stĺpec „Hr." (`c.k === 'th'`, `:1569`) → `nxfMm`; pohľad Platne „Hrúbka" `:1671` → `nxfMm`; pohľad ABS
„Hrúbka" `:1708` (`num(m.th,1)` = „1,0 mm") → `nxfMm` („1 mm", „0,8 mm", „0,45 mm") a „bm" `:1710` → 2 desatinné. Dĺžka/Šírka ostávajú `nxfDim` (dnešný výstup).
Súčtový riadok (`totalRow`) a pohľad Platne — až po H3 (§5.1).

**R-A4 · Peňažné polia Rozpočtu:** „Medzisúčet" Služieb (`:908`) a Štandardných riadkov, cena vlastnej položky (`:964`) a spotrebiča (`:1032`) → `value = nxfMoneyIn(…)`
(„68,00", „382,80", „40,99") a za poľom tlmené „€" (`<span class="bfnt">€</span>`, bez nového riadku). Polia počtu a násobku (`:930`, `:961`) sa **nemenia**.
Podmienka: `budParse(nxfMoneyIn(x)) === x` pre všetky hodnoty zo servera (test R-A-T3).

**R-A5 · Materiály, Kovanie, Demos, Pravidlá:** `proj_materials.js` — **len zobrazovacie** volania `fmtNum` (`:191,193,199,883,1751,1905,1913,3116,3123`) cez
`nxfMm`/`nxfDec` („DTDL 18,6", „23/0,8", „2800×2070"); `:2205` (pole) **nie**. `mdhFmtPrice` a `mddFmtPrice` → `nxfMoney` („12,50 €"). `rules.js:103-104` → `nxfDec(kg, 2)`
+ „kg", `nxfMm(rod)`; implementátor prejde Grepom `'…' + <číslo>` v `rules.js`, `hw_catalog.js`, `hw_sets.js` a zobrazované desatinné čísla prevedie (zoznam do PR).

**R-A6 · D-11 ABS „dookola"** (`absCompact`): keď **všetky štyri** kódy `L1 L2 W1 W2` majú pásku, **všetky štyri sú tá istá páska** (rovnaké ID) a hrúbka je známa
→ bunka `"<hrúbka> dookola"` („0,8 dookola", „2 dookola"). Inak dnešný kompakt. Titulok (`absFull`) sa **nemení** — plné L1–W2 s menom pásky. Hrúbka v oboch
tvaroch cez `nxfMm` (0,45 už nie „0,5"). Dáta riadku, `row_key`, VEPO a CSV sa nemenia (kompakt je len text bunky).

### H4b

**R-B1 · D-06 núdzové vrátenie katalógu** — **variant A (predvolený, Q1):** v lište Materiálov namiesto „Obnoviť zálohu" tlačidlo **„⋯"** (`more-horizontal`, `ghostbtn`,
`aria-label="Ďalšie akcie katalógu"`, `aria-haspopup="menu"`, `aria-expanded`) **za** „Obnoviť" (posledné vpravo); zobrazí sa pri tej istej podmienke ako dnes
(`s.backup && !s.ro`) — bez položiek sa nekreslí (D-78). Ponuka = overlay (UI_DIZAJN §1, vzor rozbaľovacieho nastavenia v lište Kontroly), jedna položka
**„Vrátiť katalóg pred migráciou…"** (`rotate-ccw`, titulok dnešného tlačidla) → `mdRestoreOpen()` (ten istý modal, ten istý Ruby callback). Zatvára ju klik mimo,
výber položky a **Escape** (Escape zavrie len ponuku — overiť voči `nx_esc.js` zoznamom FOREIGN/OWN a Escape handleru Štúdia, jedno stlačenie = jedna vrstva).
Modal: nadpis „Vrátiť katalóg pred migráciou", tlačidlo „Vrátiť katalóg" (`studio.html:899,903`); banner núdzového režimu `studio.html:1050` → „Vrátiť katalóg pred migráciou…"
(ostáva v banneri — tam je núdzová situácia). Status `materials_dialog.rb:428` → „Katalóg vrátený do stavu pred migráciou. Pri najbližšom štarte…".
*Variant B (ak Q1 = O plugine): blok „Údržba katalógu" v sekcii O plugine (len štúdiový vstup ako updater, `about.js:78-120`), príznak zálohy musí poslať server
v payloade „O plugine" (dnes ho nesie len payload Materiálov) — +Ruby, +~30 riadkov.*

**R-B2 · D-06 názvy obnov:** bežná obnova = **„Obnoviť" + `refresh-cw`** všade: Nastavenia rozpočtu „Načítať nanovo" → „Obnoviť" s `refresh-cw` (titulok
„Zahodí neuložené zmeny a načíta nastavenia nanovo" ostáva; `studio_settings.js:625,633`, veta `:579`). Iný význam = **„Vrátiť…"** s `rotate-ccw`:
Spotrebiče `appliances.js:436` „Vrátiť", veta `:743` „Vrátiť sa dá kedykoľvek"; `hw_sets.js:1821` „Vrátiť na globálne predvoľby"; Inspector `hardware.js:643`
„vrátiť" (titulok „Vrátiť položku — platí pravidlo"). **Nemenia sa:** „Načítať globálne" (Pravidlá) a „Prepočítať ceny" (Rozpočet) — iné akcie.
Spotrebiče prázdny stav `appliances.js:544` → „Zákazka sa ešte nenačítala — otvor Štúdio znova." (tlačidlo Obnoviť tam nie je).

**R-B3 · D-07 slovník náhrad** (presný text → náhrada; implementátor overí každý riadok v kóde po H3):

| Súbor:riadok | Dnes | Náhrada |
|---|---|---|
| `studio.js:167` | „… · predvoľby setov projektu zatiaľ v okne" | „… · predvoľby setov platia pre túto zákazku" *(overiť, že blok „Predvoľby projektu" je v sekcii — `hw_sets.js:1809`)* |
| `studio.js:182` | „… — jeden obsah, dva vstupy" | „to isté nájdeš v koliesku Inspectora" |
| `studio.js:1289` *(po H3)* | „Zoradené podľa závažnosti — poradie určuje server." | „Zoradené podľa závažnosti." |
| `studio.js:383` *(po H3)* | „… — počíta ich server." | bez dovetku |
| `studio.js:906`, `shell.js:415` | „bez smeru (legacy)" | „bez smeru (staršie čelá)" |
| `appliances.js:265` | „N modelov (N seed)" | „N modelov (N dodaných s pluginom)" |
| `appliances.js:422` | štítok „seed" | štítok „z pluginu", titulok „Dodaný s pluginom" |
| `panel.html:126` | „Zobraziť zóny (ghost) v modeli" | „Zobraziť obrysy zón v modeli" |
| `core/tags.rb:47` | „Zóny (ghost)" | „Zóny (obrysy)" |
| `panel.html:174` | aria „Nápoveda ovládania ghostu" | „Nápoveda ovládania vkladania" |
| `ghost_bar.js:208` | „Výška, na ktorej ghost sedí (mm)" | „Výška, na ktorej vkladaná skrinka sedí (mm)" |
| `actions_cabinet.rb:865` | „… mm — ghost sadne na túto výšku." | „… mm — vkladaná skrinka sadne na túto výšku." |
| `studio_settings.js:270` | „množstvo počíta engine z dát zákazky" | „množstvo sa počíta z dát zákazky" |
| `studio_settings.js:327` | „(slušné správanie voči serveru, …)" | „(ohľaduplnosť k webu Demos, …)" |
| `hw_sets.js:1654` | „… vyberie server podľa radu." | „… vyberie plugin podľa radu." |
| `proj_materials.js:3049` | „— server mazanie odmietne." | „— plugin mazanie nedovolí." |
| `rules.js:225` | „— server ich zoradí sám." | „— zoradia sa samy." |
| `hardware.js:118` | „Server pre túto os nemá hodnotu…" | „Pre túto os nie je hodnota…" |
| `hardware.js:641` (titulok) | „Zrušiť dormantný zámok …" | „Zrušiť zámok, ktorý recept už nepoužíva" |
| `hw_sets.js:1065,2080,2025` | „ORANGE „doplň pásmo"" / „(ORANGE)" | „oranžové upozornenie „doplň pásmo"" / „(oranžové)" |
| `budget.js:673` | „Sadzby per REŽIM" | „Sadzby podľa režimu" |
| `budget.js:676,1151` | „v KONTROLE" | „v sekcii Kontrola" |
| `budget.js:1432` *(ak nerieši H3)* | „(PLAN, blok V1)" | „(po V1)" |

**Zdôraznenie** (VEĽKÉ → malé; v HTML texte `<b>…</b>`, v titulku, statuse a `textContent` len malé písmená): `budget.js:448,500,671` („vznikajú <b>samy</b>" —
aj gramatika), `:677,1395,2201`; `appliances.js:212,743`; `bridge.js:201,979`, `panel.html:326` („Štúdio", „Kontrola"); `ghost_bar.js:36`; `hardware.js:120`;
`hw_sets.js:1113`; `rules.js:145,162,1219`; `shell.js:384,412,866`; `studio.js:646,1684`*(po H3)*; `studio_settings.js:278,316`*(po H3)*`,324,357,520,521`;
`templates.js:315,450,452,509,511`; `panel.html:1030`. Kódy a názvy (ABS, UNI, VEPO, XLSX, DPH, CAB-…, INSTALL, SPOLU) ostávajú.
**Verzia** všade „v" + verzia: `about.js:35,36,110`, `bridge.js:301`, `studio_settings.js:519`, `hw_catalog.js:503` (mŕtvy uzol — zmeniť kvôli guardu).

**R-B4 · D-08 vzhľad:**
- **(a) `select`:** základné pravidlo v `panel.css` (oba okná) s nízkou špecifickosťou: `font: inherit; font-size: 12px; padding: 4px 6px; border: 1px solid
  var(--nx-border-strong); border-radius: 6px; background: var(--nx-surface); color: var(--nx-ink); max-width: 100%; min-width: 0` — **bez** vlastnej šípky
  (dátové URI s hex farbou by porušilo pravidlo tokenov); existujúce špecifické pravidlá vyhrávajú. Výber nôh `panel.css:1750`: `flex: 1 1 auto; min-width: 0;
  max-width: 100%` (dnes pevných 150 px).
- **(b) Hľadanie:** všetkých päť polí `placeholder="Hľadať…"` + `title` a `aria-label` s rozsahom („Hľadať dekor, výrobcu alebo kód" atď.).
- **(c) Stĺpce Kusovníka:** v `partsTable` trieda `c-<kľúč>` na `th` aj `td`; `.bomtab.parts { table-layout: fixed }` a spoločné šírky: Dĺžka/Šírka 64 px, Hr. 52 px,
  ks 44 px, ABS 190 px, Smer dekoru 96 px, Rola 120 px, akcie 56 px, Skrinka 28 %, Dielec zvyšok. Textové bunky sa **zalamujú** (`white-space: normal;
  overflow-wrap: anywhere`) — nič sa neoreže. Pohľady Platne a ABS (jedna tabuľka) bez zmeny. Kontrakt Š2 (voliteľné stĺpce) platí.
- **(d) Mazanie:** 7 glyfov → `NXIcons.svg('x')` / `<svg class="ic"><use href="#i-x"/></svg>` + `aria-label` = dnešný titulok (pri `hw_sets.js:1037,1100,1780` titulok
  doplniť: „Odobrať dĺžku", „Odobrať triedu", „Odobrať pásmo"). Šírka stĺpca 22 px (test `test_smoke1_riadky.rb`) ostáva.
- **(e) CS-11:** `mddApplyBtn` bez HTML `disabled` → `aria-disabled="true"` + `title` s dôvodom („Najprv načítaj a vyber zmeny" / „Zapisujem…"); delegovaný
  handler `mdd-apply` pri `aria-disabled` **nič neodošle** (stráž dvojitého zápisu ostáva). Ostatné `disabled` v okne → §14.

**R-B5 · D-09 ikona:** **variant A (predvolený, Q2):** Nastavenia rozpočtu dostanú novú ikonu **`sliders-horizontal`** (Lucide, ISC — ako zvyšok spritu) v `NAV`
(`studio.js:139`), v tlačidle „Nastavenia" lišty Rozpočtu (`budget.js:465`) a v akcii nálezu Kontroly (`studio.js:461`); Pravidlá ostávajú s kolesom (zhoda s Inspectorom,
`panel.html:783,788`). Symbol do `icons.js` + inventár `UI_DIZAJN.md` §4 + vedomá odchýlka od mockupu Štúdia (D-09, Michal 1.10.) v odseku Štúdia `ui-lifecycle.md`.

---

## 7 · Testy a DoD

**H4a — nové `tests/js/test_h4a_format.js`** (vzor `tests/js/test_budget_ui.js`):
- **T1 tabuľka vstup → výstup:** `nxfMoney`: 1323.1 → „1 323,10 €", 0 → „0,00 €", null → „—", −12.5 → „−12,50 €", 18.994 → „18,99 €" · `nxfMoneyIn`: 68 → „68,00",
  382.8 → „382,80", 40.987 → „40,987", 1234.5 → „1234,50", null → „" · `nxfQty`: (4,'PLATŇA') „4", (2.5,'KS') „2,5", (2.4,'BAL') „2,4", (0,'KS') „0", (37.26,'BM') „37,26",
  (70.94,'BM') „70,94", (23.2,'M2') „23,20", (1,'FIX') „1", (null,'KS') „—", (1.005,'XYZ') „1,005" · `nxfUnit`: PLATŇA bez n „platňa", 1/4/5/0/2,5 → platňa/platne/platní/platní/platne;
  FIX 0/1/3 → paušálov/paušál/paušály; BM „bm", M2 „m²", KS „ks", 'XYZ' „XYZ" · `nxfMm`: 18.6 „18,6", 18 „18", 18.65 „18,65", 0.45 „0,45" · `nxfDim`: 762.5 „763",
  762.4 „762", 2800 „2800".
- **T2 zhoda:** `budFmtEur ≡ nxfMoney` na 200 hodnotách; `nxfMm ≡ mmLabel` (Inspector `core.js`) pre nenulové hodnoty.
- **T3 okružná cesta poľa:** `budParse(nxfMoneyIn(x)) === x` pre x zo serverových súm (celé, 1–3 desatinné, záporné, 0).
- **T4 render:** `budServiceRow` / `budMaterialRow` / `budSimpleRow` / `budHardwareRow` nad fixtúrou → „37,26 bm × 1,10 €", „4 platne × 17,00 €", MJ „platňa", ABS „70,94",
  kovanie „2,4"; žiadne `PLATŇA`, `BM`, `M2`, `FIX` ako text bunky; pole medzisúčtu `value="68,00"` a za ním „€".
- **T5 Kusovník:** `partsTable`/hlavička s hrúbkou 18,6 → „18,6" (nie „19"); pohľad ABS „0,8 mm" a „1 mm"; bez desatinnej **bodky** vo viditeľnom texte
  (regex `\d\.\d` nad `textContent` renderu Rozpočtu, Kusovníka a Materiálov z fixtúr — výnimka: nič).
- **T6 D-11:** 4× rovnaká páska → „0,8 dookola"; 4 hrany, dve pásky rovnakej hrúbky → plný kompakt; 3 hrany → plný kompakt; bez metadát → „L1 · L2 · W1 · W2";
  titulok nezmenený. Existujúce `test_st1a_studio.js:143-146` bez zmeny.
- **Upravené testy:** `test_hw_catalog.js` a `test_demos_diff.js:132` („18,99 €"), `test_ceny_m2_budget.js:106` (MJ „platňa"), `test_budget_ui.js:28` (bm 2 desatinné) —
  každú zmenu očakávania zdôvodniť v PR.
- **Mutácie (musia padnúť):** `nxfQty` kusové zaokrúhli na celé → T1 (2,5); tisíce aj pri `nxfDim` → T1 (2800); `absCompact` porovná len hrúbku → T6; `nxfMoneyIn` s „€"
  alebo `−` → T3; MJ surovo → T4.
- **Charakterizácia „nič iné sa nemení":** `git diff --name-only origin/main...HEAD -- noxun_engine/core noxun_engine/ui/*.rb noxun_engine/ui/panel` = **prázdne**; zelené
  zlaté a exportné sady bez zmeny fixtúr: `test_np4_golden.rb`, `test_ceny_m2_golden.rb`, `test_kova_golden.rb`, `test_kovh_golden.rb`, `test_eb_rozpocet.rb` (XLSX),
  `test_cp_export.rb`, `test_vepo_export.rb`, `test_np1_vepo_charakterizacia.rb`, `test_d92_kovanie_nakup.rb`, `test_st1c_nakup.rb` (CSV).

**H4b — nové `tests/pure/test_h4b_texty_vzhlad.rb`** (guard, vzor `test_kova2a_karta.rb:208`):
- **refute** presných fráz v `ui/js/*.js`, `ui/*.html`, `core/tags.rb`: „(legacy)", „ seed)", „>seed<", „(ghost)", „ghostu", „ghost sedí", „ghost sadne", „poradie určuje server",
  „jeden obsah, dva vstupy", „zatiaľ v okne", „počíta engine", „voči serveru", „Obnoviť zálohu", „Načítať nanovo"; **refute** `'V' + ` pri verzii (about, bridge, studio_settings, hw_catalog).
- **refute** glyfu ako obsahu tlačidla (`>✕</button>`, `hwsMk('button', …, '×')`); **refute** `disabled` na `mddApplyBtn` v `studio.html`.
- **NAV ikony jedinečné** (žiadne dve položky navigácie s rovnakým `ic`) — stráži D-09 aj budúce sekcie; `sliders-horizontal` v `icons.js` aj v §4 `UI_DIZAJN.md`.
- CSS: základné `select` pravidlo v `panel.css`, `.bomtab.parts` s `table-layout: fixed`, trieda `c-` v `partsTable`.
- **JS:** `matToolsHtml` so zálohou nekreslí `mdRestoreBtn`, kreslí „⋯" a ponuka má „Vrátiť katalóg pred migráciou…"; bez zálohy ani v RO „⋯" nie je
  (úprava `test_st2a_mat.js:89-106`); Escape zavrie len ponuku; `mdd-apply` pri `aria-disabled` neodošle.
- Upravené pripnuté texty (~15–20 asercií, napr. `test_kova2b_smer_overlay.js:115,158`, `test_d52b_updater_ui.js:153,501,521`, `test_st4a_settings.js`,
  `test_st1c_nakup.rb`, `test_s1a2_sekcia.js`, `test_p0hf_*`, `test_d27_tagy.*`) — **len znenie, nie správanie**; zoznam do PR.
- Ruby diff len 3 reťazce (`git diff` Ruby súborov = tieto riadky).

**Obe:** `ruby tests/run_all.rb` + **každá** JS sada (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + encoding guard.
**Fotky okien:** `scripts\ui_foto.ps1` (dávka H2 — **podmienka: musí byť v maine**; ak nie je, ohlásiť a fotiť ručne). H4a: `-Shoot` (len JS/CSS) — Rozpočet, Kusovník
(Dielce/Platne/ABS), Materiály, Kovanie. H4b: `-Record` (mení sa popisok tagu z Ruby) + `-Shoot` všetkých sekcií a Inspectora; pred/po do reportu.

## 8 · In-SU
**Nie** (obe dávky) — žiadny builder, observer, undo, geometria ani akcia panela meniaca model; zmenené Ruby sú len texty (pravidlo „Finálna hlava").

## 9 · Riziká

1. **CEF ≠ Chrome (D-08).** Pred úpravou (a) až (c) **overiť v SketchUpe** v `_dev\ENGINEtests.skp` (nikdy okno so zákazkou): Inspector so skrinkou na nohách (pretečie
   výber nôh pri 486 px?), Štúdio → Materiály, Kovanie, Spotrebiče → V zákazke (vzhľad rozbaľovačiek, orezané hľadanie pri 1060 px), Kusovník (skákanie stĺpcov —
   vec rozloženia tabuľky, v CEF rovnaké). Snímka okna: screenshot pracovnej plochy (orchestrátor cez computer-use alebo PowerShell `CopyFromScreen`) — `view.write_image`
   HtmlDialog nezachytí. Ak overenie nejde: CSS (a)–(c) sú neškodné aj tam, kde CEF problém nemá; overí Michal v smoke (bod 7).
2. **Iný zápis v poli = falošný ručný prepis?** Nie — `change` vzniká len pri úprave (`budget.js:2394`); T3 stráži okružnú cestu.
3. **XLSX/CSV/VEPO zasiahnuté** — formátovač je len v JS; diff guard + zlaté sady (§7). 4. **Prekryv s H3** — §5.1.
5. **„dookola" skryje rôzne pásky** — podmienka rovnakého ID (R-A6). 6. **Hrúbka 18,6 v Kusovníku vs. 18 vo VEPO** — obe pravdivé (VEPO nesie obchodnú hrúbku, `vepo_export.rb:126-132`).
7. **Escape a „⋯"** — nová vrstva v reťazi `nx_esc.js`, test v §7. 8. **Pripnuté texty** — meniť znenie, nikdy neoslabiť test (zmazaná asercia = P1 v predrecenzii).
9. **Kolízia ID D-xx s DOGFOODING** — v zápisoch vždy „triedenie HARDENING".

## 10 · Smoke checklist pre Michala (po slovensky, funkčne)

**H4a:**
1. Rozpočet → Služby: „37,26 bm × 1,10 €", „4 platne × 17,00 €", „0 ks …", „23,20 m² …"; medzisúčty v poliach „40,99 €", „68,00 €". **Sumy sú rovnaké ako predtým.**
2. Rozpočet → Materiál: MJ „platňa" malým, množstvo celé; ABS hrany množstvo na 2 desatinné (napr. 70,94). XLSX rozpočtu **bez zmeny** (MJ „PLATŇA" ako doteraz).
3. Kusovník: materiál 18,6 mm ukazuje „18,6" v hlavičke aj stĺpci Hr.; dvierka s rovnakou páskou dookola majú v ABS „0,8 dookola", po nabehnutí myšou plný zápis
   L1–W2. VEPO export **rovnaký** ako predtým.
4. Materiály: „DTDL 18,6", „23/0,8"; Kovanie a „Aktualizovať z Demosu": ceny s čiarkou („12,50 €").

**H4b:**
5. Materiály: vedľa „Obnoviť" už nie je „Obnoviť zálohu"; ak je záloha, „⋯" → „Vrátiť katalóg pred migráciou…" otvorí to isté potvrdenie. Escape ponuku zavrie.
6. Nastavenia rozpočtu: tlačidlo „Obnoviť" (namiesto „Načítať nanovo"); Spotrebiče: vyradený model sa vracia tlačidlom „Vrátiť".
7. Rozbaľovačky (Podľa výrobcu, Kresba čiel, Všetky kategórie, set nôh v Inspectore) vyzerajú ako ostatné polia a výber nôh nepresahuje okraj; hľadanie píše „Hľadať…".
8. Kusovník: stĺpce Dĺžka/Šírka/Hr./ks sú pod sebou vo všetkých skupinách; dlhý zoznam skriniek sa zalomí, nezmizne.
9. Kovanie → Sety a Pravidlá: mazanie riadku je ikona ×, nie písmeno.
10. Zbalená navigácia Štúdia: Rozpočet (€) a Nastavenia rozpočtu (posuvníky) sa dajú rozlíšiť.
11. Texty: nikde „ghost", „seed", „legacy", „server"; verzia „v0.17.x" v Štúdiu aj v pätičke Inspectora; zóny v raile „Zóny (obrysy)".

## 11 · Checklist uzáveru (každá z H4a/H4b)

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky** `?v=` v `ui/*.html` · testy zelené (headless, každá JS sada, encoding) · **`docs/UI_DIZAJN.md`**:
H4a nový odsek **„Zápis čísel a jednotiek"** za §3 Typografia (tabuľka R-A1, pravidlo „nikdy neskryť hodnotu", „MJ v dátach = kód, v okne = text"); H4b §1 (ikony mazania,
`aria-disabled`), §4 `sliders-horizontal` · **`docs/architecture/ui-lifecycle.md` odseky na mieste** (nie na koniec): „studio_dialog.rb + ui/studio.html + ui/js/studio.js"
(formátovač, Kusovník, NAV ikona), „Sekcia ROZPOČET v Štúdiu", `materials_dialog.rb` (ponuka „⋯"), `ui/js/about.js` (verzia) · **prepis `SYSTEM/STAV.md`** · **KRONIKA**
odsek navrch „Záznamy dávok" (ID ako „triedenie HARDENING D-04…", žiadny zápis do `DOGFOODING_vyriesene.md`) · **PLAN** riadok H4 (po H4b) ✅ s číslami PR (po H4a
poznámka „H4a ✅ #N") · PR popis: čo vidí používateľ, sekcia „Predrecenzia", charakterizácia (diff guard + zlaté sady), fotky, stav Q1/Q2 · `PR #?` → číslo samostatným
commitom · package do `SYSTEM/zdroje/bloky/HARDENING/`.

## 12 · Rozhodnutia autora (bezpečnejšia vratná voľba) — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| A1 | Rez H4a (čísla) → H4b (texty, vzhľad) | ~385 riadkov + ~25 testov + docs > 1 deň; iná trieda polovíc | **áno** |
| A2 | Formátovač v `studio.js` (nie nový súbor) | vzor `refreshBtnHtml`; bez nového modulu, bez auditu; R-24 (`nx_text.js`) ho neskôr presunie | **áno** |
| A3 | Kusové MJ necelé = max 2 desatinné; merné (bm, m²) vždy 2 | „rovnaké hodnoty, len zápis" — nič sa neskryje (dnes „2" pri 2,4; „70,9" pri 70,94) | nie |
| A4 | Dĺžka/Šírka v Kusovníku ostávajú celé mm, hrúbka skutočná (18,6) | zhoda s VEPO `rounded_dims`; hrúbka „19" bola chyba zobrazenia | krátko |
| A5 | Oddeľovač tisícov len pri peniazoch | rozmery bez medzier ako vo výkresoch a VEPO | nie |
| A6 | Peňažné polia 2–3 desatinné + „€" za poľom; polia počtu/násobku bez zmeny | parser ich prečíta (T3); € v poli by rozbilo zápis | nie |
| A7 | MJ preklad len v JS, kódy a serverové poznámky (aj „4 platní") bez zmeny | XLSX ich preberá (`xlsx_writer.rb:440-457`) | nie |
| A8 | „dookola" len pri 4 hranách s tou istou páskou | kompakt dnes identitu pásky nenesie (S-b2) | nie |
| A9 | „Načítať nanovo" → „Obnoviť" (titulok o zahodení zmien ostáva); iné významy → „Vrátiť…" | jedno slovo = jedna akcia | krátko |
| A10 | CS-11 len `mddApplyBtn` (zdroj auditu); ostatné `disabled` do zásobníka | menší zásah do stráží dvojitého odoslania | nie |
| A11 | Verzia malým „v" (ako dokumenty a hlavička Štúdia) | návrh CU-13; mení 5 miest a 3 testy | nie |
| A12 | „seed" → „dodaný s pluginom" (štítok „z pluginu"); „ghost" → „obrysy zón" / „vkladaná skrinka" (dva rôzne významy) | slovník triedenia; štítok musí byť krátky | krátko |

## 13 · Otázky pre Michala (produktové)

- **Q1 · Kam s „vrátiť katalóg pred migráciou"?** **Predvolené (A):** do ponuky „⋯" v lište Materiálov — ostáva pri katalógu, ktorého sa týka, len o klik ďalej.
  **Alternatíva (B):** do sekcie „O plugine" k aktualizácii (údržba pluginu na jednom mieste; +malá zmena na strane Ruby). V núdzovom režime katalógu ostáva tlačidlo
  v banneri Materiálov v oboch variantoch.
- **Q2 · Ikona Nastavení rozpočtu.** Ozubené koleso (návrh auditu) už majú **Pravidlá** — v zbalenej navigácii by sa zas zlievali dve položky.
  **Predvolené (A):** Nastavenia rozpočtu dostanú ikonu **posuvníkov** (aj tlačidlo „Nastavenia" v Rozpočte), Pravidlá ostanú s kolesom ako v Inspectore.
  **Alternatíva (B):** koleso Nastaveniam rozpočtu a Pravidlá dostanú novú ikonu (napr. zoznam s fajkami).

## 14 · Nálezy mimo scope (návrhy do zásobníka)

- **Množné číslo v serverovej poznámke** „4 platní × 5,8 m²" (`core/budget.rb:541`) — oprava mení aj text v XLSX → vlastná malá dávka so zmenou XLSX golden.
- **Ostatné HTML `disabled` na akciách** Štúdia: `budget.js:485,1687`, `demos_add.js:397`, `proj_materials.js:3864` (RO lišta) — rovnaký vzor ako CS-11.
- **Štítok „override"** (`rules.js:395`, `panel.html:843`) — kontraktový pojem UI20 Š17; preklad („ručne") len s úpravou kontraktu.
- **Mŕtvy uzol `hwline`** (`hw_catalog.js:501-504`, v `studio.html` neexistuje) — zmazať s R-24.
- **R-24** — po H4 sú formátovače v `studio.js`; zlúčenie s escapermi do `nx_text.js` a prevzatie aj Inspectorom (`mmLabel`, `nxFmtMm`) ostáva v zásobníku.
