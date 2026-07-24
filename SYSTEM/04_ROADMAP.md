# Noxun Engine — roadmapa (živý dokument, aktualizované 24.7.2026)

> Princíp: **najprv všeobecný základ pre všetko, potom vyostrovanie.** Regenerate pattern robí konštrukčné zmeny lacnými — drahé je len meniť DÁTOVÝ MODEL (atribúty, identita, hrany), preto ten je uzamknutý štandardom vopred a detaily geometrie sa doladia iteráciami z klikania.

## Kde sme (24.7.2026)

- Plugin **v0.5.0** — etapa **V0.5 KOMPLET**: výstupy (kusovník, okno Výroba, VEPO CSV validovaný proti OCL flow, odhad platní), kontrolný semafor, dekorové skupiny materiál↔ABS (V0.5-E) a dekorový katalóg UI (V0.5-F).
- Testy: **372 headless + 200 JS (CI na každý push) + ~140 in-SketchUp scenárov**.
- Práve beží: **uzáver V0.5** — cleanup, dokumentácia, hardening, slovné prechádzky systémom (ujasnenie pojmov), príprava katalógu materiálov (Demos).
- Ďalej: **V0.6 KOVANIE fáza 2** (štart ~28.7.) · V0.4.8 otvorená/neplánovaná · V1.0 zostavy.

## Hotové etapy (kompakt)

Plné pôvodné texty: [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).

| Etapa | Hotové | Obsah v skratke | PR |
|---|---|---|---|
| V0.1 klikateľný základ | 15.7. | panel, dolný korpus z Ruby, police, dvierka, ghost zóny, 1-krok Undo | — |
| V0.2a jadro korpusu | 16.7. | scale→prestavba, konštrukčné varianty, horná skrinka | — |
| V0.2b členenie/čelá/šablóny | 16.7. | strom zón + priečky, čelá fixed/auto s lockmi, šablóny | — |
| V0.2c UX panela | 16.7. | 2D náhľad, auto-apply, tagy, osové scale, opravy | #2–#5 |
| V0.3 materiály a ABS | 17.7. | katalóg, dedenie projekt→skrinka→dielec, hrany L1/L2/W1/W2 | #6–#9 |
| V0.3.1–.3 stabilizácia dát | 17.7. | hrúbky, identita part_key, ABS 1/2 mm | #10–#12 |
| V0.3.4 stabilizácia pred kovaním | 17.7. | testy+CI, panel split, BuildPlan kontrakt, SU runner, undo fixy | #13–#21 |
| V0.4 kovanie fáza 1 | 18.7. | pravidlá fixed/bands/fit_series, projektový snapshot, overrides | #23–#26 |
| V0.4.5 Inspector + satelity | 18.7. | kontextový Inspector, náhľad zoom/pan/fit, satelitné okná | #27–#30 |
| V0.4.7 samostatná doska | 19.7. | kind board, ABS editor, scale absorpcia, výrazy v poliach | #31–#35 |
| V0.4.7 dogfood dávky | 19.–21.7. | D-01…D-40 (zápisník), režimové taby, hlavička+tokeny+ikony, MCP diagnostika | #37–#69 |
| V0.5 výstupy v0 | 19.–21.7. | kusovník, okno Výroba, VEPO CSV (validovaný 2-kolovo s OCL), odhad platní, semafor | #47–#65 |
| V0.5-E dekorové skupiny | 23.7. | šírka ABS + deterministický picker, dekor = kľúč skupiny, remap pri zmene materiálu | #70–#73 |
| V0.5-F dekorový katalóg UI | 24.7. | mriežka dlaždíc, kód+dodávateľ, cena „nezadaná", inline bunky s patch protokolom, preset-čipy | #74–#77 |
| **Uzáver V0.5** | 24.7. | verzia 0.5.0, hooky, docs reštruktúra + archív, hardening | #79+ |

## Pred nami

### V0.6 — Kovanie fáza 2 (katalóg a ceny) — štart ~28.7.

- Prevzatie CatalogStore/search/Demos import z KOVANIE · mapovanie flagov na konkrétne kódy (pamätá sa) · ceny v sumári.
- **Otvorená otázka (debata 24.7., rozpracovať pred štartom):** „zadaj kód → načítaj dáta" — demos-trade.sk má verejné vyhľadávanie (kód → 1 položka aj dekor → celá skupina s cenami bez loginu) + Konfigurátor cenníkov na Démos24Plus (hromadný export za loginom). Zvážiť hybrid: hromadný seed z cenníka + per-kód dohľadanie. Viď zápisník uzáveru.
- **Pracovné dosky ako súčasť dekorovej skupiny** (Michal 24.7.): rovnaké dekory, iný rozmer/typ (PD 4100×600/920/38, HPDB hrana š.45, DTDL 36 = 2× zlepená 18) — dátovo pripravené cez `sheet_variants` s typom per variant (D-42); doriešiť pri katalógu.
- Z prenesených záväzkov zvážiť: smer otvárania + typ závesu, hmotnostné tabuľky, „použiť na podobné" pre kovanie.

### V0.4.8 — Konštrukčné možnosti z 06 (otvorená, neplánovaná)

Zostávajúce zadanie z [06_PANEL_NASTAVENIA_navrh.md](06_PANEL_NASTAVENIA_navrh.md): rohové spoje dna/stropu per strana (vľavo/vpravo vložené/naložené) · chrbát s poldrážkou · „bez dielca" varianty (bez boku/dna/stropu — otvorené niky s validáciou) · per-dielec hrúbky a odsadenia (vpredu/vzadu). *(Medzery/presahy čiel z pôvodného rozsahu sú hotové — D-07 + D-22.)* Zaradenie rozhodne Michal (kandidát: po V0.6).

### V1.0 — Zostavy a stabilizácia

Spájanie/zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, rohové situácie — snaper logika) · **soklová lišta v celku pre celý segment** · **obklady a krycie prvky segmentu**: pilastre (priznaný/skrytý + rýchly nástroj), pracovné dosky a horné krycie dosky na pár klikov na označený segment · ABS vizuálny režim (farebné hrany, klik-edit) · migrácia/oprava starých modelov · test na kompletnej reálnej zákazke.

### Neskôr (po V1)

Zásuvkové bloky (dočasne DC Atira most) · vnútorné vybavenie (koše, tyče…) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy/etikety · CNC · injecting dát do knižníc v dávkach (kódy, materiály, kovania, spotrebiče — architektúru pripraviť skôr).

## Prenesené záväzky (z uzavretých etáp — nestratiť)

- **Seed reálnych dekorov** do katalógu dodá Michal pri testovaní D-42 (zoznam materiálov pripravuje — debata 24.7.).
- **V0.4 odložené kovanie témy:** hmotnostné Blum tabuľky (chýba hustota materiálu) · smer otvárania a typ závesu (naložené/vložené/tip-on) · automatika počtu nôh podľa šírky (zmena JSON pravidla). → zvážiť vo V0.6.
- **„Použiť na podobné"** (odstránené PR #14) — vráti sa premyslené až s kovaním (V0.6+).
- **V0.4.7 vedome neobsahuje** (→ V1.0 zostavy): attachment/segmenty, automatické krycie dosky, pracovné dosky cez segment.
- **Nárezový plán fáza 2** (guillotine, kerf, orezky, orientácia dekoru): OpenCutList je GPL (kód neprebrať, algoritmus áno); D-19 kontrakt pripravený (vstup = dielce). → po V0.6.
- **Redo správanie zlúčených operácií** — Ruby API nemá na Windows spoľahlivú redo akciu; manuálne overiť Ctrl+Y pri hardeningu (otvorené pozorovanie zo 17.7.).

## Pravidlo pre postrehy (Michal)

**Píš postrehy HNEĎ, keď ich vidíš — hocikedy, hociktorú tému.** Nemusíš strážiť, čo je kedy v pláne — ja každý postreh zaradím: buď do bežiacej etapy (ak sa týka), alebo do backlogu nižšie s označením etapy. Nič sa nestratí. Krátka veta stačí („boky majú stáť na dne, nohy pod tým") — doplňujúce otázky si vyžiadam sám.

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.

## Backlog postrehov (otvorené)

Vyriešené riadky sú v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md); operatívne postrehy z dogfoodingu žijú ako D-čísla v [08_DOGFOODING.md](08_DOGFOODING.md).

| Dátum | Postreh | Zaradenie |
|---|---|---|
| 15.7. | Spájanie korpusov: zarovnanie čelných hrán (default), voliteľne zadných; pripájacie body; rohová sa nepája na rohový styk | V1.0 zostavy (štandard otvorený bod 7) |
| 15.7. | Rohová a vysoká/potravinová skrinka ako nové TYPY builderov | po V1.0 (odvodia sa od dolnej/hornej) |
| 16.7. | **Pilaster** (bočná krycia/obkladová doska): skrutkuje sa zvnútra, zakrýva biely korpus a spoje; variant **priznaný** vs. **skrytý** (čelá presahujú); ideálne rýchly nástroj | V1.0 zostavy — obklady segmentu; rola `pilaster` do štandardu pri implementácii |
| 16.7. | **Pracovné dosky + horné krycie dosky**: vloženie na pár klikov na OZNAČENÝ SEGMENT (cez viac skriniek, ako soklová lišta) | V1.0 zostavy; production_class sheet, dĺžka zo segmentu; katalógová stránka PD sa rieši už vo V0.6 (dekorové skupiny) |
| 16.7. | Zóny priamo vo viewporte (variant B vízie) — nadstavba 2D náhľadu | neskoršie verzie (A = 2D náhľad hotový) |
| 16.7. | **Stráž kolízií** — diely sa prekrývajú / vyskočia mimo box → upozorniť kde a prečo | validačná vrstva semaforu (bbox check dielcov zatiaľ neimplementovaný) |
| 16.7. | **Interact pre čelá**: dráhy otvárania, klik = otvorenie, merač kolízií pri otvorení — prezentácia, kontrola | po V1.0 (dáta máme: origin čiel na hrane pántu; premyslieť pri kovaní — typ pántu = dráha) |
| 16.7. | Náhľad povýšiť na „otvárací náhľad" panela so zobrazovaním zvolených elementov | neskoršie verzie — [07_UI_VIZIA.md](07_UI_VIZIA.md) |
| 16.7. | Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zle funguje | odložené — rieši sa s knižnicou/editorom typov |
| 17.7. | Redo po zlúčených transparentných operáciách overiť manuálne (Ctrl+Y) | hardening uzáveru V0.5 (viď prenesené záväzky) |
| 19.7. | Injecting dát po V1: kódy, materiály, kovania, spotrebiče, vybavenie do knižníc v dávkach — dovtedy pripraviť architektúru | po V1.0 — plán napĺňania knižníc (súvisí s Demos konektorom V0.6) |
| 20.7. | Nárezový plán fáza 2 (guillotine, kerf, orezky, orientácia dekoru) — vlastná heuristika v čistom Ruby | po V0.6 (D-19 kontrakt pripravený) |
