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
| **Nárezový plán fáza 2 (primitívny)** | **DO V1** — dôvod: dnes je počet platní len odhad z m² (`SheetEstimate`, koeficient prerezu 10–25 %, D-19), realita je iná; po aspoň primitívnom pláne vieme, koľko platní **najviac** treba (**horná hranica podľa zvoleného rozloženia**, nie presné množstvo — Codex #322), a keď „1 diel vychádza na celú platňu a musím objednať 2", dá sa na to pozrieť a niečo vymyslieť | **ÁNO** (rozsah §1) |
| **D-121** názvy zásuvkových dielcov > 20 znakov vo VEPO | fix hneď (implementačné okno) | **ÁNO** — fix |

## 1 · Nárezový plán — návrh rozsahu → samostatný dokument (rozdelenie PR #322 podľa pravidla 3 kôl)

Vstup, algoritmus, výstup, napojenie na rozpočet, scope OUT a rezy NP-1/NP-2 žijú v **[NAREZ_PLAN_NAVRH_2026-09-06.md](NAREZ_PLAN_NAVRH_2026-09-06.md)** (vlastný PR a review). Zapracované nálezy Codex #322
kôl 1–3: počet platní = **horná hranica podľa zvoleného rozloženia** (nie presné množstvo, objednáva človek) · jedna politika otáčania dielcov bez smeru dekoru ·
**duplák sa pred rozkladom rozvinie na `množstvo × multiplier` fyzických obdĺžnikov** zdrojového materiálu (ako `SheetEstimate` násobí plochu). Tu ostáva len rozhodnutie
(§0: primitívny nárezový plán je vo V1) a jeho dôvod.

## 2 · Nové postrehy Michala z KLINIKY (6.9.) — zapísané v [../../DOGFOODING.md](../../DOGFOODING.md)

- **D-122** Kontrola pri UNI farbách hlási každý dielec zvlášť → jedno upozornenie „nenahradené UNI farby" so zoskupením dielcov (V1, UI Kontroly).
- **D-123** Ghost bez zámku Z umiestňuje dolnú skrinku so soklom na dno skrinky, nie na nohy (so zámkom Z správne) → **bug**, fix (blok GHOST je uzavretý → STABILITA).
- **D-124** Predvoľby projektu v Materiáloch: default rozbalené, väčšie náhľadové štvorce s detailom pod sebou v jednom riadku (V1, malý UI rework) · podotázka **predvolený
  materiál per rola dielca** (police, dno, chrbát…) — Fable: uskutočniteľné (poradie: override dielca > predvoľba roly > materiál skrinky), stredná dávka (builder, BOM, VEPO,
  šablóny); dnes to kryje override dielca + šablóna s overridmi → **mimo V1** (Michal: „ak áno, mimo V1").

## 3 · Dopad na živé dokumenty (zapracuje záverečný docs PR debaty)

- [../../PLAN.md](../../PLAN.md) blok 2: D-95 → zásobník (s odkazom na koncept 01, „odškrtávanie preč, vizuálna kontrola + X-ray neskôr"); stráž kolízií + EN DANIELI → zásobník;
  nárezový plán → **V1 rozsah** s odkazom sem; D-121 fix; D-122/D-124 pridať jednou vetou; D-123 do bloku 3.
- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 6: doplniť „nárezový plán — horná hranica počtu platní podľa rozloženia" do V1 rozsahu; „Mimo V1" doplniť D-95 kontrolu diel po diele (natrvalo), stráž kolízií, EN DANIELI.
- [../../DOGFOODING.md](../../DOGFOODING.md): D-95 presunúť do skupiny Po V1 — zásobník s prepísaným stavom.
