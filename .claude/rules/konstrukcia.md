---
paths:
  - "noxun_engine/core/cabinet_builder.rb"
  - "noxun_engine/core/board_builder.rb"
  - "noxun_engine/core/construction.rb"
  - "noxun_engine/core/cabinet_types.rb"
  - "noxun_engine/core/zone_tree.rb"
  - "noxun_engine/core/zones.rb"
  - "noxun_engine/core/scale_observer.rb"
  - "noxun_engine/core/placement.rb"
  - "noxun_engine/core/front_profiles.rb"
  - "noxun_engine/core/part_faces.rb"
  - "noxun_engine/core/ghost_tool.rb"
  - "noxun_engine/core/tags.rb"
  - "noxun_engine/core/edge_check.rb"
  - "noxun_engine/core/grain_check.rb"
  - "noxun_engine/core/direction_check.rb"
  - "noxun_engine/core/hover_edge.rb"
  - "noxun_engine/core/edge_overlay.rb"
  - "noxun_engine/core/app_lifecycle.rb"
  - "noxun_engine/core/appliance_binding.rb"
  - "noxun_engine/core/appliance_checks.rb"
  - "noxun_engine/core/budget_store.rb"
  - "noxun_engine/core/materials_apply_appearance.rb"
  - "noxun_engine/core/materials_native_appearance.rb"
  - "noxun_engine/core/template_previews.rb"
  - "noxun_engine/main.rb"
  - "noxun_engine/ui/hardware_catalog_dialog.rb"
  - "noxun_engine/ui/materials_dialog.rb"
  - "noxun_engine/ui/rules_dialog.rb"
  - "noxun_engine/ui/studio_dialog.rb"
  - "noxun_engine/ui/panel/selection.rb"
  - "noxun_engine/modules/**"
  - "noxun_engine/tools/**"
  - "noxun_engine/data/recipes/**"
  - "noxun_engine/ui/panel/actions_*.rb"
---

# Oblasť: buildery · observery · undo · geometria

> Načíta sa samo pri práci s buildermi, observermi (`Sketchup::*Observer`) a kódom s operáciou `start_operation`, ktoré zapisujú do modelu
> ([POVINNE_CITANIE.md](../../SYSTEM/pravidla/POVINNE_CITANIE.md)). Práca s observerom alebo operáciou v súbore mimo `paths:` →
> prečítaj tento súbor sám (`git grep -lE "Sketchup::[A-Za-z]*Observer|add_observer|start_operation" -- noxun_engine`).

**Pred prácou POVINNE prečítaj:**

- odseky `construction`, `cabinet_builder`, `board_builder`, `zone_tree`, `scale_observer` (a dotknutého modulu)
  v [docs/architecture/construction.md](../../docs/architecture/construction.md) (Grep `^### <modul>`; celý má 174 kB),
- [docs/SKETCHUP_PRAVIDLA.md](../../docs/SKETCHUP_PRAVIDLA.md),
- [SYSTEM/STANDARD.md](../../SYSTEM/STANDARD.md) §3, §4, §9.

**In-SU test je tu brána mergu** (spúšťače: [DEFINICIE § D6](../../SYSTEM/pravidla/DEFINICIE.md#d6); runner:
[IMPLEMENTATOR.md, sekcia Testovanie](../../SYSTEM/pravidla/roly/IMPLEMENTATOR.md#testovanie), podrobnosti
v [testy.md](testy.md)). Headless sada geometriu ani undo neoverí.
