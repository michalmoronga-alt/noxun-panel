# Blok 2 · KONTROLA + VÝROBA — Nárezový plán (primitívny): rozhodnutia Michala (6.9. a 28.9.2026)

> **Produktové rozhodnutia bloku** — čo a ako má plugin robiť z pohľadu stolára. **Technické požiadavky** (tvar výsledku, verzie dát,
> výrobné a cenové brány, testy…) sa zapisujú do **package každej dávky** a prejdú jej auditom návrhu.
> Pôvodná debata: [../../next_sessions/V1_DEBATA_2026-09-06_KONTROLA_VYROBA.md](../../next_sessions/V1_DEBATA_2026-09-06_KONTROLA_VYROBA.md) §0 a návrh
> rozsahu [../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md](../../next_sessions/NAREZ_PLAN_NAVRH_2026-09-06.md) (Codex #322/#323). Tento súbor ich
> **nenahrádza** — dopĺňa rozhodnutia zo štartu bloku. Ďalšie súbory priečinka: fakty z kódu [FAKTY_Z_KODU_2026-09-28.md](FAKTY_Z_KODU_2026-09-28.md) ·
> rešerš precedensov [RESERS_OUTSIDE_IN_2026-09-28.md](RESERS_OUTSIDE_IN_2026-09-28.md) · krížový audit [CROSS_AUDIT_PROMPT_2026-09-28.md](CROSS_AUDIT_PROMPT_2026-09-28.md),
> [CROSS_AUDIT_CODEX_2026-09-28.md](CROSS_AUDIT_CODEX_2026-09-28.md), [CROSS_AUDIT_GROK_2026-09-28.md](CROSS_AUDIT_GROK_2026-09-28.md), auditovaný koncept v1 ako
> surový vstup [KONCEPT_NP_v1_2026-09-28.md](KONCEPT_NP_v1_2026-09-28.md) (nie zadanie) · vyhodnotenie nálezov
> [RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md) · schválený mockup [MOCKUP_NAREZ_2026-09-28.html](MOCKUP_NAREZ_2026-09-28.html).
> Packages dávok pribudnú s dávkami.

## 1 · Rozhodnutia

| # | Téma | Rozhodnutie | Kedy |
|---|---|---|---|
| N1 | Prečo a čo | primitívny nárezový plán **je vo V1**: dnes je počet platní len odhad z m² (koeficient prerezu 10–25 %), realita je iná — po pláne vieme, koľko platní **najviac** treba (**horná hranica podľa zvoleného rozloženia**, nie presné množstvo), a keď „1 diel vychádza na celú platňu a musím objednať 2", dá sa na to pozrieť a niečo vymyslieť | 6.9. |
| N2 | Kto reže | **rezanie robí VEPO** (vlastná optimalizácia) — plán je pre **objednávku a rozhodovanie**, nie výrobný dokument; **objednáva človek** | 6.9. |
| N3 | Prerez a orez | **hrúbka kotúča (prerez) 5 mm** a **orez okraja platne 10 mm** ako predvolené hodnoty; **obe nastaviteľné** („hrúbka kotúča aj orez sa môžu líšiť" — zmena dodávateľa, iné štandardy), ak to nekomplikuje prácu — **agent zhodnotí náročnosť** pevnej hodnoty oproti nastaveniu a navrhne | 28.9. |
| N4 | Ako VEPO účtuje | **celé tabule, zvyšky sú moje** — cena materiálu podľa počtu platní z plánu má teda zmysel (podklad pre voľbu „ceny podľa plánu" v rozpočte) | 28.9. |
| N5 | Overenie na praxi | Michal pohľadá **jednoduchú reálnu zákazku s počtami platní z objednávky VEPO** — plán sa na nej porovná s realitou (test a smoke) | 28.9. |
| N6 | Orez podľa materiálu | orez okraja platí **len pre bežné platne** (DTD, MDF, HDF a iné dosky); **pracovná doska, kompakt a zástena bez orezu** — hrany sú hotové | 28.9. |
| N7 | Duplák | VEPO reže obe vrstvy dupláku **s prídavkom +10 mm na stranu**, potom ich zlepí a oreže na hotový rozmer — plán musí prírezy vrstiev zväčšiť o prídavok | 28.9. |
| N8 | Otáčanie dielcov | či VEPO otáča dielce bez smeru dekoru, Michal nevie → **plán neotáča žiadny dielec** (len výmena podľa smeru dekoru ako vo VEPO CSV); počet je tak opatrnejší (nanajvýš o niečo vyšší, než keby sa otáčalo); počet VEPO sa môže líšiť. Otáčanie sa smie zapnúť neskôr, keď porovnanie s reálnou objednávkou ukáže, že VEPO otáča | 28.9. |
| N9 | Orez pracovnej dosky | **pracovná doska vždy bez orezu** — aj s ABS hranou (nie len postforming); krížový audit navrhoval orez pri PD s ABS, Michal ponechal N6 | 28.9. |
| N10 | Porovnanie s VEPO (N5) | vhodná reálna zákazka teraz nie je (KLINIKA je stará — polovica funkcií vtedy nebola). Porovnanie 1:1 **po V1** na novej zákazke, ktorá sa stane testovacím štandardom. **Ak je test nevyhnutný skôr:** vytvoríme objednávku, Michal ju pošle VEPO **bez potvrdenia** — príde výpis a nacenenie, bez objednania | 28.9. |

| N11 | Mockup | **mockup schválený** ([MOCKUP_NAREZ_2026-09-28.html](MOCKUP_NAREZ_2026-09-28.html)): O1–O12 podľa návrhu, **O2 so zmenou** — upozornenie na poslednú platňu pri využití **pod 20 %** alebo pri **najviac 2 dielcoch** (len pri materiáli s aspoň 2 platňami); „ideme ďalej" | 28.9. |

**Postreh mimo V1 (28.9.):** „falošný duplák" — pohľadová je len jedna strana, spodná vrstva sa skladá zo 100 mm širokých výstuh (šetrí materiál aj
váhu, keď nie sú obe strany pohľadové). Zapísané ako **D-146** do zásobníka Po V1.

## 2 · Otvorené body mockupu — zodpovedané (N11)

Všetky body mockupu (O1–O12) Michal zodpovedal 28.9.2026 večer: zobrazenie v Štúdiu a riadok v Rozpočte podľa mockupu, prepínač „ceny podľa plánu“
per zákazka predvolene vypnutý (O5), porez podľa plánu a montáž z odhadu (O6), prerez, orez a prídavok dupláku v Nastaveniach rozpočtu raz pre všetky
zákazky (O7, O12), prah upozornenia poslednej platne **20 %** alebo najviac 2 dielce (O2). Nič otvorené pred packages neostáva.
