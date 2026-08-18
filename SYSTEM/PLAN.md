# PLAN — čo sa ide robiť (bloky prác)

> Roadmapa **bez histórie**: bloky v poradí, každý s cieľom a zaradenými položkami. Blok NEMÁ číslo verzie vopred — **dostane ho pri štarte** (uzáver etapy = minor bump).
> **Údržba:** pri uzávere dávky sa jej riadok z bloku odstráni, odsek o nej ide do [archiv/KRONIKA.md](archiv/KRONIKA.md) a prepíše sa [STAV.md](STAV.md). Plné znenie otvorených postrehov žije v [DOGFOODING.md](DOGFOODING.md) **v skupinách podľa týchto blokov** — tu je len číslo, názov a jedna veta.

## Bloky

### 1 · UI 2.0 — štúdio okno a výbery

**Cieľ:** satelitné okná → jedno štúdio okno s toolbarom a bočnou navigáciou; výber materiálu/ABS na jeden klik namiesto scrollovania. **Koncept Inspectora je uzavretý** (Michal, 18.8.2026) — záväzný slovný kontrakt je [zdroje/ui20/UI20_KONTRAKT.md](zdroje/ui20/UI20_KONTRAKT.md) (sekcie „SCHVÁLENÉ ROZHODNUTIA" a „FINÁLNY KONCEPT INSPECTOR C") a vizuálna referencia mockupy vedľa neho: [Inspector C v16](zdroje/ui20/mockup_inspector_c.html) · [štúdio okno](zdroje/ui20/mockup_ui20.html) · [dizajnový lístok](zdroje/ui20/dizajnovy_listok.html); implementácia ide po dávkach nižšie. Podklad: merač používania D-25 (materiály/ABS vyše 400 interakcií, taby 287×, satelitné okná 234×) a [UI_VIZIA.md](UI_VIZIA.md); cieľový obraz v [V1_VIZIA.md](V1_VIZIA.md) §6.

**~~UI-B · Inspector kostra~~ — BLOK KOMPLET** (UI-B1 #168 · UI-B2 #169 · UI-B3 #170, v0.7.7): kostra (rail + 4 sektory), náhľad ako kontextová projekcia a obsah Korpusu vrátane kolieska. **Bugfix po teste (18.8., v0.7.8):** Základné a Materiály patria kontextu Korpus, ostatné kontexty majú kontextový riadok — nedotiahnutá mapa viditeľnosti z UI-B1. **Dotiahnutie voči kontraktu (18.8., v0.7.9):** logo v hlavičke aj v „O plugine" je zrolovaná značka z originálnych kriviek (24 px) a lišty sektorov nesú meta súhrny (projekcia · rozmery · materiály · otvorená skupina). Plné texty v [archiv/KRONIKA.md](archiv/KRONIKA.md).

**UI-C · Kontexty**
- **UI-C1 · Vkladanie** — typové tlačidlá, šablóny (nedávne prvé, dvojklik vloží, reálne náhľady), zámky D-39, doskové šablóny.
- **UI-C2 · Zóny** — strom so spojnicami, dlaždice delenia, presné delenie v mm, snap 1/4·1/2·3/4 (D-09), police ako pills, slot „Vnútro".
- **UI-C3 · Čelá (D-84, D-89a, D-96)** — riadky s ikonou typu, AUTO chip, rady výšok, naviazané kovanie pod riadkom, **reč stolára „+ pridaj čelo / + pridaj dvere" (D-84)**, **sekcia Úchytky (D-96)**, **hover hrany zvýrazní hranu v MODELI (D-89 otvorená časť)**.
- **UI-C4 · Kovanie** — položky v boxoch podľa vlastníka (skrinka / každé čelo) + značky v náhľade.

**UI-D · Dotiahnutie**
- **UI-D1 · Dielec** — Základné hore, hranové ikony, „Označiť v modeli", „Použiť na podobné".
- **UI-D2 · Náhľady šablón** — PNG pri uložení + schéma ako fallback.
- **UI-D3 · Klikateľnosť a uzávery (aj D-26)** — warnpanel deep-linky, klikateľné informačné údaje, **rozhodnutie D-26 Jednoduchý/Rozšírený** (v koncepte „Menej časté" neexistuje — potvrdí sa nad hotovým panelom) + doťaženie `UI_DIZAJN.md`.

**Fáza ŠTÚDIO** *(záver bloku — vlastné dávky po sektorovej debate nad [mockupom štúdia](zdroje/ui20/mockup_ui20.html))*
- **D-50 · OCL inšpirácia UI/UX** — prebrať detaily z OCL flow (vzory áno, GPL kód nie); ťažisko je práve v štúdio okne (kusovník, kontrola, nákup, rozpočet).
- **D-69 · Jednotný editor materiálov** — jedno modálne okno pre pridanie z Demosu / ručné pridanie / editáciu, rovnaké polia bez ohľadu na vstupný bod.
- **D-15 · „Pridávačky" ako modal** — všetky akcie „pridať niečo" (šablóna, materiál, položka) na jeden UX vzor.
- **Klik na materiál/ABS → zvýraznenie miest použitia v projekte** — z katalógu vidieť, kde presne dekor v zákazke je.
- Presun satelitných okien do štúdia po jednom (Materiály · Výroba · Kovanie · Pravidlá · Šablóny · Nastavenia) — satelity zanikajú postupne, plugin je použiteľný po každej dávke.

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
- **D-09 · Snap body pri presúvaní priečok** — 1/4, 1/2, 3/4 v zónovom náhľade.
- **D-10 · Presúvanie a úprava čiel priamo v náhľade** — ako drag priečok.
- **V1.0 zostavy:** spájanie a zarovnávanie korpusov (čelné/zadné hrany, pripájacie body, snaper logika) · soklová lišta v celku pre segment · obklady a krycie prvky segmentu vrátane pilastra (priznaný vs. skrytý) · pracovné a horné krycie dosky na označený segment · migrácia a oprava starých modelov · test na kompletnej reálnej zákazke. *(Sem patrí aj to, čo V0.4.7 vedome neobsahovalo: attachment/segmenty, automatické krycie dosky, PD cez segment.)*

### 5 · RENDER M-R

**Cieľ:** materiál vyzerá v modeli ako v skutočnosti — Luciin nástroj na vizualizácie.

- **D-28 · Textúry materiálov = M-R knižnica vzhľadov** (D-28 je do M-R zlúčená, samostatne sa nerieši): `texture_path` + render vlastnosti PBR + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 = orientácia textúry podľa smeru dekoru dielca. Zdroj JPG knižnica na firemnom Disku; väzba na D-48.
- **D-87 · Vizuálne zobrazenie SMERU štruktúry v modeli** — overlay čiar v smere dekoru na dielcoch (vzor ghost zón) ako rýchla kontrola orientácie celej zákazky; logicky sa rieši s textúrami a nárezovým plánom.
- **Nástroj „pixla"** (V1-06) — ikonka na dlaždici materiálu, klik prefarbuje dielce cez `part_override` cestu (1 klik = 1 undo).

### 6 · INFRA (priebežne, podľa potreby)

**Cieľ:** aby plugin a knižnice fungovali na dvoch pracoviskách (Michal + Lucia).

- **D-48 · Zdieľaná knižnica pre 2 PC** — katalóg materiálov, šablóny a pravidlá kovania z jedného zdroja (firemný Google Disk) namiesto lokálneho `%APPDATA%`.
- **D-52 · Tlačidlo „Aktualizovať" (auto-update pluginu)** — jednoklikový update, distribučný kanál spolu s D-48.
- **D-20 · Quick actions — bezpečný move plugin** — zlúčiť noxun_mower + Snaper do jedného toolbaru; kopírovanie musí prejsť štandardným dedup tickom (dnes vzniká kópia bez NOXUN identity).

## Po V1 — zásobník (nezaradené, nestratiť)

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

## Trvalé UI/UX pravidlo (Michal 20.7. — platí pre všetku ďalšiu prácu na paneli)

**VERTIKÁLNY priestor panela je vzácny.** Pred umiestnením každého nového tlačidla/poľa/funkcie sa POVINNE zamyslieť, či sa nedá umiestniť inak a rozumnejšie (do existujúceho radu, do rohu náhľadu, ako ikona, kontextovo) — rast do výšky len v krajných prípadoch. Inak panel skončí ako scrollovanie cez 20 tlačidiel a 30 sekcií.

## Hranica: TYP vs. ŠABLÓNA vs. PARAMETER (rozhodnuté 15.7.2026)

Tri úrovne — odpoveď na otázku „kedy nový typ korpusu":
1. **TYP (builder)** = iná **topológia**: iná množina dielcov a vzťahov, iné zóny, parametre ktoré inde nedávajú zmysel. Vlastný generovací kód. → dolná, horná; neskôr **rohová** (L-pôdorys, 2 čelné roviny — určite typ), vysoká/potravinová veža.
2. **ŠABLÓNA (template, čisté dáta)** = pomenovaná sada nastavení TYPU — žiadny nový kód. → **drezová** (= dolná + výstuhy na výšku), **varná** (= dolná + výstuhy −20 mm), klasik, zásuvková… Používateľ si tvorí vlastné (Blum „My Library" princíp).
3. **PARAMETER** = individuálna hodnota konkrétnej skrinky.
Pravidlo: kým sa dá vec vyjadriť hodnotou/variantom existujúceho dielca → parameter/šablóna. Nový typ až keď sa mení topológia.
