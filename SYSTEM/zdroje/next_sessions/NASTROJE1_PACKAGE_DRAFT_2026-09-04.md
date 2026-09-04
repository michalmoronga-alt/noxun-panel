# NÁSTROJE-1 — DRAFT package (4.9.2026, po Codex CLI audite + GH kolách #288 1–3)

> Stav: KONCEPT — nezáväzný podklad (draft package); do PLANu sa vráti až po zapracovaní nálezov kola 3 (nižšie) a novom Codex CLI audite draftu, nie priamo do implementácie.

> Rozhodnutia Michala 4.9.: jeden balík, spoločný toolbar „Noxun Nástroje", UI nástrojov nemeniť, kópia cez engine, názov kópie s písmenovou príponou, tlačidlo „Vložiť kópiu" NIE.
> Outside-in packet: [NASTROJE_OUTSIDE_IN_2026-09-04.md](NASTROJE_OUTSIDE_IN_2026-09-04.md). Referenčný kód: `../archiv_kod/legacy_*.rb.txt`.

- **NÁSTROJE-1 · TASK PACKAGE „MOWER + SNAPER V BALÍKU NOXUN ENGINE" (D-20; V1 bod 1A — Michal 4.9.2026; Audit: HOTOVÝ — Codex CLI 4.9. (1 BLOCKER + 9 FIX + 1 NOTE) + Codex GH #288, všetko zapracované nižšie; in-SU POVINNÉ):**
  **Cieľ:** jeden inštalačný balík — oba nástroje sa presunú ako moduly do `noxun_engine/tools/` (`mower.rb`, `snaper.rb` + ČISTÉ jadrá `mower_calc.rb`, `snap_calc.rb` bez `UI::*`; namespace
  `Noxun::Engine::Tools::*`), načíta ich `main.rb`, dostanú **jeden spoločný toolbar „Noxun Nástroje"** (poradie: −90° · +90° · 180° · Z = 0 · Z posun… · Kópia vľavo · Kópia vpravo · Prisunúť vľavo ·
  Prisunúť vpravo; slovenské tooltipy; menu Extensions → Noxun Engine → Nástroje). Vlastné registrácie rozšírení a `VERSION` nástrojov zaniknú — verziu aj update (D-52) preberá engine. **Prečo samostatný
  toolbar:** toolbar enginu má železné pravidlo „do modelu sa nezapisuje" (D-103/D-105); nástroje model menia. UI nástrojov sa inak NEMENÍ (Michal: „nechať im svoj svet").
  **Outside-in (CLAUDE.md pravidlo): HOTOVÝ 4.9.2026** — packet [zdroje/next_sessions/NASTROJE_OUTSIDE_IN_2026-09-04.md](zdroje/next_sessions/NASTROJE_OUTSIDE_IN_2026-09-04.md)
  (cez WebSearch/WebFetch oficiálnej API dokumentácie, agy kvóta vyčerpaná). Reconcile: `drawing_element_visible?` (od 2020.0) **hádže výnimku pred SU 2026.0, keď je posledný prvok cesty
  skupina/komponent** → volať pod `rescue` s fallbackom na `hidden?` + `layer.visible?` po celej ceste, test oboch vetiev · `transform_entities` interpretuje transformáciu globálne LEN v aktívnom
  kontexte a jeho rodičoch → nástroje výhradne v root kontexte · toolbar `show`/`restore` podľa `get_last_state` · natívne `Sketchup::Snap` (2025.0) = kandidát pre zostavy/GHOST, nie pre túto dávku.
  **Registrácia (audit FIX 9):** JEDEN idempotentný registrátor podľa vzoru `Engine.install_toolbar` (`@toolbar` procesná referencia, `file_loaded?` guard, jedna sada `UI::Command` zdieľaná menu aj
  toolbarom) — legacy `build_toolbar` pri load bez guardu sa NEprenáša. **Restart latch (FIX 3):** všetkých 9 príkazov ide cez ten istý guard ako toolbar enginu (`Updater` latch po swape = príkaz odmietne
  s hláškou). **Kontext (FIX 4, 5):** nástroje pracujú LEN v root kontexte a LEN s korpusom na root úrovni — otvorený edit komponentu alebo vnorený NOXUN korpus = hláška v statuse, žiadna operácia
  (legacy Mower počítal pivot v parent-relative rámci a rotoval po lokálnej Z; kópia vnoreného korpusu by skončila inde).
  **Kópia (Mower) — oprava fantómu:** dnes `add_instance` tej istej definície bez atribútov inštancie → kópia bez identity (Inspector ju nevidí, nie je v kusovníku, pri prestavbe originálu sa mení
  s ním). Pre NOXUN skrinku pôjde kópia **cestou „Vložiť kópiu"** (`Store.config` → `config_to_params` → `rekey_hardware_manual` → `CabinetBuilder.build(model, params, transform:
  src.transformation * Geom::Transformation.translation(Units.vector(±šírka_mm, 0, 0)))` — **mm → palce cez `Units` (audit BLOCKER 1), nikdy holé číslo**): vlastná definícia, nové sekvenčné CAB číslo,
  1 operácia = 1 Späť, výber = kópia, `push_selected`; brána R-12 `newer_config?` = kópia sa nevloží + hláška. Šírka kroku z configu (`width`) = **susednosť OBÁLOK KORPUSOV** (Codex #288: čelo so
  záporným `gap_sides` alebo úchytka smie presahovať šírku korpusu, takže sľub „dotyk bbox" neplatí — test meria X-rozsah korpusov, nie bbox); pri parametrickej skrinke odpadajú odhady osi a znamienka
  podľa uhla (kópia sedí po VLASTNEJ osi X pri akejkoľvek rotácii). **Názov kópie (FIX 10):** ručný názov + písmenová prípona: hľadá sa **najbližšia voľná** prípona v celom modeli (a, b, … z; po
  vyčerpaní číslo „ 27", „ 28"…), základ sa oreže tak, aby prípona vždy prežila `sanitize_name` (`NAME_MAX_LEN` 80); bez ručného názvu ostáva automatický. **Dosky (NOTE 11): SCOPE OUT** — `BoardBuilder.build`
  polohu neprijíma (šev príde s GHOST-D1); kópia dosky = hláška „zatiaľ nie". Nie-NOXUN objekty (staré DC komponenty): dnešná cesta (DC `lenx` / bounds, `add_instance`).
  **Undo a ghost zóny (FIX 2):** každý zápis nástroja nad NOXUN objektom (rotácia, Z, snap, kópia) vo SVOJEJ operácii zavolá existujúci sync ghost zón, ktorý inak spúšťa `ScaleWatch` po debounce —
  transparentná operácia observera sa tak nemôže prilepiť k ďalšiemu kroku používateľa. Povinný repro test: rotácia → okamžitá kópia (< debounce) → dobeh → Späť kópie vráti LEN kópiu, rotácia drží. **Scale race (Codex #288 kolo 2 P2):** ak `src.transformation` nie je rigidná (čakajúca zmena mierky v debounce okne), príkaz najprv synchrónne spustí TO ISTÉ spracovanie, ktoré robí
  `ScaleWatch` po debounce (mierka → config + prestavba), a číta transformáciu znova; ak ani potom nie je rigidná → kópia sa odmietne s hláškou (žiadny tichý neúspech). In-SU prípad: Scale → okamžitá Kópia.
  **Rotácie ±90/180, Z = 0, Z posun:** logika bez zmeny (pivot = stred bbox, svetová Z — v root kontexte); Z-posun dialog ostáva HtmlDialog (callbacky pred `show`).
  **Snaper (FIX 6):** AABB sweep v lokálnom rámci cieľa, WARN 10 m, BLOCK 20 m, kontajnery do hĺbky 8 — **efektívna viditeľnosť cez `Model#drawing_element_visible?`** (celá instance path + tag
  folder; pod `rescue` s fallbackom `hidden?`/`layer.visible?` — pred SU 2026.0 hádže výnimku pre kontajner na konci cesty, viď outside-in packet), bbox kontajnera sa počíta len z jeho VIDITEĽNÝCH detí (1 úroveň), test so skrytým dieťaťom vo viditeľnom kontajneri; hlásenia cez objekt rozšírenia enginu.
  **Upratanie starých inštalácií (FIX 7):** = **explicitná boot migrácia** v `main.rb` PRED registráciou toolbaru (pri aktualizácii vykonáva swap ešte starý kód, nový `updater.rb` beží až po reštarte):
  odstráni `noxun_mower_loader.rb`, `Noxun_Mower\`, `snaper.rb`, `snaper\` v Plugins; marker žije MIMO swapovaného stromu (`%APPDATA%\NOXUN\Engine\legacy_cleanup.json`), pri zlyhaní mazania sa
  NEoznačí ako hotové (zopakuje sa nabudúce) + hláška; inštalátor `INSTALL_noxun_engine.ps1` maže tie isté cesty. Zdroj nástrojov sa presunie do repa; pôvodné priečinky workspace ostanú ako archív. Referenčné kópie legacy zdrojov (nenačítavané, Codex #288 kolo 2): `SYSTEM/zdroje/archiv_kod/legacy_noxun_mower.rb.txt`, `legacy_snaper_main.rb.txt`,
  `legacy_snaper_snap.rb.txt`.
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

## Codex GH kolo 3 (#288, 4.9.2026) — nálezy NA ZAPRACOVANIE pred návratom do PLANu

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
