# BLOK 9 · HARDENING PO V1 — výsledok, overenie a smoke (uzáver 11.10.2026, v0.18.0)

Po dokončení všetkých siedmich bodov V1 (30.9.2026) Michal 1.10.2026 rozhodol: **pred novými funkciami spevniť, čo už je** — zavádzajúce údaje v oknách, ochranu
dát a miesta, kde sa plugin dá rozširovať. Podklad bol krížový audit V1 siedmimi audítormi; Michal z neho vytriedil **35 položiek Teraz · 29 Po V1 · 11 vyradených**
([rozhodnutia](bloky/HARDENING/ROZHODNUTIA_MICHALA_2026-10-01.md)). Blok ich spracoval v dávkach **H1–H19** sekvenčne, **bez zmeny výrobných a cenových čísel**
(vedome pomenované výnimky: ŠÍRKA 50 a skutočne použitý set závesov, nižšie). Plný text bloku je v [ROADMAP_hotove_etapy.md](ROADMAP_hotove_etapy.md), celý priečinok
bloku (rozhodnutia, krížový audit, packages H3–H18 a ŠÍRKA 50 so surovými auditmi, briefy, mockupy H6 a H7) v [bloky/HARDENING/](bloky/HARDENING/).
Uzáver vo **v0.18.0** mení len dokumentáciu a číslo verzie. **Smoke čaká na Michala** — jeden zlúčený zoznam je na konci tohto dokumentu.

## Výsledok pre stolára

- **Čísla a exporty sa nezmenili.** Rozpočet, ponuka, nákup kovania, kusovník aj VEPO CSV vychádzajú z tých istých zákaziek rovnako ako pred blokom; strážia to zlaté
  testy a nový **export test** (`scripts\export_test.ps1`), ktorý sám urobí štyri exporty testovacej zákazky na starej a novej verzii a porovná ich.
- **Okná hovoria pravdu a po slovensky.** Kusovník namiesto odhadu platní ukáže odkaz na Nárezový plán; Cenová ponuka má stĺpce Položka · Množstvo · MJ · Spolu
  a „v cene" pri Zameraní a Vizualizáciách; Kontrola píše „0 zo 7 skriniek bez nálezu" a počet riadkov; Nákup kovania má slovenské nadpisy a parametre („výška čela
  150 mm"). Čísla v Štúdiu majú jednotný zápis (čiarka, celé kusy, eurá na dve desatinné, jednotky malým) a nič sa neskryje; „0,8 dookola" pri páske okolo dvierok.
  Texty bez žargónu (nikde „ghost", „seed", „legacy"), rozbaľovačky vyzerajú ako ostatné polia, mazanie riadku je ikona ×.
- **Inspector má viac miesta.** Nápovedy sú v „?" (vedľa kamery pod náhľadom a v hlavičkách skupín), dole je jeden riadok tlačidiel, zmizlo „Pripravené."; lišty sektorov
  ukazujú súhrn (napr. „2 zóny · 3 police"); kóty v náhľade majú stále 11 px a celé sa zmestia do okna.
- **Názov zákazky je na jednom mieste** — v hlavičke Štúdia (✎); platí pre VEPO, kovanie, rozpočet aj ponuku. Neuložený model ukáže jantárovú bodku „zadaj názov".
- **Poškodený súbor nastavení neprepíše dobré dáta.** Nastavenia dodávateľa, pravidlá ABS a kovania, nastavenia exportu a rozmerové rady majú ochranu pred tichým
  prepísaním seedom; zlý súbor = červený banner a čítanie zo zálohy. **Dve okná SketchUpu** si navzájom neprepíšu pravidlá kovania a rady (druhé uloženie povie, že
  medzitým zapísalo iné okno).
- **Dielec z inej verzie štandardu** je v Kontrole jeden oranžový riadok (čísla bez zmeny). **Chyba pri načítaní súboru pluginu** = jedna hláška a plugin je v okne
  vypnutý (obnova reštartom). **Minimum je SketchUp 2026** — starší SketchUp plugin nenačíta, inštalátor ho odmietne. Pád pri ukončení SketchUpu 2026.2 (#1117) sa u nás
  **nepotvrdil** (H11c, overené bez zmeny kódu).
- **Vnútri:** typy skriniek a sekcie Štúdia sú na jednom mieste (nový typ alebo sekcia = menej súborov), dáta kovania sú oddelené od mechaniky setov, je súpis knižníc
  pre budúce zdieľanie, mapa rozširovacích bodov, tabuľka verzií dát a spoločná príprava exportov (`ExportPrep`).
- **Skrinka od 50 mm** (ŠÍRKA 50): úzka dolná skrinka má 2 nohy v strede šírky a 1 príchyt sokla; pod hrúbku dosky sa šírka zblokuje s vysvetlením. Horná od 50 mm bez nôh.
- **Závesy:** Inspector ukáže **skutočne použitý set závesov** (aj starší výber skrinky) a voľba setu pri krídle platí v nákupe (H18, H18b-1).
- **Export, keď priečinok posledného exportu zmizol** (H17b): CSV kovania aj oba XLSX otvoria výber bez chyby, ako VEPO.

## Dávky

| Dávka | PR | Obsah |
|---|---|---|
| Štart bloku | #432 | rozhodnutia Michala 1.10., krížový audit (A1–A7), triedenie |
| H1 | #433 | pravidlá čítania pre agentov (kapitoly namiesto celých súborov, PLAN bez hotových blokov, STAV po docs PR, hranice triedy dávky) |
| H2 | #434 | fotenie okien pre UI PR (`scripts\ui_foto.ps1`) |
| H3a · H3b | #435 · #436 | zavádzajúce údaje v okne (Kusovník, ponuka, Kontrola, Nákup, sadzby) · log po otvorení nového súboru |
| H4a · H4b | #437 · #438 | jednotný zápis čísel a jednotiek · texty a vzhľad (Obnoviť vs. vrátenie katalógu, žargón, rozbaľovačky, ikony) |
| H5a · H5b | #439 · #440 | dokumentácia okien a UI dizajnu: aktuálny stav oddelený od histórie |
| H6a · H6b · H6c | #453 · #454 · #455 | priestor v Inspectore: nápovedy do „?" a spodok · lišty a súhrny · kóty náhľadu |
| H7a · H7b | #456 · #457 | nastavenia exportu v jadre + ochrana R-38 · názov zákazky v hlavičke + povinný `expect` pri 4 exportoch |
| H8 | #441 | dielec z inej verzie štandardu (R-13) |
| H9 | #442 | ochrana nastavení dodávateľa, pravidiel ABS a kovania pred seedom (R-37) |
| H10a · H10b | #443 · #444 | dve okná: pravidlá kovania · rozmerové rady (R-35) |
| H11b · H11a | #445 · #458 | minimum SketchUp 2026 · načítanie súborov pluginu s jednou hláškou + nástroj quit testu |
| H11c | bez PR | pád pri ukončení na 2026.2 neprejavil — uzavreté overením, kód bez zmeny |
| H12a · H12b · H12c · H12d | #446 · #447 · #448 · #452 | typy skriniek na jednom mieste (register, panel Ruby, JS zo servera) · mená rolí |
| H13 | #449 | mapa rozširovacích bodov + tabuľka verzií dát |
| H14a · H14b · H14 Q1 | #450 · #451 · #470 | register sekcií Štúdia · jedna cesta prepnutia · Q1 „Načítavam knižnicu šablón…" |
| H15a · H15b | #459 · #460 | dáta kovania v `core/*_seed.rb` |
| H16 | #461 | súpis knižníc (`LibraryRegistry`, `kniznice.md`) |
| H17a · H17b | #467 · #471 | spoločná príprava exportov (`ExportPrep`) · koniec exportu. **H17-0 zrušené** (Michal 9.10.) |
| H18 | #462 | Inspector ukáže skutočne použitý set závesov (D-149) |
| H18b-1 | #463 | voľba setu krídla platí (D-150); H18b-2 mimo scope |
| ŠÍRKA 50 | #466 | skrinka od 50 mm + 2 nohy pod úzkou dolnou |
| H19 | #472 | export test `scripts\export_test.ps1` (P == K) |
| Uzáver | #? | dokumentácia a verzia 0.18.0, priečinok bloku do archívu |

## Overenie

Pri uzávere (v0.18.0): **5426 headless · 163 JS sád** zelené, encoding guard čistý; kód sa mení len číslom verzie a `?v=`. **In-SU** bol bránou podľa triedy dávky (napr. H3b,
H10a, H11a, H12a/b, H18b-1 a ŠÍRKA 50); **plná in-SU sada na SketchUp 2026.2 (26.2.243, plugin 0.17.29) 11.10.2026: 3421 PASS / 0 FAIL**.

- **Audit návrhu** (Codex) mali audit-povinné dávky bloku (napr. H7, H8, H9, H10, H11, H12, H14–H18); nálezy BLOCKER a FIX boli zapracované pred implementáciou
  (počty v §15 príslušného package). Dávky H7, H9, H10 a H11 mali aj delta audit.
- **Slepá predrecenzia** pred PR mali výrobné/cenové dávky, dávky s novým ovládacím prvkom a dávky nad 300 riadkov kódu; nálezy P1/P2 sa opravili pred otvorením PR.
- **Zlaté testy** (H12, H14, H15, H17) strážia bajtovú zhodu výstupov; **export test H19** (`scripts\export_test.ps1`) porovnáva 4 reálne exporty testovacej zákazky na
  maine a na vetve pred mergom výrobných dávok exportov.
- **Quit test H11c (SketchUp 2026.2, 11.10.2026):** `scripts\run_su_tests.ps1 -QuitProbe` 5× (3× `Sketchup.quit`, 2× Súbor > Koniec) — vždy exit 0, `on_quit` 1×, poradie B
  (hooky okien pred `onQuit`), **žiadny pád**. Z1 sa nerobí. Detail: [PACKAGE_H11.md](bloky/HARDENING/PACKAGE_H11.md) §18.

## Aktualizovať plugin na oboch PC (Michal aj Lucia)

**Aktualizuj plugin na 0.18.0 na OBOCH PC a potom zavri všetky okná SketchUpu** (staré okno zapisuje nastavenia bez ochrany; ochrana poškodeného súboru nastavení má len
0.17.7+, nastavení exportu 0.17.20+, dvoch okien 0.17.8+ a 0.17.9+):
- **Minimum SketchUp 2026** (0.17.10+): starší SketchUp plugin nenačíta a inštalátor ho odmietne. Obe PC majú 2026.
- Po aktualizácii na 0.17.21+ zatvoriť a znova otvoriť Štúdio (export bez kontroly názvu odmietne).
- **Zákazku z novšieho pluginu starší plugin neprestaví ani nevyexportuje** (rohovú by sklopil na dolnú, úzku rozšíril na 200); schéma configu je 23, seed pravidiel 8
  (STANDARD §13). Rozpočet po prvej úprave vo v0.15.4+ v0.15.3 a starší needituje. Katalóg materiálov v schéme 11/12 starší plugin číta, ale nezapíše doň.
- Pred prvým uložením odkazu, ručným overením ceny alebo posielaním ponúk musí mať **Lucia aspoň 0.17.0** (`BUDGET_STD` blok CENY nemení, starší plugin nevaruje).

## Priznané limity (vedome, nie chyby)

- **Ochrana pri čítaní zo zálohy** hlási poškodenie až pri premenovaní/prepnutí (H9 Q1/Q2, H7 Q1): bez nálezu v Kontrole a bez tlačidla „Obnoviť zo zálohy".
- **Rôzne rady rozmerov z dvoch okien sa zlúčia bez hlášky**, ten istý rad = hláška a zmenu treba zadať znova (H10b Q2); cudzí globál = neuloží sa nič (H10a Q1).
- **Názov zákazky patrí počítaču** (nie `.skp`): pri poškodenom súbore nastavení exportu sa názov novej zákazky nemusí preniesť k súboru (jantárová bodka, návod
  „premenuj súbor"); strata pri zatvorení pred opravou je priznaná.
- **Hlavička „Spodná skrinka 800" vs. typ „Dolná"** sa nezmenila (zmena názvu je výrobná; zásobník 6A).
- **Exporty sa stále robia štyrmi samostatnými klikmi** (D-154 „Exportovať všetko" je v zásobníku).
- **Pád SketchUpu 2026.2 pri ukončení** sa neprejavil v 5 pokusoch; smoke bod E7 ho overí rukou Michala.
- **Pri prvej rohovej v dielni overiť záves Sensys** (prevzaté z bloku 8).

## Otvorené body

- **Michalov smoke** podľa checklistu nižšie — dočasná skupina „smoke po uzávere HARDENING" v [DOGFOODING.md](../DOGFOODING.md) vznikne, až keď príde prvý nález.
- **Zásobník:** **D-154** tlačidlo „Exportovať všetko" (mockup + export test) · **D-151** výklop bez systému prijme neúčinný výber setu · **D-152** mŕtvy výber dielca
  po zmene čela ožije · **D-153** len podmienený návrh pri H18b-2 · **H18b-2** mimo scope (nerobí sa bez Michalovho pokynu).
- **Luciin PC:** nevieme, či má SketchUp 2026.2 (H11 Q3 bez odpovede); po jeho aktualizácii zopakovať smoke E7 aj tam.
- **Otázky bez odpovede, platí návrh (z „Robí sa" v STAV):** H12 Q1 (karta dielca ako Kusovník — zavedené v H12d) · H11 Q2 (starší SketchUp = nenačíta sa, jedna hláška) ·
  H11 Q3 (kedy 2026.2) · H10b Q2 (rôzne rady sa zlúčia bez hlášky, ten istý rad = hláška) · H10a Q1 (cudzí globál = neuloží sa nič) · H9 Q1/Q2 (pri čítaní zo zálohy bez
  nálezu v Kontrole, bez tlačidla „Obnoviť zo zálohy") · H8 Q1/Q2 (veta o značke verzie, bez tlačidla) · H4b Q1/Q2 (vrátenie katalógu v ponuke „⋯" Materiálov, ikona
  posuvníkov pre Nastavenia rozpočtu) · H7 Q1 (hlásiť poškodenie aj mimo zápisu — „nie") · H6 Q1 („Spodná/Dolná") · **Q1** (porez a montáž pri skle) bez odpovede.
- **Test na kompletnej reálnej zákazke po V1** je akceptačný test (C13); smoke bodov A1 a A2 ho čiastočne pokrýva.
- **Stará poznámka v kóde:** komentár v `noxun_engine/core/app_lifecycle.rb` (hlavička) ešte spomína H11c ako budúcu dávku — upraví sa pri najbližšom zásahu do súboru.

## Smoke checklist bloku (v poradí dôležitosti a okna)

Zlúčené zo sekcií „Smoke" (§10 a ekvivalentov) všetkých packages bloku — H3, H4, H6, H7, H8, H9, H10, H11, H12, H14, H15, H16, H17, H18, H18b, ŠÍRKA 50 — a z čakajúcich
D-132, D-133, D-134. Duplicity sú zlúčené; **na konci je tabuľka „zdroj → čísla bodov"** na kontrolu úplnosti. V zátvorke pri každom bode je zdroj. Body označené
**[model]** potrebujú testovací model (kópia `_dev\ENGINEtests.skp`, nie zákazka) a body **[záloha]** zálohu súboru z `%APPDATA%\NOXUN\Engine`.
Viac okien SketchUpu naraz otvárať len v testovacom modeli.

**0 · Príprava**
1. **Aktualizuj plugin na 0.18.0 na OBOCH PC** (updater v Štúdiu → O plugine alebo `INSTALL_noxun_engine.ps1`), **zavri všetky okná SketchUpu** a otvor ich znova; over verziu v O plugine
   (v0.18.0 aj v pätičke Inspectora); staré okno by zapisovalo nastavenia bez ochrany (pokyn „Pred smoke" z H10 §10). *(H7 §10/6 · H9 §10/5 · H8 §10/4)*
2. Pracuj na **kópii poslednej reálnej zákazky** (napr. KLINIKA) a maj poruke **exporty spred aktualizácie** (VEPO CSV, CSV kovania, XLSX rozpočtu aj ponuky) na porovnanie.
3. Pred bodmi **[záloha]** skopíruj bokom `%APPDATA%\NOXUN\Engine\` súbory `supplier_settings.json` (+ `.bak`), `vepo_settings.json` (+ `.bak`), `hardware_rules.json`
   a `dim_series.json`; po smoke ich vráť (pri zavretom SketchUpe).
4. Testovacie modely pre závesy pripraví agent (`_dev\H18_smoke.skp`, `_dev\H18b_smoke.skp` podľa príprav v [PACKAGE_H18.md](bloky/HARDENING/PACKAGE_H18.md) §10 a
   [PACKAGE_H18b.md](bloky/HARDENING/PACKAGE_H18b.md) §10); cestu dostaneš v reporte.

### A · Exporty a čísla (najdôležitejšie — mení alebo stráži to, čo ide do výroby a ponúk)

*Na kópii reálnej zákazky; „ako pred aktualizáciou" = porovnaj so súbormi z bodu 0/2.*
1. **Štyri exporty** (VEPO, Nákup → CSV kovania, Rozpočet → XLSX, Ponuka → XLSX): mená súborov, počty v správe a sumy ako zvyčajne; **VEPO CSV je rovnaký súbor** ako pri poslednom exporte.
   *(H17 §10/1 · H12 §10/5)*
2. **Čísla bez zmeny:** Kusovník, Rozpočet SPOLU, suma ponuky, SPOLU nákupu kovania, sadzby a prerez/orez v Nastaveniach rozpočtu, hrany v Kusovníku; žiadny banner o poškodení;
   Kontrola má rovnaké počty červených a oranžových a **nikde riadok o „verzii štandardu"**. *(H8 §10/1 · H8 §10/2 · H9 §10/1 · H3 §10/6 · H15 §10/3)*
3. **Kusovník:** spodný súčtový riadok už nepíše „odhad 2,2 – 2,4 platní", je tam odkaz **Nárezový plán** s nožnicami → klik ho otvorí; to isté v pohľade Platne
   (stĺpec „Odhad platní" po materiáloch ostal). *(H3 §10/1)*
4. **Cenová ponuka:** stĺpce Položka · Množstvo · MJ · Spolu; riadok Atira „4 · set · 171,56 €"; Zameranie a Vizualizácie „v cene"; spotrebič „dodáva zákazník" 0,00 €;
   veľký prerušovaný rámik zmizol; **Exportuj XLSX ponuky** vyzerá presne ako doteraz. *(H3 §10/2)*
5. **Nákup kovania:** nadpisy Závesy, Výsuvy, Nohy a montáž, Spojovací materiál; parametre „NL 470 mm · výška čela 150 mm", „dvierka · klasické otváranie", „výška sokla 100 mm";
   stĺpec Kde „CAB-003 ×2"; **CSV kovania rovnaké ako doteraz** (kategória veľkými písmenami). *(H3 §10/4)*
6. **Nastavenia rozpočtu:** prázdne bunky ukazujú sivé číslo (napr. Porez 17), hlavičky Základ · € nízky · €€ štandard · €€€ vysoký; Uložiť bez zmeny nič nezmení,
   Rozpočet má rovnaké sumy. *(H3 §10/5)*
7. **Rozpočet → Služby:** „37,26 bm × 1,10 €", „4 platne × 17,00 €", „0 ks …", „23,20 m² …"; medzisúčty v poliach „40,99 €", „68,00 €"; **sumy rovnaké ako predtým**. *(H4 §10/1)*
8. **Rozpočet → Materiál:** MJ „platňa" malým, množstvo celé; ABS hrany množstvo na 2 desatinné (napr. 70,94); **XLSX rozpočtu bez zmeny** (MJ „PLATŇA" ako doteraz). *(H4 §10/2)*
9. **Kusovník:** materiál 18,6 mm ukazuje „18,6" v hlavičke aj stĺpci Hr.; dvierka s rovnakou páskou dookola majú v ABS „0,8 dookola", po nabehnutí myšou plný zápis L1–W2;
   **VEPO export rovnaký** ako predtým. *(H4 §10/3)*
10. **Materiály a Kovanie:** „DTDL 18,6", „23/0,8"; v Kovaní a „Aktualizovať z Demosu" ceny s čiarkou („12,50 €"). *(H4 §10/4)*
11. **Kovanie (sety), Pravidlá, Katalóg:** rovnaké sety (Atira biela/antracit, výklopy HK/HL, nohy podľa sokla, príchyt sokla); Pravidlá ponúkajú zásuvky Atira biela aj antracit
    a závesy klasik aj Tip-On; **Katalóg kovania** má strom výrobcov (Häfele → AXILO, Hettich, Blum…) a ceny ako predtým; **nová skrinka so zásuvkou a výklopom** naplní
    kovanie bez červeného „chýba kit". *(H15 §10/1 · H15 §10/2 · H15 §10/4 · H15 §10/5)*
12. **Zákazka s riadkom bez ceny:** Rozpočet → XLSX zastaví s tou istou vetou ako predtým; druhý klik a potvrdenie súbor vytvorí. *(H17 §10/2)*
13. **Zrušiť výber súboru** → „Export zrušený."; **VEPO export s otvoreným Inspectorom** (rozpísaný rozmer) vyexportuje nový rozmer. *(H17 §10/3)*
14. **Prepíš názov v hlavičke a hneď klikni na export** (bez Enter): export prebehne raz a priečinok nesie **nový** názov — alebo veta povie, prečo sa nespustil. *(H17 §10/3 · H7 §10/3)*
15. **Premenuj priečinok, do ktorého si naposledy exportoval** → CSV kovania aj oba XLSX otvoria okno výberu bez chyby, súbor sa uloží. *(H17 §10/4)*
16. **Názov zákazky a exporty:** uložená zákazka s názvom — VEPO, CSV kovania, XLSX rozpočtu aj ponuky sa volajú **presne ako pred aktualizáciou**; nový neuložený model má
    jantárovú bodku a „zadaj názov" aj na VEPO, CSV kovania, XLSX rozpočte a Cenovej ponuke; VEPO export povie na konci „… pomenované predvoleným názvom „projekt" — názov
    zákazky zadáš v hlavičke Štúdia". *(H7 §10/1 · H7 §10/2)*
17. **Dielec z inej verzie štandardu [model]:** testovacia skrinka s kusom „z inej verzie" — v Kontrole je **jeden oranžový riadok** s vetou, čo to znamená; klik na oko označí
    skrinku; VEPO export prejde a v LOGu je ten istý riadok. *(H8 §10/3)*
18. **ŠÍRKA 50 [model]:** dolná skrinka šírka 50 sa postaví, v modeli sú 2 nohy v strede šírky (vpredu a vzadu) a v Nákupe 2 nohy + 1 príchyt sokla; dolná 150 to isté;
    dolná 200 má 4 nohy ako doteraz. *(ŠÍRKA 50 §10/1 · ŠÍRKA 50 §10/2)*
19. **Stará zákazka a úzka skrinka [model]:** v zákazke s pravidlami spred tejto verzie a novou úzkou skrinkou Kontrola ORANGE „…pred pravidlom 2/4/6 (šírka 150 → 2 nohy + 1 príchyt
    sokla)"; po „Doplniť nové predvoľby" a prestavbe zhasne. *(ŠÍRKA 50 §10/6)*
20. **Závesy — skrinkový výber [model H18]:** skrinka A (1 dvierka Tip-On + starý skrinkový výber): Kovanie → Sety „1 vlastný", riadok Závesy „podľa staršieho výberu skrinky —
    Záves KLASIK…", riadok nákupu červený „nesedí s čelom (iný spôsob otvárania)…", dvierka bez závesov v Nákupe ako pred inštaláciou; skrinka C (zmiešané dvierka): riadok skrinky
    v Setoch nie je, Sety „1 vlastný", obe krídla „podľa staršieho výberu skrinky — Záves P2O", nákup: Tip-On krídlo P2O, klasické červené. *(H18 §10/1 · H18 §10/4)*
21. **Závesy — zmena výberu [model H18]:** v riadku Závesy vyber „Záves P2O + TipOn" → Sety „1 vlastný", krídlo „podľa skrinky — Záves P2O", nákup P2O; potom prvú voľbu → stavová veta
    „Závesy: výber zrušený." (nie „platí predvoľba projektu"). *(H18 §10/2)*
22. **Závesy — výber pri krídle [model H18]:** skrinka B (2 klasické krídla): ľavé krídlo ukazuje „Záves KLASIK…", pravé „podľa projektu — Záves KLASIK", Sety „1 vlastný". *(H18 §10/3)*
23. **Závesy — bez výberu a poškodený výber [model H18]:** skrinka D a ľubovoľná so zásuvkami bez vlastného výberu — všetko „podľa projektu" ako predtým; skrinka E (poškodený výber):
    riadok krídla „neplatný výber (uložený výber)", Sety „1 vlastný", nákup „výber setu na tejto skrinke je poškodený…". *(H18 §10/5 · H18 §10/5b)*
24. **Voľba setu krídla platí [model H18b]:** skrinka A, ľavé krídlo → „Záves KLASIK": hláška „Závesy pre dielec …left: set „Záves KLASIK…“", pravé „podľa skrinky — TEST"; nákup:
    **104717** × ľavé + **NX-TEST-ZAVES** × pravé; **Ctrl+Z** raz → ľavé späť „podľa skrinky — TEST", nákup len TEST; **Ctrl+Y** → späť. *(H18b §10/1 · H18b §10/2)*
25. **Výber krídla po zmene skrinky [model H18b]:** zmeň hĺbku skrinky A → výber ľavého krídla ostane, nákup rovnaký; ľavé krídlo → prvá voľba („podľa skrinky — TEST") → nákup len TEST,
    hláška „…výber zrušený.". *(H18b §10/3 · H18b §10/4)*
26. **Tip-On a prepnutie na klasické [model H18b]:** skrinka B → riadok krídla ponúka len Tip-On sety; „Záves P2O…" → Sety „1 vlastný", nákup P2O + piest; v karte čela prepni otváranie
    na **Klasické** → nákup ukáže **červené „nesedí s čelom"** pri tom krídle; vyber „Záves KLASIK" alebo prvú voľbu → červené zmizne. *(H18b §10/5)*
27. **Reálna zákazka (kópia) po závesoch:** Nákup kovania a Rozpočet — rovnaké čísla ako pred inštaláciou (voliteľne porovnať CSV nákupu zo starej a novej verzie). *(H18 §10/6 · H18b §10/7)*
28. **Lucia:** po aktualizácii jej PC rovnaká zákazka bez nového riadku v Kontrole a s rovnakými číslami. *(H8 §10/4)*

### B · Inspector (testovací model)

1. Označ dolnú skrinku → dole **jeden riadok** „Vložiť kópiu" · „Uložiť šablónu"; kópia sa vloží, „Uložiť šablónu" otvorí to isté okno ako predtým. *(H6a §10/1)*
2. Pod panelom **nie je „Pripravené."**; zmeň šírku → zelená veta sa ukáže na konci; daj do šírky nezmysel a klikni „Vložiť kópiu" → červená veta; pätka s verziou je. *(H6a §10/2)*
3. Pri označenej skrinke nie je nadpis „Rozmery"; pri vkladaní (nič neoznačené) je. *(H6a §10/3)*
4. **„?" vedľa kamery** pod náhľadom: v Korpuse, Zónach, Čelách, Kovaní a pri označenom dielci povie iné gestá; bublina sa dá otvoriť aj klávesom Tab. *(H6a §10/4)*
5. Zóny: riadok „Zobraziť obrysy zón v modeli" nie je; rail → oko → „Zóny (obrysy)" prepína obrysy ako predtým (aj Späť). *(H6a §10/5)*
6. „?" v hlavičkách Štruktúra zón, Položky z pravidiel, Sety, Pravidlá — klik na „?" skupinu **nezbalí**; text pod skupinami už nie je. *(H6a §10/6)*
7. Materiály: „?" v lište (len pri označenej skrinke); pri vkladaní veta „Označ skrinku pre nastavenie jej materiálov." ostáva. *(H6a §10/7)*
8. Spotrebič bez očakávania → „?" v riadku; nastav „očakáva rúru" → veta „očakáva rúru" je viditeľná. *(H6a §10/8)*
9. Zóny / Čelá / Kovanie: pás „Skrinka … upravíš v Korpuse" nie je; v lište Náhľadu „800 × 864 × 520 · sokel 100 →" — klik otvorí Korpus, bublina ukáže materiál korpusu; premenuj dekor v Štúdiu →
   Materiály a bublina povie nový názov. *(H6b §10/1)*
10. Korpus, lišta Nastavenia: „strop 2 výstuhy · boky na dne · chrbát v drážke" (podľa skrinky); zmeň chrbát → lišta sa zmení hneď; otvor skupinu → lišta ostáva súhrn. *(H6b §10/2)*
11. Zóny: „1 zóna · prázdna"; rozdeľ na 2 stĺpce a do jedného daj 3 police → „2 zóny · 3 police"; Späť → späť. *(H6b §10/3)*
12. Čelá: lišta „1 čelo · F206 ST9 · medzera 3 · okraje 2"; okraj dole −20 → „… okraje 2 · dole -20" aj v „Spoločné pre skrinku"; bublina nad súhrnom = celý dekor. *(H6b §10/4)*
13. Kovanie: lišta „Nohy 4× · Výsuv 1× · …"; kresba **bez textov a väčšia**; Položky „6 ks", Sety „podľa projektu" (po vlastnom sete „1 vlastný"). *(H6b §10/5)*
14. Rohová skrinka: lišta Náhľadu povie aj „dvere vľavo 450". *(H6b §10/6)*
15. Spodná, horná a vysoká 2100 (Korpus): kóty **rovnako veľké ako text panela**, bez „mm", celé v okne; Ctrl+koliesko priblíž a oddiaľ — písmo kót ostane rovnaké, ťahaj plochu — kóty idú
    s kresbou; zmeň výšku okna Inspectora a zbaľ/rozbaľ Náhľad → kóty ostanú 11 px a celé. *(H6c §10/1 · H6c §10/2 · H6c §10/3)*
16. Čelá vysokej skrinky: popis „F2 · 593", čísla medzier sa neprekrývajú; čelo s presahom dole −20 → kóta šírky je pod ním. *(H6c §10/4)*
17. Zóny so 4 stĺpcami (kóty šírok), umývačka, rohová, vkladaná doska (kóty, „bez smeru dekoru"), chladnička v skrinke (pásma, „hrana …") — všetko čitateľné. *(H6c §10/5)*
18. **Vkladacia karta:** vlož **Dolná, Horná, Rohová (vľavo aj vpravo, kláves D), Umývačka 60 a 45**; rozmery, nohy, sokel a výška zavesenia (horná 1400) ako predtým. *(H12 §10/1)*
19. Inspector nad každou z nich: hlavička typu (Dolná/Horná/Rohová/Umývačka), riadky Sokel a Nohy (horná a umývačka ich nemajú), riadok rohovej, pri umývačke bez Zón. *(H12 §10/2)*
20. **Šablóny:** ponuka filtrovaná typom; „Uložiť ako šablónu" z rohovej a umývačky má typ zamknutý; horná ↔ dolná sa prepne; šablóna iného typu sa na skrinku nepoužije. *(H12 §10/3)*
21. **Karta dielca:** názvy rolí ako v stĺpci Rola Kusovníka (napr. „Strop", „Čelo zásuvky"); dno zásuvky už nie je `drawer_bottom`. *(H12 §10/6)*
22. **Šírka 50:** šírka 50 a hrúbka 20 (alebo 60 a 25) → šírka aj hrúbka zočervenajú s vetou „Šírka je príliš malá…", Aplikovať nič nezmení; horná skrinka 50 mm sa postaví bez nôh. *(ŠÍRKA 50 §10/3 · ŠÍRKA 50 §10/4)*
23. **Mierka:** dolnú 600 stiahnuť na ~50 → skrinka 50 s 2 nohami; jedno Späť vráti 600 so 4 nohami (pri hrúbke 25 Mierka na 50 → hláška, skrinka ostane). *(ŠÍRKA 50 §10/5)*
24. **Preklik do Štúdia:** ⚠ → „Otvoriť v Štúdiu → Kontrola"; karta dielca → materiál (otvorí detail dekoru); „Materiál" v info stĺpci → Kusovník s vyplneným hľadaním; spotrebič → Spotrebiče s riadkom. *(H14 §10/4)*
25. **Dormantný zámok osi zásuvky [model]:** pri zásuvke prepni otváranie (klasické ↔ Tip-On) — v Kovaní, v boxe čela, je riadok „Dormantný zámok · NL 470" s dôvodom a tlačidlom
    „zrušiť" (jeden krok Späť); chipy osí ani nákup sa nemenia. *(D-132)*

### C · Štúdio

1. Štúdio z toolbaru: preklikaj **všetkých 14 sekcií** — poradie, ikony, nadpisy a nápovedy ako predtým; zbaľ navigáciu na ikony a späť; badge pri Kontrole a Spotrebičoch. *(H14 §10/1)*
2. V každej sekcii „Obnoviť" — hláška počas prepočtu ako predtým; v **Šablónach** „Obnoviť" píše **„Načítavam knižnicu šablón…"**. *(H14 §10/2 · H14 Q1)*
3. Menu Extensions → Noxun Engine → Pravidlá kovania · Materiály projektu · Katalóg kovania · Nastavenia rozpočtu · Šablóny — otvorí správnu sekciu. *(H14 §10/3)*
4. Kontrola → rozpočtový nález → Rozpočet na správnej časti; nález nastavení prerezu → Nastavenia rozpočtu. *(H14 §10/5)*
5. **Klávesnica:** Tab po položkách navigácie, Enter aj medzerník otvorí sekciu; po prepnutí sekcie a návrate ostane v Kusovníku pohľad, hľadanie a zbalené skupiny, v Kontrole filter;
   zbalená navigácia sa po zatvorení a otvorení Štúdia vráti zbalená. *(H14 §10/6)*
6. Otvor modal v Materiáloch alebo Kovaní, prepni sekciu — modal zmizne; O plugine — kontrola verzie raz pri vstupe, nie pri každom prepočte. *(H14 §10/7)*
7. **Kontrola:** zelený chip „0 zo 7 skriniek bez nálezu" (7 = počet skriniek v modeli); oranžový „10 nálezov v 5 riadkoch · skontroluj pred objednávkou" (5 = riadky v zozname); vypni všetky
   tri kresby → „Vypnuté — v modeli nie je nič nakreslené."; zapni len **Smer otvárania** → veta zmizne, ostane počet krídel. *(H3 §10/3)*
8. **Hlavička — názov zákazky:** klik na názov → „Test H7" → Enter: hlavička sa zmení, zelené „Názov zákazky: Test H7 · platí pre VEPO, kovanie, rozpočet aj ponuku", bodky zmiznú;
   Ctrl+S → názov ostane. Uložená zákazka s názvom: hlavička „Zákazka: <názov> ✎" tučne v každej sekcii, v Kusovníku pole PROJEKT nie je. *(H7 §10/1 · H7 §10/3)*
9. Klik na názov → Escape: bez zmeny. Klik → zmaž → Enter: meno súboru so sivým „podľa súboru". Uložená zákazka bez názvu → „podľa súboru", bez bodky. *(H7 §10/4)*
10. **Materiály:** vedľa „Obnoviť" už nie je „Obnoviť zálohu"; ak je záloha, „⋯" → „Vrátiť katalóg pred migráciou…" otvorí to isté potvrdenie; Escape ponuku zavrie. *(H4 §10/5)*
11. **Nastavenia rozpočtu:** tlačidlo „Obnoviť" (namiesto „Načítať nanovo"); Spotrebiče: vyradený model sa vracia tlačidlom „Vrátiť". *(H4 §10/6)*
12. **Rozbaľovačky** (Podľa výrobcu, Kresba čiel, Všetky kategórie, set nôh v Inspectore) vyzerajú ako ostatné polia a výber nôh nepresahuje okraj; hľadanie píše „Hľadať…". *(H4 §10/7)*
13. **Kusovník:** stĺpce Dĺžka/Šírka/Hr./ks sú pod sebou vo všetkých skupinách; dlhý zoznam skriniek sa zalomí, nezmizne. *(H4 §10/8)*
14. Kovanie → Sety a Pravidlá: mazanie riadku je ikona ×, nie písmeno. *(H4 §10/9)*
15. Zbalená navigácia Štúdia: Rozpočet (€) a Nastavenia rozpočtu (posuvníky) sa dajú rozlíšiť. *(H4 §10/10)*
16. **Texty:** nikde „ghost", „seed", „legacy", „server"; verzia „v0.18.0" v Štúdiu aj v pätičke Inspectora; zóny v raile „Zóny (obrysy)". *(H4 §10/11)*
17. Štúdio → Pravidlá → rozbaľ „Kontroly dvierok" → veta „Platí pre dvierka…" je v „?" v hlavičke bloku; klik na „?" blok nezbalí. *(H6a §10/9)*
18. **Štúdio → Šablóny:** slovo typu na dlaždici; Pravidlá kovania: „Bystrica — na hornú skrinku". *(H12 §10/4)*
19. **„Nahradiť UNI…" [model s odpojeným dielcom]:** hromadná zámena UNI materiálu sa pozerá na rovnakú zákazku ako kusovník a VEPO; skrinka s odpojeným dielcom (výrobný dielec vytiahnutý
    na koreň modelu) zablokuje nahradenie vetou „má odpojený dielec — vráť ho do skrinky alebo skrinku prestav"; vnorená skrinka sa neprestavuje. *(D-133)*
20. **Hromadné zápisy zákazky [model s odpojeným dielcom]:** uloženie pravidiel kovania, zmena projektovej predvoľby materiálu a override materiálu dielca „aj na podobné v projekte" preskočia
    skrinku s odpojeným dielcom a vymenujú ju („CAB-3 (má odpojený dielec …)"); nastavenie projektu sa napriek tomu uloží; modal ukazuje počet po vylúčení. *(D-134)*

### D · Ochrana dát a dve okná

*Pred týmto oddielom urob zálohu súborov (bod 0/3). Dve okná SketchUpu = dva testovacie modely, nie zákazka.*
1. Ulož drobnú zmenu v Nastaveniach rozpočtu aj v okne Pravidlá (ABS alebo kovanie) a vráť ju — uloží sa bez hlášky. *(H9 §10/2)*
2. **[záloha] Poškodený súbor dodávateľa:** zavri SketchUp, prepíš `supplier_settings.json` na `[]` a spusti SketchUp → Nastavenia rozpočtu: **červený banner „poškodené — číta sa záloha"**,
   sadzby sú tvoje (nie predvolené: porez 17 €, orez 10 mm), „Uložiť" vypnuté, Rozpočet počíta s tvojimi sadzbami. *(H9 §10/3)*
3. Pokračovanie: zmaž `supplier_settings.json` (záloha ostane) → **Obnoviť** (predtým „Načítať nanovo") → banner zmizne, hodnoty tvoje; drobná zmena sa uloží. Súbory vráť. *(H9 §10/4)*
4. **[záloha] Poškodený súbor nastavení exportu (voliteľné):** skopíruj bokom `vepo_settings.json` aj `.bak`, prepíš `vepo_settings.json` na `[]`, spusti SketchUp: hlavička ukáže názov zo zálohy;
   premenovanie → **červené** „Názov zákazky sa neuložil: nastavenia exportu sú poškodené — číta sa záloha…"; premenuj `vepo_settings.json` na `vepo_settings.poskodeny.json` → premenovanie prejde.
   Na konci vráť súbory (pri zavretom SketchUpe). *(H7 §10/5)*
5. **Pravidlá, dve okná:** v oboch oknách Štúdio → Pravidlá. V A zmeň počet (napr. nohy), zaškrtni „aj ako globálnu predvoľbu", Uložiť. V B zmeň niečo iné, zaškrtni, Uložiť → **červená hláška**,
   úpravy v B **ostali vo formulári**, skrinky sa neprestavovali, Späť nemá nový krok. Druhé Uložiť v B → uložené (vedomé prepísanie). *(H10 §10/1)*
6. **Uloženie len do projektu nepotvrdí cudzí globál:** zatvor a otvor Štúdio v A aj B. V B ulož globál. V A ulož **bez** zaškrtnutia, potom **so** zaškrtnutím → **červená hláška**. *(H10 §10/2)*
7. **Nový prázdny model:** v A nový model → Štúdio → Pravidlá (globálne predvoľby), uprav číslo; v B ulož globál; v A Uložiť → **červená hláška**, úpravy ostali; druhé Uložiť → uložené. *(H10 §10/3)*
8. **Rady — rôzne riadky:** v A do Šírok pridaj 700 → Uložiť; v B (panel otvorený predtým) zmeň Hĺbky → Uložiť → editor v B ukazuje aj 700. *(H10 §10/4)*
9. **Rady — ten istý riadok:** A zmení Sokle, B (bez zatvorenia panela) zmení Sokle → **červená hláška**, editor ukáže sokle z A. *(H10 §10/5)*
10. **Jedno okno:** bežné uloženie pravidiel aj radov ako doteraz; reálna zákazka (len otvoriť) — Kusovník, Nákup, Rozpočet s rovnakými číslami. *(H10 §10/6)*

### E · SketchUp a štart

1. Spusti SketchUp 2026 → plugin naskočí ako vždy, **žiadna hláška**. *(H11 B7/1 · H11 A9/1)*
2. Zapni a vypni ABS kontrolu hrán, smer kresby, smer otvárania → kreslia ako predtým. *(H11 B7/2)*
3. Zapni Smer otvárania (aj Zvýrazniť hrany), daj **Súbor → Nový**, otvor Štúdio, pozri **Okno → Ruby konzola**: žiadny riadok „DirectionCheck.remove_overlay" (ani EdgeCheck/GrainCheck);
   prepínače v novom súbore fungujú — klikni aj **Zvýrazniť hrany** a skontroluj konzolu znova. *(H3 §10/7)*
4. Aktualizácia cez „O plugine" alebo INSTALL prebehne ako vždy (inštalátor vypíše cieľ `SketchUp 2026`). *(H11 B7/3)*
5. Inspector → **Vložiť skrinku** → skrinka visí → zavri Inspector krížikom → skrinka z kurzora zmizne, kurzor = Výber; to isté zatvorením **logom v toolbare**. *(H11 A9/2 · H11 A9/3)*
6. Hrana pod kurzorom v karte dielca → zavri Inspector → zvýraznenie zmizne; Štúdio zavri a otvor → sekcie fungujú. *(H11 A9/4 · H11 A9/5)*
7. **Koniec SketchUpu (kľúčový bod H11c, na 2026.2):** Inspector aj Štúdio otvorené, skrinka na kurzore → **Súbor → Koniec** → bez chybového okna; nový štart normálny. *(H11 A9/6)*
8. **Zrušené ukončenie:** zmeň niečo v modeli → Súbor → Koniec → v otázke „uložiť?" klikni **Zrušiť** → v Ruby konzole **nesmie** byť riadok „ukončovanie SketchUpu (onQuit)"; potom Vložiť +
   zatvorenie Inspectora funguje ako v bode 5. *(H11 A9/7)*
9. **Okná ako predtým (po súpise knižníc):** Štúdio → Šablóny (náhľady, vloženie zo šablóny), Materiály, Kovanie, Spotrebiče, O plugine — všetko ako predtým. *(H16 §10/1)*
10. V priečinku `%APPDATA%\NOXUN\Engine` (cesta je v O plugine) **žiadny nový súbor** ani priečinok. *(H16 §10/2)*
11. **Prečítaj si súpis** ([kniznice.md](../../docs/architecture/kniznice.md), časti 2 a 3): sedí, čo sa má s Luciou zdieľať a čo ostane každému? *(H16 §10/3)*

*Nezaradené:* H18b §10/6 (H18b-2) sa **nerobí** — H18b-2 je mimo scope, bod sa vynecháva do Michalovho pokynu.

### Kontrola úplnosti — zdroj → čísla bodov

| Zdroj | Číslo zdrojového bodu → bod tohto checklistu |
|---|---|
| H3 §10 | 1 → A3 · 2 → A4 · 3 → C7 · 4 → A5 · 5 → A6 · 6 → A2 · 7 → E3 |
| H4 §10 | 1 → A7 · 2 → A8 · 3 → A9 · 4 → A10 · 5 → C10 · 6 → C11 · 7 → C12 · 8 → C13 · 9 → C14 · 10 → C15 · 11 → C16 |
| H6a §10 | 1 → B1 · 2 → B2 · 3 → B3 · 4 → B4 · 5 → B5 · 6 → B6 · 7 → B7 · 8 → B8 · 9 → C17 |
| H6b §10 | 1 → B9 · 2 → B10 · 3 → B11 · 4 → B12 · 5 → B13 · 6 → B14 |
| H6c §10 | 1 → B15 · 2 → B15 · 3 → B15 · 4 → B16 · 5 → B17 |
| H7 §10 | 1 → A16, C8 · 2 → A16 · 3 → A14, C8 · 4 → C9 · 5 → D4 · 6 → P1 |
| H8 §10 | 1 → A2 · 2 → A2 · 3 → A17 · 4 → A28, P1 |
| H9 §10 | 1 → A2 · 2 → D1 · 3 → D2 · 4 → D3 · 5 → P1 |
| H10 §10 | 1 → D5 · 2 → D6 · 3 → D7 · 4 → D8 · 5 → D9 · 6 → D10 |
| H11 B7 (smoke H11b) | 1 → E1 · 2 → E2 · 3 → E4 |
| H11 A9 (smoke H11a) | 1 → E1 · 2 → E5 · 3 → E5 · 4 → E6 · 5 → E6 · 6 → E7 · 7 → E8 |
| H12 §10 | 1 → B18 · 2 → B19 · 3 → B20 · 4 → C18 · 5 → A1 · 6 → B21 |
| H14 §10 | 1 → C1 · 2 → C2 · 3 → C3 · 4 → B24 · 5 → C4 · 6 → C5 · 7 → C6 |
| H15 §10 | 1 → A11 · 2 → A11 · 3 → A2 · 4 → A11 · 5 → A11 |
| H16 §10 | 1 → E9 · 2 → E10 · 3 → E11 |
| H17 §10 | 1 → A1 · 2 → A12 · 3 → A13, A14 · 4 → A15 |
| H18 §10 | 1 → A20 · 2 → A21 · 3 → A22 · 4 → A20 · 5 → A23 · 6 → A27 |
| H18b §10 | 1 → A24 · 2 → A24 · 3 → A25 · 4 → A25 · 5 → A26 · 6 → nerobí sa (H18b-2 mimo scope) · 7 → A27 |
| ŠÍRKA 50 §10 | 1 → A18 · 2 → A18 · 3 → B22 · 4 → B22 · 5 → B23 · 6 → A19 |
| D-132 | B25 |
| D-133 | C19 |
| D-134 | C20 |
| H14 Q1 (PR #470) | C2 |

Príprava (P1–P4) sa viaže na H7/6, H8/4, H9/5, H10 „Pred smoke" a na prípravy modelov H18 a H18b.

