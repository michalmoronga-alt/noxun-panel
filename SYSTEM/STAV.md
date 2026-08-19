# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md).
> **Údržba:** pri uzávere dávky/etapy alebo zmene smeru sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide ako odsek do [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia.

## Stav

**v0.7.20 · 20.8.2026.** Etapa V0.6 (katalógy a ceny) je obsahovo splnená — plugin vie zákazku od návrhu cez materiály, ABS a kovanie až po VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku; upratovacia etapa U1–U4 uzavrela dokumentáciu a hygienu repa (checkpoint v0.6.0), blok ŠTART AUTONÓMIE (D-101 · D-86 · D-77, PR #162–#164) prebehol prvýkrát autonómne.

**INSPECTOR REWORK (UI 2.0) JE HOTOVÝ.** Koncept bol uzavretý 18.8. (Michal) — záväzný kontrakt a mockupy sú v repe: [zdroje/ui20/](zdroje/ui20/) ([UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md) + mockupy Inspector C, štúdio, dizajnový lístok). Všetky štyri bloky sú v maine: **UI-A · UI-B · UI-C · UI-D**. Zostáva fáza **ŠTÚDIO** ([PLAN.md](PLAN.md)).

Zákazka **KLINIKA** (254 dielcov) je postavená čisto z pluginu, prekontrolovaná a overená veľkým testom (porovnanie s ručným rozpočtom). Posledná zmena kódu: **UI-D3 · klikateľnosť a uzávery** — ⚠ chip otvára warnpanel s prekliknutím do modelu a do Kontroly, „Materiál" vedie do kusovníka. Testy: **1430 headless · 45 JS sád**; posledný **plný in-SketchUp beh 19.8. — 476 PASS, 0 FAIL** (UI-D3 in-SU beh nepotrebovala — čisté UI nad existujúcimi cestami).

## Robí sa

**Nič — blok UI-D je uzavretý a čaká sa na Michala.** Hotové: **UI-D1 Dielec** (#180) · **UI-D2 Náhľady šablón** (#181) · **UI-D3 Klikateľnosť a uzávery** (#182). Predošlé bloky: **UI-A** (UI-01 paleta a téma · UI-02 logo a toolbar · UI-03 combobox), **UI-B** (UI-B1 kostra · UI-B2 náhľad · UI-B3 obsah Korpusu + koliesko), **UI-C** (**C1 Vkladanie** #174 · #175 · #176 · **C2 Zóny** #177 · **C3 Čelá** #178 · **C4 Kovanie** #179). Inspector má celú kostru, kontextové projekcie, všetky kontexty (Korpus, Vkladanie, Zóny, Čelá, Kovanie, Dielec) aj dotiahnutú klikateľnosť.

## Ďalší krok

**Fáza ŠTÚDIO** — sektorová debata s Michalom nad `SYSTEM/zdroje/ui20/mockup_ui20.html` (Kusovník · Kontrola · Nákup · Rozpočet · presuny satelitných okien; D-69, zvyšok D-50). **NEZAČÍNAŤ bez Michala** — je to koncept, nie implementačná dávka: presne ako pri Inspectorovi sa najprv dohodne obsah sektorov a až potom sa reže na dávky.

**Otvorené rozhodnutia pre Michala (obe nad HOTOVÝM panelom):**

1. **D-26 — režimy panela.** Kontrakt UI 2.0 nechal otvorené, či má panel mať prepínač *Jednoduchý / Rozšírený*, alebo majú stačiť akordeóny „menej časté". Inspector rework je hotový, takže sa to dá posúdiť na živom paneli: ak je po dennej práci prehľadný, D-26 sa zavrie ako nepotrebné.
2. **Per-dielec smer dekoru.** UI-D1 nechala smer dekoru dielca ako **informáciu** (UI-D3 ju doplnila o preklik na materiál, ktorý smer určuje). Per-dielec override dnes neexistuje a jeho zavedenie mení výrobný kontrakt (kusovník, VEPO, nárez) — je to samostatná dávka s auditom, treba ju zadať zvlášť.

## Posledné uzávery

- **BLOK UI-D UZAVRETÝ — UI-D3 Klikateľnosť a uzávery** (⚠ chip v hlavičke otvára **panel upozornení**, ktorý sa vysunie *nad* obsah a nič neposunie · **každý nález má oko** — klik označí dotknutý dielec priamo v modeli (nález bez konkrétneho dielca označí celú skrinku) · dole tlačidlo **„Otvoriť v Štúdiu → Kontrola"**, ktoré otvorí okno Výroba rovno na tabe Kontrola · zatvorí ho klik vedľa alebo Escape · **„Materiál" v informačnom stĺpci** otvorí okno Výroba na tabe Kusovník — filter na jednu skrinku kusovník zatiaľ nemá a panel to povie nahlas · v karte dielca je **„Smer dekoru" preklikom** na materiál, ktorý ten smer určuje · UI_DIZAJN.md doplnený o všetko, čo bloky UI-A…D zaviedli) — PR **#182**, v0.7.20 (20.8.)

- **UI-D2 PNG náhľady šablón** (pri uložení šablóny sa **odfotí pohľad na skrinku** a dlaždica v paneli ním nahradí schematickú kresbu · fotí sa **aktuálny pohľad dorámovaný na skrinku** — vedomé rozhodnutie, izolovaný render by musel skrývať zvyšok modelu, čiže zapisovať doň · **kamera sa vždy vráti presne tam, kde bola** (perspektíva aj orto) a nevznikne ani jeden krok Späť · staršie šablóny, neúspešná fotka aj poškodený obrázok končia pri **schéme** a výška dlaždice sa nemení nikdy · pri prepise šablóny bez úspešnej fotky sa **starý obrázok zmaže** · obrázky žijú ako súbory vedľa knižnice, schéma `templates.json` sa nemenila · okno Šablóny zosúladilo poradie ukladania — najprv názov a potvrdenie prepisu, až potom dáta aj fotka z jedného snímku) — PR **#181**, v0.7.19 (19.8.)

- **UI-D1 Dielec** (karta dielca má **Základné hore** — Dĺžka/Šírka/Hrúbka a smer dekoru ako dopočítané údaje, nie polia · každá hrana má **ikonu s rotáciou podľa strany v náhľade** + farebný štvorec ABS · **„Označiť v modeli"** označí dielec bez toho, aby čokoľvek zapísalo alebo vyrobilo krok Späť · **„Použiť na podobné…"** prenesie olep hrán na dielce s **rovnakou rolou a rovnakým materiálom** — v modale sa volí rozsah *táto skrinka* / *celý projekt* a **živý počet** hovorí vopred, koľkých dielcov sa to týka; celý zápis je **jeden krok Späť**, aj keď zasiahne viac skriniek) — PR **#180**, v0.7.17 (19.8.)

- **BLOK UI-C UZAVRETÝ — UI-C4 Kovanie** (položky sú **horizontálne boxy podľa vlastníka**: „Skrinka", box každého čela a spoločný box „Vnútro skrinky" pre podperky políc; v boxe čela ostal výber setu, rad nominálnych dĺžok so zámkom aj nákupné riadky — nič sa nezmenilo, len sa preskupili · **klik na hlavičku boxu označí vlastníka priamo v modeli** a panel pritom ostáva v Kovaní · **klik na značku kovania v náhľade** (záves, koľajnica, noha) označí vlastníka a dotiahne jeho box · hover nad boxom prisvieti jeho značky v náhľade · sekcia sa rozdelila na tri skupiny **Položky · Sety · Pravidlá**) — PR **#179**, v0.7.16 (19.8.)

- **UI-C3 Čelá** (riadok začína ikonou typu N27 · úzke pole výšky 46 px, „mm" pri hodnote a **chip AUTO** namiesto zámku — zamknuté ⇔ vypísané · **výškové rady N25** napojené na rad `vyska_cela` z kolieska · pod riadkom **jeden drobný riadok naviazaného kovania** s preklikom do Kovania · **D-84** „+ pridaj dvere / + pridaj čelo", odoberacie tlačidlo zaniklo · materiál čiel priamo v zozname · **D-96 sekcia Úchytky** (profil pre rozsah čiel, ikona v riadku už len indikátor) · **N26** medzery v projekcii Čelá jantárovo pri editácii · **D-89a** hover hrany v karte dielca/dosky zvýrazní hranu priamo v MODELI. Výklop je v ponuke typov, ale zatiaľ neaktívny — rola `flap` potrebuje vlastnú dávku cez builder/ABS/kusovník) — PR **#178**, v0.7.15 (19.8.)

- **UI-C2 Zóny** (štruktúra navrchu so stromovými spojnicami a najviac 3 úrovňami · delenie na štyri dlaždice · police ako pilulky **0–6** · presné delenie prvej zóny v mm aj zlomkom 1/4·1/3·1/2 · magnet 1/4·1/2·3/4 pri ťahaní priečky, Alt ho vypína · rozmer, ktorý sa nezmestí, sa **odmietne** namiesto tichého zmenšenia · deliť a dávať police smie len nerozdelená zóna, jedinou deštruktívnou cestou ostáva „Vyčistiť zónu" · poškodené označenie zóny už nepadne na koreň a nezmaže vnútro skrinky) — PR **#177**, v0.7.14 (19.8.)

- **BLOK UI-C1 UZAVRETÝ — Vkladanie** (**C1a** šablóna má druh `cabinet`/`board`, identita je dvojica druh+názov, seed troch doskových šablón, poradie „naposledy použité" vo vlastnom súbore · **C1b** typové tlačidlá, dlaždice šablón s náhľadmi a dvojklikom, doskové zámky, náhľad vkladania · **C1c** umiestnenie dosky naležato/nastojato/na stenu ako otočenie vloženej dosky, výrobné dáta sa ním nemenia) — PR **#174 · #175 · #176**, v0.7.10 → **v0.7.12** (18.8.)

- **UI-B dotiahnutie po audite** (logo = zrolovaná značka z originálnych kriviek v hlavičke aj v „O plugine", 24 px; meta súhrny v lištách všetkých štyroch sektorov — naživo; mŕtve `ui_theme` z pushu nastavení preč, téma má jediný kanál) — PR **#173**, v0.7.9 (18.8.)
- **FIX Základné a Materiály patria Korpusu** (v ostatných kontextoch ich nahradí tenký riadok s preklikom — nedotiahnutá mapa viditeľnosti z UI-B1) — PR **#171**, v0.7.8 (18.8.)
- **BLOK UI-B UZAVRETÝ** — **UI-B3 obsah Korpusu + koliesko** (Základné v 2 stĺpcoch: vľavo rozmery s ikonami a rozmerovými radmi N6, vpravo informačný stĺpec — vnútorné rozmery, dielcov, m², hmotnosť „—"; klik na „Dielcov" ich označí v modeli; ikony skupín Nastavení; mini-modal „Uložiť ako šablónu" s Názvom a Typom + typ badge v hlavičke; koliesko = téma NOXUN/Lucia so živým prepnutím vo všetkých oknách, editor rozmerových radov, O plugine) — PR **#170**, v0.7.7 (18.8.)
- **UI-B2 náhľad = kontextová projekcia + spodný pás** (Korpus čelný rez s kótami a náznakom hĺbky · Zóny + šírky · Čelá + výšky a medzery · **Kovanie nová projekcia**: závesy, koľajnice, nohy zo súpisu kovania · Dielec hrany; dole chipy vrstiev s ghost prisvietením, kamera N7 a fit) — PR **#169**, v0.7.5 (18.8.)
- **UI-B1 kostra Inspectora** (ľavá lišta kontextov Korpus·Zóny·Čelá·Kovanie + dočasný dielec/doska s krížikom + ABS kontrola + Štúdio; obsah v 4 sektoroch Náhľad·Základné·Materiály·Nastavenia s exkluzívnymi skupinami; šírka 470 px a štandard rozmerov okien D-51; hlavička jednoradová, režimové taby a satelitné tlačidlá zanikli — uzatvára aj D-91) — PR **#168**, v0.7.4 (18.8.)
- **BLOK UI-A UZAVRETÝ** (UI-01 #165 · UI-02 #166 · UI-03 #167) — značka, toolbar a najčastejšia akcia merača sú hotové; **v0.7.3** (18.8.)
- **UI-03 D-85 zdieľaný combobox materiálov a ABS** (písanie s filtrom bez diakritiky, „Použité v projekte" + „Naposledy použité"; jeden komponent na 12 miestach, rozbaľovačka ostala zdrojom pravdy → guardy E-03/D-86/D-41 bežia nezmenene; napĺňa aj odloženú D-16) — PR **#167**, v0.7.3 (18.8.)
- **UI-02 logo ikony + SketchUp toolbar** (toolbar „Noxun Engine": Inspector ako prepínač · Štúdio (dočasne okno Výroba) · ABS kontrola hrán ako prepínač · Vložiť skrinku) — PR **#166**, v0.7.2 (18.8.)
- **UI-01 paleta NOXUN teal + rádius 6 + mechanizmus témy Lucia** (prvá dávka bloku UI-A) — PR **#165**, v0.7.1 (18.8.)
- **BLOK ŠTART AUTONÓMIE UZAVRETÝ** (D-101 panel po Späť/Znova #162 · D-86 guard smeru dekoru #163 · D-77 okná sa neotvárajú odseknuté #164) — checkpoint **v0.7.0** (12.8.)
- **RETRO — workflow retrospektíva** (risk-based codex-audit, pravidlo 3 kôl, autonómne bloky s merge po bránach, denný report; blok ŠTART AUTONÓMIE predsunutý) — PR **#161** (12.8.)
- **ETAPA UPRATANIE UZAVRETÁ** (U1 navigácia docs · U2 čistka zápisníka · U3 diéta CLAUDE.md · U4 presuny a checkpoint, PR **#157–#160**) — checkpoint **v0.6.0** (11.8.)
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
