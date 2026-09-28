# Blok 2 · Nárezový plán — vyhodnotenie krížového auditu (reconcile, 28.9.2026)

> Stav: **vyhodnotenie orchestrátora — len rozhodnutie o každom náleze a dávka, ktorá ho rieši.** Vstupy: [CROSS_AUDIT_CODEX_2026-09-28.md](CROSS_AUDIT_CODEX_2026-09-28.md)
> (`gpt-5.6-sol`, NOT SOUND — 5 BLOCKER · 6 FIX · 3 NOTE), [CROSS_AUDIT_GROK_2026-09-28.md](CROSS_AUDIT_GROK_2026-09-28.md) (`grok-4.7`, 2 BLOCKER · 4 FIX · 4 NOTE),
> auditovaný koncept [KONCEPT_NP_v1_2026-09-28.md](KONCEPT_NP_v1_2026-09-28.md) (surový vstup, nie zadanie), rešerš [RESERS_OUTSIDE_IN_2026-09-28.md](RESERS_OUTSIDE_IN_2026-09-28.md)
> a rozhodnutia Michala N6–N10 z toho istého večera ([ROZHODNUTIA_MICHALA_2026-09-28.md](ROZHODNUTIA_MICHALA_2026-09-28.md)). Sondu v SketchUpe nevyžadoval
> žiadny nález (ALREADY EXISTS ani SIMPLER NATIVE PATH na SketchUp API nie je).
> **Technické požiadavky tu nie sú:** tvar výsledku, vzorce, rozsahy, verzie dát a testy dostane **package dávky** v stĺpci „Rieši" a prejdú jej auditom
> návrhu (pravidlo štartu bloku; Codex review PR #416, P1).

## 1 · Codex (`gpt-5.6-sol`)

| # | Záv. | Nález (skrátene) | Verdikt | Rieši |
|---|---|---|---|---|
| C1 | BLOCKER | koncept nepočíta prídavok dupláku (N7) → podhodnotí počet platní | **berieme** | NP-1 (nastavenie NP-2) |
| C2 | BLOCKER | počet bez nezaradených dielcov, s chýbajúcim formátom alebo UNI nie je horná hranica | **berieme** — „horná hranica" len pri úplnom pláne so skutočným formátom | NP-1, texty NP-3 |
| C3 | BLOCKER | „bez exportnej brány" je bezpečné len vtedy, keď neistý plán nikdy nepríde do ceny | **berieme v upravenej forme** — materiál bez spoľahlivého plánu ostáva na dnešnom odhade a riadok povie prečo; či to stačí bez zastavenia exportu, rozhodne audit NP-4 | NP-4 |
| C4 | BLOCKER | nové nastavenia zahodí starší plugin pri uložení sadzieb | **berieme** — ochrana pred staršou verziou; priznaný limit pre plugin v0.15.x a starší na tom istom PC | NP-2 |
| C5 | BLOCKER | blok uzavrieť až po porovnaní s reálnou objednávkou VEPO (N5) | **neberieme — rozhodol Michal (N10)**: vhodná zákazka teraz nie je, porovnanie po V1; bezpečnosť drží konzervatívny plán a vypnutý prepínač cien | — |
| C6 | FIX | heuristiku formálne popísať a nevolať ju minimum | **berieme** | NP-1 |
| C7 | NOTE | vstup z kusovníka je správna cesta | **potvrdenie** | — |
| C8 | FIX | vstup rozdeliť na prijatie riadka, podobu pre VEPO a nákupné prírezy; neznámy smer neotáčať | **berieme** (s N8 sa neotáča nič) | NP-1 |
| C9 | FIX | jedna pravda o tom, či sa dielec zmestí, pre plán aj Kontrolu | **berieme** | NP-1 (funkcia), NP-2 (Kontrola) |
| C10 | FIX | porez a montáž dnes berú jeden súčet platní | **berieme** — montáž ostáva z odhadu (mockup O6) | NP-4 |
| C11 | NOTE | zvýšenie verzie dát rozpočtu je správna cesta pre prepínač | **berieme** | NP-4 |
| C12 | FIX | celé rozloženie v každom obnovení Štúdia zaťaží aj toho, kto sekciu neotvorí | **berieme** | NP-3 |
| C13 | NOTE | id sekcie `cut` nekoliduje s rozmerom do nárezu | **berieme** — id ostáva | NP-3 |
| C14 | FIX | precedensy: zoznam nezaradených, jasná politika otáčania a orezu | **berieme** (C2, N8) | NP-1, NP-3 |

## 2 · Grok (`grok-4.7`)

| # | Záv. | Nález (skrátene) | Verdikt | Rieši |
|---|---|---|---|---|
| G1 | BLOCKER | otáčanie dielcov bez smeru môže znížiť počet pod to, čo VEPO nareže | **berieme — rozhodol Michal (N8)**: plán neotáča; spor s C8 tým padá | NP-1 |
| G2 | BLOCKER | pracovná doska s ABS potrebuje orez | **neberieme — rozhodol Michal (N9)**: pracovná doska vždy bez orezu | — |
| G3 | FIX | plán musí vyradiť tie isté riadky ako VEPO a zaokrúhliť ako VEPO | **berieme** | NP-1 |
| G4 | FIX | Kontrola a plán jednou funkciou, veta nálezu s použiteľným rozmerom, UNI a chýbajúci formát bez tohto nálezu | **berieme** — iný orez na dvoch PC = iný nález (priznané) | NP-2 |
| G5 | FIX | neistý materiál ostáva na odhade a riadok povie prečo aj v XLSX | **berieme** (ako C3) | NP-4 |
| G6 | FIX | nastavenia s rozsahmi; orez, po ktorom nič neostane, nesmie zhodiť výpočet | **berieme** | NP-1, NP-2 |
| G7 | NOTE | zvýšenie verzie dát rozpočtu, oddeliť porez od montáže | **berieme** | NP-4 |
| G8 | NOTE | malé platne sedia, prah poslednej platne patrí do zadania, výber zo zoznamu | **berieme** (prah schválil Michal: 20 %) | NP-3 |
| G9 | NOTE | rez dávok sedí | **berieme s úpravou** — štyri dávky (časť 3) | — |
| G10 | NOTE | precedensy minimalizujú odpad; bez otáčania a s orezom je plán voči nim opatrný | **potvrdenie** | — |

## 3 · Rez dávok

| Dávka | Čo prinesie používateľovi | Audit návrhu |
|---|---|---|
| **NP-1 · jadro výpočtu** | nič viditeľné — výpočet rozloženia, počtu platní a jedna spoločná kontrola „zmestí sa" | áno (nový modul) |
| **NP-2 · nastavenia + Kontrola** | prerez, orez a prídavok dupláku v Nastaveniach rozpočtu; Kontrola „nezmestí sa" počíta s orezom | áno (verzia súboru nastavení) |
| **NP-3 · sekcia Nárezový plán** | Štúdio ukáže plán podľa mockupu; Rozpočet a XLSX dostanú poznámku „plán: N platní" (ceny sa nemenia) | nie (UI) |
| **NP-4 · ceny podľa plánu** | prepínač „ceny podľa plánu" v Rozpočte | áno (verzia dát rozpočtu) |

Uzáver bloku 2 hneď po NP-4 (variant B); smoke podľa checklistu, porovnanie s VEPO podľa N10.
