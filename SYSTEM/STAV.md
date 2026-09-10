# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.60 · 10.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(PR #265/#268/#270/#271 + uzáver). Ustálené vzory fázy ŠTÚDIO sú v [archiv/KRONIKA.md](archiv/KRONIKA.md), vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo). **Blok KOVANIE má v maine slices A · H · B · C · D · W · F · E · G — ostáva jediná: I.**
**KOV-A** dala čelám typy **výklop · sklop · blenda**, pamäť na **smer otvárania**, kartu čela a kresbu smerov v modeli. **KOV-H** dala **ad-hoc kovanie** priamo v Inspectore.
**KOV-B** dala setom **klasifikáciu**, jediný zoznam výrobcov a rád (`core/hardware_taxonomy.rb`) a vytiahla katalóg aj editor setu na obrazovku. **KOV-C** dala **zásuvky
z nemenných receptov**, **KOV-D** ich výber a zámky, **KOV-F** závesy, **KOV-E** výklopy a **KOV-G** nohy s príchytmi sokla (nižšie).
**Pozor na kompatibilitu:** čo uloží v0.9.20, to **v0.9.18 už nepoužije** — model/šablóna (`CONFIG_SCHEMA` 4 + brána `assess_set_defs`), knižnica setov aj projektový snapshot
(`std` 3) a katalóg kovania s výrobcom (`schema` 2). Pred prvou takou zákazkou aktualizovať **obe PC** (D-52 updater).

**Testy k v0.9.60:** **3769 headless** · 104 JS sád · in-SketchUp **2094 PASS / 0 FAIL** nad vetvou KOV-G1b a **2107 PASS / 0 FAIL** nad hlavou KOV-G2 `b06fd87` (10.9.) — vrátane sekcie `run_kovg`.
Dva scenáre opravného kola G2 (šablóna so setom nôh, zmena setov počas ghost session) sú **napísané, ešte nespustené**.

## Robí sa

**Blok 1b uzavretý až na D-51** · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18; R-13 čaká na Michala) · **1e HOTOVÁ**.
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)), mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + fix #286), **KOV-H KOMPLET** (#283 + #285), **slice B KOMPLET** (#284 + B2 + B3), **KOV-C KOMPLET** (C1 #302 · C2a–C2c v0.9.30–0.9.33),
**KOV-D KOMPLET** (D1a–D5, v0.9.34–0.9.42, 8 PR za deň), **KOV-W** (hmotnosť + D-125, v0.9.47), **KOV-F KOMPLET** (jadro závesov v0.9.50 + editor v0.9.51/52),
**KOV-E KOMPLET** (výklopy HK/HL: #332–#334, v0.9.53–0.9.55; fixy #335/#336).
**KOV-G KOMPLET (10.9.2026):** G1a dáta (#337, v0.9.58) · G1b pravidlá (#338, v0.9.59) · G2 UI + **D-111** (#339, v0.9.60) — z bloku KOVANIE ostáva **KOV-I**
(šablóny — uložiť aj kovanie), potom **uzáver bloku KOVANIE** (minor bump na 0.10.0).
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor. **Limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie:** ~~D-52~~ → ~~KOV-A~~ → ~~KOV-H~~ → ~~KOV-B~~ → ~~KOV-C~~ → ~~KOV-D~~ → ~~D-118~~ → ~~D-121~~ → ~~KOV-W~~ → ~~KOV-F~~ → ~~KOV-E~~ → ~~KOV-G~~
→ **KOV-I** (posledná dávka bloku; package v [PLAN.md](PLAN.md)) → uzáver bloku KOVANIE (minor bump) → D-114 balík Čiel; súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **KOV-G — NOHY 4/6, PRÍCHYT SOKLA A SET NÔH VIDITEĽNÝ PRI VKLADANÍ** (v0.9.58–0.9.60, 10.9.2026): set nôh pozná **výšku sokla 17–220 mm** (17–20 STRONG klzák,
  55–220 Häfele **AXILO** + platnička; zóna **20–55 mm ostáva ORANGE** — vedome), počet nôh ide zo **šírky korpusu** (< 1000 → 4, od 1000 → 6) a **príchyt sokla**
  pribudol ako vlastná položka (1 / 2 od 55 mm, **len pri samostatnej soklovej lište**). Oranžové kontroly: stará zákazka na starom sete nôh, nesúlad príchytov po ručnom
  zámku počtu nôh, duplicity. **A hlavne (D-111):** v Základných pribudol **jeden riadok „Nohy"** — povie vetou, čo skrinka dostane, **už pri vkladaní** (aj v ghost pásiku)
  a potom pri sokli v Korpuse, so **selectom setu** (ten istý ovládač ako v Kovaní). Katalóg +9 kódov (Démos + Quatro LM), taxonómia výrobcu Häfele. [KRONIKA](archiv/KRONIKA.md).
- **KOV-E — VÝKLOP DOSTANE KOVANIE SÁM** (v0.9.53–0.9.55, 9.9.2026): HK top podľa **LF = výška korpusu × (hmotnosť čela + 0,5 kg)** → 22K2300…2900, HL top podľa výšky a hmotnosti
  (mechanizmus + ramená + **tyč vždy**, od 1100 mm dve), **sklop = závesy ako dvierka**, **tmavý set** per čelo; červené stopky pri mimo tabuľky, HL + Tip-On a starej zákazke. [KRONIKA](archiv/KRONIKA.md).
- **Staršie uzávery** (**KOV-W** hmotnosť skrinky v Inspectore vrátane ťažšieho odhadu pri neznámej hustote v0.9.47 · **D-121** ľudské názvy dielcov zásuvky a VEPO riadok ≤ 20 znakov v0.9.45/46 ·
  **FIX #335 + #336** preklad detailu nesediaceho setu má jednu definíciu, AST guard duplicitných `def` v0.9.56/57 · **KOV-F** závesy podľa Noxun tabuľky, Tip-On svoj set, kontroly dvierok prestaviteľné v Pravidlách v0.9.48–0.9.52 ·
  **D-118a + D-118b** katalóg pozná kódy, ktoré si plugin sám objednáva (114 položiek z Démosu), a zásuvka objedná správnu sadu vrátane PTOs modulu v0.9.43/44 · **KOV-D5** zásuvka ukazuje olep na správnej hrane v0.9.42 ·
  **KOV-D4** ceruzka v Kontrole a „Bez kódov" po ľudsky v0.9.41 · **KOV-D1b + D1c** výber setu zásuvky vrátane antracitu v0.9.35/36 · **KOV-C2b + C2b-M** zásuvka naozaj vznikne a dá sa jej nastaviť materiál v0.9.31/32 ·
  **KOV-D3a + D3b** prechod na novšiu verziu receptu — latentný rámec v0.9.39/40 · **KOV-D2b** klikacie zámky výšky a dĺžky zásuvky v0.9.38 · **KOV-D2a** zámky osí zásuvky, `CONFIG_SCHEMA` 7 v0.9.37 ·
  **KOV-C1 + C2a** nemenné recepty, SHA register, 4. materiálový kanál a 8 setov s kódmi v0.9.29–v0.9.30 · **GHOST-D2** doska sa dá nakresliť na rozmer v0.9.28 · **KOV-C2c** riadok zásuvky a Technický detail na karte čela v0.9.33 ·
  **KOV-D1a** vlastný kit pre jedno čelo v0.9.34 · **KOV-B3** editor setu v modale so živým náhľadom v0.9.26 · **NÁSTROJE-1** toolbar „Noxun Nástroje“ v0.9.24–v0.9.25 · **GHOST-D1** doska sa kladie klikom v0.9.27 ·
  **KOV-B2** katalóg kovania so stromom a modalom v0.9.23 · **KOV-H2** ad-hoc kovanie priamo v Inspectorovi v0.9.20 · **1d/R-14 · R-12 · R-11** zákazka z novšieho pluginu sa už ticho nezmrzačí v0.9.2–v0.9.4 ·
  **D-52** Aktualizovať jedným klikom v0.9.14 · **SMOKE 3.9. + D-115/D-116** v0.9.21 · **VÝSTUPY D-112 + D-113** v0.9.22 · **KOV-B1** v0.9.19 · **KOV-H1** v0.9.18 · **KOV-A2b** v0.9.17 ·
  UZÁVER BLOKU GHOST VKLADANIE **v0.9.0** · 1d/R-02 · R-02b · R-01+R-04 · R-07 · R-08 · R-03 · R-34 · 1b-6a/6c · 1b-4 · 1b-3 · VEĽKÝ TEST 26.8. · DOCS CLEANUP · PICKER-1/-2/-3 · TEST-1 · ŠT-4b uzáver ŠTÚDIA **v0.8.0** · KRESBA · UI-A…UI-D · KLINIKA · Materiály 2.0 #89–#140) — v [archiv/KRONIKA.md](archiv/KRONIKA.md)

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
