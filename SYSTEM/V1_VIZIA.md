# Noxun Engine — vízia uzatvorenia V1 (schválené 3.8.2026; revízia 6.9.2026 po debate V1)

> Vznikla zo smoke testu V1 (3.8.2026; pracovný zápis testu je lokálny a do repa sa neprenáša). Účel: **kompas pre všetky dávky od hardeningu po V1** — aby každá ďalšia práca už držala jeden smer. Nie je to plán (ten žije v [PLAN.md](PLAN.md), aktuálny stav v [STAV.md](STAV.md)) — toto je definícia CIEĽA a princípov.
> **Revízia 6.9.2026:** body 1–7 prepísané podľa debaty V1 „po KOVANÍ" (Michal + Fable, 5.–6.9.2026); rozhodnutia a rozsahy sú v checkpointoch `zdroje/next_sessions/V1_DEBATA_2026-09-0*.md`.

## 1 · Čo znamená „V1 hotové"

**Kompletná reálna zákazka od návrhu po objednávky BEZ opustenia pluginu a BEZ ručného dopočítavania.**
Odškrtávací checklist — **súhrn, nie úplný výpočet**: autoritou rozsahu každého bodu sú položky
označené „V1 rozsah" v blokoch [PLAN.md](PLAN.md). **Bod sa odškrtáva, až keď je jeho V1 rozsah
v PLANe prázdny**; V1 je hotové, keď je odškrtnuté všetko. Stav dopĺňajú uzávery dávok.

1. [ ] **Návrh:** vloženie skriniek na klik (GHOST, **hotové** v0.9.0) · prisunutie a kópia po vlastnej osi (NÁSTROJE-1, **hotové** v0.9.25) · dosky vkladané a kreslené
   prichytením na skrinky (GHOST-D1/D2, packages v PLANe) · šablóny s kovaním = opakované typy na 1 klik (KOV-I). *(Zostavy, segmenty, sektory a viazané diely = PO V1, rozhodnutie 4.9.2026.)*
2. [ ] **Konštrukcia (rozhodnuté 6.9.2026):** **K1 odsadenia** — komín vzadu (dno a strop kratšie, chrbát na ich zadnej hrane) a strop zapustený vpredu, jedna nastaviteľná hodnota
   per skrinka · **K2 chrbát z výstuh** (dve lišty medzi bokmi, výška parameter) · **K3 rohová skrinka** dolná, slepá s CR lištou, prepínač L/P (nízka priorita, posledná) ·
   výstuhy v interiéri (hotové, D-80), sokel/nohy podľa výšky (hotové, D-79). *(Rohové spoje per strana, poldrážka, „bez dielca", čelo ako cenová položka V1-07 = mimo V1.)*
3. [x] **Materiály:** katalóg z Demosu, skupinové farby, ABS automatika so semaforom, vyhľadávač s kontextom *(hotové — Materiály 2.0 + PICKER-1/2/3)*.
4. [ ] **Kovanie:** blok KOVANIE (architektúra V1 FINAL 2.9.2026): sety s klasifikáciou a katalóg (A, B, H hotové), recepty a odvodené dielce zásuviek (C), resolver + zámky (D),
   výklopy podľa hmotnosti (E), závesy max(výška, hmotnosť) + úchytka + Tip-On (F), nohy 4/6 + príchyty (G), šablóny s kovaním (I), UI/UX balík Čiel (D-114 + D-119 presah
   per strana + D-120 UKW na dolnej a bočných hranách). *(Plný model výklopov, výplne fáza B, D-109 pomer setu = mimo V1.)*
5. [ ] **Spotrebiče S1 (rozhodnuté 6.9.2026):** ručný katalóg s odkazmi, technickými listami a **galériou príloh** · spotrebič patrí zákazke a vlastníkovi podľa kategórie (skrinka · slot umývačky · pracovná doska · len zákazka) · cena len v rozpočte ·
   kontrola niky vo V1 len chladnička a šírka umývačky · šablóna s tagom „spotrebičová" upozorní bez spotrebiča · za S1 spotrebičová skrinka ako šablóny nad K1.
   Predúloha (zoznam modelov + technické listy) hotová 6.9., čaká na Michalovo overenie listov. *(Kontrola rúry/mikro, police podľa niky, vetranie, digestor = mimo V1.)*
6. [ ] **Výstupy:** VEPO CSV, kusovník, nákup kovania, rozpočet s cenami, XLSX cenová ponuka *(hotové — dávky E + fáza ŠTÚDIO)* · **zvyšok V1-03 (rozhodnuté 6.9.2026):**
   manuálne 1-klik overenie ceny + viac URL na položke („na faktúru" vyradené) · **D-94** nákup s pôvodom · **nárezový plán primitívny** (horná hranica počtu platní podľa zvoleného rozloženia namiesto odhadu z m²; objednáva človek) ·
   **D-121** názvy dielcov do 20 znakov (fix). *(D-95 odškrtávanie diel po diele = preč natrvalo, stráž kolízií a EN DANIELI = mimo V1.)*
7. [ ] **Dvaja používatelia:** Michal aj **Lucia** (testuje od 6.9.2026) — updater D-52 (**hotové**) · **M-R VZHĽAD** (rozhodnuté 6.9.2026, nahrádza „Demos fotku": ručné textúry
   z knižnice, mierka + PBR v editore SketchUpu, „Uložiť vzhľad" do `.skm`, orientácia podľa smeru dekoru, aj ABS hrany a dosky) · zrozumiteľné UI *(Inspector + Štúdio hotové,
   D-51 uzavreté)* · D-122 Kontrola zoskupí UNI · D-124 predvoľby projektu rozbalené. *(Zdieľanie knižníc D-48 = prvá funkcia PO V1, viď Mimo V1.)*

**Mimo V1 (vedome; revízia 6.9.2026):** **D-48 zdieľané knižnice** = **prvá funkcia po uzávere V1** (Odoslať / Aktualizovať s verziami, koreň na Disku) ·
zostavy, segmenty, sektory, viazané diely (koncept 02) · D-95 plošná kontrola presety / X-ray, stráž kolízií, EN DANIELI · rohové spoje per strana, poldrážka, „bez dielca",
horná rohová, digestorový korpus, LeMans, materiál per rola dielca · V1-07 čelo ako cenová položka + konfigurátor typov čiel · pixla (V1-06) a zdieľanie `.skm` ·
D-106 predbežná cena skrinky · D-10 čelá ťahaním · DOCX/PDF ponuka s vizualizáciami (koncept 08) · kovanie fáza 3 geometria (plný model výklopov, výplne fáza B, D-109) ·
zásuvkové bloky na novom štandarde · CNC/výkresy · plná automatika niche→zóny · fyzické telá spotrebičov (kubusy) · výrezy/otvory v dielcoch · D-107 izolácia pri fotení šablóny.

## 2 · Princípy (nemenné)

- **Jednoduchosť > funkcie** (Lucia kompas). Automatika navrhuje, používateľ rozhoduje; semafor varuje, NIKDY neblokuje.
- **Nastav raz, používaj navždy:** šablóny (s kovaním), sety, predvoľby projektu, rady (nohy/bočnice/výklopy) — systém vyberá z radu, override na výnimky.
- **Snapshot na entite = autorita** (štandard 8.3); katalógy sú živé, projekt je reprodukovateľný z .skp.
- **Ceny = pohyblivá cache s dátumom overenia** — nikdy „zamrznuté ticho" (detail v [archiv/V1_VIZIA_priebeh_2026-08.md](archiv/V1_VIZIA_priebeh_2026-08.md), kap. 5).
- **Vertikálny priestor panela vzácny**; žiadne emoji v UI, Lucide ikony, tokeny --nx-*.
- **V1 je uzavretý balík** (Michal 6.9.2026): po uzávere obaja používajú naplno a ďalej sa doručujú update packy (postrehy Lucie a Michala, bloky po V1) cez updater a zdieľané knižnice.

## Kde je zvyšok

Pôvodné paragrafy **3–7** (konštrukčný balík · kovanie fáza 3 · spotrebiče a ceny ·
workflow a UI 2.0 · navrhované poradie po smoke teste) boli **26.8.2026 presunuté do
[archiv/V1_VIZIA_priebeh_2026-08.md](archiv/V1_VIZIA_priebeh_2026-08.md)** (dávka Docs
cleanup B). Bol to priebeh plánovania z augusta 2026, nie definícia cieľa — a väčšina
z neho je odvtedy hotová alebo prerozdelená do blokov.

**Kde tie témy žijú dnes:**

- **Aktuálne plánovanie** — [PLAN.md](PLAN.md) (bloky prác, zásobník po V1).
- **Rozhodnutia debaty V1 (5.–6.9.2026)** — checkpointy `zdroje/next_sessions/V1_DEBATA_2026-09-0*.md` (konštrukcia · spotrebiče + technické listy · výstupy · Lucia a knižnice · M-R vzhľad · kontrola a výroba).
- **Koncepty ďalších fáz** — [zdroje/next_sessions/](zdroje/next_sessions/); sú to
  **nezáväzné podklady** so statusom `KONCEPT`, neimplementujú sa priamo.
- **Čo je hotové a prečo** — [archiv/KRONIKA.md](archiv/KRONIKA.md).
