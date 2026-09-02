# Antigravity OUTSIDE-IN sweep existujúcej architektúry (3.9.2026)

> Stav: KONCEPT / research packet + reconcile — jednorazový prior-art sweep 8 subsystémov pluginu (agy `gemini-3.7-flash-high`, `--mode plan`, ~10 min). Nič z toho nie je zadanie; kandidáti idú do AUDIT_REGISTER alebo zásobníka.

## Packet (výstup agenta, nezmenený)

### Prior-Art Audit Report: Noxun Engine
**Dátum:** 2026-09-02 | **Model:** Gemini 3.7 Flash

| Subsystém | Kategória | Tvrdenie | Dôkaz (URL + verzia) | Overenie + snippet | Odporúčanie | Prácnosť | Licencia |
| :--- | :--- | :--- | :--- | :--- | :--- | :---: | :--- |
| **S1 Ghost Tool** | `GOOD CUSTOM SOLUTION` | `Model#place_component` neumožňuje translucent preview, Alt kotvy ani Undo zapuzdrenie. `InputPoint` a `lock_inference` natívne riešia snapping. `onMouseMove` nemá throttle. | [Sketchup::View#lock_inference](https://ruby.sketchup.com/Sketchup/View.html#lock_inference-instance_method) (SU 2017+) | VERIFIED `ip=Sketchup::InputPoint.new; ip.pick(view,x,y); view.lock_inference(ip) if ip.valid?` | Ponechať custom `Tool`; využiť `InputPoint#pick` + `lock_inference`; nepreťažovať `onMouseMove`. | S | N/A (Trimble API) |
| **S2 Settings Store** | `GOOD CUSTOM SOLUTION` | `Sketchup.write_default` zapisuje do `PrivatePreferences.json` bez zámkov; pri dvoch oknách SU dochádza k prepísaniu súboru. Nevhodné pre multi-KB JSON. | [Sketchup.write_default](https://ruby.sketchup.com/Sketchup.html#write_default-class_method) (SU 6.0+) | VERIFIED `Sketchup.write_default("NOXUN","k",'{"v":1}'); v=Sketchup.read_default("NOXUN","k","{}")` | Ponechať vlastné JSON úložisko v %APPDATA% s file lockom a atomickým swapom. | S | N/A |
| **S3 Model Data** | `GOOD CUSTOM SOLUTION` | `persistent_id` (SU 2017+) sa pri kopírovaní mení, ale `AttributeDictionary` sa duplikuje (detekcia kópií). Zákaz volania `start_operation` priamo v observeroch. | [Sketchup::ModelObserver](https://ruby.sketchup.com/Sketchup/ModelObserver.html) (SU 2016+) | VERIFIED `pid=inst.persistent_id; stored=inst.get_attribute("NOXUN","id"); is_copy=(stored && stored!=pid)` | Ponechať JSON v slovníku; mutácie modelu z observerov striktne odkladať cez `UI.start_timer(0, false)`. | S | N/A |
| **S4 Overlays** | `GOOD CUSTOM SOLUTION` | `Sketchup::Overlay` (SU 2023.0+) spravuje viac vrstiev cez `OverlaysManager`. `draw` beží pri každom snímku; nesmie meniť model (`RuntimeError`); vyžaduje dirty tracking. | [Sketchup::Overlay](https://ruby.sketchup.com/Sketchup/Overlay.html) (SU 2023.0+) | VERIFIED `class Ov<Sketchup::Overlay; def draw(v); v.line_stipple="-"; end; end; Sketchup.active_model.overlays.add(Ov.new("n.g","G"))` | Ponechať 3 samostatné Overlays s dirty trackingom cez observere a lazy scanom. | S | N/A |
| **S5 HtmlDialog Bridge** | `GOOD CUSTOM SOLUTION` | `UI::HtmlDialog` (CEF v118+) nemá API prepínač na zákaz cacheovania assetov (query string cache-bust je nutný). `preferences_key` ukladá pozíciu; callbacky registrovať pred `show`. | [UI::HtmlDialog](https://ruby.sketchup.com/UI/HtmlDialog.html) (SU 2017+) | VERIFIED `dlg=UI::HtmlDialog.new(preferences_key:"noxun.studio"); dlg.add_action_callback("ready"){|c,p| dlg.execute_script("init()")}` | Ponechať tokeny, generation counters a cache-busting `?v=#{timestamp}`. | S | N/A |
| **S6 Templates & Updater** | `GOOD CUSTOM SOLUTION` | `View#write_image` plne podporuje `:transparent`, `:antialias`, `:compression`. Dynamické reloadovanie Ruby za behu SU poškodzuje objekty; staging + reštart latch je štandard. | [Sketchup::View#write_image](https://ruby.sketchup.com/Sketchup/View.html#write_image-instance_method) (SU 2019.2+) | VERIFIED `opts={filename:"c:/tmp/t.png",width:400,height:400,transparent:true}; Sketchup.active_model.active_view.write_image(opts)` | Ponechať JSON + `write_image`; updater ponechať s atomickým swapom a reštart latchom. | S | N/A |
| **S7 Outputs & Cutlist** | `CAD PRECEDENT` | Precedens OpenCutList rieši hrany cez atribúty a 2D nesting. `RegionalSettings.decimal_separator` existuje, no strojové exporty (VEPO CSV/XLSX) vyžadujú invariantné formátovanie. | [Sketchup::RegionalSettings](https://ruby.sketchup.com/Sketchup/RegionalSettings.html) (SU 2014+) | VERIFIED `dec=Sketchup::RegionalSettings.decimal_separator; sep=Sketchup::RegionalSettings.list_separator` | Ponechať vlastný XLSX/CSV writer; inšpirovať sa štruktúrou atribútov hrán bez prevzatia kódu. | S | [OpenCutList](https://github.com/ladb-opencutlist/sketchup-opencutlist) (GPL-3.0) |
| **S8 Web Access** | `GOOD CUSTOM SOLUTION` | `Sketchup::Http::Request` (SU 2017+) beží asynchrónne na pozadí a callback vracia do hlavného vlákna. Objekt requestu musí držať in-memory GC anchor, inak ho GC preruší. Chýba natívny timeout. | [Sketchup::Http::Request](https://ruby.sketchup.com/Sketchup/Http/Request.html) (SU 2017+) | VERIFIED `@req=Sketchup::Http::Request.new("https://httpbin.org/get",Sketchup::Http::GET); @req.start{|r,res| puts res.status_code; @req=nil}` | Ponechať `Sketchup::Http` s GC poistkou v poli requestov a vlastným timeoutom cez `UI.start_timer`. | S | N/A |

### Nenašiel som
1. Žiadne natívne API nastavenie v `UI::HtmlDialog` na vypnutie CEF diskovej cache pre lokálne assety bez cache-busting query reťazcov.
2. Žiadny natívny mechanizmus v `Sketchup.read_default`/`write_default` pre medziprocesové zámky a bezpečné zdieľanie veľkých dát medzi paralelnými oknami SketchUpu.
3. Žiadny natívny timeout parameter priamo v inicializátore `Sketchup::Http::Request`.
4. Žiadny bezpečný natívny mechanizmus na hot-swap/live-reload celého Ruby pluginu za behu bez reštartu SketchUpu.

### Zdroje
- **Trimble SketchUp Ruby API Official Docs:** [https://ruby.sketchup.com](https://ruby.sketchup.com) (`Sketchup::View`, `Sketchup::Overlay`, `Sketchup::Http::Request`, `UI::HtmlDialog`, `Sketchup::RegionalSettings`, `Sketchup::ModelObserver`)
- **OpenCutList (Ladb):** [https://github.com/ladb-opencutlist/sketchup-opencutlist](https://github.com/ladb-opencutlist/sketchup-opencutlist) (Licencia: GNU GPL v3.0 – referenčné vzory atribútov materiálov a hrán)

## Reconcile orchestrátora (3.9.2026)

Všetkých 8 subsystémov skončilo ako GOOD CUSTOM SOLUTION alebo CAD PRECEDENT (vzory, nie kód) — sweep nenašiel nič, čo by sme stavali zbytočne.
Overené v kóde: S1 ghost nástroj už používa `Sketchup::InputPoint` (`ghost_tool.rb` ~815/1135), S8 `demos/client.rb` už drží referencie requestov (GC pasca ošetrená).
Berieme ako potvrdenia: S2 (`write_default` bez zámkov → naše JSON stores s lockom sú správne), S3 (žiadne operácie v observeroch — platí), S4 (dirty tracking + lazy scan), S5 (cache-bust nutný), S6 (staging + reštart latch = štandard), S7 (RegionalSettings existuje, ale strojové exporty vyžadujú invariantný formát — VEPO/XLSX ostávajú s vlastným formátovaním).
Kandidát do registra: **Http timeout** — over, či `demos/client.rb` má vlastný timeout (agent tvrdí, že natívny chýba); ak nie, malý hardening (1d).
