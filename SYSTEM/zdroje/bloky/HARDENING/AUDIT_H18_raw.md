1. **FIX-IN-H18 — Z1–Z4 nemajú dostatočne nezávislú referenčnú pravdu.**  
   [PACKAGE_H18.md:133](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h18/PACKAGE_H18.md:133>) predpisuje uložiť výsledný set, dôvody a nákup, ale **nie víťaznú hodnotu mapovania, zdrojovú úroveň a kľúč**, ktoré vyžadujú Z1–Z4 (`:183–188`). Ak skrinka aj projekt odkazujú na rovnaký set, z výsledného `set_id` nerozoznáš zdroj. Selektor navyše `resolve_set_id` zredukuje na konkrétny set, zatiaľ čo select identifikuje celý selektor ([hardware_sets.rb:4319](</C:/APP DEV/RUBY/ENGINE/noxun_engine/core/hardware_sets.rb:4319>), `:3598`).

   T1 porovnáva novú funkciu s jej vlastným `.first` wrapperom; to nezávislú kontrolu nenahrádza. Z3 navyše výslovne odstraňuje iba vlastníka, nie triedny kľúč skrinky: pri správnom `current` môže nesprávny text **nevybranej prvej možnosti** uniknúť. Deklarovaný zásah mutácie M5 preto zo Z3 nevyplýva.

   **Doplniť:** nezávisle určené očakávané `[raw_value, level, key]`, predzmenové výsledky sondy po odstránení vlastného kľúča a samostatné asserty prvej možnosti aj tooltipu, hoci je aktuálne vybraná iná možnosť. Očakávania nesmú pochádzať z nového helpera. Zhoda `payload_po.json` s čerstvým payloadom overuje aktuálnosť fixtúry, nie správnosť zobrazenia.

2. **FIX-IN-H18 — Po návrate na starší výber skrinky status stále nepravdivo oznámi projekt.**  
   Scenár je priamo v smoke bode 2: skrinka má starý `hinge`, používateľ vyberie triedny set a potom prvú možnosť ([PACKAGE_H18.md:253](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h18/PACKAGE_H18.md:253>)). `apply_cabinet_override` odstráni triedny kľúč, starý `hinge` ostane (`hardware_sets.rb:3697–3706`). Select podľa H18 správne ukáže starší výber, ale [actions_hardware.rb:1319](</C:/APP DEV/RUBY/ENGINE/noxun_engine/ui/panel/actions_hardware.rb:1319>) bezpodmienečne oznámi **„platí predvoľba projektu“**.

   **Doplniť do inventára a testov stavovú správu.** Oprava môže byť čisto textová, bez zmeny zápisu; napríklad neutrálne potvrdenie vykonanej zmeny. D3 je samo osebe poctivé, no celý používateľský tok zatiaľ nie.

3. **FIX-IN-H18 — Vylúčenie plochého zobrazenia na základe „je v zhode“ má konkrétny protipríklad.**  
   [PACKAGE_H18.md:96](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h18/PACKAGE_H18.md:96>) necháva neklasifikovaných vlastníkov bez zmeny. Pri legacy závese s poškodeným `hinge@<wing>` však payload emituje `{invalid: true}` ([payloads.rb:2405](</C:/APP DEV/RUBY/ENGINE/noxun_engine/ui/panel/payloads.rb:2405>)). `hwOwnerOptionList` tento príznak ignoruje a označí **„(podľa skrinky/projektu)“** ako vybranú možnosť ([hardware.js:430](</C:/APP DEV/RUBY/ENGINE/noxun_engine/ui/js/hardware.js:430>)). Resolver sa pritom na markeri zastaví s `mapping_invalid`; na projekt nepadne (`hardware_sets.rb:4301`).

   Tento výsledok som potvrdil Node sondou nad skutočnou JS funkciou. Rovnaká medzera zostáva pri legacy položke v zmiešanej skrinke; Z1 kontroluje len `compat.owners`, takže ju nezachytí.

   **Doplniť zobrazenie poškodeného legacy výberu závesov a jeho test**, primerane rozšíriť povolený rozdiel T0. Jediný zdravý prípad H12 neoprávňuje všeobecné vylúčenie tejto cesty.

4. **FIX-IN-H18 — D5 umožňuje novému údaju o účinnom zdroji počítať výber, ktorý nákup výslovne vypol.**  
   Pri projekte bez snapshotu a nekompatibilnej knižnici nákup odstráni cabinet overrides ([production_core.rb:561](</C:/APP DEV/RUBY/ENGINE/noxun_engine/ui/production_core.rb:561>)). Rovnako postupuje nákupný riadok Inspectora (`payloads.rb:2148–2149`). `hardware_set_options` však používa pôvodné overrides (`:2235`), čo R2.1 a D5 zachovávajú ([PACKAGE_H18.md:156](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h18/PACKAGE_H18.md:156>), `:281`).

   Pri uloženom `hinge` teda nový `own_count` oznámi účinný vlastný výber a select starší výber skrinky, hoci nákup tento výber vôbec nepoužil. Červený riadok vysvetlí problém, ale neodstráni protirečenie.

   **Rozlíšiť uložený výber od účinného zdroja pri `blocked`** a pridať tento stav do matice. D5 v dnešnom znení je výnimka z hlavného cieľa dávky, nie dôkaz zhody.

5. **FIX-IN-H18 — Predpísané goldeny nedokazujú celú deklarovanú cenovú identitu opravovanej vetvy.**  
   Veta požadovaná do PR „nákup, rozpočet, ponuka a VEPO bajtovo rovnaké“ ([PACKAGE_H18.md:226](</C:/APP DEV/RUBY/ENGINE/_dev/audit_h18/PACKAGE_H18.md:226>)) presahuje uvedené dôkazy:

   - `ceny_m2` a `np4` volajú rozpočet **bez `hardware_expansion`** (`tests/fixtures/ceny_m2_golden/fixture.rb:62`, `tests/pure/test_np4_golden.rb:106`); práve tento vstup napája kovanie do ceny (`noxun_engine/core/budget.rb:114`, `:130`).
   - KOV-H golden zachytáva expanziu a nákupné CSV; jeho závesová položka má prázdne `params`, takže nejde o klasifikované dvierka (`tests/pure/test_kovh_golden.rb:85–88`, `:204–207`).
   - H9 cenová časť používa materiálové riadky; samostatný nákupný scenár vypína závesové pravidlo (`tests/pure/test_r37_tvar_suborov.rb:152–157`, `:172–178`).

   **Doplniť malý predzmenový golden klasifikovaných závesov s generickým a krídlovým override cez expanziu → rozpočet → ponuku**, alebo zúžiť deklaráciu na skutočne overené výstupy. Existujúce goldeny sú užitočná regresná poistka, nie dôkaz uvedeného úplného pokrytia.

6. **NOTE — R2.6 opravuje jednu vetvu nesúladu, nie úplnú zhodu dôvodov `explain` a `expand`.**  
   Set nesprávneho generického typu pri dvierkach dostane v `expand` dôvod `hinge_set_mismatch` ([hardware_sets.rb:4205](</C:/APP DEV/RUBY/ENGINE/noxun_engine/core/hardware_sets.rb:4205>)), ale `explain` skončí skôr na `set_type_mismatch` (`:5426–5428`). Navrhnutá úprava `:5434` túto vetvu nezasiahne. Pri uzavretí R2.6 preto netvrdiť úplnú paritu; buď doplniť tento prípad, alebo ho explicitne evidovať. Pri nohách, zásuvkách a výklopoch som v samotnej navrhnutej zmene dôvodu nenašiel ďalší dopad.

7. **NOTE — F1 ponechať oddelene, ale nepovažovať ho iba za neúspešné uloženie.**  
   Zápis **odstráni platný starý výber krídla** (`hardware_sets.rb:3702`, `:3731`), takže môže zmeniť nákup napriek úspešnému statusu. H18 túto chybu nevytvára; jej oddelenie rešpektuje schválený rozsah „len zobrazenie“. H18b však má byť prioritná oprava.

   Navrhnutý zápis `hinge@<wing>` so zachovanou klasifikačnou validáciou je správny smer. Samotné povolenie `class:hinge|…@wing` v parseri nestačí: závesová vetva resolvera tento kľúč vôbec nečíta (`:4414–4432`). D3 môže zostať bez možnosti zmazať starý cabinet výber. D4(b–d) sú obhájiteľné zmeny zobrazenia; zachovávanie nesprávneho počítania mimo závesov by zaviedlo ďalšiu výnimku. T4 však musí výslovne zmeniť očakávanie testu bez položiek (`tests/js/test_h6b_suhrny.js:242`).

8. **NOTE — Verdikt a hranice overenia.**  
   **0 BLOCKER, 5 FIX-IN-H18, 3 NOTE.** Extrakcia jednej spoločnej reťaze je rozumná; najväčšia medzera je nezávislosť testov zdroja a neúplný inventár zobrazenia. Audit áno, konzervatívna výrobná trieda áno, jeden PR a `ui_foto -Record` sú primerané. Pre pôvodný rozsah nevidím spúšťač povinného in-SU runnera podľa `CLAUDE.md:184`; po rozšírení opráv treba triedu znovu posúdiť.

   Overený checkout: **`main` → `466b8b4c1073bb643da8f0a6aad58b9b9768f37e`**; lokálne nie je novší merge H7b/H15. JS sada `test_h6b_suhrny.js`: **202 OK**. Ruby sondu zastavilo zamietnutie vytvorenia dočasného adresára v `tests/helper.rb:27`; autorove počty 492/492 a 312 prípadov som nezávisle nereprodukoval. Žiadne súbory ani model som nezmenil.


