# Krížový audit V1 — A5 · Claude Code, Claude Opus 5.5 („stolár + UX")

Rozsah: všetkých 38 PNG v `_dev/v1audit_shots/` (krátke aj `_long`, drobné kóty náhľadu cez zväčšené výrezy), `docs/UI_DIZAJN.md` §1–2.1, PLAN („Trvalé UI/UX pravidlo" + „Po V1 — zásobník"), AUDIT_REGISTER („Stav po previerke 29.9." + os UI VZORY), DOGFOODING, ARCHIWOOD_INSPIRACIA a ROZHODNUTIA; dôkazy som overil Grepom v `noxun_engine/ui/` a v pár súboroch `core/` a `main.rb` (len čítanie).

## Os U — UI/UX drobnosti (nad screenshotmi)

### CU-01 · U · Nákup kovania hovorí jazykom databázy
- **Čo:** Skupiny v Nákupe kovania majú nadpisy ako surové kódy (ZAVESY, VYSUVY, NOHY, SPOJOVACI_MATERIAL). V tabuľke „Podľa pravidiel“ je stĺpec Parametre plný interných anglických kľúčov: „use_type door, opening_mode classic“, „nominal_length 470, front_height 150“, „height 100“. Katalóg Kovanie pritom tie isté kategórie volá „Závesy“, „Nohy a montáž“ a „Spojovací materiál“. Stĺpec Kde ukazuje duplicity („CAB-003×1, CAB-003×1“) a iný zápis než Kusovník („CAB-001 ×1“). Návrh: použiť už existujúce SK popisky kategórií. Pre všetky generiká nech server posiela ľudský text parametrov podľa vzoru D-90 `params_label` („NL 470 · čelo 150“, „dvierka · klasické otváranie“, „výška 100“). Kde zlúčiť na „CAB-003 ×2“. Stolár tak prečíta objednávku kovania bez prekladania v hlave.
- **Dôkaz:** studio_03_buy.png oproti studio_08_hw.png · `ui/js/studio.js:707` (nadpis = surový kód kategórie) · `ui/js/studio.js:770-772` (záloha: kľúč + hodnota) · `ui/js/studio.js:775-778` (zápis „×“ bez medzery) · SK popisky už existujú: `core/hardware_catalog.rb:75-85` (`CATEGORY_LABELS`).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** HARDENING — mení sa len zobrazenie v Štúdiu, nič sa neprepočítava. CSV kovania ostáva, ako je (pred zásahom overiť, že nemá spoločný formátovač).

### CU-02 · U · Kóty a popisy v náhľade Inspectora sa nedajú prečítať
- **Čo:** Písmo kót a popisov čiel v 2D náhľade má veľkosť v milimetroch modelu (18–22 mm), takže sa zmenšuje s veľkosťou skrinky. Pri 800 mm skrinke vychádza na ~6–8 px („sokel 100“, „telo 764“, „H 520“, „F1 · zásuvka 760“). Pri vysokej 2 100 mm skrinke to budú zhruba 3 px, čiže nečitateľné. Jednotka je navyše len pri šírke („Š 800 mm“, ale „V 864“). Návrh: prepočítať písmo tak, aby malo na obrazovke stálu veľkosť (napr. aspoň 10–11 px bez ohľadu na rozmer). Jednotku buď vynechať všade (mm je v plugine samozrejmé), alebo ju dať všade.
- **Dôkaz:** inspector_01_korpus.png, inspector_02_cela.png (zväčšený výrez) · `ui/js/preview.js:1150-1159` (písmo 22/18 v mm) · `ui/js/preview.js:1076` (popis čela, 18) · `ui/js/preview.js:971` (rozmer zóny).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — týka sa len kreslenia náhľadu, dáta sa nemenia. Stráž: JS testy náhľadu.

### CU-03 · U · Klávesové skratky pre najčastejšie činnosti (cez menu SketchUpu)
- **Čo:** SketchUp dovolí priradiť klávesovú skratku len položke menu (Okno → Predvoľby → Skratky). V menu Rozšírenia → Noxun Engine je dnes „Panel“, „Štúdio“ a staré názvy zaniknutých okien („Pravidlá kovania“, „Materiály projektu“, „Katalóg kovania“). Chýbajú v ňom najčastejšie činnosti: Kusovník, Kontrola, Rozpočet, Cenová ponuka, VEPO export, Vložiť kópiu, Uložiť ako šablónu a prepínače ABS / kresba / smer otvárania. Ten istý panel sa v toolbare volá „Inspector“, v menu „Panel“. Návrh: doplniť tieto položky (otvoria sekciu Štúdia alebo spustia tú istú akciu ako tlačidlo) a názvy zladiť s navigáciou Štúdia. Stolár si potom nastaví napr. F6 = Kusovník a Ctrl+Shift+C = Vložiť kópiu. V pluginu dnes nie je iná klávesová skratka než Escape.
- **Dôkaz:** studio_01_bom.png (navigácia Štúdia: Kusovník … Šablóny) · `main.rb:386` („Inspector“) oproti `main.rb:629` („Panel“) · `main.rb:636-648` (staré názvy okien) · Grep `keydown` v `ui/js/` (okrem polí len Escape).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · N · nie
- **Návrh zaradenia:** HARDENING — nové položky menu len volajú existujúce akcie, dáta sa nemenia.

### CU-04 · U · Inspector: pomocné texty a opakovaný pás zaberajú ~125 px v každom kontexte
- **Čo:** V kontexte Zóny je natrvalo vidno ~125 px textu, ktorý sa nikdy nemení:
  - dvojriadková nápoveda pod náhľadom,
  - riadok „Zobraziť zóny (ghost) v modeli“,
  - dvojriadkový pás „Skrinka 800 × 864 × 520 · … upravíš v Korpuse“ (opakuje sa v Zónach, Čelách aj Kovaní a opakuje údaje, ktoré sú už v hlavičke),
  - nápoveda pod stromom zón.

  V Korpuse je to podobné: „Materiály tejto skrinky — prázdne = dediť…“ a „bez spotrebiča — nastav „očakáva“…“. Vlastný princíp UI_DIZAJN pritom hovorí „pomocný text = tooltip“. Návrh: nápovedy presunúť do jedného `?` tooltipu v rohu náhľadu. Pás nahradiť tým, že klik na rozmery v lište sektora otvorí Korpus (rovnaký deep-link). Prepínač obrysov zón presunúť do rohu chipu „Zóny“ (vzor rohového tlačidla, §5.11).
- **Dôkaz:** inspector_02_zony.png (y ≈ 435–710), inspector_02_cela.png, inspector_02_kovanie.png, inspector_01_korpus.png · `ui/panel.html:120` (nápoveda náhľadu) · `ui/panel.html:126` (checkbox obrysov zón) · `ui/panel.html:457` (pás) · `ui/panel.html:574-575` (nápoveda stromu) · `ui/panel.html:395` · `ui/panel/payloads.rb:314` · princíp `docs/UI_DIZAJN.md:48-52`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · S · nie
- **Návrh zaradenia:** HARDENING — mení sa len rozloženie, nič sa nepočíta. Priamo napĺňa trvalé pravidlo o vertikálnom priestore.

### CU-05 · U · Kusovník píše počet platní, ktorý sa nedá objednať
- **Čo:** Súčtový riadok Kusovníka uvádza „odhad 2,2 – 2,4 platní“. Sčítava pritom zlomky platní troch rôznych materiálov (F206 0,4–0,5 + HDF 0,6 + W1100 1,2–1,3). Nárezový plán pre tú istú zákazku hovorí „3 platne (+1 orientačne)“ a Rozpočet počíta so 4 platňami. Kto objednáva z Kusovníka, objedná o 1–2 platne menej. Návrh: číslo platní zo súčtu Kusovníka odstrániť alebo ho nahradiť odkazom „platne → Nárezový plán“.
- **Dôkaz:** studio_01_bom_long.png (súčtový riadok), studio_06_cut.png, studio_04_budget.png · `ui/js/studio.js:1596-1597`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie (nič sa neprepočítava, len zmizne zavádzajúce číslo)
- **Návrh zaradenia:** HARDENING — ide o zobrazenie, a pritom to znižuje riziko chybnej objednávky.

### CU-06 · U · Jednotky a čísla sa v každej sekcii píšu inak
- **Čo:**
  - **Rozpočet → Služby:** „37,26 BM“, „4,00 PLATŇA“, „0,00 KS“, „0,00 FIX“, „23,20 M2“. Hneď vedľa pritom stojí „bm vrátane rezervy“ a „5,8 m²“. Nastavenia rozpočtu tie isté jednotky píšu „€/bm“, „€/platňa“, „€/m²“.
  - **Počty s desatinnými:** kusy a platne majú dve desatinné miesta („4,00 platne“).
  - **Medzisúčty v Službách:** „40,99“, „68“, „382,8“ — rôzny počet desatinných a bez €. Susedné stĺpce pritom píšu „134,66 €“.
  - **Bodka verzus čiarka:** Materiály píšu „23/0.8“ a „DTDL 18.6“, Pravidlá „rezerva 0.5 kg“, ale Kusovník „L1:0,8“.

  Návrh: jeden formátovač jednotiek (bm, ks, m², platne, paušál) a čísel (desatinná čiarka, celé kusy bez desatinných, peniaze vždy s 2 desatinnými a €) pre všetky sekcie. Dáta (`M2`, `PLATŇA`) ostávajú nezmenené.
- **Dôkaz:** studio_04_budget.png, studio_13_bset.png, studio_07_mat_long.png, studio_10_rules_long.png, studio_01_bom.png · `ui/js/budget.js:914` (výpočet: 2 desatinné + surová MJ) · `ui/js/budget.js:814` (MJ bez úpravy) · `ui/js/proj_materials.js:190` (`String(f)` = bodka) · `ui/js/rules.js:104` · oproti `ui/js/studio.js:325-329` (čiarka).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — týka sa len zobrazenia v okne. XLSX nemeniť, má vlastný slovník MJ (`core/cp_export.rb:63-64`).

### CU-07 · U · Názov zákazky je na dvoch miestach a skutočný je schovaný
- **Čo:** Hlavička Štúdia ukazuje „zákazka: Bez názvu“ (názov súboru). Skutočný názov, podľa ktorého sa pomenuje priečinok VEPO, rozpočet aj ponuka, je však pole „PROJEKT“ schované v lište Kusovníka (v ukážke má hodnotu „projekt“). Kto neotvorí Kusovník, exportuje ponuku s predvoleným názvom. Návrh: jeden „Názov zákazky“ priamo v hlavičke Štúdia (klik = úprava, uloží sa tá istá hodnota ako dnes) a pole z Kusovníka odstrániť. Kým je názov prázdny, zobraziť jantárový bod pri tlačidlách exportu.
- **Dôkaz:** studio_01_bom.png (vľavo „PROJEKT projekt“, vpravo „zákazka: Bez názvu“) · `ui/js/studio.js:1023`, `ui/js/studio.js:1208` oproti `ui/js/studio.js:1349-1352` (tooltip „Platí pre všetky exporty“).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — pole sa len presúva, uložená hodnota je tá istá (súvisí s R-38).

### CU-08 · U · Tabuľka Cenovej ponuky sa číta zle
- **Čo:**
  - **Stĺpec „Cena“:** je to súčet riadku, no stojí pred Množstvom. Riadok „K-InnoTech Atira … 171,56 € · 4 · set“ sa preto číta ako 171,56 € za set, v skutočnosti je to 42,89 € za set.
  - **Nulové položky:** „Zameranie 0,00 €“ a „Vizualizácie 0,00 €“ pôsobia pred zákazníkom lacno. „v cene“ je obchodne silnejšie.
  - **Vývojársky rámik:** veľký čiarkovaný rámik „PO V1 — VEDOMÝ PLACEHOLDER … (PLAN, blok V1)“ je interná poznámka z vývoja v produkčnom okne. Po uzávere V1 už ani nie je pravdivá.

  Návrh: poradie stĺpcov Položka · Množstvo · MJ · Spolu. Nulovú fixnú položku zobraziť ako „v cene“. Rámik skrátiť na jeden riadok alebo ho odstrániť.
- **Dôkaz:** studio_05_offer.png · `ui/js/budget.js:1438-1439` (poradie stĺpcov) · `ui/js/budget.js:1428-1432` (rámik) · `core/cp_export.rb:256-257` (fixné 0,0).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING pre tabuľku v Štúdiu. Rovnaká úprava v XLSX by menila výstup, preto PO V1.

### CU-09 · U · Semafor Kontroly mieša nálezy a skrinky
- **Čo:** Oranžové „10 skontroluj pred objednávkou“ počíta nálezy (6 z nich sú dielce jednej skupiny s pracovným materiálom UNI, 3 sú riadky rozpočtu). Zelené „0 skriniek bez nálezu“ počíta skrinky. V ukážke je 7 skriniek a 5 riadkov nálezov. Zelená nula tak vyzerá ako „všetko je zle“, hoci jediným problémom je pracovný materiál chrbta. Návrh: „0 z 7 skriniek bez nálezu“ a oranžové „10 nálezov v 5 riadkoch“ (alebo počítať riadky). Vetu „poradie určuje server“ zmazať a „(legacy)“ nahradiť slovami „staré čelá bez smeru“.
- **Dôkaz:** studio_02_ctrl.png · `ui/js/studio.js:379-386` (semafor) · `ui/js/studio.js:1289` („server“) · `ui/js/studio.js:906` („legacy“).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — počty dodáva server, mení sa len text. Počet všetkých skriniek treba doplniť do údajov, ktoré server posiela.

### CU-10 · U · Zbalený sektor hlási „všetko zbalené“ namiesto obsahu
- **Čo:** Sektory Nastavenia, Čelá a Kovanie majú v lište „3 skupiny · všetko zbalené“, čo nič nehovorí. UI_DIZAJN pritom výslovne žiada, aby zbalený sektor povedal, čo skrýva. Údaje na súhrn existujú, len sa nepoužijú. Súhrn riadku „Spoločné pre skrinku“ je zas zbytočne šifrovaný („F206 ST9 Piet… · 3 · 2/2/2/2“ = dekor · medzera · okraje bez popisu). Návrh: meta skladať z obsahu — Nastavenia „strop 2 výstuhy · chrbát v drážke“, Kovanie „7 položiek · 3 sety“, Čelá „1 čelo · F206“. Spoločné pre skrinku písať „medzera 3 · okraje 2“ (pri rovnakých okrajoch jedno číslo).
- **Dôkaz:** inspector_01_korpus_long.png (NASTAVENIA), inspector_02_cela.png, inspector_02_kovanie.png · `ui/js/shell.js:211-221` · `ui/js/core.js:597` · `docs/UI_DIZAJN.md:42-44`. Dnešný text drží test `tests/js/test_uib_meta.js`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie
- **Návrh zaradenia:** HARDENING — súhrn sa skladá z údajov, ktoré panel už má, nič sa nepočíta.

### CU-11 · U · Spodný blok Inspectora: dve tlačidlá na celú šírku, status a pätička (~110 px)
- **Čo:** Pod každým kontextom sú natrvalo tlačidlá „Vložiť kópiu“ a „Uložiť ako šablónu do knižnice“ (obe na celú šírku), riadok „Pripravené.“ a pätička s verziou. Spolu je to ~110 px, ktoré sú pri dlhých kontextoch viditeľné až po odscrollovaní. Návrh: obe akcie dať ako ikony do hlavičky vedľa názvu skrinky (ceruzka tam už je), prípadne do jedného riadku s dvomi polovičnými tlačidlami. Status zobrazovať len vtedy, keď nesie správu. Verziu nechať len v „O plugine“.
- **Dôkaz:** inspector_01_korpus_long.png, inspector_02_cela.png · `ui/panel.html:914`, `ui/panel.html:916`, `ui/panel.html:1063`, `ui/panel.html:1068`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — mení sa len rozloženie, spĺňa trvalé pravidlo o vertikálnom priestore.

### CU-12 · U · „Obnoviť zálohu“ stojí hneď vedľa „Obnoviť“
- **Čo:** V Materiáloch je tlačidlo „Obnoviť zálohu“, ktoré vráti celý katalóg do stavu pred migráciou. Stojí tesne vedľa bežného „Obnoviť“ a má takmer rovnaké meno, takže omyl hrozí pri každom kliku (hoci ho ešte zachytí potvrdzovacie okno). Tlačidlo ostáva viditeľné, kým existuje predmigračná záloha, teda aj mesiac po migrácii. Obnova sa pritom v každej sekcii volá inak: Obnoviť, Načítať nanovo, Načítať globálne, Prepočítať ceny. Návrh: núdzové „Vrátiť katalóg pred migráciou…“ presunúť do „O plugine“ alebo do menu „⋯“. Bežnú obnovu nazvať všade „Obnoviť“ s rovnakou ikonou.
- **Dôkaz:** studio_07_mat.png, studio_13_bset.png, studio_10_rules.png, studio_04_budget.png · `ui/js/proj_materials.js:3885-3891`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — tlačidlo sa len presúva a premenuje, správanie aj potvrdenie ostávajú.

### CU-13 · U · Vývojársky žargón a „kričiace“ veľké písmená v textoch
- **Čo:** Do UI prenikli slová z vývoja: „legacy“, „poradie určuje server“, „seed“ pri každom spotrebiči, „ghost“, „engine“, „zatiaľ v okne“, „jeden obsah, dva vstupy“. Pomocné texty zdôrazňujú veľkými písmenami (SAMÉ, POSLEDNÁ, LEN, GLOBÁLNE, KONKRÉTNEHO, NOVÚ). Verzia je raz „V0.17.0“, inde „v0.17.0“. Pre stolára je to šum a pôsobí to nedokončene. Návrh: jedna textová dávka so slovníkom náhrad (seed → „dodaný s pluginom“, ghost → „obrysy zón“, legacy → „staré čelá“). Zdôrazňovať tučným písmom namiesto veľkých písmen a verziu písať jednotne „v0.17.0“.
- **Dôkaz:** studio_02_ctrl.png, studio_09_appl.png, inspector_02_zony.png, studio_08_hw.png, studio_14_about.png, studio_04_budget_long.png, studio_12_sup.png, studio_11_tpl.png
  - `ui/js/studio.js:167`, `ui/js/studio.js:182`, `ui/js/studio.js:906`, `ui/js/studio.js:1289`
  - `ui/js/appliances.js:265`, `ui/js/appliances.js:422`
  - `ui/panel.html:126`
  - `ui/js/studio_settings.js:270`, `ui/js/studio_settings.js:316`, `ui/js/studio_settings.js:324`
  - `ui/js/budget.js:671`, `ui/js/budget.js:677`
  - `ui/js/templates.js:315`
  - `ui/js/about.js:110` oproti `ui/js/studio.js:1023`
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — menia sa len texty. Časť z nich držia testy (napr. `tests/js/test_kova2b_smer_overlay.js`), tie sa upravia v tej istej dávke.

### CU-14 · U · CSS drobnosti: systémové rozbaľovačky, orezané texty, rozhádzané stĺpce
- **Čo:**
  - **(a) Rozbaľovačky:** výber setu nôh v Inspectore presahuje pravý okraj panela („podľa projektu — Nohy p…“). Spolu s „očakáva: —“, „Podľa výrobcu“, „Kresba čiel“ a „Všetky kategórie“ má systémový vzhľad (čierny rámik), hoci ostatné polia majú štýl pluginu. Chýba základné pravidlo pre `select`.
  - **(b) Hľadanie:** texty v políčkach hľadania sú orezané („Hľadať dekor, výrobcu aleb“, „Hľadať kód, názov, dodávat“).
  - **(c) Kusovník:** každá tabuľka materiálu má vlastné šírky stĺpcov, takže Dĺžka a Šírka medzi skupinami skáču a oko nevie ísť po stĺpci dole.

  Návrh: základný štýl `select` v `panel.css`, kratšie texty v hľadaní („Hľadať…“ + tooltip) a pevné rozloženie (`table-layout: fixed`) so spoločnými šírkami stĺpcov pre tabuľky Kusovníka.
- **Dôkaz:** inspector_01_korpus.png (riadok Nohy), studio_07_mat.png, studio_08_hw.png, studio_01_bom.png · `ui/css/panel.css:95`, `ui/css/panel.css:598`, `ui/css/panel.css:654`, `ui/css/panel.css:1900` (pravidlá pre select len v rámci jednotlivých blokov) · `ui/css/panel.css:1750` (`.hwsetsel` max-width) · `ui/css/panel.css:1241` (`.bomtab` bez pevného rozloženia) · `ui/js/proj_materials.js:3879`, `ui/js/hw_catalog.js:1805`.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — ide len o CSS. Najprv overiť v SketchUpe (CEF), screenshoty sú z Chrome.

### CU-15 · U · Nastavenia rozpočtu neukazujú, aká sadzba naozaj platí
- **Čo:** Každá sadzba má štyri bunky (Sadzba, €, €€, €€€). Prázdna bunka režimu znamená „platí základná sadzba“, ale neukáže, aká to je — stolár nevidí, že Porez platní stojí v každom režime 17 €. Stĺpce sú označené len symbolmi, kým Rozpočet píše „režim Štandard“; význam symbolov je len v tooltipe. Návrh: v prázdnej bunke ukázať zdedenú hodnotu sivým textom („17“). Hlavičky písať „€ nízky · €€ štandard · €€€ vysoký“ a stĺpec „Sadzba“ premenovať na „Základ“.
- **Dôkaz:** studio_13_bset.png, studio_04_budget.png („režim Štandard“) · `ui/js/studio_settings.js:83` (políčko bez sivého textu) · `ui/js/studio_settings.js:113`, `ui/js/studio_settings.js:126` (hlavičky) · `ui/js/studio_settings.js:271` · `ui/js/budget.js:416-418` (mená režimov len v tooltipe).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · N · nie
- **Návrh zaradenia:** HARDENING — ide o zobrazenie; uložené hodnoty ani výpočet sa nemenia.

## Os N — nápady po V1 z pohľadu dielne

### CU-16 · N · Stav zákazky a snímka pri odoslaní
- **Čo:** Zákazka je dnes stále „živá“: rozpočet sa mení s cenami a model sa dá upravovať aj po odoslaní VEPO. Dielňa potrebuje vedieť, čo presne bolo ponúknuté a objednané. Návrh:
  - stavy Návrh → Ponuka odoslaná → Objednané → Vyrobené,
  - pri odoslaní VEPO alebo ponuky sa uloží snímka (kusovník, kovanie, suma),
  - po zmene modelu Kontrola hlási „dielec zmenený po objednávke“ a Cenová ponuka „+120 € oproti odoslanej verzii“.

  Princíp „ceny nikdy nezamrznú ticho“ ostáva, lebo ide o výslovnú snímku, nie o tiché zmrazenie.
- **Dôkaz:** studio_12_sup.png („Do zákazky sa nemrazia — rozpočet je pohyblivý obraz cien“), studio_13_bset.png · `SYSTEM/V1_VIZIA.md` §2 (ceny = pohyblivá cache s dátumom overenia) · reálne objednávky od 20.8. (`SYSTEM/PLAN.md`, „Pravidlo pre postrehy“).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · V · áno
- **Návrh zaradenia:** PO V1 — nová funkcia s uloženými dátami v zákazke.

### CU-17 · N · Rýchle „čo keby“ pre zákazníka
- **Čo:** Zákazník sa pýta: „A koľko by to stálo v dube alebo so zásuvkami Blum?“ Dnes to znamená zmeniť predvoľby projektu, čím sa prestavia skrinky v modeli. Návrh: v Rozpočte panel „Variant“ — dekor čiel alebo systém zásuviek sa zamení len vo výpočte a ukáže sa rozdiel v cene, bez zápisu do modelu. Keď sa zákazník rozhodne, variant sa použije naozaj.
- **Dôkaz:** studio_07_mat.png („Zmena sa premietne do všetkých dediacich skriniek (1 krok Späť)“), studio_04_budget.png.
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** V · V · áno
- **Návrh zaradenia:** PO V1 — počíta ceny, nie je to drobnosť.

### CU-18 · N · Zákaznícky názov položky v katalógu
- **Čo:** Cenová ponuka má byť „rečou zákazníka“, ale ukazuje katalógové názvy dodávateľa („K-InnoTech Atira čelný biely 470/70, 30 kg, SiSy“, „W1100 DTDL 18 mm“ bez názvu dekoru — zákazník nevie, že W1100 je Alpská biela). Návrh: katalóg kovania a materiálov dostane voliteľné pole „názov pre zákazníka“ (napr. „Plnovýsuvná zásuvka s tlmeným dovieraním“, „Alpská biela, 18 mm“) a ponuka ho použije. Je to zároveň pripravený podklad pre DOCX ponuku zo zásobníka.
- **Dôkaz:** studio_05_offer.png · `ui/js/studio.js:152` (sľub „rečou zákazníka, bez interných kódov“).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · áno (mení text výstupu ponuky, ceny nie)
- **Návrh zaradenia:** PO V1 — nové pole v katalógu a zmena výstupu.

### CU-19 · N · Sklad zvyškov platní
- **Čo:** Pri malej zákazke ostáva veľa platne nevyužitej — F206 má využitie 34 %, W1100 52 %. Nárezový plán by mohol zvyšok nad istý rozmer (napr. 600 × 300 mm) ponúknuť na „odloženie do skladu zvyškov“ (dekor, rozmer, dátum). Pri ďalšej zákazke v tom istom dekore by ukázal „na sklade je zvyšok 1 200 × 2 070 — pokryje 3 dielce“. Šetrí to hlavne drahé platne v dekoroch čiel.
- **Dôkaz:** studio_06_cut.png (využitie 34 % / 48 % / 52 %).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · V · áno
- **Návrh zaradenia:** PO V1 — nové dáta a zasahuje do nákupu platní.

### CU-20 · N · Odhad hodín dielne
- **Čo:** Plugin pozná všetko, z čoho sa počíta práca: počet dielcov a rezov, bm olepu, počet čiel, pántov a výsuvov, m² montáže. Ukazuje však len peniaze (montáž v €/m²). Návrh: informačný riadok „odhad: rez 1,5 h · olep 1 h · kovanie 3 h · montáž 6 h“ podľa nastaviteľných normočasov. Pomôže plánovať kapacitu dielne a overiť, či sadzby v rozpočte naozaj pokrývajú prácu.
- **Dôkaz:** studio_04_budget.png (Služby: 37,26 bm, 4 platne, 23,20 m²), studio_03_buy.png (počty kovaní).
- **Scenár:** —
- **Prínos / náročnosť / riziko pre výrobu a ceny:** S · S · nie (len informácia, do ceny nevstupuje)
- **Návrh zaradenia:** PO V1 — nová funkcia.

## Doplnky k známym

- **R-27** (text „1,0 mm“ v Pravidlách): rozpor je vidno naprieč sekciami. Pravidlá pri Dvierkach píšu „1,0 mm“, Kusovník pri tých istých čelách F206 píše „0,8“ (páska 23/0.8), takže stolár vidí dve rôzne hodnoty. Návrh: v Pravidlách písať triedu („tenká 0,8–1 / hrubá 2“) alebo „trieda 1 mm“. Dôkaz: studio_10_rules.png oproti studio_01_bom.png.
- **R-24** (zdvojení pomocníci): okrem escaperov sú zdvojené aj formátovače čísel, a dávajú rôzny výsledok — `ui/js/proj_materials.js:190` píše bodku, `ui/js/studio.js:325-329` čiarku. Riešenie CU-06 patrí do toho istého spoločného `nx_text.js`.
- **D-106** (predbežná cena skrinky): pravý informačný stĺpec Základných má 6 malých riadkov oproti 5 poliam vľavo. Pod „Hmotnosť“ ostáva ~38 px voľného miesta, takže „≈ X €“ sa zmestí bez toho, aby panel narástol. Vzor „≈ 25,4 kg“ už existuje (inspector_01_korpus.png).
- **D-141 a nové typy skriniek (horná rohová, vysoká — zásobník):** rad typov v Inspectore (Dolná · Horná · Rohová · Umývačka · Doska) už pri šírke 486 px zaberá celý riadok (inspector_00_bez_vyberu.png). Šiesty typ sa nezmestí, preto premenovanie na „Spotrebič“ (D-141) alebo ikonové zobrazenie treba vyriešiť spolu s prvým novým typom (S1).
- **DOCX/PDF ponuka (zásobník):** rámik v Cenovej ponuke odkazuje na „PLAN, blok V1“, ktorý je už uzavretý, takže text je zastaraný (`ui/js/budget.js:1431`). Pozri CU-08.
- **R-29** (sekcia si nepamätá, kam bola odscrollovaná): sekcie Pravidlá (viac ako 2 200 px), Rozpočet a Materiály sú veľmi dlhé (studio_10_rules_long.png), takže strata miesta pri prepnutí bolí viac, než register predpokladá.

## Čo som nestihol / neistoty

- Screenshoty sú z Chrome, nie z CEF. Pretečenie rozbaľovačky Nohy a systémový vzhľad rozbaľovačiek (CU-14) treba overiť v SketchUpe. Prázdne náhľady šablón v Štúdiu a „Kontrolujem priečinok…“ v O plugine považujem za artefakt renderu, preto ich neuvádzam.
- Bez hoveru a modálov: niektoré skratky (€/€€/€€€, ikony akcií šablón) majú tooltip. Hodnotil som, čo je vidno bez neho.
- XLSX ani CSV výstupy som nevidel. Pri CU-01, CU-06 a CU-08 treba pred zásahom overiť, že formátovač nezdieľa aj export; ak áno, zmenu musí chrániť golden test.
- Dlhý screenshot Pravidiel končí na 2 200 px, spodok sekcie som nevidel.
- Názvy dielcov bez diakritiky („Bok lavy“, „Zasuvkove celo“) sú zámerne viazané na skratky VEPO (`core/vepo_export.rb:72-95`), preto ich nenavrhujem meniť. Názvy šablón zo seedu („Dolna klasik“, „Drezova“ — `core/templates.rb:800-804`) sú dáta knižnice, ktoré si používateľ vie premenovať sám.
