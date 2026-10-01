# PACKAGE H14 · Sekcie Štúdia na jednom mieste (C-02) — blok 9 HARDENING PO V1

> **Autorita:** triedenie Michala 1.10.2026 (`ROZHODNUTIA_MICHALA_2026-10-01.md`: C-02 = CX-04 · CX-05 · GR-06, **Teraz**); blok 9 (`SYSTEM/PLAN.md`,
> riadok H14): **bez zmeny výrobných a cenových čísel**, UI zmeny nič nepočítajú. Dôkazy: `CROSS_AUDIT_A1_CODEX_ASTRA.md` CX-04 (dve cesty prepnutia),
> CX-05 (5+ miest evidencie), `CROSS_AUDIT_A2_GROK.md` GR-06 (zoznam 3×, telo = reťaz podmienok, testy s vlepeným zoznamom). Čísla riadkov v auditoch sú
> staršie — nižšie sú **prepočítané na dnešný main**.
> **Trieda (§5):** **audit-povinná ÁNO** (nový modul `ui/js/studio_sections.js` + kontrakt registra, ktorý číta 10 súborov; H14b mení tok prepínania sekcie) ·
> **výrobná/cenová NIE** · **predrecenzia povinná** H14a aj H14b · **in-SU nie je brána** (žiadny Ruby spúšťač) · fotky okien `-Shoot` povinné · `codex-po-pr` bez výnimky.
> **Bez viditeľnej zmeny:** navigácia, poradie, ikony, nadpisy, nápovedy, hlášky, správanie sekcií a payloady bajtovo rovnaké (golden T0 PRED zásahom).
> **Verzia:** každá časť = patch podľa mainu pri štarte (dnes `0.17.13`) + všetky `?v=` (aj nové značky skriptu) + prepis STAV.
> **Stav kódu:** sonda nad `main` **`5f787035`** (v0.17.13, po PR #448).

---

## 0 · Sonda na kóde (headless, 1.10.2026)

Skripty `scratchpad/HARDENING/sonda_h14.rb` (Ruby 3.2 cez `tests/helper.rb`, APPDATA = sandbox), `sonda_h14_js.js` (node, `vm` nad skriptami `studio.html`
v poradí HTML, špehovanie globálov), `sonda_h14_scan.rb` (sken výskytov id) a `sonda_h14_vm.js`. Do modelu ani do repa sa nič nezapisovalo.

| # | Tvrdenie o dnešnom kóde | Dôkaz | Verdikt |
|---|---|---|---|
| S1 | `StudioDialog::SECTIONS` = 14 id (`bom ctrl buy budget offer cut mat hw appl rules tpl sup bset about`), zmrazené; `show` aj `consume_pending_section` púšťajú len známe id, deep-link sa spotrebuje práve raz | `studio_dialog.rb:55`, `:139`, `:1765-1769`; sonda S1/S2 | PRAVDA |
| S2 | **Ruby nepozná názov, ikonu ani skupinu žiadnej sekcie** — zhody textov sú náhodné (hárky XLSX „Rozpočet"/„Cenová ponuka", kategória „Kovanie", položky menu „Šablóny", „Nastavenia rozpočtu"); ostatné položky menu majú iné, historické mená („Pravidlá kovania", „Materiály projektu", „Katalóg kovania") | sonda S5, Grep | PRAVDA → prezentácia je čisto klientska |
| S3 | Ruby literály sekcií: `open_section:` 6× (`main.rb:637`, `:640`, `:643`, `:646`, `:649`, `materials_dialog.rb:1057`) + `ProductionCore::ROUTE_SECTIONS = { 'appl' => 'appl' }` (`production_core.rb:2394`) — všetky známe | sonda S3/S4 | PRAVDA |
| S4 | `scripts/ui_foto/shots.json`: 14 fotiek Štúdia = `SECTIONS` v poradí, popisy = názvy navigácie („Štúdio · Kusovník" …); `record.rb:145-146` berie zoznam z `SECTIONS` | sonda S6 | PRAVDA |
| S5 | **Navigácia sa pred prvým payloadom nekreslí** (`#snav` prázdny, `studio.html:920`); `render()` volajú len `NX.setStudio` (`studio.js:1300`) a `studioGoSection` (`:2211`) | sonda J1, Grep | PRAVDA → fallback pred payloadom netreba |
| S6 | Všetkých 24 háčikov sekcií (18 renderov lišty/tela + `hwProductContextChanged`, `mdManualContextChanged`, 3× `*OnLeaveSection`, `ssOnAboutEnter`) sú top-level `function` = globály okna; `studio.js` ich hľadá `typeof x === 'function'` **v čase volania** | sonda J2, Grep deklarácií | PRAVDA |
| S7 | **Dve cesty prechodu volajú háčiky v rovnakom poradí** — navigácia (`studioGoSection`, `:2179-2212`) aj deep-link (`setStudio`, `:1226-1299`): kontext kovania → kontext materiálu → zhasnutie menu → odchod zo starej sekcie → vstup do novej; **196/196 dvojíc zhodných**, prechod na tú istú sekciu = žiadny háčik | sonda J4 | PRAVDA → zjednotenie je bezpečné |
| S8 | Rozdiel ciest: deep-link navyše spracuje **kotvu** — `bom` (text hľadania) a `mat` (detail dekoru) **pred** renderom, `budget` a `appl` (riadok) **po** renderi — a render volá až po kotvách | `studio.js:1266-1306` | PRAVDA → kotvy ostávajú len v deep-linku (CX-04) |
| S9 | Neznáma sekcia: navigácia aj deep-link ju ignorujú (sekcia ostáva); Inspector `NXShell.studioSection` vráti `null` | sonda J5, `shell.js:351-361` | PRAVDA |
| S10 | `SEC_META` 14 kľúčov (poradie `rules`/`hw` iné — lookup, nevadí); NAV ids = `SECTIONS`; tooltip navigácie navyše **len `cut`** (iný text než nápoveda hlavičky); badge `ctrl: true` (→ `ST.counts`), `appl: 'appl'` (→ `ST.appl.job.counts`, `navCounts` `:669-673`) | sonda J6 | PRAVDA |
| S11 | `REFRESH_STATUS` (`:1978-1994`) má 8 kľúčov; inak „Prepočítavam kusovník…". **Šablóny majú „Obnoviť"** (`#refreshBtn`, `templates.js:191-194`), ale hlášku nie → pri klepnutí hlási „Prepočítavam kusovník…" | čítanie kódu (klik v okne NEOVERENÝ) | PRAVDA → **F1 / Q1** |
| S12 | Tretí JS zoznam: `studio_settings.js:41` `SS_SECTIONS = ['sup','bset','about']` (`ssActive` `:48-53`) | sonda J7 | PRAVDA |
| S13 | Top-level `var`/`function` zo `studio.js` sú vo `vm` vlastnosti globálu (`studioSec`, `vepoMenuOpen`, `bomQ`), `globalThis[meno]` vidí náhradu špehom (aj v Node `global`) | sonda V1–V3 | PRAVDA → golden harness funguje pred aj po zmene |
| S14 | 48 JS sád berie `studio.js` cez Node `require` (bez zmeny — `studio.js` si register vyžiada sám); **8 sád ho púšťa cez `vm`** zoznamom súborov (`test_ceny_kov_budget_links.js:22`, `test_ceny_m2_budget.js:40`, `test_h3_zobrazenie.js:390`, `test_h4a_format.js:140`, `test_np4_ceny.js:55`, `test_r14_budget_std.js:56`, `test_st1c_ponuka.js:124`, `test_st1c_rozpocet.js:58`); `h12_harness.js` číta zoznam skriptov z HTML | Grep | PRAVDA → 8 sád dostane register do zoznamu |
| S15 | Headless `push_state` sa dá spustiť so stubmi (vzor `NxNp3Push`, `test_np3_sekcia.rb:539-604`) → odtlačok kľúčov payloadu bez SketchUpu | čítanie testu | PRAVDA |
| S16 | Sken id: polia s ≥2 id **6×** (`shell.js:349`, `studio.js:64`, `:94`, `:114`, `:136`, `studio_settings.js:41`), mapa s ≥3 kľúčmi id **1×** (`studio.js:1978`), Ruby **1×** (`studio_dialog.rb:55`); porovnaní aktívnej sekcie s literálom **≈ 50 v `studio.js`** (dispatch, prechody, kotvy, 4× ozvena Kontroly) a **26 v 8 sekčných súboroch** (modul sa pýta na vlastnú sekciu; `budget.js:526`, `:1422` = sekcia **rozpočtu** `appl`, nie Štúdia); literálových volaní `studioGoSection`/`openStudio`/`ssLinkBtn` **21** — všetky známe | `sonda_h14_scan.rb` | PRAVDA → základ guardov §6 R5 |

### 0.1 Súpis — kde sa sekcia Štúdia prihlasuje alebo kde sa podľa id vetví

Stĺpec **Druh**: `D` = dátum sekcie (id, názov, ikona, poradie, skupina, texty) · `L` = logika (vetva, háčik) · `U` = použitie id (volanie, nie prihlásenie).

| # | Súbor:riadok | Čo tam je | Druh | Po H14 |
|---|---|---|---|---|
| 1 | `ui/studio_dialog.rb:55` | `SECTIONS` (serverový whitelist, poradie) | D | **ostáva** (bezpečnostná hranica) + parita s registrom cez fixtúru |
| 2 | `ui/studio_dialog.rb:1631-1717` | `push_state` — kľúče payloadu sekcií (`rows`, `control`, `budget`, `sheet_layout`, `mat`, `hw`, `appl`, `rules`, `tpl`, `settings`) | L | ostáva explicitné; register nesie `data` + guard (R4.4) |
| 3 | `ui/studio_dialog.rb:1384-1484`, `:1357-1378`, `:252-256` | callbacky sekcií (`*_actions`), `on_ui_closed`, záklopky `@mat/@hw_full_pending` | L | ostáva (CX-05: serverové oprávnenia explicitné) |
| 4 | `main.rb:637-649`, `materials_dialog.rb:1057`, `production_core.rb:2394` | menu deep-linky, „Nahradiť UNI…", `ROUTE_SECTIONS` | U | ostáva + guard „id je známe" |
| 5 | `ui/js/studio.js:64` | `STUDIO_SECTIONS` | D | **zaniká** (H14a) |
| 6 | `ui/js/studio.js:93-146` | `NAV` (skupina, id, ikona, názov, tooltip `cut`, badge) | D | **zaniká** → register (H14a) |
| 7 | `ui/js/studio.js:148-186` | `SEC_META` (nadpis + nápoveda hlavičky) | D | **zaniká** → register (H14a) |
| 8 | `ui/js/studio.js:1978-1994` | `REFRESH_STATUS` | D | **zaniká** → register `refresh` (H14a) |
| 9 | `ui/js/studio.js:669-673` | `navCounts` (zdroj badge) | L | číta `badge` z registra (H14a) |
| 10 | `ui/js/shell.js:349-360` | `STUDIO_SECTIONS` + `studioSection` (filter deep-linku Inspectora) | D | **zaniká** → `NXStudioSections.has` (H14a) |
| 11 | `ui/js/studio_settings.js:41`, `:48-53` | `SS_SECTIONS` + `ssActive` | D | **zaniká** → `inModule('studio_settings.js')` (H14a) |
| 12 | `ui/js/studio.js:1414-1520` | `renderTools` — 11 vetiev podľa id | L | **dispatch z registra** (H14b) |
| 13 | `ui/js/studio.js:1626-1704` | `renderBody` — 11 vetiev + núdzové texty | L | **dispatch z registra** (H14b) |
| 14 | `ui/js/studio.js:2179-2212` | `studioGoSection` — odchod `mat/hw/appl`, vstup `about` | L | **jedna funkcia prechodu** (H14b) |
| 15 | `ui/js/studio.js:1226-1265` | deep-link v `setStudio` — tie isté háčiky druhýkrát | L | **tá istá funkcia** (H14b) |
| 16 | `ui/js/studio.js:1266-1306` | kotvy `bom`/`mat` (pred renderom), `budget`/`appl` (po ňom) | L | register `anchor` (H14b) |
| 17 | `ui/studio.html:1321-1391` | `<script>` sekčných modulov + komentáre poradia | L | ostáva; **nový tag `studio_sections.js` pred `studio.js`** |
| 18 | `ui/panel.html:1115` | `shell.js` (filter deep-linku) | L | **nový tag `studio_sections.js` pred `shell.js`** |
| 19 | `ui/js/icons.js` (14 symbolov navigácie) · `docs/UI_DIZAJN.md:315-319` | sprite + inventár ikon navigácie | D | ostáva; guard číta ikony z registra |
| 20 | `scripts/ui_foto/shots.json` | 14 fotiek Štúdia + popisy | D | ostáva; guard popis = „Štúdio · " + názov z fixtúry |
| 21 | 8 sekčných JS (`appliances.js:89-91`, `budget.js:418-420`, `hw_catalog.js:1255`, `:1278`, `:1295`, `md_appearance.js:21`, `:75`, `:134`, `:162`, `proj_materials.js:2026`, `sheet_layout.js:507`, `studio_settings.js:461`, `:511`, `:640-643`, `:658`, `:847`, `templates.js:57-59`) | modul sa pýta „som otvorený?" / vetví vlastné sekcie | L | **ostáva** (vlastná sekcia modulu — nie prihlásenie, D9) |
| 22 | 21 literálových volaní (§0 S16) | `studioGoSection('budget')`, `openStudio('mat', …)`, `ssLinkBtn(bar, 'bset', …)`, `panel.html:216`, `:431`, `:788`, `:793` | U | ostáva + guard „id je známe" |

**Súčet:** **13 miest prihlásenia v kóde pluginu** (Ruby 1 + JS 12: 6 zoznamov/máp, `navCounts`, 2 reťaze dispatchu, 2 cesty prechodu, blok kotiev — riadky 1, 5–16) + `studio.html` + `shots.json` + **21 testových súborov s textovou kópiou zoznamu, riadka NAV alebo vetvy** (§7 T4). Po H14: nová sekcia =
riadok registra + id v `SECTIONS` + riadok fixtúry + modul sekcie (+ tag, kľúč payloadu, callbacky, fotka) — centrálny dispatch sa nemení a zabudnuté miesto zhodí test.

### 0.2 Testy, ktoré dnes pripínajú zoznam alebo vetvu **textom zdroja** (prepíšu sa, §7 T4)

**Ruby (15):** `test_st1a_studio.rb:41-51`, `:942-951`, `:955-960`, `:993`, `:1056-1068` · `test_st1b_kontrola.rb:44-53`, `:67`, `:336-338` · `test_st1c_nakup.rb:52-53`, `:102` ·
`test_st1c_ponuka.rb:44-47`, `:53-55` · `test_st1c_rozpocet.rb:56-58`, `:71-75` · `test_st2a_mat.rb:52-54`, `:66` · `test_st2d_kde.rb:301-305` · `test_st3a_hw.rb:59-61`, `:73-78`, `:584-605` ·
`test_st3b_rules.rb:46-48`, `:66`, `:289-292` · `test_st3c_tpl.rb:46-49`, `:70` · `test_st4a_nastavenia.rb:237-243` · `test_s1a2_sekcia.rb:55-60`, `:63-75`, `:77-84` ·
`test_uid3_klikatelnost.rb:252-255` · `test_h4b_texty_vzhlad.rb:166-176` · `test_d52b_updater_ui.rb:1104-1105` (počet `ssOnAboutEnter()` = 2).
**JS (6):** `test_st1a_studio.js:45`, `:171-220` · `test_st1b_kontrola.js:130-133` · `test_uid3_klikatelnost.js:100-101` · `test_h4b_texty_vzhlad.js:238-243` · `test_s1b2_pohlad.js:498` ·
`test_st2a_mat.js:281-318` (počet `matOnLeaveSection()` = 2).
**Bez zmeny:** `test_ui_foto.rb:28` (číta Ruby `SECTIONS`, tá ostáva), `su_runner.rb:16772` (Ruby zoznam), testy menu `main.rb` (`test_st2a_mat.rb:91` …), čítanie tela `show` (`test_d52a_updater.rb:1536`, `test_kova2b_smer_overlay.rb:514`).

### 0.3 Návrh registra — riadky (hodnoty = dnešný kód, doslovne)

Skupiny v poradí: `job` „ZÁKAZKA" · `catalogs` „KATALÓGY" · `settings` „NASTAVENIA". Nápoveda hlavičky (`head`) = doslovne `studio.js:149-185`; núdzový text tela (`missing`) =
doslovne `:1635-1696`; hlášky kotiev = doslovne `:1281`, `:1302`, `:1305`. Kľúče `id`, `ic`, `t`, `hint`, `badge`, `disabled` majú **tvar dnešnej položky NAV** (menej prepisov testov).

| id | grp | ic | t | hint (tooltip nav.) | badge | refresh (hláška „Obnoviť") | module | data | tools · body (H14b) | stale | leave / enter | anchor (H14b) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| bom | job | list | Kusovník | — | — | — (predvolená) | studio.js | rows | `bomRenderTools` · `bomRenderBody` (nové, z dnešného kódu) | — | — | `bomOpenAnchor`, pred, bez hlášky |
| ctrl | job | clipboard-check | Kontrola | — | `ctrl` (dnes `true`) | Prepočítavam kontrolu… | studio.js | control | `ctrlRenderTools` · `ctrlRenderBody` | — | — | — |
| buy | job | cart | Nákup kovania | — | — | Prepočítavam nákupný zoznam… | studio.js | hardware_sets | `buyRenderTools` · `buyRenderBody` | — | — | — |
| budget | job | euro | Rozpočet | — | — | Prepočítavam rozpočet… | budget.js | budget | `budRenderTools` · `budRenderBody` | nie | — | `budOpenAnchor`, po |
| offer | job | file-text | Cenová ponuka | — | — | Prepočítavam cenovú ponuku… | budget.js | budget | `budRenderOfferTools` · `budRenderOfferBody` | nie | — | — |
| cut | job | scissors | Nárezový plán | koľko platní stačí pri tomto rozložení (horná hranica) | — | Prepočítavam nárezový plán… | sheet_layout.js | sheet_layout | `npRenderTools` · `npRenderBody` | áno | — | — |
| mat | catalogs | layers | Materiály | — | — | Prepočítavam použitie dekorov v projekte… | proj_materials.js | mat | `matRenderTools` · `matRenderBody` | áno | `matOnLeaveSection` / — | `matOpenAnchor`, pred |
| hw | catalogs | hammer | Kovanie | — | — | Načítavam čerstvý katalóg kovania a sety… | hw_catalog.js | hw | `hwRenderTools` · `hwRenderBody` | áno | `hwOnLeaveSection` / — | — |
| appl | catalogs | appliance | Spotrebiče | — | `appl` | — | appliances.js | appl | `apRenderTools` · `apRenderBody` | nie | `apOnLeaveSection` / — | `apOpenAnchor`, po |
| rules | catalogs | settings | Pravidlá | — | — | Načítavam pravidlá z aktuálneho modelu… | rules.js | rules | `rulesRenderTools` · `rulesRenderBody` | áno | — | — |
| tpl | catalogs | star | Šablóny | — | — | — (predvolená — **F1**) | templates.js | tpl | `tplRenderTools` · `tplRenderBody` | áno | — | — |
| sup | settings | truck | Dodávateľ / Demos | — | — | — | studio_settings.js | settings | `ssRenderTools` · `ssRenderBody` | nie | — | — |
| bset | settings | sliders-horizontal | Nastavenia rozpočtu | — | — | — | studio_settings.js | settings | `ssRenderTools` · `ssRenderBody` | nie | — | — |
| about | settings | info | O plugine | — | — | — | studio_settings.js | settings | `ssRenderTools` · `ssRenderBody` | nie | — / `ssOnAboutEnter` | — |

`stale` = lišta dostane `staleFlag` ako argument (dnes `mat`, `hw`, `rules`, `tpl`, `cut`); ostatné sa volajú bez argumentu (`budget`, `offer`, `appl`, `ss*`). `bom`/`ctrl`/`buy`
kreslí `studio.js` — `stale` sa číta vnútri (dnešný kód). Predvolená hláška obnovenia `REFRESH_DEFAULT` = „Prepočítavam kusovník…".

---

## 1 · Cieľ

Sekcia Štúdia sa prihlási **na jednom mieste** — riadkom registra `NXStudioSections`, z ktorého navigácia, hlavička sekcie, hláška „Obnoviť", filter deep-linku
v Inspectore, kreslenie lišty a tela aj prechod medzi sekciami berú svoje údaje. Prechod medzi sekciami má **jednu cestu** pre klik aj odkaz z Inspectora.
Ďalšia sekcia (výkresy, etikety…) = riadok registra + id v serverovom whiteliste + vlastný modul, **nie 13 miest v 4 súboroch**; zabudnutý krok zhodí test.
**Pre používateľa sa nemení nič:** rovnaká navigácia, poradie, ikony, nadpisy, nápovedy, hlášky, prepínanie, deep-linky aj čísla.

## 2 · Rez a odhad — **dve časti, sekvenčne z čerstvého `main`, každá samostatný PR**

| Časť | Obsah | Kód pluginu (+/−) | Testy | In-SU | Odhad |
|---|---|---|---|---|---|
| **H14a · register a zoznamy (CX-05)** | T0 golden PRED zásahom (1. commit, G1–G10 + T0b) → `ui/js/studio_sections.js` → `studio.js` (`STUDIO_SECTIONS`, `NAV`, `SEC_META`, `REFRESH_STATUS`, `navItem`, `renderNav`, `renderHead`, `navCounts`, whitelist v `studioGoSection` a deep-linku) · `shell.js` · `studio_settings.js` · 2 HTML tagy · parita Ruby↔JS · prepis testov zoznamov | ~+130 / −150 (+ mechanické `?v=`) | ~550 | nie | ¾ dňa |
| **H14b · jedna cesta a dispatch (CX-04 + GR-06 klient)** | `studioSwitchSection` pre navigáciu aj deep-link · kotvy z registra · `renderTools`/`renderBody` z registra · `bom`/`ctrl`/`buy` ako pomenované háčiky · guard „žiadna nová vetva podľa id" · prepis testov vetiev | ~+180 / −290 (net −110) | ~300 | nie | ¾–1 deň |

Každá časť sama osebe dá bajtovo rovnaké výstupy (T0 platí po každej, **bez regenerácie**). Spolu > 400 riadkov zmien → preto dve časti. **Audit návrhu jeden pre celý
package** (pred H14a); časť, ktorá zmení kontrakt registra z §6, ide na deltu.

## 3 · Scope IN

1. **Register** `noxun_engine/ui/js/studio_sections.js` (§0.3, R1) — načítajú ho `studio.html` aj `panel.html`.
2. **H14a:** miesta §0.1 č. 5–11 z registra; Ruby `SECTIONS` ostáva (komentár `studio_dialog.rb:39-55` → „parita cez fixtúru"). **H14b:** miesta č. 12–16.
3. Fixtúra kontraktu `tests/fixtures/h14_studio_sections.json` (most Ruby↔JS, vzor `h12_cabinet_types.json`), golden T0, guardy R5, mutácie, fotky, dokumentácia §11.

## 4 · Scope OUT

- **Obsah sekcií, výpočty, exporty, payload `NX.setStudio` a `NX.init`** — nič sa nemení (T0b to dokazuje). Žiadny nový kľúč payloadu.
- **Ruby `push_state` a callbacky sa neregistrujú automaticky** (CX-05 vs GR-06 — rozhodnutie D6): skladanie payloadu ostáva explicitné, jeden spoločný push
  počíta všetky sekcie naraz ako dnes; register len deklaruje kľúč `data` a guard overí, že v pushi je.
- Poradie a zoskupenie navigácie, texty, ikony, `#nxModalRoot`/`#matModalRoot`/`#hwModalRoot`, poradie `<script>` sekčných modulov, obaľovanie `NX.setStudio` modulmi.
- Kontroly „som otvorená sekcia?" vnútri sekčných modulov (§0.1 č. 21) a ozvena Kontroly `if (studioSec === 'ctrl') renderTools();` ×4 (`studio.js:1339-1363`).
- Položky menu v `main.rb` a ich historické mená (F3), `ROUTE_SECTIONS`, `UI20_KONTRAKT.md`.
- Oprava hlášky „Obnoviť" v Šablónach (F1) — len ak ju Michal povolí (Q1).

## 5 · Trieda podľa CLAUDE.md

- **Výrobná/cenová: NIE.** Hranice B-09: mení sa navigácia, ikona, rozloženie a kód prepínania — žiadny vzorec, rozmer, počet, hrana, `row_key`, export ani číslo,
  podľa ktorého sa objednáva či cenotvorí. Dôkaz: T0b (kľúče a bajty payloadu Štúdia), sekcie Rozpočet, Ponuka, Nákup a Nárezový plán kreslí ten istý kód z tých istých dát.
- **Audit-povinná: ÁNO** — nový modul (`studio_sections.js`, nový riadok v `ARCHITEKTURA.md`) + kontrakt registra (kľúče riadka, mená háčikov, `data`), ktorý číta
  10 súborov; H14b mení tok prepnutia sekcie. Jeden audit pre celý package (pred H14a).
- **Predrecenzia: povinná** H14a aj H14b (audit-povinná trieda; H14b navyše > 300 riadkov).
- **In-SU: nie je brána.** Ruby sa mení len komentárom a verziou; žiadny builder, observer, undo, geometria ani akcia panela zapisujúca do modelu. Štúdio cez tento
  zásah do modelu nezapisuje (zápisové akcie sekcií — rozpočet, materiály, šablóny — sa nedotýkajú, mení sa len to, ako sa sekcia otvorí a nakreslí).
- **Nový ovládací prvok: NIE.** **Fotky okien: povinné** `scripts\ui_foto.ps1 -Shoot` pred a po každej časti (payload sa nemení → `-Record` netreba).

### 5.1 Závislosti — overiť proti mainu pred každou časťou

- **H13** (mapa rozširovacích bodov) beží paralelne: ak zmerguje skôr a `docs/architecture/rozsirovacie-body.md` má riadok „nová sekcia Štúdia", H14a ho **prepíše na
  register** (§14); ak neskôr, orchestrátor dá H13 vedieť, že H14 mení zoznam miest.
- **H7** (názov zákazky na jednom mieste, mockup) môže meniť lištu Kusovníka (`bomToolsHtml`, `renderTools`) → pri štarte H14b prepočítať §0.1 č. 12–13 a prevziať jeho verziu.
- **H6** mení Inspector (`panel.html`) — kolízia len v tagu skriptu (H14a) a v `?v=`.

## 6 · Požiadavky

### R0 · Charakterizácia PRED zásahom (1. commit H14a, bez zmeny pluginu)

- **R0.1** Harness `tests/js/h14_harness.js` (nie sada; vzor `h12_harness.js`): načíta skripty `studio.html` v poradí HTML do jedného `vm` kontextu, pred nimi nastaví
  `NX_FIT_MIN`, `NX_MAT_SECTION`, `NX_HW_SECTION`, `localStorage` stub; pevný payload (`model_title: 'GOLDEN'`, `version: '0.0.0-golden'`, `counts {red 2, orange 3}`,
  `appl.job.counts {orange 5}`, malé `rows`/`control`/`hardware_sets`); **špehy** nahradia 24 globálnych háčikov (S6) a zapisujú volania s argumentmi.
  **(§15 A2, A4, A5)** Harness navyše: **zachytáva listenery** `document.addEventListener` (vzor `test_st1a_studio.js`, `LISTEN[type]`) a vie vystreliť klik
  s cieľom `closest`; `localStorage` je **záznamový stub** (čítania aj zápisy); uzly počítajú zápisy `innerHTML` (počet renderov). **Špeh pri každom volaní zapíše aj
  stav v okamihu volania:** `studioActiveSection()`, `vepoMenuOpen`/`ecMenuOpen`/`colMenuOpen`, `ST ? ST.model_guid : null`. Špehy **len nahrádzajú existujúce funkcie**
  (`typeof === 'function'`), nikdy nevytvárajú chýbajúce; kontrola existencie háčikov (R5 f) beží **pred** ich inštaláciou.
- **R0.2 Golden `tests/fixtures/h14_golden/` (generátor `generate.js`, spúšťa sa ručne, vzor `kova_golden/generate.rb`):**
  - **G1 navigácia:** pre každú zo 14 aktívnych sekcií `#snav.innerHTML`, `#sechead.innerHTML`, `#studio.className` (aj zbalená navigácia).
  - **G2 dispatch:** pre každú sekciu volania háčikov lišty a tela pri `staleFlag` false aj true (`NX.markStale()`), `#sectools`/`#secbody` pre `bom` (3 pohľady), `ctrl`, `buy`;
    variant „modul chýba" (háčik zmazaný) → núdzový text tela a prázdna lišta.
  - **G3 prechody:** 14×14 dvojíc × {navigácia, deep-link}: zoznam volaní háčikov s argumentmi **a stavom v okamihu volania** (aktívna sekcia, tri menu — pred prechodom
    nastavené `true`, identita dokumentu), stav po prechode, výsledná sekcia, **počet zápisov `#snav`/`#sectools`/`#secbody`**; neznáme id, `null`, prázdny reťazec
    (navigácia aj deep-link). **Dokumentová matica (§15 A2):** prvý payload (`ST` = `null`), rovnaký dokument, zmena dokumentu (iné `model_guid`) — každá bez `open_section`,
    s rovnakou sekciou a s inou sekciou; zachytí aj kontextové háčiky `studio.js:1185-1193` pri nezmenenej sekcii.
  - **G4 kotvy:** deep-link s kotvou `'A1'` do každej sekcie; špeh `matOpenAnchor`/`budOpenAnchor`/`apOpenAnchor` vracia raz `true`, raz `false`; zapíše sa `bomQ`, poradie
    voči `*RenderBody`, text statusu a **`#sectools` po deep-linku** (hodnota poľa hľadania — zachytí kotvu `bom` aplikovanú až po renderi).
  - **G8 návrat do rozpracovanej sekcie (§15 A4, UI20_KONTRAKT §3 „stav sekcie prežije prepnutie"):** v Kusovníku pohľad `sheets`, hľadanie `'X'`, zbalená skupina,
    vypnutý stĺpec, vo Kontrole filter `red` → prechod do inej sekcie (navigáciou aj deep-linkom bez kotvy) → návrat; zapíše sa `bomView`, `bomQ`, `groupClosed`, `COLS`,
    `ctrlFilter` a `#sectools`/`#secbody` po návrate.
  - **G9 pamäť tohto počítača:** `localStorage` s `nx_bom_cols`, `nx_bom_groups`, `nx_studio_nav = 'mini'` pred `window.onload` → po prvom payloade `#studio.className`
    obsahuje `navmini`, stĺpce a skupiny podľa pamäte; klik `[data-navmini]` a zmena stĺpca zapíšu **tie isté kľúče a hodnoty** (`studio.js:1147-1168`).
  - **G10 ovládanie navigácie:** klik cez zachytený listener na `[data-nav="<id>"]` pre 14 id (prepne sekciu, počet renderov), na neznáme `data-nav` (nič), `[data-navmini]`;
    v `#snav` je každá položka `<button type="button" … data-nav="…">` (natívna klávesnica Tab/Enter/Space — skutočné stlačenie overí smoke §10, headless ho nevie).
  - **G5 hláška obnovenia:** `requestRefresh()` v každej sekcii (stub `sketchup.refresh_bom`) → text `#status`.
  - **G6 Inspector:** `NXShell.studioOpenLink(s, a)` pre 14 id, `'xyz'`, `''`, `null`, `undefined` × kotva `' A '`, `''`, `null` (harness s `panel.html`).
  - **G7 nastavenia:** `ssActive()` pre každú sekciu.
- **R0.3 Ruby T0b:** headless `push_state` so stubmi (vzor `NxNp3Push`) nad malou syntetickou zákazkou → `push_keys.json`: poradie kľúčov `NX.setStudio` a bajty JSON
  bez `version` a `gen`. Plus `SECTIONS` a matica `consume_pending_section` (id, `'xyz'`, `nil`).
- **R0.4** Fixtúry a testy (`tests/js/test_h14_golden.js`, `tests/pure/test_h14_studio_sekcie.rb`) idú **v prvom commite spolu**, zelené na starom kóde.
  Harness smie čítať top-level premenné `studio.js` (S13); ak ich H14b presunie, upraví sa **čítačka, nie fixtúra** (PR to vysvetlí).

### R1 · Register `NXStudioSections` (H14a; háčiky H14b)

- **R1.1** Súbor `ui/js/studio_sections.js`, UTF-8 bez BOM, `(function(){ … })()` bez závislostí; v prehliadači `window.NXStudioSections`, v Node `module.exports`.
  Riadky §0.3 v poradí `SECTIONS`; riadky a skupiny **zmrazené** (`Object.freeze`).
- **R1.2 API (čisté, bez DOM):** `ids()` (nové pole v poradí) · `has(id)` (len reťazec zo zoznamu) · `get(id)` (riadok alebo `null`) · `groups()` (`[{ grp, t, items }]`
  v poradí) · `inModule(file)` (id sekcií, ktoré kreslí súbor) · `fn(name)` (globálna funkcia podľa mena **v čase volania**: `globalThis`, inak `window`; nie funkcia → `null`) ·
  `REFRESH_DEFAULT`. **`fn` slúži len háčikom iných súborov** (sekčné moduly sú v prehliadači aj v Node testoch globály — S6, S13).
- **R1.2a Háčiky `studio.js` (§15 A1 — CommonJS):** riadky s `module: 'studio.js'` (`bom`, `ctrl`, `buy` a kotva `bomOpenAnchor`) sa **nerozlišujú cez `globalThis`** — pri
  `require('./studio.js')` sú jeho top-level funkcie lokálne pre modul (audit: `globalThis.partsTable` je `undefined`). `studio.js` drží vlastnú tabuľku
  `OWN_HOOKS = { bomRenderTools: bomRenderTools, … }` a rozlišuje `OWN_HOOKS[name]` **pred** `NXStudioSections.fn(name)`. Chýbajúci vlastný háčik je **chyba programu**
  (`throw` → `errors.js`), **nikdy tichá prázdna lišta**; núdzový text „X sa nenačítal" ostáva len pre háčiky iných súborov (dnešné správanie).
- **R1.3 Žiadny odvodený zoznam pri načítaní skriptu** (poučenie H12 A1): konzumenti si smú vziať **referenciu na objekt registra**, ale `ids()`, `groups()`, `inModule()`
  volajú pri použití. Node shim v každom konzumentovi: `(typeof module !== 'undefined' && module.exports) ? require('./studio_sections.js') : window.NXStudioSections`.
- **R1.4 Poradie načítania:** `studio.html` — za `icons.js`, **pred** `studio.js`; `panel.html` — **pred** `shell.js`. Oba tagy `?v=` = VERSION. Guard R5 e.
- **R1.5 Fallback pred prvým payloadom:** navigácia sa ďalej **nekreslí pred prvým `NX.setStudio`** (S5); filter Inspectora funguje hneď (register je statický, nečaká na `NX.init`).
  Keby register chýbal (zlé poradie skriptov), načítanie skriptu nespadne (shim len vezme `undefined`), chyba sa prejaví pri prvom použití a zachytí ju `errors.js` → `js_error`;
  tomuto stavu bráni guard R5 e.

### R2 · H14a — zoznamy z registra

- **R2.1 `studio.js`:** zanikne `STUDIO_SECTIONS`, `NAV`, `SEC_META`, `REFRESH_STATUS`. `renderNav` iteruje `groups()` (rovnaký markup, `title` = `t` alebo `t + ' — ' + hint`,
  vetva `disabled` ostáva); `renderHead` číta `t`/`head` (`'—'` pri neznámej); `navItem(id)` vráti riadok (rovnaké kľúče `id`, `ic`, `t`, `hint`, `badge`, `disabled`);
  `requestRefresh` číta `refresh || REFRESH_DEFAULT`; whitelist v `studioGoSection` a v deep-linku = `has()`; `navCounts('appl')` → `ST.appl.job.counts`, inak `ST.counts`
  (aj pre `true` — test `test_s1b2_pohlad.js:496`). Exporty `STUDIO_SECTIONS` a `NAV` zaniknú; `navItem` ostáva.
- **R2.2 `shell.js`:** `studioSection(s)`: `v = String(s == null ? '' : s)`, `has(v) ? v : null` (ES5 ako zvyšok súboru); `STUDIO_SECTIONS` a jeho export zaniknú; tvar `studioOpenLink` bajtovo rovnaký (G6).
- **R2.3 `studio_settings.js`:** `SS_SECTIONS` → `inModule('studio_settings.js')` pri volaní `ssActive`; export `SS_SECTIONS` zanikne alebo sa stane funkciou (sady prepíšu).
- **R2.4 Ruby:** `SECTIONS` ostáva doslovne; komentár bez „JS zrkadlá" — autorita whitelistu je Ruby, prezentácia je register, parita = fixtúra (R4.1).

### R3 · H14b — jedna cesta prepnutia, kotvy a dispatch

- **R3.1 `studioSwitchSection(id, guid)`** (bez renderu): `has(id)` inak `false`; pri `id ≠ studioSec` `hwProductContextChanged(id, guid)` a `mdManualContextChanged(id, guid)`;
  `closeSectionMenus()`; pri `id ≠ studioSec` háčik `leave` **opúšťanej** sekcie; `studioSec = id`; pri zmene sekcie háčik `enter` novej. Poradie = dnešné (S7, G3).
  `studioGoSection(id)` = `if (!studioSwitchSection(id, ST ? (ST.model_guid || '') : '')) return;` + `render()` — **render len pri úspechu (§15 A3):** neznáme id
  nič neprekreslí (dnes `:2180` končí hneď; zbytočný render by vzal fokus), platné id **aktuálnej** sekcie zhasne menu a prekreslí (ako dnes). Deep-link = prepnutie len pri
  platnom `open_section` + kotvy + `render()` (render v `setStudio` je bezpodmienečný ako dnes — plný payload). Háčiky sa volajú cez R1.2a.
- **R3.2 Kotvy (CX-04 — len deep-link, nikdy klik):** riadok `anchor = { fn, phase: 'before'|'after', miss }`; `before` sa aplikuje pred `render()`, `after` po ňom; `fn(kotva)`
  vracia `false` → `NX.setStatus(miss, true)` (ak `miss`). `bom` dostane `bomOpenAnchor(a){ bomQ = a; return true; }`. Kotva sa spotrebuje práve raz (ako dnes).
- **R3.3 Dispatch:** `renderTools` — bez `ST` prázdna lišta (ako dnes); inak `fn(row.tools)` → `stale ? f(staleFlag) : f()`, chýba → `innerHTML = ''`. `renderBody` — bez `ST`
  „Načítavam…"; inak `fn(row.body)()`, chýba → `<div class="muted">` + `missing`. `bom`/`ctrl`/`buy` = pomenované top-level funkcie v `studio.js` s **presne dnešným
  telom** (`:1487-1519`, `:1699-1703`). V `renderTools`/`renderBody` nezostane žiadna vetva podľa id.
- **R3.4** Ozvena Kontroly (`:1339-1363`) a kontroly vlastnej sekcie v moduloch ostávajú (D9). Komentáre histórie (ŠT-xx) sa skrátia na „prečo" — história ide do KRONIKY.

### R4 · Ruby a nástroje — parita bez regexu nad zdrojom

- **R4.1 Fixtúra kontraktu** `tests/fixtures/h14_studio_sections.json` = celé riadky registra (H14a prezentácia + `module` + `data`; H14b doplní háčiky). JS test: register == fixtúra.
  Ruby test: `StudioDialog::SECTIONS == fixtúra.ids` (hláška povie: „doplň id do `SECTIONS`, riadok do `NXStudioSections` aj fixtúry").
  **Nezávislosť (§15 A5):** fixtúra vznikne v 1. commite H14a **zo starého kódu** (`NAV`, `SEC_META`, `REFRESH_STATUS`) + ručne doplnené `module`/`data`; **nikdy ju
  nevyrába generátor z testovaného registra** a test ju nezapisuje. Ruby aj JS strana porovnávajú aj **poradie**.
- **R4.2** `shots.json`: fotky Štúdia = `SECTIONS` (existujúci test) **a** popis = „Štúdio · " + `t` z fixtúry.
- **R4.3** Ikony: každé `ic` z fixtúry je v `icons.js`, ikony sú jedinečné, riadok „Navigácia Štúdia" v `UI_DIZAJN.md` §4 ich vymenúva (prepis `test_h4b_texty_vzhlad.rb:166-176`).
- **R4.4** „Kto skladá payload": každý `data` z fixtúry je kľúčom headless `push_state` (T0b harness). Ruby literály (`open_section:`, `ROUTE_SECTIONS` hodnoty) ⊂ `SECTIONS`.

### R5 · Guard proti novému prihláseniu „natvrdo" (H14a: a–c, e; H14b: d, f)

- **a)** V `noxun_engine/ui/js/*.js` okrem `studio_sections.js` nie je pole s ≥ 2 id sekcií ani objekt s ≥ 3 kľúčmi = id sekcií (sken §0 S16); v Ruby žiadne `%w[]`/pole s ≥ 2 id
  okrem `StudioDialog::SECTIONS`. Allowlist podľa obsahu riadka s dôvodom (dnes po H14 prázdny; `budget.js:526`, `:1422` nie sú zoznam).
- **b)** Každé literálové id vo volaní `studioGoSection('…')`, `openStudio('…'`, `ssLinkBtn(…, '…'`, `data-ssgo`, `open_section: '…'`, `ROUTE_SECTIONS` je známe.
- **c)** Parita R4.1–R4.4.
- **d)** V `studio.js` nie je `studioSec ===|!== '<id>'` mimo 4 riadkov ozveny Kontroly (allowlist podľa obsahu); `renderTools`, `renderBody`, `studioSwitchSection` a deep-link
  neobsahujú literál id.
- **e)** Poradie tagov (R1.4) v oboch HTML; `studio_sections.js` sa nenačítava v `noxun_engine/ui` nikde inde.
- **f)** Rozlíšenie háčikov **pred inštaláciou špehov** (§15 A5), v **oboch režimoch**: (1) `vm` so skriptmi `studio.html` — **každé** meno `tools`/`body`/`leave`/`enter`/
  `anchor.fn` z registra je funkcia a jej súbor je `module` riadka; `module` je v `studio.html` za `studio.js`; (2) **CommonJS** `require('./studio.js')` — každý háčik riadkov
  `module: 'studio.js'` je v `OWN_HOOKS` a `studioGoSection('bom'|'ctrl'|'buy')` po payloade nakreslí **neprázdnu** lištu aj telo (§15 A1).

## 7 · Testy a DoD

- **T0 · Golden PRED zásahom** (R0): `test_h14_golden.js` + `h14_golden/` + `test_h14_studio_sekcie.rb` (T0b). Zelené na starom kóde v 1. commite H14a, **bez regenerácie**
  v H14a ani H14b (zmena fixtúry = nález).
- **T1 · Register:** API R1.2 (neznáme id, `null`, číslo, `'__proto__'`), zmrazenie, `fn` nenájde `let`/`const` ani neexistujúce meno, register == fixtúra.
- **T2 · Prechod (H14b):** G3, G4, G8, G10 cez novú funkciu; samostatne: navigácia nevolá kotvy, deep-link na tú istú sekciu len zhasne menu, `enter` raz pri vstupe (D-52b),
  **neznáme id = 0 zápisov `innerHTML`, platné id aktuálnej sekcie = zhasnuté menu + 1 render** (§15 A3).
- **T3 · Guardy R5 a–f** (f v režime `vm` aj CommonJS, pred špehmi).
- **T8 · CommonJS (§15 A1):** `require('./studio.js')` + register; po `NX.setStudio` `studioGoSection` do `bom` (3 pohľady), `ctrl`, `buy` → `#sectools`/`#secbody` rovnaké ako
  G2 v `vm` (nie prázdne); existujúci tok `test_st1a_studio.js:393-460` ostáva zelený bez zmeny.
- **T4 · Prepis 21 súborov §0.2 (nemazať, nahradiť ekvivalentom):** zoznam/NAV/SEC_META regexom → register a fixtúra; vetva regexom → správanie cez harness (napr. „Materiály
  majú odchodový háčik v oboch vstupoch" = G3 namiesto `scan(...).length == 2`). **PR vypíše každý prepísaný assert a jeho náhradu.** 8 `vm` sád (S14) dostane
  `studio_sections.js` do zoznamu súborov pred `studio.js`.
- **T5 · Mutácie — každá má test, ktorý ju zhodí** (PR priloží výsledok behu každej; mutácia, ktorú nič nezhodí = doplniť test, nie vyškrtnúť mutáciu):

| M | Mutácia | Zhodí |
|---|---|---|
| M1 | prehodené dva riadky registra | G1, R4.1 (poradie) |
| M2 | chýba riadok `cut` | R4.1 Ruby aj JS, G1 |
| M3 | riadok `xyz` bez Ruby | R4.1 |
| M4 | `bset` ikona `euro` | R4.3 (jedinečnosť), G1 |
| M5 | `ctrl` bez `refresh` | G5 |
| M6 | `tpl` s `refresh` | G5 |
| M7 | `hw` bez `leave` | G3 |
| M8 | `enter` pred `leave` | G3 (poradie volaní) |
| M9 | `closeSectionMenus()` až po háčikoch | **G3 — stav menu v okamihu volania** (§15 A2) |
| M10 | kotva `bom` až po renderi | G4 (`#sectools` po deep-linku) |
| M11 | `mat` `stale: false` | G2 (`staleFlag` true) |
| M12 | preklep `hwRenderBdy` | R5 f (pred špehmi), G2 |
| M13 | späť `if (studioSec === 'tpl')` v `renderBody` | R5 d |
| M14 | nové `['sup','bset','about']` v `studio_settings.js` | R5 a |
| M15 | `studio_sections.js` za `studio.js` | R5 e |
| M16 | filter `shell.js` púšťa neznáme id | G6 |
| M17 | Ruby `SECTIONS` bez `about` | R4.1 Ruby, `test_ui_foto.rb` |
| M18 | `studioGoSection` renderuje aj pri neznámom id | T2 počet zápisov (§15 A3) |
| M19 | vlastné háčiky `studio.js` cez `globalThis` (bez `OWN_HOOKS`) | T8, R5 f CommonJS (§15 A1) |
| M20 | kontextové háčiky sa pri zmene dokumentu a rovnakej sekcii nezavolajú | G3 dokumentová matica (§15 A2) |
| M21 | prechod zresetuje `bomView`/`bomQ`/`ctrlFilter` | G8 (§15 A4) |
| M22 | premenovaný kľúč `nx_studio_nav` alebo neobnovená zbalená navigácia | G9 (§15 A4) |
| M23 | klik na `[data-nav]` nevolá `studioGoSection` | G10 |
- **T6:** `ruby tests/run_all.rb` + **každá JS sada zvlášť** (`for f in tests/js/test_*.js; do node "$f" || exit 1; done`) + `ruby scripts/encoding_guard.rb --repo`.
- **T7 · Fotky:** `scripts\ui_foto.ps1 -Shoot` na čerstvom `main` pred časťou a na hlave vetvy po nej (14 sekcií Štúdia + Inspector); porovnať hárky — či sú PNG
  bajtovo zhodné, **NEOVERENÉ** (determinizmus prehrávania); pri rozdiele vizuálna kontrola a vysvetlenie v PR. Cesty k fotkám do reportu.
- **DoD každej časti:** T0 bez zmeny fixtúr · jej T1–T5 a T8 (H14b) zelené · mutácie v PR · fotky T7 · dokumentácia §11 · PR s „Predrecenziou" a vetou „bez viditeľnej zmeny — golden fixtúry nedotknuté".

## 8 · In-SU — nie je brána

Ruby spúšťače sa nemenia (§5). Runner `run_su_tests.ps1` sa **nespúšťa ako brána**; existujúce scenáre `run_st1a` a ďalšie ostávajú v plnej sade a pobežia pri najbližšej
dávke, ktorá in-SU vyžaduje. Ručné overenie deep-linkov z menu SketchUpu je v smoke (§10).

## 9 · Riziká

- **Bajtový posun navigácie** (skladanie `title`, medzery) — G1. **Kotvy a render** (poradie pred/po) — G4, M10. **Poradie skriptov** — guard e, M15.
- **Háčik podľa mena nenájdený** (`let`/`const`, IIFE, preklep) → núdzový text sekcie — guard f, M12; vlastné háčiky `studio.js` v CommonJS — R1.2a, T8, M19.
  `globalThis` v CEF 137 (SketchUp 2026) je podporované (audit §15 A6); fallback `window` ostáva ako poistka.
- **8 `vm` sád bez registra** (S14) a **oslabenie testov pri prepise** (T4 1:1 v PR; zmena fixtúry T0 = nález).
- **Kolízia s H7/H13** (§5.1). Dáta zákaziek ani `%APPDATA%` sa nemenia → zmiešané PC (Lucia) bez rizika.

## 10 · Smoke checklist pre Michala (po H14b)

1. Štúdio z toolbaru: preklikaj **všetkých 14 sekcií** — poradie, ikony, nadpisy a nápovedy ako predtým; zbaľ navigáciu na ikony a späť; badge pri Kontrole a Spotrebičoch.
2. V každej sekcii „Obnoviť" — hláška počas prepočtu ako predtým (Šablóny podľa Q1).
3. Menu Extensions → Noxun Engine → Pravidlá kovania · Materiály projektu · Katalóg kovania · Nastavenia rozpočtu · Šablóny — otvorí správnu sekciu.
4. Inspector: ⚠ → „Otvoriť v Štúdiu → Kontrola" · karta dielca → materiál (otvorí detail dekoru) · „Materiál" v info stĺpci → Kusovník s vyplneným hľadaním · spotrebič → Spotrebiče s riadkom.
5. Kontrola → rozpočtový nález → Rozpočet na správnej časti · nález nastavení prerezu → Nastavenia rozpočtu.
6. **Klávesnica (§15 A4):** Tab po položkách navigácie, Enter aj medzerník otvorí sekciu; po prepnutí sekcie a návrate ostane v Kusovníku pohľad, hľadanie a zbalené
   skupiny, v Kontrole filter; zbalená navigácia sa po zatvorení a otvorení Štúdia vráti zbalená.
7. Otvor modal v Materiáloch alebo Kovaní, prepni sekciu — modal zmizne; O plugine — kontrola verzie raz pri vstupe, nie pri každom prepočte.

## 11 · Checklist uzáveru (každá časť zvlášť)

Bump patch VERSION (`noxun_engine.rb` + `noxun_engine/main.rb`) + **všetky `?v=`** (aj nový tag v oboch HTML) → T0–T7 → **architektúra na mieste:** `ui-lifecycle.md` nový odsek
**„ui/js/studio_sections.js — register sekcií Štúdia"** (kľúče riadka, API, poradie načítania, „háčik podľa mena v čase volania", fixtúra, ako pridať sekciu) + prepísané odrážky
„Navigácia a sekcie" (`:1287-1296`) a „Deep-link" (`:1324-1327`) v odseku okna ŠTÚDIO a „Deep-link do Štúdia" v odseku Klikateľnosť (`:945-950`, zrkadlo `NXShell.STUDIO_SECTIONS` zaniká);
H14b: „jedna cesta prepnutia" (veta „Prepnutie sekcie z kódu má jedno miesto" je dnes nepravdivá — F4) · `docs/ARCHITEKTURA.md` riadok zdieľaných JS komponentov +
`studio_sections.js` · `UI_DIZAJN.md` §4 veta „ikony navigácie čítaj z registra" (bez zmeny inventára) → **prepis STAV** → **KRONIKA** odsek navrch → **PLAN** riadok H14
s časťami (✅ + PR) → package + surový audit do `SYSTEM/zdroje/bloky/HARDENING/` → **PR popis:** „nič viditeľné", trieda, Predrecenzia, mutácie, T4 náhrady 1:1, fotky,
„golden fixtúry nedotknuté". Číslo PR: `PR #?` → samostatný commit.

## 12 · Rozhodnutia autora — na potvrdenie orchestrátorom

| # | Rozhodnutie | Prečo | Potvrdiť? |
|---|---|---|---|
| D1 | **Jediný JS register** (zdieľaný súbor) + Ruby `SECTIONS` ako serverový whitelist s paritou cez fixtúru — **nie** register v Ruby poslaný payloadom | Ruby nepozná nič okrem id (S2); háčiky sú mená JS funkcií, takže serverový register by aj tak potreboval druhú JS tabuľku; žiadna zmena payloadu `NX.setStudio` ani `NX.init` (bez `-Record`, bez časovania H12 A1, filter Inspectora funguje pred `NX.init`, 48 Node sád bez zmeny). Alternatíva V2 (server): +kontrakt payloadu, `-Record`, ~20 JS sád by musel plniť register, Inspector by potreboval kľúč v `NX.init` | **áno** |
| D2 | Parita Ruby↔JS cez fixtúru, nie regex nad zdrojom | CX-05; vzor H12 T1; Ruby test nespúšťa node (bez precedensu) | nie |
| D3 | Háčiky v registri **menom**, rozlíšené v čase volania — vlastné háčiky `studio.js` z `OWN_HOOKS`, ostatné `fn()` cez `globalThis` (§15 A1) — nie samoregistrácia modulov | presne dnešná sémantika `typeof x` (aj „modul chýba" → núdzový text); celý riadok sekcie na jednom mieste; špehy golden fungujú pred aj po | krátko |
| D4 | `bom`/`ctrl`/`buy` dostanú pomenované háčiky v `studio.js` | dispatch bez výnimiek podľa id; telá bez zmeny | nie |
| D5 | Kotvy v registri s fázou `before`/`after`, len v deep-linku | CX-04 (kotva ≠ klik); S8 | nie |
| D6 | Ruby `push_state` a callbacky ostávajú explicitné; register len deklaruje `data` + guard | CX-05 výslovne; GR-06 „stavitelia sa registrujú" by menil poradie výpočtov a záklopky (`@mat/@hw_full_pending`) bez prínosu pre túto dávku | **áno** |
| D7 | Rez H14a → H14b, audit jeden na package | > 400 riadkov zmien spolu; každá časť bajtovo rovnaká | **áno** |
| D8 | Navigácia sa ďalej nekreslí pred prvým payloadom | dnešné správanie (S5) | nie |
| D9 | Kontroly vlastnej sekcie v moduloch a ozvena Kontroly ostávajú | modul pozná svoju sekciu — nie je to prihlásenie; menší diff | nie |
| D10 | Kľúče riadka v tvare dnešnej položky NAV (`id`, `ic`, `t`, `hint`, `badge`), `navItem` ostáva | menej prepisov testov, rovnaký markup | nie |

## 13 · Otázky pre Michala (produktové; do odpovede platí návrh)

- **Q1 · Hláška pri „Obnoviť" v Šablónach.** Keď v Štúdiu → Šablóny klikneš „Obnoviť", okno počas načítania napíše „Prepočítavam kusovník…", hoci sa načítava knižnica šablón
  (ostatné sekcie píšu, čo naozaj robia). **Návrh:** H14 ostane prísne „bez viditeľnej zmeny" a hlášku nechá; opraví sa samostatnou drobnosťou (jeden riadok registra:
  „Načítavam knižnicu šablón…"). Ak chceš, H14b ju môže opraviť rovno ako jedinú vedomú zmenu.

## 14 · Nálezy mimo scope a odovzdanie H13

- **F1** Šablóny „Obnoviť" → hláška kusovníka (S11) → Q1.
- **F2** `REFRESH_STATUS` chýba aj pre `appl`, `sup`, `bset`, `about` — tie však `#refreshBtn` nemajú (Nastavenia rozpočtu majú vlastné „Obnoviť" `ss-reload`), takže dopad nie je.
- **F3** Položky menu `main.rb:637-649` majú iné mená než sekcie („Pravidlá kovania" vs „Pravidlá", „Materiály projektu" vs „Materiály", „Katalóg kovania" vs „Kovanie") — vedomé
  historické skratky; zjednotenie je produktové rozhodnutie (zásobník).
- **F4** `ui-lifecycle.md:1288` tvrdí, že prepnutie sekcie z kódu má jedno miesto — deep-link je druhé (CX-04). *Opraví H14b.*
- **F5** Hlavičky skupín navigácie sú písané VEĽKÝMI („ZÁKAZKA" …); či je to vedomá výnimka pravidla D-07 (UI_DIZAJN §1), **NEOVERENÉ** — H14 ich nemení.
- **F6** Registrácia Ruby stavačov payloadu (GR-06) — až keď niektorá sekcia bude potrebovať lenivý payload; do mapy H13.
- **Odovzdanie H13 (B-06, riadok „nová sekcia Štúdia"):** (1) riadok `NXStudioSections` (prezentácia, `refresh`, `module`, `data`, háčiky, kotva); (2) id v `StudioDialog::SECTIONS`;
  (3) riadok fixtúry `tests/fixtures/h14_studio_sections.json`; (4) JS modul sekcie + `<script>` v `studio.html` za `studio.js`; (5) kľúč payloadu v `StudioDialog.push_state`
  (+ `*_actions`, prípadne `on_ui_closed`); (6) fotka v `shots.json`; (7) nová ikona v `icons.js` + UI_DIZAJN §4. **Čo ťa zastaví:** guardy R5 a–f. H13 píše mená konštánt, nie čísla riadkov.

---

## 15 · Audit návrhu — zapracovanie (audítor audit-povinných, 1.10.2026) — 0 BLOCKER · 4 FIX · 2 NOTE · MÁ PREDNOSŤ

Surový výstup `AUDIT_H14_raw.md` (implementátor ho skopíruje do `SYSTEM/zdroje/bloky/HARDENING/` spolu s package). Všetky FIX zapracované do §1–§14; **koncept sa nemení**
(register v JS, Ruby whitelist, parita fixtúrou, rez H14a → H14b, mená háčikov) — zmeny spresňujú rozlíšenie háčikov a rozširujú charakterizáciu.

| # | Nález | Zmena v package |
|---|---|---|
| **A1** FIX (H14b) | Rozlíšenie háčikov cez `globalThis` nezachová CommonJS — pri `require('./studio.js')` sú nové `bom`/`ctrl`/`buy` háčiky lokálne pre modul (`globalThis.partsTable` = `undefined`); integračné testy cez CommonJS reálne kreslia lištu | **R1.2a** (nové): `OWN_HOOKS` v `studio.js` sa rozlišuje pred `fn()`; chýbajúci vlastný háčik = `throw`, nie tichá prázdna lišta · **R5 f** v režime `vm` aj CommonJS · **T8** (nový) · **M19** · D3 · §9 |
| **A2** FIX (H14a) | G3 nezachytí M9 (presun `closeSectionMenus` za háčiky dal 196/196 rovnakých výsledkov) ani dokumentový kontext (`studio.js:1185-1193` volá kontextové háčiky aj pri nezmenenej sekcii) | **R0.1** špeh zapíše stav v okamihu volania (sekcia, tri menu, `model_guid`) · **G3** dokumentová matica (prvý payload, rovnaký dokument, zmena dokumentu × bez/rovnaká/iná sekcia) · **M9** → G3, **M20** |
| **A3** FIX (H14b) | Obal `studioGoSection` musí rešpektovať odmietnutie neznámeho id (dnes `:2180` končí bez renderu) | **R3.1** render len pri úspechu prepnutia; platné id aktuálnej sekcie = zhasnuté menu + render · **R0.1** počítadlo zápisov `innerHTML` · **G3**, **T2** počet renderov · **M18** |
| **A4** FIX (H14a) | Pred zmrazením T0 chýba návrat do rozpracovanej sekcie, pamäť tohto počítača a ovládanie navigácie (UI20_KONTRAKT §3; `studio.js:1147-1168`; `h12_harness` nezachytáva listenery) | **R0.1** harness so záznamom listenerov a `localStorage` · **G8** návrat s filtrom a pohľadom · **G9** kľúče `nx_bom_cols`/`nx_bom_groups`/`nx_studio_nav` a obnovenie zbalenej navigácie · **G10** klik `[data-nav]`/`[data-navmini]` a markup `<button>` · smoke §10 bod 6 (Tab/Enter/medzerník) · **M21–M23** |
| **A5** NOTE | D1 je primerané; parita musí ostať nezávislým testom — fixtúra sa nesmie vyrábať z testovaného registra; kontrola existencie háčikov **pred** špehmi | **R4.1** fixtúra zo starého kódu v 1. commite H14a, nikdy generátorom z registra; porovnáva aj poradie · **R0.1**, **R5 f** existencia háčikov pred inštaláciou špehov; špehy len nahrádzajú, nevytvárajú |
| **A6** NOTE | Trieda sedí (audit áno, výrobná/cenová nie, in-SU nie je brána, `-Shoot` áno); `globalThis` podporuje CEF 137 (SketchUp 2026) | §5 bez zmeny · §9: dostupnosť `globalThis` už nie je NEOVERENÁ, fallback `window` ostáva ako poistka; riziko je CommonJS (A1) |

**§7 zladené:** každá mutácia M1–M23 má v tabuľke T5 test, ktorý ju zhodí; PR priloží beh každej.

### Potvrdenie orchestrátora

- **D1 potvrdené:** jeden JS register `NXStudioSections` + Ruby `StudioDialog::SECTIONS` ako serverový whitelist + **nezávislá paritná fixtúra** (A5).
- **Rez H14a → H14b potvrdený** — každá časť samostatný PR z čerstvého `main`, bajtovo rovnaké výstupy, golden T0 z 1. commitu H14a bez regenerácie.
- **Q1** („Prepočítavam kusovník…" pri „Obnoviť" v Šablónach) = **predvolene nechať**, otázka pre Michala; zmena len na jeho výslovné „áno".
- **Audit uzavretý** po zapracovaní FIX — **bez nového auditu**, pokiaľ implementácia nezmení koncept (§15 úvod); zmena konceptu = delta audit.
