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
v [PLAN.md](PLAN.md) — **D-51 uzavreté 6.9.2026** (archív); **D-27** je vyriešené dávkou F/D-27 (v0.8.13)
a položka „výklop ako samostatný typ čela" dávkami KOV-A1 + KOV-A2a (v0.9.16). Skupina je prázdna.)*


## Balík Čiel — k bloku 4 · V1 DOTIAHNUTIE

*(**Blok KOVANIE je od 10.9.2026 uzavretý** — v0.10.0, plný text v [archiv/ROADMAP_hotove_etapy.md](archiv/ROADMAP_hotove_etapy.md).
Postrehy nižšie sa v ňom vedome neriešili: tvoria **UI/UX balík kontextu Čelá**, ktorý pri uzávere prešiel do bloku **4 · V1 DOTIAHNUTIE**
v [PLAN.md](PLAN.md), odrážka „BALÍK ČIEL". Čo z bloku KOVANIE ostalo mimo V1 (D-109), je v skupine **Po V1 — zásobník** nižšie.)*

- **D-114 · Rad piktogramov namiesto tlačidiel „+ pridaj dvere" / „+ pridaj čelo" + upratanie kontextu Čelá** (Michal 3.9., smoke v0.9.20 po KOV-A) — nové čelo sa má pridávať
  **priamo výberom typu**: namiesto dvoch textových tlačidiel jeden rad dlaždíc s tými istými sprite ikonami ako typegrid karty (dvierka · zásuvka · výklop · sklop · blenda; „bez
  čela" rozhodnúť), klik = nový riadok daného typu (dvierka ďalej cez výrobcu smeru „neurčené", pravidlo (a) karty). Rad zaberie **ten istý jeden riadok** ako dnešné dve tlačidlá.
  Michal zároveň: „celkovo UI čiel bude treba po tomto zásahu upratať — necháme na koniec, opäť spravíme UI/UX balík". *Stav: OTVORENÉ — od uzáveru bloku KOVANIE (10.9.2026) je to **UI/UX balík Čiel v bloku 4 · V1 DOTIAHNUTIE** ([PLAN.md](PLAN.md), odrážka „BALÍK ČIEL");
  celý obsah karty čela je už známy (typy z KOV-A, zámky osí a systém zásuvky z KOV-C/D, závesy z KOV-F, výklopy z KOV-E), takže balík sa môže robiť.*
- **D-119 · Presah dverí do strán per strana** (Lucia 6.9., prvý test pluginu na jej notebooku) — presah/okraj čela do strán je dnes **jedna hodnota pre obe strany**
  (`gap_sides`, Čelá); v praxi treba ľavú a pravú stranu nastaviť **zvlášť** (napr. čelo presahuje cez bok len na viditeľnej strane, pri susede ostáva škára). Hore/dole už
  zvlášť sú (`gap_top` / `gap_bottom`). *Stav: OTVORENÉ — zaradiť do UI/UX balíka kontextu Čelá (D-114) alebo skôr, ak blokuje prácu; mení config čela (CONFIG_SCHEMA bump).*
- **D-120 · Úchytkový profil (UKW) aj na dolnej a bočných hranách** (Lucia 6.9., prvý test) — profil sa dnes osadzuje **len na hornú hranu** čela; treba voľbu hrany:
  horná (dnes) · dolná · ľavá / pravá bočná (vysoké dvere, skrine). Registry `front_profiles.rb` hranu dnes **nepozná** — záznam nesie len `reduction`, popisky, obrys, hĺbku
  a výšku, `geometry`/`options` hranu nevracajú a modul výslovne predpokladá hornú hranu (komentár D-90 sľubuje len, že config to unesie bez migrácie). **Rozsah D-120 =**
  config čela (hrana) **+ registry/API** (hrana ako parameter profilu) **+ všetci konzumenti**: matematika panelu vo `Fronts` (skrátenie v inej osi), pravidlo kovania (dĺžka
  rezu), vizuál v modeli (renderer v `CabinetBuilder`), náhľad a UI panela; smer dekoru čela sa neotáča. *Stav: OTVORENÉ — **zaradené do UI/UX balíka Čiel (D-114), rozhodnuté 8.9.2026; do KOV-F NEPATRÍ.***

## KONTROLA + VÝROBA

- **D-94 · Traceability v celkovom súpise kovania — rozklik položky na miesta použitia** (Michal 9.8., test kovania na reálnej zákazke) — nákupný zoznam v okne Výroba povie „357695 × 12", ale nie
  **kde** tých 12 kusov je. Pri kontrole objednávky (a pri hľadaní, prečo je počet iný, než človek čakal) treba vedieť rozobrať riadok na **skrinky a čelá**, z ktorých vznikol. Dáta už existujú:
  `expand` skladá pri každom riadku pole `sources` (`cabinet_id`, `owner_part_key`, `generic_type`, `rule_id`, `set_id`, počet) — chýba len zobrazenie a klik-select. Návrh: rozklik riadku (vzor
  `<details>` v tabe Rozpočet) so zoznamom „CAB-003 · F2 · zásuvkové čelo — 2 ks" a klikom na výber v modeli (vzor KONTROLA tabu); ľudské názvy dielcov dodá `PartKeys.human_label` z D-92. *Stav:
  OTVORENÉ — návrh na dávku okolo okna Výroba; nízke riziko (čisté čítanie), stredný rozsah UI.*

## STABILITA

- **D-99 · Premenovanie dielca akoby prepísalo názvy všetkých kópií** (Michal 9.8., práca na zákazke KLINIKA) — po premenovaní jedného dielca to na chvíľu vyzeralo, akoby rovnaký názov dostali
  **všetky jeho kópie**; po prepnutí okna (zmena aktívneho modelu a späť) bolo všetko v poriadku, takže **dáta boli celý čas správne** — išlo o zobrazenie. *Stav: OTVORENÉ pozorovanie — zatiaľ
  **nereprodukované**. Sleduje sa; ak sa zopakuje, treba si všimnúť, či boli kópie vytvorené Ctrl+C/V (spoločná definícia, dedup tik) a čo presne ukazoval panel oproti modelu.*
- **Redo po zlúčených transparentných operáciách** — z hardening zoznamu uzáveru V0.5: manuálne overiť redo (Ctrl+Y) po zlúčených transparentných operáciách (pozorovanie zo 17.7.). *Stav: otvorené od 17.7. — Ruby API nemá na Windows spoľahlivú redo akciu, overuje sa rukou.*

- **D-117 · Nestabilný in-SU test „GHOST suspend: aktívny nástroj po upratovaní"** (orchestrátor 6.9., beh nad KOV-D4 hlavou f611bcb) — raz zlyhal s aktívnym `MeasureTool`
  (id 21024) namiesto `SelectionTool`, opakovaný beh nad tou istou hlavou prešiel (1927 PASS); dávka sa nástrojov nedotýkala a ten istý test prešiel v ~12 behoch toho dňa. Príčina
  = asercia predpokladá `SelectionTool`, ale `GhostTool.start` používa `push_tool`, takže po upratovaní sa vráti NÁSTROJ AKTÍVNY PRED scenárom (`ghost_tool.rb` ~r. 122) — keď beh
  štartuje s Tape Measure, `SelectionTool` sa neobjaví nikdy (poll by len časoval). *Stav: OTVORENÉ — návrh (Codex #318): v setupe sekcie si zapamätať aktívny nástroj a tvrdiť návrat
  PRÁVE NEHO, alebo pred štartom explicitne zvoliť Výber (`select_tool(nil)`); pri opakovaní hlásiť ID nástroja navrchu.*

## V1 DOTIAHNUTIE

- **Vedome odložené z dávky E — ceny (V1 rozsah)** (6.8., nič z toho neblokuje prácu so zákazkou) — **manuálne 1-klik overenie ceny** pre položky BEZ väzby na Demos a **viac URL na položke**
  (zvyšok V1-03; dnes ich „Prepočítať ceny" preskočí) · ~~prepínač „na faktúru" (×1,2)~~ — **vyradené 6.9.2026** (Michal: existuje prepínač s DPH / bez DPH); zvyšok rozhodnutý v `zdroje/next_sessions/V1_DEBATA_2026-09-06_VYSTUPY.md`.
  *(Piaty kus tej istej odkladovej sady — EN DANIELI textový export — je v skupine KONTROLA + VÝROBA; DOCX/PDF generátor a rodina dokumentov sú od 26.8. v skupine Po V1 — zásobník.)*
  *Stav: čaká na prax — vytiahne sa, keď si to reálna zákazka vypýta.*

## RENDER M-R

- **D-28 · Textúry materiálov (render)** (Michal 19.7. večer) — *Stav: **ZLÚČENÉ do bloku M-R VZHĽAD** (6.9.2026, [PLAN.md](PLAN.md) blok 5): **jediný kontrakt `appearance` → `.skm`**
  (textúra, mierka, priehľadnosť aj PBR v jednom SketchUp kontajneri — `Material#save_as` / `Materials#load`); „Uložiť vzhľad" = MR-2, orientácia podľa smeru dekoru = MR-3;
  `texture_path` ani samostatné PBR polia sa **nezavádzajú**, package „M-R FOTO" (Demos fotka) je nahradený; zdieľanie `.skm` medzi PC = D-48 po V1 (Luciina priorita).*
## INFRA

  *Stav: na návrhovú dávku — od 26.8. SAMOSTATNE (bez väzby na D-48, ktorý je mimo V1); distribučný kanál jednoducho, napr. zdieľaný priečinok.*
## Po V1 — zásobník

- **D-109 · Pomer člena setu „1 ks na N nôh"** (Michal 24.8., prvý test v0.8.0) — set kovania vie dnes počítať člena len **per unit** (na kus) alebo **per owner** (na skrinku). Chýba pomer typu „**1
  príchyt sokla na 4 nohy**": pri príchytoch soklovej lišty sa počet neviaže na skrinku ani na jednotlivú nohu, ale na ich **počet**. Dnes sa to musí dopočítať ručne — a práve to má set robiť za
  človeka. *(Nefixované v TEST-1: mení dátový model setu.)* *Stav: **MIMO V1 (uzáver bloku KOVANIE 10.9.2026)** — praktický výsledok
  (1 príchyt na začaté 4 nohy) dáva od KOV-G1b pravidlo `prichyt-sokla` podľa šírky korpusu (rozhodnutie O3), nesúlad po ručnom zámku
  počtu nôh hlási Kontrola ORANGE `plinth_clip_check`; chýba už len samotná **pomerová mechanika** setu = **R-05 po V1**
  ([PLAN.md](PLAN.md), „Po V1 — zásobník").*

- **EN DANIELI textový export** výrobného zadania (Michal: „po E") — **vedome odložené z dávky E** (6.8., nič z toho neblokuje prácu so zákazkou); supplier-agnostický výstup. *Stav: **MIMO V1 (Michal 6.9.2026)** — zásobník.*
- **D-106 · Predbežná cena korpusu v informačnom stĺpci Základných** (Michal 20.8., smoke test Inspector reworku) — pri návrhu skrinky chýba **orientačný náklad**: koľko tá skrinka zhruba stojí ešte
  predtým, než sa robí rozpočet celej zákazky. Údaj by stál v **informačnom stĺpci sektora Základné** (vedľa „Materiál m²", teda **žiadny nový riadok navyše**) ako text **„≈ X €"** so značkou odhadu a s
  **tooltipom rozpadu** (materiál: plocha × cena tabule · ABS: bm × cena · kovanie: ks × cena). Dáta existujú — je to tá istá cesta, ktorou počíta tab Rozpočet (`budget`, `sheet_estimate`,
  `hardware_catalog` ceny); ide o **odvodené čítanie**, nič sa nezapisuje. Pravidlá, ktoré platia: chýbajúca cena **nikdy nula**, ale priznaný odhad (D-61); je to **výstup, nie vstup** (text, nie pole).
  *Stav: **MIMO V1 (Michal 6.9.2026)** — zásobník.*
- **D-10 · Presúvanie/úprava čiel priamo v náhľade** (ako drag priečok). *Stav: **MIMO V1 (Michal 6.9.2026)** — zásobník.*
- **D-48 · Zdieľaná knižnica pre 2 PC (Michal + Lucia)** (Michal 31.7. večer; **od 26.8. MIMO V1**) — obe pracoviská majú zobrazovať ROVNAKÉ šablóny aj materiály (spolupráca, posúvanie projektov).
  Jednotný zdroj = **firemný Google Disk** (sú tam všetky firemné veci). Dotýka sa: katalóg materiálov, šablóny korpusov, pravidlá kovania (dnes všetko v lokálnom %APPDATA%).
*Stav: po V1 — **rozhodnuté 6.9.2026: PRVÁ funkcia po uzávere V1** v tvare Odoslať / Aktualizovať naraz pre všetky katalógy (aj nastavenia rozpočtu a dodávateľa, prílohy
spotrebičov, náhľady šablón), verzie per katalóg, konflikt ručne (výber verzie), štart len oznámi, koreň `H:\Môj disk\NoxunENGINE data`; odhad 3 PR — checkpoint
`zdroje/next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md`. Dovtedy export/import ručne.*
- **DOCX/PDF generátor cenovej ponuky + rodina dokumentov** *(od 26.8. MIMO V1 — vyčlenené z odkladov dávky E)* — plný generátor ponuky do DOCX/PDF so šablónou a vizualizáciami (dnes XLSX) ·
  rodina dokumentov okolo ponuky (ponuka 3D vizualizácií, preberací protokol). *Predpoklad: neutrálny model ponuky (XLSX/DOCX/PDF ako renderery tých istých dát — audit kolo 0, P2).*
- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** (Michal 20.8., smoke test) — náhľad šablóny je dnes **kontextová fotografia** aktuálneho pohľadu dorámovaná na skrinku (UI-D2), takže do nej
  môže zasahovať okolitá geometria. Želanie: pred capture **dočasne skryť zvyšok modelu** a odfotiť skrinku samú. Prečo to nie je „malá zmena": skrývanie/odkrývanie geometrie je **zápis do modelu**
  (viditeľnosť entít, tagy), teda undo kroky, observery a riziko, že po zlyhaní ostane model rozbitý — presne tomu sa UI-D2 vedome vyhla. *Stav: OTVORENÉ, **nízka priorita / vysoká náročnosť** (Michal
  20.8.). Zaradenie: [PLAN.md](PLAN.md) → „Po V1 — zásobník". Medzitým platí náhrada: **ručné „Odfotiť" v okne Šablóny** (SMOKE PACK 1) — Michal si skrinku naaranžuje a izoluje sám a odfotí ju, kedy
  chce.*
