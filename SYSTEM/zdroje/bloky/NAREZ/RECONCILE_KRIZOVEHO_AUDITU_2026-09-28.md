# Blok 2 · Nárezový plán — vyhodnotenie krížového auditu (reconcile, 28.9.2026)

> Stav: **vyhodnotenie orchestrátora** — pri každom nálezi berieme / neberieme / mení koncept a prečo. Vstupy: [CROSS_AUDIT_CODEX_2026-09-28.md](CROSS_AUDIT_CODEX_2026-09-28.md)
> (`gpt-5.6-sol`, NOT SOUND — 5 BLOCKER · 6 FIX · 3 NOTE), [CROSS_AUDIT_GROK_2026-09-28.md](CROSS_AUDIT_GROK_2026-09-28.md) (`grok-4.7`, 2 BLOCKER · 4 FIX · 4 NOTE),
> auditovaný koncept [KONCEPT_NP_v1_2026-09-28.md](KONCEPT_NP_v1_2026-09-28.md) (surový vstup, nie zadanie), rešerš [RESERS_OUTSIDE_IN_2026-09-28.md](RESERS_OUTSIDE_IN_2026-09-28.md)
> a rozhodnutia Michala N6–N10 z toho istého večera ([ROZHODNUTIA_MICHALA_2026-09-28.md](ROZHODNUTIA_MICHALA_2026-09-28.md)). Sondu v SketchUpe nevyžadoval
> žiadny nález (ALREADY EXISTS ani SIMPLER NATIVE PATH na SketchUp API nie je). **Technické požiadavky** sa z tohto súboru prenesú do package každej dávky
> a prejdú jej auditom návrhu.

## 1 · Codex (`gpt-5.6-sol`)

| # | Záv. | Nález (skrátene) | Verdikt | Dôsledok |
|---|---|---|---|---|
| C1 | BLOCKER | koncept nepočíta prídavok dupláku N7 → podhodnotí počet | **berieme** | nákupné vrstvy dupláku zväčšené o prídavok pred orientáciou a fitom; prídavok ako nastavenie (predvolene 10 mm na stranu) |
| C2 | BLOCKER | počet bez nezaradených dielcov, s chýbajúcim formátom alebo UNI nie je horná hranica | **berieme** | „horná hranica" len pri úplnom pláne so skutočným formátom; inak „pre zaradené dielce — celkový počet neznámy" alebo „orientačne pri formáte 2800 × 2070" |
| C3 | BLOCKER | „bez exportnej brány" len s cenovým kontraktom, ktorý zlyhá bezpečne | **berieme v upravenej forme** | server per materiál odvodí **cenovú spôsobilosť** (skutočný formát, nie UNI, platné nastavenia, žiadny vyradený ani nezaradený kus, výpočet bez chyby); nespôsobilý materiál ide **na odhad z m²** (dnešná cena) s poznámkou a príznakom `estimated` aj v XLSX — odhad je vždy k dispozícii, preto sa exporty nezastavujú; či to stačí, preverí audit NP-4 |
| C4 | BLOCKER | whitelist nastavení nestačí — starší plugin nové polia zahodí | **berieme** | STD súboru nastavení +1 a dopredná brána (novší súbor sa číta, zápis sa odmietne s dôvodom — vzor R-07/R-14); priznaný limit: plugin v0.15.x a starší na tom istom PC nové polia pri uložení sadzieb zahodí (vrátia sa predvolené hodnoty) |
| C5 | BLOCKER | blok uzavrieť až po porovnaní s reálnou objednávkou (N5) | **neberieme — rozhodol Michal (N10)** | vhodná zákazka teraz nie je; bezpečnosť drží konzervatívny plán (N8 bez otáčania, orez, prídavok dupláku) a prepínač cien predvolene vypnutý; voliteľne nepotvrdená objednávka VEPO po NP-1; porovnanie 1:1 po V1 na novej testovacej zákazke |
| C6 | FIX | formalizovať policovú heuristiku (orientácia pred radením, výška pásu, nerovnosti kerfu, tolerancia, kanonický textový kľúč radenia), volať ju „rozloženie heuristiky" | **berieme** | package NP-1; bez otáčania (N8) je jednoduchšia |
| C7 | NOTE | vstup cez `Bom.compute` je správny | **potvrdenie** | — |
| C8 | FIX | tri kroky vstupu: prijatie riadka · VEPO reprezentácia · nákupné obdĺžniky; neznámy smer sa neotáča | **berieme** | package NP-1 (s N8 sa neotáča nič) |
| C9 | FIX | jedna autorita „zmestí sa" (typ materiálu, formát, orez, tolerancia) pre plán aj `oversize`; prípady `2 × orez ≥ rozmer`, neplatný kerf, obnova po uložení nastavení | **berieme** | funkcia v NP-1, Kontrola a nastavenia v NP-2 |
| C10 | FIX | rozpočet má jeden súčet platní pre porez aj montáž | **berieme** | NP-4: množstvo pre materiál a porez oddelene od montáže (bod mockupu O6) |
| C11 | NOTE | `BUDGET_STD` 3 je správna cesta | **berieme** | NP-4 cez existujúci marker R-14 |
| C12 | FIX | plný push nesie celé rozloženie aj tomu, kto sekciu neotvorí | **berieme** | NP-3: limit veľkosti a času serializácie, test veľkej zákazky, obe témy; detail platne kompaktne alebo na požiadanie |
| C13 | NOTE | id sekcie `cut` nekoliduje s `cut_*` | **berieme** | id ostáva `cut`, nový kód sa nepomenúva `cut_*` (aj Grok 8) |
| C14 | FIX | precedensy: zoznam nezaradených, výslovná politika otáčania a orezu, „počet tohto rozloženia" | **berieme** | zapracované v C2, C3, N8 |

## 2 · Grok (`grok-4.7`)

| # | Záv. | Nález (skrátene) | Verdikt | Dôsledok |
|---|---|---|---|---|
| G1 | BLOCKER | otáčanie dielcov bez smeru môže znížiť počet pod to, čo VEPO nareže | **berieme — rozhodol Michal (N8)** | plán neotáča žiadny dielec; spor s Codex C8 („smie sa otáčať len bez smeru") tým padá |
| G2 | BLOCKER | pracovná doska s ABS potrebuje orez | **neberieme — rozhodol Michal (N9)** | PD vždy bez orezu, rovnako kompakt a zástena (N6) |
| G3 | FIX | plán musí vyradiť tie isté riadky ako VEPO (neznáma ABS, zlá hrúbka) a zaokrúhliť rozmery ako VEPO | **berieme** | package NP-1; každý vyradený kus robí materiál cenovo nespôsobilým (C3) |
| G4 | FIX | `oversize` a plán jednou funkciou vrátane tolerancie; veta nálezu s použiteľným rozmerom; UNI a chýbajúci formát bez tohto RED | **berieme** | NP-2; iný orez na dvoch PC = iný RED — priznané (nastavenia sú globálne per PC) |
| G5 | FIX | nespôsobilý materiál ostáva na odhade, riadok povie prečo aj v XLSX | **berieme** | ako C3 |
| G6 | FIX | nastavenia: whitelist, predvolené hodnoty, rozsahy; orez, po ktorom nič neostane, = neúplný plán, nie pád | **berieme** | NP-1 (výpočet) a NP-2 (nastavenia) |
| G7 | NOTE | `BUDGET_STD` 3, oddeliť porez od montáže, plán aj v `Budget.compute` | **berieme** | NP-4 |
| G8 | NOTE | miniatúry sedia, prah poslednej platne do package, výber zo zoznamu, nie zo SVG | **berieme** | NP-3 (prah = bod mockupu O2) |
| G9 | NOTE | rez dávok sedí; komentár D-19 v odhade upraviť; STANDARD §12 v NP-1 | **berieme s úpravou** | štyri dávky (časť 4) |
| G10 | NOTE | precedensy minimalizujú odpad, plán nákup naddimenzuje — bezpečné, ak sa neotáča a neodpúšťa orez | **potvrdenie** | — |

## 3 · Čo sa mení oproti konceptu v1 (vstup pre packages)

1. **Žiadne otáčanie** (N8) — orientácia presne ako VEPO (`width` → výmena dĺžky a šírky), pravidlo otáčania z v1 §3 vypadá.
2. **Duplák:** nákupná vrstva = hotový rozmer + prídavok na každej strane (predvolene 10 mm → +20 mm v každom rozmere) (N7).
3. **Orez** len DTD, MDF, HDF a ostatné dosky; pracovná doska (aj s ABS), kompakt a zástena bez orezu (N6, N9).
4. **Vstup v troch krokoch:** prijatie riadka (tie isté vyradenia ako VEPO) → VEPO podoba (orientácia, zaokrúhlenie) → nákupné obdĺžniky (duplák na zdroj s prídavkom).
5. **Pomenovanie výsledku:** „horná hranica" len pri úplnom pláne so skutočným formátom; inak výslovne neúplný alebo orientačný.
6. **Cenová spôsobilosť** per materiál na serveri; nespôsobilý materiál na odhade s poznámkou; porez podľa množstva materiálu, montáž z odhadu (O6).
7. **Jedna funkcia „zmestí sa"** pre plán aj Kontrolu (typ, formát, orez, tolerancia); veta nálezu s použiteľným rozmerom.
8. **Nastavenia:** prerez 5 mm, orez 10 mm, prídavok dupláku 10 mm — globálne, STD súboru + dopredná brána.
9. **Payload:** limit veľkosti a času, test veľkej syntetickej zákazky (fixtúra KLINIKA neexistuje).
10. **N5 nie je brána** (N10).

## 4 · Rez dávok (v2)

| Dávka | Obsah | Trieda |
|---|---|---|
| **NP-1 · jadro** | čistý modul plánu + funkcia „zmestí sa" + kontrakt výsledku + testy (presné očakávané rozloženia, vlastnosti, výkon syntetickej zákazky); prerez, orez a prídavok ako vstupné parametre; STANDARD §12 a pravidlo formátu platne; komentár kontraktu odhadu | audit ÁNO (nový modul) · predrecenzia |
| **NP-2 · nastavenia + Kontrola** | 3 hodnoty v nastaveniach dodávateľa (STD + dopredná brána) a 3 riadky v Nastaveniach rozpočtu; Kontrola `oversize` cez spoločnú funkciu s orezom; obnova Štúdia po uložení | audit ÁNO (STD súboru) · predrecenzia (nový ovládací prvok) |
| **NP-3 · sekcia Nárezový plán** | plán v pushi Štúdia a v rozpočte (5 volajúcich), sekcia s miniatúrami a detailom, upozornenie poslednej platne, zoznam nezaradených, výber v modeli; poznámka „plán: N platní" v Rozpočte a XLSX **bez zmeny cien** | UI dávka · predrecenzia |
| **NP-4 · ceny podľa plánu** | prepínač per zákazka (`BUDGET_STD` 3, R-14), cenová spôsobilosť, množstvo a porez podľa plánu, montáž z odhadu | audit ÁNO (schéma) · cenová dávka · predrecenzia · in-SU |

Uzáver bloku 2 (minor verzia) hneď po NP-4 (variant B); smoke podľa checklistu + voliteľná nepotvrdená objednávka VEPO (N10).
