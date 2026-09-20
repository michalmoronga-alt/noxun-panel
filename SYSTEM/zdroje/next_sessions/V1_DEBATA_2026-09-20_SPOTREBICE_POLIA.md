# V1 debata · SPOTREBIČE S1 — polia, fyzické telá a poradie dávok (19.–20.9.2026)

> Stav: KONCEPT — neimplementovať priamo · zdroj: debata Michal + Fable v noci 19.–20.9.2026 (okno „Spotrebiče S1 — debata polí") · auditované proti kódu: nie (len čítanie
> `budget_store`, `templates`, `cabinet_builder` proxy vzor, `fronts.resolve_layout`) · nadväzuje na [V1_DEBATA_2026-09-06_SPOTREBICE.md](V1_DEBATA_2026-09-06_SPOTREBICE.md),
> [SPOTREBICE_TECHLISTY_2026-09.md](SPOTREBICE_TECHLISTY_2026-09.md) a [SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md](SPOTREBICE_TECHLISTY_OVERENIE_2026-09-19.md) — tento dokument ich
> **spresňuje a v jednom bode mení** (§2: fyzické telá umývačky a chladničky idú do V1).
> Postup: cross outside-in audit ×3 (Codex · Gemini/Antigravity · Grok) **HOTOVÝ** → reconcile ([S1_CROSS_AUDIT_2026-09-20.md](S1_CROSS_AUDIT_2026-09-20.md)) → mockup
> [../ui20/mockup_spotrebice_s1.html](../ui20/mockup_spotrebice_s1.html) **SCHVÁLENÝ Michalom 20.9.2026** → packages v [../../PLAN.md](../../PLAN.md) (blok SPOTREBIČE S1) → `codex-audit` per
> audit-povinná dávka → implementácia (nočný autonómny beh 20.9.).
>
> Pred implementáciou platí postup z [README.md](README.md).

## 0 · Prečo tento dokument

Debata 6.9. rozhodla rámec S1 (ručný katalóg, spotrebič patrí zákazke a vlastníkovi, cena len v rozpočte, kontrola len chladnička + umývačka, spotrebičová šablóna).
Predúloha listov (19.9.) dala overené čísla. Tu sú **rozhodnutia o poliach, kontrolách, UI a poradí dávok** — a nové rozhodnutie Michala, že umývačka a chladnička dostanú
**fyzické telá už vo V1** („radšej poriadne ako potom rozmotávať špagety"). Rozhodnutia sú Michalove; Fable formuloval návrhy a kritiku (§2.3).

## 1 · Rozhodnutia k otázkam Fable (Michal 20.9.)

| # | Téma | Rozhodnutie |
|---|---|---|
| 1 | Presahy čiel rúry a mikra | zapisovať presah hore/dole **s referenciou** (telo / nika) + **medzera pod čelom** + nika min–max; engine dopočíta druhú referenciu len keď pozná telo aj niku. Vo V1 sa z toho **nič nekontroluje**, len sa ukazuje. |
| 2 | Delenie dverí chladničky | **Kontrola + odporúčanie** (§4.2). Tlačidlo „Použiť odporúčané delenie" = voliteľný krok po S1-C, nie v scope. Blend hore/dole ostáva ručne (mimo V1). |
| 3 | Umývačka | **NIE len zákazka + cena** — Michal: „radšej poriadne": umývačka dostane **vlastný slot s telom, čelom a hornou blendou** (§2, §3). Kontrola: šírka slotu voči triede modelu + výška tela voči priestoru pod doskou. |
| 4 | Varná doska a drez voči PD | väzba na dosku (pracovná doska = samostatná doska) je **voliteľná, bez kontroly**; výrez sa ukáže v karte spotrebiča ako poznámka pre PD. |
| 5 | Drez | Michal dodal model: **Blanco Legra XL 6 S** (granitový drez, drezyonline.sk p47410) — rozmer **860 × 500**, výrez **840 × 480**. Ide do seedu ako 10. model; rádius a montáž (na dosku) doplniť z listu Blanco pri písaní seedu. |
| 6 | Digestor | len evidencia výrezu 437 × 216 + odkazy; **bez** parametra odsadenia (digestorový korpus je mimo V1). |
| 7 | Rúra a mikro — lacná kontrola navyše | **ÁNO**: kontrola šírky a hĺbky niky (vnútro skrinky, napr. 560–568) aj pre rúru a mikro; **výška sa nekontroluje** (zóny, police). |
| 8 | Kde sa spotrebič priraďuje | nová sekcia Štúdia **„Spotrebiče"** s pohľadmi **„V zákazke"** a **„Katalóg"** (vzor Kovanie: Položky · Sety). Rozpočet ostáva miestom pre cenu a dostane výber z katalógu. Vlastník sa priradí v Inspectore (riadok Spotrebič) aj v Štúdiu. |
| 9 | Očakávaný typ aj bez šablóny | **ÁNO** — v riadku Spotrebič v Inspectore sa dá nastaviť „očakáva: chladnička" aj na existujúcej skrinke. |
| 10 | Prílohy | kópie do priečinka pluginu, po jednom cez systémový dialóg (`UI.openpanel`), PDF bez náhľadu (ikona + otvorenie v prehliadači). **Seed nesie iba URL listov**, súbory si Michal priloží sám (PDF výrobcov do repa nejdú). |
| 11 | Kategórie | k dnešným (chladnička · rúra · mikrovlnka · umývačka · digestor · varná doska · iné) pribudne **drez**; batéria a dávkovač ostávajú „iné". |
| 12 | Dodáva zákazník | **ÁNO**: prepínač „dodáva zákazník" na položke v zákazke — vypne upozornenie „chýba cena" a v ponuke položku takto označí. |
| 13 | Nosnosť dna a vetranie | **neriešiť** — žiadne polia, žiadna kontrola; nanajvýš text v poznámke záznamu. |

### 1b · Druhé kolo po cross audite ×3 (Michal 20.9. ~02:00; syntéza auditu: [S1_CROSS_AUDIT_2026-09-20.md](S1_CROSS_AUDIT_2026-09-20.md))

| Téma z auditu | Rozhodnutie Michala |
|---|---|
| Čelo umývačky 826 vs list max 720 (audit: viazané na typ uchytenia, hmotnosť = limit) | **Prax:** štandard pracovnej dosky je dnes **900–950**, spotrebiče majú ~900 → umývačka sa umiestni **na takmer minimálnu výšku**, zvyšný priestor po líniu linky vyplní **blenda** (drevotrieskový korpus alebo výplň z rezaných dielov, materiál korpusu). Sokel to neovplyvňuje. Hmotnosť dvierok nikdy nebola problém ani pri 950 a veľkom presahu. → **Presah čela smerom hore sa NEOBMEDZUJE**, typ uchytenia sa **nerieši** (žiadne pole), hmotnosť len **okrajovo** (evidencia z listu, bez varovania). Zamerať sa na **základné rozmery tela/niky a rozmery čela**. |
| Mäkké ORANGE kontroly slotu (výška čela / hmotnosť / sokel) | **Nie ako varovanie.** Evidujú sa len **výška čela a hmotnosť** z listu (informácia v karte/riadku), bez ORANGE. Kontrola slotu ostáva: trieda šírky vs model, telo vs šírka slotu, min výška tela vs dostupná výška. |
| Delené čelo slotu (1 alebo 2 čelá) | otázka nebola zrozumiteľná → vysvetlené znova (dve čelá nad sebou spojené lištou, napr. IKEA VÅGLIG, aby lícovali so zásuvkami susedov); **zatiaľ: jedno čelo**, delené čelo = po V1, kým Michal nepovie inak. |
| Chladnička — voliteľné „nábytkové dvere z výkresu výrobcu" s prednosťou pred vzorcom pásiem | **OK.** |
| Výber spotrebiča v Inspectore filtrovaný podľa niky (+ prepínač „všetky") | **podľa náročnosti** → je lacný (porovnanie vnútra skrinky s poľami niky) → zaradený do S1-B ako malá položka; ak by komplikoval, vypadne. |

Dôsledok pre §3 (prepísané po Michalových screenoch ~02:30): slot má **jedno čelo s neobmedzeným presahom hore**, telo stojí na minimálnej výške z rozsahu listu, **výplň hore sa v slote negeneruje** (Michal ručne: malý korpus alebo doska → S1-E0 odomkne min výšku korpusu 80); polia listu „čelo V max" a „hmotnosť min–max" sú len evidencia.

## 2 · Fyzické telá umývačky a chladničky — do V1 (mení V1_VIZIA „Mimo V1")

### 2.1 Rozhodnutie Michala

> „Pre umývačku vytvoriť aj telo a základnú geometriu + čelo a možnosť hornej blendy. Chladničku takisto rovno poriadne — aj s fyzickým telom a kontrolou. Ako prvé fyzické by boli
> umývačka a chladnička — tu pochopíme základ implementácie a neskôr doplníme fyzické telá aj pre komplikovanejšie spotrebiče."

Fable súhlasí s oboma; **hranica V1 = umývačka + chladnička**. Rúra, mikro, varná doska a digestor telá vo V1 **nedostanú** (potrebujú niku ako zónu medzi pevnými policami
a výrezy do dielcov — iný a ťažší projekt; ostáva „neskôr").

### 2.2 Prečo je to v poriadku (a nie špagety)

- Katalóg, kópia rozmerov v zákazke (snapshot), vlastník a Kontrola sú **tie isté vrstvy** s telami aj bez nich; telá sú vrstva navyše, ktorá číta snapshot. Nič zo
  „zjednodušenej" verzie sa nezahadzuje.
- Jediné rozhodnutie, ktoré sa musí urobiť **teraz**: vlastník umývačky = **slot** (nový typ skrinky), nie „len zákazka". Rozhodnuté (§1 riadok 3).
- Engine má hotový vzor na referenčnú geometriu, ktorá sa nikdy nedostane do kusovníka: proxy nôh a úchytiek (`kind: hardware`, `proxy: true`, `manufactured: false`,
  `production_class: 'none'`, `cabinet_builder.render_hardware`). Telo spotrebiča použije **ten istý kontrakt** (kind `reference`, rola `appliance_body`).

### 2.3 Kritika Fable (zapísaná, Michal ju prijal)

- **Poradie nemôže byť „fyzika najprv" pre obe.** Telo chladničky vie rozmery až z priradeného spotrebiča → potrebuje katalóg a väzbu pred sebou. Slot umývačky rozmery
  nepotrebuje (generické telo z triedy 600/450), priradenie ho len spresní → slot ide skoro, chladnička po väzbe.
- **Cena:** slot mení builder korpusov (najcitlivejší modul: `codex-audit` + in-SU testy povinné). Blok narastie zo ~7 na **11–13 PR**, čas asi ×1,5. Za umývačku to stojí
  (najčastejší a najmenej previazaný spotrebič, dnes bez domova). Telo chladničky je lacné (vzor existuje).
- **Slot = nový TYP skrinky, nie nový druh objektu.** Typ skrinky dostane zadarmo ghost vkladanie, prisúvanie, Inspector, Kontrolu, kusovník, VEPO, ABS, úchytky, šablóny aj
  rozpočet; nový druh objektu by musel každú z týchto vecí dostať zvlášť.

## 3 · Slot umývačky — ZJEDNODUŠENÝ podľa Michalových screenov (20.9. ~02:30; `_dev/techlisty/umyvacka_Michal_slot_*.png` + 3 screeny v okne)

Michal po cross audite: „otázka je, či to stojí za komplikovanie … umývačka pre V1 len možnosť nastaviť šírku, výšku v rozsahu, sokel platí iba pre dvere umývačky (ako vysoko
sú od zeme) + presah hore na dorovnanie k výške linky — hornú výplň si doriešim podľa situácie ručne." Audit Q2 (limity čiel) **skomplikoval viac než doplnil** — ostáva len evidencia.

**Prax (screeny):** pracovná doska 900–950 (príklad linka **930**), susedia 820 na nohách 100. Umývačka WIO 3O540 PELG na **minimálnej výške 820**; hore ostáva **90 mm**,
ktoré vyplní **korpus na dorovnanie** (variant A) — pri linke 900 by ostalo len ~80 mm → **variant B = blenda, len čelná doska, ktorá zakryje dieru**. Čelo **776** (list max 720
— „takto som ich zamontoval desiatky, bez problému"), spodná hrana čela nižšie než dno susedov, pod ňou soklová lišta kuchyne. Telo umývačky: **spodných 200 mm je fixná
základňa** (zóna nôh a soklu spotrebiča, odsadená), zvyšok výškový rozsah z listu; hĺbka = min hĺbka z listu.

**Vstupy slotu (7):** trieda 600 | 450 · šírka slotu · **výška linky** (horná hrana susedných korpusov) · hĺbka · **výška tela** v rozsahu listu (predvolene minimum) ·
**sokel = spodná hrana čela od podlahy** · **výška čela**. **Výstupy:** horná hrana čela (sokel + čelo) a presah nad telom · **výplň hore = výška linky − horná hrana čela**
(informácia „ručne: korpus / doska") · telo (z modelu, inak generické podľa triedy) · list: čelo max, hmotnosť (informácia).

**Dielce slotu:** **len čelo** (výrobný dielec cez modul čiel: úchytka, materiál čiel, ABS, karta v Inspectore; bez závesov — priskrutkované na dvere spotrebiča) ·
**telo = referencia z dvoch boxov** (telo + fixná základňa 200 odsadená; nikdy v kusovníku ani vo VEPO). **Žiadna blenda ani sokel ako dielce slotu** — výplň hore aj sokel
rieši Michal ručne existujúcimi prostriedkami (malý korpus / samostatná doska / soklová lišta). Šablóny **„Umývačka 60"** a **„Umývačka 45"**; slot funguje **aj bez priradeného
modelu** (Winner „nika najprv, spotrebič neskôr").

**Odomknutie pre ručnú výplň (S1-E0, malý fix pred slotom):** dnes `CabinetBuilder::MIN = { width: 200, height: 200, depth: 150 }` — Michal potrebuje **korpus na dorovnanie
nízky napr. 90 mm**, preto sa **minimálna výška korpusu zníži 200 → 80 mm** (šírka a hĺbka bez zmeny; overiť guardy v JS/testoch; in-SU test nízkeho korpusu). Blendu ako
dosku vie plugin už dnes (samostatná doska).

**Kontrola slotu (3, ORANGE, nikdy neblokuje):** trieda šírky slotu vs trieda priradeného modelu · telo sa zmestí do šírky slotu · **minimálna výška tela ≤ výška linky**.
Výška čela, presah čela hore, sokel ani hmotnosť sa **nekontrolujú** (rozhodnutie 6.9., potvrdené 20.9. dvakrát) — list max 720 / 2–10 kg sa ukáže len ako informácia
v riadku Spotrebič.

## 4 · Chladnička — telo ako kontrolná geometria + Kontrola

### 4.1 Telo

Kreslí sa **box niky s pásmami dverí na čelnej ploche** — presne to, čo Michal dnes kreslí ručne (`_dev/techlisty/chladnicka_Michal_kontrolna_geometria.png`: 560 × 1940 × 555,
pásma 669 · 71 · 1200), **nie** skutočné telo 540 × 1935 × 545. Box stojí na dne niky (horná plocha dna skrinky), centrovaný na šírku, lícuje s čelnou rovinou korpusu. Vzniká
z **priradeného** spotrebiča (snapshot); pri skrinke, ktorá spotrebič len **očakáva**, generický box podľa kategórie. Regeneruje sa s korpusom (jedna Undo operácia), je referencia
(§2.2). Nikdy sa nedeformuje podľa niky — keď nesedí, trčí a Kontrola to povie (04A: „konkrétny model sa nikdy nestretchuje").

### 4.2 Kontrola

- **Nika:** pre každú os `min ≤ vnútro skrinky ≤ max` tam, kde list dáva obe (Beko výška 1940–1950), inak len `≥ min` (šírka min 560, hĺbka min 555). **Predpoklad V1:**
  nika = celé vnútro skrinky (jedna zóna); skrinka s vodorovnými deleniami → kontrola sa preskočí s poznámkou „nika nejednoznačná".
- **Delenie dverí (z pásiem listu):** `D = spodok + dolné dvere spotrebiča` (Beko 40 + 629 = 669), `G = medzera dverí spotrebiča` (71), škára nábytkových čiel `s`
  (z configu čiel, predvolene 2), presah nábytkových dverí cez hranu dverí spotrebiča **min 10 mm na oboch stranách** (konštanta enginu, Michal 19.9.).
  Hrana medzi nábytkovými dverami (horná hrana dolného čela, meraná od dna niky) musí ležať v pásme **`[D + 10, D + G − s − 10]`** = pre Beko **679 až 728**; odporúčaný
  stred **703**. Polohy čiel dáva `Fronts.resolve_layout` (`z0`/`z1` per čelo) — engine ich pozná bez novej geometrie. Mimo pásma = ORANGE s vetou, ktorá menuje
  pásmo aj aktuálnu hranu; riadok Spotrebič v Inspectore ukáže odporúčané delenie. Horné pásmo (1200 = zvyšok do výšky niky) je len informácia.
- Rúra a mikro (rozhodnutie 7): kontrola **šírky a hĺbky** niky rovnakým pravidlom, výška nie.

## 5 · Katalóg — polia per kategória (záväzný zoznam vznikne v package po audite)

**Spoločné:** názov/model · výrobca · kategória · odkazy obchod[] · listy[] (URL) · prílohy[] (súbor + druh `list` / `obrázok` / `náhľad`, presne jeden náhľad) · poznámka.
**Bez ceny.** Neznáme pole = prázdne, **nikdy tichý default** (04A invariant).

| Kategória | Rozmerové polia (mm) | Kontrola V1 |
|---|---|---|
| rúra · mikro | nika Š min–max · V min–max · H min · čelo Š × V × hrúbka · presah hore/dole **+ referencia telo/nika** · medzera pod čelom · telo Š × V × H (voliteľné) | šírka + hĺbka niky (7) |
| chladnička | nika Š min–max · V min–max · H min · dvere spotrebiča: spodok · dolné · medzera · horné (pásma) | nika + delenie dverí (§4.2) + telo (§4.1) |
| umývačka | trieda 600/450 · telo Š · V min–max · H · nábytkové čelo Š · V max (evidencia) | slot (§3) |
| varná doska | vonkajší Š × H · výrez Š × H (+ tolerancia) · montážna hĺbka · PD min hrúbka | len evidencia + poznámka pre PD |
| drez | vonkajší Š × H · výrez Š × H · R · montáž (na / pod dosku) | len evidencia + poznámka pre PD |
| digestor | šírka skrinky min · výrez do dna Š × H · Ø odvodu | len evidencia |

**Seed = 10 modelov:** 9 z OVERENIA (Whirlpool OMSR58RU1SB · MBNA900B · Bosch BFL7221B1 · HBG774KB1 · Beko BCNA306E5ZSN · Whirlpool WIO 3O540 PELG · Bosch SPV6EMX05E ·
Whirlpool WL B1160 BF · WCT3 63F LTK) + **Blanco Legra XL 6 S** (drez). Hodnoty a URL listov: OVERENIE §1–§7 a §11; odvodené hodnoty (telo BFL7221B1) označené ako odvodené.

## 6 · Spotrebič v zákazke

Dnes existuje `budget_appliances[]` v `NOXUN` dict na modeli (typ · názov · cena · dodávateľ · url · cp_skupina; `BudgetStore`, `BUDGET_STD` 1). S1 ho **rozšíri, nie nahradí:**
väzba na katalóg (`catalog_id`) + **snapshot** rozmerov a identity (zákazka nezávisí od živého katalógu) + **vlastník** podľa kategórie (`owner` = skrinka `CAB-…` pre rúru/mikro/
chladničku, **slot** pre umývačku, doska `BRD-…` voliteľne pre dosku/drez, `nil` = len zákazka) + prepínač **„dodáva zákazník"** + kategória `drez`. Formát dát rozpočtu
**`BUDGET_STD` 1 → 2** (disciplína bumpu: tichá strata väzby by poškodila cenu — presne prípad, pre ktorý bol marker zavedený). Cena ostáva len tu.

## 7 · UI (mockup pred package)

- **Štúdio:** nová sekcia **Spotrebiče** (13.; skupina KATALÓGY) s pohľadmi **V zákazke** (zoznam položiek zákazky: kategória · model · vlastník · stav kontroly · cena z rozpočtu;
  pridať z katalógu; priradiť vlastníka) a **Katalóg** (strom po kategóriách, karta záznamu s rozmermi, odkazmi a prílohami s miniatúrami; D-15 modal pridať/upraviť; mazanie =
  tombstone). Sekcia Rozpočet: „Spotrebiče" → **„Spotrebiče a vybavenie"**, „Pridať spotrebič" dostane výber z katalógu (D-15 `lookup`).
- **Inspector:** riadok **„Spotrebič"** v Korpus → Základné cez oba stĺpce (vzor riadku NOHY): stav `očakáva: —/rúra/…` · `priradený: <model>` (výber zo spotrebičov zákazky
  danej kategórie) · požiadavka niky z listu · verdikt kontroly · odporúčané delenie (chladnička) · klik → Štúdio sekcia Spotrebiče. Riadok je viditeľný, keď skrinka spotrebič
  očakáva alebo má; inak sa dá zapnúť voľbou „očakáva".
- **Slot umývačky** má v Inspectore vlastný obsah Základných (parametre §3), kontext Čelá (jedno čelo), Kovanie (úchytka).

## 8 · Spotrebičová šablóna

`expects` (kategória) na zázname šablóny (`TemplateStore` STD 4 → 5) a v configu skrinky (`CONFIG_SCHEMA` 14 → 15); nastavuje sa v modale „Uložiť ako šablónu" a v riadku
Spotrebič. Skrinka s `expects` bez priradeného spotrebiča = **ORANGE `appliance_missing`** v Kontrole (neblokuje). Slot umývačky má `expects: umývačka` implicitne.

## 9 · Poradie dávok (revízia 20.9.)

| Dávka | Obsah | Audit pred kódom | Odhad PR |
|---|---|---|---|
| S1-0 docs | tento checkpoint · cross outside-in packet(y) · mockup | nie | 1–2 |
| S1-A | katalóg: A1 jadro (nový modul, schéma per kategória, seed 10, prílohy, tombstone) · A2 sekcia Štúdia pohľad Katalóg | A1 áno (nový modul) | 2 |
| S1-E0 | **fix: min výška korpusu 200 → 80 mm** (korpus na dorovnanie nad umývačkou; JS/guardy/in-SU) | nie (clamp, bez kontraktu) | 1 |
| S1-E | **slot umývačky**: nový typ skrinky, telo (referencia: telo + základňa 200), **len čelo** cez modul čiel, 7 vstupov + výstupy (presah, výplň hore), šablóny 60/45, Inspector obsah, 3 kontroly, in-SU testy | áno (builder + schéma) | 2 |
| S1-B | spotrebič v zákazke: väzba + snapshot + vlastník + „dodáva zákazník", pohľad V zákazke, výber z katalógu v Rozpočte, riadok Spotrebič v Inspectore; pri slote väzba spresní telo | áno (BUDGET_STD 1→2) | 2 |
| S1-F | **telo chladničky** (box niky + pásma) + Kontrola niky (chladnička, rúra/mikro Š+H) + delenie dverí s odporúčaním + Kontrola slotu | áno (builder) | 2 |
| S1-C | spotrebičová šablóna `expects` + ORANGE bez spotrebiča | áno (schéma šablón + configu) | 1 |
| S1-D | uzáver bloku: docs, KRONIKA, V1_VIZIA, **v0.13.0** | nie | 1 |

Každá dávka = Opus subagent vo worktree, plný PR flow (`codex-po-pr`), štart z čerstvého `main`. Spolu **11–13 PR**.

## 10 · Cross outside-in audit ×3 (Michal 20.9.)

Pred mockupom a package sa návrh z tohto dokumentu pošle **trom nezávislým audítorom** — Codex (CLI, Astra), Gemini (Antigravity `agy`, web search) a Grok (`grok` CLI, web
search) — s rovnakým promptom a rovnakým mandátom (kategórie ALREADY EXISTS · SIMPLER NATIVE PATH · CAD PRECEDENT · MISSED CONSTRAINT · GOOD CUSTOM SOLUTION · RESEARCH GAP ·
NO ACTION; VERIFIED/UNVERIFIED; licencie). Výstupy sa porovnajú (zhoda = silný signál, rozpor = druhé kolo na thinking modeli), reconcile robí orchestrátor, ALREADY EXISTS /
SIMPLER NATIVE PATH sa overia probe snippetom v SketchUpe. Zameranie auditu: samostatný zápis (`S1_CROSS_AUDIT_2026-09-20.md`) po dohode s Michalom.

## 11 · Dopad na živé dokumenty (zapracuje docs PR S1-0)

- [../../V1_VIZIA.md](../../V1_VIZIA.md) bod 5: doplniť slot umývačky a telo chladničky; v „Mimo V1" zmeniť „fyzické telá spotrebičov (kubusy)" na „fyzické telá **ostatných**
  spotrebičov (rúra, mikro, doska, digestor)".
- [../../PLAN.md](../../PLAN.md) riadok Spotrebiče S1: odkaz sem + poradie dávok §9 + cross audit ×3 ako krok pred mockupom.
- [../../STAV.md](../../STAV.md) „Ďalší krok": debata polí hotová → cross audit → mockup → package.
- [../../POJMY.md](../../POJMY.md): pojmy **slot umývačky**, **kontrolná geometria chladničky**, **pásma dverí**, **blenda umývačky** (po S1-E/F).
