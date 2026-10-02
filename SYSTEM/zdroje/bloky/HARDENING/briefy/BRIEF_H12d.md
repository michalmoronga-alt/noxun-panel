# Brief — dávka H12d · mená rolí na jednom mieste (C-05) — blok 9 HARDENING

Si implementátor dávky **H12d** (posledná časť H12). Pracuj z **čerstvého `origin/main`** (`108c808c`, v0.17.15; obsahuje H12a–c, H13 mapu
rozširovacích bodov, H14a/b). Vetva **`refactor/h12d-mena-roli`**, verzia **0.17.16**.

## Zdroj (autorita v tomto poradí)
1. `SYSTEM/zdroje/bloky/HARDENING/PACKAGE_H12.md` — **§15 má prednosť** (A3 golden nákupu platí po každom reze, **A5 = H12d je audit-povinná a
   predrecenzia povinná bez ohľadu na veľkosť**, A6 fotky). Pre H12d: §0.3 (výrobné mená a vlastnosti rolí — NEMENIA sa), **R0.6** (charakterizácia
   mien rolí PRED zásahom), **R4.1–R4.4**, guard T3f („žiadna JS mapa mien rolí, `ROLE_LABELS` pokrýva roly"), mutácia **M16**, §10 smoke bod 6, §11 docs
   (`outputs.md` odsek s tvrdením o zhode JS mapy, `model-a-identita.md` odsek `part_keys`), §14 **F1** (opraviť nepravdivé tvrdenie v `outputs.md`).
   Čísla riadkov v package sú z 1.10. ráno — **over Grepom proti aktuálnemu mainu** (H12a–c, H13, H14 kód posunuli).
2. **Q1 (názvy v karte dielca podľa Kusovníka) = ÁNO** — Michal neodpovedal, platí predvolená voľba zo zhrnutia 1.10. („Strop", „Zvislá priečka",
   „Vodorovná priečka", „Čelo zásuvky"; dno zásuvky a voľná doska už nie surový kód `drawer_bottom`). Kusovník, VEPO, nákup ani rozpočet sa nemenia.
3. Mapa `docs/architecture/rozsirovacie-body.md` (H13) — **scenár 2 „nová rola"** dnes menuje JS `roleLabel` a `ROLE_LABELS` v `ProductionCore`;
   po H12d ho prepíš na nový stav (`PartKeys::ROLE_LABELS` + `role_label` v payloade karty). Guard kvalifikovaných mien z H13 to vynúti — ak padne, oprav mapu,
   nie guard.

## Čo spraviť (zhrnutie — detail v package)
- **1. commit = charakterizácia R0.6 na nezmenenom kóde** (golden mien rolí: `ProductionCore.role_label` pre všetky `BuildPlan::ROLES` + neznámu,
  `rows_with_roles` nad fixtúrou, `RulesDialog.abs_role_label`, `PartKeys.human_label` vzorky, `board_payload['role_label']`, dnešné JS `roleLabel`
  vrátane 9 rozdielov dokumentačne). Golden T0 z H12a (`tests/fixtures/h12_golden/`) sa **neregeneruje** — po H12d musí platiť bajtovo.
- R4.1 `PartKeys::ROLE_LABELS` (doslovne dnešné `ProductionCore::ROLE_LABELS`) + `PartKeys.role_label`; `ProductionCore` deleguje (konzumenti a testy bez zmeny).
- R4.2 `ZONE_PART_LABELS`, `DRAWER_PART_LABELS` odvodené (bajtovo rovnaké); `Panel::BOARD_ROLE_LABELS` zanikne.
- R4.3 `part_card_payload` (+ `board_payload`, ak ho karta číta) nesie `role_label`; `part_card.js` použije `pc.role_label || pc.role`; JS mapa
  `roleLabel` zanikne. **Over** `bridge.js` `nxTempLabel` (`sel.role`) — či `sel` je vždy payload karty; ak nie, doplň kľúč aj tam.
- R4.4 výrobné mená, `Recipes.role_label`, `rdRoleDesc`, `corner_preview_title`, `VepoExport::SHORT_NAMES` **bez zmeny**; guard T3f.
- Mutácie (aspoň M16 + vlastné: rola bez mena, JS mapa späť, výrobné meno zmenené) — každá musí zhodiť test.

## Testy, fotky, uzáver
- `ruby tests/run_all.rb` zelené, **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`), encoding guard.
- In-SU **nie je brána** (žiadny builder, observer, undo ani akcia zapisujúca do modelu) — ak by si menil čokoľvek z toho, STOP a otázka.
- **Fotky (A6):** zmena Ruby payloadu → `powershell -NoProfile -File scripts\ui_foto.ps1 -Record` (nová nahrávka; `exit 2` = iný beh drží zámok →
  počkaj a skús znova), potom over na fotke kontextu s kartou dielca, že názov roly je z Kusovníka. Cesty k fotkám do reportu (do gitu nie).
- Checklist uzáveru podľa CLAUDE.md: VERSION 2× + všetky `?v=` = 0.17.16 · docs odseky na mieste (`outputs.md`, `model-a-identita.md` `part_keys`,
  `ui-lifecycle.md` karta dielca, `rozsirovacie-body.md` scenár 2) · Grep tvrdení o mapách mien rolí · STAV prepísať (max 80 riadkov — prepisuj, nepridávaj)
  · KRONIKA odsek navrch · PLAN riadok H12 → H12d ✅ + `PR #?`.
- Skopíruj tento brief do `SYSTEM/zdroje/bloky/HARDENING/briefy/BRIEF_H12d.md`.
- **Predrecenzia je povinná (A5)** → po pushi vetvy **STOP, PR NEOTVÁRAJ**; vráť report: hlava, riadky kódu (bez testov/docs), počty testov, mutácie,
  cesty k fotkám, čo si overil v `nxTempLabel`. PR otvoríš až na pokyn orchestrátora po predrecenzii. **Nemerguj.**
