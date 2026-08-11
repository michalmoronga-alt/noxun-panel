# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (uzáver etapy = minor bump).
> **Údržba:** pri uzávere dávky sa jej riadok z bloku odstráni, odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a prepíše sa [STAV.md](STAV.md). Plné znenie otvorených D-čísel žije v [08_DOGFOODING.md](08_DOGFOODING.md) — tu je len číslo, názov a jedna veta.

## Bloky

### 1 · UPRATANIE — beží

**Cieľ:** dokumentácia a repo tak, aby agent na štarte sedenia do dvoch minút vedel, kde projekt je, čo sa robí a kam sa pozrieť pri probléme.

- **U1 — kronika + STAV + PLAN** *(beží)*: vyrezanie histórie do [archiv/KRONIKA.md](archiv/KRONIKA.md), nový [STAV.md](STAV.md) a tento súbor, zrušená stará roadmapa, prelinkovanie celého repa, guard test štruktúry.
- **U2 — čistka zápisníka**: v [08_DOGFOODING.md](08_DOGFOODING.md) ostanú LEN otvorené D-čísla zoskupené podľa blokov tohto plánu; história (2A migračná mapa, hardening zoznamy, priebeh seedu) do archívu; dáta merača D-25 do [zdroje/](zdroje/) ako podklad UI 2.0.
- **U3 — diéta CLAUDE.md**: sekcia Architektúra → nová `docs/ARCHITEKTURA.md` (referencia čítaná pri práci na kóde) + tabuľka povinného čítania podľa typu zásahu; mapa v STAV.md sa prepne na ARCHITEKTURU.
- **U4 — presuny a uzáver**: `00_VIZIA` a `06_PANEL_NASTAVENIA_navrh` do archívu (otvorené body sú už zaradené nižšie), `docs/ARCHIWOOD_INSPIRACIA.md` do [zdroje/](zdroje/), premenovanie súborov na mená bez čísel, README, checkpoint verzie; lokálne (bez PR) zmazanie starých worktrees a zmergovaných vetiev.

**Pravidlo dávok:** U1–U4 sa NEstackujú — každá štartuje z čerstvého `main` až PO mergi predchodcu.

### 2 · RETRO — workflow retrospektíva (samostatná session)

**Cieľ:** prejsť spôsob práce Michal ↔ Claude ↔ Codex a doladiť pravidlá, ktoré sa usadili praxou (nie kód).

- Vstup: skúsenosti zo série KLINIKA — čo brzdilo (opakované vysvetľovanie kontextu, veľkosť PR, poradie auditov), čo fungovalo (codex-audit pred implementáciou, PR popis zrozumiteľný z mobilu).
- Výstup: úprava [../CLAUDE.md](../CLAUDE.md), skillov `codex-audit` / `codex-po-pr`, pravidiel PR popisov a testovacej slučky.

### 3 · UI 2.0 — štúdio okno a výbery

**Cieľ:** satelitné okná → jedno štúdio okno s toolbarom a bočnou navigáciou; výber materiálu/ABS na jeden klik namiesto scrollovania. **Mockup PRED implementáciou** (vzor Materiály 2.0 — schválený klikateľný HTML). Podklad: merač používania D-25 (materiály/ABS vyše 400 interakcií, taby 287×, satelitné okná 234×) a [07_UI_VIZIA.md](07_UI_VIZIA.md); cieľový obraz v [10_V1_VIZIA.md](10_V1_VIZIA.md) §6.

- **D-50 · OCL inšpirácia UI/UX** — prebrať detaily z OCL flow (najprv slovné sedenie, potom zapracovanie); vzory áno, GPL kód nie.
- **D-51 · Štandard veľkostí okien a tlačidiel** — zjednotiť šírky a rozmiestnenie naprieč oknami, konkrétne hodnoty do [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) pred Luciiným nasadením.
- **D-69 · Jednotný editor materiálov** — jedno modálne okno pre pridanie z Demosu / ručné pridanie / editáciu, rovnaké polia bez ohľadu na vstupný bod.
- **D-85 · Hľadanie vo VŠETKÝCH selectoch materiálov a ABS** — jeden zdieľaný combobox s písaním a filtrom bez diakritiky + sekcia „Použité v projekte" + naposledy použité; platí aj pre selecty ABS pások.
- **D-16 · Autocomplete dekoru** — obsahovo splynulo s D-85; samostatne sa už nerieši, ale ABS časť nesmie z rozsahu D-85 vypadnúť.
- **D-15 · „Pridávačky" ako modal** — všetky akcie „pridať niečo" (šablóna, materiál, položka) na jeden UX vzor.
- **D-26 · Režim Jednoduchý/Rozšírený** — rozhodnúť spolu s reworkom; kandidáti na skrytie z merača sú známi (orientácia a odsadenie výstuh, vodorovné delenia, režim sokla, reset kovania).
- **D-27 · Rýchle zobraziť/skryť tagy z panela** — mini prepínače (Čelá, Chrbát) v logike Ghost checkboxu.
- **D-77 · Okno detailu dielca je po otvorení odseknuté** — spodná časť nastavení nie je vidieť, kým sa okno ručne nezväčší.
- **D-84 · Čelá: tlačidlá rečou stolára** — „+ pridaj čelo" / „+ pridaj dvere", „− riadok" odpadá (mazanie krížikom pri riadku).
- **D-86 · Smer dekoru vo vkladacej karte sa ticho vráti na predvoľbu** — vlastný guard: prepíš pole len pri skutočnej zmene materiálu.
- **D-89 (otvorená časť) · Orientácia hrán v UI** — hover hrany v karte dielca / ABS editore zvýrazní zodpovedajúcu hranu priamo v MODELI, prípadne slovné označenie strany. *(Časť „podľa pravidla povie výsledok" je hotová ako D-102.)*
- **D-96 · Úchytkový profil do vlastnej sekcie „Úchytky"** — výber profilu, hrany osadenia a rozsahu na jednom mieste; ikona v riadku čela ostane len indikátor.
- **Nové: klik na materiál/ABS → zvýraznenie miest použitia v projekte** — z katalógu vidieť, kde presne dekor v zákazke je.
- **Z vízie V1:** header panela ako prístup ku všetkému (UX-02) · karta Zóna so smerovými ikonami (UX-06) · polia šírkou podľa obsahu (UX-03) · viditeľný rozdiel „(podľa projektu)" vs. explicitná voľba.

*(Seed katalógu ako krok je ZRUŠENÝ (Michal 10.8.) — katalóg rastie sám prácou na zákazkách; skutočný problém „nájsť materiál aj v malom zozname" rieši D-85. Podklad kódov a cien ostáva v [zdroje/SEED_KATALOG_2026-07.md](zdroje/SEED_KATALOG_2026-07.md).)*

### 4 · KONTROLA + VÝROBA

**Cieľ:** dotiahnuť krížovú kontrolu zákazky pred odoslaním do výroby a výrobné výstupy.

- **D-94 · Traceability v súpise kovania** — rozklik nákupného riadku na skrinky a čelá, z ktorých vznikol (dáta `sources` už existujú) + klik-select v modeli.
- **D-95 · Režim krížovej kontroly „diel po diele"** — riadený prechod zákazkou s odškrtávaním, stav uložený v zákazke; rozšírenie na rozmery a kovanie, šípky smeru dekoru, X-ray. *(Vizuálny základ pre olep už stojí: D-104 + D-105.)*
- **EN DANIELI textový export** výrobného zadania — supplier-agnostický výstup, vedome odložený z dávky E.
- **Nárezový plán fáza 2** — guillotine, kerf, orezky, orientácia dekoru; vlastná heuristika v čistom Ruby (OpenCutList je GPL — algoritmus áno, kód nie), kontrakt D-19 pripravený.
- **Stráž kolízií** — upozorniť, keď sa dielce prekrývajú alebo vyskočia mimo box (bbox check do validačnej vrstvy semaforu).

### 5 · STABILITA

**Cieľ:** synchronizácia panela s modelom a okrajové situácie observerov.

- **D-101 · Panel sa po Späť/Znova neobnoví** — `ModelObserver` s `onTransactionUndo`/`onTransactionRedo` v existujúcom lifecycle panela; vlastná malá dávka s auditom a in-SketchUp behom.
- **D-99 · Glitch názvov kópií pri premenovaní dielca** — nereprodukované pozorovanie, dáta boli správne; sleduje sa.
- **Redo po zlúčených transparentných operáciách** — manuálne overiť Ctrl+Y (Ruby API nemá na Windows spoľahlivú redo akciu); otvorené od 17.7.
- **Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zlyhá** — odložené, rieši sa s knižnicou/editorom typov.

### 6 · V1 DOTIAHNUTIE

**Cieľ:** kompletná reálna zákazka od návrhu po objednávky bez opustenia pluginu a bez ručného dopočítavania — definícia a princípy v [10_V1_VIZIA.md](10_V1_VIZIA.md).

- **Kovanie fáza 3:** výklopy podľa hmotnosti čela (C-05 — generic_type lift + AVENTOS tabuľky, hustoty z M-C ako SNAPSHOT do modelu) · výplne šuflíkov ako vyrábané dielce (V1-05 — Atira dno+chrbát, Quadro/Tandem) · smer otvárania a typ závesu · hmotnostné Blum tabuľky · automatika počtu nôh podľa šírky · „Použiť na podobné".
- **Spotrebiče S1** (V1-02) — katalóg, položky projektu s väzbou na skrinku, kontrola niche semaforom, sekcia v rozpočte.
- **Ceny a dokumenty ponuky** (vedome odložené z dávky E): manuálne 1-klik overenie ceny pre položky BEZ väzby na Demos a viac URL na položke (zvyšok V1-03) · plný generátor cenovej ponuky do DOCX/PDF so šablónou a vizualizáciami · prepínač „na faktúru" (×1,2, kandidát na štvrtý cenový režim) · rodina dokumentov okolo ponuky (ponuka vizualizácií, preberací protokol).
- **Konštrukcia:** per-dielec odsadenia vpredu/vzadu pre strop/dno/boky (V1-01, chladničkový komín) · typy čiel lakované / frézované / sklo-Al rám (V1-07) · balík V0.4.8 z `06_PANEL_NASTAVENIA_navrh` — rohové spoje dna a stropu per strana, chrbát s poldrážkou, „bez dielca" varianty s validáciou, per-dielec hrúbky a odsadenia.
- **Vkladanie na klik** (V1-04 fáza 1) — skrinka visí na kurzore, klik umiestni.
- **D-09 · Snap body pri presúvaní priečok** — 1/4, 1/2, 3/4 v zónovom náhľade.
- **D-10 · Presúvanie a úprava čiel priamo v náhľade** — ako drag priečok.
- **V1.0 zostavy:** spájanie a zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, snaper logika) · soklová lišta v celku pre segment · obklady a krycie prvky segmentu vrátane pilastra (priznaný vs. skrytý) · pracovné a horné krycie dosky na označený segment · migrácia a oprava starých modelov · test na kompletnej reálnej zákazke. *(Sem patrí aj to, čo V0.4.7 vedome neobsahovalo: attachment/segmenty, automatické krycie dosky, PD cez segment.)*

### 7 · RENDER M-R

**Cieľ:** materiál vyzerá v modeli ako v skutočnosti — Luciin nástroj na vizualizácie.

- **D-28 · Textúry materiálov = M-R knižnica vzhľadov** (D-28 je do M-R zlúčená, samostatne sa nerieši): `texture_path` + render vlastnosti PBR + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 = orientácia textúry podľa smeru dekoru dielca. Zdroj JPG knižnica na firemnom Disku; väzba na D-48.
- **D-87 · Vizuálne zobrazenie SMERU štruktúry v modeli** — overlay čiar v smere dekoru na dielcoch (vzor ghost zón) ako rýchla kontrola orientácie celej zákazky; logicky sa rieši s textúrami a nárezovým plánom.
- **Nástroj „pixla"** (V1-06) — ikonka na dlaždici materiálu, klik prefarbuje dielce cez `part_override` cestu (1 klik = 1 undo).

### 8 · INFRA (priebežne, podľa potreby)

**Cieľ:** aby plugin a knižnice fungovali na dvoch pracoviskách (Michal + Lucia).

- **D-48 · Zdieľaná knižnica pre 2 PC** — katalóg materiálov, šablóny a pravidlá kovania z jedného zdroja (firemný Google Disk) namiesto lokálneho `%APPDATA%`.
- **D-52 · Tlačidlo „Aktualizovať" (auto-update pluginu)** — jednoklikový update, distribučný kanál spolu s D-48.
- **D-20 · Quick actions — bezpečný move plugin** — zlúčiť noxun_mower + Snaper do jedného toolbaru; kopírovanie musí prejsť štandardným dedup tickom (dnes vzniká kópia bez NOXUN identity).

## Po V1 — zásobník (nezaradené, nestratiť)

- Rohová a vysoká/potravinová skrinka ako **nové TYPY builderov** (odvodia sa od dolnej/hornej).
- Zóny priamo vo viewporte (variant B vízie) — nadstavba 2D náhľadu.
- **Interact pre čelá** — dráhy otvárania, klik = otvorenie, merač kolízií pri otvorení (dáta máme: origin čiel na hrane pántu; typ pántu určuje dráhu).
- Náhľad povýšiť na „otvárací náhľad" panela so zobrazovaním zvolených elementov.
- **Injecting dát do knižníc v dávkach** (kódy, materiály, kovania, spotrebiče, vybavenie) — architektúru pripraviť skôr.
- Zásuvkové bloky (dočasne DC Atira most) · vnútorné vybavenie (koše, tyče) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy a etikety · CNC.
- Pracovné dosky ako súčasť dekorovej skupiny — dátovo pripravené cez `sheet_variants` (D-42); doriešiť, keď si to prax vypýta.
- Odložené Demos prefixy: `hpdb` · `hrdb`/`hrll` · `dverny-plast` · `perfectsense`/`dtl`/`eurolight`/`lam` · `mdfd` (dyhovaná MDF).

## Pravidlo pre postrehy (Michal)

**Píš postrehy HNEĎ, keď ich vidíš — hocikedy, hociktorú tému.** Nemusíš strážiť, čo je kedy v pláne — ja každý postreh zaradím: buď do bežiacej etapy (ak sa týka), alebo do backlogu nižšie s označením etapy. Nič sa nestratí. Krátka veta stačí („boky majú stáť na dne, nohy pod tým") — doplňujúce otázky si vyžiadam sám.

**Triedenie hlásení (dohoda 25.7.):** bežiaca etapa · priebežné dopĺňanie · celková vízia · **odklad do V1** — kým sa k V1 dostaneme, zbierame dáta, a z odložených tém sa potom poskladajú ďalšie bloky V1–V2. Trvalé fakty domény (stolárske poznatky, pojmy) idú do [09_POJMY.md](09_POJMY.md).

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.
