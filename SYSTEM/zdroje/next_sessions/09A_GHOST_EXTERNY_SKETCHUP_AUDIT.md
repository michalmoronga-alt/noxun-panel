# 09A · Ghost vkladanie — externý SketchUp API/UX audit

> Stav: KONCEPT — neimplementovať priamo · zdroj: PR #210 (23.8.2026) · auditované proti kódu: zatiaľ nie
>
> **Doplnkový predimplementačný audit — nie task package.**
>
> Tento dokument dopĺňa [09_GHOST_VKLADANIE.md](09_GHOST_VKLADANIE.md) o pohľad mimo repozitára: oficiálnu SketchUp Ruby API dokumentáciu a praktické poznatky z SketchUp Developer Forum. Účelom je upozorniť implementačného agenta na pasce, ktoré read-only audit repa nemusí odhaliť. Konkrétny kód, triedy a implementačné rozhodnutia má po hardeningu znovu overiť agent proti aktuálnemu repu a aktuálnej podporovanej verzii SketchUp.

## Prečo tento dodatok vznikol

Implementačný agent pri NOXUN Engine typicky pracuje primárne s repozitárom, jeho testami a vlastnou znalosťou SketchUp API. Ghost placement je však práve typ funkcie, kde sú významné aj **hostiteľské UX konvencie a lifecycle SketchUp Tool API**.

Externý audit preto cielene hľadal:

- lifecycle custom `Sketchup::Tool`,
- `InputPoint` a inference,
- klávesové udalosti,
- kreslenie ghostu vo viewporte,
- focus po spustení z `HtmlDialog`,
- Orbit/suspend/resume,
- Escape/Undo správanie,
- model/world súradnice a rovinu Z=0,
- kompatibilitu medzi verziami SketchUp.

Výsledok koncept Ghostu **zásadne nemení**. Naopak potvrdzuje custom Tool + kreslený ghost ako vhodnú cestu. Dopĺňa však niekoľko povinných guardov a smoke scenárov.

---

# Externé zistenia a odporúčania

## 1 · Custom Tool je vhodnejší než natívne `place_component`

SketchUp má natívne placement API pre komponenty, ale pri požiadavke na vlastné:

- štyri anchor body,
- rotáciu o 90°,
- floor/free Z režim,
- vlastný ghost kváder,
- presné jednorazové potvrdenie,

je custom `Sketchup::Tool` správnejšia hranica. Natívny placement by prebral príliš veľa interakcie a následne by sme obchádzali jeho vlastné správanie.

**Odporúčanie pre audit:** nepresúvať NOXUN na natívne `Model#place_component` len preto, že „už vie komponent na kurzore“. Potreby Ghostu sú širšie.

## 2 · Šípky majú v SketchUpe vlastnú štandardnú funkciu

V natívnych SketchUp nástrojoch sú šípky používané na inference locking podľa osí. Ghost má schválené:

- `←` / `→` = rotácia ±90°,
- `↓` = floor lock,
- `↑` = free Z.

Custom Tool môže tieto udalosti zachytiť, ale implementácia tým **vedome preberá arrow keys od SketchUp inference locku** počas aktívneho Ghostu.

### Povinná poistka

Agent má overiť, že spracovaný kláves je skutočne spotrebovaný Toolom a nespustí zároveň natívny inference lock. Toto je UX rozhodnutie, nie náhodný side-effect.

## 3 · `TAB` vs `ALT/OPTION` pre cyklovanie anchorov

Pôvodný produktový kontrakt v dokumente 09 schválil `TAB` ako kandidáta na cyklovanie štyroch anchorov.

Externý audit priniesol dôvod tento detail pred implementáciou **znovu potvrdiť**:

- `TAB` nemá rovnakú jednoduchú cross-platform oporu medzi bežnými `VK_*` konštantami ako hlavné navigačné klávesy,
- pri custom Tools sa objavili verziovo/platformovo citlivé problémy s Tab/focus správaním,
- natívny SketchUp Move Tool používa **Alt/Option ako známu konvenciu na cyklovanie grip/uchytávacích bodov**.

### Odporúčanie

**ALT/OPTION je po externom audite preferovaný kandidát** pre cyklus 4 anchorov, pretože zodpovedá SketchUp mentálnemu modelu gripov.

Toto však **nie je automatická zmena schváleného kontraktu**. Pred task package má Michal/agent potvrdiť:

- ponechať `TAB`, alebo
- prejsť na `ALT/OPTION`.

## 4 · Escape a `onCancel` majú jemný kontrakt

SketchUp Tool API rozlišuje dôvody zrušenia nástroja. Implementačný agent musí preveriť presné správanie `onCancel(reason, view)` pre podporované verzie SketchUp.

Riziko: ak `onKeyDown` spotrebuje klávesy príliš všeobecne, môže sa narušiť natívny Escape/cancel tok.

### Invariant Ghostu

- Escape musí placement ukončiť,
- nesmie vzniknúť model mutation,
- nesmie vzniknúť Undo krok,
- nesmie sa „upratovať“ reálna CAB, pretože pred commitom žiadna nevznikla.

Agent nesmie používať univerzálne „consume every key“ správanie. Spotrebovať iba klávesy, ktoré Ghost skutočne vlastní.

## 5 · Undo môže vstúpiť do Tool lifecycle počas aktívneho Ghostu

Tool API rozlišuje cancel vyvolaný Escape/novým toolom/Undo. To je dôležité pre NOXUN, pretože observer/Undo vrstva je už dnes citlivá.

### Smoke scenár

Počas aktívneho Ghostu:

1. spusti Ghost,
2. zmeň anchor/rotáciu,
3. vyvolaj Undo,
4. over, že Ghost nevytvorí ani nemaže žiadnu entitu,
5. over konzistentný návrat Tool/Inspector stavu.

Konkrétny lifecycle nech agent overí proti aktuálnej SketchUp verzii — dokument nepredpisuje implementáciu.

## 6 · Ghost môže byť clipped — `getExtents`

Custom Tool kresliaci pomocnú geometriu mimo súčasných bounds modelu môže byť view frustumom/SketchUp kresliacim systémom orezaný, pokiaľ Tool neposkytne vhodné extents.

To je pre NOXUN veľmi relevantné: hlavný dôvod Ghostu je práve možnosť vložiť skrinku **tam, kde sa používateľ aktuálne pozerá**, aj keď je toto miesto ďaleko od existujúcich NOXUN objektov.

### Povinná kontrola

Agent má preveriť `Tool#getExtents` a zabezpečiť, aby extents zahŕňali aktuálny ghost kváder počas pohybu.

Smoke test musí zahŕňať placement ďaleko mimo dnešných model bounds.

## 7 · Focus po kliknutí v HtmlDialog

Ghost sa spúšťa tlačidlom **Vložiť** v Inspectore (`HtmlDialog`). Po kliknutí môže focus zostať v CEF/HtmlDialog a viewport nemusí okamžite prijímať klávesy Toolu.

SketchUp API poskytuje cestu na vrátenie focusu aktívnemu modelu (`Sketchup.focus` v podporovaných verziách).

### UX invariant

Po kliknutí `Vložiť`:

- Ghost sa zobrazí,
- používateľ **nemusí urobiť extra klik do modelu**, aby začali fungovať rotácie/anchor/Z shortcuty.

Toto má byť explicitný smoke test.

## 8 · Orbit počas placementu musí Ghost prežiť

SketchUp custom Tool môže byť dočasne `suspend`-nutý pri použití natívneho Orbit/Pan správania a potom `resume`-nutý.

Pre reálnu prácu je to zásadné: pri vkladaní skrinky používateľ často potrebuje model otočiť.

### Povinný invariant

Počas aktívneho Ghostu:

- MMB Orbit nesmie zahodiť placement session,
- po návrate musí zostať rovnaká rotácia,
- rovnaký anchor,
- rovnaký `floor/free` režim,
- Ghost sa má znovu korektne prekresliť.

## 9 · `InputPoint` je vhodná inference vrstva

`Sketchup::InputPoint` je určený pre natívne SketchUp inferencie a poskytuje:

- 3D pozíciu,
- vizuálny inference marker,
- tooltip/inference informáciu,
- transformovaný bod v model/world priestore aj pri geometrických prvkoch vo vnorenom kontexte.

To podporuje pracovný návrh dokumentu 09:

- `free Z` = mapovať aktívny anchor na plný inference point,
- `floor` = použiť horizontálnu polohu/inference a Z riadiť vlastným pravidlom.

## 10 · Floor znamená **globálny modelový Z=0**, nie current drawing axes

SketchUp umožňuje presunúť/otočiť vlastné drawing axes. Ich pracovná rovina preto nemusí byť svetový horizont projektu.

Michalov kontrakt však hovorí „na bod 0 / na zem“.

### Explicitný invariant

**Ghost floor lock = world/model `Z=0` v koreňovom modelovom rámci.**

Nie:

- aktuálna rovina používateľských SketchUp axes,
- ľubovoľný lokálny edit context,
- bounding box existujúcej geometrie.

Toto rozhodnutie zároveň pekne ponecháva možnosť, aby budúca Room/MagicPlan vrstva raz nahradila jednoduchý world Z=0 za semantickú `room.floor_reference` — ale nie v tejto dávke.

## 11 · Floor projection nemusí vyžadovať reálnu plochu podlahy

Ak pod kurzorom nie je geometria, custom Tool môže pracovať s pick rayom view a geometrickou rovinou Z=0.

Externý audit preto upozorňuje, že floor režim nemusí byť závislý od existencie SketchUp face na podlahe.

### Produktový význam

Ghost má byť použiteľný aj v:

- prázdnom modeli,
- otvorenom priestore bez podlahovej face,
- importe, kde je podlaha skrytá/neuchopiteľná.

Presnú matematiku/implementáciu nech rozhodne agent.

## 12 · Ghost má zostať viewport graphics — žiadna dočasná ComponentInstance

SketchUp Developer Forum obsahuje aj placement vzory, ktoré počas pohybu vytvárajú alebo premiestňujú dočasnú komponentovú inštanciu.

Pre NOXUN je to zlý trade-off kvôli existujúcim:

- observerom,
- ScaleWatch/dedup,
- Studio stale signalizácii,
- identity pravidlám,
- Undo citlivosti.

### Tvrdý invariant

**Pred potvrdením klikom = 0 model mutations.**

Ghost sa kreslí cez Tool/view API. Reálna CAB vznikne až v commit fáze.

## 13 · Prekresľovanie: invalidácia view, nie násilné mutácie

Ghost je dočasná vizualizácia. Agent má preveriť štandardný Tool redraw lifecycle a používať vhodnú invalidáciu view po:

- mouse move,
- rotácii,
- zmene anchoru,
- zmene floor/free režimu,
- resume po Orbit/Pan.

Cieľ: žiadne pomocné modelové entity a žiadne „refresh hacks“, ktoré by zasahovali do modelu.

## 14 · SketchUp 2025+ zmenil pixelové správanie niektorých Tool/View API

Pri 2D kreslení a mouse coordinates sa medzi staršími a novšími verziami SketchUp menilo používanie physical/logical pixels.

Pre čistý 3D ghost kváder a `InputPoint` je riziko malé, ale ak agent pridá:

- 2D HUD,
- anchor badge posunutý o pevný počet px,
- textové overlaye s ručne počítanou polohou,

musí preveriť kompatibilitu podporovaných verzií a prípadný scale factor.

### Odporúčanie

Prvú dávku držať vizuálne jednoduchú: 3D ghost + aktívny anchor + front indikácia. Nepremeniť placement na HUD framework.

## 15 · Tool stack / návrat k predchádzajúcemu nástroju

SketchUp má vlastný Tools stack (`push_tool` / `pop_tool` a súvisiace lifecycle správanie).

Ghost je jednorazový nástroj:

1. aktivovať,
2. umiestniť jednu CAB alebo zrušiť,
3. skončiť,
4. vrátiť používateľa do normálneho SketchUp workflow,
5. označiť novú CAB a nechať Inspector pokračovať editáciou.

Agent má pred implementáciou overiť najčistejší lifecycle proti dnešnému panelu a používaným toolbar commands; netreba emulovať vlastný globálny „mode manager“, ak ho SketchUp Tool stack vyrieši prirodzene.

## 16 · Status bar je vhodné miesto pre krátku nápovedu

SketchUp Tool môže používateľovi počas aktivity zobrazovať krátku nápovedu v natívnom status bare.

Pracovný text:

```text
Klik = vložiť · ←/→ = otočiť · ↑ = voľná výška · ↓ = podlaha · Alt/Tab = kotva · Esc = zrušiť
```

Finálny text sa musí zhodovať s potvrdeným keybindingom anchoru.

Výhoda: Ghost zostane jednoduchý a Inspector nepotrebuje ďalší permanentný blok ovládania.

---

# Doplnené povinné smoke scenáre

Externý audit odporúča, aby implementačný task package minimálne pokryl:

1. **Spustenie z HtmlDialog** — po `Vložiť` fungujú klávesy bez extra kliknutia do viewportu.
2. **4 rotácie × 4 anchory** — semantický anchor ostáva pod kurzorom.
3. **Floor world Z=0** — aj pri presunutých/otočených SketchUp drawing axes.
4. **Free Z + InputPoint** — bod na hrane/ploche/vo vnorenom komponente.
5. **MMB Orbit počas Ghostu** — suspend/resume zachová session.
6. **Escape** — 0 model mutations, 0 Undo.
7. **Undo počas aktívneho Ghostu** — žiadna dočasná NOXUN entita ani poškodený Inspector stav.
8. **Ghost ďaleko od model bounds** — nič sa neoreže/nestratí (`getExtents`).
9. **Prázdny model bez podlahovej face** — floor režim stále použiteľný.
10. **Nested edit context** — výsledný commit je top-level a transformácia zostane správna.
11. **Prepnutie dokumentu/modelu počas placementu** — stará session nesmie commitnúť do nového modelu; potvrdiť proti existujúcemu `model_guid` princípu.
12. **SU verzie v podporovanom rozsahu** — najmä klávesy/pixely/focus tam, kde sa API správanie historicky menilo.

---

# Zdroje, ktoré má agent pred implementáciou znovu overiť

Primárne zdroje externého auditu:

- SketchUp Ruby API — `Sketchup::Tool`
- SketchUp Ruby API — `Sketchup::InputPoint`
- SketchUp Ruby API — `Sketchup::View`
- SketchUp Ruby API — `Sketchup::Tools`
- SketchUp Ruby API — `Sketchup::Model`
- SketchUp Ruby API — `Sketchup::Axes`
- SketchUp Ruby API — top-level SketchUp constants / keyboard handling
- SketchUp Developer Forum — custom tool placement, focus z HtmlDialog a Tool keyboard/lifecycle diskusie

Pri implementácii sa **nesmie spoliehať iba na tento opis**. API dokumentácia aj konkrétne správanie medzi SketchUp verziami sa môžu meniť; agent má znovu overiť aktuálne docs pre podporované verzie NOXUN.

---

# Záver externého auditu

Externý pohľad **neodhalil dôvod Ghost odkladať**. Naopak potvrdil, že ide o rozumne izolovateľnú funkciu, pokiaľ sa držia tri hranice:

1. Ghost je čistá viewport grafika bez model mutations pred klikom.
2. Tool rešpektuje SketchUp lifecycle (`focus`, cancel, suspend/resume, extents, tool stack).
3. Hostiteľské UX konvencie a verziové rozdiely sú explicitne testované, nie predpokladané.

Najväčšie externé riziká nie sú v matematike boxu, ale v **Tool lifecycle a input správaní**: focus po HtmlDialogu, arrow key ownership, anchor keybinding, `onCancel`/Undo, Orbit suspend/resume a `getExtents`.

Preto Ghost ostáva vhodným **preferovaným prvým funkčným kandidátom po hardeningu**, ale implementačný task package má vzniknúť až po fresh audite repa + SketchUp API.