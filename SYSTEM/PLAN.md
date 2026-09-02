# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (uzáver etapy = minor bump).
> **Údržba:** pri uzávere dávky sa jej riadok z bloku odstráni, odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a prepíše sa [STAV.md](STAV.md). Plné znenie otvorených postrehov žije v [DOGFOODING.md](DOGFOODING.md) **v skupinách podľa týchto blokov** — tu je len číslo, názov a jedna veta.

## Bloky

*(Blok **1 · UI 2.0 — štúdio okno a výbery** je uzavretý (v0.8.0, 24.8.2026) — plný text
je v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md). Čísla ostatných
blokov sa kvôli odkazom v STAV a KRONIKE neprečíslúvajú.)*

**Poradie najbližších blokov (rozhodol Michal 26.8.2026; revízia 27.8.2026 — kvôli koncu MAX plánu 2.9. sa 1e predsunulo pred 1d):**
**1b STABILIZAČNÁ REVÍZIA → 1c AUDIT KÓDU → 1e PLÁNOVACIA DÁVKA (task packages) → 1d REFAKTOR Z REGISTRA (beží súbežne s 1e cez subagentov a pokračuje aj po 2.9.) → ~~GHOST VKLADANIE~~ → KOVANIE**
(pred KOVANÍM USER-debata o setoch). Zmysel sekvencie: audit a refaktor **pripravujú pôdu presne pre naplánované funkcie** a doťahujú staré dlhy — až potom nové funkcie;
1e ide skôr, lebo kvalitné packages sú podmienkou, aby implementáciu 1d a ďalších blokov zvládli agenti bez Fable.
*(Blok **PICKER-3** je hotový — v0.8.5, 26.8.2026; plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md), výsledok v [archiv/KRONIKA.md](archiv/KRONIKA.md).)*
*(Blok **GHOST VKLADANIE** je hotový — **v0.9.0, 31.8.2026** (PR #265/#268/#270/#271 + uzáver), potvrdený Michalovým smoke;
plný text vrátane výsledku je v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md), priebeh v [archiv/KRONIKA.md](archiv/KRONIKA.md).)*

### 1b · STABILIZAČNÁ REVÍZIA (dlhy fázy ŠTÚDIO — pred blokom KOVANIE)

**Cieľ:** doplatiť dlhy, ktoré fáza ŠTÚDIO vedome odložila, a spraviť refactory, na ktoré počas presunov nebol priestor.
*(Stabilizačná revízia sa od začiatku produkcie naostro (20.8.) ešte NEKONALA — patrí pred ďalšie nové funkcie.)* Poradie určí Michal.
Staré dlhy B–F nie sú blokujúce pre bežnú prácu (**B a D vybavené dávkou 1b-4, v0.8.8, 27.8.**; **sweep E je HOTOVÝ, 27.8.**; z písmen ostáva už len **F**;
mimo písmen vybavené aj **1b-6a** — názov zákazky prežije prvé uloženie, v0.8.9, 27.8. — · **1b-7** — koniec tichého návratu starej ceny dekoru, v0.8.10, 27.8. — a **1b-6b** —
rozlíšené hlavičky materiálov, v0.8.11, 27.8. — a **1b-6c** — zámok nad `vepo_settings.json`, v0.8.12, 28.8.; mimo písmen tak neostáva nič otvorené);
**P0 odrážky A, G a H sú BRÁNY a VŠETKY TRI SÚ HOTOVÉ** — **A** (možná STRATA rozpísanej editácie) dávkou 1b-1, v0.8.6, 27.8. ·
**H** (charakterizačné in-SU scenáre) dávkou 1b-2, 27.8. — cesta k builderom/observerom pre blok 1d je tým otvorená; sadu `CHAR` **dorovnala dávka 1b-5** (27.8., test-only) po
post-hoc Codex kole na #239: štyri asserty boli zelené, ale merali slabšiu veličinu, než tvrdili · **G** („Obnoviť" = čisté čítanie) dávkou 1b-3, v0.8.7, 27.8. —
na „Obnoviť" sa teraz smie postaviť ďalšia kontrola (plošná kontrola D-95 má garanciu, že zapnutie kontroly nemení model ani Undo).

**A · Optimistický zámok nastavení (dlh z #227, kolo 4) — ✅ VYRIEŠENÉ dávkou 1b-1, v0.8.6 (27.8.2026).**
Obe chyby aj obidva slabšie dôkazy sú vybavené: pin sa uvoľňuje v `ssRenderBody` (pokrýva push aj návrat do sekcie — koniec falošných konfliktov a stratených editácií)
a hláška sa vetví podľa výsledku prepočtu (`refresh_and_report`; zlyhanie povie „uložené áno, prepočet nie"). `ssTyping` má DOM dôkaz, mutácia poradia pin-release padá
behaviorálne. Plný záznam — čo bolo zle → čo platí, zamietnuté alternatívy, 6 mutácií: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-1** (27.8.2026).

**B · Sekcia Šablóny (backlog z review #225) — ✅ VYRIEŠENÉ dávkou 1b-4, v0.8.8 (27.8.2026).**
Všetky štyri: PNG kanál má **retry po timeoute** (`TPL_ASKED` drží čas, nie `true`) a odpoveď sa nasadí len na dlaždicu s **tou istou revíziou** · dotazy idú **po dávkach**
(4 na prechod, vzhľad nezmenený) · `tpl_payload` je **orezaný na tvar dlaždice** (uzavretý zoznam kľúčov + `usage: false`; podmieniť ho otvorenou sekciou sa nedá a je
zdôvodnené prečo) · echo sa volá **`push_library_echo`** (okenné `StudioDialog.refresh_if_open` si meno drží právom). Plný záznam — čo bolo zle → čo platí, zamietnuté
alternatívy, mutácie: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-4**.

*(Sekcia „C · Kovanie" tu bola omylom: všetkých šesť položiek — rozdelenie „nastav dáta"/„kresli", kurzor v editore setu, jednotný `abort_open_operation`, odmietnutý reset cez `resync_sets`, čistenie
  `HW_Q`/`HW_CAT` v `MDH.created`, lepkavá MJ `#hn_unit` aj zhody Demosu po návrate do sekcie — opravila **mini dávka ŠT-3a-3 (PR #219, v0.7.61)**. Zoznam pochádzal z NÁVRHU tej dávky, nie z jej
  výsledku. Overené v kóde pri review #228; nič otvorené v ňom nezostalo.)*

**D · Sekcia Pravidlá (NOTE z review #221/#222) — ✅ VYRIEŠENÉ dávkou 1b-4, v0.8.8 (27.8.2026).**
`edges_map` sa stavia **lenivo** (bez ABS riadkov zákazka za katalóg pások neplatí; duplicita s `control_payload`/`budget_payload`/`edges_meta` **zostáva priznaná** — zdieľanie
jednej inštancie naprieč pushom je zásah do kontraktu výstupov, kandidát pre register 1c) · riadok pri `disabled` vypisuje **víťaza** a uložené neuplatnené polia prizná v zátvorke ·
`override_group` **radí** (skrinka → dielec → položka, číslo ako číslo, **pred stropom**) a **nededuplikuje**, takže kandidátovi „zdvojené riadky pri duplicitnej identite"
(KRONIKA 1b-3) nekoliduje · mŕtve `material_id` **aj `pid`** sú zo záznamu zberu **preč**. Plný záznam: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-4**.
*(Otvorená ostáva jediná položka pôvodného zoznamu a je VEDOMÁ:* **duplicita s Kontrolou pri vypnutom kovaní** *— ORANGE nález + jantárový riadok hovoria o dvoch rôznych veciach
(správnosť vs. rozhodnutie) a formulácie sa držia oddelené.)*

**F · UI dlhy po zaniknutom bloku UI 2.0** — otvorené postrehy, ktoré blok UI 2.0 nevyriešil a ktoré po jeho archivácii (26.8.) ostali bez bloku. Zaradenie je **mechanické, nie prioritizačné**
  (poradie určí Michal). **D-27** (rýchle zobraziť/skryť tagy z panela) je **✅ VYRIEŠENÉ dávkou F/D-27, v0.8.13 (28.8.2026)** — okno tagov v raile Inspectora, jeden klik = jeden krok Späť,
  jeden stav pre okno aj checkbox ghost zón; bokom opravené kreslenie kontrol nad skrytými dielcami. Plný záznam: [archiv/KRONIKA.md](archiv/KRONIKA.md) a
  [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md). **Otvorené v F ostáva: D-51** štandard veľkostí okien a tlačidiel. Plné znenia sú v [DOGFOODING.md](DOGFOODING.md), skupina **„UI dlhy — k bloku 1b"**;
  *(výklop ako samostatný typ čela je od triáže 1e — 30.8. — PRESUNUTÝ do okruhu konceptu 07 / package bloku 4.)* Otvorené **D-106** / **D-107** sem pôvodne patrili tiež, dnes žijú vo svojich skupinách podľa zaradenia:
  D-106 v skupine V1 DOTIAHNUTIE (blok 4), D-107 v skupine Po V1 — zásobník.

**G · „Obnoviť" = čisté čítanie — ✅ VYRIEŠENÉ dávkou 1b-3, v0.8.7 (27.8.2026).**
Nález (P0 z externého auditu kolo 0, [zdroje/AUDIT_2026-08_externy_kolo0.md](zdroje/AUDIT_2026-08_externy_kolo0.md)) **platil** a je dokázaný mutačne.
`fresh_collect` je odteraz `Bom.collect` a nič viac — čítanie (refresh, `push_state`, klik-select, všetky štyri exporty) do modelu nezapisuje a nepridáva krok Späť;
stráži to guard nad CELOU UI vrstvou. Duplicitnú identitu Kontrola **prizná** (ORANGE `duplicate_identity` — hovorí aj výrobný dôsledok), opravu robí výhradne
zápisová cesta (dedup tik observera, `Panel.push_selected`). Zaniklo tým aj obmedzenie z review #222 P2-2. Plný záznam — prečo oprava v čítacej ceste vznikla,
zamietnuté alternatívy, 6 headless + 1 in-SU mutácia, in-SU scenár `CH7`: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-3**.

**H · Charakterizačné in-SU scenáre observer/Undo/multi-model — ✅ VYRIEŠENÉ dávkou 1b-2 (27.8.2026, bez bumpu verzie — pribudli len testy).**
Sekcia `run_char` v in-SU sade: **42 assertov** v šiestich scenároch (kópia · `*N` · Undo reťaz · prerušenie operácie · scale = regenerate výstup · prepnutie modelu, Windows vetva),
overené 7 zámernými mutáciami v dvoch kolách (11 + 6 cielených FAIL). **Dva scenáre sa na Windows spustiť nedajú a sú zapísané ako MANUÁLNE** priamo v INFO riadkoch behu: Znova
(Ctrl+Y) po scale a dva otvorené dokumenty naraz (macOS). Brána je splnená — **blok 1d smie siahnuť na buildery a observery.** Plný záznam (čo presne sa zafixovalo, nálezy slepého
review #239, mutácie, kandidát do registra): [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-2**.

**1b-6a · Názov zákazky sa po prvom uložení strácal — ✅ VYRIEŠENÉ, v0.8.9 (27.8.2026).** Nález nemá písmeno ani D-číslo: pochádza z **post-hoc triáže Codex threadov**
(PR #193, nález #30 ≡ #42) — teda z toho, čo odrážka **E** systematicky doťahuje. **Výrobná P2:** kto pomenoval zákazku v Štúdiu skôr, než model prvý raz uložil, dostal po Ctrl+S
VEPO, CSV kovania aj oba XLSX pomenované podľa `.skp` súboru namiesto zákazky (dáta boli správne, meno nie) — SketchUp pri uložení mení cestu **aj guid** naraz, takže záznam pod
starým guid kľúčom sa už nedal nájsť. Prvý pokus (**PR #243**) išiel do tretieho kola opráv a bol podľa **pravidla 3 kôl** zatvorený a rozdelený — do `main` z neho nešlo nič;
táto dávka je jeho **úzky re-rez**. Plný záznam — príbeh delenia, riešenie, zamietnuté alternatívy, 5 mutácií: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-6a**.

**1b-6b · Hlavičky skupín materiálov sú nerozlíšiteľné — ✅ VYRIEŠENÉ, v0.8.11 (27.8.2026).** P2 z triáže Codex threadov (PR #193, nález #33): menovka skupiny sa skladala len
z dekoru, štruktúry a názvu, takže záznamy líšiace sa **výrobcom, typom, formátom či rubom** mali v Kusovníku aj v súpise Platní **identickú hlavičku** — a podľa nej sa objednáva.
Výstupy teraz používajú **ten istý kolízny aparát ako Inspector**: bez kolízie sa hlavička nemení, pri kolízii sa eskaluje na panelovú menovku (výrobca → formát/rub → typ a hrúbka
→ poistka `[id]`); to isté dostal súpis ABS pások. Plný záznam — rozhodnutie o kolíznom kľúči, zamietnuté alternatívy, 2 mutácie:
[archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-6b**.

**1b-6c · Zápis `vepo_settings.json` pod jedným zámkom — ✅ VYRIEŠENÉ, v0.8.12 (28.8.2026).** Druhá a posledná časť delenia #243: šesť zapisovateľov jedného súboru nastavení
(`save_merge_18_36`, štyri zápisy `last_dir`, mapa `project_names`) ide odteraz cez **jedny zamknuté dvere** — medziprocesový zámok + čítanie súboru nanovo vnútri neho, takže dve
inštancie SketchUpu si už nemažú nastavenia ani mená zákaziek. Povinný `codex-audit` pridal do návrhu dva BLOCKERY (striktné čítanie v zápisovej ceste · názov aj pri nedostupnom
zámku) a tri opravy; overené aj **reálnym dvojprocesovým testom** `flocku`. Plný záznam — nálezy auditu, päť mutácií, vedomé odklady do 1c:
[archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-6c**.

**1b-7 · Tichý návrat starej ceny dekoru — ✅ VYRIEŠENÉ, v0.8.10 (27.8.2026).** Obe P2 zo sweepu (#212 · nálezy #8 a #9) mali jeden koreň — stará hodnota formulára sa spájala
s **čerstvým** `row_rev`, takže optimistický zámok prestal chrániť. Pamäť aj zotavenie z konfliktu dnes prelievajú **len bunky, ktorých sa používateľ naozaj dotkol**, a keď tú istú
hodnotu zmenil aj katalóg, formulár ukáže dvojicu *tvoja × v katalógu* a **bez rozhodnutia neuloží**. Plný záznam (vrátane vedomej zmeny správania oproti #212 a dvoch pascí, ktoré
si to vypýtalo): [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-7**.

**E · Post-hoc Codex sweep #186–#226 — ✅ HOTOVÝ (27.8.2026).** Dávky, ktoré 21.–24.8. prešli bránou so slepým subagentom, majú spätné Codex review; rozsah je uzavretý.
Otvorené nálezy z neho dostali vlastné dávky (**1b-7** — hotová, v0.8.10; **1b-6b** — otvorená) a jedna otázka ide do auditu **1c**. Kandidáti do registra 1c žijú v [zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md).
Plný záznam — metodika, čísla, bilancia slepých kôl a poučenie: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam **1b-E**.

*(Blok **1c · AUDIT KÓDU** je uzavretý (29.8.2026) — traja audítori (externý Codex · Fable · slepý subagent) sa zliali
do **[AUDIT_REGISTER.md](AUDIT_REGISTER.md)**: 2× P0 — **✅ HOTOVÉ dávkou P0-HF, PR #252, v0.8.14** (exportné brány; vrátane korekcie samotného auditu proti STANDARD §11.3 — *poučenie: nález auditu sa pred implementáciou overuje proti STANDARDU, nie preberá doslova*) — + 33 položiek z troch auditov (R-34/R-35 pribudli
neskôr z review kôl #252/#258 — dnes spolu 35) + odporúčané poradie pre 1d + 3 otvorené rozhodnutia Michala (R-05 rozsah pomeru · R-13 `std` na entite · R-30 jantárové riadky). Plný pôvodný text bloku:
[archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md); záznam s bilanciou: [archiv/KRONIKA.md](archiv/KRONIKA.md), záznam 1c.)*

### 1d · REFAKTOR/HARDENING Z REGISTRA (po 1c; **zásobník = [AUDIT_REGISTER.md](AUDIT_REGISTER.md)**, poradie dávok = sekcia „Odporúčané poradie" v ňom)

V 1d sa rieši **len to, čo je výrobné riziko alebo blokuje PONECHANÝ V1 rozsah** — nálezy viažuce sa výhradne na po-V1 témy
(DOCX/PDF renderer, G-Disk sync…) ostávajú v registri zaradené na neskôr, pred V1 sa pre ne nerefaktoruje.
Register sa vyprázdňuje **malými dávkami** (malé PR > obrie PR), zoradené podľa závažnosti × blokovanej funkcie.
Pravidlo podľa druhu dávky: **štrukturálny refaktor = „správanie sa nemení"** (presun zodpovednosti, testy to dokazujú);
**oprava chyby/hardening = explicitná, testom podložená ZMENA správania** (v PR pomenovaná: čo bolo zle → čo platí teraz).
In-SU testy povinné pri builderoch/observeroch; mutačné overenie štandard. Nálezy z reálnej výroby majú stále prednosť
(Pravidlo pre postrehy). Dávka, ktorá nevie povedať, ktorú naplánovanú funkciu pripravuje alebo ktorý dlh spláca, sa nerobí.

**Hotové dávky bloku 1d:** **R-06a** — brána dĺžkového kovania (úchytkový profil sa cez set už nenacení ako kusy), v0.8.15, 29.8.; plný `per: 'length'` ostáva pri R-05. ·
**R-08** — medziprocesový zámok pre zvyšných 5 globálnych katalógov (dve okná SketchUpu si už neprepíšu sety, pravidlá, ABS pravidlá, rozmerové rady ani nastavenia dodávateľa),
v0.8.16, 30.8.; zvyšok „úplná náhrada bez revízie" (globálne pravidlá kovania + rozmerové rady) je v registri ako **R-35**. ·
**R-01+R-04** — multi-model bezpečnosť observera veľkosti (udalosti aj požiadavky o upratanie nesú dokument, pamäť stabilných
polôh sa čistí po mazaní aj po zániku dokumentu), v0.8.17, 30.8.; zvyšok „erase bez známeho dokumentu" je v registri ako **R-36**. ·
**R-34** — presnosť brány P0-2 (zdieľané ID skriniek zastaví export len pri **skutočnom** zliatí kovania účtovaného na vlastníka; bez zliatia export prejde a ostáva
oranžový nález Kontroly), v0.8.18, 30.8.; priznaný zvyšok — dedup dvoch pravidiel na tej istej skrinke sa od dvoch inštancií nedá odlíšiť — je v zázname KRONIKY. ·
**R-02** — guard identity dokumentu v 18 zapisovacích handleroch panela (oneskorená akcia po prepnutí okna SketchUpu skončí hláškou, nie tichým zápisom
do cudzej zákazky), v0.8.19, 30.8.; jeden zdieľaný guard `foreign_document?` na serveri + jedno miesto `nxDocPayload` na klientovi, pri debounce sa identita
ZACHYTÁVA už pri naplánovaní editu a zmena dokumentu centrálne zahodí všetok rozpracovaný stav panela (Codex review kolá 1 a 2, 2+4× P1). ·
**R-03** — šev `prepare_insert` / `commit_insert` v builderi (skrinku sa dá pripraviť BEZ zásahu do modelu a položiť na presnú polohu; správanie dnešných
volajúcich sa nemení), v0.8.20, 30.8.; **tým padol TVRDÝ blocker bloku GHOST VKLADANIE** — package smie na Windows štartovať. Vedomé hranice (katalógový
seed v `normalize`, `build_plan` ostáva v commite, `bounds_mm` plán nenesie) sú zapísané v `docs/architecture/construction.md`. ·
**R-07** — kompatibilitná brána globálnej knižnice setov kovania (starší a novší plugin na jednom profile si ju už nepoškodia: knižnica z novšej verzie sa
nedá zapísať ANI použiť — súpis kovania ju prizná oranžovým riadkom a Štúdio bannerom s dôvodom, namiesto tichého orezania), v0.8.21, 30.8.;
degraded/`.bak` (**R-11**) sa nerieši, len sa mu nezavadzia. ·
**R-11** — brána degradovaného globálneho súboru (poškodený primár + platná `.bak`): plugin zo zálohy ďalej ČÍTA, ale zápisy do pokazeného súboru vypne a povie dôvod —
inak by prvý zápis prepísal primár obsahom odvodeným od STARŠEJ zálohy a všetko medzi zálohou a poškodením by zmizlo. Týka sa piatich stores (sety a pravidlá kovania,
ABS pravidlá, rozmerové rady, sadzby dodávateľa), v0.9.2, 1.9.2026; knižnica setov má degraded ako **vlastný stav** (obsah zálohy sa smie čítať aj použiť na projekt,
zakázané sú len zápisy do globálneho súboru). Codex audit návrhu vrátil 3 BLOCKERy + 2 FIXy + 1 NOTE — všetky zapracované, priznaný zvyšok je TOCTOU okno voči
zapisovateľom, ktorí zámok ignorujú. Do registra pribudli **R-37** (obsahovo zlý, ale tvarovo platný primár zničí dobrú zálohu už pri načítaní) a **R-38**
(`vepo_settings.json` — chýbajúci guard aj kanál na dôvod zlyhania).
**R-12** — dopredný guard configu korpusu (`config_schema`): zákazka z NOVŠIEHO pluginu už pri prestavbe ticho nepríde o nastavenia. Config je uzavretý whitelist,
takže polia, ktorým staršia verzia nerozumie, sa doteraz pri prvom rebuilde zahodili a uložením zvečnili. Marker sa zapisuje v jedinom zápisovom bode (vklad aj
prestavba), guard číta RAW uložený config a odmieta VÝHRADNE prestavbu a odvodené objekty (kópia, uloženie ako šablóna, použitie aj vklad šablóny) — čítanie,
kusovník, VEPO a exporty bežia ďalej; legacy skrinky bez markera prechádzajú, v0.9.3, 1.9.2026. Codex audit návrhu vrátil 2 BLOCKERy + 2 FIXy + 2 NOTE (všetky
zapracované). Priznané zvyšky: novšia KÓPIA si necháva zdieľané ID (ORANGE Kontroly + brána P0-2 exportov) a pri **scale** používateľ hlášku nedostane —
abort transparentnej absorpcie zruší aj jeho Scale krok, takže `reject_scale` sa nespustí (prevzatá vlastnosť observera, platí aj pre dnešný hardvérový guard). ·
**R-14** — verzia formátu dát rozpočtu (`budget_std`): zákazka z NOVŠIEHO pluginu už prvým klikom v Rozpočte ticho nepríde o dáta. Osem rozpočtových kľúčov na modeli sa číta cez
uzavreté whitelisty, takže neznáme polia sa doteraz orezali a zápisom zvečnili — a nasledujúci XLSX by niesol podhodnotené číslo. Marker aj guard žijú v jedinom zápisovom bode
`BudgetStore.write!` (údaj + marker = JEDNA operácia = jeden krok Späť), legacy zákazky bez markera prechádzajú a marker si zapíšu; nekompatibilná zákazka sa ďalej **číta**, ale
mutácie sú odmietnuté, obe sekcie (Rozpočet aj Cenová ponuka) nesú trvalý banner s dôvodom a **oba cenové exporty sú zastavené ešte pred výberom súboru** — VEPO a nákupný CSV
kovania bežia ďalej, v0.9.4, 1.9.2026. Codex audit návrhu vrátil 1 BLOCKER + 3 FIXy + 2 NOTE (všetky zapracované; blokuje sa nekompatibilná VERZIA dát, nie rozpracovanosť
rozpočtu — súlad so STANDARD §11.3). ·
**R-02b** — stabilný kľúč dokumentu (`core/doc_key.rb`) namiesto `Model#guid` vo VŠETKÝCH identity guardoch (Ctrl+S už nezahadzuje rozpísanú prácu panela,
zón, tagov, Štúdia, Pravidiel ani Materiálov; New/Open ďalej chráni pred zápisom do cudzej zákazky; Save As identitu vedome drží — Codex audit BLOCKER 3),
v0.8.23, 30.8.; priznaný zvyšok R-02 tým padol, JS aj tvar payloadov nezmenené. ·
**R-23.1** — Escape reťaz ručných modálov (`ui/js/nx_esc.js`): jeden dokumentový handler s prioritným zoznamom vrstiev zatvára aj posledných šesť modálov mimo kostry
D-15 (`absModal` v Inspectorovi; `mdRestoreModal`, `mdDeleteModal`, `mdUniModal`, `demosModal`, `hwDelModal` v Štúdiu) — jedno stlačenie = jedna vrstva, `budPrModal`
sa vo fáze `run` zavrieť nesmie, v0.9.1, 1.9.2026; review kolo 1 doplnilo dve triedy cudzích vrstiev (modály blokujú vždy, flyouty len bez otvoreného modalu)
a koreláciu otázky a odpovede pri „Nahradiť UNI…". Časti (2) a (3) položky R-23 (fokus späť na spúšťač, Escape `nxdaModal` mimo poľa hľadania) ostávajú otvorené.

### 1e · PLÁNOVACIA DÁVKA — task packages (po 1c, súbežne s 1d — revízia poradia 27.8.2026)

**STAV 1e (30.8.2026): packages hotové pre GHOST · M-R FOTO · D-94 · D-52 (PR #254/#255 — každý cez dve slepé
kolá; GHOST a M-R FOTO navyše korigované externým GLM review, PR #257); TRIÁŽ konceptov 01–09A je HOTOVÁ (tabuľka nižšie). Z 1e ostáva JEDINÉ:
package KOVANIE — vznikne po USER-debate o setoch (Michal).** Packages pre bloky 2/4 sa píšu pri ŠTARTE
príslušného bloku z konceptov nižšie (koncept je podklad, nie zadanie — README zdrojov platí).

| Koncept | Verdikt triáže (30.8.2026) |
|---|---|
| 01 D-95 plošná kontrola | podklad pre package pri štarte bloku 2 — AUTORITA znenia je riadok D-95 v bloku 2 (riadený prechod s odškrtávaním), koncept 01 je návrh rozšírenia; package ich zosúladí; stavia na garancii 1b-3, čaká aj rozhodnutie R-30 |
| 02 zostavy/segmenty | plné segmenty s `attachment` = PO V1 zásobník; V1 VÝSEK žije ako riadok „V1.0 zostavy" v bloku 4 (zarovnávanie, soklová lišta, krycie dosky) a koncept 02 je preň PODKLAD pri písaní package bloku 4 |
| 03 kovanie fáza 3 | blok KOVANIE — package po USER-debate o setoch; dáta SEED_KATALOG §2 |
| 04 + 04A spotrebiče S1 | podklad pre package pri štarte bloku 4 (V1-02); externý audit 04A platný |
| 05 shared library + updater | D-52 SPRACOVANÉ do package (#255); D-48 sync = PO V1 zásobník |
| 06 render M-R | quick-win SPRACOVANÝ do package M-R FOTO (#254/#257); plná appearance vrstva PO V1 (D-28 odrážka bloku 5) |
| 07 konštrukcia V1 | podklad pre package(y) pri štarte bloku 4 (V1-01 komín · V1-07 čelá cenovo · balík V0.4.8); patrí sem aj výklop=rola flap — týmto PRESUNUTÝ z 1b/F do okruhu bloku 4 (jeden domov) |
| 08 ponuka/dokumenty/ceny | V1 časť = zvyšok V1-03 v bloku 4; DOCX/PDF rodina dokumentov PO V1 zásobník |
| 09 + 09A GHOST | SPRACOVANÉ do záväzného package (#254 + #257) |


Zliať koncepty [zdroje/next_sessions/](zdroje/next_sessions/) 01–09A + zvyšné bloky PLANu do jedného backlogu →
roztriediť do **kódových a logických blokov** → každému určiť **prioritu · náročnosť · závislosti · či mení dátový kontrakt**
(→ audit-povinnosť) → z blokov spraviť **task packages**. Package = plný blok v PLANe (autorita); koncept ostáva podkladom.
**Šablóna package (povinné polia):** cieľ · scope IN · **scope OUT** (čo dávka vedome NErobí) · dotknuté dáta/kontrakt →
audit áno/nie · testy a DoD · riziká · smoke checklist pre Michala · checklist uzáveru. Každý package si na štarte
spraví krátky read-only audit proti aktuálnemu mainu. Agenti si potom packages preberajú sekvenčne bez ďalšieho plánovania.

### KOVANIE (zaradené Michalom 26.8.2026; architektúra + UX UZAVRETÉ 2.9.2026)

**Autorita bloku:** [zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md](zdroje/next_sessions/KOVANIE_V1_ARCHITEKTURA_2026-09-02_FINAL.md)
(po cross-audite Codex/GLM/Opus + reconcile + rozhodnutia O1–O3) · **UX referencia:** [zdroje/ui20/mockup_kovanie_v1.html](zdroje/ui20/mockup_kovanie_v1.html)
(schválený 2.9.) · vendor dáta: checkpoint #10 · detail fill: checkpoint #11. Otvorené postrehy D-109/D-110/D-111 sú v packages nižšie
(D-109 mechanika = R-05 po V1, výsledok cez KOV-G). **Predpoklad prvého schema bumpu: D-52 updater** (blok 6 — štartovaný 2.9.).
Poradie slices: **0 (D-52) → A → B → H → C → D → E → F → G → I**; C a D dostanú package po sonde Démos (kit vs atomic) a fixtures.
Každý package sa pred štartom krátko audituje proti aktuálnemu mainu (read-only), implementuje subagent v worktree, brány podľa CLAUDE.md.

- **KOV-A · TASK PACKAGE „ČELÁ — DÁTOVÁ VRSTVA A KLASIFIKÁCIA" (slice A; štart po D-52):**
  **Cieľ:** čelo pozná svoj typ (dvierka · zásuvkové · výklop · sklop · blenda), spôsob otvárania, smer dvierok a klasifikáciu zásuvky;
  výklop a blenda sa dajú postaviť; smery vidno v modeli; Neurčený smer je RED nález. **Kovanie, nákup ani ceny sa touto dávkou NEMENIA** —
  výstupy existujúcich zákaziek sú CONTENT-identické (jediný nový nález je smer).
  **Scope IN:** `fronts.rb` items[] — `type` rozšírený o `lift` · `fall` · `blind` (existujúce `door`/`drawer_front`/`none` nemenné);
  polia **scopované per typ** (FINAL §2): `opening_mode` (`classic`|`tipon`) na pohyblivých, `direction` (`left`|`right`|`unset`) len na jednokrídlových
  dvierkach (2 krídla = odvodené Ľ+P, neukladá sa), `drawer` blok = VÝHRADNE klasifikácia `{construction: metal|wood|other, variant: standard|internal}`
  (systém/osi = KOV-D); polia sa pri prepnutí typu **držia** (dormant, vzor `migrate_overrides`) a `normalize_items` ich nikdy nezahodí — `prune_*`
  overridov kovania sa v A nemení (zjednotenie pravidla pamäte = KOV-D). Roly: lift/fall → `flap` (+`flap_dir`), blind → `false_front`;
  `cabinet_builder` ich stavia ako panel čela (rovnaký box), tag Čelá, **`thickness_ok_for?` + `materialized_part` rozšírené o `flap`/`false_front`**
  (Opus F-5a — inak 19 mm čelný materiál zhodí stavbu); ABS default pre obe roly = ako dvierka (4 hrany 1,0). **5 uzavretých ciest round-trip**
  (`normalize_items` · `config_to_params` · `normalize` · `cabinet_config` · `template_config_from`) + JS `collectFronts` + **CONFIG_SCHEMA bump** (R-12).
  **Nový aditívny kľúč zberu `hardware_issues`** v `Bom.collect` (`{code, severity, cabinet_id, part_key, message}`; jediný čitateľ `Validation.run`) —
  v A nesie len `front_direction_unset` → **RED bez brány (O1)**; KOV-D ho rozšíri o hard konflikty + brány. Brána smeru je **pre-committed**:
  riadok do AUDIT_REGISTER „pristane s prvým direction-consuming výstupom (D-95)". **Overlay „Smer otvárania"** (modul `direction_check`, vzor
  `grain_check`: prerušované `>` `<` `∧` `∨`, blenda plné X, žiadny zápis/undo; prepínač v raile Inspectora + lište Kontroly Štúdia, jeden stav).
  **UI Inspector podľa mockupu scéna 1:** zoznam čiel s badge `smer?`, karta čela = typegrid piktogramov (5 nových sprite ikon) + kontextové riadky
  (smer segrow s ⚠ Neurčené · otváranie · konštrukcia · štandardná/vnútorná); náhľad kreslí symboly smerov; existujúce riadky kovania ostávajú ako dnes
  (set podľa otvárania príde s D — hint v karte). Dvojkrídlo: smer neponúka. **Žiadny default smeru nikde** (ani preview) — O1 podmienka.
  **Scope OUT:** resolver, sety, recepty, `lift` generic type a kovanie výklopov (KOV-E), zmena závesov podľa Tip-On (KOV-F), ad-hoc (KOV-H),
  exportné brány, D-111 sokel, heuristika smeru z kontextu.
  **Audit: ÁNO** (config kontrakt + schema bump + nové roly + nový kľúč zberu).
  **Testy a DoD:** headless — round-trip všetkých 5 ciest pre každé nové pole (matica typ × pole), legacy config → defaulty, `hardware_issues`
  vzniká len pre jednokrídlo `unset`, charakterizácia: existujúce fixtures + **reálny .skp korpus** (KLINIKA-typ) dajú CONTENT-identický kusovník/VEPO/
  nákup pred a po; JS — `collectFronts` round-trip, show/hide matica karty (5 typov × riadky), žiadny default smeru v kóde (guard grep);
  **in-SU povinné** — stavba výklop/blenda + rebuild + Ctrl+Z, šablóna uložiť/vložiť s výklopom (polia prežijú), kópia `*3`, overlay bez undo kroku,
  hrúbka 19 mm na flap/blende sa postaví. Mutácie min. 3 (pole vypadne z jednej cesty · default smeru · overlay zapisuje).
  **Riziká:** tichá strata poľa v jednej z 5 ciest (preto matica) · hrúbkový kontrakt · výkon overlayu pri veľkej zákazke (merať) · ikony sprite.
  **Smoke pre Michala:** vlož skrinku → F2 prepni na Výklop a F3 na Blendu (postavia sa, náhľad ukáže ∧ a X) · jednokrídlové dvierka = badge `smer?`,
  Kontrola RED, **nákupný CSV aj rozpočet prejdú** · nastav Ľavé → nález zmizne, overlay v modeli kreslí `>` prerušovane · Tip-On prepni (zatiaľ
  informatívne) · ulož šablónu s výklopom a vlož ju · kópia ×3 · otvor zákazku KLINIKA → kusovník/nákup/VEPO čísla identické ako pred aktualizáciou.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `docs/architecture/construction.md` (fronts, roly), `outputs.md`
  (`hardware_issues`), `ui-lifecycle.md` (karta čela, overlay), `UI_DIZAJN.md` (ikony) na mieste → AUDIT_REGISTER riadok brány smeru →
  STAV/KRONIKA/PLAN.

- **KOV-B · TASK PACKAGE „KATALÓG A SETY — KLASIFIKÁCIA A EDITORY" (slice B, D-110; štart po KOV-A, paralelne s KOV-H):**
  **Cieľ:** set aj položka katalógu nesú tú istú klasifikáciu ako čelo; katalóg je zoskupený; položka a set sa zakladajú v modaloch podľa mockupu
  scéna 3; editor setu vysvetľuje „Ako sa určí kód? / Koľko?" a ukazuje **živý náhľad expanzie**. Nákup existujúcich zákaziek sa NEMENÍ.
  **Scope IN:** `hardware_sets` — nové polia setu `use_type` (door|drawer|lift|fall|other) · `opening_mode` (classic|tipon|other) · `drawer_construction`
  (metal|wood|other, len drawer) · `manufacturer` · `series` · `active` (bool, default true) → `SET_KEYS` + `normalize_sets` + `validate_set` +
  **`snapshot_std` obsahová detekcia + `std` bump v TEJ ISTEJ dávke** (R-07: starší plugin → read-only, nikdy orez); **starý set bez klasifikácie =
  platný „nezaradený"** (resolvuje presne ako dnes — charakterizačný test). **Kontrolované zoznamy** výrobcov a rád: nový malý globálny store
  `hardware_taxonomy.json` (`JsonFileStore` + `.bak`, pod `Materials.with_catalog_lock`, seed Hettich/Blum/Strong + rady Sensys/InnoTech Atira/Quadro/
  AVENTOS/TANDEM…, `+ Vytvoriť`), rada patrí presne jednému výrobcovi. `hardware_catalog` — položka + `manufacturer`/`series` (kategória existuje),
  record std bump; **serverové zoskupenie** Kategória → Výrobca → Rada (poradie a orez vždy zo servera, „no silent caps" ostáva), hľadanie roztvára len
  zhody, nová položka sa zvýrazní (existujúci `pin`). **Modaly** (nx_modal.js, D-15 vzor): Nová/Upraviť položka (Démos hľadanie/URL hore — existujúci
  parser doplní len explicitný brand + Tip-On kľúčové slová, inak prázdne; poradie polí kód → názov → cena → MJ → kategória → výrobca → rada → poznámka),
  Nový/Upraviť set (klasifikácia 1→6 kontextovo, auto-návrh mena editovateľný, členovia). **Editor člena:** jedno „+ Pridať člena" → „Ako sa určí kód?"
  (pevný · podľa dĺžky výsuvu = `code_by_nl` · podľa parametra = `param_bands`) + „Koľko?" (na 1 kus = `per:'unit'` · na ownera = `per:'owner'`) —
  tri dnešné tlačidlá zanikajú, dátový tvar člena sa NEMENÍ (XOR kontrakt; **žiadne `code_by_height`** — R4). **Živý náhľad expanzie**: serverový
  read-only endpoint nad vzorovým ownerom (výber NL/počtu z ukážky), text skladá server (vzor `explain`). Pohľad Sety = dlaždice s chipmi klasifikácie
  + stav Aktívny/Neaktívny; neaktívny set sa nenúka ako nový default (mapovanie podľa klasifikácie = KOV-D).
  **Scope OUT:** resolver a default mapovanie podľa (typ × otváranie) (KOV-D), per-height sety a osové tabuľky (KOV-D), D-109/pomer (R-05), „newer
  version" notifikácia snapshotu (KOV-D), logá výrobcov, Démos inferencia rady/kategórie z breadcrumbu, D-111.
  **Audit: ÁNO** (schéma knižnice setov + katalógu + nový store, migrácia std).
  **Testy a DoD:** headless — round-trip nových polí, **downgrade brána** (súbor s novými poľami → starší tvar = read-only, nie orez), `snapshot_std`
  detekcia, taxonómia (zámok, seed, rada↔výrobca integrita, `+ Vytvoriť` dedup case-insensitive), starý set bez klasifikácie expanduje identicky
  (charakterizácia nad seed knižnicou), náhľad expanzie = ten istý výsledok ako `expand`; JS — modaly (validácia, kontextové polia, auto-názov),
  zoskupenie + hľadanie, editor člena (3×2 kombinácie); in-SU — uloženie setu zo Štúdia, dve okná (R-08 konflikt) nezmenené. Mutácie min. 3.
  **Riziká:** rozsah UI (deliť na B1 dáta+std / B2 katalóg UI / B3 editor setu) · kolízia s R-35 (úplná náhrada bez revízie — nezhoršiť) · Démos parser regresie.
  **Smoke pre Michala:** založ set cez modal: Zásuvka → Klasické → Kovové bočnice → Hettich → InnoTech Atira → názov navrhnutý → člen „K-sada podľa NL"
  → náhľad expanzie ukáže kód pre NL 470 · katalóg: Závesy zbalené/rozbalené, hľadanie „tipon" roztvorí len Blum · starý set KLASIK má chip „nezaradený"
  a nákup KLINIKA dáva identické čísla · na druhom PC so starším pluginom (ak ešte je) knižnica hlási read-only, nie prázdno.
  **Checklist uzáveru:** bump patch + `?v=` → testy → `docs/architecture/hardware.md` (`hardware_sets`, `hardware_catalog`, nový odsek taxonómie)
  + `ui-lifecycle.md` (sekcia hw, modaly) + ARCHITEKTURA router riadok → STANDARD §6 doplnok klasifikácie → D-110 do DOGFOODING_vyriesene → STAV/KRONIKA/PLAN.

- **KOV-H · TASK PACKAGE „AD-HOC KOVANIE" (slice H; štart po KOV-A, nezávisle od B):**
  **Cieľ:** ku skrinke, čelu alebo zóne sa dá pridať konkrétna položka kovania mimo setov (zámok, uholník, vešiak, HF komponenty…) a objaví sa v nákupe
  a rozpočte s jasným pôvodom — bez zakladania umelých setov a bez zaprataného katalógu. Mockup scéna 2.
  **Scope IN:** `config['hardware_manual'][]` = `{id, owner_part_key|nil, source: catalog|free, code, name, qty, unit, price_eur, note}`;
  **serverová normalizácia** (whitelist, qty limity, cena Float ≥ 0, `owner_part_key` musí existovať v pláne alebo nil) v `CabinetBuilder.normalize` +
  `cabinet_config` + `config_to_params` + `template_config_from` + **CONFIG_SCHEMA bump**; **plný snapshot** `code/name/unit/price` aj pri katalógovej
  položke (cena v čase pridania; prepočet cien ju NEprepisuje — priznané); `Bom.collect` nesie aditívny kľúč `hardware_manual` s `owner_id`; **vlastný
  pass-through kanál v expanzii** (vetva podľa pôvodu poľa PRED set rezolúciou — nikdy cez `resolve_set_id`, žiadny `generic_type custom`): riadok
  nákupu s `source: 'manual'` a pôvodom (owner, human_label), agregácia podľa kódu s ostatnými riadkami, `Σ zdrojov = množstvo` invariant platí;
  katalógový kód, ktorý v katalógu už nie je → `missing` flag (vzor `row_join`) + ORANGE; položka s mŕtvym `owner_part_key` → ORANGE „bez vlastníka",
  v nákupe ostáva (nič sa ticho nestráca); zdieľané `cabinet_id` → položky vstupujú do `dup_partition` (blokujúca vetva iba pri zliatí per-owner —
  manuálne položky sú per inštancia, takže varovná). **UI Inspector kontext Kovanie:** riadok „+ Pridať konkrétnu položku (mimo setov)" → modal
  (Patrí k: skrinka/čelá/zóny · Zdroj: katalóg (existujúci combobox položiek) / voľná · množstvo · cena · poznámka); riadok s chipom „ručná",
  úprava a zmazanie = **1 mutácia = 1 krok Späť** (`rebuild` netreba — zápis configu + push; položky nemenia geometriu). Šablóna nesie položky
  s configom (explicitné rozhodnutie „Uložiť aj kovanie" = KOV-I; do vtedy položky cestujú vždy); kópia skrinky ich prenáša (nové id).
  Rozpočet/CP: riadky prechádzajú existujúcou cestou z nákupu (žiadny nový výpočet).
  **Scope OUT:** „uložiť do katalógu" bridge · prepočet cien manuálnych položiek z Démosu · dĺžkové položky (ostáva R-06a ORANGE) · položky na
  úrovni zákazky bez skrinky (budget_custom_items existujú) · HF automatika.
  **Audit: ÁNO** (config kontrakt + kontrakt zberu/expanzie + brána).
  **Testy a DoD:** headless — normalizácia (odmietnutia), pass-through expanzia s pôvodom, agregácia s riadkom zo setu s rovnakým kódom, `missing`,
  mŕtvy owner, dup gate (varovná vs blokujúca), round-trip 4 ciest + šablóna + kópia; JS — modal, riadok, delete; in-SU — pridať/upraviť/zmazať =
  po jednom kroku Späť, prestavba skrinky položky drží, kópia `*2` prenáša, CSV nákupu obsahuje riadok s pôvodom. Mutácie min. 3.
  **Riziká:** cena snapshot vs. živý katalóg (priznať v UI „cena z času pridania") · owner combobox pri veľa čelách · zliatie s riadkom setu (agregácia
  podľa kódu je ŽELANÁ, pôvod ich rozlíši).
  **Smoke pre Michala:** k F1 pridaj Bystricu 93240 ×2 z katalógu → Nákup ukáže riadok, rozklik pôvod „F1 dvierka ľavé · ručná" · pridaj voľnú položku
  „zámok Abloy 12 €" ku skrinke · zmeň šírku skrinky → položky ostali · skopíruj skrinku → kópia ich má · zmaž katalógovú položku z katalógu →
  riadok „chýba v katalógu" (ORANGE), CSV ju stále obsahuje · Ctrl+Z vráti každý krok.
  **Checklist uzáveru:** bump patch + `?v=` → testy → `docs/architecture/hardware.md` (odsek ad-hoc v `hardware_sets`), `outputs.md` (zber, brána),
  `ui-lifecycle.md` (modal) → STANDARD §6 (ad-hoc kanál) → STAV/KRONIKA/PLAN.

- **KOV-C · TASK PACKAGE „RECEPTY, KONTEXT A ODVODENÉ DIELCE ZÁSUVIEK" (slice C; štart po KOV-A; audit-povinná; in-SU povinné; rez C1/C2):**
  **Cieľ:** zásuvkové čelo (klasifikované v KOV-A) dostane z receptu automaticky **vyrábané dielce** (Atira: dno + drevený chrbát; Quadro V6 EB23: 2 boky + dno +
  vnútorné čelo + chrbát), **resolved systém** (výškový variant · NL · nosnosť · otváranie) z počítaného kontextu a **jednu položku kovania** s parametrami; recepty sú
  dáta zmrazené v projekte; nevyriešená zásuvka neemituje nič a je RED + tvrdý blocker (O2). Dáta: FINAL §3/§4/§6, checkpointy #10 (vzorce, tabuľky), #11 (ABS, UNI 16, H70=105),
  #12 (kódy K-sád), draft `zdroje/next_sessions/KOVANIE_RECIPE_DATA_DRAFT_2026-09-02_13.md`.
  **C1 · jadro (čisté, bez zmeny výstupov):** nový modul `core/drawer_recipes.rb` + data packy `noxun_engine/data/recipes/atira.json`, `quadro_v6_eb23.json`
  (schéma: `family` metal_box|wood_undermount · `system` · `runner_variants` {`eb_by_kd` 16→12.5/18→10.5/19→9.5, `orderable` flag} · piny `mounting: slide_on`,
  `rear_type: wooden` · konštanty vzorcov (Atira: `BB = LB−2EB−51.5`, `RB = LB−2EB−63`, `BL = NL+10`; Quadro: `SKW = LB−46`, `SKL = NL`, `bottom_offset 12`,
  `box_clearance 40`) · `height_variants` {H70/H144/H176: rear_height 65.5/144/176, `min_clear_height` per opening SiSy/P2O/P2Os = 105/106/108 · 189/190/192 · 221/222/224,
  railing 0/1+1/1+1} · `nl_series` 260…620 · `availability` {NL→loads: 260→[30], 300–520→[30,50], 620→[50]; P2Os 10 kg len 260–350} · `min_depth` (NL×opening) tabuľka
  (260: 279 SiSy / 305 P2O; ≥300: NL+15; Quadro NL+13) · `thickness_supported` (Atira [16]; Quadro [16,18]) · `inner_supported: false` · `recipe_version`).
  Čisté funkcie: `Recipes.load(system)` (validácia schémy pri načítaní — chýbajúca tabuľka = odmietnutie celého packu, nikdy tichý default) ·
  `Recipes.resolve(ctx, classification, overrides)` → `{variant, nl, load, opening, parts[], hardware_params, conflicts[], explain}` (najvyšší variant, ktorého
  `min_clear_height[opening] ≤ clear_height`; najdlhšia NL s `min_depth[nl][opening] ≤ clear_depth`; load = default 30 / 50 pri NL 620; override polia z
  `hardware_overrides` majú prednosť — nekompatibilný override = conflict, nikdy tichá zmena) · `context_for(owner, plan, cfg)` v `construction.rb`: čistá fn →
  `{clear_width (listová zóna pretínajúca riadok, nie w−2t), clear_height (prienik z-intervalu riadku čela s interiérom z_lo=floor+t … z_hi=height−t / rail_geometry
  a listovou zónou), clear_depth (= interior back_front_y — v schéme pomenované `interior_depth`; porovnáva sa s vendor Mindest-Korpustiefe ako VNÚTORNÁ hĺbka —
  overiť v audite), side_thickness (KD), obstructions[] (shelf / divider_h / divider_v pretínajúce riadok)}`; **named test: 16 mm offset riadok-vs-interiér**.
  **Projektový snapshot receptov:** kľúč `drawer_recipes` v NOXUN dict modelu `{std, recipe_version, systems}` — zrkadlo `HardwareRules.ensure_project_rules!`
  (zápis VNÚTRI operácie buildera, prestavba číta VÝHRADNE snapshot, nikdy auto-merge); `merge_recipes_seed!` = explicitná akcia s diffom (UI v KOV-D).
  Testy C1: headless nad fixtúrami — vzorce Atira/Quadro proti #10 hodnotám (tabuľkový test každého riadku), výber variantu/NL (hranice, opening závislé
  min_depth NL260, 620 → 50 kg), overridy (kompatibilný drží / nekompatibilný conflict), context (16 mm offset, priečka cez riadok = obstruction, listová zóna),
  snapshot (nemení sa sám, merge len explicitne), schéma packu (chýbajúca tabuľka = odmietnutie).
  **C2 · integrácia (mení výstupy — VŠETKY zmeny len pre čelá klasifikované ako zásuvka so systémom; ostatné zákazky CONTENT-identické):**
  (a) `Construction.build_plan` volá resolver pre každé drawer-klasifikované čelo → **odvodené dielce** do `plan.parts` s part_key `front:<id>/drawer_bottom` ·
  `/drawer_back` · `/box_side:left|right` · `/drawer_inner_front`, nové ROLES + `plan_schema` bump + `material signals` enum (`:drawer`) + `human_label` vetvy;
  (b) **4. materiálový kanál** `:drawer`: `PROJECT_KEYS` + `default_drawer_material_id` (fallback **UNI 16 mm** — nemazateľný), `eff_drawer` v `effective_materials`,
  D-46 pending-confirmation reuse; `thickness_ok_for?` + `materialized_part` pre nové roly; **hrúbka = vstup receptu** — materiál mimo `thickness_supported` = conflict;
  ABS per rola z #11 (`drawer_bottom` bez; `drawer_side`/`drawer_inner_front`/`drawer_back` horná dlhá hrana 1,0 mm) ako explicitné `AbsRules` seed záznamy;
  (c) **jedna položka kovania** `generic_type: slide`, `rule_id: 'recipe:<system>'`, `params {system, height_variant, nominal_length, load, opening, runner_variant}`
  + **R2 exkluzivita**: `HardwareRules.evaluate` potlačí `fit_series`/slide pravidlá pre drawer-klasifikované čelá (build warning `legacy_slide_suppressed`
  info, len prvý raz per zákazka) + **migrácia D-93 zámkov**: `nominal_length` override s `rule_id vysuvy-nl-podla-hlbky` sa premapuje na `recipe:<system>`
  identitu (ak NL v rade — inak conflict `nl_lock_invalid`, nikdy tiché zmiznutie); charakterizačný test „jedno zásuvkové čelo → presne jedna slide položka";
  (d) **fail-closed**: `conflicts[]` neprázdne → ŽIADNE odvodené dielce, ŽIADNA slide položka; do `hardware_issues` (kľúč z KOV-A) RED `drawer_no_fit` /
  `drawer_thickness_unsupported` / `drawer_obstruction` / `drawer_internal_unsupported` s presným dôvodom a `export_blockers` rozšírené o tieto kódy (HW CSV + rozpočet + CP;
  VEPO nie) — prepočet ČERSTVÝ pri exporte (vzor `dup_partition`), hláška menuje zásuvku, dôvod, kam kliknúť; test „pri blockeri je cieľový priečinok prázdny";
  (e) Inspector: karta zásuvky ukazuje resolved riadok + osi (read-only v C; zámky/prepínanie = KOV-D), Kontrola RED riadky s navigáciou; Nákup: slide položka
  zatiaľ expanduje cez dnešné mapovanie `slide` (set podľa NL — code_by_nl); **per-height sety a výber podľa klasifikácie = KOV-D** (do vtedy: ak set nemá kód pre
  NL/variant → ORANGE `nl_missing` ako dnes, nikdy tichá zámena).
  **Scope OUT:** per-height sety/selector a defaulty podľa klasifikácie (D) · zámky UI a zmena osí (D — v C platia len existujúce `nominal_length` overridy po migrácii) ·
  „Doplniť nové recepty" UI (D) · Antaro/Strong/TANDEM (dáta pripravené) · vnútorné zásuvky (len klasifikácia + RED) · sync tyč P2O (KOV-D, dĺžková ostáva R-06a) ·
  editor receptov · dokonalý kolízny solver (obstruction z listovej zóny + police/priečky stačí; atyp = vizuálna kontrola, #09).
  **Audit: ÁNO** (nový modul + data pack, plan_schema/ROLES, snapshot kľúč na modeli, hardware kontrakt, brány). **In-SU POVINNÉ** (buildery, plán↔model, undo).
  **Testy a DoD C2:** headless — plán s odvodenými dielcami (rozmery Atira 900×560×175 → dno 791×480, chrbát 779,5×144 pri H144; Quadro 950 → SKW 868…), 4. kanál (UNI
  fallback, override, hrúbka 18 pri Atire = conflict), ABS per rola, R2 (jedna slide položka; legacy potlačené; D-93 migrácia s NL v rade aj mimo radu), fail-closed
  (nič sa neemituje + RED + blocker), **charakterizácia**: zákazky bez drawer klasifikácie CONTENT-identické (kusovník/VEPO/nákup/rozpočet); JS — karta resolved riadok,
  Kontrola riadky; **in-SU** — stavba zásuvky s dielcami, rebuild po zmene hĺbky/výšky (iný variant/NL, žiadna duplicita dielcov, part_overrides prežijú), Ctrl+Z,
  kópia `*2`, šablóna uložiť/vložiť (drawer config + snapshot receptov), plytká skrinka → žiadne dielce + RED + export zastavený s prázdnym priečinkom.
  Mutácie min. 4 (legacy nepotlačené · migrácia zámku zahodí hodnotu · dielce emitované pri conflict · snapshot auto-merge). **Riziká:** rozsah (preto C1/C2; C2 sa smie
  ďalej rezať na C2a dielce+materiál / C2b kovanie+brány) · definícia hĺbky (audit) · reálne .skp fixtures (D-93 zámok, legacy snapshot) treba vyrobiť PRED C2.
  **Smoke pre Michala:** skrinka 900×720×560, F2 zásuvkové čelo 175 (Kovové bočnice) → v kusovníku pribudnú dno 791×480 a chrbát 779,5×144 (H144), Kontrola bez nálezov,
  nákup 1× K-Atira 470 · zmeň hĺbku na 500 → NL 470→420, dielce sa prepočítajú, žiadny duplicitný riadok · drevený box (Quadro) → 5 dielcov, boky 450×135 · nastav materiál
  zásuviek v projekte na bielu 16 → všetky dielce ju dedia · plytká skrinka 300 → RED „bez riešenia", dielce zmiznú, nákupný CSV odmietne s hláškou · otvor KLINIKA →
  čísla identické.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `construction.md` (context_for, roly, resolver hook), `hardware.md` (recipes, R2, snapshot),
  `materials.md` (4. kanál), `outputs.md` (blockery, hardware_issues kódy), `model-a-identita.md` (part_keys drawer), ARCHITEKTURA router riadok (drawer_recipes)
  → STANDARD §5/§6/§7 doplnky (roly, drawer materiál, recepty) → STAV/KRONIKA/PLAN.

- **KOV-D · TASK PACKAGE „RESOLVER — SETY PODĽA KLASIFIKÁCIE, OSI, ZÁMKY A NAVIGÁCIA" (slice D; štart po KOV-B a KOV-C; audit-povinná):**
  **Cieľ:** kovanie sa vyberá automaticky **podľa klasifikácie čela** (typ × otváranie [× konštrukcia]) a **výškový variant vyberá set** (kit kód podľa NL vnútri);
  používateľ vidí resolved systém s osami, môže **zamknúť os** (NL, výškový variant, nosnosť) alebo prepnúť na iný kompatibilný set; resolver nikdy nemení potichu;
  „Doplniť nové recepty" s diffom; Kontrola je navigátor. Mockup scény 1–2. FINAL §5/§7/§8.
  **Scope IN:** (a) **defaulty podľa klasifikácie**: mapovanie setov rozšírené z `generic_type[@owner]` o kľúč klasifikácie `slide|hinge|lift × opening_mode
  [× drawer_construction]` (globál → projekt → čelo; `resolve_set_id` = jediná autorita; neaktívny set sa nenúka; starý projekt bez mapovania = dnešné správanie);
  (b) **per-height sety cez selector pásma** (`resolve_set_id` už vyberá set podľa numerického parametra — precedens D-81/nohy-podla-sokla): parameter položky
  `height_variant` (70/144/176) → set „Atira · H70 / H144 / H176" s `code_by_nl` (seed zo sondy #12: 357695/357696/… vs 357774/357775/357783…; Quadro K-sety SiSy vs
  P2O podľa opening); **žiadny nový tvar člena** (R4); seed setov generovaný Z recipe NL série + completeness test (GLM M6); (c) **zámky per os** = polia
  `hardware_overrides` (`nominal_length` existuje; + `height_variant`, `load`), D-93 sémantika, jantárové riadky v Pravidlách + „vrátiť na pravidlo" existujúcou cestou;
  UI: chipy osí s ikonou zámku v karte čela aj v kontexte Kovanie (jeden stav), klik = zamknúť aktuálnu hodnotu / odomknúť; **nekompatibilný zámok** po zmene geometrie
  = RED conflict + návrh náhrady + potvrdenie (náhrada ostáva zamknutá; nikdy tiché prepnutie) — bez diff-modal frameworku (status + Kontrola + potvrdzovací D-15 modal);
  (d) **explain**: server skladá text „prečo tento variant/NL" + „čo je v balení" (členovia + kódy) — `HardwareSets.explain` rozšírený; (e) **„Doplniť nové recepty"** v sekcii
  Pravidlá Štúdia (`merge_recipes_seed!` s textovým diffom pred potvrdením; snapshot inak nemenný) + info „dostupná novšia verzia setu" (record_rev porovnanie);
  (f) **Kontrola navigátor**: klik na RED/ORANGE riadok = select + `focus_inspector` + otvorenie sekcie Čelá/Kovanie + highlight riadku (malé JS); (g) **P2O sync tyč**
  člen (dĺžková položka, trigger `width>600 && opening==tipon`) — ostáva za R-06a ORANGE, ale jej chýbanie = **blocker** nákupu (Codex C4) cez `hardware_issues`;
  (h) prepnutie typu zásuvky späť na dvierka: zjednotené pravidlo pamäte (drawer klasifikácia + overridy sa DRŽIA; `prune_none_front_overrides` len pre `none`) — Opus I-4;
  (i) Tip-On dvierka → set podľa klasifikácie (P2O záves + piest per owner) — dáta zo seedu; hinge počet = KOV-F.
  **Scope OUT:** viacosový diff-modal · pomer D-109 · lifty (E) · závesy MAX (F) · linear pricing · šablóny 🔧 (I).
  **Audit: ÁNO** (mapovací kľúč = kontrakt setov + snapshot; overrides schéma; brány).
  **Testy a DoD:** headless — resolve_set_id s klasifikačným kľúčom (precedencia globál/projekt/čelo, neaktívny set, starý projekt), selector pásma per variant + code_by_nl
  (každá kombinácia zo seedu má kód — completeness), zámky (drží/konflikt/náhrada ostáva zamknutá), explain text, merge_recipes_seed diff + nemennosť snapshotu, sync tyč
  blocker; JS — chipy zámkov, potvrdzovací modal, Kontrola navigácia; in-SU — zámok NL prežije prestavbu, zmena hĺbky s nekompatibilným zámkom = RED + potvrdenie,
  „Doplniť recepty" = 1 krok Späť; mutácie min. 3 (zámok ticho prepísaný · neaktívny set ponúknutý · seed bez kódu prejde). **Riziká:** kolízia s R-35 (úplná náhrada
  mapovania) · rozsah UI (rezať D1 dáta/mapovanie, D2 zámky+UI, D3 navigácia+recepty UI).
  **Smoke pre Michala:** vlož skrinku so zásuvkou → Nákup ukáže K-Atira kód podľa NL A výšky (H144 = 357774 rad) · prepni na Tip-On → P2O kit + pri šírke 900 blocker
  sync tyč (ORANGE riadok + zastavený CSV) · zamkni NL 420, zmeň hĺbku na 600 → NL ostáva 420 · zmenši hĺbku na 400 → RED konflikt s návrhom 350, potvrď → 350 zamknuté ·
  Kontrola: klik na riadok otvorí správne čelo · Pravidlá → „Doplniť nové recepty" ukáže diff, potvrdenie = 1 Späť.
  **Checklist uzáveru:** bump patch + `?v=` → testy → `hardware.md` (mapovanie, per-height sety, zámky, explain, recepty merge), `ui-lifecycle.md` (chipy, modal, navigácia),
  `outputs.md` (blockery) → STANDARD §6 → D-109/D-111 stav v DOGFOODING → STAV/KRONIKA/PLAN.

- **KOV-E · „VÝKLOPY HK/HL" (po C, D):** `GENERIC_TYPES + lift` (plan_schema bump, `guard_unknown_hardware!` už chráni starší plugin) · roly `flap` z KOV-A dostanú
  pravidlo kind `weight_bands` (hmotnosť čela = rozmery × hrúbka × `Materials.density_for(typ)`; hustota nil → konzervatívny odhad + ORANGE) s tabuľkou HK top / HL top
  (data pack `lifts.json` z OFICIÁLNYCH Blum hodnôt — PDF follow-up pred zápisom; UNCONFIRMED sa nezapíše) · sety klasifikácia `lift × opening` (Tip-On = piest per owner)
  · fail-closed + RED rovnako ako zásuvky · žiadna geometria (cenové zaradenie). Audit ÁNO (GENERIC_TYPES). Smoke: výklop 600×400 → HK top set podľa hmotnosti; Tip-On → +piest;
  ťažké čelo mimo tabuľky → RED + blocker.
- **KOV-F · „ZÁVESY MAX(VÝŠKA, HMOTNOSŤ) + ÚCHYTKA + TIP-ON" (po D):** nový rule kind `max_bands` (dva vstupy: výška čela + hmotnosť; výsledok = max) — výškové prahy
  zo seedu (900/1400/1900 → 2/3/4/5, Michal potvrdil 2.9.), hmotnostné z tabuľky výrobcu (Michal dodá / oficiálne) · override počtu = zámok (existuje) · pod minimom ORANGE,
  export potvrditeľný · šírka len WARNING · úchytka: pravidlo `fixed 1` na krídlo/zásuvkové čelo LEN pri `opening_mode == classic` (vypínateľné; set úchytky podľa klasifikácie)
  · Tip-On dvierka = P2O záves + presne 1 piest/krídlo (per:'owner'). Audit NIE (pravidlá = JSON + kind). Smoke: dvierka 1250 mm → 3 závesy; Tip-On → P2O + 1 piest; úchytka 1 ks.
- **KOV-G · „NOHY 4/6, PRÍCHYTY, SOKEL PRI VKLADANÍ" (po D; LOW):** pravidlo nôh `bands` na šírku korpusu (<1000 → 4, ≥1000 → 6; AXILO aj klzáky) · **príchyt sokla = druhé
  bands pravidlo na šírku** (1 / 2) — O3, bez pomerového člena · set nôh podľa výšky sokla (existuje) viditeľný **pri vkladaní** (riadok v ghost pásiku/vkladacej karte) aj v
  Korpuse pri sokli (D-111) — override per skrinka. Audit NIE. Smoke: skrinka 1200 → 6 nôh + 2 príchyty; sokel 150 → iný set nôh viditeľný už pri vkladaní.
- **KOV-I · „ŠABLÓNY — ULOŽIŤ AJ KOVANIE" (po D):** checkbox „Uložiť aj kovanie" v mini-modale Inspectora (dnes freeze vždy → voľba) · 🔧 badge odvodený z prítomnosti
  `hardware_sets` snapshotu (žiadne nové pole) · hover súhrn + read-only detail pred vložením · **R12:** buď prenášať relevantné drawer overridy (`hardware_overrides` pre
  front kľúče) do šablóny, alebo v detaile priznať „zámky sa neprenášajú" — rozhodnúť v package audite · hard conflict blokuje uloženie S kovaním, geometria sa uloží.
  Audit NIE (whitelist šablóny sa rozširuje aditívne; overiť). Smoke: šablóna so zásuvkou má 🔧, po vložení rovnaký systém/NL; bez kovania = defaulty projektu.
- **Mimo V1** (FINAL §12): D-109 pomer (R-05), plný `per:'length'`, HF, Antaro/Strong/TANDEM (dáta pripravené v #10), inner drawer automatika.

### 2 · KONTROLA + VÝROBA

**Cieľ:** dotiahnuť krížovú kontrolu zákazky pred odoslaním do výroby a výrobné výstupy.

- **D-94 · TASK PACKAGE „NÁKUP S PÔVODOM" (1e, zapísané 30.8.2026, rev. po slepom review #255; štart na „štartuj"):**
  **Cieľ:** riadok Nákupu kovania sa dá rozkliknúť na skrinky/čelá, z ktorých vznikol, a klik označí vlastníka
  v modeli — koniec pátrania „prečo kupujem 14 závesov".
  **Scope IN:** rozklik riadku sekcie Nákup kovania (Štúdio) — INLINE pod riadkom (vertikálny priestor!), vzor
  `<details>` s pamäťou otvorenia (`budget.js` + `boot.js` — rozklik PREŽIJE push/prekreslenie sekcie). Zdroje
  SÚ už v payloade (overené: `add_row` → `finalize` → `hardware_expansion` → payload Štúdia — server sa nemení
  okrem obohatenia nižšie). Zobrazenie ZOSKUPENÉ per skrinka (jedna skrinka = jeden riadok so súčtom; položky
  vnútri), s ĽUDSKÝMI názvami dielcov — `PartKeys.human_label` (D-92) skladá SERVER: `hardware_expansion`
  obohatí zdroje o hotový text (surový `owner_part_key` Michalovo „prečo" nerieši); `fronts` pre `human_label`
  dodá ADITÍVNY kľúč zberu `fronts_by_cabinet` v `Bom.collect` (číta existujúce `ccfg['front_items']`, nič
  nezapisuje; bez neho by čelá — vlajkový prípad závesov — skončili so surovým id). Klik na zdroj = existujúca
  select mašinéria s NOVOU adresou: `source_ref` = IDENTITA (`cabinet_id` + `owner_part_key`), resolver = vzor
  `rule_ref`/`pids_for_override` (zvláda aj `owner_part_key = nil` → označí celý korpus) + `focus_inspector:
  true`; klikateľné je OBOJE — riadok skrinky (`owner_part_key` nil → celý korpus) aj vnútorná položka
  (konkrétne čelo/dielec); **pids z DOM sú ZAKÁZANÉ** (mŕtva legacy vetva sa neoživuje — Codex GH #48 P2: pids po flushi zomreli).
  **Scope OUT:** zmena výpočtu množstiev · traceability NEMAPOVANÝCH nad rámec dnešného textu · pomerové členy
  (po D-109 vlastný tvar zdroja — invariant `Σ sources.quantity == row.quantity` platí len pre unit/owner,
  register R-05; package ho NEbetónuje) · export rozkliku do CSV.
  **Audit:** ÁNO (úzky rozsah: aditívny kľúč `fronts_by_cabinet` v zdieľanom `Bom.collect` kontrakte —
  BOM/validácia/rozpočet/exporty ho zdieľajú; zvyšok je čítanie + existujúci resolver s novou adresou).
  **Testy a DoD:** headless — tvar zdrojov v payloade (unit aj owner, viac skriniek, doska bez kovania) +
  **regresný strážca invariantu `Σ sources.quantity == row.quantity` nad `HardwareSets.expand`** (čistá
  funkcia; stráži pôdu pre D-109) + human_label obohatenie; JS DOM — rozklik renderuje zoskupené zdroje bez
  server dotazu, prežije push, klik posiela `source_ref`; in-SU smoke — klik na zdroj označí správnu skrinku
  a Inspector ju otvorí. Mutácie min. 3 (zdroje z nesprávneho riadku · klik bez identity · invariant).
  **Riziká:** veľkosť payloadu pri veľkej zákazke (human_label texty — merať; prípadne lenivý kanál à la TPL
  PNG) · duplicitná identita (zdroje pri ORANGE stave zobraziť, neblokovať — tvrdé brány rieši P0-2/#252).
  **Smoke pre Michala:** v Nákupe rozklikni závesy → vidíš skrinky s ľudskými názvami dielcov a počtami;
  klik na skrinku ju označí v modeli a Inspector ju otvorí; klik na konkrétne čelo označí len to čelo;
  súčet zdrojov sedí s riadkom; rozklikni, zmeň
  niečo v modeli, „Obnoviť" — rozklik ostane otvorený.
  **Checklist uzáveru:** bump patch + `?v=` → testy → outputs.md + **hardware.md** (obohatenie expansion) +
  ui-lifecycle.md odseky na mieste → STAV/KRONIKA/PLAN → D-94 do DOGFOODING_vyriesene (plný text + riadok
  navrch indexu).
- **D-95 · Režim krížovej kontroly „diel po diele"** — riadený prechod zákazkou s odškrtávaním, stav uložený v zákazke; rozšírenie na rozmery a kovanie, šípky smeru dekoru, X-ray. *(Vizuálny základ pre olep už stojí: D-104 + D-105.)*
- **EN DANIELI textový export** výrobného zadania — supplier-agnostický výstup, vedome odložený z dávky E.
- **Nárezový plán fáza 2** — guillotine, kerf, orezky, orientácia dekoru; vlastná heuristika v čistom Ruby (OpenCutList je GPL — algoritmus áno, kód nie), kontrakt D-19 pripravený.
- **Stráž kolízií** — upozorniť, keď sa dielce prekrývajú alebo vyskočia mimo box (bbox check do validačnej vrstvy semaforu).

### 3 · STABILITA

**Cieľ:** synchronizácia panela s modelom a okrajové situácie observerov. *(D-101 — panel po Späť/Znova — je vyriešená, PR #162.)*

- **D-99 · Glitch názvov kópií pri premenovaní dielca** — nereprodukované pozorovanie, dáta boli správne; sleduje sa.
- **Redo po zlúčených transparentných operáciách** — manuálne overiť Ctrl+Y (Ruby API nemá na Windows spoľahlivú redo akciu); otvorené od 17.7.
- **Prepínanie typu HORNÁ/DOLNÁ na označenom korpuse občas zlyhá** — odložené, rieši sa s knižnicou/editorom typov.

### 4 · V1 DOTIAHNUTIE

**Cieľ:** kompletná reálna zákazka od návrhu po objednávky bez opustenia pluginu a bez ručného dopočítavania — definícia a princípy v [V1_VIZIA.md](V1_VIZIA.md).

- **D-106 · Predbežná cena korpusu v informačnom stĺpci Základných** — orientačný náklad skrinky („≈ X €" s tooltipom rozpadu materiál/ABS/kovanie); odvodené čítanie, žiadny nový riadok. *Michal
  20.8.: zapísať na neskôr — malo sa riešiť „s okruhom rozpočtu vo fáze ŠTÚDIO"; fáza ŠTÚDIO je uzavretá (v0.8.0) a D-106 v nej NEBOLO spravené, takže sa presúva sem — inak by otvorená požiadavka ostala
  visieť v zatvorenom bloku (review #228).*

- *(Kovanie — D-109/D-110/D-111 aj fáza 3 — sa 26.8. vyčlenilo do vlastného bloku **KOVANIE** vyššie.)*
- **Spotrebiče S1** (V1-02) — katalóg, položky projektu s väzbou na skrinku, kontrola niche semaforom, sekcia v rozpočte.
- **Ceny** (vedome odložené z dávky E, V1 rozsah): manuálne 1-klik overenie ceny pre položky BEZ väzby na Demos a viac URL na položke (zvyšok V1-03) · prepínač „na faktúru" (×1,2, kandidát na štvrtý cenový režim). **Mimo V1** (V1_VIZIA): DOCX/PDF generátor ponuky s vizualizáciami a rodina dokumentov — v zásobníku.
- **Konštrukcia:** per-dielec odsadenia vpredu/vzadu pre strop/dno/boky (V1-01, chladničkový komín) · typy čiel **len ako cenová položka s dodávateľom** (V1-07 vo V1 rozsahu;
  konfigurátor typov je mimo V1 — zásobník) · balík V0.4.8 z [archiv/06_PANEL_NASTAVENIA_navrh.md](archiv/06_PANEL_NASTAVENIA_navrh.md) — rohové spoje dna a stropu per strana,
  chrbát s poldrážkou, „bez dielca" varianty s validáciou, per-dielec hrúbky a odsadenia.
- *(Vkladanie na klik — V1-04 — sa 26.8. vyčlenilo do vlastného bloku **GHOST VKLADANIE**; ten je od 31.8.2026 **hotový** (v0.9.0), plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).)*
- **D-10 · Presúvanie a úprava čiel priamo v náhľade** — ako drag priečok.
- **V1.0 zostavy:** spájanie a zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, snaper logika) · soklová lišta v celku pre segment · obklady a krycie prvky segmentu vrátane pilastra
  (priznaný vs. skrytý) · pracovné a horné krycie dosky na označený segment · migrácia a oprava starých modelov · test na kompletnej reálnej zákazke. **Mimo V1** (V1_VIZIA):
  plné segmenty s `attachment` dátovým kontraktom, automatické krycie dosky a PD cez segment — v zásobníku (koncept 02 je podklad).

### 5 · RENDER M-R

**Cieľ:** materiál vyzerá v modeli ako v skutočnosti — Luciin nástroj na vizualizácie.

- **V1 rozsah — quick-win = TASK PACKAGE „M-R FOTO" (1e, zapísané 29.8.2026, rev. po slepom review #254; štart na „štartuj"):**
  **Cieľ:** dielce v modeli nesú REÁLNU fotku dekoru namiesto plnej farby — vizualizácie bez exportu (V1_VIZIA bod 7).
  **Scope IN:** čistý TROJSTAVOVÝ selektor `Materials.texture_state_for(material_id)` (headless — vzor `color_of`).
  POZOR (nález GLM review po #254, overený v kóde): `:none` sa NESMIE odvodzovať z neprítomnosti `image_url` —
  duplák URL DEDÍ zo zdroja (`duplak_record_from` ju nereject-uje) a `finalize_create` ju rozkopíruje na všetky
  sheet záznamy vrátane zásten. Selektor rozhoduje HIERARCHICKY: (1) UNI (`uni: true`) → `[:none]` bez ohľadu na URL · (2) záznam BEZ
  `image_url` (legacy, alebo bežný materiál, ktorému URL z katalógu UBUDLA) → `[:none]` — toto je cesta, ktorou
  párové pravidlo odstránenia textúry reálne funguje · (3) duplák a zástena fotku LEGITÍMNE MAJÚ (URL dedia) (duplák = ten istý dekor, fotka je vizuálne správna;
  zástena = fotka predného dekoru, rub je priznané obmedzenie fázy 2) · `[:missing]` = URL áno, lokálny súbor
  chýba/nevalidný → existujúca textúra v modeli sa DRŽÍ · `[:path, cesta]` = aplikuj/over kľúč (apply/verify
  je NOVÁ práca dávky — `image_cache` má dnes len fetch/validáciu/uloženie) (`core/demos/image_cache.rb`; `image_url` žije na SHEET zázname — SCHEMA_IMAGE, `family.rb` ho rozkopíruje
  zo skupinovej URL; ŽIADNY „group" objekt neexistuje). Kľúč-attribute zároveň rozlišuje textúru položenú
  pluginom od RUČNE namaľovanej používateľom — ručných sa plugin NIKDY nedotýka.
  `ensure_su_material`: pri dostupnej cache textúra + fixná mierka rapportu (šírka ≈ 600 mm, doladí vizuálny test);
  **identita textúry sa pamätá vlastným kľúčom** (napr. attribute na SU materiáli: basename+veľkosť súboru —
  `Texture#filename` po reopene NIE JE stabilný) a prepis sa robí LEN pri zmene kľúča; **farba sa pri materiáli
  s textúrou NENASTAVUJE** (color na textúre = tónovanie fotky!) a color write aj bez textúry len pri reálnej
  zmene (dnešný bezpodmienečný `mt.color=` sa guarduje — rebuild nesmie špiniť model).
  **KĽÚČOVÉ pravidlo pre stroj BEZ cache (Lucia): textúra sa NIKDY neprepisuje na farbu len preto, že cache
  chýba** (`:missing`) — existujúca textúra v uloženom modeli sa DRŽÍ. Bez tohto by prestavba na druhom PC ticho
  vyzliekla model z fotiek. PÁROVÁ cesta odstránenia: keď záznam `image_url` STRATÍ (`:none` po zmene katalógu)
  alebo budúci vypínač textúry vypne, pluginová textúra (podľa kľúča) sa ZLOŽÍ na farbu — ručné textúry nie.
  **STANDARD §7.1:** mŕtve pole `texture` na zázname variantu (deklarované, nikde neimplementované — zrkadlo
  R-13) sa touto dávkou zo STANDARDU VYŠKRTNE; zdroj textúry je runtime cache z `image_url`, žiadne nové pole.
  **Scope OUT:** PBR/appearance vrstva · knižnica vzhľadov · orientácia textúry podľa smeru dekoru dielca
  (fáza 2 D-28) · pixla (V1-06) · sťahovanie fotiek (lazy re-fetch pre druhé PC = kandidát k D-48/zásobník;
  dovtedy Lucia fotky NEuvidí pri dekoroch zakladaných u Michala — PRIZNANÉ obmedzenie, nie chyba) · UNI a legacy
  záznamy = fallback farba; rub zásteny s vlastnou textúrou = fáza 2 (model môže byť zmiešaný fotka/farba —
  priznať v smoke).
  **Audit: ÁNO (úzky rozsah)** — škrt poľa zo STANDARDU (kontraktová zmena, hoci mŕtva) + dotyk cesty volanej
  builderami; codex-audit pred implementáciou spustiť presne s týmto rozsahom.
  **Testy a DoD:** headless — `texture_state_for` (`:path` s fotkou vrátane DUPLÁKU so zdedenou URL a zásteny
  · `:missing` pri poškodenom/chýbajúcom súbore · `:none` pre UNI aj pri zdedenej URL · `:none` pre bežný záznam
  po STRATE URL — hierarchia typ→URL, nikdy len URL) + kľúč identity textúry; **in-SU sekcia POVINNÁ** (cesta sa volá z builderov): rebuild s textúrou nevyrába
  extra Undo, nemení BOM, neprepisuje textúru pri nezmenenom kľúči, model bez cache textúry DRŽÍ; mutácie min. 3
  (texture vždy/nikdy · prepis pri chýbajúcej cache · color na textúre). VEPO/kusovník/rozpočet BAJTOVO nezmenené.
  **Riziká:** veľkosť .skp (textúry sa vkladajú — smoke porovná na zákazke KLINIKA) · výkon pri mnohých
  materiáloch (merať) · mierka rapportu (vizuálne doladiť; prípadný vypínač v Nastaveniach rozhodne smoke).
  **Smoke pre Michala/Luciu:** zákazka s Demos materiálmi → dielce majú fotku; skrinka bez Demos materiálu ako
  doteraz; ulož model, otvor na druhom PC bez cache a prestav skrinku — **fotky NESMÚ zmiznúť**; VEPO/rozpočet
  čísla identické; veľkosť súboru pred/po.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `docs/architecture/materials.md` — odsek
  o SU vizuálnych materiáloch sa ZAKLADÁ (dnes neexistuje; R-32 vzor: overiť proti kódu) → STANDARD §7.1 škrt →
  STAV/KRONIKA/PLAN (package → ✅; blok 5 POKRAČUJE — bod 7 V1_VIZIA sa NEodškrtáva, kým je v bloku updater
  a zásobník).
- **D-28 · Textúry materiálov = M-R knižnica vzhľadov** (D-28 je do M-R zlúčená, samostatne sa nerieši): `texture_path` + render vlastnosti PBR + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 = orientácia textúry podľa smeru dekoru dielca. Zdroj JPG knižnica na firemnom Disku; väzba na D-48.
  *(**D-87** — overlay čiar v smere dekoru — je **HOTOVÝ** v bloku KRESBA (K2, PR #188, v0.7.26); tu ostáva len **orientácia textúry** podľa smeru dekoru ako fáza 2 D-28. Overlay je kontrola, textúra je render — dve rôzne veci.)*
- **Nástroj „pixla"** (V1-06) — ikonka na dlaždici materiálu, klik prefarbuje dielce cez `part_override` cestu (1 klik = 1 undo).

### 6 · INFRA (priebežne, podľa potreby)

**Cieľ:** aby plugin a knižnice fungovali na dvoch pracoviskách (Michal + Lucia).

- *(**D-48 · Zdieľaná knižnica pre 2 PC** je od 26.8. MIMO V1 — presunutá do zásobníka Po V1; katalógy sa dovtedy zdieľajú ručne export/importom.)*
- **D-52 · TASK PACKAGE „AKTUALIZOVAŤ JEDNÝM KLIKOM" (1e, zapísané 30.8.2026, rev. po slepom review #255; štart na „štartuj"):**
  **Cieľ:** Lucia aj Michal zaktualizujú plugin bez kopírovania súborov — tlačidlo v sekcii O plugine Štúdia.
  BEZ väzby na D-48 sync.
  **Scope IN:** cesta k distribučnému priečinku = VLASTNÝ malý JSON v %APPDATA% (JsonFileStore + .bak; NIE
  SupplierSettings — nepatrí pod jeho revízny zámok), pole na zadanie cesty priamo v sekcii About pri tlačidle — POD `data-ss` guardom (rozpísaná cesta nesmie
  zmiznúť pushom — trieda chyby z #227) a s vlastným uložením (Enter/mini-tlačidlo; About VEDOME nemá SS lištu
  ani revízny zámok) ·
  **tlačidlo a stavový riadok LEN v sekcii About ŠTÚDIA** — markup `about.js` je zrkadlo pre koliesko Inspectora
  (JEDEN OBSAH, DVA VSTUPY), updater časť sa renderuje výhradne pre štúdiový vstup (v koliesku sa neobjaví;
  mŕtve tlačidlo = D-78). Toto je VEDOMÁ odchýlka od zapísaného rozhodnutia „sup/about sú čítanie" — pomenovať
  v PR aj docs · kontrola verzie pri otvorení sekcie číta VÝHRADNE hlavičku `noxun_engine.rb` zo zdroja (jedno malé
  čítanie, žiadne skenovanie stromu; krátky timeout a chybová hláška — sieťový share nesmie zamraziť SketchUp) · **formát balíka = kópia
  repa** (`noxun_engine.rb` + strom `noxun_engine/`) · **jednotka atomicity = CELÝ strom, každý krok s
  definovaným rollbackom**: (1) staging kompletného balíka do `noxun_engine.new` (kópia, nie rename — share
  môže streamovať useknuté) → (2) **validácia STAGED stromu** (počty a veľkosti súborov proti zdroju; VERSION
  sa parsuje zo STAGED `noxun_engine.rb` — autorita — a krížovo proti staged `main.rb`; nesúlad/chýbajúce =
  koniec, `.new` sa uprace, nič sa nemenilo) → (3) `noxun_engine` → `noxun_engine.old` (zlyhanie → uprac
  `.new`, koniec bez zmeny) → (4) `.new` → `noxun_engine` (zlyhanie → vráť `.old` späť) → (5) loader TIEŽ cez
  staging: `noxun_engine.rb.new` → rename (zlyhanie → vráť celý swap, `.old` strom späť — NOVÝ strom so STARÝM
  loaderom nesmie ostať: `main.rb` fallback by hlásil starú verziu nad novým kódom) → (6) `.old` sa maže až po
  úspechu všetkých krokov; zvyšky `.old`/`.new` po páde uprace ďalší beh (vzor zametania template_previews).
  Swap zároveň prirodzene ZRKADLÍ (osirené súbory zaniknú s `.old` — vzor INSTALL, ŠT-2b) · `stage_then_rename`
  je VZOR, nie volateľná funkcia (privátna, PNG-špecifická) · **trojstav verzií:** novšia = tlačidlo aktívne; ROVNAKÁ = neaktívne („aktuálna");
  STARŠIA = aktívne s potvrdením „ideš na staršiu verziu" (priznaný downgrade, žiadny ďalší guard) ·  po úspechu hláška
  „Reštartuj SketchUp" — ŽIADEN auto-reload za behu (pasca observerov) ani auto-check na pozadí.
  **Scope OUT:** G-Disk sync knižníc (D-48, mimo V1) · podpisovanie balíka · auto-update na pozadí.
  **Audit: ÁNO** — dávka pridáva NOVÝ MODUL (updater) a zapisuje do živého Plugins priečinka (CLAUDE.md:
  nový modul = codex-audit povinný; rozsah auditu: atomicita swapu + validácia balíka).
  **Testy a DoD:** headless — čistý core modul updater BEZ `Sketchup.*` pri načítaní, cesty ako parametre
  (`find_support_file` len v UI vrstve): porovnanie verzií (novšia/rovnaká/staršia), validácia STAGED stromu
  (chýbajúci/useknutý súbor, nesúlad VERSION medzi staged noxun_engine.rb a main.rb = odmietnuť bez zmeny),
  swap logika so simulovaným zlyhaním KAŽDÉHO z krokov 3–5 (pôvodný strom aj loader sa vrátia, zmiešaný stav
  nevznikne, zvyšky po páde uprace ďalší beh); ručný smoke = reálny update z priečinka.
  Mutácie min. 3 (swap bez stagingu · úspech hlásený pri zlyhaní · zmiešaný stav prežije).
  **Riziká:** rename priečinka za behu — najpravdepodobnejší držiteľ handle nie je `.rb` (Ruby po načítaní
  zatvára), ale CEF s otvoreným HtmlDialogom nad `ui/*`; PREDPOKLAD updatu: updater pred swapom ZAVRIE Štúdio
  aj Inspector a pri zlyhaní rename povie presnú hlášku (overiť v audite) · antivírus/zámky na zdieľanom disku (chyby hlásiť, nikdy ticho) · nedostupný share
  pri otvorení sekcie (timeout, nie zamrznutie).
  **Smoke pre Michala:** nastav cestu na priečinok s novšou kópiou → About ukáže dostupnú verziu →
  Aktualizovať → reštart → nová verzia beží a v Plugins nie sú osirené staré súbory; priečinok s pokazeným
  balíkom → hláška, stará verzia beží ďalej; koliesko Inspectora tlačidlo NEukazuje.
  **REVÍZIA PO CODEX AUDITE (2.9.2026, 4 BLOCKER + 7 FIX — všetky prijaté; záväzné pre implementáciu, delí sa na D-52a jadro a D-52b UI):**
  **(B1) Recovery bootstrap v LOADERI + transakčný marker.** Swap prežije pád: stav transakcie žije v `Plugins/noxun_engine.update.json`
  (`{state: staged|tree_swapped|loader_swapped|done, from, to, started_at, pid}`), a **loader `noxun_engine.rb` nesie malú čistú recovery
  sekciu** (pred `require 'noxun_engine/main'`): podľa markera a prítomnosti `.new`/`.old` deterministicky **dokončí alebo vráti** poslednú kompletnú
  generáciu (stromu aj loaderu) — kód recovery žije v loaderi, lebo strom môže chýbať; headless test načítava loader priamo. Pôvodný „uprace ďalší beh"
  neplatí. **(B2) Restart latch.** Po úspešnom commite `Engine.restart_required!` — VŠETKY vstupné body pluginu (toolbar príkazy, `Panel.show`,
  `StudioDialog.show`, vkladanie, updater) až do reštartu odmietnu s natívnou hláškou „Aktualizované — reštartuj SketchUp"; starý Ruby nikdy nenačíta nové
  HTML/JS. **(B3) Update lock + procesný lease.** Samostatný `Plugins/noxun_engine.update.lock` (flock) držaný od recovery/cleanup po commit (nie
  `materials.lock` — dlhá operácia); pri načítaní každý proces zapíše `Plugins/noxun_engine.leases/<pid>.lease`, updater pred štartom odmietne, ak žije iný
  proces so živým PID (tasklist), hláška „zavri ostatné okná SketchUpu"; mŕtve lease sa upracú. **(B4) Downgrade vo V1 ZAKÁZANÝ.** Starší balík = tlačidlo
  `aria-disabled` s dôvodom („staršia verzia — reinštaluj ručne cez INSTALL"); trojstav ostáva ako informácia. *(Rozhodnutie orchestrátora — Michal môže
  vrátiť, ale len s capability markerom balíka; samotné VERSION nestačí.)* **(F5) Explicitný `updater_check`** z oboch vstupov do About (navigácia aj
  deep-link), nie zo `settings_payload`; beží asynchrónne (Ruby vlákno + deadline, výsledok cez `UI.start_timer` poll) s tokenom viazaným na cestu +
  inštanciu Štúdia — neskorá odpoveď sa zahodí. **(F6) Izolácia blokujúceho I/O:** čítanie hlavičky aj staging bežia vo vlákne s deadline; hlavné vlákno
  nečaká; po deadline hláška „zdroj nedostupný", výsledok vlákna sa ignoruje. **(F7) Vlastný namespace `data-updater-edit`** (nie `data-ss`) s vlastným
  focus/dirty/save. **(F8) Manifest SHA1** relatívnych ciest zo zdroja → porovnanie so STAGED stromom (byte-for-byte dôkaz), verzia a rozhodnutie „novšia"
  sa **prepočítajú zo staged loadera** tesne pred swapom. **(F9) Kanonické hranice:** cieľ = `Engine.plugin_dir` + súrodenecký loader; odmietnuť
  zdroj == cieľ, zdroj vnútri cieľa, `.new/.old`, symlinky/junctiony/reparse points (realpath ≠ path), relatívne cesty unikajúce zo staging rootu.
  **(F10) Bariéra pred swapom:** potvrdenie v Štúdiu → zavrieť Inspector aj Štúdio → počkať na oba `set_on_closed` (timer, limit 3 s) → swap → výsledok
  natívne (`UI.messagebox`), nikdy cez CEF. **(F11) `updater_settings.json`:** `std`, zápis pod `Materials.with_catalog_lock`, brána degradovanej `.bak`
  (R-11 vzor). **Testy (min. sada z auditu):** verzie (`0.9.9 < 0.10.0`, chýbajúci/duplicitný VERSION, loader–main nesúlad) · manifest/staging (chýbajúci,
  skrátený, rovnako veľký poškodený, zdroj zmenený počas kopírovania, extra súbor, symlink, prekryv) s cieľom byte-identickým pri každom odmietnutí ·
  zlyhania krokov 3–5 + mazania `.old` (kontrola stromu AJ loadera) · **simulovaný pád po každej hranici** → recovery pri ďalšom boote dá jednu kompletnú
  generáciu · dva OS procesy (jeden vstúpi, druhý nemaže staging ani nečaká bez limitu; zlyhaný flock) · restart latch blokuje všetky vstupy · async check
  (visiaci FS neblokuje, timeout, stará odpoveď zahodená, deep-link = presne 1 check) · JS (prvky len v Štúdiu, cesta prežije push, SS_DIRTY nedotknuté)
  · downgrade odmietnutý · in-SU smoke s oboma oknami + druhá inštancia (úspech/reštart, poškodený balík, zamknutý priečinok, odpojený share, žiadne siroty)
  · mutácie: odstránený recovery bootstrap, update lock, restart latch — každá zabitá testom. **Rez:** **D-52a** = loader recovery + marker + lock/lease +
  manifest + swap + settings store + restart latch API (headless, bez UI) · **D-52b** = About UI, async check, bariéra okien, natívne hlášky, in-SU smoke.
  **STAV 2.9.2026: rez D-52a (jadro bez UI) je IMPLEMENTOVANÝ** — `core/updater.rb` (manifest, staging, validácia,
  swap s rollbackmi, update lock + procesný lease, downgrade zakázaný, settings store, restart latch API),
  recovery bootstrap v loaderi `noxun_engine.rb`, 32 headless testov. **Otvorené ostáva D-52b** (About UI, async
  check, bariéra okien, natívne hlášky výsledku, in-SU smoke) — až po ňom sa D-52 zatvára do archívu.
  **Checklist uzáveru:** bump patch + `?v=` → testy → **nový odsek modulu updater v
  `docs/architecture/ui-lifecycle.md`** (vstupný bod je sekcia About; core helper popísať tamtiež; R-32 vzor:
  overiť proti kódu) + ARCHITEKTURA router riadok → STAV/KRONIKA/PLAN → D-52 do DOGFOODING_vyriesene
  (plný text + riadok navrch indexu).
- **D-52b · TASK PACKAGE „UPDATER — UI V ŠTÚDIU" (po mergi D-52a / PR #277; štart na „štartuj D-52b"):**
  **Cieľ:** Michal aj Lucia zaktualizujú plugin jedným klikom zo sekcie **O plugine** v Štúdiu; jadro (recovery, lock, lease, latch, swap) je z D-52a — táto dávka pridáva
  LEN UI a asynchrónny check. **Scope IN:** pole „Distribučný priečinok" v sekcii About (**vlastný namespace `data-updater-edit`** s vlastným focus/dirty/save — NIE `data-ss`,
  F7; uloženie cez `Updater` settings store z D-52a, Enter/mini-tlačidlo; rozpísaná cesta prežije plný push) · **explicitný `updater_check`** volaný z OBOCH vstupov do About
  (navigácia aj deep-link), NIE zo `settings_payload`; beží v Ruby vlákne s deadline (default 4 s; čítanie hlavičky aj manifest zdroja), výsledok cez `UI.start_timer` poll,
  token = (cesta, inštancia Štúdia, sekvencia) — neskorá/cudzia odpoveď sa zahodí, UI nikdy nezamrzne (F5/F6) · **stavový riadok** (trojstav: novšia = tlačidlo aktívne ·
  rovnaká = `aria-disabled` „aktuálna" · **staršia = `aria-disabled` „staršia verzia — reinštaluj ručne cez INSTALL"** (B4) · nedostupné = hláška s cestou a dôvodom) ·
  **tlačidlo „Aktualizovať"**: D-15 potvrdenie („zatvoria sa obe okná, po dokončení reštartuj SketchUp") → **bariéra**: zavrieť Inspector aj Štúdio, počkať na oba
  `set_on_closed` (timer, limit 3 s; ak nedobehne → zrušiť s hláškou), až potom `Updater.apply!` → **výsledok VÝHRADNE natívne** `UI.messagebox` (úspech: „Aktualizované na X —
  reštartuj SketchUp"; odmietnutie: presný dôvod — cudzí proces/lease, zamknutý priečinok, poškodený balík, nedostupný zdroj) (F10) · po úspechu latch z D-52a blokuje všetky vstupy ·
  updater prvky sa renderujú LEN pre štúdiový vstup `nxAboutHtml` (koliesko Inspectora ich nemá — vedomá odchýlka „about je čítanie", pomenovať v docs). **Scope OUT:** G-Disk sync ·
  podpisovanie · auto-check na pozadí · auto-reload · downgrade. **Audit: NIE** (jadro auditované v D-52a; UI nad existujúcim kontraktom) — ale codex-po-pr povinné.
  **Testy a DoD:** JS — prvky len v Štúdiu, `data-updater-edit` neovplyvní `SS_DIRTY` ani revíziu SupplierSettings, stavy tlačidla, deep-link = presne 1 check; headless —
  token/deadline logika (umelo visiace I/O neblokuje, timeout hláška, stará odpoveď zahodená); **in-SU smoke** (POVINNÝ — jediný reálny test swapu): s otvoreným Inspectorom
  aj Štúdiom klik → obe okná sa zavrú → natívna hláška → po reštarte nová verzia, žiadne `.new/.old` siroty; druhá inštancia SketchUpu → odmietnutie s hláškou; poškodený
  balík → stará verzia beží; odpojený share → timeout, UI živé. Mutácie min. 2 (bariéra preskočená · výsledok cez CEF). **Riziká:** Ruby vlákna v SketchUpe (I/O v Thread +
  poll timer — overiť v audite/smoke) · CEF drží súbory (preto bariéra) · Windows Defender pri rename. **Smoke pre Michala:** nastav cestu na priečinok s novšou kópiou → About
  ukáže „dostupná 0.9.x" → Aktualizovať → okná sa zavrú, hláška, reštart → nová verzia; skús so staršou kópiou → tlačidlo neaktívne s vysvetlením; vytiahni sieťový disk →
  sekcia hlási nedostupný zdroj, Štúdio nezamrzne. **Checklist uzáveru:** bump patch + `?v=` → testy → `ui-lifecycle.md` (odsek About + updater UI, vedomá odchýlka) →
  D-52 do DOGFOODING_vyriesene (plný text + riadok indexu) → STAV/KRONIKA/PLAN (blok 6 položka hotová).
- **D-20 · Quick actions — bezpečný move plugin** — zlúčiť noxun_mower + Snaper do jedného toolbaru; kopírovanie musí prejsť štandardným dedup tickom (dnes vzniká kópia bez NOXUN identity).

## Po V1 — zásobník (nezaradené, nestratiť)

- **Vyradené z V1 rozsahu 26.8.2026** (dôvody a rozsah: [V1_VIZIA.md](V1_VIZIA.md) „Mimo V1"): **D-48 G-Disk sync knižníc** (plné znenie v [DOGFOODING.md](DOGFOODING.md), skupina Po V1 — zásobník) · plné zostavy/segmenty s `attachment` (koncept 02) · plná appearance vrstva + pixla (koncept 06) ·
  DOCX/PDF ponuka s vizualizáciami a rodina dokumentov (koncept 08) · G-Disk sync D-48 (updater D-52 ostáva vo V1) · sektorová kontrola (koncept 01) ·
  konfigurátor typov čiel (V1-07 nad rámec cenovej položky) · kovanie fáza 3 geometria (plný model výklopov, výplne fáza B).
- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** — automatické dočasné skrytie zvyšku modelu pred `view.write_image`. *Michal 20.8.: nízka priorita / vysoká náročnosť (skrývanie geometrie = zápis do modelu, undo kroky, observery). Medzitým stačí ručné „Odfotiť" v okne Šablóny — skrinku si naaranžuje a izoluje používateľ sám.*
- Rohová a vysoká/potravinová skrinka ako **nové TYPY builderov** (odvodia sa od dolnej/hornej).
- Zóny priamo vo viewporte (variant B vízie) — nadstavba 2D náhľadu.
- **Interact pre čelá** — dráhy otvárania, klik = otvorenie, merač kolízií pri otvorení (dáta máme: origin čiel na hrane pántu; typ pántu určuje dráhu).
- Náhľad povýšiť na „otvárací náhľad" panela so zobrazovaním zvolených elementov.
- **Injecting dát do knižníc v dávkach** (kódy, materiály, kovania, spotrebiče, vybavenie) — architektúru pripraviť skôr.
- Zásuvkové bloky **na novom štandarde** (DC „Atira most" ZAVRETÝ 26.8.2026 — §12 bod C2, KRONIKA) · vnútorné vybavenie (koše, tyče) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy a etikety · CNC.
- Pracovné dosky ako súčasť dekorovej skupiny — dátovo pripravené cez `sheet_variants` (D-42); doriešiť, keď si to prax vypýta.
- Odložené Demos prefixy: `hpdb` · `hrdb`/`hrll` · `dverny-plast` · `perfectsense`/`dtl`/`eurolight`/`lam` · `mdfd` (dyhovaná MDF).

## Pravidlo pre postrehy (Michal)

**Píš postrehy HNEĎ, keď ich vidíš — hocikedy, hociktorú tému.** Nemusíš strážiť, čo je kedy v pláne — ja každý postreh zaradím: buď do bežiacej etapy (ak sa týka), alebo do backlogu nižšie s označením etapy. Nič sa nestratí. Krátka veta stačí („boky majú stáť na dne, nohy pod tým") — doplňujúce otázky si vyžiadam sám.

**Triedenie hlásení (dohoda 25.7.):** bežiaca etapa · priebežné dopĺňanie · celková vízia · **odklad do V1** — kým sa k V1 dostaneme, zbierame dáta, a z odložených tém sa potom poskladajú ďalšie bloky V1–V2. Trvalé fakty domény (stolárske poznatky, pojmy) idú do [POJMY.md](POJMY.md).

**Doplnok k triedeniu (dohoda 20.8.): z pluginu sa objednávajú REÁLNE ZÁKAZKY.** Nálezy z reálnej výroby (chybný rozmer, zlá orientácia, nesprávny olep, nekompletný nákup) a **chyby v cenách a
  rozpočtoch** majú **najvyššiu prioritu triedenia — nad plánované bloky**. Predbiehajú bežiacu etapu aj naplánované dávky: keď plugin pošle do výroby alebo do objednávky zlé číslo, stojí to peniaze a
  dôveru, a žiadna rozpracovaná dávka to nevyváži. Zaraďujú sa hneď, s plným kontextom incidentu (čo bolo objednané, čo prišlo, kde to plugin ukázal alebo neukázal) — vzor: **D-108** (kresba blendy vs.
  dverí, incident 19.8.).

## Trvalé UI/UX pravidlo (Michal 20.7. — platí pre všetku ďalšiu prácu na paneli)

**VERTIKÁLNY priestor panela je vzácny.** Pred umiestnením každého nového tlačidla/poľa/funkcie sa POVINNE zamyslieť, či sa nedá umiestniť inak a rozumnejšie (do existujúceho radu, do rohu náhľadu, ako ikona, kontextovo) — rast do výšky len v krajných prípadoch. Inak panel skončí ako scrollovanie cez 20 tlačidiel a 30 sekcií.

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.
