# VEPO výstupný kontrakt (v1.0 — extrahované z vepo_exporter, 15.7.2026)

> Presný formát tabuľky pre objednávkový systém VEPO, zreverzovaný z Michalovho pluginu `vepo_exporter` (Plugins\vepo_exporter\core\*). Nový systém bude tento výstup generovať PRIAMO z dielcov — bez medzikroku OCL CSV → vepo_exporter. Tento dokument je od teraz zdroj pravdy formátu.

## Výstupný CSV súbor (to, čo VEPO potrebuje)

- **Stĺpce v presnom poradí (bez hlavičky):** `nazov ; dlzka ; hrana_pozdlz ; sirka ; hrana_naprieč ; hrubka ; pocet_ks ; material`
- **Oddeľovač:** `;` (bodkočiarka), **všetky polia v úvodzovkách** (force_quotes)
- **Rozmery:** celé čísla v mm (zaokrúhlené `.round`) — **HOTOVÉ/finálne rozmery dielca, ŽIADEN odpočet ABS** (potvrdené 20.7., Michal: VEPO si hrúbku pásky odratáva samo na základe kódov hrán — presne preto sa kódy posielajú; stará linka OCL→vepo_exporter posielala tiež finálne rozmery)
- **Kódovanie hrán (ABS):**
  - `""` (prázdne) = bez hrany na tejto dvojici strán
  - `—` (em-dash) = hrana na JEDNEJ strane z dvojice
  - `=` = hrany na OBOCH stranách dvojice
  - `hrana_pozdlz` vyjadruje dvojicu pozdĺžnych strán (l1, l2), `hrana_naprieč` dvojicu priečnych (w1, w2)
- **Rotácia dielca** (ak treba kvôli dekóru/nestingu): vymeniť dĺžka↔šírka A ZÁROVEŇ hrana_pozdlz↔hrana_naprieč

## Normalizácia hrúbok (VEPO očakáva obchodné hrúbky)

- 18.0–19.1 mm → **18**
- 36.0–38.1 mm → **36**
- ostatné → zaokrúhliť na celé
- hrúbka ≤ 0 = chybný dielec (do exportu nejde, loguje sa)

## Delenie do súborov (grouping)

- Dielce sa delia podľa **materiál + hrúbková skupina**; voliteľne merge 18+36 do jedného súboru (tag `18_36`)
- **Názov súboru:** `<projekt_slug>_<material_slug>_<hrubka_tag>.csv`
- **Slug:** slovenská/česká diakritika → ASCII (á→a, č→c, ž→z…), nealfanumerické → `_`, lowercase, bez dvojitých/krajných `_`
- Popri CSV sa píše LOG súbor (projekt, verzia, dátum, zoznam skupín, chyby)

## Vstupný kontrakt pôvodného flow (OCL CSV) — len pre referenciu/validáciu

Pôvodný reťazec: OCL export CSV (BOM UTF-8, oddeľovač `;` alebo `,` auto-detekcia) s hlavičkami (CZ/SK): `označení (název/názov)`, `délka/dĺžka`, `šířka/šírka`, `tloušťka/hrúbka`, `počet/ks`, `hrana podél 1/2`, `hrana napříč 1/2`, `druh materiálu`, `název/názov materiálu`. Z hodnôt hrán sa počíta len „má číslo / nemá číslo" na každej strane. Názvy sa čistia od HTML tagov.

## Čo z toho vyplýva pre dátový model dielca v novom systéme

Dielec musí niesť minimálne: **názov, dĺžka, šírka, hrúbka (reálna aj obchodná), počet, materiál (názov pre VEPO), hrany 4× samostatne (l1, l2, w1, w2 — nie len súhrnný kód!), príznak rotácie/orientácie dekoru**. Súhrnné kódy `—`/`=` sa DOPOČÍTAJÚ pri exporte — v modeli držíme plné info per strana (lebo `—` nevie povedať KTORÁ strana; pre CNC a kusovník to potrebujeme presne). **Rozmery v exporte = hotové rozmery bez úprav** — ABS hrúbky sa NIKDY neodratávajú (robí to VEPO); plné per-strana info o hranách ostáva v modeli pre budúce CNC/nárezové výstupy.
