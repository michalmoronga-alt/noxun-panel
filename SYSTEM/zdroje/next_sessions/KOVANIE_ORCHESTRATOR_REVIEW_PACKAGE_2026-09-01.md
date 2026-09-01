# KOVANIE V1 — ORCHESTRATOR REVIEW PACKAGE

> **Status:** REVIEW INPUT / CHALLENGE PACKAGE — **NOT an implementation spec**.
> **Date:** 2026-09-01
> **Goal:** challenge the proposed V1 hardware architecture against the real repository, domain logic, implementation cost, and actual user value **before implementation**.

---

## 0. Mission for Orchestrator

Do **not** treat the decisions below as correct just because they were discussed and checkpointed.

Your first task is to act as a senior architect/reviewer and answer:

1. What is solid and should stay?
2. What is logically wrong, contradictory, fragile, or incompatible with the current repo?
3. What is over-engineered for V1 relative to its practical benefit?
4. What can be materially simplified without blocking future evolution?
5. What is missing but genuinely necessary for a usable V1?
6. Which assumptions are domain/technical claims that still need manufacturer documentation or user verification?

**Do not implement anything in this first pass.**

The user wants to discuss your critique first. Only after that discussion should you produce a formal audit / implementation-ready plan.

---

## 1. Required review method

### 1.1 Inspect the repo directly

Do not reason only from this document. Read current code, contracts, tests, architecture docs, current UI patterns and existing hardware/template implementation.

Relevant discussion checkpoints:

- `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01.md`
- `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01_02.md`
- `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01_03.md`
- `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01_04.md`
- `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01_05.md`
- `SYSTEM/zdroje/next_sessions/KOVANIE_DEBATA_CHECKPOINT_2026-09-01_06.md`

Also inspect at minimum the current equivalents of:

- hardware architecture / rules / BuildPlan owner contract,
- Fronts/front roles,
- ZoneTree and divider/shelf semantics,
- templates and `hardware_sets` / frozen `hardware_set_defs`,
- Supplier/Démos settings and parser,
- Inspector/form UI patterns,
- current validation / project-control patterns,
- tests/guards that constrain refactors.

### 1.2 Separate evidence classes

For every important criticism or recommendation, explicitly distinguish:

- **REPO VERIFIED** — supported by current code/docs/tests,
- **USER DECISION** — business/workflow preference chosen in discussion,
- **TECHNICAL ASSUMPTION** — must still be verified from manufacturer documentation / configurators,
- **YOUR RECOMMENDATION** — architectural judgment.

Do not turn guessed technical values into implementation constants.

### 1.3 V1 lens

Use a strict V1 rule:

> If a feature creates substantial state, migration, UI, resolver or testing complexity but produces little real daily benefit, recommend moving it out of V1.

Future extensibility is useful, but **do not build generalized frameworks merely because they may be useful later**.

---

# 2. Product intent

The Hardware block is not meant to become a generic PLM/PDM system.

The practical target is:

- classify fronts/mechanical objects,
- choose correct repeatable hardware,
- calculate quantities,
- react safely to cabinet geometry changes,
- preserve reproducibility of existing projects/templates,
- generate a trustworthy hardware/BOM/order output,
- expose enough technical detail to diagnose decisions,
- keep exceptional/manual cases possible.

The Engine should remove repetitive furniture-engineering work, not replace every possible hardware judgment.

---

# 3. Proposed V1 architecture to challenge

## 3.1 Front types

Target front types:

- `Dvierka`
- `Zásuvkové čelo`
- `Výklop`
- `Sklop`
- `Blenda / pevné čelo`

`Blenda` is a manufactured fixed panel: no direction/opening/hinge/slide behavior.

Moving fronts expose an independent opening-mode axis:

- `Classic`
- `Tip-On / Push-to-open`

`Classic` describes pull-to-open behavior, not handle type.

Opening graphics:

- moving-front opening lines = dashed,
- blenda = solid full X.

Single-door direction:

- infer only when reliable,
- otherwise `Neurčený`,
- WARNING during design,
- ERROR at final production validation.

Double doors:

- each wing is its own hardware owner,
- no general symmetric-front synchronization system in V1.

---

## 3.2 Drawer construction

For `Zásuvkové čelo`:

- `Drevený box / skrytý výsuv`
- `Kovové bočnice`
- `Ostatné / atyp`

`Ostatné` is manual/non-automated rather than a new formula family.

Reserve `drawer_variant = standard | internal`.

V1 fully automates standard drawers. Internal drawers are classified but their deeper automation can be deferred.

---

## 3.3 OWNER vs SPACE / CONTEXT

Core proposal:

- **OWNER** = who owns hardware / mechanical state,
- **SPACE/CONTEXT** = where it must fit and which geometry constrains it.

Do not conflate them.

Examples:

- door wing = owner of hinges,
- drawer assembly = owner of drawer system,
- lift/flap assembly = owner of lift system,
- cabinet = owner of legs,
- functional zone = geometry/context, not hardware owner by default.

A known current-repo concern to review: existing hardware ownership is materially simpler (e.g. part key / cabinet-level semantics). Determine the real migration/refactor cost of introducing richer logical owners.

---

## 3.4 Functional zones

Proposal: introduce a derived **functional zone** distinct from construction zones.

A functional zone:

- is virtual/derived space,
- does NOT create a divider or manufactured part,
- has exactly one parent construction zone,
- derives clear width/height/depth,
- follows its functional object automatically,
- is used for technical selection/validation,
- is visible contextually or through a `Funkčné zóny` layer rather than always shown.

Examples:

- four drawer fronts inside one construction opening can produce four functional drawer spaces without physical dividers,
- lift/flap hardware can validate against its usable clear volume.

Parent assignment:

- Engine may auto-determine parent from geometry,
- manual override is allowed,
- overlap across multiple construction zones is a hard conflict rather than silently picking the largest overlap.

**Challenge this aggressively:** determine whether functional zones are essential V1 infrastructure or whether equivalent inputs can be derived more cheaply from existing geometry/ZoneTree without creating a new first-class state model.

---

## 3.5 Mechanical assembly owners

### Drawer

When a front becomes `Zásuvkové`, proposal is to create a logical parent such as:

`Zásuvková zostava F1`

containing/owning conceptually:

- front,
- functional zone,
- manufactured drawer-box parts,
- resolved hardware set,
- technical validation.

Changing Drawer -> Door removes active drawer assembly/state after showing impact, but remembers one previous drawer configuration for possible restore.

Door -> Drawer offers:

- `Obnoviť poslednú konfiguráciu`
- `Začať od predvolených`

Restore includes system/series, height, NL, Classic/Tip-On, load variant, locks and manual overrides, followed by revalidation.

### Výklop

Changing front type to `Výklop` creates generic:

`Výklopná zostava F1`

plus its functional zone. AVENTOS HK top is a concrete mechanical system of that assembly, not the owner type itself.

### Sklop

Equivalent generic concept:

`Sklopná zostava F1`

plus functional zone, with concrete mechanism selected later.

Both lift/flap assemblies use general `Classic / Tip-On` opening mode, while concrete mechanisms declare what they support.

Previous full technical state is remembered when switching back to another front type, with restore/default choice on return.

**Challenge this:** hidden last-state memory is useful UX, but determine whether it is justified in V1 or whether it creates disproportionate lifecycle/template/copy complexity.

---

## 3.6 Default set hierarchy

Proposal:

`global company default -> project override -> concrete owner/front override`

Defaults are separate per relevant combination, e.g. front type/opening mode/system family.

The selected default is automatic but user-overridable.

---

# 4. Catalog, sets and technical variants

## 4.1 Mandatory set classification

A complete set is classified using controlled fields such as:

- type/use,
- opening mode,
- drawer construction where applicable,
- manufacturer,
- product family/series.

`Ostatné` remains an escape hatch.

Manufacturer and series are controlled lists with `+ Vytvoriť` rather than arbitrary free text.

A product series belongs to one manufacturer.

Set name may be proposed from classification but remains editable.

---

## 4.2 Catalog UX

Target catalog structure:

`Category -> Manufacturer -> Series`

with search/filtering and progressive expansion.

Add/Edit Item or Set uses one dedicated modal.

For Démos:

- search/URL at top,
- Démos URL may be parsed and prefill fields,
- manual fallback always available,
- foreign URL is stored as reference only unless deliberately supported later,
- inferred classification only when confidence is sufficient,
- explicit Tip-On/PTO/Push terms should outrank vague damping terms,
- unknown series should be proposed for creation rather than silently created.

Existing Démos parser/current URL contracts must be inspected before changing field semantics.

---

## 4.3 Resolved set / technical variant

Externally, user sees one resolved system state, e.g. conceptually:

`Atira H176 · NL520 · Classic · 30 kg`

but technical detail exposes separable axes such as:

- height class,
- nominal length,
- opening mode,
- load capacity,
- members,
- limits.

Resolver should preserve compatible axes when only one input changes:

- depth change primarily affects NL,
- height change primarily affects height class,
- opening-mode change affects opening branch,
- future load change affects load axis.

Avoid UX where a small geometry edit appears to replace the whole drawer system unnecessarily.

**Challenge the data model:** determine whether storing every Cartesian combination as a fully separate variant will explode in size and whether a compositional model would be safer/simpler while preserving snapshots.

---

## 4.4 Locks and resolver diffs

Locks are per-axis where useful, e.g. `🔒 NL470`.

Resolver never silently changes important technical state.

Normal compatible update:

- may apply through normal geometry workflow,
- show a clear after-change diff/reason.

Major system/manufacturing-logic change:

- proposal before change,
- shared diff,
- expandable per-axis detail,
- user may edit proposed axes,
- one confirmation.

Locked value still compatible:

- preserve it.

Locked value impossible:

- show hard conflict + compatible replacement proposal,
- confirmation required,
- if accepted, replacement remains locked.

System change where locked value does not exist:

- conflict + closest compatible proposal,
- no silent unlock.

---

## 4.5 Validation

At minimum:

- `OK`
- `WARNING`
- `ERROR`

Hard limit:

- invalid technical configuration,
- may remain during active design,
- project may still be saved,
- final production validation/output is blocked.

Soft recommendation:

- technically valid,
- suggests a better choice,
- does not block production by itself.

Project Control should group conflicts by cabinet/owner and act as a repair navigator:

- select model object,
- open correct `Čelá / Kovanie / Zóny` section,
- scroll/highlight exact issue.

If resolver finds **no compatible set**:

- do NOT choose a technically invalid set,
- do NOT silently switch to `Ostatné`,
- leave owner without resolved set as hard conflict,
- explain reason,
- offer manual selection or conscious `Ostatné` path.

---

# 5. Technical-profile versioning

Proposal:

A verified technical variant/profile bundles reproducible:

- compatibility limits,
- members,
- recipe/technical parameters,
- relevant system identity.

After first project/snapshot use, technical profile should be immutable.

If an unused profile contains an obvious error, it may be corrected in place. After use, correction creates a new revision.

Statuses:

- `Active`
- `Deprecated`
- `Inactive`

Active = current resolver/default candidate.

Deprecated = retained for reproducibility but not new default.

Inactive = historical/retired but retained for old snapshots.

**Challenge whether this three-state revision system is necessary in V1 or can be simplified without losing project reproducibility.**

---

# 6. Templates + hardware

Current repo already has a concept of template hardware snapshot (`hardware_sets` + frozen set definitions). Review the real current behavior before changing it.

Proposed UX:

- explicit `Uložiť aj kovanie`,
- geometry-only template has no hardware badge and uses current defaults after insertion,
- hardware template stores current ACTIVE technical state only,
- hidden last-configuration memory of inactive drawers/lifts is NOT stored in template,
- stored locks remain real locks after insertion.

Template tile:

- small 🔧 badge when hardware exists,
- hover/focus = short grouped summary,
- click = read-only hardware detail before insertion,
- expanded detail may show concrete members and Démos codes,
- no direct library editing.

Version behavior:

- stored Deprecated but compatible variant -> insert exact snapshot + subtle newer-version notice,
- stored Inactive and incompatible -> insert visible hard conflict + proposed active replacement,
- if only one set is problematic, preserve other sets.

Saving:

- hard hardware conflict blocks `save with hardware`, but geometry-only template may still be saved,
- soft warning does not block hardware save,
- soft warnings are recomputed after insertion rather than frozen,
- if same template name exists -> `Nahradiť existujúcu / Uložiť ako novú`,
- replacement shows concise diff,
- `Uložiť ako novú` requires manual name,
- replacing does not keep template rollback/history.

After insertion, later geometry edits use normal resolver rules. The snapshot is reproducible initial state, not permanent freezing.

**Challenge the interaction between template snapshots, immutable technical revisions, locks and normal resolver updates. Look specifically for contradictory ownership of truth.**

---

# 7. Drawer manufacturing recipes

Manufacturing formulas should not live as arbitrary formulas directly inside each product series.

Proposal:

- separate recipe library,
- concrete series/system references a recipe,
- similar systems may share formula families,
- immutable verified formula,
- separate system parameter table,
- readable editor, not raw JSON,
- small whitelist of controlled rule/formula types rather than arbitrary expression language.

Potential V1 systems to validate against real usage:

- Hettich Atira
- Hettich Quadro
- Blum TANDEM
- Blum TANDEMBOX Antaro
- Blum LEGRABOX

Exact formulas, heights, nominal lengths, Tip-On variants and Démos codes require later data audit from manufacturer sources and the user's real working data.

Drawer technical variant may include `load_capacity_kg`.

Future recommendation based on geometry/volume may suggest stronger load variant, but **must not silently switch**.

**Challenge whether load recommendation belongs in V1 or should be data-only/manual initially.**

---

# 8. Lifts — V1 candidates

Working V1 lift scope:

- Blum AVENTOS HK top
- Blum AVENTOS HF top
- `Ostatné` for gas struts/rare/manual cases

## HK top

- one front,
- generic `Výklopná zostava`,
- function-space validation,
- mechanism recommendation based on verified geometry + front weight + official limits,
- Inspector shows final mechanism primarily; PF/force details are expandable.

Opening branches:

- Classic,
- Tip-On.

HK Tip-On resolved set contains a real TIP-ON piston.

User-domain rule for current workflow:

- exactly **1 TIP-ON piston** per HK Tip-On front; multiple pistons are considered invalid because synchronization is not workable.

## HF top

- two-front folding assembly,
- own mechanical parent assembly,
- total front weight + dimensional/technical rules,
- default split 50/50,
- asymmetry allowed only within verified documentation,
- preview-first workflow: virtual split -> validate -> confirm -> create actual fronts,
- invalid HF configuration is not silently approximated; can switch to `Ostatné/manual`.

Mechanism/PF selection should recommend compatible mechanism; manual selection limited to compatible choices.

**Challenge whether supporting both HK and HF at this depth is an appropriate V1 scope. If HF is too expensive relative to use, recommend a staged cut rather than preserving complexity for its own sake.**

All exact HK/HF limits must be reverified from current official manufacturer docs before hardcoding.

---

# 9. Door hinge logic

The discussion deliberately simplified hinge-count calculation.

Proposal:

- **one common Engine rule for normal hinges**, not one algorithm per brand/series,
- core idea: `required hinges = MAX(requirement from front height, requirement from front weight)`,
- exact thresholds to be approved only after technical-table verification,
- excessive width does not automatically add a hinge; it produces a warning outside verified normal range,
- user can manually override hinge count.

Manual override:

- becomes visible lock, e.g. `🔒 3 hinges`,
- geometry/material/type changes do not silently change it,
- Engine recalculates recommended minimum and reports difference,
- locked value below calculated minimum = WARNING during design, ERROR at final validation,
- locked value above minimum = valid `OK`.

V1 explicitly excludes automatic synchronization of hinge locks across symmetric/equal fronts.

### Classic vs Tip-On door set

- Classic -> hinge with integrated damping,
- Tip-On -> P2O hinge without damping + exactly 1 TIP-ON piston per door wing.

Common catalog items may be shared between set definitions.

Default set-member quantity logic may include:

- hinge = resolved/locked hinge count,
- mounting plate = `1× per hinge`,
- cover = `1× per hinge`,
- TIP-ON piston = `1× per owner/wing` for Tip-On.

Members and quantity rules remain editable in set definition rather than hardcoded to one brand.

Simple allowed quantity-rule vocabulary for V1:

- fixed quantity,
- `N× per hinge`,
- `N× per owner/wing/assembly`,
- simple multiplier of a known base quantity.

No arbitrary formula language.

**Challenge the universal hinge-count rule against manufacturer reality. If it is too unsafe as a universal rule, propose the simplest defensible alternative — not an enterprise rules engine.**

---

# 10. Legs / plinth decisions already discussed

Working rules:

- cabinet width `<1000 mm` -> 4 legs,
- cabinet width `>=1000 mm` -> 6 legs,
- AXILO + 17 mm glides,
- plinth clip quantity is calculated **per cabinet**, never by combining adjacent cabinets,
- 4 legs -> 1 clip,
- 6 legs -> 2 clips.

Leg set is automatically selected from plinth height, with cabinet-level override and global default source.

Review these against actual current code/domain naming, but avoid expanding this into a generalized support/structural solver in V1.

---

# 11. Hardware order/BOM output

Resolved hardware output should aggregate identical catalog items/SKUs into one purchase row.

Example concept:

`Mounting plate X · 24 pcs`

but expanded provenance must show which cabinets/owners contributed the quantity.

Goal:

- clean procurement view,
- no loss of traceability.

Review identity/aggregation keys carefully (SKU/catalog identity/supplier code/etc.) against existing data model.

---

# 12. IMPORTANT OPEN AUDIT POINT — concrete hardware outside sets

**Do not close this in the first review.**

There is a real practical need to attach concrete hardware/accessories that do not deserve a dedicated abstract/global set.

Examples:

- door lock,
- pull-out wardrobe rail,
- switch,
- magnet,
- stop,
- adapter,
- miscellaneous accessory.

Desired property:

- the item may belong to a cabinet / owner / front / zone,
- it must appear in BOM/order output,
- provenance must remain obvious,
- user should not need to invent dozens of fake one-item sets merely to make BOM traceable.

Working idea only:

`Ostatné / Pridať konkrétnu položku`

with explicit attachment to a meaningful context.

After the architecture review / PR audit, provide **2–3 concrete UX + data-model alternatives** for this. Compare complexity, traceability, snapshot behavior and compatibility with current hardware ownership.

The user will decide after seeing those alternatives.

---

# 13. UI/UX principles

Do not mirror database structure directly into UI.

Primary responsibility split:

### Čelá

What the front is / how it behaves:

- type,
- direction,
- Classic/Tip-On,
- drawer construction,
- HF split/geometry,
- visual opening preview.

### Kovanie

How it is mechanically realized:

- selected/resolved set,
- manufacturer/series,
- mechanism,
- locks,
- compatibility/load/technical details.

### Zóny

Space/context:

- construction zones,
- functional-space relationships,
- internal subdivision/context.

One property should have one editing authority. Other sections may show read-only summary/link.

Use progressive disclosure and graphical/pictogram controls where they materially improve speed/clarity.

Before implementing major new Front/Hardware/Zone interactions, create a **UI mockup based on current/older Inspector patterns**. It does not need to be a complete Inspector redesign.

---

# 14. Explicitly outside V1 unless review finds a blocker

- general symmetric/equal-front synchronization framework,
- bulk lock propagation across the project,
- full internal-drawer automation beyond necessary classification,
- broad atypical drawer automation,
- general linear-hardware system,
- generalized formula language,
- universal hardware PLM/PDM capabilities,
- broad automatic load prediction from unknown contents,
- unrelated hardware categories that do not block the first production workflow.

If any of these are accidentally required by the proposed architecture, call that out as a design smell.

---

# 15. Technical/data audits intentionally NOT solved yet

Do not invent values. Later audit must verify:

1. exact drawer manufacturing formulas and parameter tables,
2. actual systems/variants used most often in company practice,
3. nominal lengths, height variants, load variants, Tip-On availability,
4. Démos catalog codes and mapping,
5. exact AVENTOS HK top limits/mechanism logic,
6. exact AVENTOS HF top limits/PF/hinge/split rules,
7. universal hinge-count thresholds and normal width range,
8. density/weight inputs and reliability for front-weight calculation.

Manufacturer technical docs/configurators are authoritative for engineering limits; user/company data is authoritative for workflow frequency/default choices.

---

# 16. High-risk areas you MUST challenge

Do not skip these because they sound elegant:

1. **Functional zones:** essential abstraction or duplicate state?
2. **Logical assembly owners:** correct domain model or expensive refactor around current part-based ownership?
3. **Hidden last configuration memory:** genuinely high-value UX or unnecessary lifecycle complexity for V1?
4. **Resolved variant combinatorics:** will height × NL × opening × load × revision explode?
5. **Immutable revisions + template snapshots + locks:** is there one clear source of truth?
6. **Three-state Active/Deprecated/Inactive:** useful V1 reproducibility or excessive machinery?
7. **Resolver sophistication:** are per-axis locks/diffs worth the implementation/test burden now?
8. **HF top:** is two-front preview/assembly handling justified in V1?
9. **Universal hinge rule:** safe enough or oversimplified?
10. **Catalog/set editor:** are we building too much admin UI before core selection/BOM works?
11. **Manual hardware outside sets:** is this actually more important for day-one usability than some advanced resolver features?
12. **Migration/backward compatibility:** what existing project/template contracts would the new model break?

---

# 17. FIRST RESPONSE REQUIRED FROM ORCHESTRATOR — STOP AFTER THIS

For your **first response**, do not create task packages and do not implement.

Return exactly these sections:

## A. Executive verdict

Short assessment of the overall direction and whether it fits the current repo.

## B. What I would keep

The strongest decisions that should survive into V1.

## C. What I would change

Decisions that are wrong, contradictory, fragile or should be modeled differently.

For each material point, cite concrete repo path/symbol/test where relevant.

## D. What I would move out of V1

Be aggressive. Identify complexity with low expected practical return.

## E. What is missing from V1

Only genuinely necessary missing capabilities.

## F. Architecture risk ranking

Use:

- `P0` — blocks or invalidates direction,
- `P1` — should resolve before implementation,
- `P2` — can be refined during implementation/audit.

## G. Recommended slim V1

Describe the smallest architecture you believe still delivers the intended practical value.

Do not preserve a discussed feature merely because work was spent discussing it.

## H. Questions for Michal

Only questions that genuinely require business/domain choice.

Prefer at most ~8 important questions. For each:

- explain why it matters,
- give `a) / b) / c)` where possible,
- state your recommendation.

## I. Proposed next audit after we discuss your review

Outline what you would inspect/verify next, but **do not execute that full audit yet**.

Then **STOP and wait for discussion with Michal**.

---

# 18. SECOND STAGE — only after Michal discusses/approves the critique

After the review discussion, prepare a formal repo-grounded audit containing:

- final accepted architecture,
- changed/rejected decisions and reasons,
- current repo gap analysis,
- migration/backward-compatibility plan,
- V1 / later split,
- technical-data verification checklist,
- UI mockup requirements,
- implementation sequencing,
- tests/acceptance criteria,
- explicit open points.

Do not convert unresolved technical manufacturer assumptions into code constants.

---

# 19. THIRD STAGE — cross-audit preparation

After the formal audit is stable, prepare a **neutral cross-audit package** for independent reviewers:

1. **Codex** — implementation/architecture/codebase audit,
2. **GLM** — independent architecture/value/complexity review,
3. **blind Opus review** — should receive the architecture + repo evidence/questions **without being shown the conclusions of the other reviewers first**.

The blind reviewer package should avoid leading language and should distinguish facts from proposed decisions.

After all reviews, synthesize:

- consensus,
- disagreements,
- unique risks found by only one reviewer,
- false positives / recommendations incompatible with repo reality,
- final decisions requiring Michal.

The purpose of cross-audit is not majority voting. Use it to find blind spots.

---

# 20. Review priority

Optimize in this order:

1. correctness / traceability,
2. real furniture-production usefulness,
3. compatibility with current Noxun Engine architecture,
4. V1 simplicity and testability,
5. UX speed/clarity,
6. future extensibility.

Future extensibility must not outrank a clean, shippable V1.
