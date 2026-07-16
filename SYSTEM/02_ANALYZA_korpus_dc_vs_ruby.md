# Analýza: Korpus cez DC engine vs. Ruby generovanie (v1.0, 15.7.2026)

> Kľúčové architektonické rozhodnutie nového systému — určí, ako sa budú korpusy a dielce tvoriť, meniť a čítať. Podklady: stovky hodín Michalovej praxe s DC, `STARE\_dev\DC_SCHEMA.md` (pitva Master komponentu), GPT audit (ročná história problémov), ArchiWood research, docs\DC_PRAVIDLA.md.

## Otázka

Keď nový systém vloží korpus a používateľ mu zmení rozmer/konfiguráciu — **kto prepočíta geometriu dielcov?**

- **A. DC engine** — dielce majú vzorce (`=Parent!hrubka`…), prepočet robí SketchUp pri redraw (dnešný stav).
- **B. Ruby** — dielce sú obyčajné komponenty bez vzorcov; všetku geometriu generuje a prepočítava náš plugin z konfigurácie uloženej v atribútoch.
- **C. Hybridy** — kombinácie A+B.

## Čo DC engine reálne dáva — a či to potrebujeme

| Čo DC poskytuje | Potrebujeme? |
|---|---|
| Editácia cez natívny panel Component Options (bez nášho pluginu) | ❌ Skrinky edituje len Michal (s pluginom); manželka číta výstupy. Nový panel to nahradí. |
| „Živý" komponent aj u cudzieho užívateľa (poslaný .skp) | ❌ Von idú výstupy (ponuka, výkresy), nie živé knižnice. |
| Prepočet vzorcov pri redraw | ✅ Potrebujeme prepočet — ale nemusí ho robiť DC engine. |
| Interact tool (klik-animácie dvierok) | ➖ Pekné na prezentáciu, nie jadro biznisu. Dá sa doplniť neskôr aj bez DC. |

## Možnosť A — plné DC (dnešný prístup)

**Prax po stovkách hodín — zdokumentované mantinely:**

1. **Pripájanie childov neexistuje.** Všetky varianty musia byť predmodelované vnútri a prepínané `Hidden` — presne dnešné skrinky (Horná HF, Master, Spotrebičová, Sufliková 2x). Kombinatorika rastie exponenciálne: každý nový variant šuflíka × dvierok × priečok = ďalšie vetvy vnorených IF.
2. **Tvorba nového typu = hodiny** klikania v DC editore; vzorce sa nedajú kopírovať systémovo, ladenie cez pokus-omyl.
3. **Krehkosť enginu:** tri jednotkové svety naraz (uložené palce / vzorce cm / zobrazenie mm); case-sensitivity; IF vyhodnocuje obe vetvy; `LenX=0` kolaps; zdieľané definície so zastaranými hodnotami (Master: dvere 3× tá istá definícia); zastarané `len*` vs. nominály (Master: `lenx`=771 pri reálnych 700).
4. **Redraw a zápis cez Ruby sú aj tak hacky** (`$dc_observers`, scale+redraw, make_unique) — to znamená: aj „čistá DC cesta" stojí na neoficiálnych trikoch, keď ju riadi plugin.
5. **„Inteligencia" (flagy kovania, pravidlá, výstupy) sa v DC vzorcoch vyjadruje mizerne** — DC nemá slučky, štruktúry, knižnice pravidiel; FORMULA jazyk je z roku 2008.
6. Závislosť na Pro DC editore a na tom, že Trimble DC nezmení/nezruší (12+ rokov bez vývoja — mŕtva technológia).

**Pre:** hotová dnešná knižnica; Component Options funguje bez pluginu; Melamina PRO ukazuje, že poriadna DC knižnica sa dá urobiť — ale pozor: Melamina je *statická* knižnica bez pripájania, kovaní a automatických výstupov — teda presne bez toho, čo od systému chceš.

## Možnosť B — Ruby generovanie (odporúčaná)

Korpus = **funkcia(konfigurácia) → geometria**. Konfigurácia (rozmery, hrúbky, konštrukčný typ, sokel, chrbát, obsadenie slotov) žije v `NOXUN` atribútoch (mm, JSON). Pri zmene plugin v jednej Undo operácii zmaže vnútro a **deterministicky postaví nanovo** (regenerate pattern) — žiadne kumulatívne chyby, žiadne vzorce.

**Pre:**
1. **Pripájanie childov je prirodzené** — slot je dátová štruktúra, vloženie childu = zápis do konfigurácie + rebuild. Presne ArchiWood model (ktorý DC tiež nepoužíva — rovnako ako GKWare CabMaker).
2. **Nový typ korpusu = nová šablóna** (JSON konfig + generovacia funkcia), nie hodiny v DC editore. Varianty (vložené/naložené dno…) sú `if` v kóde — píše ich agent, nie klikanie.
3. **Jeden jednotkový svet** — všetko mm, žiadne palce/cm preklady, žiadne case-sensitivity pasce.
4. **Inteligencia zadarmo:** pri rebuilde sa rovno prepočítajú flagy kovania (pravidlá z JSON), hrany, materiály — jednotný výstup je vedľajší produkt generovania, nie ďalší systém.
5. **OCL/VEPO čistota garantovaná** — dielce kladieme my: správne osi, origin, rozmery, materiál, meno. Žiadne „OCL zamenil šírku s hrúbkou".
6. **Testovateľné** — celá logika je Ruby: SkAgent slučka otestuje generovanie, rebuild aj výstupy automaticky. DC vzorce sa testujú len očami.
7. Undo = jedna operácia; žiadny `$dc_observers`.

**Proti / riziká (s mitigáciami):**
1. **Rebuild engine treba navrhnúť poriadne** (jednorazová investícia). Bloky existujú: EntitiesBuilder, V2fable placement/dc.rb, KOVANIE observers. → Referenčný korpus ako prvý míľnik to overí v malom.
2. **Bez pluginu je skrinka „mŕtva"** (statická geometria). → Akceptované: edituje len Michal. Pozn.: statický model je stále čitateľný, meratelný, renderovateľný — mŕtve sú len parametre.
3. **PersistentId dielcov sa rebuildom mení** → väzby (kovanie, markery) viazať na korpus + stabilné kľúče rolí dielcov v atribútoch (`NOXUN/role`), nie na konkrétne entity dielcov.
4. **Migrácia knižnice** — 43 .skp sa nedá prepnúť naraz. → viď migračná cesta nižšie.

## Možnosť C — hybridy

- **C1: DC kostra + Ruby childy** (pôvodný nápad): korpus zostáva DC, Ruby doň vkladá childy a nastavuje atribúty. ❌ Zlé z oboch svetov: zdedí všetku krehkosť DC (vzorce, jednotky, redraw) a Ruby stále musí robiť polovicu práce; kombinatorika Hidden vetiev zostáva.
- **C2: Ruby korpus + existujúce DC childy ako čierne skrinky** (migračný most): nový Ruby korpus, ale hotové DC moduly (šuflík Hettich Atira s vnútornými vzorcami) sa spočiatku vkladajú ako celok a škálujú cez overený scale+redraw pattern (STARE). ✅ Zmysluplné DOČASNE — šetrí prerábanie najzložitejších modulov v prvej fáze; postupne sa nahradia.

## Porovnanie podľa kritérií

| Kritérium | A: DC | B: Ruby | C1 | C2 (most) |
|---|---|---|---|---|
| Pripájanie childov do slotov | ❌ nemožné | ✅ natívne | ⚠️ obmedzené | ✅ |
| Tvorba nového typu korpusu | hodiny | minúty–hodina | hodiny | minúty–hodina |
| Auto-flagy kovania, pravidlá | ❌ mimo DC | ✅ súčasť rebuildu | ⚠️ napoly | ✅ |
| Krehkosť / počet pascí | vysoká | nízka | vysoká | stredná (len childy) |
| Čistota pre OCL/VEPO | ⚠️ závisí od disciplíny | ✅ garantovaná | ⚠️ | ✅ korpus / ⚠️ childy |
| Editácia bez nášho pluginu | ✅ | ❌ | ✅ | ⚠️ |
| Automatické testovanie | ❌ | ✅ | ⚠️ | ✅ |
| Využitie hotovej DC knižnice | ✅ | ❌ | ✅ | ⚠️ dočasne childy |

## Odporúčanie

**B — Ruby generovanie s vlastným dátovým modelom, s C2 ako migračným mostom.**

Dôvody v skratke: všetko, čo od systému chceš (pripájanie, inteligencia, jednotný výstup, rýchla tvorba knižnice), leží presne v oblastiach, kde DC engine je najslabší — a jediné, čo DC ponúka navyše (editácia bez pluginu, prenositeľnosť), reálne nepotrebuješ. Úspešné komerčné systémy v tejto doméne (ArchiWood, CabMaker) došli k rovnakému záveru.

**Migračná cesta:**
1. Referenčný korpus generovaný Ruby (podľa štandardu) → validácia OCL/VEPO.
2. Childy prvej vlny: police/priečky/jednoduché čelá generované Ruby; zložité moduly (Atira šuflíky) dočasne ako DC čierne skrinky (C2).
3. Postupné nahradenie DC childov Ruby šablónami; stará DC knižnica zostáva v archíve pre rozbehnuté zákazky.

## Proof-of-concept — VYKONANÉ 15.7.2026 cez SkAgent bridge ✅

Všetky 3 experimenty prešli (SketchUp 26.0.429, live model):

1. **Generovanie ✅** — Ruby postavil referenčný korpus (8 dielcov: 2 boky, dno, strop, chrbát HDF, sokel, polica, dvierka; NOXUN atribúty + config JSON na inštancii; materiály) za **4 ms**. Bbox presný: 600×529×720 (529 = 510 + 19 dvierka pred korpusom — systém to vie, lebo rozmery drží v konfigu, nie v bboxe).
2. **Rebuild ✅** — zmena konfigu (šírka 600→900, police 1→2) + `entities.clear!` + regenerácia = **3 ms**, jeden Undo krok. Bonus: pravidlo „šírka > 600 → 2 krídla" automaticky rozdelilo dvierka — prvá ukážka pravidlovej inteligencie.
3. **C2 most ✅** — DC šuflík Hettich Atira 176 v3 načítaný zo .skp (s kontrolou už-načítanej definície), vložený, scale+redraw na cieľ 864 mm: **trafené presne na 1 iteráciu** (273 ms; z toho DC redraw ~262 ms — DC engine je ~65× pomalší než naše generovanie).

**Poučný vedľajší nález:** pri redraw DC engine vypísal desiatky `failed to parse parent.parent!vnsir/vnhlb/c_vsok` — šuflík je vzorcami natvrdo priviazaný na rodičovskú skrinku s konkrétnymi názvami atribútov, samostatne „nefunguje". Potvrdzuje krehkosť DC väzieb; C2 most aj tak funguje (fyzický scale nominály nastaví). Dôsledok pre štandard: childy nesmú závisieť od `parent!` vzorcov — rozmery im dáva slot (Ruby); pri DC čiernych skrinkách počítať s tým, že ich vnútorné parent-vzorce mimo pôvodnej skrinky nebežia.

**Rozhodnutie B je potvrdené prakticky. Michal potvrdil 15.7.2026 — UZAMKNUTÉ.** Sekcia 4 osnovy štandardu sa uzamkne na „Ruby generovanie, regenerate pattern".
