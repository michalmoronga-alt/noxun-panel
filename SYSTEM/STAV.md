# STAV — kde projekt je

> **Vstupný bod každého sedenia.** Prečítaj tento súbor ako prvý, potom [PLAN.md](PLAN.md). Mapa autorít celého priečinka: [README.md](README.md).
> **Údržba:** pri uzávere dávky/etapy sa STAV **PREPÍŠE** (nikdy sa nedopĺňa na koniec) — nahradený text ide odsekom navrch „Záznamy dávok" v [archiv/KRONIKA.md](archiv/KRONIKA.md). Drobné fix PR ho nemenia. Drž ho krátky: **max 80 riadkov a 12 kB** (stráži guard test).

## Stav

**v0.9.4 · 1.9.2026.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste)
s **dvanástimi živými sekciami** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine.
Jediná neaktívna položka navigácie je **Nárezový plán** (fáza 2, dôvod v tooltipe).

**Blok GHOST VKLADANIE je HOTOVÝ (v0.9.0).** Skrinka sa už nekladie naslepo mimo pohľadu: po „Vložiť" visí na kurzore ghost so zelenou prednou stenou a viditeľnou kotvou,
šípky ho otáčajú a prepínajú výškový zámok, Alt cykluje kotvy, v zámku sa prichytáva na rohy a hrany existujúcich skriniek a klik ju položí **jedným Undo krokom presne tam, kde ghost stál**.

Etapa **V0.6 (katalógy a ceny) je obsahovo splnená**: plugin vedie zákazku od návrhu cez materiály a ABS až po kovanie, VEPO, kusovník, nákupné zoznamy, rozpočet a cenovú ponuku.
**Od 20.8. sa z pluginu objednávajú REÁLNE zákazky** — zákazka KLINIKA (254 dielcov) je postavená čisto z pluginu a overená proti ručnému rozpočtu.
Nálezy z reálnej výroby a chyby v cenách majú preto **najvyššiu prioritu triedenia** ([PLAN.md](PLAN.md), Pravidlo pre postrehy).

**Hotové veľké celky:** INSPECTOR REWORK (UI-A…UI-D) · **fáza ŠTÚDIO** (ŠT-1a…ŠT-4b, PR #192–#228) — **zaniklo šesť okien** a s posledným z nich celá mašinéria premostení ·
**blok KRESBA** (smer dekoru na dielci a čele) · **blok GHOST VKLADANIE** (PR #265/#268/#270/#271 + uzáver). Ustálené architektonické vzory fázy ŠTÚDIO
(okno zaniká — modul žije · uzavretý whitelist akcií · session token · echo vs. plný push · optimistický zámok) sú v [archiv/KRONIKA.md](archiv/KRONIKA.md),
vedomé odchýlky v `zdroje/ui20/UI20_KONTRAKT.md` §7.

**Testy k v0.9.4:** **2280 headless** · 78 JS sád · plný in-SketchUp beh **1264 PASS / 0 FAIL**.

> **Poznámka k procesu:** Codex review bol 21.–24.8. **nedostupný** — PR **#186–#226** prešli bránou so slepým subagentom. **Post-hoc sweep je od 27.8. HOTOVÝ** (34 PR cez Codex CLI + triáž 54 nezodpovedaných threadov): dve reálne P1 slepým kolám ušli a týždeň žili v `main`, obe sú dávno opravené — [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-E**.

## Robí sa

**Blok 1b uzavretý až na D-51** (čaká na Michalove hodnoty) · **1c hotový** ([AUDIT_REGISTER.md](AUDIT_REGISTER.md)) · **1d beží** (hotové R-06/R-08/R-01+04/R-34/R-02(b)/R-03/R-07/R-23.1/R-11/R-12/R-14; ďalej R-18 + zvyšok; R-13 čaká na Michala).
**1e HOTOVÁ** — posledný package KOVANIE vznikol 2.9. **Blok KOVANIE ŠTARTOVAL (2.9.):** architektúra V1 uzavretá po cross-audite (Codex/GLM/Opus) + reconcile + O1–O3
([zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)), mockup schválený
([zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)), packages KOV-A/B/H v [PLAN.md](PLAN.md); **D-52 UPDATER JE KOMPLET (v0.9.14)** — D-52a #277 (jadro) · D-52b1 #278 · D-52b2 #279 (UI, apply s bariérou); in-SU 1297/0; tvrdý predpoklad prvého schema bumpu SPLNENÝ → **KOV-A štartuje** (Codex audit návrhu beží).
**Od 2.9. večer bez Fable** — orchestruje Opus, review Codex; vstupný bod je [zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md](zdroje/next_sessions/KOVANIE_HANDOFF_2026-09-02.md) + tento súbor; packages všetkých slices sú v PLAN. **Drž limity dávok:** malé PR, pravidlo 3 kôl, in-SU pri builderoch/observeroch.

## Ďalší krok

**Poradie (Michal 2.9.: „poradie je na tebe"):** ~~D-52a~~ → ~~D-52b1/b2~~ (v maine) → **KOV-A** (čelá — dátová vrstva; audit → implementácia) → **KOV-A** čelá dátová vrstva
→ **KOV-B** katalóg+sety (paralelne **KOV-H** ad-hoc) → **KOV-C** context_for + recepty + odvodené dielce → **KOV-D** resolver + zámky + brány → E/F/G/I. Súbežne 1d podľa kapacity.
Každá dávka: package v PLAN (autorita) + FINAL + mockup → `codex-audit` (KOV-A/B/C/D/H povinné) → subagent vo worktree → `codex-po-pr` → merge → uzáver. V1 checklist v [V1_VIZIA.md](V1_VIZIA.md).

## Posledné uzávery

- **1d/R-14 — zákazka z NOVŠIEHO pluginu už pri prvom kliku v Rozpočte ticho nepríde o dáta** (rozpočtové dáta sú uzavretý zoznam polí; čo staršia verzia nepozná, to sa doteraz
  pri prvej úprave zahodilo — a nasledujúci XLSX by niesol podhodnotenú sumu). Taký rozpočet sa ďalej **číta a zobrazuje**, ale **upravovať sa nedá**, obe sekcie (Rozpočet aj
  Cenová ponuka) nesú banner s dôvodom a **oba XLSX exporty sú zastavené**; VEPO a nákup kovania bežia ďalej — v0.9.4 (1.9.2026) · **Michal večer:** novší plugin sa ručne simulovať nedá; over len, že **bežná práca s Rozpočtom je bez zmeny** (pridaj vlastnú položku, prepíš sumu, ulož „XLSX rozpočet").
- **1d/R-12 — to isté pri PRESTAVBE skrinky** (config skrinky je uzavretý zoznam polí): taký korpus sa ďalej **číta, počíta aj exportuje**, ale **prestavať** sa nedá — a rovnako
  sa odmietne kópia, uloženie ako šablóna aj použitie/vklad šablóny z novšej verzie — v0.9.3 (1.9.2026) · **Michal večer:** over len, že **bežná práca ide bez zmeny** (uprav skrinku, vlož kópiu, ulož šablónu a použi ju na inú skrinku).
- **1d/R-11 — poškodený súbor nastavení už neprepíše novšiu prácu staršou zálohou** (plugin zo zálohy ďalej ČÍTA, ale zápisy do pokazeného súboru VYPNE a povie prečo —
  sety a pravidlá kovania, ABS pravidlá, rozmerové rady, sadzby dodávateľa) — v0.9.2 (1.9.2026) · **Michal večer:** odlož si kópiu `%APPDATA%\NOXUN\Engine\hardware_sets.json`,
  v origináli zmaž pár znakov a ulož — v Štúdiu → Kovanie musia byť **sety stále vidieť** + **oranžový banner**, „+ Nový set / Upraviť / Zmazať" vypnuté, ale **predvoľby projektu fungujú**; po zmazaní pokazeného súboru je zase všetko po starom.
- **1d/R-23.1 — Escape zatvára aj posledných šesť ručných modálov** (ABS páska v Inspectorovi; obnova zálohy, mazanie variantu, „Nahradiť UNI…", Demos diff a mazanie položky
  kovania v Štúdiu), **jedno stlačenie = jedna vrstva** — v0.9.1 (1.9.2026) · **Michal večer:** Štúdio → Kovanie, potvrdenie zmazania + **Esc** (musí sa zavrieť); nad **oknom prepočtu cien počas behu** sa Esc zavrieť NESMIE.
- **D-52 — Aktualizovať jedným klikom** (v0.9.14, 3.9.2026, PR #277/#278/#279): Štúdio → O plugine → priečinok, kontrola verzie, tlačidlo; bariéra okien, atomický swap, restart latch; downgrade zakázaný. · **Michal večer:** cesta na NOVŠIU kópiu → Aktualizovať → okná sa zavrú → hláška → reštart → nová verzia; staršia kópia = tlačidlo neaktívne; odpojený disk = Štúdio nezamrzne.
- **UZÁVER BLOKU GHOST VKLADANIE (v0.9.0, 31.8.2026)** — **Michal odškrtol CELÝ smoke checklist** (11 bodov), uzáver bol čisto dokumentačný (plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md)); tým istým sedením odškrtol aj staršie odložené testy **R-08 · R-01+R-04 · R-02 · R-07** — **všetky PASS**, žiadny nález.
- **1d/R-07 — starší a novší plugin si už nepoškodia knižnicu setov kovania** (v0.8.21, 30.8., **overené Michalom 31.8.**) · **1d/R-02b — Ctrl+S už nezahadzuje rozpísanú prácu** (v0.8.23, 30.8.; **Michal večer:** uprav šírku skrinky a do sekundy daj **Ctrl+S** — zmena sa musí uložiť a rozpísané polia ostať).
- **1d/R-02 — panel už nezapíše do nesprávneho dokumentu** · **1d/R-01+R-04 — observer veľkosti je multi-model bezpečný a už si nepamätá zmazané** — v0.8.17/v0.8.19 (30.8.), **overené Michalom 31.8.**; **R-03** (šev vkladania, v0.8.20) a **R-34** (brána exportov, v0.8.18) sú bez UI zmeny.
- **1d/R-08 — dve okná SketchUpu si už neprepíšu nastavenia** (sety a pravidlá kovania, ABS pravidlá, rady aj sadzby dodávateľa; zastaraný formulár skončí hláškou „medzitým sa zmenilo") — v0.8.16 (30.8.) · **overené Michalom 31.8.**
- **1d/R-06a — dĺžkové kovanie sa už nenacení ako kusy** (úchytkový profil sa cez set nedostane do nákupu ani do ponuky — vydá oranžový riadok Kontroly) — v0.8.15 (29.8.) · **Michal večer:** namapuj úchytkový profil na set — nesmie sa objaviť v Nákupe ani v Rozpočte.
- **P0-HF — finálne brány pred zápisom exportov** (chybný XLSX/CSV už nevznikne: **tvrdo** sa zastaví záporná „Nábytková zostava", nesúlad ponuky s rozpočtom a zliate ID skriniek; **riadky bez ceny** až po druhom, vedomom kliku — STANDARD §11.3) — v0.8.14 (29.8.) · **Michal večer:** riadok bez ceny + „XLSX rozpočet" = prvý klik neuloží nič, druhý PRIZNÁ podhodnotenú sumu.
- **1c — AUDIT KÓDU KOMPLET** (traja audítori → [AUDIT_REGISTER.md](AUDIT_REGISTER.md); Codex review #250 korigoval samotný audit — STANDARD §11.3 má prednosť pred audítorom) — 29.8., bez zmeny kódu · **F/D-27 — tagy modelu z panela** — v0.8.13 (28.8.)
- **1b-E — POST-HOC SWEEP KOMPLET** (34 PR spätne cez Codex CLI + triáž 54 threadov; 29 nálezov, 10 platných) — kandidáti v [zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md)
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
