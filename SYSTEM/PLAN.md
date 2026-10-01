# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (minor bump = výhradne uzáver bloku).
> **Evidencia (od 26.9.2026):** hotová dávka **ostáva v bloku ako riadok s ✅ a číslom PR** (pred `gh pr create` `PR #?`, číslo doplní samostatný commit hneď po vytvorení PR);
> odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a [STAV.md](STAV.md) sa prepíše pri zvýšení VERSION, pri dokumentačnom PR, ktoré mení stav bloku, smoke alebo poradie prác, sa v ňom aktualizuje faktický stav v „Stav" (verzia a čísla testov sa nemenia) a prepíšu „Robí sa" a „Ďalší krok".
> Blok sa presúva plným textom do [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md) až s **uzáverom bloku** (fajka patrí do riadku, nikdy do nadpisu — stráži guard).
> Plné znenie otvorených postrehov žije v [DOGFOODING.md](DOGFOODING.md) **v skupinách podľa týchto blokov** — tu je len číslo, názov a jedna veta; skupina „smoke po uzávere" je dočasná a zanikne s posledným nálezom.
> **Priečinok bloku** (debata, mockup, packages, briefy, smoke checklist) je od štartu bloku v `SYSTEM/zdroje/bloky/<BLOK>/` — nie v `_dev/` ani v chate; blok tu naň odkazuje
> a po uzávere sa celý priečinok fyzicky presúva do `SYSTEM/archiv/bloky/<BLOK>/` s kontrolou odkazov (staršie mockupy v `zdroje/ui20/` sa nepresúvajú).
> **Veľkosť (od 1.10.2026, dávka H1):** PLAN drží len živé bloky, zásobník a pravidlá plánovania — **max 280 riadkov a 40 kB** (stráži guard test). Zadanie dávky patrí do priečinka
> bloku, nie sem; hotový blok aj hotová časť bloku idú plným textom do archívu.

## Bloky

**Uzavreté bloky** — plné texty v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md), priebeh dávok v [archiv/KRONIKA.md](archiv/KRONIKA.md); čísla blokov sa kvôli
odkazom v STAV a KRONIKE neprečíslúvajú:

- **1 · UI 2.0** (v0.8.0, 24.8.2026) · **PICKER-3** (v0.8.5, 26.8.) · **1b STABILIZAČNÁ REVÍZIA**, **1c AUDIT KÓDU**, **1d REFAKTOR Z REGISTRA**, **1e PLÁNOVACIA DÁVKA**
  (27.8.–1.9.2026; 1b, 1d a 1e formálne uzavreté 1.10.2026 dávkou H1) · **GHOST VKLADANIE** (v0.9.0, 31.8.) · **KOVANIE** (v0.10.0, 10.9.) a balík **Čiel** (v0.11.0, 11.9.) ·
  **M-R VZHĽAD** (v0.12.0, 12.9.).
- **5 · SPOTREBIČE S1** (v0.13.0, 24.9.; [výsledok](archiv/S1_ZAVER_2026-09-24.md)) · **7 · KONŠTRUKCIA K1+K2** (v0.14.0, 27.9.; [výsledok](archiv/KONSTRUKCIA_ZAVER_2026-09-27.md),
  [priečinok](archiv/bloky/KONSTRUKCIA/)) · **8 · K3 ROHOVÁ SKRINKA** (v0.15.0, 28.9.; [výsledok](archiv/ROHOVA_ZAVER_2026-09-28.md), [priečinok](archiv/bloky/ROHOVA/)) ·
  **2 · KONTROLA + VÝROBA** s nárezovým plánom (v0.16.0, 29.9.; [výsledok](archiv/NAREZ_ZAVER_2026-09-29.md), [priečinok](archiv/bloky/NAREZ/)) · **CENY** (v0.17.0, 30.9.;
  [výsledok](archiv/CENY_ZAVER_2026-09-30.md), [priečinok](archiv/bloky/CENY/); smoke PASS 30.9.2026).
- **4 · V1 DOTIAHNUTIE** a **6 · INFRA** — formálne uzavreté 1.10.2026 dávkou H1 (**V1 hotové**; blok 6 = updater D-52, v0.9.14). Otvorené zvyšky sú v bloku 9 a v zásobníku nižšie.

### 9 · HARDENING PO V1 (štart 1.10.2026 — krížový audit V1)

**Cieľ:** pred funkciami po V1 opraviť zavádzajúce údaje v okne, spevniť ochranu dát a zlacniť ďalšie rozširovanie (nový typ skrinky, sekcia Štúdia,
kovanie, zdieľané knižnice) — **bez zmeny výrobných a cenových čísel** (charakterizačné/golden testy pred zásahom; UI zmeny nič nepočítajú). Podklad:
krížový audit 7 audítorov → Michalovo triedenie **35 Teraz · 29 Po V1 · 11 vyradených**; priečinok bloku [zdroje/bloky/HARDENING/](zdroje/bloky/HARDENING/)
(rozhodnutia a výsledok triedenia, podklad, surové výstupy `CROSS_AUDIT_A*`, triediaca stránka). **Poradie = poradie tabuľky** (Michal 1.10.: bez viazania na
noci — beh spracuje sekvenčne, koľko stihne). **H6 a H7 čakajú na Michalom schválený mockup** (mockupy sa pripravia počas H1–H5). Trieda dávky (audit,
predrecenzia, in-SU) sa určí pri package podľa CLAUDE.md; stĺpec je predpoklad. Uzáver bloku = minor verzia + smoke.

| Dávka | Položky (ID z triedenia) | Predpokladaná trieda |
|---|---|---|
| ✅ H1 · pravidlá čítania pre agentov (kapitoly namiesto celých súborov, PLAN bez hotových blokov, STAV po docs PR, hranice triedy dávky) — **PR #433** | B-01 · B-04 · B-08 · B-09 | dokumentácia |
| ✅ H2 · fotenie okien pre UI PR (prehrávač dát pluginu + fotky Inspectora a sekcií Štúdia) — **PR #434** | D-10 | nástroj, plugin sa nemení |
| ✅ H3a · zavádzajúce údaje v okne (platne v Kusovníku → preklik do Nárezového plánu, tabuľka ponuky, semafor Kontroly, Nákup po slovensky, sadzby) — package [PACKAGE_H3.md](zdroje/bloky/HARDENING/PACKAGE_H3.md) — **PR #435** | A-01 · A-02 · A-03 · A-04 · A-07 | kód · výrobná/cenová (zobrazenie) |
| ✅ H3b · log po otvorení nového súboru (vypnutie prekrytia zatvoreného dokumentu bez falošnej chyby) — package [PACKAGE_H3.md](zdroje/bloky/HARDENING/PACKAGE_H3.md) §6.6 — **PR #436** | A-06 | kód · in-SU (audit len pri zmene toku) |
| H4 · jazyk, čísla a vzhľad (formát čísel a jednotiek, Obnoviť, texty, rozbaľovačky a stĺpce, ikona, ABS „dookola") | D-04 · D-06 · D-07 · D-08 · D-09 · D-11 | kód UI |
| H5 · dokumentácia okien a UI dizajnu (aktuálny stav oddelený od histórie, strážca rastu, zastarané vety) | B-02 · B-03 · B-05 | dokumentácia |
| H6 · priestor v Inspectore (nápovedy, pás, spodné tlačidlá, kóty náhľadu, súhrny sektorov) | D-01 · D-02 · D-05 | kód UI · mockup |
| H7 · názov zákazky na jednom mieste + nastavenia exportu v jadre — **pred presunom ochrana R-38** (poškodený súbor nastavení exportu sa nesmie ticho prepísať zálohou; výsledok zápisu sa ukáže; R-38 = návrh — potvrdí Michal s mockupom H7) | A-05 · C-07 · R-38 | kód · mockup · audit |
| H8 · dielec z inej verzie štandardu (ORANGE) | R-13 | kód · audit |
| H9 · ochrana nastavení dodávateľa pred seedom | R-37 | kód · audit |
| H10 · dve okná SketchUpu neprepíšu pravidlá kovania a rady | R-35 | kód · audit |
| H11 · SketchUp 2026.2 (ukončenie bez pádu, načítanie súborov) + minimum SketchUp 2026 | F-01 · F-02 | kód · audit · in-SU |
| H12 · typy skriniek na jednom mieste + mená rolí | C-01 · C-05 | kód · audit · in-SU · výrobná |
| H13 · mapa rozširovacích bodov (vrátane pravidiel viazaných na typ) + tabuľka verzií dát | B-06 · B-07 | dokumentácia + guard testy (po H12) |
| H14 · sekcie Štúdia na jednom mieste | C-02 | kód |
| H15 · dáta kovania oddelené od mechaniky setov | C-03 | kód · audit · výrobná |
| H16 · súpis knižníc (príprava D-48) | C-04 | kód · audit |
| H17 · spoločná príprava exportov (prvý rez R-15) | C-06 | kód · audit · výrobná |

### 3 · STABILITA

**Cieľ:** synchronizácia panela s modelom a okrajové situácie observerov. *(D-101 — panel po Späť/Znova — je vyriešená, PR #162.)*

- **D-99 · Glitch názvov kópií pri premenovaní dielca** — nereprodukované pozorovanie, dáta boli správne; sleduje sa.
- **D-117 · Nestabilný in-SU test „GHOST suspend: aktívny nástroj po upratovaní"** — raz zlyhal (MeasureTool namiesto SelectionTool), opakovaný beh prešiel; asercia má overovať návrat PÔVODNÉHO nástroja (ghost používa `push_tool`), nie SelectionTool.
- **Redo po zlúčených transparentných operáciách** — manuálne overiť Ctrl+Y (Ruby API nemá na Windows spoľahlivú redo akciu); otvorené od 17.7.
- **Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zlyhá** — odložené, rieši sa s knižnicou/editorom typov.

## Po V1 — zásobník (nezaradené, nestratiť)

- **Z krížového auditu V1 (1.10.2026) — 29 položiek Po V1** (plný zoznam a zdroje: [zdroje/bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md](zdroje/bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md);
  R-13 → R-37 → R-35 sú od 1.10. v bloku 9 ako H8–H10): najsilnejší **E-01 snímka odovzdanej zákazky + „čo sa zmenilo od objednávky"** (4 audítori nezávisle; súvisí
  **G-02** karta zákazky, **G-05** export všetkého do datovaného priečinka) · kód a API: C-08 zásuvky podľa tvaru receptu (s prvým novým systémom; **G-01** vzorky
  z konfigurátora Blum — Michal má prístup), F-03 spoločný základ prekrytí, F-04 natívne fotenie náhľadu šablóny (jednoduchšia cesta pre **D-107**), F-05 skrytie
  okien (SketchUp 2026.1+), F-06 hláška pri zamietnutej mierke, F-07 poistka výberu, F-08 výkresy cez LayOut, F-09 drobnosti API · dokumenty: B-10 strážca
  modelov agentov, B-11 workflow pravidlá na jednom mieste, B-12 skill Codex auditu, B-13 rozdelenie runnera testov (spolu s položkou nižšie) · UI a nápady:
  D-03 skratky cez menu, E-03 rad skriniek naraz, E-05/G-04 prehľad skriniek v Kusovníku, E-07 hmotnosť a logistika zákazky, E-08 Kusovník po stene, E-10 skok
  z dielca na platňu, E-11 rozpracované zákazky, E-12 zákaznícky názov položky, E-13 odhad hodín dielne, G-06 poznámka ku skrinke, G-07 pravý klik na skrinku,
  G-08 štetec dekoru.
- **Akceptačný test V1 na kompletnej reálnej zákazke** (Michal 29.–30.9.2026, rozhodnutia CENY C10/C13) — po V1; pôvodne riadok „V1.0 zostavy" bloku 4 (archív).
- **Otvorené R-čísla registra auditu 1c** — autorita a verdikty: [AUDIT_REGISTER.md](AUDIT_REGISTER.md), sekcia „Stav po previerke 29.9.2026". R-13, R-37 a R-35 sú v bloku 9
  (H8–H10), R-38 v H7 (návrh), prvý rez R-15 v H17; ostatné platné položky sú po V1 (R-05 = D-109 nižšie). Pravidlo pre dávky z registra: **Pravidlá plánovania dávok** nižšie.
- **D-48 · Zdieľaná knižnica pre 2 PC (Michal + Lucia)** (mimo V1 od 26.8.2026) — **prvá funkcia po V1** (rozhodnuté 6.9.2026) v tvare Odoslať / Aktualizovať s verziami per katalóg, konflikt ručne,
  koreň `H:\Môj disk\NoxunENGINE data`, odhad 3 PR; patrí k nej aj zdieľanie `.skm`. Rozhodnutia
  [zdroje/next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md](zdroje/next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md), mechanizmus `zdroje/next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md`
  (PR #323); plné znenie v [DOGFOODING.md](DOGFOODING.md); príprava = blok 9 · H16 (C-04 súpis knižníc); dovtedy katalógy ručne. Updater D-52 je hotový (v0.9.14).
- **Runner testov v SketchUpe po teste sám vráti pôvodnú verziu pluginu** (workflow N4, 26.9.2026) — `scripts\run_su_tests.ps1` dnes nechá nasadenú
  rozpracovanú vetvu; dovtedy platí pravidlo „po každom mergi nainštalovať main" (CLAUDE.md, Verzia a uzáver).
- **D-147 · Nárezový plán: menšie dielce nad seba v páse** (Michal 29.9.2026, smoke bloku 2) — vnárať menšie dielce do voľného miesta pásu nad nižším dielcom (plán býva niekedy o platňu opatrnejší, než musí); plné znenie v [DOGFOODING.md](DOGFOODING.md).
- **D-146 · Falošný duplák** (Michal 28.9.2026) — spodná vrstva dupláku zo 100 mm širokých výstuh namiesto plnej dosky (šetrí materiál aj váhu, keď obe strany nie sú pohľadové); plné znenie v [DOGFOODING.md](DOGFOODING.md).
- **M-R nadstavby zo smoke 12.9.2026:** **D-126** otočenie zdrojového obrázka o ±90° pred uložením; **D-127** prirodzenejšie umiestnenie textúry (náhodný posun, nadväzovanie na skrinke alebo ručné umiestnenie — výber podľa praxe Lucie). Odložené, bez termínu, neblokujú uzáver M-R; plný kontext v [DOGFOODING.md](DOGFOODING.md).

- **Mimo V1 z bloku KOVANIE** (FINAL §12; presunuté sem 10.9.2026 pri uzávere bloku): **D-109** pomerový člen setu „1 ks na N nôh" (= **R-05**; výsledok dnes dáva pravidlo
  `prichyt-sokla` podľa šírky korpusu, chýba len samotná mechanika pomeru) · plný `per: 'length'` · **HF** · ďalšie zásuvkové systémy **Antaro / StrongBox / TANDEM**
  (dáta pripravené v checkpointe #10) · automatika **vnútornej zásuvky** (inner drawer).
- **Vyradené z V1 rozsahu 26.8.2026** (dôvody a rozsah: [V1_VIZIA.md](V1_VIZIA.md) „Mimo V1“): plné zostavy/segmenty s `attachment` (koncept 02;
  rozsah z rozhodnutia 4.9.2026: segmentová automatika soklovej lišty, obkladov a krycích prvkov vrátane pilastra, pracovné a horné krycie dosky na segment, migrácia starých modelov;
  pred blokom **agy outside-in rešerš „automatický pilaster / pracovná doska"**) · pixla (koncept 06; M-R vzhľad implementovaný v #353–#359) ·
  DOCX/PDF ponuka s vizualizáciami a rodina dokumentov (koncept 08) · sektorová kontrola (koncept 01) ·
  konfigurátor typov čiel (V1-07 nad rámec cenovej položky) · kovanie fáza 3 geometria (plný model výklopov, výplne fáza B).
- **Potvrdené / vyradené z V1 6.9.2026 (debata V1 po KOVANÍ, checkpointy `zdroje/next_sessions/V1_DEBATA_2026-09-0*.md`):** **D-95** krížová kontrola diel po diele — **uzavreté bez implementácie** (archív; odškrtávanie preč natrvalo), ostáva vizuálna kontrola, neskôr presety/X-ray (koncept 01) · **stráž kolízií** · **EN DANIELI** textový export · **D-106** predbežná cena skrinky ·
  **D-10** čelá ťahaním v náhľade · **pixla** (V1-06) · rohové spoje per strana · poldrážka · „bez dielca" · V1-07 čelo ako cenová položka + konfigurátor typov čiel ·
  digestorový korpus · LeMans rohový výsuv · materiál per rola dielca (D-124b) · kontrola rúra/mikro + police podľa niky + vetranie (S1 V1+).
- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** — automatické dočasné skrytie zvyšku modelu pred `view.write_image`. *Michal 20.8.: nízka priorita / vysoká náročnosť (skrývanie geometrie = zápis do modelu, undo kroky, observery). Medzitým stačí ručné „Odfotiť" v okne Šablóny — skrinku si naaranžuje a izoluje používateľ sám.*
- **Horná** rohová skrinka (vyradená z V1 6.9.2026; dolná slepá rohová **K3 je hotová** v bloku 8, v0.15.0) a vysoká/potravinová skrinka ako **nové TYPY builderov** (odvodia sa od dolnej/hornej).
- Zóny priamo vo viewporte (variant B vízie) — nadstavba 2D náhľadu.
- **Interact pre čelá** — dráhy otvárania, klik = otvorenie, merač kolízií pri otvorení (dáta máme: origin čiel na hrane pántu; typ pántu určuje dráhu).
- Náhľad povýšiť na „otvárací náhľad" panela so zobrazovaním zvolených elementov.
- **Injecting dát do knižníc v dávkach** (kódy, materiály, kovania, spotrebiče, vybavenie) — architektúru pripraviť skôr.
- Zásuvkové bloky **na novom štandarde** (DC „Atira most" ZAVRETÝ 26.8.2026 — §12 bod C2, KRONIKA) · vnútorné vybavenie (koše, tyče) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy a etikety · CNC.
- Pracovné dosky ako súčasť dekorovej skupiny — dátovo pripravené cez `sheet_variants` (D-42); doriešiť, keď si to prax vypýta.
- Odložené Demos prefixy: `hpdb` · `hrdb`/`hrll` · `dverny-plast` · `perfectsense`/`dtl`/`eurolight`/`lam` · `mdfd` (dyhovaná MDF).

## Pravidlo pre postrehy (Michal)

**Píš postrehy HNEĎ, keď ich vidíš — hocikedy, hociktorú tému.** Nemusíš strážiť, čo je kedy v pláne — ja každý postreh zaradím: buď do bežiacej etapy (ak sa týka), alebo do backlogu nižšie s označením etapy. Nič sa nestratí. Krátka veta stačí („boky majú stáť na dne, nohy pod tým") — doplňujúce otázky si vyžiadam sám.

**Triedenie hlásení (dohoda 25.7.):** bežiaca etapa · priebežné dopĺňanie · celková vízia · **odklad do V1** — kým sa k V1 dostaneme, zbierame dáta, a z odložených tém sa potom poskladajú ďalšie bloky V1–V2. Trvalé fakty domény (stolárske poznatky, pojmy) idú do [POJMY.md](POJMY.md).

**Doplnok k triedeniu (dohoda 20.8.): z pluginu sa objednávajú REÁLNE ZÁKAZKY.** Nálezy z reálnej výroby (chybný rozmer, zlá orientácia, nesprávny olep, nekompletný nákup) a **chyby v cenách a
  rozpočtoch** majú **najvyššiu prioritu triedenia — nad plánované bloky**. Predbiehajú bežiacu etapu aj naplánované dávky: keď plugin pošle do výroby alebo do objednávky zlé číslo, stojí to peniaze a
  dôveru, a žiadna rozpracovaná dávka to nevyváži. Zaraďujú sa hneď, s plným kontextom incidentu (čo bolo objednané, čo prišlo, kde to plugin ukázal alebo neukázal) — vzor: **D-108** (kresba blendy vs.
  dverí, incident 19.8.).

## Pravidlá plánovania dávok (prenesené doslova z blokov 1d a 1e pri ich archivácii 1.10.2026)

**Šablóna package (blok 1e, 30.8.2026):** Package = plné zadanie dávky; dnes žije v priečinku bloku `zdroje/bloky/<BLOK>/` (CLAUDE.md, Verzia a uzáver). **Šablóna package (povinné polia):**
cieľ · scope IN · **scope OUT** (čo dávka vedome NErobí) · dotknuté dáta/kontrakt → audit áno/nie · testy a DoD · riziká · smoke checklist pre Michala · checklist uzáveru. Každý package si na štarte
spraví krátky read-only audit proti aktuálnemu mainu. Agenti si potom packages preberajú sekvenčne bez ďalšieho plánovania.

**Dávky z registra auditu a refaktory (blok 1d, 29.8.2026):** Register sa vyprázdňuje **malými dávkami** (malé PR > obrie PR), zoradené podľa závažnosti × blokovanej funkcie.
Pravidlo podľa druhu dávky: **štrukturálny refaktor = „správanie sa nemení"** (presun zodpovednosti, testy to dokazujú);
**oprava chyby/hardening = explicitná, testom podložená ZMENA správania** (v PR pomenovaná: čo bolo zle → čo platí teraz).
In-SU testy povinné pri builderoch/observeroch; mutačné overenie štandard. Nálezy z reálnej výroby majú stále prednosť
(Pravidlo pre postrehy). Dávka, ktorá nevie povedať, ktorú naplánovanú funkciu pripravuje alebo ktorý dlh spláca, sa nerobí.

## Trvalé pravidlá — kde žijú

- **„Vertikálny priestor panela je vzácny"** (Michal 20.7.2026, platí pre všetku prácu na paneli) — autorita [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) **§1 Princípy**.
- **Hranica TYP vs. ŠABLÓNA vs. PARAMETER** (rozhodnuté 15.7.2026, „kedy nový typ korpusu") — autorita [STANDARD.md](STANDARD.md) **§4.2 Typy korpusov na štart**.
