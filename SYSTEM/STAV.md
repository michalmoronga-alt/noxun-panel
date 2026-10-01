# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR, ktoré mení stav bloku, smoke alebo poradie prác, aktualizuje faktický stav v „Stav" (verzia a čísla testov sa nemenia) a prepíše „Robí sa" a „Ďalší krok" (od 1.10.2026); ostatné ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.17.12 · 1.10.2026 — blok 9 HARDENING; dávka H12b hotová** (PR #?): **aj panel (serverová strana Inspectora a šablón) číta typy skriniek z jedného registra**
a Inspector aj Štúdio ho od servera dostávajú (zatiaľ ho nečítajú — H12c). **Pre teba sa nemení nič:** vkladanie, úpravy, šablóny, strana rohovej, kusovník, VEPO,
nákup a rozpočet štyroch typov sú **bajtovo rovnaké** (odtlačok spred zásahu; šablóna s prázdnym typom sa na dolnú skrinku ďalej nepoužije).
Pod tým **H12a** (v0.17.11, PR #446): register typov v jadre · **H11b** (v0.17.10, PR #445): minimum SketchUp 2026 · **H10b/H10a** (v0.17.9/v0.17.8, PR #444/#443): dve okná SketchUpu sa neprebíjajú pri radoch ani pravidlách kovania · **H9** (v0.17.7, PR #442): poškodený súbor nastavení nezničí dobrú zálohu · **H8** (v0.17.6, PR #441): kus z inej verzie štandardu = oranžový riadok
· **H5/H4b/H4a** (v0.17.3–v0.17.5, PR #437–#440): mapa okien, texty, vzhľad, čísla v Štúdiu všade rovnako · **H3a/H3b** (v0.17.1–v0.17.2, PR #435–#436): bez zavádzajúcich údajov a falošnej chyby po **Súbor → Nový** — **čísla a exporty bez zmeny**.
Pod tým **BLOK CENY UZAVRETÝ** (v0.17.0, 30.9.; štart #425, PR #426–#429; **smoke PASS 30.9.**, PR #431): doska a ABS páska **bez Demosu** majú **odkaz na produkt** a **ručné overenie ceny** (Materiály aj Rozpočet; D-148), Rozpočet ukazuje vek ručných cien
a **„N cien na kontrolu"**; **materiál bez formátu — sklo aj bežná doska (C14) — sa počíta podľa skutočných m² dielcov** bez odpadu (porez a montáž bez zmeny, Q1).
Pod tým **blok 2 · KONTROLA + VÝROBA** (v0.16.0, smoke **PASS 29.9.**), **blok 8 · K3 ROHOVÁ** (v0.15.0, smoke PASS 28.9.), **blok 7 · K1+K2** (v0.14.0). Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka, **štrnásť živých sekcií**).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
**Všetkých sedem bodov V1 je odškrtnutých** ([V1_VIZIA.md](V1_VIZIA.md); Výstupy blokom CENY 30.9.) — **V1 je hotové**. Hardeningové body **R-13 (✅ H8) → R-37 (✅ H9) → R-35 (✅ H10a/H10b)** sú dávky **H8–H10 bloku 9** ([PLAN.md](PLAN.md)); **test na kompletnej reálnej zákazke je akceptačný test po V1** (C13).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE** (v0.9.0) · **blok KOVANIE** (v0.10.0)
· **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) · **blok KONŠTRUKCIA K1+K2** (v0.14.0) · **blok K3 ROHOVÁ** (v0.15.0) · **blok 2 KONTROLA + VÝROBA** (v0.16.0) · **blok CENY** (v0.17.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 22** (typ `corner_blind`), **doska v schéme 2**, **šablóny v STD 7**, výrobný plán v **schéme 7**, ABS pravidlá
v **seede 6** — starší plugin zákazku neprestaví ani nevyexportuje (rohovú by sklopil na dolnú). **Dáta rozpočtu sú od NP-4 v `BUDGET_STD` 3** (prvá úprava rozpočtu
v0.15.4 zapíše 3 — potom v0.15.3 a starší zákazku v Rozpočte needituje a zastaví oba cenové exporty). **Nastavenia dodávateľa sú od NP-2 vo verzii súboru 2** (v0.15.1 a starší pri uložení nové polia zahodí).
**Katalóg materiálov je po prvom uloženom odkaze v schéme 11 a po prvom ručnom overení ceny v schéme 12** — starší plugin ho ďalej číta (aj Rozpočet), ale nezapíše doň.
**Plugin beží len v SketchUpe 2026+** (0.17.10+; obe PC majú 2026). **Ochranu pred poškodeným súborom nastavení (H9) má len 0.17.7+, ochranu dvoch okien 0.17.8+ (pravidlá) a 0.17.9+ (rady) — aktualizovať obe PC a potom zavrieť všetky okná SketchUpu** (staré okno zapisuje bez ochrany).
**Aktualizuj plugin na oboch PC (Michal aj Lucia) na 0.17.0 pred prvým uložením odkazu, ručným overením ceny alebo porovnávaním a posielaním ponúk — starší plugin počíta sklo aj dosku bez formátu po starom** (`BUDGET_STD` blok CENY nemení, takže starší plugin nevaruje).

**Testy (H12b, PR #?):** **5131 headless · 151 JS sád** zelené + encoding guard; in-SU **3366 / 0** na `ddb82b8c` (SketchUp 2026, golden `run_h12` bajtovo rovnaký, `run_h12b` akcie panela).

## Robí sa

**Blok 9 · HARDENING PO V1** (štart 1.10.2026, PR #432): krížový audit V1 sedmimi audítormi → Michalovo triedenie **35 Teraz · 29 Po V1 · 11 vyradených**; 17 dávok **H1…H17** sekvenčne podľa tabuľky v [PLAN.md](PLAN.md), **bez zmeny výrobných a cenových čísel**; priečinok bloku [zdroje/bloky/HARDENING/](zdroje/bloky/HARDENING/).
Hotové **H1–H5** (PR #433–#440), **H8–H10b** (R-13, R-37, R-35 — PR #441–#444), **H11b** (minimum 2026, PR #445), **H12a** (register typov, PR #446) a **H12b** (panel z registra, PR #?); **H6/H7** čakajú na mockupy; **H11a** (príprava na 2026.2) čaká na Q1, **H11c** na aktualizáciu na 2026.2.
**Otázky bez odpovede, platí návrh:** H12 Q1 (karta dielca ako Kusovník — až H12d) · H11 Q2 (starší SketchUp = nenačíta sa, jedna hláška) · H11 Q1 (chyba súboru = vypnúť plugin, H11a) · H11 Q3 (kedy 2026.2) · H10b Q2 (rôzne rady sa zlúčia bez hlášky, ten istý rad = hláška) · H10a Q1 (cudzí globál = neuloží sa nič)
· H9 Q1/Q2 (pri čítaní zo zálohy bez nálezu v Kontrole, bez tlačidla „Obnoviť zo zálohy") · H8 Q1/Q2 (veta o značke verzie, bez tlačidla) · H4b Q1/Q2 (vrátenie katalógu v ponuke „⋯" Materiálov, ikona posuvníkov pre Nastavenia rozpočtu).
**H6 a H7 čakajú na schválený mockup** (R-38 v H7 potvrdí Michal) · **Q1** (porez a montáž pri skle) bez odpovede · pri prvej rohovej v dielni overiť záves Sensys · **na smoke čakajú** D-132 (#367), D-133 (#368), D-134 (#369).

## Ďalší krok

Pokračovať blokom 9: **H12c** (JS z dát servera — `cabinet_types`, `type_word`, `type_scope`), **H12d** (mená rolí); **H11a** (príprava na 2026.2); **H6** a **H7** čakajú na schválenie mockupov Michalom; potom H13–H17; uzáver bloku = minor verzia + smoke
(smoke H3a + H3b: 7 bodov v [PACKAGE_H3.md](zdroje/bloky/HARDENING/PACKAGE_H3.md) §10; H4a + H4b: body 1–11 v [PACKAGE_H4.md](zdroje/bloky/HARDENING/PACKAGE_H4.md) §10; vzhľad rozbaľovačiek a výberu nôh v SketchUpe overí smoke bod 7;
H8: 4 body v [PACKAGE_H8.md](zdroje/bloky/HARDENING/PACKAGE_H8.md) §10 — reálna zákazka bez nového riadku a s rovnakými číslami; H9: 5 bodov v [PACKAGE_H9.md](zdroje/bloky/HARDENING/PACKAGE_H9.md) §10 — rovnaké čísla rozpočtu, hrán a nákupu, ochrana naživo voliteľne;
H10a + H10b: body 1–6 v [PACKAGE_H10.md](zdroje/bloky/HARDENING/PACKAGE_H10.md) §10 — dve okná, testovacie modely, `hardware_rules.json` a `dim_series.json` zálohovať;
H11b: 3 body v [PACKAGE_H11.md](zdroje/bloky/HARDENING/PACKAGE_H11.md) §B7; H12: 6 bodov v [PACKAGE_H12.md](zdroje/bloky/HARDENING/PACKAGE_H12.md) §10 — po H12c, bod 6 po H12d). Ak druhé PC ešte nemá 0.17.0, aktualizovať (Kompatibilita vyššie). **Test na reálnej zákazke po V1.**

## Posledné uzávery

- **BLOK CENY UZAVRETÝ** (**v0.17.0**, 30.9.2026; štart #425, CENY-M1a #426 v0.16.1 · CENY-M1b #427 v0.16.2 · CENY-M2 #428 v0.16.3 + uzáver PR #429).
  Odkaz a ručné overenie ceny dosky/ABS bez Demosu, Rozpočet s vekom ručných cien, materiál bez formátu podľa m²; priečinok bloku v [archiv/bloky/CENY/](archiv/bloky/CENY/).
  [Výsledok, dávky a checklist](archiv/CENY_ZAVER_2026-09-30.md).
- **BLOK 2 · KONTROLA + VÝROBA UZAVRETÝ** (**v0.16.0**, 29.9.2026; nárezový plán: štart #417, PR #418–#421 + uzáver PR #422; **smoke PASS 29.9.**, PR #423).
  Nárezový plán v Štúdiu, nastavenia prerezu/orezu/prídavku, Kontrola s orezom, ceny podľa plánu; priečinok bloku v [archiv/bloky/NAREZ/](archiv/bloky/NAREZ/).
  [Výsledok, dávky a checklist](archiv/NAREZ_ZAVER_2026-09-29.md).
- **BLOK 8 · K3 ROHOVÁ SKRINKA UZAVRETÝ** (**v0.15.0**, 28.9.2026, PR #410–#414; smoke **PASS 28.9.**) — [výsledok](archiv/ROHOVA_ZAVER_2026-09-28.md), priečinok [archiv/bloky/ROHOVA/](archiv/bloky/ROHOVA/) ·
  **BLOK 7 · K1+K2** (**v0.14.0**, PR #401–#405; smoke **PASS 27.9.**) — [výsledok](archiv/KONSTRUKCIA_ZAVER_2026-09-27.md), priečinok [archiv/bloky/KONSTRUKCIA/](archiv/bloky/KONSTRUKCIA/) ·
  **BLOK SPOTREBIČE S1** (v0.13.0, PR #375–#390; smoke PASS 26.9.) — [výsledok](archiv/S1_ZAVER_2026-09-24.md).
- **REWORK KONTEXTU ČELÁ** — **D-130b** (v0.12.8, #372) a **D-130a** (v0.12.7, #371) · **D-134** jednotný rozsah hromadných zápisov (v0.12.6, #369) ·
  **D-133** „Nahradiť UNI…" (v0.12.5, #368) · **D-132** dormantný zámok (v0.12.4, #367) · **D-131** Kresba čiel (v0.12.3, #365) — plné znenia v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **BLOK M-R VZHĽAD UZAVRETÝ** (v0.11.1 → **v0.12.0**, 11.–12.9.2026, PR #353–#359) · **BLOK KOVANIE UZAVRETÝ** (v0.9.14 → **v0.10.0**, 2.–10.9.2026; 50 PR
  #277–#340; otvorené ostáva **D-109**, R-05 po V1) · **staršie uzávery** (v0.9.x až V0.1) — [archiv/KRONIKA.md](archiv/KRONIKA.md) a [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| ktorý dokument je autorita na čo (mapa `SYSTEM/`) | [README.md](README.md) |
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [STANDARD.md](STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [DOGFOODING.md](DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| plné texty hotových blokov a etáp (vrátane KOVANIA) | [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [POJMY.md](POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) + invarianty | rozcestník [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md) → mapa v [../docs/architecture/](../docs/architecture/) |
| workflow, verzie, uzáver dávky, testovanie | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, koncepty, prieskumy dodávateľov (nezáväzné) | [zdroje/](zdroje/) |
