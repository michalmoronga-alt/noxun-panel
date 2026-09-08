# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.52 · 9.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**. **Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu;
nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** · **blok KRESBA** · **blok GHOST VKLADANIE**
(PR #265/#268/#270/#271 + uzáver). Ustálené vzory fázy ŠTÚDIO sú v [archiv/KRONIKA.md](archiv/KRONIKA.md), vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Výstupy zákaziek bez zásuvkovej klasifikácie sú obsahovo identické** (golden, CSV bajtovo). **Blok KOVANIE má v maine celý slice A, celý slice H, CELÝ slice B (B1+B2+B3) a CELÝ slice C (C1+C2a+C2b+C2c).** **KOV-A** dala čelám typy **výklop · sklop · blenda**, pamäť na
**smer otvárania**, kartu čela a kresbu smerov v modeli. **KOV-H** dala **ad-hoc kovanie** priamo v Inspectore. **KOV-B** dala setom **klasifikáciu**, jediný zoznam výrobcov
a rád (`core/hardware_taxonomy.rb`) a vytiahla katalóg aj editor setu na obrazovku. **KOV-C** dala **zásuvky z nemenných receptov** (nižšie).
**Pozor na kompatibilitu:** čo uloží v0.9.20, to **v0.9.18 už nepoužije** — model/šablóna (`CONFIG_SCHEMA` 4 + brána `assess_set_defs`), knižnica setov aj projektový snapshot
(`std` 3) a katalóg kovania s výrobcom (`schema` 2). Pred prvou takou zákazkou aktualizovať **obe PC** (D-52 updater).

**Testy k v0.9.52:** **3511 headless** · 98 JS sád · posledný plný in-SketchUp beh **2028 PASS / 0 FAIL** (nad vetvou KOV-F1, 9.9.; F2 je UI dávka, in-SU nebežal) — vrátane sekcie `run_kovf` (závesy, `hinge_stale` aj „prestavba sama nestačí").

## Robí sa

**Blok 1b uzavretý až na D-51** · **1c hotový** · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18; R-13 čaká na Michala) · **1e HOTOVÁ** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)).
**Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)), mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A KOMPLET** (#280–#282 + fix #286), **KOV-H KOMPLET** (#283 + #285), **KOV-B1** (#284), **KOV-B2** aj **KOV-B3** hotové — **slice B je KOMPLET**.
**KOV-C má package v2 (5.9., PR #301, #19):** nemenné recepty, kódy v setoch, žiadny fallback NL; ZMRAZENÝ.
**KOV-C KOMPLET:** C1 jadro (#302), C2a príprava (v0.9.30), C2b aktivácia (#304, v0.9.31), C2b-M materiálový kanál (#305, v0.9.32) a **C2c UI zásuviek** (v0.9.33).
**KOV-D (package v2, PR #307, #20): slice D je KOMPLET (v0.9.42, 7.9.2026)** — D1a (0.9.34) · D1b (0.9.35) · D1c (0.9.36) · D2a (0.9.37) · D2b (0.9.38) · D3a/D3b (0.9.39/40) ·
D4 (0.9.41) · D5 (0.9.42); 8 PR za deň (#310–#317). **KOV-W (hmotnosť dielcov + D-125) HOTOVÁ (v0.9.47)** — podklad pre závesy a výklopy.
**KOV-F KOMPLET** — jadro závesov (v0.9.50) + **editor door guardov v Pravidlách (F2, v0.9.51; fix kolo Codex #330 — v0.9.52)**; z bloku KOVANIE ostáva **E → G → I** (packages v [PLAN.md](PLAN.md)); minor bump až pri uzávere celého bloku.
**Od 3.9. opäť Fable (Max, ~mesiac; priorita = uzavrieť V1)** — orchestruje Fable, implementujú Opus subagenti, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor. **Limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie:** ~~D-52~~ → ~~KOV-A~~ → ~~KOV-H~~ → ~~KOV-B~~ → ~~KOV-C~~ → ~~KOV-D~~ (všetko v maine, D1a–D5) → ~~D-118~~ (katalógový seed + sety, a aj b) → ~~D-121~~ (názvy dielcov zásuvky + VEPO kontrakt v1.2) → ~~KOV-W~~ (hmotnosť + D-125) → ~~KOV-F~~ (závesy: jadro F1 + editor F2)
→ **KOV-E → G → I** (poradie rozhodol Michal 8.9.2026; packages v [PLAN.md](PLAN.md), audit E Astra); súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **KOV-F — ZÁVESY PODĽA NOXUN TABUĽKY, TIP-ON SVOJ SET A KONTROLY SA DAJÚ PRESTAVIŤ** (v0.9.48–0.9.51, 8.–9.9.2026): počet už nie je starý odhad, ale **tabuľka** (do 849 → 2 · 850–1700 → 3 · … · 2601–2800 → 7)
  a **krídlo širšie než 600 mm dostane o jeden záves navyše**. Kontrola varuje (počet nemení) pri krídle nad 800 mm, pri čele širšom než vyššom a pri ťažkých dvierkach; nad 2800 mm položka vznikne s počtom 7, ale svieti **červená „mimo tabuľky"**
  (zastaví nákup, rozpočet aj ponuku, rezanie nie) — zhasne ju **ručný zámok počtu**. **Tip-On dvierka** dostanú **P2O set + piest na krídlo** (tabuľku do starej zákazky prinesie **„Doplniť nové predvoľby"**).
  **F2:** všetky tieto kontroly sa dajú v Pravidlách **prestaviť** — zbaliteľný blok „Kontroly dvierok"; nezmysel uloženie odmietne vetou. [KRONIKA](archiv/KRONIKA.md).
- **KOV-W — INSPECTOR UŽ UKÁŽE HMOTNOSŤ SKRINKY (D-125)** (v0.9.47, 8.9.2026): riadok „Hmotnosť" v Základných bol od UI 2.0 prázdny; odteraz ukazuje **skutočný súčet
  výrobných dielcov** (`12,4 kg`). Keď má niektorý dielec materiál **bez známej hustoty** (UNI, „iný" typ), plugin ho **nevynechá** — počíta ho **ťažšie** a povie to:
  `≈ 12,4 kg` s vysvetlením v tooltipe a jedným oranžovým upozornením v Kontrole (pri UNI dielcoch nie — tie už hlásia „materiál neurčený"). Rovnaká hmotnosť je teraz
  aj v pláne pri každom dielci, takže **závesy (F) a výklopy (E) ju majú pripravenú**. Kusovník, VEPO ani ceny sa nemenia. [KRONIKA](archiv/KRONIKA.md).
- **D-121 — DIELCE ZÁSUVKY MAJÚ ĽUDSKÉ NÁZVY A VEPO RIADOK MÁ VŽDY ≤ 20 ZNAKOV** (v0.9.45 + v0.9.46, 8.9.2026): namiesto interného id čela nesú **jeho číslo**
  (`Zas dno 2 s1`, dvojica bokov `Zas bok LP 2 s1`); **objednávku netreba ručne prepisovať** — rovnaké dielce sa zlúčia (`Polica 1 2 3`) a dlhý názov sa skráti
  predvídateľne po celých slovách. **Kontrola** ukáže tvar, ktorý pôjde do objednávky, **LOG** má oddiel „Skrátené názvy". [KRONIKA](archiv/KRONIKA.md).
- **Staršie uzávery** (**D-118a + D-118b** katalóg pozná kódy, ktoré si plugin sám objednáva (114 položiek
  z Démosu), a zásuvka objedná správnu sadu vrátane PTOs modulu v0.9.43/44 · **KOV-D5** zásuvka ukazuje olep na správnej hrane v0.9.42 · **KOV-D4** ceruzka v Kontrole a „Bez kódov" po ľudsky v0.9.41 · **KOV-D1b + D1c** výber setu zásuvky vrátane antracitu v0.9.35/36 · **KOV-C2b + C2b-M** zásuvka naozaj vznikne a dá sa jej nastaviť materiál v0.9.31/32 ·
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
