# Blok UPDATE — rozhodnutia Michala (17.10.2026)

> **Čo to je:** rozhodnutia Michala z debaty na štarte bloku UPDATE (okno plánovania počas smoke bloku 9 HARDENING).
> Autorita pre koncept, mockup a packages bloku. Zmena po schválení mockupu = rámček „platí" v mockupe + zápis sem.
> **Implementácia** sa začne až po Michalovom **smoke PASS bloku 9** alebo výslovnom „ideme ďalej" (CLAUDE.md, Autonómne bloky).

## Obsah bloku

| # | Otázka | Rozhodnutie Michala |
|---|---|---|
| R1 | Čo je blok UPDATE | **Len D-48 — zdieľaná knižnica pre 2 PC** (Michal + Lucia), tvar Odoslať / Aktualizovať. Postrehy zo smoke HARDENING do bloku **nepatria**. |
| R2 | Chyby zo smoke S5 (umývačka šírka vs. trieda, kontrola niky), S6 (Spotrebiče bez obnovenia), S9 (názov voľnej dosky vo VEPO) | **Opravy x.y.z mimo bloku** (po smoke PASS, pred blokom). Ostatné postrehy S1–S15 ostávajú v zápisníku smoke na zaradenie. |

## Tvar zdieľania (mení rozhodnutia zo 6.9.2026 tam, kde sa líšia)

Pôvodné rozhodnutia: [../../next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md](../../next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md) §0, mechanizmus
[../../next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md](../../next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md), súpis úložísk [../../../docs/architecture/kniznice.md](../../../docs/architecture/kniznice.md).

| # | Otázka | Rozhodnutie Michala 17.10. | Oproti 6.9. |
|---|---|---|---|
| R3 | Kto smie odosielať knižnicu na Disk | **Správca = Michal.** Odoslať má len Michalovo PC; Lucia len Aktualizovať. Neskôr sa dá rozšíriť. | **ZMENA** (6.9.: obaja zapisujú, konflikt ručne) — konflikt dvoch odoslaní z dvoch PC odpadá |
| R4 | Lucia upravila knižnicu u seba a klikne Aktualizovať | **Varovanie + preskočiť:** okno „V Materiáloch máš vlastné zmeny — prevzatím sa prepíšu"; voľba **prepísať** (jej verzia sa odloží ako záloha) alebo **tento katalóg zatiaľ preskočiť**; ostatné katalógy sa prevezmú normálne | nové |
| R5 | História na Disku | **Áno, posledných 5 odoslaní** každého katalógu; v O plugine „Vrátiť na verziu z …" — návrat sa odošle ako nová verzia, Lucia ju dostane bežným Aktualizovať | nové (6.9. malo zametanie N = 5 len technicky) |
| R6 | Rozsah kliku | **Naraz + riadok per katalóg** so stavom (aktuálny / novší na Disku / lokálne zmeny); preskočenie katalógu len cez varovanie R4 | potvrdené |
| R7 | Štart SketchUpu, na Disku je novšia knižnica | **Len oznámi**; sťahuje sa vždy až klikom | potvrdené |
| R8 | Čo cestuje navyše oproti základu registra | **Fotky dekorov** (`textures/` — inak Lucia vidí farby namiesto fotiek, kniznice.md F2) **a názov zákazky uložený v .skp** (F1 — dnes ho každé PC drží podľa cesty k súboru; nie knižnica, samostatná dávka bloku) | nové |
| R9 | Čo ostáva každému PC | rozmerové rady a „18 + 36" (rozhodnutie 2.10.2026), téma, prepínače kontrol, cesty, značky — podľa registra `LibraryRegistry` | potvrdené |
| R10 | Luciino PC | **SketchUp 2026 a Google Disk H: zrkadlený** rovnako ako u Michala (Michal 17.10.: „obe sedia") | uzatvára otázku H11 Q3 |
| R11 | Zdieľaný koreň | `H:\Môj disk\NoxunENGINE data` (6.9., bez zmeny); distribúcia updatera D-52 v tom istom koreni | potvrdené |

## Po krížovom audite (A4 Claude, 17.10.)

| # | Otázka | Rozhodnutie Michala |
|---|---|---|
| R13 | Lucia dnes do knižníc zapisuje (Prepočítať ceny, skupiny z Demosu, materiál, spotrebič) — ostáva to (A4 B4)? | **Ostáva + banner** v oknách knižníc na PC, ktoré nie je správca: „Zmeny tu sa pri Aktualizovať prepíšu — pošli ich správcovi"; pri Aktualizovať varovanie R4 |
| R14 | Odoslať / Aktualizovať len pri rovnakej verzii pluginu (A4 B3)? | **Áno, len rovnaká verzia**; inak „najprv aktualizuj plugin" (updater D-52, ten istý koreň) |
| R16 | Má Lucia rozpracované zákazky s vlastnými materiálmi či spotrebičmi (reconcile O1)? | **Nie — začína s Michalovou knižnicou**; prvé Aktualizovať jej knižnicu nahradí (záloha + varovanie R4), **bez párovania** záznamov |
| R17 | Aktualizovať prepíše ceny a sadzby (reconcile O2) | **Veta v okne stačí:** „Zmenia sa ceny v … — najbližší rozpočet pôjde podľa nového cenníka"; zmrazenie rozpočtu zákazky mimo bloku |
| R15 | Fotky dekorov cez Disk alebo dotiahnuť z Demosu (A4 A6)? | **Cez Disk** — ako prílohy verzie katalógu (len fotky, na ktoré katalóg odkazuje), R8 platí |

## Z packages (17.10.)

| # | Otázka | Rozhodnutie Michala |
|---|---|---|
| R18 | Výklad R14 (PACKAGE_U3 §13 Q1) | **Aktualizovať** len pri rovnakej verzii pluginu; **Odoslať** sa blokuje len keď je knižnica na Disku z **novšieho** pluginu alebo keď správcova verzia pluginu ešte **nie je na Disku** pre druhé PC |
| R20 | „Uložiť ako" — nesie kópia ten istý názov zákazky (PACKAGE_U1 §13 Q1)? | **Áno, ten istý**; Michal ho prepíše ceruzkou, keď chce (riziko rovnakého priečinka VEPO dvoch variantov vedome prijaté) |
| R19 | Dvaja správcovia naraz (PACKAGE_U3 §13 Q2) | **Odoslať sa vypne na oboch** s vetou o dvoch správcoch, riešenie ručne v „⋯"; Aktualizovať ide ďalej |

## Postup bloku

| # | Otázka | Rozhodnutie Michala |
|---|---|---|
| R12 | Codex v krížovom audite bloku (po tom, čo 1 beh `gpt-6-astra` so širokým zadaním zobral celé 5h okno a 17 b. týždňa bez výsledku) | Krížový audit bloku na **`gpt-6.1-sol` po resete okna, s úzkym zadaním** (vymenované súbory, bez voľného prehľadávania repa); `gpt-6-astra` len na povinné audity packages, tiež úzko |

## Mockup — schválený 17.10.2026

[MOCKUP_UPDATE_KNIZNICA.html](MOCKUP_UPDATE_KNIZNICA.html) **schválený bez úprav**; všetky body „návrh — potvrdí Michal" uzavreté:

| # | Bod mockupu | Platí |
|---|---|---|
| O1 | Kde | box **Zdieľaná knižnica** v sekcii Štúdia **O plugine** (pod aktualizáciou pluginu) |
| O2 | Správca | ponuka „⋯": na Michalovom PC raz „Toto PC je správca knižnice" s potvrdením; kým nikto, Odoslať vypnuté na oboch; neskôr „Odovzdať správcu…" |
| O3 | Riadky | **5 skupín** prevzatých/preskočených vždy celé: Materiály (+ ABS pravidlá, vzhľady, fotky dekorov) · Kovanie (katalóg, výrobcovia, sety, pravidlá) · Šablóny (+ náhľady) · Dodávateľ a sadzby · Spotrebiče (+ listy) |
| O4 | Štart | natívne oznámenie „Na Disku sú novšie knižnice: …" s „Otvoriť O plugine" / „Neskôr" + bodka pri „O plugine" v navigácii, kým je čo aktualizovať |
| O5 | História | posledných 5 odoslaní per skupina (dátum, poznámka); „Vrátiť" len správca = nová verzia; na PC bez správcu aj „Vrátiť zálohu" pred prepisom |
| O6 | Pruh | jeden jantárový riadok v oknách Materiály, Kovanie, Šablóny, Spotrebiče, Nastavenia rozpočtu na PC, ktoré nie je správca |
| O7 | Iná verzia | jantárová veta v boxe, Odoslať aj Aktualizovať čakajú |
| O8 | Poznámka k odoslaniu | **áno, nepovinné pole** pri Odoslať; Lucia ju vidí pri Aktualizovať a v histórii |
| O9 | **Ikona stiahnutia** (doplnok Michala po schválení, 17.10. — rámček „platí" v mockupe) | keď je na Disku čo aktualizovať: ikona pri „O plugine" v **navigácii Štúdia** a tlačidlo v **lište Inspectora** pod okom (viditeľnosť tagov); klik z lišty otvorí Štúdio → O plugine na boxe aktualizácie; bez aktualizácie sa nekreslí; nahrádza „bodku" z O4. **R21:** svieti pre **novú knižnicu aj novú verziu pluginu**, tooltip povie čo |
