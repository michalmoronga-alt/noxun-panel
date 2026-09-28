# Blok 2 · KONTROLA + VÝROBA — Nárezový plán (primitívny): rozhodnutia Michala (6.9. a 28.9.2026)

> **Produktové rozhodnutia bloku** — čo a ako má plugin robiť z pohľadu stolára. **Technické požiadavky** (tvar výsledku, verzie dát,
> výrobné a cenové brány, testy…) sa zapisujú do **package každej dávky** a prejdú jej auditom návrhu.
> Pôvodná debata: [../../next_sessions/V1_DEBATA_2026-09-06_KONTROLA_VYROBA.md](../../next_sessions/V1_DEBATA_2026-09-06_KONTROLA_VYROBA.md) §0 a návrh
> rozsahu [../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md](../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md) (Codex #322/#323). Tento súbor ich
> **nenahrádza** — dopĺňa rozhodnutia zo štartu bloku. Rešerš precedensov: [RESERS_OUTSIDE_IN_2026-09-28.md](RESERS_OUTSIDE_IN_2026-09-28.md).
> Ďalšie súbory priečinka (fakty z kódu, krížový audit, mockup, packages) pribudnú počas prípravy bloku.

## 1 · Rozhodnutia

| # | Téma | Rozhodnutie | Kedy |
|---|---|---|---|
| N1 | Prečo a čo | primitívny nárezový plán **je vo V1**: dnes je počet platní len odhad z m² (koeficient prerezu 10–25 %), realita je iná — po pláne vieme, koľko platní **najviac** treba (**horná hranica podľa zvoleného rozloženia**, nie presné množstvo), a keď „1 diel vychádza na celú platňu a musím objednať 2", dá sa na to pozrieť a niečo vymyslieť | 6.9. |
| N2 | Kto reže | **rezanie robí VEPO** (vlastná optimalizácia) — plán je pre **objednávku a rozhodovanie**, nie výrobný dokument; **objednáva človek** | 6.9. |
| N3 | Prerez a orez | **hrúbka kotúča (prerez) 5 mm** a **orez okraja platne 10 mm** ako predvolené hodnoty; **obe nastaviteľné** („hrúbka kotúča aj orez sa môžu líšiť" — zmena dodávateľa, iné štandardy), ak to nekomplikuje prácu — **agent zhodnotí náročnosť** pevnej hodnoty oproti nastaveniu a navrhne | 28.9. |
| N4 | Ako VEPO účtuje | **celé tabule, zvyšky sú moje** — cena materiálu podľa počtu platní z plánu má teda zmysel (podklad pre voľbu „ceny podľa plánu" v rozpočte) | 28.9. |
| N5 | Overenie na praxi | Michal pohľadá **jednoduchú reálnu zákazku s počtami platní z objednávky VEPO** — plán sa na nej porovná s realitou (test a smoke) | 28.9. |

## 2 · Otvorené — rozhodne Michal pri mockupe

- zobrazenie v Štúdiu (sekcia **Nárezový plán**) a riadok v Rozpočte — podľa mockupu (každý bod označený „návrh — potvrdí Michal" dostane odpoveď pred packages),
- prepínač „ceny podľa plánu" v rozpočte (návrh 6.9.: odhad ostáva predvolený, plán je voľba používateľa),
- kde sa nastavuje prerez a orez (jedno nastavenie pre všetky zákazky alebo per zákazka) — podľa zhodnotenia náročnosti (N3).
