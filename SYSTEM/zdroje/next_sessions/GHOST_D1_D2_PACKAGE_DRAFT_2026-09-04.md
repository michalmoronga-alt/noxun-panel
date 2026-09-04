# GHOST-D1 / GHOST-D2 — DRAFT packages (4.9.2026, po Codex kolách #288)
> Stav: KONCEPT — nezáväzný podklad (výskumný packet / draft packages); do PLANu sa prenáša len po reconcile a schválení, nie priamo do implementácie.

> **Status: DRAFT — nezáväzný podklad.** Do `SYSTEM/PLAN.md` sa vrátia ako autorita až po outside-in researchi (natívny `Sketchup::Tool`,
> inference/`InputPoint`, Measurements/VCB) a po zapracovaní nálezov Codex kola 2 (nižšie). Rozhodnutia Michala 4.9.: ↑/↓ = orientácia dosky
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
