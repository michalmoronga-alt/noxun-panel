# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.44 · 7.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(PR #265/#268/#270/#271 + uzáver). Ustálené vzory fázy ŠTÚDIO sú v [archiv/KRONIKA.md](archiv/KRONIKA.md), vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Blok KOVANIE má v maine celý slice A, celý slice H, CELÝ slice B (B1+B2+B3) a CELÝ slice C (C1+C2a+C2b+C2c).** **KOV-A** dala čelám typy **výklop · sklop · blenda**, pamäť na
**smer otvárania**, kartu čela a kresbu smerov v modeli. **KOV-H** dala **ad-hoc kovanie** priamo v Inspectore. **KOV-B** dala setom **klasifikáciu**, jediný zoznam výrobcov
a rád (`core/hardware_taxonomy.rb`) a vytiahla katalóg aj editor setu na obrazovku. **KOV-C** dala **zásuvky z nemenných receptov** (nižšie).
**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo).
**Pozor na kompatibilitu:** čo uloží v0.9.20, to **v0.9.18 už nepoužije** — model/šablóna (`CONFIG_SCHEMA` 4 + brána `assess_set_defs`), knižnica setov aj projektový snapshot
(`std` 3) a katalóg kovania s výrobcom (`schema` 2). Pred prvou takou zákazkou aktualizovať **obe PC** (D-52 updater).

**Testy k v0.9.44:** **3364 headless** · 94 JS sád · posledný plný in-SketchUp beh **1950 PASS** (nad vetvou KOV-D5, 7.9.; sekcie `run_kovd2a` … `run_kovd5` bežali; nestabilný test = D-117).

## Robí sa

**Blok 1b uzavretý až na D-51** · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18; R-13 čaká na Michala) · **1e HOTOVÁ** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)).
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)), mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + fix #286), **KOV-H KOMPLET** (#283 + #285), **KOV-B1** (#284), **KOV-B2** aj **KOV-B3** hotové — **slice B je KOMPLET**.
**KOV-C má package v2 (5.9., PR #301, #19):** nemenné recepty, kódy v setoch, žiadny fallback NL; ZMRAZENÝ.
**KOV-C KOMPLET:** C1 jadro (#302), C2a príprava (v0.9.30), C2b aktivácia (#304, v0.9.31), C2b-M materiálový kanál (#305, v0.9.32) a **C2c UI zásuviek** (v0.9.33).
**KOV-D (package v2, PR #307, #20): slice D je KOMPLET (v0.9.42, 7.9.2026)** — D1a (0.9.34) · D1b (0.9.35) · D1c (0.9.36) · D2a (0.9.37) · D2b (0.9.38) · D3a/D3b (0.9.39/40) ·
D4 (0.9.41) · D5 (0.9.42); 8 PR za deň (#310–#317). Blok KOVANIE pokračuje E/F/G/I (package + debata s Michalom pred štartom); minor bump až pri uzávere celého bloku.
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor. **Limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie:** ~~D-52~~ → ~~KOV-A~~ → ~~KOV-H~~ → ~~KOV-B~~ → ~~KOV-C~~ → ~~KOV-D~~ (všetko v maine, D1a–D5) → ~~D-118~~ (katalógový seed + sety, a aj b) → **E/F/G/I** (poradie určí Michal; package pred štartom); súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **D-118b — ZÁSUVKA OBJEDNÁ SPRÁVNU SADU A TIP-ON AJ MECHANIZMUS** (v0.9.44, 7.9.2026): antracitová zásuvka H70 s NL 470 objedná **`357889`** namiesto `348777` (ten
  **nie je K-sada** — čelné kovanie treba dokúpiť), a **každá Tip-On zásuvka** dostane k sade aj **PTOs modul** `352908` (30 kg) / `352909` (50 kg), 28,33 € s DPH — doteraz
  chýbal, lebo v K-sade nie je. Kity typu `PTO` (620 mm, Quadro V6) ho **vedome nedostanú**. Oprava sa dostane aj do knižnice na disku, ak si ju človek sám neupravil;
  **rozpracované zákazky sa nemenia samy** — do nich ju prenesie **„Doplniť nové predvoľby"** (od tejto dávky aj osvieži nedotknuté definície a povie, koľko ich bolo).
  [KRONIKA](archiv/KRONIKA.md).
- **D-118a — KATALÓG KOVANIA UŽ POZNÁ KÓDY, KTORÉ SI PLUGIN SÁM OBJEDNÁVA** (v0.9.43, 7.9.2026): katalóg má **114 položiek** a pri každej **presný názov z Démosu, cenu s DPH,
  odkaz na stránku, dátum overenia, výrobcu a radu** — doteraz boli kódy receptových setov v Nákupe „bez ceny". Dáta sú overené proti produktovej stránke tým istým parserom,
  akým beží „Overiť cenu". **Používateľské položky sa neprepisujú** (na tomto PC 11 vlastných + 13 doplnených riadkov), štyri zrušené kódy ostávajú ako **neaktívne** s dôvodom.
  Doplnením výrobcov sa katalóg označí ako novší — **staršia verzia pluginu ho otvorí len na čítanie**. [KRONIKA](archiv/KRONIKA.md).
- **KOV-D5 — ZÁSUVKA UŽ UKAZUJE OLEP NA SPRÁVNEJ HRANE** (v0.9.42, 7.9.2026): dielce zásuvky boli doteraz v modeli **jednofarebné** — páska sa na nich nekreslila vôbec.
  Odteraz má **chrbát, bok boxu aj vnútorné čelo** pásku vidieť na **hornej** hrane (presne tam, kam ide), **dno ostáva bez pásky** a **Kontrola olepov** zvýrazní **tú istú**
  hranu. Rozmery, kusovník, VEPO ani ceny sa nemenia; stará zákazka dostane farbu pri najbližšej prestavbe skrinky. [KRONIKA](archiv/KRONIKA.md).
- **Staršie uzávery** (**KOV-D4** ceruzka v Kontrole a „Bez kódov" po ľudsky v0.9.41 · **KOV-D1b + D1c** výber setu zásuvky vrátane antracitu v0.9.35/36 · **KOV-C2b + C2b-M** zásuvka naozaj vznikne a dá sa jej nastaviť materiál v0.9.31/32 ·
  **KOV-D3a + D3b** prechod na novšiu verziu receptu — latentný rámec v0.9.39/40 · **KOV-D2b** klikacie zámky výšky a dĺžky zásuvky v0.9.38 · **KOV-D2a** zámky osí zásuvky, `CONFIG_SCHEMA` 7 v0.9.37 · **KOV-C1 + C2a** nemenné recepty, SHA register, 4. materiálový kanál a 8 setov s kódmi v0.9.29–v0.9.30 · **GHOST-D2** doska sa dá nakresliť na rozmer v0.9.28 ·
  **KOV-C2c** riadok zásuvky a Technický detail na karte čela v0.9.33 · **KOV-D1a** vlastný kit pre jedno čelo, poškodený pin receptu = červená v0.9.34 · **KOV-B3** editor setu v modale so živým náhľadom v0.9.26 · **NÁSTROJE-1** toolbar „Noxun Nástroje“ v0.9.24–v0.9.25 ·
  **GHOST-D1** doska sa kladie klikom, vlastný kontrakt configu v0.9.27 · **KOV-B2** katalóg kovania so stromom a modalom v0.9.23 · **KOV-H2** ad-hoc kovanie priamo v Inspectorovi v0.9.20 · **1d/R-14 · R-12 · R-11** zákazka z novšieho pluginu sa už ticho nezmrzačí v0.9.2–v0.9.4 ·
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
