# 05 · Shared library + updater (D-48 / D-52)

> **PREDIMPLEMENTAČNÝ KONCEPT — NIE TASK PACKAGE.** Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

D-48 rieši spoločný firemný zdroj pre dva počítače (Michal + Lucia). Dnes sú viaceré knižnice v lokálnom `%APPDATA%`, ale cieľ je zdieľať najmä:

- katalóg materiálov,
- šablóny,
- pravidlá/sety kovania,
- neskôr render/textúrové assety.

D-52 rieši jednoklikový update pluginu, aby druhé pracovisko nemuselo ručne dostávať nové buildy.

Obe témy sa oplatí navrhnúť spolu, lebo používajú spoločný firemný distribučný/sync kanál.

## Základný princíp

Neodporúča sa iba presunúť všetky lokálne JSON súbory z `%APPDATA%` priamo do synchronizovaného Google Drive priečinka.

Synchronizačný disk nie je databáza ani transakčný filesystem. Treba explicitne rozdeliť:

### Shared company data

Dáta, ktoré majú byť rovnaké na oboch pracoviskách:

- materiálový katalóg,
- hardware catalog/rules/sets podľa rozhodnutia,
- templates,
- appearance library/textures,
- prípadne distribučné balíky pluginu.

### Computer-local data

Dáta, ktoré patria konkrétnemu PC/session:

- theme,
- window size/position,
- dimension series, ak ostanú lokálnou preferenciou,
- cache Demos sitemap/images,
- dočasné downloady,
- telemetry/usage podľa súčasného kontraktu,
- lokálne lock/session súbory.

### Project data

Dáta, ktoré musia cestovať v `.skp` a nesmú byť závislé od shared knižnice:

- snapshoty použitého materiálu/kovania,
- projektové predvoľby,
- výrobné konfigurácie,
- budúce spotrebiče/sektory podľa ich kontraktu.

## Kandidát architektúry

Na diskusiu, nie schválené riešenie:

```text
Google Drive / NOXUN_LIBRARY
        ↓
shared immutable/versioned data
        ↓
local read/cache layer
        ↓
NOXUN Engine
```

Zápisy by nemali predpokladať, že súbor v cloude je okamžite a atómovo zhodný na oboch PC.

Možné mechanizmy na audit:

- revision/version pri každom shared katalógu,
- lokálny staging + atomic replace,
- lock/lease alebo optimistický CAS podľa typu dát,
- read-only ochrana pri novšej schéme,
- conflict detection namiesto tichého last-write-wins,
- lokálna cache pre rýchlosť/offline prácu.

## Konflikty medzi dvoma PC

Treba navrhnúť reálny scenár:

1. Michal otvorí katalóg.
2. Lucia otvorí katalóg.
3. Michal pridá materiál.
4. Lucia upraví iný materiál skôr, než sa jej zosynchronizuje Michalova verzia.

Systém nesmie ticho prepísať jednu stranu celým starším JSON súborom.

Dnešné mechanizmy `catalog_revision`, `record_rev`, flock/CAS a read-only pri nekompatibilnej schéme môžu byť dobrým východiskom, ale musia sa auditovať pre multi-PC filesystem sync.

## Offline režim

NOXUN nesmie prestať fungovať len preto, že Google Drive nie je dostupný.

Treba rozhodnúť:

- ktoré knižnice sa čítajú z lokálnej cache,
- či sa offline zápisy povolia,
- ako sa po návrate online mergeujú,
- či jednoduchší V1 model povolí zápis shared dát iba jednému „editor“ PC a druhému prevažne read-only.

Posledný variant môže byť pre dva firemné počítače praktickejší než budovať distribuovanú databázu.

## Render assety

M-R bude pravdepodobne používať väčšie JPG/PNG/PBR súbory. Tie majú iné vlastnosti než JSON katalóg:

- sú immutable alebo content-addressed,
- môžu sa cachovať lokálne,
- netreba ich pri každom štarte celé skenovať,
- väzba v katalógu má byť stabilná aj po presune root priečinka.

Preto shared library treba navrhnúť ešte pred definitívnym appearance storage kontraktom.

## D-52 — updater

Updater treba oddeliť od shared business dát.

Možný workflow:

```text
manifest
- latest_version
- package path/hash
- minimum compatible data schema?

↓
Stiahnuť / overiť
↓
bezpečne nainštalovať
↓
cleanup obsolete files
↓
reštart SketchUp podľa potreby
```

Treba mať rollback/backup a nikdy neprepísať rozbehnutý plugin napoly.

## Otvorené otázky

1. Kto je autoritatívny editor shared knižnice — oba PC alebo primárne Michal?
2. Je Google Drive iba transport, alebo priamy live storage?
3. Aký offline model naozaj potrebujeme?
4. Ktoré súbory sú shared vs. local? Spraviť explicitnú tabuľku.
5. Ako sa riešia conflict copies vytvorené Google Drive klientom?
6. Ako sa verzujú schémy shared knižníc a kompatibilita pluginu?
7. Updater: Google Drive package, GitHub release alebo iný firemný kanál?
8. Má byť update automaticky ponúknutý, alebo výhradne ručne tlačidlom?

## Pred implementáciou

Auditovať všetky `%APPDATA%` stores, `JsonFileStore`, locking/revision mechanizmy, templates/previews, materials/hardware katalogy, Demos cache, installer cleanup a aktuálny deploy workflow. Najprv vytvoriť maticu `project/shared/local/cache`, až potom meniť cesty súborov.
