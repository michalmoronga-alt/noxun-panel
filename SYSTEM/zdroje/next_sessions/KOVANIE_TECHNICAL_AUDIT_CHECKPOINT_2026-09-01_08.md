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
- **Opening-mode confirmation:** Noxun uses both damped/classic (Silent System) and push-to-open variants for Atira.
- For the V1 manufactured-part recipe, opening mode does not create a separate box-geometry recipe. Treat opening mode as an orthogonal hardware/resolver axis that selects the appropriate runner/component set and installation data.
- **Height variant is a real recipe/data axis in V1.** Noxun requires at least these three Atira variants:
  - `H70`: wooden rear-panel height `65.5 mm` (production rounding/working value often `65 mm`); minimum internal clear/opening height `92 mm`.
  - `H144` with railing: wooden rear-panel height `144 mm`; minimum internal clear/opening height `192 mm`.
  - `H176` with railing: wooden rear-panel height `176 mm`; minimum internal clear/opening height `224 mm`.
- The same broad concept is expected later for Blum metal-sided systems: height variant changes rear-panel/railing/component data and minimum required vertical space, but should remain a data-driven recipe axis rather than a new resolver family.
- Exact Hettich nomenclature and minimum-space figures still require official-catalog cross-check before implementation; current values above are user-confirmed Noxun production inputs.
- **NL coverage decision:** Atira is a high-frequency Noxun system and V1 should support the complete applicable catalogue length set, not only a narrow Noxun whitelist. Resolver should normally choose the longest technically compatible nominal length from available space, with manual override retained.
- Current Hettich InnoTech Atira planning/catalogue data lists the main nominal-length sequence `260 / 300 / 350 / 420 / 470 / 520 / 620 mm`. Exact availability must still be validated per selected height/profile/opening/component set because not every component presentation necessarily exposes every length.
- **Preferred/recommended lengths are optional scope.** A Noxun preferred list may later rank stocked / fast-delivery lengths ahead of other technically compatible lengths, but this is not a V1 requirement if it adds complexity.
- If preferred ranking exists and no preferred length fits, resolver may automatically select a technically compatible non-preferred length and mark it as outside preferred. It must not hard-block or require confirmation merely because a valid length is non-preferred.
- Therefore the V1 technical compatibility model must remain independent from stock/delivery preference. The preferred layer may be added later without changing recipe identity or compatibility rules.
- Stock/order history must not be interpreted as technical compatibility: Atira was underrepresented in the seed because Noxun had previously purchased large industrial packs of H70/H176 components.
- **Confirmed load-class intent:** 30 kg is the standard Atira choice; 620 mm uses the 50 kg runner; 470/520 mm may also use 50 kg when required and cheap to support. User correction: the earlier mention of 60 kg was a mix-up with Blum TANDEM, not Atira.
- Current/recent Hettich data found in research exposes the same 30 kg / 50 kg Atira load classes; no Atira 60 kg support is required.

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
- **Opening-mode confirmation:** Noxun uses both damped/classic and push-to-open variants for Quadro; the same is true for Blum TANDEM (BLUMOTION/classic and TIP-ON).
- For the V1 manufacturing recipe, opening mode does **not** change the base manufactured box geometry for the cited Quadro EB23 and TANDEM profiles. Width/length box formulas stay on the same system recipe.
- Opening mode still changes mechanical/system data: concrete runner/SKU, installation/drilling details, front gap/trigger requirements, possible synchronisation, and in some variants required cabinet depth or attachment dimensions. Therefore opening mode belongs to hardware/resolver data, not to a duplicated manufactured-part recipe.
- Hettich Technical Assistant exposes separate Quadro V6 EB23 installation instructions for Silent System and Push to open, supporting this separation of same box family vs different runner installation.
- Current Blum TANDEM data likewise keeps `SKW = LW - 42` and `SKL = NL - 10` for the cited standard 11-16 mm BLUMOTION and TIP-ON variants, while TIP-ON adds trigger/front-gap and related installation requirements.
- Audit still required: verify exactly which component dimensions change with 16 vs 18 mm while the EB23 runner installation geometry remains fixed; do not assume every part formula is unchanged.
- Official Hettich data for classic Quadro V6 EB23 gives internal drawer width `SKW = LB - 46` and nominal drawer length equal to NL; min cabinet depth NL+13 for that classic V6 configuration.
- Other Quadro generations/variants differ (e.g. V6 5D / V6 YOU use internal width LB-42 and drawer length NL-10), so runner variant MUST remain a future data axis even if V1 fixes the current profile.
- Blum TANDEM standard planning uses `SKW = LW - 42` and `SKL = NL - 10` for the cited hook/locking-device variants, confirming the same broad computational family but not identical constants to classic Quadro V6 EB23.

## Procurement / supplier packaging distinction

User added an important Demos procurement reality:
- Some drawer configurations are purchasable from Demos as one complete commercial set with one supplier/order code.
- Other configurations must be purchased as multiple separate products/SKUs: e.g. runner(s), drawer side profiles, rear-panel holders/connectors, railing/connectors, etc.

Architectural implication (provisional but strong):
- A **logical Engine hardware set / recipe result** is not the same thing as a **supplier packaging SKU**.
- The logical set should describe the required mechanical result/components for one owner.
- Procurement expansion may resolve that requirement either to:
  1. one bundled supplier SKU/kit, or
  2. several atomic supplier SKUs and quantities.
- Therefore do not force `hardware_set == one catalog item` and do not duplicate geometry/rule logic merely because the supplier sells one variant as a kit and another as individual components.
- Canonical purchasing aggregation remains by concrete purchasable SKU after expansion, with owner/provenance retained.
- Stage-2 audit should inspect representative Demos cases and determine the smallest data representation for `bundle/kit vs atomic components`; reuse existing `hardware_expansion` / purchasing provenance machinery where possible rather than inventing a parallel BOM.

## Architectural interpretation — provisional only

Two useful computational families remain:
1. METAL_BOX_DRAWER — Atira as V1 archetype, later StrongBox / TANDEMBOX Antaro via different component sets + formula parameters.
2. WOOD_DRAWER_UNDERMOUNT — Quadro as V1 archetype, later Blum TANDEM via different runner/component data + formula parameters.

Important: do NOT infer that Quadro and TANDEM have identical formulas. They share the same kind of recipe, but runner-specific constants/axes differ.

Important: opening mode is an orthogonal hardware axis for both V1 drawer archetypes. Do not fork the manufactured-part recipe merely because the runner is damped/classic vs push-to-open.

Important: Atira `height_variant` is confirmed as a data-driven axis, with at least H70/H144/H176 in Noxun V1.

Important: preferred/stocked lengths are a soft ranking overlay only and can stay outside V1 if costly. Technical compatibility must not depend on the preference layer.

Important: supplier packaging (one complete kit SKU vs several component SKUs) is orthogonal to the logical hardware set/recipe. Resolve it in procurement expansion, not in manufactured-part geometry.

## Next audit work
1. Complete exact V1 Atira recipe: generated manufactured parts, dimensions, material/thickness, H70/H144/H176 rules, full applicable NL set, mandatory hardware SKUs, railing components, verified 30/50 kg load classes, and opening-mode-specific hardware/installation data.
2. Collect exact V1 Quadro EB23 recipe: four wooden box parts + bottom, dimensions, 16/18 mm thickness effects, NL, catches, load classes, opening-mode-specific runner/installation data.
3. Audit representative Demos packaging cases: same logical drawer requirement sold as one kit SKU vs assembled from multiple SKUs; propose minimal data model compatible with existing hardware expansion/provenance.
4. Compare StrongBox and TANDEMBOX Antaro against Atira to identify true shared parameters vs system-specific branches.
5. Compare Blum TANDEM against Quadro EB23 to identify shared recipe fields vs runner-specific constants.
6. Only then decide derived part keys / owner relationship / BuildPlan integration.

## Evidence status
- User production choices: confirmed by user, 2026-09-01.
- Atira formulas: confirmed by user-supplied Hettich sheet and official Hettich catalogue.
- Atira 16 mm bottom + 16 mm wooden rear panel: confirmed by user, 2026-09-01.
- Atira Silent System + Push-to-open use in Noxun: confirmed by user, 2026-09-01.
- Atira H70/H144/H176 production height data: confirmed by user, 2026-09-01; official catalogue cross-check still required before implementation lock.
- Atira complete-NL V1 intent: confirmed by user, 2026-09-01.
- Atira preferred/recommended list explicitly optional / outside V1 if complex; valid non-preferred automatic fallback allowed: confirmed by user, 2026-09-01.
- Main Atira nominal-length sequence `260/300/350/420/470/520/620`: current/recent official Hettich InnoTech Atira catalogue/planning data; compatibility must still be validated per concrete selected component profile.
- Atira 30/50 kg official load classes: current/recent Hettich data; 620 = 50 kg in cited data, 470/520 = 30 or 50 kg. User confirmed 2026-09-01 that the earlier 60 kg mention was a mix-up with Blum TANDEM.
- Supplier packaging distinction (some Demos configurations one code, others multiple component products): confirmed by user, 2026-09-01; exact representative Demos SKUs still require audit.
- Quadro EB23 profile / width: official Hettich runner documentation.
- Quadro default 16 mm and supported 18 mm box material: confirmed by user, 2026-09-01.
- Quadro box construction and Excel dimensions: confirmed by user, 2026-09-01.
- Quadro bottom offset 12-13 mm: official Hettich technical assistant sheet.
- Quadro Silent System + Push to open use in Noxun: confirmed by user, 2026-09-01; separate official Hettich EB23 installation instructions verified.
- TANDEM BLUMOTION/classic + TIP-ON use in Noxun: confirmed by user, 2026-09-01.
- TANDEM bottom offset 11-13 mm and same cited base box formulas across BLUMOTION/TIP-ON profiles: official current Blum technical catalogue.
- TANDEM formulas: official Blum technical catalogue.
