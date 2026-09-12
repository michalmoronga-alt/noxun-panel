# Noxun Engine

Parametrický nábytkársky systém pre SketchUp (Ruby plugin). Korpusy generuje kód z konfigurácie — žiadne Dynamic Components: zóny s priečkami, čelá s lockmi (fixed/auto), šablóny, scale → automatická prestavba na mm, 2D náhľad v paneli, materiály s dekorovými skupinami, kovanie so setmi a výrobné aj obchodné výstupy (kusovník, VEPO CSV, nákupné zoznamy, rozpočet, cenová ponuka).

**Stav: v0.12.0 — BLOK M-R VZHĽAD KOMPLET.** Dosky aj ABS rovnakého dekoru a povrchu majú jeden spoločný vzhľad naprieč hrúbkami; zástena má jeden vzhľad. Textúra je voliteľná, obyčajné farby zostávajú. Vzhľad sa zachová pri prestavbe a produktovej kópii; textúra rešpektuje fyzickú mierku a smer dekoru aj ABS.

V **Štúdiu → Materiály → detail dekoru → Vzhľad pri povrchu** priraď obrázok, otvor **Upraviť v SketchUpe** a v natívnom paneli uprav mierku či vlastnosti povrchu. **Uložiť vzhľad do knižnice** ho uloží pre ďalšie dielce. Farba sa ukladá hneď, **Použiť katalógovú farbu** odstráni vlastný vzhľad. **Späť vracia modelovú zmenu; uložená knižnica ostáva.** [Overenie a krátky smoke](SYSTEM/archiv/MR_ZAVER_2026-09-12.md).

Predtým: **v0.11.0 — BALÍK ČIEL KOMPLET.** Okraje čiel sa nastavujú samostatne hore, dole, vľavo a vpravo pre celú skrinku. UKW profil môže byť na všetkých hranách dvierok, zásuvkových čiel, výklopov, sklopov a blénd; zvislo na dvierkach vždy oproti pántom. Profil/hrana sú v karte aj v hromadných Úchytkách. Šesť ikon pridáva typ priamo v jednom rade. Neurčené pánty zostanú návrhom vo formulári; export, kópia aj šablóna počkajú na platný potvrdený zápis.

Predtým: **v0.10.0 — BLOK KOVANIE KOMPLET.** Plugin **vie kovanie sám**: sety aj katalógové položky sú klasifikované (typ použitia · otváranie · konštrukcia · výrobca · rada) a katalóg so stromom Kategória → Výrobca → Rada aj editor setu so živým náhľadom žijú v Štúdiu. **Zásuvka vzniká z nemenného receptu** (Hettich InnoTech Atira, Hettich Quadro V6) — dielce, výška, nominálna dĺžka a nosnosť určuje recept, objednávacie kódy kitu určuje set kovania, takže nákup nikdy nezmení fyzický návrh; **závesy** sa počítajú podľa Noxun tabuľky (Tip-On má vlastný set), **výklopy AVENTOS HK top / HL top** si nájdu silový variant z výšky a hmotnosti čela, **nohy 4/6 podľa šírky korpusu a príchyt sokla** vidno vetou v Základných už pri vkladaní, **šablóny vedia uložiť aj kovanie** a ad-hoc položku pridáš ku skrinke či čelu priamo v Inspectore. Katalóg pozná kódy, ktoré si plugin sám objednáva; plugin sa aktualizuje jedným klikom (Štúdio → O plugine). Blok: 50 PR #277–#340, 2.–10.9.2026.

Predtým: **v0.9.0 — BLOK GHOST VKLADANIE KOMPLET.** Skrinka sa vkladá **klikom tam, kde sa pozeráš**: po „Vložiť" visí na kurzore ghost so zelenou prednou stenou a viditeľnou kotvou, šípky ho otáčajú a prepínajú výškový zámok, Alt cykluje kotvy, v zámku sa prichytáva na rohy a hrany existujúcich skriniek — klik ju položí jedným Undo krokom presne tam, kde ghost stál (PR #265/#268/#270/#271; potvrdené smoke testom 31.8.2026).

Predtým: **v0.8.0 — FÁZA ŠTÚDIO KOMPLET.** Plugin má **dve okná**: **Inspector** (čo je označené a čo s tým) a **Štúdio** (celá zákazka na jednom mieste). Štúdio má **dvanásť živých sekcií** — Kusovník · Kontrola · Nákup kovania · Rozpočet · Cenová ponuka · Materiály · Kovanie · Pravidlá · Šablóny · Dodávateľ/Demos · Nastavenia rozpočtu · O plugine (Nárezový plán je jediná neaktívna, patrí do fázy 2). Fáza ŠTÚDIO (ŠT-1a … ŠT-4b, PR #192–#228) zrušila **šesť satelitných okien** — Výroba · Materiály projektu · Katalóg kovania · Pravidlá kovania · Šablóny · Nastavenia rozpočtu — a ich obsah presunula do sekcií **1:1 s jedinou výnimkou**: uloženie novej šablóny ostalo v Inspectore (má po ruke označenú skrinku), takže sekcia Šablóny ich len spravuje. Žiadna funkcia sa nestratila. Predtým: etapa V0.6 (katalógy a ceny) obsahovo splnená, prvá reálna zákazka **KLINIKA** (254 dielcov) postavená čisto z pluginu a porovnaná s ručným rozpočtom; Inspector rework (UI 2.0, bloky UI-A…UI-D). Potom nasledovala **stabilizačná revízia** (dlhy fázy, refactory), blok **GHOST VKLADANIE** a blok **KOVANIE**; balík **Čiel je hotový** (v0.11.0), ďalej dotiahnutie V1 ([SYSTEM/PLAN.md](SYSTEM/PLAN.md)).

## Kam sa pozrieť

| | |
|---|---|
| **Kde projekt je** (vstupný bod každého sedenia) | [SYSTEM/STAV.md](SYSTEM/STAV.md) |
| Čo sa ide robiť — bloky prác a zaradené položky | [SYSTEM/PLAN.md](SYSTEM/PLAN.md) |
| Záväzný dátový kontrakt (Noxun Component Standard) | [SYSTEM/STANDARD.md](SYSTEM/STANDARD.md) |
| Pravidlá kódu — SketchUp, DC, UI dizajn, architektúra modulov | [docs/](docs/) |
| História dávok a rozhodnutí | [SYSTEM/archiv/KRONIKA.md](SYSTEM/archiv/KRONIKA.md) |
| Pravidlá práce v repe (workflow, verzie, testovanie) | [CLAUDE.md](CLAUDE.md) |

## Inštalácia a vývoj

- **Inštalácia (dev):** `INSTALL_noxun_engine.ps1` → **reštartuj SketchUp** → Extensions → Noxun Engine → Panel. Je to **jeden balík**: nástroje Mower a Snaper sú od v0.9.25 súčasťou enginu (toolbar „Noxun Nástroje"), takže ich **staré samostatné inštalácie sa odstránia samé** — raz inštalátorom a raz pri prvom štarte pluginu. Staré toolbary zmiznú z okna až po reštarte; ak sa niektorý súbor nedá zmazať (SketchUp beží), skript to povie s cestou a plugin to skúsi znova pri ďalšom štarte.
- **Testy:** `ruby tests/run_all.rb` (headless) · JS sady po jednej — bash: `for f in tests/js/test_*.js; do node "$f" || exit 1; done` (glob priamo za `node` spustí len prvý súbor) · `scripts\run_su_tests.ps1` (in-SketchUp)
- **Workflow:** vetva → PR → Codex review → merge (podrobne v [CLAUDE.md](CLAUDE.md))
