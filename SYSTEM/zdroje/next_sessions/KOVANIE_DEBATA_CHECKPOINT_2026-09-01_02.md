# KOVANIE — checkpoint USER debaty 2026-09-01 · 02

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01.md`.
> **Účel:** zachytiť rozhodnutia po prvom checkpointe a umožniť bezpečne pokračovať po kompresii kontextu.

---

## 1. D-109 — nohy a pomer príchytov sokla — ROZHODNUTÉ

- šírka skrinky `< 1000 mm` → **4 nohy / klzáky**,
- šírka skrinky `>= 1000 mm` → **6 nôh / klzákov**,
- pravidlo platí rovnako pre **AXILO aj 17 mm klzáky**,
- príchyt sokla = **1 ks na každé začaté 4 nohy**,
- pomer sa počíta **samostatne per skrinka**, nie súčtom cez susedné skrinky.

Príklad:
- 4 nohy → 1 príchyt,
- 6 nôh → 2 príchyty.

---

## 2. D-111 — výber setu nôh podľa výšky sokla — ROZHODNUTÉ

- systém má podľa nastavenej výšky sokla **automaticky zvoliť predvolený kompatibilný set nôh**,
- používateľ môže set na konkrétnej skrinke manuálne prepísať,
- aktuálne zvolený set má byť viditeľný **pri vložení skrinky aj následne v Inspectore korpusu pri sokli/nohách**,
- výber nemá byť schovaný iba v projektových predvoľbách.

---

## 3. D-110 — pridávanie položky do katalógu — ROZHODNUTÉ / ROZPRACOVANÉ

### 3.1 Vstupné cesty úplne navrchu formulára

Na začiatku formulára má byť blok na načítanie/identifikáciu položky. Minimálne dve cesty:

1. **Démos vyhľadávanie** — podľa kódu/názvu, následný výber výsledku a automatické predvyplnenie dostupných údajov.
2. **URL** — používateľ vloží URL a systém automaticky rozpozná, či ide o Démos alebo cudzí zdroj.

Nepoužívať povinný ručný prepínač `Démos / iné`, ak URL možno spoľahlivo rozpoznať podľa hostu.

### 3.2 Démos URL

Ak URL patrí Démosu:

- systém sa pokúsi automaticky načítať produktový detail,
- predvyplní dostupné údaje,
- uloží Démos väzbu,
- ak načítanie/parser zlyhá, používateľ musí mať vždy možnosť **pokračovať manuálnym vyplnením**.

Démos URL je špeciálna systémová väzba, nie iba obyčajný textový odkaz.

### 3.3 Cudzia URL

Ak URL nie je Démos:

- **žiadne automatické parsovanie údajov**,
- formulár sa vyplní ručne,
- cudzia URL sa **uloží k položke ako zdroj/odkaz** pre budúce dohľadanie a kontrolu.

### 3.4 UX princíp

Démos vyhľadávanie a URL nie sú dva oddelené režimy celého formulára. Sú to dve vstupné cesty do toho istého formulára. Po načítaní/predvyplnení musí používateľ údaje vidieť, skontrolovať a podľa pravidiel doplniť/upraviť.

---

## 4. ĎALŠÍ BOD

Pokračovať v **D-110 — poradie a klasifikácia polí formulára položky po vstupnom bloku URL/Démos**.

Treba postupne uzavrieť:
- ktoré polia systém načíta/predvyplní,
- ktoré používateľ klasifikuje ručne,
- poradie polí,
- výrobca / produktová rada / kategória / MJ / cena / poznámka,
- ako sa nová klasifikácia setov a kovania prejaví v katalógu položiek.
