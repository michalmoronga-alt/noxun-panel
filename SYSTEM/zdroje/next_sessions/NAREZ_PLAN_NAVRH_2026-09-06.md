# Nárezový plán (primitívny, V1) — návrh rozsahu NP-1 / NP-2 (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (rozhodnutie v [V1_DEBATA_2026-09-06_KONTROLA_VYROBA.md](V1_DEBATA_2026-09-06_KONTROLA_VYROBA.md) §0)
> + Codex #322 kolá 1–3 (nálezy zapracované, §7) · auditované proti kódu: ČIASTOČNE (`SheetEstimate` kontrakt D-19 vrátane duplákov, `sheet_size` z katalógu, K1 `grain_direction`) ·
> task package vznikne po `codex-audit` tohto návrhu (nový modul).
>
> Pred implementáciou platí postup z [README.md](README.md).

## 0 · Prečo (Michal 6.9.)

Dnes je počet platní len **odhad z m²** (`SheetEstimate`, koeficient prerezu 10–25 %, D-19); realita je iná. Po aspoň primitívnom pláne vieme, koľko platní **najviac** treba
(horná hranica podľa zvoleného rozloženia), a keď „1 diel vychádza na celú platňu a musím objednať 2", dá sa na to pozrieť a niečo vymyslieť. **Rezanie robí VEPO** — plán je
pre objednávku a rozhodovanie, nie výrobný dokument.

## 1 · Vstup

- **BOM riadky** presne ako `SheetEstimate.estimate` (rozmery, počty, `material_id`, `material_source` dupláku) + formát platne z katalógu (`sheet_size`, fallback 2800 × 2070
  s príznakom `fallback`, nikdy delenie nulou — D-19 F4).
- **Duplák (Codex #322 kolo 3 P1):** riadok s `material_source.multiplier` 2 alebo 3 sa **pred rozkladom rozvinie** na `množstvo × multiplier` fyzických obdĺžnikov
  **zdrojového materiálu** (kupuje sa zdroj — rovnaký kontrakt, akým `SheetEstimate` násobí plochu, `sheet_estimate.rb:27-35`); duplák sa nikdy neobjaví ako vlastná platňa.
- **Smer dekoru dielca:** K1 `grain_direction` override / vlastnosť materiálu. **Najprv normalizácia orientácie** (Codex #323 P1 — rovnako ako `VepoExport.oriented` a
  `Validation.fits_on_sheet?`, presne raz): `length`/`width` sú geometrické rozmery; pri `grain_direction: "width"` beží kresba po šírke, preto sa dvojica **raz vymení**, aby
  kresba dielca bežala **po dĺžke platne** (pozdĺž smeru dekoru platne z katalógu). Až po normalizácii platí: dielec so smerom sa **neotáča**. **Dielec bez smeru** (materiál bez smeru) sa smie otočiť o 90°
  podľa **pevného pravidla**: najprv orientácia „dlhšia strana rovnobežne s dĺžkou platne", ak sa nezmestí do aktuálnej police, skúsi sa druhá; berie sa prvá, ktorá sa zmestí —
  žiadne hľadanie najlepšej.
- **Kerf** (default 4 mm) a **orez okraja platne** (default 10 mm) — parametre projektu (Nastavenia rozpočtu), snapshot v pláne.
- ABS ani prídavky na obrábanie do plánu nevstupujú (rozmery = výrobné rozmery BOM).

## 2 · Algoritmus (čisté Ruby, headless testovateľné)

Vlastná **shelf / guillotine heuristika** (OpenCutList je GPL — algoritmus áno, kód nie): dielce zoradiť podľa výšky (potom šírky) zostupne, plniť police zľava doprava, nová
polica pod poslednou, nová platňa keď sa nezmestí; kerf medzi dielcami aj policami; dielec väčší než platňa (po oreze) = **RED** riadok (nedá sa vyrobiť z tohto formátu), plán
pokračuje bez neho. **Deterministický** (rovnaký vstup = rovnaký plán, žiadne náhodné poradie), **bez optimalizačných slučiek** — KLINIKA (254 dielcov) pod sekundu.

## 3 · Výstup (kontrakt výsledku)

Per nákupný materiál: **`sheets` = počet platní = HORNÁ HRANICA podľa zvoleného rozloženia** (nie optimum — iné platné rozloženie môže vyjsť lepšie; nesmie sa vydávať za
presné množstvo), využitie % (plocha dielcov / plocha platní), zoznam dielcov per platňa (id, rozmer, poloha, otočený áno/nie), **najväčší zvyšok** per platňa, príznaky
(`fallback` formát, `red` dielce). Plus **jednoduchý obrázok** rozloženia (SVG v Štúdiu, sekcia **Nárezový plán** — dnes neaktívna položka navigácie, kontrakt D-19 pripravený).

## 4 · Napojenie na rozpočet

Sekcia „Materiály po tabuliach" ukáže **vedľa** odhadu rozsahu (`count_min–count_max`) hodnotu **„plán: N platní (horná hranica)"**. Odhad ostáva **default** pre cenu; napojenie
cien za celé tabule (D-61) na plán = **voľba používateľa** (prepínač „ceny podľa plánu"), nie automatika. Objednáva človek.

## 5 · Scope OUT

Optimalizácia na minimum odpadu (viac heuristík, hľadanie najlepšieho rozloženia či poradia dielcov — preto je výsledok horná hranica) · tlač / export plánu pre pílu · ručné
presúvanie dielcov v pláne · zvyšky ako sklad · ABS v pláne · dĺžkové materiály (`per:'length'`).

## 6 · Rezy, testy, DoD

| Rez | Obsah | Audit |
|---|---|---|
| **NP-1 algoritmus** | modul `core/cut_plan.rb` (čistý), kontrakt výsledku §3, rozvinutie duplákov, politika otáčania, kerf/orez, RED; headless: determinizmus · duplák ×2/×3 dáva správny počet obdĺžnikov zdroja · dielec so smerom sa neotočí · dielec bez smeru sa otočí podľa pravidla · kerf mení počet platní na hrane · oversize = RED · `fallback` formát · **vlastnosť horná hranica** (Codex #323 P1: `count_max` z odhadu NIE JE hranica — je to zlomkový odhad plochy s koeficientom, pre malý dielec vyjde 0,1 platne): plán ≥ **dolná hranica** `ceil(Σ plocha dielcov / plocha platne po oreze)` a plán ≤ počet platní **ručne zostrojeného platného rozloženia** tej istej fixtúry (dokázateľne uskutočniteľná hranica); mutácie min. 4 | **ÁNO** (nový modul) |
| **NP-2 sekcia + rozpočet** | Štúdio → Nárezový plán (SVG per platňa, zoznam, príznaky), riadok v rozpočte, prepínač „ceny podľa plánu"; **kerf, orez a prepínač = nové polia `BudgetStore`** (uzavretý whitelist, `BUDGET_STD`): **bump štandardu + dopredná brána** (starší plugin polia neoreže a nepočíta inú cenu) + atomická mutácia modelu (jeden Undo); in-SU smoke KLINIKA (počty vs. reálne objednané platne, čas, reopen zachová polia) | **ÁNO** (schéma rozpočtu — Codex #323 P1), potom `codex-po-pr` |

## 7 · Nálezy Codex #322 zapracované

#322 kolo 1 P1: heuristika ≠ presné množstvo → **horná hranica**, rozpočet informatívne, objednáva človek · #322 kolo 2 P2: jedna politika otáčania dielcov bez smeru (§1) ·
#322 kolo 3 P1: duplák sa rozvinie na `množstvo × multiplier` obdĺžnikov zdroja pred rozkladom (§1) + vlastný test · **#323 kolo 1 P1:** normalizácia orientácie pri
`grain_direction: "width"` pred rozkladom (§1) · `count_max` nie je hranica → test proti dolnej hranici z plochy a ručne zostrojenému rozloženiu (§6) · NP-2 = zmena schémy
rozpočtu (`BudgetStore`, `BUDGET_STD`) → audit ÁNO (§6).
