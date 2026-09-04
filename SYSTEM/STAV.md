# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.22 · 4.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru na dielci a čele) · **blok GHOST VKLADANIE** (PR #265/#268/#270/#271 + uzáver). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Blok KOVANIE má v maine celý slice A, celý slice H aj KOV-B1.** **KOV-A** dala čelám typy **výklop · sklop · blenda**, pamäť na **smer otvárania** (= strana pántov), kartu čela
a kresbu smerov priamo v modeli. **KOV-H** (H1 dáta + H2 UI) dala **ad-hoc kovanie**: ku skrinke alebo dielcu sa dá pripnúť **konkrétna položka mimo setov** a od H2 sa to celé
robí **priamo v Inspectore**. **KOV-B1** dala setom **klasifikáciu** (na čo · ako sa otvára · konštrukcia zásuvky · výrobca · rada · aktívny), **jediný zoznam výrobcov a rád**
(nový `core/hardware_taxonomy.rb`) a bezstratovú bránu definícií setov v šablónach. **Výstupy existujúcich zákaziek sú obsahovo identické** (golden, CSV bajtovo).
**Pozor na kompatibilitu:** čo uloží v0.9.20, to **v0.9.18 už nepoužije** — model/šablóna (`CONFIG_SCHEMA` 4 + brána `assess_set_defs`), knižnica setov aj projektový snapshot
(`std` 3) a katalóg kovania s výrobcom (`schema` 2). Pred prvou takou zákazkou aktualizovať **obe PC** (D-52 updater).

**Testy k v0.9.22:** **2686 headless** · 82 JS sád · posledný plný in-SketchUp beh **1504 PASS** (v0.9.21; VEPO dávka #287 ho **nespúšťala** — Michal pracoval v SketchUpe, pustiť pred merge).

## Robí sa

**Blok 1b uzavretý až na D-51** (čaká na Michalove hodnoty) · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18 + zvyšok; R-13 čaká na Michala) · **1e HOTOVÁ** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)).
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)),
mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + smoke fix #286), **KOV-H KOMPLET** (H1 #283 + H2 #285) a **KOV-B1** (#284) hotové — **ďalej KOV-B2** (katalóg), potom **B3** (editor setu + R-41).
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor. **Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie (Michal 2.9.: „poradie je na tebe"):** ~~D-52~~ → ~~KOV-A1/A2a/A2b~~ → ~~KOV-H1~~ → ~~KOV-B1~~ → ~~KOV-H2~~ (všetko v maine) → **KOV-B2** katalóg
(zoskupenie, modal, Démos) → **KOV-B3** editor setu (+ R-41) → **KOV-C** context_for + recepty → **KOV-D** resolver + zámky + brány → E/F/G/I. Súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` (KOV-A/B/C/D/H povinné) → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **VÝSTUPY · D-112 + D-113** (v0.9.22, PR #287): VEPO CSV má **deviaty stĺpec „poznámka"** — pásku v inom dekore než doska povie riadok sám (`ABS H1181 Dub Halifax tabakový`),
  netreba ju do objednávky dopisovať rukou (pri KLINIKE zabudnuté); LOG má kontrolný zoznam. Názov nesie skratku a skrinky (`Bok LP s1 s2`) kvôli 20-znakovým nálepkám. Kontrakt **v1.1**.
- **SMOKE 3.9. + D-115/D-116** (v0.9.21, PR #286): Michalov smoke nad v0.9.20 prešiel **bez chyby** (body 1–6 PASS). **D-115:** symbol otvárania je **stolárska konvencia** — čiary
  z rohov strany pántov, v náhľade **aj** vo viewporte, jediný zdroj tvaru per jazyk. **D-116:** úchytka má tag **svojho čela**. **D-114** ostáva na UI/UX balík konca bloku.
- **KOV-H2 — AD-HOC KOVANIE PRIAMO V INSPECTOROVI** (v0.9.20, 3.9.2026): dátovú vrstvu dala H1, **teraz to má obrazovku**. V kontexte **Kovanie** je blok **„Ručne pridané"**
  a tlačidlo **„Pridať konkrétnu položku (mimo setov)"**: k čomu patrí (skrinka / čelo / polica), z **katalógu** (živá cena) alebo **voľná**, množstvo a poznámka; riadky
  s chipom **„ručná"**, ceruzka a kôš, každá zmena **jeden krok Späť**. Priznajú sa stavy **„bez vlastníka"** a **„chýba v katalógu"**; v Štúdiu → **Nákup** klik na riadok ukáže
  **pôvod**. **Výstupy sa nemenia ani o znak.** Michal to večer prešiel celé (detail v [archiv/KRONIKA.md](archiv/KRONIKA.md)).
- **KOV-B1 — KATALÓG A SETY: klasifikácia, taxonómia, std 3** (v0.9.19, 3.9.2026): set vie, **na čo je** — typ použitia, otváranie, konštrukcia zásuvky, **výrobca a rada**
  z jediného zoznamu (`hardware_taxonomy.json`), príznak „aktívny"; typ kovania sa **odvodzuje**. Klasifikácia je **buď úplná, alebo žiadna** — starý „nezaradený" set funguje ako
  dosiaľ a **nákup sa nemení ani o kód**. **Navonok vidieť JEDINÚ vec — v zozname typov kovania pribudol „Výklop / sklop"** (pravidlá a dáta prídu v KOV-E).
- **KOV-H1 — ad-hoc kovanie, DÁTOVÁ VRSTVA** (v0.9.18, 3.9.2026): položka mimo setov — z **katalógu** (živá cena, zlieva sa s rovnakým kódom) alebo **voľná** (vlastný riadok,
  v CSV bez kódu). Prežijú prestavbu aj kópiu, cestujú so šablónou; po zániku dielca **ostanú v nákupe** a Kontrola to prizná oranžovo. Súčasť je **hardening R-12**: zákazka
  z novšej verzie už nevyexportuje neúplný nákup, rozpočet ani ponuku (VEPO ide ďalej).
- **KOV-A2b — smery otvárania VIDNO PRIAMO V MODELI** (v0.9.17, PR #282): prepínač **„Smer otvárania"** kreslí symbol otvárania na každé čelo NAD modelom (žiadny zápis ani krok
  Späť; tvar symbolov prekreslila D-115). **KOV-A2a** (#281) dala **kartu čela**, **KOV-A1** (#280) dáta pod tým.
- **1d/R-14 · R-12 · R-11 — zákazka či nastavenia z NOVŠIEHO pluginu sa už ticho nezmrzačia** (v0.9.2–v0.9.4) a **D-52 — Aktualizovať jedným klikom** (v0.9.14, PR #277–#279): Štúdio → O plugine → priečinok, kontrola verzie, tlačidlo; bariéra okien, atomický swap, restart latch, downgrade zakázaný.
- **Staršie uzávery** (UZÁVER BLOKU GHOST VKLADANIE **v0.9.0** so smoke checklistom · 1d/R-02 · R-02b · R-01+R-04 · R-07 · R-08 · R-03 · R-34 · 1b-6a/6c · 1b-4 · 1b-3 ·
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
