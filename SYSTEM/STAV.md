# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.8.24 · 31.8.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu a overená proti ručnému rozpočtu.
Nálezy z reálnej výroby a chyby v cenách majú preto **najvyššiu prioritu triedenia** ([PLAN.md](PLAN.md), Pravidlo pre postrehy).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru sa nastavuje na dielci a čele a dá sa vizuálne skontrolovať). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Testy k v0.8.24:** **2216 headless** · 75 JS sád · posledný plný in-SketchUp beh **1217 PASS / 0 FAIL** (dávka GHOST-FB nad stabilnou identitou dokumentu DocKey z 1d/R-02b).

> **Poznámka k procesu:** Codex review bol 21.–24.8. **nedostupný** — PR **#186–#226** prešli bránou so slepým subagentom. **Post-hoc sweep je od 27.8. HOTOVÝ** (34 PR cez Codex CLI + triáž 54 nezodpovedaných threadov): dve reálne P1 slepým kolám ušli a týždeň žili v `main`, obe sú dávno opravené — [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-E**.

## Robí sa

**Blok 1b · STABILIZAČNÁ REVÍZIA je prakticky uzavretý** ([PLAN.md](PLAN.md)): brány A/G/H hotové (1b-1/2/3), dlhy B+D (1b-4), sweep E, mimo písmen 1b-6a/6b/6c aj 1b-7, z F je hotové D-27 —
**ostáva len D-51** (štandard veľkostí okien — čaká na Michalove hodnoty) a výklop ako typ čela (ide cez task package 1e).
**Blok 1c · AUDIT KÓDU je HOTOVÝ (29.8.)** — traja audítori zliati do **[AUDIT_REGISTER.md](AUDIT_REGISTER.md)** (2×P0 + 35 položiek — 33 z 1c, 2 z review — + poradie pre 1d + 3 rozhodnutia Michala (R-05 · R-13 · R-30));
**oba P0 sú vybavené dávkou P0-HF** (v0.8.14) a **beží blok 1d** (hotové: R-06 brána, R-08 zámky katalógov, R-01+R-04 multi-model observer, R-34 presnosť P0-2 brány, R-02 guard identity dokumentu + **R-02b**, **R-03 šev vkladania — TVRDÝ blocker GHOST tým padol**, R-07 brána knižnice setov). **Beží aj 1e PLÁNOVACIA DÁVKA** (task packages, priorita do 2.9.).
**Blok GHOST VKLADANIE — implementačná dávka + GHOST-FB HOTOVÉ** (v0.8.22/v0.8.24): skrinka sa kladie klikom, vo výškovom zámku sa prichytáva na existujúcu geometriu. Blok sa uzatvára až po Michalovom smoke (11 bodov v [PLAN.md](PLAN.md)) — samostatný PR s bumpom 0.9.0.
**Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie ďalšej práce (Michal 26.8. + úprava 27.8. kvôli koncu MAX plánu 2.9.):** ~~1b~~ → ~~1c audit~~ → **1e plánovacia dávka** (task packages — Fable priorita do 2.9.)
→ **1d refaktor z [AUDIT_REGISTER.md](AUDIT_REGISTER.md)** (beží súbežne cez subagentov, pokračuje aj po 2.9.) → ~~GHOST VKLADANIE~~ (implementácia hotová, čaká smoke) → **KOVANIE** (najprv USER-debata o setoch, Michal ju rozoberie v samostatnom okne). V1 rozsah zoštíhlený — checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **GHOST VKLADANIE — skrinka sa kladie KLIKOM** (v0.8.22) **+ GHOST-FB** (v0.8.24, 31.8.): v zámku sa ghost prichytáva na rohy a hrany existujúcich skriniek (výšku drží zámok) · kotva skočí pod kurzor aj po Alt · kotva/otočenie/režim/výška sa pamätajú do zatvorenia SketchUpu · **Ghost pásik** s prestaviteľnou zamknutou výškou (0 / 1400) · **Michal večer: SMOKE — 11 bodov v [PLAN.md](PLAN.md).**
- **1d/R-07 — starší a novší plugin si už nepoškodia knižnicu setov kovania** (knižnica z novšej verzie sa nedá ani zapísať, ani použiť: namiesto tichého orezania
  ju súpis prizná oranžovým riadkom a Štúdio bannerom) — v0.8.21 (30.8.) · **Michal večer:** Štúdio → Kovanie → Sety musí vyzerať a fungovať presne ako doteraz (banner sa NESMIE ukázať).
- **1d/R-02b — Ctrl+S už nezahadzuje rozpísanú prácu** (identity dokumentu už nerotuje uloženie, ale iba File > New/Open) — v0.8.23 (30.8.) · **Michal večer:** uprav šírku skrinky a do sekundy daj **Ctrl+S** — zmena sa musí uložiť a rozpísané polia ostať.
- **1d/R-03 — skrinka sa dá pripraviť BEZ zásahu do modelu a položiť na presnú polohu** (prípravná dávka pre GHOST vkladanie na klik — **tvrdý blocker tým padol**; z pohľadu používateľa sa dnes nemení NIČ) — v0.8.20 (30.8.) · **Michal večer:** netreba, bez UI zmeny.
- **1d/R-02 — panel už nezapíše do nesprávneho dokumentu** (oneskorená akcia po prepnutí okna SketchUpu skončí hláškou „patrí inému dokumentu", nie tichým zápisom do cudzej zákazky — vkladanie, apply, premenovanie, kovanie, materiály aj karty dielca a dosky) — v0.8.19 (30.8.) · **Michal večer:** v dvoch oknách prepíš šírku skrinky a HNEĎ preklikni do druhého — zmena sa tam nesmie prejaviť.
- **1d/R-34 — brána exportov už nezastaví zákazku, ktorá je v poriadku** (zdieľané ID skriniek zastaví nákup/rozpočet/ponuku len vtedy, keď sa kovanie NAOZAJ pomieša — účtované na vlastníka započítané raz, alebo rozídené sety dvoch skriniek s jedným ID; inak export prejde a ostáva len oranžový nález Kontroly) — v0.8.18 (30.8.) · **Michal večer:** netreba, bez UI zmeny.
- **1d/R-01+R-04 — observer veľkosti je multi-model bezpečný a už si nepamätá zmazané** (pamäť pôvodných polôh sa po zmazaní skrinky vyprázdni a po **Späť** ju dostane naspäť)
  — v0.8.17 (30.8.) · **Michal večer:** vlož skrinku so zónami, zmaž ju (ghosty musia zmiznúť), **Ctrl+Z** a hneď skús neplatné zväčšenie — musí sa vrátiť tam, kde bola.
- **1d/R-08 — dve okná SketchUpu si už neprepíšu nastavenia** (sety a pravidlá kovania, ABS pravidlá, rozmerové rady aj sadzby dodávateľa; zastaraný formulár skončí hláškou
  „medzitým sa zmenilo", nie tichým prepisom) — v0.8.16 (30.8.) · **Michal večer:** v dvoch oknách SketchUpu ulož za sebou dva rôzne sety kovania — musia tam byť OBA.
- **1d/R-06a — dĺžkové kovanie sa už nenacení ako kusy** (úchytkový profil rezaný na dĺžku sa cez set nedostane do nákupu ani do ponuky — vydá oranžový riadok Kontroly
  s rozmerom „rez 597 mm"; kusové kovanie sa nemení) — v0.8.15 (29.8.) · **Michal večer:** namapuj úchytkový profil na set — nesmie sa objaviť v Nákupe ani v Rozpočte.
- **P0-HF — finálne brány pred zápisom exportov** (chybný XLSX/CSV už nevznikne: **tvrdo** sa zastaví záporná „Nábytková zostava", nesúlad ponuky s rozpočtom a zliate ID skriniek;
  **riadky bez ceny** až po druhom, vedomom kliku — STANDARD §11.3) — v0.8.14 (29.8.) · **Michal večer:** riadok bez ceny + „XLSX rozpočet" = prvý klik neuloží nič, druhý PRIZNÁ podhodnotenú sumu.
- **1c — AUDIT KÓDU KOMPLET** (traja audítori → [AUDIT_REGISTER.md](AUDIT_REGISTER.md); Codex review #250 korigoval samotný audit — kontrakt STANDARD §11.3 má prednosť pred audítorom) — 29.8., bez zmeny kódu.
- **F/D-27 — tagy modelu z panela** (ikona oka v raile → zoznam NOXUN tagov; klik = jeden krok Späť; checkbox ghost zón ide tou istou cestou; kontroly už nekreslia nad skrytým) — v0.8.13 (28.8.) ·
  **Michal večer:** skry v raile **Čelá** — musia zmiznúť, ikona sa rozsvieti, **Ctrl+Z** ich vráti; skús to aj so zapnutou ABS kontrolou (nad skrytým nesmie ostať plôška).
- **1b-E — POST-HOC SWEEP KOMPLET** (34 PR spätne cez Codex CLI + triáž 54 threadov; 29 nálezov, 10 platných) — kandidáti pre 1c v [zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md)
- **1b-6a + 1b-6c — meno zákazky (delenie PR #243)**: názov prežije prvé uloženie (v0.8.9) a `vepo_settings.json` má **jedny zamknuté dvere** (v0.8.12 — dve inštancie SketchUpu si už nemažú nastavenia ani mená) · **Michal večer:** nový model → napíš názov zákazky → Ctrl+S → VEPO sa musí volať podľa zákazky.
- **1b-4 — drobnosti sekcií Šablóny a Pravidlá** (PNG retry a dávkovanie, orezaný payload šablón; lenivý katalóg pások, víťaz pri vypnutej položke) — v0.8.8 (27.8.) · **1b-3 — „Obnoviť" = čisté čítanie** (brána G: zber už nespúšťa dedup; duplicitné ID sa priznajú ORANGE riadkom Kontroly) — v0.8.7 (27.8.)
- **VEĽKÝ TEST 26.8.** — v0.8.4, PICKER-2 aj 8 dávok fázy ŠTÚDIO (#220–#227) PASS, žiadny nález · **DOCS CLEANUP KOMPLET** (#232–#234) · **PICKER-2/-1** (#231/#230, 25.8.) · **TEST-1 — prvé nálezy z testu naostro** (#229) · **ŠT-4b — UZÁVER FÁZY ŠTÚDIO** (#228, **v0.8.0**) · **ŠT-4a — ZANIKOL POSLEDNÝ SATELIT** (#227)
- **Staršie uzávery** (1b-7 cena dekoru · 1b-2 charakterizačné in-SU scenáre · 1b-1 optimistický zámok Nastavení · PICKER-3 · fáza ŠTÚDIO ŠT-1…ŠT-3c #192–#226 · blok KRESBA #185–#190 · bloky UI-A…UI-D #165–#184 · ŠTART AUTONÓMIE #162–#164 · RETRO #161 · UPRATANIE #157–#160 · séria KLINIKA #144–#156 · Materiály 2.0 a dávky D/E #89–#140) — plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md)

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
