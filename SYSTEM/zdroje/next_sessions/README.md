# NEXT SESSIONS — predimplementačné koncepčné podklady

> **STATUS: PREDIMPLEMENTAČNÝ DISKUSNÝ BALÍK — NIE IMPLEMENTAČNÝ PLÁN ANI TASK PACKAGE.**
>
> Tento priečinok zhromažďuje témy, ktoré majú po uzavretí UI 2.0 slúžiť ako vstup do ďalších návrhových sessions. Žiadny dokument v tomto priečinku sám osebe neoprávňuje agenta začať implementáciu.

## A · Čo tu preberáme, ako dokumenty vznikli a čo riešia

Dokumenty vznikli 23. 8. 2026 počas strategickej konverzácie Michala s ChatGPT po takmer dokončenom UI 2.0/Štúdiu. Cieľom nebolo zoradiť ďalšie D-čísla mechanicky, ale vybrať oblasti, pri ktorých je výhodnejšie najprv vysvetliť používateľský workflow, dátový model, hranice a otvorené otázky a až potom vytvoriť implementačnú dávku.

Východiskový plán po UI reworku je:

1. dokončiť UI rework,
2. checkpoint + mini docs clean,
3. audit kódu a prípadný refactor/hardening **iba ak audit preukáže potrebu**,
4. pokračovať vo funkciách.

Tento priečinok obsahuje deväť kandidátov na budúce návrhové/implementačné sessions:

1. [01_D95_PLOSNA_VYROBNA_KONTROLA.md](01_D95_PLOSNA_VYROBNA_KONTROLA.md) — plošná vizuálna kontrola projektu; pôvodný „diel po diele“ koncept sa po diskusii opúšťa.
2. [02_ZOSTAVY_SEGMENTY.md](02_ZOSTAVY_SEGMENTY.md) — dátový a UX model zostáv/segmentov, scoped pravidiel, attachmentov, živých/spoločných prvkov a odložený Room/MagicPlan smer.
3. [03_KOVANIE_FAZA3.md](03_KOVANIE_FAZA3.md) — univerzálnejší rule model pre automatiku kovania, výklopy a vyrábané dielce zásuviek.
4. [04_SPOTREBICE_S1.md](04_SPOTREBICE_S1.md) — katalóg, projektové položky, väzba na skrinku/zónu, niche kontrola a rozpočet.
5. [05_SHARED_LIBRARY_UPDATE.md](05_SHARED_LIBRARY_UPDATE.md) — D-48/D-52: zdieľané firemné knižnice pre viac PC a distribúcia/updater.
6. [06_RENDER_MR.md](06_RENDER_MR.md) — appearance/render vrstva materiálov, textúry, PBR a orientácia kresby.
7. [07_KONSTRUKCIA_V1.md](07_KONSTRUKCIA_V1.md) — per-dielec konštrukčné odsadenia a budúce produktové typy čiel.
8. [08_PONUKA_DOKUMENTY_CENY.md](08_PONUKA_DOKUMENTY_CENY.md) — DOCX/PDF dokumenty, manuálna cenová čerstvosť a obchodný workflow.
9. [09_GHOST_VKLADANIE.md](09_GHOST_VKLADANIE.md) — V1-04 ghost placement: skrinka na kurzore, rotácia šípkami, floor/free Z, 4 predné anchory korpusu cez TAB; obsahuje aj predbežný audit proti `main` v0.7.51. **Pravdepodobný prvý funkčný kandidát po hardeningu**, ak finálny audit nepotvrdí blokér.

Dokumenty zámerne opisujú **problém, pracovnú predstavu a otázky**, nie konkrétne súbory, callbacky, API ani poradie commitov. Dokument 09 ide o krok ďalej: obsahuje predbežný audit dnešných dotknutých ciest, ale stále **nie je task package**.

## B · Úloha AI, model, dostupný kontext a povinné upozornenie

### Úloha AI

ChatGPT tu vystupoval ako **produktovo-architektonický konzultant a partner pre špecifikáciu**. Jeho úlohou bolo:

- prečítať aktuálne projektové dokumenty,
- spojiť otvorené položky do logických domén,
- pomenovať možné dátové/UX hranice,
- navrhovať alternatívy a otázky pre Michala,
- zachytiť rozhodnutia z rozhovoru.

AI v tejto fáze **nebola implementačný agent** a nerobila kompletný read-only audit celej aktuálnej codebase pre každý navrhnutý koncept.

### Model

Konverzácia a tieto podklady vznikli s modelom **GPT-5.6 Sol**.

### Kontext, ktorý mal model k dispozícii

Pri výbere tém a návrhoch boli načítané najmä aktuálne dokumenty:

- `SYSTEM/PLAN.md`
- `SYSTEM/DOGFOODING.md`
- `SYSTEM/V1_VIZIA.md`
- `SYSTEM/STANDARD.md`
- `docs/ARCHITEKTURA.md`

Model mal zároveň konverzačný kontext predchádzajúcej práce na NOXUN Engine, najmä UI 2.0/Inspector/Štúdio, produkčný workflow KLINIKA, existujúcu ABS kontrolu, kontrolu smeru kresby a aktuálne smerovanie od satelitných okien k jednému Štúdiu.

Nie každý budúci modul, volací graf, observer, test ani aktuálny diff bol pri vzniku týchto dokumentov auditovaný. To je zámer — ide o podklad pre diskusiu.

## ⚠ Povinné pravidlo pred implementáciou

**ŽIADNY dokument v tomto priečinku sa nesmie použiť priamo ako implementačné zadanie.**

Pred implementáciou konkrétnej témy musí agent minimálne:

1. načítať aktuálny `STAV.md`, `PLAN.md`, relevantný odsek `docs/ARCHITEKTURA.md`, `STANDARD.md` a aktuálne súvisiace docs;
2. auditovať aktuálny kód a testy dotknutej domény;
3. porovnať tento koncept s tým, čo sa odvtedy zmenilo;
4. explicitne vyriešiť otvorené otázky uvedené v danom dokumente — auditom alebo ďalšou konverzáciou s Michalom;
5. až potom vytvoriť samostatnú špecifikáciu/task package s rozsahom, invariantmi, migráciami, testami a stop condition.

Ak je koncept v konflikte s aktuálnym kódom alebo novším rozhodnutím, **aktuálna realita a novšie potvrdené rozhodnutie majú prednosť**.

## Ako tieto dokumenty používať v ďalšej session

Odporúčaný vstup pre AI:

> „Načítaj aktuálny STAV/PLAN/ARCHITEKTURU/STANDARD a potom `SYSTEM/zdroje/next_sessions/<téma>.md`. Najprv porovnaj koncept s dnešnou realitou. Nič neimplementuj. Vypíš potvrdené body, konflikty, otvorené rozhodnutia a otázky na Michala.“

Až po uzavretí tejto diskusie vzniká implementačné zadanie.

## Prednostný kandidát po hardeningu

Téma pôvodne vedená v parking lote ako **Základné vkladanie skriniek / V1-04** bola 23. 8. 2026 prebratá a zúžená na samostatný **Ghost Placement**. Jej schválený produktový kontrakt a predbežný audit sú už v [09_GHOST_VKLADANIE.md](09_GHOST_VKLADANIE.md).

Poradie stále nie je záväzný implementačný plán: najprv treba dokončiť UI 2.0, checkpoint/docs clean a následný hardening audit. Ak po ňom Ghost nemá nový konflikt, je preferovaný ako **prvá malá funkčná dávka**, pretože rieši opakovanú bolesť pri každom vložení skrinky bez otvárania segmentového scope.
