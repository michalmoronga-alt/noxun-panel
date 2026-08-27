# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (uzáver etapy = minor bump).
> **Údržba:** pri uzávere dávky sa jej riadok z bloku odstráni, odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a prepíše sa [STAV.md](STAV.md). Plné znenie otvorených postrehov žije v [DOGFOODING.md](DOGFOODING.md) **v skupinách podľa týchto blokov** — tu je len číslo, názov a jedna veta.

## Bloky

*(Blok **1 · UI 2.0 — štúdio okno a výbery** je uzavretý (v0.8.0, 24.8.2026) — plný text
je v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md). Čísla ostatných
blokov sa kvôli odkazom v STAV a KRONIKE neprečíslúvajú.)*

**Poradie najbližších blokov (rozhodol Michal 26.8.2026, doplnené v ten istý večer o hardening sekvenciu):**
**1b STABILIZAČNÁ REVÍZIA → 1c AUDIT KÓDU → 1d REFAKTOR Z REGISTRA → 1e PLÁNOVACIA DÁVKA (task packages) → GHOST VKLADANIE → KOVANIE**
(pred KOVANÍM USER-debata o setoch). Zmysel sekvencie: audit a refaktor **pripravujú pôdu presne pre naplánované funkcie** a doťahujú staré dlhy — až potom nové funkcie.
*(Blok **PICKER-3** je hotový — v0.8.5, 26.8.2026; plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md), výsledok v [archiv/KRONIKA.md](archiv/KRONIKA.md).)*

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
  do tej istej skupiny patrí aj **výklop ako samostatný typ čela** (bez D-čísla). Otvorené **D-106** / **D-107** sem pôvodne patrili tiež, dnes žijú vo svojich skupinách podľa zaradenia:
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

### 1c · AUDIT KÓDU (read-only — po 1b; rozhodnuté 26.8.2026 večer)

**Cieľ:** pripraviť plugin na naplánované funkcie a pomenovať všetky nedorobky. **Žiadny kód sa nemení** — výstupom je
**register nálezov** (nový súbor `SYSTEM/AUDIT_REGISTER.md`, štýl DOGFOODINGu: R-číslo · závažnosť **P0 (len ako
pointer na okamžitú hotfix dávku s výsledkom — nečaká v registri)** / P1–P3 · vrstva · súbor ·
**ktorú naplánovanú funkciu blokuje** · návrh riešenia). Audit, ktorý rovno opravuje, sa nedá kontrolovať.

- **Tri nezávislé pohľady:** externý Codex audit (spúšťa Michal; podklad: [zdroje/AUDIT_2026-08_podklad.md](zdroje/AUDIT_2026-08_podklad.md))
  · vlastný prechod (Fable) · slepý subagent. Nálezy sa zlejú do jedného registra s dedupom.
- **Vstup, ktorý už čaká:** [zdroje/SWEEP_2026-08_kandidati.md](zdroje/SWEEP_2026-08_kandidati.md) — nálezy z post-hoc sweepu #186–#226: sekcia **A** 7 z hlavnej session sweepu ·
  sekcia **B** 18 z triáže review threadov (*z toho B1 je už vyriešené, otvorených 17*) · sekcia **C** 13 ďalších z bloku 1b (*C4 a C5 sú tiež už vyriešené*). Každý má adresu v kóde.
  **Prvý krok bloku 1c je preliať tento zoznam do registra**, v tomto poradí: **(1)** dedup (známe zhody sú v zozname vymenované) → **(2)** vyradiť to, čo je medzitým hotové alebo
  už má dávku → **(3)** overiť proti vtedajšiemu `main` (čísla riadkov sú k `0070697`, `ui/production_core.rb` sa medzitým posunul) → **(4)** až potom priradiť R-číslo, závažnosť,
  vrstvu a blokovanú funkciu.
- **Prioritné osi auditu** (od budúcich funkcií dozadu): observery/undo/Tool lifecycle (→ GHOST) · dátový model setov kovania
  (→ D-109/KOVANIE) · `ui/production_core.rb` — jadro výstupov v UI vrstve (→ Ponuka/plošná kontrola) · payload kontrakty a identita ·
  perzistencia, `std` verzie, migrácie (→ shared library) · zjednotenie UI vzorov na nx_modal/nx_combo · VŠETKY aktuálne stub odseky architektúry (k 26.8. ich je 19; zoznam grepom, detail v podklade).
- **Mimo záberu** (zapísané aj v podklade): prepisovanie funkčných builderov a zapisovacích ciest · hromadné premenovania ·
  vizuál Inspectora/Štúdia · predčasné abstrakcie pre neschválené funkcie (attachment/segmenty) · výkon bez merania.

### 1d · REFAKTOR/HARDENING Z REGISTRA (po 1c)

V 1d sa rieši **len to, čo je výrobné riziko alebo blokuje PONECHANÝ V1 rozsah** — nálezy viažuce sa výhradne na po-V1 témy
(DOCX/PDF renderer, G-Disk sync…) ostávajú v registri zaradené na neskôr, pred V1 sa pre ne nerefaktoruje.
Register sa vyprázdňuje **malými dávkami** (malé PR > obrie PR), zoradené podľa závažnosti × blokovanej funkcie.
Pravidlo podľa druhu dávky: **štrukturálny refaktor = „správanie sa nemení"** (presun zodpovednosti, testy to dokazujú);
**oprava chyby/hardening = explicitná, testom podložená ZMENA správania** (v PR pomenovaná: čo bolo zle → čo platí teraz).
In-SU testy povinné pri builderoch/observeroch; mutačné overenie štandard. Nálezy z reálnej výroby majú stále prednosť
(Pravidlo pre postrehy). Dávka, ktorá nevie povedať, ktorú naplánovanú funkciu pripravuje alebo ktorý dlh spláca, sa nerobí.

### 1e · PLÁNOVACIA DÁVKA — task packages (po 1d)

Zliať koncepty [zdroje/next_sessions/](zdroje/next_sessions/) 01–09A + zvyšné bloky PLANu do jedného backlogu →
roztriediť do **kódových a logických blokov** → každému určiť **prioritu · náročnosť · závislosti · či mení dátový kontrakt**
(→ audit-povinnosť) → z blokov spraviť **task packages**. Package = plný blok v PLANe (autorita); koncept ostáva podkladom.
**Šablóna package (povinné polia):** cieľ · scope IN · **scope OUT** (čo dávka vedome NErobí) · dotknuté dáta/kontrakt →
audit áno/nie · testy a DoD · riziká · smoke checklist pre Michala · checklist uzáveru. Každý package si na štarte
spraví krátky read-only audit proti aktuálnemu mainu. Agenti si potom packages preberajú sekvenčne bez ďalšieho plánovania.

### GHOST VKLADANIE (V1-04 — zaradené Michalom 26.8.2026, po bloku 1e)

Vkladanie skrinky na klik: skrinka visí na kurzore ako ghost, klik umiestni. **Podklad (NEZÁVÄZNÝ koncept,
auditovaný proti v0.7.51):** [zdroje/next_sessions/09_GHOST_VKLADANIE.md](zdroje/next_sessions/09_GHOST_VKLADANIE.md)
+ externý SketchUp audit [09A](zdroje/next_sessions/09A_GHOST_EXTERNY_SKETCHUP_AUDIT.md) (Tool/InputPoint lifecycle, Orbit suspend/resume, Undo/onCancel, getExtents, klávesové pasce).
Koncept obsahuje aj **nedorozhodnuté voľby** (napr. Tab vs. Alt/Option, počiatočný Z režim) — nie je to schválený kontrakt ani task package (vrstva `zdroje/`, [README.md](README.md)).
**Pred implementáciou POVINNÉ:** finálny read-only audit proti aktuálnemu mainu + načítanie STAV/PLAN/ARCHITEKTÚRA/STANDARD;
sporné body potvrdiť auditom alebo debatou s Michalom. **Záväzné znenie vznikne až v zadaní dávky** a zapíše sa sem do PLANu.

### KOVANIE (zaradené Michalom 26.8.2026, po bloku GHOST VKLADANIE)

**Predpoklad štartu: USER-debata s Michalom o setoch** (podklad sa pripraví pred debatou; dáta v [zdroje/SEED_KATALOG_2026-07.md](zdroje/SEED_KATALOG_2026-07.md) §2,
nezáväzný koncept [zdroje/next_sessions/03_KOVANIE_FAZA3.md](zdroje/next_sessions/03_KOVANIE_FAZA3.md)).

- **Redizajn katalógu a setov — z prvého testu v0.8.0 (Michal 24.8.):** **D-109** pomer člena setu „1 ks na N nôh" (príchyt soklovej lišty — dnes len per unit/owner, pomer sa musí dopočítať ručne)
  · **D-110** pridávanie kovaní je neprehľadné (formulár dole pod zoznamom, poradie polí nesedí s dodávateľským listom; *časť „nová položka nie je vidieť" vyriešená v TEST-1, PR #229*) · **D-111** výber
  setu podľa výšky sokla je schovaný v Predvoľbách projektu, hoci ho človek hľadá pri vkladaní skrinky. Plné znenia v [DOGFOODING.md](DOGFOODING.md).
- **Kovanie fáza 3 — V1 rozsah:** výplne šuflíkov **vo výťaži/kusovníku — fáza A** (V1-05, Atira dno+chrbát, Quadro/Tandem; vzorce dodá Michal) · výklopy ako **cenové zaradenie
  podľa hmotnosti** (C-05 — AVENTOS tabuľky, hustoty z M-C ako SNAPSHOT) · smer otvárania a typ závesu · automatika počtu nôh podľa šírky · „Použiť na podobné".
  **Mimo V1** (V1_VIZIA): plný geometrický model výklopov a geometria výplní (fáza B) — v zásobníku.

### 2 · KONTROLA + VÝROBA

**Cieľ:** dotiahnuť krížovú kontrolu zákazky pred odoslaním do výroby a výrobné výstupy.

- **D-94 · Traceability v súpise kovania** — rozklik nákupného riadku na skrinky a čelá, z ktorých vznikol (dáta `sources` už existujú) + klik-select v modeli.
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
- *(Vkladanie na klik — V1-04 — sa 26.8. vyčlenilo do vlastného bloku **GHOST VKLADANIE** vyššie.)*
- **D-10 · Presúvanie a úprava čiel priamo v náhľade** — ako drag priečok.
- **V1.0 zostavy:** spájanie a zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, snaper logika) · soklová lišta v celku pre segment · obklady a krycie prvky segmentu vrátane pilastra
  (priznaný vs. skrytý) · pracovné a horné krycie dosky na označený segment · migrácia a oprava starých modelov · test na kompletnej reálnej zákazke. **Mimo V1** (V1_VIZIA):
  plné segmenty s `attachment` dátovým kontraktom, automatické krycie dosky a PD cez segment — v zásobníku (koncept 02 je podklad).

### 5 · RENDER M-R

**Cieľ:** materiál vyzerá v modeli ako v skutočnosti — Luciin nástroj na vizualizácie.

- **V1 rozsah — quick-win:** Demos fotka dekoru ako textúra SU materiálu (bez PBR, bez knižnice vzhľadov) — presne to, čo žiada bod 7
  checklistu [V1_VIZIA.md](V1_VIZIA.md). Všetko ostatné v tomto bloku je **mimo V1** (zásobník; plná appearance vrstva + pixla).

- **D-28 · Textúry materiálov = M-R knižnica vzhľadov** (D-28 je do M-R zlúčená, samostatne sa nerieši): `texture_path` + render vlastnosti PBR + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 = orientácia textúry podľa smeru dekoru dielca. Zdroj JPG knižnica na firemnom Disku; väzba na D-48.
  *(**D-87** — overlay čiar v smere dekoru — je **HOTOVÝ** v bloku KRESBA (K2, PR #188, v0.7.26); tu ostáva len **orientácia textúry** podľa smeru dekoru ako fáza 2 D-28. Overlay je kontrola, textúra je render — dve rôzne veci.)*
- **Nástroj „pixla"** (V1-06) — ikonka na dlaždici materiálu, klik prefarbuje dielce cez `part_override` cestu (1 klik = 1 undo).

### 6 · INFRA (priebežne, podľa potreby)

**Cieľ:** aby plugin a knižnice fungovali na dvoch pracoviskách (Michal + Lucia).

- *(**D-48 · Zdieľaná knižnica pre 2 PC** je od 26.8. MIMO V1 — presunutá do zásobníka Po V1; katalógy sa dovtedy zdieľajú ručne export/importom.)*
- **D-52 · Tlačidlo „Aktualizovať" (auto-update pluginu) — V1 rozsah samostatne:** jednoklikový update (distribučný kanál jednoducho — napr. zdieľaný priečinok), BEZ väzby na D-48 sync.
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
