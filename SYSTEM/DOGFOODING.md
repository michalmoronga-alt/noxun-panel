# Dogfooding zápisník — otvorené postrehy

> **Čo to je:** plné znenie **otvorených** postrehov z reálnej práce — D-čísla aj vedomé odklady bez čísla. Skupiny a ich poradie = bloky prác v [PLAN.md](PLAN.md); PLAN drží pri každej položke len jednu vetu, plný text je tu. *(PLAN nesie navyše aj prenesené záväzky z vízie V1, ktoré vlastný postreh nemajú — tie sa sem nekopírujú.)*
> **Údržba:** nový postreh = nové **D-číslo** do skupiny podľa bloku (číslovanie je trvalé, nerecykluje sa); vyriešený postreh **z tohto súboru zmizne** — plný text ide do sekcie
> „Vyriešené (plné texty)" v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md) (príčina, riešenie, PR) a **jeden riadok navrch INDEXU v tom istom súbore**.
> Tu ostávajú **len otvorené** postrehy (od 26.8.2026, dávka Docs cleanup B — stráži guard). Zmena zaradenia = presun medzi skupinami tu aj v PLAN.
> **Postrehy Michala sa píšu HNEĎ**, hocikedy a na hociktorú tému — zaradenie robí agent (plné pravidlo: [PLAN.md](PLAN.md), sekcia „Pravidlo pre postrehy").
> **Kde je zvyšok:** história zápisníka (priebežné stavy, 2A migračná mapa, hardening a sedenia V0.5, priebeh seedu, zodpovedané otázky) → [archiv/DOGFOODING_historia.md](archiv/DOGFOODING_historia.md) · odpočet merača D-25 → [zdroje/MERAC_D25_odpocet_2026-08.md](zdroje/MERAC_D25_odpocet_2026-08.md) · história dávok → [archiv/KRONIKA.md](archiv/KRONIKA.md).

## UI dlhy — k bloku 1b (STABILIZAČNÁ REVÍZIA)

*(Blok **1 · UI 2.0** je od v0.8.0 hotový a jeho plný text žije v
[archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md). Postrehy nižšie sa v ňom
nevyriešili, takže od 26.8.2026 visia na bloku **1b · STABILIZAČNÁ REVÍZIA**, odrážka **F**
v [PLAN.md](PLAN.md) — **D-51 uzavreté 6.9.2026** (archív); **D-27** je vyriešené dávkou F/D-27 (v0.8.13)
a položka „výklop ako samostatný typ čela" dávkami KOV-A1 + KOV-A2a (v0.9.16). Skupina je prázdna.)*


## KOVANIE — vlastný blok (za GHOST VKLADANÍM; poradie rozhodol Michal 26.8.)

*(Blok v [PLAN.md](PLAN.md) sa 26.8. vyčlenil z bloku 4; predpoklad štartu je USER-debata o setoch.)*

- **D-109 · Pomer člena setu „1 ks na N nôh"** (Michal 24.8., prvý test v0.8.0) — set kovania vie dnes počítať člena len **per unit** (na kus) alebo **per owner** (na skrinku). Chýba pomer typu „**1
  príchyt sokla na 4 nohy**": pri príchytoch soklovej lišty sa počet neviaže na skrinku ani na jednotlivú nohu, ale na ich **počet**. Dnes sa to musí dopočítať ručne — a práve to má set robiť za
  človeka. *(Nefixované v TEST-1: mení dátový model setu.)*
- **D-111 · Výber setu podľa výšky sokla je schovaný** (Michal 24.8., prvý test v0.8.0) — predvoľba, ktorý set kovania sa použije podľa výšky sokla, žije v **Predvoľbách projektu** v sekcii Kovanie. Je
  to nastavenie, ktoré človek hľadá pri **vkladaní skrinky**, nie v katalógu — dnes ho nájde len ten, kto vie, že tam je. *(UX.)*
- **D-114 · Rad piktogramov namiesto tlačidiel „+ pridaj dvere" / „+ pridaj čelo" + upratanie kontextu Čelá** (Michal 3.9., smoke v0.9.20 po KOV-A) — nové čelo sa má pridávať
  **priamo výberom typu**: namiesto dvoch textových tlačidiel jeden rad dlaždíc s tými istými sprite ikonami ako typegrid karty (dvierka · zásuvka · výklop · sklop · blenda; „bez
  čela" rozhodnúť), klik = nový riadok daného typu (dvierka ďalej cez výrobcu smeru „neurčené", pravidlo (a) karty). Rad zaberie **ten istý jeden riadok** ako dnešné dve tlačidlá.
  Michal zároveň: „celkovo UI čiel bude treba po tomto zásahu upratať — necháme na koniec, opäť spravíme UI/UX balík". *Stav: ZAPÍSANÉ — UI/UX balík kontextu Čelá **na koniec
  bloku KOVANIE** (po KOV-D/E/F, keď bude známy celý obsah karty: zámky osí, závesy, resolved systém); dovtedy sa nerobí.*
- **D-119 · Presah dverí do strán per strana** (Lucia 6.9., prvý test pluginu na jej notebooku) — presah/okraj čela do strán je dnes **jedna hodnota pre obe strany**
  (`gap_sides`, Čelá); v praxi treba ľavú a pravú stranu nastaviť **zvlášť** (napr. čelo presahuje cez bok len na viditeľnej strane, pri susede ostáva škára). Hore/dole už
  zvlášť sú (`gap_top` / `gap_bottom`). *Stav: OTVORENÉ — zaradiť do UI/UX balíka kontextu Čelá (D-114) alebo skôr, ak blokuje prácu; mení config čela (CONFIG_SCHEMA bump).*
- **D-120 · Úchytkový profil (UKW) aj na dolnej a bočných hranách** (Lucia 6.9., prvý test) — profil sa dnes osadzuje **len na hornú hranu** čela; treba voľbu hrany:
  horná (dnes) · dolná · ľavá / pravá bočná (vysoké dvere, skrine). Registry `front_profiles.rb` hranu dnes **nepozná** — záznam nesie len `reduction`, popisky, obrys, hĺbku
  a výšku, `geometry`/`options` hranu nevracajú a modul výslovne predpokladá hornú hranu (komentár D-90 sľubuje len, že config to unesie bez migrácie). **Rozsah D-120 =**
  config čela (hrana) **+ registry/API** (hrana ako parameter profilu) **+ všetci konzumenti**: matematika panelu vo `Fronts` (skrátenie v inej osi), pravidlo kovania (dĺžka
  rezu), vizuál v modeli (renderer v `CabinetBuilder`), náhľad a UI panela; smer dekoru čela sa neotáča. *Stav: OTVORENÉ — zaradiť ku KOV-F (úchytka podľa
  klasifikácie) alebo do UI/UX balíka Čiel; rozhodne Michal.*
- **D-125 · Hmotnosť v Inspectore (Základné) je prázdny placeholder** (Michal 6.9., KLINIKA) — riadok „Hmotnosť" v informačnom stĺpci sektora Základné ukazuje vždy „—":
  je to **statický placeholder z UI 2.0** (`panel.html` `#infWeight`, tooltip „Hmotnosť príde s kovaním (fáza 3)"), JS ho nikdy neplní a payload žiadnu hmotnosť nenesie.
  Nie je to bug, ale nedokončené miesto. Hustota per typ materiálu už existuje (`Materials.density_for`, M-C), takže **hmotnosť skrinky = Σ dielcov (dĺžka × šírka × hrúbka
  × hustota typu)** je odvodené čítanie nad BOM riadkami. Pravidlá: dielec s neznámou hustotou (typ „iný", UNI) sa **nevymýšľa** — výsledok ukázať ako „≈ X kg" s tooltipom
  „bez N dielcov (materiál bez hustoty)"; pri všetkých neznámych ostáva „—". *Stav: OTVORENÉ — zaradiť ku **KOV-E** (tam vzniká helper hmotnosti čela z tých istých vstupov;
  hmotnosť skrinky = ten istý helper nad všetkými dielcami) alebo ako malá samostatná dávka po KOVANÍ; do payloadu Inspectora pribudne `weight_kg` + `weight_missing` (aditívne).*

## KONTROLA + VÝROBA

- **D-121 · Názvy odvodených dielcov zásuviek sú pre VEPO pridlhé a nič nehovoria** (Michal 6.9., objednávka po KOV-C; **VYSOKÁ PRIORITA — výrobný výstup**) — riadky
  vo VEPO exporte typu `Dno zasuvky Fmslwqdm2-9-464wsa` / `Dno zasuvky Fmslwqew7-a-u7mna2`: názov nesie **interné id čela** (`construction.rb`: `"Dno zasuvky #{front_id}"`,
  KOV-C2b) a `VepoExport.row_name` ho nemá v mape skratiek `SHORT_NAMES`, takže prejde celý. Dôsledky: (1) používateľovi id nič nehovorí, (2) **VEPO import odmieta polia nad
  20 znakov** — pred odoslaním sa musia riadky ručne prepisovať (D-113 to riešila len pre korpusové dielce). „Aj niektoré iné dielce po poslednej zmene" — preveriť všetky
  názvy, ktoré KOV-C/D pridali (dno, chrbát, boky zásuvky, sync tyč…). Riešenie: **generované názvy dielcov ≤ 20 znakov** (guard nad GENEROVANÝMI názvami; voľné názvy dosiek ostávajú pass-through s `NAME_MAX` 60 podľa kontraktu
  v1.1 — `test_d112_d113_vepo.rb` ich chráni) + ľudské názvy odvodených dielcov (`Zas dno s1`, `Zas chrb s1`…; číslo zásuvky/čela namiesto id — `PartKeys.human_label` D-92 vzor) aj v kusovníku a LOGu.
  *Stav: OTVORENÉ — **fix dávka pre implementačné okno (KOVANIE)** hneď, nečaká na koniec bloku; audit NIE, kým sa mení len generovanie názvov (kontrakt v1.1 nedotknutý). **Otázka na Michala (Codex #322 P2):** VEPO import podľa teba 6.9. „vyhadzuje chybu
  pri poli nad 20 znakov" — kontrakt v1.1 (POJMY) doteraz hovoril, že 20 znakov je len TLAČ nálepky a CSV pole nesie do 60. Ak import naozaj odmieta, je to **revízia kontraktu**
  (NAME_MAX, voľné názvy) = samostatná kontraktová dávka s auditom, nie súčasť tohto fixu.*
- **D-122 · Kontrola hlási každý UNI dielec zvlášť** (Michal 6.9., zákazka KLINIKA) — Štúdio → Kontrola ukazuje pri UNI farbách **každý dielec ako upozornenie**; pri tvorbe
  je prirodzené, že dielce ostávajú UNI, kým sa nezvolia materiály. Želanie: **jedno upozornenie „použité nenahradené UNI farby"** a pod ním zoskupené dotknuté dielce (rozklik).
  *Stav: OTVORENÉ — V1, malá UI dávka v sekcii Kontrola (zoskupenie nálezov podľa príčiny; semafor ostáva ORANGE, neblokuje).*
- **D-94 · Traceability v celkovom súpise kovania — rozklik položky na miesta použitia** (Michal 9.8., test kovania na reálnej zákazke) — nákupný zoznam v okne Výroba povie „357695 × 12", ale nie
  **kde** tých 12 kusov je. Pri kontrole objednávky (a pri hľadaní, prečo je počet iný, než človek čakal) treba vedieť rozobrať riadok na **skrinky a čelá**, z ktorých vznikol. Dáta už existujú:
  `expand` skladá pri každom riadku pole `sources` (`cabinet_id`, `owner_part_key`, `generic_type`, `rule_id`, `set_id`, počet) — chýba len zobrazenie a klik-select. Návrh: rozklik riadku (vzor
  `<details>` v tabe Rozpočet) so zoznamom „CAB-003 · F2 · zásuvkové čelo — 2 ks" a klikom na výber v modeli (vzor KONTROLA tabu); ľudské názvy dielcov dodá `PartKeys.human_label` z D-92. *Stav:
  OTVORENÉ — návrh na dávku okolo okna Výroba; nízke riziko (čisté čítanie), stredný rozsah UI.*

## STABILITA

- **D-123 · Ghost bez zámku Z položí dolnú skrinku so soklom na dno skrinky, nie na nohy** (Michal 6.9., KLINIKA) — pri voľnej Z (bez zámku) ghost umiestni skrinku tak, že
  na cieľovú plochu sadne **dno korpusu** (Z = `floor_height`) a nohy/sokel idú pod podlahu; **so zamknutou Z umiestňuje správne**. Podozrenie: `ghost_tool.rb` počíta „spodok
  tela" pre `under_sides` ako `floor_height` (r. ~506–513) — pre voľnú Z má byť spodok **celej skrinky** (nohy, Z = 0). *Stav: OTVORENÉ — **BUG**, fix dávka s in-SU testom
  (blok GHOST je uzavretý, preto tu); overiť aj hornú skrinku a `between_sides`.*
- **D-99 · Premenovanie dielca akoby prepísalo názvy všetkých kópií** (Michal 9.8., práca na zákazke KLINIKA) — po premenovaní jedného dielca to na chvíľu vyzeralo, akoby rovnaký názov dostali
  **všetky jeho kópie**; po prepnutí okna (zmena aktívneho modelu a späť) bolo všetko v poriadku, takže **dáta boli celý čas správne** — išlo o zobrazenie. *Stav: OTVORENÉ pozorovanie — zatiaľ
  **nereprodukované**. Sleduje sa; ak sa zopakuje, treba si všimnúť, či boli kópie vytvorené Ctrl+C/V (spoločná definícia, dedup tik) a čo presne ukazoval panel oproti modelu.*
- **Redo po zlúčených transparentných operáciách** — z hardening zoznamu uzáveru V0.5: manuálne overiť redo (Ctrl+Y) po zlúčených transparentných operáciách (pozorovanie zo 17.7.). *Stav: otvorené od 17.7. — Ruby API nemá na Windows spoľahlivú redo akciu, overuje sa rukou.*

- **D-117 · Nestabilný in-SU test „GHOST suspend: aktívny nástroj po upratovaní"** (orchestrátor 6.9., beh nad KOV-D4 hlavou f611bcb) — raz zlyhal s aktívnym `MeasureTool`
  (id 21024) namiesto `SelectionTool`, opakovaný beh nad tou istou hlavou prešiel (1927 PASS); dávka sa nástrojov nedotýkala a ten istý test prešiel v ~12 behoch toho dňa. Príčina
  = asercia predpokladá `SelectionTool`, ale `GhostTool.start` používa `push_tool`, takže po upratovaní sa vráti NÁSTROJ AKTÍVNY PRED scenárom (`ghost_tool.rb` ~r. 122) — keď beh
  štartuje s Tape Measure, `SelectionTool` sa neobjaví nikdy (poll by len časoval). *Stav: OTVORENÉ — návrh (Codex #318): v setupe sekcie si zapamätať aktívny nástroj a tvrdiť návrat
  PRÁVE NEHO, alebo pred štartom explicitne zvoliť Výber (`select_tool(nil)`); pri opakovaní hlásiť ID nástroja navrchu.*

## V1 DOTIAHNUTIE

- **D-124 · Predvoľby projektu v Materiáloch — rozbalené, väčšie náhľady** (Michal 6.9., KLINIKA) — Štúdio → Katalógy → Materiály → Predvoľby projektu sú v defaulte
  **zbalené**, pritom sa používajú často. Predstava: **väčšie náhľadové štvorce s detailmi pod sebou, zoradené v jednom riadku, default rozbalený stav**. Podotázka: **predvolený
  materiál per rola dielca** (police, dno, chrbát…) — uskutočniteľné (poradie override dielca > predvoľba roly > materiál skrinky), ale stredná dávka (builder, BOM, VEPO, šablóny)
  a dnes to kryje override dielca + šablóna → **mimo V1** (Michal). *Stav: OTVORENÉ — V1 len UI rework predvolieb (malá dávka); per-rola materiál v zásobníku Po V1.*
- **Vedome odložené z dávky E — ceny (V1 rozsah)** (6.8., nič z toho neblokuje prácu so zákazkou) — **manuálne 1-klik overenie ceny** pre položky BEZ väzby na Demos a **viac URL na položke**
  (zvyšok V1-03; dnes ich „Prepočítať ceny" preskočí) · ~~prepínač „na faktúru" (×1,2)~~ — **vyradené 6.9.2026** (Michal: existuje prepínač s DPH / bez DPH); zvyšok rozhodnutý v `zdroje/next_sessions/V1_DEBATA_2026-09-06_VYSTUPY.md`.
  *(Piaty kus tej istej odkladovej sady — EN DANIELI textový export — je v skupine KONTROLA + VÝROBA; DOCX/PDF generátor a rodina dokumentov sú od 26.8. v skupine Po V1 — zásobník.)*
  *Stav: čaká na prax — vytiahne sa, keď si to reálna zákazka vypýta.*

## RENDER M-R

- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — *Stav: **ZLÚČENÉ do dávky M-R** (roadmapa „Materiály — dokončenie", 2.8.): texture_path + render vlastnosti + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 orientácia podľa smeru dekoru. Zaradenie: blok 5 M-R v PLAN.md (fotku rieši package M-R FOTO; knižnica vzhľadov/PBR/orientácia = odrážka D-28 bloku 5) (Luciina priorita).*

## INFRA

  *Stav: na návrhovú dávku — od 26.8. SAMOSTATNE (bez väzby na D-48, ktorý je mimo V1); distribučný kanál jednoducho, napr. zdieľaný priečinok.*
## Po V1 — zásobník

- **D-95 · Režim krížovej kontroly „diel po diele"** (Michal 9.8.) — pred odoslaním zákazky do výroby chýba **riadený prechod celou zákazkou**: dielec po dielci prejsť rozmery, ABS a kovanie a
  **odškrtávať** skontrolované (so stavom, ktorý prežije zatvorenie okna). Dnes sa kontroluje preklikávaním po jednom v paneli, bez akejkoľvek stopy, čo už bolo overené. Michalov cieľ je konkrétny:
  **KLINIKA ako prvý referenčný projekt vyrobený čisto z pluginu** s jasným, obhájiteľným výstupom. Návrh: nový režim v okne Výroba (vedľa KONTROLY) — zoznam dielcov s checkboxom, klik = výber v modeli,
filtre „neskontrolované / s upozornením", stav uložený v `NOXUN` dict na modeli (patrí k zákazke, nie k počítaču); semafor ostáva samostatný (automatické nálezy) — toto je **ľudská** kontrola. *Stav: **MIMO V1 (Michal 6.9.2026)** — odškrtávanie diel po diele ide **preč natrvalo**; ostáva vizuálna kontrola (ABS · smer kresby · smer otvárania · tagy D-27),
  neskôr presety a X-ray pohľady (koncept `zdroje/next_sessions/01_D95_PLOSNA_VYROBNA_KONTROLA.md`).*
- **EN DANIELI textový export** výrobného zadania (Michal: „po E") — **vedome odložené z dávky E** (6.8., nič z toho neblokuje prácu so zákazkou); supplier-agnostický výstup. *Stav: **MIMO V1 (Michal 6.9.2026)** — zásobník.*
- **D-106 · Predbežná cena korpusu v informačnom stĺpci Základných** (Michal 20.8., smoke test Inspector reworku) — pri návrhu skrinky chýba **orientačný náklad**: koľko tá skrinka zhruba stojí ešte
  predtým, než sa robí rozpočet celej zákazky. Údaj by stál v **informačnom stĺpci sektora Základné** (vedľa „Materiál m²", teda **žiadny nový riadok navyše**) ako text **„≈ X €"** so značkou odhadu a s
  **tooltipom rozpadu** (materiál: plocha × cena tabule · ABS: bm × cena · kovanie: ks × cena). Dáta existujú — je to tá istá cesta, ktorou počíta tab Rozpočet (`budget`, `sheet_estimate`,
  `hardware_catalog` ceny); ide o **odvodené čítanie**, nič sa nezapisuje. Pravidlá, ktoré platia: chýbajúca cena **nikdy nula**, ale priznaný odhad (D-61); je to **výstup, nie vstup** (text, nie pole).
  *Stav: **MIMO V1 (Michal 6.9.2026)** — zásobník.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: **MIMO V1 (Michal 6.9.2026)** — zásobník.*
- **D-48 · Zdieľaná knižnica pre 2 PC (Michal + Lucia)** (Michal 31.7. večer; **od 26.8. MIMO V1**) — obe pracoviská majú zobrazovať ROVNAKÉ šablóny aj materiály (spolupráca, posúvanie projektov).
  Jednotný zdroj = **firemný Google Disk** (sú tam všetky firemné veci). Dotýka sa: katalóg materiálov, šablóny korpusov, pravidlá kovania (dnes všetko v lokálnom %APPDATA%).
*Stav: po V1 — **rozhodnuté 6.9.2026: PRVÁ funkcia po uzávere V1** v tvare Odoslať / Aktualizovať naraz pre všetky katalógy (aj nastavenia rozpočtu a dodávateľa, prílohy
spotrebičov, náhľady šablón), verzie per katalóg, konflikt ručne (výber verzie), štart len oznámi, koreň `H:\Môj disk\NoxunENGINE data`; odhad 3 PR — checkpoint
`zdroje/next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md`. Dovtedy export/import ručne.*
- **DOCX/PDF generátor cenovej ponuky + rodina dokumentov** *(od 26.8. MIMO V1 — vyčlenené z odkladov dávky E)* — plný generátor ponuky do DOCX/PDF so šablónou a vizualizáciami (dnes XLSX) ·
  rodina dokumentov okolo ponuky (ponuka 3D vizualizácií, preberací protokol). *Predpoklad: neutrálny model ponuky (XLSX/DOCX/PDF ako renderery tých istých dát — audit kolo 0, P2).*
- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** (Michal 20.8., smoke test) — náhľad šablóny je dnes **kontextová fotografia** aktuálneho pohľadu dorámovaná na skrinku (UI-D2), takže do nej
  môže zasahovať okolitá geometria. Želanie: pred capture **dočasne skryť zvyšok modelu** a odfotiť skrinku samú. Prečo to nie je „malá zmena": skrývanie/odkrývanie geometrie je **zápis do modelu**
  (viditeľnosť entít, tagy), teda undo kroky, observery a riziko, že po zlyhaní ostane model rozbitý — presne tomu sa UI-D2 vedome vyhla. *Stav: OTVORENÉ, **nízka priorita / vysoká náročnosť** (Michal
  20.8.). Zaradenie: [PLAN.md](PLAN.md) → „Po V1 — zásobník". Medzitým platí náhrada: **ručné „Odfotiť" v okne Šablóny** (SMOKE PACK 1) — Michal si skrinku naaranžuje a izoluje sám a odfotí ju, kedy
  chce.*
