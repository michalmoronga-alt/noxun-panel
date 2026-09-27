# KONŠTRUKCIA K1+K2 — výsledok, overenie a smoke (uzáver 27.9.2026, v0.14.0)

Blok 7 vybral Michal 26.9.2026 po smoke S1 PASS. Debata 26.–27.9. dala produktové rozhodnutia M1–M12 ([bloky/KONSTRUKCIA/ROZHODNUTIA_MICHALA_2026-09-27.md](bloky/KONSTRUKCIA/ROZHODNUTIA_MICHALA_2026-09-27.md)),
krížový audit bloku (Grok s webom, Codex s repom) našiel aj starú výrobnú chybu D-144 a mockup ([bloky/KONSTRUKCIA/MOCKUP_KONSTRUKCIA_2026-09-27.html](bloky/KONSTRUKCIA/MOCKUP_KONSTRUKCIA_2026-09-27.html))
Michal schválil 27.9. **bez bokorysu**. Implementácia bežala 27.9. (PR #401–#404, podklady #400); uzáver PR #405 vo **v0.14.0** mení len dokumentáciu a verziu.
Plný text bloku je v [ROADMAP_hotove_etapy.md](ROADMAP_hotove_etapy.md), celý priečinok bloku (rozhodnutia, mockup, packages s auditmi návrhu, krížový audit,
fakty z kódu) v [bloky/KONSTRUKCIA/](bloky/KONSTRUKCIA/).

## Výsledok pre stolára

- **Chrbát v drážke ide do nárezu v plnom rozmere skrinky** (D-143): horná 600 × 720 → do nárezu, VEPO aj ceny **600 × 720** (predtým vnútorný 564 × 684),
  dielňa ho zreže do drážky. Model ho ďalej ukazuje v drážke; karta dielca má riadok **„Do nárezu 600 × 720"** pod Hrúbkou. Staršie skrinky s chrbtom v drážke
  Kontrola označí ako zastarané a výrobné exporty počkajú, kým sa neprestavia — hromadne jedným klikom z riadku Kontroly („Prestaviť zastarané skrinky").
- **Komín vzadu** (K1): dno, strop a zadná výstuha končia o komín skôr ako boky, chrbát sa posunie na ich zadnú hranu a za ním ostane vzduchový kanál (bežne 50).
  Boky majú plnú hĺbku, vnútro, police, priečky a výsuvy zásuviek sa skrátia samé. Pri komíne sa **nika spotrebiča meria z hĺbky boku** (tak kótujú listy
  výrobcov). Najmenší komín podľa chrbta: naložený = hrúbka chrbta, v drážke = 10 mm + hrúbka chrbta.
- **Zapustený strop vpredu** (K1): plný strop alebo predná výstuha začína za prednou hranou boku; dno sa neposúva; dolná aj horná skrinka.
- **D-144:** vložený chrbát a chrbát v drážke pri výstuhách **na výšku** končí pod výstuhami (predtým nimi prechádzal a v kusovníku bol vyšší, než sa zmestí).
- **Chrbát z líšt** (K2): nový typ chrbta „Z líšt" — dve vodorovné lišty z korpusovej dosky medzi bokmi (dolná na dne, horná pod stropom), výška predvolene 100.
  Vnútro končí pred lištami v celej výške. V kusovníku **jeden riadok, 2 ks „Lista chrbta"**, vo VEPO **„Chrb HD"**, páska na jednej dlhej hrane (kus sa pri montáži
  len otočí). Materiál chrbta (HDF) sa pri lištách nepoužije.
- **Šablóna „Chladničková"** (v Štúdiu → Šablóny aj pri vkladaní): vysoká skriňa **600 × 2100 × 560**, sokel 100, **komín 50** (dno a strop 510, boky 560),
  **bez chrbta**, očakáva chladničku, dve dvierka nad sebou — dolné 719, horné 1274, strana pántov neurčená (Kontrola vyzve zvoliť). Dlaždica šablóny ukazuje
  „komín vzadu 50" a tooltip vetu o vetraní.
- Nemenné zásady: pri komíne 0 a zapustení 0 sa na skrinke nemení nič · vetracie otvory a výrezy ostávajú na stolárovi · rúrové skrinky sú mimo bloku
  (rúra chce iný detail) · Inspector nemá nové skupiny, len riadky v existujúcich (Strop, Chrbát).

## Dávky

| Dávka | PR | Verzia | Obsah |
|---|---|---|---|
| Podklady | #400 | — | rozhodnutia Michala, mockup, postrehy D-143 až D-145, priečinok bloku (docs) |
| KON-0 · D-143 | #401 | 0.13.1 | chrbát v drážke do nárezu v plnom rozmere, zastarané skrinky a hromadná prestavba, `CONFIG_SCHEMA` 19 |
| KON-A · K1 | #402 | 0.13.2 | komín vzadu, zapustený strop, nika z hĺbky boku, oprava D-144, `CONFIG_SCHEMA` 20 |
| KON-B · K2 | #403 | 0.13.3 | chrbát z dvoch líšt, jeden riadok „Chrb HD", `CONFIG_SCHEMA` 21, BuildPlan 6, ABS seed 5 |
| KON-D | #404 | 0.13.4 | šablóna Chladničková, knižnica šablón STD 7, súhrn konštrukcie na dlaždici |
| Uzáver | #405 | 0.14.0 | dokumentácia a verzia, priečinok bloku do archívu |

Bokorys v náhľade Inspectora (pôvodne KON-C) vypadol — Michal 27.9. kvôli priestoru panela; neskôr lepší 3D náhľad (D-145, zásobník Po V1).

## Overenie

Pri poslednej dávke (#404): **4643 headless · 134 JS sád · 3172 in-SketchUp PASS / 0 FAIL**. Všetky štyri dávky boli audit-povinné: každá mala pred kódom
package so zapracovaným **Codex auditom návrhu** (surové audity v priečinku bloku), slepú predrecenziu pred PR, **in-SU test ako bránu mergu**, GitHub Codex review
a zelené CI. Výrobné dávky (KON-0, A, B) mali mutačné overenie (3 · 12 · 12 mutácií, všetky padli), KON-D 8 mutácií.

## Aktualizovať plugin na oboch PC (Michal aj Lucia) pred prvou zákazkou

Zákazka uložená vo v0.14.0 je pre starší plugin uzamknutá: skrinka je v **schéme 21**, výrobný plán v **BuildPlan 6**, ABS pravidlá v **seede 5**
a knižnica šablón v **STD 7**. Starší plugin takú skrinku **neprestaví ani nevyexportuje**, „Z líšt" nepozná (prestavbou by vrátil dosku chrbta)
a knižnicu šablón STD 7 len číta (nedá sa v nej ukladať, premenovať ani mazať). Samostatne prenesený chrbát alebo lištu schéma nechráni — starší plugin
by chrbát vydal malý a lištu pod plným názvom. **Preto aktualizovať obe PC skôr, ako sa na nich otvorí prvá zákazka.**

## Známe dôsledky (nie chyby)

- **Chladničková + Beko:** vnútro 2100 − 100 − 18 − 18 = **1964**, Beko chce niku výšky 1940–1950 → po priradení ORANGE „výška niky", kým sa nenastaví
  **výška osadenia 14–24 mm** (pri 14 je deliaca hrana čiel 689, v pásme). Hĺbka (560 ≥ 555) aj šírka (564 ≥ 560) sedia.
- **Chladničková po vložení:** ORANGE „očakáva chladničku" a RED neurčený smer otvárania (strana pántov), kým sa nevyriešia (zámer). Pri zamknutej šírke nad 600
  pri vkladaní vzniknú viac ako dve dvierka.
- **Lišty chrbta s výstuhami rovnakého rozmeru a materiálu** sa v kusovníku zlúčia do **jedného riadku 4 ks** „Vyst PZ/Chrb HD" (výrobne ten istý kus).
  Ručná zmena materiálu len jednej lišty = 2 riadky (kusy sa líšia).
- **Plocha HDF v rozpočte je vyššia** (chrbát v drážke v plnom rozmere, cca +12 %) — zámer, dielňa zreže.
- **Staré zákazky:** horné skrinky s chrbtom v drážke (schéma < 19) a skrinky s vloženým alebo drážkovým chrbtom pri výstuhách na výšku (schéma < 20)
  sú zastarané — Kontrola RED, exporty stoja, kým sa neprestavia. Starý **samostatný** chrbát (odpojený, skopírovaný) bez značky dostane ORANGE
  „over rozmer do nárezu" a export prejde.
- **Naložený chrbát pri komíne** sedí medzi bokmi — je užší (šírka − 2 × hrúbka korpusu) a boky sú v plnej hĺbke: iný kusovník než bez komína.
- **Komín mení vnútro** — police, priečky a výsuvy zásuviek sú kratšie; zamknutý výsuv, ktorý sa nezmestí, je RED ako doteraz.
- Neskoršia zmena šablóny Chladničková sa do existujúcich knižníc sama nedostane (ručná úprava na každom PC alebo ďalšia migrácia knižnice).

## Otvorené body

- **Delenie čiel Chladničkovej 719 / 1274** — návrh na potvrdenie pri smoke (bod 4.3). Ak prax chce iné čísla, upravia sa v šablóne.
- **D-145** — náhľad Inspectora v lepšej 3D forme (komín, zapustenie a lišty čelný náhľad neukáže); zásobník Po V1.
- **K3 rohová skrinka** ostáva v bloku 4 (V1 bod 2 preto ešte nie je odškrtnutý).

## Smoke checklist bloku (v poradí práce v dielni)

Zlúčené zo sekcií „Smoke pre Michala" všetkých štyroch packages (KON-0, A, B, D) — bez duplicít, pri každom bode je dávka, z ktorej pochádza.
Nové nálezy sa zapíšu do [DOGFOODING.md](../DOGFOODING.md) (skupina „KONŠTRUKCIA K1+K2 — smoke po uzávere bloku 7") a opravia ako v0.14.x.

**0 · Príprava**
1. Aktualizuj plugin na **0.14.0 na oboch PC** (Michal aj Lucia; updater v Štúdiu → O plugine) a reštartuj SketchUp; over verziu v O plugine. *(KON-0 až KON-D)*

**1 · Staršia zákazka** (otvor kópiu reálnej zákazky s hornými skrinkami)
1. Kontrola hlási zastarané skrinky (chrbát v drážke, aj vložený či drážkový chrbát pri výstuhách na výšku) a VEPO sa nevyexportuje. *(KON-0, KON-A · D-144)*
2. „Prestaviť zastarané skrinky" z riadku Kontroly → prestavia sa naraz, jedno Späť vráti všetko; po prestavbe Kontrola OK a VEPO ide. *(KON-0)*
3. Dolná skrinka s naloženým chrbtom a bez komína: nič sa nemení (kusovník, VEPO). *(KON-0)*

**2 · Korpus — komín a zapustenie**
1. Dolná 600 × 720 × 510, naložený chrbát HDF 3, **Komín vzadu 50** → „Vnút. hĺbka" 460; kusovník boky 510, dno a strop 460, chrbát **564 × 620** (medzi bokmi);
   zbalená hlavička Chrbát „komín 50". *(KON-A)*
2. Komín 2 pri HDF 3 → pole červené a veta, nič sa nepostaví. *(KON-A)*
3. Horná 600 × 720 × 320 s chrbtom v drážke: komín 12 → odmietnutie; **13** → vnútro 307; do nárezu chrbát 600 × 720. *(KON-A)*
4. Strop „Zapustenie vpredu 30" (plný) → strop začína 30 mm za prednou hranou boku, dno nie; pri „Dve výstuhy" sa posunie predná výstuha; pri „Bez stropu"
   riadok zmizne. *(KON-A)*
5. Potiahni hĺbku skrinky s komínom 100 pod minimum (Scale) → zastaví sa na najmenšej platnej hĺbke (160) + hláška; jedno Späť vráti všetko. *(KON-A)*
6. Do poľa Komín napíš `50-20` → ostane 30. *(KON-A)*

**3 · Chrbát**
1. Nová horná skrinka 600 × 720 s chrbtom v drážke: kusovník aj VEPO „Chrbat" **600 × 720**; karta dielca „Do nárezu 600 × 720", Dĺžka/Šírka 564 × 684. *(KON-0)*
2. Chrbát v drážke + ručné olepenie hrany (a zvlášť pravidlo olepu pre chrbty) → Kontrola RED, VEPO stojí; zruš olepenie → OK. *(KON-0)*
3. Dolná 600 × 720 × 510, Chrbát **„Z líšt"**, výška 100 → v modeli dve lišty 564 × 100 × 18 (dole na dne, hore pod stropom); „Vnút. hĺbka" 492. *(KON-B)*
4. Výška líšt 290 pri dolnej skrinke 720 (vnútro 584) → pole červené a veta „Dve lišty po 290 mm sa do vnútra 584 mm nezmestia"; nič sa nepostaví. *(KON-B)*
5. Komín 50 + lišty → lišty posunuté o 50 dopredu, vnútro 442. *(KON-B)*
6. Prepni späť na „Naložený" → chrbát HDF sa vráti (aj s ručným materiálom, ak bol). „Z líšt" → výška 999 → „Bez chrbta" → „Aplikuj" funguje
   (skryté pole neblokuje). *(KON-B)*

**4 · Šablóny a chladnička**
1. Ulož skrinku s komínom ako šablónu a použi ju na inú → komín ide; stará šablóna na skrinku s komínom → komín ostane. *(KON-A)*
2. Štúdio → Šablóny: dlaždica **„Chladničková"** — „dolná · 600 × 2100 × 560", „očakáva chladničku", **„komín vzadu 50"**; tooltip s vetou o vetraní
   (aj pri vkladaní). Ostatné dlaždice bez zmeny. *(KON-D)*
3. Vlož ju (Inspector → Šablóna → Všetky šablóny): dno a strop 510, boky 560, **bez chrbta**, dve dvierka (dolné 719, horné 1274); Kontrola: „očakáva chladničku"
   a neurčený smer otvárania — zvoľ stranu pántov. **Potvrď, či delenie 719 / 1274 sedí na vašu prax** (ak nie, povedz iné čísla). *(KON-D)*
4. Priraď chladničku Beko: nika meria hĺbku **560** (hĺbka boku, nie po chrbát) a sedí; výška hlási ORANGE, kým nenastavíš **výšku osadenia 14–24 mm**. *(KON-A, KON-D)*

**5 · Výstupy pre dielňu** (kusovník, VEPO, Kontrola olepov)
1. Skrinka so 3.3: kusovník **1 riadok, 2 ks „Lista chrbta"**, VEPO **„Chrb HD s…"**, páska na jednej dlhej hrane. *(KON-B)*
2. Tá istá skrinka so stropom „Dve výstuhy" (100) → kusovník 1 riadok **4 ks**, VEPO „Vyst PZ/Chrb HD s…". *(KON-B)*
3. Ručne zmeň materiál len jednej lišty → kusovník 2 riadky (správne — kusy sa líšia). *(KON-B)*
4. Kontrola olepov: páska na hornej hrane dolnej lišty a na dolnej hrane hornej lišty. *(KON-B)*
5. Regresia: kópia reálnej zákazky bez komína a líšt — po prestavbe zastaraných skriniek sa kusovník ostatných dielcov, VEPO a cenová ponuka nemenia
   (okrem chrbtov v drážke, ktoré idú v plnom rozmere). *(celý blok)*

## Mimo bloku

D-145 (3D náhľad) v zásobníku Po V1 · K3 rohová skrinka v bloku 4 · rohové spoje per strana, poldrážka, „bez dielca", šablóny Rúrová a Drezová, vetranie
a výrezy v modeli, rúrové skrinky, presný prídavok 9 mm pri chrbte v drážke — vedome mimo (rozhodnutie M12).
