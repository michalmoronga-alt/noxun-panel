# KOVANIE V1 — FINÁLNA ARCHITEKTÚRA (2026-09-02)

> Stav: KONCEPT-FINAL — uzavretý podklad pre task packages (autorita dávky = package v SYSTEM/PLAN.md); neimplementovať priamo.

> **Status: FINAL po cross-audite.** Nahrádza §5 source packu (`KOVANIE_CROSSAUDIT_2026-09-01_SOURCE_PACK.md`)
> so zapracovanými zmenami R1–R12 z reconcile a rozhodnutiami Michala O1–O3 (2.9.2026).
> Je to PODKLAD pre task packages (package = autorita dávky, šablóna 1e) — žiadne ďalšie veľké návrhové kolo.
> Reťaz dokumentov: debata checkpointy 01–09 → orchestrator review → Round 2 → vendor matrix #10 →
> cross-audit (Codex/GLM/Opus) → RECONCILE → **tento dokument**.

## 0. Rozhodnutia Michala po reconcile (2.9.2026)

- **O4 (5.9.2026, KOV-C audit #18):** typy otvárania pre výsuvy AJ závesy sú LEN dva — **Tip-On (Push to open, P2O)** a **tlmenie (Silent System, SiSy)**;
  vendor variant **P2Os (Push to open Silent) sa nerieši a z dát receptov sa vyhadzuje** (Michal: „ešte som sa s ním nestretol"). Klasifikácia `opening_mode classic|tipon` ostáva.
  *Upresnenie 5.9. popoludní (KOV-C v2, checkpoint #19):* Tip-On kity Atira od Démosu sú vendor variant PTOs — recept `atira_p2o_v1` ich používa pod jediným typom „Tip-On“ a berie min. svetlú výšku PTOs (108/192/224); tretí typ otvárania nevzniká.
- **O1 = a:** Neurčený smer dvierok = RED v Kontrole hneď; exportná brána AŽ s prvým výstupom, ktorý smer
  reálne nesie (D-95/výrobné zadanie). Tvrdé podmienky: ŽIADNY default ani heuristika smeru nikde v kóde
  (ani preview/overlay); legacy configy bez poľa sa negatujú; brána je pre-committed v AUDIT_REGISTER
  a pristane v TEJ ISTEJ dávke ako prvý direction-consuming výstup.
- **O2 = a:** `drawer_no_fit` (a rovnaká trieda: owner bez resolved setu, priečka cez riadok zásuvky) =
  **tvrdý blocker** nákupného CSV + oboch cenových exportov + fail-closed emisia dielcov. VEPO sa negatuje
  (chráni ho fail-closed geometria).
- **O3 = a:** D-109 pomerový člen sa vo V1 NEIMPLEMENTUJE; výsledok (1 príchyt na začaté 4 nohy, per skrinka)
  dá druhé bands pravidlo na šírku korpusu (klipy 1/2 pri <1000/≥1000). Pomerová mechanika = R-05 po V1.

## 1. Control/data flow

```
čelo (fronts item: front_type · [opening_mode] · [direction] · [drawer klasifikácia])
  → Construction.build_plan
      → context_for(owner)  — čistá fn z INTERIÉRU a listovej zóny (§4)
      → drawer/lift resolver (recept = PROJEKTOVÝ SNAPSHOT dát, §3):
        najvyšší kompatibilný výškový variant + najdlhšia kompatibilná NL;
        manuálne osi = polia hardware_overrides (§5); legacy slide pravidlo POTLAČENÉ (§5.2)
      → emituje (a) výrobné dielce do plan.parts (§6), (b) hardware položky do plan.hardware
        (params: system, runner_variant, mounting, rear_type, NL, height_variant, load, opening)
      → nevyriešený recept NEEMITUJE dielce (fail-closed) + RED kanál (§8)
  → existujúca persistencia (config['hardware'] + parts)
  → Bom.collect (+ nový aditívny kľúč hard konfliktov, + hardware_manual kanál §9)
  → HardwareSets.expand (selector pásma → per-height sety → code_by_nl; §7)
  → Kontrola + brány (§8) → Nákup / Rozpočet / CP / VEPO
```

## 2. Dátová vrstva čela (slice A)

- `front_type`: dvierka · zásuvkové čelo · výklop · sklop · blenda — mapované na roly
  (front_door / drawer_front / flap / false_front); fronts.rb sa učí stavať flap a blendu;
  `thickness_ok_for?` + `materialized_part` rozšírené o VŠETKY nové roly (R6).
- Polia **scopované per typ** (GLM F4): `opening_mode` len pohyblivé čelá; `direction` len dvierka
  (dvojkrídlo auto Ľ+P; jednokrídlo default `Neurčený` — bez heuristiky, O1); blenda nemá ani jedno;
  zásuvka: `drawer` blok = **VÝHRADNE klasifikácia** (family, system, runner_variant, mounting pin
  `slide_on`, rear_type pin `wooden`, drawer_variant standard|internal) — ŽIADNE locks (R3).
- Round-trip cez 5 uzavretých ciest (normalize_items · config_to_params · normalize · cabinet_config ·
  template_config_from) + CONFIG_SCHEMA bump; per-path charakterizačné testy + starý-projekt test
  (bajtovo... presnejšie CONTENT-identické výstupy) = **exit kritérium slice A** (R11).
- Overlay smerov: prerušované čiary (> < ∧ ∨), blenda plné X; vzor grain_check (žiadny zápis, žiadne undo).
- Pamäť pri prepnutí typu: konfiguračné kľúče sa DRŽIA (vzor migrate_overrides) a pri návrate sa
  automaticky obnovia + prevalidujú (H4); zjednotiť s dnešným prune_none_front_overrides — JEDNO pravidlo
  pamäte, zapísané v package (Opus I-4).

## 3. Recepty (slice C) — dáta s projektovým snapshotom

> **PREKONANÉ 5.9.2026 (KOV-C package v2, checkpoint #19):** projektový snapshot receptov, `recipe_version` zmrazená v modeli, KD→EB/runner-variant mapa a `orderable` flag sa NEIMPLEMENTUJÚ. Recepty sú nemenné verzované JSON súbory (`atira_sisy_v1`…), čelo nesie `drawer.recipe_refs` (mapa systém|otváranie → recipe_id), EB je pevné per recept. Autorita = `SYSTEM/PLAN.md` KOV-C v2; tento odsek ostáva ako história.

- Recept = verzované dáta v repe (data pack Atira + Quadro; bez editora — H3). Pri stavbe sa recept
  **zmrazí do modelu** (zrkadlo `ensure_project_rules!`): `recipe_version` + použité konštanty; snapshot sa
  NIKDY nemení sám; update len explicitnou akciou s diffom (R1).
- Kľúč receptu: **(system, runner_variant, mounting, rear_type)** persistovaný per čelo (V1 piny:
  slide_on, wooden; UI os len system/family).
- Tvar dát (R8): vzorce W_eff = LB − 2×EB (EB ≡ 0 pre ne-Hettich) · **KD→EB/runner-variant mapa ako
  PIATY vstup** (hrúbka boku korpusu z cfg[:thickness]; EB patrí k SKU výsuvu) + orderable-stock flag ·
  `min_depth` ako **(NL × opening) tabuľka** (NL260: 279 SiSy / 305 P2O) · availability matica
  NL × výška × load × opening VRÁTANE opening×load interakcií · min. výšky per (variant × opening)
  z OFICIÁLNYCH hodnôt (H70 = 105/106/108 — NIE 92!) · sync tyč P2O: trigger width>600, dĺžková položka
  za bránou R-06a · `internal` variant: JEDNO engine pravidlo — nerezolvuje recept, hard conflict (§8).
- Hodnoty výhradne z checkpoint #10 s tagmi; UNCONFIRMED sa do dát nedostane (PDF follow-up najprv).

## 4. context_for(owner) (slice C)

Čistá funkcia, žiadna perzistencia: zvislý priestor = prienik z-intervalu riadku čela s interiérom
(z_lo = floor+t, z_hi = height−t, rail_geometry) A listovou zónou; **16 mm offset riadok-vs-interiér =
named test case** (Opus F-4). Svetlá šírka z LISTOVEJ zóny pretínajúcej riadok (nie w−2t); svetlá hĺbka
back_front_y — pomenovať v schéme, ktorú hĺbku porovnávame s vendor Mindest-Korpustiefe (GLM I8/I-8).
Kontrola prieniku so shelf + divider_h + divider_v: **divider pretínajúci riadok zásuvky = RED/blocker
trieda (O2)**; tesné-ale-platné = ORANGE. Quadro box výška = available − clearance (40 default, recept
parameter) s ručným override; Atira variant = najvyšší bezpečne kompatibilný (H70/H144/H176; H54 sa
neponúka automaticky).

## 5. Resolver, zámky, pravidlá (slice D)

1. **Zámky výhradne v `hardware_overrides`** — rozšírené osové polia (nominal_length existuje; + height_variant,
   load...), D-93 sémantika zámok=existencia poľa; reset/zber/jantárové riadky/UI = existujúce cesty (R3).
2. **Exkluzivita slide (R2):** engine potláča fit_series/slide pravidlá pre drawer-klasifikované čelá
   (s viditeľným build warningom); test „jedno zásuvkové čelo → presne jedna slide položka".
   **Migrácia D-93 zámkov**: nominal_length na rule_id `vysuvy-nl-podla-hlbky` sa premapuje na resolver
   identitu, alebo hard conflict — nikdy tiché zmiznutie. Dávka D štartuje AŽ nad korpusom reálnych .skp
   fixtures (jeden s legacy snapshotom, jeden s NL zámkom).
3. Resolver nikdy nemení potichu: kompatibilná zmena = aplikuj + status diff; zamknutá hodnota kompatibilná =
   drž; nekompatibilná = konflikt + návrh náhrady + potvrdenie (náhrada ostáva zamknutá). Bez diff-modal
   frameworku — status + Kontrola.
4. Defaulty: globál → projekt → čelo per (front_type × opening_mode); auto-výber kompatibilného setu.
5. Závesy: jedno pravidlo MAX(výška, hmotnosť) — nový rule kind max-dvoch-pásiem; hmotnosť = rozmery ×
   density_for (typ) — hustota chýba → konzervatívny odhad + ORANGE, nikdy ticho; override počtu = zámok;
   šírka len WARNING. Úchytka: 1 ks/krídlo pri classic (pravidlo vypínateľné); Tip-On: P2O záves + presne
   1 piest/krídlo (per:'owner').

## 6. Odvodené dielce zásuvky (slice C)

part_key `front:<id>/drawer_bottom` · `/drawer_back` · `/box_side:left|right` · `/drawer_inner_front`;
nové ROLES + plan_schema bump + material signals enum + `human_label` vetvy (Codex I3/I4). Regenerate
pattern — deterministická prestavba, žiadna inkrementálna správa; overridy cez part_overrides (prežívajú).
**Materiál = štvrtý kanál `:drawer`** (R6): 4. PROJECT_KEY + nemazateľný fallback, eff_drawer,
D-46 pending-confirmation reuse; hrúbka = VSTUP receptu validovaný proti systému (Atira len 16;
Quadro 16/18). ABS: rozhodnutie PER rola (mechanika default-nič zadarmo; viditeľné bočnice Quadro boxu =
produktová otázka v detail fill). BOM/VEPO/kusovník automaticky. Atira emituje PRESNE dno + drevený chrbát;
čelo sa nikdy neemituje druhýkrát.

## 7. Sety a procurement (slice B + D)

- Klasifikácia setov (typ použitia · opening · konštrukcia zásuvky · výrobca · rada; kontrolované zoznamy,
  `+ Vytvoriť`; auto-návrh mena) — **VŠETKY zmeny schémy setov/členov v JEDNOM std bumpe** so snapshot_std
  obsahovou detekciou v tej istej dávke (R11). Starý neklasifikovaný set = plnohodnotný „nezaradený".
- **Kit výber BEZ nového tvaru člena (R4):** mapping selector pásma na height-variant parame → per-height
  SETY; vnútri kit člen cez code_by_nl; atomic = multi-member set. Member XOR kontrakt nedotknutý.
  `code_by_height` NEEXISTUJE.
- Lifecycle: Active/Inactive + projektový snapshot + „dostupná novšia verzia" (record_rev vzor).
- Agregácia podľa SKU + pôvod = existujúca hardware_expansion + D-94; nohy: bands podľa sokla (existuje) +
  klipy = druhé bands pravidlo na šírku (O3).
- Editor: jeden „+ Pridať člena" (Ako sa určí kód? / Koľko?) + živý náhľad expanzie; modaly; katalóg
  Kategória→Výrobca→Rada.

## 8. Validácia a brány (slice D)

> **UPRESNENIE 5.9.2026 (KOV-C v2):** `drawer_kit_missing` (receptová zásuvka bez setu/kódu pre svoju NL) blokuje AJ VEPO — dielce zásuvky (BL = NL + 10, boky = NL) bez kitu tej NL sú nepoužiteľné; VEPO výnimka platí len pre konflikty stavby, ktoré skončili fail-closed bez dielcov. Sync tyč P2O je vo V1 ORANGE (ad-hoc set), nie blocker.

- **Nový ADITÍVNY collected kľúč** pre hard hardware konflikty (precedens identities/cabinet_set_conflicts);
  čitatelia: Kontrola (RED) + brána; prepočet ČERSTVÝ pri exporte, nikdy z DOM (R9). Build-warning kanál
  ostáva ORANGE-only.
- **Fail-closed geometria:** nevyriešený recept/interná zásuvka/priečka cez riadok → ŽIADNE dielce
  (part_skipped_degenerate vzor) → VEPO chránené bez brány.
- **Tvrdé blockery (O2), rozšírenie export_blockers:** drawer_no_fit · owner bez resolved setu (hard
  conflict §06) · priečka cez riadok zásuvky · chýbajúca povinná sync tyč (P2O>600, kým je dĺžková) —
  blokujú HW CSV + rozpočet XLSX + CP XLSX; hláška menuje zásuvku, dôvod a kam kliknúť; exporty pri
  blockeri dokazujú PRÁZDNY cieľový priečinok (test).
- **Smer (O1):** RED nález (nový kanál), ŽIADNA brána; brána pre-committed v AUDIT_REGISTER, pristane
  s prvým direction-consuming výstupom (D-95); legacy configy vyňaté; nikde žiadny default smeru.
- ORANGE: zamknutá hodnota pod minimom (pri exporte potvrditeľná — existujúci dvojklik) · tesné prieniky ·
  soft odporúčania. Kontrola = navigátor (select + focus_inspector + otvorenie sekcie + highlight).
- do_hw_csv navyše: blocker pri generic typoch neznámych tomuto pluginu (BuildPlan.unknown_generic_types)
  ALEBO version-pair viditeľnosť ako akceptácia D-52 (GLM I7).

## 9. Ad-hoc kovanie (slice H) — variant A s vlastným kanálom

`config['hardware_manual'][]`: {owner_part_key|nil, source: catalog|free, code?, name, qty, mj, price_eur?,
note}. **Vlastný pass-through kanál** — expand vetví podľa PÔVODU poľa pred set rezolúciou; ŽIADEN generic_type
`custom` (R5). Serverová normalizácia + qty limity; plný snapshot code/name/mj/price aj pri katalógovej
položke; stale kód → `missing` flag (row_join vzor); owner join odfiltruje mŕtve kľúče (collect_manual_overrides
vzor); explicitné template pravidlo; zahrnutie do duplicate-ID konfliktu; `hardware_manual` v normalize +
CONFIG_SCHEMA bump. „Uložiť do katalógu" bridge = po V1.

## 10. Šablóny (slice I)

Explicitné „Uložiť aj kovanie" + 🔧 badge nad existujúcim freeze mechanizmom; **🔧 nesmie tvrdiť, čo whitelist
nenesie** — package rozhodne: preniesť relevantné drawer overridy do šablóny, alebo priznať v read-only detaile
(R12). Skrytá pamäť neaktívnych konfigurácií sa do šablóny neukladá (checkpoint #04).

## 11. Migrácia a bezpečnosť starých zákaziek

Aditívne polia s defaultmi; bumpy existujúcich guardov: CONFIG_SCHEMA (R-12) · sets std (R-07, jeden bump) ·
rules STD/SEED_VERSION (sety seedované Z recipe NL série + completeness test — GLM M6) · plan_schema +
GENERIC_TYPES **len +lift** + ROLES. Predpoklad: **D-52 updater nasadený PRED prvým bumpom** (H8), obe PC
rovnaká verzia. Výrobný výsledok starej zákazky sa NIKDY ticho nemení — charakterizačný korpus reálnych .skp
(legacy slide snapshot, NL zámok) porovnáva CONTENT výstupov pred/po.

## 12. Change map (delta k §5.9 source packu)

MODIFY navyše: materials.rb (PROJECT_KEYS + enum) · bom.rb (nový aditívny kľúč + hardware_manual) ·
part_keys.rb (human_label vetvy). NEROBÍ SA (potvrdené 3/3 + reconcile): FunctionalZone · assembly owner ·
recipe editor UI · Deprecated/revízne reťazce · diff-modal framework · paralelná validácia · per-brand hinge
moduly · plný per:'length' (R-05 po V1) · code_by_height · generic_type custom · D-109 ratio člen (R-05).

## 13. Slicing (potvrdené poradie + exit kritériá)

0 **D-52 updater** (tvrdý predpoklad) → A **čelá — dátová vrstva** [HIGH; exit: 5-cestný round-trip +
starý-projekt charakterizácia] → B **katalóg+sety klasifikácia a editory** [MEDIUM; exit: jeden std bump +
snapshot_std + downgrade testy] → C **context_for + recepty + odvodené dielce** [HIGH; in-SU povinné;
nesie R1/R6/R7/R8] → D **resolver + osi + zámky + brány** [HIGH; štart až nad .skp fixtures; nesie R2/R3/R9/O2]
→ E **výklopy HK/HL** [MEDIUM; +lift, hmotnosť z hustôt] → F **závesy + úchytka + TipOn** [MEDIUM] →
G **nohy 4/6 + klipy cez šírku + sokel pri vkladaní** [LOW po O3] → H **ad-hoc** [LOW–MEDIUM; hneď po A] →
I **šablóny 🔧** [MEDIUM; R12]. Mockup Čelá/Kovanie/Zóny PRED UI časťami A a B. Malé PR, brány podľa CLAUDE.md,
audit-povinnosť per dávka (kontrakt/schéma/migrácia = vždy).

## 13a. UI mockup — SCHVÁLENÝ (Michal, 2.9.2026)

`SYSTEM/zdroje/ui20/mockup_kovanie_v1.html` (4 scény: Čelá · Kovanie · Katalóg+sety · Kontrola) je od 2.9.2026
**záväzná UX referencia pre slice A/B/D/H** — Michal preklikal bez výhrad. Implementácia sa porovnáva 1:1 s mockupom;
odchýlka = vedomé rozhodnutie zapísané v package/PR, nie improvizácia.

## 14. Detail fill pred/počas implementácie (nie architektúra)

PDF follow-up list (#10, 8 bodov) · overiť H70 „92" v Michalových podkladoch (oficiálne 105/106/108) ·
Demos kit-vs-atomic reprezentatívne SKU · ABS viditeľných bočníc Quadro (produktová otázka) · prahy závesov
z tabuliek + hustotný fallback · presné texty hlášok · UI mockup zadanie.
