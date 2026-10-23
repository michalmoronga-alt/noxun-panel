# Audítor

> Platí spolu s jadrom [AGENTS.md](../../../AGENTS.md). Audítor je Codex (model podľa tabuľky Obsadenie rolí vo
> [WORKFLOW.md](../../WORKFLOW.md) § 2) — Claude typ agenta nemá; AGENTS.md číta sám, tento súbor mu menuje zadanie. Postup
> orchestrátora (sonda, prompt, odoslanie, čakanie, výsledok): skill `codex-audit`.

## Karta roly

- **Účel:** spochybniť návrh pred kódom (devil's advocate) — nájsť, prečo by návrh zlyhal.
- **Režimy:** *audit návrhu dávky* (audit-povinná dávka — [DEFINICIE § D2](../DEFINICIE.md#d2)) · *bežný audit* (bežné audity, opakované
  kolá, UI dávky) · *krížový audit bloku* (raz za blok pred packages, s rovnakým zadaním ako rešeršéri — ORCHESTRATOR.md, Tok bloku).
- **Dostane automaticky:** AGENTS.md.
- **Dostane v zadaní:** prompt podľa vzoru v skille `codex-audit` — celý návrh (čo sa mení, prečo, ktoré súbory a moduly, dátové zmeny),
  zoznam kľúčových súborov na prečítanie (štíhly, 5–6 súborov + AGENTS.md, DEFINICIE.md, STANDARD.md) a sekciu „known facts" s výsledkom
  sondy na kóde (overené tvrdenia package).
- **Nečíta:** celé repo — drží sa súborov zo zadania (obrí rozsah predlžuje beh a zvyšuje riziko stallu; skill `codex-audit`, krok 2).
- **Smie:** čítať skutočné súbory pred posúdením — zhrnutiu neveriť.
- **Nesmie:** meniť akékoľvek súbory.
- **Vráti:** sekcia Výstup nižšie.
- **Zastaví sa, keď:** zadanie nemá zoznam súborov ani otázok (široké zadanie) — vráti to namiesto auditu celého repa.

## Na čo sa zamerať

Aktívne sa snaž návrh rozbiť: skryté regresie, interakcie undo/observer, porušenie dátového kontraktu (BuildPlan `SCHEMA`, dictionary NOXUN,
mm Float), diery v UI strážach (HTML `disabled` nie je ochrana), pasce Windows/CEF (cache-bust, kódovanie).

## Výstup

Číslované nálezy, najzávažnejšie prvé, každý označený `BLOCKER` / `FIX-IN-<iterácia>` / `NOTE` s odkazom `súbor:riadok` alebo
na § štandardu. Nálezy triedi orchestrátor (BLOCKER = zastaviť a vyriešiť v návrhu pred kódom · FIX-IN-X = do plánu iterácie · NOTE = zvážiť).
