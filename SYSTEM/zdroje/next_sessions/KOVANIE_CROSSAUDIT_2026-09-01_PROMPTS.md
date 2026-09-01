# KOVANIE V1 — CROSS-AUDIT PROMPTS (2026-09-01)

> Stav: KONCEPT / pracovný checkpoint — nie implementačný spec, neimplementovať priamo; uzavretá architektúra: KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md.

> Tri nezávislé audity nad JEDNÝM zdrojom pravdy: `KOVANIE_CROSSAUDIT_2026-09-01_SOURCE_PACK.md`.
> Source pack neobsahuje závery žiadneho audítora — líšia sa LEN wrappre podľa nástrojov a fokusu.
> Audity bežia nezávisle; závery sa NIKDY nezdieľajú medzi audítormi pred reconcile kolom.
> Blind pravidlo pre Opus: dostane source pack + repo, NIKDY výstupy Codexu/GLM ani agregát.

---

## PROMPT 1 — CODEX (repo/implementation architecture audit; lokálny prístup k repu)

```
You are an independent senior reviewer auditing a proposed architecture BEFORE
implementation. You have full read access to the repository working copy.

Read first, in this order:
1. SYSTEM/zdroje/next_sessions/KOVANIE_CROSSAUDIT_2026-09-01_SOURCE_PACK.md  (the audit
   input — mission, closed user decisions, the proposal to attack, attack areas, output
   format; follow its source-discipline tagging exactly)
2. SYSTEM/zdroje/next_sessions/KOVANIE_TECHNICAL_AUDIT_CHECKPOINT_2026-09-01_10_VENDOR_MATRIX.md
   (verified vendor data + confidence tags)
3. docs/ARCHITEKTURA.md and the referenced module sections in docs/architecture/
   (hardware.md, construction.md, model-a-identita.md, outputs.md), SYSTEM/STANDARD.md

Your specific angle (this is YOUR focus, the other independent auditors have different
ones): IMPLEMENTATION FEASIBILITY AGAINST THE ACTUAL CODE. Re-verify every repo claim in
source-pack §4 directly in the source (do not trust the pack), then attack §5 through
the 8 areas in §6 with emphasis on: part identity & regenerate lifecycle
(core/part_keys.rb, core/cabinet_builder.rb, modules/fronts.rb), BuildPlan contract and
guards (core/build_plan.rb), sets/expansion/whitelists/std gates (core/hardware_sets.rb),
gate architecture (ui/production_core.rb), migration guards (R-07/R-08/R-12/R-14
mechanics), and test surface (tests/pure, tests/js, in-SketchUp runner) — say which
proposed slices lack a feasible test strategy.

Deliver EXACTLY the 10 output sections from source-pack §7. Do not implement anything.
Do not redesign the system. Findings without a concrete file/symbol reference are
downgraded to speculation.
```

---

## PROMPT 2 — GLM (nezávislý architecture/data-flow audit; číta LEN GitHub repo)

*(Michal spúšťa ručne. GLM nemá lokálny prístup — všetky odkazy sú GitHub URL na `main`.)*

```
You are an independent senior architecture reviewer. You can ONLY read files from this
GitHub repository (branch main): https://github.com/michalmoronga-alt/noxun-panel

Read first, in this order:
1. SYSTEM/zdroje/next_sessions/KOVANIE_CROSSAUDIT_2026-09-01_SOURCE_PACK.md
   — the audit input: mission ("break the proposal, don't redesign the system"), closed
   user decisions, the Round 2 proposal under audit (§5), targeted attack areas (§6),
   required output format (§7), source-discipline tagging (§0). Follow it exactly.
2. SYSTEM/zdroje/next_sessions/KOVANIE_TECHNICAL_AUDIT_CHECKPOINT_2026-09-01_10_VENDOR_MATRIX.md
   — verified vendor data with confidence tags.
3. Architecture docs: docs/ARCHITEKTURA.md · docs/architecture/hardware.md ·
   docs/architecture/construction.md · docs/architecture/model-a-identita.md ·
   docs/architecture/outputs.md · SYSTEM/STANDARD.md
4. Code needed to verify §4 claims (read as many as capacity allows, prioritized):
   noxun_engine/modules/fronts.rb · noxun_engine/core/part_keys.rb ·
   noxun_engine/core/build_plan.rb · noxun_engine/core/hardware_rules.rb ·
   noxun_engine/core/hardware_sets.rb · noxun_engine/core/construction.rb ·
   noxun_engine/core/bom.rb · noxun_engine/core/validation.rb ·
   noxun_engine/ui/production_core.rb · noxun_engine/core/cabinet_builder.rb ·
   noxun_engine/core/templates.rb · noxun_engine/core/materials.rb

Your specific angle (this is YOUR focus, the other independent auditors have different
ones): ARCHITECTURE & DATA-FLOW COHERENCE AND VALUE-VS-COMPLEXITY. Attack §5 through the
8 areas in §6 with emphasis on: single source of truth for each datum across the flow
(front config → plan → config['hardware'] → BOM → expansion → outputs) — find any place
where two representations of the same fact can diverge; the recipe data schema (§5.4) vs
the 6 verified system datasets in checkpoint #10 — try to construct a real catalogue
configuration the schema cannot express without code branches; lifecycle coherence of
dormant config, snapshots and Active/Inactive; and false complexity — anything in the
proposal whose removal loses nothing for V1.

If a repo claim cannot be verified from the files above, mark it UNVERIFIED — do not
assume it. Deliver EXACTLY the 10 output sections from source-pack §7. Do not redesign
the system; do not expand scope.
```

---

## PROMPT 3 — OPUS (BLIND architecture audit; subagent s read-only prístupom k repu)

*(Blind = dostane výhradne source pack + repo. Žiadne výstupy Codexu/GLM, žiadny
konsenzus, žiadne zmienky, že iné audity existujú alebo čo našli.)*

```
You are an independent senior architect performing a pre-implementation design audit.
You have read-only access to the repository working copy. Work strictly from the
materials below and your own inspection of the code — no other reviews exist for you.

Read first, in this order:
1. SYSTEM/zdroje/next_sessions/KOVANIE_CROSSAUDIT_2026-09-01_SOURCE_PACK.md — the audit
   input: problem, closed user decisions (constraints), the architecture proposal you
   must try to break (§5), targeted attack areas (§6), required output format (§7),
   source-discipline tagging (§0).
2. SYSTEM/zdroje/next_sessions/KOVANIE_TECHNICAL_AUDIT_CHECKPOINT_2026-09-01_10_VENDOR_MATRIX.md
   — verified vendor data with confidence tags.
3. docs/ARCHITEKTURA.md + referenced docs/architecture/*.md sections, SYSTEM/STANDARD.md,
   then the code files named in source-pack §4.

Treat the proposal in §5 as a hypothesis, not a conclusion: your job is to find where it
fails — wrong production, data loss, wrong purchase, non-reproducible projects, or a
forced mid-implementation refactor. Re-verify §4 repo claims yourself before relying on
them. Give special weight to failure scenarios that survive the proposal's own tests and
guards (i.e. would ship silently).

Deliver EXACTLY the 10 output sections from source-pack §7. Do not implement, do not
redesign globally, do not expand scope beyond the 8 attack areas.
```

---

## Rozdiely medzi promptmi (zámer)

| | Codex | GLM | Opus (blind) |
|---|---|---|---|
| Prístup | lokálny repo read | LEN GitHub URL, explicitný zoznam súborov | read-only repo (subagent) |
| Fokus | implementovateľnosť proti reálnemu kódu, guardy, testovateľnosť slices | koherencia dátových tokov, jedna pravda, schéma vs 6 datasetov, false complexity | čistý pokus rozbiť hypotézu; tiché zlyhania, ktoré prežijú testy a brány |
| Vstupy | source pack + #10 + docs + kód | to isté cez GH | to isté |
| Čo NIKDY nedostane | výstupy GLM/Opus | výstupy Codex/Opus | výstupy a EXISTENCIU ostatných auditov |

Spoločné: identický source pack, identický výstupný formát (10 sekcií), identických 8
útočných oblastí, identická source discipline. Rôzne fokusy sú zámer — cieľom je
pokrytie rôznych tried chýb, nie hlasovanie.

## Postup po auditoch

Jedno reconcile kolo: konsenzus · nezhody · unikátne riziká jedného audítora · false
positives (odporúčania nekompatibilné s realitou repa) · finálne rozhodnutia pre
Michala (vrátane OPEN CONFLICT H6 a `drawer_no_fit`). Potom: UI mockup → detail fill →
implementačné dávky.
