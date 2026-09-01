# KOVANIE — technical audit checkpoint 2026-09-01 #09

Working delta checkpoint. NOT implementation spec. Continues #08.

## Quadro V6 EB23 — newly closed production decisions

- V1 load class: 30 kg standard only. No higher-load Quadro branch required unless a concrete production need appears later.
- V1 nominal lengths: support the complete relevant catalogue NL set for the selected Quadro V6 EB23 profile.
- NL resolver behavior: choose the longest technically compatible NL from actual available depth; manual NL override remains available.

## Quadro wooden-box height — context-driven proposal

User decision: automatic proposal + manual override.

- Proposed box height should come from the **real available internal vertical space**, not merely from drawer-front height.
- Noxun V1 default proposal: `box_height ~= available_height - 40 mm`.
- `40 mm` is a **Noxun default clearance / recipe parameter**, not an official Hettich constant and not an immutable architecture rule.
- The larger 40 mm default is intentionally conservative and should cover many common obstruction cases involving partitions/dividers, cabinet top, cabinet bottom and similar geometry.
- Manual box-height override is required.
- Critical obstructions are real cabinet/context geometry such as internal partitions/dividers, cabinet top and cabinet bottom. These can reduce usable space while the front itself does not know about the obstruction.
- For very shallow/narrow or otherwise atypical drawer sectors, the user can visually inspect the generated geometry and manually correct the proposed height.
- V1 does not need perfect collision intelligence. Better automatic collision/context reasoning can be added later.
- Future drawer systems (for example TANDEM) may use a different default clearance without changing the architecture; keep the clearance system/recipe-data driven.

## Architectural implication

This strengthens the existing slim-V1 direction:

`OWNER (front) -> context_for(owner) -> drawer recipe`

The front remains the owner, while usable drawer space is computed from surrounding geometry/context. No persistent FunctionalZone object is required merely to calculate drawer height.

Do not lock derived-part identity from this checkpoint; C10 remains AUDIT FIRST.

## Evidence status

- Quadro 30 kg-only V1 load class: user-confirmed 2026-09-01.
- Complete relevant Quadro V6 EB23 NL coverage + longest-compatible automatic selection + manual override: user-confirmed 2026-09-01.
- Context-driven box-height proposal + manual override + manual visual check for difficult obstruction cases: user-confirmed 2026-09-01.
- Quadro V1 Noxun default height clearance = `40 mm`; defined as recipe/data default rather than an official Hettich constant: user-confirmed 2026-09-01.
