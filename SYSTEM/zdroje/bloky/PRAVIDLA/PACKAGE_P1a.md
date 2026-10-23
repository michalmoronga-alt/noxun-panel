# Package P1a — definície na jednom mieste (blok PRAVIDLA, 23.10.2026)

> **Trieda Ť** (mení definície, podľa ktorých sa rozhoduje o bránach každej dávky; dotkne sa ~12 súborov pravidiel) · profil `implementator` ·
> **len pravidlá a testy, kód pluginu sa nemení** (VERSION ani `?v=` bez zmeny). Vstupy: [SUPIS_DEFINICII.md](SUPIS_DEFINICII.md) (kde je ktorá
> kópia + rozhodnutie Michala k R1–R10) · [NAVRH_STRUKTURY.md](NAVRH_STRUKTURY.md) § 3 (cieľové miesta) a § 9 (rozhodnutia) ·
> [ROLY.md](ROLY.md). Čísla riadkov v súpise platia k `main` a9e8c79d — pred prácou ich over Grepom.

## 0 · Sonda pred auditom (23.10.2026, hlava 0338a888)

| Tvrdenie package | Ako overené | Výsledok |
|---|---|---|
| `SYSTEM/pravidla/` zatiaľ neexistuje | `ls SYSTEM/pravidla` | neexistuje — dávka ho zakladá |
| PLAN.md:110 má užšie spúšťače in-SU | `sed -n 110p SYSTEM/PLAN.md` | „In-SU testy povinné pri builderoch/observeroch" — potvrdené (R2) |
| STANDARD.md:1785-1787 nesie parafrázu schémy a seedu | `sed -n 1785,1787p` | potvrdené (zmena schémy + seed „spravidla výrobná/cenová") |
| `codex-audit` a `usage` nesú R1 a R8 | grep „API plocha", „85 %" | nájdené (codex-audit:9, usage:44) |
| `test_docs_navigacia.rb` má `NX_SYSTEM_LINE_FILES` | grep | riadok 33 |
| blok PRAVIDLA je v PLAN.md | grep „PRAVIDLA" | **nie je** — doplní ho úvodné PR bloku (nie P1a) |

## 1 · Cieľ (čo sa zmení pre agentov)

Každá z definícií D1–D6 má **jediné znenie** v novom súbore `SYSTEM/pravidla/DEFINICIE.md`; D7 (kvótové prahy) má jediný domov v skille
`usage`, D8 (review kolá, delta, pravidlo 3 kôl) v skille `codex-po-pr`. Všetky ostatné miesta (CLAUDE.md, WORKFLOW.md, typy agentov,
skilly, PLAN, STANDARD) znenie **neopakujú** — odkážu krátko („výrobná/cenová dávka — [DEFINICIE § D1]"). Rozpory R1–R10 sa pri tom vyriešia
podľa rozhodnutia Michala 23.10. Nový guard test stráži, že sa kópie nevrátia.

**Mimo rozsahu (neskoršie dávky):** prepis CLAUDE.md na jadro AGENTS.md (P1b) · súbory rolí a generované typy agentov (P2) · `.claude/rules/`
(P3) · hooky (P4). V P1a sa CLAUDE.md len skráti o nahradené definície — štruktúra ostáva.

## 2 · Cieľové znenie `SYSTEM/pravidla/DEFINICIE.md`

Text nižšie je **záväzný obsah** (implementátor smie upraviť len formu — nadpisy, odrážky, odkazy — nie význam). Žiadne dátumy, čísla PR ani
história v texte definícií (história ide do KRONIKY). Ku každej definícii kotva `D1`…`D6` v nadpise.

```markdown
# Definície pravidiel — jediný domov

> Každá definícia tu má jediné znenie. Ostatné súbory na ňu odkazujú (`DEFINICIE.md § D1` …) a znenie neopakujú — stráži guard
> `tests/pure/test_definicie.rb`. Zmena definície = zmena len tohto súboru (+ KRONIKA). Kvótové prahy: skill `usage`. Review kolá,
> delta a pravidlo 3 kôl: skill `codex-po-pr`.

## D1 · Výrobná/cenová dávka
Dávka, ktorá mení **rozmery alebo počty dielov, hrany, kusovník, VEPO, nákupné zoznamy, kovanie alebo ceny**.
- **Áno:** zmena vzorca, rozmeru, počtu, hrany · zmena zoskupenia riadkov kusovníka (`row_key`) alebo obsahu či stĺpcov exportu (VEPO,
  CSV/XLSX kusovníka, nákup, ponuka) · zmena ceny, sadzby alebo **čísla, podľa ktorého sa v okne objednáva či cenotvorí** (množstvo,
  počet platní, cena položky) — aj keď sa výpočet nemení a mení sa len to, čo okno ukazuje, a aj v novom čítacom stĺpci · zmena seedu
  katalógu (`SEED_VERSION`, `SEED_SET_VERSION`), ktorá mení kovanie, ABS alebo ceny.
- **Nie:** nový **popisný** čítací stĺpec alebo popis v okne, ktorého hodnoty sa nepoužívajú na výrobu, objednávanie ani cenu, bez zmeny
  `row_key`, zoskupenia a exportov (precedens `rows_with_roles`) · preklad nadpisov a popiskov bez zmeny čísel a CSV · farba, ikona, rozloženie.

## D2 · Audit-povinná dávka
Dávka, ktorá mení **dátový kontrakt, schému, migráciu, observer/undo lifecycle** alebo pridáva **nový modul**. Rozhoduje obsah zásahu, nie
žáner dávky (aj „fix" observera je audit-povinný). **Zmena schémy = každé zvýšenie `CONFIG_SCHEMA`, BuildPlan `SCHEMA` alebo STD.**
Nová plocha SketchUp API sama osebe audit-povinná nie je — spúšťa outside-in rešerš (skill `antigravity-outside-in`).

## D3 · Triedy dávok
Triedu určí orchestrátor pri zadaní; platí **najvyššia** trieda, do ktorej dávka spadá (**Ť > S > Ľ > D**).
- **D drobnosť:** oprava komentára, vety alebo textu bez zmeny správania a bez zmeny čísel. Profil ľahký · STAV sa neprepisuje (len záznam
  v KRONIKE), aj keď sa kvôli zmene súboru pluginu zvyšuje patch verzia · review len kolo 1.
- **Ľ ľahká:** docs, texty, preklady, ikony, rozloženie, mechanické presuny, testy, presné zadanie bez vlastného rozhodovania.
- **S stredná:** bežná kódová dávka bez zmeny kontraktu (nová logika, bugfix mimo výroby, nový ovládací prvok UI) do ~300 riadkov kódu pluginu.
- **Ť ťažká:** audit-povinná (D2), výrobná/cenová (D1), nad 300 riadkov kódu pluginu, oprava P0/P1.
- **Riadky kódu pluginu** sa vždy počítajú **bez testov a dokumentácie**. Hranica pri zadaní je odhad; implementátor Ľ/S pred návratom zmeria
  skutočný diff a keď je nad 300, ohlási to — dávka sa reklasifikuje na Ť.
- **Eskalácia:** nález P0 alebo P1, alebo oprava meniaca koncept v dávke Ľ/S → opravu robí profil Ť s novým zadaním (nie pokračovanie).
  Pokračovaním sa opravujú len P2/P3, ktoré nemenia koncept.
- Profil (typ agenta, model) ku každej triede určuje tabuľka obsadenia — tu sa model nepíše.

## D4 · Kedy je povinná predrecenzia
Slepá predrecenzia pred PR (skill `predrecenzia`) je **povinná** pri dávke:
- audit-povinnej (D2) · výrobnej/cenovej (D1) · nad 300 riadkov kódu pluginu (D3) · s novým ovládacím prvkom v UI (D5) ·
  každej dávke náhradného implementátora (kód iného providera vždy kontroluje aj recenzent Claude).
- Pri dávke **Ť** sa pridá druhý slepý recenzent **iného providera než implementátor**.
- **Odporúčaná** (nie povinná): nová interakcia v UI bez nového ovládacieho prvku (klávesnica, fokus, prepnutie dokumentu).
- **Nie:** dokumentačná dávka (docs-only) a trieda D.

## D5 · Nový ovládací prvok v UI
- **Áno:** nové tlačidlo, prepínač, pole, rozbaľovačka alebo položka menu, ktorá niečo **spúšťa alebo zapisuje** (model, súbor, nastavenia, katalóg).
- **Nie:** ďalšia voľba v existujúcom zozname s rovnakým správaním ako susedné (napr. ďalší stĺpec v menu „Stĺpce") · presun existujúceho
  tlačidla alebo jeho zmena na ikonu bez zmeny akcie.

## D6 · Kedy je in-SU test bránou mergu
- **Spúšťače:** dávka mení **buildery, observery, undo a operácie, geometriu alebo akcie panela zapisujúce do modelu** (Ruby strana). Headless
  sada geometriu ani undo neoverí.
- **Finálna hlava:** nový beh netreba, keď commity po poslednom behu nemenia Ruby kód spúšťačov — len JS (kryjú ho JS sady), texty,
  dokumentáciu alebo testy; PR uvedie, na ktorej hlave in-SU bežal a čo sa zmenilo potom. Pri akejkoľvek zmene Ruby spúšťača beh znova.
- Ako sa runner spúšťa (`-CloseWhenDone`, zámok, ENGINEtests): CLAUDE.md, sekcia Testovanie.
```

## 3 · D7 a D8 — jediný domov v skille

- **D7 kvótové prahy → skill `usage`** (už má plnú tabuľku). V skille zjednotiť: **Codex weekly zostatok pod 10 %** (oprava R8 — žiadne
  „> 85 %") · **Claude session nad 80 %** → nový implementačný subagent sa nespúšťa, reset do 60 min → čaká sa · **počkať, nie náhradník**
  pri resete do 60 min · keď Codex nie je (kvóta alebo CLI): **bežná dávka → náhradná brána, audit-povinná / výrobná/cenová / P0-P1 →
  rozhodne Michal** (oprava R3 v `codex-audit`:11) · predrecenzia: keď Claude weekly nestačí, náhradníkom je Codex (R4 — ponechať, ako
  riadok tabuľky v skille). Prahy shadow ostávajú vo WORKFLOW § 2 (iné pravidlo). CLAUDE.md § Kvóty: prahy nahradí odkaz na skill
  (ostane 1–2 vety, kedy sa skill volá).
- **D8 review kolá → skill `codex-po-pr`** (už má plnú kópiu). Znenie z CLAUDE.md (delta-verifikácia, opravy z review, pravidlo 3 kôl a/b)
  sa zlúči do skillu — pri rozdiele platí CLAUDE.md, okrem **R9** (P2/P3 z delty overí orchestrátor sám — ponechať) a „ďalší nezávislý
  hlas pri cenových miestach" (PO:39-41 — ponechať). Eskalácia P0/P1 podľa D3 (R7). CLAUDE.md § Git workflow: 2–3 vety + odkaz.

## 4 · Nahradenie kópií (podľa súpisu)

| Súbor | Čo urobiť |
|---|---|
| `CLAUDE.md` | D1, D2, D3, D4, D5, D6 nahradiť odkazom (jedna veta + `[DEFINICIE § Dx]`); D7 a D8 skrátiť na odkaz na skill. Do tabuľky „Povinné čítanie" pridať riadok platný pre **každú** prácu: `SYSTEM/pravidla/DEFINICIE.md`. Odkazy „vyššie/nižšie" (C:75, 85) prepísať. |
| `SYSTEM/WORKFLOW.md` | § 2 Matica (W:90-110) — tabuľka tried ostáva len ako mapovanie trieda → profil, definície tried odkazom · § 6 Brány a § 7 Hranice — stĺpec „Kde je pravidlo" na DEFINICIE / skill · hlavička (W:1-9): záväzné znenie je v DEFINICIE.md, CLAUDE.md a skilloch |
| `.claude/agents/implementator*.md` (3) | krok 1: prečítať aj `SYSTEM/pravidla/DEFINICIE.md` · krok 6 (predrecenzia): štyri kritériá nahradiť odkazom na D4 · eskalácia (LAH/STR:44-46): podľa D3, bez mena modelu (R7) · `description` skrátiť tam, kde opakuje definíciu |
| `.claude/agents/slepy-recenzent.md` | „Najprv čítaj" doplniť `DEFINICIE.md` |
| `.claude/skills/predrecenzia` | tabuľka kedy (PRE:15-24) → odkaz na D4 (R5 sa presúva do D4) · brána kvóty a náhrada (PRE:33-34, 45-49) → odkaz na skill `usage` |
| `.claude/skills/codex-audit` | kedy je audit povinný (AUD:8-9) → odkaz na D2; „nová SketchUp API plocha" z kritérií auditu vypustiť (R1) · AUD:11 podľa § 3 (R3) |
| `.claude/skills/codex-po-pr` | zlúčiť D8 podľa § 3; odkazy na definície D1/D2/D4 |
| `.claude/skills/usage` | zjednotiť D7 podľa § 3 (R8) |
| `SYSTEM/PLAN.md:110` | „In-SU povinné pri builderoch/observeroch" → odkaz na D6 (R2) |
| `SYSTEM/STANDARD.md:1785-1787` | parafráza → odkaz na D1 a D2 (príklad seedu je teraz v D1) |
| `SYSTEM/README.md` | mapa autorít: nový riadok `pravidla/DEFINICIE.md` = definície brán a tried |

Kde ostáva veta pre plynulosť textu, smie byť len **pomenovanie** definície bez obsahu („výrobná/cenová dávka (D1)"), nie jej výpočet.

## 5 · Guard test `tests/pure/test_definicie.rb` (G3)

- `SYSTEM/pravidla/DEFINICIE.md` existuje a má nadpisy `D1`–`D6`.
- **Podpisové frázy** (zoznam v teste, z každej definície 2–3 charakteristické úseky, napr. „čísla, podľa ktorého sa v okne objednáva",
  „každé zvýšenie `CONFIG_SCHEMA`", „platí najvyššia trieda", „ďalšia voľba v existujúcom zozname", „nemenia Ruby kód spúšťačov") sa smú
  vyskytnúť **len** v DEFINICIE.md — test prehľadá `CLAUDE.md`, `AGENTS.md`, `SYSTEM/WORKFLOW.md`, `SYSTEM/PLAN.md`, `SYSTEM/README.md`,
  `.claude/agents/*.md`, `.claude/skills/*/SKILL.md`. Archív, KRONIKA a `SYSTEM/zdroje/` sa neprehľadávajú (história).
- Porovnanie bez ohľadu na veľkosť písmen a zalomenie riadkov (normalizovať biele znaky).
- Test vlastného správania: frázu vloženú do dočasnej kópie CLAUDE.md test chytí (pozitívny aj negatívny prípad).
- `DEFINICIE.md` pridať do `test_docs_navigacia.rb` (kontrola relatívnych odkazov + limit 400 znakov na riadok, `NX_SYSTEM_LINE_FILES`).

## 6 · Hotovo, keď

1. Headless sada + všetky JS sady zelené (každá zvlášť), nový guard zelený a test vlastného správania prejde.
2. Grep podpisových fráz mimo DEFINICIE.md = 0 (mimo archívu a zdrojov).
3. **Overenie „nič sa nestratilo"** (akceptačný krok, robí slepý recenzent v režime overenia checklistu): každá veta definícií D1–D6 z dnešného
   CLAUDE.md má zodpovedajúce znenie v DEFINICIE.md alebo je vedome zmenená podľa R1–R10; každé R1–R10 je premietnuté.
4. Kódová dávka sa nemení: VERSION, `?v=`, STAV bez zmeny. KRONIKA: odsek navrch. PLAN: riadok dávky v bloku PRAVIDLA (ak blok v PLAN je).
5. PR popis: čo sa mení pre agentov (jedno miesto definícií, vyriešené rozpory s tabuľkou R1–R10) + ako testované.

## 7 · Brány tejto dávky

- Audit návrhu (skill `codex-audit`): dávka nie je audit-povinná podľa D2 (nemení dátový kontrakt pluginu). Orchestrátor napriek tomu pošle
  **§ 2 tohto package na úzky audit** (Codex `gpt-6.1-sol`, otázka: „je znenie D1–D6 úplné voči CLAUDE.md a jednoznačné?") — lacná poistka,
  lebo podľa týchto viet sa rozhoduje o každej dávke.
- Predrecenzia: podľa D4 nepovinná (docs a testy), ale **povinný akceptačný krok 3** (slepý recenzent).
- Review PR: plné kolo 1; P2/P3 → fix + delta.
