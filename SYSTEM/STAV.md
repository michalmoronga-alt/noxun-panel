# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md).
> **Údržba:** pri uzávere dávky/etapy alebo zmene smeru sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide ako odsek do [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia.

## Stav

**v0.7.14 · 19.8.2026.** Etapa V0.6 (katalógy a ceny) je obsahovo splnená — plugin vie zákazku od návrhu cez materiály, ABS a kovanie až po VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku; upratovacia etapa U1–U4 uzavrela dokumentáciu a hygienu repa (checkpoint v0.6.0), blok ŠTART AUTONÓMIE (D-101 · D-86 · D-77, PR #162–#164) prebehol prvýkrát autonómne.

**Beží blok UI 2.0.** Koncept Inspectora je uzavretý (Michal 18.8.) — záväzný kontrakt a mockupy sú v repe: [zdroje/ui20/](zdroje/ui20/) ([UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md) + mockupy Inspector C, štúdio, dizajnový lístok); práca je narezaná do dávok UI-A → UI-B → UI-C → UI-D a fázy ŠTÚDIO ([PLAN.md](PLAN.md)).

Zákazka **KLINIKA** (254 dielcov) je postavená čisto z pluginu, prekontrolovaná a overená veľkým testom (porovnanie s ručným rozpočtom). Posledná zmena kódu: **UI-C2 · Zóny** — kontext Zóny má štruktúru navrchu so stromovými spojnicami, delenie cez dlaždice, police ako pilulky 0–6, presné delenie prvej zóny v mm aj zlomkom a magnet pri ťahaní priečky v náhľade. Testy: **1350 headless · 40 JS sád**; posledný **plný in-SketchUp beh 427 PASS / 0 FAIL** — vrátane novej sekcie `run_uic2` (delenie, police, presná cesta, guardy a undo na živej skrinke).

## Robí sa

**BLOK UI-A JE KOMPLET** (UI-01 paleta a téma · UI-02 logo a toolbar · UI-03 combobox), **BLOK UI-B JE KOMPLET** (UI-B1 kostra · UI-B2 náhľad · UI-B3 obsah Korpusu + koliesko, vrátane dvoch dotiahnutí po teste a audite), **UI-C1 · Vkladanie JE KOMPLET** v troch PR (**C1a** #174 · **C1b** #175 · **C1c** #176) a **UI-C2 · Zóny JE HOTOVÁ** (tento PR). Inspector má celú kostru, kontextové projekcie a hotové kontexty Korpus, Vkladanie aj Zóny.

## Ďalší krok

**UI-C3 · Čelá** — obsah kontextu Čelá: riadky s ikonou typu (N27), úzke pole výšky s „mm" pri hodnote a chipom AUTO na návrat (zámok pri výške je zrušený — zamknuté ⇔ vypísané), výškové rady N25, naviazané kovanie pod riadkom s preklikom do Kovania, materiál čela priamo v zozname, výklopná klapka s upozornením „AVENTOS ručne". Audit pred implementáciou povinný nie je (dátový kontrakt ani observery sa nemenia); in-SketchUp beh áno, ak sa dávka dotkne builderov.

## Posledné uzávery

- **UI-C2 Zóny** (štruktúra navrchu so stromovými spojnicami a najviac 3 úrovňami · delenie na štyri dlaždice · police ako pilulky **0–6** · presné delenie prvej zóny v mm aj zlomkom 1/4·1/3·1/2 · magnet 1/4·1/2·3/4 pri ťahaní priečky, Alt ho vypína · rozmer, ktorý sa nezmestí, sa **odmietne** namiesto tichého zmenšenia · deliť a dávať police smie len nerozdelená zóna, jedinou deštruktívnou cestou ostáva „Vyčistiť zónu" · poškodené označenie zóny už nepadne na koreň a nezmaže vnútro skrinky) — PR **tento**, v0.7.14 (19.8.)

- **BLOK UI-C1 UZAVRETÝ — Vkladanie** (**C1a** šablóna má druh `cabinet`/`board`, identita je dvojica druh+názov, seed troch doskových šablón, poradie „naposledy použité" vo vlastnom súbore · **C1b** typové tlačidlá, dlaždice šablón s náhľadmi a dvojklikom, doskové zámky, náhľad vkladania · **C1c** umiestnenie dosky naležato/nastojato/na stenu ako otočenie vloženej dosky, výrobné dáta sa ním nemenia) — PR **#174 · #175 · tento**, v0.7.10 → **v0.7.12** (18.8.)

- **UI-B dotiahnutie po audite** (logo = zrolovaná značka z originálnych kriviek v hlavičke aj v „O plugine", 24 px; meta súhrny v lištách všetkých štyroch sektorov — naživo; mŕtve `ui_theme` z pushu nastavení preč, téma má jediný kanál) — PR **#173**, v0.7.9 (18.8.)
- **FIX Základné a Materiály patria Korpusu** (v ostatných kontextoch ich nahradí tenký riadok s preklikom — nedotiahnutá mapa viditeľnosti z UI-B1) — PR **#171**, v0.7.8 (18.8.)
- **BLOK UI-B UZAVRETÝ** — **UI-B3 obsah Korpusu + koliesko** (Základné v 2 stĺpcoch: vľavo rozmery s ikonami a rozmerovými radmi N6, vpravo informačný stĺpec — vnútorné rozmery, dielcov, m², hmotnosť „—"; klik na „Dielcov" ich označí v modeli; ikony skupín Nastavení; mini-modal „Uložiť ako šablónu" s Názvom a Typom + typ badge v hlavičke; koliesko = téma NOXUN/Lucia so živým prepnutím vo všetkých oknách, editor rozmerových radov, O plugine) — PR **#170**, v0.7.7 (18.8.)
- **UI-B2 náhľad = kontextová projekcia + spodný pás** (Korpus čelný rez s kótami a náznakom hĺbky · Zóny + šírky · Čelá + výšky a medzery · **Kovanie nová projekcia**: závesy, koľajnice, nohy zo súpisu kovania · Dielec hrany; dole chipy vrstiev s ghost prisvietením, kamera N7 a fit) — PR **#169**, v0.7.5 (18.8.)
- **UI-B1 kostra Inspectora** (ľavá lišta kontextov Korpus·Zóny·Čelá·Kovanie + dočasný dielec/doska s krížikom + ABS kontrola + Štúdio; obsah v 4 sektoroch Náhľad·Základné·Materiály·Nastavenia s exkluzívnymi skupinami; šírka 470 px a štandard rozmerov okien D-51; hlavička jednoradová, režimové taby a satelitné tlačidlá zanikli — uzatvára aj D-91) — PR **#168**, v0.7.4 (18.8.)
- **BLOK UI-A UZAVRETÝ** (UI-01 #165 · UI-02 #166 · UI-03 #167) — značka, toolbar a najčastejšia akcia merača sú hotové; **v0.7.3** (18.8.)
- **UI-03 D-85 zdieľaný combobox materiálov a ABS** (písanie s filtrom bez diakritiky, „Použité v projekte" + „Naposledy použité"; jeden komponent na 12 miestach, rozbaľovačka ostala zdrojom pravdy → guardy E-03/D-86/D-41 bežia nezmenene; napĺňa aj odloženú D-16) — PR **#167**, v0.7.3 (18.8.)
- **UI-02 logo ikony + SketchUp toolbar** (toolbar „Noxun Engine": Inspector ako prepínač · Štúdio (dočasne okno Výroba) · ABS kontrola hrán ako prepínač · Vložiť skrinku) — PR **#166**, v0.7.2 (18.8.)
- **UI-01 paleta NOXUN teal + rádius 6 + mechanizmus témy Lucia** (prvá dávka bloku UI-A) — PR **#165**, v0.7.1 (18.8.)
- **BLOK ŠTART AUTONÓMIE UZAVRETÝ** (D-101 #162 · D-86 #163 · D-77 #164) — checkpoint **v0.7.0** (12.8.)
- **D-77 okná sa neotvárajú odseknuté** (väčšie východzie rozmery a minimá všetkých okien + dorovnanie zapamätanej veľkosti pri otvorení oboma smermi — nahor po minimum, nadol po plochu obrazovky) — PR **#164**, v0.7.0 (12.8.)
- **D-86 guard smeru dekoru vo vkladacej karte** (vedomá voľba prežije živý refresh katalógu z okna Materiály; pole sa mení len pri skutočnej zmene materiálu) — PR **#163**, v0.6.2 (12.8.)
- **D-101 panel po Späť/Znova** (Ctrl+Z aj Ctrl+Y obnovia Inspector sám — čisté čítanie bez nového kroku Späť, zlúčenie rýchlych vrátení) — PR **#162**, v0.6.1 (12.8.)
- **RETRO — workflow retrospektíva** (risk-based codex-audit, pravidlo 3 kôl, autonómne bloky s merge po bránach, denný report; blok ŠTART AUTONÓMIE predsunutý) — PR **#161** (12.8.)
- **ETAPA UPRATANIE UZAVRETÁ** (U1–U4, PR **#157–#160**) — checkpoint **v0.6.0** (11.8.)
- **U4 presuny a checkpoint** (premenovanie súborov na mená bez čísel, pôvodná vízia a návrh panela do archívu, ARCHIWOOD do zdrojov, README, bump v0.6.0) — PR **#160** (11.8.)
- **U3 diéta CLAUDE.md** (architektúra do vlastnej referencie [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md), tabuľka povinného čítania podľa typu zásahu) — PR **#159** (11.8.)
- **U2 čistka dogfooding zápisníka** (otvorené postrehy v skupinách podľa blokov, história do archívu, merač do zdrojov) — PR **#158** (11.8.)
- **U1 navigácia docs (STAV · PLAN · KRONIKA)** — PR **#157** (11.8.)
- **D-93 ručný zámok dĺžky výsuvu** — PR **#156**, v0.5.61 (11.8.)
- **Séria okolo zákazky KLINIKA** (D-90…D-105: úchytkový profil UKW-7, kovanie v paneli, živé názvy, farba ABS na hranách, kontrola hrán v modeli) — PR **#144–#155**, v0.5.49 → v0.5.60 (9.–11.8.)
- **Materiály 2.0 KOMPLET + dávky D a E** (identita dekorov, Demos konektor, sety kovania, rozpočet a cenová ponuka) — PR **#89–#140**, do v0.5.48 (30.7.–6.8.)

Plné texty všetkých uzáverov a starších etáp: [archiv/KRONIKA.md](archiv/KRONIKA.md).

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [STANDARD.md](STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [DOGFOODING.md](DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [POJMY.md](POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) + invarianty | [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md) |
| workflow, verzie, uzáver dávky, testovanie, čo si pred zásahom prečítať | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| smer UI | [UI_VIZIA.md](UI_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, prieskumy dodávateľov, seed podklady | [zdroje/](zdroje/) |
