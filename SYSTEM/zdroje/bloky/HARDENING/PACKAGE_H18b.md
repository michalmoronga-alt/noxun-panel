> **Autorizácia Michala (5.10.2026): „H18B opraviť“; „pokračovať“.** Q2 = oprava H18b-1, implementácia schválená.
> Q1 A a Q3 A ostávajú; H18b-2 sa nerobí. D-151/D-152 sú mimo scope. Povinná predrecenzia a in-SU brána ostávajú.

# PACKAGE H18b · Výber setu závesov pri krídle dvierok naozaj platí (D-150) — blok 9 HARDENING

> **Autorita:** Michal — otázka **Q2** z PACKAGE_H18 §13 výslovne schválená **5.10.2026**: „opraviť samostatnou dávkou H18b hneď po H18, aby výber pri
> krídle naozaj platil (výrobná dávka, test v SketchUpe)". **Q1** (voľba „podľa projektu" v riadku skrinky zmaže aj starý výber) bez odpovede → predvolené **A**
> (nič sa nemaže); variant **B** je **voliteľná časť H18b-2** s vlastným rozhodnutím Michala (§13). Nález: PACKAGE_H18 §14 F1 / **D-150**, sonda H18 S13,
> audit H18 **NOTE 7** („zápis `hinge@<wing>` so zachovanou klasifikačnou validáciou je správny smer; povoliť `class:hinge|…@wing` v parseri nestačí").
> **Trieda (§5):** **H18b-1** — výrobná/cenová **ÁNO** · audit návrhu **NIE** (kľúč, schéma, migrácia, observer ani undo sa nemenia — zdôvodnenie §5) · predrecenzia
> **povinná** · **in-SU = BRÁNA** (mení sa výsledok zápisovej akcie panela) · nový ovládací prvok **NIE** · fotky **NIE** · `codex-po-pr` bez výnimky.
> **H18b-2 (len pri Q1 B):** výrobná **ÁNO** · audit **ÁNO** (nový význam polí payloadu rozsahu skrinky + akcia „podľa projektu" maže druhý kľúč) · predrecenzia ·
> in-SU brána · `ui_foto -Record`.
> **Bez zmeny čísel:** zákazky, v ktorých nikto neurobí nový výber pri krídle — nákup, rozpočet, ponuka, VEPO, Kontrola a config **bajtovo rovnaké** (resolver sa
> nemení; goldeny H18 bez regenerácie + R0 nižšie). Mení sa **len výsledok akcie** „vyber set pri krídle" (a pri H18b-2 akcie „podľa projektu" na skrinke).
> **Verzia:** patch podľa mainu pri štarte + všetky `?v=` + prepis STAV.
> **Stav kódu:** sonda nad `main` **`fe7f5405`** (v0.17.24, po PR #460). **Predpoklad poradia:** pred H18b zmergujú **H16** (súpis knižníc — týchto súborov sa
> nedotýka, prienik len VERSION/`?v=`/STAV/KRONIKA/PLAN) a **H18** (Inspector ukazuje skutočne použitý set) — predpoklady o H18 sú výslovne v §5.1 (P1–P5).
> Čísla riadkov nižšie sú z `fe7f5405`; implementátor ich po H16/H18 prepočíta (`git diff fe7f5405..main -- <súbor>`).

---

## 0 · Sonda na kóde (headless, 2.10.2026)

Skript `scratchpad/HARDENING/sonda_h18b.rb` → `sonda_h18b_out.txt` (Ruby 3.2 cez `tests/helper.rb` = APPDATA sandbox; `Engine.log` zachytený do pamäte). Reálne
položky z `Construction.build_plan` (seed pravidlá) pre 4 skrinky: **TIP1** (1 krídlo Tip-On), **CLS2** (2 klasické krídlá), **FALL** (sklop — závesy na
`front:F1/flap`), **MIX** (F1 Tip-On + F2 dve klasické); projekt = seed (Tip-On → Záves P2O, klasické → Záves KLASIK, legacy `hinge` → KLASIK) + fixtúrne sety
`moj-zaves` (nezaradený, kód X1) a `blum-tipon` (Tip-On, kód B1). Reťaz: `apply_cabinet_override` → `CabinetBuilder.norm_hardware_sets` (čo prežije prestavbu) →
`HardwareSets.expand` (nákup) + `hw_set_status_msg` (hláška). **Prototyp opravy** (`ProtoH18b.apply` v skripte) = dnešné telo + jedna vetva (§6 R1).
Do modelu, repa ani `%APPDATA%` sa nič nezapisovalo.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | **Cesta z UI:** riadok krídla klasifikovaných dvierok (aj sklopu) je ponuka `compat.owners[<krídlo>]` — `class_compat_payload` ju emituje pre **každého** klasifikovaného vlastníka; JS pošle `{generic_type:'hinge', owner_part_key:<krídlo>, set_id}` akciou `set_hardware_set` | `payloads.rb:2294-2321`; `hardware.js:1131-1157`; `actions_hardware.rb:1062-1129` | PRAVDA |
| S2 | `apply_cabinet_override` zloží **`class:hinge|tipon@front:F1/wing:single`** (`override_class_key`, `:3075`) a starý **`hinge@<krídlo>` zmaže** ako „stale" (`:3080`, `:3083`, `:3109`) | `hardware_sets.rb:3052-3134`; sonda R1, R2 | PRAVDA |
| S3 | **Prestavba nový kľúč zahodí** (`norm_hardware_sets` → `parse_class_key`: owner triedny kľúč majú len `slide`/`lift`) s logom „výber na úrovni dielca má zatiaľ len výsuv zásuvky a výklop" → v configu **nič** | `cabinet_builder.rb:3707-3731`; `hardware_sets.rb:939`, `:951-961`; sonda R1–R7 | PRAVDA |
| S4 | **Hláška klame:** „Závesy pre dielec front:F1/wing:single: set „Blum Tip-On záves“." | `actions_hardware.rb:1317-1326` | PRAVDA |
| S5 | **Nákup sa môže ZMENIŤ** (audit A7): R2 krídlo so starším výberom „Môj záves" (X1×3) → vyber Blum → kúpi sa **projektový P2O**; R4 pri ľavom klasickom krídle vyber KLASIK → nákup bez zmeny (X1×4) | sonda R2, R4, R5 | PRAVDA |
| S6 | Resolver pri dvierkach číta **PRVÝ `hinge@<vlastník>`** (1. stupeň reťaze KOV-F1, od v0.9.48); kľúč je v kontrakte od H1a (D-81, STANDARD §6.2 „`generic_type@owner_part_key`"). Owner triedny kľúč závesu resolver **nečíta vôbec** | `hardware_sets.rb:3792-3810`; `test_kovf_zavesy.rb:774-778` | PRAVDA → zapisovať `hinge@<krídlo>` |
| S7 | Zrušenie výberu pri krídle (prázdna voľba) už dnes `hinge@<krídlo>` zmaže správne | sonda R3 | PRAVDA — nemení sa |
| S8 | **Prototyp** (`hinge@<vlastník>`, validácia triedy ostáva, „stale" sa nemaže): R1/R2 → B1×3, R4 → ľavé 104717×2 + pravé X1×2, R5 sklop, R7 zmiešaná; R6 Tip-On + KLASIK **odmietnuté tou istou vetou**; R8 bez zmeny; log prázdny | sonda P1–P8 | PRAVDA |
| S9 | **Invariant „zápis sa prečíta"** (11 druhov položiek × skrinka/vlastník; značka → prestavba → `resolve_mapping_value`): dnes **5 mŕtvych** — dvierka Tip-On, klasické, sklop pri vlastníkovi (D-150) + **výklop bez systému** na skrinke aj pri čele (`lift_system_missing` pred mapovaním); prototyp **2** — len výklop bez systému (D-151) | sonda §4 | PRAVDA |
| S10 | **Identita mimo dvierok:** 2688 kombinácií (11 druhov × rozsah × 8 hodnôt vrátane sentinelu × 8 východiskových máp vrátane poškodeného markera × s/bez `known_sets`): zhoda **2488**, rozdiel **200** — **len** vlastník pri klasifikovaných dvierkach/sklope; všetkých 200 = presne „`class:hinge|<otv>@<v>` → `hinge@<v>`, `hinge@<v>` sa nemaže"; stav ani text chyby sa nelíši nikde | sonda §5, §9 | PRAVDA |
| S11 | `hinge@<krídlo>` inde ako dnes pri starších dvierkach: šablóna ho neuloží (`payloads.rb:2518-2524`) a cieľu ho ponechá (`templates_dialog.rb:670-681`); „Vložiť kópiu" ho nesie; R-34 ho pozná (`test_p0hf_brany.rb:318-341`); **Lucia 0.16.0 ho číta rovnako** | čítanie + Grep | PRAVDA → bez migrácie a schémy |
| S12 | **Životný cyklus:** Tip-On → klasické pri vlastnom Tip-On sete krídla → **RED `hinge_set_mismatch`** (nič zlé sa nekúpi; ako dnes skrinkový `hinge` pri H18 H1); nezaradený set kúpi ďalej + ORANGE. 2 krídla → 1 a dvierka → zásuvka: kľúč **ostáva** (`prune_missing_owners` čistí len triedne) a po návrate **ožije** | sonda §6; `hardware_sets.rb:1038-1064` | PRAVDA → Q3, D-152 |
| S13 | **Q1 B:** „podľa projektu" na skrinke dnes zmaže len `class:hinge|…`, starý `hinge` ďalej platí (X1); prototyp `q1b` zmaže aj `hinge` → P2O; zmiešaná skrinka odmietnutá; staršie dvierka mažú `hinge` už dnes | sonda §7 | PRAVDA → H18b-2 |
| S14 | Dnešný payload (pred H18) po zápise `hinge@krídlo` ukáže v riadku krídla „podľa projektu" (číta `class:hinge|…@krídlo`) — správne zobrazenie dá H18 R2.4 | sonda §2, §3 | PRAVDA → nemergovať pred H18 |
| S15 | Sentinel a selektor pri krídle závesu odmietne validácia vetou o **„zásuvke"** — len podvrhnutý payload (ponuka ich nemá); dnes rovnako na skrinke | sonda P9 | PRAVDA → D-bod textu |

### 0.1 Matica — dnes vs. po H18b-1 (nákup podľa `expand`)

| Prípad | Config pred | Akcia | Config po (dnes) | Nákup dnes | Config po (H18b-1) | Nákup po |
|---|---|---|---|---|---|---|
| R1 Tip-On 1 krídlo | — | krídlo → Blum | — | P2O (hláška „Blum") ✗ | `hinge@…single`=Blum | **B1×3** ✓ |
| R2 Tip-On | `hinge@…single`=Môj | krídlo → Blum | **— (starý zmizol)** | **P2O** ✗✗ | `hinge@…single`=Blum | **B1×3** ✓ |
| R3 Tip-On | `hinge@…single`=Môj | krídlo → (prvá voľba) | — | P2O ✓ | — | P2O ✓ (bez zmeny) |
| R4 2 klasické | `hinge`=Môj | ľavé → KLASIK | `hinge`=Môj | X1×4 ✗ | + `hinge@…left`=KLASIK | **104717×2 + X1×2** ✓ |
| R5 sklop | — | `front:F1/flap` → KLASIK | — | projekt ✗ (zhodou rovnaký) | `hinge@front:F1/flap`=KLASIK | KLASIK ✓ |
| R6 Tip-On | — | krídlo → KLASIK | odmietnuté | — | odmietnuté (tá istá veta) | — |
| R7 zmiešaná | `hinge`=Môj | F1 krídlo → Blum | `hinge`=Môj | X1×7 ✗ | + `hinge@…single`=Blum | **B1×3 + X1×4** ✓ |
| R8 zmiešaná | — | skrinka → P2O | odmietnuté | — | odmietnuté (bez zmeny) | — |

### 0.2 Súpis — kde sa výber pri krídle skladá, číta a ukazuje

| Miesto | Po H18b-1 |
|---|---|
| `hardware_sets.rb:3052-3112` `apply_cabinet_override` (jediná zápisová cesta) | **vetva závesu s vlastníkom:** kľúč `hinge@<vlastník>`, bez „stale", validácia ostáva (R1) |
| `override_class_key` `:3119`, `classified_value_problem`/`band_set_problem` `:3145-3222` | bez zmeny (trieda a validácia aj pre krídlo) |
| `resolve_mapping_value` `:3767-3833` (po H18 `resolve_mapping_source`), `parse_class_key` `:942-975`, `norm_hardware_sets` | **kód bez zmeny** (žiadna nová úroveň; `hinge@<krídlo>` prestavbu prežije už dnes); komentár parsera opravený (R2) |
| `handle_set_hardware_set` `actions_hardware.rb:1062-1129`, `hw_set_status_msg` `:1317` | bez zmeny — hláška je po oprave pravdivá (vetu zrušenia mení H18 R2.8) |
| `payloads.rb` rozsah krídla (H18 R2.4), `hardware.js` `hwSetPayload`/`onHwSet` | bez zmeny v H18b-1 (`?v=` len kvôli bumpu) |

## 1 · Cieľ

Keď pri **jednom krídle** Tip-On alebo klasických dvierok (aj pri sklope) vyberieš set, **uloží sa, platí v nákupe, prežije prestavbu, dá sa vrátiť jedným
krokom Späť** a hláška hovorí pravdu. Starší výber krídla sa novým výberom **nahradí**, nikdy potichu nezmaže. Zákazky, v ktorých nikto nový výber pri krídle
neurobí, sa nezmenia ani o bajt.

**Príklad:** skrinka s dvomi klasickými krídlami, na skrinke je vybraný vlastný set „Môj záves". Pri ľavom krídle vyberieš „Záves KLASIK". **Dnes:** hláška „Závesy
pre dielec …: set „Záves KLASIK“", ale nič sa neuloží — Nákup kovania objedná „Môj záves" na obe krídla. **Po H18b:** ľavé krídlo „Záves KLASIK" (2 ks 104717), pravé
„Môj záves" (2 ks X1); riadok ľavého krídla v Inspectore ho ukazuje (H18), Sety „2 vlastné" (skrinka + krídlo); Ctrl+Z vráti obe krídla na „Môj záves".

## 2 · Rez a odhad

| Časť | Obsah | Kód pluginu | Testy | In-SU | Odhad |
|---|---|---|---|---|---|
| **H18b-1** (Q2 A — robí sa) | R0 golden zápisu a nákupu PRED zásahom (1. commit) → R1 vetva závesu v `apply_cabinet_override` → testy, invariant, mutácie, in-SU, docs | Ruby ~+12 / −4 (+ komentáre ~15) | ~450 (golden matica, nová sada, JS kontrola zobrazenia) + in-SU ~130 | **brána** | ~0,5 dňa |
| **H18b-2** (len pri Q1 B) | „podľa projektu" na skrinke zmaže aj starý `hinge` + rozsah skrinky pri závese ukáže starý výber ako uložený a prvú voľbu „podľa projektu" | Ruby ~+30 / −8 (zápis + payload) | ~300 (+ úprava pravidiel a fixtúry H18, enumerovaný rozdiel) + in-SU ~50 | **brána** | ~0,75 dňa + audit |

Dva samostatné PR, každý z čerstvého `main` (H18b-2 až po mergi H18b-1). H18b-1 je pod 300 riadkami kódu pluginu; predrecenzia je povinná z triedy (§5).

## 3 · Scope IN

**H18b-1:** R1 zápis `hinge@<vlastník>` pri závese dvierok a sklopu (klasifikovaná položka `use_type: door`) s dnešnou validáciou · R2 opravené komentáre a docs
(tvrdenie „UI per-krídlo výber neponúka" je nepravda) · R0 golden zápisu a nákupu, invariant „zápis sa prečíta", mutácie, in-SU scenáre (výber → nákup, Späť/Znova,
prestavba, starší výber krídla, odmietnutie bez kroku Späť, kópia).

**H18b-2 (podmienené Q1 B):** R4 „podľa projektu" na skrinke pri klasifikovaných dvierkach zmaže aj generický `hinge` · R5 rozsah skrinky pri závese v payloade
(uložený starý výber viditeľný, prvá voľba = projekt) · úprava pravidiel a fixtúry H18 s enumerovaným rozdielom.

## 4 · Scope OUT

- **Resolver a precedencia** — žiadna nová úroveň, žiadna zmena reťaze (H18 `resolver.json`, `cena_zavesy.json` bajtovo).
- **Owner triedny kľúč pre záves** (`class:hinge|…@<krídlo>`) — parser ho naďalej odmieta; zavedenie = nový kontrakt + `CONFIG_SCHEMA` (zamietnutý variant, §12 D1).
- **Payload a JS v H18b-1** — zobrazenie rieši H18 (R2.4); H18b-1 ho len overí testom (T5).
- **Čistenie mŕtvych `hinge@<krídlo>`** po zmene počtu krídiel / typu čela (D-152) a **automatické zrušenie výberu krídla pri zmene otvárania** (Q3) — menia ďalšiu
  zápisovú cestu (čelá) a config existujúcich zákaziek.
- **Výklop bez systému** — mŕtvy zápis setu (D-151).
- Texty `scope_label` „Set pre toto čelo" pri krídle, technický `part_key` v hláške, veta „zásuvka" pri závese (D-bod textov, §14).
- **H18b-1:** nič v akcii „podľa projektu" na skrinke (to je Q1 → H18b-2).

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: ÁNO** — mení sa, **čo sa nakúpi** po akcii používateľa. Brány výrobnej dávky celé: golden R0 PRED zásahom, predrecenzia, KRONIKA ako výrobná
  dávka, smoke s porovnaním Nákupu.
- **Audit návrhu H18b-1: NIE** (CLAUDE.md „rozhoduje OBSAH"): (1) **kontrakt** — zapisuje sa kľúč `hinge@<part_key>`, ktorý je v kontrakte od H1a a resolver ho
  pri klasifikovaných dvierkach číta prvý od KOV-F1 — nový tvar ani význam nevzniká (S6, S11); (2) **schéma** — `CONFIG_SCHEMA` 22, BuildPlan `SCHEMA` ani STD sa
  nemenia; starší plugin (Lucia 0.16.0) kľúč číta rovnako (schémy 6 a 10 vznikli naopak preto, že starší plugin by NOVÝ owner kľúč zahodil); (3) **migrácia** —
  žiadna, rozbitý kľúč sa nikdy neuložil; (4) **undo** — telo handlera a jeho jedna operácia `rebuild_many` bez zmeny; (5) **nový modul** — nie. Smer posúdil audit
  H18 (NOTE 7). Ak orchestrátor zvolí opatrnosť, `audit_h18b_prompt.md` pokrýva aj H18b-1.
- **Audit návrhu H18b-2: ÁNO** — nový **význam polí payloadu Ruby↔JS** rozsahu skrinky pri závese (precedens H12 A5, H18 §5) + akcia „podľa projektu" maže druhý
  kľúč. Package do `_dev/audit_h18b/`.
- **Predrecenzia: povinná. In-SU: BRÁNA** (spúšťač „akcie panela zapisujúce do modelu" — mení sa, čo `set_hardware_set` zapíše; jedna operácia, Späť/Znova a
  prestavba sa overia len v SketchUpe; PR uvedie hlavu behu). **Nový ovládací prvok: NIE** (riadok krídla existuje, S1; H18b-2 mení len význam prvej voľby).
  **Fotky:** H18b-1 nie (UI ani tvar payloadu sa nemení); H18b-2 `-Record`, kontext Kovanie.

### 5.1 Závislosti a predpoklady — overiť proti mainu pri štarte (krok 0)

- **P1 · H16** zmergované — `library_registry.rb`, `templates.rb`, `usage_stats.rb`; súborov H18b sa nedotýka. Prienik VERSION, `?v=`, STAV, KRONIKA, PLAN.
- **P2 · H18 R2.4** zmergované: `Panel.hardware_set_options` pri závese dvierok plní `compat.owners[<krídlo>].current/stored/value_text` z **`hinge@<krídlo>`**
  (úroveň `owner` zdroja resolvera nad uloženými overridmi). **Overenie:** headless zápis `{"hinge@front:F1/wing:single" => "zaves-p2o"}` → `current ==
  "set:zaves-p2o"`. Ak nie → **STOP a otázka** (bez toho by po oprave Inspector ukazoval „podľa projektu" pri platnom výbere — opačná nepravda).
- **P3 · H18 R2.8:** `hw_set_status_msg` pri zrušení = „…: výber zrušený." (H18b na to len nadväzuje; ak H18 vetu nezmenilo, H18b ju **nemení**).
- **P4 · H18 goldeny** v `tests/fixtures/h18_golden/` (`resolver.json`, `source_pred.json`, `cena_zavesy.json`, `payload_pred.json`, `payload_po.json`) a sady
  `test_h18_sety_pravda.rb/js` existujú a sú zelené — **H18b-1 ich nesmie regenerovať** (zmena = nález → STOP). H18b-2 smie regenerovať **len** `payload_po.json`
  s enumerovaným rozdielom (R5).
- **P5 · H18 R1** — `resolve_mapping_source`/`item_mapping_source` existujú (potrebuje ich len H18b-2; H18b-1 používa len `resolve_mapping_value`, ktoré je na maine).
- Rozdiel meniaci zámer (napr. H18 zmenilo `apply_cabinet_override` alebo kľúč rozsahu krídla) → STOP a otázka.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit, plugin bez zmeny)

- **R0.1 Matica** `tests/fixtures/h18b_golden/cases.rb` (jeden zdroj pre generátor aj test; vzor `sonda_h18b.rb` §4–§5): 11 druhov položiek (dvierka Tip-On,
  klasické, sklop, staršie dvierka, výsuv Quadro, Atira, starší výsuv, výklop HK, **výklop bez systému**, starší výklop, nohy) × rozsah (skrinka, vlastník) ×
  hodnoty (P2O, KLASIK, nezaradený, Blum Tip-On, set výsuvu, sentinel, `nil`, `''`) × východiskové mapy (prázdna, `hinge`, `class:hinge|tipon`, `hinge@krídlo`,
  `hinge@front:F1/flap`, `slide@panel`, owner triedny výsuvu, **poškodený marker** `hinge@krídlo`) × s/bez `known_sets`. Fixtúrne sety v `cases.rb`, seed bez zmeny.
  Fixtúra ≤ 300 kB (zúžiť hodnoty/mapy, nie druhy ani rozsahy).
- **R0.2 Generátor** `generate.rb` (ručne) zapíše na **starom kóde** `zapis_pred.json` (výstup `apply_cabinet_override` každej kombinácie) a `nakup_pred.json`
  (skrinky TIP1, CLS2, FALL, MIX z `build_plan` s `owner_id` × scenáre R1–R8: zapísaná mapa, mapa po `norm_hardware_sets(map, fronts)`, `expand` pred/po, hláška).
- **R0.3** Goldeny H18 (`resolver.json`, `cena_zavesy.json`, `source_pred.json`, `payload_*.json`) a staršie (`kovh`, `ceny_m2`, `np4`, `h9`) sa v H18b-1
  **nedotknú** a ostanú zelené bez regenerácie = dôkaz „existujúce zákazky bajtovo".

### R1 · Zápis výberu pri krídle (`core/hardware_sets.rb` `apply_cabinet_override`)

- **R1.1** Keď je zadaný **vlastník** a **všetky** položky identity sú klasifikovaný záves (`override_class_key` vráti triedu **a** `door_item?` pre každú položku —
  presne podmienka, ktorou resolver vstupuje do vetvy závesu, `:3792`), kľúč zápisu je **`"#{gt}@#{owner}"`** — ten, ktorý resolver číta ako prvý. Inak doslovne ako
  dnes (owner triedny pri výsuve a výklope, generický pri starších položkách, triedny/generický na skrinke).
- **R1.2** V tejto vetve sa **nič nemaže ako „stale"** (kľúč zápisu a „stale" sú ten istý kľúč — zmazanie by zahodilo práve zapísanú hodnotu). Zrušenie (prázdna
  hodnota) zmaže `hinge@<vlastník>` ako dnes. Mimo tejto vetvy sa logika `stale` nemení (výsuv/výklop ďalej odpratávajú legacy `typ@owner`).
- **R1.3** **Validácia ostáva celá:** typ setu, neaktívny set (F10 — výnimka pre **uloženú** hodnotu teraz číta `map["hinge@<vlastník>"]`, teda skutočne uložený
  výber krídla), `classified_value_problem` proti klasifikácii krídla (Tip-On krídlo + klasický set = odmietnutie **tou istou vetou ako dnes**, S8 R6).
- **R1.4** Podmienka vetvy je **jedna pomenovaná** funkcia alebo lokálny predikát v `apply_cabinet_override` s komentárom „kľúč, ktorý resolver číta" a odkazom na
  vetvu závesu v reťazi — **žiadna kópia reťaze resolvera**. Rovnosť „zapísaný kľúč = čítaný kľúč" stráži invariant T2 (nie kód).
- **R1.5** Telo `handle_set_hardware_set`, `override_class_key`, `classified_value_problem`, parser a resolver **bez zmeny riadku** (zdrojový guard T6).

### R2 · Komentáre, docs a STANDARD (bez zmeny kontraktu)

- **R2.1** Komentár `parse_class_key` (`:951-955`, „per-krídlo triedny výber je MIMO dávky — parser ho odmieta a UI ho neponúka") a hlavička `apply_cabinet_override`
  (`:3034-3051`): výber pri krídle závesu je **`hinge@<krídlo>`**; owner triedny kľúč závesu neexistuje a zápisová cesta ho nikdy nezloží (H18b, D-150).
- **R2.2** `docs/architecture/hardware.md` odsek `### hardware_sets.rb`: odrážka „**Zápis (`apply_cabinet_override`)**" (`:837-842`) + odrážka „Triedny kľúč `hinge`…
  **Per-krídlo triedny override je MIMO F1 … UI ho neponúka**" (`:995-999`) — prepísať na mieste (vetva závesu s vlastníkom, prečo nie owner triedny, validácia).
  `docs/architecture/ui-lifecycle.md` `### actions_hardware.rb` (veta o výbere setu na dielci) a `### payloads.rb` (odrážka `compat` — „kľúč zloží
  `apply_cabinet_override`": pri krídle závesu `hinge@<krídlo>`).
- **R2.3** **STANDARD §6.2** — za odsek „OWNER TRIEDNY KĽÚČ" **jedna veta** (popis existujúceho kontraktu, nie zmena): „**Záves (dvierka aj sklop) owner triedny
  kľúč nemá** — výber pre jedno krídlo je `hinge@<part_key>`, prvý stupeň precedencie závesu; zápis ho validuje proti klasifikácii krídla rovnako ako triedny
  zápis." (Bez nej sa pasca `class:hinge|…@krídlo` dá zopakovať.) Na potvrdenie orchestrátorom (§12 D5).

### R3 · (H18b-1) zobrazenie — žiadna zmena kódu, len dôkaz

- Payload a JS sa nemenia. Test T5 nad kódom H18 dokáže, že po zápise riadok krídla ukazuje vybraný set, Sety rátajú vlastný výber a hláška menuje ten istý set.

### R4 · (H18b-2, len pri Q1 B) „podľa projektu" na skrinke vráti skrinku na projekt

- `apply_cabinet_override` pri **prázdnej** hodnote, **bez vlastníka**, keď `override_class_key` vráti triedu a **všetky** položky sú `door_item?`: zmaže triedny
  kľúč **a** generický `hinge`. Výsuv, výklop, nohy, staršie dvierka (tie mažú `hinge` už dnes) a zmiešaná skrinka (odmietnutie) bez zmeny.
- Zápis **nového** setu na skrinke generický `hinge` **nemaže** (zatienený, nákup ani Späť sa nemenia) — §12 D7. `hinge@<krídlo>` sa nikdy nemaže akciou skrinky.

### R5 · (H18b-2) rozsah skrinky pri závese (`payloads.rb`, nad H18)

- Pre `compat.cab` triedy `class:hinge|…`: `current`/`stored`/`value_text` z hodnoty víťaza úrovne **`cab_class` alebo `cab`** sondy skrinky (H18 sonda
  `owner_part_key: ''` nad **uloženými** overridmi) — starý `hinge` sa ukáže ako vybraný set (je v ponuke) alebo „… (uložený výber)"; `none_label` zo sondy **bez
  triedneho kľúča aj bez generického `hinge`** → „podľa projektu — …" (slovník H18). Rozsahy krídiel, výsuv a výklop **bajtovo** ako H18.
- `payload_po.json` H18 sa regeneruje; test vymenuje rozdiel (len `compat.cab.{current, stored, value_text, none_label}` závesových záznamov s generickým `hinge`
  v skrinke). Pravidlo zhody H18 **Z3** sa pre triedy závesu prepíše (prvá voľba = sonda bez oboch kľúčov, vybraná voľba = víťaz `cab_class`/`cab`); oracle =
  značkovací nad **nezmeneným** `resolve_mapping_value` (nie nový helper).

## 7 · Testy a DoD

- **T0 · golden zápisu:** `tests/pure/test_h18b_zaves_kridlo.rb` — v 1. commite zelený na starom kóde; po zásahu kombinácie **mimo** „vlastník + klasifikovaný
  záves" bajtovo == `zapis_pred.json`; kombinácie „vlastník + klasifikovaný záves" == **transformácia počítaná zo `zapis_pred.json`** (nie z nového kódu):
  `class:hinge|<otv>@<v>` → `hinge@<v>` s tou istou hodnotou, `hinge@<v>` z východiska sa prepíše, nie zmaže; stav a text chyby všade identické. R0.3 zelené.
- **T1 · nákup reálnych skriniek** R1–R8: očakávanie skladá **nezmenený** `expand` nad mapou „východisková − `hinge@<v>` + `hinge@<v>` ⇒ hodnota"; scenáre bez
  výberu pri krídle (R3, R6, R8, stav „pred") bajtovo == `nakup_pred.json`.
- **T2 · invariant „zápis sa prečíta":** 11 druhov × rozsah: zápis značky (bez `known_sets`) → `norm_hardware_sets` (bez čiel aj s reálnymi čelami tam, kde
  existujú) → `resolve_mapping_value` vráti značku. **Výklop bez systému:** raw resolver značku číta, ale spotrebiteľ `resolve_set_id` vracia `[nil, 'lift_system_missing', {}]` (D-151 — keď ho niekto opraví,
  test sa zmení vedome).
- **T3 · validácia:** Tip-On krídlo + KLASIK → `:invalid` s vetou „nesedí klasifikácii čela (iný spôsob otvárania)"; set iného typu → `:invalid`; **neaktívny** set
  novo pri krídle → `:invalid`; **neaktívny uložený** výber krídla znovu uložiť → `:ok` (F10 výnimka teraz platí aj pre krídlo — vymenovaná zmena správania);
  zmiešaná skrinka na úrovni skrinky → odmietnutie ako dnes.
- **T4 · ostatné cesty kľúča:** `template_config_from` `hinge@<krídlo>` neuloží, `merge_hardware_sets` ho cieľu ponechá, `owner_scoped_key?` true (po jednom assertu).
- **T5 · zobrazenie po zápise (stavia na H18):** po zápise R1/R2/R4 `Panel.hardware_set_options` → `compat.owners[<krídlo>].current == mapping_option_id(hodnota)`,
  `own_count` závesu ≥ 1, `none_label` rozsahu krídla „podľa skrinky/projektu — …" podľa nezávislého oracle (značkovací nad `resolve_mapping_value`). JS
  `tests/js/test_h18b_zaves_kridlo.js` nad `h18b_golden/payload_po.json` (generuje `generate.rb` z nového kódu; Ruby stráži čerstvosť — **aktuálnosť ≠ správnosť**,
  správnosť dokazuje porovnanie s nákupom `expand`): `hwOwnerOptionList` má vybranú voľbu vybraného setu, `hwSetsMetaText` ≠ „podľa projektu".
- **T6 · zdrojové guardy:** telo `handle_set_hardware_set`, `override_class_key`, `parse_class_key`, `resolve_mapping_value`/`resolve_mapping_source` a
  `norm_hardware_sets` bez zmeny voči mainu pri štarte (porovnanie výrezu tela; vzor `test_kovd1a_mapovanie.rb:410`).
- **T7:** `ruby tests/run_all.rb` + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + `ruby scripts/encoding_guard.rb --repo`.
- **T8 · in-SU:** §8 (brána).
- **T9 (H18b-2):** zápis R4 nad maticou T0 (len kombinácie „skrinka + klasifikovaný záves + prázdna hodnota" sa líšia — o zmazaný `hinge`); T5′ rozsah skrinky
  (uložený starý `hinge` vybraný alebo „(uložený výber)", prvá voľba „podľa projektu — …") vrátane prípadov H18 H1, H3, H8, H9; JS Z3′; rozdiel `payload_po.json`
  vymenovaný.
- **Mutácie** (PR priloží beh každej; mutácia, ktorú nič nezhodí = doplniť test; behy so zálohou a kontrolou čistého stromu na konci):

| M | Mutácia | Zhodí |
|---|---|---|
| M1 | návrat na owner triedny kľúč závesu (dnešný stav) | T0, T1, T2, T5, in-SU |
| M2 | vetva „`typ@vlastník`" aj pre klasifikovaný **výsuv/výklop** | T0 (výsuv/výklop bajtovo), T2 (výsuv pri čele mŕtvy) |
| M3 | v novej vetve sa `hinge@<v>` po zápise zmaže ako „stale" | T0 (transformácia), T1 R2, in-SU krok 4 |
| M4 | vetva závesu bez `classified_value_problem` | T3 (Tip-On + KLASIK prejde) |
| M5 | F10 výnimka číta starý kľúč (`map[class…@v]`) | T3 (neaktívny uložený výber krídla odmietnutý) |
| M6 | `hinge@` aj na úrovni **skrinky** (kľúč `hinge` namiesto triedneho) | T0 (rozsah skrinky bajtovo), T2 |
| M7 | validácia novej vetvy proti závesom **celej skrinky** namiesto položiek krídla | T1 R7 (Blum pri Tip-On krídle zmiešanej skrinky odmietnutý) |
| M8 | zrušenie pri krídle zmaže aj skrinkový `hinge` (únik Q1 do H18b-1) | T0 (zrušenie s východiskom `hinge`) |
| M9 | prestavba (`norm_hardware_sets`/prune) zahodí `hinge@<krídlo>` pri klasifikovaných dvierkach | T2 (s čelami), T1, in-SU krok 3 |
| M10 | zásah do tela `handle_set_hardware_set` (napr. hláška pred zápisom) | T6 guard tela, in-SU krok 1 |
| M11 (H18b-2) | R4 zmaže `hinge` aj pri výsuve / zmiešanej / staršej skrinke | T9 |
| M12 (H18b-2) | R4 nemaže generický `hinge` | T9, in-SU krok 8 |
| M13 (H18b-2) | `none_label` skrinky pri závese zo sondy len bez triedneho kľúča (stav H18) | T9 JS Z3′ |
| M14 (H18b-2) | `current/stored` skrinky len z triedneho kľúča (starý `hinge` neviditeľný, vybraná prvá voľba) | T9 T5′, JS Z3′ |

- **DoD:** T0–T8 zelené (H18b-2 aj T9) · goldeny H18 a staršie bez regenerácie (H18b-2: len `payload_po.json`, rozdiel vymenovaný) · mutácie v PR · in-SU PASS s
  uvedenou hlavou · docs §11 · PR s „Predrecenziou", maticou §0.1 PRED/PO z `nakup_pred.json` a vetou **„existujúce zákazky bez nového výberu pri krídle: výsledok
  resolvera, nákup kovania (expanzia + CSV), rozpočet a ponuka nad klasifikovanými závesmi bajtovo rovnaké (goldeny H18 `resolver.json`, `cena_zavesy.json`); zmení
  sa len výsledok akcie výberu pri krídle"**.

## 8 · In-SU — BRÁNA (`scripts\run_su_tests.ps1 -CloseWhenDone`)

Nový krok `kovf_wing_set(model)` v sekcii **KOV-F** `tests/sketchup/su_runner.rb` (volať v `run_kovf` za `kovf_cabinet_set`, `:26191`; fixtúrny set `KOVF_ALT_SET`
= klasický „TEST záves alternatíva", kód `NX-TEST-ZAVES`, ten istý, čo sekcia už vytvára a upratuje). Vzor kontrol: KOV-D1a (`su_runner.rb:23970-24030` —
`r03_marker` = presne jeden krok, Redo, „Vložiť kópiu"); hlášku zachytí `install_js_recorder`/`remove_js_recorder` (`:7838`, vždy v `ensure`). Kódy: KLASIK
`104717`, P2O `245723`.

1. **Výber pri krídle → nákup:** skrinka 2 klasické krídla (`kovf_build(model, 800.0, 900.0, 'wings' => '2')`) → najprv **skrinka** `set_id` = ALT (triedny kľúč;
   obe krídla ALT) → pri **ľavom krídle** `set_id` = `zaves-klasik` reálnou akciou `handle_set_hardware_set` (`owner_part_key` `front:F1/wing:left`). Overiť: config
   `hardware_sets` = `{ 'class:hinge|classic' => ALT, 'hinge@front:F1/wing:left' => 'zaves-klasik' }`; nákup `104717` × počet ľavého + `NX-TEST-ZAVES` × počet pravého
   (`kovf_codes`); hláška (`NX.setStatus`) menuje „Záves KLASIK" **a** config ho nesie; payload `compat.owners['front:F1/wing:left'].current == 'set:zaves-klasik'` (H18).
   *Na starom kóde by ľavé krídlo ostalo ALT — scenár odlíši opravu od chyby.*
2. **Späť = jeden krok:** `Sketchup.undo` → config bez `hinge@…left`, nákup obe ALT, marker platný; **Redo** (ak `Sketchup.respond_to?(:redo)`) → stav kroku 1.
3. **Prestavba:** `CabinetBuilder.rebuild` s inou hĺbkou → `hinge@…left` prežije, nákup ako v kroku 1, Kontrola bez `CAT_HW_MISMATCH`.
4. **Starší výber krídla sa nahradí, nezmaže:** pri ľavom krídle `set_id` = ALT → config `hinge@…left` = ALT (kľúč ostal, hodnota nová), nákup všetko ALT; potom
   ľavé krídlo **prvá voľba** (`set_id` '') → `hinge@…left` zmizne, nákup ALT (zo skrinky), hláška podľa H18 R2.8.
5. **Odmietnutie bez kroku Späť:** skrinka Tip-On 1 krídlo; pri krídle `set_id` = `zaves-klasik` (podvrhnutý payload) → chybová hláška „nesedí klasifikácii čela…",
   config a nákup bez zmeny, žiadna nová operácia (marker: jedno Späť ho odstráni).
6. **Tip-On krídlo platný set:** tá istá skrinka, pri krídle `set_id` = `zaves-p2o` → config `hinge@front:F1/wing:single` = `zaves-p2o`, nákup `245723` + piest,
   hláška pravdivá.
7. **Vložiť kópiu** skrinky z kroku 1 → kópia nesie `hinge@…left` aj nákup.
8. **(H18b-2)** skrinka 2 klasické krídla so starým generickým `hinge` = ALT (príprava: prestavba s `hardware_sets` + zmrazenie definície v tej istej operácii) →
   payload `compat.cab` ukazuje ALT ako vybraný (`current`), prvá voľba „podľa projektu — …" → akcia skrinky `set_id` '' → config `{}`, nákup `104717`; Späť → ALT.

Upratanie: `cleanup(model)`, fixtúrny set maže existujúce `ensure` sekcie. Riadok sumáru v zozname sekcií (`:28951`) doplniť o „výber pri krídle platí".
**Max 2 pokusy o opravu pri FAIL, test sa nikdy neobchádza** (CLAUDE.md).

## 9 · Riziká

- **Zmena nákupu po akcii** — zámer; existujúce zákazky chráni nezmenený resolver + goldeny (T0, R0.3).
- **Zmena otvárania po výbere pri krídle** → RED „nesedí s čelom" pri tom krídle (nič zlé sa nekúpi, export stojí; ako dnes starý skrinkový `hinge`) — Q3, smoke 5.
- **Mŕtvy výber krídla ožije** po návrate počtu krídiel / typu čela (S12) — dnes rovnako pri starších dvierkach; Inspector ho po H18 ukáže. D-152.
- **H18b bez H18** = opačná nepravda (platný výber, riadok „podľa projektu") → §5.1 P2.
- **Lucia 0.16.0:** nákup z toho istého `.skp` rovnaký; jej Inspector ukáže riadok krídla „podľa projektu" do aktualizácie (D-149).
- **H18b-2** mení rozhodnutie H18 D3 a pravidlo Z3 — audit, enumerovaný rozdiel fixtúry, M13/M14.

## 10 · Smoke checklist pre Michala (po mergi a inštalácii)

**Príprava (orchestrátor cez SkAgent v testovacom okne — overiť `model.path`):** kópia `_dev\ENGINEtests.skp` → `_dev\H18b_smoke.skp`; do **projektového snapshotu**
(nie do knižnice v `%APPDATA%`) fixtúrny klasický set „TEST záves" (kód `NX-TEST-ZAVES`); skrinky (zápis `hardware_sets` + prestavba + zmrazenie, jedna operácia):
**A** 2 klasické krídla + skrinka `class:hinge|classic` = TEST · **B** 1 Tip-On krídlo bez výberu · **C** (len H18b-2) 2 klasické krídla + starý skrinkový
`hinge` = TEST. Uložiť, cestu do reportu.

1. **A** → Kovanie → riadok **ľavého krídla** → vyber „Záves KLASIK": hláška „Závesy pre dielec …left: set „Záves KLASIK…“"; riadok ľavého krídla ukazuje Záves KLASIK,
   pravé „podľa skrinky — TEST"; Štúdio → Nákup kovania: **104717** × ľavé + **NX-TEST-ZAVES** × pravé. *(Pred inštaláciou by ostalo všetko TEST.)*
2. **Ctrl+Z** raz → ľavé krídlo späť „podľa skrinky — TEST", nákup len TEST; **Ctrl+Y** → späť bod 1.
3. Zmeň hĺbku skrinky A → výber ľavého krídla ostane, nákup rovnaký.
4. Ľavé krídlo → prvá voľba („podľa skrinky — TEST") → nákup len TEST, hláška „…výber zrušený."
5. **B** → riadok krídla ponúka len Tip-On sety; vyber „Záves P2O…" → Sety „1 vlastný", nákup P2O + piest. Potom v karte čela prepni otváranie na **Klasické** →
   nákup ukáže **červené „nesedí s čelom"** pri tom krídle (nič sa nekúpi zle); vyber pri krídle „Záves KLASIK" alebo prvú voľbu → červené zmizne. *(Q3.)*
6. **(H18b-2) C** → riadok Závesy ukazuje TEST ako vybraný, prvá voľba „podľa projektu — Záves KLASIK"; vyber prvú voľbu → nákup KLASIK, Sety „podľa projektu";
   Ctrl+Z → TEST späť.
7. **Reálna zákazka (kópia):** Nákup kovania a Rozpočet — rovnaké čísla ako pred inštaláciou (bez zásahu).

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** → T0–T8 (+T9) + in-SU PASS → **architektúra na mieste** (R2.2) → **Grep tvrdení o
zoznamoch:** „UI ho neponúka", „MIMO F1", „owner triedny kľúč ostáva výhradou zásuviek", `CLASS_OWNER_PART`, „per-krídlo" v `docs/`, `SYSTEM/STANDARD.md` a
komentároch → **STANDARD §6.2** jedna veta (R2.3, ak D5 potvrdené) → **D-150** do `SYSTEM/archiv/DOGFOODING_vyriesene.md` (plný text + PR, riadok navrch INDEXU;
z `SYSTEM/DOGFOODING.md` preč) · nové D-151/D-152 (+ D-153 pri H18b-2) do `SYSTEM/DOGFOODING.md` → **prepis STAV** (max 80 riadkov / 12 kB) → **KRONIKA** odsek
navrch (výrobná dávka, in-SU hlava) → **PLAN** riadok H18b s ✅ a `PR #?` → package + `sonda_h18b.rb`/`_out.txt` (+ surový audit pri H18b-2) do
`SYSTEM/zdroje/bloky/HARDENING/` → **PR popis:** čo uvidí Michal (príklad §1), trieda a zdôvodnenie „audit nie" (§5), Predrecenzia, matica §0.1, mutácie, in-SU
hlava. Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Zapisovať `hinge@<krídlo>`**, nezaviesť `class:hinge|<otv>@<krídlo>` | `hinge@` resolver číta prvý (S6), starší plugin rovnako (S11) → bez schémy, migrácie a zmeny reťaze. Owner triedny kľúč závesu = parser + nový stupeň reťaze + prune + `CONFIG_SCHEMA` 23 (starší plugin by ho zahodil — precedens schém 6, 10) + STANDARD + audit; jediný zisk: pri zmene otvárania by výber „zaspal" namiesto RED (Q3). Smer potvrdil audit H18 NOTE 7 | **áno** |
| D2 | **Resolver sa nemení**; „zapísaný = čítaný kľúč" stráži invariant T2 | najmenšia oprava; H18 práve presunulo reťaz — druhý zásah = riziko bez úžitku | áno |
| D3 | Validácia triedy pri krídle ostáva celá (tá istá veta) | Tip-On krídlo s klasickým setom = záves bez piestu | nie |
| D4 | Audit H18b-1 **nie** (§5) | obsah zásahu; prompt pokrýva aj H18b-1 | **áno** |
| D5 | STANDARD §6.2 jedna veta (popis existujúceho kontraktu) | STANDARD výber pri krídle závesu nepopisuje a docs KOV-F1 tvrdia „UI ho neponúka" — z toho D-150 vzniklo | áno |
| D6 | H18b-1 a H18b-2 = **dva PR** | H18b-2 mení zobrazenie aj rozhodnutie H18 D3 a je audit-povinné | nie |
| D7 | (H18b-2) zápis nového setu na skrinke starý `hinge` **nemaže**; maže ho len „podľa projektu" | rozsah Q1; mazanie pri zápise by menilo správanie pri zmene otvárania (starý `hinge` vtedy dnes znovu platí) | áno |

## 13 · Otázky pre Michala (do odpovede platí predvolené)

- **Q2 (z H18) · Výber setu pri jednom krídle** — predvolené **A** platí: tento package (H18b-1). *Bez ďalšej otázky.*
- **Q1 (z H18) · Starý výber závesov na skrinke — má voľba „podľa projektu" v riadku skrinky zmazať aj ten starý?** Príklad: skrinka má kedysi vybraný „Môj
  záves", dvierka sú Tip-On. Po H18 uvidíš v riadku Závesy prvú voľbu „podľa staršieho výberu skrinky — Môj záves" a vrátiť sa na predvoľby projektu sa nedá (len
  prebiť iným setom). **A (predvolené):** nechať tak. **B:** dávka **H18b-2** — riadok ukáže „Môj záves (uložený výber)" a prvá voľba „podľa projektu — Záves P2O"
  ho naozaj zmaže (zmena nákupu len pri tej akcii, test v SketchUpe, ~¾ dňa + audit).
- **Q3 (nové) · Zmena otvárania dvierok, keď má krídlo vlastný set.** Vyberieš pri krídle Tip-On set a neskôr dvierka prepneš na klasické. **A (predvolené):** výber
  krídla ostane a Nákup ukáže červenú chybu „nesedí s čelom", kým nevyberieš správny set — nič sa nekúpi zle, ale export stojí (rovnako ako dnes pri starom výbere
  skrinky). **B:** prepnutie otvárania výber krídla samo zruší (krídlo prejde na skrinku/projekt) — samostatná dávka (mení zápis čiel).

## 14 · Nálezy mimo scope a D-body

- **D-150 (vyrieši H18b-1)** — znenie z H18 §14 F1; do `DOGFOODING_vyriesene.md` s PR.
- **D-151 (navrhnuté, zásobník):** **klasifikovaný výklop bez systému** — výber setu na skrinke aj pri čele sa uloží, hláška hlási úspech, ale resolver ho nikdy
  neprečíta (`resolve_set_id` zastaví `lift_system_missing` pred mapovaním, `hardware_sets.rb:3661`); export aj tak stojí na RED. Oprava: zápis odmietnuť vetou
  „čelo nemá systém výklopu (HK top / HL top)". Sonda §4 (`lift_nosys`).
- **D-152 (navrhnuté, zásobník; rozšírenie H18 F4):** `typ@<dielec>` (aj `hinge@<krídlo>`) po zmene počtu krídiel alebo typu čela ostáva v configu a po návrate
  **ožije** — `prune_missing_owners` čistí len triedne kľúče. Po H18b ho vie vytvoriť aj klasifikované krídlo. Oprava = rozšíriť prune na legacy composite (mení
  config existujúcich zákaziek pri prestavbe → vlastná dávka s goldenom).
- **D-153 (navrhnuté, len pri H18b-2):** zmiešaná skrinka (Tip-On + klasické) so starým skrinkovým `hinge` — riadok skrinky sa nekreslí, takže návrat „na projekt"
  ostáva nemožný (len prebitie pri každom krídle).
- **F (texty, zásobník):** `scope_label` „Set pre toto čelo" aj pri **krídle** dvierok (`payloads.rb:2344`); hláška „pre dielec front:F1/wing:single" s technickým
  kľúčom (ľudský popis dielca už vie `PartKeys`); veta „táto zásuvka výškový variant nemá" pri závese (len podvrhnutý payload, S15).
- Čísla D sú ďalšie voľné po H18 (D-149, D-150); ak medzitým pribudlo iné, orchestrátor prečísluje.

**Potvrdenie orchestrátora (3.10.2026 ~00:20):** D1 áno (`hinge@<krídlo>` — kľúč, ktorý resolver číta prvý, žiadny nový triedny kľúč) · **D4 áno — H18b-1 bez auditu
návrhu** (kľúč je v kontrakte od H1a, resolver ho číta od KOV-F1; nemení sa schéma, undo ani migrácia) · D5 áno. Trieda H18b-1: výrobná/cenová, **in-SU brána**,
predrecenzia povinná. **Historický WAIT bol zrušený Michalovým schválením Q2 5.10.2026** (mení, čo sa objedná). H18b-2 len pri Q1 B, samostatný PR + audit. Q3 predvolené A.


## 15 · Implementácia H18b-1 (5.10.2026)

- Michal výslovne autorizoval opravu Q2; Q1 A/Q3 A ostávajú, H18b-2 sa nerobí. D-151/D-152 bez opravy.
- Štart `c6bba0b96d96efc63b0f90c9083e77b66bd98d52` (v0.17.26), vetva `fix/h18b-wing-selection`. R0 baseline `4a815dee` vznikol pred produkčnou editáciou; 2816 kombinácií, 8 scenárov z `Construction.build_plan` s explicitným `owner_id`. PRED fixtúry ~174 kB; H18 goldeny sa neregenerujú.
- T2 upresnené proti živému zdroju: `resolve_mapping_value` číta aj raw značku výklopu bez systému; skutočný spotrebiteľ `resolve_set_id` skončí `[nil, lift_system_missing, {}]`. Test pripína obe správania, D-151 sa nemení.
- Lokálna cielená sada T0–T6: 7 PASS/0 FAIL/0 SKIP; JS3 scenáre PASS, všetkých 163 JS sád PASS. M1–M10 zhodené; po každom behu súbory obnovené bajtovo. Plná Ruby sada 5340 PASS/0 FAIL/0 SKIP, encoding a docs guard PASS; zdrojová predrecenzia 0 P1/P2/P3 nad `746a4d69` (6.10., SOURCE ONLY). Finálny in-SU čaká.
- **In-SU prvý beh (`bccee9d1`, 5.10.2026): 3396 PASS / 4 FAIL.** Všetky štyri FAIL boli presným nákupným oracle novej sady: očakávanie vynechalo platničku a obe krytky setu KLASIK.
  Skutočný nákup bol `104717`, `106412`, `105408`, `105425` po 2 ks + `NX-TEST-ZAVES` 2 ks. Seed potvrdzuje všetky štyri členy; testová oprava `746a4d69` pripína celý set aj po Redo/prestavbe/kópii, produkčný writer bez zmeny. Cielená sada po oprave 7/0/0 a JS3 PASS.
- **Druhý natívny štart (`746a4d69`, 6.10.2026): testy nezačali, vyžaduje sa prihlásenie SketchUpu.** Michal potvrdil, že okno Welcome otvoril on a rieši login.
  Pôvodný launch PID zanikol pred bootom (bez `su_result.txt` aj `close.log`); runner prirodzene skončil po 8 minútach TIMEOUT, exit 1. Žiadny kill/reštart ani zásah do Michalovho okna.
  **In-SU brána ostáva NEOVERENÁ** do skutočného PASS po vyriešení prihlásenia; prvý FAIL aj startup záznam sa zachovávajú oddelene.

- **Draft PR #?**: dôvodom je čakajúca finálna in-SU brána a prihlásenie SketchUpu. Slepá zdrojová predrecenzia `746a4d69` má 0 P1/P2/P3; GH review sa spustí až po native PASS a prepnutí na ready. Kvótová brána pred otvorením: weekly 32 % zostáva, PASS. Žiadny merge.
