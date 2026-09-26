# Krížový audit bloku KONŠTRUKCIA K1+K2 + D-143 — zadanie (rovnaké pre všetkých audítorov)

> Záznam zadania krížového auditu bloku (27.9.2026). Audítori: **Grok** (`grok-4.7`, web, bez repa) a **Codex** (`gpt-6-astra`, s prístupom
> k repu); Gemini podľa rozhodnutia Michala 26.9. nebeží. Za týmto zadaním nasleduje inline celý [KONCEPT_K1K2_2026-09-26.md](KONCEPT_K1K2_2026-09-26.md).
> Výsledky: `CROSS_AUDIT_GROK_2026-09-27.md`, `CROSS_AUDIT_CODEX_2026-09-27.md`; syntéza a reconcile: `CROSS_AUDIT_RECONCILE_2026-09-27.md`.

## Rola

Si nezávislý audítor návrhu pre SketchUp Ruby plugin **Noxun Engine** — parametrický nábytok na mieru (korpusy, čelá, kovanie) s výstupmi do
výroby: kusovník, **VEPO CSV** pre nárezovú službu, nákup kovania, rozpočet a cenová ponuka. **Od 20.8.2026 sa z pluginu objednávajú reálne
zákazky** — chyba v rozmeroch, hranách alebo cenách je najvyššia priorita. Hodnotíš HOTOVÝ návrh (nižšie) z dvoch strán:
(1) **outside-in** — čo už CAD a nábytkársky svet rieši, oficiálne limity výrobcov, precedensy; (2) **devil's advocate** — čo návrh prehliada
a čo sa pokazí vo výrobe.

## HARD RULES

- Nerob nový návrh ani kód — hodnotíš tento návrh.
- Každý nález má **kategóriu**: ALREADY EXISTS · SIMPLER NATIVE PATH · CAD PRECEDENT · MISSED CONSTRAINT · GOOD CUSTOM SOLUTION · RESEARCH GAP · NO ACTION.
- Každý nález má **stav**: VERIFIED (stránku si naozaj otvoril — URL + verzia alebo dátum; pri repe súbor:riadok) / UNVERIFIED (z pamäti modelu).
- CAD precedens nesie **licenciu** (GPL = vzory áno, kód nie · proprietárny produkt = len vzory).
- RESEARCH GAP = „nenašiel som" — nikdy vymyslený údaj, číslo ani API.
- **Závažnosť:** BLOCKER (návrh treba zmeniť pred kódom) · FIX (zapracovať do package) · NOTE (na zváženie).
- Výstup **po slovensky**, max ~80 riadkov + zdroje. Homepage URL nie je dôkaz — cituj konkrétny dokument.

## Výstupný formát

```
# K1K2 cross audit — <nástroj a model> — <dátum>
## Nálezy
| # | Závažnosť | Kategória | Tvrdenie | Dôkaz (URL + verzia/dátum alebo súbor:riadok) | VERIFIED/UNVERIFIED | § návrhu | Odporúčanie | Prácnosť S/M/L | Licencia |
## Nenašiel som (RESEARCH GAP)
## Zdroje (len URL, ktoré si naozaj otvoril)
## Kontrola voči repu   ← len audítor s prístupom k repu
```

## Cielené otázky

- **Q1 · CAD precedens:** ako iné programy (napr. imos iX, Cabinet Vision, Polyboard, Winner Flex, KD Max, TopSolid Wood, Mozaik, Pytha,
  Cabinet Planner, SketchUp pluginy OpenCutList / ABF) modelujú (a) **odsadený chrbát so vzduchovým kanálom** (komín), (b) **zapustený strop
  alebo odsadenú prednú traverzu**, (c) **chrbát z dvoch zadných líšt (traverz)**? Názvy a sémantika parametrov (odkiaľ sa meria), obmedzenia,
  ako to ukazujú v UI (bokorys, kóty).
- **Q2 · Spotrebiče:** vetranie vstavanej chladničky a rúry — vzduchový kanál za chrbtom (hĺbka v mm, prierez v cm²) a **či sa hĺbka niky meria
  po chrbát skrinky alebo po stenu** (Bosch/Siemens, Liebherr, Beko, Whirlpool, Electrolux/AEG, Miele). Sedí prax „komín ~50 mm"?
- **Q3 · Chrbát v drážke:** bežná hĺbka drážky a prídavok rozmeru chrbta (napr. drážka 10, vôľa 1 → +9 mm na stranu); je prax „HDF do nárezu
  v plnom rozmere skrinky a zrezať v dielni" rozšírená a aké má riziká (plocha, cena, nárezová služba)?
- **Q4 · Zadné lišty namiesto chrbta:** typická výška, hrúbka, olepenie, uchytenie; ako sa rieši hĺbka políc a zásuviek pri lištách (celá výška
  vs. len pásmo líšt).
- **Q5 · Výsuvy zásuviek:** pravidlá výrobcov (Blum Legrabox/Tandembox/Movento, Hettich AvanTech YOU/InnoTech Atira/Quadro) pre minimálnu
  vnútornú hĺbku korpusu voči dĺžke výsuvu (NL) — potvrdzujú logiku „najväčšia NL s `min_depth ≤ svetlá hĺbka`"?
- **Q6 · D-143 dátovo:** oddelený **rozmer do nárezu** od geometrie dielca — precedens v CAD/CAM (cut size vs. finished size, „Zuschnittmaß vs.
  Fertigmaß", prídavky v OpenCutList)? Riziká pre agregáciu kusovníka, export a cenu.
- **Q7 · Kontrola voči repu (len audítor s prístupom k repu):** over fakty a návrh (§1–§8) voči kódu; nájdi, čo návrh prehliada — reťaz
  whitelistov, `config_to_params`, `merge_template`, absorpcia scale, D-37, `back_z_hi`, `rail_geometry`, box niky, nohy, preflighty chrbta,
  agregácia kusovníka a `NAME_PAIRS`, pole `cut` a jeho čitatelia, staršie PC, golden testy; navrhni mená polí a formu zápisu do configu.
  Nálezy BLOCKER/FIX/NOTE so súbor:riadok.

## Známe fakty z kódu (read-only, main `0f468e5`; plné znenie so súbor:riadok v `FAKTY_Z_KODU_2026-09-26.md`)

- **Osi:** X šírka, **+Y dozadu** (čelná rovina Y = 0), Z výška. `d` = celková hĺbka **vrátane chrbta** (D-37); hĺbka korpusu = `d − bt` pri
  naloženom chrbte, inak `d`.
- **Chrbát:** `overlay` (za skráteným telom, celá šírka `w`, výška `h − s`) · `inset` (medzi bokmi aj medzi dnom a stropom, zadná plocha zarovno)
  · `groove` (10 mm pred zadnou hranou, `w − 2t` × vnútorná výška; **drážka nie je modelovaná, bez prídavku**) · `none`. Hrúbka HDF 3 alebo pevný 18.
- **Strop:** `full` · `two_rails` (predná a zadná výstuha, naplocho hĺbka 100 alebo na výšku, `rails_top_offset`) · `none`. **Dno:** pod bokmi /
  medzi bokmi. **Sokel/nohy** podľa `floor_height`.
- **Predvolené:** dolná 600 × 720 × 510, sokel 100, dno pod bokmi, chrbát naložený HDF 3 · horná 600 × 720 × 320, bez sokla, dno medzi bokmi,
  chrbát v drážke HDF 3. Vysoká skrinka = dolná s väčšou výškou (vlastný typ neexistuje). Slot umývačky má vlastný plán bez korpusu.
- **Vnútorná hĺbka** má jedinú autoritu `interior_dims.back_front_y`; číta ju 10+ konzumentov: zóny, police (hĺbka zóny − 20, predné odsadenie 25),
  priečky, recepty zásuviek (**NL = najväčšia s `min_depth ≤ svetlá hĺbka`**; zamknutá NL, ktorá sa nezmestí → RED; RED zastaví nákup, rozpočet
  aj ponuku), legacy pravidlo výsuvu, výklop AVENTOS HL (`depth_min` 264), kontrola niky spotrebičov (chladnička Š/V/H, rúra a mikrovlnka Š/H),
  ponuka „zmestí sa", Inspector.
- **Každé nové konštrukčné pole** musí prejsť ~8 uzavretými whitelistami (`normalize`, `cabinet_config`, `config_to_params` s 18 volaniami,
  `PARAM_KEYS`, JS `CONSTRUCTION_FIELDS`, `template_config_from`, `merge_template`, JS zrkadlá výpočtu) — chýbajúce miesto = tichá strata poľa.
- **Schémy:** `CONFIG_SCHEMA` 18 (dopredný guard R-12: novší config odmietne prestavbu, šablóny a kópie; exporty zastaví) · BuildPlan `SCHEMA` 5
  (uzavretý slovník rolí; nové roly = bump podľa precedensu) · kľúče dielcov `cabinet/<kind>:<variant>`.
- **ABS** je pravidlo per rola (seed, `SEED_VERSION` 4; nová rola bez bumpu seedu = dielec bez pásky na existujúcich PC); hrany L1/L2 pozdĺž dĺžky,
  výnimka „stojace" roly (dielce zásuviek). Agregačný kľúč kusovníka obsahuje mapu hrán → rovnaký rozmer a rovnaký kód hrany = jeden riadok.
- **VEPO:** názov riadku ≤ 20 znakov vrátane značiek skriniek; `SHORT_NAMES` + `NAME_PAIRS` („Bok LP", „Vyst PZ"); neznámy názov ide bez zmeny.
- **Výrobný rozmer `prod` = geometria `box`** — rovnosť strážia `PartFaces` a `AppearanceMapping` (D-88/D-104/MR-3A); rozídenie by zhodilo
  stavbu otextúrovaného dielca, farbenie hrán, Kontrolu olepov a smer dekoru.
- **UI:** Inspector S4 má skupiny Strop · Dno & podstavec · Boky (len zástupný text) · Chrbát; náhľad je len čelný pohľad, chrbát sa nekreslí.
- **Šablóny:** whitelist pri ukladaní; legacy šablóna bez kľúča → predvolená hodnota, okrem vetvy „zachovaj cieľ" (vzor D-13).
- **Scale:** hĺbka × faktor, klamp nie je config-aware; neplatný výsledok sa zruší bez hlášky.
- Dve pracoviská (Michal, Lucia) — staršia verzia pluginu na druhom PC je reálne riziko.

---

*(Nasleduje inline celý NÁVRH — `KONCEPT_K1K2_2026-09-26.md`.)*
