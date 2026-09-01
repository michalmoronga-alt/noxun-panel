# CROSS-AUDIT VÝSLEDOK — BLIND OPUS (2026-09-01)

> Zverejnené po dobehnutí všetkých troch auditov (blind protokol dodržaný — audítori sa navzájom nevideli).
> Audítor: Opus subagent, read-only repo, source pack + checkpoint #10, bez vedomia o iných auditoch.

## 1. VERDICT

**SOUND WITH CHANGES.** Jadro (kompozičné osi + dátové recepty + reuse hardware_sets/expansion/brán) útok prežilo — §5.5 kit-vs-atomic výslovne potvrdené, nový BOM subsystém netreba. Nezlyháva architektúra, ale **migračná a autoritná vrstva** okolo nej: F-1, F-2, F-3, F-5 každé produkuje zlý nákup, zlý dielec alebo ticho zmenenú starú zákazku — a každé by prežilo navrhované testy aj brány. Slices A, C, D v aktuálnom znení nie sú bezpečné na štart; B, E–I áno.

## 2. CRITICAL FINDINGS

**F-1 · Recepty bez verzie a snapshotu → každý update pluginu ticho prereže staré zákazky.** HardwareRules aj HardwareSets čítajú VÝHRADNE projektový snapshot na modeli (`ensure_project_rules!` / `ensure_project_state!`, invariant „snapshot sa NIKDY nemení sám"). Repo-resident recipe pack nemá ani jedno — prestavba augustovej zákazky po korekcii receptu zmení bottom_length/rear_height/min-height/NL bez markera a diffu. Nie hypotéza: checkpoint #10 už koriguje H70 min. výšku ~92→105/106/108 a nesie 8 otvorených PDF follow-upov. „Byte-identical" garancia §5.6 platí len pre PRVÝ release.

**F-2 · Legacy `slide` pravidlo ostáva v každom projekte → dvojitý nákup výsuvov.** `vysuvy-nl-podla-hlbky` (fit_series, drawer_front) je zmrazené v každom existujúcom projekte a nikdy sa samo nemaže. Resolver z §5.1 emituje vlastný `slide` — `BuildPlan.validate_hardware!` NEvynucuje unikátnosť trojice (owner, generic_type, rule_id), obe položky prežijú, `resolve_set_id` kľúčuje len na generic_type → obe expandujú do toho istého kitu a `add_row` ich sčíta. `per:'unit'` sa nededuplikuje. Každá zásuvka v každej starej zákazke = 2 kity.

**F-3 · Všetky živé D-93 NL zámky osirejú → ticho iná dĺžka výsuvu.** Override identita je trojica s `rule_id: 'vysuvy-nl-podla-hlbky'`; resolver s novým rule_id ich nenamatchuje — zámok zmizne bez šípky, bez ORANGE, bez manual badge. Zámky sú rozšírené, LEBO seed séria obsahuje **560, ktoré nie je Atira NL** (oficiálny rad 260/300/350/420/470/520/620): 600 hlboká skrinka → available_depth 597 → budget 587 → vyberie 560 → `nl_missing` ORANGE — jediná cesta k objednávke bol ručný zámok. Latentné navyše: `clearance: 10` vs oficiálne NL+15 (a 260→279/305 P2O).

**F-4 · Výška riadku čela ≠ svetlá výška interiéru — a kolíziu nič nezobrazí.** Fronts.layout kladie čelá cez `total_v = height − floor_height` od `z = floor_height + gap_bottom(2)`; interiér je `z_lo = floor+t` … `z_hi = height−t`. Spodný/vrchný riadok stráca `t − gap = 16 mm` pri 18 mm korpuse; + police/vodorovné priečky. Konkrétne: 190 mm riadok „prejde" na H144 (Platzbedarf 189/190/192), reálny priestor 174 — zásuvka sa nezmestí. **A ticho:** vyrábané sú len dno+chrbát; 144 mm zarga sa nikdy nekreslí (`render_hardware` kreslí len nohy) → vizuálna kontrola používateľa túto triedu chýb NEVIDÍ.

**F-5 · Nové roly lámu hrúbkový kontrakt.** `thickness_ok_for?` + `materialized_part` výnimkujú LEN front_door/drawer_front; `validate_material_thickness!` inak RAISE-uje. (a) Slice A: flap/cover_panel/false_front na 18.6/19 mm materiáli → celá skrinka sa nepostaví so zavádzajúcou hláškou. (b) Slice C: 18 mm drawer materiál → raise pre každý dielec zásuvky; alebo builder hrúbku adoptuje a Atira vzorce (validované len pre 16) sú ticho zlé.

**F-6 · `drawer_no_fit` bráni nesprávny výstup.** `export_blockers` chráni HW CSV + XLSX; **VEPO je zámerne vyňaté** — a práve VEPO je rezná objednávka za reálny materiál. Ak sa pri nevyriešenom recepte dielce emitujú, idú do VEPO bez ohľadu na bránu. Fail-closed bod musí byť pri DIELCOCH (vzor `part_skipped_degenerate`): nevyriešený recept neemituje NIČ.

## 3. IMPORTANT FINDINGS

- **I-1 ABS:** plošné „bez olepu, bez ORANGE" je zlé pre Quadro (2 viditeľné bočnice + vnútorné čelo drevené — ušli by neolepené bez varovania; `check_abs` pozná len FRONT_ROLES+free_panel). ABS rozhodnúť PER rolu.
- **I-2 `hardware_manual` zmaže prvý rebuild:** `CabinetBuilder.normalize` je uzavretý whitelist nad celým configom — návrh menuje len `template_config_from`. Chýba zápis do normalize + CONFIG_SCHEMA bump.
- **I-3 Šablóny nesú pol konfigurácie:** `template_config_from` nesie fronts, ale NIE hardware_overrides ani part_overrides; `add_template_hardware` s `allow_owner: false` zahadzuje `slide@front:...` per-front voľby. Osi v fronts cestujú, zámky nie → šablóna reprodukuje dizajn s INÝM kovaním. Kópia skrinky sa správa inak (nesie celý config).
- **I-4 Prepínanie typu už dnes ničí zámky:** `prune_none_front_overrides` maže hardware_overrides pre čelá prepnuté na `none` — v rozpore s H4 pamäťou; part_overrides naopak žijú večne. Treba JEDNO pravidlo.
- **I-5 Build warnings nemôžu byť RED:** `check_build` hardcoduje ORANGE — RED riadky §5.7 potrebujú novú cestu vo Validation.run.
- **I-6 Nové member kľúče = read-only knižnica na druhom PC:** MEMBER_KEYS whitelist → neznámy kľúč = strata → :read_only → prázdna knižnica → celý súpis bez kódov. `code_by_height` (slice B) aj D-109 pomer (slice G) to spúšťajú KAŽDÝ zvlášť → všetky zmeny schémy členov v JEDNOM bumpe; D-52 tvrdý predpoklad.
- **I-7 Zvislé priečky: ORANGE nestačí** — riadky čiel idú cez celú šírku, `available_width = w−2t` je cabinet-level; dno LB−2EB−51.5 v zvisle delenej skrinke = nevyrobiteľný dielec. Dáta sú v plan[:zones] — čítať svetlú šírku z LISTOVEJ zóny pretínajúcej riadok; priečka cez riadok = hard conflict.
- **I-8 available_depth vs vendor Mindest-Korpustiefe:** definičná pasca (vonkajšia vs vnútorná hĺbka = chyba až o hrúbku chrbta). Pomenovať pole v schéme + test.
- **I-9 EB nie je odvoditeľné z kontextu:** CONTEXT_KEYS nemá `thickness`; hw_ctx hrúbku nenesie. EB = súčasť SKU kľúča, hrúbka boku = explicitný vstup.

## 4. FALSE COMPLEXITY

1. **`code_by_height` zbytočné** — `param_bands` (param+bands min/max/code) to už vie (diskrétna výška = pásmo min==max); nový kľúč len spúšťa I-6. VYHODIŤ.
2. **`custom` v GENERIC_TYPES škodlivé** — ad-hoc riadky nejdú cez validate_hardware!/resolve_set_id, typ netreba; rozšírenie zbytočne mení guard_unknown_hardware (kedy starší plugin odmieta rebuild). Platiť len za `lift`.
3. **4-D matica dostupnosti over-built pre V1** — stačia 3 tabuľky: NL→loads, (výška,opening)→min_height, (NL,opening)→min_depth. Tvar rozšíriteľný, generál nestavať.
4. **Rear-type ako user os nie** — V1 len drevený; slot v schéme držať (+10 vs −3 = 13 mm chyba), UI os nie.
5. **`inner_supported` per systém netreba** — jedno engine pravidlo: internal variant nerezolvuje recept, hard conflict s vysvetlením.

## 5. MISSING MINIMUM

1. Recipe snapshot + `recipe_version` v projekte (zrkadlo ensure_project_rules!) + explicitné „Doplniť nové recepty" s diffom.
2. Písaný kontrakt autority `slide`: resolver claimuje ownerov, legacy fit_series sa deterministicky potláča s viditeľným warningom.
3. Migračné pravidlo D-93 zámkov (premapovať na resolver identitu, alebo hard conflict — nikdy ticho).
4. Hrúbka drawer materiálu ako VSTUP receptu validovaný proti systému (Atira len 16; Quadro 16/18) + thickness_ok_for?/materialized_part pre všetky nové roly.
5. ABS rozhodnutie per nová rola + rozšírenie Validation.
6. `hardware_manual` + nové kľúče do CabinetBuilder.normalize + CONFIG_SCHEMA bump.
7. Pomenovaná definícia hĺbky vs vendor min-depth; min_depth = f(NL, opening, príslušenstvo).
8. Charakterizačný korpus reálnych .skp (jeden s legacy slide snapshotom, jeden s NL zámkom) — bajtovo identické VEPO+CSV pred/po; fixtures, nie unit test.
9. RED kanál vo Validation mimo build-warning kanála.

## 6. V1 SCOPE VERDICT

**Atira + Quadro správne; všetkých 5 nie.** Delta per systém: antaro — TOB modul podľa CELKOVEJ hmotnosti vrátane obsahu = nový VSTUP, nie dátový riadok; C-výška nepotvrdená. TANDEM — konštanty per (runner × mounting), TIP-ON ~20 kg, 19 mm program UNCONFIRMED. Strong — všetko len SECONDARY z jedného ~2021 PDF, hrúbky/generácie UNCONFIRMED, P2O neexistuje. **Podmienka lacného „neskôr": kľúč receptu = (system, runner_variant, mounting, rear_type) OD PRVÉHO DŇA a PERSISTOVANÝ per čelo** — inak je pridanie TANDEMu schema migrácia každej zásuvky, nie data pack. Blocker proti Atira+Quadro nenájdený (najsilnejšie overené datasety — 2× OFFICIAL), podmienené vyriešením F-1…F-5 pred slice C.

## 7. VALIDATION VERDICT

**(A) Neurčený smer → COUNTERPROPOSAL (RED bez brány), HARDENED** — protirečí USER rozhodnutiu, finálne slovo Michal. Dôvody: brány blokujú „číslo v hotovom platnom dokumente" a smer v žiadnom bránenom súbore nie je; spätne by zablokoval VŠETKY živé zákazky (žiadne čelo dnes smer nemá a heuristiky sú zakázané); nákup aj rezy sú smer-nezávislé (Sensys handedness sa nastavuje pri montáži, žiadne direction-dependent SKU); brána, ktorej náprava nemení exportovaný súbor, učí používateľa bránam neveriť. **3 tvrdé podmienky:** RED nie ORANGE · ŽIADNA cesta v kóde nesmie Neurčený rozviesť na stranu (žiadny default) · brána pre-committed v registri a pristane v TEJ ISTEJ dávke ako prvý výstup nesúci smer.

**(B) drawer_no_fit → NIE export blocker.** Fail-closed na GEOMETRII: neemitovať dielce (part_skipped_degenerate vzor) + RED v Kontrole (nový kanál I-5) + slide do NEMAPOVANÉ sekcie CSV (existujúci vzor). Ak brána, tak export_confirmations (dvojklik), nie blockers. Navrhnutá brána nechráni peniaze (VEPO vyňaté — zlé dielce by odišli rezačovi), nie je analóg P0-2 (tam sa chyba nedá ukázať; tu je plne vysvetliteľná existujúcim kanálom), a blok celého nákupu kvôli jednej zásuvke = presne „brať platný výstup", čo P0-HF review #250 zamietlo.

## 8. IMPLEMENTATION RISK MAP

0 updater **MEDIUM** (tvrdý predpoklad, I-6) · A front layer **HIGH** (F-5, F-4, I-1, I-4, round-trip whitelisty, R-12 bump) · B katalóg+sety **MEDIUM** (všetky member zmeny v 1 bumpe, drop code_by_height) · C context+recepty+dielce **HIGH** (F-1/F-4/F-5, I-7/8/9; in-SU povinné) · D resolver+zámky+brány **HIGH** (F-2, F-3 — živé projekty; korpus fixtures PRED, nie po) · E lifty **MEDIUM** · F závesy **LOW** · G nohy+D-109 **MEDIUM** (D-109 = nový member kind → I-6, zliať do B bumpu) · H ad-hoc **LOW–MEDIUM** (I-2 + stale kód → missing degradácia) · I šablóny **MEDIUM** (I-3 — 🔧 nesmie tvrdiť, čo whitelist zahadzuje).

## 9. EXACT REPO REFERENCES (výber)

§4 claimy všetky potvrdené s 2 korekciami: BuildPlan identity trojica LEN dokumentovaná, unikátnosť sa NEvynucuje (F-2) · fronts unknown fields „sa nedropujú — nikdy sa nečítajú" (klient payload je zdroj). Kľúčové: `CabinetBuilder.validate_material_thickness!/thickness_ok_for?/materialized_part` (F-5) · `CabinetBuilder.normalize` (I-2) · `prune_none_front_overrides`/`prune_profile_overrides` (I-4) · `render_hardware` len nohy (F-4) · `Validation.check_build` hardcoded ORANGE (I-5) · `AbsRules.thicknesses_for` → `{}` (I-1) · `HardwareSets.member_code` param_bands (FC-1) · `incompatible_member?`/`assess_library_doc` (I-6) · `purchase_csv` NEMAPOVANÉ sekcia (7B) · `VepoExport.commercial_thickness` — 16 mm mimo 18/36 pásiem = vlastný bucket (očakávaná zmena tvaru, nie defekt) · seed séria obsahuje 560 + clearance 10 (`hardware_rules.rb SEED_RULES`) (F-3).

## 10. TOP 5 CHANGES

1. **Snapshot + verzia receptov do projektu** (zrkadlo ensure_project_rules!), explicitný update s diffom.
2. **Jedna autorita `slide` + migrácia D-93 zámkov** + charakterizačný korpus reálnych .skp pred slice D.
3. **Fail-closed z CSV na DIELCE** (neemitovať pri nevyriešenom recepte; drawer_no_fit von z export_blockers, max confirmations).
4. **Svetlý priestor z interiéru a listovej zóny, nikdy z riadku čela** (16 mm offset ako named test; priečka cez riadok = hard conflict — zarga sa nekreslí, oko ju nevidí).
5. **Nové roly first-class v hrúbkovom a ABS kontrakte pred prvým dielcom** (thickness_ok_for?/materialized_part/ABS per rola; hrúbka ako recipe input; hardware_manual do normalize + schema bump).

*(+2 škrty zadarmo: drop `code_by_height` — param_bands to vie; drop `custom` z GENERIC_TYPES.)*
