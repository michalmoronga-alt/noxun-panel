# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** STAV sa **PREPÍŠE pri každom zvýšení VERSION** (aj pri malom fixe; nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md).
> Dokumentačné PR, ktoré mení stav bloku, smoke alebo poradie prác, aktualizuje faktický stav v „Stav" (verzia a čísla testov sa nemenia) a prepíše „Robí sa" a „Ďalší krok" (od 1.10.2026); ostatné ho nemenia. Testy: **jeden riadok posledného behu** — čísla starších behov patria do PR a KRONIKY. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.17.2 · 1.10.2026 — blok 9 HARDENING, dávka H3b** (PR #?): po **Súbor → Nový** a otvorení Štúdia už Ruby konzola nehlási falošnú chybu „invalid overlay"
(Smer otvárania, hrany, Smer kresby) — prekrytie zneplatnené SketchUpom sa len zabudne a kresba sa zapne nanovo; chyba živého dokumentu sa zapisuje ďalej.
Pod tým **H3a** (v0.17.1, PR #435): Štúdio bez zavádzajúcich údajov (Kusovník, ponuka, Kontrola, Nákup, sadzby) — **čísla, CSV, XLSX a VEPO bez zmeny**.
Pod tým **BLOK CENY UZAVRETÝ** (v0.17.0, 30.9.; štart #425, PR #426–#429; **smoke PASS 30.9.**, PR #431). Doska a ABS páska **bez Demosu** majú **jeden odkaz na produkt** a **ručné overenie ceny** v Štúdiu → Materiály aj v Rozpočte (doska za platňu s prepočtom
na €/m², sklo bez formátu za m², ABS za bm; „Potvrdiť cenu k dnešku" nedotknutú cenu nezmení ani o cent; zmena overených polí overenie zruší; Demos má prednosť;
D-148). Rozpočet ukazuje vek ručných cien („ručne 18.9." / „neoverená") a počíta ich medzi **„N cien na kontrolu"**; **materiál bez formátu — sklo aj bežná
doska (C14) — sa počíta podľa skutočných m² dielcov** bez odpadu (UNI a duplák bez väzby na odhade platní; porez a montáž bez zmeny, Q1).
Pod tým **blok 2 · KONTROLA + VÝROBA** (v0.16.0, smoke **PASS 29.9.**), **blok 8 · K3 ROHOVÁ** (v0.15.0, smoke PASS 28.9.), **blok 7 · K1+K2** (v0.14.0). Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
so **štrnástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · **Nárezový plán** · Materiály · Kovanie · Spotrebiče · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine. Neaktívna položka navigácie už nie je žiadna.

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).
**Všetkých sedem bodov V1 je odškrtnutých** ([V1_VIZIA.md](V1_VIZIA.md); Výstupy blokom CENY 30.9.) — **V1 je hotové**. Hardeningové body **R-13 → R-37 → R-35**
sú dávky **H8–H10 bloku 9** ([PLAN.md](PLAN.md)); **test na kompletnej reálnej zákazke je akceptačný test po V1** (C13).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(v0.9.0) · **blok KOVANIE** (v0.10.0) · **blok M-R VZHĽAD** (v0.12.0) · **blok SPOTREBIČE S1** (v0.13.0) · **blok KONŠTRUKCIA K1+K2** (v0.14.0) · **blok K3 ROHOVÁ**
(v0.15.0) · **blok 2 KONTROLA + VÝROBA** (v0.16.0) · **blok CENY** (v0.17.0) — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
**Kompatibilita:** skrinka je v **schéme 22** (typ `corner_blind`), **doska v schéme 2**, **šablóny v STD 7**, výrobný plán v **schéme 7**, ABS pravidlá
v **seede 6** — starší plugin zákazku neprestaví ani nevyexportuje (rohovú by sklopil na dolnú). **Dáta rozpočtu sú od NP-4 v `BUDGET_STD` 3** (prvá úprava rozpočtu
v0.15.4 zapíše 3 — potom v0.15.3 a starší zákazku v Rozpočte needituje a zastaví oba cenové exporty). **Nastavenia dodávateľa sú od NP-2 vo verzii súboru 2** (v0.15.1 a starší pri uložení nové polia zahodí).
**Katalóg materiálov je po prvom uloženom odkaze v schéme 11 a po prvom ručnom overení ceny v schéme 12** — starší plugin ho ďalej číta (aj Rozpočet), ale nezapíše doň.
**Aktualizuj plugin na oboch PC (Michal aj Lucia) na 0.17.0 pred prvým uložením odkazu, ručným overením ceny alebo porovnávaním a posielaním ponúk — starší plugin
počíta sklo aj dosku bez formátu po starom** (`BUDGET_STD` blok CENY nemení, takže starší plugin nevaruje).

**Testy (H3b, PR #?):** **4969 headless · 147 JS sád** zelené + encoding guard; **in-SU 3284 PASS / 0 FAIL** (brána — prekrytia po novom súbore).

## Robí sa

**Blok 9 · HARDENING PO V1** (štart 1.10.2026, PR #432): krížový audit V1 sedmimi audítormi → Michalovo triedenie **35 Teraz · 29 Po V1 · 11 vyradených**;
17 dávok **H1…H17** sekvenčne podľa tabuľky v [PLAN.md](PLAN.md), **bez zmeny výrobných a cenových čísel**; priečinok bloku [zdroje/bloky/HARDENING/](zdroje/bloky/HARDENING/).
Hotové **H1** PR #433 · **H2** (fotenie okien) PR #434 · **H3a** (zavádzajúce údaje v okne) PR #435 · **H3b** (falošná chyba v Ruby konzole po novom súbore) PR #?; nasleduje **H4**.
**H6 a H7 čakajú na schválený mockup** (R-38 v H7 potvrdí Michal) · **Q1** (porez a montáž pri skle) bez odpovede · pri prvej rohovej v dielni overiť záves Sensys · **na smoke čakajú** D-132 (#367), D-133 (#368), D-134 (#369).

## Ďalší krok

Pokračovať blokom 9 v poradí tabuľky: **H4** → H5; medzitým mockupy **H6** a **H7** na schválenie Michalom. Potom **R-13 → R-37
→ R-35** ako **H8–H10** (**R-13 rozhodnuté 29.9.: čítať** — ORANGE „dielec z inej verzie štandardu") a refaktory H11–H17; uzáver bloku = minor verzia + smoke
(smoke H3a + H3b: 7 bodov v [PACKAGE_H3.md](zdroje/bloky/HARDENING/PACKAGE_H3.md) §10). Ak druhé PC ešte nemá 0.17.0, aktualizovať (Kompatibilita vyššie). **Test na reálnej zákazke po V1.**

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
