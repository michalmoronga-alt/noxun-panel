# KOVANIE — technical audit checkpoint 2026-09-01 #08

Working research checkpoint. NOT implementation spec.

## C10 — derived drawer parts: AUDIT FIRST

Decision: do not lock derived-part identity/model yet. First collect real system formulas and compare the computational families, then decide how recipes should emit manufactured parts and hardware into current BuildPlan/BOM/ABS/VEPO pipeline.

## User-confirmed production profile

### InnoTech Atira
- Noxun uses the wooden rear-panel variant (no metal rear-panel variant for current V1 production profile).
- Cabinet body side thickness is normally 18 mm.
- Use Hettich installation width `EB = 10.5` for this profile.
- User supplied a Hettich calculation sheet; it agrees with the official Atira planning data.
- For the shown wooden rear-panel configuration:
  - bottom length `BL = NL + 10`
  - bottom width `BB = LB - 2*EB - 51.5`
  - rear panel width `RB = LB - 2*EB - 63`
- Hettich mapping on the supplied/official sheet:
  - KD 16 -> EB 12.5
  - KD 18 -> EB 10.5
  - KD 19 -> EB 9.5
- For Noxun V1, EB can therefore be fixed to 10.5 unless later requirements justify exposing the axis.
- **Confirmed production rule:** bottom material thickness = 16 mm and wooden rear-panel thickness = 16 mm for Atira V1.

### Quadro V6 EB23 / TANDEM family
- User correction: Quadro width calculation depends on the selected runner / installation width EB.
- For V1, keep this simple and fix Quadro to the most-used classic `Quadro V6, EB = 23` profile.
- **Confirmed construction:** inner front and rear are between the two drawer sides. The bottom is also between the drawer sides; user drawings + Excel show the bottom extending the full nominal drawer length below the inner front/rear rather than being shortened between them.
- **Confirmed production rule:** Quadro EB23 wooden drawer box normally uses 16 mm material for all five manufactured box parts (left/right side, inner front, rear, bottom).
- **Supported but less-used variant:** the Quadro EB23 box can also be made from 18 mm material. V1 data/model must therefore not hardcode `Quadro = 16 mm`; 16 mm is default, 18 mm remains valid.
- Official Hettich meaning relevant to the recipe: `SKW` is the clear/internal drawer width, not the assembled outside width. For EB23, `SKW = LB - 46`.
- This explains the user's real Excel example exactly:
  - cabinet external width = 950 mm,
  - cabinet sides = 18 mm -> clear cabinet width `LB = 950 - 2*18 = 914 mm`,
  - Quadro EB23 -> `SKW = 914 - 46 = 868 mm`,
  - NL = 450 mm,
  - total chosen drawer side height = 130 mm,
  - produced 16 mm parts in the spreadsheet:
    - bottom: `868 x 450`, qty 1,
    - rear: `868 x 102`, qty 1,
    - inner front: same as rear `868 x 102`, qty 1,
    - side: `450 x 130`, qty 2.
- Because `SKW = 868` is the clear width between side panels, 16 mm drawer sides yield assembled outside width 900 mm; inside a 914 mm clear cabinet this leaves 7 mm per side externally. `EB 23 = 7 + 16`, which is internally consistent. With 18 mm drawer sides, the same SKW gives 5 mm external clearance per side and `EB 23 = 5 + 18`.
- **Provisional inference from the user's 130 -> 102 example:** front/rear height follows `H - bottom_thickness - bottom_vertical_offset`. With 16 mm material, `130 - 16 - 12 = 102`, strongly indicating a 12 mm lower bottom offset for the Noxun construction. This is NOT yet locked until user explicitly confirms the 12 mm production setting.
- Official Hettich data for classic Quadro V6 EB23 gives nominal drawer length equal to NL and minimum cabinet depth NL+13 for the cited slide-on configurations.
- Other Quadro generations/variants differ (e.g. V6 YOU uses internal width LB-42 and drawer length NL-10), so runner variant MUST remain a future data axis even if V1 fixes the current profile.
- Blum TANDEM standard planning uses `SKW = LW - 42` and `SKL = NL - 10` for the cited hook/locking-device variants, confirming the same broad computational family but not identical constants to classic Quadro V6 EB23.

## Architectural interpretation — provisional only

Two useful computational families remain:
1. METAL_BOX_DRAWER — Atira as V1 archetype, later StrongBox / TANDEMBOX Antaro via different component sets + formula parameters.
2. WOOD_DRAWER_UNDERMOUNT — Quadro as V1 archetype, later Blum TANDEM via different runner/component data + formula parameters.

Important: do NOT infer that Quadro and TANDEM have identical formulas. They share the same kind of recipe, but runner-specific constants/axes differ.

The Quadro example strengthens the recipe model: `EB`, runner variant, nominal length, drawer material thickness, chosen drawer height, and bottom vertical offset are recipe parameters; generated manufactured parts should be ordinary manufacturing outputs, not manufacturer-specific special entities.

## Next audit work
1. Confirm the Quadro V6 EB23 bottom lower offset used by Noxun (Excel example implies 12 mm).
2. Collect exact V1 Atira recipe: generated manufactured parts, dimensions, height variants, NL variants, opening-mode impact, mandatory hardware SKUs.
3. Complete exact V1 Quadro EB23 recipe: 16/18 mm thickness effects, height rule, catches, opening-mode differences, runner SKUs.
4. Compare StrongBox and TANDEMBOX Antaro against Atira to identify true shared parameters vs system-specific branches.
5. Compare Blum TANDEM against Quadro EB23 to identify shared recipe fields vs runner-specific constants.
6. Only then decide derived part keys / owner relationship / BuildPlan integration.

## Evidence status
- User production choices: confirmed by user, 2026-09-01.
- Atira formulas: confirmed by user-supplied Hettich sheet and official Hettich catalogue.
- Atira 16 mm bottom + 16 mm wooden rear panel: confirmed by user, 2026-09-01.
- Quadro EB23 profile / `SKW = LB - 46`: official Hettich documentation.
- Quadro default 16 mm and supported 18 mm box material: confirmed by user, 2026-09-01.
- Quadro construction and 950/450/130 -> 868/450/102 example: confirmed by user's drawings and Excel screenshot, 2026-09-01.
- Quadro 12 mm lower-bottom offset: inferred from user example + compatible with Hettich geometry; awaiting explicit user confirmation.
- TANDEM formulas: official Blum technical catalogue.
