# VEPO výstupný kontrakt (v1.2 — extrahované z vepo_exporter 15.7.2026, deviaty stĺpec 3.9.2026, názov ≤ 20 znakov 8.9.2026)

> Presný formát tabuľky pre objednávkový systém VEPO, zreverzovaný z Michalovho pluginu `vepo_exporter` (Plugins\vepo_exporter\core\*). Nový systém tento výstup generuje PRIAMO z dielcov — bez medzikroku OCL CSV → vepo_exporter. Tento dokument je zdroj pravdy formátu.
>
> ✅ **Implementované a VALIDOVANÉ:** export V0.5-C (PR #51) prešiel 20.7.2026 dvojkolovou krížovou validáciou proti starému OCL→vepo_exporter flow (26 = 26 dielcov, presné zhody; 1. kolo chytilo omyl s odpočtom ABS → fix PR #58). Plný záznam: [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md).
>
> **v1.1 (3.9.2026, D-112 + D-113):** pribudol **deviaty stĺpec `poznamka`** a zmenil sa **tvar názvu riadku** (skratky + skrinky). Zvyšok formátu je bajtovo nezmenený.
>
> **v1.2 (8.9.2026, D-121):** **názov riadku má VŽDY najviac 20 znakov.** Michal 7.9.2026 overil v praxi, že **import objednávky VEPO pole `nazov` nad 20 znakov ODMIETA** —
> v1.1 pritom tvrdila, že 20 je len tlač nálepky a pole nesie 60, takže sa dlhé riadky pred odoslaním prepisovali ručne. `NAME_MAX = 20` je odteraz jediná autorita limitu.
> Súčasťou revízie sú: skratky dielcov zásuvky (`Zas dno N`, `Zas chrb N`, `Zas predok N`, `Zas bok L/P N` — pôvodne D-121a), **zlúčenie číslovaných tokenov** v riadku,
> **deterministický orez po hranici tokenu bez výpustky** a **priznanie orezu** (oddiel LOGu „Skrátené názvy" + ORANGE nález Kontroly). Stĺpce, oddeľovač, rozmery, kódy
> hrán, hrúbky ani názvy súborov sa nemenia.

## Výstupný CSV súbor (to, čo VEPO potrebuje)

- **Stĺpce v presnom poradí (bez hlavičky):** `nazov ; dlzka ; hrana_pozdlz ; sirka ; hrana_naprieč ; hrubka ; pocet_ks ; material ; poznamka`
- **Oddeľovač:** `;` (bodkočiarka), **všetky polia v úvodzovkách** (force_quotes)
- **Rozmery:** celé čísla v mm (zaokrúhlené `.round`) — **HOTOVÉ/finálne rozmery dielca, ŽIADEN odpočet ABS** (potvrdené 20.7., Michal: VEPO si hrúbku pásky odratáva samo na základe kódov hrán — presne preto sa kódy posielajú; stará linka OCL→vepo_exporter posielala tiež finálne rozmery)
- **Kódovanie hrán (ABS):**
  - `""` (prázdne) = bez hrany na tejto dvojici strán
  - `—` (em-dash) = hrana na JEDNEJ strane z dvojice
  - `=` = hrany na OBOCH stranách dvojice
  - `hrana_pozdlz` vyjadruje dvojicu pozdĺžnych strán (l1, l2), `hrana_naprieč` dvojicu priečnych (w1, w2)
- **Rotácia dielca** (ak treba kvôli dekóru/nestingu): vymeniť dĺžka↔šírka A ZÁROVEŇ hrana_pozdlz↔hrana_naprieč

## Stĺpec `poznamka` (v1.1, D-112)

- **Je VŽDY prítomný** — riadok bez poznámky nesie `""` (prázdny reťazec v úvodzovkách), nikdy chýbajúce pole. Deviaty stĺpec ide cez ten istý `CSV.generate` ako zvyšok (force_quotes, `;`, CRLF, UTF-8 bez BOM).
- **Kedy sa plní:** keď má dielec ABS pásku, ktorá **nepatrí do tej istej dekorovej skupiny ako doska**. Záznam pásky aj dosky musí byť ZNÁMY (obe v katalógu, aspoň jeden
  z údajov `group_id`/`decor` neprázdny) — inak sa poznámka **nevymýšľa** (neznámy materiál/pásku hlási KONTROLA a oddiel „Riadky vyradené z CSV" v LOGu).
  **UNI dosky sa neporovnávajú** — ich „dekor" je pracovný názov (`Korpus UNI`), materiál je neurčený a KONTROLA to už hlási samostatne.
- **Podľa čoho sa porovnáva (dôležité):** záväzná identita väzby doska↔ABS je **`group_id`** — dekor je kľúč SKUPINY (D-41), nie globálne unikátny kód, a katalóg vedome dovolí
  dvom výrobcom rovnaký kód v rôznych skupinách. Preto: keď **oba** záznamy majú `group_id`, rozhoduje **výhradne skupina** (rovnaký kód v inej skupine ⇒ poznámka JE; iný zápis
  kódu v tej istej skupine ⇒ poznámka nie je). Keď skupina na niektorej strane chýba (**legacy záznam**), platí **vedomý fallback** na normalizované porovnanie textu dekoru
  (`decor_norm_key`: medzery preč, case-insensitive) — je to jediný údaj, ktorý taký záznam nesie, a mlčať by znamenalo stratiť poznámku aj tam, kde je preukázateľná.
  Skupiny sa porovnávajú v **kanonickom tvare** — tou istou normalizáciou (`Materials.identity_norm`: trim, viacnásobné medzery na jednu, case-insensitive), akou identity
  porovnáva zvyšok materiálového systému, takže `grp-x` a `GRP-X` sú **jedna** skupina (surová rovnosť reťazcov by z nich urobila dve a poznámka by klamala).
- **Tvar textu:** `ABS <dekor> <názov dekoru>` (napr. `ABS H1181 Dub Halifax tabakový`); bez názvu dekoru len `ABS H1181`. Viac RÔZNYCH pások na dielci → oddelené `, ` v poradí hrán L1 L2 W1 W2, bez opakovania toho istého dekoru. Diakritika ostáva (číta ju človek vo VEPO). Bez tvrdého orezu (na dielci sú najviac 4 pásky).
- **`universal` pásky sa NEVYNÍMAJÚ** — VEPO odvodzuje pásku z materiálu, takže KAŽDÝ odlišný dekor musí vidieť.
- **Dôkaz prijatia:** Michal 3.9.2026 naimportoval do VEPO testovací 9-stĺpcový súbor — VEPO ho prijal a poznámka sa zobrazila v poli **„Poznámka pre VEPO"** pri riadku, celá (31 znakov). **Na nálepky nejde** — je to výslovne poznámka pre VEPO.
- **LOG** dostal za oddielom „Riadky vyradené z CSV" oddiel `Poznámky pre VEPO (N riadkov):` s riadkami `  * <názov riadku> [<súbor.csv>]: <poznámka>` (pri nule `  (žiadne — všetky pásky v dekore dosky)`). Je to kontrolný zoznam pred odoslaním objednávky.

## Názov riadku `nazov` (v1.2, D-113 + D-121)

Platí LEN pre VEPO CSV a LOG — **kusovník Štúdia ostáva s plnými názvami**. Tvar: `<krátke názvy> <skrinky>`, napr. `Bok LP s1 s2 s3`.

- **TVRDÉ PRAVIDLO: názov má najviac 20 znakov** (`NAME_MAX = 20`). Nie je to estetika — **import objednávky VEPO dlhšie pole odmieta** (Michal 7.9.2026, overené v praxi),
  takže riadok nad limit sa nedá odoslať bez ručného prepisu. Limit má jednu autoritu (`VepoExport::NAME_MAX`); Kontrola aj LOG ju čítajú odtiaľ.

- **Skratky** (presná zhoda na názvy z builderov; neznámy názov ide BEZ ZMENY): `Bok lavy`→`Bok L` · `Bok pravy`→`Bok P` · `Vystuha predna`→`Vyst P` · `Vystuha zadna`→`Vyst Z` ·
  `Sokel predny`→`Sokel` · `Priecka zvisla`→`Priecka Z` · `Priecka vodorovna`→`Priecka V` · `Dvierka N lave/prave`→`Dv<N> L`/`Dv<N> P` · `Dvierka N kridlo i/n`→`Dv<N> k<i>` ·
  `Dvierka N`→`Dv<N>` · `Zasuvkove celo N`→`Zas celo N`. `Dno`, `Vrch`, `Chrbat`, `Polica N`, `Blenda N`, `Výklop N`, `Sklop N` a názvy samostatných dosiek (voľný text) sa nemenia.
- **Vyrábané dielce zásuvky (D-121a, 8.9.2026):** `Dno zasuvky N`→`Zas dno N` · `Chrbat zasuvky N`→`Zas chrb N` · `Vnutorne celo zasuvky N`→`Zas predok N` ·
  `Bok boxu lavy/pravy N`→`Zas bok L/P N`; dvojica bokov jednej zásuvky v riadku → `Zas bok LP N`. `N` je **číslo čela** — to isté, aké nesie `Zasuvkove celo N`.
  **Legacy:** zákazka postavená pred D-121a má v názve namiesto čísla interné id čela (`Dno zasuvky Fmslwqdm2-9-464wsa`) — dostane tvar **bez čísla** (`Zas dno s1`);
  id sa do skratky neprenáša, lebo človeku nič nepovie. Číslo sa v názve objaví po najbližšej prestavbe skrinky.
- **Združenie dvojíc** v jednom riadku: `Bok L`+`Bok P`→`Bok LP` · `Vyst P`+`Vyst Z`→`Vyst PZ` · `Dv<N> L`+`Dv<N> P`→`Dv<N> LP` · `Zas bok L<N>`+`Zas bok P<N>`→`Zas bok LP<N>`. Ostatné rôzne názvy sa spájajú `/` (napr. `Dno/Vrch`) v poradí, v akom prišli.
- **Zlúčenie číslovaných tokenov (v1.2, po združení dvojíc):** tokeny tvaru `<základ> <číslo>` s rovnakým základom sa zlúčia do jedného — čísla vzostupne, unikátne, zlúčený
  token stojí na pozícii prvého člena: `Polica 1/Polica 2/Polica 3` → **`Polica 1 2 3`** · `Zas dno 1/Zas dno 2` → **`Zas dno 1 2`** · `Zas celo 1/2/3` → **`Zas celo 1 2 3`** ·
  `Zas bok LP 1/Zas bok LP 2` → **`Zas bok LP 1 2`** · `Polica 1/Polica 12` → **`Polica 1 12`**. Číslo musí byť **na konci** tokenu, preto `Dv1 LP/Dv2 LP` ostáva s `/`.
  Zlučujú sa **výhradne tokeny zo skratky generovaného názvu** — voľné názvy dosiek nikdy, ani keď vyzerajú číslovane (`Polička 1` + `Polička 2` môžu byť dve rôzne veci).
- **Voľné názvy samostatných dosiek sa NEMENIA ani nepárujú.** Názov dosky je voľný text používateľa, nie názov z buildera — doska pomenovaná `Bok lavy` ostáva `Bok lavy`
  (žiadna skratka) a s dielcom skrinky sa nikdy nespojí do `Bok LP`. Pôvod nesie riadok kusovníka v aditívnom kľúči `free_names` (`Bom.aggregate_rows`), lebo riadok môže byť
  zliatok dosky a dielca skrinky. Ak ten istý reťazec prispela doska **aj** skrinka, platí konzervatívna cesta: pass-through bez skratky a bez páru.
- **Skrinky** z `kde` riadku: `CAB-001`→`s1`, `CAB-012`→`s12`, samostatná doska `BRD-007`→`d7`. Unikátne, zoradené (skrinky, potom dosky, každé podľa čísla); prázdne `kde` = bez prípony. Neznámy tvar ID ide celý a až za nimi.
- **Orez (v1.2):** skrinky sa pridávajú, kým sa zmestia do 20 znakov; nezmestené zhrnie ` +K` (K = počet) — skratka sa **nikdy neroztne v polovici**. Keď je nad limit už
  samotná časť s názvami, reže sa **po hranici tokenu**: padne-li rez presne na medzeru alebo `/`, berie sa celý 20-znakový začiatok, inak sa **rozseknuté slovo zahodí**
  (rez na poslednom oddeľovači). Jedno dlhé slovo (typicky voľný názov dosky) oddeľovač nemá — tam platí tvrdý rez na 20. **Výpustka `…` sa nepoužíva** (minie znak a nálepka
  interpunkciu aj tak netlačí). Príklady: `Polica 2 3 4 5 6 7 10` → `Polica 2 3 4 5 6 7` (nikdy `…7 1` — štítok by uvádzal policu 1 namiesto 10) ·
  `Doska pod umyvadlo/Polica nad pracku` → `Doska pod umyvadlo` · `Polička pod televízorom veľká` → `Polička pod`. Pri oreze sa skrinky **už nepridávajú**.
- **Orez nie je tichý (v1.2):** LOG má medzi „Riadky vyradené z CSV" a „Poznámky pre VEPO" oddiel **„Skrátené názvy (N):"** s riadkami
  `  * <plný> -> <skrátený> [súbor.csv] — <dĺžka>×<šírka>×<hrúbka>, <ks> ks @ CAB-001` (rozmery a vlastníci robia riadok jednoznačným aj vtedy, keď sa dva rôzne názvy orežú
  na ten istý reťazec); pri nule `  (žiadne)`. **Kontrola** (Štúdio) navyše ukáže ORANGE nález `name_long` s presným tvarom, ktorý pôjde do objednávky.
  **Kontrola hodnotí AGREGOVANÉ RIADKY, nie jednotlivé dosky** — dve dosky s krátkym názvom môžu skončiť v jednom riadku a spoločný názov sa oreže; hodnotenie per doska by
  taký prípad prehliadlo.
- **Vedomé obmedzenie:** keď sa názov zmestí, ale **skrinka už nie** (`Zas celo 1 2 3 4 5 6` = presne 20 znakov), Kontrola mlčí — nie je to strata dielca, len horšia
  orientácia v dielni. Riadok je iba v LOGu, s dôvodom „bez skrinky v názve".
- **Prečo:** dielec príde z VEPO označený názvom z CSV, takže bez skrinky nebolo pri skladaní vidno, kam patrí. Nálepky VEPO tlačia **max 20 znakov bez interpunkcie**
  (medzeru mení ich stroj na `_`), takže na orientáciu je použiteľných ±20 znakov názvu — preto skratky a skrinky hneď za názvom; orez ďalších skriniek Michalovi nevadí.
  **A od v1.2 je 20 znakov aj tvrdá hranica samotného IMPORTU** — objednávkový formulár dlhšie pole `nazov` neprijme, takže limit nie je odporúčanie, ale podmienka odoslania.

## Normalizácia hrúbok (VEPO očakáva obchodné hrúbky)

- 18.0–19.1 mm → **18**
- 36.0–38.1 mm → **36**
- ostatné → zaokrúhliť na celé
- hrúbka ≤ 0 = chybný dielec (do exportu nejde, loguje sa)

## Delenie do súborov (grouping)

- Dielce sa delia podľa **materiál + hrúbková skupina**; voliteľne merge 18+36 do jedného súboru (tag `18_36`)
- **Názov súboru:** `<projekt_slug>_<material_slug>_<hrubka_tag>.csv`
- **Slug:** slovenská/česká diakritika → ASCII (á→a, č→c, ž→z…), nealfanumerické → `_`, lowercase, bez dvojitých/krajných `_`
- Popri CSV sa píše LOG súbor (projekt, verzia, dátum, zoznam skupín, chyby)

## Vstupný kontrakt pôvodného flow (OCL CSV) — len pre referenciu/validáciu

Pôvodný reťazec: OCL export CSV (BOM UTF-8, oddeľovač `;` alebo `,` auto-detekcia) s hlavičkami (CZ/SK): `označení (název/názov)`, `délka/dĺžka`, `šířka/šírka`, `tloušťka/hrúbka`, `počet/ks`, `hrana podél 1/2`, `hrana napříč 1/2`, `druh materiálu`, `název/názov materiálu`. Z hodnôt hrán sa počíta len „má číslo / nemá číslo" na každej strane. Názvy sa čistia od HTML tagov.

## Čo z toho vyplýva pre dátový model dielca v novom systéme

Dielec musí niesť minimálne: **názov, dĺžka, šírka, hrúbka (reálna aj obchodná), počet, materiál (názov pre VEPO), hrany 4× samostatne (l1, l2, w1, w2 — nie len súhrnný kód!), príznak
  rotácie/orientácie dekoru**. Súhrnné kódy `—`/`=` sa DOPOČÍTAJÚ pri exporte — v modeli držíme plné info per strana (lebo `—` nevie povedať KTORÁ strana; pre CNC a kusovník to potrebujeme presne).
  **Rozmery v exporte = hotové rozmery bez úprav** — ABS hrúbky sa NIKDY neodratávajú (robí to VEPO); plné per-strana info o hranách ostáva v modeli pre budúce CNC/nárezové výstupy.
