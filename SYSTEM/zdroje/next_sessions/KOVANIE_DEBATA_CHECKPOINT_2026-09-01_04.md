# KOVANIE — checkpoint USER debaty 2026-09-01 · 04

> **Stav:** PRACOVNÝ CHECKPOINT / USER-DEBATA — nie implementačný spec, neimplementovať priamo.
> **Nadväzuje na:** `KOVANIE_DEBATA_CHECKPOINT_2026-09-01_03.md`.
> **Účel:** zachytiť rozhodnutia po bloku funkčných zón, resolvera, lockov, validácie a šablón.

---

## 1. Zásuvková zostava ako samostatný owner

- zásuvka dostane vlastný logický parent **Zásuvková zostava F1**,
- pod ňou patria: čelo, funkčná zóna, výrobné dielce boxu a resolved hardware set,
- čelo už nie je technickým ownerom výsuvu; funkčná zóna je SPACE/CONTEXT,
- zásuvková zostava vzniká automaticky po prepnutí čela na typ `Zásuvkové`, spolu s funkčnou zónou,
- pri prepnutí `Zásuvkové -> Dvierka` sa zostava, funkčná zóna, zásuvkové dielce a aktívne kovanie odstránia po jasnom zobrazení dopadu,
- pri návrate `Dvierka -> Zásuvkové` Engine ponúkne `Obnoviť poslednú konfiguráciu / Začať od defaultov`,
- obnova poslednej konfigurácie obnoví celý posledný stav: systém/radu, výšku, NL, opening mode, load variant, locky a overridy; potom sa stav znovu validuje voči aktuálnej funkčnej zóne,
- každé čelo/zostava si pamätá iba **jednu** poslednú konfiguráciu,
- lokálna história má prioritu pred globálnymi firemnými defaultmi,
- pri kopírovaní celej skrinky sa táto posledná konfigurácia prenáša do kópie; identity nových objektov sú nové.

---

## 2. Resolver — hard/soft validácia

- kompatibilitný profil môže používať **pevné limity aj malé kontrolované pravidlá/vzorce**,
- preferovať pevné overené limity; vzorce len tam, kde ich vyžaduje dokumentácia,
- žiadny voľný formula language; iba malý whitelist podporovaných typov pravidiel,
- validácia rozlišuje minimálne `OK / WARNING / ERROR`,
- **hard limit** = technicky neplatná konfigurácia,
- **soft recommendation** = technicky platná konfigurácia, ale Engine odporúča lepšiu voľbu,
- hard conflict zostáva viditeľný ako aktuálny neplatný stav; pôvodná hodnota nezmizne,
- návrh môže pokračovať a projekt sa dá uložiť, ale výrobný výstup / finálna kontrola sú blokované, kým hard conflict existuje,
- hard konflikty sa v Kontrole zobrazujú zoskupené podľa skrinky/ownera s presným dôvodom a navigáciou na problém,
- klik z Kontroly: označiť objekt v modeli + otvoriť správnu sekciu `Čelá / Kovanie / Zóny` + scroll/highlight na konkrétny konflikt.

---

## 3. Technické profily — revízie a stavy

- technické limity, kompatibilita, komponenty a parametre receptu patria k jednej reprodukovateľnej verzii variantu,
- po prvom použití/snapshotovaní je profil immutable,
- evidentnú chybu možno prepísať iba ak profil ešte nebol použitý v projekte; po použití vzniká nová revízia,
- stavový model: **Aktívny / Deprecated / Inactive**,
- Aktívny = ponúkaný resolverom/defaultom,
- Deprecated = zachovaný pre staré projekty, ale už nie nový default,
- Inactive = historický/odstavený variant, stále zachovaný pre reprodukovateľnosť.

---

## 4. Šablóny — uložené kovanie

- pri ukladaní korpusovej šablóny bude explicitná voľba **`Uložiť aj kovanie`**,
- šablóna bez uloženého kovania je čistá geometrická šablóna a po vložení používa aktuálne defaulty/resolver,
- šablóna s uloženým kovaním nesie aktívny technický stav: resolved sety, locky/override-y, snapshot potrebných definícií a mechanické zostavy,
- **skrytá posledná konfigurácia neaktívnych zásuviek sa do šablóny neukladá**,
- šablóna s hard conflictom sa NESMIE uložiť s kovaním; stále sa môže uložiť ako čistá geometrická šablóna,
- soft warning uloženie s kovaním neblokuje,
- soft warning sa pri vložení znovu vypočíta podľa aktuálnej geometrie a technického profilu; nie je snapshotovaným warningom,
- uložené locky zostávajú po vložení normálne aktívnymi lockmi,
- snapshot šablóny určuje počiatočný resolved stav; ďalšie geometrické úpravy už spúšťajú normálny resolver, locky a diff hlášky,
- ak je uložený variant `Deprecated`, vloží sa presne snapshot a iba sa upozorní na novšiu verziu,
- ak je `Inactive` a nekompatibilný, vloží sa ako hard conflict s návrhom kompatibilnej náhrady,
- ak je problém iba v jednom sete, ostatné sety zo snapshotu zostávajú nedotknuté.

---

## 5. Šablóny — vizuálne označenie kovania

- dlaždica šablóny s uloženým kovaním má malú ikonku **🔧** v rohu,
- čistá geometrická šablóna ikonku nemá,
- ikonku netreba ukladať ako nové booleovské pole; dá sa odvodiť zo skutočného obsahu `hardware_sets` / snapshotu,
- hover/focus na 🔧 ukáže stručný technický súhrn,
- tooltip obsahuje resolved sety a dôležité locky/override-y,
- pri viacerých druhoch kovania sa základný súhrn zoskupí podľa typu (napr. zásuvky/závesy/nohy/AVENTOS) a detail sa dá rozbaliť podľa ownerov,
- soft warning nedostáva samostatnú ⚠ ikonku; v hover detaile môže byť napr. `1 odporúčanie` + stručný dôvod,
- revízia sa v základnom hoveri nezobrazuje; zobrazí sa len ak je set Deprecated/Inactive alebo existuje novšia revízia,
- klik na 🔧 otvorí **read-only detail kovania šablóny ešte pred vložením**,
- read-only detail ukazuje resolved sety podľa ownerov, locky/override-y, opening mode, NL, výškový variant, nosnosť, revízny stav a soft recommendations,
- **konkrétne členy setu a Démos kódy sú dostupné až v rozbalenom technickom detaile**; základný pohľad zostáva čistý,
- z knižnice sa šablóna technicky neupravuje; editácia až po vložení do projektu.

---

## 6. Šablóny — aktualizácia a prepis

- žiadna priama akcia `Aktualizovať kovanie šablóny` v knižnici,
- workflow aktualizácie: `vložiť šablónu -> upraviť/prevalidovať -> uložiť znova`,
- ak rovnaký názov už existuje: ponuka `Nahradiť existujúcu / Uložiť ako novú`,
- pri nahradení sa ukáže stručný diff (geometria, kovanie, revízie, NL, locky/override-y...),
- pri `Uložiť ako novú` používateľ zadáva názov vždy ručne,
- pri `Nahradiť existujúcu` sa stará verzia ďalej nezachováva; žiadny rollback ani história šablón.

---

## 7. UI/UX dôsledok

Šablóna s uloženým kovaním predstavuje **reprodukovateľný počiatočný technický štandard**, nie navždy zmrazený objekt. Knižnica má na prvý pohľad rozlíšiť čisté geometrické šablóny od firemných technických štandardov, ale detailné dáta sa zobrazujú progresívne až po hoveri/kliknutí na 🔧.
