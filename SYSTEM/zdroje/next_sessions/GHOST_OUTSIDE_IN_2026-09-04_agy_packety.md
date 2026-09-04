# GHOST outside-in — surové Antigravity packety (4.9.2026 večer)
> Stav: KONCEPT — surový research výstup (Gemini 3.8 Flash, 4 behy); rozhodnutia sú v reconcile tabuľke v `GHOST_OUTSIDE_IN_2026-09-04.md`, nie tu.

Prompty: hlavička (rola, HARD RULES, formát) + výsek draftu D1/D2 (r. 7–47) + 1–2 cielené otázky na beh. Prvý beh `life` skončil prázdny (agent skúsil `command` tool → headless auto-deny) — nižšie je opakovaný beh s pravidlom „no shell".


---

# Prior-Art Audit: GHOST-D1/D2 — vcb | 2026-09-04 | Gemini 3.8 Flash

| Kategória | Tvrdenie (1 veta) | Dôkaz (URL + verzia/dátum) | Overenie (VERIFIED/UNVERIFIED + probe snippet) | Dotknutá časť package | Odporúčanie (1 veta) | Prácnosť S/M/L | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SIMPLER NATIVE PATH** | Pri stlačení klávesu Enter s prázdnym VCB sa `onUserText` vôbec nevolá a SketchUp doručí udalosť priamo do callbacku `onReturn(view)`. | [Sketchup::Tool#onReturn](https://ruby.sketchup.com/Sketchup/Tool.html#onReturn-instance_method) (SketchUp 6.0) | VERIFIED: `class T; def enableVCB?; true; end; def onReturn(v); puts :EMPTY_ENTER; end; def onUserText(t,v); puts t; end; end; Sketchup.active_model.select_tool(T.new)` | GHOST-D2 (prázdny Enter pre prevzatie hodnoty z karty) | Prevzatie hodnoty z karty vo fáze implementujte priamo v callbacku `onReturn(view)` namiesto očakávania prázdneho reťazca v `onUserText`. | S | proprietary |
| **MISSED CONSTRAINT** | Konštanta `VK_RETURN` v mennom priestore SketchUp API neexistuje (kód klávesu je `13`) a v `Sketchup 2026.1` bola opravená regresia z 2026.0 na Windows, kde `onKeyDown` pri Enter vôbec netrigroval. | [SketchUp Release Notes](https://ruby.sketchup.com/file.ReleaseNotes.html) (SU 2026.1) a [Top Level Namespace](https://ruby.sketchup.com/top-level-namespace.html) (SU 6.0) | VERIFIED: `[defined?(VK_RETURN), Sketchup.version]` # vracia [nil, "26.1..."] | GHOST-D2 (`onKeyDown` odchytávanie klávesu Enter) | Nespoliehajte sa na symbol `VK_RETURN` v `onKeyDown`, ale použite natívny `onReturn(view)`, prípadne priamy kód `key == 13`. | S | proprietary |
| **MISSED CONSTRAINT** | Metóda `String#to_l` na slovenskom Windows zlyhá (`ArgumentError`) pri zadaní desatinnej bodky namiesto čiarky a bez explicitnej jednotky preberá globálnu šablónu modelu (napr. palce). | [String#to_l](https://ruby.sketchup.com/String.html#to_l-instance_method) (SU 6.0) a [Sketchup::RegionalSettings](https://ruby.sketchup.com/Sketchup/RegionalSettings.html) (SU 2016 M1) | VERIFIED: `begin; "600.5".to_l; rescue ArgumentError => e; [e.message, Sketchup::RegionalSettings.decimal_separator]; end` | GHOST-D2 (parsovanie rozmerov dosky) | Vyhnite sa volaniu `String#to_l` na surový používateľský vstup a zabezpečte striktnú normalizáciu na milimetre nezávisle od nastavenia šablóny modelu. | S | proprietary |
| **GOOD CUSTOM SOLUTION** | Prísny interný regulárny výraz normalizujúci bodku aj čiarku a fixujúci milimetre spoľahlivo izoluje výrobnú logiku nábytku od chýb lokality a modelových jednotiek. | [Sketchup::RegionalSettings](https://ruby.sketchup.com/Sketchup/RegionalSettings.html) (SU 2016 M1) | VERIFIED: `m = " 600,5 mm ".strip.match(/\A(\d+(?:[.,]\d+)?)\s*(?:mm)?\z/i); val = m ? m[1].tr(',', '.').to_f : nil` | GHOST-D2 (validácia VCB čísla a `BoardBuilder::LIMITS`) | Ponechajte navrhnutý vlastný parser, no doplňte `strip`, case-insensitive príznak `/i` pre `MM` a toleranciu okolitých medzier `\A\s*...\s*\z`. | S | proprietary |
| **CAD PRECEDENT** | Oficiálny Trimble príklad `99_sphere_tool` demonštruje bezpečné zachytenie VCB cez `begin/rescue ArgumentError` a parametrické vetvy prípon bez pádu nástroja. | [sketchup-ruby-api-tutorials/99_sphere_tool](https://raw.githubusercontent.com/SketchUp/sketchup-ruby-api-tutorials/main/examples/99_sphere_tool/ex_sphere_tool/main.rb) (Trimble 2018) | VERIFIED: `text = "24s"; text.end_with?('s') ? text.to_i : (begin; text.to_l; rescue ArgumentError; UI.beep; end)` | GHOST-D2 (spätná väzba a error state VCB) | Prevezmite vzor `UI.beep` a ponechanie fázy s chybovým stavom v stavovom riadku pri neplatnom formáte alebo prekročení `BoardBuilder::LIMITS`. | S | MIT |

### Nenašiel som (RESEARCH GAP)
1. Samostatnú open-source knižnicu pre SketchUp Ruby API nahrádzajúcu `to_l` komplexným matematickým VCB parserom (rozšírenia v ekosystéme využívajú buď priamy `to_l` s `rescue`, alebo jednoúčelové inline regexy).

### Zdroje
1. [Sketchup::Tool#onReturn](https://ruby.sketchup.com/Sketchup/Tool.html#onReturn-instance_method)
2. [Sketchup::Tool#onUserText](https://ruby.sketchup.com/Sketchup/Tool.html#onUserText-instance_method)
3. [Sketchup::Tool#onKeyDown](https://ruby.sketchup.com/Sketchup/Tool.html#onKeyDown-instance_method)
4. [SketchUp Ruby API Release Notes](https://ruby.sketchup.com/file.ReleaseNotes.html)
5. [Top Level Namespace Constants](https://ruby.sketchup.com/top-level-namespace.html)
6. [Sketchup::RegionalSettings](https://ruby.sketchup.com/Sketchup/RegionalSettings.html)
7. [String#to_l](https://ruby.sketchup.com/String.html#to_l-instance_method)
8. [SketchUp Ruby API Tutorials: 99_sphere_tool](https://raw.githubusercontent.com/SketchUp/sketchup-ruby-api-tutorials/main/examples/99_sphere_tool/ex_sphere_tool/main.rb)


---

# Prior-Art Audit: GHOST-D1/D2 — infer | 2026-09-04 | Gemini 3.8 Flash

| Kategória | Tvrdenie (1 veta) | Dôkaz (URL + verzia/dátum) | Overenie (VERIFIED/UNVERIFIED + probe snippet) | Dotknutá časť package | Odporúčanie (1 veta) | Prácnosť S/M/L | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **ALREADY EXISTS** | `InputPoint#pick(view, x, y, inputpoint2)` natívne počíta relatívne inferencie voči referenčnému bodu vrátane prichytenia na osi (on-axis from point). | [InputPoint#pick](https://ruby.sketchup.com/Sketchup/InputPoint.html#pick-instance_method) (SU Ruby API, 2026) | VERIFIED: `v = Sketchup.active_model.active_view; ip1 = Sketchup::InputPoint.new(ORIGIN); ip2 = Sketchup::InputPoint.new; ip2.pick(v, 100, 100, ip1); puts ip2.degrees_of_freedom` | GHOST-D2 (ťahy dĺžky a šírky) | Do `pick` v 2. a 3. fáze odovzdávať `InputPoint` predchádzajúceho bodu pre automatické prichytenie na osi a geometriu. | S | N/A |
| **MISSED CONSTRAINT** | `View#lock_inference(ip1, ip2)` uzamkne len globálne osi alebo existujúce natívne väzby, nedokáže uzamknúť ľubovoľný lokálny vektor nástroja; štandardným vzorom pre lokálnu os je manuálna projekcia. | [View#lock_inference](https://ruby.sketchup.com/Sketchup/View.html#lock_inference-instance_method) a [Point3d#project_to_line](https://ruby.sketchup.com/Geom/Point3d.html#project_to_line-instance_method) (SU Ruby API, 2026) | VERIFIED: `pt = Geom::Point3d.new(100, 50, 0); line = [ORIGIN, Geom::Vector3d.new(1, 1, 0)]; proj = pt.project_to_line(line); puts proj` | GHOST-D2 (ťahy podľa lokálnych osí dosky/korpusu) | Pre lokálne osi otočených dielov nespoliehať na `lock_inference`, ale premietať bod kurzora priamo na priamku cez `ip.position.project_to_line([pt0, axis_vec])`. | S | N/A |
| **CAD PRECEDENT** | Knižnica `Eneroth3/inference-lock-lib` implementuje vzor pre korektné zachytávanie klávesov Shift a šípok na uzamykanie inferencií v custom `Tool` podľa vzoru natívnych nástrojov. | [Eneroth3/inference-lock-lib](https://github.com/Eneroth3/inference-lock-lib) (v1.0.0, 2019-11) | VERIFIED: `require 'ene_inference_lock'; # mixin Eneroth::InferenceLock handles onKeyDown/onKeyUp calling view.lock_inference` | GHOST-D2 (ovládanie zámkov osí klávesmi) | Prevziať vzor spracovania klávesových udalostí pre globálne osi a doplniť vlastný prepínač projekcie pre lokálne osi. | S | MIT |
| **NO ACTION** | `Sketchup::Snap` (zavedený v SU 2025.0 API) je perzistentná entita úchopu vnútri `Entities` pre natívny Move tool a NIE JE jednoduchšou cestou pre `GhostTool`. | [Sketchup::Snap](https://ruby.sketchup.com/Sketchup/Snap.html) a [Entities#add_snap](https://ruby.sketchup.com/Sketchup/Entities.html#add_snap-instance_method) (SU Ruby API 2025.0/2026) | VERIFIED: `puts defined?(Sketchup::Snap) ? Sketchup::Snap.instance_methods(false).sort : :missing` | GHOST-D1 (umiestnenie dosky a prichytenie na skrinky) | Ponechať virtuálnu obálku `GhostTool` bez mutácie modelu pred klikom (pravidlo R-03), keďže `Snap` vyžaduje vopred vytvorené entity v definícii a neponúka lifecycle pre custom tool. | S | N/A |

### Nenašiel som (RESEARCH GAP)
1. Nič (všetky cielené otázky k `InputPoint#pick`, limitom `View#lock_inference`, vzorom lokálnych osí a runtime povahe `Sketchup::Snap` boli overené v oficiálnej dokumentácii a open-source repozitároch).

### Zdroje
1. https://ruby.sketchup.com/Sketchup/InputPoint.html#pick-instance_method
2. https://ruby.sketchup.com/Sketchup/View.html#lock_inference-instance_method
3. https://ruby.sketchup.com/Geom/Point3d.html#project_to_line-instance_method
4. https://github.com/Eneroth3/inference-lock-lib
5. https://ruby.sketchup.com/Sketchup/Snap.html
6. https://ruby.sketchup.com/Sketchup/Entities.html#add_snap-instance_method


---

# Prior-Art Audit: GHOST-D1/D2 — prec | 2026-09-04 | Gemini 3.8 Flash

| Kategória | Tvrdenie (1 veta) | Dôkaz (URL + verzia/dátum) | Overenie (VERIFIED/UNVERIFIED + probe snippet) | Dotknutá časť package | Odporúčanie (1 veta) | Prácnosť S/M/L | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **CAD PRECEDENT** | Natívny nástroj Rotated Rectangle používa fázové zadávanie rozmerov do VCB (jedno číslo na fázu: dĺžka, potom šírka) s náhľadom, zatiaľ čo s4u Panel generuje dosky z bodov s hrúbkou z predvoľby. | [Trimble Drawing Shapes](https://help.sketchup.com/en/sketchup/drawing-basic-shapes) (2024/2026); [s4u Panel](https://extensions.sketchup.com/extension/39f99fc0-2051-4db8-8427-bc97e59b3d04/s4u-panel) (v3.x, 2024) | VERIFIED<br><code>Sketchup.set_status_text("Dĺžka: mm", SB_VCB_LABEL)</code> | GHOST-D2 (VCB jedno číslo na fázu, ťah dĺžky a šírky) | Prevziať vzor Rotated Rectangle pre sekvenčný VCB vstup dĺžky a šírky namiesto natívneho zápisu `dĺžka;šírka`. | S | Proprietary (Trimble / Sufull) |
| **CAD PRECEDENT** | OpenCutList v7.0.0 priniesol Smart Draw Tool na ťahanie objemových dielcov/dosiek z materiálových šablón s náhľadom obálky. | [OpenCutList GitHub](https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension) (v7.0.0, 2025-09-17); [Docs](https://docs.opencutlist.org/) | VERIFIED<br><code>defined?(Ladb::OpenCutList)</code> | GHOST-D2 (obálka dosky, materiálová hrúbka) | Inšpirovať sa kreslením obálky z materiálu, no kód nekopírovať kvôli licencii GPL. | M | GPL-3.0 |
| **CAD PRECEDENT** | Polyboard generuje dosky výhradne ako výplne zón korpusu, kým SketchList 3D definuje dosku voľbou orientácie (Horizontal / Vertical / Front-to-Back) a rozmermi s pevnou hrúbkou. | [SketchList 3D](https://sketchlist.com/) (2024/2026); [Polyboard](https://boole.eu/polyboard/) (v7, 2024) | VERIFIED<br><code>[:leziaca, :stojaca, :na_stenu]</code> | GHOST-D1 / D2 (orientácia dosky) | Ponechať 3 diskrétne stavy orientácie, plne zodpovedajú zaužívanému štandardu zo SketchList 3D. | S | Proprietary |
| **MISSED CONSTRAINT** | `Sketchup::Tool#onKeyDown` zachytí šípky a vrátením `true` ich pohltí, no privlastnenie ↑/↓ a ←/→ v GHOST-D2 zabráni používateľovi využívať natívne zamykanie osí (Up=Blue, Right=Red, Left=Green od SU 2016). | [Tool#onKeyDown](https://ruby.sketchup.com/Sketchup/Tool.html#onKeyDown-instance_method) (API 2026); [Drawing Basics](https://help.sketchup.com/en/sketchup/introducing-drawing-basics-and-concepts) (2024/2026) | VERIFIED<br><code>class P < Sketchup::Tool<br>def onKeyDown(k,r,f,v)<br>puts "Key:#{k}"; k == VK_UP<br>end<br>end; Sketchup.active_model.select_tool(P.new)</code> | GHOST-D1 / GHOST-D2 (klávesy ↑/↓ a ←/→) | Ponechať šípky pre zamykanie smerov (`view.lock_inference`) a cyklovanie orientácie presunúť na kláves `Tab` (vzor s4u Panel) a rotáciu na `R` alebo koliesko myši. | S | Proprietary (Trimble API) |
| **GOOD CUSTOM SOLUTION** | Žiadne existujúce SketchUp rozšírenie neposkytuje živý ghost dosky na kurzore s okamžitým prepínaním 3 orientácií počas umiestňovania bez dialógového okna. | Extension Warehouse & SketchUcation (2026-09-04) | VERIFIED<br><code>%w[leziaca stojaca na_stenu]</code> | GHOST-D1 / D2 (ghost na kurzore) | Zachovať navrhnutý stavový automat orientácie pri umiestňovaní ako unikátnu výhodu Noxun Engine. | M | Vlastná (Noxun Engine) |

### Nenašiel som (RESEARCH GAP)
1. Žiadne SketchUp rozšírenie nekombinuje interaktívny ghost dosky na kurzore s priamym prepínaním 3 orientácií (`leziaca` / `stojaca` / `na_stenu`) počas pohybu myši bez otvorenia dialógového okna.

### Zdroje
1. https://ruby.sketchup.com/Sketchup/Tool.html#onKeyDown-instance_method
2. https://help.sketchup.com/en/sketchup/introducing-drawing-basics-and-concepts
3. https://help.sketchup.com/en/sketchup/drawing-basic-shapes
4. https://github.com/lairdubois/lairdubois-opencutlist-sketchup-extension
5. https://docs.opencutlist.org/
6. https://extensions.sketchup.com/extension/39f99fc0-2051-4db8-8427-bc97e59b3d04/s4u-panel
7. https://sketchlist.com/
8. https://boole.eu/polyboard/


---

# Prior-Art Audit: GHOST-D1/D2 — life | 2026-09-04 | Gemini 3.8 Flash

| Kategória | Tvrdenie (1 veta) | Dôkaz (URL + verzia/dátum) | Overenie (VERIFIED/UNVERIFIED + probe snippet) | Dotknutá časť package | Odporúčanie (1 veta) | Prácnosť S/M/L | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **MISSED CONSTRAINT** | Kreslenie náhľadu cez `Tool#draw` vyžaduje implementáciu `Tool#getExtents` s `Geom::BoundingBox` dosky, inak kamera v prázdnom modeli či mimo existujúcej geometrie náhľad oreže (clipping), pričom na prekreslenie patrí neblokujúce `View#invalidate` namiesto blokujúceho `View#refresh`. | `https://ruby.sketchup.com/Sketchup/Tool.html#getExtents-instance_method` (SU 6.0), `https://ruby.sketchup.com/Sketchup/View.html#invalidate-instance_method` (SU 6.0) | VERIFIED<br>`v=Sketchup.active_model.active_view; bb=Geom::BoundingBox.new.add([0,0,0],[1.m,1.m,1.m]); v.invalidate` | GHOST-D1/D2 (`GhostTool#draw`, `#onMouseMove`) | Implementovať `getExtents` vracajúci obálku ghost dosky a v `onMouseMove` volať výhradne `view.invalidate`. | S | proprietary |
| **MISSED CONSTRAINT** | Od SketchUp 2025.0 pracujú vstupy a výstupy obrazovky v logických pixeloch (`onMouseMove` x/y, `View#draw2d`, `vpwidth`/`vpheight`, `screen_coords`, `pickray` vstupné x/y, `PickHelper`, `InputPoint#pick`), zatiaľ čo 3D kreslenie (`View#draw`), návratový lúč (`pickray` bod/vektor) a `InputPoint#position` striktne zachovávajú modelové jednotky. | `https://ruby.sketchup.com/file.ReleaseNotes.html` (SketchUp 2025.0 Release Notes, 2025-04) | VERIFIED<br>`v=Sketchup.active_model.active_view; puts "vp=#{v.vpwidth.class} scale=#{UI.scale_factor(v)}"; ray=v.pickray(10,10); puts "ray=#{ray[0].class}"` | GHOST-D1/D2 (kurzor, PickHelper, InputPoint, kótovanie v `draw2d`) | Neškálovať súradnice myši vlastným DPI faktorom, predávať ich priamo ako logické pixely a 3D geometriu kresliť v modelových jednotkách. | S | proprietary |
| **MISSED CONSTRAINT** | Metóda `Tool#onCancel` dokumentuje kódy dôvodu 0 (Esc), 1 (opätovný výber nástroja) a 2 (používateľ stlačil Undo/Ctrl+Z pred jeho vykonaním), pričom pri kóde 2 musí nástroj resetovať ghost session bez volania ďalších modelových zmien, aby Undo stack ostal čistý. | `https://ruby.sketchup.com/Sketchup/Tool.html#onCancel-instance_method` (SU 6.0) | VERIFIED<br>`t=Class.new{def onCancel(r,v); puts "Cancel reason: #{r}"; end}; Sketchup.active_model.select_tool(t.new)` | GHOST-D1/D2 (`PlacementSession` reset pri Esc a Undo) | V `onCancel` ošetriť dôvody 0 aj 2 okamžitým resetom session a zmazaním náhľadu, čím sa pri Ctrl+Z zachová presne pôvodný model s 0 krokmi navyše. | S | proprietary |
| **NO ACTION** | Trieda `Sketchup::Overlay` je pasívna vrstva bez vstupu (nemá eventy myši ani klávesnice), nesmie zlyhať a modifikácia modelu počas kreslenia vyvolá `RuntimeError`, preto nemôže nahradiť interaktívny `Sketchup::Tool` s `PickHelper`/`InputPoint`. | `https://ruby.sketchup.com/Sketchup/Overlay.html` (SU 2023.0) | VERIFIED<br>`puts "Overlay: #{defined?(Sketchup::Overlay)}"; puts "overlays: #{Sketchup.active_model.respond_to?(:overlays)}"` | GHOST-D1/D2 (architektonická voľba nástroja) | Ponechať návrh postavený na `Sketchup::Tool` s `InputPoint`/`PickHelper` a nepokúšať sa o ghost placement cez `Overlay`. | S | proprietary |
| **MISSED CONSTRAINT** | Pre garantovaný 1 krok Späť pri commite v `onLButtonDown` musí byť volané `start_operation` s `transparent=false`, `disable_ui=true` (rýchlosť), bez vnorených operácií a s povinným ošetrením v `begin..rescue` s volaním `abort_operation`. | `https://ruby.sketchup.com/Sketchup/Model.html#start_operation-instance_method` (SU 6.0) | VERIFIED<br>`m=Sketchup.active_model; m.start_operation("T", true, false, false); m.commit_operation; puts "undo=#{m.undo}"` | GHOST-D1/D2 (`commit_insert` v `onLButtonDown`) | Zabaliť commit do explicitného bloku `start_operation("Vložiť dosku", true, false, false)` a v `rescue` vetve volať `model.abort_operation`. | S | proprietary |
| **CAD PRECEDENT** | Oficiálny referenčný balík Trimble `sketchup-ruby-api-tutorials` (`02_custom_tool`) demonštruje kanonický vzor implementácie nástroja s `getExtents`, `draw`, `InputPoint#pick` v `onMouseMove` a čistým `onCancel` resetom. | `https://github.com/SketchUp/sketchup-ruby-api-tutorials/tree/main/examples/02_custom_tool` (Trimble, 2016–2024) | VERIFIED<br>`# Reference: SketchUp/sketchup-ruby-api-tutorials (examples/02_custom_tool/custom_tool.rb)` | GHOST-D1/D2 (kostra triedy `GhostTool`) | Prevziať štruktúru Tool lifecycle metód a `InputPoint` workflow z oficiálneho Trimble MIT tutoriálu. | S | MIT |

### Nenašiel som (RESEARCH GAP)
1. nič

### Zdroje
1. https://ruby.sketchup.com/Sketchup/Tool.html
2. https://ruby.sketchup.com/Sketchup/View.html
3. https://ruby.sketchup.com/file.ReleaseNotes.html
4. https://ruby.sketchup.com/Sketchup/Overlay.html
5. https://ruby.sketchup.com/Sketchup/Model.html#start_operation-instance_method
6. https://github.com/SketchUp/sketchup-ruby-api-tutorials/tree/main/examples/02_custom_tool

