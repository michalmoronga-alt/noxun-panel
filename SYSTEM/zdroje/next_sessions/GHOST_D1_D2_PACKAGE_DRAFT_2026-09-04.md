# GHOST-D1 / GHOST-D2 — DRAFT packages (4.9.2026, po Codex kolách #288)
> Stav: KONCEPT — HISTÓRIA: packages boli 5.9.2026 prenesené do `SYSTEM/PLAN.md` (blok 4, GHOST-D1 a GHOST-D2 = autorita); tento súbor je archív draftu, reconcile a nálezov — nemeniť a schválení, nie priamo do implementácie.

> **Status: DRAFT — nezáväzný podklad.** Outside-in research: WebFetch + **Antigravity beh 4.9.2026 večer HOTOVÝ** (4 packety, reconcile v packete); **probe v SU 2026 čaká** (`_dev/probe_ghost_keys.rb`) — Codex #292 P1 ([GHOST_OUTSIDE_IN_2026-09-04.md](GHOST_OUTSIDE_IN_2026-09-04.md)) — reconcile je v poslednej sekcii tohto
> súboru. Do `SYSTEM/PLAN.md` sa packages vrátia ako autorita po zapracovaní reconcile + nálezov Codex kola 2 (nižšie) a po Codex CLI audite draftu. Rozhodnutia Michala 4.9.: ↑/↓ = orientácia dosky
> (nie voľná rotácia) · D1 pred D2 · jedno číslo na fázu · viazané diely/sektory po V1.

- **GHOST-D1 · TASK PACKAGE „GHOST PRE DOSKY — ZÁKLAD" (V1 bod 1B, Michal 4.9.2026; stav: DRAFT — pred implementáciou POVINNÝ outside-in research (nová Tool/inference plocha; skill `antigravity-outside-in`, pri vyčerpanej agy kvóte cez WebSearch) + `codex-audit`; Codex GH #288 nálezy zapracované; in-SU POVINNÉ; štart po NÁSTROJE-1 / KOV-B2):**
  **Cieľ:** vloženie dosky z karty Dosky ide cez ghost ako pri skrinke (doska na kurzore, prichytenie na geometriu, kotvy, klik = vloženie) — dnes sa doska kladie synchrónne na `Placement.next_x`.
  **Scope IN:** `BoardBuilder.prepare_insert` / **`commit_insert(model, plan, transform:, orientation:)`** (vzor R-03: zmrazený plán, ŽIADNA mutácia pred klikom; commit = jedna operácia, `Ids.next_board_id`,
  definícia + `draw_board`, orientácia ako transformácia inštancie NAD polohou — vnútro definície ostáva ležiace, výrobné dáta nedotknuté). **Orientácia ide do commitu SAMOSTATNE** (Codex #288 P1):
  `stojaca` a `na_stenu` vedome zdieľajú maticu (STANDARD §orientácia), takže z `transform` sa odvodiť nedá — finálnu hodnotu zo session nesie argument a zapíše sa do `config['orientation']`
  (in-SU test to overuje v uloženom configu; neskoršia zmena orientácie v karte tak počíta deltu zo správneho stavu). `GhostTool` dostane **SUBJEKT** (skrinka | doska): `PlacementSession` číta obálku
  a kotvy zo subjektu (`Calc.envelope_points`/`anchor_points` dosky z dĺžky × šírky × hrúbky + orientácie), commit cez šev subjektu; **klasický tok skrinky sa NEMENÍ** (existujúce `run_ghost*` sekcie
  zelené bez úpravy = charakterizácia) · klávesy pre dosku: ←/→ rotácia okolo Z (ako skrinka) · **↑/↓ = cyklus orientácie `leziaca → stojaca → na_stenu`** (vlastnosť dosky, nie voľná rotácia —
  Michal 4.9.: kusovník, hrany a ABS tak ostávajú správne; Z-režim skrinky pre dosku nahrádza orientácia) · ALT = kotvy · pásik ghostu ukazuje orientáciu · karta Dosky: „Vložiť dosku" štartuje ghost
  session (ako „Vložiť skrinku"), Esc = nič sa nevloží, 0 krokov Späť; pamäť session (orientácia, rotácia, kotva) per doska. **Pečiatka šablóny (Codex #288 P2):** `template_ref` dosky nesie SESSION a
  `stamp_once!`/„Naposledy použité" sa volá **až po úspešnom commite** — Esc pečiatku NEzapíše (dnešný synchrónny `handle_insert_board` pečiatkuje po vložení; test Esc → poradie nezmenené).
  **Scope OUT:** kreslenie na rozmer (D2) · roly dosiek (worktop/pilaster/plinth) · automatické generovanie · viazané diely (po V1).
  **Testy a DoD:** headless — obálka a kotvy dosky per orientácia (3×), cyklus orientácie, plán zmrazený (žiadna mutácia), `commit_insert` = jedna operácia a `orientation` v configu, subjekt skrinky
  nezmenený, pečiatka len po commite; **in-SU `run_ghost_d1`** — ghost dosky vloží dosku na kliknutý bod s prichytením na roh skrinky, ↑ zmení orientáciu (stojaca) a **uložený config ju nesie**, ←/→
  rotácia, ALT kotva, Esc = model nezmenený, 0 krokov Späť a šablóna neopečiatkovaná, vloženie = 1 krok Späť, kusovník má dosku, ghost skrinky nezmenený. Mutácie min. 4 (orientácia zapísaná do výrobných
  osí · commit mimo operácie · subjekt skrinky číta obálku dosky · orientácia odvodená z matice).
  **Smoke pre Michala:** karta Dosky → Vložiť → doska visí na kurzore, prichytí sa na roh skrinky, ↑ ju postaví, klik vloží (karta ukáže „stojaca"), Ctrl+Z vráti; vkladanie skriniek ako doteraz.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `construction.md` (šev board_builder), `ui-lifecycle.md` (ghost subjekt, klávesy, pečiatka), ARCHITEKTURA router pri novom súbore → STAV/KRONIKA/PLAN.

- **GHOST-D2 · TASK PACKAGE „KRESLENIE DOSKY NA ROZMER (Ghost 2.0)" (po D1; stav: DRAFT — outside-in research (natívny Tool, inference, Measurements/VCB) + `codex-audit` pred implementáciou; Codex GH #288 nálezy zapracované; in-SU POVINNÉ):**
  **Cieľ:** doska sa nakreslí **dvoma ťahmi**: klik = nulový bod → ťah dĺžky (prichytenie SketchUp inference ALEBO napísané číslo v mm do natívneho merania) → klik → ťah šírky → klik = vloženie;
  hrúbka z materiálu karty. **Ťahy sledujú LOKÁLNE osi dosky podľa orientácie** (Codex #288 P2): dĺžka = lokálna X (pri ležiacej aj stojacej doske vodorovná), šírka = lokálna Y (pri stojacej zvislá) —
  pilaster sa teda kreslí: ↑ stojaca, 1. ťah = hĺbka (dĺžka), 2. ťah = výška (šírka); orientácia sa cyklí ↑/↓ ako v D1, smer 1. ťahu určí otočenie okolo Z.
  **Predloha:** archívny V2fable Ghost 2.0 — kópia zdroja je v repe ako referencia `SYSTEM/zdroje/archiv_kod/v2fable_ghost_tool2.rb.txt` (Codex #288: mimo repa by implementátor nemal čo čítať): fázy,
  `enableVCB?`/`onUserText`, `Sketchup.vcb_value`, axis snap, locks — port do subjektu dosky, nie kópia. Pokrýva praktickú potrebu zostáv: pracovná doska, pilaster, soklová lišta či krycí panel sa
  nakreslia prichytením na rohy skutočných skriniek.
  **Scope IN:** fázy 0 (bod) → 1 (dĺžka) → 2 (šírka) → commit · VCB: **jedno číslo na fázu** (Michal 4.9.), Enter potvrdí; **validácia proti `BoardBuilder::LIMITS` PRED prijatím** (dĺžka 10–5000,
  šírka 10–3000 mm — Codex #288 P1: `normalize` inak ticho oreže a náhľad by ukázal iný rozmer, než sa vyrobí), mimo limitu = fáza ostáva + status s limitom; neplatný text = fáza ostáva ·
  **zamknuté fázy LEN z explicitného stavu zámkov karty (`NXInsert.boardLocks`)** — NIE z toho, že pole má hodnotu (Codex #288 P1: polia karty sú vždy predvyplnené, 800 × 600, takže by sa preskočili
  obe fázy); prázdny Enter vo fáze = vedome prevezme hodnotu karty pre TÚTO fázu (explicitná akcia, status to povie) · prichytenie na osi (axis snap) + inference, obálka kreslená počas ťahu, kóty v
  tooltipe · Esc v hociktorej fáze = nič, 0 krokov Späť, šablóna neopečiatkovaná (D1 pravidlo) · karta Dosky: dve tlačidlá „Vložiť" (D1) a „Nakresliť" (D2) — potvrdiť v audite/mockupe.
  **Scope OUT:** viac čísel naraz („600;18") · tretí rozmer · roly dosiek · automatika pilastrov/PD (po V1, po agy researchi).
  **Testy a DoD:** headless — parser čísla (mm, desatinné, neplatné) + limity (9, 10, 5000, 5001; 3000/3001), fázový automat (zámky z `boardLocks`, prázdny Enter = hodnota karty, Esc), orientácia z ťahu
  a lokálne osi per orientácia, obálka počas fázy; **in-SU `run_ghost_d2`** — nakresliť dosku dvoma ťahmi s prichytením na rohy dvoch skriniek (dĺžka = presne súčet šírok), „2400 Enter" → dĺžka 2400,
  „6000 Enter" → odmietnuté a fáza ostáva, Esc vo fáze 2 = nič (0 krokov Späť), vloženie = 1 krok Späť, ↑ stojaca → pilaster (výška = 2. ťah) a uložený config nesie orientáciu aj presné rozmery
  (náhľad = geometria = config). Mutácie min. 4 (limit neoverený pred Enter · zámok z vyplneného poľa · šírka pri stojacej po X · pečiatka pri Esc).
  **Smoke pre Michala:** pracovná doska od ľavého rohu prvej po pravý roh poslednej skrinky, šírku napíš 600, hotovo; pilaster: ↑ stojaca, 1. ťah hĺbka, 2. ťah výška; napíš 6000 → plugin odmietne
  s limitom.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `ui-lifecycle.md` (ghost D2), `docs/UI_DIZAJN.md` (tlačidlá karty Dosky) → STAV/KRONIKA/PLAN.

## Codex kolo 2 (#288, 4.9.2026) — nálezy NA ZAPRACOVANIE pred návratom do PLANu

1. **P1 (D2) — odvodený plán s nakreslenými rozmermi:** D1 šev `commit_insert(model, plan, transform:, orientation:)` beží nad plánom zmrazeným PRED štartom ghostu; D2 pozná dĺžku a šírku až po dvoch ťahoch.
   Definovať čistý krok `replan(plan, length:, width:)` → NOVÝ zmrazený plán s finálnymi rozmermi, ktorý zachová snapshot materiálu a šablóny zo session; test: náhľad = config = geometria z odvodeného plánu.
2. **P2 (D1) — štart orientácie z karty:** karta vkladania nastavuje orientáciu explicitne pri každej materializácii (aj zo šablóny, `insert_state.js`/`form.js`). Každá NOVÁ session sa inicializuje z hodnoty
   karty; pamäť ghostu drží orientáciu LEN pre zmeny klávesmi v rámci session (alebo sa orientácia z trvalej pamäte vyradí). Test: predvolená šablóna „stojaca" po predošlej ležiacej session.
3. **P1 (D2) — pravotočivá transformácia pri 2. ťahu na opačnú stranu:** archívny Ghost 2.0 pri opačnej strane obracia `@dir_y` a necháva +Z → ľavotočivé zrkadlenie, ktoré šev R-03 odmieta. Definovať:
   pri zápornom 2. ťahu sa posunie POČIATOK o −šírka po lokálnej Y a osi ostanú pravotočivé; in-SU prípady pre kladný aj záporný smer 2. ťahu.


## Outside-in reconcile (4.9.2026, packet `GHOST_OUTSIDE_IN_2026-09-04.md`) — NA ZAPRACOVANIE pred návratom do PLANu

1. **D1:** subjekt DOSKA v existujúcom `GhostTool` (jeden `Sketchup::Tool`), `getExtents` pri kreslení obálky mimo obálky modelu (prázdny model), LOGICKÉ pixely LEN pre obrazovkové API (callback `x`/`y`, `draw2d`, rozmery viewportu; SU 2025+) — `InputPoint#position`, rohy obálky a `getExtents` ostávajú v modelových jednotkách, `onCancel` reason 2 (undo) = zrušiť session bez zápisu.
2. **D2:** fázy cez `InputPoint#pick(view, x, y, ip_predošlý)` (inferencia od predchádzajúceho bodu); **lokálnu os šírky (kolmú na 1. ťah) definuje VLASTNÁ projekcia bodu na os** (vzor `axis snap`
   archívneho Ghost 2.0) — `View#lock_inference` vie zamknúť len inferenciu, ktorú SketchUp sám našiel, takže sa použije LEN na dostupné natívne inferencie (os modelu, hrana), nie ako mechanizmus
   lokálnej osi; **probe pred implementáciou (Codex #294):** `view.lock_inference(ip_a, ip_b)` s DVOMA syntetickými `InputPoint.new(pt)` na lokálnej osi — ak zamkne líniu medzi nimi,
   použije sa natívny zámok a projekcia ostane len fallback (`_dev/probe_ghost_keys.rb`, klik = os); `enableVCB?`/`onUserText` len vo fázach 1–2; `Sketchup.vcb_label=` „Dĺžka (mm)" / „Šírka (mm)".
3. **D2 vstup čísla:** VLASTNÝ čistý parser s ÚPLNOU zhodou po `strip` — `\A\d+([.,]\d+)?\s*(mm)?\z` (bodka aj čiarka, `mm` voliteľné), prefix/sufix odpad (`abc2400xyz`, `2400mmjunk`), tilda `~` a `;` odmietnuté — testy na všetko; nikdy `String#to_l`/`to_f` na surový text (pasca locale s desatinnou čiarkou); hodnota mm Float → `Units` do modelu; validácia `BoardBuilder::LIMITS` PRED prijatím.
4. **D2 pravotočivý 2. ťah** (Codex kolo 2 P1): pri zápornom smere posun počiatku o −šírka po lokálnej Y, osi ostávajú pravotočivé — žiadne obrátenie `dir_y`.
5. `Sketchup::Snap` (2025.0) = poznámka do bloku viazaných dielov po V1, nie do D1/D2.
6. **Prázdny Enter (agy, MENÍ NÁVRH):** konštanta `VK_RETURN` v SketchUp API neexistuje — prázdny Enter chytiť v **`Tool#onReturn(view)`** (`onUserText` sa pri prázdnom poli nevolá); písané hodnoty
   ostávajú v `onUserText`. Probe v SU 2026: či `onReturn` prichádza aj so zapnutým VCB a či `onKeyDown` dostane kód 13 (agy: regresia 2026.0, fix 2026.1 → overiť `Sketchup.version`).
7. **Parser (agy, doplnenie):** `\A\s*(\d+(?:[.,]\d+)?)\s*(?:mm)?\s*\z/i` po `strip` (aj `MM`, medzery okolo); neplatný vstup = `UI.beep` + status + fáza ostáva (vzor Trimble `99_sphere_tool`, MIT).
8. **Šípky — ROZHODNUTÉ (a), Michal 4.9.2026:** ostávajú ako pri ghoste skrinky (←/→ rotácia okolo Z, ↑/↓ cyklus orientácie — zhodné s riadkami 5–6, 15–16 a testami tohto draftu); natívny zámok osí
   (↑←→↓ od SU 2016) je v ghoste dosky vedome pohltený (`onKeyDown` vracia `true`), lebo zámok osí v ghoste nemá zmysel a D2 ťahy idú po lokálnych osiach dosky. Alternatíva Tab/R (agy, vzor s4u Panel) zamietnutá.
9. **Commit (agy):** `start_operation('Vložiť dosku', true)` bez vnorenia + `rescue → abort_operation` explicitne v package (zhodné s konvenciou enginu).
10. **Vzory (licencie):** Trimble `02_custom_tool` (kostra) a `99_sphere_tool` (VCB chyby) — MIT · `Eneroth3/inference-lock-lib` (Shift lock) — MIT · OpenCutList 7.0 Smart Draw — GPL, len vzory ·
    Rotated Rectangle = precedens „jedno číslo na fázu" · SketchList 3D = precedens 3 orientácií · `Sketchup::Snap` = NO ACTION pre V1 (poznámka do bloku viazaných dielov).

## Codex CLI audit kolo 1 (5.9.2026) — Sol (`gpt-5.6-sol`) + Astra (`gpt-6-astra`), ZAPRACOVANÉ do PLANu (PR #296)

**Sol — 4 BLOCKER + 11 FIX:** (1) `boardLocks` žijú len v JS („NIKDY do Ruby") → D2 nemá dátovú cestu pre zámky · (2) smer lokálnej X nedefinovaný, keď 1. fázu dokončí číslo/prázdny
Enter/zámok bez ťahu · (3) kontrakt `commit_insert` slabší než R-03 (typ plánu, identita modelu, snapshot transformácie, root kontext, rigidná matica) · (4) zmrazený plán ≠ zmrazený
materiálový snapshot (`normalize`/`board_config` čítajú živý katalóg) · (5) šípky/ALT po potvrdení 1. fázy · (6) chýba politika výšky dosky bez Z-režimu · (7) kotvy bez autoritatívneho
kontraktu · (8) pamäť ghostu nie je per subjekt · (9) limity pre všetky zdroje rozmeru · (10) `replan` a automatický názov · (11) lifecycle Shift locku · (12) dve tlačidlá bez uzavretého
callbacku / dvojklik · (13) „karta ukáže stojaca" bez sync mechanizmu · (14) `flush_pending!` bariéra pred vložením · (15) `test_ghost_vkladanie.rb:601` odporuje novému toku.
**Astra — 1 BLOCKER + 6 FIX + 1 NOTE:** (1) „jedna operácia" odporuje transparentnému scale-lock follow-upu (`board_builder.rb:527`) → kontrakt „jeden používateľský krok Späť" · (2) politika
výšky + `ghost_lock_z` pre dosku + charakterizácia skrinka → doska → skrinka · (3) bariéra pred čakajúcim `ScaleWatch` timerom · (4) projekcia vo voľnom priestore (pilaster zvislo) → fallback
`pickray` → os · (5) zámky do Ruby cez `locksFlat('board')` + whitelist · (6) smer pri preskočení 1. ťahu (4 kombinácie zámkov) · (7) `board_config` pri zápise znova číta katalóg · (8) NOTE
presnosť 0,01 mm parser vs `board_config`.
**Reconcile:** všetko prijaté a zapracované do packages D1/D2 v PLANe (verzia 2, 5.9.); rozhodnutia orchestrátora: kanonický smer pri nulovom vektore = lokálna +X podľa rotácie session;
klávesy po potvrdení 1. fázy zamknuté; ALT v D2 bez významu; presnosť 0,01 mm pri prijatí hodnoty; kotvy = tabuľka 3×4 v package. Kolo 2 auditu nad verziou 2 = ČAKÁ.

## Codex CLI audit kolo 2 (5.9.2026, Astra nad verziou 2 `b9f7173`) — ZAPRACOVANÉ (verzia 3)

Kolo 1: **21/23 RESOLVED**, 2 PARTIAL — (Sol 1 / Astra 5) `locksFlat('board')` vracia HODNOTY (`{length: 800}`), nie Boolean → kontrakt zámkov je ČÍSELNÝ snapshot; (Sol 7) tabuľka kotiev bez
konkrétnych súradníc/ID/poradia ALT → doplnená tabuľka 3 orientácie × 4 kotvy s ID `fl_bottom/fr_bottom/fr_top/fl_top` a poradím ako skrinka. **Nové:** (1) FIX-IN-D2 — kruhová závislosť
smer ↔ projekcia v 1. ťahu → fáza 1 HĽADÁ SMER v rovine 1. ťahu (vodorovná rovina Z počiatku pre všetky orientácie, žiadna projekcia na lokálnu os), fáza 2 MERIA po pevnej osi; test
šikmého 1. ťahu 45°; (2) NOTE — dve hranice zákazu ↑/↓ → jedna hranica: klávesy len vo fáze 0 (od kliku počiatku zamknuté). Kolo 3 (Sol, delta) = ČAKÁ.
