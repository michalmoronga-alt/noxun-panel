# CENY-KOV — outside-in, 10.9.2026

> Stav: KONCEPT / research packet — podklad schváleného rozsahu v PLAN.md, nie samostatné zadanie.

Gemini 3.8 Flash High cez `agy`, `--mode plan`, dve úzke otázky, scratch mimo repa; exit 0, stderr prázdny.
Orchestrátor porovnal packet s otvorenými primárnymi referenciami. Rozsah: externý prehliadač + explicitné ručné potvrdenie ceny v existujúcom Štúdiu.

| Kategória | Tvrdenie a dôkaz | Overenie | Rozhodnutie | Prácnosť / licencia |
|---|---|---|---|---|
| NO ACTION | [UI.openURL](https://ruby.sketchup.com/UI.html#openURL-class_method), od SU 6.0, otvára predvolený prehliadač | VERIFIED; existujúce volania `materials_dialog.rb:721`, `production_core.rb:2435` | Zachovať existujúcu cestu. Boolean nie je dôkazom načítania stránky ani overenia ceny. | S / referencia API |
| MISSED CONSTRAINT | [execute_script](https://ruby.sketchup.com/UI/HtmlDialog.html#execute_script-instance_method) a [add_action_callback](https://ruby.sketchup.com/UI/HtmlDialog.html#add_action_callback-instance_method), SU 2017+ | VERIFIED: asynchrónna komunikácia | Pripravenie formulára a jeho potvrdenie musia mať explicitnú identitu; poradie Ruby riadkov nepreukazuje dokončenie DOM operácie. | S / referencia API |
| MISSED CONSTRAINT | [bring_to_front](https://ruby.sketchup.com/UI/HtmlDialog.html#bring_to_front-instance_method), [visible?](https://ruby.sketchup.com/UI/HtmlDialog.html#visible%3F-instance_method) | VERIFIED: prvé zdvíha celé okno, druhé platí aj pre minimalizovaný dialóg | Po otvorení webu automaticky nezdvíhať Štúdio. Viditeľnosť okna nie je fokus poľa. | S / referencia API |
| GOOD CUSTOM SOLUTION | Existujúci formulár v DOM + explicitné potvrdenie | Návrh orchestrátora nad existujúcimi kontraktmi | Formulár čaká na návrat používateľa, cena a dátum sa zapíšu výlučne tlačidlom potvrdenia. Samotné otvorenie ani zrušenie nič nepotvrdzuje. | S / vlastné riešenie |
| RESEARCH GAP | Poradie fokusu medzi externým prehliadačom a HtmlDialog | Oficiálne referencie ho negarantujú | Overiť krátkym Windows/SketchUp smoke testom; nový správca fokusu sa nezavádza. | S / bez preberania kódu |

## Reconcile

- Berieme obmedzenia asynchrónneho kanála a fokusu. Ide o spresnenie implementácie, schválený tok sa nemení.
- Odmietnuté nezdrojované tvrdenie Flash packetu, že Boolean garantuje úspešné odovzdanie OS. Nepoužíva sa ako dôkaz kontroly produktu.
- Neprijímame novú natívnu API cestu ani CAD kód; `UI.openURL` už plugin používa. Preto sa probe nového API nevzťahuje; výsledný používateľský tok sa overí pri platformovom smoke.
- Jedno pole URL a jeden spoločný formulár stačia. Viac URL, ďalší parser dodávateľov a zmrazovanie cien zákaziek sú mimo schválených dvoch dávok.
