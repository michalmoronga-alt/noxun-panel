# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.16 · 3.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu; nálezy z výroby a chyby v cenách majú **najvyššiu prioritu** ([PLAN.md](PLAN.md)).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru na dielci a čele) · **blok GHOST VKLADANIE** (PR #265/#268/#270/#271 + uzáver). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Blok KOVANIE má v maine prvé dve dávky.** **KOV-A1** dala čelám typy **výklop · sklop · blenda**, pamäť na **smer otvárania** (= strana pántov), spôsob otvárania aj
klasifikáciu zásuvky; neurčený smer je **RED nález v Kontrole bez exportnej brány**. **KOV-A2a** k tomu pridala **ovládače**: rozbaľovačka typu v riadku čela zanikla a nahradila
ju **karta čela** (typegrid šiestich piktogramov + smer · otváranie · klasifikácia zásuvky), náhľad kreslí smery a typy symbolmi. **Výstupy existujúcich zákaziek sú obsahovo
identické** (golden charakterizácia). **Pozor:** model uložený od v0.9.15 už neprestaví starší plugin (`CONFIG_SCHEMA` 2, guard R-12).

**Testy k v0.9.16:** **2466 headless** · 80 JS sád · plný in-SketchUp beh **1355 PASS / 0 FAIL** (naposledy k v0.9.15 — A2a je UI dávka bez buildera a observera).

## Robí sa

**Blok 1b uzavretý až na D-51** (čaká na Michalove hodnoty) · **1c hotový** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)) · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18 + zvyšok; R-13 čaká na Michala).
**1e HOTOVÁ.** **Blok KOVANIE beží (od 2.9.):** architektúra V1 uzavretá po cross-audite + O1–O3 ([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)),
mockup schválený ([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages v [PLAN.md](PLAN.md); **D-52 UPDATER KOMPLET (v0.9.14)**.
**KOV-A1 HOTOVÁ** (PR #280, v0.9.15 — dátová vrstva čiel) a **KOV-A2a HOTOVÁ** (PR #281, v0.9.16 — karta čela, badge, náhľad symbolov); **ďalšia je KOV-A2b** —
overlay „Smer otvárania" v modeli (modul `direction_check`, dva prepínače = jeden stav, in-SU beh povinný).
**Od 2.9. večer bez Fable** — orchestruje Opus, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor; packages všetkých slices sú v PLAN. **Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie (Michal 2.9.: „poradie je na tebe"):** ~~D-52a~~ → ~~D-52b1/b2~~ → ~~KOV-A1~~ → ~~KOV-A2a~~ (oboje v maine) → **KOV-A2b** (overlay smerov v modeli)
→ **KOV-B** katalóg+sety (paralelne **KOV-H** ad-hoc) → **KOV-C** context_for + recepty + odvodené dielce → **KOV-D** resolver + zámky + brány → E/F/G/I. Súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` (KOV-A/B/C/D/H povinné) → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **KOV-A2a — typ čela sa vyberá PIKTOGRAMOM a smer otvárania sa dá konečne nastaviť** (v0.9.16, 3.9.2026, PR #281): klik na názov typu v riadku otvorí **kartu čela**
  priamo pod ním — šesť dlaždíc typu (Dvierka · Zásuvka · Výklop · Sklop · Blenda · Bez čela) a pod nimi len to, čo dáva zmysel: **Smer** (Ľavé · Neurčené · Pravé),
  **Otváranie** (Klasické · Tip-On), pri zásuvke **Konštrukcia** a **Štandardná/Vnútorná**. Dvojkrídlo sa na smer nepýta (je odvodený), 3/4-krídlové len na **stredné**
  krídla. Neurčený smer má v riadku badge **„smer?"**; **stará zákazka nič nedostane** — nikde sa nič nepredvolí. Náhľad kreslí **prerušované symboly** (šipka na voľnú
  hranu, `?` pri neurčenom, ∧/∨ výklop/sklop, X blenda) · **Michal večer:** vlož skrinku → F2 na **Výklop**, F3 na **Blendu** (postavia sa, náhľad ∧ a X) · jednokrídlové
  dvierka → badge **smer?** + RED v Štúdiu → Kontrola, ale **nákupný CSV aj rozpočet musia prejsť** · daj **Ľavé** → nález zmizne a v náhľade je šipka · **3 krídla** → pribudne
  riadok „Krídlo 2/3", krajné sa nepýtajú · **Tip-On** (zatiaľ informatívne) · ulož šablónu s výklopom a vlož ju · kopíruj ×3 · **KLINIKA** — čísla identické, Kontrola bez nového nálezu.
- **KOV-A1 — dátová vrstva čiel** (v0.9.15, PR #280): nové typy sa **postavia, olepia a idú do kusovníka aj VEPO**, smer/otváranie/klasifikácia sa v zákazke držia, neurčený
  smer je RED nález bez brány; **staré zákazky sa nemenia ani o číslo**. Ovládače doručila KOV-A2a (vyššie) · **Michal večer (ak ešte nebolo):** Štúdio → Pravidlá → ABS
  pravidlá majú riadky **„Výklop/sklop"** a **„Blenda"** (4 hrany 1,0) a tvoje úpravy sú nedotknuté; šírka **599 ↔ 605** (auto 1 vs. 2 krídla) ako doteraz.
- **1d/R-14 — zákazka z NOVŠIEHO pluginu už pri prvom kliku v Rozpočte ticho nepríde o dáta**: taký rozpočet sa ďalej **číta**, ale **upravovať sa nedá** (banner + oba
  XLSX exporty zastavené; VEPO a nákup bežia ďalej) — v0.9.4 (1.9.2026) · **Michal večer:** over len, že **bežná práca s Rozpočtom je bez zmeny**.
- **1d/R-12 — to isté pri PRESTAVBE skrinky**: korpus z novšieho pluginu sa ďalej **číta, počíta aj exportuje**, ale **prestavať** sa nedá (rovnako kópia a šablóny) — v0.9.3 (1.9.2026) · **Michal večer:** over, že **bežná práca ide bez zmeny**.
- **1d/R-11 — poškodený súbor nastavení už neprepíše novšiu prácu staršou zálohou** (plugin zo zálohy ČÍTA, ale zápisy VYPNE a povie prečo) — v0.9.2 (1.9.2026) · **Michal večer:** pokaz kópiu `hardware_sets.json` — sety musia byť **vidieť** + oranžový banner.
- **D-52 — Aktualizovať jedným klikom** (v0.9.14, PR #277/#278/#279): Štúdio → O plugine → priečinok, kontrola verzie, tlačidlo; bariéra okien, atomický swap,
  restart latch; downgrade zakázaný · **Michal večer:** cesta na NOVŠIU kópiu → Aktualizovať → reštart → nová verzia; staršia kópia = tlačidlo neaktívne.
- **UZÁVER BLOKU GHOST VKLADANIE (v0.9.0, 31.8.2026)** — **Michal odškrtol CELÝ smoke checklist** (11 bodov), uzáver bol čisto dokumentačný (plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)); tým istým sedením odškrtol aj staršie odložené testy **R-08 · R-01+R-04 · R-02 · R-07** — **všetky PASS**, žiadny nález.
- **1d/R-02** (panel už nezapíše do nesprávneho dokumentu) · **R-02b** (Ctrl+S nezahadzuje rozpísanú prácu) · **R-01+R-04** (observer veľkosti) · **R-07** (knižnica setov) ·
  **R-08** (dve okná SketchUpu si neprepíšu nastavenia) — v0.8.16–v0.8.23 (30.8.), **všetko overené Michalom 31.8.**; **R-03** a **R-34** sú bez UI zmeny.
- **Staršie uzávery** (1b-6a/6c meno zákazky · 1b-4 · 1b-3 · VEĽKÝ TEST 26.8. · DOCS CLEANUP · PICKER-1/-2/-3 · TEST-1 · ŠT-4b uzáver fázy ŠTÚDIO **v0.8.0** · blok KRESBA · bloky UI-A…UI-D · ŠTART AUTONÓMIE · RETRO · UPRATANIE · séria KLINIKA · Materiály 2.0 a dávky D/E #89–#140) — plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md)

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
