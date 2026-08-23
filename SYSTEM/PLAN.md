# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (uzáver etapy = minor bump).
> **Údržba:** pri uzávere dávky sa jej riadok z bloku odstráni, odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a prepíše sa [STAV.md](STAV.md). Plné znenie otvorených postrehov žije v [DOGFOODING.md](DOGFOODING.md) **v skupinách podľa týchto blokov** — tu je len číslo, názov a jedna veta.

## Bloky

### 1 · UI 2.0 — štúdio okno a výbery

**Cieľ:** satelitné okná → jedno štúdio okno s toolbarom a bočnou navigáciou; výber materiálu/ABS na jeden klik namiesto scrollovania. **Koncept Inspectora je uzavretý** (Michal, 18.8.2026) — záväzný slovný kontrakt je [zdroje/ui20/UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md) (sekcie „SCHVÁLENÉ ROZHODNUTIA" a „FINÁLNY KONCEPT INSPECTOR C") a vizuálna referencia mockupy vedľa neho: [Inspector C v16](zdroje/ui20/mockup_inspector_c.html) · [štúdio okno](zdroje/ui20/mockup_ui20.html) · [dizajnový lístok](zdroje/ui20/dizajnovy_listok.html); implementácia ide po dávkach nižšie. Podklad: merač používania D-25 (materiály/ABS vyše 400 interakcií, taby 287×, satelitné okná 234×) a [UI_VIZIA.md](UI_VIZIA.md); cieľový obraz v [V1_VIZIA.md](V1_VIZIA.md) §6.

**~~UI-B · Inspector kostra~~ — BLOK KOMPLET** (UI-B1 #168 · UI-B2 #169 · UI-B3 #170, v0.7.7): kostra (rail + 4 sektory), náhľad ako kontextová projekcia a obsah Korpusu vrátane kolieska. **Bugfix po teste (18.8., v0.7.8):** Základné a Materiály patria kontextu Korpus, ostatné kontexty majú kontextový riadok — nedotiahnutá mapa viditeľnosti z UI-B1. **Dotiahnutie voči kontraktu (18.8., v0.7.9):** logo v hlavičke aj v „O plugine" je zrolovaná značka z originálnych kriviek (24 px) a lišty sektorov nesú meta súhrny (projekcia · rozmery · materiály · otvorená skupina). Plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).

**~~UI-C · Kontexty~~ — BLOK KOMPLET** (UI-C1 #174 · #175 · #176 · UI-C2 #177 · UI-C3 #178 · UI-C4 #179, **v0.7.16**): Inspector má hotové **všetky kontexty**. **C1 Vkladanie** — typové tlačidlá (Dolná · Horná · Doska), dlaždice šablón s „naposledy použitými" a dvojklikom (N16/N17), zámky D-39 pre dosku, doskové šablóny a orientácia dosky (naležato · nastojato · na stenu); reálne PNG náhľady dlaždíc ostávajú vedome v **UI-D2**. **C2 Zóny** — štruktúra navrchu so stromovými spojnicami a najviac 3 úrovňami (N22), delenie na štyri dlaždice, presné delenie prvej zóny v mm aj zlomkom (N21), magnet pri ťahaní priečky s vypnutím cez Alt (N20, **D-09 uzavreté**), police ako pilulky 0–6, rezervovaný slot „Vnútro". **C3 Čelá** — ikona typu (N27), chip **AUTO** namiesto zámku (zamknuté ⇔ vypísané), výškové rady (N25), naviazané kovanie pod riadkom, **D-84**, **D-96 Úchytky**, **N26** medzery jantárovo a **D-89a** hover hrany v MODELI (**D-89 uzavreté**). **C4 Kovanie** — položky ako **boxy podľa vlastníka** (Skrinka · každé čelo · Vnútro skrinky), klik na hlavičku boxu aj na značku v náhľade **označí vlastníka v modeli**, hover box ↔ značka, sekcia rozdelená na Položky · Sety · Pravidlá. Vedomé odchýlky od mockupu (Zóny: aktivita ovládačov a zámok poľa · Čelá: neaktívny výklop, chýbajúca hrana osadenia · Kovanie: panel po označení nepusha, „Vnútro skrinky" namiesto boxu na policu) sú zapísané v [zdroje/ui20/UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md); plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).

**~~UI-D · Dotiahnutie~~ — BLOK KOMPLET** (UI-D1 #180 · UI-D2 #181 · UI-D3 #182, **v0.7.20**) — **a tým je INSPECTOR REWORK HOTOVÝ** (UI-A · UI-B · UI-C · UI-D). **D1 Dielec** — Základné hore ako dopočítané údaje, hranové ikony s rotáciou podľa 2D náhľadu, „Označiť v modeli" (bez zápisu a bez kroku Späť) a „Použiť na podobné…" (prenos **olepu hrán** na dielce s rovnakou rolou a materiálom, rozsah *táto skrinka / celý projekt* so živým počtom, celý zápis **jeden krok Späť**). **D2 Náhľady šablón** — pri uložení šablóny sa odfotí **skutočný pohľad na skrinku** a dlaždica ním nahradí schematickú kresbu; kamera sa vždy vráti presne tam, kde bola, a nevznikne ani jeden krok Späť; staršie šablóny aj neúspešné fotenie končia pri schéme (obrázky žijú ako súbory vedľa knižnice, schéma `templates.json` sa nemenila). **D3 Klikateľnosť a uzávery** — ⚠ chip otvára **warnpanel ako overlay** (nič neposunie), každý nález má **oko** na označenie dotknutého dielca v modeli a dole deep-link **„Otvoriť v Štúdiu → Kontrola"**; „Materiál" v info stĺpci otvára **Kusovník**; v karte dielca je „Smer dekoru" preklikom na materiál; `UI_DIZAJN.md` doplnený o všetko, čo bloky UI-A…D zaviedli. Vedomé odchýlky (smer dekoru ostal informáciou; rotácia hranovej ikony podľa náhľadu, nie podľa pevnej mapy; kontextová fotografia namiesto izolovaného renderu) sú v [zdroje/ui20/UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md); plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).

**Rozhodnuté 20.8. nad HOTOVÝM panelom:** **D-26** (režimy *Jednoduchý / Rozšírený* vs. akordeóny „menej časté") je **ZAVRETÉ bez implementácie** — koncept zbalil obsah do exkluzívnych skupín sektorov a „Menej časté" v ňom neexistuje, prepínač by pridal druhú os skrývania nad už fungujúcu (plný text v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md)) · **per-dielec smer dekoru** dostal číslo **D-108** a vlastný blok **KRESBA** nižšie (uzavretý 21.8.).

**Po smoke teste 20.8. (Michal, hotový Inspector)** — opravný pack **SMOKE PACK 1** je hotový (PR #183, v0.7.21): rozbité riadky zoznamu čiel · prekrytý text v boxe kovania · podperky políc súhrnne s rozklikom · ručné „Odfotiť" náhľadu k existujúcej šablóne. Otvorené zvyšky z toho istého testu:
- **D-106 · Predbežná cena korpusu v informačnom stĺpci Základných** — orientačný náklad skrinky („≈ X €" s tooltipom rozpadu materiál/ABS/kovanie); odvodené čítanie, žiadny nový riadok. *Michal 20.8.: zapísať na neskôr — rieši sa s okruhom rozpočtu vo fáze ŠTÚDIO.*
- ~~**Nové zobrazenie výsuvov v mini náhľade**~~ — **HOTOVÉ** (PR #184, v0.7.22): výsuv sa v projekcii Kovanie kreslí ako **koľajnica „L" pri oboch bokoch + telo šuflíka**, výšky tiel rastú s čelami. Schválené Michalom 20.8. nad mini náhľadom.

**~~BLOK KRESBA — smer dekoru~~ — BLOK KOMPLET** (K1 #185 · fixy #186 · #187 · K2 #188, **v0.7.26**) — dôvodom bol reálny incident z 19.8.: v objednávke naostro mala tenká horná blenda pozdĺžnu kresbu a vysoké úzke dvere pod ňou priečnu, a plugin to nevedel ani nastaviť, ani ukázať. **K1 · D-108** dala smer ako **vstup** — segment *Podľa materiálu / Pozdĺžna / Priečna* v karte dielca; override žije v `part_overrides['grain_direction']` (enum `length`/`width`), efektívny smer počíta `CabinetBuilder.effective_grain` a **materializuje sa raz do snapshotu dielca**, rotácia sa nepridala nikde (dĺžku/šírku a dvojice hrán vymieňa naďalej len VEPO a `fits_on_sheet`). **K2 · D-87** dala **kontrolu toho vstupu** — prepínač „Smer kresby" v okne Výroba → Kontrola nakreslí čiary v smere kresby na každý výrobný dielec (overlay nad modelom, žiadny krok Späť, po vypnutí nič neostane), kreslí **výhradne zo snapshotu** a materiál bez kresby preskočí. Z review K1 vyšla najavo výrobná pasca na odpojenom dielci — opravená (#186) a dotiahnutá (#187). **Po smoke teste K2 pribudol druhý vstupný bod prepínača — „Kontrola kresby" v raile Inspectora** (#189, v0.7.27): zdieľaná `Engine.toggle_grain_check` + broadcast obom oknám, teda **jeden zdroj stavu, dva vstupné body** (presné zrkadlo ABS kontroly z UI-B1); overlay logika sa nemenila. *Orientácia TEXTÚR podľa smeru dekoru ostáva v M-R — to je render, nie kontrola.* Plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).

**~~ABS kontrola v raile — 3-stavové nastavenie~~ — HOTOVÉ** (PR #190, **v0.7.28**, 21.8.) — drobná dávka z debaty o ikone ABS kontroly. Michal si vybral **variant B: malý plný trojuholník v pravom dolnom rohu** ikony (flyout vzor nástrojov SketchUp/Photoshop); ikona `shell` ostáva a **toggle sa nemení** — klik na roh otvorí **3-stavové nastavenie kontroly hrán** (chýba podľa pravidla / mimo pravidla / olepené + „len vybrané" so živými počtami), teda presne to, čo má okno Výroba pod chevronom. Tým je **splnený pôvodný kontrakt UI 2.0 „ABS kontrola = shell so stavom a šípkou na 3-stavové nastavenie"** a vedomá odchýlka z UI-B1 zaniká. Kľúčové rozhodnutie: nastavenie sa **nekopírovalo** — vyčlenilo sa do zdieľaného komponentu (`ui/js/edge_menu.js` + štýly v zdieľanom `panel.css`) a **obe okná zapisujú jednou serverovou cestou** (`Engine.set_edge_check_option` → broadcast), takže stav aj počty sú vždy rovnaké a dve kópie okna nikdy nestoja na obrazovke naraz. Nový vzor „flyout roh" je zapísaný v [../docs/UI_DIZAJN.md](../docs/UI_DIZAJN.md) §5.11.

**Fáza ŠTÚDIO — KONCEPT SCHVÁLENÝ 22.8.2026** *(sektorová debata 21.–22.8., 4 kolá nad
klikateľným mockupom, návrhy Š1–Š19 — všetko schválené; záväzný slovný kontrakt je sekcia
**ŠTÚDIO KONCEPT** v [zdroje/ui20/UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md), vizuálna
referencia [zdroje/ui20/mockup_studio.html](zdroje/ui20/mockup_studio.html)).* Do konceptu sú
zapracované a ním uzavreté: **D-50** (OCL vzory — skupiny kusovníka, hover akcie, voliteľné
stĺpce, klik-select), **D-69** (jednotný editor materiálov: 3 vstupy → 1 formulár) a **D-15**
(pridávačky ako zdieľaný modal) + klik na materiál → zvýraznenie použitia; D-čísla sa vyriešia
implementáciou príslušných dávok. Vedomé odklady: Nákup kovania a Katalóg kovania **presun 1:1
bez redizajnu** (redizajn s blokom KOVANIE) · D-106 s okruhom rozpočtu · D-95 s blokom
KONTROLA+VÝROBA · DOCX/PDF generátor ponuky po V1.

Implementačné dávky (poradie presunov schválil Michal; každá dávka = plugin plne použiteľný,
satelit zaniká až po plnej náhrade):
- ~~**ŠT-1a** skelet Štúdia + sekcia **Kusovník**~~ — **HOTOVÉ** (PR #192 + #193, v0.7.30, 22.8.; audit aj review „slepým subagentom" — Codex mimo; serverový názov projektu, premostenia v navigácii; vedomé odchýlky: XLSX/CSV disabled, bez stĺpca Poznámka, ABS pohľad bez cien — plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md)).
- ~~**ŠT-1b** sekcia **Kontrola**~~ — **HOTOVÉ** (PR #195, v0.7.32, 22.8.; jedno číslo cez zdieľaný control_payload vrátane rozpočtu, tretia inštancia edge_menu, zmena lifecycle overlayov — plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md)).
- ~~**ŠT-1c** Rozpočet + Cenová ponuka + Nákup — zánik okna Výroba~~ — **HOTOVÉ** (PR #197–#200, v0.7.40, 22.8.; 4 PR podľa auditu — bump:false generačný kontrakt, D-15 modal kostra `nx_modal.js`, nová in-SU sada rozpočtu; plný text v [archiv/KRONIKA.md](archiv/KRONIKA.md)).
- **ŠT-2** (M) sekcia **Materiály** + **D-69 editor** — okno Materiály zaniká. *Rez auditom na 4 PR:* ~~2a sekcia (kanál, obsah 1:1, #205)~~ · ~~2b Demos+UNI+zánik okna (#206, v0.7.48)~~ · ~~**2c D-69 editor** — 2c-1 rozšírenie nx_modal (#208) · 2c-2a atomická `Materials.save_decor` + „Upraviť…" (#212) · 2c-2b „Pridať ručne" (mode `create`) + zánik batchového zakladania (#213, v0.7.55)~~ — **HOTOVÉ, D-69 KOMPLET**; zostáva **2d** „Kde sa používa" + deep-link z karty dielca (in-SU povinné; smie sa odložiť za ŠT-3).
- **ŠT-3** (M) **Kovanie · Pravidlá · Šablóny** (Š16–Š18) — tri okná zanikajú.
- **ŠT-4** (S) **Nastavenia** (Š19) + upratanie (`open_tab` → `studioOpen` všade, docs, zánik zvyšných satelitov).

*(Z vízie V1 sú v koncepte zapracované: header ako prístup ku všetkému UX-02 → UI-B1 · karta Zóna so smerovými ikonami UX-06 → UI-C2 · polia šírkou podľa obsahu UX-03 → UI-B1/UI-C.)*

*(Seed katalógu ako krok je ZRUŠENÝ (Michal 10.8.) — katalóg rastie sám prácou na zákazkách; skutočný problém „nájsť materiál aj v malom zozname" rieši D-85 — **hotová 18.8. (PR #167)**. Podklad kódov a cien ostáva v [zdroje/SEED_KATALOG_2026-07.md](zdroje/SEED_KATALOG_2026-07.md).)*

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

- **Kovanie fáza 3:** výklopy podľa hmotnosti čela (C-05 — generic_type lift + AVENTOS tabuľky, hustoty z M-C ako SNAPSHOT do modelu) · výplne šuflíkov ako vyrábané dielce (V1-05 — Atira dno+chrbát, Quadro/Tandem) · smer otvárania a typ závesu · hmotnostné Blum tabuľky · automatika počtu nôh podľa šírky · „Použiť na podobné".
- **Spotrebiče S1** (V1-02) — katalóg, položky projektu s väzbou na skrinku, kontrola niche semaforom, sekcia v rozpočte.
- **Ceny a dokumenty ponuky** (vedome odložené z dávky E): manuálne 1-klik overenie ceny pre položky BEZ väzby na Demos a viac URL na položke (zvyšok V1-03) · plný generátor cenovej ponuky do DOCX/PDF so šablónou a vizualizáciami · prepínač „na faktúru" (×1,2, kandidát na štvrtý cenový režim) · rodina dokumentov okolo ponuky (ponuka vizualizácií, preberací protokol).
- **Konštrukcia:** per-dielec odsadenia vpredu/vzadu pre strop/dno/boky (V1-01, chladničkový komín) · typy čiel lakované / frézované / sklo-Al rám (V1-07) · balík V0.4.8 z [archiv/06_PANEL_NASTAVENIA_navrh.md](archiv/06_PANEL_NASTAVENIA_navrh.md) — rohové spoje dna a stropu per strana, chrbát s poldrážkou, „bez dielca" varianty s validáciou, per-dielec hrúbky a odsadenia.
- **Vkladanie na klik** (V1-04 fáza 1) — skrinka visí na kurzore, klik umiestni.
- **D-10 · Presúvanie a úprava čiel priamo v náhľade** — ako drag priečok.
- **V1.0 zostavy:** spájanie a zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, snaper logika) · soklová lišta v celku pre segment · obklady a krycie prvky segmentu vrátane pilastra (priznaný vs. skrytý) · pracovné a horné krycie dosky na označený segment · migrácia a oprava starých modelov · test na kompletnej reálnej zákazke. *(Sem patrí aj to, čo V0.4.7 vedome neobsahovalo: attachment/segmenty, automatické krycie dosky, PD cez segment.)*

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

**Doplnok k triedeniu (dohoda 20.8.): z pluginu sa objednávajú REÁLNE ZÁKAZKY.** Nálezy z reálnej výroby (chybný rozmer, zlá orientácia, nesprávny olep, nekompletný nákup) a **chyby v cenách a rozpočtoch** majú **najvyššiu prioritu triedenia — nad plánované bloky**. Predbiehajú bežiacu etapu aj naplánované dávky: keď plugin pošle do výroby alebo do objednávky zlé číslo, stojí to peniaze a dôveru, a žiadna rozpracovaná dávka to nevyváži. Zaraďujú sa hneď, s plným kontextom incidentu (čo bolo objednané, čo prišlo, kde to plugin ukázal alebo neukázal) — vzor: **D-108** (kresba blendy vs. dverí, incident 19.8.).

## Trvalé UI/UX pravidlo (Michal 20.7. — platí pre všetku ďalšiu prácu na paneli)

**VERTIKÁLNY priestor panela je vzácny.** Pred umiestnením každého nového tlačidla/poľa/funkcie sa POVINNE zamyslieť, či sa nedá umiestniť inak a rozumnejšie (do existujúceho radu, do rohu náhľadu, ako ikona, kontextovo) — rast do výšky len v krajných prípadoch. Inak panel skončí ako scrollovanie cez 20 tlačidiel a 30 sekcií.

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.
