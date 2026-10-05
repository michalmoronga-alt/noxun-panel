# Krížový audit V1 — rozhodnutia Michala (30.9.–1.10.2026)

> Priečinok bloku `HARDENING` (štart = krížový audit V1) — autorita počas bloku. Podklad pre audítorov: [PODKLAD_KRIZOVY_AUDIT.md](PODKLAD_KRIZOVY_AUDIT.md).

## Zadanie (Michal 30.9.2026)

Ako posledný krok V1 spraviť **krížový audit všetkými providermi** s tromi cieľmi:

1. nájsť súbory a dokumenty, ktoré potrebujú **refaktor alebo upratanie** — hlavne s ohľadom na ďalšie rozširovanie po V1,
2. pozrieť sa na plugin **ako celok** a doplniť **nápady po V1**,
3. nájsť **UI/UX drobnosti a doplnky** na spríjemnenie, sprofesionalizovanie prostredia alebo zjednodušenie práce.

Výsledky si Michal prejde a spolu roztriedime: **teraz** · **zásobník** · **vyradiť**.

## Rozhodnutia

| # | Otázka | Rozhodnutie |
|---|---|---|
| V1A-1 | Rozsah | **Matica rolí** (každá os má 2 hlavné hlasy, ostatní krátky príspevok) — nie „všetci všetko". **Antigravity vyradený** z tohto auditu; jeho rolu (konkurencia, UX vzory) preberá Claude rešeršér. |
| V1A-2 | Screenshoty pre UI audit | **Robí orchestrátor** v neuloženom okne s ukážkovou kuchyňou (7 skriniek zo šablón). |
| V1A-3 | Čo znamená „teraz" | **Nechané na orchestrátora.** Michal: máme pár dní s plánom MAX a jeden reset pre Claude aj Codex — **rozumne ich minúť na hardening pred pokračovaním na funkciách**; vypísané súbory sú „dosť extrém". → definícia bloku HARDENING nižšie. |
| V1A-4 | Kvóty | Vystačia (všade plán MAX 5×, 20 % stačí aj na veľký blok); Michal sleduje spotrebu a v prípade potreby dá reset. |

## Definícia „teraz" = blok HARDENING (orchestrátor na základe V1A-3)

Blok **pred funkciami po V1**, na pár dní s jedným resetom. Obsahuje:

- **R-13 → R-37 → R-35** (už rozhodnuté 30.9. ako prvé po V1 — [../../../PLAN.md](../../../PLAN.md), „Po V1 — zásobník"),
- **vybrané položky tohto auditu**, ktoré spĺňajú všetky štyri podmienky:
  1. zmenšujú riziko alebo cenu budúcich zmien v niektorom **scenári rozšírenia** (S1–S6 v podklade),
  2. **nemenia výrobné ani cenové čísla** — preukázateľne (charakterizačné/golden testy PRED zásahom: VEPO bajtovo, kusovník, rozpočet),
  3. dajú sa narezať na dávky po ~1 dni,
  4. pri UI: len drobnosti, ktoré nič nepočítajú a nemenia dáta.

Všetko ostatné ide do **zásobníka Po V1** alebo sa **vyradí** s dôvodom. Poradie a konečný výber robí Michal pri triedení.

## Postup

0. Podklad + balíček screenshotov (orchestrátor) → 1. beh 7 audítorov paralelne → 2. spojenie (reconcile, dedup, sondy pri „už existuje / jednoduchšia natívna cesta")
→ 3. triedenie Michalom (interaktívna stránka: Teraz / Po V1 / Vyradiť + poznámka) → 4. zápis do PLAN, zásobníka a archívu → štart bloku HARDENING.

## Výsledok triedenia (Michal 1.10.2026, interaktívna stránka)

Autorita pre zaradenie položiek. Plné znenia a dôkazy: [TRIEDENIE_krizovy_audit_v1.html](TRIEDENIE_krizovy_audit_v1.html) (stránka s popisom každej položky) a surové výstupy audítorov `CROSS_AUDIT_A*.md` v tomto priečinku (zdrojové ID v stĺpci Zdroj).
Stránka je záznam toho, čo Michal videl pri triedení, a nemení sa. **Pozn. k B-01:** veta „Užitočné sú z toho 3–4 %" je neoverený odhad (poznámka v hlavičke
`CROSS_AUDIT_A4`); zmerané sú len veľkosti povinného čítania.

**Spolu:** 35 Teraz · 29 Po V1 · 11 Vyradiť (75 položiek). **Odchýlky od odporúčania orchestrátora:** B-10 Teraz → **Po V1** · D-03 Teraz → **Po V1** · D-11 Po V1 → **Teraz** · E-02 Po V1 → **Vyradiť** · E-04 Po V1 → **Vyradiť** · E-06 Po V1 → **Vyradiť** · E-09 Po V1 → **Vyradiť** · G-01 Teraz → **Po V1** · G-03 Po V1 → **Vyradiť** · G-09 Po V1 → **Vyradiť** · G-10 Po V1 → **Vyradiť**.

**Dôvody odchýlok a vyradení (doplnok po review PR #432):** Michal pri triedení k odchýlkam ani k vyradeniu E-02, E-04, E-06, E-09, G-03, G-09, G-10
poznámku neuviedol (stĺpec prázdny) — **okrem G-01** („mám prístup ku konfigurátoru Blum" → vzorky pri prvom novom zásuvkovom systéme, odpovede nižšie) —
dôvodom je **jeho rozhodnutie pri triedení 1.10.2026**; orchestrátor dôvody nedomýšľa. **Vyradené** znamená
„v pláne sa nerieši", nie trvalý zákaz: položka sa vráti len novým postrehom Michala (DOGFOODING). G-11 a G-12 Michal výslovne potvrdil „nerieši sa"
(odpovede nižšie). Pôvodné zdôvodnenie každej položky (čo a prečo) ostáva na triediacej stránke a v surových výstupoch.

### TERAZ — blok HARDENING (35)

| ID | Oblasť | Položka | Zdroj | Poznámka Michala |
|---|---|---|---|---|
| A-01 | Zavádzajúce údaje v okne | Kusovník sčítava platne rôznych materiálov | CU-05 · overené v kóde |  |
| A-02 | Zavádzajúce údaje v okne | Cenová ponuka: stĺpec „Cena“ sa číta ako cena za kus | CU-08 |  |
| A-03 | Zavádzajúce údaje v okne | Kontrola: zelená „0 skriniek bez nálezu“ a nepravdivá veta | CU-09 · GR-19 |  |
| A-04 | Zavádzajúce údaje v okne | Nákup kovania hovorí jazykom databázy | CU-01 · overené v kóde |  |
| A-05 | Zavádzajúce údaje v okne | Názov zákazky je schovaný v Kusovníku | CU-07 · GR-20 |  |
| A-06 | Zavádzajúce údaje v okne | Chyba v logu po otvorení nového súboru | orchestrátor (sonda 1.10.) |  |
| A-07 | Zavádzajúce údaje v okne | Nastavenia rozpočtu neukazujú platnú sadzbu | CU-15 |  |
| B-01 | Dokumenty a pravidlá | Povinné čítanie po kapitolách, nie celé obrie súbory | CN-01 · CS-02 · CN-07 · CN-12 |  |
| B-02 | Dokumenty a pravidlá | Dokumentácia okien (529 kB): aktuálny stav oddeliť od histórie | CS-01 · CS-07 · CN-08 |  |
| B-03 | Dokumenty a pravidlá | Strážca, aby dokumenty znova nenapuchli | CS-04 |  |
| B-04 | Dokumenty a pravidlá | PLAN.md: 86 % tvoria hotové bloky | CN-06 · CN-10 |  |
| B-05 | Dokumenty a pravidlá | UI_DIZAJN a architektúra: zastarané a protirečivé vety | CS-06 · CN-09 |  |
| B-06 | Dokumenty a pravidlá | Mapa „kde sa plugin rozširuje“ + skrytá pasca závesov | CN-02 · CN-03 |  |
| B-07 | Dokumenty a pravidlá | Jedna tabuľka verzií dát | CN-04 |  |
| B-08 | Dokumenty a pravidlá | STAV.md zastará po každom dokumentačnom PR | CN-05 |  |
| B-09 | Dokumenty a pravidlá | Hranica „výrobná dávka“ a „nový ovládač“ s príkladmi | CN-11 |  |
| C-01 | Kód | Typy skriniek na jednom mieste | CX-01 · GR-01 · CN-02 |  |
| C-02 | Kód | Sekcie Štúdia na jednom mieste | CX-04 · CX-05 · GR-06 |  |
| C-03 | Kód | Dáta kovania von z 6 600-riadkového súboru | CX-03 · GR-07 |  |
| C-04 | Kód | Súpis knižníc pred zdieľaním medzi PC | GR-03 · CX (k D-48) |  |
| C-05 | Kód | Slovenské mená rolí dielcov v jednej tabuľke | GR-04 |  |
| C-06 | Kód | Spoločná príprava štyroch exportov | CX (k R-15) · GR (k R-15) |  |
| C-07 | Kód | Nastavenia exportu (názvy zákaziek) do jadra | GR (k R-38) |  |
| D-01 | UI drobnosti | Inspector: uvoľniť ~200 px výšky | CU-04 · CU-11 · GR-22 · CS-10 |  |
| D-02 | UI drobnosti | Čitateľné kóty v náhľade | CU-02 |  |
| D-04 | UI drobnosti | Jednotný zápis čísel a jednotiek | CU-06 · R-24 |  |
| D-05 | UI drobnosti | Zbalená sekcia povie, čo skrýva | CU-10 |  |
| D-06 | UI drobnosti | „Obnoviť zálohu“ hneď vedľa „Obnoviť“ | CU-12 |  |
| D-07 | UI drobnosti | Texty bez vývojárskeho žargónu a VEĽKÝCH písmen | CU-13 |  |
| D-08 | UI drobnosti | Rozbaľovačky, hľadanie a stĺpce Kusovníka | CU-14 · CS-09 · CS-11 |  |
| D-09 | UI drobnosti | Rozpočet a Nastavenia rozpočtu majú rovnakú ikonu | GR-23 |  |
| D-10 | UI drobnosti | Automatické fotenie okien po zmene UI | orchestrátor |  |
| D-11 | UI drobnosti | ABS „0,8 dookola“ namiesto štyroch hrán | GR-21 |  |
| F-01 | SketchUp | Pripraviť plugin na SketchUp 2026.2 (pád pri zatváraní) | RA-02 |  |
| F-02 | SketchUp | Minimálna verzia SketchUp 2026 a upratanie starých poistiek | RA-05 |  |

### PO V1 — zásobník (29)

| ID | Oblasť | Položka | Zdroj | Poznámka Michala |
|---|---|---|---|---|
| B-10 | Dokumenty a pravidlá | Strážca zhody modelov agentov | CS-05 |  |
| B-11 | Dokumenty a pravidlá | Workflow pravidlá na jednom mieste, kratší CLAUDE.md | CS-03 · CN-14 |  |
| B-12 | Dokumenty a pravidlá | Skill Codex auditu bez rýchlo starnúcich faktov | CS-08 |  |
| B-13 | Dokumenty a pravidlá | Testy v SketchUpe: jeden súbor s 1,5 MB | CN-13 |  |
| C-08 | Kód | Zásuvky: výška podľa receptu, nie podľa mena „Atira“ | GR-02 · CX-02 |  |
| D-03 | UI drobnosti | Klávesové skratky cez menu | CU-03 |  |
| E-01 | Nápady | Snímka odovzdanej zákazky a „čo sa zmenilo od objednávky“ | CX-06 · GR-12 · CU-16 · RT-01 (Cabinet Vision: sledovanie revízií) |  |
| E-03 | Nápady | Rad skriniek naraz a vloženie vedľa suseda | GR-08 · GR-09 |  |
| E-05 | Nápady | Názov skrinky v Kusovníku | GR-11 |  |
| E-07 | Nápady | Hmotnosť a logistický súhrn zákazky | GR-14 · RT-15 |  |
| E-08 | Nápady | Kusovník v poradí po stene | GR-15 |  |
| E-10 | Nápady | Z dielca skok na platňu | GR-17 |  |
| E-11 | Nápady | Zoznam rozpracovaných zákaziek na PC | GR-18 |  |
| E-12 | Nápady | Zákaznícky názov položky v ponuke | CU-18 |  |
| E-13 | Nápady | Odhad hodín dielne | CU-20 · RT-07 (Cabinet Vision: práca na dielec) |  |
| F-03 | SketchUp | Štyri prekrytia v modeli majú štyri kópie toho istého kódu | RA-01 |  |
| F-04 | SketchUp | Náhľad šablóny bez skrývania modelu | A7 k D-107 |  |
| F-05 | SketchUp | Okná Štúdia a Inspectora skryť namiesto zatvorenia | RA-04 |  |
| F-06 | SketchUp | Hláška pri zamietnutej zmene mierky skrinky | RA-08 |  |
| F-07 | SketchUp | Poistka, keď SketchUp prestane hlásiť zmenu výberu | RA-07 |  |
| F-08 | SketchUp | Výkresy cez LayOut | RA-10 |  |
| F-09 | SketchUp | Drobnosti API (kvádre, viditeľnosť, časovač) | RA-03 · RA-06 · RA-09 |  |
| G-01 | Z trhu | Porovnať recepty zásuviek s tabuľkami výrobcu | RT-05 (Blum konfigurátor, katalóg Hettich Atira) | mam pristup k blum konfiguratoru |
| G-02 | Z trhu | Karta zákazky: klient, číslo ponuky, platnosť, stav | RT-04 (Mozaik, Cabinet Vision) |  |
| G-04 | Z trhu | Prehľad skriniek ako štvrtý pohľad Kusovníka | RT-06 (OpenCutList Outliner) · GR-11 |  |
| G-05 | Z trhu | Exportovať všetko do jedného datovaného priečinka | RT-13 (Cabinet Vision) |  |
| G-06 | Z trhu | Poznámka ku skrinke vo výstupoch | RT-12 (Mozaik) |  |
| G-07 | Z trhu | Pravý klik na skrinku v modeli | RT-14 |  |
| G-08 | Z trhu | Štetec dekoru | RT-11 (OpenCutList Smart Paint) |  |

### VYRADENÉ (11)

| ID | Oblasť | Položka | Zdroj | Poznámka Michala |
|---|---|---|---|---|
| C-09 | Kód | Stĺpce Kusovníka ako jedna špecifikácia | GR-05 vs CX |  |
| E-02 | Nápady | „Čo keby“ variant ceny pre zákazníka | CU-17 · RT-03 (Mozaik „What If“, Cabinet Vision) |  |
| E-04 | Nápady | Zrkadlová ľavá/pravá skrinka | GR-10 |  |
| E-06 | Nápady | Kontrola susedných skriniek v rade | GR-13 |  |
| E-09 | Nápady | Sklad zvyškov platní | GR-16 · CU-19 |  |
| F-10 | SketchUp | Natívne prisúvanie (Snap) a kópia materiálu | RA-11 · RA-12 |  |
| G-03 | Z trhu | Export po častiach (etapy objednávky) | RT-02 (Mozaik) |  |
| G-09 | Z trhu | Obrázky pre zákazníka jedným klikom | RT-08 (Mozaik, SketchList) |  |
| G-10 | Z trhu | „Vyplniť úsek steny“ | A6 k zostavám (ArchiWood, Cabinet Vision) |  |
| G-11 | Z trhu | Ponuka do Pohody (XML) | RT-09 |  |
| G-12 | Z trhu | Nákup kovania rovno do košíka Démos24Plus | RT-10 |  |

### Odpovede na otázky zo stránky (1.10.2026)

- **B-08** (dokumentačné PR smie prepísať „Robí sa" a „Ďalší krok" v STAV) a **B-09** (hranice triedy dávky s príkladmi) — **súhlas**, zapracuje dávka bloku HARDENING.
- **G-01** — Po V1; Michal **má prístup ku konfigurátoru Blum** (vzorky zásuviek sa urobia pri prvom novom zásuvkovom systéme, napr. Antaro).
- **G-11** (Pohoda) a **G-12** (import košíka Démos24Plus) — vyradené, nerieši sa.
- **F-02** (minimum SketchUp 2026) — Michal 1.10.: **Lucia má rovnakú verziu SketchUp 2026** (jedna licencia na oboch PC) → minimum 2026 platí.

## Plán bloku (Michal 1.10.2026 — súhlas s návrhom orchestrátora)

- **17 dávok H1–H17** v poradí tabuľky bloku 9 v [../../../PLAN.md](../../../PLAN.md); R-13, R-37 a R-35 sú v bloku ako H8–H10 (pred refaktormi kódu, lebo chránia
  dáta reálnych zákaziek).
- **Bez viazania na noci:** každý beh spracuje sekvenčne, koľko stihne, a pokračuje ďalší (Michal: „nefixovať na časové obdobie").
- **Mockup schvaľuje Michal** pred packages dávok H6 (priestor v Inspectore) a H7 (názov zákazky); mockupy sa pripravia počas H1–H5.
- **H7 doplnená o R-38** (orchestrátor po review PR #432): presun nastavení exportu do jadra (C-07) ide až s ochranou poškodeného súboru nastavení
  pred tichým prepisom zo zálohy — inak by presun zachoval cestu k strate názvov zákaziek. Michal to potvrdí spolu s mockupom H7.

## Mockupy H6 a H7 — odpovede Michala (2.10.2026 ~02:15, chat)

**H6 · priestor v Inspectore (`MOCKUP_H6_INSPECTOR.html`, O1–O13) — platí:**

| Bod | Odpoveď | Čo to znamená |
|---|---|---|
| O1 | **odchýlka od návrhu** | „Vložiť kópiu" a „Uložiť šablónu" **ostávajú na dnešnom mieste dole**, ale **vedľa seba v jednom riadku** (dve tlačidlá). Text „Uložiť ako šablónu do knižnice" sa **skráti na „Uložiť šablónu"**. Žiadne ikony v hlavičke. |
| O2 | **A** | Stavová veta ostáva na konci panela, ukáže sa len vtedy, keď nesie správu („Pripravené." zmizne). Žiadny pás pri spodku okna. |
| O3 | **B** | Pätka s verziou („Noxun Engine V…") **ostáva**. |
| O4 | A | Nadpis „Rozmery" pri označenej skrinke preč; pri vkladaní ostáva. |
| O5 | A | Jeden „?" v spodnom páse náhľadu + „?" v hlavičkách skupín; stavové vety ostávajú viditeľné. |
| O6 | A | Rozmery skrinky do lišty sektora Náhľad v Zónach/Čelách/Kovaní („800 × 864 × 520 · sokel 100 →"), klik = Korpus, bublina s materiálom; pás „…upravíš v Korpuse" preč. |
| O7 | A | „F206 ST9 · medzera 3 · okraje 2 · dole −20". |
| O8 | A | Riadok „Zobraziť zóny (ghost) v modeli" preč; ostáva v raile pod okom. |
| O9 | A | Súhrn kovania do lišty sektora Kovanie, z kresby preč (kresba sa zväčší). |
| O10 | A | Kóty 11 px stále (medzery 10 px), aj pri zoome; prekreslenie kót po zoome. |
| O11 | A | Bez „mm" pri kótach všade. |
| O12 | A | Lišta sektora vždy súhrn obsahu (aj pri otvorenej skupine). |
| O13 | A | Stála nápoveda v Štúdiu → Pravidlá kovania (CS-10) do „?" v rámci H6. |

Dôsledok O1 B + O2 A + O3 B: spodný blok (tlačidlá v jednom riadku, správa len keď je, pätka) ostáva — úspora na kontext je menšia ako v mockupe (spodný blok namiesto ≈ 155 px uvoľní ≈ 40 + 39 px = rádovo ≈ 80 px). Ostatné úspory (O4–O9) platia.

**H7 · názov zákazky na jednom mieste (`MOCKUP_H7_NAZOV_ZAKAZKY.html`, O1–O9) — platí: všetko podľa odporúčania.**
O1 A (text s ceruzkou v hlavičke Štúdia, klik = pole na mieste) · O2 pole PROJEKT v lište Kusovníka zmizne · O3 jantárová bodka len pri „projekt" ·
O4 bodka + tooltip + jedna veta po exporte, neblokuje · O5 meno súboru sa pri otvorení neukladá · O6 „Uložiť ako"/Lucia → riešenie v G-02 po V1 ·
O7 tooltip s presným menom priečinka/súboru (skladá server) · O8 zlyhaný zápis názvu nahlásiť červeno, hlavička ostane na pôvodnom · O9 „projekt" → „zákazka" v textoch okna.
**R-38 v H7: áno** (odporúčanie zo zhrnutia 1.10. — „všetko podľa odporúčania"; ochrana súboru nastavení exportu pri poškodení, rozhodne package C-07).

**H7 Q2 (package H7 §13, nový stav po schválení mockupu) — POTVRDENÉ Michalom 2.10.2026 večer (nižšie):** stav hlavičky „neuložené k súboru" s jantárovou bodkou pri
čakajúcom názve (poškodený súbor nastavení pri prvom uložení zákazky) — **áno**, implementované v H7b; zapísané aj v mockupe H7 (rámček PLATÍ).

**Otázky zo zhrnutia 1.10. bez odpovede — platí predvolené (vratné, nemení výrobné čísla):**
Q1 H11a pri chybe súboru vypnúť celý plugin · Q2 SketchUp 2026.2 — H11c ostáva otvorené · Q3 H12d názvy v karte dielca podľa Kusovníka · Q4 H9 ABS/kovanie
bez zálohy — otvorené (bez zmeny) · Q5 „dolná" · Q11 H14 text nechať · Q12 H15 predvolené pravidlá kovania nepresúvať (zásobník Po V1).

### Odpovede 2.10.2026 večer (chat, prenesené orchestrátorom)

- **Q2 H7** (hlavička „neuložené k súboru" s jantárovou bodkou) — **potvrdené: áno** (H7b).
- **Porovnávacie exporty z reálnej zákazky** pošle Michal **pred H17**.
- **Závesy (3A):** nová dávka **H18** — Inspector (Sety) ukáže **skutočne použitý set závesov**; **výroba sa nemení** (zdroj: slepé recenzie PR #454).
- **Rozmerové rady (4A):** každý PC svoje. · **18 + 36 (5A):** každý PC svoje.
- **„Spodná / Dolná" (6A):** zásobník Po V1.
- **H11a (7A):** pri chybe súboru pluginu **vypnúť celý plugin**.
- **ABS a kovanie bez zálohy (8B):** len log → zásobník Po V1.
- **SketchUp 2026.2:** Michal ho nainštaluje na oboch PC a dá vedieť — **H11c čaká**.


### Odpoveď 5.10.2026 — H18b

Michal: **„H18B opraviť“**, **„pokračovať“** — výslovné schválenie Q2 opravy H18b-1 (D-150). Q1 A a Q3 A ostávajú; H18b-2 ani D-151/D-152 sa neimplementujú. Výrobná/cenová dávka, predrecenzia a in-SU ostávajú brány. Voľba implementačných subagentov 6.1 SOL platí pre toto sedenie; globálna tabuľka rolí sa nemení.
