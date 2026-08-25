# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.8.3 · 25.8.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu a overená proti ručnému rozpočtu.
Nálezy z reálnej výroby a chyby v cenách majú preto **najvyššiu prioritu triedenia** ([PLAN.md](PLAN.md), Pravidlo pre postrehy).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru sa nastavuje na dielci a čele a dá sa vizuálne skontrolovať). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Testy k v0.8.3:** 1894 headless · 67 JS sád · posledný plný in-SketchUp beh **969 PASS / 0 FAIL** (vetva #227; novšie dávky boli klientske alebo dokumentačné).

> **Poznámka k procesu:** Codex review bol 21.–24.8. **nedostupný** — PR **#186–#226** prešli bránou so slepým subagentom (audit pred kódom + review pred mergom, 15 kôl). Od **#227** review robí zase Codex, takže **post-hoc sweep sa týka presne #186–#226** ([PLAN.md](PLAN.md), blok 1b/E).

## Robí sa

**BLOK DOCS CLEANUP — upratovanie dokumentácie, bez zmeny kódu pluginu.** Docs sú pamäť agentov; cieľom je, aby mal každý živý dokument JEDNU rolu, história bola v archíve a pravidlá strážili guardy.

- **A — HOTOVÁ** (PR **#232**, 26.8.): mapa modulov sa rozdelila z jedného 260 kB súboru do `docs/architecture/` (6 tematických súborov, rozcestník ostal v `docs/ARCHITEKTURA.md`). Nové guardy: **žiadny riadok nad 400 znakov** a **pokrytie modulov** — každý ruby modul `core/`, `modules/` aj `ui/` musí mať vlastný nadpis `### <meno>.rb`, riadok v tabuľke rozcestníka a jednoznačné meno súboru.
- **B — TÁTO DÁVKA** (26.8.): to isté upratanie pre `SYSTEM/` — nová mapa autorít [README.md](README.md), STAV prepísaný nakrátko, hotový blok UI 2.0 a index vyriešených
  D-čísel do archívu, vízie do archívu, koncepty v `zdroje/next_sessions/` označené statusom, guardy rozšírené (veľkosť STAV, dĺžka riadku, „hotové veci patria do archívu").
- **C — NASLEDUJE:** refresh [STANDARD.md](STANDARD.md) (má ešte dlhé riadky, preto sa do guardu dĺžky pridáva až dávkou C).

## Ďalší krok

**MICHAL VEČER — najprv INSTALL z čerstvého mainu** (`INSTALL_noxun_engine.ps1`), potom test. Netestovaných je **PICKER-2** (PR #231 — jeden riadok na dekor, hrúbky ako čipy, duplák len vedomým klikom) a **8 dávok fázy ŠTÚDIO** (#220 … #227).
**Plné testovacie checklisty ku každej z nich sú v [archiv/KRONIKA.md](archiv/KRONIKA.md)** (záznam „Docs cleanup B", sekcia prenesených checklistov) — sem sa už nekopírujú, aby STAV ostal krátky.

**Potom podľa [PLAN.md](PLAN.md):** dorobenie vyhľadávača **PICKER-3** (osem nálezov z kola 3 review #231, z toho bod E je návrhová zmena) · **stabilizačná revízia** (blok 1b — dlhy fázy ŠTÚDIO; od začiatku produkcie naostro sa ešte nekonala) · potom blok **KOVANIE** (D-109 · D-110 · D-111 z prvého testu v0.8.0).

## Posledné uzávery

- **Docs cleanup A — mapa modulov rozdelená na 6 súborov** + guardy dĺžky riadku a pokrytia modulov — PR **#232** (26.8.), bez zmeny kódu pluginu
- **PICKER-2 — riadok je dekor, hrúbka je čip** (zoskupenie v rámci rovnakého typu dosky, predvoľba podľa kontextu, duplák nikdy sám) — PR **#231**, v0.8.3 · pred ním **PICKER-1 — jeden vyhľadávač aj v Predvoľbách projektu** — PR **#230**, v0.8.2 (25.8.)
- **TEST-1 — prvé nálezy z testu v0.8.0 naostro** (nová položka katalógu je hneď vidieť, orezanie zoznamu sa priznáva číslom, vysvetlivka úchytiek podľa roly) — PR **#229**, v0.8.1 (24.8.)
- **ŠT-4b — UZÁVER FÁZY ŠTÚDIO** (docs + minor bump **v0.8.0**, plný uzáver fázy v KRONIKE, PLAN blok 1b s dlhmi) — PR **#228** (24.8.)
- **ŠT-4a — Nastavenia ako sekcie, ZANIKOL POSLEDNÝ SATELIT** (s oknom zanikla aj celá mašinéria premostení) — PR **#227**, v0.7.69 (24.8.)
- **ŠT-3c — Šablóny sekciou + zánik okna Šablóny** (#225) a **premenovanie šablóny** vrátane presunu fotky a poradia (#226)
- **ŠT-3a/3b — Kovanie a Pravidlá sekciami + zánik oboch okien** (#216 · #218 · #219 · #220) · ABS podľa roly, jantárové riadky a „vrátiť na pravidlo" (#221 · #222) · serverová validácia pravidiel a odtlačok proti tichému prepisu (#223 · #224)
- **ŠT-2 — Materiály sekciou + zánik okna Materiály**, D-69 jednotný editor dekoru, „Kde sa používa" (#205 · #206 · #208 + #212 + #213 · #214)
- **ŠT-1 — skelet Štúdia, Kusovník, Kontrola, Nákup, Rozpočet, Cenová ponuka + zánik okna Výroba** (#192 · #193 · #195 · #197–#200) a smoke opravy po teste 22.8. (#202 · #203)
- **Blok KRESBA** — smer dekoru per dielec (#185), výrobné fixy odpojeného dielca (#186 · #187), vizuálna kontrola smeru kresby (#188), kontrola kresby a 3-stavová ABS kontrola v raile (#189 · #190) — v0.7.23 → v0.7.28 (21.8.)
- **Staršie uzávery** (bloky UI-A · UI-B · UI-C · UI-D #165–#184 · ŠTART AUTONÓMIE #162–#164 · RETRO #161 · etapa UPRATANIE #157–#160 · séria KLINIKA #144–#156 · Materiály 2.0 a dávky D/E #89–#140) — plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md)

## Kam sa pozrieť

| Keď riešiš… | Dokument |
|---|---|
| ktorý dokument je autorita na čo (mapa `SYSTEM/`) | [README.md](README.md) |
| dátový kontrakt — dictionary, roly, identita, plán, mm Float | [STANDARD.md](STANDARD.md) |
| čo sa ide robiť, bloky prác, zaradenie D-čísel | [PLAN.md](PLAN.md) |
| otvorené postrehy z praxe (plné znenie D-čísel) | [DOGFOODING.md](DOGFOODING.md) |
| „prečo je X takto?" — história dávok, etáp a rozhodnutí | [archiv/KRONIKA.md](archiv/KRONIKA.md) · [archiv/](archiv/) |
| pojmy, stolárska doména, fakty o materiáloch a kovaní | [POJMY.md](POJMY.md) |
| pravidlá písania kódu — SketchUp / DC / UI dizajn | [../docs/SKETCHUP_PRAVIDLA.md](../docs/SKETCHUP_PRAVIDLA.md) · [../docs/DC_PRAVIDLA.md](../docs/DC_PRAVIDLA.md) · [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) |
| architektúra modulov (core / modules / ui) + invarianty | rozcestník [../docs/ARCHITEKTURA.md](../docs/ARCHITEKTURA.md) → mapa v [../docs/architecture/](../docs/architecture/) |
| workflow, verzie, uzáver dávky, testovanie | [../CLAUDE.md](../CLAUDE.md) |
| cieľ — čo znamená „V1 hotové" a nemenné princípy | [V1_VIZIA.md](V1_VIZIA.md) |
| kontrakt výstupu do VEPO | [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) |
| rešerše, koncepty, prieskumy dodávateľov (nezáväzné) | [zdroje/](zdroje/) |
