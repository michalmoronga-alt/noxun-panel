# KOVANIE — Antigravity OUTSIDE-IN audit KOV-C/KOV-D (3.9.2026, checkpoint #16)

> Stav: KONCEPT / research packet + reconcile — nie implementačný spec. Pilot roly „outside-in / prior-art" (skill `antigravity-outside-in`): agy `gemini-3.7-flash-high`, `--mode plan`, web nástroje `search_web` + `read_url_content`, beh ~10 min, prompt = package KOV-C/D + FINAL §3–§8 + 6 cielených otázok. Autorita dávok ostáva package v PLAN.md.

## Packet (výstup agenta, nezmenený)

# Prior-Art Audit: KOV-C & KOV-D (Noxun Engine) | 2026-09-02 | Gemini 3.7 Flash

| Kategória | Tvrdenie (1 veta) | Dôkaz (URL + verzia/dátum) | Overenie (VERIFIED/UNVERIFIED + snippet) | Dotknutá časť package | Odporúčanie (1 veta) | Prácnosť | Licencia |
|---|---|---|---|---|---|---|---|
| CAD PRECEDENT | Podľa DIN 107 je DIN L záves vľavo, no DIN EN 12519 / ISO 7519 kreslí vrchol trojuholníka k závesom (osa), kým US CAD (Cabinet Vision) k úchytke. | DIN EN 12519:2004 [1], DIN 107 [2] | VERIFIED; n/a | KOV-D §8 (O1 smer) | Zjednotiť symboliku podľa DIN EN 12519 (vrchol = záves) a v zmluve potvrdiť DIN L = záves vľavo. | S | ISO/DIN norma (vzory) |
| GOOD CUSTOM SOLUTION | Blum ani Hettich neposkytujú verejné JSON API; exportujú len BXF XML alebo CAD modely cez partnerské portály. | Blum BXF [3], Hettich eService [4] | VERIFIED; n/a | KOV-C §3 (C1 data packy) | Ponechať lokálne zmrazené JSON recepty v repe ako nezávislé a legálne riešenie. | S | Proprietary vendor dáta |
| CAD PRECEDENT | imos 3D, Polyboard a Cabinet Vision používajú striktný fail-closed prístup pre CAM a zámky osí držia až do explicitného konfliktu. | imos 3D Docs [5], Polyboard [6], Cabinet Vision [7] | VERIFIED; n/a | KOV-C §d, KOV-D §5, §8 | Potvrdiť fail-closed pravidlo (žiadne dielce pri konflikte, RED blocker) a zákaz tichých zmien zámkov. | M | Proprietary CAD (iba vzory) |
| SIMPLER NATIVE PATH | Ukladanie JSON snapshotu do AttributeDictionary na modeli je bezpečné, no Sketchup::Overlay (SU 2023.0+) zakazuje zápis do modelu pri kreslení (`RuntimeError`). | ruby.sketchup.com Overlay [8] (SU 2023.0), AttributeDictionary [9] (SU 2014) | VERIFIED; `m=Sketchup.active_model; m.set_attribute('noxun','recipes','{}'); puts m.attribute_dictionary('noxun')['recipes']` | KOV-C §3, KOV-D §8 | Snapshoty receptov ukladať do AttributeDictionary; Overlay použiť len na pasívne kreslenie viewport badgeov. | S | SketchUp API (Trimble EULA) |
| NO ACTION | Sketchup::Classifications je určený len pre IFC/BIM schémy a Dynamic Components trpia vysokou réžiou observerov. | ruby.sketchup.com Classifications [10] (SU 2014) | VERIFIED; `puts Sketchup.active_model.classifications.keys` | KOV-C §1, FINAL §3 | Pre V1 nepoužívať Sketchup::Classifications ani DC, držať sa vlastných čistých Ruby dátových štruktúr. | S | SketchUp API (Trimble EULA) |
| MISSED CONSTRAINT | Blum vyžaduje synchronizáciu TIP-ON od šírky 300 mm (tyč T60.1125W), kým Hettich pre Atira Push to open Silent odporúča synchronizáciu od šírky 600 mm. | Blum TIP-ON Guide [11] (2024), Hettich Atira Tech Guide [12] (2023) | VERIFIED; n/a | KOV-D §g, FINAL §3 | Trigger synchronizačnej tyče parametrizovať v recepte (Blum >=300 mm, Hettich >=600 mm) a objednávať ako dĺžkovú položku. | S | Vendor Tech Guide (fakty) |

### Nenašiel som (RESEARCH GAP)
1. Verejné strojové API (REST/JSON) výrobcov kovania na priamu synchronizáciu rozmerových tabuliek a vzorcov (existujú len uzavreté BXF/XML exporty a CAD portály).
2. Oficiálne limitné šírky synchronizačnej tyče pre systémy Grass (Nova Pro / DWD XP) bez manuálneho dohľadania v PDF katalógoch výrobcu.

### Zdroje
[1] https://www.iteh.ai/catalog/standards/cen/5457a4e6-eeeb-419b-a01c-6d9a9f99f8e0/en-12519-2004  
[2] https://www.beuth.de/en/standard/din-107/1155986  
[3] https://www.blum.com/us/en/services/planning-construction-manufacturing/product-configurator/  
[4] https://eservice.hettich.com/en/hettich-cad.html  
[5] https://www.imos3d.com/en/software/cad-cam/  
[6] https://wooddesigner.org/polyboard-hardware-management/  
[7] https://www.hexagon.com/products/cabinet-vision  
[8] https://ruby.sketchup.com/Sketchup/Overlay.html  
[9] https://ruby.sketchup.com/Sketchup/AttributeDictionary.html  
[10] https://ruby.sketchup.com/Sketchup/Classifications.html  
[11] https://www.blum.com/us/en/products/runners/tip-on-blumotion/overview/  
[12] https://www.hettich.com/en-de/products/drawer-systems/innotech-atira

## Reconcile orchestrátora (3.9.2026)

| # | Nález | Verdikt | Dôvod / dopad |
|---|---|---|---|
| 1 | Symbol otvárania: DIN EN 12519 / ISO 7519 kreslí vrchol trojuholníka **k pántom**, náš náhľad aj overlay (A2a/A2b) kreslia šípku **na voľnú hranu** | **ZATVORENÉ (O4, Michal 3.9.): „šípka na voľnú hranu sedí — nič nemeníme, normy sú rôzne, mne sedí táto."** | zdroje sú katalógy noriem (paywall) — „VERIFIED" tu znamená existenciu stránky, nie prečítaný text; rozhoduje prax, nie norma |
| 2 | Blum/Hettich nemajú verejné JSON API (len BXF/CAD portály) | BERIEME (potvrdenie) | recepty ako zmrazené JSON data packy v repe (KOV-C §3) sú správna cesta |
| 3 | imos/Polyboard/Cabinet Vision = fail-closed + zámky držia až do konfliktu | BERIEME (potvrdenie O2/R3) | dôkaz slabý (produktové stránky), ale zhoda s našou architektúrou |
| 4 | Snapshot receptov v AttributeDictionary OK; Overlay `draw` nesmie meniť model | BERIEME (známe) | kategória mala byť MISSED CONSTRAINT; pre A2b už platí |
| 5 | Classifications / DC pre V1 nepoužívať | BERIEME | zhoda s DC_PRAVIDLA |
| 6 | **Sync tyč: Blum TIP-ON od šírky ≥ 300 mm, Hettich P2O ≥ 600 mm** | **BERIEME — MENÍ KOV-D §(g)**: trigger sync tyče = parameter receptu/systému (`sync_rod_min_width`), nie natvrdo 600; hodnoty potvrdiť v oficiálnych PDF pri detail fill KOV-D | reálny nález (naša hypotéza „>600" bola len Hettich) |
| GAP | Grass prahy, strojové API výrobcov | zapísané | KOV-C/D nepotrebujú |

**Verdikt pilotu:** rola funguje (10 min, lacný pool, 2 vecné vstupy do návrhu + 4 potvrdenia). Slabiny: „VERIFIED" pri paywallových normách je nadhodnotené;
odpovede na CAD UX (Q3/Q6) plytké — nabudúce menej otázok, viac hĺbky, a probe snippety povinne overiť v SketchUpe pred prijatím API tvrdení.
