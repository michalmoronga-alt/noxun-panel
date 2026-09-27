# Krížový audit bloku 8 · K3 ROHOVÁ SKRINKA — zadanie (rovnaké pre všetkých audítorov)

> Záznam zadania krížového auditu bloku (28.9.2026, noc). Audítori: **Codex** (`gpt-6-astra`, s prístupom k repu) a **Grok** (`grok-4.7`, Grok Build,
> len čítanie repa + web). Antigravity/Gemini v nočnom behu nebeží (pravidlo bezpečnosti). Za týmto zadaním nasleduje inline celý pracovný
> koncept `ROH_KONCEPT_K3.md` (v1). Výsledky: `CROSS_AUDIT_CODEX_2026-09-28.md`, `CROSS_AUDIT_GROK_2026-09-28.md`; rozhodnutia Michala:
> `ROZHODNUTIA_MICHALA_2026-09-27.md` (R1–R9) v tom istom priečinku.

## Rola

Si nezávislý audítor návrhu pre SketchUp Ruby plugin **Noxun Engine** — parametrický nábytok na mieru (korpusy, čelá, kovanie) s výstupmi do
výroby: kusovník, **VEPO CSV** pre nárezovú službu, nákup kovania, rozpočet a cenová ponuka. **Od 20.8.2026 sa z pluginu objednávajú reálne
zákazky** — chyba v rozmeroch, hranách alebo cenách je najvyššia priorita. Hodnotíš HOTOVÝ návrh (nižšie) z dvoch strán:
(1) **outside-in** — čo už CAD a nábytkársky svet rieši (slepá rohová skrinka s fillerom / „blind corner base with filler"), oficiálne limity
výrobcov, precedensy; (2) **devil's advocate** — čo návrh prehliada a čo sa pokazí vo výrobe alebo v kóde.

## HARD RULES

- Nerob nový návrh ani kód — hodnotíš tento návrh. **Nič v repe nemeň** (len čítanie).
- Každý nález má **kategóriu**: ALREADY EXISTS · SIMPLER NATIVE PATH · CAD PRECEDENT · MISSED CONSTRAINT · GOOD CUSTOM SOLUTION · RESEARCH GAP · NO ACTION.
- Každý nález má **stav**: VERIFIED (stránku si naozaj otvoril — URL + dátum; pri repe súbor:riadok) / UNVERIFIED (z pamäti modelu).
- CAD precedens nesie **licenciu** (GPL = vzory áno, kód nie · proprietárny produkt = len vzory).
- RESEARCH GAP = „nenašiel som" — nikdy vymyslený údaj, číslo ani API.
- **Závažnosť:** BLOCKER (návrh treba zmeniť pred kódom) · FIX (zapracovať do package) · NOTE (na zváženie).
- Výstup **po slovensky**, max ~90 riadkov + zdroje. Homepage URL nie je dôkaz — cituj konkrétny dokument.

## Výstupný formát

```
# K3 rohová cross audit — <nástroj a model> — <dátum>
## Nálezy
| # | Závažnosť | Kategória | Tvrdenie | Dôkaz (URL + dátum alebo súbor:riadok) | VERIFIED/UNVERIFIED | § návrhu | Odporúčanie | Prácnosť S/M/L |
## Nenašiel som (RESEARCH GAP)
## Zdroje (len URL, ktoré si naozaj otvoril)
## Kontrola voči repu   ← súbor:riadok, ak máš prístup k repu
```

## Cielené otázky

- **Q1 · CAD precedens:** ako iné programy (Cabinet Vision, Mozaik, CabWriter, KD Max, imos iX, Polyboard, TopSolid Wood, Pytha, SketchUp
  pluginy) modelujú slepú rohovú dolnú skrinku s fillerom: parametre (šírka dverí/otvoru, „blind" časť, filler v šírke aj hĺbke), strana L/P
  (parameter vs. zrkadlená geometria), filler ako súčasť skrinky vs. samostatný objekt, kusovník.
- **Q2 · Výroba a kovanie:** je bežný záves s prekrytím 16 mm na kolmej výstuhe (18 × 80 mm) v rohu v poriadku, alebo treba iný typ (Blum/Hettich
  pre blind corner)? Otvárací uhol pri CR lište 80 mm a úchytke susedného radu. Výrez police okolo výstuhy — ako to riešia iní?
- **Q3 · Dátový model:** typ `corner_blind` vs. prepínač na `lower`; dielce pred čelnou rovinou (Y < 0); hrúbka čelového materiálu v osi X (CR 2);
  otvor čiel užší ako skrinka; vynútený jediný riadok dverí; výnimka z guardu „žiadny default smeru pántov".
- **Q4 · Zrkadlenie:** zrkadlenie v pláne (X' = W − X − šírka) — riziká pre hrany (L1/L2), smer dekoru, medzery `gap_left/right`, smer pántov, overridy.
- **Q5 · Observer a Undo:** config-aware klamp šírky pri scale pre rohovú — riziká.
- **Q6 · Rez dávok:** je ROH-A jedna dávka, alebo ju rozrezať? Čo patrí do ROH-B?
- **Q7 · Kontrola voči repu (audítor s prístupom k repu):** over fakty a návrh voči kódu (`noxun_engine/core/cabinet_builder.rb`, `construction.rb`,
  `modules/fronts.rb`, `build_plan.rb`, `abs_rules.rb`, `part_faces.rb`, `validation.rb`, `vepo_export.rb`, `hardware_rules.rb`, `scale_observer.rb`,
  `ui/js/preview.js`, `ui/js/form.js`, `ui/panel/actions_cabinet.rb`, `ui/panel/payloads.rb`) — nájdi, čo návrh prehliada: uzavreté zoznamy typov
  a rolí, čitatelia plnej šírky čiel, cesty meniace štruktúru čiel, `materialized_part`, `thickness_ok_for?`, `envelope`/`Placement`/ghost pri dielcoch
  v −Y, golden testy, starší plugin. Nálezy BLOCKER/FIX/NOTE so súbor:riadok.

## Známe fakty z kódu (read-only, main `44a9d2d4`, v0.14.0)

- **Osi:** X šírka zľava, **+Y dozadu, čelná rovina korpusu Y = 0, čelá v −Y** (`materialized_part` ich posadí na `−th … 0`), Z výška; origin korpusu
  ľavý-predný-dolný roh. Dielce sú osové kvádre vložené čistou transláciou; **ľavotočivú (zrkadlenú) maticu inštancie engine odmieta** (vklad,
  nástroje; ghost ju nevie vyrobiť; scale cache si ju nezapamätá).
- **Typy** `TYPES = lower upper dishwasher` (uzavretý zoznam, neznámy typ sa sklopí na `lower`); posledný nový typ (slot umývačky) sa dotkol 48 súborov.
- **Čelá:** `Construction.front_opening(cfg)` vracia `{x0, w, z0, h}` a `Fronts.resolve_layout` otvor užší ako skrinka podporuje; plnú šírku
  natvrdo predpokladá panelový preflight, JS náhľad a draft. Čelá sa delia len na výšku (riadky), na šírku len krídla dvierok. `direction` =
  strana pántov (trojstav: chýba = legacy · `unset` = RED · `left/right`); guard test zakazuje v kóde predvolenú stranu. Medzery `gap_left/right/top/bottom`
  (default 2), `gap` medzi riadkami 3. Blenda ako čelo = rola `false_front`.
- **Materiál per rola:** `FRONT_MATERIAL_ROLES = front_door drawer_front flap false_front` → čelový kanál; hrúbku 18,6/19 toleruje `thickness_ok_for?`
  len čelám a zásuvkám, inak `validate_material_thickness!` zhodí stavbu; `materialized_part` prepisuje hrúbku len čelám a predpokladá ju v osi Y.
- **Roly:** BuildPlan `ROLES` uzavretý (SCHEMA 6); nová rola prechádza ~20 uzavretými zoznamami (ABS seed + `SEED_VERSION` 5, PartFaces osi,
  tagy, labely, VEPO skratky, Kontrola, ponuka…). ABS je pravidlo per rola, bez bumpu seedu = dielec bez pásky na existujúcich PC.
- **Kovanie:** závesy = položka krídla dverí podľa výšky (≤ 849 → 2), nohy podľa šírky (≥ 1000 → 6); miesto montáže závesu sa nemodeluje.
- **Police** idú cez celú šírku zóny od `y = 20`; kolízie dielcov engine nekontroluje. **Scale šírky** nie je config-aware (zúženie pod minimum
  konštrukcie → výnimka prestavby a tichý návrat), výška a hĺbka áno.
- **Schémy:** `CONFIG_SCHEMA` 21 (dopredný guard R-12: novší config starší plugin neprestaví ani nevyexportuje) · BuildPlan `SCHEMA` 6 · ABS
  `SEED_VERSION` 5 · šablóny `STD` 7. VEPO názov riadku ≤ 20 znakov (`SHORT_NAMES`, `NAME_PAIRS`).
- **Inspector** nemá prepínač typu označenej skrinky; typ sa volí tlačidlami vo vkladacej karte (Dolná · Horná · Umývačka · Doska).

---

# NÁVRH NA AUDIT

Audítori dostali za týmto zadaním **inline celý pracovný koncept v1** (28.9.2026 ~00:10) — jeho presná kópia je zachovaná ako **surový vstup
auditu** v [KONCEPT_K3_v1_AUDITOVANY_2026-09-28.md](KONCEPT_K3_v1_AUDITOVANY_2026-09-28.md) (tam sa dajú dohľadať odkazy nálezov `§2`, `§5`…).
Koncept **nie je zadanie**: vyhodnotenie každého nálezu je v [RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md](RECONCILE_KRIZOVEHO_AUDITU_2026-09-28.md),
technické riešenie určí **package dávky ROH-A1** po vlastnom audite návrhu (pravidlo štartu bloku z 27.9.2026).
