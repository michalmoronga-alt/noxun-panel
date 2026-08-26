# 05 · Shared library + updater (D-48 / D-52)

> Stav: KONCEPT — neimplementovať priamo · zdroj: PR #210 (23.8.2026) · auditované proti kódu: zatiaľ nie
>
> Pred implementáciou platí postup z [README.md](README.md).

## Kontext a pôvod

D-48 rieši spoločný firemný zdroj pre dva počítače (Michal + Lucia). Dnes sú viaceré knižnice v lokálnom `%APPDATA%`, ale cieľ je zdieľať najmä:

- katalóg materiálov,
- šablóny,
- pravidlá/sety kovania,
- neskôr appliance katalóg,
- neskôr render/textúrové a 3D assety.

D-52 rieši jednoklikový update pluginu, aby druhé pracovisko nemuselo ručne dostávať nové buildy.

Obe témy môžu používať rovnaký distribučný kanál, ale **software update a shared business dáta musia zostať oddelené domény**.

---

# Schválený produktový smer zo session 24. 8. 2026

## 1 · Engine version a Library versions sú dve nezávislé veci

Konceptuálne:

```text
NOXUN Engine v0.8.7

Materials library rev. 42
Templates library rev. 18
Hardware library rev. 28
```

Update pluginu nesmie ticho meniť alebo mazať používateľskú knižnicu. Library migrácie musia mať vlastný explicitný kontrakt.

## 2 · `Studio → O plugine` bude centrálna status/update stránka

Táto sekcia má vedieť ukázať minimálne:

```text
NOXUN Engine      0.8.7   ✓
Shared Library    pripojená ✓
Materiály         rev.42  ✓
Šablóny           rev.18  ✓
Kovanie           rev.27  ↑ dostupná rev.28

Posledná synchronizácia: ...
```

Ak je dostupná nová verzia Engine, `O plugine` ukáže napríklad:

```text
Aktuálna verzia: 0.8.6
Dostupná verzia: 0.8.7

[ Aktualizovať ]
```

Ak shared zdroj nie je dostupný:

```text
Shared Library
⚠ offline — používa sa lokálna cache
```

## 3 · Startup upozornenie na update

Pri zistení novej verzie má používateľ dostať krátke upozornenie. Preferovaný UX smer po externom SketchUp audite je **natívna `UI::Notification`**, nie agresívny blokujúci modal.

Príklad:

```text
Dostupná nová verzia NOXUN Engine 0.8.7

[ Otvoriť O plugine ]   [ Neskôr ]
```

Klik otvorí `Studio → O plugine`, kde používateľ vidí detaily a vedome spustí aktualizáciu.

Kritická/security aktualizácia môže neskôr použiť výraznejší režim, ale bežný update nemá blokovať štart SketchUpu.

## 4 · Reálny multi-PC workflow je low-contention

Michal bude pravdepodobne spravovať väčšinu kovania, ale občas môže materiál, kovanie alebo šablónu upraviť aj Lucia. Súbežné editovanie bude skôr výnimočné a počet zmien knižníc bude s dozrievaním systému klesať.

Preto sa **neplánuje distribuovaná databáza, CRDT ani komplexný offline merge systém**.

Použiť jednoduchý optimistic/revision guard.

### Record-level konflikt

Každý shared record má koncepčne minimálne:

```text
id
revision
updated_at
updated_by
```

Pri otvorení/editácii si klient pamätá pôvodnú revíziu. Pri uložení znova overí aktuálnu revíziu shared recordu.

Ak sa medzitým zmenila rovnaká identita:

```text
expected rev = 14
actual rev   = 15
```

zápis sa zastaví a používateľ dostane jednoduché rozhodnutie, napríklad:

- Načítať novšiu verziu,
- Uložiť ako novú položku,
- Zrušiť.

Tichý last-write-wins sa nepovoľuje.

**Dôležité:** súbežná zmena dvoch rôznych recordov nemá vyvolať konflikt celého katalógu.

## 5 · Shared source → vlastná local cache → Engine

Preferovaná mentálna architektúra:

```text
Google Drive / shared transport
        ↓
shared source
        ↓
NOXUN local cache
        ↓
NOXUN Engine
```

Engine nemá pri bežnej práci čítať cloudový/sync mount ako svoju runtime databázu.

Lokálna cache je **NOXUN cache**, nie Google Drive cache.

Výhody:

- rýchla a deterministická práca,
- projekt a Studio fungujú aj pri výpadku Drive,
- Drive pause/disconnect nesmie zastaviť Engine,
- synchronizačný filesystem nie je súčasť transakčnej logiky Engine.

## 6 · Offline režim pre V1

Ak shared source nie je dostupný:

- čítanie pokračuje z NOXUN local cache,
- projekty fungujú normálne,
- shared library editácia sa dočasne vypne,
- offline write queue + neskorší merge sa **v prvej verzii nerobí**.

Toto je vedomé zjednodušenie podľa reálneho dvoj-PC workflowu.

---

# Shared / Local / Project rozdelenie

## Shared company data

Dáta, ktoré majú byť rovnaké na oboch pracoviskách:

- materiálový katalóg,
- templates,
- hardware catalog/rules/sets podľa finálneho HW3 kontraktu,
- appliance katalóg podľa S1,
- appearance/textures,
- neskôr 3D asset knižnice,
- distribučné manifesty/balíky podľa zvoleného kanála.

## Computer-local data

- theme,
- window size/position,
- cache Demos sitemap/images,
- NOXUN local shared-library cache,
- dočasné downloady,
- telemetry/usage podľa existujúceho kontraktu,
- lock/session súbory,
- update staging/predchádzajúci package.

## Project data

Projekt nesmie byť závislý od momentálnej dostupnosti shared knižnice. V `.skp` ostávajú autoritatívne snapshoty použitých produkčných dát podľa doménových kontraktov.

---

# Externý implementačný audit — SketchUp / Google Drive / distribúcia

Externý research 24. 8. 2026 slúži ako upozornenie pre budúci implementačný audit. Nie je to hotový technický návrh.

## A · SketchUp má natívnu inštaláciu RBZ/ZIP

Ruby API poskytuje `Sketchup.install_from_archive(filepath, show_warning = true)`. Vie inštalovať RBZ/ZIP do Plugins priečinka a pri trusted automatickom update môže byť redundantné varovanie vypnuté.

To znamená, že D-52 nemusí implementovať vlastný unzip-copy mechanizmus iba preto, aby dokázal nainštalovať štandardný extension package.

## B · Kritická pasca: update počas bežiaceho SketchUpu môže vytvoriť mixed-version session

SketchUp komunita dokumentuje stav, keď sa aktualizované súbory fyzicky prepíšu, ale už načítaný Ruby runtime zostáva zo starej verzie; nové HTML/asset súbory sa pritom môžu načítať z disku. Výsledkom môže byť dočasná kombinácia starej Ruby logiky a nových UI súborov.

**Produktový invariant pre D-52:** po úspešnej inštalácii novej verzie sa update nepovažuje za runtime-aplikovaný. Používateľ dostane jasné:

> Aktualizácia nainštalovaná. Reštartuj SketchUp pre aktiváciu novej verzie.

Implementačný audit má rozhodnúť medzi:

1. jednoduchým RBZ overwrite + okamžitý restart-required stav,
2. robustnejším side-by-side/versioned release layoutom s malým stabilným bootstrap loaderom, ktorý novú verziu aktivuje až po reštarte.

Druhá cesta znižuje riziko mixed-version a obsolete-file problémov, ale nesmie sa zaviesť bez porovnania s dnešnou štruktúrou extension loadera.

## C · RBZ update nemusí odstrániť obsolete súbory

Komunitná dokumentácia upozorňuje, že inštalácia novej verzie typicky prepíše rovnaké súbory a pridá nové, ale staré súbory, ktoré už v novom balíku neexistujú, môžu zostať v Plugins priečinku.

Preto musí budúci updater explicitne riešiť jednu z možností:

- manifest `obsolete_paths` + bezpečný cleanup,
- clean versioned release directory,
- alebo iný auditovaný mechanizmus.

„Nainštalovať nový ZIP cez starý adresár“ nie je samo osebe dostatočný cleanup kontrakt.

## D · Download má byť asynchrónny

SketchUp Ruby API poskytuje `Sketchup::Http::Request` ako asynchrónnu HTTP vrstvu a dokumentácia ju odporúča ako alternatívu k `Net::HTTP`, ktorý má v SketchUpe známe problémy.

Hidden trap: request objekt musí zostať referencovaný; ak ho garbage collector odstráni, väčší download môže ticho zlyhať.

Budúci update checker/download preto nemá robiť synchronný network call na kritickej startup ceste.

## E · Kontrola update pri štarte nesmie brzdiť Studio

`Sketchup.is_online` podľa API môže trvať. Preto update availability check nemá blokovať načítanie pluginu.

Kandidát:

- Engine sa normálne otvorí,
- update check prebehne asynchrónne/deferred,
- výsledok aktualizuje `O plugine` a prípadne zobrazí `UI::Notification`,
- stav/čas poslednej kontroly sa môže cachovať, aby sa sieť nekontrolovala zbytočne pri každom otvorení okna.

## F · Integrity check package je povinný

Pred inštaláciou package overiť kryptografický digest (minimálne SHA-256) proti manifestu/release metadátam.

Ak bude distribučným kanálom GitHub Releases, aktuálne GitHub Release Asset API poskytuje `digest` pri assete a endpoint pre latest published release. Verejné releases/assets je možné čítať bez autentifikácie; privátny repository channel by vyžadoval credentials.

**Nikdy nevkladať trvalý GitHub PAT/token priamo do distribuovaného pluginu.** Ak update package musí zostať privátny, vybrať iný bezpečný firemný transport alebo samostatnú autentifikačnú vrstvu.

GitHub Releases je teda zaujímavý kandidát pre software package, nie automaticky rozhodnutý kanál.

## G · Google Drive cache nie je NOXUN cache

Google Drive for desktop má dva režimy: streaming a mirroring. Pri streamingu sú dáta závislé od Drive klienta/cache a unsynced zmeny môžu byť uložené iba v jeho cache. Google dokumentácia zároveň upozorňuje na rozdielne offline vlastnosti a riziko straty nesynchronizovaných zmien pri probléme/cache recovery.

Pre NOXUN z toho vyplýva:

> Ani „Available offline“ v Drive nenahrádza vlastnú NOXUN cache a snapshot autoritu.

Shared source je transport/distribúcia; runtime čítanie má ísť z kontrolovanej lokálnej vrstvy.

## H · Conflict copies / duplicate identity health scan

Keďže filesystem sync môže pri rozdielnych lokálnych verziách zachovať obe kópie, synchronizácia nemá predpokladať, že názov súboru automaticky znamená jedinú autoritatívnu identitu.

Lacný guard pre V1:

- pri synchronizačnom importe detegovať duplicitné `id`,
- pri rovnakej revízii a inom obsahu označiť konflikt,
- conflict/duplicate record neprepísať automaticky,
- `O plugine` alebo Studio health ukáže problém na ručné vyriešenie.

Pri očakávanej nízkej súbežnosti je to primerane jednoduchá poistka.

## I · Bezpečný lokálny zápis

Na Windows existuje natívny koncept replace-file operácie s možnosťou backupu a požiadavkou, aby replacement/target boli na rovnakom volume. Implementačný audit má preto pre lokálne cache/store zápisy zachovať vzor:

```text
serialize
→ write temp/staging
→ validate
→ replace target
```

Dôležité: lokálna atomicita filesystem operácie **neznamená cloudovú transakciu Google Drive**. Preto revision/conflict guard ostáva potrebný aj pri bezpečnom lokálnom zápise.

## J · Viac verzií SketchUpu

Každá major verzia SketchUpu používa vlastné extension prostredie/Plugins priečinok. Ak sa NOXUN používa paralelne napr. v SketchUp 2022 a 2024, update aktívnej inštalácie automaticky neznamená aktualizáciu druhej major verzie.

Toto treba pri finálnom D-52 audite zahrnúť do support kontraktu, ale nemusí to komplikovať prvú dvoj-PC verziu, ak oba workflowy používajú jednu dohodnutú verziu SketchUpu.

---

# Kandidát jednoduchého synchronizačného správania

```text
START / MANUAL REFRESH
        ↓
shared source dostupný?
   │                │
   NIE              ÁNO
   │                │
local cache       načítať/validovať shared zmeny
read-only edits      ↓
                conflict/duplicate guard
                     ↓
                refresh local cache
                     ↓
                   Engine
```

Pri shared editácii:

```text
record opened at rev N
        ↓
user edits
        ↓
pre-save reread shared record
        ↓
rev stále N ?
  │           │
 ÁNO          NIE
  │           │
save N+1    STOP + konflikt UI
```

Tento model vedome nerieši extrémny race medzi posledným reread a cloud syncom ako plnohodnotná databáza. Pri dvoch pracoviskách a nízkej súbežnosti je akceptovateľnejší jednoduchý detektor konfliktu než distribuovaný locking framework.

---

# Render/3D assety

Väčšie JPG/PNG/PBR/SKP assety majú iné vlastnosti než editovateľné JSON/catalog records:

- preferovať immutable/content-addressed alebo verzované assety,
- lokálna cache,
- katalóg drží stabilnú referenciu/asset ID,
- neprepísať potichu rovnaký asset pod rovnakou identitou iným obsahom,
- neskenovať celú veľkú knižnicu pri každom štarte.

Shared library treba zosúladiť s budúcim [06_RENDER_MR.md](06_RENDER_MR.md) a HW3 asset smerom.

---

# Otvorené otázky pred task package

1. Ktorý transport bude autoritatívny pre plugin package: GitHub Release, Google Drive alebo iný firemný kanál?
2. In-place RBZ + restart, alebo versioned releases + stable bootstrap loader?
3. Ako dnešné `JsonFileStore`, `catalog_revision` a `record_rev` najjednoduchšie rozšíriť na shared source bez paralelného druhého persistence frameworku?
4. Aká granularita recordov je reálne potrebná pre materials/templates/hardware?
5. Ako detegovať Google Drive conflict copies/duplicate IDs v dnešnej store štruktúre?
6. Ktoré library revisions zobrazovať používateľovi v `O plugine` a ktoré sú iba interné schema/revision čísla?
7. Aký presný support kontrakt bude pre SU 2022/2024 a budúce major verzie?
8. Má používateľ po update iba dostať „reštartuj SketchUp“, alebo má NOXUN ponúknuť bezpečné zavretie/reštart workflowu?

---

# Pred implementáciou

Auditovať aktuálny stav, nie implementovať priamo z tohto dokumentu:

- všetky `%APPDATA%` stores,
- `JsonFileStore`, locking/CAS/revision mechanizmy,
- materials/hardware/templates/appliance storage,
- templates/previews,
- Demos cache,
- extension registrar/loader a package layout,
- installer cleanup,
- aktuálny build/deploy workflow,
- Studio `O plugine` shell,
- podporované SketchUp major verzie.

Najprv vytvoriť explicitnú maticu `project / shared / local / cache` a porovnať dnešné persistence kontrakty s týmto konceptom. Až potom samostatný task package s migráciou, testami, rollbackom a stop condition.

## Externé zdroje použité pri koncepte

- SketchUp Ruby API — `Sketchup.install_from_archive`
  - https://ruby.sketchup.com/Sketchup.html
- SketchUp Ruby API — `UI::Notification`
  - https://ruby.sketchup.com/UI/Notification.html
- SketchUp Ruby API — `Sketchup::Http::Request`
  - https://ruby.sketchup.com/Sketchup/Http/Request.html
- SketchUp Developer Forum — mixed-version stav pri update bežiaceho extension
  - https://forums.sketchup.com/t/installing-new-version-of-an-extension/26895
- SketchUp Developer Forum — RBZ update a obsolete files
  - https://forums.sketchup.com/t/question-about-upgrading-an-extension-in-extension-warehouse/222631
- Google Drive Help — streaming/mirroring/cache/offline správanie
  - https://support.google.com/drive/answer/16631477
  - https://support.google.com/drive/answer/13470231
- GitHub Docs — Releases / release assets / digest
  - https://docs.github.com/en/rest/releases/releases
  - https://docs.github.com/en/rest/releases/assets
- Microsoft Learn — ReplaceFile / moving and replacing files
  - https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-replacefilea
