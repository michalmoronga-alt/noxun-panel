# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.31 · 5.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(PR #265/#268/#270/#271 + uzáver). Ustálené vzory fázy ŠTÚDIO sú v [archiv/KRONIKA.md](archiv/KRONIKA.md), vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Blok KOVANIE má v maine celý slice A, celý slice H, CELÝ slice B (B1+B2+B3) a z C rezy C1+C2a+C2b.** **KOV-A** dala čelám typy **výklop · sklop · blenda**, pamäť na
**smer otvárania**, kartu čela a kresbu smerov v modeli. **KOV-H** dala **ad-hoc kovanie** priamo v Inspectore. **KOV-B** dala setom **klasifikáciu**, jediný zoznam výrobcov
a rád (`core/hardware_taxonomy.rb`) a vytiahla katalóg aj editor setu na obrazovku. **KOV-C** dala **zásuvky z nemenných receptov** (nižšie).
**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Pozor na kompatibilitu:** čo uloží v0.9.20, to **v0.9.18 už nepoužije** — model/šablóna (`CONFIG_SCHEMA` 4 + brána `assess_set_defs`), knižnica setov aj projektový snapshot
(`std` 3) a katalóg kovania s výrobcom (`schema` 2). Pred prvou takou zákazkou aktualizovať **obe PC** (D-52 updater).

**Testy k v0.9.31:** **3063 headless** · 89 JS sád · posledný plný in-SketchUp beh **1750 PASS** (nad vetvou KOV-C1, 5.9.). **KOV-C2b pridala sekciu `run_kovc2b`, ktorá ešte NEBEŽALA** — spustiť ju treba pred mergom (mení buildery).

## Robí sa

**Blok 1b uzavretý až na D-51** · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18; R-13 čaká na Michala) · **1e HOTOVÁ** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)).
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)),
mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + fix #286), **KOV-H KOMPLET** (#283 + #285), **KOV-B1** (#284), **KOV-B2** aj **KOV-B3** hotové — **slice B je KOMPLET**.
**KOV-C má package v2 (5.9., PR #301, #19):** nemenné recepty, kódy v setoch, žiadny fallback NL; ZMRAZENÝ.
**C1 jadro (#302), C2a príprava (v0.9.30) aj C2b aktivácia (v0.9.31) hotové — ďalej C2c (Inspector karta, Kontrola riadky, Nákup labely, UI 4. kanála).**
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex;
vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor.
**Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie:** ~~D-52~~ → ~~KOV-A~~ → ~~KOV-H~~ → ~~KOV-B~~ (všetko v maine) → **KOV-C** (package v2 zmrazený 5.9., #19; ~~C1~~ → ~~C2a~~ → ~~C2b~~ → **C2c UI**) → **KOV-D** → E/F/G/I; súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **KOV-C2b — ZÁSUVKA UŽ NAOZAJ VZNIKNE (dielce + výsuv)** (v0.9.31, 5.9.2026): čelo označené ako zásuvka **Atira** alebo **Quadro V6** dostane automaticky **vyrábané dielce**
  (Atira dno + chrbát; Quadro 2 boky + dno + vnútorné čelo + chrbát) do modelu aj kusovníka a **jednu položku výsuvu** do nákupu. Nevyriešená zásuvka **nevyrobí nič**, je
  **červená v Kontrole** a zastaví export; chýbajúci kit zastaví **aj VEPO**. **Zákazky bez zásuvkovej klasifikácie sa nemenia.** Karta zásuvky a výber materiálu = C2c.
  Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-C1 + KOV-C2a — JADRO A PRÍPRAVA ZÁSUVIEK (bez viditeľnej zmeny)** (v0.9.29 a v0.9.30, 5.9.2026): nemenné verzované recepty Atira/Quadro V6 (`data/recipes/*.json`
  + SHA register), výpočet svetlého priestoru okolo čela, **4. materiálový kanál „Zásuvky"** (UNI 16 mm), ABS pravidlá dielcov, **8 nových setov s kódmi** a predvoľby podľa
  otvárania a konštrukcie. Výstupy sa vtedy ešte nemenili — zapla ich až C2b. Plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **GHOST-D2 — DOSKA SA DÁ NAKRESLIŤ NA ROZMER** (v0.9.28, 5.9.2026): karta Dosky má vedľa „Vložiť" aj **„Nakresliť"** — doska vznikne **dvoma ťahmi** (klik = počiatok, ťah dĺžka a smer, ťah šírka), **čísla sa dajú napísať** do meracieho poľa (2400 Enter), **zamknuté pole karty ťah preskočí**, rozmer nad limitom plugin **odmietne s hláškou**,
  **Esc** nevloží nič a vloženie je **jeden krok Späť**. Vkladanie skriniek ani „Vložiť dosku" sa **nemenia**. Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-B3 — SET SA UPRAVUJE V OKNE A HNEĎ VIDNO, ČO SA OBJEDNÁ (slice B KOMPLET, R-41 uzavretá)** (v0.9.26, 4.9.2026): **Sety** sú **dlaždice s chipmi** (starý set má chip
  **„nezaradený"**), zakladanie aj úprava sú **modal** (použitie → otváranie → konštrukcia len pri zásuvke → výrobca → rada → navrhnutý názov), člen sa pýta „Ako sa určí kód?"
  a „Koľko?" a pod formulárom beží **živý náhľad** („objedná sa 1× 357696 za 19,60 €"). **Neaktívny set sa už neponúka** (staré zákazky sa nemenia), **dve okná nad tým istým setom sa už neprepíšu** (hláška + Obnoviť), **nákup ani výstupy sa nemenia.**
- **NÁSTROJE-1 KOMPLET — MOWER A SNAPER SÚ V BALÍKU ENGINU (D-20 uzavretá)** (T1a v0.9.24 + T1b v0.9.25): druhý toolbar **„Noxun Nástroje"** (rotácie · Z = 0 · Z posun… · Kópia vľavo/vpravo · Prisunúť vľavo/vpravo) + menu → **Nástroje**. **T1a:** kópia je **plnohodnotná skrinka** (vlastné CAB číslo, Inspector, kusovník, ceny — doteraz „fantóm"), krok = **šírka korpusu po vlastnej osi**.
  **T1b:** staré samostatné inštalácie sa **odstraňujú samy** — raz inštalátorom, raz pri štarte pluginu (marker per priečinok `Plugins`); zamknutý súbor sa **neoznačí za hotový** a skúsi sa znova, staré toolbary zmiznú až po **reštarte**.
- **Staršie uzávery** (**GHOST-D1** doska sa kladie klikom, vlastný kontrakt configu v0.9.27 · **KOV-B2** katalóg kovania so stromom a modalom v0.9.23 · **KOV-H2** ad-hoc kovanie priamo v Inspectorovi v0.9.20 · **1d/R-14 · R-12 · R-11** zákazka z novšieho pluginu sa už ticho nezmrzačí v0.9.2–v0.9.4 ·
  **D-52** Aktualizovať jedným klikom v0.9.14 · **SMOKE 3.9. + D-115/D-116** symbol otvárania z rohov, tag úchytky, v0.9.21 · **VÝSTUPY D-112 + D-113** deviaty stĺpec „poznámka" vo VEPO CSV, v0.9.22 ·
  **KOV-B1** v0.9.19 · **KOV-H1** v0.9.18 · **KOV-A2b** v0.9.17 · UZÁVER BLOKU GHOST VKLADANIE **v0.9.0** · 1d/R-02 · R-02b · R-01+R-04 · R-07 · R-08 · R-03 · R-34 · 1b-6a/6c · 1b-4 · 1b-3 · VEĽKÝ TEST 26.8. · DOCS CLEANUP · PICKER-1/-2/-3 · TEST-1 · ŠT-4b uzáver ŠTÚDIA **v0.8.0** · KRESBA · UI-A…UI-D · KLINIKA · Materiály 2.0 #89–#140) — v [archiv/KRONIKA.md](archiv/KRONIKA.md)

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
