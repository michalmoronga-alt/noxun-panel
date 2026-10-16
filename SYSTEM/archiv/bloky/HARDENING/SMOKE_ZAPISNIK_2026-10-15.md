# Smoke HARDENING — zápisník (15.10.2026)

Checklist: [HARDENING_ZAVER_2026-10-11.md](../../HARDENING_ZAVER_2026-10-11.md) § „Smoke checklist bloku".
Spôsob (Michal 15.10.): namiesto kópie KLINIKA **nová maximálna zákazka** (čo najviac typov, funkcií, kovania), Michal píše postup krok za krokom,
orchestrátor sleduje model cez VBO MCP. Potom tieňová zákazka starým spôsobom → porovnanie základných exportov a dielov.

Prostredie: SketchUp 26.2.243 · Noxun Engine 0.18.1 · štart v neuloženom Untitled modeli (0 entít).

Legenda: ✅ PASS · ❌ FAIL (→ postreh) · ⚠ s poznámkou · ⏭ vynechané · ☐ nerobené

## Stav bodov

| Bod | Stav | Poznámka |
|---|---|---|
| P1 verzia | ☐ | |
| P2 exporty spred aktualizácie | ⏭ | nahradí tieňová zákazka starým spôsobom |
| P3 záloha %APPDATA% | ✅ | celý `%APPDATA%\NOXUN\Engine` (53 súborov) → `_dev\zaloha_noxun_pred_D_20261016_2032\` |
| P4 modely H18/H18b | ☐ | Michal môže načítať staršiu zákazku — dohodnúť, keď príde rad (platí aj pre D) |

**Stav 17.10. ~00:15 (z 94 bodov):** ✅ **34** · ⏭ **7** (A17, A19, A20, A23, A27, A28, D4) · ☐ **53** + tieňová zákazka.
- ✅ A1 · A11 · A18 · A21 · A22 · A24 · A25 · A26 — B8 · B14 · B17 · B18 · B19 · B22 · B23 — C9 — D1–D3 · D5–D10 — E1–E3 · E5–E10 — P1, P3
- čiastočne B20 (uloženie, načítanie a mazanie šablóny OK; ostáva filter podľa typu a zamknutý typ)

## ZOSTÁVA — zoznam na dokončenie (nové okno)

*Zákazka `_dev\SMOKE_HARD_MAX.skp` (kompletná, 12 skriniek + 6 dosiek, materiály vyplnené). Body C19/C20 v `_dev\SMOKE_bridge_test.skp`.
Plné znenie bodu: [HARDENING_ZAVER_2026-10-11.md](../../HARDENING_ZAVER_2026-10-11.md) § Smoke checklist. Stačí „ok" / čo nesedí.*
*Pred pokračovaním vráť v SMOKE_HARD_MAX: CAB-005 krídlo na klasický set (alebo dvierka späť na Tip-On), CAB-004 hĺbku 796 → 510.*

**Kusovník** — A3 súčtový riadok: odkaz „Nárezový plán" s nožnicami namiesto „odhad platní" (aj pohľad Platne) · A9 Halifax „18,6" v hlavičke aj Hr.,
dvierka „0,8 dookola" (plný L1–W2 po nabehnutí myšou) · C13 stĺpce Dĺžka/Šírka/Hr./ks pod sebou vo všetkých skupinách, dlhý zoznam skriniek sa zalomí.
**Kontrola** — A2 nikde riadok o „verzii štandardu", žiadny banner poškodenia · C7 zelený chip „0 z N skriniek bez nálezu", oranžový „X nálezov v Y riadkoch";
vypni všetky 3 kresby → „Vypnuté — v modeli nie je nič nakreslené."; zapni len Smer otvárania → veta zmizne, počet krídel · C4 rozpočtový nález → Rozpočet
na správnej časti; nález prerezu → Nastavenia rozpočtu.
**Nákup kovania** — A5 nadpisy Závesy / Výsuvy / Nohy a montáž / Spojovací materiál; parametre „NL 470 mm · výška čela 150 mm", „dvierka · klasické
otváranie", „výška sokla …"; stĺpec Kde „CAB-00x ×2"; CSV kategória VEĽKÝMI.
**Rozpočet** — A7 Služby: „… bm × … €", „… platne × 17,00 €", medzisúčty v poliach · A8 Materiál: MJ „platňa" malým, množstvo celé, ABS na 2 desatinné;
XLSX MJ „PLATŇA" · A12 riadok bez ceny → XLSX zastaví vetou, druhý klik a potvrdenie súbor vytvorí.
**Cenová ponuka** — A4 stĺpce Položka · Množstvo · MJ · Spolu; Zameranie a Vizualizácie „v cene"; spotrebič „dodáva zákazník" 0,00 €; bez veľkého
prerušovaného rámika; XLSX ponuky ako doteraz.
**Nastavenia rozpočtu** — A6 prázdne bunky ukazujú sivé číslo (napr. Porez 17), hlavičky Základ · € nízky · €€ štandard · €€€ vysoký; Uložiť bez zmeny nič
nezmení · C11 tlačidlo „Obnoviť" (nie „Načítať nanovo").
**Materiály a Kovanie** — A10 „DTDL 18,6", „23/0,8"; ceny s čiarkou „12,50 €" (aj Aktualizovať z Demosu) · C10 bez „Obnoviť zálohu", záloha v „⋯" →
„Vrátiť katalóg pred migráciou…", Escape zavrie · C14 mazanie riadku v Setoch a Pravidlách = ikona × · C12 rozbaľovačky (Podľa výrobcu, Kresba čiel, Všetky
kategórie, set nôh v Inspectore) vyzerajú ako ostatné polia, hľadanie „Hľadať…" · C11 Spotrebiče: vyradený model sa vracia tlačidlom „Vrátiť".
**Exporty** (do `_dev`, nie do reálnych projektov) — A13 zrušiť výber súboru → „Export zrušený."; VEPO s otvoreným Inspectorom a rozpísaným rozmerom
vyexportuje nový rozmer · A14 prepíš názov v hlavičke a hneď klikni export (bez Enter) → export raz, priečinok s novým názvom · A15 premenuj priečinok
posledného exportu → CSV kovania aj oba XLSX otvoria výber bez chyby · A16 nový neuložený model: jantárová bodka a „zadaj názov" pri VEPO, CSV kovania,
XLSX rozpočtu a ponuky; VEPO povie „… pomenované predvoleným názvom „projekt"…".
**Štúdio celkovo** — C1 všetkých 14 sekcií (poradie, ikony, nadpisy), zbaliť/rozbaliť navigáciu, badge Kontrola a Spotrebiče · C2 „Obnoviť" v sekciách,
v Šablónach „Načítavam knižnicu šablón…" · C3 Extensions → Noxun Engine → Pravidlá kovania / Materiály projektu / Katalóg kovania / Nastavenia rozpočtu /
Šablóny otvorí správnu sekciu · C5 Tab po navigácii, Enter aj medzerník; po návrate ostane pohľad, hľadanie a zbalené skupiny Kusovníka, filter Kontroly;
zbalená navigácia sa po zatvorení vráti zbalená · C6 modal v Materiáloch/Kovaní zmizne pri prepnutí sekcie; O plugine kontroluje verziu raz pri vstupe ·
C8 názov zákazky „Test" → Enter: hlavička, zelená veta „platí pre VEPO, kovanie, rozpočet aj ponuku", Ctrl+S ho drží; v Kusovníku nie je pole PROJEKT ·
C15 zbalená navigácia: Rozpočet (€) a Nastavenia rozpočtu (posuvníky) sa dajú rozlíšiť · C16 nikde „ghost", „seed", „legacy", „server"; „v0.18.x" v Štúdiu
aj pätičke Inspectora; „Zóny (obrysy)" v raile · C17 Pravidlá → „Kontroly dvierok": veta v „?" hlavičky, klik na „?" blok nezbalí · C18 Šablóny: slovo
typu na dlaždici; Pravidlá kovania: „Bystrica — na hornú skrinku".
**C19/C20** (`_dev\SMOKE_bridge_test.skp`, CAB-007 má odpojený ľavý bok) — Materiály → „Nahradiť UNI…" zablokuje vetou „má odpojený dielec — vráť ho do
skrinky alebo skrinku prestav" · uloženie pravidiel kovania, zmena predvoľby materiálu projektu a override „aj na podobné v projekte" CAB-007 preskočia
a vymenujú („CAB-7 (má odpojený dielec …)"), nastavenie sa aj tak uloží.
**Inspector** (označ skrinku v SMOKE_HARD_MAX) — B1 dole jeden riadok „Vložiť kópiu" · „Uložiť šablónu" · B2 pod panelom nie je „Pripravené.", zelená
veta po zmene šírky, červená pri nezmysle; pätka s verziou · B3 pri označenej skrinke bez nadpisu „Rozmery", pri vkladaní s ním · B4 „?" pri kamere
povie iné gestá v Korpuse/Zónach/Čelách/Kovaní/dielci, otvorí sa aj Tabom · B5 Zóny bez riadku „Zobraziť obrysy"; rail → oko → „Zóny (obrysy)" (aj Späť) ·
B6 „?" v hlavičkách Štruktúra zón, Položky z pravidiel, Sety, Pravidlá — klik skupinu nezbalí · B7 Materiály: „?" v lište len pri označenej skrinke;
pri vkladaní „Označ skrinku pre nastavenie jej materiálov." · B9 Zóny/Čelá/Kovanie: lišta Náhľadu „800 × 864 × 520 · sokel 100 →" otvorí Korpus,
bublina s materiálom (premenuj dekor → nový názov) · B10 Korpus: lišta „strop 2 výstuhy · boky na dne · chrbát v drážke", zmena chrbta sa prejaví hneď ·
B11 Zóny: „1 zóna · prázdna" → „2 zóny · 3 police"; Späť · B12 Čelá: „1 čelo · <dekor> · medzera 3 · okraje 2", okraj dole −20 → „… · dole -20" ·
B13 Kovanie: „Nohy 4× · Výsuv 1× · …", kresba bez textov a väčšia; Položky „N ks", Sety „podľa projektu" / „1 vlastný" · B15 dolná, horná a vysoká 2130:
kóty veľké ako text, bez „mm", celé v okne; Ctrl+koliesko a ťahanie; zmena výšky okna a zbalenie Náhľadu → kóty 11 px · B16 Čelá vysokej: popis
„F2 · …", čísla medzier sa neprekrývajú; čelo s presahom dole −20 → kóta pod ním · B20 Šablóny: ponuka filtrovaná typom; „Uložiť ako šablónu" z rohovej
a umývačky má typ zamknutý; šablóna iného typu sa na skrinku nepoužije · B21 karta dielca: názvy rolí ako v Kusovníku („Strop", „Čelo zásuvky"),
dno zásuvky nie `drawer_bottom` · B24 ⚠ → „Otvoriť v Štúdiu → Kontrola"; karta dielca → materiál otvorí detail dekoru; „Materiál" v info stĺpci →
Kusovník s hľadaním; spotrebič → Spotrebiče s riadkom · B25 zásuvka, prepni klasické ↔ Tip-On → v Kovaní riadok „Dormantný zámok · NL 470" s dôvodom
a „zrušiť" (jeden krok Späť); chipy osí ani nákup sa nemenia.
**Ostatné** — E4 aktualizácia cez O plugine / INSTALL (pri najbližšej inštalácii) · E11 prečítať [kniznice.md](../../../../docs/architecture/kniznice.md)
časti 2 a 3: sedí, čo sa zdieľa s Luciou a čo ostane každému? · **Tieňová zákazka** starým spôsobom → porovnať základné exporty a diely.

**Rozhodnutie Michala 16.10. (staré stavy):** cez plugin išla zatiaľ 1 zákazka, žiadne rozpracované zákazky v starých verziách sa nebudú
otvárať ani upravovať; po V1 idú do výroby nové zákazky. → body testujúce **len kompatibilitu so starými dátami** sa vynechávajú (⏭):
A17 (dielec z inej verzie štandardu), A19 (stará zákazka a úzka skrinka), A20 (starý skrinkový výber závesov), A23 (poškodený výber),
A27/A28 (reálna zákazka pred/po, Lucia — nahradí referenčná zákazka a tieňové porovnanie). **Súčasné správanie závesov** (A21, A22,
A24–A26) sa overí priamo v SMOKE_HARD_MAX na existujúcich setoch (bez fixtúr a TEST setu).

## Postup Michala (log)

1. Uložená prázdna zákazka `_dev\SMOKE_HARD_MAX.skp` (overené cez MCP: 0 entít). Štúdio: názov „podľa súboru" → **C9 ✅** (časť bez názvu).
2. Vložená prvá skrinka cez ghost zo šablóny (starší model šablóny — Michal ju prerobí na nový, uloží ako šablónu, starú neskôr zmaže).
   Vo vkladacej karte: šírka 900, výška zamknutá 880, sokel 150. Validácie: šírka < 50 červená; min. výška dolnej pri sokli 0 = 80 mm,
   pri sokli 150 = 210 mm (červené) → **B22 čiastočne ✅** (šírka 50 červená). Ghost bez výhrad.
   **MCP kontrola:** CAB-001 v modeli je **920 × 864 × 510, nohy 100** (nie 900/880/150) — 3 zásuvky (302/302/150), 4 nohy + 1 príchyt, NL 470. → otázka Michalovi.
   Vysvetlenie: Michal vkladal **dvojklikom na šablónu** (nie „Vložiť skrinku") → šablóna sa vložila so svojimi rozmermi; prepísané hodnoty karty sa nepoužili.
   Opravené: teraz **CAB-002 900 × 880 × 510, nohy 150**, 3 zásuvky, 4 nohy + 1 príchyt → sedí.
3. Čelá/Kovanie CAB-002: šablóna má starý základ kovania; Michal nastavuje zásuvky na nový set — Klasické · kovové bočnice · štandardná.
   MCP: 3. čelo (150) má `classic / metal / standard / atira` → recept `atira_sisy_v1` (NL 470, nosnosť 30), konflikty 0. Čelo 3 je teraz
   **fixné 150 so zámkom** — zamknuté už v uloženej šablóne (Michal overil), nie chyba.
   Doplnené všetky 3 zásuvky: MCP — všetky `classic/metal/standard/atira`, 3× výsuv `recipe:atira_sisy_v1`, 4 nohy + 1 príchyt, konflikty 0 → OK.
4. Uložená šablóna „3 šuflík" (s kovaním); znovu vložená dvojklikom → **CAB-003** je zhodná s CAB-002 (900×880, nohy 150, 3× Atira, zamknuté 150,
   4 nohy + príchyt) → uloženie/načítanie šablóny s kovaním **OK** (B20 čiastočne — filtrovanie typom a zamknutý typ pri rohovej/umývačke ešte).
5. Stará šablóna „Varná 3 šuflík": najprv vložená do scény, potom zmazaná z knižnice — potvrdenie „Knižnica je spoločná… Skrinky, ktoré zo šablóny
   vznikli, sa tým nemenia." → zmizla. MCP: skrinka zo starej šablóny (teraz CAB-003, 920×880, starý základ `vysuvy-nl-podla-hlbky`) ostala
   v modeli nezmenená → **mazanie šablóny OK**.
6. CAB-003 ostáva (kontrast starý základ). Šírka → 600; Mierka (Scale) + Ctrl+Z → OK (súvisí s B23, tam ide o stiahnutie na 50).
7. CAB-002 strop → **plný**: odsadenie 20 mm z výstuh zmizlo a plný strop odsadenie neponúka. MCP: strop 862–880 (zarovno s vrchom),
   hodnota 20 ostala v dátach uložená (`top_offset` 20) → po návrate na výstuhy sa vráti. → postreh S3.
8. Pridaná **CAB-004** dolná 600 × 880 × 510, nohy 150, zatiaľ bez čiel (výstuhy, odsadenie 0 — predvoľba novej skrinky), 4 nohy + príchyt.
   Zámky, ghost, Ctrl+C, Mierka, zmeny rozmeru v kombinácii → bez chyby. **S3: Michal áno — odsadenie doplniť aj na plný strop (neskôr).**
9. CAB-004 (teraz šírka 800): dvere auto → 2 krídla ✅; priečka (2 stĺpce po 373) + police 1 a 2 ✅; ručný prepis priečky + Ctrl+Z → zóny aj police
   sa natiahli a vrátili ✅; profil UKW7 hore, otváranie klasické. MCP kovanie: 2× (2 závesy `zavesy-podla-vysky`), 3× 4 podperky, 2× úchytkový
   profil (na krídlo), 4 nohy, 1 príchyt; konflikty 0 → **A11 čiastočne ✅** (dvierka klasické bez „chýba kit"). Smer otvárania `unset`.
10. **CAB-005** dolná 600, 1 krídlo, smer vpravo, **Tip-On**. MCP: 2 závesy `zavesy-podla-vysky`, nohy, príchyt; sety projektu (bez vlastného).
    → v Nákupe overiť, či sú závesy Tip-On variant + piest (súvisí s A26).
11. **CAB-006** = kópia CAB-005 tlačidlom „Kópia skrinky vpravo o jej šírku" (x 5060 → 5660 ✅), dvere → drevená zásuvka. MCP: čelo zásuvky Tip-On,
    `wood / standard / quadro_v6` → výsuv `recipe:quadro_v6_p2o_v1` (P2O pre Tip-On ✅); **navyše slepé čelo („blind") fixné 150 so zámkom**
    — pridal Michal zámerne (slepé čelo 150), OK. Na čele zásuvky ostal po dverách smer „right" (v dátach, bez vplyvu na kovanie).
12. CAB-006 ručný prepis zásuvky: NL 400, výška boxu 400 → MCP výsuv `quadro_v6_p2o_v1` NL 400, box 400 ✅; info v Kontrole
    „Zásuvky s receptom (1 ks) dostali výsuv z receptu — pôvodné pravidlo výsuvov sa na ne nepoužilo" (severity info).
13. **CAB-007 rohová** (corner_blind) vľavo, 1100 × 880 × 510, CR 80 → 100 (oba), dverová časť 500, dvere Tip-On, smer vpravo.
    MCP: 6 nôh, 2 závesy (`use_type door`, `tipon`), 2 príchyty sokla, konflikty 0 → B18 čiastočne (rohová vľavo).
    **B14 ✅** (lišta „dvere vľavo 500") · **B19 ✅** (hlavička Rohová, riadok rohovej). Prepnutie na vpravo → MCP: strana right, smer dverí sa
    sám zrkadlil na left, CR/dvere 500 ostali, kovanie rovnaké → Ctrl+Z jedným krokom: MCP späť left / smer right / Tip-On / CR 100 / 500 ✅.
    (B18 ešte: vkladanie rohovej vpravo klávesom D, Umývačka 60 a 45, Horná.)
14. **CAB-008 rohová vpravo** vložená klávesom D → MCP corner_blind right 1100, 6 nôh, 2 závesy, 2 príchyty ✅ (B18: rohová vľavo aj vpravo ✅;
    zostáva Umývačka 60/45, Horná). Drobnosť: CAB-003 (x 3662, š. 600 → koniec 4262) a CAB-004 (x 4260) sa prekrývajú o 2 mm — ručné
    umiestnenie, nie chyba pluginu.
15. Rohová vpravo zmazaná; vložená **umývačka 45** → dostala ID **CAB-008** (číslo zmazanej rohovej sa znovu použilo; tak isto CAB-003 skôr).
    MCP: dishwasher 450 × 880 × 560, bez nôh a sokla (support none), čelo slepé 728 od 150 (dv myčka), telo 815, kovanie žiadne ✅.
    B18: Umývačka 45 ✅ (60 ešte), Horná ešte.
16. Do umývačky CAB-008 priradený spotrebič **Bosch SPV6EMX05E** (trieda 450, niche 450 / 815–875 / 550) ✅. CAB-006 → „očakáva rúru"
    (`appliance_expects: oven`) ✅ → **B8 ✅** (podľa Michala „všetko funguje"). Ďalej: umývačka → 600 bez zmeny spotrebiča (čakám nesúlad
    s 450 spotrebičom v Kontrole/Spotrebičoch), CAB-006 späť bez očakávania.
17. Štúdio → Spotrebiče pred vrátením CAB-006: riadok Rúra „— nevybraný · vlastník očakáva rúra", oranžové „nevybraný" ✅ (screen).
    CAB-006 späť bez očakávania → riadok rúry zmizol ✅. **Umývačka CAB-008 → šírka 600**, spotrebič 450 ostal → Spotrebiče „✓ v poriadku" ❌
    (Michal čaká aspoň oranžové). MCP: `width 600`, ale **`dw_class` slotu ostalo 450** → kontrola triedy (model 450 vs slot 450) nič nenájde.
    → postreh S5.
18. Trieda slotu prepnutá na 600 → Spotrebiče oranžové „trieda nesedí"; Inspector: Trieda „60 · Bosch SPV6EMX05E ✗" (červené),
    box Spotrebič „Umývačka · trieda 450 ≠ slot 600" ✅ — kontrola triedy funguje (screeny).
19. Trieda 450 + **šírka 400** → bez upozornenia ❌ (spotrebič s nikou min. 450 sa do 400 nezmestí). MCP: width 400, dw_class 450, niche
    width_min 450; v `ApplianceChecks::AXES` umývačka **nie je** (kontrola niky len chladnička, rúra, mikrovlnka) → pri umývačke sa kontroluje
    len trieda, nie rozmer. → doplnené do S5.
20. **CAB-009 horná** vložená, natiahnutá Mierkou, Ctrl+Z vráti jedným krokom ✅. MCP: 1200 × 880 × 320, zavesenie z = 1400, bez nôh,
    dvere auto (2 krídla) → 2 × 3 závesy (`zavesy-podla-vysky`), 2 závesy hornej skrinky → **B18 ✅ celý** (Dolná, Horná 1400, Rohová L/P, Umývačka 45/60).
21. Umývačka vrátená na 450/450 → Inspector OK, ale **Štúdio → Spotrebiče ďalej „trieda nesedí"** ❌. Sekcia Spotrebiče nemá „Obnoviť";
    „Obnoviť" v inej sekcii nepomôže. Kontrola (čerstvá) je v poriadku — pri umývačke len chýbajúca cena. MCP: čerstvý zber = 450/450 bez
    nálezu. Po zatvorení a otvorení Štúdia → „✓ v poriadku". → postreh S6.
22. **CAB-010 horná s výklopom** 1200 × 880 × 320, výklop HK top (2 tyče). Inspector hneď ukáže nevhodnosť ✅. MCP konflikty:
    `lift_dimension_unsupported` („HK top… výška korpusu 880 mm je nad 600 mm") + `lift_class_missing` („LF 14878,1 … nad tabuľkou HK top
    (max 9000)"); položka výklopu ostáva v kovaní (Nákup by ju mal ukázať červenú).
23. CAB-010 znížená na 440 → HK top trieda **22K2700**, konflikty 0 ✅. **CAB-011** horná 1200 × 440, **HL top** → **22L2500**, konflikty 0 ✅.
    Michal skúšal neplatné kombinácie: HL nepustí Tip-On ✅, prerastenie rozmeru → upozornenie „použitie do 1800" ✅; Ctrl+Z, Kontrola
    a Nákup kovania priebežne bez chyby → **A11 ✅** (výklop naplní kovanie bez „chýba kit"; zásuvka ✅ skôr).
24. **CAB-012 chladničková** 600 × 1960 × 550, nohy 150 (typ `lower`, vysoká), 2 dvere (spodné 760 + horné auto), závesy 2 + 3, zatiaľ bez
    očakávania/modelu. **CAB-013 spotrebičová** 600 × 1960 × 510, prázdna (bez čiel). Ďalej: vybavenie, police, dvere.
25. CAB-012 očakáva chladničku, CAB-013 rúru. Do CAB-012 vložený **Beko BCNA306E5ZSN** (nika 560 / 1940–1950 / 555) → nezmestí sa, viditeľné
    v modeli aj Inspectore ✅ + upozornenie „hrana dverí nesedí" ✅. MCP verdikt: `clash` „nezmestí sa: výška 1774 < 1940 · hĺbka 550 < 555" ✅;
    pásma dverí z listu: spodné 629, medzera 71, horné 1159, odsadenie 40.
26. CAB-012 výška → 2130: nika ✓ (šírka, výška, hĺbka) ✅. Box Spotrebič: „hrana čiel 744 mimo 679–727, odporúčané 703 — odporúčané delenie
    podľa praxe (presah ≥ 10, škára 3)"; Náhľad Korpusu kreslí pásma (1200 / hrana 744 / 727 / 679 / 629) a kóty telo 1980, V 2130 ✅ (B17 ✅).
    Problém: tento náhľad pásiem je **len v Korpuse**, čelá sa nastavujú v Čelách → neustále preklikávanie. → postreh S7.
27. **CAB-013 spotrebičová** 600 × 2130 × 560, vložená rúra **Bosch HBG774KB1** → verdikt „nika ✓ — šírka a hĺbka ✓" ✅. Zóny 3 pod sebou
    (706 / 585 nika / 617), čelá: zásuvka 720 Tip-On (Atira → `atira_p2o_v1`) · riadok bez čela (nika) · dvierka 650 Tip-On (2 závesy);
    chrbát „none" (komín 50 mm na vetranie), konflikty 0 ✅. Michal: odkaz na technický list sa otvoril ✅, úprava zón ✅, ďalšia zásuvka ✅.
28. Voľné dosky (všetky `free_panel`, materiál `UNI_DOSKA_18`, bez hrán): **BRD-001** pracovná 4666 × 600 × 12 (mimo platne — zámerne),
    **BRD-002** 511 × 600 × 12, **BRD-003** krycí 600 × 2130 × 18, **BRD-004** sokel 4116 × 150 × 18 (mimo platne — zámerne),
    **BRD-005** sokel 1783 × 150 × 18. Sledovať: dosky 12 mm majú zatiaľ materiál UNI **18** (hrúbka ≠ materiál) — pri priradení kompaktu
    overiť Kusovník (skupina, Hr.), Kontrolu a nárezový plán (prerastenie platne).
29. BRD-001 → kompakt **F206_ST9_KOMPAKT_12_4100X920** (Pietra Grigia). Kontrola: **1 RED** „Dielec „Doska 800×600“ (BRD-001) 4666 × 600 mm
    (hotový rozmer vrátane ABS) sa nezmestí na platňu 4100 × 920 mm" ✅ (+ 117 oranžových v 12 riadkoch, 0 z 12 skriniek bez nálezu).
    Export prebehol bez otázky — podľa návrhu („nález 6": RED nikdy neblokuje, súhrn len do statusu a LOGu). → postreh S8.
    Vedľajšie: názov dosky „Doska 800×600" nesedí so skutočným rozmerom 4666 × 600 → postreh S9.
    VEPO (export do `H:\Môj disk\disk - NOXUN\NOVY BYT\výroba\smoke_hard_max\` — posledný priečinok bol reálny projekt NOVY BYT):
    8 CSV + LOG; LOG má „KONTROLA — 1 kritických (RED), 117 na kontrolu" s riadkom RED ✅. **Všetkých 5 dosiek ide do VEPO ako
    „Doska 800×600 d1…d5"** (S9 potvrdené). BRD-002 (12 mm, materiál UNI 18) ide do súboru `doska_uni_dtdl_12.csv` s hrúbkou 12.
30. Pracovné dosky kompakt 12: BRD-001 → 4000 × 600 (v rozmere), BRD-002 511 × 600, nová **BRD-006** 666 × 600 — všetky F206 ST9 KOMPAKT 12.
    Sokle BRD-004/005 + krycí BRD-003 → **H1181 ST37 Halifax 18,6** → hrúbka sa sama prepla na 18,6 ✅; Kontrola RED pre dlhý sokel
    4116 mimo platne ✅. Všetky dosky stále „Doska 800×600" (S9).
31. BRD-005 zmena orientácie, hrany doplnené. MCP: kompakt (BRD-001/002/006) bez hrán, ležiaca, smer dĺžka; krycí BRD-003 Halifax ABS 23×0,8
    dookola, stojaca, smer šírka; sokle BRD-004/005 ABS 23×0,8 na L1+L2, stojaca. Dosky hotové → ďalej materiály skriniek. Nápad → S12.
32. Materiály skriniek vyplnené → oranžové nálezy hrán zmizli (zo 117); ostáva 1 RED (dlhý sokel BRD-004 mimo platne — zámer) a pár
    očakávaných oranžových (spotrebiče bez ceny ap.).
33. Prechod Štúdiom (Michal): Rozpočet upozornil na neaktuálne ceny → prepočet „zmenené 1 · bez zmeny 24" ✅; položky mimo Demos ručne OK;
    ostatné sekcie OK. Nárezový plán: kompakt 2 platne (posledná 19 % — upozornenie), Halifax 3 platne + **„Nezmestí sa — plán neúplný"**
    s BRD-004 4116 × 150 („hlási aj Kontrola") ✅; upozornenia na malú výťažnosť ✅.
    Exporty v `_dev\SMOKE hard MAX\` (19:56): `kovanie_smoke_hard_max.csv`, `Rozpocet SMOKE_HARD_MAX - AKT 16.10. 2026.xlsx`,
    `Cenova ponuka SMOKE_HARD_MAX - 16.10.2026.xlsx`. **VEPO tam nie je** — posledné VEPO je z 18:05 v NOVY BYT (ešte s UNI materiálmi).
    Kontrola CSV kovania (MCP proti modelu): závesy 104717 = 15 (CAB-004 4 + CAB-009 6 + CAB-012 5) ✅, krytky 21 ✅, Tip-On klasické
    závesy PTO 245723 = 6 + BLUM Tip-On 3 (3 Tip-On dvere) ✅, Quadro V6 400 ✅, Atira sety ✅, výklop HK 22K2700 ✅.
    Postreh: názvy dielov bez diakritiky („Dvierka 1 lave", „Bok lavy", „Zasuvkove celo") — v Nárezovom pláne viditeľné → S13.
34. **VEPO** do `_dev\SMOKE hard MAX\smoke_hard_max\` (19:58): 5 skupín — 101 PE biela HDF 3 (9 ks), 500 SM biela DTDL 16 (13 ks),
    500 SM biela DTDL 18_36 (57 ks), F206 kompakt 12 (3 ks), H1181 Halifax 18_36 (26 ks); vyradené 0; skrátené názvy 4 (limit VEPO 20 znakov,
    plný tvar v LOGu) ✅; LOG KONTROLA 1 RED (sokel BRD-004) + 10 ORANGE (spotrebiče bez ceny, riadky rozpočtu bez ceny/m², úchytky UKW
    CAB-004 a výklop CAB-010 bez setu, skrátený názov) ✅. Hrany: kompakt bez, krycí dookola, sokle len L ✅. Halifax 18,6 ide do VEPO
    ako obchodná hrúbka **18** — podľa VEPO_KONTRAKT („Normalizácia hrúbok"), nie chyba. **S9 potvrdené aj tu** („Doska 800×600 d1–d6").
    S13 doplnok: VEPO používa vlastné krátke názvy (Dv1 LP, Zas celo 1, Výklop 1 — s diakritikou), bez diakritiky sú len interné názvy v UI.
    → **A1 ✅** (4 exporty prebehli; porovnanie so starou cestou = tieňová zákazka neskôr).
35. Michal zaradil sety v knižnici: „CHladničkove" → dvierka · klasické, „P2O Hettich" → dvierka · Tip-On (overené v `hardware_sets.json`).
    Teraz 2 klasické + 2 Tip-On závesové sety → test výberu pri krídle (A21, A22, A24–A26) na CAB-004 / CAB-005.
36. Po teste (MCP): **CAB-004** hĺbka 796 (zmenená), uložené `hinge@…/wing:left = chladnickove`, pravé bez výberu → výber krídla prežil
    zmenu hĺbky ✅. **CAB-005** otváranie prepnuté na **klasické**, pri krídle ostal `p2o-hettich` (Tip-On set) → podľa návrhu (H18b Q3 A)
    má Nákup ukázať RED „nesedí s čelom" (blokuje Nákup, rozpočet, ponuku). Overenie zobrazenia — otázka Michalovi.
    Michal: Kontrola aj Kovanie červené, exporty zastavené s hláškou o oprave CAB-005 ✅; Ctrl+Z / Ctrl+Y ✅; hláška „…výber zrušený." ✅.
    → **A21 ✅ · A22 ✅ · A24 ✅ · A25 ✅ · A26 ✅** (na súčasných setoch, nie TEST fixtúra).
    Poznámka k S8: tento RED (nesúlad závesu) exporty **blokuje**, RED „nezmestí sa na platňu" nie — dva druhy RED s rôznym správaním.
37. **Oddiel D.** Záloha celého `%APPDATA%\NOXUN\Engine` (P3). **D1 ✅** — zmena ceny Olepovanie ABS + počtu nôh v Pravidlách („prestavaných
    12 skriniek"), vrátené a uložené bez hlášky; porovnanie so zálohou: pravidlá zhodné, `supplier_settings.json` ceny zhodné, pri uložení
    povýšený `std` 1→2 a doplnené výslovné `kerf_mm 5 / trim_mm 10 / dup_allowance_mm 10` (rovnaké hodnoty ako doteraz).
    **D2 ✅** — `supplier_settings.json` = `[]` (prepísal Michal ručne; agentovi zápis do živého profilu zablokovala poistka) → červený banner
    „Nastavenia dodávateľa sú poškodené — číta sa záloha, zápisy sú vypnuté (oprav alebo zmaž súbor …)", Uložiť sivé, sadzby Michalove
    (Olepovanie 0,92 / 1 / 1,11 / 1,5), Rozpočet 5 845,00 € počíta so sadzbami zo zálohy.
    Vedľajšie z Rozpočtu: „Opracovanie pracovnej dosky — 0 paušálov · zákazka neobsahuje pracovnú dosku", hoci má 3 kompaktné pracovné
    dosky (voľné dosky `free_panel`) → postreh S15.
    **D3 ✅** — Michal zmazal `supplier_settings.json` → Obnoviť → banner zmizol, hodnoty jeho, drobná zmena uložená (nový súbor 22:07,
    `std 2`, olep 0,90). Pre D5–D10 pripravené kópie testovacieho modelu `_dev\D_okno_A.skp` a `_dev\D_okno_B.skp`.
    D4 ⏭ (voliteľný, to isté ako D2 pre názov zákazky). **D5 ✅** — B po uložení globálu v A: „Tento projekt ešte nemá vlastné pravidlá
    a preberá globálne predvoľby — tie medzitým zmenilo iné okno SketchUpu. Nič sa neuložilo, tvoje úpravy ostali vo formulári. Klikni
    Uložiť znova…"
    **D6 ✅ · D7 ✅** (Michal: „hotovo" — červená hláška pri globáli po zmene z druhého okna, úpravy ostali).
    **D8 ✅** — šírka 700 z A sa po uložení hĺbky v B ukázala v B; hĺbka 450 z B sa v A ukázala až po zatvorení a otvorení Inspectora
    (A sa sám neobnovuje — v súlade s checklistom). **D9 ✅** — „Rozmerové rady (Sokle) medzitým zmenilo iné okno SketchUpu — nič sa
    neuložilo. Editor ukazuje aktuálne uložené rady, zmenu zadaj znova." (Pozn.: pri radoch sa rozpísaná zmena B zahodí, pri Pravidlách
    ostáva vo formulári — drobná nejednotnosť, len poznámka.) **D10 ✅** — jedno okno: uloženie pravidiel aj radov bežne (D1, D8).
    Záloha vrátená pri zavretom SketchUpe: `dim_series.json`, `hardware_rules.json` (+.bak), `supplier_settings.json` (+.bak) zo zálohy
    (hash zhodný); `usage_stats` ponechané živé, nový `dim_series.json.bak` ponechaný (neškodí).
38. **Oddiel E:** **E1 ✅ · E2 ✅ · E3 ✅** (Ruby konzola bez chýb) **· E5 ✅ · E6 ✅** (Michal: splnené, potvrdené).
    **E8 ✅** (zrušené ukončenie bez „onQuit", vloženie potom funguje) **· E7 ✅** (Súbor → Koniec s Inspectorom, Štúdiom a skrinkou na kurzore
    na SketchUp 2026.2 bez chyby, nový štart normálny). **E9 ✅** (Šablóny, Materiály, Kovanie, Spotrebiče, O plugine — prejdené počas zákazky).
    **E10 ✅** (MCP: v `%APPDATA%\NOXUN\Engine` jediný nový názov `dim_series.json.bak` — záloha pri uložení radov v D8, nie nový druh súboru;
    obnovené súbory sedia so zálohou, `direction_check.json` sa líši len stavom prepínača z E2/E3).
39. **Agent cez bridge (17.10. ~00:10)** v testovacom modeli `_dev\SMOKE_bridge_test.skp` (kópia ENGINEtests, overený `model.path`):
    - **A18 ✅** — dolné s nohami: š. 50 → 2 nohy v strede šírky (vpredu a vzadu) + 1 príchyt sokla; š. 150 → to isté; š. 200 → 4 nohy + 1 príchyt.
      (Pozn.: skrinka so **soklom** — support `plinth` — príchyt nedostane; pravidlo `prichyt-sokla` platí len pre nohy, zámer.)
    - **B22 ✅ (jadro)** — dolná š. 50 s hrúbkou 20 → builder odmietne „Šírka je príliš malá vzhľadom na hrúbku materiálu", nič nepostaví;
      horná š. 50 sa postaví bez nôh (2 závesy hornej skrinky). Červený text v Inspectore videl Michal skôr (bod 2).
    - **B23 ✅** — dolná 600 (4 nohy) Mierkou na 50 → prestavba na š. 50, 2 nohy, mierka vrátená na 1,0; **jedno Späť** → 600 so 4 nohami.
      Pri hrúbke 25 Mierka na 50 → skrinka ostane 600 (mierka vrátená), hlášku v okne agent nevidí.
    - **C19/C20 pripravené:** v tom istom modeli má CAB-007 **odpojený dielec** (ľavý bok vytiahnutý na koreň modelu) — model uložený.

## Postrehy

| # | Kde | Čo | Závažnosť | Kam zaradiť |
|---|---|---|---|---|
| S1 | Inspector · vkladacia karta + šablóny | Dvojklik na šablónu vloží skrinku s rozmermi šablóny a ticho ignoruje rozmery práve prepísané v karte (šírka, zamknutá výška, sokel). Používateľ čaká, že platí to, čo vidí v karte. Návrh: dvojklik použije hodnoty karty, alebo karta pri výbere šablóny ukáže jej rozmery a dvojklik to vysloví. | UX, riziko zlého rozmeru (bez dopadu na výrobu, ak sa skontroluje) | rozhodne Michal |
| S2 | Inspector · Čelá/Kovanie zásuviek | **Nápad:** tlačidlo „rovnako pre všetky zásuvky" — nastavenie prvej zásuvky (otváranie, konštrukcia, variant/výška) jedným klikom skopíruje na ostatné zásuvky skrinky. | nápad (UX, šetrí kliky) | rozhodne Michal |
| S3 | Inspector · Korpus → strop | Plný strop nemá odsadenie zhora (výstuhy áno, 20 mm). Po prepnutí výstuhy → plný odsadenie z panela zmizne (v dátach ostáva). Otázka: je znížený plný strop potrebný (napr. pod pracovnú dosku, integrovaná úchytka)? Ak áno → nápad; ak nie → v poriadku, prípadne len poznámka „pri plnom strope sa neodsadzuje". | nápad — **Michal: áno, doplniť** | zásobník (nová funkcia) |
| S4 | Číslovanie skriniek | Po zmazaní skrinky dostane ďalšia nová jej číslo (CAB-008 rohová → zmazaná → umývačka CAB-008). Otázka: vadí to, keď už bol VEPO/kusovník odoslaný a číslo sa v dielni spája s inou skrinkou? | otázka (nízka) — **Michal: nevadí**, po odoslaní sa zákazka nemení (opravy = nový projekt) | uzavreté, bez akcie |
| S5 | Umývačka · Spotrebiče/Kontrola | Umývačka 45 prepnutá na šírku 600 so spotrebičom triedy 450 ukazuje „✓ v poriadku". Michal menil **pole Šírka** v Inspectore; trieda slotu je samostatná rozbaľovačka „Trieda" (600 · 60 cm / 450 · 45 cm) v karte umývačky. Príčina: zmena šírky nezmení triedu slotu (`dw_class` ostane 450) a kontrola porovnáva len triedu modelu s triedou slotu, nie so šírkou skrinky. **Rozhodnutie Michala:** triedu automaticky NEprepínať (nesúlad môže byť zámer); po zmene šírky, keď šírka ≠ trieda, **upozorniť (neblokuje)** + Kontrola/Spotrebiče dajú oranžové pri nesúlade šírky skrinky a triedy (slotu aj modelu). Kontrola triedy model↔slot už funguje (bod 18). **Doplnok (bod 19):** šírka 400 + trieda 450 + spotrebič s nikou min. 450 → žiadne upozornenie; umývačka nemá kontrolu niky vôbec (len trieda). Treba aj kontrolu niky umývačky (šírka/výška/hĺbka voči listu, ako pri rúre/chladničke) → oranžové „nezmestí sa". | **chyba** (stredná — zlý spotrebič v ponuke/objednávke) | oprava x.y.z (fix) |
| S6 | Štúdio · Spotrebiče | Sekcia Spotrebiče drží starý stav: po vrátení umývačky na 450/450 svieti ďalej „trieda nesedí", hoci Kontrola aj model sú v poriadku. Sekcia nemá „Obnoviť" (ostatné ho majú, C2) a „Obnoviť" v inej sekcii ju neprepočíta; pomôže až zatvoriť a otvoriť Štúdio. Treba: Spotrebiče sa prepočítajú pri vstupe/zmene modelu ako Kontrola + tlačidlo „Obnoviť". | **chyba** (stredná — neplatná výstraha) | oprava x.y.z (fix) — súvisí s C2 |
| S7 | Inspector · Náhľad, kontext Čelá | Pásma chladničky (hrana čiel, rozsah 679–727, odporúčané 703) sú v Náhľade len v kontexte Korpus. Čelá sa nastavujú v kontexte Čelá → po každej zmene výšky čela preklik do Korpusu a späť. Návrh: zobraziť pásma spotrebiča aj v Náhľade Čiel, ideálne ako ďalší prepínač vrstvy dole (vedľa Zóny · Čelá · Kovanie · Olep, napr. „Spotrebič"). Bonus: tlačidlo „nastav odporúčané delenie" (703). | UX (vysoký prínos pri chladničkách) | rozhodne Michal — UI dávka |
| S8 | Exporty · Kontrola RED | Export prejde aj pri červenom náleze (dielec sa nezmestí na platňu) — zámer z externého auditu („nález 6": semafor varuje, nikdy neblokuje; súhrn len v statuse a LOGu). Michal chce: pred exportom pri **akomkoľvek RED** vyskakovacie okno s **konkrétnymi bodmi** → po potvrdení export prebehne (neblokuje, ale nedá sa prehliadnuť). Vzor už existuje: Rozpočet XLSX pri riadku bez ceny (A12 — zastaví, druhý klik a potvrdenie). Pozn.: niektoré RED exporty už **blokujú úplne** (nesúlad závesu s čelom, chýbajúci kit zásuvky — bod 36), iné nie (nezmestí sa na platňu) — pre používateľa nejednotné; návrh zjednotiť: blokujúce ostanú, ostatné RED = potvrdzovacie okno. **Rozhodnutie Michala 16.10.:** export sa dá spraviť **vždy**; každý RED vyvolá kontextové okno s výpisom nálezov a potvrdením; ORANGE bez potvrdzovania. (Pozn. orchestrátora pre package: pri dnes blokujúcich RED — nesúlad závesu, chýbajúci kit — export po potvrdení vydá položku, ktorá nesedí; okno to má povedať konkrétne, napr. „v nákupe bude záves bez piestu".) **Doplnok Michala:** v CSV kovania (a v ostatných exportoch, ktoré číta človek — XLSX rozpočtu a ponuky) označiť dotknuté položky v jednom stĺpci; **VEPO nie** (číta ho stránka, nie človek → formát VEPO sa nemení). | zmena pravidla (výrobné — chráni pred chybnou objednávkou) | rozhodne Michal; dávka výrobná (exporty) |
| S9 | Voľná doska · názov | Doska vložená ako „Doska 800×600" si nechá názov aj po zmene na 4666 × 600 (Kontrola: „Doska 800×600“ (BRD-001) 4666 × 600). **Overené: ide do VEPO** — všetkých 5 dosiek (pracovné, krycí, sokle) má vo VEPO názov „Doska 800×600 d1…d5". V dielni zavádza. Návrh: názov z rozmeru sa prepočíta, kým ho používateľ ručne nepremenoval (alebo predvolený názov podľa účelu: „Pracovná doska", „Krycí diel", „Sokel"). | **chyba** (stredná — výrobný výstup, rozmery sú správne, zavádza len názov) | oprava x.y.z (výrobná — mení VEPO) |
| S10 | Exporty · priečinok | Výber priečinka pri exporte otvára posledný použitý priečinok (`last_dir` vo `vepo_settings.json`) → smoke export padol do reálneho projektu NOVY BYT. **Návrh Michala:** všetky exporty (VEPO, CSV kovania, XLSX rozpočtu aj ponuky) otvoria okno v **priečinku uloženého .skp**, s ktorým sa pracuje; neuložený model → posledný použitý priečinok. | nápad (UX + prevencia omylu) | rozhodne Michal — dávka exportov (cesta, nie obsah) |
| S11 | Hlavička Štúdia · názov zákazky | Michal: názov zákazky a názov .skp sú dve veci; návrh — názov zákazky predvyplniť podľa súboru (prepis ostáva, „Untitled" ignorovať). **Fakt:** to už čiastočne platí (H7) — bez zadaného názvu hlavička ukáže „SMOKE_HARD_MAX · podľa súboru" a exporty sa volajú `smoke_hard_max_…`. **Michal potvrdil:** chýba len to, že po kliku na ✎ je pole prázdne → predvyplniť menom súboru (bez prípony; pri Untitled prázdne), aby ho stačilo doupraviť. | drobné UX | UI dávka (malá) |
| S12 | Karta dielca · hrany | **Nápad (Michalovi „dlhšie chýba"):** popri „olepiť všetky 4 hrany" aj opačná akcia „**všetky bez olepu**" jedným klikom (napr. pri kompakte, pracovnej doske, zmene dekoru). | nápad (UX) | rozhodne Michal — UI dávka (malá) |
| S13 | Názvy dielov | Názvy dielov skriniek sú bez diakritiky („Dvierka 1 lave", „Bok lavy", „Vystuha predna", „Zasuvkove celo") a tak ich ukazuje aj Štúdio (Nárezový plán, Kontrola). VEPO ich nepoužíva (má vlastné krátke názvy s diakritikou, bod 34) → čisto kozmetika v UI (Nárezový plán, Kontrola). Návrh: ukazovať s diakritikou („Dvierka 1 ľavé", „Bok ľavý"). | kozmetika (bez vplyvu na výrobu) | rozhodne Michal |
| S14 | Štúdio · Kovanie → Sety | Michal sa pri vytváraní nového setu (Blum závesy) stratil. V knižnici sú 2 závesové sety **nezaradené** („CHladničkove", „P2O Hettich" — bez Použitia a Otvárania) → pri krídle sa neponúkajú, takže to vyzerá, že je len 1 set na typ. Návrh: pri vytváraní setu sprievodca krok za krokom (typ → použitie → otváranie → položky z katalógu) a pri nezaradenom sete jasná veta „tento set sa nikde neponúkne, kým nevyberieš Použitie a Otváranie". | UX (stredné — bez toho sa nové sety reálne nedajú používať) | rozhodne Michal — UI dávka |
| S15 | Rozpočet · Služby | „Opracovanie pracovnej dosky: 0 paušálov · zákazka neobsahuje pracovnú dosku", hoci zákazka má 3 kompaktné pracovné dosky. Voľná doska má rolu `free_panel` a nedá sa označiť ako pracovná doska → služba sa nezapočíta (ručný prepis ide). Návrh: pri voľnej doske voľba „Účel: pracovná doska / krycí diel / sokel / iné" — rieši aj S9 (názov) a služba sa započíta sama. | **cenová** (stredná — služba chýba v ponuke) | rozhodne Michal — výrobná/cenová dávka |
