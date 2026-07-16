# Návrh štruktúry nastavení korpusu (Michal, 16.7.2026) + rozbor

> Michalova vízia organizácie nastavení (Blum inšpirácia, screenshoty referenčného panela s akordeónmi). Status: **schválený smer pre Inspector** (viď 05_DILEMA) — implementácia V0.2c.

## Michalov návrh (doslovne štruktúra)

**1. KORPUS (základné):** Výška · Šírka · Hĺbka · Hrúbka materiálu všeobecne · Medzera/presah hore · dolu · vľavo · vpravo · Medzera medzi čelami · *view-only:* Svetlá šírka · Svetlá hĺbka (· Výška úložného priestoru)

**STROP:** naloženie (naložené/vložené) · Konštrukcia (plný / priečky → + rozmer priečky + orientácia / bez stropu) · Hrúbka · Odsadenie · Odsadenie vpredu · vzadu

**DNO:** naloženie (naložené/vložené) · Konštrukcia (plný / bez dna) · Hrúbka · **Rohový spoj vľavo** · **Rohový spoj vpravo** · Odsadenie · vpredu · vzadu

**BOK ĽAVÝ / PRAVÝ:** Konštrukcia (s bokom / bez boku) · Hrúbka · Odsadenie vpredu · vzadu

**CHRBÁT:** Konštrukcia (naložený / s poldrážkou / s drážkou / vložený / bez chrbta) · Hrúbka

Princíp: v prvom kroku KORPUS nastaví všetko podstatné; detaily per dielec smerom dole. **ČELÁ** a **VNÚTORNÉ VYBAVENIE** = osobitné kategórie rovnakého štýlu.

## Rozbor (Fable) — prijaté s doplneniami

**Prečo je to správne:** nastavuješ DIELEC (strop, dno, bok…), nie abstraktný „variant konštrukcie" — zodpovedá stolárskemu mysleniu aj nášmu dátovému modelu (config už má podstromy sides/bottom/top/back — je to hlavne UI reorganizácia + jemnejšie dáta). Pattern „všeobecná hodnota → per-dielec override" = rovnaké dedenie ako pri materiáloch.

**Dátové dôsledky (rozšírenia štandardu/configu — zadanie V0.2c):**
1. **Rohové spoje PER STRANA:** `bottom.joint_left/joint_right: "inset"|"overlay"` (a analogicky strop) — jemnejšie než dnešný celoplošný `mode under_sides/between_sides` (ten sa stane odvodeným/legacy). Umožní aj asymetriu (vľavo vložené, vpravo naložené).
2. **Per-dielec hrúbka** (default z všeobecnej, override) + **odsadenia** (všeobecné/vpredu/vzadu) na strop/dno/boky.
3. **„Bez dielca" varianty:** bez boku / bez dna / bez stropu (otvorené niky!) — pozor na validáciu (čo drží čo).
4. **Chrbát 5 variantov:** naložený / s poldrážkou (nový!) / s drážkou / vložený / bez.
5. **Medzery/presahy čiel na úrovni korpusu** (hore/dolu/vľavo/vpravo/medzi čelami) — korpusové defaulty pre fronts (dedičstvo dnešných k_medz* z DC).
6. **View-only vypočítané:** svetlá šírka/hĺbka/výška úložného priestoru — z available_*, len zobraziť (kontrola pre používateľa).
7. Priečky stropu: rozmer + orientácia už máme (rails) — zaradiť pod STROP.

**Nadväznosť na dilemu UI (05):** táto štruktúra = obsah **INSPECTORA** pre kind:cabinet. Kategórie KORPUS / ČELÁ / VNÚTORNÉ VYBAVENIE sú v súlade s hierarchiou štandardu (korpus/moduly/zóny).

**Otvorené drobnosti:** či „naloženie" stropu/dna nechať aj ako rýchly celok + per-strana rohové spoje ako pokročilé (navrhujem áno — jednoduchý prepínač nastaví obe strany, pokročilé odomkne asymetriu). Hrúbka čela 19 vs 18 — doriešiť pri materiáloch.
