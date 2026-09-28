# Package ROH-B2 · kresba rohovej zostavy, karta Čelá a drobnosti (K3)

> **Blok 8 · K3 ROHOVÁ SKRINKA**, štvrtá (posledná) kódová dávka pred uzáverom bloku. **Package v1** (28.9.2026 ~13:10, paralelná príprava počas B1).
> Štartuje z čerstvého `main` **po mergi ROH-B1**; ak B1 zmení niečo, na čom B2 stojí (riadok rohovej, `cornerDraft`, preflight), orchestrátor package zladí.
> Podklady: **schválený mockup** `SYSTEM/zdroje/bloky/ROHOVA/MOCKUP_ROHOVA_2026-09-28.html` (Michal 28.9.: „všetko sedí" — O1–O12 podľa návrhu; pre B2 sekcie
> **C** (náhľad), **B · Čelá** (O10), **O12**, **A** (ikona, O4)), packages ROH-A1/A2/B1. **Trieda:** UI (+ klávesa v nástroji vkladania = Ruby `ghost_tool`)
> → **predrecenzia povinná**, **in-SU brána** (nástroj vkladania, akcia panela), kontrakt sa nemení → `codex-audit` nie. Verzia → **v0.14.4**.

## Cieľ (z pohľadu stolára)

Rohová v paneli **vyzerá a správa sa ako v mockupe**: náhľad kreslí celú rohovú zostavu, karta Čelá nehovorí o veciach, ktoré sa pri rohovej nedajú,
a drobnosti z O12 ušetria preklikávanie.

## Scope IN

1. **Náhľad rohovej** (mockup sekcia C, `preview.js`): v čelnom pohľade Inspectora aj pri vkladaní — dvere v dverovej časti (A2), **CR 1** ako čelový pás
   vedľa dverí, **slepá časť = blenda korpusová šrafovaná** (tlmená), **CR 2 a rohová výstuha** ako 18 mm pásy (kolmo — spredu hrana), kóty 450 / 80 / 1100
   podľa mockupu, obe strany (zrkadlo), chybná kombinácia (nezmestí sa) červenou. Geometriu dielcov **počíta server** (vzor slotu/chladničky `params['preview']`,
   `pvApplianceRefs`) — JS len kreslí; žiadny druhý vzorec geometrie v JS. **Náhľad v kontexte Korpus** kreslí pri rohovej aj dvere a CR (O12). Ostatné
   typy sa **nepohnú o pixel** (parita s mainom).
2. **Karta Čelá rohovej** (O10): jeden riadok F1; rad „Pridať čelo" nahradí veta **„Rohová skrinka má v dverovej časti jedny dvierka."**; typ a krídla
   zamknuté s vysvetlením (tooltip); pánty slovami **„Pri boku / Pri rohu"** (namiesto Ľavé/Pravé — preklad podľa strany dverí; dáta ostávajú `left/right`,
   guard O1 bez zmeny). Server už štruktúru odmieta (A1) — UI prestane ponúkať mŕtve tlačidlá.
3. **Zóny rohovej:** ovládače delenia zón (stĺpce/riadky) sa pri rohovej nezobrazujú; počet políc ostáva (server odmieta delenie už z A1).
4. **O12 drobnosti:** „**Šírka dverí 446**" v pravom stĺpci Základných s preklikom do Čiel · súhrn **„dvere vľavo 450"** v lište Základné · **klávesa strany pri
   vkladaní** (ako otočenie ← →; voľ kláves, ktorý nekoliduje s existujúcimi klávesmi ghostu ani so skratkami SketchUpu počas aktívneho nástroja — zdôvodni v PR),
   pásik ghostu povie „dvere vľavo / vpravo"; prepnutie mení `cornerDraft` vkladania (vrátane zrkadla medzier/smeru/profilu šablóny — B1 bod 6 / audit B1 FIX 2).
5. **Ikona** tlačidla „Rohová" podľa mockupu (O4: dolná skrinka na sokli, dvere s úchytkou, prekrížená slepá časť), ak sa líši od ikony z A2.
6. **Odhad „≈ dielcov"** pri vkladaní rohovej započíta rohovú zostavu (+5) — A2 odchýlka 4.
7. **O8 (čaká na Michala):** ak Michal povie, že jantárové upozornenie „polica prechádza výstuhou závesov" nechce, B2 ho odstráni (inak bez zmeny).

## Scope OUT

Kontrakt, geometria stavby, výstupy (A1). Horná rohová, LeMans, kolízie so susedom, kresba výrezu police, CR v „Kresbe čiel".

## Testy a DoD

JS: kresba rohovej (server geometria → SVG prvky, obe strany, chybný stav), parita ostatných typov s mainom (všetky projekcie), Čelá (veta, zámky, „Pri boku /
Pri rohu" podľa strany), zóny bez delenia pri rohovej, O12 (šírka dverí, súhrn), odhad dielcov. In-SU: klávesa strany počas vkladania → vložená pravá rohová
(1 krok Späť), pásik ghostu; zvyšok cesty vkladania bez zmeny. Mutácie (min. 4). Každú JS sadu zvlášť.

## Smoke pre Michala (po B2) — zlúči sa do smoke checklistu uzáveru bloku

Náhľad rohovej = mockup C (vľavo/vpravo) · Čelá: veta „jedny dvierka", pánty „Pri rohu" · vkladanie: klávesa prepne stranu, pásik to povie · šírka dverí 446 v Základných.

## Checklist uzáveru

Bump v0.14.4 + `?v=` → testy (headless, JS, in-SU) → `ui-lifecycle.md`, `UI_DIZAJN.md` → STAV/KRONIKA/PLAN (riadok ROH-B2 ✅ `PR #?`) → číslo PR samostatným
commitom. Po B2 **uzáver bloku 8** (release/rohova, v0.15.0, smoke checklist, blok do archívu).
