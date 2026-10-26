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
  - "noxun_engine/modules/**"
  - "noxun_engine/tools/**"
  - "noxun_engine/data/recipes/**"
  - "noxun_engine/ui/panel/actions_*.rb"
---

# Oblasť: buildery · observery · undo · geometria

> Načíta sa samo pri práci s buildermi, observermi a akciami panela, ktoré zapisujú do modelu
> ([POVINNE_CITANIE.md](../../SYSTEM/pravidla/POVINNE_CITANIE.md)).

**Pred prácou POVINNE prečítaj:**

- odseky `construction`, `cabinet_builder`, `board_builder`, `zone_tree`, `scale_observer` (a dotknutého modulu)
  v [docs/architecture/construction.md](../../docs/architecture/construction.md) (Grep `^### <modul>`; celý má 174 kB),
- [docs/SKETCHUP_PRAVIDLA.md](../../docs/SKETCHUP_PRAVIDLA.md),
- [SYSTEM/STANDARD.md](../../SYSTEM/STANDARD.md) §3, §4, §9.

**In-SU test je tu brána mergu** (spúšťače: [DEFINICIE § D6](../../SYSTEM/pravidla/DEFINICIE.md#d6); runner:
[IMPLEMENTATOR.md, sekcia Testovanie](../../SYSTEM/pravidla/roly/IMPLEMENTATOR.md#testovanie), podrobnosti
v [testy.md](testy.md)). Headless sada geometriu ani undo neoverí.
