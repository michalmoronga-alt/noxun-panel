# Noxun Engine — vízia uzatvorenia V1 (schválené 3.8.2026)

> Vznikla zo smoke testu V1 (3.8.2026; pracovný zápis testu je lokálny a do repa sa neprenáša). Účel: **kompas pre všetky dávky od hardeningu po V1** — aby každá ďalšia práca (E, opravy, UI 2.0) už držala jeden smer. Nie je to plán (ten žije v [PLAN.md](PLAN.md), aktuálny stav v [STAV.md](STAV.md)) — toto je definícia CIEĽA a princípov.

## 1 · Čo znamená „V1 hotové"

**Kompletná reálna zákazka od návrhu po objednávky BEZ opustenia pluginu a BEZ ručného dopočítavania:**

1. **Návrh:** vloženie skriniek na klik → zostava (kuchyňa/vstavaná skriňa/obývačka) vrátane skriniek so spotrebičmi; šablóny s kovaním = opakované typy na 1 klik.
2. **Konštrukcia:** korpusy vrátane per-dielec odsadení (vzduchové komíny, špeciály), výstuhy správne v interiéri, sokel/nohy podľa výšky.
3. **Materiály:** katalóg z Demosu, skupinové farby/textúry, prefarbovanie klikom; ABS automatika so semaforom.
4. **Kovanie:** sety s automatikou (nohy podľa sokla, bočnice podľa výšky čela, výklopy podľa hmotnosti čela), per-čelo overridy, výplne šuflíkov vo výťaži.
5. **Spotrebiče:** katalóg + položky projektu, kontrola niche, ceny v ponuke.
6. **Výstupy:** VEPO CSV, kusovník, nákupný zoznam kovania CSV, **rozpočet — všetko spolu s cenami** (materiál po tabuliach, ABS bm, kovanie, spotrebiče, sadzby služieb) = cenová ponuka pre zákazníka.
7. **Dvaja používatelia:** Michal (konštrukcia/výroba) aj **Lucia (vizualizácie + cenové ponuky)** — render vzhľad z katalógu, zrozumiteľné UI, žiadne „vedieť kde čo je".

**Mimo V1 (vedome):** zásuvkové bloky DC, rohové/špeciálne typy korpusov, CNC/výkresy, plná automatika niche→zóny, fyzické telá spotrebičov (kubusy), výrezy/otvory v dielcoch, umývačkový/digestorový modul ako typ.

## 2 · Princípy (nemenné)

- **Jednoduchosť > funkcie** (Lucia kompas). Automatika navrhuje, používateľ rozhoduje; semafor varuje, NIKDY neblokuje.
- **Nastav raz, používaj navždy:** šablóny (s kovaním), sety, predvoľby projektu, rady (nohy/bočnice/výklopy) — systém vyberá z radu, override na výnimky.
- **Snapshot na entite = autorita** (štandard 8.3); katalógy sú živé, projekt je reprodukovateľný z .skp.
- **Ceny = pohyblivá cache s dátumom overenia** — nikdy „zamrznuté ticho" (detail v [archiv/V1_VIZIA_priebeh_2026-08.md](archiv/V1_VIZIA_priebeh_2026-08.md), kap. 5).
- **Vertikálny priestor panela vzácny**; žiadne emoji v UI, Lucide ikony, tokeny --nx-*.

## Kde je zvyšok

Pôvodné paragrafy **3–7** (konštrukčný balík · kovanie fáza 3 · spotrebiče a ceny ·
workflow a UI 2.0 · navrhované poradie po smoke teste) boli **26.8.2026 presunuté do
[archiv/V1_VIZIA_priebeh_2026-08.md](archiv/V1_VIZIA_priebeh_2026-08.md)** (dávka Docs
cleanup B). Bol to priebeh plánovania z augusta 2026, nie definícia cieľa — a väčšina
z neho je odvtedy hotová alebo prerozdelená do blokov.

**Kde tie témy žijú dnes:**

- **Aktuálne plánovanie** — [PLAN.md](PLAN.md) (bloky prác, zásobník po V1).
- **Koncepty ďalších fáz** — [zdroje/next_sessions/](zdroje/next_sessions/); sú to
  **nezáväzné podklady** so statusom `KONCEPT`, neimplementujú sa priamo.
- **Čo je hotové a prečo** — [archiv/KRONIKA.md](archiv/KRONIKA.md).
