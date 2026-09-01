# KOVANIE — checkpoint USER debaty 2026-09-01 · 04

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01_03.md`.
> **Účel:** zachytiť ďalšie rozhodnutia o resolveri, zásuvkových owneroch a šablónach.

---

## 1. Stav technických variantov

Používateľ zvolil **A**:
- technické varianty/revízie majú stav `Aktívny / Deprecated / Inactive`,
- Aktívny = ponúkaný resolverom a môže byť default,
- Deprecated = zachovaný pre reprodukovateľnosť starých projektov, ale neponúkaný ako nový default,
- Inactive = historický/odstavený variant, zachovaný kvôli starým projektom a snapshotom.

Kompatibilitný profil môže používať **oboje**:
- pevné overené limity,
- malé kontrolované pravidlá/vzorce tam, kde limit skutočne závisí od iného parametra.

Žiadny voľný univerzálny formula language; preferovať jednoduché auditovateľné pravidlá.

---

## 2. Hard limits vs soft recommendations

Používateľ zvolil **C**:
- technický profil rozlišuje `OK / WARNING / ERROR`,
- hard limit = technicky neplatná konfigurácia,
- soft recommendation = konfigurácia môže fungovať, ale Engine odporúča vhodnejšiu voľbu.

Hard conflict:
- zostáva viditeľný ako aktuálny neplatný stav,
- Engine ukáže pôvodnú hodnotu, dôvod konfliktu, dostupný priestor/limit a odporúčanú náhradu,
- počas návrhu možno ďalej modelovať a projekt uložiť,
- hard conflict však blokuje finálnu kontrolu/výrobný výstup.

Kontrola:
- konflikty sú zoskupené podľa skrinky/ownera,
- každý má presný dôvod a link na problémový objekt,
- klik spraví celý opravovací skok: označí objekt v modeli + otvorí správnu sekciu `Čelá / Kovanie / Zóny` + doscrolluje na konkrétny konflikt.

---

## 3. Zásuvková zostava ako samostatný owner

Používateľ zvolil **A**:
- zásuvka dostane vlastný logický parent `Zásuvková zostava F1`,
- pod ňou sú čelo, funkčná zóna, výrobné dielce boxu, resolved hardware set a technická validácia,
- výsuv už nie je koncepčne „vlastnený čelom“; hardware vlastní celá zásuvková zostava,
- funkčná zóna je priestorový context.

Vznik:
- po zmene typu čela na `Zásuvkové` sa zásuvková zostava + funkčná zóna vytvoria automaticky,
- používateľ osobitne nezakladá zásuvku.

Zmena `Zásuvkové -> Dvierka`:
- zásuvková zostava, funkčná zóna, zásuvkové výrobné dielce a aktívne zásuvkové kovanie sa odstránia,
- pred potvrdením sa ukáže jasný dopad zmeny.

Návrat `Dvierka -> Zásuvkové`:
- používateľ zvolil **C**: ponúknuť `Obnoviť poslednú konfiguráciu / Začať od predvolených`,
- pri obnove sa obnoví **celá posledná zostava**: systém/rada, výška, NL, Classic/Tip-On, load variant, locky a ručné overridy,
- potom sa vždy nanovo validuje voči aktuálnej funkčnej zóne,
- ak sa geometria zmenila, obnovený stav môže byť hard conflict s návrhom náhrady.

Pamäť:
- konkrétne čelo/zostava má jednu poslednú lokálnu konfiguráciu,
- nový objekt bez histórie používa globálne firemné defaulty,
- pamätá sa iba **jedna** posledná konfigurácia, nie história viacerých.

Kopírovanie skrinky:
- používateľ zvolil **A**: kópia prenesie aj poslednú zapamätanú konfiguráciu zásuviek,
- kopíruje sa konfigurácia, nie identita; nové objekty dostanú nové ID.

---

## 4. Šablóny — uloženie kovania je voliteľné

Používateľ zvolil **C**:
- pri ukladaní korpusovej šablóny má byť voľba, či uložiť aj kovanie/technickú konfiguráciu,
- dôvod: niektoré korpusy sú de facto firemné štandardy a majú sa vkladať už s konkrétnym kovaním, ale ďalej dynamicky reagovať cez resolver,
- čistá šablóna bez uloženého kovania používa pri vložení globálne/project defaulty,
- šablóna uložená s kovaním nesie vlastný snapshot výberov/definícií podľa existujúceho template hardware kontraktu.

Repo už dnes podporuje prenos `hardware_sets` + zmrazených `hardware_set_defs` v šablóne; nový UX má túto vlastnosť spraviť vedomou a viditeľnou, nie skrytou.

### Vizualizácia v zozname šablón

- šablóna **bez uloženého kovania**: bez HW badge/ikony,
- šablóna **s uloženým kovaním**: malá ikonka/badge priamo na náhľadovej dlaždici, ideálne v rohu,
- po hover/focus nad ikonou sa zobrazí stručný prehľad, aké kovanie je v šablóne uložené,
- cieľ je, aby používateľ ešte pred vložením rozoznal „čistú geometriu“ od „štandardnej skrinky s technickým balíkom“.

Existujúci template UI už má preview dlaždice a badge mechaniku (napr. badge hrúbky pre doskové šablóny), takže HW badge je prirodzené rozšírenie existujúceho UX, nie nový samostatný browser.
