# Podklad — krížový audit V1 (1.10.2026)

> Vrstva `zdroje/` — podklad, nie autorita. Rozhodnutia a definícia „teraz": [ROZHODNUTIA_MICHALA_2026-10-01.md](ROZHODNUTIA_MICHALA_2026-10-01.md).
> **Všetci audítori dostávajú TENTO ISTÝ podklad** a robia **len svoju kartu** (§7). Stav kódu: `main` @ `4da1c3b5`, plugin **v0.17.0**.
> Precedens: celkový audit kódu 1c (august 2026) — [../../AUDIT_2026-08_podklad.md](../../AUDIT_2026-08_podklad.md) → register [../../../AUDIT_REGISTER.md](../../../AUDIT_REGISTER.md).

## 1 · Kontext

Noxun Engine je SketchUp Ruby plugin — parametrický systém na **nábytok na mieru** (korpusy, zóny, čelá, materiály a ABS, kovanie, spotrebiče,
kusovník, VEPO export, nákup, rozpočet, cenová ponuka, nárezový plán). Autor Michal nie je programátor — vyvíja cez AI agentov (orchestrátor +
subagenti, workflow v [../../../WORKFLOW.md](../../../WORKFLOW.md)). **Od 20.8.2026 sa z pluginu objednávajú reálne zákazky** — chyba vo výrobnom
alebo cenovom čísle stojí peniaze. **Všetkých 7 bodov V1 je odškrtnutých** ([../../../V1_VIZIA.md](../../../V1_VIZIA.md)); pred funkciami po V1
ide blok **HARDENING** (pár dní). Tento audit rozhoduje, čo do neho patrí, a zbiera nápady na potom.

Plugin má dve okná: **Inspector** (čo je označené a čo s tým; úzky panel 486 px) a **Štúdio** (celá zákazka; 14 sekcií). Používatelia: Michal a Lucia
(dve PC), stolárska dielňa.

## 2 · Cieľ — štyri osi

| Os | Otázka | Čo NIE |
|---|---|---|
| **K · kód** | Čo v kóde **brzdí alebo predražuje rozširovanie** po V1? Merané **scenármi S1–S5** (§3). | štýl bez dopadu, prepis fungujúceho bez scenára |
| **D · dokumenty a workflow** | Čo v dokumentoch, pravidlách a skilloch je **drahé na čítanie, duplicitné, zastarané alebo protirečivé**? Meraný **scenár S6**. | preformulovanie pre krásu |
| **N · nápady po V1** | Čo by plugin posunulo **ako celok** (pre dielňu, ponuku, výrobu, rýchlosť práce)? | to, čo už je v zozname známych (§5) |
| **U · UI/UX drobnosti** | Drobnosti a doplnky, ktoré prostredie **sprofesionalizujú, spríjemnia alebo skrátia prácu**. | veľké redizajny (tie patria do N) |

**Princípy, ktoré audit nespochybňuje** (V1_VIZIA §2, [../../../STANDARD.md](../../../STANDARD.md)): korpusy generuje Ruby (nie DC), regenerate pattern,
mm Float, dátový slovník NOXUN, výrobné čísla sa nemenia bez dôkazu. **Trvalé UI pravidlo:** vertikálny priestor panela je vzácny.

## 3 · Scenáre rozšírenia (os K a D)

Pre každý scenár vystopuj, **koľko súborov a miest treba zmeniť** a **čo je na tom zbytočné** (duplicitné registre, rovnaká logika na 2+ miestach,
chýbajúci jeden zdroj pravdy). Návrh riešenia = položka. Refaktor bez scenára sa nezapisuje.

| # | Scenár (z plánu po V1) | Východiskový fakt |
|---|---|---|
| **S1** | **nový typ skrinky** — horná rohová, vysoká/potravinová veža | posledný nový typ `corner_blind` (blok K3, 28.9.) sa dotkol **22 súborov** (6 core, 16 UI, z toho 10 JS súborov, 32 riadkov JS: registre `CAB_TYPES`, `INSERT_TYPES`, `NX_TYPE_LABEL`, `templateType`, `TYPE_LIMITS`…) |
| **S2** | **zdieľané knižnice medzi PC** (D-48 — prvá funkcia po V1): katalóg materiálov, kovanie, šablóny, pravidlá, nastavenia na G-Disku | súbory v `%APPDATA%\NOXUN\Engine\`, `core/json_file_store.rb`; súvisí R-08, R-11, R-35, R-37 v registri |
| **S3** | **nový zásuvkový systém / značka kovania** (Antaro, StrongBox, TANDEM; pomerový člen setu D-109) | `core/hardware_sets.rb` má **6 605 riadkov**, `hardware_rules.rb` 2 633, `hardware_catalog.rb` 2 343 |
| **S4** | **nový výstup** — výkresy, etikety, CNC, DOCX ponuka | jadro výstupov `ui/production_core.rb` (**3 805 riadkov**) žije v UI vrstve (známe R-15) |
| **S5** | **nová sekcia Štúdia / nový stĺpec kusovníka** | `ui/studio_dialog.rb` 1 804, `ui/panel/payloads.rb` 3 320, `ui/js/proj_materials.js` 4 122, `studio.html` 1 346 (inline štýly) |
| **S6** | **nový agent dostane dávku** a číta povinné dokumenty podľa tabuľky v [../../../../CLAUDE.md](../../../../CLAUDE.md) | pozri §4 — napr. UI dávka = `docs/UI_DIZAJN.md` (117 kB) + `docs/architecture/ui-lifecycle.md` (**529 kB**) |

## 4 · Fakty (merané 1.10.2026 na `4da1c3b5`)

**Kód:** Ruby `core/` 71 súborov · 59 760 riadkov · `ui/` 24 súborov · 24 841 · `modules/` 946. JS/HTML/CSS v `ui/` ~44 900 riadkov.
Najväčšie Ruby: `hardware_sets.rb` 6 605 · `cabinet_builder.rb` 4 459 · `production_core.rb` 3 805 · `payloads.rb` 3 320 · `ghost_tool.rb` 2 886 ·
`hardware_rules.rb` 2 633 · `materials_dialog.rb` 2 359 · `hardware_catalog.rb` 2 343 · `construction.rb` 2 226 · `materials_decor.rb` 2 177 ·
`validation.rb` 1 921 · `studio_dialog.rb` 1 804 · `bom.rb` 1 800. Najväčšie JS: `proj_materials.js` 4 122 · `form.js` 3 249 · `hardware.js` 2 587 ·
`panel.css` 2 562 · `budget.js` 2 539 · `hw_sets.js` 2 536 · `studio.js` 2 212. Testy: 229 súborov `tests/pure`, 146 `tests/js`.

**Dokumenty (kB):** `docs/architecture/ui-lifecycle.md` **529** · `hardware.md` 204 · `construction.md` 170 · `outputs.md` 160 · `materials.md` 70 ·
`model-a-identita.md` 65 · `appliances.md` 46 · `SYSTEM/STANDARD.md` 170 · `docs/UI_DIZAJN.md` 117 · `SYSTEM/PLAN.md` 111 · `AUDIT_REGISTER.md` 62 ·
`POJMY.md` 44 · `WORKFLOW.md` 27 · `CLAUDE.md` 25 · skilly 4–12 kB.

## 5 · Známe veci — NEOPAKOVAŤ

Pred písaním si prečítaj tieto zoznamy. Čo v nich je, **nezapisuj ako novú položku**; ak máš k známej veci **nový fakt alebo lepšie riešenie**, daj ho do
sekcie „Doplnky k známym" s jej číslom (R-xx, D-xxx).

- [../../../PLAN.md](../../../PLAN.md) — sekcia **„Po V1 — zásobník"** (nápady a odložené funkcie),
- [../../../AUDIT_REGISTER.md](../../../AUDIT_REGISTER.md) — sekcia **„Stav po previerke 29.9.2026"** (verdikty otvorených R-čísel; plné znenia nižšie v súbore),
- [../../../DOGFOODING.md](../../../DOGFOODING.md) — otvorené postrehy D-xxx,
- [../../ARCHIWOOD_INSPIRACIA.md](../../ARCHIWOOD_INSPIRACIA.md) — už spracované koncepty iného pluginu (len pre os N a U).

## 6 · Formát výstupu (povinný, slovensky)

Hlavička: `# Krížový audit V1 — <karta A#> · <nástroj a model>` + jedna veta, čo si reálne prečítal (rozsah).
Potom sekcie podľa osí tvojej karty. **Limity:** hlavná os najviac **15** položiek, vedľajšia os najviac **5** — radšej menej a s dôkazom.
Poradie v sekcii = od najväčšieho prínosu. Každá položka:

```
### <PREFIX>-<nn> · <K|D|N|U> · <krátky názov>
- **Čo:** 1–3 vety funkčne (čo je zle / čo navrhuješ a aký to má dopad pre používateľa alebo ďalší vývoj).
- **Dôkaz:** súbor:riadok · screenshot · URL (bez dôkazu položka neplatí).
- **Scenár:** S1–S6 (pri K a D povinné) · pri N a U „—".
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V|S|N · V|S|N · áno|nie
- **Návrh zaradenia:** HARDENING | PO V1 | VYRADIŤ? — jedna veta prečo (kritériá HARDENING v ROZHODNUTIA).
- **Overenie nezmeneného výstupu:** (len pri refaktore K/D) aký test/golden to preukáže.
```

Na konci: sekcia **„Doplnky k známym"** (číslo + nový fakt) a sekcia **„Čo som nestihol / neistoty"** (2–5 riadkov).
**Repo len čítaš — nič nemeníš, necommituješ, nevytváraš súbory v repe.**

## 7 · Karty rolí

**Screenshoty** (os U; statické, svetlá téma, vykreslené Chrome zo skutočných dát pluginu — bez modálov a hoveru; ukážková kuchyňa 7 skriniek):
`_dev/v1audit_shots/` (absolútne `C:\APP DEV\RUBY\ENGINE\.claude\worktrees\orch-v1audit\_dev\v1audit_shots\`).
`00_model.png` model · `inspector_00_bez_vyberu` · `inspector_01_korpus` · `inspector_02_{zony,cela,kovanie}` · `studio_01_bom` … `studio_14_about`
(poradie navigácie: Kusovník, Kontrola, Nákup kovania, Rozpočet, Cenová ponuka, Nárezový plán, Materiály, Kovanie, Spotrebiče, Pravidlá, Šablóny,
Dodávateľ/Demos, Nastavenia rozpočtu, O plugine). Každý má aj `_long` variant (celá výška stránky).
*(Doplnok po review PR #432: cesta vyššie bola dočasná. Dôkazné screenshoty v bežnej výške sú trvalo v gite v [screenshoty/](screenshoty/)
(v0.17.0, ukážková kuchyňa 7 skriniek) — navyše tých päť `_long` variantov, ktoré audit A5 cituje ako dôkaz (Kusovník, Korpus, Rozpočet, Materiály,
Pravidlá); ostatné `_long` varianty nikto necituje a ostali len lokálne. Opakovateľný generátor fotiek z dát pluginu je dávka **H2** bloku 9.)*

*Mená nástrojov a modelov v tomto priečinku (tabuľka nižšie, hlavičky `CROSS_AUDIT_A*`) sú **záznam pôvodu** — kto 1.10.2026 ktorý výstup vytvoril.
Nie sú obsadením rolí; to platí výhradne v tabuľke „Obsadenie rolí" v [../../../WORKFLOW.md](../../../WORKFLOW.md).*

| Karta | Nástroj | Prefix | Hlavná os (●●) | Vedľajšia os (●) |
|---|---|---|---|---|
| **A1** | Codex `gpt-6-astra` | `CX` | **K** — scenáre S1–S5 | **N** |
| **A2** | Grok `grok-4.7` | `GR` | **K** — scenáre S1–S5 (nezávislý druhý hlas) **a N** | **U** (z kódu UI) |
| **A3** | Codex `gpt-5.6-sol` | `CS` | **D** — dokumenty, pravidlá, skilly, agenti | **U** — nekonzistencie JS/CSS/HTML voči `docs/UI_DIZAJN.md` |
| **A4** | Claude Opus — „nový agent" | `CN` | **D** — test zaúčania S6 | — |
| **A5** | Claude Opus — „stolár + UX" | `CU` | **U** — nad screenshotmi | **N** — z pohľadu dielne |
| **A6** | Claude Sonnet rešeršér | `RT` | **N** a **U** — čo majú nábytkárske CAD/SketchUp riešenia | — |
| **A7** | Claude Sonnet rešeršér | `RA` | **K** — novinky SketchUp Ruby API 2024–2026, ktoré zjednodušia náš kód | — |

**A1 / A2 (os K):** pre S1–S5 vystopuj cestu zmeny (Grep podľa existujúceho precedensu, napr. `corner_blind` pre S1). Hľadaj: registre a zoznamy
duplikované medzi Ruby a JS · logiku, ktorá žije vo vrstve, kam nepatrí · obrie súbory, ktoré sa dajú rozdeliť **bez zmeny správania** a kde ten rez
prinesie úsporu v scenári · chýbajúce testy na švoch, ktoré scenár prekročí. Ku každej K položke navrhni **rez** (čo kam) a **dôkaz nezmeneného
výstupu**. A2 navyše os **N** v plnom rozsahu (15).

**A3 (os D):** posúď všetko, čo agent číta: `CLAUDE.md`, `SYSTEM/*.md`, `docs/*.md`, `docs/architecture/*.md`, `.claude/skills/*`, `.claude/agents/*`.
Hľadaj: čo je **zastarané** (popisuje stav, ktorý už neplatí), **duplicitné** (to isté pravidlo na 2+ miestach), **protirečivé**, **príliš veľké na účel**
(napr. prečo má `ui-lifecycle.md` 529 kB — história vs. aktuálny stav), čo sa dá **archivovať** a ako rozdeliť, aby agent čítal len potrebné.
Rešpektuj guard testy (`tests/pure/test_*` nad dokumentmi) — návrh ich musí zachovať alebo povedať, ako ich upraviť.

**A4 (test zaúčania S6):** si nový agent bez kontextu. Dostal si dve vymyslené dávky: **T1** „pridaj do Kusovníka v Štúdiu stĺpec Hmotnosť dielca"
a **T2** „pridaj nový typ skrinky horná rohová". Pre každú **postupuj presne podľa tabuľky povinného čítania v `CLAUDE.md`** a zapisuj: ktoré
dokumenty a koľko kB si musel prečítať · čo si po prečítaní stále nevedel a musel hľadať v kóde · čo bolo zastarané, duplicitné alebo protirečivé ·
kde si sa stratil. **Kód nepíšeš** — len meriaš cestu. Výstup: položky D + tabuľka nameraných kB na T1 a T2.

**A5 (os U + N):** si skúsený stolár, ktorý robí ponuky a výrobu, a zároveň UX dizajnér. Prejdi **všetky screenshoty** a k nim `docs/UI_DIZAJN.md`
(stačia úvodné princípy a tokeny). Hľadaj: nekonzistencie (pomenovania, diakritika, veľké/malé písmená, jednotky, ikony) · čo je pre stolára
nezrozumiteľné · zbytočné kliky a miesto · chýbajúce prázdne a chybové stavy · drobnosti, ktoré z nástroja urobia „profi" softvér · skratky pre
najčastejšie činnosti. Rešpektuj pravidlo vertikálneho priestoru. Os N: čo by si ako stolár chcel po V1.

**A6 (rešerš trh):** porovnaj s nábytkárskymi riešeniami (napr. Cabinet Vision, Mozaik, Polyboard, KD Max, SketchList 3D, imos, Pytha, SWOOD,
TopSolid Wood, Microvellum) a SketchUp pluginmi (OpenCutList, CabMaker, ArchiWood, Profile Builder…). Hľadaj **funkcie a UX vzory relevantné
pre malú dielňu** (ponuka → výroba), nie enterprise ERP. Čo máme, zistíš z `V1_VIZIA.md` a `STAV.md`. Každá položka s URL a dátumom overenia.

**A7 (rešerš SketchUp API):** release notes Ruby API **2024.0 → 2026.x** (oficiálne ruby.sketchup.com, forum.sketchup.com). Pre každú novinku, ktorá by
**zjednodušila alebo spevnila náš kód** (overlays, Tool API, observery, HtmlDialog, atribúty, výkon), nájdi Grepom miesto v našom kóde, ktoré by
nahradila, a uveď minimálnu verziu SketchUpu (Michal aj Lucia majú SketchUp 2026).
