# Dogfooding zápisník — otvorené postrehy

> **Čo to je:** plné znenie **otvorených** postrehov z reálnej práce — D-čísla aj vedomé odklady bez čísla. Skupiny a ich poradie = bloky prác v [PLAN.md](PLAN.md); PLAN drží pri každej položke len jednu vetu, plný text je tu. *(PLAN nesie navyše aj prenesené záväzky z vízie V1, ktoré vlastný postreh nemajú — tie sa sem nekopírujú.)*
> **Údržba:** nový postreh = nové **D-číslo** do skupiny podľa bloku (číslovanie je trvalé, nerecykluje sa); vyriešený postreh **z tohto súboru zmizne** — plný text ide do sekcie
> „Vyriešené (plné texty)" v [archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md) (príčina, riešenie, PR) a **jeden riadok navrch INDEXU v tom istom súbore**.
> Tu ostávajú **len otvorené** postrehy (od 26.8.2026, dávka Docs cleanup B — stráži guard). Zmena zaradenia = presun medzi skupinami tu aj v PLAN.
> **Postrehy Michala sa píšu HNEĎ**, hocikedy a na hociktorú tému — zaradenie robí agent (plné pravidlo: [PLAN.md](PLAN.md), sekcia „Pravidlo pre postrehy").
> **Kde je zvyšok:** história zápisníka (priebežné stavy, 2A migračná mapa, hardening a sedenia V0.5, priebeh seedu, zodpovedané otázky) → [archiv/DOGFOODING_historia.md](archiv/DOGFOODING_historia.md) · odpočet merača D-25 → [zdroje/MERAC_D25_odpocet_2026-08.md](zdroje/MERAC_D25_odpocet_2026-08.md) · história dávok → [archiv/KRONIKA.md](archiv/KRONIKA.md).

## KONTROLA + VÝROBA

*(Skupina je prázdna a **blok 2 je uzavretý vo v0.16.0 (29.9.2026)** — D-94, D-112, D-113, D-121 a D-122 majú plné texty v
[archiv/DOGFOODING_vyriesene.md](archiv/DOGFOODING_vyriesene.md), primitívny nárezový plán (posledný bod bloku) je v [archiv/NAREZ_ZAVER_2026-09-29.md](archiv/NAREZ_ZAVER_2026-09-29.md).
Smoke bloku 2 **PASS 29.9.2026** (bez chýb); nové postrehy k týmto funkciám idú do skupiny podľa bloku — postreh zo smoke je **D-147** v Po V1 — zásobník.)*

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

## Po V1 — zásobník

- **D-147 · Nárezový plán: menšie dielce sa neukladajú nad seba v páse** (Michal 29.9.2026, smoke bloku 2) — pásové rozloženie dá do pásu dielce len
  vedľa seba; nad nižším dielcom ostáva voľné miesto (vidno ho ako zvyšok), hoci by sa tam zmestil ďalší menší dielec. Plán je preto opatrnejší (niekedy
  o platňu viac), než by musel. Doladiť heuristiku (vnáranie menších dielcov do voľného miesta pásu) po V1. *Stav: zásobník — Michal: „doladíme po V1".*
- **D-146 · Falošný duplák** (Michal 28.9.2026, pri štarte bloku Nárezový plán) — duplák, ktorý je pohľadový len z jednej strany: spodná vrstva sa neskladá
  z celej dosky, ale zo **100 mm širokých výstuh** — šetrí materiál aj váhu, keď obe strany nie sú pohľadové. Dnešný duplák (dve alebo tri plné vrstvy
  zdrojovej dosky) takú skladbu nepozná. *Stav: zásobník — Michal: „mimo V1, na zápis".*
- **D-145 · Náhľad Inspectora v lepšej 3D forme** (Michal 27.9.2026, pri schvaľovaní mockupu bloku KONŠTRUKCIA) — hĺbkové veci korpusu (komín vzadu,
  zapustený strop, lišty chrbta) dnešný čelný náhľad neukáže; malý bokorys v rohu náhľadu Michal **zamietol** kvôli zahlteniu priestoru panela. Neskôr
  navrhnúť celý náhľad v lepšej 3D forme, kde sa to dá zobraziť. *Stav: zásobník — bez termínu.*
- **D-141 · Typ „Umývačka" vo vkladacej karte neskôr ako „Spotrebič"** (Michal 21.9.2026, smoke S1) — samostatné tlačidlo typu pre jeden spotrebič je
  nesystémové; keď pribudne ďalší fyzický spotrebič ako samostatný objekt (voľne stojaca chladnička, sporák…), tlačidlo sa premenuje na **„Spotrebič"**
  a konkrétny druh sa vyberie pod ním. *Stav: zásobník — kým je slot umývačky jediný objekt bez korpusu, ostáva „Umývačka".*
- **D-142 · Delenie dverí chladničky aj pri skrinke so zásuvkami pod ňou** (Michal 24.9.2026, smoke S1) — kontrola delenia čiel (S1-F) sa počíta len pri
  skrinke s **práve dvoma** dvierkami nad sebou; vysoká skrinka so zásuvkami pod chladničkou (viac čiel) dostane „delenie sa netýka". Po výške osadenia
  (D-140) by sa dala vybrať dvojica dvierok nad osadením. *Stav: zásobník — Michal: „neskôr".*
- **D-126 · Otočenie obrázka textúry pred uložením** (Michal 12.9.2026, smoke M-R PASS) — pri vkladaní obrázka nie je samozrejmé, že kresba drevodekoru má byť vodorovná; plugin smer obrázka automaticky nerozpoznáva.
  Uzáver M-R pridáva pomocný text. Neskôr zvážiť otočenie obrázka o **±90° priamo v plugine pred uložením**. *Stav: odložené, bez termínu; neblokuje prijatý blok M-R.*
- **D-127 · Prirodzenejšie umiestnenie textúry na dielcoch** (Michal 12.9.2026, smoke M-R PASS) — orientácia textúry je správna, ale opakovanie vždy od rovnakého bodu pôsobí neprirodzene.
  Možnosti: **náhodný posun**, **nadväzovanie textúry v rámci skrinky** alebo **ručné umiestnenie**. Michal najprv zistí, ako sa s tým pracuje Lucii; výsledné ovládanie ani konkrétna možnosť ešte nie sú rozhodnuté.
  *Stav: odložené, čaká na prax; neblokuje prijatý blok M-R.*

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
`zdroje/next_sessions/V1_DEBATA_2026-09-06_LUCIA_KNIZNICE.md`. Dovtedy export/import ručne. **Príprava hotová (H16, 2.10.2026):** súpis
[../docs/architecture/kniznice.md](../docs/architecture/kniznice.md) (register `LibraryRegistry` v kóde) nahrádza záväzný zoznam store-ov §1 návrhu SYNC; rozmerové rady
a „18 + 36" ostávajú každému PC (Michal 2.10.); fakty pre D-48 v jeho časti 5.*
- **DOCX/PDF generátor cenovej ponuky + rodina dokumentov** *(od 26.8. MIMO V1 — vyčlenené z odkladov dávky E)* — plný generátor ponuky do DOCX/PDF so šablónou a vizualizáciami (dnes XLSX) ·
  rodina dokumentov okolo ponuky (ponuka 3D vizualizácií, preberací protokol). *Predpoklad: neutrálny model ponuky (XLSX/DOCX/PDF ako renderery tých istých dát — audit kolo 0, P2).*
- **D-107 · Izolácia objektu pred fotením náhľadu šablóny** (Michal 20.8., smoke test) — náhľad šablóny je dnes **kontextová fotografia** aktuálneho pohľadu dorámovaná na skrinku (UI-D2), takže do nej
  môže zasahovať okolitá geometria. Želanie: pred capture **dočasne skryť zvyšok modelu** a odfotiť skrinku samú. Prečo to nie je „malá zmena": skrývanie/odkrývanie geometrie je **zápis do modelu**
  (viditeľnosť entít, tagy), teda undo kroky, observery a riziko, že po zlyhaní ostane model rozbitý — presne tomu sa UI-D2 vedome vyhla. *Stav: OTVORENÉ, **nízka priorita / vysoká náročnosť** (Michal
  20.8.). Zaradenie: [PLAN.md](PLAN.md) → „Po V1 — zásobník". Medzitým platí náhrada: **ručné „Odfotiť" v okne Šablóny** (SMOKE PACK 1) — Michal si skrinku naaranžuje a izoluje sám a odfotí ju, kedy
  chce.*
