# M-R VZHĽAD — návrhový a implementačný podklad (11.9.2026)

> Stav: KONCEPT — návrhový podklad po audite a používateľskom schválení; platný rozsah určuje PLAN.md, dátový kontrakt STANDARD.md a hotové API docs/architecture/materials.md.

Stav: Michal schválil používateľský návrh aj implementáciu 11.9.2026. Spoločný vzhľad dosiek a ABS rovnakého povrchu nahrádza pôvodnú oddelenú ABS voľbu. Prvá dávka MR-1A pripravuje katalógový kontrakt; natívny adaptér, mapovanie a ovládanie nasledujú v samostatných dávkach. Východiskový main b41c4f8 / v0.11.0. Prvý návrhový audit: 0 BLOCKER, 5 FIX zapracovaných do tohto návrhu. Návrhové mená ešte nie sú zárukou existujúceho API.

## 1. Uzavreté produktové rozhodnutia

- Voliteľná textúra. Dnešná plošná farba, jej editor a skupinové pravidlá fungujú bez súboru a bez kroku Uložiť vzhľad.
- Jeden uložený vzhľad pre rovnakú dekorovú skupinu a rovnaký povrch naprieč hrúbkami, **spoločne pre DOSKY AJ ABS**. Michal 11.9.2026 po schválení mockupu výslovne zjednotil tieto dva rozsahy; samostatný ABS override sa nezavádza. Lesklý a matný povrch sa nezlučujú. Nová doska aj ABS preberú spoločný vzhľad.
- Zástena používa tento jediný vzhľad na oboch dekorových plochách. Rubové objednávkové údaje ostávajú bez vizuálnej väzby.
- Priradiť vlastný obrázok, upravovať mierku/vlastnosti v natívnom SketchUpe, výslovne Uložiť vzhľad do knižnice. Bez vlastného PBR editora či automatického sledovania každej zmeny.
- Orientácia používa existujúci smer dekoru. ABS má stabilnú orientáciu po hrane bez ďalšieho používateľského prepínača.
- Bez zásahu do výrobného snapshotu, rozmerov, ABS množstiev, kovania alebo cien.

## 2. Dávky a brány

1. **MR-1A Knižnica:** voliteľný kontrakt, spoločný rozsah, atómová publikácia a zachovanie vo všetkých katalogových zápisoch. Zatiaľ bez nového ovládania.
2. **MR-1B Natívny materiál:** načítanie/uloženie .skm, zachovanie živých úprav, návrat k farbe, identita a stavy chýbajúceho súboru. Úzka integračná sonda sa zmení na testy.
3. **MR-2 Štúdio:** schválený kompaktný mockup nad hotovým jadrom; strážené akcie a jasný výsledok knižnica/model.
4. **MR-3 Smer a uzáver:** spoločný mapovací helper, skrinky/dosky/ABS, reálny skúšobný model a regresie. Ak MR-2 potrebuje modelový Apply, helper a jeho testy musia byť pripravené skôr; používateľské ovládanie sa nesmie vydať s nekorektnou orientáciou. Integrácia po malých PR, vždy fresh main, žiadne stackovanie.

Michal 11.9.2026 schválil mockup aj pokračovanie implementáciou, s jediným doplnením spoločného vzhľadu pre dosky a ABS. Pred implementáciou sa kontroluje delta spoločného scope a zapracovaných nálezov. Každý implementačný PR má vlastné testy, verziu a review podľa CLAUDE.md. Blok je hotový až po MR-3 a používateľskom smoke.

## 3. Katalógový kontrakt MR-1A

### Rozsah

Autoritatívny helper nad čerstvým katalógom odvodí scope z dvojice **platné group_id, normalizovaná structure**. kind sheet/edge iba identifikuje cieľový záznam callbacku, NIE rozsah vzhľadu. Hrúbka, šírka ABS ani formát do scope nepatria. Použiť rovnakú normalizáciu povrchu ako dnešné zoskupovanie UI; nevytvoriť odlišné Ruby/JS pravidlá. Identitu skupiny neodhadovať z mena/decor substringu. Legacy záznam bez platného group_id sa bez tichej migrácie nesmie zlúčiť s inými záznamami; pri požiadavke na spoločné uloženie vyžiadať opravu skupiny dnešnou cestou. Prázdna structure je vlastný rozsah, automaticky nepreberá vzhľad iného povrchu.

Pracovné materiály **UNI sú vylúčené** zo všetkých nových appearance mutácií, dedenia a Apply, vrátane native vzhľadu bez obrázka. Ostávajú dnešnou farebnou značkou nevyriešeného výrobného materiálu. Guard je na serveri aj v UI, nie iba skryté tlačidlo. Normalizácia povrchu je presne trim + kolaps vnútorných whitespace + uppercase ako mdStructureSections; ST9 a ST 9 tým zostávajú rozdielne.

Skupina zostáva odvodená zo záznamov. Žiadna nová perzistentná tabuľka skupín. Rovnaký descriptor je serverom zapísaný do všetkých členov scope v jednej existujúcej katalógovej transakcii. Duplák dostáva descriptor svojho zdroja a nemá vlastný nezávislý override.

### Voliteľné pole appearance

Záznam dosky aj ABS môže mať uzavretý objekt:

- `{ "version": 1, "id": "<server-generated UUID>", "mode": "native" }` — nemenný uložený .skm;
- `{ "version": 1, "id": "<server-generated UUID>", "mode": "color" }` — výslovné odstránenie uloženého vzhľadu, návrat k dnešnej farebnej ceste;
- chýbajúce pole — doterajší katalóg, obyčajné farby bez nového nároku na súbor.

Descriptor nesie aj serverový saved_at v UTC ISO8601 pre pravdivé „posledné uloženie“. Nie je to dôkaz, že natívny materiál odvtedy nebol upravený. appearance.id označuje **revíziu spoločného vzhľadu**, nikdy material_id/abs_id konkrétnej hrúbky.

Tombstone color rozlišuje odstránenie od chýbajúceho súboru/starého katalógu. Nie je samostatnou uloženou farbou: RGB naďalej žije v pôvodnom color. Vzhľad native môže obsahovať iba farbu + natívne vlastnosti, obrázok nie je povinný. PBR vlastnosti nezdvojovať do JSON.

Súborová cesta sa odvodí z validovaného id v známom knižničnom priečinku; žiadna cesta z UI. appearance prejde oboma normalizátormi, required_schema_for ho zaradí do novej schema 10 až keď je prítomný. Existujúci schema9 katalóg iba s farbami sa samotným otvorením nemení. Neznámy/poškodený appearance sa nesmie ticho zahodiť a následne zapísať ako farebný: zastaviť appearance mutáciu a zachovať existujúcu ochranu katalógu.

### Zápis a odvodené cesty

- Vlastný účelový zápis prijíma kind, anchor_id, očakávanú revíziu/scope baseline a interný uložený descriptor. Pod existujúcim cross-process lockom načíta zdravý čerstvý katalóg, overí schému a baseline vrátane členstva; nespolieha sa iba na procesový cache read-only flag. Při stale/kolízii obnoviť formulár, neprepísať cudziu zmenu.
- Nový .skm sa uloží do staging súboru, overí, dokončí ako nový nemenný súbor; až potom sa publikuje descriptor do JSON. Neúspech JSON ponechá starý descriptor/súbor, môže nechať osirelý nový súbor. Žiadne okamžité mazanie starých revízií ani nový GC v tomto bloku. Náhľad nie je podmienkou zachovania .skm; jeho zlyhanie má pravdivý fallback.
- Generické patch/edit polia nesmú prijať appearance z klienta. save_decor, ceny, Demos refresh a legacy variant editor ho zachovajú zo serverového záznamu; legacy existing.merge(data) musí explicitne odstrániť tento kľúč z dát klienta. **V každom upserte sa appearance preberá až z čerstvého riadka vnútri zámku**, vrátane jeho neprítomnosti; záznam zostavený pred zámkom nie je autorita. Platí aj pre upsert_sheet_with_duplak_sync a ABS upsert, pred normalizáciou a sync duplákov. Test: otvorený starý editor → druhý proces uloží native/color → prvý uloží cenu → nový vzhľad prežije.
- Nové varianty cez add_decor_batch_v3/save_decor/Demos/autoABS preberú jednoznačný descriptor svojho scope. Pri viacerých odlišných descriptoroch sa **automatické dedenie odmietne**; žiadny náhodný prvý záznam. **Explicitné nahradenie vzhľadu celého scope je povolená náprava:** formulár dostane čerstvé členstvo a baseline všetkých descriptorov, účelový zápis ich pod zámkom overí a nahradí jedným novým native/color descriptorom. Toto nie je automatické dedenie a konflikt sám túto nápravu neblokuje. Zmena baseline medzi potvrdením a zápisom stále znamená stale. Dnešné bežné úpravy cien sa kvôli nesúladu vzhľadov plošne neblokujú.
- sync dupláku pokrýva native aj color descriptor; zmena zdroja, explicitné odstránenie a nový duplák majú test. Reparenting variantu/decor edit buď prevedie na jednoznačný cieľový scope, alebo mutation odmietne s vysvetlením. Pôvodný descriptor sa nesmie preniesť do inej rodiny náhodným merge.

## 4. Natívna cesta MR-1B a modelové zmeny

Natívne .skm je úplný kontajner. Nekopírovať jeho vlastnosti po jednotlivých poliach: sonda odhalila odlišné výsledky colorize a host 26.0 nemá Material.duplicate. Materials.load môže reuse alebo vrátiť nový objekt; výsledok treba identifikovať a validovať, nie slepo premenovať alebo mazať.

Existujúce ensure_su_material/ensure_su_edge_material zostanú vstupné body, ale dostanú dočasný kontext účelu (nový vklad/prestavba) a overeného pôvodného materiálu. **Pred clear!** korpusu sa z pôvodných dielcov zachytia väzby part_key/rola/material_id a ABS slot/abs_id na živé material handles; doska zachytí svoju väzbu pred prekreslením. Kontext sa používa iba pri prestavbe toho istého vlastníka, nezmenenom príslušnom výrobnom ID a jednoznačnom pôvodnom dielci. Nový vklad, zmena ID alebo nový dielec využíva aktuálnu knižničnú revíziu. Nevyberá sa iná skrinka s rovnakým material_id ako náhrada za stratený pôvodný handle. Kontext žije iba počas stavby, nič nepridáva do výrobného snapshotu.

Natívna identita pre native vzhľad je v oddelenom namespaci **scope_key = [group_id, normalizovaná structure] + appearance_id**. Neobsahuje kind ani ID hrúbkového variantu. Všetky dosky aj ABS toho istého scope/revízie smú zdieľať jeden handle; iný scope alebo revízia sa obsahovou zhodou nezlučuje. Čistá farebná cesta naďalej rozlišuje dnešné material_id/abs_id a používa aktuálne RGB. Pri load sa overí celý očakávaný tuple; pri nekompatibilných metadátach sa výsledok nesmie preoznačiť ani vizuálne upraviť, Apply sa odmietne bez straty starého modelu.

Každý nový knižničný .skm sa serializuje s interným menom **NOXUN_APPEARANCE_<appearance.id>_NATIVE** a správnym scope/revíziou v metadátach. Nekončiť priamo UUID: izolovaná sonda 11.9. dokázala, že dvojicu zhodných obsahov s podobnými UUID končiacimi 301/302 host zlúčil; prípona _NATIVE ich oddelila a opakované načítanie tej istej revízie ju správne znovu použilo. Interpretácia číselného konca ako suffixu je inferencia, nie zdokumentovaná záruka API. Preto sa vždy overuje tuple načítaného materiálu.

Exporter pri explicitnom Save použije krátku vlastnú guarded modelovú operáciu: zachytí zdroj, dočasne nastaví iba meno a appearance metadata pre serializáciu, save_as do staging súboru a v ensure operáciu abortuje, aby sa obnovilo pôvodné meno aj metadata zdroja. Až potom overí súbor a publikuje knižnicu. Dočasná operácia sa nesmie vnoriť do inej otvorenej NOXUN operácie. Sonda v SU26.0.429 teraz dokázala obnovenie zdroja/PBR po aborte, správne exportované metadata, oddelenie R1/R2 s príponou, zhodu PBR a pixel hashov aj reuse rovnakej revízie. Produkčná integrácia, chyby a lifecycle stále vyžadujú MR-1B testy. Žiadne ručné kopírovanie PBR, žiadna úprava cudzej geometrie.

Pri kopírovaní/reopen zostáva tuple na natívnom materiáli; jeho ručné premenovanie tuple nemení. Ak je materiál už overene priradený pôvodnému dielcu, má pri prestavbe prednosť aj bez lokálneho .skm. Legacy materiál rozpoznávať doterajším presným menom iba pri potvrdenej väzbe z parametrického dielca. Konflikt živých kandidátov sa neháda podľa prvého mena.

- **Dnešná čistá farba:** zachovať súčasný RGB sync a spôsob dedenia plôch. Nemusí vzniknúť .skm alebo aktívna appearance metadata.
- **Uložený vzhľad/živá natívna úprava rovnakej revízie:** rebuild používa živý materiál, neprepisuje ho RGB a nenačítava stále pôvodný .skm. Rozpoznanie ručnej textúry/PBR pri legacy materiáli nesmie súčasne označiť každý obyčajný starý materiál za chráněný.
- **Nová knižničná revízia:** načítať plný .skm a pri explicitnom Apply/Save aktualizovať iba oprávnené objekty aktuálneho modelu. Starý objekt materiálu sa vizuálne neupravuje in-place. Reuse je povolené iba pri kompatibilnej natívnej identite podľa predchádzajúceho odseku; samotná obsahová zhoda nestačí. Nový vklad využije najnovšiu dostupnú uloženú revíziu, bežný rebuild zachová lokálne neuložené úpravy svojej revízie cez zachytený kontext.
- **Explicitné color:** vytvoriť čistý natívny materiál s aktuálnou katalógovou farbou a prepnúť oprávnené dielce; nečistiť starý materiál po jednotlivých PBR poliach. Návrat do štandardnej farebnej cesty musí znova umožniť bežné zmeny farby. Vzhľadový rozsah nemení doterajší rozsah RGB.
- **Chýbajúci/nečitateľný .skm:** ponechať existujúci natívny vzhľad modelu. Keď neexistuje, použiť doterajšiu farbu a zobrazit stav dostupnosti; nejde o explicitné odstránenie. Stejně u chýbajúceho katalógového záznamu nepřemaľovať existujúci model pri otvorení.

Publikácia knižnice a modelový Apply nie sú jedna atómová transakcia. Najskôr dokončiť knižnicu, potom samostatná guarded SketchUp operácia nad stále správnym dokumentom. Keď Apply zlyhá, model abortovať a pravdivo oznámiť „Vzhľad uložený, model sa nepodarilo aktualizovať“; umožniť opakovať Apply existujúcej revízie bez vytvárania ďalšieho .skm. Undo vracia iba model, knižnica ostáva uložená. Iné otvorené modely sa na pozadí nemenia.

Aktívny editovaný materiál a cieľ zachytiť pred otvorením natívneho editora. Uložiť nesmie náhodne vziať materials.current, ak používateľ medzitým zvolil iný materiál. Guard: token + konkrétny model/DocKey + cieľ scope + baseline revízia + stále platný material handle; busyLock proti súbehu. Pri zmene sekcie/cieľa/modelu alebo zániku materiálu session zneplatniť. File dialog cancel nezapisuje. Otvorenie/read/preview formulára nikdy nemutuje.

## 5. Mapovanie MR-3

Jeden helper pre nový finálny part a explicitný modelový Apply. Dekorové plochy určuje min/max T cez existujúce verified_axes, nie dve najväčšie plochy. UV vzniká z aktuálnej fyzickej mierky natívnej textúry a L/W podľa existujúceho grain/override; žiadna zmena výrobných rozmerov. ABS ide po vlastnej fyzickej hrane. Odstrániť dnešnú RGB-only skratku paint_edge_faces iba tam, kde nepreukazuje zhodný vzhľad. Jednofarebná cesta ostáva dnešná.

Apply nesmie použiť EdgeCheck.each_part bez úpravy: skrýva hidden a zahrňuje odpojené dielce. Cieli parametrické korpusy/boards vrátane skrytých, overený generovaný kváder, rolu, snapshot, material/abs id a jednoznačné osi. Vynechá cudzie entity, UKW aluminium proxy, odpojené dielce a neoveriteľnú/custom geometriu s počtom preskočených. Pri zdieľanej definícii izolovať oprávneného vlastníka pred zmenou plôch; žiadny rebuild/resolver/Store.write iba kvôli vzhľadu. Jedna modelová Undo operácia, bez nového observera.

Natívna mierka po UV funguje bez observera (sonda 100→200 mm dala UV1→0,5). Ručné UV posunutie jednotlivej plochy nie je nový trvalý override; vedomé Apply/rebuild ho môže premapovať podľa smeru dekoru.

Prenositeľnosť v tomto bloku = .skp uchová natívne zobrazenie bez dostupnosti lokálneho .skm. **Kompletný rebuild bez celého katalógu nie je sľubovaný:** dnešný korpus môže stratiť grain na none. Jeho fallback by menil výrobný snapshot a patrí prípadnej samostatnej dávke. Žiadna cloudová synchronizácia knižnice.

## 6. Minimálne dôkazy pred vydaním

- Pure: schema9 bez zmeny, schema10 roundtrip oboch druhov, native/color/absent, odmietnutie poškodeného descriptoru, forward guard, konflikt a jeho explicitná náprava, atómové zlyhanie, shared scope + nový variant + duplák + Demos/legacy editor preservation; stale legacy editor po cudzej zmene vzhľadu; UNI odmietne native aj color aj bez obrázka.
- Native: plný .skm roundtrip vrátane farebného materiálu s vlastnosťami; serializácia unikátneho interného mena/metadát s obnovením zdroja pri úspechu i chybe; dve hrúbky jednej revízie reuse bez preoznačenia; obsahovo zhodné R1/R2 bez kolízie; skrinka A so živou R1 + nová B/R2 → rebuild A zachová R1; ručne premenovaný materiál, UV a živé úpravy; odstránenie→bežná farba; chýbajúci súbor; cudzí objekt používajúci starý materiál; model save/reopen. Minimum SU2024 ostáva; PBR podmienené API dostupnosťou, na 2024 nesľubovať novšie vlastnosti.
- UI: oneskorená odpoveď po zmene cieľa/modelu, zrušený výber súboru, double submit, zlyhanie knižnice vs zlyhanie modelu, neúspešný náhľad; jedna akcia pre dosky aj ABS všetkých hrúbok, iný povrch ostáva nezmenený.
- Skúšobná skrinka + dosky: bok/polica/čelo UKW/zásuvka, spoločná textúra dosky/ABS a kontrastná ABS z inej skupiny pri rovnakej RGB, duplák a obojstranná zástena; insert/rebuild/scale/copy/template/UNI/save/reopen/Undo + používateľské Redo. BOM/VEPO/ceny pred a po vzhľadovej operácii zhodné.

Stop pravidlo auditu: riešiť skutočné porušenia vyššie uvedených záruk. Nové funkcie (cloud, regenerácia bez katalógu, ručné UV overrides, PBR editor, GC) odložiť. Ak jadro potrebuje ďalšie mechanizmy, zúžiť dávku skôr než pridať všeobecný framework.
