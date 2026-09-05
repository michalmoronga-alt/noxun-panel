# KOVANIE — KOV-C package v2: simplification review + Astra predaudit (2026-09-05, checkpoint #19)

> Stav: KONCEPT / audit checkpoint — nie implementačný spec. Záznam simplification review (Michal + Claude) a jediného auditného kola (Codex CLI 0.153.3 npm, `codex exec -m gpt-6-astra`)
> nad package KOV-C v2 v `SYSTEM/PLAN.md`. Výsledok: **2 BLOCKER · 8 FIX · 1 NOTE — všetky zapracované malými pravidlami, žiadny návrat k mechanizmu v13**. Autorita zadania = PLAN.md.

Nadväzuje na checkpoint #18 (package v13, 4 CLI + 9 GH kôl, nekonvergovalo). Tento checkpoint zaznamenáva **rozhodnutie prepísať package**, zásady v2 a jediné auditné kolo (Astra) s reconcile.

## 1. Simplification review (Michal + Claude, 5.9.2026 popoludní)

Otázka Michala: nedostali sme sa po mnohých auditných kolách do zbytočne univerzálneho riešenia? Reálny use-case = ~5 zásuvkových systémov za 10 rokov (Atira, Antaro, Quadro, TANDEM, StrongBox/Max), atyp = ručne.

**Porovnanie A (v13) vs B (explicitné nemenné recepty) — závery, ktoré Michal potvrdil („so všetkým súhlasím"):**

| Mechanizmus v13 | Pri v2 |
|---|---|
| KD → EB → `runner_variant` → `orderable` → `runner_not_orderable`, os `runner_variant` na setoch | zmizne; EB pevné per recept (Atira 10.5 — Michal: fyzicky OK pri KD 16/18/19, mení sa len svetlá šírka) |
| `candidates[]` s dielcami per NL, predfilter zámkov, `explain` preskočených | zmizne; jedna výška, jedna NL z radu, ktorý Noxun reálne kupuje (`nl_series_by_height`) |
| exact tabuľka `{height_variant, load, set_id}`, `parse_mapping` rozšírenie, lazy `std` 4 | zmizne; existujúci pásmový selektor na `height_variant` (D-81) + `code_by_nl` |
| `load` ako os výberu | zmizne; 50 kg / farba = alternatívny selektor v override skrinky |
| projektový snapshot receptov (5 stavov), `recipe_digest`, `drawer_recipes_mismatch/invalid`, `merge_recipes_seed!` | zmizne; `recipe_ref` per čelo, 3 stavy, CI SHA register nemennosti |
| šablóna nesie snapshot receptov, atomické zjednotenie systémov | zmizne; ref = reťazec vo whiteliste |
| automatická migrácia `slide` → triedne mapovanie | zmizne; RED + existujúca akcia „Doplniť nové predvolené" |
| `drawer_stale` preflight | zmizne; stavba sety nečíta |
| sync tyč: capability, `generic_type sync_shaft`, dĺžka | zmizne; ORANGE + ad-hoc set (Michal: mimo V1) |

**Jediný výrobný scenár, ktorý B musí riešiť inak než A:** dielce zásuvky bez kúpiteľného kitu vo VEPO (BL = NL + 10, boky Quadro = NL). Riešenie: `drawer_kit_missing` z nákupu blokuje AJ VEPO. Register blockerov 15 → 10.

**Rozhodnutie:** PR #300 zavretý s komentárom, nová vetva `docs/kov-c-v2`, PR #301 (draft → ready po reconcile). KOV-D revidovaná (triedny kľúč, per-height sety, seed a `drawer_kit_missing` sú už v C).

## 2. Astra predaudit (Codex CLI 0.153.3 npm, `codex exec -m gpt-6-astra -s read-only`, effort high)

Prompt: adversarial review package v2 s explicitnou úlohou pri každom náleze povedať, či stačí malé pravidlo/dátový riadok, alebo je nutný niektorý odstránený mechanizmus v13 (s konkrétnym výrobným scenárom). Companion runtime (Codex 0.144) model odmietol — Astra beží cez npm binárku.

**Výsledok: 2 BLOCKER + 8 FIX + 1 NOTE. Pri ŽIADNOM náleze Astra netvrdí, že je potrebný mechanizmus v13** — každý je označený „malé pravidlo, bez v13/snapshotu/digestu".

### Nálezy (doslovný výstup Astry)

1. **BLOCKER — Priamy override môže objednať H70 pre dielce H176.** Package zachováva prednosť overridov, ale kompatibilitu kontroluje len cez opening/construction. H70/470 aj H176/470 majú tieto hodnoty rovnaké. Override `slide@front:F1/panel` na H70 preto prejde aj po zvýšení zásuvky na H176; existujúci resolver ho vyberie pred selektorom (`hardware_sets.rb` `resolve_mapping_value`). Malé explicitné pravidlo, bez v13: povoľovať iba schválené ekvivalentné sety konkrétneho systému a výšky, kontrolované aj pri expanzii.
2. **BLOCKER — Kontrakt `recipe_ref` súčasne prikazuje zahodenie aj zachovanie tou istou normalizáciou.** Package prikazuje, aby `norm_drawer` ref zahodil, ale požaduje round-trip cez `normalize_config`, ktorú používajú aj uloženie šablóny (`payloads.rb` `template_config_from`) a normalizácia pred prestavbou kópie (`cabinet_builder.rb` dedup). Stratené `_v1` sa po vydaní `_v2` zmení na „chýbajúci → latest", teda na tichú zmenu geometrie. Malé pravidlo, bez snapshotu/digestu: oddeliť filtrovanie klientského payloadu od bezstratového čítania uloženého configu/šablóny; zápis v rovnakej operácii ako geometria.
3. **FIX-IN-C1 — Quadro nemá podmienku minimálnej výšky vyrábaných dielcov.** Pri svetlej výške 60 mm dá `box_height = 20`, predok/chrbát pri dne 16 mm vyjdú −8 mm. Existujúci filter odstraňuje degenerované dielce jednotlivo (`construction.rb`), čo poruší atomicitu. Malé pravidlo: pred emisiou overiť všetky rozmery všetkých dielcov proti `BuildPlan::MIN_DIM`; jediný neplatný → `drawer_no_fit`.
4. **FIX-IN-C2 — Zmena verzie receptu môže odpojiť existujúci zámok NL.** Identita override obsahuje `rule_id`; upgrade ref v1 → v2 bez preadresovania zámku `recipe:atira_sisy_v1` → automat vyberie inú NL napriek zachovanému záznamu. Malé pravidlo: atomické preadresovanie zámkov pri upgrade; nekompatibilný zámok = konflikt.
5. **FIX-IN-C2 — Šablóna prenesie recept, ale stratí jeho zámok.** `template_config_from` neukladá `hardware_overrides`; zásuvka zamknutá na NL 420 sa po vložení šablóny postaví na 470. Malé whitelist pravidlo: preniesť receptové zámky spolu s čelami.
6. **FIX-IN-C2 — Chýba uložený nosič konfliktov stavby.** `hardware_issues` dnes vzniká až v `Bom.collect`; `merge_final` ukladá warnings a hardware, nie konflikty resolvera. Po fail-closed stavbe nezostane výsuv, z ktorého by expanzia dôvod obnovila. Malý dátový kontrakt: uložené konflikty per čelo, cesta plán → config → Bom → Kontrola/brána; test save/reopen aj Undo.
7. **FIX-IN-C2 — „Doplniť nové predvolené" po bežnej aktualizácii nemusí pridať triedne mapovania.** Globálny `merge_seed` dopĺňa sety; mapovania mení iba cez `MAPPING_MIGRATIONS`; projektový merge kopíruje iba mapovania prítomné v globále. Malé migračné pravidlo: doplniť triedne kľúče do globálu cez migrácie; test upgrade zo starého globálu aj snapshotu.
8. **FIX-IN-C2 — Aktivácia triednych mapovaní obchádza ochranu kolidujúcich kópií.** `override_keys_in_use` (`production_core.rb`, R-34) pozná iba `slide` a `slide@owner`. Malé pravidlo: rozšíriť o triedne kľúče, ktoré začne čítať resolver.
9. **FIX-IN-C2 — Nie je jednoznačne určené, ktoré staré čelá sa aktivujú a ktoré dostanú RED.** Čelo s `construction: metal` bez opening/system môže resolver obísť a pokračovať legacy cestou. Malá rozhodovacia tabuľka: legacy / čiastočne klasifikované / úplne klasifikované bez `system` / `other`.
10. **FIX-IN-C1 — CI nemennosť chráni iba `_v1`.** Úprava už používanej `_v2` prejde CI. Malé testovacie pravidlo: register všetkých vydaných verzií + referenčné výsledky výpočtu (SHA JSON nezachytí zmenu interpretácie v Ruby).
11. **NOTE — `locked: true` pre každú receptovú položku = falošné „ručne prepísané".** Jednoduchšie: zákaz zmeny množstva zo `source: recipe`; `locked` len z reálneho zámku.

## 3. Reconcile (Claude, overené proti kódu: `MAPPING_MIGRATIONS` existuje, `override_keys_in_use` pozná len `gt` a `gt@opk`, `hardware_issues` vzniká v `Bom.collect`, `MIN_DIM = 0.01`)

| # | Rozhodnutie | Kam v package |
|---|---|---|
| 1 | PRIJATÉ. Hodnota mapovania pre receptové položky so `height_variant` musí byť na každej úrovni selektor podľa výšky; pevný `set_id` pre Atiru = RED; farba/50 kg = alternatívny selektor; Quadro smie pevný set. Žiadna nová os na setoch. | KOV-C C2 (d); KOV-D (c) |
| 2 | PRIJATÉ. Dve cesty: klientsky payload sa filtruje v handleri akcie, `normalize_config` ref bezstratovo zachováva; test straty ref = FAIL. | KOV-C C1 `recipe_ref` |
| 3 | PRIJATÉ. `min_box_height` v recepte Quadro + kontrola všetkých rozmerov proti `MIN_DIM` pred emisiou, jediný neplatný = `drawer_no_fit`. | KOV-C C1 |
| 4 | PRIJATÉ. Upgrade receptu = prepis ref + atomické preadresovanie zámkov + prestavba v jednej operácii. | KOV-D (e) |
| 5 | VEDOMÉ, NIE C. Šablóna zámky neprenáša dnes ani po C — vložená zásuvka sa rieši automatom konzistentne (dielce aj kit z tej istej NL, žiadna rezná chyba); prenos zámkov = KOV-I R12. Test v C to potvrdí explicitne. | KOV-C Riziká |
| 6 | PRIJATÉ. `drawer_conflicts` v configu z `merge_final`, `Bom.collect` zlúči do `hardware_issues`; test save/reopen/Undo. | KOV-C C2 (e) |
| 7 | PRIJATÉ. Triedne kľúče do `MAPPING_MIGRATIONS`; test upgrade zo starého globálu aj snapshotu. | KOV-C C2 (d) |
| 8 | PRIJATÉ. `override_keys_in_use` + triedne kľúče. | KOV-C C2 (d) |
| 9 | PRIJATÉ. Rozhodovacia tabuľka 3 stavov; chýbajúci `system` server doplní a zapíše (migrácia čiel klasifikovaných pred v2). | KOV-C C1 |
| 10 | PRIJATÉ. `RELEASED.json` register SHA všetkých verzií + golden testy `resolve` per verzia. | KOV-C C1 |
| 11 | PRIJATÉ. `locked` len pri platnom zámku. | KOV-C C2 (c) |

**Záver:** návrh v2 drží — všetky nálezy sú dátové riadky, kontrakty poľa alebo testy; ani jeden nevracia snapshot/digest, kandidátov, KD→EB mapu, osi na setoch, exact tabuľku ani preflight. Ďalšie kolo sa nevyžaduje (Michal 5.9.: „po doladení implementácia; ak niečo bude nejasné, stačí napísať").

## 4. Otvorené dátové otázky na Michala (nie blokujú C1)

- Kódy Démos pre bunky bez kitu: Atira biela H70/350, H144/470 (dnes „š" = na objednávku) — doplniť kód alebo NL z radu vyradiť pred mergom seedu.
- ~~Kódy Atira Tip-On kitov pre NL ≠ 620~~ — **DODANÉ 5.9. popoludní** (13 kódov PTOs, draft #13 nová tabuľka): `atira_p2o_v1` má rady H70/H144 [350–620], H176 [350, 420, 470, 620];
  kity sú vendor variant PTOs → min. svetlá výška Tip-On receptu = 108/192/224 (prísnejšia). Neskôr 5.9. dodané aj SiSy H70/520 (357697), H144/350 (357734), H144/420 (357735) a Tip-On H176/520 (357812, len 50 kg) — **všetky bunky radov v1 majú kód**.

## 5. GH Codex kolo 1 nad PR #301 (Sol cloud, commit `b29bdd5`, 5.9. 13:04 UTC) — 3 P1 + 1 P2, reconcile

| # | Nález | Rozhodnutie | Kam |
|---|---|---|---|
| P1 | Set vybraný triednym kľúčom sa neoveruje proti systému receptu — Antaro/StrongBox budú zdieľať `class:slide|classic|metal` s Atirou. | PRIJATÉ (menší z dvoch návrhov): kompatibilita setu zahŕňa `manufacturer` + `series` ↔ `system` receptu, overené pri expanzii; rozšírenie kľúča o systém až v dávke, ktorá pridá druhý kovový systém. | KOV-C C2 (d) |
| P1 | Prepnutie SiSy → P2O → SiSy by cez `latest_for` ticho povýšilo v1 na v2. | PRIJATÉ: pri zmene klasifikácie súrodenecký recept ROVNAKEJ verzie (`Recipes.sibling`), `latest_for` len ak neexistuje; zmena verzie = výhradne KOV-D. | KOV-C C1 `recipe_ref` |
| P1 | `MAPPING_MIGRATIONS` vie len nahradiť existujúci kľúč, chýbajúci `class:` kľúč nevytvorí → „Doplniť nové predvolené" by nič neopravilo. | PRIJATÉ: nový malý kontrakt `MAPPING_ADDITIONS` (add-if-absent) v `merge_seed`, prenos do snapshotu cez `merge_project_sets_seed!`; test starý globál + starý snapshot. | KOV-C C2 (d) |
| P2 | Draft #13 §0 stále nesie tvar v13 (`runner_variants`, KD→EB, `orderable`, SiSy+P2O v jednom). | PRIJATÉ: §0 označená HISTORICKÁ s odkazom na kanonickú schému v PLAN; hodnoty §1–§2 platia. | draft #13 |

Žiadny nález nevracia mechanizmus v13. P1 v kole 1 → opravy + nové plné GH kolo (`@codex review`) podľa pravidla delta-verifikácie.

## 6. GH Codex kolo 2 nad PR #301 (commit `5f6aff2`, 5.9. 13:27 UTC) — 3 P1 + 2 P2, reconcile

| # | Nález | Rozhodnutie | Kam |
|---|---|---|---|
| P1 | Súrodenec rovnakej verzie nestačí: systém, ktorý má len v2, uloží v2 a návrat k Atire nájde v2 súrodenca → tichý upgrade. | PRIJATÉ: `drawer.recipe_refs` = mapa systém|otváranie → recipe_id (namiesto jediného ref); návrat k skôr použitej kombinácii vráti pôvodný záznam; súrodenec/latest len pre NOVÚ kombináciu. | KOV-C C1 |
| P1 | Owner-level selektor nemá reprezentovateľný kľúč (`class:…@owner` parser odmieta, `slide@owner` je zakázaný fallback). | PRIJATÉ: v C precedencia LEN cabinet override (triedny kľúč v `hardware_sets` configu) → projekt; owner-level `slide@…` sa pre receptové položky ignoruje; owner-scoped tvar = audit KOV-D. | KOV-C C2 (d); KOV-D (c) |
| P1 | Oba merge ponechávajú existujúcu definíciu `vysuv-atira-biela-h70` bez klasifikácie → kompatibilita by padla. | PRIJATÉ: seed používa NOVÉ klasifikované set ID (`atira-biela-h70-sisy`, `-p2o` …), legacy set ostáva nedotknutý pre legacy mapovanie. | KOV-C C2 (d) |
| P2 | Register SHA chráni len registrované súbory, neregistrovaný `_v2` by `latest_for` načítal. | PRIJATÉ: inventár `data/recipes/*.json` = množina registrovaných ID (test) + loader načíta výhradne registrované. | KOV-C C1 |
| P2 | Package odkazuje na FINAL §3/§8, ktoré predpisujú snapshot, KD→EB a VEPO výnimku. | PRIJATÉ: poznámky PREKONANÉ/UPRESNENIE priamo v FINAL §3 a §8; PLAN odkazuje len na §4/§6. | FINAL, PLAN |

Žiadny nález nevracia mechanizmus v13 (mapa refs je stále reťazce bez snapshotu/digestu). P1 → kolo 3 (`@codex review`); ak kolo 3 prinesie P1, platí pravidlo 3 kôl (rezať).

## 7. GH Codex kolo 3 nad PR #301 (commit `0490def`, 5.9. 13:46 UTC) — 4 P1, reconcile + ROZHODNUTIE MICHALA

| # | Nález | Rozhodnutie | Kam |
|---|---|---|---|
| P1 | Recept nemá vstup hrúbok drawer materiálu; `build_into` volá `build_plan` PRED `effective_materials` (overené v kóde). | PRIJATÉ: hrúbky kanála `:drawer` + `part_overrides` sa vyriešia pred plánom a idú receptu ako `part_thicknesses`. | KOV-C C1 resolve, C2 (a) |
| P1 | Panel nahrádza `params['fronts']` vcelku → mapa `recipe_refs` sa dá prepísať/vymazať. | PRIJATÉ: handler ju z payloadu zahodí a uloženú mapu pripojí späť podľa ID čela; test stale/forged payload. | KOV-C C1 |
| P1 | Čiastočná klasifikácia (opening bez construction) by šla legacy cestou. | PRIJATÉ: legacy len pre čelo bez akéhokoľvek drawer poľa; akékoľvek čiastočné = RED. | KOV-C C1 tabuľka |
| P1 | Pásmo selektora H176 → H70 set: sety nemajú výškovú metadátu, expanzia nemá čo overiť. | PRIJATÉ (Michal 5.9.: „výškové pole áno"): klasifikačné pole `height_variant` na drawer setoch = overenie pri expanzii, NIE os výberu; lazy std 4 obsahom. | KOV-C C2 (d) |

**Rozhodnutie Michala 5.9. (po kole 3):** zapracovať kolo 3, package ZMRAZIŤ, PR mergnuť BEZ ďalšieho GH kola (pravidlo 3 kôl: review dokumentu produkuje nové hypotetické okraje
každé kolo bez ohľadu na kvalitu návrhu — pri v13 aj v2). Ďalšia brána = implementácia C1 s testami a in-SU behom. Dátové commity po kole 2 (Atira kódy, rename `recipe_refs`) = docs, delta overená orchestrátorom.
