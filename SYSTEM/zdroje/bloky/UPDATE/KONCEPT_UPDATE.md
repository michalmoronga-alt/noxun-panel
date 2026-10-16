# Blok UPDATE — koncept (D-48 zdieľaná knižnica pre 2 PC)

> **Stav:** KONCEPT na rešerš a krížový audit bloku (17.10.2026) — nie zadanie dávky. Technické požiadavky (vzorce, kontrakt, tvar súborov)
> patria **výhradne do packages** s ich auditom návrhu (CLAUDE.md, Štart bloku). Rozhodnutia: [ROZHODNUTIA_MICHALA_2026-10-17.md](ROZHODNUTIA_MICHALA_2026-10-17.md).
> **Implementácia až po smoke PASS bloku 9 HARDENING.**

## 1 · Čo blok prinesie používateľovi

Michal a Lucia uvidia **rovnaké knižnice**: materiály a ABS, kovanie (katalóg, výrobcovia a rady, sety, pravidlá), šablóny s náhľadmi,
nastavenia dodávateľa, spotrebiče s technickými listami, vzhľady materiálov a fotky dekorov. Zákazka otvorená na druhom PC ukáže aj
**svoj názov** (uložený v .skp, nie v pamäti jedného PC).

**Príklad dňa:** Michal ráno doplní do katalógu nový dekor a set závesov Blum → v Štúdiu → O plugine klikne **Odoslať**. Lucia pri štarte
SketchUpu dostane krátke oznámenie „Na Disku sú novšie knižnice: Materiály, Kovanie — otvoriť O plugine". Klikne **Aktualizovať** a má
dekor aj set. Ak si medzitým u seba doplnila vlastný materiál, okno jej povie „V Materiáloch máš vlastné zmeny — prevzatím sa prepíšu":
buď prepíše (jej verzia ostane ako záloha), alebo Materiály zatiaľ preskočí a povie Michalovi, čo má doplniť. Keď Michal odošle
pokazený katalóg, v O plugine ho **vráti na verziu spred dvoch dní** — návrat ide na Disk ako nová verzia a Lucia ho dostane bežným Aktualizovať.

## 2 · Toky (funkčne)

| Tok | Kto | Čo sa stane |
|---|---|---|
| **Prvé odoslanie** | Michal (správca) | každý zdieľaný katalóg sa uloží na Disk ako verzia 1; Michalova knižnica je od toho dňa vzor |
| **Prvé pripojenie** | Lucia | plugin porovná jej knižnice s Diskom: rovnaké → len si zapamätá verziu; iné → varovanie R4 (prepísať so zálohou / preskočiť) — nikdy nič potichu |
| **Odoslať** | len správca | naraz všetky katalógy so zmenou; nezmenené sa neodosielajú; riadok per katalóg ukáže výsledok |
| **Aktualizovať** | každé PC | naraz všetky katalógy, kde je na Disku novšia verzia; katalóg s lokálnymi zmenami → varovanie R4 |
| **Štart SketchUpu** | každé PC | len porovná a oznámi; ak Disk neodpovie včas, nič nezamrzne (oznámi „Disk nedostupný") |
| **História a návrat** | správca | posledných 5 odoslaní per katalóg; „Vrátiť na verziu z …" = nové odoslanie so starším obsahom |
| **Novší plugin na Disku** | každé PC | knižnicu z novšieho pluginu staršie PC **neprevezme** a pošle na aktualizáciu pluginu (D-52, ten istý koreň) |
| **Disk nedostupný** | každé PC | práca beží ďalej z lokálnych knižníc; Odoslať/Aktualizovať hlási „Disk nedostupný" |

**Čo blok vedome NErobí:** zlučovanie po záznamoch (verzia = celý katalóg) · odosielanie z Luciinho PC · automatické sťahovanie ·
zdieľanie rozmerových radov, „18 + 36", témy a prepínačov · offline front zmien · zdieľanie zákaziek (.skp si posielate ako dnes).

## 3 · Čo sa zjednodušuje oproti návrhu zo 6.9.

Návrh [SYNC_KNIZNICE_NAVRH_2026-09-06.md](../../next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md) riešil **dvoch zapisovateľov** na Disku bez
zámku (lineage cez `parent`, `supersedes`, konfliktné okno, kolízie dvoch PC). S jedným správcom (R3) **odpadá**: konfliktné okno dvoch
odoslaní, detekcia kolízie medzi PC, rekonštrukcia manifestu z konkurenčných vetiev. **Ostáva** (aj s jedným správcom platí):

- Disk doručuje súbory mimo poradia → Lucia smie prevziať verziu až keď je **celá** (manifest, artefakt aj všetky prílohy s overeným obsahom);
- dve okná SketchUpu u Michala → dve súbežné odoslania z jedného PC (nemenné artefakty s jedinečným menom, ukazovateľ zapísaný posledný);
- JSON katalógu + jeho prílohy (náhľady, listy, `.skm`, fotky) sa prevezmú **ako jeden celok** alebo vôbec;
- lokálne zmeny sa zisťujú voči poslednej prevzatej/odoslanej verzii a overia sa znova pod zámkom katalógu tesne pred prepísaním;
- **dopredná brána** (novší `std` z novšieho pluginu → odmietnutie pred zápisom) v sync vrstve, nie v store-och;
- ochrana „seed vedome zmazaný" (značky UNI, kniznice.md F5) pri prevzatí;
- čítania Disku s časovým limitom bez visiacich vlákien (vzor updatera).

**Ako sa určí správca** — návrh na mockup (potvrdí Michal): na Disku leží súbor „správca" s menom PC; Odoslať je povolené len PC,
ktoré v ňom je. Odovzdanie správcu (napr. výmena PC) = výslovná akcia v O plugine s potvrdením. Bez súboru = prvý, kto odošle, sa stáva správcom.

## 4 · Predbežný rez dávok (potvrdí sa po audite bloku)

| Dávka | Obsah (funkčne) | Trieda / brány |
|---|---|---|
| **U1 · Názov zákazky v .skp** | názov zákazky sa ukladá do modelu; starý záznam podľa cesty sa pri otvorení prevezme; exporty a hlavička Štúdia čítajú model | Ť — zmena dát modelu → `codex-audit`, predrecenzia; export test |
| **U2 · Register vynútený** | každé úložisko zapisuje len cez register (SYNC-0); háčiky posúdenia importu a doprednej brány; bez zmeny správania | Ť — kontrakt perzistencie → `codex-audit` |
| **U3 · Jadro synchronizácie** | čistý modul: odoslanie, prevzatie, celistvosť verzie, história 5 + návrat, lokálne zmeny, správca, časové limity; headless testy s mutáciami | Ť — nový modul + zápis do všetkých knižníc → `codex-audit` |
| **U4 · Prílohy a fotky** | náhľady šablón, listy spotrebičov, vzhľady `.skm`, fotky dekorov ako súčasť verzie katalógu; migrácia existujúcich | Ť — migrácia → `codex-audit` |
| **U5 · Okno O plugine** | riadky per katalóg, Odoslať / Aktualizovať, varovanie R4, história a návrat, oznámenie pri štarte, správca | S/Ť — nové ovládacie prvky → predrecenzia; in-SU + smoke na oboch PC |

Odhad: 5 PR (oproti 3 zo 6.9. — pribudol názov zákazky a fotky dekorov; jadro je menšie vďaka jednému správcovi).

## 5 · Otázky pre rešerš a krížový audit bloku

1. Je model „jeden správca + nemenné verzie + ukazovateľ" na zrkadlenom Google Disku bezpečný? Čo presne Google Drive for desktop robí pri
   súbore prepísanom kým sa sťahuje, pri premenovaní (temp + rename), pri konfliktnej kópii a v režime offline? (oficiálne zdroje)
2. Existuje jednoduchšia natívna cesta (SketchUp, Windows, Google Drive API, iný CAD/nábytkársky softvér pri zdieľaných knižniciach dvoch pracovísk)?
3. Rez dávok: dá sa U2 zlúčiť s U3? Patrí U1 (názov v .skp) do tohto bloku, alebo je samostatná?
4. Riziká pre výrobu: môže prevzatie knižnice zmeniť čísla existujúcej zákazky (snapshoty na skrinkách, projektové materiály, rozpočet)?
5. Čo sa stane pri zlyhaní uprostred prevzatia, pri dvoch oknách SketchUpu u Lucie, pri odpojení Disku počas odoslania?
6. Fotky dekorov (`textures/`) sú dnes cache — dá sa z nich bezpečne urobiť zdieľanú prílohu, alebo ich radšej dotiahnuť pri zobrazení?
