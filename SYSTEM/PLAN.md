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
(schválený 2.9.) · vendor dáta: checkpoint #10 · detail fill: checkpoint #11. Otvorené postrehy D-109/D-111 sú v packages nižšie (D-110 ✅ vyriešená KOV-B2)
(D-109 mechanika = R-05 po V1, výsledok cez KOV-G). **Predpoklad prvého schema bumpu: D-52 updater** (blok 6 — štartovaný 2.9.).
Poradie slices: **0 (D-52 ✅) → A1 ✅ → A2 ✅ → H1 ✅ → B1 ✅ → H2 ✅ → B2 ✅ → B3 ✅ → C (AKTUÁLNA, package v2) → D → E → F → G → I** (B po Codex audite #17 rezaná na B1 dáta+std / B2 katalóg UI / B3 editor setu)
(KOV-A rezaná po Codex audite #14 na A1 dátová vrstva / A2 UI+overlay; otázka 3/4 krídel rozhodnutá Michalom 3.9. — variant a); **KOV-C package v2 (5.9.2026)** nahradil v13 z PR #300 po simplification review (zásady: nemenné recepty, kódy v setoch, žiadny fallback NL, pevné EB) — KOV-D revidovaná podľa neho.
**KOV-A je KOMPLET a v maine** (A1 PR #280 · A2a PR #281 · A2b PR #282 — plné texty packages v git histórii a v checkpointe #14; záznamy dávok v [archiv/KRONIKA.md](archiv/KRONIKA.md)).
Každý package sa pred štartom krátko audituje proti aktuálnemu mainu (read-only), implementuje subagent v worktree, brány podľa CLAUDE.md.

**Postrehy zo smoku 3.9. (Michal, v0.9.20; otvorené plné texty v [DOGFOODING.md](DOGFOODING.md), skupina KOVANIE):** **✅ D-115** symboly smeru = čiary z rohov strany pántov
(nie šípky), v náhľade aj vo viewporte — **HOTOVÉ (PR #286, v0.9.21)**, tvar má jediný zdroj per jazyk nad spoločnou fixtúrou a zásuvka dostala prerušované X ·
**✅ D-116** úchytkové profily na tag Čelá (dnes Kovanie) — **HOTOVÉ (PR #286, v0.9.21)**, vedomý dôsledok: prepínač Kovanie ich už neschová ·
**D-114** rad piktogramov namiesto „+ pridaj dvere/čelo" + upratanie kontextu Čelá — **UI/UX balík na koniec bloku** (OTVORENÉ). Michal 3.9. potvrdil v smoku bez chýb: zmeny
všetkých typov, trojkrídlo + Kontrola vedie na neurčené čelo, medzery, všetky voľby otvárania/konštrukcie.

- **✅ HOTOVÉ (PR #284, v0.9.19)** — **KOV-B1 · TASK PACKAGE „KATALÓG A SETY — DÁTA, KLASIFIKÁCIA, TAXONÓMIA, STD" (slice B, rez B1 po Codex audite #17; štart po KOV-H1):**
  **Cieľ:** set aj položka katalógu nesú klasifikáciu (typ použitia · otváranie · konštrukcia zásuvky · výrobca · rada · aktívny), knižnica má verzovanú taxonómiu
  výrobcov/rád, downgrade brány držia aj pre šablóny, a KOV-D má hotový tvar mapovacieho kľúča — **bez UI** (B2/B3). Nákup existujúcich zákaziek CONTENT-identický.
  Rozhodnutia: [zdroje/next_sessions/KOVANIE_KOVB_AUDIT_2026-09-03_17.md](zdroje/next_sessions/KOVANIE_KOVB_AUDIT_2026-09-03_17.md) (B1–B4, FIX 5–10, 13-server).
  **Scope IN:** `hardware_sets` — polia setu `use_type` (door|drawer|lift|fall|other) · `opening_mode` (classic|tipon|other) · `drawer_construction` (metal|wood|other,
  len drawer) · `manufacturer` · `series` · `active` (sparse: ukladá sa len `false`) → `SET_KEYS` + `normalize_sets` (tolerantné čítanie) + `validate_set` (zápis: klasifikácia
  buď úplne chýba = legacy „nezaradený", alebo úplná a kontextovo platná; **`generic_type` je ODVODENÝ** kanonickou mapou `door→hinge · drawer→slide · lift/fall→lift ·
  other→explicitný`; nekonzistencia = odmietnutie) · **`GENERIC_TYPES + lift`** + `plan_schema` bump (presunuté z KOV-E; `guard_unknown_hardware!` chráni starší plugin) ·
  `snapshot_std` obsahová detekcia: bumpne LEN pri prítomnom klasifikačnom poli alebo `class:` kľúči v mapovaní (legacy ostáva na pôvodnom std) · `assess_library_doc`
  whitelist rozšírený (R-07) · **kanonický mapovací kľúč pre KOV-D** `class:<generic_type>|<opening_mode>[|<drawer_construction>]` v `parse_mapping` (round-trip, whitelist,
  std detekcia; nič ho zatiaľ nečíta) · `active` nečítajú `expand`/`explain` (existujúce mapovanie, snapshot a šablóna expandujú identicky). **Šablóny (B1 blocker):**
  `CONFIG_SCHEMA` **3 → 4**; pri použití/vklade šablóny bezstratová kontrola `hardware_set_defs` (`assess_set_defs`, ten istý detektor) — novší tvar = odmietnutie BEZ zápisu
  do modelu. **Taxonómia:** nový store `core/hardware_taxonomy.rb` + `%APPDATA%\NOXUN\Engine\hardware_taxonomy.json` `{std, schema, manufacturers[], series[]}`, prísny
  `assess!` (vzor `HardwareCatalog`), stavy `:ok/:degraded/:read_only`, fresh-read + revízia pod `Materials.with_catalog_lock`, `.bak`, seed (Hettich, Blum, Strong, Grass;
  rady Sensys, InnoTech Atira, Quadro, AvanTech YOU, AVENTOS, TANDEMBOX, LEGRABOX, MERIVOBOX, Nova Pro…), API len `create_manufacturer!`/`create_series!` (patch, CI dedup,
  rada ↔ presne jeden výrobca); rename/delete mimo V1. `hardware_catalog` — položka + `manufacturer`/`series` (whitelist, `SCHEMA_CURRENT` bump, `assess!`), hľadanie indexuje
  obe polia; serverový payload `save_set!` vracia štruktúrované chyby `{row, field, msg}` (kontrakt pre B3).
  **Scope OUT:** všetko UI (B2 katalóg, B3 editor setu), resolver/defaulty podľa klasifikácie (KOV-D), per-height sety, D-109, notifikácia novšej verzie snapshotu, rename/delete
  taxonómie, Démos parser zmeny (B2).
  **Audit:** HOTOVÝ (#17). Subagent začne read-only auditom proti aktuálnemu mainu (KOV-H1 už pristála: CONFIG_SCHEMA 3, `hardware_manual`).
  **Testy a DoD:** headless — round-trip nových polí setu a položky (globál · projektový snapshot · šablóna), kanonická mapa + validačná matica (každá nekonzistencia odmietnutá,
  legacy prejde), `active` sparse, `snapshot_std` per pole (každé samostatne bumpne; legacy nie), `class:` kľúč parse/round-trip + std, `GENERIC_TYPES lift` + plan_schema
  bump + guard staršieho pluginu, **downgrade**: knižnica/snapshot/šablóna s novými poľami → starší tvar = read-only/odmietnutie, nikdy orez (test „model sa nezmenil"),
  taxonómia (assess stavy, zámok — dvojprocesový flock vzor R-08, seed merge, dedup, rada↔výrobca integrita, degraded `.bak`), **charakterizácia**: starý set bez klasifikácie
  expanduje identicky (seed knižnica + fixtures), `expand`/`explain` ignorujú `active`; guardy (`SET_KEYS` kontrakt, `?v=`). In-SU — uloženie setu s klasifikáciou zo servera,
  šablóna s `hardware_set_defs` novej verzie odmietnutá bez zápisu (simulácia cez `assess_set_defs` nad payloadom), dve okná (R-08) nezmenené. Mutácie min. 4 (klasifikácia
  doplnená legacy setu · `active` uložené ako `true` · šablóna prejde bránou · `class:` kľúč zahodený pri round-tripe).
  **Riziká:** kolízia s R-35 (taxonómia len create) · veľkosť (ak by rástla, rezať B1a sety+šablóny / B1b taxonómia+katalóg).
  **Smoke pre Michala (B1 navonok neviditeľná):** Štúdio → Kovanie: sety a katalóg vyzerajú ako doteraz, nákup KLINIKA identický; nič nové sa nedá pokaziť.
  **Checklist uzáveru (v PR):** bump patch + `?v=` → testy vrátane in-SU → `hardware.md` (`hardware_sets`: klasifikácia, mapa, `class:` kľúč, std; nový odsek `hardware_taxonomy`;
  `hardware_catalog`) + ARCHITEKTURA router riadok → STANDARD §6 (klasifikácia, mapovací kľúč, taxonómia) → AUDIT_REGISTER (R-41 ostáva pre B3) → STAV/KRONIKA/PLAN (B1 ✅).

- **✅ HOTOVÉ (PR #290, v0.9.23)** — **KOV-B2 · TASK PACKAGE „KATALÓG — ZOSKUPENIE, MODAL POLOŽKY, DÉMOS" (slice B, rez B2; Audit: NIE, `codex-po-pr` povinné):**
  **Scope IN (mockup scéna 3):** serverové zoskupenie Kategória → Výrobca → Rada so `shown/total` na každej úrovni + „načítať ďalšie" (žiadne tiché stropy; test 500+ položiek
  nájde položku za poradím 200, `pin` zachovaný); hľadanie roztvára len zhody; modal Nová/Upraviť položka (D-15 vzor: štruktúrované chyby, busy lock, draft bez `row_rev`) s poradím
  polí kód → názov → cena → MJ → kategória → výrobca → rada → poznámka; **Démos**: `pid` proposal flow ostáva server-owned (kód/názov/cena/MJ), klient nastavuje len kategóriu,
  poznámku, výrobcu a radu; parser `brand` → kanonický výrobca cez taxonómiu na serveri (inak prázdne), Tip-On len schváleným pravidlom; ručne zmenený údaj nie je „overený";
  „+ Vytvoriť" výrobcu/radu z modalu = `create_*!` API B1. **Scope OUT:** editor setu (B3), logá, inferencia rady z breadcrumbu, rename/delete taxonómie.
  **Testy:** JS modal (validácia, kontext, chyby servera), strom + paginácia + hľadanie (čisté funkcie + minidom), Démos proposal bez regresie (`test_demos_*`); headless — strom
  a `shown/total`, hľadanie podľa výrobcu/rady, `create_*!` cez modal cestu; in-SU — založenie položky a výrobcu zo Štúdia = bez kroku Späť (globálne stores). Mutácie min. 3.
  **Smoke pre Michala:** katalóg: Závesy zbalené/rozbalené, hľadanie „tipon" roztvorí len Blum · založ položku s novým výrobcom cez „+ Vytvoriť" · Démos URL predvyplní kód/názov/
  cenu/MJ, výrobcu podľa značky. **Uzáver (v PR):** `hardware.md` + `ui-lifecycle.md` (modal, strom) → STAV/KRONIKA/PLAN (B2 ✅).

- **✅ HOTOVÉ (PR #297, v0.9.26) — KOV-B je tým KOMPLET a R-41 uzavretá** — **KOV-B3 · TASK PACKAGE „EDITOR SETU — KLASIFIKÁCIA, ČLENOVIA, ŽIVÝ NÁHĹAD" (slice B, rez B3; Audit: NIE, `codex-po-pr` povinné):**
  **Scope IN (mockup scéna 3):** modal Nový/Upraviť set: klasifikácia 1→6 kontextovo (`use_type` → odvodený `generic_type` zo servera, `drawer_construction` len pri zásuvke,
  rada podľa výrobcu), auto-návrh mena editovateľný; **pripnutá revízia + základná definícia pri otvorení** (R-41 — opravuje aj dnešný `HWS_EDIT`), konflikt = obnova/riešenie;
  editor člena: jedno „+ Pridať člena" → „Ako sa určí kód?" (pevný · `code_by_nl` · `param_bands`) + „Koľko?" (`per: unit|owner`), dátový tvar člena NEMENÍ (XOR, žiadne
  `code_by_height`); **živý náhľad expanzie**: server endpoint validuje odoslaný DRAFT, zostaví syntetického ownera a dočasné mapovanie bez IO, vracia request generation
  (staršia odpoveď neprepíše novšiu), text skladá server (vzor `explain`); pohľad Sety = dlaždice s chipmi klasifikácie + Aktívny/Neaktívny (neaktívny sa nenúka ako nový default;
  mapovanie podľa klasifikácie = KOV-D). **Scope OUT:** resolver, defaulty podľa klasifikácie, per-height sety (KOV-D).
  **Testy:** JS modal (3×2 kombinácie člena, kontextové polia, auto-názov, štruktúrované chyby, pripnutá revízia), náhľad = ten istý výsledok ako `expand` (headless), konflikt
  dvoch okien in-SU (R-08 vzor) + uloženie setu = bez kroku Späť. Mutácie min. 3 (revízia nepripnutá · náhľad číta uložený set namiesto draftu · `active` filtruje existujúce mapovanie).
  **Smoke pre Michala:** založ set: Zásuvka → Klasické → Kovové bočnice → Hettich → InnoTech Atira → navrhnuté meno → člen „K-sada podľa NL" → náhľad ukáže kód pre NL 470 ·
  starý set KLASIK má chip „nezaradený" a nákup KLINIKA dáva identické čísla · dve okná: úprava toho istého setu = konflikt s hláškou, nie tichý prepis.
  **Uzáver (v PR):** `hardware.md` + `ui-lifecycle.md` (editor, náhľad) → AUDIT_REGISTER R-41 ✅ → STAV/KRONIKA/PLAN (KOV-B komplet). *(D-110 je v archíve už od KOV-B2.)*
  **Vedomé odchýlky (v PR aj v KRONIKE):** klasifikácia sa posiela VŽDY CELÁ (aj prázdna `drawer_construction`) — vynechať ju by pri prepnutí zo zásuvky nechalo starú hodnotu
  z merge `save_set!` a set by už nikdy neprešiel validáciou; filter `active` sedí priamo v `set_options` (jediná UI ponuka, referencovaný set v nej ostáva), `expand`/`explain`/
  `resolve_set_id` ho ďalej nečítajú.

- **✅ HOTOVÉ (PR #285, v0.9.20)** — **KOV-H2 · TASK PACKAGE „AD-HOC KOVANIE — INSPECTOR UI" (slice H, rez H2; H1 je v maine od v0.9.18 — kontrakt `config['hardware_manual'][]` popisuje
  [../docs/architecture/construction.md](../docs/architecture/construction.md), expanziu [../docs/architecture/hardware.md](../docs/architecture/hardware.md)):**
  **Cieľ:** v kontexte Kovanie riadok „+ Pridať konkrétnu položku (mimo setov)" → D-15 modal (Patrí k: skrinka / čelo / zónový dielec — `human_label`; Zdroj: katalóg (existujúci
  combobox položiek, zobrazí živú cenu a MJ) / voľná (názov, MJ, cena, poznámka); množstvo); položky ako riadky s chipom „ručná", úprava a zmazanie = zmena configu cez apply
  (1 krok Späť); pôvod v sekcii Nákup Štúdia (rozklik zdrojov, chip „ručná"). Mockup scéna 2. **Audit:** NIE (UI nad kontraktom H1); `codex-po-pr` povinné.
  **Testy:** JS modal (validácia, kontextové polia, katalógový výber = len kód), riadky a chip, minidom round-trip cez `collectAll`; in-SU: pridať/upraviť/zmazať = po jednom kroku
  Späť. Mutácie min. 3. **Smoke pre Michala:** k F1 pridaj Bystricu 93240 ×2 z katalógu → Nákup ukáže riadok zliaty s ostatnými, rozklik pôvod „F1 · dvierka · ručná" · pridaj voľnú
  položku „zámok Abloy 12 €" ku skrinke → vlastný riadok, rozpočet ju započíta · zmeň šírku skrinky → položky ostali · kópia skrinky ich má · zmaž katalógovú položku z katalógu →
  riadok „chýba v katalógu" bez ceny · Ctrl+Z vráti každý krok. **Checklist uzáveru (v PR):** bump + `?v=` → testy → `ui-lifecycle.md` (modal, riadky, Nákup) → STAV/KRONIKA/PLAN
  (KOV-H komplet).

- **KOV-C · TASK PACKAGE „NEMENNÉ RECEPTY ZÁSUVIEK A ODVODENÉ DIELCE" (slice C; **v2 z 5.9.2026** — simplification review Michal + Claude nahradil package v13 z PR #300
  (4 CLI + 9 GH kôl nekonvergovalo; záznam [zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_18.md](zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_18.md));
  predaudit Astra = checkpoint #19; in-SU povinné; rez C1 → C2):**
  **Cieľ:** zásuvkové čelo (klasifikované v KOV-A) dostane z **nemenného receptu** automaticky **vyrábané dielce** (Atira: dno + drevený chrbát; Quadro V6 EB23: 2 boky +
  dno + vnútorné čelo + chrbát), **jednu položku výsuvu** s číselnými parametrami (výška · NL · nosnosť · otváranie) a nákup k nej nájde kit kód v setoch z KOV-B.
  Nevyriešená zásuvka neemituje nič a je RED + tvrdý blocker (O2). Dáta: FINAL §3/§4/§6, checkpointy #10 (vzorce), #11 (ABS, UNI 16, H70 = 105), #12 (kódy K-sád), draft #13.
  **Zásady v2 (Michal 5.9.2026, záväzné):** (1) explicitné **nemenné recepty pre ~5 systémov** (Atira, Quadro, neskôr Antaro, TANDEM, StrongBox/Max), žiadny univerzálny
  resolver ani framework pre hypotetické systémy; (2) **fyzika v recepte, objednávacie kódy v setoch** (KOV-B) — dve vrstvy, každá s jednou zodpovednosťou;
  (3) **nákup nikdy nemení fyzický návrh**: žiadne kandidáty, žiadny fallback na inú NL kvôli chýbajúcemu kódu — rad NL v recepte = rad, ktorý Noxun reálne kupuje,
  chýbajúci kód = RED a používateľ rozhodne; (4) **EB je pevné per recept** (Atira 10.5, Quadro 23) — zmena hrúbky boku mení len svetlú šírku, z ktorej sa dielce počítajú,
  engine nikdy nehľadá iný runner (KD → EB mapa NEEXISTUJE); (5) systém je **explicitná hodnota** `drawer.system` popri `construction` (V1: metal → jediný kandidát Atira,
  wood → Quadro; UI predvyplní, hodnota sa uloží); (6) malý počet stavov, každé pravidlo auditovateľné z jedného JSON súboru.
  **C1 · jadro (čisté, bez zmeny výstupov):** nový modul `core/drawer_recipes.rb` + recepty `noxun_engine/data/recipes/<recipe_id>.json`:
  `atira_sisy_v1`, `atira_p2o_v1`, `quadro_v6_sisy_v1`, `quadro_v6_p2o_v1` (jeden recept = jeden systém × jedno otváranie × verzia). Schéma receptu (validovaná pri načítaní,
  chýbajúca bunka = odmietnutie celého receptu, nikdy tichý default): `recipe_id` · `system` · `family` metal_box|wood_undermount · `opening` sisy|p2o · `eb` (číslo) ·
  `kd_supported` (Atira [16, 18, 19]; Quadro [16, 18, 19]) · `mounting: slide_on` · `rear_type: wooden` · `thickness_supported` per rola (Atira dno aj chrbát [16]; Quadro každý dielec
  [16, 18]) · vzorce ako konštanty (Atira: `BB = LB − 2EB − 51.5`, `RB = LB − 2EB − 63`, `BL = NL + 10`; Quadro: `SKW = LB − 46`, `SKL = NL`, `bottom_offset 12`, `box_clearance 40`,
  výška predku/chrbta `box_height − t_dna − 12`) · `height_variants` (Atira 70/144/176: `rear_height` 65.5/144/176, `min_clear_height` pre otváranie receptu — SiSy 105/189/221,
  Tip-On 108/192/224 (kity Démos sú vendor variant PTOs — prísnejšia z oboch tabuliek; Michal 5.9.), `railing` 0/1+1/1+1; Quadro bez variantov: `box_height = clear_height − 40`, `min_box_height` tak, aby predok/chrbát `box_height − t − 12` ≥ 30 mm — Astra #19 F3: svetlá výška 60 by dala −8 mm) · **`nl_series_by_height`** = Noxun rad podľa K-sád z #12 (atira_sisy: H70 [350, 420, 470] ·
  H144 [470, 620] · H176 [350, 420, 470, 520, 620]; atira_p2o: H70 [350, 420, 470, 520, 620] · H144 [350, 420, 470, 520, 620] · H176 [350, 420, 470, 620] (kódy Démos od Michala 5.9., draft #13); quadro_v6_sisy [350, 400, 450, 500, 550]; quadro_v6_p2o [350, 400, 450]) ·
  `min_depth_by_nl` explicitná tabuľka (Atira NL + 15; Quadro NL + 13) · `load_by_nl` (Atira 30, pri 620 → 50; Quadro 30) · `sync_min_width` 600 · `abs` per rola (dno bez;
  chrbát/boky/vnútorné čelo L1 1,0 mm horná dlhá hrana) · `source` tagy per hodnota. **Nemennosť:** register vydaných receptov `data/recipes/RELEASED.json` `{recipe_id → sha256}` — test v `tests/pure` overuje, že KAŽDÝ zaregistrovaný súbor existuje a sedí na SHA (nie len `_v1`; Astra #19 F10) + **golden test výsledkov `resolve` per vydaná verzia** (fixtúra vstup → dielce/NL),
  lebo SHA JSON nezachytí zmenu interpretácie v Ruby; zmena obsahu zhodí CI;
  oprava alebo rozšírenie = nový súbor `_v2`, staré verzie sa NIKDY nemažú ani nemenia (reprodukovateľnosť starých zákaziek bez snapshotu).
  Čisté funkcie: `Recipes.load(recipe_id)` · `Recipes.latest_for(system, opening)` · `Recipes.resolve(recipe, ctx, overrides)` → `{height_variant (Atira číselné 70|144|176) |
  box_height (Quadro mm), nl, load, parts[], hardware_params, conflicts[], explain}` — **jedna výška** (najvyšší variant s `min_clear_height ≤ clear_height_raw`), **jedna NL**
  (najdlhšia z radu TEJ výšky s `min_depth ≤ clear_depth_raw`; porovnania inkluzívne s NEZAOKRÚHLENOU hodnotou, bez EPS: 105,00 platí, 104,995 padá); NL zámok
  z `hardware_overrides.nominal_length` (v rade výšky a zmestí sa → použije sa; inak conflict `nl_lock_invalid`, nikdy tichá zmena); hrúbka mimo `thickness_supported` =
  conflict `drawer_thickness_unsupported`; KD mimo `kd_supported` = `drawer_kd_unsupported`; žiadna výška/NL = `drawer_no_fit` s hláškou (napr. „Quadro P2O v1: hĺbka 300, najkratšia NL 350 potrebuje 363"); emisia dielcov ATOMICKÁ (všetky alebo žiadny); **každý rozmer každého dielca sa PRED emisiou overí proti `BuildPlan::MIN_DIM` a receptovému minimu — jediný neplatný rozmer =
  `drawer_no_fit` pre celú zásuvku** (existujúci per-dielec filter `part_skipped_degenerate` by atomicitu porušil; Astra #19 F3). `context_for(owner, plan, cfg)` v `construction.rb`:
  čistá fn z NEZAOKRÚHLENÝCH listových zón
  (`ZoneTree` odovzdá `raw_bounds`; projekcia `front_items` raw) → `{clear_width (listová zóna pretínajúca riadok), clear_height (prienik z-intervalu riadku s interiérom
  z_lo = floor + t … z_hi = height − t / rail_geometry a listovou zónou), clear_depth (= `back_front_y`), side_thickness (KD), obstructions[] (shelf / divider pretínajúci riadok →
  conflict `drawer_obstruction`)}`; named test: 16 mm offset riadok-vs-interiér.
  **Klasifikácia → recept — rozhodovacia tabuľka (Astra #19 F9, nikdy dve cesty naraz):** (1) typ ≠ zásuvka, `construction other` alebo chýba → legacy cesta, CONTENT-identická, resolver sa nevolá; (2) `construction metal|wood` + `opening_mode` prítomné → resolver (`metal → system atira`, `wood → quadro_v6`; chýbajúci `drawer.system` server doplní default per construction a
  ZAPÍŠE = migrácia čiel klasifikovaných pred v2, vo V1 jediný kandidát); (3) `construction metal|wood` BEZ `opening_mode` → RED `drawer_unclassified`, žiadne dielce, žiadna slide položka ani legacy pravidlo; `opening_mode classic → sisy` ·
  `tipon → p2o` (len 2 typy otvárania — rozhodnutie 5.9.); `variant internal` = conflict `drawer_internal_unsupported`; čiastočná klasifikácia pri type zásuvka = RED
  `drawer_unclassified`; dormant drawer polia na dvierkach sa ignorujú. **`recipe_ref` per čelo** `drawer.recipe_ref = "atira_sisy_v1"` (reťazec): **3 stavy** — chýbajúci
  (nové čelo → `latest_for`; zmena system/opening/construction používateľom → súrodenec ROVNAKEJ verzie, inak `latest_for`) a zápis; známy → použi presne ten; neznámy → RED `drawer_recipe_unknown` („aktualizuj plugin"),
  bez dielcov. Autorita SERVER — DVE cesty, nie jedna normalizácia (Astra #19 B2): (i) **klientsky payload** z panela — handler akcie (`actions_*`) zahodí `recipe_ref` PRED zlúčením do configu (klientsky whitelist ho nepozná); (ii) **uložený config** — `Fronts.normalize_config` ref BEZSTRATOVO zachováva (server-side whitelist), preto ho prežije prestavba, šablóna
  (`template_config_from`) aj natívny Copy/Paste; server pri prestavbe overí, že ref patrí k systému/otváraniu klasifikácie čela — nesúlad = explicitná zmena klasifikácie → **súrodenecký recept ROVNAKEJ verzie** pre nový systém/otváranie (`Recipes.sibling(ref, system, opening)`, napr. `atira_sisy_v1` → `atira_p2o_v1`), `latest_for` LEN ak taká verzia neexistuje (Codex #301 P1:
  prepnutie SiSy → P2O → SiSy by cez `latest_for` ticho povýšilo v1 na v2; zmena verzie = VÝHRADNE explicitná akcia KOV-D); zápis len `Fronts.write_recipe_ref!` v TEJ ISTEJ operácii ako geometria; test: strata ref pri normalizácii = FAIL (po vydaní `_v2` by stav „chýbajúci → latest" ticho zmenil geometriu) —
  ten istý nemenný recept v každom dokumente, preto **žiadny projektový snapshot receptov, digest ani merge** (zavedú sa až keby recepty boli používateľsky editovateľné).
  Testy C1: tabuľkové testy vzorcov proti #10/#13 bez zaokrúhľovania (900/KD18 → LB 864, BB 791,5, RB 780, BL = NL + 10; **KD 16 → LB 868, BB 795,5 s EB stále 10.5**),
  hranice výšky/NL (175 → H70; H70 hĺbka 500 → 470, 560 → 470 lebo rad H70 končí; H176 560 → 520; Quadro 497 → 450, 500 potrebuje 513), zámok v rade / mimo, context
  (offset, obstruction, listová zóna), stavy `recipe_ref` (3), validácia receptu (chýbajúca bunka), nemennosť (SHA), `latest_for` pri dvoch verziách.
  **C2 · aktivácia (mení výstupy LEN pre čelá so systémom; ostatné zákazky CONTENT-identické; NARAZ a–h):**
  (a) `Construction.build_plan` volá resolver pre každé drawer čelo so systémom → dielce do `plan.parts` s part_key `front:<id>/drawer_bottom` · `/drawer_back` ·
  `/box_side:left|right` · `/drawer_inner_front`; nové ROLES + `plan_schema` bump + `material signals` enum `:drawer` + `human_label` vetvy; `materialized_part` sa NEPOUŽÍVA
  (nový `drawer_part` s finálnou geometriou, hrúbka vyriešená pred receptom);
  (b) **4. materiálový kanál `:drawer`**: `PROJECT_KEYS` + `default_drawer_material_id` (fallback UNI 16 mm, nemazateľný), `eff_drawer`, `ensure_drawer_uni!` (samostatná
  idempotentná; `ensure_uni_records!` končí pri `uni_seed.done`; ochrana ID), `UNI_ROLES` + drawer, `thickness_ok_for?` pre nové roly, D-46 reuse pre kanál len cez preflight
  per systém; ABS seed per rola z #11 (`SEED_VERSION` bump); **hrúbka = vstup receptu** — materiál mimo `thickness_supported` = conflict;
  (c) **jedna položka výsuvu** v úplnom tvare `BuildPlan`: `generic_type: slide`, `rule_id: recipe:<recipe_id>`, `owner_part_key: front:<id>/panel`, `quantity: 1`,
  `rule_quantity: 1`, `source: recipe` (enum bump), **`locked: true` LEN pri položke s platným osovým zámkom** (`nominal_length` override), nie na každej receptovej položke (Astra #19 N11: inak falošné „ručne prepísané"); zákaz zmeny množstva plynie zo `source: recipe`; spotrebitelia `note_manual` a payloady Nákupu/Inspectora berú `locked` ako dnešné
  `source manual`, `params {recipe_id, system, height_variant (číselné) | box_height, nominal_length, load, opening, opening_mode, drawer_construction}`; **R2 exkluzivita**:
  `HardwareRules.evaluate` potlačí `fit_series`/slide pravidlá pre čelá so systémom (warning `legacy_slide_suppressed` raz per zákazka); **migrácia D-93**: existujúci
  `nominal_length` override s `rule_id vysuvy-nl-podla-hlbky` na drawer čele sa v tej istej prestavbe premapuje na `recipe:<recipe_id>` a platí ako zámok (mimo radu →
  `nl_lock_invalid`); server odmieta `quantity`/`disabled` mutácie pre `rule_id recipe:*` (`actions_hardware.rb`); legacy override s `disabled` alebo `quantity ≠ 1` na recipe
  položke = RED `drawer_override_invalid` (jeden kód); charakterizačný test „jedno zásuvkové čelo → presne jedna slide položka s množstvom 1";
  (d) **výber setu = NÁKUP, nie stavba:** `HardwareSets.resolve_mapping_value` pre položky, ktoré nesú `opening_mode` + `drawer_construction` v params, číta **triedny kľúč**
  `class:slide|<opening_mode>|<drawer_construction>` (KOV-B1 ho už parsuje a round-tripuje; precedencia owner override → cabinet override → projekt ostáva; odhad < 30 riadkov); **hodnota mapovania pre receptové položky so `height_variant` musí byť na KAŽDEJ úrovni (owner / cabinet / projekt) selektor podľa `height_variant`** (Astra #19 B1: pevný `set_id` v override skrinky by
  po prerastení zásuvky H70 → H176 objednal H70 kit k dielcom H176, lebo klasifikácia opening/construction je pri oboch rovnaká) — pevný `set_id` pre Atiru = RED `drawer_kit_missing` „override nie je selektor podľa výšky"; farba / 50 kg = ALTERNATÍVNY selektor (antracit per výška); Quadro (bez variantu) smie pevný `set_id`; expanzia navyše overí kód pre `nominal_length`;
  `override_keys_in_use` (R-34 ochrana kolidujúcich kópií v `production_core.rb`) rozšírená o triedne kľúče, ktoré resolver číta (Astra #19 F8)
  a pre `source: recipe` **NIKDY nepadá na generické `slide`** (set H70 pre zásuvku H176 by bol zlý kit) — chýbajúce triedne mapovanie = RED `drawer_kit_missing` s hláškou
  „Pravidlá → Doplniť nové predvolené" (existujúca akcia `merge_project_sets_seed!`, vždy explicitná, nikdy automatická migrácia snapshotu); **seed** (`SEED_VERSION` bump; std 3
  obsahom už existuje; **+ nový malý kontrakt `MAPPING_ADDITIONS` (add-if-absent) v `merge_seed`** — Astra #19 F7 + Codex #301 P1: `MAPPING_MIGRATIONS` vie len nahradiť `[from_set_id, to_set_id]` pri existujúcom kľúči a chýbajúci `class:` kľúč nevytvorí, takže „Doplniť nové predvolené" by nič neopravilo; `MAPPING_ADDITIONS = {class_key → hodnota}` sa do globálu doplní LEN ak
  kľúč chýba (používateľské mapovanie sa nikdy neprepíše), `merge_project_sets_seed!` ho prenesie do snapshotu projektu; test: starý globál + starý snapshot → po oboch mergoch triedny kľúč prítomný a zásuvka zelená): `class:slide|classic|metal` → selektor `{param:
  height_variant, bands: [70–70 → vysuv-atira-biela-h70, 144–144 → …-h144, 176–176 → …-h176]}`
  (existujúci mechanizmus D-81 — žiadny nový tvar), `class:slide|tipon|metal` → P2O sety per výška, `class:slide|classic|wood` → `vysuv-quadro-v6-sisy`, `class:slide|tipon|wood` →
  `vysuv-quadro-v6-p2o`; sety nesú klasifikáciu (KOV-B1: `use_type drawer`, opening, construction, Hettich, rada) a `code_by_nl` z #12 (H70: 420 → 357695, 470 → 357696;
  H176: 420 → 357774, 470 → 357775, 620 → 357783; Quadro SiSy 400 → 317641, 450 → 317642, 500 → 317643; P2O 350 → 343031, 400 → 343033, 450 → 317644 …); **žiadne nové osi na setoch**
  (50 kg alebo antracit = alternatívny selektor per výška v override skrinky — nemení geometriu); kompatibilita = existujúca klasifikácia setu ↔ params položky **VRÁTANE systému: `manufacturer` + `series` setu ↔ `system` receptu** (Codex #301 P1: Antaro/StrongBox budú zdieľať `class:slide|classic|metal` s Atirou — kým je v mape jeden systém per konštrukciu, triedny kľúč stačí a
  identita setu sa overí pri expanzii; rozšírenie kľúča o systém patrí dávke, ktorá pridá druhý kovový systém) (nesúlad opening/construction/system = RED
  `drawer_kit_missing` s dôvodom); **completeness test (GLM M6):** každá bunka výška × NL z radov receptov v1 má v seede kód — bunka bez kódu (SiSy H70/520, H144/350, H144/420; Tip-On H176/520 — NIE sú v radoch v1) sa pred mergom vyrieši DÁTOVO (kód od Michala alebo NL ostáva mimo radu), nikdy behovým fallbackom; chýbajúci kód pre vybranú NL v projekte = RED `drawer_kit_missing`;
  (e) **brány — jeden register `DRAWER_BLOCKERS` (10 kódov):** `drawer_unclassified` · `drawer_no_fit` · `drawer_obstruction` · `drawer_internal_unsupported` ·
  `drawer_thickness_unsupported` · `drawer_kd_unsupported` · `drawer_recipe_unknown` · `nl_lock_invalid` · `drawer_override_invalid` · `drawer_kit_missing`; `export_blockers` číta
  CELÝ register (test: každý kód zastaví blokované exporty, priečinok ostáva prázdny). Konflikty STAVBY (prvých 9) = fail-closed: žiadne dielce ani položka + RED do
  `hardware_issues` (kľúč z KOV-A); **uložený nosič (Astra #19 F6):** builder zapíše konflikty per čelo do configu v `merge_final` ako `drawer_conflicts` (vedľa `warnings`/`hardware`; tvar `[{front_id, code, message}]`), `Bom.collect` ich zlúči do `hardware_issues` — po fail-closed stavbe nezostane položka, z ktorej by sa dôvod obnovil; test save/reopen aj Undo (Kontrola ukáže
  RED aj po znovuotvorení) → blokujú HW CSV + rozpočet + CP, VEPO chráni fail-closed geometria. **`drawer_kit_missing` vzniká v NÁKUPE** (`Bom`/`HardwareSets.expand`:
  receptová položka bez setu alebo bez kódu pre svoju NL — dnešné ORANGE `no_set`/`nl_missing` sa pre `source: recipe` povyšuje na RED), dielce v modeli OSTÁVAJÚ (fyzika je správna),
  ale **blokuje VŠETKY exporty VRÁTANE VEPO** (BL = NL + 10, boky Quadro = NL — dielce rezané na NL bez kitu tej NL sú nepoužiteľné); prepočet ČERSTVÝ pri exporte z uložených
  položiek plánu + aktuálneho snapshotu setov projektu (existujúci vzor R9, žiadny nový preflight, žiadny `drawer_stale` — stavba sety nečíta, takže rozdiel nemôže vzniknúť);
  (f) **sync tyč P2O (Michal 5.9.2026 — MIMO V1 mechanika):** recept nesie `sync_min_width`; pri `opening p2o` a `clear_width ≥ prah` (inkluzívne, Hettich „od 600") stavba pridá
  **ORANGE** warning `drawer_sync_recommended` („zásuvka vyžaduje synchronizáciu — pridaj set cez ad-hoc kovanie", KOV-H kanál) — potvrditeľné pri exporte existujúcim dvojklikom;
  žiadny blocker, žiadny nový `generic_type`, žiadna dĺžka, capability ani cena za meter (plný režim `per: length` po V1, R-06a);
  (g) `CabinetBuilder::CONFIG_SCHEMA` 4 → 5 (`recipe_ref`, `source: recipe`, drawer roly) s forward-version odmietnutím a testom downgrade (starší plugin config 5 odmietne, nikdy
  ticho neodstráni dielce ani položku; `PartKeys::SCHEMA` sa nebumpuje); whitelisty šablón a `normalize_config` doplnené o `drawer.recipe_ref` a `drawer.system` (aditívne);
  (h) Inspector: karta zásuvky read-only riadok (systém · výška · NL · nosnosť · otváranie · recept v1) + `explain`; Kontrola RED/ORANGE riadky s dôvodom a navigáciou; Nákup:
  položka expanduje cez triedny kľúč (kód podľa výšky a NL, `note_manual` pri zámku).
  **Scope OUT:** zámky UI a zmena osí (D — v C platia len existujúce `nominal_length` overridy po migrácii) · prepínanie setu / systému / verzie receptu UI (D) · upgrade `recipe_ref`
  na novšiu verziu (D, explicitná akcia s textovým diffom konštánt) · sync tyč dĺžková a cenová (po V1) · Antaro/TANDEM/StrongBox/Max/Legrabox (recepty v ďalších dávkach, dáta
  v #12; kontrakt sa nemení) · vnútorné zásuvky (len klasifikácia + RED) · editor receptov · projektový snapshot receptov, digest, merge (len ak recepty budú editovateľné) ·
  KD → EB mapa, `runner_variant`, `orderable` · kandidáti / fallback NL · osi `height_variant`/`load`/`runner_variant` na setoch a exact tabuľka · `drawer_stale` preflight ·
  dokonalý kolízny solver (obstruction stačí; atyp = vizuálna kontrola, #09).
  **Audit: HOTOVÝ — Astra predaudit 5.9.2026** (2 BLOCKER + 8 FIX + 1 NOTE, všetky zapracované malými pravidlami, ŽIADNY návrat k mechanizmu v13; záznam [zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_19.md](zdroje/next_sessions/KOVANIE_KOVC_AUDIT_2026-09-05_19.md)) → implementácia; nový modul + data pack, `plan_schema`/ROLES, `CONFIG_SCHEMA` 5, hardware kontrakt
  (`source recipe`, `locked`), brány. **In-SU POVINNÉ** (buildery, plán↔model, undo).
  **Testy a DoD C2:** headless — plán s dielcami (Atira 900×720×500, KD 18, čelo 175 → H70/470: dno 791,5×480, chrbát 780×65,5; **KD 16 → dno 795,5×480**; Quadro 900/KD18
  hĺbka 500 → NL 450: SKW 818, boky 450 × box_height, vnútorné čelo/chrbát 818 × (box_height − 16 − 12); hĺbka 560 Atira H176 čelo 300 → NL 520), 4. kanál (UNI fallback, override,
  hrúbka 18 pri Atire = conflict), ABS per rola, R2 (jedna položka; legacy potlačené; D-93 v rade aj mimo), fail-closed (nič sa neemituje + RED + blocker), **triedny výber**
  (H70 vs H176 iný set; wood iný set; chýbajúce triedne mapovanie = RED, NIE fallback na `slide`; owner/cabinet override má prednosť), `drawer_kit_missing` blokuje VEPO aj CSV
  s prázdnym priečinkom, completeness seedu, downgrade schémy 5, **charakterizácia**: zákazky bez drawer klasifikácie CONTENT-identické (kusovník/VEPO/nákup/rozpočet);
  JS — karta resolved riadok, Kontrola riadky; **in-SU** — stavba zásuvky s dielcami, rebuild po zmene hĺbky/výšky (iný variant/NL, žiadna duplicita, part_overrides prežijú),
  Ctrl+Z, kópia `*2` (ref prežije), šablóna uložiť/vložiť (drawer config + ref), plytká skrinka → žiadne dielce + RED + export zastavený s prázdnym priečinkom.
  Mutácie min. 4 (legacy nepotlačené · zámok mimo radu ticho padne na inú NL · dielce emitované pri conflict · recipe položka padne na generické `slide` mapovanie).
  **Riziká:** rozsah C2 (ak PR narastie, oddeliť C2a = materiálový kanál + ABS seed bez zmeny výstupov) · dátová úplnosť seedu (bunky bez kódu — rozhodnúť pred mergom) ·
  reálne .skp fixtures (D-93 zámok, legacy snapshot setov) treba vyrobiť PRED C2 · šablóna dnes neprenáša `hardware_overrides` (NL zámok) — vložená zásuvka sa rieši automatom (dielce aj kit konzistentne z tej istej NL), prenos zámkov = KOV-I R12 (Astra #19 F5, vedomé; test to potvrdí).
  **Smoke pre Michala:** skrinka 900×720×500 (KD 18), F2 zásuvkové čelo 175 (Kovové bočnice → Atira) → kusovník: dno 791,5×480 + chrbát 780×65,5 (H70), Kontrola bez nálezov,
  nákup 1× K-Atira 470 (357696) · zmeň bok na 16 → dno 795,5×480, kód rovnaký · zmeň hĺbku na 560 → ostáva NL 470 (rad H70 končí pri 470, explain to povie), žiadny duplicitný
  riadok · drevený box (Quadro) → 5 dielcov: SKW 818, boky 450 × (svetlá výška − 40), nákup K-set V6 SiSy 450 (317642) · materiál zásuviek v projekte na bielu 16 → všetky dielce
  ju dedia · override skrinky na antracit set → iný kód, dielce rovnaké · plytká skrinka 250 → RED „bez riešenia", dielce zmiznú, CSV odmietne · Tip-On Atira pri hĺbke 500 → NL 470, nákup 357724 (PTOs kit), dielce rovnaké ako pri SiSy · P2O šírka 900 → ORANGE „pridaj synchronizačný set" · starý projekt bez triedneho mapovania → RED „Doplniť nové predvolené", po kliku zelené ·
  otvor KLINIKA → čísla identické.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `construction.md` (context_for, roly, resolver hook), `hardware.md` (recipes, R2, triedny kľúč, seed),
  `materials.md` (4. kanál), `outputs.md` (blockery, hardware_issues kódy, VEPO brána), `model-a-identita.md` (part_keys drawer, recipe_ref), ARCHITEKTURA router riadok
  (drawer_recipes) → STANDARD §5/§6/§7 doplnky (roly, drawer materiál, recepty) → STAV/KRONIKA/PLAN.

- **KOV-D · TASK PACKAGE „OVLÁDANIE ZÁSUVIEK — ZÁMKY OSÍ, PREPÍNANIE SETU, VERZIA RECEPTU, NAVIGÁCIA" (slice D; štart po KOV-C; audit-povinná; revízia 5.9.2026 podľa KOV-C v2):**
  **Cieľ:** používateľ vidí resolved zásuvku (systém · výška · NL · nosnosť · otváranie · recept) s vysvetlením, môže **zamknúť os** (NL, výškový variant) alebo prepnúť na iný
  kompatibilný set (farba, 50 kg); resolver nikdy nemení potichu; Kontrola je navigátor; prechod na novšiu verziu receptu je explicitná akcia. Mockup scény 1–2. FINAL §5/§7/§8.
  **Už hotové v KOV-C v2 (NIE scope D):** triedny kľúč `class:slide|…` čítaný v `resolve_mapping_value`, per-height sety cez existujúci selektor pásma, seed setov + completeness,
  `drawer_kit_missing` brána, sync tyč ako ORANGE.
  **Scope IN:** (a) **UI mapovania podľa klasifikácie** v Pravidlách Štúdia: pre kľúče `class:slide|…` (a neskôr `hinge|lift × opening`) výber setu globál → projekt → skrinka
  (`resolve_set_id` ostáva jediná autorita; neaktívny set sa nenúka; existujúce projekty menia mapovanie len explicitne); (b) **zámky per os** = polia `hardware_overrides`
  (`nominal_length` existuje; + `height_variant`), D-93 sémantika, jantárové riadky v Pravidlách + „vrátiť na pravidlo" existujúcou cestou; UI: chipy osí s ikonou zámku v karte čela
  aj v kontexte Kovanie (jeden stav), klik = zamknúť aktuálnu hodnotu / odomknúť; **nekompatibilný zámok** po zmene geometrie = RED conflict + návrh náhrady + potvrdenie (náhrada
  ostáva zamknutá; nikdy tiché prepnutie) — bez diff-modal frameworku (status + Kontrola + potvrdzovací D-15 modal); (c) **prepnutie setu per skrinka/čelo** (antracit, 50 kg)
  cez cabinet override triedneho kľúča s hodnotou = selektor per výška (Astra #19 B1) a ponukou LEN kompatibilných selektorov/setov (klasifikácia setu ↔ params položky); (d) **explain**: server skladá text „prečo
  táto výška/NL" (z `Recipes.resolve.explain`) + „čo je v balení" (členovia + kódy) — `HardwareSets.explain` rozšírený; (e) **verzia receptu**: info „dostupný recept v2" pri čele
  s `recipe_ref` staršej verzie + akcia „Prejsť na v2" s textovým diffom konštánt (per čelo alebo celý projekt; JEDNA operácia: prepis ref + **atomické preadresovanie zámkov `rule_id recipe:<v1> → recipe:<v2>`** (identita override obsahuje `rule_id` — Astra #19 F4; zámok mimo radu v2 = konflikt, nikdy tiché uvoľnenie) + prestavba dotknutých čiel; zlyhanie =
  rollback; 1 Späť) — recepty ostávajú nemenné, snapshot sa nezavádza; (f) **Kontrola navigátor**: klik na RED/ORANGE riadok = select + `focus_inspector` + otvorenie sekcie
  Čelá/Kovanie + highlight riadku (malé JS); (g) prepnutie typu zásuvky späť na dvierka: zjednotené pravidlo pamäte (drawer klasifikácia + overridy sa DRŽIA;
  `prune_none_front_overrides` len pre `none`) — Opus I-4; (h) Tip-On dvierka → set podľa klasifikácie `class:hinge|tipon` (P2O záves + piest per owner) — dáta zo seedu;
  hinge počet = KOV-F.
  **Scope OUT:** viacosový diff-modal · pomer D-109 · lifty (E) · závesy MAX (F) · linear pricing a sync tyč dĺžková (po V1) · šablóny 🔧 (I) · editor receptov · snapshot receptov.
  **Audit: ÁNO** (overrides schéma `height_variant`; akcia zmeny `recipe_ref`; brány).
  **Testy a DoD:** headless — UI mapovanie triednych kľúčov (precedencia globál/projekt/skrinka, neaktívny set), zámky (drží/konflikt/náhrada ostáva zamknutá), prepnutie setu len
  kompatibilný, explain text, prechod ref v1 → v2 (diff, atomicita, Späť, v1 súbor nedotknutý), navigácia; JS — chipy zámkov, potvrdzovací modal, Kontrola navigácia; in-SU — zámok NL
  prežije prestavbu, zmena hĺbky s nekompatibilným zámkom = RED + potvrdenie, „Prejsť na v2" = 1 krok Späť; mutácie min. 3 (zámok ticho prepísaný · neaktívny set ponúknutý ·
  nekompatibilný set ponúknutý). **Riziká:** kolízia s R-35 (úplná náhrada mapovania) · rozsah UI (rezať D1 mapovanie+prepnutie setu, D2 zámky+UI, D3 navigácia+verzia receptu).
  **Smoke pre Michala:** vlož skrinku so zásuvkou → Nákup ukáže K-Atira kód podľa NL A výšky (H176 = 357774 rad) · prepni set skrinky na antracit → iný kód, dielce rovnaké ·
  zamkni NL 420, zmeň hĺbku na 600 → NL ostáva 420 · zmenši hĺbku na 400 → RED konflikt s návrhom 350, potvrď → 350 zamknuté · Kontrola: klik na riadok otvorí správne čelo ·
  Pravidlá → „Prejsť na recept v2" ukáže diff, potvrdenie = 1 Späť.
  **Checklist uzáveru:** bump patch + `?v=` → testy → `hardware.md` (UI mapovania, zámky, explain, verzia receptu), `ui-lifecycle.md` (chipy, modal, navigácia),
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
- ✅ **D-112 · Zmenená ABS viditeľná vo VEPO exporte** — VEPO CSV má **deviaty stĺpec `poznamka`** (`ABS H1181 Dub Halifax tabakový`), plnený automaticky, keď sa dekor pásky líši od
  dekoru dosky; LOG dostal kontrolný oddiel „Poznámky pre VEPO" pred odoslaním objednávky. Variantu rozhodol Michalov import 3.9. — VEPO 9-stĺpcový súbor prijalo. Kontrakt je v1.1.
  **PR #287, v0.9.22.**
- ✅ **D-113 · Krátky popis korpusu v názvoch dielcov** — názov riadku vo VEPO CSV a LOGu nesie skratku dielca a skrinky (`Bok LP s1 s2`); riadok sa **nerozpadá per skrinka**
  (nálepky VEPO tlačia ~20 znakov, agregácia kusovníka ostáva). Kusovník Štúdia má ďalej plné názvy. **PR #287, v0.9.22.**
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
- **V1.0 zostavy — V1 rozsah PO ROZHODNUTÍ 4.9.2026:** prisunutie a kopírovanie korpusov po vlastnej osi (snaper + mower logika → draft NÁSTROJE-1) · dosky (pracovná doska, pilaster,
  soklová lišta, krycí panel) vkladané a kreslené prichytením na rohy skriniek (drafty GHOST-D1/D2) · test na kompletnej reálnej zákazke. **PO V1** (rozhodnutie 4.9., koncept 02):
  segmentová automatika — soklová lišta v celku pre segment, obklady a krycie prvky segmentu vrátane pilastra (priznaný vs. skrytý) ako generované diely, pracovné a horné krycie dosky
  na označený segment, migrácia a oprava starých modelov, plné segmenty s `attachment` dátovým kontraktom, automatické krycie dosky a PD cez segment — v zásobníku.
  **Rozhodnutie 4.9.2026 (Michal, debata V1 bod 1B):** viazané diely a sektory (koncept 02) idú **PO V1** — „radšej raz a poriadne, než teraz kúskovať". Praktickú potrebu zostáv pokryjú v V1
  **GHOST-D1 + GHOST-D2** (dosky vkladané a kreslené prichytením na skrinky, packages nižšie) — **oba ✅ hotové (v0.9.27 / v0.9.28)**. **Agy outside-in research** „automatický pilaster / pracovná doska" (skill `antigravity-outside-in`)
  sa spraví, keď bude kvóta — podklad pre blok viazaných dielov po V1.
- **NÁSTROJE-1 · TASK PACKAGE „MOWER + SNAPER V BALÍKU NOXUN ENGINE" (D-20; V1 bod 1A — Michal 4.9.2026; **Audit: HOTOVÝ** — Codex CLI 4.9. audity 1–5 (11 → 7 → 3 → 1 → 0 nálezov, posledný **SOUND**) + Codex GH #288 kolá 1–3, všetko zapracované; história v [zdroje/next_sessions/NASTROJE1_PACKAGE_DRAFT_2026-09-04.md](zdroje/next_sessions/NASTROJE1_PACKAGE_DRAFT_2026-09-04.md); in-SU POVINNÉ):**
  **STAV IMPLEMENTÁCIE: ✅ NÁSTROJE-1 KOMPLET (4.9.2026) — T1a PR #293 (v0.9.24) + T1b PR #295 (v0.9.25); D-20 uzavretá** (plný text v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md)).
  **T1a:** moduly `noxun_engine/tools/`, toolbar „Noxun Nástroje" + submenu, kópia cez šev enginu, `ScaleWatch.flush_pending!` + rigidita na hranici cache, Z-dialog v bariére
  aktualizácie, ikony v repe, headless sady `test_nastroje1_tools`/`test_nastroje1_observer` a in-SU `run_tools1` + `run_tools1_async`.
  **T1b:** boot migrácia `Tools::LegacyCleanup` (čisté jadro + tenký hook v `main.rb` PRED registráciou toolbaru), marker `%APPDATA%\NOXUN\Engine\legacy_cleanup.json` kľúčovaný
  normalizovanou cestou `Plugins`, kľúč až po overenej neprítomnosti všetkých štyroch cieľov, jednorazová hláška o reštarte; inštalátor maže tie isté cesty s rovnakou
  postkontrolou a končí LEN pokynom „Reštartuj SketchUp"; headless `test_nastroje1b_legacy` + in-SU `run_tools1b`; README a `docs/architecture/ui-lifecycle.md` doplnené.
  **REVÍZIA FIX 10 (Michal 4.9.2026, pri internej kontrole #293) — platí PRED znením nižšie:** prípony kópie sú **VÝHRADNE písmenové** — `a`…`z`, po vyčerpaní `aa`…`zz`
  (a ďalej `aaa`…), **nikdy čísla**; zo zdroja sa odstraňuje **len** koncová prípona v tvare *medzera + 1–2 malé písmená*. Dôvod: ručný názov skrinky bežne končí šírkou, takže
  „Dolná 900" by sa inak skopírovala ako „Dolná a" a informácia by sa stratila („Dolná 900" → „Dolná 900 a" → „Dolná 900 b"). Znenie „po vyčerpaní číslo „ 27"…" nižšie **neplatí**.
  **Cieľ:** jeden inštalačný balík — oba nástroje sa presunú ako moduly do `noxun_engine/tools/` (`mower.rb`, `snaper.rb` + ČISTÉ jadrá `mower_calc.rb`, `snap_calc.rb` bez `UI::*`; namespace
  `Noxun::Engine::Tools::*`), načíta ich `main.rb`, dostanú **jeden spoločný toolbar „Noxun Nástroje"** (poradie: −90° · +90° · 180° · Z = 0 · Z posun… · Kópia vľavo · Kópia vpravo · Prisunúť vľavo ·
  Prisunúť vpravo; slovenské tooltipy; menu Extensions → Noxun Engine → Nástroje). Vlastné registrácie rozšírení a `VERSION` nástrojov zaniknú — verziu aj update (D-52) preberá engine. **Prečo samostatný
  toolbar:** toolbar enginu má železné pravidlo „do modelu sa nezapisuje" (D-103/D-105); nástroje model menia. UI nástrojov sa inak NEMENÍ (Michal: „nechať im svoj svet").
  **Outside-in (CLAUDE.md pravidlo): HOTOVÝ 4.9.2026** — packet [zdroje/next_sessions/NASTROJE_OUTSIDE_IN_2026-09-04.md](zdroje/next_sessions/NASTROJE_OUTSIDE_IN_2026-09-04.md)
  (cez WebSearch/WebFetch oficiálnej API dokumentácie, agy kvóta vyčerpaná). Reconcile: `drawing_element_visible?` (od 2020.0) **hádže výnimku pred SU 2026.0, keď je posledný prvok cesty
  skupina/komponent** → volať pod `rescue` s fallbackom na `hidden?` + `layer.visible?` po celej ceste, test oboch vetiev · `transform_entities` interpretuje transformáciu globálne LEN v aktívnom
  kontexte a jeho rodičoch → nástroje výhradne v root kontexte · toolbar `show`/`restore` podľa `get_last_state` · natívne `Sketchup::Snap` (2025.0) = kandidát pre zostavy/GHOST, nie pre túto dávku.
  **Registrácia (audit FIX 9):** JEDEN idempotentný registrátor podľa vzoru `Engine.install_toolbar` (`@toolbar` procesná referencia, `file_loaded?` guard, jedna sada `UI::Command` zdieľaná menu aj
  toolbarom) — legacy `build_toolbar` pri load bez guardu sa NEprenáša. Trojstav toolbaru sa implementuje VÝSLOVNE (audit 2 NOTE: `install_toolbar` volá len `restore`): `get_last_state`
  never shown → `show`, visible → `restore`, hidden → nič. **Restart latch (FIX 3 + audit 2 FIX 4):** všetkých 9 príkazov kontroluje **`Engine.update_restart_pending?`** (ako toolbar enginu; po swape príkaz odmietne s hláškou). **Kontext (FIX 4, 5):** nástroje pracujú LEN v root kontexte a LEN s korpusom na root úrovni — otvorený edit komponentu alebo vnorený NOXUN korpus =
  hláška v statuse, žiadna operácia
  (legacy Mower počítal pivot v parent-relative rámci a rotoval po lokálnej Z; kópia vnoreného korpusu by skončila inde). Odmietnutie je **preflight NÁSTROJA** — `CabinetBuilder.build` si edit
  kontext zatvára sám, preto musí prísť pred ním (audit 2).
  **Kópia (Mower) — oprava fantómu:** dnes `add_instance` tej istej definície bez atribútov inštancie → kópia bez identity (Inspector ju nevidí, nie je v kusovníku, pri prestavbe originálu sa mení
  s ním). Pre NOXUN skrinku pôjde kópia **cestou „Vložiť kópiu"** (`Store.config` → `config_to_params` → `rekey_hardware_manual` → `CabinetBuilder.build(model, params, transform:
  src.transformation * Geom::Transformation.translation(Units.vector(±šírka_mm, 0, 0)))` — **mm → palce cez `Units` (audit BLOCKER 1), nikdy holé číslo**): vlastná definícia, nové sekvenčné CAB číslo,
  1 operácia = 1 Späť, výber = kópia, **`Panel.push_selected(model, dedup: false)`** (audit 2 FIX 3: predvolené `dedup: true` by založilo ďalšiu observerovú požiadavku — kópia má vlastné CAB id;
  test aj s prázdnou `@requested` frontou); brána R-12 `newer_config?` = kópia sa nevloží + hláška. Šírka kroku z configu (`width`) = **susednosť OBÁLOK KORPUSOV** (Codex #288: čelo so
  záporným `gap_sides` alebo úchytka smie presahovať šírku korpusu, takže sľub „dotyk bbox" neplatí — test meria X-rozsah korpusov, nie bbox); pri parametrickej skrinke odpadajú odhady osi a znamienka
  podľa uhla (kópia sedí po VLASTNEJ osi X pri akejkoľvek rotácii). **Názov kópie (FIX 10):** ručný názov + písmenová prípona: hľadá sa **najbližšia voľná** prípona v celom modeli (a, b, … z; po
  vyčerpaní číslo „ 27", „ 28"…), základ sa oreže tak, aby prípona vždy prežila `sanitize_name` (`NAME_MAX_LEN` 80); bez ručného názvu ostáva automatický. **Dosky (NOTE 11): SCOPE OUT** — `BoardBuilder.build`
  polohu neprijíma (šev príde s GHOST-D1); kópia dosky = hláška „zatiaľ nie". Nie-NOXUN objekty (staré DC komponenty): dnešná cesta (DC `lenx` / bounds, `add_instance`).
  **Undo a ghost zóny (FIX 2 + kolo 3 P1/P2):** každá mutácia nástroja nad NOXUN objektom (rotácia, Z, snap, kópia) beží **celá pod existujúcim `ScaleWatch.guard`** (ako vlastné stavby
  enginu) a v tej istej operácii zavolá existujúci sync ghost zón — guard zabráni, aby `notify_change` zaradil korpus do fronty, takže odložený `process_dirty` nemá čo commitnúť a transparentný
  `move_ghost_op` sa nemôže prilepiť k ďalšiemu kroku používateľa. **Pred KAŽDOU polohovou mutáciou NOXUN objektu** (rotácia, Z, snap, kópia) nástroj zavolá NOVÉ explicitné API **`ScaleWatch.flush_pending!(model)`** (audit 2 BLOCKER: dnešný `guard`
  zabráni len NOVÝM udalostiam, naplnené fronty `@dirty/@added/@requested` nevyčistí a ručný `process_dirty` nezastaví debounce timer — prázdny timer by cez `@last_model` znovu spustil globálny
  `dedup_copies` a prilepil ho k ďalšej operácii): `flush_pending!` zastaví timer, zneplatní jeho generáciu a spracuje fronty (mierka → config + prestavba, ghost sync, dedup) PRED otvorením
  operácie nástroja — aj pri čakajúcom obyčajnom Move/Rotate, nielen pri mierke. **Je to skutočná BARIÉRA, nie jedno spracovanie (audit 3 BLOCKER):** `process_dirty` môže pri čerstvej kópii
  nájsť staršiu duplicitu a znova zavolať `schedule` — nový timer s prázdnymi frontami by cez `@last_model` vykonal transparentný dedup PO operácii nástroja. Preto flush opakuje spracovanie,
  kým observer nie je v pokoji (žiadny naplánovaný timer, prázdne `@dirty/@added/@requested`), so stropom iterácií (napr. 5) — ak pokoj nenastane, nástroj operáciu ODMIETNE s hláškou. **Multi-model proveniencia (audit 4 BLOCKER):** keď `process_dirty` pri čerstvej kópii nájde
  staršiu duplicitu, dnes volá len `schedule` bez cieľového modelu a ďalšia iterácia by spracovala iba `@last_model` — follow-up preto musí znovu zaradiť KONKRÉTNY `mdl` do `@requested`
  (per-model fronta), bariéra vyhlási pokoj až keď sú prázdne fronty VŠETKÝCH modelov, a `@prune_models` sa flushom nestráca. Test s dvoma dokumentmi (A aj B majú duplicitu, `@last_model`
  ukazuje len na B): po flushi sú obe identity opravené a žiadny timer nebeží. Test: „stará duplicita + čerstvá kópia → flush → operácia nástroja → žiadny timer a OBE identity opravené". Po flushi sa transformácia číta znova; ak nie je rigidná (`CabinetBuilder.rigid_matrix?`), príkaz sa ODMIETNE
  s hláškou (žiadny tichý neúspech) — platí pre rotáciu, Z, snap aj kópiu (audit 2 FIX 2 + audit 3 FIX 2: `attach_one` dnes kontroluje LEN `scaled?` — dĺžky osí — takže šmyková matica s jednotkovými, ale nekolmými osami prejde a vetvy Move/Rotate aj verejný
  `remember_transform` ju uložia bez kontroly; **rigidita sa preto vynúti PRIAMO na hranici cache** — `remember_transform`/`attach_one` uložia len `CabinetBuilder.rigid_matrix?` transform a
  `reject_scale` nerigidný stav nikdy „nepotvrdí"; test s maticou s jednotkovými osami a nenulovým skalárnym súčinom).
  **`ScaleWatch.remember_transform`** sa volá až po úspešnom commite a LEN po potvrdenej rigidite (pod guardom ho observer nedosiahne; inak by neskôr odmietnutá šikmá mierka cez
  `reject_scale` obnovila polohu spred príkazu). Povinné testy: rotácia → okamžitá kópia (< debounce) → dobeh → Späť kópie vráti LEN kópiu, rotácia
  drží **a vo fronte observera neostane dirty udalosť**; posun nástrojom → odmietnutá (šikmá) mierka → poloha z nástroja ostáva; natívny Move → okamžitá Kópia → dobeh → Späť vráti LEN kópiu (žiadny ghost sync zdroja);
  Scale → okamžitá rotácia / Z / snap (aj so zlyhanou absorpciou = odmietnutie); po flushi je timer zastavený a fronty prázdne (test číta stav observera). **Scale race (Codex #288 kolo 2 P2 → audit 2 BLOCKER):** riešený `flush_pending!` vyššie (pre všetky príkazy, nie len kópiu). In-SU prípad: Scale → okamžitá Kópia.
  **Rotácie ±90/180, Z = 0, Z posun:** logika bez zmeny (pivot = stred bbox, svetová Z — v root kontexte); Z-posun dialog ostáva HtmlDialog (callbacky pred `show`). **Z-dialog počas update (kolo 3 P1 + audit 2 FIX 4):** callback `applyZ` je guardovaný cez **`Engine.update_locked?(:tools_z)`** (API vyžaduje `tag`); dialog dostane `hide`,
  `dialog_closed?` a `set_on_closed` (nastaví referenciu na `nil`) a je zaradený do VŠETKÝCH TROCH zoznamov bariéry: `SupplierSettingsDialog.close_plugin_dialogs`,
  `SupplierSettingsDialog.dialogs_closed?` (pred stagingom aj tesne pred commitom) a post-swap `Engine.close_all_dialogs`; test: update pri otvorenom Z dialogu = dialog zavretý, žiadny zápis do modelu.
  **Snaper (FIX 6):** AABB sweep v lokálnom rámci cieľa, WARN 10 m, BLOCK 20 m, kontajnery do hĺbky 8 — **efektívna viditeľnosť cez `Model#drawing_element_visible?`** (celá instance path + tag
  folder; pod `rescue` s fallbackom — pred SU 2026.0 hádže výnimku pre kontajner na konci cesty (viď outside-in packet), takže fallback je tam BEŽNÁ cesta: `hidden?` + `layer.visible?` +
  **skrytý tag folder** po celej ceste (existujúca `Tags.folder_hidden?`, tags.rb — tag pod skrytým priečinkom ostáva `visible?`); test pre pre-2026 vetvu s prekážkou pod skrytým priečinkom), bbox kontajnera sa odvodzuje **rekurzívne** tou istou visibility-aware traverzou (len viditeľné listy, hĺbka 8) — jednoúrovňový výpočet by bral bounds vnoreného kontajnera so skrytou
  geometriou (kolo 3 P2); **tou istou traverzou sa počítajú aj bounds CIEĽA** (`ctx[:t]` — legacy bral surové `definition.bounds`, audit 2 FIX 6); testy so skrytým dieťaťom aj so skrytým VNUKOM vo viditeľnom
  kontajneri a so skrytým presahujúcim potomkom VYBRANÉHO objektu; hlásenia cez objekt rozšírenia enginu.
  **Upratanie starých inštalácií (FIX 7):** = **explicitná boot migrácia** v `main.rb` PRED registráciou toolbaru (pri aktualizácii vykonáva swap ešte starý kód, nový `updater.rb` beží až po reštarte):
  odstráni `noxun_mower_loader.rb`, `Noxun_Mower\`, `snaper.rb`, `snaper\` v Plugins; marker žije MIMO swapovaného stromu (`%APPDATA%\NOXUN\Engine\legacy_cleanup.json`) a je **kľúčovaný normalizovanou cestou Plugins priečinka** (viac verzií SketchUpu = viac Plugins, každý sa uprace samostatne — kolo 3 P2); kľúč sa zapíše **AŽ po overenej neprítomnosti všetkých štyroch cieľov**
  (`!File.exist?`/`!Dir.exist?` po mazaní — `rm_f`/`rm_rf` chybu potláčajú, audit 2 FIX 5), inak sa
  NEoznačí ako hotové (zopakuje sa nabudúce) + hláška; test s dvoma dočasnými Plugins koreňmi nad jedným app-data a test „mazanie vrátilo bez výnimky, ale cesta ostala"; inštalátor má rovnakú
  postkontrolu pred hláškou o upratanií a **po tejto dávke vypíše LEN „Reštartuj SketchUp"** (audit 3 FIX 3: živý `load "noxun_engine.rb"` legacy toolbary neodregistruje a už načítaný
  loader/`main.rb` registráciu preskočí cez `@loaded`/`file_loaded?`); pri zlyhanej postkontrole legacy cieľov NIE „HOTOVO", ale varovanie s cestami; inštalátor `INSTALL_noxun_engine.ps1` maže tie isté cesty. Zdroj nástrojov sa presunie do repa; pôvodné priečinky workspace ostanú ako archív. Referenčné kópie legacy zdrojov (nenačítavané, Codex #288 kolo 2):
  `SYSTEM/zdroje/archiv_kod/legacy_noxun_mower.rb.txt`, `legacy_snaper_main.rb.txt`,
  `legacy_snaper_snap.rb.txt`. **Ikony (kolo 3 P2):** 7 PNG ikon Mowera a 2 SVG Snapera sa presunú do repa do `noxun_engine/ui/icons/tools/` (sledované assety, žiadna závislosť na workspace).
  **Headless (FIX 8):** čisté jadrá (`*_calc.rb`) sú v zozname `tests/helper.rb`; UI registrácia je oddelená a guardovaná (`defined?(UI::Toolbar)`), takže sa bez SketchUpu nenačíta.
  **Scope OUT:** tlačidlo „Vložiť kópiu" v toolbare (Michal: nie) · nové funkcie nástrojov · zarovnanie výšky/hĺbky k susedovi (bod 1B) · Noxun_Pick/V2fable vkladanie · KOVANIE (starý) a
  vepo_exporter (odstavia sa samostatne) · kópia dosky (GHOST-D1).
  **Testy a DoD:** headless — vektor posunu (mm→palce, lokálna os, obálka korpusu), prípona názvu (opakovaná kópia toho istého zdroja, existujúce a/b, prechod po z, 80-znakový názov), zoznam legacy
  súborov + marker (zlyhanie = nehotové), výber cesty NOXUN/DC/iné/vnorený/edit-context, Snaper viditeľnosť (skryté dieťa); **in-SU sekcia `run_tools1`** — kópia vľavo/vpravo NOXUN skrinky = nová
  inštancia s VLASTNOU definíciou a novým CAB id, `Panel` payload ju vidí, kusovník má o skrinku viac, 1 krok Späť ju odstráni; kópia rotovanej skrinky (90°) = obálky korpusov susedia (X-rozsah), aj pri
  čele so záporným `gap_sides`; názov a → b; ad-hoc položky rekeyed; R-12 odmietnutá bez zmeny modelu; repro FIX 2 (rotácia → kópia → Späť); rotácie/Z = 1 krok Späť, žiadna prestavba; vnorený korpus
  a otvorený edit context = hláška, 0 krokov Späť; Snaper: prisunutie k susedovi (medzera 0), bez prekážky blokované, skrytá prekážka neblokuje; DC komponent → stará cesta; boot migrácia: legacy
  súbory v dočasnom Plugins strome zmiznú, marker zapísaný, po zlyhaní nezapísaný. Mutácie min. 4 (kópia cez `add_instance` · holé mm v transformácii · prípona bez hľadania voľnej · marker zapísaný pri zlyhaní).
  **Riziká (audit 5 — reziduálne implementačné):** model zaradiť do `@requested` PRED `schedule` · každá iterácia bariéry zastaví timer (referencia `nil`) a zvýši generáciu, pri limite nezahodí `@requested` ani `@prune_models` · in-SU test musí REÁLNE spracovať oba modely (nielen skontrolovať kľúče). Ďalšie:** kolízia namespace pri neodstránenej starej inštalácii (preto
  upratanie v OBOCH kanáloch) · rozsah (rez T1a presun + toolbar + kópia / T1b boot migrácia + inštalátor).
  **Smoke pre Michala:** po inštalácii jeden toolbar „Noxun Nástroje", staré toolbary Mower/Snaper preč · označ skrinku → Kópia vpravo → nová skrinka vedľa, Inspector ju otvorí, v kusovníku
  pribudla, Ctrl+Z ju odstráni · pomenovaná skrinka → kópia „… a", ďalšia „… b" · rotuj 90° a skopíruj → korpusy susedia · Snaper prisunie k susedovi · Z = 0 a Z posun ako doteraz · vnútri otvoreného
  komponentu nástroj odmietne s hláškou.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → nový odsek `tools` v `docs/architecture/ui-lifecycle.md` + riadok rozcestníka `docs/ARCHITEKTURA.md` (guard) → README
  (inštalácia, upratanie starých pluginov) → D-20 do DOGFOODING_vyriesene (plný text + riadok indexu) → STAV/KRONIKA/PLAN.
- **GHOST-D1 · TASK PACKAGE „GHOST PRE DOSKY — ZÁKLAD" (V1 bod 1B — Michal 4.9.2026; outside-in HOTOVÝ: WebFetch + agy 4.9. + probe SU 26.0.429 5.9. —
  [zdroje/next_sessions/GHOST_OUTSIDE_IN_2026-09-04.md](zdroje/next_sessions/GHOST_OUTSIDE_IN_2026-09-04.md); Codex GH #288 kolá 1–2 zapracované; **Audit: HOTOVÝ — Codex CLI 5.9.2026, 4 kolá (kolo 1 Sol 4 BLOCKER + 11 FIX a Astra 1 BLOCKER + 6 FIX + 1 NOTE → kolo 2 Astra 21/23 vyriešené + 1 FIX + 1 NOTE → kolo 3 Sol 6 FIX →
  kolo 4 Sol **SOUND**, 3 FIX zapracované, žiadny BLOCKER)** (história v [zdroje/next_sessions/GHOST_D1_D2_PACKAGE_DRAFT_2026-09-04.md](zdroje/next_sessions/GHOST_D1_D2_PACKAGE_DRAFT_2026-09-04.md));
  in-SU POVINNÉ; štart po KOV-B3 alebo podľa Michala):**
  **STAV IMPLEMENTÁCIE: ✅ GHOST-D1 KOMPLET (5.9.2026, v0.9.27)** — šev `BoardPlan` + `prepare_insert`/`commit_insert`, subjekt a interakcia session, dátová tabuľka kotiev,
  plne XYZ prichytenie, ↑/↓ umiestnenie, bariéra `flush_pending!` s `:blocked`, kontrakt configu dosky `BOARD_CONFIG_SCHEMA` (vrátane `std` 4 knižnice šablón) a rozšírená
  výrobná brána (`newer_configs` s druhom, VEPO už výnimku nemá). Headless sada `test_ghost_d1_dosky.rb`, JS `test_ghost_d1_pasik.js`, in-SU `run_ghost_d1` +
  `run_ghost_d1_async`. **Zostáva GHOST-D2** (kreslenie na rozmer). Znenie nižšie je autorita, podľa ktorej sa implementovalo.
  **Cieľ:** vloženie dosky z karty Dosky ide cez ghost ako pri skrinke (doska na kurzore, prichytenie na geometriu, kotvy, klik = vloženie) — dnes sa doska kladie synchrónne na `Placement.next_x`.
  **Šev `BoardBuilder.prepare_insert` → `commit_insert(model, plan, transform:, orientation:)` — kontrakt rovnako silný ako R-03 (`CabinetBuilder.commit_insert`, audit 1):** plán je
  EXPLICITNÝ zmrazený typ (`BoardPlan`, nie voľný Hash) viazaný na IDENTITU modelu (cudzí `Model` = odmietnutie), `Geom::Transformation` sa pri commite snapshotuje RAZ (mutovateľný objekt),
  kontrola root kontextu (otvorený edit kontext = odmietnutie so statusom) a **rigidná pravotočivá matica** (`rigid_matrix?`) — ŽIADNA mutácia pred klikom. **Zmrazený = aj výrobný snapshot:**
  `prepare_insert` vyrieši materiál/`material_source`/názov proti katalógu RAZ a plán nesie už FINALIZOVANÝ serializovateľný config; `commit_insert` (ani D2 `replan`) NIKDY nenormalizuje znova
  proti živému katalógu (dnešný `board_config` katalóg pri zápise číta znova a pri dupláku uprednostní aktuálny zdroj — šev to obíde: config ide z plánu až na entitu); test „zmeň katalóg po
  prepare → commit identický". `Ids.next_board_id`, definícia + `draw_board`, orientácia ako transformácia inštancie NAD polohou — vnútro definície ostáva ležiace, výrobné dáta nedotknuté.
  **Downgrade brána doskových šablón (audit 4, vzor kabinetovej cesty):** pred `prepare_insert` sa znovu načíta AUTORITATÍVNY (RAW) záznam šablóny dosky a vyššia/neznáma schéma sa
  ODMIETNE (dnešný `handle_insert_board` skladá známe polia rovno z `template_ref` a starší plugin by budúcu šablónu, napr. s `attachment`, ticho zmenil na voľnú dosku a ešte ju
  opečiatkoval) — `BoardBuilder` dostane vlastný doskový schema marker (`BOARD_CONFIG_SCHEMA`, zapísaný do configu KAŽDEJ dosky) a kontrolu RAW záznamu; **marker píše a zachováva KAŽDÝ zapisovateľ
  doskovej šablóny (Codex #296 kolo 5 P1):** seed dosiek, `TemplateStore.upsert` pre dosky (bez markera = zápis odmietnutý, nie „legacy"), budúce migrácie; existujúce doskové šablóny bez markera
  dostanú pri prvom načítaní knižnice migráciu na marker `1` (= dnešný tvar); testy bežia nad PERZISTOVANÝMI záznamami (seed → načítanie, upsert → načítanie, migrácia), nie len nad umelo
  označenou fixture; vyššia schéma v šablóne = odmietnutie vloženia; **brána platí pre VŠETKY cesty, kde sa číta
  uložený config dosky (Codex #296 P1):** prestavba uloženej dosky (`rebuild_in_operation`), zmena orientácie z karty, vloženie zo šablóny (uloženie DOSKY ako šablóny dnes NEEXISTUJE — `saveTemplateAs` je kabinetový, doskové
  šablóny vznikajú zo seedu/`TemplateStore.upsert` a uložený config nečítajú; mimo D1, Codex #296 kolo 4 P2) **a dávkové cesty, ktoré config normalizujú PRED prestavbou —
  najmä „Nahradiť UNI…" v `materials_dialog.rb` (~r. 873–886: `BoardBuilder.normalize(merged)` → `rebuild_in_operation`; normalizácia zahodí `config_schema` aj neznáme polia, takže brána MUSÍ
  bežať nad RAW configom ešte pred `normalize`, Codex #296 kolo 2 P1)** — config s vyššou schémou sa ODMIETNE s hláškou (model nedotknutý); v dávke „Nahradiť UNI" ide doska do `blocked` plánu a **CELÁ náhrada sa odmietne** (all-or-nothing kontrakt
  `materials_replace_uni` v `materials.md` — žiadny čiastočne migrovaný projekt; Codex #296 kolo 6), nikdy sa ticho neznormalizuje cez `BoardBuilder.normalize` (rovnaký vzor ako `CabinetBuilder::CONFIG_SCHEMA` 4). **VŠEOBECNÉ PRAVIDLO (Codex #296 kolo 3 P1) — KAŽDÝ čitateľ configu dosky
  zaobchádza s vyššou schémou ako s „novším configom":** (1) mutácie a šablóny = odmietnutie (vyššie); (2) **výrobné výstupy: `Bom.collect` zaradí dosku s vyššou schémou do `newer_configs`** — záznamy nesú DRUH (`kind: cabinet | board`) a `Validation.check_newer_configs` aj
  `ProductionCore.export_blockers` hlásia „Skrinka/Doska <id>" + ÚPLNÝ zoznam blokovaných výstupov (vrátane kusovníka a VEPO), nie len tri kabinetové (Codex #296 kolo 4 P2; znenie
  hlášok pre dosku je v testovacej matici)
  (dnes vetva dosky r. ~151–172 skladá známe polia bez toho) a existujúca výrobná brána kompatibility platí pre VŠETKY výstupy, ktoré dosky konzumujú — kusovník, VEPO (`ProductionCore`
  `fresh_collect` → `Bom.compute`), nákup, rozpočet, cenová ponuka — rovnako ako pri skrinkách (fail-closed, žiadny tichý výpadok budúceho výrobného poľa); (3) zobrazenie v Inspectore/karte
  je read-only s upozornením. Testovacia matica: doska vyššej schémy × každá cesta (prestavba, orientácia, vloženie zo šablóny, Nahradiť UNI, kusovník, VEPO, nákup, rozpočet, ponuka — vrátane znenia hlášok „Doska <id>"). **kontrakt configu dosky
  (marker, forward-version odmietnutie, cesty) sa zapíše do `SYSTEM/STANDARD.md`** v uzávere D1; D2 bránu dedí; testy: šablóna aj uložená doska s vyššou schémou = odmietnuté, bez pečiatky, bez session, bez zmeny modelu; dávka „Nahradiť UNI" nad modelom s doskou vyššej schémy = CELÁ náhrada zablokovaná (`blocked` nesie dosku), model nedotknutý.
  **Jeden POUŽÍVATEĽSKÝ krok Späť, nie „jedna operácia" (Astra BLOCKER):** vytváracia operácia `start_operation('Vložiť dosku', true)` + existujúci transparentný follow-up scale-lock zápis
  (`dynamic_attributes/scaletool`, vzor `board_builder.rb` — presun do vytváracej operácie by vypol selection eventy, vynechanie by uvoľnilo scale úchopy) pod SPOLOČNÝM `ScaleWatch.guard`;
  follow-up sa nesmie abortovať, `attach_one` ostáva; `rescue → abort_operation` len pre vytváraciu operáciu. **Bariéra pred mutáciou (audit 3):** `ScaleWatch.flush_pending!(model)` beží PRED `begin_commit!` session (session ostáva v stave umiestňovania, nie `:committing`);
  `false` (limit AJ výnimka — API ich nerozlišuje) = šev vráti EXPLICITNÝ výsledok `:blocked` + status (čakajúca kópia/scale by sa prilepila k vloženiu a poškodila Redo) — žiadne ID,
  geometria, krok Späť ani pečiatka a session NIKDY neskončí falošne `:committed`; test na `flush_pending! == false`. Overiť výber, Undo AJ Redo so zapnutým DC rozšírením.
  **Orientácia ide do commitu SAMOSTATNE** (Codex #288 P1): `stojaca` a `na_stenu` vedome zdieľajú maticu (STANDARD §orientácia), z `transform` sa odvodiť nedá — finálnu hodnotu zo session nesie
  argument a zapíše sa do `config['orientation']` (in-SU test to overuje v uloženom configu).
  **`GhostTool` dostane SUBJEKT (skrinka | doska) a INTERAKCIU (`interaction: placement | drawing`, audit 4):** `PlacementSession` číta obálku a kotvy zo subjektu, commit cez šev
  subjektu; interakcia je EXPLICITNÝ rozlišovač session (nie hádanie podľa prítomnosti fázy) a riadi kliky (placement: 1. klik = commit; drawing: 1. klik = počiatok, 3 fázy), klávesy
  (ALT kotvy len v placement), `enableVCB?` (len drawing) aj payload pásika; D1 zavádza `placement` pre oba subjekty, D2 pridá `drawing` pre dosku; charakterizácia
  `cabinet → board placement → board drawing → cabinet`; **klasický tok skrinky sa NEMENÍ** (existujúce `run_ghost*`
  sekcie zelené bez úpravy) + nová charakterizácia **skrinka → doska → skrinka** (pamäť a callbacky sa nepomiešajú). **Pamäť ghostu je oddelená per subjekt A interakciu** (`cabinet` / `board placement` / `board drawing`): doska si v `placement` pamätá LEN rotáciu a kotvu; **`drawing` má PEVNÝ počiatok
  = kotva `fl_bottom` a pamätanú kotvu placementu IGNORUJE** (ALT v kreslení nemá význam; Codex #296 kolo 2 P2 — charakterizácia placement s ALT `fr_top` → drawing = doska začína presne
  v kliknutom počiatku); **orientácia žije LEN v session** a každá nová session ju číta z karty Dosky (karta ju nastavuje pri každej materializácii, aj zo šablóny — Codex #288 P2).
  **Politika výšky dosky:** doska sa prichytáva plne v XYZ (`pick_free` sémantika s inferenciou; ŽIADNY Z-zámok z pamäte skrinky — inak roh hornej skrinky skončí na zamknutej výške), prázdny
  model = rovina Z = 0; test snapu na ZVÝŠENÝ roh skrinky. **Server odmieta kabinetové callbacky pre dosku** (`ghost_lock_z` a spol. kontrolujú subjekt session, nie len „aktívna session").
  **Kotvy dosky = AUTORITATÍVNA TABUĽKA** (nie odvodenie z helpera) — identifikátory a poradie ALT cyklu ZHODNÉ so skrinkou (`GhostTool::ANCHORS = fl_bottom → fr_bottom → fr_top → fl_top`,
  „predná" plocha = plocha s nižšou lokálnou Y, ako pri skrinke); body v LOKÁLNYCH súradniciach umiestnenej dosky (L = dĺžka, W = šírka, T = hrúbka, mm):
  `leziaca` (X = L, Y = W, Z = T): `fl_bottom (0,0,0)` · `fr_bottom (L,0,0)` · `fr_top (L,0,T)` · `fl_top (0,0,T)` — kotvy na PREDNEJ dlhej hrane, spodná/horná plocha;
  `stojaca` (X = L, Y = T, Z = W — doska stojí na spodnej hrane): `fl_bottom (0,0,0)` · `fr_bottom (L,0,0)` · `fr_top (L,0,W)` · `fl_top (0,0,W)` — kotvy na PREDNEJ zvislej ploche;
  `na_stenu`: TÁ ISTÁ tabuľka ako `stojaca` (STANDARD §orientácia: zdieľaná matica, rozdiel je len v configu). Nezávislý test: zvolená kotva COMMITNUTEJ geometrie skončí presne na
  kliknutom bode pre všetky 3 orientácie × 4 kotvy (nie porovnanie helper vs helper).
  **Klávesy (ROZHODNUTÉ (a) — Michal 4.9.):** ←/→ rotácia okolo Z (ako skrinka) · **↑/↓ = cyklus orientácie `leziaca → stojaca → na_stenu`** (vlastnosť dosky, nie voľná rotácia — kusovník,
  hrany a ABS ostávajú správne; Z-režim skrinky pre dosku nahrádza orientácia a XYZ prichytenie) · ALT = kotvy · natívny zámok osí (↑←→↓ od SU 2016) je v ghoste vedome pohltený
  (`onKeyDown` vracia `true`; probe 5.9.: šípky prídu s `VK_UP/DOWN/LEFT/RIGHT`, Shift s `VK_SHIFT`).
  **Synchronizácia s kartou a pásik (audit 3):** push ghostu nesie `subject` + `orientation`; pásik ghostu pre dosku SKRYJE kabinetové ovládače výšky (`gbMode`, `gbLockWrap` — pole
  `ghost_lock_z` sa pre dosku z JS nikdy nepošle, server ho navyše odmietne), ukáže orientáciu a doskovú nápovedu; JS aktualizuje `NXInsert.boardOrientation` BEZ materializácie/resetu karty (karta ukáže „stojaca"
  hneď po ↑; ďalšia session štartuje z tejto hodnoty). Karta Dosky: „Vložiť dosku" štartuje ghost session (ako „Vložiť skrinku"), Esc = nič sa nevloží, 0 krokov Späť.
  **Callbacky:** `insert_board` = D1 ghost (aj dvojklik šablóny dosky); D2 dostane SAMOSTATNÝ serverom whitelistovaný callback `draw_board` — HTML `disabled` ani názov tlačidla nie sú ochrana.
  **Pečiatka šablóny (Codex #288 P2):** `template_ref` dosky nesie SESSION a `stamp_once!`/„Naposledy použité" sa volá **až po úspešnom commite** — Esc pečiatku NEzapíše.
  **Tool kontrakt (outside-in):** jeden `Sketchup::Tool` (kostra Trimble `02_custom_tool`, MIT); `getExtents` = obálka ghostu (náhľad mimo obálky modelu / prázdny model), prekresľovať
  `View#invalidate`; obrazovkové API (`x,y` callbackov, `draw2d`, viewport, `PickHelper`, vstup `pickray`) v LOGICKÝCH pixeloch (SU 2025+), geometria (`InputPoint#position`, obálka,
  `getExtents`, `View#draw`) v modelových jednotkách; `onCancel` reason 0 (Esc — probe ✔) / 1 (opätovný výber TOHO ISTÉHO nástroja) / 2 (Undo počas nástroja) = zrušiť session bez zápisu; **prepnutie na INÝ nástroj prichádza cez
  `deactivate`** (nie `onCancel`) = session zrušená bez zápisu, viewport a pásik vyčistené — test `deactivate` osobitne (Codex #296 P2);
  `Sketchup::Overlay` a `Sketchup::Snap` = NO ACTION (Snap = perzistentná snap entita pre natívny Move, `Entities#add_snap` — poznámka pre viazané diely po V1).
  **Scope OUT:** kreslenie na rozmer (D2) · roly dosiek (worktop/pilaster/plinth) · automatické generovanie · viazané diely (po V1).
  **Testy a DoD:** headless — tabuľka kotiev per orientácia (3×4 body) + obálka, cyklus orientácie, štart session z hodnoty karty (predvolená šablóna „stojaca" po predošlej ležiacej session),
  plán zmrazený (žiadna mutácia; zmena katalógu po prepare → commit identický), `commit_insert` odmietne cudzí model / otvorený kontext / nerigidnú maticu, `orientation` v configu, pamäť per
  subjekt (skrinka → doska → skrinka), pečiatka len po commite, **aktualizovaný `test_ghost_vkladanie.rb` (`handle_insert_board` = synchrónne ukončí session skrinky, založí session dosky,
  pred klikom žiadna doska ani krok Späť)**; **in-SU `run_ghost_d1`** — ghost dosky vloží dosku na kliknutý bod s prichytením na roh skrinky (aj ZVÝŠENÝ roh), ↑ zmení orientáciu (stojaca),
  karta ju ukáže a **uložený config ju nesie**, ←/→ rotácia, ALT kotva, Esc = model nezmenený, 0 krokov Späť a šablóna neopečiatkovaná, vloženie = 1 krok Späť **a Redo funguje**,
  kusovník má dosku, ghost skrinky nezmenený (skrinka → doska → skrinka), `ghost_lock_z` pre dosku odmietnutý, pásik bez ovládačov výšky; **`onCancel(2)` pre dosku:** predchádzajúci
  krok Späť → ghost dosky → Ctrl+Z → predchádzajúci krok sa vráti a doska/session/pečiatka nezanechajú stopu; **výmena dokumentu** (File > Open / prepnutie okna) počas board session =
  session zrušená bez zápisu (aj pri recyklovanom `Sketchup::Model` objekte na Windows); **`run_ghost_d1_async`** — vloženie dosky počas čakajúcej kópie/scale
  (bariéra `flush_pending!`), potom Undo/Redo čisté (vzor `run_ghost_async`). Mutácie min. 5 (orientácia zapísaná do výrobných osí · commit mimo operácie · subjekt skrinky číta obálku dosky ·
  orientácia odvodená z matice · commit bez bariéry `flush_pending!`).
  **Smoke pre Michala:** karta Dosky → Vložiť → doska visí na kurzore, prichytí sa na roh skrinky (aj hore), ↑ ju postaví, klik vloží (karta ukáže „stojaca"), Ctrl+Z vráti, Ctrl+Y vráti späť;
  vkladanie skriniek ako doteraz.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `construction.md` (šev board_builder, BoardPlan, jeden krok Späť, `BOARD_CONFIG_SCHEMA`), `ui-lifecycle.md` (ghost
  subjekt + interakcia, pamäť per subjekt, klávesy, pečiatka, sync karty, pásik dosky, `deactivate`), **`SYSTEM/STANDARD.md` (kontrakt configu dosky: marker, forward-version odmietnutie)**, **`outputs.md`** (`newer_configs` už nie sú len skrinky — druh záznamu, brána
  BOM/VEPO/nákup/rozpočet/ponuka; dnešná veta „neblokuje VEPO" sa prepíše), **`materials.md`** (`materials_replace_uni` — brána schémy pred normalizáciou; Codex #296 kolo 4 P1),
  ARCHITEKTURA router pri novom súbore → STAV/KRONIKA/PLAN.

- **GHOST-D2 · TASK PACKAGE „KRESLENIE DOSKY NA ROZMER (Ghost 2.0)" (po D1; outside-in HOTOVÝ + probe SU 26.0.429 5.9.; Codex #288 kolá 1–2 zapracované; **Audit: HOTOVÝ — Codex CLI 5.9.2026, 4 kolá (Sol + Astra), kolo 4 SOUND**; in-SU POVINNÉ):**
  **STAV IMPLEMENTÁCIE: ✅ GHOST-D2 KOMPLET (5.9.2026, v0.9.28)** — fázový automat `:origin → :length → :width → :done` so zámkami fáz, dve rozdielne geometrie ťahov
  (rovina Z počiatku · pevná os per orientácia) s plným guardom degenerácie, kanonický smer pri nulovom vektore, pravotočivý záporný 2. ťah, vlastný parser meracieho poľa
  + limity pre všetky 4 zdroje rozmeru, `enableVCB?`/`onUserText`/`onReturn`, Shift hold-to-lock so zamknutým smerom aj vo voľnom priestore, samostatný callback `draw_board`
  so zámkami z karty, tlačidlo „Nakresliť" a fáza v pásiku, `BoardBuilder.replan`. Headless `test_ghost_d2_kreslenie.rb` (75), JS `test_ghost_d2_karta.js` +
  `test_ghost_d2_pasik.js`, in-SU `run_ghost_d2` + `run_ghost_d2_async`. Znenie nižšie je autorita, podľa ktorej sa implementovalo.
  **Cieľ:** doska sa nakreslí **dvoma ťahmi**: klik = nulový bod → ťah dĺžky (prichytenie SketchUp inference ALEBO napísané číslo v mm do meracieho poľa) → klik → ťah šírky → klik = vloženie;
  hrúbka z materiálu karty. **Ťahy sledujú LOKÁLNE osi dosky podľa orientácie** (Codex #288 P2): dĺžka = lokálna X (pri ležiacej aj stojacej doske vodorovná), šírka = lokálna Y (pri stojacej
  zvislá) — pilaster: ↑ stojaca, 1. ťah = hĺbka (dĺžka), 2. ťah = výška (šírka); orientácia (↑/↓) a rotácia (←/→) sa menia LEN vo fáze 0 (pred klikom počiatku) — od kliku počiatku sú zamknuté (jedna hranica, viď Klávesy). Precedens: natívny Rotated Rectangle (jedno číslo
  na fázu — rozhodnutie Michala 4.9. potvrdené), OpenCutList 7.0 Smart Draw (GPL — len vzory), SketchList 3D (3 orientácie).
  **Predloha:** archívny V2fable Ghost 2.0 — `SYSTEM/zdroje/archiv_kod/v2fable_ghost_tool2.rb.txt` (fázy, `enableVCB?`/`onUserText`, axis snap, locks — port do subjektu dosky, nie kópia).
  **Callback (R-02, audit 3):** samostatný serverom whitelistovaný `draw_board` (D1 `insert_board` ostáva pre vloženie a dvojklik šablóny); tlačidlo karty „Nakresliť" posiela `nxDocPayload`
  a Ruby volá `foreign_document?` ako ÚPLNE PRVÝ krok (vzor `handle_insert_board`); záväzné poradie: doc guard → šablóna/zámky → prepare/replan → session — oneskorený CEF callback zo starého
  Inspectora po prepnutí zákazky nesmie pripraviť `BoardPlan` nad novým modelom; test so starým `model_guid`.
  **Smer dosky (audit 1 BLOCKER, audit 2 FIX):** dve fázy majú ROZDIELNU geometriu — **fáza 1 HĽADÁ SMER**: kurzor (`InputPoint` s natívnou inferenciou) sa premieta do ROVINY 1. ŤAHU
  = vodorovná rovina Z = Z počiatku pre VŠETKY orientácie (dĺžka je vodorovná aj pri stojacej doske), smerový vektor = počiatok → premietnutý kurzor (voliteľný axis snap na osi modelu
  v tolerancii, vzor Ghost 2.0 — pomôcka, nie obmedzenie), dĺžka = |vektor| alebo napísané číslo (smer ostáva z kurzora); ŽIADNA projekcia na „lokálnu os" vo fáze 1 (kruhová závislosť:
  os ešte neexistuje — test šikmého 1. ťahu 45° v prázdnom modeli = rotácia 45°, nie 0°). **Brána voľného priestoru vo fáze 1 (audit 3, vzor dnešného ghostu):** použije sa LEN reálna
  geometrická inferencia (vertex/hrana/plocha) premietnutá na Z = Z počiatku; „voľný" InputPoint bez geometrie sa NEPOUŽIJE (pri otočených drawing axes leží mimo kurzora) → namiesto neho
  priesečník `view.pickray(x, y)` s rovinou Z = Z počiatku **s PLNÝM guardom dnešného ghostu** (`construction.md`: parameter lúča `t >= 0` — rovina za kamerou = neplatné, konečné
  súradnice, uhlový prah proti takmer rovnobežnému lúču, `MAX_REACH_MM`; Codex #296 kolo 2 P2) — porušenie = fáza nepokročí + status; testy: rovina za kamerou, takmer rovnobežný pohľad
  z oboch strán, OTOČENÉ drawing axes, nie len predvolené. **Rotáciu okolo Z určuje smerový vektor v okamihu POTVRDENIA 1. fázy** (klik, Enter s číslom,
  prázdny Enter alebo zamknutá dĺžka); ak je vektor nulový (kurzor sa od počiatku nepohol — číslo napísané hneď, obe fázy zamknuté), použije sa **kanonický smer = lokálna +X podľa
  rotácie session (←/→ vo fáze 0)** a status to povie; nulový vektor sa NIKDY nedostane do transformácie (test). **Fáza 2 MERIA po PEVNEJ osi** = lokálna Y kolmá na 1. ťah (ležiaca:
  vodorovná; stojaca/na_stenu: zvislá, svetová +Z) — projekcia + pickray fallback (nižšie). Fázový automat pokrýva **všetky 4 kombinácie zámkov** a číslo bez pohybu myšou.
  **Zámky fáz — prenos do Ruby (audit 1 BLOCKER, audit 2 PARTIAL):** `NXInsert.boardLocks` je súkromný JS stav („NIKDY do Ruby") → pri štarte D2 session JS pošle **ČÍSELNÝ snapshot
  `locks: { length: <mm>, width: <mm> }` cez existujúci `locksFlat('board')`** (vracia HODNOTY zamknutých polí, napr. `{length: 800}`; nezamknutý kľúč chýba) ako SAMOSTATNÉ pole payloadu —
  žiadny prevod na Boolean; Ruby whitelist LEN kľúče `length`/`width`, hodnota = Float mm validovaná proti `BoardBuilder::LIMITS` už pri štarte session (mimo limitu / nečíslo = session sa
  nespustí + status); zámky NIKDY neskončia vo výrobnom configu. Zámok z toho, že pole má hodnotu, neexistuje (Codex #288 P1: polia sú vždy predvyplnené 800 × 600).
  **Odvodený plán (Codex #288 P1):** D1 šev beží nad plánom zmrazeným PRED štartom ghostu; D2 pozná rozmery až po ťahoch → čistý krok **`replan(plan, length:, width:)`** = NOVÝ zmrazený `BoardPlan`
  s finálnymi rozmermi, ktorý zachová vyriešený výrobný snapshot (materiál, `material_source`, šablóna) BEZ opätovného čítania katalógu; **názov:** plán rozlišuje explicitný vs automatický
  názov — automatický („Doska 800×600") sa finalizuje z NOVÝCH rozmerov, explicitný ostáva; test: náhľad = config = geometria z odvodeného plánu.
  **Presnosť (audit 1 NOTE):** rozmery sa zaokrúhľujú na 0,01 mm (2 desatinné miesta, ako `board_config`) UŽ pri prijatí hodnoty (parser aj potvrdenie ťahu myšou) — náhľad, config a geometria
  nesú tú istú hodnotu (test `600,123` → 600,12 všade; rebuild nemení geometriu).
  **Inferencia a lokálne osi (outside-in + probe 5.9.):** fázy cez `InputPoint#pick(view, x, y, ip_predošlý)` (inferencia relatívne k predošlému bodu vrátane „on axis from point");
  **lokálnu os definuje VLASTNÁ projekcia** bodu na priamku (`Point3d#project_to_line`, vzor axis snap archívneho Ghost 2.0) — probe 5.9. v SU 26.0.429: `view.lock_inference(ip_a, ip_b)`
  so syntetickými `InputPoint.new(pt)` vracia `inference_locked? = false` (3×), natívny zámok na vlastnú os NEFUNGUJE. **Voľný priestor (audit 1):** ak InputPoint nemá geometrickú inferenciu
  (voľný bod na rovine kreslenia), premietnutie z vodorovnej roviny dáva pri zvislej šírke pilastra konštantnú výšku → **fallback = najbližší bod medzi `view.pickray(x, y)` a priamkou lokálnej
  osi** (alt. pomocná rovina obsahujúca os a natočená ku kamere); **kontrakt degenerácie (audit 4, vzor dnešného ghostu):** uhlový prah medzi lúčom a osou (takmer rovnobežný lúč = takmer nulový
  menovateľ → výsledok odletí alebo zmení znamienko šírky), parameter lúča `t >= 0` (polpriamka od kamery, nie za ňou), konečné čísla a maximálny dosah; porušenie = fáza nepokročí +
  status; testy čistej geometrie: skoro rovnobežné pohľady z OBOCH strán, nie len presná rovnobežnosť. In-SU: šírka pilastra ťahaná mimo geometrie v perspektíve
  a pri otočených drawing axes. **Pravotočivý 2. ťah (Codex #288 P1):** pri zápornom smere sa posunie POČIATOK o −šírka po lokálnej Y, osi ostávajú pravotočivé — žiadne obrátenie `dir_y`;
  in-SU prípady pre kladný aj záporný smer.
  **Shift = natívny zámok inferencie (lifecycle, audit 1; Codex #296 kolo 6):** hold-to-lock (`onKeyDown` VK_SHIFT zamkne aktuálnu natívnu inferenciu `view.lock_inference(ip)`, `onKeyUp`
  odomkne); **zamknutý smer platí aj vo fáze 1 a aj vo voľnom priestore:** zamknutý inferovaný InputPoint (os od počiatku bez vertexu/hrany/plochy) sa PRIJME, alebo sa `pickray` fallback
  premietne na zamknutý smer — pohyb kurzora po zamknutí NESMIE zmeniť smer dosky; test overuje výsledný SMER, nie len `inference_locked?`; zámok sa
  VŽDY uvoľní pri zmene fázy, `suspend`/`resume`, `deactivate` a `onCancel` (zámok z 1. fázy nesmie obmedziť 2. ani visieť po nástroji); vzor `Eneroth3/inference-lock-lib` (MIT, len vzor);
  in-SU test skutočného `inference_locked?` (nie len projekčnej matematiky).
  **Klávesy od kliku počiatku (audit 1 + audit 2 NOTE — JEDNA hranica):** ←/→ a ↑/↓ platia LEN vo fáze 0; od kliku počiatku sú ZAMKNUTÉ (ignorované + status „orientáciu a rotáciu meň
  pred kliknutím počiatku") — rovina 1. ťahu aj os 2. ťahu závisia od orientácie, takže zmena uprostred by rozpracované rozmery preniesla do inej sústavy; ALT v režime kreslenia nemá
  význam (ignorovaný); Esc = reset celej session. Test intervalu „počiatok kliknutý, dĺžka nepotvrdená": šípky nič nemenia.
  **Meracie pole (probe 5.9., audit 3):** `enableVCB?` vracia `true` počas CELÉHO života D2 nástroja (vzor Ghost 2.0 — fázovo podmienené by nechalo Measurements pole po aktivácii
  vypnuté a písané rozmery by po prvom kliku neprišli); fáza riadi LEN label/hodnotu a spracovanie: vo fáze 0 sa `onUserText`/`onReturn` ignorujú; `Sketchup.vcb_label=` „Dĺžka (mm)" / „Šírka (mm)"; **jedno číslo na fázu**, Enter potvrdí; písaná hodnota príde
  cez `onUserText("600")`; **prázdny Enter = `Tool#onReturn(view)`** (`VK_RETURN` v SketchUp API NEEXISTUJE; `onKeyDown` dostane kód 13 aj v 26.0 — bez regresie; pri prázdnom poli `onUserText`
  nepríde) = vedome prevezme hodnotu karty pre TÚTO fázu (explicitná akcia, status to povie).
  **Parser:** VLASTNÝ, úplná zhoda po `strip`: `\A\s*(\d+(?:[.,]\d+)?)\s*(?:mm)?\s*\z/i` (bodka aj čiarka, `mm`/`MM` voliteľné); `abc2400xyz`, `2400mmjunk`, `~600`, `600;18` = neplatné;
  nikdy `String#to_l`/`to_f` na surový text (locale s desatinnou čiarkou); mm Float → `Units` do modelu.
  **Limity pre VŠETKY zdroje rozmeru (audit 1):** písané číslo, zamknutá hodnota, hodnota karty pri prázdnom Enter AJ dĺžka z myši sa validujú proti `BoardBuilder::LIMITS` (dĺžka 10–5000, šírka
  10–3000 mm) PRED posunom fázy — `normalize` inak ticho oreže a náhľad by ukázal 6000, model dostal 5000; mimo limitu / neplatný text = `UI.beep` + status s limitom + fáza ostáva (vzor
  Trimble `99_sphere_tool`, MIT); ťah myšou nad limit = náhľad orezaný na limit s výrazným statusom, klik mimo limitu odmietnutý.
  Obálka kreslená počas ťahu (`getExtents`, `View#invalidate`), kóty v tooltipe · Esc v hociktorej fáze = nič, 0 krokov Späť, šablóna neopečiatkovaná (D1 pravidlo) · commit ako D1
  (bariéra `flush_pending!`, vytváracia operácia + transparentný follow-up pod `guard`, `rescue → abort_operation`) · karta Dosky: **ROZHODNUTÉ (5.9.2026, orchestrátor v rámci V1 debaty 4.9. — Michal môže vetovať): dve tlačidlá vedľa seba v JEDNOM riadku — „Vložiť" (D1 ghost) a „Nakresliť" (D2)**,
  bez samostatného mockupu (existujúca karta + druhé tlačidlo; vertikálny priestor nerastie); zápis do `docs/UI_DIZAJN.md` je v uzávere D2.
  **Scope OUT:** viac čísel naraz („600;18") · tretí rozmer · roly dosiek · automatika pilastrov/PD (po V1, po agy researchi) · `Sketchup::Snap`.
  **Testy a DoD:** headless — parser (mm, desatinné, prefix/sufix, tilda, `;`, `MM`, medzery, zaokrúhlenie 0,01) + limity (9, 10, 5000, 5001; 3000/3001) pre všetky 4 zdroje, fázový automat
  (4 kombinácie zámkov, číslo bez pohybu = kanonický smer, nulový vektor nikdy v transformácii, šikmý 1. ťah 45° v prázdnom modeli = rotácia 45°, prázdny Enter = hodnota karty cez `onReturn`, klávesy po 1. fáze ignorované, Esc), whitelist
  payloadu `locks`, `replan` (snapshot zachovaný, názov explicitný/automatický), orientácia z ťahu a lokálne osi per orientácia, pravotočivosť pri zápornom 2. ťahu, fallback `pickray` → os
  (čistá geometria) a degenerovaný pohľad, obálka počas fázy; **in-SU `run_ghost_d2`** — nakresliť dosku dvoma ťahmi s prichytením na rohy dvoch skriniek (dĺžka = presne súčet šírok),
  „2400 Enter" → dĺžka 2400, „6000 Enter" → odmietnuté a fáza ostáva, prázdny Enter → hodnota karty, zamknutá dĺžka z karty + „600 Enter" bez pohybu myšou → kanonický smer, Esc vo fáze 2 =
  nič (0 krokov Späť), vloženie = 1 krok Späť + Redo, ↑ stojaca → pilaster (výška = 2. ťah ťahaná vo voľnom priestore v perspektíve) a uložený config nesie orientáciu aj presné rozmery
  (náhľad = geometria = config), záporný 2. ťah = pravotočivá doska, Shift lock: `inference_locked?` true počas držania a false po zmene fázy/Esc; **`onCancel(2)` a výmena dokumentu VO FÁZE 2** (s držaným Shiftom) = session zrušená, zámok inferencie
  uvoľnený, žiadna stopa; doručenie ALT a potlačenie menu na Windows = manuálny smoke (headless callback nestačí). Mutácie min. 5 (limit neoverený pred Enter ·
  zámok z vyplneného poľa · šírka pri stojacej po X · pečiatka pri Esc · nulový smerový vektor prepustený do transformácie).
  **Smoke pre Michala:** pracovná doska od ľavého rohu prvej po pravý roh poslednej skrinky, šírku napíš 600, hotovo; pilaster: ↑ stojaca, 1. ťah hĺbka, 2. ťah výška ťahaná do vzduchu;
  napíš 6000 → plugin odmietne s limitom; klikni počiatok a hneď napíš 2400 Enter → doska ide po osi podľa rotácie.
  **Checklist uzáveru:** bump patch + `?v=` → testy vrátane in-SU → `construction.md` (`BoardBuilder.replan`, fázy kreslenia, geometria lúča/projekcie, degenerácie, lifecycle zámkov —
  Codex #296 P1), `ui-lifecycle.md` (ghost D2, `interaction: drawing`, `draw_board`, zámky, Shift, VCB), `docs/UI_DIZAJN.md` (tlačidlá karty Dosky) → STAV/KRONIKA/PLAN.

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
- **D-52 · TASK PACKAGE „AKTUALIZOVAŤ JEDNÝM KLIKOM" (1e, zapísané 30.8.2026, rev. po slepom review #255; rev. po Codex audite 2.9.; ✅ **D-52 KOMPLET 3.9.2026** — D-52a PR #277 (v0.9.9) · D-52b1 PR #278 (v0.9.13) · D-52b2 PR #279 (v0.9.14); plný text v archiv/DOGFOODING_vyriesene.md):**
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
- **D-52b · TASK PACKAGE „UPDATER — UI V ŠTÚDIU" (D-52a je v maine — PR #277; ŠTARTOVATEĽNÁ;
  **REZ 3.9. (pravidlo 3 kôl po Codex kole 3 na #278):** **D-52b1** = #278 prerobený (cesta + nastavenia + async check + stavový riadok + doklad; tlačidlo len aria-disabled) ·
  **D-52b2** = `feat/d52b2-updater-apply` stacked (apply flow: single-flight, worker príprava, guard show počas in-flight + re-check dialog_closed? pred commit!, hlášky, in-SU async).
  3× P3 z delta-verifikácie #277 zapracovať: (1) `clear_marker` výsledok sa na rollback/refuse cestách zahadzuje — do `Refused` správy doplniť poznámku o markeri; (2) tautologický assert `clear_marker == 'true'` v `test_d52a_updater.rb:~1312` odstrániť; (3) `close_all_dialogs` overiť in-SU, headless ho nepokrýva):**
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
- ~~**D-20 · Quick actions — bezpečný move plugin**~~ — **✅ VYRIEŠENÁ 4.9.2026** package **NÁSTROJE-1** (T1a PR #293 v0.9.24 + T1b PR #294 v0.9.25); plný text v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md).

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
