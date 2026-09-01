# KOVANIE — detail fill checkpoint 2026-09-02 #11

> Stav: KONCEPT / pracovný checkpoint — nie implementačný spec, neimplementovať priamo; uzavretá architektúra: KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md.

> Produkčné rozhodnutia Michala po schválení mockupu (2.9.2026). Vstupy pre data packy receptov (slice C),
> ABS defaulty nových rolí (slice A/C) a 4. materiálový kanál (slice C). Dopĺňa FINAL §3/§6/§14.

## 1. Atira H70 — min. výška niky

- „~92 mm" v Noxun podkladoch bolo **neoficiálne, odhad z hlavy** (Michal 2.9.). **Neplatí.**
- Do dát idú VÝHRADNE oficiálne Hettich hodnoty per opening mode: **H70 = 105 (SiSy) / 106 (P2O) / 108 (P2Os)**;
  H144 = 189/190/192; H176 = 221/222/224 (checkpoint #10, VERIFIED OFFICIAL).

## 2. ABS odvodených dielcov zásuvky — USER-CONFIRMED PRODUCTION RULE (platí pre všetky systémy)

- **Drevený box (Quadro a rodina WOOD):** 4 dielce dookola — **boky + vnútorné čelo + chrbát** majú olepenú
  **hornú („dlhú") hranu**; ostatné hrany bez olepu. **Dno neolepené.**
- **Atira (a rodina METAL):** **dno neolepené**; **drevený chrbát — olepená dlhá (horná) hrana.**
- Mapovanie na roly: `drawer_side` · `drawer_inner_front` · `drawer_back` → ABS na hornej dlhej hrane;
  `drawer_bottom` → bez ABS. Nová položka `AbsRules::SEED_RULES` per rola (ORANGE „skontroluj" sa pre tieto
  roly neuplatňuje — pravidlo je explicitné, nie prázdne).
- **Predpoklad na potvrdenie (detail fill):** hrúbka pásky = projektové ABS pravidlo (default **1,0 mm**, ako čelá).

## 3. Materiál zásuviek — 4. materiálový kanál `:drawer`

- Štandard Noxun: **16 mm biela DTD**.
- Rozhodnutie o defaulte (Michalova otázka „my používame UNI, kým user nevyberie?" → odporúčanie orchestrátora,
  konzistentné s existujúcim E-03 UNI mechanizmom): **projektový default `:drawer` = UNI 16 mm** (hrúbka je
  garantovaná UNI mechanizmom, dekor nezvolený); používateľ v Materiáloch projektu nastaví konkrétny dekor
  (typicky biela 16). UNI sa prizná ako dnes (Kontrola/kusovník — UNI riadok), nikdy tichá biela.
  Ručný override per dielec cez part_overrides ostáva.

## Otvorené (čaká na Michala)

4. Démos kit vs. atomic — 2–3 reálne príklady objednávok (jedna K-sada kód · jedna zložená z komponentov).
5. Hmotnostné prahy závesov (tabuľka výrobcu alebo Noxun prax); výšková os seedu 900/1400/1900 → 2/3/4/5 potvrdiť.
6. Poradie packages: návrh 0 (D-52) · A · B · H hneď; C · D po bodoch 4–5.
