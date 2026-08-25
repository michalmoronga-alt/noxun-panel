# SYSTEM — mapa autorít

> **Načo je tento súbor:** `SYSTEM/` je pamäť projektu pre agentov. Aby sa v nej dalo
> orientovať bez čítania všetkého, má **každý živý dokument práve JEDNU rolu**. Tu je
> napísané, ktorý súbor je autorita na čo, v akom poradí sa číta a čo sa kam zapisuje.
> Pravidlá práce v repe (workflow, verzie, checklist uzáveru dávky, testovanie) žijú
> v [../CLAUDE.md](../CLAUDE.md) — tento súbor ich nenahrádza, len ukazuje na dokumenty.

## Poradie čítania

1. [STAV.md](STAV.md) — **kde projekt je dnes** (verzia, čo funguje, čo sa robí, ďalší krok).
2. [PLAN.md](PLAN.md) — **čo sa ide robiť** (bloky prác, zásobník, trvalé pravidlá).
3. [DOGFOODING.md](DOGFOODING.md) — plné znenia **otvorených** postrehov (D-čísla) k bloku.
4. Podľa témy zásahu: STANDARD · VEPO_KONTRAKT · POJMY (tabuľka nižšie).

Na otázku **„prečo je to takto?"** sa nečíta nič z hora — na to je [archiv/KRONIKA.md](archiv/KRONIKA.md).

## Živé dokumenty — jedna rola na súbor

| Súbor | Autorita na | Nie je |
|---|---|---|
| [STAV.md](STAV.md) | dnešok: verzia, hotové, rozrobené, ďalší krok | história (tá je v KRONIKE) |
| [PLAN.md](PLAN.md) | budúcnosť: bloky prác, zásobník, trvalé pravidlá | záznam hotových blokov |
| [DOGFOODING.md](DOGFOODING.md) | **otvorené** postrehy z praxe, plné znenie | zoznam vyriešeného |
| [STANDARD.md](STANDARD.md) | záväzný dátový kontrakt (dictionary, roly, mm Float) | návod na UI |
| [VEPO_KONTRAKT.md](VEPO_KONTRAKT.md) | formát výstupu do VEPO | ostatné výstupy |
| [POJMY.md](POJMY.md) | glosár + trvalé fakty stolárskej domény | plán ani stav |
| [V1_VIZIA.md](V1_VIZIA.md) | definícia „V1 hotové" + nemenné princípy | plán (ten je v PLAN.md) |

## Vrstvy

- **Živé docs** (`SYSTEM/*.md`) — platia teraz, čítajú sa podľa tabuľky vyššie.
- **[zdroje/](zdroje/)** — **nezáväzné** koncepty, rešerše, prieskumy dodávateľov, mockupy,
  seed podklady. **Nečítať automaticky** — otvárajú sa, len keď na ne živý dokument
  výslovne pošle. Koncepty v [zdroje/next_sessions/](zdroje/next_sessions/) nesú status
  riadok `> Stav: KONCEPT` a **neimplementujú sa priamo** (najprv návrh + audit proti kódu).
- **[archiv/](archiv/)** — história a uzavreté rozhodnutia: [KRONIKA.md](archiv/KRONIKA.md)
  (záznam každej dávky), [ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md) (plné
  texty hotových blokov a etáp), [DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md)
  (index + plné texty vyriešených D-čísel), staršie analýzy a vízie. Archív je
  **append-only** — nič sa v ňom neprepisuje.

## Pravidlá (strážia ich guardy v `tests/pure/test_docs_navigacia.rb`)

- **Živý dokument nesmie odkazovať na zdrojový koncept ako na autoritu.** Podklad zo
  `zdroje/` sa cituje ako podklad; záväzné znenie patrí do STANDARD, PLAN alebo docs.
- **Hotový blok nesmie zostať v PLAN.** Uzavretý blok ide plným textom do
  `archiv/ROADMAP_hotove_etapy.md`; v PLAN ostávajú len nehotové veci a trvalé pravidlá.
  (Guard: PLAN nesmie mať nadpis bloku s „KOMPLET" ani „✅".)
- **DOGFOODING drží len otvorené postrehy.** Vyriešené idú plným textom do
  `archiv/DOGFOODING_vyriesene.md` a **index vyriešených je tam tiež** — nie tu.
- **STAV je krátky** (max 80 riadkov a 12 kB) a má stabilnú kostru piatich sekcií.
  Nahradený text ide odsekom navrch „Záznamy dávok" v `archiv/KRONIKA.md`.
- **Žiadny riadok nad 400 znakov** v živých docs — jeden odsek na jednom obrom riadku
  znamená nečitateľný diff a nemožné review. (Archív a zdroje sa nestrážia.)
- **Po každej väčšej otestovanej dávke sa docs aktualizujú** podľa **checklistu uzáveru
  dávky** v [../CLAUDE.md](../CLAUDE.md) — nie „niekedy neskôr", ale v tej istej dávke.
