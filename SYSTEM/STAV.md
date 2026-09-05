# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.27 · 5.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru na dielci a čele) · **blok GHOST VKLADANIE** (PR #265/#268/#270/#271 + uzáver). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Blok KOVANIE má v maine celý slice A, celý slice H a CELÝ slice B (B1+B2+B3).** **KOV-A** dala čelám typy **výklop · sklop · blenda**, pamäť na **smer otvárania** (= strana pántov), kartu čela
a kresbu smerov priamo v modeli. **KOV-H** (H1 dáta + H2 UI) dala **ad-hoc kovanie**: ku skrinke alebo dielcu sa dá pripnúť **konkrétna položka mimo setov** a od H2 sa to celé
robí **priamo v Inspectore**. **KOV-B1** dala setom **klasifikáciu** (na čo · ako sa otvára · konštrukcia zásuvky · výrobca · rada · aktívny), **jediný zoznam výrobcov a rád**
(nový `core/hardware_taxonomy.rb`) a bezstratovú bránu definícií setov v šablónach; **KOV-B2** a **KOV-B3** to vytiahli na obrazovku (strom položiek + modal položky; dlaždice setov s chipmi, modal setu so živým náhľadom — nižšie).
**Výstupy existujúcich zákaziek sú obsahovo identické** (golden, CSV bajtovo).
**Pozor na kompatibilitu:** čo uloží v0.9.20, to **v0.9.18 už nepoužije** — model/šablóna (`CONFIG_SCHEMA` 4 + brána `assess_set_defs`), knižnica setov aj projektový snapshot
(`std` 3) a katalóg kovania s výrobcom (`schema` 2). Pred prvou takou zákazkou aktualizovať **obe PC** (D-52 updater).

**Testy k v0.9.27:** **2842 headless** · 87 JS sád · posledný plný in-SketchUp beh **1504 PASS** (v0.9.21; dávky #287, KOV-B2, NÁSTROJE-1 a GHOST-D1 ho **nespúšťali** — Michal pracoval v SketchUpe, pustiť pred merge; pribudli sekcie `run_kovb2`, `run_tools1`, `run_tools1_async`, `run_tools1b`, `run_kovb3`, `run_ghost_d1` a `run_ghost_d1_async`).

## Robí sa

**Blok 1b uzavretý až na D-51** (čaká na Michalove hodnoty) · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18 + zvyšok; R-13 čaká na Michala) · **1e HOTOVÁ** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)).
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)),
mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + smoke fix #286), **KOV-H KOMPLET** (H1 #283 + H2 #285), **KOV-B1** (#284), **KOV-B2** (katalóg) aj **KOV-B3** (editor setu, R-41 uzavretá) hotové — **slice B je KOMPLET, ďalej KOV-C**.
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor. **Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie (Michal 2.9.: „poradie je na tebe"):** ~~D-52~~ → ~~KOV-A1/A2a/A2b~~ → ~~KOV-H1~~ → ~~KOV-B1~~ → ~~KOV-H2~~ → ~~KOV-B2~~ → ~~KOV-B3~~ (všetko v maine)
→ **KOV-C** context_for + recepty → **KOV-D** resolver + zámky + brány → E/F/G/I. Súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` (KOV-A/B/C/D/H povinné) → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **GHOST-D1 — DOSKA SA UŽ TIEŽ KLADIE KLIKOM** (v0.9.27, 5.9.2026): „Vložiť dosku" **už nevkladá vedľa poslednej skrinky** — doska **visí na kurzore**, prichytáva sa
  **v celom priestore** (aj na **zvýšený** roh skrinky), **←/→** ju otáčajú, **↑/↓** menia **umiestnenie** (naležato · nastojato · na stenu) a karta to hneď ukáže, **Alt**
  prepína kotvu, **Esc** nevloží nič (ani krok Späť, ani pečiatku šablóny), vloženie je **jeden krok Späť** a **Ctrl+Y** ho vráti; vkladanie skriniek sa **nemení**. Doska má
  navyše vlastný **kontrakt configu** — zákazku z **novšieho** pluginu už nikto ticho neoreže (prestavba, otočenie, šablóna aj „Nahradiť UNI" ju odmietnu; VEPO, nákup, rozpočet ani ponuka nad ňou nevzniknú).
- **KOV-B3 — SET SA UPRAVUJE V OKNE A HNEĎ VIDNO, ČO SA OBJEDNÁ (slice B KOMPLET, R-41 uzavretá)** (v0.9.26, 4.9.2026): **Sety** sú **dlaždice s chipmi** (starý set má chip
  **„nezaradený"**), zakladanie aj úprava sú **modal** (použitie → otváranie → konštrukcia len pri zásuvke → výrobca → rada → navrhnutý názov), člen sa pýta „Ako sa určí kód?"
  a „Koľko?" a pod formulárom beží **živý náhľad** („objedná sa 1× 357696 za 19,60 €"). **Neaktívny set sa už neponúka** (staré zákazky sa nemenia), **dve okná nad tým istým setom sa už neprepíšu** (hláška + Obnoviť), **nákup ani výstupy sa nemenia.**
- **NÁSTROJE-1 KOMPLET — MOWER A SNAPER SÚ V BALÍKU ENGINU (D-20 uzavretá)** (T1a v0.9.24 + T1b v0.9.25): druhý toolbar **„Noxun Nástroje"** (rotácie · Z = 0 · Z posun… · Kópia vľavo/vpravo · Prisunúť vľavo/vpravo) + menu → **Nástroje**. **T1a:** kópia je **plnohodnotná skrinka** (vlastné CAB číslo, Inspector, kusovník, ceny — doteraz „fantóm"), krok = **šírka korpusu po vlastnej osi**.
  **T1b:** staré samostatné inštalácie sa **odstraňujú samy** — raz inštalátorom, raz pri štarte pluginu (marker per priečinok `Plugins`); zamknutý súbor sa **neoznačí za hotový** a skúsi sa znova, staré toolbary zmiznú až po **reštarte**.
- **KOV-B2 — KATALÓG KOVANIA MÁ STROM A MODAL (D-110 uzavretá)** (v0.9.23, 4.9.2026): položky sú **strom Kategória → „Výrobca · Rada"** — zbalená kategória je jeden riadok
  s počtom, hľadanie roztvorí **len** to, kde niečo našlo, a orezanie sa prizná číslom + **„Načítať ďalšie (N)"**. Zakladanie a úprava sú **modal** (nie formulár pod zoznamom)
  s poradím **Démos → kód → názov → cena → MJ → kategória → výrobca → rada → poznámka**; Démos predvyplní kód/názov/cenu/MJ **a výrobcu podľa značky** — ručne prepísaný údaj
  uloží položku ako **ručnú** (bez väzby a bez dátumu overenia). Nákup ani výstupy sa nemenia.
- **Staršie uzávery** (**KOV-H2** ad-hoc kovanie priamo v Inspectorovi v0.9.20 · **1d/R-14 · R-12 · R-11** zákazka z novšieho pluginu sa už ticho nezmrzačí v0.9.2–v0.9.4 ·
  **D-52** Aktualizovať jedným klikom v0.9.14 · **SMOKE 3.9. + D-115/D-116** symbol otvárania z rohov, tag úchytky, v0.9.21 · **VÝSTUPY D-112 + D-113** deviaty stĺpec „poznámka" vo VEPO CSV, v0.9.22 ·
  **KOV-B1** klasifikácia setov a taxonómia v0.9.19 · **KOV-H1** ad-hoc kovanie dátová vrstva v0.9.18 · **KOV-A2b** smer otvárania v modeli v0.9.17 ·
  UZÁVER BLOKU GHOST VKLADANIE **v0.9.0** so smoke checklistom · 1d/R-02 · R-02b · R-01+R-04 · R-07 · R-08 · R-03 · R-34 · 1b-6a/6c · 1b-4 · 1b-3 ·
  VEĽKÝ TEST 26.8. · DOCS CLEANUP · PICKER-1/-2/-3 · TEST-1 · ŠT-4b uzáver fázy ŠTÚDIO **v0.8.0** · blok KRESBA · UI-A…UI-D · ŠTART AUTONÓMIE · RETRO · UPRATANIE · séria KLINIKA · Materiály 2.0 a dávky D/E #89–#140) — plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md)

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
