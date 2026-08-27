# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.8.10 · 27.8.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu a overená proti ručnému rozpočtu.
Nálezy z reálnej výroby a chyby v cenách majú preto **najvyššiu prioritu triedenia** ([PLAN.md](PLAN.md), Pravidlo pre postrehy).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru sa nastavuje na dielci a čele a dá sa vizuálne skontrolovať). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Testy k v0.8.10:** **1952 headless** · 70 JS sád · posledný plný in-SketchUp beh **1036 PASS / 0 FAIL / 0 SKIP** (dávka **1b-5** — dorovnanie sady `CHAR`, +14 assertov).

> **Poznámka k procesu:** Codex review bol 21.–24.8. **nedostupný** — PR **#186–#226** prešli bránou so slepým subagentom. **Post-hoc sweep je od 27.8. HOTOVÝ** (34 PR cez Codex CLI + triáž 54 nezodpovedaných threadov): dve reálne P1 slepým kolám ušli a týždeň žili v `main`, obe sú dávno opravené — [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-E**.

## Robí sa

**Beží blok 1b · STABILIZAČNÁ REVÍZIA** ([PLAN.md](PLAN.md)). **Všetky tri brány sú HOTOVÉ:** **1b-1** (odrážka **A** — optimistický zámok Nastavení, v0.8.6; zastaraný pin už
neprežije návrat do sekcie a status po uložení netvrdí prepočet, ktorý neprebehol) · **1b-2** (odrážka **H** — charakterizačné in-SU scenáre; kópia, `*N`, Undo, prerušenie operácie,
scale a prepnutie modelu sú zapísané testami, takže **blok 1d už smie siahnuť na buildery a observery**; Ctrl+Y a dva dokumenty naraz ostávajú manuálne; sadu **dorovnala dávka 1b-5** — štyri asserty merali slabšiu veličinu, než tvrdili) · **1b-3** (odrážka **G** —
**„Obnoviť" už do modelu nezapisuje**; duplicitné ID sa miesto tichej opravy priznajú oranžovým riadkom Kontroly, opravu robí len reálny zásah do modelu).
**Staré dlhy B a D sú vybavené** dávkou **1b-4** (v0.8.8), **sweep E je hotový** (27.8.); mimo písmen vybavené aj **1b-6a** (názov zákazky prežije Ctrl+S, v0.8.9) a **1b-7** (tichý návrat starej ceny dekoru, v0.8.10).
**Ďalej z bloku 1b:** **1b-6b** (nerozlíšiteľné hlavičky skupín materiálov) · **1b-6c** (zámok nad `vepo_settings.json`, audit-povinná) · **F** (UI dlhy — **D-27** · **D-51** · výklop ako samostatný typ čela).
Poradie určuje Michal. **Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**VEĽKÝ TEST JE HOTOVÝ (26.8. večer):** v0.8.4 nainštalovaná, **PICKER-2 aj všetkých 8 dávok fázy ŠTÚDIO (#220–#227) prešlo — všetko PASS, žiadny nález**; Michal vecne potvrdil aj ABS defaulty rolí. Záznam v [archiv/KRONIKA.md](archiv/KRONIKA.md). **PICKER-3 je HOTOVÝ** (v0.8.5) — vyhľadávač materiálov je dorobený (detail v uzávere nižšie).

**Poradie ďalšej práce (Michal 26.8., večer doplnená hardening sekvencia):** **1b stabilizačná revízia** → **1c AUDIT KÓDU** (read-only; traja audítori, podklad
[zdroje/AUDIT_2026-08_podklad.md](zdroje/AUDIT_2026-08_podklad.md), výstup register nálezov) → **1d refaktor z registra** → **1e plánovacia dávka** (task packages zo všetkých
konceptov) → **GHOST VKLADANIE** → **KOVANIE** (najprv USER-debata o setoch). V1 rozsah zoštíhlený — checklist v [V1_VIZIA.md](V1_VIZIA.md). Dávky štartujú na Michalovo „štartuj".

## Posledné uzávery

- **1b-7 — koniec tichého návratu starej ceny dekoru** (editor prelieva už len bunky, ktorých si sa dotkol; pri strete ukáže *tvoja × v katalógu* a bez rozhodnutia neuloží) — v0.8.10 (27.8.) · **Michal večer:** oprav cenu dekoru, daj **Esc**, spusti „Aktualizovať z Demosu", otvor ten istý dekor — nová cena musí ostať.
- **1b-E — POST-HOC SWEEP KOMPLET** (odrážka E bloku 1b: 34 PR spätne cez Codex CLI + triáž 54 nezodpovedaných threadov; 29 nálezov — 18 vyriešených, 1 zaniknutý, 10 platných) — bez zmeny kódu (27.8.) · **z toho vzišli otvorené dávky 1b-7 a 1b-6b**; kandidáti pre blok 1c sú v [zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md).
- **1b-6a — názov zákazky prežije prvé uloženie** (dovtedy sa po Ctrl+S všetky štyri exporty pomenovali podľa `.skp` súboru; nález z post-hoc triáže #193; úzky re-rez po zatvorení PR #243 pravidlom 3 kôl — zámok ostáva na **1b-6c**) — v0.8.9 (27.8.) · **Michal večer:** nový model → v Štúdiu napíš názov zákazky → Ctrl+S → VEPO export sa musí volať podľa zákazky.
- **1b-4 — drobnosti sekcií Šablóny a Pravidlá** (odrážky B + D: PNG retry a dávkovanie, orezaný payload šablón; lenivý katalóg pások, víťaz pri vypnutej položke) — v0.8.8 (27.8.) · **Michal večer:** v **Šablónach** sa fotky dlaždíc majú doplniť po chvíli a **všetky**; v **Pravidlách** má poradie jantárových riadkov ostať rovnaké a vypnutá položka kovania má hovoriť „vypnuté".
- **1b-3 — „Obnoviť" = čisté čítanie** (brána G: zber už nespúšťa dedup; duplicitné ID sa priznajú ORANGE riadkom Kontroly aj s výrobným dôsledkom, oprava = zápisová cesta) — v0.8.7 (27.8.) · **Michal večer:** v Štúdiu klikni „Obnoviť" a skús Späť — zoznam krokov sa refreshom nesmie meniť; po skopírovaní skrinky môže na okamih blysnúť oranžový riadok „Skrinky s ID … sú v modeli 2×".
- **1b-2 — charakterizačné in-SU scenáre** (brána H: kópia · `*N` · Undo · prerušenie operácie · scale = regenerate · prepnutie modelu; +34 assertov, bez zmeny kódu, 27.8.) · **1b-1 — optimistický zámok Nastavení** (zastaraný pin nezostane po návrate do sekcie; status hovorí pravdu, keď prepočet zlyhá) — v0.8.6 (27.8.)
- **PICKER-3 — dorobenie vyhľadávača** (virtuálny duplák v menovke, kanonický kľúč rodiny, „54 duplák", dôvod čipu z klávesnice, **kontext radí aj riadky**) — v0.8.5 (26.8.)
- **BLOK DOCS CLEANUP KOMPLET (26.8.)** — **C: refresh STANDARD.md** (zastarané tvrdenia opravené proti kódu, reflow, guard dĺžky bez výnimiek) PR **#234**, bez zmeny kódu pluginu ·
  **B: upratané `SYSTEM/`** (mapa autorít, archív, guardy) PR **#233**, v0.8.4 · **A: mapa modulov rozdelená na 6 súborov** + guardy dĺžky riadku a pokrytia modulov PR **#232**
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
