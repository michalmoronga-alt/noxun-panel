# KOVANIE V1 — CROSS-AUDIT SOURCE PACK (2026-09-01)

> **Status:** neutral audit input. This pack is IDENTICAL for all independent auditors.
> It contains NO conclusions from any other auditor. It distinguishes facts from proposals.
> **Your mission is to BREAK the proposed architecture, not to redesign the system.**

## 0. Source discipline (mandatory tagging)

Tag every material claim in your findings as one of:

- **VERIFIED REPO FACT** — you verified it in the repository yourself (cite file/symbol),
- **USER-CONFIRMED PRODUCTION RULE** — business/production decision by the owner (listed in §2/§3; do not overturn, only flag conflicts),
- **VERIFIED OFFICIAL VENDOR FACT** — from checkpoint #10 matrix with OFFICIAL/SECONDARY tag,
- **ARCHITECTURAL PROPOSAL** — part of the Round 2 proposal under audit (§5),
- **UNCONFIRMED DATA** — anything else. Never promote UNCONFIRMED to fact.

Vendor values tagged UNCONFIRMED in checkpoint #10 stay UNCONFIRMED. The PDF follow-up
list is NOT a blocker unless a missing number changes the architecture itself.

## 1. Problem statement

Noxun Engine is a SketchUp Ruby plugin generating custom furniture (cabinets, fronts,
zones, materials/ABS edging, hardware, production outputs: cut list/BOM, VEPO order CSV,
hardware purchase CSV, budget/quote XLSX). Real production orders run through it since
2026-08-20 — wrong dimensions or wrong purchase = real money.

The V1 hardware block must: classify fronts, resolve correct repeatable drawer/lift/hinge
hardware, compute quantities, emit drawer manufactured parts (bottom/rear/wooden box),
react safely to geometry changes, keep old projects reproducible, and produce a
trustworthy purchase/BOM output with provenance. It must NOT become a generic PLM.

Repository: https://github.com/michalmoronga-alt/noxun-panel (branch `main`).

## 2. Closed user decisions (USER-CONFIRMED — respect as constraints)

From debate checkpoints `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01*.md`
and `KOVANIE_TECHNICAL_AUDIT_CHECKPOINT_2026-09-01_{08,09}.md`:

- Front types: Dvierka · Zásuvkové čelo · Výklop · Sklop · Blenda (fixed panel, no hardware).
- Independent opening-mode axis: Classic vs Tip-On/Push-to-open (not handle type).
- Drawer construction axis: wooden box/concealed runner · metal sides · other/atyp
  (other = manual set + qty, no generated parts). `drawer_variant = standard | internal`
  (internal classified only in V1).
- Default set hierarchy: global company default → project override → per-front override.
- Mandatory set classification (use/opening/drawer construction/manufacturer/series),
  controlled lists with `+ Create`, auto-suggested editable set name.
- Sets keep ONE opening-mode classification; catalog components may be shared.
- V1 lifts: **HK + HL**; **HF is OUT of V1** (two-front assembly), must be solvable via
  ad-hoc hardware.
- V1 drawer archetypes: **Atira + Quadro** as archetypes of two computational families
  (METAL_BOX_DRAWER: Atira → later StrongBox/Antaro · WOOD_DRAWER_UNDERMOUNT: Quadro →
  later TANDEM).
- No recipe editor UI in V1 — recipes are audited, versioned technical DATA in the repo.
- Config memory: automatic restore + revalidation on front-type switch back, NO dialog.
- Set lifecycle: Active/Inactive + project snapshot + "newer version available" info.
  No Deprecated state, no immutable revision chains.
- OWNER = existing real front/part. CONTEXT is computed, not persistent. No first-class
  assembly owner in V1. No persistent FunctionalZone objects.
- Locks = existing `hardware_overrides` fields extended per axis (manual value = lock).
- Resolver never changes state silently; no silent fallback on incompatible set; owner
  without compatible set stays a HARD conflict with explanation.
- Validation reuses existing Kontrola (ORANGE/RED) + existing final/export gates. No
  parallel validation framework.
- Compositional axes + recipe — NO Cartesian variant records.
- Ad-hoc hardware belongs EARLY in V1 (controlled escape hatch with owner + provenance).
- Templates may store hardware snapshot (explicit "Uložiť aj kovanie", 🔧 badge).
- UI mockup is mandatory before UI implementation.
- Updater (D-52) is a prerequisite: both production PCs run the same plugin version;
  older version must refuse/read-only rather than silently damage data.
- Legs: width <1000 → 4 legs, ≥1000 → 6 (AXILO + 17mm glides); plinth clip = 1 per
  started 4 legs, computed PER CABINET; leg set auto-selected from plinth height,
  visible at insertion (D-111).
- Hinges: ONE universal engine rule `hinges = MAX(by height, by weight)`; width only
  warns; manual override = visible lock; below minimum = WARNING (design) / ERROR (final).
- Door set quantities: hinge = resolved count · plate = 1×/hinge · cover = 1×/hinge ·
  Tip-On piston = exactly 1×/wing (Tip-On only). Small closed quantity-rule vocabulary;
  no formula language.
- Purchase output: aggregate by SKU with expandable per-owner provenance.

Production profile (USER-CONFIRMED, checkpoints #08/#09):

- Atira: wooden rear variant; carcass sides 18 mm → **EB fixed 10.5**; bottom+rear 16 mm;
  formulas BL=NL+10, BB=LB−2EB−51.5, RB=LB−2EB−63 (same RB across heights); height
  variants H70/H144/H176 (railing: H70=0, H144/176 = 1 per side); FULL catalogue NL set
  supported, resolver picks longest compatible NL, manual override; 30 kg standard,
  620 = 50 kg; both SiSy and P2O used; opening mode does NOT fork box geometry.
- Quadro V6 EB23: 5 wooden parts, 16 mm default (18 mm valid variant); SKW = LB−46;
  box height ≈ available_vertical_space − 40 mm (40 = Noxun recipe default clearance,
  not vendor constant); manual height override; 30 kg only in V1; full NL set.
- Drawer manufactured parts use the project's/default DRAWER material (own default,
  not derived from carcass), manual override allowed.
- Atira manufactured BOM = exactly 2 sheet parts (bottom + wooden rear); front is the
  existing owner, never re-emitted; everything else is purchased hardware.

## 3. OPEN CONFLICT for this cross-audit (deliberate, not an error)

**H6 — single-door direction `Neurčený`:**

- USER-CONFIRMED DECISION: unresolved direction **blocks final output** (ERROR at final
  production validation) until the user sets it. No heuristics, no fixed L/R default.
- ORCHESTRATOR ROUND-2 COUNTERPROPOSAL: RED finding in Kontrola but **no export gate
  yet**, because direction currently changes no produced output (purchase quantities and
  cut dimensions are direction-independent today), and a hard gate would retroactively
  block exports of existing live jobs that predate the direction field; the gate would
  arrive when the first output actually consumes direction (guided final check D-95 /
  production sheet).
- STATUS: **OPEN CONFLICT FOR CROSS-AUDIT.** Recommend exactly one option and justify
  via production risk, backward compatibility, UX, and the existing gate architecture
  (see `export_blockers`/`export_confirmations` in `noxun_engine/ui/production_core.rb`).

## 4. Repo evidence map (verify these claims yourself)

Architecture docs (read first): `docs/ARCHITEKTURA.md` → `docs/architecture/hardware.md`,
`construction.md`, `model-a-identita.md`, `outputs.md` · data contract `SYSTEM/STANDARD.md`.

Claimed repo facts the proposal builds on (each MUST be re-verified, cite exact spots):

1. Front rows: `noxun_engine/modules/fronts.rb` — items `door|drawer_front|none`,
   fixed/auto heights, wings 1–4, part_keys via `PartKeys.front(front_id, kind, variant)`;
   `normalize_items` is a whitelist (unknown fields dropped).
2. Part identity: `noxun_engine/core/part_keys.rb` — `front:<id>/<kind>[:variant]`
   syntax, `valid?` regex, `migrate_overrides` KEEPS keys of non-existent parts.
3. Plan contract: `noxun_engine/core/build_plan.rb` — ROLES list (includes `flap`,
   `false_front`), `GENERIC_TYPES = leg hinge slide handle shelf_pin connector
   wall_hanger` (NO `lift`), hardware item = string-keyed with `owner_part_key`
   referential integrity; identity = (owner_part_key, generic_type, rule_id).
4. Rules: `noxun_engine/core/hardware_rules.rb` — kinds `fixed|bands|fit_series|
   part_flag_length`, project snapshot on model, overrides with independent fields
   (`quantity`/`disabled`/`nominal_length` — D-93 lock = field existence), context keys
   incl. `available_width/height/depth`.
5. Context: `noxun_engine/core/construction.rb` (~lines 78–92) — `hw_ctx` computes
   `available_width = w − 2t`, `available_height`, `available_depth` at cabinet level;
   hardware evaluated AFTER degenerate-part filtering.
6. Evaluated hardware persists in cabinet config: `Bom.collect` reads `ccfg['hardware']`
   and merges `owner_id` (`noxun_engine/core/bom.rb` ~line 74).
7. Sets: `noxun_engine/core/hardware_sets.rb` — member keys `per qty label code
   code_by_nl param_bands`, `per: unit|owner`, expansion `expand`/`expand_members`,
   `resolve_set_id` (mapping keys `generic_type` or `generic_type@owner_part_key`),
   project snapshot + global library with std marker + R-07 read-only gate + R-08 lock,
   length gate R-06a (`cut_length_mm` → ORANGE `length_unsupported`), template freeze
   `template_set_defs`/`freeze_template_sets!`.
8. Validation/gates: `noxun_engine/core/validation.rb` + `noxun_engine/ui/
   production_core.rb` — Kontrola ORANGE/RED never blocks EXCEPT final priced/order file
   writes: `export_blockers` (hard) vs `export_confirmations` (two-click), `dup_partition`,
   `budget_std_block`. VEPO deliberately exempt.
9. Migration guards: config `CONFIG_SCHEMA` + `guard_newer_config!` (R-12, cabinet_builder),
   sets library `std` (R-07), rules `STD`, budget `budget_std` (R-14), templates `std`;
   `template_config_from` is another closed whitelist.
10. Density: `noxun_engine/core/materials.rb` — `density_for(rec)` per material TYPE
    (kg/m3), decided 2026-08-02.
11. Purchase provenance: `hardware_expansion` rows carry sources; invariant
    `Σ sources.quantity == row.quantity` (only for unit/owner members); task package
    D-94 (purchase drill-down) exists in `SYSTEM/PLAN.md`.

## 5. ROUND 2 TARGET ARCHITECTURE (ARCHITECTURAL PROPOSAL — the thing to attack)

### 5.1 Control/data flow

```
front item (fronts config: front_type · opening_mode · direction ·
            drawer{family, system, axis values, locks})
  → Construction.build_plan
      → context_for(owner)   — pure fn: clear_width/clear_height/clear_depth
      → resolver (recipe = data): highest compatible height variant, longest
        compatible NL, per-axis manual overrides act as locks
      → emits (a) manufactured part descriptors (drawer bottom/rear or wooden box)
               into plan.parts, (b) hardware items into plan.hardware
        (params: system, NL, height_variant, load, opening)
  → persisted via existing config['hardware'] + parts path
  → Bom.collect → HardwareSets.expand (classification + axis tables → SKU rows
    with provenance) → Kontrola + existing export gates → outputs
```

### 5.2 Derived drawer parts

- part_key via existing `PartKeys.front(front_id, kind)`: `front:F1/drawer_bottom`,
  `front:F1/drawer_back`, `front:F1/box_side:left|right`, `front:F1/drawer_inner_front`.
- New ROLES `drawer_bottom|drawer_back|drawer_side|drawer_inner_front` (+plan_schema bump).
- Regenerate pattern: parts rebuilt deterministically each rebuild — no incremental
  lifecycle; type switch removes parts, `part_overrides` keys survive (dormant config).
- Material role `:drawer` → new project default "drawer material" (16 mm), override via
  existing part_overrides.
- ABS: new role defaults in `abs_rules` (proposal: no edging by default, no ORANGE).
- BOM/VEPO/kusovník pick parts up automatically as manufactured parts.
- Templates: drawer config travels inside cabinet config; `template_config_from`
  whitelist must be extended.

### 5.3 context_for(owner)

Existing cabinet-level `hw_ctx` + per-owner vertical space = front row height/z
(from `Fronts.layout` resolved items) projected onto interior (floor/top/rails).
Clearance is recipe data (Quadro default −40). V1 explicitly does NOT do full collision
solving: detectable vertical divider in a drawer row → ORANGE; atypical geometry is
visually checked and manually overridden (USER-CONFIRMED). No persistent zone objects.

### 5.4 Recipe schema (data-driven, both families)

Shared computation: `width = W_eff − c`, `length = NL + c`, rear height from height
table, `min_depth = NL + c_d(opening)`, min internal height from (variant × opening)
table, NL/height selection from context. Required schema features (from verified vendor
research, checkpoint #10): (1) EB indirection `W_eff = LB − 2×EB`, **EB belongs to the
runner SKU variant** (Blum/Strong: EB ≡ 0); (2) rear-type discriminator (wooden/steel
changes bottom length); (3) availability matrix NL × height × load × opening —
**including opening×load interactions** (TANDEM Tip-On ≈ 20 kg; antaro TOB module by
total weight) and per-opening min_depth (Atira NL260: 279 SiSy vs 305 P2O); (4) mounting
variant in recipe key (Quadro slide-on: len = NL vs coupling: NL−10) — V1 pins
`mounting: slide_on`; (5) opening-specific extra components (P2O sync shaft, trigger
`width > 600 && P2O`) — V1: length-cut member stays behind existing R-06a ORANGE gate
(full `per:'length'` pricing remains post-V1 with R-05); (6) `inner_supported: false`
flag per system until inner-drawer recipes exist.

### 5.5 Hardware vs procurement

Logical configuration → set (existing mechanism) → members: kit SKU = set whose single
member's code is selected by axis tables (`code_by_nl` + new `code_by_height`); atomic
SKUs = multi-member set (runners, zargen, rear holders, railings per height, D-109 ratio
member). No new data concept for kit-vs-atomic. Aggregation by SKU + provenance =
existing `hardware_expansion` + D-94.

### 5.6 Migration / old projects

All additive with defaults; bumps of EXISTING guards: CONFIG_SCHEMA (R-12), sets std
(R-07), rules STD, plan_schema + GENERIC_TYPES(+`lift`,+`custom`) + ROLES, budget
untouched. Old unclassified set = fully valid, interpreted as "nezaradený/Ostatné",
production result of old jobs byte-identical (characterization test required).
Prerequisite: D-52 updater (both PCs same version).

### 5.7 Validation mapping (proposal)

| State | Level | Gate |
|---|---|---|
| drawer: no compatible NL/height fits | RED `drawer_no_fit` | blocks hardware CSV + priced exports (analogous to P0-2: knowingly incomplete order) |
| owner without resolved set (hard conflict) | RED | same |
| locked value below minimum / outside series | ORANGE (design) | confirmable at export (two-click pattern) |
| direction `Neurčený` | see §3 OPEN CONFLICT | see §3 |
| vertical divider inside drawer row | ORANGE | — |
| soft recommendations | ORANGE info | — |

### 5.8 Ad-hoc hardware (recommended variant A)

`config['hardware_manual'][]` on the cabinet: `{owner_part_key|nil, source:
catalog|free, code?, name, qty, mj, price_eur?, note}` → merged by `Bom.collect` into
the hardware channel (own kind) → expansion passes it through as its own purchase row
with provenance. Lives in .skp (undo/copy/templates). Optional "save to catalog" bridge.
Rejected: budget-only custom rows (no purchase provenance), catalog-mandatory variant
(catalog clutter for one-offs).

### 5.9 Repo change map (proposal)

MODIFY: fronts.rb · construction.rb · build_plan.rb · hardware_rules.rb ·
hardware_sets.rb · hardware_catalog.rb · abs_rules.rb · validation.rb ·
production_core.rb · bom.rb · cabinet_builder.rb · materials_project (drawer material
default) · panel/studio UI (after mockup). NEW MINIMAL: `core/drawer_recipes.rb` (pure
compute + validation) + recipe data packs (Atira, Quadro). REUSE unchanged: part_keys,
doc_key, json_file_store, templates freeze, hardware_expansion/D-94, density_for, ghost.
EXPLICITLY DO NOT ADD: FunctionalZone entity · assembly-owner registry · recipe editor
UI · revision chains/Deprecated · multi-axis diff-modal framework · parallel validation
framework · per-brand hinge modules · full `per:'length'` (stays with R-05, post-V1).

### 5.10 Implementation slicing (proposal)

0 D-52 updater (prereq) → A front data layer (types, opening, direction, flap/blenda
build, config_schema, direction overlay) → B catalog+sets classification & editors →
C context_for + recipes + derived parts (hardest; in-SketchUp tests mandatory) →
D resolver + set axes + locks + Kontrola/gates → E lifts HK/HL (generic_type lift,
weight from densities) → F hinges MAX(height, weight) + handle-per-wing + TipOn piston →
G legs 4/6 + D-109 + plinth set at insertion → H ad-hoc hardware (can go right after A)
→ I templates 🔧 + "Uložiť aj kovanie". Small PRs inside slices.

## 6. Targeted attack areas (your audit MUST cover these; do not redesign globally)

1. **Derived drawer part identity** — is `PartKeys.front(front_id, kind)` for
   drawer_bottom/back/side/inner_front truly safe? Verify: rebuild, NL change, height
   change, system change, dormant overrides, obsolete parts, template cloning,
   copy/duplicate cabinet, part_key collisions, BOM/VEPO/ABS lifecycle. Look for a
   CONCRETE repo-level failure mode.
2. **context_for(owner)** — does computed context (no persistent FunctionalZone)
   suffice for V1: width, depth, vertical clear space, dividers, floor/top, multiple
   drawers, asymmetric sectors? Question is ONLY: can the proposed minimum generate
   wrong production without a visible warning? (No perfect collision solver required.)
3. **Drawer recipe schema** — try to break §5.4 with Atira/Quadro/Antaro/StrongBox/
   StrongMax/TANDEM (data in checkpoint #10): EB-on-SKU, rear type, availability matrix,
   NL×height×opening×load interactions, per-opening min_depth, mounting variant,
   opening-specific extras, sync trigger, inner_supported. Can it stay data-driven
   without brand-specific code spaghetti?
4. **Logical hardware vs procurement** — verify §5.5 against existing hardware_sets/
   expansion; find where the existing model does NOT suffice. If it suffices, do not
   propose a new BOM subsystem.
5. **Migration / old-project safety** — schema bumps, whitelists, old unclassified sets,
   live jobs, older templates, dormant overrides, D-52, guard behavior. Goal: NO silent
   change of an old job's production result.
6. **Validation semantics** — two contested points: (A) `drawer_no_fit` as hard blocker;
   (B) §3 direction conflict. Recommend exactly one option each, justified by production
   risk, backward compatibility, UX, and existing gate architecture.
7. **V1 scope** — verify Atira+Quadro now, other 3 data-ready later. If you claim all 5
   are cheap, show the concrete implementation delta. If you claim even Atira+Quadro is
   too big, show the concrete blocker.
8. **Ad-hoc hardware** — verify §5.8 (owner identity, clone/copy, templates,
   aggregation, provenance, catalog/free item, price snapshot, stale catalog reference).
   Find the SMALLEST safe version.

## 7. Required output format (exactly these sections)

1. **VERDICT** — `SOUND` | `SOUND WITH CHANGES` | `UNSAFE`
2. **CRITICAL FINDINGS** — only issues that can cause wrong production, data loss,
   wrong purchase, non-reproducible project, or a major mid-implementation refactor.
3. **IMPORTANT FINDINGS**
4. **FALSE COMPLEXITY** — what can still be removed from the proposal.
5. **MISSING MINIMUM** — what is genuinely missing.
6. **V1 SCOPE VERDICT** — Atira+Quadro vs all 5 (with concrete delta/blocker).
7. **VALIDATION VERDICT** — explicitly decide `Neurčený smer` (§3) and `drawer_no_fit`.
8. **IMPLEMENTATION RISK MAP** — each slice from §5.10 rated LOW/MEDIUM/HIGH.
9. **EXACT REPO REFERENCES** — every repo claim cites file/function.
10. **TOP 5 CHANGES** — max five changes you would make before implementation.

Do not expand scope merely because a more elegant system is imaginable.
