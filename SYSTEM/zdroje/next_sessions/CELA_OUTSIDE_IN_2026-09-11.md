# Balík Čiel — outside-in, 11.9.2026

> Stav: KONCEPT / research packet — podklad návrhu D-114/D-119/D-120; autorita implementácie bude PLAN.md.

Gemini 3.8 Flash High cez agy, režim plan, dve úzke otázky, izolovaný scratch. Exit a surový výstup v `_dev/cela-plan/`.
Orchestrátor otvoril obe uvedené primárne referencie a porovnal odporúčania s aktuálnym kódom na main 21be151.

| Kategória | Dôkaz | Overenie a rozhodnutie |
|---|---|---|
| MISSED CONSTRAINT | [W3C SC2.5.8](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html) | VERIFIED. Berieme dostatočnú veľkosť a odstupy klikateľných plôch. Šesť ikon sa zmestí do jedného radu; použijú existujúce názvy a dostupné popisky. Nie je to audit celkovej prístupnosti pluginu. |
| ALREADY EXISTS | [Geom::Transformation](https://ruby.sketchup.com/Geom/Transformation.html#rotation-class_method), rotation/translation od SU6 | VERIFIED existencia API, nie funkčnosť navrhnutého renderera. Kód už transformácie používa. Nie je potrebný nový Tool ani Observer. Konkrétne štyri osadenia sa musia overiť in-SU pred prijatím implementácie. |
| SIMPLER NATIVE PATH | Jedna extrúzia profilu a rigidné osadenie na hranu | Návrh zostáva kandidátom, nie preukázaným výsledkom probe. **Odmietnutá chyba packetu:** v Noxune je čelo v X/Z a normála v Y; rotácie okolo Z by zmenili hĺbku a nos profilu. Použiť os Y a overiť všetky kotvy, nos a dĺžky. |
| CAD PRECEDENT | Polyboard/imos spomenuté iba z pamäte modelu | UNVERIFIED. Neberieme ako dôkaz ani odporúčanie. Ide o proprietárne produkty; nepreberá sa kód, dáta ani komponenty. |
| RESEARCH GAP | Verejný precedens konkrétnej kombinácie štyroch okrajov a hromadného/per-čelo profilu | Agent nenašiel overený primárny zdroj. Jeho tvrdenie „neexistuje publikovaný vzor“ odmietnuté: neúspešné hľadanie nepreukazuje neexistenciu. |
| GOOD CUSTOM SOLUTION | Existujúci Inspector: karta jedného čela a hromadná skupina Úchytky | Vlastný návrh schválený Michalom, nie externý fakt. Zachovať kompaktnosť a identitu čela pri prekreslení. |
| MISSED CONSTRAINT | [HtmlDialog add_action_callback/execute_script](https://ruby.sketchup.com/UI/HtmlDialog.html#add_action_callback-instance_method) | VERIFIED orchestrátorom po audite. Oba smery komunikácie sú asynchrónne. Nový read-only preflight musí korelovať reláciu a revíziu návrhu; návrat JS volania nepreukazuje hotové Ruby vyhodnotenie ani úspešný zápis. |

## Reconcile

- Používateľské rozhodnutia a rozsah sa nemenia. CAD zmienky bez dôkazov nie sú podkladom implementácie.
- Neprijímame nezdrojované tvrdenie, že negatívny determinant vždy obracia uložené face.normal. Cieľom sú rigidné osadenia; geometriu treba merať v SketchUpe.
- Rozhodujúca kontrola je skutočný panel aj prierez vo všetkých štyroch polohách, s nemennou prednou stranou profilu a súhlasnou výrobnou dĺžkou.
- Žiadny SketchUp probe zatiaľ neprebehol. Rešerš neuzatvára geometrickú bránu ČELÁ-B. Pred prijatím kandidátnej transformačnej cesty musí prejsť krátky in-SU probe.
