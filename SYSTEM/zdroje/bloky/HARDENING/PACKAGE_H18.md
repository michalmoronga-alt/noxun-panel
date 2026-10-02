# PACKAGE H18 · Inspector ukáže skutočne použitý set závesov — blok 9 HARDENING

> **Autorita:** rozhodnutie Michala 2.10.2026 (odpoveď **3A** na otázku 3 ranného reportu): Inspector ukáže **skutočne použitý set**; **výroba, nákup ani ceny
> sa NEMENIA** — mení sa len zobrazenie pravdy. Nález: slepé recenzie PR #454 (H6b) + delta H6b (P3), overené sondou nižšie.
> **Trieda (§5):** **audit-povinná ÁNO** (zmena kontraktu payloadu panela Ruby↔JS — precedens H12 A5 — a extrakcia reťaze resolvera setov) · **výrobná/cenová ÁNO
> (konzervatívne)** · **predrecenzia povinná** · **in-SU nie je brána** · fotky `ui_foto -Record` povinné · nový ovládací prvok **NIE** · `codex-po-pr` bez výnimky.
> **Bez zmeny čísel:** nákup, rozpočet, ponuka, VEPO, Kontrola a config skrinky bajtovo rovnaké (golden R0 PRED zásahom).
> **Verzia:** patch podľa mainu pri štarte + všetky `?v=` (mení sa `hardware.js`) + prepis STAV.
> **Stav kódu:** sonda nad `main` **`466b8b4c`** (v0.17.20, po PR #456). **Predpoklad:** pred štartom zmerguje H7b (Štúdio — bez prieniku so súbormi H18 okrem
> `?v=`, STAV, KRONIKA); čísla riadkov nižšie sú z `466b8b4c` — pri štarte ich implementátor prepočíta (`git diff 466b8b4c..main -- <súbor>`).
> **Audit návrhu 2.10.2026 (audítor audit-povinných): 0 BLOCKER · 5 FIX · 3 NOTE — zapracované, §15 MÁ PREDNOSŤ.** Koncept bez zmeny; rozsah rozšírený o pravdivú
> stavovú vetu (A2), poškodený výber v plochých riadkoch (A3), stav `blocked` (A4) a paritu `explain` (A6); testy o nezávislú pravdu (A1) a cenový golden (A5).

---

## 0 · Sonda na kóde (headless, 2.10.2026)

Skripty v `scratchpad/HARDENING/`: `sonda_h18.rb` (+ `sonda_h18_js.js`) — 19 pomenovaných prípadov, čo resolver použije vs. čo Inspector nakreslí (reálne
funkcie `hardware.js` v Node nad reálnym payloadom `Panel.hardware_set_options`); `sonda_h18_proto.rb` (+ `sonda_h18_proto_js.js`) — **prototyp návrhu** nad
maticou **312 prípadov** (12 sád položiek × kľúče skrinky × 3 stavy projektu). Ruby 3.2 cez `tests/helper.rb` (APPDATA = sandbox), `hardware_read_state` podvrhnutý
v pamäti procesu. Do modelu, repa ani `%APPDATA%` sa nič nezapisovalo. Výstupy `sonda_h18_*_out.*`.

| # | Tvrdenie | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | Generický kľúč pri **klasifikovanej** položke číta **LEN záves** (`door_item?`): päťstupňová reťaz `hinge@<krídlo>` → `class:hinge\|<otváranie>` skrinky → **`hinge` skrinky** → triedny kľúč projektu → **`hinge` projektu**. Výsuv (`slide`) a výklop (`lift`) generický kľúč ani `typ@<čelo>` **nečítajú** | `hardware_sets.rb:4414-4433` vs `:4434-4447` (klasifikovaná) a `:4449-4459` (ostatné); sonda S1/S2/L1 (generický `slide`/`lift` resolver ignoruje a Inspector to tak aj ukazuje) | PRAVDA — nález je len o závesoch |
| S2 | Inspector pri klasifikovaných dvierkach kreslí riadok skrinky a riadky pri krídlach z `compat` (`class_compat_payload`), kde `none_label` pozná len triedny kľúč skrinky a projektu (`compat_none_label`, `inherited = overrides[class_key] \|\| proj_map[class_key]`) | `payloads.rb:2294-2358`, `:2338` | PRAVDA |
| S3 | Kľúč krídla `hinge@<krídlo>` (ktorý resolver pri dvierkach číta ako prvý) payload **zahodí** (`owner_set_overrides`: `next if active[owner]`) a `compat.owners` hľadá `class:hinge\|…@<krídlo>`, ktorý **nikdy neexistuje** (parser ho odmieta — `CLASS_OWNER_PART` má len `slide`/`lift`) | `payloads.rb:2401`, `:2336`; `hardware_sets.rb:1561`, `:1572-1580` | PRAVDA |
| S4 | Hlavička skupiny Sety (`hwSetsMetaText`) rozhoduje v JS kópiou znalosti resolvera (`hwHasLegacyItem`: „kľúč typu číta len položka bez klasifikácie") — pri závesoch **nepravda** | `hardware.js:849-889` | PRAVDA |
| S5 | Riadok nákupu pod položkou (`purchase` = `HardwareSets.explain`) set **menuje správne** — volá ten istý resolver. Nepravdu hovoria len **selecty a hlavička** | sonda: `explain.set_name` = set resolvera vo všetkých 19 prípadoch | PRAVDA |
| S6 | Príklad z nálezu (`{'hinge'=>'zaves-klasik'}`, dvierka Tip-On) **nekupuje** klasický záves: resolver ho vyberie, ale set je klasifikovaný ako klasický → **RED `hinge_set_mismatch`**, dvierka bez závesov, export stojí. **Tichý nákup** nastane pri **nezaradenom** (vlastnom) sete (`moj-zaves` → kúpi sa, ORANGE `hinge_set_unclassified`) alebo pri sete správnej triedy (`zaves-p2o` → kúpi sa ten istý ako projekt, ale zmena predvoľby projektu sa tejto skrinky netýka) | sonda H1, H2, H3 | PRAVDA (spresnenie nálezu) |
| S7 | Prípad P3 z delty H6b: zmiešaná skrinka (Tip-On + klasické) + skrinkový `hinge` → resolver dá obom krídlam ten istý set, riadok skrinky sa nekreslí, hlavička „podľa projektu", riadky krídel „podľa projektu — <triedny set projektu>" | sonda H7 | PRAVDA |
| S8 | Ďalšie rozchody tej istej príčiny: krídlo s `hinge@krídlo` (H5, H6) · sentinel „bez setu" alebo poškodená hodnota v skrinkovom `hinge` (H9 — dvierka bez závesov, Inspector „podľa projektu — Záves P2O") · projekt **len** so starou predvoľbou `hinge` (vlastný nezaradený set — migrácia `hinge_class_v1` triedny kľúč nevyrobí) → Inspector „podľa projektu — **bez setu**", nákup kupuje (H10, H11) · krídlo `hinge@` + triedny výber skrinky → riadok krídla „podľa skrinky — Blum", platí krídlo (H14) | sonda | PRAVDA |
| S9 | Neklasifikované (staršie) dvierka idú plochým zoznamom a sú **v zhode** (H12); výsuv a výklop klasifikovaný sú v zhode (S1, S2, L1) | sonda | PRAVDA |
| S10 | **Extrakcia reťaze je možná bez zmeny správania:** prototyp `resolve_mapping_source` (tá istá reťaz, navyše vráti úroveň a kľúč) dal na matici **492/492** položkových porovnaní rovnakú hodnotu ako `resolve_mapping_value` | `sonda_h18_proto_out.txt` P1 | PRAVDA |
| S11 | **„Bez vlastného výberu platí" zo zdroja resolvera** (zdroj sondy položky bez kľúča daného rozsahu) mení text **len pri závesoch** (174 rozsahov); výsuv, výklop a nohy **0 rozdielov** = bajtovo dnešný text | P2 | PRAVDA → byte-identita pre nezávesové typy je dosiahnuteľná |
| S12 | Hlavička podľa pravidla „počet vlastných kľúčov skrinky, ktoré resolver **naozaj použije**": zhoda s dnešnou v 189/312, rozdiel 123 — kategórie **(a)** závesy so starým/krídlovým kľúčom (nález, väčšina) · **(b)** zmiešané triedy s triednym výberom skrinky, ktorý platí (dnes „podľa projektu" — klame aj pri výsuve) · **(c)** mŕtve kľúče (krídlo/čelo, ktoré v skrinke už nie je; generický `lift` pri výklope bez systému) dnes rátané · **(d)** zatienený výber skrinky (každá položka má vlastný krídlový/čelový) dnes rátaný | P3 | PRAVDA → D4 |
| S13 | **Výber setu pri krídle klasifikovaných dvierok sa neuloží:** `apply_cabinet_override` zapíše `class:hinge\|tipon@front:F1/wing:single`, prestavba (`norm_hardware_sets`) ho **zahodí** a zároveň **zmaže** starý `hinge@krídlo`; status hlási úspech („set „Blum…““), nákup ide podľa projektu. Zrušenie výberu pri krídle (prázdna voľba) `hinge@krídlo` zmaže správne | sonda `owner_write`, `owner_clear`; `hardware_sets.rb:3741-3765`, `:3702`; `cabinet_builder.rb:3707-3714` | PRAVDA → **F1, mimo H18** |
| S14 | Riadok nákupu pri dvierkach s nesediacim setom hovorí „nesedí **so zásuvkou**" — `explain` posiela `'set_incompatible'` a zahodí `bad['reason']` (`hinge_set_mismatch`), ktorý `expand` použije; Nákup a Kontrola hovoria „nesedí s čelom … — vyber správny set…" | `hardware_sets.rb:5432-5435` vs `:4217-4223` | PRAVDA → **R2.6 (v H18)** |
| S15 | Voľba „podľa projektu" v riadku skrinky pri dvierkach so starým skrinkovým `hinge` zmaže len triedny kľúč — **starý `hinge` ostane**, nič sa nezmení | sonda `cab_clear` (`{'hinge'=>'moj-zaves'}` ostáva) | PRAVDA → Q1 |
| S16 | **Nezávislá pravda zdroja je možná bez nového helpera:** „značkovací" oracle (každý prítomný kľúč skrinky aj projektu dostane jedinečnú značku ako hodnotu, **starý** `resolve_mapping_value` vráti značku víťaza → kľúč, rozsah, úroveň z tvaru kľúča, pôvodná hodnota) sa zhoduje s prototypom v **492/492** položkách | `sonda_h18_audit.rb` A1 | PRAVDA → (§15 A1) |
| S17 | **Poškodený výber v plochých riadkoch klame:** staré dvierka s `hinge@krídlo` = poškodená hodnota → riadok krídla „(podľa skrinky/projektu)", resolver `mapping_invalid` (nič sa nekúpi); to isté v zmiešanej skrinke; poškodený skrinkový `hinge`/`slide` pri starších položkách → riadok skrinky **„podľa: parameter"** (marker sa tvári ako selektor) | sonda A3 (Node nad `hwOwnerOptionList`/`hwCabOptionList`) | PRAVDA → (§15 A3) |
| S18 | **Stav `blocked`** (projekt bez snapshotu + nekompatibilná knižnica): nákup aj riadok nákupu overridy skrinky **vypnú** (`production_core.rb:561`, `payloads.rb:2148-2149`), `hardware_set_options` ich číta (`:2235`) — pôvodný návrh by ukázal „1 vlastný" a „starší výber skrinky", hoci sa nepoužije | sonda A4 + čítanie | PRAVDA → (§15 A4) |
| S19 | `explain` pri sete iného typu pod kľúčom závesu dá `set_type_mismatch` („v projekte je iného typu kovania"), `expand` RED `hinge_set_mismatch` | sonda A6; `hardware_sets.rb:4205`, `:5426-5428` | PRAVDA → (§15 A6) |
| S20 | Stavová veta po zrušení výberu je pevná: „Závesy: platí predvoľba projektu." / „…pre dielec …: platí výber skrinky/projektu." — pri starom skrinkovom `hinge` nepravda; žiadny test ju nepripína | sonda A2; `actions_hardware.rb:1317-1326` | PRAVDA → (§15 A2) |
| S21 | Reťaz **expand → `purchase_csv` → `Budget.compute` → `CpExport`** beží headless nad klasifikovanými závesmi so skrinkovým aj krídlovým kľúčom (sekcia kovania 50,33 € nad seed katalógom, 1× RED) | `sonda_h18_cena.rb` | PRAVDA → (§15 A5) |

### 0.1 Matica — čo sa kúpi vs. čo Inspector ukazuje dnes (výber zo sondy; projekt = seed: Tip-On → Záves P2O, klasik → Záves KLASIK)

| Prípad | Config skrinky | Resolver / nákup | Hlavička Sety | Riadok skrinky | Riadok krídla |
|---|---|---|---|---|---|
| H0 kontrola | — | P2O, kúpi | podľa projektu ✓ | podľa projektu — Záves P2O ✓ | podľa projektu — Záves P2O ✓ |
| H1 Tip-On | `hinge`=KLASIK | KLASIK → **RED**, bez závesov | podľa projektu ✗ | podľa projektu — Záves P2O ✗ | podľa projektu — Záves P2O ✗ |
| H3 Tip-On | `hinge`=vlastný nezaradený | **kúpi vlastný** + ORANGE | podľa projektu ✗ | podľa projektu — Záves P2O ✗ | ✗ |
| H5 Tip-On | `hinge@krídlo`=KLASIK | **RED** | podľa projektu ✗ | (správne) | podľa projektu — Záves P2O ✗ |
| H7 zmiešaná | `hinge`=vlastný | obe krídla vlastný | podľa projektu ✗ | nekreslí sa | podľa projektu — <trieda> ✗ |
| H9 Tip-On | `hinge`=„bez setu" | **bez závesov** | podľa projektu ✗ | podľa projektu — Záves P2O ✗ | ✗ |
| H10 Tip-On | — (projekt len `hinge`=vlastný) | kúpi vlastný | podľa projektu ✓ | podľa projektu — **bez setu** ✗ | ✗ |
| H14 Tip-On | `class:…tipon`=Blum + `hinge@krídlo`=vlastný | krídlo vlastný | 1 vlastný (zhodou okolností) | Blum ✓ | podľa skrinky — Blum ✗ |
| S1/S2/L1 | generický `slide`/`lift` | resolver ignoruje | ✓ | ✓ | ✓ |

### 0.2 Kde sa zobrazenie skladá (súpis)

| Miesto | Čo robí | Po H18 |
|---|---|---|
| `hardware_sets.rb:4389-4468` `resolve_mapping_value` | reťaz precedencie | **telo sa presunie** do `resolve_mapping_source` (vráti aj úroveň a kľúč); `resolve_mapping_value` = jeho prvý prvok |
| `hardware_sets.rb:4283` | zastavenie klasifikovaného výklopu bez systému pred mapovaním | **predikát** zdieľaný s novým zdrojom položky (žiadna kópia podmienky) |
| `hardware_sets.rb:5409-5411` `explain` | obal položky (`EXPLAIN_OWNER`) + normalizácia overridov | ten istý obal použije `item_mapping_source` |
| `hardware_sets.rb:4205-4212`, `:5426-5428` | set iného typu pri dvierkach: `expand` RED, `explain` `set_type_mismatch` | **spoločný pomocník** pre obe (R2.6, §15 A6) |
| `hardware_sets.rb:4217-4223`, `:5432-5435` | nesúlad klasifikácie: `expand` s `bad['reason']`, `explain` bez neho | **spoločný pomocník** pre obe (R2.6) |
| `payloads.rb:2137-2167` `decorate_hardware_purchase` | riadok nákupu; pri `blocked` overridy vypne | pravidlo `blocked` v **jednom pomocníkovi** zdieľanom s R2.1 (§15 A4) |
| `payloads.rb:2223-2289` `hardware_set_options` | ponuka per typ | + kľúč **`own_count`**; poškodený skrinkový kľúč → `override_label` „neplatný výber (uložený výber)", `owner_default_label` „podľa skrinky — neplatný výber" (§15 A3) |
| `payloads.rb:2335-2358` `compat_scope` / `compat_none_label` | „bez vlastného výberu platí" | text zo **zdroja resolvera**; rozsah krídla pri dvierkach číta `hinge@krídlo` |
| `payloads.rb:2390-2418` `owner_set_overrides` | plochý riadok neklasifikovaných vlastníkov | poškodený záznam dostane `label` (§15 A3), inak bez zmeny |
| `actions_hardware.rb:1317-1326` `hw_set_status_msg` | stavová veta po zmene setu | zrušenie výberu: neutrálna pravdivá veta (§15 A2); telo `handle_set_hardware_set` **bez zmeny** |
| `hardware.js:849-889` `hwHasLegacyItem`, `hwSetsMetaText` | hlavička Sety | **súčet `own_count`**; `hwHasLegacyItem` zaniká |
| `hardware.js:430-436` `hwOwnerOptionList` | plochý riadok vlastníka | poškodený záznam ako zablokovaná vybraná voľba s textom servera (§15 A3) |
| `hardware.js:414-560` ostatné option listy a tooltipy | kreslia `none_label`, `current`, `stored` | **bez zmeny** (texty prídu pravdivé zo servera) |

## 1 · Cieľ

Pri každej skrinke Inspector v Kovaní povie, **ktorý set naozaj platí a odkiaľ**: hlavička Sety „podľa projektu" znamená, že sa naozaj nič vlastné nepoužíva;
riadok skrinky a riadky krídel ukážu starší výber skrinky či krídla, keď platí; text pochádza z **tej istej funkcie**, ktorou sa vyberá set pre nákup. Nákup, rozpočet,
ponuka, VEPO a config sa nemenia ani o bajt.

**Príklad (H1):** skrinka vložená zo starej šablóny má zapísaný set závesov „Záves KLASIK", dvierka sú dnes Tip-On. Dnes: Sety „podľa projektu", riadok „podľa
projektu — Záves P2O", Nákup dvierka bez závesov (RED). Po H18: Sety **„1 vlastný"**, riadok skrinky **„podľa staršieho výberu skrinky — Záves KLASIK…"**, riadok krídla
to isté, riadok nákupu „set „zaves-klasik“ nesedí s čelom (iný spôsob otvárania) — vyber správny set…". Výber Tip-On setu v riadku skrinky starý výber prebije (ako dnes).

## 2 · Rez a odhad — jeden PR

| Časť | Obsah | Kód pluginu | Testy | In-SU | Odhad |
|---|---|---|---|---|---|
| **H18** | R0 golden + nezávislá pravda zdroja + cenový golden + matica zhody PRED zásahom (1. commit) → R1 resolver so zdrojom → R2 payload → R3 JS → testy, mutácie, docs, fotky | ~+190 / −90 (Ruby ~+175/−55, JS ~+10/−30) (§15) | ~850 (matica s `blocked` a poškodenými kľúčmi, 3 nové sady, prepis T4 v `test_h6b_suhrny.js`) | nie | ~1,5 dňa (§15) |

Pod 300 riadkami kódu pluginu; predrecenzia je povinná z triedy (§5). **F1** (výber pri krídle) je samostatná dávka **H18b** (§14) — mení zápis do modelu a nákup.

## 3 · Scope IN

1. **R1** jedna reťaz precedencie so zdrojom (`resolve_mapping_source`) + zdroj položky (`item_mapping_source`) v `core/hardware_sets.rb`.
2. **R2** `own_count`, pravdivé `none_label` a rozsah krídla dvierok v `ui/panel/payloads.rb`, účinné overridy pri `blocked` (R2.1, §15 A4); **R2.6** text riadku
   nákupu pri nesediacom zavese aj pri sete iného typu (`explain`, §15 A6); **R2.7** poškodený výber v plochých riadkoch (§15 A3); **R2.8** stavová veta po zrušení
   výberu (§15 A2).
3. **R3** hlavička Sety zo servera a poškodený záznam vlastníka v `ui/js/hardware.js`.
4. Golden (vrátane cenového, §15 A5), nezávislá pravda zdroja (§15 A1), matica zhody, mutácie, docs (§11), fotky.

## 4 · Scope OUT

- **Výber resolvera, precedencia, config, nákup, rozpočet, ponuka, VEPO, Kontrola** — nič (golden R0). Žiadna migrácia, žiadny zápis do modelu, žiadna zmena schémy.
- **Zápis výberu pri krídle** (F1 → H18b) a **voľba, ktorá zmaže starší výber skrinky** (Q1 → H18b alebo nikdy) — obe menia zápis do modelu.
- Plochý riadok neklasifikovaných vlastníkov — **mimo poškodenej hodnoty** (R2.7) v zhode (S9); `project_label` bez zmeny.
- Štúdio (Pravidlá, Nákup, Kontrola) — počítajú cez `expand`, sú pravdivé. Texty `unmapped_reason_sk` (Nákup/Kontrola/CSV) sa nemenia.
- Poškodený snapshot setov (`:invalid`) — nákup overridy skrinky číta (sety chýbajú), panel ich ponúka ako dnes; pravdu nesie červený riadok nákupu (D5).
  Stav `blocked` sa naopak rieši (R2.1, §15 A4).
- Telo `handle_set_hardware_set` a celá zápisová cesta (`apply_cabinet_override`) — bez zmeny; mení sa len text stavovej vety (R2.8).
- Mŕtve kľúče `typ@<čelo>` čiel, ktoré v skrinke už nie sú (nečistia sa — F4).

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: ÁNO (konzervatívne, hranica posúdená výslovne).** Mení sa len zobrazenie — žiadny vzorec, rozmer, počet, `row_key` ani export. Ale: (1) definícia
  počíta aj **„to, čo okno ukazuje"** o tom, podľa čoho sa objednáva — set pri skrinke je presne „čo sa objedná", Michal podľa neho kontroluje zákazku; (2) dávka
  **presúva telo resolvera setov**, ktorý rozhoduje nákup každej zákazky; (3) mení text riadku nákupu (R2.6). Nie je to „popisný stĺpec bez vplyvu na objednávanie".
  Dôsledok: brány výrobnej dávky celé — golden R0 bajtovo **vrátane cenového goldenu klasifikovaných závesov (R0.5, §15 A5)**, predrecenzia, KRONIKA ako výrobná dávka.
  Rozšírenia z auditu (A2 text stavovej vety, A3 poškodený výber, A4 `blocked`, A6 text `explain`) sú tiež len zobrazenie — triedu nemenia.
- **Audit návrhu: ÁNO** — mení sa **kontrakt payloadu panela Ruby↔JS** (nový kľúč `own_count`, nový význam `compat.*.none_label`, rozsah krídla dvierok číta iný kľúč;
  precedens H12 A5 „kontrakt Ruby↔JS → audit-povinná") a jadro resolvera. Package do `_dev/audit_h18/`, prompt `audit_h18_prompt.md`.
- **Predrecenzia: povinná** (audit-povinná + výrobná).
- **In-SU: nie je brána (znovu posúdené po audite, §15 A8)** — žiadny spúšťač (builder, observer, undo/operácia, geometria, akcia panela zapisujúca do modelu).
  R2.8 mení **len čistú textovú funkciu** `hw_set_status_msg` (headless test T9); telo `handle_set_hardware_set`, poradie operácie, zápis a `push_selected` ostávajú
  **bez jediného zmeneného riadku** — predrecenzia to overí v diffe (ak by sa telo handlera menilo, in-SU sa stáva bránou). Resolver beží aj pri stavbe (Kontrola,
  brány), ale jeho výstup je bajtovo rovnaký (R0). Payload v SketchUpe overí `ui_foto -Record` (beží overenou slučkou nad kópiou ENGINEtests.skp).
- **Nový ovládací prvok: NIE.** Žiadne tlačidlo, voľba ani pole; mení sa text existujúcich volieb a hlavičky.
- **Fotky: `-Record` povinné** (zmena tvaru payloadu), potom `-Shoot`; cesty do reportu.

### 5.1 Závislosti — overiť proti mainu pri štarte

- **H15** (dáta kovania oddelené od mechaniky setov) mení `core/hardware_sets.rb` (seed dáta) — ktorá zmerguje druhá, rebase a prepočet riadkov; R0 golden sa nahráva
  na maine pri štarte H18 (po H15, ak už je), nikdy sa neregeneruje.
- **H17** (spoločná príprava exportov) volá `expand` — bez prieniku, golden nákupu ho stráži z oboch strán.
- **H6c/H7b** — prienik len `?v=`, STAV, KRONIKA.
- **H18b** (F1, ak ho Michal schváli) štartuje až z mainu po H18 — stavia na rozsahu krídla z R2.4.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit, plugin bez zmeny)

- **R0.1 Matica** `tests/fixtures/h18_golden/cases.rb` (jeden zdroj pre generátor aj testy, vzor `kovh_golden`): sady položiek (dvierka Tip-On, 2 klasické krídla,
  zmiešané triedy, staršie dvierka, klasifikované + staršie, výsuv 1 a 2 čelá, zmiešaný výsuv, výsuv + starší výsuv, nohy, výklop so systémom, výklop bez systému) ×
  kľúče skrinky (generický, triedny, krídlový/čelový, sentinel „bez setu", poškodená hodnota, kombinácie, kľúč čela, ktoré v skrinke nie je) × projekt (seed · len
  `hinge` s vlastným nezaradeným setom · prázdny) **× stav projektu `ok` a `blocked`** (projekt bez snapshotu + nekompatibilná knižnica, §15 A4); kľúče navyše
  **poškodený `hinge@krídlo` pri starších dvierkach (aj v zmiešanej skrinke) a poškodený skrinkový `hinge`/`slide` pri starších položkách** (§15 A3) a **set iného typu
  pod kľúčom závesu** (§15 A6). Vzor a čísla: `sonda_h18_proto.rb` (312 prípadov), `sonda_h18_audit.rb`. Vlastné fixtúrne sety (`moj-zaves` nezaradený, Tip-On iného
  výrobcu) sú v `cases.rb`, produkčný seed sa nemení.
- **R0.2 Generátor** `tests/fixtures/h18_golden/generate.rb` (ručne, test ho nevolá) zapíše:
  - `resolver.json` — pre každý prípad a položku `resolve_set_id` (set, dôvod, info), riadky a `unmapped`/`notes` z `expand`, `explain` (`set_id`, `set_name`,
    `problems`) = **pravda nákupu**;
  - **`source_pred.json` (§15 A1) — nezávislá pravda zdroja** „značkovacím" oracle nad **starým** `resolve_mapping_value` (S16; žiadny nový helper): pre každú položku
    `[raw_value, level, key]`, pre **sondu skrinky** (`owner_part_key: ''`, overridy bez triedneho kľúča skrinky) a pre **sondu vlastníka** (overridy bez víťazného
    kľúča úrovne `owner`/`owner_class`) to isté. Pri `blocked` sa oracle počíta s overridmi, ktoré použije nákup (`{}`). Úroveň sa odvodí len z tvaru kľúča a rozsahu
    (skrinka/projekt). Kód oracle je v `cases.rb`/`generate.rb`, nie v plugine;
  - `payload_pred.json` — `Panel.hardware_set_options` každého prípadu (dnešný stav).
- **R0.3 Matica zhody PRED** `tests/fixtures/h18_golden/zhoda_pred.json` (ručný `generate_zhoda.js` nad `payload_pred.json` + `source_pred.json` + `resolver.json`
  s reálnymi funkciami `hardware.js`): zoznam (prípad, rozsah, čo Inspector ukazuje, čo platí) podľa pravidiel Z1–Z6 (R4) — dnešné rozchody, ktoré H18 odstraňuje.
  Je to dôkaz nálezu v PR.
- **R0.4** Existujúce goldeny nákupu a cien (`kovh_golden`, `ceny_m2_golden`, `np4_golden`, `h9_golden`) sa v H18 **nedotknú** — sú regresná poistka, **nie dôkaz**
  pre klasifikované závesy (bez `hardware_expansion` v rozpočte, resp. závesy bez klasifikácie — §15 A5); `resolver.json` po zásahu bajtovo rovnaký **okrem**
  `explain.problems`/`unmapped` dvierok s nesediacim setom a setom iného typu (R2.6 — test ich vymenuje presne).
- **R0.5 Cenový golden klasifikovaných závesov (§15 A5)** `tests/fixtures/h18_golden/cena_zavesy.json` (ten istý ručný generátor, nahraný PRED zásahom, nikdy sa
  neregeneruje): skrinky **A** Tip-On + skrinkový `hinge`=Záves P2O · **B** 2 klasické krídla + `hinge@krídlo`=Záves KLASIK · **C** Tip-On + klasické + skrinkový
  `hinge`=Záves KLASIK (1× RED) · **D** Tip-On bez výberu · **E** Tip-On + skrinkový `hinge`=nezaradený vlastný set mimo katalógu → `HardwareSets.expand` (riadky,
  `unmapped`, `notes`) → `HardwareSets.purchase_csv` (text) → `Budget.compute` (sekcia kovania + `totals`; pevné `now`, seed dodávateľa, prázdny kusovník) →
  `CpExport.cp_rows` a kovanie z `CpExport.specification`. Overené sondou `sonda_h18_cena.rb` (beží headless). Test bajtovo porovná po zásahu.

### R1 · Jedna reťaz precedencie so zdrojom (`core/hardware_sets.rb`)

- **R1.1** `resolve_mapping_source(generic_type, it, cabinet_overrides, mapping)` → `[hodnota, úroveň, kľúč]` alebo `[nil, nil, nil]`. Telo = **dnešná reťaz
  `resolve_mapping_value` presunutá doslovne** (všetky tri vetvy: záves, klasifikovaná položka, ostatné); každé `return v` vráti aj úroveň a kľúč, ktorý vyhral.
  Úrovne = zmrazená konštanta `MAPPING_SOURCE_LEVELS = %w[owner owner_class cab_class cab project_class project]`, vlastné úrovne skrinky
  `MAPPING_OWN_LEVELS = %w[owner owner_class cab_class cab]`.
- **R1.2** `resolve_mapping_value(...)` = `resolve_mapping_source(...).first` — signatúra, volajúci a komentáre histórie precedencie ostávajú (komentáre sa presunú k reťazi).
- **R1.3** Predikát `mapping_skipped?(it, ck)` (dnes inline `ck.nil? && lift_item?(it)`, `:4283`) — volá ho `resolve_set_id` aj R1.4. **Žiadna iná kópia podmienok
  resolvera** mimo `hardware_sets.rb`.
- **R1.4** `item_mapping_source(item, mapping, overrides)` — zdroj pre **uloženú položku skrinky** presne tak, ako ju vidí `explain` (rovnaký obal `EXPLAIN_OWNER`
  a `normalize_mapping(..., allow_owner: true)`; ideálne spoločný súkromný pomocník s `explain`, ktorého výstup sa nesmie zmeniť); položka, ktorú `expand` nerozpisuje
  (prázdny typ, `quantity < 1`) a položka s `mapping_skipped?` → `[nil, nil, nil]`. Filter zdieľa s `expand` predikátom, nie kópiou.

### R2 · Payload Setov (`ui/panel/payloads.rb`)

- **R2.1 Vstupy (§15 A4):** projekt z `hardware_read_state`, položky `hardware`; overridy skrinky v **dvoch úlohách** — **uložené** (`cabinet_set_overrides(cfg)`,
  z nich `current`/`stored`/`value_text` a ponuka, ako dnes) a **účinné pre nákup** = výsledok **jedného pomocníka** (napr. `hw_purchase_overrides(cfg, status)`:
  `status == :missing && HardwareSets.library_read_only?` → `{}`, inak uložené), ktorý **zdieľa** `decorate_hardware_purchase` (`:2148-2149`) a ktorý zrkadlí
  `ProductionCore.hardware_expansion` (`production_core.rb:561`). Z účinných sa počíta `own_count`, `none_label` a víťaz vlastníka. Mimo `blocked` sú obe sady
  totožné. `class_compat_payload` ponechá **signatúru** (8 volaní v `test_kovd1b_ui.rb` a `test_kove2_ui.rb`); účinné overridy dostane voliteľným kľúčovým argumentom.
- **R2.2 `own_count`** (nový kľúč každého záznamu typu): počet **rôznych kľúčov** skrinky, ktoré pre aspoň jednu položku daného typu vrátil `item_mapping_source`
  nad **účinnými** overridmi na úrovni z `MAPPING_OWN_LEVELS`. Typ bez položky (záznam len z kľúča overridu) = 0; pri `blocked` = 0. Celé číslo, nikdy `nil`.
- **R2.3 „Bez vlastného výberu platí" (`none_label`)** = zdroj resolvera (nad účinnými overridmi) pre **sondu rozsahu bez jeho vlastného kľúča**:
  - **skrinka:** prvá položka triedy so `owner_part_key: ''` (kľúče krídiel/čiel sa nečítajú), overridy bez triedneho kľúča skrinky;
  - **krídlo/čelo:** položka vlastníka (tá, z ktorej `active_class_by_owner` berie triedu), overridy bez kľúča, ktorý `item_mapping_source` vrátil na úrovni
    `owner`/`owner_class` (keď taký nie je, zdroj samotný);
  - text `"podľa <zdroj> — <mapping_value_text>"`, slovník zdroja (jediná tabuľka v `payloads.rb`): `cab_class` → **„skrinky"** · `cab` → **„staršieho výberu skrinky"**
    · `project_class`, `project`, žiadny → **„projektu"**. Pre výsuv a výklop dá **bajtovo dnešný text** (S11) — test to stráži nad celou maticou.
- **R2.4 Rozsah krídla dvierok** (`compat.owners[krídlo]` pri `hinge`): `current` / `stored` / `value_text` z hodnoty, ktorú `item_mapping_source` vrátil na úrovni
  `owner` nad **uloženými** overridmi (`hinge@<krídlo>` — kľúč, ktorý resolver naozaj číta); pri výsuve a výklope ostáva `class:…@<čelo>` (dnešný výsledok, len
  odvodený zo zdroja). `class_key`, `class_label`, `scope_label`, `options` bez zmeny. **Nové kľúče v rozsahu nepribúdajú.** Pri `blocked` uložený výber krídla ostane
  viditeľný ako „(uložený výber)" (ponuka je prázdna), `none_label` z účinných overridov — uložený ≠ účinný (§15 A4).
- **R2.5** `compat_none_label` a premenná `inherited` zaniknú; komentár `owner_set_overrides` (`:2379-2389`) sa opraví — záves `hinge@<krídlo>` číta aj klasifikované
  dvierka a ukazuje ho `compat.owners`.
- **R2.6 Text riadku nákupu pri dvierkach** (`explain`, §15 A6): **dve vetvy, dva spoločné pomocníky** pre `expand` aj `explain` — (1) set iného typu
  (`:4205-4212` vs `:5426-5428`; dvierka → RED `hinge_set_mismatch` s `detail: 'generic_type'`, ostatné `set_type_mismatch`), (2) nesúlad klasifikácie
  (`bad['reason'] || 'set_incompatible'`, `:4217-4223` vs `:5432-5435`). Mení sa výhradne `problems`/`unmapped` v `explain` pri dvierkach; výklop, výsuv a nohy
  bez zmeny. **Úplnú paritu `explain`/`expand` dávka netvrdí** — tvrdí ju pre tieto dve vetvy (ostatné vetvy už zhodné sú: `set_missing`, `length_unsupported`).
- **R2.7 Poškodený výber v plochých riadkoch (§15 A3):** `owner_set_overrides` pri poškodenom zázname pridá `'label' => 'neplatný výber (uložený výber)'`
  (text z `HardwareSets.mapping_value_text` + prípona); `hardware_set_options` pri poškodenom kľúči typu skrinky pošle `override_label` = „neplatný výber (uložený
  výber)" (dnes „podľa: parameter") a `owner_default_label` „podľa skrinky — neplatný výber". Platí pre každý typ (výsuv, nohy… — tá istá cesta).
- **R2.8 Stavová veta po zrušení výberu (§15 A2):** `hw_set_status_msg` pri `value.nil?` netvrdí, čo platí: **„<Závesy>: výber zrušený."** (skrinka) a
  **„<Závesy> pre dielec <…>: výber zrušený."** (dielec) — čo platí, ukáže hneď nasledujúci `push_selected` v riadku setu (pravdivo, R2.3). Veta pri výbere setu
  ostáva. Telo `handle_set_hardware_set` sa nemení (§5). *Alternatíva „platí starší výber skrinky — X" by potrebovala config v handleri — zamietnutá (in-SU).*

### R3 · Hlavička Sety (`ui/js/hardware.js`)

- **R3.1** `hwSetsMetaText(setOptions)` = súčet `own_count` záznamov (nečíselná hodnota = 0); text a skloňovanie bez zmeny (`'podľa projektu'`, „1 vlastný",
  „2 vlastné", „5 vlastných"; prázdna ponuka = `''`). `hwHasLegacyItem` a jeho export zaniknú; `hwMetaApply` volá `hwSetsMetaText(HW_SET_OPTIONS)` (pri `items == null` ostáva `''`).
- **R3.2 (§15 A3)** `hwOwnerOptionList`: poškodený záznam vlastníka (`invalid`) sa kreslí ako **zablokovaná vybraná voľba** s textom servera (`ov.label`), rovnako
  ako dnes výber podľa parametra (`HW_SET_PARAM` — nikdy sa neodošle); bez `label` záložné „neplatný výber".
- **R3.3** Inak JS bez zmeny — option listy, tooltipy (`hwOwnerTitle`, `hwCabTitle`) a ľahký push kreslia texty servera. Všetky `?v=` = nová VERSION.

### R4 · Matica zhody — pravidlá (test po zásahu, `zhoda_pred.json` pred ním)

Pre každý prípad matice, nad payloadom z nového kódu, **nezávislou pravdou zdroja `source_pred.json`** (R0.2, starý kód — nikdy nový helper, §15 A1) a pravdou
nákupu `resolver.json`, **reálnymi funkciami `hardware.js`**:
- **Z1 krídlo/čelo** s `compat.owners`: zobrazená voľba (`hwOwnerOptionList`) — pri úrovni oracle `owner`/`owner_class`: `current` = `mapping_option_id(raw_value)`
  (selektor ako celok, nie set po výbere pásma), alebo `stored` s `value_text` = text `raw_value`; inak je vybraná prvá voľba.
- **Z1b plochý riadok vlastníka (§15 A3)** (staršie položky, aj v zmiešanej skrinke): úroveň `owner` ⇔ vybraná je vlastná voľba (set, selektor alebo poškodený
  záznam s textom „neplatný výber"); inak „(podľa skrinky/projektu)".
- **Z2 prvá voľba a tooltip — vždy, aj keď je vybraná iná voľba (§15 A1):** text prvej voľby == „podľa <slovník(level sondy)> — <text raw_value sondy>" zo
  `source_pred.json` (sonda **bez vlastného kľúča rozsahu**), a `hwOwnerTitle`/`hwCabTitle` ho obsahuje; slovník: `cab_class` „skrinky", `cab` „staršieho výberu
  skrinky", projekt/žiadny „projektu".
- **Z3 skrinka** (`compat.cab`): ako Z1 + Z2 pre sondu skrinky (`owner_part_key: ''`; prvá voľba zo sondy **aj bez triedneho kľúča skrinky**).
- **Z4 hlavička:** „podľa projektu" ⇔ žiadna položka nemá v `source_pred.json` úroveň z `MAPPING_OWN_LEVELS`; inak číslo = počet rôznych víťazných kľúčov skrinky.
- **Z5 `blocked` (§15 A4):** hlavička „podľa projektu", prvé voľby „podľa projektu — bez setu", uložený výber viditeľný ako „(uložený výber)".
- **Z6 plochý riadok skrinky** s poškodeným kľúčom typu: vybraná zablokovaná voľba „neplatný výber (uložený výber)" (§15 A3).
- **Rozdiel PRED → PO** (zmenené rozsahy, riadky a hlavičky) ⊆ `zhoda_pred.json` ∪ kategórie D4 (b)–(d) — nič iné sa nezmení.

## 7 · Testy a DoD

- **T0 · golden:** `tests/pure/test_h18_sety_pravda.rb` — v **1. commite** zelený na starom kóde (čerstvý výpočet == `resolver.json` a `payload_pred.json`);
  po zásahu: `resolver.json` bajtovo (výnimka R2.6 vymenovaná), pre **nezávesové typy** payload **bez `own_count`** == `payload_pred.json` bajtovo **okrem**
  vymenovaných prípadov s poškodeným kľúčom (R2.7: `override_label`, `owner_default_label`, `owner_overrides[*].label`); pre závesy sa smú líšiť **len**
  `compat.*.none_label`/`current`/`stored`/`value_text`, R2.7 polia a `own_count`. **Cenový golden `cena_zavesy.json` (R0.5) bajtovo.** Existujúce goldeny R0.4
  zelené **bez regenerácie**.
- **T1 · resolver (§15 A1):** `resolve_mapping_source` == **`source_pred.json`** (`[raw_value, level, key]` z oracle nad starým kódom) na celej matici — nie len
  `.first` voči vlastnému obalu; `resolve_mapping_value` == `raw_value`; úroveň a kľúč pre každú vetvu reťaze (5 stupňov závesu, 3 klasifikovanej položky,
  3 ostatných); `mapping_skipped?` (výklop bez systému → žiadny zdroj, aj keď má skrinka generický `lift`).
- **T2 · payload:** `own_count` pre kategórie (a)–(d), typ bez položky a `blocked` (= 0, §15 A4); `none_label` slovník (3 zdroje × skrinka/krídlo); rozsah krídla
  s `hinge@krídlo` (výber v ponuke → `current`, mimo ponuky → `stored` + `value_text`); zmiešaná skrinka (H7) — bez riadku skrinky, krídla „podľa staršieho výberu
  skrinky"; `blocked` — uložený výber ostane „(uložený výber)", `none_label` a hlavička z účinných overridov; pomocník účinných overridov zdieľaný s
  `decorate_hardware_purchase` (riadok nákupu bajtovo rovnaký); **R2.7** poškodený `hinge@krídlo` (staré dvierka, aj v zmiešanej skrinke) a poškodený skrinkový
  `hinge`/`slide` → texty R2.7 (§15 A3).
- **T3 · zhoda (JS):** `tests/js/test_h18_sety_pravda.js` nad `h18_golden/payload_po.json` (generuje `generate.rb` z nového kódu; Ruby T0 stráži, že fixtúra =
  čerstvý payload — to dokazuje **aktuálnosť** fixtúry, **správnosť** zobrazenia dokazuje až porovnanie so `source_pred.json` zo starého kódu, §15 A1) — Z1–Z6
  a podmnožina zmien. **Prvá voľba a tooltip sa overujú v každom rozsahu aj vtedy, keď je vybraná iná voľba** (Z2).
- **T4 · prepis `tests/js/test_h6b_suhrny.js` (21 výskytov `hwSetsMetaText`):** syntetické payloady dostanú `own_count`; každý assert sa nahradí ekvivalentom
  (rovnaký text pri rovnakom `own_count`), asserty logiky `hwHasLegacyItem` sa presunú do Ruby T2 (server je autorita). **Vedomá zmena očakávania (§15 A7):**
  `:242` („bez klasifikácie platí kľúč typu aj bez zoznamu položiek" → „1 vlastný") — typ bez položky má `own_count` 0 → **„podľa projektu"**; assert sa
  **prepíše na nové očakávanie s komentárom D4 (c)**, nie zmaže. **PR vypíše 1:1** čo sa prepísalo a kam.
- **T5 · R2.6 (§15 A6):** `explain` dvierok Tip-On so setom KLASIK → `problems` = veta Nákupu („nesedí s čelom (iný spôsob otvárania) — …"); dvierka so setom
  **iného typu** (nohy pod `class:hinge|tipon`) → `explain.unmapped` = `hinge_set_mismatch` ako `expand`; výsuv/výklop/nohy → bez zmeny.
- **T9 · stavová veta (§15 A2):** `hw_set_status_msg` pri zrušení (skrinka, dielec) = „výber zrušený" bez tvrdenia o projekte; pri výbere setu a selektora bez zmeny;
  zdrojový guard, že telo `handle_set_hardware_set` volá `hw_set_status_msg` s tými istými argumentmi ako dnes.
- **T6:** `ruby tests/run_all.rb` + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + `ruby scripts/encoding_guard.rb --repo`.
- **T7 · fotky:** `scripts\ui_foto.ps1 -Record` na hlave vetvy (+ `-Shoot` na čerstvom maine pred zásahom na porovnanie); Inspector kontext Kovanie — na dátach
  ENGINEtests sa zmena pravdepodobne neprejaví (bez starých kľúčov), cieľom je dôkaz, že payload v SketchUpe prešiel; scenár nálezu overí smoke §10.
- **T8 · mutácie** — každá má test, ktorý ju zhodí (PR priloží beh každej; mutácia, ktorú nič nezhodí = doplniť test):

| M | Mutácia | Zhodí |
|---|---|---|
| M1 | v reťazi závesu prehodené `cab_class` a `cab` | T0 `resolver.json` |
| M2 | zdroj hlási `project` namiesto `cab` (hodnota správna) | T1 (`source_pred.json`), T3 Z2, Z4 (H1 „podľa projektu") |
| M3 | `own_count` ráta aj projektové úrovne | T2, T3 Z4 |
| M4 | `own_count` ráta aj zatienený kľúč (nie víťaza) | T2 kategória (d) |
| M5 | `none_label` skrinky bez odobratia triedneho kľúča | **T3 Z2/Z3 — prvá voľba overená aj pri vybranom triednom sete** (H8; §15 A1) |
| M6 | sonda skrinky ponechá `owner_part_key` | T2/T3 Z3 (H14) |
| M7 | rozsah krídla dvierok číta ďalej `class:hinge\|…@krídlo` | T3 Z1/Z2 (H5, H6) |
| M8 | `item_mapping_source` ignoruje `mapping_skipped?` | T1, T2 (výklop bez systému) |
| M9 | `item_mapping_source` bez filtra `quantity < 1` | T2 (položka s počtom 0 nemá zdroj) |
| M10 | JS `hwSetsMetaText` po starom (bez `own_count`) | T3 Z4, T4 |
| M11 | slovník zdroja pre `project_class` iný text | T0 bajtovo (výsuv) |
| M12 | `explain` ďalej `'set_incompatible'` pri dvierkach | T5 |
| M13 | `resolve_mapping_value` vlastná kópia reťaze (nie delegácia) s odchýlkou pri sentineli | T1 (oracle), T0 |
| M14 | `current` krídla zo selektora po výbere pásma (set namiesto celého selektora) | T3 Z1 (§15 A1) |
| M15 | tooltip skrinky/krídla bez `none_label` | T3 Z2 (§15 A1) |
| M16 | `hw_set_status_msg` pri zrušení ďalej „platí predvoľba projektu" | T9 (§15 A2) |
| M17 | `hwOwnerOptionList` ignoruje `invalid` (dnešný stav) | T3 Z1b (§15 A3) |
| M18 | poškodený skrinkový kľúč typu ďalej „podľa: parameter" | T2, T3 Z6 (§15 A3) |
| M19 | `own_count`/`none_label` z uložených overridov aj pri `blocked` | T2, T3 Z5 (§15 A4) |
| M20 | `decorate_hardware_purchase` nepoužije spoločný pomocník (vlastná kópia pravidla `blocked`) | T2 zdrojový guard + T0 riadok nákupu (§15 A4) |
| M21 | `explain` pri sete iného typu ďalej `set_type_mismatch` pri dvierkach | T5 (§15 A6) |
| M22 | v reťazi závesu `hinge@krídlo` až za triednym kľúčom skrinky (rovnaký set na oboch úrovniach) | T1 oracle — kľúč aj úroveň, nie len set (§15 A1) |
| M23 | prehodené poradie krídlového a skrinkového výberu v nákupe | **T0 `cena_zavesy.json`** (skrinka B/C, §15 A5) |

- **DoD:** T0–T9 zelené · golden R0 a cenový golden R0.5 nedotknuté (okrem vymenovanej R2.6/R2.7) · mutácie v PR · fotky · docs §11 · PR s „Predrecenziou", maticou
  PRED/PO (počty z `zhoda_pred.json` → 0) a vetou **„nákup kovania (expanzia + CSV), rozpočet (sekcia kovania a súčty) a cenová ponuka nad klasifikovanými
  závesmi bajtovo rovnaké (`cena_zavesy.json`); výsledok resolvera pre celú maticu bajtovo rovnaký (`resolver.json`) — VEPO a brány exportov čítajú ten istý
  výsledok"** (§15 A5 — deklarácia len v rozsahu dôkazov).

## 8 · In-SU — nie je brána

Žiadny spúšťač (§5). `run_su_tests.ps1` sa nespúšťa ako brána; payload v SketchUpe overí `ui_foto -Record`. Smoke model §10 pripraví orchestrátor cez SkAgent
v **testovacom** okne (overiť `model.path`).

## 9 · Riziká

- **Extrakcia reťaze zmení výber setu** (preklep pri presune) — T0 `resolver.json` na celej matici + existujúce goldeny nákupu, M1/M13.
- **Text pri výsuve/výklope sa posunie** — T0 bajtovo (S11), M11.
- **Hlavička sa zmení aj mimo závesov** (D4 b–d) — vedome, vymenované kategórie, smoke bod 5. Michal môže vidieť „1 vlastný" tam, kde dnes videl „podľa projektu"
  (zmiešané zásuvky s výberom skrinky) a naopak (mŕtvy kľúč odstráneného čela).
- **H18 zviditeľní F1:** po výbere setu pri krídle Tip-On dvierok Inspector ukáže pravdu (výber sa neuložil) — dnes ukazuje „podľa projektu" tiež, ale
  status hlási úspech; navyše zápis **zmaže platný starší výber krídla** (nákup sa môže zmeniť — §15 A7). Pre Michala vysvetlené v Q2; náprava **H18b prioritne**.
- **Fixtúra „po" dokazuje len aktuálnosť** (§15 A1) — správnosť zobrazenia stojí na `source_pred.json` a `resolver.json` zo starého kódu; tie sa nikdy neregenerujú.
- **`blocked` a poškodené kľúče** — zriedkavé stavy, ale v matici (Z5, Z1b, Z6) a v T2.
- **Kolízia s H15** v `hardware_sets.rb` (§5.1). Dáta zákaziek ani `%APPDATA%` sa nemenia → zmiešané PC (Lucia) bez rizika.

## 10 · Smoke checklist pre Michala (po mergi a inštalácii)

**Príprava (orchestrátor, nie Michal):** kópia `_dev\ENGINEtests.skp` → `_dev\H18_smoke.skp`, cez SkAgent 4 skrinky (zápis `hardware_sets` + prestavba tou istou cestou
ako `handle_set_hardware_set` — `existing_params` → `rebuild_many`, jedna operácia):
**A** 1 dvierka Tip-On + skrinka `{'hinge'=>'zaves-klasik'}` · **B** 2 klasické krídla + `{'hinge@front:F1/wing:left'=>'zaves-klasik'}` · **C** dvierka Tip-On (F1)
+ klasické (F2) + skrinka `{'hinge'=>'zaves-p2o'}` · **D** 1 dvierka Tip-On bez výberu (kontrola) · **E** 1 dvierka Tip-On + `{'hinge@front:F1/wing:single'=>''}`
(§15 A3). Uložiť, cestu dať do reportu.

1. **A** → Kovanie: Sety **„1 vlastný"**; riadok Závesy **„podľa staršieho výberu skrinky — Záves KLASIK…"**; riadok krídla to isté; riadok nákupu červený
   „nesedí s čelom (iný spôsob otvárania)…". Štúdio → Nákup kovania: dvierka bez závesov (rovnako ako pred inštaláciou).
2. **A** → v riadku Závesy vyber „Záves P2O + TipOn": Sety „1 vlastný", krídlo „podľa skrinky — Záves P2O", nákup P2O. Potom vyber prvú voľbu → späť na stav bodu 1,
   stavová veta **„Závesy: výber zrušený."** (nie „platí predvoľba projektu" — §15 A2); vrátiť sa „na projekt" sa tu nedá — Q1.
3. **B** → riadok ľavého krídla ukazuje **„Záves KLASIK…"** (nie „podľa projektu"), pravé krídlo „podľa projektu — Záves KLASIK"; Sety „1 vlastný".
4. **C** → riadok skrinky v Setoch nie je (zmiešané dvierka, ako dnes); Sety **„1 vlastný"**; obe krídla „podľa staršieho výberu skrinky — Záves P2O"; nákup: Tip-On
   krídlo P2O, klasické červené.
5. **D** a ľubovoľná skrinka so zásuvkami bez vlastného výberu → všetko ako predtým („podľa projektu").
5b. **E** (príprava: 1 dvierka Tip-On + `{'hinge@front:F1/wing:single'=>''}` — prestavba ho uloží ako poškodený výber) → riadok krídla **„neplatný výber (uložený
   výber)"**, Sety „1 vlastný", riadok nákupu „výber setu na tejto skrinke je poškodený…". Plochý riadok starších dvierok (§15 A3) overujú len headless testy —
   prestavba dvierka klasifikuje.
6. **Reálna zákazka (kópia):** Nákup kovania a Rozpočet — rovnaké čísla ako pred inštaláciou (voliteľne porovnať CSV nákupu zo starej a novej verzie).

## 11 · Checklist uzáveru

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** → T0–T9 → **architektúra na mieste:** `docs/architecture/hardware.md`
odsek `### hardware_sets.rb`, odstavec KOV-F1 „PRECEDENCIA závesu je PÄŤSTUPŇOVÁ" (+ `resolve_mapping_source`, úrovne, `item_mapping_source`, predikát
`mapping_skipped?`; `explain` a `expand` zdieľajú pomocníkov dvoch vetiev nesúladu — `hinge_set_mismatch` pri dvierkach v oboch) · `docs/architecture/ui-lifecycle.md`
odsek `### payloads.rb` (odrážky „`hardware_set_options` a owner výbery" — dnes nepravdivá veta „legacy `typ@owner` len pri neklasifikovanej položke" — a „`compat`":
`none_label` zo zdroja resolvera, slovník zdroja, `own_count`, rozsah krídla dvierok, **uložené vs. účinné overridy pri `blocked` a spoločný pomocník s riadkom
nákupu**, poškodený výber v plochých riadkoch) a `### Kontext Kovanie` (meta Sety = súčet `own_count`, `hwHasLegacyItem` zaniká; stavová veta pri zrušení výberu) ·
**Grep tvrdení o zoznamoch:**
`hwHasLegacyItem`, `compat_none_label`, „podľa projektu", `MAPPING_*_LEVELS` · STANDARD sa nemení (precedencia ani kontrakt dát nie) → **D-149** (§14) do
`archiv/DOGFOODING_vyriesene.md` (plný text + riadok INDEXU) → **prepis STAV** → **KRONIKA** odsek navrch (výrobná dávka) → **PLAN** riadok H18 s ✅ a PR →
package + surový audit do `SYSTEM/zdroje/bloky/HARDENING/` → **PR popis:** čo uvidí Michal (príklad §1), trieda, Predrecenzia, matica PRED/PO, mutácie, T4 1:1, fotky,
„golden nákupu a cien nedotknuté". Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Telo `resolve_mapping_value` sa presunie** do `resolve_mapping_source`; `resolve_mapping_value` = jeho prvý prvok (správanie bez zmeny, T0/T1) | „jedna pravda, nie kópia logiky" (Michal/brief) sa inak dosiahnuť nedá: kópia reťaze v payloade by sa pri ďalšej zmene precedencie rozišla (presne pasca `hwHasLegacyItem`); sondovanie odoberaním kľúčov by kódovalo mená kľúčov druhýkrát. S10: 492/492 zhoda | **áno** |
| D2 | **Pravda sa počíta na serveri, JS len kreslí** — `own_count` a hotové texty; `hwHasLegacyItem` zaniká | JS dnes rozhoduje kópiou znalosti resolvera (S4) — to je príčina nálezu pri hlavičke | áno |
| D3 | Starý skrinkový `hinge` sa v riadku skrinky ukazuje ako **„podľa staršieho výberu skrinky — X"** (prvá voľba), nie ako „uložený výber" | prvá voľba sľubuje, čo platí po jej výbere — a výber prázdnej voľby maže len triedny kľúč (S15); „uložený výber" + „podľa projektu" by sľubovalo návrat na projekt, ktorý nenastane. Text bez žargónu (UI_DIZAJN §1 D-07) | áno (text) |
| D4 | Hlavička = **počet vlastných kľúčov, ktoré resolver naozaj použije** — opravuje aj (b) zmiešané triedy s platným výberom skrinky, (c) mŕtve kľúče, (d) zatienený výber skrinky („2 vlastné" → „1 vlastný") | jedno pravidlo, žiadne výnimky podľa typu; (b) a (c) sú tá istá nepravda ako nález. Alternatíva „počítať aj uložené zatienené" = druhé pravidlo len pre (d) | **áno** |
| D5 | **(zmenené §15 A4)** `blocked` (projekt bez snapshotu + nekompatibilná knižnica): účinný zdroj z overridov, ktoré použije nákup (`{}`), uložený výber ostáva viditeľný ako „(uložený výber)"; pravidlo v jednom pomocníkovi s riadkom nákupu. Poškodený snapshot (`:invalid`) ako dnes — nákup tam overridy číta | pôvodné „ako dnes" by po H18 ukázalo „1 vlastný" pri výbere, ktorý nákup vypol (S18) | áno |
| D6 | R2.6 (text riadku nákupu pri dvierkach) **v H18**, obe vetvy nesúladu (§15 A6) | ten istý pohľad, zladí panel s Nákupom a Kontrolou (lekcia „panel a súpis sa nesmú rozísť"); CSV ani Kontrola sa nemenia | áno |
| D9 | **(nové §15 A2)** stavová veta pri zrušení výberu **neutrálna** („výber zrušený"), pravdu o tom, čo platí, nesie riadok setu | pravdivá veta „platí starší výber skrinky — X" potrebuje config v tele handlera → zásah do zápisovej akcie → in-SU brána; neutrálna veta je pravdivá vždy | áno |
| D10 | **(nové §15 A3)** poškodený výber v plochých riadkoch sa ukáže ako zablokovaná vybraná voľba s textom servera (vzor „uložený výber" a „podľa parametra") | žiadny nový prvok; marker sa dnes tvári ako „podľa skrinky/projektu" alebo „podľa: parameter" | nie |
| D7 | F1 (zápis pri krídle) a Q1 (zmazanie starého výberu) **mimo H18** → H18b | menia zápis do modelu a nákup — Michalovo 3A „len zobrazenie" | áno |
| D8 | Jeden PR | < 300 riadkov kódu pluginu aj po audite (~+190/−90), jedna téma | nie |

## 13 · Otázky pre Michala (do odpovede platí predvolené)

- **Q1 · Starý výber závesov na skrinke — dať v riadku voľbu „podľa projektu", ktorá ho zmaže?** Po H18 uvidíš pri takej skrinke „podľa staršieho výberu skrinky —
  Záves KLASIK". Prebiješ ho výberom iného setu, ale **vrátiť skrinku „na projekt"** (aby sledovala predvoľby projektu) sa nedá — prázdna voľba ruší len nový výber.
  **A (predvolené):** H18 len ukáže pravdu, nič nemaže. **B:** v H18b pridať, aby výber „podľa projektu" zmazal aj starý výber (zmena zápisu do modelu → test v SketchUpe).
- **Q2 · Výber setu pri jednom krídle Tip-On/klasických dvierok dnes nefunguje** (F1): vyberieš set pri krídle, status napíše „set uložený", ale nič sa neuloží
  — a ak tam bol starší výber krídla, zmizne; nákup ide podľa skrinky/projektu. **A (predvolené):** opraviť samostatnou malou dávkou **H18b** hneď po H18, aby výber
  pri krídle naozaj platil (výrobná dávka, test v SketchUpe). **B:** výber pri krídle dvierok skryť — set sa vyberá na skrinke alebo v projekte.

## 14 · Nálezy mimo scope a D-body

- **D-149 (navrhnuté, vyrieši H18):** Inspector pri dvierkach Tip-On/klasických ukazuje „podľa projektu", hoci platí starší výber skrinky či krídla (`hinge`,
  `hinge@krídlo`) alebo stará predvoľba projektu `hinge` — S1–S8; vrátane hlavičky Sety pri zmiešaných triedach a mŕtvych kľúčoch (D4).
- **F1 → D-150 (navrhnuté, H18b podľa Q2):** výber setu pri krídle klasifikovaných dvierok sa neuloží (`override_class_key` skladá `class:hinge|…@krídlo`, parser ho
  odmieta, prestavba zahodí) a **zmaže** starší platný `hinge@krídlo` — **nákup sa tým môže zmeniť** napriek hláseniu úspechu (S13, §15 A7). **H18b prioritne.**
  Smer opravy (audítor potvrdil): pri dvierkach s vlastníkom zapisovať `hinge@<krídlo>` (kľúč, ktorý resolver číta) s dnešnou validáciou triedy
  (`classified_value_problem`); **povoliť `class:hinge|…@krídlo` v parseri nestačí** — závesová vetva resolvera ho nečíta (`:4414-4432`). Test in-SU, nová sada.
- **F2 (v H18 ako R2.6):** riadok nákupu dvierok „nesedí so zásuvkou" (S14) a „iného typu kovania" pri sete iného typu (S19).
- **F3 (informatívne):** pôvodný príklad nálezu (`hinge`=`zaves-klasik` pri Tip-On) nekupuje klasický záves — končí RED; tichý nákup cudzieho setu je pri nezaradenom
  vlastnom sete alebo sete správnej triedy (S6). Opravené v znení D-149.
- **F4 (zásobník):** legacy `typ@<čelo>` kľúče čiel, ktoré v skrinke už nie sú, sa pri normalizácii nečistia (`prune_missing_owners` čistí len triedne) — na nákup
  vplyv nemajú (nikto ich nečíta), po H18 ich už nepočíta ani hlavička.
- **F5:** `ui-lifecycle.md` (`### payloads.rb`) tvrdí, že sa emituje len kľúč, ktorý resolver číta, a `typ@owner` len pri neklasifikovanej položke — pri závesoch
  nepravda. *Opraví H18 (§11).*
- Čísla D sú ďalšie voľné k `466b8b4c` (posledné D-148); ak medzitým pribudlo iné, orchestrátor prečísluje.

---

## 15 · Audit návrhu — zapracovanie (audítor audit-povinných, 2.10.2026) — 0 BLOCKER · 5 FIX · 3 NOTE · MÁ PREDNOSŤ

Surový výstup `AUDIT_H18_raw.md` (implementátor ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Audítorovi zlyhala headless Ruby sonda
(`tests/helper.rb:27` — temp adresár); tvrdenia A1–A6 som preto overil vlastnou sondou v sandboxe: `sonda_h18_audit.rb` (+ `sonda_h18_audit_js.js`, reálne funkcie
`hardware.js`) a `sonda_h18_cena.rb` — výsledky S16–S21 v §0. **Všetky FIX potvrdené a zapracované do §0–§14** (značka „(§15 A?)").

| # | Nález | Overenie sondou | Dispozícia a zmena v package |
|---|---|---|---|
| **A1** FIX | Z1–Z4 nemajú nezávislú pravdu zdroja: `resolver.json` nesie set, nie víťaznú hodnotu, úroveň a kľúč (rovnaký set na dvoch úrovniach je nerozlíšiteľný, selektor sa zredukuje na set); T1 porovnáva helper s vlastným obalom; prvá voľba sa overuje len keď je vybraná | **Potvrdené.** „Značkovací" oracle nad **starým** `resolve_mapping_value` dá `[raw_value, level, key]` bez nového helpera — 492/492 zhoda s prototypom (S16) | **R0.2** `source_pred.json` (oracle, aj pre sondu skrinky bez triedneho kľúča a sondu vlastníka bez víťazného kľúča) · **R4** Z1 porovnáva `mapping_option_id(raw_value)` (selektor ako celok), **Z2 prvá voľba a tooltip v každom rozsahu aj pri vybranej inej voľbe**, Z3 sonda skrinky bez triedneho kľúča · **T1** voči oracle · **T3** „aktuálnosť ≠ správnosť" · **M2, M5, M13** prepojené na oracle, nové **M14, M15, M22** |
| **A2** FIX | Po návrate na starší výber skrinky status hlási „platí predvoľba projektu" (`actions_hardware.rb:1319`) | **Potvrdené** (S20): „Závesy: platí predvoľba projektu." aj pri platnom starom `hinge`; žiadny test vetu nepripína | **R2.8** neutrálna veta „výber zrušený" (skrinka aj dielec) v čistej funkcii `hw_set_status_msg`; telo handlera bez zmeny · **D9** · **T9** + zdrojový guard volania · **M16** · smoke bod 2 · §0.2 inventár. Pravdivá veta s menom setu zamietnutá (potrebovala by config v zápisovej akcii → in-SU) |
| **A3** FIX | Poškodený legacy `hinge@krídlo` (`{invalid:true}`) — plochý riadok ukáže „(podľa skrinky/projektu)", resolver `mapping_invalid` | **Potvrdené** (S17) pre staré dvierka aj zmiešanú skrinku; **navyše** poškodený skrinkový kľúč typu pri starších položkách ukáže v riadku skrinky „podľa: parameter" (marker sa tvári ako selektor) — platí pre každý typ | **R2.7** server: `label` poškodeného vlastníka, `override_label` a `owner_default_label` poškodeného kľúča typu · **R3.2** `hwOwnerOptionList` kreslí poškodený záznam ako zablokovanú vybranú voľbu · **R0.1** matica + **Z1b, Z6** · **T0** povolený rozdiel vymenovaný · **T2** · **M17, M18** · **D10** · smoke 5b (klasifikované krídlo; plochý riadok len headless) · §4 upravené |
| **A4** FIX | `blocked` (projekt bez snapshotu + nekompatibilná knižnica): nákup overridy vypne, `hardware_set_options` ich číta — nový `own_count`/„starší výber skrinky" by tvrdil účinný výber, ktorý nákup nepoužil | **Potvrdené** (S18): dnes hlavička náhodou „podľa projektu", pôvodný návrh by dal „1 vlastný" | **R2.1** uložené vs. **účinné** overridy, pravidlo `blocked` v **jednom pomocníkovi** zdieľanom s `decorate_hardware_purchase` (zrkadlo `production_core.rb:561`) · **R2.2/R2.3/R2.4** z účinných, uložený výber „(uložený výber)" · **R0.1** stav `blocked` v matici, oracle s `{}` · **Z5** · **T2** · **M19, M20** · **D5 prepísané** · `:invalid` vedome ako dnes (nákup tam overridy číta) |
| **A5** FIX | Goldeny nepokrývajú deklarovanú cenovú identitu: `ceny_m2`/`np4` bez `hardware_expansion`, KOV-H golden so závesom bez klasifikácie, H9 závesové pravidlo vypína | **Potvrdené čítaním**; reťaz expand → CSV → `Budget.compute` → `CpExport` beží headless nad klasifikovanými závesmi (S21) | **R0.5** nový predzmenový `cena_zavesy.json` (skrinky A–E: skrinkový aj krídlový override, zmiešaná, RED, nezaradený set mimo katalógu) · **R0.4** existujúce goldeny = poistka, nie dôkaz · **T0** bajtovo · **M23** · **DoD** veta zúžená na rozsah dôkazov (VEPO cez nezmenený výsledok resolvera) · §5 trieda |
| **A6** NOTE | R2.6 opravuje len vetvu nesúladu klasifikácie; set **iného typu** pri dvierkach: `expand` RED `hinge_set_mismatch`, `explain` `set_type_mismatch` | **Potvrdené** (S19) | **Doplnené (nie len evidované):** R2.6 = dva spoločné pomocníci pre `expand`/`explain` (obe vetvy); úplná parita sa netvrdí · **T5** prípad setu iného typu · **M21** · §0.2 |
| **A7** NOTE | F1 nie je len neúspešné uloženie — zmaže platný starší výber krídla (nákup sa zmení); smer H18b `hinge@<krídlo>` správny, povolenie `class:hinge\|…@krídlo` v parseri nestačí; D3 a D4 (b–d) obhájiteľné; T4 musí výslovne zmeniť `test_h6b_suhrny.js:242` | súhlas | **§14 F1** prepísané (zmena nákupu, H18b prioritne, smer opravy) · **§9** riziko · **T4** vedomá zmena očakávania `:242` s komentárom D4 (c) · Q2 bez zmeny (predvolené A) |
| **A8** NOTE | Verdikt: extrakcia reťaze rozumná; audit áno, konzervatívna výrobná trieda áno, jeden PR a `-Record` primerané; po rozšírení znovu posúdiť in-SU | — | **§5 znovu posúdené:** výrobná/cenová **áno**, audit áno (hotový), predrecenzia povinná, **in-SU stále nie je brána** — A2 mení len čistú textovú funkciu, A3/A4/A6 len čítacie cesty; podmienka: telo `handle_set_hardware_set` bez zmeny (overí predrecenzia, inak in-SU brána). Jeden PR (~+190/−90 kódu pluginu) |

**Otázky pre Michala bez zmeny:** Q1 (zmazanie starého výberu skrinky) predvolené **A** — H18 nič nemaže; Q2 (výber pri krídle) predvolené **A** — oprava H18b prioritne.

**Koncept: BEZ ZMENY** (jedna reťaz resolvera so zdrojom, pravda zo servera, JS len kreslí, nič sa nezapisuje). Mení sa rozsah zobrazenia (A2 stavová veta, A3
poškodený výber v plochých riadkoch, A4 `blocked`, A6 druhá vetva `explain`) a sila dôkazov (A1 nezávislý oracle, A5 cenový golden). Nový audit netreba, pokiaľ
implementácia nezmení koncept; zmena konceptu (napr. zásah do tela handlera alebo zápisu) = delta audit.
**Odhad:** ~1,5 dňa (pôvodne ~1 deň) — kód pluginu ~+190/−90, testy ~850 riadkov (matica s `blocked` a poškodenými kľúčmi, oracle, cenový golden, 3 nové sady, prepis T4).

**Potvrdenie orchestrátora (2.10.2026):** audit H18 uzavretý (0 BLOCKER, 5 FIX zapracované v §15 s overením sondou, koncept bez zmeny — delta audit sa nespúšťa,
overí predrecenzia a GH review). §12: D1 áno (presun reťaze resolvera doslovne do `resolve_mapping_source`, hodnota bez zmeny — 492/492 + golden) · D4 áno
(hlavička ráta len účinné výbery; zmena očakávania `test_h6b_suhrny.js:242` vedome v T4) · D5 v znení §15 A4 · D9, D10 áno · ostatné bez výhrad. **Jeden PR**, z čerstvého
mainu po H11a/H15/H16 (poradie bloku), výrobná/cenová trieda → predrecenzia povinná; ak by implementácia menila telo `handle_set_hardware_set` alebo iný zápis do
modelu → in-SU brána. **Q1/Q2** (vrátenie skrinky „na projekt"; F1/H18b) — otázky Michalovi, kým neodpovie platí A/A (H18 nič nemaže; F1 = samostatná dávka H18b).

## 16 · Implementácia a dôkazy (Codex, 3.10.2026)

**Krok 0:** čerstvý main po H16 `2640f47b33814c5f49562205fc80657f8997bf14` (v0.17.25). H15 presunul iba seed dáta a kotvy;
precedencia, payload a zápis bez konceptuálneho driftu. Patch H18 = **0.17.26**, vetva `fix/h18-zavesy-v-inspectore`.
**R0 prvý commit `76ba403526bc83af774db13e2c31d30f53e041a0`**, plugin v ňom nezmenený; všetkých päť predzmenových JSON zostáva bez diffu.
Matica **1 242 prípadov / 1 686 položiek**, nezávislý značkovací oracle starého resolvera; `zhoda_pred.json` **1 979 rozdielov → PO 0**.
Expanzia + CSV nákupu, rozpočet (kovanie/súčty) a ponuka klasifikovaných závesov bajtovo rovnaké (`cena_zavesy.json`);
výsledok resolvera celej matice rovnaký (`resolver.json`) okrem vymenovaných textových opráv `explain` R2.6.
`T0` výslovne povoľuje aj A4 `none_label` pri blocked výsuve/výklope; zdravé texty ostatných typov sú bajtovo pripnuté.

**Izolácia:** štyri nahradené singleton metódy (`hardware_read_state`, `HardwareSets.load`, `library_read_only?`, `HardwareCatalog.items`)
obnovené v `ensure`, aj po výnimke; Time/ENV nezmenené. Decorator používa pôvodný seed katalógu, preto nezávisí od predchádzajúcej sady.
Zdrojové guardy starých KOV-D1b/R-07 teraz overujú callsite aj samotný spoločný blocked helper; poškodený výber KOV-D1a pripína nový label.
**Zápis:** celé telo `handle_set_hardware_set` bez zmeny voči mainu; SHA256 `1c595ace9e2ee2d2ec03e7a166823a39cd458adb78723d9a91a018673c910f82`.
H18b-1 **čaká na Michalovu odpoveď Q2** podľa posledného potvrdenia 3.10.; D-150 otvorené, D-151/D-152 v zásobníku, D-153 len podmienený návrh.

**T4 1:1** (riadky pôvodného mainu v `test_h6b_suhrny.js`; každý assert zachovaný, JS kreslí explicitný serverový `own_count`):

| Pôvodný riadok | Prípad | own_count / výsledok po H18 |
|---|---|---|
| 196 | prázdna ponuka | prázdny text |
| 197 | chýbajúca ponuka | prázdny text |
| 198 | bez vlastného výberu | 0 / podľa projektu |
| 199 | skrinkový výber | 1 / 1 vlastný |
| 200 | selektor | 1 / 1 vlastný |
| 201 | výber pri čele | 1 / 1 vlastný |
| 203 | selektor + poškodený vlastník | 2 / 2 vlastné |
| 205 | dve kategórie | 3 + 1 / 4 vlastné |
| 207 | päť vlastných | 5 / 5 vlastných |
| 210 | compat skrinka + vlastník | 2 / 2 vlastné |
| 212 | compat bez výberu | 0 / podľa projektu |
| 219 | klasifikovaný + legacy vlastník | 2 / 2 vlastné |
| 220 | iba legacy vlastník | 1 / 1 vlastný |
| 223 | poškodený klasifikovaný vlastník | 1 / 1 vlastný |
| 229 | dve triedy, bez legacy | 0 / podľa projektu |
| 231 | bez zoznamu položiek | 0 / podľa projektu |
| 233 | zmiešaná s legacy položkou | 1 / 1 vlastný |
| 236 | anonymná legacy položka | 1 / 1 vlastný |
| 239 | legacy položka iného typu | 0 / podľa projektu |
| 242 | typ bez položky | **D4(c): 1 vlastný → podľa projektu**, komentár zachovaný |
| 243 | dormantný kľúč typu | 0 / podľa projektu |

Logika zdroja presunutá do Ruby T1/T2: S1/S2/Smix/Smixleg/Snone, víťazné kľúče a dva explicitné prípady anonymného a iného typu.
Oba pôvodné refresh asserty zostávajú: payload `own_count` 0 → 1. Sada stále **202 OK**.

**T8:** `python tests/fixtures/h18_golden/mutations.py` — **M1–M23 všetky zhodené**; pred každým behom diskové zálohy,
po každom presná byte obnova (Windows krátke odmietnutie otvorenia rieši retry, trvalá chyba zastaví beh a nechá zálohu).
M1/M6/M11 → Ruby T0; M2/M8/M9/M13/M22 → T1 oracle; M3/M4/M19 → T2; M12/M21 → T5;
M16 → T9; M20 → spoločný helper/callsite guard; **M23 → cenový T0**.
M5/M7/M14/M18 → T3 nad **čerstvým mutovaným Ruby payloadom v `_dev/`** proti starému oracle (prvá voľba, tooltip, celé ID selektora);
M10/M15/M17 → JS T3. M6 zhodí payload už nepovoleným zdrojom `owner` (KeyError slovníka), zachytené v Ruby T0.
Predzmenové JSON ani `payload_po.json` sa počas mutácií nemenia.

**Kontroly:** 5331 headless / 0 FAIL, 162 JS sád / 0 FAIL. **Fotky:** natívna nahrávka ešte čaká na voľný SU slot.
Predrecenzia a GH review sú následné brány; smoke §10 po mergi a inštalácii overí Michal.
