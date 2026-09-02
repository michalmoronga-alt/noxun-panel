# Dogfooding zápisník — otvorené postrehy

> **Čo to je:** plné znenie **otvorených** postrehov z reálnej práce — D-čísla aj vedomé odklady bez čísla. Skupiny a ich poradie = bloky prác v [PLAN.md](PLAN.md); PLAN drží pri každej položke len jednu vetu, plný text je tu. *(PLAN nesie navyše aj prenesené záväzky z vízie V1, ktoré vlastný postreh nemajú — tie sa sem nekopírujú.)*
> **Údržba:** nový postreh = nové **D-číslo** do skupiny podľa bloku (číslovanie je trvalé, nerecykluje sa); vyriešený postreh **z tohto súboru zmizne** — plný text ide do sekcie
> „Vyriešené (plné texty)" v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md) (príčina, riešenie, PR) a **jeden riadok navrch INDEXU v tom istom súbore**.
> Tu ostávajú **len otvorené** postrehy (od 26.8.2026, dávka Docs cleanup B — stráži guard). Zmena zaradenia = presun medzi skupinami tu aj v PLAN.
> **Postrehy Michala sa píšu HNEĎ**, hocikedy a na hociktorú tému — zaradenie robí agent (plné pravidlo: [PLAN.md](PLAN.md), sekcia „Pravidlo pre postrehy").
> **Kde je zvyšok:** história zápisníka (priebežné stavy, 2A migračná mapa, hardening a sedenia V0.5, priebeh seedu, zodpovedané otázky) → [archiv/DOGFOODING_historia.md](archiv/DOGFOODING_historia.md) · odpočet merača D-25 → [zdroje/MERAC_D25_odpocet_2026-08.md](zdroje/MERAC_D25_odpocet_2026-08.md) · história dávok → [archiv/KRONIKA.md](archiv/KRONIKA.md).

## UI dlhy — k bloku 1b (STABILIZAČNÁ REVÍZIA)

*(Blok **1 · UI 2.0** je od v0.8.0 hotový a jeho plný text žije v
[archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md). Postrehy nižšie sa v ňom
nevyriešili, takže od 26.8.2026 visia na bloku **1b · STABILIZAČNÁ REVÍZIA**, odrážka **F**
v [PLAN.md](PLAN.md) — dnes už len **D-51**; **D-27** je vyriešené dávkou F/D-27 (v0.8.13)
a položka „výklop ako samostatný typ čela" dávkami KOV-A1 + KOV-A2a (v0.9.16).)*

- **D-51 · Štandard veľkostí okien a tlačidiel** (Michal 31.7. večer) — zjednotiť šírky, rozmery a rozmiestnenie naprieč oknami (panel, Materiály, Výroba, Pravidlá, Šablóny) — dohodnúť konkrétne
  hodnoty do UI_DIZAJN.md **pred prvým testovaním Lucie („skúška ohňom")**. *Stav: ČIASTOČNE — UI-B1 (PR #168) zaviedol mechaniku aj tabuľku rozmerov okien v UI_DIZAJN.md a vyplnil riadok Inspectora
  (obsah 470 × 810). Riadky satelitných okien sa doplnia, keď ich prevezme Štúdio.*

## KOVANIE — vlastný blok (za GHOST VKLADANÍM; poradie rozhodol Michal 26.8.)

*(Blok v [PLAN.md](PLAN.md) sa 26.8. vyčlenil z bloku 4; predpoklad štartu je USER-debata o setoch.)*

- **D-109 · Pomer člena setu „1 ks na N nôh"** (Michal 24.8., prvý test v0.8.0) — set kovania vie dnes počítať člena len **per unit** (na kus) alebo **per owner** (na skrinku). Chýba pomer typu „**1
  príchyt sokla na 4 nohy**": pri príchytoch soklovej lišty sa počet neviaže na skrinku ani na jednotlivú nohu, ale na ich **počet**. Dnes sa to musí dopočítať ručne — a práve to má set robiť za
  človeka. *(Nefixované v TEST-1: mení dátový model setu.)*
- **D-110 · Pridávanie kovaní je neprehľadné** (Michal 24.8., prvý test v0.8.0) — formulár novej položky je **dole pod zoznamom**, poradie polí nezodpovedá tomu, ako človek údaje prepisuje z
  dodávateľského listu, a po uložení sa položka stratí v zozname. *(Časť — aby nová položka bola hneď vidieť a orezanie zoznamu sa priznalo — vyriešená v TEST-1, PR #229; REDIZAJN formulára a zoradenia
  patrí sem.)*
- **D-111 · Výber setu podľa výšky sokla je schovaný** (Michal 24.8., prvý test v0.8.0) — predvoľba, ktorý set kovania sa použije podľa výšky sokla, žije v **Predvoľbách projektu** v sekcii Kovanie. Je
  to nastavenie, ktoré človek hľadá pri **vkladaní skrinky**, nie v katalógu — dnes ho nájde len ten, kto vie, že tam je. *(UX.)*

## KONTROLA + VÝROBA

- **D-94 · Traceability v celkovom súpise kovania — rozklik položky na miesta použitia** (Michal 9.8., test kovania na reálnej zákazke) — nákupný zoznam v okne Výroba povie „357695 × 12", ale nie
  **kde** tých 12 kusov je. Pri kontrole objednávky (a pri hľadaní, prečo je počet iný, než človek čakal) treba vedieť rozobrať riadok na **skrinky a čelá**, z ktorých vznikol. Dáta už existujú:
  `expand` skladá pri každom riadku pole `sources` (`cabinet_id`, `owner_part_key`, `generic_type`, `rule_id`, `set_id`, počet) — chýba len zobrazenie a klik-select. Návrh: rozklik riadku (vzor
  `<details>` v tabe Rozpočet) so zoznamom „CAB-003 · F2 · zásuvkové čelo — 2 ks" a klikom na výber v modeli (vzor KONTROLA tabu); ľudské názvy dielcov dodá `PartKeys.human_label` z D-92. *Stav:
  OTVORENÉ — návrh na dávku okolo okna Výroba; nízke riziko (čisté čítanie), stredný rozsah UI.*
- **D-95 · Režim krížovej kontroly „diel po diele"** (Michal 9.8.) — pred odoslaním zákazky do výroby chýba **riadený prechod celou zákazkou**: dielec po dielci prejsť rozmery, ABS a kovanie a
  **odškrtávať** skontrolované (so stavom, ktorý prežije zatvorenie okna). Dnes sa kontroluje preklikávaním po jednom v paneli, bez akejkoľvek stopy, čo už bolo overené. Michalov cieľ je konkrétny:
  **KLINIKA ako prvý referenčný projekt vyrobený čisto z pluginu** s jasným, obhájiteľným výstupom. Návrh: nový režim v okne Výroba (vedľa KONTROLY) — zoznam dielcov s checkboxom, klik = výber v modeli,
  filtre „neskontrolované / s upozornením", stav uložený v `NOXUN` dict na modeli (patrí k zákazke, nie k počítaču); semafor ostáva samostatný (automatické nálezy) — toto je **ľudská** kontrola. *Stav:
  OTVORENÉ — väčší celok, návrh + Codex audit; kandidát hneď po dávke kovania. **Základ už stojí: D-104 + D-105** (v0.5.58/v0.5.59) dávajú vizuálnu časť pre olep — tri stavy hrany priamo v modeli, s
  prepínačmi, živými počtami a filtrom podľa označeného. D-95 k tomu doplní **odškrtávanie so stavom uloženým v zákazke**, riadený prechod dielec po dielci a rozšírenie na **rozmery a kovanie**; z
  pôvodného zadania ostávajú otvorené aj **šípky smeru dekoru** a **X-ray cez telesá**.*
- **D-112 · Zmenená ABS (odlišná od dekoru dielca) musí byť viditeľná vo VEPO exporte** (Michal 3.9., dielňa — skladanie zákazky KLINIKA) — dielce, kde ručne zmenil pásku
  (biely dielec, hnedá ABS), pri zadávaní objednávky do VEPO **zabudol označiť** — VEPO to zvyčajne dostáva ako poznámku v objednávkovom formulári. Plugin rozdiel pozná: hrana nesie
  `abs_id` a katalóg vie dekor pásky aj dosky, takže „ABS ≠ dekor dielca" je čisto odvodený údaj. VEPO CSV kontrakt **nemá stĺpec poznámky** (`nazov;dlzka;hrana_pozdlz;sirka;
  hrana_naprieč;hrubka;pocet_ks;material` — pásku VEPO odvodí z materiálu), takže kandidáti: (a) samostatný oddiel vo VEPO LOGu „dielce s odlišnou ABS — prepíš do poznámky objednávky"
  (najmenší zásah, CSV nezmenené), (b) príznak v stĺpci `nazov` („Dno · ABS hnedá" — pozor na `NAME_MAX` a agregáciu riadkov), (c) samostatná skupina/súbor per ABS dekor.
  **Výrobný dopad:** nesprávny olep dodaný z VEPO. *Stav: OTVORENÉ — Michal: „zapísať, prebrať a dotiahneme"; výrobný nález (priorita nad plánovanými blokmi), variant sa rozhodne
  pri debate; patrí k výstupom (VEPO_KONTRAKT + `vepo_export`).*
- **D-113 · Názvy korpusových dielcov nesú aspoň krátky popis korpusu** (Michal 3.9., dielňa — skladanie KLINIKY) — dielce prídu z VEPO označené názvom z CSV („Dno", „Bok lavy"…),
  takže pri skladaní nie je vidno, **ku ktorej skrinke dielec patrí**; želaný tvar napr. „Cab1_Dno", „Cab2_Bok L/P". Dnes VEPO `row_name` spája názvy agregovaného riadku (`names`
  cez `/`, orez `NAME_MAX`) a kusovník riadky zhodných dielcov **zlučuje naprieč skrinkami** (rozmery + materiál + hrany) — pri prefixe skrinky by riadok „Dno" ×3 buď rozpadol,
  alebo niesol „Cab1/Cab2/Cab3", čo je pri zhodných dielcoch vlastne užitočné (ktorýkoľvek sedí). Zdroj krátkeho kódu: `cabinet_id` (CAB-xxx) alebo `CabinetBuilder.display_name`
  (D-100 — výstupy názov skrinky dnes nepoužívajú). *Stav: OTVORENÉ — rozhodnúť tvar (kód vs. názov, oddeľovač, dopad na agregáciu a `NAME_MAX`), potom malá dávka vo výstupoch
  (kusovník + VEPO + štítky); súvisí s D-95 (kontrola diel po diele) a D-94 (pôvod riadku).*
- **EN DANIELI textový export** výrobného zadania (Michal: „po E") — **vedome odložené z dávky E** (6.8., nič z toho neblokuje prácu so zákazkou); supplier-agnostický výstup. *Stav: čaká na prax — vytiahne sa, keď si to reálna zákazka vypýta.*

## STABILITA

- **D-99 · Premenovanie dielca akoby prepísalo názvy všetkých kópií** (Michal 9.8., práca na zákazke KLINIKA) — po premenovaní jedného dielca to na chvíľu vyzeralo, akoby rovnaký názov dostali
  **všetky jeho kópie**; po prepnutí okna (zmena aktívneho modelu a späť) bolo všetko v poriadku, takže **dáta boli celý čas správne** — išlo o zobrazenie. *Stav: OTVORENÉ pozorovanie — zatiaľ
  **nereprodukované**. Sleduje sa; ak sa zopakuje, treba si všimnúť, či boli kópie vytvorené Ctrl+C/V (spoločná definícia, dedup tik) a čo presne ukazoval panel oproti modelu.*
- **Redo po zlúčených transparentných operáciách** — z hardening zoznamu uzáveru V0.5: manuálne overiť redo (Ctrl+Y) po zlúčených transparentných operáciách (pozorovanie zo 17.7.). *Stav: otvorené od 17.7. — Ruby API nemá na Windows spoľahlivú redo akciu, overuje sa rukou.*

## V1 DOTIAHNUTIE

- **Vedome odložené z dávky E — ceny (V1 rozsah)** (6.8., nič z toho neblokuje prácu so zákazkou) — **manuálne 1-klik overenie ceny** pre položky BEZ väzby na Demos a **viac URL na položke**
  (zvyšok V1-03; dnes ich „Prepočítať ceny" preskočí) · prepínač **„na faktúru"** (×1,2 — vzor ADAMČÍK), kandidát na štvrtý cenový režim.
  *(Piaty kus tej istej odkladovej sady — EN DANIELI textový export — je v skupine KONTROLA + VÝROBA; DOCX/PDF generátor a rodina dokumentov sú od 26.8. v skupine Po V1 — zásobník.)*
  *Stav: čaká na prax — vytiahne sa, keď si to reálna zákazka vypýta.*
- **D-106 · Predbežná cena korpusu v informačnom stĺpci Základných** (Michal 20.8., smoke test Inspector reworku) — pri návrhu skrinky chýba **orientačný náklad**: koľko tá skrinka zhruba stojí ešte
  predtým, než sa robí rozpočet celej zákazky. Údaj by stál v **informačnom stĺpci sektora Základné** (vedľa „Materiál m²", teda **žiadny nový riadok navyše**) ako text **„≈ X €"** so značkou odhadu a s
  **tooltipom rozpadu** (materiál: plocha × cena tabule · ABS: bm × cena · kovanie: ks × cena). Dáta existujú — je to tá istá cesta, ktorou počíta tab Rozpočet (`budget`, `sheet_estimate`,
  `hardware_catalog` ceny); ide o **odvodené čítanie**, nič sa nezapisuje. Pravidlá, ktoré platia: chýbajúca cena **nikdy nula**, ale priznaný odhad (D-61); je to **výstup, nie vstup** (text, nie pole).
  *Stav: OTVORENÉ — zapísať na neskôr (Michal 20.8.: „zapísať na neskôr"). Zaradenie: [PLAN.md](PLAN.md) blok 4 (bloky okolo rozpočtu) — dovtedy sa nerobí.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: nápad, D-08 hotové — môže sa rozpracovať.*

## RENDER M-R

- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — *Stav: **ZLÚČENÉ do dávky M-R** (roadmapa „Materiály — dokončenie", 2.8.): texture_path + render vlastnosti + „Uložiť vzhľad do knižnice" + mierka rapportu; fáza 2 orientácia podľa smeru dekoru. Zaradenie: blok 5 M-R v PLAN.md (fotku rieši package M-R FOTO; knižnica vzhľadov/PBR/orientácia = odrážka D-28 bloku 5) (Luciina priorita).*

## INFRA

  *Stav: na návrhovú dávku — od 26.8. SAMOSTATNE (bez väzby na D-48, ktorý je mimo V1); distribučný kanál jednoducho, napr. zdieľaný priečinok.*
- **D-20 · Quick actions — bezpečný move plugin** (Michal 19.7., „pre budúceho Michala a Fable, keď bude základ top 😉") — zlúčiť funkčné pluginy noxun_mower + Snaper do jedného toolbar pluginu (rýchly
  pohyb, kopírovanie, rotácie, prisunutie na doraz). **Známy poznatok:** mower „rýchla kópia skrinky vedľa" vytvorí kópiu LEN ako geometriu — bez NOXUN identity kabinetu (kópia mimo observer/dedup
  flow). Pri stavbe quick actions kopírovanie prerobiť tak, aby kópia prešla štandardným dedup tickom (plná identita + config). *Stav: budúcnosť (po V1 / pri zostavách).*

## Po V1 — zásobník

- **D-48 · Zdieľaná knižnica pre 2 PC (Michal + Lucia)** (Michal 31.7. večer; **od 26.8. MIMO V1**) — obe pracoviská majú zobrazovať ROVNAKÉ šablóny aj materiály (spolupráca, posúvanie projektov).
  Jednotný zdroj = **firemný Google Disk** (sú tam všetky firemné veci). Dotýka sa: katalóg materiálov, šablóny korpusov, pravidlá kovania (dnes všetko v lokálnom %APPDATA%).
  *Stav: po V1 — dovtedy export/import ručne; predpoklad je perzistenčný kontrakt (CAS/rollback/konflikt 2 PC), viď audit podklad.*
- **DOCX/PDF generátor cenovej ponuky + rodina dokumentov** *(od 26.8. MIMO V1 — vyčlenené z odkladov dávky E)* — plný generátor ponuky do DOCX/PDF so šablónou a vizualizáciami (dnes XLSX) ·
  rodina dokumentov okolo ponuky (ponuka 3D vizualizácií, preberací protokol). *Predpoklad: neutrálny model ponuky (XLSX/DOCX/PDF ako renderery tých istých dát — audit kolo 0, P2).*
- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** (Michal 20.8., smoke test) — náhľad šablóny je dnes **kontextová fotografia** aktuálneho pohľadu dorámovaná na skrinku (UI-D2), takže do nej
  môže zasahovať okolitá geometria. Želanie: pred capture **dočasne skryť zvyšok modelu** a odfotiť skrinku samú. Prečo to nie je „malá zmena": skrývanie/odkrývanie geometrie je **zápis do modelu**
  (viditeľnosť entít, tagy), teda undo kroky, observery a riziko, že po zlyhaní ostane model rozbitý — presne tomu sa UI-D2 vedome vyhla. *Stav: OTVORENÉ, **nízka priorita / vysoká náročnosť** (Michal
  20.8.). Zaradenie: [PLAN.md](PLAN.md) → „Po V1 — zásobník". Medzitým platí náhrada: **ručné „Odfotiť" v okne Šablóny** (SMOKE PACK 1) — Michal si skrinku naaranžuje a izoluje sám a odfotí ju, kedy
  chce.*
