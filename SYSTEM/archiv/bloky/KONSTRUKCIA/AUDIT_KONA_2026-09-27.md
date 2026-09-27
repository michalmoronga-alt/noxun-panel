> Stav: surový výsledok auditu návrhu KON-A (Codex gpt-6-astra, 27.9.2026, 11,5 min) — nálezy sú zapracované v [PACKAGE_KONA_K1.md](PACKAGE_KONA_K1.md) (Scope IN a sekcia Audit návrhu); nie autorita.

Audit na čistom `main`, commit **50efa1fce054**. Súbory som nemenil. **1 BLOCKER, 5 FIX-IN-KONA, 2 NOTE.** Najväčšie riziko: navrhnuté minimum hĺbky môže odstrániť objednané police z kusovníka a export ich nebude blokovať.

1. **BLOCKER — Úspešný `build_plan` nezaručuje zachovanie požadovaných dielcov.**  
   Pri `d=161`, `X=150`, bez chrbta a bez stropu vyjde `R=11`. Podmienka `back_front_y > 10` prejde, ale police potrebujú ešte predné odsadenie 20 mm. `zone_tree.rb:550` ich vynechá a vráti iba upozornenie; ďalšie degenerované dielce podobne odstraňuje `construction.rb:153`. Čistá sonda dnešného plánovača potvrdila: požadovaná jedna polica, výsledok bez police, bez výnimky. Kontrola vydá iba ORANGE (`validation.rb:1663`).  
   **Doplniť odmietnutie hĺbky, pri ktorej požadované police nemajú platné rozmery; tú istú validáciu musí používať `min_valid_depth`.** Do matice pridať `top_mode=none`, ktoré dnes v navrhnutej matici chýba.

2. **FIX-IN-KONA — JS pomocníky nemajú zabezpečený prísun X/Y zo skutočného formulára.**  
   Vlastné zoznamy vstupov majú aj `core.js:1582` (`currentCarcass`) a `preview.js:385` (`pvGeom`). Rozšírenie `CONSTRUCTION_FIELDS` ich automaticky nerozšíri. Pri `d=260`, `X=50`, `Y=70` má flat výstuha limit **60 mm**; cez starý most môže výpočet ponechať požadovaných **100 mm**.  
   **Výslovne doplniť oba mosty a integračný test formulár → kontext → výpočet.** Parita pomocníkov nad ručne vytvorenými objektmi túto chybu nezachytí.

3. **FIX-IN-KONA — Chýba pripojenie nových polí k ochrane rozpisovaných výrazov.**  
   `boot.js:63` má samostatný zoznam `bindExprFields`. Ochrana v `form.js:442` funguje iba pre pripojené polia. Pri písaní `50-20` môže bez pripojenia debounce odoslať medzistav `50-2`, teda komín **48 mm**.  
   **Pridať X/Y do `bindExprFields` a overiť písanie s prestávkou, Enter a opustenie poľa.**

4. **FIX-IN-KONA — Podmienka upright porušuje deklarované zachovanie X=Y=0 v povolenom rozsahu.**  
   Číselná sonda potvrdila dnes platný config: `d=150`, `t=50`, `bt=50`, overlay, upright. Dnešný `R=100`; nové pravidlo požaduje **120 mm**. Normalizácia tieto hodnoty povoľuje (`cabinet_builder.rb:3009`, `construction.rb:1242`). Prestavba takej starej skrinky začne zlyhávať aj bez komína a zapustenia.  
   **Ak má ostať invariant nulových hodnôt, nový odstup 20 mm podmieniť nenulovým X alebo Y.** Inak treba túto ďalšiu zmenu kompatibility výslovne priznať; samotné zelené goldeny ju nevylúčia.

5. **FIX-IN-KONA — Vzor `plinth_recess` nespĺňa sľub „nečíselné → 0“.**  
   `cabinet_builder.rb:4003` používa `.to_f`, následný clamp nekontroluje konečnosť. Overené výsledky: `"50oops"` → 50, `"50-20"` → 50, `NaN` zostane `NaN`, objekt vyvolá výnimku. Bežný panel výraz vyhodnocuje prísnejšie, ale šablóna a Ruby vstup touto ochranou neprechádzajú.  
   **Pre X/Y určiť úplné parsovanie konečného čísla, potom predvolenú nulu a clamp.** Pridať neplatné vstupy do testov normalizácie aj načítania šablóny.

6. **FIX-IN-KONA — Existujúce texty KON-0 budú odporúčať nesprávny rozmer D-144.**  
   `bom.rb:1425` pri starej skrinke vypisuje plný `w × (h−s)`. Pre uvedený príklad schémy 18 tak odporučí **600 × 620**, hoci oprava má vydať **600 × 538**. Hromadná prestavba navyše vždy hlási „chrbát v drážke … v plnom rozmere“, aj keď bude opravovať vložený chrbát (`production_core.rb:1305`).  
   **Upraviť staré diagnostické a úspešné hlášky.** Pri konzervatívnom predikáte tiež hovoriť o potrebnej prestavbe, nie o dokázanej kolízii každého označeného kusu.

7. **NOTE — Odhad plochy potrebuje širšiu úpravu než dno a strop.**  
   `nxDraftStats` používa celkovú `D` aj pre police a priečky; chrbát vždy počíta plnou šírkou (`preview.js:492`). Po úprave iba dna a stropu bude pri väčšom X odhad výrazne nadhodnotený. Doplniť aj tieto spotreby hĺbky a užší overlay chrbát. Výrobné výstupy týmto odhadom riadené nie sú.

8. **NOTE — `rebuild_stale` zapína ponuku opravy, neurčuje jej kandidátov.**  
   Hromadný výber sa samostatne pýta na `Bom.back_stale?`, ktorý dnes pozná iba D-143 (`production_core.rb:1251`, `bom.rb:1411`). Pri implementácii musí spoločný výber zahrnúť **D-143 alebo D-144**; nový kód potrebuje aj `CUT_BLOCKER_TEXTS`. Navrhnutý test hromadnej prestavby musí prejsť cez tento skutočný výber.

Otázky pre audit:

1. **D-144 `cut_size`:** áno, zachovať rovnaký pokles, ale výslovne `Δ=max(occupy−t,0)`; pri groove/X=0 odčítať Δ, pri X>0 ponechať plnú výšku.
2. **Predikát bez rozmerov:** prijateľný konzervatívny postup; prestavba odstráni falošný poplach, hláška však nesmie tvrdiť preukázanú kolíziu.
3. **Samostatný chrbát v0.13.1:** prijateľný priznaný zvyšok podľa rozhodnutia Michala; nová značka spätne pôvod existujúceho kusu neobnoví.
4. **60 mm a 0–300:** prijateľné, ale nepokrývajú vetvu bez stropu a stratu políc z nálezu 1.
5. **Upright pri X=Y=0:** bez úpravy nie; existuje platný proti-príklad, pozri nález 4.
6. **Mierka:** klamp s hláškou je vhodný po oprave definície platnej hĺbky; samotný úspech plánu nestačí.
7. **Nika aj pre rúru/mikrovlnku:** áno, spoločný pomocník pre obe čítacie cesty zodpovedá M9; nevyjadruje kontrolu vetrania.
8. **Zápis iba >0:** áno; explicitné nuly v nových šablónach a nezmenené odvodené `top`/`back` sú konzistentné.
9. **Ďalšie cesty:** doplniť miesta z nálezov 2, 3, 7 a 8; kópie, dedup, UNI a hromadné zmeny používajú spoločný prevod — overil som **15 volaní `CabinetBuilder.config_to_params`, nie 18**.

Dnešná verzia so schémou 19 už odmietne prestavbu schémy 20 a zastaví všetky štyri exporty pred výberom súboru. Užší overlay chrbát aj dlhšie boky prejdú do výstupov cez existujúce výrobné snapshoty a `Bom.cut_dims`; samostatný nový exportný vzorec netreba. `cabinet_builder.rb:827`, `production_core.rb:1922`, `bom.rb:1372`

**NOT SOUND**


Codex session ID: 01a0e1da-a5cf-76a1-bb6b-ddfbbfc00073
Resume in Codex: codex resume 01a0e1da-a5cf-76a1-bb6b-ddfbbfc00073
