# Noxun Engine — pravidlá práce v repe

SketchUp Ruby plugin — parametrický nábytkársky systém (korpusy, zóny, čelá, neskôr materiály/ABS/kovanie/výstupy).
GitHub: https://github.com/michalmoronga-alt/noxun-panel

## Git workflow (záväzné od 16.7.2026)

- **Žiadne priame commity do `main`.** Každá zmena: **vetva → commity → PR → Codex auto-review → merge robí Michal** po kontrole.
- Vetvy pomenúvať `feat/<krátky-popis>`, `fix/<popis>`, `docs/<popis>` (napr. `feat/v03-materialy`).
- PR popis po slovensky: čo sa mení z pohľadu používateľa + ako testované (SkAgent/MCP výsledky). Malé PR > obrie PR — deliť po celkoch.
- Commit messages: vecné, slovensky/anglicky konzistentne s históriou, trailer `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`.
- Paralelné úlohy: každá vo vlastnej vetve (agenti: worktree izolácia), konflikty rieši integrácia pred PR.

## Špecifikácia a kontext (všetko v tomto repe)

- **Záväzný štandard dát:** [SYSTEM/01_STANDARD_draft.md](SYSTEM/01_STANDARD_draft.md) (dictionary NOXUN, mm Float, roly, regenerate pattern)
- **Roadmapa a backlog postrehov:** [SYSTEM/04_ROADMAP.md](SYSTEM/04_ROADMAP.md) · UI vízia: [SYSTEM/07_UI_VIZIA.md](SYSTEM/07_UI_VIZIA.md)
- **Pravidlá SketchUp kódu:** [docs/SKETCHUP_PRAVIDLA.md](docs/SKETCHUP_PRAVIDLA.md) · DC pasce: [docs/DC_PRAVIDLA.md](docs/DC_PRAVIDLA.md) (+ `..\CLAUDE.md` — konvencie rodiny Noxun v workspace)

## Testovanie (záväzné pravidlá)

- Kanál: MCP `mcp__vbo-sketchup__execute_ruby` (SketchUp 2026 + VBO SkAgent, port 7891); fallback file-bridge (`vbo_sk_agent\bridge\command.rb` → `result.json`, pozor na mtime pascu). Deploy: `INSTALL_noxun_engine.ps1`.
- **Testuje sa VÝHRADNE v testovacom projekte `_dev\ENGINEtests.skp`** (alebo neuloženom Untitled okne) — v ňom môžu agenti tvoriť/mazať čokoľvek. `_dev/` je gitignorované.
- **NIKDY netestovať v okne so zákazkou** — pred testami vždy overiť `model.path`/titul okna (bridge vykonáva príkazy v každom okne, kde je zapnutý — bridge zapínať len v testovacom okne).

## Architektúra (V0.2)

`noxun_engine.rb` loader → `noxun_engine\main.rb` → core (units — JEDINÉ miesto mm↔Length; ids; store — NOXUN dict; construction — plánovač cfg→dielce; cabinet_builder — regenerate; zone_tree — strom zón+priečky; zones — ghost boxy; scale_observer=ScaleWatch — absorpcia scale; templates) → modules (shelves, fronts — čelá fixed/auto s lockmi) → ui (panel.rb + panel.html).

Kľúčové invarianty: dáta na inštancii v `NOXUN` dictionary (config = JSON string, mm Float); rebuild = 1 undo operácia s `@rebuilding` guardom; recyklácia definícií podľa mena; žiadne DC vzorce.
