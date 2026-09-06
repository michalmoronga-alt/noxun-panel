# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.36 · 6.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
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

**Testy k v0.9.36:** **3189 headless** · 91 JS sád · posledný plný in-SketchUp beh **1815 PASS** (nad vetvou KOV-D1a, 6.9. — nová sekcia `run_kovd1a`: Undo aj Redo owner mapovania).

## Robí sa

**Blok 1b uzavretý až na D-51** · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18; R-13 čaká na Michala) · **1e HOTOVÁ** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)).
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)), mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + fix #286), **KOV-H KOMPLET** (#283 + #285), **KOV-B1** (#284), **KOV-B2** aj **KOV-B3** hotové — **slice B je KOMPLET**.
**KOV-C má package v2 (5.9., PR #301, #19):** nemenné recepty, kódy v setoch, žiadny fallback NL; ZMRAZENÝ.
**KOV-C KOMPLET:** C1 jadro (#302), C2a príprava (v0.9.30), C2b aktivácia (#304, v0.9.31), C2b-M materiálový kanál (#305, v0.9.32) a **C2c UI zásuviek** (v0.9.33).
**KOV-D má package v2 (6.9., PR #307, checkpoint #20): ZMRAZENÝ**, rez na malé série D1a/D1b · D2a/D2b · D3a/D3b · D4 · D5. **D1a (jadro mapovania)** (v0.9.34), **D1b (UI výberu setu)** (v0.9.35) aj **D1c (antracit seed)** (v0.9.36) hotové — ďalej D2 (zámky osí), D3 (novšia verzia receptu), D4, D5.
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex;
vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor.
**Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie:** ~~D-52~~ → ~~KOV-A~~ → ~~KOV-H~~ → ~~KOV-B~~ → ~~KOV-C~~ (všetko v maine; C1+C2a+C2b+C2c) → **KOV-D** → E/F/G/I; súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **KOV-D1b — SET ZÁSUVKY SA DÁ VYBRAŤ (Štúdio aj karta)** (v0.9.35, 6.9.2026): **Štúdio → Kovanie → Predvoľby projektu** má v tej istej tabuľke **štyri riadky
  zásuviek** (výsuv × klasické/Tip-On × kovové bočnice/drevený box) a ponúka **len to, čo naozaj sadne**: Atira ako **rodina „podľa výšky“** (H70 · H144 · H176 naraz),
  Quadro ako pevný set, **neaktívny set už nie** (uložený výber ostane vidno). V **Inspectorovi → Kovanie** sa ten istý výber prepne **pre skrinku** aj **pre jedno čelo**
  (a vráti na projekt). **Nosnosť sa nákupnou voľbou nikdy nemení**; rozklik **Technický detail** navyše ukáže **čo je v balení**. Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-D1c — ATIRA ANTRACIT SA DÁ VYBRAŤ** (v0.9.36, 6.9.2026): pribudlo **6 setov „Atira antracit"** (H70 · H144 · H176 × klasické/Tip-On) s kódmi z Démosu. V **Pravidlách
  Štúdia** aj na **karte čela** je pri zásuvkách nová voľba **„Atira antracit podľa výšky"**; **predvoľba ostáva biela** a existujúce zákazky sa nemenia. Antracit **nemá kit
  pre každú dĺžku** (SiSy H176/350 a 520, všetky NL 620) — taká zásuvka je **červená** („nákup nenašiel kit"), nikdy sa ticho neobjedná biely. Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-D1a — VLASTNÝ KIT PRE JEDNO ČELO (jadro, bez viditeľnej zmeny)** (v0.9.34, 6.9.2026): server vie po novom uložiť výber setu **pre konkrétne čelo** a **neaktívny set
  sa už nedá novo vybrať**. **Jediná zmena, ktorú vidno:** zásuvka s **poškodenou pripnutou verziou receptu** je teraz **červená**. Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-C2c — ZÁSUVKU VIDNO V INSPECTOROVI (slice C KOMPLET)** (v0.9.33, 6.9.2026): karta zásuvkového čela má **jeden riadok** „Atira · H70 · NL 470 · 30 kg · SiSy · recept v1“ a rozbaliteľný **Technický detail**; nevyriešená zásuvka ukáže **červenú vetu, prečo**, v **Nákupe** je bez kitu **červená**. Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-C2b + C2b-M — ZÁSUVKA NAOZAJ VZNIKNE A DÁ SA JEJ NASTAVIŤ MATERIÁL** (v0.9.31 a v0.9.32, 5.–6.9.2026): čelo označené ako **Atira** alebo **Quadro V6** dostane **vyrábané dielce** do modelu aj kusovníka a **jednu položku výsuvu** do nákupu; nevyriešená zásuvka **nevyrobí nič**, je **červená v Kontrole** a zastaví export (chýbajúci kit **aj VEPO**).
  Štúdio → Materiály má riadok **„Zásuvky“** a plugin nepustí dosku, ktorou sa zásuvka nedá vyrobiť (Atira **16**, Quadro V6 **16/18**) žiadnou cestou. **Zákazky bez zásuvkovej klasifikácie sa nemenia.** Plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **KOV-C1 + KOV-C2a — JADRO A PRÍPRAVA ZÁSUVIEK (bez viditeľnej zmeny)** (v0.9.29 a v0.9.30): nemenné recepty + SHA register, svetlý priestor okolo čela, **4. materiálový kanál** (UNI 16 mm), ABS pravidlá a **8 setov s kódmi**. Plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **GHOST-D2 — DOSKA SA DÁ NAKRESLIŤ NA ROZMER** (v0.9.28, 5.9.2026): karta Dosky má vedľa „Vložiť" aj **„Nakresliť"** — doska vznikne **dvoma ťahmi**, **čísla sa dajú napísať** do meracieho poľa, **zamknuté pole karty ťah preskočí**, rozmer nad limitom plugin **odmietne s hláškou**, **Esc** nevloží nič a vloženie je **jeden krok Späť**. Plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md).
- **Staršie uzávery** (**KOV-B3** editor setu v modale so živým náhľadom v0.9.26 · **NÁSTROJE-1** toolbar „Noxun Nástroje“ v0.9.24–v0.9.25 ·
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
