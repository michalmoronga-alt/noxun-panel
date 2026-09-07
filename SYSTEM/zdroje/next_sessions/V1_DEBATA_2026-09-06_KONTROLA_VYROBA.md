# V1 debata · blok 2 KONTROLA + VÝROBA — rozhodnutia (6.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable 6.9.2026 (okno „V1 plánovanie po KOVANÍ") · auditované proti kódu: ČIASTOČNE (`sheet_estimate.rb`
> D-19 kontrakt, `vepo_export.rb` D-113, `ghost_tool.rb` Z režimy) · task packages: D-94 už má package v PLANe; nárezový plán dostane package po tomto checkpointe (`codex-audit`
> áno — nový modul).
>
> Pred implementáciou platí postup z [README.md](README.md). Nadväzuje na [01_D95_PLOSNA_VYROBNA_KONTROLA.md](01_D95_PLOSNA_VYROBNA_KONTROLA.md) (D-95 smer) — tento dokument ho **rozhoduje**.

## 0 · Rozhodnutia (Michal 6.9.)

| Položka | Rozhodnutie | V1? |
|---|---|---|
| **D-94 Nákup s pôvodom** | package v PLANe platí | **ÁNO** (po KOVANÍ, malá dávka) |
| **D-95 krížová kontrola** | odškrtávanie diel po diele **ide preč natrvalo**; ostáva **vizuálna kontrola** (ABS · smer kresby · smer otvárania · tagy D-27); neskôr posilniť X-ray pohľady a podobne („SketchUp pravdepodobne bude mať nejaké riešenie") | mimo V1 |
| Stráž kolízií | — | mimo V1 |
| EN DANIELI textový export | — | mimo V1 |
| **Nárezový plán fáza 2 (primitívny)** | **DO V1** — dôvod: dnes je počet platní len odhad z m² (`SheetEstimate`, koeficient prerezu 10–25 %, D-19), realita je iná; po aspoň primitívnom nárezovom pláne vieme **presne**, koľko platní treba, a keď „1 diel vychádza na celú platňu a musím objednať 2", dá sa na to pozrieť a niečo vymyslieť | **ÁNO** (rozsah §1) |
| **D-121** názvy zásuvkových dielcov > 20 znakov vo VEPO | fix hneď (implementačné okno) | **ÁNO** — fix |

## 1 · Nárezový plán — minimálny rozsah V1 (návrh Fable, potvrdiť v package)

- **Vstup:** tie isté BOM riadky ako `SheetEstimate.estimate` (rozmery, počty, materiál, duplák → zdrojový materiál) + formát platne z katalógu (`sheet_size`, fallback 2800 × 2070
  s príznakom) + **smer dekoru dielca** (K1 `grain_direction` / vlastnosť materiálu; „bez smeru" = dielec sa smie otočiť) + kerf (default 4 mm) + orez okraja platne (default 10 mm).
- **Algoritmus:** čisté Ruby, headless testovateľné (vlastná heuristika — OpenCutList je GPL: algoritmus áno, kód nie): **guillotine / police (shelf) heuristika** s triedením
  dielcov podľa výšky, rešpektovanie smeru dekoru, dielec > platňa = RED. Deterministický výsledok (rovnaký vstup = rovnaký plán), bez optimalizačných slučiek na výkon (KLINIKA
  254 dielcov musí prejsť pod sekundu).
- **Výstup:** per nákupný materiál: **počet platní**, využitie %, zoznam dielcov per platňa, **najväčší zvyšok** (orezok) per platňa; **jednoduchý obrázok** rozloženia (SVG v
  Štúdiu, sekcia **Nárezový plán** — dnes neaktívna položka navigácie, kontrakt D-19 pripravený). Rozpočet: „Materiály po tabuliach" dostane vedľa odhadu **presný počet z plánu**
  (odhad ostáva ako kontrola rozsahu; D-61 ceny za celé tabule sa napoja na plán).
- **Scope OUT:** optimalizácia na minimum odpadu (viac heuristík, rotácie bez dekoru), tlač / export plánu pre pílu, ručné presúvanie dielcov v pláne, zvyšky ako sklad, ABS
  v pláne. *(Rezanie robí VEPO — plán je pre **objednávku správneho počtu platní a rozhodovanie**, nie výrobný dokument.)*
- **Rezy:** NP-1 algoritmus + kontrakt výsledku (audit ÁNO, nový modul) → NP-2 sekcia Štúdia + napojenie rozpočtu (in-SU smoke KLINIKA: počty vs. reálne objednané platne).

## 2 · Nové postrehy Michala z KLINIKY (6.9.) — zapísané v [../../DOGFOODING.md](../../DOGFOODING.md)

- **D-122** Kontrola pri UNI farbách hlási každý dielec zvlášť → jedno upozornenie „nenahradené UNI farby" so zoskupením dielcov (V1, UI Kontroly).
- **D-123** Ghost bez zámku Z umiestňuje dolnú skrinku so soklom na dno skrinky, nie na nohy (so zámkom Z správne) → **bug**, fix (blok GHOST je uzavretý → STABILITA).
- **D-124** Predvoľby projektu v Materiáloch: default rozbalené, väčšie náhľadové štvorce s detailom pod sebou v jednom riadku (V1, malý UI rework) · podotázka **predvolený
  materiál per rola dielca** (police, dno, chrbát…) — Fable: uskutočniteľné (poradie: override dielca > predvoľba roly > materiál skrinky), stredná dávka (builder, BOM, VEPO,
  šablóny); dnes to kryje override dielca + šablóna s overridmi → **mimo V1** (Michal: „ak áno, mimo V1").

## 3 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../PLAN.md](../../PLAN.md) blok 2: D-95 → zásobník (s odkazom na koncept 01, „odškrtávanie preč, vizuálna kontrola + X-ray neskôr"); stráž kolízií + EN DANIELI → zásobník;
  nárezový plán → **V1 rozsah** s odkazom sem; D-121 fix; D-122/D-124 pridať jednou vetou; D-123 do bloku 3.
- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 6: doplniť „nárezový plán — presný počet platní" do V1 rozsahu; „Mimo V1" doplniť D-95 kontrolu diel po diele (natrvalo), stráž kolízií, EN DANIELI.
- [../../DOGFOODING.md](../../DOGFOODING.md): D-95 presunúť do skupiny Po V1 — zásobník s prepísaným stavom.
