# Noxun Engine — vízia uzatvorenia V1 (schválené 3.8.2026)

> Vznikla zo smoke testu V1 (3.8.2026; pracovný zápis testu je lokálny a do repa sa neprenáša). Účel: **kompas pre všetky dávky od hardeningu po V1** — aby každá ďalšia práca (E, opravy, UI 2.0) už držala jeden smer. Nie je to plán (ten žije v [PLAN.md](PLAN.md), aktuálny stav v [STAV.md](STAV.md)) — toto je definícia CIEĽA a princípov.

## 1 · Čo znamená „V1 hotové"

**Kompletná reálna zákazka od návrhu po objednávky BEZ opustenia pluginu a BEZ ručného dopočítavania.**
Odškrtávací checklist — **súhrn, nie úplný výpočet**: autoritou rozsahu každého bodu sú položky
označené „V1 rozsah" v blokoch [PLAN.md](PLAN.md). **Bod sa odškrtáva, až keď je jeho V1 rozsah
v PLANe prázdny**; V1 je hotové, keď je odškrtnuté všetko. Stav dopĺňajú uzávery dávok.

1. [ ] **Návrh:** vloženie skriniek na klik (GHOST) → zostava vrátane skriniek so spotrebičmi; šablóny s kovaním = opakované typy na 1 klik. *(Zarovnanie a snap k susedom rieši blok „V1.0 zostavy" — snaper logika sa preberá DO pluginu, žiadny externý plugin; plné segmenty/attachments sú mimo V1.)*
2. [ ] **Konštrukcia:** korpusy vrátane per-dielec odsadení (vzduchové komíny, špeciály — V1-01), výstuhy správne v interiéri (hotové, D-80), sokel/nohy podľa výšky (hotové, D-79),
   čelo ako **cenová položka s dodávateľom** (V1-07 vo V1 rozsahu) a balík V0.4.8 (rohové spoje per strana, chrbát s poldrážkou, „bez dielca" varianty, per-dielec hrúbky a odsadenia).
3. [x] **Materiály:** katalóg z Demosu, skupinové farby, ABS automatika so semaforom, vyhľadávač s kontextom *(hotové — Materiály 2.0 + PICKER-1/2/3)*; quick-win textúry z Demos fotky ostávajú v bode 7.
4. [ ] **Kovanie:** sety s automatikou (nohy hotové D-79, bočnice hotové D-81; pomer 1:N = D-109; automatika počtu nôh podľa šírky), výklopy ako **cenové zaradenie podľa hmotnosti** (C-05),
   smer otvárania a typ závesu, per-čelo overridy + „Použiť na podobné", výplne šuflíkov **vo výťaži — fáza A** (vzorce dodá Michal). *(Plná geometria výplní a výklopový model = mimo V1.)*
5. [ ] **Spotrebiče:** katalóg + položky projektu, kontrola niche semaforom, ceny v rozpočte (S1).
6. [ ] **Výstupy:** VEPO CSV, kusovník, nákup kovania, rozpočet s cenami, XLSX cenová ponuka *(hotové — dávky E + fáza ŠTÚDIO)*; **ostáva zvyšok V1-03: manuálne 1-klik overenie ceny
   A viac URL na položke** — odškrtnúť až s oboma.
7. [ ] **Dvaja používatelia:** Michal aj **Lucia** — quick-win render (Demos fotka ako textúra), jednoduchý updater (D-52), zrozumiteľné UI *(Inspector+Štúdio hotové)*.

**Mimo V1 (vedome; rozšírené 26.8.2026 po debate s Michalom):** zásuvkové bloky (na novom štandarde), rohové/špeciálne typy korpusov, CNC/výkresy,
plná automatika niche→zóny, fyzické telá spotrebičov (kubusy), výrezy/otvory v dielcoch, umývačkový/digestorový modul ako typ ·
**plné zostavy/segmenty s attachments** (koncept 02) · **plná appearance vrstva a nástroj pixla** (koncept 06) ·
**ponuka DOCX/PDF s vizualizáciami** (koncept 08 — XLSX ponuka stačí na milník) · **G-Disk sync knižníc D-48** (updater D-52 ostáva;
katalógy zatiaľ export/import ručne) · **sektorová kontrola** (koncept 01 — toggle/presety plošnej kontroly ostávajú) ·
**typy čiel ako konfigurátor** (V1-07 — vo V1 len čelo ako cenová položka s dodávateľom, cena/m²) ·
**kovanie fáza 3 geometria** (výklopy plný model, výplne fáza B).

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
