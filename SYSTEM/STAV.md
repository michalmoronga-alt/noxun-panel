# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.8.16 · 30.8.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu a overená proti ručnému rozpočtu.
Nálezy z reálnej výroby a chyby v cenách majú preto **najvyššiu prioritu triedenia** ([PLAN.md](PLAN.md), Pravidlo pre postrehy).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru sa nastavuje na dielci a čele a dá sa vizuálne skontrolovať). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Testy k v0.8.16:** **2054 headless** · 72 JS sád · posledný plný in-SketchUp beh **1057 PASS / 0 FAIL / 0 SKIP** (dávka **F/D-27** — nová sekcia `run_d27`, +21 assertov).

> **Poznámka k procesu:** Codex review bol 21.–24.8. **nedostupný** — PR **#186–#226** prešli bránou so slepým subagentom. **Post-hoc sweep je od 27.8. HOTOVÝ** (34 PR cez Codex CLI + triáž 54 nezodpovedaných threadov): dve reálne P1 slepým kolám ušli a týždeň žili v `main`, obe sú dávno opravené — [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-E**.

## Robí sa

**Blok 1b · STABILIZAČNÁ REVÍZIA je prakticky uzavretý** ([PLAN.md](PLAN.md)): brány A/G/H hotové (1b-1/2/3), dlhy B+D (1b-4), sweep E, mimo písmen 1b-6a/6b/6c aj 1b-7, z F je hotové D-27 —
**ostáva len D-51** (štandard veľkostí okien — čaká na Michalove hodnoty) a výklop ako typ čela (ide cez task package 1e).
**Blok 1c · AUDIT KÓDU je HOTOVÝ (29.8.)** — traja audítori zliati do **[AUDIT_REGISTER.md](AUDIT_REGISTER.md)** (2×P0 + 33 položiek + poradie pre 1d + 2 rozhodnutia Michala);
**oba P0 sú vybavené dávkou P0-HF** (v0.8.14) a **beží blok 1d** (hotové: R-06 brána, R-08 zámky katalógov). **Beží aj 1e PLÁNOVACIA DÁVKA** (task packages, priorita do 2.9.).
**Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie ďalšej práce (Michal 26.8. + úprava 27.8. kvôli koncu MAX plánu 2.9.):** ~~1b~~ → ~~1c audit~~ → **1e plánovacia dávka** (task packages — Fable priorita do 2.9.)
→ **1d refaktor z [AUDIT_REGISTER.md](AUDIT_REGISTER.md)** (beží súbežne cez subagentov, pokračuje aj po 2.9.) → **GHOST VKLADANIE** → **KOVANIE** (najprv USER-debata o setoch,
Michal ju rozoberie v samostatnom okne). V1 rozsah zoštíhlený — checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **1d/R-08 — dve okná SketchUpu si už neprepíšu nastavenia** (sety a pravidlá kovania, ABS pravidlá, rozmerové rady aj sadzby dodávateľa; zastaraný formulár skončí hláškou
  „medzitým sa zmenilo", nie tichým prepisom) — v0.8.16 (30.8.) · **Michal večer:** v dvoch oknách SketchUpu ulož za sebou dva rôzne sety kovania — musia tam byť OBA.
- **1d/R-06a — dĺžkové kovanie sa už nenacení ako kusy** (úchytkový profil rezaný na dĺžku sa cez set nedostane do nákupu ani do ponuky — vydá oranžový riadok Kontroly
  s rozmerom „rez 597 mm"; kusové kovanie sa nemení) — v0.8.15 (29.8.) · **Michal večer:** namapuj úchytkový profil na set — nesmie sa objaviť v Nákupe ani v Rozpočte.
- **P0-HF — finálne brány pred zápisom exportov** (chybný XLSX/CSV už nevznikne: **tvrdo** sa zastaví záporná „Nábytková zostava", nesúlad ponuky s rozpočtom a zliate ID skriniek;
  **riadky bez ceny** až po druhom, vedomom kliku — STANDARD §11.3) — v0.8.14 (29.8.) · **Michal večer:** riadok bez ceny + „XLSX rozpočet" = prvý klik neuloží nič, druhý PRIZNÁ podhodnotenú sumu.
- **1c — AUDIT KÓDU KOMPLET** (traja audítori → [AUDIT_REGISTER.md](AUDIT_REGISTER.md); Codex review #250 korigoval samotný audit — kontrakt STANDARD §11.3 má prednosť pred audítorom) — 29.8., bez zmeny kódu.
- **F/D-27 — tagy modelu z panela** (ikona oka v raile → zoznam NOXUN tagov; klik = jeden krok Späť; checkbox ghost zón ide tou istou cestou; kontroly už nekreslia nad skrytým) — v0.8.13 (28.8.) ·
  **Michal večer:** skry v raile **Čelá** — musia zmiznúť, ikona sa rozsvieti, **Ctrl+Z** ich vráti; skús to aj so zapnutou ABS kontrolou (nad skrytým nesmie ostať plôška).
- **1b-7 — koniec tichého návratu starej ceny dekoru** (editor prelieva už len bunky, ktorých si sa dotkol; pri strete ukáže *tvoja × v katalógu* a bez rozhodnutia neuloží) — v0.8.10 (27.8.) · **Michal večer:** oprav cenu dekoru, daj **Esc**, spusti „Aktualizovať z Demosu", otvor ten istý dekor — nová cena musí ostať.
- **1b-E — POST-HOC SWEEP KOMPLET** (34 PR spätne cez Codex CLI + triáž 54 threadov; 29 nálezov, 10 platných) — kandidáti pre 1c v [zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md)
- **1b-6a + 1b-6c — meno zákazky (delenie PR #243)**: názov prežije prvé uloženie (v0.8.9) a `vepo_settings.json` má **jedny zamknuté dvere** (v0.8.12 — dve inštancie SketchUpu si už nemažú nastavenia ani mená) · **Michal večer:** nový model → napíš názov zákazky → Ctrl+S → VEPO sa musí volať podľa zákazky.
- **1b-4 — drobnosti sekcií Šablóny a Pravidlá** (odrážky B + D: PNG retry a dávkovanie, orezaný payload šablón; lenivý katalóg pások, víťaz pri vypnutej položke) — v0.8.8 (27.8.) · **Michal večer:** v **Šablónach** sa fotky dlaždíc majú doplniť po chvíli a **všetky**; v **Pravidlách** má poradie jantárových riadkov ostať rovnaké a vypnutá položka kovania má hovoriť „vypnuté".
- **1b-3 — „Obnoviť" = čisté čítanie** (brána G: zber už nespúšťa dedup; duplicitné ID sa priznajú ORANGE riadkom Kontroly aj s výrobným dôsledkom, oprava = zápisová cesta) — v0.8.7 (27.8.) · **Michal večer:** v Štúdiu klikni „Obnoviť" a skús Späť — zoznam krokov sa refreshom nesmie meniť; po skopírovaní skrinky môže na okamih blysnúť oranžový riadok „Skrinky s ID … sú v modeli 2×".
- **1b-2 — charakterizačné in-SU scenáre** (brána H: kópia · `*N` · Undo · prerušenie operácie · scale = regenerate · prepnutie modelu; +34 assertov, bez zmeny kódu, 27.8.) · **1b-1 — optimistický zámok Nastavení** (zastaraný pin nezostane po návrate do sekcie; status hovorí pravdu, keď prepočet zlyhá) — v0.8.6 (27.8.) · **PICKER-3 — dorobenie vyhľadávača** — v0.8.5 (26.8.)
- **VEĽKÝ TEST 26.8.** — v0.8.4, PICKER-2 aj všetkých 8 dávok fázy ŠTÚDIO (#220–#227) PASS, žiadny nález · **BLOK DOCS CLEANUP KOMPLET (26.8.)** — C: refresh STANDARD.md (#234) · B: upratané `SYSTEM/` (#233, v0.8.4) · A: mapa modulov na 6 súborov + guardy (#232)
- **PICKER-2 — riadok je dekor, hrúbka je čip** — PR **#231**, v0.8.3 · **PICKER-1 — jeden vyhľadávač aj v Predvoľbách projektu** — PR **#230**, v0.8.2 (25.8.) · **TEST-1 — prvé
  nálezy z testu naostro** (#229, v0.8.1) · **ŠT-4b — UZÁVER FÁZY ŠTÚDIO** (#228, **v0.8.0**) · **ŠT-4a — ZANIKOL POSLEDNÝ SATELIT** (#227, v0.7.69)
- **ŠT-3c — Šablóny sekciou + zánik okna Šablóny** (#225) a **premenovanie šablóny** vrátane presunu fotky a poradia (#226) · **ŠT-3a/3b — Kovanie a Pravidlá sekciami + zánik oboch
  okien** (#216 · #218 · #219 · #220) · ABS podľa roly, jantárové riadky a „vrátiť na pravidlo" (#221 · #222) · serverová validácia pravidiel a odtlačok (#223 · #224)
- **ŠT-2 — Materiály sekciou + zánik okna Materiály**, D-69 jednotný editor dekoru, „Kde sa používa" (#205 · #206 · #208 + #212 + #213 · #214) · **ŠT-1 — skelet Štúdia, Kusovník, Kontrola, Nákup, Rozpočet, Cenová ponuka + zánik okna Výroba** (#192 · #193 · #195 · #197–#200) a smoke opravy po teste 22.8. (#202 · #203)
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
