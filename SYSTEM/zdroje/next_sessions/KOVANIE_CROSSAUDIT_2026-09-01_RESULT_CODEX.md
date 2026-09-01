# CROSS-AUDIT VÝSLEDOK — CODEX (2026-09-01)

> Zverejnené po dobehnutí všetkých troch auditov (blind protokol dodržaný — audítori sa navzájom nevideli).
> Audítor: Codex CLI (gpt-5.6-sol, effort high), lokálny repo prístup, task-mtizkxnj-mf1ppr, 13m26s.
> Fokus: implementovateľnosť proti reálnemu kódu.

## 1. VERDICT

**UNSAFE** (v dnešnej podobe). Jadro použiteľné, ale pred implementáciou chýba päť výrobných kontraktov — hrozí neúplná objednávka, nesprávna geometria zásuvky a veľký refaktor počas implementácie setov.

## 2. CRITICAL FINDINGS

1. **Hrúbka materiálu vstupuje do výpočtu príliš neskoro.** Quadro 16/18 mm [USER]; `CabinetBuilder.build_into` (597-620) najprv plan, potom materiály; geometricky sa prispôsobujú len front_door/drawer_front (`validate_material_thickness!` 800-811, `materialized_part` 1419-1431) — inak raise. Quadro 18 mm sa nedá spraviť len cez `material: :drawer`; recept musí dostať VÝSLEDNÚ hrúbku pred zostavením dielcov, inak odmietnutý rebuild alebo zlé vnútorné rozmery.

2. **`code_by_nl + code_by_height` nekompatibilné s dnešným modelom člena.** Člen musí mať PRÁVE JEDNO z code/code_by_nl/param_bands (`validate_member` 2086-2110), `member_code` vykoná len jednu vetvu (1721-1749), `resolve_set_id` vyberá set podľa JEDINÉHO parametra (1636-1647). Bez presného kontraktu, kde sa tuple systém × NL × výška × opening × load mení na jedno SKU → zlý nákup alebo refaktor setov uprostred slice D.

3. **D-109 nie je „ďalší člen existujúceho setu".** PER_KINDS len unit|owner (105-109), expanzia materializuje po jednej položke (1689-1718); AUDIT_REGISTER R-05 (121-131) presne menuje chýbajúcu agregačnú fázu + zmenu provenance invariantu. „1 klip na začaté 4 nohy per cabinet" = najprv spočítať nohy, potom zaokrúhliť. Bez uzavretého tvaru člena + STD markera + provenance = major refactor slice B/G.

4. **Povinná P2O sync tyč môže vypadnúť z objednávky.** Pri P2O > 600 mm povinná [OFFICIAL]; návrh ju posiela cez R-06a ORANGE → `expand` ju presunie do `unmapped` (1608-1616, 1675-1687), ale `do_hw_csv` blokuje len duplicitných vlastníkov — unmapped NEblokuje a CSV sa zapíše (production_core 1424-1449). Nákupnému CSV môže chýbať povinný komponent. Kým nie je per:length: tento stav musí TVRDO blokovať objednávkové/cenové exporty, alebo P2O > 600 mimo V1.

5. **Recepty bez kontraktu reprodukovateľnosti.** Pravidlá aj sety majú projektový snapshot (`ensure_project_rules!` 337-345; snapshot kontrakt hardware_sets 62-78); receptové balíky nemajú identitu ani snapshot — oprava konštanty v novšom plugine po rebuilde zmení rozmery/SKU rozrobenej zákazky. CONFIG_SCHEMA chráni starší plugin pred novším configom, NIE projekt pred zmenou receptových dát novšej verzie.

## 3. IMPORTANT FINDINGS

1. **Formát part_key bezpečný, systémová semantika nie:** Atira aj Quadro zdieľajú `front:F1/drawer_bottom` → JEDEN slot v part_overrides; `resolve_part` (664-671) vyberá len podľa part_key bez family/system. Rozhodnúť: per-part override je spoločný medzi systémami, alebo zmeniť adresovanie.
2. **Template clone neprenesie manuálne overridy drawer dielcov:** `template_config_from` (payloads 347-373) zámerne nevkladá part_overrides — šablóna prenesie drawer config, dielce vzniknú s defaultmi; kópia skrinky ich prenesie (config_to_params).
3. **Nové drawer kľúče v UI surové:** `human_label` pozná len panel/wing/zone (89-103) — drawer_bottom/back/box_side potrebujú vetvu, inak provenance nečitateľná.
4. **BuildPlan zmena väčšia než ROLES:** validator povoľuje len material signals :korpus/:front/:concrete (193-202) — treba rozšíriť; `lift` áno, `custom` nie (ad-hoc nejde cez BuildPlan); owner musí ostať reálny diel planu.
5. **Whitelisty a STD brány = jedna atómová zmena:** front config whitelist preklápa neznámy typ na `door` (312-334!); cabinet config má ŠTYRI cesty rozšíriť spolu: normalize, cabinet_config, config_to_params, template_config_from.
6. **Klasifikácia setov = plný forward-compat rozsah:** polia súčasne v SET_KEYS/MEMBER_KEYS + detektor tvaru + normalizácia + validátor + editor + snapshot_std + template freeze (117-138, 411-469, 531-574, 1206-1212, 1416-1551, 2025-2111, 2194-2213) — inak starší plugin oreže alebo vlastný súbor vyhlási za read-only.
7. **Ad-hoc hardware potrebuje VLASTNÝ persistovaný kontrakt, nie merge do hardware:** navrhnutý tvar nemá generic_type/rule_id/production_class/BuildPlan source → neprejde cez expand/BuildPlan kontrakt. Najmenšia bezpečná cesta = samostatný pass-through kanál v zbere a expanzii: serverová normalizácia + limity · plný snapshot code/name/mj/price aj pri catalog položke · odfiltrovanie záznamu s neexistujúcim owner_part_key (join vzor collect_manual_overrides, bom 214-257) · explicitné template pravidlo · zahrnutie do konfliktu duplicitných cabinet ID.

## 4. FALSE COMPLEXITY

- `code_by_height` odstrániť — selector vie vybrať výškovo špecifický SET a člen potom code_by_nl; najprv uzavrieť ako klasifikácia vyberá presný set pre system/opening/load.
- `custom` z BuildPlan scope von — ad-hoc má samostatný kanál.
- Prázdne ABS pravidlá pre drawer roly netreba — neznáma rola už prirodzene vracia 4× nil (`thicknesses_for/resolve_edges` 282-292, 309-324); treba hlavne UI labely rolí.
- „Save to catalog" bridge pre ad-hoc odložiť.

## 5. MISSING MINIMUM

1. Stabilný, po vydaní nemenný recipe_id/verzia nesený drawer configom.
2. Pre-plan resolver výsledného drawer materiálu a hrúbky vrátane per-part override.
3. Kontrola prieniku drawer priestoru so VŠETKÝMI divider_v, divider_h AJ shelves (zone_tree 221-249, 257-284, 510-549) — nie len zvislou priečkou.
4. Presný kontrakt výberu jedného SKU z multi-axis tuple + D-109 ratio/provenance tvar so sets STD bumpom.
5. Serverový export-blocker z ČERSTVÉHO výsledku resolvera/expanzie, nie z DOM stavu.
6. Kanonický hardware_manual normalizátor, snapshot ceny, owner join, template/copy pravidlá.
7. Testovacia matica system/NL/height/opening/load/material × lifecycle rebuild→undo→copy→template→BOM/VEPO/export.

## 6. V1 SCOPE VERDICT

**Atira + Quadro, nie všetkých 5.** Strong = neúplné sekundárne podklady [UNCONFIRMED]; antaro/TANDEM = ďalšie opening×load interakcie, montážne varianty, iné príslušenstvo. Blocker ani pre Atira+Quadro nie je rozsah značiek, ale 4 spoločné švy: pre-plan hrúbka · výber SKU · exportná brána · reprodukovateľnosť receptu. Po ich uzavretí realizovateľné.

## 7. VALIDATION VERDICT

**Neurčený smer: RED v Kontrole, BEZ exportnej brány vo V1.** Tvrdá brána je výnimka pre súbor, o ktorom systém VIE, že bude číselne chybný; smer dnes nemení rezné rozmery ani nákupné množstvá — blok by zastavil staré živé projekty bez ochrany konkrétneho výstupu. Brána pribudne s prvým výstupom, ktorý smer spotrebuje.

**drawer_no_fit: TVRDÝ, nepotvrditeľný blocker HW CSV + oboch cenových XLSX.** Kontrola nestačí — `do_hw_csv` nevolá Validation.run a zapisuje aj pri unmapped (1415-1449). Blocker musí byť serverový, z toho istého čerstvého planu/expanzie, vyhodnotený pred UI.savepanel. VEPO neblokovať (rezné dielce validné; architektúra ho zámerne vyňala).

## 8. IMPLEMENTATION RISK MAP

0 updater HIGH · A front layer HIGH · B catalog/sets HIGH · C context/recipes/parts HIGH · D resolver/gates HIGH · E lifts MEDIUM · F hinges MEDIUM · G legs/D-109 HIGH · H ad-hoc HIGH · I templates HIGH. §5.10 dáva konkrétny testovací pokyn len pri C; A–I potrebujú stratégiu (vzory: su_runner 505-523, 1280-1315, 1563-1677 — rebuild, dedup, copy, template guardy, undo). Exporty musia dokazovať PRÁZDNY cieľový priečinok pri blockeri.

## 9. EXACT REPO REFERENCES

fronts.rb layout:40-82, panels_for:132-171, normalize_config:269-285, normalize_items:299-336 · part_keys.rb front:22-25, valid?:45-47, migrate_overrides:52-71, human_label:89-103 · build_plan.rb ROLES:83-90, GENERIC_TYPES:94-100, validate_part!:185-220, validate_hardware!:259-315 · cabinet_builder.rb build_into:597-643, resolve_part:664-721, validate_material_thickness!:800-811, materialized_part:1419-1431, rebuild_in_operation:438-465, dedup_copies:512-571, cabinet_config:1534-1587, normalize:1670-1715, config_to_params:1863-1903 · zone_tree.rb compute/walk:215-249, split_boxes:257-284, divider_desc/add_shelves:510-549 · hardware_sets.rb constants:86-138, guards:411-469+531-574, expand:1571-1618, resolve_set_id:1636-1647, expand_members:1689-1718, member_code:1724-1749, validate_member:2059-2111 · bom.rb collect:45-149, collect_manual_overrides:216-257, record:295-315, aggregate_rows:319-369 · production_core.rb hardware_expansion:736-776, dup_partition:854-866, export_blockers:982-999, export_confirmations:1028-1033, do_hw_csv:1415-1449, do_budget_xlsx:1890-1945, do_cp_xlsx:1959-2016 · payloads.rb template_config_from:347-374, add_template_hardware:382-399 · testy: test_build_plan.rb, test_fronts_shelves.rb, test_hardware_sets.rb, test_r12_config_schema.rb, su_runner.rb.

## 10. TOP 5 CHANGES

1. Uzavrieť JEDEN dátový kontrakt procurementu: multi-axis výber SKU, D-109 ratio fáza, provenance, sets STD/whitelist bump.
2. Drawer materiál a hrúbku vyriešiť PRED BuildPlanom + stabilná nemenná identita receptu.
3. context_for: detekcia prieniku so shelf + divider_h + divider_v; každý neanalyzovaný prienik = viditeľná ORANGE.
4. Serverové hard blockery pre drawer_no_fit, unresolved required set a povinnú length-cut položku pred savepanel; smer bez export gate.
5. Kompletný persistence/test kontrakt: front whitelisty, dormant overridy, hardware_manual, copy/dedup/templates, byte-identické staré projekty.
