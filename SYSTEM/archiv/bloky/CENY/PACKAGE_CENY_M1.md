# PACKAGE CENY-M1 · Odkaz na produkt a ručné overenie ceny dosky/ABS — dáta katalógu + Štúdio → Materiály

> **Autorita:** rozhodnutia Michala C1–C11 (`SYSTEM/zdroje/bloky/CENY/ROZHODNUTIA_MICHALA_2026-09-29.md` — **C7 jeden odkaz**, **C8 doska za platňu, ABS za bm**,
> **C11 mockup schválený, O1–O9 podľa návrhu**), schválený mockup `MOCKUP_CENY_2026-09-30.html` — obrazovky **A, A2, B, B2, C** a karty **O1–O9** (odporúčanie =
> schválené znenie), fakty `FAKTY_Z_KODU_2026-09-29.md` (6 pascí). Vzor: CENY-KOV-A/B (`SYSTEM/archiv/ROADMAP_hotove_etapy.md` §CENY-KOV, `core/hardware_catalog.rb`,
> `ui/hardware_catalog_dialog.rb`, `ui/js/hw_catalog.js`). **Kde sa package a vzor kovania rozchádzajú, platí package** (O8 ručný odkaz sa pri Demos väzbe NEmaže,
> O9 overenie aj bez odkazu, O3/O7 doska za platňu s presnou €/m²).
> **Trieda:** **audit-povinná** (SCHEMA katalógu materiálov 10 → 11 [→ 12], nový dátový kontrakt) · **cenová dávka** (mení ceny v katalógu, a tým Rozpočet všetkých
> zákaziek) · **slepá predrecenzia povinná** (audit-povinná + cenová + > 300 riadkov + nové ovládacie prvky UI) · **in-SU nie je brána** (§8) · `codex-po-pr` bez výnimky.
> **Verzia:** patch (v0.16.0 → **v0.16.1**; pri reze M1a v0.16.1 → M1b v0.16.2) + všetky `?v=` + prepis STAV. Minor až uzáver bloku CENY po M2.
> **Stav kódu:** sonda nad `docs/ceny-start` `aba002cf` (= `main` `41b1bbcd` + dokumenty bloku, kód identický).
> **Rozhodnutia orchestrátora (30.9.2026):** **D2 rez prijatý** — blok CENY má dávky **M1a → M1b → M2** (každá z čerstvého `main`); **D1 http aj https** potvrdené
> (schválený mockup C1 aj vzor kovania); **D5** potvrdené; **F1 zaradené do M1b** ako **R13b / D-148**; otvorenie obchodu **neblokuje** potvrdenie pri neúspechu
> (mockup B1 po Codex review #425). Ostatné D3–D14 platia podľa §12. Po review #425 platí aj **C8**: keď cenu vo formulári neprepíšeš, potvrdenie ju nezmení
> ani o cent (R11 krok 5–7) a **C12** (materiál bez formátu v Rozpočte podľa skutočných m²) patrí do **M2**.
> **Audit návrhu (Codex gpt-6-astra, 30.9.2026, surový výstup `AUDIT_CENY_M1_2026-09-30.md`): 1 BLOCKER [B] + 2 FIX-IN-M1a + 1 FIX-IN-M1b — všetky
> zapracované:** BLOCKER → **R11a** (nezmenená cena = presná zhoda so **zobrazenou** hodnotou zo servera, nie interval ±0,005; R12 a D4 prepísané) ·
> FIX-M1a-2 → **R6b** (formulár variantu drží vlastnú revíziu z otvorenia) · FIX-M1a-3 → **R6c** (kontrola + merge + zápis pod jedným zámkom) ·
> FIX-M1b-4 → **R20b** (presná interná hodnota; samotné prepnutie jednotky cenu nemení).
> **Delta audit (Codex gpt-5.6-sol, 30.9.2026, `AUDIT2_CENY_M1_2026-09-30.md`):** R6b, R6c, R20b RESOLVED; BLOCKER čiastočne → doplnené v R11a:
> (1) celočíselné porovnanie v centoch **len pre `plate` a `m2`**, `bm` porovnáva normalizovaný vstup **presne** s uloženou hodnotou; (2) FIX-M1b:
> `price_display.plate = nil` pri riadku **bez platného katalógového `sheet_size`** (Rozpočet tam používa odhad 2800 × 2070 — tvrdenie o zhode s Rozpočtom
>  platí len pre riadky s formátom; bezformátový materiál ide v M2 podľa m², C12).

---

## 0 · Sonda pred auditom (skill `codex-audit`, krok 0) — 30.9.2026

Skripty a surové výstupy: scratchpad `CENY/sonda_m1.rb` (+`_out.txt`), `sonda_m1b.rb`, `sonda_m1c.rb`, `sonda_m1.js`. Ruby cez `tests/helper.rb` (APPDATA = sandbox,
živý katalóg sa nedotkol), JS nad reálnym `proj_materials.js` s DOM stubom vzoru `tests/js/test_st2a_mat.js`. Nič sa nezapisovalo do modelu ani do repa.

| # | Tvrdenie package o dnešnom kóde | Skript · test | Čo vrátil | Verdikt |
|---|---|---|---|---|
| S1 | Schéma materiálov nikdy neklesá — zápis bez nových polí nad markerom 10 ostane 10 (`target_schema_fresh`) | sonda_m1.rb T1b | `[true, 10]` | PRAVDA |
| S2 | `required_schema_for`: riadok `need = SCHEMA_APPEARANCE if r.key?('appearance')` je **bezpodmienečné priradenie** — pri markeri > 10 by neskorší záznam s `appearance` marker znížil | T2a/T2b (simulácia `SCHEMA_APPEARANCE=3`, zoznam `[uni, appearance]`) | zdrojový riadok bez `need <`; výsledok **3** namiesto 7 | PRAVDA — **pasca**, rieši R2 |
| S3 | `normalize_sheet`/`normalize_edge` dnes `product_url` aj `price_check_method` zahodia (starší plugin by ich ticho stratil → bump schémy povinný) | T3b/T3c | `[false, false]` / `[false, false]` | PRAVDA |
| S4 | `duplak_record_from` by nové polia **zdedil** (reject zoznam ich nepozná), Demos polia nie | T4 | product_url `true`, price_check_method `true`, demos_url `false`, price_checked_at `false` | PRAVDA — **pasca**, R5 |
| S5 | `uni_edit_error` `product_url` nepozná (demos_url áno) | T5/T5b | `nil` / hláška UNI | PRAVDA — **pasca**, R5 |
| S6 | `validate_price` pripúšťa 0 **aj prázdnu**; záporné/nečíslo odmietne; `normalize_price('179,90')` = 179.9 | T6/T6b | `[[true,nil],[true,nil],[false,…],[false,…]]`, `[179.9, nil, 0.0]` | PRAVDA — prázdnu musí odmietnuť potvrdenie samo (R11) |
| S7 | `Demos.sanitize_url` prijme len https na demos-trade.sk; `HardwareCatalog.sanitize_product_url` prijme http aj https, odmietne `javascript:`, `ftp:`, `file:`, medzery, úvodzovky, URL bez hostu | T7a–T7d | `[nil,'povolené je len https']`, `[nil,'adresa nie je z demos-trade.sk']`, `https://…demos…` ok; http/https obchodu ok, ostatné `nil` | PRAVDA |
| S8 | FAKTY: „`price_checked_at` zapisuje **len Demos cesta** (vyžaduje cenu > 0)" | T8a–c, **sonda_m1c.rb T20** | `demos_patch_for`: cena 0 → „musí byť kladná"; `price_confirmed` → pečiatka **bez** ceny; kód-only apply s URL pečiatku **nezmení** (starý dátum prežije). **Formulár ceruzky prijal od klienta podvrhnutý `price_checked_at`** | **ČIASTOČNE NEPRAVDA** — opravené v R6 (strhávanie server-owned polí) a R14 (O8) |
| S9 | Kto dnes maže `price_checked_at`: bunka (cena/kód/dodávateľ áno, `cp_nazov` nie, rovnaká cena „31,0" nie), editor „Upraviť…" (cena áno, **formát nie**), **formulár ceruzky pri zmene ceny/kódu/formátu NIE** (len zmena Demos URL a `supplier_decor`) | T9a–T9j | `[:ok,false]`×3, `[:ok,true]`×2; save_decor cena `false`, formát `true`; formulár cena/formát/kód → dátum **prežil** | PRAVDA (fakty „~6 miest" sedia) + **medzera formulára** (§13 F1) |
| S10 | Formulár, ktorý vráti zaokrúhlenú €/m² („31.04") nad presnou 179,9/5,796, cenu zmení → Rozpočet 179,91 € | T9k | `[31.04, 179.91]` | PRAVDA — rieši echo R12 |
| S11 | `Budget.price_per_plate` zaokrúhľuje až výsledok `(price_m2 × area).round(2)`, plocha z nezaokrúhleného formátu; 179,90 → €/m² presne → späť 179,90; €/m² na centy 31,04 → 179,91 | T10a/T10b | `179.91` / `179.9`; `179.9/5.796` = `31.03864734299517` | PRAVDA |
| S12 | O7 mriežka: 14 formátov × ceny 0,00–200,00 € (+4 hraničné) — presná €/m² vždy vráti zadanú cenu platne; €/m² na centy nie; JSON round-trip presnej hodnoty je bezstratový aj v JS | T10d, sonda_m1.js J1–J3 | **280 070 kombinácií: presne 0 chýb, na centy 195 435 chýb (70 %), JSON 0 chýb**; JS `JSON.parse` Ruby reprezentácie = ten istý double; JS platňa 179.9 | PRAVDA — O7 riešenie: ukladať nezaokrúhlene (R11) |
| S13 | Plocha platne v odhade (`SheetEstimate`) = `l*w/1e6` = `Budget.exact_sheet_m2` | T10e | `[5.796, 5.796]` | PRAVDA — potvrdenie použije ten istý vzorec |
| S14 | Rozpočet: materiál bez `demos_url` s ručným overením má v `freshness_item` stav `manual` (metódu ignoruje, `checked_at` len prepustí) → M1 Rozpočet vizuálne nemení | T11a/T11b | `state: "manual"`, `checked_at` prepustený, `age_days: nil` | PRAVDA — R24 |
| S15 | Starší plugin (dnešný kód = „starší" voči 11) nad markerom 11: `schema_write_allowed?(10)` false, zápis odmietnutý, `assess_catalog!` read-only s dôvodom | T12a–c | `false`, `false`, `[:read_only, "katalóg je v novšej schéme (11), než pozná táto verzia pluginu"]` | PRAVDA |
| S16 | Zápis jedného riadku mení `catalog_revision`, `row_rev` iného riadku nie → potvrdenie strážené len `row_rev` nekoliduje s ostatnými riadkami | sonda_m1b.rb T13 | `[[:ok,nil], true, false]` | PRAVDA |
| S17 | Klient sekcie posiela pevnú `MD_CLIENT_SCHEMA = 10`; guard ju viaže na `SCHEMA_CURRENT`; `schema_write_allowed?(11)` nad diskom ≤ 10 je `true` | `proj_materials.js:39`, `tests/pure/test_guards.rb:30`, T14 | `10`, guard existuje, `true` | PRAVDA |
| S18 | Bunka €/m² dnes ukazuje surový double, riadok bez Demosu nemá žiadnu ikonu, hlavička stĺpcov nemá slot pre ikony | sonda_m1.js J4–J7 | `value="31.03864734299517"`; bez ikon `true`; Demos `mddm` `true`; hlavička bez slotu | PRAVDA — R16, R21 |
| S19 | `PATCHABLE` ani `SAVE_DECOR_*_KEYS` `product_url` nenesú; `SHEET_SIZE_RANGE` = 500–5000 | sonda_m1b.rb T16/T18/T19 | zoznamy bez `product_url`; `500.0..5000.0` | PRAVDA — bunka ani editor odkaz nemenia (mockup C) |

**Opravené tvrdenia oproti FAKTY:** S8 (server-owned dátum ide dnes podvrhnúť formulárom; kód-only Demos apply nechá starý dátum). Ostatné fakty platia.

---

## 1 · Cieľ

Doska a ABS páska **bez väzby na Demos** dostanú v Štúdiu → Materiály (1) **jeden odkaz na produkt** — preklik do obchodu jedným klikom, chýbajúci odkaz svieti
jantárovo a vedie rovno do poľa na jeho doplnenie, a (2) **ručné overenie ceny** — „Overiť cenu" otvorí obchod (ak odkaz je) a formulár, kde cena „sedí" jedným klikom
(„Potvrdiť cenu k dnešku" zapíše dnešný dátum) alebo sa prepíše; doska sa zadáva **za platňu** s prepočtom na €/m², sklo bez formátu za m², ABS za bm. Stav overenia
(čerstvá / na kontrolu / nikdy) je farba ikony a tooltip. Akákoľvek zmena ceny, kódu, dodávateľa, odkazu (a pri doske formátu) mimo formulára overenie zruší. Demos má
prednosť. **Rozpočet sa v M1 nemení** (prichádza v M2).

## 2 · Rez dávky — odhad veľkosti a odporúčanie

Odhad zmenených riadkov **kódu pluginu** (bez testov, dokumentácie a mechanického prepisu `?v=`), podľa súborov. Referencia: CENY-KOV-A mal +329/−69, CENY-KOV-B +426/−70
(z toho ~95 Rozpočet); materiály majú navyše prepočet platňa ↔ m², echo, 6 ciest zneplatnenia, Demos prednosť v 3 cestách a pevný slot ikon.

| Súbor | M1a · odkaz | M1b · ručné overenie |
|---|---|---|
| `core/materials.rb` (schéma, normalize, sanitize, stav, echo) | ~55 | ~70 |
| `core/materials_catalog.rb` (whitelisty, confirm, reconcile, patch, Demos apply) | ~6 | ~120 |
| `core/materials_decor.rb` (save_decor edit) | — | ~15 |
| `ui/materials_dialog.rb` (akcie, formulár, payload) | ~65 | ~130 |
| `ui/js/proj_materials.js` (slot, ikony, formulár C, modal B/B2, zobrazenie) | ~130 | ~300 |
| `ui/studio.html` + `ui/css/panel.css` | ~32 | ~15 |
| **Spolu** | **~290** | **~650** |

**Celé M1 ≈ 940 riadkov → nad hranicou ~700. Odporúčam rez podľa vzoru CENY-KOV-A/B:** **M1a · Odkaz na produkt** (SCHEMA 11) → z čerstvého `main` **M1b · Ručné
overenie** (SCHEMA 12). Každá polovica je samostatne použiteľná a bezpečná: M1a nič neoceňuje (nie je cenová — len audit-povinná), M1b stavia na hotovom odkaze.
Dve schémy (nie jedna spoločná) sú zámer: keby 11 niesla obe polia už v M1a, plugin M1a by musel poznať celé pravidlá zneplatnenia `price_check_method` (inak by nad
katalógom z M1b editoval cenu a nechal „overené"). Rozhodne orchestrátor; požiadavky nižšie sú značené **[A]** / **[B]**. **Variant celé M1:** jediný
`SCHEMA_PRICE_LINK = 11` pre `product_url` ∪ `price_check_method`, jeden PR, jedna verzia; všetko ostatné rovnaké.

## 3 · Scope IN

- **Dáta katalógu** (`%APPDATA%\NOXUN\Engine\materials.json`): pole `product_url` (doska aj ABS) [A]; pole `price_check_method: 'manual'` + existujúce `price_checked_at`
  v novom význame „dátum ručného potvrdenia" pri položke bez Demos väzby [B]; schéma 11 [A] / 12 [B] podľa obsahu; všetky whitelisty (normalize, duplák, UNI, formulár,
  editor, patch, Demos apply).
- **Serverové operácie:** uloženie/zmazanie odkazu formulárom variantu [A]; otvorenie odkazu serverom [A]; ručné potvrdenie ceny s prepočtom platňa → €/m² [B]; zneplatnenie
  na všetkých cestách [B]; Demos prednosť [B]; stav overenia do payloadu katalógu [B].
- **UI Štúdio → Materiály:** pevný slot ikon v riadku variantu + hlavička [A]; ikona „Otvoriť produkt" (sivá/jantárová) [A]; pole „Odkaz na produkt" vo formulári
  variantu (ceruzka) so zámkom pri Demos [A]; ikona „Overiť cenu" + tooltip stavu [B]; formulár „Overiť cenu" pre dosku (za platňu / za m²) a ABS [B]; zobrazenie €/m²
  na 2 desatinné [B]; hlášky zneplatnenia [B].
- **Dokumentácia:** STANDARD §7.1, `docs/architecture/materials.md`, `docs/architecture/ui-lifecycle.md`, STAV, KRONIKA, PLAN, stav riadku DOGFOODING.

## 4 · Scope OUT

- **Rozpočet (M2):** stĺpec „Overená" pre ručné ceny, čip „N cien na kontrolu", zoznam na kontrolu, ikony odkazu/overenia v riadkoch Materiál a ABS hrany,
  `freshness_item`/`stale_scan` pre materiály, „Skontrolovať ceny", ikona odkazu pri Demos materiáloch v Rozpočte. **`budget.rb`, `budget.js`, `price_refresh.rb`, XLSX,
  cenová ponuka a VEPO sa v M1 nemenia** (R24).
- Kovanie (katalóg aj Rozpočet) — bez zmeny. Zjednotenie troch http(s) sanitizérov (§13 F3).
- Zoznam odkazov (C7 zrušil), cena za rolku ABS (nápad v mockupe), automatické sťahovanie cien mimo Demosu, história cien, upozornenie na dlaždici skupiny.
- Pole odkazu v editore „Upraviť…" (mockup C) a v „Pridať ručne"; odkaz v bunke riadku; `delete_preflight` sa nemení.
- *(Oprava medzery Demos dátumu vo formulári ceruzky — §13 F1 — je od rozhodnutia orchestrátora 30.9. v M1b ako R13b / D-148.)*
- Materiál bez formátu v Rozpočte podľa skutočných m² (C12) — **M2**.
- Klesanie schémy materiálov (vzor kovania) — ostáva „nikdy neklesá".

## 5 · Dotknuté dáta a kontrakt → **audit ÁNO**

- **Zmena schémy:** `SCHEMA_CURRENT` 10 → 11 [A] → 12 [B] (trieda `codex-audit`: „každé zvýšenie … STD/SCHEMA"). Marker **lazy podľa obsahu**: zdvihne ho **prvý zápis
  katalógu**, ktorý nesie neprázdny `product_url` [A] resp. kľúč `price_check_method` [B] — nie inštalácia, nie otvorenie Štúdia, nie zápis bez týchto polí (S1).
  Marker **nikdy neklesá** (S1): po zmazaní posledného odkazu ostáva 11 — vedome, zapíše sa do STANDARD.
- **Starší plugin** (≤ v0.16.0 voči 11; M1a voči 12) katalóg s vyšším markerom **len číta**: `assess_catalog!` read-only s dôvodom, `write_unlocked` odmietne, okno
  sekcie odmietne zápis (`schema_write_allowed?`) — S15. Rozpočet v staršom plugine číta ceny ďalej (ručne overený materiál ukáže ako dnes). **Pre Luciu:** katalóg je
  súbor na **každom PC zvlášť** — riziko vzniká pri **prenose `materials.json`** medzi PC alebo keď na tom istom PC beží **iný SketchUp so starším pluginom**
  (spoločný `%APPDATA%`). STAV, PR aj report: „aktualizovať obe PC pred prvým uložením odkazu [A] / ručného overenia [B]".
- **Server-owned polia:** `price_checked_at`, `price_check_method` NIKDY od klienta (dnes ide dátum podvrhnúť formulárom — S8/T20 → R6).
- **Model sa nemení:** všetky nové zápisy idú do globálneho katalógu (JsonFileStore + `with_catalog_lock`), žiadna `start_operation`, observer, undo, builder ani
  geometria. Zákazka nenesie cenu, dátum ani odkaz materiálu (snapshot dielca = `material_id`).

## 6 · Požiadavky

### 6.1 Dáta a schéma

- **R1 [A/B] Konštanty.** `materials.rb`: [A] `SCHEMA_PRODUCT_URL = 11`, `SCHEMA_CURRENT = SCHEMA_PRODUCT_URL`; [B] `SCHEMA_MANUAL_CHECK = 12`,
  `SCHEMA_CURRENT = SCHEMA_MANUAL_CHECK` — komentár vzoru ostatných `SCHEMA_*` (čo pole je, prečo starší klient read-only). `ui/js/proj_materials.js`
  `MD_CLIENT_SCHEMA` = tá istá hodnota (guard `test_guards.rb:30`) + komentár.
- **R2 [A/B] `Materials.required_schema_for`.** (a) **oprava pasce S2:** `need = SCHEMA_APPEARANCE if need < SCHEMA_APPEARANCE && r.key?('appearance')`; (b) [A] v cykle
  nad sheets+edges `need = SCHEMA_PRODUCT_URL if need < SCHEMA_PRODUCT_URL && !r['product_url'].to_s.strip.empty?`; [B] `need = SCHEMA_MANUAL_CHECK if
  need < SCHEMA_MANUAL_CHECK && r.key?('price_check_method')`. Výsledok nesmie závisieť od poradia záznamov (test všetkých permutácií zmiešaného zoznamu
  appearance · uni · demos · product_url · manual).
- **R3 [A] `product_url` v normalizácii.** `normalize_sheet` a `normalize_edge` volajú nový `put_product_fields(out, a)` **po** `put_uni_fields`/`put_duplak_fields`
  (doska) resp. `put_demos_fields` (ABS): uloží `product_url` len keď `sanitize_product_url` vráti String; UNI (`out['uni'] == true`) ani duplák
  (`out.key?('source_material_id')`) pole nikdy nedostanú. Neplatná hodnota sa tu ticho zahodí (poistka — hláška patrí formuláru, R6). Pole prežije každý
  merge-safe zápis existujúceho záznamu (bunka, editor „Upraviť…", Demos apply, `set_decor_name/color/manufacturer`, `rename_decor`, zápis vzhľadu, `sync_duplaks_in!`).
- **R4 [A] `Materials.sanitize_product_url(raw)`** — rovnaké pravidlá ako `HardwareCatalog.sanitize_product_url` (String → strip → bez `\s"'<>\` → `URI::HTTP`/`URI::HTTPS`
  s neprázdnym hostom → `uri.to_s`), **lokálna kópia** (normalize nesmie závisieť od poradia načítania iného modulu) + **parity test** nad tabuľkou S7 rozšírenou o
  `HTTPS://` veľkými, query, fragment, port, `mailto:`, `data:`. **http aj https** — rozhodnutie §12 D1.
- **R5 [A/B] Whitelisty.** `duplak_record_from` reject += [A] `product_url`, [B] `price_check_method` (S4); `uni_edit_error` touched += [A] `product_url` (S5);
  `PATCHABLE` a `SAVE_DECOR_SHEET_KEYS`/`SAVE_DECOR_EDGE_KEYS` sa **nemenia** (S19; test ich pripne — bunka ani editor odkaz nemenia a server-owned polia neprijmú);
  `demos_patch_for`/`demos_items_from_accepts`/`create_group_from_demos` `product_url` ani `price_check_method` nikdy nezapisujú.
- **R9 [B] `price_check_method` v normalizácii** — `put_price_check_fields(out, a)` (volá sa ako posledné pred `put_appearance_field`): pole nesie **len** hodnotu
  `'manual'` a **len** keď `out['price_checked_at']` je neprázdne, `out['demos_url']` prázdne a záznam nie je UNI ani duplák. Ak `'manual'` príde spolu s neprázdnou
  `demos_url`, zahodí sa **metóda aj `price_checked_at`** (ručný dátum sa nikdy nesmie tváriť ako Demos dátum — poistka pre O8; Demos cesty to riešia výslovne R14).
  Iná hodnota metódy → zahodená.
- **R10 [B] `Materials.manual_price_state(rec, stale_days:, now:)`** — čistá funkcia, **jediná autorita stavu** (M2 ju prevezme do Rozpočtu): `nil` pri Demos väzbe,
  UNI a dupláku; inak `{'state' => 'fresh'|'stale'|'never', 'checked_at' => String|nil, 'age_days' => Integer|nil}`. Platné overenie = `price_check_method == 'manual'`
  ∧ `Time.iso8601(price_checked_at)` sa dá prečítať ∧ ≤ `now` ∧ cena (`price_per_m2`/`price_per_bm`) je konečné číslo ≥ 0. Vek = `floor((now − stamp) / 86 400)`
  (vzor `Budget.manual_hardware_freshness`); `age ≥ stale_days` → `stale`. **Odkaz sa nevyžaduje** (O9 — odchýlka od kovania). Neplatné/chýbajúce → `never`.

### 6.2 Serverové operácie

- **R6 [A] Formulár variantu (ceruzka) — server** `MaterialsDialog.handle_save_sheet` / `handle_save_edge`:
  - **pred** merge strhnúť od klienta `price_checked_at`, `price_check_method` (S8/T20) a ozdoby payloadu (`product_link`, `price_check`, `row_rev`, `label`, `row_label`,
    `row_key`, `image_file`) — ozdoby by normalize zahodil aj tak, test ich pošle;
  - kľúč `product_url`: nie String → hláška „Odkaz musí byť text."; prázdny po strip → vedomé zmazanie; neprázdny → `sanitize_product_url`, inak **celý save odmietnuť**
    hláškou „Odkaz musí začínať http:// alebo https:// (bez medzier a úvodzoviek)." (nič sa nezapíše); chýbajúci kľúč = bez zmeny (merge);
  - **O8/C4:** ak je **výsledná** `demos_url` (z payloadu, keď ju nesie, inak uložená) neprázdna a payload nesie `product_url` odlišný od uloženého → odmietnuť
    „Položka je viazaná na Demos — ručný odkaz zadáš až po vymazaní Demos URL." (odložený odkaz sa formulárom nezmaže ani neprepíše; v jednom uložení sa dá Demos URL
    vymazať a odkaz vložiť);
  - UNI s neprázdnym `product_url` → existujúca hláška `uni_edit_error`.
- **R6b [A] Formulár variantu drží vlastnú revíziu (audit FIX-M1a-2).** `mdOpenSheetForm`/`mdOpenEdgeForm` uložia do stavu formulára `row_rev` riadku **z okamihu
  otvorenia** (baseline); katalógové echo (`MD.setCatalog` → globálny `MD_REV`) ho **neomladí**; `mdSaveSheet`/`mdSaveEdge` posielajú baseline. Server pri
  nezhode vráti `:conflict` „Položka sa medzitým zmenila — formulár sa otvoril s aktuálnymi údajmi." a klient formulár otvorí nanovo s čerstvými údajmi (rozpísané
  hodnoty sa nezapíšu). Scenár testu (doska aj ABS): otvorená ceruzka → Demos apply alebo zmena bunky → echo → uloženie samotného odkazu = konflikt, cena ani Demos
  väzba sa nevrátia do starého stavu.
- **R6c [A] Kontrola a zápis formulára v jednej transakcii (audit FIX-M1a-3).** `handle_save_sheet`/`handle_save_edge` vykonajú kontrolu schémy a revízie (R6b),
  načítanie existujúceho záznamu, merge, pravidlá R6 (v M1b aj R12/R13/R13b) a zápis **pod jedným `with_catalog_lock`** (vzor `save_decor` v
  `core/materials_decor.rb` ~r. 1107) — dnes sa revízia kontroluje a záznam číta mimo zámku (`materials_dialog.rb` ~r. 1634) a zámok berie až
  `upsert_sheet`/`upsert_edge` (`materials_catalog.rb` ~r. 225), ktorý čerstvý záznam neoverí znova. Test: konkurenčný zápis (druhá inštancia) vložený presne medzi
  dnešnú kontrolu a získanie zámku (stub) → `:conflict`, konkurenčný odkaz ani potvrdená cena sa neprepíšu. Mutácia M22.
- **R7 [A] Otvorenie odkazu** — nová akcia `mat_product_open` `{kind, id}` (SECTION_ACTIONS + `run_section_action`): `JsonFileStore.invalidate(Materials.path)` +
  čerstvý záznam podľa `kind + id`; `UI.openURL(sanitize_product_url(rec['product_url']))` **len** ak záznam existuje, nie je UNI/duplák, `demos_url` je prázdna a
  odkaz je platný; inak `set_status('Odkaz sa medzitým zmenil alebo chýba — katalóg sa obnovil.', true)` + `push_catalog`. **Nič nezapisuje** (test: bajty katalógu
  pred/po rovnaké). URL od klienta sa neprijíma. Demos riadky ostávajú na `open_demos_url` bez zmeny.
- **R8 [A/B] Payload katalógu** (`MaterialsDialog.full_catalog_payload`): [A] riadky dosiek/ABS nesú `product_link` (bool — platný `product_url`) **len** pri „ručných"
  záznamoch (bez `demos_url`, nie UNI, nie duplák); `row_rev` sa počíta zo **surového** záznamu pred ozdobami (bez zmeny). [B] navyše `price_check` =
  `Materials.manual_price_state(rec, stale_days:, now: Time.now.utc)` pri ručných záznamoch a v `catalog_payload` kľúč `stale_days`
  (`SupplierSettings.scalar(SupplierSettings.active, 'stale_days')`, fail-soft 30). Klient stav nepočíta, len skladá text.
- **R11 [B] Potvrdenie** `Materials.confirm_manual_price(kind, id, price:, basis:, row_rev:)` →
  `[:ok, {'rec', 'unchanged', 'plate', 'price'}] | [:not_found | :conflict | :invalid | :catalog_read_only | :write_failed, msg, field]`:
  1. `catalog_read_only?` → `:catalog_read_only` (`catalog_read_only_message`).
  2. Cena: String alebo Numeric → `normalize_price`; `nil`, prázdna, nekonečná, záporná → `:invalid` „Vlož nezápornú cenu s DPH; prázdna cena sa nedá potvrdiť."
     (field `price`). **0 je platná** (O4).
  3. `basis`: doska `'plate' | 'm2'`, ABS `'bm'`; iné → `:invalid` (field `basis`).
  4. **Pod `with_catalog_lock`:** `JsonFileStore.invalidate`, `load`, záznam podľa `kind + id`; chýba → `:not_found` „Položka už v katalógu nie je."; `row_rev` prázdny
     alebo iný → `:conflict` „Položka sa medzitým zmenila — skontroluj aktuálne údaje."; UNI → `:invalid` „UNI je pracovný materiál bez nákupnej ceny."; duplák →
     `:invalid` „Duplák sa oceňuje zdrojovou doskou."; neprázdna `demos_url` → `:invalid` „Položka je viazaná na Demos — cenu obnovuje Demos." **Odkaz sa nevyžaduje (O9).**
  5. `plate`: vyžaduje platný `sheet_size` (dve čísla v `SHEET_SIZE_RANGE`), inak `:invalid` „Cena za platňu sa bez formátu nedá prepočítať na €/m² — prepni na
     „za m²" alebo doplň formát." (field `basis`). `plate = (amount * 100).round / 100.0` (D3); `area = l * w / 1_000_000.0` (ten istý vzorec ako
     `Budget.exact_sheet_m2` — S13). Ak sa `plate` v centoch **presne rovná zobrazenej cene platne** (R11a) → cena ostáva **bitovo tá istá** (`unchanged: true`);
     inak `price_per_m2 = plate / area` **nezaokrúhlene** (O7, S11/S12).
  6. `m2`: vstup v centoch **presne rovný zobrazenej €/m²** (R11a) alebo bitová rovnosť → ostáva uložená (`unchanged`); inak `price_per_m2 = amount`.
  7. `bm`: `price_per_bm = amount` (bitová rovnosť alebo presná zhoda so zobrazenou hodnotou → `unchanged`).
- **R11a [B] Nezmenená cena = presná zhoda so zobrazenou hodnotou (audit BLOCKER).** Žiadny symetrický interval (±0,005 vedie pri uložených hodnotách na hranici
  pol centa k tomu, že vedomá zmena o 1 cent sa vyhodnotí ako „bez zmeny": sonda audítora — uložené 1,005 €/m², formát 1000 × 1000, vstup 1,00 € → `unchanged`,
  ale Rozpočet ďalej účtuje 1,01 €). **Zobrazené hodnoty počíta VÝHRADNE server** a posiela ich v payloade (`price_display` v riadku katalógu a v snapshote
  formulára): **cena platne** = presne tá hodnota, ktorú ukáže Rozpočet (`Budget.price_per_plate(uložená_€/m², nil, sheet_size)` — tá istá funkcia, nie kópia
  vzorca), **€/m²** = jedna definovaná zaokrúhľovacia funkcia `Materials.display_m2` (napr. `BigDecimal(stored.to_s).round(2, :half_up)`; tá istá pre bunku,
  formulár, editor aj prefill), **€/bm** = uložená hodnota bez zaokrúhlenia. Klient čísla sám **nezaokrúhľuje** (prefill = `price_display` servera).
  „Bez zmeny" ⇔ pri **`plate` a `m2`** vstup prevedený na celé centy == zobrazená hodnota v celých centoch (celočíselné porovnanie); pri **`bm`**
  normalizovaný vstup == uložená hodnota **presne** (napr. uložené 0,125 €/bm a vstup 0,13 = zmena — delta audit). `price_display.plate` je `nil`, keď
  riadok nemá platný katalógový `sheet_size` (potvrdenie „za platňu" je tam aj tak odmietnuté, krok 5; zhoda s Rozpočtom sa sľubuje len pri formáte). Testy: hodnoty na hranici pol centa (1,005 · 31,005 ·
  2,675 · 0,125 · …) × formáty (1000 × 1000, 2800 × 2070, 4100 × 635) — vstup = zobrazená hodnota → bitovo bez zmeny; vstup = susedný cent → zmena a Rozpočet
  potom ukáže presne vstup. Mutácia M23 (interval namiesto presnej zhody).
  8. `merged` = existujúci + cena + `price_checked_at = Time.now.utc.iso8601` + `price_check_method = 'manual'` → `validate_sheet_attrs`/`validate_edge_attrs` →
     `normalize_*` → nahradiť v dátach → `write_unlocked` (marker 12 podľa obsahu); zlyhanie → `:write_failed` „Cenu sa nepodarilo uložiť."
  9. **Nepoužíva `catalog_rev`** (len `row_rev` — S16), nemení iný záznam; dátum a metóda nikdy od klienta.
- **R12 [B] Echo zaokrúhlenej €/m²** `Materials.sheet_price_echo?(raw, stored)` = vstup v celých centoch **presne rovný `display_m2(stored)`** (R11a — nie interval)
  → „bez zmeny" (uložená hodnota ostáva). Používa sa pri €/m² **dosky** v: `patch_record` (bunka —
  kľúč sa z `clean` vyhodí; keď tým patch ostane prázdny, vráti sa `[:ok, nil]` **bez zápisu**, nie dnešné `:invalid` „Žiadne editovateľné pole."), `handle_save_sheet` (vstup nahradí uložená hodnota), `save_decor_edit_sheet` (kľúč sa z patchu vyhodí),
  `confirm_manual_price` basis `m2`. ABS echo nemá (€/bm sa nezaokrúhľuje ani v zobrazení). Bez toho S10: formulár zmení 179,90 € na 179,91 € a zruší overenie.
- **R13 [B] Zneplatnenie (O6)** — jedna funkcia `Materials.reconcile_manual_check!(existing, rec)` (mutuje `rec`): ak `existing['price_check_method'] == 'manual'`
  a `rec['price_checked_at'] == existing['price_checked_at']` (nejde o nové potvrdenie) a líši sa niektoré overené pole — **cena** (Float, po echu R12), **`code`**
  (strip), **`supplier`** (strip), **`product_url`** (sanitizovaný), pri doske **`sheet_size`** (normalizovaný pár; pridanie, zmena aj zmazanie), **`supplier_decor`**
  (strip — D5) — alebo `rec['demos_url']` je neprázdna → zmaže `price_check_method` **aj** `price_checked_at` a vráti `true` (volajúci podľa toho povie vetu R22).
  Volá sa na **každej** ceste, ktorá prepisuje existujúci záznam a môže zmeniť tieto polia:

  | cesta | súbor:metóda |
  |---|---|
  | bunka kód / €/m² / €/bm / dodávateľ / `supplier_decor` | `core/materials_catalog.rb:patch_record` |
  | formulár variantu (ceruzka) | `ui/materials_dialog.rb:handle_save_sheet`, `handle_save_edge` |
  | editor „Upraviť…" | `core/materials_decor.rb:save_decor_edit_sheet`, `save_decor_edit_edge` |
  | Demos apply (lookup, ručná URL v lookup-e, Prepočítať ceny) | `core/materials_catalog.rb:apply_demos_batch` (cez R14) |

- **R13b [B] D-148 — Demos dátum vo formulári ceruzky.** `handle_save_sheet` / `handle_save_edge` pri položke **s Demos väzbou**, ktorá väzbu nemení, zmaže
  `price_checked_at`, keď sa zmení cena (po echu R12), `code`, `supplier` alebo pri doske `sheet_size` — to isté, čo dnes robí bunka (`patch_record`) a editor
  „Upraviť…" (S9). Ručne prepísaná Demos cena tak prestane vyzerať overene a „Prepočítať ceny" ju znova overí. Status: „Uložené — dátum overenia z Demosu sa
  zrušil, cenu obnoví Prepočítať ceny." Test v O6 matici (Demos riadok × formulár × každé pole) + mutácia M20.

  **Nezneplatňuje** (test „prežije" pre každú): `set_decor_name`, `set_decor_color`, `set_decor_manufacturer`, `rename_decor`, zápis vzhľadu (appearance), `grain`,
  `cp_nazov`, `pd_edge_subtype`, `universal`, `sync_duplaks_in!` na zdroji, `ensure_uni_records!`/seed.
- **R14 [B] Demos má prednosť (O8).** `demos_patch_for`/`apply_demos_batch`: ak má existujúci záznam `price_check_method == 'manual'`, výsledok stratí metódu;
  `price_checked_at` ostane **len** ak ho patch práve zapísal (nová alebo potvrdená Demos cena), inak sa zmaže (S8: kód-only apply by nechal ručný dátum ako Demos
  dátum). `product_url` sa **nemaže** (odchýlka od `HardwareCatalog.apply_price_proposal!`, vedomá). Formulár: vloženie Demos URL k ručne overenej položke
  (`manual_demos_url` invalidate) zmaže aj metódu (R13). Zrušenie Demos väzby (prázdne Demos URL) → `price_checked_at` sa zmaže (dnešné správanie), `product_url` je
  znova aktívny, ručné overenie sa **nevracia** (položka je „nikdy neoverená").
- **R15 [B] Akcie kanála** (SECTION_ACTIONS + `run_section_action`; mená s predponou **`mat_`** — kolízie so `hw_*` a ostatnými sekciami stráži test vzoru
  `test_s1a2_sekcia.rb:107`):
  - `mat_manual_prepare` `{kind, id, token, section, model_guid}` → `MD.manualReady(snapshot)`; snapshot = echo `kind, id, token, section, model_guid` + čerstvý `item`
    (kópia záznamu s `label`), `row_rev`, `has_url` (platný `product_url` a bez Demos), `read_only`, `reason`, `stale_days`. Nič nezapisuje.
  - `mat_manual_open` `{kind, id, row_rev, token, section, model_guid}` → čerstvý záznam; `UI.openURL` **len** ak existuje, bez Demos, `has_url` a `row_rev` sedí;
    `UI.openURL == false` → výsledok s upozornením „Obchod sa nepodarilo otvoriť — cenu si over inak a potvrď." (**neblokuje** potvrdenie — mockup B1 po review #425);
    výsledok `MD.manualResult(phase: 'open', opened: true|false)`. Nič nezapisuje.
  - `mat_manual_confirm` `{kind, id, row_rev, price, basis, token, section, model_guid, catalog_schema}` → `schema_ok?` (starý klient odmietnutý) → model guard
    `DocKey.foreign?` (vzor `HardwareCatalogDialog.product_model_current?`, D10) → `Materials.confirm_manual_price`; `:ok` → `after_catalog_change` (push katalógu,
    panel, `refresh_if_open(bump: false)`) + status R20; `:conflict` → `push_catalog` + výsledok s čerstvým snapshotom; výsledok `MD.manualResult(phase: 'submit',
    ok, status, msg, errors[field])`.
  - Tok **nepoužíva** Demos session ani `@demos_running` → `cancel_demos_on_leave`/`mat_leave` ho neruší; odoslané potvrdenie na serveri dobehne aj po odchode zo sekcie
    (neskorá odpoveď smie obnoviť katalóg, nesmie vlastniť cudzí modal — vzor `hwManualClose`).

### 6.3 UI — Štúdio → Materiály

- **R16 [A] Pevný slot ikon (O1, A3)** — `mdSectionRows`/`mdVariantRow`: medzi bunku Dodávateľ a `.mdvact` `<span class="mdslot">` s **troma pozíciami**:
  1 = duplák (DTDL/MDF) resp. univerzálna (ABS) · 2 = Demos ikona **alebo** ikona odkazu · 3 = ikona overenia [B]; prázdna pozícia = `<i class="mdgap">` rovnakej šírky;
  `.mdvhead` dostane ten istý prázdny slot → stĺpce Kód / €/m² / Dodávateľ sú pod sebou v riadkoch s Demosom aj bez neho. Riadok **nepribudne** (vertikálny priestor).
  `mdDuplakRow` sa nemení. UNI: pozície 2 a 3 prázdne (A7). CSS v `ui/css/panel.css` (tokeny `--nx-*`, obe témy; vzor mockupu `.mkslot/.mkgap/.mdprod/.mdchk`).
- **R17 [A] Ikona „Otvoriť produkt"** (`#i-external-link`, tá istá kresba ako Demos, ale sivá; `mduni mdprod`) **len** pri ručných záznamoch: `product_link === true` →
  `title` „Otvoriť produkt v prehliadači\n<host>", klik `sketchup.mat_product_open({kind, id})`; `false` → `is-missing` (jantár `--nx-warn-fg/bg`, vzor
  `.hw-product-link.is-missing`), `title` „Chýba odkaz — doplniť odkaz na produkt", klik otvorí formulár variantu s **kurzorom v poli „Odkaz na produkt"** a krátkym
  zvýraznením riadku (C3; `mdOpenSheetForm(id, {focus: 'product_url'})`, `mdOpenEdgeForm` obdobne). `aria-label` „Otvoriť produkt · DTDL 25" / „Doplniť odkaz na
  produkt · DTDL 25". Read-only katalóg: existujúci odkaz sa otvorí, jantárová ikona povie „Katalóg je len na čítanie — úpravy sú vypnuté."
- **R18 [A] Pole „Odkaz na produkt" vo formulári variantu** (`ui/studio.html` `#mdSheetForm`/`#mdEdgeForm`: `ms_product_url`/`me_product_url` + `*_product_hint`) hneď **nad**
  „Demos URL": prefill `product_url`; hint „Otvorí sa vo webovom prehliadači." [B: + veta R22]; **zamknuté** (`readonly`, prázdne, placeholder „— viazané na Demos",
  hint C4 „Položka je viazaná na Demos — odkaz aj cenu spravuje Demos (pole Demos URL nižšie). Ručný odkaz zadáš až po vymazaní Demos URL." + pri uloženom odloženom
  odkaze „ Uložený ručný odkaz sa po zrušení väzby vráti.") **keď pole Demos URL nie je prázdne — živo** pri písaní do Demos URL; pri UNI skryté (vzor `mdDemosField`);
  klientska kontrola `mdProductUrlLocalError` (zrkadlo R4, formulár ostáva otvorený — vzor `mdDemosUrlLocalError`); `mdSaveSheet`/`mdSaveEdge` pošlú `product_url`
  **len** keď je pole editovateľné; `mdReopenFromAttempt` ho obnoví. Editor „Upraviť…" pole nedostane (C).
- **R19 [B] Ikona „Overiť cenu"** (`#i-clipboard-check`, `mduni mdchk`) na pozícii 3 pri ručných záznamoch: `price_check.state` `never`/`stale` → `is-pending` (jantár),
  `fresh` → sivá; `title` presne podľa **O5** (čistá funkcia `mdManualTip(rec)`, dátum `mdDateLabel`, vek zo servera):
  „Cena ručne overená 18.9.2026 (pred 12 dňami)" (vek 0 → „(dnes)", 1 → „(pred 1 dňom)") · „Ručne overená 16.8.2026 — pred 45 dňami, na kontrolu" ·
  „Cena nebola nikdy ručne overená — na kontrolu" · bez ceny „Cena chýba a nebola nikdy overená — na kontrolu"; druhý riadok „Overiť cenu — otvorí obchod a formulár" /
  „Overiť cenu — bez odkazu otvorí len formulár". `aria-label` „Overiť cenu · DTDL 25". Read-only katalóg → `disabled`.
- **R20 [B] Formulár „Overiť cenu" (B, B2)** — `NXModal.open` (vzor `hwManualOpen`): titulok „Overiť cenu ručne", podtitulok „H1180 DTDL 25 mm · Dub Halifax prírodný" /
  „ABS H1180 43/0,8 · …", `memoryKey: null`, `busyLock: true`, `initialFocus: 'price'`, `okLabel` „Potvrdiť cenu k dnešku". Polia:
  1. `group`: dodávateľ (alebo „Dodávateľ neuvedený") + odkaz ako text, **alebo** „Bez odkazu — obchod sa neotvorí; cenu si over u dodávateľa (telefón, e-mail, ponuka)." (O9);
  2. „Položka" (text): doska „kód 310418 · formát 2800 × 2070 mm (5,796 m²)" / „kód — · formát nie je v katalógu"; ABS „ABS 43 × 0,8 mm · kód —";
  3. `custom` pole `price` (typ KOV-B3): pri doske prepínač **„za platňu | za m²"** (predvolené za platňu, keď formát je; za m², keď nie je — O3); vstup ceny (prefill:
     platňa `round2(€/m² × plocha)`, m² `round2(€/m²)`, ABS presná hodnota; prázdne pri chýbajúcej cene); jednotka „€ s DPH" / „€ s DPH / m²" / „€ s DPH / bm";
     **živý prepočet** („→ 31,04 €/m² (2800 × 2070)" / „= 179,90 € za platňu (2800 × 2070)" / „bez prepočtu — formát nie je v katalógu"); riadok **„Oproti katalógu"**
     („bez zmeny (179,90 € za platňu) — stačí potvrdiť" · „+2,30 € (+1,3 %) oproti katalógu (179,90 € za platňu)" · „v katalógu zatiaľ bez ceny"); prepnutie režimu
     prepočíta rozpísané číslo; `read` vráti `{basis, price}`;
  4. `note`: „Posledné ručné potvrdenie: 18.9.2026." / „Cena zatiaľ nebola ručne potvrdená." + „ Potvrdená cena platí v celom katalógu." + pri 0 „ 0 € — materiál sa do
     rozpočtu započíta nulou (napr. ho dodá zákazník)." (O4).

  S odkazom: 25 ms po otvorení `mat_manual_open`; potvrdenie čaká len na **odpoveď** servera o pokuse (úspech aj neúspech; kým nepríde, chyba „Počkaj na otvorenie
  produktu a skontroluj cenu."); **neúspešné otvorenie prehliadača potvrdenie neblokuje** — formulár ukáže upozornenie z R15 a potvrdiť sa dá (B1). **Bez odkazu (O9): prehliadač sa neotvára, potvrdiť sa dá hneď.** Klientska kontrola: prázdne / nečíslo / záporné → chyba pri poli;
  „za platňu" bez formátu → chyba navrchu. Enter v poli = potvrdiť; Esc, krížik, „Zrušiť" = nič sa nezapíše. `ok` → zatvoriť + status „Cena potvrdená k 30.9.2026:
  179,90 € za platňu = 31,04 €/m²." (+ „ (bez zmeny ceny — len dátum)" pri `unchanged`); `conflict` → formulár nanovo s čerstvými údajmi a hláškou (vzor kovania);
  `read_only` / `not_found` / Demos / `stale_model` → zatvoriť + status. Čisté funkcie pre Node test: `mdManualCalc`, `mdManualDiff`, `mdManualNote`, `mdManualPayload`.
- **R20b [B] Presná interná hodnota formulára (audit FIX-M1b-4).** Formulár drží **presnú** hodnotu zo servera (uložená €/m², plocha platne, `price_display`
  pre oba režimy) oddelene od zobrazeného textu a príznak **„dotknuté"** (používateľ písal do poľa). **Samotné prepnutie jednotky bez písania cenu nemení:** text sa
  prepíše na `price_display` zvoleného režimu (nie prepočtom zobrazeného textu) a pole ostáva nedotknuté → potvrdenie = bitovo tá istá cena, len dátum. Po písaní sa
  pri prepnutí prepočíta **napísané** číslo a pole ostáva dotknuté. Server rozhoduje podľa R11a (klientsky príznak je len pomoc UI). Testy (Node + Ruby):
  10× prepnutie tam a späť bez písania → potvrdenie bez zmeny ceny (179,90 € ostane 179,90 €, nie 179,91 €); napísaná nová cena → prepnutie → potvrdenie uloží
  zámer. Mutácia M24 (prepnutie prepočíta zobrazený text).
- **R21 [B] Zobrazenie €/m² (O7)** — bunka €/m², pole „Cena" formulára variantu a stĺpec ceny editora „Upraviť…" ukazujú €/m² dosky na **2 desatinné** (bunka s bodkou ako
  dnes, editor s čiarkou); `data-orig` = zobrazený text (nezmenená bunka nič nepošle — S18). ABS €/bm bez zmeny. Server R12 zaručí, že vrátená zaokrúhlená hodnota
  nič nezmení.
- **R22 [B] Vety o zneplatnení** — hint pod odkazom vo formulári variantu: „Cena ručne overená 18.9.2026 — zmena odkazu, ceny, kódu, dodávateľa alebo formátu overenie
  zruší." (ABS bez „alebo formátu") / „Cena zatiaľ nebola ručne overená."; po uložení, ktoré overenie zrušilo (bunka, formulár, editor — server vie z R13): status
  „Uložené — ručné overenie ceny sa zrušilo, položka ide na kontrolu."
- **R23 [A/B] Životný cyklus.** Odchod zo sekcie `mat` (`matCloseModals`) zatvorí formulár „Overiť cenu" a zahodí čakajúci prepare/open; zmena modelu/dokumentu tiež —
  nová `mdManualContextChanged(section, model_guid)` volaná zo `studio.js` na tých istých miestach ako `hwProductContextChanged` (:984, :1021, :1932). Katalógové echo
  (`MD.setCatalog`) otvorený formulár nezatvára; ďalšie potvrdenie nesie pôvodný `row_rev` a server rozhodne (conflict = nový formulár s čerstvými dátami). Odpoveď
  s cudzím tokenom sa ignoruje. Okná dostanú novú klientsku schému cez `?v=` (konštanta kódu, nie echo servera).
- **R24 [A/B] Rozpočet a ostatné výstupy sa NEMENIA.** `budget.rb`, `budget.js`, `price_refresh.rb`, `xlsx_writer.rb`, `cp_export.rb`, VEPO bez zmeny kódu. Ručne overený
  materiál ostáva v Rozpočte v stave `manual` (S14; `checked_at` payload `stale.items` prepúšťa už dnes a `budget.js` ho pri materiáloch nečíta — M2 ho prevezme).
  Jediný dopad na Rozpočet je **dátový**: potvrdená alebo zmenená cena sa prepočíta vo všetkých zákazkách (katalóg je živý) — zámer (mockup B, „Na vedomie").

### 6.4 Dokumentácia

- STANDARD **§7.1**: nový odsek „Odkaz na produkt a ručné overenie ceny (CENY-M1, SCHEMA 11/12)" — polia, server-owned, O6 zoznam overených polí, O7 presná €/m²,
  O8 prednosť Demosu a odložený odkaz, marker lazy a neklesá, starší plugin read-only.
- `docs/architecture/materials.md` — prepísať **na mieste** odseky `materials.rb` (schéma, normalize, sanitize, stav, echo), `materials_catalog.rb` (confirm,
  reconcile, patch, Demos apply, duplák), `materials_decor.rb` (save_decor edit) a „materials_* — spoločný kontrakt" (zoznam markerov 11/12).
- `docs/architecture/ui-lifecycle.md` odsek `materials_dialog.rb` (nové akcie `mat_*`, formulár variantu, payload `product_link`/`price_check`/`stale_days`, životný cyklus
  formulára „Overiť cenu").

## 7 · Testy a DoD

1. **`tests/pure/test_ceny_m1_links.rb` [A]:** marker 11 len obsahom, permutácie R2, neklesá po zmazaní odkazu; normalize carry/drop (UNI, duplák, neplatný, http, https);
   parity R4; whitelisty R5 (duplák, UNI, `PATCHABLE`/`SAVE_DECOR_*` pripnuté); `product_url` prežije každú zapisovaciu cestu R3; formulár R6 (platný / neplatný =
   nič nezapísané / prázdny = zmazanie / Demos zámok / Demos vymazané + odkaz v jednom uložení / podvrhnuté server-owned polia strhnuté); `mat_product_open` R7
   (`UI.openURL` stub vzoru `test_ceny_kov_links.rb:209`; neplatný, Demos, UNI, chýbajúci → neotvorí; bajty katalógu nezmenené); payload R8 (`product_link`, `row_rev`
   zo surového záznamu); **starší plugin** (dočasne `SCHEMA_CURRENT` = 10, vzor `test_ceny_kov_links.rb:173`) → read-only, zápis odmietnutý; SECTION_ACTIONS bez kolízie.
2. **`tests/pure/test_ceny_m1_manual.rb` [B]:** matica `confirm_manual_price` (plate / m2 / bm; 0; prázdna; záporná; nečíslo; plate bez formátu; UNI; duplák; Demos;
   conflict; not_found; read-only; **bez odkazu OK**; `unchanged` bitovo rovnaká cena; dátum zo servera v okne `before..after`; metóda `manual`; marker 12);
   **O7 mriežka** (≥ 14 formátov × 0,00–200,00 € po centoch: `Budget.price_per_plate(uložená, plocha.round(3), formát) == zadaná platňa` + round-trip cez
   `JsonFileStore`); echo R12 (bunka, formulár, editor, confirm m2; ABS bez echa); **O6 matica** (každá cesta R13 × každé overené pole → overenie zanikne a status
   nesie vetu R22; každá nezneplatňujúca cesta → prežije); **O8** (lookup apply s novou cenou / `price_confirmed` / kód-only; formulár Demos URL; zrušenie väzby →
   odkaz späť, overenie nie; `product_url` nikdy zmazaný); normalize invarianty R9; `manual_price_state` R10 (deň 29/30, prah z nastavení, budúci dátum, poškodený
   dátum, bez ceny, bez odkazu = fresh, UNI/duplák/Demos = nil); akcie R15 (prepare/open/confirm snapshot, model guard, schema guard, conflict push, `openURL == false`,
   tok mimo Demos session); **Rozpočet nezmenený** (R24: `test_np4_golden.rb` zelený + `Budget.compute` pre katalóg s/bez nových polí rovnaké riadky, čísla a XLSX
   bajty; jediný rozdiel `stale.items[].checked_at`).
3. **`tests/js/test_ceny_m1_links.js` [A]:** slot R16 (hlavička = každý riadok, Demos / ručný / UNI / ABS), ikona sivá/jantár, `title`/`aria-label`, klik (open vs.
   formulár s fokusom), formulár C R18 (živý zámok pri Demos URL, hinty, lokálna chyba, payload bez `product_url` pri zámku), `MD_CLIENT_SCHEMA`.
4. **`tests/js/test_ceny_m1_manual.js` [B]:** texty O5 (presné reťazce, vek 0/1/12), stav ikony, tok modalu (prepare → ready → open ack → submit → result; O9 bez open;
   `browserPending`; cudzí token; odchod zo sekcie; zmena modelu; conflict reopen; Enter; Esc = nič), čisté funkcie calc/diff/note (platňa ↔ m², bez formátu, 0 €,
   percentá, režim prepnutý s rozpísaným číslom), zobrazenie 2 desatinné R21 (bunka, formulár, editor; ABS nie), payload bez server-owned polí.
5. **Existujúce testy na úpravu:** JS sady s regexami riadku variantu (`test_md_schema2.js`, `test_st2a_mat.js`, `test_1b7_kolizia_buniek.js`, `test_st2c_editor.js` —
   podľa toho, čo zhodí slot); `test_guards.rb` sa prispôsobí sám (konštanty).
6. **Mutácie (každá musí zhodiť aspoň jeden test; min. 14):** M1 vrátiť bezpodmienečný riadok appearance · M2 normalize nenesie `product_url` · M3 duplák zdedí
   `product_url` · M4 UNI prijme `product_url` · M5 formulár prijme neplatný odkaz · M6 formulár zmení odkaz pri Demos väzbe · M7 formulár nestrhne klientsky
   `price_checked_at` · M8 `mat_product_open` otvorí URL z payloadu klienta · [B] M9 potvrdenie ukladá €/m² na centy · M10 potvrdenie vyžaduje odkaz · M11 0 € odmietnutá ·
   M12 bez echa R12 · M13 `patch_record` bez reconcile · M14 `save_decor` formát nezneplatní · M15 kód-only Demos apply nechá ručný dátum · M16 Demos apply zmaže
   `product_url` · M17 normalize nechá `manual` pri Demos väzbe · M18 JS povolí potvrdenie pred odpoveďou o otvorení (s odkazom) · M19 JS cudzí token vlastní modal · M20 formulár ceruzky pri Demos položke nezruší dátum pri zmene
   ceny (R13b) · M21 JS po neúspešnom otvorení prehliadača potvrdenie zablokuje (B1) · M22 formulár variantu kontroluje revíziu mimo zámku / echo omladí baseline
   (R6b/R6c) · M23 „bez zmeny" cez interval ±0,005 (R11a) · M24 prepnutie jednotky prepočíta zobrazený text (R20b).
7. **Celá headless sada** (`ruby tests/run_all.rb`) + **všetky JS sady** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) zelené; encoding guard.

## 8 · In-SU test — **nie je brána mergu**

Spúšťače z CLAUDE.md: buildery, observery, undo a operácie, geometria, akcie panela zapisujúce do modelu. Nové akcie (`mat_product_open`, `mat_manual_*`, formulár
variantu) zapisujú **výhradne** globálny katalóg `%APPDATA%\NOXUN\Engine\materials.json` cez JsonFileStore pod `with_catalog_lock` — žiadna `start_operation`, žiadny
zápis do entít, žiadny observer ani Späť; `after_catalog_change` len obnovuje UI a cache (`EdgeCheck.invalidate!`). Headless sada pokryje server aj kanál (vzor
`test_d134_rozsah_zapisov.rb` — MaterialsDialog so stubmi, `UI.openURL` stub). Existujúci in-SU test katalógu (`su_runner.rb` test 11) posiela `SCHEMA_CURRENT` →
bump ho nerozbije. **Odporúčanie (nie brána):** ak je SketchUp voľný, pred PR jeden beh `scripts\run_su_tests.ps1 -CloseWhenDone` ako dymová kontrola; PR uvedie hlavu.

## 9 · Riziká

- **Starší plugin / druhé PC:** prvé uloženie odkazu [A] / overenia [B] prepne katalóg staršiemu pluginu do režimu len na čítanie (S15). Týka sa prenosu `materials.json`
  alebo iného SketchUpu so starším pluginom na tom istom PC. Zmierniť: STAV/PR/report „aktualizovať obe PC pred prvým použitím".
- **Marker neklesá:** skúšobné vloženie a zmazanie odkazu nechá katalóg na 11 — vedomé, zapísané v STANDARD.
- **Presná €/m² (O7):** v JSON pribudnú dlhé desatinné čísla (bezstratové — S12); zobrazenie a echo (R12, R21) musia sedieť, inak by „nezmenený" formulár cenu posunul
  o cent (S10). Test mriežky + echo matica.
- **Rozptýlené zneplatnenie:** ~6 ciest (S9) — jedna funkcia R13 + matica testov + mutácie M13/M14; nová cesta v budúcnosti musí volať R13 (napísať do materials.md).
- **Súbeh s Demos lookup-om:** lookup beží s `catalog_rev` a baseline `row_rev`; potvrdenie medzitým spôsobí `:stale_catalog`/`:conflict` pri apply — bezpečný smer.
- **Dátum v UTC** (`Time.now.utc.iso8601`, `mdDateLabel` číta dátumovú časť): potvrdenie po polnoci miestneho času ukáže predošlý deň — rovnako ako kovanie (§13 F5).

## 10 · Smoke checklist pre Michala (po slovensky, funkčne)

**M1a · odkaz (v0.16.1)** — najprv aktualizuj plugin na **oboch** PC.
1. Štúdio → Materiály → otvor dekor, kde je doska alebo páska **bez Demosu** (napr. DTDL 25 z Drevocentra): vpravo v riadku je **jantárová** ikona odkazu; stĺpce kód,
   cena, dodávateľ sú pod sebou aj v riadkoch s Demosom.
2. Klik na jantárovú ikonu → otvorí sa úprava (ceruzka) s kurzorom v poli „Odkaz na produkt". Vlož adresu obchodu a ulož → ikona zosivie; klik na ňu otvorí obchod
   v prehliadači a **nič sa nezmení** (cena, dátum).
3. Vlož zlú adresu (bez http/https alebo s medzerou) → formulár ostane otvorený s hláškou, nič sa neuloží.
4. Otvor ceruzku pri **Demos** položke → pole odkazu je zamknuté s vysvetlením. Vymaž Demos URL → pole sa odomkne.
5. UNI a duplák ikonu odkazu nemajú. Rozpočet vyzerá ako predtým.

**M1b · ručné overenie (v0.16.2)** — znova aktualizuj **obe** PC.
6. Pri položke bez Demosu je druhá ikona **„Overiť cenu"** — jantárová; tooltip „Cena nebola nikdy ručne overená — na kontrolu".
7. Klik → otvorí sa obchod aj formulár. Doska: cena **za platňu** (napr. 179,90) → vedľa prepočet na €/m²; „Potvrdiť cenu k dnešku" → ikona zosivie, tooltip
   „Cena ručne overená 30.9.2026 (dnes)". Rozpočet zákazky s touto doskou ukáže za platňu **presne 179,90 €**.
8. Sklo bez odkazu a bez formátu → formulár sa otvorí **bez prehliadača**, cena **za m²**; potvrď. ABS páska → cena za bm.
9. Potvrď **0 €** → prejde s vetou „materiál sa do rozpočtu započíta nulou".
10. Prepíš cenu v bunke (alebo kód, dodávateľa; v ceruzke odkaz alebo formát) → ikona overenia zožltne a status povie, že ručné overenie sa zrušilo. Názov, farba ani
    vzhľad overenie nezrušia.
11. Bunka ceny ukazuje 2 desatinné; klik do bunky a von bez zmeny nič nezmení (ikona ostane sivá).
12. Ručne overenú položku napoj na Demos (Aktualizovať z Demosu alebo Demos URL v ceruzke) → ukazuje sa Demos ikona, ručné overenie zmizlo. Vymaž Demos URL → vráti sa
    tvoj ručný odkaz, overenie ostane jantárové (treba overiť znova).
13. Pri **Demos** položke prepíš v ceruzke cenu a ulož → status povie, že dátum overenia z Demosu sa zrušil (D-148); „Prepočítať ceny" ju znova overí.
14. Rozpočet: stĺpec „Overená" a čip ostávajú ako doteraz — ručné ceny tam pribudnú v M2.

## 11 · Checklist uzáveru (každá z M1a / M1b)

Bump VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + všetky `?v=` · headless + všetky JS sady zelené · `MD_CLIENT_SCHEMA` = `SCHEMA_CURRENT` · STANDARD §7.1 ·
`materials.md` a `ui-lifecycle.md` odseky na mieste · **prepis STAV** (verzia, riadok „aktualizovať obe PC pred prvým uložením odkazu / ručného overenia — starší
plugin katalóg materiálov potom len číta") · KRONIKA odsek navrch · PLAN riadok dávky ✅ + PR · DOGFOODING „V1 DOTIAHNUTIE" — len riadok *Stav* (vyriešené až po M2) · [B] **D-148** do `DOGFOODING_vyriesene.md` (plný text + riadok indexu) ·
package + surový audit do `SYSTEM/zdroje/bloky/CENY/` · PR popis: čo sa mení pre používateľa, sekcia „Predrecenzia", brána in-SU „nie je (§8)", Lucia/obe PC.

## 12 · Rozhodnutia autora package (bezpečnejšia vratná voľba) — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | Odkaz **http aj https** (ako kovanie) | schválený mockup C1 má text „Adresa musí začínať http:// alebo https://" a validáciu `https?`; C6 „rovnaký vzor ako kovanie"; plugin odkaz nikdy nesťahuje ani neparsuje, len `UI.openURL` v externom prehliadači. Pôvodný koncept (debata 6.9.) chcel len https — ak orchestrátor chce len https, je to jedna podmienka v R4 + text C1; sprísnenie **pred** prvým releasom je vratné, po ňom by uložené http odkazy stratili platnosť | **áno** (zadanie tvrdí, že Michal nerozhodoval) |
| D2 | Rez M1a (SCHEMA 11) → M1b (SCHEMA 12) | odhad ~940 riadkov; dve schémy bránia tomu, aby plugin M1a editoval katalóg z M1b bez pravidiel zneplatnenia | **áno** (rozhoduje orchestrátor) |
| D3 | Cena za platňu sa na serveri zaokrúhli na centy **pred** delením plochou | Rozpočet potom ukáže presne zadané centy (invariant testovateľný); €/m² ostáva nezaokrúhlená (O7) | nie |
| D4 | ~~Echo ±0,005 €~~ → **presná zhoda so zobrazenou hodnotou servera** (R11a, audit BLOCKER) | „cena sedí" = bitovo rovnaká cena, len dátum; zobrazenie na 2 desatinné nič neposunie | nie |
| D5 | Zmena `supplier_decor` zruší aj ručné overenie | dnes ruší Demos dátum (S9); invariant „metóda nežije bez svojho dátumu"; smer = položka ide na kontrolu. O6 ho výslovne neuvádza | krátko |
| D6 | Nezneplatňuje: názov, farba, vzhľad, smer, `cp_nazov`, `pd_edge_subtype`, výrobca, premenovanie dekoru | O6 „Názov, farba, smer dekoru nie" | nie |
| D7 | Formulár strhne od klienta aj `price_checked_at` | dnešná medzera S8/T20; náš JS ho neposiela → bez zmeny správania | nie |
| D8 | Vek = 24 h `floor` (ako Rozpočet), vek 0 → „(dnes)" | jedna autorita s M2; mockup počítal kalendárne dni | nie |
| D9 | Platné ručné overenie nevyžaduje odkaz | O9 (kovanie ho vyžaduje) | nie |
| D10 | Model guard na `mat_manual_*` (DocKey) aj keď je katalóg globálny | vzor kovania; M2 bude volať z Rozpočtu (per zákazka) | nie |
| D11 | Lokálna kópia sanitizéra + parity test (nie volanie `HardwareCatalog`, nie nový modul) | normalize nesmie závisieť od poradia načítania; nový modul = ďalší audit a rozcestník | nie |
| D12 | Akcie s predponou `mat_` | spoločný priestor mien callbackov Štúdia (`hw_manual_*` už existujú) | nie |
| D13 | ABS: prefill presná hodnota, bez zaokrúhlenia a bez echa | €/bm sa neprepočítava; zaokrúhlený prefill by pri „cena sedí" cenu zmenil | nie |
| D14 | Hint Demos zámku navyše „Uložený ručný odkaz sa po zrušení väzby vráti." (keď existuje) | O8 „odložený" odkaz inak nie je vidieť | nie |

## 13 · Nálezy mimo scope (návrhy D-čísel)

- **F1** — formulár ceruzky dnes **nezruší Demos `price_checked_at`** pri zmene ceny, kódu ani dodávateľa (S9/T9h, T9j) — ručne prepísaná Demos cena ostáva „overená"
  a Rozpočet ju berie ako čerstvú. **Rozhodnutie orchestrátora 30.9.: zaradené do M1b ako R13b, D-148** (cenová oprava v tej istej ceste zneplatnenia).
- **F2** — FAKTY §2 „`price_checked_at` zapisuje len Demos cesta" neplatí pre formulár (S8/T20); M1a to opraví strhávaním (R6), fakty ostanú historické.
- **F3** — v kóde sú tri takmer rovnaké http(s) sanitizéry (`BudgetStore.sanitize_url`, `HardwareCatalog.sanitize_product_url`, nový `Materials.sanitize_product_url`);
  zjednotiť neskôr jedným modulom.
- **F4** — kovanie pri napojení na Demos `product_url` maže (`apply_price_proposal!`), materiály ho odkladajú (O8) — dva katalógy, dve pravidlá; zvážiť zjednotenie kovania.
- **F5** — dátum ručného overenia je v UTC; po polnoci miestneho času tooltip ukáže predošlý deň (kovanie rovnako).
