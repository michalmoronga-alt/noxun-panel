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

### Quadro / TANDEM family
- User correction: Quadro width calculation depends on the selected runner / installation width EB.
- For V1, keep this simple and fix Quadro to the most-used `EB = 23` profile.
- **Confirmed production rule:** Quadro EB23 wooden drawer box normally uses 16 mm material for all five manufactured box parts (left/right side, inner front, rear, bottom).
- **Supported but less-used variant:** the Quadro EB23 box can also be made from 18 mm material. V1 data/model must therefore not hardcode `Quadro = 16 mm`; 16 mm should be the default, while 18 mm remains a valid material-thickness variant.
- Confirmed Noxun assembly: left/right sides run full drawer length; bottom is between the sides and runs full nominal drawer length; inner front and rear are between the sides and sit above the bottom.
- User Excel example for outer cabinet width 950 mm, 18 mm cabinet sides, NL 450, drawer height 130:
  - internal cabinet width `LB = 950 - 36 = 914`
  - Quadro V6 EB23 internal drawer width `SKW = LB - 46 = 868`
  - 2x side = `450 x 130`
  - bottom = `868 x 450`
  - inner front = `868 x 102`
  - rear = `868 x 102`
- Official Hettich Quadro V6 EB23 drawing specifies bottom offset/range `12-13 mm`; Noxun can use `12 mm` as the V1 default while retaining the official range as technical data.
- For the 16 mm example, `102 = 130 - 16 - 12`, i.e. front/rear height = drawer height - bottom thickness - bottom offset.
- Official current Blum TANDEM planning shows a closely related bottom offset/range of `11-13 mm` for the cited 11-16 mm wooden-drawer variants. Do not assume it is exactly identical to Quadro; keep the offset as runner-family/system data.
- Audit still required: verify exactly which component dimensions change with 16 vs 18 mm while the EB23 runner installation geometry remains fixed; do not assume every part formula is unchanged.
- Official Hettich data for classic Quadro V6 EB23 gives internal drawer width `SKW = LB - 46` and nominal drawer length equal to NL; min cabinet depth NL+13 for that classic V6 configuration.
- Other Quadro generations/variants differ (e.g. V6 5D / V6 YOU use internal width LB-42 and drawer length NL-10), so runner variant MUST remain a future data axis even if V1 fixes the current profile.
- Blum TANDEM standard planning uses `SKW = LW - 42` and `SKL = NL - 10` for the cited hook/locking-device variants, confirming the same broad computational family but not identical constants to classic Quadro V6 EB23.

## Architectural interpretation — provisional only

Two useful computational families remain:
1. METAL_BOX_DRAWER — Atira as V1 archetype, later StrongBox / TANDEMBOX Antaro via different component sets + formula parameters.
2. WOOD_DRAWER_UNDERMOUNT — Quadro as V1 archetype, later Blum TANDEM via different runner/component data + formula parameters.

Important: do NOT infer that Quadro and TANDEM have identical formulas. They share the same kind of recipe, but runner-specific constants/axes differ.

## Next audit work
1. Collect exact V1 Atira recipe: generated manufactured parts, dimensions, material/thickness, height variants, NL variants, opening mode impact, mandatory hardware SKUs.
2. Collect exact V1 Quadro EB23 recipe: four wooden box parts + bottom, dimensions, 16/18 mm thickness effects, NL, catches, opening-mode differences, runner SKUs.
3. Compare StrongBox and TANDEMBOX Antaro against Atira to identify true shared parameters vs system-specific branches.
4. Compare Blum TANDEM against Quadro EB23 to identify shared recipe fields vs runner-specific constants.
5. Only then decide derived part keys / owner relationship / BuildPlan integration.

## Evidence status
- User production choices: confirmed by user, 2026-09-01.
- Atira formulas: confirmed by user-supplied Hettich sheet and official Hettich catalogue.
- Atira 16 mm bottom + 16 mm wooden rear panel: confirmed by user, 2026-09-01.
- Quadro EB23 profile / width: official Hettich runner documentation.
- Quadro default 16 mm and supported 18 mm box material: confirmed by user, 2026-09-01.
- Quadro box construction and Excel dimensions: confirmed by user, 2026-09-01.
- Quadro bottom offset 12-13 mm: official Hettich technical assistant sheet.
- TANDEM bottom offset 11-13 mm: official current Blum technical catalogue for cited variants.
- TANDEM formulas: official Blum technical catalogue.
