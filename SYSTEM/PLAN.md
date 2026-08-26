# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (uzáver etapy = minor bump).
> **Údržba:** pri uzávere dávky sa jej riadok z bloku odstráni, odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a prepíše sa [STAV.md](STAV.md). Plné znenie otvorených postrehov žije v [DOGFOODING.md](DOGFOODING.md) **v skupinách podľa týchto blokov** — tu je len číslo, názov a jedna veta.

## Bloky

*(Blok **1 · UI 2.0 — štúdio okno a výbery** je uzavretý (v0.8.0, 24.8.2026) — plný text
je v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md). Čísla ostatných
blokov sa kvôli odkazom v STAV a KRONIKE neprečíslúvajú.)*

### PICKER-3 · dorobenie vyhľadávača materiálov

**Odčlenené z PR #231 podľa pravidla 3 kôl (25.8.)** — kolo 3 Codex review prinieslo osem
vecných nálezov; **ship-blockery sa opravili v #231**, zvyšok je tu. Dôvod rezu: bod **E**
je **návrhová zmena** (kontext výberu má radiť aj riadky medzi sebou), a tá si zaslúži
vlastný návrh + review, nie ďalšiu iteráciu v dobiehajúcom PR — doťahovačky idú s ňou,
aby sa okruh riešil naraz. Poradie určí Michal; nič z toho nie je blokujúce (vyhľadávač je
použiteľný), ale všetko je pomenované, aby sa to nestratilo.

- **A · Virtuálne dupláky v kontexte menovky riadku** (`noxun_engine/ui/panel/payloads.rb`, comment **3848691739**, P2). Kontext `row_fam_ctx` vidí len `Materials.sheets`, takže rodinu s jednou
  kúpenou hrúbkou plus virtuálnou ponukou `duplak2:` označí za jednovariantnú a server pošle menovku „Dekor · DTDL 18 mm". Klient potom na ten istý riadok pridá čip `36 duplák` — a po jeho výbere
  menovka riadku ďalej tvrdí 18 mm. Fix: postaviť kontext s virtuálnymi variantmi, alebo hrúbku v menovke potlačiť vždy, keď riadok čipy dostane.
- **B · Normalizovať VŠETKY zložky kľúča rodiny** (`noxun_engine/core/materials.rb`, comment **3848691741**, P2). Kanonická je zatiaľ len skupinová časť; `decor`, `structure`, `type` a prípona idú v
  surovom orezanom tvare. Katalógový kontrakt pritom identity typu a štruktúry porovnáva **bez ohľadu na veľkosť písmen**, takže `DTDL`/`dtdl` alebo `ST9`/`st9` dostanú rôzne kľúče a dekor sa v ponuke
  zjaví ako **dva riadky**. Fix: skladať rodinu z normalizovaných zložiek (ideálne z kanonickej identity dosky bez hrúbky).
- **C · Dotaz „54 duplák" musí trafiť SVOJ duplák** (`noxun_engine/ui/js/nx_combo.js`, comment **3848691744**, P2). Keď má rodina duplák ×2 aj ×3, slovo „duplák" v dotaze vráti **prvý** duplák (spravidla 36 mm) ešte pred prečítaním čísla. Riadok sa nájde, ale Enter vloží iný duplák, než dotaz menoval. Fix: pri slovnom dotaze najprv hľadať zhodu hrúbky medzi duplákmi a až potom padať na prvý.
- **D · Dôvod nedostupného čipu aj z KLÁVESNICE** (`noxun_engine/ui/js/nx_combo.js`, comment **3848691758**, P2). Po prechode na `aria-disabled` je čip fokusovateľný, ale jediná klávesová cesta (šípky
  vľavo/vpravo) nedostupné varianty **preskakuje** a `Tab` ponuku zatvára — človek od klávesnice sa teda k vysvetleniu, ktoré myš dostane klikom, nedostane. Fix: pustiť fokus do tlačidiel čipov, alebo
  dať klávesovú akciu, ktorá na nedostupnom čipe zastane a dôvod oznámi.
- **E · KONTEXT VÝBERU MÁ RADIŤ AJ RIADKY (návrhová zmena)** (`noxun_engine/ui/js/nx_combo.js`, comment **3848691761**, P2 — vecne najväčší). Kontext (`back` → 3 mm, `worktop` → 38) sa dnes uplatňuje
  **vnútri** už rozdelenej rodiny, takže nevie uprednostniť riadok HDF 3 pred riadkom DTDL 18 toho istého dekoru. V Štúdiu je `md_back` naplnený **všetkými** doskami bez zakázania nechrbtových
  variantov: po napísaní dekoru je prvý zhodný riadok spravidla DTDL, jeho predvoľba je 18 mm a Enter ju vloží — hoci kontext „chrbát" sľubuje HDF 3. Fix: kontext musí riadky **radiť alebo filtrovať**
  predtým, než sa vyberie aktívny riadok, nielen hľadať 3 mm vnútri každého z nich.

### 1b · STABILIZAČNÁ REVÍZIA (dlhy fázy ŠTÚDIO — pred blokom KOVANIE)

**Cieľ:** doplatiť dlhy, ktoré fáza ŠTÚDIO vedome odložila, a spraviť refactory, na ktoré počas presunov nebol priestor. *(Stabilizačná revízia sa od začiatku produkcie naostro (20.8.) ešte NEKONALA — patrí pred ďalšie nové funkcie.)* Poradie určí Michal; nič z toho nie je blokujúce pre prácu, ale všetko je pomenované, aby sa to nestratilo.

**A · Optimistický zámok nastavení (dlh z #227, kolo 4 — Codex, priznané v PR threadoch):**
- **Zastaraný pin prežije návrat do sekcie.** Uvoľnenie nevyužitého pinu je LEN v `ssApplyState`, takže cestu cez `studioGoSection` (prekreslenie BEZ nového pushu) nepokrýva: fokus nezmeneného poľa →
  cudzia zmena a push (prekreslenie potlačené, pin ostáva) → odchod zo sekcie a návrat → sekcia ukáže čerstvé hodnoty so starým pinom → uloženie skončí falošným konfliktom a `SS.saved()` editáciu
  zahodí. **Dôsledok: stratená editácia, nie prepísané dáta.** Fix: uvoľniť nevyužitý pin aj pri prekreslení z navigácie, alebo na `blur`.
- **Status potvrdzuje prepočet, ktorý nemusel prebehnúť** (`supplier_settings_dialog.rb`, cesta `handle_save`). Návratová hodnota `refresh_studio` sa ignoruje; keď plný push po zápise zlyhá (výnimka
  pri počítaní payloadu, neúspešné `execute_script`), hláška aj tak tvrdí „Rozpočet je prepočítaný." — a keďže `SS.saved()` už rozpis zahodil, formulár aj čísla môžu ostať viditeľne staré. Zápis do
  súboru pritom prebehol, klame len hláška. Fix: vetviť podľa výsledku refreshu, alebo poslať samostatné echo nastavení.
- **Slabšie dôkazy:** `ssTyping` (neprekresľovať, kým používateľ píše) je overený grepom, nie DOM testom (`document.activeElement` sa v Node stube nedá vyrobiť dôveryhodne); mutácia „presun uvoľnenia pinu ZA prijatie stavu" je sémanticky ekvivalentná, drží ju len tvarový guard na poradie.

**B · Sekcia Šablóny (backlog z review #225):**
- **PNG kanál nemá retry.** `TPL_ASKED` sa pri stratenej odpovedi nemaže (dlaždica ostane navždy na schéme) a formulácia v ARCHITEKTURE naznačuje retry, ktorý neexistuje; `rev` odpovede sa neporovnáva s dlaždicou.
- **Burst pri vstupe do sekcie** — `tpl_preview` ide na každú šablónu naraz (~64 kB × N); pri raste knižnice doplniť lazy gating.
- **`tpl_payload` beží v KAŽDOM plnom pushi** (`TemplateStore.load` + `File.stat` + celý `config` per šablóna), hoci dlaždica potrebuje len typ a rozmery — orezať payload alebo ho podmieniť otvorenou sekciou.
- **`refresh_if_open` už nekontroluje „if open"** (guard je od #225 na klientovi) — meno klame, premenovať.

*(Sekcia „C · Kovanie" tu bola omylom: všetkých šesť položiek — rozdelenie „nastav dáta"/„kresli", kurzor v editore setu, jednotný `abort_open_operation`, odmietnutý reset cez `resync_sets`, čistenie
  `HW_Q`/`HW_CAT` v `MDH.created`, lepkavá MJ `#hn_unit` aj zhody Demosu po návrate do sekcie — opravila **mini dávka ŠT-3a-3 (PR #219, v0.7.61)**. Zoznam pochádzal z NÁVRHU tej dávky, nie z jej
  výsledku. Overené v kóde pri review #228; nič otvorené v ňom nezostalo.)*

**D · Sekcia Pravidlá (NOTE z review #221/#222, nefixnuté vedome):**
- **`edges_map` sa stavia pri každom pushi** aj pri prázdnych ABS overridoch a duplicitne s `control_payload` — lenivo, alebo prevziať od volajúceho.
- **Záznam `disabled` + `quantity`** vypisuje obe hodnoty, hoci `disabled` víťazí.
- **`override_group` neradí** — poradie jantárových riadkov je nestabilné pri vložení/zmazaní skrinky (strop F15 platí).
- **`material_id` v ABS zázname zberu je mŕtve pole** (`bom.rb`) — použiť alebo vyhodiť.
- **Duplicita s Kontrolou pri vypnutom kovaní** (ORANGE nález + jantárový riadok) — VEDOMÁ, formulácie držať oddelené (rozhodnutie vs. správnosť).

**F · UI dlhy po zaniknutom bloku UI 2.0** — otvorené postrehy, ktoré blok UI 2.0 nevyriešil a ktoré po jeho archivácii (26.8.) ostali bez bloku. Zaradenie je **mechanické, nie prioritizačné**
  (poradie určí Michal): **D-27** rýchle zobraziť/skryť tagy z panela · **D-51** štandard veľkostí okien a tlačidiel. Plné znenia sú v [DOGFOODING.md](DOGFOODING.md), skupina **„UI dlhy — k bloku 1b"**;
  do tej istej skupiny patrí aj **výklop ako samostatný typ čela** (bez D-čísla). Otvorené **D-106** / **D-107** sem pôvodne patrili tiež, dnes žijú vo svojich skupinách podľa zaradenia:
  D-106 v skupine V1 DOTIAHNUTIE (blok 4), D-107 v skupine Po V1 — zásobník.

**E · Post-hoc Codex sweep #186–#226.** Rozsah je JEDNO číslo naprieč STAV, PLAN aj KRONIKOU a znamená presne toto: **dávky, ktorých primárnym reviewerom bol slepý subagent, lebo Codex bol 21.–24.8.
  nedostupný**. Od **#227** review robí Codex, takže #227 aj #228 sú mimo sweepu. Keď má Codex kapacitu, prejsť tie PR spätne — nie kvôli nedôvere v subagenta (chytil o. i. spiacu mínu duplicitných
  kódov), ale preto, že je to iný pohľad na dávky, ktoré medzitým tvoria základ celej fázy.

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

- **Z prvého testu v0.8.0 (Michal 24.8.) — do redizajnu katalógu a setov:** **D-109** pomer člena setu „1 ks na N nôh" (príchyt soklovej lišty — dnes len per unit/owner, pomer sa musí dopočítať ručne)
  · **D-110** pridávanie kovaní je neprehľadné (formulár dole pod zoznamom, poradie polí nesedí s dodávateľským listom; *časť „nová položka nie je vidieť" vyriešená v TEST-1, PR #229*) · **D-111** výber
  setu podľa výšky sokla je schovaný v Predvoľbách projektu, hoci ho človek hľadá pri vkladaní skrinky. Plné znenia v [DOGFOODING.md](DOGFOODING.md).
- **Kovanie fáza 3:** výklopy podľa hmotnosti čela (C-05 — generic_type lift + AVENTOS tabuľky, hustoty z M-C ako SNAPSHOT do modelu) · výplne šuflíkov ako vyrábané dielce (V1-05 — Atira dno+chrbát, Quadro/Tandem) · smer otvárania a typ závesu · hmotnostné Blum tabuľky · automatika počtu nôh podľa šírky · „Použiť na podobné".
- **Spotrebiče S1** (V1-02) — katalóg, položky projektu s väzbou na skrinku, kontrola niche semaforom, sekcia v rozpočte.
- **Ceny a dokumenty ponuky** (vedome odložené z dávky E): manuálne 1-klik overenie ceny pre položky BEZ väzby na Demos a viac URL na položke (zvyšok V1-03) · plný generátor cenovej ponuky do DOCX/PDF so šablónou a vizualizáciami · prepínač „na faktúru" (×1,2, kandidát na štvrtý cenový režim) · rodina dokumentov okolo ponuky (ponuka vizualizácií, preberací protokol).
- **Konštrukcia:** per-dielec odsadenia vpredu/vzadu pre strop/dno/boky (V1-01, chladničkový komín) · typy čiel lakované / frézované / sklo-Al rám (V1-07) · balík V0.4.8 z [archiv/06_PANEL_NASTAVENIA_navrh.md](archiv/06_PANEL_NASTAVENIA_navrh.md) — rohové spoje dna a stropu per strana, chrbát s poldrážkou, „bez dielca" varianty s validáciou, per-dielec hrúbky a odsadenia.
- **Vkladanie na klik** (V1-04 fáza 1) — skrinka visí na kurzore, klik umiestni.
- **D-10 · Presúvanie a úprava čiel priamo v náhľade** — ako drag priečok.
- **V1.0 zostavy:** spájanie a zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, snaper logika) · soklová lišta v celku pre segment · obklady a krycie prvky segmentu vrátane pilastra
  (priznaný vs. skrytý) · pracovné a horné krycie dosky na označený segment · migrácia a oprava starých modelov · test na kompletnej reálnej zákazke. *(Sem patrí aj to, čo V0.4.7 vedome neobsahovalo:
  attachment/segmenty, automatické krycie dosky, PD cez segment.)*

### 5 · RENDER M-R

**Cieľ:** materiál vyzerá v modeli ako v skutočnosti — Luciin nástroj na vizualizácie.

- **D-28 · Textúry materiálov = M-R knižnica vzhľadov** (D-28 je do M-R zlúčená, samostatne sa nerieši): `texture_path` + render vlastnosti PBR + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 = orientácia textúry podľa smeru dekoru dielca. Zdroj JPG knižnica na firemnom Disku; väzba na D-48.
  *(**D-87** — overlay čiar v smere dekoru — je **HOTOVÝ** v bloku KRESBA (K2, PR #188, v0.7.26); tu ostáva len **orientácia textúry** podľa smeru dekoru ako fáza 2 D-28. Overlay je kontrola, textúra je render — dve rôzne veci.)*
- **Nástroj „pixla"** (V1-06) — ikonka na dlaždici materiálu, klik prefarbuje dielce cez `part_override` cestu (1 klik = 1 undo).

### 6 · INFRA (priebežne, podľa potreby)

**Cieľ:** aby plugin a knižnice fungovali na dvoch pracoviskách (Michal + Lucia).

- **D-48 · Zdieľaná knižnica pre 2 PC** — katalóg materiálov, šablóny a pravidlá kovania z jedného zdroja (firemný Google Disk) namiesto lokálneho `%APPDATA%`.
- **D-52 · Tlačidlo „Aktualizovať" (auto-update pluginu)** — jednoklikový update, distribučný kanál spolu s D-48.
- **D-20 · Quick actions — bezpečný move plugin** — zlúčiť noxun_mower + Snaper do jedného toolbaru; kopírovanie musí prejsť štandardným dedup tickom (dnes vzniká kópia bez NOXUN identity).

## Po V1 — zásobník (nezaradené, nestratiť)

- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** — automatické dočasné skrytie zvyšku modelu pred `view.write_image`. *Michal 20.8.: nízka priorita / vysoká náročnosť (skrývanie geometrie = zápis do modelu, undo kroky, observery). Medzitým stačí ručné „Odfotiť" v okne Šablóny — skrinku si naaranžuje a izoluje používateľ sám.*
- Rohová a vysoká/potravinová skrinka ako **nové TYPY builderov** (odvodia sa od dolnej/hornej).
- Zóny priamo vo viewporte (variant B vízie) — nadstavba 2D náhľadu.
- **Interact pre čelá** — dráhy otvárania, klik = otvorenie, merač kolízií pri otvorení (dáta máme: origin čiel na hrane pántu; typ pántu určuje dráhu).
- Náhľad povýšiť na „otvárací náhľad" panela so zobrazovaním zvolených elementov.
- **Injecting dát do knižníc v dávkach** (kódy, materiály, kovania, spotrebiče, vybavenie) — architektúru pripraviť skôr.
- Zásuvkové bloky (dočasne DC Atira most) · vnútorné vybavenie (koše, tyče) · doplnky (LED, gola) · dĺžkové materiály naplno · odpojený režim UI · výkresy a etikety · CNC.
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
