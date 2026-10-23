# Hliadka výroby 2026-10-23 · materiály, ABS a hrany

- Oblasť: Pi — materiály, ABS, hrany (STANDARD §7.5)
- Prečítané: SYSTEM/STANDARD.md §7.5, core/abs_rules.rb, core/materials_abs.rb, core/materials_project.rb, časti core/materials.rb (ceny, `supported_edge_thickness?`, `abs_default_suppression`), core/materials_decor.rb (`ensure_edge_for_sheet`), core/materials_catalog.rb (`validate_price`), core/edge_check.rb (úvod + `classify_edges`)
- run_all: `ruby tests/run_all.rb` → 5419 passed, 0 failed, 7 skipped (nutné `LANG=C.UTF-8`; pod predvoleným US-ASCII locale padá už `tests/helper.rb:33` na `File.read` — vlastnosť prostredia hliadky, nie kódu)

## Nálezy
Žiadne.

## Podozrenia
Žiadne dokázateľné.

## Skontrolované bez nálezu
- Resolver hrúbky ABS (jednotka 0,8→1,0→1,2; dvojka 2,0→1,5; 0,4 nikdy automaticky) zodpovedá §7.5.
- Výber šírky pásky: najmenšia ≥ hrúbka+2 → univerzálna → nič; nikdy užšia (`pick_edge_variant`, `edge_fits_width?`, `auto_width_for`).
- Hierarchia štruktúry: dve prázdne štruktúry nie sú zhoda; `universal` ako samostatná vetva.
- `remap_edges_v2`: 0,4 → `abs_04_manual`, cudzia skupina/štruktúra sa nemení.
- SEED_RULES pokrývajú všetky sheet roly v builderoch (rozdiel len nepanelové roly cabinet/zone/leg/handle/appliance_*).
- Mapa L1/L2/W1/W2 ↔ EDGE_LABELS ↔ EDGE_SIDES konzistentná so STANDING_ROLES.
- Ceny: `validate_price`/`normalize_price` rozlišujú nezadanú cenu od 0, necislo sa odmieta (nie ticha 0); `plate_to_m2` bez platného formátu vráti nil.
- `edge_check.classify_edges`: preskok UNI/KOMPAKT/PD postforming, násobenie quantity.
