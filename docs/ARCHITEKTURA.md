# ARCHITEKTURA — mapa modulov Noxun Engine

> **Čo to je:** rozcestník referenčnej mapy modulov pluginu — **JEDINÉ miesto, kde architektúra žije**
> (dávkou U3 sem presunutá zo `CLAUDE.md`, 11.8.2026; dávkou „Docs cleanup A" 26.8.2026 rozdelená
> do `docs/architecture/`). Nenačítava sa automaticky.
> **Ako sa číta:** v tabuľkách nižšie nájdi modul, ktorého sa zásah týka, otvor jeho súbor v
> `docs/architecture/` a prečítaj si **JEHO odsek** — každý modul má vlastný nadpis s menom súboru,
> takže Grep podľa mena súboru (`edge_check`, `materials_abs`, `fronts`…) funguje ďalej.
> Kedy je čítanie povinné, hovorí tabuľka „Povinné čítanie podľa typu práce" v [../CLAUDE.md](../CLAUDE.md).
> **Údržba:** dávka, ktorá mení modul, upraví **JEHO odsek na mieste** v príslušnom súbore
> `docs/architecture/` — **nikdy append na koniec**. Nový modul = nový odsek v správnom súbore
> (a nový riadok v tabuľke nižšie).
> Odsek popisuje **kontrakt a pasce** modulu, nie priebeh prác — história dávok patrí do
> [../SYSTEM/archiv/KRONIKA.md](../SYSTEM/archiv/KRONIKA.md).

## Architektúra (v0.5.32)

Reťaz: `noxun_engine.rb` (loader, autorita VERSION) → `noxun_engine\main.rb` (requires, menu, **toolbar**, logger) → core → modules → ui.

## Kde čo nájdeš

| Súbor v `docs/architecture/` | Čo je vnútri |
|---|---|
| [architecture/model-a-identita.md](architecture/model-a-identita.md) | dictionary `NOXUN`, jednotky, identifikátory, identita dielcov, kontrakt plánu, atomický zápis nastavení, knižnica šablón |
| [architecture/construction.md](architecture/construction.md) | plánovač, buildery, strom zón, police a čelá, osi dielca, prekrytia v modeli (`Sketchup::Overlay`), absorpcia scale |
| [architecture/materials.md](architecture/materials.md) | katalóg materiálov a ABS, dekorové skupiny, migrácia a zdravie katalógu, pravidlové ABS defaulty, Demos konektor |
| [architecture/hardware.md](architecture/hardware.md) | pravidlá kovania, katalóg položiek, sety |
| [architecture/outputs.md](architecture/outputs.md) | kontrolný semafor, zdieľané jadro výstupov zákazky (kusovník, VEPO, nákup, rozpočet, ceny, exporty) |
| [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) | Inspector (kostra, kontexty, karty), Štúdio (okno a sekcie), zdieľané JS komponenty, lifecycle okien |

Ďalej v `docs/`: pravidlá SketchUp kódu [SKETCHUP_PRAVIDLA.md](SKETCHUP_PRAVIDLA.md) ·
DC pasce [DC_PRAVIDLA.md](DC_PRAVIDLA.md) · UI dizajn [UI_DIZAJN.md](UI_DIZAJN.md).

### Core (`noxun_engine/core/`)

| Modul | Odsek žije v |
|---|---|
| `units` · `ids` · `store` · `part_keys` · `build_plan` · `doc_key` | [architecture/model-a-identita.md](architecture/model-a-identita.md) |
| `json_file_store` · `dim_series` · `debug` | [architecture/model-a-identita.md](architecture/model-a-identita.md) |
| `templates` · `template_usage` · `template_previews` | [architecture/model-a-identita.md](architecture/model-a-identita.md) |
| `construction` · `cabinet_builder` · `board_builder` · `placement` · `zones` · `zone_tree` · `tags` | [architecture/construction.md](architecture/construction.md) |
| `ghost_tool` (GHOST vkladanie na klik — SketchUp `Tool` + placement session) | [architecture/construction.md](architecture/construction.md) |
| `front_profiles` · `part_faces` | [architecture/construction.md](architecture/construction.md) |
| `edge_check` · `edge_overlay` · `grain_check` · `direction_check` · `hover_edge` | [architecture/construction.md](architecture/construction.md) |
| `scale_observer` | [architecture/construction.md](architecture/construction.md) |
| `materials` a celý split (`materials_catalog` · `materials_decor` · `materials_abs` · `materials_demos_create` · `materials_project` · `materials_replace_uni`) | [architecture/materials.md](architecture/materials.md) |
| `materials_migration` · `materials_health` · `abs_rules` | [architecture/materials.md](architecture/materials.md) |
| `demos/` (`client` · `slug_matcher` · `name_search` · `product_parser` · `family` · `lookup` · `sitemap_cache` · `image_cache`) | [architecture/materials.md](architecture/materials.md) |
| `hardware_rules` · `hardware_catalog` · `hardware_taxonomy` · `hardware_sets` | [architecture/hardware.md](architecture/hardware.md) |
| `validation` · `bom` · `budget` · `budget_store` · `sheet_estimate` | [architecture/outputs.md](architecture/outputs.md) |
| `price_refresh` · `supplier_settings` · `vepo_export` · `cp_export` · `xlsx_writer` | [architecture/outputs.md](architecture/outputs.md) |
| `usage_stats` | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| `updater` (D-52a jadro — manifest, staging, swap, zámok/lease, restart latch; recovery žije v loaderi · D-52b UI — sekcia „O plugine": asynchrónny check s tokenom, bariéra zatvorenia okien, natívne hlášky) | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |

### Modules (`noxun_engine/modules/`)

| Modul | Odsek žije v |
|---|---|
| `shelves` · `fronts` | [architecture/construction.md](architecture/construction.md) |

### Nástroje (`noxun_engine/tools/`)

| Modul | Odsek žije v |
|---|---|
| `tools` (registrátor toolbaru „Noxun Nástroje" + spoločná vrstva: preflight, bariéra, mutácia) | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| `mower_calc` · `snap_calc` (čisté jadrá — posun, názov kópie, AABB sweep) | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| `mower` (rotácie, Z, kópia cez šev enginu, Z-dialog) · `snaper` (prisunutie na doraz, viditeľnosť) | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |

### UI — Inspector + satelity (`noxun_engine/ui/`, V0.4.5+)

| Modul / oblasť | Odsek žije v |
|---|---|
| `panel.rb` (Inspector — centrálne callbacky) + `panel.css` + `ui/js/*.js` | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| domény panela (`ui/panel/*.rb`): `payloads.rb` · `resolvers.rb` · `selection.rb` · `sync.rb` · `actions_board.rb` · `actions_cabinet.rb` · `actions_hardware.rb` · `actions_materials.rb` · `actions_parts.rb` · `actions_settings.rb` · `actions_templates.rb` · `actions_usage.rb` · `actions_zones.rb` | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| `studio_dialog.rb` + `ui/studio.html` + `ui/js/studio.js` (okno ŠTÚDIO a jeho sekcie) | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| zdieľané JS komponenty (`nx_combo.js` · `nx_modal.js` · `edge_menu.js` · `win_fit.js`), téma, toolbar, lifecycle okien | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |
| `production_core.rb` (`ui/production_core.rb`) — čisté jadro výstupov zákazky | [architecture/outputs.md](architecture/outputs.md) |
| moduly bez vlastného okna: `materials_dialog.rb` · `hardware_catalog_dialog.rb` · `rules_dialog.rb` · `templates_dialog.rb` · `supplier_settings_dialog.rb` | [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md) |

### Kľúčové invarianty

- Dáta na inštancii v `NOXUN` dictionary (config = JSON string, mm Float).
- Rebuild = 1 undo operácia s `@rebuilding` guardom; observer reakcie na krok používateľa
  = transparentné operácie (absorpcia scale, dedup kópie, ghost presuny).
- Recyklácia definícií podľa mena; žiadne DC vzorce.
- Plán musí prejsť `BuildPlan.validate!`.
- Kovanie sa NIKDY nečíta z geometrie (proxy) — ale z `config.hardware[]`.
- Zásahy do modelu z dialógov vždy cez guardy (baseline/typ/hrúbka) — HTML disabled nie je ochrana.
- Autorita výrobného záznamu = snapshot na entite (štandard 8.3).

**Trvalé UI pravidlo (Michal 20.7.2026): VERTIKÁLNY priestor panela je vzácny** — plné znenie je
v [architecture/ui-lifecycle.md](architecture/ui-lifecycle.md), sekcia „Ostatné".
