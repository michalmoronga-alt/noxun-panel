# NÁSTROJE-1 — DRAFT package (4.9.2026, po Codex CLI audite + GH kolách #288 1–3)

> Stav: KONCEPT — HISTÓRIA auditov; package bol 4.9.2026 po audite 5 (SOUND) PRENESENÝ do `SYSTEM/PLAN.md` (blok 4) — autorita je PLAN, tento súbor je archív nálezov a rozhodnutí.

> Rozhodnutia Michala 4.9.: jeden balík, spoločný toolbar „Noxun Nástroje", UI nástrojov nemeniť, kópia cez engine, názov kópie s písmenovou príponou, tlačidlo „Vložiť kópiu" NIE.
> Outside-in packet: [NASTROJE_OUTSIDE_IN_2026-09-04.md](NASTROJE_OUTSIDE_IN_2026-09-04.md). Referenčný kód: `../archiv_kod/legacy_*.rb.txt`.

- **NÁSTROJE-1 · TASK PACKAGE „MOWER + SNAPER V BALÍKU NOXUN ENGINE" (D-20; V1 bod 1A — Michal 4.9.2026; Audit: HOTOVÝ — Codex CLI 4.9. (1 BLOCKER + 9 FIX + 1 NOTE) + Codex GH #288 kolá 1–3 + **Codex CLI audit 2 (4.9.: 1 BLOCKER + 5 FIX + 1 NOTE) zapracované** (v texte označené „audit 2"); **audit 3 (1 BLOCKER + 2 FIX) a audit 4 (1 BLOCKER) zapracované**; čaká na potvrdzujúci CLI audit 5; in-SU POVINNÉ):**
  **Cieľ:** jeden inštalačný balík — oba nástroje sa presunú ako moduly do `noxun_engine/tools/` (`mower.rb`, `snaper.rb` + ČISTÉ jadrá `mower_calc.rb`, `snap_calc.rb` bez `UI::*`; namespace
  `Noxun::Engine::Tools::*`), načíta ich `main.rb`, dostanú **jeden spoločný toolbar „Noxun Nástroje"** (poradie: −90° · +90° · 180° · Z = 0 · Z posun… · Kópia vľavo · Kópia vpravo · Prisunúť vľavo ·
  Prisunúť vpravo; slovenské tooltipy; menu Extensions → Noxun Engine → Nástroje). Vlastné registrácie rozšírení a `VERSION` nástrojov zaniknú — verziu aj update (D-52) preberá engine. **Prečo samostatný
  toolbar:** toolbar enginu má železné pravidlo „do modelu sa nezapisuje" (D-103/D-105); nástroje model menia. UI nástrojov sa inak NEMENÍ (Michal: „nechať im svoj svet").
  **Outside-in (CLAUDE.md pravidlo): HOTOVÝ 4.9.2026** — packet [zdroje/next_sessions/NASTROJE_OUTSIDE_IN_2026-09-04.md](zdroje/next_sessions/NASTROJE_OUTSIDE_IN_2026-09-04.md)
  (cez WebSearch/WebFetch oficiálnej API dokumentácie, agy kvóta vyčerpaná). Reconcile: `drawing_element_visible?` (od 2020.0) **hádže výnimku pred SU 2026.0, keď je posledný prvok cesty
  skupina/komponent** → volať pod `rescue` s fallbackom na `hidden?` + `layer.visible?` po celej ceste, test oboch vetiev · `transform_entities` interpretuje transformáciu globálne LEN v aktívnom
  kontexte a jeho rodičoch → nástroje výhradne v root kontexte · toolbar `show`/`restore` podľa `get_last_state` · natívne `Sketchup::Snap` (2025.0) = kandidát pre zostavy/GHOST, nie pre túto dávku.
  **Registrácia (audit FIX 9):** JEDEN idempotentný registrátor podľa vzoru `Engine.install_toolbar` (`@toolbar` procesná referencia, `file_loaded?` guard, jedna sada `UI::Command` zdieľaná menu aj
  toolbarom) — legacy `build_toolbar` pri load bez guardu sa NEprenáša. Trojstav toolbaru sa implementuje VÝSLOVNE (audit 2 NOTE: `install_toolbar` volá len `restore`): `get_last_state`
  never shown → `show`, visible → `restore`, hidden → nič. **Restart latch (FIX 3 + audit 2 FIX 4):** všetkých 9 príkazov kontroluje **`Engine.update_restart_pending?`** (ako toolbar enginu; po swape príkaz odmietne s hláškou). **Kontext (FIX 4, 5):** nástroje pracujú LEN v root kontexte a LEN s korpusom na root úrovni — otvorený edit komponentu alebo vnorený NOXUN korpus = hláška v statuse, žiadna operácia
  (legacy Mower počítal pivot v parent-relative rámci a rotoval po lokálnej Z; kópia vnoreného korpusu by skončila inde). Odmietnutie je **preflight NÁSTROJA** — `CabinetBuilder.build` si edit
  kontext zatvára sám, preto musí prísť pred ním (audit 2).
  **Kópia (Mower) — oprava fantómu:** dnes `add_instance` tej istej definície bez atribútov inštancie → kópia bez identity (Inspector ju nevidí, nie je v kusovníku, pri prestavbe originálu sa mení
  s ním). Pre NOXUN skrinku pôjde kópia **cestou „Vložiť kópiu"** (`Store.config` → `config_to_params` → `rekey_hardware_manual` → `CabinetBuilder.build(model, params, transform:
  src.transformation * Geom::Transformation.translation(Units.vector(±šírka_mm, 0, 0)))` — **mm → palce cez `Units` (audit BLOCKER 1), nikdy holé číslo**): vlastná definícia, nové sekvenčné CAB číslo,
  1 operácia = 1 Späť, výber = kópia, **`Panel.push_selected(model, dedup: false)`** (audit 2 FIX 3: predvolené `dedup: true` by založilo ďalšiu observerovú požiadavku — kópia má vlastné CAB id;
  test aj s prázdnou `@requested` frontou); brána R-12 `newer_config?` = kópia sa nevloží + hláška. Šírka kroku z configu (`width`) = **susednosť OBÁLOK KORPUSOV** (Codex #288: čelo so
  záporným `gap_sides` alebo úchytka smie presahovať šírku korpusu, takže sľub „dotyk bbox" neplatí — test meria X-rozsah korpusov, nie bbox); pri parametrickej skrinke odpadajú odhady osi a znamienka
  podľa uhla (kópia sedí po VLASTNEJ osi X pri akejkoľvek rotácii). **Názov kópie (FIX 10):** ručný názov + písmenová prípona: hľadá sa **najbližšia voľná** prípona v celom modeli (a, b, … z; po
  vyčerpaní číslo „ 27", „ 28"…), základ sa oreže tak, aby prípona vždy prežila `sanitize_name` (`NAME_MAX_LEN` 80); bez ručného názvu ostáva automatický. **Dosky (NOTE 11): SCOPE OUT** — `BoardBuilder.build`
  polohu neprijíma (šev príde s GHOST-D1); kópia dosky = hláška „zatiaľ nie". Nie-NOXUN objekty (staré DC komponenty): dnešná cesta (DC `lenx` / bounds, `add_instance`).
  **Undo a ghost zóny (FIX 2 + kolo 3 P1/P2):** každá mutácia nástroja nad NOXUN objektom (rotácia, Z, snap, kópia) beží **celá pod existujúcim `ScaleWatch.guard`** (ako vlastné stavby
  enginu) a v tej istej operácii zavolá existujúci sync ghost zón — guard zabráni, aby `notify_change` zaradil korpus do fronty, takže odložený `process_dirty` nemá čo commitnúť a transparentný
  `move_ghost_op` sa nemôže prilepiť k ďalšiemu kroku používateľa. **Pred KAŽDOU polohovou mutáciou NOXUN objektu** (rotácia, Z, snap, kópia) nástroj zavolá NOVÉ explicitné API **`ScaleWatch.flush_pending!(model)`** (audit 2 BLOCKER: dnešný `guard`
  zabráni len NOVÝM udalostiam, naplnené fronty `@dirty/@added/@requested` nevyčistí a ručný `process_dirty` nezastaví debounce timer — prázdny timer by cez `@last_model` znovu spustil globálny
  `dedup_copies` a prilepil ho k ďalšej operácii): `flush_pending!` zastaví timer, zneplatní jeho generáciu a spracuje fronty (mierka → config + prestavba, ghost sync, dedup) PRED otvorením
  operácie nástroja — aj pri čakajúcom obyčajnom Move/Rotate, nielen pri mierke. **Je to skutočná BARIÉRA, nie jedno spracovanie (audit 3 BLOCKER):** `process_dirty` môže pri čerstvej kópii
  nájsť staršiu duplicitu a znova zavolať `schedule` — nový timer s prázdnymi frontami by cez `@last_model` vykonal transparentný dedup PO operácii nástroja. Preto flush opakuje spracovanie,
  kým observer nie je v pokoji (žiadny naplánovaný timer, prázdne `@dirty/@added/@requested`), so stropom iterácií (napr. 5) — ak pokoj nenastane, nástroj operáciu ODMIETNE s hláškou. **Multi-model proveniencia (audit 4 BLOCKER):** keď `process_dirty` pri čerstvej kópii nájde
  staršiu duplicitu, dnes volá len `schedule` bez cieľového modelu a ďalšia iterácia by spracovala iba `@last_model` — follow-up preto musí znovu zaradiť KONKRÉTNY `mdl` do `@requested`
  (per-model fronta), bariéra vyhlási pokoj až keď sú prázdne fronty VŠETKÝCH modelov, a `@prune_models` sa flushom nestráca. Test s dvoma dokumentmi (A aj B majú duplicitu, `@last_model`
  ukazuje len na B): po flushi sú obe identity opravené a žiadny timer nebeží. Test: „stará duplicita + čerstvá kópia → flush → operácia nástroja → žiadny timer a OBE identity opravené". Po flushi sa transformácia číta znova; ak nie je rigidná (`CabinetBuilder.rigid_matrix?`), príkaz sa ODMIETNE
  s hláškou (žiadny tichý neúspech) — platí pre rotáciu, Z, snap aj kópiu (audit 2 FIX 2 + audit 3 FIX 2: `attach_one` dnes kontroluje LEN `scaled?` — dĺžky osí — takže šmyková matica s jednotkovými, ale nekolmými osami prejde a vetvy Move/Rotate aj verejný
  `remember_transform` ju uložia bez kontroly; **rigidita sa preto vynúti PRIAMO na hranici cache** — `remember_transform`/`attach_one` uložia len `CabinetBuilder.rigid_matrix?` transform a
  `reject_scale` nerigidný stav nikdy „nepotvrdí"; test s maticou s jednotkovými osami a nenulovým skalárnym súčinom).
  **`ScaleWatch.remember_transform`** sa volá až po úspešnom commite a LEN po potvrdenej rigidite (pod guardom ho observer nedosiahne; inak by neskôr odmietnutá šikmá mierka cez
  `reject_scale` obnovila polohu spred príkazu). Povinné testy: rotácia → okamžitá kópia (< debounce) → dobeh → Späť kópie vráti LEN kópiu, rotácia
  drží **a vo fronte observera neostane dirty udalosť**; posun nástrojom → odmietnutá (šikmá) mierka → poloha z nástroja ostáva; natívny Move → okamžitá Kópia → dobeh → Späť vráti LEN kópiu (žiadny ghost sync zdroja);
  Scale → okamžitá rotácia / Z / snap (aj so zlyhanou absorpciou = odmietnutie); po flushi je timer zastavený a fronty prázdne (test číta stav observera). **Scale race (Codex #288 kolo 2 P2 → audit 2 BLOCKER):** riešený `flush_pending!` vyššie (pre všetky príkazy, nie len kópiu). In-SU prípad: Scale → okamžitá Kópia.
  **Rotácie ±90/180, Z = 0, Z posun:** logika bez zmeny (pivot = stred bbox, svetová Z — v root kontexte); Z-posun dialog ostáva HtmlDialog (callbacky pred `show`). **Z-dialog počas update (kolo 3 P1 + audit 2 FIX 4):** callback `applyZ` je guardovaný cez **`Engine.update_locked?(:tools_z)`** (API vyžaduje `tag`); dialog dostane `hide`,
  `dialog_closed?` a `set_on_closed` (nastaví referenciu na `nil`) a je zaradený do VŠETKÝCH TROCH zoznamov bariéry: `SupplierSettingsDialog.close_plugin_dialogs`,
  `SupplierSettingsDialog.dialogs_closed?` (pred stagingom aj tesne pred commitom) a post-swap `Engine.close_all_dialogs`; test: update pri otvorenom Z dialogu = dialog zavretý, žiadny zápis do modelu.
  **Snaper (FIX 6):** AABB sweep v lokálnom rámci cieľa, WARN 10 m, BLOCK 20 m, kontajnery do hĺbky 8 — **efektívna viditeľnosť cez `Model#drawing_element_visible?`** (celá instance path + tag
  folder; pod `rescue` s fallbackom — pred SU 2026.0 hádže výnimku pre kontajner na konci cesty (viď outside-in packet), takže fallback je tam BEŽNÁ cesta: `hidden?` + `layer.visible?` +
  **skrytý tag folder** po celej ceste (existujúca `Tags.folder_hidden?`, tags.rb — tag pod skrytým priečinkom ostáva `visible?`); test pre pre-2026 vetvu s prekážkou pod skrytým priečinkom), bbox kontajnera sa odvodzuje **rekurzívne** tou istou visibility-aware traverzou (len viditeľné listy, hĺbka 8) — jednoúrovňový výpočet by bral bounds vnoreného kontajnera so skrytou
  geometriou (kolo 3 P2); **tou istou traverzou sa počítajú aj bounds CIEĽA** (`ctx[:t]` — legacy bral surové `definition.bounds`, audit 2 FIX 6); testy so skrytým dieťaťom aj so skrytým VNUKOM vo viditeľnom
  kontajneri a so skrytým presahujúcim potomkom VYBRANÉHO objektu; hlásenia cez objekt rozšírenia enginu.
  **Upratanie starých inštalácií (FIX 7):** = **explicitná boot migrácia** v `main.rb` PRED registráciou toolbaru (pri aktualizácii vykonáva swap ešte starý kód, nový `updater.rb` beží až po reštarte):
  odstráni `noxun_mower_loader.rb`, `Noxun_Mower\`, `snaper.rb`, `snaper\` v Plugins; marker žije MIMO swapovaného stromu (`%APPDATA%\NOXUN\Engine\legacy_cleanup.json`) a je **kľúčovaný normalizovanou cestou Plugins priečinka** (viac verzií SketchUpu = viac Plugins, každý sa uprace samostatne — kolo 3 P2); kľúč sa zapíše **AŽ po overenej neprítomnosti všetkých štyroch cieľov** (`!File.exist?`/`!Dir.exist?` po mazaní — `rm_f`/`rm_rf` chybu potláčajú, audit 2 FIX 5), inak sa
  NEoznačí ako hotové (zopakuje sa nabudúce) + hláška; test s dvoma dočasnými Plugins koreňmi nad jedným app-data a test „mazanie vrátilo bez výnimky, ale cesta ostala"; inštalátor má rovnakú
  postkontrolu pred hláškou o upratanií a **po tejto dávke vypíše LEN „Reštartuj SketchUp"** (audit 3 FIX 3: živý `load "noxun_engine.rb"` legacy toolbary neodregistruje a už načítaný
  loader/`main.rb` registráciu preskočí cez `@loaded`/`file_loaded?`); pri zlyhanej postkontrole legacy cieľov NIE „HOTOVO", ale varovanie s cestami; inštalátor `INSTALL_noxun_engine.ps1` maže tie isté cesty. Zdroj nástrojov sa presunie do repa; pôvodné priečinky workspace ostanú ako archív. Referenčné kópie legacy zdrojov (nenačítavané, Codex #288 kolo 2): `SYSTEM/zdroje/archiv_kod/legacy_noxun_mower.rb.txt`, `legacy_snaper_main.rb.txt`,
  `legacy_snaper_snap.rb.txt`. **Ikony (kolo 3 P2):** 7 PNG ikon Mowera a 2 SVG Snapera sa presunú do repa do `noxun_engine/ui/icons/tools/` (sledované assety, žiadna závislosť na workspace).
  **Headless (FIX 8):** čisté jadrá (`*_calc.rb`) sú v zozname `tests/helper.rb`; UI registrácia je oddelená a guardovaná (`defined?(UI::Toolbar)`), takže sa bez SketchUpu nenačíta.
  **Scope OUT:** tlačidlo „Vložiť kópiu" v toolbare (Michal: nie) · nové funkcie nástrojov · zarovnanie výšky/hĺbky k susedovi (bod 1B) · Noxun_Pick/V2fable vkladanie · KOVANIE (starý) a
  vepo_exporter (odstavia sa samostatne) · kópia dosky (GHOST-D1).
  **Testy a DoD:** headless — vektor posunu (mm→palce, lokálna os, obálka korpusu), prípona názvu (opakovaná kópia toho istého zdroja, existujúce a/b, prechod po z, 80-znakový názov), zoznam legacy
  súborov + marker (zlyhanie = nehotové), výber cesty NOXUN/DC/iné/vnorený/edit-context, Snaper viditeľnosť (skryté dieťa); **in-SU sekcia `run_tools1`** — kópia vľavo/vpravo NOXUN skrinky = nová
  inštancia s VLASTNOU definíciou a novým CAB id, `Panel` payload ju vidí, kusovník má o skrinku viac, 1 krok Späť ju odstráni; kópia rotovanej skrinky (90°) = obálky korpusov susedia (X-rozsah), aj pri
  čele so záporným `gap_sides`; názov a → b; ad-hoc položky rekeyed; R-12 odmietnutá bez zmeny modelu; repro FIX 2 (rotácia → kópia → Späť); rotácie/Z = 1 krok Späť, žiadna prestavba; vnorený korpus
  a otvorený edit context = hláška, 0 krokov Späť; Snaper: prisunutie k susedovi (medzera 0), bez prekážky blokované, skrytá prekážka neblokuje; DC komponent → stará cesta; boot migrácia: legacy
  súbory v dočasnom Plugins strome zmiznú, marker zapísaný, po zlyhaní nezapísaný. Mutácie min. 4 (kópia cez `add_instance` · holé mm v transformácii · prípona bez hľadania voľnej · marker zapísaný pri zlyhaní).
  **Riziká:** kolízia namespace pri neodstránenej starej inštalácii (preto upratanie v OBOCH kanáloch) · rozsah (rez T1a presun + toolbar + kópia / T1b boot migrácia + inštalátor).
  **Smoke pre Michala:** po inštalácii jeden toolbar „Noxun Nástroje", staré toolbary Mower/Snaper preč · označ skrinku → Kópia vpravo → nová skrinka vedľa, Inspector ju otvorí, v kusovníku
  pribudla, Ctrl+Z ju odstráni · pomenovaná skrinka → kópia „… a", ďalšia „… b" · rotuj 90° a skopíruj → korpusy susedia · Snaper prisunie k susedovi · Z = 0 a Z posun ako doteraz · vnútri otvoreného
  komponentu nástroj odmietne s hláškou.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → nový odsek `tools` v `docs/architecture/ui-lifecycle.md` + riadok rozcestníka `docs/ARCHITEKTURA.md` (guard) → README
  (inštalácia, upratanie starých pluginov) → D-20 do DOGFOODING_vyriesene (plný text + riadok indexu) → STAV/KRONIKA/PLAN.

## Codex GH kolo 3 (#288, 4.9.2026) — nálezy ZAPRACOVANÉ v texte vyššie (kde: „kolo 3 P1/P2")

1. **P1 — mutácie nástrojov pod `ScaleWatch.guard`:** rotácia/Z/snap nad NOXUN korpusom bez guardu zaradí korpus do fronty `notify_change`; `Zones.sync_ghost` v tej istej operácii frontu nevyčistí, takže
   odložený `process_dirty` aj tak commitne transparentný `move_ghost_op` a môže sa prilepiť k nasledujúcej kópii (presne rasa, ktorú má dávka riešiť). Celá mutácia + sync ghost zón musí bežať pod
   existujúcim guardom; test rotácia → kópia musí padnúť, ak vo fronte ostane dirty udalosť.
2. **P2 — `ScaleWatch.remember_transform` po každej guardovanej zmene polohy:** pod guardom observer nedosiahne `remember_transform`, cache drží polohu spred príkazu; neskôr odmietnutá mierka
   (`reject_scale`) by obnovila starú polohu a ticho zrušila rotáciu/posun. Volať `remember_transform` po každom úspešnom commite nástroja; test: posun nástrojom → odmietnutá (šikmá) mierka.
3. **P1 — Z-posun dialog počas update:** guard 9 príkazov nekryje samostatný callback `applyZ` otvoreného HtmlDialogu; bariéra updatera zatvára a čaká len na Inspector a Štúdio. Dialog zaradiť do
   close/wait životného cyklu updatera ALEBO guardovať callback cez `Engine.update_locked?` a po zatvorení uvoľniť referenciu; test update pri otvorenom Z dialogu.
4. **P2 — marker upratania per Plugins priečinok:** viac verzií SketchUpu = viac Plugins priečinkov, zdieľaný marker v `%APPDATA%NOXUNEngine` by druhú verziu neupratal. Kľúčovať marker
   normalizovanou cestou Plugins / verziou SketchUpu (alebo legacy cesty kontrolovať pri každom boote); test s dvoma dočasnými Plugins koreňmi nad jedným app-data.
5. **P2 — viditeľné bounds kontajnera rekurzívne:** jednoúrovňový výpočet z viditeľných detí stále berie bežné bounds vnoreného kontajnera so skrytou geometriou; odvodiť bounds rekurzívne cez tú
   istú visibility-aware traverzu (alebo brať len viditeľné listy) a testovať skryté VNUKA, nie len dieťa.
6. **P2 — ikony toolbaru v repe:** legacy Mower odkazuje 7 PNG ikon a Snaper 2 SVG; po zmazaní samostatných priečinkov by čistý checkout nemal zdroj ikon. Pridať referenčné kópie/asset súbory
   (cieľ `noxun_engine/ui/icons/tools/`), alebo určiť náhrady zo sprite enginu.


## Codex CLI audit 2 (4.9.2026, `task-mtmxiufz-ln805y`) — ZAPRACOVANÉ (kde: „audit 2")

1. **BLOCKER** — synchrónny flush neexistoval: nové API `ScaleWatch.flush_pending!(model)` (timer stop + generácia + fronty) pred KAŽDOU polohovou mutáciou, aj pri obyčajnom Move.
2. **FIX** — rotácia/Z/snap: pending scale absorbovať alebo odmietnuť; `remember_transform` až po overenej rigidite.
3. **FIX** — `Panel.push_selected(model, dedup: false)` po kópii.
4. **FIX** — latch API: `Engine.update_restart_pending?` pre príkazy, `Engine.update_locked?(:tools_z)` pre callback; Z-dialog v troch zoznamoch bariéry + `set_on_closed`.
5. **FIX** — marker upratania až po overenej neprítomnosti všetkých cieľov (aj inštalátor).
6. **FIX** — visibility-aware bounds aj pre cieľ Snapera.
7. **NOTE** — trojstav toolbaru výslovne (`get_last_state`), `install_toolbar` len ako vzor referencie/idempotencie.


## Codex CLI audit 3 (4.9.2026, `task-mtmy3qre-v8zlp6`) — ZAPRACOVANÉ (kde: „audit 3")

1. **BLOCKER** — `flush_pending!` = bariéra do pokoja (opakované spracovanie so stropom, žiadny naplánovaný timer, prázdne fronty; inak odmietnutie), multi-model a `@prune_models` zachované.
2. **FIX** — rigidita vynútená na hranici cache observera (`rigid_matrix?` v `remember_transform`/`attach_one`, `reject_scale` nerigidné nepotvrdí; test šmyku).
3. **FIX** — inštalátor po uprataní: len „Reštartuj SketchUp", žiadny živý `load`; zlyhaná postkontrola = varovanie, nie „HOTOVO".


## Codex CLI audit 4 (4.9.2026, `task-mtmymlug-koyl06`) — ZAPRACOVANÉ (kde: „audit 4")

1. **BLOCKER** — follow-up práca bariéry musí znovu zaradiť konkrétny model do per-model fronty `@requested` (nie `@last_model`); pokoj = prázdne fronty všetkých modelov; test s dvoma dokumentmi.
