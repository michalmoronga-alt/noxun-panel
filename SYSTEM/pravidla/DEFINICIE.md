# Definície pravidiel — jediný domov

> Každá definícia tu má jediné znenie. Ostatné súbory na ňu odkazujú (`DEFINICIE.md § D1` …) a znenie neopakujú — stráži guard
> `tests/pure/test_definicie.rb`. Zmena definície = zmena len tohto súboru (+ KRONIKA). Kvótové prahy: skill `usage`. Review kolá,
> delta a pravidlo 3 kôl: skill `codex-po-pr`.

<a id="d1"></a>

## D1 · Výrobná/cenová dávka

Dávka, ktorá mení **rozmery alebo počty dielov, hrany, kusovník, VEPO, nákupné zoznamy, kovanie alebo ceny**.

- **Áno:** zmena vzorca, rozmeru, počtu, hrany · zmena zoskupenia riadkov kusovníka (`row_key`) alebo obsahu či stĺpcov exportu (VEPO,
  CSV/XLSX kusovníka, nákup, ponuka) · zmena ceny, sadzby alebo **čísla, podľa ktorého sa v okne objednáva či cenotvorí** (množstvo,
  počet platní, cena položky) — aj keď sa výpočet nemení a mení sa len to, čo okno ukazuje, a aj v novom čítacom stĺpci · zmena seedu
  katalógu (`SEED_VERSION`, `SEED_SET_VERSION`), ktorá mení kovanie, ABS alebo ceny.
- **Nie:** nový **popisný** čítací stĺpec alebo popis v okne, ktorého hodnoty sa nepoužívajú na výrobu, objednávanie ani cenu, bez zmeny
  `row_key`, zoskupenia a exportov (precedens `rows_with_roles`) · preklad nadpisov a popiskov bez zmeny čísel a CSV · farba, ikona, rozloženie.

<a id="d2"></a>

## D2 · Audit-povinná dávka

Dávka, ktorá mení **dátový kontrakt, schému, migráciu, observer/undo lifecycle** alebo pridáva **nový modul**. Rozhoduje obsah zásahu, nie
žáner dávky (aj „fix" observera je audit-povinný). **Zmena schémy = každé zvýšenie `CONFIG_SCHEMA`, BuildPlan `SCHEMA` alebo STD** (a všetkých schém so stĺpcom „Schéma" = áno
v [STANDARD §13](../STANDARD.md)).
Nová plocha SketchUp API sama osebe audit-povinná nie je — spúšťa outside-in rešerš (skill `antigravity-outside-in`).

Pre audit-povinnú dávku je **pred implementáciou povinný audit návrhu** (skill `codex-audit`); pred odoslaním orchestrátor overí kľúčové
tvrdenia package krátkou sondou na kóde bez zápisu do modelu a výsledok zapíše do package (skill `codex-audit`, krok 0). Keď Codex nie je
k dispozícii, platia pravidlá skillu `usage` (sekcia „Prahy a reakcie"). Ostatné dávky audit návrhu nevyžadujú.

<a id="d3"></a>

## D3 · Triedy dávok

Triedu určí orchestrátor pri zadaní; platí **najvyššia** trieda, do ktorej dávka spadá (**Ť > S > Ľ**; napr. presne zadaná migrácia schémy
alebo oprava výrobnej ceny je Ť, aj keď zadanie nevyžaduje vlastné rozhodovanie). **D je užší prípad Ľ:** dávka, ktorá spĺňa definíciu D
a nespĺňa kritérium S ani Ť, je D (nie Ľ).

- **D drobnosť:** oprava komentára, vety alebo textu bez zmeny správania a bez zmeny čísel. Profil ľahký · STAV sa neprepisuje (len záznam
  v KRONIKE), aj keď sa kvôli zmene súboru pluginu zvyšuje patch verzia · review len kolo 1: kolo 1 je plné GH review; nálezy P2/P3 →
  oprava + reply a kontrolu opravy urobí orchestrátor sám (bez delta subagenta a bez ďalšieho GH kola); P0/P1 → eskalácia nižšie.
- **Ľ ľahká:** docs, texty, preklady, ikony, rozloženie, mechanické presuny, testy, presné zadanie bez vlastného rozhodovania.
- **S stredná:** bežná kódová dávka bez zmeny kontraktu (nová logika, bugfix mimo výroby, nový ovládací prvok UI) do ~300 riadkov kódu pluginu.
- **Ť ťažká:** audit-povinná ([D2](#d2)), výrobná/cenová ([D1](#d1)), nad 300 riadkov kódu pluginu, oprava P0/P1.
- **Riadky kódu pluginu** sa vždy počítajú **bez testov a dokumentácie**. Hranica pri zadaní je odhad; implementátor Ľ/S pred návratom zmeria
  skutočný diff a keď je nad 300, ohlási to — dávka sa reklasifikuje na Ť.
- **Eskalácia:** nález P0 alebo P1, alebo oprava meniaca koncept v dávke D/Ľ/S → opravu robí profil Ť s novým zadaním (nie pokračovanie).
  Pokračovaním sa opravujú len P2/P3, ktoré nemenia koncept.
- Profil (typ agenta, model) ku každej triede určuje tabuľka obsadenia — tu sa model nepíše.

<a id="d4"></a>

## D4 · Kedy je povinná predrecenzia

Slepá predrecenzia pred PR (skill `predrecenzia`) je **povinná** pri dávke:

- audit-povinnej ([D2](#d2)) · výrobnej/cenovej ([D1](#d1)) · nad 300 riadkov kódu pluginu ([D3](#d3)) · s novým ovládacím prvkom v UI
  ([D5](#d5)) · každej dávke náhradného implementátora (kód iného providera vždy kontroluje aj recenzent Claude).
- Pri dávke **Ť**, pri ktorej je predrecenzia povinná podľa tohto zoznamu, sa pridá druhý slepý recenzent **iného providera než implementátor**.
- **Odporúčaná** (nie povinná): nová interakcia v UI bez nového ovládacieho prvku (klávesnica, fokus, prepnutie dokumentu, prekreslenie).
- **Nie:** dokumentačná dávka (docs-only), dávka, ktorá mení len verziu, a trieda D — **okrem dávky náhradného implementátora** (tá má
  predrecenziu vždy).
- Slepý recenzent dostane len zadanie a `git diff main...HEAD`; jeho P1/P2 sa opravia ešte pred PR a výsledok ide do PR popisu (sekcia
  „Predrecenzia"). Predrecenzia nenahrádza audit návrhu (`codex-audit`) ani review PR (`codex-po-pr`).

<a id="d5"></a>

## D5 · Nový ovládací prvok v UI

- **Áno:** nové tlačidlo, prepínač, pole, rozbaľovačka alebo položka menu, ktorá niečo **spúšťa alebo zapisuje** (model, súbor, nastavenia, katalóg).
- **Nie:** ďalšia voľba v existujúcom zozname s rovnakým správaním ako susedné (napr. ďalší stĺpec v menu „Stĺpce") · presun existujúceho
  tlačidla alebo jeho zmena na ikonu bez zmeny akcie.

<a id="d6"></a>

## D6 · Kedy je in-SU test bránou mergu

- **Spúšťače:** dávka mení **buildery, observery, undo a operácie, geometriu alebo akcie panela zapisujúce do modelu** (Ruby strana). Headless
  sada geometriu ani undo neoverí.
- **Finálna hlava:** nový beh netreba, keď commity po poslednom behu nemenia Ruby kód spúšťačov — len JS (kryjú ho JS sady), texty,
  dokumentáciu alebo testy; PR uvedie, na ktorej hlave in-SU bežal a čo sa zmenilo potom. Pri akejkoľvek zmene Ruby spúšťača beh znova.
- Ako sa runner spúšťa (`-CloseWhenDone`, zámok, ENGINEtests): [CLAUDE.md](../../CLAUDE.md), sekcia Testovanie.
