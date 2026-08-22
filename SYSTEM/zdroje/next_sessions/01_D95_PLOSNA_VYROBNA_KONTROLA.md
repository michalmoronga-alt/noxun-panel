# 01 · D-95 — Plošná výrobná kontrola projektu

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md): aktuálny audit + vyriešenie otvorených bodov.

## Kontext a pôvod

D-95 vznikol pôvodne ako nápad na „krížovú kontrolu diel po diele“ pred výrobou: prechádzať zákazku po dielcoch, odškrtávať skontrolované položky a ukladať stav kontroly v projekte.

Po diskusii 23. 8. 2026 Michal tento smer zásadne korigoval podľa reálneho workflow:

- zákazka môže mať stovky až tisíce dielcov; manuálne preklikávanie každého kusu by bolo neúmerne pomalé,
- rozmery sa kontrolujú priebežne počas návrhu,
- dnes už existujú dve veľmi hodnotné **plošné vizuálne kontroly**: ABS kontrola a kontrola smeru kresby,
- pri nich používateľ očami kontroluje celý projekt naraz a hľadá výnimky,
- budúce kontrolné funkcie majú skôr rozšíriť pohľady, izolácie, viditeľnosť a kontrolu sektorov než vytvoriť administratívny checklist per dielec.

## Aktualizovaný cieľ

D-95 má smerovať k **plošnej výrobnej kontrole projektu**:

> SketchUp viewport je hlavná kontrolná plocha. NOXUN nastavuje kontrolný režim, zvýrazní relevantné informácie a pomáha nájsť výnimky.

Cieľom nie je potvrdiť každý kus ručne, ale umožniť človeku rýchlo a spoľahlivo prehliadnuť aj veľmi veľkú zákazku.

## Základný princíp: toggles + presety

Michal preferuje **kombináciu** dvoch vrstiev:

### 1. Základné nezávislé prepínače

Používateľ môže kombinovať jednotlivé nástroje podľa potreby, napríklad:

- ABS kontrola,
- smer kresby,
- viditeľnosť čiel,
- viditeľnosť chrbta,
- výrobné dielce,
- zóny,
- budúce kontrolné overlaye.

Tieto nástroje majú zostať power-user flexibilné a nemajú byť násilne zviazané do jedného režimu.

### 2. Kontrolné presety/pohľady

Nad togglemi môžu neskôr vzniknúť hotové režimy, ktoré naraz nastavia kombináciu viditeľnosti, overlayov, filtrov a prípadne odporúčaného pohľadu, napríklad:

- **Kontrola ABS** — výrobná geometria + edge overlay, nepotrebné vrstvy stlmené,
- **Kontrola kresby** — grain overlay + vhodná viditeľnosť,
- **Kontrola čiel** — čelá plné, korpus stlmený/skrytý, pohľad spredu,
- **Kontrola interiéru** — čelá preč, viditeľné police/priečky/vnútorné dielce,
- budúca **kontrola sektoru** — zobraziť iba konkrétnu zostavu/segment.

Preset nemá byť nový zdroj stavu; má iba ovládať existujúce kontrolné nástroje.

## D-27 ako prirodzená súčasť smeru

Otvorený D-27 („rýchle zobraziť/skryť tagy z panela“) sa sem funkčne hodí.

Budúce rýchle show/hide ovládanie môže zahŕňať napríklad:

- Čelá,
- Korpusy,
- Chrbty,
- Zóny,
- výrobné dielce,
- prípadné ďalšie výrobné triedy.

Treba však auditovať, či má implementácia skutočne manipulovať SketchUp Tags, entity visibility, overlayom alebo kombináciou. Pôvodný D-27 názov nie je implementačné rozhodnutie.

## Kontrola rozmerov: výnimky, nie 2000 kót

Rozmery sa dnes kontrolujú priebežne. Ak sa pridá plošná rozmerová kontrola, vhodnejší smer je **detekcia anomálií** než vizualizovať rozmery každého dielca naraz.

Možní kandidáti na automatické zvýraznenie:

- extrémne úzky/krátky dielec,
- nezvyčajný rozmer vzhľadom na rolu,
- diel mimo dostupného formátu,
- podozrivá minimálna hrúbka/rozmer,
- geometria mimo očakávaného boxu,
- kolízie.

Princíp:

> automatika zúži tisíce položiek na malý počet kandidátov, ktoré si zaslúžia ľudský pohľad.

Presné heuristiky sa nesmú rozhodnúť bez reálnych výrobných príkladov, aby systém nevytváral šum.

## Kontrola sektoru/zostavy

Michal naznačil, že budúci uložený stav ľudskej kontroly môže byť prirodzenejší **per sektor/zostava** než per dielec.

Príklad budúcej úrovne:

```text
SEG-03 · Horné skrinky
ABS        ✓
Kresba     ✓
Kovanie    ✓
Geometria  ✓
```

Tento model sa však **nemá implementovať pred návrhom dátového modelu zostáv/segmentov**. Najprv treba vyriešiť [02_ZOSTAVY_SEGMENTY.md](02_ZOSTAVY_SEGMENTY.md).

Ak sa neskôr uložený check sektoru implementuje, zmysel môže mať fingerprint výrobne relevantného stavu sektoru, aby sa po zmene kontrola označila ako zastaraná. To je iba koncept, nie schválený dátový formát.

## D-94 — traceability kovania

D-94 je príbuzná, ale samostatná schopnosť: rozklik nákupného riadku kovania na konkrétne skrinky/čelá, z ktorých počet vznikol, a klik-select v modeli.

Je vhodné ju chápať ako súčasť filozofie:

> z agregovaného výrobného čísla sa viem rýchlo dostať k fyzickým zdrojom v modeli.

D-94 môže byť implementačne menšia a môže vzniknúť skôr než celý D-95.

## Čo sa po diskusii explicitne NEODPORÚČA

- povinné preklikávanie diel po diele,
- checkbox pre každý z tisícov dielcov,
- ručné potvrdenie každej ABS hrany,
- povinný sign-off každého výrobného atribútu,
- blokovanie exportu len preto, že nie je „odškrtnutých 100 % dielcov“.

## Otvorené otázky pre budúcu session/audit

1. Aké presety sú reálne najužitočnejšie pri veľkej zákazke? Začať empiricky z dogfoodingu, nie zo zoznamu možností.
2. Ako technicky riešiť izoláciu/stlmenie tak, aby read-only kontrola nevytvárala Undo kroky ani nezostala po páde v zlom stave?
3. Ktoré existujúce overlaye sa dajú bezpečne kombinovať a ktoré sa musia navzájom vylučovať?
4. Má byť „kontrolný preset“ iba UI projekcia existujúcich stavov, alebo potrebuje vlastný dočasný session state?
5. Ako sa budú kontrolné pohľady správať pri vybranom sektore/zostave?
6. Ktoré rozmerové/anomálne kontroly majú nízky false-positive rate v reálnej výrobe?
7. Ak sa neskôr uloží stav kontroly sektoru, čo presne ho invaliduje?

## Pred implementáciou

Povinne auditovať minimálne dnešné moduly ABS kontroly, grain overlay, selection/highlight cesty, Studio Control sekciu, model observer lifecycle, show/hide/tag mechanizmy a budúci model zostáv.
