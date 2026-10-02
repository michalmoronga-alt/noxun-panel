# Knižnice a úložiská na počítači — súpis

> **Časť mapy modulov Noxun Engine.** Rozcestník a kľúčové invarianty sú
> v [../ARCHITEKTURA.md](../ARCHITEKTURA.md).
> **Čo to je:** súpis **všetkého, čo plugin ukladá mimo zákazky** — súbor, druh, či sa pri zdieľaní knižníc medzi počítačmi (D-48,
> Michal ↔ Lucia) prenáša alebo ostáva len tomuto PC, zámok, verzia dát, prílohy a kto súbor zapisuje. Autorita je register v kóde
> `Noxun::Engine::LibraryRegistry` (`noxun_engine/core/library_registry.rb`); táto stránka je jeho zrkadlo pre ľudí.
> **Ako sa číta:** časť 2 = knižnice, ktoré sa zdieľajú · časť 3 = len tento počítač · časť 4 = čo plugin ukladá mimo koreňa
> · časť 5 = fakty, na ktoré zdieľanie narazí. Čísla verzií sú len v [../../SYSTEM/STANDARD.md](../../SYSTEM/STANDARD.md) §13.1.
> **Údržba:** tabuľky časti 2–4 stráži `tests/pure/test_h16_kniznice.rb` — riadok musí sedieť s registrom (súbor, druh, zdieľanie,
> zámok, verzie), inak test padne. Nové úložisko = postup v [rozsirovacie-body.md](rozsirovacie-body.md) scenár 7. Priebeh prác sem
> nepatrí (KRONIKA).

## 1 · Pravidlá

- **Jediný koreň:** všetko leží v `%APPDATA%\NOXUN\Engine` a každý modul sa naň pýta cez `Materials.dir` (aj šablóny a štatistika).
  Testy celý koreň presmerujú jedným `Materials.test_dir_override`; vlastný výpočet koreňa z `%APPDATA%` guard nepustí.
- **„Zdieľa sa" (áno)** = D-48 Odoslať / Aktualizovať súbor prenesie na druhý počítač — **knižnice a ich prílohy** (materiály, ABS,
  kovanie, šablóny, dodávateľ, spotrebiče). **Len tento PC (nie)** = cesty, značky, osobné nastavenia, cache a zálohy.
  **Zmena zdieľania je rozhodnutie Michala** (test pripína zdieľanú množinu).
- **Nikdy sa neprenáša:** `.bak`, zámky (`*.lock`) ani dočasné mená zápisu (`*.tmp-…`, `*.staging`, `*.png.new`, `tmp/`). Z priečinka
  príloh sa prenášajú len **finálne** súbory (vzory `children` riadku), nie ľubovoľný obsah priečinka.
- **D-48 vyberá súbory podľa registra, nikdy výpisom priečinka** — v koreni môžu byť cudzie súbory (nástroj agentov, časť 4).
- **Rozmerové rady a „18 + 36" ostávajú každému PC** (rozhodnutie Michala 2.10.2026).

### library_registry.rb

**Čisté dáta** (bez IO a SketchUp API, hlboko zmrazené) — načíta sa hneď za `core/materials`, koreň sa pýta až pri volaní.

- **Riadok `ENTRIES`** (reťazcové kľúče): `key` · `file` (relatívne ku koreňu, priečinok končí `/`, forenzné zálohy = glob) · `kind`
  (`library attachments setting cache marker backup`) · `sync` (`shared` / `local`) · `resolver` (`'Modul.metóda'`, ktorá vráti cestu)
  · `lock` (meno z `LOCKS`) · `lock_mode` (`module` modul berie zámok sám · `caller` drží ho volajúci · `mixed` časť zápisov bez neho
  · `self` súbor zamyká sám seba · `none`) · `versions` (mená zo STANDARD §13.1) · `bak` (zápis cez `JsonFileStore.write`) · `of` /
  `attachments` (prílohy ↔ knižnica) · `children` (vzory finálnych súborov priečinka) · `transient` (dočasné mená; pri `bak` sa
  doplnia `<súbor>.tmp-*` a `<súbor>.bak.tmp-*`) · `writers` (súbory so zápisom, cesty od koreňa repa) · `outputs` (obsah mení
  kusovník, VEPO, kovanie alebo ceny) · `note`.
- **`LOCKS`** = 6 zámkových súborov → metóda ich cesty · **`OUTSIDE`** = 8 skupín mimo koreňa (`key`, `where`, `names`, `writers`,
  `reason`) · **`PRIMITIVES`** = `JsonFileStore` (zapisuje za volajúceho).
- **API:** `root` (= `Materials.dir`) · `entries` · `keys` · `get(key)` (String alebo Symbol, neznámy = `nil`) · `shared` · `path(key)`
  (absolútna cesta bez lomky na konci, glob = `nil`). Nič nečíta z disku.
- **Guardy** (`tests/pure/test_h16_kniznice.rb`): golden prvého behu v samostatnom procese (`tests/h16_first_use.rb`, súbory, obsah,
  zámky) · tvar registra · parita ciest s override aj bez neho · zámok držaný pri zápise = `lock` · jediný koreň · literály mien
  úložísk · zapisovatelia a **počet zápisových miest na súbor** (`WRITE_SITES`) · žiadny neznámy súbor po prvom behu a triedenie mien
  (finálne / technické / dočasné / neznáme — D-48 prenáša len finálne) · verzie ↔ STANDARD §13.1 · táto stránka ↔ register ·
  kľúče `localStorage` a zákaz inej perzistencie okna · pripnutá zdieľaná množina.
- **Ako pridať úložisko:** riadok `ENTRIES` (zdieľanie rozhodne Michal), cesta cez `Materials.dir`, verzia do STANDARD §13.1,
  riadok sem, krok v bežci prvého behu (ak súbor vzniká bez okna) a počet v `WRITE_SITES` — kontrolný zoznam je scenár 7
  v [rozsirovacie-body.md](rozsirovacie-body.md).
- **Čo register nerobí:** nič nekopíruje a `JsonFileStore` neregistrovaný súbor neodmieta — vynútenie a háčiky importu
  (`assess_import`, dopredná brána) pridá D-48 (SYNC-0) s vlastným auditom.

## 2 · Knižnice — zdieľajú sa pri D-48

| Súbor | Druh | Zdieľa | Zámok | Verzia | Čo to je |
|---|---|---|---|---|---|
| `materials.json` | knižnica | áno | `materials.lock` | `Materials::STD` · `Materials::SCHEMA_CURRENT` | katalóg dosiek a ABS pások (ceny, dekory, formáty) |
| `appearances/` | prílohy | áno | `materials.lock` | — | nemenné súbory vzhľadu `<uuid>.skm`; katalóg na ne odkazuje `appearance.id` |
| `abs_rules.json` | knižnica | áno | `materials.lock` | `AbsRules::STD` · `AbsRules::SEED_VERSION` | predvolené hrany podľa roly dielca |
| `hardware_rules.json` | knižnica | áno | `materials.lock` | `HardwareRules::STD` · `HardwareRules::SEED_VERSION` | pravidlá kovania |
| `hardware_catalog.json` | knižnica | áno | `hardware_catalog.lock` | `HardwareCatalog::SCHEMA_CURRENT` · `HardwareCatalog::SEED_SET_VERSION` | katalóg položiek kovania (kódy, ceny) |
| `hardware_taxonomy.json` | knižnica | áno | `materials.lock` | `HardwareTaxonomy::SCHEMA_CURRENT` · `HardwareTaxonomy::SEED_VERSION` | výrobcovia a rady kovania |
| `hardware_sets.json` | knižnica | áno | `materials.lock` | `HardwareSets::STD` · `HardwareSets::SEED_VERSION` | sety kovania |
| `templates.json` | knižnica | áno | `templates.json.lock` | `TemplateStore::STD` | šablóny skriniek a dosiek |
| `template_previews/` | prílohy | áno | `templates.json.lock` · drží volajúci | — | náhľady šablón `<druh>-<slug>-<sha16>.png` — meno z druhu a mena, na oboch PC rovnaké |
| `supplier_settings.json` | knižnica | áno | `materials.lock` | `SupplierSettings::STD` · `SupplierSettings::SEED_VERSION` | sadzby a riadky rozpočtu (Nastavenia rozpočtu) |
| `appliances.json` | knižnica | áno | `appliances.json.lock` | `ApplianceCatalog::STD` · `ApplianceCatalog::SEED_VERSION` | katalóg spotrebičov |
| `appliances/` | prílohy | áno | `appliances.json.lock` | — | listy spotrebičov `<uuid>/<uuid>_<slug>.<ext>`; záznam drží relatívne meno |

## 3 · Tento počítač

| Súbor | Druh | Zdieľa | Zámok | Verzia | Čo to je |
|---|---|---|---|---|---|
| `dim_series.json` | nastavenie | nie | `materials.lock` | `DimSeries::STD` | rozmerové rady polí Inspectora — každý PC svoje |
| `vepo_settings.json` | nastavenie | nie | `materials.lock` | — | zmiešaný: názvy zákaziek (kľúč = cesta .skp), posledný priečinok exportu a „18 + 36" (mení súbory VEPO) — každý PC svoje |
| `template_usage.json` | nastavenie | nie | `template_usage.json.lock` | `TemplateUsage::STD` | naposledy použité šablóny |
| `ui_theme.json` | nastavenie | nie | — | `Engine::UI_THEME_STD` | téma okien (Michal / Lucia) |
| `edge_check.json` | nastavenie | nie | — | `EdgeCheck::SETTINGS_STD` | prepínač kontroly hrán |
| `grain_check.json` | nastavenie | nie | — | `GrainCheck::SETTINGS_STD` | prepínač kontroly kresby |
| `direction_check.json` | nastavenie | nie | — | `DirectionCheck::SETTINGS_STD` | prepínač smeru otvárania |
| `updater_settings.json` | nastavenie | nie | `materials.lock` | `Updater::STD` | cesta k distribúcii aktualizácií |
| `usage_stats.json` | nastavenie | nie | `usage_stats.json.lock` | `UsageStats::SCHEMA` | merač používania panela |
| `demos_sitemap.json` | cache | nie | — | — | zoznam produktov Demosu (dá sa stiahnuť znova) |
| `textures/` | cache | nie | — | — | obrázky dekorov `<sha10>_<meno>` (časť 5, F2) |
| `legacy_cleanup.json` | značka | nie | `materials.lock` | `LegacyCleanup::STD` | upratanie starých nástrojov; kľúč = cesta Plugins tohto PC |
| `migration_hold.json` | značka | nie | `materials.lock` · zmiešaný | — | jednorazová značka migrácie katalógu; mazanie bez zámku |
| `uni_seed.done` | značka | nie | `materials.lock` · drží volajúci | — | UNI záznamy doplnené — aj „seed vedome zmazaný, nevracať" (F5) |
| `drawer_uni_seed.done` | značka | nie | `materials.lock` · drží volajúci | — | to isté pre UNI dosky zásuviek (F5) |
| `demos_throttle.lock` | značka | nie | sám seba | — | čas posledného dopytu na Demos |
| `materials.pre-schema-2.json` | záloha | nie | `materials.lock` · drží volajúci | — | záloha katalógu pred migráciou schémy |
| `materials.{corrupted,rolledback,json.bak.pre-rollback}-*.json` | záloha | nie | `materials.lock` · drží volajúci | — | forenzné kópie pri obnove a vrátení katalógu |

Zámkové súbory (`materials.lock`, `hardware_catalog.lock`, `templates.json.lock`, `template_usage.json.lock`, `appliances.json.lock`,
`usage_stats.json.lock`) a `.bak` každého súboru so zápisom cez `JsonFileStore` ležia vedľa — nikdy sa neprenášajú.

## 4 · Mimo koreňa

D-48 sa ich netýka — v súpise sú kvôli úplnosti „čo plugin ukladá".

| Skupina | Kde | Kto zapisuje | Prečo nie D-48 |
|---|---|---|---|
| `plugin_install` | priečinok `Plugins` (`noxun_engine.update.json`, `.update.lock`, `noxun_engine.leases`, `.new` / `.old`) | loader, `updater.rb`, `legacy_cleanup.rb` | inštalácia a aktualizácia pluginu |
| `plugin_data` | `noxun_engine/data/recipes/` (`RELEASED.json`, recepty) | nikto (len čítanie) | príde s aktualizáciou pluginu |
| `exports` | priečinok alebo súbor, ktorý vybral používateľ (VEPO, CSV, XLSX) | `vepo_export.rb`, `xlsx_writer.rb`, `production_core.rb` | výstup zákazky, nie knižnica |
| `temp` | `Dir.mktmpdir`, `Sketchup.temp_dir` (`preview.png`, `working.skm.staging`, miniatúra prílohy) | `materials_appearance_dialog.rb`, `appliance_dialog.rb` | po použití zaniká |
| `ui_memory` | `localStorage` okien (profil SketchUpu) — zbalenia `nxsec_*`, stĺpce a skupiny Kusovníka, navigácia Štúdia, DPH rozpočtu, posledné dekory a ABS, kovanie v šablóne | `boot.js`, `budget.js`, `form.js`, `hardware.js`, `nx_combo.js`, `sheet_layout.js`, `studio.js` | pamäť okna tohto PC |
| `dialog_prefs` | SketchUp `preferences_key` (Inspector, Štúdio, Mower) | SketchUp | veľkosť a poloha okien |
| `model` | `.skp` a slovník `NOXUN` (snapshoty pravidiel a setov, rozpočet, projektové materiály) | buildery a okná | cestuje so zákazkou |
| `dev_tools` | v koreni: `agent_register_videne.txt` | `scripts/start_okna.ps1` (nástroj agentov) | nie je súčasť pluginu; D-48 súbory mimo registra ignoruje |

## 5 · Čo zdieľanie narazí (podklad D-48)

- **F1 · Názov zákazky necestuje so zákazkou:** `vepo_settings.json` drží názvy pod kľúčom **cesty .skp** na tomto PC — Lucia
  pri otvorení tvojej zákazky názov nevidí (VEPO a exporty dostanú meno súboru). Súvisí s kartou zákazky.
- **F2 · Obrázky dekorov** sa sťahujú len pri založení skupiny z Demosu; okno Materiály číta len lokálny súbor → po zdieľaní
  katalógu druhé PC ukáže farby namiesto fotiek. D-48: zdieľať `textures/` alebo obrázok dotiahnuť pri zobrazení.
- **F3 · Zámky nie sú jednotné:** návratovú hodnotu `flock` kontrolujú len `Materials` a `ApplianceCatalog`; `TemplateStore.with_lock`
  výnimku prehltne. Na sieťovom disku by sekcia bežala bez zámku. D-48 import: zámok z registra + jednotné primitívum.
- **F4 · Poradie zámkov:** `hardware_catalog.lock` a `materials.lock` sa nesmú vnárať → Aktualizovať berie knižnice **postupne**.
- **F5 · Značky UNI** nesú aj význam „používateľ seed vedome zmazal — nevracaj ho", no žijú na PC. Katalóg bez UNI záznamu na PC
  **bez** značky (napr. starší plugin, potom aktualizácia) záznam pri ďalšom štarte doplní späť. **D-48 import musí zachovať úmyselné
  odstránenie**; zo súpisu nevyplýva automatické zdieľanie značiek.
- **F6 · Knižnica šablón** má vlastnú kópiu pravidla „zlý tvar = poškodený" (mimo spoločného primitíva) → zjednotiť pri D-48.
- **F7 · In-SU scenár KOV-I** si koreň šablón prepisuje ručne — po jedinom koreni zbytočné; upratať s najbližšou in-SU dávkou.
- **F8 · `scripts/ui_foto.ps1`** má vlastný zoznam „čo z koreňa kopírovať do nahrávky" → brať druhy z registra.
- **F9 · Návrh zdieľania** (`SYSTEM/zdroje/next_sessions/SYNC_KNIZNICE_NAVRH_2026-09-06.md` §1) má nepresnosti (jeden súbor setov,
  rozpočet žije v zákazke, chýbajúce súbory) — D-48 package odkáže na register namiesto tabuľky §1.
- **F10 · Nápad:** `Debug.report` doplniť o inventár knižníc (existuje, veľkosť, `std`) — porovnanie Michal vs Lucia jedným príkazom.
- **F11 · Téma a prepínače kontroly sú bez zámku** — dve okná SketchUpu: posledný zápis vyhrá (osobné nastavenie, prijateľné).
- **F12 · `versions` nie je kompatibilitná brána:** sety majú značky obsahu (STANDARD §13.2), materiály a kovanie lazy schému (§13.3)
  — SYNC-0 potrebuje skutočné pravidlá kompatibility (funkcie posúdenia store-ov), nie len čísla.
- **F13 · Cudzie súbory v koreni:** nástroj agentov píše `agent_register_videne.txt` priamo do koreňa → D-48 vyberá podľa registra.

## História

Kapitola vznikla dávkou H16 bloku 9 · HARDENING (krížový audit V1, C-04 / GR-03, príprava D-48) ako náhrada „záväzného zoznamu
store-ov" v návrhu zdieľania knižníc zo 6.9.2026; package a surový audit sú v `SYSTEM/zdroje/bloky/HARDENING/`.
