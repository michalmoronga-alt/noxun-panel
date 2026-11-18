---
paths:
  - "noxun_engine/core/vepo_export.rb"
  - "noxun_engine/core/bom.rb"
  - "noxun_engine/core/cp_export.rb"
  - "noxun_engine/core/xlsx_writer.rb"
  - "noxun_engine/core/validation.rb"
  - "noxun_engine/core/build_plan.rb"
  - "noxun_engine/core/part_keys.rb"
  - "noxun_engine/core/budget*.rb"
  - "noxun_engine/core/sheet_*.rb"
  - "noxun_engine/core/export_settings.rb"
  - "noxun_engine/core/price_refresh.rb"
  - "noxun_engine/core/supplier_settings.rb"
  - "noxun_engine/core/hardware_sets.rb"
  - "noxun_engine/ui/studio_dialog.rb"
  - "noxun_engine/ui/production_core.rb"
  - "noxun_engine/ui/export_prep.rb"
  - "scripts/export_test.ps1"
  - "scripts/export_compare.rb"
  - "tests/sketchup/su_export_probe.rb"
---

# Oblasť: výstupy — VEPO, kusovník, nákup, CSV/XLSX

> Načíta sa samo pri práci so súbormi výstupov ([POVINNE_CITANIE.md](../../SYSTEM/pravidla/POVINNE_CITANIE.md)). Zmena generátora
> exportu (`*_csv`, `*_xlsx`, VEPO) v súbore mimo `paths:` → prečítaj tento súbor sám.

**Pred prácou POVINNE prečítaj:**

- [SYSTEM/VEPO_KONTRAKT.md](../../SYSTEM/VEPO_KONTRAKT.md),
- odseky `validation`, `production_core` a dotknutého výstupu v [docs/architecture/outputs.md](../../docs/architecture/outputs.md)
  (Grep `^### <modul>`; celý má 163 kB),
- odseky `build_plan`, `part_keys` v [docs/architecture/model-a-identita.md](../../docs/architecture/model-a-identita.md),
- [SYSTEM/STANDARD.md](../../SYSTEM/STANDARD.md) §8 a §11.

**Export test je brána mergu** dávky, ktorá mení VEPO, CSV kovania, XLSX rozpočtu či ponuky alebo ich cestu: po zmene exportu
`powershell -NoProfile -File scripts\export_test.ps1` musí dať `P == K`, resp. len **vedomé rozdiely uvedené v PR**.
Povolené rozdiely, exit kódy a zámok: [NASTROJE_TESTOV.md, Export test](../../SYSTEM/pravidla/NASTROJE_TESTOV.md#export).
