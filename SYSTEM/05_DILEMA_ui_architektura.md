# DILEMA: Architektúra UI — ako logicky rozdeliť panely (v0.1, 16.7.2026)

> Otvorená dilema na hlbší rozbor (Michal + GPT + Fable). Zapísané po V0.2a teste. Nie je to blokér — V0.2b pokračuje v jednom paneli; rozhodnutie sa aplikuje refaktorom UI vrstvy (dátové jadro sa nemení).

## Kontext a dôvod

- Nastavení pribúda (typy, konštrukčné varianty, chrbát hrúbka, výstuhy, čelá, zóny…) — jeden panel časom prestane stačiť. Zásada: **nebrzdiť korpus, neprehltiť panel** (progressive disclosure — základné hneď, pokročilé skladacie).
- **Noxun Pick / V2fable už z veľkej časti nebude použiteľný** (stavaný na DC knižnicu) — ale má overené funkcie, ktoré treba VYOPEROVAŤ: knižnica s náhľadmi (2-úrovňové thumby), jednoklikové vkladanie, ghost placement (klik/rad/rotácia šípkami), draw-to-size (Ghost 2.0: šírka→hĺbka→výška cez VCB), obľúbené, mm rozmery pri vklade, prisadzovanie (compute_gap → snaper).
- Panel má vždy zobrazovať len nastavenia pre vybraný typ + rozmery aktuálne označeného komponentu (potvrdené, už funguje).

## Možnosti

**A) Dva samostatné panely (pracovný návrh Fable — odporúčam):**
1. **VKLADAČ (Picker 2.0)** — „čo chcem pridať": šablóny korpusov s náhľadmi, neskôr knižnica modulov (čelá, vybavenie, doplnky), ghost placement, draw-to-size, obľúbené. Dedič Noxun Pick.
2. **INSPECTOR (Component Options 2.0)** — „čo mám označené": context-sensitive podľa výberu — korpus → parametre+konštrukcia; zóna → delenie/police/vkladanie do zóny; čelo → typ/výška/lock; dielec → rola/materiál/ABS (neskôr). Dedič dnešného panela + DC Control myšlienky.
- Pre: každé okno malé a sústredené; vkladač zavrieš, keď len upravuješ; Inspector žije pri výbere. Zrkadlí reálny workflow: najprv vkladám, potom ladím.
- Proti: dve okná = správa pozícií (HtmlDialog nemá docking); prekryv „vlož do zóny" je v oboch (riešiteľné: Inspector má rýchle skratky, Vkladač plnú knižnicu).

**B) Jeden panel s tabmi** (Vkladanie | Nastavenie | neskôr Výstupy):
- Pre: jedno okno, jednoduchá správa. Proti: taby skrývajú kontext (výber v modeli vs. aktívny tab), okno rastie do veľkosti najväčšieho tabu.

**C) Tri piliere (A + tretí panel Výstupy/Kontrola neskôr):** Vkladač + Inspector + od V0.5 „Výroba" (kusovník, semafor, exporty — persona: manželka). V podstate rozšírenie A.

## Otázky na rozbor (s GPT)

1. Dva panely vs. taby — čo je v SketchUp praxi príjemnejšie? (HtmlDialog pozície sa pamätajú cez preferences_key — docking neexistuje.)
2. Kde má žiť „vloženie do zóny": Inspector (kontext zóny) / Vkladač (knižnica) / oboje?
3. VCB kódy à la ArchiWood (zameriam zónu, napíšem `11 18 18` → čelá) — samostatná power vrstva popri paneloch? Kedy?
4. Klávesové skratky a toolbar ikony — ktoré akcie sú tak časté, že si zaslúžia ikonu (vlož poslednú šablónu, toggle zóny, Inspector)?
5. Čo presne vyoperovať z Noxun Pick ako prvé (thumby knižnice? ghost placement? draw-to-size?) a v ktorej etape (Vkladač je logicky V0.3+, po jadre).
6. Výstupný panel pre manželku — samostatné jednoduché okno („otvor, skontroluj semafor, exportuj") oddelené od návrhárskych panelov?

## Zapísané rozhodnutia (zatiaľ)

- Progressive disclosure v každom paneli: základné hneď, pokročilé skladacie, per-typ relevantné polia. (✅ ide do V0.2b)
- Dátové jadro je od UI oddelené — rozhodnutie dilemy je refaktor UI vrstvy, nie jadra. Preto sa dilema NEMUSÍ rozhodnúť hneď.
- Návrh Fable: smer **A/C** (Vkladač + Inspector, Výstupy neskôr tretí). Čaká na Michalov rozbor.
