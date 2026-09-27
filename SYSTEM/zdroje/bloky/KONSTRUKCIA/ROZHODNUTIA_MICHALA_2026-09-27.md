# Blok 7 · KONŠTRUKCIA K1+K2 — rozhodnutia Michala (26.–27.9.2026)

> **Produktové rozhodnutia bloku** z debát s Michalom 26. a 27.9.2026 — čo a ako má plugin robiť z pohľadu stolára. **Technické požiadavky**
> (formát dát, verzie configu a šablón, výrobné brány exportov, zastarané skrinky, samostatné dielce, seed Chladničkovej s verziou configu…)
> sa zapisujú do **package každej dávky** a prejdú jej auditom návrhu: KON-0 [PACKAGE_KON0_D143.md](PACKAGE_KON0_D143.md) (+ audit návrhu
> [AUDIT_KON0_2026-09-27.md](AUDIT_KON0_2026-09-27.md)); pre KON-A, B, D zatiaľ [VSTUPY_PRE_PACKAGES_2026-09-27.md](VSTUPY_PRE_PACKAGES_2026-09-27.md)
> (vstup, nie autorita). Ďalšie súbory priečinka: fakty z kódu [FAKTY_Z_KODU_2026-09-26.md](FAKTY_Z_KODU_2026-09-26.md) · krížový audit
> [CROSS_AUDIT_PROMPT_2026-09-27.md](CROSS_AUDIT_PROMPT_2026-09-27.md), [CROSS_AUDIT_GROK_2026-09-27.md](CROSS_AUDIT_GROK_2026-09-27.md),
> [CROSS_AUDIT_CODEX_2026-09-27.md](CROSS_AUDIT_CODEX_2026-09-27.md) · schválený mockup [MOCKUP_KONSTRUKCIA_2026-09-27.html](MOCKUP_KONSTRUKCIA_2026-09-27.html)
> (sekcia B — bokorys — zamietnutá).

## 1 · Rozhodnutia

| # | Téma | Rozhodnutie | Kedy |
|---|---|---|---|
| M1 | Komín vzadu (K1) | komín = o koľko sú dno a strop vzadu kratšie ako bok; **bežne ~50 mm**; jedna hodnota na skrinku, predvolene 0 | 6.9. + 26.9. |
| M2 | Komín + chrbát v drážke | drážka **len v bokoch**, na úrovni zadnej hrany dna a stropu; na dne a strope chrbát **presahuje** (je naložený na ich zadné hrany) | 26.9. |
| M3 | Zapustený strop (K1) | strop alebo predná výstuha začína za prednou hranou boku; dno sa neodsadzuje; **dolná aj horná** skrinka | 6.9. + 26.9. |
| M4 | Chrbát z líšt (K2) | dve vodorovné lišty z korpusu medzi bokmi (hore + dole), výška = parameter (návrh 100), ABS len na hrane viditeľnej zvnútra | 6.9. |
| M5 | Vnútro pri lištách | police, priečky a zásuvky končia pred lištami **v celej výške** skrinky | 26.9. |
| M6 | Lišty vo výstupoch | **jeden riadok, 2 ks, „Chrb HD"**, páska na jednej dlhej hrane (kus sa pri montáži len otočí); ak má skrinka aj výstuhy na výšku rovnakého rozmeru a materiálu, zlúčia sa s nimi do jedného riadku (výrobne ten istý kus) | 26.9. |
| M7 | Šablóna | blok pridá **len „Chladničkovú": 600 × 2100 × 560, komín 50 (dno 510), bez chrbta**, očakáva chladničku — tak ju Michal v praxi vyrába | 26.9. + 27.9. |
| M8 | **D-143** chrbát v drážke | dnes do nárezu vnútorný rozmer (horná 600 × 720 → 564 × 684); presne by bolo +9 mm na stranu s drážkou, ale pre V1 **do nárezu plný rozmer skrinky** (šírka × výška od spodku dna po vrch — horná **600 × 720**), dielňa zreže; model ukazuje chrbát v drážke | 26.9. |
| M9 | **Nika spotrebiča pri komíne** | **hĺbka niky sa pri komíne ráta z hĺbky boku**, nie po chrbát — technické listy kótujú min. hĺbku boku (napr. ≥ 550), chladnička zasahuje aj do priestoru komína (nohy sú ponorené hlbšie od zadnej hrany); overené praxou | 27.9. |
| M10 | Ostatné návrhy orchestrátora | výsuvy zásuviek sa pri komíne **skrátia samé** (zamknutý výsuv, ktorý sa nezmestí → RED ako dnes) · stará šablóna bez komína komín skrinky nechá · Inspector **bez nových skupín** · semafor bez nových prahov (varujú dôsledky) · **minimum komína podľa typu chrbta** (v drážke 10 mm + hrúbka chrbta, pri naloženom hrúbka chrbta, inak bez minima) | 26.9. + 27.9. |
| M11 | Mockup | **schválený 27.9.** — riadky v Inspectore, výstupy a karta dielca („Do nárezu 600 × 720" pod Hrúbkou), šablóna; **bokorys v náhľade NIE** (priestor panela) — neskôr lepší 3D náhľad (**D-145**, zásobník) | 27.9. |
| M12 | Mimo bloku | rohové spoje per strana, poldrážka, „bez dielca", K3 rohová, šablóny Rúrová a Drezová, vetranie a výrezy, **rúrové skrinky** (rúra chce iný detail — bez chrbta za rúrou a vetranie, nie komín), bokorys | 6.9. – 27.9. |

## 2 · Dávky bloku

**KON-0 · D-143** (prvá, výrobná chyba) → **KON-A · K1** (komín, zapustenie, D-144) → **KON-B · K2** (chrbát z líšt) → **KON-D** (šablóna Chladničková).
Bokorys (pôvodne KON-C) vypadol (M11). Každá dávka má package v tomto priečinku; audit-povinné dávky (KON-0, A, B, D) prejdú auditom návrhu.

## 3 · Zodpovedané otázky (Michal 27.9.2026)

Rozmery Chladničkovej: 560 / 510, bez chrbta, nika z hĺbky boku (M7, M9) · bokorys nie (M11) · karta dielca „Do nárezu" pod Hrúbkou — áno (M11) ·
samostatné chrbty nepoužíva — starý samostatný chrbát stačí upozorniť · D-144 kombináciu nepoužíva (ostáva v KON-A) · minimum komína podľa typu
chrbta — áno (M10). **Pripomienka:** po KON-0 musí mať aj Lucia hneď novú verziu (jej starší plugin zákazky z Michalovho PC neprestaví ani nevyexportuje — zámer).
